# 24-HOUR CONTINUOUS OPERATION (CRITICAL)

> This document contains detailed 24-hour operation protocols for the tri-agent system.

## Session Persistence Architecture

**Progress File:** Update `claude-progress.txt` each session with: date, session ID, `git log --oneline -20`, current branch, uncommitted count, last checkpoint, and next TODOs.

**State Persistence Locations:**
| State Type | Location | Backup Frequency |
|------------|----------|------------------|
| Task Queue | `state/tri-agent.db` (SQLite) | Real-time WAL |
| Progress Log | `claude-progress.txt` | Every commit |
| Checkpoints | `sessions/checkpoints/` | Every 5 minutes |
| Event Log | `state/event-store/events.jsonl` | Append-only |

## Context Window Management (CRITICAL FOR 24HR)

**Token Budget Per Session:**
| Model | Context Window | Safe Working Limit | Refresh Trigger |
|-------|---------------|-------------------|-----------------|
| Claude Opus/Sonnet | 200K | 160K (80%) | 150K tokens used |
| Gemini 3 Pro | 1M | 800K (80%) | 750K tokens used |
| Codex GPT-5.2 | 400K | 320K (80%) | 300K tokens used |

**Context Overflow:** At 80% threshold (Claude 150K, Gemini 750K, Codex 300K): checkpoint → summarize via Gemini → refresh.
**Failover:** Claude (200K) → Gemini (1M) → split sub-tasks.

## Session Refresh Protocol (Every 8 Hours)

```bash
SESSION_DURATION_HOURS=8
SESSION_REFRESH_ENABLED=true
CONTEXT_CHECKPOINT_INTERVAL=300  # 5 minutes

# At session boundary:
# 1. Checkpoint all in-progress work
# 2. Commit with descriptive message
# 3. Update claude-progress.txt
# 4. Generate session summary via Gemini
# 5. Clear context and reload essentials
# 6. Resume from checkpoint
```

## Watchdog & Auto-Recovery Stack

**3-Layer Supervision:**

```
Layer 1: tri-agent-daemon (Parent)
  ├─ tri-agent-worker (Task executor)
  ├─ tri-agent-supervisor (Approval flow)
  └─ budget-watchdog (Cost tracking)

Layer 2: watchdog-master (External supervisor)
  ├─ Monitors Layer 1 health
  ├─ Restarts failed daemons
  └─ Exponential backoff (2^n seconds)

Layer 3: tri-24-monitor (24-hour guardian)
  ├─ Heartbeat every 30 seconds
  ├─ System health checks
  └─ Alerting on failures
```

**Recovery Hierarchy:**
| Failure Type | Detection | Recovery Action |
|--------------|-----------|-----------------|
| Task Timeout | Heartbeat > threshold | Requeue task, increment retry |
| Worker Crash | PID check fails | Mark dead, recover tasks |
| Daemon Crash | watchdog-master | Auto-restart with backoff |
| Context Overflow | Token tracking | Session refresh |
| Rate Limit | 429 response | Exponential backoff |
| Budget Exhausted | cost-tracker | Pause until reset |

## 24-Hour Budget Management

**Daily Token Budgets:**
| Model | Daily Limit | Hourly Average | Alert Threshold |
|-------|-------------|----------------|-----------------|
| Claude Max | ~100M tokens | 4.2M/hour | 70% daily |
| Gemini Pro | Unlimited\* | N/A | API rate limits |
| Codex | ~50M tokens | 2.1M/hour | 70% daily |

**Budget Reset Schedule:**

- Claude: Rolling 5-hour window + 7-day weekly cap
- Gemini: Daily reset at midnight UTC
- Codex: Daily reset at midnight UTC

## 24-Hour Operation Checklist

**Before Starting:**

- [ ] Verify watchdog-master is running
- [ ] Check daily budget availability
- [ ] Initialize claude-progress.txt
- [ ] Create initial git checkpoint
- [ ] Configure 8-hour session refresh

**During Operation (Automated):**

- [ ] Heartbeat every 30 seconds
- [ ] Context checkpoint every 5 minutes
- [ ] Progress update every commit
- [ ] Budget check every 100K tokens
- [ ] Session refresh at 8-hour boundaries

**Recovery Triggers:**

- [ ] Task timeout → Requeue
- [ ] Worker crash → Auto-restart
- [ ] Context overflow → Session refresh
- [ ] Budget exhaustion → Pause & alert

## Commands for 24-Hour Operation

```bash
# Start 24-hour session
tri-agent start --mode=24hr --watchdog --monitor

# Check session health
tri-agent health --verbose

# Force checkpoint
tri-agent checkpoint --reason="manual"

# Resume from crash
tri-agent resume --from-checkpoint latest

# View progress
cat claude-progress.txt

# Check budget
cost-tracker --status --daily

# Session refresh
tri-agent session-refresh --summarize
```

## Resource & Log Governance (24HR MANDATORY)

**Log Rotation Policy:**

- **Max Log Size:** 50MB per file
- **Retention:** 7 days (rolling window)
- **Rotation Check:** Every session refresh (8 hours)
- **Command:** `find logs/ -name "*.log" -size +50M -exec gzip {} \;`

**Hardware Safety Limits:**

- **Max Concurrent CLI Processes:** 15 (prevent fork bombs)
- **Max RAM Usage:** 75% of System Total (pause new agents if exceeded)
- **Disk Free Space Floor:** 2GB (emergency stop if crossed)

**Emergency Dead Man's Switch:**

- **Mechanism:** `tri-24-monitor` must touch `~/.claude/heartbeat` every 30s
- **Systemd/Cron Action:** If file age > 5m, kill all `tri-agent` processes and restart `watchdog-master`

## Large Repository Protocol (8GB+ Support)

**Context Strategy: Sparse Loading**

- **Problem:** 1M tokens ≈ 4MB text. 8GB repo is 2000x larger
- **Solution:** NEVER load "entire codebase". Use hierarchical narrowing:
  1. **Map:** `tree -L 2` or `find . -maxdepth 2` for structure
  2. **Search:** Use `ripgrep` (rg) to find specific symbols
  3. **Read:** Only read files confirmed relevant by search

**Incremental Verification (8GB+ repos):**

- **Unit:** `jest -o` / `pytest --lf` (last-failed only)
- **Build:** `tsc --incremental`
- **Lint:** `eslint --cache`

## Security Hardening (Production)

**Risk Mitigation:**
| Risk | Mitigation |
|------|------------|
| `danger-full-access` | Run Codex in Docker container |
| YOLO mode | Audit log all auto-approved actions |
| Credential exposure | Secret scanning on `claude-progress.txt` |
| Budget drain | Hard stop at 95% daily budget |

**Atomic State Writes:**

```bash
# Use write-to-temp-and-rename pattern
write_state() {
    local target="$1" content="$2"
    local tmp="${target}.tmp.$$"
    echo "$content" > "$tmp"
    mv "$tmp" "$target"  # Atomic on same filesystem
}
```

**Fallback Summarization:**

- If Gemini fails during session refresh, dump raw context to timestamped file
- Alert and preserve data for manual recovery
