#!/bin/bash
# Quality gate hook for Claude Code SDLC Orchestration
# Enforces quality standards before task completion
# Receives JSON input from Claude Code via stdin (Stop hook)

# Don't use set -e as we want to report all issues, not fail on first

# Read JSON input from stdin (Claude Code hook format)
INPUT_JSON=$(cat)

# Parse hook data (requires jq) - optional for Stop hooks
if command -v jq &> /dev/null; then
    SESSION_ID=$(echo "$INPUT_JSON" | jq -r '.session_id // empty' 2>/dev/null || echo "")
fi

# Configuration (from env vars set in settings.json)
HOOK_MODE="${CLAUDE_HOOK_MODE:-automatic}"  # automatic | ask | disabled
MIN_COVERAGE="${MIN_TEST_COVERAGE:-80}"
REQUIRE_TESTS="${REQUIRE_TESTS:-true}"
REQUIRE_DOCS="${REQUIRE_DOCS:-false}"
MAX_COMPLEXITY="${MAX_COMPLEXITY:-10}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Functions
log_info() { echo -e "${BLUE}[QUALITY]${NC} $1"; }
log_success() { echo -e "${GREEN}[QUALITY]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[QUALITY]${NC} $1"; }
log_error() { echo -e "${RED}[QUALITY]${NC} $1"; }
log_header() { echo -e "${CYAN}$1${NC}"; }

# Check if hook is disabled
if [ "$HOOK_MODE" = "disabled" ]; then
    exit 0
fi

echo ""
log_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_header "🏁 Quality Gate Check"
log_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

PASSED=0
FAILED=0
WARNINGS=0

# 1. Check test coverage
log_info "Checking test coverage..."

coverage_check() {
    local coverage=0

    # Try different coverage tools
    if [ -f "coverage/coverage-summary.json" ]; then
        coverage=$(jq '.total.lines.pct' coverage/coverage-summary.json 2>/dev/null || echo 0)
    elif [ -f "coverage.xml" ]; then
        coverage=$(grep -oP 'line-rate="\K[^"]+' coverage.xml 2>/dev/null | head -1 || echo 0)
        coverage=$(echo "$coverage * 100" | bc 2>/dev/null || echo 0)
    elif [ -f ".coverage" ] && command -v coverage &> /dev/null; then
        coverage=$(coverage report | grep TOTAL | awk '{print $4}' | tr -d '%' 2>/dev/null || echo 0)
    fi

    echo "$coverage"
}

COVERAGE=$(coverage_check)
if [ -n "$COVERAGE" ] && [ "$COVERAGE" != "0" ]; then
    if (( $(echo "$COVERAGE >= $MIN_COVERAGE" | bc -l 2>/dev/null || echo 0) )); then
        log_success "Test coverage: ${COVERAGE}% (minimum: ${MIN_COVERAGE}%)"
        ((PASSED++))
    else
        log_error "Test coverage: ${COVERAGE}% (minimum: ${MIN_COVERAGE}%)"
        ((FAILED++))
    fi
else
    if [ "$REQUIRE_TESTS" = "true" ]; then
        log_warning "Could not determine test coverage"
        ((WARNINGS++))
    fi
fi

# 2. Run tests
log_info "Running tests..."

run_tests() {
    if [ -f "package.json" ] && grep -q '"test"' package.json; then
        npm test 2>/dev/null
        return $?
    elif [ -f "pytest.ini" ] || [ -f "setup.py" ] || [ -f "pyproject.toml" ]; then
        pytest 2>/dev/null
        return $?
    elif [ -f "Cargo.toml" ]; then
        cargo test 2>/dev/null
        return $?
    elif [ -f "go.mod" ]; then
        go test ./... 2>/dev/null
        return $?
    fi
    return 0
}

if run_tests; then
    log_success "All tests passing"
    ((PASSED++))
else
    log_error "Tests failed"
    ((FAILED++))
fi

# 3. Check for linting errors
log_info "Checking for linting errors..."

lint_check() {
    local errors=0

    if [ -f "package.json" ] && grep -q '"lint"' package.json; then
        npm run lint 2>/dev/null || errors=1
    elif command -v ruff &> /dev/null && [ -f "pyproject.toml" ]; then
        ruff check . 2>/dev/null || errors=1
    fi

    return $errors
}

if lint_check; then
    log_success "No linting errors"
    ((PASSED++))
else
    log_error "Linting errors found"
    ((FAILED++))
fi

# 4. Check for type errors
log_info "Checking for type errors..."

type_check() {
    if [ -f "tsconfig.json" ]; then
        npx tsc --noEmit 2>/dev/null
        return $?
    elif command -v mypy &> /dev/null && [ -f "pyproject.toml" ]; then
        mypy . 2>/dev/null
        return $?
    fi
    return 0
}

if type_check; then
    log_success "No type errors"
    ((PASSED++))
else
    log_error "Type errors found"
    ((FAILED++))
fi

# 5. Check for security vulnerabilities
log_info "Checking for security vulnerabilities..."

security_check() {
    local vulns=0

    if [ -f "package-lock.json" ]; then
        # npm audit returns non-zero if vulnerabilities found
        npm audit --audit-level=high 2>/dev/null || vulns=1
    elif [ -f "requirements.txt" ] || [ -f "Pipfile.lock" ]; then
        if command -v safety &> /dev/null; then
            safety check 2>/dev/null || vulns=1
        fi
    fi

    return $vulns
}

if security_check; then
    log_success "No high/critical vulnerabilities"
    ((PASSED++))
else
    log_warning "Security vulnerabilities detected"
    ((WARNINGS++))
fi

# 6. Check documentation (if required)
if [ "$REQUIRE_DOCS" = "true" ]; then
    log_info "Checking documentation..."

    if [ -f "README.md" ]; then
        log_success "README.md present"
        ((PASSED++))
    else
        log_warning "README.md missing"
        ((WARNINGS++))
    fi
fi

# 7. Check for uncommitted changes
log_info "Checking git status..."

if git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null; then
    log_success "Working directory clean"
    ((PASSED++))
else
    log_warning "Uncommitted changes detected"
    ((WARNINGS++))
fi

# Summary
echo ""
log_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_header "📊 Quality Gate Summary"
log_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  ✅ Passed:   $PASSED"
echo "  ❌ Failed:   $FAILED"
echo "  ⚠️  Warnings: $WARNINGS"
echo ""

if [ $FAILED -gt 0 ]; then
    log_error "Quality gate FAILED"
    echo ""
    echo "Please fix the issues above before proceeding."
    # Note: Exit code 1 is non-blocking, 2 would block
    # Quality gate failures are reported but don't block
    exit 1
fi

if [ $WARNINGS -gt 0 ]; then
    log_warning "Quality gate PASSED with warnings"
else
    log_success "Quality gate PASSED"
fi

echo ""
exit 0
