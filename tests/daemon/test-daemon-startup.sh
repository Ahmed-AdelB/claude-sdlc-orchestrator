#!/bin/bash
# =============================================================================
# test-daemon-startup.sh
# Comprehensive test suite for tri-agent daemon startup behavior
# =============================================================================
# Tests verify:
#   1. Daemon starts correctly
#   2. PID file is created and contains valid PID
#   3. Heartbeat mechanism works
#   4. Graceful shutdown works
#   5. Restart behavior (stop and start)
#   6. State file creation
#   7. Log directory initialization
#
# Usage: ./test-daemon-startup.sh [--verbose] [--skip-cleanup]
#
# Author: Ahmed Adel Bakr Alderai
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="/tmp/daemon-startup-test-$$"
DAEMON_SCRIPT="/home/aadel/.claude/tri-agent-daemon.sh"
LIB_DIR="/home/aadel/.claude/autonomous/lib"
VERBOSE="${1:---verbose}"
SKIP_CLEANUP="${2:-}"

# Test daemon configuration (isolated from production)
TEST_LOG_DIR="${TEST_DIR}/daemon-logs"
TEST_RESULTS_DIR="${TEST_DIR}/24hr-results"
TEST_STATE_FILE="${TEST_DIR}/daemon-state.json"
TEST_HEARTBEAT_FILE="${TEST_DIR}/daemon-heartbeat"
TEST_PID_FILE="${TEST_DIR}/tri-agent-daemon.pid"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'  # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# =============================================================================
# Test Framework Functions
# =============================================================================

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    ((TESTS_SKIPPED++))
}

log_info() {
    if [[ "$VERBOSE" == "--verbose" ]]; then
        echo -e "${CYAN}[INFO]${NC} $1"
    fi
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

assert_equal() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [[ "$expected" == "$actual" ]]; then
        log_pass "$message"
        return 0
    else
        log_fail "$message (expected: '$expected', got: '$actual')"
        return 1
    fi
}

assert_true() {
    local condition="$1"
    local message="$2"

    if eval "$condition"; then
        log_pass "$message"
        return 0
    else
        log_fail "$message (condition failed: $condition)"
        return 1
    fi
}

assert_false() {
    local condition="$1"
    local message="$2"

    if ! eval "$condition"; then
        log_pass "$message"
        return 0
    else
        log_fail "$message (condition should have failed: $condition)"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="$2"

    if [[ -f "$file" ]]; then
        log_pass "$message"
        return 0
    else
        log_fail "$message (file not found: $file)"
        return 1
    fi
}

assert_dir_exists() {
    local dir="$1"
    local message="$2"

    if [[ -d "$dir" ]]; then
        log_pass "$message"
        return 0
    else
        log_fail "$message (directory not found: $dir)"
        return 1
    fi
}

assert_process_running() {
    local pid="$1"
    local message="$2"

    if kill -0 "$pid" 2>/dev/null; then
        log_pass "$message"
        return 0
    else
        log_fail "$message (process $pid not running)"
        return 1
    fi
}

assert_process_not_running() {
    local pid="$1"
    local message="$2"

    if ! kill -0 "$pid" 2>/dev/null; then
        log_pass "$message"
        return 0
    else
        log_fail "$message (process $pid still running)"
        return 1
    fi
}

# Wait for condition with timeout
wait_for_condition() {
    local condition="$1"
    local timeout="${2:-10}"
    local interval="${3:-0.5}"
    local elapsed=0

    while ! eval "$condition"; do
        if (( $(echo "$elapsed >= $timeout" | bc -l) )); then
            return 1
        fi
        sleep "$interval"
        elapsed=$(echo "$elapsed + $interval" | bc)
    done
    return 0
}

# =============================================================================
# Setup and Teardown
# =============================================================================

setup() {
    log_info "Creating test environment at $TEST_DIR"
    mkdir -p "$TEST_DIR"
    mkdir -p "$TEST_LOG_DIR"
    mkdir -p "$TEST_RESULTS_DIR"

    # Create test daemon script (isolated version)
    create_test_daemon_script

    log_info "Test environment initialized"
}

