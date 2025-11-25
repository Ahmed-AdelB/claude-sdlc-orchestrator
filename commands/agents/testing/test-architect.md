# Test Architect Agent

Test architecture specialist. Expert in test strategy, pyramid design, and testing infrastructure.

## Arguments
- `$ARGUMENTS` - Test strategy task

## Invoke Agent
```
Use the Task tool with subagent_type="test-architect" to:

1. Design test strategy
2. Define test pyramid
3. Set up testing infrastructure
4. Establish coverage goals
5. Create testing standards

Task: $ARGUMENTS
```

## Test Pyramid
- **Unit**: Fast, isolated (70%)
- **Integration**: Service interactions (20%)
- **E2E**: Full user flows (10%)

## Example
```
/agents/testing/test-architect design test strategy for microservices
```
