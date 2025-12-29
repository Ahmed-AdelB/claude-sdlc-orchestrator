#!/bin/bash
# =============================================================================
# cost-breaker.sh - Cost-based circuit breaker with margin
# =============================================================================
# Prevents new requests when estimated daily cost approaches budget.
# Uses cost-tracker daily token stats + per-model token rates.
# =============================================================================

: "${STATE_DIR:=$HOME/.claude/autonomous/state}"
: "${BREAKERS_DIR:=$STATE_DIR/breakers}"
: "${CONFIG_FILE:=$HOME/.claude/autonomous/config/tri-agent.yaml}"

_cost_config_value() {
    local env_name="$1"
    local config_path="$2"
    local default="$3"
    local env_val=""
    env_val="${!env_name:-}"
    if [[ -n "$env_val" ]]; then
        echo "$env_val"
        return
    fi
    if type -t read_config >/dev/null 2>&1; then
        read_config "$config_path" "$default" "$CONFIG_FILE"
    else
        echo "$default"
    fi
}

_is_truthy() {
    case "${1:-}" in
        1|true|TRUE|yes|YES|on|ON) return 0 ;;
        *) return 1 ;;
    esac
}

_get_cost_state_file() {
    echo "${BREAKERS_DIR}/cost.state"
}

_init_cost_breaker_state() {
    mkdir -p "$BREAKERS_DIR"
    local state_file
    state_file="$(_get_cost_state_file)"
    if [[ ! -f "$state_file" ]]; then
        cat > "$state_file" <<EOF
state=CLOSED
date=$(date +%Y-%m-%d)
opened_at=0
last_checked=0
reason=
EOF
    fi
}

_read_cost_state() {
    local key="$1"
    local state_file
    state_file="$(_get_cost_state_file)"
    if [[ -f "$state_file" ]]; then
        grep -E "^${key}=" "$state_file" 2>/dev/null | head -1 | cut -d'=' -f2-
    else
        echo ""
    fi
}

_write_cost_state() {
    local state="$1"
    local date_str="$2"
    local opened_at="$3"
    local last_checked="$4"
    local reason="${5:-}"
    local state_file
    state_file="$(_get_cost_state_file)"
    mkdir -p "$BREAKERS_DIR"

    cat > "${state_file}.tmp" <<EOF
state=${state}
date=${date_str}
opened_at=${opened_at}
last_checked=${last_checked}
reason=${reason}
EOF
    mv "${state_file}.tmp" "$state_file"
}

_get_rate() {
    local model="$1"
    local kind="$2"  # input|output
    local env_key="COST_RATE_${model^^}_${kind^^}_PER_1K"
    local env_val="${!env_key:-}"
    if [[ -n "$env_val" ]]; then
        echo "$env_val"
        return
    fi
    if type -t read_config >/dev/null 2>&1; then
        read_config ".cost_limits.per_1k_tokens.${model}.${kind}" "0" "$CONFIG_FILE"
    else
        echo "0"
    fi
}

estimate_request_cost() {
    local model="$1"
    local input_tokens="${2:-0}"
    local output_tokens="${3:-0}"

    local rate_in rate_out
    rate_in=$(_get_rate "$model" "input")
    rate_out=$(_get_rate "$model" "output")

    if [[ -z "$rate_in" || -z "$rate_out" ]]; then
        echo "0"
        return
    fi

    awk "BEGIN {printf \"%.6f\", ($input_tokens/1000.0)*$rate_in + ($output_tokens/1000.0)*$rate_out}"
}

_daily_stats_file() {
    local date_str="${1:-$(date +%Y-%m-%d)}"
    echo "${STATE_DIR}/costs/daily_${date_str}.json"
}

_read_tokens() {
    local file="$1"
    local model="$2"
    local field="$3"
    if command -v jq &>/dev/null; then
        jq -r --arg model "$model" --arg field "$field" '.models[$model][$field] // 0' "$file" 2>/dev/null || echo "0"
    elif command -v python3 &>/dev/null; then
        python3 - "$file" "$model" "$field" <<'PYEOF'
import json
import sys
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    model = sys.argv[2]
    field = sys.argv[3]
    print(int(data.get("models", {}).get(model, {}).get(field, 0)))
except Exception:
    print(0)
PYEOF
    else
        echo "0"
    fi
}

