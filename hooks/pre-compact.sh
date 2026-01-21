#!/bin/bash
# Pre-Compact Hook - Snapshot context before compaction
# Called before context window is compacted

set -uo pipefail

LOG_DIR="${HOME}/.claude/logs"
SESSION_DIR="${HOME}/.claude/sessions"
SNAPSHOT_DIR="${SESSION_DIR}/snapshots"

mkdir -p "$LOG_DIR" "$SNAPSHOT_DIR"

# Parse event data
EVENT_DATA=$(cat)
SESSION_ID=$(echo "$EVENT_DATA" | jq -r '.session_id // "unknown"')
TRANSCRIPT_PATH=$(echo "$EVENT_DATA" | jq -r '.transcript_path // ""')
TIMESTAMP=$(date -Iseconds)

# Log compaction event
echo "[${TIMESTAMP}] PRE_COMPACT session_id=${SESSION_ID}" >> "${LOG_DIR}/compaction.log"

# Create context snapshot before compaction
SNAPSHOT_FILE="${SNAPSHOT_DIR}/snapshot-${SESSION_ID}-$(date +%Y%m%d_%H%M%S).json"

cat > "$SNAPSHOT_FILE" <<EOF
{
  "session_id": "${SESSION_ID}",
  "snapshot_at": "${TIMESTAMP}",
  "transcript_path": "${TRANSCRIPT_PATH}",
  "reason": "pre_compaction",
  "working_directory": "$(pwd)",
  "git_state": {
    "branch": "$(git branch --show-current 2>/dev/null || echo 'N/A')",
    "last_commit": "$(git log -1 --format='%h %s' 2>/dev/null || echo 'N/A')",
    "uncommitted": $(git status --short 2>/dev/null | wc -l)
  },
  "active_todos": $(cat "${HOME}/.claude/todos.json" 2>/dev/null || echo '[]')
}
EOF

# Update progress file with compaction note
PROGRESS_FILE="${SESSION_DIR}/claude-progress.txt"
if [[ -f "$PROGRESS_FILE" ]]; then
    echo "" >> "$PROGRESS_FILE"
    echo "### Context Compaction: ${TIMESTAMP}" >> "$PROGRESS_FILE"
    echo "Snapshot saved: ${SNAPSHOT_FILE}" >> "$PROGRESS_FILE"
fi

# Cleanup old snapshots (keep last 10)
ls -t "${SNAPSHOT_DIR}"/snapshot-*.json 2>/dev/null | tail -n +11 | xargs -r rm -f

# Also create a manual checkpoint before compaction (critical save point)
CHECKPOINT_NOW="${HOME}/.claude/hooks/checkpoint-now.sh"
if [[ -x "$CHECKPOINT_NOW" ]]; then
    "$CHECKPOINT_NOW" "pre_compaction" >/dev/null 2>&1 || true
fi

echo '{"continue": true}'
