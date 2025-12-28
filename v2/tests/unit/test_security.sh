#!/bin/bash
#===============================================================================
# test_security.sh - Unit tests for security.sh
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
source "${LIB_DIR}/security.sh"

echo ""
echo "=================================================="
echo "  SECURITY LIBRARY UNIT TESTS"
echo "=================================================="

#===============================================================================
# Test: Input Length Validation
#===============================================================================

echo ""
echo "--- Input Length Validation ---"

test_input_length_valid() {
    local short_input="Hello World"

    if validate_input_length "$short_input" 100; then
        pass "Input length: Short input accepted"
    else
        fail "Input length: Short input rejected"
    fi
}
test_input_length_valid

test_input_length_exceeded() {
    local long_input
    long_input=$(printf 'A%.0s' {1..200})

    if ! validate_input_length "$long_input" 100 2>/dev/null; then
        pass "Input length: Long input rejected"
    else
        fail "Input length: Long input should be rejected"
    fi
}
test_input_length_exceeded

#===============================================================================
# Test: Dangerous Pattern Detection
#===============================================================================

echo ""
echo "--- Dangerous Pattern Detection ---"

test_detect_rm_command() {
    local dangerous="; rm -rf /"

    if ! check_dangerous_patterns "$dangerous" 2>/dev/null; then
        pass "Dangerous patterns: Detected 'rm' command"
    else
        fail "Dangerous patterns: Failed to detect 'rm' command"
    fi
}
test_detect_rm_command

test_detect_path_traversal() {
    local traversal="../../../etc/passwd"

    if ! check_dangerous_patterns "$traversal" 2>/dev/null; then
        pass "Dangerous patterns: Detected path traversal"
    else
        fail "Dangerous patterns: Failed to detect path traversal"
    fi
}
test_detect_path_traversal

test_safe_input() {
    local safe="Hello, this is a normal message!"

    if check_dangerous_patterns "$safe" 2>/dev/null; then
        pass "Dangerous patterns: Safe input accepted"
    else
        fail "Dangerous patterns: False positive on safe input"
    fi
}
test_safe_input

#===============================================================================
# Test: Secret Detection
#===============================================================================

echo ""
echo "--- Secret Detection ---"

test_detect_openai_key() {
    local text="My API key is sk-1234567890abcdef1234567890abcdef1234567890abcdef12"

    if ! check_secrets "$text" 2>/dev/null; then
        pass "Secret detection: Detected OpenAI key pattern"
    else
        fail "Secret detection: Failed to detect OpenAI key"
    fi
}
test_detect_openai_key

test_detect_github_token() {
    local text="token: ghp_abcdefghijklmnopqrstuvwxyz1234567890"

    if ! check_secrets "$text" 2>/dev/null; then
        pass "Secret detection: Detected GitHub token"
    else
        fail "Secret detection: Failed to detect GitHub token"
    fi
}
test_detect_github_token

test_detect_password_config() {
    local config='password = "supersecret123"'

    if ! check_secrets "$config" 2>/dev/null; then
        pass "Secret detection: Detected password in config"
    else
        fail "Secret detection: Failed to detect password"
    fi
}
test_detect_password_config

test_no_false_positives() {
    local safe="This is just normal text without any secrets"

    if check_secrets "$safe" 2>/dev/null; then
        pass "Secret detection: No false positive on normal text"
    else
        fail "Secret detection: False positive on safe text"
    fi
}
test_no_false_positives

#===============================================================================
# Test: Secret Redaction
#===============================================================================

echo ""
echo "--- Secret Redaction ---"

test_redact_openai_key() {
    local text="Key: sk-1234567890abcdef1234567890abcdef1234567890abcdef12"
    local redacted
    redacted=$(redact_secrets "$text")

    if [[ "$redacted" == *"REDACTED"* ]] && [[ "$redacted" != *"1234567890"* ]]; then
        pass "Redaction: OpenAI key redacted"
    else
        fail "Redaction: OpenAI key not properly redacted"
    fi
}
test_redact_openai_key

test_redact_github_token() {
    local text="ghp_abcdefghijklmnopqrstuvwxyz1234567890"
    local redacted
    redacted=$(redact_secrets "$text")

    if [[ "$redacted" == *"REDACTED"* ]]; then
        pass "Redaction: GitHub token redacted"
    else
        fail "Redaction: GitHub token not redacted"
    fi
}
test_redact_github_token

#===============================================================================
# Test: Path Validation
#===============================================================================

echo ""
echo "--- Path Validation ---"

test_valid_path() {
    local base_dir="$TEST_DIR"
    mkdir -p "${base_dir}/subdir"

    local result
    result=$(validate_path "${base_dir}/subdir" "$base_dir")

    if [[ -n "$result" ]]; then
        pass "Path validation: Valid path accepted"
    else
        fail "Path validation: Valid path rejected"
    fi
}
test_valid_path

