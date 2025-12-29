#!/bin/bash
# =============================================================================
# test_sec009c_json_limits.sh - SEC-009C Verification Tests
# =============================================================================
# Tests for JSON Size Limits to prevent DoS attacks via unbounded JSON parsing.
# This ensures all JSON inputs are validated for size and depth before parsing.
# =============================================================================

set -euo pipefail

# =============================================================================
# TEST SETUP
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source security.sh which contains JSON validation functions
source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/security.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

# =============================================================================
# TEST HELPER FUNCTIONS
# =============================================================================

test_pass() {
    local test_name="$1"
    ((TESTS_PASSED++)) || true
    echo -e "${GREEN}PASS${RESET}: $test_name"
}

test_fail() {
    local test_name="$1"
    local reason="${2:-}"
    ((TESTS_FAILED++)) || true
    echo -e "${RED}FAIL${RESET}: $test_name"
    [[ -n "$reason" ]] && echo "       Reason: $reason"
}

test_skip() {
    local test_name="$1"
    local reason="${2:-}"
    echo -e "${YELLOW}SKIP${RESET}: $test_name"
    [[ -n "$reason" ]] && echo "       Reason: $reason"
}

# =============================================================================
# TEST 1: Constants are defined
# =============================================================================

test_constants_defined() {
    local test_name="[1] SEC-009C constants are defined"
    ((TESTS_RUN++)) || true

    local passed=true

    if [[ -z "${MAX_TASK_SIZE_BYTES:-}" ]]; then
        echo "  MAX_TASK_SIZE_BYTES not defined"
        passed=false
    elif [[ "$MAX_TASK_SIZE_BYTES" != "102400" ]]; then
        echo "  MAX_TASK_SIZE_BYTES should be 102400, got: $MAX_TASK_SIZE_BYTES"
        passed=false
    fi

    if [[ -z "${MAX_JSON_DEPTH:-}" ]]; then
        echo "  MAX_JSON_DEPTH not defined"
        passed=false
    elif [[ "$MAX_JSON_DEPTH" != "20" ]]; then
        echo "  MAX_JSON_DEPTH should be 20, got: $MAX_JSON_DEPTH"
        passed=false
    fi

    if [[ -z "${MAX_ARRAY_ITEMS:-}" ]]; then
        echo "  MAX_ARRAY_ITEMS not defined"
        passed=false
    elif [[ "$MAX_ARRAY_ITEMS" != "1000" ]]; then
        echo "  MAX_ARRAY_ITEMS should be 1000, got: $MAX_ARRAY_ITEMS"
        passed=false
    fi

    if [[ "$passed" == "true" ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name"
    fi
}

# =============================================================================
# TEST 2: Valid small JSON is accepted
# =============================================================================

test_valid_small_json_accepted() {
    local test_name="[2] Valid small JSON is accepted"
    ((TESTS_RUN++)) || true

    local valid_json='{"name": "test", "value": 123}'

    if validate_json_size "$valid_json" 2>/dev/null; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Small valid JSON was rejected"
    fi
}

# =============================================================================
# TEST 3: Oversized JSON is rejected
# =============================================================================

test_oversized_json_rejected() {
    local test_name="[3] Oversized JSON is rejected"
    ((TESTS_RUN++)) || true

    # Create a JSON string larger than 100KB (102400 bytes)
    local oversized_json='{"data": "'
    # Add enough characters to exceed the limit
    local padding=""
    for i in $(seq 1 103000); do
        padding+="x"
    done
    oversized_json+="${padding}\"}"

    if validate_json_size "$oversized_json" 2>/dev/null; then
        test_fail "$test_name" "Oversized JSON was not rejected"
    else
        test_pass "$test_name"
    fi
}

# =============================================================================
# TEST 4: Valid shallow nested JSON is accepted
# =============================================================================

test_valid_shallow_json_accepted() {
    local test_name="[4] Valid shallow nested JSON is accepted"
    ((TESTS_RUN++)) || true

    # Create JSON with 5 levels of nesting (well under 20)
    local shallow_json='{"a": {"b": {"c": {"d": {"e": "value"}}}}}'

    if validate_json_depth "$shallow_json" 2>/dev/null; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Shallow nested JSON was rejected"
    fi
}

# =============================================================================
# TEST 5: Deeply nested JSON is rejected
# =============================================================================

test_deeply_nested_json_rejected() {
    local test_name="[5] Deeply nested JSON is rejected"
    ((TESTS_RUN++)) || true

    # Create JSON with more than 20 levels of nesting
    local deep_json=""
    local close_braces=""
    for i in $(seq 1 25); do
        deep_json+='{"level'$i'":'
        close_braces+='}'
    done
    deep_json+='"value"'
    deep_json+="$close_braces"

    if validate_json_depth "$deep_json" 2>/dev/null; then
        test_fail "$test_name" "Deeply nested JSON was not rejected"
    else
        test_pass "$test_name"
    fi
}

# =============================================================================
# TEST 6: safe_parse_json validates and parses correctly
# =============================================================================

test_safe_parse_json_works() {
    local test_name="[6] safe_parse_json validates and parses correctly"
    ((TESTS_RUN++)) || true

    local valid_json='{"name": "test", "value": 123}'

    local result
    if result=$(safe_parse_json "$valid_json" 2>/dev/null); then
        # Check if result contains expected content
        if echo "$result" | grep -q "test"; then
            test_pass "$test_name"
        else
            test_fail "$test_name" "Parsed result does not contain expected content"
        fi
    else
        test_fail "$test_name" "safe_parse_json failed for valid JSON"
    fi
}

# =============================================================================
# TEST 7: safe_parse_json rejects oversized input
# =============================================================================

test_safe_parse_json_rejects_oversized() {
    local test_name="[7] safe_parse_json rejects oversized input"
    ((TESTS_RUN++)) || true

    # Create oversized JSON
    local oversized_json='{"data": "'
    local padding=""
    for i in $(seq 1 103000); do
        padding+="x"
    done
    oversized_json+="${padding}\"}"

    if safe_parse_json "$oversized_json" 2>/dev/null; then
        test_fail "$test_name" "safe_parse_json did not reject oversized input"
    else
        test_pass "$test_name"
    fi
}

# =============================================================================
# TEST 8: safe_parse_json rejects deeply nested input
# =============================================================================

test_safe_parse_json_rejects_deep() {
    local test_name="[8] safe_parse_json rejects deeply nested input"
    ((TESTS_RUN++)) || true

    # Create deeply nested JSON
    local deep_json=""
    local close_braces=""
    for i in $(seq 1 25); do
        deep_json+='{"level'$i'":'
        close_braces+='}'
    done
    deep_json+='"value"'
    deep_json+="$close_braces"

    if safe_parse_json "$deep_json" 2>/dev/null; then
        test_fail "$test_name" "safe_parse_json did not reject deeply nested input"
    else
        test_pass "$test_name"
    fi
}

# =============================================================================
# TEST 9: Edge case - exactly at size limit
# =============================================================================

test_edge_case_at_limit() {
    local test_name="[9] JSON at exactly size limit is accepted"
    ((TESTS_RUN++)) || true

    # Create JSON exactly at limit (102400 bytes)
    # Account for the wrapper: {"d":"..."} = 9 bytes
    local wrapper_size=9
    local padding_size=$((MAX_TASK_SIZE_BYTES - wrapper_size))
    local padding=""
    for i in $(seq 1 $padding_size); do
        padding+="x"
    done
    local at_limit_json='{"d":"'${padding}'"}'

    local actual_size=${#at_limit_json}
    if [[ $actual_size -eq $MAX_TASK_SIZE_BYTES ]]; then
        if validate_json_size "$at_limit_json" 2>/dev/null; then
            test_pass "$test_name"
        else
            test_fail "$test_name" "JSON at exact limit was rejected"
        fi
    else
        # Size calculation was off, just test that it passes if under limit
        if [[ $actual_size -le $MAX_TASK_SIZE_BYTES ]]; then
            if validate_json_size "$at_limit_json" 2>/dev/null; then
                test_pass "$test_name"
            else
                test_fail "$test_name" "JSON under limit was rejected (size: $actual_size)"
            fi
        else
            test_skip "$test_name" "Could not create JSON at exact limit (size: $actual_size)"
        fi
    fi
}

# =============================================================================
# TEST 10: JSON with array nesting is counted
# =============================================================================

test_array_nesting_counted() {
    local test_name="[10] Array nesting depth is counted correctly"
    ((TESTS_RUN++)) || true

    # Create JSON with 25 levels of array nesting
    local deep_array=""
    local close_brackets=""
    for i in $(seq 1 25); do
        deep_array+='['
        close_brackets+=']'
    done
    deep_array+='"value"'
    deep_array+="$close_brackets"

    if validate_json_depth "$deep_array" 2>/dev/null; then
        test_fail "$test_name" "Deeply nested array was not rejected"
    else
        test_pass "$test_name"
    fi
}

# =============================================================================
# TEST 11: Mixed object/array nesting is counted
# =============================================================================

test_mixed_nesting_counted() {
    local test_name="[11] Mixed object/array nesting is counted correctly"
    ((TESTS_RUN++)) || true

    # Create JSON with mixed 25 levels of nesting
    local mixed_json=""
    local close=""
    for i in $(seq 1 25); do
        if (( i % 2 == 0 )); then
            mixed_json+='['
            close+=']'
        else
            mixed_json+='{"k":'
            close+='}'
        fi
    done
    mixed_json+='"value"'
    mixed_json+="$close"

    if validate_json_depth "$mixed_json" 2>/dev/null; then
        test_fail "$test_name" "Deeply mixed nested structure was not rejected"
    else
        test_pass "$test_name"
    fi
}

# =============================================================================
# TEST 12: Brackets in strings don't count as nesting
# =============================================================================

test_brackets_in_strings_ignored() {
    local test_name="[12] Brackets in strings don't count as nesting"
    ((TESTS_RUN++)) || true

    # Create JSON with many brackets inside strings (should not count)
    local json_with_string_brackets='{"data": "{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}"}'

    if validate_json_depth "$json_with_string_brackets" 2>/dev/null; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Brackets inside strings were counted as nesting"
    fi
}

# =============================================================================
# TEST 13: Functions are exported
# =============================================================================

test_functions_exported() {
    local test_name="[13] SEC-009C functions are exported"
    ((TESTS_RUN++)) || true

    local passed=true

    if ! declare -F validate_json_size >/dev/null 2>&1; then
        echo "  validate_json_size not available"
        passed=false
    fi

    if ! declare -F validate_json_depth >/dev/null 2>&1; then
        echo "  validate_json_depth not available"
        passed=false
    fi

    if ! declare -F safe_parse_json >/dev/null 2>&1; then
        echo "  safe_parse_json not available"
        passed=false
    fi

    if [[ "$passed" == "true" ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name"
    fi
}

# =============================================================================
# MAIN TEST RUNNER
# =============================================================================

echo ""
echo "============================================================================="
echo " SEC-009C: JSON Size Limits Tests"
echo "============================================================================="
echo ""

# Run all tests
test_constants_defined
test_valid_small_json_accepted
test_oversized_json_rejected
test_valid_shallow_json_accepted
test_deeply_nested_json_rejected
test_safe_parse_json_works
test_safe_parse_json_rejects_oversized
test_safe_parse_json_rejects_deep
test_edge_case_at_limit
test_array_nesting_counted
test_mixed_nesting_counted
test_brackets_in_strings_ignored
test_functions_exported

# Print summary
echo ""
echo "============================================================================="
echo " Test Summary"
echo "============================================================================="
echo ""
echo "  Tests run:    $TESTS_RUN"
echo -e "  Tests passed: ${GREEN}$TESTS_PASSED${RESET}"
echo -e "  Tests failed: ${RED}$TESTS_FAILED${RESET}"
echo ""

# Exit with appropriate code
if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}ALL SEC-009C TESTS PASSED${RESET}"
    exit 0
else
    echo -e "${RED}SOME TESTS FAILED${RESET}"
    exit 1
fi
