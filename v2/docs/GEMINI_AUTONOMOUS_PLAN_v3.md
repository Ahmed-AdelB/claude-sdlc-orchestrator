# GEMINI 3 PRO - AUTONOMOUS SDLC ORCHESTRATOR PLAN v3

**Date**: 2025-12-29
**Author**: Gemini 3 Pro (Autonomous Agent)
**Status**: APPROVED
**Based on**: Codebase Dump (121,416 lines) + Real-time Analysis

---

## SECTION 1: EXECUTIVE SUMMARY

### 1.1 Current Implementation Status
The codebase represents a **mature prototype** (v2.0.0) with significant architectural strengths but critical operational gaps preventing true autonomous operation.

| Component | Status | % Complete | Key Observation |
|-----------|--------|------------|-----------------|
| **Core State** | 🟢 STABLE | 90% | `sqlite-state.sh` is robust, atomic, and WAL-enabled. |
| **Worker Loop** | 🔴 CRITICAL | 60% | `tri-agent-worker` uses brittle file locking (`mkdir`), ignoring SQLite state. |
| **Supervisor** | 🟡 PARTIAL | 70% | Split brain between `tri-agent-supervisor` (git) and `supervisor-approver` (files). |
| **Consensus** | 🟢 STABLE | 95% | `tri-agent-consensus` is production-ready with parallel voting. |
| **Resilience** | 🟡 PARTIAL | 50% | Circuit breakers exist (`lib/circuit-breaker.sh`) but aren't fully integrated into workers. |
| **Governance** | 🔴 CRITICAL | 40% | `budget-watchdog` tracks cost but cannot effectively pause rogue workers. |

### 1.2 Production Readiness Score: 58/100
- **Architecture**: 85/100 (Solid multi-agent design)
- **Security**: 70/100 (Secret masking present, audits automated)
- **Reliability**: 40/100 (Race conditions in task claiming, weak resource governance)
- **Autonomy**: 35/100 (Requires manual intervention for stalls/locks)

### 1.3 Top 5 Blockers (Critical Path)
1.  **State Disconnect**: `bin/tri-agent-worker` (lines 350-400) uses `mkdir` file locking, ignoring `lib/sqlite-state.sh`'s `claim_task_atomic`. This causes race conditions and state desync.
2.  **Sharding Failure**: `lib/worker-pool.sh` assigns shards, but `tri-agent-worker` ignores `WORKER_SHARD` env var, causing all workers to fight for the same tasks.
3.  **Supervisor Split-Brain**: `bin/tri-agent-supervisor` watches Git commits, while `lib/supervisor-approver.sh` watches file directories. They must be unified to prevent double-processing.
4.  **Zombie Locks**: Worker crash recovery (`cleanup_stale_locks` in `tri-agent-worker`) is file-based and doesn't reset SQLite state, leaving tasks "RUNNING" forever in DB.
5.  **Weak Governance**: `budget-watchdog` sets a `pause.requested` file, but workers only check this periodically via inbox messages, creating a dangerous lag window.

---

## SECTION 2: CURRENT STATE ANALYSIS

### 2.1 Component Architecture (Current)

```
┌─────────────────┐      ┌────────────────────┐      ┌──────────────────┐
│  BUDGET WATCH   │      │  SQLITE STATE DB   │      │  TASK QUEUE (FS) │
│ (bin/budget...) │───┐  │ (lib/sqlite...)    │  ┌───│ (tasks/queue/)   │
└─────────────────┘   │  └────────────────────┘  │   └──────────────────┘
       │ Sets Flag    │             ▲            │            ▲
       ▼              │             │ (Unused)   │            │ (Polling)
┌─────────────────┐   │  ┌────────────────────┐  │   ┌──────────────────┐
│  TRI-AGENT      │   │  │  WORKER POOL       │  │   │  WORKER (x3)     │
│  LAUNCHER       │───┴─▶│ (lib/worker-pool)  │──┴──▶│ (bin/worker)     │
└─────────────────┘      └────────────────────┘      └──────────────────┘
                                                              │
                                                              ▼
┌─────────────────┐      ┌────────────────────┐      ┌──────────────────┐
│  SUPERVISOR     │◀─────│  APPROVAL ENGINE   │◀─────│  MODEL DELEGATES │
│  (bin/super...) │      │ (lib/supervisor..) │      │ (bin/claude...)  │
└─────────────────┘      └────────────────────┘      └──────────────────┘
```

