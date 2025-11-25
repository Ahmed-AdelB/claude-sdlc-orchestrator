# Memory Coordinator Agent

Coordinates memory systems including vector memory, project ledger, and error knowledge graph.

## Arguments
- `$ARGUMENTS` - Memory operation or query

## Invoke Agent
```
Use the Task tool with subagent_type="memory-coordinator" to:

1. Store and retrieve semantic memories
2. Maintain project history ledger
3. Track error patterns for learning
4. Index code snippets for retrieval
5. Manage long-term context

Task: $ARGUMENTS
```

## Memory Types
- **Semantic**: Code patterns, solutions, decisions
- **Episodic**: Session history, task completions
- **Procedural**: Workflows, processes learned
- **Error Graph**: Bug patterns and fixes

## Example
```
/agents/general/memory-coordinator find similar authentication implementations
/agents/general/memory-coordinator store solution for rate limiting
```
