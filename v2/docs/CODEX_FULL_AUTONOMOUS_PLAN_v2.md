# CODEX_FULL_AUTONOMOUS_PLAN_v2

Date: 2025-12-28
Author: Codex (GPT-5.2)
Scope: /home/aadel/projects/claude-sdlc-orchestrator/v2 (full codebase + /tmp/AUTONOMOUS_SDLC_PROMPT.md dump)
Goal: 24/7 autonomous tri-agent SDLC system with queue auto-pickup, routing, 5-phase enforcement, tri-supervisor approvals, and self-healing.

---

## 0) Quick TL;DR

- The repo already contains many building blocks (worker, supervisor, consensus, circuit breakers, queue libs), but they are not wired together and are split across incompatible state backends.
- The highest-impact fixes are: unify SQLite state + DB paths, implement SDLC phase engine, switch worker + queue to SQLite, add an autonomous daemon that launches worker pool + supervisor + approver + watchdogs, and enforce quality-gate + consensus approvals.
- This plan is intentionally explicit and copy/paste-ready. Each fix has file:line anchors and concrete snippets.

---

## 1) Target Architecture (ASCII)

### 1.1 Overall Runtime (24/7)

```
+------------------------+         +-------------------------+
| tri-agent-daemon       |         | systemd user services   |
| (new)                  |         | (tri-agent-daemon)      |
+-----------+------------+         +-----------+-------------+
            |                                      |
            v                                      v
+------------------------+         +-------------------------+
| worker-pool (3 shards) |<------->| sqlite state (tri-agent)|
| impl/review/analysis   |         | tasks/events/workers    |
+----+----+----+---------+         +-----------+-------------+
     |    |    |                                |
     |    |    |                                v
     |    |    |                      +--------------------+
     |    |    |                      | supervisor/approver|
     |    |    |                      | (quality+consensus)|
     |    |    |                      +--------------------+
     |    |    |
     v    v    v
Claude  Codex  Gemini

Budget Watchdog + Process Reaper + Heartbeat Monitor
             (self-heal + pause/resume)
```

### 1.2 SDLC Phase Engine (Task lifecycle)

```
QUEUED
  |
  v
RUNNING
  |
  +--> Phase 1: BRAINSTORM (Claude)
  |
  +--> Phase 2: DOCUMENT   (Gemini)
  |
  +--> Phase 3: PLAN       (Claude/Gemini consensus)
  |
  +--> Phase 4: EXECUTE    (Codex)
  |
  +--> Phase 5: TRACK      (Claude supervisor + metrics)
  |
  v
REVIEW  --> APPROVED/REJECTED --> COMPLETED/REQUEUED
```

---

## 2) Component-by-Component Analysis (What Works / Broken / Missing)

### 2.1 Task Queue + State Storage

**Works**
- SQLite schema and helpers exist in `lib/sqlite-state.sh` (tasks/events/workers) with atomic claim helpers. (lib/sqlite-state.sh:46-571)
- SQLite-backed CLI exists (`bin/db-tool`) and a queue tool (`bin/tri-agent-queue`). (bin/db-tool:1-69, bin/tri-agent-queue:1-143)

**Broken**
- State backends are split across 3 different stores:
  - `lib/sqlite-state.sh` uses `state/tri-agent.db` (lib/sqlite-state.sh:16-19)
  - `bin/db-tool` uses `~/.claude/autonomous/state/tri_agent_v5.db` (bin/db-tool:8)
  - `bin/tri-agent-worker` uses filesystem tasks in `~/.claude/autonomous/tasks/...` (bin/tri-agent-worker:110-156)
- `config/schema.sql` defines `current_phase`, but `lib/sqlite-state.sh` does not. (config/schema.sql:4-15 vs lib/sqlite-state.sh:73-101)

**Missing**
- Unified DB migrations for schema changes.
- Single-source config for DB path.
- Phase-aware tasks (Brainstorm → Track) in SQLite.

### 2.2 Worker Agent

**Works**
- Worker does auto-pickup (filesystem), retries, locks, local tests, submission, and comms. (bin/tri-agent-worker:1-1100)
- Has routing logic in-script (task type → model). (bin/tri-agent-worker:640-725)

**Broken**
- Worker doesn’t use SQLite queue or schema, despite helper library. It operates on filesystem tasks. (bin/tri-agent-worker:110-176, 586-634)
- AUTONOMOUS_ROOT override happens *after* `common.sh` is sourced, so libraries are bound to the wrong root. (bin/tri-agent-worker:43-74)

