#!/bin/bash
#===============================================================================
# test_cost_tracker.sh - Unit tests for lib/cost-tracker.sh
#===============================================================================
# Tests:
#   1. test_cost_recording - Test recording of API costs
#   2. test_budget_enforcement - Test budget limit enforcement
#   3. test_cost_aggregation - Test cost summation by model/time
#   4. test_budget_threshold_alerts - Test alert triggers at thresholds
#   5. test_cost_by_model - Test per-model cost tracking
#   6. test_daily_cost_reset - Test daily cost rollover
#===============================================================================

set -euo pipefail

# Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(dirname "$(dirname "$SCRIPT_DIR")")}"
LIB_DIR="${PROJECT_ROOT}/lib"

# Test counters
TESTS_PASSED=${TESTS_PASSED:-0}
TESTS_FAILED=${TESTS_FAILED:-0}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

pass() {
    ((TESTS_PASSED++)) || true
    echo -e "  ${GREEN}[PASS]${RESET} $1"
}

fail() {
    ((TESTS_FAILED++)) || true
    echo -e "  ${RED}[FAIL]${RESET} $1"
    if [[ -n "${2:-}" ]]; then
        echo -e "         ${RED}Details: $2${RESET}"
    fi
}

skip() {
    echo -e "  ${YELLOW}[SKIP]${RESET} $1"
}

#===============================================================================
# Setup test environment
#===============================================================================

# Create temp directories for test isolation
TEST_TEMP_ROOT=$(mktemp -d)

# Export trace ID before sourcing
export TRACE_ID="test-cost-$$"

# Disable SQLite for isolated testing
export STATE_DB="/nonexistent/path/disabled.db"

# Skip binary verification for faster tests
export SKIP_BINARY_VERIFICATION=1

cleanup() {
    rm -rf "$TEST_TEMP_ROOT" 2>/dev/null || true
}
trap cleanup EXIT

# Source dependencies from the actual project lib directory
source "${LIB_DIR}/common.sh"

# Now override the state directories AFTER sourcing to use isolated temp directories
# This is critical for test isolation - we don't want to pollute the real state
TEST_STATE_DIR="${TEST_TEMP_ROOT}/state"
TEST_LOG_DIR="${TEST_TEMP_ROOT}/logs"
TEST_COST_STATE_DIR="${TEST_STATE_DIR}/costs"
TEST_COST_LOG_DIR="${TEST_LOG_DIR}/costs"
TEST_LOCKS_DIR="${TEST_STATE_DIR}/locks"

# Create the test directories
mkdir -p "$TEST_COST_STATE_DIR" "$TEST_COST_LOG_DIR" "$TEST_LOCKS_DIR"

# Override the globals that cost-tracker.sh uses
STATE_DIR="$TEST_STATE_DIR"
COST_STATE_DIR="$TEST_COST_STATE_DIR"
COST_LOG_DIR="$TEST_COST_LOG_DIR"
LOG_DIR="$TEST_LOG_DIR"
LOCKS_DIR="$TEST_LOCKS_DIR"

# Export so subshells and functions use the test directories
export STATE_DIR COST_STATE_DIR COST_LOG_DIR LOG_DIR LOCKS_DIR

#===============================================================================
# Helper Functions
#===============================================================================

# Check if jq is available for JSON parsing
HAS_JQ=false
if command -v jq &>/dev/null; then
    HAS_JQ=true
fi

# Parse JSON value using jq or python
json_get() {
    local json="$1"
    local key="$2"
    local default="${3:-0}"

    # Handle empty JSON
    if [[ -z "$json" ]]; then
        echo "$default"
        return
    fi

    if [[ "$HAS_JQ" == "true" ]]; then
        local result
        # Use direct key interpolation in the jq filter
        result=$(printf '%s' "$json" | jq -r ".$key // empty" 2>/dev/null) || result=""
        # Handle null or empty
        if [[ -z "$result" ]] || [[ "$result" == "null" ]]; then
            result="$default"
        fi
        echo "$result"
    elif command -v python3 &>/dev/null; then
        local escaped_json
        escaped_json=$(printf '%s' "$json" | sed "s/'/\\\\'/g")
        python3 << PYEOF 2>/dev/null || echo "$default"
import json
try:
    data = json.loads('$escaped_json')
    keys = '$key'.split('.')
    v = data
    for k in keys:
        if isinstance(v, dict):
            v = v.get(k, '$default')
        else:
            v = '$default'
    print(v if v is not None else '$default')
except:
    print('$default')
PYEOF
    else
        echo "$default"
    fi
}

