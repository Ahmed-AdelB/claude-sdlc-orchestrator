#!/bin/bash
# =============================================================================
# heartbeat.sh - Progressive heartbeat management
# =============================================================================
# Provides:
# - Task-type-aware timeout profiles (5/15/30 min)
# - Activity detection helpers
# - Stale worker recovery
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

AUTONOMOUS_ROOT="${AUTONOMOUS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
STATE_DIR="${STATE_DIR:-${AUTONOMOUS_ROOT}/state}"
STATE_DB="${STATE_DB:-${STATE_DIR}/tri-agent.db}"
TRACE_ID="${TRACE_ID:-heartbeat-$(date +%Y%m%d%H%M%S)-$$}"

# Optional logging if common.sh is available
if [[ -f "${AUTONOMOUS_ROOT}/lib/common.sh" ]]; then
    # shellcheck source=/dev/null
    source "${AUTONOMOUS_ROOT}/lib/common.sh"
fi

if [[ -f "${AUTONOMOUS_ROOT}/lib/sqlite-state.sh" ]]; then
    # shellcheck source=/dev/null
    source "${AUTONOMOUS_ROOT}/lib/sqlite-state.sh"
fi

_heartbeat_require_sqlite() {
    if ! command -v sqlite3 >/dev/null 2>&1; then
        echo "Error: sqlite3 not found in PATH" >&2
        return 1
    fi
}

heartbeat_timeout_for_task_type() {
    local task_type="${1:-}"
    local upper
    upper=$(printf '%s' "$task_type" | tr '[:lower:]' '[:upper:]')

    case "$upper" in
        LINT*|FORMAT*|REVIEW*|DOC*|QUICK*)
            echo 300 ;;   # 5 min
        TEST*|COVERAGE*|FULL_BUILD*|SECURITY*|AUDIT*|RESEARCH*|ANALYSIS*)
            echo 1800 ;;  # 30 min
        *)
            echo 900 ;;   # 15 min
    esac
}

heartbeat_record() {
    local worker_id="$1"
    local status="$2"
    local task_id="${3:-}"
    local task_type="${4:-}"
    local progress_percent="${5:-0}"

    _heartbeat_require_sqlite
    sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true

    local expected_timeout
    expected_timeout=$(heartbeat_timeout_for_task_type "$task_type")

    local esc_worker esc_status esc_task esc_type
    esc_worker=$(_sql_escape "$worker_id")
    esc_status=$(_sql_escape "$status")
    esc_task=$(_sql_escape "$task_id")
    esc_type=$(_sql_escape "$task_type")

    sqlite3 "$STATE_DB" <<SQL
INSERT OR REPLACE INTO workers (worker_id, pid, status, last_heartbeat)
VALUES ('${esc_worker}', NULL, '${esc_status}', datetime('now'));

INSERT OR REPLACE INTO worker_heartbeats
    (worker_id, timestamp, status, task_id, task_type, progress_percent, expected_timeout, last_activity_at, updated_at)
VALUES
    ('${esc_worker}', datetime('now'), '${esc_status}', '${esc_task}', '${esc_type}', ${progress_percent}, ${expected_timeout}, datetime('now'), datetime('now'));
SQL
}

heartbeat_record_activity() {
    local worker_id="$1"
    local task_id="${2:-}"

    _heartbeat_require_sqlite
    sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true

    local esc_worker esc_task
    esc_worker=$(_sql_escape "$worker_id")
    esc_task=$(_sql_escape "$task_id")

    sqlite3 "$STATE_DB" <<SQL
UPDATE worker_heartbeats
SET last_activity_at=datetime('now'), updated_at=datetime('now')
WHERE worker_id='${esc_worker}';

UPDATE tasks
SET last_activity_at=datetime('now'), updated_at=datetime('now')
WHERE id='${esc_task}';
SQL
}

