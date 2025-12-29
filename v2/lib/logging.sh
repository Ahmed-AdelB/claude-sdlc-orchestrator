#!/bin/bash
# =============================================================================
# logging.sh - Structured JSONL logging with trace_id correlation
# =============================================================================
# Provides:
# - JSONL format logging for machine parsing
# - Trace ID correlation across all log entries
# - Log levels (DEBUG, INFO, WARN, ERROR, FATAL)
# - Component tagging (CLAUDE, GEMINI, CODEX, ROUTER, etc.)
# - Event types for state transitions
# - Log rotation and retention
# - Audit logging (optional prompt/response hashes)
#
# This file is sourced by common.sh - do not source directly
# =============================================================================

# Ensure we have required directories
: "${LOG_DIR:=$HOME/.claude/autonomous/logs}"

# INC-ARCH-003: Support log separation by execution mode
if [[ -n "${EXECUTION_MODE:-}" ]]; then
    # When running in a specific mode (stress-test, dev, etc.),
    # segregate logs into a subdirectory
    LOG_DIR="${LOG_DIR}/${EXECUTION_MODE}"
    
    # Force update derived paths as they might be pre-set by common.sh
    SESSION_LOG_DIR="${LOG_DIR}/sessions"
    ERROR_LOG_DIR="${LOG_DIR}/errors"
    AUDIT_LOG_DIR="${LOG_DIR}/audit"
fi

: "${SESSION_LOG_DIR:=$LOG_DIR/sessions}"
: "${ERROR_LOG_DIR:=$LOG_DIR/errors}"
: "${AUDIT_LOG_DIR:=$LOG_DIR/audit}"
: "${TRACE_ID:=unknown}"

# Current session log file
SESSION_LOG="${SESSION_LOG_DIR}/$(date +%Y-%m-%d).jsonl"

# =============================================================================
# Log Levels
# =============================================================================
declare -gA LOG_LEVELS=(
    ["DEBUG"]=0
    ["INFO"]=1
    ["WARN"]=2
    ["ERROR"]=3
    ["FATAL"]=4
)

# Current minimum log level (default: INFO)
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Check if a message at given level should be logged
should_log() {
    local level="$1"
    local current_level="${LOG_LEVELS[$LOG_LEVEL]:-1}"
    local msg_level="${LOG_LEVELS[$level]:-1}"
    [[ $msg_level -ge $current_level ]]
}

# =============================================================================
# Core Logging Functions
# =============================================================================

# Core JSON log function
# Usage: log_json LEVEL COMPONENT EVENT "message" [metadata_json]
log_json() {
    local level="$1"
    local component="$2"
    local event="$3"
    local message="$4"
    local metadata="${5:-{}}"
    local timestamp
    local hostname
    local pid

    # Check if this level should be logged
    should_log "$level" || return 0

    timestamp="$(date -Iseconds)"
    hostname="${HOSTNAME:-$(hostname)}"
    pid="$$"

    # Ensure log directory exists
    mkdir -p "$(dirname "$SESSION_LOG")"

    # Build JSON log entry
    local log_entry
    log_entry=$(cat <<EOF
{"timestamp":"${timestamp}","level":"${level}","component":"${component}","event":"${event}","message":"${message}","trace_id":"${TRACE_ID}","hostname":"${hostname}","pid":${pid},"metadata":${metadata}}
EOF
)

    # Write to session log (append)
    (flock -x 200; echo "$log_entry" >> "$SESSION_LOG") 200>"${SESSION_LOG}.lock"

    # Also write errors to error log
    if [[ "$level" == "ERROR" || "$level" == "FATAL" ]]; then
        mkdir -p "$ERROR_LOG_DIR"
        local error_log_file="${ERROR_LOG_DIR}/$(date +%Y-%m-%d).jsonl"
        (flock -x 200; echo "$log_entry" >> "$error_log_file") 200>"${error_log_file}.lock"
    fi

    # Terminal output (human-readable) if not in quiet mode
    if [[ "${QUIET:-0}" != "1" ]]; then
        _log_to_terminal "$level" "$component" "$event" "$message"
    fi
}

# Human-readable terminal output
_log_to_terminal() {
    local level="$1"
    local component="$2"
    local event="$3"
    local message="$4"

    local color=""
    local reset=""

    if [[ -t 2 ]]; then
        reset='\033[0m'
        case "$level" in
            DEBUG)  color='\033[0;90m' ;;  # Gray
            INFO)   color='\033[0;32m' ;;  # Green
            WARN)   color='\033[0;33m' ;;  # Yellow
            ERROR)  color='\033[0;31m' ;;  # Red
            FATAL)  color='\033[1;31m' ;;  # Bold Red
        esac
    fi

    local short_trace="${TRACE_ID:0:8}"
    local timestamp
    timestamp="$(date +%H:%M:%S)"

    printf "${color}[%s][%s][%s][%s]${reset} %s\n" \
        "$timestamp" "$level" "$component" "$short_trace" "$message" >&2
}

