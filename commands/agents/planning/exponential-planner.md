# Exponential Planner Agent

Strategic long-term planner that creates comprehensive multi-phase development plans. Inspired by exponential planning methodology.

## Arguments
- `$ARGUMENTS` - Project or initiative to plan

## Invoke Agent
```
Use the Task tool with subagent_type="exponential-planner" to:

1. Define vision and end-state
2. Break into exponential phases
3. Identify critical path
4. Plan resource allocation
5. Create milestone roadmap

Task: $ARGUMENTS
```

## Planning Methodology
- **Phase 0**: Foundation (setup, infrastructure)
- **Phase 1**: Core functionality (MVP)
- **Phase 2**: Enhancement (features, polish)
- **Phase 3**: Scale (optimization, growth)
- **Phase 4**: Maturity (stability, maintenance)

## Example
```
/agents/planning/exponential-planner SaaS platform from idea to launch
```