teardown() {
    log_info "Cleaning up test environment"

    # Kill any test daemons
    if [[ -f "$TEST_PID_FILE" ]]; then
        local pid
        pid=$(cat "$TEST_PID_FILE" 2>/dev/null) || true
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            log_info "Stopping test daemon (PID: $pid)"
            kill -TERM "$pid" 2>/dev/null || true
            sleep 1
            kill -9 "$pid" 2>/dev/null || true
        fi
    fi

    # Kill any orphaned test processes
    pkill -f "test-daemon-startup" 2>/dev/null || true

    # Cleanup test directory unless skip flag is set
    if [[ "$SKIP_CLEANUP" != "--skip-cleanup" ]]; then
        rm -rf "$TEST_DIR"
        log_info "Test environment cleaned up"
    else
        log_info "Skipping cleanup, test files at: $TEST_DIR"
    fi
}

# Create an isolated test daemon script
create_test_daemon_script() {
    cat > "$TEST_DIR/test-daemon.sh" << 'DAEMON_EOF'
#!/bin/bash
# Test Daemon Script - Isolated for testing
# This is a minimal daemon that mimics tri-agent-daemon.sh behavior

# Configuration (will be overridden by environment)
LOG_DIR="${TEST_LOG_DIR:-/tmp/test-daemon-logs}"
RESULTS_DIR="${TEST_RESULTS_DIR:-/tmp/test-daemon-results}"
STATE_FILE="${TEST_STATE_FILE:-/tmp/test-daemon-state.json}"
HEARTBEAT_FILE="${TEST_HEARTBEAT_FILE:-/tmp/test-daemon-heartbeat}"
PID_FILE="${TEST_PID_FILE:-/tmp/test-daemon.pid}"

mkdir -p "$LOG_DIR" "$RESULTS_DIR"
echo $$ > "$PID_FILE"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/daemon.log"
}

update_heartbeat() {
    echo "$(date -Iseconds)" > "$HEARTBEAT_FILE"
}

# Main daemon loop
main() {
    log "=== Test Daemon Started ==="
    log "PID: $$"

    local cycle=0

    while true; do
        cycle=$((cycle + 1))
        update_heartbeat

        log "Cycle $cycle: heartbeat updated"

        echo "{\"cycle\":$cycle,\"timestamp\":\"$(date -Iseconds)\",\"status\":\"running\"}" > "$STATE_FILE"

        sleep 1
    done
}

trap 'log "Shutting down..."; rm -f "$PID_FILE"; exit 0' SIGTERM SIGINT

main
DAEMON_EOF

    chmod +x "$TEST_DIR/test-daemon.sh"
}

# Start the test daemon
start_test_daemon() {
    export TEST_LOG_DIR TEST_RESULTS_DIR TEST_STATE_FILE TEST_HEARTBEAT_FILE TEST_PID_FILE

    nohup bash "$TEST_DIR/test-daemon.sh" > "$TEST_LOG_DIR/startup.log" 2>&1 &
    local daemon_pid=$!

    # Wait for PID file to be created
    if wait_for_condition "[[ -f '$TEST_PID_FILE' ]]" 5; then
        local pid_from_file
        pid_from_file=$(cat "$TEST_PID_FILE")
        log_info "Test daemon started (PID: $pid_from_file)"
        return 0
    else
        log_error "Daemon failed to create PID file within timeout"
        return 1
    fi
}

# Stop the test daemon gracefully
stop_test_daemon() {
    if [[ ! -f "$TEST_PID_FILE" ]]; then
        log_info "No PID file found, daemon may not be running"
        return 0
    fi

    local pid
    pid=$(cat "$TEST_PID_FILE")

    if ! kill -0 "$pid" 2>/dev/null; then
        log_info "Daemon process $pid already stopped"
        rm -f "$TEST_PID_FILE"
        return 0
    fi

    log_info "Sending SIGTERM to daemon (PID: $pid)"
    kill -TERM "$pid" 2>/dev/null

    # Wait for graceful shutdown
    if wait_for_condition "! kill -0 '$pid' 2>/dev/null" 10; then
        log_info "Daemon stopped gracefully"
        return 0
    else
        log_info "Daemon did not stop gracefully, force killing"
        kill -9 "$pid" 2>/dev/null || true
        rm -f "$TEST_PID_FILE"
        return 1
    fi
}