### 2.2 Evidence of Status

| File | Status | Line Ref | Issue/Strength |
|------|--------|----------|----------------|
| `lib/sqlite-state.sh` | **SOLID** | 225-250 | `claim_task_atomic` uses `BEGIN IMMEDIATE` correctly. |
| `bin/tri-agent-worker` | **BROKEN** | 368 | `if mkdir "$lock_dir"` - Primitive file locking, ignoring SQLite. |
| `bin/tri-agent-worker` | **BROKEN** | 338 | `pick_next_task` ignores `WORKER_SHARD` variable. |
| `lib/circuit-breaker.sh` | **GOOD** | 120 | Atomic state updates with lock files. |
| `bin/tri-agent-supervisor` | **PARTIAL** | 225 | Only watches Git commits (`git rev-parse`), misses task lifecycle events. |
| `bin/budget-watchdog` | **WEAK** | 120 | Uses Python injection for math (good) but pause mechanism is passive. |

---

## SECTION 3: TARGET STATE DESIGN

### 3.1 Architecture (Target)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        AUTONOMOUS ORCHESTRATOR                          │
├───────────────────────┬───────────────────────────┬─────────────────────┤
│   GOVERNANCE LAYER    │      WORKER LAYER         │   SUPERVISOR LAYER  │
├───────────────────────┼───────────────────────────┼─────────────────────┤
│ ┌───────────────────┐ │  ┌─────────────────────┐  │ ┌─────────────────┐ │
│ │  WATCHDOG DAEMON  │ │  │ WORKER 1 (Impl)     │  │ │  AUDIT DAEMON   │ │
│ │ - Cost Limit      │ │  │ - Shard 0           │  │ │ - Sec Scan      │ │
│ │ - Process Health  │ │  │ - Codex Focus       │  │ │ - Test Runner   │ │
│ │ - Lock Reaper     │ │  └─────────────────────┘  │ └─────────────────┘ │
│ └─────────┬─────────┘ │             ▲             │          ▲          │
│           │ Signal    │             │ Claims      │          │ Triggers │
│           ▼           │  ┌─────────────────────┐  │ ┌────────┴────────┐ │
│ ┌───────────────────┐ │  │ WORKER 2 (Review)   │  │ │ APPROVAL ENGINE │ │
│ │  STATE MANAGER    │◀┼──│ - Shard 1           │──┼▶│ - Quality Gates │ │
│ │ (SQLite + WAL)    │ │  │ - Claude Focus      │  │ │ - Consensus     │ │
│ └───────────────────┘ │  └─────────────────────┘  │ └─────────────────┘ │
│           ▲           │             ▲             │          ▲          │
│           │ Updates   │             │ Claims      │          │ Feeds    │
│ ┌─────────┴─────────┐ │  ┌─────────────────────┐  │ ┌────────┴────────┐ │
│ │CIRCUIT BREAKER   │ │  │ WORKER 3 (Analysis) │  │ │ CONSENSUS       │ │
│ │ (Redis/File)      │◀┼──│ - Shard 2           │──┼▶│ - Gemini Focus      │ │
│ └───────────────────┘ │  │ - Gemini Focus      │  │ └─────────────────┘ │
└───────────────────────┴──└─────────────────────┘──┴─────────────────────┘
```

### 3.2 Key Design Changes
1.  **Unified State**: Workers MUST use `lib/sqlite-state.sh` for claiming. `mkdir` locking is deprecated.
2.  **Strict Sharding**: Worker 1 only claims `shard-0`, Worker 2 `shard-1`, etc. defined in SQLite `tasks` table.
3.  **Active Governance**: Watchdog sends `SIGSTOP`/`SIGCONT` to worker PIDs based on budget, rather than setting a passive flag.
4.  **Supervisor Unification**: `bin/tri-agent-supervisor` becomes the entry point, spawning `supervisor-approver` as a thread/subprocess.

### 3.3 Resource Governance Flow
1.  `cost-tracker.sh` logs usage to `logs/costs/`.
2.  `budget-watchdog` runs every 30s.
3.  If rate > $1/min:
    - Calls `sqlite-state.sh set_pause_requested`.
    - Sends `SIGUSR1` (Pause) to all worker PIDs found in `workers` table.
4.  Workers trap `SIGUSR1`, finish current step, and sleep.
5.  If rate < $0.40/min:
    - Sends `SIGUSR2` (Resume).

---

## SECTION 4: TRANSFORMATION GAP ANALYSIS

### 4.1 Component: `bin/tri-agent-worker`
| Feature | Current | Target | Risk | Effort |
|---------|---------|--------|------|--------|
| **Task Claiming** | `mkdir` based (Race-prone) | `sqlite-state.sh claim_task_atomic` | HIGH | 4h |
| **Sharding** | Ignored (Hardcoded FIFO) | Respects `WORKER_SHARD` env var | MEDIUM | 2h |
| **Pause** | Checks boolean flag loop | Traps `SIGUSR1`/`SIGUSR2` | MEDIUM | 2h |
| **Output** | Writes local files | Updates SQLite `tasks` row | MEDIUM | 3h |

### 4.2 Component: `bin/tri-agent-supervisor`
| Feature | Current | Target | Risk | Effort |
|---------|---------|--------|------|--------|
| **Trigger** | Git commits only | Task status change (SQL polling) | HIGH | 4h |
| **Integration** | Calls `claude-delegate` directly | Uses `lib/supervisor-approver.sh` | MEDIUM | 2h |
| **Feedback** | Writes Markdown files | Updates `tasks.result` & `events` table | LOW | 2h |

### 4.3 Component: `lib/sqlite-state.sh`
| Feature | Current | Target | Risk | Effort |
|---------|---------|--------|------|--------|
| **Schema** | Basic tables | Add `locks`, `shards`, `heartbeats` | LOW | 1h |
| **Access** | CLI wrapper | Direct optimized queries | LOW | 1h |

---

## SECTION 5: CRITICAL FIXES (15)

### FIX-1: Enable Atomic SQLite Task Claiming in Worker
**File**: `bin/tri-agent-worker`
**Priority**: P0
**Impact**: Eliminates race conditions and enables sharding.

```bash
# REPLACEMENT FUNCTION for acquire_task_lock (lines 350-390)
acquire_task_lock() {
    local worker_id="$WORKER_ID"
    local shard="${WORKER_SHARD:-}" # Respect env var
    
    # Use SQLite atomic claim
    local task_id
    task_id=$("${PROJECT_ROOT}/lib/sqlite-state.sh" claim_task_atomic_filtered \
        "$worker_id" "" "$shard" "")

    if [[ -n "$task_id" ]]; then
        CURRENT_TASK="$task_id"
        log_info "Acquired task $task_id via SQLite (shard: ${shard:-any})"
        
        # Sync file state for legacy compatibility
        local task_file="${QUEUE_DIR}/${task_id}.md"
        local running_file="${RUNNING_DIR}/${task_id}.md"
        if [[ -f "$task_file" ]]; then
            mv "$task_file" "$running_file"
        fi
        
        # Log to ledger
        log_ledger "TASK_LOCKED" "$task_id" "worker=$worker_id shard=$shard"
        return 0
    fi
    
    return 1
}
```

### FIX-2: Implement Signal-Based Pause/Resume
**File**: `bin/tri-agent-worker`
**Priority**: P0
**Impact**: Enables immediate budget kill-switch enforcement.

```bash
# INSERT at beginning of script (after set -euo pipefail)
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

