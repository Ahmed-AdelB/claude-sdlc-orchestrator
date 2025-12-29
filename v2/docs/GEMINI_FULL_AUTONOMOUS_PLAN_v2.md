# Gemini's Comprehensive Plan for the Autonomous SDLC Orchestrator v2

**Version:** 2.0
**Date:** 2025-12-28
**Author:** Gemini (Architect)

## 0. Executive Summary

This document outlines a comprehensive architectural plan to evolve the existing SDLC Orchestrator into a fully autonomous, 24/7, self-healing Tri-Agent system. The current foundation is strong, with many key components already prototyped as shell scripts. This plan formalizes the architecture, defines the remaining work, and provides a clear implementation path.

The core of this evolution is to move from a script-based system to a robust, daemonized service-oriented architecture, with clear separation of concerns, resilient state management, and a sophisticated consensus mechanism for quality control.

---

## 1. System Architecture

The proposed architecture is composed of several key services that communicate via a shared filesystem message bus and a central SQLite state database.

### 1.1. High-Level Component Diagram

This diagram illustrates the primary services and their interactions.

```ascii
+------------------------+      Reads      +-----------------+      Picks Task     +----------------------+
|     Task Queue         | <---------------|  Task Ingestion | <-------------------|  Human / API Client  |
| (tasks/queue/*.md)     |                 |  (External)     |                     +----------------------+
+------------------------+      Writes     +-----------------+
        |
        | 1. Picks up New Task
        v
+------------------------+
|  Tri-Agent Supervisor  |
| (tri-agent-supervisor) |-----------+
+------------------------+           |
        | 2. Routes Task             | 3. Monitors & Manages
        |                            |
        v                            v
+------------------------+   +------------------------+   +------------------------+
|    Claude (Architect)  |   |    Codex (Implementer) |   |    Gemini (Reviewer)   |
|  (tri-agent-worker)    |   |  (tri-agent-worker)    |   |  (tri-agent-worker)    |
+------------------------+   +------------------------+   +------------------------+
        | 4. Performs Work &          ^
        |    Submits for Review       |
        v                             | 5. Consensus & Approval
+------------------------+            |
| Task Review Directory  |------------+
| (tasks/review/)        |
+------------------------+
        |
        | 6. Approved
        v
+------------------------+
|  Completed Tasks       |
| (tasks/completed/)     |
+------------------------+

+-----------------------------------------------------------------------------------+
| Shared Services & State                                                           |
|                                                                                   |
| +-----------------+   +------------------+   +-------------------+   +-----------+ |
| |   SQLite DB     |   |   Logging        |   |   Cost Tracker    |   |  Circuit  | |
| | (state/*.sqlite)|   |   (logs/)        |   | (cost-tracker.sh) |   |  Breaker  | |
| +-----------------+   +------------------+   +-------------------+   +-----------+ |
|                                                                                   |
+-----------------------------------------------------------------------------------+
```

### 1.2. Service Breakdown

*   **Tri-Agent Supervisor (`tri-agent-supervisor`):** The master daemon. It's a persistent process that monitors the task queue, routes tasks, manages the worker lifecycle, and orchestrates the consensus protocol. It replaces the current cron-based `monitor.sh`.
*   **Tri-Agent Worker (`tri-agent-worker`):** A generic worker process. When the Supervisor assigns it a task, it assumes a "personality" (Claude, Codex, or Gemini) based on the routing decision and executes the task using the appropriate delegate script (`claude-delegate`, `codex-delegate`, `gemini-delegate`).
*   **State Database (`state/orchestrator.sqlite`):** A central SQLite database to manage all state, replacing the current file-based state system (e.g., `state/locks/`, `state/retries/`). This provides transactional integrity and simplifies state management.
*   **Message Bus (Filesystem):** The existing filesystem structure (`tasks/queue`, `tasks/review`, etc.) will be maintained as the primary message bus for inter-service communication. This is simple, observable, and leverages the strengths of the current design.
*   **Self-Healing Services:**
    *   **Budget Watchdog (`budget-watchdog`):** Monitors the cost tracking logs and can trigger a system-wide pause via the Circuit Breaker if costs exceed thresholds.
    *   **Process Reaper (`process-reaper`):** Kills zombie or runaway agent processes that exceed their TTL.
    *   **Circuit Breaker (`circuit-breaker.sh`):** Provides a global mechanism to halt or gracefully degrade system operations. It will be controlled via state flags in the SQLite database.

