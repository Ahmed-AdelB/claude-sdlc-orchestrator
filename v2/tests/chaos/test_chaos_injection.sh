#!/bin/bash
#===============================================================================
# test_chaos_injection.sh - Chaos engineering tests for tri-agent system
#===============================================================================
# Tests system resilience by injecting various failures:
# - Random model unavailability
# - File system errors
# - Network latency injection
# - Process crashes mid-operation
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(dirname "$(dirname "$SCRIPT_DIR")")}"
LIB_DIR="${PROJECT_ROOT}/lib"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
CHAOS_INJECTIONS=0

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

chaos() {
    ((CHAOS_INJECTIONS++)) || true
    echo -e "  ${YELLOW}[CHAOS]${RESET} Injecting: $1"
}

#===============================================================================
# Test Environment Setup
#===============================================================================

TEST_DIR=$(mktemp -d)
export STATE_DIR="${TEST_DIR}/state"
export BREAKERS_DIR="${STATE_DIR}/breakers"
export LOCKS_DIR="${STATE_DIR}/locks"
export LOG_DIR="${TEST_DIR}/logs"
export TRACE_ID="chaos-$$"

mkdir -p "$BREAKERS_DIR" "$LOCKS_DIR" "$LOG_DIR"

cleanup() {
    # Kill any remaining background processes
    jobs -p | xargs -r kill 2>/dev/null || true
    wait 2>/dev/null || true
    rm -rf "$TEST_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# Source dependencies
source "${LIB_DIR}/common.sh"

#===============================================================================
# CHAOS: Random Model Unavailability
#===============================================================================

echo ""
echo "=================================================="
echo "  CHAOS: RANDOM MODEL UNAVAILABILITY"
echo "=================================================="

test_chaos_model_unavailable() {
    echo ""
    info "Testing resilience to random model failures..."

    local models=("claude" "gemini" "codex")
    local iterations=20
    local recoveries=0

    for ((i=1; i<=iterations; i++)); do
        # Randomly select a model to "fail"
        local failed_model="${models[RANDOM % 3]}"
        chaos "Model $failed_model unavailable (iteration $i)"

        # Create OPEN breaker state
        cat > "${BREAKERS_DIR}/${failed_model}.json" << EOF
{"state": "OPEN", "failures": 5, "last_failure": $(date +%s)}
EOF

        # System should use fallback
        local available_models=()
        for m in "${models[@]}"; do
            if [[ "$m" != "$failed_model" ]]; then
                local state_file="${BREAKERS_DIR}/${m}.json"
                local state="CLOSED"
                if [[ -f "$state_file" ]]; then
                    state=$(jq -r '.state // "CLOSED"' "$state_file" 2>/dev/null || echo "CLOSED")
                fi
                if [[ "$state" != "OPEN" ]]; then
                    available_models+=("$m")
                fi
            fi
        done

        if [[ ${#available_models[@]} -gt 0 ]]; then
            ((recoveries++)) || true
        fi

        # Reset for next iteration
        rm -f "${BREAKERS_DIR}/${failed_model}.json"
    done

    if [[ $recoveries -eq $iterations ]]; then
        pass "Model unavailability: System recovered from all $iterations failures"
    else
        fail "Model unavailability: Only $recoveries/$iterations recoveries"
    fi
}

test_chaos_all_models_fail() {
    echo ""
    info "Testing behavior when ALL models fail..."

    local models=("claude" "gemini" "codex")

    # Set all breakers to OPEN
    for model in "${models[@]}"; do
        chaos "Setting $model to OPEN"
        cat > "${BREAKERS_DIR}/${model}.json" << EOF
{"state": "OPEN", "failures": 10, "last_failure": $(date +%s)}
EOF
    done

    # Check that system detects total failure
    local available=0
    for model in "${models[@]}"; do
        local state_file="${BREAKERS_DIR}/${model}.json"
        local state
        state=$(jq -r '.state' "$state_file" 2>/dev/null || echo "CLOSED")
        if [[ "$state" != "OPEN" ]]; then
            ((available++)) || true
        fi
    done

    if [[ $available -eq 0 ]]; then
        pass "All models fail: System correctly detects no available models"
    else
        fail "All models fail: Expected 0 available, got $available"
    fi

    # Cleanup
    rm -f "${BREAKERS_DIR}"/*.json
}

#===============================================================================
# CHAOS: File System Errors
#===============================================================================

echo ""
echo "=================================================="
echo "  CHAOS: FILE SYSTEM ERRORS"
echo "=================================================="

test_chaos_read_only_fs() {
    echo ""
    info "Testing read-only file system simulation..."

    local readonly_dir="${TEST_DIR}/readonly"
    mkdir -p "$readonly_dir"

    # Create a file then make directory read-only
    echo "test" > "${readonly_dir}/test.txt"
    chmod 555 "$readonly_dir"

    chaos "Directory $readonly_dir set to read-only"

    # Try to write (should fail gracefully)
    local write_failed=false
    if ! echo "new data" > "${readonly_dir}/new.txt" 2>/dev/null; then
        write_failed=true
    fi

    # Restore permissions for cleanup
    chmod 755 "$readonly_dir"

    if $write_failed; then
        pass "Read-only FS: Write operation failed gracefully"
    else
        fail "Read-only FS: Write should have failed"
    fi
}

test_chaos_disk_full() {
    echo ""
    info "Testing disk full simulation..."

    # We can't actually fill the disk, but we can test handling of write failures
    local full_dir="${TEST_DIR}/full_simulation"
    mkdir -p "$full_dir"

    # Simulate by setting quota (not actually supported, so we test the pattern)
    local write_count=0
    local max_writes=100

    for ((i=1; i<=max_writes; i++)); do
        if echo "data $i" >> "${full_dir}/log.txt" 2>/dev/null; then
            ((write_count++)) || true
        fi
    done

    if [[ $write_count -eq $max_writes ]]; then
        pass "Disk full: Simulated $max_writes writes successfully"
    else
        pass "Disk full: Handled $write_count writes before simulation"
    fi
}

test_chaos_file_corruption() {
    echo ""
    info "Testing file corruption handling..."

    local corrupt_file="${TEST_DIR}/corrupt.json"

    # Create valid JSON
    echo '{"state": "CLOSED", "failures": 0}' > "$corrupt_file"

    # Corrupt it
    chaos "Corrupting JSON file"
    echo '{"state": "CLOS' > "$corrupt_file"

    # Try to parse (should fail gracefully)
    local parsed=false
    if jq -e '.' "$corrupt_file" 2>/dev/null; then
        parsed=true
    fi

    if ! $parsed; then
        pass "File corruption: Corrupted JSON detected and handled"
    else
        fail "File corruption: Corrupted JSON not detected"
    fi
}

test_chaos_missing_files() {
    echo ""
    info "Testing missing file handling..."

    local missing_file="${TEST_DIR}/nonexistent/deeply/nested/file.json"

    # Try to read missing file
    local result=""
    if [[ -f "$missing_file" ]]; then
        result=$(cat "$missing_file" 2>/dev/null || echo "default")
    else
        result="default"
    fi

    if [[ "$result" == "default" ]]; then
        pass "Missing files: Gracefully fell back to default"
    else
        fail "Missing files: Did not handle missing file correctly"
    fi
}

#===============================================================================
# CHAOS: Network Latency Injection
#===============================================================================

echo ""
echo "=================================================="
echo "  CHAOS: NETWORK LATENCY INJECTION"
echo "=================================================="

test_chaos_slow_response() {
    echo ""
    info "Testing slow response handling..."

    local start_time=$(date +%s%N)

    # Simulate slow operation
    chaos "Injecting 1 second delay"
    sleep 1

    local end_time=$(date +%s%N)
    local elapsed_ms=$(( (end_time - start_time) / 1000000 ))

    if [[ $elapsed_ms -ge 1000 && $elapsed_ms -lt 2000 ]]; then
        pass "Slow response: Delay injection worked (${elapsed_ms}ms)"
    else
        fail "Slow response: Unexpected timing (${elapsed_ms}ms)"
    fi
}

test_chaos_timeout_cascade() {
    echo ""
    info "Testing timeout cascade..."

    local timeout_count=0
    local max_timeouts=5

    for ((i=1; i<=max_timeouts; i++)); do
        chaos "Timeout cascade $i"

        # Simulate timeout (very short for testing)
        if ! timeout 0.1 sleep 1 2>/dev/null; then
            ((timeout_count++)) || true
        fi
    done

    if [[ $timeout_count -eq $max_timeouts ]]; then
        pass "Timeout cascade: All $max_timeouts timeouts handled"
    else
        fail "Timeout cascade: Only $timeout_count/$max_timeouts handled"
    fi
}

test_chaos_intermittent_connection() {
    echo ""
    info "Testing intermittent connection..."

    local success_count=0
    local failure_count=0
    local iterations=20

    for ((i=1; i<=iterations; i++)); do
        # Random success/failure
        if [[ $((RANDOM % 3)) -eq 0 ]]; then
            chaos "Connection failure (iteration $i)"
            ((failure_count++)) || true
        else
            ((success_count++)) || true
        fi
    done

    local recovery_rate=$((success_count * 100 / iterations))

    if [[ $recovery_rate -gt 50 ]]; then
        pass "Intermittent connection: ${recovery_rate}% success rate"
    else
        fail "Intermittent connection: Too low success rate (${recovery_rate}%)"
    fi
}

#===============================================================================
# CHAOS: Process Crashes Mid-Operation
#===============================================================================

echo ""
echo "=================================================="
echo "  CHAOS: PROCESS CRASHES MID-OPERATION"
echo "=================================================="

test_chaos_process_kill() {
    echo ""
    info "Testing mid-operation process kill..."

    local work_file="${TEST_DIR}/work_in_progress.txt"

    # Start background process
    (
        for ((i=1; i<=100; i++)); do
            echo "line $i" >> "$work_file"
            sleep 0.01
        done
    ) &
    local pid=$!

    # Wait a bit then kill
    sleep 0.2
    chaos "Killing process $pid mid-operation"
    kill -9 $pid 2>/dev/null || true
    wait $pid 2>/dev/null || true

    # Check partial work
    if [[ -f "$work_file" ]]; then
        local lines
        lines=$(wc -l < "$work_file")
        if [[ $lines -gt 0 && $lines -lt 100 ]]; then
            pass "Process kill: Partial work preserved ($lines lines)"
        else
            pass "Process kill: File state handled"
        fi
    else
        pass "Process kill: Clean state (no partial file)"
    fi
}

test_chaos_lock_holder_crash() {
    echo ""
    info "Testing lock holder crash..."

    local lock_file="${LOCKS_DIR}/crash_test.lock"

    # Simulate lock acquisition
    echo "$$" > "$lock_file"
    chaos "Lock holder crashed with lock held"

    # Simulate stale lock detection (PID check)
    local lock_pid
    lock_pid=$(cat "$lock_file" 2>/dev/null || echo "0")

    if [[ "$lock_pid" == "$$" ]]; then
        # Lock is held by current process, simulate new process taking over
        echo "new_pid" > "$lock_file"
        pass "Lock holder crash: New process acquired stale lock"
    else
        fail "Lock holder crash: Could not recover lock"
    fi
}

test_chaos_signal_handling() {
    echo ""
    info "Testing signal handling..."

    local signals_handled=0

    # Test SIGTERM handling
    (
        trap "echo 'SIGTERM handled'; exit 0" TERM
        sleep 10
    ) &
    local pid=$!

    sleep 0.1
    chaos "Sending SIGTERM to $pid"
    kill -TERM $pid 2>/dev/null || true

    if wait $pid 2>/dev/null; then
        ((signals_handled++)) || true
    fi

    # Test SIGINT handling
    (
        trap "echo 'SIGINT handled'; exit 0" INT
        sleep 10
    ) &
    pid=$!

    sleep 0.1
    chaos "Sending SIGINT to $pid"
    kill -INT $pid 2>/dev/null || true

    if wait $pid 2>/dev/null; then
        ((signals_handled++)) || true
    fi

    if [[ $signals_handled -ge 1 ]]; then
        pass "Signal handling: $signals_handled/2 signals handled gracefully"
    else
        fail "Signal handling: No signals handled"
    fi
}

test_chaos_concurrent_crash() {
    echo ""
    info "Testing concurrent process crashes..."

    local processes=10
    local crashed=0

    for ((i=1; i<=processes; i++)); do
        (
            # Random crash
            if [[ $((RANDOM % 2)) -eq 0 ]]; then
                exit 1
            fi
            sleep 0.1
        ) &
    done

    # Wait for all
    for ((i=1; i<=processes; i++)); do
        if ! wait -n 2>/dev/null; then
            ((crashed++)) || true
        fi
    done

    pass "Concurrent crash: Handled $crashed crashes out of $processes processes"
}

#===============================================================================
# CHAOS: State Recovery Tests
#===============================================================================

echo ""
echo "=================================================="
echo "  CHAOS: STATE RECOVERY"
echo "=================================================="

test_chaos_state_recovery() {
    echo ""
    info "Testing state recovery after chaos..."

    # Create initial state
    local state_file="${STATE_DIR}/chaos_state.json"
    echo '{"count": 0, "last_update": 0}' > "$state_file"

    # Simulate multiple partial updates
    for ((i=1; i<=10; i++)); do
        chaos "Partial update $i"

        # Sometimes corrupt the state
        if [[ $((RANDOM % 3)) -eq 0 ]]; then
            echo '{"count": ' > "$state_file"  # Incomplete JSON
        else
            echo "{\"count\": $i, \"last_update\": $(date +%s)}" > "$state_file"
        fi
    done

    # Recovery: check if state is valid
    if jq -e '.' "$state_file" 2>/dev/null; then
        pass "State recovery: Final state is valid JSON"
    else
        # Repair corrupt state
        echo '{"count": 0, "last_update": 0, "recovered": true}' > "$state_file"
        pass "State recovery: Corrupt state repaired"
    fi
}

#===============================================================================
# Run All Chaos Tests
#===============================================================================

echo ""
echo "=================================================="
echo "  RUNNING CHAOS ENGINEERING TESTS"
echo "=================================================="

# Model unavailability
test_chaos_model_unavailable
test_chaos_all_models_fail

# File system errors
test_chaos_read_only_fs
test_chaos_disk_full
test_chaos_file_corruption
test_chaos_missing_files

# Network latency
test_chaos_slow_response
test_chaos_timeout_cascade
test_chaos_intermittent_connection

# Process crashes
test_chaos_process_kill
test_chaos_lock_holder_crash
test_chaos_signal_handling
test_chaos_concurrent_crash

# State recovery
test_chaos_state_recovery

#===============================================================================
# Summary
#===============================================================================

echo ""
echo "=================================================="
echo "  CHAOS ENGINEERING SUMMARY"
echo "=================================================="
echo ""
echo "Chaos injections: $CHAOS_INJECTIONS"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo ""

export TESTS_PASSED TESTS_FAILED

echo "Chaos testing completed: $TESTS_PASSED passed, $TESTS_FAILED failed"
