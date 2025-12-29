#!/usr/bin/env bash
# ==============================================================================
# SEC-003A: State File Symlink Protection Tests
# ==============================================================================
# Verifies that symlink attacks are properly blocked to prevent arbitrary
# file overwrite vulnerabilities.
#
# Tests:
#   1. test_direct_symlink_blocked - Direct symlink writes are rejected
#   2. test_parent_symlink_blocked - Parent directory symlinks are detected
#   3. test_path_traversal_blocked - Path traversal attempts are blocked
#   4. test_legitimate_writes_allowed - Normal writes still work
#   5. test_atomic_write_symlink - atomic_write blocks symlinks
#   6. test_atomic_append_symlink - atomic_append blocks symlinks
#   7. test_state_set_symlink - state_set blocks symlinks
#   8. test_state_delete_symlink - state_delete blocks symlinks
#   9. test_atomic_increment_symlink - atomic_increment blocks symlinks
#  10. test_nested_symlink_attack - Nested symlinks are detected
#
# Usage: ./test_symlink_protection.sh [test_name]
# ==============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_TMP="${TMPDIR:-/tmp}/symlink_test_$$"
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ==============================================================================
# Test Framework Functions
# ==============================================================================

setup() {
    mkdir -p "$TEST_TMP"
    cd "$TEST_TMP"

    # Create mock autonomous root structure
    mkdir -p autonomous_root/{state,tasks,logs,sessions,locks}
    export AUTONOMOUS_ROOT="$TEST_TMP/autonomous_root"
    export STATE_DIR="$AUTONOMOUS_ROOT/state"
    export TASKS_DIR="$AUTONOMOUS_ROOT/tasks"
    export LOG_DIR="$AUTONOMOUS_ROOT/logs"
    export SESSIONS_DIR="$AUTONOMOUS_ROOT/sessions"
    export LOCKS_DIR="$AUTONOMOUS_ROOT/locks"

    # Create external directory (simulating outside autonomous root)
    mkdir -p "$TEST_TMP/external/sensitive"
    echo "SENSITIVE_DATA" > "$TEST_TMP/external/sensitive/secret.txt"

    # Define minimal log functions if not already defined
    if ! declare -F log_error &>/dev/null; then
        log_error() { echo "[ERROR] $*" >&2; }
    fi
    if ! declare -F log_warn &>/dev/null; then
        log_warn() { echo "[WARN] $*" >&2; }
    fi

    # Source the state.sh library directly (it uses log_error from environment)
    # shellcheck source=/dev/null
    source "$PROJECT_ROOT/lib/state.sh"
}

teardown() {
    cd /
    rm -rf "$TEST_TMP"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
}

log_info() {
    echo -e "[INFO] $1"
}

# ==============================================================================
# Test: is_symlink_safe Function
# ==============================================================================

test_is_symlink_safe_direct_symlink() {
    log_info "Testing is_symlink_safe: direct symlink detection..."

    local test_passed=true

    # Create a symlink pointing outside STATE_DIR
    ln -sf "$TEST_TMP/external/sensitive/secret.txt" "$STATE_DIR/malicious_link"

    # is_symlink_safe should reject this
    if is_symlink_safe "$STATE_DIR/malicious_link" "$STATE_DIR" 2>/dev/null; then
        log_fail "is_symlink_safe: Failed to detect direct symlink"
        test_passed=false
    else
        log_info "  Direct symlink correctly blocked"
    fi

    # Cleanup
    rm -f "$STATE_DIR/malicious_link"

    if $test_passed; then
        log_pass "is_symlink_safe: Direct symlink detection works"
    fi
}

test_is_symlink_safe_parent_symlink() {
    log_info "Testing is_symlink_safe: parent directory symlink detection..."

    local test_passed=true

    # Create a directory symlink
    mkdir -p "$STATE_DIR/nested"
    ln -sf "$TEST_TMP/external" "$STATE_DIR/nested/escape"

    # is_symlink_safe should reject paths through symlinked directories
    if is_symlink_safe "$STATE_DIR/nested/escape/sensitive/secret.txt" "$STATE_DIR" 2>/dev/null; then
        log_fail "is_symlink_safe: Failed to detect parent directory symlink"
        test_passed=false
    else
        log_info "  Parent directory symlink correctly blocked"
    fi

    # Cleanup
    rm -rf "$STATE_DIR/nested"

    if $test_passed; then
        log_pass "is_symlink_safe: Parent directory symlink detection works"
    fi
}

