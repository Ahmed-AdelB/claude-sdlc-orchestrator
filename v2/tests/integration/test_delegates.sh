#!/bin/bash
#===============================================================================
# test_delegates.sh - Integration tests for delegate scripts
#===============================================================================

set -euo pipefail

# Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(dirname "$(dirname "$SCRIPT_DIR")")}"
BIN_DIR="${PROJECT_ROOT}/bin"

# Test counters
TESTS_PASSED=${TESTS_PASSED:-0}
TESTS_FAILED=${TESTS_FAILED:-0}

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
# Tests
#===============================================================================

echo ""
echo "Testing delegate scripts..."

# Test 1: claude-delegate exists
test_claude_delegate_exists() {
    if [[ -x "${BIN_DIR}/claude-delegate" ]]; then
        pass "claude-delegate: Script exists and is executable"
    else
        fail "claude-delegate: Not found or not executable"
    fi
}

# Test 2: claude-delegate shows help
test_claude_delegate_help() {
    local output
    output=$("${BIN_DIR}/claude-delegate" --help 2>&1 || true)

    if echo "$output" | grep -q "Usage"; then
        pass "claude-delegate --help: Shows usage"
    else
        fail "claude-delegate --help: No usage info"
    fi
}

# Test 3: claude-delegate returns JSON for missing prompt
test_claude_delegate_no_prompt() {
    local output
    output=$("${BIN_DIR}/claude-delegate" 2>&1 || true)

    if echo "$output" | grep -q '"status".*"error"'; then
        pass "claude-delegate: Returns JSON error for missing prompt"
    elif echo "$output" | grep -q 'ABSTAIN'; then
        pass "claude-delegate: Returns ABSTAIN for missing prompt"
    else
        fail "claude-delegate: Should return JSON error"
    fi
}

# Test 4: gemini-delegate exists
test_gemini_delegate_exists() {
    if [[ -x "${BIN_DIR}/gemini-delegate" ]]; then
        pass "gemini-delegate: Script exists and is executable"
    else
        fail "gemini-delegate: Not found or not executable"
    fi
}

# Test 5: gemini-delegate shows help
test_gemini_delegate_help() {
    local output
    output=$("${BIN_DIR}/gemini-delegate" --help 2>&1 || true)

    if echo "$output" | grep -q "Usage"; then
        pass "gemini-delegate --help: Shows usage"
    else
        fail "gemini-delegate --help: No usage info"
    fi
}

# Test 6: gemini-delegate returns JSON for missing prompt
test_gemini_delegate_no_prompt() {
    local output
    output=$("${BIN_DIR}/gemini-delegate" 2>&1 || true)

    if echo "$output" | grep -q '"status".*"error"'; then
        pass "gemini-delegate: Returns JSON error for missing prompt"
    elif echo "$output" | grep -q 'ABSTAIN'; then
        pass "gemini-delegate: Returns ABSTAIN for missing prompt"
    else
        fail "gemini-delegate: Should return JSON error"
    fi
}

# Test 7: codex-delegate exists
test_codex_delegate_exists() {
    if [[ -x "${BIN_DIR}/codex-delegate" ]]; then
        pass "codex-delegate: Script exists and is executable"
    else
        fail "codex-delegate: Not found or not executable"
    fi
}

# Test 8: codex-delegate shows help
test_codex_delegate_help() {
    local output
    output=$("${BIN_DIR}/codex-delegate" --help 2>&1 || true)

    if echo "$output" | grep -q "Usage"; then
        pass "codex-delegate --help: Shows usage"
    else
        fail "codex-delegate --help: No usage info"
    fi
}

# Test 9: codex-delegate returns JSON for missing prompt
test_codex_delegate_no_prompt() {
    local output
    output=$("${BIN_DIR}/codex-delegate" 2>&1 || true)

    if echo "$output" | grep -q '"status".*"error"'; then
        pass "codex-delegate: Returns JSON error for missing prompt"
    elif echo "$output" | grep -q 'ABSTAIN'; then
        pass "codex-delegate: Returns ABSTAIN for missing prompt"
    else
        fail "codex-delegate: Should return JSON error"
    fi
}

# Test 10: gemini-ask exists
test_gemini_ask_exists() {
    if [[ -x "${BIN_DIR}/gemini-ask" ]]; then
        pass "gemini-ask: Script exists and is executable"
    else
        fail "gemini-ask: Not found or not executable"
    fi
}

