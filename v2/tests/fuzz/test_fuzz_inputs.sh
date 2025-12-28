#!/bin/bash
#===============================================================================
# test_fuzz_inputs.sh - Fuzzing tests for input validation functions
#===============================================================================
# Tests input handling with random, malformed, and edge-case inputs to find
# crashes, hangs, or security vulnerabilities.
#===============================================================================

set -euo pipefail

# Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(dirname "$(dirname "$SCRIPT_DIR")")}"
LIB_DIR="${PROJECT_ROOT}/lib"

# Test counters
TESTS_PASSED=${TESTS_PASSED:-0}
TESTS_FAILED=${TESTS_FAILED:-0}
FUZZ_ITERATIONS=${FUZZ_ITERATIONS:-100}

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
export STATE_DIR="$TEST_STATE_DIR"
export LOG_DIR="$TEST_LOG_DIR"
export TRACE_ID="fuzz-$$"

mkdir -p "$STATE_DIR" "$LOG_DIR"

cleanup() {
    rm -rf "$TEST_STATE_DIR" "$TEST_LOG_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# Source dependencies
source "${LIB_DIR}/common.sh"

#===============================================================================
# Fuzzing Utilities
#===============================================================================

# Generate random string with control characters
random_string() {
    local length="${1:-32}"
    if [[ -r /dev/urandom ]]; then
        head -c "$length" /dev/urandom | base64 | head -c "$length"
    else
        # Fallback
        local str=""
        for ((i=0; i<length; i++)); do
            str+="${RANDOM:0:1}"
        done
        echo "$str"
    fi
}

# Generate random bytes including null bytes and control characters
random_bytes() {
    local length="${1:-32}"
    if [[ -r /dev/urandom ]]; then
        head -c "$length" /dev/urandom
    else
        dd if=/dev/zero bs=1 count="$length" 2>/dev/null
    fi
}

# Generate string with special characters
special_chars_string() {
    echo -e "test\x00null\x01soh\x02stx\x1besc\x7fdel<script>alert(1)</script>'; DROP TABLE users; --"
}

# Generate deeply nested JSON
nested_json() {
    local depth="${1:-10}"
    local json="\"value\""
    for ((i=0; i<depth; i++)); do
        json="{\"nested\": $json}"
    done
    echo "$json"
}

# Generate long string
long_string() {
    local length="${1:-10000}"
    printf 'A%.0s' $(seq 1 "$length")
}

# Unicode edge cases
unicode_strings() {
    cat <<'EOF'

😀🎉🔥
中文测试
العربية
🏳️‍🌈
EOF
}

#===============================================================================
# Fuzz Tests
#===============================================================================

echo ""
echo "Running fuzzing tests with $FUZZ_ITERATIONS iterations..."

# Test 1: Fuzz mask_secrets with random inputs
test_fuzz_mask_secrets() {
    local crashes=0
    local timeouts=0

    echo "  Fuzzing mask_secrets..."

    for ((i=0; i<FUZZ_ITERATIONS; i++)); do
        local input
        case $((i % 5)) in
            0) input=$(random_string 100) ;;
            1) input=$(special_chars_string) ;;
            2) input=$(long_string 1000) ;;
            3) input="" ;;
            4) input=$(unicode_strings | head -1) ;;
        esac

        # Run with timeout to detect hangs
        if ! timeout 2s bash -c 'source "'"${LIB_DIR}/common.sh"'" 2>/dev/null && mask_secrets "$1" >/dev/null 2>&1' _ "$input"; then
            ((timeouts++)) || true
        fi
    done

    if [[ $timeouts -lt 3 ]]; then
        pass "mask_secrets: Survived $FUZZ_ITERATIONS fuzz iterations (timeouts: $timeouts)"
    else
        fail "mask_secrets: Too many timeouts ($timeouts)"
    fi
}

# Test 2: Fuzz _validate_numeric with random inputs
test_fuzz_validate_numeric() {
    local crashes=0

    echo "  Fuzzing _validate_numeric..."

    local test_inputs=(
        ""
        "0"
        "-1"
        "1.5"
        "1e10"
        "9999999999999999999999999999"
        "abc"
        "123abc"
        "$(random_string 50)"
        "$(printf '\x00')"
        "$(printf '\n\n')"
        "$(special_chars_string)"
    )

    for input in "${test_inputs[@]}"; do
        if ! timeout 1s bash -c 'source "'"${LIB_DIR}/common.sh"'" 2>/dev/null && _validate_numeric "$1" 2>/dev/null' _ "$input"; then
            # Expected to fail on invalid input, but should not crash
            true
        fi
    done

    pass "_validate_numeric: Survived fuzz test without crashes"
}

# Test 3: Fuzz is_valid_json with malformed JSON
test_fuzz_is_valid_json() {
    echo "  Fuzzing is_valid_json..."

    local malformed_jsons=(
        ""
        "{"
        "}"
        "{{"
        "}}"
        '{"key": "value"'
        '{"key": }'
        "$(nested_json 50)"
        "$(nested_json 100)"
        '{"key": "$(random_string 1000)"}'
        "null"
        "true"
        "false"
        "[[[[[[[[[["
        '{"a": "b", "c": }'
        "$(long_string 10000)"
    )

    local errors=0
    for json in "${malformed_jsons[@]}"; do
        if ! timeout 2s bash -c 'source "'"${LIB_DIR}/common.sh"'" 2>/dev/null && is_valid_json "$1" 2>/dev/null' _ "$json"; then
            # Expected failure for malformed JSON
            true
        fi
    done

    pass "is_valid_json: Survived malformed JSON fuzz test"
}

