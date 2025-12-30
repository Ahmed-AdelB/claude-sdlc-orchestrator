# Global SDLC Orchestration System

## AI Stack ($420/month)
- **Claude Max** ($200): Primary orchestrator, 900 msg/5hr, Opus + Sonnet
- **ChatGPT Pro** ($200): Codex CLI for prototyping, o3-pro for debugging
- **Google AI Pro** ($20): Gemini 3 Pro, 1M token context

## 96 Specialized Agents (14 Categories + Special)
1. **General Purpose** (6): orchestrator, task-router, context-manager, session-manager, memory-coordinator, parallel-coordinator
2. **Planning** (8): requirements-analyst, architect, tech-spec-writer, risk-assessor, exponential-planner, product-manager, ux-researcher, tech-lead
3. **Backend** (10): backend-developer, api-architect, django-expert, fastapi-expert, nodejs-expert, rails-expert, go-expert, graphql-specialist, microservices-architect, authentication-specialist
4. **Frontend** (10): frontend-developer, react-expert, nextjs-expert, vue-expert, typescript-expert, css-expert, mobile-web-expert, testing-frontend, accessibility-expert, state-management-expert
5. **Database** (6): database-architect, postgresql-expert, mongodb-expert, redis-expert, orm-expert, migration-expert
6. **Testing** (8): test-generator, unit-test-specialist, integration-test-specialist, e2e-test-specialist, playwright-tester, vitest-tester, pytest-tester, test-coverage-analyst
7. **Quality** (8): code-reviewer, qa-validator, refactoring-expert, code-archaeologist, rubber-duck-debugger, linting-expert, documentation-expert, technical-debt-analyst
8. **Security** (6): security-auditor, owasp-specialist, penetration-tester, dependency-scanner, secrets-detector, compliance-checker
9. **Performance** (5): performance-optimizer, profiling-specialist, caching-specialist, load-testing-specialist, bundle-optimizer
10. **DevOps** (8): ci-cd-specialist, deployment-manager, docker-specialist, kubernetes-specialist, terraform-specialist, github-actions-specialist, monitoring-specialist, infrastructure-architect
11. **Cloud** (5): aws-architect, gcp-specialist, azure-specialist, serverless-specialist, multi-cloud-coordinator
12. **AI/ML** (4): ml-engineer, prompt-engineer, langchain-specialist, ai-agent-builder
13. **Integration** (4): integration-specialist, webhook-specialist, third-party-api-specialist, mcp-integration-specialist
14. **Business** (4): business-analyst, cost-optimizer, stakeholder-communicator, project-tracker

## Special Integration Agents (Root-Level)
- **codex-sdlc-developer**: Implements code changes using Codex CLI (GPT-5.1-Codex-Max) following SDLC best practices. Part of tri-agent architecture where Claude handles requirements, Codex handles implementation, and Gemini handles review. Use for feature implementation, bug fixes, and code development tasks.
- **gemini-reviewer**: Coordinates with Gemini CLI for code review and security analysis as part of tri-agent workflow. Expert in security vulnerabilities (OWASP Top 10), code quality validation, and design review. Use for security audits, compliance validation, and code quality scoring.

## 5-Phase Development Discipline (CCPM)
1. **Brainstorm**: `/sdlc:brainstorm` - Gather requirements, ask clarifying questions
2. **Document**: `/sdlc:spec` - Create specifications with acceptance criteria
3. **Plan**: `/sdlc:plan` - Technical design, mission breakdown (AB Method)
4. **Execute**: `/sdlc:execute` - Implement with parallel/sequential agents
5. **Track**: `/sdlc:status` - Monitor progress, update stakeholders

## Hybrid Adaptive Workflow
- **Sequential**: Dependent tasks (backend before frontend, types before components)
- **Parallel**: Independent tasks (git worktrees for isolation, CCPM pattern)
- **Decision Logic**: Task router determines execution mode based on dependencies

## Quality Gates (Never Compromise)
- All PRs require: `/review` + `/test`
- Security-sensitive code: `/security-review`
- Architecture changes: architect agent approval
- Critical changes: Multi-agent consensus (Claude + Codex + Gemini)
- Minimum test coverage: 80%
- Zero critical security vulnerabilities

