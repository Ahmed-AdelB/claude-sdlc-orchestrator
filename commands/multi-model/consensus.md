# Tri-Agent Consensus

Request consensus review from all three AI agents (Claude, Codex, Gemini) for critical decisions.

## Arguments
- `$ARGUMENTS` - Topic or code to review

## Process

### Step 1: Prepare Review Request
```markdown
## Consensus Review Request

### Topic
[Topic or decision to review]

### Context
[Relevant context and background]

### Specific Questions
1. [Question 1]
2. [Question 2]
3. [Question 3]

### Artifacts
[Code, designs, or documents to review]
```

### Step 2: Distribute to Agents

#### Claude Code (Sonnet/Opus)
Focus: Code quality, security, best practices
```markdown
Review this for:
- Code quality and maintainability
- Security vulnerabilities
- Adherence to best practices
- Error handling completeness
```

#### Codex (GPT-5.1 / o3-pro)
Focus: Implementation correctness, alternatives
```markdown
Review this for:
- Implementation correctness
- Algorithm efficiency
- Alternative approaches
- Edge case handling
```

#### Gemini (2.5 Pro)
Focus: Architecture, scalability, documentation
```markdown
Review this for:
- Architectural soundness
- Scalability considerations
- Documentation completeness
- Integration impacts
```

### Step 3: Collect Responses
```markdown
## Agent Reviews

### Claude Code (Sonnet)
**Verdict:** APPROVE / APPROVE_WITH_COMMENTS / REQUEST_CHANGES

**Findings:**
- ✅ [Positive finding]
- ⚠️ [Warning]
- ❌ [Issue]

**Recommendations:**
1. [Recommendation]

---

### Codex (GPT-5.1)
**Verdict:** APPROVE / APPROVE_WITH_COMMENTS / REQUEST_CHANGES

**Findings:**
- ✅ [Positive finding]
- ⚠️ [Warning]
- ❌ [Issue]

**Recommendations:**
1. [Recommendation]

---

### Gemini (2.5 Pro)
**Verdict:** APPROVE / APPROVE_WITH_COMMENTS / REQUEST_CHANGES

**Findings:**
- ✅ [Positive finding]
- ⚠️ [Warning]
- ❌ [Issue]

**Recommendations:**
1. [Recommendation]
```

### Step 4: Determine Consensus

#### Voting Rules
| Scenario | Votes | Decision |
|----------|-------|----------|
| Unanimous Approve | 3/3 ✅ | **APPROVED** |
| Majority Approve | 2/3 ✅ | **APPROVED with discussion** |
| Unanimous Changes | 3/3 ❌ | **BLOCKED** |
| Split Decision | Mixed | **Requires resolution** |

### Step 5: Generate Consensus Report
```markdown
## Consensus Report

### Decision: [APPROVED / BLOCKED / NEEDS_RESOLUTION]

### Vote Summary
| Agent | Vote | Confidence |
|-------|------|------------|
| Claude | ✅ APPROVE | High |
| Codex | ✅ APPROVE | Medium |
| Gemini | ⚠️ COMMENTS | High |

### Consensus: 2/3 APPROVED with conditions

### Agreed Points
All agents agree on:
1. [Point of agreement]
2. [Point of agreement]

### Points of Disagreement
| Topic | Claude | Codex | Gemini |
|-------|--------|-------|--------|
| [Topic] | [View] | [View] | [View] |

### Required Actions Before Merge
1. [Action from Claude's review]
2. [Action from Codex's review]
3. [Action from Gemini's review]

### Optional Improvements
- [Suggested improvement 1]
- [Suggested improvement 2]
```

## Consensus Types

### Code Review Consensus
```
/consensus review src/auth/login.ts
```
All agents review the same code for different aspects.

### Architecture Decision
```
/consensus architecture: microservices vs monolith
```
All agents evaluate architectural options.

### Security Review
```
/consensus security: authentication implementation
```
All agents focus on security aspects.

### Performance Review
```
/consensus performance: database query optimization
```
All agents analyze performance implications.

## Conflict Resolution

### When Agents Disagree
1. **Identify the core disagreement**
2. **Gather more context** if needed
3. **Apply domain-specific tie-breaker:**

| Domain | Lead Agent | Reason |
|--------|------------|--------|
| Security | Claude | Deep security analysis |
| Algorithm | Codex | Implementation expertise |
| Architecture | Gemini | Large context understanding |
| Code Quality | Claude | Best practices focus |
| Performance | Codex | Optimization expertise |

### Escalation Path
1. Majority vote decides
2. Domain expert agent leads
3. Human decision requested

## Example Usage
```
/consensus review authentication PR
/consensus architecture decision
/consensus security audit results
/consensus before deploying to production
```

## Commit Format with Consensus
```
feat(auth): implement OAuth 2.0 login

- Add OAuth provider integration
- Implement token refresh flow
- Add session management

Tri-Agent Approval:
- Claude Code (Sonnet): APPROVE
- Codex (GPT-5.1): APPROVE
- Gemini (2.5 Pro): APPROVE

Consensus: 3/3 UNANIMOUS

Co-Authored-By: Claude <noreply@anthropic.com>
```
