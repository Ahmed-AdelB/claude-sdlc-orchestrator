#!/bin/bash
#===============================================================================
# run_tests.sh - Test runner for delegate script tests
#===============================================================================
# This script runs all delegate tests using the available test frameworks.
#
# Usage:
#   ./run_tests.sh              # Run all tests
#   ./run_tests.sh --bats       # Run only BATS tests
#   ./run_tests.sh --pytest     # Run only pytest tests
#   ./run_tests.sh --standalone # Run only standalone shell tests
#   ./run_tests.sh --quick      # Run quick validation tests
#   ./run_tests.sh --v2         # Test v2 delegates (default)
#   ./run_tests.sh --autonomous # Test autonomous delegates
#
# Environment Variables:
#   TEST_BIN_DIR    - Override delegate bin directory
#   DEBUG           - Enable debug output (DEBUG=1)
#   VERBOSE         - Enable verbose output (VERBOSE=1)
#===============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_ROOT="${SCRIPT_DIR}/../.."

# Default to v2 bin directory
export TEST_BIN_DIR="${TEST_BIN_DIR:-${CLAUDE_ROOT}/v2/bin}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Test results
TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_SKIPPED=0

#===============================================================================
# Utility Functions
#===============================================================================

print_header() {
    echo ""
    echo -e "${BOLD}===============================================================================${RESET}"
    echo -e "${BOLD}$1${RESET}"
    echo -e "${BOLD}===============================================================================${RESET}"
}

print_section() {
    echo ""
    echo -e "${CYAN}--- $1 ---${RESET}"
}

check_dependency() {
    local cmd="$1"
    local name="${2:-$cmd}"

    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "  ${GREEN}[OK]${RESET} $name found: $(command -v "$cmd")"
        return 0
    else
        echo -e "  ${YELLOW}[MISSING]${RESET} $name not found"
        return 1
    fi
}

#===============================================================================
# Test Runners
#===============================================================================

run_bats_tests() {
    print_section "Running BATS Tests"

    if ! command -v bats >/dev/null 2>&1; then
        echo -e "  ${YELLOW}[SKIP]${RESET} BATS not installed (install with: npm install -g bats)"
        return 0
    fi

    local bats_file="${SCRIPT_DIR}/test_delegates.bats"
    if [[ ! -f "$bats_file" ]]; then
        echo -e "  ${YELLOW}[SKIP]${RESET} BATS test file not found: $bats_file"
        return 0
    fi

    echo "  Running: bats $bats_file"
    echo ""

    local exit_code=0
    if [[ "${VERBOSE:-0}" == "1" ]]; then
        bats --tap "$bats_file" || exit_code=$?
    else
        bats "$bats_file" || exit_code=$?
    fi

    return $exit_code
}

run_pytest_tests() {
    print_section "Running pytest Tests"

    if ! command -v pytest >/dev/null 2>&1; then
        if command -v python3 >/dev/null 2>&1; then
            # Try running with python3 -m pytest
            if ! python3 -c "import pytest" 2>/dev/null; then
                echo -e "  ${YELLOW}[SKIP]${RESET} pytest not installed (install with: pip install pytest)"
                return 0
            fi
        else
            echo -e "  ${YELLOW}[SKIP]${RESET} Python3 not available"
            return 0
        fi
    fi

    local pytest_file="${SCRIPT_DIR}/test_delegates.py"
    if [[ ! -f "$pytest_file" ]]; then
        echo -e "  ${YELLOW}[SKIP]${RESET} pytest file not found: $pytest_file"
        return 0
    fi

    echo "  Running: pytest $pytest_file"
    echo ""

    local pytest_args=("-v" "$pytest_file")
    if [[ "${VERBOSE:-0}" == "1" ]]; then
        pytest_args+=("-s")
    fi

    local exit_code=0
    if command -v pytest >/dev/null 2>&1; then
        pytest "${pytest_args[@]}" || exit_code=$?
    else
        python3 -m pytest "${pytest_args[@]}" || exit_code=$?
    fi

    return $exit_code
}

