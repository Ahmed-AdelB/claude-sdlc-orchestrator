#!/bin/bash
# ~/.claude/scripts/cleanup.sh
# Tri-Agent System Data Retention & Cleanup Script
#
# Run via cron: 0 3 * * * ~/.claude/scripts/cleanup.sh
# Manual run:   ~/.claude/scripts/cleanup.sh [--dry-run] [--verbose]
#
# =============================================================================
# DATA RETENTION POLICIES (from CLAUDE.md)
# =============================================================================
# | Data Type       | Retention  | Cleanup Freq | Location                    |
# |-----------------|------------|--------------|------------------------------|
# | Audit Logs      | 30 days    | Daily        | ~/.claude/logs/audit/        |
# | Session Logs    | 7 days     | Daily        | ~/.claude/logs/sessions.log  |
# | Checkpoints     | 3 days     | Every 8 hrs  | ~/.claude/sessions/checkpoints/|
# | Snapshots       | 7 days     | Daily        | ~/.claude/sessions/snapshots/|
# | Task Files      | 14 days    | Daily        | ~/.claude/tasks/             |
# | Metrics         | 90 days    | Weekly       | ~/.claude/metrics/           |
# | Backups         | 30 days    | Daily        | ~/.claude/backups/           |
# | Debug Logs      | 7 days     | Daily        | ~/.claude/debug/             |
# | Shell Snapshots | 7 days     | Daily        | ~/.claude/shell-snapshots/   |
# | Queue Files     | 3 days     | Daily        | ~/.claude/queue/             |
# | Session Env     | 7 days     | Daily        | ~/.claude/session-env/       |
# | Handoffs        | 14 days    | Daily        | ~/.claude/handoffs/          |
# | Telemetry       | 30 days    | Daily        | ~/.claude/telemetry/         |
# | File History    | 30 days    | Daily        | ~/.claude/file-history/      |
# =============================================================================

set -uo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================
CLAUDE_DIR="${HOME}/.claude"
LOG_DIR="${CLAUDE_DIR}/logs"
SESSION_DIR="${CLAUDE_DIR}/sessions"
STATE_DIR="${CLAUDE_DIR}/state"
TASKS_DIR="${CLAUDE_DIR}/tasks"
METRICS_DIR="${CLAUDE_DIR}/metrics"
BACKUPS_DIR="${CLAUDE_DIR}/backups"
DEBUG_DIR="${CLAUDE_DIR}/debug"
SHELL_SNAPSHOTS_DIR="${CLAUDE_DIR}/shell-snapshots"
QUEUE_DIR="${CLAUDE_DIR}/queue"
SESSION_ENV_DIR="${CLAUDE_DIR}/session-env"
HANDOFFS_DIR="${CLAUDE_DIR}/handoffs"
TELEMETRY_DIR="${CLAUDE_DIR}/telemetry"
FILE_HISTORY_DIR="${CLAUDE_DIR}/file-history"

# Lock file for preventing concurrent runs
LOCK_FILE="${CLAUDE_DIR}/.cleanup.lock"
LOCK_TIMEOUT=3600  # 1 hour max lock age before stale

# Disk space thresholds (from CLAUDE.md)
DISK_WARN_THRESHOLD_GB=5
DISK_CRITICAL_THRESHOLD_GB=2

# Log rotation threshold
LOG_ROTATE_SIZE_MB=50

# Command line options
DRY_RUN=false
VERBOSE=false

# Counters for summary
declare -A CLEANUP_STATS=(
    [files_deleted]=0
    [files_compressed]=0
    [bytes_freed]=0
    [databases_vacuumed]=0
    [errors]=0
)

# Exit codes
EXIT_SUCCESS=0
EXIT_LOCK_FAILED=1
EXIT_CRITICAL_DISK=2
EXIT_PARTIAL_FAILURE=3

# =============================================================================
# PARSE ARGUMENTS
# =============================================================================
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run|-n)
                DRY_RUN=true
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Tri-Agent System Data Retention & Cleanup Script

