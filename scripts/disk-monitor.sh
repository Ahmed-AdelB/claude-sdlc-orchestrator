#!/bin/bash
# ==============================================================================
# Tri-Agent Disk Space Monitor
# ==============================================================================
# Version: 1.0.0
# Author: Ahmed Adel Bakr Alderai
# Created: 2026-01-21
#
# Standalone disk monitoring script with advanced alerting
#
# USAGE:
#   ./disk-monitor.sh [OPTIONS]
#
# OPTIONS:
#   -q, --quiet     Suppress non-alert output
#   -j, --json      Output in JSON format
#   --once          Run once and exit (default)
#   --daemon        Run continuously with interval
#   --interval N    Check interval in seconds (default: 3600)
#   -h, --help      Show help
#
# CRON SETUP:
#   # Check every 4 hours
#   0 */4 * * * ~/.claude/scripts/disk-monitor.sh >> ~/.claude/logs/disk-monitor.log 2>&1
#
#   # Check every hour during business hours
#   0 9-18 * * 1-5 ~/.claude/scripts/disk-monitor.sh
#
# ==============================================================================

set -uo pipefail

# ==============================================================================
# CONFIGURATION
# ==============================================================================
readonly CLAUDE_DIR="${HOME}/.claude"
readonly LOG_DIR="${CLAUDE_DIR}/logs"
readonly MONITOR_LOG="${LOG_DIR}/disk-monitor.log"
readonly ALERT_HISTORY="${LOG_DIR}/disk-alert-history.jsonl"

# Disk thresholds (GB)
readonly DISK_OK_GB=10
readonly DISK_WARN_GB=5
readonly DISK_CRITICAL_GB=2
readonly DISK_EMERGENCY_GB=1

# Alert cooldown (seconds) - don't repeat same alert within this period
readonly ALERT_COOLDOWN=3600  # 1 hour

# ==============================================================================
# OPTIONS
# ==============================================================================
QUIET=false
JSON_OUTPUT=false
DAEMON_MODE=false
CHECK_INTERVAL=3600

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

timestamp() {
    date -Iseconds
}

timestamp_epoch() {
    date +%s
}

log() {
    local level="$1"
    local message="$2"

    if [[ "$JSON_OUTPUT" == "true" ]]; then
        printf '{"ts":"%s","level":"%s","msg":"%s"}\n' "$(timestamp)" "$level" "$message"
    elif [[ "$QUIET" != "true" || "$level" != "INFO" ]]; then
        echo "[$(timestamp)] [$level] $message"
    fi

    # Always append to log file
    if [[ -d "$LOG_DIR" ]]; then
        echo "[$(timestamp)] [$level] $message" >> "$MONITOR_LOG"
    fi
}

show_help() {
    cat << 'EOF'
Tri-Agent Disk Space Monitor

USAGE:
    disk-monitor.sh [OPTIONS]

OPTIONS:
    -q, --quiet       Suppress non-alert output
    -j, --json        Output in JSON format
    --once            Run once and exit (default)
    --daemon          Run continuously with interval
    --interval N      Check interval in seconds (default: 3600)
    -h, --help        Show this help

THRESHOLDS:
    OK        >= 10 GB
    WARNING   < 5 GB
    CRITICAL  < 2 GB
    EMERGENCY < 1 GB

EXAMPLES:
    # Quick check
    disk-monitor.sh

    # JSON output for scripting
    disk-monitor.sh --json --quiet

    # Daemon mode checking every 30 minutes
    disk-monitor.sh --daemon --interval 1800
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -q|--quiet)
                QUIET=true
                shift
                ;;
            -j|--json)
                JSON_OUTPUT=true
                shift
                ;;
            --once)
                DAEMON_MODE=false
                shift
                ;;
            --daemon)
                DAEMON_MODE=true
                shift
                ;;
            --interval)
                CHECK_INTERVAL="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "ERROR: Unknown option: $1" >&2
                show_help
                exit 1
                ;;
        esac
    done
}

