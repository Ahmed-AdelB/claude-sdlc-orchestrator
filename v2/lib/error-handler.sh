#!/bin/bash
# =============================================================================
# error-handler.sh - Retry, fallback, and error classification
# =============================================================================
# Provides:
# - Exponential backoff with jitter
# - Rate limit detection and cooldown
# - Automatic fallback chain (claude → codex → gemini)
# - Error classification (TIMEOUT, RATE_LIMIT, AUTH_ERROR, etc.)
# - Retry budget per task
# - Auth refresh detection
# - Hung process detection
#
# This file is sourced by common.sh - do not source directly
# =============================================================================

# Ensure we have required directories
: "${STATE_DIR:=$HOME/.claude/autonomous/state}"
: "${RATE_LIMITS_DIR:=$STATE_DIR/rate-limits}"

# Default configuration (can be overridden by config or env)
EH_MAX_RETRIES="${EH_MAX_RETRIES:-3}"
EH_BACKOFF_BASE="${EH_BACKOFF_BASE:-5}"
EH_BACKOFF_MAX="${EH_BACKOFF_MAX:-300}"
EH_BACKOFF_MULTIPLIER="${EH_BACKOFF_MULTIPLIER:-2}"
EH_JITTER="${EH_JITTER:-true}"
EH_RETRY_BUDGET="${EH_RETRY_BUDGET:-5}"

# Fallback order (default)
EH_FALLBACK_ORDER=("claude" "codex" "gemini")

# =============================================================================
# Error Types
# =============================================================================
declare -gA ERROR_TYPES=(
    ["RATE_LIMIT"]="Rate limit exceeded"
    ["AUTH_ERROR"]="Authentication failed"
    ["TIMEOUT"]="Request timed out"
    ["MODEL_UNAVAILABLE"]="Model not available"
    ["NETWORK_ERROR"]="Network connectivity issue"
    ["INVALID_REQUEST"]="Invalid request format"
    ["CONTEXT_TOO_LONG"]="Context exceeds limit"
    ["HUNG_PROCESS"]="Process appears hung"
    # Codex-specific error types (#109)
    ["CODEX_REASONING_ERROR"]="Codex reasoning budget exceeded"
    ["CODEX_CONTEXT_ERROR"]="Codex context compaction failed"
    ["CODEX_SANDBOX_ERROR"]="Codex sandbox permission denied"
    ["CODEX_OUTPUT_ERROR"]="Codex output token limit exceeded"
    ["UNKNOWN"]="Unknown error"
)

# =============================================================================
# Error Classification
# =============================================================================

# Classify an error based on output/exit code
# Usage: error_type=$(detect_error_type "$output" $exit_code)
detect_error_type() {
    local output="$1"
    local exit_code="${2:-1}"
    local output_lower
    output_lower=$(echo "$output" | tr '[:upper:]' '[:lower:]')

    # Rate limit patterns
    if echo "$output_lower" | grep -qE "(rate limit|429|quota exceeded|too many requests|rate_limit)"; then
        echo "RATE_LIMIT"
        return
    fi

    # Auth error patterns
    if echo "$output_lower" | grep -qE "(authentication|unauthorized|401|403|invalid token|auth|permission denied|access denied)"; then
        echo "AUTH_ERROR"
        return
    fi

    # Timeout patterns
    if echo "$output_lower" | grep -qE "(timeout|timed out|deadline exceeded|context deadline)"; then
        echo "TIMEOUT"
        return
    fi

    # Model unavailable patterns
    if echo "$output_lower" | grep -qE "(model not found|404|model unavailable|model_not_found|no model)"; then
        echo "MODEL_UNAVAILABLE"
        return
    fi

    # Network error patterns
    if echo "$output_lower" | grep -qE "(network|connection refused|connection reset|dns|could not resolve|econnrefused)"; then
        echo "NETWORK_ERROR"
        return
    fi

    # Context too long
    if echo "$output_lower" | grep -qE "(context.*too long|token limit|max.*tokens|context length)"; then
        echo "CONTEXT_TOO_LONG"
        return
    fi

    # Invalid request
    if echo "$output_lower" | grep -qE "(invalid request|bad request|400|malformed)"; then
        echo "INVALID_REQUEST"
        return
    fi

    # Codex-specific: Reasoning budget exceeded (#109)
    if echo "$output_lower" | grep -qE "(reasoning.*budget|reasoning.*exceeded|reasoning.*timeout|model_reasoning_timeout)"; then
        echo "CODEX_REASONING_ERROR"
        return
    fi

    # Codex-specific: Context compaction failed (#109)
    if echo "$output_lower" | grep -qE "(context.*compact|context_compaction_failed)"; then
        echo "CODEX_CONTEXT_ERROR"
        return
    fi

    # Codex-specific: Sandbox permission denied (#109)
    if echo "$output_lower" | grep -qE "(sandbox.*permission|sandbox.*denied)"; then
        echo "CODEX_SANDBOX_ERROR"
        return
    fi

    # Codex-specific: Output token limit (#109)
    if echo "$output_lower" | grep -qE "(output.*token.*limit|max.*output.*tokens)"; then
        echo "CODEX_OUTPUT_ERROR"
        return
    fi

    echo "UNKNOWN"
}

