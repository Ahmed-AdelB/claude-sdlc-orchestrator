#!/bin/bash
# ==============================================================================
# Tri-Agent Automated Storage Cleanup System
# ==============================================================================
# Version: 1.1.0
# Author: Ahmed Adel Bakr Alderai
# Created: 2026-01-21
# Updated: 2026-01-21 - Fixed protected patterns to allow cleanup of temp files
#
# RETENTION POLICIES (from CLAUDE.md - STRICTLY ENFORCED):
# | Data Type     | Retention  | Cleanup Freq | Location                       |
# |---------------|------------|--------------|--------------------------------|
# | Audit Logs    | 365 days   | Weekly       | ~/.claude/logs/audit/          |
# | Session Logs  | 7 days     | Daily        | ~/.claude/logs/sessions.log    |
# | Checkpoints   | 3 days     | Every 8 hrs  | ~/.claude/sessions/checkpoints/|
# | Snapshots     | 7 days     | Daily        | ~/.claude/sessions/snapshots/  |
# | Task Files    | 14 days    | Daily        | ~/.claude/tasks/               |
# | Metrics       | 90 days    | Weekly       | ~/.claude/metrics/             |
# | Backups       | 30 days    | Daily        | ~/.claude/backups/             |
# ==============================================================================
#
# SAFETY FEATURES:
# - Lock file prevents concurrent execution
# - Dry-run mode for testing
# - Pre-deletion validation (path sanity checks)
# - Protected patterns (never delete credentials, configs)
# - Minimum file age validation
# - Disk space monitoring with alerts
# - Detailed audit logging
# ==============================================================================
#
# USAGE:
#   ./auto-cleanup.sh [OPTIONS]
#
# OPTIONS:
#   -n, --dry-run      Show what would be deleted without deleting
#   -v, --verbose      Enable verbose output
#   -f, --force        Skip confirmation prompts
#   -q, --quiet        Suppress non-error output
#   --check-disk       Only check disk space and exit
#   --monitor          Run in monitoring mode (check disk, report status)
#   -h, --help         Show this help message
#
# CRON SETUP (add to crontab -e):
#   # Daily cleanup at 3 AM
#   0 3 * * * /home/aadel/.claude/scripts/auto-cleanup.sh >> /home/aadel/.claude/logs/auto-cleanup.log 2>&1
#
#   # Disk space monitoring every 4 hours
#   0 */4 * * * /home/aadel/.claude/scripts/auto-cleanup.sh --monitor >> /home/aadel/.claude/logs/disk-monitor.log 2>&1
#
# ==============================================================================

set -uo pipefail

# ==============================================================================
# CONFIGURATION - RETENTION POLICIES (days)
# ==============================================================================
readonly RETENTION_AUDIT_LOGS=365
readonly RETENTION_SESSION_LOGS=7
readonly RETENTION_CHECKPOINTS=3
readonly RETENTION_SNAPSHOTS=7
readonly RETENTION_TASK_FILES=14
readonly RETENTION_METRICS=90
readonly RETENTION_BACKUPS=30

# Extended retention for additional directories
readonly RETENTION_DEBUG=7
readonly RETENTION_SHELL_SNAPSHOTS=7
readonly RETENTION_QUEUE=3
readonly RETENTION_SESSION_ENV=7
readonly RETENTION_HANDOFFS=14
readonly RETENTION_TELEMETRY=30
readonly RETENTION_FILE_HISTORY=30
readonly RETENTION_24HR_RESULTS=7

