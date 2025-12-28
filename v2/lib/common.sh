#!/bin/bash
# =============================================================================
# common.sh - Shared utilities for tri-agent system
# =============================================================================
# This file MUST be sourced by all tri-agent scripts for:
# - Strict bash defaults
# - Trace ID generation
# - Common utilities
# - Library imports
#
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
# =============================================================================

# Library version for compatibility checking (#122)
COMMON_SH_VERSION="2.0.0"
export COMMON_SH_VERSION

# Strict bash defaults - fail fast, fail loud
set -euo pipefail
IFS=$'\n\t'

# =============================================================================
# Performance: Initialization Flag (#performance)
# =============================================================================
# Prevent redundant initialization when sourced multiple times
if [[ "${_COMMON_SH_INITIALIZED:-}" == "1" ]]; then
    return 0 2>/dev/null || true
fi

# =============================================================================
# Directory Configuration
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Default to parent of lib directory if not set (portable mode)
AUTONOMOUS_ROOT="${AUTONOMOUS_ROOT:-$(dirname "$SCRIPT_DIR")}"

# Directory paths
CONFIG_DIR="${AUTONOMOUS_ROOT}/config"
LIB_DIR="${AUTONOMOUS_ROOT}/lib"
BIN_DIR="${AUTONOMOUS_ROOT}/bin"
LOG_DIR="${AUTONOMOUS_ROOT}/logs"
STATE_DIR="${AUTONOMOUS_ROOT}/state"
TASKS_DIR="${AUTONOMOUS_ROOT}/tasks"
SESSIONS_DIR="${AUTONOMOUS_ROOT}/sessions"

# Subdirectories
LOCKS_DIR="${STATE_DIR}/locks"
BREAKERS_DIR="${STATE_DIR}/breakers"
RATE_LIMITS_DIR="${STATE_DIR}/rate-limits"
AUDIT_LOG_DIR="${LOG_DIR}/audit"
SESSION_LOG_DIR="${LOG_DIR}/sessions"
ERROR_LOG_DIR="${LOG_DIR}/errors"
COST_LOG_DIR="${LOG_DIR}/costs"
CHECKPOINTS_DIR="${SESSIONS_DIR}/checkpoints"
TASK_QUEUE_DIR="${TASKS_DIR}/queue"
TASK_RUNNING_DIR="${TASKS_DIR}/running"
TASK_COMPLETED_DIR="${TASKS_DIR}/completed"
TASK_FAILED_DIR="${TASKS_DIR}/failed"

# Files
TASK_LEDGER="${TASKS_DIR}/ledger.jsonl"
CONFIG_FILE="${CONFIG_DIR}/tri-agent.yaml"
ROUTING_POLICY="${CONFIG_DIR}/routing-policy.yaml"
HEALTH_STATUS="${STATE_DIR}/health.json"

# =============================================================================
# Trace ID Generation
# =============================================================================
# Every invocation gets a unique trace_id for correlation across logs
generate_trace_id() {
    local prefix="${1:-tri}"
    local timestamp
    local random_suffix

    timestamp="$(date +%Y%m%d%H%M%S)"

    # Try uuidgen first, fall back to /dev/urandom, then date+RANDOM
    if command -v uuidgen &>/dev/null; then
        random_suffix="$(uuidgen | cut -d'-' -f1)"
    elif [[ -r /dev/urandom ]]; then
        random_suffix="$(head -c 4 /dev/urandom | xxd -p)"
    else
        random_suffix="${RANDOM}${RANDOM}"
    fi

    echo "${prefix}-${timestamp}-${random_suffix}"
}

# Set trace ID if not already set (allows inheritance from parent process)
TRACE_ID="${TRACE_ID:-$(generate_trace_id)}"
export TRACE_ID

# =============================================================================
# Version Information
# =============================================================================
TRI_AGENT_VERSION="2.0.0"
TRI_AGENT_BUILD_DATE="2025-12-27"