# Check if error is retryable
is_retryable_error() {
    local error_type="$1"

    case "$error_type" in
        RATE_LIMIT|TIMEOUT|NETWORK_ERROR|MODEL_UNAVAILABLE)
            return 0  # Retryable
            ;;
        AUTH_ERROR|INVALID_REQUEST|CONTEXT_TOO_LONG)
            return 1  # Not retryable
            ;;
        # Codex-specific errors (#109)
        CODEX_REASONING_ERROR|CODEX_OUTPUT_ERROR)
            return 0  # Retryable (may succeed with smaller prompt)
            ;;
        CODEX_CONTEXT_ERROR|CODEX_SANDBOX_ERROR)
            return 1  # Not retryable (needs config change)
            ;;
        *)
            return 0  # Unknown errors are retryable
            ;;
    esac
}

# =============================================================================
# Rate Limit Tracking
# =============================================================================

# Record rate limit hit
record_rate_limit() {
    local model="$1"
    local retry_after="${2:-60}"
    local rate_file="${RATE_LIMITS_DIR}/${model}.limit"

    mkdir -p "$RATE_LIMITS_DIR"

    local now
    now=$(date +%s)
    local until=$((now + retry_after))

    echo "$until" > "$rate_file"
    log_rate_limit "$model" "$retry_after" 2>/dev/null || true
}

# Check if a model is rate limited
# Returns 0 if rate limited, 1 if not
is_rate_limited() {
    local model="$1"
    local rate_file="${RATE_LIMITS_DIR}/${model}.limit"

    if [[ ! -f "$rate_file" ]]; then
        return 1  # Not rate limited
    fi

    local until
    until=$(cat "$rate_file")
    local now
    now=$(date +%s)

    if [[ $now -lt $until ]]; then
        return 0  # Still rate limited
    else
        rm -f "$rate_file"
        return 1  # Rate limit expired
    fi
}

# Get rate limit remaining time
get_rate_limit_remaining() {
    local model="$1"
    local rate_file="${RATE_LIMITS_DIR}/${model}.limit"

    if [[ ! -f "$rate_file" ]]; then
        echo 0
        return
    fi

    local until
    until=$(cat "$rate_file")
    local now
    now=$(date +%s)
    local remaining=$((until - now))

    if [[ $remaining -gt 0 ]]; then
        echo "$remaining"
    else
        echo 0
    fi
}

# =============================================================================
# Backoff Calculation
# =============================================================================

# Calculate backoff time with exponential growth and jitter
# Usage: sleep_time=$(calculate_backoff $attempt)
calculate_backoff() {
    local attempt="$1"
    local base="${EH_BACKOFF_BASE}"
    local max="${EH_BACKOFF_MAX}"
    local multiplier="${EH_BACKOFF_MULTIPLIER}"

    # Exponential backoff: base * multiplier^(attempt-1)
    # Use awk for portability (#116) - bc not always available
    local backoff
    backoff=$(awk "BEGIN {printf \"%.0f\", $base * ($multiplier ^ ($attempt - 1))}" 2>/dev/null || echo "$base")

    # Cap at max
    if [[ $backoff -gt $max ]]; then
        backoff=$max
    fi

    # Add jitter (±25%)
    if [[ "$EH_JITTER" == "true" ]]; then
        local jitter_range=$((backoff / 4))
        local jitter=$((RANDOM % (jitter_range * 2 + 1) - jitter_range))
        backoff=$((backoff + jitter))
    fi

    # Ensure minimum of 1 second
    if [[ $backoff -lt 1 ]]; then
        backoff=1
    fi

    echo "$backoff"
}

