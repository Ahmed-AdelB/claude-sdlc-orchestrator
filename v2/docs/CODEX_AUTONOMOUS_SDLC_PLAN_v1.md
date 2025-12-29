# CODEX AUTONOMOUS SDLC PLAN v1

Date: 2025-12-28
Scope: Implementation-focused analysis for the five specified components.
Goal: Enable a 24/7 tri-agent SDLC orchestrator with queue pickup, correct routing, 5-phase enforcement, tri-supervisor approvals, and self-healing.

---

## Component 1: bin/tri-agent-worker

### Current implementation status
Partial. File-based queue processing, lock acquisition, execution, retries, submission, and heartbeats are implemented.

### What works
- Priority queue scanning (CRITICAL/HIGH/MEDIUM/LOW) with FIFO by mtime (`bin/tri-agent-worker:342`).
- Atomic task locks via mkdir + lock metadata (`bin/tri-agent-worker:370`).
- Task parsing, type inference, routing heuristics, and execution pipeline (`bin/tri-agent-worker:540`, `bin/tri-agent-worker:640`, `bin/tri-agent-worker:768`).
- Local pre-submission checks and submission to review queue (`bin/tri-agent-worker:873`, `bin/tri-agent-worker:941`).
- Retry/rejection handling and stale lock cleanup (`bin/tri-agent-worker:1120`, `bin/tri-agent-worker:1224`, `bin/tri-agent-worker:460`).
- Worker heartbeat loop (`bin/tri-agent-worker:1450`).

### What is broken or missing
- Root mismatch: worker force-overrides `AUTONOMOUS_ROOT` to `~/.claude/autonomous`, while supervisor/approver default to repo root. This splits queues and comms (`bin/tri-agent-worker:57`).
- No shard/lane/model filtering. Worker ignores `WORKER_SPECIALIZATION`, `WORKER_MODEL`, `WORKER_SHARD` from worker-pool and uses only filename priority (`bin/tri-agent-worker:342`, `bin/tri-agent-worker:640`).
- No SQLite task/worker state integration. Worker never updates `tasks`, `workers`, or `worker_heartbeats` tables; pool health checks and routing are blind.
- Circuit breaker is not used. Model calls proceed even when breakers are OPEN, no failure recording/fallback (`bin/tri-agent-worker:670`).
- SDLC phases are not enforced. No Brainstorm->Document->Plan->Execute->Track gating or transitions.
- Local tests and delegates can hang without timeouts in some paths (CLI fallbacks have no timeout, tests not wrapped).

### Exact code changes needed
- `bin/tri-agent-worker:57` remove the hard override of `AUTONOMOUS_ROOT` and instead respect an env var or a shared config value used by supervisor/approver. Add a sanity log to ensure all agents use the same root.
- `bin/tri-agent-worker:103` align queue/comm paths with the chosen root (either project root or global). This must match supervisor and approver paths.
- `bin/tri-agent-worker:342` add filtering by shard/lane/model. Two options:
  - File-based: parse task front matter (e.g., `Assigned-Model`, `Shard`, `Lane`) and skip tasks that do not match.
  - SQLite-based: query `tasks` table for matching `assigned_model`/`shard` and atomically claim tasks (preferred for multi-worker correctness).
- `bin/tri-agent-worker:640` honor `WORKER_MODEL`/`WORKER_SPECIALIZATION` overrides (from worker-pool) before heuristic routing.
- `bin/tri-agent-worker:670` integrate circuit breaker:
  - Before calling a model: `should_call_model`.
  - After call: `record_success`/`record_failure`.
  - On OPEN: fallback to an available model (via `get_available_models`) or requeue with backoff.
- `bin/tri-agent-worker:802` include actual task content and optional repo context in `execute_with_model` (currently passes empty context), or attach path references so delegates can read context.
- `bin/tri-agent-worker:873` wrap local tests/lints with `timeout` to prevent hung worker.
- `bin/tri-agent-worker:941` update task state to REVIEW in SQLite (if using DB) and add a `phase` field in task metadata for SDLC phase tracking.
- `bin/tri-agent-worker:1654` add phase transition enforcement (e.g., refuse to execute if task missing Brainstorm/Document/Plan artifacts), and update heartbeat info into SQLite using `heartbeat_record`.

