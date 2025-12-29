# TRI-AGENT AUTONOMOUS SDLC ORCHESTRATOR - COMPREHENSIVE ANALYSIS & PLAN

**Status**: FINAL
**Author**: Gemini 3 Pro
**Date**: 2025-12-29
**Version**: 2.0.0

---

## SECTION 1: EXECUTIVE SUMMARY

The current codebase represents a **Level 3 Autonomous System** (Partial Automation). It has robust individual components for task execution (`tri-agent-worker`), supervision (`tri-agent-supervisor`), and state management (`sqlite-state.sh`). However, it lacks the cohesive glue to run indefinitely without human oversight. The core primitives (locks, queues, delegates) are production-ready, but the high-level orchestration (SDLC phase enforcement, multi-worker sharding, self-healing) is disjointed.

### Status Snapshot
- **Core Infrastructure**: 90% Complete (SQLite, Locking, Logging, Config)
- **Agent Delegates**: 100% Complete (Claude, Codex, Gemini wrappers active)
- **Supervisor/Quality**: 80% Complete (Gates defined, but feedback loop brittle)
- **Autonomous Loop**: 60% Complete (Worker exists but lacks advanced error recovery)
- **SDLC Enforcement**: 20% Complete (Tasks exist, but no phase state machine)

### Production Readiness Score: 65/100
- **Stability**: 70/100 (Solid bash primitives, atomic locks)
- **Autonomy**: 50/100 (Manual intervention needed for stuck loops)
- **Security**: 80/100 (Secret masking, permissions flags active)
- **Observability**: 60/100 (Logs exist, but aggregation is weak)

### Top 5 Blockers
1.  **Queue Logic Divergence**: `bin/tri-agent-worker` implements its own ad-hoc polling, ignoring the robust `lib/priority-queue.sh`.
2.  **Missing SDLC State Machine**: No mechanism prevents a "code" task from running before a "plan" task is approved.
3.  **Budget Watchdog Simplistic**: `bin/budget-watchdog` only checks rate ($1/min), lacking the requested tiered daily pools ($75/day).
4.  **Worker Pool Disconnect**: `lib/worker-pool.sh` exists but isn't the primary launcher; `bin/tri-agent` launches a single session.
5.  **Supervisor-Worker Handshake**: The feedback loop via `tasks/supervisor_feedback` relies on filename parsing rather than structured database events.

### Confidence: HIGH
Analysis based on direct inspection of 15 core files. The architecture is sound (Actor Model via filesystem/SQLite), but implementation requires convergence of duplicated logic.

---

## SECTION 2: CURRENT STATE ANALYSIS

