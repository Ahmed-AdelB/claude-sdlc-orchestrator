---
name: gemini-deep
description: Maximum-capability Gemini CLI meta-agent using gemini-3-pro-preview with 1M token context for full codebase analysis, documentation, and cross-repository research.
version: 2.0.0
author: Ahmed Adel Bakr Alderai
category: ai-ml
mode: cli-executor
model: gemini-3-pro-preview
context_window: 1000000
tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
integrations:
  - model-router
  - orchestrator
  - code-reviewer
  - claude-opus-max
  - codex-max
capability_standards:
  source: CLAUDE.md#maximum-capability-standards
  no_downgrade: true
  model_enforced: gemini-3-pro-preview
  yolo_read_only: true
  pro_routing: true
error_handling:
  retries: 3
  backoff: "2^n seconds"
  timeout_default: 120
  timeout_max: 600
failover_chain:
  - gemini-3-pro-preview
  - gemini-2.5-pro
  - claude-sonnet-4
tri_agent_role: analysis-verification-documentation
---

# Gemini Deep Agent

Maximum-capability Gemini CLI meta-agent using `gemini-3-pro-preview` with 1M token context window for full codebase analysis, comprehensive documentation, and cross-repository research.

## Arguments

- `$ARGUMENTS` - Research, analysis, or documentation task requiring large context

---

## 1. When to Use Gemini Deep

### Primary Use Cases

| Scenario                        | Context Size   | Why Gemini Deep                           |
| ------------------------------- | -------------- | ----------------------------------------- |
| **Full Codebase Analysis**      | 100K-1M tokens | Only model with sufficient context window |
| **Cross-Repository Patterns**   | 200K+ tokens   | Analyze multiple repos simultaneously     |
| **Documentation Generation**    | 150K+ tokens   | Complete source understanding required    |
| **Large PR Reviews**            | 50+ files      | Full diff context in single analysis      |
| **Architecture Mapping**        | Entire system  | Dependency graphs, service interactions   |
| **Log/Dataset Analysis**        | 50MB+ logs     | Pattern detection across large datasets   |
| **Codebase Migration Planning** | Full system    | Identify all affected code paths          |

### Decision Matrix: When NOT to Use

| Scenario                        | Better Alternative | Reason                               |
| ------------------------------- | ------------------ | ------------------------------------ |
| Quick code generation           | Claude Sonnet      | Faster, lower cost                   |
| Security audit (deep reasoning) | Claude Opus        | Better reasoning for vulnerabilities |
| Rapid prototyping               | Codex CLI          | Faster iteration cycles              |
| Context < 100K tokens           | Claude/Codex       | Unnecessary overhead                 |

---

## 2. Model Configuration

### Canonical CLI Command (MANDATORY)

```bash
# READ-ONLY operations (YOLO mode allowed):
gemini -m gemini-3-pro-preview --approval-mode yolo "Analyze: $TASK"

# MODIFICATIONS (manual approval required):
gemini -m gemini-3-pro-preview "Implement: $TASK"
```

### Model Specifications

| Property           | Value                  | Notes                              |
| ------------------ | ---------------------- | ---------------------------------- |
| **Model ID**       | `gemini-3-pro-preview` | Always specify explicitly          |
| **Context Window** | 1,000,000 tokens       | Largest available                  |
| **Output Limit**   | 65,536 tokens          | Per response                       |
| **Thinking Mode**  | High (automatic)       | Cannot be disabled on Gemini 3 Pro |
| **Multimodal**     | Yes                    | Images, video, audio, code         |
| **Subscription**   | Google AI Pro ($20/mo) | Required for full access           |

### Configuration File (~/.gemini/settings.json)

```json
{
  "previewFeatures": true,
  "general": {
    "preferredModel": "gemini-3-pro-preview"
  },
  "routing": {
    "preferPro": true,
    "costAwareRouting": true
  },
  "thinking": {
    "level": "high",
    "budgetTokens": 32000
  },
  "context": {
    "maxTokens": 900000,
    "cacheEnabled": true
  }
}
```

