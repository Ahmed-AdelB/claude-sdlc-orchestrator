#!/bin/bash
# checkpoint.sh - Saves session state after each Claude Code stop
# Called by the Stop hook in settings-autonomous.json

set -e

CHECKPOINT_DIR="$HOME/.claude/autonomous/sessions"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SESSION_FILE="$CHECKPOINT_DIR/checkpoint_$TIMESTAMP.json"

# Get current session info
CURRENT_DIR=$(pwd)
GIT_BRANCH=$(git branch --show-current 2>/dev/null || echo "none")
GIT_STATUS=$(git status --porcelain 2>/dev/null | head -20 || echo "not a git repo")

# Create checkpoint
cat > "$SESSION_FILE" << EOF
{
  "timestamp": "$TIMESTAMP",
  "working_directory": "$CURRENT_DIR",
  "git_branch": "$GIT_BRANCH",
  "git_status": "$GIT_STATUS",
  "environment": {
    "USER": "$USER",
    "HOME": "$HOME",
    "PATH": "$PATH"
  }
}
EOF

# Keep only last 50 checkpoints
ls -t "$CHECKPOINT_DIR"/checkpoint_*.json 2>/dev/null | tail -n +51 | xargs rm -f 2>/dev/null || true

echo "[Checkpoint] Saved to $SESSION_FILE"
