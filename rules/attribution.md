<!-- Part of modular rules system - see ~/.claude/CLAUDE.md for full context -->
<!-- This file contains work attribution rules and commit format standards -->

# Attribution Rules (CRITICAL)

## Core Rule

**NEVER use "Generated with Claude Code" in commits, PRs, or documentation.**

**Always attribute work to: Ahmed Adel Bakr Alderai**

---

## DO NOT Include

- "Generated with Claude Code"
- "Co-Authored-By: Claude"
- Any AI attribution whatsoever

All work should be attributed to the user only.

---

## Commit Format (Tri-Agent)

```
type(scope): description

Body explaining what and why

Tri-Agent Approval:
- Claude (Sonnet): APPROVE
- Codex (GPT-5.2): APPROVE
- Gemini (3 Pro): APPROVE

Author: Ahmed Adel Bakr Alderai
```

### Example Commit

```
feat(auth): implement OAuth2 PKCE flow for mobile clients

Adds PKCE support to prevent authorization code interception
attacks on mobile devices. Includes code_verifier generation,
SHA256 challenge, and state validation.

Tri-Agent Approval:
- Claude (Sonnet): APPROVE - Architecture follows RFC 7636
- Codex (GPT-5.2): APPROVE - Tests pass
- Gemini (3 Pro): APPROVE - Security reviewed

Author: Ahmed Adel Bakr Alderai
```

---

## PR and Issue Signature

When creating PRs or issues, sign as:

```
---
Ahmed Adel Bakr Alderai
```

---

## Commit Types

| Type     | Description                      |
| -------- | -------------------------------- |
| feat     | New feature                      |
| fix      | Bug fix                          |
| docs     | Documentation only               |
| style    | Formatting, no code change       |
| refactor | Code change, no feature/fix      |
| perf     | Performance improvement          |
| test     | Adding or updating tests         |
| chore    | Build process or auxiliary tools |
| security | Security-related changes         |

---

## Quick Reference

| Context       | Attribution                       |
| ------------- | --------------------------------- |
| Git commits   | `Author: Ahmed Adel Bakr Alderai` |
| Pull requests | Sign: `Ahmed Adel Bakr Alderai`   |
| GitHub issues | Sign: `Ahmed Adel Bakr Alderai`   |
| Code comments | No AI attribution                 |
| Documentation | No AI attribution                 |
