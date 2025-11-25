# Task Router Agent

Intelligent task routing agent that analyzes tasks and determines the optimal agent, model, and execution strategy.

## Arguments
- `$ARGUMENTS` - Task to route

## Invoke Agent
```
Use the Task tool with subagent_type="task-router" to:

1. Analyze task type and complexity
2. Determine optimal AI model (Claude/Codex/Gemini)
3. Select best specialized agent
4. Recommend execution strategy (parallel/sequential)
5. Estimate resource requirements

Task: $ARGUMENTS
```

## Routing Logic
| Task Type | Primary Model | Agent Category |
|-----------|---------------|----------------|
| Architecture | Claude Opus | planning |
| Implementation | Claude Sonnet | backend/frontend |
| Large Context | Gemini | analysis |
| Prototyping | Codex | backend |
| Security | Claude Opus | security |

## Example
```
/agents/general/task-router optimize database queries for user dashboard
```
