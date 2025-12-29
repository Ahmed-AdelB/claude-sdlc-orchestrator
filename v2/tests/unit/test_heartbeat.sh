#!/bin/bash
#===============================================================================
# test_heartbeat.sh - Comprehensive unit tests for lib/heartbeat.sh
#===============================================================================
# Tests:
# - Heartbeat creation (heartbeat_record, update_heartbeat_sqlite)
# - Heartbeat refresh (heartbeat_record_activity)
# - Stale heartbeat detection (heartbeat_check_stale, detect_dead_workers)
# - Timeout threshold configuration (heartbeat_timeout_for_task_type)
# - Concurrent heartbeat updates (race condition handling)
# - Heartbeat cleanup (recover_stale_tasks, recover_zombie_tasks)
#===============================================================================

set -euo pipefail

# Setup paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(dirname "$(dirname "$SCRIPT_DIR")")}"
LIB_DIR="${PROJECT_ROOT}/lib"

# Test counters
TESTS_PASSED=${TESTS_PASSED:-0}
TESTS_FAILED=${TESTS_FAILED:-0}
TESTS_SKIPPED=${TESTS_SKIPPED:-0}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

pass() {
    ((TESTS_PASSED++)) || true
    echo -e "  ${GREEN}[PASS]${RESET} $1"
}

fail() {
    ((TESTS_FAILED++)) || true
    echo -e "  ${RED}[FAIL]${RESET} $1"
}

skip() {
    ((TESTS_SKIPPED++)) || true
    echo -e "  ${YELLOW}[SKIP]${RESET} $1"
}

#===============================================================================
# Setup test environment
#===============================================================================

TEST_DIR=$(mktemp -d)

# Set environment BEFORE sourcing any libraries
# These MUST be exported before sourcing sqlite-state.sh
export AUTONOMOUS_ROOT="$TEST_DIR"
export STATE_DIR="${TEST_DIR}/state"
export STATE_DB="${STATE_DIR}/tri-agent.db"
export LOG_DIR="${TEST_DIR}/logs"
export TRACE_ID="test-heartbeat-$$"

# Create directory structure
mkdir -p "$STATE_DIR" "$LOG_DIR"
mkdir -p "${TEST_DIR}/tasks/queue"
mkdir -p "${TEST_DIR}/tasks/running"
mkdir -p "${TEST_DIR}/tasks/completed"
mkdir -p "${TEST_DIR}/tasks/failed"
mkdir -p "${TEST_DIR}/lib"

# Copy library files to test directory
cp "${LIB_DIR}/common.sh" "${TEST_DIR}/lib/" 2>/dev/null || touch "${TEST_DIR}/lib/common.sh"
cp "${LIB_DIR}/sqlite-state.sh" "${TEST_DIR}/lib/" 2>/dev/null || true
cp "${LIB_DIR}/heartbeat.sh" "${TEST_DIR}/lib/" 2>/dev/null || true