run_standalone_tests() {
    print_section "Running Standalone Shell Tests"

    local standalone_file="${SCRIPT_DIR}/test_delegates_standalone.sh"
    if [[ ! -f "$standalone_file" ]]; then
        echo -e "  ${YELLOW}[SKIP]${RESET} Standalone test file not found: $standalone_file"
        return 0
    fi

    echo "  Running: bash $standalone_file"
    echo ""

    local exit_code=0
    bash "$standalone_file" || exit_code=$?

    return $exit_code
}

run_quick_tests() {
    print_section "Running Quick Validation Tests"

    local exit_code=0
    local delegates=("claude-delegate" "codex-delegate" "gemini-delegate")

    for delegate in "${delegates[@]}"; do
        local script="${TEST_BIN_DIR}/${delegate}"

        echo -n "  Checking $delegate: "

        if [[ ! -f "$script" ]]; then
            echo -e "${YELLOW}NOT FOUND${RESET}"
            ((exit_code++))
            continue
        fi

        if [[ ! -x "$script" ]]; then
            echo -e "${YELLOW}NOT EXECUTABLE${RESET}"
            ((exit_code++))
            continue
        fi

        # Test --help
        if ! "$script" --help >/dev/null 2>&1; then
            echo -e "${RED}HELP FAILED${RESET}"
            ((exit_code++))
            continue
        fi

        # Test no prompt (should return JSON error)
        local output
        output=$("$script" 2>&1)
        if echo "$output" | grep -q '"status"'; then
            echo -e "${GREEN}OK${RESET}"
        else
            echo -e "${RED}NO JSON OUTPUT${RESET}"
            ((exit_code++))
        fi
    done

    return $exit_code
}

#===============================================================================
# Main
#===============================================================================

main() {
    local run_bats=true
    local run_pytest=true
    local run_standalone=true
    local run_quick=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --bats)
                run_pytest=false
                run_standalone=false
                shift
                ;;
            --pytest)
                run_bats=false
                run_standalone=false
                shift
                ;;
            --standalone)
                run_bats=false
                run_pytest=false
                shift
                ;;
            --quick)
                run_quick=true
                run_bats=false
                run_pytest=false
                run_standalone=false
                shift
                ;;
            --v2)
                export TEST_BIN_DIR="${CLAUDE_ROOT}/v2/bin"
                shift
                ;;
            --autonomous)
                export TEST_BIN_DIR="${CLAUDE_ROOT}/autonomous/bin"
                shift
                ;;
            --help|-h)
                cat << EOF
Usage: $0 [OPTIONS]

Options:
  --bats        Run only BATS tests
  --pytest      Run only pytest tests
  --standalone  Run only standalone shell tests
  --quick       Run quick validation tests only
  --v2          Test v2 delegates (default)
  --autonomous  Test autonomous delegates
  --help        Show this help

Environment Variables:
  TEST_BIN_DIR  Override delegate bin directory
  DEBUG=1       Enable debug output
  VERBOSE=1     Enable verbose output
EOF
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage"
                exit 1
                ;;
        esac
    done

    print_header "Tri-Agent Delegate Script Test Suite"
    echo ""
    echo "Testing delegates in: ${TEST_BIN_DIR}"
    echo ""

    # Check dependencies
    print_section "Checking Dependencies"
    check_dependency "jq" "jq (JSON processor)"
    check_dependency "bash" "bash"

    local overall_exit=0

    # Run selected tests
    if [[ "$run_quick" == "true" ]]; then
        run_quick_tests || overall_exit=$?
    else
        if [[ "$run_standalone" == "true" ]]; then
            run_standalone_tests || overall_exit=$?
        fi

        if [[ "$run_bats" == "true" ]]; then
            run_bats_tests || overall_exit=$?
        fi

        if [[ "$run_pytest" == "true" ]]; then
            run_pytest_tests || overall_exit=$?
        fi
    fi

    # Print final summary
    print_header "Test Summary"
    if [[ $overall_exit -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${RESET}"
    else
        echo -e "${RED}Some tests failed (exit code: $overall_exit)${RESET}"
    fi

    return $overall_exit
}

# Run main
main "$@"