# =============================================================================
# Color Codes (for terminal output)
# =============================================================================
if [[ -t 1 ]]; then
    # Terminal supports colors
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[0;37m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    # No color support
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    MAGENTA=''
    CYAN=''
    WHITE=''
    BOLD=''
    RESET=''
fi

# =============================================================================
# Basic Logging (minimal, before logging.sh is loaded)
# =============================================================================
_log_basic() {
    local level="$1"
    local message="$2"
    local timestamp
    local trace_prefix=""
    timestamp="$(date -Iseconds)"

    # Include TRACE_ID if available
    if [[ -n "${TRACE_ID:-}" ]]; then
        trace_prefix="[${TRACE_ID}] "
    fi

    echo -e "[${timestamp}] ${trace_prefix}[${level}] ${message}" >&2
}

log_debug() { [[ "${DEBUG:-0}" == "1" ]] && _log_basic "DEBUG" "$*" || true; }
log_info()  { _log_basic "${GREEN:-}INFO${RESET:-}" "$*"; }
log_warn()  { _log_basic "${YELLOW:-}WARN${RESET:-}" "$*"; }
log_error() { _log_basic "${RED:-}ERROR${RESET:-}" "$*"; }

# =============================================================================
# Utility Functions
# =============================================================================

# Check if a command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Require a command to exist, exit if not
require_command() {
    local cmd="$1"
    local package="${2:-$cmd}"
    if ! command_exists "$cmd"; then
        log_error "Required command '$cmd' not found. Install: $package"
        exit 1
    fi
}

# Get current timestamp in ISO 8601 format
iso_timestamp() {
    date -Iseconds
}

# Get current timestamp in epoch milliseconds
epoch_ms() {
    if date --version &>/dev/null 2>&1; then
        # GNU date
        echo "$(($(date +%s%N) / 1000000))"
    else
        # macOS/BSD date - fall back to seconds * 1000
        echo "$(($(date +%s) * 1000))"
    fi
}

# Ensure a directory exists
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_debug "Created directory: $dir"
    fi
}

# Ensure all required directories exist
ensure_all_dirs() {
    local dirs=(
        "$CONFIG_DIR"
        "$LIB_DIR"
        "$BIN_DIR"
        "$LOG_DIR"
        "$STATE_DIR"
        "$TASKS_DIR"
        "$SESSIONS_DIR"
        "$LOCKS_DIR"
        "$BREAKERS_DIR"
        "$RATE_LIMITS_DIR"
        "$AUDIT_LOG_DIR"
        "$SESSION_LOG_DIR"
        "$ERROR_LOG_DIR"
        "$COST_LOG_DIR"
        "$CHECKPOINTS_DIR"
        "$TASK_QUEUE_DIR"
        "$TASK_RUNNING_DIR"
        "$TASK_COMPLETED_DIR"
        "$TASK_FAILED_DIR"
    )

    for dir in "${dirs[@]}"; do
        ensure_dir "$dir"
    done
}

# Mask secrets in a string (for logging)
mask_secrets() {
    local input="$1"

    # Mask common API key patterns
    input=$(echo "$input" | sed -E 's/sk-[a-zA-Z0-9]{20,}/sk-***MASKED***/g')
    input=$(echo "$input" | sed -E 's/ANTHROPIC_API_KEY=[^ ]*/ANTHROPIC_API_KEY=***MASKED***/g')
    input=$(echo "$input" | sed -E 's/OPENAI_API_KEY=[^ ]*/OPENAI_API_KEY=***MASKED***/g')
    input=$(echo "$input" | sed -E 's/GOOGLE_API_KEY=[^ ]*/GOOGLE_API_KEY=***MASKED***/g')
    input=$(echo "$input" | sed -E 's/GEMINI_API_KEY=[^ ]*/GEMINI_API_KEY=***MASKED***/g')
    input=$(echo "$input" | sed -E 's/Bearer [a-zA-Z0-9._-]+/Bearer ***MASKED***/g')
    input=$(echo "$input" | sed -E 's/ghp_[a-zA-Z0-9]{36}/ghp_***MASKED***/g')
    input=$(echo "$input" | sed -E 's/gho_[a-zA-Z0-9]{36}/gho_***MASKED***/g')
    input=$(echo "$input" | sed -E 's/ghs_[a-zA-Z0-9]{36}/ghs_***MASKED***/g')
    input=$(echo "$input" | sed -E 's/github_pat_[a-zA-Z0-9_]{82}/github_pat_***MASKED***/g')
    # AWS keys
    input=$(echo "$input" | sed -E 's/AKIA[A-Z0-9]{16}/AKIA***MASKED***/g')
    input=$(echo "$input" | sed -E 's/AWS_SECRET_ACCESS_KEY=[^ ]*/AWS_SECRET_ACCESS_KEY=***MASKED***/g')
    # Azure keys
    input=$(echo "$input" | sed -E 's/DefaultEndpointsProtocol=[^;]*;AccountName=[^;]*;AccountKey=[^;]*/***AZURE_CONNECTION_MASKED***/g')
    # JWT tokens
    input=$(echo "$input" | sed -E 's/eyJ[a-zA-Z0-9_-]+\.eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+/***JWT_MASKED***/g')
    # Generic password/token/secret JSON patterns
    input=$(echo "$input" | sed -E 's/"password"\s*:\s*"[^"]*"/"password": "***MASKED***"/g')
    input=$(echo "$input" | sed -E 's/"token"\s*:\s*"[^"]*"/"token": "***MASKED***"/g')
    input=$(echo "$input" | sed -E 's/"secret"\s*:\s*"[^"]*"/"secret": "***MASKED***"/g')
    input=$(echo "$input" | sed -E 's/"api_key"\s*:\s*"[^"]*"/"api_key": "***MASKED***"/g')
    input=$(echo "$input" | sed -E 's/"apiKey"\s*:\s*"[^"]*"/"apiKey": "***MASKED***"/g')

    echo "$input"
}

