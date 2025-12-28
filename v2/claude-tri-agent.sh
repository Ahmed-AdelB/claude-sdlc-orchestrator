#!/bin/bash
#===============================================================================
# claude-tri-agent.sh - Launch Claude with Gemini 3 Pro & Codex GPT-5.2 support
#===============================================================================
# Usage:
#   claude-tri-agent.sh [project_dir] [task_file]
#   claude-tri-agent.sh ~/projects/myapp
#   claude-tri-agent.sh ~/projects/myapp tasks/complex-feature.md
#
# This launcher:
#   1. Runs Claude Opus 4.5 as the primary orchestrator
#   2. Enables Claude to delegate to Gemini 3 Pro (1M context, high thinking)
#   3. Enables Claude to delegate to Codex GPT-5.2 (xhigh reasoning)
#   4. Provides task routing based on task type
#   5. Runs in tmux for 24+ hour persistence
#
# Model Configuration:
#   - Claude Opus 4.5: Primary orchestration, complex reasoning
#   - Gemini 3 Pro Preview: Large context analysis (1M tokens), multimodal
#   - Codex GPT-5.2: Rapid implementation, xhigh reasoning effort
#===============================================================================

set -e

# Configuration
CLAUDE_SESSION="claude-tri-agent"
PROJECT_DIR="${1:-$(pwd)}"
TASK_FILE="${2:-}"
LOG_DIR="$HOME/.claude/autonomous/logs"
SETTINGS_FILE="$HOME/.claude/autonomous/settings-tri-agent.json"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/tri-agent_$TIMESTAMP.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

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

# Check all CLIs are available
check_deps() {
    local missing=()

    command -v tmux >/dev/null 2>&1 || missing+=("tmux")
    command -v claude >/dev/null 2>&1 || missing+=("claude")
    command -v gemini >/dev/null 2>&1 || missing+=("gemini")
    command -v codex >/dev/null 2>&1 || missing+=("codex")

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required tools: ${missing[*]}"
    fi

    log "All tools available: claude, gemini, codex, tmux"
}

# Kill existing session if running
kill_existing() {
    if tmux has-session -t "$CLAUDE_SESSION" 2>/dev/null; then
        warn "Existing session found. Killing..."
        tmux kill-session -t "$CLAUDE_SESSION"
        sleep 1
    fi
}

# Build the Claude command with tri-agent system prompt
build_claude_cmd() {
    local cmd="claude"

    # Core autonomous flags
    cmd="$cmd --dangerously-skip-permissions"
    cmd="$cmd --settings '$SETTINGS_FILE'"
    cmd="$cmd --model opus"

    # Add tri-agent system prompt
    local system_prompt="You have access to two additional AI models for delegation:

1. GEMINI 3 PRO (1M context, high thinking):
   Use: gemini-ask \"your prompt here\"
   Best for: Large codebase analysis, long documents, multimodal tasks

2. CODEX GPT-5.2 (xhigh reasoning):
   Use: codex-ask \"your prompt here\"
   Best for: Rapid implementation, code generation, debugging

DELEGATION GUIDELINES:
- For analyzing files >50KB or full codebases: Use Gemini
- For rapid prototyping or alternative implementations: Use Codex
- For complex architecture decisions: Handle yourself (Opus)
- For consensus on critical changes: Query both and synthesize
- Always integrate responses back into your work"

    cmd="$cmd --append-system-prompt \"$system_prompt\""

    # If task file provided, use print mode
    if [[ -n "$TASK_FILE" && -f "$TASK_FILE" ]]; then
        local task_content=$(cat "$TASK_FILE")
        cmd="$cmd -p \"$task_content\""
    fi

    echo "$cmd"
}

