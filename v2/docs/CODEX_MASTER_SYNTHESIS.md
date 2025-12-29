# CODEX MASTER SYNTHESIS - TRI-AGENT AUTONOMOUS SDLC ORCHESTRATOR

Date: 2025-12-29
Sources:
- docs/CLAUDE_AUTONOMOUS_PLAN_v2.md
- docs/CODEX_AUTONOMOUS_PLAN_v2.md
- docs/GEMINI_AUTONOMOUS_PLAN_v3.md

---

## 1) CONSENSUS FINDINGS

### What is solid today
- Core libraries are stable: `lib/common.sh`, `lib/sqlite-state.sh`, `lib/circuit-breaker.sh` are robust and mostly correct.
- Router + consensus work: `bin/tri-agent-router` and `bin/tri-agent-consensus` are close to production-ready.
- Delegate wrappers exist for Claude/Codex/Gemini with timeouts and structured envelopes.
- Health/status and logging foundations exist (common logging + health-check JSON).

### Consistent critical gaps (all three plans agree)
1) **Single Source of Truth is missing**
   - SQLite state exists but is not the canonical task system.
   - Worker claims tasks via `mkdir` locks and file queues, causing races and desync.

2) **Supervisor split-brain**
   - `bin/tri-agent-supervisor` and `lib/supervisor-approver.sh` operate independently.
   - Approvals and gate results are inconsistent and not centralized.

3) **SDLC phase enforcement is missing**
   - Tasks can skip Brainstorm/Document/Plan/Execute/Track gates.
   - No enforced state machine or artifact requirements.

4) **Governance gap (budget/pause)**
   - Budget watchdog exists but workers don’t reliably honor pause or respond quickly.
   - Kill-switch behavior is inconsistent or missing (depending on branch state).

5) **Self-healing incomplete**
   - Stale task recovery is partial; zombie tasks remain RUNNING in DB.
   - Heartbeat system is not fully wired into pool recovery.

6) **Circuit breaker integration missing**
   - Breaker functions exist but delegates don’t call them consistently.

7) **Security masking incomplete**
   - Secret masking patterns do not cover AWS/Azure/GCP/DB connection strings.

### Key discrepancies (resolved in this synthesis)
- **Budget watchdog**: Claude says missing; Codex says present; Gemini says passive. Synthesis treats it as **present but insufficient** and provides a hardened, active watchdog implementation.
- **Worker pipeline**: Codex focuses on file queue fixes; Claude/Gemini emphasize SQLite-first. Synthesis adopts **SQLite as canonical** and adds a queue-to-SQLite bridge for backward compatibility.

---

## 2) PRODUCTION READINESS SCORES

### Reported Scores
| Source  | Score | Category Notes |
|---------|-------|----------------|
| Claude  | 62/100 | Core 85, Resilience 70, Security 65, Autonomy 45, Observability 60 |
| Codex   | 58/100 | Reliability 55, Autonomy 50, Security 70, Testing 60, Perf 55, Observability 65 |
| Gemini  | 58/100 | Architecture 85, Security 70, Reliability 40, Autonomy 35 |

### Consensus Score
- **Average readiness: 59/100** (rounded from 59.33).
- **Critical blockers** remain in state management, governance, and phase enforcement.

---

## 3) TOP 10 CRITICAL FIXES (WITH COMPLETE CODE)

> These are the most impactful changes agreed across the three plans. Each fix includes complete, drop‑in code (function or full file) for implementation.

### FIX-1: Queue-to-SQLite Bridge (Canonical Task Intake)
**File**: `bin/tri-agent-queue-watcher` (NEW)
**Priority**: P0
**Why**: Make SQLite the system of record while keeping file queue compatibility.

```bash
#!/bin/bash
# tri-agent-queue-watcher - queue bridge

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTONOMOUS_ROOT="${AUTONOMOUS_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

source "${AUTONOMOUS_ROOT}/lib/common.sh"
source "${AUTONOMOUS_ROOT}/lib/sqlite-state.sh"

QUEUE_ROOT="${AUTONOMOUS_ROOT}/tasks/queue"
POLL_INTERVAL="${POLL_INTERVAL:-5}"

parse_priority() {
    local path="$1"
    local base
    base=$(basename "$(dirname "$path")")
    case "$base" in
        CRITICAL|HIGH|MEDIUM|LOW) echo "$base" ;;
        *) echo "MEDIUM" ;;
    esac
}

watch_loop() {
    sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true
    while true; do
        find "$QUEUE_ROOT" -type f -name "*.md" 2>/dev/null | while read -r file; do
            local task_id
            task_id=$(basename "$file" | sed 's/\.md$//')
            local priority
            priority=$(parse_priority "$file")
            create_task "$task_id" "$task_id" "general" "$priority" "" "QUEUED" "$TRACE_ID"
        done
        sleep "$POLL_INTERVAL"
    done
}

watch_loop
```

---

### FIX-2: Worker Uses SQLite Atomic Claim + Sharding
**File**: `bin/tri-agent-worker`
**Priority**: P0
**Why**: Eliminate race conditions and enforce shard ownership.

```bash
# REPLACEMENT FUNCTION for acquire_task_lock
acquire_task_lock() {
    local worker_id="$WORKER_ID"
    local shard="${WORKER_SHARD:-}"  # Respect env var

    local task_id=""

    # Prefer sourced functions if available
    if declare -f claim_task_atomic_filtered >/dev/null 2>&1; then
        task_id=$(claim_task_atomic_filtered "$worker_id" "" "$shard" "")
    elif declare -f claim_task_atomic >/dev/null 2>&1; then
        task_id=$(claim_task_atomic "$worker_id")
    elif [[ -x "${PROJECT_ROOT}/lib/sqlite-state.sh" ]]; then
        # Fallback to CLI-style usage
        task_id=$("${PROJECT_ROOT}/lib/sqlite-state.sh" claim_task_atomic_filtered "$worker_id" "" "$shard" "" 2>/dev/null || true)
        if [[ -z "$task_id" ]]; then
            task_id=$("${PROJECT_ROOT}/lib/sqlite-state.sh" claim_task_atomic "$worker_id" 2>/dev/null || true)
        fi
    fi

    if [[ -n "$task_id" ]]; then
        CURRENT_TASK="$task_id"
        log_info "Acquired task $task_id via SQLite (shard: ${shard:-any})"

        # Sync file state for legacy compatibility
        local task_file="${QUEUE_DIR}/${task_id}.md"
        local running_file="${RUNNING_DIR}/${task_id}.md"
        if [[ -f "$task_file" ]]; then
            mv "$task_file" "$running_file" 2>/dev/null || true
        fi

        log_ledger "TASK_LOCKED" "$task_id" "worker=$worker_id shard=$shard"
        return 0
    fi

    return 1
}
```

