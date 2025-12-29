# GEMINI'S AUTONOMOUS SDLC ARCHITECTURE PLAN v1.0

**Author**: Gemini 3 Pro (1M Token Context)
**Date**: 2025-12-28
**Based on**: Analysis of `v2` codebase and `FINAL_SDLC_SPLIT_SPECIFICATION_v5.md`
**Goal**: Design the 24/7 Autonomous Orchestrator

---

## 1. SYSTEM ARCHITECTURE

The system transforms from a single-threaded loop to a multi-agent, event-driven architecture backed by SQLite WAL mode.

```ascii
                                  ┌──────────────────┐
                                  │   USER / GITHUB  │
                                  └────────┬─────────┘
                                           │ (New Task/Issue)
                                           ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                            AUTONOMOUS SUPERVISOR                             │
│ ┌──────────────┐     ┌──────────────┐     ┌──────────────┐    ┌────────────┐ │
│ │  TASK INTAKE │────▶│  PRIORITIZER │────▶│  DISPATCHER  │───▶│ WATCHDOG   │ │
│ └──────────────┘     └──────┬───────┘     └──────┬───────┘    └─────┬──────┘ │
│                             │                    │ (Claim)          │ (Kill) │
└─────────────────────────────┼────────────────────┼──────────────────┼────────┘
                              │                    │                  │
                              ▼                    ▼                  ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                              STATE LAYER (SQLite)                            │
│ ┌─────────┐  ┌─────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐ ┌────────┐ │
│ │  TASKS  │  │ EVENTS  │  │ CONTEXT  │  │ FAILURES │  │ METRICS │ │ LOCKS  │ │
│ └─────────┘  └─────────┘  └──────────┘  └──────────┘  └─────────┘ └────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
           ▲                  ▲                    ▲                  ▲
           │ (Read/Write)     │ (RAG Query)        │ (Log Error)      │ (Heartbeat)
           │                  │                    │                  │
┌──────────┼──────────────────┼────────────────────┼──────────────────┼────────┐
│          │                  │   WORKER POOL      │                  │        │
│ ┌────────┴──────┐    ┌──────┴────────┐    ┌──────┴────────┐  ┌──────┴──────┐ │
│ │   WORKER 1    │    │   WORKER 2    │    │   WORKER 3    │  │   REAPER    │ │
│ │ (Fast Lane)   │    │ (Medium Lane) │    │ (Slow Lane)   │  │   DAEMON    │ │
│ │ Lint/Review   │    │ Implement/Fix │    │ Test/Coverage │  │   Cleanup   │ │
│ └───────┬───────┘    └──────┬────────┘    └──────┬────────┘  └─────────────┘ │
│         │                   │                    │                           │
│         ▼                   ▼                    ▼                           │
│  ┌────────────┐      ┌────────────┐       ┌────────────┐                     │
│  │ CLAUDE OPUS│      │ CODEX XHIGH│       │ GEMINI PRO │                     │
│  └────────────┘      └────────────┘       └────────────┘                     │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. TASK LIFECYCLE FLOW

The system enforces a rigorous state machine to ensure no task is lost or stuck.

### States
1.  **QUEUED**: Task accepted, prioritized, waiting for worker.
2.  **RUNNING**: Worker claimed task, heartbeat active.
3.  **REVIEW**: Work output generated, waiting for Supervisor Gates.
4.  **APPROVED**: Supervisor Gates passed + Consensus achieved.
5.  **REJECTED**: Gates failed or Consensus veto. Returns to QUEUED (with feedback).
6.  **COMPLETED**: Merged and verified.
7.  **FAILED**: Max retries exceeded.
8.  **ESCALATED**: Human intervention required (P0 failure).

### Flow Logic
1.  **Intake**: Task file created `tasks/queue/XXXX_description.md` -> Parsed -> SQLite `QUEUED`.
2.  **Dispatch**: Worker queries SQLite for `QUEUED` tasks matching its lane capability.
3.  **Execution**:
    *   Worker transitions task to `RUNNING`.
    *   Worker updates `last_heartbeat` every minute.
    *   Worker executes SDLC phases (see Section 3).
4.  **Review**:
    *   Worker transitions to `REVIEW`.
    *   Supervisor (Claude) triggers `gate_check`.
    *   Tri-Agent Consensus (Claude+Gemini+Codex) votes.
5.  **Completion**:
    *   If Vote > 2/3 AND Gates == PASS -> `APPROVED`.
    *   Else -> `REJECTED` (Retry count + 1).

---

## 3. SDLC PHASE ENFORCEMENT

The worker **MUST** step through these phases sequentially. The `state` table in SQLite will track the sub-state `phase`.

| Phase | Action | Output Artifact | Exit Criteria |
|-------|--------|-----------------|---------------|
| **1. Brainstorm** | Analyze task, query RAG, check architecture. | `plan.md` | Plan approved by Supervisor. |
| **2. Document** | Create/Update specs, test plans. | `spec.md`, `test_plan.md` | Files exist and pass lint. |
| **3. Plan** | Break down into atomic steps. | `steps.json` | JSON valid, steps < 10. |
| **4. Execute** | Write code, run local tests. | Source files | Code compiles, unit tests pass. |
| **5. Track** | Verify against requirements, record metrics. | `result.json` | All requirements checked. |

**Enforcement**: The Worker script (`tri-agent-worker`) will not proceed to the next phase until the `supervisor-approver` validates the artifact of the current phase.

---

## 4. TRI-AGENT CONSENSUS PROTOCOL

To ensure 24/7 reliability without human oversight, we rely on **Model Diversity**.

### Voting Logic
*   **Claude Opus**: Focuses on **Security** and **Architecture** (System integrity).
*   **Gemini Pro**: Focuses on **Completeness** and **Edge Cases** (1M token scan).
*   **Codex**: Focuses on **Correctness** and **Implementation** (Code logic).

### Protocol
1.  **Proposal**: Worker submits `diff` + `summary` to Consensus Engine.
2.  **Parallel Evaluation**:
    *   Claude: "Does this break the architecture?"
    *   Gemini: "Did we miss any files in this massive repo?"
    *   Codex: "Is this code bug-free?"
3.  **Quorum**:
    *   **CRITICAL Tasks**: Unanimous (3/3).
    *   **STANDARD Tasks**: Majority (2/3).
    *   **TRIVIAL Tasks**: Single Approver (1/3) (usually Codex).
4.  **Veto**: Claude has veto power on Security violations.

---

## 5. SUPERVISOR AUTO-APPROVAL LOGIC

The Supervisor is a specialized agent (running Claude Opus) that runs purely to validate quality gates.

### Quality Gates (Automated)
1.  **Syntax/Lint**: `npm run lint` / `ruff check` must pass.
2.  **Types**: `tsc --noEmit` / `mypy` must pass.
3.  **Tests**: `npm test` / `pytest` must pass.
4.  **Coverage**: Must not decrease below 80%.
5.  **Security**: `snyk test` (or equivalent) must pass.
6.  **Budget**: Cost < $Limit for the task.

### Auto-Approval Trigger
If (Gates == PASS) AND (Consensus == ACHIEVED) THEN:
*   `git commit -am "feat: ..."`
*   `git push`
*   Mark task `COMPLETED`
*   Move file to `tasks/completed/`

---

## 6. SELF-HEALING & RESILIENCE

### Components
1.  **Watchdog (Cron/Systemd)**: Checks if `tri-agent-supervisor` is running. Restarts if down.
2.  **Reaper Daemon**:
    *   Scans for `RUNNING` tasks with `last_heartbeat` > Timeout (e.g., 30m).
    *   Kills the corresponding Worker process.
    *   Resets task to `QUEUED` (increments retry count).
3.  **Circuit Breaker**:
    *   If a specific Task Type fails 3x consecutively -> Open Circuit (stop processing that type).
    *   If API Error Rate > 5% -> Pause System (Wait 10m).
4.  **Budget Governor**:
    *   Checks API spend every minute.
    *   If Spend > $1/min -> Kill Switch (PAUSE system).

---

## 7. MONITORING REQUIREMENTS

We will use the existing Prometheus setup (`monitoring/prometheus.yml`) to track:

### Metrics
1.  `sdlc_queue_depth`: Number of tasks in QUEUED.
2.  `sdlc_task_duration_seconds`: Histogram of completion times.
3.  `sdlc_failure_rate`: Rate of REJECTED/FAILED tasks.
4.  `sdlc_cost_total`: Cumulative API cost.
5.  `sdlc_consensus_disagreement`: Count of split votes (indicates ambiguity).

### Logs
*   Structured JSON logs in `logs/sessions/` for every state transition and API call.
*   Trace IDs passed through all agents for full observability.

---

## NEXT STEPS
1.  Migrate `task-queue.sh` to use SQLite (Week 1).
2.  Implement `tri-agent-supervisor` loop (Week 1).
3.  Deploy `reaper` daemon (Week 2).
