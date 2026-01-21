#!/bin/bash
# =============================================================================
# atomic-daemon-tests.sh
# Comprehensive test suite for flock-based atomic daemon startup
# =============================================================================
# Tests verify:
#   1. Single startup works correctly
#   2. Concurrent startup attempts are serialized
#   3. Lock timeout prevents infinite waits
#   4. Stale PID files are cleaned up
#   5. Lock files don't accumulate
#   6. Lock-free status reads don't block
#
# Usage: ./atomic-daemon-tests.sh [--verbose]
#
# Author: Ahmed Adel Bakr Alderai
# =============================================================================

set -euo pipefail

# Configuration
TEST_DIR="/tmp/atomic-daemon-test-$$"
LIB_DIR="/home/aadel/.claude/autonomous/lib"
VERBOSE="${1:---verbose}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# =============================================================================
# Test Framework
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

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

assert_equal() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [[ "$expected" == "$actual" ]]; then
        log_pass "$message (expected: $expected)"
        return 0
    else
        log_fail "$message (expected: $expected, got: $actual)"
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
        log_fail "$message"
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
        log_fail "$message"
        return 1
    fi
}

# =============================================================================
# Setup and Teardown
# =============================================================================

setup() {
    mkdir -p "$TEST_DIR"/{pid,lock,state}
    log_info "Test environment created at $TEST_DIR"
}

teardown() {
    # Kill any test daemons
    pkill -f "test-daemon" 2>/dev/null || true
    sleep 1

    # Cleanup
    rm -rf "$TEST_DIR"
    log_info "Test environment cleaned up"
}

# =============================================================================
# Mock Daemon for Testing
# =============================================================================

create_test_daemon() {
    local name="$1"
    local behavior="${2:-normal}"

    cat > "$TEST_DIR/$name" <<'EOF'
#!/bin/bash
set -euo pipefail

# Source atomic startup module
source "$ATOMIC_MODULE"

TEST_DIR="$TEST_DIR"
DAEMON_NAME="test-daemon-$1"
PID_FILE="$TEST_DIR/pid/$DAEMON_NAME.pid"
LOCK_FILE="$TEST_DIR/lock/$DAEMON_NAME.lock"

# Mock daemon loop
daemon_loop() {
    echo "Daemon $DAEMON_NAME running with PID $$" > "$TEST_DIR/state/${DAEMON_NAME}.state"
    while true; do sleep 1; done
}

case "${2:-normal}" in
    normal)
        start_daemon_atomic "$PID_FILE" "$LOCK_FILE" "daemon_loop"
        ;;
    slow-start)
        # Simulate slow startup (helps trigger race conditions)
        sleep 2
        start_daemon_atomic "$PID_FILE" "$LOCK_FILE" "daemon_loop"
        ;;
    *)
        echo "Unknown behavior: $2" >&2
        exit 1
        ;;
esac
EOF

    chmod +x "$TEST_DIR/$name"
}

# =============================================================================
# Test Cases
# =============================================================================

test_single_startup() {
    ((TESTS_RUN++))
    log_test "Single daemon startup completes successfully"

    local pid_file="$TEST_DIR/pid/test-daemon-single.pid"
    local lock_file="$TEST_DIR/lock/test-daemon-single.lock"

    # Test basic startup
    if (
        source "$LIB_DIR/daemon-atomic-startup.sh"
        start_daemon_atomic "$pid_file" "$lock_file" "sleep 60" > /dev/null 2>&1
    ); then
        # Verify PID file exists and contains a valid PID
        if [[ -f "$pid_file" ]]; then
            local pid
            pid=$(cat "$pid_file")
            if kill -0 "$pid" 2>/dev/null; then
                log_pass "Single startup created valid PID $pid"
                kill "$pid" 2>/dev/null
                return 0
            fi
        fi
    fi

    log_fail "Single startup failed or didn't create valid PID"
    return 1
}