# ==============================================================================
# DISK SPACE FUNCTIONS
# ==============================================================================

get_available_gb() {
    df -BG "$CLAUDE_DIR" 2>/dev/null | awk 'NR==2 {gsub("G",""); print $4}'
}

get_total_gb() {
    df -BG "$CLAUDE_DIR" 2>/dev/null | awk 'NR==2 {gsub("G",""); print $2}'
}

get_used_percent() {
    df "$CLAUDE_DIR" 2>/dev/null | awk 'NR==2 {gsub("%",""); print $5}'
}

get_claude_size_mb() {
    du -sm "$CLAUDE_DIR" 2>/dev/null | cut -f1
}

get_claude_size_human() {
    du -sh "$CLAUDE_DIR" 2>/dev/null | cut -f1
}

# Get largest directories in .claude
get_top_directories() {
    local count="${1:-5}"
    du -sm "${CLAUDE_DIR}"/*/ 2>/dev/null | sort -rn | head -"$count" | \
        while read -r size dir; do
            echo "  $(printf '%6dM' "$size") $(basename "$dir")"
        done
}

# ==============================================================================
# ALERT FUNCTIONS
# ==============================================================================

# Check if we should send an alert (cooldown logic)
should_alert() {
    local level="$1"
    local now
    now=$(timestamp_epoch)

    [[ ! -f "$ALERT_HISTORY" ]] && return 0

    local last_alert
    last_alert=$(grep "\"level\":\"$level\"" "$ALERT_HISTORY" 2>/dev/null | tail -1 | \
        sed -n 's/.*"epoch":\([0-9]*\).*/\1/p')

    [[ -z "$last_alert" ]] && return 0

    local age=$((now - last_alert))
    [[ $age -gt $ALERT_COOLDOWN ]] && return 0

    return 1
}

# Record alert in history
record_alert() {
    local level="$1"
    local message="$2"
    local epoch
    epoch=$(timestamp_epoch)

    mkdir -p "$(dirname "$ALERT_HISTORY")" 2>/dev/null || true

    printf '{"ts":"%s","epoch":%d,"level":"%s","msg":"%s"}\n' \
        "$(timestamp)" "$epoch" "$level" "$message" >> "$ALERT_HISTORY"
}

# Send alert through available channels
send_alert() {
    local level="$1"
    local title="$2"
    local message="$3"

    # Check cooldown
    if ! should_alert "$level"; then
        log "DEBUG" "Alert suppressed (cooldown): $level - $title"
        return 0
    fi

    # Record this alert
    record_alert "$level" "$message"

    # Source alerts configuration
    local alerts_conf="${CLAUDE_DIR}/alerts.conf"
    [[ -f "$alerts_conf" ]] && source "$alerts_conf"

    # Desktop notification
    if [[ "${DESKTOP_NOTIFY_ENABLED:-false}" == "true" ]] && command -v notify-send &>/dev/null; then
        local urgency="normal"
        [[ "$level" == "CRITICAL" || "$level" == "EMERGENCY" ]] && urgency="critical"
        notify-send -u "$urgency" "Disk Monitor: $title" "$message" 2>/dev/null || true
    fi

    # Sound alert for critical/emergency
    if [[ "${SOUND_ENABLED:-false}" == "true" ]]; then
        if [[ "$level" == "EMERGENCY" || "$level" == "CRITICAL" ]]; then
            if command -v paplay &>/dev/null; then
                paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null &
            elif command -v aplay &>/dev/null; then
                aplay /usr/share/sounds/alsa/Front_Center.wav 2>/dev/null &
            fi
        fi
    fi

    # Slack webhook
    if [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
        local color="good"
        [[ "$level" == "WARNING" ]] && color="warning"
        [[ "$level" == "CRITICAL" || "$level" == "EMERGENCY" ]] && color="danger"

        curl -s -X POST "$SLACK_WEBHOOK_URL" \
            -H 'Content-Type: application/json' \
            -d "{
                \"attachments\": [{
                    \"color\": \"$color\",
                    \"title\": \"[$level] $title\",
                    \"text\": \"$message\",
                    \"ts\": $(timestamp_epoch)
                }]
            }" 2>/dev/null || true
    fi

    # Email
    if [[ -n "${ALERT_EMAIL:-}" ]] && command -v msmtp &>/dev/null; then
        echo -e "Subject: [$level] Disk Monitor: $title\n\n$message" | \
            msmtp "$ALERT_EMAIL" 2>/dev/null || true
    fi

    log "$level" "ALERT SENT: $title - $message"
}