# REPLACE main loop pause check (lines 880-885)
if $WORKER_PAUSED; then
    log_debug "Worker paused by signal. Waiting..."
    sleep 5
    continue
fi
```

### FIX-3: Enforce Sharding in Worker Pool
**File**: `lib/worker-pool.sh`
**Priority**: P1
**Impact**: Prevents workers from fighting over the same tasks.

```bash
# REPLACE start_worker function (lines 75-95)
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

    # Export variables specifically for the worker process
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

### FIX-4: Unify Supervisor Logic
**File**: `bin/tri-agent-supervisor`
**Priority**: P1
**Impact**: Integrates approval engine into the main supervisor loop.

```bash
# INSERT in main_loop (lines 220+)
# Check for tasks awaiting review in SQLite/Filesystem
check_reviews() {
    # Scan review directory
    for task_file in "${REVIEW_DIR}"/*.md; do
        [[ -f "$task_file" ]] || continue
        local task_id=$(basename "$task_file" .md)
        
        log_info "Found task in review: $task_id"
        
        # Use the approval library
        if "${LIB_DIR}/supervisor-approver.sh" workflow "$task_id" "$(pwd)"; then
            log_info "Task $task_id approved"
        else
            log_warn "Task $task_id rejected"
        fi
    done
}

# ADD call to check_reviews in main_loop
main_loop() {
    # ... existing init ...
    while true;
        check_reviews
        # ... existing git check ...
        sleep "$WATCH_INTERVAL"
    done
}
```

