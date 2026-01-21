---
name: ab-method.ab-master
description: Orchestrate the full AB Method workflow from task to completion.
version: 1.0.0
integration_with_tri_agent_workflow: |
  - Codex: run the workflow steps and keep artifacts consistent.
  - Claude Code: provide architectural oversight and complex debugging.
  - Gemini CLI: analyze large codebases and documentation for context.
templates_and_examples: |
  - Orchestration summary template
  - Status template
  - Example usage
step_by_step_execution_protocol: |
  1) Interpret the command mode (start, status, next, complete).
  2) Invoke the right sub-commands in order.
  3) Track mission progress and quality gates.
  4) Surface blockers and suggest delegation.
  5) Produce a concise status or completion report.
---

# AB Master

Master orchestrator for the AB Method workflow, managing the task-to-mission lifecycle.

## Arguments
- `$ARGUMENTS`: Feature description or command (start, status, next, complete)

## Inputs
- Feature request or task ID
- Existing task and mission artifacts

## Outputs
- Orchestration summary
- Status updates
- Next steps or completion report

## Execution Protocol
1) Determine the command mode: start, status, next, or complete.
2) Start: run create-task, then create-mission, then queue Mission 1.
3) Status: summarize task, mission progress, and quality gates.
4) Next: close current mission, run test-mission, then open the next.
5) Complete: verify all missions and generate completion report.

## Command Modes

### Start
- Use `/create-task` to define the task.
- Use `/create-mission` to break the task into missions.
- Prepare Mission 1 for execution.

### Status
- Summarize overall progress, current mission, and blockers.

### Next
- Close the current mission with tests.
- Transition to the next mission.

### Complete
- Verify all missions complete and tests pass.
- Provide a completion report and review checklist.

## Orchestration Summary Template
```markdown
# AB Method Orchestration

## Feature: [Feature Name]

### Phase 1: Task Definition
- Task ID: [TASK-YYYYMMDD-XXX]
- Status: [status]

### Phase 2: Mission Planning
- Total missions: [N]
- Execution mode: Sequential | Parallel

### Phase 3: Execution
- Current mission: [Mission Title]
- Progress: [XX%]
```

## Status Template
```markdown
# AB Method Status

## Current Feature
- Feature: [Name]
- Overall progress: [XX%]

## Task
- Task ID: [TASK-YYYYMMDD-XXX]
- Status: [status]

## Missions
| Mission | Status | Progress | Notes |
|---------|--------|----------|-------|
| Mission 1 | complete | 100% | - |
| Mission 2 | in_progress | 60% | - |
| Mission 3 | pending | 0% | - |

## Quality Gates
- [ ] All missions complete
- [ ] Tests passing
- [ ] Code review complete
- [ ] Docs updated

## Next Steps
1. [Action 1]
2. [Action 2]
```

## Examples
```
/ab-master Add OAuth-based authentication for users
/ab-master status
/ab-master next
/ab-master complete
```

## Tri-Agent Workflow Integration
- Use Claude Code for architectural reviews and complex debugging.
- Use Gemini CLI to scan large codebases for context or impacts.
- Use Codex to keep the AB artifacts and steps consistent.
