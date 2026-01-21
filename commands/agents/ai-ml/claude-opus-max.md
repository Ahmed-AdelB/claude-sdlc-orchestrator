---
name: claude-opus-max
description: Maximum capability Claude agent using Opus 4.5 with ultrathink (32K thinking tokens) for the most complex tasks requiring deep reasoning, architecture decisions, and security audits.
version: 2.0.0
author: Ahmed Adel Bakr Alderai
category: ai-ml
mode: meta-agent
tools:
  - Read
  - Write
  - Task
integrations:
  - model-router
  - orchestrator
  - architect
cost:
  input: $15/1M tokens
  output: $75/1M tokens
  daily_cap: $15
context_window: 200000
thinking_budget: 32000
---

# Claude Opus Max Agent

Maximum-powered Claude Code agent using Opus 4.5 with ultrathink (32K token thinking budget) for the most complex tasks requiring deep reasoning, exhaustive analysis, and mission-critical decision-making.

## Arguments

- `$ARGUMENTS` - Complex task requiring deep reasoning (architecture, security, debugging)

---

## 1. When to Use Opus Max

### Primary Use Cases

| Use Case                   | Description                                                          | Why Opus Max                                                        |
| -------------------------- | -------------------------------------------------------------------- | ------------------------------------------------------------------- |
| **Architecture Decisions** | System design, microservices decomposition, technology selection     | Requires weighing multiple trade-offs with long-term implications   |
| **Security Audits**        | Vulnerability assessment, threat modeling, penetration test analysis | Must consider subtle attack vectors and defense-in-depth strategies |
| **Complex Debugging**      | Race conditions, memory leaks, distributed system failures           | Needs to hold multiple execution paths in context simultaneously    |
| **Code Migration**         | Large-scale refactoring, framework upgrades, language transitions    | Must understand both source and target patterns deeply              |
| **Critical Bug Analysis**  | Production incidents, data corruption, cascading failures            | Requires systematic root cause investigation                        |

### Decision Criteria

Use Opus Max when:

- [ ] Task requires reasoning across 50+ files or concepts
- [ ] Incorrect output would cause significant business impact
- [ ] Multiple stakeholders will rely on the output
- [ ] Problem has no obvious solution path
- [ ] Previous attempts with Sonnet were insufficient
- [ ] Security implications require exhaustive analysis

### Do NOT Use For

- Simple CRUD implementations (use Sonnet)
- Routine refactoring (use Sonnet)
- Rapid prototyping (use Codex)
- Large context analysis >100K (use Gemini)
- Documentation generation (use Gemini)

---

## 2. Ultrathink Configuration (32K Thinking Tokens)

### What is Ultrathink?

Ultrathink allocates 32,000 tokens for Claude's internal reasoning before generating a response. This enables:

- Deeper exploration of solution space
- More thorough consideration of edge cases
- Better handling of multi-step problems
- Higher quality architectural decisions

### Configuration Methods

#### Method 1: Environment Variable

```bash
export MAX_THINKING_TOKENS=32000
export ANTHROPIC_MODEL=opus
claude --model opus
```

#### Method 2: settings.json

```json
{
  "model": "opus",
  "alwaysThinkingEnabled": true,
  "env": {
    "MAX_THINKING_TOKENS": "32000",
    "ANTHROPIC_MODEL": "opus"
  }
}
```

#### Method 3: Per-Session Selection

```bash
# Select Opus model for current session
/model opus

# Check current model
/status
```

### Thinking Budget Tiers

| Mode       | Tokens | Use Case                                   | Cost Impact |
| ---------- | ------ | ------------------------------------------ | ----------- |
| think      | 4K     | Simple tasks, quick answers                | +$0.30      |
| megathink  | 10K    | Complex logic, multi-file changes          | +$0.75      |
| ultrathink | 32K    | Architecture, security, critical debugging | +$2.40      |

### Verification

Confirm ultrathink is active:

```bash
# View thinking output (verbose mode)
Ctrl+O

# Check settings
/config
```

---

## 3. Task Types Best Suited for Deep Reasoning

### Tier 1: Architecture & Design (Highest Value)

