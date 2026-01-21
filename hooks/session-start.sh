#!/bin/bash
# Session Start Hook - Initialize 24hr session tracking
# Called when Claude Code session begins

set -uo pipefail

LOG_DIR="${HOME}/.claude/logs"
SESSION_DIR="${HOME}/.claude/sessions"
CHECKPOINT_DIR="${SESSION_DIR}/checkpoints"
HOOKS_DIR="${HOME}/.claude/hooks"
HEALTH_CHECK="${HOOKS_DIR}/health-check.sh"

mkdir -p "$LOG_DIR" "$SESSION_DIR" "$CHECKPOINT_DIR"

# Parse session info from stdin
SESSION_DATA=$(cat)
SESSION_ID=$(echo "$SESSION_DATA" | jq -r '.session_id // "unknown"')
TIMESTAMP=$(date -Iseconds)

# Run health check on session start (do not block or fail startup)
if [ -x "$HEALTH_CHECK" ]; then
    "$HEALTH_CHECK" >/dev/null 2>&1 || true
fi

# Create session log
SESSION_LOG="${SESSION_DIR}/session-${SESSION_ID}.log"
cat > "$SESSION_LOG" <<EOF
# Session Started: $TIMESTAMP
# Session ID: $SESSION_ID
# Working Directory: $(pwd)
# User: $(whoami)
# Host: $(hostname)
EOF

# Log session start
echo "[${TIMESTAMP}] SESSION_START session_id=${SESSION_ID}" >> "${LOG_DIR}/sessions.log"

# Initialize progress tracking
PROGRESS_FILE="${SESSION_DIR}/claude-progress.txt"
(
    flock -x 200
    cat > "$PROGRESS_FILE" <<EOF
# Session Progress Log
## Last Updated: ${TIMESTAMP}
## Session ID: ${SESSION_ID}

### Session Info:
- Started: ${TIMESTAMP}
- Working Directory: $(pwd)
- Git Branch: $(git branch --show-current 2>/dev/null || echo "N/A")

### Completed Tasks:
(none yet)

### Current State:
- Phase: INITIALIZING
- Active Agents: 0

### Next Actions:
(awaiting first prompt)
EOF
) 200>"${PROGRESS_FILE}.lock"

# Output: allow session to continue
echo '{"continue": true}'
