# Session Manager Agent

Manages session state, progress tracking, and ensures continuity across conversation turns.

## Arguments
- `$ARGUMENTS` - Session operation (save/restore/status)

## Invoke Agent
```
Use the Task tool with subagent_type="session-manager" to:

1. Save current session state
2. Track task progress
3. Restore previous session context
4. Manage todo lists across sessions
5. Ensure workflow continuity

Task: $ARGUMENTS
```

## Session Data
- Active todos and their status
- Files being worked on
- Current phase (brainstorm/spec/plan/execute/track)
- Pending decisions
- Recent changes made

## Example
```
/agents/general/session-manager save current progress
/agents/general/session-manager restore last session
```
