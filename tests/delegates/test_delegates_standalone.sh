#!/bin/bash
#===============================================================================
# test_delegates_standalone.sh - Standalone tests for delegate scripts
#===============================================================================
# This test file runs without BATS and can be executed directly.
# It tests CLI invocation patterns, error handling, timeout behavior, and
# return code handling for all three delegate scripts.
#
# Usage:
#   ./test_delegates_standalone.sh
#   TEST_BIN_DIR=/path/to/bin ./test_delegates_standalone.sh
#   DEBUG=1 ./test_delegates_standalone.sh
#===============================================================================

# Don't use set -e since assertions can return 1
set -uo pipefail

# Load helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.bash"

#===============================================================================
# Test Configuration
#===============================================================================
DEBUG="${DEBUG:-0}"

debug_log() {
    [[ "$DEBUG" == "1" ]] && echo "[DEBUG] $*" >&2 || true
}

#===============================================================================
# Test Suite: Claude Delegate
#===============================================================================

test_claude_delegate_exists() {
    echo -e "\n${CYAN}Testing claude-delegate existence...${RESET}"

    if delegate_exists "claude-delegate"; then
        assert_equals "1" "1" "claude-delegate: Script exists and is executable" || true
    else
        assert_equals "1" "0" "claude-delegate: Script exists and is executable" || true
    fi
}

test_claude_delegate_help() {
    echo -e "\n${CYAN}Testing claude-delegate --help...${RESET}"

    local output
    output=$(delegate_help "claude-delegate")

    if [[ "$output" == *"Usage"* ]]; then
        assert_equals "1" "1" "claude-delegate --help: Shows usage information" || true
    else
        assert_equals "1" "0" "claude-delegate --help: Shows usage information" || true
    fi

    if [[ "$output" == *"--timeout"* ]]; then
        assert_equals "1" "1" "claude-delegate --help: Documents --timeout option" || true
    else
        assert_equals "1" "0" "claude-delegate --help: Documents --timeout option" || true
    fi
}

test_claude_delegate_no_prompt() {
    echo -e "\n${CYAN}Testing claude-delegate with no prompt...${RESET}"

    local result exit_code output
    result=$(run_delegate "claude-delegate" 2>&1)
    parse_delegate_result "$result"

    debug_log "Exit code: $DELEGATE_EXIT_CODE"
    debug_log "Output: $DELEGATE_OUTPUT"

    assert_exit_code "1" "$DELEGATE_EXIT_CODE" "claude-delegate: Exit code 1 for missing prompt" || true

    if is_valid_json "$DELEGATE_OUTPUT"; then
        assert_equals "1" "1" "claude-delegate: Returns valid JSON for error" || true

        local status decision
        status=$(json_field "$DELEGATE_OUTPUT" "status")
        decision=$(json_field "$DELEGATE_OUTPUT" "decision")

        assert_equals "error" "$status" "claude-delegate: Status is 'error'" || true
        assert_equals "ABSTAIN" "$decision" "claude-delegate: Decision is 'ABSTAIN'" || true
    else
        assert_equals "1" "0" "claude-delegate: Returns valid JSON for error" || true
    fi
}

test_claude_delegate_cli_not_found() {
    echo -e "\n${CYAN}Testing claude-delegate with missing CLI...${RESET}"

    export CLAUDE_CMD="nonexistent-claude-cli-xyz"
    export TRI_FALLBACK_DISABLED="true"

    local result
    result=$(run_delegate "claude-delegate" "test prompt" 2>&1)
    parse_delegate_result "$result"

    assert_exit_code "1" "$DELEGATE_EXIT_CODE" "claude-delegate: Exit code 1 for missing CLI" || true

    if is_valid_json "$DELEGATE_OUTPUT"; then
        local reasoning
        reasoning=$(json_field "$DELEGATE_OUTPUT" "reasoning")
        assert_contains "$reasoning" "not found" "claude-delegate: Reports CLI not found" || true
    else
        assert_equals "1" "0" "claude-delegate: Returns valid JSON for CLI not found" || true
    fi

    unset CLAUDE_CMD TRI_FALLBACK_DISABLED
}

