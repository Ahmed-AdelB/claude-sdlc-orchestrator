#!/bin/bash
# =============================================================================
# event-store.sh - Append-only event sourcing with projections
# =============================================================================
# Provides:
# - Append-only event log (JSONL)
# - Projection rebuilding
# - Time-travel queries (since/until)
#
# This file is safe to source from common.sh or other scripts.
# It defines functions only and performs no actions on import.
# =============================================================================

: "${AUTONOMOUS_ROOT:=${HOME}/.claude/autonomous}"
: "${STATE_DIR:=${AUTONOMOUS_ROOT}/state}"

EVENT_STORE_DIR="${EVENT_STORE_DIR:-${STATE_DIR}/event-store}"
EVENT_LOG_FILE="${EVENT_LOG_FILE:-${EVENT_STORE_DIR}/events.jsonl}"
EVENT_PROJECTIONS_DIR="${EVENT_PROJECTIONS_DIR:-${EVENT_STORE_DIR}/projections}"
EVENT_SCHEMA_VERSION="${EVENT_SCHEMA_VERSION:-1}"

_event_log() {
    local level="$1"
    shift
    if type -t log_info >/dev/null 2>&1; then
        case "$level" in
            INFO) log_info "$*" ;;
            WARN) log_warn "$*" ;;
            ERROR) log_error "$*" ;;
            *) log_info "$*" ;;
        esac
    else
        echo "[$level] $*" >&2
    fi
}

_event_ensure_dir() {
    local dir="$1"
    if type -t ensure_dir >/dev/null 2>&1; then
        ensure_dir "$dir"
    else
        mkdir -p "$dir"
    fi
}

_event_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen
    else
        echo "evt-$(date +%Y%m%d%H%M%S)-${RANDOM}${RANDOM}"
    fi
}

_event_now() {
    if type -t iso_timestamp >/dev/null 2>&1; then
        iso_timestamp
    else
        date -Iseconds
    fi
}

_event_is_valid_json() {
    local json="$1"
    if [[ -z "$json" ]]; then
        return 1
    fi
    if command -v jq >/dev/null 2>&1; then
        printf '%s' "$json" | jq . >/dev/null 2>&1
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "import json,sys; json.loads(sys.stdin.read())" <<< "$json" >/dev/null 2>&1
    else
        return 1
    fi
}

_event_json_escape() {
    local input="$1"
    if command -v python3 >/dev/null 2>&1; then
        printf '%s' "$input" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))"
    else
        local escaped
        escaped=$(printf '%s' "$input" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e ':a;N;$!ba;s/\n/\\n/g')
        printf '"%s"' "$escaped"
    fi
}

_event_normalize_payload() {
    local payload="$1"
    if _event_is_valid_json "$payload"; then
        printf '%s' "$payload"
    else
        local escaped
        escaped=$(_event_json_escape "$payload")
        printf '{"message":%s}' "$escaped"
    fi
}

_event_normalize_metadata() {
    local metadata="$1"
    if _event_is_valid_json "$metadata"; then
        printf '%s' "$metadata"
    else
        printf '{}'
    fi
}

event_store_init() {
    _event_ensure_dir "$EVENT_STORE_DIR"
    _event_ensure_dir "$EVENT_PROJECTIONS_DIR"

    if [[ ! -f "$EVENT_LOG_FILE" ]]; then
        touch "$EVENT_LOG_FILE"
    fi

    local schema_file="${EVENT_STORE_DIR}/schema.json"
    if [[ ! -f "$schema_file" ]]; then
        cat > "$schema_file" <<SCHEMAEOF
{"version":${EVENT_SCHEMA_VERSION},"created_at":"$(_event_now)"}
SCHEMAEOF
    fi
}

event_append() {
    local event_type="$1"
    local payload="${2:-{}}"
    local metadata="${3:-{}}"

    event_store_init

    local event_id
    event_id=$(_event_uuid)
    local ts
    ts=$(_event_now)

    local payload_json
    payload_json=$(_event_normalize_payload "$payload")
    local metadata_json
    metadata_json=$(_event_normalize_metadata "$metadata")

    local event_json
    event_json=$(cat <<EVENTEOF
{"id":"${event_id}","type":"${event_type}","timestamp":"${ts}","payload":${payload_json},"metadata":${metadata_json},"trace_id":"${TRACE_ID:-}"}
EVENTEOF
)

    if command -v flock >/dev/null 2>&1; then
        (flock -x 200; echo "$event_json" >> "$EVENT_LOG_FILE") 200>"${EVENT_LOG_FILE}.lock"
    else
        echo "$event_json" >> "$EVENT_LOG_FILE"
    fi

    echo "$event_json"
}

event_store_stats() {
    event_store_init
    local count
    count=$(wc -l < "$EVENT_LOG_FILE" | tr -d ' ')
    echo "$count"
}

_event_query_with_jq() {
    local since="$1"
    local until="$2"
    local type_filter="$3"

    jq -c --arg since "$since" --arg until "$until" --arg type "$type_filter" '
        select((($since == "") or (.timestamp >= $since)) and
               (($until == "") or (.timestamp <= $until)) and
               (($type == "") or (.type == $type)))
    '
}

