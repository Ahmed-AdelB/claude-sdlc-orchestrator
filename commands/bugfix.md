# Bug Fix Workflow

Execute systematic bug fix with root cause analysis and regression testing.

## Arguments
- `$ARGUMENTS` - Bug description or issue number

## Process

### Step 1: Reproduce the Issue
```markdown
## Reproduction Steps
1. [Action 1]
2. [Action 2]
3. [Observe bug]

Expected: [What should happen]
Actual: [What happens]
Environment: [Browser/OS/Version]
```

### Step 2: Root Cause Analysis

Use the 5 Whys technique:
1. **Why did the bug occur?** [Answer]
2. **Why did that happen?** [Answer]
3. **Why did that condition exist?** [Answer]
4. **Why wasn't it caught?** [Answer]
5. **Why did our process allow this?** [Answer]

### Step 3: Investigation

#### Git History Analysis
```bash
# Find when bug was introduced
git log --all --full-history -- path/to/file.ts

# View specific commit
git show <commit-hash>

# Find commits mentioning issue
git log --grep="related-keyword"
```

#### Code Analysis
- [ ] Locate affected code paths
- [ ] Identify all call sites
- [ ] Check for similar patterns elsewhere
- [ ] Review related tests (if any)

### Step 4: Solution Design

```markdown
## Fix Strategy

### Root Cause
[Core issue identified]

### Proposed Solution
[How to fix it]

### Impact Analysis
- Affected components: [List]
- Breaking changes: [Yes/No]
- Migration needed: [Yes/No]

### Alternative Approaches
1. [Approach 1] - Pros/Cons
2. [Approach 2] - Pros/Cons

### Selected Approach
[Chosen solution and rationale]
```

### Step 5: Implementation

1. **Create Feature Branch**
   ```bash
   git checkout -b fix/issue-number-brief-description
   ```

2. **Write Regression Test First**
   ```typescript
   it('should [prevent the bug from occurring]', () => {
     // Test that fails with current code
     // Will pass after fix
   });
   ```

3. **Implement Fix**
   - Make minimal changes
   - Focus on root cause, not symptoms
   - Add defensive programming where appropriate

4. **Verify Fix**
   - [ ] Regression test passes
   - [ ] All existing tests pass
   - [ ] Manual verification in affected scenarios
   - [ ] No new warnings/errors

### Step 6: Quality Gates

- [ ] Test coverage >= 80%
- [ ] No console.log or debug code
- [ ] Documentation updated if API changed
- [ ] CHANGELOG.md updated
- [ ] Related issues linked

### Step 7: Issue Linking

```bash
# Commit references issue
git commit -m "fix(component): brief description

Root cause: [What caused the bug]
Solution: [How it was fixed]
Prevention: [How to prevent recurrence]

Fixes #123
Relates to #456"
```

## Commit Format

```
fix(scope): [concise bug fix description]

Root Cause: [What caused the bug]
Solution: [How it was fixed]
Impact: [What this affects]

Regression Test: [Test added to prevent recurrence]

Fixes #[issue-number]

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

## Output Format

```markdown
## Bug Fix Report

### Issue
[Bug description]

### Severity
🔴 Critical | 🟠 High | 🟡 Medium | 🟢 Low

### Root Cause
[Identified root cause]

### Fix Summary
[What was changed]

### Files Changed
- `path/to/file1.ts` - [Change description]
- `path/to/file2.ts` - [Change description]

### Tests Added
- `path/to/test.spec.ts` - [Regression test]

### Verification
- [x] Bug no longer reproduces
- [x] Regression test added
- [x] All tests pass
- [x] Code reviewed
```

## Example Usage

```
/bugfix User session expires immediately after login
/bugfix #456 - API returns 500 on empty request body
/bugfix Race condition in payment processing
```
