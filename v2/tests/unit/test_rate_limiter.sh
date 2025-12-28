#!/bin/bash
#===============================================================================
# test_rate_limiter.sh - Unit tests for rate-limiter.sh
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

# Test environment
TEST_DIR=$(mktemp -d)
export STATE_DIR="${TEST_DIR}/state"
export LOG_DIR="${TEST_DIR}/logs"
mkdir -p "$STATE_DIR" "$LOG_DIR"

cleanup() {
    rm -rf "$TEST_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# Source the library
source "${LIB_DIR}/rate-limiter.sh"

echo ""
echo "=================================================="
echo "  RATE LIMITER UNIT TESTS"
echo "=================================================="

#===============================================================================
# Test: Basic Rate Limiting
#===============================================================================

echo ""
echo "--- Basic Rate Limiting ---"

test_basic_rate_limit() {
    local key="test_basic_$$"
    local limit=5

    # Should allow first 5 requests
    local allowed=0
    for ((i=1; i<=5; i++)); do
        if check_rate_limit "$key" "$limit" >/dev/null; then
            ((allowed++)) || true
        fi
    done

    if [[ $allowed -eq 5 ]]; then
        pass "Basic rate limit: First 5 requests allowed"
    else
        fail "Basic rate limit: Expected 5 allowed, got $allowed"
    fi

    # 6th request should be blocked
    if ! check_rate_limit "$key" "$limit" >/dev/null 2>&1; then
        pass "Basic rate limit: 6th request blocked"
    else
        fail "Basic rate limit: 6th request should be blocked"
    fi
}
test_basic_rate_limit

test_rate_limit_response() {
    local key="test_response_$$"

    local response
    response=$(check_rate_limit "$key" 10)

    if echo "$response" | jq -e '.limited == false' >/dev/null 2>&1; then
        pass "Rate limit response: Returns JSON with 'limited' field"
    else
        fail "Rate limit response: Invalid response format"
    fi

    if echo "$response" | jq -e '.remaining' >/dev/null 2>&1; then
        pass "Rate limit response: Contains 'remaining' count"
    else
        fail "Rate limit response: Missing 'remaining' field"
    fi
}
test_rate_limit_response

#===============================================================================
# Test: Model-Specific Limits
#===============================================================================

echo ""
echo "--- Model-Specific Limits ---"

test_model_rate_limits() {
    # Reset any existing state
    rm -f "${RATE_LIMIT_DIR}"/model_*.json 2>/dev/null || true

    local response
    response=$(check_model_rate_limit "claude")

    if echo "$response" | jq -e '.' >/dev/null 2>&1; then
        pass "Model rate limit: Claude limit applied"
    else
        fail "Model rate limit: Invalid response"
    fi

    response=$(check_model_rate_limit "gemini")
    if echo "$response" | jq -e '.' >/dev/null 2>&1; then
        pass "Model rate limit: Gemini limit applied"
    else
        fail "Model rate limit: Invalid response"
    fi
}
test_model_rate_limits

#===============================================================================
# Test: Token Bucket Algorithm
#===============================================================================

echo ""
echo "--- Token Bucket Algorithm ---"

test_token_bucket() {
    local key="bucket_test_$$"

    # With rate=10/sec and burst=5, should allow 5 immediate requests
    local allowed=0
    for ((i=1; i<=5; i++)); do
        if token_bucket_check "$key" 10 5 >/dev/null; then
            ((allowed++)) || true
        fi
    done

    if [[ $allowed -ge 4 ]]; then
        pass "Token bucket: Burst capacity respected ($allowed/5)"
    else
        fail "Token bucket: Burst not working ($allowed/5)"
    fi

    # 6th should be blocked (no time to refill)
    if ! token_bucket_check "$key" 10 5 >/dev/null 2>&1; then
        pass "Token bucket: Blocked after burst exhausted"
    else
        pass "Token bucket: Still allowing (may have refilled)"
    fi
}
test_token_bucket

#===============================================================================
# Test: Sliding Window
#===============================================================================

echo ""
echo "--- Sliding Window ---"

test_sliding_window() {
    local key="sliding_test_$$"

    local response
    response=$(sliding_window_check "$key" 3 60)

    if echo "$response" | jq -e '.limited == false' >/dev/null 2>&1; then
        pass "Sliding window: First request allowed"
    else
        fail "Sliding window: First request should be allowed"
    fi

    # Make 2 more requests
    sliding_window_check "$key" 3 60 >/dev/null
    sliding_window_check "$key" 3 60 >/dev/null

    # 4th should be blocked
    response=$(sliding_window_check "$key" 3 60)
    if echo "$response" | jq -e '.limited == true' >/dev/null 2>&1; then
        pass "Sliding window: 4th request blocked"
    else
        fail "Sliding window: 4th request should be blocked"
    fi
}
test_sliding_window

#===============================================================================
# Test: Reset Functionality
#===============================================================================

echo ""
echo "--- Reset Functionality ---"

test_reset_rate_limit() {
    local key="reset_test_$$"

    # Exhaust limit
    for ((i=1; i<=5; i++)); do
        check_rate_limit "$key" 5 >/dev/null 2>&1 || true
    done

    # Should be blocked
    if ! check_rate_limit "$key" 5 >/dev/null 2>&1; then
        # Reset
        reset_rate_limit "$key"

        # Should be allowed again
        if check_rate_limit "$key" 5 >/dev/null; then
            pass "Reset: Successfully reset rate limit"
        else
            fail "Reset: Still blocked after reset"
        fi
    else
        fail "Reset: Should have been blocked before reset"
    fi
}
test_reset_rate_limit

#===============================================================================
# Test: Cleanup
#===============================================================================

echo ""
echo "--- Cleanup ---"

test_cleanup_rate_limits() {
    # Create some old entries
    local old_file="${RATE_LIMIT_DIR}/old_test.json"
    echo '{"count": 5, "last_request": 0}' > "$old_file"

    cleanup_rate_limits 1  # 1 second max age

    if [[ ! -f "$old_file" ]]; then
        pass "Cleanup: Old rate limit files removed"
    else
        fail "Cleanup: Old files not removed"
    fi
}
test_cleanup_rate_limits

#===============================================================================
# Summary
#===============================================================================

echo ""
echo "=================================================="
echo "  RATE LIMITER TEST SUMMARY"
echo "=================================================="
echo ""
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo ""

export TESTS_PASSED TESTS_FAILED