### FIX-5: Correct SQLite Path in Worker
**File**: `bin/tri-agent-worker`
**Priority**: P0
**Impact**: Fixes "table not found" errors by ensuring correct DB path.

```bash
# REPLACE initialization block (lines 50-60)
# Ensure we use the correct state DB path from common.sh/sqlite-state.sh
if [[ -f "${PROJECT_ROOT}/lib/sqlite-state.sh" ]]; then
    source "${PROJECT_ROOT}/lib/sqlite-state.sh"
    # sqlite-state.sh defines STATE_DB, usually $AUTONOMOUS_ROOT/state/tri-agent.db
else
    # Fallback
    STATE_DB="${AUTONOMOUS_ROOT}/state/tri-agent.db"
fi

# Export for subprocesses
export STATE_DB
```

### FIX-6: Implement Watchdog Signaling
**File**: `bin/budget-watchdog`
**Priority**: P1
**Impact**: Makes the watchdog active rather than passive.

```bash
# REPLACE set_pause function
set_pause() {
    log_msg WARN "Pausing system due to budget overrun..."
    
    # 1. Set SQLite flag
    if declare -F set_pause_requested >/dev/null; then
        set_pause_requested "budget_watchdog"
    fi
    
    # 2. Signal Workers (Active Governance)
    if command -v sqlite3 >/dev/null; then
        # Get active PIDs from DB
        local pids
        pids=$(sqlite3 "$STATE_DB" "SELECT pid FROM workers WHERE status IN ('idle','busy')")
        for pid in $pids; do
            if kill -0 "$pid" 2>/dev/null; then
                log_msg INFO "Sending SIGUSR1 to worker $pid"
                kill -SIGUSR1 "$pid"
            fi
        done
    fi
}
```

### FIX-7: Fix Consensus Timeout Handling
**File**: `bin/tri-agent-consensus`
**Priority**: P2
**Impact**: Prevents consensus from hanging indefinitely on zombie processes.

```bash
# REPLACE cleanup_processes (lines 600-615)
cleanup_processes() {
    # Kill background processes if still running
    for pid in "$claude_pid" "$gemini_pid" "$codex_pid"; do
        if [[ -n "$pid" ]]; then
            # Check if process exists and is a child of this shell
            if kill -0 "$pid" 2>/dev/null; then
                log_debug "Killing process $pid"
                kill -TERM "$pid" 2>/dev/null || true
                # Wait briefly
                (sleep 0.5; kill -KILL "$pid" 2>/dev/null) &
            fi
        fi
    done
    [[ -n "$temp_dir" ]] && rm -rf "$temp_dir"
}
```

### FIX-8: Add Stale Task Recovery to SQLite
**File**: `lib/sqlite-state.sh`
**Priority**: P1
**Impact**: Automatically resets tasks held by dead workers.

```bash
# ADD function to sqlite-state.sh
recover_zombie_tasks() {
    local timeout_minutes="${1:-60}"
    
    _sqlite_exec "$STATE_DB" <<EOF
    -- Reset tasks where worker hasn't heartbeat in X minutes
    UPDATE tasks 
    SET state='QUEUED', worker_id=NULL, updated_at=datetime('now')
    WHERE state='RUNNING' 
      AND worker_id IN (
          SELECT worker_id FROM workers 
          WHERE last_heartbeat < datetime('now', '-$timeout_minutes minutes')
      );
      
    -- Mark those workers as dead
    UPDATE workers
    SET status='dead'
    WHERE last_heartbeat < datetime('now', '-$timeout_minutes minutes')
      AND status != 'dead';
EOF
}
```

### FIX-9: Improve Circuit Breaker Atomic Read
**File**: `lib/circuit-breaker.sh`
**Priority**: P2
**Impact**: Prevents partial reads of state files.

```bash
# REPLACE _read_breaker_state
_read_breaker_state() {
    local model="$1"
    local state_file="$(_get_breaker_file "$model")"
    
    # Use flock for shared lock if available, otherwise just read
    if command -v flock >/dev/null; then
        (
            flock -s 200
            if [[ -f "$state_file" ]]; then
                grep -E "^state=" "$state_file" | head -1 | cut -d'=' -f2-
            else
                echo "CLOSED"
            fi
        ) 200<"$state_file" 2>/dev/null || echo "CLOSED"
    else
        # Fallback
        if [[ -f "$state_file" ]]; then
            grep -E "^state=" "$state_file" | head -1 | cut -d'=' -f2-
        else
            echo "CLOSED"
        fi
    fi
}
```

