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
# Prevent redundant initialization when sourced multiple times.
# If the flag is inherited from the environment but core symbols are missing,
# continue initialization to avoid partial state.
if [[ "${_COMMON_SH_INITIALIZED:-}" == "1" ]]; then
    if declare -F command_exists >/dev/null 2>&1 && [[ -n "${CONFIG_FILE:-}" && -n "${AUTONOMOUS_ROOT:-}" ]]; then
        return 0 2>/dev/null || true
    fi
    unset _COMMON_SH_INITIALIZED
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

# SEC-010: Mask secrets in a string (for safe logging)
# Comprehensive secret masking to prevent credential leakage in logs
mask_secrets() {
    local input="$1"
    local masked="$input"

    # =========================================================================
    # API Keys (Vendor-specific patterns)
    # =========================================================================
    # OpenAI / Anthropic (use [^ ] for non-space, more portable than \s)
    masked=$(echo "$masked" | sed -E 's/(ANTHROPIC_API_KEY=)[^ ]+/\1[REDACTED]/g')
    masked=$(echo "$masked" | sed -E 's/(OPENAI_API_KEY=)[^ ]+/\1[REDACTED]/g')
    masked=$(echo "$masked" | sed -E 's/sk-proj-[a-zA-Z0-9]{20,}/sk-proj-[REDACTED]/g')
    masked=$(echo "$masked" | sed -E 's/sk-[a-zA-Z0-9-]{20,}/sk-[REDACTED]/g')

    # Google
    masked=$(echo "$masked" | sed -E 's/(GOOGLE_API_KEY=)[^ ]+/\1[REDACTED]/g')
    masked=$(echo "$masked" | sed -E 's/(GEMINI_API_KEY=)[^ ]+/\1[REDACTED]/g')
    masked=$(echo "$masked" | sed -E 's/AIza[a-zA-Z0-9_-]{30,}/AIza[REDACTED]/g')

    # =========================================================================
    # GitHub / GitLab tokens
    # =========================================================================
    masked=$(echo "$masked" | sed -E 's/ghp_[a-zA-Z0-9]{36,}/ghp_[REDACTED]/g')
    masked=$(echo "$masked" | sed -E 's/gho_[a-zA-Z0-9]{36,}/gho_[REDACTED]/g')
    masked=$(echo "$masked" | sed -E 's/ghs_[a-zA-Z0-9]{36,}/ghs_[REDACTED]/g')
    masked=$(echo "$masked" | sed -E 's/ghr_[a-zA-Z0-9]{36,}/ghr_[REDACTED]/g')
    masked=$(echo "$masked" | sed -E 's/github_pat_[a-zA-Z0-9_]{22,}/github_pat_[REDACTED]/g')
    masked=$(echo "$masked" | sed -E 's/glpat-[a-zA-Z0-9_-]{20,}/glpat-[REDACTED]/g')

    # =========================================================================
    # AWS credentials
    # =========================================================================
    masked=$(echo "$masked" | sed -E 's/(AWS_ACCESS_KEY_ID=)[A-Z0-9]{20}/\1[REDACTED]/g')
    masked=$(echo "$masked" | sed -E 's/(AWS_SECRET_ACCESS_KEY=)[^ ]+/\1[REDACTED]/g')
    masked=$(echo "$masked" | sed -E 's/((A3T|AKIA|ASIA|AGPA|AIDA|ANPA|ANVA|AROA|AIPA|APKA))[A-Z0-9]{16}/\1[REDACTED]/g')

    # =========================================================================
    # Azure credentials
    # =========================================================================
    masked=$(echo "$masked" | sed -E 's/(AZURE_[A-Z_]*KEY=)[^ ]+/\1[REDACTED]/g')
    masked=$(echo "$masked" | sed -E 's/DefaultEndpointsProtocol=[^;]*;AccountName=[^;]*;AccountKey=[^;]*/[AZURE_CONNECTION_REDACTED]/g')

    # =========================================================================
    # Generic patterns (case-insensitive where applicable)
    # =========================================================================
    # Environment variable patterns
    masked=$(echo "$masked" | sed -E 's/(password=)[^ ]+/\1[REDACTED]/gi')
    masked=$(echo "$masked" | sed -E 's/(secret=)[^ ]+/\1[REDACTED]/gi')
    masked=$(echo "$masked" | sed -E 's/(token=)[^ ]+/\1[REDACTED]/gi')

    # HTTP Headers
    masked=$(echo "$masked" | sed -E 's/(bearer )[a-zA-Z0-9._-]+/\1[REDACTED]/gi')
    masked=$(echo "$masked" | sed -E 's/([Aa]uthorization:\s*)[^\n]+/\1[REDACTED]/g')
    masked=$(echo "$masked" | sed -E 's/([Xx]-[Aa]pi-[Kk]ey:\s*)[^\n]+/\1[REDACTED]/g')

    # =========================================================================
    # JWT tokens
    # =========================================================================
    masked=$(echo "$masked" | sed -E 's/eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}/[JWT_REDACTED]/g')

    # =========================================================================
    # OAuth tokens
    # =========================================================================
    masked=$(echo "$masked" | sed -E 's/(oauth[_-]?token=)[^ ]+/\1[REDACTED]/gi')
    masked=$(echo "$masked" | sed -E 's/(oauth[_-]?secret=)[^ ]+/\1[REDACTED]/gi')
    masked=$(echo "$masked" | sed -E 's/(access_token=)[^ ]+/\1[REDACTED]/gi')
    masked=$(echo "$masked" | sed -E 's/(refresh_token=)[^ ]+/\1[REDACTED]/gi')
    masked=$(echo "$masked" | sed -E 's/(id_token=)[^ ]+/\1[REDACTED]/gi')
    masked=$(echo "$masked" | sed -E 's/ya29\.[a-zA-Z0-9._-]{20,}/ya29.[REDACTED]/g')

    # =========================================================================
    # JSON object patterns
    # =========================================================================
    masked=$(echo "$masked" | sed -E 's/"password"\s*:\s*"[^"]*"/"password": "[REDACTED]"/g')
    masked=$(echo "$masked" | sed -E 's/"token"\s*:\s*"[^"]*"/"token": "[REDACTED]"/g')
    masked=$(echo "$masked" | sed -E 's/"secret"\s*:\s*"[^"]*"/"secret": "[REDACTED]"/g')
    masked=$(echo "$masked" | sed -E 's/"api_key"\s*:\s*"[^"]*"/"api_key": "[REDACTED]"/g')
    masked=$(echo "$masked" | sed -E 's/"apiKey"\s*:\s*"[^"]*"/"apiKey": "[REDACTED]"/g')
    masked=$(echo "$masked" | sed -E 's/"access_token"\s*:\s*"[^"]*"/"access_token": "[REDACTED]"/g')
    masked=$(echo "$masked" | sed -E 's/"refresh_token"\s*:\s*"[^"]*"/"refresh_token": "[REDACTED]"/g')

    # =========================================================================
    # Database connection strings
    # =========================================================================
    masked=$(echo "$masked" | sed -E 's|(postgres(ql)?://)[^:]+:[^@]+@|\1[REDACTED]@|g')
    masked=$(echo "$masked" | sed -E 's|(mysql://)[^:]+:[^@]+@|\1[REDACTED]@|g')
    masked=$(echo "$masked" | sed -E 's|(mariadb://)[^:]+:[^@]+@|\1[REDACTED]@|g')
    masked=$(echo "$masked" | sed -E 's|(mongodb(\+srv)?://)[^:]+:[^@]+@|\1[REDACTED]@|g')
    masked=$(echo "$masked" | sed -E 's|(rediss?://)[^@]+@|\1[REDACTED]@|g')
    masked=$(echo "$masked" | sed -E 's|(sqlserver://)[^:]+:[^@]+@|\1[REDACTED]@|g')
    masked=$(echo "$masked" | sed -E 's|(mssql://)[^:]+:[^@]+@|\1[REDACTED]@|g')
    masked=$(echo "$masked" | sed -E 's|(oracle://)[^:]+:[^@]+@|\1[REDACTED]@|g')
    masked=$(echo "$masked" | sed -E 's|(cockroachdb://)[^:]+:[^@]+@|\1[REDACTED]@|g')
    masked=$(echo "$masked" | sed -E 's#(jdbc:(postgresql|mysql|mariadb|sqlserver|oracle)://)[^:]+:[^@]+@#\1[REDACTED]@#g')

    # =========================================================================
    # Slack / Stripe / Twilio / SendGrid
    # =========================================================================
    masked=$(echo "$masked" | sed -E 's/xox[baprs]-[a-zA-Z0-9-]+/xox[REDACTED]/g')
    masked=$(echo "$masked" | sed -E 's/sk_live_[a-zA-Z0-9]{24,}/sk_live_[REDACTED]/g')
    masked=$(echo "$masked" | sed -E 's/sk_test_[a-zA-Z0-9]{24,}/sk_test_[REDACTED]/g')
    masked=$(echo "$masked" | sed -E 's/rk_live_[a-zA-Z0-9]{24,}/rk_live_[REDACTED]/g')
    masked=$(echo "$masked" | sed -E 's/rk_test_[a-zA-Z0-9]{24,}/rk_test_[REDACTED]/g')
    masked=$(echo "$masked" | sed -E 's/pk_live_[a-zA-Z0-9]{24,}/pk_live_[REDACTED]/g')
    masked=$(echo "$masked" | sed -E 's/pk_test_[a-zA-Z0-9]{24,}/pk_test_[REDACTED]/g')
    masked=$(echo "$masked" | sed -E 's/SK[a-f0-9]{32}/SK[REDACTED]/g')
    masked=$(echo "$masked" | sed -E 's/SG\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+/SG.[REDACTED]/g')

    # =========================================================================
    # Private key headers (log warning, don't expose)
    # =========================================================================
    masked=$(echo "$masked" | sed -E 's/-----BEGIN PRIVATE KEY-----/[PRIVATE_KEY_REDACTED]/g')
    masked=$(echo "$masked" | sed -E 's/-----BEGIN ENCRYPTED PRIVATE KEY-----/[PRIVATE_KEY_REDACTED]/g')
    masked=$(echo "$masked" | sed -E 's/-----BEGIN RSA PRIVATE KEY-----/[PRIVATE_KEY_REDACTED]/g')
    masked=$(echo "$masked" | sed -E 's/-----BEGIN EC PRIVATE KEY-----/[PRIVATE_KEY_REDACTED]/g')
    masked=$(echo "$masked" | sed -E 's/-----BEGIN DSA PRIVATE KEY-----/[PRIVATE_KEY_REDACTED]/g')
    masked=$(echo "$masked" | sed -E 's/-----BEGIN OPENSSH PRIVATE KEY-----/[PRIVATE_KEY_REDACTED]/g')
    masked=$(echo "$masked" | sed -E 's/-----BEGIN PGP PRIVATE KEY BLOCK-----/[PGP_PRIVATE_KEY_REDACTED]/g')

    echo "$masked"
}

