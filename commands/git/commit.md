# Smart Commit

Create a well-formatted git commit with conventional commit format and optional tri-agent approval.

## Arguments
- `$ARGUMENTS` - Commit message or 'auto' for auto-generated message

## Process

### Step 1: Analyze Changes
```bash
# Check for staged changes
git diff --cached --stat

# If nothing staged, show unstaged changes
git diff --stat

# Get list of modified files
git status --porcelain
```

### Step 2: Generate Commit Message
If 'auto' or no message provided, analyze changes to generate message:

```markdown
## Commit Analysis

### Files Changed
- src/auth/login.ts (modified)
- src/auth/types.ts (new)
- tests/auth.test.ts (modified)

### Change Summary
- Added login functionality
- Created type definitions for auth
- Updated tests for new features

### Suggested Commit Message
feat(auth): add login functionality with JWT support

- Implement login endpoint with email/password
- Add JWT token generation and validation
- Create auth type definitions
- Update tests for authentication flow
```

### Step 3: Format Message
Use conventional commit format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Formatting
- `refactor`: Code restructuring
- `perf`: Performance improvement
- `test`: Adding tests
- `chore`: Maintenance

### Step 4: Validate Commit
Check for:
- [ ] No sensitive files (.env, credentials)
- [ ] No large binary files
- [ ] No debug code (console.log, debugger)
- [ ] Linting passes
- [ ] Tests pass (optional)

### Step 5: Create Commit
```bash
git commit -m "$(cat <<'EOF'
feat(auth): add login functionality with JWT support

- Implement login endpoint with email/password
- Add JWT token generation and validation
- Create auth type definitions
- Update tests for authentication flow

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

## Tri-Agent Approval Mode
When enabled, request approval from all three agents:

```markdown
## Commit Review Request

### Changes
[Summary of changes]

### Commit Message
[Proposed message]

---

### Agent Reviews

**Claude Code (Sonnet):** ✅ APPROVE
- Code quality verified
- Tests passing
- No security concerns

**Codex (GPT-5.1):** ✅ APPROVE
- Implementation correct
- Follows best practices

**Gemini (2.5 Pro):** ✅ APPROVE
- Logic verified
- Documentation adequate

---

**Consensus:** 3/3 APPROVED - Proceeding with commit
```

## Example Usage
```
/commit                          # Auto-generate message
/commit fix: resolve login bug   # Use provided message
/commit --tri-agent              # Require tri-agent approval
```

## Safety Checks

### Pre-Commit Validation
- No secrets in staged files
- No TODO/FIXME in production code
- File sizes within limits
- No merge conflict markers

### Abort Conditions
- Sensitive data detected
- Tests failing
- Lint errors present
