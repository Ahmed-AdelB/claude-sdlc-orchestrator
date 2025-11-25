# Orchestrator Agent

Master workflow orchestrator that coordinates all SDLC phases and delegates to specialized agents.

## Arguments
- `$ARGUMENTS` - Task or workflow to orchestrate

## Invoke Agent
```
Use the Task tool with subagent_type="orchestrator" to:

1. Analyze the task requirements
2. Break down into phases (brainstorm, spec, plan, execute, track)
3. Route to appropriate specialized agents
4. Coordinate parallel/sequential execution
5. Aggregate results and report progress

Task: $ARGUMENTS
```

## Capabilities
- Full SDLC workflow management
- Multi-agent coordination
- Parallel task execution via git worktrees
- Progress tracking and reporting
- Quality gate enforcement

## Example
```
/agents/general/orchestrator implement user authentication with OAuth
```
