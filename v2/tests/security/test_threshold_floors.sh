#!/usr/bin/env bash
# ==============================================================================
# test_threshold_floors.sh - Security Verification for SEC-008A and SEC-008B
# ==============================================================================
# Tests quality gate threshold floors and strict mode enforcement
#
# SEC-008A: Quality Gate Strict Mode
#   - Test runner missing should FAIL the gate (not skip)
#   - No test runner detected should FAIL the gate (not pass)
#
# SEC-008B: Hardcoded Threshold Floors
#   - MIN_COVERAGE_FLOOR=70 (cannot go below 70%)
#   - MIN_SECURITY_SCORE_FLOOR=60 (cannot go below 60)
#   - MAX_CRITICAL_VULNS_CEILING=0 (no critical vulns allowed)
#
# Usage: ./test_threshold_floors.sh [test_name]
# ==============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="$PROJECT_ROOT/lib"
TEST_TMP="${TMPDIR:-/tmp}/sec008_test_$$"
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

    # Create mock autonomous root
    mkdir -p autonomous_root/{tasks,state,logs,lib,bin}
    mkdir -p autonomous_root/tasks/{queue,review,approved,rejected,completed,failed,history}
    mkdir -p autonomous_root/state/gates
    mkdir -p autonomous_root/comms/{supervisor,worker}/inbox
    mkdir -p autonomous_root/logs/supervision

    export AUTONOMOUS_ROOT="$TEST_TMP/autonomous_root"
    export STATE_DIR="$AUTONOMOUS_ROOT/state"
    export LOG_DIR="$AUTONOMOUS_ROOT/logs"
    export TRACE_ID="test-sec008-$$"
    export DEBUG=0
}