test_claude_delegate_json_envelope() {
    echo -e "\n${CYAN}Testing claude-delegate JSON envelope...${RESET}"

    export CLAUDE_CMD="nonexistent-cli"
    export TRI_FALLBACK_DISABLED="true"

    local result
    result=$(run_delegate "claude-delegate" "test" 2>&1)
    parse_delegate_result "$result"

    if is_valid_json "$DELEGATE_OUTPUT"; then
        local model trace_id duration_ms confidence

        model=$(json_field "$DELEGATE_OUTPUT" "model")
        trace_id=$(json_field "$DELEGATE_OUTPUT" "trace_id")
        duration_ms=$(json_field "$DELEGATE_OUTPUT" "duration_ms")
        confidence=$(json_field "$DELEGATE_OUTPUT" "confidence")

        assert_equals "claude" "$model" "claude-delegate: Model field is 'claude'" || true
        assert_not_empty "$trace_id" "claude-delegate: Has trace_id" || true
        assert_not_empty "$duration_ms" "claude-delegate: Has duration_ms" || true
        assert_not_empty "$confidence" "claude-delegate: Has confidence" || true
    else
        assert_equals "1" "0" "claude-delegate: Returns valid JSON envelope" || true
    fi

    unset CLAUDE_CMD TRI_FALLBACK_DISABLED
}

#===============================================================================
# Test Suite: Codex Delegate
#===============================================================================

test_codex_delegate_exists() {
    echo -e "\n${CYAN}Testing codex-delegate existence...${RESET}"

    if delegate_exists "codex-delegate"; then
        assert_equals "1" "1" "codex-delegate: Script exists and is executable" || true
    else
        assert_equals "1" "0" "codex-delegate: Script exists and is executable" || true
    fi
}

test_codex_delegate_help() {
    echo -e "\n${CYAN}Testing codex-delegate --help...${RESET}"

    local output
    output=$(delegate_help "codex-delegate")

    if [[ "$output" == *"Usage"* ]]; then
        assert_equals "1" "1" "codex-delegate --help: Shows usage information" || true
    else
        assert_equals "1" "0" "codex-delegate --help: Shows usage information" || true
    fi

    if [[ "$output" == *"--reasoning"* ]]; then
        assert_equals "1" "1" "codex-delegate --help: Documents --reasoning option" || true
    else
        assert_equals "1" "0" "codex-delegate --help: Documents --reasoning option" || true
    fi

    if [[ "$output" == *"--sandbox"* ]] || [[ "$output" == *"-s"* ]]; then
        assert_equals "1" "1" "codex-delegate --help: Documents --sandbox option" || true
    else
        assert_equals "1" "0" "codex-delegate --help: Documents --sandbox option" || true
    fi
}

test_codex_delegate_no_prompt() {
    echo -e "\n${CYAN}Testing codex-delegate with no prompt...${RESET}"

    local result
    result=$(run_delegate "codex-delegate" 2>&1)
    parse_delegate_result "$result"

    assert_exit_code "1" "$DELEGATE_EXIT_CODE" "codex-delegate: Exit code 1 for missing prompt" || true

    if is_valid_json "$DELEGATE_OUTPUT"; then
        local status decision
        status=$(json_field "$DELEGATE_OUTPUT" "status")
        decision=$(json_field "$DELEGATE_OUTPUT" "decision")

        assert_equals "error" "$status" "codex-delegate: Status is 'error'" || true
        assert_equals "ABSTAIN" "$decision" "codex-delegate: Decision is 'ABSTAIN'" || true
    else
        assert_equals "1" "0" "codex-delegate: Returns valid JSON for error" || true
    fi
}

