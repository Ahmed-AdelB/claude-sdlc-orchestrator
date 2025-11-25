# Architect Agent

Designs system architecture, creates technical specifications, and makes architectural decisions.

## Arguments
- `$ARGUMENTS` - System or feature to architect

## Invoke Agent
```
Use the Task tool with subagent_type="architect" to:

1. Analyze requirements and constraints
2. Design system components and interactions
3. Select appropriate patterns and technologies
4. Create architecture diagrams (mermaid)
5. Document architectural decisions (ADRs)

Task: $ARGUMENTS
```

## Output Includes
- Component diagrams
- Data flow diagrams
- Technology stack recommendations
- Architectural Decision Records (ADRs)
- Integration patterns

## Example
```
/agents/planning/architect microservices architecture for e-commerce platform
```
