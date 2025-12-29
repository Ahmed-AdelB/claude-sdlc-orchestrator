# FINAL SDLC Split Specification: Autonomous Dual 24-Hour Tri-Agent System

**Version**: 3.0 FINAL
**Date**: 2025-12-28
**Status**: APPROVED FOR IMPLEMENTATION
**Consolidated From**:
- Claude Opus: MASTER_IMPLEMENTATION_PLAN_v2.md (1,870 lines)
- Claude Opus: SUPERVISOR_IMPLEMENTATION_SPEC.md (1,737 lines)
- Gemini 3 Pro: GEMINI_ARCHITECTURE_REVIEW.md (Critical gaps analysis)
- Gemini 3 Pro: GEMINI_TESTING_FRAMEWORK.md (Testing framework)
- Codex: PHASE_HANDOFF_SPEC.md (Handoff protocols)
- 14+ parallel agents across Claude, Codex, and Gemini

---

## Executive Summary

This specification defines a **production-ready autonomous SDLC system** where:
- **Two 24-hour tri-agent sessions** operate continuously
- **Supervisor Agent**: Owns requirements, planning, quality gates, approval/rejection
- **Worker Agent**: Owns implementation, testing, submission
- **Quality is FORCED**: 12 automated checks, 80% coverage, tri-agent consensus
- **No human intervention required** except for escalations

---

## 1. DUAL 24-HOUR SESSION ARCHITECTURE

### 1.1 Session Split

```
┌────────────────────────────────────────────────────────────────────────────┐
│                        CONTINUOUS 24/7 OPERATION                           │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  ┌─────────────────────────────┐    ┌─────────────────────────────┐      │
│  │   SESSION 1: SUPERVISOR     │◄──►│     SESSION 2: WORKER       │      │
│  │   (24-hour tmux session)    │    │   (24-hour tmux session)    │      │
│  ├─────────────────────────────┤    ├─────────────────────────────┤      │
│  │ Model: Claude Opus 4.5      │    │ Model: Claude Opus 4.5      │      │
│  │ Thinking: 32K ultrathink    │    │ Thinking: 32K ultrathink    │      │
│  │ Delegation: Gemini (1M ctx) │    │ Delegation: Codex (impl)    │      │
│  └─────────────────────────────┘    └─────────────────────────────┘      │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐│
│  │                    SHARED FILE-BASED IPC                              ││
│  │  comms/supervisor/inbox/  ◄────────────►  comms/worker/inbox/        ││
│  │  tasks/queue/             ◄────────────►  tasks/running/             ││
│  │  tasks/review/            ◄────────────►  tasks/approved/rejected/   ││
│  └──────────────────────────────────────────────────────────────────────┘│
└────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 SDLC Phase Ownership Matrix

| SDLC Phase    | Primary Owner  | Secondary Role   | Model Delegation      | Quality Gate |
|---------------|----------------|------------------|-----------------------|--------------|
| **BRAINSTORM**| SUPERVISOR     | Worker: Context  | Gemini (1M context)   | Gate 1       |
| **DOCUMENT**  | COLLABORATIVE  | Worker: Draft    | Gemini (documentation)| Gate 2       |
| **PLAN**      | SUPERVISOR     | Worker: Estimate | Claude Opus (arch)    | Gate 3       |
| **EXECUTE**   | WORKER         | Supervisor: QA   | Codex (implementation)| Gate 4       |
| **TRACK**     | SUPERVISOR     | Worker: Report   | Gemini (analysis)     | Gate 5       |

---

## 2. FORCED QUALITY GATES (12 CHECKS)

### 2.1 Gate 4: Execute → Approved (CRITICAL)

All 12 checks MUST pass for autonomous approval:

| Check ID | Check Name              | Implementation              | Pass Threshold    | Blocking |
|----------|-------------------------|-----------------------------|--------------------|----------|
| EXE-001  | Test Suite Execution    | `npm test` / `pytest`       | 100% pass          | YES      |
| EXE-002  | Test Coverage           | Coverage report             | ≥ 80%              | YES      |
| EXE-003  | Linting                 | ESLint / Ruff               | Zero errors        | YES      |
| EXE-004  | Type Checking           | tsc --noEmit / mypy         | Zero errors        | YES      |
| EXE-005  | Security Scan           | npm audit / bandit          | Zero critical/high | YES      |
| EXE-006  | Build Success           | Build command               | Exit code 0        | YES      |
| EXE-007  | Dependency Audit        | Vulnerable deps check       | Zero critical      | YES      |
| EXE-008  | Breaking Change Check   | API surface comparison      | None OR documented | YES      |
| EXE-009  | Tri-Agent Code Review   | Claude + Codex + Gemini     | ≥ 2/3 approve      | YES      |
| EXE-010  | Performance Benchmarks  | Perf tests if applicable    | Within ±10%        | NO       |
| EXE-011  | Documentation Updated   | README/CHANGELOG check      | Updated if needed  | NO       |
| EXE-012  | Commit Message Format   | Conventional commits        | Valid format       | YES      |

### 2.2 Tri-Agent Consensus (EXE-009)

```
┌────────────────────────────────────────────────────────────────────────────┐
│                        TRI-AGENT CODE REVIEW                               │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│    ┌─────────────┐     ┌─────────────┐     ┌─────────────┐               │
│    │   CLAUDE    │     │   CODEX     │     │   GEMINI    │               │
│    │  (Logic &   │     │  (Bugs &    │     │ (Security & │               │
│    │  Architect) │     │ Edge Cases) │     │ Performance)│               │
│    └──────┬──────┘     └──────┬──────┘     └──────┬──────┘               │
│           │                   │                   │                       │
│           ▼                   ▼                   ▼                       │
│    ┌─────────────────────────────────────────────────────────────────┐   │
│    │              CONSENSUS VOTING: ≥ 2/3 Required                    │   │
│    │                                                                  │   │
│    │  • APPROVE + APPROVE + APPROVE = PASS                           │   │
│    │  • APPROVE + APPROVE + REJECT  = PASS                           │   │
│    │  • APPROVE + REJECT  + REJECT  = FAIL                           │   │
│    │  • REJECT  + REJECT  + REJECT  = FAIL                           │   │
│    └─────────────────────────────────────────────────────────────────┘   │
│                                                                            │
│    VETO MODE: Security-sensitive code requires ALL 3 to approve           │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. PHASE TRANSITION HANDOFFS

