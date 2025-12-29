# Master Implementation Plan: Autonomous Dual Tri-Agent SDLC System

**Generated**: 2025-12-28
**Source**: 14+ parallel agents (Claude Opus, Codex GPT-5.2, Gemini 3 Pro)
**Goal**: Split SDLC phases between two 24-hour tri-agent sessions for continuous autonomous operation with forced quality gates

---

## Executive Summary

This plan consolidates research from multiple AI models to design a self-sustaining SDLC system where:
- **SUPERVISOR Agent**: Owns requirements, planning, quality gates, and approval authority
- **WORKER Agent**: Owns implementation, testing, and execution
- **Quality Gates**: Force validation between every phase transition
- **No Human Intervention Required**: 24/7 autonomous operation with escalation only for critical failures

---

## 1. Architecture Overview

### 1.1 Dual Agent Roles

| Role | Primary Model | Responsibilities | Authority |
|------|---------------|------------------|-----------|
| **SUPERVISOR** | Claude Opus (ultrathink) | Brainstorm, Plan, Track, Approve/Reject | APPROVE, REJECT, ESCALATE |
| **WORKER** | Claude Opus + Codex delegation | Execute, Test, Report | IMPLEMENT, COMMIT, SUBMIT |

### 1.2 SDLC Phase Ownership Matrix

```
+============+==================+==================+==================+
| SDLC PHASE | PRIMARY OWNER    | SECONDARY ROLE   | DELEGATION       |
+============+==================+==================+==================+
| BRAINSTORM | SUPERVISOR       | Worker: Context  | Gemini (1M ctx)  |
| DOCUMENT   | COLLABORATIVE    | Worker: Draft    | Gemini (docs)    |
| PLAN       | SUPERVISOR       | Worker: Estimate | Claude (arch)    |
| EXECUTE    | WORKER           | Supervisor: Gate | Codex (impl)     |
| TRACK      | SUPERVISOR       | Worker: Report   | Gemini (analysis)|
+============+==================+==================+==================+
```

---

## 2. Directory Structure

```
~/.claude/autonomous/
├── config/
│   ├── tri-agent.yaml           # Base configuration
│   ├── supervisor-agent.yaml    # Supervisor settings
│   ├── worker-agent.yaml        # Worker settings
│   ├── quality-gates.yaml       # Gate thresholds
│   └── supervision.yaml         # Approval engine config
├── tasks/
│   ├── queue/                   # Pending tasks (priority ordered)
│   ├── running/                 # Worker executing (max 1)
│   ├── review/                  # Awaiting supervisor approval
│   ├── approved/                # Passed all gates
│   ├── rejected/                # Failed with feedback
│   ├── completed/               # Successfully merged
│   └── failed/                  # Max retries exceeded
├── state/
│   ├── sdlc/                    # Phase artifacts
│   │   ├── brainstorm/          # Requirements docs
│   │   ├── document/            # Specifications
│   │   ├── plan/                # Implementation plans
│   │   ├── execute/             # Mission tracking
│   │   └── track/               # Status reports
│   └── supervision/
│       ├── current-review.json  # Active review
│       ├── review-history.jsonl # Audit trail
│       └── signals/             # Inter-agent IPC
├── comms/
│   ├── supervisor/
│   │   ├── inbox/               # FROM Worker TO Supervisor
│   │   └── sent/                # Supervisor sent history
│   └── worker/
│       ├── inbox/               # FROM Supervisor TO Worker
│       └── sent/                # Worker sent history
├── lib/
│   ├── common.sh               # Shared utilities
│   ├── supervisor-approver.sh  # Approval engine
│   ├── worker-executor.sh      # Execution engine
│   └── comms.sh                # IPC helpers
├── bin/
│   ├── tri-agent-supervisor    # Supervisor daemon
│   └── tri-agent-worker        # Worker daemon
└── logs/
    └── supervision/
        ├── evaluations.jsonl   # Gate results
        ├── approvals.jsonl     # Approval records
        └── rejections.jsonl    # Rejection records
```

---

## 3. Message Protocol (Inter-Agent Communication)

