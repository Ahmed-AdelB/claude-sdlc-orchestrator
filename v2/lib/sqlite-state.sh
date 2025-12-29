#!/bin/bash
# =============================================================================
# sqlite-state.sh - SQLite-backed state management for tri-agent system
# =============================================================================
# Provides:
# - Full SQLite schema (tasks, events, workers, costs, etc.)
# - WAL initialization for concurrency
# - Atomic task claiming
# - State transition helpers
# - Python fallback for environments without sqlite3 binary
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# Safe defaults when sourced without common.sh
AUTONOMOUS_ROOT="${AUTONOMOUS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
STATE_DIR="${STATE_DIR:-${AUTONOMOUS_ROOT}/state}"
STATE_DB="${STATE_DB:-${STATE_DIR}/tri-agent.db}"
TRACE_ID="${TRACE_ID:-sqlite-$(date +%Y%m%d%H%M%S)-$$}"

# Preserve overrides before sourcing common utilities.
_AUTONOMOUS_ROOT_OVERRIDE="${AUTONOMOUS_ROOT}"
_STATE_DIR_OVERRIDE="${STATE_DIR}"
_STATE_DB_OVERRIDE="${STATE_DB}"
_TRACE_ID_OVERRIDE="${TRACE_ID}"

if [[ -f "${AUTONOMOUS_ROOT}/lib/common.sh" ]]; then
    # shellcheck source=/dev/null
    source "${AUTONOMOUS_ROOT}/lib/common.sh"
fi

# Restore overrides to avoid clobbering caller-provided values.
AUTONOMOUS_ROOT="${_AUTONOMOUS_ROOT_OVERRIDE}"
STATE_DIR="${_STATE_DIR_OVERRIDE}"
STATE_DB="${_STATE_DB_OVERRIDE}"
TRACE_ID="${_TRACE_ID_OVERRIDE}"

if [[ -z "${STATE_DIR}" ]]; then
    STATE_DIR="${AUTONOMOUS_ROOT}/state"
fi
if [[ -z "${STATE_DB}" ]]; then
    STATE_DB="${STATE_DIR}/tri-agent.db"
fi
if [[ -z "${TRACE_ID}" ]]; then
    TRACE_ID="sqlite-$(date +%Y%m%d%H%M%S)-$$"
fi

if ! declare -F log_error >/dev/null 2>&1; then
    log_info() { echo "INFO: $*" >&2; }
    log_warn() { echo "WARN: $*" >&2; }
    log_error() { echo "ERROR: $*" >&2; }
fi

_sqlite_require() {
    if command -v sqlite3 >/dev/null 2>&1; then
        return 0
    fi
    if command -v python3 >/dev/null 2>&1;
     then
        return 0
    fi
    echo "Error: neither sqlite3 nor python3 found in PATH" >&2
    return 1
}

_sql_escape() {
    local value="${1:-}"
    # SQL escape: double single quotes to prevent SQL injection
    # SECURITY: This is CRITICAL - single quotes in SQL strings must be doubled
    # The original code only removed forward slashes which was incorrect
    value="${value//\'/\'\'}"
    printf '%s' "$value"
}

# =============================================================================
# db_query() - Safe parameterized SQL query wrapper (Round 6 improvement)
# =============================================================================
# Usage: db_query "SELECT * FROM tasks WHERE id = ?" "$task_id"
#        db_query "UPDATE tasks SET status = ? WHERE id = ?" "$status" "$id"
#
# Arguments:
#   $1 - SQL query template with ? placeholders
#   $2+ - Values to substitute (auto-escaped)
#
# Returns: Query result on stdout, exit code from SQLite
# =============================================================================
db_query() {
    local template="$1"
    shift
    local query="$template"
    local param_index=0

    # Replace each ? with escaped parameter value
    for param in "$@"; do
        local escaped
        escaped=$(_sql_escape "$param")
        # Replace first occurrence of ? with escaped value
        query="${query/\?/\'$escaped\'}"
        ((param_index++))
    done

    # Execute the query
    _sqlite_exec "$STATE_DB" "$query"
}

# db_query_raw - Execute query without result filtering (for multi-statement)
db_query_raw() {
    local template="$1"
    shift
    local query="$template"

    for param in "$@"; do
        local escaped
        escaped=$(_sql_escape "$param")
        query="${query/\?/\'$escaped\'}"
    done

    _sqlite_exec "$STATE_DB" "$query"
}

