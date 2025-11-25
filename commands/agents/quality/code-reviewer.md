# Code Reviewer Agent

Code review specialist. Expert in code quality, best practices, and constructive feedback.

## Arguments
- `$ARGUMENTS` - Code or PR to review

## Invoke Agent
```
Use the Task tool with subagent_type="code-reviewer" to:

1. Review code quality
2. Check for best practices
3. Identify potential issues
4. Suggest improvements
5. Provide constructive feedback

Task: $ARGUMENTS
```

## Review Focus
- Code readability
- Design patterns
- Error handling
- Performance implications
- Security concerns

## Example
```
/agents/quality/code-reviewer review authentication module
```