## ENFORCED MULTI-AGENT PARALLELISM (CRITICAL REQUIREMENT)

### Minimum Agent Requirements
**ALWAYS run at least 9 CONCURRENT agents** (3 Claude + 3 Codex + 3 Gemini) at ANY time.
**Total invocations per task: 21 agents across 3 phases.**
**CRITICAL: At least 9 agents (3×3) MUST be running simultaneously throughout ALL work.**

| Activity Type | Min Concurrent | Distribution (3+3+3) |
|--------------|----------------|----------------------|
| **Planning** | 9 | 3 Claude (architecture, security, specs) + 3 Gemini (context, codebase, patterns) + 3 Codex (feasibility, complexity, APIs) |
| **Implementation** | 9 | 3 Claude (core code, tests, docs) + 3 Codex (implement, optimize, validate) + 3 Gemini (review, context, security) |
| **Verification** | 9 | 3 Claude (security, logic, edges) + 3 Gemini (context, patterns, regression) + 3 Codex (completeness, coverage, quality) |

**TOTAL PER TASK: 21 agent invocations (7 per phase × 3 phases)**

### How to Launch Parallel Agents

**Option 1: Use Task tool with multiple parallel agents**
```
Launch 9 agents in a SINGLE message with multiple Task tool calls:
- Task 1-3: Claude agents (architecture, security, specs)
- Task 4-6: Codex via bin/codex-delegate
- Task 7-9: Gemini via bin/gemini-delegate
```

**Option 2: Use CLI delegates in parallel**
```bash
# Launch all 9 in parallel using & and wait
gemini -y "Analyze architecture of: [context]" &
gemini -y "Review security of: [context]" &
gemini -y "Check patterns of: [context]" &
codex exec "Implement: [task]" &
codex exec "Generate tests for: [task]" &
codex exec "Optimize: [task]" &
# Claude runs inline as orchestrator (3 Task tool calls)
wait  # Wait for all background jobs
```

### Enforcement Checklist (Before Marking ANY Task Complete)
- [ ] **21 agents** were invoked across 3 phases (7 per phase)
- [ ] **9+ concurrent** agents ran simultaneously at peak
- [ ] All three AI models (Claude, Codex, Gemini) participated in EACH phase
- [ ] Implementation was verified by at least **2 non-implementing AIs**
- [ ] Security review completed by at least **2 AIs** from different models
- [ ] Todo was updated throughout the process with phase tracking

## MAXIMUM CAPABILITY USAGE (MANDATORY)

### Gemini Maximum Capability Configuration
```bash
# Gemini 3 Pro with full capabilities
gemini -m gemini-3-pro-preview -y --approval-mode yolo "prompt"
```

**Gemini Maximum Capabilities:**
- **1M token context**: Use for full codebase analysis, multi-file review
- **Pro routing**: Always routes to Gemini 3 Pro for complex tasks
- **High thinking**: Extended reasoning for architectural decisions

### Codex Maximum Capability Configuration
```bash
# Codex with GPT-5.2-Codex and xhigh reasoning
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s danger-full-access "task"
```

**Codex Maximum Capabilities:**
- **xhigh reasoning**: Maximum reasoning depth for complex problems
- **400K context**: Large codebase understanding
- **Full access**: Can modify files, run commands, access system

### Claude Maximum Capability Configuration
```
# In Claude Code, use: ultrathink before complex tasks
# Use Task tool with model="opus" for maximum capability
```

**Claude Maximum Capabilities:**
- **ultrathink (32K)**: Maximum reasoning for architecture, security
- **Opus model**: Deepest analysis and most thorough responses

## TRI-AI ACTIVE TODO MANAGEMENT (CRITICAL)

### All Three AIs MUST Update Todo
Every AI (Claude, Codex, Gemini) is responsible for:

1. **Adding new requirements discovered during work**
2. **Updating task status in real-time**
3. **Breaking down complex tasks into subtasks**
4. **Flagging blockers and dependencies**
5. **Recording verification results**

