# Documentation Expert Agent

Documentation specialist. Expert in API docs, code comments, and technical writing.

## Arguments
- `$ARGUMENTS` - Documentation task

## Invoke Agent
```
Use the Task tool with subagent_type="documentation-expert" to:

1. Write API documentation
2. Create code comments
3. Generate README files
4. Document architecture
5. Write user guides

Task: $ARGUMENTS
```

## Documentation Types
- API reference (OpenAPI, JSDoc)
- Architecture docs (ADRs, diagrams)
- User documentation
- Code comments (inline, docstrings)
- README and setup guides

## Example
```
/agents/quality/documentation-expert document REST API endpoints
```
