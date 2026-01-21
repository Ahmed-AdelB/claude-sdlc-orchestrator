#!/bin/bash
# Session End Hook - Finalize session and create checkpoint
# Called when Claude Code session ends

set -uo pipefail

LOG_DIR="${HOME}/.claude/logs"
SESSION_DIR="${HOME}/.claude/sessions"
CHECKPOINT_DIR="${SESSION_DIR}/checkpoints"

mkdir -p "$LOG_DIR" "$CHECKPOINT_DIR"

# Parse session info
SESSION_DATA=$(cat)
SESSION_ID=$(echo "$SESSION_DATA" | jq -r '.session_id // "unknown"')
TRANSCRIPT_PATH=$(echo "$SESSION_DATA" | jq -r '.transcript_path // ""')
TIMESTAMP=$(date -Iseconds)

# Log session end
echo "[${TIMESTAMP}] SESSION_END session_id=${SESSION_ID}" >> "${LOG_DIR}/sessions.log"

# Create final checkpoint
CHECKPOINT_FILE="${CHECKPOINT_DIR}/checkpoint-${SESSION_ID}-$(date +%Y%m%d_%H%M%S).json"
cat > "$CHECKPOINT_FILE" <<EOF
{
  "session_id": "${SESSION_ID}",
  "ended_at": "${TIMESTAMP}",
  "transcript_path": "${TRANSCRIPT_PATH}",
  "working_directory": "$(pwd)",
  "git_branch": "$(git branch --show-current 2>/dev/null || echo 'N/A')",
  "git_status": "$(git status --short 2>/dev/null | head -10 | tr '\n' ';')",
  "uncommitted_changes": $(git status --short 2>/dev/null | wc -l)
}
EOF

# Update progress file
PROGRESS_FILE="${SESSION_DIR}/claude-progress.txt"
(
    flock -x 200
    if [[ -f "$PROGRESS_FILE" ]]; then
        sed -i "s/Last Updated:.*/Last Updated: ${TIMESTAMP}/" "$PROGRESS_FILE"
        echo "" >> "$PROGRESS_FILE"
        echo "### Session Ended: ${TIMESTAMP}" >> "$PROGRESS_FILE"
    fi
) 200>"${PROGRESS_FILE}.lock"

# Cleanup old checkpoints (keep last 20)
ls -t "${CHECKPOINT_DIR}"/checkpoint-*.json 2>/dev/null | tail -n +21 | xargs -r rm -f

echo '{"continue": true}'
