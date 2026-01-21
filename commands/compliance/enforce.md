# /guardrails:enforce

Define pre-execution guardrails for AI workflows and tools to prevent unsafe or non-compliant actions.

## Arguments
- scope: workflow or system being guarded
- risk_level: (minimal, limited, high, prohibited)
- sensitive_domains: areas requiring strict controls
- data_types: personal, sensitive, confidential, regulated
- allowed_actions: explicitly permitted actions
- blocked_actions: explicitly forbidden actions
- escalation_path: who approves exceptions
- logging: required logging and retention

## Process
1. Identify workflow entry points
2. Classify data and risks
3. Define allow/deny rules
4. Add pre-execution checks
5. Add post-execution auditing
6. Define escalation and override
7. Validate guardrails in staging

## Guardrail Rules Template
- rule_id:
- description:
- condition:
- action: (allow, block, require_approval)
- justification_required: (true/false)
- escalation_contact:
- log_level: (info, warn, critical)

## Pre-Execution Checklist
- Input validation complete
- PII and sensitive data checks
- Jurisdiction and policy alignment
- Model capability and limitation checks
- Safety and security checks
- Human oversight requirement satisfied

## Integration with Security Agents
- Security agent validates guardrail rules
- Security agent reviews logs and alerts
- Security agent owns escalation playbooks
- Shared artifacts: ruleset, audit trail, exception log

## Output Template
- Guardrail ruleset
- Enforcement workflow
- Escalation matrix
- Logging and monitoring plan
- Test cases and validation results
