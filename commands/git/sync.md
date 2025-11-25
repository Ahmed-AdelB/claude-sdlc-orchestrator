# Sync Branch

Synchronize current branch with remote and optionally rebase on base branch.

## Arguments
- `$ARGUMENTS` - Options: 'pull', 'push', 'rebase', 'all'

## Process

### Step 1: Check Current State
```bash
# Get current branch
git branch --show-current

# Check for uncommitted changes
git status --porcelain

# Check remote status
git remote -v
```

### Step 2: Fetch Latest
```bash
# Fetch all remotes
git fetch --all --prune

# Show status relative to remote
git status -sb
```

### Step 3: Display Sync Status
```markdown
## Branch Sync Status

### Current Branch: `feat/auth-oauth`
- Local commits: 3 ahead
- Remote commits: 0 behind
- Uncommitted changes: 2 files

### Main Branch
- Local: abc123
- Remote: def456 (2 commits ahead)

### Recommended Actions
1. ✅ Pull remote changes to current branch
2. ⚠️ Rebase on main to get latest changes
3. 📤 Push local commits to remote
```

### Step 4: Execute Sync

#### Pull Mode
```bash
# Pull with rebase to keep history clean
git pull --rebase origin $(git branch --show-current)
```

#### Push Mode
```bash
# Push to remote
git push origin $(git branch --show-current)

# If rejected, offer force push (with warning)
# git push --force-with-lease origin $(git branch --show-current)
```

#### Rebase Mode
```bash
# Rebase on main
git fetch origin main
git rebase origin/main

# Handle conflicts if any
# After resolution: git rebase --continue
```

#### All Mode
```bash
# Complete sync: fetch, rebase, push
git fetch --all
git rebase origin/main
git push origin $(git branch --show-current)
```

### Step 5: Handle Conflicts
If conflicts occur:

```markdown
## Merge Conflicts Detected

### Conflicting Files
- src/auth/login.ts
- src/utils/helpers.ts

### Resolution Options
1. **Auto-resolve** - Use ours/theirs strategy
2. **Manual resolve** - Edit files manually
3. **Abort** - Cancel rebase/merge

### After Resolution
```bash
git add <resolved-files>
git rebase --continue
```
```

## Sync Strategies

### Keep Branch Updated
```bash
# Daily sync routine
git fetch origin
git rebase origin/main
```

### Before PR
```bash
# Ensure branch is up to date
git fetch origin
git rebase origin/main
git push --force-with-lease
```

### After PR Feedback
```bash
# Sync after making changes
git add .
git commit --amend
git push --force-with-lease
```

## Safety Features

### Force Push Protection
```markdown
⚠️ **Force Push Warning**

You are about to force push to: `feat/auth-oauth`

This will:
- Overwrite remote history
- Potentially disrupt other developers

Checks:
- [ ] Branch is not protected
- [ ] No open PRs with reviews
- [ ] You are the only contributor

Proceed? [y/N]
```

### Stash Management
```bash
# Auto-stash before sync
git stash push -m "Auto-stash before sync"

# After sync
git stash pop
```

## Example Usage
```
/sync                    # Show status and recommend actions
/sync pull               # Pull remote changes
/sync push               # Push local changes
/sync rebase             # Rebase on main
/sync all                # Full sync (fetch, rebase, push)
```

## Sync Report
```markdown
## Sync Complete ✅

### Actions Performed
1. ✅ Fetched latest from origin
2. ✅ Rebased on main (2 commits)
3. ✅ Pushed to remote

### Current State
- Branch: `feat/auth-oauth`
- Commits ahead: 5
- Commits behind: 0
- Status: Up to date with remote

### Next Steps
- Continue development
- Create PR when ready: `/pr`
```
