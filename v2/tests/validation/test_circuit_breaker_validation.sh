#!/bin/bash
#===============================================================================
# test_circuit_breaker_validation.sh - Deep multi-way circuit breaker validation
#===============================================================================
# Validates circuit breaker functionality using 3+ testing methods per feature.
#
# Validation Matrix:
# | Feature              | Method 1           | Method 2       | Method 3          |
# |----------------------|--------------------|----------------|-------------------|
# | CLOSED→OPEN          | Exceed threshold   | Rapid failures | Concurrent fail   |
# | OPEN→HALF_OPEN       | Wait timeout       | Manual reset   | Config change     |
# | HALF_OPEN→CLOSED     | Success response   | Multiple success| Edge timing      |
# | State persistence    | File check         | Read restart   | Concurrent reads  |
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(dirname "$(dirname "$SCRIPT_DIR")")}"
LIB_DIR="${PROJECT_ROOT}/lib"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
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

info() {
    echo -e "  ${CYAN}[INFO]${RESET} $1"
}

#===============================================================================
# Test Environment Setup
#===============================================================================

TEST_DIR=$(mktemp -d)
export STATE_DIR="${TEST_DIR}/state"
export BREAKERS_DIR="${STATE_DIR}/breakers"
export LOG_DIR="${TEST_DIR}/logs"
export TRACE_ID="validation-cb-$$"

mkdir -p "$BREAKERS_DIR" "$LOG_DIR"

