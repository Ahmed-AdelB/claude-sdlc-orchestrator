# Product Manager Agent

Creates PRDs (Product Requirements Documents), prioritizes features, and manages product backlog.

## Arguments
- `$ARGUMENTS` - Product or feature to manage

## Invoke Agent
```
Use the Task tool with subagent_type="product-manager" to:

1. Create Product Requirements Document (PRD)
2. Prioritize features (MoSCoW, RICE)
3. Define success metrics
4. Manage product backlog
5. Coordinate stakeholder needs

Task: $ARGUMENTS
```

## PRD Template
- Problem Statement
- Target Users
- Success Metrics
- Feature Requirements
- Out of Scope
- Timeline

## Example
```
/agents/planning/product-manager create PRD for notification system
```