| Task                        | Thinking Requirement | Expected Output                                            |
| --------------------------- | -------------------- | ---------------------------------------------------------- |
| System architecture design  | 32K                  | Component diagrams, ADRs, interface contracts              |
| Database schema design      | 24K                  | ERD, migration strategy, indexing plan                     |
| API contract design         | 16K                  | OpenAPI spec, versioning strategy, error taxonomy          |
| Microservices decomposition | 32K                  | Service boundaries, communication patterns, data ownership |

### Tier 2: Security & Compliance

| Task                       | Thinking Requirement | Expected Output                                              |
| -------------------------- | -------------------- | ------------------------------------------------------------ |
| OWASP vulnerability audit  | 32K                  | Finding report, severity rankings, remediation plan          |
| Threat modeling            | 32K                  | STRIDE analysis, attack trees, mitigation strategies         |
| Authentication flow design | 24K                  | Sequence diagrams, token strategy, session management        |
| Compliance gap analysis    | 24K                  | Control mapping, evidence requirements, remediation timeline |

### Tier 3: Complex Debugging

| Task                       | Thinking Requirement | Expected Output                                              |
| -------------------------- | -------------------- | ------------------------------------------------------------ |
| Race condition analysis    | 32K                  | Execution timeline, lock ordering, fix proposal              |
| Memory leak investigation  | 24K                  | Allocation tracking, lifecycle analysis, fix                 |
| Distributed system failure | 32K                  | Causality chain, network partition analysis, resilience plan |
| Performance bottleneck     | 16K                  | Profile analysis, hotspot identification, optimization plan  |

### Tier 4: Strategic Planning

| Task                          | Thinking Requirement | Expected Output                                      |
| ----------------------------- | -------------------- | ---------------------------------------------------- |
| Technical debt prioritization | 24K                  | Debt inventory, ROI ranking, refactoring roadmap     |
| Technology selection          | 32K                  | Comparison matrix, risk analysis, recommendation     |
| Migration planning            | 32K                  | Phase breakdown, rollback strategy, success criteria |

---

## 4. Integration with Tri-Agent Workflow

### Role in Tri-Agent System

```
+-------------------+
|   Claude Opus Max |  <- Architecture, Security, Core Logic
+-------------------+
         |
    Orchestrates
         |
+--------+--------+
|                 |
v                 v
+----------+  +------------+
| Codex    |  | Gemini     |
| GPT-5.2  |  | 3 Pro      |
+----------+  +------------+
Implementation   Analysis
```

### Phase Assignments

| Phase              | Opus Max Role                                  | Handoff To                |
| ------------------ | ---------------------------------------------- | ------------------------- |
| **Planning**       | Define architecture, identify risks            | Gemini (context analysis) |
| **Implementation** | Review critical paths, security code           | Codex (implementation)    |
| **Verification**   | Final security review, architecture compliance | Gemini (documentation)    |

### Tri-Agent Invocation Pattern

```bash
# Phase 1: Opus designs architecture
# (Direct in Claude Code with ultrathink)

# Phase 2: Hand off to Codex for implementation
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write \
  "Implement the authentication service based on this architecture: [OPUS_OUTPUT]"

# Phase 3: Gemini verifies and documents
gemini -m gemini-3-pro-preview --approval-mode yolo \
  "Verify implementation matches architecture and generate API documentation"
```

### Verification Protocol

Opus Max outputs MUST be verified by a different AI:

```markdown
VERIFY:

- Scope: Architecture decision for [component]
- Change summary: [Opus recommendation]
- Expected behavior: [Concrete outcomes]
- Evidence to check: [ADR, diagrams, interface contracts]
- Risk notes: [Edge cases, failure modes]

Verifier: Gemini (3 Pro) or Codex (GPT-5.2)
```

---

## 5. Cost Considerations

### Pricing Model

| Metric          | Rate   | Example                |
| --------------- | ------ | ---------------------- |
| Input tokens    | $15/1M | 50K context = $0.75    |
| Output tokens   | $75/1M | 10K response = $0.75   |
| Thinking tokens | $75/1M | 32K ultrathink = $2.40 |

### Typical Task Costs

| Task Type                 | Input | Output | Thinking | Total |
| ------------------------- | ----- | ------ | -------- | ----- |
| Quick architecture review | 20K   | 5K     | 16K      | $1.93 |
| Full system design        | 80K   | 15K    | 32K      | $5.73 |
| Security audit            | 100K  | 20K    | 32K      | $6.40 |
| Complex debugging         | 50K   | 10K    | 32K      | $4.15 |

### Budget Management

