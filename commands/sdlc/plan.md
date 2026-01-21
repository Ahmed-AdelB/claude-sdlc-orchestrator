---
name: sdlc:plan
description: "Phase 3: Technical design and mission breakdown."
version: 1.0.0
---

# SDLC Phase 3: Plan

Create technical design and break work into missions.

## Arguments
- `$ARGUMENTS` - Feature specification or name.

## Deliverables
- Technical design document
- Mission breakdown with dependencies
- Test strategy and risk mitigation

## Phase Template
```markdown
# Technical Design: $ARGUMENTS

## Architecture Overview
[High-level diagram or description]

## Component Breakdown
| Component | Responsibility | Technology |
|-----------|----------------|------------|
| | | |

## API Design
- Endpoints to create/modify
- Request/response schemas
- Auth and rate limits

## Data Changes
- New tables/collections
- Migrations and backfills
- Indexes and constraints

## Dependencies
- External services
- Libraries/packages
- Infrastructure requirements

## Test Strategy
- Unit tests
- Integration tests
- E2E tests (if applicable)

## Mission Breakdown
### Mission 1: [Foundation]
- Goal:
- Scope:
- Files:
- Tests:
- Dependencies:

### Mission 2: [Core Logic]
- Goal:
- Scope:
- Files:
- Tests:
- Dependencies:

### Mission 3: [Integration]
- Goal:
- Scope:
- Files:
- Tests:
- Dependencies:

## Risks and Mitigations
- Risk:
  - Mitigation:
```

## Checklist
- [ ] Architecture and components mapped to requirements
- [ ] APIs and data changes specified
- [ ] Dependencies and infra needs identified
- [ ] Mission scopes are non-overlapping and testable
- [ ] Risk mitigation documented
- [ ] Test strategy aligns with acceptance criteria

## Tri-Agent Workflow Integration
- Codex: Draft the plan and mission breakdown.
- Claude Code: Review architecture, dependencies, and sequencing.
- Gemini CLI: Evaluate scalability, performance, and security risks.

## Handoff Protocol to Phase 4 (Execute)
- Provide the approved plan and mission list.
- Assign owners or agents to missions and clarify dependencies.
- Confirm test strategy per mission.
- Transition command: `/sdlc:execute $ARGUMENTS [mission-id]`.
