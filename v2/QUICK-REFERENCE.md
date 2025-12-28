# Claude Code 24-Hour Operation - Quick Reference

**Verified Working:** 2025-12-28

## Commands (available after `source ~/.bashrc`)
Ensure both `~/bin` and `~/.claude/autonomous/bin` are on PATH:

```bash
export PATH="$HOME/bin:$HOME/.claude/autonomous/bin:$PATH"
```

```bash
# Start 24-hour session
claude-24h [project_dir] [task_file]
claude-24h ~/projects/myapp

# Task queue
claude-queue add "description"     # Add task
claude-queue add-file task.md      # Add from file
claude-queue list                  # List pending
claude-queue process ~/project     # Run all tasks
claude-queue status               # Show stats
claude-queue retry                # Retry failed

# Monitoring
claude-monitor                    # Dashboard
claude-monitor --summary          # One-line status
claude-monitor --log              # Tail logs

# Auto-restart
claude-watchdog start ~/project   # Start watchdog
claude-watchdog status            # Check status
claude-watchdog stop              # Stop watchdog
```

```bash
# Tri-Agent v2 (recommended)
tri-agent --mode tri-agent ~/projects/myapp
tri-agent --mode consensus ~/projects/myapp
tri-agent --validate
tri-agent --attach

# Router / consensus utilities
tri-agent-router "Analyze this codebase"
tri-agent-router -f src/a.ts -f src/b.ts "Review these files"
tri-agent-consensus --mode weighted "Approve this change?"

# Diagnostics & metrics
tri-agent-preflight --quick
health-check --status
cost-tracker summary
```

## Direct Claude CLI Flags

```bash
# Bypass all prompts (YOLO mode)
claude --dangerously-skip-permissions

# Non-interactive with task
claude -p "your task" --dangerously-skip-permissions

# Resume previous session
claude --continue
claude --resume <session-id>

# Custom settings
claude --settings ~/.claude/autonomous/settings-autonomous.json
```

## Tmux Session Management

```bash
# Attach to running session
tmux attach -t claude-autonomous

# Detach (keep running)
# Press: Ctrl+B, then D

# Kill session
tmux kill-session -t claude-autonomous

# List sessions
tmux ls
```

## Files Location

```
~/.claude/autonomous/
├── bin/                     # tri-agent utilities
├── config/                  # tri-agent.yaml, routing-policy.yaml
├── lib/                     # shared libs
├── settings-autonomous.json # Legacy settings
├── settings-tri-agent.json  # Legacy tri-agent settings
├── claude-24h.sh            # Legacy launcher
├── claude-tri-agent.sh      # Legacy tri-agent launcher
├── task-queue.sh            # Queue manager
├── monitor.sh               # Dashboard
├── watchdog.sh              # Auto-restart
├── tasks/                   # queue/running/completed/failed
├── logs/                    # sessions/errors/costs/audit
├── state/                   # health/breakers/locks
└── README.md                # Full docs
```

## Typical Workflow

```bash
# 1. Add tasks to queue
claude-queue add "Implement user authentication"
claude-queue add "Write unit tests"
claude-queue add "Update documentation"

# 2. Start processing with watchdog
claude-24h ~/projects/myapp &
claude-watchdog start ~/projects/myapp

# 3. Detach and let it run
# Press Ctrl+B, D

# 4. Check progress anytime
claude-monitor --summary

# 5. Reattach when needed
tmux attach -t claude-autonomous
```

## Tri-Agent Mode (Claude + Gemini + Codex)

```bash
# Launch tri-agent session (v2 recommended)
tri-agent --mode tri-agent ~/projects/myapp

# Legacy launcher (still supported)
~/.claude/autonomous/claude-tri-agent.sh ~/projects/myapp

# Inside Claude session, delegate to other models:
gemini-ask "Analyze entire codebase"           # 1M context
codex-ask "Implement this feature quickly"     # xhigh reasoning

# Auto-route to best model
tri-agent-router "analyze large codebase"      # → Gemini
tri-agent-router "implement user auth"         # → Codex
tri-agent-router "design architecture"         # → Claude

# Get consensus from all three
tri-agent-consensus "critical decision"
```

Legacy router: `tri-agent-route "task"` (keyword-only, no policy file).

### Model Capabilities

| Model | Best For | Context |
|-------|----------|---------|
| Claude Opus 4.5 | Architecture, complex reasoning | 200K |
| Gemini 3 Pro | Large codebase analysis | 1M |
| Codex GPT-5.2 | Rapid implementation | 400K |

### Note on Gemini
Before first use, run `gemini` interactively once to complete OAuth authentication.
