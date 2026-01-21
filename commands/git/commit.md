---
name: git:commit
scope: command
version: 2.0.0
summary: Smart commit with conventional commits, safety gates, and tri-agent approval.
args:
  - name: message
    type: string
    required: false
    description: Commit message or "auto" to generate.
  - name: scope
    type: string
    required: false
    description: Conventional commit scope override.
  - name: tri-agent
    type: boolean
    required: false
    default: false
    description: Require tri-agent verification before committing.
  - name: dry-run
    type: boolean
    required: false
    default: false
    description: Print intended actions without executing.
---

# /git/commit

Create a conventional commit with quality gates, tri-agent verification, and recovery paths.

## Usage

/git/commit [message|auto] [--scope name] [--tri-agent] [--dry-run]

## Git Safety Protocols (from CLAUDE.md)

- Git operations require manual approval; YOLO mode is not allowed for git operations.
- Prefer `git revert` over `git reset --hard` for rollback.
- Rollback after 3 verification FAILs or a critical error, then re-run verification and require a new plan before retry.
- Use git worktrees for isolation when running parallel tasks.
- Check `git status` and warn on uncommitted tracked changes before any operation.

## Process

1. Inspect staged changes
   - `git diff --cached --stat`
   - If nothing staged, show unstaged diff and stop for confirmation.
2. Validate diff
   - No secrets, large binaries, or debug artifacts.
   - Optional: lint and tests.
3. Generate or validate message
   - Use conventional commits: `<type>(<scope>): <subject>`.
   - Ensure subject is imperative, <= 72 chars.
4. Tri-agent verification (if required)
   - Use the two-key rule: verification by a different AI.
   - Record PASS/FAIL and address failures before commit.
5. Create commit
   - `git commit -m "<message>"` (or multi-line with body).

## Conventional Commit Types

- feat: new feature
- fix: bug fix
- docs: documentation
- style: formatting
- refactor: code restructuring
- perf: performance
- test: tests
- chore: maintenance

## Tri-Agent Verification Integration

- Require verification for high-risk changes or when `--tri-agent` is set.
- Verification must be performed by a different AI (two-key rule).

Verification request template:

```
gemini -m gemini-3-pro-preview --approval-mode yolo "Verify: <desc>. Check correctness, security, edges. PASS/FAIL."
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "Verify: <desc>. Check logic, completeness. PASS/FAIL."
```

Approval log template:

```
## Commit Verification

Changes: <short summary>
Proposed message: <message>

- Claude: PASS/FAIL (notes)
- Codex: PASS/FAIL (notes)
- Gemini: PASS/FAIL (notes)

Decision: PROCEED | HOLD
```

## Templates (Commit and PR)

Commit message template:

```
<type>(<scope>): <subject>

<context>
- <bullet>
- <bullet>

Refs: <ticket-id>
BREAKING CHANGE: <details> (optional)
```

PR description template:

```
## Summary
<short summary>

## Changes
- <change 1>
- <change 2>

## Testing
- [ ] unit
- [ ] integration
- [ ] manual
- [ ] not run (explain)

## Risk and Rollback
- Risk: Low | Medium | High
- Rollback: git revert <sha>

## Verification (Two-Key Rule)
- Scope:
- Change summary:
- Expected behavior:
- Repro steps:
- Evidence:
- Risk notes:

## Checklist
- [ ] self-review complete
- [ ] docs updated (if needed)
- [ ] tests pass
```

## Error Handling and Recovery

- No staged changes: stage files (`git add ...`) and re-run.
- Hook failures: fix issues; do not bypass with `--no-verify` unless explicitly approved.
- Bad commit message: `git commit --amend` and re-verify if required.
- Incorrect changes: `git revert <sha>`; do not use `git reset --hard`.
- Verification FAIL: fix issues, re-run verification, and only then commit.

## Examples

```
/git/commit auto
/git/commit "fix(auth): handle token refresh"
/git/commit --tri-agent
```
