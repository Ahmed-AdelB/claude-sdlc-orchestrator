---
name: git:sync
scope: command
version: 2.0.0
summary: Sync local branches with remote using safe pull, rebase, and push flows.
args:
  - name: mode
    type: string
    required: false
    enum: [status, pull, push, rebase, all]
    description: Sync mode to run (default: status).
  - name: base
    type: string
    required: false
    default: main
    description: Base branch used for rebase.
  - name: force-with-lease
    type: boolean
    required: false
    default: false
    description: Allow force push with lease when required.
  - name: dry-run
    type: boolean
    required: false
    default: false
    description: Print intended actions without executing.
---

# /git/sync

Synchronize the current branch with remotes using safe fetch, rebase, and push flows.

## Usage

/git/sync [status|pull|push|rebase|all] [--base main] [--force-with-lease] [--dry-run]

## Git Safety Protocols (from CLAUDE.md)

- Git operations require manual approval; YOLO mode is not allowed for git operations.
- Prefer `git revert` over `git reset --hard` for rollback.
- Rollback after 3 verification FAILs or a critical error, then re-run verification and require a new plan before retry.
- Use git worktrees for isolation when running parallel tasks.
- Check `git status` and warn on uncommitted tracked changes before any operation.

## Process

1. Inspect current status
   - `git branch --show-current`
   - `git status --porcelain` and `git status -sb`
2. Fetch latest
   - `git fetch --all --prune`
3. Choose sync strategy
   - pull: rebase onto remote tracking branch.
   - rebase: rebase onto `<base>`.
   - push: push current branch.
   - all: fetch, rebase on base, then push.
4. Resolve conflicts if any
   - Fix conflicts, `git add`, then `git rebase --continue`.
5. Push updates
   - Use `git push` or `git push --force-with-lease` when required and approved.

## Tri-Agent Verification Integration

- Use verification for risky sync actions (rebases on shared branches or force push).
- Verification must be performed by a different AI (two-key rule).
- If verification FAILs, stop and revert the rebase or use `git revert` for bad changes.

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

- Uncommitted changes: stash or commit before syncing.
- Rebase conflict: resolve files, `git add`, then `git rebase --continue`.
- Need to abort rebase: `git rebase --abort` and reassess.
- Non-fast-forward push: rebase and retry; use `--force-with-lease` only with explicit approval.
- Remote errors: check `git remote -v`, auth, and retry fetch/push.

## Examples

```
/git/sync
/git/sync pull
/git/sync rebase --base main
/git/sync all --force-with-lease
```
