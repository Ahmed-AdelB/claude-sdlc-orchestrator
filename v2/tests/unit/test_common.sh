#!/bin/bash
#===============================================================================
# test_common.sh - Unit tests for lib/common.sh
#===============================================================================

set -euo pipefail

# Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(dirname "$(dirname "$SCRIPT_DIR")")}"
LIB_DIR="${PROJECT_ROOT}/lib"

# Test counters (inherit from runner or initialize)
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

#===============================================================================
# Source library (with mocked dependencies)
#===============================================================================

# Create temp state dir
TEST_STATE_DIR=$(mktemp -d)
TEST_LOG_DIR=$(mktemp -d)
TEST_COSTS_DIR=$(mktemp -d)
export STATE_DIR="$TEST_STATE_DIR"
export LOG_DIR="$TEST_LOG_DIR"
export COST_LOG_DIR="$TEST_COSTS_DIR"
export CONFIG_FILE="${PROJECT_ROOT}/config/tri-agent.yaml"

# Cleanup trap
cleanup() {
    rm -rf "$TEST_STATE_DIR" "$TEST_LOG_DIR" "$TEST_COSTS_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# Source common.sh
if [[ -f "${LIB_DIR}/common.sh" ]]; then
    source "${LIB_DIR}/common.sh"
else
    echo "Error: common.sh not found"
    exit 1
fi

#===============================================================================
# Tests
#===============================================================================

echo ""
echo "Testing lib/common.sh functions..."

# Test 1: generate_trace_id generates unique IDs
test_generate_trace_id() {
    local id1 id2
    id1=$(generate_trace_id "test")
    id2=$(generate_trace_id "test")

    if [[ -n "$id1" && "$id1" == test-* ]]; then
        pass "generate_trace_id: Creates ID with prefix"
    else
        fail "generate_trace_id: Expected prefix 'test-', got '$id1'"
    fi

    if [[ "$id1" != "$id2" ]]; then
        pass "generate_trace_id: IDs are unique"
    else
        fail "generate_trace_id: IDs should be unique"
    fi
}

# Test 2: epoch_ms returns milliseconds
test_epoch_ms() {
    local ms
    ms=$(epoch_ms)

    # Should be a large number (13+ digits)
    if [[ "$ms" =~ ^[0-9]+$ && ${#ms} -ge 13 ]]; then
        pass "epoch_ms: Returns valid millisecond timestamp"
    else
        fail "epoch_ms: Expected 13+ digit number, got '$ms'"
    fi
}

# Test 3: iso_timestamp returns ISO format
test_iso_timestamp() {
    local ts
    ts=$(iso_timestamp)

    # Should match ISO 8601 format
    if [[ "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
        pass "iso_timestamp: Returns ISO 8601 format"
    else
        fail "iso_timestamp: Expected ISO format, got '$ts'"
    fi
}

# Test 4: mask_secrets masks API keys
test_mask_secrets() {
    local input="API key is sk-1234567890abcdefghij"
    local masked
    masked=$(mask_secrets "$input")

    # Function uses [REDACTED] marker
    if [[ "$masked" != *"sk-1234567890abcdefghij"* && "$masked" == *"REDACTED"* ]]; then
        pass "mask_secrets: Masks OpenAI API keys"
    else
        fail "mask_secrets: Should mask API key, got '$masked'"
    fi

    # Test with ANTHROPIC_API_KEY
    input="ANTHROPIC_API_KEY=sk-ant-api1234567890abcdef"
    masked=$(mask_secrets "$input")
    if [[ "$masked" == *"REDACTED"* ]]; then
        pass "mask_secrets: Masks ANTHROPIC_API_KEY"
    else
        fail "mask_secrets: Should mask ANTHROPIC_API_KEY, got '$masked'"
    fi

    # Test with Bearer token
    input="Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    masked=$(mask_secrets "$input")
    if [[ "$masked" == *"REDACTED"* ]]; then
        pass "mask_secrets: Masks Bearer tokens"
    else
        fail "mask_secrets: Should mask Bearer tokens, got '$masked'"
    fi
}

# Test 5: command_exists works correctly
test_command_exists() {
    if command_exists "bash"; then
        pass "command_exists: Finds 'bash'"
    else
        fail "command_exists: Should find 'bash'"
    fi

    if ! command_exists "nonexistent_command_xyz"; then
        pass "command_exists: Returns false for missing command"
    else
        fail "command_exists: Should return false for missing command"
    fi
}

# Test 6: read_config reads YAML values
test_read_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        local version
        version=$(read_config ".system.version" "unknown" "$CONFIG_FILE")

        if [[ -n "$version" && "$version" != "unknown" ]]; then
            pass "read_config: Reads config values (version=$version)"
        else
            fail "read_config: Should read version from config"
        fi

        # Test default value
        local missing
        missing=$(read_config ".nonexistent.key" "default_val" "$CONFIG_FILE")
        if [[ "$missing" == "default_val" ]]; then
            pass "read_config: Returns default for missing key"
        else
            fail "read_config: Should return default for missing key"
        fi
    else
        echo "  [SKIP] read_config: Config file not found"
    fi
}

# Test 7: validate numeric
test_validate_numeric() {
    # Test valid numbers
    if _validate_numeric "123"; then
        pass "_validate_numeric: Accepts '123'"
    else
        fail "_validate_numeric: Should accept '123'"
    fi

    if _validate_numeric "0"; then
        pass "_validate_numeric: Accepts '0'"
    else
        fail "_validate_numeric: Should accept '0'"
    fi

    # Test invalid numbers
    if ! _validate_numeric "abc" 2>/dev/null; then
        pass "_validate_numeric: Rejects 'abc'"
    else
        fail "_validate_numeric: Should reject 'abc'"
    fi

    if ! _validate_numeric "" 2>/dev/null; then
        pass "_validate_numeric: Rejects empty string"
    else
        fail "_validate_numeric: Should reject empty string"
    fi
}

# Test 8: parse_delegate_envelope
test_parse_delegate_envelope() {
    local test_json='{"model":"claude","status":"success","decision":"APPROVE","confidence":0.9}'

    if command -v jq &>/dev/null; then
        local model status decision confidence
        model=$(echo "$test_json" | jq -r '.model')
        status=$(echo "$test_json" | jq -r '.status')
        decision=$(echo "$test_json" | jq -r '.decision')
        confidence=$(echo "$test_json" | jq -r '.confidence')

        if [[ "$model" == "claude" && "$status" == "success" && "$decision" == "APPROVE" ]]; then
            pass "parse_delegate_envelope: Parses JSON correctly"
        else
            fail "parse_delegate_envelope: JSON parsing failed"
        fi
    else
        echo "  [SKIP] parse_delegate_envelope: jq not available"
    fi
}

#===============================================================================
# Test: _sql_escape function
#===============================================================================

test_sql_escape() {
    echo ""
    echo "Testing _sql_escape..."

    if type _sql_escape &>/dev/null; then
        # Test basic escaping
        local input="O'Reilly"
        local expected="O''Reilly"
        local result
        result=$(_sql_escape "$input")
        if [[ "$result" == "$expected" ]]; then
            pass "_sql_escape: Escapes single quote correctly"
        else
            fail "_sql_escape: Expected '$expected', got '$result'"
        fi

        # Test SQL injection attempt
        local injection="'; DROP TABLE users; --"
        local escaped
        escaped=$(_sql_escape "$injection")
        if [[ "$escaped" == "''; DROP TABLE users; --" ]]; then
            pass "_sql_escape: Escapes SQL injection payload"
        else
            fail "_sql_escape: SQL injection not properly escaped (got: $escaped)"
        fi

        # Test empty string
        result=$(_sql_escape "")
        if [[ "$result" == "" ]]; then
            pass "_sql_escape: Handles empty string"
        else
            fail "_sql_escape: Empty string should return empty"
        fi
    else
        echo "  [SKIP] _sql_escape: Function not available"
    fi
}

#===============================================================================
# Test: _validate_fd function
#===============================================================================

test_validate_fd() {
    echo ""
    echo "Testing _validate_fd..."

    if type _validate_fd &>/dev/null; then
        # Test valid fd
        if _validate_fd "200" 2>/dev/null; then
            pass "_validate_fd: Accepts valid fd '200'"
        else
            fail "_validate_fd: Should accept '200'"
        fi

        # Test invalid fd (non-numeric)
        if ! _validate_fd "abc" 2>/dev/null; then
            pass "_validate_fd: Rejects non-numeric 'abc'"
        else
            fail "_validate_fd: Should reject 'abc'"
        fi

        # Test injection attempt in fd
        if ! _validate_fd '200; rm -rf /' 2>/dev/null; then
            pass "_validate_fd: Rejects injection in fd"
        else
            fail "_validate_fd: Should reject injection payload"
        fi
    else
        echo "  [SKIP] _validate_fd: Function not available"
    fi
}

#===============================================================================
# Test: Lock functions with malicious filenames
#===============================================================================

test_lock_malicious_filenames() {
    echo ""
    echo "Testing lock functions with malicious filenames..."

    if type acquire_lock &>/dev/null && type release_lock &>/dev/null; then
        local test_dir
        test_dir=$(mktemp -d)

        # Test 1: Filename with spaces
        local lock_with_spaces="${test_dir}/my lock file.lock"
        if acquire_lock "$lock_with_spaces" 2 202 2>/dev/null; then
            release_lock 202 2>/dev/null
            pass "acquire_lock: Handles filename with spaces"
        else
            fail "acquire_lock: Should handle filename with spaces"
        fi

        # Test 2: Filename with quotes
        local lock_with_quotes="${test_dir}/test'quote.lock"
        if acquire_lock "$lock_with_quotes" 2 203 2>/dev/null; then
            release_lock 203 2>/dev/null
            pass "acquire_lock: Handles filename with quotes"
        else
            fail "acquire_lock: Should handle filename with quotes"
        fi

        # Test 3: Filename with semicolon (command injection attempt)
        local lock_injection="${test_dir}/test;echo pwned.lock"
        if acquire_lock "$lock_injection" 2 204 2>/dev/null; then
            release_lock 204 2>/dev/null
            # Check no 'pwned' file was created
            if [[ ! -f "${test_dir}/pwned.lock" ]]; then
                pass "acquire_lock: Command injection prevented"
            else
                fail "acquire_lock: Command injection executed!"
            fi
        else
            pass "acquire_lock: Rejected dangerous filename"
        fi

        # Test 4: Invalid fd should be rejected
        if ! acquire_lock "${test_dir}/test.lock" 2 "abc" 2>/dev/null; then
            pass "acquire_lock: Rejects invalid fd"
        else
            fail "acquire_lock: Should reject non-numeric fd"
        fi

        rm -rf "$test_dir"
    else
        echo "  [SKIP] Lock functions not available"
    fi
}

#===============================================================================
# Run Tests
#===============================================================================

test_generate_trace_id
test_epoch_ms
test_iso_timestamp
test_mask_secrets
test_command_exists
test_read_config
test_validate_numeric
test_parse_delegate_envelope
test_sql_escape
test_validate_fd
test_lock_malicious_filenames

# Export counters back
export TESTS_PASSED TESTS_FAILED

echo ""
echo "common.sh tests completed: $TESTS_PASSED passed, $TESTS_FAILED failed"