---

## 2. Task Lifecycle State Machine

A task progresses through a well-defined set of states, managed by the Supervisor and recorded in the `tasks` table of the SQLite database.

```ascii
             +-----------+
        +---->  FAILED   |
        |    +-----------+
        |          ^
        |          | Processing Error /
        |          | Max Retries Reached
        |          |
+-------+---+      +-------------+       +-----------+       +----------+
|  PENDING  |----->|   ROUTING   |------>| ASSIGNED  |------>|  PHASE_1 | Brainstorming (Claude)
+-----------+ 1.   +-------------+  2.   +-----------+  3.   +----------+
New task in          Supervisor             Worker                  |
`tasks/queue`        selects agent          process                 | 4. Work Submitted
                     & phase                spawned                 |
                                                                    v
+-----------+      +-------------+       +-----------+       +----------+
| REJECTED  |<-----+   REVIEW    |<------+  PHASE_2 | Documentation (Claude/Gemini)
+-----------+ 9.   +-------------+  8.   +-----------+       +----------+
Consensus Failed     Tri-Supervisor         Work                    |
                     Consensus              Submitted               | 5.
                                                                    v
                                                               +----------+
                                                               |  PHASE_3 | Planning (Claude/Gemini)
                                                               +----------+
                                                                    |
                                                                    | 6.
                                                                    v
                                                               +----------+
                                                               |  PHASE_4 | Execution (Codex)
                                                               +----------+
                                                                    |
                                                                    | 7.
                                                                    v
                                                               +----------+
                                                               |  PHASE_5 | Tracking (Gemini)
                                                               +----------+
                                                                    ^
                                                                    |
+-------------+                                                     |
|  COMPLETED  |<----------------------------------------------------+ 10. Final Review Approved
+-------------+

```

**States:**
*   **PENDING:** A new task file exists in `tasks/queue`.
*   **ROUTING:** Supervisor is analyzing the task to determine the agent and phase.
*   **ASSIGNED:** Task assigned to a worker; process is being spawned.
*   **PHASE_1..5:** Worker is actively executing the task for a specific SDLC phase.
*   **REVIEW:** Work for a phase is complete and submitted. The three Supervisor instances are performing quality checks and voting.
*   **COMPLETED:** Task has passed all phases and final review.
*   **REJECTED:** A phase failed the review consensus. The task may be moved to `tasks/rejected` or re-queued for another attempt.
*   **FAILED:** An unrecoverable processing error occurred, or the task exceeded its max retry count.

---

## 3. SDLC Phase Enforcement Design

The Supervisor will enforce the 5-phase SDLC by managing the task's state and verifying artifacts at each stage.

**Table: SDLC Phases & Gates**

| Phase       | Agent(s)          | Primary Action                                     | Gate / Artifact Required for Next Phase                        |
|-------------|-------------------|----------------------------------------------------|----------------------------------------------------------------|
| 1. Brainstorm | Claude            | Analyze task, explore solutions, define scope.     | `docs/TASK_ID_BRAINSTORM.md` with high-level approach.         |
| 2. Document   | Claude, Gemini    | Create detailed specifications, architecture docs. | `docs/TASK_ID_SPEC.md`, `docs/TASK_ID_ARCH.md`. Gemini review. |
| 3. Plan       | Claude, Gemini    | Generate a detailed, step-by-step implementation plan. | `tasks/TASK_ID_PLAN.md` with file modifications & commands.     |
| 4. Execute    | Codex             | Write/modify code, generate unit tests.            | Pull Request / diff file. `tests/` updated. All tests pass.    |
| 5. Track      | Gemini            | Verify completion, update status docs, create report. | `docs/TASK_ID_REPORT.md`, `IMPLEMENTATION-STATUS.md` updated.  |

**Enforcement Logic (`tri-agent-supervisor`):**

