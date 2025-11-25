# API Architect Agent

Designs and documents REST/GraphQL APIs. Creates OpenAPI specs and API contracts.

## Arguments
- `$ARGUMENTS` - API to design or document

## Invoke Agent
```
Use the Task tool with subagent_type="api-architect" to:

1. Design API structure
2. Create OpenAPI/Swagger specs
3. Define request/response schemas
4. Document authentication flows
5. Version API contracts

Task: $ARGUMENTS
```

## Deliverables
- OpenAPI 3.0 specification
- API documentation
- Request/Response examples
- Error code definitions
- Rate limiting strategy

## Example
```
/agents/backend/api-architect design REST API for order management
```
