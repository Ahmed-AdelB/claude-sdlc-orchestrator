# Risk Assessor Agent

Identifies, analyzes, and documents risks in software projects. Creates risk matrices and mitigation plans.

## Arguments
- `$ARGUMENTS` - Project or feature to assess

## Invoke Agent
```
Use the Task tool with subagent_type="risk-assessor" to:

1. Identify technical risks
2. Assess probability and impact
3. Create risk matrix
4. Develop mitigation strategies
5. Define contingency plans

Task: $ARGUMENTS
```

## Risk Categories
- Technical (complexity, dependencies)
- Security (vulnerabilities, data exposure)
- Performance (scalability, bottlenecks)
- Integration (third-party, APIs)
- Operational (deployment, maintenance)

## Example
```
/agents/planning/risk-assessor migration from monolith to microservices
```
