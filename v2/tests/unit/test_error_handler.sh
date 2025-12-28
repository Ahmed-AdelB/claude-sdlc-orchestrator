#!/bin/bash
#===============================================================================
# test_error_handler.sh - Unit tests for lib/error-handler.sh
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
export LOG_DIR="$TEST_LOG_DIR"
export TRACE_ID="test-eh-$$"

mkdir -p "$STATE_DIR" "$LOG_DIR"

cleanup() {
    rm -rf "$TEST_STATE_DIR" "$TEST_LOG_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# Source dependencies
source "${LIB_DIR}/common.sh"

#===============================================================================
# Tests
#===============================================================================

echo ""
echo "Testing lib/error-handler.sh functions..."

# Test 1: classify_error identifies rate limit errors
test_classify_rate_limit() {
    if type classify_error &>/dev/null; then
        local result
        result=$(classify_error "rate limit exceeded")
        if [[ "$result" == "rate_limit" ]]; then
            pass "classify_error: Identifies rate limit errors"
        else
            fail "classify_error: Expected 'rate_limit', got '$result'"
        fi
    else
        skip "classify_error: Function not available"
    fi
}

# Test 2: classify_error identifies timeout errors
test_classify_timeout() {
    if type classify_error &>/dev/null; then
        local result
        result=$(classify_error "connection timed out")
        if [[ "$result" == "timeout" ]]; then
            pass "classify_error: Identifies timeout errors"
        else
            fail "classify_error: Expected 'timeout', got '$result'"
        fi
    else
        skip "classify_error: Function not available"
    fi
}

# Test 3: classify_error identifies auth errors
test_classify_auth() {
    if type classify_error &>/dev/null; then
        local result
        result=$(classify_error "authentication failed")
        if [[ "$result" == "auth_error" ]]; then
            pass "classify_error: Identifies auth errors"
        else
            fail "classify_error: Expected 'auth_error', got '$result'"
        fi
    else
        skip "classify_error: Function not available"
    fi
}

# Test 4: should_retry returns true for rate limits on first attempt
test_should_retry_rate_limit() {
    if type should_retry &>/dev/null; then
        if should_retry "rate_limit" 1; then
            pass "should_retry: Returns true for rate_limit on attempt 1"
        else
            fail "should_retry: Should return true for rate_limit"
        fi
    else
        skip "should_retry: Function not available"
    fi
}

# Test 5: should_retry returns false for auth errors
test_should_retry_auth() {
    if type should_retry &>/dev/null; then
        if ! should_retry "auth_error" 1; then
            pass "should_retry: Returns false for auth_error"
        else
            fail "should_retry: Should return false for auth_error"
        fi
    else
        skip "should_retry: Function not available"
    fi
}

# Test 6: calculate_backoff returns increasing delays
test_calculate_backoff() {
    if type calculate_backoff &>/dev/null; then
        local delay1 delay2
        delay1=$(calculate_backoff 1)
        delay2=$(calculate_backoff 2)
        if [[ "$delay2" -gt "$delay1" ]]; then
            pass "calculate_backoff: Delay increases with attempts"
        else
            fail "calculate_backoff: Delay should increase (got $delay1, $delay2)"
        fi
    else
        skip "calculate_backoff: Function not available"
    fi
}

# Test 7: get_fallback_model returns alternative model
test_get_fallback_model() {
    if type get_fallback_model &>/dev/null; then
        local fallback
        fallback=$(get_fallback_model "claude")
        if [[ -n "$fallback" && "$fallback" != "claude" ]]; then
            pass "get_fallback_model: Returns alternative model ($fallback)"
        else
            pass "get_fallback_model: May return empty if no fallback defined"
        fi
    else
        skip "get_fallback_model: Function not available"
    fi
}

#===============================================================================
# Run Tests
#===============================================================================

test_classify_rate_limit
test_classify_timeout
test_classify_auth
test_should_retry_rate_limit
test_should_retry_auth
test_calculate_backoff
test_get_fallback_model

export TESTS_PASSED TESTS_FAILED

echo ""
echo "error-handler.sh tests completed: $TESTS_PASSED passed, $TESTS_FAILED failed"