### FIX-10: Add Model Routing to Worker
**File**: `bin/tri-agent-worker`
**Priority**: P1
**Impact**: Ensures worker uses the model assigned by the pool/router.

```bash
# MODIFY execute_task function
execute_task() {
    local task_file="$1"
    # ... existing parsing ...
    
    # Check if a specific model was assigned in DB
    local assigned_model
    assigned_model=$("${PROJECT_ROOT}/lib/sqlite-state.sh" state_get "tasks" "${TASK_ID}_model" "")
    
    # If not in DB, check env var from pool
    if [[ -z "$assigned_model" ]]; then
        assigned_model="${WORKER_MODEL:-}"
    fi
    
    # If still empty, use heuristic routing
    if [[ -z "$assigned_model" ]]; then
        assigned_model=$(route_to_model "$TASK_TYPE" "$context_size")
    fi
    
    log_info "Executing with model: $assigned_model"
    # ... proceed with execution ...
}
```

### FIX-11: Harden Health Check JSON Output
**File**: `bin/health-check`
**Priority**: P2
**Impact**: Ensures valid JSON output for monitoring tools.

```bash
# REPLACE JSON generation block
    # Build JSON output using jq to ensure validity
    if command -v jq >/dev/null; then
        local health_json
        health_json=$(jq -n \
            --arg status "$overall_status" \
            --arg ts "$timestamp" \
            --arg trace "${TRACE_ID:-unknown}" \
            --arg disk "$disk_status" \
            --arg error_rate "$error_count" \
            --arg session "$session_status" \
            --argjson issues "$issues_json" \
            '{ 
                status: $status,
                timestamp: $ts,
                trace_id: $trace,
                checks: {
                    disk: $disk,
                    error_rate: ($error_rate | tonumber),
                    session: $session
                },
                issues: $issues
            }')
        echo "$health_json" > "$HEALTH_FILE"
        echo "$health_json"
    else
        # Fallback manual JSON construction (risky but needed if jq missing)
        # ... existing fallback code ...
    fi
```

### FIX-12: Update Preflight for SQLite
**File**: `bin/tri-agent-preflight` (assuming existence or creating)
**Priority**: P1
**Impact**: Fails fast if SQLite environment is not ready.

```bash
# ADD check to preflight
check_sqlite_env() {
    if ! command -v sqlite3 >/dev/null; then
        echo "FAIL: sqlite3 not found"
        return 1
    fi
    
    if ! "${PROJECT_ROOT}/lib/sqlite-state.sh" sqlite_state_init; then
        echo "FAIL: Could not initialize SQLite DB"
        return 1
    fi
    
    echo "PASS: SQLite environment ready"
    return 0
}
```

### FIX-13: Enhance Cost Tracker Precision
**File**: `lib/cost-tracker.sh` (referenced in common.sh)
**Priority**: P2
**Impact**: Improves budget accuracy.

```bash
# ADD token counting function (if missing)
estimate_tokens() {
    local text="$1"
    local len=${#text}
    # Rough estimate: 4 chars per token
    echo $((len / 4))
}

track_cost() {
    local model="$1"
    local input_len="$2"
    local output_len="$3"
    
    local in_tok=$(estimate_tokens "$input_len")
    local out_tok=$(estimate_tokens "$output_len")
    
    # Log to CSV/JSONL for watchdog
    echo "{"timestamp":"$(date -Iseconds)","model":"$model","input_tokens":$in_tok,"output_tokens":$out_tok}" \
        >> "${COST_LOG_DIR}/costs.jsonl"
}
```

### FIX-14: Unify Logging
**File**: `lib/logging.sh` (create or update)
**Priority**: P2
**Impact**: Consistent trace IDs across all components.

```bash
# ENSURE log_json function exists
log_json() {
    local level="$1"
    local msg="$2"
    local extra="${3:-{}}"
    
    local ts=$(date -Iseconds)
    echo "{"timestamp":"$ts","level":"$level","trace_id":"${TRACE_ID:-}","message":"$msg","data":$extra}" \
        >> "${LOG_DIR}/system.jsonl"
}
```

