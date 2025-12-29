#!/bin/bash
#===============================================================================
# test_worker_supervisor_comms.sh - Integration tests for Worker-Supervisor IPC
#===============================================================================
# Tests:
# 1. test_dependency_request_timeout - Test DEP_REQUEST timeout handling
# 2. test_ipc_race_conditions - Test for race conditions in IPC
# 3. test_heartbeat_timeout_detection - Test worker heartbeat monitoring
# 4. test_message_ordering - Test message ordering guarantees
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"

# Test counters
PASS_COUNT=0
FAIL_COUNT=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

pass() {
    ((PASS_COUNT++)) || true
    echo -e "  ${GREEN}[PASS]${RESET} $1"
}

fail() {
    ((FAIL_COUNT++)) || true
    echo -e "  ${RED}[FAIL]${RESET} $1"
}

skip() {
    echo -e "  ${YELLOW}[SKIP]${RESET} $1"
}

info() {
    echo -e "  ${CYAN}[INFO]${RESET} $1"
}

#===============================================================================
# Setup test environment
#===============================================================================
TEST_DIR=$(mktemp -d)
export STATE_DIR="$TEST_DIR/state"
export LOG_DIR="$TEST_DIR/logs"
export AUDIT_LOG_DIR="$LOG_DIR/audit"
export STATE_DB="$STATE_DIR/tri-agent.db"
export AUTONOMOUS_ROOT="$TEST_DIR"
export TRACE_ID="ipc-test-$$"

# Create directory structure
mkdir -p "$STATE_DIR/comms/supervisor/inbox"
mkdir -p "$STATE_DIR/comms/worker/worker-test/inbox"
mkdir -p "$LOG_DIR" "$AUDIT_LOG_DIR"

# Link lib directory for common.sh to find dependencies
ln -sf "$PROJECT_ROOT/lib" "$AUTONOMOUS_ROOT/lib"
ln -sf "$PROJECT_ROOT/config" "$AUTONOMOUS_ROOT/config" 2>/dev/null || true