### 3.1 Phase 1: BRAINSTORM → DOCUMENT

**Goal**: Transform user request into concrete requirements

| Component        | Specification                                              |
|------------------|-----------------------------------------------------------|
| **Trigger**      | New task in `tasks/queue/NEW_*.md`                        |
| **Primary**      | SUPERVISOR (analyzes request, gathers context)            |
| **Secondary**    | WORKER (scans codebase for related files)                 |
| **Output**       | `docs/requirements/{task_id}_req.md`                      |
| **Quality Gate** | Gate 1: Context Completeness (goal clear, constraints def)|
| **Handoff**      | Move `NEW_{id}.md` → `DOC_{id}.md`                       |

### 3.2 Phase 2: DOCUMENT → PLAN

**Goal**: Convert requirements into technical specification

| Component        | Specification                                              |
|------------------|-----------------------------------------------------------|
| **Trigger**      | Task `DOC_*.md` in queue                                  |
| **Primary**      | WORKER (drafts specification)                             |
| **Secondary**    | SUPERVISOR (reviews and critiques)                        |
| **Output**       | `docs/specs/{id}_spec.md`                                 |
| **Quality Gate** | Gate 2: Spec Validation (acceptance criteria, test cases) |
| **Handoff**      | Move to `PLAN_{id}.md` after supervisor sign-off          |

### 3.3 Phase 3: PLAN → EXECUTE

**Goal**: Break specification into atomic executable tasks

| Component        | Specification                                              |
|------------------|-----------------------------------------------------------|
| **Trigger**      | Task `PLAN_*.md` in queue                                 |
| **Primary**      | SUPERVISOR (decomposition & planning)                     |
| **Secondary**    | WORKER (effort estimation)                                |
| **Output**       | `docs/plans/{id}_plan.md` + `EXEC_{id}_*.md` atomic tasks |
| **Quality Gate** | Gate 3: Plan Approval (tasks atomic, deps mapped, budget) |
| **Handoff**      | Atomic tasks placed in `tasks/queue/EXEC_*`               |

