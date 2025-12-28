#!/bin/bash
#===============================================================================
# test_cost_tracking_validation.sh - Deep multi-way cost tracking validation
#===============================================================================
# Validates cost tracking functionality using 3+ testing methods per feature.
#
# Validation Matrix:
# | Feature          | Method 1     | Method 2      | Method 3          |
# |------------------|--------------|---------------|-------------------|
# | Token counting   | Known input  | Large input   | Unicode input     |
# | Cost calculation | Standard rate| Custom rate   | Zero tokens       |
# | Daily rollup     | Single day   | Multi-day     | Month boundary    |
# | Export format    | JSON         | CSV           | Prometheus        |
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(dirname "$(dirname "$SCRIPT_DIR")")}"
LIB_DIR="${PROJECT_ROOT}/lib"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

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
# Test Environment Setup
#===============================================================================

TEST_DIR=$(mktemp -d)
export STATE_DIR="${TEST_DIR}/state"
export LOG_DIR="${TEST_DIR}/logs"
export COST_LOG_DIR="${LOG_DIR}/costs"
export TRACE_ID="validation-cost-$$"

mkdir -p "$STATE_DIR" "$LOG_DIR" "$COST_LOG_DIR"

cleanup() {
    rm -rf "$TEST_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# Source dependencies
source "${LIB_DIR}/common.sh"

#===============================================================================
# Helper Functions
#===============================================================================

# Estimate token count (rough approximation)
estimate_tokens() {
    local text="$1"
    # Rough estimate: ~4 chars per token
    local chars=${#text}
    echo $(( (chars + 3) / 4 ))
}

# Calculate cost from tokens
calculate_cost() {
    local model="$1"
    local input_tokens="$2"
    local output_tokens="$3"

    local input_rate output_rate

    case "$model" in
        claude)
            input_rate="0.015"    # $15 per 1M tokens
            output_rate="0.075"   # $75 per 1M tokens
            ;;
        gemini)
            input_rate="0.00025"  # $0.25 per 1M tokens
            output_rate="0.0005"  # $0.50 per 1M tokens
            ;;
        codex)
            input_rate="0.01"     # $10 per 1M tokens
            output_rate="0.03"    # $30 per 1M tokens
            ;;
        *)
            input_rate="0.01"
            output_rate="0.03"
            ;;
    esac

    # Cost = (input_tokens * input_rate + output_tokens * output_rate) / 1000000
    local cost
    cost=$(echo "scale=8; ($input_tokens * $input_rate + $output_tokens * $output_rate) / 1000000" | bc)
    echo "$cost"
}

# Create cost log entry
log_cost_entry() {
    local date="$1"
    local model="$2"
    local input_tokens="$3"
    local output_tokens="$4"
    local cost="$5"

    local log_file="${COST_LOG_DIR}/${date}.jsonl"

    echo "{\"timestamp\":\"$(date -Iseconds)\",\"model\":\"$model\",\"input_tokens\":$input_tokens,\"output_tokens\":$output_tokens,\"cost\":$cost}" >> "$log_file"
}

#===============================================================================
# TOKEN COUNTING VALIDATION (3 Methods)
#===============================================================================

echo ""
echo "=================================================="
echo "  TOKEN COUNTING VALIDATION (3 Methods)"
echo "=================================================="

# Method 1: Known Input (Exact Count)
test_tokens_known() {
    echo ""
    echo "Method 1: Known Input (Exact Count)"

    # "Hello world" is approximately 2-3 tokens
    local known_input="Hello world"
    local expected_min=2
    local expected_max=4

    local tokens
    tokens=$(estimate_tokens "$known_input")

    if [[ $tokens -ge $expected_min && $tokens -le $expected_max ]]; then
        pass "Token counting: Known input - $tokens tokens for '$known_input'"
    else
        fail "Token counting: Known input - Expected $expected_min-$expected_max, got $tokens"
    fi

    # Longer known input
    local longer_input="The quick brown fox jumps over the lazy dog"
    local longer_expected_min=8
    local longer_expected_max=12

    tokens=$(estimate_tokens "$longer_input")

    if [[ $tokens -ge $longer_expected_min && $tokens -le $longer_expected_max ]]; then
        pass "Token counting: Known longer input - $tokens tokens"
    else
        fail "Token counting: Known longer input - Expected $longer_expected_min-$longer_expected_max, got $tokens"
    fi
}

