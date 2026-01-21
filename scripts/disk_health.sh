#!/bin/bash
# P4.3: Disk Health Check Script - Part of self-healing system
# Run via cron: */15 * * * * ~/.claude/scripts/disk_health.sh

set -euo pipefail

LOG_DIR="${HOME}/.claude/logs"
STATE_DIR="${HOME}/.claude/state"
ALERT_LOG="${LOG_DIR}/disk-health.log"

mkdir -p "$LOG_DIR" "$STATE_DIR"

log() {
    echo "[$(date -Iseconds)] $*" >> "$ALERT_LOG"
}

alert() {
    local level="$1"
    local message="$2"
    echo "[$(date -Iseconds)] [$level] $message" >> "$ALERT_LOG"

    if [[ "$level" == "CRITICAL" ]] && command -v notify-send &>/dev/null; then
        notify-send -u critical "Disk Health Alert" "$message"
    fi
}

# Configuration
DISK_CRITICAL_GB="${DISK_CRITICAL_THRESHOLD_GB:-2}"
DISK_WARN_GB="${DISK_WARN_THRESHOLD_GB:-5}"
INODE_WARN_PERCENT="${INODE_WARN_PERCENT:-90}"
IO_WAIT_WARN="${IO_WAIT_WARN_PERCENT:-50}"

log "Disk health check started"

# Check 1: Free Space
log "Check 1: Disk space"
CLAUDE_DIR="${HOME}/.claude"
DISK_INFO=$(df -B1G "$CLAUDE_DIR" | tail -1)
DISK_TOTAL=$(echo "$DISK_INFO" | awk '{print $2}')
DISK_USED=$(echo "$DISK_INFO" | awk '{print $3}')
DISK_FREE=$(echo "$DISK_INFO" | awk '{print $4}')
DISK_PERCENT=$(echo "$DISK_INFO" | awk '{print $5}' | tr -d '%')

log "Disk usage: ${DISK_USED}GB / ${DISK_TOTAL}GB (${DISK_PERCENT}%)"

if [[ $DISK_FREE -lt $DISK_CRITICAL_GB ]]; then
    alert "CRITICAL" "Disk space critical: ${DISK_FREE}GB free (threshold: ${DISK_CRITICAL_GB}GB)"

    # Emergency cleanup
    log "Initiating emergency cleanup..."

    # Remove old audit logs
    find "${LOG_DIR}/audit" -name "*.jsonl" -mtime +7 -delete 2>/dev/null || true

    # Compress large logs
    find "$LOG_DIR" -name "*.log" -size +10M -exec gzip {} \; 2>/dev/null || true

    # Remove old checkpoints
    find "${HOME}/.claude/sessions/checkpoints" -name "*.json" -mtime +1 -delete 2>/dev/null || true

    # Report new free space
    NEW_FREE=$(df -BG "$CLAUDE_DIR" | tail -1 | awk '{print $4}' | tr -d 'G')
    log "After cleanup: ${NEW_FREE}GB free"

elif [[ $DISK_FREE -lt $DISK_WARN_GB ]]; then
    alert "WARNING" "Disk space low: ${DISK_FREE}GB free"
fi

# Check 2: Inode Usage
log "Check 2: Inode usage"
INODE_INFO=$(df -i "$CLAUDE_DIR" | tail -1)
INODE_PERCENT=$(echo "$INODE_INFO" | awk '{print $5}' | tr -d '%')

if [[ $INODE_PERCENT -gt $INODE_WARN_PERCENT ]]; then
    alert "WARNING" "Inode usage high: ${INODE_PERCENT}%"

    # Count files in common directories
    log "File counts:"
    for dir in logs tasks sessions state; do
        if [[ -d "${CLAUDE_DIR}/$dir" ]]; then
            COUNT=$(find "${CLAUDE_DIR}/$dir" -type f 2>/dev/null | wc -l)
            log "  $dir: $COUNT files"
        fi
    done
fi

# Check 3: Directory Sizes
log "Check 3: Directory sizes"
echo "Directory sizes:" >> "$ALERT_LOG"
du -sh "${CLAUDE_DIR}"/* 2>/dev/null | sort -rh | head -10 >> "$ALERT_LOG"

# Check 4: SQLite Database Health
log "Check 4: SQLite database health"
for db in "${STATE_DIR}"/*.db; do
    [[ -f "$db" ]] || continue

    DB_NAME=$(basename "$db")
    DB_SIZE=$(stat -c %s "$db" 2>/dev/null || echo "0")
    DB_SIZE_MB=$((DB_SIZE / 1024 / 1024))

    # Check integrity
    if command -v sqlite3 &>/dev/null; then
        INTEGRITY=$(sqlite3 "$db" "PRAGMA integrity_check;" 2>/dev/null || echo "error")
        if [[ "$INTEGRITY" != "ok" ]]; then
            alert "WARNING" "SQLite integrity issue in $DB_NAME: $INTEGRITY"
        fi

        # Check for WAL file bloat
        WAL_FILE="${db}-wal"
        if [[ -f "$WAL_FILE" ]]; then
            WAL_SIZE=$(stat -c %s "$WAL_FILE" 2>/dev/null || echo "0")
            WAL_SIZE_MB=$((WAL_SIZE / 1024 / 1024))

            if [[ $WAL_SIZE_MB -gt 100 ]]; then
                alert "WARNING" "Large WAL file for $DB_NAME: ${WAL_SIZE_MB}MB"
                log "Running WAL checkpoint..."
                sqlite3 "$db" "PRAGMA wal_checkpoint(TRUNCATE);" 2>/dev/null || true
            fi
        fi

        log "$DB_NAME: ${DB_SIZE_MB}MB, integrity: $INTEGRITY"
    fi
done

# Check 5: Log File Rotation Check
log "Check 5: Large log files"
LARGE_LOGS=$(find "$LOG_DIR" -name "*.log" -size +50M 2>/dev/null)
if [[ -n "$LARGE_LOGS" ]]; then
    alert "INFO" "Large log files detected, compressing..."
    echo "$LARGE_LOGS" | while read -r logfile; do
        log "Compressing: $logfile"
        gzip "$logfile" 2>/dev/null || true
    done
fi

# Check 6: IO Wait (if iostat available)
log "Check 6: IO wait"
if command -v iostat &>/dev/null; then
    IO_WAIT=$(iostat -c 1 2 | tail -1 | awk '{print $4}' | cut -d'.' -f1)
    if [[ $IO_WAIT -gt $IO_WAIT_WARN ]]; then
        alert "WARNING" "High IO wait: ${IO_WAIT}%"
    fi
    log "IO wait: ${IO_WAIT}%"
fi

# Summary
log "Disk health check completed"
echo "DISK_FREE_GB=$DISK_FREE"
echo "DISK_PERCENT=$DISK_PERCENT"
echo "INODE_PERCENT=$INODE_PERCENT"
