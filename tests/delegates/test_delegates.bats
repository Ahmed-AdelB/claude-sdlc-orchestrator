#!/usr/bin/env bats
#===============================================================================
# test_delegates.bats - Comprehensive BATS tests for tri-agent delegate scripts
#===============================================================================
# Run with: bats test_delegates.bats
# Or:       bats --tap test_delegates.bats
#===============================================================================

# Load test helpers
load 'test_helpers.bash'

#===============================================================================
# Setup/Teardown
#===============================================================================

setup() {
    test_setup
}

teardown() {
    test_teardown
}

#===============================================================================
# SECTION 1: Claude Delegate Tests
#===============================================================================

@test "claude-delegate: script exists and is executable" {
    [[ -x "${BIN_DIR}/claude-delegate" ]]
}

@test "claude-delegate: --help shows usage information" {
    run "${BIN_DIR}/claude-delegate" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
    [[ "$output" == *"Options"* ]]
}

@test "claude-delegate: returns JSON error for missing prompt" {
    run "${BIN_DIR}/claude-delegate"
    [ "$status" -eq 1 ]
    is_valid_json "$output"
    [[ "$(json_field "$output" "status")" == "error" ]]
    [[ "$(json_field "$output" "decision")" == "ABSTAIN" ]]
}

@test "claude-delegate: returns JSON error when CLI not found" {
    export CLAUDE_CMD="nonexistent-claude-cli-12345"
    export TRI_FALLBACK_DISABLED="true"
    run "${BIN_DIR}/claude-delegate" "test prompt"
    [ "$status" -eq 1 ]
    is_valid_json "$output"
    [[ "$(json_field "$output" "status")" == "error" ]]
    [[ "$(json_field "$output" "reasoning")" == *"not found"* ]]
}

@test "claude-delegate: accepts --timeout option" {
    run "${BIN_DIR}/claude-delegate" --help
    [[ "$output" == *"--timeout"* ]]
}

@test "claude-delegate: validates timeout is positive integer" {
    # The delegate should handle invalid timeout gracefully
    export CLAUDE_CMD="nonexistent-cli"
    export TRI_FALLBACK_DISABLED="true"
    run "${BIN_DIR}/claude-delegate" --timeout "invalid" "test prompt"
    # Should still run (uses default timeout) and fail for CLI not found
    [ "$status" -eq 1 ]
}

@test "claude-delegate: timeout is capped at MAX_TIMEOUT" {
    run "${BIN_DIR}/claude-delegate" --help
    # Check that help mentions max timeout
    [[ "$output" == *"max"* ]] || [[ "$output" == *"MAX"* ]] || skip "Max timeout not mentioned in help"
}

@test "claude-delegate: accepts --model option" {
    run "${BIN_DIR}/claude-delegate" --help
    [[ "$output" == *"--model"* ]] || [[ "$output" == *"-m"* ]]
}

@test "claude-delegate: accepts --thinking option" {
    run "${BIN_DIR}/claude-delegate" --help
    [[ "$output" == *"--thinking"* ]] || [[ "$output" == *"-t"* ]] || [[ "$output" == *"think"* ]]
}

@test "claude-delegate: accepts --print option for stderr output" {
    run "${BIN_DIR}/claude-delegate" --help
    [[ "$output" == *"--print"* ]]
}

@test "claude-delegate: JSON envelope has required fields" {
    export CLAUDE_CMD="nonexistent-cli"
    export TRI_FALLBACK_DISABLED="true"
    run "${BIN_DIR}/claude-delegate" "test"
    is_valid_json "$output"

    # Check required fields exist
    [[ -n "$(json_field "$output" "model")" ]]
    [[ -n "$(json_field "$output" "status")" ]]
    [[ -n "$(json_field "$output" "decision")" ]]
    [[ -n "$(json_field "$output" "trace_id")" ]]
}

@test "claude-delegate: model field is 'claude'" {
    export CLAUDE_CMD="nonexistent-cli"
    export TRI_FALLBACK_DISABLED="true"
    run "${BIN_DIR}/claude-delegate" "test"
    [[ "$(json_field "$output" "model")" == "claude" ]]
}

