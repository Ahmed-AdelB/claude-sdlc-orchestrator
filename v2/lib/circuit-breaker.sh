#!/bin/bash
# =============================================================================
# circuit-breaker.sh - Per-model circuit breaker pattern
# =============================================================================
# Implements the circuit breaker pattern to prevent cascading failures:
#
# States:
# - CLOSED: Normal operation, calls go through
# - OPEN: After N consecutive failures, skip calls entirely
# - HALF_OPEN: After cooldown, test with one call
#
# This file is sourced by common.sh - do not source directly
# =============================================================================

# Ensure we have required directories
: "${STATE_DIR:=$HOME/.claude/autonomous/state}"
: "${BREAKERS_DIR:=$STATE_DIR/breakers}"
: "${LOCKS_DIR:=$STATE_DIR/locks}"

# Default configuration (can be overridden by tri-agent.yaml)
CB_FAILURE_THRESHOLD="${CB_FAILURE_THRESHOLD:-3}"
CB_COOLDOWN_SECONDS="${CB_COOLDOWN_SECONDS:-60}"
CB_HALF_OPEN_MAX_CALLS="${CB_HALF_OPEN_MAX_CALLS:-1}"

# =============================================================================
# Circuit Breaker State Management
# =============================================================================

# Get state file path for a model
_get_breaker_file() {
    local model="$1"
    local state_file="${BREAKERS_DIR}/${model}.state"
    echo "$state_file"
}

# Initialize breaker state if not exists
_init_breaker() {
    local model="$1"
    local state_file
    state_file="$(_get_breaker_file "$model")"

    mkdir -p "$BREAKERS_DIR"

    if [[ ! -f "$state_file" ]]; then
        cat > "$state_file" <<EOF
state=CLOSED
failure_count=0
last_failure=0
last_success=0
half_open_calls=0
EOF
    fi
}

# Read breaker state (atomic file read)
_read_breaker_state() {
    local model="$1"
    local state_file
    local state

    state_file="$(_get_breaker_file "$model")"

    _init_breaker "$model"

    # Read state atomically
    if [[ -f "$state_file" ]]; then
        state=$(grep -E "^state=" "$state_file" 2>/dev/null | head -1 | cut -d'=' -f2-)
        echo "${state:-CLOSED}"
    else
        echo "CLOSED"
    fi
}

# Get failure count (with safe file reading)
_get_failure_count() {
    local model="$1"
    local state_file
    local failure_count

    state_file="$(_get_breaker_file "$model")"

    _init_breaker "$model"

    if [[ -f "$state_file" ]]; then
        failure_count=$(grep -E "^failure_count=" "$state_file" 2>/dev/null | head -1 | cut -d'=' -f2-)
        echo "${failure_count:-0}"
    else
        echo "0"
    fi
}

# Update breaker state atomically (caller must hold lock)
_update_breaker_state() {
    local model="$1"
    local new_state="$2"
    local new_failure_count="$3"
    local last_failure="$4"
    local last_success="$5"
    local half_open_calls="${6:-0}"
    local state_file
    local content
    local tmp_file

    state_file="$(_get_breaker_file "$model")"

    mkdir -p "$BREAKERS_DIR"

    content="state=${new_state}
failure_count=${new_failure_count}
last_failure=${last_failure}
last_success=${last_success}
half_open_calls=${half_open_calls}"

    # Direct atomic write (caller holds lock)
    # Use mktemp in the same directory to ensure atomic mv is possible
    tmp_file=$(mktemp -p "$BREAKERS_DIR") || return 1
    chmod 600 "$tmp_file"

    if printf "%s\n" "$content" > "$tmp_file"; then
        mv "$tmp_file" "$state_file" || rm -f "$tmp_file"
    else
        rm -f "$tmp_file"
        return 1
    fi
}

# =============================================================================
# Circuit Breaker Core Functions
# =============================================================================

