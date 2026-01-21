---
name: sdlc:status
description: "Phase 5: Monitor progress and update stakeholders."
version: 1.0.0
---

# SDLC Phase 5: Status

Monitor progress and update stakeholders.

## Arguments
- `$ARGUMENTS` - Feature name or "all" for portfolio status.

## Deliverables
- Status report with progress and risks
- Updated mission tracking
- Stakeholder-ready summary

## Phase Template
```markdown
# SDLC Status Report

## Feature: $ARGUMENTS
Date: [current date]
Phase: [current phase]

## Progress Overview
| Phase | Status | Completion |
|-------|--------|------------|
| 1. Brainstorm | Complete | 100% |
| 2. Spec | Complete | 100% |
| 3. Plan | Complete | 100% |
| 4. Execute | In Progress | X% |
| 5. Status | Ongoing | - |

## Mission Status
| Mission | Status | Notes |
|---------|--------|-------|
| Mission 1 | Complete | |
| Mission 2 | In Progress | |
| Mission 3 | Pending | |

## Quality Metrics
- Test coverage: X%
- Linting: Pass/Fail
- Type errors: X
- Security issues: X

## Risks and Blockers
- [ ] Blocker 1
- [ ] Blocker 2

## Next Steps
1. [Next action]
2. [Next action]

## Timeline
- Started: [date]
- Target completion: [date]
- Current estimate: [date]
```

## Checklist
- [ ] Status reflects latest plan and mission updates
- [ ] Quality metrics are current
- [ ] Risks and blockers have owners
- [ ] Next steps are actionable and prioritized
- [ ] Stakeholder summary is clear and concise

## Tri-Agent Workflow Integration
- Codex: Compile progress, metrics, and open issues.
- Claude Code: Validate technical status and testing accuracy.
- Gemini CLI: Flag risk trends and security concerns.

## Handoff Protocols
- To stakeholders: share report, highlight risks and asks.
- To Phase 4 (Execute): feed back blockers and re-prioritized missions.
- To Phase 1 (Brainstorm): capture new requirements discovered during execution.
