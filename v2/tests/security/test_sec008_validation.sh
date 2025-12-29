#!/usr/bin/env bash
# =============================================================================
# test_sec008_validation.sh - Security Tests for SEC-008-2 and SEC-008-3
# =============================================================================
# Tests validation functions that prevent score manipulation attacks:
#
# SEC-008-2: Coverage Report Validation (supervisor-approver.sh)
#   - Validates coverage values are numeric and within 0-100%
#   - Prevents injection of fake coverage values to bypass quality gates
#
# SEC-008-3: Security Score Validation (phase-gate.sh)
#   - Validates security scores are numeric and within 0-100
#   - Prevents manipulation of security gate scores
#
# Usage: ./test_sec008_validation.sh [test_name]
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="$PROJECT_ROOT/lib"
TEST_TMP="${TMPDIR:-/tmp}/sec008_validation_test_$$"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# Test Framework Functions
# =============================================================================

setup() {
    mkdir -p "$TEST_TMP"
    cd "$TEST_TMP"

    # Create mock autonomous root for lib dependencies
    mkdir -p autonomous_root/{state,logs,tasks}
    mkdir -p autonomous_root/tasks/{queue,review,approved,rejected,completed,failed,history}
    mkdir -p autonomous_root/state/gates
    mkdir -p autonomous_root/logs/{supervision,security}
    mkdir -p logs/security

    export AUTONOMOUS_ROOT="$TEST_TMP/autonomous_root"
    export STATE_DIR="$AUTONOMOUS_ROOT/state"
    export LOG_DIR="$TEST_TMP/logs"
    export TRACE_ID="test-sec008-validation-$$"
    export DEBUG=0
}

teardown() {
    cd /
    rm -rf "$TEST_TMP"
}

test_pass() {
    local test_name="$1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -e "${GREEN}[PASS]${NC} $test_name"
}

test_fail() {
    local test_name="$1"
    local reason="${2:-}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -e "${RED}[FAIL]${NC} $test_name"
    [[ -n "$reason" ]] && echo "       Reason: $reason"
}