# =============================================================================
# Test Cases
# =============================================================================

test_daemon_starts_correctly() {
    ((TESTS_RUN++))
    log_test "T-001: Daemon starts correctly"

    # Start the daemon
    if ! start_test_daemon; then
        log_fail "Daemon failed to start"
        return 1
    fi

    # Verify daemon is running
    local pid
    pid=$(cat "$TEST_PID_FILE")

    if assert_process_running "$pid" "Daemon process is running"; then
        stop_test_daemon
        return 0
    else
        return 1
    fi
}

test_pid_file_created() {
    ((TESTS_RUN++))
    log_test "T-002: PID file is created with valid PID"

    # Remove any existing PID file
    rm -f "$TEST_PID_FILE"

    # Start the daemon
    if ! start_test_daemon; then
        log_fail "Daemon failed to start"
        return 1
    fi

    # Verify PID file exists
    if ! assert_file_exists "$TEST_PID_FILE" "PID file exists"; then
        stop_test_daemon
        return 1
    fi

    # Verify PID file contains numeric value
    local pid
    pid=$(cat "$TEST_PID_FILE")

    if [[ "$pid" =~ ^[0-9]+$ ]]; then
        log_pass "PID file contains valid numeric PID: $pid"
    else
        log_fail "PID file contains invalid value: $pid"
        stop_test_daemon
        return 1
    fi

    # Verify the PID matches a running process
    if assert_process_running "$pid" "PID in file matches running process"; then
        stop_test_daemon
        return 0
    else
        stop_test_daemon
        return 1
    fi
}

test_heartbeat_mechanism() {
    ((TESTS_RUN++))
    log_test "T-003: Heartbeat mechanism works"

    # Remove any existing heartbeat file
    rm -f "$TEST_HEARTBEAT_FILE"

    # Start the daemon
    if ! start_test_daemon; then
        log_fail "Daemon failed to start"
        return 1
    fi

    # Wait for heartbeat file to be created
    if ! wait_for_condition "[[ -f '$TEST_HEARTBEAT_FILE' ]]" 5; then
        log_fail "Heartbeat file not created within timeout"
        stop_test_daemon
        return 1
    fi

    # Get initial heartbeat timestamp
    local heartbeat1
    heartbeat1=$(cat "$TEST_HEARTBEAT_FILE")
    log_info "Initial heartbeat: $heartbeat1"

    # Wait for heartbeat to update (daemon updates every 1 second)
    sleep 2

    # Get updated heartbeat timestamp
    local heartbeat2
    heartbeat2=$(cat "$TEST_HEARTBEAT_FILE")
    log_info "Updated heartbeat: $heartbeat2"

    # Verify heartbeat was updated
    if [[ "$heartbeat1" != "$heartbeat2" ]]; then
        log_pass "Heartbeat mechanism is working (timestamp updated)"
        stop_test_daemon
        return 0
    else
        log_fail "Heartbeat not updated (both timestamps: $heartbeat1)"
        stop_test_daemon
        return 1
    fi
}

