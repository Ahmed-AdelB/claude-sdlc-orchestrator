#!/bin/bash
# Hook Cleanup Script - Run via cron, NOT in hot path
# Schedule: 0 3 * * * ~/.claude/scripts/hook-cleanup.sh
# 
# This script handles all cleanup operations that were previously
# running on every hook invocation, causing ~30-50ms overhead per call.

set -uo pipefail

LOG_DIR="${HOME}/.claude/logs"
AUDIT_DIR="${LOG_DIR}/audit"
NOTIFY_DIR="${LOG_DIR}/notifications"
TASK_DIR="${HOME}/.claude/tasks"
SESSION_DIR="${HOME}/.claude/sessions"
CHECKPOINT_DIR="${SESSION_DIR}/checkpoints"

CLEANUP_LOG="${LOG_DIR}/cleanup.log"
TIMESTAMP=$(date -Iseconds)

log() {
    echo "[${TIMESTAMP}] $1" >> "$CLEANUP_LOG"
    echo "$1"
}

log "=== Hook Cleanup Started ==="

# 1. Rotate audit logs (keep 7 days)
if [[ -d "$AUDIT_DIR" ]]; then
    DELETED=$(find "$AUDIT_DIR" -name "audit-*.jsonl" -mtime +7 -delete -print | wc -l)
    log "Deleted $DELETED old audit logs"
fi

# 2. Rotate notification logs (keep 14 days)
if [[ -d "$NOTIFY_DIR" ]]; then
    DELETED=$(find "$NOTIFY_DIR" -name "notifications-*.log" -mtime +14 -delete -print | wc -l)
    log "Deleted $DELETED old notification logs"
fi

# 3. Cleanup old task files (keep last 100)
if [[ -d "$TASK_DIR" ]]; then
    DELETED=$(ls -t "${TASK_DIR}"/task-*.json 2>/dev/null | tail -n +101 | xargs -r rm -fv | wc -l)
    log "Deleted $DELETED old task files"
fi

# 4. Cleanup old auto-checkpoints (keep last 50)
if [[ -d "$CHECKPOINT_DIR" ]]; then
    DELETED=$(ls -t "${CHECKPOINT_DIR}"/auto-checkpoint-*.json 2>/dev/null | tail -n +51 | xargs -r rm -fv | wc -l)
    log "Deleted $DELETED old auto-checkpoints"
fi

# 5. Cleanup old manual checkpoints (keep last 20)
if [[ -d "$CHECKPOINT_DIR" ]]; then
    DELETED=$(ls -t "${CHECKPOINT_DIR}"/checkpoint-*.json 2>/dev/null | tail -n +21 | xargs -r rm -fv | wc -l)
    log "Deleted $DELETED old checkpoints"
fi

# 6. Compress large log files (>50MB)
COMPRESSED=$(find "$LOG_DIR" -name "*.log" -size +50M -exec gzip -v {} \; 2>&1 | wc -l)
log "Compressed $COMPRESSED large log files"

# 7. Remove stale lock files (older than 1 hour)
STALE=$(find "$LOG_DIR" "$SESSION_DIR" -name "*.lock" -mmin +60 -delete -print 2>/dev/null | wc -l)
log "Removed $STALE stale lock files"

# 8. Vacuum tool-stats.json if it exists and is large
STATS_FILE="${LOG_DIR}/tool-stats.json"
if [[ -f "$STATS_FILE" && $(stat -f%z "$STATS_FILE" 2>/dev/null || stat -c%s "$STATS_FILE" 2>/dev/null) -gt 1048576 ]]; then
    # Compact: keep only top 100 tools by count
    jq 'to_entries | sort_by(-.value) | .[0:100] | from_entries' "$STATS_FILE" > "${STATS_FILE}.tmp" && \
    mv "${STATS_FILE}.tmp" "$STATS_FILE"
    log "Compacted tool-stats.json"
fi

# 9. Report disk usage
USAGE=$(du -sh "${HOME}/.claude" 2>/dev/null | cut -f1)
log "Total ~/.claude size: $USAGE"

log "=== Hook Cleanup Completed ==="