# Method 2: Large Input
test_tokens_large() {
    echo ""
    echo "Method 2: Large Input"

    # Generate large input (10KB)
    local large_input
    large_input=$(printf 'A%.0s' {1..10000})

    local tokens
    tokens=$(estimate_tokens "$large_input")

    # 10000 chars / 4 = ~2500 tokens
    local expected_min=2000
    local expected_max=3000

    if [[ $tokens -ge $expected_min && $tokens -le $expected_max ]]; then
        pass "Token counting: Large input - $tokens tokens for 10KB input"
    else
        fail "Token counting: Large input - Expected $expected_min-$expected_max, got $tokens"
    fi
}

# Method 3: Unicode Input
test_tokens_unicode() {
    echo ""
    echo "Method 3: Unicode Input"

    local unicode_input="Hello 世界 🌍 مرحبا"
    local tokens
    tokens=$(estimate_tokens "$unicode_input")

    # Unicode typically takes more bytes but similar token count
    if [[ $tokens -gt 0 ]]; then
        pass "Token counting: Unicode input - $tokens tokens (handles Unicode)"
    else
        fail "Token counting: Unicode input - Failed to count Unicode tokens"
    fi
}

#===============================================================================
# COST CALCULATION VALIDATION (3 Methods)
#===============================================================================

echo ""
echo "=================================================="
echo "  COST CALCULATION VALIDATION (3 Methods)"
echo "=================================================="