# =============================================================================
# Secure Binary Resolution (SEC-008C)
# =============================================================================
# Resolves binaries to absolute paths to prevent PATH hijacking attacks.
# Validates binaries exist and are executable before use.
# SECURITY: Attackers can prepend malicious directories to PATH. By resolving
# to absolute paths in trusted directories, we prevent execution of rogue binaries.
# =============================================================================

# Known safe paths for common binaries (customize per system)
# These are checked first before falling back to PATH lookup
declare -A SECURE_BINARY_PATHS=(
    ["sqlite3"]="/usr/bin/sqlite3"
    ["python3"]="/usr/bin/python3"
    ["python"]="/usr/bin/python3"
    ["jq"]="/usr/bin/jq"
    ["npm"]="/usr/bin/npm"
    ["npx"]="/usr/bin/npx"
    ["node"]="/usr/bin/node"
    ["git"]="/usr/bin/git"
    ["curl"]="/usr/bin/curl"
    ["grep"]="/bin/grep"
    ["sed"]="/bin/sed"
    ["awk"]="/usr/bin/awk"
    ["bash"]="/bin/bash"
    ["sh"]="/bin/sh"
    ["date"]="/bin/date"
    ["cat"]="/bin/cat"
    ["mkdir"]="/bin/mkdir"
    ["rm"]="/bin/rm"
    ["mv"]="/bin/mv"
    ["cp"]="/bin/cp"
    ["chmod"]="/bin/chmod"
    ["chown"]="/bin/chown"
    ["stat"]="/usr/bin/stat"
    ["find"]="/usr/bin/find"
    ["xargs"]="/usr/bin/xargs"
    ["tee"]="/usr/bin/tee"
    ["wc"]="/usr/bin/wc"
    ["sort"]="/usr/bin/sort"
    ["uniq"]="/usr/bin/uniq"
    ["head"]="/usr/bin/head"
    ["tail"]="/usr/bin/tail"
    ["cut"]="/usr/bin/cut"
    ["tr"]="/usr/bin/tr"
    ["env"]="/usr/bin/env"
    ["make"]="/usr/bin/make"
    ["cargo"]="/usr/bin/cargo"
    ["go"]="/usr/bin/go"
    ["ruff"]="/usr/bin/ruff"
    ["mypy"]="/usr/bin/mypy"
    ["shellcheck"]="/usr/bin/shellcheck"
    ["pipenv"]="/usr/bin/pipenv"
    ["pytest"]="/usr/bin/pytest"
)

