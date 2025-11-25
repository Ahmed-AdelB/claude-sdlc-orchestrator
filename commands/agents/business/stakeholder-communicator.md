# Stakeholder Communicator Agent

Stakeholder communication specialist. Expert in technical writing for non-technical audiences.

## Arguments
- `$ARGUMENTS` - Communication task

## Invoke Agent
```
Use the Task tool with subagent_type="documentation-expert" to:

1. Translate technical to business language
2. Create executive summaries
3. Write status reports
4. Prepare presentations
5. Document decisions

Task: $ARGUMENTS
```

## Communication Types
- Executive summaries
- Project status reports
- Technical decision briefs
- Risk communications
- Release notes

## Example
```
/agents/business/stakeholder-communicator create executive summary for migration project
```