_sqlite_exec() {
    local db="${1:-$STATE_DB}"
    shift

    # Retry settings for concurrent access
    local max_retries="${SQLITE_MAX_RETRIES:-5}"
    local retry_delay="${SQLITE_RETRY_DELAY:-0.1}"
    local attempt=0
    local result=""
    local exit_code=0

    if command -v sqlite3 >/dev/null 2>&1; then
        # Standard CLI with busy_timeout and WAL pragmas
        while (( attempt < max_retries )); do
            ((attempt++))

            local raw_result
            if [[ $# -eq 0 ]]; then
                # Read from stdin - prepend pragmas
                raw_result=$(cat | {
                    echo "PRAGMA busy_timeout=10000;"
                    echo "PRAGMA journal_mode=WAL;"
                    cat
                } | sqlite3 "$db" 2>&1) && exit_code=0 || exit_code=$?
            else
                # Direct SQL - prepend pragmas
                raw_result=$(sqlite3 "$db" "PRAGMA busy_timeout=10000; PRAGMA journal_mode=WAL; $*" 2>&1) && exit_code=0 || exit_code=$?
            fi

            # Check if it's a locking error
            if [[ $exit_code -eq 0 ]] || ! echo "$raw_result" | grep -qiE "database is locked|busy"; then
                # Success or non-locking error - filter out PRAGMA output
                result=$(echo "$raw_result" | grep -vE '^[0-9]+$|^wal$' || true)
                echo "$result"
                return $exit_code
            fi

            # Locking error - retry with exponential backoff
            if (( attempt < max_retries )); then
                sleep "$(echo "$retry_delay * $attempt" | bc 2>/dev/null || echo "0.2")"
            fi
        done

        # All retries exhausted
        echo "$result" >&2
        return $exit_code
    elif command -v python3 >/dev/null 2>&1;
     then
        # Python fallback
        local sql_arg="$*"
        
        # If no arguments provided, read from stdin (heredoc support)
        if [[ -z "$sql_arg" ]]; then
            sql_arg=$(cat)
        fi

        python3 -c "
import sqlite3, sys, os

db_path = '$db'
sql_to_run = '''$sql_arg'''

try:
    conn = sqlite3.connect(db_path, timeout=10.0)
    # Enable WAL mode via python if possible
    try:
        conn.execute('PRAGMA journal_mode=WAL;')
    except:
        pass
    
    cursor = conn.cursor()
    
    if not sql_to_run.strip():
        sys.exit(0)

    # Execute
    # We use executescript to support multiple statements (BEGIN...COMMIT)
    # Note: executescript does not return rows. 
    # For claim_task_atomic, we need the SELECT id output.
    # We will detect if it's a script or a single query.
    
    # Detect if multiple statements
    sql_stripped = sql_to_run.strip()
    if sql_stripped.endswith(';'):
        sql_stripped = sql_stripped[:-1]
    
    is_script = ';' in sql_stripped
    
    if is_script or 'COMMIT;' in sql_to_run or 'BEGIN' in sql_to_run:
        # It's a script
        cursor.executescript(sql_to_run)
    else:
        # Single statement?
        cursor.execute(sql_to_run)
        for row in cursor.fetchall():
            # Mimic sqlite3 default output (pipe separated)
            print('|'.join([str(item) if item is not None else '' for item in row]))
            
    conn.commit()
except Exception as e:
    sys.stderr.write(f'SQLite Error: {e}\n')
    sys.exit(1)
finally:
    if 'conn' in locals(): conn.close()
"
    else
        echo "Error: sqlite3/python3 missing" >&2
        return 1
    fi
}

# =============================================================================
# db_exec_checked - Execute SQL with error handling and logging
# =============================================================================
# Usage: db_exec_checked "SQL" "operation_name" [critical]
#
# Arguments:
#   sql        - The SQL statement to execute
#   operation  - Human-readable name for the operation (for logging)
#   critical   - If "true", logs CRITICAL and returns 1 on failure
#                If "false" (default), logs WARN and returns 1 on failure
#
# Returns:
#   0 on success, 1 on failure
#
# Example:
#   db_exec_checked "INSERT INTO tasks ..." "create task" true
#   db_exec_checked "UPDATE workers SET ..." "update worker heartbeat" false
# =============================================================================
db_exec_checked() {
    local sql="$1"
    local operation="${2:-SQL operation}"
    local critical="${3:-false}"

    local result=""
    local exit_code=0

    # Execute the SQL and capture both output and exit code
    result=$(_sqlite_exec "$STATE_DB" "$sql" 2>&1) && exit_code=0 || exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        # SQL execution failed
        if [[ "$critical" == "true" ]]; then
            log_error "CRITICAL: $operation failed (exit code: $exit_code)"
            if [[ -n "$result" ]]; then
                log_error "CRITICAL: SQLite error: $result"
            fi
        else
            log_warn "$operation failed (exit code: $exit_code)"
            if [[ -n "$result" ]]; then
                log_warn "SQLite error: $result"
            fi
        fi
        return 1
    fi

    # Check for SQLite error messages in output (some errors don't set exit code)
    if echo "$result" | grep -qiE "^(Error|SQLite Error|Runtime error|database is locked)"; then
        if [[ "$critical" == "true" ]]; then
            log_error "CRITICAL: $operation returned error: $result"
        else
            log_warn "$operation returned error: $result"
        fi
        return 1
    fi

    # Success - output the result if any
    if [[ -n "$result" ]]; then
        echo "$result"
    fi

    return 0
}

_ensure_db() {
    if [[ ! -f "$STATE_DB" ]]; then
        sqlite_state_init "$STATE_DB"
    fi
}

# SEC-003B: Validate database path is safe (symlink protection)
# Prevents symlink attacks against SQLite database files
validate_db_path() {
    local db_path="$1"
    local allowed_base="${2:-$STATE_DIR}"

    # SEC-003B: Reject symlinks to prevent symlink attacks
    if [[ -L "$db_path" ]]; then
        log_error "SEC-003B: Blocked SQLite path - symlink detected: $db_path"
        return 1
    fi

    # SEC-003B: Check parent directory for symlinks
    local parent_dir
    parent_dir=$(dirname "$db_path")
    if [[ -L "$parent_dir" ]]; then
        log_error "SEC-003B: Blocked SQLite path - parent directory is symlink: $parent_dir"
        return 1
    fi

    # SEC-003B: Validate path is within allowed STATE_DIR using realpath
    local canonical_path canonical_base
    canonical_path=$(realpath -m "$db_path" 2>/dev/null || echo "")
    if [[ -z "$canonical_path" ]]; then
        log_error "SEC-003B: Cannot resolve database path: $db_path"
        return 1
    fi
    canonical_base=$(realpath -m "$allowed_base" 2>/dev/null || echo "")
    if [[ -z "$canonical_base" ]]; then
        log_error "SEC-003B: Cannot resolve base directory: $allowed_base"
        return 1
    fi

    if [[ "$canonical_path" != "$canonical_base"* ]]; then
        log_error "SEC-003B: SQLite path escapes STATE_DIR: $db_path -> $canonical_path (allowed: $canonical_base)"
        return 1
    fi

    # SEC-003B: Reject path traversal attempts
    if [[ "$db_path" =~ \.\.\/ || "$db_path" =~ /\.\. ]]; then
        log_error "SEC-003B: Database path contains traversal: $db_path"
        return 1
    fi

    # Validate file extension (warn only)
    if [[ "$db_path" != *.db && "$db_path" != *.sqlite && "$db_path" != *.sqlite3 ]]; then
        log_warn "SEC-003B: Unusual database extension: $db_path"
    fi

    return 0
}

sqlite_state_init() {
    local db="${1:-$STATE_DB}"
    _sqlite_require

    if [[ -L "$db" ]]; then
        log_error 'Security: Blocked SQLite init on symlink'
        return 1
    fi

    # SEC-003B: Validate database path before any operations
    if ! validate_db_path "$db" "$STATE_DIR"; then
        log_error "SEC-003B: Refusing to initialize database at unsafe path: $db"
        return 1
    fi

    local parent_dir
    parent_dir=$(dirname "$db")
    if [[ ! -d "$parent_dir" ]]; then
        mkdir -p "$parent_dir" || {
            log_error "Failed to create database directory: $parent_dir"
            return 1
        }
        chmod 700 "$parent_dir"
    fi

    # SEC-003B: Check if database already exists (with race condition protection)
    if [[ -f "$db" ]]; then
        if [[ -L "$db" ]]; then
            log_error "SEC-003B: Race condition detected - database became symlink: $db"
            return 1
        fi
        log_info "Database already exists: $db"
        return 0
    fi

    # SEC-003B: Final symlink check before creation
    if [[ -L "$db" ]]; then
        log_error "SEC-003B: Database path is symlink (pre-creation): $db"
        return 1
    fi

    touch "$db"
    chmod 600 "$db"

    # Core schema
    _sqlite_exec "$db" <<'SQL'
PRAGMA journal_mode=WAL;
PRAGMA synchronous=NORMAL;
PRAGMA foreign_keys=ON;
PRAGMA busy_timeout=5000;

CREATE TABLE IF NOT EXISTS meta (
    key TEXT PRIMARY KEY,
    value TEXT
);

INSERT OR IGNORE INTO meta (key, value) VALUES ('schema_version', '5.1');  -- M3-019: Added crash recovery columns

CREATE TABLE IF NOT EXISTS state (
    file_path TEXT NOT NULL,
    key TEXT NOT NULL,
    value TEXT,
    updated_at TEXT DEFAULT (datetime('now')),
    PRIMARY KEY (file_path, key)
);

CREATE TABLE IF NOT EXISTS tasks (
    id TEXT PRIMARY KEY,
    name TEXT,
    type TEXT,
    priority INTEGER DEFAULT 2 CHECK(priority BETWEEN 0 AND 3),
    state TEXT NOT NULL CHECK(state IN (
        'QUEUED','RUNNING','REVIEW','APPROVED','REJECTED','COMPLETED',
        'FAILED','ESCALATED','TIMEOUT','PAUSED','CANCELLED'
    )),
    lane TEXT,
    shard TEXT,
    worker_id TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    started_at TEXT,
    completed_at TEXT,
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    parent_task_id TEXT,
    checksum TEXT,
    payload TEXT,
    result TEXT,
    error TEXT,
    trace_id TEXT,
    heartbeat_at TEXT,
    last_activity_at TEXT,
    assigned_model TEXT,
    metadata TEXT,
    FOREIGN KEY (parent_task_id) REFERENCES tasks(id)
);

CREATE INDEX IF NOT EXISTS idx_tasks_state ON tasks(state);
CREATE INDEX IF NOT EXISTS idx_tasks_priority ON tasks(priority);
CREATE INDEX IF NOT EXISTS idx_tasks_worker ON tasks(worker_id);
CREATE INDEX IF NOT EXISTS idx_tasks_type ON tasks(type);

CREATE TABLE IF NOT EXISTS task_checkpoints (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id TEXT NOT NULL,
    checkpoint_at TEXT DEFAULT (datetime('now')),
    payload TEXT,
    trace_id TEXT,
    FOREIGN KEY (task_id) REFERENCES tasks(id)
);

CREATE TABLE IF NOT EXISTS events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id TEXT,
    event_type TEXT NOT NULL,
    actor TEXT NOT NULL,
    payload TEXT,
    timestamp TEXT DEFAULT (datetime('now')),
    trace_id TEXT,
    FOREIGN KEY (task_id) REFERENCES tasks(id)
);

CREATE INDEX IF NOT EXISTS idx_events_task ON events(task_id);

CREATE TABLE IF NOT EXISTS consensus_votes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id TEXT,
    gate_id TEXT NOT NULL,
    claude_vote TEXT,
    codex_vote TEXT,
    gemini_vote TEXT,
    final_decision TEXT,
    timestamp TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (task_id) REFERENCES tasks(id)
);

CREATE TABLE IF NOT EXISTS workers (
    worker_id TEXT PRIMARY KEY,
    pid INTEGER,
    status TEXT CHECK(status IN ('starting','idle','busy','stopping','dead','crashed')) DEFAULT 'starting',
    specialization TEXT,
    started_at TEXT DEFAULT (datetime('now')),
    last_heartbeat TEXT,
    tasks_completed INTEGER DEFAULT 0,
    tasks_failed INTEGER DEFAULT 0,
    shard TEXT,
    model TEXT,
    metadata TEXT,
    -- M3-019: Worker Crash Recovery columns
    crash_count INTEGER DEFAULT 0,
    crashed_at TEXT,
    current_task TEXT
);

CREATE TABLE IF NOT EXISTS worker_heartbeats (
    worker_id TEXT PRIMARY KEY,
    timestamp TEXT DEFAULT (datetime('now')),
    status TEXT,
    task_id TEXT,
    task_type TEXT,
    progress_percent INTEGER DEFAULT 0,
    expected_timeout INTEGER DEFAULT 0,
    last_activity_at TEXT,
    updated_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (worker_id) REFERENCES workers(worker_id)
);

CREATE TABLE IF NOT EXISTS breakers (
    model TEXT PRIMARY KEY,
    state TEXT CHECK(state IN ('CLOSED','OPEN','HALF_OPEN')),
    failure_count INTEGER DEFAULT 0,
    last_failure TEXT,
    last_success TEXT,
    half_open_calls INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS costs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT DEFAULT (datetime('now')),
    model TEXT NOT NULL,
    input_tokens INTEGER,
    output_tokens INTEGER,
    duration_ms INTEGER,
    task_type TEXT,
    trace_id TEXT
);

CREATE INDEX IF NOT EXISTS idx_costs_time ON costs(timestamp);
CREATE INDEX IF NOT EXISTS idx_costs_model ON costs(model);

CREATE VIEW IF NOT EXISTS daily_costs AS
SELECT
    date(timestamp) as day,
    model,
    COUNT(*) as requests,
    COALESCE(SUM(input_tokens),0) as total_input,
    COALESCE(SUM(output_tokens),0) as total_output,
    COALESCE(AVG(duration_ms),0) as avg_duration
FROM costs
GROUP BY date(timestamp), model;

CREATE TABLE IF NOT EXISTS gates (
    gate_id TEXT PRIMARY KEY,
    status TEXT,
    payload TEXT,
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS health_status (
    component TEXT PRIMARY KEY,
    status TEXT,
    details TEXT,
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS supervisor_status (
    key TEXT PRIMARY KEY,
    value TEXT,
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS routing_decisions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT,
    trace_id TEXT,
    model TEXT,
    confidence REAL,
    reason TEXT,
    prompt_length INTEGER,
    file_count INTEGER,
    executed INTEGER,
    forced TEXT,
    consensus INTEGER
);

CREATE TABLE IF NOT EXISTS event_log (
    sequence_id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT DEFAULT (datetime('now')),
    aggregate_type TEXT NOT NULL,
    aggregate_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    event_data TEXT,
    trace_id TEXT,
    causation_id TEXT,
    correlation_id TEXT
);
SQL

    # FTS tables (optional)
    _sqlite_exec "$db" <<'SQL' 2>/dev/null || true
CREATE VIRTUAL TABLE IF NOT EXISTS context_store USING fts5(
    task_id,
    content,
    content_type,
    timestamp,
    tokenize='porter unicode61'
);

CREATE TABLE IF NOT EXISTS context_embeddings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id TEXT,
    chunk_hash TEXT,
    embedding BLOB,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS documents (
    id TEXT PRIMARY KEY,
    type TEXT NOT NULL,
    title TEXT,
    content TEXT NOT NULL,
    embedding BLOB,
    created_at TEXT DEFAULT (datetime('now')),
    task_id TEXT,
    trace_id TEXT
);

CREATE VIRTUAL TABLE IF NOT EXISTS documents_fts USING fts5(
    title,
    content,
    content='documents',
    content_rowid='rowid'
);

CREATE TRIGGER IF NOT EXISTS documents_ai AFTER INSERT ON documents BEGIN
    INSERT INTO documents_fts(rowid, title, content)
    VALUES (new.rowid, new.title, new.content);
END;

CREATE TRIGGER IF NOT EXISTS documents_ad AFTER DELETE ON documents BEGIN
    INSERT INTO documents_fts(documents_fts, rowid, title, content)
    VALUES('delete', old.rowid, old.title, old.content);
END;

CREATE TRIGGER IF NOT EXISTS documents_au AFTER UPDATE ON documents BEGIN
    INSERT INTO documents_fts(documents_fts, rowid, title, content)
    VALUES('delete', old.rowid, old.title, old.content);
    INSERT INTO documents_fts(rowid, title, content)
    VALUES (new.rowid, new.title, new.content);
END;
SQL
}

# ----------------------------------------------------------------------------
# Key/value state helpers (compatible with state.sh interface)
# ----------------------------------------------------------------------------
state_get() {
    local file_path="$1"
    local key="$2"
    local default="${3:-}"
    local esc_file esc_key result
    _ensure_db
    esc_file=$(_sql_escape "$file_path")
    esc_key=$(_sql_escape "$key")
    result=$(_sqlite_exec "$STATE_DB" "SELECT value FROM state WHERE file_path='${esc_file}' AND key='${esc_key}' LIMIT 1;")
    echo "${result:-$default}"
}

state_set() {
    local file_path="$1"
    local key="$2"
    local value="$3"
    local esc_file esc_key esc_val
    _ensure_db
    esc_file=$(_sql_escape "$file_path")
    esc_key=$(_sql_escape "$key")
    esc_val=$(_sql_escape "$value")
    _sqlite_exec "$STATE_DB" "INSERT OR REPLACE INTO state (file_path, key, value, updated_at) VALUES ('${esc_file}','${esc_key}','${esc_val}', datetime('now'));"
}

state_delete() {
    local file_path="$1"
    local key="$2"
    local esc_file esc_key
    _ensure_db
    esc_file=$(_sql_escape "$file_path")
    esc_key=$(_sql_escape "$key")
    _sqlite_exec "$STATE_DB" "DELETE FROM state WHERE file_path='${esc_file}' AND key='${esc_key}';"
}

# ----------------------------------------------------------------------------
# Task helpers
# ----------------------------------------------------------------------------
priority_to_int() {
    case "${1:-}" in
        CRITICAL|critical) echo 0 ;;
        HIGH|high) echo 1 ;;
        MEDIUM|medium) echo 2 ;;
        LOW|low) echo 3 ;;
        *) echo 2 ;;
    esac
}

