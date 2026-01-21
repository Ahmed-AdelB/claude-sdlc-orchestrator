---
name: ab-method.create-mission
description: Create focused missions from a task spec using the AB Method.
version: 1.0.0
integration_with_tri_agent_workflow: |
  - Codex: draft mission boundaries, acceptance criteria, and file or test lists.
  - Claude Code: validate architecture and cross-mission dependencies.
  - Gemini CLI: scan large codebases for affected areas and risks.
templates_and_examples: |
  - Mission plan template
  - Mission file template
  - Example usage
step_by_step_execution_protocol: |
  1) Load task spec or prompt for missing inputs.
  2) Identify deliverables, risks, and dependency graph.
  3) Slice work into 1-4 hour missions with clear scope.
  4) Draft plan and per-mission checklists.
  5) Validate test strategy and definition of done.
  6) Save plan and suggest the next action.
---

# Create Mission

Break a task into focused implementation missions following the AB Method.

## Arguments
- `$ARGUMENTS`: Task ID or task description

## Inputs
- Task specification (preferred) or a concise task summary
- Known constraints, dependencies, and target files

## Outputs
- Mission plan document
- Individual mission entries (if the repo uses per-mission files)
- Suggested next step for execution

## Execution Protocol
1) Load the task specification and confirm the goal and boundaries.
2) Identify deliverables, risks, and dependency chain.
3) Split the work into missions that are 1-4 hours and testable in isolation.
4) Draft mission objectives, scope, acceptance criteria, files, and tests.
5) Validate each mission for single-responsibility and minimal coupling.
6) Save the plan and recommend starting Mission 1.

## Mission Plan Template
```markdown
# Mission Plan: [Task Title]

## Overview
- Task ID: [TASK-YYYYMMDD-XXX]
- Total missions: [N]
- Estimated total time: [X hours]
- Execution mode: Sequential | Parallel

## Missions

### Mission 1: [Title]
Objective: [What this mission accomplishes]
Estimated time: [X hours]
Dependencies: [None | Mission N]

Scope
- [Deliverable 1]
- [Deliverable 2]

Acceptance Criteria
- [ ] [Criterion 1]
- [ ] [Criterion 2]

Files to Create or Modify
- `path/to/file1.ts`
- `path/to/file2.tsx`

Tests Required
- [ ] Unit: [area]
- [ ] Integration: [area]

Risks or Notes
- [Potential risk or assumption]

---

### Mission 2: [Title]
...

## Dependency Map
Mission 1 -> Mission 2 -> Mission 4
Mission 3 -> Mission 4

## Quality Gates
- [ ] Each mission meets acceptance criteria
- [ ] Tests pass for each mission
- [ ] Documentation updated as needed
```

## Mission File Template (Optional)
```markdown
# Mission: [Title]

## Objective
[One sentence goal]

## Scope
- [Deliverable 1]
- [Deliverable 2]

## Acceptance Criteria
- [ ] [Criterion 1]
- [ ] [Criterion 2]

## Dependencies
- [Mission IDs]

## Files
- `path/to/file1`
- `path/to/file2`

## Tests
- [ ] Unit tests: [area]
- [ ] Integration tests: [area]

## Definition of Done
- [ ] All acceptance criteria met
- [ ] Tests added and passing
- [ ] No lint or type errors
```

## Examples
```
/create-mission TASK-20240115-001
/create-mission Add OAuth-based authentication for users
```

## Tri-Agent Workflow Integration
- Use Claude Code to review mission boundaries if architecture is complex.
- Use Gemini CLI to scan a very large codebase for impacted modules.
- Use Codex to produce actionable mission plans and checklists.
