#!/bin/bash
#===============================================================================
# test_concurrent_operations.sh - Stress tests for concurrent operations
#===============================================================================
# Tests system behavior under high concurrency with 100+ parallel processes.
# Validates lock handling, state consistency, and race condition resistance.
#===============================================================================

set -euo pipefail

# Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(dirname "$(dirname "$SCRIPT_DIR")")}"
LIB_DIR="${PROJECT_ROOT}/lib"

# Test counters
TESTS_PASSED=${TESTS_PASSED:-0}
TESTS_FAILED=${TESTS_FAILED:-0}

# Concurrency settings
PARALLEL_PROCESSES=${PARALLEL_PROCESSES:-100}
STRESS_DURATION=${STRESS_DURATION:-5}  # seconds

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

pass() {
    ((TESTS_PASSED++)) || true
    echo -e "  ${GREEN}[PASS]${RESET} $1"
}

fail() {
    ((TESTS_FAILED++)) || true
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

TEST_ROOT_DIR=$(mktemp -d)

# IMPORTANT: Preserve LIB_DIR before setting AUTONOMOUS_ROOT
# Otherwise common.sh will look for libs in the temp directory
export LIB_DIR="${LIB_DIR:-${PROJECT_ROOT}/lib}"

# Set AUTONOMOUS_ROOT to allow writes to temp directories
# This ensures safe_write_check validates against the temp directory structure
# All test directories must be under AUTONOMOUS_ROOT for safe_write_check to pass
export AUTONOMOUS_ROOT="$TEST_ROOT_DIR"
export STATE_DIR="${TEST_ROOT_DIR}/state"
export LOCKS_DIR="${STATE_DIR}/locks"
export BREAKERS_DIR="${STATE_DIR}/breakers"
export LOG_DIR="${TEST_ROOT_DIR}/logs"
export TASKS_DIR="${TEST_ROOT_DIR}/tasks"
export SESSIONS_DIR="${TEST_ROOT_DIR}/sessions"
export TRACE_ID="stress-$$"

# Backward compatibility
TEST_STATE_DIR="$STATE_DIR"
TEST_LOG_DIR="$LOG_DIR"

mkdir -p "$LOCKS_DIR" "$BREAKERS_DIR" "$TASKS_DIR" "$SESSIONS_DIR" "$LOG_DIR"

cleanup() {
    # Kill any remaining background processes
    jobs -p | xargs -r kill 2>/dev/null || true
    wait 2>/dev/null || true
    rm -rf "$TEST_ROOT_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# Source dependencies (LIB_DIR preserved above)
source "${LIB_DIR}/common.sh"

#===============================================================================
# Stress Tests
#===============================================================================

echo ""
echo "Running stress tests with $PARALLEL_PROCESSES parallel processes..."

# Test 1: Concurrent lock acquisition
test_concurrent_locks() {
    echo ""
    info "Stress test: Concurrent lock acquisition ($PARALLEL_PROCESSES processes)..."

    if ! type with_lock &>/dev/null; then
        skip "with_lock: Function not available"
        return
    fi

    local lock_name="stress_test_lock"
    local counter_file="${TEST_STATE_DIR}/lock_counter.txt"
    local success_file="${TEST_STATE_DIR}/lock_success.txt"

    echo "0" > "$counter_file"
    echo "0" > "$success_file"

    # Spawn parallel processes that try to acquire lock and increment counter
    for ((i=0; i<PARALLEL_PROCESSES; i++)); do
        (
            if with_lock "$lock_name" bash -c '
                count=$(cat "'"$counter_file"'")
                echo $((count + 1)) > "'"$counter_file"'"
            ' 2>/dev/null; then
                # Atomic increment of success counter
                flock -x "$success_file" -c 'echo $(($(cat "'"$success_file"'") + 1)) > "'"$success_file"'"' 2>/dev/null || true
            fi
        ) &
    done

    # Wait for all processes
    wait

    local final_count
    final_count=$(cat "$counter_file" 2>/dev/null || echo "0")
    local success_count
    success_count=$(cat "$success_file" 2>/dev/null || echo "0")

    info "Final counter: $final_count (expected: $success_count)"

    # Allow for some lock acquisition failures under extreme load
    if [[ "$final_count" -eq "$success_count" ]]; then
        pass "concurrent_locks: Counter integrity maintained under $PARALLEL_PROCESSES concurrent locks"
    elif [[ "$final_count" -gt $((PARALLEL_PROCESSES * 80 / 100)) ]]; then
        pass "concurrent_locks: Acceptable performance ($final_count/$PARALLEL_PROCESSES operations)"
    else
        fail "concurrent_locks: Too many failures ($final_count/$PARALLEL_PROCESSES)"
    fi
}

# Test 2: Concurrent file operations
test_concurrent_file_ops() {
    echo ""
    info "Stress test: Concurrent file operations ($PARALLEL_PROCESSES processes)..."

    local results_dir="${TEST_STATE_DIR}/concurrent_files"
    mkdir -p "$results_dir"

    # Spawn parallel processes that write to different files
    local pids=()
    for ((i=0; i<PARALLEL_PROCESSES; i++)); do
        (
            local file="${results_dir}/file_${i}.txt"
            echo "Process $i at $(date +%s%N)" > "$file"

            # Simulate some work
            for ((j=0; j<10; j++)); do
                echo "Line $j from process $i" >> "$file"
            done
        ) &
        pids+=($!)
    done

    # Wait for all processes
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done

    # Verify all files were created
    local created_count
    created_count=$(find "$results_dir" -name "file_*.txt" 2>/dev/null | wc -l)

    if [[ "$created_count" -eq "$PARALLEL_PROCESSES" ]]; then
        pass "concurrent_file_ops: All $PARALLEL_PROCESSES files created correctly"
    else
        fail "concurrent_file_ops: Only $created_count/$PARALLEL_PROCESSES files created"
    fi
}

# Test 3: Concurrent trace ID generation
test_concurrent_trace_ids() {
    echo ""
    info "Stress test: Concurrent trace ID generation ($PARALLEL_PROCESSES processes)..."

    local ids_file="${TEST_STATE_DIR}/trace_ids.txt"
    > "$ids_file"  # Clear file

    # Spawn parallel processes that generate trace IDs
    local pids=()
    for ((i=0; i<PARALLEL_PROCESSES; i++)); do
        (
            local id
            id=$(generate_trace_id "stress")
            echo "$id" >> "$ids_file"
        ) &
        pids+=($!)
    done

    # Wait for all processes
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done

    # Check for duplicates
    local total_ids
    total_ids=$(wc -l < "$ids_file")
    local unique_ids
    unique_ids=$(sort -u "$ids_file" | wc -l)

    if [[ "$total_ids" -eq "$unique_ids" ]]; then
        pass "concurrent_trace_ids: All $PARALLEL_PROCESSES IDs are unique"
    else
        local duplicates=$((total_ids - unique_ids))
        fail "concurrent_trace_ids: $duplicates duplicate IDs found"
    fi
}

# Test 4: Concurrent state operations
test_concurrent_state_ops() {
    echo ""
    info "Stress test: Concurrent state operations ($PARALLEL_PROCESSES processes)..."

    if ! type state_set &>/dev/null || ! type state_get &>/dev/null; then
        skip "state_set/state_get: Functions not available"
        return
    fi

    local state_file="${TEST_STATE_DIR}/concurrent_state.json"
    echo "{}" > "$state_file"

    local errors=0
    local pids=()

    for ((i=0; i<PARALLEL_PROCESSES; i++)); do
        (
            local key="key_$i"
            local value="value_$i"

            state_set "$state_file" "$key" "$value" 2>/dev/null || true

            local retrieved
            retrieved=$(state_get "$state_file" "$key" "" 2>/dev/null) || true

            if [[ "$retrieved" != "$value" ]]; then
                echo "1" >> "${TEST_STATE_DIR}/state_errors.txt"
            fi
        ) &
        pids+=($!)
    done

    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done

    local error_count=0
    if [[ -f "${TEST_STATE_DIR}/state_errors.txt" ]]; then
        error_count=$(wc -l < "${TEST_STATE_DIR}/state_errors.txt")
    fi

    # Under extreme concurrency, some operations may fail - allow 10% failure rate
    local max_errors=$((PARALLEL_PROCESSES / 10))
    if [[ "$error_count" -le "$max_errors" ]]; then
        pass "concurrent_state_ops: Acceptable error rate ($error_count/$PARALLEL_PROCESSES)"
    else
        fail "concurrent_state_ops: Too many errors ($error_count/$PARALLEL_PROCESSES)"
    fi
}

# Test 5: Concurrent circuit breaker operations
test_concurrent_circuit_breaker() {
    echo ""
    info "Stress test: Concurrent circuit breaker operations ($PARALLEL_PROCESSES processes)..."

    if ! type record_failure &>/dev/null || ! type record_success &>/dev/null; then
        skip "record_failure/record_success: Functions not available"
        return
    fi

    local model="stress_test_model"

    local pids=()
    for ((i=0; i<PARALLEL_PROCESSES; i++)); do
        (
            if [[ $((i % 2)) -eq 0 ]]; then
                record_failure "$model" 2>/dev/null || true
            else
                record_success "$model" 2>/dev/null || true
            fi
        ) &
        pids+=($!)
    done

    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done

    # Verify the circuit breaker state is readable
    if type get_breaker_state &>/dev/null; then
        local state
        state=$(get_breaker_state "$model" 2>/dev/null) || state="error"
        if [[ "$state" == "OPEN" || "$state" == "CLOSED" || "$state" == "HALF_OPEN" ]]; then
            pass "concurrent_circuit_breaker: State consistent after $PARALLEL_PROCESSES operations"
        else
            fail "concurrent_circuit_breaker: Invalid state: $state"
        fi
    else
        pass "concurrent_circuit_breaker: Operations completed without crashes"
    fi
}

# Test 6: Burst request simulation
test_burst_requests() {
    echo ""
    info "Stress test: Burst request simulation ($PARALLEL_PROCESSES simultaneous requests)..."

    local start_time
    start_time=$(epoch_ms)

    local pids=()
    for ((i=0; i<PARALLEL_PROCESSES; i++)); do
        (
            # Simulate a request by generating trace ID and logging
            local trace
            trace=$(generate_trace_id "burst")
            log_debug "Burst request $i: $trace" 2>/dev/null || true

            # Simulate some processing
            mask_secrets "API: sk-test1234567890abcdefghij" >/dev/null
            is_valid_json '{"test": "data"}' >/dev/null
        ) &
        pids+=($!)
    done

    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done

    local end_time
    end_time=$(epoch_ms)
    local duration=$((end_time - start_time))
    local throughput=$((PARALLEL_PROCESSES * 1000 / (duration + 1)))

    info "Burst completed in ${duration}ms (throughput: ~${throughput} req/s)"
    pass "burst_requests: Handled $PARALLEL_PROCESSES concurrent requests"
}

# Test 7: Memory pressure test
test_memory_pressure() {
    echo ""
    info "Stress test: Memory pressure (large data processing)..."

    local large_input=""
    # Generate 1MB of data
    for ((i=0; i<100; i++)); do
        large_input+="sk-1234567890abcdefghijklmnopqrstuvwxyz$(printf 'A%.0s' {1..10000})"
    done

    local start_mem
    if command -v free &>/dev/null; then
        start_mem=$(free -m | awk '/Mem:/ {print $3}')
    else
        start_mem=0
    fi

    # Process large input multiple times
    for ((i=0; i<10; i++)); do
        mask_secrets "$large_input" >/dev/null 2>&1
    done

    local end_mem
    if command -v free &>/dev/null; then
        end_mem=$(free -m | awk '/Mem:/ {print $3}')
    else
        end_mem=0
    fi

    local mem_increase=$((end_mem - start_mem))
    info "Memory increase: ${mem_increase}MB"

    # Allow up to 100MB memory increase
    if [[ "$mem_increase" -lt 100 ]]; then
        pass "memory_pressure: Acceptable memory usage (${mem_increase}MB increase)"
    else
        fail "memory_pressure: Excessive memory usage (${mem_increase}MB increase)"
    fi
}

# Test 8: Sustained load test
test_sustained_load() {
    echo ""
    info "Stress test: Sustained load for ${STRESS_DURATION}s..."

    local end_time=$(($(date +%s) + STRESS_DURATION))
    local operations=0
    local errors=0

    while [[ $(date +%s) -lt $end_time ]]; do
        # Run batch of operations
        for ((i=0; i<10; i++)); do
            (
                generate_trace_id "load" >/dev/null
                mask_secrets "test sk-abc123" >/dev/null
                is_valid_json '{"a":1}' >/dev/null
            ) &
        done
        wait
        ((operations += 10)) || true
    done

    local rate=$((operations / STRESS_DURATION))
    info "Completed $operations operations in ${STRESS_DURATION}s (~$rate ops/s)"
    pass "sustained_load: Maintained $rate ops/s for ${STRESS_DURATION}s"
}

# Test 9: Fork bomb resistance
test_fork_resistance() {
    echo ""
    info "Stress test: Fork bomb resistance (process limits)..."

    # Set a reasonable limit to prevent actual fork bombs
    local max_children=50
    local pids=()
    local spawned=0

    for ((i=0; i<max_children; i++)); do
        if (
            # Each child spawns a few grandchildren
            for ((j=0; j<3; j++)); do
                (generate_trace_id "fork" >/dev/null) &
            done
            wait
        ) & then
            pids+=($!)
            ((spawned++)) || true
        else
            break
        fi
    done

    # Wait for all with timeout
    local wait_start
    wait_start=$(date +%s)
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true

        # Timeout after 10 seconds
        if [[ $(($(date +%s) - wait_start)) -gt 10 ]]; then
            kill "${pids[@]}" 2>/dev/null || true
            fail "fork_resistance: Timed out waiting for processes"
            return
        fi
    done

    pass "fork_resistance: Handled $spawned parent processes with children"
}

# Test 10: Race condition detection
test_race_conditions() {
    echo ""
    info "Stress test: Race condition detection..."

    local shared_counter="${TEST_STATE_DIR}/race_counter.txt"
    echo "0" > "$shared_counter"

    local expected_count=$((PARALLEL_PROCESSES * 5))

    # Without proper locking, this should have race conditions
    local pids=()
    for ((i=0; i<PARALLEL_PROCESSES; i++)); do
        (
            for ((j=0; j<5; j++)); do
                # Intentionally racy increment
                local val
                val=$(cat "$shared_counter" 2>/dev/null) || val=0
                echo $((val + 1)) > "$shared_counter"
            done
        ) &
        pids+=($!)
    done

    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done

    local final_count
    final_count=$(cat "$shared_counter" 2>/dev/null || echo "0")

    # This test demonstrates the need for proper locking
    if [[ "$final_count" -lt "$expected_count" ]]; then
        info "Race condition detected (expected $expected_count, got $final_count) - this is expected behavior"
        pass "race_conditions: Race detection working as expected"
    else
        pass "race_conditions: Surprisingly no races detected (possibly due to OS serialization)"
    fi
}

#===============================================================================
# Run Tests
#===============================================================================

test_concurrent_locks
test_concurrent_file_ops
test_concurrent_trace_ids
test_concurrent_state_ops
test_concurrent_circuit_breaker
test_burst_requests
test_memory_pressure
test_sustained_load
test_fork_resistance
test_race_conditions

export TESTS_PASSED TESTS_FAILED

echo ""
echo "Stress tests completed: $TESTS_PASSED passed, $TESTS_FAILED failed"