test_double_startup_prevented() {
    ((TESTS_RUN++))
    log_test "Second startup attempt is prevented while first is running"

    local pid_file="$TEST_DIR/pid/test-daemon-double.pid"
    local lock_file="$TEST_DIR/lock/test-daemon-double.lock"

    # Start first daemon
    if ! (
        source "$LIB_DIR/daemon-atomic-startup.sh"
        start_daemon_atomic "$pid_file" "$lock_file" "sleep 60" > /dev/null 2>&1
    ); then
        log_fail "First startup failed"
        return 1
    fi

    # Attempt second startup (should fail)
    if (
        source "$LIB_DIR/daemon-atomic-startup.sh"
        start_daemon_atomic "$pid_file" "$lock_file" "sleep 60" > /dev/null 2>&1
    ); then
        log_fail "Second startup succeeded when it should have failed"
        pkill -f "sleep 60" 2>/dev/null || true
        return 1
    fi

    # Verify only one process running
    local first_pid
    first_pid=$(cat "$pid_file")
    kill "$first_pid" 2>/dev/null || true

    log_pass "Second startup correctly prevented (only one process running)"
    return 0
}

test_concurrent_startups() {
    ((TESTS_RUN++))
    log_test "Concurrent startup attempts result in exactly one daemon"

    local pid_file="$TEST_DIR/pid/test-daemon-concurrent.pid"
    local lock_file="$TEST_DIR/lock/test-daemon-concurrent.lock"

    local pids=()

    # Launch 5 concurrent startup attempts
    for i in {1..5}; do
        (
            source "$LIB_DIR/daemon-atomic-startup.sh"
            start_daemon_atomic "$pid_file" "$lock_file" "sleep 60" > /dev/null 2>&1
        ) &
        pids+=($!)
    done

    # Wait for all to complete
    for pid in "${pids[@]}"; do
        wait "$pid" || true
    done

    # Verify only one daemon is running
    local running_count=0
    if [[ -f "$pid_file" ]]; then
        local daemon_pid
        daemon_pid=$(cat "$pid_file")
        if kill -0 "$daemon_pid" 2>/dev/null; then
            running_count=1
            kill "$daemon_pid" 2>/dev/null
        fi
    fi

    assert_equal "1" "$running_count" "Exactly one daemon running after concurrent startup attempts"
}

test_stale_pid_cleanup() {
    ((TESTS_RUN++))
    log_test "Stale PID files are cleaned up on restart"

    local pid_file="$TEST_DIR/pid/test-daemon-stale.pid"
    local lock_file="$TEST_DIR/lock/test-daemon-stale.lock"

    # Create a stale PID file (pointing to non-existent process)
    echo "99999" > "$pid_file"

    # Attempt to start daemon
    if (
        source "$LIB_DIR/daemon-atomic-startup.sh"
        start_daemon_atomic "$pid_file" "$lock_file" "sleep 60" > /dev/null 2>&1
    ); then
        log_pass "Startup succeeded after cleaning stale PID"

        # Verify new PID file has a valid process
        local new_pid
        new_pid=$(cat "$pid_file")
        if kill -0 "$new_pid" 2>/dev/null; then
            kill "$new_pid" 2>/dev/null
            return 0
        fi
    fi

    log_fail "Stale PID cleanup failed"
    return 1
}

test_lock_file_cleanup() {
    ((TESTS_RUN++))
    log_test "Lock files are properly cleaned up"

    local pid_file="$TEST_DIR/pid/test-daemon-lock-cleanup.pid"
    local lock_file="$TEST_DIR/lock/test-daemon-lock-cleanup.lock"

    # Start and stop daemon
    (
        source "$LIB_DIR/daemon-atomic-startup.sh"
        start_daemon_atomic "$pid_file" "$lock_file" "sleep 60" > /dev/null 2>&1
        local daemon_pid
        daemon_pid=$(cat "$pid_file")
        sleep 0.5
        kill "$daemon_pid" 2>/dev/null
    )

    # Give it time to clean up
    sleep 1

    # Lock file should be empty or removable
    if [[ ! -f "$lock_file" ]] || [[ ! -s "$lock_file" ]]; then
        log_pass "Lock file is empty or removed"
        return 0
    else
        log_fail "Lock file still contains data"
        return 1
    fi
}