**Missing**
- 5-phase SDLC engine and enforcement.
- Integration with circuit-breakers, cost-breaker, budget watchdog pause, or consensus for critical phases.
- Automatic phase metadata persistence in DB.

### 2.3 Supervisor / Approval

**Works**
- `bin/tri-agent-supervisor` runs security audit + tests on commit changes; tri-model analysis exists. (bin/tri-agent-supervisor:86-403)
- `lib/supervisor-approver.sh` implements a rich multi-check quality gate. (lib/supervisor-approver.sh:630-776)

**Broken**
- Supervisor watches git commits only, not task review queue in SQLite. (bin/tri-agent-supervisor:330-407)
- Quality gates are not wired to auto-approve/reject tasks.
- Consensus votes are not persisted into SQLite.

**Missing**
- A dedicated approval daemon for task review.
- Auto-update of task states APPROVED/REJECTED with gate results and consensus.

### 2.4 Router / Model Selection

**Works**
- tri-agent-router has a policy-based keyword system and file-size rules. (bin/tri-agent-router:132-239)

**Broken**
- Router doesn’t consult circuit-breakers, cost-breaker, or model availability from `lib/model-diversity.sh`.
- Worker does not use router; it re-implements its own rules.

**Missing**
- Unified routing decisions saved to SQLite for audit.
- Auto fallback based on breaker state and retry budget.

### 2.5 Self-Healing / Reliability

**Works**
- Circuit breaker and error-handling libs are present. (lib/circuit-breaker.sh, lib/error-handler.sh)
- Budget watchdog and process reaper exist. (bin/budget-watchdog, bin/process-reaper)
- Heartbeat and stale task recovery functions exist in SQLite libs. (lib/heartbeat.sh, lib/sqlite-state.sh:572-586)

**Broken**
- These reliability tools are not orchestrated together or started automatically.
- Worker does not check global pause state from budget watchdog.

**Missing**
- Unified daemon that runs worker pool + supervisor + approval + watchdog + reaper.
- Runtime health signals in SQLite for easy dashboards.

### 2.6 Configuration & Schema

**Works**
- config/tri-agent.yaml and schema exist. (config/tri-agent.yaml, config/schema.yaml)

**Broken**
- Schema does not cover new SDLC phase settings or queue config.
- Config path mismatches with runtime root (project vs ~/.claude/autonomous).

**Missing**
- Phase definitions and gates in config.
- Explicit queue/worker/supervisor configuration in schema.

### 2.7 Worker Pool & Sharding

**Works**
- `lib/worker-pool.sh` can start 3 workers and assign shards/models. (lib/worker-pool.sh:108-184)

**Broken**
- Pool routes via SQLite but the worker still consumes filesystem tasks, so sharding is ineffective. (lib/worker-pool.sh:133-153 vs bin/tri-agent-worker:1690-1699)
- No daemon or service starts the pool automatically.

**Missing**
- Health aggregation and pool supervision loop.
- Coordinated shutdown that requeues RUNNING tasks in SQLite.

### 2.8 Launcher & Session Management

**Works**
- `bin/tri-agent` creates tmux sessions and manages CLI validation. (bin/tri-agent:30-678)

**Broken**
- Launches an interactive orchestrator but does not start the autonomous worker/supervisor pipeline.

**Missing**
- Background, 24/7 daemon mode to spawn worker pool + supervisor + approver + watchdogs.

### 2.9 Monitoring & Ops

**Works**
- `monitor.sh` and `bin/tri-agent-dashboard` provide basic runtime visibility.

**Broken**
- Monitoring reads filesystem queues and misses SQLite-backed tasks/states.

**Missing**
- SQLite-backed health status and phase timing metrics.

---

## 3) Gap Analysis vs Requirements

Requirement | Current State | Gap
---|---|---
24/7 autonomous | Scripts exist but not orchestrated | Missing daemon/service layer
Auto-pick tasks | Worker picks from filesystem queue | No SQLite-backed auto-pick
Router to right AI | Router exists but not used by worker | Integrate router + model diversity
5 SDLC phases | Phase concept in schema only | No phase engine / DB fields
Tri-supervisor approvals | Quality gate exists but unused | Need approval daemon + consensus logging
Self-heal | Tools exist (watchdog, reaper, heartbeat) | Not wired to worker/queue

---

## 4) Integration Points (What talks to what)

