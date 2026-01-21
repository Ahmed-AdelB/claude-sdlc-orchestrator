#!/usr/bin/env bash
#
# Tri-Agent Task Queue Manager - Shell Wrapper
#
# Provides convenient shortcuts for common queue operations.
# For full functionality, use: queue-manager.py <command>
#
# Author: Ahmed Adel Bakr Alderai
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUEUE_MANAGER="${SCRIPT_DIR}/queue-manager.py"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Priority color coding
priority_color() {
    case "$1" in
        P0*|CRITICAL) echo -e "${RED}$1${NC}" ;;
        P1*|HIGH)     echo -e "${YELLOW}$1${NC}" ;;
        P2*|MEDIUM)   echo -e "${BLUE}$1${NC}" ;;
        P3*|LOW)      echo -e "${GREEN}$1${NC}" ;;
        *)            echo "$1" ;;
    esac
}

show_help() {
    cat << 'EOF'
Tri-Agent Task Queue Manager

USAGE:
    queue-manager.sh <command> [options]

COMMANDS:
    add <desc> [-p priority] [-c category]    Add a new task
    next                                       Get next task to process
    start <task_id> [-a agent]                Start working on a task
    complete <task_id>                        Mark task as completed
    fail <task_id>                            Mark task as failed
    retry <task_id>                           Retry a failed task
    priority <task_id> <priority>             Change task priority
    list [-s status] [-p priority]            List tasks
    batch [--export]                          Create task batch
    boost                                      Apply age-based boosts
    stats [--json]                            Show queue statistics
    import <file>                             Import tasks from file
    watch                                      Watch queue (live updates)
    daemon                                     Run as background processor

PRIORITY LEVELS:
    P0 / CRITICAL   - Immediate attention required
    P1 / HIGH       - Should be done soon
    P2 / MEDIUM     - Normal priority (default)
    P3 / LOW        - Can wait

CATEGORIES:
    security, backend, frontend, testing, documentation,
    devops, refactoring, bugfix, feature, other

EXAMPLES:
    # Add a high-priority security task
    queue-manager.sh add "Fix SQL injection vulnerability" -p P0 -c security

    # Get and start the next task
    queue-manager.sh next
    queue-manager.sh start task_123456_789 -a claude

    # Complete or fail a task
    queue-manager.sh complete task_123456_789
    queue-manager.sh fail task_123456_789

    # Create batches for parallel processing
    queue-manager.sh batch --export

    # Apply priority boosts to aging tasks
    queue-manager.sh boost

AGE-BASED PRIORITY BOOST:
    Tasks automatically get promoted if they wait too long:
    - P3 (LOW) -> P2 (MEDIUM) after 4 hours
    - P2 (MEDIUM) -> P1 (HIGH) after 8 hours
    - P1 (HIGH) -> P0 (CRITICAL) after 24 hours

EOF
}

# Quick stats summary
quick_stats() {
    python3 "${QUEUE_MANAGER}" stats 2>/dev/null | head -15
}

# Watch mode - refresh stats every N seconds
watch_queue() {
    local interval="${1:-5}"
    echo "Watching queue (refresh every ${interval}s, Ctrl+C to stop)..."
    while true; do
        clear
        echo "=== Queue Status: $(date '+%Y-%m-%d %H:%M:%S') ==="
        echo ""
        python3 "${QUEUE_MANAGER}" stats
        echo ""
        echo "--- Next Task ---"
        python3 "${QUEUE_MANAGER}" next 2>/dev/null || echo "No pending tasks"
        sleep "${interval}"
    done
}

# Daemon mode - process tasks automatically
daemon_mode() {
    echo "Starting queue processor daemon..."
    echo "PID: $$"

    while true; do
        # Apply age boosts
        boosted=$(python3 "${QUEUE_MANAGER}" boost 2>/dev/null | grep -oP '\d+' || echo "0")
        [[ "$boosted" -gt 0 ]] && echo "[$(date '+%H:%M:%S')] Boosted ${boosted} tasks"

        # Get next task
        next_task=$(python3 "${QUEUE_MANAGER}" next 2>/dev/null | grep "^Next task:" | cut -d: -f2 | tr -d ' ')

        if [[ -n "$next_task" ]]; then
            echo "[$(date '+%H:%M:%S')] Next task available: ${next_task}"
            # In a real daemon, this would dispatch to an agent
            # For now, just log availability
        fi

        # Save metrics periodically
        python3 "${QUEUE_MANAGER}" stats --save >/dev/null 2>&1 || true

        sleep 60
    done
}

# Main command dispatcher
case "${1:-help}" in
    add)
        shift
        python3 "${QUEUE_MANAGER}" add "$@"
        ;;
    next)
        python3 "${QUEUE_MANAGER}" next
        ;;
    start)
        shift
        python3 "${QUEUE_MANAGER}" start "$@"
        ;;
    complete)
        shift
        python3 "${QUEUE_MANAGER}" complete "$@"
        ;;
    fail)
        shift
        python3 "${QUEUE_MANAGER}" complete --failed "$@"
        ;;
    retry)
        shift
        python3 "${QUEUE_MANAGER}" retry "$@"
        ;;
    priority|prio)
        shift
        python3 "${QUEUE_MANAGER}" priority "$@"
        ;;
    list|ls)
        shift
        python3 "${QUEUE_MANAGER}" list "$@"
        ;;
    batch)
        shift
        python3 "${QUEUE_MANAGER}" batch "$@"
        ;;
    boost)
        python3 "${QUEUE_MANAGER}" boost
        ;;
    stats)
        shift
        python3 "${QUEUE_MANAGER}" stats "$@"
        ;;
    import)
        shift
        python3 "${QUEUE_MANAGER}" import "$@"
        ;;
    get)
        shift
        python3 "${QUEUE_MANAGER}" get "$@"
        ;;
    delete|rm)
        shift
        python3 "${QUEUE_MANAGER}" delete "$@"
        ;;
    watch)
        shift
        watch_queue "${1:-5}"
        ;;
    daemon)
        daemon_mode
        ;;
    help|-h|--help)
        show_help
        ;;
    *)
        # Pass through to Python script
        python3 "${QUEUE_MANAGER}" "$@"
        ;;
esac