### FIX-15: Fix Rate Limiter State Path
**File**: `lib/rate-limiter.sh`
**Priority**: P2
**Impact**: Ensures rate limits persist across restarts.

```bash
# UPDATE state path
RATE_LIMIT_DB="${STATE_DIR}/rate-limits.db"

_init_rate_limit_db() {
    sqlite3 "$RATE_LIMIT_DB" "CREATE TABLE IF NOT EXISTS limits (key TEXT PRIMARY KEY, count INTEGER, reset_at INTEGER);"
}
```

---

## SECTION 6: NEW FILES TO CREATE

### 6.1 `config/routing-policy.yaml`
**Purpose**: Defines rules for delegating tasks to models.
**Content**:
```yaml
rules:
  - name: "Large Context Analysis"
    condition: "context_tokens > 100000"
    model: "gemini"
    reason: "Exceeds Claude context window"

  - name: "Security Audit"
    condition: "task_type == 'security'"
    model: "consensus"
    reason: "Requires multi-model validation"

  - name: "Implementation"
    condition: "task_type == 'feature' OR task_type == 'bugfix'"
    model: "codex"
    reason: "Specialized for code generation"

defaults:
  model: "claude"
```

### 6.2 `bin/tri-agent-auditor`
**Purpose**: Dedicated daemon for security/compliance scanning (decoupled from supervisor).
**Content**:
```bash
#!/bin/bash
source "$(dirname $0)/../lib/common.sh"

while true; do
    # Scan recent commits
    # Run security checks
    # Sleep
    sleep 300
done
```

---

## SECTION 7: SDLC PHASE ENFORCEMENT

### 7.1 State Machine
```
[BRAINSTORM] --(Spec Approved)--> [DOCUMENT] --(Docs Reviewed)--> [PLAN] --(Plan Approved)--> [EXECUTE] --(Tests Pass)--> [TRACK]
      ^                                                                                             |
      └────────────────────────────────(Rejection)──────────────────────────────────────────────────┘
```

### 7.2 Enforcement Logic (`lib/supervisor-approver.sh`)
- **Phase 1 (Brainstorm)**: Output must be `spec/*.md`. Gate: Stakeholder consensus.
- **Phase 2 (Document)**: Output `docs/*.md`, `API.md`. Gate: Link check, clarity score.
- **Phase 3 (Plan)**: Output `tasks/*.md`. Gate: Dependency graph valid.
- **Phase 4 (Execute)**: Output code changes. Gate: Tests, Coverage, Lint.
- **Phase 5 (Track)**: Output `changelog`, metrics. Gate: Production verification.

**Integration**: `quality_gate` function will check `current_phase` from SQLite and apply phase-specific checks.

---

## SECTION 8: TRI-SUPERVISOR DESIGN

### 8.1 Unified Logic
The supervisor will evolve into a **Coordinator Process** that manages three sub-agents:
1.  **Auditor** (Security/Compliance) - Runs passively.
2.  **Approver** (Quality Gates) - Runs on `submit_for_review`.
3.  **Planner** (Phase Transitions) - Runs on completion.

### 8.2 Consensus Protocol (Consolidated)
- **Trigger**: Any P0 task or Security alert.
- **Process**:
    1.  Supervisor pauses task.
    2.  Spawns `tri-agent-consensus`.
    3.  If `REJECT` -> Move to `rejected/`.
    4.  If `APPROVE` -> Move to `approved/`.

---

## SECTION 9: SELF-HEALING DESIGN

### 9.1 Hierarchy of Recovery
1.  **Process Level** (systemd/supervisord): Restarts `tri-agent` if it crashes.
2.  **Worker Level** (Watchdog):
    - Periodically checks SQLite `last_heartbeat`.
    - If > 5min, kills PID and restarts worker.
    - Resets task status to `QUEUED`.
3.  **Task Level** (Worker Loop):
    - Try/Catch blocks around execution.
    - On error, increment `retry_count` in SQLite.
    - If `retry_count > 3`, move to `failed/` and alert.

### 9.2 Implementation
- **Watchdog**: `bin/health-check --daemon` configured to auto-restart components.
- **State Repair**: `tri-agent-preflight --fix` runs on startup to clean lock files and reset dangling DB states.

---

## SECTION 10: PRIORITY MATRIX

