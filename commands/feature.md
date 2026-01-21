---
name: feature
description: Full feature workflow across all five SDLC phases with tri-agent coordination.
version: 1.0.0
---

# /feature

Run a complete feature workflow from discovery to verification.

## Usage

/feature <feature description>

## Step-by-step workflow execution

1. Phase 1 - Discovery (Brainstorm)
   - Gather requirements and constraints.
   - Ask clarifying questions and define scope boundaries.
   - Identify stakeholders, dependencies, and risks.
   - Output: Feature Brief.
2. Phase 2 - Specification (Document)
   - Write functional and non-functional requirements.
   - Define acceptance criteria and UX/API contracts.
   - Capture edge cases and failure modes.
   - Output: Feature Spec.
3. Phase 3 - Planning (Plan)
   - Choose architecture and major design decisions.
   - Break down work into tasks and milestones.
   - Define test strategy and rollout plan.
   - Output: Implementation Plan.
4. Phase 4 - Execution (Build)
   - Implement iteratively with tests.
   - Validate each milestone against acceptance criteria.
   - Update docs and changelog as needed.
   - Output: Implementation Log.
5. Phase 5 - Tracking (Verify)
   - Run final quality gates and regression checks.
   - Confirm acceptance criteria and stakeholder sign-off.
   - Prepare release notes and monitoring plan.
   - Output: Release Readiness Report.

## Templates

### Phase 1 - Feature Brief

```markdown
## Feature Brief

### Problem
[What problem are we solving?]

### Goals
- [Goal 1]
- [Goal 2]

### Non-Goals
- [Out of scope 1]
- [Out of scope 2]

### Constraints
- [Technical or business constraints]

### Open Questions
- [Question 1]
- [Question 2]
```

### Phase 2 - Feature Spec

```markdown
## Feature Spec

### Requirements
- [Requirement 1]
- [Requirement 2]

### Acceptance Criteria
- [ ] [Criterion 1]
- [ ] [Criterion 2]

### UX or API Contract
- [UI flow or endpoints]

### Edge Cases
- [Edge case 1]
- [Edge case 2]
```

### Phase 3 - Implementation Plan

```markdown
## Implementation Plan

### Architecture Decisions
- [Decision 1]
- [Decision 2]

### Work Breakdown
1. [Task 1]
2. [Task 2]

### Test Strategy
- Unit: [scope]
- Integration: [scope]
- E2E: [scope]

### Rollout Plan
- [Canary or staged rollout]
```

### Phase 4 - Implementation Log

```markdown
## Implementation Log

### Milestone
[What was delivered]

### Changes
- [File or component]
- [Behavior]

### Tests
- [Test name and result]

### Notes
- [Risks or follow-ups]
```

### Phase 5 - Release Readiness

```markdown
## Release Readiness

### Acceptance Criteria Status
- [ ] [Criterion 1]
- [ ] [Criterion 2]

### Verification
- [ ] Unit tests
- [ ] Integration tests
- [ ] Manual QA

### Monitoring
- [Metric or alert]

### Release Notes
- [User-facing summary]
```

## Integration with tri-agent system

- Codex: primary executor for implementation and quick iteration.
- Claude Code: architecture review, cross-file coherence, complex debugging.
- Gemini CLI: large codebase analysis, dependency impact, documentation scan.

### Coordination checkpoints

- After Phase 1: ask Claude Code to validate scope and risk list.
- After Phase 2: ask Gemini CLI to scan for existing patterns or similar features.
- After Phase 3: ask Claude Code to review architecture decisions.
- During Phase 4: use Codex for coding, Claude Code for review, Gemini CLI for impact checks.
- Before Phase 5: ask all agents to confirm readiness and regression coverage.