# Check if we should call a model
# Returns 0 (allow) or 1 (skip)
should_call_model() {
    local model="$1"
    local lock_file="${LOCKS_DIR}/breaker_${model}.lock"

    with_lock "$lock_file" "${DEFAULT_LOCK_TIMEOUT:-10}" _should_call_model_locked "$model"
}

_should_call_model_locked() {
    local model="$1"
    local state_file
    local state
    local failure_count
    local last_failure
    local last_success
    local half_open_calls
    local now
    local elapsed
    local remaining

    state_file="$(_get_breaker_file "$model")"

    _init_breaker "$model"

    # Read current state safely (without sourcing - prevents code injection)
    if [[ -f "$state_file" ]]; then
        state=$(grep -E "^state=" "$state_file" 2>/dev/null | head -1 | cut -d'=' -f2- || echo "CLOSED")
        failure_count=$(grep -E "^failure_count=" "$state_file" 2>/dev/null | head -1 | cut -d'=' -f2- || echo "0")
        last_failure=$(grep -E "^last_failure=" "$state_file" 2>/dev/null | head -1 | cut -d'=' -f2- || echo "0")
        last_success=$(grep -E "^last_success=" "$state_file" 2>/dev/null | head -1 | cut -d'=' -f2- || echo "0")
        half_open_calls=$(grep -E "^half_open_calls=" "$state_file" 2>/dev/null | head -1 | cut -d'=' -f2- || echo "0")
    else
        state="CLOSED"
        failure_count=0
        last_failure=0
        last_success=0
        half_open_calls=0
    fi

    if ! [[ "$failure_count" =~ ^[0-9]+$ ]]; then
        failure_count=0
    fi
    if ! [[ "$last_failure" =~ ^[0-9]+$ ]]; then
        last_failure=0
    fi
    if ! [[ "$last_success" =~ ^[0-9]+$ ]]; then
        last_success=0
    fi
    if ! [[ "$half_open_calls" =~ ^[0-9]+$ ]]; then
        half_open_calls=0
    fi

    now=$(date +%s)

    case "$state" in
        CLOSED)
            # Normal operation - allow call
            return 0
            ;;

        OPEN)
            # Check if cooldown has elapsed
            elapsed=$((now - last_failure))
            if [[ $elapsed -ge $CB_COOLDOWN_SECONDS ]]; then
                # Transition to HALF_OPEN
                _update_breaker_state "$model" "HALF_OPEN" "$failure_count" "$last_failure" "$last_success" 0
                log_circuit_breaker "$model" "OPEN" "HALF_OPEN" 2>/dev/null || true
                return 0  # Allow test call
            else
                # Still in cooldown
                remaining=$((CB_COOLDOWN_SECONDS - elapsed))
                log_debug "[${TRACE_ID:-unknown}] Circuit breaker OPEN for ${model}, ${remaining}s remaining" 2>/dev/null || true
                return 1  # Skip call
            fi
            ;;

        HALF_OPEN)
            # Check if we've exceeded max half-open calls
            if [[ $half_open_calls -ge $CB_HALF_OPEN_MAX_CALLS ]]; then
                log_debug "[${TRACE_ID:-unknown}] Circuit breaker HALF_OPEN max calls reached for ${model}" 2>/dev/null || true
                return 1  # Skip call
            fi
            # Increment half-open call count
            _update_breaker_state "$model" "HALF_OPEN" "$failure_count" "$last_failure" "$last_success" $((half_open_calls + 1))
            return 0  # Allow test call
            ;;

        *)
            # Unknown state - reset to CLOSED
            log_warn "[${TRACE_ID:-unknown}] Unknown circuit breaker state for ${model}: ${state}, resetting to CLOSED" 2>/dev/null || true
            _update_breaker_state "$model" "CLOSED" 0 0 "$now" 0
            return 0
            ;;
    esac
}

