---
name: debug
description: Systematic debug assistance with hypothesis-driven investigation.
version: 1.0.0
---

# /debug

Provide structured debugging support from intake to verified resolution.

## Usage

/debug <issue description>

## Step-by-step workflow execution

1. Define the problem
   - Capture expected vs actual behavior.
   - Collect error messages, logs, and stack traces.
   - Output: Debug Intake.
2. Establish context
   - Identify recent changes and affected areas.
   - Map relevant data flows and dependencies.
   - Output: Context Notes.
3. Form hypotheses
   - List possible causes and rank by likelihood.
   - Decide what evidence would confirm or refute each hypothesis.
   - Output: Hypothesis Log.
4. Run experiments
   - Add targeted instrumentation or logs.
   - Reproduce and collect data.
   - Output: Experiment Log.
5. Isolate the fault
   - Narrow down to a minimal failing case.
   - Identify the precise code path or config.
   - Output: Fault Localization.
6. Propose or implement fix
   - Draft a minimal fix and assess side effects.
   - Add or update tests.
   - Output: Fix Proposal or Patch.
7. Verify and summarize
   - Validate the fix and document findings.
   - Provide next steps if not fully resolved.
   - Output: Debug Report.

## Templates

### Debug Intake

```markdown
## Debug Intake

### Issue
[Short description]

### Expected
[Expected behavior]

### Actual
[Actual behavior]

### Environment
- OS:
- Runtime:
- Version/Commit:

### Evidence
- [Error message or log]
```

### Hypothesis Log

```markdown
## Hypothesis Log

1. Hypothesis: [Cause]
   - Evidence for:
   - Evidence against:
   - Experiment:

2. Hypothesis: [Cause]
   - Evidence for:
   - Evidence against:
   - Experiment:
```

### Experiment Log

```markdown
## Experiment Log

### Experiment
[What you changed or observed]

### Result
[What happened]

### Conclusion
[What this means]
```

### Debug Report

```markdown
## Debug Report

### Root Cause
[Identified cause]

### Fix
[What was changed or proposed]

### Verification
- [ ] Issue no longer reproduces
- [ ] Tests added or updated

### Follow-ups
- [TODO]
```

## Integration with tri-agent system

- Codex: primary executor for instrumentation and fixes.
- Claude Code: deep reasoning on complex faults and architecture risks.
- Gemini CLI: broad search across the repository for similar patterns.

### Coordination checkpoints

- After hypotheses: ask Claude Code to challenge assumptions.
- Before experiments: ask Gemini CLI to surface related code or configs.
- After fix: ask Claude Code to review for side effects.
