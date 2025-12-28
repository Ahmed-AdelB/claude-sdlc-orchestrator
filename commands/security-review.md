# Security Review

Comprehensive security audit using OWASP Top 10 and best practices.

## Arguments
- `$ARGUMENTS` - Target files, directory, or PR number

## Process

### Step 1: Scope Identification

```markdown
## Security Review Scope
- Files: [List of files]
- Components: [Affected components]
- Entry Points: [API endpoints, forms, etc.]
```

### Step 2: OWASP Top 10 Analysis

#### A01: Broken Access Control
- [ ] Authentication required for protected resources
- [ ] Authorization checks on all endpoints
- [ ] No insecure direct object references
- [ ] Session management secure

#### A02: Cryptographic Failures
- [ ] Sensitive data encrypted at rest
- [ ] TLS/HTTPS for data in transit
- [ ] No hardcoded secrets or keys
- [ ] Strong encryption algorithms used

#### A03: Injection
- [ ] SQL queries parameterized
- [ ] NoSQL injection prevented
- [ ] Command injection prevented
- [ ] XSS prevention (output encoding)

#### A04: Insecure Design
- [ ] Threat modeling performed
- [ ] Secure defaults configured
- [ ] Defense in depth implemented
- [ ] Fail securely

#### A05: Security Misconfiguration
- [ ] No default credentials
- [ ] Error messages don't leak info
- [ ] Security headers configured
- [ ] Dependencies up to date

#### A06: Vulnerable Components
- [ ] Dependencies scanned for CVEs
- [ ] No known vulnerable versions
- [ ] Supply chain security verified

#### A07: Authentication Failures
- [ ] Strong password policy
- [ ] Multi-factor authentication available
- [ ] Account lockout on failed attempts
- [ ] Session timeout configured

#### A08: Software Integrity Failures
- [ ] Code signing implemented
- [ ] CI/CD pipeline secured
- [ ] Dependency integrity verified

#### A09: Logging Failures
- [ ] Security events logged
- [ ] Logs don't contain secrets
- [ ] Log tampering prevented
- [ ] Monitoring and alerting configured

#### A10: Server-Side Request Forgery
- [ ] URL validation on external requests
- [ ] Allowlist for external hosts
- [ ] No user-controlled URLs

### Step 3: Secret Detection

```bash
# Scan for hardcoded secrets
patterns=(
  "AKIA[A-Z0-9]{16}"                    # AWS Access Key
  "ghp_[A-Za-z0-9]{36,}"                # GitHub Token
  "-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----"  # Private Keys
  "password\s*=\s*['\"][^'\"]{8,}['\"]" # Hardcoded passwords
  "api[_-]?key\s*=\s*['\"][^'\"]+['\"]" # API keys
)
```

**Findings:**
- [ ] No secrets found
- [ ] Secrets properly externalized
- [ ] Environment variables used
- [ ] Secrets manager integrated

### Step 4: Dependency Audit

```bash
# Node.js
npm audit
npm audit fix

# Python
pip-audit
safety check

# Go
go list -json -m all | nancy sleuth
```

### Step 5: Code Analysis

#### Input Validation
- [ ] All user input validated
- [ ] Type checking enforced
- [ ] Length limits applied
- [ ] Whitelist validation used

#### Output Encoding
- [ ] HTML encoding for display
- [ ] JSON encoding for API responses
- [ ] SQL escaping for queries
- [ ] URL encoding for redirects

#### Authentication & Authorization
- [ ] JWT tokens validated properly
- [ ] CSRF protection enabled
- [ ] CORS configured correctly
- [ ] Rate limiting implemented

### Step 6: Infrastructure Review

- [ ] Principle of least privilege
- [ ] Network segmentation
- [ ] Firewall rules configured
- [ ] Secrets rotation policy

## Severity Classification

| Severity | Criteria | Action Required |
|----------|----------|-----------------|
| 🔴 Critical | Exploitable, high impact | Fix immediately |
| 🟠 High | Exploitable, medium impact | Fix before release |
| 🟡 Medium | Requires conditions to exploit | Fix in sprint |
| 🟢 Low | Informational, best practice | Document for future |

## Output Format

```markdown
## Security Review Report

### Overall Risk: 🔴 CRITICAL | 🟠 HIGH | 🟡 MEDIUM | 🟢 LOW

### Executive Summary
[2-3 sentence overview of findings]

### Critical Findings (🔴)
| ID | Issue | Location | OWASP | Remediation |
|----|-------|----------|-------|-------------|
| S-001 | [Issue] | file.ts:42 | A03 | [Fix] |

### High Findings (🟠)
| ID | Issue | Location | OWASP | Remediation |
|----|-------|----------|-------|-------------|

### Medium Findings (🟡)
[List of medium severity issues]

### Best Practice Recommendations
- [Recommendation 1]
- [Recommendation 2]

### Compliance Status
- [ ] OWASP Top 10: [X/10 passed]
- [ ] Secrets Detection: [Pass/Fail]
- [ ] Dependency Audit: [Pass/Fail]

### Approval Decision
⚠️ REQUIRES FIXES | ✅ APPROVED WITH RECOMMENDATIONS | ✅ APPROVED
```

## Remediation Tracking

```markdown
## Remediation Plan

### Critical (Fix immediately)
- [ ] S-001: [Issue] - Owner: [Name] - Due: [Date]
- [ ] S-002: [Issue] - Owner: [Name] - Due: [Date]

### High (Fix before release)
- [ ] S-003: [Issue] - Owner: [Name] - Due: [Date]

### Medium (Fix in sprint)
- [ ] S-004: [Issue] - Owner: [Name] - Due: [Date]
```

## Example Usage

```
/security-review src/auth/
/security-review PR #123
/security-review src/api/payments.ts
```

## Integration with Agents

- **security-expert**: Overall security assessment
- **owasp-specialist**: OWASP Top 10 specific checks
- **penetration-tester**: Exploit scenario analysis
- **dependency-auditor**: Vulnerability scanning
- **secrets-detector**: Secret detection patterns
- **compliance-checker**: Regulatory compliance