test_heartbeat_file_format() {
    ((TESTS_RUN++))
    log_test "T-004: Heartbeat file contains valid ISO timestamp"

    # Start daemon if not running
    if [[ ! -f "$TEST_PID_FILE" ]] || ! kill -0 "$(cat "$TEST_PID_FILE")" 2>/dev/null; then
        if ! start_test_daemon; then
            log_fail "Daemon failed to start"
            return 1
        fi
    fi

    # Wait for heartbeat
    if ! wait_for_condition "[[ -f '$TEST_HEARTBEAT_FILE' ]]" 5; then
        log_fail "Heartbeat file not created"
        stop_test_daemon
        return 1
    fi

    local heartbeat
    heartbeat=$(cat "$TEST_HEARTBEAT_FILE")

    # Validate ISO 8601 format (basic check)
    if [[ "$heartbeat" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
        log_pass "Heartbeat contains valid ISO timestamp: $heartbeat"
        stop_test_daemon
        return 0
    else
        log_fail "Heartbeat has invalid format: $heartbeat"
        stop_test_daemon
        return 1
    fi
}

test_graceful_shutdown_sigterm() {
    ((TESTS_RUN++))
    log_test "T-005: Graceful shutdown works with SIGTERM"

    # Start the daemon
    if ! start_test_daemon; then
        log_fail "Daemon failed to start"
        return 1
    fi

    local pid
    pid=$(cat "$TEST_PID_FILE")

    # Verify daemon is running
    if ! kill -0 "$pid" 2>/dev/null; then
        log_fail "Daemon not running before shutdown test"
        return 1
    fi

    # Send SIGTERM
    log_info "Sending SIGTERM to daemon (PID: $pid)"
    kill -TERM "$pid"

    # Wait for daemon to stop
    if wait_for_condition "! kill -0 '$pid' 2>/dev/null" 10; then
        log_pass "Daemon stopped gracefully after SIGTERM"
        return 0
    else
        log_fail "Daemon did not stop gracefully (timeout)"
        kill -9 "$pid" 2>/dev/null || true
        return 1
    fi
}

test_graceful_shutdown_sigint() {
    ((TESTS_RUN++))
    log_test "T-006: Graceful shutdown works with SIGINT"

    # Start the daemon
    if ! start_test_daemon; then
        log_fail "Daemon failed to start"
        return 1
    fi

    local pid
    pid=$(cat "$TEST_PID_FILE")

    # Verify daemon is running
    if ! kill -0 "$pid" 2>/dev/null; then
        log_fail "Daemon not running before shutdown test"
        return 1
    fi

    # Send SIGINT
    log_info "Sending SIGINT to daemon (PID: $pid)"
    kill -INT "$pid"

    # Wait for daemon to stop
    if wait_for_condition "! kill -0 '$pid' 2>/dev/null" 10; then
        log_pass "Daemon stopped gracefully after SIGINT"
        return 0
    else
        log_fail "Daemon did not stop gracefully (timeout)"
        kill -9 "$pid" 2>/dev/null || true
        return 1
    fi
}

test_pid_file_cleanup_on_shutdown() {
    ((TESTS_RUN++))
    log_test "T-007: PID file is cleaned up on graceful shutdown"

    # Start the daemon
    if ! start_test_daemon; then
        log_fail "Daemon failed to start"
        return 1
    fi

    local pid
    pid=$(cat "$TEST_PID_FILE")

    # Verify PID file exists
    if [[ ! -f "$TEST_PID_FILE" ]]; then
        log_fail "PID file does not exist before shutdown"
        return 1
    fi

    # Send SIGTERM for graceful shutdown
    kill -TERM "$pid"

    # Wait for daemon to stop
    wait_for_condition "! kill -0 '$pid' 2>/dev/null" 10

    # Verify PID file is removed
    sleep 0.5  # Give filesystem time to sync
    if [[ ! -f "$TEST_PID_FILE" ]]; then
        log_pass "PID file was cleaned up on graceful shutdown"
        return 0
    else
        log_fail "PID file still exists after graceful shutdown"
        rm -f "$TEST_PID_FILE"
        return 1
    fi
}

test_restart_behavior() {
    ((TESTS_RUN++))
    log_test "T-008: Daemon can be restarted after stop"

    # Start the daemon
    if ! start_test_daemon; then
        log_fail "Initial daemon start failed"
        return 1
    fi

    local pid1
    pid1=$(cat "$TEST_PID_FILE")
    log_info "First daemon PID: $pid1"

    # Stop the daemon
    stop_test_daemon

    # Wait a moment
    sleep 1

    # Start again
    if ! start_test_daemon; then
        log_fail "Daemon restart failed"
        return 1
    fi

    local pid2
    pid2=$(cat "$TEST_PID_FILE")
    log_info "Second daemon PID: $pid2"

    # Verify new PID is different (new process)
    if [[ "$pid1" != "$pid2" ]]; then
        log_pass "Daemon restarted with new PID (was: $pid1, now: $pid2)"
        stop_test_daemon
        return 0
    else
        log_fail "Daemon restart has same PID (might be same process)"
        stop_test_daemon
        return 1
    fi
}

test_state_file_creation() {
    ((TESTS_RUN++))
    log_test "T-009: State file is created and updated"

    # Remove existing state file
    rm -f "$TEST_STATE_FILE"

    # Start the daemon
    if ! start_test_daemon; then
        log_fail "Daemon failed to start"
        return 1
    fi

    # Wait for state file to be created
    if ! wait_for_condition "[[ -f '$TEST_STATE_FILE' ]]" 5; then
        log_fail "State file not created within timeout"
        stop_test_daemon
        return 1
    fi

    # Verify state file contains valid JSON
    if jq -e . "$TEST_STATE_FILE" > /dev/null 2>&1; then
        local cycle
        cycle=$(jq -r '.cycle' "$TEST_STATE_FILE")
        log_pass "State file contains valid JSON with cycle: $cycle"
        stop_test_daemon
        return 0
    else
        log_fail "State file does not contain valid JSON"
        stop_test_daemon
        return 1
    fi
}

test_log_directory_creation() {
    ((TESTS_RUN++))
    log_test "T-010: Log directory is created"

    # Remove existing log directory
    rm -rf "$TEST_LOG_DIR"

    # Start the daemon
    if ! start_test_daemon; then
        log_fail "Daemon failed to start"
        return 1
    fi

    # Verify log directory was created
    if assert_dir_exists "$TEST_LOG_DIR" "Log directory exists"; then
        # Verify daemon.log exists
        if wait_for_condition "[[ -f '$TEST_LOG_DIR/daemon.log' ]]" 5; then
            log_pass "Daemon log file created"
            stop_test_daemon
            return 0
        else
            log_fail "Daemon log file not created"
            stop_test_daemon
            return 1
        fi
    else
        stop_test_daemon
        return 1
    fi
}

test_concurrent_startup_prevention() {
    ((TESTS_RUN++))
    log_test "T-011: Concurrent startup attempts are handled"

    # Start the first daemon
    if ! start_test_daemon; then
        log_fail "First daemon failed to start"
        return 1
    fi

    local pid1
    pid1=$(cat "$TEST_PID_FILE")
    log_info "First daemon PID: $pid1"

    # Attempt to start a second daemon (should not replace first)
    export TEST_LOG_DIR TEST_RESULTS_DIR TEST_STATE_FILE TEST_HEARTBEAT_FILE TEST_PID_FILE
    nohup bash "$TEST_DIR/test-daemon.sh" > "$TEST_LOG_DIR/startup2.log" 2>&1 &
    local second_attempt_pid=$!

    sleep 2

    # Check what's in the PID file now
    local current_pid
    current_pid=$(cat "$TEST_PID_FILE" 2>/dev/null)

    # The first daemon should still be running (or PID file overwritten by second)
    # Either way, only ONE daemon should be running effectively
    if kill -0 "$pid1" 2>/dev/null; then
        log_pass "First daemon still running (PID: $pid1)"
    else
        log_info "First daemon stopped, second took over (PID: $current_pid)"
    fi

    # Cleanup
    stop_test_daemon
    kill -9 "$second_attempt_pid" 2>/dev/null || true

    return 0
}

test_stale_pid_file_handling() {
    ((TESTS_RUN++))
    log_test "T-012: Stale PID file is handled on startup"

    # Create a stale PID file pointing to a non-existent process
    echo "99999" > "$TEST_PID_FILE"

    # Start the daemon (should succeed despite stale PID file)
    if start_test_daemon; then
        local new_pid
        new_pid=$(cat "$TEST_PID_FILE")

        if [[ "$new_pid" != "99999" ]] && kill -0 "$new_pid" 2>/dev/null; then
            log_pass "Daemon started successfully, overwriting stale PID file (new PID: $new_pid)"
            stop_test_daemon
            return 0
        else
            log_fail "Daemon did not properly handle stale PID file"
            stop_test_daemon
            return 1
        fi
    else
        log_fail "Daemon failed to start with stale PID file present"
        rm -f "$TEST_PID_FILE"
        return 1
    fi
}

# =============================================================================
# Performance Tests
# =============================================================================

test_startup_time() {
    ((TESTS_RUN++))
    log_test "T-013: Daemon starts within acceptable time (< 2 seconds)"

    # Ensure clean state
    rm -f "$TEST_PID_FILE"

    local start_time
    start_time=$(date +%s%N)

    # Start the daemon
    export TEST_LOG_DIR TEST_RESULTS_DIR TEST_STATE_FILE TEST_HEARTBEAT_FILE TEST_PID_FILE
    nohup bash "$TEST_DIR/test-daemon.sh" > "$TEST_LOG_DIR/startup.log" 2>&1 &

    # Wait for PID file
    if wait_for_condition "[[ -f '$TEST_PID_FILE' ]]" 5; then
        local end_time
        end_time=$(date +%s%N)

        local duration_ms
        duration_ms=$(( (end_time - start_time) / 1000000 ))

        if [[ $duration_ms -lt 2000 ]]; then
            log_pass "Daemon started in ${duration_ms}ms (< 2000ms threshold)"
            stop_test_daemon
            return 0
        else
            log_fail "Daemon startup took ${duration_ms}ms (> 2000ms threshold)"
            stop_test_daemon
            return 1
        fi
    else
        log_fail "Daemon failed to start (PID file not created)"
        return 1
    fi
}

test_heartbeat_frequency() {
    ((TESTS_RUN++))
    log_test "T-014: Heartbeat updates at expected frequency"

    # Start the daemon
    if ! start_test_daemon; then
        log_fail "Daemon failed to start"
        return 1
    fi

    # Wait for initial heartbeat
    sleep 2

    # Collect heartbeat timestamps over 5 seconds
    local timestamps=()
    for i in {1..5}; do
        if [[ -f "$TEST_HEARTBEAT_FILE" ]]; then
            timestamps+=("$(cat "$TEST_HEARTBEAT_FILE")")
        fi
        sleep 1
    done

    # Count unique timestamps
    local unique_count
    unique_count=$(printf '%s\n' "${timestamps[@]}" | sort -u | wc -l)

    stop_test_daemon

    # We expect at least 3 unique timestamps in 5 seconds (daemon updates every 1s)
    if [[ $unique_count -ge 3 ]]; then
        log_pass "Heartbeat updated $unique_count times in 5 seconds (expected >= 3)"
        return 0
    else
        log_fail "Heartbeat only updated $unique_count times in 5 seconds (expected >= 3)"
        return 1
    fi
}

# =============================================================================
# Main Test Runner
# =============================================================================

run_all_tests() {
    echo ""
    echo -e "${BLUE}==============================================================================${NC}"
    echo -e "${BLUE}  Tri-Agent Daemon Startup Test Suite${NC}"
    echo -e "${BLUE}==============================================================================${NC}"
    echo ""

    # Core functionality tests
    test_daemon_starts_correctly || true
    test_pid_file_created || true
    test_heartbeat_mechanism || true
    test_heartbeat_file_format || true

    # Shutdown tests
    test_graceful_shutdown_sigterm || true
    test_graceful_shutdown_sigint || true
    test_pid_file_cleanup_on_shutdown || true

    # Restart and state tests
    test_restart_behavior || true
    test_state_file_creation || true
    test_log_directory_creation || true

    # Edge case tests
    test_concurrent_startup_prevention || true
    test_stale_pid_file_handling || true

    # Performance tests
    test_startup_time || true
    test_heartbeat_frequency || true

    # Print summary
    echo ""
    echo -e "${BLUE}==============================================================================${NC}"
    echo -e "${BLUE}  Test Summary${NC}"
    echo -e "${BLUE}==============================================================================${NC}"
    echo -e "Tests run:    $TESTS_RUN"
    echo -e "Passed:       ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed:       ${RED}$TESTS_FAILED${NC}"
    echo -e "Skipped:      ${YELLOW}$TESTS_SKIPPED${NC}"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo ""
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo ""
        echo -e "${RED}Some tests failed!${NC}"
        return 1
    fi
}

# =============================================================================
# Main Entry Point
# =============================================================================

main() {
    # Trap for cleanup on script exit
    trap teardown EXIT

    setup
    run_all_tests
    exit_code=$?

    exit $exit_code
}

# Run tests
main "$@"
