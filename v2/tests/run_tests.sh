#!/bin/bash
#===============================================================================
# run_tests.sh - Main test runner for tri-agent system
#===============================================================================
# Usage:
#   ./tests/run_tests.sh              Run all tests
#   ./tests/run_tests.sh unit         Run only unit tests
#   ./tests/run_tests.sh integration  Run only integration tests
#   ./tests/run_tests.sh -v           Verbose output
#   ./tests/run_tests.sh --help       Show help
#===============================================================================

set -euo pipefail

# Script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
UNIT_DIR="${SCRIPT_DIR}/unit"
INTEGRATION_DIR="${SCRIPT_DIR}/integration"
E2E_DIR="${SCRIPT_DIR}/e2e"
SECURITY_DIR="${SCRIPT_DIR}/security"
FUZZ_DIR="${SCRIPT_DIR}/fuzz"
PROPERTY_DIR="${SCRIPT_DIR}/property"
STRESS_DIR="${SCRIPT_DIR}/stress"
VALIDATION_DIR="${SCRIPT_DIR}/validation"
CHAOS_DIR="${SCRIPT_DIR}/chaos"

# Colors
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' RESET=''
fi

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
VERBOSE=false
TEST_TYPE="all"

#===============================================================================
# Utility Functions
#===============================================================================

log_pass() {
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}[PASS]${RESET} $1"
}

log_fail() {
    ((TESTS_FAILED++))
    echo -e "  ${RED}[FAIL]${RESET} $1"
    if [[ "$VERBOSE" == "true" && -n "${2:-}" ]]; then
        echo -e "         ${RED}Error: $2${RESET}"
    fi
}

log_skip() {
    ((TESTS_SKIPPED++))
    echo -e "  ${YELLOW}[SKIP]${RESET} $1"
}

log_section() {
    echo ""
    echo -e "${BOLD}${BLUE}=== $1 ===${RESET}"
}

show_help() {
    cat <<EOF
${BOLD}run_tests.sh${RESET} - Test runner for tri-agent system

${BOLD}USAGE:${RESET}
    ./tests/run_tests.sh [OPTIONS] [TEST_TYPE]

${BOLD}TEST TYPES:${RESET}
    all          Run all tests (default)
    unit         Run only unit tests
    integration  Run only integration tests
    e2e          Run end-to-end tests
    security     Run security tests
    fuzz         Run fuzzing tests
    property     Run property-based tests
    stress       Run stress/concurrency tests
    validation   Run deep feature validation tests
    chaos        Run chaos engineering tests
    advanced     Run fuzz + property + stress tests
    deep         Run validation + chaos tests

${BOLD}OPTIONS:${RESET}
    -v, --verbose    Show detailed error messages
    -h, --help       Show this help message

${BOLD}EXAMPLES:${RESET}
    ./tests/run_tests.sh              Run all tests
    ./tests/run_tests.sh unit         Run only unit tests
    ./tests/run_tests.sh -v           Verbose output
    ./tests/run_tests.sh integration  Run integration tests

${BOLD}EXIT CODES:${RESET}
    0   All tests passed
    1   Some tests failed
EOF
}

#===============================================================================
# Parse Arguments
#===============================================================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        unit|integration|e2e|security|fuzz|property|stress|validation|chaos|advanced|deep|all)
            TEST_TYPE="$1"
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${RESET}" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
    esac
done

#===============================================================================
# Test Runner
#===============================================================================

run_test_file() {
    local test_file="$1"
    local test_name
    test_name=$(basename "$test_file" .sh)

    if [[ ! -x "$test_file" ]]; then
        chmod +x "$test_file"
    fi

    echo -e "\n${CYAN}Running: ${test_name}${RESET}"

    if "$test_file"; then
        return 0
    else
        return 1
    fi
}

run_unit_tests() {
    log_section "Unit Tests"

    local unit_tests=("$UNIT_DIR"/test_*.sh)

    if [[ ! -e "${unit_tests[0]}" ]]; then
        echo "  No unit tests found in ${UNIT_DIR}"
        return 0
    fi

    for test_file in "${unit_tests[@]}"; do
        if [[ -f "$test_file" ]]; then
            run_test_file "$test_file" || true
        fi
    done
}

run_integration_tests() {
    log_section "Integration Tests"

    local integration_tests=("$INTEGRATION_DIR"/test_*.sh)

    if [[ ! -e "${integration_tests[0]}" ]]; then
        echo "  No integration tests found in ${INTEGRATION_DIR}"
        return 0
    fi

    for test_file in "${integration_tests[@]}"; do
        if [[ -f "$test_file" ]]; then
            run_test_file "$test_file" || true
        fi
    done
}

run_e2e_tests() {
    log_section "End-to-End Tests"

    local e2e_tests=("$E2E_DIR"/test_*.sh)

    if [[ ! -e "${e2e_tests[0]}" ]]; then
        echo "  No e2e tests found in ${E2E_DIR}"
        return 0
    fi

    for test_file in "${e2e_tests[@]}"; do
        if [[ -f "$test_file" ]]; then
            run_test_file "$test_file" || true
        fi
    done
}

