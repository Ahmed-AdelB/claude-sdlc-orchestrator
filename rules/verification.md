<!-- Part of the modular rules system for ~/.claude/CLAUDE.md -->
<!-- This file contains the Two-Key Rule verification protocol -->
<!-- Reference: Include via symlink or import in main CLAUDE.md -->

# Verification Protocol

## TWO-KEY RULE

Any change must be independently verified by a second agent before acceptance.

### Verification Request Format (Required)

```
VERIFY:
- Scope: <files/paths>
- Change summary: <1-3 sentences>
- Expected behavior: <concrete outcomes>
- Repro steps: <commands or manual steps>
- Evidence to check: <logs/screenshots/tests>
- Risk notes: <edge cases>
```

### PASS/FAIL/INCONCLUSIVE Criteria

| Result           | Condition                                                                 |
| ---------------- | ------------------------------------------------------------------------- |
| **PASS**         | All expected behaviors match, tests reproduce cleanly, no regressions     |
| **FAIL**         | Any expected behavior missing, tests fail, or regressions/new risks found |
| **INCONCLUSIVE** | Evidence insufficient to determine outcome                                |

### Re-verification Rules

1. Any change after FAIL requires a **fresh** verification request
2. Verifier must re-run the **full** scope (no partial spot checks)
3. INCONCLUSIVE handling: Request third AI review OR escalate to user with evidence

### FAIL Example

```
VERIFICATION RESULT: FAIL
Issues Found:
1. CRITICAL - Token expiration not enforced (line 47)
2. HIGH - Token not invalidated after use (line 89)
Required: Fix both issues, re-run tests, submit fresh VERIFY
Verifier: Codex (GPT-5.2)
```

### Comprehensive FAIL Workflow Example (Refresh Token Rotation)

```
--- INITIAL VERIFY REQUEST ---
VERIFY:
- Scope: src/auth/token-rotation.ts, src/auth/refresh.ts
- Change summary: Implements refresh token rotation per RFC 6749
- Expected behavior: Old token invalidated on use, new token issued, family tracking
- Repro steps: npm test -- --grep "token rotation"
- Evidence to check: Test output, DB token_family table
- Risk notes: Race conditions on concurrent refresh

--- VERIFICATION RESULT: FAIL ---
Issues Found:
1. CRITICAL - Old refresh token remains valid after rotation (line 78)
2. HIGH - Token family not tracked; replay attacks possible (missing family_id)
3. MEDIUM - No rate limiting on refresh endpoint (DoS vector)
Required Fixes:
- [ ] Invalidate old token BEFORE issuing new (atomic transaction)
- [ ] Add family_id column and track token lineage
- [ ] Add rate limit: 10 refreshes/min per user
Re-run ALL tests after fixes, submit FRESH verify request.
Verifier: Gemini (3 Pro)

--- FRESH RE-VERIFY REQUEST (after fixes) ---
VERIFY:
- Scope: src/auth/token-rotation.ts, src/auth/refresh.ts, migrations/003_token_family.sql
- Change summary: Fixed token invalidation, added family tracking, added rate limiting
- Expected behavior: All 3 issues resolved, tests pass, no regressions
- Repro steps: npm test -- --grep "token rotation" && npm run test:security
- Evidence to check: Test output (expect 12/12 pass), rate limit logs
- Risk notes: Verify atomic transaction under load
```

---

## STALEMATE RESOLUTION PROTOCOL

**Trigger:** Implementer and verifier disagree after a verification cycle.

| Step | Action                                                                 |
| ---- | ---------------------------------------------------------------------- |
| 1    | Max retries: 2 total verification cycles after initial disagreement    |
| 2    | Deadlock detection: Same dispute recurs twice = declare deadlock       |
| 3    | Tie-breaker: Escalate to user with disputed claim, evidence, clear ask |
| 4    | Alternative: Request consensus from third AI, follow majority          |
| 5    | Documentation: Record deadlock and resolution path in change log       |

### Escalation Template

```
DEADLOCK DETECTED:
- Disputed claim: <description>
- Implementer position: <summary>
- Verifier position: <summary>
- Evidence: <links/snippets>
- Ask: Which outcome should we prioritize?
```

---

## ROLLBACK & RECOVERY PROCEDURES

### When to Rollback

- Verification fails **3 times** on the same change
- **Critical error** introduced (data loss, security regression, prod outage risk)
- Change no longer aligned with user intent

### How to Rollback

| Method                 | Command                               | Notes                         |
| ---------------------- | ------------------------------------- | ----------------------------- |
| Git revert (preferred) | `git revert <bad-commit>`             | Reversible, preserves history |
| Checkpoint restore     | Restore to last known-good checkpoint | Use when revert insufficient  |

### Post-Rollback Verification

1. Re-run the **original** verification steps against rolled-back state
2. Log rollback reason and verification outcome
3. Document in change log for audit trail

### Preventing Rollback Loops

- Require a **new plan** before re-attempting the same change
- If rollback happens twice, **escalate to user** for direction
- Consider alternative implementation approach

---

## Quick Reference

```
Verification Flow:
  Implement → VERIFY request → Review → PASS/FAIL/INCONCLUSIVE
                                  ↓
                         FAIL → Fix → Fresh VERIFY
                                  ↓
                    INCONCLUSIVE → Third AI or User

Rollback Trigger:
  3 FAIL cycles OR Critical error OR User intent mismatch
```

### Verification Marks

| Mark  | Meaning                 |
| ----- | ----------------------- |
| `[ ]` | Pending                 |
| `[x]` | Passed                  |
| `[!]` | Failed                  |
| `[?]` | Inconclusive (escalate) |
