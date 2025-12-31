#!/bin/bash
# File Guard Hook - Security checks for file operations (Read/Edit/Write)
# Called before file tool execution

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
FILE_PATH=$(echo "$TOOL_DATA" | jq -r '.tool_input.file_path // .tool_input.path // ""')
TIMESTAMP=$(date -Iseconds)

# Normalize path
REAL_PATH=$(realpath -m "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")

# Sensitive file patterns to block
BLOCKED_PATTERNS=(
    '^/etc/passwd$'
    '^/etc/shadow$'
    '\.env$'
    '\.env\.'
    '/\.ssh/'
    '/\.aws/'
    '/\.config/gcloud/'
    '/\.azure/'
    '/\.kube/'
    'id_rsa'
    'id_ed25519'
    '\.pem$'
    '\.key$'
    'private.*key'
    '/secrets/'
    'credentials'
    'password'
    'token'
    'apikey'
    'api_key'
)

# Check for blocked patterns
for pattern in "${BLOCKED_PATTERNS[@]}"; do
    if echo "$REAL_PATH" | grep -qiE "$pattern"; then
        echo "[${TIMESTAMP}] BLOCKED_FILE tool=${TOOL_NAME} pattern='$pattern' path='$FILE_PATH'" >> "${LOG_DIR}/security.log"
        echo '{"continue": false, "reason": "Access to sensitive file blocked: '"$pattern"'"}'
        exit 0
    fi
done

# Warn on system files but allow (except blocked above)
if echo "$REAL_PATH" | grep -qE '^/(etc|var|usr|bin|sbin|lib)/'; then
    echo "[${TIMESTAMP}] WARN_FILE tool=${TOOL_NAME} system_path='$FILE_PATH'" >> "${LOG_DIR}/security.log"
fi

# Log access for audit
echo "[${TIMESTAMP}] ALLOW_FILE tool=${TOOL_NAME} path='$FILE_PATH'" >> "${LOG_DIR}/files.log"

echo '{"continue": true}'
