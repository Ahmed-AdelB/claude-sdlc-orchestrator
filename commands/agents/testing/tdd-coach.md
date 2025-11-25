# TDD Coach Agent

TDD coaching specialist. Expert in test-driven development, red-green-refactor cycle, and TDD best practices.

## Arguments
- `$ARGUMENTS` - Feature to implement with TDD

## Invoke Agent
```
Use the Task tool with subagent_type="tdd-coach" to:

1. Guide TDD workflow
2. Write failing tests first
3. Implement minimal code
4. Refactor safely
5. Maintain test coverage

Task: $ARGUMENTS
```

## TDD Cycle
1. **Red**: Write failing test
2. **Green**: Make it pass (minimal code)
3. **Refactor**: Clean up code
4. Repeat

## Example
```
/agents/testing/tdd-coach implement shopping cart with TDD
```
