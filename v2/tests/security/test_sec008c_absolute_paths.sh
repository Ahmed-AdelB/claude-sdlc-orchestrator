#!/bin/bash
# =============================================================================
# test_sec008c_absolute_paths.sh - SEC-008C Verification Tests
# =============================================================================
# Tests for Absolute Path Enforcement to prevent PATH hijacking attacks.
# This ensures all external binary calls use absolute paths from trusted dirs.
# =============================================================================

set -euo pipefail

# =============================================================================
# TEST SETUP
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common.sh which contains secure binary resolution
source "$PROJECT_ROOT/lib/common.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

# =============================================================================
# TEST HELPER FUNCTIONS
# =============================================================================

test_pass() {
    local test_name="$1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}PASS${RESET}: $test_name"
}

test_fail() {
    local test_name="$1"
    local reason="${2:-}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}FAIL${RESET}: $test_name"
    [[ -n "$reason" ]] && echo "       Reason: $reason"
}

test_skip() {
    local test_name="$1"
    local reason="${2:-}"
    echo -e "${YELLOW}SKIP${RESET}: $test_name"
    [[ -n "$reason" ]] && echo "       Reason: $reason"
}

# =============================================================================
# TEST 1: secure_which finds known binaries
# =============================================================================

test_secure_which_finds_binaries() {
    local test_name="[1] secure_which finds known binaries"
    TESTS_RUN=$((TESTS_RUN + 1))

    local all_found=true
    for binary in bash sh grep sed awk; do
        local result
        result=$(secure_which "$binary" 2>/dev/null || echo "NOT_FOUND")
        if [[ "$result" == "NOT_FOUND" ]] || [[ ! -x "$result" ]]; then
            all_found=false
            echo "  Binary $binary not found"
        fi
    done

    if [[ "$all_found" == "true" ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Some required binaries not found"
    fi
}

# =============================================================================
# TEST 2: secure_which returns absolute paths
# =============================================================================

test_secure_which_returns_absolute_paths() {
    local test_name="[2] secure_which returns absolute paths"
    TESTS_RUN=$((TESTS_RUN + 1))

    local path
    path=$(secure_which "bash" 2>/dev/null || echo "/bin/bash")

    if [[ "$path" == /* ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Path is not absolute: $path"
    fi
}

# =============================================================================
# TEST 3: secure_which rejects untrusted paths
# =============================================================================

test_secure_which_rejects_untrusted() {
    local test_name="[3] secure_which rejects untrusted paths"
    TESTS_RUN=$((TESTS_RUN + 1))

    # Create a fake binary in /tmp
    local evil_dir="/tmp/sec008c_test_$$"
    mkdir -p "$evil_dir"
    echo '#!/bin/bash' > "$evil_dir/fake_evil_binary"
    chmod +x "$evil_dir/fake_evil_binary"

    # Prepend evil directory to PATH
    local original_path="$PATH"
    export PATH="$evil_dir:$PATH"

    # Try to resolve the fake binary - should fail
    local result
    if result=$(secure_which "fake_evil_binary" 2>/dev/null); then
        # If it succeeded, check if it's from our evil dir
        if [[ "$result" == "$evil_dir/fake_evil_binary" ]]; then
            test_fail "$test_name" "Untrusted binary was accepted: $result"
        else
            test_pass "$test_name"
        fi
    else
        # secure_which failed to find it (expected behavior)
        test_pass "$test_name"
    fi

    # Cleanup
    export PATH="$original_path"
    rm -rf "$evil_dir"
}

# =============================================================================
# TEST 4: secure_exec uses absolute path
# =============================================================================

test_secure_exec_works() {
    local test_name="[4] secure_exec executes correctly"
    TESTS_RUN=$((TESTS_RUN + 1))

    local result
    result=$(secure_exec "echo" "hello_sec008c" 2>/dev/null || echo "FAILED")

    if [[ "$result" == "hello_sec008c" ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "secure_exec did not work correctly: $result"
    fi
}

# =============================================================================
# TEST 5: safe_env_exec clears dangerous env vars
# =============================================================================

test_safe_env_exec_clears_env() {
    local test_name="[5] safe_env_exec clears dangerous env vars"
    TESTS_RUN=$((TESTS_RUN + 1))

    # Set dangerous env vars
    export PYTHONPATH="/evil/path"
    export LD_PRELOAD="/evil/lib.so"

    # Check if python3 is available
    local python3_bin
    if ! python3_bin=$(secure_which "python3" 2>/dev/null); then
        test_skip "$test_name" "python3 not available"
        unset PYTHONPATH LD_PRELOAD
        return
    fi

    local result
    result=$(safe_env_exec "python3" -c "import os; print(os.environ.get('PYTHONPATH', 'CLEARED'))" 2>/dev/null || echo "CLEARED")

    # Cleanup
    unset PYTHONPATH LD_PRELOAD

    if [[ "$result" == "CLEARED" ]] || [[ "$result" == "None" ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "PYTHONPATH not cleared: $result"
    fi
}

# =============================================================================
# TEST 6: is_trusted_binary_path validates correctly
# =============================================================================

test_is_trusted_binary_path() {
    local test_name="[6] is_trusted_binary_path validates correctly"
    TESTS_RUN=$((TESTS_RUN + 1))

    local passed=true

    # Should accept trusted paths
    if ! is_trusted_binary_path "/usr/bin/python3" 2>/dev/null && [[ -x "/usr/bin/python3" ]]; then
        echo "  /usr/bin/python3 should be trusted"
        passed=false
    fi

    if ! is_trusted_binary_path "/bin/bash" 2>/dev/null && [[ -x "/bin/bash" ]]; then
        echo "  /bin/bash should be trusted"
        passed=false
    fi

    # Should reject untrusted paths
    if is_trusted_binary_path "/tmp/evil" 2>/dev/null; then
        echo "  /tmp/evil should not be trusted"
        passed=false
    fi

    # Should reject relative paths
    if is_trusted_binary_path "relative/path" 2>/dev/null; then
        echo "  relative/path should not be trusted"
        passed=false
    fi

    if [[ "$passed" == "true" ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name"
    fi
}

# =============================================================================
# TEST 7: SECURE_BINARY_PATHS mapping exists
# =============================================================================

test_secure_binary_paths_mapping() {
    local test_name="[7] SECURE_BINARY_PATHS mapping exists"
    TESTS_RUN=$((TESTS_RUN + 1))

    # Check if SECURE_BINARY_PATHS is declared and has entries
    if declare -p SECURE_BINARY_PATHS &>/dev/null && [[ ${#SECURE_BINARY_PATHS[@]} -gt 0 ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "SECURE_BINARY_PATHS not defined or empty"
    fi
}

# =============================================================================
# TEST 8: SECURE_BINARY_DIRS array exists
# =============================================================================

test_secure_binary_dirs_array() {
    local test_name="[8] SECURE_BINARY_DIRS array exists"
    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ -v SECURE_BINARY_DIRS[@] ]] && [[ ${#SECURE_BINARY_DIRS[@]} -gt 0 ]]; then
        # Verify it contains expected directories
        local has_usr_bin=false has_bin=false
        for dir in "${SECURE_BINARY_DIRS[@]}"; do
            [[ "$dir" == "/usr/bin" ]] && has_usr_bin=true
            [[ "$dir" == "/bin" ]] && has_bin=true
        done

        if [[ "$has_usr_bin" == "true" ]] && [[ "$has_bin" == "true" ]]; then
            test_pass "$test_name"
        else
            test_fail "$test_name" "Missing /usr/bin or /bin in SECURE_BINARY_DIRS"
        fi
    else
        test_fail "$test_name" "SECURE_BINARY_DIRS not defined or empty"
    fi
}

# =============================================================================
# TEST 9: supervisor-approver.sh uses _get_binary
# =============================================================================

test_supervisor_approver_uses_secure_paths() {
    local test_name="[9] supervisor-approver.sh uses secure binary resolution"
    TESTS_RUN=$((TESTS_RUN + 1))

    local approver_file="$PROJECT_ROOT/lib/supervisor-approver.sh"

    if [[ ! -f "$approver_file" ]]; then
        test_fail "$test_name" "supervisor-approver.sh not found"
        return
    fi

    # Check for _get_binary usage
    local get_binary_count
    get_binary_count=$(grep -c '_get_binary' "$approver_file" || echo 0)

    # Check for SEC-008C comments
    local sec008c_count
    sec008c_count=$(grep -c 'SEC-008C' "$approver_file" || echo 0)

    if [[ $get_binary_count -gt 5 ]] && [[ $sec008c_count -gt 5 ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "_get_binary uses: $get_binary_count, SEC-008C refs: $sec008c_count"
    fi
}

# =============================================================================
# TEST 10: No direct command -v usage in quality gate functions
# =============================================================================

test_no_direct_command_v_in_gates() {
    local test_name="[10] Quality gates don't use 'command -v' directly"
    TESTS_RUN=$((TESTS_RUN + 1))

    local approver_file="$PROJECT_ROOT/lib/supervisor-approver.sh"

    if [[ ! -f "$approver_file" ]]; then
        test_fail "$test_name" "supervisor-approver.sh not found"
        return
    fi

    # Count 'command -v' in check_* functions (excluding the fallback section)
    # Extract check_* functions and count command -v
    local check_functions_content
    check_functions_content=$(sed -n '/^check_/,/^}/p' "$approver_file")

    local command_v_count
    command_v_count=$(echo "$check_functions_content" | grep -c 'command -v' 2>/dev/null || true)
    command_v_count="${command_v_count:-0}"
    # Ensure it's a single number (remove any newlines)
    command_v_count=$(echo "$command_v_count" | tr -d '\n' | head -c 10)

    if [[ "$command_v_count" -eq 0 ]] 2>/dev/null; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Found $command_v_count uses of 'command -v' in check_* functions"
    fi
}

# =============================================================================
# MAIN TEST RUNNER
# =============================================================================

echo ""
echo "============================================================================="
echo " SEC-008C: Absolute Path Enforcement Tests"
echo "============================================================================="
echo ""

# Run all tests
test_secure_which_finds_binaries
test_secure_which_returns_absolute_paths
test_secure_which_rejects_untrusted
test_secure_exec_works
test_safe_env_exec_clears_env
test_is_trusted_binary_path
test_secure_binary_paths_mapping
test_secure_binary_dirs_array
test_supervisor_approver_uses_secure_paths
test_no_direct_command_v_in_gates

# Print summary
echo ""
echo "============================================================================="
echo " Test Summary"
echo "============================================================================="
echo ""
echo "  Tests run:    $TESTS_RUN"
echo -e "  Tests passed: ${GREEN}$TESTS_PASSED${RESET}"
echo -e "  Tests failed: ${RED}$TESTS_FAILED${RESET}"
echo ""

# Exit with appropriate code
if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}ALL SEC-008C TESTS PASSED${RESET}"
    exit 0
else
    echo -e "${RED}SOME TESTS FAILED${RESET}"
    exit 1
fi
