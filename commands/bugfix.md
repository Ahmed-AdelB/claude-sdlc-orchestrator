---
name: bugfix
description: Bug fix workflow with root cause analysis and regression prevention.
version: 1.0.0
---

# /bugfix

Execute a structured bug fix workflow with root cause analysis and verification.

## Usage

/bugfix <bug description or issue id>

## Step-by-step workflow execution

1. Intake and reproduce
   - Capture expected vs actual behavior and environment details.
   - Reproduce the issue reliably and document the steps.
   - Output: Reproduction Record.
2. Triage and scope
   - Assess severity, impact, and affected components.
   - Identify potential regressions or recent changes.
   - Output: Triage Notes.
3. Root cause analysis
   - Gather evidence (logs, traces, code paths).
   - Use causal chain or 5 Whys to identify the true cause.
   - Output: RCA Summary.
4. Fix design
   - Propose solution options and choose a minimal, safe fix.
   - Evaluate risks and side effects.
   - Output: Fix Plan.
5. Implement fix
   - Apply the smallest change that addresses the root cause.
   - Add or update regression tests.
   - Output: Patch and Tests.
6. Verify and prevent regression
   - Run targeted and full test suites as needed.
   - Validate in the original environment if possible.
   - Output: Verification Checklist.
7. Document and close
   - Record root cause, fix, and prevention steps.
   - Link issues and update changelog or incident notes.
   - Output: Bug Fix Report.

## Templates

### Reproduction Record

```markdown
## Reproduction Record

### Environment
- OS:
- Browser/Runtime:
- Version/Commit:

### Steps to Reproduce
1.
2.
3.

### Expected
[What should happen]

### Actual
[What happens]
```

### Root Cause Analysis

```markdown
## Root Cause Analysis

### Evidence
- [Logs, stack traces, metrics]

### Causal Chain
1. [Immediate cause]
2. [Underlying cause]
3. [Systemic cause]

### 5 Whys (optional)
1. Why?
2. Why?
3. Why?
4. Why?
5. Why?
```

### Fix Plan

```markdown
## Fix Plan

### Proposed Fix
[Summary of the change]

### Alternatives Considered
- [Option 1]
- [Option 2]

### Risks
- [Potential side effect]

### Tests
- [Regression test]
- [Related tests]
```

### Verification Checklist

```markdown
## Verification Checklist

- [ ] Reproduction no longer occurs
- [ ] Regression test added or updated
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] No new warnings or logs
```

### Bug Fix Report

```markdown
## Bug Fix Report

### Issue
[Bug description]

### Root Cause
[Short summary]

### Fix Summary
[What changed and why]

### Files Changed
- `path/to/file` - [Change]

### Tests Added or Updated
- `path/to/test` - [Coverage]
```

## Integration with tri-agent system

- Codex: primary executor for patching and test updates.
- Claude Code: root cause validation, architecture impact, complex debugging.
- Gemini CLI: wide codebase search for related patterns and regressions.

### Coordination checkpoints

- After reproduction: ask Gemini CLI to locate related code paths and similar bugs.
- During RCA: ask Claude Code to validate causal chain and system impact.
- Before merge: ask Claude Code to review fix quality and test coverage.
