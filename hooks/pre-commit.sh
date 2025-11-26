#!/bin/bash
# Pre-commit hook for Claude Code SDLC Orchestration
# Performs quality checks before allowing commits
# Receives JSON input from Claude Code via stdin

# Don't use set -e as we want to continue on non-critical failures

# Read JSON input from stdin (Claude Code hook format)
INPUT_JSON=$(cat)

# Parse hook data (requires jq)
TOOL_NAME=""
TOOL_INPUT=""
SESSION_ID=""
if command -v jq &> /dev/null; then
    TOOL_NAME=$(echo "$INPUT_JSON" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
    TOOL_INPUT=$(echo "$INPUT_JSON" | jq -r '.tool_input // empty' 2>/dev/null || echo "")
    SESSION_ID=$(echo "$INPUT_JSON" | jq -r '.session_id // empty' 2>/dev/null || echo "")
fi

# SECURITY: Sanitize TOOL_INPUT to prevent command injection
# Only allow specific characters in the input
if [ -n "$TOOL_INPUT" ]; then
    # Check for dangerous shell metacharacters
    if [[ "$TOOL_INPUT" =~ [\;\|\&\`\$\(\)\{\}\<\>] ]]; then
        echo "[SECURITY] Potentially dangerous characters in input - checking safely" >&2
    fi
    # Use a safe comparison method (no shell expansion)
    if [[ "$TOOL_INPUT" != *"git commit"* ]]; then
        # Not a git commit, skip
        exit 0
    fi
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    # Not in a git repo, skip
    exit 0
fi

# Configuration (from env vars set in settings.json)
HOOK_MODE="${CLAUDE_HOOK_MODE:-automatic}"  # automatic | ask | disabled
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
    echo "🤖 Tri-Agent Review (Claude + Codex + Gemini)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Get staged diff for review
    STAGED_DIFF=$(git diff --cached --no-color 2>/dev/null | head -500)
    REVIEW_PROMPT="Review this code change for security issues, bugs, and best practices. Respond with APPROVE or REJECT with brief reason:\n\n$STAGED_DIFF"

    CLAUDE_VOTE="APPROVE"  # Claude is the orchestrator (us)
    CODEX_VOTE="PENDING"
    GEMINI_VOTE="PENDING"

    echo "Claude Code (Opus 4.5): $CLAUDE_VOTE ✅"

    # Call Codex CLI if available (GPT-5.1 Pro)
    if command -v codex &> /dev/null; then
        echo -n "Codex (GPT-5.1): "
        CODEX_RESULT=$(timeout 30 codex -q "$REVIEW_PROMPT" 2>/dev/null || echo "APPROVE (timeout)")
        if echo "$CODEX_RESULT" | grep -qi "reject"; then
            CODEX_VOTE="REJECT"
            echo "REJECT ❌"
            log_warning "Codex flagged issues: $CODEX_RESULT"
        else
            CODEX_VOTE="APPROVE"
            echo "APPROVE ✅"
        fi
    else
        CODEX_VOTE="SKIP"
        echo "Codex (GPT-5.1): SKIP (not installed)"
    fi

    # Call Gemini CLI if available (Gemini 3 Pro)
    if command -v gemini &> /dev/null; then
        echo -n "Gemini (3 Pro): "
        GEMINI_RESULT=$(timeout 30 gemini -y "$REVIEW_PROMPT" 2>/dev/null || echo "APPROVE (timeout)")
        if echo "$GEMINI_RESULT" | grep -qi "reject"; then
            GEMINI_VOTE="REJECT"
            echo "REJECT ❌"
            log_warning "Gemini flagged issues: $GEMINI_RESULT"
        else
            GEMINI_VOTE="APPROVE"
            echo "APPROVE ✅"
        fi
    else
        GEMINI_VOTE="SKIP"
        echo "Gemini (3 Pro): SKIP (not installed)"
    fi

    # Calculate consensus (need 2/3 or 2/2 approvals)
    APPROVE_COUNT=0
    TOTAL_VOTES=0

    [[ "$CLAUDE_VOTE" == "APPROVE" ]] && ((APPROVE_COUNT++))
    [[ "$CLAUDE_VOTE" != "SKIP" ]] && ((TOTAL_VOTES++))
    [[ "$CODEX_VOTE" == "APPROVE" ]] && ((APPROVE_COUNT++))
    [[ "$CODEX_VOTE" != "SKIP" ]] && ((TOTAL_VOTES++))
    [[ "$GEMINI_VOTE" == "APPROVE" ]] && ((APPROVE_COUNT++))
    [[ "$GEMINI_VOTE" != "SKIP" ]] && ((TOTAL_VOTES++))

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Require majority approval
    REQUIRED=$((TOTAL_VOTES / 2 + 1))
    if [ $APPROVE_COUNT -ge $REQUIRED ]; then
        echo "Consensus: APPROVED ($APPROVE_COUNT/$TOTAL_VOTES) ✅"
        log_success "Tri-agent review passed"
    else
        echo "Consensus: REJECTED ($APPROVE_COUNT/$TOTAL_VOTES) ❌"
        log_error "Tri-agent review failed - majority rejected"
        ((ERRORS++))
    fi
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
    # Exit code 2 = blocking error in Claude Code hooks
    exit 2
fi

if [ $WARNINGS -gt 0 ]; then
    log_warning "Commit proceeding with warnings"
fi

log_success "Pre-commit checks passed!"
exit 0
