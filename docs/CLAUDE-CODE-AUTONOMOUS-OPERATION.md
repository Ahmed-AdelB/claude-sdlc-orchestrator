# Claude Code Autonomous & Continuous Operation Guide

## Complete Reference for 24+ Hour Unattended Operation

**Version:** 1.0.0
**Last Updated:** December 2025
**Author:** AI Development Configuration System

---

## Table of Contents

1. [Overview](#overview)
2. [Operation Modes](#operation-modes)
3. [Method 1: YOLO Mode](#method-1-yolo-mode---dangerously-skip-permissions)
4. [Method 2: Auto-Accept Mode](#method-2-auto-accept-mode)
5. [Method 3: Headless Mode](#method-3-headless-mode-with-allowed-tools)
6. [Method 4: Claude Agent SDK](#method-4-claude-agent-sdk)
7. [Method 5: Continuous Conversation Chain](#method-5-continuous-conversation-chain)
8. [Method 6: Background Tasks & Subagents](#method-6-background-tasks--subagents)
9. [Method 7: Safety Hooks](#method-7-hooks-for-safe-automation)
10. [Method 8: Session Persistence](#method-8-tmux--screen-for-persistence)
11. [Multi-Session Architecture](#multi-session-architecture-for-extended-tasks)
12. [Progress Tracking System](#progress-tracking-system)
13. [Container Isolation](#container-isolation-for-safety)
14. [Best Practices](#best-practices-for-24-hour-operation)
15. [Troubleshooting](#troubleshooting)
16. [Quick Start Templates](#quick-start-templates)
17. [API Reference](#api-reference)
18. [Resources](#resources)

---

## Overview

Claude Code can operate autonomously for extended periods (24+ hours) using various methods ranging from simple permission bypassing to sophisticated multi-agent architectures. This guide covers all available approaches with their trade-offs.

### Key Capabilities

| Capability | Description |
|------------|-------------|
| **Context Compaction** | Automatic summarization when context limit approaches |
| **Session Resume** | Continue from any previous session ID |
| **Subagents** | Parallel task execution with isolated contexts |
| **Background Tasks** | Keep dev servers running without blocking |
| **Hooks** | Custom scripts that intercept operations |
| **Headless Mode** | Non-interactive CLI execution |

### Choosing the Right Method

| Scenario | Recommended Method |
|----------|-------------------|
| Quick autonomous task (< 1 hour) | YOLO Mode |
| Supervised development | Auto-Accept Mode |
| CI/CD pipelines | Headless Mode |
| Production agents (24+ hours) | Claude Agent SDK |
| Multi-feature development | Multi-Session Architecture |
| Security-sensitive work | Container + Hooks |

---

## Operation Modes

### Mode Comparison

| Mode | Permissions | Duration | Safety | Use Case |
|------|-------------|----------|--------|----------|
| Normal | All prompts | Manual | Highest | Learning, sensitive work |
| Auto-Accept | Auto-approve edits | Session | High | Supervised development |
| YOLO | No prompts | Until done | Low | Isolated environments |
| Headless | Pre-configured | Script | Medium | Automation, CI/CD |
| SDK | Programmable | Unlimited | Configurable | Production agents |

---

## Method 1: YOLO Mode (--dangerously-skip-permissions)

### Basic Usage

```bash
# Enter YOLO mode - bypasses ALL permission prompts
claude --dangerously-skip-permissions

# With initial prompt
claude --dangerously-skip-permissions -p "Build the entire authentication system"

# Short form (if configured)
claude -y  # Some configurations support this alias
```

### What Gets Bypassed

- ✅ File read/write permissions
- ✅ Bash command execution
- ✅ Edit confirmations
- ✅ Tool usage approvals
- ✅ MCP server operations
- ⚠️ Still respects deny rules in settings.json

### Safety Configuration

Even in YOLO mode, you can restrict operations via `~/.claude/settings.json`:

```json
{
  "permissions": {
    "deny": [
      "Bash(rm -rf /)",
      "Bash(rm -rf ~)",
      "Bash(sudo:*)",
      "Write(.env)",
      "Write(*secret*)",
      "Write(*password*)",
      "Write(~/.ssh/*)"
    ]
  }
}
```

### YOLO Mode with Task File

```bash
# Create task specification
cat > AUTONOMOUS_TASK.md << 'EOF'
# Autonomous Development Task

## Objective
Build a complete REST API with authentication

## Requirements
1. User registration and login (JWT)
2. CRUD operations for resources
3. Input validation with Zod
4. Error handling middleware
5. Unit tests (80% coverage minimum)
6. API documentation

## Completion Criteria
- All tests pass
- No TypeScript errors
- Linting passes
- Documentation complete

## Instructions
Work through each requirement. After each:
1. Write tests first (TDD)
2. Implement feature
3. Run tests to verify
4. Commit with descriptive message
5. Update progress below

## Progress
- [ ] Project setup
- [ ] User registration
- [ ] User login
- [ ] JWT middleware
- [ ] Resource CRUD
- [ ] Validation
- [ ] Error handling
- [ ] Tests
- [ ] Documentation
EOF

# Launch autonomous mode
claude --dangerously-skip-permissions -p "Read AUTONOMOUS_TASK.md and complete all tasks"
```

### When to Use YOLO Mode

✅ **Good for:**
- Isolated development environments
- Docker containers without network
- Well-defined, bounded tasks
- Trusted codebases
- Personal projects

❌ **Avoid for:**
- Production servers
- Systems with sensitive data
- Network-connected environments
- Shared development machines
- Tasks without clear boundaries

---

## Method 2: Auto-Accept Mode

### Keyboard Shortcut

```
Shift+Tab  →  Cycles through modes:

  1. Normal Mode (default)
     └── Prompts for ALL operations

  2. Auto-Accept Mode
     └── Shows "accept edits on"
     └── Auto-approves file edits
     └── Auto-approves safe bash commands
     └── Still shows what's happening
     └── You can intervene if needed

  3. Back to Normal Mode
```

### Visual Indicator

When Auto-Accept is enabled, you'll see in the UI:
```
┌─────────────────────────────────────────┐
│  Claude Code [auto-accept edits on]     │
└─────────────────────────────────────────┘
```

### Best Practices for Auto-Accept

1. **Monitor the output** - Watch for unexpected operations
2. **Have git ready** - Easy rollback with `git checkout .`
3. **Set boundaries** - Clear task scope before enabling
4. **Use for sessions** - Disable when done with focused work

---

## Method 3: Headless Mode with Allowed Tools

### Basic Headless Execution

```bash
# Simple prompt execution
claude -p "Analyze this codebase and list all API endpoints"

# With output format
claude -p "Summarize the project structure" --output-format json

# Stream output in real-time
claude -p "Run tests and fix failures" --output-format stream-json
```

### Allowed Tools Configuration

```bash
# Allow specific tools without prompting
claude -p "Implement user authentication" \
  --allowedTools "Bash,Read,Write,Edit,Glob,Grep"

# Granular bash permissions
claude -p "Run tests and commit changes" \
  --allowedTools "Bash(npm:*),Bash(git:*),Read,Edit"

# Very specific permissions
claude -p "Fix TypeScript errors" \
  --allowedTools "Bash(npx tsc:*),Bash(npm run:*),Read,Edit(./src/**)"
```

### Tool Permission Patterns

| Pattern | Description | Example |
|---------|-------------|---------|
| `Tool` | Allow all uses of tool | `Bash` |
| `Tool(prefix:*)` | Allow with command prefix | `Bash(npm:*)` |
| `Tool(exact)` | Allow exact command | `Bash(npm test)` |
| `Tool(path)` | Allow for specific path | `Read(./src/**)` |
| `Tool(domain:x)` | Allow for domain | `WebFetch(domain:github.com)` |

### Common Allowed Tools Sets

```bash
# Development (safe)
--allowedTools "Read,Glob,Grep,WebSearch"

# Development (with edits)
--allowedTools "Read,Write,Edit,Glob,Grep"

# Full development
--allowedTools "Bash(npm:*),Bash(npx:*),Bash(git:*),Read,Write,Edit,Glob,Grep"

# Testing only
--allowedTools "Bash(npm test:*),Bash(npm run test:*),Read"

# CI/CD pipeline
--allowedTools "Bash(npm:*),Bash(git diff:*),Bash(git status),Read,Glob,Grep"
```

### Structured Output

```bash
# Get JSON output with metadata
claude -p "List all React components" --output-format json

# Response structure:
# {
#   "result": "...",
#   "session_id": "abc123",
#   "cost_usd": 0.05,
#   "duration_ms": 1234,
#   "tokens": { "input": 500, "output": 200 }
# }

# With JSON Schema validation
claude -p "Extract API endpoints from routes.ts" \
  --output-format json \
  --json-schema '{
    "type": "object",
    "properties": {
      "endpoints": {
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "method": {"type": "string"},
            "path": {"type": "string"},
            "handler": {"type": "string"}
          }
        }
      }
    },
    "required": ["endpoints"]
  }'
```

### Parsing Headless Output

```bash
# Extract just the result
claude -p "What is the main entry point?" --output-format json | jq -r '.result'

# Get session ID for resume
SESSION=$(claude -p "Start analysis" --output-format json | jq -r '.session_id')

# Parse structured output
claude -p "List functions" --output-format json --json-schema '...' \
  | jq '.structured_output.functions[]'
```

---

## Method 4: Claude Agent SDK

### Installation

```bash
# TypeScript/Node.js
npm install @anthropic-ai/claude-agent-sdk

# Python
pip install anthropic-claude-agent-sdk
```

### Basic Agent (TypeScript)

```typescript
import { Agent, Session } from '@anthropic-ai/claude-agent-sdk';

// Create an agent
const agent = new Agent({
  systemPrompt: `You are a coding assistant.
    Complete tasks incrementally and commit progress.`,
  tools: ['Bash', 'Read', 'Write', 'Edit'],
  maxTokens: 100000,
});

// Run a session
async function runTask() {
  const session = new Session({ agent });

  const result = await session.run({
    prompt: 'Implement user authentication with JWT',
    onProgress: (event) => {
      console.log(`[${event.type}] ${event.message}`);
    },
  });

  console.log('Task completed:', result.summary);
  console.log('Session ID:', result.sessionId);
}

runTask();
```

### Basic Agent (Python)

```python
from claude_agent_sdk import Agent, Session

# Create an agent
agent = Agent(
    system_prompt="""You are a coding assistant.
    Complete tasks incrementally and commit progress.""",
    tools=['Bash', 'Read', 'Write', 'Edit'],
    max_tokens=100000,
)

# Run a session
def run_task():
    session = Session(agent=agent)

    result = session.run(
        prompt='Implement user authentication with JWT',
        on_progress=lambda event: print(f"[{event.type}] {event.message}")
    )

    print(f"Task completed: {result.summary}")
    print(f"Session ID: {result.session_id}")

run_task()
```

### Long-Running Agent with Auto-Resume

```python
from claude_agent_sdk import Agent, Session
import time
import json

class LongRunningProject:
    def __init__(self, project_dir: str):
        self.project_dir = project_dir
        self.progress_file = f"{project_dir}/claude-progress.json"
        self.agent = self._create_agent()

    def _create_agent(self) -> Agent:
        return Agent(
            system_prompt="""You are a senior developer working on a project.

            RULES:
            1. Read claude-progress.json at the start of each session
            2. Complete ONE feature per session
            3. Update progress file after each feature
            4. Commit changes with descriptive messages
            5. Run tests before marking complete
            6. If tests fail, fix and re-run

            NEVER:
            - Skip tests
            - Remove existing tests
            - Mark incomplete features as done
            """,
            tools=['Bash', 'Read', 'Write', 'Edit', 'Glob', 'Grep'],
            working_directory=self.project_dir,
            context_compaction=True,  # Enable automatic context management
        )

    def _load_progress(self) -> dict:
        try:
            with open(self.progress_file) as f:
                return json.load(f)
        except FileNotFoundError:
            return {"features": [], "completed": [], "current": None}

    def _is_complete(self) -> bool:
        progress = self._load_progress()
        return len(progress["features"]) == len(progress["completed"])

    def run_continuous(self, check_interval: int = 60):
        """Run continuously until all features are complete."""
        print(f"Starting continuous development in {self.project_dir}")

        session_count = 0
        while not self._is_complete():
            session_count += 1
            print(f"\n{'='*50}")
            print(f"Session {session_count}")
            print(f"{'='*50}")

            session = Session(agent=self.agent)
            result = session.run(
                prompt="Continue with the next incomplete feature.",
                on_progress=lambda e: print(f"  [{e.type}] {e.message}")
            )

            print(f"Session complete: {result.summary}")

            # Brief pause between sessions
            if not self._is_complete():
                print(f"Waiting {check_interval}s before next session...")
                time.sleep(check_interval)

        print("\n🎉 All features complete!")

# Usage
project = LongRunningProject("/home/user/my-project")
project.run_continuous()
```

### Subagents for Parallel Work

```typescript
import { Agent, Session, Subagent } from '@anthropic-ai/claude-agent-sdk';

const orchestrator = new Agent({
  systemPrompt: 'You coordinate development tasks across multiple agents.',
});

async function parallelDevelopment() {
  const session = new Session({ agent: orchestrator });

  // Spawn subagents for parallel work
  const [frontendResult, backendResult, testsResult] = await Promise.all([
    session.spawnSubagent({
      prompt: 'Build the React frontend components',
      workingDirectory: './frontend',
    }),
    session.spawnSubagent({
      prompt: 'Build the Express API backend',
      workingDirectory: './backend',
    }),
    session.spawnSubagent({
      prompt: 'Write integration tests',
      workingDirectory: './tests',
    }),
  ]);

  // Merge results
  await session.run({
    prompt: `Integrate the completed work:
      Frontend: ${frontendResult.summary}
      Backend: ${backendResult.summary}
      Tests: ${testsResult.summary}

      Verify everything works together.`
  });
}
```

### Context Compaction

The SDK automatically compacts context when approaching limits:

```typescript
const agent = new Agent({
  systemPrompt: '...',
  contextCompaction: {
    enabled: true,
    threshold: 0.8,  // Compact at 80% of context limit
    strategy: 'summarize',  // 'summarize' | 'truncate' | 'selective'
    preserveRecent: 10,  // Keep last 10 messages intact
  },
});
```

---

## Method 5: Continuous Conversation Chain

### Basic Chain Script

```bash
#!/bin/bash
# continuous-development.sh

set -e

PROJECT_DIR="${1:-.}"
TASK_FILE="${2:-TASK.md}"
MAX_SESSIONS=100
SESSION_PAUSE=30

cd "$PROJECT_DIR"

echo "Starting continuous development..."
echo "Project: $PROJECT_DIR"
echo "Task file: $TASK_FILE"

# Initial session
RESULT=$(claude -p "Read $TASK_FILE and start working on the first incomplete task." \
  --output-format json \
  --allowedTools "Bash(npm:*),Bash(git:*),Read,Write,Edit,Glob,Grep")

SESSION_ID=$(echo "$RESULT" | jq -r '.session_id')
echo "Initial session: $SESSION_ID"

# Continuation loop
for i in $(seq 2 $MAX_SESSIONS); do
  echo ""
  echo "=== Session $i ==="

  RESULT=$(claude -p "Continue working. Complete the current task, update progress, then move to the next. If all tasks are complete, respond with exactly: ALL_TASKS_COMPLETE" \
    --resume "$SESSION_ID" \
    --output-format json \
    --allowedTools "Bash(npm:*),Bash(git:*),Read,Write,Edit,Glob,Grep")

  RESPONSE=$(echo "$RESULT" | jq -r '.result')

  if [[ "$RESPONSE" == *"ALL_TASKS_COMPLETE"* ]]; then
    echo "✅ All tasks completed!"
    exit 0
  fi

  echo "Session $i complete. Waiting ${SESSION_PAUSE}s..."
  sleep $SESSION_PAUSE
done

echo "⚠️ Reached maximum sessions ($MAX_SESSIONS)"
exit 1
```

### Advanced Chain with Error Recovery

```bash
#!/bin/bash
# robust-continuous.sh

set -e

LOG_FILE="claude-sessions.log"
ERROR_LOG="claude-errors.log"
STATE_FILE=".claude-state.json"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }
error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$ERROR_LOG"; }

save_state() {
  echo "{\"session_id\": \"$1\", \"iteration\": $2, \"timestamp\": \"$(date -Iseconds)\"}" > "$STATE_FILE"
}

load_state() {
  if [[ -f "$STATE_FILE" ]]; then
    cat "$STATE_FILE"
  else
    echo "{}"
  fi
}

run_session() {
  local prompt="$1"
  local session_id="$2"
  local resume_flag=""

  if [[ -n "$session_id" ]]; then
    resume_flag="--resume $session_id"
  fi

  claude -p "$prompt" \
    $resume_flag \
    --output-format json \
    --allowedTools "Bash(npm:*),Bash(npx:*),Bash(git:*),Read,Write,Edit,Glob,Grep" \
    2>> "$ERROR_LOG"
}

main() {
  local max_retries=3
  local retry_delay=60
  local session_delay=30
  local max_sessions=200

  log "Starting continuous development"

  # Load previous state if exists
  local state=$(load_state)
  local session_id=$(echo "$state" | jq -r '.session_id // empty')
  local start_iteration=$(echo "$state" | jq -r '.iteration // 1')

  if [[ -n "$session_id" ]]; then
    log "Resuming from session $session_id at iteration $start_iteration"
  fi

  for i in $(seq $start_iteration $max_sessions); do
    log "=== Iteration $i ==="

    local prompt
    if [[ $i -eq 1 ]] && [[ -z "$session_id" ]]; then
      prompt="Read TASK.md and begin working on the first task."
    else
      prompt="Continue with development. Complete current task, update TASK.md, commit changes, then proceed to next task. If all tasks are done, respond with: COMPLETED"
    fi

    local retries=0
    local success=false

    while [[ $retries -lt $max_retries ]] && [[ "$success" != "true" ]]; do
      if result=$(run_session "$prompt" "$session_id"); then
        success=true
        session_id=$(echo "$result" | jq -r '.session_id')
        save_state "$session_id" "$i"

        if echo "$result" | jq -r '.result' | grep -q "COMPLETED"; then
          log "✅ All tasks completed!"
          exit 0
        fi
      else
        retries=$((retries + 1))
        error "Session failed (attempt $retries/$max_retries)"
        if [[ $retries -lt $max_retries ]]; then
          log "Retrying in ${retry_delay}s..."
          sleep $retry_delay
        fi
      fi
    done

    if [[ "$success" != "true" ]]; then
      error "Failed after $max_retries attempts"
      exit 1
    fi

    log "Session complete. Waiting ${session_delay}s..."
    sleep $session_delay
  done

  log "Reached maximum sessions"
}

main "$@"
```

---

## Method 6: Background Tasks & Subagents

### Background Development Server

Claude Code can keep processes running in the background:

```bash
# In Claude Code, Claude can:

# 1. Start dev server in background
npm run dev &
DEV_PID=$!

# 2. Continue working while server runs
# Claude will make changes and test against running server

# 3. Server stays active throughout the session
```

### Subagent Delegation

```javascript
// Claude can spawn subagents for isolated tasks
// This happens automatically in SDK, or via prompting:

// Prompt to Claude:
`For this large refactoring task:
1. Spawn a subagent to handle frontend changes
2. Spawn a subagent to handle backend changes
3. Spawn a subagent to update tests
4. Coordinate the results and merge

Each subagent has its own context, preventing overflow.`
```

### Manual Subagent Pattern

```bash
# Terminal 1: Main orchestrator
claude --dangerously-skip-permissions -p "You are the orchestrator.
  Create task files for subagents in ./tasks/
  Monitor ./results/ for completed work
  Integrate results when all subagents complete"

# Terminal 2: Frontend subagent
claude --dangerously-skip-permissions -p "You are a frontend specialist.
  Read ./tasks/frontend.md
  Complete the task
  Write results to ./results/frontend.md"

# Terminal 3: Backend subagent
claude --dangerously-skip-permissions -p "You are a backend specialist.
  Read ./tasks/backend.md
  Complete the task
  Write results to ./results/backend.md"
```

---

## Method 7: Hooks for Safe Automation

### Hook System Overview

Hooks intercept Claude Code operations at specific points:

| Hook Event | When It Fires | Use Case |
|------------|---------------|----------|
| `PreToolUse` | Before any tool | Validate/block operations |
| `PostToolUse` | After any tool | Auto-format, logging |
| `Stop` | End of turn | Quality gates |
| `SubagentStop` | Subagent completes | Validate subagent output |

### Auto-Approve Hook

```bash
#!/bin/bash
# ~/.claude/hooks/auto-approve.sh
# Makes safe operations automatic while blocking dangerous ones

TOOL_NAME="${1:-}"
TOOL_INPUT="${2:-}"

# Always approve read-only operations
case "$TOOL_NAME" in
  Read|Glob|Grep|WebSearch|WebFetch)
    exit 0
    ;;
esac

# Approve safe write operations
if [[ "$TOOL_NAME" == "Write" ]] || [[ "$TOOL_NAME" == "Edit" ]]; then
  # Block sensitive files
  if [[ "$TOOL_INPUT" == *".env"* ]] || \
     [[ "$TOOL_INPUT" == *"secret"* ]] || \
     [[ "$TOOL_INPUT" == *"password"* ]] || \
     [[ "$TOOL_INPUT" == *"credential"* ]] || \
     [[ "$TOOL_INPUT" == *".ssh"* ]]; then
    echo "BLOCKED: Sensitive file modification"
    exit 1
  fi
  exit 0
fi

# Approve safe bash commands
if [[ "$TOOL_NAME" == "Bash" ]]; then
  # Whitelist safe commands
  SAFE_PATTERNS=(
    "npm test"
    "npm run"
    "npx "
    "git status"
    "git diff"
    "git log"
    "git add"
    "git commit"
    "ls "
    "cat "
    "echo "
    "node "
    "python "
    "pytest"
  )

  for pattern in "${SAFE_PATTERNS[@]}"; do
    if [[ "$TOOL_INPUT" == *"$pattern"* ]]; then
      exit 0
    fi
  done

  # Block dangerous commands
  DANGEROUS_PATTERNS=(
    "rm -rf"
    "sudo"
    "chmod 777"
    "> /dev"
    "mkfs"
    "dd if"
    "curl | sh"
    "wget | sh"
  )

  for pattern in "${DANGEROUS_PATTERNS[@]}"; do
    if [[ "$TOOL_INPUT" == *"$pattern"* ]]; then
      echo "BLOCKED: Dangerous command"
      exit 1
    fi
  done
fi

# Default: require approval
exit 1
```

### Configure Hooks in settings.json

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/auto-approve.sh \"$TOOL_NAME\" \"$TOOL_INPUT\""
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/auto-format.sh \"$TOOL_INPUT_FILE_PATH\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/quality-gate.sh"
          }
        ]
      }
    ]
  }
}
```

### Quality Gate Hook

```bash
#!/bin/bash
# ~/.claude/hooks/quality-gate.sh
# Runs at end of each turn to ensure quality

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")

echo "Running quality gates..."

FAILED=0

# TypeScript check
if [[ -f "$PROJECT_ROOT/tsconfig.json" ]]; then
  echo "  TypeScript..."
  if ! npx tsc --noEmit 2>/dev/null; then
    echo "  ❌ TypeScript errors"
    FAILED=1
  else
    echo "  ✅ TypeScript OK"
  fi
fi

# Linting
if [[ -f "$PROJECT_ROOT/.eslintrc.js" ]] || [[ -f "$PROJECT_ROOT/eslint.config.js" ]]; then
  echo "  ESLint..."
  if ! npx eslint . --quiet 2>/dev/null; then
    echo "  ❌ Linting errors"
    FAILED=1
  else
    echo "  ✅ Linting OK"
  fi
fi

# Tests
if [[ -f "$PROJECT_ROOT/package.json" ]] && grep -q '"test"' "$PROJECT_ROOT/package.json"; then
  echo "  Tests..."
  if ! npm test --passWithNoTests 2>/dev/null; then
    echo "  ❌ Tests failed"
    FAILED=1
  else
    echo "  ✅ Tests OK"
  fi
fi

if [[ $FAILED -eq 1 ]]; then
  echo "Quality gate: FAILED"
  exit 1
else
  echo "Quality gate: PASSED"
  exit 0
fi
```

---

## Method 8: tmux & Screen for Persistence

### tmux Setup

```bash
# Create persistent Claude session
tmux new-session -d -s claude-dev

# Start Claude in the session
tmux send-keys -t claude-dev "cd /path/to/project && claude --dangerously-skip-permissions" Enter

# Detach: Already detached (we used -d flag)

# Reattach later
tmux attach -t claude-dev

# List sessions
tmux list-sessions

# Kill session when done
tmux kill-session -t claude-dev
```

### tmux with Monitoring

```bash
#!/bin/bash
# claude-tmux.sh - Run Claude with monitoring

SESSION_NAME="claude-autonomous"
PROJECT_DIR="${1:-.}"
LOG_FILE="$PROJECT_DIR/claude-session.log"

# Create session with logging
tmux new-session -d -s "$SESSION_NAME"

# Split into panes: Claude + monitoring
tmux split-window -h -t "$SESSION_NAME"

# Left pane: Claude
tmux send-keys -t "$SESSION_NAME:0.0" \
  "cd $PROJECT_DIR && claude --dangerously-skip-permissions 2>&1 | tee $LOG_FILE" Enter

# Right pane: Monitoring
tmux send-keys -t "$SESSION_NAME:0.1" \
  "watch -n 5 'tail -20 $LOG_FILE && echo --- && git status --short'" Enter

# Attach to session
tmux attach -t "$SESSION_NAME"
```

### Screen Alternative

```bash
# Create screen session
screen -dmS claude-dev

# Run Claude in session
screen -S claude-dev -X stuff "claude --dangerously-skip-permissions\n"

# Attach
screen -r claude-dev

# Detach: Ctrl+A, D

# List sessions
screen -ls
```

---

## Multi-Session Architecture for Extended Tasks

### The Two-Agent Pattern

For tasks spanning many hours/days, use two specialized agents:

```
┌─────────────────────────────────────────────────────────────┐
│                    INITIALIZER AGENT                        │
│  Runs once at project start                                 │
│  Creates: init.sh, progress.json, features.json             │
│  Sets up: git repo, dependencies, environment               │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     CODING AGENT                            │
│  Runs in loop until all features complete                   │
│  Each session:                                              │
│    1. Read progress.json                                    │
│    2. Run init.sh to restore environment                    │
│    3. Complete ONE feature                                  │
│    4. Update progress.json                                  │
│    5. Commit changes                                        │
│    6. Exit (context resets)                                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    [Loop until complete]
```

### Implementation

```bash
# 1. Create project structure
mkdir -p my-big-project && cd my-big-project
git init

# 2. Initialize with first agent
cat > INIT_PROMPT.md << 'EOF'
You are the INITIALIZER AGENT. Set up this project:

1. Create init.sh that:
   - Installs dependencies
   - Starts dev server in background
   - Sets up environment

2. Create progress.json with structure:
   {
     "features": [
       {"id": 1, "name": "...", "status": "pending"},
       ...
     ],
     "current": null,
     "completed": []
   }

3. Create features.json with detailed specs for each feature

4. Set up basic project structure

5. Make initial commit

When done, output: INITIALIZATION_COMPLETE
EOF

claude -p "$(cat INIT_PROMPT.md)" --allowedTools "Bash,Read,Write,Edit"

# 3. Run coding agent in loop
cat > CODING_PROMPT.md << 'EOF'
You are the CODING AGENT. Each session you must:

1. Run: cat progress.json
2. Run: ./init.sh
3. Find the next pending feature
4. Implement it completely with tests
5. Run tests to verify
6. Update progress.json (mark complete, set next current)
7. Commit with message: "feat: [feature name]"

CRITICAL RULES:
- Complete exactly ONE feature per session
- NEVER skip tests
- NEVER remove existing tests
- Always update progress.json
- Always commit your changes

If all features are complete, output: ALL_FEATURES_COMPLETE
EOF

while true; do
  RESULT=$(claude -p "$(cat CODING_PROMPT.md)" \
    --output-format json \
    --allowedTools "Bash,Read,Write,Edit,Glob,Grep")

  if echo "$RESULT" | grep -q "ALL_FEATURES_COMPLETE"; then
    echo "Project complete!"
    break
  fi

  echo "Feature completed. Next session in 30s..."
  sleep 30
done
```

### Progress File Format

```json
{
  "project": "my-big-project",
  "started": "2025-12-27T00:00:00Z",
  "features": [
    {
      "id": 1,
      "name": "User Authentication",
      "description": "JWT-based auth with login/register",
      "status": "completed",
      "completedAt": "2025-12-27T02:30:00Z",
      "commit": "abc1234"
    },
    {
      "id": 2,
      "name": "Product Catalog",
      "description": "CRUD API for products",
      "status": "in_progress",
      "startedAt": "2025-12-27T02:35:00Z"
    },
    {
      "id": 3,
      "name": "Shopping Cart",
      "description": "Cart management with sessions",
      "status": "pending"
    }
  ],
  "current": 2,
  "completed": [1],
  "totalSessions": 5,
  "lastSession": "2025-12-27T02:35:00Z"
}
```

---

## Progress Tracking System

### Simple Progress File

```markdown
# claude-progress.md

## Current Session
- Started: 2025-12-27 10:00
- Task: Implementing user authentication

## Completed
- [x] Project setup (commit: abc1234)
- [x] Database schema (commit: def5678)
- [x] User model (commit: ghi9012)

## In Progress
- [ ] Authentication middleware
  - [x] JWT generation
  - [x] JWT validation
  - [ ] Refresh tokens
  - [ ] Password hashing

## Pending
- [ ] Protected routes
- [ ] User profile API
- [ ] Tests

## Notes
- Using bcrypt for password hashing
- JWT expires in 1 hour
- Refresh tokens expire in 7 days

## Blockers
- None currently
```

### Git-Based Progress

```bash
# Use git commits as progress markers
# Claude should commit after each logical unit of work

# View progress
git log --oneline

# Example output:
# abc1234 feat: add user authentication
# def5678 feat: add product catalog CRUD
# ghi9012 feat: add shopping cart
# jkl3456 test: add auth tests
# mno7890 docs: add API documentation
```

---

## Container Isolation for Safety

### Docker Setup

```dockerfile
# Dockerfile.claude
FROM node:20-slim

# Install Claude Code
RUN npm install -g @anthropic-ai/claude-code

# Create workspace
WORKDIR /workspace

# Security: Run as non-root
RUN useradd -m claude
USER claude

# Entry point
ENTRYPOINT ["claude"]
```

### Run Isolated

```bash
# Build image
docker build -t claude-isolated -f Dockerfile.claude .

# Run WITHOUT network (safest)
docker run -it --rm \
  --network none \
  -v $(pwd):/workspace \
  claude-isolated --dangerously-skip-permissions

# Run with limited network (for npm install, etc.)
docker run -it --rm \
  --network bridge \
  -v $(pwd):/workspace \
  claude-isolated --dangerously-skip-permissions
```

### Docker Compose for Development

```yaml
# docker-compose.claude.yml
version: '3.8'

services:
  claude:
    build:
      context: .
      dockerfile: Dockerfile.claude
    volumes:
      - .:/workspace
    network_mode: none  # No network access
    stdin_open: true
    tty: true
    command: ["--dangerously-skip-permissions"]

  claude-with-network:
    build:
      context: .
      dockerfile: Dockerfile.claude
    volumes:
      - .:/workspace
    networks:
      - limited
    stdin_open: true
    tty: true
    command: ["--dangerously-skip-permissions"]

networks:
  limited:
    driver: bridge
    internal: true  # No external access
```

---

## Best Practices for 24+ Hour Operation

### 1. Use Version Control

```bash
# Initialize git before starting
git init
git add .
git commit -m "Initial state before autonomous work"

# Claude should commit frequently
# Easy rollback: git reset --hard HEAD~1
```

### 2. Define Clear Boundaries

```markdown
# TASK.md - Be specific!

## Scope
Build a user authentication system

## Included
- Login/register endpoints
- JWT tokens
- Password hashing
- Basic tests

## NOT Included (Do not implement)
- OAuth providers
- Two-factor auth
- Email verification
- Admin panel

## Completion Criteria
1. All endpoints return correct responses
2. Tests pass
3. No TypeScript errors
4. Passwords are hashed
```

### 3. Incremental Checkpoints

```bash
# Instruct Claude to checkpoint frequently
"After completing each function:
1. Run tests
2. Commit with descriptive message
3. Continue to next function"
```

### 4. Monitor Resources

```bash
# Watch system resources
watch -n 5 'ps aux | grep claude | head -5; echo "---"; free -h'

# Log output
claude --dangerously-skip-permissions 2>&1 | tee claude-$(date +%Y%m%d-%H%M%S).log
```

### 5. Set Timeouts

```bash
# Limit session duration
timeout 4h claude --dangerously-skip-permissions

# Or in script
#!/bin/bash
MAX_RUNTIME=14400  # 4 hours in seconds
START=$(date +%s)

while true; do
  ELAPSED=$(($(date +%s) - START))
  if [[ $ELAPSED -gt $MAX_RUNTIME ]]; then
    echo "Max runtime reached"
    exit 0
  fi

  # Run Claude session
  claude -p "Continue working" --allowedTools "..."

  sleep 30
done
```

### 6. Error Recovery

```bash
#!/bin/bash
# Run with automatic restart on failure

while true; do
  claude --dangerously-skip-permissions -p "Continue development"

  EXIT_CODE=$?
  if [[ $EXIT_CODE -eq 0 ]]; then
    echo "Completed successfully"
    break
  else
    echo "Session failed with code $EXIT_CODE. Restarting in 60s..."
    sleep 60
  fi
done
```

---

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Context overflow | Too much in single session | Use SDK with compaction, or multi-session |
| Session hangs | Waiting for input | Use --dangerously-skip-permissions |
| Permission denied | Hook blocking | Check hook logic, add to whitelist |
| Lost progress | No persistence | Use git commits, progress files |
| Memory issues | Long session | Restart periodically, use containers |

### Debug Mode

```bash
# Verbose output
DEBUG=claude:* claude --dangerously-skip-permissions

# Log all tool calls
claude -p "task" --output-format stream-json 2>&1 | tee debug.log
```

### Recovery Commands

```bash
# Revert all changes
git checkout .
git clean -fd

# Resume from last good state
git log --oneline  # Find last good commit
git reset --hard <commit>

# Check what Claude did
git diff HEAD~5  # Last 5 commits
```

---

## Quick Start Templates

### Template 1: Simple Autonomous Task

```bash
#!/bin/bash
# simple-autonomous.sh

cd /path/to/project

cat > TASK.md << 'EOF'
# Task: Fix all TypeScript errors

1. Run `npx tsc --noEmit` to find errors
2. Fix each error
3. Re-run to verify
4. Commit when all errors fixed

When complete, say: DONE
EOF

claude --dangerously-skip-permissions -p "Read TASK.md and complete the task"
```

### Template 2: Feature Development

```bash
#!/bin/bash
# feature-development.sh

PROJECT="$1"
FEATURE="$2"

cd "$PROJECT"

cat > "FEATURE_$FEATURE.md" << EOF
# Feature: $FEATURE

## Requirements
[Add specific requirements]

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Tests pass
- [ ] No TypeScript errors

## Implementation Notes
[Add any notes]
EOF

claude --dangerously-skip-permissions -p "Implement the feature described in FEATURE_$FEATURE.md"
```

### Template 3: Full Project Build

```bash
#!/bin/bash
# full-project.sh

mkdir -p "$1" && cd "$1"
git init

cat > PROJECT.md << 'EOF'
# Project: [Name]

## Overview
[Description]

## Tech Stack
- Node.js + Express
- TypeScript
- PostgreSQL
- Jest for testing

## Features
1. [ ] Feature 1
2. [ ] Feature 2
3. [ ] Feature 3

## Instructions
Work through each feature sequentially.
For each feature:
1. Create tests first
2. Implement feature
3. Verify tests pass
4. Commit changes
5. Update this file

When all features complete: PROJECT_COMPLETE
EOF

# Run initializer
claude -p "Set up this project according to PROJECT.md. Create package.json, tsconfig, basic structure." \
  --allowedTools "Bash(npm:*),Write,Edit"

# Run in loop
while true; do
  RESULT=$(claude -p "Continue building the project. Follow PROJECT.md instructions." \
    --output-format json \
    --allowedTools "Bash(npm:*),Bash(npx:*),Bash(git:*),Read,Write,Edit,Glob,Grep")

  if echo "$RESULT" | grep -q "PROJECT_COMPLETE"; then
    echo "✅ Project complete!"
    break
  fi

  sleep 30
done
```

---

## API Reference

### CLI Flags

| Flag | Description |
|------|-------------|
| `-p, --print` | Headless mode with prompt |
| `--dangerously-skip-permissions` | YOLO mode |
| `--allowedTools` | Pre-approve specific tools |
| `--output-format` | `text`, `json`, `stream-json` |
| `--json-schema` | Validate output structure |
| `--continue` | Continue last conversation |
| `--resume <id>` | Resume specific session |
| `--system-prompt` | Replace system prompt |
| `--append-system-prompt` | Add to system prompt |

### Output Format (JSON)

```json
{
  "result": "The response text",
  "session_id": "ses_abc123",
  "cost_usd": 0.05,
  "duration_ms": 5000,
  "tokens": {
    "input": 1000,
    "output": 500
  },
  "structured_output": {},
  "tool_calls": [
    {
      "tool": "Edit",
      "input": "...",
      "output": "..."
    }
  ]
}
```

### Environment Variables

| Variable | Description |
|----------|-------------|
| `ANTHROPIC_API_KEY` | API authentication |
| `CLAUDE_CODE_MODEL` | Model override |
| `MAX_THINKING_TOKENS` | Thinking budget |
| `MCP_TIMEOUT` | MCP server timeout |

---

## Resources

### Official Documentation
- [Claude Code Docs](https://code.claude.com/docs)
- [Headless Mode](https://code.claude.com/docs/en/headless)
- [Claude Agent SDK](https://github.com/anthropics/claude-agent-sdk-typescript)
- [Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices)

### Guides
- [Long-Running Agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [Building Agents with SDK](https://www.anthropic.com/engineering/building-agents-with-the-claude-agent-sdk)
- [Safe YOLO Mode](https://blog.promptlayer.com/claude-dangerously-skip-permissions/)

### Community
- [Claude Code GitHub](https://github.com/anthropics/claude-code)
- [Discussions](https://github.com/anthropics/claude-code/discussions)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | Dec 2025 | Initial comprehensive guide |

---

*This document is part of the AI Development Configuration System.*
*Location: ~/.claude/docs/CLAUDE-CODE-AUTONOMOUS-OPERATION.md*
