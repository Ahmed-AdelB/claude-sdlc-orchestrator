#!/bin/bash
# Optimized Bash Guard Hook - Uses bash native pattern matching
# Expected execution: <45ms (vs 159ms original)

set -uo pipefail

# Read input
TOOL_DATA=""
if read -t 1 -r line; then
    TOOL_DATA="$line"
    while read -t 0.1 -r line; do
        TOOL_DATA="${TOOL_DATA}${line}"
    done
fi

# Fast bypass check
if [[ "$TOOL_DATA" == *'"permission_mode":"bypassPermissions"'* ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Single jq call for command extraction
COMMAND=$(echo "$TOOL_DATA" | jq -r '.tool_input.command // ""' 2>/dev/null) || COMMAND=""

# Combined dangerous pattern as single regex (bash native matching)
# This eliminates 15+ grep subprocess calls
DANGEROUS_REGEX='rm[[:space:]]+-rf[[:space:]]+/|rm[[:space:]]+-rf[[:space:]]+~|sudo[[:space:]]+rm[[:space:]]+-rf|:\(\)\{[[:space:]]*:\|:&[[:space:]]*\};:|chmod[[:space:]]+777|dd[[:space:]]+if=/dev|mkfs\.|curl.*\|.*bash|wget.*\|.*bash|eval.*\$|>[[:space:]]*/dev/sd|shutdown|reboot|init[[:space:]]+[06]'

if [[ "$COMMAND" =~ $DANGEROUS_REGEX ]]; then
    LOG_DIR="${HOME}/.claude/logs"
    [[ -d "$LOG_DIR" ]] || mkdir -p "$LOG_DIR"
    echo "[$(date -Iseconds)] BLOCKED_BASH pattern_match command='${COMMAND:0:100}'" >> "${LOG_DIR}/security.log"
    echo '{"continue": false, "reason": "Dangerous command pattern detected"}'
    exit 0
fi

# Sensitive path warning (combined pattern, single check)
SENSITIVE_REGEX='\.(env|ssh|aws|pem)(/|$|[[:space:]])|id_(rsa|ed25519)|credentials|secrets'
if [[ "$COMMAND" =~ (cat|less|more|head|tail|vim|nano|vi)[[:space:]]+ ]] && [[ "$COMMAND" =~ $SENSITIVE_REGEX ]]; then
    LOG_DIR="${HOME}/.claude/logs"
    [[ -d "$LOG_DIR" ]] || mkdir -p "$LOG_DIR"
    echo "[$(date -Iseconds)] WARN_BASH sensitive_path command='${COMMAND:0:100}'" >> "${LOG_DIR}/security.log"
fi

# Log allowed command (async to not block)
(
    LOG_DIR="${HOME}/.claude/logs"
    [[ -d "$LOG_DIR" ]] || mkdir -p "$LOG_DIR"
    echo "[$(date -Iseconds)] ALLOW_BASH command='${COMMAND:0:200}'" >> "${LOG_DIR}/bash.log"
) &

echo '{"continue": true}'