### 3.4 Phase 4: EXECUTE → TRACK

**Goal**: Implement code, pass tests, merge changes

| Component        | Specification                                              |
|------------------|-----------------------------------------------------------|
| **Trigger**      | Task `EXEC_*.md` in queue                                 |
| **Primary**      | WORKER (implementation via Codex)                         |
| **Secondary**    | SUPERVISOR (audit & merge)                                |
| **Output**       | Code changes (Git commit) + Test results                  |
| **Quality Gate** | Gate 4: The 12-Check Gate (ALL MUST PASS)                 |
| **Handoff**      | Move to `tasks/completed/` or `tasks/rejected/`           |

---

## 4. REJECTION & RETRY WORKFLOW

### 4.1 Retry Budget

```yaml
retry_limits:
  per_task:
    max_attempts: 3              # Maximum retries per task
    max_rejection_retries: 2     # Retries after supervisor rejection
    backoff_strategy: "linear"
    backoff_increment: 300       # 5 minutes per retry

  global:
    max_rejections_per_hour: 10
    max_rejections_per_day: 30
    pause_on_threshold: true

escalation:
  thresholds:
    - attempts: 3
      action: "notify_slack"
    - attempts: 4
      action: "pause_autonomous"
    - attempts: 5
      action: "create_github_issue"
```

### 4.2 Rejection Flow

```
SUPERVISOR detects gate failure
    ↓
Analyze root cause (which of 12 checks failed)
    ↓
Generate actionable feedback:
  - Priority order of fixes
  - Specific file:line references
  - Suggested code changes
    ↓
Create enhanced retry task with feedback
    ↓
Move to tasks/rejected/ (for audit)
    ↓
Re-queue with retry counter
    ↓
Signal worker: TASK_REJECT with feedback
    ↓
IF retries >= 3:
    → Escalate to human
    → Create GitHub issue
    → Pause autonomous mode
```

---

## 5. SAFEGUARDS & ANTI-LOOP MECHANISMS

### 5.1 Critical Safety Features (From Gemini Review)

| Issue                  | Solution                                                    |
|------------------------|-------------------------------------------------------------|
| **Dependency Deadlock**| Add `DEP_REQUEST` message type; Supervisor installs deps    |
| **IPC Race Conditions**| Write to `tmp/` first, then atomic `mv` to `inbox/`         |
| **Execution Sandbox**  | Wrap execution in Docker container (REQUIRED for prod)      |
| **Hallucination Echo** | Supervisor generates immutable acceptance tests BEFORE task |
| **Context Exhaustion** | 50KB limit on IPC payloads; use file paths for large data   |
| **Budget Runaway**     | Global cost circuit breaker; max API spend per day          |

### 5.2 Loop Prevention

```bash
# Circuit breaker configuration
CIRCUIT_BREAKER_THRESHOLD=10      # Rejections per hour
SAME_GATE_FAILURE_LIMIT=2         # Same failure type triggers strategy switch
GLOBAL_DAILY_REJECTION_LIMIT=30   # Max rejections per day

# On threshold breach:
# 1. Pause autonomous mode
# 2. Create escalation ticket
# 3. Notify human operators
```

### 5.3 Crash Recovery

1. **Heartbeats**: Every 60 seconds from both agents
2. **Stale Detection**: > 5 minutes without heartbeat = crashed
3. **Auto-Recovery**: Watchdog respawns agent
4. **Task Recovery**: In-progress tasks return to queue with "RECOVERED" status

---

## 6. FILE SYSTEM STATE MACHINE

### 6.1 Task State Transitions