```bash
# Daily cap enforcement
OPUS_DAILY_CAP=$15.00

# Pre-flight cost prediction
Predicted Cost = (Input * $0.015) + (Output * $0.075) + (Thinking * $0.075)

# Alert thresholds
70% cap ($10.50) -> WARNING: Consider switching to Sonnet
90% cap ($13.50) -> PAUSE: Require explicit approval
100% cap ($15.00) -> STOP: Route all tasks to Sonnet/Gemini
```

### Cost Optimization Strategies

1. **Context Pruning**: Remove irrelevant files before invoking Opus
2. **Staged Analysis**: Use Gemini for initial context, Opus for decision-making
3. **Selective Ultrathink**: Use 16K for medium tasks, reserve 32K for critical
4. **Batch Similar Tasks**: Combine related architecture decisions in single session

---

## 6. Context Window Optimization (200K Tokens)

### Context Budget Allocation

| Category             | Allocation | Purpose                         |
| -------------------- | ---------- | ------------------------------- |
| System prompt        | 5K         | Agent instructions, rules       |
| Relevant code        | 100K       | Primary files under analysis    |
| Supporting context   | 50K        | Dependencies, interfaces, tests |
| Conversation history | 25K        | Prior exchanges in session      |
| Thinking budget      | 32K        | Internal reasoning (separate)   |
| Response buffer      | 20K        | Output generation               |

### Context Loading Strategy

```bash
# Priority 1: Core files (always include)
/read src/core/**/*.ts

# Priority 2: Interfaces (include if relevant)
/read src/types/**/*.ts

# Priority 3: Tests (include for debugging)
/read tests/unit/**/*.test.ts

# Priority 4: Config (include if deployment-related)
/read config/*.json
```

### When Context Exceeds 200K

1. **Split Task**: Break into focused sub-problems
2. **Delegate to Gemini**: Use Gemini's 1M context for initial analysis
3. **Summarize First**: Create condensed context via Gemini, then analyze with Opus
4. **Iterative Deep Dive**: Analyze sections sequentially, maintaining findings

### Context Handoff Pattern

```bash
# Gemini analyzes full codebase (1M context)
SUMMARY=$(gemini -m gemini-3-pro-preview --approval-mode yolo \
  "Analyze entire codebase. Summarize architecture, identify security concerns, list critical paths.")

# Opus makes decisions on condensed context
# (In Claude Code session)
"Based on this codebase analysis: $SUMMARY
Design the authentication refactoring strategy."
```

---

## 7. Best Practices for Prompting Opus

### Prompt Structure

```markdown
## Context

[Provide relevant background, constraints, and goals]

## Current State

[Describe what exists now]

## Desired Outcome

[Specify concrete deliverables]

## Constraints

[List non-negotiables: performance, security, compatibility]

## Evaluation Criteria

[How will success be measured?]
```

### Effective Prompting Patterns

#### Pattern 1: Architectural Decision

```markdown
Design a [system/component] that:

1. Handles [scale requirements]
2. Integrates with [existing systems]
3. Maintains [quality attributes]

Provide:

- Component diagram (Mermaid)
- Interface contracts (TypeScript)
- ADR documenting the decision
- Risk analysis with mitigations
```

#### Pattern 2: Security Audit

```markdown
Conduct a security review of [component/codebase]:

Focus areas:

1. Authentication and authorization
2. Input validation and sanitization
3. Data protection (at rest, in transit)
4. Error handling and information disclosure
5. Dependency vulnerabilities

Output format:

- Severity-ranked findings (CRITICAL/HIGH/MEDIUM/LOW)
- Affected code with line numbers
- Remediation recommendations
- Verification steps
```

#### Pattern 3: Complex Debugging

```markdown
Debug [issue description]:

Symptoms:

- [Observable behavior]
- [Error messages/logs]
- [Reproduction steps]

Environment:

- [System configuration]
- [Recent changes]

Requested analysis:

1. Root cause hypothesis
2. Evidence supporting/refuting each hypothesis
3. Diagnostic steps to confirm
4. Fix proposal with test coverage
```

### Anti-Patterns to Avoid

| Anti-Pattern             | Problem                  | Better Approach                                    |
| ------------------------ | ------------------------ | -------------------------------------------------- |
| Vague goals              | "Make it better"         | Specify metrics: "Reduce latency to <100ms"        |
| Missing constraints      | Unbounded solution space | List: budget, timeline, compatibility requirements |
| Single-shot complex task | Overwhelms context       | Break into phases with checkpoints                 |
| No success criteria      | Cannot verify completion | Define acceptance tests upfront                    |

