# Create Branch

Create a feature branch with proper naming conventions and setup.

## Arguments
- `$ARGUMENTS` - Branch description or type/name

## Process

### Step 1: Determine Branch Type
Parse arguments to identify branch type:
- `feat/` or `feature/` - New feature
- `fix/` or `bugfix/` - Bug fix
- `hotfix/` - Production hotfix
- `refactor/` - Code refactoring
- `docs/` - Documentation
- `test/` - Test additions
- `chore/` - Maintenance

### Step 2: Generate Branch Name
Format: `<type>/<ticket-id>-<short-description>`

```markdown
## Branch Naming

### Input Analysis
Description: "Add user authentication with OAuth"

### Suggested Names
1. `feat/auth-oauth-support`
2. `feat/USER-123-oauth-authentication` (if ticket provided)
3. `feature/add-oauth-login`

### Selected: `feat/auth-oauth-support`
```

### Step 3: Ensure Clean State
```bash
# Check for uncommitted changes
git status --porcelain

# If changes exist, offer options:
# 1. Stash changes
# 2. Commit changes
# 3. Abort branch creation
```

### Step 4: Update Base Branch
```bash
# Fetch latest
git fetch origin

# Ensure base is up to date
git checkout main
git pull origin main
```

### Step 5: Create and Checkout Branch
```bash
# Create new branch
git checkout -b feat/auth-oauth-support

# Push and set upstream (optional)
git push -u origin feat/auth-oauth-support
```

### Step 6: Initialize Branch
```markdown
## Branch Created

### Details
- **Branch:** `feat/auth-oauth-support`
- **Base:** `main` (at commit abc123)
- **Created:** 2024-01-15 10:30:00

### Next Steps
1. Implement changes
2. Commit with conventional commits
3. Push and create PR

### Useful Commands
- View branch: `git log --oneline -10`
- Switch back: `git checkout main`
- Delete branch: `git branch -d feat/auth-oauth-support`
```

## Branch Naming Conventions

### Pattern
```
<type>/<ticket-id>-<description>
```

### Examples
| Type | Example |
|------|---------|
| Feature | `feat/AUTH-123-oauth-login` |
| Bug fix | `fix/BUG-456-login-timeout` |
| Hotfix | `hotfix/critical-security-patch` |
| Refactor | `refactor/auth-module-cleanup` |
| Documentation | `docs/api-documentation` |
| Tests | `test/auth-integration-tests` |
| Chore | `chore/update-dependencies` |

### Rules
- Use lowercase
- Use hyphens (not underscores)
- Keep short but descriptive
- Include ticket ID when available
- No special characters

## Worktree Support
For parallel development:

```bash
# Create branch with worktree
git worktree add ../project-feat-auth feat/auth-oauth-support

# List worktrees
git worktree list

# Remove worktree
git worktree remove ../project-feat-auth
```

## Example Usage
```
/branch add user authentication     # Auto-detect type
/branch feat/oauth-support          # Explicit type
/branch fix/login-timeout           # Bug fix branch
/branch --worktree new-feature      # Create with worktree
```

## Branch Management

### Check Branch Status
```bash
# Compare with main
git log main..HEAD --oneline

# Check if branch is stale
git log -1 --format="%cr" HEAD
```

### Cleanup Old Branches
```bash
# List merged branches
git branch --merged main

# Delete merged branches
git branch -d $(git branch --merged main | grep -v main)
```
