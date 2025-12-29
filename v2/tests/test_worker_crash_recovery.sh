#!/bin/bash
set -ex

# Setup test environment
echo "Setting up test environment..."
TEST_DIR="$(mktemp -d)"
export AUTONOMOUS_ROOT="$TEST_DIR"
export STATE_DIR="$TEST_DIR/state"
export STATE_DB="$STATE_DIR/tri-agent.db"
export LOG_DIR="$TEST_DIR/logs"
export BIN_DIR="$TEST_DIR/bin"
mkdir -p "$STATE_DIR" "$LOG_DIR" "$BIN_DIR"

# Source the libraries
# We need to copy them to TEST_DIR or just source them from original location
# Sourcing from original location is better, but need to handle relative paths if any.
# The libs use AUTONOMOUS_ROOT, which we overrode.
# So we should copy lib/ to TEST_DIR/lib/
mkdir -p "$TEST_DIR/lib"
cp lib/* "$TEST_DIR/lib/"

# Mock common.sh functions if missing
if [[ ! -f "$TEST_DIR/lib/common.sh" ]]; then
    touch "$TEST_DIR/lib/common.sh"
    echo "log_info() { echo \"INFO: $@\"; }" >> "$TEST_DIR/lib/common.sh"
    echo "log_warn() { echo \"WARN: $@\"; }" >> "$TEST_DIR/lib/common.sh"
    echo "log_error() { echo \"ERROR: $@\"; }" >> "$TEST_DIR/lib/common.sh"
fi

source "$TEST_DIR/lib/worker-pool.sh"

# Mock start_worker to avoid actual process spawning
start_worker() {
    local spec="$1"
    local model="$2"
    local shard="$3"
    local new_id="worker-${spec}-new-$$"
    echo "$new_id"
    # Register the new worker in DB so the loop sees it as "started"
    _sqlite_exec "$STATE_DB" "INSERT INTO workers (worker_id, status, specialization, shard, model, last_heartbeat) VALUES ('$new_id', 'starting', '$spec', '$shard', '$model', datetime('now'));"
}
export -f start_worker

# Initialize DB
sqlite_state_init "$STATE_DB"

echo "Checking tables..."
_sqlite_exec "$STATE_DB" "SELECT name FROM sqlite_master WHERE type='table';"

# Setup: Create a "dead" worker and a running task
DEAD_WORKER="worker-impl-dead"
SPEC="impl"
MODEL="codex"
SHARD="shard-0"
TASK_ID="task-1"

# Insert dead worker
_sqlite_exec "$STATE_DB" "INSERT INTO workers (worker_id, status, specialization, shard, model, last_heartbeat) VALUES ('$DEAD_WORKER', 'dead', '$SPEC', '$SHARD', '$MODEL', datetime('now', '-10 minutes'));"

# Insert running task assigned to dead worker
_sqlite_exec "$STATE_DB" "INSERT INTO tasks (id, state, worker_id, type) VALUES ('$TASK_ID', 'RUNNING', '$DEAD_WORKER', 'IMPLEMENTATION');"

echo "Initial State:"
_sqlite_exec "$STATE_DB" "SELECT id, state, worker_id FROM tasks WHERE id='$TASK_ID';"
_sqlite_exec "$STATE_DB" "SELECT worker_id, status FROM workers WHERE worker_id='$DEAD_WORKER';"

# Run automatic_worker_restart
echo "Running automatic_worker_restart..."
automatic_worker_restart

echo "Post-Recovery State:"
TASK_STATE=$(_sqlite_exec "$STATE_DB" "SELECT state FROM tasks WHERE id='$TASK_ID';")
TASK_WORKER=$(_sqlite_exec "$STATE_DB" "SELECT worker_id FROM tasks WHERE id='$TASK_ID';")
NEW_WORKER_COUNT=$(_sqlite_exec "$STATE_DB" "SELECT COUNT(*) FROM workers WHERE status='starting' AND specialization='$SPEC';")

echo "Task State: $TASK_STATE"
echo "Task Worker: $TASK_WORKER"
echo "New Workers: $NEW_WORKER_COUNT"

# Verification
if [[ "$TASK_STATE" == "QUEUED" ]]; then
    echo "PASS: Task was requeued."
else
    echo "FAIL: Task state is $TASK_STATE (expected QUEUED)."
    exit 1
fi

if [[ -z "$TASK_WORKER" ]]; then
    echo "PASS: Task worker_id is cleared."
else
    echo "FAIL: Task worker_id is $TASK_WORKER (expected empty/NULL)."
    exit 1
fi

if [[ "$NEW_WORKER_COUNT" -ge 1 ]]; then
    echo "PASS: New worker spawned."
else
    echo "FAIL: No new worker spawned."
    exit 1
fi

# Cleanup
rm -rf "$TEST_DIR"