_event_query_with_python() {
    local since="$1"
    local until="$2"
    local type_filter="$3"

    python3 - "$since" "$until" "$type_filter" <<'PY'
import json
import sys
since = sys.argv[1]
until = sys.argv[2]
type_filter = sys.argv[3]
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        obj = json.loads(line)
    except Exception:
        continue
    ts = obj.get("timestamp", "")
    if since and ts < since:
        continue
    if until and ts > until:
        continue
    if type_filter and obj.get("type") != type_filter:
        continue
    print(line)
PY
}

event_store_query() {
    local since="${1:-}"
    local until="${2:-}"
    local type_filter="${3:-}"
    local limit="${4:-}"

    event_store_init

    local filter_cmd=""
    if command -v jq >/dev/null 2>&1; then
        filter_cmd="_event_query_with_jq"
    elif command -v python3 >/dev/null 2>&1; then
        filter_cmd="_event_query_with_python"
    else
        _event_log WARN "No JSON parser available; returning raw events"
        cat "$EVENT_LOG_FILE" | head -n "${limit:-1000000}"
        return 0
    fi

    if [[ -n "$limit" ]]; then
        "$filter_cmd" "$since" "$until" "$type_filter" < "$EVENT_LOG_FILE" | head -n "$limit"
    else
        "$filter_cmd" "$since" "$until" "$type_filter" < "$EVENT_LOG_FILE"
    fi
}

event_store_time_travel() {
    local at_timestamp="$1"
    local type_filter="${2:-}"
    local limit="${3:-}"
    event_store_query "" "$at_timestamp" "$type_filter" "$limit"
}

event_projection_handler_count_by_type() {
    local state_json="$1"
    local event_json="$2"

    if command -v jq >/dev/null 2>&1; then
        local event_type
        event_type=$(printf '%s' "$event_json" | jq -r '.type // "unknown"')
        printf '%s' "$state_json" | jq --arg t "$event_type" '.[$t] = (.[$t] // 0) + 1'
    else
        if command -v python3 >/dev/null 2>&1; then
            python3 - "$state_json" "$event_json" <<'PY'
import json
import sys
state = json.loads(sys.argv[1]) if sys.argv[1] else {}
event = json.loads(sys.argv[2])
type_ = event.get("type", "unknown")
state[type_] = state.get(type_, 0) + 1
print(json.dumps(state))
PY
        else
            printf '%s' "$state_json"
        fi
    fi
}

event_projection_rebuild() {
    local projection_name="$1"
    local handler="${2:-event_projection_handler_count_by_type}"

    if [[ -z "$projection_name" ]]; then
        _event_log ERROR "Projection name required"
        return 1
    fi

    if ! type -t "$handler" >/dev/null 2>&1; then
        _event_log ERROR "Handler not found: $handler"
        return 1
    fi

    event_store_init

    local state="{}"
    local count=0

    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        state=$($handler "$state" "$line") || true
        count=$((count + 1))
    done < "$EVENT_LOG_FILE"

    local projection_file="${EVENT_PROJECTIONS_DIR}/${projection_name}.json"
    cat > "$projection_file" <<PROJEOF
{"projection":"${projection_name}","rebuilt_at":"$(_event_now)","event_count":${count},"state":${state}}
PROJEOF

    echo "$projection_file"
}
# =============================================================================
# M3-020: Event store API implementation
# =============================================================================

append_event() {
    # Wrapper for event_append to satisfy M3-020 naming and thread-safety
    event_append "$@"
}

replay_events() {
    local handler="$1"
    local state="${2:-{}}"
    local type_filter="$3"

    event_store_init

    # Create a temporary file for event stream to avoid pipe subshell issues
    local tmp_stream
    tmp_stream=$(mktemp) || return 1
    
    if [[ -n "$type_filter" ]]; then
        event_store_query "" "" "$type_filter" "" > "$tmp_stream"
    else
        cat "$EVENT_LOG_FILE" > "$tmp_stream"
    fi

    # Process events
    while IFS= read -r event_json; do
        [[ -n "$event_json" ]] || continue
        # Verify JSON validity to prevent injection or errors
        if _event_is_valid_json "$event_json"; then
            state=$("$handler" "$state" "$event_json")
        fi
    done < "$tmp_stream"

    rm -f "$tmp_stream"
    echo "$state"
}

get_projection() {
    local name="$1"
    local projection_file="${EVENT_PROJECTIONS_DIR}/${name}.json"
    
    if [[ -f "$projection_file" ]]; then
        if command -v jq >/dev/null 2>&1; then
             jq -c '.state' "$projection_file"
        elif command -v python3 >/dev/null 2>&1; then
             python3 -c "import json,sys; data=json.load(open('$projection_file')); print(json.dumps(data.get('state', {})))"
        else
             cat "$projection_file"
        fi
    else
        echo "{}"
    fi
}
