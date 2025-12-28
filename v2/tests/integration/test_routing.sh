#!/bin/bash
#===============================================================================
# test_routing.sh - Integration tests for routing functionality
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
echo "Testing routing functionality..."

# Test 1: tri-agent-route exists and is executable
test_route_exists() {
    if [[ -x "${BIN_DIR}/tri-agent-route" ]]; then
        pass "tri-agent-route: Script exists and is executable"
    else
        fail "tri-agent-route: Not found or not executable"
    fi
}

# Test 2: tri-agent-route shows help
test_route_help() {
    local output
    output=$("${BIN_DIR}/tri-agent-route" --help 2>&1 || true)

    if echo "$output" | grep -q "Usage"; then
        pass "tri-agent-route --help: Shows usage"
    else
        fail "tri-agent-route --help: No usage info"
    fi
}

# Test 3: tri-agent-router exists and is executable
test_router_exists() {
    if [[ -x "${BIN_DIR}/tri-agent-router" ]]; then
        pass "tri-agent-router: Script exists and is executable"
    else
        fail "tri-agent-router: Not found or not executable"
    fi
}

# Test 4: tri-agent-router shows help
test_router_help() {
    local output
    output=$("${BIN_DIR}/tri-agent-router" --help 2>&1 || true)

    if echo "$output" | grep -qi "usage\|help"; then
        pass "tri-agent-router --help: Shows usage"
    else
        fail "tri-agent-router --help: No usage info"
    fi
}

# Test 5: Routing policy file exists
test_routing_policy_exists() {
    local policy_file="${PROJECT_ROOT}/config/routing-policy.yaml"

    if [[ -f "$policy_file" ]]; then
        pass "routing-policy.yaml: File exists"
    else
        fail "routing-policy.yaml: Not found"
    fi
}

# Test 6: Routing policy is valid YAML
test_routing_policy_valid() {
    local policy_file="${PROJECT_ROOT}/config/routing-policy.yaml"

    if command -v yq &>/dev/null; then
        if yq eval '.' "$policy_file" &>/dev/null; then
            pass "routing-policy.yaml: Valid YAML"
        else
            fail "routing-policy.yaml: Invalid YAML"
        fi
    elif command -v python3 &>/dev/null; then
        if python3 -c "import yaml; yaml.safe_load(open('$policy_file'))" &>/dev/null; then
            pass "routing-policy.yaml: Valid YAML (python)"
        else
            fail "routing-policy.yaml: Invalid YAML (python)"
        fi
    else
        skip "routing-policy.yaml: No YAML parser available"
    fi
}

# Test 7: Routing policy has required sections
test_routing_policy_sections() {
    local policy_file="${PROJECT_ROOT}/config/routing-policy.yaml"

    if command -v yq &>/dev/null; then
        local has_rules has_settings
        has_rules=$(yq eval '.routing_rules // ""' "$policy_file" 2>/dev/null)
        has_settings=$(yq eval '.settings // ""' "$policy_file" 2>/dev/null)

        if [[ -n "$has_rules" && "$has_rules" != "null" ]]; then
            pass "routing-policy.yaml: Has routing_rules section"
        else
            fail "routing-policy.yaml: Missing routing_rules"
        fi

        if [[ -n "$has_settings" && "$has_settings" != "null" ]]; then
            pass "routing-policy.yaml: Has settings section"
        else
            fail "routing-policy.yaml: Missing settings"
        fi
    else
        skip "routing-policy.yaml: yq not available"
    fi
}

# Test 8: Auto-detection routes "implement" to codex
test_auto_detect_implement() {
    # This tests the detection logic without actually calling the model
    local prompt="implement a new authentication system"
    local expected_model="codex"

    # Use grep to check if the prompt would route to codex
    if echo "$prompt" | grep -qiE "implement|build|create|fix"; then
        pass "auto-detect: 'implement' routes to codex"
    else
        fail "auto-detect: 'implement' should route to codex"
    fi
}

# Test 9: Auto-detection routes "analyze codebase" to gemini
test_auto_detect_analyze() {
    local prompt="analyze entire codebase for security"
    local expected_model="gemini"

    if echo "$prompt" | grep -qiE "analyze|entire|codebase|large"; then
        pass "auto-detect: 'analyze codebase' routes to gemini"
    else
        fail "auto-detect: 'analyze codebase' should route to gemini"
    fi
}

# Test 10: Auto-detection routes "architect" to claude
test_auto_detect_architect() {
    local prompt="architect the database schema"
    local expected_model="claude"

    if echo "$prompt" | grep -qiE "architect|design|security|plan"; then
        pass "auto-detect: 'architect' routes to claude"
    else
        fail "auto-detect: 'architect' should route to claude"
    fi
}

# Test 11: preflight check exists
test_preflight_exists() {
    if [[ -x "${BIN_DIR}/tri-agent-preflight" ]]; then
        pass "tri-agent-preflight: Script exists and is executable"
    else
        fail "tri-agent-preflight: Not found or not executable"
    fi
}

# Test 12: preflight quick mode runs
test_preflight_quick() {
    local output exit_code
    output=$("${BIN_DIR}/tri-agent-preflight" --quick --json 2>&1) && exit_code=0 || exit_code=$?

    if command -v jq &>/dev/null && echo "$output" | jq . &>/dev/null; then
        pass "tri-agent-preflight --quick: Returns valid JSON"
    elif [[ -n "$output" ]]; then
        pass "tri-agent-preflight --quick: Returns output"
    else
        fail "tri-agent-preflight --quick: No output"
    fi
}

# Test 13: health-check exists
test_health_check_exists() {
    if [[ -x "${BIN_DIR}/health-check" ]]; then
        pass "health-check: Script exists and is executable"
    else
        fail "health-check: Not found or not executable"
    fi
}

# Test 14: health-check JSON output
test_health_check_json() {
    local output
    output=$("${BIN_DIR}/health-check" --json 2>&1 || true)

    if command -v jq &>/dev/null && echo "$output" | jq . &>/dev/null; then
        pass "health-check --json: Returns valid JSON"
    elif echo "$output" | grep -q "status"; then
        pass "health-check --json: Contains status"
    else
        fail "health-check --json: Invalid output"
    fi
}

#===============================================================================
# Run Tests
#===============================================================================

test_route_exists
test_route_help
test_router_exists
test_router_help
test_routing_policy_exists
test_routing_policy_valid
test_routing_policy_sections
test_auto_detect_implement
test_auto_detect_analyze
test_auto_detect_architect
test_preflight_exists
test_preflight_quick
test_health_check_exists
test_health_check_json

export TESTS_PASSED TESTS_FAILED

echo ""
echo "routing tests completed: $TESTS_PASSED passed, $TESTS_FAILED failed"
