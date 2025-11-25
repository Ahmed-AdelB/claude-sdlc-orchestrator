# Resume Mission

Continue an incomplete mission from where it left off.

## Arguments
- `$ARGUMENTS` - Mission ID or path to resume (optional - will find latest if not specified)

## Process

### Step 1: Find Mission State
Look for mission state in:
1. Active mission file (if ID provided)
2. Latest incomplete mission
3. Session memory for in-progress work

### Step 2: Load Mission Context
Restore the mission context:
- Original mission objectives
- Completed steps
- Remaining steps
- Current file states
- Test status

### Step 3: Display Progress Summary

```markdown
# Resuming Mission: [Mission Title]

## Progress
████████░░░░░░░░░░░░ 40%

## Completed Steps
✅ Step 1: Created user model
✅ Step 2: Added database migration

## Current Step
🔄 Step 3: Implementing API endpoints
   - `/api/users` endpoint - Done
   - `/api/auth/login` endpoint - In Progress
   - `/api/auth/logout` endpoint - Not Started

## Remaining Steps
⬜ Step 4: Add authentication middleware
⬜ Step 5: Write unit tests
⬜ Step 6: Integration testing

## Files Modified This Session
- `src/models/user.ts` (complete)
- `src/routes/auth.ts` (in progress)

## Last Activity
[Timestamp] - Working on login endpoint
```

### Step 4: Continue Execution
Resume from the current step:
- Read any partially modified files
- Continue implementation
- Update progress as work completes

### Step 5: Handle Blockers
If blocked by:
- Missing dependencies → Suggest prerequisite missions
- Unclear requirements → Ask clarifying questions
- Technical issues → Invoke debugging agent

## State Management

### Mission State File Format
```json
{
  "missionId": "MISSION-001",
  "taskId": "TASK-20240115",
  "title": "Implement authentication endpoints",
  "status": "in_progress",
  "progress": 40,
  "startedAt": "2024-01-15T10:00:00Z",
  "lastActivityAt": "2024-01-15T12:30:00Z",
  "steps": [
    {"id": 1, "title": "Create user model", "status": "completed"},
    {"id": 2, "title": "Add migration", "status": "completed"},
    {"id": 3, "title": "Implement endpoints", "status": "in_progress", "substeps": [...]},
    {"id": 4, "title": "Add middleware", "status": "pending"},
    {"id": 5, "title": "Write tests", "status": "pending"}
  ],
  "filesModified": ["src/models/user.ts", "src/routes/auth.ts"],
  "context": {
    "decisions": [],
    "blockers": [],
    "notes": []
  }
}
```

## Example Usage
```
/resume-mission
/resume-mission MISSION-001
/resume-mission auth-endpoints
```

## Recovery Scenarios

### Scenario: Incomplete File Edit
- Detect partially edited file
- Show diff of changes made
- Confirm continuation or rollback

### Scenario: Failed Tests
- Show which tests failed
- Suggest fixes
- Re-run tests after fixes

### Scenario: Missing Context
- Load relevant files
- Prime context with project structure
- Continue with refreshed understanding