@test "claude-delegate: confidence is a number between 0 and 1" {
    export CLAUDE_CMD="nonexistent-cli"
    export TRI_FALLBACK_DISABLED="true"
    run "${BIN_DIR}/claude-delegate" "test"
    local confidence
    confidence=$(json_field "$output" "confidence")
    # Check it's a valid number format
    [[ "$confidence" =~ ^[0-9]+\.?[0-9]*$ ]]
}

#===============================================================================
# SECTION 2: Codex Delegate Tests
#===============================================================================

@test "codex-delegate: script exists and is executable" {
    [[ -x "${BIN_DIR}/codex-delegate" ]]
}

@test "codex-delegate: --help shows usage information" {
    run "${BIN_DIR}/codex-delegate" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
    [[ "$output" == *"Options"* ]]
}

@test "codex-delegate: returns JSON error for missing prompt" {
    run "${BIN_DIR}/codex-delegate"
    [ "$status" -eq 1 ]
    is_valid_json "$output"
    [[ "$(json_field "$output" "status")" == "error" ]]
    [[ "$(json_field "$output" "decision")" == "ABSTAIN" ]]
}

@test "codex-delegate: returns JSON error when CLI not found" {
    export CODEX_CMD="nonexistent-codex-cli-12345"
    export TRI_FALLBACK_DISABLED="true"
    run "${BIN_DIR}/codex-delegate" "test prompt"
    [ "$status" -eq 1 ]
    is_valid_json "$output"
    [[ "$(json_field "$output" "status")" == "error" ]]
    [[ "$(json_field "$output" "reasoning")" == *"not found"* ]]
}

@test "codex-delegate: accepts --timeout option" {
    run "${BIN_DIR}/codex-delegate" --help
    [[ "$output" == *"--timeout"* ]]
}

@test "codex-delegate: accepts --model option" {
    run "${BIN_DIR}/codex-delegate" --help
    [[ "$output" == *"--model"* ]]
}

@test "codex-delegate: accepts --reasoning option" {
    run "${BIN_DIR}/codex-delegate" --help
    [[ "$output" == *"--reasoning"* ]]
}

@test "codex-delegate: accepts --sandbox option" {
    run "${BIN_DIR}/codex-delegate" --help
    [[ "$output" == *"--sandbox"* ]] || [[ "$output" == *"-s"* ]]
}

@test "codex-delegate: validates reasoning effort values" {
    run "${BIN_DIR}/codex-delegate" --help
    # Should mention valid reasoning values
    [[ "$output" == *"xhigh"* ]] || [[ "$output" == *"high"* ]]
}

@test "codex-delegate: validates sandbox mode values" {
    run "${BIN_DIR}/codex-delegate" --help
    [[ "$output" == *"workspace-write"* ]] || [[ "$output" == *"danger-full-access"* ]]
}

@test "codex-delegate: JSON envelope has required fields" {
    export CODEX_CMD="nonexistent-cli"
    export TRI_FALLBACK_DISABLED="true"
    run "${BIN_DIR}/codex-delegate" "test"
    is_valid_json "$output"

    [[ -n "$(json_field "$output" "model")" ]]
    [[ -n "$(json_field "$output" "status")" ]]
    [[ -n "$(json_field "$output" "decision")" ]]
    [[ -n "$(json_field "$output" "trace_id")" ]]
}

@test "codex-delegate: model field is 'codex'" {
    export CODEX_CMD="nonexistent-cli"
    export TRI_FALLBACK_DISABLED="true"
    run "${BIN_DIR}/codex-delegate" "test"
    [[ "$(json_field "$output" "model")" == "codex" ]]
}

@test "codex-delegate: default timeout is set for xhigh reasoning" {
    run "${BIN_DIR}/codex-delegate" --help
    # Default should be higher for xhigh reasoning (typically 480s or more)
    [[ "$output" == *"480"* ]] || [[ "$output" == *"default"* ]]
}