---

## 8. Handoff Patterns To/From Other Agents

### Opus -> Codex (Implementation Handoff)

```bash
# Opus produces architecture spec
ARCH_SPEC=$(cat <<'EOF'
## Authentication Service Architecture
- JWT-based with refresh tokens
- Redis session store
- Rate limiting at gateway
[Full spec from Opus...]
EOF
)

# Codex implements
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write \
  "Implement this architecture: $ARCH_SPEC

  Generate:
  1. src/auth/jwt.service.ts
  2. src/auth/session.service.ts
  3. src/middleware/rate-limit.ts
  4. tests/auth/*.test.ts"
```

### Opus -> Gemini (Documentation Handoff)

```bash
# Opus produces technical decisions
DECISIONS=$(cat <<'EOF'
## ADR-007: Event-Driven Architecture
Status: Accepted
Context: Need async processing for high-throughput...
[Full ADR from Opus...]
EOF
)

# Gemini generates documentation
gemini -m gemini-3-pro-preview --approval-mode yolo \
  "Generate comprehensive documentation from this ADR: $DECISIONS

  Include:
  1. System overview for stakeholders
  2. Developer integration guide
  3. Operations runbook
  4. API reference"
```

### Gemini -> Opus (Analysis Handoff)

```bash
# Gemini analyzes large codebase
ANALYSIS=$(gemini -m gemini-3-pro-preview --approval-mode yolo \
  "Analyze the entire repository. Identify:
  1. Architectural patterns in use
  2. Technical debt hotspots
  3. Security concerns
  4. Performance bottlenecks")

# Opus makes strategic decisions
# (In Claude Code with ultrathink)
"Based on this codebase analysis:
$ANALYSIS

Prioritize the top 5 improvements by ROI.
Create a 3-sprint remediation plan with dependencies."
```

### Codex -> Opus (Escalation Handoff)

```bash
# Codex hits complexity limit
CODEX_BLOCKER="Unable to resolve circular dependency between
AuthService and UserService without breaking changes."

# Escalate to Opus for architectural guidance
# (In Claude Code with ultrathink)
"Codex encountered this blocker:
$CODEX_BLOCKER

Analyze the dependency structure and propose:
1. Refactoring strategy to break the cycle
2. Migration path that maintains backward compatibility
3. Test strategy to verify no regressions"
```

---

## 9. Quality Verification for Opus Outputs

### Verification Checklist

Before accepting Opus output as complete:

- [ ] **Completeness**: All requested deliverables present
- [ ] **Consistency**: No contradictions between sections
- [ ] **Feasibility**: Implementation is technically viable
- [ ] **Security**: No obvious vulnerabilities introduced
- [ ] **Testability**: Clear verification steps provided
- [ ] **Documentation**: Decisions are well-justified

### Two-Key Verification Protocol

```markdown
VERIFY:

- Scope: [Opus output scope]
- Change summary: [What Opus produced]
- Expected behavior: [Concrete outcomes]
- Repro steps: [How to validate]
- Evidence to check: [Artifacts to review]
- Risk notes: [Edge cases, failure modes]
```

### Verifier Assignment

| Opus Output Type    | Primary Verifier         | Secondary Verifier                 |
| ------------------- | ------------------------ | ---------------------------------- |
| Architecture design | Gemini (context check)   | Codex (implementation feasibility) |
| Security audit      | Codex (test coverage)    | Gemini (pattern verification)      |
| Debugging analysis  | Codex (fix validation)   | Gemini (regression check)          |
| Migration plan      | Gemini (impact analysis) | Codex (automation feasibility)     |

### Verification Commands

```bash
# Gemini verification (read-only, YOLO allowed)
gemini -m gemini-3-pro-preview --approval-mode yolo \
  "Verify this architecture design:
  [OPUS_OUTPUT]

  Check:
  1. Consistency with existing codebase patterns
  2. Complete coverage of requirements
  3. No obvious security gaps
  4. Feasibility of implementation

  Output: PASS/FAIL with detailed findings"

# Codex verification (implementation test)
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write \
  "Validate this design is implementable:
  [OPUS_OUTPUT]

  Create:
  1. Skeleton implementation
  2. Interface stubs
  3. Test scaffolding

  Report any blockers or ambiguities."
```

