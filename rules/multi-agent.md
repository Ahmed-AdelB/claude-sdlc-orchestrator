<!-- Part of modular rules system - see ~/.claude/CLAUDE.md for full context -->

# Multi-Agent Parallelism Rules

## Minimum Agent Requirements

**Standard:** 9 concurrent agents (3 Claude + 3 Codex + 3 Gemini), 27 total per task.
**Tiered by complexity:** 1 (trivial) -> 3 (standard) -> 9 (complex tasks).
**Exception:** Degraded mode allows minimum 3 agents.

## Agent Distribution (3+3+3 Pattern)

| Activity Type      | Min Concurrent | Distribution                                                                                                                |
| ------------------ | -------------- | --------------------------------------------------------------------------------------------------------------------------- |
| **Planning**       | 9              | 3 Claude (architecture, security, specs) + 3 Gemini (context, codebase, patterns) + 3 Codex (feasibility, complexity, APIs) |
| **Implementation** | 9              | 3 Claude (core code, tests, docs) + 3 Codex (implement, optimize, validate) + 3 Gemini (review, context, security)          |
| **Verification**   | 9              | 3 Claude (security, logic, edges) + 3 Gemini (context, patterns, regression) + 3 Codex (completeness, coverage, quality)    |

**TOTAL PER TASK: 27 agent invocations (9 per phase x 3 phases)**

## Enforcement Checklist

Before marking ANY task complete:

- [ ] **27 agents** were invoked across 3 phases (9 per phase)
- [ ] **9+ concurrent** agents ran simultaneously at peak
- [ ] All three AI models (Claude, Codex, Gemini) participated in EACH phase
- [ ] Implementation was verified by at least **2 non-implementing AIs**
- [ ] Security review completed by at least **2 AIs** from different models
- [ ] Todo was updated throughout the process with phase tracking

## TODO Table Format

```markdown
| ID    | Task          |      Assigned       |    Verifier    |  Status  |  V  |
| ----- | ------------- | :-----------------: | :------------: | :------: | :-: |
| T-001 | [Description] | Claude/Codex/Gemini | [Different AI] | [Status] | [ ] |
```

**Example:**

| ID    | Task                    | Assigned | Verifier | Status           |  V  |
| ----- | ----------------------- | :------: | :------: | ---------------- | :-: |
| T-001 | Design webhook schema   |  Claude  |  Gemini  | Completed        | [x] |
| T-002 | Implement idempotency   |  Codex   |  Claude  | Verified         | [x] |
| T-003 | Add retry logic         |  Claude  |  Codex   | Ready for Verify | [ ] |
| T-004 | Create refund endpoint  |  Codex   |  Gemini  | In Progress      | [ ] |
| T-005 | Write integration tests |  Gemini  |  Claude  | Pending          | [ ] |

## Status Definitions

| Status             | Meaning               | Next Action             |
| ------------------ | --------------------- | ----------------------- |
| `Pending`          | Not started           | Begin work              |
| `In Progress`      | Work underway         | Complete implementation |
| `Ready for Verify` | Awaiting verification | Request verification    |
| `Verified`         | PASSED                | Mark completed          |
| `Completed`        | Fully done            | Archive/close           |
| `Blocked`          | Cannot proceed        | Resolve blocker         |
| `Failed`           | Verification FAILED   | Fix and re-verify       |

**Status Flow:** `Pending -> In Progress -> Ready for Verify -> Verified -> Completed`

## Verification Marks

| Mark  | Meaning                 |
| ----- | ----------------------- |
| `[ ]` | Pending verification    |
| `[x]` | Passed verification     |
| `[!]` | Failed verification     |
| `[?]` | Inconclusive (escalate) |

## Agent Assignment by Task Type

| Category      | Implementer | Reviewer 1 | Reviewer 2 |
| ------------- | ----------- | ---------- | ---------- |
| Security      | Claude      | Codex      | Gemini     |
| UI/Frontend   | Codex       | Claude     | Gemini     |
| Documentation | Gemini      | Claude     | Codex      |
| Complex Logic | Claude      | Gemini     | Codex      |
| Testing       | Codex       | Gemini     | Claude     |
| API/Backend   | Codex       | Claude     | Gemini     |

## Runtime Rules

Every AI MUST continuously:

- Add discovered requirements to TODO
- Update status in real-time
- Flag blockers immediately
- Record verification results