update_heartbeat_sqlite() {
    local worker_id="${1:-${WORKER_ID:-}}"
    local arg2="${2:-}"
    local arg3="${3:-}"
    local arg4="${4:-}"
    local arg5="${5:-0}"

    if [[ -z "$worker_id" ]]; then
        echo "Error: worker_id is required for update_heartbeat_sqlite" >&2
        return 1
    fi

    local status=""
    local task_id=""
    local task_type=""
    local progress_percent="0"

    case "$arg2" in
        starting|idle|busy|paused|stopping|dead|stale)
            status="$arg2"
            task_id="$arg3"
            task_type="$arg4"
            progress_percent="${arg5:-0}"
            ;;
        *)
            task_id="$arg2"
            status="${arg3:-busy}"
            task_type="$arg4"
            progress_percent="${arg5:-0}"
            ;;
    esac

    if [[ -z "$task_id" && -n "${CURRENT_TASK:-}" ]]; then
        task_id="$CURRENT_TASK"
    fi
    if [[ -z "$task_type" && -n "${CURRENT_TASK_TYPE:-}" ]]; then
        task_type="$CURRENT_TASK_TYPE"
    fi
    if [[ -z "$status" ]]; then
        status="busy"
    fi

    heartbeat_record "$worker_id" "$status" "$task_id" "$task_type" "$progress_percent"

    if [[ -n "$task_id" ]]; then
        heartbeat_record_activity "$worker_id" "$task_id"
    fi
}

heartbeat_check_stale() {
    local grace_multiplier="${1:-1.5}"

    _heartbeat_require_sqlite
    sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true

    local rows
    rows=$(sqlite3 "$STATE_DB" -separator '|' <<SQL
SELECT
    h.worker_id,
    h.task_id,
    h.task_type,
    h.expected_timeout,
    CAST((julianday('now') - julianday(h.timestamp)) * 86400 AS INTEGER) AS heartbeat_age,
    CAST((julianday('now') - julianday(COALESCE(h.last_activity_at, h.timestamp))) * 86400 AS INTEGER) AS activity_age
FROM worker_heartbeats h
JOIN tasks t ON t.id = h.task_id
WHERE h.status = 'busy' AND t.state = 'RUNNING';
SQL
)

    local row
    while IFS='|' read -r worker_id task_id task_type expected_timeout heartbeat_age activity_age; do
        [[ -z "$worker_id" || -z "$task_id" ]] && continue

        local timeout
        timeout="${expected_timeout:-$(heartbeat_timeout_for_task_type "$task_type")}"
        local stale_heartbeat=0
        local stale_activity=0

        if [[ -n "$heartbeat_age" ]] && awk "BEGIN{exit !($heartbeat_age > $timeout * $grace_multiplier)}"; then
            stale_heartbeat=1
        fi
        if [[ -n "$activity_age" ]] && awk "BEGIN{exit !($activity_age > $timeout)}"; then
            stale_activity=1
        fi

        if [[ $stale_heartbeat -eq 1 || $stale_activity -eq 1 ]]; then
            recover_stale_task "$task_id" "$worker_id" "stale heartbeat or activity"
        fi
    done <<< "$rows"
}

mark_worker_dead() {
    local worker_id="$1"
    local reason="${2:-unknown}"

    _heartbeat_require_sqlite
    sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true

    if command -v sqlite3 &>/dev/null && [[ -f "$STATE_DB" ]]; then
        local esc_worker_id esc_reason
        esc_worker_id="${worker_id//\'/\'\'}"
        esc_reason="${reason//\'/\'\'}"

        sqlite3 "$STATE_DB" <<SQL
UPDATE workers
SET status='dead',
    last_heartbeat=datetime('now')
WHERE worker_id='${esc_worker_id}';

INSERT INTO events (task_id, event_type, actor, payload, trace_id)
VALUES (
    NULL,
    'WORKER_CRASH_DETECTED',
    'heartbeat',
    '{"worker_id":"${esc_worker_id}","reason":"${esc_reason}"}',
    '${TRACE_ID}'
);
SQL
    fi
}