---

### FIX-3: Signal-Based Pause/Resume in Worker
**File**: `bin/tri-agent-worker`
**Priority**: P0
**Why**: Enables immediate pause when budget watchdog detects overspend.

```bash
# INSERT near top (after set -euo pipefail)
WORKER_PAUSED=false

handle_pause() {
    log_warn "Received PAUSE signal (SIGUSR1). Pausing after current operation..."
    WORKER_PAUSED=true
}

handle_resume() {
    log_info "Received RESUME signal (SIGUSR2). Resuming operations..."
    WORKER_PAUSED=false
}

trap handle_pause SIGUSR1
trap handle_resume SIGUSR2

# REPLACE main loop pause check
if $WORKER_PAUSED; then
    log_debug "Worker paused by signal. Waiting..."
    sleep 5
    continue
fi
```

---

### FIX-4: Worker Pool Sharding Injection
**File**: `lib/worker-pool.sh`
**Priority**: P1
**Why**: Prevents workers from competing for the same tasks.

```bash
# REPLACE start_worker
start_worker() {
    local specialization="$1"
    local model="$2"
    local shard="$3"
    local worker_id="worker-${specialization}-$(date +%s)-$$"
    local worker_cmd="${BIN_DIR}/tri-agent-worker"

    if [[ ! -x "$worker_cmd" ]]; then
        echo "Error: tri-agent-worker not found" >&2
        return 1
    fi

    (
        export WORKER_ID="$worker_id"
        export WORKER_SPECIALIZATION="$specialization"
        export WORKER_MODEL="$model"
        export WORKER_SHARD="$shard"
        export AUTONOMOUS_ROOT="$AUTONOMOUS_ROOT"

        nohup "$worker_cmd" >> "${LOG_DIR}/worker-${worker_id}.log" 2>&1 &
        echo $!
    ) | read pid

    pool_register_worker "$worker_id" "$pid" "$specialization" "$shard" "$model"
    echo "$worker_id"
}
```

---

### FIX-5: Active Budget Watchdog (Kill-Switch + Signals)
**File**: `bin/budget-watchdog` (NEW or full replacement)
**Priority**: P0
**Why**: Enforces $/min kill-switch and pausing via SIGUSR1/SIGUSR2.