---

## 10. Example Workflows Using Opus Max

### Example 1: Microservices Architecture Design

```markdown
## Request

Design a microservices architecture for an e-commerce platform
handling 10K orders/minute with global distribution.

## Opus Max Workflow

### Step 1: Context Loading

/read src/monolith/\*_/_.ts
/read docs/requirements/_.md
/read infrastructure/_.yaml

### Step 2: Ultrathink Analysis (32K)

[Opus analyzes requirements, identifies bounded contexts,
evaluates trade-offs between consistency and availability]

### Step 3: Output Deliverables

1. Service decomposition diagram (Mermaid)
2. Data ownership matrix
3. API contracts (OpenAPI)
4. ADR-012: Microservices Migration
5. Event schema definitions
6. Infrastructure requirements

### Step 4: Handoff

- Codex: Implement service skeletons
- Gemini: Generate documentation
- Codex: Create infrastructure as code

### Step 5: Verification

Gemini verifies consistency with requirements
Codex validates implementation feasibility
```

### Example 2: Security Incident Response

```markdown
## Request

Production database credentials were potentially exposed.
Conduct security audit and remediation plan.

## Opus Max Workflow

### Step 1: Context Loading

/read src/config/\*_/_.ts
/read .env.example
/read infrastructure/secrets/\*.yaml
/read logs/access.log (last 24h summary)

### Step 2: Ultrathink Analysis (32K)

[Opus traces credential flow, identifies exposure points,
assesses blast radius, prioritizes remediation]

### Step 3: Output Deliverables

1. Exposure timeline reconstruction
2. Affected systems inventory
3. Immediate containment steps
4. Credential rotation procedure
5. Long-term hardening recommendations
6. Monitoring enhancements

### Step 4: Handoff

- Codex: Implement secrets management migration
- Gemini: Document incident for compliance
- Codex: Create automated rotation scripts

### Step 5: Verification

Gemini verifies compliance requirements met
Codex validates new secrets infrastructure
```

### Example 3: Performance Optimization

```markdown
## Request

API response times degraded from 50ms to 800ms after
deploying new feature. Identify root cause and fix.

## Opus Max Workflow

### Step 1: Context Loading

/read src/api/routes/**/\*.ts
/read src/services/feature-x/**/_.ts
/read profiles/cpu-_.json
/read logs/slow-query.log

### Step 2: Ultrathink Analysis (32K)

[Opus correlates timeline with deployments, analyzes
query patterns, identifies N+1 queries, evaluates
caching strategies]

### Step 3: Output Deliverables

1. Root cause analysis report
2. Query optimization recommendations
3. Caching strategy proposal
4. Database index suggestions
5. Load test scenarios
6. Rollback criteria

### Step 4: Handoff

- Codex: Implement query optimizations
- Codex: Add caching layer
- Gemini: Document performance baseline

### Step 5: Verification

Codex runs load tests
Gemini compares before/after metrics
```

---

## Quick Reference

### Invocation

```bash
# Select Opus for session
/model opus

# Or via environment
export ANTHROPIC_MODEL=opus
export MAX_THINKING_TOKENS=32000
```

### Configuration Summary

| Setting         | Value                    |
| --------------- | ------------------------ |
| Model ID        | claude-opus-4-5-20251101 |
| Context Window  | 200K tokens              |
| Thinking Budget | 32K tokens (ultrathink)  |
| Input Cost      | $15/1M tokens            |
| Output Cost     | $75/1M tokens            |
| Daily Cap       | $15                      |
| Rate Limit      | ~200-800 prompts/5hr     |

### Command

```
/agents/ai-ml/claude-opus-max [task description]
```

### Example

```
/agents/ai-ml/claude-opus-max Design a distributed event-driven architecture for real-time analytics processing 10M events/second with exactly-once delivery guarantees
```

---

## Related Agents

- `/agents/ai-ml/codex-max` - Implementation partner for Opus designs
- `/agents/ai-ml/gemini-deep` - Large context analysis partner
- `/agents/general/model-router` - Automatic model selection
- `/agents/general/orchestrator` - Multi-agent coordination
- `/agents/planning/architect` - Architecture documentation
- `/agents/security/security-expert` - Security-focused analysis
