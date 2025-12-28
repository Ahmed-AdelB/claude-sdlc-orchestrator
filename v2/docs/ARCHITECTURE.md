# Tri-Agent System Architecture

## Overview

The tri-agent system orchestrates three AI models (Claude, Gemini, Codex) for intelligent task routing, consensus decision-making, and fault-tolerant operation.

```
                           ┌─────────────────────────────────────┐
                           │         USER / AUTOMATION          │
                           └──────────────┬──────────────────────┘
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              TRI-AGENT ROUTER                                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │  Keyword    │  │  Context    │  │  File Size  │  │  Confidence Score   │ │
│  │  Analysis   │  │  Analysis   │  │  Analysis   │  │  Calculation        │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────────────┘ │
└────────────────────────────────┬────────────────────────────────────────────┘
                                 │
            ┌────────────────────┼────────────────────┐
            │                    │                    │
            ▼                    ▼                    ▼
   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
   │    CLAUDE       │  │    GEMINI       │  │    CODEX        │
   │   (Opus 4.5)    │  │   (3 Pro)       │  │   (GPT-5.2)     │
   ├─────────────────┤  ├─────────────────┤  ├─────────────────┤
   │ • Orchestrator  │  │ • Large Context │  │ • Implementer   │
   │ • Architecture  │  │ • 1M tokens     │  │ • xhigh reason  │
   │ • Security      │  │ • Multimodal    │  │ • Rapid coding  │
   │ • Deep Reason   │  │ • Analysis      │  │ • Prototyping   │
   └────────┬────────┘  └────────┬────────┘  └────────┬────────┘
            │                    │                    │
            └────────────────────┴────────────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │    CONSENSUS ENGINE     │
                    │  ┌───────────────────┐  │
                    │  │ Voting: majority  │  │
                    │  │ Min approvals: 2  │  │
                    │  │ Weighted scoring  │  │
                    │  └───────────────────┘  │
                    └────────────┬────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │    JSON RESPONSE        │
                    │  {decision, confidence, │
                    │   reasoning, output}    │
                    └─────────────────────────┘
```

## Components

### 1. Router Layer (`bin/tri-agent-router`)

The router analyzes incoming tasks and determines the optimal model based on:

```
                    ┌─────────────────────────┐
                    │      INPUT PROMPT       │
                    └───────────┬─────────────┘
                                │
                    ┌───────────▼─────────────┐
                    │   SIGNAL EXTRACTION     │
                    │  • Keywords             │
                    │  • File size            │
                    │  • Token estimate       │
                    │  • File extensions      │
                    └───────────┬─────────────┘
                                │
                    ┌───────────▼─────────────┐
                    │   RULE MATCHING         │
                    │  (routing-policy.yaml)  │
                    └───────────┬─────────────┘
                                │
              ┌─────────────────┼─────────────────┐
              │                 │                 │
              ▼                 ▼                 ▼
       ┌────────────┐   ┌────────────┐   ┌────────────┐
       │  Claude    │   │  Gemini    │   │  Codex     │
       │  conf:0.85 │   │  conf:0.90 │   │  conf:0.80 │
       └────────────┘   └────────────┘   └────────────┘
                                │
                    ┌───────────▼─────────────┐
                    │   CONFIDENCE MODIFIERS  │
                    │  • Explicit mentions    │
                    │  • Multi-signal boost   │
                    │  • Short prompt penalty │
                    └───────────┬─────────────┘
                                │
                    ┌───────────▼─────────────┐
                    │   THRESHOLD CHECK       │
                    │  conf >= 0.7 → route    │
                    │  conf <  0.7 → prompt   │
                    └─────────────────────────┘
```

**Routing Rules Priority:**
1. Forced routing (`--claude`, `--gemini`, `--codex`)
2. File size > 50KB → Gemini
3. Token estimate > 100K → Gemini
4. Keyword matching (see routing-policy.yaml)
5. Default → Claude (orchestrator)

### 2. Delegate Layer (`bin/*-delegate`)

Each delegate wraps a model's CLI and produces a standardized JSON envelope:

```
┌───────────────────────────────────────────────────────────────┐
│                     DELEGATE PATTERN                          │
│                                                               │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐       │
│  │   Input     │───▶│   Execute   │───▶│   Parse     │       │
│  │ Validation  │    │    CLI      │    │   Output    │       │
│  └─────────────┘    └─────────────┘    └─────────────┘       │
│         │                 │                   │               │
│         ▼                 ▼                   ▼               │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐       │
│  │ Size limits │    │  Timeout    │    │  Decision   │       │
│  │ Secret mask │    │  handling   │    │  Confidence │       │
│  └─────────────┘    └─────────────┘    │  Reasoning  │       │
│                                        └─────────────┘       │
│                                               │               │
│                           ┌───────────────────▼─────────────┐ │
│                           │        JSON ENVELOPE            │ │
│                           │ {model, status, decision,       │ │
│                           │  confidence, reasoning,         │ │
│                           │  output, trace_id, duration_ms} │ │
│                           └─────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────┘
```

### 3. Consensus Engine (`bin/tri-agent-consensus`)

When critical decisions require multi-model agreement:

```
                    ┌─────────────────────────┐
                    │     CONSENSUS REQUEST   │
                    └───────────┬─────────────┘
                                │
              ┌─────────────────┼─────────────────┐
              │                 │                 │
              ▼                 ▼                 ▼
       ┌────────────┐   ┌────────────┐   ┌────────────┐
       │   Claude   │   │   Gemini   │   │   Codex    │
       │  APPROVE   │   │  APPROVE   │   │  REJECT    │
       │  conf:0.9  │   │  conf:0.8  │   │  conf:0.6  │
       └────────────┘   └────────────┘   └────────────┘
              │                 │                 │
              └─────────────────┴─────────────────┘
                                │
                    ┌───────────▼─────────────┐
                    │     VOTING ENGINE       │
                    │                         │
                    │  Mode: majority         │
                    │  Approvals: 2/3         │
                    │  Threshold: met         │
                    │                         │
                    │  Weighted Score:        │
                    │  0.4×0.9 + 0.3×0.8      │
                    │  + 0.3×(-0.6) = 0.42    │
                    └───────────┬─────────────┘
                                │
                    ┌───────────▼─────────────┐
                    │     FINAL DECISION      │
                    │                         │
                    │  Decision: APPROVE      │
                    │  Combined conf: 0.76    │
                    │  Dissent: Codex         │
                    └─────────────────────────┘
```

**Voting Modes:**
- `majority`: 2+ agreeing models wins
- `weighted`: Score = Σ(weight × confidence × decision_sign)
- `veto`: Designated model can block decision

### 4. Error Handling & Resilience

#### Circuit Breaker Pattern

```
                    ┌─────────────────────────┐
                    │        CLOSED           │◀─────────────┐
                    │    (normal state)       │              │
                    └───────────┬─────────────┘              │
                                │                            │
                           failure                      success
                                │                            │
                    ┌───────────▼─────────────┐              │
                    │    Failure Counter      │              │
                    │    count++              │              │
                    └───────────┬─────────────┘              │
                                │                            │
                       count >= threshold                    │
                                │                            │
                    ┌───────────▼─────────────┐              │
                    │         OPEN            │              │
                    │   (reject requests)     │              │
                    └───────────┬─────────────┘              │
                                │                            │
                         cooldown elapsed                    │
                                │                            │
                    ┌───────────▼─────────────┐              │
                    │       HALF_OPEN         │──────────────┘
                    │   (test one request)    │
                    └─────────────────────────┘
```

#### Retry with Exponential Backoff

```
attempt 1: wait 0s
    │
    └── failure → attempt 2: wait 5s
                      │
                      └── failure → attempt 3: wait 10s
                                        │
                                        └── failure → attempt 4: wait 20s
                                                          │
                                                          └── max reached → fallback
```

#### Fallback Chain

```
┌─────────┐     fail     ┌─────────┐     fail     ┌─────────┐
│ Claude  │─────────────▶│  Codex  │─────────────▶│ Gemini  │
└─────────┘              └─────────┘              └─────────┘
     │                        │                        │
  success                  success                  success
     │                        │                        │
     └────────────────────────┴────────────────────────┘
                              │
                         ┌────▼────┐
                         │ Response│
                         └─────────┘
```

### 5. State Management

```
$STATE_DIR/
├── breakers/
│   ├── claude.state      # Circuit breaker state
│   ├── gemini.state
│   └── codex.state
├── costs/
│   └── totals.json       # Usage statistics
├── locks/
│   └── *.lock           # Distributed locks
├── health.json          # Health check results
└── preflight.json       # Preflight validation results
```

### 6. Logging Architecture

