#!/bin/bash
# =============================================================================
# worker-pool.sh - 3-worker coordination with sharding and health monitoring
# =============================================================================
# Provides:
# - 3-worker pool orchestration (implementation/review/analysis)
# - Task routing (impl -> codex, review -> claude, analysis -> gemini)
# - Sharding based on task id
# - Health monitoring and graceful shutdown
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

AUTONOMOUS_ROOT="${AUTONOMOUS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
STATE_DIR="${STATE_DIR:-${AUTONOMOUS_ROOT}/state}"
STATE_DB="${STATE_DB:-${STATE_DIR}/tri-agent.db}"
BIN_DIR="${BIN_DIR:-${AUTONOMOUS_ROOT}/bin}"
LOG_DIR="${LOG_DIR:-${AUTONOMOUS_ROOT}/logs}"
TRACE_ID="${TRACE_ID:-pool-$(date +%Y%m%d%H%M%S)-$$}"

# Optional logging if common.sh exists
if [[ -f "${AUTONOMOUS_ROOT}/lib/common.sh" ]]; then
    # shellcheck source=/dev/null
    source "${AUTONOMOUS_ROOT}/lib/common.sh"
fi

if [[ -f "${AUTONOMOUS_ROOT}/lib/sqlite-state.sh" ]]; then
    # shellcheck source=/dev/null
    source "${AUTONOMOUS_ROOT}/lib/sqlite-state.sh"
fi

if [[ -f "${AUTONOMOUS_ROOT}/lib/heartbeat.sh" ]]; then
    # shellcheck source=/dev/null
    source "${AUTONOMOUS_ROOT}/lib/heartbeat.sh"
fi

POOL_SIZE="${POOL_SIZE:-3}"
POOL_CHECK_INTERVAL="${POOL_CHECK_INTERVAL:-30}"
POOL_SHUTDOWN_TIMEOUT="${POOL_SHUTDOWN_TIMEOUT:-20}"
TRI_AGENT_PROCESS_PATTERN="${TRI_AGENT_PROCESS_PATTERN:-tri-agent-worker|tri-agent-supervisor|tri-agent-queue-watcher|tri-agent-daemon|budget-watchdog|claude-delegate|codex-delegate|gemini-delegate}"

# =============================================================================
# M1-006: Worker Pool Sharding Configuration
# =============================================================================
# WORKER_SHARD: Environment variable to specify which shard this worker handles
# Valid values: 0, 1, 2 (maps to shard-0, shard-1, shard-2)
# If not set, worker can claim tasks from any shard
# =============================================================================
WORKER_SHARD="${WORKER_SHARD:-}"
SHARD_COUNT="${SHARD_COUNT:-3}"
SHARD_HEALTH_TIMEOUT="${SHARD_HEALTH_TIMEOUT:-120}"  # seconds before shard considered unhealthy
SHARD_REBALANCE_THRESHOLD="${SHARD_REBALANCE_THRESHOLD:-5}"  # task imbalance threshold
SHARD_HEARTBEAT_INTERVAL="${SHARD_HEARTBEAT_INTERVAL:-30}"  # seconds between shard heartbeats
WORKER_STALE_HEARTBEAT_MINUTES="${WORKER_STALE_HEARTBEAT_MINUTES:-5}"
WORKER_STALE_GRACE_MULTIPLIER="${WORKER_STALE_GRACE_MULTIPLIER:-1.5}"

_pool_require_sqlite() {
    if declare -F _sqlite_require >/dev/null 2>&1; then
        _sqlite_require
        return $?
    fi
    if ! command -v sqlite3 >/dev/null 2>&1; then
        echo "Error: sqlite3 not found in PATH" >&2
        return 1
    fi
}

# =============================================================================
# SQL Escape Function for Injection Prevention
# =============================================================================
# Escapes single quotes by doubling them (SQL standard)
# Usage: escaped=$(_sql_escape "$user_input")
_sql_escape() {
    local input="$1"
    # Handle empty input
    if [[ -z "$input" ]]; then
        echo ""
        return 0
    fi
    # Escape single quotes by doubling them
    # Also escape backslashes for safety
    local escaped="${input//\\/\\\\}"
    escaped="${escaped//\'/\'\'}"
    echo "$escaped"
}

# =============================================================================
# M3-018: Zombie Process Cleanup
# =============================================================================
_pool_log() {
    local level="$1"
    shift

    if declare -F log_rinfo >/dev/null 2>&1; then
        case "$level" in
            INFO) log_rinfo "$*" ;;
            WARN) log_rwarn "$*" ;;
            ERROR) log_rerror "$*" ;;
            DEBUG) log_rdebug "$*" ;;
            *) log_rinfo "$*" ;;
        esac
        return 0
    fi

    if declare -F log_info >/dev/null 2>&1; then
        case "$level" in
            INFO) log_info "$*" ;;
            WARN) log_warn "$*" ;;
            ERROR) log_error "$*" ;;
            DEBUG) log_debug "$*" ;;
            *) log_info "$*" ;;
        esac
        return 0
    fi

    local ts
    ts=$(date -Iseconds 2>/dev/null || date "+%Y-%m-%dT%H:%M:%S")
    echo "[$ts] [$level] $*" >&2
}