Options:
    -n, --dry-run    Show what would be deleted without actually deleting
    -v, --verbose    Enable verbose output
    -h, --help       Show this help message

Cron setup (run daily at 3 AM):
    0 3 * * * ${HOME}/.claude/scripts/cleanup.sh >> ${LOG_DIR}/cleanup.log 2>&1

Exit codes:
    0 - Success
    1 - Failed to acquire lock
    2 - Critical disk space
    3 - Partial failure (some operations failed)
EOF
}

# =============================================================================
# LOGGING & NOTIFICATIONS
# =============================================================================
TIMESTAMP=$(date -Iseconds)
CLEANUP_LOG="${LOG_DIR}/cleanup.log"

log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date -Iseconds)
    local log_line="[${timestamp}] [${level}] ${message}"

    echo "$log_line"

    # Append to cleanup log
    if [[ -d "$LOG_DIR" ]]; then
        echo "$log_line" >> "$CLEANUP_LOG"
    fi
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        log "DEBUG" "$1"
    fi
}

# Send notification based on alerts.conf
send_notification() {
    local level="$1"
    local title="$2"
    local message="$3"
    local alerts_conf="${CLAUDE_DIR}/alerts.conf"

    # Source alerts config if exists
    if [[ -f "$alerts_conf" ]]; then
        # shellcheck source=/dev/null
        source "$alerts_conf"
    else
        return 0
    fi

    # Desktop notification
    if [[ "${DESKTOP_NOTIFY_ENABLED:-false}" == "true" ]] && command -v notify-send &>/dev/null; then
        local urgency="normal"
        [[ "$level" == "CRITICAL" ]] && urgency="critical"
        [[ "$level" == "WARNING" ]] && urgency="normal"
        notify-send -u "$urgency" "$title" "$message" 2>/dev/null || true
    fi

    # Sound for critical alerts
    if [[ "${SOUND_ENABLED:-false}" == "true" ]] && [[ "$level" == "CRITICAL" ]]; then
        if command -v paplay &>/dev/null; then
            paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null || true
        elif command -v aplay &>/dev/null; then
            aplay /usr/share/sounds/alsa/Front_Center.wav 2>/dev/null || true
        fi
    fi

    # Slack webhook
    if [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
        curl -s -X POST "$SLACK_WEBHOOK_URL" \
            -H 'Content-Type: application/json' \
            -d "{\"text\":\"[${level}] ${title}: ${message}\"}" 2>/dev/null || true
    fi

    # Email notification
    if [[ -n "${ALERT_EMAIL:-}" ]] && command -v msmtp &>/dev/null; then
        echo -e "Subject: Tri-Agent Cleanup Alert: ${title}\n\n${message}" | \
            msmtp "$ALERT_EMAIL" 2>/dev/null || true
    fi
}

# =============================================================================
# LOCK MANAGEMENT
# =============================================================================
acquire_lock() {
    local lock_dir
    lock_dir=$(dirname "$LOCK_FILE")
    mkdir -p "$lock_dir" 2>/dev/null || true

    # Check for stale lock
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_age
        lock_age=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0) ))

        if [[ $lock_age -gt $LOCK_TIMEOUT ]]; then
            log "WARNING" "Removing stale lock file (age: ${lock_age}s)"
            rm -f "$LOCK_FILE"
        else
            local lock_pid
            lock_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "unknown")
            log "ERROR" "Another cleanup is running (PID: ${lock_pid}, age: ${lock_age}s)"
            return 1
        fi
    fi

    # Create lock
    echo $$ > "$LOCK_FILE"
    log_verbose "Lock acquired (PID: $$)"
    return 0
}

release_lock() {
    rm -f "$LOCK_FILE"
    log_verbose "Lock released"
}