# Create the tmux session with tri-agent environment
create_session() {
    log "Creating tri-agent tmux session: $CLAUDE_SESSION"

    # Create session in detached mode
    tmux new-session -d -s "$CLAUDE_SESSION" -c "$PROJECT_DIR"

    # Configure tmux for long-running operation
    tmux set-option -t "$CLAUDE_SESSION" history-limit 100000
    tmux set-option -t "$CLAUDE_SESSION" remain-on-exit on

    # Set environment variables
    tmux send-keys -t "$CLAUDE_SESSION" "export CLAUDE_AUTONOMOUS_MODE=true" C-m
    tmux send-keys -t "$CLAUDE_SESSION" "export CLAUDE_TRI_AGENT=true" C-m
    tmux send-keys -t "$CLAUDE_SESSION" "export CLAUDE_LOG_FILE='$LOG_FILE'" C-m
    tmux send-keys -t "$CLAUDE_SESSION" "export PATH=\"\$HOME/.claude/autonomous/bin:\$PATH\"" C-m
    tmux send-keys -t "$CLAUDE_SESSION" "cd '$PROJECT_DIR'" C-m

    # Start Claude with tri-agent support
    local claude_cmd=$(build_claude_cmd)
    log "Starting Claude with tri-agent support..."

    if [[ -n "$TASK_FILE" && -f "$TASK_FILE" ]]; then
        tmux send-keys -t "$CLAUDE_SESSION" "$claude_cmd 2>&1 | tee -a '$LOG_FILE'" C-m
    else
        tmux send-keys -t "$CLAUDE_SESSION" "script -q -a '$LOG_FILE' -c \"$claude_cmd\"" C-m
    fi
}

# Show session info
show_info() {
    echo ""
    echo -e "${BOLD}${MAGENTA}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║           TRI-AGENT AUTONOMOUS SESSION STARTED                   ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "  ${BOLD}Primary Model:${NC}"
    echo -e "    ${CYAN}Claude Opus 4.5${NC} - Orchestration & Complex Reasoning"
    echo ""
    echo -e "  ${BOLD}Delegation Models:${NC}"
    echo -e "    ${GREEN}Gemini 3 Pro${NC} - 1M Context, High Thinking"
    echo -e "    ${YELLOW}Codex GPT-5.2${NC} - xHigh Reasoning Effort"
    echo ""
    echo -e "  ${BOLD}Session:${NC}        $CLAUDE_SESSION"
    echo -e "  ${BOLD}Project:${NC}        $PROJECT_DIR"
    echo -e "  ${BOLD}Log File:${NC}       $LOG_FILE"
    [[ -n "$TASK_FILE" ]] && echo -e "  ${BOLD}Task File:${NC}      $TASK_FILE"
    echo ""
    echo "════════════════════════════════════════════════════════════════════"
    echo "  Commands:"
    echo "════════════════════════════════════════════════════════════════════"
    echo ""
    echo "  Attach to session:     tmux attach -t $CLAUDE_SESSION"
    echo "  Detach (keep running): Press Ctrl+B, then D"
    echo "  View logs:             tail -f $LOG_FILE"
    echo "  Kill session:          tmux kill-session -t $CLAUDE_SESSION"
    echo ""
    echo "════════════════════════════════════════════════════════════════════"
    echo ""
}

# Main
main() {
    echo -e "${BOLD}${MAGENTA}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║              TRI-AGENT LAUNCHER v1.0                             ║"
    echo "║         Claude Opus + Gemini 3 Pro + Codex GPT-5.2               ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    check_deps
    mkdir -p "$LOG_DIR"
    mkdir -p "$HOME/.claude/autonomous/bin"

    # Validate project directory
    [[ -d "$PROJECT_DIR" ]] || error "Project directory not found: $PROJECT_DIR"

    # Validate task file if provided
    if [[ -n "$TASK_FILE" && ! -f "$TASK_FILE" ]]; then
        error "Task file not found: $TASK_FILE"
    fi

    # Ensure helper scripts exist
    if [[ ! -x "$HOME/.claude/autonomous/bin/gemini-ask" ]]; then
        warn "Helper scripts not found. Run setup first."
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