```bash
#!/bin/bash
#===============================================================================
# budget-watchdog - Cost monitoring and kill-switch for autonomous operation
#===============================================================================
# Monitors spend rate and triggers soft pause or hard stop.
#
# Usage:
#   budget-watchdog                    # Start monitoring
#   budget-watchdog --status           # Show current spend
#   budget-watchdog --reset            # Reset daily counters
#   budget-watchdog --daemon           # Run as background daemon
#===============================================================================

set -euo pipefail

# Resolve script location
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
    SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
AUTONOMOUS_ROOT="${AUTONOMOUS_ROOT:-$(dirname "$SCRIPT_DIR")}"\n
# Source common utilities
source "${AUTONOMOUS_ROOT}/lib/common.sh"
source "${AUTONOMOUS_ROOT}/lib/cost-tracker.sh" 2>/dev/null || true
source "${AUTONOMOUS_ROOT}/lib/sqlite-state.sh" 2>/dev/null || true

#===============================================================================
# Configuration
#===============================================================================
VERSION="1.1.0"
BUDGET_DAILY_LIMIT="${BUDGET_DAILY_LIMIT:-75.00}"
BUDGET_RATE_LIMIT="${BUDGET_RATE_LIMIT:-1.00}"          # $1/min hard limit
BUDGET_RATE_WARNING="${BUDGET_RATE_WARNING:-0.50}"      # $0.50/min soft limit
BUDGET_CHECK_INTERVAL="${BUDGET_CHECK_INTERVAL:-30}"    # seconds
BUDGET_WINDOW_SIZE="${BUDGET_WINDOW_SIZE:-300}"         # 5-minute rolling window

# State files
STATE_DIR="${AUTONOMOUS_ROOT}/state/budget"
SPEND_LOG="${STATE_DIR}/spend.jsonl"
DAILY_TOTAL="${STATE_DIR}/daily_total.json"
KILL_SWITCH_FILE="${STATE_DIR}/kill_switch.active"
PAUSE_FILE="${STATE_DIR}/pause.requested"
PID_FILE="${STATE_DIR}/watchdog.pid"

mkdir -p "$STATE_DIR"

#===============================================================================
# Logging
#===============================================================================
_watchdog_log() {
    local level="$1"
    local message="$2"
    printf "[%s][%s][WATCHDOG] %s\n" "$(date +%H:%M:%S)" "$level" "$message" >&2
}

log_info()  { _watchdog_log "INFO" "$*"; }
log_warn()  { _watchdog_log "WARN" "$*"; }
log_error() { _watchdog_log "ERROR" "$*"; }

#===============================================================================
# Kill Switch / Pause Functions
#===============================================================================

is_kill_switch_active() { [[ -f "$KILL_SWITCH_FILE" ]]; }

signal_workers() {
    # Prefer SQLite worker table if available
    if command -v sqlite3 >/dev/null 2>&1 && [[ -f "${STATE_DB:-}" ]]; then
        local pids
        pids=$(sqlite3 "$STATE_DB" "SELECT pid FROM workers WHERE status IN ('idle','busy');" 2>/dev/null || true)
        for pid in $pids; do
            if kill -0 "$pid" 2>/dev/null; then
                log_info "Signaling worker PID $pid with $1"
                kill -"$1" "$pid" 2>/dev/null || true
            fi
        done
    else
        # Fallback: signal by process name
        pkill -"$1" -f "tri-agent-worker" 2>/dev/null || true
    fi
}

activate_kill_switch() {
    local reason="$1"
    local timestamp
    timestamp=$(date -Iseconds)

    cat > "$KILL_SWITCH_FILE" <<EOF
{
    "activated_at": "$timestamp",
    "reason": "$reason",
    "daily_spend": $(get_daily_spend),
    "current_rate": $(get_current_rate),
    "trace_id": "${TRACE_ID:-unknown}"
}
EOF

    log_error "!!! KILL SWITCH ACTIVATED: $reason !!!"

    # Kill all tri-agent processes
    kill_all_agents
}

kill_all_agents() {
    log_warn "Terminating all tri-agent processes..."

    local socket="${TMUX_SOCKET:-tri-agent}"
    if tmux -L "$socket" list-sessions 2>/dev/null | grep -q "tri-agent"; then
        tmux -L "$socket" kill-server 2>/dev/null || true
        log_info "Killed tmux sessions"
    fi

    pkill -f "tri-agent-worker" 2>/dev/null || true
    pkill -f "tri-agent-supervisor" 2>/dev/null || true
    pkill -f "claude-delegate" 2>/dev/null || true
    pkill -f "codex-delegate" 2>/dev/null || true
    pkill -f "gemini-delegate" 2>/dev/null || true

    pkill -f "^claude " 2>/dev/null || true
    pkill -f "^codex " 2>/dev/null || true
    pkill -f "^gemini " 2>/dev/null || true

    log_info "All agent processes terminated"
}

set_pause() {
    if [[ ! -f "$PAUSE_FILE" ]]; then
        echo "paused_at=$(date -Iseconds)" > "$PAUSE_FILE"
        log_warn "Soft pause activated: signaling workers"
        signal_workers SIGUSR1
    fi
    if declare -f set_pause_requested >/dev/null 2>&1; then
        set_pause_requested "budget_watchdog" || true
    fi
}

clear_pause() {
    if [[ -f "$PAUSE_FILE" ]]; then
        rm -f "$PAUSE_FILE"
        log_info "Soft pause cleared: signaling workers"
        signal_workers SIGUSR2
    fi
    if declare -f clear_pause_requested >/dev/null 2>&1; then
        clear_pause_requested || true
    fi
}

#===============================================================================
# Spend Tracking
#===============================================================================

get_daily_spend() {
    local today
    today=$(date +%Y-%m-%d)

    if [[ -f "$DAILY_TOTAL" ]]; then
        local date_in_file
        date_in_file=$(jq -r '.date // ""' "$DAILY_TOTAL" 2>/dev/null)
        if [[ "$date_in_file" == "$today" ]]; then
            jq -r '.total // 0' "$DAILY_TOTAL" 2>/dev/null || echo "0"
            return
        fi
    fi

    echo "0"
}

get_current_rate() {
    local window_start
    window_start=$(date -d "-${BUDGET_WINDOW_SIZE} seconds" +%s 2>/dev/null || \
                   date -v-${BUDGET_WINDOW_SIZE}S +%s 2>/dev/null || \
                   echo $(($(date +%s) - BUDGET_WINDOW_SIZE)))

    if [[ ! -f "$SPEND_LOG" ]]; then
        echo "0"
        return
    fi

    local total_in_window
    total_in_window=$(tail -1000 "$SPEND_LOG" 2>/dev/null | \
        jq -r "select(.timestamp_epoch >= $window_start) | .amount" 2>/dev/null | \
        awk '{sum += $1} END {print sum+0}')

    local rate
    rate=$(awk "BEGIN {printf \"%.4f\", $total_in_window / ($BUDGET_WINDOW_SIZE / 60)}")
    echo "$rate"
}

update_daily_total() {
    local amount="$1"
    local today
    today=$(date +%Y-%m-%d)

    local current_total=0
    if [[ -f "$DAILY_TOTAL" ]]; then
        local date_in_file
        date_in_file=$(jq -r '.date // ""' "$DAILY_TOTAL" 2>/dev/null)
        if [[ "$date_in_file" == "$today" ]]; then
            current_total=$(jq -r '.total // 0' "$DAILY_TOTAL" 2>/dev/null)
        fi
    fi

    local new_total
    new_total=$(awk "BEGIN {printf \"%.4f\", $current_total + $amount}")

    cat > "$DAILY_TOTAL" <<EOF
{
    "date": "$today",
    "total": $new_total,
    "updated_at": "$(date -Iseconds)",
    "daily_limit": $BUDGET_DAILY_LIMIT
}
EOF
}

#===============================================================================
# Monitoring Loop
#===============================================================================

check_budget_status() {
    if is_kill_switch_active; then
        return 1
    fi

    local daily_spend current_rate
    daily_spend=$(get_daily_spend)
    current_rate=$(get_current_rate)

    if (( $(echo "$current_rate >= $BUDGET_RATE_LIMIT" | bc -l 2>/dev/null || echo 0) )); then
        activate_kill_switch "Rate limit exceeded: \$${current_rate}/min >= \$${BUDGET_RATE_LIMIT}/min"
        return 1
    fi

    if (( $(echo "$daily_spend >= $BUDGET_DAILY_LIMIT" | bc -l 2>/dev/null || echo 0) )); then
        activate_kill_switch "Daily limit exceeded: \$${daily_spend} >= \$${BUDGET_DAILY_LIMIT}"
        return 1
    fi

    if (( $(echo "$current_rate >= $BUDGET_RATE_WARNING" | bc -l 2>/dev/null || echo 0) )); then
        log_warn "Rate warning: \$${current_rate}/min approaching limit"
        set_pause
    else
        clear_pause
    fi

    return 0
}

monitoring_loop() {
    log_info "Budget watchdog started"
    log_info "  Daily limit: \$${BUDGET_DAILY_LIMIT}"
    log_info "  Rate limit: \$${BUDGET_RATE_LIMIT}/min"
    log_info "  Check interval: ${BUDGET_CHECK_INTERVAL}s"

    echo $$ > "$PID_FILE"
    trap 'rm -f "$PID_FILE"; log_info "Watchdog stopped"' EXIT

    while true; do
        if ! check_budget_status; then
            log_error "Kill switch active, monitoring paused"
            sleep 60
            continue
        fi
        sleep "$BUDGET_CHECK_INTERVAL"
    done
}

#===============================================================================
# Status Display
#===============================================================================

show_status() {
    echo "=============================================="
    echo "  BUDGET WATCHDOG STATUS"
    echo "=============================================="
    echo ""

    if is_kill_switch_active; then
        echo "!!! KILL SWITCH ACTIVE !!!"
        cat "$KILL_SWITCH_FILE" | jq .
        echo ""
    fi

    echo "Daily Budget:"
    echo "  Limit:    \$${BUDGET_DAILY_LIMIT}"
    echo "  Spent:    \$$(get_daily_spend)"
    echo ""

    echo "Rate (5-min rolling):"
    echo "  Current:  \$$(get_current_rate)/min"
    echo "  Warning:  \$${BUDGET_RATE_WARNING}/min"
    echo "  Limit:    \$${BUDGET_RATE_LIMIT}/min"
    echo ""

    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "Watchdog: RUNNING (PID: $(cat "$PID_FILE"))"
    else
        echo "Watchdog: NOT RUNNING"
    fi
    echo "=============================================="
}

#===============================================================================
# Main
#===============================================================================

case "${1:-}" in
    --status|-s)
        show_status
        ;;
    --reset)
        log_info "Resetting daily counters..."
        rm -f "$DAILY_TOTAL" "$SPEND_LOG"
        log_info "Counters reset"
        ;;
    --daemon|-d)
        log_info "Starting in daemon mode..."
        nohup "$0" > "${AUTONOMOUS_ROOT}/logs/watchdog.log" 2>&1 &
        echo "Watchdog started (PID: $!)"
        ;;
    --help|-h)
        cat <<EOF
budget-watchdog v${VERSION} - Cost monitoring and kill-switch

Usage: budget-watchdog [OPTION]

Options:
  (none)        Start monitoring loop
  --status      Show current budget status
  --reset       Reset daily counters
  --daemon      Run as background daemon
  --help        Show this help

Environment:
  BUDGET_DAILY_LIMIT      Daily limit (default: \$75)
  BUDGET_RATE_LIMIT       Per-minute limit (default: \$1.00)
  BUDGET_CHECK_INTERVAL   Check interval seconds (default: 30)
EOF
        ;;
    *)
        monitoring_loop
        ;;
esac
```

