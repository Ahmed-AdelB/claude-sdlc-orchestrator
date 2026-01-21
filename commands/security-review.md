---
name: security-review
description: Comprehensive security review workflow for codebases and APIs including OWASP Top 10 scanning, dependency vulnerability checks, secret detection, SQL injection and XSS analysis, authentication and authorization review, input validation analysis, security header review, and report generation with remediation recommendations. Use when asked to perform a security review, audit, or risk assessment.
---

# Security Review

## Scope and setup
- Identify targets: codebase, services, endpoints, configs, and infrastructure.
- Document tech stack, entry points, data flows, and trust boundaries.
- Prefer existing repo tooling; note sandbox or network constraints.
- Define severity model and reporting expectations.

## Workflow
### 1) OWASP Top 10 vulnerability scanning
- Map the application surface to OWASP Top 10 categories.
- Perform static review of auth, access control, data handling, logging, and config.
- Run repo-provided SAST or security scripts when available.

### 2) Dependency vulnerability check
- Review lockfiles and package manifests for all languages used.
- Run the ecosystem audit tool if present; record vulnerable packages and fixed versions.

### 3) Secret detection
- Scan for hardcoded secrets in source, configs, and CI artifacts.
- Use available secret scanners; otherwise use targeted searches for common key patterns.

### 4) SQL injection detection
- Identify raw SQL usage and string interpolation.
- Verify parameterized queries, prepared statements, and safe query builders.

### 5) XSS vulnerability detection
- Trace user-controlled data to rendering sinks.
- Verify output encoding and sanitization at the sink, not just at input.

### 6) Authentication and authorization review
- Review auth flows, token handling, session management, and MFA.
- Verify authorization checks at route, service, and data layers.

### 7) Input validation analysis
- Confirm boundary validation for all inputs, including files and headers.
- Ensure allowlist validation, strict parsing, and size limits.

### 8) Security header review
- Check HTTP response headers and cookie flags for web surfaces.
- Validate CSP, HSTS, X-Content-Type-Options, X-Frame-Options or frame-ancestors,
  Referrer-Policy, Permissions-Policy, and Set-Cookie flags.

### 9) Report generation
- Produce a structured report with scope, methodology, findings, and evidence.
- Include severity, impact, and reproducible steps where safe.

### 10) Remediation recommendations
- Provide prioritized fixes with concrete guidance and references.
- Include verification steps to confirm remediations.

## Evidence handling
- Link findings to file paths and relevant code or config snippets.
- Capture tool output, versions, and command lines for traceability.

## Report format
- Deliver `security-review-report.md` with sections:
  - Summary
  - Scope and Methodology
  - Findings (severity ordered)
  - Recommendations
  - Appendix (tool output, versions, commands)
