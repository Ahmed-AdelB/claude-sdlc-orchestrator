#!/bin/bash
# Post-edit hook for Claude Code SDLC Orchestration
# Performs formatting and validation after file edits
# Receives JSON input from Claude Code via stdin

# Don't use set -e as we want to continue on formatting failures

# Read JSON input from stdin (Claude Code hook format)
INPUT_JSON=$(cat)

# Parse hook data (requires jq)
TOOL_NAME=""
FILE_PATH=""
if command -v jq &> /dev/null; then
    TOOL_NAME=$(echo "$INPUT_JSON" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
    # For Edit/Write tools, file_path is in tool_input
    FILE_PATH=$(echo "$INPUT_JSON" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")
fi

# Configuration (from env vars set in settings.json)
HOOK_MODE="${CLAUDE_HOOK_MODE:-automatic}"  # automatic | ask | disabled
AUTO_FORMAT="${AUTO_FORMAT:-true}"
AUTO_LINT_FIX="${AUTO_LINT_FIX:-true}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() { echo -e "${BLUE}[POST-EDIT]${NC} $1"; }
log_success() { echo -e "${GREEN}[POST-EDIT]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[POST-EDIT]${NC} $1"; }

# Check if hook is disabled
if [ "$HOOK_MODE" = "disabled" ]; then
    exit 0
fi

# Only process Edit and Write tools
if [[ "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "Write" ]]; then
    exit 0
fi

# Skip if no file path
if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
    exit 0
fi

# Get file extension
EXT="${FILE_PATH##*.}"

# Auto-format based on file type
if [ "$AUTO_FORMAT" = "true" ]; then
    case "$EXT" in
        js|jsx|ts|tsx|json|md|css|scss|html)
            if command -v prettier &> /dev/null; then
                log_info "Formatting $FILE_PATH with Prettier..."
                prettier --write "$FILE_PATH" 2>/dev/null || true
            elif command -v npx &> /dev/null; then
                log_info "Formatting $FILE_PATH with Prettier (npx)..."
                npx prettier --write "$FILE_PATH" 2>/dev/null || true
            fi
            ;;
        py)
            if command -v black &> /dev/null; then
                log_info "Formatting $FILE_PATH with Black..."
                black "$FILE_PATH" 2>/dev/null || true
            elif command -v ruff &> /dev/null; then
                log_info "Formatting $FILE_PATH with Ruff..."
                ruff format "$FILE_PATH" 2>/dev/null || true
            fi
            ;;
        go)
            if command -v gofmt &> /dev/null; then
                log_info "Formatting $FILE_PATH with gofmt..."
                gofmt -w "$FILE_PATH" 2>/dev/null || true
            fi
            ;;
        rs)
            if command -v rustfmt &> /dev/null; then
                log_info "Formatting $FILE_PATH with rustfmt..."
                rustfmt "$FILE_PATH" 2>/dev/null || true
            fi
            ;;
    esac
fi

# Auto-fix lint issues
if [ "$AUTO_LINT_FIX" = "true" ]; then
    case "$EXT" in
        js|jsx|ts|tsx)
            if command -v eslint &> /dev/null || command -v npx &> /dev/null; then
                log_info "Auto-fixing lint issues in $FILE_PATH..."
                npx eslint --fix "$FILE_PATH" 2>/dev/null || true
            fi
            ;;
        py)
            if command -v ruff &> /dev/null; then
                log_info "Auto-fixing lint issues in $FILE_PATH..."
                ruff check --fix "$FILE_PATH" 2>/dev/null || true
            fi
            ;;
    esac
fi

# Validate file syntax
case "$EXT" in
    json)
        if command -v jq &> /dev/null; then
            if ! jq empty "$FILE_PATH" 2>/dev/null; then
                log_warning "Invalid JSON syntax in $FILE_PATH"
            fi
        fi
        ;;
    yaml|yml)
        if command -v yq &> /dev/null; then
            if ! yq eval '.' "$FILE_PATH" > /dev/null 2>&1; then
                log_warning "Invalid YAML syntax in $FILE_PATH"
            fi
        fi
        ;;
    py)
        if command -v python3 &> /dev/null; then
            if ! python3 -m py_compile "$FILE_PATH" 2>/dev/null; then
                log_warning "Python syntax error in $FILE_PATH"
            fi
        fi
        ;;
esac

# Check for common issues
if grep -qE "TODO|FIXME|XXX|HACK" "$FILE_PATH" 2>/dev/null; then
    log_info "Found TODO/FIXME comments in $FILE_PATH"
fi

# Track file change for session memory
if [ -n "$CLAUDE_SESSION_ID" ]; then
    echo "$FILE_PATH" >> "/tmp/claude-session-$CLAUDE_SESSION_ID-files.txt"
fi

log_success "Post-edit processing complete for $FILE_PATH"
exit 0
