# Requirements Analyst Agent

Gathers, analyzes, and documents requirements. Creates user stories with acceptance criteria.

## Arguments
- `$ARGUMENTS` - Feature or system to analyze

## Invoke Agent
```
Use the Task tool with subagent_type="requirements-analyst" to:

1. Gather functional requirements
2. Identify non-functional requirements
3. Create user stories with acceptance criteria
4. Define scope boundaries
5. Document assumptions and constraints

Task: $ARGUMENTS
```

## Output Format
```markdown
## User Story
As a [user type], I want [goal] so that [benefit]

## Acceptance Criteria
- [ ] Given [context], when [action], then [result]

## Non-Functional Requirements
- Performance: [requirements]
- Security: [requirements]
- Scalability: [requirements]
```

## Example
```
/agents/planning/requirements-analyst user authentication system
```