- **Queue → Worker**: SQLite tasks table, atomic claim (`claim_task_atomic_filtered`) from `lib/sqlite-state.sh`.
- **Worker → Phase Engine**: new `lib/sdlc-phases.sh` manages phase transitions + model invocations.
- **Worker → Router**: call `bin/tri-agent-router --json` for model selection OR use router logic in lib.
- **Worker → Supervisor**: write review submission to SQLite + send comms message.
- **Supervisor/Approver → SQLite**: updates `tasks.state`, writes `gates` + `consensus_votes`.
- **Watchdog → SQLite**: sets pause flag; worker respects it.
- **Reaper/Heartbeat → SQLite**: recovers stale tasks, updates workers.

---

## 5) P0 Implementation Plan (Blocking)

### P0-01: Unify SQLite DB Path Across Tools

**Problem**: `db-tool` uses `tri_agent_v5.db`, while `sqlite-state.sh` uses `tri-agent.db`. (bin/db-tool:8, lib/sqlite-state.sh:16-19)

**Fix** (update `bin/db-tool`):

File: `bin/db-tool:8-30`

```python
# Replace existing DB_PATH definition
DEFAULT_ROOT = os.environ.get("AUTONOMOUS_ROOT", os.path.expanduser("~/.claude/autonomous"))
DB_PATH = os.environ.get("TRI_AGENT_DB", os.path.join(DEFAULT_ROOT, "state/tri-agent.db"))

# Add optional --db argument
# ... inside main()
query_parser.add_argument("--db", help="Path to sqlite db", default=DB_PATH)

# and use args.db
if args.command == "init":
    init_db(args.db)
elif args.command == "query":
    query_args = json.loads(args.args)
    execute_query(args.sql, query_args, args.db)
```

Also update signatures:
```python
def init_db(db_path=DB_PATH):
    os.makedirs(os.path.dirname(db_path), exist_ok=True)
    conn = sqlite3.connect(db_path)
    ...

def execute_query(query, args=(), db_path=DB_PATH):
    conn = sqlite3.connect(db_path)
    ...
```

**Integration**: `bin/tri-agent-queue` should call db-tool with `--db` or set `TRI_AGENT_DB` env.

**Complexity**: S

---

### P0-02: Align `tri-agent-queue` With Unified DB Path

**Problem**: queue uses db-tool from `~/.claude/autonomous/bin`, but DB path inside db-tool is inconsistent and not configurable. (bin/tri-agent-queue:8-11, 42-45)

**Fix** (update queue tool to pass explicit DB path):

File: `bin/tri-agent-queue:8-47`

```bash
# New defaults
AUTONOMOUS_ROOT="${AUTONOMOUS_ROOT:-$HOME/.claude/autonomous}"
DB_PATH="${TRI_AGENT_DB:-${AUTONOMOUS_ROOT}/state/tri-agent.db}"
DB_TOOL="${AUTONOMOUS_ROOT}/bin/db-tool"

# In add_task/list/process/status:
$DB_TOOL --db "$DB_PATH" query "$query" --args "$args" > /dev/null
```

**Integration**: makes queue consistent with `lib/sqlite-state.sh` and worker pool.

**Complexity**: S

---

### P0-03: Add `current_phase` + Phase Metadata To SQLite Schema

**Problem**: config schema includes `current_phase`, but runtime schema does not. (config/schema.sql:4-15 vs lib/sqlite-state.sh:73-101)

**Fix** (update schema + migration):

File: `lib/sqlite-state.sh:73-101`

```bash
# Add columns in CREATE TABLE tasks
current_phase TEXT DEFAULT 'BRAINSTORM',
phase_started_at TEXT,
phase_updated_at TEXT,
```

Add a migration helper:

File: `lib/sqlite-state.sh` (new function near sqlite_state_init):

```bash
sqlite_state_migrate() {
    _sqlite_require
    _ensure_db
    # add columns if missing
    sqlite3 "$STATE_DB" "ALTER TABLE tasks ADD COLUMN current_phase TEXT DEFAULT 'BRAINSTORM';" 2>/dev/null || true
    sqlite3 "$STATE_DB" "ALTER TABLE tasks ADD COLUMN phase_started_at TEXT;" 2>/dev/null || true
    sqlite3 "$STATE_DB" "ALTER TABLE tasks ADD COLUMN phase_updated_at TEXT;" 2>/dev/null || true
}
```

Call it at the end of `sqlite_state_init`.

**Complexity**: M

---

### P0-04: Introduce SDLC Phase Engine (New Library)

**Problem**: No enforcement of Brainstorm → Document → Plan → Execute → Track.

**Fix**: Create `lib/sdlc-phases.sh` with deterministic phase transitions + model routing hooks.

New file: `lib/sdlc-phases.sh`