# Test 11: gemini-ask shows help
test_gemini_ask_help() {
    local output
    output=$("${BIN_DIR}/gemini-ask" --help 2>&1 || true)

    if echo "$output" | grep -q "Usage"; then
        pass "gemini-ask --help: Shows usage"
    else
        fail "gemini-ask --help: No usage info"
    fi
}

# Test 12: codex-ask exists
test_codex_ask_exists() {
    if [[ -x "${BIN_DIR}/codex-ask" ]]; then
        pass "codex-ask: Script exists and is executable"
    else
        fail "codex-ask: Not found or not executable"
    fi
}

# Test 13: codex-ask shows help
test_codex_ask_help() {
    local output
    output=$("${BIN_DIR}/codex-ask" --help 2>&1 || true)

    if echo "$output" | grep -q "Usage"; then
        pass "codex-ask --help: Shows usage"
    else
        fail "codex-ask --help: No usage info"
    fi
}

# Test 14: All delegates have consistent JSON envelope format
test_json_envelope_format() {
    # Check that all delegates define the same envelope structure
    local delegates=("claude-delegate" "gemini-delegate" "codex-delegate")
    local all_consistent=true

    for delegate in "${delegates[@]}"; do
        local file="${BIN_DIR}/${delegate}"
        if [[ -f "$file" ]]; then
            # Check for json_output function
            if grep -q "json_output" "$file" && grep -q "jq -n" "$file"; then
                : # Good
            else
                all_consistent=false
                break
            fi
        fi
    done

    if [[ "$all_consistent" == "true" ]]; then
        pass "delegates: All have consistent JSON envelope format"
    else
        fail "delegates: Inconsistent JSON envelope format"
    fi
}

# Test 15: All delegates mask secrets
test_delegates_mask_secrets() {
    local delegates=("claude-delegate" "gemini-delegate" "codex-delegate")
    local all_mask=true

    for delegate in "${delegates[@]}"; do
        local file="${BIN_DIR}/${delegate}"
        if [[ -f "$file" ]]; then
            if grep -q "mask_secrets" "$file"; then
                : # Good
            else
                all_mask=false
                break
            fi
        fi
    done

    if [[ "$all_mask" == "true" ]]; then
        pass "delegates: All mask secrets"
    else
        fail "delegates: Not all mask secrets"
    fi
}

# Test 16: All delegates have timeout handling
test_delegates_timeout() {
    local delegates=("claude-delegate" "gemini-delegate" "codex-delegate")
    local all_timeout=true

    for delegate in "${delegates[@]}"; do
        local file="${BIN_DIR}/${delegate}"
        if [[ -f "$file" ]]; then
            if grep -q "timeout" "$file" && grep -q "TIMEOUT" "$file"; then
                : # Good
            else
                all_timeout=false
                break
            fi
        fi
    done

    if [[ "$all_timeout" == "true" ]]; then
        pass "delegates: All have timeout handling"
    else
        fail "delegates: Not all have timeout handling"
    fi
}

# Test 17: cost-tracker exists
test_cost_tracker_exists() {
    if [[ -x "${BIN_DIR}/cost-tracker" ]]; then
        pass "cost-tracker: Script exists and is executable"
    else
        fail "cost-tracker: Not found or not executable"
    fi
}

# Test 18: cost-tracker shows help
test_cost_tracker_help() {
    local output
    output=$("${BIN_DIR}/cost-tracker" --help 2>&1 || true)

    if echo "$output" | grep -q "Usage"; then
        pass "cost-tracker --help: Shows usage"
    else
        fail "cost-tracker --help: No usage info"
    fi
}

#===============================================================================
# Run Tests
#===============================================================================

test_claude_delegate_exists
test_claude_delegate_help
test_claude_delegate_no_prompt
test_gemini_delegate_exists
test_gemini_delegate_help
test_gemini_delegate_no_prompt
test_codex_delegate_exists
test_codex_delegate_help
test_codex_delegate_no_prompt
test_gemini_ask_exists
test_gemini_ask_help
test_codex_ask_exists
test_codex_ask_help
test_json_envelope_format
test_delegates_mask_secrets
test_delegates_timeout
test_cost_tracker_exists
test_cost_tracker_help

export TESTS_PASSED TESTS_FAILED

echo ""
echo "delegate tests completed: $TESTS_PASSED passed, $TESTS_FAILED failed"
