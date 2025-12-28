#!/bin/bash
#===============================================================================
# monitor.sh - Real-time monitoring of Claude Code autonomous session
#===============================================================================
# Usage:
#   monitor.sh              # Interactive dashboard
#   monitor.sh --watch      # Auto-refresh every 5 seconds
#   monitor.sh --log        # Tail the latest log file
#   monitor.sh --summary    # Quick status summary
#===============================================================================

set -e

LOG_DIR="$HOME/.claude/autonomous/logs"
SESSION_DIR="$HOME/.claude/autonomous/sessions"
QUEUE_DIR="$HOME/.claude/autonomous/tasks/queue"
COMPLETED_DIR="$HOME/.claude/autonomous/tasks/completed"
FAILED_DIR="$HOME/.claude/autonomous/tasks/failed"
TMUX_SESSION="claude-autonomous"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

clear_screen() {
    printf "\033c"
}

# Get session status
get_session_status() {
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        echo "RUNNING"
    else
        echo "STOPPED"
    fi
}

# Get latest log file
get_latest_log() {
    ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1
}

# Get log size in human readable format
get_log_size() {
    local log=$(get_latest_log)
    if [[ -n "$log" && -f "$log" ]]; then
        du -h "$log" | cut -f1
    else
        echo "0"
    fi
}

# Get message count from log
get_message_count() {
    local log=$(get_latest_log)
    if [[ -n "$log" && -f "$log" ]]; then
        grep -c "^\[" "$log" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Get uptime of tmux session
get_uptime() {
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        local created=$(tmux display-message -p -t "$TMUX_SESSION" '#{session_created}' 2>/dev/null)
        if [[ -n "$created" ]]; then
            local now=$(date +%s)
            local diff=$((now - created))
            local hours=$((diff / 3600))
            local mins=$(((diff % 3600) / 60))
            echo "${hours}h ${mins}m"
        else
            echo "Unknown"
        fi
    else
        echo "N/A"
    fi
}

# Show dashboard
show_dashboard() {
    clear_screen

    local status=$(get_session_status)
    local uptime=$(get_uptime)
    local latest_log=$(get_latest_log)
    local log_size=$(get_log_size)
    local pending=$(ls -1 "$QUEUE_DIR"/*.md 2>/dev/null | wc -l || echo "0")
    local completed=$(ls -1 "$COMPLETED_DIR"/*.md 2>/dev/null | wc -l || echo "0")
    local failed=$(ls -1 "$FAILED_DIR"/*.md 2>/dev/null | wc -l || echo "0")
    local checkpoints=$(ls -1 "$SESSION_DIR"/checkpoint_*.json 2>/dev/null | wc -l || echo "0")

    echo -e "${BOLD}${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║           CLAUDE CODE AUTONOMOUS SESSION MONITOR                 ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # Status section
    echo -e "${BOLD}Session Status${NC}"
    echo "────────────────────────────────────────────────────────────────────"
    if [[ "$status" == "RUNNING" ]]; then
        echo -e "  Status:     ${GREEN}● RUNNING${NC}"
    else
        echo -e "  Status:     ${RED}○ STOPPED${NC}"
    fi
    echo -e "  Uptime:     ${CYAN}$uptime${NC}"
    echo -e "  Session:    ${CYAN}$TMUX_SESSION${NC}"
    echo ""

    # Task Queue section
    echo -e "${BOLD}Task Queue${NC}"
    echo "────────────────────────────────────────────────────────────────────"
    echo -e "  Pending:    ${YELLOW}$pending${NC}"
    echo -e "  Completed:  ${GREEN}$completed${NC}"
    echo -e "  Failed:     ${RED}$failed${NC}"
    echo ""

    # Logs section
    echo -e "${BOLD}Logging${NC}"
    echo "────────────────────────────────────────────────────────────────────"
    echo -e "  Log File:   ${CYAN}$(basename "$latest_log" 2>/dev/null || echo 'None')${NC}"
    echo -e "  Log Size:   ${CYAN}$log_size${NC}"
    echo -e "  Checkpoints: ${CYAN}$checkpoints${NC}"
    echo ""

    # Recent activity
    echo -e "${BOLD}Recent Activity (last 10 lines)${NC}"
    echo "────────────────────────────────────────────────────────────────────"
    if [[ -n "$latest_log" && -f "$latest_log" ]]; then
        tail -10 "$latest_log" 2>/dev/null | while IFS= read -r line; do
            # Truncate long lines
            echo "  ${line:0:66}"
        done
    else
        echo -e "  ${YELLOW}No log activity yet${NC}"
    fi
    echo ""

    # Commands
    echo -e "${BOLD}Commands${NC}"
    echo "────────────────────────────────────────────────────────────────────"
    echo "  [a] Attach to session    [l] Tail log    [r] Refresh"
    echo "  [s] Stop session         [q] Quit        [t] Task queue"
    echo ""
    echo -e "  Last Updated: $(date '+%Y-%m-%d %H:%M:%S')"
}

# Interactive mode
interactive_mode() {
    while true; do
        show_dashboard
        read -t 5 -n 1 -s key 2>/dev/null || key=""

        case "$key" in
            a|A)
                if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
                    tmux attach -t "$TMUX_SESSION"
                else
                    echo -e "${RED}No active session${NC}"
                    sleep 2
                fi
                ;;
            l|L)
                local log=$(get_latest_log)
                if [[ -n "$log" ]]; then
                    tail -f "$log"
                fi
                ;;
            s|S)
                if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
                    read -p "Stop session? [y/N] " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        tmux kill-session -t "$TMUX_SESSION"
                        echo -e "${GREEN}Session stopped${NC}"
                        sleep 2
                    fi
                fi
                ;;
            t|T)
                "$HOME/.claude/autonomous/task-queue.sh" list
                read -p "Press Enter to continue..." -r
                ;;
            r|R)
                # Just refresh
                ;;
            q|Q)
                clear_screen
                exit 0
                ;;
        esac
    done
}

# Watch mode - auto-refresh
watch_mode() {
    while true; do
        show_dashboard
        sleep 5
    done
}

# Summary mode
summary_mode() {
    local status=$(get_session_status)
    local uptime=$(get_uptime)
    local pending=$(ls -1 "$QUEUE_DIR"/*.md 2>/dev/null | wc -l || echo "0")
    local completed=$(ls -1 "$COMPLETED_DIR"/*.md 2>/dev/null | wc -l || echo "0")
    local failed=$(ls -1 "$FAILED_DIR"/*.md 2>/dev/null | wc -l || echo "0")

    echo "Claude Autonomous: $status | Uptime: $uptime | Queue: $pending pending, $completed done, $failed failed"
}

# Log tail mode
log_mode() {
    local log=$(get_latest_log)
    if [[ -n "$log" && -f "$log" ]]; then
        echo -e "${CYAN}Tailing: $log${NC}"
        echo "Press Ctrl+C to exit"
        echo ""
        tail -f "$log"
    else
        echo -e "${RED}No log file found${NC}"
    fi
}

# Main
case "${1:-}" in
    --watch|-w)
        watch_mode
        ;;
    --log|-l)
        log_mode
        ;;
    --summary|-s)
        summary_mode
        ;;
    *)
        interactive_mode
        ;;
esac
