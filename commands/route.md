# Model Routing

Intelligently route tasks to the optimal AI model based on task characteristics.

## Arguments
- `$ARGUMENTS` - Task type and description

## Routing Decision Matrix

### Claude Opus 4.5
**Best For:**
- Architecture and system design
- Complex reasoning and decision-making
- Security audits and vulnerability analysis
- Code review with deep analysis
- Technical specification writing

**Characteristics:**
- Extended thinking capability (32K tokens)
- Deep reasoning and nuance understanding
- Strong security and compliance knowledge

### Claude Sonnet
**Best For:**
- Standard implementation tasks
- Code refactoring and optimization
- API development
- Documentation writing
- General-purpose coding

**Characteristics:**
- Balanced speed and quality
- Cost-effective for routine tasks
- Good for iterative development

### Codex CLI (GPT-5.2)
**Best For:**
- Rapid prototyping
- Code generation and scaffolding
- Bug fixes with o3 reasoning
- Test generation
- Quick iterations

**Characteristics:**
- Fast execution
- Strong code completion
- xhigh reasoning mode available
- Good for implementation speed

### Gemini 3 Pro
**Best For:**
- Large codebase analysis (1M tokens)
- Full repository reviews
- Documentation generation
- Multi-file refactoring
- Compliance validation

**Characteristics:**
- 1M token context window
- Excellent for holistic analysis
- Strong multimodal capabilities

## Routing Process

### Step 1: Task Analysis

```markdown
## Task Classification

### Task Type
- [ ] Architecture/Design
- [ ] Implementation
- [ ] Review/Analysis
- [ ] Documentation
- [ ] Security Audit
- [ ] Bug Fix
- [ ] Testing

### Task Characteristics
- Complexity: Low | Medium | High | Critical
- Context Size: <10K | 10-100K | >100K tokens
- Reasoning Required: Standard | Extended | Maximum
- Speed Priority: High | Medium | Low
- Cost Sensitivity: High | Medium | Low
```

### Step 2: Model Recommendation

```markdown
## Routing Recommendation

### Primary Model: [Model Name]
**Confidence:** 95%

**Rationale:**
- [Reason 1]
- [Reason 2]
- [Reason 3]

### Alternative Models
1. **[Model 2]** - If [condition]
2. **[Model 3]** - If [condition]

### Cost-Benefit Analysis
| Model | Time | Cost | Quality | Score |
|-------|------|------|---------|-------|
| Opus  | 5min | $$$  | 95%     | 8.5   |
| Sonnet| 2min | $$   | 90%     | 9.0   |
| Codex | 1min | $$   | 85%     | 8.0   |
| Gemini| 3min | $    | 92%     | 9.5   |
```

### Step 3: Execution

#### For Claude Opus/Sonnet
```markdown
Execute task directly in Claude Code with appropriate thinking mode:
- Standard tasks: Default thinking
- Complex tasks: `think hard`
- Critical decisions: `ultrathink`
```

#### For Codex
```bash
# Standard execution
codex exec "$ARGUMENTS"

# With maximum reasoning (xhigh)
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' "$ARGUMENTS"

# For specific model
codex exec -m o3 "$ARGUMENTS"
```

#### For Gemini
```bash
# Standard execution with auto-approve
gemini -y "$ARGUMENTS"

# With specific model
gemini -m gemini-3-pro "$ARGUMENTS"

# For large context
gemini -m gemini-3-pro -y "Analyze entire codebase: $ARGUMENTS"
```

## Routing Rules

### Rule 1: Context Size Threshold
```
IF context_size > 100K tokens THEN
  route_to: Gemini 3 Pro
  reason: "1M context window required"
```

### Rule 2: Security-Critical Tasks
```
IF task_type == "security_audit" THEN
  route_to: Claude Opus
  require: ultrathink mode
  reason: "Security requires deep analysis"
```

### Rule 3: Rapid Prototyping
```
IF task_type == "prototype" AND speed_priority == "high" THEN
  route_to: Codex
  model: gpt-5.2-codex
  reason: "Fastest implementation"
```

### Rule 4: Architecture Decisions
```
IF task_type == "architecture" OR complexity == "critical" THEN
  route_to: Claude Opus
  thinking_mode: ultrathink
  reason: "Complex decision-making required"
```

### Rule 5: Standard Implementation
```
IF task_type == "implementation" AND complexity == "medium" THEN
  route_to: Claude Sonnet
  reason: "Balanced quality and speed"
```

### Rule 6: Full Codebase Analysis
```
IF task_contains("entire", "full", "complete") AND target == "codebase" THEN
  route_to: Gemini 3 Pro
  reason: "Large context analysis needed"
```

## Multi-Model Consensus

For critical tasks, use tri-agent consensus:

```markdown
## Consensus Workflow

### Task: [Description]

### Agent 1: Claude Opus (Architecture)
**Role:** Design validation
**Output:** [Analysis]

### Agent 2: Codex (Implementation)
**Role:** Implementation review
**Output:** [Review]

### Agent 3: Gemini (Security/Compliance)
**Role:** Security audit
**Output:** [Audit]

### Consensus Decision
**Votes:** 3/3 Approve | 2/3 Approve with Changes | 0/3 Reject
**Final Decision:** [Outcome]
```

## Output Format

```markdown
## Routing Decision

### Task Summary
[Brief description]

### Selected Model: [Model Name]
**Confidence:** [Percentage]

### Routing Rationale
1. [Primary reason]
2. [Supporting reason]
3. [Additional factor]

### Execution Command
\`\`\`bash
[Exact command to run]
\`\`\`

### Expected Outcome
- Duration: [Estimated time]
- Cost: [Estimated cost]
- Quality: [Expected quality level]

### Fallback Options
If primary model fails or unavailable:
1. [Fallback 1]
2. [Fallback 2]
```

## Example Usage

```
/route architecture Design microservices communication pattern
/route implementation Build user authentication API
/route review Analyze entire authentication module
/route security Audit payment processing code
/route documentation Generate API docs from codebase
```

## Routing Metrics

Track routing decisions to improve accuracy:

```json
{
  "task_id": "route-001",
  "task_type": "implementation",
  "selected_model": "codex",
  "confidence": 0.95,
  "actual_duration": "2m15s",
  "quality_score": 0.92,
  "cost": 0.05,
  "user_satisfaction": "high"
}
```

## Integration with Tri-Agent System

```bash
# 1. Route task to optimal model
/route [type] [task description]

# 2. Execute with selected model
# (Command provided in routing output)

# 3. Validate with complementary model
# Architecture → Validate with Codex
# Implementation → Review with Opus
# Security → Cross-check with Gemini
```
