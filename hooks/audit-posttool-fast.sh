#!/bin/bash
# Optimized Audit Post-Tool Hook - Performance-focused version
# Expected execution: <120ms (vs 319ms original)

set -uo pipefail

# Read input with timeout
TOOL_DATA=""
if read -t 1 -r line; then
    TOOL_DATA="$line"
    while read -t 0.1 -r line; do
        TOOL_DATA="${TOOL_DATA}${line}"
    done
fi

# Handle empty input
[[ -z "$TOOL_DATA" ]] && { echo '{"continue": true}'; exit 0; }

# Configuration
LOG_DIR="${HOME}/.claude/logs"
AUDIT_DIR="${LOG_DIR}/audit"

# Single directory check
[[ -d "$AUDIT_DIR" ]] || mkdir -p "$AUDIT_DIR"

# Single date call
eval $(date +'TS_ISO=%FT%T%z AUDIT_DATE=%Y%m%d')
AUDIT_FILE="${AUDIT_DIR}/audit-${AUDIT_DATE}.jsonl"

# Single jq call to extract all fields plus build audit entry
AUDIT_ENTRY=$(echo "$TOOL_DATA" | jq -c '
{
    timestamp: (now | strftime("%Y-%m-%dT%H:%M:%S%z") // "'"$TS_ISO"'"),
    phase: "post",
    session_id: (.session_id // "unknown"),
    tool: (.tool_name // "unknown"),
    success: (.success // true),
    result_preview: ((.tool_response // {}) | tostring | .[0:500])
}
' 2>/dev/null)

# Fallback if jq fails
if [[ -z "$AUDIT_ENTRY" ]]; then
    SESSION_ID=$(echo "$TOOL_DATA" | jq -r '.session_id // "unknown"' 2>/dev/null) || SESSION_ID="unknown"
    TOOL_NAME=$(echo "$TOOL_DATA" | jq -r '.tool_name // "unknown"' 2>/dev/null) || TOOL_NAME="unknown"
    AUDIT_ENTRY="{\"timestamp\":\"${TS_ISO}\",\"phase\":\"post\",\"session_id\":\"${SESSION_ID}\",\"tool\":\"${TOOL_NAME}\",\"success\":true,\"result_preview\":\"...\"}"
fi

# Append audit entry (direct append, no lock for single writer)
echo "$AUDIT_ENTRY" >> "$AUDIT_FILE"

# Extract fields for error tracking (reuse from audit entry if possible)
SUCCESS=$(echo "$AUDIT_ENTRY" | jq -r '.success // true' 2>/dev/null) || SUCCESS="true"

# Track errors (async)
if [[ "$SUCCESS" == "false" ]]; then
    (
        SESSION_ID=$(echo "$AUDIT_ENTRY" | jq -r '.session_id // "unknown"' 2>/dev/null) || SESSION_ID="unknown"
        TOOL_NAME=$(echo "$AUDIT_ENTRY" | jq -r '.tool // "unknown"' 2>/dev/null) || TOOL_NAME="unknown"
        echo "[${TS_ISO}] TOOL_ERROR tool=${TOOL_NAME} session=${SESSION_ID}" >> "${LOG_DIR}/errors.log"
    ) &
fi

# Periodic checkpoint in background (fire-and-forget)
CHECKPOINT_SCRIPT="${HOME}/.claude/hooks/periodic-checkpoint.sh"
if [[ -x "$CHECKPOINT_SCRIPT" ]]; then
    SESSION_ID=$(echo "$AUDIT_ENTRY" | jq -r '.session_id // "unknown"' 2>/dev/null) || SESSION_ID="unknown"
    ("$CHECKPOINT_SCRIPT" "$TOOL_DATA" "$SESSION_ID" >/dev/null 2>&1 &)
fi

echo '{"continue": true}'
