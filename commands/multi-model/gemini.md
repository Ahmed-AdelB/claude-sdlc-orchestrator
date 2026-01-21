---
name: gemini-cli-execution
description: Execute large-context analysis via Gemini CLI with max-capability settings and consensus-ready output.
version: "1.0.0"
command_templates:
  claude: |
    Claude Code (this session): "<task>"
  codex: |
    codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "<task>"
  gemini: |
    gemini -m gemini-3-pro-preview --approval-mode yolo "<task>"
error_handling:
  retries: 3
  backoff: "2^n seconds"
  timeouts_seconds:
    default: 120
    max: 600
  exit_codes:
    "0": success
    "1": general error, check syntax and inputs
    "2": auth failed, reauthenticate
    "124": timeout, split task or increase timeout
    "429": rate limited, backoff and retry
result_aggregation:
  output_template: Agent Review
  required_fields:
    - verdict
    - findings
    - risks
    - recommended_actions
    - confidence
capability_standards:
  source: CLAUDE.md#maximum-capability-standards
  no_downgrade: true
  codex_model: gpt-5.2-codex
  codex_reasoning: xhigh
  gemini_model: gemini-3-pro-preview
  gemini_yolo_read_only: true
---

# Gemini CLI Execution

Use Gemini CLI for large-context analysis, documentation, and cross-file reviews.

## Arguments
- `$ARGUMENTS` - Task description or content to analyze

## Command Templates (All Models)
- Claude (this session):
  - Prompt: `"<task>"`
- Codex:
  - `codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "<task>"`
- Gemini (read-only analysis allowed with YOLO):
  - `gemini -m gemini-3-pro-preview --approval-mode yolo "<task>"`

## Gemini Workflow
1. Gather large context (full modules, docs, or long diffs).
2. Provide a structured prompt with explicit questions.
3. Run Gemini with the max-capability command template.
4. Summarize findings with file references when possible.

### Prompt Template
```markdown
## Task for Gemini

### Context
[large context or file list]

### Task
[analysis request]

### Requirements
- Cover edge cases
- Reference specific files when possible
- Include risks and recommendations

### Output Format
Detailed analysis with actionable findings.
```

## Consensus-Ready Output (Result Aggregation)
When Gemini is part of consensus, return this exact block.

```markdown
## Agent Review

### Verdict
APPROVE | APPROVE_WITH_COMMENTS | REQUEST_CHANGES

### Findings
- [Finding 1]
- [Finding 2]

### Risks
- [Risk 1]
- [Risk 2]

### Recommended Actions
1. [Action 1]
2. [Action 2]

### Confidence
Low | Medium | High
```

## Error Handling and Retry Logic
- Retry up to 3 times with exponential backoff (2^n seconds).
- Exit codes: 1 (syntax), 2 (auth), 124 (timeout), 429 (rate limit).
- For timeouts, reduce context or split the task.
- Failover chain (degraded mode): 3 Pro -> 2.5 Pro -> Claude Sonnet.

## Capability Standards Integration
- Always use `gemini-3-pro-preview`.
- Do not use `-m pro` or lower-tier models.
- YOLO is allowed for read-only analysis only; omit YOLO for modifications or git operations.
- Use positional prompts; avoid deprecated flags.

## Example Usage
```
/gemini analyze authentication flow and document risks
/gemini review a large PR with 50+ file changes
/gemini generate API documentation from source
```
