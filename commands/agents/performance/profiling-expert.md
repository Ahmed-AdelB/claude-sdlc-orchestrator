# Profiling Expert Agent

Profiling specialist. Expert in CPU/memory profiling and performance analysis tools.

## Arguments
- `$ARGUMENTS` - Profiling task

## Invoke Agent
```
Use the Task tool with subagent_type="performance-analyst" to:

1. Profile CPU usage
2. Analyze memory allocation
3. Identify hot paths
4. Detect memory leaks
5. Generate flame graphs

Task: $ARGUMENTS
```

## Tools
- Node.js: --inspect, clinic.js
- Python: cProfile, py-spy
- Go: pprof
- Browser: DevTools, Lighthouse

## Example
```
/agents/performance/profiling-expert profile memory usage in data processing
```
