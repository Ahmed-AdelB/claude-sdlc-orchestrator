# System Operations Guide

This document provides operational guidelines for the Tri-Agent Orchestrator system, including quick start procedures, worker management, troubleshooting, configuration, and API references.

## 1. Quick Start Guide

### Prerequisites
- Linux environment (or WSL2)
- Docker (optional, for sandboxed execution)
- `tmux` and `jq` installed
- API keys for Anthropic, Google Gemini, and OpenAI (Codex) configured in your environment.

### Initialization
Run the setup script to initialize the environment and install dependencies:

```bash
~/.claude/autonomous/setup.sh
```

### Starting the System
You can start the system in different modes depending on your needs.

#### Standard Tri-Agent Mode
This is the recommended mode where Claude orchestrates tasks, delegating to Gemini for analysis and Codex for implementation.

```bash
tri-agent --mode tri-agent ~/projects/my-project
```

#### Autonomous Mode (Single Model)
Runs with a single model (defaulting to Claude) but with delegation hints enabled.

```bash
tri-agent --mode autonomous ~/projects/my-project
```

#### Consensus Mode
Requires majority approval from models for critical decisions.

```bash
tri-agent --mode consensus ~/projects/my-project
```

#### Legacy 24-Hour Session
Starts a persistent session using the legacy launcher.

```bash
claude-24h ~/projects/my-project
```

## 2. Worker Management Commands

The system uses a supervisor-worker architecture to manage tasks.

### Service Management
The system is designed to run as a systemd user service.

**Enable and Start Service:**
```bash
systemctl --user enable tri-agent-supervisor
systemctl --user start tri-agent-supervisor
```

**Check Status:**
```bash
systemctl --user status tri-agent-supervisor
```

**Stop Service:**
```bash
systemctl --user stop tri-agent-supervisor
```

### Manual Worker Operations
You can manually interact with workers using the CLI tools in `bin/`.

**Start a Worker:**
```bash
tri-agent-worker --type <type> --id <worker-id>
```

**Start the Supervisor:**
```bash
tri-agent-supervisor --config config/tri-agent-supervisor.service
```

**Task Queue Management:**
Use `tri-agent-queue` or the legacy `task-queue.sh` to manage tasks.

```bash
# List tasks
tri-agent-queue list

# Add a task
tri-agent-queue add "Refactor authentication module"
```

## 3. Troubleshooting Common Issues

### Session Won't Start
**Symptoms:** `tri-agent` command exits immediately or fails to attach.

**Checks:**
1.  **Verify Prerequisites:** Ensure `tmux`, `jq`, and `curl` are installed.
2.  **Check Logs:** Inspect `~/.claude/autonomous/logs/` for startup errors.
    ```bash
    tail -n 50 ~/.claude/autonomous/logs/tri-agent.log
    ```
3.  **Kill Stale Sessions:**
    ```bash
    tmux kill-session -t tri-agent
    ```

### Model Availability Issues
**Symptoms:** Tasks failing with "model unavailable" or authentication errors.

**Checks:**
1.  **API Keys:** specific environment variables (`ANTHROPIC_API_KEY`, `GOOGLE_API_KEY`, `OPENAI_API_KEY`) must be set.
2.  **Circuit Breaker Status:** Check if a model is "OPEN" due to too many failures.
    ```bash
    health-check --status
    ```
3.  **Connectivity:** Run the preflight check.
    ```bash
    tri-agent-preflight --full
    ```

### Task Queue Stuck
**Symptoms:** Tasks remain in "pending" or "running" state indefinitely.

**Resolution:**
1.  **Check Supervisor:** Ensure `tri-agent-supervisor` is running.
2.  **Inspect Worker Logs:** Check `logs/worker/` for specific worker errors.
3.  **Reset Queue:** (Use with caution)
    ```bash
    # Manually move tasks from running back to queue or failed
    mv tasks/running/* tasks/queue/ 
    ```

## 4. Configuration Reference

The primary configuration file is `config/tri-agent.yaml`.

### Key Sections

#### `models`
Defines available models, their roles, and specific settings.
```yaml
models:
  claude:
    role: "orchestrator"
    model: "opus"
    max_budget_usd: 50
  gemini:
    role: "analyst"
    context_window: 1000000
  codex:
    role: "implementer"
    sandbox_mode: "workspace-write"
```

#### `routing`
Controls how tasks are distributed among agents.
```yaml
routing:
  auto_detect: true
  file_size_threshold: 51200 # Bytes
  keywords:
    gemini: ["analyze", "codebase"]
    codex: ["implement", "fix"]
```

#### `circuit_breaker`
Configures resilience patterns.
```yaml
circuit_breaker:
  failure_threshold: 3
  cooldown_seconds: 60
```

#### `security`
Defines secret masking patterns and excluded files.
```yaml
security:
  mask_secrets: true
  excluded_files: [".env", "*.key"]
```

### Environment Variables
- `AUTONOMOUS_ROOT`: Root directory of the autonomous system.
- `CLAUDE_LOG_FILE`: Custom log file path.
- `TRI_AGENT_MODE`: Default startup mode.

## 5. API Documentation

For detailed API documentation, please refer to [docs/API.md](API.md).

### Core Libraries
- **`lib/common.sh`**: Utilities for tracing, timestamping, and secret masking.
- **`lib/state.sh`**: State management with atomic locking.
- **`lib/circuit-breaker.sh`**: Logic for handling model failures and recovery.
- **`lib/cost-tracker.sh`**: Usage metrics and budget tracking.

### CLI Tools
- **`tri-agent-router`**: Intelligent task routing.
- **`tri-agent-consensus`**: Multi-model voting system.
- **`health-check`**: System status reporting.
- **`cost-tracker`**: Financial and token usage reporting.

### Integration
External tools can integrate by:
1.  Adding tasks to the queue directory structure.
2.  Invoking `tri-agent` with specific modes.
3.  Consuming JSON logs from `logs/`.