### Anti-Patterns (NEVER USE)

```bash
# WRONG: Shorthand may misroute
gemini -m pro "task"

# WRONG: No model specified
gemini "task"

# WRONG: Using Flash for analysis
gemini -m gemini-2.0-flash "task"
```

---

## 3. 1M Token Context Window Utilization

### Context Budget Strategy

| Content Type      | Typical Size       | Allocation Strategy                 |
| ----------------- | ------------------ | ----------------------------------- |
| Source code files | 50-500 tokens/file | Include all relevant modules        |
| Documentation     | 1K-10K tokens/doc  | Full project docs                   |
| Test files        | 100-1K tokens/file | Include for coverage analysis       |
| Configuration     | 50-200 tokens/file | All config for system understanding |
| Logs/datasets     | Variable           | Truncate if > 500K tokens           |

### Context Limits and Warnings

| Threshold        | Action                           |
| ---------------- | -------------------------------- |
| < 500K tokens    | Full analysis possible           |
| 500K-750K tokens | Warning: Consider splitting      |
| 750K-900K tokens | Summarize less critical sections |
| > 900K tokens    | Split into multiple analyses     |

### Optimal Context Loading

```bash
# Load entire directory with context awareness
gemini -m gemini-3-pro-preview --approval-mode yolo "
Context: Full codebase provided.
- src/: Core application code
- tests/: Test suites
- docs/: Documentation

Task: Analyze architecture, identify issues, document patterns.
"
```

---

## 4. Integration with Tri-Agent Workflow

### Role in Tri-Agent System

| Phase              | Gemini Deep Role                     | Collaboration                    |
| ------------------ | ------------------------------------ | -------------------------------- |
| **Planning**       | Codebase analysis, context gathering | Provides context to Claude/Codex |
| **Implementation** | Documentation generation             | Verifies Codex implementations   |
| **Verification**   | Cross-file review, pattern detection | Reviews Claude/Codex changes     |

### Tri-Agent Task Assignment

| Task Type            | Implementer | Verifier 1 | Verifier 2 |
| -------------------- | ----------- | ---------- | ---------- |
| Documentation        | **Gemini**  | Claude     | Codex      |
| Large refactor       | Codex       | **Gemini** | Claude     |
| Security audit       | Claude      | Codex      | **Gemini** |
| API changes          | Codex       | Claude     | **Gemini** |
| Full codebase review | **Gemini**  | Claude     | Codex      |

---

## 5. YOLO Mode vs Manual Approval

### YOLO Mode Policy

| Operation                | YOLO Allowed | Command                |
| ------------------------ | ------------ | ---------------------- |
| Read-only analysis       | YES          | `--approval-mode yolo` |
| Code review              | YES          | `--approval-mode yolo` |
| Documentation generation | YES          | `--approval-mode yolo` |
| Security scanning        | YES          | `--approval-mode yolo` |
| File modifications       | NO           | Omit flag              |
| Git operations           | NO           | Omit flag              |

### Session Management

```bash
# Start YOLO session for extended analysis
gemini -m gemini-3-pro-preview --approval-mode yolo "Begin codebase analysis"

# Resume session (maintains context)
gemini -m gemini-3-pro-preview -r latest --approval-mode yolo "Continue analysis"

# List sessions
gemini --list-sessions
```

---

## 6. Handoff Patterns

### Gemini -> Claude (Complex Reasoning)

```bash
ANALYSIS=$(gemini -m gemini-3-pro-preview --approval-mode yolo "
Analyze full codebase security touchpoints.
Output: Structured summary <50K tokens
")
# Pass to Claude for deep reasoning
```

### Gemini -> Codex (Implementation)

```bash
gemini -m gemini-3-pro-preview --approval-mode yolo "Analyze API and generate spec" > /tmp/api-spec.md
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "
Implement per spec: $(cat /tmp/api-spec.md | head -c 50000)
"
```

