#!/bin/bash
# Tri-Agent Pre-Task Hook - Validate and track subagent tasks
# Called before Task tool execution

set -uo pipefail

LOG_DIR="${HOME}/.claude/logs"
TASK_DIR="${HOME}/.claude/tasks"

mkdir -p "$LOG_DIR" "$TASK_DIR"

# Parse tool input
# Safe input reading with timeout
TOOL_DATA=""
if read -t 1 -r line; then
    TOOL_DATA="$line"
    while read -t 0.1 -r line; do
        TOOL_DATA="${TOOL_DATA}${line}"
    done
fi
SESSION_ID=$(echo "$TOOL_DATA" | jq -r '.session_id // "unknown"')
TASK_PROMPT=$(echo "$TOOL_DATA" | jq -r '.tool_input.prompt // ""')
TASK_TYPE=$(echo "$TOOL_DATA" | jq -r '.tool_input.subagent_type // "general-purpose"')
TASK_DESC=$(echo "$TOOL_DATA" | jq -r '.tool_input.description // ""')
TIMESTAMP=$(date -Iseconds)

# Log task creation
echo "[${TIMESTAMP}] PRE_TASK type=${TASK_TYPE} desc='${TASK_DESC}'" >> "${LOG_DIR}/tasks.log"

# Track task for tri-agent coordination
TASK_FILE="${TASK_DIR}/task-$(date +%s%N).json"
cat > "$TASK_FILE" <<EOF
{
  "session_id": "${SESSION_ID}",
  "created_at": "${TIMESTAMP}",
  "type": "${TASK_TYPE}",
  "description": "${TASK_DESC}",
  "prompt_length": ${#TASK_PROMPT},
  "status": "started"
}
EOF

# Check if task prompt contains required verification instructions
HAS_VERIFICATION=false
if echo "$TASK_PROMPT" | grep -qiE 'verify|validate|check|confirm|PASS|FAIL'; then
    HAS_VERIFICATION=true
fi

# Log verification status
echo "[${TIMESTAMP}] TASK_VERIFICATION present=${HAS_VERIFICATION}" >> "${LOG_DIR}/tasks.log"

# Track concurrent agent count
AGENT_COUNT_FILE="${HOME}/.claude/sessions/active-agents.count"
if [[ -f "$AGENT_COUNT_FILE" ]]; then
    CURRENT=$(cat "$AGENT_COUNT_FILE")
    echo $((CURRENT + 1)) > "$AGENT_COUNT_FILE"
else
    echo "1" > "$AGENT_COUNT_FILE"
fi

# Cleanup old task files (keep last 100)
ls -t "${TASK_DIR}"/task-*.json 2>/dev/null | tail -n +101 | xargs -r rm -f

echo '{"continue": true}'