# ==============================================================================
# DIRECTORY PATHS
# ==============================================================================
readonly CLAUDE_DIR="${HOME}/.claude"
readonly LOG_DIR="${CLAUDE_DIR}/logs"
readonly AUDIT_LOG_DIR="${LOG_DIR}/audit"
readonly SESSION_DIR="${CLAUDE_DIR}/sessions"
readonly CHECKPOINT_DIR="${SESSION_DIR}/checkpoints"
readonly SNAPSHOT_DIR="${SESSION_DIR}/snapshots"
readonly STATE_DIR="${CLAUDE_DIR}/state"
readonly TASKS_DIR="${CLAUDE_DIR}/tasks"
readonly METRICS_DIR="${CLAUDE_DIR}/metrics"
readonly BACKUPS_DIR="${CLAUDE_DIR}/backups"
readonly DEBUG_DIR="${CLAUDE_DIR}/debug"
readonly SHELL_SNAPSHOTS_DIR="${CLAUDE_DIR}/shell-snapshots"
readonly QUEUE_DIR="${CLAUDE_DIR}/queue"
readonly SESSION_ENV_DIR="${CLAUDE_DIR}/session-env"
readonly HANDOFFS_DIR="${CLAUDE_DIR}/handoffs"
readonly TELEMETRY_DIR="${CLAUDE_DIR}/telemetry"
readonly FILE_HISTORY_DIR="${CLAUDE_DIR}/file-history"
readonly RESULTS_24HR_DIR="${CLAUDE_DIR}/24hr-results"

# ==============================================================================
# SAFETY CONFIGURATION
# ==============================================================================
readonly LOCK_FILE="${CLAUDE_DIR}/.auto-cleanup.lock"
readonly LOCK_TIMEOUT=3600  # 1 hour max lock age
readonly CLEANUP_AUDIT_LOG="${LOG_DIR}/auto-cleanup-audit.jsonl"

# Disk space thresholds (GB)
readonly DISK_WARN_GB=5
readonly DISK_CRITICAL_GB=2
readonly DISK_EMERGENCY_GB=1

# Log rotation threshold (MB)
readonly LOG_ROTATE_SIZE_MB=50

# Protected file names (exact match) - NEVER delete these specific files
readonly -a PROTECTED_FILES=(
    ".credentials.json"
    "credentials.json"
    "oauth_creds.json"
    "settings.json"
    "config.toml"
    "config.json"
    ".mcp.json"
    ".mcp.json.backup-consolidated"
    ".gitignore"
    "CLAUDE.md"
    "README.md"
    "alerts.conf"
    "degradation.conf"
)

# Protected file patterns (glob match) - NEVER delete files matching these
readonly -a PROTECTED_PATTERNS=(
    "*.key"
    "*.pem"
    "*.gpg"
    "*.gpg-pass"
    "*.secret"
    "*.credentials"
    ".credentials*"
    "oauth*"
)

# Protected directories - NEVER delete content from these
readonly -a PROTECTED_DIRS=(
    "${CLAUDE_DIR}/rules"
    "${CLAUDE_DIR}/context"
    "${CLAUDE_DIR}/docs"
    "${CLAUDE_DIR}/agents"
    "${CLAUDE_DIR}/skills"
    "${CLAUDE_DIR}/.git"
    "${CLAUDE_DIR}/.github"
    "${CLAUDE_DIR}/.local-backup"
)

# Directories where JSON files can be safely cleaned (data/cache directories)
readonly -a CLEANABLE_DATA_DIRS=(
    "${CHECKPOINT_DIR}"
    "${SNAPSHOT_DIR}"
    "${QUEUE_DIR}"
    "${SESSION_ENV_DIR}"
    "${HANDOFFS_DIR}"
    "${TELEMETRY_DIR}"
    "${FILE_HISTORY_DIR}"
    "${RESULTS_24HR_DIR}"
    "${DEBUG_DIR}"
    "${TASKS_DIR}"
    "${METRICS_DIR}"
)

# ==============================================================================
# COMMAND LINE OPTIONS
# ==============================================================================
DRY_RUN=false
VERBOSE=false
FORCE=false
QUIET=false
CHECK_DISK_ONLY=false
MONITOR_MODE=false

