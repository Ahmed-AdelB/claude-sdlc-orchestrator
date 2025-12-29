#!/bin/bash
set -u

# Setup environment
export AUTONOMOUS_ROOT=$(pwd)
export STATE_DIR="${AUTONOMOUS_ROOT}/state"
export STATE_DB="${STATE_DIR}/tri-agent.db"
export TASKS_DIR="${AUTONOMOUS_ROOT}/tasks"
export REVIEW_DIR="${TASKS_DIR}/review"
export APPROVED_DIR="${TASKS_DIR}/approved"
export LOG_DIR="${AUTONOMOUS_ROOT}/logs/supervision"
export GATES_DIR="${STATE_DIR}/gates"

# Clean up
rm -f "$STATE_DB"
mkdir -p "$REVIEW_DIR" "$APPROVED_DIR" "$LOG_DIR" "$GATES_DIR"

# Initialize DB
source lib/sqlite-state.sh
sqlite_state_init "$STATE_DB"

# Create a test task in REVIEW state
TASK_ID="TEST-TASK-001"
create_task "$TASK_ID" "Test Task" "general" "HIGH" "{}" "REVIEW"
echo "Initial State in DB:"
_sqlite_exec "$STATE_DB" "SELECT id, state FROM tasks WHERE id='$TASK_ID';"

# Create dummy task file
echo "Task content" > "${REVIEW_DIR}/${TASK_ID}.md"

# Create dummy gate results (all pass)
cat <<EOF > "${GATES_DIR}/tests_${TASK_ID}.json"
{"check":"EXE-001","status":"PASS","exit_code":0}
EOF
cat <<EOF > "${GATES_DIR}/coverage_${TASK_ID}.json"
{"check":"EXE-002","status":"PASS","coverage":90}
EOF
cat <<EOF > "${GATES_DIR}/lint_${TASK_ID}.json"
{"check":"EXE-003","status":"PASS","errors":0}
EOF
cat <<EOF > "${GATES_DIR}/types_${TASK_ID}.json"
{"check":"EXE-004","status":"PASS","errors":0}
EOF
cat <<EOF > "${GATES_DIR}/security_${TASK_ID}.json"
{"check":"EXE-005","status":"PASS","critical":0}
EOF
cat <<EOF > "${GATES_DIR}/build_${TASK_ID}.json"
{"check":"EXE-006","status":"PASS","exit_code":0}
EOF

# Mock quality_gate_breaker to always succeed (since we don't want to rely on the actual circuit breaker logic for this test)
quality_gate_breaker() {
    return 0
}
export -f quality_gate_breaker

# Run supervisor approver workflow
# We need to source supervisor-approver.sh to use its functions, or run it if it's executable.
# It seems it has a main() function that handles 'workflow' command.
# But quality_gate calls check_tests etc which try to run real tools.
# We need to mock the checks or just ensure the 'quality_gate' function reads our dummy json files.
# The 'quality_gate' function in supervisor-approver.sh *calls* check_tests etc.
# We need to mock check_tests, check_coverage etc. to just return 0 and write the json.
# OR, since we already wrote the JSON files, if quality_gate logic checks them...
# Wait, quality_gate logic runs the checks.
# We need to override the check functions.

source lib/supervisor-approver.sh

# Override check functions to do nothing (since we pre-populated JSONs)
check_tests() { return 0; }
check_coverage() { return 0; }
check_lint() { return 0; }
check_types() { return 0; }
check_security() { return 0; }
check_build() { return 0; }

# Run workflow
echo "Running unified_workflow..."
unified_workflow "$TASK_ID" "$(pwd)"

# Check results
echo "Final State in DB:"
_sqlite_exec "$STATE_DB" "SELECT id, state FROM tasks WHERE id='$TASK_ID';"

echo "File location:"
if [[ -f "${APPROVED_DIR}/${TASK_ID}.md" ]]; then
    echo "File moved to APPROVED_DIR"
elif [[ -f "${REVIEW_DIR}/${TASK_ID}.md" ]]; then
    echo "File still in REVIEW_DIR"
else
    echo "File missing"
fi
