#!/bin/bash
# =============================================================================
# cost-tracker.sh - Usage metrics tracking for tri-agent system
# =============================================================================
# Tracks usage metrics (token estimates, request counts) per model.
# Note: Subscription-based unlimited usage, these are metrics only.
#
# This file is sourced by common.sh - do not source directly
#
# Provides:
# - Per-model request counting
# - Token estimation (based on heuristics)
# - Daily aggregation
# - Usage statistics queries
# =============================================================================

# Note: This file may be sourced in strict mode (set -u)
# Ensure we have required directories with safe defaults
STATE_DIR="${STATE_DIR:-$HOME/.claude/autonomous/state}"
COST_LOG_DIR="${COST_LOG_DIR:-$HOME/.claude/autonomous/logs/costs}"
TRACE_ID="${TRACE_ID:-unknown}"

# Cost data directory
COST_STATE_DIR="${STATE_DIR}/costs"

# Ensure directories exist
mkdir -p "$COST_STATE_DIR" "$COST_LOG_DIR" 2>/dev/null || true

# =============================================================================
# Token Estimation Heuristics
# =============================================================================
# Rough estimates based on typical tokenization patterns
# Actual token counts vary by model tokenizer

# Characters per token (approximate)
CHARS_PER_TOKEN_CLAUDE=4.0
CHARS_PER_TOKEN_GEMINI=4.0
CHARS_PER_TOKEN_CODEX=3.5

# Get chars per token for a model
_get_chars_per_token() {
    local model="$1"
    case "$model" in
        claude|opus)  echo "$CHARS_PER_TOKEN_CLAUDE" ;;
        gemini|pro)   echo "$CHARS_PER_TOKEN_GEMINI" ;;
        codex|gpt)    echo "$CHARS_PER_TOKEN_CODEX" ;;
        *)            echo "4.0" ;;
    esac
}

# Estimate tokens from character count
estimate_tokens() {
    local content="$1"
    local model="${2:-claude}"
    local char_count=${#content}
    local chars_per_token
    chars_per_token=$(_get_chars_per_token "$model")

    # Use awk for portability (#116) - always available
    awk "BEGIN {printf \"%.0f\", $char_count / $chars_per_token}"
}

# =============================================================================
# State File Paths
# =============================================================================

# Get daily stats file path
_get_daily_file() {
    local date="${1:-$(date +%Y-%m-%d)}"
    echo "${COST_STATE_DIR}/daily_${date}.json"
}

# Get model stats file path
_get_model_file() {
    local model="$1"
    echo "${COST_STATE_DIR}/model_${model}.json"
}

# Get cumulative totals file
_get_totals_file() {
    echo "${COST_STATE_DIR}/totals.json"
}

# =============================================================================
# Recording Functions
# =============================================================================

# Validate numeric fields (non-negative integers only)
_validate_numeric() {
    local value="$1"
    local field="$2"

    if [[ -z "$value" ]]; then
        echo "0"
        return 1
    fi

    if [[ "$value" =~ ^[0-9]+$ ]]; then
        echo "$value"
        return 0
    fi

    if declare -f log_warn &>/dev/null; then
        log_warn "[${TRACE_ID:-unknown}] Invalid numeric value for ${field}: ${value}. Defaulting to 0." 2>/dev/null || true
    fi

    echo "0"
    return 1
}

# Record a request for a model
# Usage: record_request MODEL [INPUT_TOKENS] [OUTPUT_TOKENS] [DURATION_MS] [TASK_TYPE]
record_request() {
    local model="$1"
    local input_tokens="${2:-0}"
    local output_tokens="${3:-0}"
    local duration_ms="${4:-0}"
    local task_type="${5:-unknown}"
    local timestamp
    local date_str

    timestamp="$(date -Iseconds)"
    date_str="$(date +%Y-%m-%d)"

    input_tokens="$(_validate_numeric "$input_tokens" "input_tokens")"
    output_tokens="$(_validate_numeric "$output_tokens" "output_tokens")"
    duration_ms="$(_validate_numeric "$duration_ms" "duration_ms")"

    # Normalize model name
    case "$model" in
        claude|opus)   model="claude" ;;
        gemini|pro)    model="gemini" ;;
        codex|gpt)     model="codex" ;;
    esac

    # Create cost log entry (JSONL)
    local log_entry
    log_entry=$(cat <<EOF
{"timestamp":"${timestamp}","trace_id":"${TRACE_ID}","model":"${model}","input_tokens":${input_tokens},"output_tokens":${output_tokens},"duration_ms":${duration_ms},"task_type":"${task_type}"}
EOF
)

    # Append to daily cost log
    local cost_log="${COST_LOG_DIR}/${date_str}.jsonl"
    mkdir -p "$COST_LOG_DIR"
    echo "$log_entry" >> "$cost_log"

    # Update daily aggregates
    _update_daily_stats "$model" "$input_tokens" "$output_tokens" "$duration_ms" "$date_str"

    # Update model aggregates
    _update_model_stats "$model" "$input_tokens" "$output_tokens" "$duration_ms"

    # Update totals
    _update_totals "$model" "$input_tokens" "$output_tokens" "$duration_ms"

    # Log the record (if logging functions available)
    if declare -f log_json &>/dev/null; then
        log_json "DEBUG" "COST" "RECORD" "Recorded request for ${model}" \
            "{\"model\":\"${model}\",\"input_tokens\":${input_tokens},\"output_tokens\":${output_tokens},\"duration_ms\":${duration_ms}}"
    fi
}