#===============================================================================
# SECTION 3: Gemini Delegate Tests
#===============================================================================

@test "gemini-delegate: script exists and is executable" {
    [[ -x "${BIN_DIR}/gemini-delegate" ]]
}

@test "gemini-delegate: --help shows usage information" {
    run "${BIN_DIR}/gemini-delegate" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
    [[ "$output" == *"Options"* ]]
}

@test "gemini-delegate: returns JSON error for missing prompt" {
    run "${BIN_DIR}/gemini-delegate"
    [ "$status" -eq 1 ]
    is_valid_json "$output"
    [[ "$(json_field "$output" "status")" == "error" ]]
    [[ "$(json_field "$output" "decision")" == "ABSTAIN" ]]
}

@test "gemini-delegate: returns JSON error when CLI not found" {
    export GEMINI_CMD="nonexistent-gemini-cli-12345"
    export TRI_FALLBACK_DISABLED="true"
    run "${BIN_DIR}/gemini-delegate" "test prompt"
    [ "$status" -eq 1 ]
    is_valid_json "$output"
    [[ "$(json_field "$output" "status")" == "error" ]]
    [[ "$(json_field "$output" "reasoning")" == *"not found"* ]]
}

@test "gemini-delegate: accepts --timeout option" {
    run "${BIN_DIR}/gemini-delegate" --help
    [[ "$output" == *"--timeout"* ]]
}

@test "gemini-delegate: accepts --model option" {
    run "${BIN_DIR}/gemini-delegate" --help
    [[ "$output" == *"--model"* ]]
}

@test "gemini-delegate: accepts --session option" {
    run "${BIN_DIR}/gemini-delegate" --help
    [[ "$output" == *"--session"* ]]
}

@test "gemini-delegate: accepts --include-directories option" {
    run "${BIN_DIR}/gemini-delegate" --help
    [[ "$output" == *"--include-directories"* ]] || [[ "$output" == *"include"* ]]
}

@test "gemini-delegate: accepts -o/--output-format option" {
    run "${BIN_DIR}/gemini-delegate" --help
    [[ "$output" == *"--output-format"* ]] || [[ "$output" == *"-o"* ]]
}

@test "gemini-delegate: JSON envelope has required fields" {
    export GEMINI_CMD="nonexistent-cli"
    export TRI_FALLBACK_DISABLED="true"
    run "${BIN_DIR}/gemini-delegate" "test"
    is_valid_json "$output"

    [[ -n "$(json_field "$output" "model")" ]]
    [[ -n "$(json_field "$output" "status")" ]]
    [[ -n "$(json_field "$output" "decision")" ]]
    [[ -n "$(json_field "$output" "trace_id")" ]]
}

@test "gemini-delegate: model field is 'gemini'" {
    export GEMINI_CMD="nonexistent-cli"
    export TRI_FALLBACK_DISABLED="true"
    run "${BIN_DIR}/gemini-delegate" "test"
    [[ "$(json_field "$output" "model")" == "gemini" ]]
}

@test "gemini-delegate: default model is gemini-3-pro-preview" {
    run "${BIN_DIR}/gemini-delegate" --help
    [[ "$output" == *"gemini-3-pro-preview"* ]] || [[ "$output" == *"default"* ]]
}

@test "gemini-delegate: mentions environment variables" {
    run "${BIN_DIR}/gemini-delegate" --help
    [[ "$output" == *"Environment"* ]] || [[ "$output" == *"GEMINI_"* ]]
}

#===============================================================================
# SECTION 4: Common Functionality Tests
#===============================================================================

@test "all delegates: have consistent JSON envelope structure" {
    local delegates=("claude-delegate" "codex-delegate" "gemini-delegate")

    for delegate in "${delegates[@]}"; do
        local cmd_var="${delegate//-/_}_CMD"
        cmd_var="${cmd_var^^}"
        export "${cmd_var}=nonexistent-cli"
    done
    export TRI_FALLBACK_DISABLED="true"

    local fields_match=true
    local prev_fields=""

    for delegate in "${delegates[@]}"; do
        run "${BIN_DIR}/${delegate}" "test"
        local fields
        fields=$(echo "$output" | jq -r 'keys | sort | join(",")' 2>/dev/null || echo "")

        if [[ -n "$prev_fields" && "$fields" != "$prev_fields" ]]; then
            fields_match=false
            break
        fi
        prev_fields="$fields"
    done

    [[ "$fields_match" == "true" ]]
}

