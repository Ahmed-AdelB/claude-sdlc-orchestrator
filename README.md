# Claude Code SDLC Orchestrator

[![CI](https://github.com/Ahmed-AdelB/claude-sdlc-orchestrator/actions/workflows/ci.yml/badge.svg)](https://github.com/Ahmed-AdelB/claude-sdlc-orchestrator/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A comprehensive production-ready configuration for Claude Code with 96 specialized agents, 20+ slash commands, and tri-agent quality enforcement.

## Features

- **96 Specialized Agents** across 14 categories + special integration agents
- **20+ Slash Commands** for SDLC phases, AB Method, Git workflows
- **Tri-Agent Hooks** for quality enforcement (Claude + Codex + Gemini)
- **Multi-Model Routing** for optimal task assignment
- **MCP Integrations** for Git, GitHub, PostgreSQL, and Filesystem

## Quick Installation

```bash
curl -fsSL https://raw.githubusercontent.com/Ahmed-AdelB/claude-sdlc-orchestrator/main/install.sh | bash
```

## Manual Installation

```bash
# Clone the repository
git clone https://github.com/Ahmed-AdelB/claude-sdlc-orchestrator.git

# Backup existing config
cp -r ~/.claude ~/.claude.backup

# Copy configuration
cp -r claude-sdlc-orchestrator/.claude/* ~/.claude/

# Make hooks executable
chmod +x ~/.claude/hooks/*.sh
```

## Agent Categories (96 Agents)

| Category | Count | Description |
|----------|-------|-------------|
| 01-general-purpose | 6 | Orchestration, routing, context management |
| 02-planning | 8 | Requirements, architecture, tech specs |
| 03-backend | 10 | API development, frameworks, microservices |
| 04-frontend | 10 | React, Vue, Next.js, accessibility |
| 05-database | 6 | PostgreSQL, MongoDB, Redis, ORM, migrations |
| 06-testing | 8 | Unit, integration, E2E, coverage |
| 07-quality | 8 | Code review, QA, refactoring, documentation |
| 08-security | 6 | OWASP, penetration testing, compliance |
| 09-performance | 5 | Profiling, caching, load testing |
| 10-devops | 8 | CI/CD, Docker, Kubernetes, Terraform |
| 11-cloud | 5 | AWS, GCP, Azure, serverless |
| 12-ai-ml | 4 | ML engineering, prompt engineering, LangChain |
| 13-integration | 4 | Webhooks, APIs, MCP integration |
| 14-business | 4 | Business analysis, cost optimization |
| **Special (root)** | 2 | **codex-sdlc-developer**, **gemini-reviewer** |

### Special Integration Agents
- **codex-sdlc-developer**: SDLC-compliant code implementation using Codex CLI (GPT-5.1). Handles feature development, bug fixes, and code generation with tri-agent approval workflow.
- **gemini-reviewer**: Security and code quality review using Gemini CLI. Performs OWASP audits, best practice validation, and compliance checks.

## Slash Commands

### SDLC Phase Commands
```
/sdlc:brainstorm [feature]  - Phase 1: Gather requirements
/sdlc:spec [feature]        - Phase 2: Create specifications
/sdlc:plan [feature]        - Phase 3: Technical design
/sdlc:execute [feature]     - Phase 4: Implementation
/sdlc:status                - Phase 5: Progress tracking
```

### AB Method Commands
```
/create-task [desc]    - Define new task with specifications
/create-mission        - Break task into focused missions
/resume-mission        - Continue incomplete mission
/test-mission          - Generate tests for mission
/ab-master             - Master orchestrator command
```

### Git Workflow Commands
```
/commit [message]      - Smart commit with conventional format
/pr [title]            - Create pull request
/branch [name]         - Create feature branch
/sync                  - Sync with remote
```

### Multi-Model Commands
```
/codex [task]          - Execute via Codex CLI (GPT-5.1)
/gemini [task]         - Execute via Gemini CLI (3 Pro)
/consensus [task]      - Tri-agent consensus review
```

## 5-Phase Development Discipline

1. **Brainstorm** - Gather requirements, ask clarifying questions
2. **Document** - Create specifications with acceptance criteria
3. **Plan** - Technical design, mission breakdown (AB Method)
4. **Execute** - Implement with parallel/sequential agents
5. **Track** - Monitor progress, update stakeholders

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

## Hooks System

### Pre-Commit Hook
Runs before git commits:
- Secrets detection
- Debug code detection
- File size validation
- Linting checks
- Type checking
- Tri-agent review (optional)

### Post-Edit Hook
Runs after file edits:
- Auto-formatting (Prettier, Black, gofmt)
- Lint fix (ESLint, Ruff)
- Syntax validation
- TODO/FIXME detection

### Quality Gate Hook
Runs on task completion:
- Test coverage check (minimum 80%)
- Test execution
- Linting errors
- Type errors
- Security vulnerabilities
- Documentation check

## Configuration

### Environment Variables

```bash
# Hook behavior: automatic | ask | disabled
export CLAUDE_HOOK_MODE="ask"

# Tri-agent review on commits
export TRI_AGENT_REVIEW="false"

# Minimum test coverage
export MIN_TEST_COVERAGE="80"

# Require tests to exist
export REQUIRE_TESTS="true"

# Require documentation
export REQUIRE_DOCS="false"

# Auto-format on edit
export AUTO_FORMAT="true"

# Auto-fix lint issues
export AUTO_LINT_FIX="true"
```

### Thinking Mode Escalation

```
think        - Standard (4K tokens) - Simple tasks
think hard   - Extended (10K tokens) - Complex logic
ultrathink   - Maximum (32K tokens) - Architecture, debugging
```

## Quality Gates

- All PRs require: `/review` + `/test`
- Security-sensitive code: `/security-review`
- Architecture changes: architect agent approval
- Critical changes: Multi-agent consensus (Claude + Codex + Gemini)
- Minimum test coverage: 80%
- Zero critical security vulnerabilities

## Tri-Agent Consensus

For critical changes, use the consensus workflow:

```
/consensus [task]
```

This invokes:
1. **Claude Code** - Primary implementation
2. **Codex CLI** - Implementation review
3. **Gemini CLI** - Security/compliance review

Approval requires:
- **3/3 unanimous** for critical changes
- **2/3 majority** for standard changes

## MCP Servers

Configured MCP servers:
- **git** - Version control operations
- **github** - Issues, PRs, repos via API
- **postgres** - Database queries and schema
- **filesystem** - File system access

## Commit Format

```
type(scope): description

Body explaining what and why

Tri-Agent Approval:
- Claude Code (Sonnet): APPROVE
- Codex (GPT-5.1): APPROVE
- Gemini (3 Pro): APPROVE

Co-Authored-By: Claude <noreply@anthropic.com>
```

## AI Stack Requirements

- **Claude Max** ($200/mo) - Primary orchestrator, 900 msg/5hr
- **ChatGPT Pro** ($200/mo) - Codex CLI for prototyping
- **Google AI Pro** ($20/mo) - Gemini 3 Pro, 1M context

## Directory Structure

```
~/.claude/
├── CLAUDE.md              # Global instructions
├── settings.json          # Permissions and hooks
├── .mcp.json              # MCP server config
├── README.md              # This documentation
├── agents/                # 85+ specialized agents
│   ├── 01-general-purpose/
│   ├── 02-planning/
│   ├── 03-backend/
│   ├── 04-frontend/
│   ├── 05-database/
│   ├── 06-testing/
│   ├── 07-quality/
│   ├── 08-security/
│   ├── 09-performance/
│   ├── 10-devops/
│   ├── 11-cloud/
│   ├── 12-ai-ml/
│   ├── 13-integration/
│   └── 14-business/
├── commands/              # 20+ slash commands
│   ├── sdlc/              # SDLC phase commands
│   ├── ab-method/         # AB Method commands
│   ├── git/               # Git workflow commands
│   ├── multi-model/       # Multi-model commands
│   └── utility/           # Utility commands
└── hooks/                 # Automation hooks
    ├── pre-commit.sh
    ├── post-edit.sh
    └── quality-gate.sh
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run quality gates
5. Submit a pull request

## License

MIT License - See LICENSE file for details.

## Support

- GitHub Issues: https://github.com/Ahmed-AdelB/claude-sdlc-orchestrator/issues
- Documentation: https://github.com/Ahmed-AdelB/claude-sdlc-orchestrator/wiki