test_codex_delegate_cli_not_found() {
    echo -e "\n${CYAN}Testing codex-delegate with missing CLI...${RESET}"

    export CODEX_CMD="nonexistent-codex-cli-xyz"
    export TRI_FALLBACK_DISABLED="true"

    local result
    result=$(run_delegate "codex-delegate" "test prompt" 2>&1)
    parse_delegate_result "$result"

    assert_exit_code "1" "$DELEGATE_EXIT_CODE" "codex-delegate: Exit code 1 for missing CLI" || true

    if is_valid_json "$DELEGATE_OUTPUT"; then
        local reasoning
        reasoning=$(json_field "$DELEGATE_OUTPUT" "reasoning")
        assert_contains "$reasoning" "not found" "codex-delegate: Reports CLI not found" || true
    else
        assert_equals "1" "0" "codex-delegate: Returns valid JSON for CLI not found" || true
    fi

    unset CODEX_CMD TRI_FALLBACK_DISABLED
}

test_codex_delegate_json_envelope() {
    echo -e "\n${CYAN}Testing codex-delegate JSON envelope...${RESET}"

    export CODEX_CMD="nonexistent-cli"
    export TRI_FALLBACK_DISABLED="true"

    local result
    result=$(run_delegate "codex-delegate" "test" 2>&1)
    parse_delegate_result "$result"

    if is_valid_json "$DELEGATE_OUTPUT"; then
        local model
        model=$(json_field "$DELEGATE_OUTPUT" "model")
        assert_equals "codex" "$model" "codex-delegate: Model field is 'codex'" || true
    else
        assert_equals "1" "0" "codex-delegate: Returns valid JSON envelope" || true
    fi

    unset CODEX_CMD TRI_FALLBACK_DISABLED
}

#===============================================================================
# Test Suite: Gemini Delegate
#===============================================================================

test_gemini_delegate_exists() {
    echo -e "\n${CYAN}Testing gemini-delegate existence...${RESET}"

    if delegate_exists "gemini-delegate"; then
        assert_equals "1" "1" "gemini-delegate: Script exists and is executable" || true
    else
        assert_equals "1" "0" "gemini-delegate: Script exists and is executable" || true
    fi
}

test_gemini_delegate_help() {
    echo -e "\n${CYAN}Testing gemini-delegate --help...${RESET}"

    local output
    output=$(delegate_help "gemini-delegate")

    if [[ "$output" == *"Usage"* ]]; then
        assert_equals "1" "1" "gemini-delegate --help: Shows usage information" || true
    else
        assert_equals "1" "0" "gemini-delegate --help: Shows usage information" || true
    fi

    if [[ "$output" == *"--session"* ]]; then
        assert_equals "1" "1" "gemini-delegate --help: Documents --session option" || true
    else
        assert_equals "1" "0" "gemini-delegate --help: Documents --session option" || true
    fi

    if [[ "$output" == *"--model"* ]]; then
        assert_equals "1" "1" "gemini-delegate --help: Documents --model option" || true
    else
        assert_equals "1" "0" "gemini-delegate --help: Documents --model option" || true
    fi
}

test_gemini_delegate_no_prompt() {
    echo -e "\n${CYAN}Testing gemini-delegate with no prompt...${RESET}"

    local result
    result=$(run_delegate "gemini-delegate" 2>&1)
    parse_delegate_result "$result"

    assert_exit_code "1" "$DELEGATE_EXIT_CODE" "gemini-delegate: Exit code 1 for missing prompt" || true

    if is_valid_json "$DELEGATE_OUTPUT"; then
        local status decision
        status=$(json_field "$DELEGATE_OUTPUT" "status")
        decision=$(json_field "$DELEGATE_OUTPUT" "decision")

        assert_equals "error" "$status" "gemini-delegate: Status is 'error'" || true
        assert_equals "ABSTAIN" "$decision" "gemini-delegate: Decision is 'ABSTAIN'" || true
    else
        assert_equals "1" "0" "gemini-delegate: Returns valid JSON for error" || true
    fi
}