# =============================================================================
# Retry Logic
# =============================================================================

# Execute a command with retry logic (SECURE: no eval)
# Usage: execute_with_retry [--max-retries N] command [args...]
# Returns: exit code of final attempt
#
# Examples:
#   execute_with_retry curl -s https://api.example.com
#   execute_with_retry --max-retries 5 ./my-script.sh arg1 arg2
execute_with_retry() {
    local max_retries="$EH_MAX_RETRIES"

    # Parse optional --max-retries flag
    if [[ "$1" == "--max-retries" ]]; then
        max_retries="$2"
        shift 2
    fi

    # Remaining args are the command and its arguments
    local -a cmd=("$@")
    local attempt=1
    local result=0
    local output=""
    local error_type=""

    if [[ ${#cmd[@]} -eq 0 ]]; then
        log_error "execute_with_retry: No command provided" 2>/dev/null || true
        return 1
    fi

    while [[ $attempt -le $max_retries ]]; do
        # Execute command safely using array expansion (no eval)
        output=$("${cmd[@]}" 2>&1)
        result=$?

        if [[ $result -eq 0 ]]; then
            echo "$output"
            return 0
        fi

        # Classify error
        error_type=$(detect_error_type "$output" $result)

        # Check if retryable
        if ! is_retryable_error "$error_type"; then
            log_error "Non-retryable error ($error_type): $output" 2>/dev/null || true
            echo "$output"
            return $result
        fi

        # Log retry with trace context (#124)
        log_retry "${TRACE_ID:-unknown}" "unknown" $attempt $max_retries 0 2>/dev/null || true

        # Check if more retries available
        if [[ $attempt -lt $max_retries ]]; then
            local backoff
            backoff=$(calculate_backoff $attempt)
            log_warn "Retry $attempt/$max_retries, backing off ${backoff}s" 2>/dev/null || true
            sleep "$backoff"
        fi

        ((attempt++))
    done

    log_error "All $max_retries retries exhausted" 2>/dev/null || true
    echo "$output"
    return $result
}

# =============================================================================
# Retry Budget Tracking (#78 fix)
# =============================================================================

# Track retry count per task
get_task_retry_count() {
    local task_id="$1"
    local retry_file="${RATE_LIMITS_DIR}/retry_${task_id}"

    if [[ -f "$retry_file" ]]; then
        cat "$retry_file"
    else
        echo "0"
    fi
}

# Increment task retry count
increment_task_retry_count() {
    local task_id="$1"
    local retry_file="${RATE_LIMITS_DIR}/retry_${task_id}"

    mkdir -p "$RATE_LIMITS_DIR"

    local current
    current=$(get_task_retry_count "$task_id")
    local new=$((current + 1))
    echo "$new" > "$retry_file"
    echo "$new"
}

# Reset task retry count
reset_task_retry_count() {
    local task_id="$1"
    local retry_file="${RATE_LIMITS_DIR}/retry_${task_id}"
    rm -f "$retry_file" 2>/dev/null || true
}

# =============================================================================
# Fallback Chain
# =============================================================================

# Execute with fallback to other models
# Usage: execute_with_fallback_chain "task" [model_func_prefix]
# The model_func_prefix should be a function that takes model and task as args
execute_with_fallback_chain() {
    local task="$1"
    local executor="${2:-execute_model}"
    local models=("${EH_FALLBACK_ORDER[@]}")
    local task_id="${TRACE_ID:-unknown}"

    # Get current retry count for this task (#78 fix)
    local task_retries
    task_retries=$(get_task_retry_count "$task_id")

    for model in "${models[@]}"; do
        # Check circuit breaker
        if ! should_call_model "$model" 2>/dev/null; then
            log_warn "Skipping $model (circuit breaker open)" 2>/dev/null || true
            continue
        fi

        # Check rate limit
        if is_rate_limited "$model"; then
            local remaining
            remaining=$(get_rate_limit_remaining "$model")
            log_warn "Skipping $model (rate limited for ${remaining}s)" 2>/dev/null || true
            continue
        fi

        # Check retry budget per task (#78 fix)
        if [[ $task_retries -ge $EH_RETRY_BUDGET ]]; then
            log_error "Task retry budget exhausted ($task_retries/$EH_RETRY_BUDGET)" 2>/dev/null || true
            return 1
        fi

        log_info "Trying model: $model" 2>/dev/null || true

        # Execute with the model
        local output
        local result
        output=$("$executor" "$model" "$task" 2>&1)
        result=$?

        if [[ $result -eq 0 ]]; then
            record_success "$model" 2>/dev/null || true
            # Reset retry count on success (#78 fix)
            reset_task_retry_count "$task_id" 2>/dev/null || true
            echo "$output"
            return 0
        fi

        # Record failure
        local error_type
        error_type=$(detect_error_type "$output" $result)
        record_failure "$model" "$error_type" 2>/dev/null || true

        # Handle rate limit
        if [[ "$error_type" == "RATE_LIMIT" ]]; then
            record_rate_limit "$model" 60
        fi

        # Increment task retry count (#78 fix)
        task_retries=$(increment_task_retry_count "$task_id")

        # Log fallback
        local next_model="${models[$((${#models[@]} - 1))]}"
        for ((i=0; i<${#models[@]}; i++)); do
            if [[ "${models[$i]}" == "$model" && $((i+1)) -lt ${#models[@]} ]]; then
                next_model="${models[$((i+1))]}"
                break
            fi
        done

        if [[ "$model" != "${models[-1]}" ]]; then
            log_fallback "$task_id" "$model" "$next_model" "$error_type" 2>/dev/null || true
        fi
    done

    log_error "All models in fallback chain exhausted" 2>/dev/null || true
    return 1
}

# =============================================================================
# Auth Token Detection
# =============================================================================

# Detect if an error indicates auth expiry
detect_auth_expiry() {
    local output="$1"
    local output_lower
    output_lower=$(echo "$output" | tr '[:upper:]' '[:lower:]')

    if echo "$output_lower" | grep -qE "(token expired|refresh token|reauth|re-authenticate|login again)"; then
        return 0  # Auth expired
    fi

    return 1  # Auth OK
}

# Trigger auth refresh (placeholder - implement per model)
trigger_auth_refresh() {
    local model="$1"

    log_warn "Auth refresh needed for $model" 2>/dev/null || true

    case "$model" in
        gemini)
            log_info "Run 'gemini' interactively to re-authenticate" 2>/dev/null || true
            ;;
        codex)
            log_info "Run 'codex auth' to re-authenticate" 2>/dev/null || true
            ;;
        claude)
            log_info "Claude Code should auto-authenticate" 2>/dev/null || true
            ;;
    esac
}

# =============================================================================
# Hung Process Detection
# =============================================================================

# Check if a process appears hung (no output for N seconds)
# Usage: is_hung=$(detect_hung_process $pid $timeout_seconds)
detect_hung_process() {
    local pid="$1"
    local timeout="${2:-60}"
    local output_file="${3:-}"

    if [[ -z "$output_file" ]]; then
        # Just check if process is alive
        if ! kill -0 "$pid" 2>/dev/null; then
            return 1  # Process not running
        fi
        return 0  # Can't determine without output file
    fi

    # Check if output file has been modified recently
    local now
    now=$(date +%s)
    local last_modified
    last_modified=$(stat -c %Y "$output_file" 2>/dev/null || stat -f %m "$output_file" 2>/dev/null || echo 0)
    local age=$((now - last_modified))

    if [[ $age -gt $timeout ]]; then
        return 0  # Hung (no output for too long)
    fi

    return 1  # Not hung
}

# Kill a hung process safely
kill_hung_process() {
    local pid="$1"
    local grace_period="${2:-5}"

    # Try SIGTERM first
    kill -TERM "$pid" 2>/dev/null || true
    sleep "$grace_period"

    # Check if still running
    if kill -0 "$pid" 2>/dev/null; then
        # Force kill
        kill -KILL "$pid" 2>/dev/null || true
    fi
}

# =============================================================================
# Error Recovery Helpers
# =============================================================================

# Get user-friendly error message
get_error_message() {
    local error_type="$1"
    echo "${ERROR_TYPES[$error_type]:-Unknown error}"
}

# Suggest recovery action
suggest_recovery() {
    local error_type="$1"
    local model="$2"

    case "$error_type" in
        RATE_LIMIT)
            echo "Wait for rate limit cooldown or use a different model"
            ;;
        AUTH_ERROR)
            echo "Re-authenticate with: $model auth"
            ;;
        TIMEOUT)
            echo "Try a smaller request or increase timeout"
            ;;
        MODEL_UNAVAILABLE)
            echo "Check model name in config or use fallback model"
            ;;
        NETWORK_ERROR)
            echo "Check internet connection"
            ;;
        CONTEXT_TOO_LONG)
            echo "Reduce context size or use Gemini (1M tokens)"
            ;;
        *)
            echo "Review error output and try again"
            ;;
    esac
}