| Priority | ID | Task | Component | Effort | Milestone |
|----------|----|------|-----------|--------|-----------|
| **P0** | 1 | Fix `tri-agent-worker` to use SQLite locking | `bin/tri-agent-worker` | 4h | M1 |
| **P0** | 2 | Implement Signal-based Pause in Worker | `bin/tri-agent-worker` | 2h | M1 |
| **P0** | 3 | Activate Budget Watchdog Signaling | `bin/budget-watchdog` | 2h | M1 |
| **P0** | 4 | Fix Worker Pool Sharding Injection | `lib/worker-pool.sh` | 2h | M1 |
| **P1** | 5 | Unify Supervisor Logic | `bin/tri-agent-supervisor` | 4h | M2 |
| **P1** | 6 | Add SQLite Preflight Checks | `bin/tri-agent-preflight` | 1h | M2 |
| **P1** | 7 | Implement Zombie Task Recovery | `lib/sqlite-state.sh` | 2h | M2 |
| **P1** | 8 | Fix Model Routing in Worker | `bin/tri-agent-worker` | 2h | M2 |
| **P2** | 9 | Enhance Health Check JSON | `bin/health-check` | 1h | M3 |
| **P2** | 10 | Improve Circuit Breaker Atomic Read | `lib/circuit-breaker.sh` | 1h | M3 |
| **P2** | 11 | Add Cost Tracking Precision | `lib/cost-tracker.sh` | 2h | M3 |
| **P2** | 12 | Create Routing Policy Config | `config/routing-policy.yaml` | 1h | M3 |
| **P2** | 13 | Unified Logging Format | `lib/logging.sh` | 2h | M3 |
| **P2** | 14 | Update Rate Limiter State Path | `lib/rate-limiter.sh` | 1h | M3 |
| **P3** | 15 | Create Tri-Agent Auditor | `bin/tri-agent-auditor` | 3h | M4 |
| **P3** | 16 | Implement SDLC Phase Gates | `lib/supervisor-approver.sh` | 4h | M4 |
| **P3** | 17 | Add Dashboard UI (CLI) | `bin/tri-agent-dashboard` | 4h | M4 |
| **P3** | 18 | Optimize SQLite Indexes | `lib/sqlite-state.sh` | 1h | M4 |
| **P3** | 19 | Add Slack/Discord Notifications | `lib/notifications.sh` | 2h | M5 |
| **P3** | 20 | Final Security Hardening | All | 4h | M5 |

---

## SECTION 11: IMPLEMENTATION TIMELINE

### Phase 1: Stabilization (M1) - Days 1-2
- **Goal**: System runs without race conditions or resource leaks.
- **Deliverables**: Atomic worker, working watchdog, sharded pool.
- **Validation**: Run 3 workers in parallel, flood queue, verify no overlaps.

### Phase 2: Core Autonomy (M2) - Days 3-4
- **Goal**: Full autonomous loop (Queue -> Work -> Review -> Approve).
- **Deliverables**: Unified supervisor, routing logic, zombie recovery.
- **Validation**: End-to-end task completion without human input.

### Phase 3: Resilience & Scale (M3) - Days 5-6
- **Goal**: Self-healing and observability.
- **Deliverables**: Health JSON, precise costs, circuit breakers.
- **Validation**: Kill processes randomly, verify auto-recovery.

### Phase 4: Feature Completeness (M4) - Days 7-8
- **Goal**: Advanced SDLC features.
- **Deliverables**: Auditor, Phase gates, Dashboard.
- **Validation**: Full SDLC compliance check.

### Phase 5: Hardening (M5) - Day 9
- **Goal**: Security and Optimization.
- **Deliverables**: Hardened configs, performance tuning.
- **Validation**: Security audit pass.

---

## SECTION 12: VERIFICATION TEST SUITE

### Test 1: Atomic Locking Verification
```bash
#!/bin/bash
# test_locking.sh
# Spawns 10 concurrent processes trying to claim the same task
task_id="TEST_LOCK_001"
echo "Creating test task..."
"${PROJECT_ROOT}/lib/sqlite-state.sh" create_task "$task_id" "Test Lock" "test" "HIGH"

count=0
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
# Success criteria: Only ONE "GOT LOCK" output
```

