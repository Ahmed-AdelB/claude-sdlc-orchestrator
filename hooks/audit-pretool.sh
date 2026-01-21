#!/bin/bash
# Audit Pre-Tool Hook - Log tool usage before execution
# Called before tool execution for audit trail

set -uo pipefail

LOG_DIR="${HOME}/.claude/logs"
AUDIT_DIR="${LOG_DIR}/audit"

mkdir -p "$AUDIT_DIR"

# Parse tool data
# Safe input reading with timeout
TOOL_DATA=""
if read -t 1 -r line; then
    TOOL_DATA="$line"
    while read -t 0.1 -r line; do
        TOOL_DATA="${TOOL_DATA}${line}"
    done
fi
SESSION_ID=$(echo "$TOOL_DATA" | jq -r '.session_id // "unknown"')
TOOL_NAME=$(echo "$TOOL_DATA" | jq -r '.tool_name // "unknown"')
TOOL_INPUT=$(echo "$TOOL_DATA" | jq -c '.tool_input // {}')
TIMESTAMP=$(date -Iseconds)

# Create audit log entry (append-only JSONL)
AUDIT_FILE="${AUDIT_DIR}/audit-$(date +%Y%m%d).jsonl"

# Use flock to prevent concurrent write corruption
(
    flock -x 200
    cat >> "$AUDIT_FILE" <<EOF
{"timestamp":"${TIMESTAMP}","phase":"pre","session_id":"${SESSION_ID}","tool":"${TOOL_NAME}","input":${TOOL_INPUT}}
EOF
) 200>"${AUDIT_FILE}.lock"

# Track tool usage counts
STATS_FILE="${LOG_DIR}/tool-stats.json"

init_stats() {
    echo "{\"${TOOL_NAME}\": 1}" > "$STATS_FILE"
}

(
    flock -x 200
    if [[ -f "$STATS_FILE" ]] && [[ -s "$STATS_FILE" ]]; then
        # Increment tool counter
        # Handle potentially corrupt/empty JSON file
        CURRENT=$(jq -r ".\"${TOOL_NAME}\" // 0" "$STATS_FILE" 2>/dev/null || echo "FAIL")
        
        if [[ "$CURRENT" == "FAIL" ]]; then
             init_stats
        else
             if ! jq ".\"${TOOL_NAME}\" = $((CURRENT + 1))" "$STATS_FILE" > "${STATS_FILE}.tmp" 2>/dev/null; then
                 init_stats
             else
                 mv "${STATS_FILE}.tmp" "$STATS_FILE"
             fi
        fi
    else
        init_stats
    fi
) 200>"${STATS_FILE}.lock"

# Rotate audit logs (keep 7 days)
find "$AUDIT_DIR" -name "audit-*.jsonl" -mtime +7 -delete 2>/dev/null || true

echo '{"continue": true}'
