# Skills Directory

> **Location:** `~/.claude/skills/`
> **Status:** Structural Placeholder (Phase 1)
> **Version:** 1.0.0

## Overview

The skills directory contains workflow definitions and reusable procedures for the SDLC orchestration system. Skills are modular, hot-reloadable components that define how Claude handles specific types of tasks.

## What Are Skills?

Skills are declarative workflow definitions that:

1. **Encapsulate Expertise** - Package domain knowledge (security audits, code review, documentation) into reusable units
2. **Define Procedures** - Specify step-by-step workflows with decision points and quality gates
3. **Enable Hot-Reload** - Can be updated without restarting the session
4. **Support Composition** - Can be combined to create complex workflows

### Skill vs Rule vs Agent

| Component | Purpose                            | Location            | Loaded                         |
| --------- | ---------------------------------- | ------------------- | ------------------------------ |
| **Rule**  | Enforce constraints and protocols  | `~/.claude/rules/`  | Always (system context)        |
| **Skill** | Define workflows and procedures    | `~/.claude/skills/` | On-demand (via slash commands) |
| **Agent** | Specialized persona with expertise | `~/.claude/agents/` | On-demand (via Task tool)      |

**Relationship:**

- Rules are always active (verification protocol, multi-agent requirements)
- Skills are invoked via slash commands (`/sdlc:brainstorm`, `/review`)
- Agents are specialists invoked within skills (architect, security-reviewer)

## How Skills Relate to Slash Commands

Each slash command in CLAUDE.md maps to a skill definition:

### SDLC Phase Commands (Future Skills)

| Command            | Future Skill File    | Description                     |
| ------------------ | -------------------- | ------------------------------- |
| `/sdlc:brainstorm` | `sdlc/brainstorm.md` | Requirements gathering workflow |
| `/sdlc:spec`       | `sdlc/spec.md`       | Documentation creation workflow |
| `/sdlc:plan`       | `sdlc/plan.md`       | Technical design workflow       |
| `/sdlc:execute`    | `sdlc/execute.md`    | Implementation workflow         |
| `/sdlc:status`     | `sdlc/status.md`     | Progress tracking workflow      |

### Utility Commands (Future Skills)

| Command            | Future Skill File        | Description                        |
| ------------------ | ------------------------ | ---------------------------------- |
| `/feature`         | `workflows/feature.md`   | Full feature workflow (all phases) |
| `/bugfix`          | `workflows/bugfix.md`    | Bug fix with root cause analysis   |
| `/debug`           | `workflows/debug.md`     | Debug assistance workflow          |
| `/test`            | `quality/test.md`        | Test generation workflow           |
| `/review`          | `quality/review.md`      | Multi-agent code review            |
| `/security-review` | `security/review.md`     | OWASP vulnerability scan           |
| `/consensus`       | `tri-agent/consensus.md` | Tri-agent consensus workflow       |

### Git Commands (Future Skills)

| Command       | Future Skill File | Description                |
| ------------- | ----------------- | -------------------------- |
| `/git/branch` | `git/branch.md`   | Branch management workflow |
| `/git/commit` | `git/commit.md`   | Commit with quality gates  |
| `/git/pr`     | `git/pr.md`       | Pull request workflow      |
| `/git/sync`   | `git/sync.md`     | Remote sync workflow       |

## Planned Directory Structure

```
~/.claude/skills/
├── README.md                    # This file
├── .gitkeep                     # Ensures directory is tracked
│
├── sdlc/                        # SDLC phase workflows
│   ├── brainstorm.md            # Phase 1: Requirements
│   ├── spec.md                  # Phase 2: Documentation
│   ├── plan.md                  # Phase 3: Technical design
│   ├── execute.md               # Phase 4: Implementation
│   └── status.md                # Phase 5: Progress tracking
│
├── workflows/                   # Composite workflows
│   ├── feature.md               # Full feature development
│   ├── bugfix.md                # Bug fix workflow
│   ├── debug.md                 # Debugging workflow
│   └── refactor.md              # Refactoring workflow
│
├── quality/                     # Quality assurance skills
│   ├── test.md                  # Test generation
│   ├── review.md                # Code review
│   └── coverage.md              # Coverage analysis
│
├── security/                    # Security-focused skills
│   ├── review.md                # Security review (OWASP)
│   ├── audit.md                 # Full security audit
│   └── pentest.md               # Penetration testing
│
├── tri-agent/                   # Multi-agent coordination
│   ├── consensus.md             # Tri-agent consensus
│   ├── parallel.md              # Parallel execution
│   └── handoff.md               # Context handoff
│
├── git/                         # Git workflow skills
│   ├── branch.md                # Branch management
│   ├── commit.md                # Commit workflow
│   ├── pr.md                    # Pull request workflow
│   └── sync.md                  # Sync operations
│
└── templates/                   # Skill templates
    ├── basic-skill.md           # Simple skill template
    └── composite-skill.md       # Multi-step skill template
```