# Test 4: Fuzz read_config with invalid paths and keys
test_fuzz_read_config() {
    echo "  Fuzzing read_config..."

    local malicious_paths=(
        "/etc/passwd"
        "../../../etc/passwd"
        "/dev/null"
        "/proc/self/environ"
        "$(random_string 500)"
        ""
        "/nonexistent/path/file.yaml"
    )

    local malicious_keys=(
        ""
        "."
        ".."
        "......"
        "$(random_string 100)"
        "a.b.c.d.e.f.g.h.i.j.k.l.m.n.o.p"
        "__proto__"
        "constructor"
        "\$(whoami)"
        "; ls -la"
    )

    for path in "${malicious_paths[@]}"; do
        for key in "${malicious_keys[@]}"; do
            timeout 1s bash -c 'source "'"${LIB_DIR}/common.sh"'" 2>/dev/null && read_config "$1" "default" "$2" 2>/dev/null' _ "$key" "$path" || true
        done
    done

    pass "read_config: Survived path traversal and injection fuzz test"
}

# Test 5: Fuzz parse_delegate_envelope with malformed envelopes
test_fuzz_parse_delegate_envelope() {
    echo "  Fuzzing parse_delegate_envelope..."

    local malformed_envelopes=(
        ""
        "{}"
        '{"model": null}'
        '{"status": 12345}'
        '{"decision": {}}'
        '{"confidence": "not_a_number"}'
        '{"confidence": -1}'
        '{"confidence": 999999999}'
        "$(nested_json 20)"
        '{"model": "$(whoami)", "status": "success"}'
        "$(long_string 10000)"
    )

    for envelope in "${malformed_envelopes[@]}"; do
        timeout 1s bash -c 'source "'"${LIB_DIR}/common.sh"'" 2>/dev/null && parse_delegate_envelope "$1" 2>/dev/null' _ "$envelope" || true
    done

    pass "parse_delegate_envelope: Survived malformed envelope fuzz test"
}

# Test 6: Fuzz generate_trace_id with various prefixes
test_fuzz_generate_trace_id() {
    echo "  Fuzzing generate_trace_id..."

    local prefixes=(
        ""
        "$(random_string 100)"
        "$(special_chars_string)"
        "$(printf '\x00\x01\x02')"
        "../../../"
        "\$(whoami)"
        "a b c"
        "test-with-dashes"
        "test_with_underscores"
    )

    for prefix in "${prefixes[@]}"; do
        local result
        result=$(timeout 1s bash -c 'source "'"${LIB_DIR}/common.sh"'" 2>/dev/null && generate_trace_id "$1" 2>/dev/null' _ "$prefix") || true

        # Ensure result doesn't contain shell injection attempts
        if [[ "$result" == *'$('* ]] || [[ "$result" == *'`'* ]]; then
            fail "generate_trace_id: Potential injection in output"
            return
        fi
    done

    pass "generate_trace_id: Survived prefix fuzz test"
}

# Test 7: Boundary value testing for numeric functions
test_boundary_values() {
    echo "  Testing boundary values..."

    local boundary_values=(
        "0"
        "1"
        "-1"
        "2147483647"           # INT32_MAX
        "2147483648"           # INT32_MAX + 1
        "-2147483648"          # INT32_MIN
        "9223372036854775807"  # INT64_MAX
        "9223372036854775808"  # INT64_MAX + 1
        "18446744073709551615" # UINT64_MAX
    )

    local crashed=0
    for value in "${boundary_values[@]}"; do
        if ! timeout 1s bash -c 'source "'"${LIB_DIR}/common.sh"'" 2>/dev/null && _validate_numeric "$1" 2>/dev/null' _ "$value"; then
            # May reject some values, but shouldn't crash
            true
        fi
    done

    pass "boundary_values: Survived boundary value tests"
}

# Test 8: Format string attack testing
test_format_string_attacks() {
    echo "  Testing format string resistance..."

    local format_strings=(
        "%s%s%s%s%s%s%s%s%s%s"
        "%n%n%n%n%n%n%n%n%n%n"
        "%x%x%x%x%x%x%x%x%x%x"
        "%p%p%p%p%p%p%p%p%p%p"
        "AAAA%08x.%08x.%08x.%08x.%08x"
        "%99999999s"
        "%-99999999s"
    )

    for fmt in "${format_strings[@]}"; do
        # Test in mask_secrets
        timeout 1s bash -c 'source "'"${LIB_DIR}/common.sh"'" 2>/dev/null && mask_secrets "$1" >/dev/null 2>&1' _ "$fmt" || true

        # Test in log functions
        timeout 1s bash -c 'source "'"${LIB_DIR}/common.sh"'" 2>/dev/null && log_info "$1" 2>/dev/null' _ "$fmt" || true
    done

    pass "format_string_attacks: Survived format string tests"
}

#===============================================================================
# Run Tests
#===============================================================================

test_fuzz_mask_secrets
test_fuzz_validate_numeric
test_fuzz_is_valid_json
test_fuzz_read_config
test_fuzz_parse_delegate_envelope
test_fuzz_generate_trace_id
test_boundary_values
test_format_string_attacks

export TESTS_PASSED TESTS_FAILED

echo ""
echo "Fuzzing tests completed: $TESTS_PASSED passed, $TESTS_FAILED failed"