# ==============================================================================
# MONITORING LOGIC
# ==============================================================================

check_disk() {
    local available_gb total_gb used_percent claude_size_human
    available_gb=$(get_available_gb)
    total_gb=$(get_total_gb)
    used_percent=$(get_used_percent)
    claude_size_human=$(get_claude_size_human)

    if [[ -z "$available_gb" ]]; then
        log "ERROR" "Could not determine disk space"
        return 1
    fi

    # Determine status
    local status="OK"
    local exit_code=0

    if [[ "$available_gb" -lt "$DISK_EMERGENCY_GB" ]]; then
        status="EMERGENCY"
        exit_code=3
    elif [[ "$available_gb" -lt "$DISK_CRITICAL_GB" ]]; then
        status="CRITICAL"
        exit_code=2
    elif [[ "$available_gb" -lt "$DISK_WARN_GB" ]]; then
        status="WARNING"
        exit_code=1
    elif [[ "$available_gb" -lt "$DISK_OK_GB" ]]; then
        status="LOW"
        exit_code=0
    fi

    # JSON output format
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        cat << EOF
{
    "timestamp": "$(timestamp)",
    "status": "$status",
    "available_gb": $available_gb,
    "total_gb": $total_gb,
    "used_percent": $used_percent,
    "claude_size": "$claude_size_human",
    "thresholds": {
        "ok": $DISK_OK_GB,
        "warn": $DISK_WARN_GB,
        "critical": $DISK_CRITICAL_GB,
        "emergency": $DISK_EMERGENCY_GB
    }
}
EOF
    else
        # Human-readable output
        log "INFO" "=== DISK SPACE CHECK ==="
        log "INFO" "Status:     $status"
        log "INFO" "Available:  ${available_gb}GB"
        log "INFO" "Total:      ${total_gb}GB"
        log "INFO" "Used:       ${used_percent}%"
        log "INFO" ".claude:    ${claude_size_human}"

        if [[ "$VERBOSE" == "true" || "$status" != "OK" ]]; then
            log "INFO" "Top directories:"
            get_top_directories 5 | while read -r line; do
                log "INFO" "$line"
            done
        fi
    fi

    # Send alerts based on status
    case "$status" in
        EMERGENCY)
            send_alert "EMERGENCY" "DISK SPACE EMERGENCY" \
                "Only ${available_gb}GB remaining! System may become unstable. .claude size: ${claude_size_human}"
            ;;
        CRITICAL)
            send_alert "CRITICAL" "Critical Disk Space" \
                "Only ${available_gb}GB remaining. Immediate cleanup recommended. .claude size: ${claude_size_human}"
            ;;
        WARNING)
            send_alert "WARNING" "Low Disk Space" \
                "${available_gb}GB remaining. Consider running cleanup. .claude size: ${claude_size_human}"
            ;;
    esac

    return $exit_code
}

# ==============================================================================
# VERBOSE FLAG
# ==============================================================================
VERBOSE=false

# ==============================================================================
# MAIN
# ==============================================================================

main() {
    parse_args "$@"

    # Ensure log directory exists
    mkdir -p "$LOG_DIR" 2>/dev/null || true

    if [[ "$DAEMON_MODE" == "true" ]]; then
        log "INFO" "Starting disk monitor daemon (interval: ${CHECK_INTERVAL}s)"

        while true; do
            check_disk
            sleep "$CHECK_INTERVAL"
        done
    else
        check_disk
        exit $?
    fi
}

main "$@"