detect_crashed_workers_sqlite() {
    local threshold_minutes="${1:-5}"
    local grace_multiplier="${2:-1.5}"

    _heartbeat_require_sqlite
    sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true

    local rows
    rows=$(sqlite3 "$STATE_DB" -separator '|' <<SQL
SELECT
    w.worker_id,
    w.pid,
    w.status,
    t.id,
    t.type,
    h.expected_timeout,
    CAST((julianday('now') - julianday(COALESCE(h.updated_at, h.timestamp, w.last_heartbeat))) * 86400 AS INTEGER) AS heartbeat_age
FROM workers w
LEFT JOIN worker_heartbeats h ON h.worker_id = w.worker_id
LEFT JOIN tasks t ON t.worker_id = w.worker_id AND t.state = 'RUNNING'
WHERE w.status NOT IN ('dead','stopping')
  AND (w.last_heartbeat IS NOT NULL OR h.timestamp IS NOT NULL);
SQL
)

    while IFS='|' read -r worker_id pid status task_id task_type expected_timeout heartbeat_age; do
        [[ -z "$worker_id" ]] && continue

        if [[ -z "$heartbeat_age" ]] || ! [[ "$heartbeat_age" =~ ^[0-9]+$ ]]; then
            continue
        fi

        local timeout_seconds
        if [[ -n "$expected_timeout" ]] && [[ "$expected_timeout" =~ ^[0-9]+$ ]] && [[ "$expected_timeout" -gt 0 ]]; then
            timeout_seconds="$expected_timeout"
        elif [[ -n "$task_type" ]]; then
            timeout_seconds=$(heartbeat_timeout_for_task_type "$task_type")
        else
            timeout_seconds=$((threshold_minutes * 60))
        fi

        if awk "BEGIN{exit !($heartbeat_age > $timeout_seconds * $grace_multiplier)}"; then
            local reason="stale heartbeat age=${heartbeat_age}s timeout=${timeout_seconds}s"
            if [[ -n "$task_id" ]]; then
                recover_stale_task "$task_id" "$worker_id" "$reason"
            fi
            mark_worker_dead "$worker_id" "$reason"
        fi
    done <<< "$rows"
}

check_stale_workers_sqlite() {
    local threshold_minutes="${1:-5}"
    local grace_multiplier="${2:-1.5}"

    _heartbeat_require_sqlite
    sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true

    if declare -F heartbeat_check_stale >/dev/null 2>&1; then
        heartbeat_check_stale "$grace_multiplier"
    fi
    if declare -F detect_crashed_workers_sqlite >/dev/null 2>&1; then
        detect_crashed_workers_sqlite "$threshold_minutes" "$grace_multiplier"
    fi

    local rows
    rows=$(sqlite3 "$STATE_DB" -separator '|' <<SQL
SELECT
    w.worker_id,
    t.id,
    w.last_heartbeat
FROM workers w
LEFT JOIN worker_heartbeats h ON h.worker_id = w.worker_id
LEFT JOIN tasks t ON t.worker_id = w.worker_id AND t.state='RUNNING'
WHERE h.worker_id IS NULL
  AND w.status NOT IN ('dead','stopping')
  AND (w.last_heartbeat IS NULL OR w.last_heartbeat < datetime('now', '-$threshold_minutes minutes'));
SQL
)

    while IFS='|' read -r worker_id task_id last_heartbeat; do
        [[ -z "$worker_id" ]] && continue

        if [[ -n "$task_id" ]]; then
            recover_stale_task "$task_id" "$worker_id" "heartbeat_timeout"
            mark_worker_dead "$worker_id" "heartbeat_timeout"
        else
            if declare -F log_warn >/dev/null 2>&1; then
                log_warn "[HEARTBEAT] Stale worker detected: $worker_id (last_heartbeat=${last_heartbeat:-unknown})"
            else
                echo "[WARN] [HEARTBEAT] Stale worker detected: $worker_id (last_heartbeat=${last_heartbeat:-unknown})" >&2
            fi
            mark_worker_dead "$worker_id" "heartbeat_timeout"
        fi
    done <<< "$rows"
}

#===============================================================================
# Task Recovery Functions
#===============================================================================
# Enhanced recovery that handles both file system operations and SQLite state.
# This function wraps the sqlite-state.sh version with file operations.

