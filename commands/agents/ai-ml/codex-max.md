# Codex Max Agent

Maximum-powered Codex CLI agent using GPT-5.2-Codex with xhigh reasoning effort for project-scale coding tasks.

## Arguments

- `$ARGUMENTS` - Large-scale coding task

## Configuration (ChatGPT Pro Subscription)

- **Subscription:** ChatGPT Pro ($200/mo)
- **Model:** gpt-5.2-codex (FORCED - NOT o3, NOT older models)
- **Reasoning Effort:** xhigh (maximum available)
- **Context Window:** 400,000 tokens
- **Max Output:** 128,000 tokens
- **Limits:** ~300-1500 local / ~50-400 cloud per 5 hours
- **Auth:** Sign in with ChatGPT Pro credentials

## Invoke Agent

Use the Task tool with subagent_type="general-purpose" to act as Codex Max:

Execute with maximum reasoning power using Codex CLI:

1. Perform project-scale refactoring across entire codebases
2. Implement full-stack features end-to-end
3. Remediate vulnerabilities across all affected files
4. Optimize complex algorithms with comprehensive analysis
5. Generate multi-file implementations with full context awareness

Task: $ARGUMENTS

## CLI Execution

```bash
# Execute with xhigh reasoning (ALWAYS use gpt-5.2-codex)
codex exec --model gpt-5.2-codex "$ARGUMENTS"

# With file context
codex exec --model gpt-5.2-codex --context . "$ARGUMENTS"

# Use max-reasoning profile
codex --profile max-reasoning "$ARGUMENTS"
```

## config.toml Settings

```toml
# FORCED: gpt-5.2-codex with xhigh reasoning everywhere
model = "gpt-5.2-codex"
model_context_window = 400000
model_max_output_tokens = 128000
model_reasoning_effort = "xhigh"
```

## When to Use

- Project-wide refactoring (100+ files)
- Full-stack feature implementation
- Complex vulnerability remediation
- Deep debugging sessions requiring hours
- Multi-file code generation

## Reasoning Effort Levels

| Level   | Thinking Time | Use Case                                   |
| ------- | ------------- | ------------------------------------------ |
| none    | Instant       | No reasoning needed                        |
| minimal | Fastest       | Quick questions                            |
| low     | Fast          | Simple tasks                               |
| medium  | Standard      | Daily driver                               |
| high    | Extended      | Complex tasks                              |
| xhigh   | Maximum       | Project-scale work (default for Codex Max) |

## Example

```
/agents/ai-ml/codex-max Refactor the entire authentication system from session-based to JWT with refresh tokens across all 50+ affected files
```
