# /llmops:evaluate

Run LLM evaluation suites: define metrics, run benchmark prompts, compare against baseline, generate report, and track metrics over time.

## Usage
```
/llmops:evaluate [suite] [--model <id>] [--baseline <id>] [--metrics <list>] [--benchmarks <path>] [--report <path>] [--track <path>] [--format <md|json>] [--limit <n>] [--seed <n>] [--notes <text>] [--agent <name>] [--dry-run]
```

## Arguments
- `suite` (optional): Evaluation suite name (e.g., `qa-core-v1`). Default: infer from benchmark file name.

## Options
- `--model <id>`: Target model identifier.
- `--baseline <id>`: Baseline model or run id to compare against.
- `--metrics <list>`: Comma-separated list. Default: `accuracy,relevance,coherence`.
- `--benchmarks <path>`: Path to benchmark suite file (YAML or JSONL).
- `--report <path>`: Output report path. Default: `reports/llmops/<suite>-<timestamp>.md`.
- `--track <path>`: Metrics history file (JSONL or CSV). Default: `metrics/llmops/<suite>.jsonl`.
- `--format <md|json>`: Report format. Default: `md`.
- `--limit <n>`: Limit number of benchmark cases.
- `--seed <n>`: Random seed for sampling.
- `--notes <text>`: Notes to include in the report.
- `--agent <name>`: Evaluation runner. Default: `llmops-agent`.
- `--dry-run`: Show resolved inputs and plan without executing.

## Workflow
1. Define evaluation metrics: accuracy, relevance, coherence. Set scale and weights.
2. Run benchmark prompts using the target model and capture outputs.
3. Compare against baseline: compute deltas and significance where applicable.
4. Generate evaluation report with per-metric scores and highlights.
5. Track metrics over time by appending run results to history.

## Metrics Definitions
Use a consistent 1-5 rubric and normalize to 0-1 for reporting.

- **Accuracy**: 1 = incorrect or contradicts reference, 3 = partially correct, 5 = fully correct and precise.
- **Relevance**: 1 = off-topic, 3 = partially on-topic, 5 = directly addresses the prompt without fluff.
- **Coherence**: 1 = disjointed or contradictory, 3 = mostly coherent, 5 = logically consistent and well-structured.

Optional weights:
```
accuracy: 0.5
relevance: 0.3
coherence: 0.2
```

## Benchmark Templates

### YAML Suite
```yaml
suite: qa-core-v1
description: Core short-answer QA
metrics: [accuracy, relevance, coherence]
cases:
  - id: qa-001
    input: "What is the capital of France?"
    expected: "Paris"
    reference: "Paris"
    tags: [geography, short]
    rubric:
      accuracy: "Answer must be Paris."
      relevance: "Answer must address the question directly."
      coherence: "Single sentence, no contradictions."

  - id: qa-002
    input: "Summarize the main idea of the paragraph."
    context: "The paragraph text goes here."
    expected: "One-sentence summary."
    reference: "Authoritative summary."
    tags: [summarization]
```

### JSONL Suite
```json
{"id":"qa-001","input":"What is the capital of France?","expected":"Paris","reference":"Paris","tags":["geography","short"]}
{"id":"qa-002","input":"Summarize the main idea of the paragraph.","context":"The paragraph text goes here.","expected":"One-sentence summary.","reference":"Authoritative summary.","tags":["summarization"]}
```

### Judge Prompt Template
```text
You are evaluating a model response.

Prompt:
{{input}}
{{#if context}}Context: {{context}}{{/if}}

Expected:
{{expected}}
Reference:
{{reference}}

Model Response:
{{response}}

Score each metric from 1-5 with brief justification.
Return JSON:
{"accuracy": <1-5>, "relevance": <1-5>, "coherence": <1-5>, "notes": "<short>"}
```

## Baseline Comparison
- Compute per-metric delta: `score_model - score_baseline`.
- Flag regressions where delta <= -0.05 (configurable threshold).
- Include top 5 regressions and improvements in report.

## Integration with llmops-agent
Use llmops-agent as the runner and judge where available.

```bash
llmops-agent evaluate \
  --suite "$SUITE" \
  --benchmarks "$BENCHMARKS" \
  --model "$MODEL" \
  --baseline "$BASELINE" \
  --metrics "$METRICS" \
  --report "$REPORT" \
  --track "$TRACK" \
  --format "$FORMAT" \
  --limit "$LIMIT" \
  --seed "$SEED"
```

Expected inputs:
- Benchmarks file (YAML or JSONL)
- Optional judge prompt template (path or inline)

Expected outputs:
- Report file (md/json)
- Metrics history append (jsonl/csv)

## Report Template
```markdown
## LLM Evaluation Report

### Run Metadata
- Suite: <suite>
- Model: <model>
- Baseline: <baseline>
- Metrics: <metrics>
- Cases: <n>
- Timestamp: <iso8601>

### Aggregate Scores
| Metric | Score | Baseline | Delta |
|--------|-------|----------|-------|
| accuracy | | | |
| relevance | | | |
| coherence | | | |

### Highlights
- Regressions: [top 3]
- Improvements: [top 3]

### Failure Analysis
- [case id] - [summary of issue]
- [case id] - [summary of issue]

### Notes
<freeform notes>
```

## Metrics Tracking Format
Append JSONL records for each run:

```json
{"timestamp":"2026-01-21T12:00:00Z","suite":"qa-core-v1","model":"gpt-4.1","baseline":"gpt-4.0","metrics":{"accuracy":0.92,"relevance":0.88,"coherence":0.90},"cases":120,"notes":"release-candidate"}
```
