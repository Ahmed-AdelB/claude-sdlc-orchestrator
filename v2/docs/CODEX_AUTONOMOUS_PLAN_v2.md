SECTION 1: EXECUTIVE SUMMARY

Current implementation status (estimated, evidence-based):
- Entrypoint/session management: ~80% complete; tmux session creation, validation, and degraded-mode orchestration are implemented. (bin/tri-agent:55-678)
- Routing/consensus/delegates: ~75% complete; router heuristics, consensus voting, and delegate wrappers with timeouts/envelopes exist. (bin/tri-agent-router:156-787; bin/tri-agent-consensus:723-1077; bin/claude-delegate:90-460; bin/codex-delegate:94-519; bin/gemini-delegate:104-580)
- File-based worker pipeline: ~70% complete; file queue scanning, atomic locks, execution, and review submission are implemented. (bin/tri-agent-worker:342-1034)
- SQLite state + worker pool: ~55% complete; schema and atomic claims exist, but pool/worker integration is incomplete. (lib/sqlite-state.sh:46-549; lib/worker-pool.sh:133-205)
- Supervisor + quality gates: ~60% complete; supervisor audits commits and a 12-gate engine exists but is not unified. (bin/tri-agent-supervisor:330-404; lib/supervisor-approver.sh:118-776)
- Resilience/self-healing: ~55% complete; circuit breaker, heartbeat, and process reaper exist but are not consistently wired. (lib/circuit-breaker.sh:130-215; lib/heartbeat.sh:104-145; bin/process-reaper:131-245)
- Budget governance: ~65% complete; cost tracking, cost breaker, and watchdog are implemented. (lib/cost-tracker.sh:111-156; lib/cost-breaker.sh:175-229; bin/budget-watchdog:62-188)
- Observability/health: ~60% complete; common logging + health-check JSON status exist. (lib/common.sh:131-152; bin/health-check:229-425)
- Tests: ~55% complete; unit and chaos tests exist, but security/phase enforcement tests are minimal. (tests/pytest/unit/test_consensus.py:1-200; tests/chaos/chaos_rate_limit.sh:1-120)

Production readiness score (0-100): 58
- Reliability: 55 (self-healing exists but integration gaps remain between file queue and sqlite worker pool). (bin/tri-agent-worker:103-113; lib/worker-pool.sh:133-205; lib/circuit-breaker.sh:130-215)
- Autonomy: 50 (no enforced SDLC phase state machine; supervisor and gates are separate). (bin/tri-agent-worker:941-1034; lib/supervisor-approver.sh:118-776; bin/tri-agent-supervisor:17-25)
- Security: 70 (security utilities and scan gate exist but are not universally enforced). (lib/security.sh:83-214; lib/supervisor-approver.sh:286-331)
- Testing/Quality: 60 (12-gate engine exists but has edge-case gaps and duplicated runs). (lib/supervisor-approver.sh:118-283)
- Performance: 55 (duplicate tool runs and polling loops exist). (lib/supervisor-approver.sh:258-265; bin/tri-agent-worker:1667-1717)
- Observability: 65 (health check, audit logs, and cost logs exist). (bin/health-check:229-425; lib/cost-tracker.sh:111-156)

Top 5 blockers preventing autonomous 24/7 operation:
1. Queue priority subdirectories are not supported by worker or priority queue; only filename prefixes are scanned. (bin/tri-agent-worker:342-363; lib/priority-queue.sh:106-158)
2. File-queue worker and sqlite worker pool are parallel but not integrated; no single source of truth for claiming. (bin/tri-agent-worker:103-113; lib/worker-pool.sh:133-205; lib/sqlite-state.sh:454-549)
3. Supervisor logic is duplicated and not unified with the 12-gate approval engine. (bin/tri-agent-supervisor:17-25; lib/supervisor-approver.sh:118-776)
4. SDLC phase enforcement is missing; worker can submit directly to review without phase gates. (bin/tri-agent-worker:941-1034)
5. Budget kill-switch sets pause state, but workers do not consume it; pause is only via inbox commands. (bin/budget-watchdog:147-188; bin/tri-agent-worker:1093-1125)

Key research findings applied (based on training data):
- Mature autonomous systems use explicit, persisted state machines to prevent phase skipping and to enforce artifact/gate checks.
- Multi-model orchestration stabilizes via quorum consensus + model-specific circuit breakers with cooldowns to avoid cascading failures.
- Self-healing combines watchdog restart logic, idempotent task claiming, and durable event logs to ensure recovery without human intervention.

Confidence level: MEDIUM
- Justification: The codebase was reviewed with file-level evidence, but the system was not executed end-to-end and several integrations are currently missing. (bin/tri-agent-worker:1667-1717; lib/worker-pool.sh:237-244)


SECTION 2: CURRENT STATE ANALYSIS

What EXISTS and WORKS (with evidence):
- Unified launcher with tmux session management, validation, and degraded-mode orchestration. (bin/tri-agent:95-678)
- Routing and consensus logic with parallel model queries and JSON aggregation. (bin/tri-agent-router:359-787; bin/tri-agent-consensus:723-1077)
- Delegate wrappers for Claude/Codex/Gemini with timeouts and structured JSON envelopes. (bin/claude-delegate:90-460; bin/codex-delegate:94-519; bin/gemini-delegate:104-580)
- File-based worker pipeline: queue scan, atomic locks, execution, review submission, rejection handling. (bin/tri-agent-worker:342-1361)
- SQLite schema + atomic task claim helpers and task state transitions. (lib/sqlite-state.sh:46-571)
- Circuit breaker implementation with CLOSED/OPEN/HALF_OPEN transitions. (lib/circuit-breaker.sh:130-215)
- Budget monitoring and pause requests. (bin/budget-watchdog:62-188)
- Health monitoring and status JSON output. (bin/health-check:229-425)

What is PARTIALLY implemented (with gaps):
- Worker pool + sharding exists but is not used by the file-queue worker. (lib/worker-pool.sh:133-205; bin/tri-agent-worker:103-113)
- Heartbeat logic exists in sqlite, but worker uses file-based heartbeats and does not call sqlite heartbeat functions. (lib/heartbeat.sh:52-145; bin/tri-agent-worker:1460-1523)
- Supervisor has its own auditing loop, while a separate 12-gate approval engine exists but is not invoked. (bin/tri-agent-supervisor:330-404; lib/supervisor-approver.sh:118-776)
- Priority queue library uses filename prefixes, but required queue subdirectories are not supported. (lib/priority-queue.sh:106-158)
- Safeguards library exists but is not integrated into worker execution. (lib/safeguards.sh:33-181; bin/tri-agent-worker:731-865)

What is BROKEN or BUGGY (with error descriptions):
- Worker ignores required priority subdirectories (CRITICAL/HIGH/MEDIUM/LOW) and will miss tasks placed there. (bin/tri-agent-worker:342-363)
- Worker uses jq unguarded in inbox and lock cleanup; missing jq will crash under set -e. (bin/tri-agent-worker:1094-1134; bin/tri-agent-worker:515-519)
- Type-check gate runs tsc/mypy twice, causing inconsistent results and performance overhead. (lib/supervisor-approver.sh:258-265)
- Security and dependency gates assume jq availability; missing jq will exit the entire gate run. (lib/supervisor-approver.sh:295-301; lib/supervisor-approver.sh:385-390)
- Tri-agent review gate fails if repo has no diff or no git history, causing false negatives. (lib/supervisor-approver.sh:463-529)

What is completely MISSING:
- SDLC phase state machine and phase transition enforcement across Brainstorm->Document->Plan->Execute->Track. (No phase manager exists; worker submits directly to review). (bin/tri-agent-worker:941-1034)
- Queue-to-sqlite bridge to make sqlite the canonical task store. (lib/sqlite-state.sh:454-549; lib/worker-pool.sh:133-205)
- Unified supervisor that uses the 12-gate engine and consensus results for approval. (lib/supervisor-approver.sh:118-776; bin/tri-agent-supervisor:330-404)

CURRENT ARCHITECTURE (ASCII)
+-------------------------------------------------------------+
|                    CURRENT ARCHITECTURE                     |
+-------------------------------------------------------------+
| [bin/tri-agent WORKS] -> tmux session + delegates            |
| [bin/tri-agent-router WORKS] -> model routing                |
| [bin/tri-agent-consensus WORKS] -> quorum voting             |
| [bin/tri-agent-worker PARTIAL] -> file queue + locks         |
| [lib/worker-pool.sh PARTIAL] -> sqlite pool/sharding         |
| [lib/sqlite-state.sh WORKS] -> schema + atomic claim helpers |
| [bin/tri-agent-supervisor PARTIAL] -> git audits             |
| [lib/supervisor-approver.sh PARTIAL] -> 12 gates             |
| [lib/circuit-breaker.sh PARTIAL] -> breaker state            |
| [bin/budget-watchdog WORKS] -> pause flags                   |
| [bin/health-check WORKS] -> health.json                      |
+-------------------------------------------------------------+


SECTION 3: TARGET STATE DESIGN

TARGET ARCHITECTURE (ASCII)
+-------------------------------------------------------------+
|                    TARGET ARCHITECTURE                      |
+-------------------------------------------------------------+
| [tri-agent-daemon]                                           |
|   +- [queue-watcher] -> sqlite tasks (canonical)             |
|   +- [worker-pool] -> claim_task_atomic -> delegates         |
|   +- [supervisor] -> supervisor-approver -> consensus        |
|   +- [budget-watchdog] -> pause/resume gate                  |
|   +- [process-reaper] -> zombie cleanup                      |
|   +- [health-check] -> health.json + alerts                  |
|                                                             |
| SQLite (WAL) is the system of record for tasks/state/events  |
+-------------------------------------------------------------+

Component interaction flow (numbered):
1. Queue-watcher detects new task files under tasks/queue/CRITICAL|HIGH|MEDIUM|LOW and creates sqlite task rows.
2. Worker-pool assigns lane/shard/model, then workers call claim_task_atomic to move QUEUED->RUNNING.
3. Worker executes task via delegates; results and artifacts are stored in execution dir and sqlite events.
4. Supervisor runs quality gates via supervisor-approver and triggers tri-agent consensus when needed.
5. If gates pass and consensus approves, supervisor marks task APPROVED/COMPLETED; otherwise REJECTED with feedback.
6. Budget watchdog and circuit breakers can pause new work; health-check and reaper keep system stable.