---

## Component 2: bin/tri-agent-supervisor

### Current implementation status
Partial. It watches git commits and runs security/tests, generates feedback tasks and tri-agent analysis.

### What works
- Commit-based auditing with security and test runs (`bin/tri-agent-supervisor:330`).
- Tri-agent analysis (Claude/Codex/Gemini) for failures (`bin/tri-agent-supervisor:155`).
- Task creation for primary session queue (`bin/tri-agent-supervisor:241`).

### What is broken or missing
- Does not process worker submissions or review queue. It never consumes `comms/supervisor/inbox` or `tasks/review`.
- No integration with the approval engine (`lib/supervisor-approver.sh`), so quality gates are not enforced for worker submissions.
- No tri-supervisor consensus enforcement; tri-agent usage is only for failure analysis.
- Root mismatch (uses repo-root via `common.sh`) can disconnect from worker queues.
- `--daemon` flag does not actually daemonize; relies on external process manager.

### Exact code changes needed
- `bin/tri-agent-supervisor:30` align AUTONOMOUS_ROOT with worker/approver (shared config or env) so queues and comms are consistent.
- `bin/tri-agent-supervisor:330` extend main loop to:
  - Read `comms/supervisor/inbox` for `TASK_COMPLETE`, `TASK_FAIL`, `ESCALATION` messages.
  - Trigger `lib/supervisor-approver.sh` `run_approval_workflow` for each task in review.
- `bin/tri-agent-supervisor:330` add 5-phase enforcement checks before approval (fail tasks missing Brainstorm/Document/Plan artifacts).
- `bin/tri-agent-supervisor:330` optionally write decisions back to SQLite `gates`/`consensus_votes` tables for auditability.

---

## Component 3: lib/worker-pool.sh

### Current implementation status
Partial. It can start a 3-worker pool, assign routing metadata in SQLite, and mark dead workers.

### What works
- Worker launch with specialization and model env vars (`lib/worker-pool.sh:156`).
- SQLite routing assignment based on task type (`lib/worker-pool.sh:133`).
- Health check to mark dead workers (`lib/worker-pool.sh:186`).

### What is broken or missing
- No ingestion from file-based queue into SQLite tasks table; routing is a no-op if tasks are never inserted.
- No task claiming logic for workers. Workers do not read SQLite state or respect assigned shard/model.
- Health check does not auto-respawn dead workers or reassign their tasks.
- Worker status/heartbeat is never updated by workers, so health checks are stale.

### Exact code changes needed
- `lib/worker-pool.sh:133` add a sync step from `tasks/queue` (filesystem) into SQLite `tasks` table (or replace file queue entirely).
- `lib/worker-pool.sh:237` expand loop to maintain pool size: detect `dead` workers and restart them; reassign `RUNNING` tasks to `QUEUED` when worker dies.
- `lib/worker-pool.sh:156` pass a shared `AUTONOMOUS_ROOT` and worker constraints; update worker to honor these values.
- Add a DB claim function in `lib/sqlite-state.sh` (or in worker) for atomic task claiming by shard/model.

---

## Component 4: lib/supervisor-approver.sh

### Current implementation status
Implemented quality gates, approvals, rejections, and a daemon loop.

### What works
- 12 gate checks (tests, coverage, lint, security, build, etc.) and scoring (`lib/supervisor-approver.sh:630`).
- Approval/rejection flows with feedback and retry safeguards (`lib/supervisor-approver.sh:1005`, `lib/supervisor-approver.sh:1088`).
- Tri-agent review check (2/3 approval) (`lib/supervisor-approver.sh:455`).

### What is broken or missing
- Quality gate execution uses `timeout` on shell function names, which will fail because shell functions are not executables. This makes gates effectively always fail or be skipped (`lib/supervisor-approver.sh:701`).
- Tri-agent review uses raw CLIs (`codex`, `gemini`) and not the delegate wrappers; may fail in production where delegates are expected.
- Approval does not update task state to COMPLETED or persist results to SQLite tables.
- Root mismatch with worker queues if AUTONOMOUS_ROOT differs.

