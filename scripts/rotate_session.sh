#!/bin/bash
# P4.1: Session Rotation Script - 8hr context refresh for 24hr operation
# Run via cron: 0 */8 * * * ~/.claude/scripts/rotate_session.sh

set -euo pipefail

LOG_DIR="${HOME}/.claude/logs"
SESSION_DIR="${HOME}/.claude/sessions"
CHECKPOINT_DIR="${SESSION_DIR}/checkpoints"
PROGRESS_FILE="${SESSION_DIR}/claude-progress.txt"

mkdir -p "$LOG_DIR" "$CHECKPOINT_DIR"

log() {
    echo "[$(date -Iseconds)] $*" >> "${LOG_DIR}/rotation.log"
    echo "[$(date -Iseconds)] $*"
}

# Configuration
SESSION_MAX_HOURS="${SESSION_MAX_DURATION_HOURS:-8}"
SESSION_MAX_SECONDS=$((SESSION_MAX_HOURS * 3600))
GEMINI_SUMMARIZE="${GEMINI_SUMMARIZE:-true}"

log "Starting session rotation check"

# Check if session needs rotation
SESSION_FILE=$(ls -t "${SESSION_DIR}"/session-*.log 2>/dev/null | head -1)
if [[ -z "$SESSION_FILE" ]]; then
    log "No active session found, skipping rotation"
    exit 0
fi

# Get session age
SESSION_START=$(stat -c %Y "$SESSION_FILE" 2>/dev/null || echo "0")
CURRENT_TIME=$(date +%s)
SESSION_AGE=$((CURRENT_TIME - SESSION_START))

log "Session age: $((SESSION_AGE / 3600))h $((SESSION_AGE % 3600 / 60))m"

if [[ $SESSION_AGE -lt $SESSION_MAX_SECONDS ]]; then
    log "Session under ${SESSION_MAX_HOURS}h threshold, no rotation needed"
    exit 0
fi

log "Session exceeded ${SESSION_MAX_HOURS}h, initiating rotation"

# Step 1: Create checkpoint
log "Step 1: Creating session checkpoint"
CHECKPOINT_FILE="${CHECKPOINT_DIR}/rotation-$(date +%Y%m%d_%H%M%S).json"

# Gather session state
git_branch=$(git branch --show-current 2>/dev/null || echo "N/A")
git_status=$(git status --short 2>/dev/null | head -20 | tr '\n' ';' || echo "N/A")
last_commit=$(git log -1 --format='%h %s' 2>/dev/null || echo "N/A")
uncommitted=$(git status --short 2>/dev/null | wc -l || echo "0")

cat > "$CHECKPOINT_FILE" <<EOF
{
  "rotation_at": "$(date -Iseconds)",
  "session_age_hours": $((SESSION_AGE / 3600)),
  "reason": "scheduled_8hr_rotation",
  "git_state": {
    "branch": "$git_branch",
    "last_commit": "$last_commit",
    "uncommitted_changes": $uncommitted,
    "status": "$git_status"
  },
  "progress_file": "$PROGRESS_FILE"
}
EOF

log "Checkpoint created: $CHECKPOINT_FILE"

# Step 2: Generate session summary (optional Gemini integration)
if [[ "$GEMINI_SUMMARIZE" == "true" ]] && command -v gemini &>/dev/null; then
    log "Step 2: Generating session summary via Gemini"
    SUMMARY_FILE="${SESSION_DIR}/summary-$(date +%Y%m%d_%H%M%S).md"

    if [[ -f "$PROGRESS_FILE" ]]; then
        PROGRESS_CONTENT=$(cat "$PROGRESS_FILE" | head -100)
        gemini -y "Summarize this session progress for context handoff. Be concise (< 500 words): $PROGRESS_CONTENT" > "$SUMMARY_FILE" 2>/dev/null || {
            log "Gemini summarization failed, using raw progress"
            cp "$PROGRESS_FILE" "$SUMMARY_FILE"
        }
    fi
    log "Summary saved: $SUMMARY_FILE"
else
    log "Step 2: Skipping Gemini summary (disabled or unavailable)"
fi

# Step 3: Update progress file for next session
log "Step 3: Updating progress file"
cat > "$PROGRESS_FILE" <<EOF
# Session Progress Log
## Last Updated: $(date -Iseconds)
## Previous Session Rotated: Yes

### Rotation Summary:
- Rotated at: $(date -Iseconds)
- Previous session age: $((SESSION_AGE / 3600)) hours
- Checkpoint: $CHECKPOINT_FILE

### Git State at Rotation:
- Branch: $git_branch
- Last commit: $last_commit
- Uncommitted changes: $uncommitted

### Resume Notes:
[Previous context summarized. Review checkpoint for full state.]

### Next Actions:
[Continue from where previous session left off]
EOF

log "Progress file updated"

# Step 4: Archive old session logs
log "Step 4: Archiving old session logs"
find "${SESSION_DIR}" -name "session-*.log" -mmin +$((SESSION_MAX_SECONDS / 60 + 10)) -exec gzip {} \; 2>/dev/null || true

# Step 5: Cleanup old rotations (keep last 10)
log "Step 5: Cleaning up old rotation checkpoints"
ls -t "${CHECKPOINT_DIR}"/rotation-*.json 2>/dev/null | tail -n +11 | xargs -r rm -f

log "Session rotation completed successfully"
log "Next session should resume from: $CHECKPOINT_FILE"

# Output for automation
echo "ROTATION_COMPLETED"
echo "CHECKPOINT=$CHECKPOINT_FILE"
echo "PROGRESS=$PROGRESS_FILE"