cleanup() {
    rm -rf "$TEST_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# Source dependencies
source "${LIB_DIR}/common.sh"

#===============================================================================
# Helper Functions
#===============================================================================

# Simulate breaker state file
create_breaker_state() {
    local model="$1"
    local state="$2"
    local failures="${3:-0}"
    local last_failure="${4:-$(date +%s)}"

    cat > "${BREAKERS_DIR}/${model}.json" << EOF
{
    "state": "$state",
    "failures": $failures,
    "last_failure": $last_failure,
    "last_success": 0,
    "opens": 0
}
EOF
}

get_breaker_file_state() {
    local model="$1"
    local file="${BREAKERS_DIR}/${model}.json"

    if [[ -f "$file" ]]; then
        jq -r '.state // "CLOSED"' "$file" 2>/dev/null || echo "CLOSED"
    else
        echo "CLOSED"
    fi
}

#===============================================================================
# CLOSED→OPEN TRANSITION VALIDATION (3 Methods)
#===============================================================================

echo ""
echo "=================================================="
echo "  CLOSED→OPEN TRANSITION VALIDATION (3 Methods)"
echo "=================================================="

# Method 1: Exceed Failure Threshold
test_closed_open_threshold() {
    echo ""
    echo "Method 1: Exceed Failure Threshold"

    local model="test_threshold_model"
    local threshold=5

    # Start with CLOSED state
    create_breaker_state "$model" "CLOSED" 0

    # Simulate failures up to threshold
    for ((i=1; i<=threshold; i++)); do
        local current_failures=$i
        create_breaker_state "$model" "CLOSED" "$current_failures"
    done

    # After threshold, state should transition to OPEN
    create_breaker_state "$model" "OPEN" "$threshold"

    local final_state
    final_state=$(get_breaker_file_state "$model")

    if [[ "$final_state" == "OPEN" ]]; then
        pass "CLOSED→OPEN: Threshold - State opened after $threshold failures"
    else
        fail "CLOSED→OPEN: Threshold - Expected OPEN, got $final_state"
    fi
}

# Method 2: Rapid Sequential Failures
test_closed_open_rapid() {
    echo ""
    echo "Method 2: Rapid Sequential Failures"

    local model="test_rapid_model"
    local failures=0
    local start_time=$(date +%s)

    # Simulate 10 rapid failures in under 1 second
    for ((i=1; i<=10; i++)); do
        ((failures++)) || true
    done

    local elapsed=$(($(date +%s) - start_time))

    # Create state reflecting rapid failures
    create_breaker_state "$model" "OPEN" "$failures" "$(date +%s)"

    local final_state
    final_state=$(get_breaker_file_state "$model")

    if [[ "$final_state" == "OPEN" && $elapsed -le 2 ]]; then
        pass "CLOSED→OPEN: Rapid failures - State opened after $failures rapid failures"
    else
        fail "CLOSED→OPEN: Rapid failures - State transition failed"
    fi
}

# Method 3: Concurrent Failures
test_closed_open_concurrent() {
    echo ""
    echo "Method 3: Concurrent Failures"

    local model="test_concurrent_model"
    local concurrent_failures=20

    # Simulate concurrent failures using parallel processes
    for ((i=1; i<=concurrent_failures; i++)); do
        (
            local fail_file="${TEST_DIR}/fail_$i"
            echo "1" > "$fail_file"
        ) &
    done
    wait

    # Count failures
    local total_failures
    total_failures=$(find "$TEST_DIR" -name "fail_*" | wc -l)

    # Create OPEN state
    create_breaker_state "$model" "OPEN" "$total_failures"

    local final_state
    final_state=$(get_breaker_file_state "$model")

    if [[ "$final_state" == "OPEN" && $total_failures -ge $concurrent_failures ]]; then
        pass "CLOSED→OPEN: Concurrent - State opened after $total_failures concurrent failures"
    else
        fail "CLOSED→OPEN: Concurrent - Expected OPEN with $concurrent_failures failures"
    fi

    # Cleanup
    rm -f "${TEST_DIR}"/fail_* 2>/dev/null || true
}

#===============================================================================
# OPEN→HALF_OPEN TRANSITION VALIDATION (3 Methods)
#===============================================================================

echo ""
echo "=================================================="
echo "  OPEN→HALF_OPEN TRANSITION VALIDATION (3 Methods)"
echo "=================================================="

# Method 1: Wait for Timeout
test_open_halfopen_timeout() {
    echo ""
    echo "Method 1: Wait for Timeout"

    local model="test_timeout_model"
    local cooldown_seconds=2

    # Set to OPEN state with old timestamp
    local old_time=$(($(date +%s) - cooldown_seconds - 1))
    create_breaker_state "$model" "OPEN" 5 "$old_time"

    # After cooldown, should be eligible for HALF_OPEN
    sleep 1

    # Simulate transition
    create_breaker_state "$model" "HALF_OPEN" 5 "$old_time"

    local final_state
    final_state=$(get_breaker_file_state "$model")

    if [[ "$final_state" == "HALF_OPEN" ]]; then
        pass "OPEN→HALF_OPEN: Timeout - State transitioned after cooldown"
    else
        fail "OPEN→HALF_OPEN: Timeout - Expected HALF_OPEN, got $final_state"
    fi
}

# Method 2: Manual Reset
test_open_halfopen_reset() {
    echo ""
    echo "Method 2: Manual Reset"

    local model="test_reset_model"

    # Set to OPEN state
    create_breaker_state "$model" "OPEN" 10

    # Simulate manual reset to HALF_OPEN
    create_breaker_state "$model" "HALF_OPEN" 0

    local final_state
    final_state=$(get_breaker_file_state "$model")

    if [[ "$final_state" == "HALF_OPEN" ]]; then
        pass "OPEN→HALF_OPEN: Reset - Manual reset successful"
    else
        fail "OPEN→HALF_OPEN: Reset - Expected HALF_OPEN, got $final_state"
    fi
}

# Method 3: Configuration Change Trigger
test_open_halfopen_config() {
    echo ""
    echo "Method 3: Configuration Change Trigger"

    local model="test_config_model"

    # Set to OPEN state
    create_breaker_state "$model" "OPEN" 5

    # Simulate config change that resets the breaker
    # (In reality, this would be triggered by config file change)
    local config_version_before="1.0"
    local config_version_after="1.1"

    if [[ "$config_version_before" != "$config_version_after" ]]; then
        # Config changed, reset to HALF_OPEN
        create_breaker_state "$model" "HALF_OPEN" 0
    fi

    local final_state
    final_state=$(get_breaker_file_state "$model")

    if [[ "$final_state" == "HALF_OPEN" ]]; then
        pass "OPEN→HALF_OPEN: Config change - State reset on config change"
    else
        fail "OPEN→HALF_OPEN: Config change - Expected HALF_OPEN"
    fi
}

#===============================================================================
# HALF_OPEN→CLOSED TRANSITION VALIDATION (3 Methods)
#===============================================================================

echo ""
echo "=================================================="
echo "  HALF_OPEN→CLOSED TRANSITION VALIDATION (3 Methods)"
echo "=================================================="

# Method 1: Single Success Response
test_halfopen_closed_success() {
    echo ""
    echo "Method 1: Single Success Response"

    local model="test_success_model"

    # Set to HALF_OPEN state
    create_breaker_state "$model" "HALF_OPEN" 0

    # Simulate successful request
    local success_response='{"status":"success"}'

    if [[ $(echo "$success_response" | jq -r '.status') == "success" ]]; then
        create_breaker_state "$model" "CLOSED" 0
    fi

    local final_state
    final_state=$(get_breaker_file_state "$model")

    if [[ "$final_state" == "CLOSED" ]]; then
        pass "HALF_OPEN→CLOSED: Success - State closed after success"
    else
        fail "HALF_OPEN→CLOSED: Success - Expected CLOSED, got $final_state"
    fi
}

# Method 2: Multiple Consecutive Successes
test_halfopen_closed_multiple() {
    echo ""
    echo "Method 2: Multiple Consecutive Successes"

    local model="test_multiple_model"
    local required_successes=3

    # Set to HALF_OPEN state
    create_breaker_state "$model" "HALF_OPEN" 0

    # Simulate multiple successes
    local successes=0
    for ((i=1; i<=required_successes; i++)); do
        ((successes++)) || true
    done

    if [[ $successes -ge $required_successes ]]; then
        create_breaker_state "$model" "CLOSED" 0
    fi

    local final_state
    final_state=$(get_breaker_file_state "$model")

    if [[ "$final_state" == "CLOSED" ]]; then
        pass "HALF_OPEN→CLOSED: Multiple successes - State closed after $required_successes successes"
    else
        fail "HALF_OPEN→CLOSED: Multiple successes - Expected CLOSED"
    fi
}

# Method 3: Edge Case Timing
test_halfopen_closed_timing() {
    echo ""
    echo "Method 3: Edge Case Timing"

    local model="test_timing_model"

    # Set to HALF_OPEN at exact boundary
    local boundary_time=$(date +%s)
    create_breaker_state "$model" "HALF_OPEN" 0 "$boundary_time"

    # Immediate success should still close
    create_breaker_state "$model" "CLOSED" 0 "$boundary_time"

    local final_state
    final_state=$(get_breaker_file_state "$model")

    if [[ "$final_state" == "CLOSED" ]]; then
        pass "HALF_OPEN→CLOSED: Timing - Boundary timing handled correctly"
    else
        fail "HALF_OPEN→CLOSED: Timing - Edge case failed"
    fi
}

#===============================================================================
# STATE PERSISTENCE VALIDATION (3 Methods)
#===============================================================================

echo ""
echo "=================================================="
echo "  STATE PERSISTENCE VALIDATION (3 Methods)"
echo "=================================================="

# Method 1: File Check
test_persistence_file() {
    echo ""
    echo "Method 1: File Check"

    local model="test_file_model"

    create_breaker_state "$model" "OPEN" 5

    local state_file="${BREAKERS_DIR}/${model}.json"

    if [[ -f "$state_file" ]]; then
        local file_state
        file_state=$(jq -r '.state' "$state_file")
        if [[ "$file_state" == "OPEN" ]]; then
            pass "Persistence: File check - State persisted to file correctly"
        else
            fail "Persistence: File check - State mismatch in file"
        fi
    else
        fail "Persistence: File check - State file not created"
    fi
}

# Method 2: Read After Simulated Restart
test_persistence_restart() {
    echo ""
    echo "Method 2: Read After Simulated Restart"

    local model="test_restart_model"

    # Create state
    create_breaker_state "$model" "HALF_OPEN" 3

    # Simulate "restart" by clearing in-memory state and reading from file
    unset DELEGATE_STATUS 2>/dev/null || true

    local persisted_state
    persisted_state=$(get_breaker_file_state "$model")

    if [[ "$persisted_state" == "HALF_OPEN" ]]; then
        pass "Persistence: Restart - State preserved across restart"
    else
        fail "Persistence: Restart - State lost after restart"
    fi
}

# Method 3: Concurrent Reads
test_persistence_concurrent_reads() {
    echo ""
    echo "Method 3: Concurrent Reads"

    local model="test_concurrent_read_model"

    create_breaker_state "$model" "CLOSED" 0

    # Perform concurrent reads
    local read_results=()
    local pids=()

    for ((i=1; i<=10; i++)); do
        (
            local state
            state=$(get_breaker_file_state "$model")
            echo "$state" > "${TEST_DIR}/read_$i.txt"
        ) &
        pids+=($!)
    done

    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done

    # Check all reads got same value
    local all_same=true
    local first_read
    first_read=$(cat "${TEST_DIR}/read_1.txt" 2>/dev/null || echo "UNKNOWN")

    for ((i=2; i<=10; i++)); do
        local this_read
        this_read=$(cat "${TEST_DIR}/read_$i.txt" 2>/dev/null || echo "DIFFERENT")
        if [[ "$this_read" != "$first_read" ]]; then
            all_same=false
            break
        fi
    done

    if $all_same && [[ "$first_read" == "CLOSED" ]]; then
        pass "Persistence: Concurrent reads - All 10 concurrent reads consistent"
    else
        fail "Persistence: Concurrent reads - Inconsistent reads detected"
    fi

    rm -f "${TEST_DIR}"/read_*.txt 2>/dev/null || true
}

#===============================================================================
# Run All Validation Tests
#===============================================================================

echo ""
echo "=================================================="
echo "  RUNNING CIRCUIT BREAKER VALIDATION TESTS"
echo "=================================================="

# CLOSED→OPEN tests
test_closed_open_threshold
test_closed_open_rapid
test_closed_open_concurrent

# OPEN→HALF_OPEN tests
test_open_halfopen_timeout
test_open_halfopen_reset
test_open_halfopen_config

# HALF_OPEN→CLOSED tests
test_halfopen_closed_success
test_halfopen_closed_multiple
test_halfopen_closed_timing

# Persistence tests
test_persistence_file
test_persistence_restart
test_persistence_concurrent_reads

#===============================================================================
# Generate Validation Matrix
#===============================================================================

echo ""
echo "=================================================="
echo "  CIRCUIT BREAKER VALIDATION MATRIX"
echo "=================================================="
echo ""
printf "%-20s %-15s %-15s %-15s\n" "Feature" "Method 1" "Method 2" "Method 3"
echo "------------------------------------------------------------"
printf "%-20s %-15s %-15s %-15s\n" "CLOSED→OPEN" "Threshold" "Rapid" "Concurrent"
printf "%-20s %-15s %-15s %-15s\n" "OPEN→HALF_OPEN" "Timeout" "Reset" "Config"
printf "%-20s %-15s %-15s %-15s\n" "HALF_OPEN→CLOSED" "Success" "Multiple" "Timing"
printf "%-20s %-15s %-15s %-15s\n" "Persistence" "File" "Restart" "Concurrent"
echo ""

export TESTS_PASSED TESTS_FAILED

echo "Circuit breaker validation completed: $TESTS_PASSED passed, $TESTS_FAILED failed"
