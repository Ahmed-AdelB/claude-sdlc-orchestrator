#!/bin/bash
#===============================================================================
# rate-limiter.sh - Rate limiting utilities for tri-agent system
#===============================================================================
# Implements token bucket algorithm with persistent state
# Provides per-model, per-user, and global rate limiting
#===============================================================================

# Rate limiter configuration (can be overridden)
RATE_LIMIT_DIR="${STATE_DIR:-/tmp}/rate_limits"
RATE_LIMIT_WINDOW="${RATE_LIMIT_WINDOW:-60}"           # Window in seconds
RATE_LIMIT_DEFAULT="${RATE_LIMIT_DEFAULT:-100}"        # Default requests per window
RATE_LIMIT_BURST="${RATE_LIMIT_BURST:-10}"             # Burst allowance

# Model-specific limits (requests per minute)
declare -A MODEL_LIMITS=(
    ["claude"]=60
    ["gemini"]=120
    ["codex"]=90
    ["default"]=100
)

# Initialize rate limiter state directory
init_rate_limiter() {
    mkdir -p "$RATE_LIMIT_DIR"
    chmod 700 "$RATE_LIMIT_DIR"
}

# Get rate limit file for a key
_get_limit_file() {
    local key="$1"
    local safe_key
    safe_key=$(echo "$key" | tr -cd '[:alnum:]_-')
    echo "${RATE_LIMIT_DIR}/${safe_key}.json"
}

# Check if rate limit is exceeded (with atomic locking)
# Usage: check_rate_limit "key" [limit]
# Returns: 0 if allowed, 1 if rate limited
# FIX: Added flock to prevent race conditions (Tri-Agent Improvement Round 7)
check_rate_limit() {
    local key="$1"
    local limit="${2:-$RATE_LIMIT_DEFAULT}"
    local limit_file
    limit_file=$(_get_limit_file "$key")
    local lock_file="${limit_file}.lock"

    init_rate_limiter

    # Acquire lock for atomic read-modify-write
    exec 211>"$lock_file"
    if ! flock -w 5 211; then
        echo '{"error": "Could not acquire lock", "limited": true}'
        return 1
    fi

    local now
    now=$(date +%s)

    # Read current state (under lock)
    local count=0
    local window_start=$now

    if [[ -f "$limit_file" ]]; then
        local state
        state=$(cat "$limit_file" 2>/dev/null || echo '{}')
        count=$(echo "$state" | jq -r '.count // 0' 2>/dev/null || echo 0)
        window_start=$(echo "$state" | jq -r '.window_start // 0' 2>/dev/null || echo 0)
    fi

    # Check if window has expired
    local window_age=$((now - window_start))
    if [[ $window_age -ge $RATE_LIMIT_WINDOW ]]; then
        # Reset window
        count=0
        window_start=$now
    fi

    # Check limit
    if [[ $count -ge $limit ]]; then
        local retry_after=$((RATE_LIMIT_WINDOW - window_age))
        flock -u 211  # Release lock
        echo "{\"limited\": true, \"retry_after\": $retry_after, \"count\": $count, \"limit\": $limit}"
        return 1
    fi

    # Increment counter
    ((count++))

    # Write updated state (atomic write under lock)
    local tmp_file="${limit_file}.tmp.$$"
    cat > "$tmp_file" << EOF
{
    "count": $count,
    "window_start": $window_start,
    "last_request": $now,
    "limit": $limit
}
EOF
    mv "$tmp_file" "$limit_file"

    # Release lock
    flock -u 211

    echo "{\"limited\": false, \"remaining\": $((limit - count)), \"count\": $count, \"limit\": $limit}"
    return 0
}

# Check model-specific rate limit
# Usage: check_model_rate_limit "model"
check_model_rate_limit() {
    local model="$1"
    local limit="${MODEL_LIMITS[$model]:-${MODEL_LIMITS[default]}}"
    check_rate_limit "model_${model}" "$limit"
}

# Check user rate limit
# Usage: check_user_rate_limit "user_id" [limit]
check_user_rate_limit() {
    local user_id="$1"
    local limit="${2:-$RATE_LIMIT_DEFAULT}"
    check_rate_limit "user_${user_id}" "$limit"
}