```bash
#!/bin/bash
# SDLC phase engine (Brainstorm → Document → Plan → Execute → Track)

SDLC_PHASES=("BRAINSTORM" "DOCUMENT" "PLAN" "EXECUTE" "TRACK")

sdlc_phase_next() {
  local phase="$1"
  case "$phase" in
    BRAINSTORM) echo "DOCUMENT";;
    DOCUMENT)   echo "PLAN";;
    PLAN)       echo "EXECUTE";;
    EXECUTE)    echo "TRACK";;
    TRACK)      echo "DONE";;
    *)          echo "BRAINSTORM";;
  esac
}

sdlc_phase_valid() {
  local from="$1" to="$2"
  [[ "$(sdlc_phase_next "$from")" == "$to" ]]
}

sdlc_set_phase() {
  local task_id="$1" phase="$2" actor="${3:-system}"
  local esc_task esc_phase
  esc_task=$(_sql_escape "$task_id")
  esc_phase=$(_sql_escape "$phase")
  _sqlite_exec "$STATE_DB" "UPDATE tasks SET current_phase='${esc_phase}', phase_updated_at=datetime('now') WHERE id='${esc_task}';"
  _sqlite_exec "$STATE_DB" "INSERT INTO events (task_id,event_type,actor,payload,trace_id) VALUES ('${esc_task}','PHASE_${esc_phase}','${actor}','', '${TRACE_ID}');"
}
```

**Integration**:
- Source from `lib/common.sh` or worker.
- Worker uses `sdlc_set_phase` before each model execution.

**Complexity**: M

---

### P0-05: Switch Worker to SQLite Queue (Atomic Claim)

**Problem**: Worker reads filesystem tasks, ignoring SQLite. (bin/tri-agent-worker:110-176)

**Fix**: Add a SQLite claim path and disable filesystem path by default.

File: `bin/tri-agent-worker:586-634` (parser) and `bin/tri-agent-worker:1654-1717` (main loop):

```bash
claim_task_from_db() {
  local types_csv="${WORKER_TASK_TYPES:-}"
  local task_id
  task_id=$(claim_task_atomic_filtered "$WORKER_ID" "$types_csv" "${WORKER_SHARD:-}" "${WORKER_MODEL:-}")
  [[ -n "$task_id" ]] && echo "$task_id"
}

load_task_payload_db() {
  local task_id="$1"
  local esc_task
  esc_task=$(_sql_escape "$task_id")
  _sqlite_exec "$STATE_DB" "SELECT payload FROM tasks WHERE id='${esc_task}' LIMIT 1;"
}
```

Then in main loop:

```bash
# Replace filesystem scan with db claim
if pause_requested; then
  log_warn "Pause requested; worker idle"
  sleep 10
  continue
fi

TASK_ID=$(claim_task_from_db || true)
[[ -z "$TASK_ID" ]] && sleep "$POLL_CURRENT" && continue

TASK_PAYLOAD=$(load_task_payload_db "$TASK_ID")
parse_task_payload "$TASK_PAYLOAD"  # new parser for DB payload
```

**Integration**: Uses `claim_task_atomic_filtered` from `lib/sqlite-state.sh` (lines 495-548).

**Complexity**: L

---

### P0-06: Fix Worker Root Initialization Order

**Problem**: `AUTONOMOUS_ROOT` override occurs after `common.sh` is sourced (libraries bound to wrong root). (bin/tri-agent-worker:43-74)

**Fix**: set `AUTONOMOUS_ROOT` before sourcing common.sh.

File: `bin/tri-agent-worker:35-55`

```bash
# Move this block BEFORE sourcing common.sh
AUTONOMOUS_ROOT="${AUTONOMOUS_ROOT:-${HOME}/.claude/autonomous}"
export AUTONOMOUS_ROOT

# Now source common
source "${PROJECT_ROOT}/lib/common.sh"
```

**Complexity**: S

---

### P0-07: SDLC Phase Execution Pipeline in Worker

**Problem**: Worker executes once; no phase gating.

**Fix**: Add phase pipeline wrapper around model execution.

File: `bin/tri-agent-worker:769-860` (execute_task) and `bin/tri-agent-worker:731-767` (prompt build):

