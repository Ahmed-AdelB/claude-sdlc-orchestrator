# Claude Code Stuck Process Troubleshooting Guide

## Overview

This document explains why Claude Code CLI processes get stuck, what error codes mean, and how to prevent/handle orphaned processes.

---

## Error: "No messages returned" + Exit Code 124

### What This Error Means

```
Error: No messages returned
    at aAB (/$bunfs/root/claude:5329:78)
    at processTicksAndRejections (native:7:39)
Exit code: 124
```

**Two separate issues combined:**

| Component | Meaning |
|-----------|---------|
| `No messages returned` | Claude API returned empty response - session state corrupted or context overflow |
| `Exit code 124` | Linux `timeout` command terminated the process - command exceeded time limit |

### Exit Code 124 Explained

From the [Linux timeout manual](https://man7.org/linux/man-pages/man1/timeout.1.html):

| Exit Code | Meaning |
|-----------|---------|
| **124** | Command timed out (SIGTERM sent) |
| 125 | Timeout command itself failed |
| 126 | Command found but cannot be invoked |
| 127 | Command not found |
| 137 | Command killed with SIGKILL (128+9) |

**Exit 124 = The process ran longer than allowed and was terminated.**

---

## Why Claude Processes Get Stuck

### 1. Context Accumulation (Primary Cause)

From [GitHub Issue #17711](https://github.com/anthropics/claude-code/issues/17711):

- CLI accumulates excessive context over multiple prompts
- Memory bloat causes CPU to peg at ~100%
- Internal processing slows, causing timeout loops
- **Affected versions:** 2.1.4, 2.1.5
- **Working versions:** 2.1.0, 2.0.76

**Symptoms:**
1. Terminal input becomes slow
2. Cursor movement lags
3. Requests stall and enter retry loops
4. Eventually: complete failure

### 2. Terminal Disconnection (Orphaned Process)

When SSH/terminal disconnects:
- Claude process loses controlling terminal (TTY becomes `?`)
- Process is "adopted" by init (PPID becomes `1`)
- With `--dangerously-skip-permissions`, process continues running
- No way to send input or see output
- Process may spin consuming CPU with no useful work

### 3. Background Task Timeout

When running background agents (Gemini, Codex via Task tool):
- Sub-process times out waiting for response
- Parent Claude gets stuck waiting for result
- No error handler to break the loop

### 4. Session File Corruption

When resuming sessions:
- Corrupted `.jsonl` session file
- Missing messages in conversation history
- Session index mismatch with actual files

---

## Prevention Strategies

### 1. Configure Timeouts

Add to `~/.claude/settings.json`:

```json
{
  "env": {
    "BASH_DEFAULT_TIMEOUT_MS": "1800000",
    "BASH_MAX_TIMEOUT_MS": "7200000"
  }
}
```

### 2. Use Session Management

```bash
# Start with session naming for easier tracking
claude --session-name "feature-x" --dangerously-skip-permissions

# Check active sessions before starting new ones
ps aux | grep claude

# Kill orphaned sessions before resuming
pkill -f "claude.*resume" 2>/dev/null
```

### 3. Use tmux/screen for Long Sessions

```bash
# Start in tmux to prevent orphaning on disconnect
tmux new -s claude-session
claude --dangerously-skip-permissions

# Detach safely: Ctrl+B, then D
# Reattach: tmux attach -t claude-session
```

### 4. Monitor Context Usage

Watch for warning signs:
- Typing lag in terminal
- Slow response times
- Increasing memory usage

When detected:
```bash
# Check memory of Claude processes
ps aux | grep claude | awk '{print $2, $4"%", $11}'

# If memory > 10%, consider restarting session
```

### 5. Regular Checkpoint/Restart

For long-running work:
- Create git commits frequently
- Update progress files
- Restart Claude session every 4-8 hours

---

## Handling Stuck/Orphaned Processes

### Identify Orphaned Processes

```bash
# Find orphaned Claude processes (PPID=1 or TTY=?)
ps -eo pid,ppid,tty,etime,%cpu,%mem,cmd | grep claude | grep -E '(^\s*[0-9]+\s+1\s|\s+\?\s+)'

# Show all Claude processes with details
ps aux | grep -E 'claude.*(resume|skip-permissions)' | grep -v grep
```

### Safe Cleanup Script

```bash
#!/bin/bash
# ~/.claude/scripts/cleanup-orphans.sh

echo "=== Orphaned Claude Processes (PPID=1) ==="
ps -eo pid,ppid,tty,etime,cmd | grep claude | grep -E '^\s*[0-9]+\s+1\s'

echo ""
echo "=== Claude Processes with no TTY ==="
ps -eo pid,ppid,tty,etime,cmd | grep claude | grep '\s?\s'

read -p "Kill orphaned processes? (y/N): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    # Kill orphans (PPID=1)
    ps -eo pid,ppid,cmd | grep claude | awk '$2==1 {print $1}' | xargs -r kill
    echo "Orphaned processes terminated."
fi
```

### Force Kill Stuck Process

```bash
# Graceful termination
kill <PID>

# If still running after 10 seconds
kill -9 <PID>
```

---

## Quick Reference: Process States

| TTY | PPID | State | Meaning |
|-----|------|-------|---------|
| `pts/X` | >1 | Normal | Attached to terminal |
| `?` | 1 | Orphan | Terminal disconnected, adopted by init |
| `?` | >1 | Background | Intentional background process |
| Any | Any | `T` | Stopped (Ctrl+Z) |

---

## Recovery Checklist

When Claude gets stuck:

1. [ ] Check if process has network connections: `ss -tnp | grep <PID>`
2. [ ] Check last file modification: `ls -la /proc/<PID>/fd | grep jsonl`
3. [ ] Check CPU usage: If high but no I/O = stuck loop
4. [ ] Safe to kill if:
   - No network connections
   - No recent file writes (>1 hour)
   - High CPU with no progress
5. [ ] After killing:
   - Check session files for corruption
   - Resume with `claude --resume`
   - Or start fresh session

---

## Related Resources

- [GitHub: Claude Code CLI Timeout Issues](https://github.com/anthropics/claude-code/issues?q=timeout)
- [GitHub: CLI Degradation Bug #17711](https://github.com/anthropics/claude-code/issues/17711)
- [Linux timeout(1) Manual](https://man7.org/linux/man-pages/man1/timeout.1.html)

---

*Document created: 2026-01-17*
*Last updated: 2026-01-17*