# Check global rate limit
# Usage: check_global_rate_limit [limit]
check_global_rate_limit() {
    local limit="${1:-500}"
    check_rate_limit "global" "$limit"
}

# Get current rate limit status
# Usage: get_rate_limit_status "key"
get_rate_limit_status() {
    local key="$1"
    local limit_file
    limit_file=$(_get_limit_file "$key")

    if [[ -f "$limit_file" ]]; then
        cat "$limit_file"
    else
        echo '{"count": 0, "limited": false}'
    fi
}

# Reset rate limit for a key
# Usage: reset_rate_limit "key"
reset_rate_limit() {
    local key="$1"
    local limit_file
    limit_file=$(_get_limit_file "$key")
    rm -f "$limit_file"
}

# Get all rate limit statuses
get_all_rate_limits() {
    init_rate_limiter

    echo "{"
    local first=true
    for file in "$RATE_LIMIT_DIR"/*.json; do
        [[ -f "$file" ]] || continue
        local key
        key=$(basename "$file" .json)
        local status
        status=$(cat "$file" 2>/dev/null || echo '{}')

        if $first; then
            first=false
        else
            echo ","
        fi
        echo "  \"$key\": $status"
    done
    echo "}"
}

# Token bucket rate limiter (more sophisticated, with atomic locking)
# Usage: token_bucket_check "key" "rate" "burst"
# rate: tokens per second, burst: max bucket size
# FIX: Added flock to prevent race conditions (Tri-Agent Improvement Round 7)
token_bucket_check() {
    local key="$1"
    local rate="${2:-10}"      # tokens per second
    local burst="${3:-$RATE_LIMIT_BURST}"
    local limit_file
    limit_file=$(_get_limit_file "bucket_${key}")
    local lock_file="${limit_file}.lock"

    init_rate_limiter

    # Acquire lock for atomic read-modify-write
    exec 212>"$lock_file"
    if ! flock -w 5 212; then
        echo '{"error": "Could not acquire lock", "allowed": false}'
        return 1
    fi

    local now
    now=$(date +%s%N)  # Nanoseconds for precision
    local now_sec=$((now / 1000000000))

    # Read current state (under lock)
    local tokens=$burst
    local last_update=$now

    if [[ -f "$limit_file" ]]; then
        local state
        state=$(cat "$limit_file" 2>/dev/null || echo '{}')
        tokens=$(echo "$state" | jq -r '.tokens // '"$burst"'' 2>/dev/null || echo "$burst")
        last_update=$(echo "$state" | jq -r '.last_update // '"$now"'' 2>/dev/null || echo "$now")
    fi

    # Calculate tokens to add based on time elapsed
    local elapsed=$(( (now - last_update) / 1000000000 ))  # Convert to seconds
    local new_tokens=$((tokens + elapsed * rate))

    # Cap at burst limit
    if [[ $new_tokens -gt $burst ]]; then
        new_tokens=$burst
    fi

    # Check if we have a token available
    if [[ $new_tokens -lt 1 ]]; then
        local wait_time=$(echo "scale=2; (1 - $new_tokens) / $rate" | bc 2>/dev/null || echo "0.1")
        flock -u 212  # Release lock
        echo "{\"allowed\": false, \"tokens\": $new_tokens, \"wait_time\": $wait_time}"
        return 1
    fi

    # Consume a token
    new_tokens=$((new_tokens - 1))

    # Write updated state (under lock)
    local tmp_file="${limit_file}.tmp.$$"
    cat > "$tmp_file" << EOF
{
    "tokens": $new_tokens,
    "last_update": $now,
    "rate": $rate,
    "burst": $burst
}
EOF
    mv "$tmp_file" "$limit_file"

    # Release lock
    flock -u 212

    echo "{\"allowed\": true, \"tokens\": $new_tokens, \"rate\": $rate}"
    return 0
}

# Sliding window rate limiter (with atomic locking)
# More accurate than fixed windows, prevents burst at window boundaries
# FIX: Added flock to prevent race conditions (Tri-Agent Improvement Round 7)
sliding_window_check() {
    local key="$1"
    local limit="${2:-100}"
    local window="${3:-60}"
    local limit_file
    limit_file=$(_get_limit_file "sliding_${key}")
    local lock_file="${limit_file}.lock"

    init_rate_limiter

    # Acquire lock for atomic read-modify-write
    exec 213>"$lock_file"
    if ! flock -w 5 213; then
        echo '{"error": "Could not acquire lock", "limited": true}'
        return 1
    fi

    local now
    now=$(date +%s)
    local cutoff=$((now - window))

    # Read timestamps (under lock)
    local timestamps=()
    if [[ -f "$limit_file" ]]; then
        while IFS= read -r ts; do
            if [[ $ts -gt $cutoff ]]; then
                timestamps+=("$ts")
            fi
        done < "$limit_file"
    fi

    local count=${#timestamps[@]}

    # Check limit
    if [[ $count -ge $limit ]]; then
        local oldest=${timestamps[0]:-$now}
        local retry_after=$((oldest + window - now))
        flock -u 213  # Release lock
        echo "{\"limited\": true, \"count\": $count, \"limit\": $limit, \"retry_after\": $retry_after}"
        return 1
    fi

    # Add current timestamp
    timestamps+=("$now")

    # Write updated timestamps (under lock)
    printf '%s\n' "${timestamps[@]}" > "$limit_file"

    # Release lock
    flock -u 213

    echo "{\"limited\": false, \"count\": $((count + 1)), \"limit\": $limit, \"remaining\": $((limit - count - 1))}"
    return 0
}

# Distributed rate limiting helper (for multi-process scenarios)
# Uses file locking for consistency
distributed_rate_check() {
    local key="$1"
    local limit="${2:-100}"
    local lock_file="${RATE_LIMIT_DIR}/${key}.lock"

    init_rate_limiter

    # Acquire lock
    exec 210>"$lock_file"
    if ! flock -w 5 210; then
        echo '{"error": "Could not acquire lock", "limited": true}'
        return 1
    fi

    # Perform rate check
    local result
    result=$(check_rate_limit "$key" "$limit")
    local status=$?

    # Release lock
    flock -u 210

    echo "$result"
    return $status
}

# Rate limit decorator for functions
# Usage: rate_limited_call "key" "limit" command args...
rate_limited_call() {
    local key="$1"
    local limit="$2"
    shift 2

    local check_result
    check_result=$(check_rate_limit "$key" "$limit")

    if [[ $? -ne 0 ]]; then
        local retry_after
        retry_after=$(echo "$check_result" | jq -r '.retry_after')
        echo "Rate limited. Retry after ${retry_after}s" >&2
        return 1
    fi

    # Execute the command
    "$@"
}

# Clean up old rate limit files
cleanup_rate_limits() {
    local max_age="${1:-3600}"  # Default 1 hour
    local now
    now=$(date +%s)

    init_rate_limiter

    local cleaned=0
    for file in "$RATE_LIMIT_DIR"/*.json; do
        [[ -f "$file" ]] || continue

        local last_update
        last_update=$(jq -r '.last_update // .last_request // 0' "$file" 2>/dev/null || echo 0)

        # Handle nanosecond timestamps
        if [[ ${#last_update} -gt 12 ]]; then
            last_update=$((last_update / 1000000000))
        fi

        local age=$((now - last_update))
        if [[ $age -gt $max_age ]]; then
            rm -f "$file"
            ((cleaned++))
        fi
    done

    echo "Cleaned up $cleaned stale rate limit files"
}

# Export functions for use in other scripts
export -f init_rate_limiter
export -f check_rate_limit
export -f check_model_rate_limit
export -f check_user_rate_limit
export -f check_global_rate_limit
export -f get_rate_limit_status
export -f reset_rate_limit
export -f get_all_rate_limits
export -f token_bucket_check
export -f sliding_window_check
export -f distributed_rate_check
export -f rate_limited_call
export -f cleanup_rate_limits
