# Secrets Management Expert Agent

Secrets management specialist. Expert in vault systems, environment variables, and secure credential handling.

## Arguments
- `$ARGUMENTS` - Secrets management task

## Invoke Agent
```
Use the Task tool with subagent_type="secrets-management-expert" to:

1. Set up secrets management
2. Configure vault systems
3. Manage environment variables
4. Rotate credentials
5. Audit secret access

Task: $ARGUMENTS
```

## Tools & Patterns
- HashiCorp Vault
- AWS Secrets Manager
- Environment variables (.env)
- Kubernetes secrets
- Git-crypt / SOPS

## Example
```
/agents/security/secrets-management-expert set up AWS Secrets Manager
```
