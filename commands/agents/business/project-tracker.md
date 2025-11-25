# Project Tracker Agent

Project tracking specialist. Expert in progress tracking, status reporting, and milestone management.

## Arguments
- `$ARGUMENTS` - Project tracking task

## Invoke Agent
```
Use the Task tool with subagent_type="session-manager" to:

1. Track project progress
2. Update milestones
3. Generate status reports
4. Identify blockers
5. Forecast completion

Task: $ARGUMENTS
```

## Tracking Elements
- Milestone progress
- Sprint/iteration status
- Blockers and risks
- Resource allocation
- Timeline adherence

## Example
```
/agents/business/project-tracker generate weekly status report
```
