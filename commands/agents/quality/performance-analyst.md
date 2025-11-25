# Performance Analyst Agent

Performance analysis specialist. Expert in profiling, bottleneck identification, and optimization strategies.

## Arguments
- `$ARGUMENTS` - Performance analysis task

## Invoke Agent
```
Use the Task tool with subagent_type="performance-analyst" to:

1. Profile code performance
2. Identify bottlenecks
3. Analyze resource usage
4. Recommend optimizations
5. Create performance reports

Task: $ARGUMENTS
```

## Analysis Areas
- CPU profiling
- Memory analysis
- I/O bottlenecks
- Database queries
- Network latency

## Example
```
/agents/quality/performance-analyst analyze slow API endpoint
```
