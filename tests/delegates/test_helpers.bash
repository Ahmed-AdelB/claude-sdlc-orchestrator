#!/bin/bash
#===============================================================================
# test_helpers.bash - Common test helpers for delegate script tests
#===============================================================================
# This file provides shared utilities for both BATS and standalone shell tests.
# Source this file before running tests.
#===============================================================================

# Test environment setup
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_ROOT="${TEST_DIR}/../.."
V2_BIN="${CLAUDE_ROOT}/v2/bin"
AUTONOMOUS_BIN="${CLAUDE_ROOT}/autonomous/bin"

# Choose which bin directory to test (default to v2, allow override)
BIN_DIR="${TEST_BIN_DIR:-${V2_BIN}}"

# Temp directory for test artifacts
TEST_TMP_DIR="${TMPDIR:-/tmp}/tri-agent-delegate-tests-$$"
mkdir -p "$TEST_TMP_DIR"

# Test counters (for standalone mode)
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Colors (only if terminal supports it)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    BOLD=''
    RESET=''
fi

#===============================================================================
# Mock CLI tools for testing without actual API calls
#===============================================================================

# Create a mock claude CLI that returns predictable output
create_mock_claude() {
    local mock_dir="$1"
    local response="${2:-APPROVE: Test response}"
    local exit_code="${3:-0}"
    local delay="${4:-0}"

    mkdir -p "$mock_dir"
    cat > "${mock_dir}/claude" << EOF
#!/bin/bash
[[ "$delay" -gt 0 ]] && sleep $delay
if [[ "\$1" == "--help" ]]; then
    echo "Mock Claude CLI"
    exit 0
fi
echo "$response"
exit $exit_code
EOF
    chmod +x "${mock_dir}/claude"
}

# Create a mock codex CLI
create_mock_codex() {
    local mock_dir="$1"
    local response="${2:-APPROVE: Test response}"
    local exit_code="${3:-0}"
    local delay="${4:-0}"

    mkdir -p "$mock_dir"
    cat > "${mock_dir}/codex" << EOF
#!/bin/bash
[[ "$delay" -gt 0 ]] && sleep $delay
if [[ "\$1" == "--help" ]]; then
    echo "Mock Codex CLI"
    exit 0
fi
if [[ "\$1" == "exec" ]]; then
    shift  # Remove 'exec'
    while [[ \$# -gt 0 && "\$1" == -* ]]; do
        case "\$1" in
            -m) shift 2 ;;
            -c) shift 2 ;;
            -s) shift 2 ;;
            --skip-git-repo-check) shift ;;
            *) shift ;;
        esac
    done
fi
echo "$response"
exit $exit_code
EOF
    chmod +x "${mock_dir}/codex"
}

# Create a mock gemini CLI
create_mock_gemini() {
    local mock_dir="$1"
    local response="${2:-APPROVE: Test response}"
    local exit_code="${3:-0}"
    local delay="${4:-0}"

    mkdir -p "$mock_dir"
    cat > "${mock_dir}/gemini" << EOF
#!/bin/bash
[[ "$delay" -gt 0 ]] && sleep $delay
if [[ "\$1" == "--help" ]] || [[ "\$1" == "-h" ]]; then
    echo "Mock Gemini CLI"
    exit 0
fi
echo "$response"
exit $exit_code
EOF
    chmod +x "${mock_dir}/gemini"
}

# Create mock environment with all CLIs
create_mock_environment() {
    local mock_dir="${1:-${TEST_TMP_DIR}/mock-bin}"
    local claude_response="${2:-APPROVE: Claude test response}"
    local codex_response="${3:-APPROVE: Codex test response}"
    local gemini_response="${4:-APPROVE: Gemini test response}"

    create_mock_claude "$mock_dir" "$claude_response"
    create_mock_codex "$mock_dir" "$codex_response"
    create_mock_gemini "$mock_dir" "$gemini_response"

    echo "$mock_dir"
}

#===============================================================================
# JSON Validation Helpers
#===============================================================================

# Check if string is valid JSON
is_valid_json() {
    local json="$1"
    echo "$json" | jq . >/dev/null 2>&1
}

# Extract field from JSON
json_field() {
    local json="$1"
    local field="$2"
    echo "$json" | jq -r ".$field // empty" 2>/dev/null
}

# Validate JSON envelope has required fields
validate_json_envelope() {
    local json="$1"
    local required_fields=("model" "status" "decision" "confidence" "trace_id" "duration_ms")

    if ! is_valid_json "$json"; then
        echo "Invalid JSON"
        return 1
    fi

    for field in "${required_fields[@]}"; do
        local value
        value=$(json_field "$json" "$field")
        if [[ -z "$value" ]]; then
            echo "Missing field: $field"
            return 1
        fi
    done

    return 0
}

#===============================================================================
# Test Assertion Functions (for standalone mode)
#===============================================================================

# Helper to safely increment counter (works with set -e)
_inc_counter() {
    local var_name="$1"
    eval "$var_name=\$(( $var_name + 1 ))"
}