# =============================================================================
# Configuration Loading
# =============================================================================

# Load error handling config from config file
load_error_config() {
    local config="${1:-${CONFIG_DIR:-$HOME/.claude/autonomous/config}/tri-agent.yaml}"

    if [[ ! -f "$config" ]]; then
        return 0
    fi

    if command -v yq &>/dev/null; then
        EH_MAX_RETRIES=$(yq eval '.error_handling.max_retries // 3' "$config" 2>/dev/null)
        EH_BACKOFF_BASE=$(yq eval '.error_handling.backoff_base // 5' "$config" 2>/dev/null)
        EH_BACKOFF_MAX=$(yq eval '.error_handling.backoff_max // 300' "$config" 2>/dev/null)
        EH_BACKOFF_MULTIPLIER=$(yq eval '.error_handling.backoff_multiplier // 2' "$config" 2>/dev/null)
        EH_JITTER=$(yq eval '.error_handling.jitter // true' "$config" 2>/dev/null)
        EH_RETRY_BUDGET=$(yq eval '.error_handling.retry_budget_per_task // 5' "$config" 2>/dev/null)

        # Load fallback order (#79 fix)
        local fallback
        fallback=$(yq eval '.error_handling.fallback_order | join(",")' "$config" 2>/dev/null)
        if [[ -n "$fallback" && "$fallback" != "null" ]]; then
            IFS=',' read -ra EH_FALLBACK_ORDER <<< "$fallback"
        fi

        # Load orchestrator failover from models.claude.failover_to (#77 fix)
        local claude_failover
        claude_failover=$(yq eval '.models.claude.failover_to // ""' "$config" 2>/dev/null)
        if [[ -n "$claude_failover" && "$claude_failover" != "null" ]]; then
            # Update fallback order to use configured failover
            # Replace "claude" with [claude, failover_model] in the chain
            local new_order=()
            local claude_added=false
            for model in "${EH_FALLBACK_ORDER[@]}"; do
                if [[ "$model" == "claude" && ! "$claude_added" ]]; then
                    new_order+=("claude")
                    new_order+=("$claude_failover")
                    claude_added=true
                elif [[ "$model" != "$claude_failover" ]]; then
                    new_order+=("$model")
                fi
            done
            EH_FALLBACK_ORDER=("${new_order[@]}")
        fi
    fi
}

# =============================================================================
# Export Functions
# =============================================================================
export -f detect_error_type
export -f is_retryable_error
export -f record_rate_limit
export -f is_rate_limited
export -f get_rate_limit_remaining
export -f calculate_backoff
export -f execute_with_retry
export -f get_task_retry_count
export -f increment_task_retry_count
export -f reset_task_retry_count
export -f execute_with_fallback_chain
export -f detect_auth_expiry
export -f trigger_auth_refresh
export -f detect_hung_process
export -f kill_hung_process
export -f get_error_message
export -f suggest_recovery
export -f load_error_config

# Initialize configuration
load_error_config