recover_stale_tasks() {
    local timeout_seconds="${1:-}"
    local use_task_timeout=0

    if [[ -z "$timeout_seconds" ]]; then
        use_task_timeout=1
    elif ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]]; then
        timeout_seconds="900"
    fi

    _heartbeat_require_sqlite
    sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true

    if declare -F log_info >/dev/null 2>&1; then
        if [[ $use_task_timeout -eq 1 ]]; then
            log_info "[RECOVERY] Scanning for stale tasks (timeout: task-type)"
        else
            log_info "[RECOVERY] Scanning for stale tasks (timeout: ${timeout_seconds}s)"
        fi
    else
        if [[ $use_task_timeout -eq 1 ]]; then
            echo "[INFO] [RECOVERY] Scanning for stale tasks (timeout: task-type)" >&2
        else
            echo "[INFO] [RECOVERY] Scanning for stale tasks (timeout: ${timeout_seconds}s)" >&2
        fi
    fi

    local rows
    rows=$(sqlite3 "$STATE_DB" -separator '|' <<SQL
SELECT
    t.id,
    t.type,
    t.worker_id,
    w.pid,
    w.status,
    CAST((julianday('now') - julianday(w.last_heartbeat)) * 86400 AS INTEGER) AS worker_heartbeat_age,
    CAST((julianday('now') - julianday(COALESCE(t.last_activity_at, t.heartbeat_at, t.started_at, t.updated_at))) * 86400 AS INTEGER) AS task_age
FROM tasks t
LEFT JOIN workers w ON w.worker_id = t.worker_id
WHERE t.state='RUNNING';
SQL
)

    local recovered=0
    while IFS='|' read -r task_id task_type worker_id pid status worker_heartbeat_age task_age; do
        [[ -z "$task_id" ]] && continue
        [[ -z "$task_age" ]] && continue

        local effective_timeout
        if [[ $use_task_timeout -eq 1 ]]; then
            effective_timeout=$(heartbeat_timeout_for_task_type "$task_type")
        else
            effective_timeout="$timeout_seconds"
        fi

        if ! awk "BEGIN{exit !($task_age > $effective_timeout)}"; then
            continue
        fi

        local worker_alive=0
        if [[ -n "$worker_id" ]]; then
            if [[ "$status" == "dead" || "$status" == "stopping" ]]; then
                worker_alive=0
            elif [[ -n "$pid" && "$pid" =~ ^[0-9]+$ ]]; then
                if kill -0 "$pid" 2>/dev/null; then
                    worker_alive=1
                fi
            elif [[ -n "$worker_heartbeat_age" ]]; then
                if awk "BEGIN{exit !($worker_heartbeat_age <= $effective_timeout)}"; then
                    worker_alive=1
                fi
            fi
        fi

        if [[ $worker_alive -eq 1 ]]; then
            if declare -F log_info >/dev/null 2>&1; then
                log_info "[RECOVERY] Stale task still has active worker: $task_id (worker: $worker_id, age: ${task_age}s)"
            else
                echo "[INFO] [RECOVERY] Stale task still has active worker: $task_id (worker: $worker_id, age: ${task_age}s)" >&2
            fi
            continue
        fi

        local reason="stale running task age=${task_age}s timeout=${effective_timeout}s"
        recover_stale_task "$task_id" "${worker_id:-unknown}" "$reason"
        ((recovered++)) || true
    done <<< "$rows"

    if declare -F log_info >/dev/null 2>&1; then
        log_info "[RECOVERY] Stale task recovery complete (recovered: $recovered)"
    else
        echo "[INFO] [RECOVERY] Stale task recovery complete (recovered: $recovered)" >&2
    fi

    echo "$recovered"
}