# Update daily statistics atomically
_update_daily_stats() {
    local model="$1"
    local input_tokens="$2"
    local output_tokens="$3"
    local duration_ms="$4"
    local date_str="$5"
    local stats_file
    stats_file="$(_get_daily_file "$date_str")"

    # Use consolidated locking (#82)
    # Replaces explicit flock with with_lock_timeout
    local lock_name="cost_daily_${date_str}"
    
    with_lock_timeout "$lock_name" 5 _perform_daily_update "$model" "$input_tokens" "$output_tokens" "$duration_ms" "$date_str" "$stats_file"
}

_perform_daily_update() {
    local model="$1"
    local input_tokens="$2"
    local output_tokens="$3"
    local duration_ms="$4"
    local date_str="$5"
    local stats_file="$6"

    # Read existing or create new
    local existing
    if [[ -f "$stats_file" ]]; then
        existing=$(cat "$stats_file")
    else
        existing='{}'
    fi

    # Update using jq if available, otherwise Python
    if command -v jq &>/dev/null; then
        echo "$existing" | jq \
            --arg model "$model" \
            --argjson input "$input_tokens" \
            --argjson output "$output_tokens" \
            --argjson duration "$duration_ms" \
            --arg date "$date_str" \
            '\
            .date = $date |\
            .models[$model] = (\
                (.models[$model] // {"requests": 0, "input_tokens": 0, "output_tokens": 0, "total_duration_ms": 0}) |\
                .requests += 1 |\
                .input_tokens += $input |\
                .output_tokens += $output |\
                .total_duration_ms += $duration\
            ) |\
            .total_requests = ((.total_requests // 0) + 1) |\
            .total_input_tokens = ((.total_input_tokens // 0) + $input) |\
            .total_output_tokens = ((.total_output_tokens // 0) + $output) |\
            .last_updated = (now | todate)
            ' > "${stats_file}.tmp" && mv "${stats_file}.tmp" "$stats_file"
    elif command -v python3 &>/dev/null; then
        python3 - "$existing" "$model" "$input_tokens" "$output_tokens" "$duration_ms" "$date_str" "$stats_file" <<'PYEOF'
import json
import sys
from datetime import datetime

existing = json.loads(sys.argv[1]) if sys.argv[1] != '{}' else {}
model = sys.argv[2]
input_t = int(sys.argv[3])
output_t = int(sys.argv[4])
duration = int(sys.argv[5])
date_str = sys.argv[6]
out_file = sys.argv[7]

existing['date'] = date_str
if 'models' not in existing:
    existing['models'] = {}
if model not in existing['models']:
    existing['models'][model] = {'requests': 0, 'input_tokens': 0, 'output_tokens': 0, 'total_duration_ms': 0}

existing['models'][model]['requests'] += 1
existing['models'][model]['input_tokens'] += input_t
existing['models'][model]['output_tokens'] += output_t
existing['models'][model]['total_duration_ms'] += duration

existing['total_requests'] = existing.get('total_requests', 0) + 1
existing['total_input_tokens'] = existing.get('total_input_tokens', 0) + input_t
existing['total_output_tokens'] = existing.get('total_output_tokens', 0) + output_t
existing['last_updated'] = datetime.utcnow().isoformat() + 'Z'

with open(out_file, 'w') as f:
    json.dump(existing, f, indent=2)
PYEOF
    fi
}

