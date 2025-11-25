# Security Expert Agent

Application security specialist. Expert in OWASP Top 10, secure coding, and vulnerability assessment.

## Arguments
- `$ARGUMENTS` - Security task or audit

## Invoke Agent
```
Use the Task tool with subagent_type="security-expert" to:

1. Audit for vulnerabilities
2. Review secure coding
3. Identify OWASP Top 10 issues
4. Recommend security fixes
5. Implement security controls

Task: $ARGUMENTS
```

## OWASP Top 10 Focus
- Injection attacks
- Broken authentication
- Sensitive data exposure
- XXE, XSS, CSRF
- Security misconfiguration

## Example
```
/agents/security/security-expert audit authentication module
```
