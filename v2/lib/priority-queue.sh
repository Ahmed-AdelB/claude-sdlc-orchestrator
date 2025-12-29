#!/bin/bash
# =============================================================================
# priority-queue.sh - Multi-lane priority queue with preemption and escalation
# =============================================================================
# Provides:
# - CRITICAL, HIGH, MEDIUM, LOW lanes (FIFO within each lane)
# - Preemption with checkpointing when higher priority arrives
# - Priority escalation based on wait time
#
# This file is safe to source from common.sh or other scripts.
# It defines functions only and performs no actions on import.
# =============================================================================

: "${AUTONOMOUS_ROOT:=${HOME}/.claude/autonomous}"
: "${TASK_QUEUE_DIR:=${AUTONOMOUS_ROOT}/tasks/queue}"
: "${TASK_RUNNING_DIR:=${AUTONOMOUS_ROOT}/tasks/running}"
: "${CHECKPOINTS_DIR:=${AUTONOMOUS_ROOT}/sessions/checkpoints}"
: "${STATE_DIR:=${AUTONOMOUS_ROOT}/state}"

PQ_QUEUE_DIR="${PQ_QUEUE_DIR:-$TASK_QUEUE_DIR}"
PQ_RUNNING_DIR="${PQ_RUNNING_DIR:-$TASK_RUNNING_DIR}"
PQ_STATE_DIR="${PQ_STATE_DIR:-${STATE_DIR}/priority-queue}"
PQ_CHECKPOINT_DIR="${PQ_CHECKPOINT_DIR:-$CHECKPOINTS_DIR}"

PQ_ESCALATE_LOW_AFTER_SECONDS="${PQ_ESCALATE_LOW_AFTER_SECONDS:-3600}"
PQ_ESCALATE_MEDIUM_AFTER_SECONDS="${PQ_ESCALATE_MEDIUM_AFTER_SECONDS:-1800}"
PQ_ESCALATE_HIGH_AFTER_SECONDS="${PQ_ESCALATE_HIGH_AFTER_SECONDS:-900}"

PQ_PRIORITIES=("CRITICAL" "HIGH" "MEDIUM" "LOW")

_pq_log() {
    local level="$1"
    shift
    if type -t log_info >/dev/null 2>&1; then
        case "$level" in
            INFO) log_info "$*" ;;
            WARN) log_warn "$*" ;;
            ERROR) log_error "$*" ;;
            *) log_info "$*" ;;
        esac
    else
        echo "[$level] $*" >&2
    fi
}

_pq_ensure_dir() {
    local dir="$1"
    if type -t ensure_dir >/dev/null 2>&1; then
        ensure_dir "$dir"
    else
        mkdir -p "$dir"
    fi
}

pq_init() {
    _pq_ensure_dir "$PQ_QUEUE_DIR"
    _pq_ensure_dir "$PQ_RUNNING_DIR"
    _pq_ensure_dir "$PQ_STATE_DIR"
    _pq_ensure_dir "$PQ_CHECKPOINT_DIR"
}

pq_normalize_priority() {
    local p="$1"
    p=$(echo "${p}" | tr '[:lower:]' '[:upper:]')
    case "$p" in
        CRITICAL|HIGH|MEDIUM|LOW) echo "$p" ;;
        *) echo "MEDIUM" ;;
    esac
}

pq_priority_rank() {
    local p
    p=$(pq_normalize_priority "$1")
    case "$p" in
        CRITICAL) echo 0 ;;
        HIGH) echo 1 ;;
        MEDIUM) echo 2 ;;
        LOW) echo 3 ;;
        *) echo 99 ;;
    esac
}

pq_is_higher_priority() {
    local a b
    a=$(pq_priority_rank "$1")
    b=$(pq_priority_rank "$2")
    [[ "$a" -lt "$b" ]]
}

pq_task_priority_from_name() {
    local name
    name=$(basename "$1")
    local p
    p=$(echo "$name" | grep -oE '^(CRITICAL|HIGH|MEDIUM|LOW)' || echo "MEDIUM")
    echo "$p"
}

pq_random_id() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen | tr '[:upper:]' '[:lower:]' | cut -d'-' -f1
    else
        echo "${RANDOM}${RANDOM}"
    fi
}

pq_enqueue_text() {
    local priority
    priority=$(pq_normalize_priority "${1:-MEDIUM}")
    shift || true
    local text="$*"

    pq_init

    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    local id
    id=$(pq_random_id)
    local file="${PQ_QUEUE_DIR}/${priority}_${ts}_${id}.md"

    cat > "$file" <<TASKEOF
# Task
Created: $(date -Iseconds)
Priority: ${priority}

${text}
TASKEOF
    echo "$file"
}