recover_stale_task() {
    local task_id="$1"
    local worker_id="${2:-unknown}"
    local reason="${3:-unknown}"

    # Use logging if available, fall back to echo
    if declare -F log_warn >/dev/null 2>&1; then
        log_warn "[RECOVERY] Recovering stale task: $task_id (worker: $worker_id, reason: $reason)"
    else
        echo "[WARN] [RECOVERY] Recovering stale task: $task_id (worker: $worker_id, reason: $reason)" >&2
    fi

    local running_dir="${AUTONOMOUS_ROOT}/tasks/running"
    local queue_dir="${AUTONOMOUS_ROOT}/tasks/queue"
    local task_file="${running_dir}/${task_id}"

    # Find task file if not exact match
    if [[ ! -f "$task_file" ]]; then
        task_file=$(find "$running_dir" -maxdepth 1 -name "*${task_id}*" -type f 2>/dev/null | head -1)
    fi

    if [[ -n "$task_file" && -f "$task_file" ]]; then
        local task_name
        task_name=$(basename "$task_file")
        local lock_file="${running_dir}/${task_name}.lock"
        local lock_dir="${running_dir}/${task_name}.lock.d"

        # Release locks
        rm -f "$lock_file" 2>/dev/null || true
        rmdir "$lock_dir" 2>/dev/null || true

        # Ensure queue directory exists
        mkdir -p "$queue_dir"

        # Move back to queue
        if mv "$task_file" "$queue_dir/" 2>/dev/null; then
            if declare -F log_info >/dev/null 2>&1; then
                log_info "[RECOVERY] Task requeued: $task_name"
            else
                echo "[INFO] [RECOVERY] Task requeued: $task_name" >&2
            fi
        else
            if declare -F log_error >/dev/null 2>&1; then
                log_error "[RECOVERY] Failed to requeue task: $task_name"
            else
                echo "[ERROR] [RECOVERY] Failed to requeue task: $task_name" >&2
            fi
            return 1
        fi
    fi

    # Update SQLite state if available
    if command -v sqlite3 &>/dev/null && [[ -f "$STATE_DB" ]]; then
        local esc_task_id esc_worker_id esc_reason
        esc_task_id="${task_id//\'/\'\'}"
        esc_worker_id="${worker_id//\'/\'\'}"
        esc_reason="${reason//\'/\'\'}"

        sqlite3 "$STATE_DB" <<SQL
-- Update task state to QUEUED
UPDATE tasks
SET state='QUEUED',
    worker_id=NULL,
    updated_at=datetime('now'),
    retry_count = COALESCE(retry_count, 0) + 1
WHERE id='${esc_task_id}';

    -- Mark worker as dead
    UPDATE workers
    SET status='dead',
        last_heartbeat=datetime('now')
    WHERE worker_id='${esc_worker_id}';

-- Log recovery event
INSERT INTO events (task_id, event_type, actor, payload, trace_id)
VALUES (
    '${esc_task_id}',
    'TASK_RECOVERED',
    'heartbeat',
    '{"reason": "${esc_reason}", "worker": "${esc_worker_id}"}',
    '${TRACE_ID}'
);
SQL
    fi

    # Log to ledger file
    local ledger_file="${AUTONOMOUS_ROOT}/logs/ledger.jsonl"
    mkdir -p "$(dirname "$ledger_file")"
    printf '{"timestamp":"%s","event":"TASK_RECOVERED","task":"%s","worker":"%s","reason":"%s","trace_id":"%s"}\n' \
        "$(date -Iseconds)" "$task_id" "$worker_id" "$reason" "$TRACE_ID" >> "$ledger_file"

    return 0
}

