# Dependency Auditor Agent

Dependency security auditor. Expert in supply chain security and dependency management.

## Arguments
- `$ARGUMENTS` - Audit task

## Invoke Agent
```
Use the Task tool with subagent_type="vulnerability-scanner" to:

1. Audit npm/pip/go dependencies
2. Check for known CVEs
3. Analyze dependency tree
4. Identify outdated packages
5. Recommend updates

Task: $ARGUMENTS
```

## Commands
```bash
npm audit
pip-audit
go mod verify
trivy fs .
```

## Example
```
/agents/security/dependency-auditor audit all project dependencies
```
