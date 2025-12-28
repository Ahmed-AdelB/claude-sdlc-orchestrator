# Claude Code 24-Hour Autonomous Operation

Complete system for running Claude Code continuously for 24+ hours without interruption.
Includes the legacy 24-hour launcher and the v2 tri-agent orchestrator (Claude + Gemini + Codex)
with routing, consensus, and diagnostics.

## Quick Start

```bash
# Run setup
~/.claude/autonomous/setup.sh

# Start a 24-hour session
claude-24h ~/projects/myapp

# Or with a specific task
claude-24h ~/projects/myapp ~/.claude/autonomous/tasks/sample-feature.md
```

### Tri-Agent Quick Start (v2)
```bash
# Ensure tri-agent utilities are on PATH
export PATH="$HOME/.claude/autonomous/bin:$PATH"

# Validate prerequisites
tri-agent --validate

# Start tri-agent session
tri-agent --mode tri-agent ~/projects/myapp
```

## Components

### 1. Settings Profile (`settings-autonomous.json`)
Permissive settings for autonomous operation:
- `bypassPermissions` mode - no confirmation prompts
- Expanded tool allowlist
- 32K thinking tokens
- Auto-checkpoint on stop

### 2. Launcher Script (`claude-24h.sh`)
Starts Claude in a persistent tmux session:
- Survives SSH disconnects
- Logs all output
- Supports task files

```bash
claude-24h [project_dir] [task_file]
claude-24h ~/projects/myapp
claude-24h ~/projects/myapp tasks/build-feature.md
```

### 3. Task Queue (`task-queue.sh`)
Process multiple tasks sequentially:

```bash
# Add tasks
claude-queue add "Build user authentication"
claude-queue add "Write integration tests"
claude-queue add-file ~/tasks/refactor.md

# View queue
claude-queue list

# Process all tasks
claude-queue process ~/projects/myapp

# Check status
claude-queue status
```

### 4. Monitor (`monitor.sh`)
Real-time dashboard showing:
- Session status and uptime
- Task queue progress
- Recent log activity
- Quick commands

```bash
claude-monitor           # Interactive dashboard
claude-monitor --watch   # Auto-refresh
claude-monitor --log     # Tail latest log
claude-monitor --summary # One-line status
```

### 5. Watchdog (`watchdog.sh`)
Auto-restarts crashed sessions:

```bash
claude-watchdog start ~/projects/myapp  # Start monitoring
claude-watchdog status                   # Check status
claude-watchdog stop                     # Stop monitoring
```

Features:
- Checks session every 30 seconds
- Auto-restarts with `--continue`
- Desktop notifications (if available)
- Restart cooldown to prevent loops

### 6. Docker Sandbox
Isolated environment for safe autonomous operation:

```bash
cd ~/.claude/autonomous
docker-compose up -d
docker-compose exec claude bash
claude-24h /workspace
```

### 7. Systemd Service
For 24/7 operation across reboots:

```bash
# Install
cp ~/.claude/autonomous/claude-autonomous.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable claude-autonomous

# Enable lingering (survive logouts)
sudo loginctl enable-linger $USER

# Start
systemctl --user start claude-autonomous

# Attach
tmux attach -t claude-autonomous
```

### 8. Tri-Agent CLI (v2) (`bin/tri-agent`)
Unified launcher with modes:
- `autonomous` (single-model with delegation hints)
- `tri-agent` (Claude orchestrates Gemini + Codex)
- `consensus` (multi-model voting for critical decisions)

```bash
tri-agent --mode tri-agent ~/projects/myapp
tri-agent --mode consensus ~/projects/myapp
```

### 9. Router & Consensus (v2)
Policy-driven routing and structured voting:
- `tri-agent-router` (routing via `config/routing-policy.yaml`)
- `tri-agent-consensus` (majority/weighted/veto voting)

```bash
tri-agent-router -f src/a.ts -f src/b.ts "Review these files"
tri-agent-consensus --mode weighted "Approve this API change?"
```

Legacy keyword router (backwards compatibility): `bin/tri-agent-route`.

### 10. Diagnostics & Metrics
Preflight validation, health checks, and usage metrics:

```bash
tri-agent-preflight --quick
health-check --status
cost-tracker summary
```

## Directory Structure

```
~/.claude/autonomous/
├── bin/                      # tri-agent utilities (tri-agent, router, consensus, ask)
├── config/                   # tri-agent.yaml, routing-policy.yaml, schema.yaml
├── lib/                      # shared shell libraries
├── settings-autonomous.json  # Legacy settings profile
├── settings-tri-agent.json   # Legacy tri-agent settings
├── claude-24h.sh             # Legacy 24h launcher
├── claude-tri-agent.sh       # Legacy tri-agent launcher
├── task-queue.sh             # Task queue processor
├── monitor.sh                # Session monitor
├── watchdog.sh               # Auto-resume watchdog
├── checkpoint.sh             # State checkpoint hook (legacy)
├── setup.sh                  # One-command setup
├── Dockerfile                # Docker sandbox
├── docker-compose.yml        # Docker orchestration
├── claude-autonomous.service # Systemd service
├── tasks/
│   ├── queue/                # Pending tasks (runtime)
│   ├── running/              # In-progress tasks (runtime)
│   ├── completed/            # Finished tasks (runtime)
│   └── failed/               # Failed tasks (runtime)
├── logs/
│   ├── sessions/             # Session logs
│   ├── errors/               # Error logs
│   ├── costs/                # Usage metrics
│   └── audit/                # Consensus/router audit logs
├── state/                    # Runtime state (health, breakers, locks)
└── sessions/                 # Checkpoint JSON files (legacy hook)
```

