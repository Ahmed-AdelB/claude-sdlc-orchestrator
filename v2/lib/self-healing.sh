#!/bin/bash
# =============================================================================
# self-healing.sh - Autonomous Self-Healing Orchestrator
# =============================================================================
# Coordinates recovery from failures across all system components:
#   - Circuit breaker recovery
#   - Stale task recovery
#   - Worker pool maintenance
#   - Database integrity checks
#   - Cost overrun recovery
#   - API failover
# =============================================================================

: "${STATE_DIR:=$HOME/.claude/autonomous/state}"
: "${STATE_DB:=$STATE_DIR/tri-agent.db}"
: "${LOG_DIR:=$HOME/.claude/autonomous/logs}"
: "${BREAKERS_DIR:=$STATE_DIR/breakers}"

# Healing configuration
HEALING_INTERVAL_SECONDS=60
MAX_HEALING_RETRIES=3
HEALING_BACKOFF_BASE=2

# =============================================================================
# Health Check Functions
# =============================================================================

# Comprehensive system health check
check_system_health() {
    local health_report
    health_report=$(cat <<EOF
{
    "timestamp": "$(date -Iseconds)",
    "checks": {}
}
EOF
)

    # Check database health
    local db_health
    db_health=$(check_database_health)
    health_report=$(echo "$health_report" | jq --argjson db "$db_health" '.checks.database = $db')

    # Check circuit breakers
    local cb_health
    cb_health=$(check_circuit_breaker_health)
    health_report=$(echo "$health_report" | jq --argjson cb "$cb_health" '.checks.circuit_breakers = $cb')

    # Check worker pool
    local wp_health
    wp_health=$(check_worker_pool_health)
    health_report=$(echo "$health_report" | jq --argjson wp "$wp_health" '.checks.worker_pool = $wp')

    # Check task queue
    local tq_health
    tq_health=$(check_task_queue_health)
    health_report=$(echo "$health_report" | jq --argjson tq "$tq_health" '.checks.task_queue = $tq')

    # Check cost status
    local cost_health
    cost_health=$(check_cost_health)
    health_report=$(echo "$health_report" | jq --argjson cost "$cost_health" '.checks.cost = $cost')

    # Determine overall status
    local overall_status="healthy"
    local critical_issues=0

    for key in database circuit_breakers worker_pool task_queue cost; do
        local status
        status=$(echo "$health_report" | jq -r ".checks.$key.status // \"unknown\" ")
        if [[ "$status" == "critical" ]]; then
            overall_status="critical"
            ((critical_issues++)) || true
        elif [[ "$status" == "degraded" ]] && [[ "$overall_status" != "critical" ]]; then
            overall_status="degraded"
        fi
    done

    health_report=$(echo "$health_report" | jq --arg status "$overall_status" --argjson issues "$critical_issues" \
        '.overall_status = $status | .critical_issues = $issues')

    echo "$health_report"
}

# Database health check
check_database_health() {
    local status="healthy"
    local issues=()

    # Check if database exists and is accessible
    if [[ ! -f "$STATE_DB" ]]; then
        status="critical"
        issues+=("Database file missing")
    else
        # Check integrity
        local integrity
        integrity=$(sqlite3 "$STATE_DB" "PRAGMA integrity_check;" 2>&1)
        if [[ "$integrity" != "ok" ]]; then
            status="critical"
            issues+=("Integrity check failed: $integrity")
        fi

        # Check WAL mode
        local journal_mode
        journal_mode=$(sqlite3 "$STATE_DB" "PRAGMA journal_mode;" 2>&1)
        if [[ "$journal_mode" != "wal" ]]; then
            status="degraded"
            issues+=("Not using WAL mode")
        fi

        # Check for locked database
        if ! sqlite3 "$STATE_DB" "SELECT 1;" 2>/dev/null; then
            status="critical"
            issues+=("Database locked")
        fi
    fi

    local issues_json
    issues_json=$(printf '%s\n' "${issues[@]}" | jq -R . | jq -s . 2>/dev/null || echo "[]")

    cat <<EOF
{
    "status": "$status",
    "issues": $issues_json,
    "database_path": "$STATE_DB"
}
EOF
}

