#!/bin/bash
#===============================================================================
# test_circuit_breaker.sh - Unit tests for lib/circuit-breaker.sh
#===============================================================================

set -euo pipefail

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
    echo -e "  [SKIP] $1"
}

#===============================================================================
# Setup test environment
#===============================================================================

TEST_STATE_DIR=$(mktemp -d)
TEST_LOG_DIR=$(mktemp -d)
export STATE_DIR="$TEST_STATE_DIR"
export BREAKERS_DIR="${TEST_STATE_DIR}/breakers"
export LOG_DIR="$TEST_LOG_DIR"
export TRACE_ID="test-cb-$$"

mkdir -p "$BREAKERS_DIR"

cleanup() {
    rm -rf "$TEST_STATE_DIR" "$TEST_LOG_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# Source dependencies
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/circuit-breaker.sh" 2>/dev/null || {
    echo "Error: Could not source circuit-breaker.sh"
    exit 1
}

# Helper functions to adapt test API to actual API
get_breaker_state() {
    local model="$1"
    local json_output
    json_output=$(get_breaker_status "$model" 2>/dev/null) || {
        echo "CLOSED"
        return
    }
    # Parse state from JSON output
    echo "$json_output" | grep '"state"' | sed 's/.*"state": *"\([^"]*\)".*/\1/'
}

set_breaker_state() {
    local model="$1"
    local state="$2"
    local breaker_file="${BREAKERS_DIR}/${model}.state"
    mkdir -p "$BREAKERS_DIR"
    echo "state=$state" > "$breaker_file"
    echo "failures=0" >> "$breaker_file"
    echo "last_failure=" >> "$breaker_file"
    echo "half_open_until=" >> "$breaker_file"
}

check_circuit() {
    local model="$1"
    should_call_model "$model"
}

#===============================================================================
# Tests
#===============================================================================

echo ""
echo "Testing lib/circuit-breaker.sh functions..."

# Test 1: get_breaker_state returns CLOSED for new model
test_get_breaker_state_new() {
    if type get_breaker_state &>/dev/null; then
        local state
        state=$(get_breaker_state "test_model")
        if [[ "$state" == "CLOSED" ]]; then
            pass "get_breaker_state: Returns CLOSED for new model"
        else
            fail "get_breaker_state: Expected CLOSED, got '$state'"
        fi
    else
        skip "get_breaker_state: Function not available"
    fi
}

# Test 2: set_breaker_state and get_breaker_state work together
test_set_get_breaker_state() {
    if type set_breaker_state &>/dev/null && type get_breaker_state &>/dev/null; then
        set_breaker_state "test_model_2" "OPEN"
        local state
        state=$(get_breaker_state "test_model_2")
        if [[ "$state" == "OPEN" ]]; then
            pass "set_breaker_state: Sets state correctly"
        else
            fail "set_breaker_state: Expected OPEN, got '$state'"
        fi
    else
        skip "set/get_breaker_state: Functions not available"
    fi
}

# Test 3: record_failure increments failure count
test_record_failure() {
    if type record_failure &>/dev/null && type get_failure_count &>/dev/null; then
        record_failure "test_model_3"
        record_failure "test_model_3"
        local count
        count=$(get_failure_count "test_model_3")
        if [[ "$count" == "2" ]]; then
            pass "record_failure: Increments failure count"
        else
            fail "record_failure: Expected 2, got '$count'"
        fi
    else
        skip "record_failure: Functions not available"
    fi
}

# Test 4: record_success resets failure count
test_record_success() {
    if type record_failure &>/dev/null && type record_success &>/dev/null && type get_failure_count &>/dev/null; then
        record_failure "test_model_4"
        record_failure "test_model_4"
        record_success "test_model_4"
        local count
        count=$(get_failure_count "test_model_4")
        if [[ "$count" == "0" ]]; then
            pass "record_success: Resets failure count"
        else
            fail "record_success: Expected 0, got '$count'"
        fi
    else
        skip "record_success: Functions not available"
    fi
}

# Test 5: reset_breaker clears state
test_reset_breaker() {
    if type set_breaker_state &>/dev/null && type reset_breaker &>/dev/null && type get_breaker_state &>/dev/null; then
        set_breaker_state "test_model_5" "OPEN"
        reset_breaker "test_model_5"
        local state
        state=$(get_breaker_state "test_model_5")
        if [[ "$state" == "CLOSED" ]]; then
            pass "reset_breaker: Resets to CLOSED"
        else
            fail "reset_breaker: Expected CLOSED, got '$state'"
        fi
    else
        skip "reset_breaker: Functions not available"
    fi
}

# Test 6: check_circuit returns success for CLOSED
test_check_circuit() {
    if type set_breaker_state &>/dev/null && type check_circuit &>/dev/null; then
        set_breaker_state "test_model_6" "CLOSED"
        if check_circuit "test_model_6"; then
            pass "check_circuit: Returns success for CLOSED"
        else
            fail "check_circuit: Should return success for CLOSED"
        fi
    else
        skip "check_circuit: Functions not available"
    fi
}

#===============================================================================
# Run Tests
#===============================================================================

test_get_breaker_state_new
test_set_get_breaker_state
test_record_failure
test_record_success
test_reset_breaker
test_check_circuit

export TESTS_PASSED TESTS_FAILED

echo ""
echo "circuit-breaker.sh tests completed: $TESTS_PASSED passed, $TESTS_FAILED failed"
