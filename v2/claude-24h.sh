#!/bin/bash
#===============================================================================
# claude-24h.sh - Launch Claude Code for 24+ hour autonomous operation
#===============================================================================
# Usage:
#   claude-24h.sh [project_dir] [task_file]
#   claude-24h.sh ~/projects/myapp tasks/build-feature.md
#   claude-24h.sh                    # Uses current directory, interactive
#
# Features:
#   - Runs in tmux for session persistence
#   - Auto-resumes on disconnect
#   - YOLO mode (--dangerously-skip-permissions)
#   - Checkpoint saves on each stop
#   - Task queue processing
#   - Logging to ~/.claude/autonomous/logs/
#===============================================================================

set -e

# Configuration
CLAUDE_SESSION="claude-autonomous"
PROJECT_DIR="${1:-$(pwd)}"
TASK_FILE="${2:-}"
LOG_DIR="$HOME/.claude/autonomous/logs"
SETTINGS_FILE="$HOME/.claude/autonomous/settings-autonomous.json"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/session_$TIMESTAMP.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ERROR:${NC} $1"
    exit 1
}

# Check dependencies
check_deps() {
    command -v tmux >/dev/null 2>&1 || error "tmux is required. Install with: sudo apt install tmux"
    command -v claude >/dev/null 2>&1 || error "Claude Code CLI not found"
}

# Kill existing session if running
kill_existing() {
    if tmux has-session -t "$CLAUDE_SESSION" 2>/dev/null; then
        warn "Existing session found. Killing..."
        tmux kill-session -t "$CLAUDE_SESSION"
        sleep 1
    fi
}

# Build the Claude command
build_claude_cmd() {
    local cmd="claude"

    # Core autonomous flags
    cmd="$cmd --dangerously-skip-permissions"
    cmd="$cmd --settings '$SETTINGS_FILE'"
    cmd="$cmd --model opus"

    # If task file provided, use print mode with the task
    if [[ -n "$TASK_FILE" && -f "$TASK_FILE" ]]; then
        local task_content=$(cat "$TASK_FILE")
        cmd="$cmd -p \"$task_content\""
    fi

    echo "$cmd"
}

# Create the tmux session
create_session() {
    log "Creating tmux session: $CLAUDE_SESSION"

    # Create session in detached mode
    tmux new-session -d -s "$CLAUDE_SESSION" -c "$PROJECT_DIR"

    # Configure tmux for long-running operation
    tmux set-option -t "$CLAUDE_SESSION" history-limit 100000
    tmux set-option -t "$CLAUDE_SESSION" remain-on-exit on

    # Set environment variables
    tmux send-keys -t "$CLAUDE_SESSION" "export CLAUDE_AUTONOMOUS_MODE=true" C-m
    tmux send-keys -t "$CLAUDE_SESSION" "export CLAUDE_LOG_FILE='$LOG_FILE'" C-m
    tmux send-keys -t "$CLAUDE_SESSION" "cd '$PROJECT_DIR'" C-m

    # Start Claude
    local claude_cmd=$(build_claude_cmd)
    log "Starting Claude with: $claude_cmd"

    # If task file provided, use print mode with logging
    # Otherwise, run interactively without tee (which interferes with terminal)
    if [[ -n "$TASK_FILE" && -f "$TASK_FILE" ]]; then
        tmux send-keys -t "$CLAUDE_SESSION" "$claude_cmd 2>&1 | tee -a '$LOG_FILE'" C-m
    else
        # Interactive mode - use script command for logging without breaking terminal
        tmux send-keys -t "$CLAUDE_SESSION" "script -q -a '$LOG_FILE' -c \"$claude_cmd\"" C-m
    fi
}

# Show session info
show_info() {
    echo ""
    echo "================================================================"
    echo -e "${GREEN}Claude Code 24-Hour Autonomous Session Started${NC}"
    echo "================================================================"
    echo ""
    echo -e "  ${BLUE}Session Name:${NC}  $CLAUDE_SESSION"
    echo -e "  ${BLUE}Project Dir:${NC}   $PROJECT_DIR"
    echo -e "  ${BLUE}Log File:${NC}      $LOG_FILE"
    echo -e "  ${BLUE}Settings:${NC}      $SETTINGS_FILE"
    [[ -n "$TASK_FILE" ]] && echo -e "  ${BLUE}Task File:${NC}     $TASK_FILE"
    echo ""
    echo "================================================================"
    echo "  Commands:"
    echo "================================================================"
    echo ""
    echo "  Attach to session:     tmux attach -t $CLAUDE_SESSION"
    echo "  Detach (keep running): Press Ctrl+B, then D"
    echo "  View logs:             tail -f $LOG_FILE"
    echo "  Kill session:          tmux kill-session -t $CLAUDE_SESSION"
    echo "  List sessions:         tmux ls"
    echo ""
    echo "================================================================"
    echo ""
}

# Main
main() {
    log "Claude Code 24-Hour Launcher v1.0"

    check_deps
    mkdir -p "$LOG_DIR"

    # Validate project directory
    [[ -d "$PROJECT_DIR" ]] || error "Project directory not found: $PROJECT_DIR"

    # Validate task file if provided
    if [[ -n "$TASK_FILE" && ! -f "$TASK_FILE" ]]; then
        error "Task file not found: $TASK_FILE"
    fi

    kill_existing
    create_session
    show_info

    # Option to attach immediately
    read -p "Attach to session now? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        tmux attach -t "$CLAUDE_SESSION"
    else
        log "Session running in background. Use: tmux attach -t $CLAUDE_SESSION"
    fi
}

main "$@"
