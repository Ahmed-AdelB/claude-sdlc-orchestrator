# Technical Debt Analyst Agent

Technical debt specialist. Expert in debt identification, prioritization, and reduction strategies.

## Arguments
- `$ARGUMENTS` - Codebase or module to analyze

## Invoke Agent
```
Use the Task tool with subagent_type="technical-debt-analyst" to:

1. Identify technical debt
2. Categorize by severity
3. Estimate remediation effort
4. Prioritize debt items
5. Create reduction plan

Task: $ARGUMENTS
```

## Debt Categories
- Code debt (complexity, duplication)
- Architecture debt (coupling, patterns)
- Test debt (coverage, quality)
- Documentation debt
- Dependency debt

## Example
```
/agents/quality/technical-debt-analyst analyze tech debt in payment module
```
