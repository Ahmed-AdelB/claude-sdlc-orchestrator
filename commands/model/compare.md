---
name: /model:compare
version: 1.0
description: Compare outputs across Claude, Codex, and Gemini for the same prompt and recommend the best model.
args:
  - name: prompt
    type: string
    required: true
    description: The exact prompt to send to each model.
  - name: task_type
    type: string
    required: false
    default: general
    description: Task category (e.g., coding, analysis, summarization, creative, data-extraction, planning, debugging, UX copy).
  - name: context
    type: string
    required: false
    description: Optional background or constraints to include with the prompt.
  - name: criteria
    type: string
    required: false
    default: default
    description: Scoring rubric selection (default | coding | analysis | creative | summarization | extraction).
  - name: format
    type: string
    required: false
    default: markdown
    description: Output format (markdown | json).
  - name: max_tokens
    type: number
    required: false
    default: 1024
    description: Per-model response token budget.
---

# /model:compare

Compare outputs across Claude, Codex, and Gemini for the same prompt. Produce a structured comparison, highlight differences, score quality metrics, and recommend the best model for the task type.

## Usage

```
/model:compare
  prompt="<YOUR PROMPT>"
  task_type="coding"
  context="Optional constraints or background"
  criteria="coding"
  format="markdown"
  max_tokens=1024
```

## Arguments

- `prompt` (required): Exact prompt to send to each model.
- `task_type` (optional): Task category for recommendation bias (default: `general`).
- `context` (optional): Extra constraints appended to the prompt.
- `criteria` (optional): Scoring rubric selection (default: `default`).
- `format` (optional): Output format for comparison (default: `markdown`).
- `max_tokens` (optional): Response length limit per model (default: `1024`).

## Procedure

1. Construct the final prompt:
   - If `context` provided, append under a clear header.
   - Preserve exact wording for all models.
2. Send the identical prompt to each model:
   - Claude
   - Codex
   - Gemini
3. Capture the full responses.
4. Normalize formatting (trim leading/trailing whitespace; preserve code blocks).
5. Compare outputs and highlight differences.
6. Score each model on the selected rubric.
7. Recommend the best model for `task_type` with brief justification.

## Comparison Template (Markdown)

```
# Model Comparison

## Prompt
<FINAL PROMPT>

## Responses

### Claude
<CLAUDE RESPONSE>

### Codex
<CODEX RESPONSE>

### Gemini
<GEMINI RESPONSE>

## Differences
- Content coverage:
  - Claude: <notes>
  - Codex: <notes>
  - Gemini: <notes>
- Correctness/accuracy:
  - Claude: <notes>
  - Codex: <notes>
  - Gemini: <notes>
- Clarity/structure:
  - Claude: <notes>
  - Codex: <notes>
  - Gemini: <notes>
- Compliance with constraints:
  - Claude: <notes>
  - Codex: <notes>
  - Gemini: <notes>
- Style/tone fit:
  - Claude: <notes>
  - Codex: <notes>
  - Gemini: <notes>

## Scores (0-5)
| Metric | Claude | Codex | Gemini |
|---|---:|---:|---:|
| Instruction following | | | |
| Accuracy/correctness | | | |
| Completeness | | | |
| Clarity/structure | | | |
| Safety/risk | | | |
| Task-specific quality | | | |
| Overall | | | |

## Recommendation
Best model for `<task_type>`: **<MODEL>**
Rationale: <brief, 2-4 sentences>
```

## Comparison Template (JSON)

```
{
  "prompt": "<FINAL PROMPT>",
  "responses": {
    "claude": "<CLAUDE RESPONSE>",
    "codex": "<CODEX RESPONSE>",
    "gemini": "<GEMINI RESPONSE>"
  },
  "differences": {
    "content_coverage": {"claude": "", "codex": "", "gemini": ""},
    "accuracy": {"claude": "", "codex": "", "gemini": ""},
    "clarity": {"claude": "", "codex": "", "gemini": ""},
    "constraint_compliance": {"claude": "", "codex": "", "gemini": ""},
    "style_tone": {"claude": "", "codex": "", "gemini": ""}
  },
  "scores": {
    "instruction_following": {"claude": 0, "codex": 0, "gemini": 0},
    "accuracy": {"claude": 0, "codex": 0, "gemini": 0},
    "completeness": {"claude": 0, "codex": 0, "gemini": 0},
    "clarity": {"claude": 0, "codex": 0, "gemini": 0},
    "safety_risk": {"claude": 0, "codex": 0, "gemini": 0},
    "task_specific": {"claude": 0, "codex": 0, "gemini": 0},
    "overall": {"claude": 0, "codex": 0, "gemini": 0}
  },
  "recommendation": {
    "task_type": "<task_type>",
    "best_model": "<MODEL>",
    "rationale": "<brief rationale>"
  }
}
```

## Scoring Rubrics (0-5)

### Default Rubric
- 5: Exceptional; fully correct, complete, clear, and aligned with constraints.
- 4: Strong; minor gaps or slight clarity issues.
- 3: Adequate; correct but incomplete or somewhat unclear.
- 2: Weak; partial correctness or notable omissions.
- 1: Poor; mostly incorrect or off-task.
- 0: Failure; unusable or unsafe.

### Coding Rubric
- Instruction following: Adheres to language/framework constraints.
- Accuracy/correctness: Code compiles/runs; logic correct; no obvious bugs.
- Completeness: Covers edge cases, tests, and error handling where expected.
- Clarity/structure: Readable, idiomatic, and well-organized.
- Safety/risk: Avoids insecure patterns; respects input validation and constraints.
- Task-specific quality: Performance, DX, and maintainability.

### Analysis Rubric
- Instruction following: Matches requested depth and scope.
- Accuracy: Sound reasoning; no factual errors.
- Completeness: Covers key factors and alternatives.
- Clarity: Logical flow; easy to follow.
- Safety/risk: Avoids unsupported claims or risky guidance.
- Task-specific quality: Insightfulness and practical applicability.

### Creative Rubric
- Instruction following: Matches genre, tone, and constraints.
- Originality: Novelty and imagination.
- Coherence: Internal consistency and structure.
- Clarity: Readable and engaging.
- Safety/risk: Avoids disallowed content.
- Task-specific quality: Fit for audience and purpose.

### Summarization Rubric
- Instruction following: Follows length and style constraints.
- Accuracy: Faithful to source; no hallucinations.
- Completeness: Captures key points.
- Clarity: Concise and well-structured.
- Safety/risk: No sensitive leakage.
- Task-specific quality: Appropriate emphasis and abstraction level.

### Extraction Rubric
- Instruction following: Extracts required fields only.
- Accuracy: Correctly identifies entities/values.
- Completeness: All required fields captured.
- Clarity: Clean, unambiguous output.
- Safety/risk: No extra or inferred data.
- Task-specific quality: Schema adherence and validation readiness.

## Differences Guidance

Highlight differences that matter for the task:
- Coverage gaps or missing constraints
- Incorrect assumptions or hallucinations
- Misaligned tone or format
- Errors in code, math, or logic
- Over- or under-verbosity

## Recommendation Guidance

Recommend the model that best fits `task_type` based on scores and observed strengths.
Use ties only if truly equivalent; otherwise choose one and justify briefly.
