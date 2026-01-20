# Advanced Protocols & Best Practices

## Multi-AI Context Handoff

```bash
# Variable handoff
ANALYSIS=$(gemini -m gemini-3-pro-preview -y "Analyze: $TASK"); codex exec "Fix based on: $ANALYSIS"

# File handoff (large context)
gemini -m gemini-3-pro-preview -y "Analyze codebase" > /tmp/ctx.txt
codex exec "Implement: $(cat /tmp/ctx.txt)"
```

## Partial Failure Strategy

| Scenario              | Action                                                                         |
| --------------------- | ------------------------------------------------------------------------------ |
| 1-2 agents fail       | Quarantine failed tasks, commit successful results, retry with alternate model |
| 3+ agents fail        | Pause, diagnose root cause, escalate to user before continuing                 |
| Verification conflict | Third AI tie-breaker, majority wins                                            |

## Credential Security

- **Storage:** OS keychain only (`libsecret` Linux / Keychain macOS)
- **Rotation:** 30-day mandatory rotation for API keys
- **Audit:** Log all credential access events
- **NEVER:** Store in plaintext, env files, or git

## Audit Trail Requirements

- **Retention:** 365 days (compliance requirement)
- **Format:** Append-only JSONL with SHA-256 checksums
- **Location:** `~/.claude/logs/audit/YYYY-MM-DD.jsonl`
- **Immutability:** `chattr +a` on log files (append-only attribute)

### Log Integrity (Checksums + Signing)

```bash
# Generate checksums for all audit logs
cd ~/.claude/logs/audit
sha256sum *.jsonl > manifest.sha256

# Sign the manifest with GPG (tamper-proof)
gpg --sign --armor manifest.sha256

# Verify integrity (run weekly via cron)
sha256sum -c manifest.sha256 && gpg --verify manifest.sha256.asc
```

**Automation (add to crontab):**

```bash
# Weekly integrity check: 0 0 * * 0 ~/.claude/scripts/verify-audit.sh
#!/bin/bash
cd ~/.claude/logs/audit
sha256sum -c manifest.sha256 || notify-send -u critical "Audit log integrity FAILED"
```

## Rate Limit Thresholds

| Usage | Action                                             |
| ----- | -------------------------------------------------- |
| 70%   | `WARN` - Alert, reduce concurrency to 6 agents     |
| 85%   | `PAUSE` - Queue new tasks, complete in-flight only |
| 95%   | `STOP` - Hard stop, notify user, wait for reset    |

## Anti-Patterns to Avoid

- **Agent count**: Use tiered approach: 1 (trivial), 3 (standard), 9 (complex) - not always 9
- **Git resets**: Prefer `git revert` over `git reset --hard` (recoverable)
- **Verification**: INCONCLUSIVE allowed with escalation to third AI or user (see CLAUDE.md)

## Pre-Flight Validations

- [ ] Tool versions: `codex --version`, `gemini --version`
- [ ] Network: `curl -s https://api.anthropic.com/health`
- [ ] Git clean: `git status --porcelain` is empty
- [ ] Credentials: `gh auth status`, OAuth tokens valid

## Better Defaults

| Setting           | Default           | Reason             |
| ----------------- | ----------------- | ------------------ |
| Codex sandbox     | `workspace-write` | Least privilege    |
| Gemini approval   | `manual`          | Safety first       |
| Agent concurrency | 3                 | Scale up as needed |

## Debugging Aids

- **Correlation IDs**: Include `CORR_ID=$(uuidgen)` in all logs
- **Diagnostics**: `tri-agent doctor --full` for system check
- **Failure snapshot**: Auto-save to `~/.claude/snapshots/last-failure.json`

## Key Metrics

| Metric                 | Target         | Alert       |
| ---------------------- | -------------- | ----------- |
| Verification pass rate | >95%           | <90%        |
| Cost per task          | Track by model | >$0.50/task |
| Test coverage delta    | +/- 0          | Negative    |
