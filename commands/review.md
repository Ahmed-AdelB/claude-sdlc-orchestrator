---
name: review
description: Multi-agent code review workflow with risk-based findings.
version: 1.0.0
---

# /review

Run a multi-agent code review with consolidated findings and clear verdict.

## Usage

/review <files, diff, or PR reference>

## Step-by-step workflow execution

1. Define scope
   - Identify files, modules, or PR diff to review.
   - Capture context: feature intent, constraints, and known risks.
   - Output: Review Brief.
2. Assign agent roles
   - Split review focus across agents by specialty.
   - Output: Review Allocation.
3. Perform review passes
   - Functional correctness and edge cases.
   - Security and input validation.
   - Performance and resource usage.
   - Maintainability and style consistency.
   - Output: Agent Findings.
4. Consolidate and deduplicate
   - Merge overlapping findings and rank by severity.
   - Identify test gaps and required follow-ups.
   - Output: Consolidated Findings.
5. Produce verdict
   - APPROVE, REQUEST_CHANGES, or COMMENT.
   - Provide actionable fixes with file references.
   - Output: Review Summary.

## Templates

### Review Brief

```markdown
## Review Brief

### Scope
- Files:
- Diff/PR:

### Intent
[What the change is supposed to do]

### Constraints
- [Performance, security, compatibility]
```

### Findings Table

```markdown
## Findings

| Severity | File | Line | Issue | Recommendation |
| --- | --- | --- | --- | --- |
| Critical | | | | |
| Major | | | | |
| Minor | | | | |
```

### Review Summary

```markdown
## Review Summary

### Verdict
APPROVE | REQUEST_CHANGES | COMMENT

### Key Issues
- [Issue 1]
- [Issue 2]

### Tests Suggested
- [Test 1]
- [Test 2]
```

## Integration with tri-agent system

- Codex: primary reviewer for implementation details and diffs.
- Claude Code: architecture coherence, design risks, and complex logic.
- Gemini CLI: large codebase impact, documentation, and dependency review.

### Coordination checkpoints

- Before review: ask Gemini CLI to map impacted modules.
- During review: ask Claude Code for deep reasoning on complex changes.
- After review: merge findings into one prioritized list.
