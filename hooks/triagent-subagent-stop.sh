#!/bin/bash
# Tri-Agent Subagent Stop Hook - Capture subagent summaries for coordination
# Called when a subagent (Task tool) completes

set -uo pipefail

LOG_DIR="${HOME}/.claude/logs"
HANDOFF_DIR="${HOME}/.claude/handoffs"

mkdir -p "$LOG_DIR" "$HANDOFF_DIR"

# Parse event data
EVENT_DATA=$(cat)
SESSION_ID=$(echo "$EVENT_DATA" | jq -r '.session_id // "unknown"')
AGENT_ID=$(echo "$EVENT_DATA" | jq -r '.agent_id // "unknown"')
AGENT_TYPE=$(echo "$EVENT_DATA" | jq -r '.agent_type // "unknown"')
SUMMARY=$(echo "$EVENT_DATA" | jq -r '.summary // ""')
TIMESTAMP=$(date -Iseconds)

# Log subagent completion
echo "[${TIMESTAMP}] SUBAGENT_STOP agent_id=${AGENT_ID} type=${AGENT_TYPE}" >> "${LOG_DIR}/subagents.log"

# Create handoff record for orchestrator
HANDOFF_FILE="${HANDOFF_DIR}/handoff-${AGENT_ID}-$(date +%s).json"
cat > "$HANDOFF_FILE" <<EOF
{
  "session_id": "${SESSION_ID}",
  "agent_id": "${AGENT_ID}",
  "agent_type": "${AGENT_TYPE}",
  "completed_at": "${TIMESTAMP}",
  "summary_length": ${#SUMMARY},
  "summary_preview": "$(echo "$SUMMARY" | head -c 500 | tr '\n' ' ')"
}
EOF

# Track agent counts for tri-agent verification
AGENT_COUNT_FILE="${HOME}/.claude/sessions/agent-count.json"
if [[ -f "$AGENT_COUNT_FILE" ]]; then
    CURRENT_COUNT=$(jq -r '.total // 0' "$AGENT_COUNT_FILE")
    NEW_COUNT=$((CURRENT_COUNT + 1))
    jq ".total = $NEW_COUNT | .last_agent = \"$AGENT_ID\" | .last_type = \"$AGENT_TYPE\"" "$AGENT_COUNT_FILE" > "${AGENT_COUNT_FILE}.tmp"
    mv "${AGENT_COUNT_FILE}.tmp" "$AGENT_COUNT_FILE"
else
    echo '{"total": 1, "last_agent": "'"$AGENT_ID"'", "last_type": "'"$AGENT_TYPE"'"}' > "$AGENT_COUNT_FILE"
fi

# Cleanup old handoffs (keep last 50)
ls -t "${HANDOFF_DIR}"/handoff-*.json 2>/dev/null | tail -n +51 | xargs -r rm -f

echo '{"continue": true}'