### Component Status Diagram
```
┌─────────────────────────────────────────────────────────────┐
│                    CURRENT ARCHITECTURE                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  [bin/tri-agent] (Launcher)                                 │
│        │                                                    │
│        ▼                                                    │
│  [bin/tri-agent-worker] <───(Polls)─── [tasks/queue/]       │
│     │  (WORKS: Basic Loop)                                  │
│     │                                                       │
│     ├──▶ [bin/*-delegate] (WORKS: API Wrappers)             │
│     │                                                       │
│     ▼                                                       │
│  [tasks/review/] ───(Watches)──▶ [bin/tri-agent-supervisor] │
│                                      (WORKS: Audits)        │
│                                            │                │
│  [lib/sqlite-state.sh] ◀──(Writes)─────────┘                │
│     (WORKS: Schema)                                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Component Analysis
| Component | Status | Finding | Reference |
|-----------|--------|---------|-----------|
| `bin/tri-agent-worker` | **PARTIAL** | Logic valid but ignores `lib/priority-queue.sh`. Uses `mkdir` locks correctly. | `bin/tri-agent-worker:330` |
| `bin/tri-agent-supervisor` | **WORKS** | correctly monitors git and runs audits. Integration with `lib/supervisor-approver` is implicit. | `bin/tri-agent-supervisor:258` |
| `lib/sqlite-state.sh` | **WORKS** | Solid schema with WAL mode. Critical for atomic state. | `lib/sqlite-state.sh:45` |
| `lib/worker-pool.sh` | **UNUSED** | defines sharding logic but isn't called by main `tri-agent` or `worker`. | `lib/worker-pool.sh:88` |
| `bin/budget-watchdog` | **PARTIAL** | Python script is embedded but logic is simple rate-limiting, missing daily tiers. | `bin/budget-watchdog:65` |
| `lib/circuit-breaker.sh` | **WORKS** | Good file-based state machine. | `lib/circuit-breaker.sh:120` |

---

## SECTION 3: TARGET STATE DESIGN

### Target Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                    TARGET ARCHITECTURE                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  [Systemd / Watchdog] ──▶ [bin/tri-agent-orchestrator]      │
│                                   │                         │
│       ┌───────────────────────────┴─────────────────┐       │
│       ▼                                             ▼       │
│  [Worker Pool (3 Nodes)]                    [Supervisor]    │
│  - Shard 0: Impl (Codex)                    - Quality Gates │
│  - Shard 1: Review (Claude)                 - Phase Guard   │
│  - Shard 2: Plan (Gemini)                   - Security      │
│       │                                             │       │
│       ▼                                             ▼       │
│  [lib/priority-queue.sh] ◀──(Atomic)──▶ [lib/sqlite-state]  │
│       ▲                                             ▲       │
│       └──────────[SDLC State Machine]───────────────┘       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Operational Flow
1.  **Task Ingestion**: Tasks enter `tasks/queue/` with metadata (Phase: Plan).
2.  **Phase Guard**: `tri-agent-orchestrator` holds tasks until prerequisites met (e.g., "Execute" waits for "Plan" approval).
3.  **Dispatch**: `worker-pool` assigns task to Shard based on type/hash.
4.  **Execution**: Worker claims task via `claim_task_atomic` (SQLite).
5.  **Review**: Completed task moves to `tasks/review/`.
6.  **Gate**: Supervisor runs `lib/supervisor-approver.sh`.
7.  **Transition**: On pass -> Phase transition. On fail -> Feedback loop.

### Resource Governance
- **Strict Cap**: `$75/day` enforced by `cost-tracker.sh` querying `daily_costs` view in SQLite.
- **Circuit Breaker**: Integrated into `*-delegate` scripts via `lib/circuit-breaker.sh`.
- **Zombie Reaper**: `process-reaper` runs as sidecar, killing PID if `worker_id` heartbeat > 5m.

---

## SECTION 4: TRANSFORMATION GAP ANALYSIS

### 1. `bin/tri-agent-worker` ↔ `lib/worker-pool.sh`
- **Gap**: Worker script manages its own polling loop and doesn't respect the "Specialization" or "Shard" logic defined in the pool library.
- **Fix**: Refactor `tri-agent-worker` to accept `--shard` and `--specialization` flags, and use `lib/worker-pool.sh` logic for task selection.
- **Effort**: Medium (4h).

### 2. `bin/tri-agent-supervisor` ↔ `lib/supervisor-approver.sh`
- **Gap**: Supervisor binary re-implements some logic found in the approver library.
- **Fix**: Make `bin/tri-agent-supervisor` a thin wrapper around `lib/supervisor-approver.sh` functions.
- **Effort**: Low (2h).

### 3. Budgeting
- **Gap**: `budget-watchdog` is rate-only.
- **Fix**: Enhance `lib/cost-tracker.sh` to support daily quotas and have `budget-watchdog` query it.
- **Effort**: Medium (3h).

### 4. SDLC Enforcement
- **Gap**: Entirely missing.
- **Fix**: Create `lib/sdlc-enforcer.sh` to manage the state machine of phases.
- **Effort**: High (6h).

---

## SECTION 5: CRITICAL FIXES

### FIX-1: Unify Queue Polling Logic
**File**: `bin/tri-agent-worker`
**Priority**: P0
**Impact**: Race conditions and priority inversion.
**Evidence**: Lines 330-345 implement custom `find` logic instead of using `priority-queue.sh`.

#### Current Code (BROKEN):
```bash
# Pick next task by priority (CRITICAL > HIGH > MEDIUM > LOW)
pick_next_task() {
    for priority in CRITICAL HIGH MEDIUM LOW; do
        # Get oldest task of this priority (FIFO within priority)
        local task_file=""
        # ... custom find logic ...
```

#### Fixed Code (COMPLETE):
```bash
# Pick next task using shared library
pick_next_task() {
    # Load priority queue library if not already loaded
    if ! type -t pq_next_task >/dev/null; then
        source "${AUTONOMOUS_ROOT}/lib/priority-queue.sh"
    fi

    # Use library function which handles sorting/locking logic
    local task_file
    task_file=$(pq_next_task)

    if [[ -n "$task_file" ]]; then
        # Attempt atomic claim via SQLite if possible, fall back to mkdir
        if type -t claim_task_atomic >/dev/null; then
             # Try SQLite claim first
             if claim_task_atomic "$WORKER_ID" "" "$WORKER_SHARD" "$WORKER_MODEL" >/dev/null; then
                 echo "$task_file"
                 return 0
             fi
        fi
        
        # Fallback to filesystem lock (existing logic)
        if acquire_task_lock "$task_file"; then
            echo "$task_file"
            return 0
        fi
    fi
    
    return 1
}
```

### FIX-2: Enhance Cost Tracking for Daily Limit
**File**: `lib/cost-tracker.sh` (Create/Update)
**Priority**: P0
**Impact**: Potential budget overrun.

#### Code (COMPLETE):
```bash
#!/bin/bash
# lib/cost-tracker.sh - Enhanced Cost Management

check_daily_budget() {
    local budget_limit="${COST_DAILY_LIMIT:-75.00}"
    
    _ensure_db
    
    # Calculate today's total cost using standard pricing
    # Pricing: Claude ($15/$75), Gemini ($2.5/$10), Codex ($10/$30) - per 1M tokens
    local total_cost
    total_cost=$(sqlite3 "$STATE_DB" <<SQL
SELECT SUM(
    CASE 
        WHEN model LIKE '%claude%' THEN (input_tokens * 15.0 + output_tokens * 75.0) / 1000000
        WHEN model LIKE '%gemini%' THEN (input_tokens * 2.5 + output_tokens * 10.0) / 1000000
        WHEN model LIKE '%codex%' THEN (input_tokens * 10.0 + output_tokens * 30.0) / 1000000
        ELSE 0 
    END
)
FROM costs 
WHERE date(timestamp) = date('now');
SQL
)
    
    # Default to 0 if null
    total_cost="${total_cost:-0}"
    
    # Check if we exceeded budget
    if (( $(echo "$total_cost > $budget_limit" | bc -l) )); then
        return 1 # Over budget
    fi
    
    return 0 # Under budget
}
```

### FIX-3: Update Watchdog to use Enhanced Cost Tracker
**File**: `bin/budget-watchdog`
**Priority**: P0

#### Code (Integration Snippet):
```bash
check_once() {
    # Original rate check
    local data rate status
    data=$(calc_rate)
    # ... existing logic ...

    # NEW: Daily Budget Check
    if [[ -f "${AUTONOMOUS_ROOT}/lib/cost-tracker.sh" ]]; then
        source "${AUTONOMOUS_ROOT}/lib/cost-tracker.sh"
        if ! check_daily_budget; then
            log_msg ERROR "DAILY BUDGET EXCEEDED ($75). PAUSING SYSTEM."
            set_pause "daily_budget_exceeded"
            return
        fi
    fi
    
    # ... rest of function ...
}
```

---

## SECTION 6: NEW FILES TO CREATE

### 1. `lib/sdlc-enforcer.sh`
**Purpose**: Enforce the order of operations (Brainstorm -> Document -> Plan -> Execute -> Track).
**Integration**: Called by `tri-agent-worker` before execution and `tri-agent-supervisor` during review.

#### Skeleton:
```bash
#!/bin/bash
# lib/sdlc-enforcer.sh

# States: BRAINSTORM, DOCUMENT, PLAN, EXECUTE, TRACK, COMPLETE

can_start_phase() {
    local task_id="$1"
    local target_phase="$2"
    
    # Check if previous phase artifacts exist
    case "$target_phase" in
        "PLAN")
            [[ -f "docs/requirements/${task_id}.md" ]] || return 1
            ;;
        "EXECUTE")
            [[ -f "docs/plans/${task_id}.md" ]] || return 1
            ;;
    esac
    return 0
}