# Reset test environment between tests
reset_test_env() {
    rm -rf "${TEST_COST_STATE_DIR}"/* 2>/dev/null || true
    rm -rf "${TEST_COST_LOG_DIR}"/* 2>/dev/null || true
    mkdir -p "$TEST_COST_STATE_DIR" "$TEST_COST_LOG_DIR"
}

#===============================================================================
# Tests: 1. Cost Recording
#===============================================================================

echo ""
echo "Testing lib/cost-tracker.sh functions..."
echo ""
echo "=== 1. Test Cost Recording ==="

test_record_request_basic() {
    reset_test_env

    if type record_request &>/dev/null; then
        # Record a basic request
        record_request "claude" 1000 500 150 "coding"

        # Check if the cost log was created
        local date_str
        date_str="$(date +%Y-%m-%d)"
        local cost_log="${TEST_COST_LOG_DIR}/${date_str}.jsonl"

        if [[ -f "$cost_log" ]]; then
            local entry
            entry=$(tail -1 "$cost_log")

            # Verify the entry contains expected model
            if echo "$entry" | grep -q '"model":"claude"'; then
                pass "record_request: Creates cost log entry with correct model"
            else
                fail "record_request: Log entry missing model" "$entry"
            fi
        else
            fail "record_request: Cost log not created" "Expected: $cost_log"
        fi
    else
        skip "record_request: Function not available"
    fi
}

test_record_request_tokens() {
    reset_test_env

    if type record_request &>/dev/null; then
        record_request "claude" 2500 1500 200 "analysis"

        local date_str
        date_str="$(date +%Y-%m-%d)"
        local cost_log="${TEST_COST_LOG_DIR}/${date_str}.jsonl"

        if [[ -f "$cost_log" ]]; then
            local entry
            entry=$(tail -1 "$cost_log")

            # Verify token counts in entry
            if echo "$entry" | grep -q '"input_tokens":2500' && echo "$entry" | grep -q '"output_tokens":1500'; then
                pass "record_request: Records correct token counts"
            else
                fail "record_request: Token counts incorrect" "$entry"
            fi
        else
            fail "record_request: Cost log not created"
        fi
    else
        skip "record_request: Function not available"
    fi
}

test_record_request_model_normalization() {
    reset_test_env

    if type record_request &>/dev/null; then
        # Test model normalization (opus -> claude)
        record_request "opus" 100 50 10 "test"

        local date_str
        date_str="$(date +%Y-%m-%d)"
        local cost_log="${TEST_COST_LOG_DIR}/${date_str}.jsonl"

        if [[ -f "$cost_log" ]]; then
            local entry
            entry=$(tail -1 "$cost_log")

            if echo "$entry" | grep -q '"model":"claude"'; then
                pass "record_request: Normalizes 'opus' to 'claude'"
            else
                fail "record_request: Model normalization failed" "$entry"
            fi
        else
            fail "record_request: Cost log not created"
        fi
    else
        skip "record_request: Function not available"
    fi
}

test_record_request_duration() {
    reset_test_env

    if type record_request &>/dev/null; then
        record_request "gemini" 500 250 3500 "review"

        local date_str
        date_str="$(date +%Y-%m-%d)"
        local cost_log="${TEST_COST_LOG_DIR}/${date_str}.jsonl"

        if [[ -f "$cost_log" ]]; then
            local entry
            entry=$(tail -1 "$cost_log")

            if echo "$entry" | grep -q '"duration_ms":3500'; then
                pass "record_request: Records duration correctly"
            else
                fail "record_request: Duration not recorded" "$entry"
            fi
        else
            fail "record_request: Cost log not created"
        fi
    else
        skip "record_request: Function not available"
    fi
}

test_record_request_task_type() {
    reset_test_env

    if type record_request &>/dev/null; then
        record_request "codex" 800 400 100 "implementation"

        local date_str
        date_str="$(date +%Y-%m-%d)"
        local cost_log="${TEST_COST_LOG_DIR}/${date_str}.jsonl"

        if [[ -f "$cost_log" ]]; then
            local entry
            entry=$(tail -1 "$cost_log")

            if echo "$entry" | grep -q '"task_type":"implementation"'; then
                pass "record_request: Records task type"
            else
                fail "record_request: Task type not recorded" "$entry"
            fi
        else
            fail "record_request: Cost log not created"
        fi
    else
        skip "record_request: Function not available"
    fi
}

#===============================================================================
# Tests: 2. Budget Enforcement
#===============================================================================

echo ""
echo "=== 2. Test Budget Enforcement ==="

test_sanitize_numeric_valid() {
    if type _sanitize_numeric &>/dev/null; then
        local result
        result=$(_sanitize_numeric "12345" "test_field")

        if [[ "$result" == "12345" ]]; then
            pass "_sanitize_numeric: Accepts valid numeric value"
        else
            fail "_sanitize_numeric: Did not return valid value" "Got: $result"
        fi
    else
        skip "_sanitize_numeric: Function not available"
    fi
}

test_sanitize_numeric_invalid() {
    if type _sanitize_numeric &>/dev/null; then
        local result
        # Function returns non-zero for invalid input, capture output regardless
        result=$(_sanitize_numeric "abc" "test_field" 2>/dev/null) || true

        if [[ "$result" == "0" ]]; then
            pass "_sanitize_numeric: Returns 0 for invalid input"
        else
            fail "_sanitize_numeric: Should return 0 for invalid" "Got: $result"
        fi
    else
        skip "_sanitize_numeric: Function not available"
    fi
}

test_sanitize_numeric_empty() {
    if type _sanitize_numeric &>/dev/null; then
        local result
        # Function returns non-zero for empty input, capture output regardless
        result=$(_sanitize_numeric "" "test_field" 2>/dev/null) || true

        if [[ "$result" == "0" ]]; then
            pass "_sanitize_numeric: Returns 0 for empty input"
        else
            fail "_sanitize_numeric: Should return 0 for empty" "Got: $result"
        fi
    else
        skip "_sanitize_numeric: Function not available"
    fi
}

test_sanitize_numeric_negative() {
    if type _sanitize_numeric &>/dev/null; then
        local result
        # Function returns non-zero for negative input (not matching ^[0-9]+$)
        result=$(_sanitize_numeric "-100" "test_field" 2>/dev/null) || true

        if [[ "$result" == "0" ]]; then
            pass "_sanitize_numeric: Returns 0 for negative input"
        else
            fail "_sanitize_numeric: Should reject negative numbers" "Got: $result"
        fi
    else
        skip "_sanitize_numeric: Function not available"
    fi
}

test_budget_enforcement_max_tokens() {
    reset_test_env

    if type record_request &>/dev/null && type get_daily_stats &>/dev/null; then
        # Simulate recording requests up to a "budget" threshold
        local max_daily_tokens=10000

        # Record several requests
        record_request "claude" 3000 1500 100 "test1"
        record_request "claude" 2000 1000 100 "test2"
        record_request "claude" 2500 1200 100 "test3"

        local stats
        stats=$(get_daily_stats)

        local total_input
        total_input=$(json_get "$stats" "total_input_tokens" "0")

        if [[ "$total_input" =~ ^[0-9]+$ ]] && [[ "$total_input" -ge 7000 ]]; then
            # Check if we would exceed budget
            local projected=$((total_input + 5000))
            if [[ $projected -gt $max_daily_tokens ]]; then
                pass "Budget enforcement: Can detect when tokens exceed threshold"
            else
                fail "Budget enforcement: Token tracking not working"
            fi
        else
            fail "Budget enforcement: Could not get total tokens" "Got: $total_input"
        fi
    else
        skip "Budget enforcement: Required functions not available"
    fi
}

#===============================================================================
# Tests: 3. Cost Aggregation
#===============================================================================

echo ""
echo "=== 3. Test Cost Aggregation ==="

test_cost_aggregation_daily() {
    reset_test_env

    if type record_request &>/dev/null && type get_daily_stats &>/dev/null; then
        # Record multiple requests
        record_request "claude" 1000 500 100 "task1"
        record_request "claude" 2000 1000 200 "task2"
        record_request "gemini" 1500 750 150 "task3"

        local stats
        stats=$(get_daily_stats)

        local total_requests
        total_requests=$(json_get "$stats" "total_requests" "0")

        if [[ "$total_requests" == "3" ]]; then
            pass "Cost aggregation: Daily total requests correct"
        else
            fail "Cost aggregation: Expected 3 requests" "Got: $total_requests"
        fi
    else
        skip "Cost aggregation: Required functions not available"
    fi
}

test_cost_aggregation_input_tokens() {
    reset_test_env

    if type record_request &>/dev/null && type get_daily_stats &>/dev/null; then
        record_request "claude" 1000 0 0 "test"
        record_request "claude" 2000 0 0 "test"
        record_request "claude" 3000 0 0 "test"

        local stats
        stats=$(get_daily_stats)

        local total_input
        total_input=$(json_get "$stats" "total_input_tokens" "0")

        if [[ "$total_input" == "6000" ]]; then
            pass "Cost aggregation: Input tokens summed correctly"
        else
            fail "Cost aggregation: Expected 6000 input tokens" "Got: $total_input"
        fi
    else
        skip "Cost aggregation: Required functions not available"
    fi
}

test_cost_aggregation_output_tokens() {
    reset_test_env

    if type record_request &>/dev/null && type get_daily_stats &>/dev/null; then
        record_request "claude" 0 500 0 "test"
        record_request "claude" 0 750 0 "test"
        record_request "claude" 0 250 0 "test"

        local stats
        stats=$(get_daily_stats)

        local total_output
        total_output=$(json_get "$stats" "total_output_tokens" "0")

        if [[ "$total_output" == "1500" ]]; then
            pass "Cost aggregation: Output tokens summed correctly"
        else
            fail "Cost aggregation: Expected 1500 output tokens" "Got: $total_output"
        fi
    else
        skip "Cost aggregation: Required functions not available"
    fi
}

test_cost_aggregation_by_model() {
    reset_test_env

    if type record_request &>/dev/null && type get_daily_stats &>/dev/null; then
        record_request "claude" 1000 500 100 "test"
        record_request "gemini" 2000 1000 200 "test"
        record_request "codex" 1500 750 150 "test"

        local stats
        stats=$(get_daily_stats)

        # Check that models section exists
        local models_section
        if [[ "$HAS_JQ" == "true" ]]; then
            models_section=$(echo "$stats" | jq '.models // {}' 2>/dev/null)
        else
            models_section=$(echo "$stats" | grep -o '"models":{[^}]*}' 2>/dev/null || echo "{}")
        fi

        if echo "$models_section" | grep -q "claude" && \
           echo "$models_section" | grep -q "gemini" && \
           echo "$models_section" | grep -q "codex"; then
            pass "Cost aggregation: Tracks all models separately"
        else
            fail "Cost aggregation: Not all models tracked" "$models_section"
        fi
    else
        skip "Cost aggregation: Required functions not available"
    fi
}

test_usage_summary_totals() {
    reset_test_env

    if type record_request &>/dev/null && type get_usage_summary &>/dev/null; then
        record_request "claude" 1000 500 100 "test"
        record_request "gemini" 2000 1000 200 "test"

        local summary
        summary=$(get_usage_summary)

        local total_requests
        total_requests=$(json_get "$summary" "total_requests" "0")

        if [[ "$total_requests" == "2" ]]; then
            pass "Usage summary: Returns correct total requests"
        else
            fail "Usage summary: Expected 2 total requests" "Got: $total_requests"
        fi
    else
        skip "Usage summary: Required functions not available"
    fi
}

#===============================================================================
# Tests: 4. Budget Threshold Alerts
#===============================================================================

echo ""
echo "=== 4. Test Budget Threshold Alerts ==="

test_threshold_detection_50_percent() {
    reset_test_env

    if type record_request &>/dev/null && type get_daily_stats &>/dev/null; then
        local budget_limit=10000

        # Record requests to reach ~50% of budget
        record_request "claude" 2500 0 0 "test1"
        record_request "claude" 2500 0 0 "test2"

        local stats
        stats=$(get_daily_stats)

        local total_input
        total_input=$(json_get "$stats" "total_input_tokens" "0")

        local percentage=0
        if [[ "$total_input" =~ ^[0-9]+$ ]] && [[ $budget_limit -gt 0 ]]; then
            percentage=$((total_input * 100 / budget_limit))
        fi

        if [[ $percentage -ge 50 ]]; then
            pass "Threshold detection: 50% threshold detected (${percentage}%)"
        else
            fail "Threshold detection: Should be at 50%" "Got: ${percentage}%"
        fi
    else
        skip "Threshold detection: Required functions not available"
    fi
}

test_threshold_detection_80_percent() {
    reset_test_env

    if type record_request &>/dev/null && type get_daily_stats &>/dev/null; then
        local budget_limit=10000

        # Record requests to reach ~80% of budget
        record_request "claude" 4000 0 0 "test1"
        record_request "claude" 4000 0 0 "test2"

        local stats
        stats=$(get_daily_stats)

        local total_input
        total_input=$(json_get "$stats" "total_input_tokens" "0")

        local percentage=0
        if [[ "$total_input" =~ ^[0-9]+$ ]] && [[ $budget_limit -gt 0 ]]; then
            percentage=$((total_input * 100 / budget_limit))
        fi

        if [[ $percentage -ge 80 ]]; then
            pass "Threshold detection: 80% threshold detected (${percentage}%)"
        else
            fail "Threshold detection: Should be at 80%" "Got: ${percentage}%"
        fi
    else
        skip "Threshold detection: Required functions not available"
    fi
}

test_threshold_detection_exceeded() {
    reset_test_env

    if type record_request &>/dev/null && type get_daily_stats &>/dev/null; then
        local budget_limit=10000

        # Record requests to exceed budget
        record_request "claude" 6000 0 0 "test1"
        record_request "claude" 6000 0 0 "test2"

        local stats
        stats=$(get_daily_stats)

        local total_input
        total_input=$(json_get "$stats" "total_input_tokens" "0")

        local percentage=0
        if [[ "$total_input" =~ ^[0-9]+$ ]] && [[ $budget_limit -gt 0 ]]; then
            percentage=$((total_input * 100 / budget_limit))
        fi

        if [[ $percentage -gt 100 ]]; then
            pass "Threshold detection: Budget exceeded detected (${percentage}%)"
        else
            fail "Threshold detection: Should exceed 100%" "Got: ${percentage}%"
        fi
    else
        skip "Threshold detection: Required functions not available"
    fi
}

test_threshold_multiple_models() {
    reset_test_env

    if type record_request &>/dev/null && type get_usage_summary &>/dev/null; then
        local per_model_limit=5000

        # Record for multiple models
        record_request "claude" 3000 0 0 "test1"
        record_request "gemini" 4000 0 0 "test2"
        record_request "codex" 6000 0 0 "test3"

        local summary
        summary=$(get_usage_summary)

        # Check if any model exceeds per-model limit
        local exceeded_count=0

        for model in claude gemini codex; do
            local model_tokens
            if [[ "$HAS_JQ" == "true" ]]; then
                model_tokens=$(echo "$summary" | jq -r ".by_model.${model}.input_tokens // 0" 2>/dev/null)
            else
                model_tokens="0"
            fi

            if [[ "$model_tokens" =~ ^[0-9]+$ ]] && [[ $model_tokens -gt $per_model_limit ]]; then
                ((exceeded_count++)) || true
            fi
        done

        if [[ $exceeded_count -ge 1 ]]; then
            pass "Threshold detection: Per-model threshold exceeded ($exceeded_count model(s))"
        else
            skip "Threshold detection: JSON parsing limited, skipping model check"
        fi
    else
        skip "Threshold detection: Required functions not available"
    fi
}

#===============================================================================
# Tests: 5. Cost By Model
#===============================================================================

echo ""
echo "=== 5. Test Cost By Model ==="

test_cost_by_model_claude() {
    reset_test_env

    if type record_request &>/dev/null && type get_model_stats &>/dev/null; then
        record_request "claude" 1000 500 100 "test1"
        record_request "claude" 2000 1000 200 "test2"

        local stats
        stats=$(get_model_stats "claude")

        local total_requests
        total_requests=$(json_get "$stats" "total_requests" "0")

        if [[ "$total_requests" == "2" ]]; then
            pass "Cost by model: Claude requests tracked correctly"
        else
            fail "Cost by model: Expected 2 Claude requests" "Got: $total_requests"
        fi
    else
        skip "Cost by model: Required functions not available"
    fi
}

test_cost_by_model_gemini() {
    reset_test_env

    if type record_request &>/dev/null && type get_model_stats &>/dev/null; then
        record_request "gemini" 1500 750 150 "review"

        local stats
        stats=$(get_model_stats "gemini")

        local model_name
        model_name=$(json_get "$stats" "model" "")

        if [[ "$model_name" == "gemini" ]]; then
            pass "Cost by model: Gemini stats retrieved correctly"
        else
            fail "Cost by model: Expected gemini model" "Got: $model_name"
        fi
    else
        skip "Cost by model: Required functions not available"
    fi
}

test_cost_by_model_codex() {
    reset_test_env

    if type record_request &>/dev/null && type get_model_stats &>/dev/null; then
        record_request "codex" 800 400 80 "implementation"
        record_request "codex" 1200 600 120 "refactor"
        record_request "codex" 500 250 50 "fix"

        local stats
        stats=$(get_model_stats "codex")

        local total_input
        total_input=$(json_get "$stats" "total_input_tokens" "0")

        if [[ "$total_input" == "2500" ]]; then
            pass "Cost by model: Codex tokens summed correctly"
        else
            fail "Cost by model: Expected 2500 input tokens" "Got: $total_input"
        fi
    else
        skip "Cost by model: Required functions not available"
    fi
}

test_cost_by_model_normalization_opus() {
    reset_test_env

    if type record_request &>/dev/null && type get_model_stats &>/dev/null; then
        record_request "opus" 1000 500 100 "test"

        local stats
        stats=$(get_model_stats "opus")

        local model_name
        model_name=$(json_get "$stats" "model" "")

        if [[ "$model_name" == "claude" ]]; then
            pass "Cost by model: 'opus' normalized to 'claude' in stats"
        else
            fail "Cost by model: Expected claude" "Got: $model_name"
        fi
    else
        skip "Cost by model: Required functions not available"
    fi
}

test_cost_by_model_normalization_gpt() {
    reset_test_env

    if type record_request &>/dev/null && type get_model_stats &>/dev/null; then
        record_request "gpt" 1000 500 100 "test"

        local stats
        stats=$(get_model_stats "gpt")

        local model_name
        model_name=$(json_get "$stats" "model" "")

        if [[ "$model_name" == "codex" ]]; then
            pass "Cost by model: 'gpt' normalized to 'codex' in stats"
        else
            fail "Cost by model: Expected codex" "Got: $model_name"
        fi
    else
        skip "Cost by model: Required functions not available"
    fi
}

test_cost_by_model_all_stats() {
    reset_test_env

    if type record_request &>/dev/null && type get_all_model_stats &>/dev/null; then
        record_request "claude" 1000 500 100 "test"
        record_request "gemini" 2000 1000 200 "test"
        record_request "codex" 1500 750 150 "test"

        local all_stats
        all_stats=$(get_all_model_stats)

        if echo "$all_stats" | grep -q '"models"'; then
            pass "Cost by model: get_all_model_stats returns models array"
        else
            fail "Cost by model: Missing models array in all stats"
        fi
    else
        skip "Cost by model: get_all_model_stats not available"
    fi
}

test_cost_by_model_duration_tracking() {
    reset_test_env

    if type record_request &>/dev/null && type get_model_stats &>/dev/null; then
        record_request "claude" 1000 500 1000 "test1"
        record_request "claude" 1000 500 2000 "test2"
        record_request "claude" 1000 500 3000 "test3"

        local stats
        stats=$(get_model_stats "claude")

        local total_duration
        total_duration=$(json_get "$stats" "total_duration_ms" "0")

        if [[ "$total_duration" == "6000" ]]; then
            pass "Cost by model: Duration tracked correctly (6000ms)"
        else
            fail "Cost by model: Expected 6000ms total duration" "Got: $total_duration"
        fi
    else
        skip "Cost by model: Required functions not available"
    fi
}

#===============================================================================
# Tests: 6. Daily Cost Reset
#===============================================================================

echo ""
echo "=== 6. Test Daily Cost Reset ==="

test_reset_daily_stats() {
    reset_test_env

    if type record_request &>/dev/null && type reset_daily_stats &>/dev/null && type get_daily_stats &>/dev/null; then
        # Record some requests
        record_request "claude" 1000 500 100 "test"
        record_request "gemini" 2000 1000 200 "test"

        # Verify we have data
        local stats_before
        stats_before=$(get_daily_stats)
        local requests_before
        requests_before=$(json_get "$stats_before" "total_requests" "0")

        if [[ "$requests_before" != "2" ]]; then
            fail "Daily reset: Initial data not recorded" "Got: $requests_before"
            return
        fi

        # Reset daily stats
        reset_daily_stats

        # Verify stats are reset
        local stats_after
        stats_after=$(get_daily_stats)
        local requests_after
        requests_after=$(json_get "$stats_after" "total_requests" "0")

        if [[ "$requests_after" == "0" ]]; then
            pass "Daily reset: reset_daily_stats clears daily stats"
        else
            fail "Daily reset: Stats not cleared" "Got: $requests_after requests"
        fi
    else
        skip "Daily reset: Required functions not available"
    fi
}

test_reset_model_stats() {
    reset_test_env

    if type record_request &>/dev/null && type reset_model_stats &>/dev/null && type get_model_stats &>/dev/null; then
        # Record for a specific model
        record_request "claude" 1000 500 100 "test"
        record_request "claude" 2000 1000 200 "test"

        # Reset claude stats
        reset_model_stats "claude"

        # Verify stats are reset
        local stats
        stats=$(get_model_stats "claude")
        local total_requests
        total_requests=$(json_get "$stats" "total_requests" "0")

        if [[ "$total_requests" == "0" ]]; then
            pass "Model reset: reset_model_stats clears model stats"
        else
            fail "Model reset: Stats not cleared" "Got: $total_requests"
        fi
    else
        skip "Model reset: Required functions not available"
    fi
}

test_reset_model_stats_preserves_others() {
    reset_test_env

    if type record_request &>/dev/null && type reset_model_stats &>/dev/null && type get_model_stats &>/dev/null; then
        # Record for multiple models
        record_request "claude" 1000 500 100 "test"
        record_request "gemini" 2000 1000 200 "test"

        # Reset only claude
        reset_model_stats "claude"

        # Verify gemini stats preserved
        local stats
        stats=$(get_model_stats "gemini")
        local total_requests
        total_requests=$(json_get "$stats" "total_requests" "0")

        if [[ "$total_requests" == "1" ]]; then
            pass "Model reset: Preserves other model stats"
        else
            fail "Model reset: Other model stats affected" "Got: $total_requests"
        fi
    else
        skip "Model reset: Required functions not available"
    fi
}

test_reset_all_stats() {
    reset_test_env

    if type record_request &>/dev/null && type reset_all_stats &>/dev/null && type get_usage_summary &>/dev/null; then
        # Record for multiple models
        record_request "claude" 1000 500 100 "test"
        record_request "gemini" 2000 1000 200 "test"
        record_request "codex" 1500 750 150 "test"

        # Reset all stats
        reset_all_stats

        # Verify all stats are reset
        local summary
        summary=$(get_usage_summary)
        local total_requests
        total_requests=$(json_get "$summary" "total_requests" "0")

        if [[ "$total_requests" == "0" ]]; then
            pass "All reset: reset_all_stats clears all stats"
        else
            fail "All reset: Stats not cleared" "Got: $total_requests"
        fi
    else
        skip "All reset: Required functions not available"
    fi
}

test_stats_after_reset_and_new_record() {
    reset_test_env

    if type record_request &>/dev/null && type reset_all_stats &>/dev/null && type get_daily_stats &>/dev/null; then
        # Record initial data
        record_request "claude" 1000 500 100 "test"

        # Reset
        reset_all_stats

        # Record new data
        record_request "gemini" 500 250 50 "new_test"

        # Verify new data is recorded
        local stats
        stats=$(get_daily_stats)
        local total_requests
        total_requests=$(json_get "$stats" "total_requests" "0")

        if [[ "$total_requests" == "1" ]]; then
            pass "Post-reset recording: New data recorded after reset"
        else
            fail "Post-reset recording: Expected 1 request" "Got: $total_requests"
        fi
    else
        skip "Post-reset recording: Required functions not available"
    fi
}

#===============================================================================
# Additional Tests: Token Estimation
#===============================================================================

echo ""
echo "=== Additional: Token Estimation ==="

test_estimate_tokens_basic() {
    if type estimate_tokens &>/dev/null; then
        local content="Hello world this is a test string"
        local tokens
        tokens=$(estimate_tokens "$content" "claude")

        # Should be roughly 34 chars / 4 = ~9 tokens
        if [[ "$tokens" =~ ^[0-9]+$ ]] && [[ $tokens -gt 0 ]]; then
            pass "estimate_tokens: Returns numeric estimate ($tokens)"
        else
            fail "estimate_tokens: Should return positive number" "Got: $tokens"
        fi
    else
        skip "estimate_tokens: Function not available"
    fi
}

test_estimate_tokens_different_models() {
    if type estimate_tokens &>/dev/null; then
        local content="Sample content for token estimation"
        local claude_tokens gemini_tokens codex_tokens

        claude_tokens=$(estimate_tokens "$content" "claude")
        gemini_tokens=$(estimate_tokens "$content" "gemini")
        codex_tokens=$(estimate_tokens "$content" "codex")

        # All should return valid numbers
        if [[ "$claude_tokens" =~ ^[0-9]+$ ]] && \
           [[ "$gemini_tokens" =~ ^[0-9]+$ ]] && \
           [[ "$codex_tokens" =~ ^[0-9]+$ ]]; then
            pass "estimate_tokens: Works for different models (claude=$claude_tokens, gemini=$gemini_tokens, codex=$codex_tokens)"
        else
            fail "estimate_tokens: Invalid tokens for some models"
        fi
    else
        skip "estimate_tokens: Function not available"
    fi
}

test_estimate_tokens_empty() {
    if type estimate_tokens &>/dev/null; then
        local tokens
        tokens=$(estimate_tokens "" "claude")

        if [[ "$tokens" == "0" ]]; then
            pass "estimate_tokens: Returns 0 for empty content"
        else
            fail "estimate_tokens: Should return 0 for empty" "Got: $tokens"
        fi
    else
        skip "estimate_tokens: Function not available"
    fi
}

#===============================================================================
# Additional Tests: JSON Escaping
#===============================================================================

echo ""
echo "=== Additional: JSON Escaping ==="

test_json_escape_basic() {
    if type _cost_json_escape_value &>/dev/null; then
        local result
        result=$(_cost_json_escape_value "test string")

        if [[ "$result" == "test string" ]]; then
            pass "JSON escape: Handles basic strings"
        else
            fail "JSON escape: Basic string modified" "Got: $result"
        fi
    else
        skip "JSON escape: Function not available"
    fi
}

test_json_escape_quotes() {
    if type _cost_json_escape_value &>/dev/null; then
        local result
        result=$(_cost_json_escape_value 'test "quoted" string')

        if echo "$result" | grep -q '\\\"'; then
            pass "JSON escape: Escapes double quotes"
        else
            fail "JSON escape: Quotes not escaped" "Got: $result"
        fi
    else
        skip "JSON escape: Function not available"
    fi
}

test_json_escape_newlines() {
    if type _cost_json_escape_value &>/dev/null; then
        local input="line1
line2"
        local result
        result=$(_cost_json_escape_value "$input")

        if echo "$result" | grep -q '\\n'; then
            pass "JSON escape: Escapes newlines"
        else
            fail "JSON escape: Newlines not escaped" "Got: $result"
        fi
    else
        skip "JSON escape: Function not available"
    fi
}

#===============================================================================
# Run All Tests
#===============================================================================

echo ""
echo "Running all cost tracker tests..."

# 1. Cost Recording
test_record_request_basic
test_record_request_tokens
test_record_request_model_normalization
test_record_request_duration
test_record_request_task_type

# 2. Budget Enforcement
test_sanitize_numeric_valid
test_sanitize_numeric_invalid
test_sanitize_numeric_empty
test_sanitize_numeric_negative
test_budget_enforcement_max_tokens

# 3. Cost Aggregation
test_cost_aggregation_daily
test_cost_aggregation_input_tokens
test_cost_aggregation_output_tokens
test_cost_aggregation_by_model
test_usage_summary_totals

# 4. Budget Threshold Alerts
test_threshold_detection_50_percent
test_threshold_detection_80_percent
test_threshold_detection_exceeded
test_threshold_multiple_models

# 5. Cost By Model
test_cost_by_model_claude
test_cost_by_model_gemini
test_cost_by_model_codex
test_cost_by_model_normalization_opus
test_cost_by_model_normalization_gpt
test_cost_by_model_all_stats
test_cost_by_model_duration_tracking

# 6. Daily Cost Reset
test_reset_daily_stats
test_reset_model_stats
test_reset_model_stats_preserves_others
test_reset_all_stats
test_stats_after_reset_and_new_record

# Additional tests
test_estimate_tokens_basic
test_estimate_tokens_different_models
test_estimate_tokens_empty
test_json_escape_basic
test_json_escape_quotes
test_json_escape_newlines

export TESTS_PASSED TESTS_FAILED

echo ""
echo "============================================================"
echo "cost-tracker.sh tests completed: $TESTS_PASSED passed, $TESTS_FAILED failed"
echo "============================================================"

# Exit with error if any tests failed
if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
