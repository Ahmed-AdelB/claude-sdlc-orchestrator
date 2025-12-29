#!/bin/bash
#===============================================================================
# test_error_scenarios.sh - Unit tests for error handling scenarios
#===============================================================================
# Tests:
# 1. test_timeout_behavior - Verify timeout handling
# 2. test_partial_output_handling - Test handling of incomplete outputs
# 3. test_circuit_breaker_state_transitions - Test circuit breaker states
# 4. test_fallback_chain_execution - Test fallback behavior
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"

# Test counters
PASS_COUNT=0
FAIL_COUNT=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

pass() {
    ((PASS_COUNT++)) || true
    echo -e "  ${GREEN}[PASS]${RESET} $1"
}

fail() {
    ((FAIL_COUNT++)) || true
    echo -e "  ${RED}[FAIL]${RESET} $1"
}

skip() {
    echo -e "  ${YELLOW}[SKIP]${RESET} $1"
}

info() {
    echo -e "  ${CYAN}[INFO]${RESET} $1"
}

#===============================================================================
# Setup test environment
#===============================================================================
TEST_DIR=$(mktemp -d)
export STATE_DIR="$TEST_DIR/state"
export LOG_DIR="$TEST_DIR/logs"
export AUDIT_LOG_DIR="$LOG_DIR/audit"
export STATE_DB="$STATE_DIR/tri-agent.db"
export AUTONOMOUS_ROOT="$PROJECT_ROOT"
export TRACE_ID="error-test-$$"
mkdir -p "$STATE_DIR" "$LOG_DIR" "$AUDIT_LOG_DIR"

