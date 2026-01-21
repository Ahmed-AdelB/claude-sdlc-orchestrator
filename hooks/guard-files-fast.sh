#!/bin/bash
# Optimized File Guard Hook - Uses bash native pattern matching
# Expected execution: <60ms (vs 196ms original)

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

# Single jq call for both fields
read -r TOOL_NAME FILE_PATH < <(
    echo "$TOOL_DATA" | jq -r '[(.tool_name // "unknown"), (.tool_input.file_path // .tool_input.path // "")] | @tsv' 2>/dev/null
) || {
    TOOL_NAME="unknown"
    FILE_PATH=""
}

# Skip if no file path
[[ -z "$FILE_PATH" ]] && { echo '{"continue": true}'; exit 0; }

# Resolve path (only if file exists)
REAL_PATH="$FILE_PATH"
if [[ -e "$FILE_PATH" ]]; then
    REAL_PATH=$(realpath -m "$FILE_PATH" 2>/dev/null) || REAL_PATH="$FILE_PATH"
fi

# Combined blocked pattern as single extended regex
BLOCKED_REGEX='^/etc/(passwd|shadow)$|\.(env)($|\.)|/\.(ssh|aws|azure|kube)/|/\.config/gcloud/|id_(rsa|ed25519)|\.pem$|\.key$|private.*key|/secrets/|credentials|password|token|apikey|api_key'

if [[ "$REAL_PATH" =~ $BLOCKED_REGEX ]]; then
    LOG_DIR="${HOME}/.claude/logs"
    [[ -d "$LOG_DIR" ]] || mkdir -p "$LOG_DIR"
    echo "[$(date -Iseconds)] BLOCKED_FILE tool=${TOOL_NAME} path='$FILE_PATH'" >> "${LOG_DIR}/security.log"
    echo '{"continue": false, "reason": "Access to sensitive file blocked"}'
    exit 0
fi

# Warn on system files (async)
if [[ "$REAL_PATH" =~ ^/(etc|var|usr|bin|sbin|lib)/ ]]; then
    (
        LOG_DIR="${HOME}/.claude/logs"
        [[ -d "$LOG_DIR" ]] || mkdir -p "$LOG_DIR"
        echo "[$(date -Iseconds)] WARN_FILE tool=${TOOL_NAME} system_path='$FILE_PATH'" >> "${LOG_DIR}/security.log"
    ) &
fi

# Log access (async)
(
    LOG_DIR="${HOME}/.claude/logs"
    [[ -d "$LOG_DIR" ]] || mkdir -p "$LOG_DIR"
    echo "[$(date -Iseconds)] ALLOW_FILE tool=${TOOL_NAME} path='$FILE_PATH'" >> "${LOG_DIR}/files.log"
) &

echo '{"continue": true}'