```bash
execute_task_phases() {
  local task_id="$1"
  local context="$2"

  # Phase 1: Brainstorm (Claude)
  sdlc_set_phase "$task_id" "BRAINSTORM" "$WORKER_ID"
  execute_with_model "claude" "Brainstorm solution for task $task_id" "$context" 180

  # Phase 2: Document (Gemini)
  sdlc_set_phase "$task_id" "DOCUMENT" "$WORKER_ID"
  execute_with_model "gemini" "Document requirements and constraints for $task_id" "$context" 240

  # Phase 3: Plan (Consensus)
  sdlc_set_phase "$task_id" "PLAN" "$WORKER_ID"
  execute_with_model "consensus" "Provide an execution plan for $task_id" "$context" 240

  # Phase 4: Execute (Codex)
  sdlc_set_phase "$task_id" "EXECUTE" "$WORKER_ID"
  execute_with_model "codex" "Implement the task $task_id" "$context" 600

  # Phase 5: Track (Claude)
  sdlc_set_phase "$task_id" "TRACK" "$WORKER_ID"
  execute_with_model "claude" "Summarize changes and track metrics for $task_id" "$context" 180
}
```

**Integration**: calls `sdlc_set_phase` from new `lib/sdlc-phases.sh`.

**Complexity**: L

---

### P0-08: Enforce Quality Gates + Consensus on Review

**Problem**: Quality gates exist but not used for auto-approval.

**Fix**: Add new `bin/tri-agent-approver` daemon to pull REVIEW tasks from SQLite, run `quality_gate`, then `tri-agent-consensus` for final approval.

New file: `bin/tri-agent-approver`

```bash
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/sqlite-state.sh"
source "${SCRIPT_DIR}/../lib/supervisor-approver.sh"

APPROVER_INTERVAL="${APPROVER_INTERVAL:-20}"

while true; do
  task_id=$(sqlite3 "$STATE_DB" "SELECT id FROM tasks WHERE state='REVIEW' ORDER BY updated_at ASC LIMIT 1;")
  if [[ -z "$task_id" ]]; then
    sleep "$APPROVER_INTERVAL"
    continue
  fi

  if quality_gate "$task_id" "${TRI_AGENT_WORKSPACE:-$PWD}"; then
    consensus_json=$("${BIN_DIR}/tri-agent-consensus" --mode veto --category security "Approve task $task_id?" --json-only || true)
    decision=$(echo "$consensus_json" | jq -r '.decision // "NO_CONSENSUS"')
    if [[ "$decision" == "APPROVE" ]]; then
      mark_task_approved "$task_id"
    else
      mark_task_rejected "$task_id" "Consensus rejected"
    fi
  else
    mark_task_rejected "$task_id" "Quality gate failed"
  fi

done
```

**Integration**: uses `lib/supervisor-approver.sh` and `bin/tri-agent-consensus`.

**Complexity**: L

---

### P0-09: Persist Consensus Votes to SQLite

**Problem**: consensus results are logged to files only; no DB audit.

**Fix**: insert consensus results into `consensus_votes` table.

File: `bin/tri-agent-consensus` near `log_consensus_event()` (around line 691+):

```bash
# After final decision computed
if [[ -f "${LIB_DIR}/sqlite-state.sh" ]]; then
  source "${LIB_DIR}/sqlite-state.sh"
  sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true
  sqlite3 "$STATE_DB" <<SQL
INSERT INTO consensus_votes (task_id, gate_id, claude_vote, codex_vote, gemini_vote, final_decision)
VALUES ('${TASK_ID:-}', 'CONSENSUS', '${claude_verdict}', '${codex_verdict}', '${gemini_verdict}', '${decision}');
SQL
fi
```

**Complexity**: M

---

### P0-10: Integrate Circuit Breaker + Cost Breaker Into Worker Execution

**Problem**: worker executes models without breaker checks. (bin/tri-agent-worker:670-725)

**Fix**: add guard before `execute_with_model`.

File: `bin/tri-agent-worker:670-725`

```bash
# Pre-exec guards
if command -v should_call_model &>/dev/null; then
  if ! should_call_model "$model"; then
    log_warn "Circuit breaker OPEN for $model; falling back"
    model="claude"
  fi
fi

if command -v cost_breaker_should_allow &>/dev/null; then
  if ! cost_breaker_should_allow "$model" 0 0; then
    log_warn "Cost breaker blocked $model; falling back"
    model="claude"
  fi
fi
```

**Complexity**: S

---

### P0-11: Add Pause/Resume Hook in Worker

**Problem**: budget-watchdog sets pause state but worker ignores it.

**Fix** (in worker main loop):

File: `bin/tri-agent-worker:1667-1676` (main loop pause check):

```bash
if pause_requested; then
  log_warn "Pause requested (budget watchdog). Sleeping..."
  sleep 15
  continue
fi
```

**Complexity**: S

---

### P0-12: Autonomous Daemon (One Command, 24/7)