# =============================================================================
# Performance: Config Caching (#performance)
# =============================================================================
# Cache config values to avoid repeated YAML parsing
declare -A _CONFIG_CACHE 2>/dev/null || true
_CONFIG_CACHE_FILE=""
_CONFIG_CACHE_MTIME=""

# Clear config cache (call when config changes)
clear_config_cache() {
    _CONFIG_CACHE=()
    _CONFIG_CACHE_FILE=""
    _CONFIG_CACHE_MTIME=""
}

# Check if config file has changed (invalidate cache)
_check_config_cache_validity() {
    local config="${1:-$CONFIG_FILE}"

    if [[ ! -f "$config" ]]; then
        return 1
    fi

    local current_mtime
    current_mtime=$(stat -c %Y "$config" 2>/dev/null || stat -f %m "$config" 2>/dev/null || echo "0")

    if [[ "$config" != "$_CONFIG_CACHE_FILE" ]] || [[ "$current_mtime" != "$_CONFIG_CACHE_MTIME" ]]; then
        # Config changed, invalidate cache
        _CONFIG_CACHE=()
        _CONFIG_CACHE_FILE="$config"
        _CONFIG_CACHE_MTIME="$current_mtime"
        return 1
    fi

    return 0
}

# Read a value from YAML config (requires yq or python3)
# Performance: Uses caching to avoid repeated YAML parsing
read_config() {
    local key="$1"
    local default="${2:-}"
    local config="${3:-$CONFIG_FILE}"

    if [[ ! -f "$config" ]]; then
        echo "$default"
        return
    fi

    # Check cache validity
    _check_config_cache_validity "$config" || true

    # Check if value is cached
    local cache_key="${config}:${key}"
    if [[ -n "${_CONFIG_CACHE[$cache_key]+isset}" ]]; then
        local cached_value="${_CONFIG_CACHE[$cache_key]}"
        if [[ -n "$cached_value" ]]; then
            echo "$cached_value"
        else
            echo "$default"
        fi
        return
    fi

    local value=""
    if command_exists yq; then
        value=$(yq -r "$key // \"\"" "$config" 2>/dev/null || echo "")
    elif command_exists python3; then
        value=$(python3 -c "
import yaml, sys
try:
    with open('$config') as f:
        cfg = yaml.safe_load(f)
    keys = '$key'.strip('.').split('.')
    v = cfg
    for k in keys:
        v = v.get(k, {}) if isinstance(v, dict) else {}
    print(v if v and v != {} else '')
except:
    print('')
" 2>/dev/null || echo "")
    fi

    # Cache the result
    _CONFIG_CACHE[$cache_key]="$value"

    echo "${value:-$default}"
}

# Validate that a value is a positive integer
_validate_numeric() {
    local value="$1"

    # Handle empty value
    if [[ -z "$value" ]]; then
        return 1
    fi

    # Check if it's a non-negative integer
    if [[ "$value" =~ ^[0-9]+$ ]]; then
        return 0
    fi

    return 1
}

# Validate JSON string
is_valid_json() {
    local json="$1"

    # Handle empty input
    if [[ -z "$json" ]]; then
        return 1
    fi

    if command_exists jq; then
        printf '%s' "$json" | jq . &>/dev/null
    elif command_exists python3; then
        # Use stdin to avoid shell escaping issues
        python3 -c "import json, sys; json.loads(sys.stdin.read())" <<< "$json" &>/dev/null
    else
        # Can't validate, assume valid
        return 0
    fi
}

# Get model display name
get_model_display_name() {
    local model="$1"
    case "$model" in
        claude|opus)     echo "Claude Opus 4.5" ;;
        gemini|pro)      echo "Gemini 3 Pro" ;;
        codex|gpt)       echo "Codex GPT-5.2" ;;
        *)               echo "$model" ;;
    esac
}

# =============================================================================
# Source Additional Libraries (if they exist)
# =============================================================================
# These are sourced conditionally to allow common.sh to work standalone
# during initial setup before other libraries are created

source_if_exists() {
    local lib="$1"
    if [[ -f "$lib" ]]; then
        # shellcheck source=/dev/null
        source "$lib"
        log_debug "Sourced library: $lib"
        return 0
    else
        log_debug "Library not found (skipped): $lib"
        return 1
    fi
}

