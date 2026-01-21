---
name: git:pr
scope: command
version: 2.0.0
summary: Create pull requests with templates, safety checks, and tri-agent verification.
args:
  - name: title
    type: string
    required: false
    description: PR title or "auto" to generate.
  - name: base
    type: string
    required: false
    default: main
    description: Base branch for the PR.
  - name: draft
    type: boolean
    required: false
    default: false
    description: Create a draft PR.
  - name: reviewers
    type: string
    required: false
    description: Comma-separated reviewer handles.
  - name: labels
    type: string
    required: false
    description: Comma-separated labels.
  - name: dry-run
    type: boolean
    required: false
    default: false
    description: Print intended actions without executing.
---

# /git/pr

Create a pull request with consistent templates, verification notes, and safety checks.

## Usage

/git/pr [title|auto] [--base main] [--draft] [--reviewers a,b] [--labels x,y] [--dry-run]

## Git Safety Protocols (from CLAUDE.md)

- Git operations require manual approval; YOLO mode is not allowed for git operations.
- Prefer `git revert` over `git reset --hard` for rollback.
- Rollback after 3 verification FAILs or a critical error, then re-run verification and require a new plan before retry.
- Use git worktrees for isolation when running parallel tasks.
- Check `git status` and warn on uncommitted tracked changes before any operation.

## Process

1. Analyze branch status
   - `git branch --show-current`
   - `git log <base>..HEAD --oneline`
   - `git diff <base>...HEAD --stat`
2. Ensure branch is pushed
   - `git push -u origin <branch>` if upstream is missing.
3. Generate PR title and summary
   - Prefer a concise, conventional title aligned to the commit message.
4. Fill PR template
   - Include summary, changes, testing, risk, and verification notes.
5. Create PR
   - Use `gh pr create` with base, title, and body.
6. Add reviewers and labels
   - `gh pr edit --add-reviewer` and `gh pr edit --add-label`.

## Tri-Agent Verification Integration

- For non-trivial changes, include a VERIFY block in the PR body.
- Verification must be performed by a different AI (two-key rule).
- If verification FAILs, fix issues and update the PR before requesting review again.

Verification request template:

```
gemini -m gemini-3-pro-preview --approval-mode yolo "Verify: <desc>. Check correctness, security, edges. PASS/FAIL."
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "Verify: <desc>. Check logic, completeness. PASS/FAIL."
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

- Upstream not set: `git push -u origin <branch>` then retry PR creation.
- Non-fast-forward push: rebase on base branch, resolve conflicts, then `git push --force-with-lease` after confirmation.
- Missing gh auth: run `gh auth login` and retry.
- PR body incomplete: stop and fill required sections before creating.
- Verification FAIL: update PR with fixes and new verification evidence.

## Examples

```
/git/pr
/git/pr "feat(auth): add oauth login" --base main
/git/pr --draft --reviewers alice,bob --labels enhancement,security
```