# Assert equality
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    _inc_counter TESTS_RUN

    if [[ "$expected" == "$actual" ]]; then
        _inc_counter TESTS_PASSED
        echo -e "  ${GREEN}[PASS]${RESET} ${message:-Expected '$expected', got '$actual'}"
        return 0
    else
        _inc_counter TESTS_FAILED
        echo -e "  ${RED}[FAIL]${RESET} ${message:-Expected '$expected', got '$actual'}"
        return 1
    fi
}

# Assert not empty
assert_not_empty() {
    local value="$1"
    local message="${2:-}"

    _inc_counter TESTS_RUN

    if [[ -n "$value" ]]; then
        _inc_counter TESTS_PASSED
        echo -e "  ${GREEN}[PASS]${RESET} ${message:-Value is not empty}"
        return 0
    else
        _inc_counter TESTS_FAILED
        echo -e "  ${RED}[FAIL]${RESET} ${message:-Value is empty}"
        return 1
    fi
}

# Assert exit code
assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    assert_equals "$expected" "$actual" "${message:-Exit code}"
}

# Assert contains
assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-}"

    _inc_counter TESTS_RUN

    if [[ "$haystack" == *"$needle"* ]]; then
        _inc_counter TESTS_PASSED
        echo -e "  ${GREEN}[PASS]${RESET} ${message:-Contains '$needle'}"
        return 0
    else
        _inc_counter TESTS_FAILED
        echo -e "  ${RED}[FAIL]${RESET} ${message:-Does not contain '$needle'}"
        return 1
    fi
}

# Assert JSON field equals
assert_json_field() {
    local json="$1"
    local field="$2"
    local expected="$3"
    local message="${4:-}"

    local actual
    actual=$(json_field "$json" "$field")
    assert_equals "$expected" "$actual" "${message:-JSON field '$field'}"
}

# Skip test
skip_test() {
    local reason="${1:-No reason provided}"
    _inc_counter TESTS_RUN
    _inc_counter TESTS_SKIPPED
    echo -e "  ${YELLOW}[SKIP]${RESET} $reason"
}

#===============================================================================
# Test Setup/Teardown
#===============================================================================

# Setup function - call before each test
test_setup() {
    # Create fresh temp directory for this test
    TEST_CASE_TMP="${TEST_TMP_DIR}/case-$$-${RANDOM}"
    mkdir -p "$TEST_CASE_TMP"

    # Export for delegates to use
    export TRACE_ID="test-${RANDOM}"
}

# Teardown function - call after each test
test_teardown() {
    # Clean up test case temp directory
    if [[ -d "${TEST_CASE_TMP:-}" ]]; then
        rm -rf "$TEST_CASE_TMP"
    fi
}

# Global cleanup - call at end of test suite
cleanup_all() {
    if [[ -d "${TEST_TMP_DIR:-}" ]]; then
        rm -rf "$TEST_TMP_DIR"
    fi
}

# Print test summary
print_summary() {
    echo ""
    echo "==============================================================================="
    echo "Test Summary"
    echo "==============================================================================="
    echo -e "Total:   ${BOLD}${TESTS_RUN}${RESET}"
    echo -e "Passed:  ${GREEN}${TESTS_PASSED}${RESET}"
    echo -e "Failed:  ${RED}${TESTS_FAILED}${RESET}"
    echo -e "Skipped: ${YELLOW}${TESTS_SKIPPED}${RESET}"
    echo "==============================================================================="

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${RESET}"
        return 0
    else
        echo -e "${RED}Some tests failed.${RESET}"
        return 1
    fi
}

# Set trap for cleanup
trap cleanup_all EXIT

#===============================================================================
# Delegate-specific test helpers
#===============================================================================

# Run delegate and capture output + exit code
run_delegate() {
    local delegate="$1"
    shift
    local args=("$@")

    local output
    local exit_code=0

    output=$("${BIN_DIR}/${delegate}" "${args[@]}" 2>&1) || exit_code=$?

    # Return as tab-separated: exit_code\toutput
    printf '%d\t%s' "$exit_code" "$output"
}

# Parse delegate result
parse_delegate_result() {
    local result="$1"

    # Split by first tab
    DELEGATE_EXIT_CODE="${result%%	*}"
    DELEGATE_OUTPUT="${result#*	}"
}

# Run delegate with mock CLI
run_delegate_with_mock() {
    local delegate="$1"
    local mock_dir="$2"
    shift 2
    local args=("$@")

    # Prepend mock dir to PATH
    local old_path="$PATH"
    export PATH="${mock_dir}:${PATH}"

    local result
    result=$(run_delegate "$delegate" "${args[@]}")

    # Restore PATH
    export PATH="$old_path"

    echo "$result"
}

# Check if a delegate script exists
delegate_exists() {
    local delegate="$1"
    [[ -x "${BIN_DIR}/${delegate}" ]]
}

# Get delegate version/help output
delegate_help() {
    local delegate="$1"
    "${BIN_DIR}/${delegate}" --help 2>&1 || true
}