# Source libraries in dependency order
# Note: These will be created in subsequent implementation steps
source_if_exists "${LIB_DIR}/state.sh"
source_if_exists "${LIB_DIR}/logging.sh"
source_if_exists "${LIB_DIR}/circuit-breaker.sh"
source_if_exists "${LIB_DIR}/error-handler.sh"
source_if_exists "${LIB_DIR}/cost-tracker.sh"

# =============================================================================
# Initialization
# =============================================================================
# Ensure required directories exist on source
ensure_all_dirs

# Log trace ID for debugging
log_debug "Trace ID: ${TRACE_ID}"

# =============================================================================
# JSON Envelope Parsing (#84 fix)
# =============================================================================

# Parse JSON envelope from delegate output
# Usage: parse_delegate_envelope "$json_output"
# Returns: Sets global variables DELEGATE_MODEL, DELEGATE_STATUS, DELEGATE_DECISION, etc.
# Performance: Uses a single jq call to extract all fields (#performance)
parse_delegate_envelope() {
    local json="$1"

    # Handle empty input
    if [[ -z "$json" ]]; then
        log_error "[${TRACE_ID:-unknown}] Empty JSON envelope provided" 2>/dev/null || true
        return 1
    fi

    if ! command_exists jq; then
        log_error "[${TRACE_ID:-unknown}] jq not found, cannot parse delegate envelope" 2>/dev/null || true
        return 1
    fi

    # Performance: Extract all fields in a single jq call
    local parsed
    parsed=$(printf '%s' "$json" | jq -r '
        [
            (.model // "unknown"),
            (.status // "error"),
            (.decision // "ABSTAIN"),
            (.confidence // 0 | tostring),
            (.reasoning // ""),
            (.output // ""),
            (.trace_id // ""),
            (.duration_ms // 0 | tostring)
        ] | @tsv
    ' 2>/dev/null) || {
        log_error "[${TRACE_ID:-unknown}] Invalid JSON envelope: ${json:0:100}..." 2>/dev/null || true
        return 1
    }

    # Parse tab-separated values
    IFS=$'\t' read -r DELEGATE_MODEL DELEGATE_STATUS DELEGATE_DECISION DELEGATE_CONFIDENCE \
        DELEGATE_REASONING DELEGATE_OUTPUT DELEGATE_TRACE_ID DELEGATE_DURATION_MS <<< "$parsed"

    export DELEGATE_MODEL DELEGATE_STATUS DELEGATE_DECISION DELEGATE_CONFIDENCE
    export DELEGATE_REASONING DELEGATE_OUTPUT DELEGATE_TRACE_ID DELEGATE_DURATION_MS

    return 0
}

# Extract specific field from JSON envelope
# Usage: get_delegate_field "$json" "field_name" ["default"]
get_delegate_field() {
    local json="$1"
    local field="$2"
    local default="${3:-}"

    # Handle empty input
    if [[ -z "$json" ]]; then
        echo "$default"
        return 1
    fi

    if ! command_exists jq; then
        echo "$default"
        return 1
    fi

    local value
    if [[ -z "$field" ]]; then
        echo "$default"
        return 1
    fi

    value=$(printf '%s' "$json" | jq -r --arg field "$field" --arg default "$default" '
        def to_path($s):
            $s
            | split(".")
            | map(select(length > 0))
            | map(if test("^[0-9]+$") then tonumber else . end);
        (to_path($field)) as $path
        | if ($path | length) == 0 then
              $default
          else
              (try getpath($path) catch null) as $v
              | if $v == null then $default else $v end
          end
    ' 2>/dev/null) || value="$default"
    echo "$value"
}

# Check if delegate call was successful
# Usage: if is_delegate_success "$json"; then ...
is_delegate_success() {
    local json="$1"

    # Handle empty input
    if [[ -z "$json" ]]; then
        return 1
    fi

    local status
    status=$(get_delegate_field "$json" "status" "error")
    [[ "$status" == "success" ]]
}

# =============================================================================
# Export Functions for Subshells
# =============================================================================
export -f command_exists
export -f require_command
export -f iso_timestamp
export -f epoch_ms
export -f ensure_dir
export -f ensure_all_dirs
export -f mask_secrets
export -f read_config
export -f is_valid_json
export -f get_model_display_name
export -f generate_trace_id
export -f _log_basic
export -f parse_delegate_envelope
export -f get_delegate_field
export -f is_delegate_success
export -f log_debug
export -f log_info
export -f log_warn
export -f log_error
export -f clear_config_cache
export -f _validate_numeric

# =============================================================================
# Performance: Mark Initialization Complete (#performance)
# =============================================================================
# This prevents redundant initialization when common.sh is sourced multiple times
_COMMON_SH_INITIALIZED=1
export _COMMON_SH_INITIALIZED