# =============================================================================
# Convenience Logging Functions
# =============================================================================

# Generic component loggers
log_debug() { log_json "DEBUG" "${COMPONENT:-SYSTEM}" "LOG" "$*"; }
log_info()  { log_json "INFO"  "${COMPONENT:-SYSTEM}" "LOG" "$*"; }
log_warn()  { log_json "WARN"  "${COMPONENT:-SYSTEM}" "LOG" "$*"; }
log_error() { log_json "ERROR" "${COMPONENT:-SYSTEM}" "LOG" "$*"; }
log_fatal() { log_json "FATAL" "${COMPONENT:-SYSTEM}" "LOG" "$*"; }

# Component-specific loggers
log_claude()  { log_json "${1:-INFO}" "CLAUDE"  "${2:-LOG}" "$3" "${4:-{}}"; }
log_gemini()  { log_json "${1:-INFO}" "GEMINI"  "${2:-LOG}" "$3" "${4:-{}}"; }
log_codex()   { log_json "${1:-INFO}" "CODEX"   "${2:-LOG}" "$3" "${4:-{}}"; }
log_router()  { log_json "${1:-INFO}" "ROUTER"  "${2:-LOG}" "$3" "${4:-{}}"; }
log_monitor() { log_json "${1:-INFO}" "MONITOR" "${2:-LOG}" "$3" "${4:-{}}"; }

# =============================================================================
# State Transition Events
# =============================================================================

# Log task queue event
log_task_queue() {
    local task_id="$1"
    local task_type="$2"
    local model="${3:-auto}"
    log_json "INFO" "TASK" "QUEUE" "Task queued" \
        "{\"task_id\":\"${task_id}\",\"task_type\":\"${task_type}\",\"model\":\"${model}\"}"
}

# Log task start
log_task_start() {
    local task_id="$1"
    local model="$2"
    log_json "INFO" "${model^^}" "TASK_START" "Task started" \
        "{\"task_id\":\"${task_id}\",\"model\":\"${model}\"}"
}

# Log task completion
log_task_complete() {
    local task_id="$1"
    local model="$2"
    local duration_ms="${3:-0}"
    log_json "INFO" "${model^^}" "TASK_COMPLETE" "Task completed" \
        "{\"task_id\":\"${task_id}\",\"model\":\"${model}\",\"duration_ms\":${duration_ms}}"
}

# Log task failure
log_task_fail() {
    local task_id="$1"
    local model="$2"
    local error_type="$3"
    local error_msg="$4"
    log_json "ERROR" "${model^^}" "TASK_FAIL" "Task failed: ${error_msg}" \
        "{\"task_id\":\"${task_id}\",\"model\":\"${model}\",\"error_type\":\"${error_type}\"}"
}

# Log retry attempt
log_retry() {
    local task_id="$1"
    local model="$2"
    local attempt="$3"
    local max_attempts="$4"
    local backoff_seconds="$5"
    log_json "WARN" "${model^^}" "RETRY" "Retrying task (attempt ${attempt}/${max_attempts})" \
        "{\"task_id\":\"${task_id}\",\"model\":\"${model}\",\"attempt\":${attempt},\"max_attempts\":${max_attempts},\"backoff_seconds\":${backoff_seconds}}"
}

# Log fallback to different model
log_fallback() {
    local task_id="$1"
    local from_model="$2"
    local to_model="$3"
    local reason="$4"
    log_json "WARN" "ROUTER" "FALLBACK" "Falling back from ${from_model} to ${to_model}: ${reason}" \
        "{\"task_id\":\"${task_id}\",\"from_model\":\"${from_model}\",\"to_model\":\"${to_model}\",\"reason\":\"${reason}\"}"
}

# Log circuit breaker state change
log_circuit_breaker() {
    local model="$1"
    local old_state="$2"
    local new_state="$3"
    log_json "WARN" "${model^^}" "CIRCUIT_BREAKER" "Circuit breaker: ${old_state} -> ${new_state}" \
        "{\"model\":\"${model}\",\"old_state\":\"${old_state}\",\"new_state\":\"${new_state}\"}"
}

# Log rate limit hit
log_rate_limit() {
    local model="$1"
    local retry_after="${2:-unknown}"
    log_json "WARN" "${model^^}" "RATE_LIMIT" "Rate limit hit, retry after ${retry_after}s" \
        "{\"model\":\"${model}\",\"retry_after\":\"${retry_after}\"}"
}

