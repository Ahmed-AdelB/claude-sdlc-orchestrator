# Create Mission

Break a task into focused implementation missions following the AB Method.

## Arguments
- `$ARGUMENTS` - Task ID or description to break into missions

## Process

### Step 1: Analyze Task
Read the task specification and understand:
- Overall goal and scope
- Technical requirements
- Dependencies between components

### Step 2: Identify Mission Boundaries
Break the task into focused missions that:
- Can be completed in 1-4 hours
- Have clear start and end points
- Minimize dependencies on other missions
- Can be tested independently

### Step 3: Create Mission Plan

Generate missions in this format:

```markdown
# Mission Plan for: [Task Title]

## Overview
Total Missions: X
Estimated Total Time: X hours
Execution Mode: Sequential/Parallel

## Missions

### Mission 1: [Mission Title]
**Objective:** [What this mission accomplishes]
**Estimated Time:** X hours
**Dependencies:** None / Mission X

#### Scope
- [Specific deliverable 1]
- [Specific deliverable 2]

#### Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2

#### Files to Create/Modify
- `path/to/file1.ts`
- `path/to/file2.ts`

#### Tests Required
- [ ] Unit tests for X
- [ ] Integration test for Y

---

### Mission 2: [Mission Title]
...

## Execution Order

### Sequential Dependencies
```
Mission 1 → Mission 2 → Mission 4
                    ↘
Mission 3 ──────────→ Mission 5
```

### Parallel Opportunities
- Missions 2 and 3 can run in parallel
- Mission 5 requires 2 and 3 to complete

## Quality Gates
- [ ] All missions pass their acceptance criteria
- [ ] All tests pass
- [ ] Code review completed
- [ ] Documentation updated
```

### Step 4: Save Mission Plan
Save the mission plan and individual mission files.

### Step 5: Initialize First Mission
Prepare the first mission for execution with `/sdlc:execute`.

## Example Usage
```
/create-mission TASK-20240115
/create-mission Add user authentication feature
```

## Mission Design Principles

### Good Mission Boundaries
✅ "Implement user model and database schema"
✅ "Create authentication API endpoints"
✅ "Build login form component"
✅ "Add JWT token handling"

### Poor Mission Boundaries
❌ "Start working on authentication" (too vague)
❌ "Build entire auth system" (too large)
❌ "Fix that bug" (not specific enough)
