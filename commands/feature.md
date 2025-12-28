# Feature Workflow

Execute complete feature development workflow through all 5 SDLC phases.

## Arguments
- `$ARGUMENTS` - Feature description

## Process

### Phase 1: Brainstorm
```
/sdlc:brainstorm $ARGUMENTS
```
- Gather requirements
- Ask clarifying questions
- Identify dependencies
- Define scope boundaries

### Phase 2: Document
```
/sdlc:spec $ARGUMENTS
```
- Create detailed specifications
- Define acceptance criteria
- Document API contracts
- Specify test requirements

### Phase 3: Plan
```
/sdlc:plan $ARGUMENTS
```
- Technical design decisions
- Break down into missions (AB Method)
- Identify parallel work streams
- Estimate complexity and risk

### Phase 4: Execute
```
/sdlc:execute $ARGUMENTS
```
- Implement feature components
- Write tests alongside code
- Run quality gates continuously
- Address review feedback

### Phase 5: Track
```
/sdlc:status
```
- Monitor implementation progress
- Verify acceptance criteria met
- Run final quality gates
- Prepare for deployment

## Quality Gates

At each phase transition:
- [ ] Stakeholder approval on requirements
- [ ] Technical design approved by architect
- [ ] Test coverage >= 80%
- [ ] Security review passed
- [ ] Documentation complete

## Output Format

```markdown
## Feature: [Feature Name]

### Status
Phase: [1-5]
Progress: [Percentage]

### Current Mission
[Active mission description]

### Completed
- [x] Mission 1
- [x] Mission 2

### Remaining
- [ ] Mission 3
- [ ] Mission 4

### Blockers
[Any blockers identified]

### Next Steps
1. [Next action]
2. [Following action]
```

## Commit Format

```
feat(scope): [feature summary]

[Detailed description of changes]

BREAKING CHANGE: [if applicable]

Resolves #[issue-number]

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

## Example Usage

```
/feature Add user authentication with OAuth2
/feature Implement real-time notifications system
/feature Create admin dashboard with analytics
```
