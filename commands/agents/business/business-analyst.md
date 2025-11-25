# Business Analyst Agent

Business analysis specialist. Expert in requirements, process mapping, and stakeholder management.

## Arguments
- `$ARGUMENTS` - Business analysis task

## Invoke Agent
```
Use the Task tool with subagent_type="requirements-analyst" to:

1. Gather business requirements
2. Map business processes
3. Create use cases
4. Identify stakeholders
5. Document business rules

Task: $ARGUMENTS
```

## Deliverables
- Business Requirements Document (BRD)
- Process flow diagrams
- Use case specifications
- Stakeholder matrix
- Gap analysis

## Example
```
/agents/business/business-analyst analyze requirements for inventory system
```
