#!/bin/bash
# Manual Checkpoint - Save progress immediately
# Usage: ~/.claude/hooks/checkpoint-now.sh [reason]
# Creates a comprehensive checkpoint of current session state

set -uo pipefail

SESSION_DIR="${HOME}/.claude/sessions"
CHECKPOINT_DIR="${SESSION_DIR}/checkpoints"
LOG_DIR="${HOME}/.claude/logs"
PROGRESS_FILE="${SESSION_DIR}/claude-progress.txt"

mkdir -p "$CHECKPOINT_DIR" "$LOG_DIR"

# Get reason from argument or default
REASON="${1:-manual_checkpoint}"
TIMESTAMP=$(date -Iseconds)
EPOCH_NOW=$(date +%s)

# Try to get session ID from progress file
SESSION_ID="manual"
if [[ -f "$PROGRESS_FILE" ]]; then
    SESSION_ID=$(grep "Session ID:" "$PROGRESS_FILE" | head -1 | sed 's/.*Session ID: //' || echo "manual")
fi

checkpoint_file="${CHECKPOINT_DIR}/checkpoint-${SESSION_ID}-$(date +%Y%m%d_%H%M%S).json"

echo "Creating checkpoint: $checkpoint_file"

# Get recent audit entries
recent_tools="[]"
audit_file="${LOG_DIR}/audit/audit-$(date +%Y%m%d).jsonl"
if [[ -f "$audit_file" ]]; then
    recent_tools=$(tail -50 "$audit_file" | jq -s '[.[] | {tool: .tool, timestamp: .timestamp, success: .success}]' 2>/dev/null || echo "[]")
fi

# Get current todos
todos="[]"
if [[ -f "${HOME}/.claude/todos.json" ]]; then
    todos=$(cat "${HOME}/.claude/todos.json" 2>/dev/null || echo "[]")
fi

# Get git state
git_branch=$(git branch --show-current 2>/dev/null || echo "N/A")
git_last_commit=$(git log -1 --format='%h %s' 2>/dev/null || echo "N/A")
uncommitted_count=$(git status --short 2>/dev/null | wc -l)
git_status=$(git status --short 2>/dev/null | tr '\n' ';' || echo "")
git_diff_stat=$(git diff --stat 2>/dev/null | tail -5 | tr '\n' ';' || echo "")

# Get recent files modified (last 30 minutes)
recent_files=$(find . -type f -mmin -30 \
    -not -path "./.git/*" \
    -not -path "./node_modules/*" \
    -not -path "./venv/*" \
    -not -path "./__pycache__/*" \
    -not -path "./.mypy_cache/*" \
    -not -path "./.pytest_cache/*" \
    2>/dev/null | head -30 | tr '\n' ',' || echo "")

# Get progress file content
progress_content=""
if [[ -f "$PROGRESS_FILE" ]]; then
    progress_content=$(cat "$PROGRESS_FILE" | jq -Rs '.' 2>/dev/null | sed 's/^"//;s/"$//' || echo "")
fi

# Build comprehensive checkpoint
cat > "$checkpoint_file" <<EOF
{
  "type": "manual_checkpoint",
  "reason": "${REASON}",
  "session_id": "${SESSION_ID}",
  "created_at": "${TIMESTAMP}",
  "epoch": ${EPOCH_NOW},
  "working_directory": "$(pwd)",
  "user": "$(whoami)",
  "hostname": "$(hostname)",
  "git_state": {
    "branch": "${git_branch}",
    "last_commit": "${git_last_commit}",
    "uncommitted_count": ${uncommitted_count},
    "status": "${git_status}",
    "diff_stat": "${git_diff_stat}"
  },
  "recent_files_modified": "${recent_files}",
  "recent_tools_count": $(echo "$recent_tools" | jq 'length' 2>/dev/null || echo 0),
  "recent_tools": ${recent_tools},
  "todos": ${todos},
  "progress_summary": "${progress_content:0:2000}"
}
EOF

# Update progress file
(
    flock -x 200
    if [[ -f "$PROGRESS_FILE" ]]; then
        sed -i "s/^## Last Updated:.*/## Last Updated: ${TIMESTAMP}/" "$PROGRESS_FILE"
        echo "" >> "$PROGRESS_FILE"
        echo "### Manual Checkpoint: ${TIMESTAMP}" >> "$PROGRESS_FILE"
        echo "- Reason: ${REASON}" >> "$PROGRESS_FILE"
        echo "- File: ${checkpoint_file}" >> "$PROGRESS_FILE"
    fi
) 200>"${PROGRESS_FILE}.lock"

# Log checkpoint
echo "[${TIMESTAMP}] MANUAL_CHECKPOINT session=${SESSION_ID} reason=${REASON} file=${checkpoint_file}" >> "${LOG_DIR}/checkpoints.log"

echo "✓ Checkpoint saved: $checkpoint_file"
echo "  - Session: $SESSION_ID"
echo "  - Git branch: $git_branch"
echo "  - Uncommitted changes: $uncommitted_count"
echo "  - Recent tools: $(echo "$recent_tools" | jq 'length' 2>/dev/null || echo 0)"
