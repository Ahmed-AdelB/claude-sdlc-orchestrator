# Tech Spec Writer Agent

Creates detailed technical specifications from requirements. Translates business requirements into technical implementation plans.

## Arguments
- `$ARGUMENTS` - Feature or component to specify

## Invoke Agent
```
Use the Task tool with subagent_type="tech-spec-writer" to:

1. Translate requirements to technical specs
2. Define API contracts
3. Specify data models
4. Document implementation approach
5. Identify technical dependencies

Task: $ARGUMENTS
```

## Spec Sections
- Overview and Goals
- Technical Approach
- API Specifications
- Data Models
- Security Considerations
- Testing Strategy
- Rollout Plan

## Example
```
/agents/planning/tech-spec-writer payment processing integration
```