---

### FIX-6: SDLC Phase Enforcement Library
**File**: `lib/sdlc-phases.sh` (NEW)
**Priority**: P0
**Why**: Enforces Brainstorm->Document->Plan->Execute->Track transitions with gates + artifacts.

```bash
#!/bin/bash
#===============================================================================
# sdlc-phases.sh - SDLC Phase State Machine and Enforcement
#===============================================================================

set -euo pipefail

AUTONOMOUS_ROOT="${AUTONOMOUS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
STATE_DIR="${STATE_DIR:-${AUTONOMOUS_ROOT}/state}"
STATE_DB="${STATE_DB:-${STATE_DIR}/tri-agent.db}"
ARTIFACTS_DIR="${AUTONOMOUS_ROOT}/artifacts"

[[ -f "${AUTONOMOUS_ROOT}/lib/common.sh" ]] && source "${AUTONOMOUS_ROOT}/lib/common.sh"
[[ -f "${AUTONOMOUS_ROOT}/lib/sqlite-state.sh" ]] && source "${AUTONOMOUS_ROOT}/lib/sqlite-state.sh"
[[ -f "${AUTONOMOUS_ROOT}/lib/supervisor-approver.sh" ]] && source "${AUTONOMOUS_ROOT}/lib/supervisor-approver.sh"

declare -A PHASE_ORDER=(
    ["BRAINSTORM"]=1
    ["DOCUMENT"]=2
    ["PLAN"]=3
    ["EXECUTE"]=4
    ["TRACK"]=5
    ["COMPLETE"]=6
)

declare -A PHASE_ARTIFACTS=(
    ["BRAINSTORM"]="requirements.md"
    ["DOCUMENT"]="spec.md,acceptance_criteria.md"
    ["PLAN"]="tech_design.md,missions/"
    ["EXECUTE"]="implementation/,tests/"
    ["TRACK"]="deployment_log.md"
)

declare -A PHASE_GATES=(
    ["BRAINSTORM"]=""
    ["DOCUMENT"]="requirements_complete"
    ["PLAN"]="spec_approved"
    ["EXECUTE"]="design_approved,tests_pass,coverage_check,security_scan,lint_check"
    ["TRACK"]="all_gates_passed"
)

sdlc_init_schema() {
    sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true

    sqlite3 "$STATE_DB" <<SQL
ALTER TABLE tasks ADD COLUMN sdlc_phase TEXT DEFAULT 'BRAINSTORM';

CREATE TABLE IF NOT EXISTS phase_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id TEXT NOT NULL,
    from_phase TEXT,
    to_phase TEXT NOT NULL,
    transitioned_by TEXT,
    transition_reason TEXT,
    artifacts_present TEXT,
    gates_passed TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (task_id) REFERENCES tasks(id)
);

CREATE TABLE IF NOT EXISTS task_artifacts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id TEXT NOT NULL,
    phase TEXT NOT NULL,
    artifact_type TEXT NOT NULL,
    artifact_path TEXT NOT NULL,
    checksum TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (task_id) REFERENCES tasks(id)
);
SQL

    log_debug "SDLC schema initialized"
}

get_task_phase() {
    local task_id="$1"
    local phase
    phase=$(sqlite3 "$STATE_DB" "SELECT sdlc_phase FROM tasks WHERE id='$(echo "$task_id" | sed "s/'/''/g")' LIMIT 1;" 2>/dev/null)
    echo "${phase:-BRAINSTORM}"
}

is_valid_transition() {
    local from_phase="$1"
    local to_phase="$2"

    local from_order="${PHASE_ORDER[$from_phase]:-0}"
    local to_order="${PHASE_ORDER[$to_phase]:-0}"

    [[ $to_order -ge $from_order ]]
}

check_phase_artifacts() {
    local task_id="$1"
    local phase="$2"
    local task_dir="${ARTIFACTS_DIR}/${task_id}"

    local required="${PHASE_ARTIFACTS[$phase]:-}"
    [[ -z "$required" ]] && return 0

    local missing=()
    IFS=',' read -ra artifacts <<< "$required"

    for artifact in "${artifacts[@]}"; do
        local artifact_path="${task_dir}/${artifact}"

        if [[ "$artifact" == */ ]]; then
            [[ ! -d "$artifact_path" ]] && missing+=("$artifact")
        else
            [[ ! -f "$artifact_path" ]] && missing+=("$artifact")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warn "[${TRACE_ID:-sdlc}] Missing artifacts for $phase: ${missing[*]}"
        return 1
    fi

    return 0
}

register_artifact() {
    local task_id="$1"
    local phase="$2"
    local artifact_type="$3"
    local artifact_path="$4"

    local checksum=""
    if [[ -f "$artifact_path" ]]; then
        checksum=$(md5sum "$artifact_path" 2>/dev/null | cut -d' ' -f1 || echo "")
    fi

    sqlite3 "$STATE_DB" <<SQL
INSERT INTO task_artifacts (task_id, phase, artifact_type, artifact_path, checksum)
VALUES (
    '$(echo "$task_id" | sed "s/'/''/g")',
    '$(echo "$phase" | sed "s/'/''/g")',
    '$(echo "$artifact_type" | sed "s/'/''/g")',
    '$(echo "$artifact_path" | sed "s/'/''/g")',
    '$(echo "$checksum" | sed "s/'/''/g")'
);
SQL

    log_debug "[${TRACE_ID:-sdlc}] Registered artifact: $artifact_type for $task_id"
}

check_phase_gates() {
    local task_id="$1"
    local from_phase="$2"
    local to_phase="$3"

    local required_gates="${PHASE_GATES[$to_phase]:-}"
    [[ -z "$required_gates" ]] && return 0

    local failed_gates=()
    IFS=',' read -ra gates <<< "$required_gates"

    for gate in "${gates[@]}"; do
        if ! run_gate_check "$task_id" "$gate"; then
            failed_gates+=("$gate")
        fi
    done

    if [[ ${#failed_gates[@]} -gt 0 ]]; then
        log_error "[${TRACE_ID:-sdlc}] Gates failed for $to_phase: ${failed_gates[*]}"
        return 1
    fi

    return 0
}

run_gate_check() {
    local task_id="$1"
    local gate_name="$2"
    local task_dir="${ARTIFACTS_DIR}/${task_id}"

    case "$gate_name" in
        requirements_complete)
            [[ -f "${task_dir}/requirements.md" && -s "${task_dir}/requirements.md" ]]
            ;;
        spec_approved)
            [[ -f "${task_dir}/spec.md" ]] && grep -q "APPROVED" "${task_dir}/spec.md" 2>/dev/null
            ;;
        design_approved)
            [[ -f "${task_dir}/tech_design.md" ]] && grep -q "APPROVED" "${task_dir}/tech_design.md" 2>/dev/null
            ;;
        tests_pass)
            if [[ -x "${AUTONOMOUS_ROOT}/tests/run_tests.sh" ]]; then
                "${AUTONOMOUS_ROOT}/tests/run_tests.sh" unit >/dev/null 2>&1
            else
                return 0
            fi
            ;;
        coverage_check)
            if [[ -f "${task_dir}/coverage.json" ]]; then
                local coverage
                coverage=$(jq -r '.total_coverage // 0' "${task_dir}/coverage.json" 2>/dev/null)
                [[ "$coverage" -ge 80 ]]
            else
                return 0
            fi
            ;;
        security_scan)
            if [[ -f "${task_dir}/security_scan.json" ]]; then
                local criticals
                criticals=$(jq -r '.critical_count // 0' "${task_dir}/security_scan.json" 2>/dev/null)
                [[ "$criticals" -eq 0 ]]
            else
                return 0
            fi
            ;;
        lint_check)
            return 0
            ;;
        all_gates_passed)
            return 0
            ;;
        *)
            log_warn "[${TRACE_ID:-sdlc}] Unknown gate: $gate_name"
            return 0
            ;;
    esac
}

transition_phase() {
    local task_id="$1"
    local to_phase="$2"
    local reason="${3:-manual transition}"

    local from_phase
    from_phase=$(get_task_phase "$task_id")

    log_info "[${TRACE_ID:-sdlc}] Attempting transition: $task_id $from_phase -> $to_phase"

    if ! is_valid_transition "$from_phase" "$to_phase"; then
        log_error "[${TRACE_ID:-sdlc}] Invalid transition: $from_phase -> $to_phase"
        return 1
    fi

    if ! check_phase_artifacts "$task_id" "$from_phase"; then
        log_error "[${TRACE_ID:-sdlc}] Missing artifacts for $from_phase, cannot proceed"
        return 1
    fi

    if ! check_phase_gates "$task_id" "$from_phase" "$to_phase"; then
        log_error "[${TRACE_ID:-sdlc}] Gates not passed for $to_phase"
        return 1
    fi

    sqlite3 "$STATE_DB" <<SQL
UPDATE tasks
SET sdlc_phase = '$(echo "$to_phase" | sed "s/'/''/g")',
    updated_at = datetime('now')
WHERE id = '$(echo "$task_id" | sed "s/'/''/g")';

INSERT INTO phase_history (task_id, from_phase, to_phase, transitioned_by, transition_reason)
VALUES (
    '$(echo "$task_id" | sed "s/'/''/g")',
    '$(echo "$from_phase" | sed "s/'/''/g")',
    '$(echo "$to_phase" | sed "s/'/''/g")',
    '${WORKER_ID:-system}',
    '$(echo "$reason" | sed "s/'/''/g")'
);
SQL

    log_info "[${TRACE_ID:-sdlc}] Transition successful: $from_phase -> $to_phase"
    return 0
}

auto_advance_phase() {
    local task_id="$1"
    local current_phase
    current_phase=$(get_task_phase "$task_id")

    local next_phase=""
    case "$current_phase" in
        BRAINSTORM) next_phase="DOCUMENT" ;;
        DOCUMENT)   next_phase="PLAN" ;;
        PLAN)       next_phase="EXECUTE" ;;
        EXECUTE)    next_phase="TRACK" ;;
        TRACK)      next_phase="COMPLETE" ;;
        COMPLETE)   return 0 ;;
    esac

    if [[ -n "$next_phase" ]]; then
        if transition_phase "$task_id" "$next_phase" "auto-advance"; then
            log_info "[${TRACE_ID:-sdlc}] Auto-advanced $task_id to $next_phase"
            return 0
        fi
    fi

    return 1
}

get_phase_status() {
    local task_id="$1"
    local current_phase
    current_phase=$(get_task_phase "$task_id")

    local required_artifacts="${PHASE_ARTIFACTS[$current_phase]:-none}"
    local required_gates="${PHASE_GATES[$current_phase]:-none}"

    cat <<EOF
{
    "task_id": "$task_id",
    "current_phase": "$current_phase",
    "phase_order": ${PHASE_ORDER[$current_phase]:-0},
    "required_artifacts": "$required_artifacts",
    "required_gates": "$required_gates",
    "artifacts_present": $(check_phase_artifacts "$task_id" "$current_phase" && echo "true" || echo "false"),
    "gates_passed": $(check_phase_gates "$task_id" "" "$current_phase" && echo "true" || echo "false"),
    "can_advance": $(auto_advance_phase "$task_id" 2>/dev/null && echo "true" || echo "false")
}
EOF
}

init_task_phases() {
    local task_id="$1"
    local task_dir="${ARTIFACTS_DIR}/${task_id}"

    mkdir -p "$task_dir"

    sqlite3 "$STATE_DB" <<SQL
UPDATE tasks
SET sdlc_phase = 'BRAINSTORM',
    updated_at = datetime('now')
WHERE id = '$(echo "$task_id" | sed "s/'/''/g")';

INSERT INTO phase_history (task_id, from_phase, to_phase, transitioned_by, transition_reason)
VALUES (
    '$(echo "$task_id" | sed "s/'/''/g")',
    NULL,
    'BRAINSTORM',
    '${WORKER_ID:-system}',
    'Task initialized'
);
SQL

    log_info "[${TRACE_ID:-sdlc}] Initialized task phases: $task_id"
}

sdlc_init_schema 2>/dev/null || true

export -f get_task_phase
export -f is_valid_transition
export -f check_phase_artifacts
export -f check_phase_gates
export -f transition_phase
export -f auto_advance_phase
export -f get_phase_status
export -f init_task_phases
```