test_path_traversal_blocked() {
    local base_dir="$TEST_DIR"

    if ! validate_path "${base_dir}/../../../etc/passwd" "$base_dir" 2>/dev/null; then
        pass "Path validation: Traversal blocked"
    else
        fail "Path validation: Traversal not blocked"
    fi
}
test_path_traversal_blocked

#===============================================================================
# Test: Secure File Operations
#===============================================================================

echo ""
echo "--- Secure File Operations ---"

test_secure_write_read() {
    local file="${TEST_DIR}/secure_test.txt"
    local content="Secure content"

    if secure_write "$file" "$content" "$TEST_DIR" 2>/dev/null; then
        local read_content
        read_content=$(secure_read "$file" "$TEST_DIR" 2>/dev/null)

        if [[ "$read_content" == "$content" ]]; then
            pass "Secure file ops: Write and read successful"
        else
            fail "Secure file ops: Content mismatch"
        fi
    else
        fail "Secure file ops: Write failed"
    fi
}
test_secure_write_read

test_secure_read_outside_base() {
    if ! secure_read "/etc/passwd" "$TEST_DIR" 2>/dev/null; then
        pass "Secure file ops: Read outside base blocked"
    else
        fail "Secure file ops: Read outside base not blocked"
    fi
}
test_secure_read_outside_base

#===============================================================================
# Test: JSON Validation
#===============================================================================

echo ""
echo "--- JSON Validation ---"

test_valid_json() {
    local json='{"key": "value", "number": 42}'

    if validate_json "$json" 2>/dev/null; then
        pass "JSON validation: Valid JSON accepted"
    else
        fail "JSON validation: Valid JSON rejected"
    fi
}
test_valid_json

test_invalid_json() {
    local invalid='{"key": "value",}'

    if ! validate_json "$invalid" 2>/dev/null; then
        pass "JSON validation: Invalid JSON rejected"
    else
        fail "JSON validation: Invalid JSON accepted"
    fi
}
test_invalid_json

#===============================================================================
# Test: Random Generation
#===============================================================================

echo ""
echo "--- Secure Random Generation ---"

test_secure_random_hex() {
    local random
    random=$(secure_random 32 hex)

    if [[ ${#random} -ge 32 ]] && [[ "$random" =~ ^[0-9a-f]+$ ]]; then
        pass "Secure random: Hex generation works"
    else
        fail "Secure random: Hex generation failed"
    fi
}
test_secure_random_hex

test_secure_random_alphanumeric() {
    local random
    random=$(secure_random 16 alphanumeric)

    if [[ ${#random} -ge 16 ]] && [[ "$random" =~ ^[a-zA-Z0-9]+$ ]]; then
        pass "Secure random: Alphanumeric generation works"
    else
        fail "Secure random: Alphanumeric generation failed"
    fi
}
test_secure_random_alphanumeric

#===============================================================================
# Test: Hashing
#===============================================================================

echo ""
echo "--- Hashing ---"

test_hash_consistent() {
    local data="test data"
    local hash1
    local hash2

    hash1=$(hash_sensitive "$data")
    hash2=$(hash_sensitive "$data")

    if [[ "$hash1" == "$hash2" ]]; then
        pass "Hashing: Consistent hash output"
    else
        fail "Hashing: Inconsistent hash"
    fi
}
test_hash_consistent

test_hash_different_inputs() {
    local hash1
    local hash2

    hash1=$(hash_sensitive "data1")
    hash2=$(hash_sensitive "data2")

    if [[ "$hash1" != "$hash2" ]]; then
        pass "Hashing: Different inputs produce different hashes"
    else
        fail "Hashing: Collision detected"
    fi
}
test_hash_different_inputs

#===============================================================================
# Test: Input Validation Combined
#===============================================================================

echo ""
echo "--- Combined Input Validation ---"

test_validate_input_safe() {
    local safe="This is safe input"

    if validate_input "$safe"; then
        pass "Combined validation: Safe input passes"
    else
        fail "Combined validation: Safe input rejected"
    fi
}
test_validate_input_safe

test_validate_input_with_secret() {
    local with_secret="API key: sk-1234567890abcdef1234567890abcdef1234567890abcdef12"

    if ! validate_input "$with_secret" 2>/dev/null; then
        pass "Combined validation: Input with secret rejected"
    else
        fail "Combined validation: Input with secret accepted"
    fi
}
test_validate_input_with_secret

test_validate_input_skip_secret_check() {
    local with_secret="API key: sk-1234567890abcdef1234567890abcdef1234567890abcdef12"

    if validate_input "$with_secret" --no-secrets 2>/dev/null; then
        pass "Combined validation: Secret check skipped when requested"
    else
        fail "Combined validation: --no-secrets flag not working"
    fi
}
test_validate_input_skip_secret_check

#===============================================================================
# Summary
#===============================================================================

echo ""
echo "=================================================="
echo "  SECURITY LIBRARY TEST SUMMARY"
echo "=================================================="
echo ""
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo ""

export TESTS_PASSED TESTS_FAILED
