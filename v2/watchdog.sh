#!/bin/bash
#===============================================================================
# watchdog.sh - Auto-resume watchdog for Claude Code autonomous sessions
#===============================================================================
# Usage:
#   watchdog.sh start [project_dir]   # Start watching
#   watchdog.sh stop                  # Stop watchdog
#   watchdog.sh status               # Check watchdog status
#
# The watchdog runs in the background and:
#   1. Monitors the Claude tmux session every 30 seconds
#   2. If session dies, attempts to resume with --continue
#   3. Logs all restart events
#   4. Sends desktop notification (if available)
#===============================================================================

set -e

WATCHDOG_PID_FILE="$HOME/.claude/autonomous/watchdog.pid"
WATCHDOG_LOG="$HOME/.claude/autonomous/logs/watchdog.log"
TMUX_SESSION="claude-autonomous"
CHECK_INTERVAL=30  # seconds
MAX_RESTARTS=999999  # Effectively unlimited for production resilience
RESTART_COOLDOWN=60 # Seconds between restarts

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" >> "$WATCHDOG_LOG"
    echo -e "${GREEN}$msg${NC}"
}

error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1"
    echo "$msg" >> "$WATCHDOG_LOG"
    echo -e "${RED}$msg${NC}"
}

notify() {
    local msg="$1"
    # Try desktop notification
    if command -v notify-send &>/dev/null; then
        notify-send "Claude Watchdog" "$msg" 2>/dev/null || true
    fi
    log "NOTIFICATION: $msg"
}

is_session_running() {
    tmux has-session -t "$TMUX_SESSION" 2>/dev/null
}

restart_session() {
    local project_dir="$1"
    log "Attempting to restart Claude session..."

    # Kill any zombie session
    tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
    sleep 2

    # Start new session with continue flag
    tmux new-session -d -s "$TMUX_SESSION" -c "$project_dir"
    tmux set-option -t "$TMUX_SESSION" remain-on-exit on

    # Try to continue previous conversation
    tmux send-keys -t "$TMUX_SESSION" "claude --dangerously-skip-permissions --continue" C-m

    if is_session_running; then
        log "Session restarted successfully"
        notify "Claude session restarted"
        return 0
    else
        error "Failed to restart session"
        return 1
    fi
}

run_watchdog() {
    local project_dir="${1:-$HOME}"
    local restart_count=0
    local last_restart=0

    log "Watchdog started for project: $project_dir"
    log "Check interval: ${CHECK_INTERVAL}s | Max restarts: $MAX_RESTARTS"

    while true; do
        sleep "$CHECK_INTERVAL"

        # P2-FIX-3: Reset counter in main loop (not subshell) after 10min stability
        if [[ $restart_count -gt 0 ]] && [[ $last_restart -gt 0 ]]; then
            local stable_time=$(($(date +%s) - last_restart))
            if [[ $stable_time -gt 600 ]] && is_session_running; then
                log "Session stable for 10m, reset restart counter (was: $restart_count)"
                restart_count=0
            fi
        fi

        if ! is_session_running; then
            local now=$(date +%s)
            local since_last=$((now - last_restart))

            # Check cooldown
            if [[ $since_last -lt $RESTART_COOLDOWN ]]; then
                log "Cooldown active, waiting... ($since_last/$RESTART_COOLDOWN)"
                continue
            fi

            # Check max restarts
            if [[ $restart_count -ge $MAX_RESTARTS ]]; then
                error "Max restarts ($MAX_RESTARTS) reached. Watchdog stopping."
                notify "Claude watchdog: Max restarts reached. Manual intervention needed."
                break
            fi

            error "Session died! Restart attempt #$((restart_count + 1))"
            notify "Claude session died, attempting restart..."

            if restart_session "$project_dir"; then
                restart_count=$((restart_count + 1))
                last_restart=$now
                # Note: Counter reset now happens in main loop (P2-FIX-3)
            fi
        fi
    done

    log "Watchdog stopped"
    rm -f "$WATCHDOG_PID_FILE"
}

start_watchdog() {
    local project_dir="${1:-$(pwd)}"

    # Check if already running
    if [[ -f "$WATCHDOG_PID_FILE" ]]; then
        local pid=$(cat "$WATCHDOG_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${YELLOW}Watchdog already running (PID: $pid)${NC}"
            return 1
        fi
        rm -f "$WATCHDOG_PID_FILE"
    fi

    mkdir -p "$(dirname "$WATCHDOG_LOG")"

    echo -e "${GREEN}Starting watchdog for: $project_dir${NC}"
    log "Starting watchdog daemon..."

    # Run in background
    nohup bash -c "
        echo \$\$ > '$WATCHDOG_PID_FILE'
        source '$0'
        run_watchdog '$project_dir'
    " >> "$WATCHDOG_LOG" 2>&1 &

    local new_pid=$!
    echo "$new_pid" > "$WATCHDOG_PID_FILE"

    sleep 1
    if kill -0 "$new_pid" 2>/dev/null; then
        echo -e "${GREEN}Watchdog started (PID: $new_pid)${NC}"
        echo -e "Log file: $WATCHDOG_LOG"
    else
        error "Failed to start watchdog"
        return 1
    fi
}

stop_watchdog() {
    if [[ ! -f "$WATCHDOG_PID_FILE" ]]; then
        echo -e "${YELLOW}Watchdog not running${NC}"
        return 0
    fi

    local pid=$(cat "$WATCHDOG_PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid"
        rm -f "$WATCHDOG_PID_FILE"
        echo -e "${GREEN}Watchdog stopped (was PID: $pid)${NC}"
        log "Watchdog stopped by user"
    else
        rm -f "$WATCHDOG_PID_FILE"
        echo -e "${YELLOW}Watchdog was not running (stale PID file removed)${NC}"
    fi
}

status_watchdog() {
    echo -e "${BLUE}=== Watchdog Status ===${NC}"

    if [[ -f "$WATCHDOG_PID_FILE" ]]; then
        local pid=$(cat "$WATCHDOG_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "  Status:     ${GREEN}● RUNNING${NC} (PID: $pid)"
        else
            echo -e "  Status:     ${RED}○ DEAD${NC} (stale PID: $pid)"
        fi
    else
        echo -e "  Status:     ${YELLOW}○ NOT RUNNING${NC}"
    fi

    if is_session_running; then
        echo -e "  Session:    ${GREEN}● ACTIVE${NC}"
    else
        echo -e "  Session:    ${RED}○ INACTIVE${NC}"
    fi

    if [[ -f "$WATCHDOG_LOG" ]]; then
        echo -e "  Log File:   $WATCHDOG_LOG"
        echo -e "\n  ${BLUE}Last 5 log entries:${NC}"
        tail -5 "$WATCHDOG_LOG" | sed 's/^/    /'
    fi
    echo ""
}

# Export functions for nohup subshell
export -f log error notify is_session_running restart_session run_watchdog

# Main
case "${1:-}" in
    start)
        start_watchdog "$2"
        ;;
    stop)
        stop_watchdog
        ;;
    status)
        status_watchdog
        ;;
    *)
        echo "Usage: watchdog.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  start [DIR]   Start watchdog (monitors session, auto-restarts)"
        echo "  stop          Stop watchdog"
        echo "  status        Show watchdog status"
        echo ""
        echo "The watchdog monitors the Claude tmux session and automatically"
        echo "restarts it if it crashes, using --continue to resume work."
        ;;
esac