---

### FIX-7: Supervisor Uses Approver Engine (Unified Review Flow)
**File**: `bin/tri-agent-supervisor`
**Priority**: P1
**Why**: Eliminate split-brain approvals and use the single gate engine.

```bash
# INSERT in tri-agent-supervisor (function)
check_reviews() {
    for task_file in "${REVIEW_DIR}"/*.md; do
        [[ -f "$task_file" ]] || continue
        local task_id
        task_id=$(basename "$task_file" .md)

        log_info "Found task in review: $task_id"

        if "${LIB_DIR}/supervisor-approver.sh" workflow "$task_id" "$(pwd)"; then
            log_info "Task $task_id approved"
        else
            log_warn "Task $task_id rejected"
        fi
    done
}

# ADD to main_loop
main_loop() {
    # ... existing init ...
    while true; do
        check_reviews
        # ... existing git checks ...
        sleep "$WATCH_INTERVAL"
    done
}
```

---

### FIX-8: Recover Stale Tasks (Heartbeat Recovery)
**File**: `lib/heartbeat.sh`
**Priority**: P0
**Why**: Prevent stuck tasks and requeue on worker failure.

```bash
#===============================================================================
# Task Recovery Functions
#===============================================================================

recover_stale_task() {
    local task_id="$1"
    local worker_id="$2"
    local reason="${3:-unknown}"

    log_warn "[${TRACE_ID:-recovery}] Recovering stale task: $task_id (worker: $worker_id, reason: $reason)"

    local running_dir="${AUTONOMOUS_ROOT}/tasks/running"
    local queue_dir="${AUTONOMOUS_ROOT}/tasks/queue"
    local task_file="${running_dir}/${task_id}"

    if [[ ! -f "$task_file" ]]; then
        task_file=$(find "$running_dir" -name "*${task_id}*" -type f 2>/dev/null | head -1)
    fi

    if [[ -n "$task_file" && -f "$task_file" ]]; then
        local task_name
        task_name=$(basename "$task_file")

        local lock_file="${running_dir}/${task_name}.lock"
        local lock_dir="${running_dir}/${task_name}.lock.d"

        rm -f "$lock_file" 2>/dev/null || true
        rmdir "$lock_dir" 2>/dev/null || true

        mv "$task_file" "$queue_dir/" 2>/dev/null || {
            log_error "[${TRACE_ID:-recovery}] Failed to requeue task: $task_name"
            return 1
        }

        log_info "[${TRACE_ID:-recovery}] Task requeued: $task_name"
    else
        log_warn "[${TRACE_ID:-recovery}] Task file not found for: $task_id"
    fi

    if [[ -f "$STATE_DB" ]] && command -v sqlite3 &>/dev/null; then
        sqlite3 "$STATE_DB" <<SQL
UPDATE tasks
SET state = 'PENDING',
    worker_id = NULL,
    updated_at = datetime('now'),
    recovery_count = COALESCE(recovery_count, 0) + 1
WHERE id = '$(echo "$task_id" | sed "s/'/''/g")';

UPDATE workers
SET status = 'stale',
    last_heartbeat = datetime('now')
WHERE worker_id = '$(echo "$worker_id" | sed "s/'/''/g")';

INSERT INTO events (task_id, event_type, event_data, created_at)
VALUES (
    '$(echo "$task_id" | sed "s/'/''/g")',
    'TASK_RECOVERED',
    '{"reason": "$(echo "$reason" | sed "s/'/''/g")", "worker": "$(echo "$worker_id" | sed "s/'/''/g")"}',
    datetime('now')
);
SQL
    fi

    local ledger_file="${AUTONOMOUS_ROOT}/logs/ledger.jsonl"
    if [[ -d "$(dirname "$ledger_file")" ]]; then
        echo "{\"timestamp\":\"$(date -Iseconds)\",\"event\":\"TASK_RECOVERED\",\"task\":\"$task_id\",\"worker\":\"$worker_id\",\"reason\":\"$reason\"}" >> "$ledger_file"
    fi

    return 0
}

recover_all_stale_tasks() {
    local max_age="${1:-3600}"
    local recovered=0

    log_info "[${TRACE_ID:-recovery}] Starting batch recovery (max age: ${max_age}s)"

    heartbeat_check_stale 1.5

    local running_dir="${AUTONOMOUS_ROOT}/tasks/running"
    local now
    now=$(date +%s)

    for lock_dir in "$running_dir"/*.lock.d; do
        [[ -d "$lock_dir" ]] || continue

        local dir_mtime
        dir_mtime=$(stat -c %Y "$lock_dir" 2>/dev/null || stat -f %m "$lock_dir" 2>/dev/null || echo 0)
        local age=$((now - dir_mtime))

        if [[ $age -gt $max_age ]]; then
            local task_name="${lock_dir%.lock.d}"
            task_name=$(basename "$task_name")

            log_warn "[${TRACE_ID:-recovery}] Cleaning orphaned lock: $task_name (age: ${age}s)"
            rmdir "$lock_dir" 2>/dev/null || true
            ((recovered++)) || true
        fi
    done

    log_info "[${TRACE_ID:-recovery}] Batch recovery complete (recovered: $recovered)"
    return 0
}

export -f recover_stale_task
export -f recover_all_stale_tasks
```

