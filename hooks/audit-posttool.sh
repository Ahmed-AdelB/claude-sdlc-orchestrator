#!/bin/bash
# Audit Post-Tool Hook - Log tool results after execution
# Called after tool execution for audit trail
# Fixed: Handle empty input, escape JSON properly

# Don't use set -e to allow graceful error handling
set -uo pipefail

LOG_DIR="${HOME}/.claude/logs"
AUDIT_DIR="${LOG_DIR}/audit"

mkdir -p "$AUDIT_DIR"

# Read input with timeout to handle empty stdin
TOOL_DATA=""
if read -t 1 -r line; then
    TOOL_DATA="$line"
    while read -t 0.1 -r line; do
        TOOL_DATA="${TOOL_DATA}${line}"
    done
fi

# Handle empty input gracefully
if [[ -z "$TOOL_DATA" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Parse tool data with fallbacks
SESSION_ID=$(echo "$TOOL_DATA" | jq -r '.session_id // "unknown"' 2>/dev/null) || SESSION_ID="unknown"
TOOL_NAME=$(echo "$TOOL_DATA" | jq -r '.tool_name // "unknown"' 2>/dev/null) || TOOL_NAME="unknown"
SUCCESS=$(echo "$TOOL_DATA" | jq -r '.success // true' 2>/dev/null) || SUCCESS="true"
TIMESTAMP=$(date -Iseconds)

# Get result preview and escape it properly for JSON
TOOL_RESULT=$(echo "$TOOL_DATA" | jq -r '.tool_response // {}' 2>/dev/null | head -c 500) || TOOL_RESULT="{}"
# Escape special characters for JSON embedding
TOOL_RESULT_ESCAPED=$(echo "$TOOL_RESULT" | jq -Rs '.' 2>/dev/null | sed 's/^"//;s/"$//') || TOOL_RESULT_ESCAPED="..."

# Create audit log entry (append-only JSONL)
AUDIT_FILE="${AUDIT_DIR}/audit-$(date +%Y%m%d).jsonl"

# Build JSON using jq for proper escaping
AUDIT_ENTRY=$(jq -n \
    --arg ts "$TIMESTAMP" \
    --arg phase "post" \
    --arg sid "$SESSION_ID" \
    --arg tool "$TOOL_NAME" \
    --argjson success "$SUCCESS" \
    --arg preview "$TOOL_RESULT_ESCAPED" \
    '{timestamp: $ts, phase: $phase, session_id: $sid, tool: $tool, success: $success, result_preview: $preview}' 2>/dev/null)

# Fallback if jq fails
if [[ -z "$AUDIT_ENTRY" ]]; then
    AUDIT_ENTRY="{\"timestamp\":\"${TIMESTAMP}\",\"phase\":\"post\",\"session_id\":\"${SESSION_ID}\",\"tool\":\"${TOOL_NAME}\",\"success\":true,\"result_preview\":\"...\"}"
fi

# Use flock to prevent concurrent write corruption
(
    flock -x 200
    echo "$AUDIT_ENTRY" >> "$AUDIT_FILE"
) 200>"${AUDIT_FILE}.lock"

# Track errors
if [[ "$SUCCESS" == "false" ]]; then
    ERROR_LOG="${LOG_DIR}/errors.log"
    echo "[${TIMESTAMP}] TOOL_ERROR tool=${TOOL_NAME} session=${SESSION_ID}" >> "$ERROR_LOG"
fi

# Trigger periodic checkpoint check (runs in background to not block)
CHECKPOINT_SCRIPT="${HOME}/.claude/hooks/periodic-checkpoint.sh"
if [[ -x "$CHECKPOINT_SCRIPT" ]]; then
    # Run checkpoint check in background, suppress output
    ("$CHECKPOINT_SCRIPT" "$TOOL_DATA" "$SESSION_ID" >/dev/null 2>&1 &)
fi

echo '{"continue": true}'