### How Each AI Updates Todo

**Claude (Primary Orchestrator):**
- Uses TodoWrite tool directly
- Coordinates todo updates from other AIs
- Synthesizes requirements from all sources

**Codex (via Claude orchestration):**
```bash
# Codex reports findings that Claude adds to todo:
codex exec "Analyze task and report: 1) New requirements found, 2) Subtasks needed, 3) Dependencies, 4) Blockers. Format as JSON for todo update."
```

**Gemini (via Claude orchestration):**
```bash
# Gemini provides comprehensive analysis for todo:
gemini -y "Analyze task context and report: 1) Additional requirements from codebase, 2) Hidden dependencies, 3) Security considerations, 4) Test requirements. Format as structured list."
```

### Active Todo Enforcement
```
BEFORE marking ANY task complete, verify:
- [ ] All user requirements addressed
- [ ] All Claude-identified requirements addressed
- [ ] All Codex-identified requirements addressed
- [ ] All Gemini-identified requirements addressed
- [ ] Plan file synced with todo
- [ ] No orphaned requirements
```

## 24-HOUR CONTINUOUS OPERATION (CRITICAL)

### Session Persistence Architecture

**Progress File Pattern** (Required for context resumption):
```bash
# Create/update claude-progress.txt at start of each session
cat > claude-progress.txt <<EOF
# Session Progress Log
## Last Updated: $(date -Iseconds)
## Session ID: ${SESSION_ID}

### Completed Tasks:
$(git log --oneline -20)

### Current State:
- Active branch: $(git branch --show-current)
- Uncommitted changes: $(git status --short | wc -l)
- Last checkpoint: ${LAST_CHECKPOINT}

### Next Actions:
[TODO items from previous session]
EOF
```

**State Persistence Locations:**
| State Type | Location | Backup Frequency |
|------------|----------|------------------|
| Task Queue | `state/tri-agent.db` (SQLite) | Real-time WAL |
| Progress Log | `claude-progress.txt` | Every commit |
| Checkpoints | `sessions/checkpoints/` | Every 5 minutes |
| Event Log | `state/event-store/events.jsonl` | Append-only |
| Git History | `.git/` | Every feature |

### Context Window Management (CRITICAL FOR 24HR)

**Token Budget Per Session:**
| Model | Context Window | Safe Working Limit | Refresh Trigger |
|-------|---------------|-------------------|-----------------|
| Claude Opus | 200K | 160K (80%) | 150K tokens used |
| Claude Sonnet | 200K | 160K (80%) | 150K tokens used |
| Gemini 3 Pro | 1M | 800K (80%) | 750K tokens used |
| Codex GPT-5.2 | 400K | 320K (80%) | 300K tokens used |

**Context Overflow Prevention:**
```bash
# Monitor context usage and trigger refresh
check_context_health() {
    local tokens_used=$1
    local model=$2

    case "$model" in
        claude*) limit=150000 ;;
        gemini*) limit=750000 ;;
        codex*)  limit=300000 ;;
    esac

    if [[ $tokens_used -gt $limit ]]; then
        # Checkpoint current state
        create_session_checkpoint
        # Summarize context with Gemini (largest context)
        gemini -y "Summarize the current session state for resumption: $(cat claude-progress.txt)"
        # Refresh session
        refresh_session
    fi
}
```

**Model Failover Chain (Context Overflow):**
```
Claude Sonnet (200K) → Gemini Pro (1M) → Split into sub-tasks
```

### Session Refresh Protocol (Every 8 Hours)

**Automatic Session Boundaries:**
```bash
SESSION_DURATION_HOURS=8
SESSION_REFRESH_ENABLED=true
CONTEXT_CHECKPOINT_INTERVAL=300  # 5 minutes

# At session boundary:
1. Checkpoint all in-progress work
2. Commit with descriptive message
3. Update claude-progress.txt
4. Generate session summary via Gemini
5. Clear context and reload essentials
6. Resume from checkpoint
```