```
                    ┌─────────────┐
                    │   QUEUED    │
                    └──────┬──────┘
                           │ worker_claims
                           v
                    ┌─────────────┐
              ┌─────│   RUNNING   │
              │     └──────┬──────┘
              │            │ work_completed
              │            v
              │     ┌─────────────┐
              │     │   REVIEW    │◄────────────────┐
              │     └──────┬──────┘                 │
              │            │                        │
              │     ┌──────┴──────┐                 │
              │     v             v                 │
         ┌─────────────┐   ┌─────────────┐         │
         │  APPROVED   │   │  REJECTED   │─────────┘
         └──────┬──────┘   └──────┬──────┘  retry < 3
                │                 │
                │                 v retry >= 3
                │          ┌─────────────┐
                │          │  ESCALATED  │
                │          └──────┬──────┘
                v                 │
         ┌─────────────┐         v
         │  COMPLETED  │   ┌─────────────┐
         └─────────────┘   │   FAILED    │
                           └─────────────┘
```

### 6.2 Directory Structure (Production Ready)

```
~/.claude/autonomous/
├── config/
│   ├── tri-agent.yaml           # Base configuration
│   ├── supervisor-agent.yaml    # Supervisor settings
│   ├── worker-agent.yaml        # Worker settings
│   ├── quality-gates.yaml       # Gate thresholds (12 checks)
│   └── retry-limits.yaml        # Retry and escalation config
│
├── tasks/
│   ├── queue/                   # Pending tasks (priority ordered)
│   │   ├── CRITICAL_*.md        # P0: Immediate
│   │   ├── HIGH_*.md            # P1: Same-day
│   │   ├── MEDIUM_*.md          # P2: This sprint
│   │   └── LOW_*.md             # P3: Backlog
│   ├── running/                 # Worker executing (max 1)
│   ├── review/                  # Awaiting supervisor approval
│   ├── approved/                # Passed all gates
│   ├── rejected/                # Failed with feedback
│   ├── completed/               # Successfully merged
│   ├── failed/                  # Max retries exceeded
│   └── escalations/             # Human intervention required
│
├── comms/
│   ├── supervisor/
│   │   ├── inbox/               # FROM Worker TO Supervisor
│   │   └── sent/                # Supervisor sent history
│   └── worker/
│       ├── inbox/               # FROM Supervisor TO Worker
│       └── sent/                # Worker sent history
│
├── state/
│   ├── system_state.json        # Global system state
│   ├── gates/                   # Gate evaluation results
│   ├── retries/                 # Retry counters per task
│   └── locks/                   # PID locks for crash detection
│
├── lib/
│   ├── common.sh                # Shared utilities
│   ├── worker-executor.sh       # Worker execution engine
│   ├── supervisor-approver.sh   # Approval engine (1,501 lines)
│   ├── quality-gates.sh         # Gate runners
│   └── comms.sh                 # IPC helpers
│
├── bin/
│   ├── tri-agent-supervisor     # Supervisor daemon
│   ├── tri-agent-worker         # Worker daemon (1,362 lines)
│   ├── tri-agent-consensus      # Tri-agent voting
│   ├── tri-agent-coverage       # Coverage enforcement
│   └── tri-agent-security-audit # Security scanning
│
└── logs/
    ├── ledger.jsonl             # Immutable audit trail
    ├── supervisor.log           # Supervisor debug stream
    └── worker.log               # Worker debug stream
```

---

## 7. INTER-AGENT COMMUNICATION PROTOCOL

### 7.1 Message Schema

```json
{
  "id": "UUID-v4",
  "type": "MESSAGE_TYPE",
  "source": "supervisor|worker",
  "target": "worker|supervisor",
  "timestamp": "ISO8601-UTC",
  "task_id": "TASK_ID",
  "payload": {},
  "trace_id": "tri-YYYYMMDDHHMMSS-hash"
}
```

### 7.2 Message Types

**Supervisor → Worker:**
| Type             | Description                    |
|------------------|--------------------------------|
| `TASK_ASSIGN`    | Assign task to worker          |
| `TASK_APPROVE`   | Work passed all 12 gates       |
| `TASK_REJECT`    | Work failed with feedback      |
| `DEP_APPROVED`   | Dependency install approved    |
| `CONTROL_PAUSE`  | Pause worker execution         |
| `CONTROL_RESUME` | Resume worker                  |