# Batch recovery of zombie tasks - tasks stuck in RUNNING with dead workers
recover_zombie_tasks() {
    local timeout_minutes="${1:-60}"

    if declare -F log_info >/dev/null 2>&1; then
        log_info "[RECOVERY] Scanning for zombie tasks (timeout: ${timeout_minutes}m)"
    else
        echo "[INFO] [RECOVERY] Scanning for zombie tasks (timeout: ${timeout_minutes}m)" >&2
    fi

    local recovered=0

    if command -v sqlite3 &>/dev/null && [[ -f "$STATE_DB" ]]; then
        # Get count of tasks to recover before the update
        recovered=$(sqlite3 "$STATE_DB" <<SQL
SELECT COUNT(*) FROM tasks
WHERE state='RUNNING'
  AND worker_id IN (
      SELECT worker_id FROM workers
      WHERE last_heartbeat < datetime('now', '-$timeout_minutes minutes')
  );
SQL
)
        # Perform the recovery
        sqlite3 "$STATE_DB" <<SQL
BEGIN IMMEDIATE;

-- Requeue zombie tasks
UPDATE tasks
SET state='QUEUED',
    worker_id=NULL,
    updated_at=datetime('now'),
    retry_count = COALESCE(retry_count, 0) + 1
WHERE state='RUNNING'
  AND worker_id IN (
      SELECT worker_id FROM workers
      WHERE last_heartbeat < datetime('now', '-$timeout_minutes minutes')
  );

-- Mark dead workers
UPDATE workers
SET status='dead'
WHERE last_heartbeat < datetime('now', '-$timeout_minutes minutes')
  AND status != 'dead';

-- Log batch recovery event
INSERT INTO events (task_id, event_type, actor, payload, trace_id)
VALUES (
    NULL,
    'ZOMBIE_RECOVERY',
    'heartbeat',
    '{"timeout_minutes": $timeout_minutes, "recovered_count": $recovered}',
    '${TRACE_ID}'
);

COMMIT;
SQL

        if declare -F log_info >/dev/null 2>&1; then
            log_info "[RECOVERY] Recovered $recovered zombie tasks"
        else
            echo "[INFO] [RECOVERY] Recovered $recovered zombie tasks" >&2
        fi
    fi

    # Also check file system for orphaned running tasks
    local running_dir="${AUTONOMOUS_ROOT}/tasks/running"
    local queue_dir="${AUTONOMOUS_ROOT}/tasks/queue"

    if [[ -d "$running_dir" ]]; then
        local cutoff_seconds=$((timeout_minutes * 60))
        local now_epoch
        now_epoch=$(date +%s)

        for task_file in "$running_dir"/*.md; do
            [[ -f "$task_file" ]] || continue

            local file_mtime
            file_mtime=$(stat -c %Y "$task_file" 2>/dev/null || stat -f %m "$task_file" 2>/dev/null || echo "$now_epoch")
            local age=$((now_epoch - file_mtime))

            if [[ $age -gt $cutoff_seconds ]]; then
                local task_name
                task_name=$(basename "$task_file")

                # Check if there's an active lock
                local lock_dir="${running_dir}/${task_name}.lock.d"
                if [[ -d "$lock_dir" ]]; then
                    # Lock exists, check if it's stale
                    local lock_mtime
                    lock_mtime=$(stat -c %Y "$lock_dir" 2>/dev/null || stat -f %m "$lock_dir" 2>/dev/null || echo "$now_epoch")
                    local lock_age=$((now_epoch - lock_mtime))

                    if [[ $lock_age -gt $cutoff_seconds ]]; then
                        # Stale lock, recover the task
                        recover_stale_task "$task_name" "unknown-worker" "file system timeout ($age seconds)"
                        ((recovered++)) || true
                    fi
                else
                    # No lock, definitely orphaned
                    recover_stale_task "$task_name" "unknown-worker" "orphaned file ($age seconds)"
                    ((recovered++)) || true
                fi
            fi
        done
    fi

    echo "$recovered"
}

#===============================================================================
# M1-005: Scheduled Stale Task Recovery
#===============================================================================
# Enhanced recovery daemon that runs periodically to detect and recover
# stale tasks. Integrates with worker heartbeats and process monitoring.
#===============================================================================

# M1-005: Recovery daemon state
RECOVERY_DAEMON_RUNNING=false
RECOVERY_DAEMON_PID=""
RECOVERY_INTERVAL="${RECOVERY_INTERVAL:-60}"  # Check every 60 seconds
RECOVERY_TIMEOUT="${RECOVERY_TIMEOUT:-900}"   # Default 15 min timeout

# M1-005: Start stale task recovery daemon
start_recovery_daemon() {
    if [[ "$RECOVERY_DAEMON_RUNNING" == "true" ]]; then
        if declare -F log_warn >/dev/null 2>&1; then
            log_warn "[M1-005] Recovery daemon already running"
        fi
        return 1
    fi

    RECOVERY_DAEMON_RUNNING=true

    (
        trap 'RECOVERY_DAEMON_RUNNING=false; exit 0' SIGTERM SIGINT

        if declare -F log_info >/dev/null 2>&1; then
            log_info "[M1-005] Stale task recovery daemon started (interval: ${RECOVERY_INTERVAL}s)"
        else
            echo "[INFO] [M1-005] Stale task recovery daemon started (interval: ${RECOVERY_INTERVAL}s)" >&2
        fi

        while [[ "$RECOVERY_DAEMON_RUNNING" == "true" ]]; do
            # Run recovery
            local recovered
            recovered=$(recover_stale_tasks "" 2>/dev/null || echo "0")

            if [[ "$recovered" -gt 0 ]]; then
                if declare -F log_info >/dev/null 2>&1; then
                    log_info "[M1-005] Recovered $recovered stale tasks"
                else
                    echo "[INFO] [M1-005] Recovered $recovered stale tasks" >&2
                fi
            fi

            # Also check for zombie tasks (workers that died without releasing tasks)
            local zombies
            zombies=$(recover_zombie_tasks 30 2>/dev/null || echo "0")

            if [[ "$zombies" -gt 0 ]]; then
                if declare -F log_info >/dev/null 2>&1; then
                    log_info "[M1-005] Recovered $zombies zombie tasks"
                else
                    echo "[INFO] [M1-005] Recovered $zombies zombie tasks" >&2
                fi
            fi

            sleep "$RECOVERY_INTERVAL"
        done
    ) &

    RECOVERY_DAEMON_PID=$!

    if declare -F log_debug >/dev/null 2>&1; then
        log_debug "[M1-005] Recovery daemon PID: $RECOVERY_DAEMON_PID"
    fi
}

# M1-005: Stop stale task recovery daemon
stop_recovery_daemon() {
    if [[ -n "$RECOVERY_DAEMON_PID" ]] && kill -0 "$RECOVERY_DAEMON_PID" 2>/dev/null; then
        kill "$RECOVERY_DAEMON_PID" 2>/dev/null || true
        wait "$RECOVERY_DAEMON_PID" 2>/dev/null || true
        RECOVERY_DAEMON_PID=""
    fi
    RECOVERY_DAEMON_RUNNING=false

    if declare -F log_info >/dev/null 2>&1; then
        log_info "[M1-005] Stale task recovery daemon stopped"
    else
        echo "[INFO] [M1-005] Stale task recovery daemon stopped" >&2
    fi
}

# M1-005: Check if a specific worker is alive
is_worker_alive() {
    local worker_id="$1"

    if [[ -z "$worker_id" ]]; then
        return 1
    fi

    _heartbeat_require_sqlite

    # Get worker info from SQLite
    local info
    info=$(sqlite3 "$STATE_DB" -separator '|' <<SQL
SELECT pid, status, last_heartbeat,
    CAST((julianday('now') - julianday(last_heartbeat)) * 86400 AS INTEGER) AS heartbeat_age
FROM workers
WHERE worker_id='${worker_id//\'/\'\'}'
LIMIT 1;
SQL
)

    if [[ -z "$info" ]]; then
        return 1  # Worker not found
    fi

    local pid status last_heartbeat heartbeat_age
    IFS='|' read -r pid status last_heartbeat heartbeat_age <<< "$info"

    # Check status
    if [[ "$status" == "dead" || "$status" == "stopping" ]]; then
        return 1
    fi

    # Check if process is running
    if [[ -n "$pid" && "$pid" =~ ^[0-9]+$ ]]; then
        if kill -0 "$pid" 2>/dev/null; then
            return 0  # Process is running
        else
            # Process died, update status
            sqlite3 "$STATE_DB" "UPDATE workers SET status='dead' WHERE worker_id='${worker_id//\'/\'\'}';"
            return 1
        fi
    fi

    # Check heartbeat age (default 5 min timeout)
    local timeout="${RECOVERY_TIMEOUT:-300}"
    if [[ -n "$heartbeat_age" ]] && (( heartbeat_age > timeout )); then
        return 1  # Heartbeat too old
    fi

    return 0  # Assume alive if we can't determine otherwise
}

# M1-005: Force recover a specific task
force_recover_task() {
    local task_id="$1"
    local reason="${2:-manual recovery}"

    if [[ -z "$task_id" ]]; then
        echo "Error: task_id required" >&2
        return 1
    fi

    _heartbeat_require_sqlite
    sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true

    # Get current task state
    local task_info
    task_info=$(sqlite3 "$STATE_DB" -separator '|' <<SQL
SELECT state, worker_id FROM tasks WHERE id='${task_id//\'/\'\'}' LIMIT 1;
SQL
)

    if [[ -z "$task_info" ]]; then
        echo "Error: Task not found: $task_id" >&2
        return 1
    fi

    local current_state worker_id
    IFS='|' read -r current_state worker_id <<< "$task_info"

    if [[ "$current_state" != "RUNNING" ]]; then
        echo "Warning: Task $task_id is not in RUNNING state (current: $current_state)" >&2
    fi

    # Force recovery
    recover_stale_task "$task_id" "${worker_id:-unknown}" "$reason"

    if declare -F log_info >/dev/null 2>&1; then
        log_info "[M1-005] Force recovered task: $task_id (reason: $reason)"
    else
        echo "[INFO] [M1-005] Force recovered task: $task_id (reason: $reason)" >&2
    fi

    return 0
}

# M1-005: Get recovery status/statistics
get_recovery_stats() {
    _heartbeat_require_sqlite

    local stats
    stats=$(sqlite3 "$STATE_DB" <<SQL
SELECT
    (SELECT COUNT(*) FROM tasks WHERE state='RUNNING') as running_tasks,
    (SELECT COUNT(*) FROM tasks WHERE state='QUEUED') as queued_tasks,
    (SELECT COUNT(*) FROM workers WHERE status IN ('idle', 'busy')) as active_workers,
    (SELECT COUNT(*) FROM workers WHERE status='dead') as dead_workers,
    (SELECT COUNT(*) FROM events WHERE event_type='TASK_RECOVERED' AND timestamp > datetime('now', '-1 hour')) as recovered_last_hour,
    (SELECT COUNT(*) FROM events WHERE event_type='ZOMBIE_RECOVERY' AND timestamp > datetime('now', '-1 hour')) as zombies_last_hour;
SQL
)

    echo "M1-005 Recovery Statistics:"
    echo "  Running tasks:        $(echo "$stats" | cut -d'|' -f1)"
    echo "  Queued tasks:         $(echo "$stats" | cut -d'|' -f2)"
    echo "  Active workers:       $(echo "$stats" | cut -d'|' -f3)"
    echo "  Dead workers:         $(echo "$stats" | cut -d'|' -f4)"
    echo "  Recovered (1hr):      $(echo "$stats" | cut -d'|' -f5)"
    echo "  Zombie recoveries:    $(echo "$stats" | cut -d'|' -f6)"
    echo "  Recovery daemon:      ${RECOVERY_DAEMON_RUNNING:-false}"
    echo "  Recovery interval:    ${RECOVERY_INTERVAL}s"
}

# M1-005: Run immediate recovery check (for cron or manual use)
run_recovery_check() {
    local timeout="${1:-}"

    if declare -F log_info >/dev/null 2>&1; then
        log_info "[M1-005] Running immediate recovery check"
    else
        echo "[INFO] [M1-005] Running immediate recovery check" >&2
    fi

    # Check stale tasks
    local stale_recovered
    stale_recovered=$(recover_stale_tasks "$timeout" 2>/dev/null || echo "0")

    # Check zombie tasks
    local zombie_recovered
    zombie_recovered=$(recover_zombie_tasks 30 2>/dev/null || echo "0")

    # Check workers with stale heartbeats
    check_stale_workers_sqlite 5 1.5 2>/dev/null || true

    local total=$((stale_recovered + zombie_recovered))

    if declare -F log_info >/dev/null 2>&1; then
        log_info "[M1-005] Recovery check complete: $stale_recovered stale, $zombie_recovered zombies recovered"
    else
        echo "[INFO] [M1-005] Recovery check complete: $stale_recovered stale, $zombie_recovered zombies recovered" >&2
    fi

    echo "$total"
}

export -f recover_stale_tasks recover_stale_task recover_zombie_tasks
export -f start_recovery_daemon stop_recovery_daemon is_worker_alive
export -f force_recover_task get_recovery_stats run_recovery_check