test_is_symlink_safe_legitimate_path() {
    log_info "Testing is_symlink_safe: legitimate paths allowed..."

    local test_passed=true

    # Create a legitimate file
    echo "legitimate content" > "$STATE_DIR/legit_file.txt"

    # is_symlink_safe should allow this
    if ! is_symlink_safe "$STATE_DIR/legit_file.txt" "$STATE_DIR" 2>/dev/null; then
        log_fail "is_symlink_safe: Incorrectly blocked legitimate file"
        test_passed=false
    else
        log_info "  Legitimate file correctly allowed"
    fi

    # Test non-existent file (should also be allowed as it will be created)
    if ! is_symlink_safe "$STATE_DIR/new_file.txt" "$STATE_DIR" 2>/dev/null; then
        log_fail "is_symlink_safe: Incorrectly blocked non-existent legitimate path"
        test_passed=false
    else
        log_info "  Non-existent legitimate path correctly allowed"
    fi

    # Cleanup
    rm -f "$STATE_DIR/legit_file.txt"

    if $test_passed; then
        log_pass "is_symlink_safe: Legitimate paths allowed"
    fi
}

# ==============================================================================
# Test: validate_path_in_directory Function
# ==============================================================================

test_validate_path_in_directory() {
    log_info "Testing validate_path_in_directory: path traversal detection..."

    local test_passed=true

    # Test path that stays within directory
    if ! validate_path_in_directory "$STATE_DIR/subdir/file.txt" "$STATE_DIR" 2>/dev/null; then
        log_fail "validate_path_in_directory: Incorrectly rejected path within directory"
        test_passed=false
    else
        log_info "  Path within directory correctly allowed"
    fi

    # Test path that escapes directory with ..
    if validate_path_in_directory "$STATE_DIR/../external/file.txt" "$STATE_DIR" 2>/dev/null; then
        log_fail "validate_path_in_directory: Failed to detect path traversal"
        test_passed=false
    else
        log_info "  Path traversal correctly blocked"
    fi

    # Test absolute path outside directory
    if validate_path_in_directory "/etc/passwd" "$STATE_DIR" 2>/dev/null; then
        log_fail "validate_path_in_directory: Failed to block absolute path outside directory"
        test_passed=false
    else
        log_info "  Absolute path outside directory correctly blocked"
    fi

    # Test prefix attack (e.g., /tmp/state vs /tmp/stateevil)
    mkdir -p "${STATE_DIR}evil"
    if validate_path_in_directory "${STATE_DIR}evil/file.txt" "$STATE_DIR" 2>/dev/null; then
        log_fail "validate_path_in_directory: Failed to detect prefix attack"
        test_passed=false
    else
        log_info "  Prefix attack correctly blocked"
    fi
    rm -rf "${STATE_DIR}evil"

    if $test_passed; then
        log_pass "validate_path_in_directory: Path traversal detection works"
    fi
}

# ==============================================================================
# Test: atomic_write Symlink Protection
# ==============================================================================

test_atomic_write_symlink_blocked() {
    log_info "Testing atomic_write: symlink writes blocked..."

    local test_passed=true

    # Create a symlink pointing to external file
    ln -sf "$TEST_TMP/external/sensitive/secret.txt" "$STATE_DIR/atomic_symlink"

    # Try to write through symlink - should fail
    if atomic_write "$STATE_DIR/atomic_symlink" "malicious content" 2>/dev/null; then
        log_fail "atomic_write: Failed to block symlink write"
        test_passed=false

        # Check if the external file was overwritten
        if [[ "$(cat "$TEST_TMP/external/sensitive/secret.txt")" == "malicious content" ]]; then
            log_fail "CRITICAL: Symlink attack succeeded - external file was overwritten!"
            test_passed=false
        fi
    else
        log_info "  Symlink write correctly blocked"
    fi

    # Cleanup
    rm -f "$STATE_DIR/atomic_symlink"

    if $test_passed; then
        log_pass "atomic_write: Symlink writes blocked"
    fi
}

test_atomic_write_legitimate() {
    log_info "Testing atomic_write: legitimate writes allowed..."

    local test_passed=true

    # Write to a legitimate file
    if ! atomic_write "$STATE_DIR/legit_atomic.txt" "test content" 2>/dev/null; then
        log_fail "atomic_write: Failed to write to legitimate file"
        test_passed=false
    else
        if [[ "$(cat "$STATE_DIR/legit_atomic.txt")" == "test content" ]]; then
            log_info "  Legitimate write succeeded"
        else
            log_fail "atomic_write: Content mismatch after write"
            test_passed=false
        fi
    fi

    # Cleanup
    rm -f "$STATE_DIR/legit_atomic.txt"

    if $test_passed; then
        log_pass "atomic_write: Legitimate writes work"
    fi
}

# ==============================================================================
# Test: atomic_append Symlink Protection
# ==============================================================================