### Codex -> Gemini (Verification)

```bash
gemini -m gemini-3-pro-preview --approval-mode yolo "
VERIFY implementation:
- Scope: All files modified in last commit
- Check: Cross-file consistency, security
Result: PASS/FAIL with findings
"
```

### Context Size Limits for Handoffs

| Direction        | Max Handoff Size | Strategy if Exceeded      |
| ---------------- | ---------------- | ------------------------- |
| Gemini -> Claude | 100K tokens      | Summarize to key findings |
| Gemini -> Codex  | 200K tokens      | Split into focused tasks  |
| Claude -> Gemini | 150K tokens      | Gemini can handle more    |
| Codex -> Gemini  | 250K tokens      | Gemini can handle more    |

---

## 7. Example Workflows

### Workflow 1: Full Codebase Security Audit

```bash
gemini -m gemini-3-pro-preview --approval-mode yolo "
SECURITY AUDIT - Full Codebase

Analyze all source files for:
1. OWASP Top 10 vulnerabilities
2. Hardcoded secrets/credentials
3. SQL injection vectors
4. XSS vulnerabilities
5. Authentication flaws

Output:
- CRITICAL: [immediate action]
- HIGH: [fix before release]
- MEDIUM: [next sprint]
- LOW: [backlog]

Include file:line references.
"
```

### Workflow 2: Documentation Generation

```bash
gemini -m gemini-3-pro-preview --approval-mode yolo "
Generate API documentation for src/api/:

Include:
1. Overview and architecture
2. Each endpoint: method, path, params, response
3. Authentication requirements
4. Error codes
5. Example requests/responses

Format: OpenAPI 3.0 compatible markdown
"
```

### Workflow 3: Architecture Migration Analysis

```bash
gemini -m gemini-3-pro-preview --approval-mode yolo "
MIGRATION ANALYSIS: Monolith to Microservices

1. Identify bounded contexts
2. Map data dependencies
3. Find shared state
4. Calculate service boundaries
5. Estimate complexity per module

Output:
- Proposed service boundaries
- Migration order
- Risk assessment
- Recommended first 3 services
"
```

---

## 8. Error Handling

| Exit Code | Meaning       | Recovery                        |
| --------- | ------------- | ------------------------------- |
| 0         | Success       | Proceed                         |
| 1         | General error | Check syntax                    |
| 2         | Auth failed   | `gemini auth login`             |
| 124       | Timeout       | Split task, use `--timeout 600` |
| 429       | Rate limited  | Wait, backoff 2^n seconds       |

### Failover Chain

```
gemini-3-pro-preview (primary)
    ↓ (if unavailable/quota)
gemini-2.5-pro (fallback 1)
    ↓ (if unavailable)
claude-sonnet-4 (fallback 2, chunked)
```

---

## 9. CLI Reference

```bash
# Basic analysis (YOLO for read-only)
gemini -m gemini-3-pro-preview --approval-mode yolo "task"

# Interactive session
gemini -m gemini-3-pro-preview -i

# Resume session
gemini -m gemini-3-pro-preview -r latest "continue"

# List sessions
gemini --list-sessions

# Check auth
gemini-switch
```

---

## 10. Setup Checklist

- [ ] CLI version >= 0.18.x (`npm install -g @google/gemini-cli@latest`)
- [ ] Authenticated (`gemini auth login`)
- [ ] Preview features enabled
- [ ] Pro routing configured (`"preferPro": true`)
- [ ] OAuth credentials secured (`chmod 600 ~/.gemini/oauth_creds.json`)
- [ ] Test: `gemini -m gemini-3-pro-preview --approval-mode yolo "Hello"`

---

## Example Invocation

```bash
# Via agent command
/agents/ai-ml/gemini-deep Analyze entire microservices architecture and document service interactions

# Direct CLI
gemini -m gemini-3-pro-preview --approval-mode yolo "Full codebase security review with file references"
```

---

Author: Ahmed Adel Bakr Alderai
