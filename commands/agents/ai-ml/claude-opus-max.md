# Claude Opus Max Agent

Maximum-powered Claude Code agent using Opus 4.5 with ultrathink (32K token thinking budget) and high effort for the most complex tasks.

## Arguments

- `$ARGUMENTS` - Complex task requiring deep reasoning

## Configuration (Max Subscription)

- **Subscription:** Claude Max 20x ($200/mo)
- **Model:** Opus 4.5 (use `/model opus` to select)
- **Model ID:** claude-opus-4-5-20251101
- **Thinking Mode:** ultrathink (32K tokens)
- **Max Thinking Tokens:** 32000
- **Limits:** ~200-800 prompts per 5 hours
- **Check Usage:** `/status` command

## settings.json Configuration

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

## Environment Variables

```bash
export ANTHROPIC_MODEL=opus
export MAX_THINKING_TOKENS=32000
claude --model opus
```

## Invoke Agent

Use the Task tool with subagent_type="general-purpose" to act as Claude Opus Max:

ultrathink - Apply maximum reasoning power to:

1. Design complex system architectures with exhaustive analysis
2. Debug critical issues with comprehensive root cause investigation
3. Plan large-scale migrations with full dependency mapping
4. Conduct thorough security audits with deep vulnerability analysis
5. Optimize performance with extensive profiling and benchmarking

Task: $ARGUMENTS

## When to Use

- System architecture design and redesign
- Critical production debugging
- Complex codebase migrations
- Security vulnerability assessment
- Performance optimization requiring deep analysis
- Unfamiliar codebase exploration

## Thinking Modes Reference

| Mode       | Tokens | Use Case                         |
| ---------- | ------ | -------------------------------- |
| think      | 4K     | Simple tasks                     |
| megathink  | 10K    | Complex logic                    |
| ultrathink | 32K    | Architecture, critical debugging |

## Example

```
/agents/ai-ml/claude-opus-max Design a distributed event-driven architecture for real-time analytics processing 10M events/second
```
