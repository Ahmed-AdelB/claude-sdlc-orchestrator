#!/bin/bash
# =============================================================================
# supervisor-communicator.sh - Inter-Session Communication for Supervisor
# =============================================================================
# Handles communication between supervisor and primary session via:
# - Task queue (file-based)
# - Tmux notifications
# - Response monitoring
#
# Usage: source this file in tri-agent-supervisor
# =============================================================================

# Communicator version
SUPERVISOR_COMMUNICATOR_VERSION="1.0.0"

# =============================================================================
# Configuration
# =============================================================================

COMM_RATE_LIMIT_SECONDS="${COMM_RATE_LIMIT_SECONDS:-60}"
COMM_MAX_RETRIES="${COMM_MAX_RETRIES:-3}"
COMM_RESPONSE_TIMEOUT="${COMM_RESPONSE_TIMEOUT:-300}"

# State for rate limiting
declare -g COMM_LAST_SEND_TIME=0

# =============================================================================
# Task Queue Management
# =============================================================================

# Inject a task into the primary session's queue
inject_task_to_queue() {
    local task_file="$1"
    local notify="${2:-true}"

    if [[ ! -f "$task_file" ]]; then
        log_error "Task file not found: $task_file"
        return 1
    fi

    local queue_dir="${TASKS_DIR}/queue"
    ensure_dir "$queue_dir"

    # Copy to queue if not already there
    if [[ "$(dirname "$task_file")" != "$queue_dir" ]]; then
        cp "$task_file" "$queue_dir/"
        log_info "Task injected to queue: $(basename "$task_file")"
    fi

    # Optionally notify primary session
    if [[ "$notify" == "true" ]]; then
        send_tmux_notification "New task in queue: $(basename "$task_file")" "INFO"
    fi

    return 0
}

# Move task to completed
mark_task_completed() {
    local task_file="$1"
    local completed_dir="${TASKS_DIR}/completed"

    ensure_dir "$completed_dir"

    if [[ -f "$task_file" ]]; then
        mv "$task_file" "$completed_dir/"
        log_info "Task marked completed: $(basename "$task_file")"
    fi
}

# Move task to failed
mark_task_failed() {
    local task_file="$1"
    local reason="${2:-Unknown}"
    local failed_dir="${TASKS_DIR}/failed"

    ensure_dir "$failed_dir"

    if [[ -f "$task_file" ]]; then
        # Append failure reason
        echo -e "\n---\n## Failure Reason\n${reason}\n" >> "$task_file"
        mv "$task_file" "$failed_dir/"
        log_warn "Task marked failed: $(basename "$task_file") - $reason"
    fi
}

# =============================================================================
# Tmux Communication
# =============================================================================

# Send notification to primary session via tmux
send_tmux_notification() {
    local message="$1"
    local priority="${2:-INFO}"
    local session="${PRIMARY_SESSION:-tri-agent-aadel-v2}"
    local socket="${TMUX_SOCKET:-tri-agent}"

    # Rate limiting
    local current_time=$(date +%s)
    local time_diff=$((current_time - COMM_LAST_SEND_TIME))

    if [[ $time_diff -lt $COMM_RATE_LIMIT_SECONDS ]]; then
        log_debug "Rate limited tmux notification (${time_diff}s < ${COMM_RATE_LIMIT_SECONDS}s)"
        return 0
    fi

    # Check if session exists
    if ! tmux -L "$socket" has-session -t "$session" 2>/dev/null; then
        log_warn "Primary session not found: $session"
        return 1
    fi

    # Format message
    local formatted="SUPERVISOR [${priority}]: ${message}"

    # Send to tmux
    if tmux -L "$socket" send-keys -t "$session" "$formatted" Enter 2>/dev/null; then
        COMM_LAST_SEND_TIME=$current_time
        log_info "Notification sent: $formatted"
        return 0
    else
        log_error "Failed to send notification to $session"
        return 1
    fi
}

# Send urgent notification (bypasses rate limiting)
send_urgent_notification() {
    local message="$1"
    local session="${PRIMARY_SESSION:-tri-agent-aadel-v2}"
    local socket="${TMUX_SOCKET:-tri-agent}"

    # Check if session exists
    if ! tmux -L "$socket" has-session -t "$session" 2>/dev/null; then
        log_warn "Primary session not found: $session"
        return 1
    fi

    local formatted="!!! SUPERVISOR URGENT !!!: ${message}"

    tmux -L "$socket" send-keys -t "$session" "$formatted" Enter 2>/dev/null
    log_warn "URGENT notification sent: $message"
}