# Update model lifetime statistics
_update_model_stats() {
    local model="$1"
    local input_tokens="$2"
    local output_tokens="$3"
    local duration_ms="$4"
    local stats_file
    stats_file="$(_get_model_file "$model")"
    
    # Use consolidated locking (#82)
    local lock_name="cost_model_${model}"
    
    with_lock_timeout "$lock_name" 5 _perform_model_update "$model" "$input_tokens" "$output_tokens" "$duration_ms" "$stats_file"
}

_perform_model_update() {
    local model="$1"
    local input_tokens="$2"
    local output_tokens="$3"
    local duration_ms="$4"
    local stats_file="$5"

    local existing
    if [[ -f "$stats_file" ]]; then
        existing=$(cat "$stats_file")
    else
        existing='{}'
    fi

    if command -v jq &>/dev/null; then
        echo "$existing" | jq \
            --arg model "$model" \
            --argjson input "$input_tokens" \
            --argjson output "$output_tokens" \
            --argjson duration "$duration_ms" \
            '\
            .model = $model |\
            .total_requests = ((.total_requests // 0) + 1) |\
            .total_input_tokens = ((.total_input_tokens // 0) + $input) |\
            .total_output_tokens = ((.total_output_tokens // 0) + $output) |\
            .total_duration_ms = ((.total_duration_ms // 0) + $duration) |\
            .avg_duration_ms = ((.total_duration_ms // 0) / ((.total_requests // 0) + 1)) |\
            .last_used = (now | todate)
            ' > "${stats_file}.tmp" && mv "${stats_file}.tmp" "$stats_file"
    elif command -v python3 &>/dev/null; then
        python3 - "$existing" "$model" "$input_tokens" "$output_tokens" "$duration_ms" "$stats_file" <<'PYEOF'
import json
import sys
from datetime import datetime

existing = json.loads(sys.argv[1]) if sys.argv[1] != '{}' else {}
model = sys.argv[2]
input_t = int(sys.argv[3])
output_t = int(sys.argv[4])
duration = int(sys.argv[5])
out_file = sys.argv[6]

existing['model'] = model
existing['total_requests'] = existing.get('total_requests', 0) + 1
existing['total_input_tokens'] = existing.get('total_input_tokens', 0) + input_t
existing['total_output_tokens'] = existing.get('total_output_tokens', 0) + output_t
existing['total_duration_ms'] = existing.get('total_duration_ms', 0) + duration
existing['avg_duration_ms'] = existing['total_duration_ms'] / existing['total_requests']
existing['last_used'] = datetime.utcnow().isoformat() + 'Z'

with open(out_file, 'w') as f:
    json.dump(existing, f, indent=2)
PYEOF
    fi
}

# Update cumulative totals
_update_totals() {
    local model="$1"
    local input_tokens="$2"
    local output_tokens="$3"
    local duration_ms="$4"
    local stats_file
    stats_file="$(_get_totals_file)"
    
    # Use consolidated locking (#82)
    local lock_name="cost_totals"
    
    with_lock_timeout "$lock_name" 5 _perform_totals_update "$model" "$input_tokens" "$output_tokens" "$duration_ms" "$stats_file"
}

