# COMPREHENSIVE TASK LIST - TRI-24 SYSTEM
# Generated: 2025-12-29 from 20-PART PLAN
# Source: COMPREHENSIVE_AUTONOMOUS_SDLC_v5.md + INCIDENT_REPORT_20251229.md

## QUICK STATUS
- Total Tasks: 43
- P0 (Critical): 12
- P1 (High): 20
- P2 (Medium): 11
- Completed: 12
- In Progress: 4
- Pending: 27

**Last Updated**: 2025-12-29T06:50:00Z

---

## M1: STABILIZATION (8 tasks) - Priority: CRITICAL

| # | ID | Task | Priority | Status | Files |
|---|-----|------|----------|--------|-------|
| 1 | M1-001 | SQLite canonical task claiming | P0 | PENDING | bin/tri-agent-worker |
| 2 | M1-002 | Queue-to-SQLite bridge | P0 | PENDING | bin/tri-agent-queue-watcher (NEW) |
| 3 | M1-003 | Active budget watchdog | P0 | PENDING | bin/budget-watchdog |
| 4 | M1-004 | Signal-based worker pause | P0 | PENDING | bin/tri-agent-worker |
| 5 | M1-005 | Stale task recovery | P0 | PENDING | lib/heartbeat.sh |
| 6 | M1-006 | Worker pool sharding | P1 | PENDING | lib/worker-pool.sh |
| 7 | M1-007 | Heartbeat SQLite integration | P1 | PENDING | lib/heartbeat.sh, lib/sqlite-state.sh |
| 8 | M1-008 | Process reaper enhancement | P1 | PENDING | bin/process-reaper |

---

## M2: CORE AUTONOMY (6 tasks)

| # | ID | Task | Priority | Status | Files |
|---|-----|------|----------|--------|-------|
| 9 | M2-009 | SDLC phase enforcement library | P0 | PENDING | lib/sdlc-phases.sh (NEW) |
| 10 | M2-010 | Supervisor unification | P1 | PENDING | bin/tri-agent-supervisor, lib/supervisor-approver.sh |
| 11 | M2-011 | Supervisor main loop | P1 | PENDING | bin/tri-agent-supervisor |
| 12 | M2-012 | Task artifact tracking | P1 | PENDING | lib/sdlc-phases.sh |
| 13 | M2-013 | Phase gate validation | P1 | PENDING | lib/sdlc-phases.sh |
| 14 | M2-014 | Rejection feedback generator | P2 | PENDING | lib/supervisor-approver.sh |

---

## M3: SELF-HEALING (6 tasks)