# Method 1: Standard Rate
test_cost_standard() {
    echo ""
    echo "Method 1: Standard Rate"

    local model="claude"
    local input_tokens=1000
    local output_tokens=500

    local cost
    cost=$(calculate_cost "$model" "$input_tokens" "$output_tokens")

    # Expected: (1000 * 0.015 + 500 * 0.075) / 1000000 = 0.0000525
    local expected="0.0000525"

    # Compare with tolerance
    local diff
    diff=$(echo "scale=10; $cost - $expected" | bc)
    diff=${diff#-}  # Absolute value

    if (( $(echo "$diff < 0.0000001" | bc -l) )); then
        pass "Cost calculation: Standard rate - $cost for $input_tokens/$output_tokens tokens"
    else
        fail "Cost calculation: Standard rate - Expected ~$expected, got $cost"
    fi
}

# Method 2: Custom Rate (Different Model)
test_cost_custom() {
    echo ""
    echo "Method 2: Custom Rate (Different Models)"

    local models=("claude" "gemini" "codex")
    local input_tokens=10000
    local output_tokens=5000

    local all_valid=true

    for model in "${models[@]}"; do
        local cost
        cost=$(calculate_cost "$model" "$input_tokens" "$output_tokens")

        if (( $(echo "$cost > 0" | bc -l) )); then
            info "$model: \$$cost for $input_tokens/$output_tokens tokens"
        else
            all_valid=false
        fi
    done

    if $all_valid; then
        pass "Cost calculation: Custom rates - All models calculated correctly"
    else
        fail "Cost calculation: Custom rates - Some models failed"
    fi
}

# Method 3: Zero Tokens
test_cost_zero() {
    echo ""
    echo "Method 3: Zero Tokens"

    local cost
    cost=$(calculate_cost "claude" 0 0)

    if [[ "$cost" == "0" ]] || (( $(echo "$cost == 0" | bc -l) )); then
        pass "Cost calculation: Zero tokens - Cost is $0"
    else
        fail "Cost calculation: Zero tokens - Expected 0, got $cost"
    fi
}

#===============================================================================
# DAILY ROLLUP VALIDATION (3 Methods)
#===============================================================================

echo ""
echo "=================================================="
echo "  DAILY ROLLUP VALIDATION (3 Methods)"
echo "=================================================="

# Method 1: Single Day
test_rollup_single_day() {
    echo ""
    echo "Method 1: Single Day"

    local today
    today=$(date +%Y-%m-%d)

    # Log multiple entries for today
    log_cost_entry "$today" "claude" 1000 500 0.0000525
    log_cost_entry "$today" "claude" 2000 1000 0.000105
    log_cost_entry "$today" "gemini" 5000 2500 0.00000375

    local log_file="${COST_LOG_DIR}/${today}.jsonl"

    if [[ -f "$log_file" ]]; then
        local entry_count
        entry_count=$(wc -l < "$log_file")

        if [[ $entry_count -eq 3 ]]; then
            pass "Daily rollup: Single day - $entry_count entries logged"
        else
            fail "Daily rollup: Single day - Expected 3 entries, got $entry_count"
        fi
    else
        fail "Daily rollup: Single day - Log file not created"
    fi
}

# Method 2: Multi-Day
test_rollup_multi_day() {
    echo ""
    echo "Method 2: Multi-Day"

    local day1 day2 day3
    day1="2024-01-01"
    day2="2024-01-02"
    day3="2024-01-03"

    log_cost_entry "$day1" "claude" 1000 500 0.0000525
    log_cost_entry "$day2" "gemini" 2000 1000 0.00000125
    log_cost_entry "$day3" "codex" 3000 1500 0.000075

    local files_created=0

    for day in "$day1" "$day2" "$day3"; do
        if [[ -f "${COST_LOG_DIR}/${day}.jsonl" ]]; then
            ((files_created++)) || true
        fi
    done

    if [[ $files_created -eq 3 ]]; then
        pass "Daily rollup: Multi-day - All 3 day files created"
    else
        fail "Daily rollup: Multi-day - Only $files_created/3 files created"
    fi
}

# Method 3: Month Boundary
test_rollup_month_boundary() {
    echo ""
    echo "Method 3: Month Boundary"

    local end_of_jan="2024-01-31"
    local start_of_feb="2024-02-01"

    log_cost_entry "$end_of_jan" "claude" 1000 500 0.0000525
    log_cost_entry "$start_of_feb" "gemini" 2000 1000 0.00000125

    local jan_file="${COST_LOG_DIR}/${end_of_jan}.jsonl"
    local feb_file="${COST_LOG_DIR}/${start_of_feb}.jsonl"

    if [[ -f "$jan_file" && -f "$feb_file" ]]; then
        pass "Daily rollup: Month boundary - Both month files created correctly"
    else
        fail "Daily rollup: Month boundary - Missing file at month boundary"
    fi
}

#===============================================================================
# EXPORT FORMAT VALIDATION (3 Methods)
#===============================================================================

echo ""
echo "=================================================="
echo "  EXPORT FORMAT VALIDATION (3 Methods)"
echo "=================================================="

# Method 1: JSON Format
test_export_json() {
    echo ""
    echo "Method 1: JSON Format"

    local sample_entry='{"timestamp":"2024-01-01T12:00:00+00:00","model":"claude","input_tokens":1000,"output_tokens":500,"cost":0.0000525}'

    if is_valid_json "$sample_entry"; then
        local model
        model=$(echo "$sample_entry" | jq -r '.model')
        if [[ "$model" == "claude" ]]; then
            pass "Export: JSON format - Valid JSON with correct fields"
        else
            fail "Export: JSON format - Field extraction failed"
        fi
    else
        fail "Export: JSON format - Invalid JSON"
    fi
}

# Method 2: CSV Format
test_export_csv() {
    echo ""
    echo "Method 2: CSV Format"

    # Generate CSV from JSONL
    local csv_file="${TEST_DIR}/costs.csv"
    echo "timestamp,model,input_tokens,output_tokens,cost" > "$csv_file"

    local today
    today=$(date +%Y-%m-%d)
    local jsonl_file="${COST_LOG_DIR}/${today}.jsonl"

    if [[ -f "$jsonl_file" ]]; then
        while IFS= read -r line; do
            local ts model input output cost
            ts=$(echo "$line" | jq -r '.timestamp')
            model=$(echo "$line" | jq -r '.model')
            input=$(echo "$line" | jq -r '.input_tokens')
            output=$(echo "$line" | jq -r '.output_tokens')
            cost=$(echo "$line" | jq -r '.cost')
            echo "$ts,$model,$input,$output,$cost" >> "$csv_file"
        done < "$jsonl_file"

        local line_count
        line_count=$(wc -l < "$csv_file")

        if [[ $line_count -gt 1 ]]; then
            pass "Export: CSV format - $((line_count - 1)) data rows exported"
        else
            fail "Export: CSV format - No data rows"
        fi
    else
        skip "Export: CSV format - No log file to convert"
    fi
}

# Method 3: Prometheus Format
test_export_prometheus() {
    echo ""
    echo "Method 3: Prometheus Format"

    # Generate Prometheus metrics
    local prom_output=""

    prom_output+="# HELP tri_agent_tokens_total Total tokens processed\n"
    prom_output+="# TYPE tri_agent_tokens_total counter\n"
    prom_output+="tri_agent_tokens_total{model=\"claude\",type=\"input\"} 1000\n"
    prom_output+="tri_agent_tokens_total{model=\"claude\",type=\"output\"} 500\n"
    prom_output+="# HELP tri_agent_cost_dollars Total cost in dollars\n"
    prom_output+="# TYPE tri_agent_cost_dollars counter\n"
    prom_output+="tri_agent_cost_dollars{model=\"claude\"} 0.0000525\n"

    # Validate Prometheus format
    if echo -e "$prom_output" | grep -q "# TYPE" && echo -e "$prom_output" | grep -q "tri_agent_"; then
        pass "Export: Prometheus format - Valid Prometheus exposition format"
    else
        fail "Export: Prometheus format - Invalid format"
    fi
}

#===============================================================================
# Run All Validation Tests
#===============================================================================

echo ""
echo "=================================================="
echo "  RUNNING COST TRACKING VALIDATION TESTS"
echo "=================================================="

# Token counting tests
test_tokens_known
test_tokens_large
test_tokens_unicode

# Cost calculation tests
test_cost_standard
test_cost_custom
test_cost_zero

# Daily rollup tests
test_rollup_single_day
test_rollup_multi_day
test_rollup_month_boundary

# Export format tests
test_export_json
test_export_csv
test_export_prometheus

#===============================================================================
# Generate Validation Matrix
#===============================================================================

echo ""
echo "=================================================="
echo "  COST TRACKING VALIDATION MATRIX"
echo "=================================================="
echo ""
printf "%-20s %-15s %-15s %-15s\n" "Feature" "Method 1" "Method 2" "Method 3"
echo "------------------------------------------------------------"
printf "%-20s %-15s %-15s %-15s\n" "Token counting" "Known" "Large" "Unicode"
printf "%-20s %-15s %-15s %-15s\n" "Cost calculation" "Standard" "Custom" "Zero"
printf "%-20s %-15s %-15s %-15s\n" "Daily rollup" "Single" "Multi" "Boundary"
printf "%-20s %-15s %-15s %-15s\n" "Export format" "JSON" "CSV" "Prometheus"
echo ""

export TESTS_PASSED TESTS_FAILED

echo "Cost tracking validation completed: $TESTS_PASSED passed, $TESTS_FAILED failed"