1.  When a task is in state `PHASE_N`, the supervisor dispatches it to the appropriate agent.
2.  The agent completes its work and places the required artifacts in the specified locations. It then moves the task file to `tasks/review/TASK_ID_PHASE_N.md`.
3.  The supervisor detects the new review request. It initiates the **Tri-Agent Consensus Protocol**.
4.  If consensus is `APPROVE`, the supervisor updates the task state to `PHASE_N+1` in the database and moves the task file back to the `tasks/running/` directory (or its equivalent), ready for the next phase.
5.  If consensus is `REJECT`, the supervisor updates state to `REJECTED`, logs the reasons, and moves the task to `tasks/rejected/`.
6.  This cycle repeats until `PHASE_5` is approved, at which point the state becomes `COMPLETED`.

---

## 4. Tri-Agent Consensus Protocol

To ensure quality and prevent single-agent failure or hallucination, a 3-supervisor consensus mechanism will be used for all quality gates. This is an evolution of the `tri-agent-consensus` script.

**Protocol Steps:**

1.  **Initiation:** When a task enters the `REVIEW` state, the main Supervisor daemon creates a consensus request in the database, linking it to the task and phase.
2.  **Distribution:** The Supervisor spawns three independent, isolated "approver" instances of itself. Each instance is assigned a primary model (Claude, Codex, Gemini) for its "perspective".
3.  **Evaluation:** Each approver instance independently evaluates the artifacts for the phase being reviewed.
    *   It runs a battery of validation scripts (`tri-agent-quality`, `tri-agent-lint`, `tri-agent-coverage`).
    *   It uses its assigned primary model to perform a qualitative review (e.g., "Does this code meet the plan's requirements?").
    *   It generates a structured `vote.json` file with its decision (`APPROVE`/`REJECT`), confidence score, and rationale.
4.  **Tallying:** The main Supervisor collects the three `vote.json` files.
5.  **Decision:**
    *   **Unanimous Approval (3/3):** The task is automatically approved and moves to the next phase.
    *   **Majority Approval (2/3):** The task is approved, but the dissenting opinion is logged as a warning and flagged for potential future review.
    *   **Majority/Unanimous Rejection (0/3 or 1/3):** The task is rejected. The reasons from the majority are logged, and the task is moved to the `rejected` state.

**ASCII Flow:**

```ascii
+-----------------------------+
| Task Artifacts in           |
| `tasks/review/`             |
+-----------------------------+
              |
              v
+-----------------------------+
| Supervisor (Master)         |
| Creates consensus job in DB |
+-----------------------------+
              |
              +----------------------------+-----------------------------+
              |                            |                             |
              v                            v                             v
+-------------+-----------+  +-------------+-----------+   +-------------+-----------+
| Approver 1 (Claude)     |  | Approver 2 (Codex)      |   | Approver 3 (Gemini)     |
| - Runs validation scripts |  - Runs validation scripts |   - Runs validation scripts |
| - Performs qualitative review |  - Performs qualitative review |   - Performs qualitative review |
| - Writes vote1.json       |  - Writes vote2.json       |   - Writes vote3.json       |
+-------------------------+  +-------------------------+   +-------------------------+
              |                            |                             |
              +----------------------------+-----------------------------+
              |
              v
+-----------------------------+
| Supervisor (Master)         |
| - Collects 3 votes          |
| - Tallies result (>= 2/3?)  |
+-----------------------------+
              |
      +-------+--------+
      |                |
      v                v
+-----------+    +-------------+
|  APPROVE  |    |   REJECT    |
+-----------+    +-------------+

```

---

## 5. Self-Healing Mechanisms

The system must be resilient to failure. This will be achieved by formalizing and integrating the existing self-healing scripts.

*   **Stateful Retries:**
    *   The `tasks` table in SQLite will have a `retry_count` column.
    *   When a worker fails, the Supervisor will catch the non-zero exit code, log the error, increment `retry_count`, and re-queue the task if `retry_count` < `MAX_RETRIES` (a configurable value).
    *   This replaces ephemeral, file-based retry logic.

*   **Circuit Breaker (`lib/circuit-breaker.sh`):**
    *   A new `system_status` table will be created in SQLite with flags like `master_switch` (`ENABLED`/`DISABLED`), `cost_alert` (`true`/`false`).
    *   The `budget-watchdog` service will update `cost_alert` to `true` if spending limits are breached.
    *   The Supervisor will check these flags at the start of its main loop. If the `master_switch` is `DISABLED` or `cost_alert` is `true`, it will pause all new task processing.
    *   A new admin tool (`tri-agent-admin`) will provide a CLI to manually flip these switches for maintenance.

