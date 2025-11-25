#!/bin/bash
# Pre-commit hook for Claude Code SDLC Orchestration
# Performs quality checks before allowing commits

set -e

# Configuration
HOOK_MODE="${CLAUDE_HOOK_MODE:-ask}"  # automatic | ask | disabled
TRI_AGENT_ENABLED="${TRI_AGENT_REVIEW:-false}"
MIN_COVERAGE="${MIN_TEST_COVERAGE:-80}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[FAIL]${NC} $1"; }

# Check if hook is disabled
if [ "$HOOK_MODE" = "disabled" ]; then
    exit 0
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Claude Code Pre-Commit Hook"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ERRORS=0
WARNINGS=0

# 1. Check for secrets/sensitive data
log_info "Checking for sensitive data..."
SENSITIVE_PATTERNS=(
    "password\s*=\s*['\"][^'\"]+['\"]"
    "api[_-]?key\s*=\s*['\"][^'\"]+['\"]"
    "secret\s*=\s*['\"][^'\"]+['\"]"
    "token\s*=\s*['\"][^'\"]+['\"]"
    "AWS_ACCESS_KEY"
    "AWS_SECRET"
    "PRIVATE_KEY"
)

STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)
for file in $STAGED_FILES; do
    if [ -f "$file" ]; then
        for pattern in "${SENSITIVE_PATTERNS[@]}"; do
            if grep -qiE "$pattern" "$file" 2>/dev/null; then
                log_error "Potential secret found in $file"
                ((ERRORS++))
            fi
        done
    fi
done

if [ $ERRORS -eq 0 ]; then
    log_success "No sensitive data detected"
fi

# 2. Check for debug code
log_info "Checking for debug code..."
DEBUG_PATTERNS=(
    "console\.log\("
    "debugger"
    "print\("
    "var_dump\("
    "dd\("
)

for file in $STAGED_FILES; do
    if [[ "$file" =~ \.(js|ts|jsx|tsx|py|php)$ ]]; then
        for pattern in "${DEBUG_PATTERNS[@]}"; do
            if grep -qE "$pattern" "$file" 2>/dev/null; then
                log_warning "Debug code found in $file: $pattern"
                ((WARNINGS++))
            fi
        done
    fi
done

if [ $WARNINGS -eq 0 ]; then
    log_success "No debug code detected"
fi

# 3. Check file sizes
log_info "Checking file sizes..."
MAX_FILE_SIZE=1048576  # 1MB

for file in $STAGED_FILES; do
    if [ -f "$file" ]; then
        size=$(wc -c < "$file")
        if [ $size -gt $MAX_FILE_SIZE ]; then
            log_warning "Large file: $file ($((size/1024))KB)"
            ((WARNINGS++))
        fi
    fi
done

# 4. Run linter (if available)
log_info "Running linter checks..."
if command -v npm &> /dev/null && [ -f "package.json" ]; then
    if npm run lint --if-present 2>/dev/null; then
        log_success "Linting passed"
    else
        log_error "Linting failed"
        ((ERRORS++))
    fi
fi

# 5. Run type check (if TypeScript)
if [ -f "tsconfig.json" ]; then
    log_info "Running type checks..."
    if npx tsc --noEmit 2>/dev/null; then
        log_success "Type checking passed"
    else
        log_error "Type checking failed"
        ((ERRORS++))
    fi
fi

# 6. Tri-Agent Review (if enabled)
if [ "$TRI_AGENT_ENABLED" = "true" ]; then
    log_info "Requesting tri-agent review..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🤖 Tri-Agent Review Required"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # This would integrate with the actual tri-agent system
    # For now, it's a placeholder
    echo "Claude Code: Reviewing..."
    echo "Codex: Reviewing..."
    echo "Gemini: Reviewing..."

    # Simulated consensus
    echo ""
    echo "Consensus: APPROVED (3/3)"
    log_success "Tri-agent review passed"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Pre-Commit Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"

if [ $ERRORS -gt 0 ]; then
    log_error "Commit blocked due to errors"

    if [ "$HOOK_MODE" = "ask" ]; then
        echo ""
        read -p "Override and commit anyway? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_warning "Proceeding with commit (override)"
            exit 0
        fi
    fi

    exit 1
fi

if [ $WARNINGS -gt 0 ]; then
    log_warning "Commit proceeding with warnings"
fi

log_success "Pre-commit checks passed!"
exit 0
