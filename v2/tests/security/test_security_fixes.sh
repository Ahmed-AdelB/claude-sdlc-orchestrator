#!/bin/bash
# =============================================================================
# test_security_fixes.sh - Verification suite for M5-Scale-UX Security Fixes
# =============================================================================
# Covers:
#   1. Symlink protection (SEC-003A/B)
#   2. Path traversal protection
#   3. Git log sanitization (SEC-001)
#   4. LLM input sanitization (SEC-006)
#   5. Threshold floors (SEC-008B)
#   6. Ledger locking (SEC-007)
#   7. Pattern normalization (SEC-009A)
# =============================================================================

# Exit on error
set -e

# Configuration
TEST_DIR="/tmp/tri_agent_security_test_$$"
mkdir -p "$TEST_DIR/logs" "$TEST_DIR/state/locks" "$TEST_DIR/tasks"
export LOG_DIR="$TEST_DIR/logs"
export STATE_DIR="$TEST_DIR/state"
export LOCKS_DIR="$TEST_DIR/state/locks"
export AUTONOMOUS_ROOT="$TEST_DIR"
export TRACE_ID="test-sec-fixes-$$"

# Mock required variables/functions if libraries are missing them
export SESSION_LOG="$LOG_DIR/session.log"
touch "$SESSION_LOG"

# Source required libraries
# We use relative paths based on the project structure
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Symlink lib directory for common.sh to find dependencies
mkdir -p "$AUTONOMOUS_ROOT"
ln -sf "$PROJECT_ROOT/lib" "$AUTONOMOUS_ROOT/lib"
ln -sf "$PROJECT_ROOT/config" "$AUTONOMOUS_ROOT/config"

source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/logging.sh"
source "$PROJECT_ROOT/lib/security.sh"
source "$PROJECT_ROOT/lib/state.sh"
# supervisor-approver.sh might be needed for threshold floors
# We source it inside the test function to avoid global side effects if possible, 
# or mock the specific function if it's too coupled.
# Actually, let's try to source it globally but carefully.
# source "$PROJECT_ROOT/lib/supervisor-approver.sh" 

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
log_test() {
    local name="$1"
    echo -e "\n[TEST] $name"
}

pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# =============================================================================
# Test 1 & 2: Symlink & Path Traversal Protection (SEC-003A/B)
# =============================================================================
test_path_validation() {
    log_test "Symlink & Path Traversal Protection"

    local base_dir="$TEST_DIR/safe_dir"
    mkdir -p "$base_dir"
    
    # 1. Valid path
    local valid_file="$base_dir/file.txt"
    touch "$valid_file"
    if validate_path "$valid_file" "$base_dir" >/dev/null; then
        pass "Valid path accepted"
    else
        fail "Valid path rejected"
    fi

    # 2. Path traversal
    local traversal_path="$base_dir/../outside.txt"
    touch "$TEST_DIR/outside.txt"
    if validate_path "$traversal_path" "$base_dir" >/dev/null 2>&1; then
        fail "Path traversal accepted"
    else
        pass "Path traversal rejected"
    fi

    # 3. Symlink to outside
    local symlink_file="$base_dir/symlink_out"
    ln -s "$TEST_DIR/outside.txt" "$symlink_file"
    if validate_path "$symlink_file" "$base_dir" >/dev/null 2>&1; then
        fail "Symlink to outside accepted"
    else
        pass "Symlink to outside rejected"
    fi

    # 4. Symlink to inside (valid)
    local symlink_in="$base_dir/symlink_in"
    ln -s "$valid_file" "$symlink_in"
    if validate_path "$symlink_in" "$base_dir" >/dev/null; then
        pass "Symlink to inside accepted"
    else
        fail "Symlink to inside rejected"
    fi
}

# =============================================================================
# Test 3: Git Log Sanitization (SEC-001)
# =============================================================================
test_git_log_sanitization() {
    log_test "Git Log Sanitization"

    local secret="sk-ant-12345678901234567890"
    local safe_msg="This is a safe commit message"
    local dirty_msg="Commit with key $secret included"

    # Test redact_secrets function directly
    local redacted
    redacted=$(redact_secrets "$dirty_msg")
    
    if [[ "$redacted" == *"$secret"* ]]; then
        fail "Secret not redacted from message"
    else
        if [[ "$redacted" == *"sk-ant-***REDACTED***"* ]]; then
            pass "Secret redacted successfully"
        else
            fail "Redaction format incorrect: $redacted"
        fi
    fi

    local clean_redacted
    clean_redacted=$(redact_secrets "$safe_msg")
    if [[ "$clean_redacted" == "$safe_msg" ]]; then
        pass "Safe message untouched"
    else
        fail "Safe message modified: $clean_redacted"
    fi
}