# ==============================================================================
# STATISTICS TRACKING
# ==============================================================================
declare -A STATS=(
    [files_deleted]=0
    [files_compressed]=0
    [bytes_freed]=0
    [dirs_cleaned]=0
    [dbs_vacuumed]=0
    [errors]=0
    [skipped_protected]=0
)

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_LOCK_FAILED=1
readonly EXIT_CRITICAL_DISK=2
readonly EXIT_PARTIAL_FAILURE=3
readonly EXIT_INVALID_ARGS=4

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

# Get current timestamp in ISO format
timestamp() {
    date -Iseconds
}

# Log message with level
log() {
    local level="$1"
    local message="$2"
    local ts
    ts=$(timestamp)

    # Skip INFO messages in quiet mode
    [[ "$QUIET" == "true" && "$level" == "INFO" ]] && return

    local log_line="[${ts}] [${level}] ${message}"
    echo "$log_line"

    # Append to cleanup audit log (JSON format)
    if [[ -d "$(dirname "$CLEANUP_AUDIT_LOG")" ]]; then
        printf '{"ts":"%s","level":"%s","msg":"%s"}\n' "$ts" "$level" "${message//\"/\\\"}" >> "$CLEANUP_AUDIT_LOG"
    fi
}

log_verbose() {
    [[ "$VERBOSE" == "true" ]] && log "DEBUG" "$1"
}

log_error() {
    log "ERROR" "$1" >&2
    ((STATS[errors]++))
}

# Display help
show_help() {
    cat << 'EOF'
Tri-Agent Automated Storage Cleanup System

USAGE:
    auto-cleanup.sh [OPTIONS]

OPTIONS:
    -n, --dry-run      Show what would be deleted without deleting
    -v, --verbose      Enable verbose output
    -f, --force        Skip confirmation prompts
    -q, --quiet        Suppress non-error output
    --check-disk       Only check disk space and exit
    --monitor          Run in monitoring mode (check disk, report status)
    -h, --help         Show this help message

RETENTION POLICIES:
    Audit Logs    365 days    ~/.claude/logs/audit/
    Session Logs    7 days    ~/.claude/logs/sessions.log
    Checkpoints     3 days    ~/.claude/sessions/checkpoints/
    Snapshots       7 days    ~/.claude/sessions/snapshots/
    Task Files     14 days    ~/.claude/tasks/
    Metrics        90 days    ~/.claude/metrics/
    Backups        30 days    ~/.claude/backups/

CRON SETUP:
    # Daily cleanup at 3 AM
    0 3 * * * ~/.claude/scripts/auto-cleanup.sh

    # Disk monitoring every 4 hours
    0 */4 * * * ~/.claude/scripts/auto-cleanup.sh --monitor

EXIT CODES:
    0 - Success
    1 - Failed to acquire lock
    2 - Critical disk space
    3 - Partial failure
    4 - Invalid arguments

EXAMPLES:
    # Preview what would be deleted
    auto-cleanup.sh --dry-run --verbose

    # Run cleanup silently
    auto-cleanup.sh --quiet

    # Check disk space only
    auto-cleanup.sh --check-disk
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            --check-disk)
                CHECK_DISK_ONLY=true
                shift
                ;;
            --monitor)
                MONITOR_MODE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "ERROR: Unknown option: $1" >&2
                show_help
                exit $EXIT_INVALID_ARGS
                ;;
        esac
    done
}

# ==============================================================================
# SAFETY FUNCTIONS
# ==============================================================================

# Check if directory is in cleanable list
is_cleanable_dir() {
    local dir="$1"
    for cleanable in "${CLEANABLE_DATA_DIRS[@]}"; do
        [[ "$dir" == "$cleanable" ]] && return 0
    done
    return 1
}

# Validate path is safe for cleanup
is_safe_path() {
    local path="$1"

    # Must start with CLAUDE_DIR
    [[ "$path" != "${CLAUDE_DIR}"* ]] && return 1

    # Must not be in a protected directory
    for protected in "${PROTECTED_DIRS[@]}"; do
        [[ "$path" == "$protected"* ]] && return 1
    done

    # Must exist
    [[ ! -e "$path" ]] && return 1

    return 0
}