cleanup_zombie_processes() {
    local pattern="${1:-${TRI_AGENT_PROCESS_PATTERN:-tri-agent}}"
    local zombies
    zombies=$(ps -eo pid=,ppid=,pgid=,stat=,command= 2>/dev/null | awk -v pat="$pattern" '$4 ~ /Z/ && $0 ~ pat {pid=$1; ppid=$2; pgid=$3; stat=$4; $1=$2=$3=$4=""; sub(/^ +/, "", $0); print pid "|" ppid "|" pgid "|" stat "|" $0}' || true)

    if [[ -z "$zombies" ]]; then
        _pool_log "INFO" "Zombie cleanup: no tri-agent zombies found"
        return 0
    fi

    local self_pgid
    self_pgid=$(ps -o pgid= -p $$ 2>/dev/null | tr -d ' ' || true)

    local processed=0
    while IFS='|' read -r pid ppid pgid stat cmd; do
        [[ -z "$pid" ]] && continue
        processed=$((processed + 1))
        _pool_log "WARN" "Zombie detected: PID $pid PPID ${ppid:-unknown} PGID ${pgid:-unknown} CMD ${cmd:-unknown}"

        local parent_alive="false"
        if [[ -n "${ppid:-}" && "$ppid" != "1" ]] && kill -0 "$ppid" 2>/dev/null; then
            parent_alive="true"
            if [[ "$ppid" == "$$" ]]; then
                _pool_log "INFO" "Waiting on zombie $pid (parent is current process)"
                wait "$pid" 2>/dev/null || true
            else
                _pool_log "INFO" "Signaling parent $ppid to reap zombie $pid"
                kill -SIGCHLD "$ppid" 2>/dev/null || true
            fi

            local attempts=5
            while (( attempts > 0 )); do
                if ! ps -o stat= -p "$pid" 2>/dev/null | grep -q "Z"; then
                    _pool_log "INFO" "Zombie $pid reaped by parent $ppid"
                    break
                fi
                sleep 1
                attempts=$((attempts - 1))
            done

            if ps -o stat= -p "$pid" 2>/dev/null | grep -q "Z"; then
                _pool_log "WARN" "Zombie $pid still present after parent reap attempt"
            fi
        fi

        local orphaned="false"
        if [[ -z "${ppid:-}" || "$ppid" == "1" || "$parent_alive" != "true" ]]; then
            orphaned="true"
        fi

        if [[ "$orphaned" == "true" ]]; then
            if [[ -n "${pgid:-}" && "$pgid" =~ ^[0-9]+$ ]]; then
                if [[ "$pgid" == "0" || "$pgid" == "1" ]]; then
                    _pool_log "WARN" "Skipping process group $pgid for zombie $pid (unsafe pgid)"
                elif [[ -n "${self_pgid:-}" && "$pgid" == "$self_pgid" ]]; then
                    _pool_log "WARN" "Skipping process group $pgid for zombie $pid (current process group)"
                else
                    if [[ "${DRY_RUN:-false}" == "true" ]]; then
                        _pool_log "INFO" "[DRY-RUN] Would terminate orphaned process group $pgid for zombie $pid"
                    else
                        _pool_log "WARN" "Terminating orphaned process group $pgid for zombie $pid"
                        kill -TERM -"$pgid" 2>/dev/null || true
                        sleep 2
                        if kill -0 -"$pgid" 2>/dev/null; then
                            _pool_log "WARN" "Force killing orphaned process group $pgid"
                            kill -KILL -"$pgid" 2>/dev/null || true
                        fi
                    fi
                fi
            else
                _pool_log "WARN" "Orphaned zombie $pid has invalid process group: ${pgid:-unknown}"
            fi
        fi
    done <<< "$zombies"

    _pool_log "INFO" "Zombie cleanup complete (processed $processed)"
}

# =============================================================================
# M1-006: WORKER_SHARD Environment Variable Support
# =============================================================================
# Validates and normalizes the WORKER_SHARD environment variable
# Returns 0 if valid, 1 if invalid
# =============================================================================

validate_worker_shard() {
    local shard="${1:-$WORKER_SHARD}"

    # Empty shard is valid (worker handles all shards)
    if [[ -z "$shard" ]]; then
        return 0
    fi

    # Normalize: strip "shard-" prefix if present
    shard="${shard#shard-}"

    # Validate numeric range
    if ! [[ "$shard" =~ ^[0-9]+$ ]]; then
        echo "Error: WORKER_SHARD must be a number (0, 1, 2), got: $shard" >&2
        return 1
    fi

    if (( shard < 0 || shard >= SHARD_COUNT )); then
        echo "Error: WORKER_SHARD must be between 0 and $((SHARD_COUNT - 1)), got: $shard" >&2
        return 1
    fi

    return 0
}

# Normalize shard identifier to standard format (shard-N)
normalize_shard_id() {
    local shard="${1:-}"

    if [[ -z "$shard" ]]; then
        echo ""
        return 0
    fi

    # Strip prefix if present
    shard="${shard#shard-}"

    # Return normalized format
    echo "shard-${shard}"
}

# Get shard number from shard ID (shard-0 -> 0)
get_shard_number() {
    local shard_id="${1:-}"

    if [[ -z "$shard_id" ]]; then
        echo ""
        return 0
    fi

    # Strip prefix and return number
    echo "${shard_id#shard-}"
}

# Get current worker's shard ID from environment
get_worker_shard() {
    if [[ -z "$WORKER_SHARD" ]]; then
        echo ""
        return 0
    fi

    normalize_shard_id "$WORKER_SHARD"
}

validate_worker_credentials() {
    local model="$1"
    
    case "$model" in
        "claude")
            if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
                echo "Error: ANTHROPIC_API_KEY is not set for model claude" >&2
                return 1
            fi
            ;;
        "codex")
            if [[ -z "${OPENAI_API_KEY:-}" ]]; then
                echo "Error: OPENAI_API_KEY is not set for model codex" >&2
                return 1
            fi
            ;;
        "gemini")
            local creds_file="${HOME}/.gemini/oauth_creds.json"
            if [[ ! -f "$creds_file" ]]; then
                echo "Error: Gemini credentials not found at $creds_file" >&2
                return 1
            fi
            ;;
    esac
    return 0
}