# Record a successful call
record_success() {
    local model="$1"
    local lock_file="${LOCKS_DIR}/breaker_${model}.lock"

    with_lock "$lock_file" "${DEFAULT_LOCK_TIMEOUT:-10}" _record_success_locked "$model"
}

_record_success_locked() {
    local model="$1"
    local state_file
    local state
    local failure_count
    local last_failure
    local last_success
    local half_open_calls
    local now

    state_file="$(_get_breaker_file "$model")"

    _init_breaker "$model"

    # Read state safely
    if [[ -f "$state_file" ]]; then
        state=$(grep -E "^state=" "$state_file" 2>/dev/null | head -1 | cut -d'=' -f2- || echo "CLOSED")
        failure_count=$(grep -E "^failure_count=" "$state_file" 2>/dev/null | head -1 | cut -d'=' -f2- || echo "0")
        last_failure=$(grep -E "^last_failure=" "$state_file" 2>/dev/null | head -1 | cut -d'=' -f2- || echo "0")
        last_success=$(grep -E "^last_success=" "$state_file" 2>/dev/null | head -1 | cut -d'=' -f2- || echo "0")
        half_open_calls=$(grep -E "^half_open_calls=" "$state_file" 2>/dev/null | head -1 | cut -d'=' -f2- || echo "0")
    else
        state="CLOSED"
        failure_count=0
        last_failure=0
        last_success=0
        half_open_calls=0
    fi

    if ! [[ "$failure_count" =~ ^[0-9]+$ ]]; then
        failure_count=0
    fi
    if ! [[ "$last_failure" =~ ^[0-9]+$ ]]; then
        last_failure=0
    fi
    if ! [[ "$last_success" =~ ^[0-9]+$ ]]; then
        last_success=0
    fi
    if ! [[ "$half_open_calls" =~ ^[0-9]+$ ]]; then
        half_open_calls=0
    fi

    now=$(date +%s)

    case "$state" in
        HALF_OPEN)
            # Success in half-open - close the breaker
            _update_breaker_state "$model" "CLOSED" 0 "$last_failure" "$now" 0
            log_circuit_breaker "$model" "HALF_OPEN" "CLOSED" 2>/dev/null || true
            ;;

        CLOSED|OPEN)
            # Reset failure count on success
            _update_breaker_state "$model" "CLOSED" 0 "$last_failure" "$now" 0
            ;;
    esac
}

# Record a failed call
record_failure() {
    local model="$1"
    local error_type="${2:-UNKNOWN}"
    local lock_file="${LOCKS_DIR}/breaker_${model}.lock"

    with_lock "$lock_file" "${DEFAULT_LOCK_TIMEOUT:-10}" _record_failure_locked "$model" "$error_type"
}