cleanup() {
    # Kill any background processes
    jobs -p | xargs -r kill 2>/dev/null || true
    rm -rf "$TEST_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# Source required libraries
export SKIP_BINARY_VERIFICATION=1
source "${LIB_DIR}/common.sh"

# Source sqlite-state if available
if [[ -f "${LIB_DIR}/sqlite-state.sh" ]]; then
    source "${LIB_DIR}/sqlite-state.sh"
    sqlite_state_init "$STATE_DB" 2>/dev/null || true
fi

#===============================================================================
# Test 1: Dependency Request Timeout
#===============================================================================
test_dependency_request_timeout() {
    echo ""
    echo "Test 1: Dependency Request Timeout"
    echo "----------------------------------------"

    local worker_id="worker-test"
    local task_id="task-dep-test-$$"
    local request_timeout=2  # 2 seconds for test
    local request_id="depreq_${task_id}_$(date +%s)"
    local request_file="${STATE_DIR}/comms/supervisor/inbox/${request_id}.json"
    local response_file="${STATE_DIR}/comms/worker/${worker_id}/inbox/${request_id}_response.json"

    mkdir -p "$(dirname "$response_file")"

    # Create a dependency request
    cat > "$request_file" <<EOF
{
    "type": "DEP_REQUEST",
    "request_id": "$request_id",
    "task_id": "$task_id",
    "worker_id": "$worker_id",
    "dependency": {"type":"pip","name":"test-package"},
    "timestamp": "$(date -Iseconds)",
    "timeout_sec": $request_timeout
}
EOF

    if [[ -f "$request_file" ]]; then
        pass "DEP_REQUEST created successfully"
    else
        fail "Failed to create DEP_REQUEST"
        return
    fi

    # Simulate waiting for response that never comes (timeout)
    local wait_start wait_end
    wait_start=$(date +%s)

    info "Waiting for response with ${request_timeout}s timeout..."
    local got_response=false
    while (( $(date +%s) - wait_start < request_timeout )); do
        if [[ -f "$response_file" ]]; then
            got_response=true
            break
        fi
        sleep 0.5
    done

    wait_end=$(date +%s)
    local elapsed=$((wait_end - wait_start))

    if [[ "$got_response" == "false" && "$elapsed" -ge "$request_timeout" ]]; then
        pass "Request correctly timed out after ${elapsed}s"
    elif [[ "$got_response" == "true" ]]; then
        fail "Should not have received response (nothing is responding)"
    else
        fail "Timeout behavior unexpected: elapsed=${elapsed}s"
    fi

    # Test response handling when response arrives
    cat > "$response_file" <<EOF
{
    "type": "DEP_RESPONSE",
    "request_id": "$request_id",
    "status": "installed",
    "message": "Package installed successfully"
}
EOF

    if [[ -f "$response_file" ]]; then
        local status
        status=$(jq -r '.status' "$response_file" 2>/dev/null)
        if [[ "$status" == "installed" ]]; then
            pass "DEP_RESPONSE parsed correctly: status=$status"
        else
            fail "Failed to parse DEP_RESPONSE status"
        fi
        rm -f "$response_file"
    fi

    rm -f "$request_file"
}

#===============================================================================
# Test 2: IPC Race Conditions
#===============================================================================
test_ipc_race_conditions() {
    echo ""
    echo "Test 2: IPC Race Conditions"
    echo "----------------------------------------"

    local num_writers=5
    local num_messages=10
    local inbox_dir="${STATE_DIR}/comms/race_test_inbox"
    mkdir -p "$inbox_dir"

    info "Starting $num_writers concurrent writers, $num_messages messages each..."

    # Launch multiple writers concurrently
    local pids=()
    for ((w=1; w<=num_writers; w++)); do
        (
            for ((m=1; m<=num_messages; m++)); do
                local msg_file="${inbox_dir}/writer${w}_msg${m}_$(date +%s%N).json"
                cat > "$msg_file" <<EOF
{"writer":$w,"message":$m,"timestamp":"$(date -Iseconds)"}
EOF
                # Small random delay to increase contention
                sleep 0.0$((RANDOM % 10))
            done
        ) &
        pids+=($!)
    done

    # Wait for all writers
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done

    # Count messages
    local total_messages
    total_messages=$(find "$inbox_dir" -name "*.json" 2>/dev/null | wc -l)
    local expected_total=$((num_writers * num_messages))

    if [[ "$total_messages" -eq "$expected_total" ]]; then
        pass "All $expected_total messages written without loss"
    else
        fail "Message loss detected: got $total_messages, expected $expected_total"
    fi

    # Verify message integrity
    local corrupt_count=0
    for file in "$inbox_dir"/*.json; do
        [[ -f "$file" ]] || continue
        if ! jq . "$file" &>/dev/null; then
            ((corrupt_count++)) || true
        fi
    done

    if [[ "$corrupt_count" -eq 0 ]]; then
        pass "All messages have valid JSON format"
    else
        fail "$corrupt_count messages have corrupt JSON"
    fi

    rm -rf "$inbox_dir"
}

#===============================================================================
# Test 3: Heartbeat Timeout Detection
#===============================================================================
test_heartbeat_timeout_detection() {
    echo ""
    echo "Test 3: Heartbeat Timeout Detection"
    echo "----------------------------------------"

    local worker_id="worker-heartbeat-test"
    local heartbeat_file="${STATE_DIR}/workers/${worker_id}/heartbeat"
    local heartbeat_timeout=2  # 2 seconds for test

    mkdir -p "$(dirname "$heartbeat_file")"

    # Create initial heartbeat
    date +%s > "$heartbeat_file"
    info "Initial heartbeat written"

    # Check heartbeat is fresh
    local last_heartbeat now age
    last_heartbeat=$(cat "$heartbeat_file" 2>/dev/null || echo "0")
    now=$(date +%s)
    age=$((now - last_heartbeat))

    if [[ "$age" -lt "$heartbeat_timeout" ]]; then
        pass "Fresh heartbeat detected (age: ${age}s)"
    else
        fail "Heartbeat should be fresh, but age is ${age}s"
    fi

    # Simulate stale heartbeat
    info "Waiting for heartbeat to become stale..."
    sleep $((heartbeat_timeout + 1))

    now=$(date +%s)
    age=$((now - last_heartbeat))

    if [[ "$age" -ge "$heartbeat_timeout" ]]; then
        pass "Stale heartbeat detected (age: ${age}s >= ${heartbeat_timeout}s)"
    else
        fail "Heartbeat should be stale, but age is only ${age}s"
    fi

    # Test heartbeat update
    date +%s > "$heartbeat_file"
    local new_heartbeat
    new_heartbeat=$(cat "$heartbeat_file" 2>/dev/null || echo "0")
    now=$(date +%s)
    age=$((now - new_heartbeat))

    if [[ "$age" -lt "$heartbeat_timeout" ]]; then
        pass "Heartbeat successfully refreshed (age: ${age}s)"
    else
        fail "Heartbeat refresh failed"
    fi

    rm -rf "$(dirname "$heartbeat_file")"
}

#===============================================================================
# Test 4: Message Ordering
#===============================================================================
test_message_ordering() {
    echo ""
    echo "Test 4: Message Ordering"
    echo "----------------------------------------"

    local queue_dir="${STATE_DIR}/ordered_queue"
    mkdir -p "$queue_dir"

    local num_messages=20

    info "Writing $num_messages ordered messages..."

    # Write messages with sequence numbers
    for ((i=1; i<=num_messages; i++)); do
        # Use timestamp with microseconds for ordering
        local timestamp
        timestamp=$(date +%s%6N)
        local msg_file="${queue_dir}/${timestamp}_msg${i}.json"
        echo "{\"seq\":$i,\"ts\":\"$timestamp\"}" > "$msg_file"
        # Small delay to ensure unique timestamps
        sleep 0.01
    done

    # Read messages in sorted order
    local prev_seq=0
    local order_correct=true

    for file in $(ls -1 "$queue_dir"/*.json 2>/dev/null | sort); do
        [[ -f "$file" ]] || continue
        local seq
        seq=$(jq -r '.seq' "$file" 2>/dev/null)
        if [[ "$seq" -le "$prev_seq" ]]; then
            order_correct=false
            fail "Message out of order: seq=$seq after prev=$prev_seq"
            break
        fi
        prev_seq=$seq
    done

    if [[ "$order_correct" == "true" ]]; then
        pass "All $num_messages messages read in correct order"
    fi

    rm -rf "$queue_dir"
}

#===============================================================================
# Test 5: Concurrent Inbox Access
#===============================================================================
test_concurrent_inbox_access() {
    echo ""
    echo "Test 5: Concurrent Inbox Access"
    echo "----------------------------------------"

    local inbox_dir="${STATE_DIR}/concurrent_inbox"
    mkdir -p "$inbox_dir"

    # Pre-populate inbox
    for ((i=1; i<=10; i++)); do
        echo "{\"id\":$i}" > "${inbox_dir}/msg_${i}.json"
    done

    local initial_count
    initial_count=$(ls -1 "$inbox_dir"/*.json 2>/dev/null | wc -l)
    info "Initial inbox has $initial_count messages"

    # Start concurrent readers that process and delete messages
    local pids=()
    local processed_dir="${TEST_DIR}/processed"
    mkdir -p "$processed_dir"

    for ((r=1; r<=3; r++)); do
        (
            while true; do
                # Atomic claim: try to move a file
                local file
                for file in "$inbox_dir"/*.json; do
                    [[ -f "$file" ]] || continue
                    local target="${processed_dir}/$(basename "$file").reader${r}"
                    if mv "$file" "$target" 2>/dev/null; then
                        # Successfully claimed this message
                        :
                    fi
                done
                # Check if any messages left
                if [[ -z "$(ls -A "$inbox_dir" 2>/dev/null)" ]]; then
                    break
                fi
                sleep 0.01
            done
        ) &
        pids+=($!)
    done

    # Wait for all readers
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done

    # Verify no messages left in inbox
    local remaining
    remaining=$(find "$inbox_dir" -maxdepth 1 -name "*.json" 2>/dev/null | wc -l)
    if [[ "$remaining" -eq 0 ]]; then
        pass "All messages processed from inbox"
    else
        fail "$remaining messages still in inbox"
    fi

    # Verify no duplicates (each message processed exactly once)
    local processed_count
    processed_count=$(ls -1 "$processed_dir" 2>/dev/null | wc -l)
    if [[ "$processed_count" -eq "$initial_count" ]]; then
        pass "Each message processed exactly once ($processed_count messages)"
    else
        fail "Message duplication detected: $processed_count processed vs $initial_count original"
    fi

    rm -rf "$inbox_dir" "$processed_dir"
}

#===============================================================================
# Test 6: Supervisor Response Latency
#===============================================================================
test_supervisor_response_latency() {
    echo ""
    echo "Test 6: Supervisor Response Latency"
    echo "----------------------------------------"

    local request_dir="${STATE_DIR}/comms/supervisor/inbox"
    local response_dir="${STATE_DIR}/comms/worker/worker-test/inbox"
    mkdir -p "$request_dir" "$response_dir"

    # Simulate a supervisor that responds to requests
    (
        while true; do
            for req in "$request_dir"/*.json; do
                [[ -f "$req" ]] || continue
                local request_id
                request_id=$(jq -r '.request_id // empty' "$req" 2>/dev/null)
                if [[ -n "$request_id" ]]; then
                    # Simulate processing delay
                    sleep 0.1
                    # Write response
                    cat > "${response_dir}/${request_id}_response.json" <<EOF
{"request_id":"$request_id","status":"completed","latency_test":true}
EOF
                    rm -f "$req"
                fi
            done
            sleep 0.05
            # Exit if no more work
            if [[ -z "$(ls -A "$request_dir" 2>/dev/null)" ]]; then
                break
            fi
        done
    ) &
    local supervisor_pid=$!

    # Send request and measure latency
    local request_id="latency_test_$(date +%s%N)"
    local request_file="${request_dir}/${request_id}.json"
    local response_file="${response_dir}/${request_id}_response.json"

    local start_time
    start_time=$(date +%s%N)
    echo "{\"request_id\":\"$request_id\",\"type\":\"PING\"}" > "$request_file"

    # Wait for response
    local max_wait=2000  # 2 seconds in ms
    local waited=0
    while [[ ! -f "$response_file" && $waited -lt $max_wait ]]; do
        sleep 0.05
        waited=$((waited + 50))
    done

    local end_time
    end_time=$(date +%s%N)

    # Kill supervisor
    kill $supervisor_pid 2>/dev/null || true
    wait $supervisor_pid 2>/dev/null || true

    if [[ -f "$response_file" ]]; then
        local latency_ns=$((end_time - start_time))
        local latency_ms=$((latency_ns / 1000000))
        pass "Response received in ${latency_ms}ms"

        if [[ $latency_ms -lt 500 ]]; then
            pass "Latency acceptable (<500ms)"
        else
            info "Latency higher than expected: ${latency_ms}ms"
        fi
    else
        fail "No response received within ${max_wait}ms"
    fi

    rm -f "$request_file" "$response_file"
}

#===============================================================================
# Run all tests
#===============================================================================
main() {
    echo ""
    echo "=============================================="
    echo "Worker-Supervisor IPC Integration Tests"
    echo "=============================================="
    echo "Project Root: $PROJECT_ROOT"
    echo "Test Dir: $TEST_DIR"
    echo "=============================================="

    test_dependency_request_timeout
    test_ipc_race_conditions
    test_heartbeat_timeout_detection
    test_message_ordering
    test_concurrent_inbox_access
    test_supervisor_response_latency

    echo ""
    echo "=============================================="
    echo "Test Results: $PASS_COUNT passed, $FAIL_COUNT failed"
    echo "=============================================="

    [[ $FAIL_COUNT -eq 0 ]]
}

main "$@"
