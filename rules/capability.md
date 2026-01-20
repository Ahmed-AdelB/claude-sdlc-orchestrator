<!-- Part of modular rules system - see ~/.claude/CLAUDE.md for full context -->
<!-- This file contains maximum capability standards for all AI models -->

# Maximum Capability Standards (MANDATORY)

**NEVER use weaker models or configurations to save tokens. Maximum capability is required at all times.**

---

## 1. Gemini Maximum Capability

```bash
# READ-ONLY (analysis, review, docs) - YOLO allowed:
gemini -m gemini-3-pro-preview --approval-mode yolo "Analyze: ..."

# MODIFICATIONS (code changes, git) - Manual approval:
gemini -m gemini-3-pro-preview "Implement: ..."
```

| Capability   | Requirement                                        |
| ------------ | -------------------------------------------------- |
| Model        | `gemini-3-pro-preview` (always specify)            |
| Context      | 1M tokens - full codebase analysis                 |
| Routing      | Pro routing - always most capable model            |
| No Downgrade | Never use `gemini-1.5-flash` or shorthand `-m pro` |

---

## 2. Codex Maximum Capability

```bash
# DEFAULT (workspace-write):
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "task"

# ESCALATED (danger-full-access) - See security.md for checklist:
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s danger-full-access "task"
```

| Capability   | Requirement                                    |
| ------------ | ---------------------------------------------- |
| Model        | `gpt-5.2-codex` (always specify)               |
| Reasoning    | `xhigh` - maximum reasoning depth              |
| Context      | 400K tokens - large codebase understanding     |
| No Downgrade | Never use `gpt-4o` or lower reasoning settings |

---

## 3. Claude Maximum Capability

| Task Type             | Configuration                              |
| --------------------- | ------------------------------------------ |
| Architecture/Security | `ultrathink` (32K thinking tokens)         |
| Implementation        | Standard `thinking` (4K-10K tokens)        |
| Deep Analysis         | Opus model via Task tool with model="opus" |

**No Downgrade Rule:** Do not turn off thinking mode for code generation.

---

## Enforcement Checklist

Before any AI invocation, verify:

- [ ] **Gemini:** `-m gemini-3-pro-preview` is specified
- [ ] **Codex:** `xhigh` reasoning is active
- [ ] **Claude:** Thinking mode is enabled
- [ ] **Context:** Full relevant context was loaded
- [ ] **Downgrade Check:** No lower-tier models selected

---

## Model Summary Table

| Model         | Full Identifier      | Context | Key Setting            |
| ------------- | -------------------- | ------- | ---------------------- |
| Gemini        | gemini-3-pro-preview | 1M      | Pro routing            |
| Codex         | gpt-5.2-codex        | 400K    | reasoning_effort=xhigh |
| Claude Opus   | claude-opus-4        | 200K    | ultrathink (32K)       |
| Claude Sonnet | claude-sonnet-4      | 200K    | thinking (4K-10K)      |

---

## Common Violations (AVOID)

| Violation                   | Correct Usage                             |
| --------------------------- | ----------------------------------------- |
| `gemini "prompt"`           | `gemini -m gemini-3-pro-preview "prompt"` |
| `-m pro`                    | `-m gemini-3-pro-preview`                 |
| `reasoning_effort="medium"` | `reasoning_effort="xhigh"`                |
| `-m gpt-4o`                 | `-m gpt-5.2-codex`                        |
| Thinking mode disabled      | Keep thinking enabled for code generation |
