#!/bin/bash
# Web Guard Hook - Security checks for web operations (WebSearch/WebFetch)
# Called before web tool execution

set -uo pipefail

LOG_DIR="${HOME}/.claude/logs"
mkdir -p "$LOG_DIR"

# Parse tool input
# Safe input reading with timeout
TOOL_DATA=""
if read -t 1 -r line; then
    TOOL_DATA="$line"
    while read -t 0.1 -r line; do
        TOOL_DATA="${TOOL_DATA}${line}"
    done
fi

# Check for bypass mode - allow everything if enabled
PERMISSION_MODE=$(echo "$TOOL_DATA" | jq -r '.permission_mode // empty' 2>/dev/null)
if [[ "$PERMISSION_MODE" == "bypassPermissions" ]]; then
    echo '{"continue": true}'
    exit 0
fi

TOOL_NAME=$(echo "$TOOL_DATA" | jq -r '.tool_name // "unknown"')
URL=$(echo "$TOOL_DATA" | jq -r '.tool_input.url // ""')
QUERY=$(echo "$TOOL_DATA" | jq -r '.tool_input.query // ""')
TIMESTAMP=$(date -Iseconds)

# Blocked domains (suspicious/malicious)
BLOCKED_DOMAINS=(
    'pastebin.com'
    'paste.ee'
    'hastebin.com'
    'file.io'
    'transfer.sh'
    '0x0.st'
    'temp.sh'
)

# Check URL for blocked domains
for domain in "${BLOCKED_DOMAINS[@]}"; do
    if echo "$URL" | grep -qiE "$domain"; then
        echo "[${TIMESTAMP}] BLOCKED_WEB tool=${TOOL_NAME} domain='$domain' url='$URL'" >> "${LOG_DIR}/security.log"
        echo '{"continue": false, "reason": "Access to potentially malicious domain blocked: '"$domain"'"}'
        exit 0
    fi
done

# Check for data exfiltration patterns in URLs
EXFIL_PATTERNS=(
    'api_key='
    'apikey='
    'token='
    'secret='
    'password='
    'credential'
    'base64='
)

for pattern in "${EXFIL_PATTERNS[@]}"; do
    if echo "$URL" | grep -qiE "$pattern"; then
        echo "[${TIMESTAMP}] WARN_WEB exfil_pattern='$pattern' url='${URL:0:200}'" >> "${LOG_DIR}/security.log"
        # Log but allow - could be legitimate API usage
    fi
done

# Log web access for audit
if [[ -n "$URL" ]]; then
    echo "[${TIMESTAMP}] ALLOW_WEB tool=${TOOL_NAME} url='${URL:0:200}'" >> "${LOG_DIR}/web.log"
elif [[ -n "$QUERY" ]]; then
    echo "[${TIMESTAMP}] ALLOW_WEB tool=${TOOL_NAME} query='${QUERY:0:200}'" >> "${LOG_DIR}/web.log"
fi

echo '{"continue": true}'
