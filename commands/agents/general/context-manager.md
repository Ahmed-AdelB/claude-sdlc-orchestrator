# Context Manager Agent

Manages project context, loads relevant files, and maintains awareness of the current project state.

## Arguments
- `$ARGUMENTS` - Context operation or query

## Invoke Agent
```
Use the Task tool with subagent_type="context-manager" to:

1. Scan project structure
2. Identify key configuration files
3. Load relevant code context
4. Track file dependencies
5. Maintain project state awareness

Task: $ARGUMENTS
```

## Context Sources
- package.json / requirements.txt / go.mod
- README.md and documentation
- Configuration files (.env.example, config/)
- Entry points (main.*, index.*, app.*)
- Test files for understanding expected behavior

## Example
```
/agents/general/context-manager load context for authentication module
```
