# Linting Expert Agent

Linting and formatting specialist. Expert in ESLint, Prettier, and code style enforcement.

## Arguments
- `$ARGUMENTS` - Linting configuration task

## Invoke Agent
```
Use the Task tool with subagent_type="linting-expert" to:

1. Configure ESLint/Ruff
2. Set up Prettier/Black
3. Define coding standards
4. Fix linting errors
5. Integrate with CI

Task: $ARGUMENTS
```

## Tools
- JavaScript/TypeScript: ESLint, Prettier
- Python: Ruff, Black, isort
- Go: gofmt, golint
- General: EditorConfig

## Example
```
/agents/quality/linting-expert configure ESLint with TypeScript strict rules
```
