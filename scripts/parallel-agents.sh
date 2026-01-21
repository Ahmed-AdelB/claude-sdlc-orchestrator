#!/bin/bash
# Parallel Agent Orchestration Script
# Creates git worktrees and runs multiple AI agents in parallel

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

usage() {
    cat << EOF
${CYAN}Parallel Agent Orchestration${NC}

Usage: $(basename "$0") <command> [options]

Commands:
  create <name> <branch>     Create a new worktree for an agent
  list                       List all worktrees
  remove <name>              Remove a worktree
  run <name> <agent> <task>  Run an agent in a worktree
  parallel <config-file>     Run multiple agents from config

Agents:
  claude    Claude Code CLI
  gemini    Gemini CLI
  codex     Codex CLI

Examples:
  $(basename "$0") create auth-feature feature/auth
  $(basename "$0") run auth-feature claude "Implement user authentication"
  $(basename "$0") parallel agents.yaml

EOF
}

create_worktree() {
    local name="$1"
    local branch="$2"
    local worktree_path="../${PROJECT_ROOT##*/}-$name"

    if [ -z "$name" ] || [ -z "$branch" ]; then
        log_error "Usage: create <name> <branch>"
        exit 1
    fi

    log_info "Creating worktree: $worktree_path (branch: $branch)"

    # Create branch if it doesn't exist
    if ! git show-ref --verify --quiet "refs/heads/$branch"; then
        git branch "$branch" 2>/dev/null || true
    fi

    git worktree add "$worktree_path" "$branch"
    log_success "Worktree created: $worktree_path"
    echo "$worktree_path"
}

list_worktrees() {
    log_info "Active worktrees:"
    git worktree list
}

remove_worktree() {
    local name="$1"
    local worktree_path="../${PROJECT_ROOT##*/}-$name"

    if [ -z "$name" ]; then
        log_error "Usage: remove <name>"
        exit 1
    fi

    log_info "Removing worktree: $worktree_path"
    git worktree remove "$worktree_path" --force
    log_success "Worktree removed"
}

run_agent() {
    local name="$1"
    local agent="$2"
    local task="$3"
    local worktree_path="../${PROJECT_ROOT##*/}-$name"

    if [ -z "$name" ] || [ -z "$agent" ] || [ -z "$task" ]; then
        log_error "Usage: run <name> <agent> <task>"
        exit 1
    fi

    if [ ! -d "$worktree_path" ]; then
        log_error "Worktree not found: $worktree_path"
        exit 1
    fi

    log_info "Running $agent in $worktree_path"
    cd "$worktree_path"

    case "$agent" in
        claude)
            claude -p "$task"
            ;;
        gemini)
            gemini -y "$task"
            ;;
        codex)
            codex exec "$task"
            ;;
        *)
            log_error "Unknown agent: $agent (use: claude, gemini, codex)"
            exit 1
            ;;
    esac
}

run_parallel() {
    local config_file="$1"

    if [ ! -f "$config_file" ]; then
        log_error "Config file not found: $config_file"
        exit 1
    fi

    log_info "Running parallel agents from: $config_file"
    log_warning "Parallel execution requires tmux. Install with: apt install tmux"

    # Create tmux session
    local session_name="parallel-agents-$$"
    tmux new-session -d -s "$session_name"

    local pane=0
    while IFS=: read -r name branch agent task; do
        [ -z "$name" ] && continue
        [[ "$name" =~ ^# ]] && continue

        local worktree_path="../${PROJECT_ROOT##*/}-$name"

        # Create worktree if needed
        if [ ! -d "$worktree_path" ]; then
            create_worktree "$name" "$branch"
        fi

        # Escape variables for safe shell execution
        local safe_path=$(printf %q "$worktree_path")
        local safe_task=$(printf %q "$task")

        # Create pane and run agent
        if [ $pane -gt 0 ]; then
            tmux split-window -t "$session_name"
            tmux select-layout -t "$session_name" tiled
        fi

        case "$agent" in
            claude)
                tmux send-keys -t "$session_name" "cd $safe_path && claude -p $safe_task" Enter
                ;;
            gemini)
                tmux send-keys -t "$session_name" "cd $safe_path && gemini -y $safe_task" Enter
                ;;
            codex)
                tmux send-keys -t "$session_name" "cd $safe_path && codex exec $safe_task" Enter
                ;;
        esac

        ((pane++))
    done < "$config_file"

    log_success "Parallel agents started in tmux session: $session_name"
    echo "Attach with: tmux attach -t $session_name"
}

# Main
case "$1" in
    create)
        create_worktree "$2" "$3"
        ;;
    list)
        list_worktrees
        ;;
    remove)
        remove_worktree "$2"
        ;;
    run)
        run_agent "$2" "$3" "$4"
        ;;
    parallel)
        run_parallel "$2"
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        usage
        exit 1
        ;;
esac
