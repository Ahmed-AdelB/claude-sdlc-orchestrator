---
name: sdlc:execute
description: "Phase 4: Implementation with parallel/sequential agents."
version: 1.0.0
---

# SDLC Phase 4: Execute

Implement a specific mission from the technical plan.

## Arguments
- `$ARGUMENTS` - Feature name and mission id (e.g., "auth-feature mission-2").

## Deliverables
- Implemented code changes
- Tests and verification notes
- Mission completion summary

## Phase Template
```markdown
# Mission Execution: $ARGUMENTS

## Scope
- Mission goal:
- In scope:
- Out of scope:

## Files to Create/Modify
1. [path] - [purpose]
2. [path] - [purpose]

## Implementation Steps
1. [ ] Step 1
2. [ ] Step 2
3. [ ] Step 3

## Tests Required
- [ ] Unit tests
- [ ] Integration tests (if applicable)
- [ ] E2E tests (if applicable)

## Verification Notes
- Commands run:
- Results:
```

## Checklist
- [ ] Mission scope and dependencies confirmed
- [ ] Acceptance criteria mapped to changes
- [ ] Tests implemented or updated
- [ ] Linting/type checks pass
- [ ] Documentation updated if needed

## Tri-Agent Workflow Integration
- Codex: Implement the mission and document changes.
- Claude Code: Review critical logic, architecture impact, and regressions.
- Gemini CLI: Assess security, performance, and edge cases.
- Parallel option: split code, tests, and review across agents.

## Handoff Protocol to Phase 5 (Status)
- Provide summary of changes and files touched.
- List tests run and results.
- Note open issues or follow-up tasks.
- Update mission status in the plan.
- Transition command: `/sdlc:status $ARGUMENTS`.
