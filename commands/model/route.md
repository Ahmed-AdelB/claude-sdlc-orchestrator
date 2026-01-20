# Model Routing

Route tasks to the optimal AI model based on complexity, context size, and budget.

## Arguments

- `$ARGUMENTS` - Task description and optional flags (--budget low|medium|high)

## Routing Decision Matrix

| Task Type               | Context Size | Complexity | Recommended Model |
| ----------------------- | ------------ | ---------- | ----------------- |
| Architecture/Security   | Any          | High       | Claude Opus       |
| Large Codebase Analysis | >100K        | Any        | Gemini 3 Pro      |
| Standard Features       | <100K        | Medium     | Claude Sonnet     |
| Scripts/Prototypes      | <50K         | Low        | Codex GPT-5.2     |
| Documentation           | >50K         | Low        | Gemini 3 Pro      |

## Budget Modes

| Mode              | Behavior                           | Default Model |
| ----------------- | ---------------------------------- | ------------- |
| `--budget low`    | Minimize cost, prefer Gemini/Codex | Codex         |
| `--budget medium` | Balance cost/quality (default)     | Sonnet        |
| `--budget high`   | Maximum capability, no cost limit  | Opus          |

## Cost Estimation (per 1K tokens)

| Model         | Input   | Output  | Best For          |
| ------------- | ------- | ------- | ----------------- |
| Claude Opus   | $0.015  | $0.075  | Complex reasoning |
| Claude Sonnet | $0.003  | $0.015  | Daily development |
| Codex GPT-5.2 | $0.001  | $0.002  | Fast prototyping  |
| Gemini 3 Pro  | $0.0005 | $0.0015 | Large context     |

## Process

### Step 1: Analyze Task

```markdown
## Task Analysis

- **Description:** [User's task description]
- **Estimated Context:** [tokens]
- **Complexity:** Low/Medium/High
- **Budget Mode:** [from --budget flag or default medium]
```

### Step 2: Select Model

Based on analysis:

1. Check explicit budget constraint
2. Evaluate context requirements (>100K → Gemini)
3. Assess complexity (High → Opus, Medium → Sonnet, Low → Codex)
4. Apply cost optimization if budget=low

### Step 3: Estimate Cost

```markdown
## Cost Estimate

- **Input tokens:** ~[X]K
- **Output tokens:** ~[Y]K
- **Estimated cost:** $[Z]
- **Selected model:** [Model Name]
```

### Step 4: Execute or Delegate

```bash
# For Gemini tasks:
gemini -m gemini-3-pro-preview --approval-mode yolo "[task]"

# For Codex tasks:
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "[task]"

# For Claude tasks:
# Use Task tool with appropriate model parameter
```

## Routing Decision Log

Track all routing decisions for optimization:

```json
{
  "timestamp": "ISO-8601",
  "task_summary": "...",
  "context_tokens": 0,
  "complexity": "medium",
  "budget": "medium",
  "selected_model": "claude-sonnet",
  "estimated_cost": 0.0,
  "actual_cost": 0.0,
  "success": true
}
```

Log location: `~/.claude/logs/routing-decisions.jsonl`

## Fallback Strategy

If primary model fails:

1. **Claude Opus** → Claude Sonnet → Gemini Pro
2. **Gemini 3 Pro** → Gemini 2.5 Pro → Claude Sonnet
3. **Codex GPT-5.2** → Codex o3 → Claude Sonnet

## Usage Examples

```bash
# Default routing (medium budget)
/model:route "Refactor the authentication module"

# Low budget mode
/model:route "Generate unit tests" --budget low

# High budget for complex task
/model:route "Design microservices architecture" --budget high
```