### Test 2: Watchdog Signal Verification
```bash
#!/bin/bash
# test_watchdog.sh
# Mock a high cost and check if worker pauses
export COST_LOG_DIR="/tmp/mock_costs"
mkdir -p "$COST_LOG_DIR"
# Write high cost entry
echo "{"timestamp":"$(date -Iseconds)","model":"claude","input_tokens":1000000,"output_tokens":1000000}" > "$COST_LOG_DIR/cost.jsonl"

# Start dummy worker
(
    trap 'echo "PAUSED"; exit 0' SIGUSR1
    while true; do sleep 1; done
) &
pid=$!

# Run watchdog
"${PROJECT_ROOT}/bin/budget-watchdog" --once --kill-rate 0.01

# Check if worker exited
wait $pid
# Success criteria: Worker prints "PAUSED"
```

### Test 3: End-to-End Task Flow
```bash
#!/bin/bash
# test_e2e.sh
# Create task -> Worker -> Supervisor -> Approved
"${PROJECT_ROOT}/lib/sqlite-state.sh" create_task "E2E_001" "E2E Test" "feature" "MEDIUM"
"${PROJECT_ROOT}/bin/tri-agent-worker" --once
"${PROJECT_ROOT}/bin/tri-agent-supervisor" --once
# Verify file exists in tasks/approved/E2E_001.md
ls "${PROJECT_ROOT}/tasks/approved/E2E_001.md"
```

---

## SECTION 11: IMPLEMENTATION TIMELINE

### Phase 1: Stabilization (M1) - Days 1-2
- **Goal**: System runs without race conditions or resource leaks.
- **Deliverables**: Atomic worker, working watchdog, sharded pool.
- **Validation**: Run 3 workers in parallel, flood queue, verify no overlaps.

### Phase 2: Core Autonomy (M2) - Days 3-4
- **Goal**: Full autonomous loop (Queue -> Work -> Review -> Approve).
- **Deliverables**: Unified supervisor, routing logic, zombie recovery.
- **Validation**: End-to-end task completion without human input.

### Phase 3: Resilience & Scale (M3) - Days 5-6
- **Goal**: Self-healing and observability.
- **Deliverables**: Health JSON, precise costs, circuit breakers.
- **Validation**: Kill processes randomly, verify auto-recovery.

### Phase 4: Feature Completeness (M4) - Days 7-8
- **Goal**: Advanced SDLC features.
- **Deliverables**: Auditor, Phase gates, Dashboard.
- **Validation**: Full SDLC compliance check.

### Phase 5: Hardening (M5) - Day 9
- **Goal**: Security and Optimization.
- **Deliverables**: Hardened configs, performance tuning.
- **Validation**: Security audit pass.

---

## SECTION 12: VERIFICATION TEST SUITE

### Test 1: Atomic Locking Verification
```bash
#!/bin/bash
# test_locking.sh
# Spawns 10 concurrent processes trying to claim the same task
task_id="TEST_LOCK_001"
echo "Creating test task..."
"${PROJECT_ROOT}/lib/sqlite-state.sh" create_task "$task_id" "Test Lock" "test" "HIGH"

count=0
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
# Success criteria: Only ONE "GOT LOCK" output
```

### Test 2: Watchdog Signal Verification
```bash
#!/bin/bash
# test_watchdog.sh
# Mock a high cost and check if worker pauses
export COST_LOG_DIR="/tmp/mock_costs"
mkdir -p "$COST_LOG_DIR"
# Write high cost entry
echo "{"timestamp":"$(date -Iseconds)","model":"claude","input_tokens":1000000,"output_tokens":1000000}" > "$COST_LOG_DIR/cost.jsonl"

# Start dummy worker
(
    trap 'echo "PAUSED"; exit 0' SIGUSR1
    while true; do sleep 1; done
) &
pid=$!

# Run watchdog
"${PROJECT_ROOT}/bin/budget-watchdog" --once --kill-rate 0.01

# Check if worker exited
wait $pid
# Success criteria: Worker prints "PAUSED"
```

### Test 3: End-to-End Task Flow
```bash
#!/bin/bash
# test_e2e.sh
# Create task -> Worker -> Supervisor -> Approved
"${PROJECT_ROOT}/lib/sqlite-state.sh" create_task "E2E_001" "E2E Test" "feature" "MEDIUM"
"${PROJECT_ROOT}/bin/tri-agent-worker" --once
"${PROJECT_ROOT}/bin/tri-agent-supervisor" --once
# Verify file exists in tasks/approved/E2E_001.md
ls "${PROJECT_ROOT}/tasks/approved/E2E_001.md"
```

---

**End of Plan v3**
