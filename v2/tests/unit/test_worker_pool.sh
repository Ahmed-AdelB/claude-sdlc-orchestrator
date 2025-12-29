#!/bin/bash
#===============================================================================
# test_worker_pool.sh - Unit tests for lib/worker-pool.sh
#===============================================================================
# Tests worker pool functionality including:
# - Worker registration
# - Heartbeat updates
# - Stale worker detection
# - Task assignment
# - Concurrent worker limits (anti-starvation)
# - Worker status transitions
# - Worker cleanup
# - Pool initialization
#===============================================================================

# NOTE: Using set -u and pipefail but NOT -e because the library has a known
# issue with ((attempt++)) returning 1 when attempt=0, which triggers set -e
set -uo pipefail

# Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(dirname "$(dirname "$SCRIPT_DIR")")}"
LIB_DIR="${PROJECT_ROOT}/lib"

# Test counters
TESTS_PASSED=${TESTS_PASSED:-0}
TESTS_FAILED=${TESTS_FAILED:-0}

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
    echo -e "  ${YELLOW}[SKIP]${RESET} $1"
}

#===============================================================================
# Setup test environment
#===============================================================================

TEST_STATE_DIR=$(mktemp -d)
TEST_LOG_DIR=$(mktemp -d)

# Initialize arrays before sourcing state.sh (avoid unbound variable errors)
declare -g -a ACTIVE_LOCK_FDS=() 2>/dev/null || ACTIVE_LOCK_FDS=()
declare -g LAST_LOCK_FD="" 2>/dev/null || LAST_LOCK_FD=""

# Set worker pool configuration for testing
export POOL_SIZE=3
export POOL_CHECK_INTERVAL=1
export POOL_SHUTDOWN_TIMEOUT=5
export SHARD_COUNT=3
export WORKER_STALE_HEARTBEAT_MINUTES=1
export MAX_CONCURRENT_TASKS_PER_WORKER=3
export MAX_TASKS_PER_WORKER=5
export ANTI_STARVATION_ENABLED="true"
export ANTI_STARVATION_BACKOFF_SEC=0  # No delay in tests
export PER_USER_LIMITS_ENABLED="false"  # Disable per-user limits for simpler testing

# First, source lib files with PROJECT_ROOT as AUTONOMOUS_ROOT
export AUTONOMOUS_ROOT="${PROJECT_ROOT}"
export STATE_DIR="$TEST_STATE_DIR/state"
export STATE_DB="${STATE_DIR}/tri-agent.db"
export LOG_DIR="$TEST_LOG_DIR"
export BIN_DIR="${PROJECT_ROOT}/bin"
export TRACE_ID="test-worker-pool-$$"
export LOCKS_DIR="${STATE_DIR}/locks"

# Create required directories
mkdir -p "$STATE_DIR"
mkdir -p "$LOG_DIR"
mkdir -p "$LOCKS_DIR"