pq_enqueue_file() {
    local priority
    priority=$(pq_normalize_priority "${1:-MEDIUM}")
    local src="$2"
    local mode="${3:-move}"  # move|copy

    if [[ -z "$src" || ! -f "$src" ]]; then
        _pq_log ERROR "Source file not found: $src"
        return 1
    fi

    pq_init

    local base
    base=$(basename "$src")
    local dest
    if [[ "$base" =~ ^(CRITICAL|HIGH|MEDIUM|LOW)_ ]]; then
        dest="${PQ_QUEUE_DIR}/${base}"
    else
        dest="${PQ_QUEUE_DIR}/${priority}_${base}"
    fi

    if [[ "$mode" == "copy" ]]; then
        cp "$src" "$dest"
    else
        mv "$src" "$dest"
    fi

    echo "$dest"
}

pq_list() {
    pq_init
    for priority in "${PQ_PRIORITIES[@]}"; do
        local count
        count=$(find "$PQ_QUEUE_DIR" -maxdepth 1 -type f -name "${priority}_*" 2>/dev/null | wc -l | tr -d ' ')
        echo "${priority}: ${count}"
    done
}

_pq_file_mtime_epoch() {
    local file="$1"
    if stat -c %Y "$file" >/dev/null 2>&1; then
        stat -c %Y "$file"
    else
        stat -f %m "$file"
    fi
}

_pq_find_oldest_by_priority() {
    local priority="$1"
    local oldest_file=""
    local oldest_time=""

    while IFS= read -r file; do
        [[ -f "$file" ]] || continue
        local mtime
        mtime=$(_pq_file_mtime_epoch "$file")
        if [[ -z "$oldest_time" || "$mtime" -lt "$oldest_time" ]]; then
            oldest_time="$mtime"
            oldest_file="$file"
        fi
    done < <(find "$PQ_QUEUE_DIR" -maxdepth 1 -type f -name "${priority}_*" 2>/dev/null)

    if [[ -n "$oldest_file" ]]; then
        echo "$oldest_file"
        return 0
    fi

    return 1
}

pq_next_task() {
    pq_init
    for priority in "${PQ_PRIORITIES[@]}"; do
        local task
        task=$(_pq_find_oldest_by_priority "$priority" || true)
        if [[ -n "$task" ]]; then
            echo "$task"
            return 0
        fi
    done
    return 1
}

pq_set_current() {
    local task_path="$1"
    local priority
    priority=$(pq_normalize_priority "${2:-$(pq_task_priority_from_name "$task_path")}")

    pq_init

    local now
    now=$(date -Iseconds)
    cat > "${PQ_STATE_DIR}/current.json" <<STATEEOF
{
  "task_path": "${task_path}",
  "priority": "${priority}",
  "started_at": "${now}",
  "pid": $$,
  "trace_id": "${TRACE_ID:-}"
}
STATEEOF
}

pq_get_current_path() {
    local state_file="${PQ_STATE_DIR}/current.json"
    [[ -f "$state_file" ]] || return 1
    if command -v jq >/dev/null 2>&1; then
        jq -r '.task_path // empty' "$state_file" 2>/dev/null
    else
        grep -oE '"task_path"\s*:\s*"[^"]+"' "$state_file" | head -1 | sed -E 's/.*"task_path"\s*:\s*"([^"]+)".*/\1/'
    fi
}

pq_get_current_priority() {
    local state_file="${PQ_STATE_DIR}/current.json"
    [[ -f "$state_file" ]] || return 1
    if command -v jq >/dev/null 2>&1; then
        jq -r '.priority // "MEDIUM"' "$state_file" 2>/dev/null
    else
        grep -oE '"priority"\s*:\s*"[^"]+"' "$state_file" | head -1 | sed -E 's/.*"priority"\s*:\s*"([^"]+)".*/\1/'
    fi
}

pq_clear_current() {
    rm -f "${PQ_STATE_DIR}/current.json" 2>/dev/null || true
}

pq_checkpoint_task() {
    local task_path="$1"
    local reason="${2:-preemption}"
    pq_init

    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    local base
    base=$(basename "$task_path")
    local checkpoint_file="${PQ_CHECKPOINT_DIR}/pq_${ts}_${base}.json"

    local content_preview=""
    if [[ -f "$task_path" ]]; then
        content_preview=$(head -c 2000 "$task_path" | tr '\n' ' ')
    fi

    cat > "$checkpoint_file" <<CHECKEOF
{
  "timestamp": "$(date -Iseconds)",
  "reason": "${reason}",
  "task_path": "${task_path}",
  "task_name": "${base}",
  "preview": "${content_preview}"
}
CHECKEOF

    local checkpoint_script="${AUTONOMOUS_ROOT}/checkpoint.sh"
    if [[ -x "$checkpoint_script" ]]; then
        "$checkpoint_script" >/dev/null 2>&1 || true
    fi

    _pq_log INFO "Checkpoint saved: $checkpoint_file"
}

