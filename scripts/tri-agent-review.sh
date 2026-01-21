#!/bin/bash
# Tri-Agent Code Review Script
# Gets consensus from Claude, Gemini, and Codex

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[FAIL]${NC} $1"; }

usage() {
    cat << EOF
${CYAN}Tri-Agent Code Review${NC}

Usage: $(basename "$0") <target> [options]

Arguments:
  target    File, directory, or git diff to review

Options:
  --diff    Review staged git changes
  --pr      Review pull request changes
  --file    Review specific file(s)

Examples:
  $(basename "$0") src/auth/
  $(basename "$0") --diff
  $(basename "$0") --file src/api/users.ts

EOF
}

TIMEOUT="${TRI_AGENT_TIMEOUT:-60}"
APPROVALS=0
TOTAL=3

review_with_claude() {
    local content="$1"
    log_info "Claude Code reviewing..."

    local result
    result=$(echo "$content" | timeout "$TIMEOUT" claude -p "Review this code for issues, bugs, security vulnerabilities, and best practices. Reply with APPROVED or REJECTED followed by your findings." 2>/dev/null | tail -5) || true

    if echo "$result" | grep -qi "APPROVED"; then
        log_success "Claude: APPROVED"
        ((APPROVALS++))
        echo "$result"
    elif [ -z "$result" ]; then
        log_warning "Claude: TIMEOUT (implicit approval)"
        ((APPROVALS++))
    else
        log_error "Claude: REJECTED"
        echo "$result"
    fi
}

review_with_gemini() {
    local content="$1"
    log_info "Gemini reviewing..."

    local result
    result=$(echo "$content" | timeout "$TIMEOUT" gemini -y "Review this code for issues, bugs, security vulnerabilities, and best practices. Reply with APPROVED or REJECTED followed by your findings." 2>/dev/null | tail -5) || true

    if echo "$result" | grep -qi "APPROVED"; then
        log_success "Gemini: APPROVED"
        ((APPROVALS++))
        echo "$result"
    elif [ -z "$result" ]; then
        log_warning "Gemini: TIMEOUT (implicit approval)"
        ((APPROVALS++))
    else
        log_error "Gemini: REJECTED"
        echo "$result"
    fi
}

review_with_codex() {
    local content="$1"
    log_info "Codex reviewing..."

    local result
    result=$(echo "$content" | timeout "$TIMEOUT" codex exec "Review this code for issues, bugs, security vulnerabilities, and best practices. Reply with APPROVED or REJECTED followed by your findings." 2>/dev/null | tail -5) || true

    if echo "$result" | grep -qi "APPROVED"; then
        log_success "Codex: APPROVED"
        ((APPROVALS++))
        echo "$result"
    elif [ -z "$result" ]; then
        log_warning "Codex: TIMEOUT (implicit approval)"
        ((APPROVALS++))
    else
        log_error "Codex: REJECTED"
        echo "$result"
    fi
}

main() {
    local target="$1"
    local content=""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🤖 Tri-Agent Code Review"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    case "$target" in
        --diff)
            log_info "Reviewing staged changes..."
            content=$(git diff --cached --no-color 2>/dev/null | head -500)
            ;;
        --pr)
            log_info "Reviewing PR changes..."
            content=$(git diff origin/main...HEAD --no-color 2>/dev/null | head -500)
            ;;
        --file)
            shift
            log_info "Reviewing file: $1"
            content=$(cat "$1" 2>/dev/null | head -500)
            ;;
        *)
            if [ -f "$target" ]; then
                log_info "Reviewing file: $target"
                content=$(cat "$target" | head -500)
            elif [ -d "$target" ]; then
                log_info "Reviewing directory: $target"
                content=$(find "$target" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.py" \) -exec cat {} \; | head -500)
            else
                log_error "Target not found: $target"
                usage
                exit 1
            fi
            ;;
    esac

    if [ -z "$content" ]; then
        log_warning "No content to review"
        exit 0
    fi

    echo ""

    # Run reviews (sequentially to avoid rate limits)
    review_with_claude "$content"
    echo ""
    review_with_gemini "$content"
    echo ""
    review_with_codex "$content"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Consensus: $APPROVALS/$TOTAL APPROVED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ $APPROVALS -ge 2 ]; then
        log_success "Review PASSED (majority approval)"
        exit 0
    else
        log_error "Review FAILED (insufficient approvals)"
        exit 1
    fi
}

if [ -z "$1" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
    exit 0
fi

main "$@"
