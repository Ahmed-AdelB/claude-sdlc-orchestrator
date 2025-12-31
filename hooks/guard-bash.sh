#!/bin/bash
# Bash Guard Hook - Security checks for shell commands
# Called before Bash tool execution

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

COMMAND=$(echo "$TOOL_DATA" | jq -r '.tool_input.command // ""')
TIMESTAMP=$(date -Iseconds)

# Dangerous pattern detection
DANGEROUS_PATTERNS=(
    'rm -rf /'
    'rm -rf ~'
    'sudo rm -rf'
    ':(){ :|:& };:'
    'chmod 777'
    'dd if=/dev'
    'mkfs\.'
    'curl.*|.*bash'
    'wget.*|.*bash'
    'eval.*\$'
    '>\s*/dev/sd'
    'shutdown'
    'reboot'
    'init 0'
    'init 6'
)

# Check for dangerous patterns
for pattern in "${DANGEROUS_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qE "$pattern"; then
        echo "[${TIMESTAMP}] BLOCKED_BASH pattern='$pattern' command='${COMMAND:0:100}'" >> "${LOG_DIR}/security.log"
        echo '{"continue": false, "reason": "Dangerous command pattern detected: '"$pattern"'"}'
        exit 0
    fi
done

# Check for sensitive file access
SENSITIVE_PATHS=(
    '\.env'
    '\.ssh/'
    '\.aws/'
    '\.config/gcloud'
    'id_rsa'
    'id_ed25519'
    '\.pem$'
    'credentials'
    'secrets'
)

for path in "${SENSITIVE_PATHS[@]}"; do
    if echo "$COMMAND" | grep -qE "(cat|less|more|head|tail|vim|nano|vi)\s+.*$path"; then
        echo "[${TIMESTAMP}] WARN_BASH sensitive_path='$path' command='${COMMAND:0:100}'" >> "${LOG_DIR}/security.log"
        # Allow but log - actual blocking is in permissions.deny
    fi
done

# Log command for audit
echo "[${TIMESTAMP}] ALLOW_BASH command='${COMMAND:0:200}'" >> "${LOG_DIR}/bash.log"

echo '{"continue": true}'