## Skill File Format (Proposed)

Skills will use a structured markdown format with YAML frontmatter:

```markdown
---
name: security-review
version: 1.0.0
command: /security-review
aliases: [/sec-review, /owasp]
requires:
  - verification-protocol
  - multi-agent
agents:
  primary: security-analyst
  verifiers: [codex, gemini]
---

# Security Review Skill

## Purpose

Perform OWASP-based security review of code changes.

## Prerequisites

- [ ] Target files/directories specified
- [ ] Git working tree clean
- [ ] No uncommitted sensitive data

## Workflow

### Phase 1: Static Analysis

1. Run Bandit/Semgrep on target
2. Collect findings by severity
3. Filter false positives

### Phase 2: Manual Review

1. Check OWASP Top 10 categories
2. Review authentication/authorization
3. Check input validation
4. Verify output encoding

### Phase 3: Verification

1. Document findings in VERIFY format
2. Request verification from different AI
3. Track remediation status

## Quality Gates

- [ ] All CRITICAL findings addressed
- [ ] All HIGH findings addressed or accepted
- [ ] Verification PASS from 2 AIs

## Output

- Security report in `~/.claude/reports/security/`
- VERIFY block for each finding
- Remediation TODO items
```

## Migration Plan

### Phase 1: Structure (Current)

- Create directory structure
- Document skill format
- Maintain backward compatibility with CLAUDE.md

### Phase 2: Extraction

- Extract workflow definitions from CLAUDE.md
- Create individual skill files
- Test hot-reload functionality

### Phase 3: Enhancement

- Add skill composition
- Implement skill versioning
- Add skill validation

### Phase 4: Automation

- Auto-generate skill index
- Implement skill dependencies
- Add skill testing framework

## Hot-Reload Mechanism

Skills support hot-reload for rapid iteration:

```bash
# Reload all skills
tri-agent skills --reload

# Reload specific skill
tri-agent skills --reload security/review

# List loaded skills
tri-agent skills --list

# Validate skill syntax
tri-agent skills --validate security/review.md
```

## Integration with Rules

Skills reference rules but do not duplicate them:

```markdown
---
name: code-review
requires:
  - verification-protocol # References ~/.claude/rules/verification.md
  - multi-agent # References ~/.claude/rules/multi-agent.md
---
```

The rule content is injected at runtime, ensuring:

- Single source of truth for protocols
- Rules can be updated independently
- Skills inherit rule updates automatically

## Best Practices

### Do

- Keep skills focused on one workflow
- Reference rules instead of duplicating
- Include clear quality gates
- Document prerequisites and outputs
- Use consistent YAML frontmatter

### Avoid

- Embedding protocol details (use rules)
- Creating overly complex composite skills
- Hardcoding model names (use routing)
- Skipping verification steps

## Related Documentation

- `~/.claude/CLAUDE.md` - Main configuration (source of truth)
- `~/.claude/rules/` - Modular rule definitions
- `~/.claude/agents/` - Agent definitions (95 specialized agents)
- `~/.claude/context/` - Extended context documents

## Contributing

To add a new skill:

1. Create skill file following the format above
2. Add entry to CLAUDE.md slash commands section
3. Test with `tri-agent skills --validate <skill>.md`
4. Submit for review via `/git/pr`

---

**Author:** Ahmed Adel Bakr Alderai
**Last Updated:** 2026-01-20