_record_failure_locked() {
    local model="$1"
    local error_type="${2:-UNKNOWN}"
    local state_file
    local state
    local failure_count
    local last_failure
    local last_success
    local half_open_calls
    local now
    local new_failure_count

    state_file="$(_get_breaker_file "$model")"

    _init_breaker "$model"

    # Read state safely
    if [[ -f "$state_file" ]]; then
        state=$(grep -E "^state=" "$state_file" 2>/dev/null | head -1 | cut -d'=' -f2- || echo "CLOSED")
        failure_count=$(grep -E "^failure_count=" "$state_file" 2>/dev/null | head -1 | cut -d'=' -f2- || echo "0")
        last_failure=$(grep -E "^last_failure=" "$state_file" 2>/dev/null | head -1 | cut -d'=' -f2- || echo "0")
        last_success=$(grep -E "^last_success=" "$state_file" 2>/dev/null | head -1 | cut -d'=' -f2- || echo "0")
        half_open_calls=$(grep -E "^half_open_calls=" "$state_file" 2>/dev/null | head -1 | cut -d'=' -f2- || echo "0")
    else
        state="CLOSED"
        failure_count=0
        last_failure=0
        last_success=0
        half_open_calls=0
    fi

    if ! [[ "$failure_count" =~ ^[0-9]+$ ]]; then
        failure_count=0
    fi
    if ! [[ "$last_failure" =~ ^[0-9]+$ ]]; then
        last_failure=0
    fi
    if ! [[ "$last_success" =~ ^[0-9]+$ ]]; then
        last_success=0
    fi
    if ! [[ "$half_open_calls" =~ ^[0-9]+$ ]]; then
        half_open_calls=0
    fi

    now=$(date +%s)
    new_failure_count=$((failure_count + 1))

    case "$state" in
        CLOSED)
            if [[ $new_failure_count -ge $CB_FAILURE_THRESHOLD ]]; then
                # Trip the breaker
                _update_breaker_state "$model" "OPEN" "$new_failure_count" "$now" "$last_success" 0
                log_circuit_breaker "$model" "CLOSED" "OPEN" 2>/dev/null || true
                log_warn "[${TRACE_ID:-unknown}] Circuit breaker tripped for $model (failures: $new_failure_count, error: $error_type)" 2>/dev/null || true
            else
                # Increment failure count
                _update_breaker_state "$model" "CLOSED" "$new_failure_count" "$now" "$last_success" 0
            fi
            ;;

        HALF_OPEN)
            # Failure in half-open - back to open
            _update_breaker_state "$model" "OPEN" "$new_failure_count" "$now" "$last_success" 0
            log_circuit_breaker "$model" "HALF_OPEN" "OPEN" 2>/dev/null || true
            ;;

        OPEN)
            # Already open - just update timestamp
            _update_breaker_state "$model" "OPEN" "$new_failure_count" "$now" "$last_success" 0
            ;;
    esac
}

# Record result (convenience wrapper)
# Usage: record_result "model" 0|1 [error_type]
record_result() {
    local model="$1"
    local success="$2"
    local error_type="${3:-UNKNOWN}"

    if [[ "$success" == "0" ]]; then
        record_success "$model"
    else
        record_failure "$model" "$error_type"
    fi
}

# =============================================================================
# Fallback Logic
# =============================================================================

# Model fallback chains - configurable per model
# Each model has a space-separated list of fallback models in priority order
declare -A MODEL_FALLBACKS=(
    ["claude"]="codex gemini"
    ["codex"]="claude gemini"
    ["gemini"]="claude codex"
)

# Check circuit breaker state (public wrapper)
# Usage: check_breaker "model"
# Returns: CLOSED, OPEN, or HALF_OPEN
check_breaker() {
    local model="$1"
    _read_breaker_state "$model"
}

# Get failure count (public wrapper)
# Usage: get_failure_count "model"
# Returns: Number of consecutive failures
get_failure_count() {
    local model="$1"
    _get_failure_count "$model"
}

# Get the next fallback model in the chain: Claude -> Codex -> Gemini
# Usage: fallback_to_next_model "current_model"
# Returns: Next available model name on stdout, or exits with 1 if none
fallback_to_next_model() {
    local failed_model="$1"
    local next_model=""

    case "$failed_model" in
        "claude") next_model="codex" ;;
        "codex") next_model="gemini" ;;
        "gemini")
            log_warn "[${TRACE_ID:-unknown}] End of fallback chain reached (Gemini failed)" 2>/dev/null || true
            return 1
            ;;
        *)
            log_warn "[${TRACE_ID:-unknown}] Unknown model for fallback: $failed_model" 2>/dev/null || true
            return 1
            ;;
    esac

    # Check if the fallback model is available (Circuit Breaker is CLOSED or HALF_OPEN)
    if should_call_model "$next_model"; then
        log_info "[${TRACE_ID:-unknown}] Fallback: Switching from ${failed_model} to ${next_model}" 2>/dev/null || true
        echo "$next_model"
        return 0
    else
        # If the fallback is also down, try the next one in the chain
        log_warn "[${TRACE_ID:-unknown}] Fallback model ${next_model} is unavailable (Circuit Breaker OPEN), trying next..." 2>/dev/null || true
        fallback_to_next_model "$next_model"
    fi
}