is_valid_transition() {
    local from="$1"
    local to="$2"
    case "$from" in
        QUEUED) [[ "$to" == "RUNNING" || "$to" == "CANCELLED" ]] ;;
        RUNNING) [[ "$to" == "REVIEW" || "$to" == "TIMEOUT" || "$to" == "PAUSED" || "$to" == "CANCELLED" || "$to" == "FAILED" || "$to" == "COMPLETED" ]] ;;
        REVIEW) [[ "$to" == "APPROVED" || "$to" == "REJECTED" || "$to" == "ESCALATED" || "$to" == "FAILED" ]] ;;
        REJECTED) [[ "$to" == "QUEUED" || "$to" == "ESCALATED" ]] ;;
        TIMEOUT) [[ "$to" == "QUEUED" || "$to" == "ESCALATED" ]] ;;
        PAUSED) [[ "$to" == "RUNNING" || "$to" == "CANCELLED" || "$to" == "QUEUED" ]] ;;
        APPROVED) [[ "$to" == "COMPLETED" || "$to" == "ESCALATED" ]] ;;
        FAILED) [[ "$to" == "QUEUED" || "$to" == "ESCALATED" || "$to" == "CANCELLED" ]] ;;
        COMPLETED|ESCALATED|CANCELLED) return 1 ;;
        *) return 1 ;;
    esac
}