### 3.1 Message Schema

```json
{
  "id": "UUID-v4",
  "type": "MESSAGE_TYPE",
  "source": "supervisor|worker",
  "target": "worker|supervisor",
  "timestamp": "ISO8601-UTC",
  "correlation_id": "UUID-v4 (for replies)",
  "payload": {},
  "metadata": {
    "priority": "high|medium|low",
    "requires_ack": true,
    "retry_count": 0
  }
}
```

### 3.2 Message Types

**Supervisor → Worker:**
| Type | Description |
|------|-------------|
| `TASK_ASSIGN` | Assign task to worker |
| `TASK_APPROVE` | Work passed all gates |
| `TASK_REJECT` | Work failed with feedback |
| `CONTROL_PAUSE` | Pause worker execution |
| `CONTROL_RESUME` | Resume worker |

**Worker → Supervisor:**
| Type | Description |
|------|-------------|
| `TASK_ACCEPT` | Acknowledged task |
| `TASK_COMPLETE` | Ready for review |
| `TASK_FAIL` | Non-recoverable error |
| `QUERY_CLARIFY` | Need clarification |
| `HEARTBEAT` | Liveness signal |

---

## 4. Quality Gates Specification

### 4.1 Automated Gates (Always Run)

```yaml
quality_gates:
  tests:
    required: true
    min_pass_rate: 1.0
    timeout_seconds: 300

  coverage:
    required: true
    min_coverage: 0.80
    fail_on_decrease: true

  build:
    required: true
    timeout_seconds: 180

  lint:
    required: true
    zero_errors: true
    max_warnings: 10

  security_scan:
    required: true
    tools: ["npm audit", "bandit"]
    max_high_severity: 0
```

### 4.2 Tri-Agent Code Review (Conditional)

Triggered when:
- Security-sensitive code modified
- Architecture patterns changed
- > 500 lines changed
- New dependencies added

```yaml
review:
  tri_agent:
    mode: "veto|majority|weighted"
    triggers:
      - pattern: "auth|security|password|token"
        mode: "veto"
      - lines_changed: 500
        mode: "majority"
```

### 4.3 Scoring Matrix

| Check | Weight | Blocking |
|-------|--------|----------|
| Tests Pass | 0.25 | Yes |
| Coverage ≥80% | 0.15 | Yes |
| Build Success | 0.15 | Yes |
| Lint Clean | 0.10 | Yes |
| Security Scan | 0.20 | Yes |
| Claude Review | 0.15 | Veto (security) |
| Codex Review | 0.10 | No |
| Gemini Review | 0.10 | No |

**Approval Threshold**: Score ≥ 85 + No blockers

---

## 5. Approval/Rejection Workflow

### 5.1 Approval Flow

```
WORKER completes task
    ↓
Moves to tasks/review/
    ↓
Signals supervisor via comms/supervisor/inbox/
    ↓
SUPERVISOR runs quality gates
    ↓
IF all gates pass (score ≥ 85):
    → Commit changes
    → Move to tasks/approved/
    → Signal worker: TASK_APPROVE
    → Assign next task
```

### 5.2 Rejection Flow

```
SUPERVISOR detects gate failure
    ↓
Analyze root cause
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
```

### 5.3 Rejection Limit

```yaml
retry_limits:
  per_task:
    max_attempts: 3
    backoff_strategy: "linear"
    backoff_increment: 300  # 5 min per retry

  escalation:
    after_max_retries: "escalate_to_human"
    create_github_issue: true
    pause_autonomous: true
```

---

## 6. State Machine

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

---

## 7. Safeguards

### 7.1 Infinite Loop Prevention

1. **Retry Budget**: Max 3 retries per task
2. **Diminishing Scope**: Each retry focuses only on flagged issues
3. **Pattern Detection**: Same failures across retries triggers escalation
4. **Circuit Breaker**: > 10 rejections/hour pauses autonomous mode

### 7.2 Crash Recovery

