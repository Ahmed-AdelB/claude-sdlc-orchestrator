#!/bin/bash
# =============================================================================
# run-daemon-tests.sh
# Runner script for tri-agent daemon startup tests
# =============================================================================
#
# Runs both the shell-based comprehensive tests and YAML test cases
# for daemon startup validation.
#
# Usage:
#   ./run-daemon-tests.sh [OPTIONS]
#
# Options:
#   --shell-only      Run only shell-based tests
#   --yaml-only       Run only YAML test cases
#   --verbose         Enable verbose output
#   --quick           Run only critical tests
#   --help            Show this help message
#
# Author: Ahmed Adel Bakr Alderai
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_TESTS="$SCRIPT_DIR/test-daemon-startup.sh"
YAML_CASES_DIR="$SCRIPT_DIR/cases"
TRI_AGENT_RUNNER="/home/aadel/.claude/tests/tri-agent/runners/test-runner.sh"
RESULTS_DIR="$SCRIPT_DIR/results"
LOG_FILE="$SCRIPT_DIR/daemon-tests-$(date +%Y%m%d_%H%M%S).log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Options
RUN_SHELL=true
RUN_YAML=true
VERBOSE=false
QUICK=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --shell-only)
            RUN_SHELL=true
            RUN_YAML=false
            shift
            ;;
        --yaml-only)
            RUN_SHELL=false
            RUN_YAML=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --quick|-q)
            QUICK=true
            shift
            ;;
        --help|-h)
            echo "Usage: $(basename "$0") [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --shell-only      Run only shell-based tests"
            echo "  --yaml-only       Run only YAML test cases"
            echo "  --verbose, -v     Enable verbose output"
            echo "  --quick, -q       Run only critical tests"
            echo "  --help, -h        Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Create results directory
mkdir -p "$RESULTS_DIR"

# Header
echo ""
echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}  Tri-Agent Daemon Test Suite Runner${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo ""
echo "Date: $(date)"
echo "Log: $LOG_FILE"
echo ""

# Summary variables
TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_SKIPPED=0

# Run shell-based tests
if [[ "$RUN_SHELL" == "true" ]]; then
    echo -e "${BLUE}--- Running Shell-Based Tests ---${NC}"
    echo ""

    if [[ -x "$SHELL_TESTS" ]]; then
        if [[ "$VERBOSE" == "true" ]]; then
            if "$SHELL_TESTS" --verbose 2>&1 | tee -a "$LOG_FILE"; then
                echo -e "${GREEN}Shell tests passed${NC}"
            else
                echo -e "${RED}Shell tests failed${NC}"
                ((TOTAL_FAILED++)) || true
            fi
        else
            if "$SHELL_TESTS" 2>&1 | tee -a "$LOG_FILE"; then
                echo -e "${GREEN}Shell tests passed${NC}"
            else
                echo -e "${RED}Shell tests failed${NC}"
                ((TOTAL_FAILED++)) || true
            fi
        fi
    else
        echo -e "${YELLOW}Shell test script not found or not executable: $SHELL_TESTS${NC}"
        chmod +x "$SHELL_TESTS" 2>/dev/null || true
        if [[ -x "$SHELL_TESTS" ]]; then
            "$SHELL_TESTS" 2>&1 | tee -a "$LOG_FILE" || ((TOTAL_FAILED++)) || true
        else
            ((TOTAL_SKIPPED++)) || true
        fi
    fi

    echo ""
fi

# Run YAML test cases
if [[ "$RUN_YAML" == "true" ]]; then
    echo -e "${BLUE}--- Running YAML Test Cases ---${NC}"
    echo ""

    if [[ -d "$YAML_CASES_DIR" ]]; then
        yaml_tests=($(find "$YAML_CASES_DIR" -name "TAT-D*.yaml" | sort))

        if [[ ${#yaml_tests[@]} -eq 0 ]]; then
            echo -e "${YELLOW}No YAML test cases found in $YAML_CASES_DIR${NC}"
        else
            echo "Found ${#yaml_tests[@]} YAML test cases"
            echo ""

            for test_file in "${yaml_tests[@]}"; do
                test_name=$(basename "$test_file" .yaml)
                test_id=$(grep "^id:" "$test_file" | head -1 | sed 's/id: *"\?\([^"]*\)"\?/\1/')
                test_title=$(grep "^name:" "$test_file" | head -1 | sed 's/name: *"\?\([^"]*\)"\?/\1/')

                # Skip non-critical tests in quick mode
                if [[ "$QUICK" == "true" ]]; then
                    priority=$(grep "^priority:" "$test_file" | head -1 | sed 's/priority: *"\?\([^"]*\)"\?/\1/')
                    if [[ "$priority" != "critical" ]]; then
                        echo -e "${YELLOW}[SKIP]${NC} $test_id: $test_title (not critical)"
                        ((TOTAL_SKIPPED++)) || true
                        continue
                    fi
                fi

                echo -e "${BLUE}[TEST]${NC} $test_id: $test_title"

                # Run the test case if tri-agent runner exists
                if [[ -x "$TRI_AGENT_RUNNER" ]]; then
                    # Create a temporary directory for this test
                    test_temp_dir=$(mktemp -d)

                    # Use the test runner (simplified execution)
                    if bash -c "
                        source '$test_file' 2>/dev/null || true
                        # Execute setup commands
                        pkill -f 'tri-agent-daemon' 2>/dev/null || true
                        sleep 1
                        # Run the test
                        cd /home/aadel/.claude
                        timeout 120 bash -c \"\$(grep -A 100 'args:' '$test_file' | grep -A 50 '- |' | tail -n +2 | head -50 | sed 's/^        //')\" 2>&1
                    " >> "$LOG_FILE" 2>&1; then
                        echo -e "${GREEN}[PASS]${NC} $test_id"
                        ((TOTAL_PASSED++)) || true
                    else
                        echo -e "${RED}[FAIL]${NC} $test_id (see log for details)"
                        ((TOTAL_FAILED++)) || true
                    fi

                    rm -rf "$test_temp_dir"
                else
                    echo -e "${YELLOW}[SKIP]${NC} $test_id (tri-agent runner not available)"
                    ((TOTAL_SKIPPED++)) || true
                fi
            done
        fi
    else
        echo -e "${YELLOW}YAML cases directory not found: $YAML_CASES_DIR${NC}"
    fi

    echo ""
fi

# Final cleanup
echo -e "${BLUE}--- Cleanup ---${NC}"
pkill -f 'tri-agent-daemon' 2>/dev/null || true
rm -f /home/aadel/.claude/tri-agent-daemon.pid 2>/dev/null || true

# Summary
echo ""
echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}  Test Summary${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo -e "Passed:  ${GREEN}$TOTAL_PASSED${NC}"
echo -e "Failed:  ${RED}$TOTAL_FAILED${NC}"
echo -e "Skipped: ${YELLOW}$TOTAL_SKIPPED${NC}"
echo ""
echo "Log file: $LOG_FILE"
echo ""

# Exit code
if [[ $TOTAL_FAILED -gt 0 ]]; then
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All executed tests passed!${NC}"
    exit 0
fi
