---
name: tri-agent-consensus
description: Tri-agent consensus workflow across Claude, Codex, and Gemini with standardized aggregation.
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
  required_fields:
    - verdict
    - findings
    - risks
    - recommended_actions
    - confidence
  decision_rules:
    unanimous_approve: APPROVED
    majority_approve: APPROVED_WITH_CONDITIONS
    split: NEEDS_RESOLUTION
    unanimous_block: BLOCKED
capability_standards:
  source: CLAUDE.md#maximum-capability-standards
  no_downgrade: true
  codex_model: gpt-5.2-codex
  codex_reasoning: xhigh
  gemini_model: gemini-3-pro-preview
  gemini_yolo_read_only: true
---

# Tri-Agent Consensus

Request consensus from Claude, Codex, and Gemini for critical decisions and merge a single outcome.

## Arguments
- `$ARGUMENTS` - Topic, decision, or code to review

## Command Templates (All Models)
Use these exact templates to meet capability standards.

- Claude (this session):
  - Prompt: `"<task>"`
- Codex:
  - `codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "<task>"`
- Gemini (read-only analysis allowed with YOLO):
  - `gemini -m gemini-3-pro-preview --approval-mode yolo "<task>"`

## Request Template
```markdown
## Consensus Review Request

### Topic
[Topic or decision]

### Context
[Relevant context, constraints, and artifacts]

### Specific Questions
1. [Question 1]
2. [Question 2]
3. [Question 3]

### Artifacts
[Code snippets, file paths, or documents to review]
```

## Response Template (Per Agent)
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

## Result Aggregation
Combine all three responses into a single decision using the rules below.

### Decision Rules
- 3/3 approve: APPROVED
- 2/3 approve: APPROVED_WITH_CONDITIONS
- 1/3 approve or split: NEEDS_RESOLUTION
- 0/3 approve: BLOCKED

### Aggregated Output Template
```markdown
## Consensus Report

### Decision
[APPROVED | APPROVED_WITH_CONDITIONS | NEEDS_RESOLUTION | BLOCKED]

### Vote Summary
| Agent  | Vote | Confidence |
| ------ | ---- | ---------- |
| Claude |      |            |
| Codex  |      |            |
| Gemini |      |            |

### Agreed Points
1. [Point]
2. [Point]

### Disagreements
| Topic | Claude | Codex | Gemini |
| ----- | ------ | ----- | ------ |
|       |        |       |        |

### Required Actions
1. [Action]
2. [Action]

### Optional Improvements
- [Improvement]
```

## Error Handling and Retry Logic
- Retry up to 3 times with exponential backoff (2^n seconds).
- Exit codes: 1 (syntax), 2 (auth), 124 (timeout), 429 (rate limit).
- Split large prompts when timeouts occur.
- Failover chain (degraded mode):
  - Claude: Opus -> Sonnet -> Gemini Pro
  - Codex: GPT-5.2 -> o3 -> Claude Sonnet
  - Gemini: 3 Pro -> 2.5 Pro -> Claude Sonnet

## Capability Standards Integration
- Follow CLAUDE.md maximum capability standards and no-downgrade rule.
- Codex must use `gpt-5.2-codex` with `model_reasoning_effort="xhigh"`.
- Gemini must use `gemini-3-pro-preview`. YOLO is allowed for read-only analysis only.
- For modifications or git operations, do not use YOLO.
- Use `workspace-write` by default; use `danger-full-access` only after the required checklist.

## Example Usage
```
/consensus review auth flow in src/auth
/consensus architecture decision: monolith vs services
/consensus security review for token storage
```