```
$LOG_DIR/
├── sessions/
│   └── YYYY-MM-DD.jsonl  # Daily session logs
├── errors/
│   └── YYYY-MM-DD.jsonl  # Error logs
├── costs/
│   └── YYYY-MM-DD.jsonl  # Cost/usage logs
├── audit/
│   └── YYYY-MM-DD.jsonl  # Audit trail (optional)
└── routing-decisions.jsonl # Routing decision history
```

**Log Entry Format:**
```json
{
  "timestamp": "2025-12-28T14:30:52+00:00",
  "level": "INFO",
  "component": "ROUTER",
  "event": "ROUTE_DECISION",
  "trace_id": "tri-20251228143052-abc123",
  "message": "Routed to gemini",
  "metadata": {
    "model": "gemini",
    "confidence": 0.92,
    "reason": "Large file analysis",
    "prompt_length": 150000
  }
}
```

## Data Flow

### Single Model Request

```
User Request
     │
     ▼
┌────────────┐
│  Router    │───▶ Analyze task
└────────────┘
     │
     ▼
┌────────────┐
│  Check CB  │───▶ Circuit open? → Fallback
└────────────┘
     │
     ▼
┌────────────┐
│  Delegate  │───▶ Execute CLI with timeout
└────────────┘
     │
     ▼
┌────────────┐     success
│  Response  │◀─────────────┐
└────────────┘              │
     │                      │
 error?                     │
     │                      │
     ▼                      │
┌────────────┐              │
│  Retry?    │───yes───▶ Backoff → Retry
└────────────┘
     │
     no
     │
     ▼
┌────────────┐
│  Fallback  │
└────────────┘
```

### Consensus Request

```
User Request (--consensus)
     │
     ▼
┌─────────────────────────────────────────────┐
│              PARALLEL EXECUTION              │
│  ┌──────┐    ┌──────┐    ┌──────┐          │
│  │Claude│    │Gemini│    │Codex │          │
│  └──┬───┘    └──┬───┘    └──┬───┘          │
│     │           │           │               │
│     ▼           ▼           ▼               │
│  ┌──────┐    ┌──────┐    ┌──────┐          │
│  │ JSON │    │ JSON │    │ JSON │          │
│  └──────┘    └──────┘    └──────┘          │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
          ┌───────────────┐
          │ Voting Engine │
          └───────┬───────┘
                  │
                  ▼
          ┌───────────────┐
          │ Final Decision│
          └───────────────┘
```

## Configuration

### tri-agent.yaml Structure

```yaml
system:
  version: "2.0.0"
  default_mode: "tri-agent"

models:
  claude:
    role: "orchestrator"
    model: "opus"
    timeout_seconds: 300

  gemini:
    role: "analyst"
    model: "gemini-3-pro-preview"
    context_window: 1000000

  codex:
    role: "implementer"
    model: "gpt-5.2-codex"
    reasoning_effort: "xhigh"

routing:
  auto_detect: true
  file_size_threshold: 51200
  context_threshold: 100000
  confidence_threshold: 0.7

error_handling:
  max_retries: 3
  backoff_base: 5
  backoff_max: 300
  fallback_order: [claude, codex, gemini]

circuit_breaker:
  failure_threshold: 3
  cooldown_seconds: 60

consensus:
  voting_mode: "majority"
  min_approvals: 2
  weights:
    claude: 0.4
    gemini: 0.3
    codex: 0.3
```

## Security Considerations

1. **Secret Masking**: All logs mask API keys and tokens
2. **Temp File Security**: Uses `mktemp` with `chmod 600`
3. **Input Validation**: Numeric and format validation
4. **Size Limits**: Stdin capped at 500KB per delegate
5. **No Eval**: Uses `jq --arg` instead of string interpolation
6. **Lock Files**: Prevent race conditions in concurrent access

## Performance Optimizations

1. **Parallel Execution**: Consensus queries run simultaneously
2. **Config Caching**: YAML parsed once and cached
3. **Lazy Loading**: Lib files sourced only when needed
4. **Lock Timeouts**: Prevent indefinite blocking
5. **Jitter**: Random delay prevents thundering herd

## Extension Points

1. **New Models**: Add `*-delegate` script following pattern
2. **New Routing Rules**: Extend `routing-policy.yaml`
3. **Custom Voting**: Implement in consensus engine
4. **Metrics Export**: Add Prometheus endpoint (see bin/tri-agent-metrics)
5. **Webhooks**: Add notification on failures