*   **Process Reaper (`bin/process-reaper`):**
    *   This will run as a separate, simple daemon.
    *   When the Supervisor spawns a worker, it records the worker's PID and a TTL in a `worker_processes` table in SQLite.
    *   The Process Reaper periodically scans this table. If a process's age exceeds its TTL, the reaper kills the process and its process group, and marks it as `REAPED` in the database.
    *   The Supervisor, on its next cycle, will see the `REAPED` status and handle it as a standard task failure (incrementing the retry count).

---

## 6. Files to Create/Modify

This section details the most critical changes.

1.  **Create `state/orchestrator.sqlite` (and schema):**
    *   **File:** `config/schema.sql`
    *   **Content:**
        ```sql
        -- Defines the schema for the central state database.
        CREATE TABLE tasks (
            task_id TEXT PRIMARY KEY,
            status TEXT NOT NULL,
            current_phase INTEGER NOT NULL,
            retry_count INTEGER NOT NULL DEFAULT 0,
            assigned_worker_pid INTEGER,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE worker_processes (
            pid INTEGER PRIMARY KEY,
            task_id TEXT NOT NULL,
            started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            ttl_seconds INTEGER NOT NULL,
            status TEXT NOT NULL -- e.g., RUNNING, REAPED
        );

        CREATE TABLE system_status (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        INSERT INTO system_status (key, value) VALUES ('master_switch', 'ENABLED');
        INSERT INTO system_status (key, value) VALUES ('cost_alert', 'false');

        CREATE TABLE consensus_votes (
            vote_id INTEGER PRIMARY KEY AUTOINCREMENT,
            task_id TEXT NOT NULL,
            phase INTEGER NOT NULL,
            approver_model TEXT NOT NULL,
            vote TEXT NOT NULL, -- APPROVE / REJECT
            rationale TEXT,
            voted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        ```

2.  **Modify `bin/tri-agent-supervisor`:**
    *   **Action:** Convert from a transient script to a persistent daemon.
    *   **Logic:**
        ```bash
        #!/bin/bash
        # tri-agent-supervisor - Main orchestrator daemon

        source "$(dirname "$0")/../lib/common.sh"
        source "$(dirname "$0")/../lib/sqlite-state.sh" # NEW library for DB interactions

        main_loop() {
            while true; do
                # 1. Check Circuit Breaker
                if ! is_system_enabled; then
                    log_warn "System is paused by circuit breaker. Standing by."
                    sleep 60
                    continue
                fi

                # 2. Process tasks in review (highest priority)
                process_review_queue

                # 3. Process new tasks
                process_new_task_queue

                # 4. Cleanup/Check on running tasks
                check_running_tasks

                sleep 10
            done
        }

        process_new_task_queue() {
            local task_file=$(find "$TASK_QUEUE_DIR" -name "*.md" | head -n 1)
            if [[ -n "$task_file" ]]; then
                local task_id=$(basename "$task_file" .md)
                log_info "New task found: $task_id"

                # Create record in DB, route, and assign
                db_create_task "$task_id"
                route_and_assign_task "$task_id"
                mv "$task_file" "$TASK_RUNNING_DIR/$task_id.md"
            fi
        }

        # ... functions for process_review_queue, check_running_tasks, etc.

        main_loop
        ```

3.  **Create `lib/sqlite-state.sh`:**
    *   **Action:** Centralize all database interactions.
    *   **Content:**
        ```bash
        #!/bin/bash
        # Library for interacting with the orchestrator.sqlite database

        DB_PATH="$STATE_DIR/orchestrator.sqlite"

        # Function to query the DB
        db_query() {
            sqlite3 "$DB_PATH" "$1"
        }

        # Function to check system status
        is_system_enabled() {
            local master=$(db_query "SELECT value FROM system_status WHERE key = 'master_switch';")
            local cost=$(db_query "SELECT value FROM system_status WHERE key = 'cost_alert';")
            [[ "$master" == "ENABLED" && "$cost" == "false" ]]
        }

        # Function to create a task
        db_create_task() {
            local task_id=$1
            db_query "INSERT INTO tasks (task_id, status, current_phase) VALUES ('$task_id', 'PENDING', 0);"
        }

        # ... more functions for updating status, incrementing retries, managing workers etc.
        ```

