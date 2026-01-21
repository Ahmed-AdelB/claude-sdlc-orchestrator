#!/bin/bash
# Tri-Agent User Prompt Hook - Parse routing tags and inject context
# Called on UserPromptSubmit events

set -uo pipefail

LOG_DIR="${HOME}/.claude/logs"
QUEUE_DIR="${HOME}/.claude/queue"

mkdir -p "$LOG_DIR" "$QUEUE_DIR"

# Parse event data
EVENT_DATA=$(cat)
SESSION_ID=$(echo "$EVENT_DATA" | jq -r '.session_id // "unknown"')
PROMPT=$(echo "$EVENT_DATA" | jq -r '.prompt // ""')
TIMESTAMP=$(date -Iseconds)

# Log user prompt
echo "[${TIMESTAMP}] USER_PROMPT session_id=${SESSION_ID} length=${#PROMPT}" >> "${LOG_DIR}/prompts.log"

# Detect routing tags (@claude, @gemini, @codex)
ROUTE_CLAUDE=false
ROUTE_GEMINI=false
ROUTE_CODEX=false

if echo "$PROMPT" | grep -qiE '@claude|/claude'; then
    ROUTE_CLAUDE=true
fi
if echo "$PROMPT" | grep -qiE '@gemini|/gemini'; then
    ROUTE_GEMINI=true
fi
if echo "$PROMPT" | grep -qiE '@codex|/codex'; then
    ROUTE_CODEX=true
fi

# If no explicit routing, default to tri-agent
if ! $ROUTE_CLAUDE && ! $ROUTE_GEMINI && ! $ROUTE_CODEX; then
    ROUTE_CLAUDE=true
fi

# Add routing metadata to queue
QUEUE_FILE="${QUEUE_DIR}/prompt-$(date +%s%N).json"
cat > "$QUEUE_FILE" <<EOF
{
  "session_id": "${SESSION_ID}",
  "timestamp": "${TIMESTAMP}",
  "prompt_length": ${#PROMPT},
  "routing": {
    "claude": ${ROUTE_CLAUDE},
    "gemini": ${ROUTE_GEMINI},
    "codex": ${ROUTE_CODEX}
  }
}
EOF

# Inject context reminder if prompt mentions specific phase
CONTEXT_INJECTION=""
if echo "$PROMPT" | grep -qiE 'ultrathink|think hard|architecture|security'; then
    CONTEXT_INJECTION="[System: Extended thinking mode activated - 32K tokens]"
fi

# Output: continue with optional context injection
if [[ -n "$CONTEXT_INJECTION" ]]; then
    echo "{\"continue\": true, \"context\": \"${CONTEXT_INJECTION}\"}"
else
    echo '{"continue": true}'
fi