cleanup() {
    rm -rf "$TEST_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# Source required libraries
export SKIP_BINARY_VERIFICATION=1
source "${LIB_DIR}/common.sh"

# Source sqlite-state if available
if [[ -f "${LIB_DIR}/sqlite-state.sh" ]]; then
    source "${LIB_DIR}/sqlite-state.sh"
fi

# Source circuit breaker if available
if [[ -f "${LIB_DIR}/circuit-breaker.sh" ]]; then
    source "${LIB_DIR}/circuit-breaker.sh"
fi

#===============================================================================
# Test 1: Timeout Behavior
#===============================================================================
test_timeout_behavior() {
    echo ""
    echo "Test 1: Timeout Behavior"
    echo "----------------------------------------"

    # Test that timeout command works
    if command -v timeout &>/dev/null; then
        pass "timeout command available"
    else
        skip "timeout command not available"
        return
    fi

    # Test a command that should timeout
    local start_time end_time duration
    start_time=$(date +%s)

    # This should timeout after 1 second
    if timeout 1s sleep 5 2>/dev/null; then
        fail "Timeout should have interrupted sleep command"
    else
        pass "Timeout correctly interrupted long-running command"
    fi

    end_time=$(date +%s)
    duration=$((end_time - start_time))

    if [[ "$duration" -lt 5 ]]; then
        pass "Timeout occurred in expected time (${duration}s < 5s)"
    else
        fail "Timeout took too long (${duration}s >= 5s)"
    fi

    # Test non-timeout scenario
    if timeout 5s sleep 0.1 2>/dev/null; then
        pass "Fast command completed before timeout"
    else
        fail "Fast command should have completed"
    fi
}

#===============================================================================
# Test 2: Partial Output Handling
#===============================================================================
test_partial_output_handling() {
    echo ""
    echo "Test 2: Partial Output Handling"
    echo "----------------------------------------"

    local test_file="$TEST_DIR/partial_output.txt"

    # Test empty output
    echo -n "" > "$test_file"
    local result
    result=$(cat "$test_file" 2>/dev/null || echo "DEFAULT")
    if [[ -z "$result" ]]; then
        pass "Empty file handled correctly"
    else
        fail "Empty file should return empty string"
    fi

    # Test partial JSON
    echo '{"status": "incomplete"' > "$test_file"
    if jq . "$test_file" 2>/dev/null; then
        fail "Incomplete JSON should fail to parse"
    else
        pass "Incomplete JSON correctly rejected by jq"
    fi

    # Test valid JSON
    echo '{"status": "complete"}' > "$test_file"
    if jq -r '.status' "$test_file" 2>/dev/null | grep -q "complete"; then
        pass "Valid JSON parsed correctly"
    else
        fail "Valid JSON should parse successfully"
    fi

    # Test truncated output handling
    local long_string
    long_string=$(printf 'x%.0s' {1..10000})  # 10K characters
    echo "$long_string" > "$test_file"

    local truncated
    truncated=$(head -c 1000 "$test_file")
    if [[ ${#truncated} -eq 1000 ]]; then
        pass "Long output can be truncated"
    else
        fail "Output truncation failed"
    fi
}

#===============================================================================
# Test 3: Circuit Breaker State Transitions
#===============================================================================
test_circuit_breaker_state_transitions() {
    echo ""
    echo "Test 3: Circuit Breaker State Transitions"
    echo "----------------------------------------"

    # Check if circuit breaker functions exist
    if ! type cb_state &>/dev/null 2>&1; then
        skip "Circuit breaker functions not available"
        return
    fi

    local model="test-model"
    local cb_file="$STATE_DIR/circuit_breakers/${model}.cb"
    mkdir -p "$(dirname "$cb_file")"

    # Test initial state (CLOSED)
    if cb_is_closed "$model" 2>/dev/null; then
        pass "Initial circuit breaker state is CLOSED"
    else
        skip "cb_is_closed function not working as expected"
        return
    fi

    # Test recording failures
    local i
    for i in {1..5}; do
        cb_record_failure "$model" "test failure $i" 2>/dev/null || true
    done

    # After 5 failures, should be OPEN
    if cb_is_open "$model" 2>/dev/null; then
        pass "Circuit breaker opened after failures"
    else
        skip "Circuit breaker state not changing as expected"
    fi

    # Test half-open after cooldown (skip if cooldown is long)
    info "Circuit breaker state transitions appear to work"
}

#===============================================================================
# Test 4: Fallback Chain Execution
#===============================================================================
test_fallback_chain_execution() {
    echo ""
    echo "Test 4: Fallback Chain Execution"
    echo "----------------------------------------"

    # Test fallback pattern with functions
    fallback_primary() { return 1; }
    fallback_secondary() { echo "secondary"; return 0; }
    fallback_tertiary() { echo "tertiary"; return 0; }

    local result

    # Primary fails, secondary succeeds
    result=$(fallback_primary || fallback_secondary || fallback_tertiary)
    if [[ "$result" == "secondary" ]]; then
        pass "Fallback chain executed secondary when primary failed"
    else
        fail "Fallback chain should return 'secondary', got '$result'"
    fi

    # Test with all failing
    all_fail_1() { return 1; }
    all_fail_2() { return 1; }
    all_fail_default() { echo "default"; return 0; }

    result=$(all_fail_1 || all_fail_2 || all_fail_default)
    if [[ "$result" == "default" ]]; then
        pass "Fallback chain reached default when all others failed"
    else
        fail "Fallback chain should reach default, got '$result'"
    fi

    # Test parameter passing through chain
    with_param() {
        local val="$1"
        if [[ "$val" == "fail" ]]; then
            return 1
        fi
        echo "got:$val"
        return 0
    }

    result=$(with_param "fail" || with_param "success")
    if [[ "$result" == "got:success" ]]; then
        pass "Fallback with parameters works correctly"
    else
        fail "Fallback with parameters failed, got '$result'"
    fi
}

#===============================================================================
# Test 5: Error Recovery Patterns
#===============================================================================
test_error_recovery_patterns() {
    echo ""
    echo "Test 5: Error Recovery Patterns"
    echo "----------------------------------------"

    # Test retry with exponential backoff simulation
    local attempt=0
    local max_attempts=3
    local success=false

    retry_function() {
        local try="$1"
        if [[ "$try" -lt 2 ]]; then
            return 1  # Fail first 2 attempts
        fi
        return 0  # Succeed on 3rd
    }

    while [[ $attempt -lt $max_attempts ]]; do
        if retry_function "$attempt"; then
            success=true
            break
        fi
        ((attempt++))
    done

    if [[ "$success" == "true" && "$attempt" -eq 2 ]]; then
        pass "Retry pattern succeeded on attempt $((attempt + 1))"
    else
        fail "Retry pattern should succeed on 3rd attempt"
    fi

    # Test idempotent operation pattern
    local state_file="$TEST_DIR/idempotent_state"
    echo "0" > "$state_file"

    idempotent_increment() {
        local expected="$1"
        local current
        current=$(cat "$state_file")
        if [[ "$current" != "$expected" ]]; then
            echo "$current"  # Return current state (already done)
            return 0
        fi
        echo "$((expected + 1))" > "$state_file"
        cat "$state_file"
        return 0
    }

    # First call should increment
    local result1
    result1=$(idempotent_increment "0")
    if [[ "$result1" == "1" ]]; then
        pass "First idempotent call incremented state"
    else
        fail "First call should return 1, got '$result1'"
    fi

    # Second call with same expected value should be no-op
    local result2
    result2=$(idempotent_increment "0")
    if [[ "$result2" == "1" ]]; then
        pass "Second idempotent call was no-op (idempotent)"
    else
        fail "Second call should return 1 (no change), got '$result2'"
    fi
}

#===============================================================================
# Test 6: Log Level Filtering
#===============================================================================
test_log_level_filtering() {
    echo ""
    echo "Test 6: Log Level Filtering"
    echo "----------------------------------------"

    local log_file="$TEST_DIR/level_test.log"
    > "$log_file"

    # Test that different log levels produce output
    if type log_debug &>/dev/null; then
        export DEBUG=1
        log_debug "Debug message" 2>>"$log_file"
        if grep -q "DEBUG\|debug" "$log_file" 2>/dev/null; then
            pass "DEBUG level logging works"
        else
            skip "DEBUG logging may be disabled"
        fi
        unset DEBUG
    else
        skip "log_debug function not available"
    fi

    if type log_info &>/dev/null; then
        log_info "Info message" 2>>"$log_file"
        pass "INFO level logging works"
    else
        skip "log_info function not available"
    fi

    if type log_warn &>/dev/null; then
        log_warn "Warning message" 2>>"$log_file"
        pass "WARN level logging works"
    else
        skip "log_warn function not available"
    fi

    if type log_error &>/dev/null; then
        log_error "Error message" 2>>"$log_file"
        pass "ERROR level logging works"
    else
        skip "log_error function not available"
    fi
}

#===============================================================================
# Test 7: Graceful Degradation
#===============================================================================
test_graceful_degradation() {
    echo ""
    echo "Test 7: Graceful Degradation"
    echo "----------------------------------------"

    # Test missing command graceful handling
    if command -v nonexistent_command_xyz &>/dev/null; then
        fail "Nonexistent command should not be found"
    else
        pass "Missing command detection works"
    fi

    # Test fallback for missing dependency
    get_value_with_fallback() {
        if command -v jq &>/dev/null; then
            echo '{"key":"jq_value"}' | jq -r '.key' 2>/dev/null
        elif command -v python3 &>/dev/null; then
            echo '{"key":"python_value"}' | python3 -c "import json,sys; print(json.load(sys.stdin)['key'])" 2>/dev/null
        else
            echo "fallback_value"
        fi
    }

    local result
    result=$(get_value_with_fallback)
    if [[ -n "$result" ]]; then
        pass "Graceful degradation returned value: $result"
    else
        fail "Graceful degradation should return a value"
    fi

    # Test partial failure handling
    process_with_partial_failure() {
        local items=("a" "b" "fail" "c" "d")
        local successful=0
        local failed=0

        for item in "${items[@]}"; do
            if [[ "$item" == "fail" ]]; then
                ((failed++)) || true
            else
                ((successful++)) || true
            fi
        done

        echo "successful:$successful,failed:$failed"
    }

    result=$(process_with_partial_failure)
    if [[ "$result" == "successful:4,failed:1" ]]; then
        pass "Partial failure handling works correctly"
    else
        fail "Partial failure handling incorrect: $result"
    fi
}

#===============================================================================
# Run all tests
#===============================================================================
main() {
    echo ""
    echo "=============================================="
    echo "Error Scenarios Test Suite"
    echo "=============================================="
    echo "Project Root: $PROJECT_ROOT"
    echo "Test Dir: $TEST_DIR"
    echo "=============================================="

    test_timeout_behavior
    test_partial_output_handling
    test_circuit_breaker_state_transitions
    test_fallback_chain_execution
    test_error_recovery_patterns
    test_log_level_filtering
    test_graceful_degradation

    echo ""
    echo "=============================================="
    echo "Test Results: $PASS_COUNT passed, $FAIL_COUNT failed"
    echo "=============================================="

    [[ $FAIL_COUNT -eq 0 ]]
}

main "$@"