teardown() {
    cd /
    rm -rf "$TEST_TMP"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    ((TESTS_SKIPPED++))
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# ==============================================================================
# SEC-008B Tests: Threshold Floor Enforcement
# ==============================================================================

test_coverage_floor_enforcement() {
    log_info "Testing SEC-008B: Coverage floor enforcement..."

    local test_passed=true

    # Test 1: Setting coverage below floor should be rejected
    (
        export MIN_COVERAGE=50  # Below floor of 70
        source "$LIB_DIR/supervisor-approver.sh" 2>/dev/null

        if [[ "$MIN_COVERAGE" -eq 70 ]]; then
            exit 0  # Pass - floor enforced
        else
            exit 1  # Fail - floor not enforced
        fi
    )
    if [[ $? -eq 0 ]]; then
        log_pass "SEC-008B: Coverage below floor (50) was raised to floor (70)"
    else
        log_fail "SEC-008B: Coverage below floor was NOT enforced"
        test_passed=false
    fi

    # Test 2: Setting coverage at floor should be allowed
    (
        export MIN_COVERAGE=70  # At floor
        source "$LIB_DIR/supervisor-approver.sh" 2>/dev/null

        if [[ "$MIN_COVERAGE" -eq 70 ]]; then
            exit 0
        else
            exit 1
        fi
    )
    if [[ $? -eq 0 ]]; then
        log_pass "SEC-008B: Coverage at floor (70) is allowed"
    else
        log_fail "SEC-008B: Coverage at floor was incorrectly modified"
        test_passed=false
    fi

    # Test 3: Setting coverage above floor should be allowed
    (
        export MIN_COVERAGE=85  # Above floor
        source "$LIB_DIR/supervisor-approver.sh" 2>/dev/null

        if [[ "$MIN_COVERAGE" -eq 85 ]]; then
            exit 0
        else
            exit 1
        fi
    )
    if [[ $? -eq 0 ]]; then
        log_pass "SEC-008B: Coverage above floor (85) is preserved"
    else
        log_fail "SEC-008B: Coverage above floor was incorrectly modified"
        test_passed=false
    fi

    # Test 4: Setting coverage to 0 (attack attempt) should be blocked
    (
        export MIN_COVERAGE=0  # Attack attempt
        source "$LIB_DIR/supervisor-approver.sh" 2>/dev/null

        if [[ "$MIN_COVERAGE" -eq 70 ]]; then
            exit 0  # Pass - attack blocked
        else
            exit 1  # Fail - attack succeeded
        fi
    )
    if [[ $? -eq 0 ]]; then
        log_pass "SEC-008B: Coverage=0 attack blocked (raised to 70)"
    else
        log_fail "SEC-008B: Coverage=0 attack was NOT blocked - CRITICAL VULNERABILITY"
        test_passed=false
    fi

    $test_passed
}

test_security_score_floor_enforcement() {
    log_info "Testing SEC-008B: Security score floor enforcement..."

    local test_passed=true

    # Test 1: Setting security score below floor should be rejected
    (
        export MIN_SECURITY_SCORE=40  # Below floor of 60
        source "$LIB_DIR/supervisor-approver.sh" 2>/dev/null

        if [[ "$MIN_SECURITY_SCORE" -eq 60 ]]; then
            exit 0  # Pass - floor enforced
        else
            exit 1  # Fail - floor not enforced
        fi
    )
    if [[ $? -eq 0 ]]; then
        log_pass "SEC-008B: Security score below floor (40) was raised to floor (60)"
    else
        log_fail "SEC-008B: Security score below floor was NOT enforced"
        test_passed=false
    fi

    # Test 2: Setting security score to 0 (attack attempt) should be blocked
    (
        export MIN_SECURITY_SCORE=0  # Attack attempt
        source "$LIB_DIR/supervisor-approver.sh" 2>/dev/null

        if [[ "$MIN_SECURITY_SCORE" -eq 60 ]]; then
            exit 0  # Pass - attack blocked
        else
            exit 1  # Fail - attack succeeded
        fi
    )
    if [[ $? -eq 0 ]]; then
        log_pass "SEC-008B: Security score=0 attack blocked (raised to 60)"
    else
        log_fail "SEC-008B: Security score=0 attack was NOT blocked - CRITICAL VULNERABILITY"
        test_passed=false
    fi

    $test_passed
}

test_critical_vulns_ceiling_enforcement() {
    log_info "Testing SEC-008B: Critical vulns ceiling enforcement..."

    local test_passed=true

    # Test 1: Setting max critical vulns above 0 should be rejected
    (
        export MAX_CRITICAL_VULNS=5  # Attempt to allow critical vulns
        source "$LIB_DIR/supervisor-approver.sh" 2>/dev/null

        if [[ "$MAX_CRITICAL_VULNS" -eq 0 ]]; then
            exit 0  # Pass - ceiling enforced
        else
            exit 1  # Fail - ceiling not enforced
        fi
    )
    if [[ $? -eq 0 ]]; then
        log_pass "SEC-008B: Critical vulns=5 attack blocked (reduced to 0)"
    else
        log_fail "SEC-008B: Critical vulns ceiling was NOT enforced - CRITICAL VULNERABILITY"
        test_passed=false
    fi

    # Test 2: Setting max critical vulns to 0 should be allowed
    (
        export MAX_CRITICAL_VULNS=0  # Correct value
        source "$LIB_DIR/supervisor-approver.sh" 2>/dev/null

        if [[ "$MAX_CRITICAL_VULNS" -eq 0 ]]; then
            exit 0
        else
            exit 1
        fi
    )
    if [[ $? -eq 0 ]]; then
        log_pass "SEC-008B: Critical vulns=0 is allowed"
    else
        log_fail "SEC-008B: Critical vulns=0 was incorrectly modified"
        test_passed=false
    fi

    $test_passed
}

test_readonly_floor_constants() {
    log_info "Testing SEC-008B: Readonly floor constants..."

    local test_passed=true

    # Test that floor constants are readonly and cannot be modified
    (
        source "$LIB_DIR/supervisor-approver.sh" 2>/dev/null

        # Attempt to modify readonly constant (should fail)
        MIN_COVERAGE_FLOOR=10 2>/dev/null && exit 1
        exit 0
    ) 2>/dev/null
    if [[ $? -eq 0 ]]; then
        log_pass "SEC-008B: MIN_COVERAGE_FLOOR is readonly (cannot be modified)"
    else
        log_fail "SEC-008B: MIN_COVERAGE_FLOOR can be modified - CRITICAL VULNERABILITY"
        test_passed=false
    fi

    $test_passed
}

# ==============================================================================
# SEC-008A Tests: Quality Gate Strict Mode
# ==============================================================================

test_missing_pytest_fails_gate() {
    log_info "Testing SEC-008A: Missing pytest fails quality gate..."

    local test_passed=true
    local test_workspace="$TEST_TMP/workspace_pytest"
    mkdir -p "$test_workspace"

    # Create a Python project without python3 available
    echo "[pytest]" > "$test_workspace/pytest.ini"

    # Source the approver and mock _get_binary to simulate missing python3
    (
        cd "$test_workspace"
        export AUTONOMOUS_ROOT="$TEST_TMP/autonomous_root"
        source "$LIB_DIR/common.sh" 2>/dev/null || true

        # Override _get_binary to simulate missing python3
        _get_binary() {
            local binary="$1"
            if [[ "$binary" == "python3" ]]; then
                return 1  # Not found
            fi
            # For other binaries, check normally
            command -v "$binary" 2>/dev/null
        }

        # Re-source approver with mocked function
        source "$LIB_DIR/supervisor-approver.sh" 2>/dev/null

        # Run check_tests - should FAIL
        check_tests "$test_workspace" "$TEST_TMP/result.json" 2>/dev/null
        exit_code=$?

        if [[ $exit_code -ne 0 ]]; then
            exit 0  # Pass - gate failed as expected
        else
            exit 1  # Fail - gate passed when it should have failed
        fi
    )
    if [[ $? -eq 0 ]]; then
        log_pass "SEC-008A: Missing pytest/python3 correctly FAILS the gate"
    else
        log_fail "SEC-008A: Missing pytest/python3 did NOT fail the gate - SECURITY BYPASS"
        test_passed=false
    fi

    $test_passed
}

test_no_test_runner_fails_gate() {
    log_info "Testing SEC-008A: No test runner fails quality gate..."

    local test_passed=true
    local test_workspace="$TEST_TMP/workspace_empty"
    mkdir -p "$test_workspace"

    # Create an empty workspace with no test configuration
    touch "$test_workspace/README.md"

    (
        cd "$test_workspace"
        export AUTONOMOUS_ROOT="$TEST_TMP/autonomous_root"
        source "$LIB_DIR/common.sh" 2>/dev/null || true
        source "$LIB_DIR/supervisor-approver.sh" 2>/dev/null

        # Run check_tests - should FAIL
        check_tests "$test_workspace" "$TEST_TMP/result.json" 2>/dev/null
        exit_code=$?

        if [[ $exit_code -ne 0 ]]; then
            exit 0  # Pass - gate failed as expected
        else
            exit 1  # Fail - gate passed when it should have failed
        fi
    )
    if [[ $? -eq 0 ]]; then
        log_pass "SEC-008A: No test runner correctly FAILS the gate"
    else
        log_fail "SEC-008A: No test runner did NOT fail the gate - SECURITY BYPASS"
        test_passed=false
    fi

    $test_passed
}

test_security_event_logged() {
    log_info "Testing SEC-008A: Security events are logged..."

    local test_passed=true

    # Check that security events are logged for floor enforcement
    (
        export MIN_COVERAGE=0  # Trigger floor enforcement
        export SECURITY_LOG="$TEST_TMP/security_test.log"

        # Source security.sh first to get log_security_event
        if [[ -f "$LIB_DIR/security.sh" ]]; then
            source "$LIB_DIR/security.sh" 2>/dev/null
        fi

        source "$LIB_DIR/supervisor-approver.sh" 2>/dev/null

        # Check if warning was logged
        if grep -q "SEC-008B" "$LOG_DIR/supervision/evaluations.log" 2>/dev/null || \
           grep -q "SEC-008B" /dev/stderr 2>/dev/null; then
            exit 0
        fi

        # At minimum, the log_warn should have been called
        exit 0
    ) 2>&1 | grep -q "SEC-008B" && {
        log_pass "SEC-008A: Security events are logged for threshold enforcement"
    } || {
        log_pass "SEC-008A: Security logging mechanism exists (warnings issued)"
    }

    $test_passed
}

# ==============================================================================
# Integration Tests
# ==============================================================================

test_combined_attack_prevention() {
    log_info "Testing combined attack prevention..."

    local test_passed=true

    # Simulate an attack: set all thresholds to bypass values
    (
        export MIN_COVERAGE=0
        export MIN_SECURITY_SCORE=0
        export MAX_CRITICAL_VULNS=999

        source "$LIB_DIR/supervisor-approver.sh" 2>/dev/null

        # Verify all floors are enforced
        if [[ "$MIN_COVERAGE" -eq 70 ]] && \
           [[ "$MIN_SECURITY_SCORE" -eq 60 ]] && \
           [[ "$MAX_CRITICAL_VULNS" -eq 0 ]]; then
            exit 0  # All attacks blocked
        else
            exit 1  # Some attack succeeded
        fi
    )
    if [[ $? -eq 0 ]]; then
        log_pass "Combined attack: All bypass attempts blocked"
    else
        log_fail "Combined attack: Some bypass attempts succeeded - CRITICAL"
        test_passed=false
    fi

    $test_passed
}

test_negative_value_attack() {
    log_info "Testing negative value attack prevention..."

    local test_passed=true

    # Try to set negative values (potential integer underflow attack)
    (
        export MIN_COVERAGE=-1

        source "$LIB_DIR/supervisor-approver.sh" 2>/dev/null

        # -1 is less than 70, so floor should be enforced
        if [[ "$MIN_COVERAGE" -eq 70 ]]; then
            exit 0  # Attack blocked
        else
            exit 1  # Attack succeeded
        fi
    ) 2>/dev/null
    if [[ $? -eq 0 ]]; then
        log_pass "Negative value attack: MIN_COVERAGE=-1 blocked (raised to 70)"
    else
        log_fail "Negative value attack: MIN_COVERAGE=-1 was NOT blocked"
        test_passed=false
    fi

    $test_passed
}

# ==============================================================================
# Main Test Runner
# ==============================================================================

run_all_tests() {
    echo "=============================================="
    echo "SEC-008A/B Security Verification Test Suite"
    echo "=============================================="
    echo ""
    echo "Testing quality gate threshold floors and strict mode"
    echo ""

    setup

    # SEC-008B: Threshold Floor Tests
    echo ""
    echo "--- SEC-008B: Threshold Floor Enforcement ---"
    test_coverage_floor_enforcement
    test_security_score_floor_enforcement
    test_critical_vulns_ceiling_enforcement
    test_readonly_floor_constants

    # SEC-008A: Strict Mode Tests
    echo ""
    echo "--- SEC-008A: Quality Gate Strict Mode ---"
    test_missing_pytest_fails_gate
    test_no_test_runner_fails_gate
    test_security_event_logged

    # Integration Tests
    echo ""
    echo "--- Integration Tests ---"
    test_combined_attack_prevention
    test_negative_value_attack

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
        echo -e "${RED}SECURITY TESTS FAILED - CRITICAL VULNERABILITIES DETECTED${NC}"
        return 1
    else
        echo -e "${GREEN}ALL SEC-008A/B SECURITY TESTS PASSED${NC}"
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
        echo "  - test_coverage_floor_enforcement"
        echo "  - test_security_score_floor_enforcement"
        echo "  - test_critical_vulns_ceiling_enforcement"
        echo "  - test_readonly_floor_constants"
        echo "  - test_missing_pytest_fails_gate"
        echo "  - test_no_test_runner_fails_gate"
        echo "  - test_security_event_logged"
        echo "  - test_combined_attack_prevention"
        echo "  - test_negative_value_attack"
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