run_security_tests() {
    log_section "Security Tests"

    local security_tests=("$SECURITY_DIR"/test_*.sh)

    if [[ ! -e "${security_tests[0]}" ]]; then
        echo "  No security tests found in ${SECURITY_DIR}"
        return 0
    fi

    for test_file in "${security_tests[@]}"; do
        if [[ -f "$test_file" ]]; then
            run_test_file "$test_file" || true
        fi
    done
}

run_fuzz_tests() {
    log_section "Fuzzing Tests"

    local fuzz_tests=("$FUZZ_DIR"/test_*.sh)

    if [[ ! -e "${fuzz_tests[0]}" ]]; then
        echo "  No fuzz tests found in ${FUZZ_DIR}"
        return 0
    fi

    for test_file in "${fuzz_tests[@]}"; do
        if [[ -f "$test_file" ]]; then
            run_test_file "$test_file" || true
        fi
    done
}

run_property_tests() {
    log_section "Property-Based Tests"

    local property_tests=("$PROPERTY_DIR"/test_*.sh)

    if [[ ! -e "${property_tests[0]}" ]]; then
        echo "  No property tests found in ${PROPERTY_DIR}"
        return 0
    fi

    for test_file in "${property_tests[@]}"; do
        if [[ -f "$test_file" ]]; then
            run_test_file "$test_file" || true
        fi
    done
}

run_stress_tests() {
    log_section "Stress/Concurrency Tests"

    local stress_tests=("$STRESS_DIR"/test_*.sh)

    if [[ ! -e "${stress_tests[0]}" ]]; then
        echo "  No stress tests found in ${STRESS_DIR}"
        return 0
    fi

    for test_file in "${stress_tests[@]}"; do
        if [[ -f "$test_file" ]]; then
            run_test_file "$test_file" || true
        fi
    done
}

run_advanced_tests() {
    run_fuzz_tests
    run_property_tests
    run_stress_tests
}

run_validation_tests() {
    log_section "Deep Feature Validation Tests"

    local validation_tests=("$VALIDATION_DIR"/test_*.sh)

    if [[ ! -e "${validation_tests[0]}" ]]; then
        echo "  No validation tests found in ${VALIDATION_DIR}"
        return 0
    fi

    for test_file in "${validation_tests[@]}"; do
        if [[ -f "$test_file" ]]; then
            run_test_file "$test_file" || true
        fi
    done
}

run_chaos_tests() {
    log_section "Chaos Engineering Tests"

    local chaos_tests=("$CHAOS_DIR"/test_*.sh)

    if [[ ! -e "${chaos_tests[0]}" ]]; then
        echo "  No chaos tests found in ${CHAOS_DIR}"
        return 0
    fi

    for test_file in "${chaos_tests[@]}"; do
        if [[ -f "$test_file" ]]; then
            run_test_file "$test_file" || true
        fi
    done
}

run_deep_tests() {
    run_validation_tests
    run_chaos_tests
}

print_summary() {
    echo ""
    echo -e "${BOLD}${BLUE}============================================================${RESET}"
    echo -e "${BOLD}                     TEST SUMMARY                              ${RESET}"
    echo -e "${BOLD}${BLUE}============================================================${RESET}"
    echo ""
    echo -e "  ${GREEN}Passed:${RESET}  $TESTS_PASSED"
    echo -e "  ${RED}Failed:${RESET}  $TESTS_FAILED"
    echo -e "  ${YELLOW}Skipped:${RESET} $TESTS_SKIPPED"
    echo -e "  ${BOLD}Total:${RESET}   $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"
    echo ""

    local total=$((TESTS_PASSED + TESTS_FAILED))
    if [[ $total -gt 0 ]]; then
        local pass_rate=$((TESTS_PASSED * 100 / total))
        echo -e "  Pass rate: ${BOLD}${pass_rate}%${RESET}"
    fi

    echo ""
    echo -e "${BOLD}${BLUE}============================================================${RESET}"
}

#===============================================================================
# Main
#===============================================================================

main() {
    echo ""
    echo -e "${BOLD}${CYAN}Tri-Agent Test Suite${RESET}"
    echo -e "Project: ${PROJECT_ROOT}"
    echo -e "Running: ${TEST_TYPE} tests"

    # Export for test files
    export PROJECT_ROOT
    export TESTS_PASSED TESTS_FAILED TESTS_SKIPPED
    export VERBOSE
    export -f log_pass log_fail log_skip

    case "$TEST_TYPE" in
        unit)
            run_unit_tests
            ;;
        integration)
            run_integration_tests
            ;;
        e2e)
            run_e2e_tests
            ;;
        security)
            run_security_tests
            ;;
        fuzz)
            run_fuzz_tests
            ;;
        property)
            run_property_tests
            ;;
        stress)
            run_stress_tests
            ;;
        advanced)
            run_advanced_tests
            ;;
        validation)
            run_validation_tests
            ;;
        chaos)
            run_chaos_tests
            ;;
        deep)
            run_deep_tests
            ;;
        all)
            run_unit_tests
            run_integration_tests
            run_e2e_tests
            run_security_tests
            run_advanced_tests
            run_deep_tests
            ;;
    esac

    print_summary

    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

main
