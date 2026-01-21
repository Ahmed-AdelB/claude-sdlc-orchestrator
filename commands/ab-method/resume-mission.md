---
name: ab-method.resume-mission
description: Resume an incomplete mission with context and progress tracking.
version: 1.0.0
integration_with_tri_agent_workflow: |
  - Codex: rehydrate context, summarize progress, and continue implementation.
  - Claude Code: diagnose blockers or architectural mismatches.
  - Gemini CLI: locate relevant files in large codebases.
templates_and_examples: |
  - Progress summary template
  - Mission state schema
  - Example usage
step_by_step_execution_protocol: |
  1) Locate the latest incomplete mission or specified mission ID.
  2) Load mission context, files, and test status.
  3) Summarize progress and identify the next step.
  4) Resume work and update mission state.
  5) Surface blockers and request help if needed.
---

# Resume Mission

Continue an incomplete mission from where it left off.

## Arguments
- `$ARGUMENTS`: Mission ID or path to resume (optional; defaults to latest incomplete)

## Inputs
- Mission plan or mission state file
- Related files and recent diffs
- Test output if available

## Outputs
- Progress summary
- Updated mission state
- Next actionable steps

## Execution Protocol
1) Identify the mission to resume and its current status.
2) Load objectives, completed steps, and remaining steps.
3) Summarize progress and confirm the next action.
4) Continue implementation and update state as work completes.
5) If blocked, surface the issue and propose resolution paths.

## Progress Summary Template
```markdown
# Resuming Mission: [Mission Title]

## Progress
Progress: [XX%]

## Completed Steps
- [x] Step 1: [Completed item]
- [x] Step 2: [Completed item]

## Current Step
- [ ] Step 3: [In progress item]
  - Subtask A: [status]
  - Subtask B: [status]

## Remaining Steps
- [ ] Step 4: [Remaining item]
- [ ] Step 5: [Remaining item]

## Files Touched
- `path/to/file1`
- `path/to/file2`

## Last Activity
[Timestamp] - [Short note]
```

## Mission State Schema (Example)
```json
{
  "missionId": "MISSION-001",
  "taskId": "TASK-20240115-001",
  "title": "Implement authentication endpoints",
  "status": "in_progress",
  "progress": 40,
  "startedAt": "2024-01-15T10:00:00Z",
  "lastActivityAt": "2024-01-15T12:30:00Z",
  "steps": [
    {"id": 1, "title": "Create user model", "status": "completed"},
    {"id": 2, "title": "Add migration", "status": "completed"},
    {"id": 3, "title": "Implement endpoints", "status": "in_progress"},
    {"id": 4, "title": "Add middleware", "status": "pending"}
  ],
  "filesModified": ["src/models/user.ts", "src/routes/auth.ts"],
  "context": {
    "decisions": [],
    "blockers": [],
    "notes": []
  }
}
```

## Examples
```
/resume-mission
/resume-mission MISSION-001
/resume-mission auth-endpoints
```

## Tri-Agent Workflow Integration
- Use Claude Code when blockers require architectural reasoning.
- Use Gemini CLI when the mission spans many modules.
- Use Codex to continue implementation with tight scope.
