---
name: context-prime
description: Load and summarize project context before major work.
version: 1.0.0
---

# /context-prime

Load and summarize project context to enable effective execution.

## Usage

/context-prime [optional focus area]

## Step-by-step workflow execution

1. Identify scope
   - Determine project root and focus area.
   - Capture current task goals and constraints.
   - Output: Scope Notes.
2. Read key docs
   - Review README, CONTRIBUTING, and architecture docs.
   - Identify conventions and project workflows.
   - Output: Documentation Summary.
3. Map structure
   - Scan top-level directories and key modules.
   - Identify entry points and critical paths.
   - Output: Structure Map.
4. Inspect configuration
   - Review package managers, build tools, and runtime configs.
   - Note environment variables and secrets handling.
   - Output: Config Summary.
5. Identify conventions
   - Check naming, test patterns, and lint rules.
   - Note component and API patterns.
   - Output: Conventions Summary.
6. Assess recent changes
   - Review recent commits and hotspots if available.
   - Identify areas of active development or churn.
   - Output: Activity Notes.
7. Synthesize context
   - Produce a concise context brief with risks and open questions.
   - Output: Context Digest.

## Templates

### Context Digest

```markdown
## Context Digest

### Project Summary
[One paragraph overview]

### Tech Stack
- Frontend:
- Backend:
- Data:
- Tooling:

### Key Paths
- `path/to/entry`
- `path/to/core/module`

### Conventions
- Naming:
- Testing:
- Error handling:

### Risks and Open Questions
- [Risk or question]
```

### Structure Map

```markdown
## Structure Map

- /src
  - [Major module]
- /tests
  - [Test suites]
- /docs
  - [Documentation]
```

### Config Summary

```markdown
## Config Summary

- package manager:
- build tool:
- runtime:
- env vars:
```

## Integration with tri-agent system

- Codex: primary collector of local project files and summaries.
- Claude Code: architecture interpretation and system design insights.
- Gemini CLI: large codebase analysis and documentation cross-checks.

### Coordination checkpoints

- After structure map: ask Gemini CLI to flag additional hotspots.
- After config summary: ask Claude Code to identify architectural constraints.
- Before final digest: consolidate all agent findings into one brief.