test_gemini_delegate_cli_not_found() {
    echo -e "\n${CYAN}Testing gemini-delegate with missing CLI...${RESET}"

    export GEMINI_CMD="nonexistent-gemini-cli-xyz"
    export TRI_FALLBACK_DISABLED="true"

    local result
    result=$(run_delegate "gemini-delegate" "test prompt" 2>&1)
    parse_delegate_result "$result"

    assert_exit_code "1" "$DELEGATE_EXIT_CODE" "gemini-delegate: Exit code 1 for missing CLI" || true

    if is_valid_json "$DELEGATE_OUTPUT"; then
        local reasoning
        reasoning=$(json_field "$DELEGATE_OUTPUT" "reasoning")
        assert_contains "$reasoning" "not found" "gemini-delegate: Reports CLI not found" || true
    else
        assert_equals "1" "0" "gemini-delegate: Returns valid JSON for CLI not found" || true
    fi

    unset GEMINI_CMD TRI_FALLBACK_DISABLED
}

test_gemini_delegate_json_envelope() {
    echo -e "\n${CYAN}Testing gemini-delegate JSON envelope...${RESET}"

    export GEMINI_CMD="nonexistent-cli"
    export TRI_FALLBACK_DISABLED="true"

    local result
    result=$(run_delegate "gemini-delegate" "test" 2>&1)
    parse_delegate_result "$result"

    if is_valid_json "$DELEGATE_OUTPUT"; then
        local model
        model=$(json_field "$DELEGATE_OUTPUT" "model")
        assert_equals "gemini" "$model" "gemini-delegate: Model field is 'gemini'" || true
    else
        assert_equals "1" "0" "gemini-delegate: Returns valid JSON envelope" || true
    fi

    unset GEMINI_CMD TRI_FALLBACK_DISABLED
}

#===============================================================================
# Test Suite: Common Functionality
#===============================================================================

test_delegates_consistency() {
    echo -e "\n${CYAN}Testing delegate consistency...${RESET}"

    local delegates=("claude-delegate" "codex-delegate" "gemini-delegate")

    for delegate in "${delegates[@]}"; do
        if ! delegate_exists "$delegate"; then
            skip_test "$delegate not found, skipping consistency check"
            continue
        fi

        # Check for common patterns in script
        local script="${BIN_DIR}/${delegate}"

        if grep -q "extract_decision" "$script"; then
            assert_equals "1" "1" "$delegate: Has extract_decision function" || true
        else
            assert_equals "1" "0" "$delegate: Has extract_decision function" || true
        fi

        if grep -q "calculate_confidence" "$script"; then
            assert_equals "1" "1" "$delegate: Has calculate_confidence function" || true
        else
            assert_equals "1" "0" "$delegate: Has calculate_confidence function" || true
        fi

        if grep -q "json_output\|json_escape" "$script"; then
            assert_equals "1" "1" "$delegate: Has JSON output function" || true
        else
            assert_equals "1" "0" "$delegate: Has JSON output function" || true
        fi
    done
}

test_delegates_error_handling() {
    echo -e "\n${CYAN}Testing delegate error handling...${RESET}"

    local delegates=("claude-delegate" "codex-delegate" "gemini-delegate")

    for delegate in "${delegates[@]}"; do
        if ! delegate_exists "$delegate"; then
            skip_test "$delegate not found"
            continue
        fi

        local script="${BIN_DIR}/${delegate}"

        # Check for timeout handling
        if grep -q "124" "$script" && grep -q "timeout" "$script"; then
            assert_equals "1" "1" "$delegate: Handles timeout (exit code 124)" || true
        else
            assert_equals "1" "0" "$delegate: Handles timeout (exit code 124)" || true
        fi

        # Check for rate limit handling
        if grep -qi "rate" "$script" || grep -q "429" "$script"; then
            assert_equals "1" "1" "$delegate: Handles rate limits" || true
        else
            assert_equals "1" "0" "$delegate: Handles rate limits" || true
        fi

        # Check for auth error handling
        if grep -qi "auth" "$script" || grep -q "401" "$script"; then
            assert_equals "1" "1" "$delegate: Handles auth errors" || true
        else
            assert_equals "1" "0" "$delegate: Handles auth errors" || true
        fi
    done
}