# Get next available model in fallback chain (enhanced version)
# Usage: get_fallback_model "failed_model" [excluded_models...]
# Returns: Next available model name on stdout, or exits with 1 if none available
get_fallback_model() {
    local failed_model="$1"
    shift
    local excluded_models=("$@")
    local fallbacks="${MODEL_FALLBACKS[$failed_model]:-}"

    if [[ -z "$fallbacks" ]]; then
        log_error "[${TRACE_ID:-unknown}] No fallback chain defined for model: $failed_model" 2>/dev/null || true
        return 1
    fi

    for fallback in $fallbacks; do
        # Skip if in excluded list
        local is_excluded=false
        for excluded in "${excluded_models[@]}"; do
            if [[ "$fallback" == "$excluded" ]]; then
                is_excluded=true
                break
            fi
        done
        [[ "$is_excluded" == "true" ]] && continue

        # Check circuit breaker state
        local state
        state=$(check_breaker "$fallback")
        if [[ "$state" != "OPEN" ]]; then
            log_info "[${TRACE_ID:-unknown}] Fallback selected: $fallback (state: $state)" 2>/dev/null || true
            echo "$fallback"
            return 0
        else
            log_debug "[${TRACE_ID:-unknown}] Skipping fallback $fallback (circuit OPEN)" 2>/dev/null || true
        fi
    done

    # All circuits open
    log_error "[${TRACE_ID:-unknown}] All model circuits are open - no fallback available" 2>/dev/null || true
    return 1
}

# Execute with automatic fallback across the model chain
# Usage: execute_with_auto_fallback "primary_model" "prompt" [timeout_seconds]
# Returns: 0 on success with output, 1 on all fallbacks exhausted
execute_with_auto_fallback() {
    local primary_model="$1"
    local prompt="$2"
    local timeout="${3:-300}"

    local current_model="$primary_model"
    local attempts=0
    local max_attempts=3
    local tried_models=()

    while [[ $attempts -lt $max_attempts ]]; do
        ((attempts++))
        tried_models+=("$current_model")

        # Check circuit breaker state
        local state
        state=$(check_breaker "$current_model")

        if [[ "$state" == "OPEN" ]]; then
            log_warn "[${TRACE_ID:-unknown}] Circuit OPEN for $current_model (attempt $attempts/$max_attempts), finding fallback" 2>/dev/null || true
            current_model=$(get_fallback_model "$current_model" "${tried_models[@]}") || {
                log_error "[${TRACE_ID:-unknown}] No available fallback after $attempts attempts" 2>/dev/null || true
                return 1
            }
            continue
        fi

        # Attempt execution
        local result=""
        local exit_code=0
        local start_time
        start_time=$(date +%s)

        log_info "[${TRACE_ID:-unknown}] Executing with $current_model (attempt $attempts/$max_attempts)" 2>/dev/null || true

        case "$current_model" in
            claude)
                result=$(timeout "$timeout" claude --dangerously-skip-permissions -p "$prompt" 2>&1) || exit_code=$?
                ;;
            codex)
                result=$(timeout "$timeout" codex exec "$prompt" 2>&1) || exit_code=$?
                ;;
            gemini)
                result=$(timeout "$timeout" gemini -y "$prompt" 2>&1) || exit_code=$?
                ;;
            *)
                log_error "[${TRACE_ID:-unknown}] Unknown model: $current_model" 2>/dev/null || true
                exit_code=127
                ;;
        esac

        local duration=$(( $(date +%s) - start_time ))

        if [[ $exit_code -eq 0 ]]; then
            record_success "$current_model"
            log_info "[${TRACE_ID:-unknown}] Execution successful with $current_model (${duration}s, attempt $attempts)" 2>/dev/null || true
            echo "$result"
            return 0
        else
            # Check for timeout (exit code 124)
            local error_type="exit_$exit_code"
            if [[ $exit_code -eq 124 ]]; then
                error_type="timeout"
                log_warn "[${TRACE_ID:-unknown}] $current_model timed out after ${timeout}s" 2>/dev/null || true
            fi

            record_failure "$current_model" "$error_type"
            log_warn "[${TRACE_ID:-unknown}] $current_model failed (exit $exit_code, ${duration}s), finding fallback" 2>/dev/null || true

            current_model=$(get_fallback_model "$current_model" "${tried_models[@]}") || {
                log_error "[${TRACE_ID:-unknown}] All fallback attempts exhausted (tried: ${tried_models[*]})" 2>/dev/null || true
                return 1
            }
        fi
    done

    log_error "[${TRACE_ID:-unknown}] Maximum attempts ($max_attempts) exhausted" 2>/dev/null || true
    return 1
}