### Exact code changes needed
- `lib/supervisor-approver.sh:701` change gate runner to execute functions correctly, e.g.:
  - `timeout "$GATE_TIMEOUT" bash -c "$check_func \"$workspace\" \"$check_result_file\""`
  - or re-route through CLI subcommands (preferred for isolation).
- `lib/supervisor-approver.sh:455` use `bin/codex-delegate` and `bin/gemini-delegate` if present, with timeouts.
- `lib/supervisor-approver.sh:1005` after approval, move task to COMPLETED and write to SQLite `tasks.state='APPROVED'/'COMPLETED'` plus `gates`/`consensus_votes` records.
- `lib/supervisor-approver.sh:1450` ensure daemon watches the correct review directory (shared root) and consumes `comms/supervisor/inbox`.

---

## Component 5: lib/circuit-breaker.sh

### Current implementation status
Implemented per-model circuit breaker with CLOSED/OPEN/HALF_OPEN state and file-based persistence.

### What works
- Atomic state updates, cooldown handling, half-open probing (`lib/circuit-breaker.sh:132`).
- Success/failure recording and state transitions (`lib/circuit-breaker.sh:228`, `lib/circuit-breaker.sh:295`).
- Query helpers and reset functions (`lib/circuit-breaker.sh:396`, `lib/circuit-breaker.sh:515`).

### What is broken or missing
- Not integrated anywhere in worker/supervisor routing. Self-healing is not active.
- File-based breaker state is not mirrored to SQLite `breakers` table for global visibility.
- Config loader (`load_breaker_config`) is never invoked.

### Exact code changes needed
- `bin/tri-agent-worker:670` integrate `should_call_model` + `record_success`/`record_failure` around all model calls.
- `lib/circuit-breaker.sh:546` call `load_breaker_config` during common initialization or worker startup.
- `lib/circuit-breaker.sh` add optional SQLite sync (write to `breakers` table) after each state update.

---

## Priority Order for Implementation (P0 -> P2)

P0 (must fix to enable 24/7 autonomous flow):
1) Unify AUTONOMOUS_ROOT across worker/supervisor/approver to remove queue split. (Worker: `bin/tri-agent-worker:57`, Supervisor: `bin/tri-agent-supervisor:30`, Approver: `lib/supervisor-approver.sh:43`)
2) Fix quality gate runner to actually execute checks (`lib/supervisor-approver.sh:701`).
3) Wire supervisor to review queue + approval workflow (Supervisor main loop) and process worker messages (`bin/tri-agent-supervisor:330`).

P1 (correct routing and pool stability):
4) Add shard/model filtering or SQLite-based claiming in worker (`bin/tri-agent-worker:342`, `bin/tri-agent-worker:640`).
5) Add worker heartbeat/state updates to SQLite and auto-respawn in pool (`lib/worker-pool.sh:186`, `lib/worker-pool.sh:237`).
6) Update approver to persist approval results to SQLite and move tasks to COMPLETED (`lib/supervisor-approver.sh:1005`).

P2 (self-healing + 5-phase enforcement):
7) Integrate circuit breaker in model execution and add fallback routing (`bin/tri-agent-worker:670`, `lib/circuit-breaker.sh:132`).
8) Add SDLC phase enforcement (Brainstorm/Document/Plan/Execute/Track) in worker + supervisor; store phase state in task metadata and SQLite.

---

## Estimated Complexity (rough)

- P0.1 Unify root across components: S (1-2 hours)
- P0.2 Fix quality gate runner: M (2-4 hours)
- P0.3 Supervisor review + approval wiring: M (4-8 hours)
- P1.4 Shard/model filtering + SQLite claiming: L (1-2 days)
- P1.5 Pool auto-respawn + worker heartbeat updates: M (4-8 hours)
- P1.6 Approver persistence + completed transitions: S (2-4 hours)
- P2.7 Circuit breaker integration + fallback routing: M (4-8 hours)
- P2.8 SDLC 5-phase enforcement and state machine: L (2-4 days)

---

## Notes
- The fastest path to a working autonomous loop is to align on a single queue backend (filesystem or SQLite). If SQLite is chosen, add a sync/claim layer and migrate the worker to consume from it.
- Avoid partial fixes that only update one component; the queue root mismatch is a systemic blocker.