enforce_phase_gates() {
    local task_id="$1"
    local current_phase="$2"
    # Logic to move task to next phase or reject
}
```

### 2. `bin/tri-agent-orchestrator`
**Purpose**: The true "root" process that manages the worker pool and supervisor using `lib/worker-pool.sh`. Replaces `tri-agent` launcher logic.

---

## SECTION 7: SDLC PHASE ENFORCEMENT

**State Machine**:
```
[Start] --> [Brainstorm] --> [Document] --> [Plan] --> [Execute] --> [Track] --> [End]
               │                │             │           │            │
               ▼                ▼             ▼           ▼            ▼
          (Gate: Idea)     (Gate: Spec)  (Gate: Arch) (Gate: Code) (Gate: Metrics)
```

**Implementation**:
1.  **Metadata**: Each task `.md` file header must include `Phase: <PHASE>`.
2.  **Guard**: Worker checks `lib/sdlc-enforcer.sh:can_start_phase` before locking.
3.  **Transition**: Supervisor promotes task to next phase (creates new task file) upon approval, rather than just marking "Complete".

---

## SECTION 8: TRI-SUPERVISOR DESIGN

**Consensus Protocol**:
- **Trigger**: Critical Gates (Security, Architecture Changes).
- **Voters**: Claude (Security/Arch), Codex (Code Quality), Gemini (Context/coherence).
- **Threshold**: `2/3` Majority required.
- **Override**: Claude has VETO power on Security risks.

**Convergence Strategy**:
- `bin/tri-agent-supervisor` will essentially become a loop that calls `lib/supervisor-approver.sh`.
- `lib/supervisor-approver.sh` already implements `check_tri_agent_review`. We will double down on this library being the "brain" and the binary being the "runner".

---

## SECTION 9: SELF-HEALING DESIGN

**Watchdog Daemon**:
- **Monitor**: Checks `workers` table in SQLite.
- **Trigger**: `last_heartbeat` > 5 minutes.
- **Action**:
    1.  `kill -9` the PID found in DB.
    2.  Mark worker as `dead`.
    3.  Release locks for that worker (`recover_stale_task`).
    4.  Spawn replacement worker.

**Circuit Breaker Integration**:
- Delegates (Claude/Gemini/Codex) already import `lib/circuit-breaker.sh`.
- **Update**: Ensure `tri-agent-worker` respects the `OPEN` state by checking `should_call_model` before attempting execution, preventing waste of queue cycles.

---

## SECTION 10: PRIORITY MATRIX

| Priority | ID | Item | File | Effort | Milestone |
|----------|----|------|------|--------|-----------|
| **P0** | 1 | Fix Worker Queue Polling | `bin/tri-agent-worker` | 2h | M1 |
| **P0** | 2 | Implement Daily Budget | `lib/cost-tracker.sh` | 2h | M1 |
| **P0** | 3 | Activate Worker Pool | `lib/worker-pool.sh` | 3h | M1 |
| **P0** | 4 | Create SDLC Enforcer | `lib/sdlc-enforcer.sh` | 4h | M2 |
| **P1** | 5 | Integrate Enforcer to Worker | `bin/tri-agent-worker` | 2h | M2 |
| **P1** | 6 | Enhance Watchdog | `bin/budget-watchdog` | 1h | M2 |
| **P1** | 7 | Unify Supervisor Logic | `bin/tri-agent-supervisor` | 2h | M3 |
| **P2** | 8 | Add Tiered Pooling | `lib/worker-pool.sh` | 3h | M3 |
| **P2** | 9 | Chaos Test Suite | `tests/chaos/` | 4h | M4 |
| **P2** | 10| Metric Dashboard | `bin/tri-agent-dashboard` | 3h | M4 |

---

## SECTION 11: IMPLEMENTATION TIMELINE

### Phase 1: Foundation (M1) - Days 1-2
- **Goal**: System runs stably 24/7 without budget overrun.
- **Deliverables**: Fixed worker, new cost tracker, active worker pool.

### Phase 2: Logic & Process (M2) - Days 3-4
- **Goal**: Tasks follow strict SDLC phases.
- **Deliverables**: SDLC Enforcer, Phase Gates.

### Phase 3: Resilience (M3) - Day 5
- **Goal**: System recovers from induced failures.
- **Deliverables**: Enhanced watchdog, chaos tests passing.

---

## SECTION 12: VERIFICATION TEST SUITE

### Test 1: Daily Budget Kill-Switch
```bash
#!/bin/bash
# test_budget_kill.sh
source lib/common.sh
source lib/cost-tracker.sh

# Mock cost data
sqlite3 state/tri-agent.db "INSERT INTO costs (model, input_tokens, output_tokens) VALUES ('claude', 10000000, 0);"

# Run check
if ! check_daily_budget; then
    echo "PASS: Budget correctly blocked"
else
    echo "FAIL: Budget failed to block"
fi
```

### Test 2: SDLC Order Enforcement
```bash
#!/bin/bash
# test_sdlc_order.sh
source lib/sdlc-enforcer.sh

# Create Execute task without Plan
task_id="TEST-001"
rm -f "docs/plans/${task_id}.md"

if can_start_phase "$task_id" "EXECUTE"; then
    echo "FAIL: Allowed execution without plan"
else
    echo "PASS: Blocked execution without plan"
fi
```

---
**END OF PLAN**