# =============================================================================
# DISK SPACE MANAGEMENT
# =============================================================================
check_disk_space() {
    if [[ ! -d "$CLAUDE_DIR" ]]; then
        return 0
    fi

    local available_gb
    available_gb=$(df -BG "$CLAUDE_DIR" 2>/dev/null | awk 'NR==2 {print $4}' | tr -d 'G')

    if [[ -z "$available_gb" ]]; then
        log "WARNING" "Could not determine disk space"
        return 0
    fi

    if [[ "$available_gb" -lt "$DISK_CRITICAL_THRESHOLD_GB" ]]; then
        log "CRITICAL" "Disk space critically low: ${available_gb}GB available (threshold: ${DISK_CRITICAL_THRESHOLD_GB}GB)"
        send_notification "CRITICAL" "Disk Space Critical" "Only ${available_gb}GB available on .claude partition"
        return 1
    elif [[ "$available_gb" -lt "$DISK_WARN_THRESHOLD_GB" ]]; then
        log "WARNING" "Disk space low: ${available_gb}GB available (threshold: ${DISK_WARN_THRESHOLD_GB}GB)"
        send_notification "WARNING" "Disk Space Warning" "${available_gb}GB available on .claude partition"
    else
        log "INFO" "Disk space OK: ${available_gb}GB available"
    fi

    return 0
}

get_file_size() {
    local file="$1"
    stat -c%s "$file" 2>/dev/null || echo 0
}

# =============================================================================
# DIRECTORY MANAGEMENT
# =============================================================================
ensure_directories() {
    local dirs=(
        "$LOG_DIR"
        "${LOG_DIR}/audit"
        "${SESSION_DIR}/checkpoints"
        "${SESSION_DIR}/snapshots"
        "$STATE_DIR"
        "$METRICS_DIR"
    )

    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                log_verbose "Would create directory: $dir"
            else
                mkdir -p "$dir"
                log_verbose "Created directory: $dir"
            fi
        fi
    done
}

# =============================================================================
# CLEANUP FUNCTIONS
# =============================================================================

# Generic cleanup function for a directory with retention policy
cleanup_directory() {
    local dir="$1"
    local days="$2"
    local pattern="${3:-*}"
    local description="$4"

    log "INFO" "Cleaning up ${description} older than ${days} days..."

    if [[ ! -d "$dir" ]]; then
        log_verbose "Directory does not exist: $dir"
        return 0
    fi

    local count=0
    local bytes=0

    while IFS= read -r -d '' file; do
        local size
        size=$(get_file_size "$file")

        if [[ "$DRY_RUN" == "true" ]]; then
            log_verbose "Would delete: $file ($(numfmt --to=iec "$size" 2>/dev/null || echo "${size}B"))"
        else
            if rm -f "$file" 2>/dev/null; then
                ((bytes += size))
                log_verbose "Deleted: $file"
            else
                log "WARNING" "Failed to delete: $file"
                ((CLEANUP_STATS[errors]++))
            fi
        fi
        ((count++))
    done < <(find "$dir" -maxdepth 1 -type f -name "$pattern" -mtime +"$days" -print0 2>/dev/null)

    # Also handle subdirectories if needed
    while IFS= read -r -d '' file; do
        local size
        size=$(get_file_size "$file")

        if [[ "$DRY_RUN" == "true" ]]; then
            log_verbose "Would delete: $file"
        else
            if rm -f "$file" 2>/dev/null; then
                ((bytes += size))
                log_verbose "Deleted: $file"
            else
                log "WARNING" "Failed to delete: $file"
                ((CLEANUP_STATS[errors]++))
            fi
        fi
        ((count++))
    done < <(find "$dir" -mindepth 2 -type f -name "$pattern" -mtime +"$days" -print0 2>/dev/null)

    # Remove empty subdirectories
    if [[ "$DRY_RUN" != "true" ]]; then
        find "$dir" -mindepth 1 -type d -empty -delete 2>/dev/null || true
    fi

    ((CLEANUP_STATS[files_deleted] += count))
    ((CLEANUP_STATS[bytes_freed] += bytes))

    local human_size
    human_size=$(numfmt --to=iec "$bytes" 2>/dev/null || echo "${bytes}B")
    log "INFO" "Deleted ${count} ${description} files (${human_size} freed)"
}