# Log routing decision
log_route_decision() {
    local task_id="$1"
    local selected_model="$2"
    local confidence="$3"
    local signals="$4"
    log_json "INFO" "ROUTER" "ROUTE_DECISION" "Routed to ${selected_model} (confidence: ${confidence})" \
        "{\"task_id\":\"${task_id}\",\"model\":\"${selected_model}\",\"confidence\":${confidence},\"signals\":${signals}}"
}

# Log consensus result
log_consensus() {
    local task_id="$1"
    local decision="$2"
    local votes="$3"
    log_json "INFO" "CONSENSUS" "VOTE_RESULT" "Consensus decision: ${decision}" \
        "{\"task_id\":\"${task_id}\",\"decision\":\"${decision}\",\"votes\":${votes}}"
}

# =============================================================================
# Audit Logging (Optional - for prompt/response tracking)
# =============================================================================

# Log audit entry with hash (for compliance)
log_audit() {
    local model="$1"
    local prompt_hash="$2"
    local response_hash="$3"
    local token_estimate="${4:-0}"

    mkdir -p "$AUDIT_LOG_DIR"

    local timestamp
    timestamp="$(date -Iseconds)"

    local audit_entry
    audit_entry="{\"timestamp\":\"${timestamp}\",\"trace_id\":\"${TRACE_ID}\",\"model\":\"${model}\",\"prompt_hash\":\"${prompt_hash}\",\"response_hash\":\"${response_hash}\",\"token_estimate\":${token_estimate}}"

    local audit_log_file="${AUDIT_LOG_DIR}/$(date +%Y-%m-%d).jsonl"
    (flock -x 200; echo "$audit_entry" >> "$audit_log_file") 200>"${audit_log_file}.lock"
}

# Generate SHA256 hash of content (for audit)
hash_content() {
    local content="$1"
    echo -n "$content" | sha256sum | cut -d' ' -f1
}

# =============================================================================
# Log Rotation and Cleanup
# =============================================================================

# Rotate logs older than N days
rotate_logs() {
    local retention_days="${1:-7}"
    local compress="${2:-true}"

    # Find and compress old logs
    if [[ "$compress" == "true" ]] && command -v gzip &>/dev/null; then
        find "$LOG_DIR" -name "*.jsonl" -type f -mtime "+${retention_days}" ! -name "*.gz" \
            -exec gzip {} \; 2>/dev/null || true
    fi

    # Delete very old compressed logs (2x retention)
    find "$LOG_DIR" -name "*.gz" -type f -mtime "+$((retention_days * 2))" \
        -delete 2>/dev/null || true

    log_info "Log rotation complete (retention: ${retention_days} days)"
}

# Get current log file path
get_log_file() {
    echo "$SESSION_LOG"
}

# Get log size in bytes
get_log_size() {
    local log_file="${1:-$SESSION_LOG}"
    if [[ -f "$log_file" ]]; then
        stat -c%s "$log_file" 2>/dev/null || stat -f%z "$log_file" 2>/dev/null || echo 0
    else
        echo 0
    fi
}

# =============================================================================
# Log Search and Analysis
# =============================================================================

# Search logs for a trace ID
search_trace() {
    local trace_id="$1"
    local days="${2:-7}"

    find "$SESSION_LOG_DIR" -name "*.jsonl" -mtime "-${days}" -exec grep -l "\"trace_id\":\"${trace_id}\"" {} \; 2>/dev/null | while read -r file; do
        grep "\"trace_id\":\"${trace_id}\"" "$file"
    done
}

# Get error summary for today
get_error_summary() {
    local log_file="${ERROR_LOG_DIR}/$(date +%Y-%m-%d).jsonl"
    if [[ -f "$log_file" ]]; then
        jq -s 'group_by(.component) | map({component: .[0].component, count: length, last_error: .[-1].message})' "$log_file" 2>/dev/null || echo "[]"
    else
        echo "[]"
    fi
}

# Count events by type for a component
count_events() {
    local component="$1"
    local event="$2"
    local log_file="${3:-$SESSION_LOG}"

    if [[ -f "$log_file" ]]; then
        grep -c "\"component\":\"${component}\".*\"event\":\"${event}\"" "$log_file" 2>/dev/null || echo 0
    else
        echo 0
    fi
}

# =============================================================================
# Export Functions
# =============================================================================
export -f log_json
export -f log_debug
export -f log_info
export -f log_warn
export -f log_error
export -f log_fatal
export -f log_claude
export -f log_gemini
export -f log_codex
export -f log_router
export -f log_monitor
export -f log_task_queue
export -f log_task_start
export -f log_task_complete
export -f log_task_fail
export -f log_retry
export -f log_fallback
export -f log_circuit_breaker
export -f log_rate_limit
export -f log_route_decision
export -f log_consensus
export -f log_audit
export -f hash_content
export -f rotate_logs
export -f get_log_file
export -f get_log_size
export -f search_trace
export -f get_error_summary
export -f count_events