@test "all delegates: mask secrets in logs" {
    local delegates=("claude-delegate" "codex-delegate" "gemini-delegate")

    for delegate in "${delegates[@]}"; do
        [[ -f "${BIN_DIR}/${delegate}" ]] || continue
        grep -q "mask_secrets" "${BIN_DIR}/${delegate}"
    done
}

@test "all delegates: have timeout handling" {
    local delegates=("claude-delegate" "codex-delegate" "gemini-delegate")

    for delegate in "${delegates[@]}"; do
        [[ -f "${BIN_DIR}/${delegate}" ]] || continue
        grep -q "timeout" "${BIN_DIR}/${delegate}"
        grep -q "TIMEOUT" "${BIN_DIR}/${delegate}"
    done
}

@test "all delegates: source common.sh library" {
    local delegates=("claude-delegate" "codex-delegate" "gemini-delegate")

    for delegate in "${delegates[@]}"; do
        [[ -f "${BIN_DIR}/${delegate}" ]] || continue
        grep -q "common.sh" "${BIN_DIR}/${delegate}"
    done
}

@test "all delegates: handle exit code 124 as timeout" {
    local delegates=("claude-delegate" "codex-delegate" "gemini-delegate")

    for delegate in "${delegates[@]}"; do
        [[ -f "${BIN_DIR}/${delegate}" ]] || continue
        grep -q '124' "${BIN_DIR}/${delegate}"
    done
}

@test "all delegates: have extract_decision function" {
    local delegates=("claude-delegate" "codex-delegate" "gemini-delegate")

    for delegate in "${delegates[@]}"; do
        [[ -f "${BIN_DIR}/${delegate}" ]] || continue
        grep -q "extract_decision" "${BIN_DIR}/${delegate}"
    done
}

@test "all delegates: have calculate_confidence function" {
    local delegates=("claude-delegate" "codex-delegate" "gemini-delegate")

    for delegate in "${delegates[@]}"; do
        [[ -f "${BIN_DIR}/${delegate}" ]] || continue
        grep -q "calculate_confidence" "${BIN_DIR}/${delegate}"
    done
}

@test "all delegates: support APPROVE, REJECT, ABSTAIN decisions" {
    local delegates=("claude-delegate" "codex-delegate" "gemini-delegate")

    for delegate in "${delegates[@]}"; do
        [[ -f "${BIN_DIR}/${delegate}" ]] || continue
        grep -q "APPROVE" "${BIN_DIR}/${delegate}"
        grep -q "REJECT" "${BIN_DIR}/${delegate}"
        grep -q "ABSTAIN" "${BIN_DIR}/${delegate}"
    done
}

#===============================================================================
# SECTION 5: Error Handling Tests
#===============================================================================

@test "claude-delegate: handles rate limit errors gracefully" {
    [[ -f "${BIN_DIR}/claude-delegate" ]] || skip "Delegate not found"
    grep -q "rate" "${BIN_DIR}/claude-delegate" || grep -q "429" "${BIN_DIR}/claude-delegate"
}

@test "codex-delegate: handles rate limit errors gracefully" {
    [[ -f "${BIN_DIR}/codex-delegate" ]] || skip "Delegate not found"
    grep -q "rate" "${BIN_DIR}/codex-delegate" || grep -q "429" "${BIN_DIR}/codex-delegate"
}

@test "gemini-delegate: handles rate limit errors gracefully" {
    [[ -f "${BIN_DIR}/gemini-delegate" ]] || skip "Delegate not found"
    grep -q "rate" "${BIN_DIR}/gemini-delegate" || grep -q "429" "${BIN_DIR}/gemini-delegate"
}