**Session Refresh Command:**
```bash
# Force session refresh
tri-agent session-refresh --checkpoint --summarize

# Resume from last checkpoint
tri-agent session-resume --from-checkpoint latest
```

### Watchdog & Auto-Recovery Stack

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

**Heartbeat Configuration:**
```yaml
heartbeat:
  interval: 30s
  stale_threshold: 2m
  task_timeouts:
    lint: 5m
    test: 30m
    build: 30m
    default: 15m
  grace_multiplier: 1.5
```

### 24-Hour Budget Management

**Daily Token Budgets:**
| Model | Daily Limit | Hourly Average | Alert Threshold |
|-------|-------------|----------------|-----------------|
| Claude Max | ~100M tokens | 4.2M/hour | 80% daily |
| Gemini Pro | Unlimited* | N/A | API rate limits |
| Codex | ~50M tokens | 2.1M/hour | 80% daily |

**Cost Tracking Integration:**
```bash
# Track costs per session
cost-tracker --session ${SESSION_ID} --model claude --tokens ${TOKENS_USED}

# Check remaining budget
cost-tracker --status --daily

# Pause if budget exhausted
if [[ $(cost-tracker --remaining-percent) -lt 10 ]]; then
    log_warn "Budget low, pausing expensive operations"
    EXPENSIVE_OPERATIONS_PAUSED=true
fi
```

**Budget Reset Schedule:**
- Claude: Rolling 5-hour window + 7-day weekly cap
- Gemini: Daily reset at midnight UTC
- Codex: Daily reset at midnight UTC

### Progress Tracking Pattern

**Feature List JSON (Structured State):**
```json
{
  "session_id": "tri-24-001",
  "started_at": "2025-12-30T00:00:00Z",
  "features": [
    {"id": "F001", "name": "SQL injection fix", "status": "completed"},
    {"id": "F002", "name": "DLQ RUNNING state", "status": "completed"},
    {"id": "F003", "name": "30min threshold", "status": "completed"}
  ],
  "current_phase": "verification",
  "next_actions": ["Run tests", "Deploy to staging"],
  "blockers": [],
  "token_usage": {
    "claude": 45000,
    "gemini": 120000,
    "codex": 30000
  }
}
```

**Git Checkpoint Protocol:**
```bash
# After each feature completion
git add -A
git commit -m "feat(scope): description

Session: ${SESSION_ID}
Checkpoint: ${CHECKPOINT_NUM}
Tokens used: ${TOTAL_TOKENS}

🤖 Generated with [Claude Code](https://claude.com/claude-code)
Co-Authored-By: Claude <noreply@anthropic.com>"
```

### 24-Hour Operation Checklist

**Before Starting 24-Hour Session:**
- [ ] Verify watchdog-master is running
- [ ] Verify tri-24-monitor is active
- [ ] Check daily budget availability
- [ ] Initialize claude-progress.txt
- [ ] Create initial git checkpoint
- [ ] Configure session refresh (8-hour intervals)

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
- [ ] Rate limit → Exponential backoff

### Commands for 24-Hour Operation

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

## Multi-Model Routing
| Task Type | Primary Model | When to Use |
|-----------|---------------|-------------|
| Architecture & Design | Claude Opus | Deep reasoning, complex decisions |
| Implementation | Claude Sonnet | Standard coding, speed + quality |
| Rapid Prototyping | Codex CLI | Fast iteration, alternatives |
| Large Codebase Analysis | Gemini | Context > 100K tokens |
| Complex Debugging | o3-pro | Extended reasoning chains |
| Documentation | Gemini | Long-form writing |
| Code Review | Claude Sonnet | Balanced analysis |
| Security Audit | Claude Opus | Thorough vulnerability analysis |

## Thinking Mode Escalation
- Standard: `think` (4K tokens) - Simple tasks
- Extended: `think hard` (10K tokens) - Complex logic
- Maximum: `ultrathink` (32K tokens) - Architecture, debugging

