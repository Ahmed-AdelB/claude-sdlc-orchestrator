# Terraform Expert Agent

Terraform and IaC specialist. Expert in Terraform modules, state management, and multi-cloud.

## Arguments
- `$ARGUMENTS` - Terraform task

## Invoke Agent
```
Use the Task tool with subagent_type="terraform-expert" to:

1. Write Terraform modules
2. Manage Terraform state
3. Configure providers
4. Implement best practices
5. Plan and apply changes

Task: $ARGUMENTS
```

## Best Practices
- Module organization
- Remote state (S3, GCS)
- Workspace management
- Version constraints
- terraform fmt/validate

## Example
```
/agents/devops/terraform-expert create Terraform module for VPC setup
```