# Trusted directories for binary lookup (in priority order)
SECURE_BINARY_DIRS=("/usr/bin" "/bin" "/usr/local/bin" "/usr/sbin" "/sbin")

# Resolve binary to absolute path securely
# Usage: bin_path=$(secure_which "sqlite3")
# Returns: Absolute path to binary, or exits with error code 1 if not found
secure_which() {
    local binary="$1"
    local resolved=""

    # First check known secure paths
    # Use -v to check if key exists in associative array (safer with set -u)
    if [[ -v SECURE_BINARY_PATHS && -v "SECURE_BINARY_PATHS[$binary]" ]]; then
        resolved="${SECURE_BINARY_PATHS[$binary]}"
        if [[ -x "$resolved" ]]; then
            echo "$resolved"
            return 0
        fi
    fi

    # Fall back to standard locations
    for path in "${SECURE_BINARY_DIRS[@]}"; do
        if [[ -x "$path/$binary" ]]; then
            resolved="$path/$binary"
            echo "$resolved"
            return 0
        fi
    done

    # Last resort: use 'command -v' but verify result is in trusted path
    resolved=$(command -v "$binary" 2>/dev/null || true)
    if [[ -n "$resolved" ]]; then
        # Verify resolved path is in trusted directory
        local resolved_dir
        resolved_dir=$(dirname "$resolved")
        local is_trusted=false
        for trusted_dir in "${SECURE_BINARY_DIRS[@]}"; do
            if [[ "$resolved_dir" == "$trusted_dir" ]]; then
                is_trusted=true
                break
            fi
        done

        if [[ "$is_trusted" == "true" ]]; then
            echo "$resolved"
            return 0
        else
            log_warn "SEC-008C: Binary $binary found in untrusted path: $resolved" 2>/dev/null || true
            return 1
        fi
    fi

    log_debug "SEC-008C: Secure binary not found: $binary" 2>/dev/null || true
    return 1
}

# Execute binary securely with absolute path
# Usage: secure_exec "sqlite3" "$db" "SELECT 1"
# This ensures the binary is resolved to an absolute path before execution
secure_exec() {
    local binary="$1"
    shift
    local bin_path

    bin_path=$(secure_which "$binary") || {
        log_error "SEC-008C: Cannot find secure path for: $binary" >&2
        return 1
    }

    "$bin_path" "$@"
}

# Clear potentially dangerous environment variables before executing
# Usage: safe_env_exec "python3" script.py
# This prevents attacks via PYTHONPATH, LD_PRELOAD, etc.
safe_env_exec() {
    local binary="$1"
    shift
    local bin_path

    bin_path=$(secure_which "$binary") || {
        log_error "SEC-008C: Cannot find secure path for: $binary" >&2
        return 1
    }

    # Clear dangerous env vars that could be used for code injection
    # SEC-P1-12: Python env vars (dependency hijacking prevention)
    # - PYTHONPATH: Controls module search path
    # - PYTHONHOME: Controls Python installation location
    # - PYTHONSTARTUP: Script executed on interpreter startup
    env -u PYTHONPATH \
        -u PYTHONHOME \
        -u PYTHONSTARTUP \
        -u LD_PRELOAD \
        -u LD_LIBRARY_PATH \
        -u NODE_OPTIONS \
        -u NODE_PATH \
        -u RUBYLIB \
        -u RUBYOPT \
        -u PERL5LIB \
        -u PERL5OPT \
        "$bin_path" "$@"
}

