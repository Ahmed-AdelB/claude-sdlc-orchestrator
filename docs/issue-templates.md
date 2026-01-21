# GitHub Issue Templates

Use these templates to ensure compliance with the Tri-Agent Workflow.

## Bug Report

```markdown
### Bug Description
[Clear description of the issue]

### Reproduction Steps
1. [Step 1]
2. [Step 2]
3. [Step 3]

### Expected vs Actual Behavior
- **Expected:** [Description]
- **Actual:** [Description]

### Tri-Agent Assignment (REQUIRED)
| Role | Assigned AI | Model |
|------|-------------|-------|
| **Implementer** | [Claude/Codex/Gemini] | [Model Name] |
| **Reviewer 1** | [Different AI] | [Model Name] |
| **Reviewer 2** | [Different AI] | [Model Name] |

> **Enforcement:** Implementer ≠ Reviewer 1 ≠ Reviewer 2. All 3 models must be used.

### Verification Plan (Two-Key Rule)
- **Scope:** [Files/Paths]
- **Change Summary:** [1-3 sentences]
- **Expected Behavior:** [Concrete outcomes]
- **Repro Steps:** [Commands/Steps to verify fix]
- **Evidence to Check:** [Logs/Screenshots/Tests]
- **Risk Notes:** [Edge cases/Regressions]

### Tri-Agent Todo List
| ID | Task | Assigned AI | Verifier AI | Status | Verified |
|----|------|:-----------:|:-----------:|:------:|:--------:|
| B-01 | Analyze root cause | [AI Name] | [Diff AI] | Pending | [ ] |
| B-02 | Implement fix | [AI Name] | [Diff AI] | Pending | [ ] |
| B-03 | Add regression test | [AI Name] | [Diff AI] | Pending | [ ] |
```

## Feature Request

```markdown
### Feature Description
[Goal and value of the feature]

### Requirements
- [ ] Requirement 1
- [ ] Requirement 2
- [ ] Requirement 3

### Technical Approach (Brainstorm)
[Brief summary of approach]

### Tri-Agent Assignment (REQUIRED)
| Role | Assigned AI | Model |
|------|-------------|-------|
| **Implementer** | [Claude/Codex/Gemini] | [Model Name] |
| **Reviewer 1** | [Different AI] | [Model Name] |
| **Reviewer 2** | [Different AI] | [Model Name] |

> **Enforcement:** Implementer ≠ Reviewer 1 ≠ Reviewer 2. All 3 models must be used.

### Verification Plan (Two-Key Rule)
- **Scope:** [Files/Paths]
- **Change Summary:** [1-3 sentences]
- **Expected Behavior:** [Concrete outcomes]
- **Repro Steps:** [Steps to verify feature]
- **Evidence to Check:** [Logs/Screenshots/Tests]
- **Risk Notes:** [Edge cases]

### Tri-Agent Todo List
| ID | Task | Assigned AI | Verifier AI | Status | Verified |
|----|------|:-----------:|:-----------:|:------:|:--------:|
| F-01 | Create spec/docs | [AI Name] | [Diff AI] | Pending | [ ] |
| F-02 | Implement core logic | [AI Name] | [Diff AI] | Pending | [ ] |
| F-03 | Implement UI/API | [AI Name] | [Diff AI] | Pending | [ ] |
```

## Security Issue

```markdown
### Vulnerability Description
[Description of the flaw]

### Severity & Impact
- **Severity:** [Critical/High/Medium/Low]
- **Impact:** [What can be compromised?]

### Remediation Plan
[Proposed fix]

### Tri-Agent Assignment (REQUIRED)
| Role | Assigned AI | Model |
|------|-------------|-------|
| **Implementer** | Claude (Recommended) | Opus/Sonnet |
| **Reviewer 1** | Codex | GPT-5.2 |
| **Reviewer 2** | Gemini | Pro |

> **Enforcement:** Implementer ≠ Reviewer 1 ≠ Reviewer 2. All 3 models must be used.

### Verification Plan (Two-Key Rule)
- **Scope:** [Files/Paths]
- **Change Summary:** [1-3 sentences]
- **Expected Behavior:** [Vulnerability patched]
- **Repro Steps:** [Exploit attempt (safe) or verification steps]
- **Evidence to Check:** [Security scan results]
- **Risk Notes:** [Side effects]

### Tri-Agent Todo List
| ID | Task | Assigned AI | Verifier AI | Status | Verified |
|----|------|:-----------:|:-----------:|:------:|:--------:|
| S-01 | Security analysis | Claude | Gemini | Pending | [ ] |
| S-02 | Implement patch | Claude | Codex | Pending | [ ] |
| S-03 | Verify fix | Codex | Gemini | Pending | [ ] |
```

## Performance Issue

```markdown
### Bottleneck Description
[Where is the slowness?]

### Metrics
- **Current:** [e.g., 500ms]
- **Target:** [e.g., <100ms]

### Profiling Data
[Logs, traces, or observations]

### Tri-Agent Assignment (REQUIRED)
| Role | Assigned AI | Model |
|------|-------------|-------|
| **Implementer** | [Claude/Codex/Gemini] | [Model Name] |
| **Reviewer 1** | [Different AI] | [Model Name] |
| **Reviewer 2** | [Different AI] | [Model Name] |

> **Enforcement:** Implementer ≠ Reviewer 1 ≠ Reviewer 2. All 3 models must be used.

### Verification Plan (Two-Key Rule)
- **Scope:** [Files/Paths]
- **Change Summary:** [1-3 sentences]
- **Expected Behavior:** [Performance target met]
- **Repro Steps:** [Load test or benchmark command]
- **Evidence to Check:** [Benchmark results]
- **Risk Notes:** [Resource usage increase]

### Tri-Agent Todo List
| ID | Task | Assigned AI | Verifier AI | Status | Verified |
|----|------|:-----------:|:-----------:|:------:|:--------:|
| P-01 | Profile code | [AI Name] | [Diff AI] | Pending | [ ] |
| P-02 | Optimize logic | [AI Name] | [Diff AI] | Pending | [ ] |
| P-03 | Verify metrics | [AI Name] | [Diff AI] | Pending | [ ] |
```

---
Signed: Ahmed Adel Bakr Alderai