test_atomic_append_symlink_blocked() {
    log_info "Testing atomic_append: symlink appends blocked..."

    local test_passed=true

    # Create a symlink pointing to external file
    ln -sf "$TEST_TMP/external/sensitive/secret.txt" "$STATE_DIR/append_symlink"

    # Try to append through symlink - should fail
    if atomic_append "$STATE_DIR/append_symlink" "malicious append" 2>/dev/null; then
        log_fail "atomic_append: Failed to block symlink append"
        test_passed=false
    else
        log_info "  Symlink append correctly blocked"
    fi

    # Cleanup
    rm -f "$STATE_DIR/append_symlink"

    if $test_passed; then
        log_pass "atomic_append: Symlink appends blocked"
    fi
}

# ==============================================================================
# Test: state_set Symlink Protection
# ==============================================================================

test_state_set_symlink_blocked() {
    log_info "Testing state_set: symlink state files blocked..."

    local test_passed=true

    # Create a symlink pointing to external file
    ln -sf "$TEST_TMP/external/sensitive/secret.txt" "$STATE_DIR/state_symlink"

    # Try to set state through symlink - should fail
    if state_set "$STATE_DIR/state_symlink" "key" "value" 2>/dev/null; then
        log_fail "state_set: Failed to block symlink state file"
        test_passed=false
    else
        log_info "  Symlink state file correctly blocked"
    fi

    # Cleanup
    rm -f "$STATE_DIR/state_symlink"

    if $test_passed; then
        log_pass "state_set: Symlink state files blocked"
    fi
}

# ==============================================================================
# Test: state_delete Symlink Protection
# ==============================================================================

test_state_delete_symlink_blocked() {
    log_info "Testing state_delete: symlink state files blocked..."

    local test_passed=true

    # Create a symlink pointing to external file
    ln -sf "$TEST_TMP/external/sensitive/secret.txt" "$STATE_DIR/delete_symlink"

    # Try to delete through symlink - should fail
    if state_delete "$STATE_DIR/delete_symlink" "key" 2>/dev/null; then
        log_fail "state_delete: Failed to block symlink state file"
        test_passed=false
    else
        log_info "  Symlink state delete correctly blocked"
    fi

    # Cleanup
    rm -f "$STATE_DIR/delete_symlink"

    if $test_passed; then
        log_pass "state_delete: Symlink state files blocked"
    fi
}

# ==============================================================================
# Test: atomic_increment Symlink Protection
# ==============================================================================

test_atomic_increment_symlink_blocked() {
    log_info "Testing atomic_increment: symlink counter files blocked..."

    local test_passed=true

    # Create a symlink pointing to external file
    ln -sf "$TEST_TMP/external/sensitive/secret.txt" "$STATE_DIR/counter_symlink"

    # Try to increment through symlink - should fail
    if atomic_increment "$STATE_DIR/counter_symlink" 2>/dev/null; then
        log_fail "atomic_increment: Failed to block symlink counter file"
        test_passed=false
    else
        log_info "  Symlink counter file correctly blocked"
    fi

    # Cleanup
    rm -f "$STATE_DIR/counter_symlink"

    if $test_passed; then
        log_pass "atomic_increment: Symlink counter files blocked"
    fi
}

# ==============================================================================
# Test: Nested Symlink Attack
# ==============================================================================

test_nested_symlink_attack() {
    log_info "Testing nested symlink attack detection..."

    local test_passed=true

    # Create a chain of directories with a symlink in the middle
    mkdir -p "$STATE_DIR/level1/level2"
    ln -sf "$TEST_TMP/external" "$STATE_DIR/level1/level2/escape"

    # Try to write through nested symlink - should fail
    if atomic_write "$STATE_DIR/level1/level2/escape/sensitive/secret.txt" "pwned" 2>/dev/null; then
        log_fail "Nested symlink attack: Failed to block nested symlink"
        test_passed=false

        # Check if attack succeeded
        if [[ "$(cat "$TEST_TMP/external/sensitive/secret.txt" 2>/dev/null)" == "pwned" ]]; then
            log_fail "CRITICAL: Nested symlink attack succeeded!"
            test_passed=false
        fi
    else
        log_info "  Nested symlink correctly blocked"
    fi

    # Cleanup
    rm -rf "$STATE_DIR/level1"

    if $test_passed; then
        log_pass "Nested symlink attack: Detection works"
    fi
}

# ==============================================================================
# Test: Path Traversal via Symlink
# ==============================================================================

test_path_traversal_symlink() {
    log_info "Testing path traversal via symlink..."

    local test_passed=true

    # Create a symlink that points to parent directory
    ln -sf ".." "$STATE_DIR/parent_escape"

    # Try to write through path traversal symlink
    if atomic_write "$STATE_DIR/parent_escape/external/pwned.txt" "malicious" 2>/dev/null; then
        log_fail "Path traversal symlink: Failed to block"
        test_passed=false
    else
        log_info "  Path traversal symlink correctly blocked"
    fi

    # Cleanup
    rm -f "$STATE_DIR/parent_escape"

    if $test_passed; then
        log_pass "Path traversal symlink: Detection works"
    fi
}