# Get model health summary for monitoring
# Usage: get_model_health_summary
# Returns: JSON object with health status of all models
get_model_health_summary() {
    local models=("claude" "codex" "gemini")
    local first=true

    echo "{"
    for model in "${models[@]}"; do
        local state
        local failure_count

        state=$(check_breaker "$model")
        failure_count=$(get_failure_count "$model")

        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo ","
        fi
        echo "  \"$model\": {\"state\": \"$state\", \"failures\": $failure_count}"
    done
    echo "}"
}

# Check if all circuits are open (system degraded)
# Usage: all_circuits_open
# Returns: 0 if all open (degraded), 1 if at least one is available
all_circuits_open() {
    local models=("claude" "codex" "gemini")

    for model in "${models[@]}"; do
        local state
        state=$(check_breaker "$model")
        if [[ "$state" != "OPEN" ]]; then
            return 1  # At least one is available
        fi
    done

    return 0  # All are open - system degraded
}

# =============================================================================
# Circuit Breaker Queries
# =============================================================================

# Get circuit breaker status for a model
get_breaker_status() {
    local model="$1"
    local lock_file="${LOCKS_DIR}/breaker_${model}.lock"

    with_lock "$lock_file" "${DEFAULT_LOCK_TIMEOUT:-10}" _get_breaker_status_locked "$model"
}

_get_breaker_status_locked() {
    local model="$1"
    local state_file
    local state
    local failure_count
    local last_failure
    local last_success
    local half_open_calls
    local now
    local since_failure
    local since_success

    state_file="$(_get_breaker_file "$model")"

    _init_breaker "$model"

    # Read state safely
    if [[ -f "$state_file" ]]; then
        state=$(grep -E "^state=" "$state_file" 2>/dev/null | head -1 | cut -d'=' -f2- || echo "CLOSED")
        failure_count=$(grep -E "^failure_count=" "$state_file" 2>/dev/null | head -1 | cut -d'=' -f2- || echo "0")
        last_failure=$(grep -E "^last_failure=" "$state_file" 2>/dev/null | head -1 | cut -d'=' -f2- || echo "0")
        last_success=$(grep -E "^last_success=" "$state_file" 2>/dev/null | head -1 | cut -d'=' -f2- || echo "0")
        half_open_calls=$(grep -E "^half_open_calls=" "$state_file" 2>/dev/null | head -1 | cut -d'=' -f2- || echo "0")
    else
        state="CLOSED"
        failure_count=0
        last_failure=0
        last_success=0
        half_open_calls=0
    fi

    if ! [[ "$failure_count" =~ ^[0-9]+$ ]]; then
        failure_count=0
    fi
    if ! [[ "$last_failure" =~ ^[0-9]+$ ]]; then
        last_failure=0
    fi
    if ! [[ "$last_success" =~ ^[0-9]+$ ]]; then
        last_success=0
    fi
    if ! [[ "$half_open_calls" =~ ^[0-9]+$ ]]; then
        half_open_calls=0
    fi

    now=$(date +%s)
    since_failure=$((now - last_failure))
    since_success=$((now - last_success))

    if [[ $since_failure -lt 0 ]]; then
        since_failure=0
    fi
    if [[ $since_success -lt 0 ]]; then
        since_success=0
    fi

    cat <<EOF
{
    "model": "${model}",
    "state": "${state}",
    "failure_count": ${failure_count},
    "failure_threshold": ${CB_FAILURE_THRESHOLD},
    "seconds_since_last_failure": ${since_failure},
    "seconds_since_last_success": ${since_success},
    "cooldown_seconds": ${CB_COOLDOWN_SECONDS},
    "half_open_calls": ${half_open_calls}
}
EOF
}