# Validate that a binary path is in a trusted directory
# Usage: if is_trusted_binary_path "/usr/bin/python3"; then ...
is_trusted_binary_path() {
    local binary_path="$1"

    # Must be an absolute path
    if [[ "$binary_path" != /* ]]; then
        return 1
    fi

    # Must exist and be executable
    if [[ ! -x "$binary_path" ]]; then
        return 1
    fi

    local binary_dir
    binary_dir=$(dirname "$binary_path")

    for trusted_dir in "${SECURE_BINARY_DIRS[@]}"; do
        if [[ "$binary_dir" == "$trusted_dir" ]]; then
            return 0
        fi
    done

    return 1
}

# Log security event for binary resolution
# Usage: log_security_event "PATH_HIJACK_RISK" "message" "WARN"
log_security_event() {
    local event_type="$1"
    local message="$2"
    local level="${3:-WARN}"
    local timestamp
    timestamp=$(iso_timestamp 2>/dev/null || date -Iseconds)

    local log_entry="[${timestamp}] [${TRACE_ID:-unknown}] [SECURITY] [${level}] ${event_type}: ${message}"
    echo "$log_entry" >&2

    # Also log to security audit file if available
    local security_log="${AUDIT_LOG_DIR:-/tmp}/security-events.log"
    echo "$log_entry" >> "$security_log" 2>/dev/null || true
}

# =============================================================================
# Git Output Sanitization (SEC-001)
# =============================================================================
# Prevents prompt injection attacks via git commit messages and diff output.
# Strips known LLM control sequences that could hijack agent behavior.
# =============================================================================

# Sanitize git log/diff output to prevent prompt injection
# Usage: sanitized_output=$(git log -1 | sanitize_git_log)
# Or:    sanitize_git_log "$git_output"
sanitize_git_log() {
    local input="${1:-}"

    # If no argument, read from stdin
    if [[ -z "$input" ]]; then
        input=$(cat)
    fi

    # Return empty if input is empty
    [[ -z "$input" ]] && return 0

    # Remove LLM control sequences and prompt injection patterns
    # These patterns are case-insensitive
    # Use multiple sed calls for better compatibility across sed versions
    echo "$input" | \
        sed -E 's/\[SYSTEM\]//gi' | \
        sed -E 's/\[INST\]//gi' | \
        sed -E 's/\[\/INST\]//gi' | \
        sed -E 's/<\|[^|]*\|>//g' | \
        sed -E 's/<<SYS>>//gi' | \
        sed -E 's/<<\/SYS>>//gi' | \
        sed -E 's/IGNORE[[:space:]]+PREVIOUS[[:space:]]+INSTRUCTIONS//gi' | \
        sed -E 's/IGNORE[[:space:]]+ALL[[:space:]]+PREVIOUS[[:space:]]+INSTRUCTIONS//gi' | \
        sed -E 's/DISREGARD[[:space:]]+.*ABOVE//gi' | \
        sed -E 's/FORGET[[:space:]]+.*INSTRUCTIONS//gi' | \
        sed -E 's/NEW[[:space:]]+INSTRUCTIONS[[:space:]]*://gi' | \
        sed -E 's/OVERRIDE[[:space:]]+SYSTEM//gi' | \
        sed -E 's/OUTPUT[[:space:]]*:[[:space:]]*APPROVED//gi' | \
        sed -E 's/RESULT[[:space:]]*:[[:space:]]*APPROVED//gi' | \
        sed -E 's/MARK[[:space:]]+.*AS[[:space:]]+APPROVED//gi' | \
        sed -E 's/EXECUTE[[:space:]]*:.*//gi' | \
        sed -E 's/RUN[[:space:]]*:.*//gi' | \
        sed -E 's/SHELL[[:space:]]*:.*//gi' | \
        sed -E 's/YOU[[:space:]]+ARE[[:space:]]+NOW//gi' | \
        sed -E 's/ACT[[:space:]]+AS[[:space:]]+IF//gi' | \
        sed -E 's/PRETEND[[:space:]]+YOU[[:space:]]+ARE//gi' | \
        sed -E 's/base64[[:space:]]*\|[[:space:]]*curl//gi' | \
        sed -E 's/curl.*base64//gi'
}

# SEC-006: Sanitize task content before sending to LLM
# Prevents prompt injection attacks by stripping known LLM control sequences
# Usage: sanitized=$(sanitize_llm_input "$task_content")
# Features:
#   - Strips [SYSTEM], [INST], ```system, ```assistant patterns
#   - Removes embedded system prompts between delimiters
#   - Limits content to 100KB (102400 bytes) to prevent context overflow
sanitize_llm_input() {
    local input="${1:-}"

    # Return empty if no input provided
    [[ -z "$input" ]] && return 0

    # Apply git log sanitization (covers most injection patterns)
    local sanitized
    sanitized=$(sanitize_git_log "$input")

    # Additional sanitization for task content
    # Remove embedded system prompts (match content between delimiters)
    # Remove markdown code block system/assistant markers
    sanitized=$(echo "$sanitized" | \
        sed -E 's/###[[:space:]]*SYSTEM[^#]*###//gi' | \
        sed -E 's/---[[:space:]]*SYSTEM[^-]*---//gi' | \
        sed -E 's/\*\*\*[[:space:]]*SYSTEM[^*]*\*\*\*//gi' | \
        sed -E 's/```system//gi' | \
        sed -E 's/```assistant//gi' | \
        sed -E 's/```user//gi' | \
        head -c 102400)

    echo "$sanitized"
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
# Security library MUST be sourced first for verify_integrity and other security functions
source_if_exists "${LIB_DIR}/security.sh"
source_if_exists "${LIB_DIR}/state.sh"
source_if_exists "${LIB_DIR}/logging.sh"
source_if_exists "${LIB_DIR}/circuit-breaker.sh"
source_if_exists "${LIB_DIR}/error-handler.sh"
source_if_exists "${LIB_DIR}/cost-tracker.sh"
source_if_exists "${LIB_DIR}/cost-breaker.sh"
source_if_exists "${LIB_DIR}/priority-queue.sh"
source_if_exists "${LIB_DIR}/rag-context.sh"
source_if_exists "${LIB_DIR}/event-store.sh"
source_if_exists "${LIB_DIR}/model-diversity.sh"

# =============================================================================
# Initialization
# =============================================================================
# Ensure required directories exist on source
ensure_all_dirs

# Log trace ID for debugging
log_debug "Trace ID: ${TRACE_ID}"

# =============================================================================
# SEC-P1-10: Critical Binary Integrity Verification
# =============================================================================
# Verifies critical binaries (sqlite3, python3, jq) are in trusted paths at startup.
# Uses verify_integrity() from security.sh if hash baselines exist, otherwise
# validates binaries are in trusted directories using secure_which().
# Logs warnings but does not crash on verification failure to allow graceful degradation.
# =============================================================================

# File to store binary hash baselines (created on first run)
BINARY_HASH_BASELINE="${STATE_DIR}/binary-hashes.baseline"

# Verify a critical binary and optionally check its hash
# Usage: _verify_critical_binary "binary_name"
# Returns: 0 if verified, 1 if verification failed (but logs warning, doesn't crash)
_verify_critical_binary() {
    local binary="$1"
    local binary_path=""
    local verification_status="unknown"

    # Step 1: Resolve binary to trusted path using secure_which
    binary_path=$(secure_which "$binary" 2>/dev/null) || {
        log_warn "SEC-P1-10: Critical binary '$binary' not found in trusted paths"
        log_security_event "BINARY_NOT_FOUND" "Critical binary $binary not in trusted paths" "WARN"
        return 1
    }

    # Step 2: Verify the path is in a trusted directory
    if ! is_trusted_binary_path "$binary_path"; then
        log_warn "SEC-P1-10: Binary '$binary' at '$binary_path' is not in a trusted directory"
        log_security_event "BINARY_UNTRUSTED_PATH" "Binary $binary at $binary_path is not in trusted directory" "WARN"
        return 1
    fi

    # Step 3: Hash-based verification if security.sh verify_integrity is available
    # and baseline exists
    if declare -F verify_integrity >/dev/null 2>&1 && [[ -f "$BINARY_HASH_BASELINE" ]]; then
        local expected_hash=""
        expected_hash=$(grep "^${binary}:" "$BINARY_HASH_BASELINE" 2>/dev/null | cut -d: -f2)

        if [[ -n "$expected_hash" ]]; then
            if verify_integrity "$binary_path" "$expected_hash"; then
                verification_status="hash_verified"
                log_debug "SEC-P1-10: Binary '$binary' hash verified successfully"
            else
                log_warn "SEC-P1-10: Binary '$binary' hash mismatch - possible tampering or update"
                log_security_event "BINARY_HASH_MISMATCH" "Binary $binary at $binary_path hash mismatch" "WARN"
                verification_status="hash_mismatch"
                # Don't fail - binary may have been legitimately updated
            fi
        else
            verification_status="path_verified"
            log_debug "SEC-P1-10: Binary '$binary' verified in trusted path (no baseline hash)"
        fi
    else
        verification_status="path_verified"
        log_debug "SEC-P1-10: Binary '$binary' verified in trusted path"
    fi

    return 0
}

# Initialize or update binary hash baseline
# Usage: _init_binary_hash_baseline
# Creates baseline file with hashes of critical binaries on first run
_init_binary_hash_baseline() {
    local critical_binaries=("sqlite3" "python3" "jq")
    local needs_update=false

    # Only initialize if baseline doesn't exist
    if [[ ! -f "$BINARY_HASH_BASELINE" ]]; then
        needs_update=true
        log_info "SEC-P1-10: Initializing binary hash baseline"
    fi

    if [[ "$needs_update" == "true" ]]; then
        ensure_dir "$(dirname "$BINARY_HASH_BASELINE")"

        for binary in "${critical_binaries[@]}"; do
            local binary_path=""
            binary_path=$(secure_which "$binary" 2>/dev/null) || continue

            if [[ -x "$binary_path" ]]; then
                local hash=""
                hash=$(sha256sum "$binary_path" 2>/dev/null | cut -d' ' -f1) || continue
                echo "${binary}:${hash}" >> "$BINARY_HASH_BASELINE"
                log_debug "SEC-P1-10: Recorded baseline hash for $binary"
            fi
        done

        # Set restrictive permissions on baseline file
        chmod 600 "$BINARY_HASH_BASELINE" 2>/dev/null || true
        log_info "SEC-P1-10: Binary hash baseline created at $BINARY_HASH_BASELINE"
    fi
}

# Verify all critical binaries at startup
# Called during common.sh initialization
# Logs warnings but does not exit on failure
_verify_critical_binaries_at_startup() {
    local critical_binaries=("sqlite3" "python3" "jq")
    local failed_count=0
    local verified_count=0

    # Skip verification if explicitly disabled
    if [[ "${SKIP_BINARY_VERIFICATION:-0}" == "1" ]]; then
        log_debug "SEC-P1-10: Binary verification skipped (SKIP_BINARY_VERIFICATION=1)"
        return 0
    fi

    # Initialize baseline if needed (first run)
    _init_binary_hash_baseline

    # Verify each critical binary
    for binary in "${critical_binaries[@]}"; do
        if _verify_critical_binary "$binary"; then
            ((verified_count++)) || true
        else
            ((failed_count++)) || true
        fi
    done

    # Log summary
    if [[ $failed_count -gt 0 ]]; then
        log_warn "SEC-P1-10: Binary verification completed with $failed_count warning(s), $verified_count verified"
    else
        log_debug "SEC-P1-10: All $verified_count critical binaries verified successfully"
    fi

    # Return success even if some verifications failed (graceful degradation)
    return 0
}

# Run verification at startup (non-blocking)
_verify_critical_binaries_at_startup || true

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
# File Locking Utilities (SEC-007)
# =============================================================================
# Provides secure file locking to prevent race conditions and data corruption
# when multiple processes write to shared files (e.g., ledger, logs).
# Uses flock for portable advisory locking with timeout support.
# =============================================================================

# FIX-004: Lock configuration with increased timeouts
# Default lock timeout increased to prevent contention under load
LEDGER_LOCK_TIMEOUT="${LEDGER_LOCK_TIMEOUT:-10}"
LOG_FILE_LOCK_TIMEOUT="${LOG_FILE_LOCK_TIMEOUT:-5}"
DEFAULT_LOCK_TIMEOUT="${DEFAULT_LOCK_TIMEOUT:-10}"
MAX_LOCK_RETRIES="${MAX_LOCK_RETRIES:-3}"

# INC-ARCH-005: Lock timeout optimization and stale lock handling
LOCK_BACKOFF_INITIAL="${LOCK_BACKOFF_INITIAL:-1}"
LOCK_BACKOFF_MAX="${LOCK_BACKOFF_MAX:-8}"
LOCK_STALE_TIMEOUT_SECONDS="${LOCK_STALE_TIMEOUT_SECONDS:-300}"
LOCK_AUTO_RELEASE_STALE="${LOCK_AUTO_RELEASE_STALE:-1}"
LOCK_DEADLOCK_WARN_SECONDS="${LOCK_DEADLOCK_WARN_SECONDS:-$LOCK_STALE_TIMEOUT_SECONDS}"
LOCK_METRICS_ENABLED="${LOCK_METRICS_ENABLED:-1}"
LOCK_METRICS_FILE="${LOCK_METRICS_FILE:-${LOCKS_DIR}/lock-metrics.jsonl}"
LOCK_METRICS_LOCK="${LOCK_METRICS_LOCK:-${LOCKS_DIR}/lock-metrics.lock}"

_lock_epoch_seconds() { date +%s; }

_lock_json_escape() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

_lock_file_mtime() {
    local file="$1"
    stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null || echo "0"
}

_lock_file_age_seconds() {
    local file="$1"
    [[ -f "$file" ]] || { echo "0"; return; }
    local now
    local mtime
    now=$(_lock_epoch_seconds)
    mtime=$(_lock_file_mtime "$file")
    if ! _validate_numeric "$mtime"; then
        echo "0"
        return
    fi
    echo $((now - mtime))
}

_lock_get_metadata_value() {
    local lock_file="$1"
    local key="$2"
    [[ -f "$lock_file" ]] || return 1
    awk -v key="$key" '
        {
            for (i = 1; i <= NF; i++) {
                if ($i ~ "^" key "=") {
                    sub("^" key "=", "", $i)
                    print $i
                    exit
                }
            }
        }
    ' "$lock_file" 2>/dev/null || true
}

_lock_write_metadata() {
    local lock_file="$1"
    local ts
    ts=$(_lock_epoch_seconds)
    printf 'pid=%s ts=%s trace=%s\n' "$$" "$ts" "${TRACE_ID:-}" > "$lock_file" 2>/dev/null || true
}

_lock_pid_alive() {
    local pid="$1"
    [[ -n "$pid" ]] || return 1
    kill -0 "$pid" 2>/dev/null
}

_lock_age_seconds() {
    local lock_file="$1"
    local now
    local ts
    local mtime
    local latest=0
    now=$(_lock_epoch_seconds)
    ts=$(_lock_get_metadata_value "$lock_file" "ts")
    mtime=$(_lock_file_mtime "$lock_file")
    if _validate_numeric "$mtime"; then
        latest="$mtime"
    fi
    if _validate_numeric "$ts" && [[ "$ts" -gt "$latest" ]]; then
        latest="$ts"
    fi
    if ! _validate_numeric "$latest"; then
        echo "0"
        return
    fi
    echo $((now - latest))
}

_lock_record_metric() {
    local event="$1"
    local lock_file="$2"
    local attempt="${3:-}"
    local wait_s="${4:-}"
    local elapsed_s="${5:-}"
    local detail="${6:-}"

    [[ "${LOCK_METRICS_ENABLED}" == "1" ]] || return 0

    local ts
    ts=$(date -Iseconds)
    local lock_escaped
    lock_escaped=$(_lock_json_escape "$lock_file")
    local json
    json="{\"timestamp\":\"${ts}\",\"event\":\"${event}\",\"lock_file\":\"${lock_escaped}\",\"pid\":$$"
    if [[ -n "${TRACE_ID:-}" ]]; then
        json+=",\"trace_id\":\"$(_lock_json_escape "${TRACE_ID}")\""
    fi
    if _validate_numeric "$attempt"; then
        json+=",\"attempt\":${attempt}"
    fi
    if _validate_numeric "$wait_s"; then
        json+=",\"wait_s\":${wait_s}"
    fi
    if _validate_numeric "$elapsed_s"; then
        json+=",\"elapsed_s\":${elapsed_s}"
    fi
    if [[ -n "$detail" ]]; then
        json+=",\"detail\":\"$(_lock_json_escape "$detail")\""
    fi
    json+="}"

    mkdir -p "$(dirname "$LOCK_METRICS_FILE")" 2>/dev/null || true
    (
        flock -n 299 2>/dev/null || true
        printf '%s\n' "$json" >> "$LOCK_METRICS_FILE" 2>/dev/null || true
    ) 299>"$LOCK_METRICS_LOCK" 2>/dev/null || true
}

_lock_deadlock_heuristic() {
    local lock_file="$1"
    local attempt="${2:-}"
    local age
    age=$(_lock_age_seconds "$lock_file")
    if ! _validate_numeric "$age"; then
        return 1
    fi
    if ! _validate_numeric "$LOCK_DEADLOCK_WARN_SECONDS"; then
        return 1
    fi
    if [[ "$age" -lt "$LOCK_DEADLOCK_WARN_SECONDS" ]]; then
        return 1
    fi
    local owner_pid
    owner_pid=$(_lock_get_metadata_value "$lock_file" "pid")
    local status="unknown"
    if [[ -n "$owner_pid" ]]; then
        if _lock_pid_alive "$owner_pid"; then
            status="alive"
        else
            status="dead"
        fi
    fi
    local detail="age=${age}s owner=${owner_pid:-unknown} status=${status}"
    if [[ -n "$owner_pid" && "$owner_pid" == "$$" ]]; then
        detail="${detail} self=true"
    fi
    log_warn "SEC-007: Deadlock heuristic triggered for $lock_file (${detail})"
    _lock_record_metric "deadlock_suspected" "$lock_file" "$attempt" "" "$age" "$detail"
    return 0
}

_lock_auto_release_stale() {
    local lock_file="$1"
    local attempt="${2:-}"
    local age
    age=$(_lock_age_seconds "$lock_file")
    if ! _validate_numeric "$age"; then
        return 1
    fi
    if ! _validate_numeric "$LOCK_STALE_TIMEOUT_SECONDS"; then
        return 1
    fi
    if [[ "$age" -lt "$LOCK_STALE_TIMEOUT_SECONDS" ]]; then
        return 1
    fi
    local owner_pid
    owner_pid=$(_lock_get_metadata_value "$lock_file" "pid")
    local status="unknown"
    if [[ -n "$owner_pid" ]]; then
        if _lock_pid_alive "$owner_pid"; then
            status="alive"
        else
            status="dead"
        fi
    fi
    local detail="age=${age}s owner=${owner_pid:-unknown} status=${status}"
    if [[ "${LOCK_AUTO_RELEASE_STALE}" == "1" ]]; then
        rm -f "$lock_file" 2>/dev/null || true
        log_warn "SEC-007: Auto-released stale lock $lock_file (${detail})"
        _lock_record_metric "stale_released" "$lock_file" "$attempt" "" "$age" "$detail"
        return 0
    fi
    return 1
}

_lock_acquire_with_backoff() {
    local mode="$1"
    local lock_file="$2"
    local timeout="$3"
    local fd="$4"

    if ! _validate_numeric "$timeout"; then
        timeout="$DEFAULT_LOCK_TIMEOUT"
    fi
    if [[ "$timeout" -lt 0 ]]; then
        timeout=0
    fi

    local backoff="${LOCK_BACKOFF_INITIAL}"
    local max_backoff="${LOCK_BACKOFF_MAX}"
    if ! _validate_numeric "$backoff"; then
        backoff=1
    fi
    if ! _validate_numeric "$max_backoff"; then
        max_backoff=8
    fi
    if [[ "$max_backoff" -lt "$backoff" ]]; then
        max_backoff="$backoff"
    fi

    local start_ts
    start_ts=$(_lock_epoch_seconds)
    local attempts=0
    local deadlock_reported=0

    while true; do
        attempts=$((attempts + 1))
        local now
        now=$(_lock_epoch_seconds)
        local elapsed=$((now - start_ts))
        local remaining="$timeout"
        if [[ "$timeout" -gt 0 ]]; then
            remaining=$((timeout - elapsed))
            if [[ "$remaining" -le 0 ]]; then
                break
            fi
        else
            remaining=0
        fi
        local wait="$backoff"
        if [[ "$timeout" -gt 0 && "$wait" -gt "$remaining" ]]; then
            wait="$remaining"
        fi

        eval "exec $fd>>\"$lock_file\""

        if [[ "$mode" == "shared" ]]; then
            if flock -s -w "$wait" "$fd" 2>/dev/null; then
                touch "$lock_file" 2>/dev/null || true
                now=$(_lock_epoch_seconds)
                elapsed=$((now - start_ts))
                _lock_record_metric "acquired" "$lock_file" "$attempts" "$wait" "$elapsed" "mode=shared"
                return 0
            fi
        else
            if flock -x -w "$wait" "$fd" 2>/dev/null; then
                _lock_write_metadata "$lock_file"
                now=$(_lock_epoch_seconds)
                elapsed=$((now - start_ts))
                _lock_record_metric "acquired" "$lock_file" "$attempts" "$wait" "$elapsed" "mode=exclusive"
                return 0
            fi
        fi

        eval "exec $fd>&-" 2>/dev/null || true
        now=$(_lock_epoch_seconds)
        elapsed=$((now - start_ts))
        _lock_record_metric "contention" "$lock_file" "$attempts" "$wait" "$elapsed" "mode=${mode}"

        if _lock_auto_release_stale "$lock_file" "$attempts"; then
            backoff="${LOCK_BACKOFF_INITIAL}"
            if ! _validate_numeric "$backoff"; then
                backoff=1
            fi
            continue
        fi

        if [[ "$deadlock_reported" -eq 0 ]]; then
            if _lock_deadlock_heuristic "$lock_file" "$attempts"; then
                deadlock_reported=1
            fi
        fi

        if [[ "$backoff" -lt "$max_backoff" ]]; then
            backoff=$((backoff * 2))
            if [[ "$backoff" -gt "$max_backoff" ]]; then
                backoff="$max_backoff"
            fi
        fi

        if [[ "$timeout" -eq 0 ]]; then
            break
        fi
    done

    local final_elapsed
    final_elapsed=$(( $(_lock_epoch_seconds) - start_ts ))
    _lock_record_metric "timeout" "$lock_file" "$attempts" "$backoff" "$final_elapsed" "mode=${mode}"
    return 1
}

# Acquire exclusive lock on file descriptor
# Usage: acquire_lock "lockfile" [timeout_seconds] [file_descriptor]
# Returns: 0 on success, 1 on timeout/failure
acquire_lock() {
    local lock_file="$1"
    local timeout="${2:-30}"
    local fd="${3:-200}"

    # Create lock file directory if needed
    mkdir -p "$(dirname "$lock_file")" 2>/dev/null || true

    # Create lock file if it doesn't exist (preserve mtime for stale detection)
    [[ -f "$lock_file" ]] || : > "$lock_file" 2>/dev/null || true

    if _lock_acquire_with_backoff "exclusive" "$lock_file" "$timeout" "$fd"; then
        return 0
    else
        log_warn "SEC-007: Failed to acquire lock on $lock_file after ${timeout}s"
        eval "exec $fd>&-" 2>/dev/null || true
        return 1
    fi
}

# Acquire shared lock on file descriptor (allows concurrent reads)
# Usage: acquire_shared_lock "lockfile" [timeout_seconds] [file_descriptor]
acquire_shared_lock() {
    local lock_file="$1"
    local timeout="${2:-5}"
    local fd="${3:-201}"

    mkdir -p "$(dirname "$lock_file")" 2>/dev/null || true
    [[ -f "$lock_file" ]] || : > "$lock_file" 2>/dev/null || true

    if _lock_acquire_with_backoff "shared" "$lock_file" "$timeout" "$fd"; then
        return 0
    else
        log_warn "SEC-007: Failed to acquire shared lock on $lock_file after ${timeout}s"
        eval "exec $fd>&-" 2>/dev/null || true
        return 1
    fi
}

# Release lock on file descriptor
# Usage: release_lock [file_descriptor]
release_lock() {
    local fd="${1:-200}"
    flock -u "$fd" 2>/dev/null || true
    eval "exec $fd>&-" 2>/dev/null || true
}

# Execute command with exclusive lock
# Usage: with_lock "lockfile" timeout_seconds command [args...]
# Example: with_lock "/tmp/myfile.lock" 10 echo "hello" >> /tmp/myfile
with_lock() {
    local lock_file="$1"
    local timeout="$2"
    shift 2

    if acquire_lock "$lock_file" "$timeout"; then
        "$@"
        local result=$?
        release_lock
        return $result
    else
        log_error "SEC-007: with_lock failed to acquire lock: $lock_file"
        return 1
    fi
}

# Atomic append to file with exclusive locking
# Usage: atomic_append "file" "content" [lock_timeout]
# This is the primary function for safe concurrent writes
atomic_append() {
    local target_file="$1"
    local content="$2"
    local timeout="${3:-$LEDGER_LOCK_TIMEOUT}"
    local lock_file="${target_file}.lock"

    # Ensure target directory exists
    mkdir -p "$(dirname "$target_file")" 2>/dev/null || true

    # Use subshell with lock acquisition for atomic append
    (
        local fd=200
        if ! acquire_lock "$lock_file" "$timeout" "$fd"; then
            log_error "SEC-007: atomic_append failed to acquire lock for $target_file"
            exit 1
        fi
        trap 'release_lock "$fd"' EXIT

        # Append content with newline
        printf '%s\n' "$content" >> "$target_file"

        # Sync to disk for durability (optional, may slow down high-frequency writes)
        sync "$target_file" 2>/dev/null || true

    )

    return $?
}

# FIX-004: Atomic append with exponential backoff for high contention scenarios
# Usage: atomic_append_with_backoff "file" "content" [initial_timeout] [max_retries]
atomic_append_with_backoff() {
    local target_file="$1"
    local content="$2"
    local timeout="${3:-$LEDGER_LOCK_TIMEOUT}"
    local max_retries="${4:-$MAX_LOCK_RETRIES}"
    local backoff="${LOCK_BACKOFF_INITIAL}"
    local max_backoff="${LOCK_BACKOFF_MAX}"
    if ! _validate_numeric "$backoff"; then
        backoff=1
    fi
    if ! _validate_numeric "$max_backoff"; then
        max_backoff=8
    fi

    for ((attempt=1; attempt<=max_retries; attempt++)); do
        if atomic_append "$target_file" "$content" "$timeout"; then
            return 0
        fi

        if [[ $attempt -lt $max_retries ]]; then
            log_warn "SEC-007: Lock contention on $target_file, retry $attempt/${max_retries} after ${backoff}s backoff"
            sleep "$backoff"
            backoff=$((backoff * 2))
            if [[ "$backoff" -gt "$max_backoff" ]]; then
                backoff="$max_backoff"
            fi
        fi
    done

    log_error "SEC-007: Failed to acquire lock after $max_retries attempts on $target_file"
    return 1
}

# Read file with shared lock (allows concurrent readers)
# Usage: content=$(atomic_read "file" [lock_timeout])
atomic_read() {
    local target_file="$1"
    local timeout="${2:-5}"
    local lock_file="${target_file}.lock"

    [[ ! -f "$target_file" ]] && return 0

    (
        local fd=200
        if ! acquire_shared_lock "$lock_file" "$timeout" "$fd"; then
            log_error "SEC-007: atomic_read failed to acquire shared lock for $target_file"
            exit 1
        fi
        trap 'release_lock "$fd"' EXIT
        cat "$target_file"
    )
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
export -f sanitize_git_log
export -f sanitize_llm_input
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

# SEC-008C: Export secure binary resolution functions
export -f secure_which
export -f secure_exec
export -f safe_env_exec
export -f is_trusted_binary_path
export -f log_security_event

# SEC-007: Export file locking functions
export -f acquire_lock
export -f acquire_shared_lock
export -f release_lock
export -f with_lock
export -f atomic_append
export -f atomic_read

# SEC-P1-10: Export binary verification functions
export -f _verify_critical_binary
export -f _init_binary_hash_baseline
export -f _verify_critical_binaries_at_startup

# =============================================================================
# Performance: Mark Initialization Complete (#performance)
# =============================================================================
# This prevents redundant initialization when common.sh is sourced multiple times
# in the SAME shell. NOT exported to preserve child process initialization.
_COMMON_SH_INITIALIZED=1
# Note: Intentionally NOT exported - child processes need their own initialization