| # | ID | Task | Priority | Status | Files |
|---|-----|------|----------|--------|-------|
| 15 | M3-015 | Circuit breaker delegate integration | P1 | PENDING | bin/claude-delegate, bin/codex-delegate, bin/gemini-delegate |
| 16 | M3-016 | Model fallback chain | P1 | PENDING | bin/*-delegate |
| 17 | M3-017 | Health check JSON hardening | P2 | PENDING | bin/health-check |
| 18 | M3-018 | Zombie process cleanup | P2 | PENDING | bin/process-reaper |
| 19 | M3-019 | Worker crash recovery | P1 | PENDING | lib/heartbeat.sh, lib/worker-pool.sh |
| 20 | M3-020 | Event store implementation | P2 | PENDING | lib/event-store.sh |

---

## M4: SECURITY HARDENING (12 tasks) - Priority: CRITICAL

| # | ID | Task | Priority | Status | Files |
|---|-----|------|----------|--------|-------|
| 21 | SEC-001 | sanitize_git_log() | P0 | IN PROGRESS | lib/common.sh (Claude agent) |
| 22 | SEC-003A | State symlink protection | P0 | IN PROGRESS | lib/state.sh:215 (Claude agent) |
| 23 | SEC-003B | SQLite symlink protection | P0 | IN PROGRESS | lib/sqlite-state.sh:46 (Codex agent) |
| 24 | SEC-006 | LLM input sanitization | P0 | IN PROGRESS | lib/common.sh (Claude agent) |
| 25 | SEC-007 | Ledger file locking | P0 | IN PROGRESS | lib/supervisor-approver.sh (Codex agent) |
| 26 | SEC-008A | Quality gate strict mode | P0 | PENDING | lib/supervisor-approver.sh |
| 27 | SEC-008B | Threshold floor hardening | P0 | PENDING | lib/supervisor-approver.sh |
| 28 | SEC-008C | Absolute path enforcement | P0 | PENDING | lib/supervisor-approver.sh |
| 29 | SEC-009A | Pattern normalization | P1 | IN PROGRESS | lib/safeguards.sh (Codex agent) |
| 30 | SEC-009B | CLI authentication | P1 | PENDING | lib/supervisor-approver.sh |
| 31 | SEC-009C | JSON size limits | P1 | PENDING | lib/security.sh:179-218 |
| 32 | SEC-010 | Expanded secret mask patterns | P1 | PENDING | config/tri-agent.yaml |

---

## M5: SCALE & UX (4 tasks)

| # | ID | Task | Priority | Status | Files |
|---|-----|------|----------|--------|-------|
| 33 | M5-033 | Security verification test suite | P1 | PENDING | tests/security/test_security_fixes.sh (NEW) |
| 34 | M5-034 | Load testing validation | P2 | **DONE** | tests/load/ |
| 35 | M5-035 | Dashboard/CLI status | P3 | PENDING | bin/tri-agent-dashboard (NEW) |
| 36 | M5-036 | Documentation updates | P2 | PENDING | docs/*.md |

---

## INCIDENT FIX TASKS (7 tasks) - Priority: IMMEDIATE

| # | ID | Task | Priority | Status | Files |
|---|-----|------|----------|--------|-------|
| 37 | FIX-001 | Fix coverage measurement bug | P0 | **DONE** | lib/supervisor-approver.sh:448-502 |
| 38 | FIX-002 | Configure Codex API key | P0 | PENDING | Manual - env setup |
| 39 | FIX-003 | Monitor daemon exception handling | P0 | **DONE** | bin/tri-24-monitor |
| 40 | FIX-004 | Increase lock timeout to 5s | P0 | **DONE** | lib/common.sh |
| 41 | FIX-005 | Add max retry limit to quality gates | P0 | **DONE** | lib/supervisor-approver.sh |
| 42 | FIX-006 | Separate stress test logs | P1 | IN PROGRESS | lib/logging.sh (Gemini agent) |
| 43 | FIX-007 | Add preflight API key validation | P1 | IN PROGRESS | lib/worker-pool.sh (Gemini agent) |

---

## ARCHITECTURE IMPROVEMENT TASKS (5 tasks from Gemini)

| # | ID | Task | Priority | Description |
|---|-----|------|----------|-------------|
| A1 | INC-ARCH-001 | Active Monitor Daemon with Heartbeat | P1 | Replace passive monitor with active daemon |
| A2 | INC-ARCH-002 | Circuit Breaker for Quality Gates | P1 | Trip after 3 consecutive failures |
| A3 | INC-ARCH-003 | Log Separation for Execution Modes | P2 | production/stress-test/dev logs |
| A4 | INC-ARCH-004 | API Key Pre-flight Validation | P1 | Validate all API keys at startup |
| A5 | INC-ARCH-005 | Lock Timeout Optimization | P1 | Exponential backoff for lock acquisition |

---

## EXECUTION PRIORITY ORDER

### Phase 1 (Immediate - Unblock System)
1. [DONE] FIX-001: Coverage measurement fix
2. [DONE] FIX-003: Monitor daemon crash handling
3. [IN PROGRESS] FIX-004: Lock timeout increase
4. [NEXT] FIX-005: Max retry limit
5. FIX-002: Codex API key (manual)

### Phase 2 (24h - Security Critical)
6. SEC-001: sanitize_git_log()
7. SEC-003A/B: Symlink protection
8. SEC-006: LLM input sanitization
9. SEC-007: Ledger file locking
10. SEC-008A/B/C: Quality gate hardening

### Phase 3 (48h - Stability)
11-20. M1 tasks (stabilization)
21-26. M2 tasks (core autonomy)

### Phase 4 (72h - Resilience)
27-32. M3 tasks (self-healing)
33-43. Remaining tasks

---

## SYSTEM COMMANDS

```bash
# Check current status
cd /home/aadel/projects/tri-24-execution-20251229_005901/claude-sdlc-orchestrator/v2
./bin/health-check

# View task queue
ls -la tasks/queue/ | wc -l
ls -la tasks/completed/ | wc -l

# Start supervisor (after fixes)
./bin/tri-agent-supervisor

# Monitor logs
tail -f logs/tri-24-monitor.log

# Check for crashed processes
ps aux | grep tri-agent | grep -v grep
```

---

## METRICS TARGETS

| Metric | Current | Target |
|--------|---------|--------|
| Task Completion Rate | 0% | >80% |
| Error Rate | 28,132/5hr | <100/hr |
| Workers Healthy | 2/3 | 3/3 |
| Lock Contention | 60% of errors | <5% |
| Security Score | 42/100 | 82/100 |

---

*Generated from 20-PART COMPREHENSIVE PLAN*
*Last Updated: 2025-12-29*
