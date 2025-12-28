#!/bin/bash
# Test runner for Claude SDLC Orchestrator
# Runs all BATS test suites

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Claude SDLC Orchestrator - Test Suite${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if bats is installed
if ! command -v bats &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} BATS is not installed."
    echo ""
    echo "Install BATS:"
    echo "  macOS:   brew install bats-core"
    echo "  Ubuntu:  sudo apt-get install bats"
    echo "  Manual:  git clone https://github.com/bats-core/bats-core.git && cd bats-core && ./install.sh /usr/local"
    echo ""
    exit 1
fi

# Check if shellcheck is installed (optional but recommended)
if ! command -v shellcheck &> /dev/null; then
    echo -e "${YELLOW}[WARN]${NC} shellcheck not installed - skipping linting"
else
    echo -e "${BLUE}[INFO]${NC} Running shellcheck on shell scripts..."
    shellcheck install.sh hooks/*.sh 2>&1 | head -50 || echo "  (shellcheck warnings found)"
    echo ""
fi

# Run all test suites
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

run_test_suite() {
    local test_file="$1"
    local test_name=$(basename "$test_file" .bats)

    echo -e "${BLUE}[RUN]${NC} $test_name"

    if bats "$test_file"; then
        echo -e "${GREEN}[PASS]${NC} $test_name"
        echo ""
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $test_name"
        echo ""
        return 1
    fi
}

# Run each test suite
TEST_FILES=(
    "tests/test_install.bats"
    "tests/test_pre_commit.bats"
    "tests/test_post_edit.bats"
    "tests/test_quality_gate.bats"
    "tests/test_hooks.bats"
)

for test_file in "${TEST_FILES[@]}"; do
    if [ -f "$test_file" ]; then
        if run_test_suite "$test_file"; then
            ((PASSED_TESTS++))
        else
            ((FAILED_TESTS++))
        fi
        ((TOTAL_TESTS++))
    else
        echo -e "${YELLOW}[SKIP]${NC} $test_file (not found)"
    fi
done

# Summary
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Test Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Total Test Suites: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
fi