**Problem**: no single command to start worker pool + supervisor + approver + watchdogs.

**Fix**: new `bin/tri-agent-daemon`.

New file: `bin/tri-agent-daemon`

```bash
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/sqlite-state.sh"

nohup "${BIN_DIR}/tri-agent-migrate" --all >/dev/null 2>&1 &
nohup "${BIN_DIR}/tri-agent-approver" >/dev/null 2>&1 &
nohup "${BIN_DIR}/tri-agent-supervisor" >/dev/null 2>&1 &
nohup "${BIN_DIR}/budget-watchdog" --daemon >/dev/null 2>&1 &
nohup "${BIN_DIR}/process-reaper" --daemon >/dev/null 2>&1 &
nohup "${LIB_DIR}/worker-pool.sh" start >/dev/null 2>&1 &

log_info "tri-agent-daemon started"
```

**Complexity**: M

---

### P0-13: Systemd Service for Daemon

**Problem**: 24/7 requires boot persistence and auto-restart.

**Fix**: add service file `deployment/tri-agent-daemon.service`.

New file: `deployment/tri-agent-daemon.service`

```ini
[Unit]
Description=Tri-Agent Autonomous Daemon
After=network.target

[Service]
Type=simple
ExecStart=/home/aadel/projects/claude-sdlc-orchestrator/v2/bin/tri-agent-daemon
WorkingDirectory=/home/aadel/projects/claude-sdlc-orchestrator/v2
Restart=always
RestartSec=5
Environment=AUTONOMOUS_ROOT=/home/aadel/.claude/autonomous

[Install]
WantedBy=default.target
```

**Complexity**: S

---

### P0-14: Update Config Schema for Phase & Queue Settings

**Problem**: config lacks phase + queue settings.

**Fix**: extend schema in `config/schema.yaml` and values in `config/tri-agent.yaml`.

File: `config/schema.yaml` (add new sections after `monitoring`):

```yaml
  sdlc:
    type: object
    properties:
      phases:
        type: array
        items: { type: string }
      phase_timeouts:
        type: object
        additionalProperties:
          type: integer
  queue:
    type: object
    properties:
      backend:
        type: string
        enum: ["sqlite"]
      poll_interval:
        type: integer
  approval:
    type: object
    properties:
      quality_gate_threshold:
        type: integer
      consensus_mode:
        type: string
        enum: ["majority","weighted","veto"]
```

File: `config/tri-agent.yaml` (add):

```yaml
sdlc:
  phases: ["BRAINSTORM","DOCUMENT","PLAN","EXECUTE","TRACK"]
  phase_timeouts:
    BRAINSTORM: 600
    DOCUMENT: 900
    PLAN: 900
    EXECUTE: 3600
    TRACK: 600
queue:
  backend: "sqlite"
  poll_interval: 10
approval:
  quality_gate_threshold: 85
  consensus_mode: "veto"
```

**Complexity**: M

---

### P0-15: Migrate Existing File-Based Queue Into SQLite

**Problem**: legacy tasks in `tasks/queue` are invisible to SQLite worker.

**Fix**: add migration to `bin/tri-agent-migrate` for tasks.

File: `bin/tri-agent-migrate` (add after queue migration):

```bash
migrate_tasks_to_sqlite() {
  sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true
  for f in "${TASK_QUEUE_DIR}"/*.md; do
    [[ -f "$f" ]] || continue
    local id
    id=$(basename "$f" | sed 's/\.md$//')
    local payload
    payload=$(cat "$f")
    create_task "$id" "$id" "legacy" "MEDIUM" "$payload" "QUEUED"
  done
}
```

**Complexity**: M

---

## 6) P1 Implementation Plan (Important)

### P1-01: Router Integration With Model Diversity & Error Handling

**Problem**: router does not check model availability or diversity. (bin/tri-agent-router:132-239)

**Fix**: integrate `lib/model-diversity.sh` + error-handler fallback chain.

File: `bin/tri-agent-router:359-402` (decision) and `bin/tri-agent-router:408-429` (logging):

```bash
# After best_model computed
if command -v diversity_select &>/dev/null; then
  selected=$(diversity_select 1 "$best_model")
  best_model=$(echo "$selected" | awk '{print $1}')
fi

# If model unavailable, fallback
if command -v model_is_available &>/dev/null; then
  if ! model_is_available "$best_model"; then
    best_model="claude"
  fi
fi
```

**Complexity**: M

---

### P1-02: Persist Routing Decisions to SQLite

**Problem**: routing decisions are logged only to JSONL.

**Fix**: insert a row in `routing_decisions` table.