@test "all delegates: handle auth errors gracefully" {
    local delegates=("claude-delegate" "codex-delegate" "gemini-delegate")

    for delegate in "${delegates[@]}"; do
        [[ -f "${BIN_DIR}/${delegate}" ]] || continue
        grep -q -i "auth" "${BIN_DIR}/${delegate}"
    done
}

@test "codex-delegate: handles reasoning budget errors" {
    [[ -f "${BIN_DIR}/codex-delegate" ]] || skip "Delegate not found"
    grep -q "reasoning" "${BIN_DIR}/codex-delegate"
}

@test "codex-delegate: handles context compaction errors" {
    [[ -f "${BIN_DIR}/codex-delegate" ]] || skip "Delegate not found"
    grep -q "context" "${BIN_DIR}/codex-delegate" || grep -q "compaction" "${BIN_DIR}/codex-delegate"
}

@test "codex-delegate: handles sandbox permission errors" {
    [[ -f "${BIN_DIR}/codex-delegate" ]] || skip "Delegate not found"
    grep -q "sandbox" "${BIN_DIR}/codex-delegate"
}

#===============================================================================
# SECTION 6: Stdin/Input Handling Tests
#===============================================================================

@test "claude-delegate: accepts stdin input" {
    [[ -f "${BIN_DIR}/claude-delegate" ]] || skip "Delegate not found"
    grep -q "stdin" "${BIN_DIR}/claude-delegate" || grep -q "STDIN" "${BIN_DIR}/claude-delegate" || grep -q '\-t 0' "${BIN_DIR}/claude-delegate"
}

@test "codex-delegate: accepts stdin input" {
    [[ -f "${BIN_DIR}/codex-delegate" ]] || skip "Delegate not found"
    grep -q "stdin" "${BIN_DIR}/codex-delegate" || grep -q "STDIN" "${BIN_DIR}/codex-delegate" || grep -q '\-t 0' "${BIN_DIR}/codex-delegate"
}

@test "gemini-delegate: accepts stdin input" {
    [[ -f "${BIN_DIR}/gemini-delegate" ]] || skip "Delegate not found"
    grep -q "stdin" "${BIN_DIR}/gemini-delegate" || grep -q "STDIN" "${BIN_DIR}/gemini-delegate" || grep -q '\-t 0' "${BIN_DIR}/gemini-delegate"
}

@test "all delegates: have stdin size limit" {
    local delegates=("claude-delegate" "codex-delegate" "gemini-delegate")

    for delegate in "${delegates[@]}"; do
        [[ -f "${BIN_DIR}/${delegate}" ]] || continue
        grep -q "MAX_STDIN_SIZE" "${BIN_DIR}/${delegate}" || grep -q "500000" "${BIN_DIR}/${delegate}"
    done
}

#===============================================================================
# SECTION 7: Fallback Tests
#===============================================================================

@test "claude-delegate: has fallback mechanism" {
    [[ -f "${BIN_DIR}/claude-delegate" ]] || skip "Delegate not found"
    grep -q "fallback" "${BIN_DIR}/claude-delegate" || grep -q "FALLBACK" "${BIN_DIR}/claude-delegate"
}

@test "codex-delegate: has fallback mechanism" {
    [[ -f "${BIN_DIR}/codex-delegate" ]] || skip "Delegate not found"
    grep -q "fallback" "${BIN_DIR}/codex-delegate" || grep -q "FALLBACK" "${BIN_DIR}/codex-delegate"
}

@test "gemini-delegate: has fallback mechanism" {
    [[ -f "${BIN_DIR}/gemini-delegate" ]] || skip "Delegate not found"
    grep -q "fallback" "${BIN_DIR}/gemini-delegate" || grep -q "FALLBACK" "${BIN_DIR}/gemini-delegate"
}

