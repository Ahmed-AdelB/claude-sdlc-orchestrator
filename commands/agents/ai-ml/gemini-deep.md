# Gemini Deep Agent

Maximum-powered Gemini CLI agent using Gemini 3 Pro with Deep Think mode for comprehensive research and analysis with 1M token context.

## Arguments

- `$ARGUMENTS` - Research or analysis task requiring full context

## Configuration (Google AI Ultra Subscription)

- **Subscription:** Google AI Ultra ($20/mo) or waitlist access
- **Model:** gemini-3-pro-preview
- **Thinking Level:** high (maximum reasoning - cannot be disabled on Gemini 3 Pro)
- **Mode:** Deep Think (extended reasoning)
- **Context:** 1M tokens
- **Limits:** Highest daily limits with Ultra subscription

## Setup (One-time)

```bash
# Upgrade to latest CLI (v0.16.x+ required)
npm install -g @google/gemini-cli@latest

# Authenticate
gemini auth login

# Enable Preview features (required for Gemini 3)
# Run: /settings -> Toggle "Preview features" to true

# Or use --model flag directly
gemini --model gemini-3-pro-preview
```

## settings.json Configuration

```json
{
  "previewFeatures": true,
  "general": {
    "preferredModel": "gemini-3-pro-preview"
  },
  "routing": {
    "preferPro": true
  },
  "thinking": {
    "level": "high"
  }
}
```

## Invoke Agent

Use the Task tool with subagent_type="general-purpose" to act as Gemini Deep:

Execute deep research and analysis using Gemini 3 Pro:

1. Analyze entire codebases with full 1M token context
2. Conduct comprehensive research with extended reasoning
3. Generate detailed documentation from complete source
4. Identify cross-repository patterns and dependencies
5. Create architecture documentation with full system context

Task: $ARGUMENTS

## CLI Execution

```bash
# Deep analysis with auto-approve (YOLO mode)
gemini -m gemini-3-pro-preview -y "$ARGUMENTS"

# With full directory context
gemini -m gemini-3-pro-preview -y "Analyze this codebase"

# Interactive deep research session
gemini -m gemini-3-pro-preview -i
```

## When to Use

- Full codebase analysis (entire repositories)
- Deep research requiring comprehensive context
- Documentation generation from complete source
- Cross-repository pattern analysis
- Architecture review with full system visibility

## Context Comparison

| Model        | Max Context | Full Repo Analysis |
| ------------ | ----------- | ------------------ |
| Gemini 3 Pro | 1M tokens   | Complete           |
| Claude       | 200K tokens | Partial            |
| GPT-4        | 128K tokens | Limited            |

## Benchmarks (Gemini 3 Pro)

- 93.8% on GPQA Diamond
- 41.0% on Humanity's Last Exam
- 45.1% on ARC-AGI-2

## Example

```
/agents/ai-ml/gemini-deep Analyze the entire microservices architecture across all 12 repositories and create comprehensive documentation of service interactions, data flows, and dependencies
```
