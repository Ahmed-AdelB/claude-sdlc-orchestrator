#!/bin/bash
# Periodic Checkpoint Hook - Auto-save progress every N minutes
# Triggered by audit-posttool.sh based on SESSION_CHECKPOINT_INTERVAL
# Prevents context loss on abnormal session termination

set -uo pipefail

SESSION_DIR="${HOME}/.claude/sessions"
CHECKPOINT_DIR="${SESSION_DIR}/checkpoints"
LOG_DIR="${HOME}/.claude/logs"
PROGRESS_FILE="${SESSION_DIR}/claude-progress.txt"
LAST_CHECKPOINT_FILE="${SESSION_DIR}/.last_checkpoint_time"

# Interval in seconds (default 5 minutes)
CHECKPOINT_INTERVAL="${SESSION_CHECKPOINT_INTERVAL:-300}"

mkdir -p "$CHECKPOINT_DIR" "$LOG_DIR"

# Parse input
TOOL_DATA="${1:-}"
SESSION_ID="${2:-unknown}"
TIMESTAMP=$(date -Iseconds)
EPOCH_NOW=$(date +%s)

# Check if checkpoint is due
should_checkpoint() {
    if [[ ! -f "$LAST_CHECKPOINT_FILE" ]]; then
        return 0  # First checkpoint
    fi

    local last_checkpoint
    last_checkpoint=$(cat "$LAST_CHECKPOINT_FILE" 2>/dev/null || echo "0")
    local elapsed=$((EPOCH_NOW - last_checkpoint))

    if [[ $elapsed -ge $CHECKPOINT_INTERVAL ]]; then
        return 0  # Time for checkpoint
    fi
    return 1  # Not yet
}

# Create checkpoint
create_checkpoint() {
    local checkpoint_file="${CHECKPOINT_DIR}/auto-checkpoint-${SESSION_ID}-$(date +%Y%m%d_%H%M%S).json"

    # Get recent audit entries (last 20 tools used)
    local recent_tools=""
    local audit_file="${LOG_DIR}/audit/audit-$(date +%Y%m%d).jsonl"
    if [[ -f "$audit_file" ]]; then
        recent_tools=$(tail -20 "$audit_file" | jq -s '[.[] | {tool: .tool, timestamp: .timestamp}]' 2>/dev/null || echo "[]")
    else
        recent_tools="[]"
    fi

    # Get current todos
    local todos="[]"
    if [[ -f "${HOME}/.claude/todos.json" ]]; then
        todos=$(cat "${HOME}/.claude/todos.json" 2>/dev/null || echo "[]")
    fi

    # Get git state
    local git_branch git_status git_last_commit uncommitted_count
    git_branch=$(git branch --show-current 2>/dev/null || echo "N/A")
    git_last_commit=$(git log -1 --format='%h %s' 2>/dev/null || echo "N/A")
    uncommitted_count=$(git status --short 2>/dev/null | wc -l)
    git_status=$(git status --short 2>/dev/null | head -10 | tr '\n' ';' || echo "")

    # Get modified files in last checkpoint interval
    local recent_files=""
    recent_files=$(find . -type f -mmin -$((CHECKPOINT_INTERVAL / 60 + 1)) \
        -not -path "./.git/*" \
        -not -path "./node_modules/*" \
        -not -path "./venv/*" \
        -not -path "./__pycache__/*" \
        2>/dev/null | head -20 | tr '\n' ',' || echo "")

    # Build checkpoint JSON
    cat > "$checkpoint_file" <<EOF
{
  "type": "periodic_auto_checkpoint",
  "session_id": "${SESSION_ID}",
  "created_at": "${TIMESTAMP}",
  "epoch": ${EPOCH_NOW},
  "interval_seconds": ${CHECKPOINT_INTERVAL},
  "working_directory": "$(pwd)",
  "git_state": {
    "branch": "${git_branch}",
    "last_commit": "${git_last_commit}",
    "uncommitted_count": ${uncommitted_count},
    "status_preview": "${git_status}"
  },
  "recent_files_modified": "${recent_files}",
  "recent_tools": ${recent_tools},
  "todos": ${todos}
}
EOF

    # Update last checkpoint time
    echo "$EPOCH_NOW" > "$LAST_CHECKPOINT_FILE"

    # Update progress file
    (
        flock -x 200
        if [[ -f "$PROGRESS_FILE" ]]; then
            # Update the Last Updated timestamp
            sed -i "s/^## Last Updated:.*/## Last Updated: ${TIMESTAMP}/" "$PROGRESS_FILE"

            # Add checkpoint note if not already present for this minute
            local checkpoint_marker="### Auto-Checkpoint: $(date +%Y-%m-%d_%H:%M)"
            if ! grep -q "$checkpoint_marker" "$PROGRESS_FILE" 2>/dev/null; then
                echo "" >> "$PROGRESS_FILE"
                echo "$checkpoint_marker" >> "$PROGRESS_FILE"
                echo "- Working in: $(pwd)" >> "$PROGRESS_FILE"
                echo "- Git branch: ${git_branch}" >> "$PROGRESS_FILE"
                if [[ -n "$recent_files" ]]; then
                    echo "- Recent files: ${recent_files:0:200}" >> "$PROGRESS_FILE"
                fi
            fi
        fi
    ) 200>"${PROGRESS_FILE}.lock"

    # Log checkpoint
    echo "[${TIMESTAMP}] AUTO_CHECKPOINT session=${SESSION_ID} file=${checkpoint_file}" >> "${LOG_DIR}/checkpoints.log"

    # Cleanup old auto-checkpoints (keep last 50)
    ls -t "${CHECKPOINT_DIR}"/auto-checkpoint-*.json 2>/dev/null | tail -n +51 | xargs -r rm -f
}

# Main logic
if should_checkpoint; then
    create_checkpoint
fi

# Always return success
echo '{"continue": true}'