# Circuit breaker health check
check_circuit_breaker_health() {
    local status="healthy"
    local open_breakers=()

    if declare -f _read_breaker_state >/dev/null; then
        for model in claude gemini codex; do
            local breaker_state
            breaker_state=$(_read_breaker_state "$model" 2>/dev/null || echo "UNKNOWN")

            if [[ "$breaker_state" == "OPEN" ]]; then
                open_breakers+=("$model")
            fi
        done
    fi

    if [[ ${#open_breakers[@]} -eq 3 ]]; then
        status="critical"
    elif [[ ${#open_breakers[@]} -gt 0 ]]; then
        status="degraded"
    fi

    local open_breakers_json
    open_breakers_json=$(printf '%s\n' "${open_breakers[@]}" | jq -R . | jq -s . 2>/dev/null || echo "[]")
    
    local available_models_json="[]"
    if declare -f get_available_models >/dev/null; then
        available_models_json=$(get_available_models | tr ',' '\n' | jq -R . | jq -s . 2>/dev/null || echo "[]")
    fi

    cat <<EOF
{
    "status": "$status",
    "open_breakers": $open_breakers_json,
    "available_models": $available_models_json
}
EOF
}

# Worker pool health check
check_worker_pool_health() {
    local status="healthy"
    local issues=()

    # Check for stale workers
    local stale_count
    stale_count=$(sqlite3 "$STATE_DB" <<SQL 2>/dev/null || echo "0"
SELECT COUNT(*) FROM workers
WHERE status = 'busy'
AND last_heartbeat < datetime('now', '-30 minutes');
SQL
)

    if [[ "$stale_count" -gt 0 ]]; then
        status="degraded"
        issues+=("$stale_count stale workers")
    fi

    # Check worker count
    local active_workers
    active_workers=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM workers WHERE status IN ('idle', 'busy');" 2>/dev/null || echo "0")

    if [[ "$active_workers" -eq 0 ]]; then
        status="critical"
        issues+=("No active workers")
    elif [[ "$active_workers" -lt 3 ]]; then
        status="degraded"
        issues+=("Only $active_workers workers active")
    fi

    local issues_json
    issues_json=$(printf '%s\n' "${issues[@]}" | jq -R . | jq -s . 2>/dev/null || echo "[]")

    cat <<EOF
{
    "status": "$status",
    "active_workers": $active_workers,
    "stale_workers": $stale_count,
    "issues": $issues_json
}
EOF
}

# Task queue health check
check_task_queue_health() {
    local status="healthy"
    local issues=()

    # Check for stuck tasks
    local stuck_count
    stuck_count=$(sqlite3 "$STATE_DB" <<SQL 2>/dev/null || echo "0"
SELECT COUNT(*) FROM tasks
WHERE state = 'RUNNING'
AND started_at < datetime('now', '-2 hours');
SQL
)

    if [[ "$stuck_count" -gt 0 ]]; then
        status="degraded"
        issues+=("$stuck_count stuck tasks")
    fi

    # Check queue depth
    local queue_depth
    queue_depth=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM tasks WHERE state = 'QUEUED';" 2>/dev/null || echo "0")

    if [[ "$queue_depth" -gt 100 ]]; then
        status="degraded"
        issues+=("Queue depth: $queue_depth")
    fi

    # Check for failed tasks needing retry
    local failed_count
    failed_count=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM tasks WHERE state = 'FAILED' AND retry_count < 3;" 2>/dev/null || echo "0")

    local issues_json
    issues_json=$(printf '%s\n' "${issues[@]}" | jq -R . | jq -s . 2>/dev/null || echo "[]")

    cat <<EOF
{
    "status": "$status",
    "queue_depth": $queue_depth,
    "stuck_tasks": $stuck_count,
    "failed_retryable": $failed_count,
    "issues": $issues_json
}
EOF
}

# Cost health check
check_cost_health() {
    local status="healthy"
    local issues=()

    # Check if paused due to budget
    if declare -f pause_requested >/dev/null && pause_requested 2>/dev/null; then
        status="critical"
        issues+=("System paused due to budget")
    fi

    # Check daily spend rate
    local daily_spend="0"
    if declare -f calculate_daily_spend >/dev/null; then
        daily_spend=$(calculate_daily_spend 2>/dev/null || echo "0")
    fi
    local budget
budget=${COST_DAILY_BUDGET_USD:-50}

    local spend_pct=0
    if [[ "$budget" -gt 0 ]]; then
        spend_pct=$(awk "BEGIN {printf \"%.0f\", ($daily_spend / $budget) * 100}")
    fi

    if [[ "$spend_pct" -gt 90 ]]; then
        status="critical"
        issues+=("Spend at ${spend_pct}% of budget")
    elif [[ "$spend_pct" -gt 75 ]]; then
        status="degraded"
        issues+=("Spend at ${spend_pct}% of budget")
    fi

    local issues_json
    issues_json=$(printf '%s\n' "${issues[@]}" | jq -R . | jq -s . 2>/dev/null || echo "[]")
    local paused_str
    if declare -f pause_requested >/dev/null && pause_requested 2>/dev/null; then
        paused_str="true"
    else
        paused_str="false"
    fi

    cat <<EOF
{
    "status": "$status",
    "daily_spend": $daily_spend,
    "budget": $budget,
    "spend_percent": $spend_pct,
    "paused": $paused_str,
    "issues": $issues_json
}
EOF
}

# =============================================================================
# Healing Functions
# =============================================================================

# Execute healing for all detected issues
execute_healing() {
    local health_report="$1"
    local healing_log="${LOG_DIR}/healing-$(date +%Y%m%d).jsonl"

    log_info "Executing self-healing..."

    local healed=0
    local failed=0

    # Heal database issues
    local db_status
    db_status=$(echo "$health_report" | jq -r '.checks.database.status // "unknown"')
    if [[ "$db_status" != "healthy" ]]; then
        if heal_database; then
            ((healed++)) || true
        else
            ((failed++)) || true
        fi
    fi

    # Heal circuit breaker issues
    local cb_status
    cb_status=$(echo "$health_report" | jq -r '.checks.circuit_breakers.status // "unknown"')
    if [[ "$cb_status" != "healthy" ]]; then
        if heal_circuit_breakers; then
            ((healed++)) || true
        else
            ((failed++)) || true
        fi
    fi

    # Heal worker pool issues
    local wp_status
    wp_status=$(echo "$health_report" | jq -r '.checks.worker_pool.status // "unknown"')
    if [[ "$wp_status" != "healthy" ]]; then
        if heal_worker_pool; then
            ((healed++)) || true
        else
            ((failed++)) || true
        fi
    fi

    # Heal task queue issues
    local tq_status
    tq_status=$(echo "$health_report" | jq -r '.checks.task_queue.status // "unknown"')
    if [[ "$tq_status" != "healthy" ]]; then
        if heal_task_queue; then
            ((healed++)) || true
        else
            ((failed++)) || true
        fi
    fi

    # Log healing results
    local log_entry
    log_entry=$(cat <<EOF
{"timestamp":"$(date -Iseconds)","healed":$healed,"failed":$failed,"overall_status":"$(echo "$health_report" | jq -r '.overall_status')"}
EOF
)
    echo "$log_entry" >> "$healing_log"

    log_info "Self-healing complete: $healed healed, $failed failed"
}

# Heal database issues
heal_database() {
    log_info "Healing database..."

    # If database is locked, try to unlock
    if ! sqlite3 "$STATE_DB" "SELECT 1;" 2>/dev/null; then
        log_warn "Attempting to recover locked database"

        # Check for stuck WAL checkpoint
        sqlite3 "$STATE_DB" "PRAGMA wal_checkpoint(TRUNCATE);" 2>/dev/null || true

        # If still locked, it might be another process
        local lock_holder
        lock_holder=$(fuser "$STATE_DB" 2>/dev/null || echo "")
        if [[ -n "$lock_holder" ]]; then
            log_warn "Database held by PID: $lock_holder"
            # Don't kill - let watchdog handle
        fi
    fi

    # If not using WAL mode, enable it
    local journal_mode
    journal_mode=$(sqlite3 "$STATE_DB" "PRAGMA journal_mode;" 2>&1)
    if [[ "$journal_mode" != "wal" ]]; then
        log_info "Enabling WAL mode"
        sqlite3 "$STATE_DB" "PRAGMA journal_mode=WAL;" 2>/dev/null || true
    fi

    # Vacuum if fragmented
    sqlite3 "$STATE_DB" "PRAGMA auto_vacuum=INCREMENTAL;" 2>/dev/null || true

    return 0
}

# Heal circuit breaker issues
heal_circuit_breakers() {
    log_info "Healing circuit breakers..."

    local now
    now=$(date +%s)

    if declare -f _read_breaker_state >/dev/null; then
        for model in claude gemini codex; do
            local state
            state=$(_read_breaker_state "$model" 2>/dev/null || echo "CLOSED")

            if [[ "$state" == "OPEN" ]]; then
                # Check if cooldown has elapsed
                local last_failure
                last_failure=$(grep -E "^last_failure=" "${BREAKERS_DIR}/${model}.state" 2>/dev/null | cut -d= -f2 || echo "0")
                local elapsed=$((now - last_failure))

                if [[ $elapsed -gt 120 ]]; then
                    # Transition to HALF_OPEN for testing
                    log_info "Transitioning $model circuit breaker to HALF_OPEN after ${elapsed}s"
                    _update_breaker_state "$model" "HALF_OPEN" 0 "$last_failure" "$now" 0
                fi
            fi
        done
    fi

    return 0
}

# Heal worker pool issues
heal_worker_pool() {
    log_info "Healing worker pool..."

    # Mark stale workers as dead
    sqlite3 "$STATE_DB" <<SQL
UPDATE workers
SET status = 'dead'
WHERE status = 'busy'
AND last_heartbeat < datetime('now', '-30 minutes');
SQL

    # Re-queue tasks from dead workers
    sqlite3 "$STATE_DB" <<SQL
UPDATE tasks
SET state = 'QUEUED',
    worker_id = NULL,
    retry_count = retry_count + 1
WHERE state = 'RUNNING'
AND worker_id IN (SELECT worker_id FROM workers WHERE status = 'dead');
SQL

    return 0
}

# Heal task queue issues
heal_task_queue() {
    log_info "Healing task queue..."

    # Re-queue stuck tasks
    local stuck_count
    stuck_count=$(sqlite3 "$STATE_DB" <<SQL
UPDATE tasks
SET state = 'QUEUED',
    worker_id = NULL,
    retry_count = retry_count + 1
WHERE state = 'RUNNING'
AND started_at < datetime('now', '-2 hours')
AND retry_count < 3;
SELECT changes();
SQL
)

    if [[ "$stuck_count" -gt 0 ]]; then
        log_info "Re-queued $stuck_count stuck tasks"
    fi

    # Retry failed tasks with remaining retries
    local retried_count
    retried_count=$(sqlite3 "$STATE_DB" <<SQL
UPDATE tasks
SET state = 'QUEUED'
WHERE state = 'FAILED'
AND retry_count < 3
AND error_type NOT IN ('auth_error', 'invalid_input');
SELECT changes();
SQL
)

    if [[ "$retried_count" -gt 0 ]]; then
        log_info "Retried $retried_count failed tasks"
    fi

    return 0
}

# =============================================================================
# Self-Healing Daemon
# =============================================================================

# Main healing loop
run_healing_loop() {
    log_info "Self-healing orchestrator starting..."

    while true; do
        # Perform health check
        local health_report
        health_report=$(check_system_health)

        local overall_status
        overall_status=$(echo "$health_report" | jq -r '.overall_status // "unknown"')

        if [[ "$overall_status" != "healthy" ]]; then
            log_warn "System status: $overall_status - initiating healing"
            execute_healing "$health_report"
        else
            log_debug "System healthy"
        fi

        # Write health status file
        echo "$health_report" > "${STATE_DIR}/health.json"

        sleep "$HEALING_INTERVAL_SECONDS"
    done
}

# Export functions
export -f check_system_health
export -f check_database_health
export -f check_circuit_breaker_health
export -f check_worker_pool_health
export -f check_task_queue_health
export -f check_cost_health
export -f execute_healing
export -f heal_database
export -f heal_circuit_breakers
export -f heal_worker_pool
export -f heal_task_queue
export -f run_healing_loop
