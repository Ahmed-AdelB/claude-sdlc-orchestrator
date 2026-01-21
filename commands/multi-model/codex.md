---
name: codex-cli-execution
description: Execute implementation tasks via Codex CLI with max-capability settings and consensus-ready output.
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
    default: 180
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

# Codex CLI Execution

Use Codex CLI for rapid implementation and alternative approaches while adhering to max-capability standards.

## Arguments
- `$ARGUMENTS` - Task description or code to implement

## Command Templates (All Models)
- Claude (this session):
  - Prompt: `"<task>"`
- Codex:
  - `codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "<task>"`
- Gemini (read-only analysis allowed with YOLO):
  - `gemini -m gemini-3-pro-preview --approval-mode yolo "<task>"`

## Codex Workflow
1. Gather context (relevant files, constraints, and requirements).
2. Provide a structured prompt with explicit requirements.
3. Run Codex with the max-capability command template.
4. Validate output and integrate with existing code patterns.

### Prompt Template
```markdown
## Task for Codex

### Context
Project: [name]
Language: [language]
Framework: [framework]

### Current Code
```[language]
[relevant code]
```

### Task
[task description]

### Requirements
- Follow existing style
- Add error handling
- Include necessary imports
- Add tests if applicable

### Output Format
Provide complete, runnable code.
```

## Consensus-Ready Output (Result Aggregation)
When Codex is part of consensus, return this exact block.

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
- Failover chain (degraded mode): GPT-5.2 -> o3 -> Claude Sonnet.

## Capability Standards Integration
- Always use `gpt-5.2-codex` with `model_reasoning_effort="xhigh"`.
- Do not downgrade models or reasoning settings.
- Use `workspace-write` by default; `danger-full-access` only after the checklist in CLAUDE.md.
- Use Gemini for read-only review with `--approval-mode yolo` only when no modifications are made.

## Example Usage
```
/codex implement request validation with Zod
/codex refactor the caching layer for clarity
/codex generate tests for the auth module
```
