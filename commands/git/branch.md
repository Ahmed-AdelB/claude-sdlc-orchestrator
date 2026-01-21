---
name: git:branch
scope: command
version: 2.0.0
summary: Create and manage branches with naming conventions, safety gates, and optional worktrees.
args:
  - name: name
    type: string
    required: false
    description: Branch type/name or short description.
  - name: base
    type: string
    required: false
    default: main
    description: Base branch to branch from.
  - name: worktree
    type: string
    required: false
    description: Optional path to create a worktree for the branch.
  - name: push
    type: boolean
    required: false
    default: false
    description: Push and set upstream after creation.
  - name: dry-run
    type: boolean
    required: false
    default: false
    description: Print intended actions without executing.
---

# /git/branch

Create and manage branches using naming conventions, safety checks, and optional worktrees.

## Usage

/git/branch [name] [--base main] [--worktree path] [--push] [--dry-run]

## Git Safety Protocols (from CLAUDE.md)

- Git operations require manual approval; YOLO mode is not allowed for git operations.
- Prefer `git revert` over `git reset --hard` for rollback.
- Rollback after 3 verification FAILs or a critical error, then re-run verification and require a new plan before retry.
- Use git worktrees for isolation when running parallel tasks.
- Check `git status` and warn on uncommitted tracked changes before any operation.

## Process

1. Parse branch type and name
   - If a type prefix is provided, normalize it (feat, fix, hotfix, refactor, docs, test, chore).
   - If no type is provided, infer from the description and confirm.
2. Generate branch name
   - Format: `<type>/<ticket-id>-<short-description>`
   - Lowercase, hyphens only, no special characters.
3. Validate working tree
   - If uncommitted changes exist, offer: stash, commit, or abort.
4. Update base branch
   - `git fetch origin` then `git checkout <base>` and `git pull origin <base>`.
5. Create branch
   - `git checkout -b <branch>` (or `git worktree add <path> <branch>` if requested).
6. Push (optional)
   - `git push -u origin <branch>` if `--push` is set.

## Branch Naming Conventions

Pattern:

```
<type>/<ticket-id>-<description>
```

Examples:

- `feat/auth-oauth-support`
- `fix/BUG-456-login-timeout`
- `hotfix/critical-security-patch`
- `docs/api-authentication`
- `chore/update-dependencies`

## Tri-Agent Verification Integration

- If this branch is for non-trivial work, follow the unified tri-agent workflow before implementation.
- Build the TODO table, assign verifiers, and obtain user approval before changes.
- Use two-key verification (different AI) before merge or release.

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

- Branch already exists: switch to it (`git checkout <branch>`) or choose a new name.
- Base update fails: resolve auth/remote issues, then retry `git fetch` and `git pull`.
- Uncommitted changes: `git stash push -m "pre-branch"` or commit before branching.
- Worktree add fails: ensure target path is empty, run `git worktree prune`, then retry.
- Wrong base chosen: delete the branch and re-create from the correct base.

## Examples

```
/git/branch feat/oauth-support
/git/branch "add user authentication" --base main
/git/branch fix/login-timeout --push
/git/branch refactor/auth-cleanup --worktree ../auth-refactor
```
