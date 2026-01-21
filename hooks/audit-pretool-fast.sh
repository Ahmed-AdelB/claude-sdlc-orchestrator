#!/bin/bash
# Optimized Audit Pre-Tool Hook - Performance-focused version
# Reduces subprocess spawning and removes cleanup from hot path
# Expected execution: <80ms (vs 212ms original)

set -uo pipefail

# Quick bypass check without full parsing
TOOL_DATA=""
if read -t 1 -r line; then
    TOOL_DATA="$line"
    while read -t 0.1 -r line; do
        TOOL_DATA="${TOOL_DATA}${line}"
    done
fi

# Fast bypass check using string matching (no jq)
if [[ "$TOOL_DATA" == *'"permission_mode":"bypassPermissions"'* ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Configuration
LOG_DIR="${HOME}/.claude/logs"
AUDIT_DIR="${LOG_DIR}/audit"

# Single directory check
[[ -d "$AUDIT_DIR" ]] || mkdir -p "$AUDIT_DIR"

# Single date call for all timestamps
eval $(date +'TS_ISO=%FT%T%z AUDIT_DATE=%Y%m%d')
AUDIT_FILE="${AUDIT_DIR}/audit-${AUDIT_DATE}.jsonl"

# Single jq call to extract all fields (major optimization)
if [[ -n "$TOOL_DATA" ]]; then
    read -r SESSION_ID TOOL_NAME TOOL_INPUT < <(
        echo "$TOOL_DATA" | jq -r '
            [
                (.session_id // "unknown"),
                (.tool_name // "unknown"),
                ((.tool_input // {}) | @json)
            ] | @tsv
        ' 2>/dev/null
    ) || {
        SESSION_ID="unknown"
        TOOL_NAME="unknown" 
        TOOL_INPUT="{}"
    }
else
    SESSION_ID="unknown"
    TOOL_NAME="unknown"
    TOOL_INPUT="{}"
fi

# Append audit entry (use >> directly, flock only if high contention expected)
echo "{\"timestamp\":\"${TS_ISO}\",\"phase\":\"pre\",\"session_id\":\"${SESSION_ID}\",\"tool\":\"${TOOL_NAME}\",\"input\":${TOOL_INPUT}}" >> "$AUDIT_FILE"

# Tool stats update - simplified (no lock for non-critical stats)
STATS_FILE="${LOG_DIR}/tool-stats.json"
if [[ -f "$STATS_FILE" ]]; then
    # Background update to not block
    (
        CURRENT=$(jq -r ".\"${TOOL_NAME}\" // 0" "$STATS_FILE" 2>/dev/null || echo 0)
        jq ".\"${TOOL_NAME}\" = $((CURRENT + 1))" "$STATS_FILE" > "${STATS_FILE}.tmp" 2>/dev/null && \
        mv "${STATS_FILE}.tmp" "$STATS_FILE"
    ) &
else
    echo "{\"${TOOL_NAME}\": 1}" > "$STATS_FILE"
fi

# NOTE: Log rotation moved to cron job (~/.claude/scripts/hook-cleanup.sh)
# Do NOT run find -delete here - it adds 30-50ms per call

echo '{"continue": true}'
