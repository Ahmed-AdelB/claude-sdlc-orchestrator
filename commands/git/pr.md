# Create Pull Request

Create a well-documented pull request with comprehensive description and review checklist.

## Arguments
- `$ARGUMENTS` - PR title or 'auto' for auto-generated

## Process

### Step 1: Analyze Branch
```bash
# Get current branch
git branch --show-current

# Get commits since diverging from base
git log main..HEAD --oneline

# Get changed files
git diff main...HEAD --stat
```

### Step 2: Generate PR Content

```markdown
## Summary
[2-3 sentences describing the change]

## Changes Made
- [Bullet point of change 1]
- [Bullet point of change 2]
- [Bullet point of change 3]

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to change)
- [ ] Documentation update

## How Has This Been Tested?
- [ ] Unit tests
- [ ] Integration tests
- [ ] Manual testing

## Test Instructions
1. [Step to test the change]
2. [Another step]

## Screenshots (if applicable)
[Add screenshots here]

## Checklist
- [ ] My code follows the project's style guidelines
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes
- [ ] Any dependent changes have been merged and published

## Related Issues
Closes #[issue number]

---
🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

### Step 3: Ensure Branch is Pushed
```bash
# Check if branch is pushed
git rev-parse --abbrev-ref --symbolic-full-name @{u}

# If not pushed, push with upstream
git push -u origin $(git branch --show-current)
```

### Step 4: Create PR
```bash
gh pr create \
  --title "[PR Title]" \
  --body "$(cat <<'EOF'
[Generated PR body]
EOF
)" \
  --base main \
  --draft  # Optional
```

### Step 5: Add Labels and Reviewers
```bash
# Add labels
gh pr edit --add-label "enhancement,needs-review"

# Request reviewers
gh pr edit --add-reviewer @teammate
```

## PR Templates

### Feature PR
```markdown
## 🚀 Feature: [Feature Name]

### Description
[What does this feature do?]

### User Story
As a [type of user], I want [goal] so that [benefit].

### Implementation Details
[Technical details of the implementation]

### Dependencies
- [Dependency 1]
- [Dependency 2]
```

### Bug Fix PR
```markdown
## 🐛 Fix: [Bug Description]

### Problem
[What was the bug?]

### Root Cause
[What caused it?]

### Solution
[How was it fixed?]

### Regression Risk
[Low/Medium/High] - [Explanation]
```

### Refactoring PR
```markdown
## ♻️ Refactor: [Area Refactored]

### Motivation
[Why was this refactoring needed?]

### Changes
[What was changed?]

### Impact
- No functional changes
- [Any behavioral differences]

### Performance Impact
[Better/Same/Worse] - [Metrics if available]
```

## Example Usage
```
/pr                                    # Auto-generate PR
/pr feat: add user authentication      # Use provided title
/pr --draft                            # Create as draft
/pr --reviewers @john,@jane            # Add reviewers
```

## PR Best Practices

### Size Guidelines
- Small: < 200 lines (ideal)
- Medium: 200-400 lines
- Large: > 400 lines (consider splitting)

### Commit History
- Squash messy commits
- Keep logical commits separate
- Write meaningful commit messages

### Self-Review Checklist
Before creating PR:
- [ ] Diff reviewed line by line
- [ ] No console.log or debug code
- [ ] No commented out code
- [ ] All tests pass
- [ ] Documentation updated