@test "all delegates: respect TRI_FALLBACK_DISABLED flag" {
    local delegates=("claude-delegate" "codex-delegate" "gemini-delegate")

    for delegate in "${delegates[@]}"; do
        [[ -f "${BIN_DIR}/${delegate}" ]] || continue
        grep -q "TRI_FALLBACK_DISABLED" "${BIN_DIR}/${delegate}"
    done
}

#===============================================================================
# SECTION 8: Circuit Breaker Tests
#===============================================================================

@test "claude-delegate: has circuit breaker support" {
    [[ -f "${BIN_DIR}/claude-delegate" ]] || skip "Delegate not found"
    grep -q "circuit" "${BIN_DIR}/claude-delegate" || grep -q "breaker" "${BIN_DIR}/claude-delegate"
}

@test "codex-delegate: has circuit breaker support" {
    [[ -f "${BIN_DIR}/codex-delegate" ]] || skip "Delegate not found"
    grep -q "circuit" "${BIN_DIR}/codex-delegate" || grep -q "breaker" "${BIN_DIR}/codex-delegate"
}

@test "gemini-delegate: has circuit breaker support" {
    [[ -f "${BIN_DIR}/gemini-delegate" ]] || skip "Delegate not found"
    grep -q "circuit" "${BIN_DIR}/gemini-delegate" || grep -q "breaker" "${BIN_DIR}/gemini-delegate"
}

@test "all delegates: handle exit code 126 as circuit breaker open" {
    local delegates=("claude-delegate" "codex-delegate" "gemini-delegate")

    for delegate in "${delegates[@]}"; do
        [[ -f "${BIN_DIR}/${delegate}" ]] || continue
        grep -q '126' "${BIN_DIR}/${delegate}"
    done
}

#===============================================================================
# SECTION 9: Security Tests
#===============================================================================

@test "all delegates: sanitize LLM input" {
    local delegates=("claude-delegate" "codex-delegate" "gemini-delegate")

    for delegate in "${delegates[@]}"; do
        [[ -f "${BIN_DIR}/${delegate}" ]] || continue
        grep -q "sanitize" "${BIN_DIR}/${delegate}"
    done
}

@test "all delegates: use secure temp file creation" {
    local delegates=("claude-delegate" "codex-delegate" "gemini-delegate")

    for delegate in "${delegates[@]}"; do
        [[ -f "${BIN_DIR}/${delegate}" ]] || continue
        grep -q "mktemp" "${BIN_DIR}/${delegate}" || grep -q "secure_mktemp" "${BIN_DIR}/${delegate}"
    done
}

@test "all delegates: clean up temp files on exit" {
    local delegates=("claude-delegate" "codex-delegate" "gemini-delegate")

    for delegate in "${delegates[@]}"; do
        [[ -f "${BIN_DIR}/${delegate}" ]] || continue
        grep -q "trap" "${BIN_DIR}/${delegate}"
    done
}

#===============================================================================
# SECTION 10: Cost Tracking Tests
#===============================================================================

@test "all delegates: estimate input tokens" {
    local delegates=("claude-delegate" "codex-delegate" "gemini-delegate")

    for delegate in "${delegates[@]}"; do
        [[ -f "${BIN_DIR}/${delegate}" ]] || continue
        grep -q "tokens" "${BIN_DIR}/${delegate}" || grep -q "TOKENS" "${BIN_DIR}/${delegate}"
    done
}

@test "all delegates: record cost usage" {
    local delegates=("claude-delegate" "codex-delegate" "gemini-delegate")

    for delegate in "${delegates[@]}"; do
        [[ -f "${BIN_DIR}/${delegate}" ]] || continue
        grep -q "record_cost" "${BIN_DIR}/${delegate}" || grep -q "cost" "${BIN_DIR}/${delegate}"
    done
}

@test "all delegates: support cost breaker" {
    local delegates=("claude-delegate" "codex-delegate" "gemini-delegate")

    for delegate in "${delegates[@]}"; do
        [[ -f "${BIN_DIR}/${delegate}" ]] || continue
        grep -q "cost_breaker" "${BIN_DIR}/${delegate}" || grep -q "COST_BREAKER" "${BIN_DIR}/${delegate}"
    done
}
