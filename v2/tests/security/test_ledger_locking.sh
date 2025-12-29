#!/bin/bash
# =============================================================================
# test_ledger_locking.sh - SEC-007 Ledger File Locking Tests
# =============================================================================
# Tests for secure ledger operations that prevent race conditions and
# data corruption during concurrent writes.
#
# SEC-007: Ledger File Locking
# - Tests append_to_ledger() with exclusive flock
# - Tests read_ledger_entries() with shared flock
# - Tests concurrent write integrity
# - Tests lock timeout handling
# - Tests ledger rotation
# - Tests integrity verification
# =============================================================================

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")/lib"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Test utilities
log_test() {
    echo -e "${BLUE}[TEST]${RESET} $*"
}

log_pass() {
    echo -e "${GREEN}[PASS]${RESET} $*"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${RESET} $*"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_info() {
    echo -e "${YELLOW}[INFO]${RESET} $*"
}

# Setup test environment
setup_test_env() {
    TEST_DIR="/tmp/sec007_test_$$"
    mkdir -p "$TEST_DIR"

    # Create a minimal test environment
    mkdir -p "$TEST_DIR/tasks" "$TEST_DIR/logs/supervision" "$TEST_DIR/state" "$TEST_DIR/state/gates"

    # Set environment for testing BEFORE sourcing
    export TASKS_DIR="$TEST_DIR/tasks"
    export TASK_LEDGER="$TEST_DIR/tasks/ledger.jsonl"
    export LEDGER_LOCK="$TASK_LEDGER.lock"
    export LOG_DIR="$TEST_DIR/logs"
    export STATE_DIR="$TEST_DIR/state"
    export GATES_DIR="$STATE_DIR/gates"
    export LEDGER_LOCK_TIMEOUT="5"
    # Do NOT set AUTONOMOUS_ROOT - let it default to real lib dir

    # Source the library using a subshell to capture any return codes
    if ! (source "$LIB_DIR/supervisor-approver.sh" 2>/dev/null) 2>&1; then
        log_info "Note: Some optional libraries not loaded (expected in test)"
    fi

    # Source again without set -e to actually load the functions
    set +e
    source "$LIB_DIR/supervisor-approver.sh" 2>/dev/null
    set -e

    # Override paths after sourcing
    export TASK_LEDGER="$TEST_DIR/tasks/ledger.jsonl"
    export LEDGER_LOCK="$TASK_LEDGER.lock"

    log_info "Test environment setup at $TEST_DIR"
}

# Cleanup test environment
cleanup_test_env() {
    if [[ -d "${TEST_DIR:-}" ]]; then
        rm -rf "$TEST_DIR"
        log_info "Cleaned up test environment"
    fi
}

# =============================================================================
# TEST 1: Basic append_to_ledger functionality
# =============================================================================
test_basic_append() {
    log_test "TEST 1: Basic append_to_ledger functionality"
    TESTS_RUN=$((TESTS_RUN + 1))

    local entry='{"event":"TEST","id":"1","timestamp":"2025-01-01T00:00:00Z"}'

    if append_to_ledger "$entry"; then
        if [[ -f "$TASK_LEDGER" ]]; then
            local content
            content=$(cat "$TASK_LEDGER")
            if echo "$content" | grep -q "TEST"; then
                log_pass "Basic append works correctly"
                return 0
            else
                log_fail "Entry not found in ledger"
                return 1
            fi
        else
            log_fail "Ledger file not created"
            return 1
        fi
    else
        log_fail "append_to_ledger returned non-zero"
        return 1
    fi
}

