# Debugging Aids & Metrics Tracking

> **Reference:** Full debugging and metrics documentation for tri-agent system.

## Debugging Aids

### Correlation IDs

All logs/tasks tagged with `CID:{session}-{task}-{agent}-{seq}` for end-to-end tracing.

```bash
# Generate: CID=$(printf "s%s-T%03d-%s-%03d" "$(date +%Y%m%d)" "$TASK_NUM" "$AGENT" "$SEQ")
# Example: CID:s20260120-T042-claude-007
# Search:  grep "CID:s20260120-T042" ~/.claude/logs/*.log | less
```

### Diagnostic Command (`tri-agent doctor`)

```bash
tri-agent doctor                      # Full health check
tri-agent doctor --component gemini   # Single component
tri-agent doctor --fix                # Auto-repair common issues
```

| Check            | Pass Criteria                   | Auto-Fix Action            |
| ---------------- | ------------------------------- | -------------------------- |
| CLI versions     | gemini >= 0.18, codex >= 1.0    | `npm update -g`            |
| Auth credentials | OAuth tokens valid, not expired | Re-auth prompt             |
| DB integrity     | `PRAGMA integrity_check = ok`   | `VACUUM; REINDEX`          |
| Disk space       | >= 2GB free                     | Run cleanup script         |
| Network          | API endpoints reachable         | DNS/proxy diagnostics      |
| Stale processes  | No zombie PIDs                  | Kill stale, remove pidfile |

### Last Failure Snapshot

Auto-persisted to `~/.claude/debug/last-failure.json` on any task failure.

```json
{
  "cid": "s20260120-T042-codex-007",
  "ts": "2026-01-20T14:32:01Z",
  "task": "T-042",
  "agent": "codex",
  "error": "timeout",
  "exit": 124,
  "stderr": "...last 50 lines...",
  "tokens": 285000,
  "retries": 2,
  "git_sha": "abc123",
  "env": { "TRI_AGENT_DEBUG": "1" }
}
```

**Replay:** `tri-agent replay --from ~/.claude/debug/last-failure.json`

### Debug Mode

```bash
TRI_AGENT_DEBUG=1 tri-agent start   # Verbose logging (stderr)
TRI_AGENT_DEBUG=2 tri-agent start   # + API request/response bodies
TRI_AGENT_TRACE=1 tri-agent start   # + Function-level tracing
```

### Common Error Patterns

| Pattern                   | Cause                | Fix                                    |
| ------------------------- | -------------------- | -------------------------------------- |
| `exit 2` (gemini/codex)   | Auth expired/invalid | `gemini-switch` or `codex auth`        |
| `exit 124` timeout        | Task too large       | Split task, `--timeout 600`            |
| `SQLITE_BUSY`             | DB lock contention   | Reduce concurrency, add retry logic    |
| `context_length_exceeded` | Token overflow       | Trigger session refresh, split context |
| `429 Too Many Requests`   | Rate limit           | Backoff 2^n sec, check daily budget    |
| 3+ verification FAILs     | Spec mismatch        | Escalate to user, re-clarify reqs      |

---

## Metrics Tracking

### Verification Pass Rate

```bash
tri-agent metrics --type verify --range 7d
# Output: Pass: 94.2% | Fail: 4.1% | Inconclusive: 1.7% | Avg attempts: 1.3
```

| Metric             | Target | Alert Threshold |
| ------------------ | ------ | --------------- |
| First-attempt pass | >= 85% | < 75%           |
| Max attempts       | <= 2   | > 3             |
| Inconclusive rate  | < 5%   | > 10%           |

### Approval Latency (Ready-to-Verified)

```bash
tri-agent metrics --type latency --range 24h
# Output: P50: 42s | P90: 2m15s | P99: 7m30s
```

| Percentile | Target   | Alert Threshold |
| ---------- | -------- | --------------- |
| P50        | < 1 min  | > 2 min         |
| P90        | < 5 min  | > 10 min        |
| P99        | < 15 min | > 30 min        |

### Cost per Task by Model

```bash
tri-agent metrics --type cost --range 30d --group-by model
```

| Model         | Avg $/Task | Daily Cap |
| ------------- | ---------- | --------- |
| Claude Opus   | $0.45      | $15       |
| Claude Sonnet | $0.08      | $10       |
| Gemini 3 Pro  | $0.02      | Unlimited |
| Codex GPT-5.2 | $0.12      | $12       |

**Alerts:** 70% daily cap → WARNING, 90% → PAUSE new tasks

### Resource Utilization per Agent

```bash
tri-agent metrics --type utilization --live
# Output: Claude: 78% | Codex: 65% | Gemini: 82% | Avg: 75%
```

| Metric           | Healthy    | Action if Outside |
| ---------------- | ---------- | ----------------- |
| CPU per agent    | 10-80%     | Scale or throttle |
| Memory per agent | < 2GB      | Restart if > 4GB  |
| Active/Max ratio | 60-90%     | Add/remove agents |
| Queue depth      | < 20 tasks | Scale up if > 50  |

### Test Coverage Delta per Task

```bash
tri-agent metrics --type coverage --task T-042
# Output: Before: 78.2% | After: 81.5% | Delta: +3.3%
```

| Metric         | Requirement | Block If |
| -------------- | ----------- | -------- |
| Coverage delta | >= 0%       | < -1%    |
| New code cov   | >= 80%      | < 60%    |
| Critical paths | 100%        | < 100%   |

**Enforcement:** Tasks reducing coverage are auto-flagged; merge blocked until resolved.