# =============================================================================
# Hash to Integer Conversion (Fixed)
# =============================================================================
# Converts any string to a deterministic integer for consistent sharding
# Uses multiple fallback methods for portability
_hash_to_int() {
    local input="$1"

    # Validate input
    if [[ -z "$input" ]]; then
        echo "0"
        return 0
    fi

    # Method 1: Use cksum (most portable, available on all POSIX systems)
    if command -v cksum >/dev/null 2>&1; then
        printf '%s' "$input" | cksum | awk '{print $1}'
        return 0
    fi

    # Method 2: Use md5sum with proper hex-to-decimal conversion
    if command -v md5sum >/dev/null 2>&1; then
        local hex
        hex=$(printf '%s' "$input" | md5sum | awk '{print $1}' | cut -c1-8)
        # FIXED: Use shell arithmetic for hex conversion instead of xargs printf
        echo $((16#$hex))
        return 0
    fi

    # Method 3: Use md5 (macOS)
    if command -v md5 >/dev/null 2>&1; then
        local hex
        hex=$(printf '%s' "$input" | md5 | cut -c1-8)
        echo $((16#$hex))
        return 0
    fi

    # Method 4: Use sha256sum
    if command -v sha256sum >/dev/null 2>&1; then
        local hex
        hex=$(printf '%s' "$input" | sha256sum | awk '{print $1}' | cut -c1-8)
        echo $((16#$hex))
        return 0
    fi

    # Fallback: Simple character-based hash
    local hash=0
    local i
    for ((i=0; i<${#input}; i++)); do
        local char="${input:i:1}"
        local ord
        ord=$(printf '%d' "'$char" 2>/dev/null || echo 0)
        hash=$(( (hash * 31 + ord) % 2147483647 ))
    done
    echo "$hash"
}

shard_for_task() {
    local task_id="$1"
    local hash
    hash=$(_hash_to_int "$task_id")
    echo "shard-$((hash % POOL_SIZE))"
}

route_model_for_task_type() {
    local task_type="${1:-}"
    local upper
    upper=$(printf '%s' "$task_type" | tr '[:lower:]' '[:upper:]')

    case "$upper" in
        REVIEW*|AUDIT*|SECURITY*|GATE*|QUALITY*)
            echo "claude" ;;
        ANALYSIS*|RESEARCH*|ARCH*|DESIGN*)
            echo "gemini" ;;
        IMPLEMENT*|FEATURE*|FIX*|BUILD*|CODE*|BUG*)
            echo "codex" ;;
        *)
            echo "codex" ;;
    esac
}

route_lane_for_task_type() {
    local task_type="${1:-}"
    local upper
    upper=$(printf '%s' "$task_type" | tr '[:lower:]' '[:upper:]')
    case "$upper" in
        REVIEW*|AUDIT*|SECURITY*|GATE*|QUALITY*)
            echo "review" ;;
        ANALYSIS*|RESEARCH*|ARCH*|DESIGN*)
            echo "analysis" ;;
        *)
            echo "impl" ;;
    esac
}

# =============================================================================
# M1-006: Shard-Aware Task Claiming
# =============================================================================
# Claims tasks only from the worker's assigned shard
# Supports fallback to any shard if worker has no shard assignment
# =============================================================================

# Claim a task for a specific shard (M1-006)
# Usage: claim_task_for_shard WORKER_ID SHARD [TASK_TYPES_CSV] [MODEL]
# Returns: Task ID if claimed, empty otherwise
claim_task_for_shard() {
    local worker_id="$1"
    local shard="${2:-}"
    local task_types_csv="${3:-}"
    local model="${4:-}"

    _pool_require_sqlite

    # Normalize shard ID
    local normalized_shard=""
    if [[ -n "$shard" ]]; then
        normalized_shard=$(normalize_shard_id "$shard")
    fi

    local esc_worker esc_shard esc_model
    esc_worker=$(_sql_escape "$worker_id")
    esc_shard=$(_sql_escape "$normalized_shard")
    esc_model=$(_sql_escape "$model")

    # Build type filter
    local type_filter=""
    if [[ -n "$task_types_csv" ]]; then
        local raw_types=()
        local quoted_types=()
        local t
        IFS=',' read -r -a raw_types <<< "$task_types_csv"
        for t in "${raw_types[@]}"; do
            t=$(_sql_escape "${t}")
            quoted_types+=("'${t}'")
        done
        type_filter=" AND type IN (${quoted_types[*]})"
    fi

    # Build shard filter - strict match for assigned shard
    local shard_filter=""
    if [[ -n "$normalized_shard" ]]; then
        shard_filter=" AND shard='${esc_shard}'"
    fi

    # Build model filter
    local model_filter=""
    if [[ -n "$model" ]]; then
        model_filter=" AND (assigned_model IS NULL OR assigned_model='${esc_model}')"
    fi

    # Execute atomic claim
    if command -v sqlite3 >/dev/null 2>&1; then
        local result
        result=$(sqlite3 "$STATE_DB" <<SQL
BEGIN IMMEDIATE;
-- M1-006: Shard-aware atomic task claim
-- Priority: 0=CRITICAL, 1=HIGH, 2=MEDIUM, 3=LOW
UPDATE tasks
SET state='RUNNING',
    worker_id='${esc_worker}',
    started_at=datetime('now'),
    updated_at=datetime('now'),
    heartbeat_at=datetime('now'),
    last_activity_at=datetime('now')
WHERE id = (
    SELECT id FROM tasks
    WHERE state='QUEUED'${type_filter}${shard_filter}${model_filter}
    ORDER BY priority ASC, created_at ASC
    LIMIT 1
) AND state='QUEUED';
-- Return task ID only if claim succeeded
SELECT CASE WHEN changes() > 0
    THEN (SELECT id FROM tasks
          WHERE worker_id='${esc_worker}'
            AND state='RUNNING'
          ORDER BY started_at DESC
          LIMIT 1)
    ELSE NULL
END;
COMMIT;
SQL
)
        if [[ -n "$result" && "$result" != "NULL" && "$result" != "" ]]; then
            echo "$result"
        fi
    else
        # Python fallback
        python3 -c "
import sqlite3, sys
db_path = '$STATE_DB'
worker_id = '$worker_id'
type_filter = '''$type_filter'''
shard_filter = '''$shard_filter'''
model_filter = '''$model_filter'''

try:
    conn = sqlite3.connect(db_path, timeout=10.0)
    conn.isolation_level = None
    cur = conn.cursor()
    cur.execute('BEGIN IMMEDIATE')

    sql = f'''
    SELECT id FROM tasks
    WHERE state='QUEUED'{type_filter}{shard_filter}{model_filter}
    ORDER BY priority ASC, created_at ASC
    LIMIT 1
    '''
    cur.execute(sql)
    row = cur.fetchone()

    if row:
        task_id = row[0]
        cur.execute('''
        UPDATE tasks
        SET state='RUNNING',
            worker_id=?,
            started_at=datetime('now'),
            updated_at=datetime('now'),
            heartbeat_at=datetime('now'),
            last_activity_at=datetime('now')
        WHERE id = ? AND state='QUEUED'
        ''', (worker_id, task_id))

        if cur.rowcount > 0:
            cur.execute('COMMIT')
            print(task_id)
        else:
            cur.execute('ROLLBACK')
    else:
        cur.execute('ROLLBACK')
except Exception as e:
    try:
        cur.execute('ROLLBACK')
    except:
        pass
    sys.exit(1)
finally:
    conn.close()
"
    fi
}

# Claim task using WORKER_SHARD environment variable (M1-006)
# Usage: claim_task_from_env WORKER_ID [TASK_TYPES_CSV] [MODEL]
claim_task_from_env() {
    local worker_id="$1"
    local task_types_csv="${2:-}"
    local model="${3:-}"

    # Validate shard configuration
    if ! validate_worker_shard; then
        return 1
    fi

    # Get shard from environment
    local shard
    shard=$(get_worker_shard)

    # Claim task for this shard
    claim_task_for_shard "$worker_id" "$shard" "$task_types_csv" "$model"
}

# =============================================================================
# M1-006: Even Task Distribution Across Shards
# =============================================================================
# Assigns tasks to shards using consistent hashing for even distribution
# Supports weighted distribution based on shard capacity
# =============================================================================

# Assign shard to a task for even distribution (M1-006)
# Uses consistent hashing based on task ID
assign_shard_to_task() {
    local task_id="$1"
    local total_shards="${2:-$SHARD_COUNT}"

    local hash
    hash=$(_hash_to_int "$task_id")
    local shard_num=$((hash % total_shards))
    echo "shard-${shard_num}"
}

# Get shard task distribution statistics (M1-006)
get_shard_distribution() {
    _pool_require_sqlite
    sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true

    sqlite3 "$STATE_DB" -header -column <<SQL
SELECT
    COALESCE(shard, 'unassigned') as shard,
    state,
    COUNT(*) as task_count
FROM tasks
WHERE state IN ('QUEUED', 'RUNNING')
GROUP BY shard, state
ORDER BY shard, state;
SQL
}

# Get pending tasks per shard (M1-006)
get_pending_per_shard() {
    _pool_require_sqlite
    sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true

    sqlite3 "$STATE_DB" -separator '|' <<SQL
SELECT
    COALESCE(shard, 'shard-0') as shard,
    COUNT(*) as pending
FROM tasks
WHERE state = 'QUEUED'
GROUP BY shard
ORDER BY shard;
SQL
}

# Check if task distribution is balanced (M1-006)
# Returns 0 if balanced, 1 if rebalancing needed
check_shard_balance() {
    local threshold="${1:-$SHARD_REBALANCE_THRESHOLD}"

    _pool_require_sqlite
    sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true

    local counts
    counts=$(sqlite3 "$STATE_DB" <<SQL
SELECT
    MIN(cnt) as min_count,
    MAX(cnt) as max_count
FROM (
    SELECT COALESCE(shard, 'shard-0') as shard, COUNT(*) as cnt
    FROM tasks
    WHERE state = 'QUEUED'
    GROUP BY shard
);
SQL
)

    if [[ -z "$counts" ]]; then
        # No tasks, balanced by default
        return 0
    fi

    local min_count max_count
    min_count=$(echo "$counts" | cut -d'|' -f1)
    max_count=$(echo "$counts" | cut -d'|' -f2)

    # Handle empty values
    min_count="${min_count:-0}"
    max_count="${max_count:-0}"

    local diff=$((max_count - min_count))
    if (( diff > threshold )); then
        return 1
    fi
    return 0
}

# Rebalance tasks across shards (M1-006)
# Moves tasks from overloaded shards to underloaded ones
rebalance_shards() {
    local dry_run="${1:-false}"

    _pool_require_sqlite
    sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true

    # Get current distribution
    local distribution
    distribution=$(sqlite3 "$STATE_DB" -separator '|' <<SQL
SELECT
    COALESCE(shard, 'shard-0') as shard,
    COUNT(*) as cnt
FROM tasks
WHERE state = 'QUEUED'
GROUP BY shard
ORDER BY cnt DESC;
SQL
)

    if [[ -z "$distribution" ]]; then
        log_info "[SHARD] No queued tasks to rebalance"
        return 0
    fi

    # Calculate target per shard
    local total_queued
    total_queued=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM tasks WHERE state='QUEUED';")
    local target_per_shard=$((total_queued / SHARD_COUNT))

    log_info "[SHARD] Rebalancing: $total_queued queued tasks, target $target_per_shard per shard"

    # Find overloaded shards and reassign tasks
    local reassigned=0
    while IFS='|' read -r shard count; do
        [[ -z "$shard" ]] && continue

        local excess=$((count - target_per_shard - 1))
        if (( excess > 0 )); then
            # Find underloaded shard
            local target_shard
            target_shard=$(sqlite3 "$STATE_DB" <<SQL
SELECT shard FROM (
    SELECT COALESCE(shard, 'shard-0') as shard, COUNT(*) as cnt
    FROM tasks
    WHERE state = 'QUEUED'
    GROUP BY shard
    ORDER BY cnt ASC
    LIMIT 1
);
SQL
)
            if [[ -n "$target_shard" && "$target_shard" != "$shard" ]]; then
                if [[ "$dry_run" == "true" ]]; then
                    log_info "[SHARD] Would move $excess tasks from $shard to $target_shard"
                else
                    # Move excess tasks to target shard
                    local esc_shard esc_target
                    esc_shard=$(_sql_escape "$shard")
                    esc_target=$(_sql_escape "$target_shard")

                    sqlite3 "$STATE_DB" <<SQL
UPDATE tasks
SET shard='${esc_target}', updated_at=datetime('now')
WHERE id IN (
    SELECT id FROM tasks
    WHERE state='QUEUED' AND shard='${esc_shard}'
    ORDER BY priority DESC, created_at DESC
    LIMIT ${excess}
);
SQL
                    reassigned=$((reassigned + excess))
                    log_info "[SHARD] Moved $excess tasks from $shard to $target_shard"
                fi
            fi
        fi
    done <<< "$distribution"

    if [[ "$dry_run" != "true" ]]; then
        log_info "[SHARD] Rebalancing complete: $reassigned tasks reassigned"
    fi

    return 0
}

pool_init() {
    _pool_require_sqlite
    sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true
    mkdir -p "$LOG_DIR"
}

pool_register_worker() {
    local worker_id="$1"
    local pid="${2:-}"
    local specialization="${3:-}"
    local shard="${4:-}"
    local model="${5:-}"

    local esc_worker esc_spec esc_shard esc_model
    esc_worker=$(_sql_escape "$worker_id")
    esc_spec=$(_sql_escape "$specialization")
    esc_shard=$(_sql_escape "$shard")
    esc_model=$(_sql_escape "$model")

    _sqlite_exec "$STATE_DB" <<SQL
INSERT OR REPLACE INTO workers (worker_id, pid, status, specialization, shard, model, started_at, last_heartbeat)
VALUES ('${esc_worker}', ${pid:-NULL}, 'starting', '${esc_spec}', '${esc_shard}', '${esc_model}', datetime('now'), datetime('now'));
SQL
}

pool_assign_routing() {
    _pool_require_sqlite
    sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true

    local rows
    rows=$(_sqlite_exec "$STATE_DB" -separator '|' "SELECT id, type FROM tasks WHERE state='QUEUED' AND (assigned_model IS NULL OR assigned_model='') AND (shard IS NULL OR shard='');")

    local row
    while IFS='|' read -r task_id task_type; do
        [[ -z "$task_id" ]] && continue
        local model lane shard
        model=$(route_model_for_task_type "$task_type")
        lane=$(route_lane_for_task_type "$task_type")
        shard=$(shard_for_task "$task_id")
        local esc_task esc_model esc_lane esc_shard
        esc_task=$(_sql_escape "$task_id")
        esc_model=$(_sql_escape "$model")
        esc_lane=$(_sql_escape "$lane")
        esc_shard=$(_sql_escape "$shard")
        _sqlite_exec "$STATE_DB" "UPDATE tasks SET assigned_model='${esc_model}', lane='${esc_lane}', shard='${esc_shard}', updated_at=datetime('now') WHERE id='${esc_task}';"
    done <<< "$rows"
}

start_worker() {
    local specialization="$1"
    local model="$2"
    local shard="$3"

    if ! validate_worker_credentials "$model"; then
        return 1
    fi

    local worker_id="worker-${specialization}-$(date +%s)-$$"
    local worker_cmd="${BIN_DIR}/tri-agent-worker"

    if [[ ! -x "$worker_cmd" ]]; then
        echo "Error: tri-agent-worker not found at $worker_cmd" >&2
        return 1
    fi

    WORKER_ID="$worker_id" \
    WORKER_SPECIALIZATION="$specialization" \
    WORKER_MODEL="$model" \
    WORKER_SHARD="$shard" \
    nohup "$worker_cmd" >> "${LOG_DIR}/worker-${worker_id}.log" 2>&1 &

    local pid=$!
    pool_register_worker "$worker_id" "$pid" "$specialization" "$shard" "$model"
    echo "$worker_id"
}

start_default_pool() {
    pool_init
    start_worker "impl" "codex" "shard-0" >/dev/null
    start_worker "review" "claude" "shard-1" >/dev/null
    start_worker "analysis" "gemini" "shard-2" >/dev/null
}

pool_health_check() {
    _pool_require_sqlite
    sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true

    local rows
    rows=$(_sqlite_exec "$STATE_DB" -separator '|' "SELECT worker_id, pid FROM workers WHERE status IN ('starting','idle','busy');")

    local row
    while IFS='|' read -r worker_id pid; do
        [[ -z "$worker_id" || -z "$pid" ]] && continue
        if ! kill -0 "$pid" 2>/dev/null; then
            _sqlite_exec "$STATE_DB" "UPDATE workers SET status='dead', last_heartbeat=datetime('now') WHERE worker_id='${worker_id}';"
        fi
    done <<< "$rows"

    # Recover stale tasks via heartbeat logic if available
    if declare -F check_stale_workers_sqlite >/dev/null 2>&1; then
        check_stale_workers_sqlite "$WORKER_STALE_HEARTBEAT_MINUTES" "$WORKER_STALE_GRACE_MULTIPLIER"
    elif declare -F heartbeat_check_stale >/dev/null 2>&1; then
        heartbeat_check_stale
    fi
}

# =============================================================================
# M1-006: Shard Health Monitoring
# =============================================================================
# Tracks health of each shard based on worker status and activity
# Detects unhealthy shards and triggers auto-rebalancing
# =============================================================================

# Update shard heartbeat (M1-006)
# Called by workers to signal shard activity
update_shard_heartbeat() {
    local shard="${1:-}"
    local worker_id="${2:-}"

    if [[ -z "$shard" ]]; then
        return 0
    fi

    _pool_require_sqlite
    sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true

    local normalized_shard
    normalized_shard=$(normalize_shard_id "$shard")
    local esc_shard=$(_sql_escape "$normalized_shard")
    local esc_worker=$(_sql_escape "$worker_id")

    sqlite3 "$STATE_DB" <<SQL
INSERT OR REPLACE INTO health_status (component, status, details, updated_at)
VALUES ('${esc_shard}', 'healthy', '{"worker_id": "${esc_worker}", "type": "shard"}', datetime('now'));
SQL
}

# Get shard health status (M1-006)
# Returns: healthy, degraded, or unhealthy
get_shard_health() {
    local shard="${1:-}"

    if [[ -z "$shard" ]]; then
        echo "unknown"
        return 1
    fi

    _pool_require_sqlite
    sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true

    local normalized_shard
    normalized_shard=$(normalize_shard_id "$shard")
    local esc_shard=$(_sql_escape "$normalized_shard")

    local health_data
    health_data=$(sqlite3 "$STATE_DB" -separator '|' <<SQL
SELECT
    status,
    CAST((julianday('now') - julianday(updated_at)) * 86400 AS INTEGER) as age_seconds
FROM health_status
WHERE component='${esc_shard}'
LIMIT 1;
SQL
)

    if [[ -z "$health_data" ]]; then
        echo "unknown"
        return 0
    fi

    local status age_seconds
    status=$(echo "$health_data" | cut -d'|' -f1)
    age_seconds=$(echo "$health_data" | cut -d'|' -f2)

    # Check if heartbeat is stale
    if (( age_seconds > SHARD_HEALTH_TIMEOUT )); then
        echo "unhealthy"
        return 0
    elif (( age_seconds > SHARD_HEALTH_TIMEOUT / 2 )); then
        echo "degraded"
        return 0
    fi

    echo "$status"
}

# Get all shard health statuses (M1-006)
get_all_shard_health() {
    _pool_require_sqlite
    sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true

    echo "Shard Health Status:"
    echo "===================="

    local i
    for (( i=0; i<SHARD_COUNT; i++ )); do
        local shard="shard-${i}"
        local health
        health=$(get_shard_health "$shard")

        # Get worker count for shard
        local worker_count
        worker_count=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM workers WHERE shard='${shard}' AND status IN ('starting','idle','busy');")

        # Get task count for shard
        local queued_count running_count
        queued_count=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM tasks WHERE shard='${shard}' AND state='QUEUED';")
        running_count=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM tasks WHERE shard='${shard}' AND state='RUNNING';")

        printf "%-10s | %-10s | Workers: %d | Queued: %d | Running: %d\n" \
            "$shard" "$health" "${worker_count:-0}" "${queued_count:-0}" "${running_count:-0}"
    done
}

# Check for unhealthy shards (M1-006)
# Returns list of unhealthy shard IDs
get_unhealthy_shards() {
    _pool_require_sqlite
    sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true

    local unhealthy_shards=()
    local i
    for (( i=0; i<SHARD_COUNT; i++ )); do
        local shard="shard-${i}"
        local health
        health=$(get_shard_health "$shard")

        if [[ "$health" == "unhealthy" ]]; then
            unhealthy_shards+=("$shard")
        fi
    done

    if (( ${#unhealthy_shards[@]} > 0 )); then
        printf '%s\n' "${unhealthy_shards[@]}"
    fi
}

# Check shard by worker activity (M1-006)
# Detects shards with no active workers
detect_orphaned_shards() {
    _pool_require_sqlite
    sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true

    local orphaned_shards=()
    local i
    for (( i=0; i<SHARD_COUNT; i++ )); do
        local shard="shard-${i}"
        local esc_shard=$(_sql_escape "$shard")

        # Check for active workers on this shard
        local active_workers
        active_workers=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM workers WHERE shard='${esc_shard}' AND status IN ('starting','idle','busy');")

        if (( active_workers == 0 )); then
            # Check if there are queued tasks for this shard
            local queued_tasks
            queued_tasks=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM tasks WHERE shard='${esc_shard}' AND state='QUEUED';")

            if (( queued_tasks > 0 )); then
                orphaned_shards+=("$shard")
                log_warn "[SHARD] Orphaned shard detected: $shard (no workers, $queued_tasks queued tasks)"
            fi
        fi
    done

    if (( ${#orphaned_shards[@]} > 0 )); then
        printf '%s\n' "${orphaned_shards[@]}"
    fi
}

# =============================================================================
# M1-006: Auto-Rebalancing When Shard Goes Down
# =============================================================================
# Automatically redistributes tasks when a shard becomes unhealthy
# Maintains service continuity during partial outages
# =============================================================================

# Redistribute tasks from an unhealthy shard (M1-006)
# Usage: redistribute_shard_tasks SHARD
redistribute_shard_tasks() {
    local unhealthy_shard="${1:-}"

    if [[ -z "$unhealthy_shard" ]]; then
        return 1
    fi

    _pool_require_sqlite
    sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true

    local normalized_shard
    normalized_shard=$(normalize_shard_id "$unhealthy_shard")
    local esc_shard=$(_sql_escape "$normalized_shard")

    # Get count of tasks to redistribute
    local task_count
    task_count=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM tasks WHERE shard='${esc_shard}' AND state='QUEUED';")

    if (( task_count == 0 )); then
        log_info "[SHARD] No queued tasks to redistribute from $normalized_shard"
        return 0
    fi

    log_warn "[SHARD] Redistributing $task_count tasks from unhealthy shard $normalized_shard"

    # Find healthy shards
    local healthy_shards=()
    local i
    for (( i=0; i<SHARD_COUNT; i++ )); do
        local shard="shard-${i}"
        if [[ "$shard" == "$normalized_shard" ]]; then
            continue
        fi

        local health
        health=$(get_shard_health "$shard")
        if [[ "$health" == "healthy" || "$health" == "degraded" ]]; then
            healthy_shards+=("$shard")
        fi
    done

    if (( ${#healthy_shards[@]} == 0 )); then
        log_error "[SHARD] No healthy shards available for redistribution"
        return 1
    fi

    # Distribute tasks evenly across healthy shards
    local tasks_per_shard=$(( (task_count + ${#healthy_shards[@]} - 1) / ${#healthy_shards[@]} ))

    local idx=0
    for target_shard in "${healthy_shards[@]}"; do
        local esc_target=$(_sql_escape "$target_shard")
        local offset=$((idx * tasks_per_shard))

        sqlite3 "$STATE_DB" <<SQL
UPDATE tasks
SET shard='${esc_target}', updated_at=datetime('now')
WHERE id IN (
    SELECT id FROM tasks
    WHERE shard='${esc_shard}' AND state='QUEUED'
    ORDER BY priority ASC, created_at ASC
    LIMIT ${tasks_per_shard}
    OFFSET ${offset}
);
SQL

        local moved
        moved=$(sqlite3 "$STATE_DB" "SELECT changes();")
        if (( moved > 0 )); then
            log_info "[SHARD] Moved $moved tasks from $normalized_shard to $target_shard"
        fi

        idx=$((idx + 1))
    done

    # Log redistribution event
    sqlite3 "$STATE_DB" <<SQL
INSERT INTO events (task_id, event_type, actor, payload, trace_id)
VALUES (NULL, 'SHARD_REDISTRIBUTION', 'supervisor', '{"from_shard": "${esc_shard}", "task_count": ${task_count}}', '${TRACE_ID}');
SQL

    return 0
}

# Auto-rebalance on shard failure (M1-006)
# Called from the supervisor loop to handle shard failures
auto_rebalance_on_failure() {
    _pool_require_sqlite
    sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true

    # Detect orphaned shards (shards with no workers but queued tasks)
    local orphaned
    orphaned=$(detect_orphaned_shards)

    if [[ -n "$orphaned" ]]; then
        while IFS= read -r shard; do
            [[ -z "$shard" ]] && continue
            log_warn "[SHARD] Auto-rebalancing triggered for orphaned shard: $shard"
            redistribute_shard_tasks "$shard"
        done <<< "$orphaned"
    fi

    # Detect unhealthy shards based on heartbeat
    local unhealthy
    unhealthy=$(get_unhealthy_shards)

    if [[ -n "$unhealthy" ]]; then
        while IFS= read -r shard; do
            [[ -z "$shard" ]] && continue
            log_warn "[SHARD] Auto-rebalancing triggered for unhealthy shard: $shard"
            redistribute_shard_tasks "$shard"
        done <<< "$unhealthy"
    fi
}

# Comprehensive shard health check (M1-006)
# Combines worker health check with shard monitoring
shard_health_check() {
    _pool_require_sqlite
    sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true

    # Run standard pool health check
    pool_health_check

    # Update shard health based on worker status
    local i
    for (( i=0; i<SHARD_COUNT; i++ )); do
        local shard="shard-${i}"
        local esc_shard=$(_sql_escape "$shard")

        # Get active worker for this shard
        local active_worker
        active_worker=$(sqlite3 "$STATE_DB" "SELECT worker_id FROM workers WHERE shard='${esc_shard}' AND status IN ('starting','idle','busy') ORDER BY last_heartbeat DESC LIMIT 1;")

        if [[ -n "$active_worker" ]]; then
            update_shard_heartbeat "$shard" "$active_worker"
        fi
    done

    # Check for imbalance and trigger rebalancing if needed
    if ! check_shard_balance; then
        log_warn "[SHARD] Task imbalance detected, triggering rebalancing"
        rebalance_shards
    fi

    # Handle failed shards
    auto_rebalance_on_failure
}

pool_graceful_shutdown() {
    _pool_require_sqlite
    sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true

    local rows
    rows=$(_sqlite_exec "$STATE_DB" -separator '|' "SELECT worker_id, pid FROM workers WHERE status IN ('starting','idle','busy');")

    local row
    while IFS='|' read -r worker_id pid; do
        [[ -z "$worker_id" || -z "$pid" ]] && continue
        _sqlite_exec "$STATE_DB" "UPDATE workers SET status='stopping', last_heartbeat=datetime('now') WHERE worker_id='${worker_id}';"
        kill -TERM "$pid" 2>/dev/null || true
    done <<< "$rows"

    local deadline=$((SECONDS + POOL_SHUTDOWN_TIMEOUT))
    while [[ $SECONDS -lt $deadline ]]; do
        local remaining
        remaining=$(_sqlite_exec "$STATE_DB" "SELECT COUNT(*) FROM workers WHERE status='stopping';")
        [[ "$remaining" == "0" ]] && break
        sleep 1
    done

    rows=$(_sqlite_exec "$STATE_DB" -separator '|' "SELECT worker_id, pid FROM workers WHERE status='stopping';")
    while IFS='|' read -r worker_id pid; do
        [[ -z "$worker_id" || -z "$pid" ]] && continue
        kill -KILL "$pid" 2>/dev/null || true
        _sqlite_exec "$STATE_DB" "UPDATE workers SET status='dead', last_heartbeat=datetime('now') WHERE worker_id='${worker_id}';"
    done <<< "$rows"
}

automatic_worker_restart() {
    _pool_require_sqlite
    sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true

    # Define expected pool configuration
    # Format: specialization:model:shard
    local expected_workers=(
        "impl:codex:shard-0"
        "review:claude:shard-1"
        "analysis:gemini:shard-2"
    )

    for config in "${expected_workers[@]}"; do
        local spec="${config%%:*}"
        local remainder="${config#*:}"
        local model="${remainder%%:*}"
        local shard="${remainder#*:}"

        # 1) Check for active worker
        local active_worker_id
        active_worker_id=$(_sqlite_exec "$STATE_DB" "SELECT worker_id FROM workers WHERE specialization='$spec' AND shard='$shard' AND status IN ('starting','idle','busy') LIMIT 1;")

        if [[ -z "$active_worker_id" ]]; then
            # No active worker found. Find the dead one to clean up.
            local dead_worker_id
            dead_worker_id=$(_sqlite_exec "$STATE_DB" "SELECT worker_id FROM workers WHERE specialization='$spec' AND shard='$shard' AND status='dead' ORDER BY last_heartbeat DESC LIMIT 1;")

            if [[ -n "$dead_worker_id" ]]; then
                 log_warn "[SUPERVISOR] Detected crashed worker: $dead_worker_id ($spec/$shard). Initiating recovery."
                 
                 # 2) Clean up worker state & 3) Requeue tasks
                 _sqlite_exec "$STATE_DB" <<SQL
UPDATE tasks
SET state='QUEUED', worker_id=NULL, updated_at=datetime('now'), retry_count = COALESCE(retry_count, 0) + 1
WHERE worker_id='$dead_worker_id' AND state='RUNNING';

INSERT INTO events (task_id, event_type, actor, payload, trace_id)
VALUES (NULL, 'WORKER_CRASH_RECOVERY', 'supervisor', '{"worker_id": "$dead_worker_id", "spec": "$spec"}', '${TRACE_ID}');
SQL
            else
                 log_warn "[SUPERVISOR] Missing worker for $spec/$shard. Spawning new one."
            fi

            # 4) Spawn replacement
            local new_worker_id
            new_worker_id=$(start_worker "$spec" "$model" "$shard")
            
            # 5) Notify supervisor
            log_info "[SUPERVISOR] Spawned replacement worker: $new_worker_id"
        fi
    done
}

pool_run_loop() {
    pool_init
    while true; do
        pool_assign_routing
        shard_health_check  # M1-006: Enhanced health check with shard monitoring
        automatic_worker_restart
        sleep "$POOL_CHECK_INTERVAL"
    done
}

# =============================================================================
# M1-006: Shard-Aware Pool Run Loop
# =============================================================================
# Enhanced run loop with full shard monitoring and auto-rebalancing
# =============================================================================

pool_run_loop_sharded() {
    pool_init

    log_info "[SHARD] Starting sharded pool supervisor with ${SHARD_COUNT} shards"

    # Initialize shard health records
    local i
    for (( i=0; i<SHARD_COUNT; i++ )); do
        update_shard_heartbeat "shard-${i}" "supervisor"
    done

    while true; do
        # Assign routing for new tasks
        pool_assign_routing

        # Comprehensive shard health monitoring
        shard_health_check

        # Restart any crashed workers
        automatic_worker_restart

        # Periodic rebalancing check (every 5 cycles)
        local cycle_count="${_POOL_CYCLE_COUNT:-0}"
        _POOL_CYCLE_COUNT=$((cycle_count + 1))

        if (( _POOL_CYCLE_COUNT % 5 == 0 )); then
            if ! check_shard_balance; then
                log_info "[SHARD] Periodic rebalance triggered"
                rebalance_shards
            fi
        fi

        sleep "$POOL_CHECK_INTERVAL"
    done
}

# =============================================================================
# M1-006: Shard Status and Diagnostics
# =============================================================================

# Print comprehensive shard status (M1-006)
shard_status() {
    echo "=============================================="
    echo "Worker Pool Shard Status (M1-006)"
    echo "=============================================="
    echo ""

    # Configuration
    echo "Configuration:"
    echo "  SHARD_COUNT: $SHARD_COUNT"
    echo "  SHARD_HEALTH_TIMEOUT: ${SHARD_HEALTH_TIMEOUT}s"
    echo "  SHARD_REBALANCE_THRESHOLD: $SHARD_REBALANCE_THRESHOLD"
    echo "  WORKER_SHARD: ${WORKER_SHARD:-<not set>}"
    echo ""

    # Shard health
    get_all_shard_health
    echo ""

    # Task distribution
    echo "Task Distribution:"
    echo "=================="
    get_shard_distribution
    echo ""

    # Balance check
    echo "Balance Status:"
    if check_shard_balance; then
        echo "  Status: BALANCED"
    else
        echo "  Status: IMBALANCED (rebalancing recommended)"
    fi
    echo ""

    # Orphaned shards
    echo "Orphaned Shards:"
    local orphaned
    orphaned=$(detect_orphaned_shards)
    if [[ -z "$orphaned" ]]; then
        echo "  None"
    else
        echo "$orphaned" | while read -r shard; do
            echo "  - $shard (no workers, has queued tasks)"
        done
    fi
}