# =============================================================================
# Response Monitoring
# =============================================================================

# Wait for task completion
wait_for_task_completion() {
    local task_id="$1"
    local timeout="${2:-$COMM_RESPONSE_TIMEOUT}"
    local queue_dir="${TASKS_DIR}/queue"
    local completed_dir="${TASKS_DIR}/completed"

    local start_time=$(date +%s)
    local elapsed=0

    log_info "Waiting for task $task_id completion (timeout: ${timeout}s)..."

    while [[ $elapsed -lt $timeout ]]; do
        # Check if task moved to completed
        if ls "${completed_dir}"/*"${task_id}"* 2>/dev/null | head -1 | grep -q .; then
            log_info "Task $task_id completed"
            return 0
        fi

        # Check if task no longer in queue (might be completed or failed)
        if ! ls "${queue_dir}"/*"${task_id}"* 2>/dev/null | head -1 | grep -q .; then
            # Check failed directory
            if ls "${TASKS_DIR}/failed"/*"${task_id}"* 2>/dev/null | head -1 | grep -q .; then
                log_warn "Task $task_id failed"
                return 2
            fi
            log_info "Task $task_id no longer in queue (assumed completed)"
            return 0
        fi

        sleep 10
        elapsed=$(($(date +%s) - start_time))
    done

    log_warn "Timeout waiting for task $task_id"
    return 1
}

# Check if primary session is responsive
check_primary_session_responsive() {
    local session="${PRIMARY_SESSION:-tri-agent-aadel-v2}"
    local socket="${TMUX_SOCKET:-tri-agent}"

    # Check session exists
    if ! tmux -L "$socket" has-session -t "$session" 2>/dev/null; then
        return 1
    fi

    # Try to capture pane content (non-invasive check)
    if tmux -L "$socket" capture-pane -t "$session" -p 2>/dev/null | head -1 | grep -q .; then
        return 0
    fi

    return 1
}

# =============================================================================
# Batch Communication
# =============================================================================

# Send daily summary to primary session
send_daily_summary() {
    local queue_dir="${TASKS_DIR}/queue"
    local completed_dir="${TASKS_DIR}/completed"
    local failed_dir="${TASKS_DIR}/failed"

    local pending=$(ls -1 "$queue_dir"/*.md 2>/dev/null | wc -l || echo "0")
    local completed_today=$(find "$completed_dir" -name "*.md" -mtime 0 2>/dev/null | wc -l || echo "0")
    local failed_today=$(find "$failed_dir" -name "*.md" -mtime 0 2>/dev/null | wc -l || echo "0")

    local summary="Daily Summary: ${pending} pending, ${completed_today} completed, ${failed_today} failed today"

    send_tmux_notification "$summary" "INFO"
}

# =============================================================================
# Logging Integration
# =============================================================================

# Log communication event
log_comm_event() {
    local event_type="$1"
    local details="$2"
    local log_file="${LOG_DIR}/supervisor-comm.jsonl"

    local entry=$(cat <<EOF
{"timestamp":"$(iso_timestamp)","event":"$event_type","details":$(echo "$details" | jq -Rs .),"trace_id":"${TRACE_ID}"}
EOF
)

    echo "$entry" >> "$log_file"
}

# =============================================================================
# Utility Functions
# =============================================================================

# Get primary session info
get_primary_session_info() {
    local session="${PRIMARY_SESSION:-tri-agent-aadel-v2}"
    local socket="${TMUX_SOCKET:-tri-agent}"

    if tmux -L "$socket" has-session -t "$session" 2>/dev/null; then
        echo "Session: $session (active)"
        tmux -L "$socket" list-windows -t "$session" 2>/dev/null | head -3
    else
        echo "Session: $session (not found)"
    fi
}

# Test communication channel
test_communication() {
    echo "=== Communication Channel Test ==="
    echo ""
    echo "Primary Session: ${PRIMARY_SESSION:-tri-agent-aadel-v2}"
    echo "Tmux Socket: ${TMUX_SOCKET:-tri-agent}"
    echo ""

    if check_primary_session_responsive; then
        echo "Status: CONNECTED"
        get_primary_session_info
    else
        echo "Status: DISCONNECTED"
    fi

    echo ""
    echo "Task Queue: $(get_pending_task_count 2>/dev/null || echo "0") pending tasks"
}
