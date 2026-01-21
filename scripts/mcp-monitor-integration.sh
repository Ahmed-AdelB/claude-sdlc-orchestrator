#!/bin/bash
#
# MCP Monitor Integration Script
# Integrates MCP health checks with the existing tri-agent monitoring system
#
# Author: Ahmed Adel Bakr Alderai
# Version: 1.0.0
#
# This script:
#   - Runs MCP health checks
#   - Exports metrics to Prometheus format
#   - Sends alerts via existing notification hooks
#   - Logs to the centralized monitoring system
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-${HOME}/.claude}"

# Import MCP health check
MCP_HEALTH_CHECK="${SCRIPT_DIR}/mcp-health-check.sh"

# Monitoring integration paths
METRICS_DIR="${CLAUDE_HOME}/metrics"
LOGS_DIR="${CLAUDE_HOME}/logs"
ALERTS_CONF="${CLAUDE_HOME}/alerts.conf"

# Alert levels
ALERT_WARN_THRESHOLD=1   # 1+ servers with warnings
ALERT_ERROR_THRESHOLD=1  # 1+ servers with errors

# Load alert configuration if exists
if [[ -f "$ALERTS_CONF" ]]; then
    # shellcheck source=/dev/null
    source "$ALERTS_CONF"
fi

# Send desktop notification
send_notification() {
    local urgency="$1"
    local title="$2"
    local message="$3"

    if [[ "${DESKTOP_NOTIFY_ENABLED:-true}" == "true" ]]; then
        if command -v notify-send &>/dev/null; then
            notify-send -u "$urgency" "$title" "$message"
        fi
    fi
}

# Send alert via configured methods
send_alert() {
    local severity="$1"
    local component="$2"
    local message="$3"

    local timestamp
    timestamp=$(date -Iseconds)

    # Log to alert log
    echo "{\"timestamp\":\"$timestamp\",\"severity\":\"$severity\",\"component\":\"$component\",\"message\":\"$message\"}" >> "${LOGS_DIR}/mcp-alerts.jsonl"

    # Desktop notification
    case "$severity" in
        CRITICAL)
            send_notification "critical" "MCP CRITICAL" "$message"
            # Play sound if enabled
            if [[ "${SOUND_ENABLED:-false}" == "true" ]]; then
                paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null || true
            fi
            ;;
        ERROR)
            send_notification "normal" "MCP ERROR" "$message"
            ;;
        WARNING)
            send_notification "low" "MCP Warning" "$message"
            ;;
    esac

    # Slack webhook if configured
    if [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
        curl -sf -X POST "$SLACK_WEBHOOK_URL" \
            -H 'Content-Type: application/json' \
            -d "{\"text\":\"[$severity] MCP: $message\"}" &>/dev/null || true
    fi
}

# Export metrics to Prometheus format
export_prometheus_metrics() {
    local metrics_file="${METRICS_DIR}/mcp-health.prom"
    "$MCP_HEALTH_CHECK" --format prometheus > "$metrics_file" 2>/dev/null || true
}

# Run health check and process results
run_integrated_check() {
    local json_output
    local exit_code=0

    # Run health check with JSON output
    json_output=$("$MCP_HEALTH_CHECK" --format json 2>/dev/null) || exit_code=$?

    # Parse results
    local overall_status
    overall_status=$(echo "$json_output" | jq -r '.overall_status' 2>/dev/null || echo "UNKNOWN")

    local healthy_count
    healthy_count=$(echo "$json_output" | jq '[.servers[] | select(.status == "OK")] | length' 2>/dev/null || echo "0")

    local warn_count
    warn_count=$(echo "$json_output" | jq '[.servers[] | select(.status == "WARN")] | length' 2>/dev/null || echo "0")

    local error_count
    error_count=$(echo "$json_output" | jq '[.servers[] | select(.status == "ERROR" or .status == "CRITICAL")] | length' 2>/dev/null || echo "0")

    local total_count
    total_count=$(echo "$json_output" | jq '.total_servers' 2>/dev/null || echo "13")

    # Log to monitoring
    echo "[$(date -Iseconds)] MCP Health: ${overall_status} - ${healthy_count}/${total_count} healthy, ${warn_count} warnings, ${error_count} errors" >> "${LOGS_DIR}/mcp-health.log"

    # Send alerts based on status
    if [[ "$error_count" -ge "$ALERT_ERROR_THRESHOLD" ]]; then
        local failed_servers
        failed_servers=$(echo "$json_output" | jq -r '[.servers | to_entries[] | select(.value.status == "ERROR" or .value.status == "CRITICAL") | .key] | join(", ")' 2>/dev/null || echo "unknown")
        send_alert "ERROR" "mcp-servers" "MCP servers failing: ${failed_servers}"
    elif [[ "$warn_count" -ge "$ALERT_WARN_THRESHOLD" ]]; then
        local warn_servers
        warn_servers=$(echo "$json_output" | jq -r '[.servers | to_entries[] | select(.value.status == "WARN") | .key] | join(", ")' 2>/dev/null || echo "unknown")
        send_alert "WARNING" "mcp-servers" "MCP servers with warnings: ${warn_servers}"
    fi

    # Export Prometheus metrics
    export_prometheus_metrics

    # Output summary
    echo "MCP Health Check Complete"
    echo "  Status: ${overall_status}"
    echo "  Healthy: ${healthy_count}/${total_count}"
    echo "  Warnings: ${warn_count}"
    echo "  Errors: ${error_count}"

    return "$exit_code"
}

# Add MCP metrics to the main metrics collection
integrate_with_main_metrics() {
    local main_metrics="${METRICS_DIR}/current.prom"
    local mcp_metrics="${METRICS_DIR}/mcp-health.prom"

    if [[ -f "$mcp_metrics" ]]; then
        # Append MCP metrics to main metrics file
        if [[ -f "$main_metrics" ]]; then
            # Remove old MCP metrics first
            grep -v "^mcp_" "$main_metrics" > "${main_metrics}.tmp" || true
            mv "${main_metrics}.tmp" "$main_metrics"
        fi

        # Append new MCP metrics
        cat "$mcp_metrics" >> "$main_metrics"
    fi
}

main() {
    mkdir -p "$METRICS_DIR" "$LOGS_DIR"

    case "${1:-}" in
        --check)
            run_integrated_check
            ;;
        --metrics)
            export_prometheus_metrics
            cat "${METRICS_DIR}/mcp-health.prom"
            ;;
        --integrate)
            run_integrated_check
            integrate_with_main_metrics
            ;;
        --help|-h)
            echo "MCP Monitor Integration"
            echo ""
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  --check      Run health check with alerting"
            echo "  --metrics    Export Prometheus metrics only"
            echo "  --integrate  Full integration with main monitoring"
            echo "  --help       Show this help"
            ;;
        *)
            run_integrated_check
            integrate_with_main_metrics
            ;;
    esac
}

main "$@"