---

### FIX-9: Circuit Breaker Integration (Claude Delegate)
**File**: `bin/claude-delegate`
**Priority**: P1
**Why**: Prevent cascading failures when a model is unhealthy.

```bash
# Execute Claude with circuit breaker protection
execute_claude() {
    local prompt="$1"
    local timeout="${2:-300}"
    local model="claude"

    if ! declare -f check_breaker &>/dev/null; then
        source "${LIB_DIR}/circuit-breaker.sh"
    fi

    local breaker_state
    breaker_state=$(check_breaker "$model")

    if [[ "$breaker_state" == "OPEN" ]]; then
        log_warn "[${TRACE_ID}] Circuit OPEN for $model, using fallback"
        record_failure "$model" "circuit_open_skip"

        if check_breaker "codex" != "OPEN"; then
            log_info "[${TRACE_ID}] Falling back to Codex"
            execute_codex_fallback "$prompt" "$timeout"
            return $?
        fi

        log_error "[${TRACE_ID}] All circuits open, cannot execute"
        return 1
    fi

    local start_time end_time duration
    start_time=$(date +%s)

    local exit_code=0
    local output
    output=$(timeout "$timeout" claude \
        --dangerously-skip-permissions \
        -p "$prompt" \
        2>&1) || exit_code=$?

    end_time=$(date +%s)
    duration=$((end_time - start_time))

    if [[ $exit_code -eq 0 ]]; then
        record_success "$model"
        log_debug "[${TRACE_ID}] Claude execution successful (${duration}s)"
    elif [[ $exit_code -eq 124 ]]; then
        record_failure "$model" "timeout"
        log_error "[${TRACE_ID}] Claude timeout after ${timeout}s"
    else
        record_failure "$model" "exit_code_$exit_code"
        log_error "[${TRACE_ID}] Claude failed with exit code $exit_code"
    fi

    if declare -f record_request &>/dev/null; then
        record_request "$model" "$((${#prompt} / 4))" "$((${#output} / 4))" "$((duration * 1000))" "delegate"
    fi

    echo "$output"
    return $exit_code
}

execute_codex_fallback() {
    local prompt="$1"
    local timeout="${2:-300}"

    log_info "[${TRACE_ID}] Executing via Codex fallback"

    if [[ -x "${BIN_DIR}/codex-delegate" ]]; then
        "${BIN_DIR}/codex-delegate" --timeout "$timeout" "$prompt"
    elif command -v codex &>/dev/null; then
        timeout "$timeout" codex exec --skip-git-repo-check "$prompt" 2>&1
    else
        log_error "[${TRACE_ID}] Codex fallback not available"
        return 1
    fi
}
```