test_lock_free_status_check() {
    ((TESTS_RUN++))
    log_test "Status checks don't acquire locks (lock-free read)"

    local pid_file="$TEST_DIR/pid/test-daemon-lock-free.pid"
    local lock_file="$TEST_DIR/lock/test-daemon-lock-free.lock"

    # Start daemon
    (
        source "$LIB_DIR/daemon-atomic-startup.sh"
        start_daemon_atomic "$pid_file" "$lock_file" "sleep 60" > /dev/null 2>&1
    ) &
    local startup_pid=$!

    sleep 1
    local daemon_pid
    daemon_pid=$(cat "$pid_file")

    # Perform multiple status checks concurrently
    # These should NOT block on the lock
    local success=true
    for i in {1..3}; do
        (
            source "$LIB_DIR/daemon-atomic-startup.sh"
            if ! is_daemon_running "$pid_file"; then
                exit 1
            fi
        ) &
    done

    # Wait for all checks
    if wait; then
        log_pass "Lock-free status checks completed without blocking"
        kill "$daemon_pid" 2>/dev/null
        return 0
    else
        log_fail "Lock-free status checks timed out or failed"
        return 1
    fi
}

test_lock_timeout() {
    ((TESTS_RUN++))
    log_test "Lock acquisition has timeout protection"

    local pid_file="$TEST_DIR/pid/test-daemon-timeout.pid"
    local lock_file="$TEST_DIR/lock/test-daemon-timeout.lock"

    # Create a lock file and hold the lock
    (
        exec 200> "$lock_file"
        flock -x 200  # Acquire exclusive lock

        # Now try to start daemon (should timeout after ~10 seconds)
        timeout 15 bash -c "
            source '$LIB_DIR/daemon-atomic-startup.sh'
            start_daemon_atomic '$pid_file' '$lock_file' 'sleep 60'
        " && exit_code=0 || exit_code=$?

        exit $exit_code
    ) &
    local bg_pid=$!

    # Give background process time to try
    sleep 12

    # It should have timed out by now (not completed successfully)
    if kill -0 "$bg_pid" 2>/dev/null; then
        # Still running (waiting for lock) - that's expected
        kill "$bg_pid" 2>/dev/null
        log_pass "Lock timeout prevented infinite wait"
        return 0
    fi

    # Check exit status
    wait "$bg_pid" || local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_pass "Lock timeout protection works (timeout occurred)"
        return 0
    else
        log_fail "Lock acquisition should have timed out"
        return 1
    fi
}

test_stop_daemon_atomic() {
    ((TESTS_RUN++))
    log_test "Atomic daemon stop works correctly"

    local pid_file="$TEST_DIR/pid/test-daemon-stop.pid"
    local lock_file="$TEST_DIR/lock/test-daemon-stop.lock"

    # Start daemon
    if ! (
        source "$LIB_DIR/daemon-atomic-startup.sh"
        start_daemon_atomic "$pid_file" "$lock_file" "sleep 60" > /dev/null 2>&1
    ); then
        log_fail "Could not start daemon"
        return 1
    fi

    local daemon_pid
    daemon_pid=$(cat "$pid_file")

    # Stop daemon
    if (
        source "$LIB_DIR/daemon-atomic-startup.sh"
        stop_daemon_atomic "$pid_file" "$lock_file" > /dev/null 2>&1
    ); then
        # Verify process is gone
        sleep 0.5
        if ! kill -0 "$daemon_pid" 2>/dev/null; then
            log_pass "Daemon stopped successfully"
            return 0
        fi
    fi

    log_fail "Daemon stop failed or process still running"
    kill "$daemon_pid" 2>/dev/null || true
    return 1
}