# Check if file is protected (exact name match)
is_protected_file_name() {
    local file="$1"
    local basename
    basename=$(basename "$file")

    for protected in "${PROTECTED_FILES[@]}"; do
        [[ "$basename" == "$protected" ]] && return 0
    done

    return 1
}

# Check if file matches protected pattern
matches_protected_pattern() {
    local file="$1"
    local basename
    basename=$(basename "$file")

    for pattern in "${PROTECTED_PATTERNS[@]}"; do
        # shellcheck disable=SC2053
        [[ "$basename" == $pattern ]] && return 0
    done

    return 1
}

# Check if file is protected
is_protected_file() {
    local file="$1"
    local parent_dir
    parent_dir=$(dirname "$file")

    # Check exact file name match
    is_protected_file_name "$file" && return 0

    # Check pattern match
    matches_protected_pattern "$file" && return 0

    # For files in root .claude directory, be extra careful with JSON
    if [[ "$parent_dir" == "$CLAUDE_DIR" ]]; then
        local basename
        basename=$(basename "$file")
        # Protect all JSON in root .claude except explicitly handled ones
        [[ "$basename" == *.json ]] && return 0
    fi

    return 1
}

# Acquire exclusive lock
acquire_lock() {
    local lock_dir
    lock_dir=$(dirname "$LOCK_FILE")
    mkdir -p "$lock_dir" 2>/dev/null || true

    # Check for stale lock
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_age lock_pid
        lock_age=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0) ))
        lock_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "unknown")

        if [[ $lock_age -gt $LOCK_TIMEOUT ]]; then
            log "WARNING" "Removing stale lock (PID: $lock_pid, age: ${lock_age}s)"
            rm -f "$LOCK_FILE"
        else
            log_error "Another cleanup is running (PID: $lock_pid, age: ${lock_age}s)"
            return 1
        fi
    fi

    # Create lock with PID
    echo $$ > "$LOCK_FILE"
    log_verbose "Lock acquired (PID: $$)"
    return 0
}

# Release lock
release_lock() {
    rm -f "$LOCK_FILE" 2>/dev/null || true
    log_verbose "Lock released"
}

# ==============================================================================
# DISK SPACE MONITORING
# ==============================================================================

# Get available disk space in GB
get_available_space_gb() {
    df -BG "$CLAUDE_DIR" 2>/dev/null | awk 'NR==2 {gsub("G",""); print $4}'
}

# Get used disk space for .claude directory
get_claude_dir_size() {
    du -sh "$CLAUDE_DIR" 2>/dev/null | cut -f1
}

