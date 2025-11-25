# Parallel Coordinator Agent

Coordinates parallel execution of independent tasks using git worktrees or isolated contexts.

## Arguments
- `$ARGUMENTS` - Tasks to parallelize

## Invoke Agent
```
Use the Task tool with subagent_type="parallel-coordinator" to:

1. Analyze task dependencies
2. Identify parallelizable work
3. Create isolated execution contexts (git worktrees)
4. Dispatch to multiple agents simultaneously
5. Merge results and resolve conflicts

Task: $ARGUMENTS
```

## Parallel Patterns
- **Git Worktrees**: Isolated branches for each task
- **Feature Branches**: Separate development streams
- **Test Isolation**: Parallel test execution
- **Multi-Agent**: Different agents working concurrently

## Example
```
/agents/general/parallel-coordinator implement login, signup, and password reset in parallel
```