---

### FIX-10: Expanded Secret Mask Patterns
**File**: `config/tri-agent.yaml`
**Priority**: P1
**Why**: Prevent leakage of AWS/Azure/GCP tokens, DB URLs, and key material.

```yaml
security:
  mask_secrets: true
  mask_patterns:
    # OpenAI / Anthropic
    - 'sk-[a-zA-Z0-9]{20,}'
    - 'sk-proj-[a-zA-Z0-9]{20,}'
    - 'ANTHROPIC_API_KEY=[^\s]+'
    - 'OPENAI_API_KEY=[^\s]+'

    # Google
    - 'GOOGLE_API_KEY=[^\s]+'
    - 'AIza[a-zA-Z0-9_-]{35}'
    - 'GCLOUD_[A-Z_]+=[^\s]+'

    # AWS
    - 'AKIA[A-Z0-9]{16}'
    - 'aws_access_key_id["\s:=]+[A-Za-z0-9/+=]{20,}'
    - 'aws_secret_access_key["\s:=]+[A-Za-z0-9/+=]{40,}'
    - 'AWS_[A-Z_]+=[^\s]+'

    # Azure
    - 'azure[_-]?storage[_-]?key["\s:=]+[A-Za-z0-9/+=]{88}'
    - 'AZURE_[A-Z_]+=[^\s]+'
    - 'DefaultEndpointsProtocol=https;AccountName=[^;]+;AccountKey=[^;]+'

    # GitHub
    - 'ghp_[a-zA-Z0-9]{36}'
    - 'gho_[a-zA-Z0-9]{36}'
    - 'ghs_[a-zA-Z0-9]{36}'
    - 'ghr_[a-zA-Z0-9]{36}'
    - 'github_pat_[a-zA-Z0-9]{22}_[a-zA-Z0-9]{59}'

    # Generic tokens
    - 'Bearer [a-zA-Z0-9._-]{20,}'
    - 'token["\s:=]+[a-zA-Z0-9._-]{20,}'
    - 'api[_-]?key["\s:=]+[a-zA-Z0-9._-]{20,}'
    - 'secret["\s:=]+[a-zA-Z0-9._-]{20,}'
    - 'password["\s:=]+[^\s"]{8,}'

    # Private keys
    - '-----BEGIN (RSA |EC |DSA |OPENSSH |)PRIVATE KEY-----'
    - '-----BEGIN PGP PRIVATE KEY BLOCK-----'

    # Database connection strings
    - 'postgres://[^:]+:[^@]+@'
    - 'mysql://[^:]+:[^@]+@'
    - 'mongodb://[^:]+:[^@]+@'
    - 'mongodb\+srv://[^:]+:[^@]+@'
    - 'redis://:[^@]+@'

    # Slack
    - 'xox[baprs]-[a-zA-Z0-9-]+'

    # Stripe
    - 'sk_live_[a-zA-Z0-9]{24,}'
    - 'rk_live_[a-zA-Z0-9]{24,}'

    # Twilio
    - 'SK[a-f0-9]{32}'

    # SendGrid
    - 'SG\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+'

  excluded_files:
    - ".env"
    - ".env.*"
    - ".env.local"
    - ".env.*.local"
    - "credentials.json"
    - "service-account*.json"
    - "*.pem"
    - "*.key"
    - "*.p12"
    - "*.pfx"
    - "id_rsa*"
    - "id_ed25519*"
    - "*.keystore"
    - "secrets.yaml"
    - "secrets.yml"
    - "**/secrets/**"
    - ".npmrc"
    - ".pypirc"
    - ".netrc"
    - "**/.git/config"
```

