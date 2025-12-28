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
    echo "${BREAKERS_DIR}/${model}.state"
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

# Read breaker state
_read_breaker_state() {
    local model="$1"
    local state_file
    state_file="$(_get_breaker_file "$model")"

    _init_breaker "$model"

    # Source the state file to get variables
    # shellcheck disable=SC1090
    source "$state_file"

    echo "$state"
}

# Get failure count
_get_failure_count() {
    local model="$1"
    local state_file
    state_file="$(_get_breaker_file "$model")"

    _init_breaker "$model"

    # shellcheck disable=SC1090
    source "$state_file"
    echo "$failure_count"
}

# Update breaker state atomically (#82 fix - use atomic_write for consistency)
_update_breaker_state() {
    local model="$1"
    local new_state="$2"
    local new_failure_count="$3"
    local last_failure="$4"
    local last_success="$5"
    local half_open_calls="${6:-0}"
    local state_file
    state_file="$(_get_breaker_file "$model")"

    mkdir -p "$BREAKERS_DIR"

    # Use atomic_write from state.sh for unified locking mechanism (#82)
    local content
    content="state=${new_state}
failure_count=${new_failure_count}
last_failure=${last_failure}
last_success=${last_success}
half_open_calls=${half_open_calls}"

    atomic_write "$state_file" "$content"
}

# =============================================================================
# Circuit Breaker Core Functions
# =============================================================================

# Check if we should call a model
# Returns 0 (allow) or 1 (skip)
should_call_model() {
    local model="$1"
    local state_file
    state_file="$(_get_breaker_file "$model")"

    _init_breaker "$model"

    # Read current state
    local state failure_count last_failure last_success half_open_calls
    # shellcheck disable=SC1090
    source "$state_file"

    local now
    now=$(date +%s)

    case "$state" in
        CLOSED)
            # Normal operation - allow call
            return 0
            ;;

        OPEN)
            # Check if cooldown has elapsed
            local elapsed=$((now - last_failure))
            if [[ $elapsed -ge $CB_COOLDOWN_SECONDS ]]; then
                # Transition to HALF_OPEN
                _update_breaker_state "$model" "HALF_OPEN" "$failure_count" "$last_failure" "$last_success" 0
                log_circuit_breaker "$model" "OPEN" "HALF_OPEN" 2>/dev/null || true
                return 0  # Allow test call
            else
                # Still in cooldown
                local remaining=$((CB_COOLDOWN_SECONDS - elapsed))
                log_debug "Circuit breaker OPEN for ${model}, ${remaining}s remaining" 2>/dev/null || true
                return 1  # Skip call
            fi
            ;;

        HALF_OPEN)
            # Check if we've exceeded max half-open calls
            if [[ $half_open_calls -ge $CB_HALF_OPEN_MAX_CALLS ]]; then
                log_debug "Circuit breaker HALF_OPEN max calls reached for ${model}" 2>/dev/null || true
                return 1  # Skip call
            fi
            # Increment half-open call count
            _update_breaker_state "$model" "HALF_OPEN" "$failure_count" "$last_failure" "$last_success" $((half_open_calls + 1))
            return 0  # Allow test call
            ;;

        *)
            # Unknown state - reset to CLOSED
            _update_breaker_state "$model" "CLOSED" 0 0 "$now" 0
            return 0
            ;;
    esac
}

# Record a successful call
record_success() {
    local model="$1"
    local state_file
    state_file="$(_get_breaker_file "$model")"

    _init_breaker "$model"

    local state failure_count last_failure last_success half_open_calls
    # shellcheck disable=SC1090
    source "$state_file"

    local now
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
    local state_file
    state_file="$(_get_breaker_file "$model")"

    _init_breaker "$model"

    local state failure_count last_failure last_success half_open_calls
    # shellcheck disable=SC1090
    source "$state_file"

    local now
    now=$(date +%s)
    local new_failure_count=$((failure_count + 1))

    case "$state" in
        CLOSED)
            if [[ $new_failure_count -ge $CB_FAILURE_THRESHOLD ]]; then
                # Trip the breaker
                _update_breaker_state "$model" "OPEN" "$new_failure_count" "$now" "$last_success" 0
                log_circuit_breaker "$model" "CLOSED" "OPEN" 2>/dev/null || true
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
# Circuit Breaker Queries
# =============================================================================

# Get circuit breaker status for a model
get_breaker_status() {
    local model="$1"
    local state_file
    state_file="$(_get_breaker_file "$model")"

    _init_breaker "$model"

    local state failure_count last_failure last_success half_open_calls
    # shellcheck disable=SC1090
    source "$state_file"

    local now
    now=$(date +%s)
    local since_failure=$((now - last_failure))
    local since_success=$((now - last_success))

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

    for model in "${models[@]}"; do
        if should_call_model "$model"; then
            available+=("$model")
        fi
    done

    # Return as comma-separated list
    IFS=,
    echo "${available[*]}"
}

# =============================================================================
# Circuit Breaker Reset Functions
# =============================================================================

# Force reset a circuit breaker to CLOSED
reset_breaker() {
    local model="$1"
    local now
    now=$(date +%s)

    _update_breaker_state "$model" "CLOSED" 0 0 "$now" 0
    log_info "Circuit breaker reset for ${model}" 2>/dev/null || true
}

# Reset all circuit breakers
reset_all_breakers() {
    local models=("claude" "gemini" "codex")

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

    if [[ ! -f "$config" ]]; then
        return 0
    fi

    # Try to read config values
    if command -v yq &>/dev/null; then
        local threshold cooldown max_calls
        threshold=$(yq eval '.circuit_breaker.failure_threshold // 3' "$config" 2>/dev/null)
        cooldown=$(yq eval '.circuit_breaker.cooldown_seconds // 60' "$config" 2>/dev/null)
        max_calls=$(yq eval '.circuit_breaker.half_open_max_calls // 1' "$config" 2>/dev/null)

        CB_FAILURE_THRESHOLD="${threshold:-3}"
        CB_COOLDOWN_SECONDS="${cooldown:-60}"
        CB_HALF_OPEN_MAX_CALLS="${max_calls:-1}"
    fi
}

# =============================================================================
# Export Functions
# =============================================================================
export -f should_call_model
export -f record_success
export -f record_failure
export -f record_result
export -f get_breaker_status
export -f get_all_breaker_status
export -f any_breakers_open
export -f get_available_models
export -f reset_breaker
export -f reset_all_breakers
export -f load_breaker_config