# Rotate logs larger than threshold
rotate_large_logs() {
    log "INFO" "Rotating logs larger than ${LOG_ROTATE_SIZE_MB}MB..."

    if [[ ! -d "$LOG_DIR" ]]; then
        log_verbose "Log directory does not exist: $LOG_DIR"
        return 0
    fi

    local count=0
    local bytes_saved=0

    while IFS= read -r -d '' file; do
        local original_size
        original_size=$(get_file_size "$file")

        if [[ "$DRY_RUN" == "true" ]]; then
            log_verbose "Would compress: $file ($(numfmt --to=iec "$original_size" 2>/dev/null))"
            ((count++))
        else
            if gzip -f "$file" 2>/dev/null; then
                local new_size
                new_size=$(get_file_size "${file}.gz")
                local saved=$((original_size - new_size))
                ((bytes_saved += saved))
                ((count++))
                log_verbose "Compressed: $file (saved $(numfmt --to=iec "$saved" 2>/dev/null))"
            else
                log "WARNING" "Failed to compress: $file"
                ((CLEANUP_STATS[errors]++))
            fi
        fi
    done < <(find "$LOG_DIR" -name "*.log" -size +"${LOG_ROTATE_SIZE_MB}M" -print0 2>/dev/null)

    ((CLEANUP_STATS[files_compressed] += count))
    ((CLEANUP_STATS[bytes_freed] += bytes_saved))

    log "INFO" "Compressed ${count} log files ($(numfmt --to=iec "$bytes_saved" 2>/dev/null) saved)"
}

# Cleanup audit logs (30 days uncompressed, 90 days compressed)
cleanup_audit_logs() {
    local audit_dir="${LOG_DIR}/audit"

    log "INFO" "Cleaning up audit logs..."

    if [[ ! -d "$audit_dir" ]]; then
        log_verbose "Audit log directory does not exist: $audit_dir"
        return 0
    fi

    # Delete .jsonl files older than 30 days
    local jsonl_count=0
    local jsonl_bytes=0
    while IFS= read -r -d '' file; do
        local size
        size=$(get_file_size "$file")
        if [[ "$DRY_RUN" == "true" ]]; then
            log_verbose "Would delete: $file"
        else
            rm -f "$file" && ((jsonl_bytes += size))
        fi
        ((jsonl_count++))
    done < <(find "$audit_dir" -name "*.jsonl" -mtime +30 -print0 2>/dev/null)

    log "INFO" "Deleted ${jsonl_count} audit log files older than 30 days"

    # Delete compressed audit logs older than 90 days
    local gz_count=0
    local gz_bytes=0
    while IFS= read -r -d '' file; do
        local size
        size=$(get_file_size "$file")
        if [[ "$DRY_RUN" == "true" ]]; then
            log_verbose "Would delete: $file"
        else
            rm -f "$file" && ((gz_bytes += size))
        fi
        ((gz_count++))
    done < <(find "$audit_dir" -name "*.jsonl.gz" -mtime +90 -print0 2>/dev/null)

    log "INFO" "Deleted ${gz_count} compressed audit log files older than 90 days"

    ((CLEANUP_STATS[files_deleted] += jsonl_count + gz_count))
    ((CLEANUP_STATS[bytes_freed] += jsonl_bytes + gz_bytes))
}

