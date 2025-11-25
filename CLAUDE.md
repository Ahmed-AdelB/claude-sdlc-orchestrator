# Global SDLC Orchestration System

## AI Stack ($420/month)
- **Claude Max** ($200): Primary orchestrator, 900 msg/5hr, Opus + Sonnet
- **ChatGPT Pro** ($200): Codex CLI for prototyping, o3-pro for debugging
- **Google AI Pro** ($20): Gemini 2.5/3 Pro, 1M token context

## 85+ Specialized Agents (14 Categories)
1. **General Purpose** (6): orchestrator, task-router, context-manager, session-manager, memory-coordinator, parallel-coordinator
2. **Planning** (8): requirements-analyst, architect, tech-spec-writer, risk-assessor, exponential-planner, product-manager, ux-researcher, tech-lead
3. **Backend** (10): backend-developer, api-architect, django-expert, fastapi-expert, nodejs-expert, rails-expert, go-expert, graphql-specialist, microservices-architect, authentication-specialist
4. **Frontend** (10): frontend-developer, react-expert, nextjs-expert, vue-expert, angular-expert, typescript-expert, ui-component-builder, shadcn-ui-adapter, accessibility-specialist, state-management-expert
5. **Database** (6): database-specialist, postgresql-expert, mongodb-expert, redis-expert, sql-optimizer, migration-specialist
6. **Testing** (8): test-generator, unit-test-specialist, integration-test-specialist, e2e-test-specialist, playwright-tester, vitest-tester, pytest-tester, test-coverage-analyst
7. **Quality** (8): code-reviewer, qa-validator, refactoring-specialist, code-archaeologist, rubber-duck-debugger, linter-specialist, documentation-writer, api-documentation-specialist
8. **Security** (6): security-auditor, owasp-specialist, penetration-tester, dependency-scanner, secrets-detector, compliance-checker
9. **Performance** (5): performance-optimizer, profiling-specialist, caching-specialist, load-testing-specialist, bundle-optimizer
10. **DevOps** (8): ci-cd-specialist, deployment-manager, docker-specialist, kubernetes-specialist, terraform-specialist, github-actions-specialist, monitoring-specialist, infrastructure-architect
11. **Cloud** (5): aws-architect, gcp-specialist, azure-specialist, serverless-specialist, multi-cloud-coordinator
12. **AI/ML** (4): ml-engineer, prompt-engineer, langchain-specialist, ai-agent-builder
13. **Integration** (4): integration-specialist, webhook-specialist, third-party-api-specialist, mcp-integration-specialist
14. **Business** (4): business-analyst, cost-optimizer, stakeholder-communicator, project-tracker

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
- Gemini (2.5 Pro): APPROVE

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
gemini -m gemini-2.5-pro "prompt"     # Specify model
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
