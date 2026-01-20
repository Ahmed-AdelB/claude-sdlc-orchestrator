<!-- Part of modular rules system - see ~/.claude/CLAUDE.md for full context -->
<!-- This file contains security code generation requirements and escalation policies -->

# Security Rules

## Security-First Code Generation (MANDATORY)

When generating code, always apply these security requirements:

- **Input Validation:** Validate and sanitize all user inputs
- **Parameterized Queries:** Use parameterized queries for all database operations (never string concatenation)
- **Error Handling:** Implement proper error handling; never expose stack traces to users
- **Least Privilege:** Follow principle of least privilege for all operations
- **Secure Defaults:** Use HTTPS, encrypted storage, secure cookies
- **No Hardcoded Secrets:** Never hardcode credentials, API keys, or secrets - use environment variables
- **Dependency Security:** Check for known vulnerabilities in dependencies before adding

---

## danger-full-access Escalation Checklist

Before using Codex with `-s danger-full-access`, verify ALL conditions:

- [ ] Task genuinely requires system-wide access (not just workspace)
- [ ] Running in isolated container/VM (not host system)
- [ ] Security review completed by second AI
- [ ] Backup/checkpoint created before execution
- [ ] Changes will be reviewed post-execution

**Default to `-s workspace-write` unless all boxes are checked.**

```bash
# DEFAULT (workspace-write) - Use for most tasks:
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "task"

# ESCALATED (danger-full-access) - Only after checklist passes:
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s danger-full-access "task"
```

---

## YOLO Mode Policy

YOLO mode (`-y` or `--approval-mode yolo`) bypasses manual approval.

| Operation Type           | YOLO Allowed? | Rationale                  |
| ------------------------ | ------------- | -------------------------- |
| Read-only analysis       | Yes           | No risk of modification    |
| Code review              | Yes           | Analysis only              |
| Documentation generation | Yes           | Output can be reviewed     |
| File modifications       | No            | Requires explicit approval |
| Git operations           | No            | Risk of data loss          |
| Deployments              | No            | Production impact          |
| System commands          | No            | Security risk              |

**Rule:** Use YOLO only for read-only operations. For modifications, use manual approval.

```bash
# READ-ONLY (YOLO allowed):
gemini -m gemini-3-pro-preview --approval-mode yolo "Analyze: ..."

# MODIFICATIONS (manual approval required):
gemini -m gemini-3-pro-preview "Implement: ..."
```

---

## Credential Security

**Storage:**

- Use OS keychain (libsecret/Keychain) for sensitive credentials
- Encrypt config files containing secrets at rest
- Set restrictive permissions: `chmod 600` on credential files

**Rotation:**

- Rotate OAuth tokens every 30 days
- Audit credential access in `~/.claude/logs/audit/`

**Locations:**
| Credential | Path | Permissions |
|------------|------|-------------|
| Gemini OAuth | `~/.gemini/oauth_creds.json` | 600 |
| Codex config | `~/.codex/config.toml` | 600 |
| Claude settings | `~/.claude/settings.json` | 644 |

---

## Quick Reference

| Mode               | Use Case                        | Risk Level |
| ------------------ | ------------------------------- | ---------- |
| workspace-write    | Standard development tasks      | Low        |
| danger-full-access | System-wide operations in VM    | High       |
| YOLO read-only     | Analysis, review, documentation | Minimal    |
| YOLO write         | NEVER - Not allowed             | -          |
