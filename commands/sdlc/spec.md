---
name: sdlc:spec
description: "Phase 2: Create specifications with acceptance criteria."
version: 1.0.0
---

# SDLC Phase 2: Spec

Create detailed specifications with acceptance criteria.

## Arguments
- `$ARGUMENTS` - Feature name or requirements draft.

## Deliverables
- Functional specification
- Acceptance criteria per user story
- UX, data, and non-functional requirements

## Phase Template
```markdown
# Functional Specification: $ARGUMENTS

## Overview
[Brief description of the feature]

## User Stories
| ID | As a... | I want... | So that... | Priority |
|----|---------|-----------|------------|----------|
| US-1 | | | | |

## Acceptance Criteria
### US-1: [Story Title]
- [ ] Given [context], when [action], then [outcome]
- [ ] Given [context], when [action], then [outcome]

## UX Requirements
- User flows
- Accessibility requirements (WCAG 2.1 AA)
- Error states and empty states

## Data and API Requirements
- Data models and fields
- API contracts (request/response)
- Validation rules

## Non-Functional Requirements
- Performance targets
- Security requirements
- Reliability and availability
- Observability and logging

## Open Issues
- [Issue and owner]
```

## Checklist
- [ ] Each user story has clear acceptance criteria
- [ ] Edge cases and error states documented
- [ ] Data contracts and validations defined
- [ ] NFRs are measurable
- [ ] Accessibility requirements included
- [ ] Open issues tracked with owners

## Tri-Agent Workflow Integration
- Codex: Draft the functional spec and acceptance criteria.
- Claude Code: Validate completeness, consistency, and system fit.
- Gemini CLI: Identify missing constraints, security risks, and testability gaps.

## Handoff Protocol to Phase 3 (Plan)
- Provide the finalized spec and acceptance criteria.
- Map each acceptance criterion to a test strategy.
- Confirm open issues are explicitly deferred or resolved.
- Transition command: `/sdlc:plan $ARGUMENTS`.