## Implementation Status
See `IMPLEMENTATION-STATUS.md` for phase-by-phase status (updated 2025-12-28).

## Usage Patterns

### Pattern 1: Single Long Task
```bash
claude-24h ~/projects/myapp tasks/big-refactor.md
```

### Pattern 2: Multiple Sequential Tasks
```bash
claude-queue add "Phase 1: Setup database models"
claude-queue add "Phase 2: Create API endpoints"
claude-queue add "Phase 3: Build frontend components"
claude-queue add "Phase 4: Write tests"
claude-queue add "Phase 5: Update documentation"
claude-queue process ~/projects/myapp
```

### Pattern 3: Resilient Operation
```bash
# Start session
claude-24h ~/projects/myapp

# Start watchdog in another terminal
claude-watchdog start ~/projects/myapp

# Monitor progress
claude-monitor --watch
```

### Pattern 4: Safe Sandbox Mode
```bash
cd ~/.claude/autonomous
docker-compose up -d
docker-compose exec claude bash

# Inside container
claude-queue add "Implement risky feature"
claude-queue process /workspace
```

## Tri-Agent CLI (v2) Usage
```bash
# Start tri-agent session (recommended)
tri-agent --mode tri-agent ~/projects/myapp

# Autonomous single-model mode via tri-agent
tri-agent --mode autonomous ~/projects/myapp

# Consensus mode (requires 2/3 model approval)
tri-agent --mode consensus ~/projects/myapp

# One-off routing with file context
tri-agent-router -f src/api.ts -f src/types.ts "Review API contracts"

# Explicit consensus vote for a decision
tri-agent-consensus --mode weighted "Approve this deployment plan?"
```

## CLI Flags Reference

### Core Autonomous Flags
```bash
--dangerously-skip-permissions    # Bypass all permission checks
--permission-mode bypassPermissions  # Alternative to above
--settings <file>                 # Load custom settings
--model opus                      # Use Opus for complex tasks
--continue                        # Resume last conversation
--resume <session-id>             # Resume specific session
```

### Print Mode (Non-Interactive)
```bash
-p "task description"             # Run task, print result, exit
--output-format json              # JSON output
--output-format stream-json       # Streaming JSON
```

### Tool Control
```bash
--allowedTools "Bash(*) Edit(*)"  # Only allow specific tools
--disallowedTools "Write(*.env)"  # Block specific tools
```

## Safety Considerations

1. **Permission Model**: The autonomous settings bypass permission prompts.
   Only use in sandboxed environments or for trusted tasks.

2. **Docker Isolation**: Use Docker for risky or untrusted tasks.

3. **Deny List**: Critical operations are still blocked:
   - `rm -rf /` and variants
   - System shutdown/reboot
   - Writing to .env, .ssh, credentials

4. **Watchdog Limits**: Max 10 restarts before stopping.

5. **Checkpoints**: State saved after each stop for recovery.

## Hooks and Checkpointing (Legacy Launchers)
Hooks are configured in `settings-autonomous.json` and `settings-tri-agent.json`.
Currently configured hook modes:

- **Stop**: Runs `checkpoint.sh` when the Claude CLI exits normally.

Behavior:
- Writes `checkpoint_YYYYMMDD_HHMMSS.json` to `~/.claude/autonomous/sessions/`
- Retains the latest 50 checkpoints
- Best-effort only; hard kills (e.g., `tmux kill-session`) may skip hook execution

Hook configuration shape (legacy settings JSON):
```json
{
  "hooks": {
    "Stop": [
      { "hooks": [ { "type": "command", "command": "..." } ] }
    ]
  }
}
```

## Troubleshooting

### Diagnostics (Tri-Agent v2)
```bash
# Preflight validation
tri-agent-preflight --quick
tri-agent-preflight --full

# Health status (writes state/health.json)
health-check --status
health-check --json

# Usage metrics
cost-tracker summary
cost-tracker daily 2025-12-27
```

### Session won't start
```bash
# Check Claude is installed
claude --version

# Check tmux is available
tmux -V

# Check for existing session
tmux ls
tmux kill-session -t claude-autonomous
```

### Session keeps dying
```bash
# Check logs
tail -100 ~/.claude/autonomous/logs/session_*.log

# Check for permission issues
ls -la ~/.claude/autonomous/

# Try interactive mode first
claude --dangerously-skip-permissions
```

### Task queue not processing
```bash
# Check queue status
claude-queue status

# Check for failed tasks
ls ~/.claude/autonomous/tasks/failed/

# Retry failed tasks
claude-queue retry
```

## Environment Variables

```bash
export ANTHROPIC_API_KEY="sk-..."     # Required for API auth
export CLAUDE_AUTONOMOUS_MODE=true     # Set by scripts
export CLAUDE_LOG_FILE="/path/to/log"  # Custom log location
export AUTONOMOUS_ROOT="$HOME/.claude/autonomous"  # Override repo root for tri-agent v2
export TRI_AGENT_MODE="tri-agent"      # Default mode for tri-agent launcher
export TRACE_ID="tri-YYYYMMDDHHMMSS-xxxx" # Optional trace correlation
```

## Integration with Other Tools

### With Claude Squad
```bash
cs new myfeature
cd $(cs worktree myfeature)
claude-24h . tasks/feature.md
```

### With CCManager
```bash
ccmanager add claude-autonomous
ccmanager switch claude-autonomous
```

### With Gemini CLI (Large Context)
```bash
# Offload large file analysis to Gemini
gemini-ask "Analyze this entire codebase and create a summary" > summary.md
claude-queue add "Use summary.md to plan refactoring"
```

Note: Run `gemini` interactively once to complete OAuth authentication before
using `gemini-ask`.