**Worker → Supervisor:**
| Type             | Description                    |
|------------------|--------------------------------|
| `TASK_ACCEPT`    | Acknowledged task              |
| `TASK_COMPLETE`  | Ready for review               |
| `TASK_FAIL`      | Non-recoverable error          |
| `DEP_REQUEST`    | Request dependency install     |
| `QUERY_CLARIFY`  | Need clarification             |
| `HEARTBEAT`      | Liveness signal (60s interval) |

---

## 8. STARTUP COMMANDS

### 8.1 Launch Supervisor Session (24-hour)

```bash
# Terminal 1: Start Supervisor
tmux new-session -d -s tri-agent-supervisor \
  'cd ~/.claude/autonomous && \
   bin/tri-agent-supervisor --daemon --log logs/supervisor.log'
```

### 8.2 Launch Worker Session (24-hour)

```bash
# Terminal 2: Start Worker
tmux new-session -d -s tri-agent-worker \
  'cd ~/.claude/autonomous && \
   bin/tri-agent-worker --daemon --log logs/worker.log'
```

### 8.3 Monitor Both Sessions

```bash
# Check status
bin/tri-agent-supervisor --status
bin/tri-agent-worker --status

# Watch logs
tail -f logs/supervisor.log logs/worker.log

# View task states
ls -la tasks/*/
```

---

## 9. PRODUCTION READINESS CHECKLIST

### 9.1 Before Going Live

- [ ] **Sandboxing**: Execution wrapped in Docker container
- [ ] **Dependency Protocol**: `DEP_REQUEST` message implemented
- [ ] **Supervisor Loop**: Main loop fully implemented (missing in v1)
- [ ] **Acceptance Tests**: Supervisor generates immutable tests BEFORE tasks
- [ ] **IPC Safety**: Atomic write (tmp → mv) pattern implemented
- [ ] **Cost Circuit Breaker**: Global spend limit enforced
- [ ] **Kill Switch**: `stop.flag` file check in every loop iteration

### 9.2 Current Status (From Gemini Review)

| Component      | Score   | Status                              |
|----------------|---------|-------------------------------------|
| Architecture   | 90/100  | Dual-agent + Consensus is robust    |
| Safety         | 40/100  | Needs sandboxing, dep handling      |
| Completeness   | 60/100  | Supervisor loop needs completion    |
| Robustness     | 70/100  | Good retry logic, file persistence  |
| **OVERALL**    | **65/100** | Ready for SUPERVISED BETA        |

---

## 10. SUCCESS CRITERIA

- [ ] 24/7 autonomous operation without human intervention
- [ ] Zero unapproved code reaches main branch
- [ ] Quality gates enforce 80%+ test coverage
- [ ] Rejection feedback is actionable (worker can fix without clarification)
- [ ] Max 3 retries prevent infinite loops
- [ ] Escalation creates GitHub issue for human review
- [ ] System recovers automatically from crashes
- [ ] Audit trail captures all decisions in `logs/ledger.jsonl`

---

## APPENDIX A: Implementation Files Summary

| File                              | Lines   | Purpose                           |
|-----------------------------------|---------|-----------------------------------|
| `bin/tri-agent-worker`            | 1,362   | Worker daemon (complete)          |
| `lib/supervisor-approver.sh`      | 1,501   | Approval engine (complete)        |
| `docs/MASTER_IMPLEMENTATION_PLAN_v2.md` | 1,870 | Full implementation spec       |
| `docs/SUPERVISOR_IMPLEMENTATION_SPEC.md` | 1,737 | Supervisor details            |
| `docs/QUALITY_GATES_SPEC.md`      | 417     | 12-check gate specification       |
| `docs/PHASE_HANDOFF_SPEC.md`      | 215     | Phase transition protocols        |
| `docs/GEMINI_ARCHITECTURE_REVIEW.md` | 96   | Critical gaps analysis            |
| `docs/GEMINI_TESTING_FRAMEWORK.md`| 101     | Testing framework                 |

**Total Planning Documentation**: ~7,299 lines across 8 core specification documents

---

*This specification was consolidated from 14+ parallel agents across Claude Opus 4.5, Codex GPT-5.2, and Gemini 3 Pro.*