# Get all circuit breaker statuses
get_all_breaker_status() {
    local models=("claude" "gemini" "codex")
    local first=true
    local model

    echo "["
    for model in "${models[@]}"; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo ","
        fi
        get_breaker_status "$model"
    done
    echo "]"
}

# Check if any breakers are open
any_breakers_open() {
    local models=("claude" "gemini" "codex")
    local model

    for model in "${models[@]}"; do
        local state
        state=$(_read_breaker_state "$model")
        if [[ "$state" == "OPEN" ]]; then
            return 0  # True - at least one is open
        fi
    done

    return 1  # False - none are open
}

# Get list of available models (not in OPEN state)
get_available_models() {
    local models=("claude" "gemini" "codex")
    local available=()
    local model

    for model in "${models[@]}"; do
        if should_call_model "$model"; then
            available+=("$model")
        fi
    done

    # Return as comma-separated list
    local IFS=,
    echo "${available[*]}"
}

# =============================================================================
# Circuit Breaker Reset Functions
# =============================================================================

# Force reset a circuit breaker to CLOSED
reset_breaker() {
    local model="$1"
    local lock_file="${LOCKS_DIR}/breaker_${model}.lock"

    with_lock "$lock_file" "${DEFAULT_LOCK_TIMEOUT:-10}" _reset_breaker_locked "$model"
}

_reset_breaker_locked() {
    local model="$1"
    local now

    now=$(date +%s)

    _update_breaker_state "$model" "CLOSED" 0 0 "$now" 0
    log_info "[${TRACE_ID:-unknown}] Circuit breaker reset for ${model}" 2>/dev/null || true
}

# Reset all circuit breakers
reset_all_breakers() {
    local models=("claude" "gemini" "codex")
    local model

    for model in "${models[@]}"; do
        reset_breaker "$model"
    done
}

# =============================================================================
# Circuit Breaker Configuration
# =============================================================================

# Update circuit breaker configuration from config file
load_breaker_config() {
    local config="${1:-$HOME/.claude/autonomous/config/tri-agent.yaml}"
    local threshold
    local cooldown
    local max_calls

    if [[ ! -f "$config" ]]; then
        return 0
    fi

    # Try to read config values
    if command -v yq &>/dev/null; then
        threshold=$(yq eval '.circuit_breaker.failure_threshold // 3' "$config" 2>/dev/null)
        cooldown=$(yq eval '.circuit_breaker.cooldown_seconds // 60' "$config" 2>/dev/null)
        max_calls=$(yq eval '.circuit_breaker.half_open_max_calls // 1' "$config" 2>/dev/null)

        CB_FAILURE_THRESHOLD="${threshold:-3}"
        CB_COOLDOWN_SECONDS="${cooldown:-60}"
        CB_HALF_OPEN_MAX_CALLS="${max_calls:-1}"

        log_debug "[${TRACE_ID:-unknown}] Circuit breaker config: threshold=$CB_FAILURE_THRESHOLD, cooldown=$CB_COOLDOWN_SECONDS, max_calls=$CB_HALF_OPEN_MAX_CALLS" 2>/dev/null || true
    fi
}

