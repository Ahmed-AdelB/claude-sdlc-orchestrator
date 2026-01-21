---
name: sdlc:brainstorm
description: "Phase 1: Gather requirements and ask clarifying questions."
version: 1.0.0
---

# SDLC Phase 1: Brainstorm

Gather requirements and ask clarifying questions for a new feature or change.

## Arguments
- `$ARGUMENTS` - Feature description or problem statement.

## Deliverables
- Requirements draft
- Open questions and assumptions
- Initial scope boundaries

## Phase Template
```markdown
# Requirements Draft: $ARGUMENTS

## Problem Statement
[What problem are we solving? Why now?]

## Goals
- [Goal 1]
- [Goal 2]

## Non-Goals
- [Explicitly out of scope]

## Users and Personas
- [Primary user]
- [Secondary user]

## Current Behavior
[How things work today]

## Desired Behavior
[What should change]

## Constraints
- Security:
- Performance:
- Compliance:
- Platform/Stack:

## Open Questions
1. [Question]
2. [Question]

## Assumptions
- [Assumption 1]
- [Assumption 2]

## Draft Acceptance Criteria
- [ ] [Criterion]
- [ ] [Criterion]

## Risks
- [Risk and impact]
```

## Checklist
- [ ] Problem statement and goals are clear
- [ ] Non-goals are explicit
- [ ] Users/personas identified
- [ ] Constraints captured (security, performance, compliance)
- [ ] Open questions prioritized
- [ ] Draft acceptance criteria written

## Tri-Agent Workflow Integration
- Codex: Facilitate discovery, capture requirements, and draft questions.
- Claude Code: Sanity-check scope, missing edge cases, and feasibility.
- Gemini CLI: Surface risks, compliance concerns, and system-wide impacts.

## Handoff Protocol to Phase 2 (Spec)
- Provide the requirements draft and resolved answers.
- List unresolved questions with owners and target dates.
- Confirm scope boundaries and assumptions.
- If criteria are not yet measurable, flag for Phase 2 refinement.
- Transition command: `/sdlc:spec $ARGUMENTS`.