# ==============================================================================
# Test: Symlink Race Condition Prevention
# ==============================================================================

test_symlink_toctou() {
    log_info "Testing TOCTOU (time-of-check-time-of-use) mitigation..."

    local test_passed=true

    # This tests that the check happens right before the write
    # Note: True TOCTOU prevention requires more complex mechanisms,
    # but this validates the check is in the write path

    # Create legitimate file first
    echo "original" > "$STATE_DIR/toctou_test.txt"

    # Verify write works
    if ! atomic_write "$STATE_DIR/toctou_test.txt" "updated" 2>/dev/null; then
        log_fail "TOCTOU test: Initial write failed"
        test_passed=false
    fi

    # Now replace with symlink and try again
    rm -f "$STATE_DIR/toctou_test.txt"
    ln -sf "$TEST_TMP/external/sensitive/secret.txt" "$STATE_DIR/toctou_test.txt"

    # This should fail because it's now a symlink
    if atomic_write "$STATE_DIR/toctou_test.txt" "pwned" 2>/dev/null; then
        log_fail "TOCTOU test: Failed to detect symlink replacement"
        test_passed=false
    else
        log_info "  Symlink replacement correctly detected"
    fi

    # Cleanup
    rm -f "$STATE_DIR/toctou_test.txt"

    if $test_passed; then
        log_pass "TOCTOU mitigation: Check is in write path"
    fi
}

# ==============================================================================
# Test: Empty Path Handling
# ==============================================================================

test_empty_path_handling() {
    log_info "Testing empty path handling..."

    local test_passed=true

    # is_symlink_safe should reject empty paths
    if is_symlink_safe "" "$STATE_DIR" 2>/dev/null; then
        log_fail "Empty path: is_symlink_safe should reject"
        test_passed=false
    else
        log_info "  Empty path correctly rejected by is_symlink_safe"
    fi

    # validate_path_in_directory should reject empty paths
    if validate_path_in_directory "" "$STATE_DIR" 2>/dev/null; then
        log_fail "Empty path: validate_path_in_directory should reject"
        test_passed=false
    else
        log_info "  Empty path correctly rejected by validate_path_in_directory"
    fi

    if $test_passed; then
        log_pass "Empty path handling: Properly rejected"
    fi
}

# ==============================================================================
# Main Test Runner
# ==============================================================================

run_all_tests() {
    echo "=============================================="
    echo "SEC-003A: State File Symlink Protection Tests"
    echo "=============================================="
    echo ""

    setup

    # Run all tests
    test_is_symlink_safe_direct_symlink
    test_is_symlink_safe_parent_symlink
    test_is_symlink_safe_legitimate_path
    test_validate_path_in_directory
    test_atomic_write_symlink_blocked
    test_atomic_write_legitimate
    test_atomic_append_symlink_blocked
    test_state_set_symlink_blocked
    test_state_delete_symlink_blocked
    test_atomic_increment_symlink_blocked
    test_nested_symlink_attack
    test_path_traversal_symlink
    test_symlink_toctou
    test_empty_path_handling

    teardown

    echo ""
    echo "=============================================="
    echo "Test Summary"
    echo "=============================================="
    echo -e "Passed:  ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Failed:  ${RED}${TESTS_FAILED}${NC}"
    echo -e "Skipped: ${YELLOW}${TESTS_SKIPPED}${NC}"
    echo ""

    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${RED}SEC-003A SYMLINK PROTECTION TESTS FAILED${NC}"
        return 1
    else
        echo -e "${GREEN}ALL SEC-003A SYMLINK PROTECTION TESTS PASSED${NC}"
        return 0
    fi
}

run_single_test() {
    local test_name="$1"

    setup

    if declare -f "$test_name" > /dev/null; then
        "$test_name"
    else
        echo "ERROR: Unknown test '$test_name'" >&2
        echo "Available tests:"
        echo "  - test_is_symlink_safe_direct_symlink"
        echo "  - test_is_symlink_safe_parent_symlink"
        echo "  - test_is_symlink_safe_legitimate_path"
        echo "  - test_validate_path_in_directory"
        echo "  - test_atomic_write_symlink_blocked"
        echo "  - test_atomic_write_legitimate"
        echo "  - test_atomic_append_symlink_blocked"
        echo "  - test_state_set_symlink_blocked"
        echo "  - test_state_delete_symlink_blocked"
        echo "  - test_atomic_increment_symlink_blocked"
        echo "  - test_nested_symlink_attack"
        echo "  - test_path_traversal_symlink"
        echo "  - test_symlink_toctou"
        echo "  - test_empty_path_handling"
        teardown
        return 1
    fi

    teardown
}

# Entry point
main() {
    if [[ $# -eq 0 ]]; then
        run_all_tests
    else
        run_single_test "$1"
    fi
}

main "$@"