1. **Heartbeats**: Every 60 seconds
2. **Stale Detection**: > 5 min = agent crashed
3. **Auto-Recovery**: Watchdog respawns agent
4. **Task Recovery**: In-progress tasks return to queue

### 7.3 Escalation Path

| Trigger | Action |
|---------|--------|
| 3 retries | Notify human |
| 4 retries | Pause autonomous |
| 5 retries | Create GitHub issue |
| Loop detected | Switch strategy/model |

---

## 8. Implementation Phases

### Phase 1: Core Infrastructure (Day 1)

1. Create `lib/supervisor-approver.sh`:
   - `quality_gate()` - run all automated checks
   - `approve_task()` - handle approval flow
   - `reject_task()` - generate feedback, re-queue
   - `score_work()` - calculate approval score

2. Create `lib/worker-executor.sh`:
   - `main_loop()` - poll queue every 10 seconds
   - `get_next_task()` - priority-based selection
   - `execute_task()` - run implementation
   - `submit_for_review()` - signal supervisor

3. Create `lib/comms.sh`:
   - `send_message()` - atomic write to inbox
   - `check_inbox()` - process incoming messages
   - `acknowledge()` - send ACK

### Phase 2: Daemon Scripts (Day 2)

1. Update `bin/tri-agent-supervisor`:
   - Add review monitoring
   - Integrate approval engine
   - Add rejection feedback loop

2. Create `bin/tri-agent-worker`:
   - Task pickup loop
   - Codex delegation for implementation
   - Local test execution
   - Review submission

### Phase 3: Quality Gates (Day 3)

1. Create `config/quality-gates.yaml`
2. Implement gate runners
3. Add tri-agent consensus for code review
4. Configure thresholds

### Phase 4: Integration (Day 4)

1. Connect supervisor ↔ worker via comms/
2. Test full approval cycle
3. Test rejection/retry cycle
4. Verify escalation path

### Phase 5: Hardening (Day 5)

1. Add circuit breaker for supervision
2. Implement watchdog for both agents
3. Add metrics and logging
4. Create recovery procedures

---

## 9. Configuration Files to Create

### supervisor-agent.yaml

```yaml
agent:
  name: "supervisor"
  role: "validator"
  model: "claude-opus-4.5"
  thinking_tokens: 32000

permissions:
  can_approve: true
  can_reject: true
  can_create_pr: true
  can_merge: false

delegation:
  large_context: "gemini"
  security_scan: "self"
```

### worker-agent.yaml

```yaml
agent:
  name: "worker"
  role: "implementer"
  model: "claude-opus-4.5"
  thinking_tokens: 32000

permissions:
  can_modify_code: true
  can_commit: true
  can_push: true

delegation:
  implementation: "codex"
  test_generation: "codex"
```

---

## 10. Success Criteria

- [ ] 24/7 autonomous operation without human intervention
- [ ] Zero unapproved code reaches main branch
- [ ] Quality gates enforce 80%+ test coverage
- [ ] Rejection feedback is actionable (worker can fix without clarification)
- [ ] Max 3 retries prevent infinite loops
- [ ] Escalation creates GitHub issue for human review
- [ ] System recovers automatically from crashes
- [ ] Audit trail captures all decisions

---

## 11. Files Generated by Research Agents

| File | Source | Purpose |
|------|--------|---------|
| `AUTONOMOUS_SDLC_ARCHITECTURE.md` | Gemini | Complete system architecture |
| `INTER_AGENT_PROTOCOL.md` | Gemini | Communication protocol spec |
| Agent a76f5ce output | Claude | SDLC phase ownership matrix |
| Agent ae5ea64 output | Claude | Approval workflow design |
| Agent b71f686 | Codex | Supervisor approver script (in progress) |

---

## 12. Next Steps

1. **Immediate**: Review and finalize this plan
2. **Day 1**: Implement Phase 1 (Core Infrastructure)
3. **Day 2**: Implement Phase 2 (Daemon Scripts)
4. **Ongoing**: Follow implementation phases to completion

---

*This plan was generated by consolidating outputs from 14+ parallel agents across Claude Opus, Codex GPT-5.2, and Gemini 3 Pro.*
