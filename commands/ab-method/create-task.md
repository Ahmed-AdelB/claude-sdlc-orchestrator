---
name: ab-method.create-task
description: Define a new task with clear specifications and acceptance criteria.
version: 1.0.0
integration_with_tri_agent_workflow: |
  - Codex: gather requirements and draft the task specification.
  - Claude Code: refine scope and architecture implications.
  - Gemini CLI: confirm existing patterns across large codebases.
templates_and_examples: |
  - Task specification template
  - Example usage
step_by_step_execution_protocol: |
  1) Gather requirements and constraints.
  2) Draft objectives and acceptance criteria.
  3) Identify dependencies and out-of-scope items.
  4) Estimate complexity and risks.
  5) Save the task file and propose next steps.
---

# Create Task

Create a new task with clear specifications following the AB Method.

## Arguments
- `$ARGUMENTS`: Task description or requirements

## Inputs
- Problem statement or feature request
- Stakeholders and target users
- Known constraints and dependencies

## Outputs
- Task specification document
- Suggested next actions (mission planning or execution)

## Execution Protocol
1) Clarify the desired outcome and success criteria.
2) Capture objectives and acceptance criteria in testable terms.
3) List constraints, dependencies, and out-of-scope items.
4) Estimate complexity and flag risks.
5) Save the task spec and suggest creating missions if needed.

## Task Specification Template
```markdown
# Task: [Task Title]

## ID
TASK-[YYYYMMDD-XXX]

## Description
[What needs to be done and why]

## Objectives
- [ ] [Objective 1]
- [ ] [Objective 2]

## Acceptance Criteria
1. Given [context], when [action], then [expected result]
2. Given [context], when [action], then [expected result]

## Technical Requirements
- [Requirement 1]
- [Requirement 2]

## Constraints
- [Constraint 1]
- [Constraint 2]

## Dependencies
- [Dependency 1]
- [Dependency 2]

## Out of Scope
- [Explicit exclusions]

## Risks and Assumptions
- [Risk or assumption]

## Estimated Complexity
- [ ] Small (< 2 hours)
- [ ] Medium (2-8 hours)
- [ ] Large (1-3 days)
- [ ] Epic (> 3 days, requires mission split)

## Related Tasks
- [Links or references]
```

## Examples
```
/create-task Add OAuth-based authentication for users
/create-task Improve search performance for large datasets
```

## Tri-Agent Workflow Integration
- Ask Claude Code to validate scope creep or architectural concerns.
- Ask Gemini CLI to locate relevant modules in large repos.
- Use Codex to finalize task specs quickly.