_perform_totals_update() {
    local model="$1"
    local input_tokens="$2"
    local output_tokens="$3"
    local duration_ms="$4"
    local stats_file="$5"

    local existing
    if [[ -f "$stats_file" ]]; then
        existing=$(cat "$stats_file")
    else
        existing='{}'
    fi

    if command -v jq &>/dev/null; then
        echo "$existing" | jq \
            --arg model "$model" \
            --argjson input "$input_tokens" \
            --argjson output "$output_tokens" \
            --argjson duration "$duration_ms" \
            '\
            .total_requests = ((.total_requests // 0) + 1) |\
            .total_input_tokens = ((.total_input_tokens // 0) + $input) |\
            .total_output_tokens = ((.total_output_tokens // 0) + $output) |\
            .total_duration_ms = ((.total_duration_ms // 0) + $duration) |\
            .by_model[$model].requests = (((.by_model[$model].requests) // 0) + 1) |\
            .by_model[$model].input_tokens = (((.by_model[$model].input_tokens) // 0) + $input) |\
            .by_model[$model].output_tokens = (((.by_model[$model].output_tokens) // 0) + $output) |\
            .last_updated = (now | todate)
            ' > "${stats_file}.tmp" && mv "${stats_file}.tmp" "$stats_file"
    elif command -v python3 &>/dev/null; then
        python3 - "$existing" "$model" "$input_tokens" "$output_tokens" "$duration_ms" "$stats_file" <<'PYEOF'
import json
import sys
from datetime import datetime

existing = json.loads(sys.argv[1]) if sys.argv[1] != '{}' else {}
model = sys.argv[2]
input_t = int(sys.argv[3])
output_t = int(sys.argv[4])
duration = int(sys.argv[5])
out_file = sys.argv[6]

existing['total_requests'] = existing.get('total_requests', 0) + 1
existing['total_input_tokens'] = existing.get('total_input_tokens', 0) + input_t
existing['total_output_tokens'] = existing.get('total_output_tokens', 0) + output_t
existing['total_duration_ms'] = existing.get('total_duration_ms', 0) + duration

by_model = existing.get('by_model', {})
if model not in by_model:
    by_model[model] = {'requests': 0, 'input_tokens': 0, 'output_tokens': 0}

by_model[model]['requests'] += 1
by_model[model]['input_tokens'] += input_t
by_model[model]['output_tokens'] += output_t

existing['by_model'] = by_model
existing['last_updated'] = datetime.utcnow().isoformat() + 'Z'

with open(out_file, 'w') as f:
    json.dump(existing, f, indent=2)
PYEOF
    fi
}

# =============================================================================
# Query Functions
# =============================================================================

# Get daily statistics
# Usage: get_daily_stats [DATE]
get_daily_stats() {
    local date_str="${1:-$(date +%Y-%m-%d)}"
    local stats_file
    stats_file="$(_get_daily_file "$date_str")"

    if [[ -f "$stats_file" ]]; then
        cat "$stats_file"
    else
        cat <<EOF
{
    "date": "${date_str}",
    "models": {},
    "total_requests": 0,
    "total_input_tokens": 0,
    "total_output_tokens": 0,
    "message": "No data for this date"
}
EOF
    fi
}

# Get model statistics
# Usage: get_model_stats MODEL
get_model_stats() {
    local model="$1"

    # Normalize model name
    case "$model" in
        claude|opus)   model="claude" ;;
        gemini|pro)    model="gemini" ;;
        codex|gpt)     model="codex" ;;
    esac

    local stats_file
    stats_file="$(_get_model_file "$model")"

    if [[ -f "$stats_file" ]]; then
        cat "$stats_file"
    else
        cat <<EOF
{
    "model": "${model}",
    "total_requests": 0,
    "total_input_tokens": 0,
    "total_output_tokens": 0,
    "total_duration_ms": 0,
    "avg_duration_ms": 0,
    "message": "No usage data for this model"
}
EOF
    fi
}