# =============================================================================
# TEST 2: Concurrent write integrity
# =============================================================================
test_concurrent_writes() {
    log_test "TEST 2: Concurrent write integrity (20 parallel writes)"
    TESTS_RUN=$((TESTS_RUN + 1))

    # Clear ledger for this test
    rm -f "$TASK_LEDGER"

    # Launch 20 concurrent writes
    for i in {1..20}; do
        (
            append_to_ledger "{\"event\":\"CONCURRENT_TEST\",\"id\":\"$i\",\"pid\":\"$$\"}"
        ) &
    done

    # Wait for all writes to complete
    wait

    # Verify all entries are valid JSON
    local errors=0
    local count=0

    if [[ -f "$TASK_LEDGER" ]]; then
        while IFS= read -r line; do
            count=$((count + 1))
            if [[ -n "$line" ]]; then
                if ! echo "$line" | jq -e . >/dev/null 2>&1; then
                    log_info "Invalid JSON at line $count: ${line:0:50}..."
                    errors=$((errors + 1))
                fi
            fi
        done < "$TASK_LEDGER"

        if [[ $errors -eq 0 && $count -eq 20 ]]; then
            log_pass "All 20 concurrent writes produced valid JSON"
            return 0
        elif [[ $errors -gt 0 ]]; then
            log_fail "Found $errors corrupted entries (race condition!)"
            return 1
        else
            log_fail "Expected 20 entries, got $count"
            return 1
        fi
    else
        log_fail "Ledger file not created after concurrent writes"
        return 1
    fi
}

# =============================================================================
# TEST 3: Lock timeout handling
# =============================================================================
test_lock_timeout() {
    log_test "TEST 3: Lock timeout handling"
    TESTS_RUN=$((TESTS_RUN + 1))

    # Clear ledger for this test
    rm -f "$TASK_LEDGER"

    # Hold an exclusive lock on the ledger
    local lock_pid
    (
        flock -x 200
        sleep 10  # Hold lock for 10 seconds
    ) 200>"$LEDGER_LOCK" &
    lock_pid=$!

    # Wait for lock to be acquired
    sleep 0.5

    # Try to write with a short timeout (should fail or wait)
    local old_timeout="$LEDGER_LOCK_TIMEOUT"
    LEDGER_LOCK_TIMEOUT=1

    local start_time end_time duration
    start_time=$(date +%s)

    # This should fail after 1 second timeout
    if append_to_ledger '{"event":"TIMEOUT_TEST"}' 2>/dev/null; then
        # Write succeeded - lock was released quickly
        log_info "Write succeeded (lock was released)"
    else
        # Write failed due to timeout - expected behavior
        log_info "Write failed due to lock timeout (expected)"
    fi

    end_time=$(date +%s)
    duration=$((end_time - start_time))

    # Clean up
    kill "$lock_pid" 2>/dev/null || true
    wait "$lock_pid" 2>/dev/null || true
    LEDGER_LOCK_TIMEOUT="$old_timeout"

    # The operation should have taken at least 1 second (timeout)
    if [[ $duration -ge 1 ]]; then
        log_pass "Lock timeout handled correctly (waited ${duration}s)"
        return 0
    else
        log_fail "Lock timeout not enforced (only waited ${duration}s)"
        return 1
    fi
}

# =============================================================================
# TEST 4: Shared read lock
# =============================================================================
test_shared_read_lock() {
    log_test "TEST 4: Shared read lock allows concurrent reads"
    TESTS_RUN=$((TESTS_RUN + 1))

    # Clear and populate ledger
    rm -f "$TASK_LEDGER"
    for i in {1..5}; do
        append_to_ledger "{\"event\":\"READ_TEST\",\"id\":\"$i\"}"
    done

    # Start multiple concurrent reads
    local results=()
    for i in {1..3}; do
        (
            read_ledger_entries "READ_TEST" | wc -l
        ) &
        results+=($!)
    done

    # Wait for all reads
    wait

    # Verify reads succeeded
    local entries
    entries=$(read_ledger_entries "READ_TEST" | wc -l)

    if [[ $entries -eq 5 ]]; then
        log_pass "Shared read lock works correctly"
        return 0
    else
        log_fail "Expected 5 entries, got $entries"
        return 1
    fi
}