# =============================================================================
# Circuit Breaker Wrapper
# =============================================================================

# Execute a command with circuit breaker protection
# Usage: circuit_breaker_call "model" command [args...]
# Returns:
#   0: Success
#   1-125: Command failure
#   126: Circuit breaker OPEN (Fallback suggested)
#   127: Command not found or other error
circuit_breaker_call() {
    local model="$1"
    shift
    
    # 1. Check breaker state
    if ! should_call_model "$model"; then
        log_warn "[${TRACE_ID:-unknown}] Circuit breaker OPEN for ${model}."
        
        # Trigger fallback logic (identify next model)
        local next_model
        if next_model=$(fallback_to_next_model "$model"); then
             log_info "[${TRACE_ID:-unknown}] Circuit Breaker Triggered Fallback -> ${next_model}"
        fi
        
        # Return special exit code for Breaker Open
        return 126 
    fi

    # 2. Execute command
    "$@"
    local exit_code=$?

    # 3. Record result
    if [[ $exit_code -eq 0 ]]; then
        record_success "$model"
    else
        record_failure "$model" "exit_code_${exit_code}"
    fi

    return $exit_code
}

# =============================================================================
# Quality Gate Circuit Breaker (INC-ARCH-002)
# =============================================================================

# Quality Gate specific constants
# Guard against re-sourcing
if [[ -z "${QG_FAILURE_THRESHOLD:-}" ]]; then
    readonly QG_FAILURE_THRESHOLD=3
fi
if [[ -z "${QG_COOLDOWN_SECONDS:-}" ]]; then
    readonly QG_COOLDOWN_SECONDS=300 # 5 minutes
fi

# Handle Quality Gate Circuit Breaker
# Usage: quality_gate_breaker "gate_type" "action" [args...]
# Actions:
#   check: Returns 0 if allowed, 1 if breaker OPEN
#   success: Records a success
#   failure: Records a failure
quality_gate_breaker() {
    local gate_type="$1"
    local action="$2"
    local error_type="${3:-UNKNOWN}"
    local breaker_name="gate_${gate_type}"
    
    # Shadow global config with Quality Gate specific values
    # These will be picked up by the core functions called within this scope
    local CB_FAILURE_THRESHOLD=$QG_FAILURE_THRESHOLD
    local CB_COOLDOWN_SECONDS=$QG_COOLDOWN_SECONDS
    
    case "$action" in
        "check")
            should_call_model "$breaker_name"
            ;;
        "success")
            record_success "$breaker_name"
            ;;
        "failure")
            record_failure "$breaker_name" "$error_type"
            ;;
        "status")
            get_breaker_status "$breaker_name"
            ;;
        *)
            log_error "Unknown quality_gate_breaker action: $action"
            return 1
            ;;
    esac
}

# Export for use in other scripts
export -f quality_gate_breaker

# =============================================================================
# Export Functions
# =============================================================================
export -f should_call_model
export -f _should_call_model_locked
export -f record_success
export -f _record_success_locked
export -f record_failure
export -f _record_failure_locked
export -f record_result
export -f get_breaker_status
export -f _get_breaker_status_locked
export -f get_all_breaker_status
export -f any_breakers_open
export -f get_available_models
export -f reset_breaker
export -f _reset_breaker_locked
export -f reset_all_breakers
export -f load_breaker_config
export -f _get_breaker_file
export -f _init_breaker
export -f _read_breaker_state
export -f _get_failure_count
export -f _update_breaker_state
export -f fallback_to_next_model
export -f circuit_breaker_call

# Fallback chain exports
export -f check_breaker
export -f get_failure_count
export -f get_fallback_model
export -f execute_with_auto_fallback
export -f get_model_health_summary
export -f all_circuits_open