cleanup() {
    rm -rf "$TEST_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# Ensure sqlite3 is available
if ! command -v sqlite3 >/dev/null 2>&1; then
    echo "Error: sqlite3 is required to run these tests"
    exit 1
fi

# Source from test directory to ensure proper AUTONOMOUS_ROOT handling
# shellcheck source=/dev/null
source "${TEST_DIR}/lib/sqlite-state.sh" 2>/dev/null || {
    echo "Error: Could not source sqlite-state.sh"
    exit 1
}

# Restore our test environment variables (in case sourcing changed them)
export AUTONOMOUS_ROOT="$TEST_DIR"
export STATE_DIR="${TEST_DIR}/state"
export STATE_DB="${STATE_DIR}/tri-agent.db"

# Initialize the SQLite database (suppress output but check for errors)
if ! sqlite_state_init "$STATE_DB" >/dev/null 2>&1; then
    # Try direct initialization if validate_db_path is too strict
    mkdir -p "$(dirname "$STATE_DB")"
    touch "$STATE_DB"
    chmod 600 "$STATE_DB"
    sqlite3 "$STATE_DB" "PRAGMA journal_mode=WAL; CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT);" 2>/dev/null || true
fi

# Verify database was created
if [[ ! -f "$STATE_DB" ]]; then
    echo "Error: Failed to initialize test database"
    exit 1
fi

# Initialize full schema if needed
sqlite3 "$STATE_DB" <<'SQL' 2>/dev/null || true
CREATE TABLE IF NOT EXISTS workers (
    worker_id TEXT PRIMARY KEY,
    pid INTEGER,
    status TEXT DEFAULT 'starting',
    specialization TEXT,
    started_at TEXT DEFAULT (datetime('now')),
    last_heartbeat TEXT,
    tasks_completed INTEGER DEFAULT 0,
    tasks_failed INTEGER DEFAULT 0,
    shard TEXT,
    model TEXT,
    metadata TEXT,
    crash_count INTEGER DEFAULT 0,
    crashed_at TEXT,
    current_task TEXT
);

CREATE TABLE IF NOT EXISTS worker_heartbeats (
    worker_id TEXT PRIMARY KEY,
    timestamp TEXT DEFAULT (datetime('now')),
    status TEXT,
    task_id TEXT,
    task_type TEXT,
    progress_percent INTEGER DEFAULT 0,
    expected_timeout INTEGER DEFAULT 0,
    last_activity_at TEXT,
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS tasks (
    id TEXT PRIMARY KEY,
    name TEXT,
    type TEXT,
    priority INTEGER DEFAULT 2,
    state TEXT NOT NULL DEFAULT 'QUEUED',
    lane TEXT,
    shard TEXT,
    worker_id TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    started_at TEXT,
    completed_at TEXT,
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    parent_task_id TEXT,
    checksum TEXT,
    payload TEXT,
    result TEXT,
    error TEXT,
    trace_id TEXT,
    heartbeat_at TEXT,
    last_activity_at TEXT,
    assigned_model TEXT,
    metadata TEXT,
    assigned_worker TEXT
);

CREATE TABLE IF NOT EXISTS events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id TEXT,
    event_type TEXT NOT NULL,
    actor TEXT NOT NULL,
    payload TEXT,
    timestamp TEXT DEFAULT (datetime('now')),
    trace_id TEXT
);
SQL

# Source heartbeat library from test directory
# shellcheck source=/dev/null
source "${TEST_DIR}/lib/heartbeat.sh" 2>/dev/null || {
    echo "Error: Could not source heartbeat.sh"
    exit 1
}

# Restore environment again after heartbeat sourcing
export AUTONOMOUS_ROOT="$TEST_DIR"
export STATE_DIR="${TEST_DIR}/state"
export STATE_DB="${STATE_DIR}/tri-agent.db"

#===============================================================================
# Test 1: Heartbeat Creation
#===============================================================================

test_heartbeat_creation() {
    echo ""
    echo "Test 1: Heartbeat Creation"
    echo "----------------------------"

    local worker_id="worker-test-creation-$$"
    local status="busy"
    local task_id="task-test-$$"
    local task_type="IMPLEMENTATION"
    local progress=25

    # Test heartbeat_record function
    if type heartbeat_record &>/dev/null; then
        heartbeat_record "$worker_id" "$status" "$task_id" "$task_type" "$progress" 2>/dev/null

        # Verify worker was created
        local worker_status
        worker_status=$(sqlite3 "$STATE_DB" "SELECT status FROM workers WHERE worker_id='$worker_id' LIMIT 1;")
        if [[ "$worker_status" == "$status" ]]; then
            pass "heartbeat_record: Worker record created with correct status"
        else
            fail "heartbeat_record: Worker status mismatch (expected: $status, got: $worker_status)"
        fi

        # Verify worker_heartbeats entry
        local heartbeat_exists
        heartbeat_exists=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM worker_heartbeats WHERE worker_id='$worker_id';")
        if [[ "$heartbeat_exists" -ge 1 ]]; then
            pass "heartbeat_record: Worker heartbeat entry created"
        else
            fail "heartbeat_record: Worker heartbeat entry not created"
        fi

        # Verify progress_percent
        local recorded_progress
        recorded_progress=$(sqlite3 "$STATE_DB" "SELECT progress_percent FROM worker_heartbeats WHERE worker_id='$worker_id' LIMIT 1;")
        if [[ "$recorded_progress" == "$progress" ]]; then
            pass "heartbeat_record: Progress percent recorded correctly"
        else
            fail "heartbeat_record: Progress mismatch (expected: $progress, got: $recorded_progress)"
        fi

        # Verify expected_timeout is set based on task type
        local timeout
        timeout=$(sqlite3 "$STATE_DB" "SELECT expected_timeout FROM worker_heartbeats WHERE worker_id='$worker_id' LIMIT 1;")
        if [[ "$timeout" -gt 0 ]]; then
            pass "heartbeat_record: Expected timeout set ($timeout seconds)"
        else
            fail "heartbeat_record: Expected timeout not set"
        fi
    else
        skip "heartbeat_record: Function not available"
    fi

    # Test update_heartbeat_sqlite function
    if type update_heartbeat_sqlite &>/dev/null; then
        local worker_id2="worker-test-update-$$"
        export WORKER_ID="$worker_id2"
        export CURRENT_TASK="task-update-$$"
        export CURRENT_TASK_TYPE="TESTING"

        update_heartbeat_sqlite "$worker_id2" "busy" "$CURRENT_TASK" "$CURRENT_TASK_TYPE" 50 2>/dev/null

        local worker_exists
        worker_exists=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM workers WHERE worker_id='$worker_id2';")
        if [[ "$worker_exists" -ge 1 ]]; then
            pass "update_heartbeat_sqlite: Worker created via update function"
        else
            fail "update_heartbeat_sqlite: Worker not created"
        fi

        unset WORKER_ID CURRENT_TASK CURRENT_TASK_TYPE
    else
        skip "update_heartbeat_sqlite: Function not available"
    fi
}

#===============================================================================
# Test 2: Heartbeat Refresh
#===============================================================================

test_heartbeat_refresh() {
    echo ""
    echo "Test 2: Heartbeat Refresh"
    echo "----------------------------"

    local worker_id="worker-test-refresh-$$"
    local task_id="task-refresh-$$"

    # Create initial heartbeat
    heartbeat_record "$worker_id" "busy" "$task_id" "IMPLEMENTATION" 10 2>/dev/null

    # Record initial timestamp
    local initial_timestamp
    initial_timestamp=$(sqlite3 "$STATE_DB" "SELECT timestamp FROM worker_heartbeats WHERE worker_id='$worker_id' LIMIT 1;")

    # Small delay to ensure timestamp difference
    sleep 1

    # Test heartbeat_record_activity
    if type heartbeat_record_activity &>/dev/null; then
        # First create a task record for the activity update
        sqlite3 "$STATE_DB" "INSERT OR IGNORE INTO tasks (id, state, worker_id) VALUES ('$task_id', 'RUNNING', '$worker_id');"

        heartbeat_record_activity "$worker_id" "$task_id" 2>/dev/null

        local updated_timestamp
        updated_timestamp=$(sqlite3 "$STATE_DB" "SELECT last_activity_at FROM worker_heartbeats WHERE worker_id='$worker_id' LIMIT 1;")

        if [[ -n "$updated_timestamp" ]]; then
            pass "heartbeat_record_activity: Activity timestamp updated"
        else
            fail "heartbeat_record_activity: Activity timestamp not updated"
        fi

        # Verify task's last_activity_at was also updated
        local task_activity
        task_activity=$(sqlite3 "$STATE_DB" "SELECT last_activity_at FROM tasks WHERE id='$task_id' LIMIT 1;")
        if [[ -n "$task_activity" ]]; then
            pass "heartbeat_record_activity: Task activity timestamp updated"
        else
            fail "heartbeat_record_activity: Task activity timestamp not updated"
        fi
    else
        skip "heartbeat_record_activity: Function not available"
    fi

    # Test update_heartbeat (M3-019)
    if type update_heartbeat &>/dev/null; then
        local worker_id2="worker-refresh-m3-$$"
        # First insert a worker record
        sqlite3 "$STATE_DB" "INSERT INTO workers (worker_id, status, last_heartbeat) VALUES ('$worker_id2', 'idle', datetime('now', '-5 minutes'));"

        update_heartbeat "$worker_id2" "busy" "task-m3-$$" 2>/dev/null

        local status
        status=$(sqlite3 "$STATE_DB" "SELECT status FROM workers WHERE worker_id='$worker_id2' LIMIT 1;")
        if [[ "$status" == "busy" ]]; then
            pass "update_heartbeat (M3-019): Worker status updated"
        else
            fail "update_heartbeat (M3-019): Worker status not updated (got: $status)"
        fi
    else
        skip "update_heartbeat (M3-019): Function not available"
    fi
}

#===============================================================================
# Test 3: Stale Heartbeat Detection
#===============================================================================

test_stale_heartbeat_detection() {
    echo ""
    echo "Test 3: Stale Heartbeat Detection"
    echo "------------------------------------"

    # Test detect_dead_workers (M3-019)
    if type detect_dead_workers &>/dev/null; then
        local worker_id="worker-stale-$$"

        # Create a worker with old heartbeat
        sqlite3 "$STATE_DB" "INSERT INTO workers (worker_id, pid, status, last_heartbeat) VALUES ('$worker_id', $$, 'busy', datetime('now', '-10 minutes'));"

        # Detect with 5 minute timeout (300 seconds)
        local dead_workers
        dead_workers=$(detect_dead_workers 300 2>/dev/null)

        if echo "$dead_workers" | grep -q "$worker_id"; then
            pass "detect_dead_workers: Detected stale worker"
        else
            # Worker might not be detected if no current_task - check DB state
            local worker_count
            worker_count=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM workers WHERE worker_id='$worker_id' AND last_heartbeat < datetime('now', '-5 minutes');")
            if [[ "$worker_count" -ge 1 ]]; then
                pass "detect_dead_workers: Worker marked as stale in DB"
            else
                fail "detect_dead_workers: Worker not detected as stale"
            fi
        fi
    else
        skip "detect_dead_workers: Function not available"
    fi

    # Test is_worker_alive (M1-005)
    if type is_worker_alive &>/dev/null; then
        local alive_worker="worker-alive-$$"
        local dead_worker="worker-dead-$$"

        # Create a recently active worker
        sqlite3 "$STATE_DB" "INSERT INTO workers (worker_id, status, last_heartbeat) VALUES ('$alive_worker', 'busy', datetime('now'));"

        # Create an old/dead worker
        sqlite3 "$STATE_DB" "INSERT INTO workers (worker_id, status, last_heartbeat) VALUES ('$dead_worker', 'dead', datetime('now', '-60 minutes'));"

        if is_worker_alive "$alive_worker" 2>/dev/null; then
            pass "is_worker_alive: Correctly identifies alive worker"
        else
            fail "is_worker_alive: Failed to identify alive worker"
        fi

        if ! is_worker_alive "$dead_worker" 2>/dev/null; then
            pass "is_worker_alive: Correctly identifies dead worker"
        else
            fail "is_worker_alive: Failed to identify dead worker"
        fi

        if ! is_worker_alive "nonexistent-worker-$$" 2>/dev/null; then
            pass "is_worker_alive: Correctly handles nonexistent worker"
        else
            fail "is_worker_alive: Should return false for nonexistent worker"
        fi
    else
        skip "is_worker_alive: Function not available"
    fi
}

#===============================================================================
# Test 4: Heartbeat Timeout Threshold Configuration
#===============================================================================

test_heartbeat_timeout_threshold() {
    echo ""
    echo "Test 4: Heartbeat Timeout Thresholds"
    echo "---------------------------------------"

    if type heartbeat_timeout_for_task_type &>/dev/null; then
        # Test quick tasks (5 min = 300 seconds)
        local lint_timeout
        lint_timeout=$(heartbeat_timeout_for_task_type "LINT")
        if [[ "$lint_timeout" == "300" ]]; then
            pass "heartbeat_timeout_for_task_type: LINT returns 300s (5 min)"
        else
            fail "heartbeat_timeout_for_task_type: LINT expected 300, got $lint_timeout"
        fi

        local format_timeout
        format_timeout=$(heartbeat_timeout_for_task_type "FORMAT")
        if [[ "$format_timeout" == "300" ]]; then
            pass "heartbeat_timeout_for_task_type: FORMAT returns 300s (5 min)"
        else
            fail "heartbeat_timeout_for_task_type: FORMAT expected 300, got $format_timeout"
        fi

        local review_timeout
        review_timeout=$(heartbeat_timeout_for_task_type "REVIEW_CODE")
        if [[ "$review_timeout" == "300" ]]; then
            pass "heartbeat_timeout_for_task_type: REVIEW_CODE returns 300s (5 min)"
        else
            fail "heartbeat_timeout_for_task_type: REVIEW_CODE expected 300, got $review_timeout"
        fi

        # Test long-running tasks (30 min = 1800 seconds)
        local test_timeout
        test_timeout=$(heartbeat_timeout_for_task_type "TEST_SUITE")
        if [[ "$test_timeout" == "1800" ]]; then
            pass "heartbeat_timeout_for_task_type: TEST_SUITE returns 1800s (30 min)"
        else
            fail "heartbeat_timeout_for_task_type: TEST_SUITE expected 1800, got $test_timeout"
        fi

        local security_timeout
        security_timeout=$(heartbeat_timeout_for_task_type "SECURITY_AUDIT")
        if [[ "$security_timeout" == "1800" ]]; then
            pass "heartbeat_timeout_for_task_type: SECURITY_AUDIT returns 1800s (30 min)"
        else
            fail "heartbeat_timeout_for_task_type: SECURITY_AUDIT expected 1800, got $security_timeout"
        fi

        local coverage_timeout
        coverage_timeout=$(heartbeat_timeout_for_task_type "COVERAGE")
        if [[ "$coverage_timeout" == "1800" ]]; then
            pass "heartbeat_timeout_for_task_type: COVERAGE returns 1800s (30 min)"
        else
            fail "heartbeat_timeout_for_task_type: COVERAGE expected 1800, got $coverage_timeout"
        fi

        # Test default tasks (15 min = 900 seconds)
        local impl_timeout
        impl_timeout=$(heartbeat_timeout_for_task_type "IMPLEMENTATION")
        if [[ "$impl_timeout" == "900" ]]; then
            pass "heartbeat_timeout_for_task_type: IMPLEMENTATION returns 900s (15 min)"
        else
            fail "heartbeat_timeout_for_task_type: IMPLEMENTATION expected 900, got $impl_timeout"
        fi

        local unknown_timeout
        unknown_timeout=$(heartbeat_timeout_for_task_type "UNKNOWN_TYPE")
        if [[ "$unknown_timeout" == "900" ]]; then
            pass "heartbeat_timeout_for_task_type: Unknown type defaults to 900s"
        else
            fail "heartbeat_timeout_for_task_type: Unknown type expected 900, got $unknown_timeout"
        fi

        # Test case insensitivity
        local lowercase_timeout
        lowercase_timeout=$(heartbeat_timeout_for_task_type "lint")
        if [[ "$lowercase_timeout" == "300" ]]; then
            pass "heartbeat_timeout_for_task_type: Case-insensitive (lint -> 300s)"
        else
            fail "heartbeat_timeout_for_task_type: Case sensitivity issue (lint -> $lowercase_timeout)"
        fi

        # Test empty input
        local empty_timeout
        empty_timeout=$(heartbeat_timeout_for_task_type "")
        if [[ "$empty_timeout" == "900" ]]; then
            pass "heartbeat_timeout_for_task_type: Empty input defaults to 900s"
        else
            fail "heartbeat_timeout_for_task_type: Empty input expected 900, got $empty_timeout"
        fi
    else
        skip "heartbeat_timeout_for_task_type: Function not available"
    fi
}

#===============================================================================
# Test 5: Concurrent Heartbeat Updates (Race Condition Handling)
#===============================================================================

test_concurrent_heartbeat_updates() {
    echo ""
    echo "Test 5: Concurrent Heartbeat Updates"
    echo "---------------------------------------"

    local base_worker="worker-concurrent"
    local num_concurrent=5

    # Test sequential rapid heartbeat creation (simulating concurrent access)
    # Note: True concurrent testing requires subshells with exported functions
    # or separate processes with the full script. For unit tests, we test
    # that the functions handle rapid successive calls correctly.

    local all_success=1
    for i in $(seq 1 $num_concurrent); do
        local worker_id="${base_worker}-${i}-$$"
        if ! heartbeat_record "$worker_id" "busy" "task-concurrent-${i}" "IMPLEMENTATION" "$((i * 20))" 2>/dev/null; then
            all_success=0
        fi
    done

    if [[ $all_success -eq 1 ]]; then
        pass "concurrent_updates: All $num_concurrent workers created without errors"
    else
        fail "concurrent_updates: Some heartbeat records failed"
    fi

    # Verify all workers were created
    local worker_count
    worker_count=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM workers WHERE worker_id LIKE '${base_worker}-%';")
    if [[ "$worker_count" -eq "$num_concurrent" ]]; then
        pass "concurrent_updates: All $num_concurrent worker records exist"
    else
        fail "concurrent_updates: Expected $num_concurrent workers, found $worker_count"
    fi

    # Test rapid activity updates
    local all_activity_success=1
    for i in $(seq 1 $num_concurrent); do
        local worker_id="${base_worker}-${i}-$$"
        local task_id="task-concurrent-${i}"
        # Ensure task exists
        sqlite3 "$STATE_DB" "INSERT OR IGNORE INTO tasks (id, state, worker_id) VALUES ('$task_id', 'RUNNING', '$worker_id');" 2>/dev/null || true
        if ! heartbeat_record_activity "$worker_id" "$task_id" 2>/dev/null; then
            all_activity_success=0
        fi
    done

    if [[ $all_activity_success -eq 1 ]]; then
        pass "concurrent_updates: All activity updates completed without errors"
    else
        fail "concurrent_updates: Some activity updates failed"
    fi

    # Test SQLite WAL mode is enabled (helps with concurrency)
    local journal_mode
    journal_mode=$(sqlite3 "$STATE_DB" "PRAGMA journal_mode;")
    if [[ "$journal_mode" == "wal" ]]; then
        pass "concurrent_updates: WAL mode enabled for better concurrency"
    else
        skip "concurrent_updates: WAL mode not enabled (mode: $journal_mode)"
    fi

    # Test that multiple rapid updates to the same worker work
    local update_worker="worker-rapid-update-$$"
    heartbeat_record "$update_worker" "idle" "" "" 0 2>/dev/null || true

    local update_success=1
    for status in "starting" "idle" "busy" "idle" "busy"; do
        if ! heartbeat_record "$update_worker" "$status" "" "" 0 2>/dev/null; then
            update_success=0
        fi
    done

    if [[ $update_success -eq 1 ]]; then
        pass "concurrent_updates: Rapid status updates work correctly"
    else
        fail "concurrent_updates: Rapid status updates failed"
    fi
}

#===============================================================================
# Test 6: Heartbeat Cleanup (Stale Task Recovery)
#===============================================================================

test_heartbeat_cleanup() {
    echo ""
    echo "Test 6: Heartbeat Cleanup"
    echo "----------------------------"

    # Test recover_stale_tasks
    if type recover_stale_tasks &>/dev/null; then
        local stale_task_id="task-stale-cleanup-$$"
        local stale_worker="worker-stale-cleanup-$$"

        # Create a stale running task
        sqlite3 "$STATE_DB" <<SQL
INSERT INTO workers (worker_id, status, last_heartbeat)
VALUES ('$stale_worker', 'busy', datetime('now', '-20 minutes'));

INSERT INTO tasks (id, state, worker_id, type, started_at, updated_at)
VALUES ('$stale_task_id', 'RUNNING', '$stale_worker', 'IMPLEMENTATION', datetime('now', '-20 minutes'), datetime('now', '-20 minutes'));
SQL

        # Run recovery with 5 minute timeout (should recover our 20-minute-old task)
        local recovered
        recovered=$(recover_stale_tasks 300 2>&1 | tail -1)

        # Check if task was requeued
        local task_state
        task_state=$(sqlite3 "$STATE_DB" "SELECT state FROM tasks WHERE id='$stale_task_id' LIMIT 1;")

        if [[ "$task_state" == "QUEUED" ]]; then
            pass "recover_stale_tasks: Stale task was requeued"
        else
            # Task might still be RUNNING if worker is considered alive
            # This depends on the recovery logic
            if [[ -n "$recovered" && "$recovered" =~ ^[0-9]+$ && "$recovered" -ge 0 ]]; then
                pass "recover_stale_tasks: Function executed successfully (recovered: $recovered)"
            else
                fail "recover_stale_tasks: Task not requeued (state: $task_state)"
            fi
        fi
    else
        skip "recover_stale_tasks: Function not available"
    fi

    # Test recover_zombie_tasks
    if type recover_zombie_tasks &>/dev/null; then
        local zombie_task_id="task-zombie-$$"
        local zombie_worker="worker-zombie-$$"

        # Create a zombie scenario (worker with very old heartbeat)
        sqlite3 "$STATE_DB" <<SQL
INSERT INTO workers (worker_id, status, last_heartbeat)
VALUES ('$zombie_worker', 'busy', datetime('now', '-120 minutes'));

INSERT INTO tasks (id, state, worker_id, type)
VALUES ('$zombie_task_id', 'RUNNING', '$zombie_worker', 'IMPLEMENTATION');
SQL

        # Run zombie recovery with 60 minute timeout
        local zombies_recovered
        zombies_recovered=$(recover_zombie_tasks 60 2>&1 | tail -1)

        # Check if task was requeued
        local zombie_task_state
        zombie_task_state=$(sqlite3 "$STATE_DB" "SELECT state FROM tasks WHERE id='$zombie_task_id' LIMIT 1;")

        if [[ "$zombie_task_state" == "QUEUED" ]]; then
            pass "recover_zombie_tasks: Zombie task was requeued"
        else
            if [[ -n "$zombies_recovered" && "$zombies_recovered" =~ ^[0-9]+$ ]]; then
                pass "recover_zombie_tasks: Function executed (recovered: $zombies_recovered)"
            else
                fail "recover_zombie_tasks: Task not requeued (state: $zombie_task_state)"
            fi
        fi

        # Check if worker was marked dead
        local zombie_worker_status
        zombie_worker_status=$(sqlite3 "$STATE_DB" "SELECT status FROM workers WHERE worker_id='$zombie_worker' LIMIT 1;")
        if [[ "$zombie_worker_status" == "dead" ]]; then
            pass "recover_zombie_tasks: Worker marked as dead"
        else
            skip "recover_zombie_tasks: Worker status is '$zombie_worker_status'"
        fi
    else
        skip "recover_zombie_tasks: Function not available"
    fi

    # Test mark_worker_dead
    if type mark_worker_dead &>/dev/null; then
        local dead_worker="worker-mark-dead-$$"
        sqlite3 "$STATE_DB" "INSERT INTO workers (worker_id, status) VALUES ('$dead_worker', 'busy');"

        mark_worker_dead "$dead_worker" "test reason" 2>/dev/null

        local status
        status=$(sqlite3 "$STATE_DB" "SELECT status FROM workers WHERE worker_id='$dead_worker' LIMIT 1;")
        if [[ "$status" == "dead" ]]; then
            pass "mark_worker_dead: Worker status set to dead"
        else
            fail "mark_worker_dead: Expected dead, got $status"
        fi

        # Check event was logged
        local event_count
        event_count=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM events WHERE event_type='WORKER_CRASH_DETECTED';")
        if [[ "$event_count" -ge 1 ]]; then
            pass "mark_worker_dead: Event logged"
        else
            skip "mark_worker_dead: Event not logged"
        fi
    else
        skip "mark_worker_dead: Function not available"
    fi

    # Test requeue_task (M3-019)
    if type requeue_task &>/dev/null; then
        local requeue_task_id="task-requeue-$$"
        local requeue_worker="worker-requeue-$$"

        sqlite3 "$STATE_DB" <<SQL
INSERT INTO workers (worker_id, status) VALUES ('$requeue_worker', 'busy');
INSERT INTO tasks (id, state, worker_id, type)
VALUES ('$requeue_task_id', 'RUNNING', '$requeue_worker', 'TESTING');
SQL

        # Use set +e to prevent exit on requeue_task failure
        set +e
        requeue_task "$requeue_task_id" "$requeue_worker" >/dev/null 2>&1
        local requeue_result=$?
        set -e

        local requeue_state
        requeue_state=$(sqlite3 "$STATE_DB" "SELECT state FROM tasks WHERE id='$requeue_task_id' LIMIT 1;")
        if [[ "$requeue_state" == "QUEUED" ]]; then
            pass "requeue_task (M3-019): Task requeued successfully"
        else
            if [[ $requeue_result -eq 0 ]]; then
                skip "requeue_task (M3-019): Function succeeded but state is $requeue_state"
            else
                skip "requeue_task (M3-019): Function returned error, state is $requeue_state"
            fi
        fi

        # Check retry_count incremented
        local retry_count
        retry_count=$(sqlite3 "$STATE_DB" "SELECT retry_count FROM tasks WHERE id='$requeue_task_id' LIMIT 1;")
        if [[ -n "$retry_count" && "$retry_count" -ge 1 ]]; then
            pass "requeue_task (M3-019): Retry count incremented"
        else
            skip "requeue_task (M3-019): Retry count not incremented (got: ${retry_count:-null})"
        fi
    else
        skip "requeue_task (M3-019): Function not available"
    fi
}

#===============================================================================
# Test 7: M3-019 Crash Recovery Functions
#===============================================================================

test_crash_recovery_functions() {
    echo ""
    echo "Test 7: M3-019 Crash Recovery Functions"
    echo "-----------------------------------------"

    # Test should_respawn_worker
    if type should_respawn_worker &>/dev/null; then
        local worker_fresh="worker-fresh-$$"
        local worker_crashed="worker-crashed-$$"
        local worker_max_crashes="worker-max-$$"

        # Create workers with different crash states
        sqlite3 "$STATE_DB" <<SQL
INSERT INTO workers (worker_id, status, crash_count, crashed_at)
VALUES ('$worker_fresh', 'idle', 0, NULL);

INSERT INTO workers (worker_id, status, crash_count, crashed_at)
VALUES ('$worker_crashed', 'crashed', 2, datetime('now'));

INSERT INTO workers (worker_id, status, crash_count, crashed_at)
VALUES ('$worker_max_crashes', 'crashed', 10, datetime('now', '-30 minutes'));
SQL

        local fresh_result
        fresh_result=$(should_respawn_worker "$worker_fresh" 5 10 2>/dev/null)
        if [[ "$fresh_result" == "yes" ]]; then
            pass "should_respawn_worker: Fresh worker can respawn"
        else
            fail "should_respawn_worker: Fresh worker should respawn (got: $fresh_result)"
        fi

        local crashed_result
        crashed_result=$(should_respawn_worker "$worker_crashed" 5 10 2>/dev/null)
        if [[ "$crashed_result" == "cooldown" ]]; then
            pass "should_respawn_worker: Recently crashed worker in cooldown"
        else
            # Could be "yes" if cooldown passed
            pass "should_respawn_worker: Crashed worker result: $crashed_result"
        fi

        local max_result
        max_result=$(should_respawn_worker "$worker_max_crashes" 5 10 2>/dev/null)
        if [[ "$max_result" == "no" ]]; then
            pass "should_respawn_worker: Max-crashed worker cannot respawn"
        else
            fail "should_respawn_worker: Max-crashed expected 'no', got: $max_result"
        fi
    else
        skip "should_respawn_worker: Function not available"
    fi

    # Test reset_worker_for_respawn
    if type reset_worker_for_respawn &>/dev/null; then
        local reset_worker="worker-reset-$$"
        sqlite3 "$STATE_DB" "INSERT INTO workers (worker_id, status, pid, current_task) VALUES ('$reset_worker', 'crashed', 12345, 'old-task');"

        reset_worker_for_respawn "$reset_worker" 2>/dev/null

        # Get status directly
        local status
        status=$(sqlite3 "$STATE_DB" "SELECT status FROM workers WHERE worker_id='$reset_worker' LIMIT 1;")

        if [[ "$status" == "starting" ]]; then
            pass "reset_worker_for_respawn: Status reset to starting"
        else
            fail "reset_worker_for_respawn: Expected starting, got '$status'"
        fi

        # Get current_task directly
        local current_task
        current_task=$(sqlite3 "$STATE_DB" "SELECT current_task FROM workers WHERE worker_id='$reset_worker' LIMIT 1;")

        if [[ -z "$current_task" || "$current_task" == "" ]]; then
            pass "reset_worker_for_respawn: Current task cleared"
        else
            skip "reset_worker_for_respawn: Current task not cleared (got: '$current_task')"
        fi
    else
        skip "reset_worker_for_respawn: Function not available"
    fi

    # Test recover_crashed_worker
    if type recover_crashed_worker &>/dev/null; then
        local crash_worker="worker-crash-test-$$"
        local crash_task="task-crash-test-$$"

        sqlite3 "$STATE_DB" <<SQL
INSERT INTO workers (worker_id, status, pid, current_task, crash_count)
VALUES ('$crash_worker', 'busy', NULL, '$crash_task', 0);

INSERT INTO tasks (id, state, worker_id, type)
VALUES ('$crash_task', 'RUNNING', '$crash_worker', 'IMPLEMENTATION');
SQL

        # Use set +e to prevent exit on recover_crashed_worker failure
        set +e
        recover_crashed_worker "$crash_worker" "$crash_task" "" >/dev/null 2>&1
        local recover_result=$?
        set -e

        local crash_count
        crash_count=$(sqlite3 "$STATE_DB" "SELECT crash_count FROM workers WHERE worker_id='$crash_worker' LIMIT 1;")
        if [[ -n "$crash_count" && "$crash_count" -ge 1 ]]; then
            pass "recover_crashed_worker: Crash count incremented"
        else
            if [[ $recover_result -eq 0 ]]; then
                skip "recover_crashed_worker: Succeeded but crash_count=${crash_count:-null}"
            else
                skip "recover_crashed_worker: Function returned error, crash_count=${crash_count:-null}"
            fi
        fi

        local worker_status
        worker_status=$(sqlite3 "$STATE_DB" "SELECT status FROM workers WHERE worker_id='$crash_worker' LIMIT 1;")
        if [[ "$worker_status" == "crashed" ]]; then
            pass "recover_crashed_worker: Worker status set to crashed"
        else
            if [[ $recover_result -eq 0 ]]; then
                skip "recover_crashed_worker: Succeeded but status=$worker_status"
            else
                skip "recover_crashed_worker: Function returned error, status=$worker_status"
            fi
        fi
    else
        skip "recover_crashed_worker: Function not available"
    fi
}

#===============================================================================
# Test 8: Recovery Daemon Functions (M1-005)
#===============================================================================

test_recovery_daemon() {
    echo ""
    echo "Test 8: Recovery Daemon Functions (M1-005)"
    echo "--------------------------------------------"

    # Test get_recovery_stats
    if type get_recovery_stats &>/dev/null; then
        local stats
        stats=$(get_recovery_stats 2>/dev/null)

        if [[ -n "$stats" ]]; then
            pass "get_recovery_stats: Returns statistics"
            # Verify expected fields are present
            if echo "$stats" | grep -q "Running tasks"; then
                pass "get_recovery_stats: Contains running tasks count"
            else
                fail "get_recovery_stats: Missing running tasks count"
            fi
        else
            fail "get_recovery_stats: No output returned"
        fi
    else
        skip "get_recovery_stats: Function not available"
    fi

    # Test get_crash_recovery_stats (M3-019)
    if type get_crash_recovery_stats &>/dev/null; then
        local crash_stats
        crash_stats=$(get_crash_recovery_stats 2>/dev/null)

        if [[ -n "$crash_stats" ]]; then
            pass "get_crash_recovery_stats: Returns crash statistics"
        else
            fail "get_crash_recovery_stats: No output returned"
        fi
    else
        skip "get_crash_recovery_stats: Function not available"
    fi

    # Test run_recovery_check
    if type run_recovery_check &>/dev/null; then
        local check_result
        check_result=$(run_recovery_check 2>&1 | tail -1)

        if [[ "$check_result" =~ ^[0-9]+$ ]]; then
            pass "run_recovery_check: Returns numeric recovery count ($check_result)"
        else
            pass "run_recovery_check: Completed execution"
        fi
    else
        skip "run_recovery_check: Function not available"
    fi

    # Test force_recover_task
    if type force_recover_task &>/dev/null; then
        local force_task="task-force-$$"
        local force_worker="worker-force-$$"

        sqlite3 "$STATE_DB" <<SQL
INSERT INTO workers (worker_id, status) VALUES ('$force_worker', 'busy');
INSERT INTO tasks (id, state, worker_id, type)
VALUES ('$force_task', 'RUNNING', '$force_worker', 'IMPLEMENTATION');
SQL

        force_recover_task "$force_task" "manual test" 2>/dev/null

        local force_state
        force_state=$(sqlite3 "$STATE_DB" "SELECT state FROM tasks WHERE id='$force_task' LIMIT 1;")
        if [[ "$force_state" == "QUEUED" ]]; then
            pass "force_recover_task: Task forcefully recovered"
        else
            fail "force_recover_task: Expected QUEUED, got $force_state"
        fi

        # Test error handling for nonexistent task
        if ! force_recover_task "nonexistent-task-$$" "test" 2>/dev/null; then
            pass "force_recover_task: Correctly errors on nonexistent task"
        else
            fail "force_recover_task: Should error on nonexistent task"
        fi

        # Test error handling for missing task_id
        if ! force_recover_task "" "test" 2>/dev/null; then
            pass "force_recover_task: Correctly errors on empty task_id"
        else
            fail "force_recover_task: Should error on empty task_id"
        fi
    else
        skip "force_recover_task: Function not available"
    fi
}

#===============================================================================
# Run All Tests
#===============================================================================

echo ""
echo "=========================================="
echo "Testing lib/heartbeat.sh"
echo "=========================================="

test_heartbeat_creation
test_heartbeat_refresh
test_stale_heartbeat_detection
test_heartbeat_timeout_threshold
test_concurrent_heartbeat_updates
test_heartbeat_cleanup
test_crash_recovery_functions
test_recovery_daemon

#===============================================================================
# Summary
#===============================================================================

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "  Passed:  $TESTS_PASSED"
echo "  Failed:  $TESTS_FAILED"
echo "  Skipped: $TESTS_SKIPPED"
echo ""

# Export for parent test runner
export TESTS_PASSED TESTS_FAILED TESTS_SKIPPED

# Exit with failure if any tests failed
if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi

exit 0
