#!/bin/bash
# P4.2: Semantic Watchdog - Detect and recover stuck agents
# Run via cron: */5 * * * * ~/.claude/scripts/semantic_watchdog.sh

set -euo pipefail

LOG_DIR="${HOME}/.claude/logs"
TASKS_DIR="${HOME}/.claude/tasks"
STATE_DIR="${HOME}/.claude/state"
ALERT_LOG="${LOG_DIR}/watchdog-alerts.log"

mkdir -p "$LOG_DIR" "$TASKS_DIR" "$STATE_DIR"

log() {
    echo "[$(date -Iseconds)] $*" >> "${LOG_DIR}/watchdog.log"
}

alert() {
    local level="$1"
    local message="$2"
    echo "[$(date -Iseconds)] [$level] $message" >> "$ALERT_LOG"

    # Desktop notification for critical alerts
    if [[ "$level" == "CRITICAL" ]] && command -v notify-send &>/dev/null; then
        notify-send -u critical "Tri-Agent Watchdog" "$message"
    fi
}

# Configuration
STUCK_THRESHOLD_MINUTES="${STUCK_TASK_THRESHOLD_MINUTES:-30}"
HEARTBEAT_STALE_MINUTES="${HEARTBEAT_STALE_MINUTES:-5}"
MAX_CONSECUTIVE_FAILURES="${MAX_CONSECUTIVE_FAILURES:-5}"

log "Semantic watchdog check started"

# Check 1: Stuck Tasks (no progress for threshold minutes)
log "Check 1: Scanning for stuck tasks"
STUCK_COUNT=0
for task_file in "${TASKS_DIR}"/*.json; do
    [[ -f "$task_file" ]] || continue

    # Get task age in minutes
    TASK_AGE=$(( ($(date +%s) - $(stat -c %Y "$task_file")) / 60 ))
    TASK_STATUS=$(jq -r '.status // "unknown"' "$task_file" 2>/dev/null)

    if [[ "$TASK_STATUS" == "in_progress" || "$TASK_STATUS" == "started" ]] && [[ $TASK_AGE -gt $STUCK_THRESHOLD_MINUTES ]]; then
        TASK_ID=$(basename "$task_file" .json)
        STUCK_COUNT=$((STUCK_COUNT + 1))
        alert "WARNING" "Stuck task detected: $TASK_ID (age: ${TASK_AGE}m, status: $TASK_STATUS)"

        # Mark as stuck and queue for recovery
        jq '.status = "stuck" | .stuck_at = "'$(date -Iseconds)'" | .stuck_age_minutes = '$TASK_AGE "$task_file" > "${task_file}.tmp"
        mv "${task_file}.tmp" "$task_file"
    fi
done
log "Found $STUCK_COUNT stuck tasks"

# Check 2: Stale Heartbeats (workers not responding)
log "Check 2: Checking worker heartbeats"
HEARTBEAT_FILE="${STATE_DIR}/heartbeats.json"
STALE_WORKERS=0

if [[ -f "$HEARTBEAT_FILE" ]]; then
    CURRENT_TIME=$(date +%s)

    # Parse each worker's heartbeat
    while read -r worker; do
        WORKER_ID=$(echo "$worker" | jq -r '.id')
        LAST_BEAT=$(echo "$worker" | jq -r '.last_heartbeat')
        BEAT_EPOCH=$(date -d "$LAST_BEAT" +%s 2>/dev/null || echo "0")
        BEAT_AGE=$(( (CURRENT_TIME - BEAT_EPOCH) / 60 ))

        if [[ $BEAT_AGE -gt $HEARTBEAT_STALE_MINUTES ]]; then
            STALE_WORKERS=$((STALE_WORKERS + 1))
            alert "WARNING" "Stale worker heartbeat: $WORKER_ID (last: ${BEAT_AGE}m ago)"
        fi
    done < <(jq -c '.workers[]' "$HEARTBEAT_FILE" 2>/dev/null || echo "")
fi
log "Found $STALE_WORKERS stale workers"

# Check 3: Semantic Loop Detection (repetitive failures)
log "Check 3: Detecting semantic loops"
ERROR_LOG="${LOG_DIR}/errors.log"
if [[ -f "$ERROR_LOG" ]]; then
    # Count consecutive similar errors in last 10 minutes
    RECENT_ERRORS=$(tail -50 "$ERROR_LOG" | grep -c "TOOL_ERROR" 2>/dev/null || echo "0")

    if [[ $RECENT_ERRORS -gt $MAX_CONSECUTIVE_FAILURES ]]; then
        alert "CRITICAL" "Potential semantic loop detected: $RECENT_ERRORS consecutive errors"

        # Extract error pattern
        ERROR_PATTERN=$(tail -20 "$ERROR_LOG" | grep "TOOL_ERROR" | awk '{print $3}' | sort | uniq -c | sort -rn | head -1)
        alert "INFO" "Most common error: $ERROR_PATTERN"
    fi
fi

# Check 4: Context Overflow Prevention
log "Check 4: Checking context usage"
PROGRESS_FILE="${HOME}/.claude/sessions/claude-progress.txt"
if [[ -f "$PROGRESS_FILE" ]]; then
    # Check if progress file mentions high token usage
    TOKEN_USAGE=$(grep -oP 'tokens.*?(\d+)' "$PROGRESS_FILE" | grep -oP '\d+' | tail -1 || echo "0")
    CONTEXT_LIMIT="${CONTEXT_REFRESH_THRESHOLD:-150000}"

    if [[ $TOKEN_USAGE -gt $CONTEXT_LIMIT ]]; then
        alert "WARNING" "High context usage: $TOKEN_USAGE tokens (threshold: $CONTEXT_LIMIT)"
        alert "INFO" "Consider running session rotation: ~/.claude/scripts/rotate_session.sh"
    fi
fi

# Check 5: Disk Space
log "Check 5: Checking disk space"
DISK_FREE_KB=$(df "${HOME}/.claude" | tail -1 | awk '{print $4}')
DISK_FREE_GB=$((DISK_FREE_KB / 1024 / 1024))
DISK_CRITICAL="${DISK_CRITICAL_THRESHOLD_GB:-2}"
DISK_WARN="${DISK_WARN_THRESHOLD_GB:-5}"

if [[ $DISK_FREE_GB -lt $DISK_CRITICAL ]]; then
    alert "CRITICAL" "Disk space critically low: ${DISK_FREE_GB}GB free"
elif [[ $DISK_FREE_GB -lt $DISK_WARN ]]; then
    alert "WARNING" "Disk space low: ${DISK_FREE_GB}GB free"
fi

# Summary
TOTAL_ISSUES=$((STUCK_COUNT + STALE_WORKERS))
log "Watchdog check completed: $TOTAL_ISSUES issues found"

# Output status
if [[ $TOTAL_ISSUES -gt 0 ]]; then
    echo "WATCHDOG_ALERT: $TOTAL_ISSUES issues detected"
    echo "STUCK_TASKS=$STUCK_COUNT"
    echo "STALE_WORKERS=$STALE_WORKERS"
    exit 1
else
    echo "WATCHDOG_OK"
    exit 0
fi