File: `bin/tri-agent-router:408-429` (log_routing_decision) or immediately after compute_routing_decision (lines 359-402):

```bash
if [[ -f "${LIB_DIR}/sqlite-state.sh" ]]; then
  source "${LIB_DIR}/sqlite-state.sh"
  sqlite_state_init "$STATE_DB" >/dev/null 2>&1 || true
  sqlite3 "$STATE_DB" "INSERT INTO routing_decisions (timestamp,trace_id,model,confidence,reason,prompt_length,file_count,executed,forced,consensus) VALUES (datetime('now'),'${TRACE_ID}','${best_model}',${confidence},'${reason}',${prompt_len},${file_count},1,'${FORCE_MODEL}',${CONSENSUS});"
fi
```

**Complexity**: S

---

### P1-03: Heartbeat Integration With Worker

**Problem**: worker doesn’t update SQLite heartbeat. (lib/heartbeat.sh exists)

**Fix**: update worker loop to call `heartbeat_record` and `heartbeat_record_activity`.

File: `bin/tri-agent-worker:1654-1717` (main loop) and `bin/tri-agent-worker:1501-1523` (heartbeat loop):

```bash
heartbeat_record "$WORKER_ID" "busy" "$TASK_ID" "$TASK_TYPE" 10
# ... during long operations
heartbeat_record_activity "$WORKER_ID" "$TASK_ID"
```

**Complexity**: M

---

### P1-04: Event Store Integration

**Problem**: event-store exists but unused; SQLite events used inconsistently.

**Fix**: dual-write high-level events to `event-store.sh`.

File: `bin/tri-agent-worker:769-860` (execute_task) and `bin/tri-agent-worker:941-1034` (submit_for_review):

```bash
event_append "TASK_STARTED" "{\"task_id\":\"$TASK_ID\"}" "{\"worker\":\"$WORKER_ID\"}"
```

**Complexity**: M

---

### P1-05: Central Health Status Table Updates

**Problem**: health_status table exists but never written.

**Fix**: add periodic health update in `bin/tri-agent-daemon` or worker pool.

```bash
sqlite3 "$STATE_DB" "INSERT OR REPLACE INTO health_status (component,status,details,updated_at) VALUES ('worker-pool','ok','heartbeat ok',datetime('now'));"
```

**Complexity**: S

---

### P1-06: RAG Context Store for Large Tasks

**Problem**: large-context tasks lack RAG/FTS integration.

**Fix**: when task payload is large, chunk into rag store.

File: `bin/tri-agent-worker:731-760` (prompt build) and `bin/tri-agent-worker:769-820` (execute_task):

```bash
if [[ ${#TASK_PAYLOAD} -gt 50000 ]]; then
  rag_init
  rag_store "$TASK_ID" "$TASK_PAYLOAD" "task_payload"
fi
```

**Complexity**: M

---

## 7) P2 Implementation Plan (Nice-to-have)

### P2-01: Upgrade monitor.sh to show SQLite task stats

Replace filesystem task counts with SQLite queries. (monitor.sh:1-120)

Snippet:
```bash
pending=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM tasks WHERE state='QUEUED';")
running=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM tasks WHERE state='RUNNING';")
review=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM tasks WHERE state='REVIEW';")
```

### P2-02: Expand tri-agent-dashboard and quality reports

Add per-phase durations from SQLite and show in dashboard.

Snippet:
```bash
sqlite3 "$STATE_DB" "SELECT current_phase, AVG((julianday('now')-julianday(phase_updated_at))*86400) AS avg_age_s FROM tasks GROUP BY current_phase;"
```

### P2-03: Automated nightly `tri-agent-quality --report`

Generate HTML reports and store in `reports/`.

Snippet (cron):
```bash
0 2 * * * /home/aadel/projects/claude-sdlc-orchestrator/v2/bin/tri-agent-quality --report >> /home/aadel/projects/claude-sdlc-orchestrator/v2/logs/quality-nightly.log 2>&1
```

---

## 8) New Files to Create

- `lib/sdlc-phases.sh` (phase engine)
- `bin/tri-agent-approver` (approval daemon)
- `bin/tri-agent-daemon` (orchestration daemon)
- `deployment/tri-agent-daemon.service` (systemd service)

---

## 9) Priority Order + Complexity Summary