4.  **Modify `bin/tri-agent-worker`:**
    *   **Action:** Adapt to be spawned by the supervisor with specific context.
    *   **Logic:**
        ```bash
        #!/bin/bash
        # Generic worker, spawned by the supervisor.

        TASK_ID=$1
        AGENT_PERSONALITY=$2 # claude, codex, or gemini
        PHASE=$3

        source "$(dirname "$0")/../lib/common.sh"
        source "$(dirname "$0")/../lib/sqlite-state.sh"

        cleanup() {
            # Error handling and cleanup
            db_update_task_status "$TASK_ID" "FAILED"
            # ...
        }
        trap cleanup ERR

        log_info "Worker PID $$ starting task $TASK_ID as $AGENT_PERSONALITY for phase $PHASE"
        db_update_task_status "$TASK_ID" "PHASE_$PHASE"
        db_register_worker_process "$$" "$TASK_ID" 7200 # 2 hour TTL

        # Delegate to the correct script
        case "$AGENT_PERSONALITY" in
            claude)
                "$(dirname "$0")/claude-delegate" --task_id "$TASK_ID" --phase "$PHASE"
                ;;
            codex)
                "$(dirname "$0")/codex-delegate" --task_id "$TASK_ID" --phase "$PHASE"
                ;;
            gemini)
                "$(dirname "$0")/gemini-delegate" --task_id "$TASK_ID" --phase "$PHASE"
                ;;
        esac

        log_info "Worker finished task $TASK_ID for phase $PHASE. Submitting for review."
        db_update_task_status "$TASK_ID" "REVIEW"
        mv "$TASK_RUNNING_DIR/$TASK_ID.md" "$TASK_REVIEW_DIR/${TASK_ID}_PHASE_${PHASE}.md"
        db_unregister_worker_process "$$"

        exit 0
        ```

---

## 7. Implementation Priority Order

This roadmap outlines the sequence of implementation to achieve the v2 architecture.

1.  **Phase 1: Foundational State Management**
    *   **Goal:** Replace file-based state with the central SQLite database.
    *   Implement `config/schema.sql` and `lib/sqlite-state.sh`.
    *   Modify existing scripts (`state.sh`, `lib/locks/` dependent scripts) to use the new DB library. This is a critical, large-scale refactoring.

2.  **Phase 2: Supervisor Daemonization**
    *   **Goal:** Convert the Supervisor into a persistent service.
    *   Refactor `bin/tri-agent-supervisor` into the daemonized loop structure.
    *   Create a systemd service file (`config/tri-agent-supervisor.service`) to manage the daemon.
    *   Integrate the supervisor with the new SQLite state for task tracking.

3.  **Phase 3: Worker Lifecycle Management**
    *   **Goal:** Enable the Supervisor to spawn and manage workers.
    *   Refactor `bin/tri-agent-worker` to accept context from the supervisor.
    *   Implement the `worker_processes` table logic in the supervisor and the worker.

4.  **Phase 4: Implement Self-Healing Services**
    *   **Goal:** Formalize the self-healing components as daemons.
    *   Refactor `bin/process-reaper` to run as a daemon, using the DB for its source of truth.
    *   Refactor `bin/budget-watchdog` to run as a daemon and interact with the Circuit Breaker flags in the DB.
    *   Solidify the circuit breaker logic in the Supervisor's main loop.

5.  **Phase 5: Consensus Protocol Integration**
    *   **Goal:** Fully integrate the tri-agent consensus mechanism.
    *   Implement the `consensus_votes` table and the logic for the supervisor to spawn, manage, and tally votes from the approver instances.
    *   Refine the validation scripts (`tri-agent-quality`, etc.) to be callable by the approvers.

6.  **Phase 6: Final Polish and Activation**
    *   **Goal:** Clean up, remove old scripts, and go live.
    *   Remove the old cron-based `monitor.sh` and other redundant scripts.
    *   Perform a full integration test of the end-to-end flow.
    *   Update documentation (`README.md`, `ARCHITECTURE.md`) to reflect the new service-oriented architecture.
    *   Flip the master switch.