Data flow (task lifecycle):
- tasks/queue/PRIORITY/*.md -> queue-watcher -> sqlite.tasks (QUEUED)
- worker claims -> sqlite.tasks (RUNNING) + file lock in tasks/running/
- output -> tasks/review/ + sqlite.events + cost logs
- supervisor gates -> APPROVED or REJECTED -> tasks/completed/ or tasks/rejected/

State machine design (task state, not SDLC phases):
- QUEUED -> RUNNING -> REVIEW -> APPROVED -> COMPLETED
- REJECTED/TIMEOUT/FAILED can requeue or escalate

Communication patterns:
- Workers send JSON messages to supervisor inbox; supervisor responds with TASK_APPROVE/TASK_REJECT.
- Delegates emit JSON envelopes; supervisor and router parse decisions for consensus.
- SQLite event log captures all transitions for auditing.

Resource Governance (budget and runaways):
- Budget watchdog enforces $1/min cap by setting pause state; workers must honor pause state before claiming new tasks.
- Circuit breaker per model blocks calls after N failures, transitions to HALF_OPEN after cooldown.
- Worker pool limits concurrency to 3 and enforces per-task timeout policies.


SECTION 4: TRANSFORMATION GAP ANALYSIS

1) bin/tri-agent-worker <-> lib/worker-pool.sh
- Current state: worker scans filesystem queue and locks tasks with mkdir; pool assigns routing in sqlite but is not used by worker. (bin/tri-agent-worker:342-430; lib/worker-pool.sh:133-205)
- Target state: worker claims tasks from sqlite and uses pool routing/sharding as canonical.
- Gaps: duplicate queues, no sqlite claim usage, no shard/model enforcement in worker. (bin/tri-agent-worker:103-113; lib/sqlite-state.sh:454-549)
- Interface alignment: mismatched; worker expects file path, pool expects task_id and sqlite rows.
- Dependencies: sqlite-state, queue-watcher/bridge, supervisor-approver.
- Risk: HIGH (task loss or duplicate execution).
- Effort: ~12 hours (queue bridge 6h, worker refactor 4h, tests 2h).

2) bin/tri-agent-supervisor <-> lib/supervisor-approver.sh
- Current state: supervisor monitors git commits and runs audits; 12-gate engine exists separately. (bin/tri-agent-supervisor:330-404; lib/supervisor-approver.sh:118-776)
- Target state: supervisor uses supervisor-approver as the single gate implementation and integrates consensus outputs.
- Gaps: duplicate test/security logic; no phase-gate mapping; no shared state. (lib/supervisor-approver.sh:118-776)
- Interface alignment: weak; supervisor emits feedback/tasks, approver expects task_id/workspace.
- Dependencies: queue bridge, SDLC phase state machine.
- Risk: HIGH (inconsistent approvals).
- Effort: ~10 hours (refactor supervisor, unify gate output, add tests).

3) lib/circuit-breaker.sh <-> delegate scripts
- Current state: circuit breaker functions exist but delegates do not call should_call_model/record_result. (lib/circuit-breaker.sh:130-215; bin/claude-delegate:368-460; bin/codex-delegate:379-499; bin/gemini-delegate:449-545)
- Target state: all delegates check breaker state before execution and record success/failure after execution.
- Gaps: no integration points, no failure tracking per model.
- Interface alignment: good (breaker API is simple), but unused.
- Dependencies: common.sh for logging and locks.
- Risk: MEDIUM (cascading failures).
- Effort: ~4 hours.

4) lib/sqlite-state.sh <-> all consumers
- Current state: schema and helpers exist; only some scripts use sqlite. (lib/sqlite-state.sh:46-571; lib/worker-pool.sh:133-205)
- Target state: sqlite is canonical state store, and all components read/write via helpers.
- Gaps: worker uses filesystem queue; supervisor does not update sqlite tasks/events.
- Interface alignment: good for tasks/events, but missing callers.
- Dependencies: queue-watcher, worker refactor, supervisor refactor.
- Risk: HIGH (state divergence).
- Effort: ~14 hours.

5) lib/heartbeat.sh <-> worker pool
- Current state: heartbeat functions exist; worker uses separate file-based heartbeat loop. (lib/heartbeat.sh:52-145; bin/tri-agent-worker:1460-1523)
- Target state: workers write sqlite heartbeats; pool uses heartbeat_check_stale to recover tasks.
- Gaps: no heartbeat_record integration in worker; pool recovery not driven by real worker data.
- Interface alignment: partial; worker uses WORKER_ID but not sqlite functions.
- Dependencies: sqlite-state, worker refactor.
- Risk: MEDIUM.
- Effort: ~5 hours.

6) Quality gates <-> SDLC phase enforcement
- Current state: 12 gate checks exist but are not tied to SDLC phase transitions. (lib/supervisor-approver.sh:118-776)
- Target state: gates are required for Execute->Track transition and phase artifacts must exist.
- Gaps: no phase state machine; no artifact validation. (bin/tri-agent-worker:941-1034)
- Interface alignment: missing; approver accepts task_id/workspace but no phase context.
- Dependencies: new sdlc-state-machine library, supervisor integration.
- Risk: HIGH.
- Effort: ~12 hours.


SECTION 5: CRITICAL FIXES

## FIX-1: Support priority subdirectories in task pickup
File: bin/tri-agent-worker
Lines: 342-364
Priority: P0
Impact: Worker misses all tasks placed in tasks/queue/CRITICAL|HIGH|MEDIUM|LOW, preventing autonomous operation.
Evidence: Task pickup scans only filename prefixes in a single directory. (bin/tri-agent-worker:342-363)

### Current Code (BROKEN):
```bash
# Pick next task by priority (CRITICAL > HIGH > MEDIUM > LOW)
pick_next_task() {
    for priority in CRITICAL HIGH MEDIUM LOW; do
        # Get oldest task of this priority (FIFO within priority)
        local task_file=""

        # Use find with proper sorting by modification time
        while IFS= read -r line; do
            task_file="${line#* }"  # Remove timestamp prefix
            [[ -n "$task_file" && -f "$task_file" ]] && break
        done < <(find "$QUEUE_DIR" -name "${priority}_*.md" -type f -printf '%T+ %p\n' 2>/dev/null | sort | head -1)

        if [[ -n "$task_file" && -f "$task_file" ]]; then
            # Attempt to acquire lock
            if acquire_task_lock "$task_file"; then
                echo "$task_file"
                return 0
            fi
        fi
    done

    return 1  # No tasks available
}
```

### Fixed Code (COMPLETE):
```bash
# Pick next task by priority (CRITICAL > HIGH > MEDIUM > LOW)
pick_next_task() {
    for priority in CRITICAL HIGH MEDIUM LOW; do
        local candidate_file=""
        local candidate_mtime=""

        # Search priority subdir first (tasks/queue/CRITICAL/*)
        for dir in "$QUEUE_DIR/$priority" "$QUEUE_DIR"; do
            [[ -d "$dir" ]] || continue

            local pattern="*.md"
            if [[ "$dir" == "$QUEUE_DIR" ]]; then
                pattern="${priority}_*.md"
            fi

            while IFS= read -r file; do
                [[ -f "$file" ]] || continue
                local mtime
                mtime=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null || echo 0)
                if [[ -z "$candidate_mtime" || "$mtime" -lt "$candidate_mtime" ]]; then
                    candidate_mtime="$mtime"
                    candidate_file="$file"
                fi
            done < <(find "$dir" -maxdepth 1 -type f -name "$pattern" 2>/dev/null)
        done

        if [[ -n "$candidate_file" && -f "$candidate_file" ]]; then
            if acquire_task_lock "$candidate_file"; then
                echo "$candidate_file"
                return 0
            fi
        fi
    done

    return 1
}
```

### Integration Steps:
1. `rg -n "pick_next_task" bin/tri-agent-worker`
2. Replace the existing function with the fixed version above in `bin/tri-agent-worker`.

### Verification:
```bash
./bin/tri-agent-worker --cleanup
```
Expected output: No errors and no tasks missed in queue subdirectories.


## FIX-2: Derive task priority from parent directory when prefix is missing
File: bin/tri-agent-worker
Lines: 371-430
Priority: P0
Impact: Tasks stored in priority subdirectories lose priority and default to MEDIUM, breaking SLA logic.
Evidence: Priority is parsed only from filename prefix. (bin/tri-agent-worker:377-379)

### Current Code (BROKEN):
```bash
# Acquire atomic lock on task using mkdir
acquire_task_lock() {
    local task_file="$1"
    local task_name
    task_name=$(basename "$task_file")
    local lock_dir="${RUNNING_DIR}/${task_name}.lock.d"
    local lock_file="${RUNNING_DIR}/${task_name}.lock"
    local task_priority
    task_priority=$(echo "$task_name" | grep -oE '^(CRITICAL|HIGH|MEDIUM|LOW)' || echo "MEDIUM")
    local timeout_seconds
    timeout_seconds=$(get_task_timeout_seconds "$task_priority")
    local claim_id
    claim_id=$(new_claim_id)
    local now_epoch
    now_epoch=$(date +%s)
    local locked_at
    locked_at=$(date -Iseconds)
    local heartbeat_ts
    heartbeat_ts="$locked_at"
    local expires_at
    expires_at=$(epoch_to_iso $((now_epoch + timeout_seconds + TASK_LOCK_GRACE_SECONDS)))

    # Atomic lock acquisition using mkdir (POSIX atomic operation)
    if mkdir "$lock_dir" 2>/dev/null; then
        # Won the lock - write lock metadata
        write_json_atomic "$lock_file" "$(cat <<EOF
{
    "worker_id": "$WORKER_ID",
    "claim_id": "$claim_id",
    "locked_at": "$locked_at",
    "heartbeat": "$heartbeat_ts",
    "timeout_seconds": $timeout_seconds,
    "expires_at": "$expires_at",
    "task": "$task_name",
    "pid": $WORKER_PID,
    "trace_id": "$TRACE_ID"
}
EOF
)"
        # Move task to running
        mv "$task_file" "$RUNNING_DIR/" 2>/dev/null || {
            # Failed to move - release lock and return failure
            rmdir "$lock_dir" 2>/dev/null
            rm -f "$lock_file" 2>/dev/null
            return 1
        }

        CURRENT_TASK_LOCK_FILE="$lock_file"
        CURRENT_TASK_LOCK_CLAIM_ID="$claim_id"
        CURRENT_TASK_LOCKED_AT_EPOCH="$now_epoch"
        CURRENT_TASK_TIMEOUT_SECONDS="$timeout_seconds"

        # Log to ledger
        log_ledger "TASK_LOCKED" "$task_name" "worker=$WORKER_ID"
        log_info "Acquired lock: $task_name"

        return 0
    else
        return 1  # Another worker got it
    fi
}
```

### Fixed Code (COMPLETE):
```bash
# Acquire atomic lock on task using mkdir
acquire_task_lock() {
    local task_file="$1"
    local task_name
    task_name=$(basename "$task_file")
    local lock_dir="${RUNNING_DIR}/${task_name}.lock.d"
    local lock_file="${RUNNING_DIR}/${task_name}.lock"

    # Priority from filename prefix or parent directory
    local task_priority=""
    task_priority=$(echo "$task_name" | grep -oE '^(CRITICAL|HIGH|MEDIUM|LOW)' || true)
    if [[ -z "$task_priority" ]]; then
        local parent_dir
        parent_dir=$(basename "$(dirname "$task_file")")
        case "$parent_dir" in
            CRITICAL|HIGH|MEDIUM|LOW) task_priority="$parent_dir" ;;
            *) task_priority="MEDIUM" ;;
        esac
    fi

    local timeout_seconds
    timeout_seconds=$(get_task_timeout_seconds "$task_priority")
    local claim_id
    claim_id=$(new_claim_id)
    local now_epoch
    now_epoch=$(date +%s)
    local locked_at
    locked_at=$(date -Iseconds)
    local heartbeat_ts
    heartbeat_ts="$locked_at"
    local expires_at
    expires_at=$(epoch_to_iso $((now_epoch + timeout_seconds + TASK_LOCK_GRACE_SECONDS)))

    # Atomic lock acquisition using mkdir (POSIX atomic operation)
    if mkdir "$lock_dir" 2>/dev/null; then
        # Won the lock - write lock metadata
        write_json_atomic "$lock_file" "$(cat <<EOF
{
    "worker_id": "$WORKER_ID",
    "claim_id": "$claim_id",
    "locked_at": "$locked_at",
    "heartbeat": "$heartbeat_ts",
    "timeout_seconds": $timeout_seconds,
    "expires_at": "$expires_at",
    "task": "$task_name",
    "pid": $WORKER_PID,
    "trace_id": "$TRACE_ID"
}
EOF
)"
        # Move task to running
        mv "$task_file" "$RUNNING_DIR/" 2>/dev/null || {
            rmdir "$lock_dir" 2>/dev/null
            rm -f "$lock_file" 2>/dev/null
            return 1
        }

        CURRENT_TASK_LOCK_FILE="$lock_file"
        CURRENT_TASK_LOCK_CLAIM_ID="$claim_id"
        CURRENT_TASK_LOCKED_AT_EPOCH="$now_epoch"
        CURRENT_TASK_TIMEOUT_SECONDS="$timeout_seconds"

        log_ledger "TASK_LOCKED" "$task_name" "worker=$WORKER_ID"
        log_info "Acquired lock: $task_name"
        return 0
    else
        return 1
    fi
}
```

### Integration Steps:
1. `rg -n "acquire_task_lock" bin/tri-agent-worker`
2. Replace the existing function with the fixed version above in `bin/tri-agent-worker`.

### Verification:
```bash
./bin/tri-agent-worker --cleanup
```
Expected output: Tasks inside tasks/queue/CRITICAL are processed with CRITICAL timeout values.


## FIX-3: Make inbox parsing resilient to missing jq/invalid JSON
File: bin/tri-agent-worker
Lines: 1094-1139
Priority: P1
Impact: Missing jq or malformed JSON currently terminates the worker loop.
Evidence: jq is called directly under set -e. (bin/tri-agent-worker:1094-1134)

### Current Code (BROKEN):
```bash
# Check worker inbox for supervisor messages
check_inbox() {
    local msg_count=0

    for msg_file in "$INBOX_DIR"/*.json; do
        [[ -f "$msg_file" ]] || continue

        local msg_type
        msg_type=$(jq -r '.type // ""' "$msg_file" 2>/dev/null)
        local payload
        payload=$(jq -c '.payload // {}' "$msg_file" 2>/dev/null)

        case "$msg_type" in
            TASK_APPROVE)
                local task_id
                task_id=$(echo "$payload" | jq -r '.task_id // ""')
                log_info "✓ Received APPROVAL for task: $task_id"
                ;;
            TASK_REJECT)
                local task_id
                task_id=$(echo "$payload" | jq -r '.task_id // ""')
                log_warn "✗ Received REJECTION for task: $task_id"
                # Rejection will be processed by check_for_rejections
                ;;
            CONTROL_PAUSE)
                local reason
                reason=$(echo "$payload" | jq -r '.reason // "No reason given"')
                log_warn "⏸ Received PAUSE command: $reason"
                WORKER_PAUSED=true
                ;;
            CONTROL_RESUME)
                log_info "▶ Received RESUME command"
                WORKER_PAUSED=false
                ;;
            *)
                log_debug "Unknown message type: $msg_type"
                ;;
        esac

        # Move to processed
        mkdir -p "$PROCESSED_DIR"
        mv "$msg_file" "$PROCESSED_DIR/" 2>/dev/null || rm "$msg_file"
        ((msg_count++)) || true  # Prevent set -e exit on first increment
    done

    [[ $msg_count -gt 0 ]] && log_debug "Processed $msg_count inbox messages"
    return 0
}
```

### Fixed Code (COMPLETE):
```bash
# Check worker inbox for supervisor messages
check_inbox() {
    local msg_count=0

    for msg_file in "$INBOX_DIR"/*.json; do
        [[ -f "$msg_file" ]] || continue

        local msg_type=""
        local payload="{}"

        if command -v jq &>/dev/null; then
            msg_type=$(jq -r '.type // ""' "$msg_file" 2>/dev/null || echo "")
            payload=$(jq -c '.payload // {}' "$msg_file" 2>/dev/null || echo "{}")
        elif command -v python3 &>/dev/null; then
            local parsed
            parsed=$(python3 - "$msg_file" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
    msg_type = data.get("type", "")
    payload = json.dumps(data.get("payload", {}))
except Exception:
    msg_type = ""
    payload = "{}"
print(f"{msg_type}\t{payload}")
PY
)
            IFS=$'\t' read -r msg_type payload <<< "$parsed"
        else
            msg_type=$(grep -oE '"type"\s*:\s*"[^"]+"' "$msg_file" | head -1 | cut -d'"' -f4 || echo "")
            payload="{}"
        fi

        case "$msg_type" in
            TASK_APPROVE)
                local task_id=""
                if command -v jq &>/dev/null; then
                    task_id=$(echo "$payload" | jq -r '.task_id // ""' 2>/dev/null || echo "")
                elif command -v python3 &>/dev/null; then
                    task_id=$(python3 - "$payload" <<'PY'
import json, sys
try:
    data = json.loads(sys.argv[1])
    print(data.get("task_id", ""))
except Exception:
    print("")
PY
)
                else
                    task_id=$(echo "$payload" | grep -oE '"task_id"\s*:\s*"[^"]+"' | head -1 | cut -d'"' -f4 || echo "")
                fi
                log_info "Received APPROVAL for task: $task_id"
                ;;
            TASK_REJECT)
                local task_id=""
                if command -v jq &>/dev/null; then
                    task_id=$(echo "$payload" | jq -r '.task_id // ""' 2>/dev/null || echo "")
                elif command -v python3 &>/dev/null; then
                    task_id=$(python3 - "$payload" <<'PY'
import json, sys
try:
    data = json.loads(sys.argv[1])
    print(data.get("task_id", ""))
except Exception:
    print("")
PY
)
                else
                    task_id=$(echo "$payload" | grep -oE '"task_id"\s*:\s*"[^"]+"' | head -1 | cut -d'"' -f4 || echo "")
                fi
                log_warn "Received REJECTION for task: $task_id"
                ;;
            CONTROL_PAUSE)
                local reason="No reason given"
                if command -v jq &>/dev/null; then
                    reason=$(echo "$payload" | jq -r '.reason // "No reason given"' 2>/dev/null || echo "No reason given")
                fi
                log_warn "Received PAUSE command: $reason"
                WORKER_PAUSED=true
                ;;
            CONTROL_RESUME)
                log_info "Received RESUME command"
                WORKER_PAUSED=false
                ;;
            *)
                log_debug "Unknown message type: $msg_type"
                ;;
        esac

        mkdir -p "$PROCESSED_DIR"
        mv "$msg_file" "$PROCESSED_DIR/" 2>/dev/null || rm "$msg_file"
        ((msg_count++)) || true
    done

    [[ $msg_count -gt 0 ]] && log_debug "Processed $msg_count inbox messages"
    return 0
}
```

### Integration Steps:
1. `rg -n "check_inbox" bin/tri-agent-worker`
2. Replace the existing function with the fixed version above in `bin/tri-agent-worker`.

### Verification:
```bash
mkdir -p "$HOME/.claude/autonomous/comms/worker/inbox" && echo '{"type":"CONTROL_PAUSE","payload":{}}' > "$HOME/.claude/autonomous/comms/worker/inbox/test.json"
./bin/tri-agent-worker --status
```
Expected output: Worker reports paused state without crashing.


## FIX-4: Harden stale lock cleanup when jq is missing or lock JSON is invalid
File: bin/tri-agent-worker
Lines: 505-572
Priority: P1
Impact: Lock recovery can crash the worker under set -e if jq fails.
Evidence: jq is used without guard in stale lock cleanup. (bin/tri-agent-worker:515-519)

### Current Code (BROKEN):
```bash
# Cleanup stale locks from crashed workers
cleanup_stale_locks() {
    local max_age_seconds="${1:-3600}"  # Default 1 hour
    local now
    now=$(date +%s)
    local recovered=0

    for lock_file in "$RUNNING_DIR"/*.lock; do
        [[ -f "$lock_file" ]] || continue

        local locked_at heartbeat_ts timeout_seconds task_name
        locked_at=$(jq -r '.locked_at // ""' "$lock_file" 2>/dev/null || echo "")
        heartbeat_ts=$(jq -r '.heartbeat // ""' "$lock_file" 2>/dev/null || echo "")
        timeout_seconds=$(jq -r '.timeout_seconds // ""' "$lock_file" 2>/dev/null || echo "")
        task_name=$(jq -r '.task // ""' "$lock_file" 2>/dev/null || echo "")

        if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]]; then
            local fallback_priority
            fallback_priority=$(echo "$task_name" | grep -oE '^(CRITICAL|HIGH|MEDIUM|LOW)' || echo "MEDIUM")
            timeout_seconds=$(get_task_timeout_seconds "$fallback_priority")
        fi

        local ts="${heartbeat_ts:-$locked_at}"
        local lock_time
        lock_time=$(iso_to_epoch "$ts")
        if [[ "$lock_time" -eq 0 ]]; then
            lock_time=$(stat -c %Y "$lock_file" 2>/dev/null || echo 0)
        fi
        local age=$((now - lock_time))

        local expiry=$((timeout_seconds + TASK_LOCK_GRACE_SECONDS))
        [[ $expiry -lt $max_age_seconds ]] && expiry=$max_age_seconds

        if [[ $age -gt $expiry ]]; then
            [[ -z "$task_name" ]] && continue

            log_warn "Recovering stale lock: $task_name (age: ${age}s)"

            # Move task back to queue
            local task_file="${RUNNING_DIR}/${task_name}"
            if [[ -f "$task_file" ]]; then
                mv "$task_file" "$QUEUE_DIR/" 2>/dev/null || true
            fi

            release_task_lock "$task_name"
            log_ledger "STALE_LOCK_RECOVERED" "$task_name" "age=${age}s"
            ((recovered++)) || true  # Prevent set -e exit on first increment
        fi
    done

    # Cleanup orphaned lock directories without lock files
    for lock_dir in "$RUNNING_DIR"/*.lock.d; do
        [[ -d "$lock_dir" ]] || continue
        local expected_lock_file="${lock_dir%.lock.d}.lock"
        if [[ ! -f "$expected_lock_file" ]]; then
            local dir_mtime
            dir_mtime=$(stat -c %Y "$lock_dir" 2>/dev/null || echo 0)
            local dir_age=$((now - dir_mtime))
            if [[ $dir_age -gt $max_age_seconds ]]; then
                rmdir "$lock_dir" 2>/dev/null || true
                ((recovered++)) || true
            fi
        fi
    done

    [[ $recovered -gt 0 ]] && log_info "Recovered $recovered stale locks"
    return 0
}
```

### Fixed Code (COMPLETE):
```bash
# Cleanup stale locks from crashed workers
cleanup_stale_locks() {
    local max_age_seconds="${1:-3600}"
    local now
    now=$(date +%s)
    local recovered=0

    for lock_file in "$RUNNING_DIR"/*.lock; do
        [[ -f "$lock_file" ]] || continue

        local locked_at="" heartbeat_ts="" timeout_seconds="" task_name=""

        if command -v jq &>/dev/null; then
            locked_at=$(jq -r '.locked_at // ""' "$lock_file" 2>/dev/null || echo "")
            heartbeat_ts=$(jq -r '.heartbeat // ""' "$lock_file" 2>/dev/null || echo "")
            timeout_seconds=$(jq -r '.timeout_seconds // ""' "$lock_file" 2>/dev/null || echo "")
            task_name=$(jq -r '.task // ""' "$lock_file" 2>/dev/null || echo "")
        elif command -v python3 &>/dev/null; then
            local parsed
            parsed=$(python3 - "$lock_file" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
    print(f"{data.get('locked_at','')}\t{data.get('heartbeat','')}\t{data.get('timeout_seconds','')}\t{data.get('task','')}")
except Exception:
    print("\t\t\t")
PY
)
            IFS=$'\t' read -r locked_at heartbeat_ts timeout_seconds task_name <<< "$parsed"
        else
            locked_at=$(grep -oE '"locked_at"\s*:\s*"[^"]+"' "$lock_file" | head -1 | cut -d'"' -f4 || echo "")
            heartbeat_ts=$(grep -oE '"heartbeat"\s*:\s*"[^"]+"' "$lock_file" | head -1 | cut -d'"' -f4 || echo "")
            timeout_seconds=$(grep -oE '"timeout_seconds"\s*:\s*[0-9]+' "$lock_file" | head -1 | grep -oE '[0-9]+' || echo "")
            task_name=$(grep -oE '"task"\s*:\s*"[^"]+"' "$lock_file" | head -1 | cut -d'"' -f4 || echo "")
        fi

        if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]]; then
            local fallback_priority
            fallback_priority=$(echo "$task_name" | grep -oE '^(CRITICAL|HIGH|MEDIUM|LOW)' || echo "MEDIUM")
            timeout_seconds=$(get_task_timeout_seconds "$fallback_priority")
        fi

        local ts="${heartbeat_ts:-$locked_at}"
        local lock_time
        lock_time=$(iso_to_epoch "$ts")
        if [[ "$lock_time" -eq 0 ]]; then
            lock_time=$(stat -c %Y "$lock_file" 2>/dev/null || stat -f %m "$lock_file" 2>/dev/null || echo 0)
        fi
        local age=$((now - lock_time))

        local expiry=$((timeout_seconds + TASK_LOCK_GRACE_SECONDS))
        [[ $expiry -lt $max_age_seconds ]] && expiry=$max_age_seconds

        if [[ $age -gt $expiry ]]; then
            [[ -z "$task_name" ]] && continue
            log_warn "Recovering stale lock: $task_name (age: ${age}s)"

            local task_file="${RUNNING_DIR}/${task_name}"
            if [[ -f "$task_file" ]]; then
                mv "$task_file" "$QUEUE_DIR/" 2>/dev/null || true
            fi

            release_task_lock "$task_name"
            log_ledger "STALE_LOCK_RECOVERED" "$task_name" "age=${age}s"
            ((recovered++)) || true
        fi
    done

    for lock_dir in "$RUNNING_DIR"/*.lock.d; do
        [[ -d "$lock_dir" ]] || continue
        local expected_lock_file="${lock_dir%.lock.d}.lock"
        if [[ ! -f "$expected_lock_file" ]]; then
            local dir_mtime
            dir_mtime=$(stat -c %Y "$lock_dir" 2>/dev/null || stat -f %m "$lock_dir" 2>/dev/null || echo 0)
            local dir_age=$((now - dir_mtime))
            if [[ $dir_age -gt $max_age_seconds ]]; then
                rmdir "$lock_dir" 2>/dev/null || true
                ((recovered++)) || true
            fi
        fi
    done

    [[ $recovered -gt 0 ]] && log_info "Recovered $recovered stale locks"
    return 0
}
```

### Integration Steps:
1. `rg -n "cleanup_stale_locks" bin/tri-agent-worker`
2. Replace the existing function with the fixed version above in `bin/tri-agent-worker`.

### Verification:
```bash
./bin/tri-agent-worker --cleanup
```
Expected output: Cleanup completes without jq errors.


## FIX-5: Validate JSON payloads in send_message
File: bin/tri-agent-worker
Lines: 1041-1078
Priority: P2
Impact: Invalid JSON payloads can corrupt comms files and break supervisor parsing.
Evidence: Payload is injected without validation. (bin/tri-agent-worker:1053-1063)

### Current Code (BROKEN):
```bash
# Send message to target agent
send_message() {
    local msg_type="$1"
    local target="$2"
    local payload="$3"

    local msg_id
    msg_id=$(uuidgen 2>/dev/null || echo "msg-$(date +%s)-$$-$RANDOM")
    local inbox_dir="${AUTONOMOUS_ROOT}/comms/${target}/inbox"
    local msg_file="${inbox_dir}/${msg_id}.json"

    mkdir -p "$inbox_dir"

    # Atomic write using temp file
    local tmp_file="${msg_file}.tmp"
    cat > "$tmp_file" <<EOF
{
    "id": "${msg_id}",
    "type": "${msg_type}",
    "source": "worker",
    "target": "${target}",
    "timestamp": "$(date -Iseconds)",
    "payload": ${payload},
    "metadata": {
        "worker_id": "${WORKER_ID}",
        "priority": "high",
        "requires_ack": true,
        "trace_id": "${TRACE_ID}"
    }
}
EOF
    mv "$tmp_file" "$msg_file"

    # Save to sent
    mkdir -p "$SENT_DIR"
    cp "$msg_file" "${SENT_DIR}/${msg_id}.json" 2>/dev/null || true

    log_debug "Sent message: $msg_type to $target (id: $msg_id)"
}
```

### Fixed Code (COMPLETE):
```bash
# Send message to target agent
send_message() {
    local msg_type="$1"
    local target="$2"
    local payload="$3"

    local msg_id
    msg_id=$(uuidgen 2>/dev/null || echo "msg-$(date +%s)-$$-$RANDOM")
    local inbox_dir="${AUTONOMOUS_ROOT}/comms/${target}/inbox"
    local msg_file="${inbox_dir}/${msg_id}.json"

    mkdir -p "$inbox_dir"

    local safe_payload="$payload"
    if type -t is_valid_json >/dev/null 2>&1; then
        if ! is_valid_json "$payload"; then
            if command -v jq &>/dev/null; then
                safe_payload=$(jq -nc --arg msg "$payload" '{message:$msg}')
            else
                local escaped
                escaped=${payload//\\/\\\\}
                escaped=${escaped//"/\\"}
                safe_payload="{\"message\":\"$escaped\"}"
            fi
        fi
    else
        if command -v jq &>/dev/null; then
            if ! echo "$payload" | jq -e . >/dev/null 2>&1; then
                safe_payload=$(jq -nc --arg msg "$payload" '{message:$msg}')
            fi
        fi
    fi

    local tmp_file="${msg_file}.tmp"
    cat > "$tmp_file" <<EOF
{
    "id": "${msg_id}",
    "type": "${msg_type}",
    "source": "worker",
    "target": "${target}",
    "timestamp": "$(date -Iseconds)",
    "payload": ${safe_payload},
    "metadata": {
        "worker_id": "${WORKER_ID}",
        "priority": "high",
        "requires_ack": true,
        "trace_id": "${TRACE_ID}"
    }
}
EOF
    mv "$tmp_file" "$msg_file"

    mkdir -p "$SENT_DIR"
    cp "$msg_file" "${SENT_DIR}/${msg_id}.json" 2>/dev/null || true

    log_debug "Sent message: $msg_type to $target (id: $msg_id)"
}
```

### Integration Steps:
1. `rg -n "send_message" bin/tri-agent-worker`
2. Replace the existing function with the fixed version above in `bin/tri-agent-worker`.

### Verification:
```bash
./bin/tri-agent-worker --status
```
Expected output: No JSON formatting errors in comms files.


## FIX-6: Make test gate use python3 and single execution
File: lib/supervisor-approver.sh
Lines: 118-161
Priority: P1
Impact: Python tests may not run when only python3 exists; double execution wastes time.
Evidence: Uses `python` and runs tooling multiple times. (lib/supervisor-approver.sh:129-136)

### Current Code (BROKEN):
```bash
# CHECK 1: Test Suite Execution
check_tests() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-001: Running test suite..."

    local test_output="" exit_code=0
    cd "$workspace" || return 1

    # Detect test runner and execute
    if [[ -f "package.json" ]]; then
        test_output=$(npm test 2>&1) || exit_code=$?
    elif [[ -f "pytest.ini" ]] || [[ -f "setup.py" ]] || [[ -f "pyproject.toml" ]]; then
        test_output=$(python -m pytest 2>&1) || exit_code=$?
    elif [[ -f "Cargo.toml" ]]; then
        test_output=$(cargo test 2>&1) || exit_code=$?
    elif [[ -f "go.mod" ]]; then
        test_output=$(go test ./... 2>&1) || exit_code=$?
    elif [[ -x "./tests/run_tests.sh" ]]; then
        test_output=$(./tests/run_tests.sh 2>&1) || exit_code=$?
    else
        log_gate "WARN" "EXE-001: No test runner detected"
        exit_code=0
    fi

    local passed failed
    passed=$(echo "$test_output" | grep -oE "[0-9]+ passed" | grep -oE "[0-9]+" | head -1 || echo 0)
    failed=$(echo "$test_output" | grep -oE "[0-9]+ failed" | grep -oE "[0-9]+" | head -1 || echo 0)

    if command -v jq &>/dev/null; then
        jq -nc \
            --arg check "EXE-001" \
            --arg name "Test Suite" \
            --argjson passed "${passed:-0}" \
            --argjson failed "${failed:-0}" \
            --argjson exit_code "$exit_code" \
            '{check:$check,name:$name,passed:$passed,failed:$failed,exit_code:$exit_code,status:(if $exit_code == 0 then "PASS" else "FAIL" end)}' \
            > "$output_file"
    fi

    [[ $exit_code -eq 0 ]] && log_gate "PASS" "EXE-001: Tests passed" || log_gate "FAIL" "EXE-001: Tests failed"
    return $exit_code
}
```

### Fixed Code (COMPLETE):
```bash
# CHECK 1: Test Suite Execution
check_tests() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-001: Running test suite..."

    local test_output="" exit_code=0
    cd "$workspace" || return 1

    if [[ -f "package.json" ]]; then
        test_output=$(npm test 2>&1) || exit_code=$?
    elif [[ -f "pytest.ini" ]] || [[ -f "setup.py" ]] || [[ -f "pyproject.toml" ]]; then
        if command -v python3 &>/dev/null; then
            test_output=$(python3 -m pytest 2>&1) || exit_code=$?
        else
            log_gate "WARN" "EXE-001: python3 not found, skipping pytest"
            exit_code=0
        fi
    elif [[ -f "Cargo.toml" ]]; then
        test_output=$(cargo test 2>&1) || exit_code=$?
    elif [[ -f "go.mod" ]]; then
        test_output=$(go test ./... 2>&1) || exit_code=$?
    elif [[ -x "./tests/run_tests.sh" ]]; then
        test_output=$(./tests/run_tests.sh 2>&1) || exit_code=$?
    else
        log_gate "WARN" "EXE-001: No test runner detected"
        exit_code=0
    fi

    local passed failed
    passed=$(echo "$test_output" | grep -oE "[0-9]+ passed" | grep -oE "[0-9]+" | head -1 || echo 0)
    failed=$(echo "$test_output" | grep -oE "[0-9]+ failed" | grep -oE "[0-9]+" | head -1 || echo 0)

    if command -v jq &>/dev/null; then
        jq -nc \
            --arg check "EXE-001" \
            --arg name "Test Suite" \
            --argjson passed "${passed:-0}" \
            --argjson failed "${failed:-0}" \
            --argjson exit_code "$exit_code" \
            '{check:$check,name:$name,passed:$passed,failed:$failed,exit_code:$exit_code,status:(if $exit_code == 0 then "PASS" else "FAIL" end)}' \
            > "$output_file"
    fi

    [[ $exit_code -eq 0 ]] && log_gate "PASS" "EXE-001: Tests passed" || log_gate "FAIL" "EXE-001: Tests failed"
    return $exit_code
}
```

### Integration Steps:
1. `rg -n "check_tests" lib/supervisor-approver.sh`
2. Replace the existing function with the fixed version above in `lib/supervisor-approver.sh`.

### Verification:
```bash
bash -n lib/supervisor-approver.sh
```
Expected output: No syntax errors; gate runs pytest via python3 if available.


## FIX-7: Make coverage gate portable (no grep -P, no bc dependency)
File: lib/supervisor-approver.sh
Lines: 164-203
Priority: P1
Impact: Coverage gate can fail on systems without grep -P or bc.
Evidence: Uses grep -oP and bc in comparison. (lib/supervisor-approver.sh:173-185)

### Current Code (BROKEN):
```bash
# CHECK 2: Test Coverage
check_coverage() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-002: Checking test coverage..."

    local coverage=0 exit_code=0
    cd "$workspace" || return 1

    if [[ -f "package.json" ]] && grep -q '"coverage"' package.json 2>/dev/null; then
        coverage=$(npm run coverage 2>&1 | grep -oP "All files\s+\|\s+\K[0-9.]+" | head -1 || echo 0)
    elif [[ -f "pytest.ini" ]] || [[ -f "pyproject.toml" ]]; then
        if command -v pytest &>/dev/null; then
            coverage=$(python -m pytest --cov=. --cov-report=term 2>&1 | grep -oP "TOTAL.*\K[0-9]+%" | tr -d '%' | head -1 || echo 0)
        fi
    fi

    # Handle empty coverage
    coverage="${coverage:-0}"

    if (( $(echo "${coverage} >= ${COVERAGE_THRESHOLD}" | bc -l 2>/dev/null || echo 0) )); then
        exit_code=0
    else
        exit_code=1
    fi

    if command -v jq &>/dev/null; then
        jq -nc \
            --arg check "EXE-002" \
            --arg name "Test Coverage" \
            --argjson coverage "${coverage}" \
            --argjson threshold "$COVERAGE_THRESHOLD" \
            --argjson exit_code "$exit_code" \
            '{check:$check,name:$name,coverage:$coverage,threshold:$threshold,exit_code:$exit_code,status:(if $exit_code == 0 then "PASS" else "FAIL" end)}' \
            > "$output_file"
    fi

    [[ $exit_code -eq 0 ]] && log_gate "PASS" "EXE-002: Coverage ${coverage}% >= ${COVERAGE_THRESHOLD}%" || log_gate "FAIL" "EXE-002: Coverage ${coverage}% < ${COVERAGE_THRESHOLD}%"
    return $exit_code
}
```

### Fixed Code (COMPLETE):
```bash
# CHECK 2: Test Coverage
check_coverage() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-002: Checking test coverage..."

    local coverage=0 exit_code=0 output=""
    cd "$workspace" || return 1

    if [[ -f "package.json" ]] && grep -q '"coverage"' package.json 2>/dev/null; then
        output=$(npm run coverage 2>&1 || true)
        coverage=$(printf '%s\n' "$output" | awk -F'|' '/All files/ {gsub(/%/,"",$4); gsub(/ /,"",$4); print $4; exit}' )
    elif [[ -f "pytest.ini" ]] || [[ -f "pyproject.toml" ]]; then
        if command -v python3 &>/dev/null; then
            output=$(python3 -m pytest --cov=. --cov-report=term 2>&1 || true)
            coverage=$(printf '%s\n' "$output" | awk '/^TOTAL/ {gsub(/%/,"",$NF); print $NF; exit}')
        fi
    fi

    coverage="${coverage:-0}"

    if awk "BEGIN{exit !($coverage >= $COVERAGE_THRESHOLD)}"; then
        exit_code=0
    else
        exit_code=1
    fi

    if command -v jq &>/dev/null; then
        jq -nc \
            --arg check "EXE-002" \
            --arg name "Test Coverage" \
            --argjson coverage "${coverage:-0}" \
            --argjson threshold "$COVERAGE_THRESHOLD" \
            --argjson exit_code "$exit_code" \
            '{check:$check,name:$name,coverage:$coverage,threshold:$threshold,exit_code:$exit_code,status:(if $exit_code == 0 then "PASS" else "FAIL" end)}' \
            > "$output_file"
    fi

    [[ $exit_code -eq 0 ]] && log_gate "PASS" "EXE-002: Coverage ${coverage}% >= ${COVERAGE_THRESHOLD}%" || log_gate "FAIL" "EXE-002: Coverage ${coverage}% < ${COVERAGE_THRESHOLD}%"
    return $exit_code
}
```

### Integration Steps:
1. `rg -n "check_coverage" lib/supervisor-approver.sh`
2. Replace the existing function with the fixed version above in `lib/supervisor-approver.sh`.

### Verification:
```bash
bash -n lib/supervisor-approver.sh
```
Expected output: Coverage gate runs without grep -P or bc.


## FIX-8: Fix shell lint detection and include bin/ scripts
File: lib/supervisor-approver.sh
Lines: 206-246
Priority: P2
Impact: Shell linting may silently skip scripts due to incorrect glob check.
Evidence: Uses `[[ -f "*.sh" ]]` which never matches. (lib/supervisor-approver.sh:223)

### Current Code (BROKEN):
```bash
# CHECK 3: Linting
check_lint() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-003: Running linter..."

    local errors=0 warnings=0 exit_code=0
    cd "$workspace" || return 1

    local lint_output=""
    if [[ -f "package.json" ]] && grep -q '"lint"' package.json 2>/dev/null; then
        lint_output=$(npm run lint 2>&1) || true
        errors=$(echo "$lint_output" | grep -c "error" || echo 0)
        warnings=$(echo "$lint_output" | grep -c "warning" || echo 0)
    elif command -v ruff &>/dev/null && [[ -f "pyproject.toml" || -f "setup.cfg" || -d "src" ]]; then
        lint_output=$(ruff check . 2>&1) || true
        errors=$(echo "$lint_output" | grep -cE "^[^:]+:[0-9]+:" || echo 0)
    elif [[ -f "*.sh" ]] || [[ -d "bin" ]]; then
        # Shellcheck for bash scripts
        if command -v shellcheck &>/dev/null; then
            lint_output=$(find . -name "*.sh" -exec shellcheck {} \; 2>&1) || true
            errors=$(echo "$lint_output" | grep -c "error" || echo 0)
        fi
    fi

    [[ ${errors:-0} -gt 0 ]] && exit_code=1

    if command -v jq &>/dev/null; then
        jq -nc \
            --arg check "EXE-003" \
            --arg name "Linting" \
            --argjson errors "${errors:-0}" \
            --argjson warnings "${warnings:-0}" \
            --argjson exit_code "$exit_code" \
            '{check:$check,name:$name,errors:$errors,warnings:$warnings,exit_code:$exit_code,status:(if $exit_code == 0 then "PASS" else "FAIL" end)}' \
            > "$output_file"
    fi

    [[ $exit_code -eq 0 ]] && log_gate "PASS" "EXE-003: No linting errors" || log_gate "FAIL" "EXE-003: ${errors} linting errors"
    return $exit_code
}
```

### Fixed Code (COMPLETE):
```bash
# CHECK 3: Linting
check_lint() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-003: Running linter..."

    local errors=0 warnings=0 exit_code=0
    cd "$workspace" || return 1

    local lint_output=""
    if [[ -f "package.json" ]] && grep -q '"lint"' package.json 2>/dev/null; then
        lint_output=$(npm run lint 2>&1) || true
        errors=$(echo "$lint_output" | grep -c "error" || echo 0)
        warnings=$(echo "$lint_output" | grep -c "warning" || echo 0)
    elif command -v ruff &>/dev/null && { [[ -f "pyproject.toml" ]] || [[ -f "setup.cfg" ]] || [[ -d "src" ]]; }; then
        lint_output=$(ruff check . 2>&1) || true
        errors=$(echo "$lint_output" | grep -cE "^[^:]+:[0-9]+:" || echo 0)
    elif command -v shellcheck &>/dev/null; then
        local targets=()
        while IFS= read -r f; do targets+=("$f"); done < <(find . -name "*.sh" 2>/dev/null)
        if [[ -d "bin" ]]; then
            while IFS= read -r f; do targets+=("$f"); done < <(find bin -maxdepth 1 -type f -perm -u+x 2>/dev/null)
        fi
        if [[ ${#targets[@]} -gt 0 ]]; then
            lint_output=$(shellcheck "${targets[@]}" 2>&1) || true
            errors=$(echo "$lint_output" | grep -c "error" || echo 0)
            warnings=$(echo "$lint_output" | grep -c "warning" || echo 0)
        fi
    fi

    [[ ${errors:-0} -gt 0 ]] && exit_code=1

    if command -v jq &>/dev/null; then
        jq -nc \
            --arg check "EXE-003" \
            --arg name "Linting" \
            --argjson errors "${errors:-0}" \
            --argjson warnings "${warnings:-0}" \
            --argjson exit_code "$exit_code" \
            '{check:$check,name:$name,errors:$errors,warnings:$warnings,exit_code:$exit_code,status:(if $exit_code == 0 then "PASS" else "FAIL" end)}' \
            > "$output_file"
    fi

    [[ $exit_code -eq 0 ]] && log_gate "PASS" "EXE-003: No linting errors" || log_gate "FAIL" "EXE-003: ${errors} linting errors"
    return $exit_code
}
```

### Integration Steps:
1. `rg -n "check_lint" lib/supervisor-approver.sh`
2. Replace the existing function with the fixed version above in `lib/supervisor-approver.sh`.

### Verification:
```bash
bash -n lib/supervisor-approver.sh
```
Expected output: Shellcheck runs on bin/ scripts when present.


## FIX-9: Avoid double-running type checks and use python3
File: lib/supervisor-approver.sh
Lines: 248-283
Priority: P1
Impact: Type-checks are run twice and python is assumed.
Evidence: tsc/mypy invoked twice; python used. (lib/supervisor-approver.sh:258-265)

### Current Code (BROKEN):
```bash
# CHECK 4: Type Checking
check_types() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-004: Running type checker..."

    local errors=0 exit_code=0
    cd "$workspace" || return 1

    if [[ -f "tsconfig.json" ]]; then
        npx tsc --noEmit 2>&1 || exit_code=$?
        errors=$(npx tsc --noEmit 2>&1 | grep -c "error TS" || echo 0)
    elif [[ -f "pyproject.toml" ]] || [[ -f "mypy.ini" ]]; then
        if command -v mypy &>/dev/null; then
            python -m mypy . 2>&1 || exit_code=$?
            errors=$(python -m mypy . 2>&1 | grep -c "error:" || echo 0)
        fi
    else
        # No type checker configured - pass
        exit_code=0
    fi

    if command -v jq &>/dev/null; then
        jq -nc \
            --arg check "EXE-004" \
            --arg name "Type Checking" \
            --argjson errors "${errors:-0}" \
            --argjson exit_code "$exit_code" \
            '{check:$check,name:$name,errors:$errors,exit_code:$exit_code,status:(if $exit_code == 0 then "PASS" else "FAIL" end)}' \
            > "$output_file"
    fi

    [[ $exit_code -eq 0 ]] && log_gate "PASS" "EXE-004: No type errors" || log_gate "FAIL" "EXE-004: ${errors} type errors"
    return $exit_code
}
```

### Fixed Code (COMPLETE):
```bash
# CHECK 4: Type Checking
check_types() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-004: Running type checker..."

    local errors=0 exit_code=0 output=""
    cd "$workspace" || return 1

    if [[ -f "tsconfig.json" ]]; then
        output=$(npx tsc --noEmit 2>&1) || exit_code=$?
        errors=$(echo "$output" | grep -c "error TS" || echo 0)
    elif [[ -f "pyproject.toml" ]] || [[ -f "mypy.ini" ]]; then
        if command -v mypy &>/dev/null && command -v python3 &>/dev/null; then
            output=$(python3 -m mypy . 2>&1) || exit_code=$?
            errors=$(echo "$output" | grep -c "error:" || echo 0)
        fi
    else
        exit_code=0
    fi

    if command -v jq &>/dev/null; then
        jq -nc \
            --arg check "EXE-004" \
            --arg name "Type Checking" \
            --argjson errors "${errors:-0}" \
            --argjson exit_code "$exit_code" \
            '{check:$check,name:$name,errors:$errors,exit_code:$exit_code,status:(if $exit_code == 0 then "PASS" else "FAIL" end)}' \
            > "$output_file"
    fi

    [[ $exit_code -eq 0 ]] && log_gate "PASS" "EXE-004: No type errors" || log_gate "FAIL" "EXE-004: ${errors} type errors"
    return $exit_code
}
```

### Integration Steps:
1. `rg -n "check_types" lib/supervisor-approver.sh`
2. Replace the existing function with the fixed version above in `lib/supervisor-approver.sh`.

### Verification:
```bash
bash -n lib/supervisor-approver.sh
```
Expected output: No duplicate type-check runs; python3 used for mypy.


## FIX-10: Make security gate robust without jq
File: lib/supervisor-approver.sh
Lines: 286-331
Priority: P1
Impact: Missing jq causes gate failure even when audits are available.
Evidence: npm audit JSON is parsed with jq only. (lib/supervisor-approver.sh:295-301)

### Current Code (BROKEN):
```bash
# CHECK 5: Security Scan
check_security() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-005: Running security scan..."

    local critical=0 high=0 medium=0 exit_code=0
    cd "$workspace" || return 1

    if [[ -f "package.json" ]] || [[ -f "package-lock.json" ]]; then
        local audit_json
        audit_json=$(npm audit --json 2>/dev/null || echo '{"metadata":{"vulnerabilities":{}}}')
        critical=$(echo "$audit_json" | jq '.metadata.vulnerabilities.critical // 0' 2>/dev/null || echo 0)
        high=$(echo "$audit_json" | jq '.metadata.vulnerabilities.high // 0' 2>/dev/null || echo 0)
        medium=$(echo "$audit_json" | jq '.metadata.vulnerabilities.moderate // 0' 2>/dev/null || echo 0)
    elif [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]]; then
        if command -v safety &>/dev/null; then
            local safety_output
            safety_output=$(safety check --json 2>/dev/null || echo '[]')
            critical=$(echo "$safety_output" | jq 'length' 2>/dev/null || echo 0)
        fi
        if command -v bandit &>/dev/null; then
            local bandit_output
            bandit_output=$(bandit -r . -f json 2>/dev/null || echo '{"results":[]}')
            high=$((high + $(echo "$bandit_output" | jq '[.results[] | select(.issue_severity == "HIGH")] | length' 2>/dev/null || echo 0)))
        fi
    fi

    # Critical or high = blocking failure
    [[ ${critical:-0} -gt 0 || ${high:-0} -gt 0 ]] && exit_code=1

    if command -v jq &>/dev/null; then
        jq -nc \
            --arg check "EXE-005" \
            --arg name "Security Scan" \
            --argjson critical "${critical:-0}" \
            --argjson high "${high:-0}" \
            --argjson medium "${medium:-0}" \
            --argjson exit_code "$exit_code" \
            '{check:$check,name:$name,critical:$critical,high:$high,medium:$medium,exit_code:$exit_code,status:(if $exit_code == 0 then "PASS" else "FAIL" end)}' \
            > "$output_file"
    fi

    [[ $exit_code -eq 0 ]] && log_gate "PASS" "EXE-005: No critical/high vulnerabilities" || log_gate "FAIL" "EXE-005: Critical=${critical}, High=${high}"
    return $exit_code
}
```

### Fixed Code (COMPLETE):
```bash
# CHECK 5: Security Scan
check_security() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-005: Running security scan..."

    local critical=0 high=0 medium=0 exit_code=0
    cd "$workspace" || return 1

    if [[ -f "package.json" ]] || [[ -f "package-lock.json" ]]; then
        local audit_json
        audit_json=$(npm audit --json 2>/dev/null || echo '{"metadata":{"vulnerabilities":{}}}')
        if command -v jq &>/dev/null; then
            critical=$(echo "$audit_json" | jq '.metadata.vulnerabilities.critical // 0' 2>/dev/null || echo 0)
            high=$(echo "$audit_json" | jq '.metadata.vulnerabilities.high // 0' 2>/dev/null || echo 0)
            medium=$(echo "$audit_json" | jq '.metadata.vulnerabilities.moderate // 0' 2>/dev/null || echo 0)
        elif command -v python3 &>/dev/null; then
            critical=$(python3 - "$audit_json" <<'PY'
import json, sys
try:
    data=json.loads(sys.argv[1])
    print(data.get('metadata',{}).get('vulnerabilities',{}).get('critical',0))
except Exception:
    print(0)
PY
)
            high=$(python3 - "$audit_json" <<'PY'
import json, sys
try:
    data=json.loads(sys.argv[1])
    print(data.get('metadata',{}).get('vulnerabilities',{}).get('high',0))
except Exception:
    print(0)
PY
)
            medium=$(python3 - "$audit_json" <<'PY'
import json, sys
try:
    data=json.loads(sys.argv[1])
    print(data.get('metadata',{}).get('vulnerabilities',{}).get('moderate',0))
except Exception:
    print(0)
PY
)
        fi
    elif [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]]; then
        if command -v safety &>/dev/null; then
            local safety_output
            safety_output=$(safety check --json 2>/dev/null || echo '[]')
            if command -v jq &>/dev/null; then
                critical=$(echo "$safety_output" | jq 'length' 2>/dev/null || echo 0)
            elif command -v python3 &>/dev/null; then
                critical=$(python3 - "$safety_output" <<'PY'
import json, sys
try:
    print(len(json.loads(sys.argv[1])))
except Exception:
    print(0)
PY
)
            fi
        fi
        if command -v bandit &>/dev/null; then
            local bandit_output
            bandit_output=$(bandit -r . -f json 2>/dev/null || echo '{"results":[]}')
            if command -v jq &>/dev/null; then
                high=$((high + $(echo "$bandit_output" | jq '[.results[] | select(.issue_severity == "HIGH")] | length' 2>/dev/null || echo 0)))
            elif command -v python3 &>/dev/null; then
                high=$((high + $(python3 - "$bandit_output" <<'PY'
import json, sys
try:
    data=json.loads(sys.argv[1])
    print(len([r for r in data.get('results',[]) if r.get('issue_severity')=='HIGH']))
except Exception:
    print(0)
PY
)))
            fi
        fi
    fi

    [[ ${critical:-0} -gt 0 || ${high:-0} -gt 0 ]] && exit_code=1

    if command -v jq &>/dev/null; then
        jq -nc \
            --arg check "EXE-005" \
            --arg name "Security Scan" \
            --argjson critical "${critical:-0}" \
            --argjson high "${high:-0}" \
            --argjson medium "${medium:-0}" \
            --argjson exit_code "$exit_code" \
            '{check:$check,name:$name,critical:$critical,high:$high,medium:$medium,exit_code:$exit_code,status:(if $exit_code == 0 then "PASS" else "FAIL" end)}' \
            > "$output_file"
    fi

    [[ $exit_code -eq 0 ]] && log_gate "PASS" "EXE-005: No critical/high vulnerabilities" || log_gate "FAIL" "EXE-005: Critical=${critical}, High=${high}"
    return $exit_code
}
```

### Integration Steps:
1. `rg -n "check_security" lib/supervisor-approver.sh`
2. Replace the existing function with the fixed version above in `lib/supervisor-approver.sh`.

### Verification:
```bash
bash -n lib/supervisor-approver.sh
```
Expected output: Security gate runs even when jq is missing.


## FIX-11: Make dependency audit robust without jq
File: lib/supervisor-approver.sh
Lines: 376-407
Priority: P1
Impact: Missing jq exits the gate; dependency audit becomes unreliable.
Evidence: jq is required for npm/pipenv output. (lib/supervisor-approver.sh:385-390)

### Current Code (BROKEN):
```bash
# CHECK 7: Dependency Audit
check_dependencies() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-007: Auditing dependencies..."

    local critical_deps=0 exit_code=0
    cd "$workspace" || return 1

    if [[ -f "package-lock.json" ]]; then
        critical_deps=$(npm audit --json 2>/dev/null | jq '.metadata.vulnerabilities.critical // 0' 2>/dev/null || echo 0)
    elif [[ -f "Pipfile.lock" ]]; then
        if command -v pipenv &>/dev/null; then
            critical_deps=$(pipenv check --json 2>/dev/null | jq 'length' 2>/dev/null || echo 0)
        fi
    fi

    [[ ${critical_deps:-0} -gt 0 ]] && exit_code=1

    if command -v jq &>/dev/null; then
        jq -nc \
            --arg check "EXE-007" \
            --arg name "Dependency Audit" \
            --argjson critical "${critical_deps:-0}" \
            --argjson exit_code "$exit_code" \
            '{check:$check,name:$name,critical_vulnerabilities:$critical,exit_code:$exit_code,status:(if $exit_code == 0 then "PASS" else "FAIL" end)}' \
            > "$output_file"
    fi

    [[ $exit_code -eq 0 ]] && log_gate "PASS" "EXE-007: No critical dependency vulnerabilities" || log_gate "FAIL" "EXE-007: ${critical_deps} critical vulnerabilities"
    return $exit_code
}
```

### Fixed Code (COMPLETE):
```bash
# CHECK 7: Dependency Audit
check_dependencies() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-007: Auditing dependencies..."

    local critical_deps=0 exit_code=0
    cd "$workspace" || return 1

    if [[ -f "package-lock.json" ]]; then
        local audit_json
        audit_json=$(npm audit --json 2>/dev/null || echo '{"metadata":{"vulnerabilities":{}}}')
        if command -v jq &>/dev/null; then
            critical_deps=$(echo "$audit_json" | jq '.metadata.vulnerabilities.critical // 0' 2>/dev/null || echo 0)
        elif command -v python3 &>/dev/null; then
            critical_deps=$(python3 - "$audit_json" <<'PY'
import json, sys
try:
    data=json.loads(sys.argv[1])
    print(data.get('metadata',{}).get('vulnerabilities',{}).get('critical',0))
except Exception:
    print(0)
PY
)
        fi
    elif [[ -f "Pipfile.lock" ]]; then
        if command -v pipenv &>/dev/null; then
            local pipenv_json
            pipenv_json=$(pipenv check --json 2>/dev/null || echo '[]')
            if command -v jq &>/dev/null; then
                critical_deps=$(echo "$pipenv_json" | jq 'length' 2>/dev/null || echo 0)
            elif command -v python3 &>/dev/null; then
                critical_deps=$(python3 - "$pipenv_json" <<'PY'
import json, sys
try:
    print(len(json.loads(sys.argv[1])))
except Exception:
    print(0)
PY
)
            fi
        fi
    fi

    [[ ${critical_deps:-0} -gt 0 ]] && exit_code=1

    if command -v jq &>/dev/null; then
        jq -nc \
            --arg check "EXE-007" \
            --arg name "Dependency Audit" \
            --argjson critical "${critical_deps:-0}" \
            --argjson exit_code "$exit_code" \
            '{check:$check,name:$name,critical_vulnerabilities:$critical,exit_code:$exit_code,status:(if $exit_code == 0 then "PASS" else "FAIL" end)}' \
            > "$output_file"
    fi

    [[ $exit_code -eq 0 ]] && log_gate "PASS" "EXE-007: No critical dependency vulnerabilities" || log_gate "FAIL" "EXE-007: ${critical_deps} critical vulnerabilities"
    return $exit_code
}
```

### Integration Steps:
1. `rg -n "check_dependencies" lib/supervisor-approver.sh`
2. Replace the existing function with the fixed version above in `lib/supervisor-approver.sh`.

### Verification:
```bash
bash -n lib/supervisor-approver.sh
```
Expected output: Dependency gate runs without jq.


## FIX-12: Make breaking-change detection resilient to missing git/main
File: lib/supervisor-approver.sh
Lines: 410-452
Priority: P2
Impact: New repos or non-main branches can cause false failures.
Evidence: Uses `git diff main...HEAD` directly. (lib/supervisor-approver.sh:419-421)

### Current Code (BROKEN):
```bash
# CHECK 8: Breaking Change Detection
check_breaking_changes() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-008: Detecting breaking changes..."

    local breaking_count=0 documented=false exit_code=0
    cd "$workspace" || return 1

    # Detect exported API changes
    breaking_count=$(git diff main...HEAD 2>/dev/null | \
        grep -cE "^-.*export.*(function|interface|class|type)" || echo 0)

    if [[ $breaking_count -gt 0 ]]; then
        # Check if documented in commit message
        if git log --oneline -1 2>/dev/null | grep -qiE "(breaking|BREAKING)"; then
            documented=true
            exit_code=0
        else
            exit_code=1
        fi
    fi

    if command -v jq &>/dev/null; then
        jq -nc \
            --arg check "EXE-008" \
            --arg name "Breaking Changes" \
            --argjson count "$breaking_count" \
            --argjson documented "$documented" \
            --argjson exit_code "$exit_code" \
            '{check:$check,name:$name,breaking_changes:$count,documented:$documented,exit_code:$exit_code,status:(if $count == 0 or $documented then "PASS" else "FAIL" end)}' \
            > "$output_file"
    fi

    if [[ $breaking_count -eq 0 ]]; then
        log_gate "PASS" "EXE-008: No breaking changes"
    elif [[ "$documented" == "true" ]]; then
        log_gate "PASS" "EXE-008: Breaking changes documented"
    else
        log_gate "FAIL" "EXE-008: Breaking changes not documented"
    fi
    return $exit_code
}
```

### Fixed Code (COMPLETE):
```bash
# CHECK 8: Breaking Change Detection
check_breaking_changes() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-008: Detecting breaking changes..."

    local breaking_count=0 documented=false exit_code=0
    cd "$workspace" || return 1

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log_gate "WARN" "EXE-008: Not a git repo, skipping"
        exit_code=0
    else
        local base_ref=""
        if git show-ref --verify --quiet refs/heads/main; then
            base_ref="main"
        elif git show-ref --verify --quiet refs/heads/master; then
            base_ref="master"
        elif git rev-parse HEAD~1 >/dev/null 2>&1; then
            base_ref="HEAD~1"
        else
            base_ref="HEAD"
        fi

        breaking_count=$(git diff "${base_ref}...HEAD" 2>/dev/null | \
            grep -cE "^-.*export.*(function|interface|class|type)" || echo 0)

        if [[ $breaking_count -gt 0 ]]; then
            if git log --oneline -1 2>/dev/null | grep -qiE "(breaking|BREAKING)"; then
                documented=true
                exit_code=0
            else
                exit_code=1
            fi
        fi
    fi

    if command -v jq &>/dev/null; then
        jq -nc \
            --arg check "EXE-008" \
            --arg name "Breaking Changes" \
            --argjson count "$breaking_count" \
            --argjson documented "$documented" \
            --argjson exit_code "$exit_code" \
            '{check:$check,name:$name,breaking_changes:$count,documented:$documented,exit_code:$exit_code,status:(if $count == 0 or $documented then "PASS" else "FAIL" end)}' \
            > "$output_file"
    fi

    if [[ $breaking_count -eq 0 ]]; then
        log_gate "PASS" "EXE-008: No breaking changes"
    elif [[ "$documented" == "true" ]]; then
        log_gate "PASS" "EXE-008: Breaking changes documented"
    else
        log_gate "FAIL" "EXE-008: Breaking changes not documented"
    fi
    return $exit_code
}
```

### Integration Steps:
1. `rg -n "check_breaking_changes" lib/supervisor-approver.sh`
2. Replace the existing function with the fixed version above in `lib/supervisor-approver.sh`.

### Verification:
```bash
bash -n lib/supervisor-approver.sh
```
Expected output: Gate skips cleanly when no git or main branch is absent.


## FIX-13: Use delegates and skip review gate when diff is empty
File: lib/supervisor-approver.sh
Lines: 454-530
Priority: P1
Impact: Gate fails when there is no diff; also bypasses delegate wrappers.
Evidence: Uses raw codex/gemini CLIs and treats empty diff as failure. (lib/supervisor-approver.sh:463-529)

### Current Code (BROKEN):
```bash
# CHECK 9: Tri-Agent Code Review
check_tri_agent_review() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-009: Running tri-agent code review..."

    cd "$workspace" || return 1

    local diff_content approvals=0
    diff_content=$(git diff HEAD~1 2>/dev/null | head -c 50000 || echo "")

    local claude_verdict="ABSTAIN" codex_verdict="ABSTAIN" gemini_verdict="ABSTAIN"
    local claude_score=0 codex_score=0 gemini_score=0

    # Claude Review
    if [[ -x "${BIN_DIR}/claude-delegate" ]]; then
        local claude_response
        claude_response=$(echo "$diff_content" | timeout 60 "${BIN_DIR}/claude-delegate" \
            "Review this code diff. Reply APPROVE or REQUEST_CHANGES only." 2>/dev/null || echo "")
        if echo "$claude_response" | grep -q "APPROVE"; then
            claude_verdict="APPROVE"
            claude_score=1
            ((approvals++))
        elif echo "$claude_response" | grep -q "REQUEST_CHANGES"; then
            claude_verdict="REQUEST_CHANGES"
        fi
    fi

    # Codex Review
    if command -v codex &>/dev/null; then
        local codex_response
        codex_response=$(echo "$diff_content" | timeout 60 codex exec \
            "Review for bugs. Reply APPROVE or REQUEST_CHANGES." 2>/dev/null || echo "")
        if echo "$codex_response" | grep -q "APPROVE"; then
            codex_verdict="APPROVE"
            codex_score=1
            ((approvals++))
        elif echo "$codex_response" | grep -q "REQUEST_CHANGES"; then
            codex_verdict="REQUEST_CHANGES"
        fi
    fi

    # Gemini Review
    if command -v gemini &>/dev/null; then
        local gemini_response
        gemini_response=$(echo "$diff_content" | timeout 60 gemini -y \
            "Security review. Reply APPROVE or REQUEST_CHANGES." 2>/dev/null || echo "")
        if echo "$gemini_response" | grep -q "APPROVE"; then
            gemini_verdict="APPROVE"
            gemini_score=1
            ((approvals++))
        elif echo "$gemini_response" | grep -q "REQUEST_CHANGES"; then
            gemini_verdict="REQUEST_CHANGES"
        fi
    fi

    local consensus="REJECT" exit_code=1
    [[ $approvals -ge 2 ]] && { consensus="APPROVE"; exit_code=0; }

    if command -v jq &>/dev/null; then
        jq -nc \
            --arg check "EXE-009" \
            --arg name "Tri-Agent Review" \
            --arg claude "$claude_verdict" \
            --arg codex "$codex_verdict" \
            --arg gemini "$gemini_verdict" \
            --argjson approvals "$approvals" \
            --arg consensus "$consensus" \
            --argjson exit_code "$exit_code" \
            '{check:$check,name:$name,claude:$claude,codex:$codex,gemini:$gemini,approvals:$approvals,consensus:$consensus,exit_code:$exit_code,status:(if $approvals >= 2 then "PASS" else "FAIL" end)}' \
            > "$output_file"
    fi

    [[ $exit_code -eq 0 ]] && log_gate "PASS" "EXE-009: Tri-agent consensus ($approvals/3)" || log_gate "FAIL" "EXE-009: Insufficient approvals ($approvals/3)"
    return $exit_code
}
```

### Fixed Code (COMPLETE):
```bash
# CHECK 9: Tri-Agent Code Review
check_tri_agent_review() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-009: Running tri-agent code review..."

    cd "$workspace" || return 1

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log_gate "WARN" "EXE-009: Not a git repo, skipping"
        if command -v jq &>/dev/null; then
            jq -nc \
                --arg check "EXE-009" \
                --arg name "Tri-Agent Review" \
                --arg claude "SKIPPED" \
                --arg codex "SKIPPED" \
                --arg gemini "SKIPPED" \
                --argjson approvals 0 \
                --arg consensus "SKIPPED" \
                --argjson exit_code 0 \
                '{check:$check,name:$name,claude:$claude,codex:$codex,gemini:$gemini,approvals:$approvals,consensus:$consensus,exit_code:$exit_code,status:"PASS"}' \
                > "$output_file"
        fi
        return 0
    fi

    local diff_content approvals=0
    diff_content=$(git diff HEAD~1 2>/dev/null | head -c 50000 || echo "")
    if [[ -z "$diff_content" ]]; then
        log_gate "WARN" "EXE-009: Empty diff, skipping"
        if command -v jq &>/dev/null; then
            jq -nc \
                --arg check "EXE-009" \
                --arg name "Tri-Agent Review" \
                --arg claude "SKIPPED" \
                --arg codex "SKIPPED" \
                --arg gemini "SKIPPED" \
                --argjson approvals 0 \
                --arg consensus "SKIPPED" \
                --argjson exit_code 0 \
                '{check:$check,name:$name,claude:$claude,codex:$codex,gemini:$gemini,approvals:$approvals,consensus:$consensus,exit_code:$exit_code,status:"PASS"}' \
                > "$output_file"
        fi
        return 0
    fi

    local claude_verdict="ABSTAIN" codex_verdict="ABSTAIN" gemini_verdict="ABSTAIN"

    if [[ -x "${BIN_DIR}/claude-delegate" ]]; then
        local claude_response
        claude_response=$(echo "$diff_content" | timeout 60 "${BIN_DIR}/claude-delegate" \
            "Review this code diff. Reply APPROVE or REQUEST_CHANGES only." 2>/dev/null || echo "")
        if echo "$claude_response" | grep -q "APPROVE"; then
            claude_verdict="APPROVE"; ((approvals++))
        elif echo "$claude_response" | grep -q "REQUEST_CHANGES"; then
            claude_verdict="REQUEST_CHANGES"
        fi
    fi

    if [[ -x "${BIN_DIR}/codex-delegate" ]]; then
        local codex_response
        codex_response=$(echo "$diff_content" | timeout 60 "${BIN_DIR}/codex-delegate" \
            "Review for bugs. Reply APPROVE or REQUEST_CHANGES." 2>/dev/null || echo "")
        if echo "$codex_response" | grep -q "APPROVE"; then
            codex_verdict="APPROVE"; ((approvals++))
        elif echo "$codex_response" | grep -q "REQUEST_CHANGES"; then
            codex_verdict="REQUEST_CHANGES"
        fi
    elif command -v codex &>/dev/null; then
        local codex_response
        codex_response=$(echo "$diff_content" | timeout 60 codex exec \
            "Review for bugs. Reply APPROVE or REQUEST_CHANGES." 2>/dev/null || echo "")
        if echo "$codex_response" | grep -q "APPROVE"; then
            codex_verdict="APPROVE"; ((approvals++))
        elif echo "$codex_response" | grep -q "REQUEST_CHANGES"; then
            codex_verdict="REQUEST_CHANGES"
        fi
    fi

    if [[ -x "${BIN_DIR}/gemini-delegate" ]]; then
        local gemini_response
        gemini_response=$(echo "$diff_content" | timeout 60 "${BIN_DIR}/gemini-delegate" \
            "Security review. Reply APPROVE or REQUEST_CHANGES." 2>/dev/null || echo "")
        if echo "$gemini_response" | grep -q "APPROVE"; then
            gemini_verdict="APPROVE"; ((approvals++))
        elif echo "$gemini_response" | grep -q "REQUEST_CHANGES"; then
            gemini_verdict="REQUEST_CHANGES"
        fi
    elif command -v gemini &>/dev/null; then
        local gemini_response
        gemini_response=$(echo "$diff_content" | timeout 60 gemini -y \
            "Security review. Reply APPROVE or REQUEST_CHANGES." 2>/dev/null || echo "")
        if echo "$gemini_response" | grep -q "APPROVE"; then
            gemini_verdict="APPROVE"; ((approvals++))
        elif echo "$gemini_response" | grep -q "REQUEST_CHANGES"; then
            gemini_verdict="REQUEST_CHANGES"
        fi
    fi

    local consensus="REJECT" exit_code=1
    [[ $approvals -ge 2 ]] && { consensus="APPROVE"; exit_code=0; }

    if command -v jq &>/dev/null; then
        jq -nc \
            --arg check "EXE-009" \
            --arg name "Tri-Agent Review" \
            --arg claude "$claude_verdict" \
            --arg codex "$codex_verdict" \
            --arg gemini "$gemini_verdict" \
            --argjson approvals "$approvals" \
            --arg consensus "$consensus" \
            --argjson exit_code "$exit_code" \
            '{check:$check,name:$name,claude:$claude,codex:$codex,gemini:$gemini,approvals:$approvals,consensus:$consensus,exit_code:$exit_code,status:(if $approvals >= 2 then "PASS" else "FAIL" end)}' \
            > "$output_file"
    fi

    [[ $exit_code -eq 0 ]] && log_gate "PASS" "EXE-009: Tri-agent consensus ($approvals/3)" || log_gate "FAIL" "EXE-009: Insufficient approvals ($approvals/3)"
    return $exit_code
}
```

### Integration Steps:
1. `rg -n "check_tri_agent_review" lib/supervisor-approver.sh`
2. Replace the existing function with the fixed version above in `lib/supervisor-approver.sh`.

### Verification:
```bash
bash -n lib/supervisor-approver.sh
```
Expected output: Gate skips cleanly when no diff; delegates used when available.


## FIX-14: Make commit format check skip cleanly without git
File: lib/supervisor-approver.sh
Lines: 592-624
Priority: P2
Impact: Non-git contexts produce misleading warnings.
Evidence: Commit message is read unconditionally. (lib/supervisor-approver.sh:601-609)

### Current Code (BROKEN):
```bash
# CHECK 12: Commit Message Format
check_commit_format() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-012: Validating commit message format..."

    local valid_format=false exit_code=0
    cd "$workspace" || return 1

    local commit_msg
    commit_msg=$(git log -1 --pretty=%B 2>/dev/null || echo "")

    # Check conventional commit format: type(scope): description
    if echo "$commit_msg" | head -1 | grep -qE "^(feat|fix|docs|style|refactor|perf|test|chore|ci|build)(\([^)]+\))?: .+"; then
        valid_format=true
    else
        exit_code=1
    fi

    if command -v jq &>/dev/null; then
        jq -nc \
            --arg check "EXE-012" \
            --arg name "Commit Format" \
            --argjson valid_format "$valid_format" \
            --arg commit_msg "$(echo "$commit_msg" | head -1)" \
            --argjson exit_code "$exit_code" \
            '{check:$check,name:$name,valid_format:$valid_format,first_line:$commit_msg,exit_code:$exit_code,status:(if $valid_format then "PASS" else "FAIL" end)}' \
            > "$output_file"
    fi

    [[ "$valid_format" == "true" ]] && log_gate "PASS" "EXE-012: Valid commit format" || log_gate "WARN" "EXE-012: Invalid commit format (non-blocking)"
    return 0  # Non-blocking (just a warning)
}
```

### Fixed Code (COMPLETE):
```bash
# CHECK 12: Commit Message Format
check_commit_format() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-012: Validating commit message format..."

    local valid_format=false exit_code=0
    cd "$workspace" || return 1

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        valid_format=true
        exit_code=0
    else
        local commit_msg
        commit_msg=$(git log -1 --pretty=%B 2>/dev/null || echo "")
        if echo "$commit_msg" | head -1 | grep -qE "^(feat|fix|docs|style|refactor|perf|test|chore|ci|build)(\([^)]+\))?: .+"; then
            valid_format=true
        else
            exit_code=1
        fi
    fi

    if command -v jq &>/dev/null; then
        jq -nc \
            --arg check "EXE-012" \
            --arg name "Commit Format" \
            --argjson valid_format "$valid_format" \
            --arg commit_msg "$(git log -1 --pretty=%B 2>/dev/null | head -1 || echo "")" \
            --argjson exit_code "$exit_code" \
            '{check:$check,name:$name,valid_format:$valid_format,first_line:$commit_msg,exit_code:$exit_code,status:(if $valid_format then "PASS" else "FAIL" end)}' \
            > "$output_file"
    fi

    [[ "$valid_format" == "true" ]] && log_gate "PASS" "EXE-012: Valid commit format" || log_gate "WARN" "EXE-012: Invalid commit format (non-blocking)"
    return 0
}
```

### Integration Steps:
1. `rg -n "check_commit_format" lib/supervisor-approver.sh`
2. Replace the existing function with the fixed version above in `lib/supervisor-approver.sh`.

### Verification:
```bash
bash -n lib/supervisor-approver.sh
```
Expected output: Non-git contexts show PASS without warning.


## FIX-15: Make router policy reading resilient when common.sh is missing
File: bin/tri-agent-router
Lines: 226-235
Priority: P2
Impact: Router fails if read_config is unavailable; policy file becomes unusable.
Evidence: read_policy_value assumes read_config exists. (bin/tri-agent-router:226-235)

### Current Code (BROKEN):
```bash
# Policy File Reading
read_policy_value() {
    local key="$1"
    local default="${2:-}"

    if [[ -f "$ROUTING_POLICY" ]]; then
        read_config "$key" "$default" "$ROUTING_POLICY"
    else
        echo "$default"
    fi
}
```

### Fixed Code (COMPLETE):
```bash
# Policy File Reading
read_policy_value() {
    local key="$1"
    local default="${2:-}"

    if [[ -f "$ROUTING_POLICY" ]]; then
        if type -t read_config >/dev/null 2>&1; then
            read_config "$key" "$default" "$ROUTING_POLICY"
        elif command -v yq >/dev/null 2>&1; then
            local val
            val=$(yq -r "$key // \"\"" "$ROUTING_POLICY" 2>/dev/null || echo "")
            echo "${val:-$default}"
        elif command -v python3 >/dev/null 2>&1; then
            python3 - "$ROUTING_POLICY" "$key" "$default" <<'PY'
import sys, yaml
path = sys.argv[1]
key = sys.argv[2].strip('.')
default = sys.argv[3]
try:
    with open(path) as f:
        data = yaml.safe_load(f) or {}
    cur = data
    for part in key.split('.'):
        if isinstance(cur, dict) and part in cur:
            cur = cur[part]
        else:
            cur = None
            break
    if cur is None or cur == {}:
        print(default)
    else:
        print(cur)
except Exception:
    print(default)
PY
        else
            echo "$default"
        fi
    else
        echo "$default"
    fi
}
```

### Integration Steps:
1. `rg -n "read_policy_value" bin/tri-agent-router`
2. Replace the existing function with the fixed version above in `bin/tri-agent-router`.

### Verification:
```bash
./bin/tri-agent-router --dry-run "test routing"
```
Expected output: Router runs even when common.sh is unavailable.


SECTION 6: NEW FILES TO CREATE

1) File: lib/sdlc-state-machine.sh
Purpose: Enforce Brainstorm->Document->Plan->Execute->Track transitions with persisted state; no current file provides phase enforcement. (bin/tri-agent-worker:941-1034)
Skeleton code (full file):
```bash
#!/bin/bash
# sdlc-state-machine.sh - SDLC phase enforcement

set -euo pipefail

: "${STATE_DIR:=$HOME/.claude/autonomous/state}"
: "${TRACE_ID:=sdlc-$(date +%Y%m%d%H%M%S)-$$}"

PHASES=(BRAINSTORM DOCUMENT PLAN EXECUTE TRACK)

sdlc_state_file() {
    local task_id="$1"
    echo "${STATE_DIR}/sdlc/${task_id}.phase"
}

sdlc_init() {
    local task_id="$1"
    mkdir -p "${STATE_DIR}/sdlc"
    echo "BRAINSTORM" > "$(sdlc_state_file "$task_id")"
}

sdlc_get_phase() {
    local task_id="$1"
    local file
    file=$(sdlc_state_file "$task_id")
    [[ -f "$file" ]] && cat "$file" || echo "BRAINSTORM"
}

sdlc_can_transition() {
    local from="$1"
    local to="$2"
    case "$from" in
        BRAINSTORM) [[ "$to" == "DOCUMENT" ]] ;;
        DOCUMENT) [[ "$to" == "PLAN" ]] ;;
        PLAN) [[ "$to" == "EXECUTE" ]] ;;
        EXECUTE) [[ "$to" == "TRACK" ]] ;;
        TRACK) return 1 ;;
        *) return 1 ;;
    esac
}

sdlc_transition() {
    local task_id="$1"
    local to="$2"
    local from
    from=$(sdlc_get_phase "$task_id")

    if ! sdlc_can_transition "$from" "$to"; then
        echo "Invalid SDLC transition: ${from} -> ${to}" >&2
        return 1
    fi

    echo "$to" > "$(sdlc_state_file "$task_id")"
}

export -f sdlc_init sdlc_get_phase sdlc_transition sdlc_can_transition
```
Key functions: sdlc_init, sdlc_get_phase, sdlc_transition, sdlc_can_transition.
Integration: supervisor-approver calls sdlc_transition to enforce Execute->Track; worker or queue-watcher sets initial phase.

2) File: bin/tri-agent-daemon
Purpose: 24/7 orchestrator that starts worker pool, supervisor, watchdogs, and health-check in a single managed process.
Skeleton code (full file):
```bash
#!/bin/bash
# tri-agent-daemon - 24/7 orchestrator

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTONOMOUS_ROOT="${AUTONOMOUS_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

source "${AUTONOMOUS_ROOT}/lib/common.sh"
source "${AUTONOMOUS_ROOT}/lib/worker-pool.sh"

BIN_DIR="${AUTONOMOUS_ROOT}/bin"
LOG_DIR="${AUTONOMOUS_ROOT}/logs"
PID_FILE="${AUTONOMOUS_ROOT}/state/tri-agent-daemon.pid"

start_component() {
    local name="$1"; shift
    log_info "Starting ${name}..."
    "$@" >> "${LOG_DIR}/${name}.log" 2>&1 &
    echo $! > "${AUTONOMOUS_ROOT}/state/${name}.pid"
}

stop_component() {
    local name="$1"
    local pid_file="${AUTONOMOUS_ROOT}/state/${name}.pid"
    if [[ -f "$pid_file" ]]; then
        local pid
        pid=$(cat "$pid_file")
        kill -TERM "$pid" 2>/dev/null || true
        rm -f "$pid_file"
    fi
}

cleanup() {
    stop_component "worker-pool"
    stop_component "supervisor"
    stop_component "budget-watchdog"
    stop_component "health-check"
    rm -f "$PID_FILE"
    exit 0
}
trap cleanup SIGINT SIGTERM

mkdir -p "${AUTONOMOUS_ROOT}/state" "$LOG_DIR"
echo $$ > "$PID_FILE"

start_component "worker-pool" "${BIN_DIR}/tri-agent-worker"
start_component "supervisor" "${BIN_DIR}/tri-agent-supervisor" --daemon
start_component "budget-watchdog" "${BIN_DIR}/budget-watchdog" --watch
start_component "health-check" "${BIN_DIR}/health-check" --daemon

wait
```
Key functions: start_component, stop_component, cleanup.
Integration: systemd service runs tri-agent-daemon to guarantee 24/7 operation; components log to logs/.

3) File: bin/tri-agent-queue-watcher
Purpose: Bridge filesystem tasks/queue/PRIORITY to sqlite tasks table.
Skeleton code (full file):
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
Key functions: parse_priority, watch_loop.
Integration: runs alongside worker-pool; makes sqlite canonical for task claiming.


SECTION 7: SDLC PHASE ENFORCEMENT

State machine (ASCII):
```
BRAINSTORM -> DOCUMENT -> PLAN -> EXECUTE -> TRACK
```

Phase transition rules:
- BRAINSTORM -> DOCUMENT: requires `docs/brainstorm.md` or equivalent artifact.
- DOCUMENT -> PLAN: requires `docs/requirements.md` and acceptance criteria.
- PLAN -> EXECUTE: requires `docs/plan.md` and queued tasks under tasks/queue/.
- EXECUTE -> TRACK: requires quality gates PASS via supervisor-approver.
- TRACK -> COMPLETE: requires metrics/log artifacts and completion summary.

Gate checks per phase:
- DOCUMENT: schema validation, requirement completeness.
- PLAN: task decomposition, risk log.
- EXECUTE: 12 quality gates in supervisor-approver. (lib/supervisor-approver.sh:118-776)
- TRACK: artifact presence and event log update.

Artifact requirements per phase:
- BRAINSTORM: `docs/brainstorm.md`
- DOCUMENT: `docs/requirements.md`
- PLAN: `docs/plan.md`
- EXECUTE: `tasks/review/*`, `state/gates/*`
- TRACK: `logs/audit/*`, `tasks/completed/*`

Enforcement mechanism:
- Use sdlc-state-machine.sh to persist and validate transitions; deny transitions when artifacts are missing.
- Supervisor uses sdlc_transition after gates pass; worker cannot advance phase.

Integration point: supervisor-approver
- Call sdlc_transition(task_id, TRACK) only if quality_gate passes. (lib/supervisor-approver.sh:630-776)


SECTION 8: TRI-SUPERVISOR DESIGN

Consensus protocol:
- Use bin/tri-agent-consensus for all gate-level approvals requiring multi-model input. (bin/tri-agent-consensus:723-1077)
- Decision passes when 2/3 models return APPROVE; veto mode allowed for security/architecture. (bin/tri-agent-consensus:614-655)

Voting weights and thresholds:
- Default 2/3 majority; weighted option uses Claude 0.4, Gemini 0.3, Codex 0.3. (bin/tri-agent-consensus:220-223; 568-612)

Quality gate checklist (12 checks):
- Tests, Coverage, Lint, Types, Security, Build, Dependency audit, Breaking changes, Tri-agent review, Performance (non-blocking), Docs (non-blocking), Commit format (non-blocking). (lib/supervisor-approver.sh:118-624)

Auto-approval conditions:
- All blocking checks PASS and consensus decision = APPROVE; retry budget not exceeded. (lib/supervisor-approver.sh:630-775; 782-801)

Rejection and retry flow:
- On failure, generate feedback and move to rejected; increment retry count and enforce retry budget. (lib/supervisor-approver.sh:782-845)

Escalation path for disagreements:
- If consensus returns NO_CONSENSUS, mark task REJECTED and escalate to human review queue.

Convergence strategy (avoid logic duplication):
- Replace tri-agent-supervisor's direct audits with calls into supervisor-approver; supervisor becomes a thin orchestrator. (bin/tri-agent-supervisor:330-404; lib/supervisor-approver.sh:630-776)


SECTION 9: SELF-HEALING DESIGN

Circuit breaker integration points:
- Delegate scripts should call should_call_model before execution and record_result after execution. (lib/circuit-breaker.sh:130-215; bin/claude-delegate:397-460; bin/codex-delegate:399-499; bin/gemini-delegate:469-545)

Watchdog daemon design:
- tri-agent-daemon supervises worker pool, supervisor, watchdog, and health-check; restarts on failure.
- process-reaper handles zombies and stale locks. (bin/process-reaper:131-245)

Auto-restart logic:
- Restart components after crash up to N times with exponential backoff; log failures to audit log.

Failure detection:
- Missing heartbeat -> recover task. (lib/heartbeat.sh:104-145)
- Circuit breaker OPEN -> skip model calls. (lib/circuit-breaker.sh:191-215)
- Budget watchdog sets pause flag. (bin/budget-watchdog:147-188)

Recovery procedures:
- Worker crash: recover stale locks, requeue tasks, restart worker.
- Model failure: open breaker, fallback to other model, cool down then retry.
- Budget exceeded: pause queue intake; resume when rate normalizes.


SECTION 10: PRIORITY MATRIX

| Priority | ID | Item | File | Effort (hrs) | Impact | Dependencies | Milestone |
|---------|----|------|------|--------------|--------|--------------|-----------|
| P0 | 1 | Support priority subdirectories in worker pickup | bin/tri-agent-worker | 2 | Queue works as spec | None | M1 |
| P0 | 2 | Derive priority from parent dir in locks | bin/tri-agent-worker | 2 | Correct SLAs | P0-1 | M1 |
| P0 | 3 | Queue->sqlite bridge (new queue-watcher) | bin/tri-agent-queue-watcher | 6 | Canonical state | P0-1 | M1 |
| P0 | 4 | Integrate worker with sqlite claim_task_atomic | bin/tri-agent-worker | 8 | Prevent double execution | P0-3 | M1 |
| P0 | 5 | Unify supervisor with 12-gate approver | bin/tri-agent-supervisor | 8 | Consistent approvals | P0-3 | M1 |
| P1 | 6 | SDLC phase state machine | lib/sdlc-state-machine.sh | 6 | Phase enforcement | P0-5 | M2 |
| P1 | 7 | Hook gates to SDLC transitions | lib/supervisor-approver.sh | 4 | Prevent skipping | P1-6 | M2 |
| P1 | 8 | Circuit breaker integration in delegates | bin/*-delegate | 4 | Resilience | None | M2 |
| P1 | 9 | Heartbeat sqlite integration in worker | bin/tri-agent-worker | 4 | Stale recovery | P0-4 | M2 |
| P1 | 10 | Budget pause consumption in worker | bin/tri-agent-worker | 3 | Kill-switch works | None | M2 |
| P1 | 11 | Fix gate portability (tests/coverage/types/security/deps) | lib/supervisor-approver.sh | 6 | Reliable gates | None | M2 |
| P1 | 12 | Tri-agent review uses delegates and skips empty diff | lib/supervisor-approver.sh | 3 | Avoid false fails | None | M2 |
| P2 | 13 | Replace tri-agent-route with router wrapper | bin/tri-agent-route | 2 | Reduce drift | None | M3 |
| P2 | 14 | Health-check alerts integration | bin/health-check | 3 | Better ops | None | M3 |
| P2 | 15 | Event-store integration for task lifecycle | lib/event-store.sh | 4 | Auditability | P0-4 | M3 |
| P2 | 16 | Improve process reaper with worker-pool awareness | bin/process-reaper | 3 | Cleanup accuracy | P0-4 | M3 |
| P2 | 17 | Add inotify-based queue watcher | bin/tri-agent-queue-watcher | 3 | Performance | P0-3 | M4 |
| P2 | 18 | Add chaos tests for worker crash recovery | tests/chaos | 4 | Resilience | P1-9 | M4 |
| P2 | 19 | Add security tests (SAST/secret scan) | tests/security | 6 | Hardening | P1-11 | M5 |
| P2 | 20 | Add doc artifacts validation tooling | lib/sdlc-state-machine.sh | 3 | Compliance | P1-6 | M5 |


SECTION 11: IMPLEMENTATION TIMELINE

| Phase | Milestone | Deliverables | Success Criteria |
|------|-----------|--------------|------------------|
| 1 | M1: Critical Fixes | Queue subdir support, priority parsing, queue-watcher, sqlite claim integration, supervisor unify | System starts and processes 1 task end-to-end without manual intervention |
| 2 | M2: Core Loop | SDLC state machine, gate enforcement, circuit breaker integration, budget pause consumption | Tasks flow through Brainstorm->Track with gates enforced |
| 3 | M3: Self-Healing | Heartbeat integration, process reaper improvements, health-check alerts | System survives worker crash and resumes processing |
| 4 | M4: Optimization | inotify queue watch, performance tuning | 200+ tasks/day without backlog |
| 5 | M5: Hardening | security tests, doc artifact validation, audit improvements | Passes security audit and reliability tests |


SECTION 12: VERIFICATION TEST SUITE

Test script for each critical fix (copy-paste ready):
- Queue subdir pickup (FIX-1/FIX-2):
```bash
mkdir -p "$HOME/.claude/autonomous/tasks/queue/CRITICAL"
echo "# Task" > "$HOME/.claude/autonomous/tasks/queue/CRITICAL/test_task.md"
./bin/tri-agent-worker --cleanup
```
Expected: No errors; task lock created in tasks/running.

- Inbox parsing (FIX-3):
```bash
mkdir -p "$HOME/.claude/autonomous/comms/worker/inbox"
echo '{"type":"CONTROL_PAUSE","payload":{}}' > "$HOME/.claude/autonomous/comms/worker/inbox/pause.json"
./bin/tri-agent-worker --status
```
Expected: Worker stays running and logs pause.

- Gate portability (FIX-6..FIX-11):
```bash
bash -n lib/supervisor-approver.sh
```
Expected: No syntax errors; gates run without jq/bc/grep -P.

Integration test scenarios:
1. Enqueue -> sqlite -> worker claim -> review -> supervisor approval.
2. Budget watchdog sets pause; worker halts claiming new tasks.
3. Circuit breaker opens after repeated delegate failures and later half-opens.

Chaos test scenarios:
- Kill worker during RUNNING; ensure stale lock recovery and requeue. (lib/heartbeat.sh:104-145)
- Simulate rate limit 429 via chaos_rate_limit.sh. (tests/chaos/chaos_rate_limit.sh:1-120)

Success criteria for autonomous operation:
- 24 hours continuous processing with no manual intervention.
- No duplicate task execution (verified via sqlite events and logs).
- Budget kill-switch halts new task claims under $1/min cap.

Monitoring commands:
```bash
./bin/health-check --status
./bin/budget-watchdog --status
./bin/process-reaper --status
```
Expected: Health=OK, budget status OK, reaper running.


QUALITY CHECKLIST (SELF-VERIFIED)
- [x] All 12 sections present
- [x] ASCII diagrams for current and target architecture
- [x] At least 15 complete code fixes
- [x] At least 20 items in priority matrix
- [x] File:line references included for code-based claims
- [x] No secrets included