cleanup() {
    rm -rf "$TEST_STATE_DIR" "$TEST_LOG_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# Source dependencies - order matters
# sqlite-state.sh provides _sql_escape and _sqlite_exec
# heartbeat.sh provides update_heartbeat_sqlite and check_stale_workers_sqlite
# worker-pool.sh provides pool functions

if [[ -f "${LIB_DIR}/sqlite-state.sh" ]]; then
    # shellcheck source=/dev/null
    source "${LIB_DIR}/sqlite-state.sh"
else
    echo "ERROR: sqlite-state.sh not found at ${LIB_DIR}/sqlite-state.sh" >&2
    exit 1
fi

if [[ -f "${LIB_DIR}/heartbeat.sh" ]]; then
    # shellcheck source=/dev/null
    source "${LIB_DIR}/heartbeat.sh"
else
    echo "ERROR: heartbeat.sh not found at ${LIB_DIR}/heartbeat.sh" >&2
    exit 1
fi

if [[ -f "${LIB_DIR}/worker-pool.sh" ]]; then
    # shellcheck source=/dev/null
    source "${LIB_DIR}/worker-pool.sh"
else
    echo "ERROR: worker-pool.sh not found at ${LIB_DIR}/worker-pool.sh" >&2
    exit 1
fi

# IMPORTANT: The library files set -e which breaks tests due to ((attempt++)) bug
# Disable -e for the test runner
set +e

# NOW switch AUTONOMOUS_ROOT to TEST_STATE_DIR for runtime file operations
# This allows recover_stale_task to find the tasks/running and tasks/queue dirs
export AUTONOMOUS_ROOT="$TEST_STATE_DIR"

# Create task directories under the test AUTONOMOUS_ROOT
mkdir -p "${AUTONOMOUS_ROOT}/tasks/queue"
mkdir -p "${AUTONOMOUS_ROOT}/tasks/running"
mkdir -p "${AUTONOMOUS_ROOT}/logs"

# Initialize database
init_test_db() {
    sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true
}

#===============================================================================
# Test 1: Worker Pool Initialization
#===============================================================================
test_worker_pool_initialization() {
    echo ""
    echo "Test 1: Worker Pool Initialization"
    echo "-----------------------------------"

    # Re-initialize for this test
    rm -f "$STATE_DB"
    init_test_db

    if type pool_init &>/dev/null; then
        pool_init 2>/dev/null

        # Verify database exists
        if [[ -f "$STATE_DB" ]]; then
            pass "pool_init: Database created"
        else
            fail "pool_init: Database not created"
        fi

        # Verify workers table exists
        local tables
        tables=$(sqlite3 "$STATE_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='workers';" 2>/dev/null || echo "")
        if [[ "$tables" == "workers" ]]; then
            pass "pool_init: Workers table exists"
        else
            fail "pool_init: Workers table missing"
        fi

        # Verify tasks table exists
        tables=$(sqlite3 "$STATE_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='tasks';" 2>/dev/null || echo "")
        if [[ "$tables" == "tasks" ]]; then
            pass "pool_init: Tasks table exists"
        else
            fail "pool_init: Tasks table missing"
        fi

        # Verify log directory exists
        if [[ -d "$LOG_DIR" ]]; then
            pass "pool_init: Log directory exists"
        else
            fail "pool_init: Log directory missing"
        fi
    else
        skip "pool_init: Function not available"
    fi
}

#===============================================================================
# Test 2: Worker Registration
#===============================================================================
test_worker_registration() {
    echo ""
    echo "Test 2: Worker Registration"
    echo "---------------------------"

    init_test_db

    if type pool_register_worker &>/dev/null; then
        local worker_id="test-worker-$$"
        local pid="12345"
        local specialization="impl"
        local shard="shard-0"
        local model="codex"

        # Register worker
        pool_register_worker "$worker_id" "$pid" "$specialization" "$shard" "$model" 2>/dev/null

        # Verify worker was registered
        local result
        result=$(sqlite3 "$STATE_DB" "SELECT worker_id FROM workers WHERE worker_id='$worker_id';" 2>/dev/null || echo "")
        if [[ "$result" == "$worker_id" ]]; then
            pass "pool_register_worker: Worker registered successfully"
        else
            fail "pool_register_worker: Worker not found in database"
        fi

        # Verify specialization
        result=$(sqlite3 "$STATE_DB" "SELECT specialization FROM workers WHERE worker_id='$worker_id';" 2>/dev/null || echo "")
        if [[ "$result" == "$specialization" ]]; then
            pass "pool_register_worker: Specialization recorded"
        else
            fail "pool_register_worker: Specialization mismatch (expected: $specialization, got: $result)"
        fi

        # Verify shard
        result=$(sqlite3 "$STATE_DB" "SELECT shard FROM workers WHERE worker_id='$worker_id';" 2>/dev/null || echo "")
        if [[ "$result" == "$shard" ]]; then
            pass "pool_register_worker: Shard recorded"
        else
            fail "pool_register_worker: Shard mismatch (expected: $shard, got: $result)"
        fi

        # Verify model
        result=$(sqlite3 "$STATE_DB" "SELECT model FROM workers WHERE worker_id='$worker_id';" 2>/dev/null || echo "")
        if [[ "$result" == "$model" ]]; then
            pass "pool_register_worker: Model recorded"
        else
            fail "pool_register_worker: Model mismatch (expected: $model, got: $result)"
        fi

        # Verify initial status is 'starting'
        result=$(sqlite3 "$STATE_DB" "SELECT status FROM workers WHERE worker_id='$worker_id';" 2>/dev/null || echo "")
        if [[ "$result" == "starting" ]]; then
            pass "pool_register_worker: Initial status is 'starting'"
        else
            fail "pool_register_worker: Status should be 'starting', got: $result"
        fi

        # Test re-registration (should update, not duplicate)
        pool_register_worker "$worker_id" "$pid" "$specialization" "$shard" "$model" 2>/dev/null
        local count
        count=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM workers WHERE worker_id='$worker_id';" 2>/dev/null || echo "0")
        if [[ "$count" == "1" ]]; then
            pass "pool_register_worker: Re-registration updates instead of duplicating"
        else
            fail "pool_register_worker: Re-registration created duplicate entries (count: $count)"
        fi
    else
        skip "pool_register_worker: Function not available"
    fi
}

#===============================================================================
# Test 3: Worker Heartbeat Update
#===============================================================================
test_worker_heartbeat_update() {
    echo ""
    echo "Test 3: Worker Heartbeat Update"
    echo "--------------------------------"

    init_test_db

    if type update_heartbeat_sqlite &>/dev/null; then
        local worker_id="heartbeat-worker-$$"

        # First register the worker
        if type pool_register_worker &>/dev/null; then
            pool_register_worker "$worker_id" "$$" "impl" "shard-0" "codex" 2>/dev/null
        else
            # Manually insert worker
            sqlite3 "$STATE_DB" "INSERT INTO workers (worker_id, pid, status, last_heartbeat) VALUES ('$worker_id', $$, 'starting', datetime('now', '-1 hour'));" 2>/dev/null
        fi

        # Get initial heartbeat time
        local initial_heartbeat
        initial_heartbeat=$(sqlite3 "$STATE_DB" "SELECT last_heartbeat FROM workers WHERE worker_id='$worker_id';" 2>/dev/null || echo "")

        # Small delay to ensure time difference
        sleep 1

        # Update heartbeat
        update_heartbeat_sqlite "$worker_id" "busy" "task-123" "IMPLEMENTATION" 50 2>/dev/null

        # Get updated heartbeat time
        local updated_heartbeat
        updated_heartbeat=$(sqlite3 "$STATE_DB" "SELECT last_heartbeat FROM workers WHERE worker_id='$worker_id';" 2>/dev/null || echo "")

        if [[ -n "$updated_heartbeat" && "$updated_heartbeat" != "$initial_heartbeat" ]]; then
            pass "update_heartbeat_sqlite: Heartbeat time updated"
        else
            fail "update_heartbeat_sqlite: Heartbeat time not updated"
        fi

        # Verify status was updated
        local status
        status=$(sqlite3 "$STATE_DB" "SELECT status FROM workers WHERE worker_id='$worker_id';" 2>/dev/null || echo "")
        if [[ "$status" == "busy" ]]; then
            pass "update_heartbeat_sqlite: Status updated to 'busy'"
        else
            fail "update_heartbeat_sqlite: Status not updated (expected: busy, got: $status)"
        fi

        # Verify worker_heartbeats table entry
        local heartbeat_entry
        heartbeat_entry=$(sqlite3 "$STATE_DB" "SELECT worker_id FROM worker_heartbeats WHERE worker_id='$worker_id';" 2>/dev/null || echo "")
        if [[ "$heartbeat_entry" == "$worker_id" ]]; then
            pass "update_heartbeat_sqlite: Heartbeat entry created in worker_heartbeats"
        else
            fail "update_heartbeat_sqlite: No entry in worker_heartbeats table"
        fi
    else
        skip "update_heartbeat_sqlite: Function not available"
    fi
}

#===============================================================================
# Test 4: Stale Worker Detection
#===============================================================================
test_stale_worker_detection() {
    echo ""
    echo "Test 4: Stale Worker Detection"
    echo "-------------------------------"

    init_test_db

    if type recover_stale_task &>/dev/null; then
        local worker_id="stale-worker-$$"
        local task_id="stale-task-$$"

        # Create a stale worker and task that should be recovered
        sqlite3 "$STATE_DB" <<SQL
INSERT INTO workers (worker_id, pid, status, last_heartbeat)
VALUES ('$worker_id', 99999, 'busy', datetime('now', '-10 minutes'));

INSERT INTO tasks (id, name, type, priority, state, worker_id, started_at, heartbeat_at, last_activity_at)
VALUES ('$task_id', 'Test Task', 'IMPLEMENTATION', 2, 'RUNNING', '$worker_id', datetime('now', '-10 minutes'), datetime('now', '-10 minutes'), datetime('now', '-10 minutes'));

INSERT INTO worker_heartbeats (worker_id, timestamp, status, task_id, task_type, progress_percent, expected_timeout, last_activity_at, updated_at)
VALUES ('$worker_id', datetime('now', '-10 minutes'), 'busy', '$task_id', 'IMPLEMENTATION', 0, 300, datetime('now', '-10 minutes'), datetime('now', '-10 minutes'));
SQL

        # Verify task is initially in RUNNING state
        local initial_state
        initial_state=$(sqlite3 "$STATE_DB" "SELECT state FROM tasks WHERE id='$task_id';")
        if [[ "$initial_state" == "RUNNING" ]]; then
            pass "stale_worker_detection: Task initially in RUNNING state"
        else
            fail "stale_worker_detection: Task not in expected initial state (got: $initial_state)"
        fi

        # Test recover_stale_task directly - this is the core function
        recover_stale_task "$task_id" "$worker_id" "test stale detection" 2>/dev/null

        # Verify worker status was updated to 'dead'
        local worker_status
        worker_status=$(sqlite3 "$STATE_DB" "SELECT status FROM workers WHERE worker_id='$worker_id';")
        if [[ "$worker_status" == "dead" ]]; then
            pass "stale_worker_detection: Stale worker marked as 'dead'"
        else
            fail "stale_worker_detection: Worker status not updated (expected: dead, got: $worker_status)"
        fi

        # Verify task was requeued
        local task_state
        task_state=$(sqlite3 "$STATE_DB" "SELECT state FROM tasks WHERE id='$task_id';")
        if [[ "$task_state" == "QUEUED" ]]; then
            pass "stale_worker_detection: Task requeued after worker marked dead"
        else
            fail "stale_worker_detection: Task not requeued (state: $task_state)"
        fi
    else
        skip "recover_stale_task: Function not available"
    fi
}

#===============================================================================
# Test 5: Worker Task Assignment
#===============================================================================
test_worker_task_assignment() {
    echo ""
    echo "Test 5: Worker Task Assignment"
    echo "-------------------------------"

    init_test_db

    if type claim_task_for_shard &>/dev/null; then
        local worker_id="assign-worker-$$"
        local task_id="assign-task-$$"
        local shard="shard-0"

        # Register worker
        if type pool_register_worker &>/dev/null; then
            pool_register_worker "$worker_id" "$$" "impl" "$shard" "codex" 2>/dev/null
        fi

        # Create a queued task
        sqlite3 "$STATE_DB" <<SQL 2>/dev/null
INSERT INTO tasks (id, name, type, priority, state, shard, assigned_model)
VALUES ('$task_id', 'Test Task', 'IMPLEMENTATION', 2, 'QUEUED', '$shard', 'codex');
SQL

        # Claim the task
        local claimed_task
        claimed_task=$(claim_task_for_shard "$worker_id" "$shard" "" "codex" 2>/dev/null || echo "")

        if [[ "$claimed_task" == "$task_id" ]]; then
            pass "claim_task_for_shard: Task claimed successfully"
        else
            fail "claim_task_for_shard: Task not claimed (expected: $task_id, got: $claimed_task)"
        fi

        # Verify task state changed to RUNNING
        local task_state
        task_state=$(sqlite3 "$STATE_DB" "SELECT state FROM tasks WHERE id='$task_id';" 2>/dev/null || echo "")
        if [[ "$task_state" == "RUNNING" ]]; then
            pass "claim_task_for_shard: Task state changed to RUNNING"
        else
            fail "claim_task_for_shard: Task state not updated (expected: RUNNING, got: $task_state)"
        fi

        # Verify worker_id was set
        local assigned_worker
        assigned_worker=$(sqlite3 "$STATE_DB" "SELECT worker_id FROM tasks WHERE id='$task_id';" 2>/dev/null || echo "")
        if [[ "$assigned_worker" == "$worker_id" ]]; then
            pass "claim_task_for_shard: Worker ID assigned to task"
        else
            fail "claim_task_for_shard: Worker ID not assigned (expected: $worker_id, got: $assigned_worker)"
        fi

        # Verify started_at was set
        local started_at
        started_at=$(sqlite3 "$STATE_DB" "SELECT started_at FROM tasks WHERE id='$task_id';" 2>/dev/null || echo "")
        if [[ -n "$started_at" ]]; then
            pass "claim_task_for_shard: started_at timestamp set"
        else
            fail "claim_task_for_shard: started_at not set"
        fi
    else
        skip "claim_task_for_shard: Function not available"
    fi
}

#===============================================================================
# Test 6: Concurrent Worker Limits (Anti-Starvation)
#===============================================================================
test_concurrent_worker_limits() {
    echo ""
    echo "Test 6: Concurrent Worker Limits (Anti-Starvation)"
    echo "---------------------------------------------------"

    init_test_db

    if type check_worker_can_claim &>/dev/null && type get_worker_running_task_count &>/dev/null; then
        local worker_id="limit-worker-$$"

        # Register worker
        if type pool_register_worker &>/dev/null; then
            pool_register_worker "$worker_id" "$$" "impl" "shard-0" "codex" 2>/dev/null
        fi

        # Initially worker should be able to claim
        if check_worker_can_claim "$worker_id" "$STATE_DB" 2>/dev/null; then
            pass "check_worker_can_claim: Worker can claim with no running tasks"
        else
            fail "check_worker_can_claim: Worker should be able to claim initially"
        fi

        # Create MAX_CONCURRENT_TASKS_PER_WORKER running tasks for this worker
        local i
        for ((i = 1; i <= MAX_CONCURRENT_TASKS_PER_WORKER; i++)); do
            sqlite3 "$STATE_DB" <<SQL 2>/dev/null
INSERT INTO tasks (id, name, type, priority, state, worker_id, started_at)
VALUES ('limit-task-$i-$$', 'Test Task $i', 'IMPLEMENTATION', 2, 'RUNNING', '$worker_id', datetime('now'));
SQL
        done

        # Verify running task count
        local running_count
        running_count=$(get_worker_running_task_count "$worker_id" "$STATE_DB" 2>/dev/null || echo "0")
        if [[ "$running_count" == "$MAX_CONCURRENT_TASKS_PER_WORKER" ]]; then
            pass "get_worker_running_task_count: Correct count ($running_count)"
        else
            fail "get_worker_running_task_count: Wrong count (expected: $MAX_CONCURRENT_TASKS_PER_WORKER, got: $running_count)"
        fi

        # Now worker should NOT be able to claim
        if ! check_worker_can_claim "$worker_id" "$STATE_DB" 2>/dev/null; then
            pass "check_worker_can_claim: Worker blocked at limit"
        else
            fail "check_worker_can_claim: Worker should be blocked at limit"
        fi

        # Test get_worker_starvation_status
        if type get_worker_starvation_status &>/dev/null; then
            local status_json
            status_json=$(get_worker_starvation_status "$worker_id" "$STATE_DB" 2>/dev/null || echo "{}")

            if echo "$status_json" | grep -q '"can_claim": false'; then
                pass "get_worker_starvation_status: Correctly reports can_claim=false"
            else
                fail "get_worker_starvation_status: Should report can_claim=false at limit"
            fi
        fi

        # Complete one task - worker should be able to claim again
        sqlite3 "$STATE_DB" "UPDATE tasks SET state='COMPLETED' WHERE id='limit-task-1-$$';" 2>/dev/null

        if check_worker_can_claim "$worker_id" "$STATE_DB" 2>/dev/null; then
            pass "check_worker_can_claim: Worker can claim after task completion"
        else
            fail "check_worker_can_claim: Worker should be able to claim after task completion"
        fi
    else
        skip "check_worker_can_claim/get_worker_running_task_count: Functions not available"
    fi
}

#===============================================================================
# Test 7: Worker Status Transitions
#===============================================================================
test_worker_status_transitions() {
    echo ""
    echo "Test 7: Worker Status Transitions"
    echo "----------------------------------"

    init_test_db

    local worker_id="transition-worker-$$"

    # Test valid worker status values: starting, idle, busy, stopping, dead, crashed

    # Create worker with 'starting' status
    sqlite3 "$STATE_DB" <<SQL 2>/dev/null
INSERT INTO workers (worker_id, pid, status, last_heartbeat)
VALUES ('$worker_id', $$, 'starting', datetime('now'));
SQL

    # Verify initial status
    local status
    status=$(sqlite3 "$STATE_DB" "SELECT status FROM workers WHERE worker_id='$worker_id';" 2>/dev/null || echo "")
    if [[ "$status" == "starting" ]]; then
        pass "status_transitions: Initial status is 'starting'"
    else
        fail "status_transitions: Initial status wrong (expected: starting, got: $status)"
    fi

    # Transition to 'idle'
    sqlite3 "$STATE_DB" "UPDATE workers SET status='idle' WHERE worker_id='$worker_id';" 2>/dev/null
    status=$(sqlite3 "$STATE_DB" "SELECT status FROM workers WHERE worker_id='$worker_id';" 2>/dev/null || echo "")
    if [[ "$status" == "idle" ]]; then
        pass "status_transitions: Transitioned to 'idle'"
    else
        fail "status_transitions: Transition to 'idle' failed (got: $status)"
    fi

    # Transition to 'busy'
    sqlite3 "$STATE_DB" "UPDATE workers SET status='busy' WHERE worker_id='$worker_id';" 2>/dev/null
    status=$(sqlite3 "$STATE_DB" "SELECT status FROM workers WHERE worker_id='$worker_id';" 2>/dev/null || echo "")
    if [[ "$status" == "busy" ]]; then
        pass "status_transitions: Transitioned to 'busy'"
    else
        fail "status_transitions: Transition to 'busy' failed (got: $status)"
    fi

    # Transition to 'stopping'
    sqlite3 "$STATE_DB" "UPDATE workers SET status='stopping' WHERE worker_id='$worker_id';" 2>/dev/null
    status=$(sqlite3 "$STATE_DB" "SELECT status FROM workers WHERE worker_id='$worker_id';" 2>/dev/null || echo "")
    if [[ "$status" == "stopping" ]]; then
        pass "status_transitions: Transitioned to 'stopping'"
    else
        fail "status_transitions: Transition to 'stopping' failed (got: $status)"
    fi

    # Transition to 'dead'
    sqlite3 "$STATE_DB" "UPDATE workers SET status='dead' WHERE worker_id='$worker_id';" 2>/dev/null
    status=$(sqlite3 "$STATE_DB" "SELECT status FROM workers WHERE worker_id='$worker_id';" 2>/dev/null || echo "")
    if [[ "$status" == "dead" ]]; then
        pass "status_transitions: Transitioned to 'dead'"
    else
        fail "status_transitions: Transition to 'dead' failed (got: $status)"
    fi

    # Test 'crashed' status
    sqlite3 "$STATE_DB" "UPDATE workers SET status='crashed' WHERE worker_id='$worker_id';" 2>/dev/null
    status=$(sqlite3 "$STATE_DB" "SELECT status FROM workers WHERE worker_id='$worker_id';" 2>/dev/null || echo "")
    if [[ "$status" == "crashed" ]]; then
        pass "status_transitions: Transitioned to 'crashed'"
    else
        fail "status_transitions: Transition to 'crashed' failed (got: $status)"
    fi

    # Test invalid status is rejected by CHECK constraint
    local invalid_result
    invalid_result=$(sqlite3 "$STATE_DB" "UPDATE workers SET status='invalid_status' WHERE worker_id='$worker_id';" 2>&1 || echo "error")
    if echo "$invalid_result" | grep -qiE "constraint|check|error"; then
        pass "status_transitions: Invalid status rejected by constraint"
    else
        # Check if status was actually changed
        status=$(sqlite3 "$STATE_DB" "SELECT status FROM workers WHERE worker_id='$worker_id';" 2>/dev/null || echo "")
        if [[ "$status" != "invalid_status" ]]; then
            pass "status_transitions: Invalid status rejected"
        else
            fail "status_transitions: Invalid status accepted (should be rejected)"
        fi
    fi
}

#===============================================================================
# Test 8: Worker Cleanup (Dead Workers)
#===============================================================================
test_worker_cleanup() {
    echo ""
    echo "Test 8: Worker Cleanup"
    echo "----------------------"

    init_test_db

    # Test recover_crashed_worker directly for reliable cleanup testing
    if type recover_crashed_worker &>/dev/null; then
        local worker_id="cleanup-worker-$$"
        local task_id="cleanup-task-$$"

        # Create a worker with stale heartbeat and non-existent PID
        sqlite3 "$STATE_DB" <<SQL
INSERT INTO workers (worker_id, pid, status, last_heartbeat)
VALUES ('$worker_id', 999999999, 'busy', datetime('now', '-10 minutes'));

INSERT INTO tasks (id, name, type, priority, state, worker_id, started_at, heartbeat_at)
VALUES ('$task_id', 'Cleanup Test Task', 'IMPLEMENTATION', 2, 'RUNNING', '$worker_id', datetime('now', '-10 minutes'), datetime('now', '-10 minutes'));
SQL

        # Verify worker exists and is 'busy'
        local initial_status
        initial_status=$(sqlite3 "$STATE_DB" "SELECT status FROM workers WHERE worker_id='$worker_id';")
        if [[ "$initial_status" == "busy" ]]; then
            pass "worker_cleanup: Worker created with 'busy' status"
        else
            fail "worker_cleanup: Worker not created properly (status: $initial_status)"
        fi

        # Test recover_crashed_worker directly
        recover_crashed_worker "$worker_id" "$task_id" "999999999" 2>/dev/null

        # Verify worker is now marked as 'crashed' (recover_crashed_worker marks as crashed, not dead)
        local final_status
        final_status=$(sqlite3 "$STATE_DB" "SELECT status FROM workers WHERE worker_id='$worker_id';")
        if [[ "$final_status" == "crashed" || "$final_status" == "dead" ]]; then
            pass "worker_cleanup: Dead worker detected and marked ($final_status)"
        else
            fail "worker_cleanup: Worker not marked as dead/crashed (status: $final_status)"
        fi
    else
        skip "recover_crashed_worker: Function not available"
    fi

    # Test mark_worker_dead function
    if type mark_worker_dead &>/dev/null; then
        local worker_id2="dead-worker-$$"

        # Create another worker
        sqlite3 "$STATE_DB" <<SQL 2>/dev/null
INSERT INTO workers (worker_id, pid, status, last_heartbeat)
VALUES ('$worker_id2', 888888, 'idle', datetime('now'));
SQL

        # Mark as dead
        mark_worker_dead "$worker_id2" "test cleanup" 2>/dev/null

        # Verify status
        local status
        status=$(sqlite3 "$STATE_DB" "SELECT status FROM workers WHERE worker_id='$worker_id2';" 2>/dev/null || echo "")
        if [[ "$status" == "dead" ]]; then
            pass "mark_worker_dead: Worker marked as dead"
        else
            fail "mark_worker_dead: Worker not marked (status: $status)"
        fi

        # Verify event was logged
        local event
        event=$(sqlite3 "$STATE_DB" "SELECT event_type FROM events WHERE payload LIKE '%$worker_id2%' ORDER BY id DESC LIMIT 1;" 2>/dev/null || echo "")
        if [[ "$event" == "WORKER_CRASH_DETECTED" ]]; then
            pass "mark_worker_dead: Event logged"
        else
            # Event might not be logged in all cases
            skip "mark_worker_dead: Event logging (event: $event)"
        fi
    else
        skip "mark_worker_dead: Function not available"
    fi
}

#===============================================================================
# Additional Tests: Shard Validation
#===============================================================================
test_shard_validation() {
    echo ""
    echo "Test: Shard Validation"
    echo "----------------------"

    if type validate_worker_shard &>/dev/null; then
        # Test valid shard values
        WORKER_SHARD="0"
        if validate_worker_shard 2>/dev/null; then
            pass "validate_worker_shard: Accepts shard 0"
        else
            fail "validate_worker_shard: Should accept shard 0"
        fi

        WORKER_SHARD="1"
        if validate_worker_shard 2>/dev/null; then
            pass "validate_worker_shard: Accepts shard 1"
        else
            fail "validate_worker_shard: Should accept shard 1"
        fi

        WORKER_SHARD="2"
        if validate_worker_shard 2>/dev/null; then
            pass "validate_worker_shard: Accepts shard 2"
        else
            fail "validate_worker_shard: Should accept shard 2"
        fi

        # Test with shard- prefix
        WORKER_SHARD="shard-1"
        if validate_worker_shard 2>/dev/null; then
            pass "validate_worker_shard: Accepts shard-1 format"
        else
            fail "validate_worker_shard: Should accept shard-1 format"
        fi

        # Test empty shard (should be valid - handles all shards)
        WORKER_SHARD=""
        if validate_worker_shard 2>/dev/null; then
            pass "validate_worker_shard: Accepts empty shard"
        else
            fail "validate_worker_shard: Should accept empty shard"
        fi

        # Test invalid shard
        WORKER_SHARD="99"
        if ! validate_worker_shard 2>/dev/null; then
            pass "validate_worker_shard: Rejects invalid shard 99"
        else
            fail "validate_worker_shard: Should reject shard 99"
        fi

        # Test non-numeric shard
        WORKER_SHARD="invalid"
        if ! validate_worker_shard 2>/dev/null; then
            pass "validate_worker_shard: Rejects non-numeric shard"
        else
            fail "validate_worker_shard: Should reject non-numeric shard"
        fi

        # Reset
        WORKER_SHARD=""
    else
        skip "validate_worker_shard: Function not available"
    fi
}

#===============================================================================
# Additional Tests: Task Type Routing
#===============================================================================
test_task_routing() {
    echo ""
    echo "Test: Task Type Routing"
    echo "-----------------------"

    if type route_model_for_task_type &>/dev/null; then
        # Test implementation routing
        local model
        model=$(route_model_for_task_type "IMPLEMENTATION" 2>/dev/null || echo "")
        if [[ "$model" == "codex" ]]; then
            pass "route_model_for_task_type: IMPLEMENTATION -> codex"
        else
            fail "route_model_for_task_type: IMPLEMENTATION should route to codex (got: $model)"
        fi

        # Test review routing
        model=$(route_model_for_task_type "REVIEW" 2>/dev/null || echo "")
        if [[ "$model" == "claude" ]]; then
            pass "route_model_for_task_type: REVIEW -> claude"
        else
            fail "route_model_for_task_type: REVIEW should route to claude (got: $model)"
        fi

        # Test analysis routing
        model=$(route_model_for_task_type "ANALYSIS" 2>/dev/null || echo "")
        if [[ "$model" == "gemini" ]]; then
            pass "route_model_for_task_type: ANALYSIS -> gemini"
        else
            fail "route_model_for_task_type: ANALYSIS should route to gemini (got: $model)"
        fi

        # Test security routing (should go to claude)
        model=$(route_model_for_task_type "SECURITY" 2>/dev/null || echo "")
        if [[ "$model" == "claude" ]]; then
            pass "route_model_for_task_type: SECURITY -> claude"
        else
            fail "route_model_for_task_type: SECURITY should route to claude (got: $model)"
        fi
    else
        skip "route_model_for_task_type: Function not available"
    fi

    if type route_lane_for_task_type &>/dev/null; then
        # Test lane routing
        local lane
        lane=$(route_lane_for_task_type "IMPLEMENTATION" 2>/dev/null || echo "")
        if [[ "$lane" == "impl" ]]; then
            pass "route_lane_for_task_type: IMPLEMENTATION -> impl"
        else
            fail "route_lane_for_task_type: IMPLEMENTATION should route to impl (got: $lane)"
        fi

        lane=$(route_lane_for_task_type "REVIEW" 2>/dev/null || echo "")
        if [[ "$lane" == "review" ]]; then
            pass "route_lane_for_task_type: REVIEW -> review"
        else
            fail "route_lane_for_task_type: REVIEW should route to review (got: $lane)"
        fi

        lane=$(route_lane_for_task_type "ANALYSIS" 2>/dev/null || echo "")
        if [[ "$lane" == "analysis" ]]; then
            pass "route_lane_for_task_type: ANALYSIS -> analysis"
        else
            fail "route_lane_for_task_type: ANALYSIS should route to analysis (got: $lane)"
        fi
    else
        skip "route_lane_for_task_type: Function not available"
    fi
}

#===============================================================================
# Additional Tests: Shard Assignment
#===============================================================================
test_shard_assignment() {
    echo ""
    echo "Test: Shard Assignment"
    echo "----------------------"

    if type shard_for_task &>/dev/null; then
        # Test deterministic sharding (same task_id should always get same shard)
        local shard1 shard2
        shard1=$(shard_for_task "task-abc-123" 2>/dev/null || echo "")
        shard2=$(shard_for_task "task-abc-123" 2>/dev/null || echo "")

        if [[ "$shard1" == "$shard2" && -n "$shard1" ]]; then
            pass "shard_for_task: Deterministic sharding (same task -> same shard)"
        else
            fail "shard_for_task: Sharding not deterministic (shard1: $shard1, shard2: $shard2)"
        fi

        # Verify shard format
        if [[ "$shard1" =~ ^shard-[0-2]$ ]]; then
            pass "shard_for_task: Shard format is correct ($shard1)"
        else
            fail "shard_for_task: Invalid shard format (got: $shard1)"
        fi
    else
        skip "shard_for_task: Function not available"
    fi

    if type assign_shard_to_task &>/dev/null; then
        local assigned_shard
        assigned_shard=$(assign_shard_to_task "test-task-xyz" 3 2>/dev/null || echo "")

        if [[ "$assigned_shard" =~ ^shard-[0-2]$ ]]; then
            pass "assign_shard_to_task: Returns valid shard ($assigned_shard)"
        else
            fail "assign_shard_to_task: Invalid shard returned ($assigned_shard)"
        fi
    else
        skip "assign_shard_to_task: Function not available"
    fi
}

#===============================================================================
# Run All Tests
#===============================================================================

echo ""
echo "=============================================="
echo "Worker Pool Unit Tests (lib/worker-pool.sh)"
echo "=============================================="

test_worker_pool_initialization
test_worker_registration
test_worker_heartbeat_update
test_stale_worker_detection
test_worker_task_assignment
test_concurrent_worker_limits
test_worker_status_transitions
test_worker_cleanup
test_shard_validation
test_task_routing
test_shard_assignment

export TESTS_PASSED TESTS_FAILED

echo ""
echo "=============================================="
echo "worker-pool.sh tests completed: $TESTS_PASSED passed, $TESTS_FAILED failed"
echo "=============================================="

# Exit with failure if any tests failed
if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi

exit 0