# Send alert notification
send_alert() {
    local level="$1"
    local title="$2"
    local message="$3"

    # Source alerts configuration if available
    local alerts_conf="${CLAUDE_DIR}/alerts.conf"
    [[ -f "$alerts_conf" ]] && source "$alerts_conf"

    # Desktop notification (libnotify)
    if [[ "${DESKTOP_NOTIFY_ENABLED:-false}" == "true" ]] && command -v notify-send &>/dev/null; then
        local urgency="normal"
        [[ "$level" == "CRITICAL" ]] && urgency="critical"
        notify-send -u "$urgency" "Tri-Agent: $title" "$message" 2>/dev/null || true
    fi

    # Sound alert for critical
    if [[ "${SOUND_ENABLED:-false}" == "true" && "$level" == "CRITICAL" ]]; then
        if command -v paplay &>/dev/null; then
            paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null &
        fi
    fi

    # Slack webhook
    if [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
        curl -s -X POST "$SLACK_WEBHOOK_URL" \
            -H 'Content-Type: application/json' \
            -d "{\"text\":\"[$level] $title: $message\"}" 2>/dev/null || true
    fi

    # Email via msmtp
    if [[ -n "${ALERT_EMAIL:-}" ]] && command -v msmtp &>/dev/null; then
        echo -e "Subject: Tri-Agent Alert: $title\n\n$message" | msmtp "$ALERT_EMAIL" 2>/dev/null || true
    fi

    # Log the alert
    log "$level" "ALERT: $title - $message"
}

# Check disk space and send alerts
check_disk_space() {
    local available_gb
    available_gb=$(get_available_space_gb)

    if [[ -z "$available_gb" ]]; then
        log "WARNING" "Could not determine disk space"
        return 0
    fi

    local claude_size
    claude_size=$(get_claude_dir_size)

    log "INFO" "Disk space: ${available_gb}GB available, .claude size: ${claude_size}"

    if [[ "$available_gb" -lt "$DISK_EMERGENCY_GB" ]]; then
        send_alert "CRITICAL" "EMERGENCY: Disk Space" \
            "Only ${available_gb}GB remaining! Immediate action required. .claude size: ${claude_size}"
        return 2
    elif [[ "$available_gb" -lt "$DISK_CRITICAL_GB" ]]; then
        send_alert "CRITICAL" "Critical Disk Space" \
            "Only ${available_gb}GB remaining. .claude size: ${claude_size}"
        return 1
    elif [[ "$available_gb" -lt "$DISK_WARN_GB" ]]; then
        send_alert "WARNING" "Low Disk Space" \
            "${available_gb}GB remaining. .claude size: ${claude_size}"
    fi

    return 0
}

# Generate disk usage report
disk_usage_report() {
    log "INFO" "=== DISK USAGE REPORT ==="

    local total_size
    total_size=$(get_claude_dir_size)
    log "INFO" "Total .claude size: $total_size"

    log "INFO" "Directory breakdown:"

    # Get sizes for each major directory
    local dirs=(
        "logs" "sessions" "state" "tasks" "metrics" "backups"
        "debug" "24hr-results" "queue" "telemetry"
    )

    for dir in "${dirs[@]}"; do
        local dir_path="${CLAUDE_DIR}/${dir}"
        if [[ -d "$dir_path" ]]; then
            local size
            size=$(du -sh "$dir_path" 2>/dev/null | cut -f1)
            log "INFO" "  ${dir}: ${size}"
        fi
    done

    log "INFO" "Available space: $(get_available_space_gb)GB"
    log "INFO" "==========================="
}

# ==============================================================================
# CLEANUP FUNCTIONS
# ==============================================================================

# Get file size in bytes
get_file_size() {
    stat -c%s "$1" 2>/dev/null || echo 0
}

# Safe delete with validation
safe_delete() {
    local path="$1"
    local reason="$2"

    # Validate path
    if ! is_safe_path "$path"; then
        log_verbose "Skipping unsafe path: $path"
        ((STATS[skipped_protected]++))
        return 1
    fi

    # Check if protected file
    if [[ -f "$path" ]] && is_protected_file "$path"; then
        log_verbose "Skipping protected file: $path"
        ((STATS[skipped_protected]++))
        return 1
    fi

    local size=0
    [[ -f "$path" ]] && size=$(get_file_size "$path")

    if [[ "$DRY_RUN" == "true" ]]; then
        local human_size
        human_size=$(numfmt --to=iec "$size" 2>/dev/null || echo "${size}B")
        log_verbose "[DRY-RUN] Would delete: $path ($human_size) - $reason"
        ((STATS[files_deleted]++))
        ((STATS[bytes_freed] += size))
        return 0
    fi

    if rm -rf "$path" 2>/dev/null; then
        ((STATS[bytes_freed] += size))
        ((STATS[files_deleted]++))
        log_verbose "Deleted: $path - $reason"
        return 0
    else
        log_error "Failed to delete: $path"
        return 1
    fi
}

# Clean a directory based on retention policy
clean_directory() {
    local dir="$1"
    local days="$2"
    local pattern="${3:-*}"
    local description="$4"

    log "INFO" "Cleaning ${description} (retention: ${days} days)..."

    if [[ ! -d "$dir" ]]; then
        log_verbose "Directory does not exist: $dir"
        return 0
    fi

    # Validate directory is safe
    if ! is_safe_path "$dir"; then
        log_error "Refusing to clean unsafe directory: $dir"
        return 1
    fi

    local count_before=${STATS[files_deleted]}

    # Find and delete old files
    while IFS= read -r -d '' file; do
        safe_delete "$file" "older than ${days} days"
    done < <(find "$dir" -type f -name "$pattern" -mtime +"$days" -print0 2>/dev/null)

    # Clean up empty subdirectories (but not the root)
    if [[ "$DRY_RUN" != "true" ]]; then
        find "$dir" -mindepth 1 -type d -empty -delete 2>/dev/null || true
    fi

    local count_deleted=$((STATS[files_deleted] - count_before))
    log "INFO" "Cleaned ${count_deleted} files from ${description}"
    ((STATS[dirs_cleaned]++))
}

# Rotate large log files
rotate_large_logs() {
    log "INFO" "Rotating logs larger than ${LOG_ROTATE_SIZE_MB}MB..."

    [[ ! -d "$LOG_DIR" ]] && return 0

    local count=0

    while IFS= read -r -d '' file; do
        # Skip already compressed files
        [[ "$file" == *.gz ]] && continue

        local original_size
        original_size=$(get_file_size "$file")

        if [[ "$DRY_RUN" == "true" ]]; then
            log_verbose "[DRY-RUN] Would compress: $file"
            ((count++))
        else
            if gzip -f "$file" 2>/dev/null; then
                local new_size
                new_size=$(get_file_size "${file}.gz")
                local saved=$((original_size - new_size))
                ((STATS[bytes_freed] += saved))
                ((STATS[files_compressed]++))
                ((count++))
                log_verbose "Compressed: $file (saved $(numfmt --to=iec $saved))"
            else
                log_error "Failed to compress: $file"
            fi
        fi
    done < <(find "$LOG_DIR" -name "*.log" -size +"${LOG_ROTATE_SIZE_MB}M" -print0 2>/dev/null)

    log "INFO" "Compressed ${count} log files"
}

# Clean audit logs (365 days retention - from CLAUDE.md)
clean_audit_logs() {
    log "INFO" "Cleaning audit logs (retention: ${RETENTION_AUDIT_LOGS} days)..."

    [[ ! -d "$AUDIT_LOG_DIR" ]] && return 0

    local count=0

    # Delete .jsonl files older than retention period
    while IFS= read -r -d '' file; do
        safe_delete "$file" "audit log older than ${RETENTION_AUDIT_LOGS} days"
        ((count++))
    done < <(find "$AUDIT_LOG_DIR" -name "*.jsonl" -mtime +"$RETENTION_AUDIT_LOGS" -print0 2>/dev/null)

    # Delete compressed audit logs with same retention
    while IFS= read -r -d '' file; do
        safe_delete "$file" "compressed audit log older than ${RETENTION_AUDIT_LOGS} days"
        ((count++))
    done < <(find "$AUDIT_LOG_DIR" -name "*.jsonl.gz" -mtime +"$RETENTION_AUDIT_LOGS" -print0 2>/dev/null)

    log "INFO" "Cleaned ${count} audit log files"
}

# Clean session log file (7 days retention)
clean_session_logs() {
    local session_log="${LOG_DIR}/sessions.log"

    log "INFO" "Cleaning session logs (retention: ${RETENTION_SESSION_LOGS} days)..."

    [[ ! -f "$session_log" ]] && return 0

    local file_age_days
    file_age_days=$(( ($(date +%s) - $(stat -c %Y "$session_log" 2>/dev/null || echo $(date +%s))) / 86400 ))

    if [[ $file_age_days -gt $RETENTION_SESSION_LOGS ]]; then
        local size
        size=$(get_file_size "$session_log")

        if [[ "$DRY_RUN" == "true" ]]; then
            log_verbose "[DRY-RUN] Would archive: $session_log (age: ${file_age_days} days)"
        else
            # Archive with timestamp
            local archive="${LOG_DIR}/sessions.log.$(date +%Y%m%d%H%M%S)"
            mv "$session_log" "$archive"
            gzip "$archive" 2>/dev/null || true
            touch "$session_log"
            ((STATS[bytes_freed] += size))
            log "INFO" "Archived session log (${file_age_days} days old)"
        fi
    fi

    # Clean old archived session logs
    clean_directory "$LOG_DIR" 30 "sessions.log.*.gz" "archived session logs"
}

# Vacuum SQLite databases
vacuum_databases() {
    log "INFO" "Vacuuming SQLite databases..."

    [[ ! -d "$STATE_DIR" ]] && return 0

    if ! command -v sqlite3 &>/dev/null; then
        log "WARNING" "sqlite3 not found, skipping database vacuum"
        return 0
    fi

    local count=0
    local total_saved=0

    for db in "${STATE_DIR}"/*.db; do
        [[ ! -f "$db" ]] && continue

        local before_size
        before_size=$(get_file_size "$db")

        if [[ "$DRY_RUN" == "true" ]]; then
            log_verbose "[DRY-RUN] Would vacuum: $db"
            ((count++))
        else
            # Integrity check first
            if ! sqlite3 "$db" "PRAGMA integrity_check;" 2>/dev/null | grep -q "^ok$"; then
                log_error "Database integrity check failed: $db"
                continue
            fi

            if sqlite3 "$db" "VACUUM; PRAGMA wal_checkpoint(TRUNCATE);" 2>/dev/null; then
                local after_size
                after_size=$(get_file_size "$db")
                local saved=$((before_size - after_size))
                [[ $saved -gt 0 ]] && ((total_saved += saved))
                ((count++))
                ((STATS[dbs_vacuumed]++))
                log_verbose "Vacuumed: $db (saved $(numfmt --to=iec $saved 2>/dev/null))"
            else
                log_error "Failed to vacuum: $db"
            fi
        fi
    done

    ((STATS[bytes_freed] += total_saved))
    log "INFO" "Vacuumed ${count} databases (saved $(numfmt --to=iec $total_saved 2>/dev/null))"
}

# ==============================================================================
# SUMMARY AND REPORTING
# ==============================================================================

generate_summary() {
    local end_time
    end_time=$(timestamp)

    local bytes_human
    bytes_human=$(numfmt --to=iec "${STATS[bytes_freed]}" 2>/dev/null || echo "${STATS[bytes_freed]}B")

    log "INFO" "============================================"
    log "INFO" "AUTO-CLEANUP SUMMARY"
    log "INFO" "============================================"
    log "INFO" "Mode:              $([ "$DRY_RUN" == "true" ] && echo "DRY RUN" || echo "LIVE")"
    log "INFO" "Files deleted:     ${STATS[files_deleted]}"
    log "INFO" "Files compressed:  ${STATS[files_compressed]}"
    log "INFO" "Directories:       ${STATS[dirs_cleaned]}"
    log "INFO" "DBs vacuumed:      ${STATS[dbs_vacuumed]}"
    log "INFO" "Protected/skipped: ${STATS[skipped_protected]}"
    log "INFO" "Space freed:       ${bytes_human}"
    log "INFO" "Errors:            ${STATS[errors]}"
    log "INFO" "Completed:         ${end_time}"
    log "INFO" "============================================"

    # Send summary notification if there were errors
    if [[ ${STATS[errors]} -gt 0 ]]; then
        send_alert "WARNING" "Cleanup Completed with Errors" \
            "${STATS[errors]} errors occurred. Space freed: ${bytes_human}. Check logs."
    fi
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main() {
    parse_args "$@"

    local start_time
    start_time=$(timestamp)

    # Handle special modes
    if [[ "$CHECK_DISK_ONLY" == "true" ]]; then
        check_disk_space
        exit $?
    fi

    if [[ "$MONITOR_MODE" == "true" ]]; then
        log "INFO" "=== DISK MONITORING CHECK: ${start_time} ==="
        check_disk_space
        disk_usage_report
        exit $?
    fi

    # Main cleanup execution
    log "INFO" "============================================"
    log "INFO" "Starting auto-cleanup at ${start_time}"
    [[ "$DRY_RUN" == "true" ]] && log "INFO" "*** DRY RUN MODE - No files will be deleted ***"
    log "INFO" "============================================"

    # Acquire lock (skip for dry run)
    if [[ "$DRY_RUN" != "true" ]]; then
        if ! acquire_lock; then
            exit $EXIT_LOCK_FAILED
        fi
        trap release_lock EXIT
    fi

    # Ensure base directories exist
    mkdir -p "$LOG_DIR" "$AUDIT_LOG_DIR" "$CHECKPOINT_DIR" "$SNAPSHOT_DIR" "$STATE_DIR" 2>/dev/null || true

    # Pre-cleanup disk check
    local disk_status=0
    check_disk_space || disk_status=$?

    if [[ $disk_status -eq 2 ]]; then
        log "CRITICAL" "Emergency disk space situation - proceeding with aggressive cleanup"
    fi

    # ===========================================================================
    # Execute cleanup tasks in order of priority/frequency
    # ===========================================================================

    # 1. Rotate large logs first (immediate space savings)
    rotate_large_logs

    # 2. Short retention (3 days) - Checkpoints, Queue
    clean_directory "$CHECKPOINT_DIR" "$RETENTION_CHECKPOINTS" "*" "checkpoints"
    clean_directory "$QUEUE_DIR" "$RETENTION_QUEUE" "*" "queue files"

    # 3. Weekly retention (7 days) - Sessions, Snapshots, Debug
    clean_directory "$SNAPSHOT_DIR" "$RETENTION_SNAPSHOTS" "*" "snapshots"
    clean_session_logs
    clean_directory "$DEBUG_DIR" "$RETENTION_DEBUG" "*" "debug files"
    clean_directory "$SHELL_SNAPSHOTS_DIR" "$RETENTION_SHELL_SNAPSHOTS" "*" "shell snapshots"
    clean_directory "$SESSION_ENV_DIR" "$RETENTION_SESSION_ENV" "*" "session environment"
    clean_directory "$RESULTS_24HR_DIR" "$RETENTION_24HR_RESULTS" "*" "24hr results"

    # 4. Bi-weekly retention (14 days) - Tasks, Handoffs
    clean_directory "$TASKS_DIR" "$RETENTION_TASK_FILES" "*" "task files"
    clean_directory "$HANDOFFS_DIR" "$RETENTION_HANDOFFS" "*" "handoff files"

    # 5. Monthly retention (30 days) - Backups, Telemetry
    clean_directory "$BACKUPS_DIR" "$RETENTION_BACKUPS" "*" "backup files"
    clean_directory "$TELEMETRY_DIR" "$RETENTION_TELEMETRY" "*" "telemetry"
    clean_directory "$FILE_HISTORY_DIR" "$RETENTION_FILE_HISTORY" "*" "file history"

    # 6. Quarterly retention (90 days) - Metrics
    clean_directory "$METRICS_DIR" "$RETENTION_METRICS" "*" "metrics"

    # 7. Yearly retention (365 days) - Audit logs
    clean_audit_logs

    # 8. Database maintenance
    vacuum_databases

    # 9. Post-cleanup reporting
    disk_usage_report

    # Final disk check
    check_disk_space || true

    # Generate summary
    generate_summary

    # Determine exit code
    if [[ ${STATS[errors]} -gt 0 ]]; then
        exit $EXIT_PARTIAL_FAILURE
    fi

    exit $EXIT_SUCCESS
}

# Run main
main "$@"