pq_requeue_task() {
    local task_path="$1"
    local priority
    priority=$(pq_normalize_priority "${2:-$(pq_task_priority_from_name "$task_path")}")

    pq_init

    if [[ ! -f "$task_path" ]]; then
        _pq_log WARN "Task not found for requeue: $task_path"
        return 1
    fi

    local base
    base=$(basename "$task_path")
    local dest
    if [[ "$base" =~ ^(CRITICAL|HIGH|MEDIUM|LOW)_ ]]; then
        dest="${PQ_QUEUE_DIR}/${base}"
    else
        dest="${PQ_QUEUE_DIR}/${priority}_${base}"
    fi

    mv "$task_path" "$dest"
    echo "$dest"
}

pq_preempt_if_needed() {
    local incoming_priority
    incoming_priority=$(pq_normalize_priority "${1:-MEDIUM}")
    local reason="${2:-preemption}"

    local current_path
    current_path=$(pq_get_current_path || true)
    if [[ -z "$current_path" ]]; then
        return 1
    fi

    local current_priority
    current_priority=$(pq_get_current_priority || echo "MEDIUM")

    if pq_is_higher_priority "$incoming_priority" "$current_priority"; then
        _pq_log WARN "Preempting ${current_priority} for ${incoming_priority}"
        pq_checkpoint_task "$current_path" "$reason"
        pq_requeue_task "$current_path" "$current_priority" >/dev/null || true
        pq_clear_current
        return 0
    fi

    return 1
}

pq_promote_task() {
    local task_path="$1"
    local new_priority
    new_priority=$(pq_normalize_priority "$2")

    if [[ ! -f "$task_path" ]]; then
        return 1
    fi

    local base
    base=$(basename "$task_path")
    local stripped
    stripped=$(echo "$base" | sed -E 's/^(CRITICAL|HIGH|MEDIUM|LOW)_//')
    local dest="${PQ_QUEUE_DIR}/${new_priority}_${stripped}"

    mv "$task_path" "$dest"
    echo "$dest"
}

pq_escalate_waiting() {
    pq_init
    local now
    now=$(date +%s)

    local file
    while IFS= read -r file; do
        [[ -f "$file" ]] || continue
        local priority
        priority=$(pq_task_priority_from_name "$file")
        local mtime
        mtime=$(_pq_file_mtime_epoch "$file")
        local age=$((now - mtime))

        case "$priority" in
            LOW)
                if [[ "$age" -ge "$PQ_ESCALATE_LOW_AFTER_SECONDS" ]]; then
                    pq_promote_task "$file" "MEDIUM" >/dev/null
                    _pq_log INFO "Escalated LOW -> MEDIUM: $(basename "$file")"
                fi
                ;;
            MEDIUM)
                if [[ "$age" -ge "$PQ_ESCALATE_MEDIUM_AFTER_SECONDS" ]]; then
                    pq_promote_task "$file" "HIGH" >/dev/null
                    _pq_log INFO "Escalated MEDIUM -> HIGH: $(basename "$file")"
                fi
                ;;
            HIGH)
                if [[ "$age" -ge "$PQ_ESCALATE_HIGH_AFTER_SECONDS" ]]; then
                    pq_promote_task "$file" "CRITICAL" >/dev/null
                    _pq_log INFO "Escalated HIGH -> CRITICAL: $(basename "$file")"
                fi
                ;;
        esac
    done < <(find "$PQ_QUEUE_DIR" -maxdepth 1 -type f 2>/dev/null)
}

pq_counts_json() {
    pq_init
    local critical high medium low
    critical=$(find "$PQ_QUEUE_DIR" -maxdepth 1 -type f -name "CRITICAL_*" 2>/dev/null | wc -l | tr -d ' ')
    high=$(find "$PQ_QUEUE_DIR" -maxdepth 1 -type f -name "HIGH_*" 2>/dev/null | wc -l | tr -d ' ')
    medium=$(find "$PQ_QUEUE_DIR" -maxdepth 1 -type f -name "MEDIUM_*" 2>/dev/null | wc -l | tr -d ' ')
    low=$(find "$PQ_QUEUE_DIR" -maxdepth 1 -type f -name "LOW_*" 2>/dev/null | wc -l | tr -d ' ')

    cat <<JSONEOF
{"CRITICAL":${critical},"HIGH":${high},"MEDIUM":${medium},"LOW":${low}}
JSONEOF
}
