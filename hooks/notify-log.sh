#!/bin/bash
# Notification Log Hook - Log and optionally forward notifications
# Called on Notification events

set -uo pipefail

LOG_DIR="${HOME}/.claude/logs"
NOTIFY_DIR="${LOG_DIR}/notifications"

mkdir -p "$NOTIFY_DIR"

# Parse notification data
NOTIFY_DATA=$(cat)
SESSION_ID=$(echo "$NOTIFY_DATA" | jq -r '.session_id // "unknown"')
TITLE=$(echo "$NOTIFY_DATA" | jq -r '.title // ""')
MESSAGE=$(echo "$NOTIFY_DATA" | jq -r '.message // ""')
LEVEL=$(echo "$NOTIFY_DATA" | jq -r '.level // "info"')
TIMESTAMP=$(date -Iseconds)

# Log notification
NOTIFY_LOG="${NOTIFY_DIR}/notifications-$(date +%Y%m%d).log"
echo "[${TIMESTAMP}] [${LEVEL^^}] ${TITLE}: ${MESSAGE}" >> "$NOTIFY_LOG"

# For critical notifications, also log to main log
if [[ "$LEVEL" == "error" || "$LEVEL" == "critical" ]]; then
    echo "[${TIMESTAMP}] CRITICAL_NOTIFICATION session=${SESSION_ID} title='${TITLE}'" >> "${LOG_DIR}/critical.log"

    # Optional: Send to external alerting system
    # curl -X POST "http://alerting-system/api/alert" \
    #   -H "Content-Type: application/json" \
    #   -d "{\"level\":\"${LEVEL}\",\"title\":\"${TITLE}\",\"message\":\"${MESSAGE}\"}"
fi

# Track notification counts by level
STATS_FILE="${NOTIFY_DIR}/stats.json"
(
    flock -x 200
    if [[ -f "$STATS_FILE" ]]; then
        CURRENT=$(jq -r ".\"${LEVEL}\" // 0" "$STATS_FILE")
        jq ".\"${LEVEL}\" = $((CURRENT + 1))" "$STATS_FILE" > "${STATS_FILE}.tmp"
        mv "${STATS_FILE}.tmp" "$STATS_FILE"
    else
        echo "{\"${LEVEL}\": 1}" > "$STATS_FILE"
    fi
) 200>"${STATS_FILE}.lock"

# Rotate old notification logs (keep 14 days)
find "$NOTIFY_DIR" -name "notifications-*.log" -mtime +14 -delete 2>/dev/null || true

echo '{"continue": true}'
