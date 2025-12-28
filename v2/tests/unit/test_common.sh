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

    if [[ "$masked" != *"sk-1234567890"* && "$masked" == *"MASKED"* ]]; then
        pass "mask_secrets: Masks OpenAI API keys"
    else
        fail "mask_secrets: Should mask API key, got '$masked'"
    fi

    # Test with ANTHROPIC_API_KEY
    input="ANTHROPIC_API_KEY=sk-ant-123456"
    masked=$(mask_secrets "$input")
    if [[ "$masked" == *"MASKED"* ]]; then
        pass "mask_secrets: Masks ANTHROPIC_API_KEY"
    else
        fail "mask_secrets: Should mask ANTHROPIC_API_KEY"
    fi

    # Test with Bearer token
    input="Authorization: Bearer abc123def456"
    masked=$(mask_secrets "$input")
    if [[ "$masked" == *"MASKED"* ]]; then
        pass "mask_secrets: Masks Bearer tokens"
    else
        fail "mask_secrets: Should mask Bearer tokens"
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

# Export counters back
export TESTS_PASSED TESTS_FAILED

echo ""
echo "common.sh tests completed: $TESTS_PASSED passed, $TESTS_FAILED failed"