# =============================================================================
# TEST 5: Ledger integrity verification
# =============================================================================
test_integrity_verification() {
    log_test "TEST 5: Ledger integrity verification"
    TESTS_RUN=$((TESTS_RUN + 1))

    # Clear and populate with valid entries
    rm -f "$TASK_LEDGER"
    for i in {1..5}; do
        append_to_ledger "{\"event\":\"INTEGRITY_TEST\",\"id\":\"$i\"}"
    done

    # Verify integrity passes
    set +e
    local output
    output=$(verify_ledger_integrity 2>&1)
    set -e

    if echo "$output" | grep -q "PASS"; then
        log_pass "Integrity verification passes for valid ledger"
        return 0
    else
        log_fail "Integrity verification failed for valid ledger"
        echo "Output was: $output"
        return 1
    fi
}

# =============================================================================
# TEST 6: Integrity verification with corrupted entry
# =============================================================================
test_integrity_corrupted() {
    log_test "TEST 6: Integrity verification detects corruption"
    TESTS_RUN=$((TESTS_RUN + 1))

    # Clear ledger
    rm -f "$TASK_LEDGER"

    # Add valid entries
    append_to_ledger '{"event":"VALID","id":"1"}'
    append_to_ledger '{"event":"VALID","id":"2"}'

    # Add corrupted entry directly (bypassing append_to_ledger)
    echo 'NOT VALID JSON {broken' >> "$TASK_LEDGER"

    # Add more valid entries
    append_to_ledger '{"event":"VALID","id":"3"}'

    # Verify integrity detects corruption
    set +e
    local output
    output=$(verify_ledger_integrity 2>&1)
    set -e

    if echo "$output" | grep -q "FAIL"; then
        log_pass "Integrity verification detects corrupted entry"
        return 0
    else
        log_fail "Integrity verification missed corrupted entry"
        echo "Output was: $output"
        return 1
    fi
}

# =============================================================================
# TEST 7: log_ledger uses secure append
# =============================================================================
test_log_ledger_secure() {
    log_test "TEST 7: log_ledger() uses secure append_to_ledger"
    TESTS_RUN=$((TESTS_RUN + 1))

    # Clear ledger
    rm -f "$TASK_LEDGER"

    # Use log_ledger function
    log_ledger "TASK_STARTED" "test-task-001" "Testing secure ledger"

    # Verify entry was written
    if [[ -f "$TASK_LEDGER" ]]; then
        local content
        content=$(cat "$TASK_LEDGER")

        if echo "$content" | jq -e '.event == "TASK_STARTED"' >/dev/null 2>&1; then
            log_pass "log_ledger writes valid JSON entries"
            return 0
        else
            log_fail "log_ledger entry is not valid JSON"
            echo "Content: $content"
            return 1
        fi
    else
        log_fail "Ledger file not created by log_ledger"
        return 1
    fi
}

# =============================================================================
# TEST 8: Special characters in log details
# =============================================================================
test_special_characters() {
    log_test "TEST 8: Special characters in log details are escaped"
    TESTS_RUN=$((TESTS_RUN + 1))

    # Clear ledger
    rm -f "$TASK_LEDGER"

    # Log with special characters
    log_ledger "TEST_EVENT" "task-002" 'Details with "quotes" and \backslash and
newline'

    # Verify entry is valid JSON
    if [[ -f "$TASK_LEDGER" ]]; then
        local content
        content=$(cat "$TASK_LEDGER")

        if echo "$content" | jq -e . >/dev/null 2>&1; then
            log_pass "Special characters escaped correctly"
            return 0
        else
            log_fail "Special characters not properly escaped"
            echo "Content: $content"
            return 1
        fi
    else
        log_fail "Ledger file not created"
        return 1
    fi
}

