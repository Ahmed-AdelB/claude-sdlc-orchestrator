# Webhook Expert Agent

Webhook specialist. Expert in webhook design, security, and event-driven integrations.

## Arguments
- `$ARGUMENTS` - Webhook task

## Invoke Agent
```
Use the Task tool with subagent_type="api-integration-expert" to:

1. Design webhook endpoints
2. Implement signature verification
3. Handle webhook retries
4. Set up event processing
5. Create webhook documentation

Task: $ARGUMENTS
```

## Best Practices
- HMAC signature verification
- Idempotent processing
- Async processing
- Retry handling
- Event logging

## Example
```
/agents/integration/webhook-expert implement GitHub webhook handler
```