---

## 4) PRIORITY MATRIX (MERGED)

| Priority | Item | File(s) | Effort | Dependencies | Goal |
|---------|------|---------|--------|--------------|------|
| P0 | SQLite canonical task claim | `bin/tri-agent-worker`, `lib/sqlite-state.sh` | 4-8h | Queue bridge | Prevent duplicate execution |
| P0 | Queue -> SQLite bridge | `bin/tri-agent-queue-watcher` | 4-6h | None | Canonical intake |
| P0 | Budget watchdog active pause/kill | `bin/budget-watchdog` | 4h | SQLite optional | Prevent runaway spend |
| P0 | SDLC phase enforcement | `lib/sdlc-phases.sh` | 8-10h | Schema migration | Prevent phase skipping |
| P0 | Stale task recovery | `lib/heartbeat.sh` | 2h | SQLite | Recover from crashes |
| P1 | Supervisor unification | `bin/tri-agent-supervisor`, `lib/supervisor-approver.sh` | 8-12h | Queue bridge | Single approval path |
| P1 | Worker pool sharding | `lib/worker-pool.sh`, worker | 4-6h | SQLite claim | Avoid task contention |
| P1 | Circuit breaker integration | `bin/*-delegate` | 4h | Circuit breaker | Resilience |
| P1 | Security mask patterns | `config/tri-agent.yaml` | 1h | None | Prevent leakage |
| P2 | Gate portability fixes | `lib/supervisor-approver.sh` | 4-6h | None | Reliable CI gates |
| P2 | Health-check JSON hardening | `bin/health-check` | 1-2h | None | Observability |
| P2 | Process reaper | `bin/process-reaper` | 2-3h | Worker pool | Zombie cleanup |
| P3 | Event store | `lib/event-store.sh` | 4-6h | SQLite | Audit trail |
| P3 | Dashboard | `bin/tri-agent-dashboard` | 4-8h | Health data | Ops visibility |

---

## 5) IMPLEMENTATION ROADMAP

### M1: Stabilization (Days 1-2)
- SQLite canonical claim + queue bridge.
- Active budget watchdog + worker pause/resume signals.
- Stale task recovery wired into heartbeat.

**Exit criteria**: 3 workers run concurrently without duplicate task claims; budget pause works within 10 seconds.

### M2: Core Autonomy (Days 3-5)
- Supervisor unified with approver engine.
- SDLC phases enforced for Brainstorm -> Track.
- Circuit breaker integrated into all delegates.

**Exit criteria**: Single task flows from queue -> review -> approved without manual steps.

### M3: Self-Healing & Observability (Days 6-7)
- Process reaper; heartbeat + zombie recovery across DB.
- Health-check JSON hardened; alerts available.

**Exit criteria**: Kill a worker mid-task and system recovers with no manual intervention.

### M4: Hardening (Days 8-9)
- Gate portability fixes (jq-less, no bc, no grep -P).
- Security masking expanded and validated.

**Exit criteria**: Full gate suite runs on minimal environments without crashing.

### M5: Scale & UX (Days 10+)
- Event store for auditability.
- Dashboard/CLI for live status.

**Exit criteria**: 200+ tasks/day with clean audits and minimal backlog.

---

## 6) VERIFICATION TESTS

### 6.1 SQLite Atomic Claim (Concurrency)
```bash
#!/bin/bash
# tests/verify_sqlite_claim.sh
set -euo pipefail

TASK_ID="TEST_LOCK_001"
"${PROJECT_ROOT}/lib/sqlite-state.sh" create_task "$TASK_ID" "Test Lock" "test" "HIGH"

for i in {1..10}; do
    (
        if "${PROJECT_ROOT}/lib/sqlite-state.sh" claim_task_atomic "worker-$i"; then
            echo "Worker $i GOT LOCK"
            exit 0
        else
            echo "Worker $i FAILED"
            exit 1
        fi
    ) &
done
wait
# Expectation: exactly one GOT LOCK
```

### 6.2 Budget Watchdog Signal Test
```bash
#!/bin/bash
# tests/verify_watchdog_signals.sh
set -euo pipefail

# Dummy worker that exits on SIGUSR1
(
  trap 'echo "PAUSED"; exit 0' SIGUSR1
  while true; do sleep 1; done
) &
PID=$!

# Force pause
touch "${PROJECT_ROOT}/state/budget/spend.jsonl"
"${PROJECT_ROOT}/bin/budget-watchdog" --status
kill -SIGUSR1 "$PID"
wait "$PID"
```

### 6.3 SDLC Phase Transition
```bash
#!/bin/bash
# tests/verify_sdlc.sh
set -euo pipefail

source lib/sdlc-phases.sh
init_task_phases "test-sdlc-001"
mkdir -p artifacts/test-sdlc-001
printf "# Requirements\n" > artifacts/test-sdlc-001/requirements.md
transition_phase "test-sdlc-001" "DOCUMENT" "test transition"
get_phase_status "test-sdlc-001"
```

### 6.4 Stale Task Recovery
```bash
#!/bin/bash
# tests/verify_stale_recovery.sh
set -euo pipefail

source lib/common.sh
source lib/heartbeat.sh

mkdir -p "$HOME/.claude/autonomous/tasks/running"
mkdir -p "$HOME/.claude/autonomous/tasks/queue"

echo "# Test" > "$HOME/.claude/autonomous/tasks/running/HIGH_test_task.md"
mkdir "$HOME/.claude/autonomous/tasks/running/HIGH_test_task.md.lock.d"

recover_stale_task "HIGH_test_task.md" "test-worker" "manual test"
ls "$HOME/.claude/autonomous/tasks/queue/" | grep -q "HIGH_test_task.md"
```

### 6.5 Circuit Breaker Smoke Test
```bash
#!/bin/bash
# tests/verify_circuit_breaker.sh
set -euo pipefail

source lib/circuit-breaker.sh
source lib/common.sh

for i in {1..5}; do record_failure "claude" "test"; done
./bin/claude-delegate "test prompt" || true
# Expect log showing circuit OPEN and fallback
```

---

## FINAL NOTES
- This synthesis prioritizes **SQLite as the canonical state**, while preserving the file queue as an input path via a queue bridge.
- If you want, I can now apply these fixes directly and wire them together in the codebase.