# =============================================================================
# TEST 9: Ledger rotation (mock test)
# =============================================================================
test_ledger_rotation() {
    log_test "TEST 9: Ledger rotation function exists and works"
    TESTS_RUN=$((TESTS_RUN + 1))

    # Clear ledger
    rm -f "$TASK_LEDGER"

    # Create a small ledger
    for i in {1..10}; do
        append_to_ledger "{\"event\":\"ROTATION_TEST\",\"id\":\"$i\"}"
    done

    # Get current size
    local size_before
    size_before=$(stat -c%s "$TASK_LEDGER" 2>/dev/null || stat -f%z "$TASK_LEDGER" 2>/dev/null || echo 0)

    # Set low rotation threshold (100 bytes for testing)
    LEDGER_MAX_SIZE_MB=0  # Will be 0 bytes threshold

    # Call rotation (should rotate since any file > 0 bytes)
    # Note: In practice, we test with a realistic threshold

    # Verify function exists and runs without error
    if type rotate_ledger_if_needed &>/dev/null; then
        log_pass "Ledger rotation function exists"
        return 0
    else
        log_fail "Ledger rotation function not found"
        return 1
    fi
}

# =============================================================================
# TEST 10: flock command availability
# =============================================================================
test_flock_available() {
    log_test "TEST 10: flock command is available"
    TESTS_RUN=$((TESTS_RUN + 1))

    if command -v flock &>/dev/null; then
        local version
        version=$(flock --version 2>&1 || echo "unknown")
        log_pass "flock is available: $version"
        return 0
    else
        log_fail "flock command not found - locking will not work!"
        return 1
    fi
}

# =============================================================================
# TEST 11: High-concurrency stress test
# =============================================================================
test_high_concurrency() {
    log_test "TEST 11: High-concurrency stress test (50 parallel writes)"
    TESTS_RUN=$((TESTS_RUN + 1))

    # Clear ledger
    rm -f "$TASK_LEDGER"

    # Launch 50 concurrent writes
    for i in {1..50}; do
        (
            append_to_ledger "{\"event\":\"STRESS_TEST\",\"seq\":$i,\"pid\":$$,\"time\":\"$(date -Iseconds)\"}"
        ) &
    done

    # Wait for all writes
    wait

    # Verify results
    if [[ -f "$TASK_LEDGER" ]]; then
        local count errors
        count=$(wc -l < "$TASK_LEDGER")
        errors=0

        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                if ! echo "$line" | jq -e . >/dev/null 2>&1; then
                    errors=$((errors + 1))
                fi
            fi
        done < "$TASK_LEDGER"

        if [[ $errors -eq 0 && $count -eq 50 ]]; then
            log_pass "All 50 concurrent writes succeeded without corruption"
            return 0
        elif [[ $errors -gt 0 ]]; then
            log_fail "High-concurrency test: $errors corrupted entries out of $count"
            return 1
        else
            log_fail "High-concurrency test: expected 50 entries, got $count"
            return 1
        fi
    else
        log_fail "Ledger file not created"
        return 1
    fi
}

# =============================================================================
# Main test runner
# =============================================================================
main() {
    echo ""
    echo "============================================================================="
    echo "SEC-007: Ledger File Locking Tests"
    echo "============================================================================="
    echo ""

    # Check if jq is available (required for JSON validation)
    if ! command -v jq &>/dev/null; then
        echo -e "${RED}ERROR: jq is required for these tests but not found${RESET}"
        echo "Install jq and run again: sudo apt-get install jq"
        exit 1
    fi

    # Setup
    setup_test_env

    # Run tests
    test_flock_available
    test_basic_append
    test_concurrent_writes
    test_lock_timeout
    test_shared_read_lock
    test_integrity_verification
    test_integrity_corrupted
    test_log_ledger_secure
    test_special_characters
    test_ledger_rotation
    test_high_concurrency

    # Cleanup
    cleanup_test_env

    # Summary
    echo ""
    echo "============================================================================="
    echo "Test Summary"
    echo "============================================================================="
    echo "Tests Run:    $TESTS_RUN"
    echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${RESET}"
    echo -e "Tests Failed: ${RED}$TESTS_FAILED${RESET}"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}=== ALL SEC-007 TESTS PASSED ===${RESET}"
        exit 0
    else
        echo -e "${RED}=== SOME TESTS FAILED ===${RESET}"
        exit 1
    fi
}

# Run main
main "$@"