calculate_daily_spend() {
    local date_str="${1:-$(date +%Y-%m-%d)}"
    local file
    file="$(_daily_stats_file "$date_str")"

    if [[ ! -f "$file" ]]; then
        echo "0"
        return
    fi

    local total=0
    local model
    for model in claude gemini codex; do
        local in_t out_t rate_in rate_out
        in_t=$(_read_tokens "$file" "$model" "input_tokens")
        out_t=$(_read_tokens "$file" "$model" "output_tokens")
        rate_in=$(_get_rate "$model" "input")
        rate_out=$(_get_rate "$model" "output")
        local cost
        cost=$(awk "BEGIN {printf \"%.6f\", ($in_t/1000.0)*$rate_in + ($out_t/1000.0)*$rate_out}")
        total=$(awk "BEGIN {printf \"%.6f\", $total + $cost}")
    done

    echo "$total"
}

cost_breaker_should_allow() {
    local model="$1"
    local input_tokens="${2:-0}"
    local output_tokens="${3:-0}"

    _init_cost_breaker_state

    local enabled budget margin reserve
    enabled=$(_cost_config_value "COST_BREAKER_ENABLED" ".cost_limits.enabled" "false")
    budget=$(_cost_config_value "COST_DAILY_BUDGET_USD" ".cost_limits.daily_budget_usd" "0")
    margin=$(_cost_config_value "COST_BREAKER_MARGIN_PCT" ".cost_limits.margin_pct" "0.15")
    reserve=$(_cost_config_value "COST_BREAKER_RESERVE_USD" ".cost_limits.reserve_usd" "1.0")

    if ! _is_truthy "$enabled"; then
        return 0
    fi

    if [[ -z "$budget" || "$budget" == "0" ]]; then
        return 0
    fi

    local today
    today=$(date +%Y-%m-%d)
    local state
    state=$(_read_cost_state "state")
    local state_date
    state_date=$(_read_cost_state "date")

    if [[ "$state_date" != "$today" ]]; then
        _write_cost_state "CLOSED" "$today" 0 "$(date +%s)" ""
        state="CLOSED"
    fi

    if [[ "$state" == "OPEN" ]]; then
        return 1
    fi

    local daily_spend
    daily_spend=$(calculate_daily_spend "$today")
    local request_cost
    request_cost=$(estimate_request_cost "$model" "$input_tokens" "$output_tokens")

    local threshold
    threshold=$(awk "BEGIN {printf \"%.6f\", $budget * (1 - $margin)}")
    local projected
    projected=$(awk "BEGIN {printf \"%.6f\", $daily_spend + $request_cost + $reserve}")

    if awk "BEGIN {exit !($projected >= $threshold)}"; then
        _write_cost_state "OPEN" "$today" "$(date +%s)" "$(date +%s)" "budget_guardrail"
        return 1
    fi

    _write_cost_state "CLOSED" "$today" 0 "$(date +%s)" ""
    return 0
}

get_cost_breaker_status() {
    _init_cost_breaker_state
    local state
    state=$(_read_cost_state "state")
    local date_str
    date_str=$(_read_cost_state "date")
    local last_checked
    last_checked=$(_read_cost_state "last_checked")
    local opened_at
    opened_at=$(_read_cost_state "opened_at")
    local reason
    reason=$(_read_cost_state "reason")

    cat <<EOF
{
    "state": "${state:-CLOSED}",
    "date": "${date_str}",
    "opened_at": ${opened_at:-0},
    "last_checked": ${last_checked:-0},
    "reason": "${reason}"
}
EOF
}

reset_cost_breaker() {
    _write_cost_state "CLOSED" "$(date +%Y-%m-%d)" 0 "$(date +%s)" ""
}

export -f estimate_request_cost
export -f calculate_daily_spend
export -f cost_breaker_should_allow
export -f get_cost_breaker_status
export -f reset_cost_breaker
