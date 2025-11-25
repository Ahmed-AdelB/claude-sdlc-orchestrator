# AB Master

Master orchestrator for the AB Method workflow, managing the complete task-to-mission-to-completion lifecycle.

## Arguments
- `$ARGUMENTS` - Feature description or command (start, status, next, complete)

## Process

### Starting a New Feature
When given a feature description:

```markdown
# AB Method Orchestration

## Feature: [Feature Name]

### Phase 1: Task Definition
Running `/create-task` to define specifications...
[Task specification created]

### Phase 2: Mission Planning
Running `/create-mission` to break into missions...
[Mission plan created]

### Phase 3: Execution
Ready to begin Mission 1 of X
```

### Status Check
When `status` is specified:

```markdown
# AB Method Status

## Current Feature: [Feature Name]
📊 Overall Progress: 65%

## Task Status
- Task ID: TASK-20240115
- Status: In Progress
- Started: 2024-01-15

## Mission Progress
| Mission | Status | Progress | Time |
|---------|--------|----------|------|
| Mission 1: Database schema | ✅ Complete | 100% | 2h |
| Mission 2: API endpoints | 🔄 In Progress | 75% | 3h |
| Mission 3: Frontend forms | ⬜ Pending | 0% | - |
| Mission 4: Testing | ⬜ Pending | 0% | - |

## Current Mission: API Endpoints
- Working on: Authentication middleware
- Blockers: None
- ETA: 1 hour remaining

## Quality Gates
- [ ] All missions complete
- [ ] Tests passing (42/50)
- [ ] Code review pending
- [ ] Documentation updated

## Next Steps
1. Complete current mission
2. Run `/test-mission` for Mission 2
3. Begin Mission 3: Frontend forms
```

### Next Mission
When `next` is specified:
- Complete current mission
- Run tests for current mission
- Transition to next mission
- Initialize next mission context

### Complete Feature
When `complete` is specified:
- Verify all missions complete
- Run full test suite
- Generate completion report
- Prepare for code review

## Workflow Orchestration

### Sequential Mode
```
Task Definition
     ↓
Mission Planning
     ↓
Mission 1 → Test → Review
     ↓
Mission 2 → Test → Review
     ↓
Mission N → Test → Review
     ↓
Feature Complete
```

### Parallel Mode (with git worktrees)
```
Task Definition
     ↓
Mission Planning
     ↓
     ├─→ Mission 1 (worktree 1) → Test
     ├─→ Mission 2 (worktree 2) → Test
     └─→ Mission 3 (worktree 3) → Test
             ↓
        Merge & Integration Test
             ↓
        Feature Complete
```

## State Management

```json
{
  "feature": {
    "id": "FEAT-001",
    "name": "User Authentication",
    "status": "in_progress",
    "startedAt": "2024-01-15T10:00:00Z"
  },
  "task": {
    "id": "TASK-001",
    "status": "in_progress"
  },
  "missions": [
    {"id": "M1", "status": "completed", "completedAt": "..."},
    {"id": "M2", "status": "in_progress", "progress": 75},
    {"id": "M3", "status": "pending"},
    {"id": "M4", "status": "pending"}
  ],
  "currentMission": "M2",
  "qualityGates": {
    "allMissionsComplete": false,
    "testsPass": false,
    "codeReview": false,
    "docsUpdated": false
  }
}
```

## Commands Integration

The AB Master orchestrates these commands:
- `/create-task` - Phase 1: Define task
- `/create-mission` - Phase 2: Plan missions
- `/sdlc:execute` - Phase 3: Execute missions
- `/test-mission` - Phase 4: Test each mission
- `/review` - Phase 5: Code review
- `/resume-mission` - Continue interrupted work

## Example Usage
```
/ab-master Add user authentication with OAuth support
/ab-master status
/ab-master next
/ab-master complete
```

## Quality Enforcement

### Before Mission Completion
- [ ] All acceptance criteria met
- [ ] Tests written and passing
- [ ] No linting errors
- [ ] No type errors

### Before Feature Completion
- [ ] All missions complete
- [ ] Integration tests pass
- [ ] Documentation updated
- [ ] Code review approved
- [ ] Security review (if applicable)

## Thinking Modes
- Standard tasks: `think` (4K tokens)
- Complex missions: `think hard` (10K tokens)
- Architecture decisions: `ultrathink` (32K tokens)
