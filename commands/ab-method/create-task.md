# Create Task

Create a new task with clear specifications following the AB Method.

## Arguments
- `$ARGUMENTS` - Task description or requirements

## Process

### Step 1: Gather Requirements
Ask clarifying questions to understand:
- What is the desired outcome?
- Who are the users/stakeholders?
- What are the acceptance criteria?
- Are there any constraints or dependencies?

### Step 2: Create Task Specification

Generate a task specification in this format:

```markdown
# Task: [Task Title]

## ID
TASK-[timestamp]

## Description
[Clear description of what needs to be done]

## Objectives
- [ ] Objective 1
- [ ] Objective 2
- [ ] Objective 3

## Acceptance Criteria
1. Given [context], when [action], then [expected result]
2. Given [context], when [action], then [expected result]

## Technical Requirements
- [Requirement 1]
- [Requirement 2]

## Dependencies
- [Dependency 1]
- [Dependency 2]

## Out of Scope
- [Explicitly excluded item]

## Estimated Complexity
- [ ] Small (< 2 hours)
- [ ] Medium (2-8 hours)
- [ ] Large (1-3 days)
- [ ] Epic (> 3 days - should be broken down)

## Related Tasks
- [Related task links]
```

### Step 3: Save Task
Save the task specification to a file in the project's tasks directory.

### Step 4: Suggest Next Steps
- If task is large, suggest breaking into missions with `/create-mission`
- If task is ready, suggest execution with `/sdlc:execute`

## Example Usage
```
/create-task Add user authentication with OAuth support
```

## Output
- Task specification file saved
- Summary displayed to user
- Next steps recommended