# Get all model statistics
get_all_model_stats() {
    local models=("claude" "gemini" "codex")

    echo "{"
    echo '  "models": ['
    local first=true
    for model in "${models[@]}"; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo ","
        fi
        get_model_stats "$model" | sed 's/^/    /'
    done
    echo "  ],"
    echo "  \"generated_at\": \"$(date -Iseconds)\""
    echo "}"
}

# Get summary statistics
get_usage_summary() {
    local totals_file
    totals_file="$(_get_totals_file)"

    if [[ -f "$totals_file" ]]; then
        cat "$totals_file"
    else
        cat <<EOF
{
    "total_requests": 0,
    "total_input_tokens": 0,
    "total_output_tokens": 0,
    "total_duration_ms": 0,
    "by_model": {},
    "message": "No usage data recorded yet"
}
EOF
    fi
}

# Get stats for date range
# Usage: get_range_stats START_DATE END_DATE
get_range_stats() {
    local start_date="$1"
    local end_date="${2:-$(date +%Y-%m-%d)}"

    # List all daily files in range
    local total_requests=0
    local total_input=0
    local total_output=0
    local current="$start_date"

    local results='{"days": ['
    local first=true

    while [[ "$current" < "$end_date" ]] || [[ "$current" == "$end_date" ]]; do
        local stats
        stats=$(get_daily_stats "$current")

        if [[ "$first" == "true" ]]; then
            first=false
        else
            results+=,
        fi
        results+="$stats"

        # Aggregate
        if command -v jq &>/dev/null; then
            local day_requests day_input day_output
            day_requests=$(echo "$stats" | jq -r '.total_requests // 0')
            day_input=$(echo "$stats" | jq -r '.total_input_tokens // 0')
            day_output=$(echo "$stats" | jq -r '.total_output_tokens // 0')
            total_requests=$((total_requests + day_requests))
            total_input=$((total_input + day_input))
            total_output=$((total_output + day_output))
        fi

        # Increment date (GNU date vs BSD)
        if date --version &>/dev/null 2>&1; then
            current=$(date -d "$current + 1 day" +%Y-%m-%d)
        else
            current=$(date -j -v+1d -f "%Y-%m-%d" "$current" +%Y-%m-%d)
        fi
    done

    results+=],
    results+="\"start_date\":\"${start_date}\","
    results+="\"end_date\":\"${end_date}\","
    results+="\"total_requests\":${total_requests},"
    results+="\"total_input_tokens\":${total_input},"
    results+="\"total_output_tokens\":${total_output},"
    results+="\"generated_at\":\"$(date -Iseconds)\""
    results+='}'

    echo "$results"
}

# =============================================================================
# Reset Functions
# =============================================================================

# Reset daily stats
reset_daily_stats() {
    local date_str="${1:-$(date +%Y-%m-%d)}"
    local stats_file
    stats_file="$(_get_daily_file "$date_str")"

    if [[ -f "$stats_file" ]]; then
        rm -f "$stats_file"
        echo "Reset daily stats for ${date_str}"
    else
        echo "No stats file for ${date_str}"
    fi
}

# Reset model stats
reset_model_stats() {
    local model="$1"

    # Normalize model name
    case "$model" in
        claude|opus)   model="claude" ;;
        gemini|pro)    model="gemini" ;;
        codex|gpt)     model="codex" ;;
    esac

    local stats_file
    stats_file="$(_get_model_file "$model")"

    if [[ -f "$stats_file" ]]; then
        rm -f "$stats_file"
        echo "Reset stats for ${model}"
    else
        echo "No stats file for ${model}"
    fi
}

# Reset all stats
reset_all_stats() {
    rm -f "${COST_STATE_DIR}"/*.json 2>/dev/null || true
    rm -f "${COST_STATE_DIR}"/*.lock 2>/dev/null || true
    echo "All cost tracking stats reset"
}

# =============================================================================
# Export Functions
# =============================================================================
export -f estimate_tokens
export -f record_request
export -f get_daily_stats
export -f get_model_stats
export -f get_all_model_stats
export -f get_usage_summary
export -f get_range_stats
export -f reset_daily_stats
export -f reset_model_stats
export -f reset_all_stats