## Slash Commands
### SDLC Phase Commands
- `/sdlc:brainstorm [feature]` - Phase 1: Requirements
- `/sdlc:spec [feature]` - Phase 2: Documentation
- `/sdlc:plan [feature]` - Phase 3: Technical design
- `/sdlc:execute [feature] [mission]` - Phase 4: Implementation
- `/sdlc:status` - Phase 5: Progress tracking

### AB Method Commands
- `/create-task [desc]` - Define new task with specs
- `/create-mission` - Break task into focused missions
- `/resume-mission` - Continue incomplete mission
- `/test-mission` - Generate tests for mission
- `/ab-master` - Orchestrate workflow

### Utility Commands
- `/feature [desc]` - Full feature workflow (all phases)
- `/bugfix [desc]` - Bug fix with root cause analysis
- `/test [target]` - Generate comprehensive tests
- `/review [target]` - Multi-agent code review
- `/security-review [target]` - OWASP vulnerability scan
- `/codex [task]` - Execute via Codex CLI
- `/route [type] [task]` - Route to optimal model
- `/context-prime` - Load project context

## Commit Format (Tri-Agent)
```
type(scope): description

Body explaining what and why

Tri-Agent Approval:
- Claude Code (Sonnet): APPROVE
- Codex (GPT-5.1): APPROVE
- Gemini (3 Pro): APPROVE

Co-Authored-By: Claude <noreply@anthropic.com>
```

## MCP Servers
- **git**: Version control operations
- **github**: Issues, PRs, repos via API
- **postgres**: Database queries and schema
- **filesystem**: File system access

## CLI Tool Usage (CRITICAL)

### Gemini CLI
**IMPORTANT**: Do NOT use deprecated `-p` flag!

```bash
# CORRECT - Use positional arguments
gemini "your prompt here"
gemini -y "prompt"                    # Auto-approve (YOLO mode)
gemini -m gemini-3-pro "prompt"       # Specify model
gemini --approval-mode yolo "prompt"  # Auto-approve all tools

# WRONG - Deprecated flag
gemini -p "prompt"  # DO NOT USE - deprecated, will be removed
```

### Gemini Session Pattern (Multi-turn Conversations)
Based on gemini_session_test.py - maintains conversation history across calls:

```python
import subprocess
import json
from pathlib import Path

HISTORY_PATH = Path("gemini_session.json")

def load_history():
    if HISTORY_PATH.exists():
        return json.loads(HISTORY_PATH.read_text())
    return []

def save_history(history):
    HISTORY_PATH.write_text(json.dumps(history, indent=2))

def build_conversation_prompt(history):
    """Build prompt with conversation context"""
    if len(history) <= 1:
        return history[0]["content"]

    prompt_parts = ["[Conversation History]"]
    for msg in history[:-1]:
        role = msg["role"].capitalize()
        prompt_parts.append(f"{role}: {msg['content']}")
    prompt_parts.append(f"\nUser: {history[-1]['content']}")
    prompt_parts.append("\nAssistant:")
    return "\n\n".join(prompt_parts)

def call_gemini(prompt):
    """Call Gemini CLI - use positional args, NOT -p flag"""
    result = subprocess.run(
        ["gemini", "-y", prompt],  # CORRECT: positional, NOT ["gemini", "-p", prompt]
        capture_output=True,
        text=True
    )
    if result.returncode != 0:
        raise RuntimeError(f"Gemini failed: {result.stderr}")
    return result.stdout.strip()
```

### Codex CLI (GPT-5.1)
```bash
# Non-interactive execution
codex exec "task description"
codex exec "Implement feature X" src/component.py

# With specific model
codex exec -m o3 "complex reasoning task"

# View help
codex --help
codex exec --help
```

### Tri-Agent CLI Pattern
```bash
# 1. Claude (primary orchestration) - Direct in Claude Code
# 2. Codex (implementation)
codex exec "Review and implement: <task>"

# 3. Gemini (validation/security)
gemini -y "Review for security issues: <code>"
```

## Code Style
- TypeScript: Strict mode, explicit types
- Python: Type hints, async/await for I/O
- Formatting: Prettier (JS/TS), Black (Python)
- Linting: ESLint, Ruff
- Commits: Conventional commits
