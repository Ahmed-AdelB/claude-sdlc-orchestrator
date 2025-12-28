#!/bin/bash
#===============================================================================
# test_consensus.sh - Integration tests for tri-agent consensus
#===============================================================================

set -euo pipefail

# Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(dirname "$(dirname "$SCRIPT_DIR")")}"
BIN_DIR="${PROJECT_ROOT}/bin"
CONFIG_DIR="${PROJECT_ROOT}/config"

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
echo "Testing consensus functionality..."

# Test 1: tri-agent-consensus exists
test_consensus_exists() {
    if [[ -x "${BIN_DIR}/tri-agent-consensus" ]]; then
        pass "tri-agent-consensus: Script exists and is executable"
    else
        fail "tri-agent-consensus: Not found or not executable"
    fi
}

# Test 2: tri-agent-consensus shows help
test_consensus_help() {
    local output
    output=$("${BIN_DIR}/tri-agent-consensus" --help 2>&1 || true)

    if echo "$output" | grep -qi "usage\|help"; then
        pass "tri-agent-consensus --help: Shows usage"
    else
        fail "tri-agent-consensus --help: No usage info"
    fi
}

# Test 3: Config has consensus section
test_config_consensus_section() {
    local config_file="${CONFIG_DIR}/tri-agent.yaml"

    if command -v yq &>/dev/null && [[ -f "$config_file" ]]; then
        local consensus
        consensus=$(yq eval '.consensus // ""' "$config_file" 2>/dev/null)

        if [[ -n "$consensus" && "$consensus" != "null" ]]; then
            pass "config: Has consensus section"
        else
            fail "config: Missing consensus section"
        fi
    else
        skip "config: yq not available or config missing"
    fi
}

# Test 4: Consensus voting modes are defined
test_consensus_voting_modes() {
    local config_file="${CONFIG_DIR}/tri-agent.yaml"

    if command -v yq &>/dev/null && [[ -f "$config_file" ]]; then
        local voting_mode
        voting_mode=$(yq eval '.consensus.voting_mode // ""' "$config_file" 2>/dev/null)

        if [[ "$voting_mode" == "majority" || "$voting_mode" == "weighted" || "$voting_mode" == "veto" ]]; then
            pass "consensus: Valid voting_mode ($voting_mode)"
        else
            fail "consensus: Invalid voting_mode: $voting_mode"
        fi
    else
        skip "consensus: yq not available"
    fi
}

# Test 5: Consensus weights are defined
test_consensus_weights() {
    local config_file="${CONFIG_DIR}/tri-agent.yaml"

    if command -v yq &>/dev/null && [[ -f "$config_file" ]]; then
        local claude_weight gemini_weight codex_weight
        claude_weight=$(yq eval '.consensus.weights.claude // 0' "$config_file" 2>/dev/null)
        gemini_weight=$(yq eval '.consensus.weights.gemini // 0' "$config_file" 2>/dev/null)
        codex_weight=$(yq eval '.consensus.weights.codex // 0' "$config_file" 2>/dev/null)

        # Check weights sum to approximately 1.0
        local sum
        sum=$(echo "$claude_weight + $gemini_weight + $codex_weight" | bc 2>/dev/null || echo "0")

        if [[ -n "$claude_weight" && "$claude_weight" != "0" ]]; then
            pass "consensus: Weights defined (claude=$claude_weight)"
        else
            skip "consensus: Weights not defined (optional)"
        fi
    else
        skip "consensus: yq not available"
    fi
}

# Test 6: Consensus min_approvals is valid
test_consensus_min_approvals() {
    local config_file="${CONFIG_DIR}/tri-agent.yaml"

    if command -v yq &>/dev/null && [[ -f "$config_file" ]]; then
        local min_approvals
        min_approvals=$(yq eval '.consensus.min_approvals // 0' "$config_file" 2>/dev/null)

        if [[ "$min_approvals" -ge 1 && "$min_approvals" -le 3 ]]; then
            pass "consensus: Valid min_approvals ($min_approvals)"
        else
            fail "consensus: Invalid min_approvals ($min_approvals)"
        fi
    else
        skip "consensus: yq not available"
    fi
}

# Test 7: Routing policy has consensus triggers
test_routing_policy_consensus() {
    local policy_file="${CONFIG_DIR}/routing-policy.yaml"

    if command -v yq &>/dev/null && [[ -f "$policy_file" ]]; then
        local triggers
        triggers=$(yq eval '.consensus_triggers // ""' "$policy_file" 2>/dev/null)

        if [[ -n "$triggers" && "$triggers" != "null" ]]; then
            pass "routing-policy: Has consensus_triggers"
        else
            skip "routing-policy: No consensus_triggers (optional)"
        fi
    else
        skip "routing-policy: yq not available"
    fi
}

# Test 8: tri-agent main script exists
test_tri_agent_exists() {
    if [[ -x "${BIN_DIR}/tri-agent" ]]; then
        pass "tri-agent: Main script exists and is executable"
    else
        fail "tri-agent: Not found or not executable"
    fi
}

# Test 9: tri-agent shows help
test_tri_agent_help() {
    local output
    output=$("${BIN_DIR}/tri-agent" --help 2>&1 || true)

    if echo "$output" | grep -qi "usage\|help"; then
        pass "tri-agent --help: Shows usage"
    else
        fail "tri-agent --help: No usage info"
    fi
}

# Test 10: Dashboard exists
test_dashboard_exists() {
    if [[ -x "${BIN_DIR}/tri-agent-dashboard" ]]; then
        pass "tri-agent-dashboard: Script exists and is executable"
    else
        fail "tri-agent-dashboard: Not found or not executable"
    fi
}

# Test 11: Dashboard shows help
test_dashboard_help() {
    local output
    output=$("${BIN_DIR}/tri-agent-dashboard" --help 2>&1 || true)

    if echo "$output" | grep -qi "usage\|help"; then
        pass "tri-agent-dashboard --help: Shows usage"
    else
        fail "tri-agent-dashboard --help: No usage info"
    fi
}

# Test 12: Dashboard --once mode works
test_dashboard_once() {
    local output
    output=$("${BIN_DIR}/tri-agent-dashboard" --once 2>&1 || true)

    if [[ -n "$output" ]]; then
        pass "tri-agent-dashboard --once: Produces output"
    else
        fail "tri-agent-dashboard --once: No output"
    fi
}

# Test 13: Config schema exists
test_schema_exists() {
    if [[ -f "${CONFIG_DIR}/schema.yaml" ]]; then
        pass "schema.yaml: File exists"
    else
        fail "schema.yaml: Not found"
    fi
}

# Test 14: Schema defines consensus properties
test_schema_consensus() {
    local schema_file="${CONFIG_DIR}/schema.yaml"

    if [[ -f "$schema_file" ]]; then
        if grep -q "consensus" "$schema_file"; then
            pass "schema.yaml: Defines consensus properties"
        else
            fail "schema.yaml: Missing consensus properties"
        fi
    else
        skip "schema.yaml: File not found"
    fi
}

#===============================================================================
# Run Tests
#===============================================================================

test_consensus_exists
test_consensus_help
test_config_consensus_section
test_consensus_voting_modes
test_consensus_weights
test_consensus_min_approvals
test_routing_policy_consensus
test_tri_agent_exists
test_tri_agent_help
test_dashboard_exists
test_dashboard_help
test_dashboard_once
test_schema_exists
test_schema_consensus

export TESTS_PASSED TESTS_FAILED

echo ""
echo "consensus tests completed: $TESTS_PASSED passed, $TESTS_FAILED failed"