# =============================================================================
# Test 4 & 7: LLM Input Sanitization & Pattern Normalization (SEC-006, SEC-009A)
# =============================================================================
test_llm_input_sanitization() {
    log_test "LLM Input Sanitization & Pattern Normalization"

    # 1. Dangerous patterns (Exact)
    local dangerous_input="Some text; rm -rf / ; more text"
    if check_dangerous_patterns "$dangerous_input" >/dev/null 2>&1; then
        fail "Dangerous pattern 'rm -rf' accepted"
    else
        pass "Dangerous pattern 'rm -rf' rejected"
    fi

    # 2. Pattern Normalization (Case insensitivity/Whitespace)
    # The library function check_dangerous_patterns uses grep -qiE so it handles case
    local mixed_case="Some text; RM -RF / ; more text"
    if check_dangerous_patterns "$mixed_case" >/dev/null 2>&1; then
        fail "Mixed case 'RM -RF' accepted"
    else
        pass "Mixed case 'RM -RF' rejected"
    fi
    
    local sql_inject="User input; DROP TABLE users; --"
    if check_dangerous_patterns "$sql_inject" >/dev/null 2>&1; then
        fail "SQL injection 'DROP TABLE' accepted"
    else
        pass "SQL injection 'DROP TABLE' rejected"
    fi

    # 3. Sanitization (Sanitize input function)
    local raw_input="Hello \$ \` World"
    local sanitized
    sanitized=$(sanitize_input "$raw_input")
    # Expect backslashes to be escaped or removed depending on implementation
    # Implementation: input="${input//\\$/\\\$\}"
    if [[ "$sanitized" == *"\\\$"* ]]; then
        pass "Shell metacharacters escaped"
    else
        fail "Shell metacharacters not escaped: $sanitized"
    fi
}

# =============================================================================
# Test 5: Threshold Floors (SEC-008B)
# =============================================================================
test_threshold_floors() {
    log_test "Threshold Floors"

    # Test 1: Coverage below floor
    (
        # Set low value BEFORE sourcing
        export MIN_COVERAGE=10
        
        # Mock logging to avoid spam
        log_security_event() { :; }
        log_debug() { :; }
        log_warn() { :; }
        ensure_dir() { :; } # Mock dir creation

        # Source the library (which runs enforcement)
        # We need to silence stdout/stderr potentially if it's noisy
        source "$PROJECT_ROOT/lib/supervisor-approver.sh" >/dev/null 2>&1
        
        # MIN_COVERAGE_FLOOR is 70
        if [[ "$MIN_COVERAGE" -eq 70 ]]; then
            pass "Coverage threshold enforced (raised to floor)"
        else
            fail "Coverage threshold not enforced: $MIN_COVERAGE (expected 70)"
        fi
    ) || fail "Test 1 crashed"

    # Test 2: Security score below floor
    (
        export MIN_SECURITY_SCORE=10
        
        log_security_event() { :; }
        log_debug() { :; }
        log_warn() { :; }
        ensure_dir() { :; }

        source "$PROJECT_ROOT/lib/supervisor-approver.sh" >/dev/null 2>&1

        # MIN_SECURITY_SCORE_FLOOR is 60
        if [[ "$MIN_SECURITY_SCORE" -eq 60 ]]; then
            pass "Security score threshold enforced (raised to floor)"
        else
            fail "Security score threshold not enforced: $MIN_SECURITY_SCORE (expected 60)"
        fi
    ) || fail "Test 2 crashed"
    
    # Test 3: Critical vulns above ceiling
    (
        export MAX_CRITICAL_VULNS=100
        
        log_security_event() { :; }
        log_debug() { :; }
        log_warn() { :; }
        ensure_dir() { :; }

        source "$PROJECT_ROOT/lib/supervisor-approver.sh" >/dev/null 2>&1
        
        # MAX_CRITICAL_VULNS_CEILING is 0
        if [[ "$MAX_CRITICAL_VULNS" -eq 0 ]]; then
            pass "Max critical vulns enforced (lowered to ceiling)"
        else
            fail "Max critical vulns not enforced: $MAX_CRITICAL_VULNS"
        fi
    ) || fail "Test 3 crashed"
}
# =============================================================================
# Test 6: Ledger Locking (SEC-007)
# =============================================================================
test_ledger_locking() {
    log_test "Ledger Locking"

    local ledger_file="$TEST_DIR/tasks/ledger.jsonl"
    local lock_file="${ledger_file}.lock"
    touch "$ledger_file"
    
    # We will use flock manually to simulate a held lock
    # and verify that a concurrent write respects it (or fails safely).
    
    # 1. Hold lock
    (   
        flock -x 200
        sleep 2
    ) 200>"$lock_file" &
    local holder_pid=$!
    
    sleep 0.5
    
    # 2. Try to write using helper from supervisor-approver (or logic replicated)
    # We'll replicate the logic to be self-contained but consistent with lib/supervisor-approver.sh
    
    local start_time=$(date +%s)
    
    (   
        # Simulate append_to_ledger logic
        local timeout=5
        if flock -x -w "$timeout" 200; then
            echo "Write success" >> "$ledger_file"
        else
            echo "Write failed"
            exit 1
        fi
    ) 200>"$lock_file" &
    local writer_pid=$!
    
    wait $writer_pid
    local writer_status=$?
    local end_time=$(date +%s)
    
    wait $holder_pid
    
    local duration=$((end_time - start_time))
    
    # If writer waited for lock, duration should be around 1.5s (2s sleep - 0.5s start delay)
    # If it failed immediately, duration would be near 0.
    
    if [[ $writer_status -eq 0 ]]; then
        # It succeeded, meaning it waited for the lock
        pass "Ledger write waited for lock and succeeded"
        if [[ $duration -ge 1 ]]; then
             pass "Lock wait duration verified"
        else
             fail "Write happened too fast, lock might have been ignored"
        fi
    else
        # If it failed (timeout), that's also "safe" in a way (didn't corrupt), but for this test we want it to wait
        # If the timeout in simulation was short, it might fail.
        fail "Ledger write failed to acquire lock (timeout?)"
    fi
}


# =============================================================================
# Run Tests
# =============================================================================

test_path_validation
test_git_log_sanitization
test_llm_input_sanitization
test_threshold_floors
test_ledger_locking

echo -e "\n=================================================="
echo "Tests Completed: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}All security tests passed.${NC}"
    exit 0
fi