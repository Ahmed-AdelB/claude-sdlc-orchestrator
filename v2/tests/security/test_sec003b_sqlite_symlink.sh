#!/usr/bin/env bash
# ==============================================================================
# SEC-003B: SQLite Database Symlink Protection Tests
# ==============================================================================
# Validates symlink protection for SQLite database files to prevent
# symlink attacks that could redirect database operations to arbitrary files.
#
# Tests:
#   1. test_symlink_db_rejected - Symlink database files are rejected
#   2. test_path_outside_state_dir_rejected - Paths outside STATE_DIR are rejected
#   3. test_normal_db_path_works - Normal database paths work correctly
#   4. test_parent_symlink_detected - Parent directory symlinks are detected
#   5. test_path_traversal_blocked - Path traversal attempts are blocked
#   6. test_race_condition_protection - Race condition symlink swap is detected
#
# Usage: ./test_sec003b_sqlite_symlink.sh [test_name]
# ==============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_TMP="${TMPDIR:-/tmp}/sec003b_test_$$"
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==============================================================================
# Test Framework Functions
# ==============================================================================

setup() {
    mkdir -p "$TEST_TMP"
    cd "$TEST_TMP"

    # Create mock autonomous root with proper structure
    mkdir -p autonomous_root/{tasks,state,logs,bin,lib}
    export AUTONOMOUS_ROOT="$TEST_TMP/autonomous_root"
    export STATE_DIR="$AUTONOMOUS_ROOT/state"
    export STATE_DB="$STATE_DIR/tri-agent.db"
    export LOG_DIR="$AUTONOMOUS_ROOT/logs"
    export TRACE_ID="test-sec003b-$$"

    # Create external directory for attack simulation
    mkdir -p "$TEST_TMP/external"
    mkdir -p "$TEST_TMP/sensitive"
    echo "SENSITIVE_DATA" > "$TEST_TMP/sensitive/secret.txt"
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
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Source the sqlite-state.sh library
source_sqlite_state() {
    if [[ -f "$PROJECT_ROOT/lib/sqlite-state.sh" ]]; then
        # shellcheck source=/dev/null
        source "$PROJECT_ROOT/lib/sqlite-state.sh"
        return 0
    else
        echo "ERROR: sqlite-state.sh not found at $PROJECT_ROOT/lib/sqlite-state.sh" >&2
        return 1
    fi
}

# ==============================================================================
# SEC-003B Test: Symlink Database Files are Rejected
# ==============================================================================
test_symlink_db_rejected() {
    log_info "SEC-003B Test 1: Symlink database files should be rejected..."

    local test_passed=true

    # Create an external database file
    touch "$TEST_TMP/external/malicious.db"

    # Create a symlink in STATE_DIR pointing to external database
    ln -sf "$TEST_TMP/external/malicious.db" "$STATE_DIR/symlinked.db"

    # Source the library
    if ! source_sqlite_state; then
        log_fail "SEC-003B: Could not source sqlite-state.sh"
        return 1
    fi

    # Test 1: validate_db_path should reject symlink
    if validate_db_path "$STATE_DIR/symlinked.db" "$STATE_DIR" 2>/dev/null; then
        log_fail "SEC-003B: validate_db_path failed to reject symlink database"
        test_passed=false
    fi

    # Test 2: sqlite_state_init should fail on symlink
    if sqlite_state_init "$STATE_DIR/symlinked.db" 2>/dev/null; then
        log_fail "SEC-003B: sqlite_state_init failed to reject symlink database"
        test_passed=false
    fi

    # Cleanup
    rm -f "$STATE_DIR/symlinked.db"

    if $test_passed; then
        log_pass "SEC-003B: Symlink database files correctly rejected"
    fi
}

# ==============================================================================
# SEC-003B Test: Paths Outside STATE_DIR are Rejected
# ==============================================================================
test_path_outside_state_dir_rejected() {
    log_info "SEC-003B Test 2: Paths outside STATE_DIR should be rejected..."

    local test_passed=true

    # Source the library
    if ! source_sqlite_state; then
        log_fail "SEC-003B: Could not source sqlite-state.sh"
        return 1
    fi

    # Test various path escape attempts
    local escape_paths=(
        "/tmp/escape.db"
        "/etc/passwd.db"
        "$TEST_TMP/external/escape.db"
        "../../../tmp/escape.db"
        "$STATE_DIR/../../../tmp/escape.db"
    )

    for path in "${escape_paths[@]}"; do
        if validate_db_path "$path" "$STATE_DIR" 2>/dev/null; then
            log_fail "SEC-003B: validate_db_path failed to reject path escape: $path"
            test_passed=false
        fi
    done

    # Test sqlite_state_init with external path
    if sqlite_state_init "$TEST_TMP/external/escape.db" 2>/dev/null; then
        log_fail "SEC-003B: sqlite_state_init failed to reject external path"
        test_passed=false
    fi

    if $test_passed; then
        log_pass "SEC-003B: Paths outside STATE_DIR correctly rejected"
    fi
}

# ==============================================================================
# SEC-003B Test: Normal Database Paths Work Correctly
# ==============================================================================
test_normal_db_path_works() {
    log_info "SEC-003B Test 3: Normal database paths should work correctly..."

    local test_passed=true

    # Source the library
    if ! source_sqlite_state; then
        log_fail "SEC-003B: Could not source sqlite-state.sh"
        return 1
    fi

    # Test 1: validate_db_path should accept normal path
    if ! validate_db_path "$STATE_DIR/normal.db" "$STATE_DIR" 2>/dev/null; then
        log_fail "SEC-003B: validate_db_path incorrectly rejected normal path"
        test_passed=false
    fi

    # Test 2: sqlite_state_init should succeed with normal path
    if ! sqlite_state_init "$STATE_DIR/test_normal.db" 2>/dev/null; then
        log_fail "SEC-003B: sqlite_state_init failed on normal database path"
        test_passed=false
    fi

    # Verify database was created
    if [[ ! -f "$STATE_DIR/test_normal.db" ]]; then
        log_fail "SEC-003B: Database file was not created"
        test_passed=false
    fi

    # Verify database has correct permissions (600)
    if [[ -f "$STATE_DIR/test_normal.db" ]]; then
        local perms
        perms=$(stat -c "%a" "$STATE_DIR/test_normal.db" 2>/dev/null || stat -f "%Lp" "$STATE_DIR/test_normal.db" 2>/dev/null)
        if [[ "$perms" != "600" ]]; then
            log_fail "SEC-003B: Database has incorrect permissions: $perms (expected 600)"
            test_passed=false
        fi
    fi

    # Test 3: Re-init on existing database should succeed
    if ! sqlite_state_init "$STATE_DIR/test_normal.db" 2>/dev/null; then
        log_fail "SEC-003B: sqlite_state_init failed on existing database"
        test_passed=false
    fi

    # Cleanup
    rm -f "$STATE_DIR/test_normal.db" "$STATE_DIR/test_normal.db-wal" "$STATE_DIR/test_normal.db-shm"

    if $test_passed; then
        log_pass "SEC-003B: Normal database paths work correctly"
    fi
}

# ==============================================================================
# SEC-003B Test: Parent Directory Symlinks are Detected
# ==============================================================================
test_parent_symlink_detected() {
    log_info "SEC-003B Test 4: Parent directory symlinks should be detected..."

    local test_passed=true

    # Source the library
    if ! source_sqlite_state; then
        log_fail "SEC-003B: Could not source sqlite-state.sh"
        return 1
    fi

    # Create a symlink parent directory attack
    mkdir -p "$TEST_TMP/external/fake_state"
    touch "$TEST_TMP/external/fake_state/target.db"

    # Create a symlink in autonomous_root pointing to external state
    ln -sf "$TEST_TMP/external/fake_state" "$AUTONOMOUS_ROOT/symlink_state"

    # Test: validate_db_path should detect parent symlink
    if validate_db_path "$AUTONOMOUS_ROOT/symlink_state/target.db" "$STATE_DIR" 2>/dev/null; then
        log_fail "SEC-003B: validate_db_path failed to detect parent directory symlink"
        test_passed=false
    fi

    # Cleanup
    rm -f "$AUTONOMOUS_ROOT/symlink_state"

    if $test_passed; then
        log_pass "SEC-003B: Parent directory symlinks correctly detected"
    fi
}

# ==============================================================================
# SEC-003B Test: Path Traversal Attempts are Blocked
# ==============================================================================
test_path_traversal_blocked() {
    log_info "SEC-003B Test 5: Path traversal attempts should be blocked..."

    local test_passed=true

    # Source the library
    if ! source_sqlite_state; then
        log_fail "SEC-003B: Could not source sqlite-state.sh"
        return 1
    fi

    # Test various path traversal attempts
    local traversal_paths=(
        "$STATE_DIR/../../../etc/passwd"
        "$STATE_DIR/subdir/../../../tmp/evil.db"
        "$STATE_DIR/./../../sensitive/data.db"
        "$STATE_DIR/test/../../../external/hack.db"
    )

    for path in "${traversal_paths[@]}"; do
        if validate_db_path "$path" "$STATE_DIR" 2>/dev/null; then
            log_fail "SEC-003B: validate_db_path failed to block traversal: $path"
            test_passed=false
        fi
    done

    if $test_passed; then
        log_pass "SEC-003B: Path traversal attempts correctly blocked"
    fi
}

# ==============================================================================
# SEC-003B Test: Race Condition Protection
# ==============================================================================
test_race_condition_protection() {
    log_info "SEC-003B Test 6: Race condition protection should work..."

    local test_passed=true

    # Source the library
    if ! source_sqlite_state; then
        log_fail "SEC-003B: Could not source sqlite-state.sh"
        return 1
    fi

    # Create a legitimate database first
    local test_db="$STATE_DIR/race_test.db"
    if ! sqlite_state_init "$test_db" 2>/dev/null; then
        log_fail "SEC-003B: Could not create initial database for race test"
        return 1
    fi

    # Simulate race condition by replacing with symlink
    rm -f "$test_db"
    ln -sf "$TEST_TMP/external/malicious.db" "$test_db"

    # Re-init should detect the symlink
    if sqlite_state_init "$test_db" 2>/dev/null; then
        log_fail "SEC-003B: sqlite_state_init failed to detect symlink swap (race condition)"
        test_passed=false
    fi

    # Cleanup
    rm -f "$test_db"

    if $test_passed; then
        log_pass "SEC-003B: Race condition protection working"
    fi
}

# ==============================================================================
# SEC-003B Test: Error Messages Contain SEC-003B Tag
# ==============================================================================
test_error_messages_tagged() {
    log_info "SEC-003B Test 7: Error messages should contain SEC-003B tag..."

    local test_passed=true

    # Source the library
    if ! source_sqlite_state; then
        log_fail "SEC-003B: Could not source sqlite-state.sh"
        return 1
    fi

    # Create a symlink database to trigger error
    ln -sf "$TEST_TMP/external/malicious.db" "$STATE_DIR/tagged_test.db"

    # Capture error output
    local error_output
    error_output=$(validate_db_path "$STATE_DIR/tagged_test.db" "$STATE_DIR" 2>&1 || true)

    # Check if error contains SEC-003B tag
    if [[ "$error_output" != *"SEC-003B"* ]]; then
        log_fail "SEC-003B: Error message does not contain SEC-003B tag: $error_output"
        test_passed=false
    fi

    # Cleanup
    rm -f "$STATE_DIR/tagged_test.db"

    if $test_passed; then
        log_pass "SEC-003B: Error messages properly tagged with SEC-003B"
    fi
}

# ==============================================================================
# SEC-003B Test: Multiple Extension Types Supported
# ==============================================================================
test_valid_extensions() {
    log_info "SEC-003B Test 8: Valid database extensions should be accepted..."

    local test_passed=true

    # Source the library
    if ! source_sqlite_state; then
        log_fail "SEC-003B: Could not source sqlite-state.sh"
        return 1
    fi

    # Test valid extensions
    local valid_extensions=(
        "$STATE_DIR/test.db"
        "$STATE_DIR/test.sqlite"
        "$STATE_DIR/test.sqlite3"
    )

    for path in "${valid_extensions[@]}"; do
        if ! validate_db_path "$path" "$STATE_DIR" 2>/dev/null; then
            log_fail "SEC-003B: validate_db_path incorrectly rejected valid extension: $path"
            test_passed=false
        fi
    done

    if $test_passed; then
        log_pass "SEC-003B: Valid database extensions accepted"
    fi
}

# ==============================================================================
# Main Test Runner
# ==============================================================================

run_all_tests() {
    echo "=============================================="
    echo "SEC-003B: SQLite Symlink Protection Tests"
    echo "=============================================="
    echo ""

    setup

    # Run all tests
    test_symlink_db_rejected
    test_path_outside_state_dir_rejected
    test_normal_db_path_works
    test_parent_symlink_detected
    test_path_traversal_blocked
    test_race_condition_protection
    test_error_messages_tagged
    test_valid_extensions

    teardown

    echo ""
    echo "=============================================="
    echo "SEC-003B Test Summary"
    echo "=============================================="
    echo -e "Passed:  ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Failed:  ${RED}${TESTS_FAILED}${NC}"
    echo -e "Skipped: ${YELLOW}${TESTS_SKIPPED}${NC}"
    echo ""

    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${RED}SEC-003B TESTS FAILED${NC}"
        return 1
    else
        echo -e "${GREEN}ALL SEC-003B TESTS PASSED${NC}"
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
        echo "  - test_symlink_db_rejected"
        echo "  - test_path_outside_state_dir_rejected"
        echo "  - test_normal_db_path_works"
        echo "  - test_parent_symlink_detected"
        echo "  - test_path_traversal_blocked"
        echo "  - test_race_condition_protection"
        echo "  - test_error_messages_tagged"
        echo "  - test_valid_extensions"
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