transition_task() {
    local task_id="$1"
    local new_state="$2"
    local reason="${3:-}"
    local actor="${4:-system}"

    local esc_task esc_state esc_reason esc_actor
    _ensure_db
    esc_task=$(_sql_escape "$task_id")
    esc_state=$(_sql_escape "$new_state")
    esc_reason=$(_sql_escape "$reason")
    esc_actor=$(_sql_escape "$actor")

    local current_state
    current_state=$(_sqlite_exec "$STATE_DB" "SELECT state FROM tasks WHERE id='${esc_task}' LIMIT 1;")
    if [[ -z "$current_state" ]]; then
        echo "Error: task not found: $task_id" >&2
        return 1
    fi

    if ! is_valid_transition "$current_state" "$new_state"; then
        echo "Error: invalid transition $current_state -> $new_state for $task_id" >&2
        return 1
    fi

    local completed_at=""
    if [[ "$new_state" == "COMPLETED" || "$new_state" == "ESCALATED" || "$new_state" == "CANCELLED" ]]; then
        completed_at=", completed_at=datetime('now')"
    fi

    # M1-FIX: Verify UPDATE succeeded via changes()
    # Added: flock + busy_timeout + retry logic for concurrent access
    local result
    local attempt=0
    local max_retries="${SQLITE_MAX_RETRIES:-10}"
    local exit_code=0
    local lock_file="${STATE_DB}.lock"
    touch "$lock_file" 2>/dev/null || lock_file="/tmp/.tri-agent-sqlite.lock"
    touch "$lock_file" 2>/dev/null || true

    if command -v sqlite3 >/dev/null 2>&1; then
        while (( attempt < max_retries )); do
            ((attempt++))
            # Use flock for application-level serialization
            local raw_result
            raw_result=$(
                flock -w 15 200 2>/dev/null || true
                sqlite3 "$STATE_DB" <<SQL 2>&1
PRAGMA busy_timeout=30000;
PRAGMA journal_mode=WAL;
UPDATE tasks SET state='${esc_state}', updated_at=datetime('now')${completed_at} WHERE id='${esc_task}';
SELECT changes();
SQL
            ) 200>"$lock_file" && exit_code=0 || exit_code=$?

            if [[ $exit_code -eq 0 ]] || ! echo "$raw_result" | grep -qiE "database is locked|busy|Runtime error"; then
                # Filter out PRAGMA output, keep only the changes() result
                result=$(echo "$raw_result" | grep -vE '^wal$' | tail -1)
                break
            fi
            if (( attempt < max_retries )); then
                local delay jitter
                delay=$(awk "BEGIN {printf \"%.2f\", 0.2 * $attempt * $attempt}" 2>/dev/null || echo "0.5")
                jitter=$(awk "BEGIN {srand(); printf \"%.2f\", rand() * 0.3}" 2>/dev/null || echo "0.1")
                sleep "$(awk "BEGIN {printf \"%.2f\", $delay + $jitter}" 2>/dev/null || echo "0.5")" 2>/dev/null || sleep 1
            fi
        done
    else
        # Python fallback
        result=$(python3 -c "
import sqlite3, sys
try:
    conn = sqlite3.connect('$STATE_DB', timeout=10.0)
    cur = conn.cursor()
    cur.execute(\"UPDATE tasks SET state='${esc_state}', updated_at=datetime('now')${completed_at} WHERE id='${esc_task}'\")
    conn.commit()
    print(cur.rowcount)
    conn.close()
except:
    print('0')
")
    fi

    # Check if row was updated
    if [[ "$result" == "0" ]]; then
        echo "Error: Failed to update task $task_id state to $new_state (DB lock or concurrent mod)" >&2
        return 1
    fi

    if [[ -n "$reason" ]]; then
        _sqlite_exec "$STATE_DB" "INSERT INTO events (task_id, event_type, actor, payload, trace_id) VALUES ('${esc_task}','STATE_${esc_state}','${esc_actor}','${esc_reason}','${TRACE_ID}');"
    else
        _sqlite_exec "$STATE_DB" "INSERT INTO events (task_id, event_type, actor, payload, trace_id) VALUES ('${esc_task}','STATE_${esc_state}','${esc_actor}','', '${TRACE_ID}');"
    fi
    
    return 0
}

create_task() {
    local task_id="$1"
    local name="${2:-$task_id}"
    local type="${3:-}"
    local priority="${4:-MEDIUM}"
    local payload="${5:-}"
    local state="${6:-QUEUED}"
    local trace_id="${7:-$TRACE_ID}"

    local p_int
    _ensure_db
    p_int=$(priority_to_int "$priority")

    local esc_id esc_name esc_type esc_payload esc_state esc_trace
    esc_id=$(_sql_escape "$task_id")
    esc_name=$(_sql_escape "$name")
    esc_type=$(_sql_escape "$type")
    esc_payload=$(_sql_escape "$payload")
    esc_state=$(_sql_escape "$state")
    esc_trace=$(_sql_escape "$trace_id")

    _sqlite_exec "$STATE_DB" "INSERT OR IGNORE INTO tasks (id, name, type, priority, state, payload, trace_id) VALUES ('${esc_id}','${esc_name}','${esc_type}',${p_int},'${esc_state}','${esc_payload}','${esc_trace}');"
}

update_task_worker() {
    local task_id="$1"
    local worker_id="$2"
    local esc_task esc_worker
    _ensure_db
    esc_task=$(_sql_escape "$task_id")
    esc_worker=$(_sql_escape "$worker_id")
    _sqlite_exec "$STATE_DB" "UPDATE tasks SET worker_id='${esc_worker}', updated_at=datetime('now') WHERE id='${esc_task}';"
}

increment_retry() {
    local task_id="$1"
    local esc_task
    _ensure_db
    esc_task=$(_sql_escape "$task_id")
    _sqlite_exec "$STATE_DB" "UPDATE tasks SET retry_count=retry_count+1, updated_at=datetime('now') WHERE id='${esc_task}';"
}

# =============================================================================
# M1-001: SQLite Canonical Task Claiming
# =============================================================================
# Uses BEGIN IMMEDIATE transaction for atomic task claiming.
# Verifies the UPDATE succeeded before returning task ID.
#
# Key guarantees:
# 1. BEGIN IMMEDIATE acquires write lock at transaction start
# 2. WHERE state='QUEUED' prevents claiming already-claimed tasks
# 3. changes() > 0 check verifies the claim actually succeeded
# 4. Only the worker that successfully claimed gets the task ID
#
# This prevents race conditions where multiple workers try to claim
# the same task simultaneously.
# =============================================================================

# M1-001: Log task claim attempt for audit trail
_log_claim_attempt() {
    local worker_id="$1"
    local task_id="$2"
    local success="$3"
    local reason="${4:-}"

    if command -v sqlite3 >/dev/null 2>&1 && [[ -f "$STATE_DB" ]]; then
        local esc_worker="${worker_id//\'/\'\'}"
        local esc_task="${task_id//\'/\'\'}"
        local esc_reason="${reason//\'/\'\'}"

        sqlite3 "$STATE_DB" "
            INSERT INTO events (task_id, event_type, actor, payload, trace_id)
            VALUES (
                NULLIF('${esc_task}', ''),
                CASE WHEN $success THEN 'TASK_CLAIM_SUCCESS' ELSE 'TASK_CLAIM_ATTEMPT' END,
                '${esc_worker}',
                json_object('success', $success, 'reason', '${esc_reason}'),
                '${TRACE_ID}'
            );
        " 2>/dev/null || true
    fi
}

# Canonical SQLite task claim function (M1-001)
# Returns task ID only if claim succeeded, empty otherwise
sqlite_claim_task() {
    local worker_id="$1"
    local task_types_csv="${2:-}"
    local shard="${3:-}"
    local model="${4:-}"

    # Delegate to the filtered version for full functionality
    local result
    result=$(claim_task_atomic_filtered "$worker_id" "$task_types_csv" "$shard" "$model")

    # M1-001: Log the result for audit trail
    if [[ -n "$result" ]]; then
        _log_claim_attempt "$worker_id" "$result" 1 "atomic claim success"
    fi

    echo "$result"
}

# Atomic task claim (returns task id if claimed, empty otherwise)
claim_task_atomic() {
    local worker_id="$1"
    local task_types_csv="${2:-}"
    local esc_worker
    _ensure_db
    esc_worker=$(_sql_escape "$worker_id")

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

    # Using standard CLI if available
    if command -v sqlite3 >/dev/null 2>&1;
     then
        local result
        # M1-001: Use BEGIN IMMEDIATE and verify UPDATE succeeded via changes()
        result=$(sqlite3 "$STATE_DB" <<SQL
BEGIN IMMEDIATE;
-- Select candidate task (priority 0=CRITICAL, 1=HIGH, 2=MEDIUM, 3=LOW)
UPDATE tasks
SET state='RUNNING',
    worker_id='${esc_worker}',
    started_at=datetime('now'),
    updated_at=datetime('now'),
    heartbeat_at=datetime('now')
WHERE id = (
    SELECT id FROM tasks
    WHERE state='QUEUED'${type_filter}
    ORDER BY priority ASC, created_at ASC
    LIMIT 1
) AND state='QUEUED';
-- Only return task ID if we actually claimed it (changes() > 0)
SELECT CASE WHEN changes() > 0
    THEN (SELECT id FROM tasks WHERE worker_id='${esc_worker}' AND state='RUNNING' ORDER BY started_at DESC LIMIT 1)
    ELSE NULL
END;
COMMIT;
SQL
)
        # Filter out empty/null results
        if [[ -n "$result" && "$result" != "NULL" && "$result" != "" ]]; then
            echo "$result"
        fi
    else
        # Python fallback for transaction with result return
        # M1-001: Verify rowcount > 0 before returning task ID
        python3 -c "
import sqlite3, sys
db_path = '$STATE_DB'
worker_id = '$worker_id'
type_filter = '''$type_filter'''

try:
    conn = sqlite3.connect(db_path, timeout=10.0)
    conn.isolation_level = None  # Manual transaction control
    cur = conn.cursor()
    cur.execute('BEGIN IMMEDIATE')

    # 1. Find candidate
    sql = f'''
    SELECT id FROM tasks
    WHERE state='QUEUED'{type_filter}
    ORDER BY priority ASC, created_at ASC
    LIMIT 1
    '''
    cur.execute(sql)
    row = cur.fetchone()

    if row:
        task_id = row[0]
        # 2. Atomic update with state double-check
        cur.execute('''
        UPDATE tasks
        SET state='RUNNING',
            worker_id=?,
            started_at=datetime('now'),
            updated_at=datetime('now'),
            heartbeat_at=datetime('now')
        WHERE id = ? AND state='QUEUED'
        ''', (worker_id, task_id))

        # M1-001: Only return task ID if UPDATE actually succeeded
        if cur.rowcount > 0:
            cur.execute('COMMIT')
            print(task_id)
        else:
            # Another worker claimed it first
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

# Atomic task claim with shard/model filters (M1-001)
# Usage: claim_task_atomic_filtered WORKER_ID "TYPE1,TYPE2" SHARD MODEL
# Returns task ID only if claim succeeded, empty otherwise
claim_task_atomic_filtered() {
    local worker_id="$1"
    local task_types_csv="${2:-}"
    local shard="${3:-}"
    local model="${4:-}"
    local esc_worker esc_shard esc_model
    _ensure_db
    esc_worker=$(_sql_escape "$worker_id")
    esc_shard=$(_sql_escape "$shard")
    esc_model=$(_sql_escape "$model")

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

    local shard_filter=""
    if [[ -n "$shard" ]]; then
        shard_filter=" AND (shard IS NULL OR shard='${esc_shard}')"
    fi

    local model_filter=""
    if [[ -n "$model" ]]; then
        model_filter=" AND (assigned_model IS NULL OR assigned_model='${esc_model}')"
    fi

    if command -v sqlite3 >/dev/null 2>&1;
     then
        local result
        local attempt=0
        local max_retries="${SQLITE_MAX_RETRIES:-10}"
        local exit_code=0
        local lock_file="${STATE_DB}.lock"
        touch "$lock_file" 2>/dev/null || lock_file="/tmp/.tri-agent-sqlite.lock"
        touch "$lock_file" 2>/dev/null || true

        # M1-001: BEGIN IMMEDIATE for atomic claiming with verified success
        # Added: flock + busy_timeout + retry logic for concurrent access
        # Research: https://berthub.eu/articles/posts/a-brief-post-on-sqlite3-database-locked-despite-timeout/
        while (( attempt < max_retries )); do
            ((attempt++))
            # Use flock for application-level serialization
            # M1-001-FIX: Atomic claim with direct UPDATE
            # Filter PRAGMA output at bash level to avoid .output issues
            local raw_result
            raw_result=$(
                flock -w 15 200 2>/dev/null || true  # Wait up to 15s for lock
                sqlite3 "$STATE_DB" <<SQL 2>&1
PRAGMA busy_timeout=30000;
PRAGMA journal_mode=WAL;
BEGIN IMMEDIATE;
-- Atomic claim: Update first QUEUED task, verify success via changes()
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
-- Only return task ID if we actually claimed it (changes() > 0)
-- Use max(started_at) to get the task we just updated
SELECT CASE WHEN changes() > 0
    THEN (SELECT id FROM tasks
          WHERE worker_id='${esc_worker}' AND state='RUNNING'
          AND started_at = (SELECT MAX(started_at) FROM tasks
                            WHERE worker_id='${esc_worker}' AND state='RUNNING'))
    ELSE NULL
END;
COMMIT;
SQL
            ) 200>"$lock_file" && exit_code=0 || exit_code=$?

            # Check for locking errors in raw result
            if [[ $exit_code -eq 0 ]] || ! echo "$raw_result" | grep -qiE "database is locked|busy|Runtime error"; then
                # Filter out PRAGMA output (numbers and 'wal'), keep only task IDs
                result=$(echo "$raw_result" | grep -vE '^[0-9]+$|^wal$|^$' | tail -1)
                break  # Success or non-locking error
            fi

            # Locking error - retry with exponential backoff + jitter
            if (( attempt < max_retries )); then
                local delay jitter
                delay=$(awk "BEGIN {printf \"%.2f\", 0.2 * $attempt * $attempt}" 2>/dev/null || echo "0.5")
                jitter=$(awk "BEGIN {srand(); printf \"%.2f\", rand() * 0.3}" 2>/dev/null || echo "0.1")
                sleep "$(awk "BEGIN {printf \"%.2f\", $delay + $jitter}" 2>/dev/null || echo "0.5")" 2>/dev/null || sleep 1
            fi
        done
        # Filter out empty/null results
        if [[ -n "$result" && "$result" != "NULL" && "$result" != "" ]]; then
            echo "$result"
        fi
    else
        # Python fallback with verified claim success
        python3 -c "
import sqlite3, sys
db_path = '$STATE_DB'
worker_id = '$worker_id'
type_filter = '''$type_filter'''
shard_filter = '''$shard_filter'''
model_filter = '''$model_filter'''

try:
    conn = sqlite3.connect(db_path, timeout=10.0)
    conn.isolation_level = None  # Manual transaction control
    cur = conn.cursor()
    # M1-001: BEGIN IMMEDIATE acquires write lock immediately
    cur.execute('BEGIN IMMEDIATE')

    # 1. Find candidate task matching filters
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
        # 2. Atomic update with state double-check
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

        # M1-001: Only return task ID if UPDATE actually succeeded
        if cur.rowcount > 0:
            cur.execute('COMMIT')
            print(task_id)
        else:
            # Another worker claimed it first (race condition handled)
            cur.execute('ROLLBACK')
    else:
        # No matching tasks in queue
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

# ----------------------------------------------------------------------------
# Transition helpers (explicit)
# ----------------------------------------------------------------------------
mark_task_running() {
    local task_id="$1"
    local worker_id="$2"
    update_task_worker "$task_id" "$worker_id"
    transition_task "$task_id" "RUNNING" "" "$worker_id"
}

mark_task_review() { transition_task "$1" "REVIEW" "" "system"; }
mark_task_approved() { transition_task "$1" "APPROVED" "" "system"; }
mark_task_rejected() { increment_retry "$1"; transition_task "$1" "REJECTED" "${2:-}" "system"; }
mark_task_completed() { transition_task "$1" "COMPLETED" "${2:-}" "system"; }
mark_task_failed() { increment_retry "$1"; transition_task "$1" "FAILED" "${2:-}" "system"; }
mark_task_escalated() { transition_task "$1" "ESCALATED" "${2:-}" "system"; }
mark_task_timeout() { transition_task "$1" "TIMEOUT" "${2:-}" "system"; }
mark_task_paused() { transition_task "$1" "PAUSED" "${2:-}" "system"; }
mark_task_cancelled() { transition_task "$1" "CANCELLED" "${2:-}" "system"; }
mark_task_requeued() { transition_task "$1" "QUEUED" "${2:-}" "system"; }

recover_stale_task() {
    local task_id="$1"
    local worker_id="${2:-}"
    local reason="${3:-stale heartbeat}"
    local esc_task esc_worker
    _ensure_db
    esc_task=$(_sql_escape "$task_id")
    esc_worker=$(_sql_escape "$worker_id")

    _sqlite_exec "$STATE_DB" "UPDATE tasks SET state='QUEUED', worker_id=NULL, updated_at=datetime('now') WHERE id='${esc_task}';"
    if [[ -n "$worker_id" ]]; then
        _sqlite_exec "$STATE_DB" "UPDATE workers SET status='dead', last_heartbeat=datetime('now') WHERE worker_id='${esc_worker}';"
    fi
    _sqlite_exec "$STATE_DB" "INSERT INTO events (task_id, event_type, actor, payload, trace_id) VALUES ('${esc_task}','RECOVER_STALE','system','${reason}','${TRACE_ID}');"
}

recover_zombie_tasks() {
    local timeout_minutes="${1:-60}"
    _ensure_db
    
    _sqlite_exec "$STATE_DB" <<SQL
BEGIN IMMEDIATE;
UPDATE tasks 
SET state='QUEUED', worker_id=NULL, updated_at=datetime('now')
WHERE state='RUNNING' 
  AND worker_id IN (
      SELECT worker_id FROM workers 
      WHERE last_heartbeat < datetime('now', '-$timeout_minutes minutes')
  );
  
UPDATE workers
SET status='dead'
WHERE last_heartbeat < datetime('now', '-$timeout_minutes minutes')
  AND status != 'dead';
COMMIT;
SQL
}

ensure_task_exists() {
    local task_id="$1"
    local priority="${2:-MEDIUM}"
    local state="${3:-QUEUED}"
    local p_int
    _ensure_db
    p_int=$(priority_to_int "$priority")
    local esc_id=$(_sql_escape "$task_id")
    local esc_state=$(_sql_escape "$state")
    
    _sqlite_exec "$STATE_DB" "INSERT OR IGNORE INTO tasks (id, name, type, priority, state, created_at, updated_at) VALUES ('${esc_id}', '${esc_id}', 'general', ${p_int}, '${esc_state}', datetime('now'), datetime('now'));"
}

set_pause_requested() {
    local reason="${1:-budget}"
    state_set "system" "pause_requested" "1"
    state_set "system" "pause_reason" "$reason"
    state_set "system" "pause_requested_at" "$(date -Iseconds)"
}

clear_pause_requested() {
    state_set "system" "pause_requested" "0"
    state_delete "system" "pause_reason"
    state_delete "system" "pause_requested_at"
}

pause_requested() {
    local value
    value=$(state_get "system" "pause_requested" "0")
    [[ "$value" == "1" ]]
}