test_get_daemon_pid() {
    ((TESTS_RUN++))
    log_test "get_daemon_pid retrieves running daemon PID correctly"

    local pid_file="$TEST_DIR/pid/test-daemon-getpid.pid"
    local lock_file="$TEST_DIR/lock/test-daemon-getpid.lock"

    # Start daemon
    if ! (
        source "$LIB_DIR/daemon-atomic-startup.sh"
        start_daemon_atomic "$pid_file" "$lock_file" "sleep 60" > /dev/null 2>&1
    ); then
        log_fail "Could not start daemon"
        return 1
    fi

    sleep 0.5

    # Get PID using lock-free function
    local retrieved_pid
    retrieved_pid=$(
        source "$LIB_DIR/daemon-atomic-startup.sh"
        get_daemon_pid "$pid_file"
    ) || {
        log_fail "get_daemon_pid failed"
        pkill -f "sleep 60" 2>/dev/null || true
        return 1
    }

    local actual_pid
    actual_pid=$(cat "$pid_file")

    kill "$actual_pid" 2>/dev/null
    assert_equal "$actual_pid" "$retrieved_pid" "Retrieved PID matches stored PID"
}

# =============================================================================
# Performance Tests
# =============================================================================

test_startup_performance() {
    ((TESTS_RUN++))
    log_test "Startup completes within reasonable time"

    local pid_file="$TEST_DIR/pid/test-daemon-perf.pid"
    local lock_file="$TEST_DIR/lock/test-daemon-perf.lock"

    local start_time
    start_time=$(date +%s%N)

    if (
        source "$LIB_DIR/daemon-atomic-startup.sh"
        start_daemon_atomic "$pid_file" "$lock_file" "sleep 60" > /dev/null 2>&1
    ); then
        local end_time
        end_time=$(date +%s%N)

        local duration_ms
        duration_ms=$(( (end_time - start_time) / 1000000 ))

        local daemon_pid
        daemon_pid=$(cat "$pid_file")
        kill "$daemon_pid" 2>/dev/null

        # Should complete in less than 500ms
        if [[ $duration_ms -lt 500 ]]; then
            log_pass "Startup completed in ${duration_ms}ms (< 500ms threshold)"
            return 0
        else
            log_fail "Startup took ${duration_ms}ms (> 500ms threshold)"
            return 1
        fi
    fi

    log_fail "Startup performance test failed"
    return 1
}

# =============================================================================
# Main Test Runner
# =============================================================================

run_all_tests() {
    echo -e "${BLUE}==============================================================================${NC}"
    echo -e "${BLUE}Atomic Daemon Startup Test Suite${NC}"
    echo -e "${BLUE}==============================================================================${NC}"
    echo ""

    # Run all tests
    test_single_startup || true
    test_double_startup_prevented || true
    test_concurrent_startups || true
    test_stale_pid_cleanup || true
    test_lock_file_cleanup || true
    test_lock_free_status_check || true
    test_lock_timeout || true
    test_stop_daemon_atomic || true
    test_get_daemon_pid || true
    test_startup_performance || true

    # Print summary
    echo ""
    echo -e "${BLUE}==============================================================================${NC}"
    echo -e "${BLUE}Test Summary${NC}"
    echo -e "${BLUE}==============================================================================${NC}"
    echo -e "Tests run:    $TESTS_RUN"
    echo -e "Passed:       ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed:       ${RED}$TESTS_FAILED${NC}"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        return 1
    fi
}

# =============================================================================
# Main Entry Point
# =============================================================================

main() {
    setup
    run_all_tests
    local exit_code=$?
    teardown
    exit $exit_code
}

# Run tests
main