test_delegates_security() {
    echo -e "\n${CYAN}Testing delegate security features...${RESET}"

    local delegates=("claude-delegate" "codex-delegate" "gemini-delegate")

    for delegate in "${delegates[@]}"; do
        if ! delegate_exists "$delegate"; then
            skip_test "$delegate not found"
            continue
        fi

        local script="${BIN_DIR}/${delegate}"

        # Check for secret masking
        if grep -q "mask_secrets" "$script"; then
            assert_equals "1" "1" "$delegate: Masks secrets in logs" || true
        else
            assert_equals "1" "0" "$delegate: Masks secrets in logs" || true
        fi

        # Check for temp file cleanup
        if grep -q "trap" "$script"; then
            assert_equals "1" "1" "$delegate: Has cleanup trap" || true
        else
            assert_equals "1" "0" "$delegate: Has cleanup trap" || true
        fi

        # Check for input sanitization
        if grep -q "sanitize" "$script"; then
            assert_equals "1" "1" "$delegate: Sanitizes input" || true
        else
            assert_equals "1" "0" "$delegate: Sanitizes input" || true
        fi
    done
}

#===============================================================================
# Test Suite: Return Code Handling
#===============================================================================

test_return_codes() {
    echo -e "\n${CYAN}Testing return code handling...${RESET}"

    local delegates=("claude-delegate" "codex-delegate" "gemini-delegate")

    for delegate in "${delegates[@]}"; do
        if ! delegate_exists "$delegate"; then
            skip_test "$delegate not found"
            continue
        fi

        # Test --help returns 0
        local exit_code=0
        "${BIN_DIR}/${delegate}" --help >/dev/null 2>&1 || exit_code=$?
        assert_exit_code "0" "$exit_code" "$delegate --help: Returns exit code 0" || true

        # Test missing prompt returns 1
        exit_code=0
        "${BIN_DIR}/${delegate}" >/dev/null 2>&1 || exit_code=$?
        assert_exit_code "1" "$exit_code" "$delegate (no prompt): Returns exit code 1" || true
    done
}

#===============================================================================
# Run All Tests
#===============================================================================

run_all_tests() {
    echo "==============================================================================="
    echo "Tri-Agent Delegate Scripts Test Suite"
    echo "==============================================================================="
    echo "Testing scripts in: ${BIN_DIR}"
    echo "==============================================================================="

    # Claude Delegate Tests
    echo -e "\n${BOLD}=== Claude Delegate Tests ===${RESET}"
    test_claude_delegate_exists
    test_claude_delegate_help
    test_claude_delegate_no_prompt
    test_claude_delegate_cli_not_found
    test_claude_delegate_json_envelope

    # Codex Delegate Tests
    echo -e "\n${BOLD}=== Codex Delegate Tests ===${RESET}"
    test_codex_delegate_exists
    test_codex_delegate_help
    test_codex_delegate_no_prompt
    test_codex_delegate_cli_not_found
    test_codex_delegate_json_envelope

    # Gemini Delegate Tests
    echo -e "\n${BOLD}=== Gemini Delegate Tests ===${RESET}"
    test_gemini_delegate_exists
    test_gemini_delegate_help
    test_gemini_delegate_no_prompt
    test_gemini_delegate_cli_not_found
    test_gemini_delegate_json_envelope

    # Common Functionality Tests
    echo -e "\n${BOLD}=== Common Functionality Tests ===${RESET}"
    test_delegates_consistency
    test_delegates_error_handling
    test_delegates_security
    test_return_codes

    # Print summary
    print_summary
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
    # Return non-zero if any tests failed
    [[ $TESTS_FAILED -eq 0 ]]
fi
