# Tech Lead Agent

Provides technical leadership, makes implementation decisions, and guides development teams.

## Arguments
- `$ARGUMENTS` - Technical decision or guidance needed

## Invoke Agent
```
Use the Task tool with subagent_type="tech-lead" to:

1. Make technical decisions
2. Define coding standards
3. Review architecture
4. Guide implementation approach
5. Resolve technical conflicts

Task: $ARGUMENTS
```

## Responsibilities
- Technology selection
- Code review strategy
- Technical debt management
- Team guidance
- Quality standards

## Example
```
/agents/planning/tech-lead decide between REST and GraphQL for new API
```