ID | Priority | Complexity | Summary
---|---|---|---
P0-01 | P0 | S | unify DB path
P0-02 | P0 | S | queue uses DB path
P0-03 | P0 | M | schema + migrations for phases
P0-04 | P0 | M | phase engine lib
P0-05 | P0 | L | worker SQLite queue
P0-06 | P0 | S | fix AUTONOMOUS_ROOT ordering
P0-07 | P0 | L | phase execution pipeline
P0-08 | P0 | L | approval daemon
P0-09 | P0 | M | persist consensus
P0-10 | P0 | S | breaker + cost guard
P0-11 | P0 | S | pause hook
P0-12 | P0 | M | daemon entrypoint
P0-13 | P0 | S | systemd service
P0-14 | P0 | M | config schema updates
P0-15 | P0 | M | migrate legacy tasks
P1-01 | P1 | M | router diversity + fallback
P1-02 | P1 | S | routing decisions to DB
P1-03 | P1 | M | heartbeat integration
P1-04 | P1 | M | event-store integration
P1-05 | P1 | S | health status
P1-06 | P1 | M | RAG integration
P2-01 | P2 | S | monitor SQLite stats
P2-02 | P2 | M | dashboards
P2-03 | P2 | S | nightly quality reports

---

## 10) Detailed Fixes (Expanded with File:Line References + Snippets)

### D-01: `bin/db-tool` DB Path Parameterization

- Files: `bin/db-tool:8-46`
- Replace global `DB_PATH` and add `--db` arg as shown in P0-01.

### D-02: `bin/tri-agent-queue` uses explicit DB path

- Files: `bin/tri-agent-queue:8-47`
- Add `AUTONOMOUS_ROOT` and `DB_PATH`, pass to db-tool.

### D-03: `lib/sqlite-state.sh` migration

- Files: `lib/sqlite-state.sh:46-101`
- Add `sqlite_state_migrate()` and call it at end of init.

### D-04: `lib/sqlite-state.sh` tasks table phase fields

- Files: `lib/sqlite-state.sh:73-101`

```bash
current_phase TEXT DEFAULT 'BRAINSTORM',
phase_started_at TEXT,
phase_updated_at TEXT,
```

### D-05: `lib/sdlc-phases.sh` new library

- New file: see P0-04.

### D-06: Worker claim from SQLite

- Files: `bin/tri-agent-worker:586-634` (new parse function) and main loop around task claiming
- Snippet provided in P0-05.

### D-07: Worker phase pipeline

- Files: `bin/tri-agent-worker:731-820`
- Snippet in P0-07.

### D-08: Worker breaker + cost guard

- Files: `bin/tri-agent-worker:670-725`
- Snippet in P0-10.

### D-09: Worker pause hook

- Files: `bin/tri-agent-worker` main loop
- Snippet in P0-11.

### D-10: Approver daemon

- New file: `bin/tri-agent-approver` (see P0-08)

### D-11: Persist consensus votes

- Files: `bin/tri-agent-consensus:660-700`
- Snippet in P0-09.

### D-12: Router diversity fallback

- Files: `bin/tri-agent-router:132-239`
- Snippet in P1-01.

### D-13: Routing decisions to DB

- Files: `bin/tri-agent-router` decision block
- Snippet in P1-02.

### D-14: Config schema + defaults

- Files: `config/schema.yaml:197+`, `config/tri-agent.yaml:200+`
- Snippet in P0-14.

### D-15: Migration of legacy tasks

- Files: `bin/tri-agent-migrate` add new function

---

## 11) Testing / Validation Plan

- `bin/db-tool init` creates SQLite schema and `tasks` includes `current_phase`.
- `bin/tri-agent-queue add` inserts task and `current_phase=BRAINSTORM`.
- `bin/tri-agent-daemon` starts worker pool + supervisor + approver + watchdog.
- Create a test task -> worker claims -> phases update -> task enters REVIEW -> approver runs quality gate -> APPROVED -> COMPLETED.
- Verify `consensus_votes` and `routing_decisions` tables populated.

---

## 12) Risks & Mitigations

- **Schema drift**: add `sqlite_state_migrate` and keep schema version in `meta` table.
- **Race conditions**: use SQLite `BEGIN IMMEDIATE` for claim and transitions.
- **Model unavailability**: use circuit breaker + fallback order.
- **Budget runaway**: budget-watchdog pause + cost breaker.

---

## 13) Next Steps (Execution Order)

1) Implement P0-01 to P0-03 to unify storage.
2) Implement P0-04 to P0-07 to enforce phases in worker.
3) Implement P0-08 to P0-13 to wire approvals + daemon + service.
4) Implement P0-14 to P0-15 to update schema/config + migrate legacy tasks.
5) Implement P1 items (routing persistence, heartbeat, RAG).
6) Add P2 improvements.

---

End of plan.