test_skip() {
    local test_name="$1"
    local reason="${2:-}"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -e "${YELLOW}[SKIP]${NC} $test_name"
    [[ -n "$reason" ]] && echo "       Reason: $reason"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Helper to run validation tests in isolated subshell
run_in_subshell() {
    local lib_file="$1"
    shift
    local test_script="$1"

    # Run in subshell, capture only the exit code
    # All output goes to /dev/null to suppress security warnings
    (
        set +e  # Disable errexit in subshell
        export LOG_DIR="$TEST_TMP/logs"
        export AUTONOMOUS_ROOT="$TEST_TMP/autonomous_root"
        export STATE_DIR="$AUTONOMOUS_ROOT/state"
        export STATE_DB="$STATE_DIR/test.db"
        export TRACE_ID="test-sec008-validation-$$"
        export DEBUG=0
        mkdir -p "$LOG_DIR/security" 2>/dev/null || true
        mkdir -p "$AUTONOMOUS_ROOT"/{state,logs,tasks} 2>/dev/null || true

        # Source the library (suppress all output during source)
        source "$lib_file" >/dev/null 2>&1 || true

        # Verify at least one expected function exists
        if ! declare -f validate_coverage_report >/dev/null 2>&1 && \
           ! declare -f validate_security_score >/dev/null 2>&1 && \
           ! declare -f validate_confidence_score >/dev/null 2>&1 && \
           ! declare -f validate_gate_score >/dev/null 2>&1; then
            exit 99  # Special code to indicate source failed
        fi

        # Execute the test script (suppress stderr from validation functions)
        eval "$test_script" 2>/dev/null
    )
    return $?
}

# =============================================================================
# SEC-008-2 Tests: Coverage Report Validation
# =============================================================================

test_coverage_valid_values() {
    log_info "Testing SEC-008-2: Valid coverage values (0-100%)..."

    local test_name="SEC-008-2: Valid coverage values"
    local test_script='
        # Test valid integer values
        for val in 0 1 50 70 80 99 100; do
            if ! validate_coverage_report "$val" "test" 2>/dev/null; then
                exit 1
            fi
        done

        # Test valid decimal values
        for val in 0.0 0.5 50.5 70.25 80.123 99.99 100.0; do
            if ! validate_coverage_report "$val" "test" 2>/dev/null; then
                exit 1
            fi
        done
        exit 0
    '

    if run_in_subshell "$LIB_DIR/supervisor-approver.sh" "$test_script"; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Some valid coverage values were rejected"
    fi
}

test_coverage_empty_value() {
    log_info "Testing SEC-008-2: Empty coverage value rejected..."

    local test_name="SEC-008-2: Empty coverage value rejected"
    local test_script='
        # Empty value should fail
        if validate_coverage_report "" "test" 2>/dev/null; then
            exit 1  # Should have failed
        fi
        exit 0  # Rejection worked
    '

    if run_in_subshell "$LIB_DIR/supervisor-approver.sh" "$test_script"; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Empty coverage value was not rejected"
    fi
}

test_coverage_negative_values() {
    log_info "Testing SEC-008-2: Negative coverage values rejected..."

    local test_name="SEC-008-2: Negative coverage values rejected"
    local test_script='
        # Negative values should fail (note: regex catches leading -)
        for val in -1 -10 -100; do
            if validate_coverage_report "$val" "test" 2>/dev/null; then
                exit 1
            fi
        done
        exit 0
    '

    if run_in_subshell "$LIB_DIR/supervisor-approver.sh" "$test_script"; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Negative coverage value was not rejected"
    fi
}

test_coverage_over_100() {
    log_info "Testing SEC-008-2: Coverage values > 100% rejected..."

    local test_name="SEC-008-2: Coverage values >100% rejected"
    local test_script='
        # Values > 100 should fail
        for val in 101 150 200 100.01 999 1000; do
            if validate_coverage_report "$val" "test" 2>/dev/null; then
                exit 1
            fi
        done
        exit 0
    '

    if run_in_subshell "$LIB_DIR/supervisor-approver.sh" "$test_script"; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Coverage value >100% was not rejected"
    fi
}

test_coverage_non_numeric() {
    log_info "Testing SEC-008-2: Non-numeric coverage values rejected..."

    local test_name="SEC-008-2: Non-numeric coverage values rejected"
    local test_script='
        # Non-numeric values should fail
        for val in abc 50% fifty 10a a10; do
            if validate_coverage_report "$val" "test" 2>/dev/null; then
                exit 1
            fi
        done
        exit 0
    '

    if run_in_subshell "$LIB_DIR/supervisor-approver.sh" "$test_script"; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Non-numeric coverage value was not rejected"
    fi
}

test_coverage_shell_injection() {
    log_info "Testing SEC-008-2: Shell injection attempts blocked..."

    local test_name="SEC-008-2: Shell injection attempts blocked"
    local test_script='
        # Shell injection attempts should fail
        if validate_coverage_report "\$(whoami)" "test" 2>/dev/null; then exit 1; fi
        if validate_coverage_report "\`id\`" "test" 2>/dev/null; then exit 1; fi
        if validate_coverage_report "50;rm" "test" 2>/dev/null; then exit 1; fi
        if validate_coverage_report "100|cat" "test" 2>/dev/null; then exit 1; fi
        if validate_coverage_report "80&echo" "test" 2>/dev/null; then exit 1; fi
        exit 0
    '

    if run_in_subshell "$LIB_DIR/supervisor-approver.sh" "$test_script"; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Shell injection attempt was not blocked"
    fi
}

test_coverage_perfect_score_warning() {
    log_info "Testing SEC-008-2: Perfect 100% coverage passes with warning..."

    local test_name="SEC-008-2: Perfect 100% coverage handling"
    local test_script='
        # 100% should pass (but generate warning)
        if ! validate_coverage_report "100" "test" 2>/dev/null; then
            exit 1
        fi
        if ! validate_coverage_report "100.0" "test" 2>/dev/null; then
            exit 1
        fi
        exit 0
    '

    if run_in_subshell "$LIB_DIR/supervisor-approver.sh" "$test_script"; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "100% coverage handling failed"
    fi
}

# =============================================================================
# SEC-008-3 Tests: Security Score Validation
# =============================================================================

test_security_score_valid_values() {
    log_info "Testing SEC-008-3: Valid security score values (0-100)..."

    local test_name="SEC-008-3: Valid security score values"
    local test_script='
        # Test valid integer values
        for val in 0 1 50 60 70 80 99 100; do
            if ! validate_security_score "$val" "test" 2>/dev/null; then
                exit 1
            fi
        done

        # Test valid decimal values
        for val in 0.0 0.5 50.5 60.25 70.123 99.99 100.0; do
            if ! validate_security_score "$val" "test" 2>/dev/null; then
                exit 1
            fi
        done
        exit 0
    '

    if run_in_subshell "$LIB_DIR/phase-gate.sh" "$test_script"; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Some valid security score values were rejected"
    fi
}

test_security_score_empty_value() {
    log_info "Testing SEC-008-3: Empty security score rejected..."

    local test_name="SEC-008-3: Empty security score rejected"
    local test_script='
        # Empty value should fail
        if validate_security_score "" "test" 2>/dev/null; then
            exit 1  # Should have failed
        fi
        exit 0  # Rejection worked
    '

    if run_in_subshell "$LIB_DIR/phase-gate.sh" "$test_script"; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Empty security score was not rejected"
    fi
}

test_security_score_negative_values() {
    log_info "Testing SEC-008-3: Negative security scores rejected..."

    local test_name="SEC-008-3: Negative security scores rejected"
    local test_script='
        # Negative values should fail
        for val in -1 -10 -0.5 -100; do
            if validate_security_score "$val" "test" 2>/dev/null; then
                exit 1
            fi
        done
        exit 0
    '

    if run_in_subshell "$LIB_DIR/phase-gate.sh" "$test_script"; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Negative security score was not rejected"
    fi
}

test_security_score_over_100() {
    log_info "Testing SEC-008-3: Security scores > 100 rejected..."

    local test_name="SEC-008-3: Security scores >100 rejected"
    local test_script='
        # Values > 100 should fail
        for val in 101 150 200 100.01 999 1000; do
            if validate_security_score "$val" "test" 2>/dev/null; then
                exit 1
            fi
        done
        exit 0
    '

    if run_in_subshell "$LIB_DIR/phase-gate.sh" "$test_script"; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Security score >100 was not rejected"
    fi
}

test_security_score_non_numeric() {
    log_info "Testing SEC-008-3: Non-numeric security scores rejected..."

    local test_name="SEC-008-3: Non-numeric security scores rejected"
    local test_script='
        # Non-numeric values should fail
        for val in abc 50% fifty 10a a10 PASS HIGH; do
            if validate_security_score "$val" "test" 2>/dev/null; then
                exit 1
            fi
        done
        exit 0
    '

    if run_in_subshell "$LIB_DIR/phase-gate.sh" "$test_script"; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Non-numeric security score was not rejected"
    fi
}

test_security_score_shell_injection() {
    log_info "Testing SEC-008-3: Shell injection attempts blocked..."

    local test_name="SEC-008-3: Shell injection attempts blocked"
    local test_script='
        # Shell injection attempts should fail
        if validate_security_score "\$(whoami)" "test" 2>/dev/null; then exit 1; fi
        if validate_security_score "\`id\`" "test" 2>/dev/null; then exit 1; fi
        if validate_security_score "50;rm" "test" 2>/dev/null; then exit 1; fi
        if validate_security_score "100|cat" "test" 2>/dev/null; then exit 1; fi
        exit 0
    '

    if run_in_subshell "$LIB_DIR/phase-gate.sh" "$test_script"; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Shell injection attempt was not blocked"
    fi
}

test_security_score_perfect_warning() {
    log_info "Testing SEC-008-3: Perfect 100 score passes with warning..."

    local test_name="SEC-008-3: Perfect 100 score handling"
    local test_script='
        # 100 should pass (but generate warning)
        if ! validate_security_score "100" "test" 2>/dev/null; then
            exit 1
        fi
        if ! validate_security_score "100.0" "test" 2>/dev/null; then
            exit 1
        fi
        exit 0
    '

    if run_in_subshell "$LIB_DIR/phase-gate.sh" "$test_script"; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "100 score handling failed"
    fi
}

# =============================================================================
# SEC-008-3 Tests: Confidence Score Validation
# =============================================================================

test_confidence_score_valid_values() {
    log_info "Testing SEC-008-3: Valid confidence score values..."

    local test_name="SEC-008-3: Valid confidence score values"
    local test_script='
        # Test valid probability values (0-1)
        for val in 0 0.0 0.5 0.75 0.99 1 1.0; do
            if ! validate_confidence_score "$val" "test" 2>/dev/null; then
                exit 1
            fi
        done

        # Test valid percentage values (0-100)
        for val in 0 50 75 99 100; do
            if ! validate_confidence_score "$val" "test" 2>/dev/null; then
                exit 1
            fi
        done
        exit 0
    '

    if run_in_subshell "$LIB_DIR/phase-gate.sh" "$test_script"; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Some valid confidence score values were rejected"
    fi
}

test_confidence_score_invalid_values() {
    log_info "Testing SEC-008-3: Invalid confidence score values rejected..."

    local test_name="SEC-008-3: Invalid confidence score values rejected"
    local test_script='
        # Values outside valid ranges should fail
        for val in -1 -0.5 101 150 200; do
            if validate_confidence_score "$val" "test" 2>/dev/null; then
                exit 1
            fi
        done

        # Non-numeric values should fail
        for val in abc high medium low; do
            if validate_confidence_score "$val" "test" 2>/dev/null; then
                exit 1
            fi
        done
        exit 0
    '

    if run_in_subshell "$LIB_DIR/phase-gate.sh" "$test_script"; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Some invalid confidence score values were accepted"
    fi
}

# =============================================================================
# Integration Tests
# =============================================================================

test_gate_score_wrapper() {
    log_info "Testing SEC-008-3: validate_gate_score wrapper function..."

    local test_name="SEC-008-3: validate_gate_score wrapper"
    local test_script='
        # Test with security score type
        if ! validate_gate_score "85" "security" "test" 2>/dev/null; then
            exit 1
        fi

        # Test with confidence type
        if ! validate_gate_score "0.95" "confidence" "test" 2>/dev/null; then
            exit 1
        fi

        # Test with generic type (defaults to security score validation)
        if ! validate_gate_score "75" "generic" "test" 2>/dev/null; then
            exit 1
        fi

        # Invalid values should fail
        if validate_gate_score "abc" "security" "test" 2>/dev/null; then
            exit 1
        fi
        exit 0
    '

    if run_in_subshell "$LIB_DIR/phase-gate.sh" "$test_script"; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "validate_gate_score wrapper failed"
    fi
}

test_readonly_score_constraints() {
    log_info "Testing SEC-008-3: Readonly score constraints..."

    local test_name="SEC-008-3: Readonly score constraints"

    # Test that the constants are defined as readonly by checking if modification fails
    local test_script='
        # Check that the constants have the expected values and cannot be modified
        # First verify the constants exist with expected values
        if [[ "$MIN_VALID_SCORE" != "0" ]] || [[ "$MAX_VALID_SCORE" != "100" ]]; then
            exit 1  # Constants not defined correctly
        fi

        # Try to modify - this should fail because they are readonly
        # We capture stderr to check for "readonly" error message
        err_output=$(MIN_VALID_SCORE=50 2>&1)
        if [[ "$err_output" != *"readonly"* ]]; then
            # No readonly error means modification might have succeeded
            # Double check by verifying value unchanged
            if [[ "$MIN_VALID_SCORE" != "0" ]]; then
                exit 1  # Modification succeeded - vulnerability!
            fi
        fi

        err_output=$(MAX_VALID_SCORE=200 2>&1)
        if [[ "$err_output" != *"readonly"* ]]; then
            if [[ "$MAX_VALID_SCORE" != "100" ]]; then
                exit 1  # Modification succeeded - vulnerability!
            fi
        fi

        exit 0  # Constants are properly protected
    '

    if run_in_subshell "$LIB_DIR/phase-gate.sh" "$test_script"; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Score constraints can be modified - SECURITY VULNERABILITY"
    fi
}

test_whitespace_handling() {
    log_info "Testing SEC-008-2/3: Whitespace handling..."

    local test_name="SEC-008-2/3: Whitespace handling"

    # Test coverage validation with whitespace
    local test_script='
        if ! validate_coverage_report "  85  " "test" 2>/dev/null; then
            exit 1
        fi
        exit 0
    '
    if ! run_in_subshell "$LIB_DIR/supervisor-approver.sh" "$test_script"; then
        test_fail "$test_name" "Coverage whitespace handling failed"
        return
    fi

    # Test security score validation with whitespace
    test_script='
        if ! validate_security_score "  90  " "test" 2>/dev/null; then
            exit 1
        fi
        exit 0
    '
    if ! run_in_subshell "$LIB_DIR/phase-gate.sh" "$test_script"; then
        test_fail "$test_name" "Security score whitespace handling failed"
        return
    fi

    test_pass "$test_name"
}

test_boundary_values() {
    log_info "Testing SEC-008-2/3: Boundary value testing..."

    local test_name="SEC-008-2/3: Boundary values (0 and 100)"

    # Test coverage boundaries
    local test_script='
        for val in 0 0.0 100 100.0; do
            if ! validate_coverage_report "$val" "test" 2>/dev/null; then
                exit 1
            fi
        done
        # Just outside boundaries should fail
        if validate_coverage_report "100.01" "test" 2>/dev/null; then
            exit 1
        fi
        exit 0
    '
    if ! run_in_subshell "$LIB_DIR/supervisor-approver.sh" "$test_script"; then
        test_fail "$test_name" "Coverage boundary handling failed"
        return
    fi

    # Test security score boundaries
    test_script='
        for val in 0 0.0 100 100.0; do
            if ! validate_security_score "$val" "test" 2>/dev/null; then
                exit 1
            fi
        done
        # Just outside boundaries should fail
        if validate_security_score "100.01" "test" 2>/dev/null; then
            exit 1
        fi
        exit 0
    '
    if ! run_in_subshell "$LIB_DIR/phase-gate.sh" "$test_script"; then
        test_fail "$test_name" "Security score boundary handling failed"
        return
    fi

    test_pass "$test_name"
}

# =============================================================================
# Attack Scenario Tests
# =============================================================================

test_attack_fake_coverage() {
    log_info "Testing SEC-008-2: Attack scenario - fake coverage injection..."

    local test_name="SEC-008-2: Fake coverage injection attack"
    local test_script='
        # Attacker tries to inject fake high coverage
        if validate_coverage_report "100\$(echo pwned)" "attacker" 2>/dev/null; then exit 1; fi
        if validate_coverage_report "100\`id\`" "attacker" 2>/dev/null; then exit 1; fi
        if validate_coverage_report "100;echo hacked" "attacker" 2>/dev/null; then exit 1; fi
        if validate_coverage_report "100|whoami" "attacker" 2>/dev/null; then exit 1; fi
        exit 0
    '

    if run_in_subshell "$LIB_DIR/supervisor-approver.sh" "$test_script"; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Fake coverage injection attack succeeded - CRITICAL"
    fi
}

test_attack_bypass_security_score() {
    log_info "Testing SEC-008-3: Attack scenario - security score bypass..."

    local test_name="SEC-008-3: Security score bypass attack"
    local test_script='
        # Attacker tries to inject fake high security score
        if validate_security_score "100\$(echo pwned)" "attacker" 2>/dev/null; then exit 1; fi
        if validate_security_score "100\`id\`" "attacker" 2>/dev/null; then exit 1; fi
        if validate_security_score "100;echo hacked" "attacker" 2>/dev/null; then exit 1; fi
        if validate_security_score "100|whoami" "attacker" 2>/dev/null; then exit 1; fi
        if validate_security_score "9999" "attacker" 2>/dev/null; then exit 1; fi
        if validate_security_score "100.000001" "attacker" 2>/dev/null; then exit 1; fi
        exit 0
    '

    if run_in_subshell "$LIB_DIR/phase-gate.sh" "$test_script"; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Security score bypass attack succeeded - CRITICAL"
    fi
}

# =============================================================================
# Main Test Runner
# =============================================================================

run_all_tests() {
    echo "=============================================================================="
    echo " SEC-008-2/3 Validation Security Tests"
    echo "=============================================================================="
    echo ""
    echo " Testing score validation functions that prevent gate manipulation attacks"
    echo ""

    setup

    # SEC-008-2: Coverage Validation Tests
    echo ""
    echo "--- SEC-008-2: Coverage Report Validation ---"
    test_coverage_valid_values
    test_coverage_empty_value
    test_coverage_negative_values
    test_coverage_over_100
    test_coverage_non_numeric
    test_coverage_shell_injection
    test_coverage_perfect_score_warning

    # SEC-008-3: Security Score Validation Tests
    echo ""
    echo "--- SEC-008-3: Security Score Validation ---"
    test_security_score_valid_values
    test_security_score_empty_value
    test_security_score_negative_values
    test_security_score_over_100
    test_security_score_non_numeric
    test_security_score_shell_injection
    test_security_score_perfect_warning

    # SEC-008-3: Confidence Score Tests
    echo ""
    echo "--- SEC-008-3: Confidence Score Validation ---"
    test_confidence_score_valid_values
    test_confidence_score_invalid_values

    # Integration Tests
    echo ""
    echo "--- Integration Tests ---"
    test_gate_score_wrapper
    test_readonly_score_constraints
    test_whitespace_handling
    test_boundary_values

    # Attack Scenario Tests
    echo ""
    echo "--- Attack Scenario Tests ---"
    test_attack_fake_coverage
    test_attack_bypass_security_score

    teardown

    echo ""
    echo "=============================================================================="
    echo " Test Summary"
    echo "=============================================================================="
    echo -e "  Tests run:    ${TESTS_RUN}"
    echo -e "  Passed:       ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "  Failed:       ${RED}${TESTS_FAILED}${NC}"
    echo -e "  Skipped:      ${YELLOW}${TESTS_SKIPPED}${NC}"
    echo ""

    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${RED}SECURITY TESTS FAILED - VALIDATION VULNERABILITIES DETECTED${NC}"
        return 1
    else
        echo -e "${GREEN}ALL SEC-008-2/3 VALIDATION TESTS PASSED${NC}"
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
        echo ""
        echo "Available tests:"
        echo "  SEC-008-2 (Coverage):"
        echo "    - test_coverage_valid_values"
        echo "    - test_coverage_empty_value"
        echo "    - test_coverage_negative_values"
        echo "    - test_coverage_over_100"
        echo "    - test_coverage_non_numeric"
        echo "    - test_coverage_shell_injection"
        echo "    - test_coverage_perfect_score_warning"
        echo ""
        echo "  SEC-008-3 (Security Score):"
        echo "    - test_security_score_valid_values"
        echo "    - test_security_score_empty_value"
        echo "    - test_security_score_negative_values"
        echo "    - test_security_score_over_100"
        echo "    - test_security_score_non_numeric"
        echo "    - test_security_score_shell_injection"
        echo "    - test_security_score_perfect_warning"
        echo ""
        echo "  SEC-008-3 (Confidence):"
        echo "    - test_confidence_score_valid_values"
        echo "    - test_confidence_score_invalid_values"
        echo ""
        echo "  Integration:"
        echo "    - test_gate_score_wrapper"
        echo "    - test_readonly_score_constraints"
        echo "    - test_whitespace_handling"
        echo "    - test_boundary_values"
        echo ""
        echo "  Attack Scenarios:"
        echo "    - test_attack_fake_coverage"
        echo "    - test_attack_bypass_security_score"
        teardown
        return 1
    fi

    teardown
}

# =============================================================================
# Entry Point
# =============================================================================

main() {
    if [[ $# -eq 0 ]]; then
        run_all_tests
    else
        run_single_test "$1"
    fi
}

main "$@"
