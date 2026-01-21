# Incident Response Runbooks

## Runbook 1: Daemon Crash Recovery

```bash
# Symptoms: tri-agent-daemon not responding, PID file stale
# Severity: CRITICAL
# ETA: 5 minutes

# Step 1: Check process status
pgrep -f tri-agent-daemon || echo "Daemon not running"

# Step 2: Check last logs
tail -50 ~/.claude/logs/daemon.log

# Step 3: Clear stale locks
rm -f ~/.claude/locks/*.lock

# Step 4: Recover stuck tasks
tri-agent-admin requeue-stale
tri-agent-admin sync-db

# Step 5: Restart daemon
tri-agent start --watchdog

# Step 6: Verify recovery
tri-agent health --verbose
```

## Runbook 2: Context Overflow Recovery

```bash
# Symptoms: "Context limit exceeded" errors, slow responses
# Severity: HIGH
# ETA: 10 minutes

# Step 1: Check current context usage
cat ~/.claude/sessions/claude-progress.txt | grep "tokens"

# Step 2: Create emergency checkpoint
tri-agent checkpoint --reason="context_overflow"

# Step 3: Force session refresh
tri-agent session-refresh --force

# Step 4: Resume from checkpoint
tri-agent resume --from-checkpoint latest

# Step 5: Consider splitting large tasks
# If task > 100K tokens, break into subtasks
```

## Runbook 3: Budget Exhaustion

```bash
# Symptoms: 429 errors, "rate limit" messages
# Severity: MEDIUM
# ETA: Varies (wait for reset)

# Step 1: Check budget status
cost-tracker --status --daily

# Step 2: Identify high-consumption tasks
cost-tracker --breakdown --last-hour

# Step 3: Pause non-critical operations
tri-agent pause --priority low

# Step 4: Wait for reset OR switch model
# Claude: Rolling 5-hour window
# Gemini: Midnight UTC reset
# Codex: Midnight UTC reset

# Step 5: Resume operations
tri-agent resume --all
```

## Runbook 4: Lock Contention Spike

```bash
# Symptoms: High lock failure rate, slow task processing
# Severity: MEDIUM
# ETA: 15 minutes

# Step 1: Identify contention hotspots
grep "LOCK_FAIL" ~/.claude/logs/*.log | sort | uniq -c | sort -rn | head

# Step 2: Clear orphaned locks
find ~/.claude/tasks -name "*.lock.d" -mmin +30 -exec rm -rf {} +

# Step 3: Reduce concurrent agents
export MAX_CONCURRENT_AGENTS=6  # Reduce from 15

# Step 4: Restart workers
tri-agent workers restart

# Step 5: Monitor improvement
watch -n 5 'grep -c LOCK_FAIL ~/.claude/logs/$(date +%Y%m%d).log'
```

## Runbook 5: Security Incident

```bash
# Symptoms: Suspicious activity, unauthorized access attempts
# Severity: CRITICAL
# ETA: Immediate

# Step 1: STOP ALL OPERATIONS IMMEDIATELY
tri-agent stop --force --reason="security_incident"

# Step 2: Preserve evidence
cp -r ~/.claude/logs ~/security-incident-$(date +%Y%m%d)/
cp ~/.claude/settings.json ~/security-incident-$(date +%Y%m%d)/

# Step 3: Review recent activity
grep -E "BLOCKED|WARN|DENY" ~/.claude/logs/security.log | tail -100

# Step 4: Check for credential exposure
grep -rE "(password|token|apikey|secret)" ~/.claude/logs/

# Step 5: Rotate all credentials
# - Anthropic API key
# - GitHub token
# - Database credentials
# - MCP server credentials

# Step 6: Review and harden configuration
# - Check permissions.deny patterns
# - Verify MCP server allowlist
# - Audit hook scripts

# Step 7: Report incident (if required)
# - Document timeline
# - Identify root cause
# - Implement preventive measures
```

## Runbook 6: Zombie Process / CPU Spike

```bash
# Symptoms: 100% CPU usage by orphaned CLI processes, system sluggishness
# Severity: HIGH
# ETA: 5 minutes

# Step 1: Detect high CPU consumers
top -b -n 1 | head -n 20
# OR
ps aux --sort=-%cpu | head -n 10

# Step 2: Identify parent process (PPID)
# Look for processes with PPID 1 (init) that shouldn't be there
ps -ef | grep -v grep | grep [process_name]

# Step 3: Check process tree
pstree -p -s [PID]

# Step 4: Terminate specific stuck process
kill -15 [PID]
# Wait 10s, if not gone:
kill -9 [PID]

# Step 5: Cleanup orphaned CLI processes
# Kill all instances of specific CLI tools if confirmed stuck
pkill -f "node.*cli.js"
pkill -f "python.*cli.py"

# Step 6: Verify CPU returns to normal
vmstat 1 5
```

## Escalation Matrix

| Severity | First Responder | Escalate After | Escalate To |
|----------|----------------|----------------|-------------|
| CRITICAL | Immediate auto-response | 5 min | Human operator |
| HIGH | Watchdog auto-recovery | 15 min | Human operator |
| MEDIUM | Scheduled retry | 1 hour | Review queue |
| LOW | Log and continue | 24 hours | Weekly review |