# Cleanup session logs file (rotate if old)
cleanup_session_logs() {
    local session_log="${LOG_DIR}/sessions.log"

    log "INFO" "Cleaning up session logs..."

    if [[ ! -f "$session_log" ]]; then
        log_verbose "Session log file does not exist: $session_log"
        return 0
    fi

    # Check if file is older than 7 days
    local file_age
    file_age=$(( ($(date +%s) - $(stat -c %Y "$session_log" 2>/dev/null || echo $(date +%s))) / 86400 ))

    if [[ $file_age -gt 7 ]]; then
        local size
        size=$(get_file_size "$session_log")

        if [[ "$DRY_RUN" == "true" ]]; then
            log_verbose "Would archive and truncate: $session_log (age: ${file_age} days)"
        else
            # Archive old log with timestamp
            local archive_name="sessions.log.$(date +%Y%m%d%H%M%S)"
            mv "$session_log" "${LOG_DIR}/${archive_name}"
            gzip "${LOG_DIR}/${archive_name}" 2>/dev/null || true
            touch "$session_log"
            log "INFO" "Archived session log (${file_age} days old)"
            ((CLEANUP_STATS[bytes_freed] += size))
        fi
    fi

    # Also cleanup old archived session logs (older than 30 days)
    cleanup_directory "$LOG_DIR" 30 "sessions.log.*.gz" "archived session logs"
}

# Vacuum SQLite databases
vacuum_databases() {
    log "INFO" "Vacuuming SQLite databases..."

    if [[ ! -d "$STATE_DIR" ]]; then
        log_verbose "State directory does not exist: $STATE_DIR"
        return 0
    fi

    if ! command -v sqlite3 &>/dev/null; then
        log "WARNING" "sqlite3 not found, skipping database vacuum"
        return 0
    fi

    local count=0
    local total_saved=0

    for db in "${STATE_DIR}"/*.db; do
        if [[ -f "$db" ]]; then
            local before_size
            before_size=$(get_file_size "$db")

            if [[ "$DRY_RUN" == "true" ]]; then
                log_verbose "Would vacuum: $db"
                ((count++))
            else
                if sqlite3 "$db" "VACUUM; PRAGMA wal_checkpoint(TRUNCATE);" 2>/dev/null; then
                    local after_size
                    after_size=$(get_file_size "$db")
                    local saved=$((before_size - after_size))
                    ((total_saved += saved > 0 ? saved : 0))
                    ((count++))
                    log_verbose "Vacuumed: $db (saved $(numfmt --to=iec "$saved" 2>/dev/null))"
                else
                    log "WARNING" "Failed to vacuum: $db"
                    ((CLEANUP_STATS[errors]++))
                fi
            fi
        fi
    done

    ((CLEANUP_STATS[databases_vacuumed] += count))
    ((CLEANUP_STATS[bytes_freed] += total_saved))

    log "INFO" "Vacuumed ${count} databases ($(numfmt --to=iec "$total_saved" 2>/dev/null) freed)"
}

# Report disk usage
report_disk_usage() {
    log "INFO" "Generating disk usage report..."

    local disk_log="${LOG_DIR}/disk-usage.log"
    local timestamp
    timestamp=$(date -Iseconds)

    if [[ ! -d "$CLAUDE_DIR" ]]; then
        log "WARNING" "Claude directory does not exist: $CLAUDE_DIR"
        return 0
    fi

    local total_size
    total_size=$(du -sh "$CLAUDE_DIR" 2>/dev/null | cut -f1)

    log "INFO" "Total .claude directory size: ${total_size}"

    if [[ "$DRY_RUN" != "true" ]] && [[ -d "$LOG_DIR" ]]; then
        {
            echo "===== Disk Usage Report: ${timestamp} ====="
            echo "Total: ${total_size}"
            echo ""
            echo "Breakdown:"
            du -sh "${CLAUDE_DIR}"/*/ 2>/dev/null | sort -hr | head -20
            echo ""
        } >> "$disk_log"
    fi

    # Show breakdown in verbose mode
    if [[ "$VERBOSE" == "true" ]]; then
        log "INFO" "Detailed breakdown:"
        for dir in logs sessions state tasks metrics backups debug shell-snapshots queue; do
            if [[ -d "${CLAUDE_DIR}/${dir}" ]]; then
                local dir_size
                dir_size=$(du -sh "${CLAUDE_DIR}/${dir}" 2>/dev/null | cut -f1)
                log "INFO" "  ${dir}: ${dir_size}"
            fi
        done
    fi
}

