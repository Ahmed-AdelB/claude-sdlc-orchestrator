---
name: "/agentic:trace"
trigger: "/agentic:trace [--since <time>] [--until <time>] [--agent <id>] [--task <id|pattern>] [--format markdown|text|json] [--export-prom <path>] [--verbose]"
description: "Enable end-to-end tracing of agent operations; show LLM calls, tool calls, decisions, and costs; generate readable reports; filter by time range, agent, or task; export Prometheus metrics."
parameters:
  - name: --since
    type: string
    required: false
    description: "Start time (ISO-8601 or relative like 30m)."
  - name: --until
    type: string
    required: false
    description: "End time (ISO-8601 or relative like now)."
  - name: --agent
    type: string
    required: false
    description: "Agent id or name filter."
  - name: --task
    type: string
    required: false
    description: "Task id, label, or keyword filter."
  - name: --format
    type: string
    required: false
    description: "Report format: markdown, text, or json."
  - name: --export-prom
    type: string
    required: false
    description: "Prometheus exposition output path."
  - name: --verbose
    type: boolean
    required: false
    description: "Include full prompts and tool payloads."
---

# Agentic Trace

Enable end-to-end tracing for agent operations and generate filtered reports.

## Usage

```
/agentic:trace --since 1h --agent planner --format markdown
/agentic:trace --task "checkout" --export-prom /tmp/agentic_trace.prom
/agentic:trace --since 2025-01-20T00:00:00Z --until 2025-01-20T23:59:59Z
```

## Tracing Logic Template

### Trace Context

Define a shared context and propagate it through every LLM and tool call.

```json
{
  "trace_id": "uuid",
  "session_id": "session-uuid",
  "agent_id": "agent-name",
  "task_id": "task-id",
  "started_at": "RFC3339"
}
```

### Trace Event Schema

Emit JSON Lines events in timestamp order.

```json
{
  "timestamp": "RFC3339",
  "trace_id": "uuid",
  "span_id": "uuid",
  "parent_span_id": "uuid|null",
  "agent_id": "agent-name",
  "task_id": "task-id",
  "event_type": "llm.call|tool.call|decision|error|span",
  "status": "ok|error",
  "duration_ms": 1234,
  "data": {}
}
```

### LLM Call Event Data

Capture model details, tokens, and cost per call.

```json
{
  "model": "gpt-5",
  "temperature": 0.2,
  "prompt_tokens": 1234,
  "completion_tokens": 456,
  "cost_usd": 0.0187,
  "input_preview": "redacted",
  "output_preview": "redacted"
}
```

### Tool Call Event Data

Capture tool usage with redaction by default.

```json
{
  "tool_name": "shell_command",
  "args_preview": "rg -n \"foo\" src/",
  "result_preview": "stdout summary",
  "error": "string|null"
}
```

### Decision Event Data

Record agent decisions and rationale.

```json
{
  "decision_id": "decision-uuid",
  "options": ["option-a", "option-b"],
  "selected": "option-a",
  "rationale": "short explanation",
  "confidence": 0.72
}
```

### Instrumentation Steps

1. Initialize `TraceContext` at task start and attach `trace_id` to all sub-operations.
2. Wrap every LLM call to emit `llm.call` start/end events with latency, tokens, and cost.
3. Wrap every tool call to emit `tool.call` start/end events with status and previews.
4. Emit `decision` events at branch points or when choosing between options.
5. Aggregate totals across events and emit a final `span` event with summary stats.
6. Redact secrets by default and include full payloads only when `--verbose` is set.

### Filtering Logic

Apply filters before reporting or export.

```
include_event =
  event.timestamp in [since, until]
  and (agent == null or event.agent_id matches agent)
  and (task == null or event.task_id matches task or task in event.data)
```

## Report Generation Template

Render a human-readable report by grouping events and computing totals.

```text
1. Load events for the trace or time range
2. Apply filters
3. Compute totals (calls, tokens, cost, latency)
4. Group by event_type and tool/model
5. Render report in requested format
```

## Output Format Examples

### Markdown Report

```markdown
# Agentic Trace Report
Trace ID: 6f0b2c7a-5b6f-4e2a-9c61-1c8a97f4a9e1
Time Range: 2025-01-20T10:00:00Z to 2025-01-20T10:12:14Z
Filters: agent=planner, task=checkout

## Summary
| Metric | Value |
| --- | --- |
| LLM Calls | 6 |
| Tool Calls | 9 |
| Decisions | 3 |
| Total Tokens | 12,340 |
| Total Cost | $0.42 |

## LLM Calls
| Model | Calls | Tokens | Cost |
| --- | --- | --- | --- |
| gpt-5 | 6 | 12,340 | $0.42 |

## Tool Calls
- shell_command: 4
- read_file: 3
- apply_patch: 2

## Decisions
- Choose data source: cache over live fetch (confidence 0.72)
- Skip test run: no test target found (confidence 0.61)
- Use apply_patch: single-file edit (confidence 0.83)
```

### Text Report

```text
Agentic Trace Report
Trace: 6f0b2c7a-5b6f-4e2a-9c61-1c8a97f4a9e1
Range: 2025-01-20T10:00:00Z..2025-01-20T10:12:14Z
Filters: agent=planner task=checkout

LLM calls: 6  Tool calls: 9  Decisions: 3
Tokens: 12,340  Cost: $0.42

Top tools: shell_command(4), read_file(3), apply_patch(2)
```

### Prometheus Export

```text
# HELP agent_trace_llm_calls_total Total LLM calls in trace window
# TYPE agent_trace_llm_calls_total counter
agent_trace_llm_calls_total{agent="planner",model="gpt-5"} 6
# HELP agent_trace_tool_calls_total Total tool calls in trace window
# TYPE agent_trace_tool_calls_total counter
agent_trace_tool_calls_total{agent="planner",tool="shell_command"} 4
# HELP agent_trace_cost_usd_total Total estimated cost in USD
# TYPE agent_trace_cost_usd_total counter
agent_trace_cost_usd_total{agent="planner"} 0.42
# HELP agent_trace_tokens_total Total tokens in trace window
# TYPE agent_trace_tokens_total counter
agent_trace_tokens_total{agent="planner",direction="in"} 9500
agent_trace_tokens_total{agent="planner",direction="out"} 2840
# HELP agent_trace_latency_seconds LLM call latency seconds
# TYPE agent_trace_latency_seconds histogram
agent_trace_latency_seconds_bucket{agent="planner",model="gpt-5",le="0.25"} 1
agent_trace_latency_seconds_bucket{agent="planner",model="gpt-5",le="0.5"} 3
agent_trace_latency_seconds_bucket{agent="planner",model="gpt-5",le="1"} 6
agent_trace_latency_seconds_sum{agent="planner",model="gpt-5"} 2.38
agent_trace_latency_seconds_count{agent="planner",model="gpt-5"} 6
```

## Integration Instructions

1. Wrap the LLM client to emit start/end events with tokens, model, latency, and cost.
2. Wrap the tool runner to emit start/end events with duration, status, and redacted previews.
3. Emit `decision` events at branching points and capture options, selected choice, and rationale.
4. Store events as JSON Lines under `~/.claude/traces/<trace_id>.jsonl` or another configured sink.
5. Build a report generator that loads events, applies filters, computes totals, and renders the requested format.
6. Export Prometheus metrics by aggregating filtered events and writing the exposition format to `--export-prom`.
7. Redact secrets and PII by default; allow full payloads only when explicitly requested.