# Generate cleanup summary
generate_summary() {
    local end_time
    end_time=$(date -Iseconds)

    local bytes_human
    bytes_human=$(numfmt --to=iec "${CLEANUP_STATS[bytes_freed]}" 2>/dev/null || echo "${CLEANUP_STATS[bytes_freed]}B")

    log "INFO" "=========================================="
    log "INFO" "CLEANUP SUMMARY"
    log "INFO" "=========================================="
    log "INFO" "Files deleted:    ${CLEANUP_STATS[files_deleted]}"
    log "INFO" "Files compressed: ${CLEANUP_STATS[files_compressed]}"
    log "INFO" "DBs vacuumed:     ${CLEANUP_STATS[databases_vacuumed]}"
    log "INFO" "Space freed:      ${bytes_human}"
    log "INFO" "Errors:           ${CLEANUP_STATS[errors]}"
    log "INFO" "Mode:             $([ "$DRY_RUN" == "true" ] && echo "DRY RUN" || echo "LIVE")"
    log "INFO" "Completed:        ${end_time}"
    log "INFO" "=========================================="

    # Send notification if there were errors
    if [[ ${CLEANUP_STATS[errors]} -gt 0 ]]; then
        send_notification "WARNING" "Cleanup Completed with Errors" \
            "${CLEANUP_STATS[errors]} errors occurred. Check ${CLEANUP_LOG}"
    fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================
main() {
    parse_args "$@"

    log "INFO" "=========================================="
    log "INFO" "Starting cleanup at ${TIMESTAMP}"
    [[ "$DRY_RUN" == "true" ]] && log "INFO" "*** DRY RUN MODE - No files will be deleted ***"
    log "INFO" "=========================================="

    # Acquire lock (skip lock for dry run)
    if [[ "$DRY_RUN" != "true" ]]; then
        if ! acquire_lock; then
            exit $EXIT_LOCK_FAILED
        fi
        trap release_lock EXIT
    fi

    # Ensure base directories exist
    ensure_directories

    # Check disk space first
    if ! check_disk_space; then
        log "CRITICAL" "Aborting due to critical disk space"
        exit $EXIT_CRITICAL_DISK
    fi

    # =========================================================================
    # Execute cleanup tasks (ordered by priority/impact)
    # =========================================================================

    # 1. Rotate large logs first to free immediate space
    rotate_large_logs

    # 2. Short retention items (3 days)
    cleanup_directory "${SESSION_DIR}/checkpoints" 3 "*.json" "checkpoints"
    cleanup_directory "$QUEUE_DIR" 3 "*" "queue files"

    # 3. Weekly retention items (7 days)
    cleanup_directory "${SESSION_DIR}/snapshots" 7 "*.json" "snapshots"
    cleanup_session_logs
    cleanup_directory "$DEBUG_DIR" 7 "*" "debug files"
    cleanup_directory "$SHELL_SNAPSHOTS_DIR" 7 "*" "shell snapshots"
    cleanup_directory "$SESSION_ENV_DIR" 7 "*" "session environment files"

    # 4. Bi-weekly retention items (14 days)
    cleanup_directory "$TASKS_DIR" 14 "*" "task files"
    cleanup_directory "$HANDOFFS_DIR" 14 "*" "handoff files"

    # 5. Monthly retention items (30 days)
    cleanup_audit_logs
    cleanup_directory "$BACKUPS_DIR" 30 "*" "backup files"
    cleanup_directory "$TELEMETRY_DIR" 30 "*" "telemetry files"
    cleanup_directory "$FILE_HISTORY_DIR" 30 "*" "file history"

    # 6. Quarterly retention items (90 days)
    cleanup_directory "$METRICS_DIR" 90 "*" "metrics"

    # 7. Database maintenance
    vacuum_databases

    # 8. Final reporting
    report_disk_usage

    # Final disk space check
    check_disk_space || true

    # Generate summary
    generate_summary

    # Determine exit code
    if [[ ${CLEANUP_STATS[errors]} -gt 0 ]]; then
        exit $EXIT_PARTIAL_FAILURE
    fi

    exit $EXIT_SUCCESS
}

# Run main function
main "$@"
