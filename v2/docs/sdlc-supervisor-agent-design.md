# SDLC Supervisor Agent Design

> **Version:** 1.0.0
> **Author:** Supervisor Research Session
> **Created:** 2025-12-28
> **Status:** Design Complete - Ready for Implementation

## Executive Summary

This document defines the SUPERVISOR AGENT's role in autonomous SDLC orchestration. The supervisor owns **quality enforcement** - it validates worker output, makes APPROVE/REJECT decisions, and ensures continuous quality improvement through feedback loops.

---

## 1. SDLC Phase Ownership Matrix

The supervisor does NOT own implementation - workers (Claude/Codex/Gemini) do. The supervisor owns **gates** and **quality enforcement**.

### 1.1 Phase Ownership Table

| Phase | Primary Owner | Supervisor Role | Trigger |
|-------|---------------|-----------------|---------|
| **BRAINSTORM** | Worker (Claude) | Validate completeness | Manual or PRD input |
| **DOCUMENT** | Worker (Claude) | Verify acceptance criteria exist | Brainstorm complete |
| **PLAN** | Worker (Claude) | Approve/reject decomposition | Spec approved |
| **EXECUTE** | Worker (Codex) | Monitor & audit commits | Task assigned |
| **REVIEW** | Supervisor | **OWN: Quality gate enforcement** | Work submitted |
| **APPROVE** | Supervisor | **OWN: Final decision** | Review passed |
| **TRACK** | Supervisor | **OWN: Metrics & regression detection** | Continuous |

### 1.2 Phase Transition Rules

```
[BRAINSTORM] --supervisor_validates--> [DOCUMENT]
     |
     v (if incomplete)
  [BRAINSTORM + feedback]

[DOCUMENT] --supervisor_validates--> [PLAN]
     |
     v (if missing acceptance criteria)
  [DOCUMENT + feedback]

[PLAN] --supervisor_approves--> [EXECUTE]
     |
     v (if scope too large)
  [PLAN + decomposition_request]

[EXECUTE] --worker_submits--> [REVIEW]
     |
     v (automatic on commit)

[REVIEW] --all_gates_pass--> [APPROVE] --merge--> [TRACK]
     |
     v (any gate fails)
  [REJECT] --feedback--> [EXECUTE]
```

### 1.3 Supervisor Input/Output Contracts

```yaml
# Supervisor receives from workers:
input:
  - task_id: string           # Unique identifier
  - commit_hash: string       # Git commit being reviewed
  - task_type: enum           # brainstorm|document|plan|execute
  - artifacts:                # Files changed
      - path: string
        diff_hash: string
  - worker_model: string      # claude|codex|gemini
  - trace_id: string

# Supervisor outputs:
output:
  - decision: enum            # APPROVE|REJECT|ESCALATE
  - gate_results: object      # Per-gate pass/fail
  - score: float              # 0.0-1.0 quality score
  - feedback: string          # Human-readable feedback
  - next_action: string       # What worker should do
  - metrics_update: object    # Updated quality metrics
```

---

## 2. Approval Engine Algorithm

### 2.1 Detection: Completed Work

The supervisor polls or watches for completed work:

```bash
# Detection sources (priority order):
1. tasks/review/          # Worker explicitly submits for review
2. git commits            # Automatic on any commit (current impl)
3. tasks/queue/*_DONE.md  # Worker marks task done
```

### 2.2 Quality Gate Pipeline

```
                    +-----------------+
                    | Work Submitted  |
                    +--------+--------+
                             |
                    +--------v--------+
                    | Gate 1: Syntax  |  (fast, blocking)
                    +--------+--------+
                             |
              +-----> FAIL --+
              |              |
              |     +--------v--------+
              |     | Gate 2: Tests   |  (medium, blocking)
              |     +--------+--------+
              |              |
              +-----> FAIL --+
              |              |
              |     +--------v--------+
              |     | Gate 3: Security|  (medium, blocking)
              |     +--------+--------+
              |              |
              +-----> FAIL --+
              |              |
              |     +--------v--------+
              |     | Gate 4: Coverage|  (slow, advisory)
              |     +--------+--------+
              |              |
              +-----> WARN --+  (advisory only)
              |              |
              |     +--------v--------+
              |     | Gate 5: Review  |  (slow, weighted)
              |     +--------+--------+
              |              |
              +-----> FAIL --+
              |              |
              |     +--------v--------+
     REJECT <-+-----| Decision Engine |-----> APPROVE
                    +-----------------+
```

### 2.3 Scoring Algorithm

```python
def calculate_approval_score(gate_results: dict) -> float:
    """
    Calculates weighted approval score.
    Returns 0.0-1.0 where >= 0.7 is APPROVE threshold.
    """
    weights = {
        'syntax':   {'weight': 0.15, 'blocking': True},
        'tests':    {'weight': 0.30, 'blocking': True},
        'security': {'weight': 0.25, 'blocking': True},
        'coverage': {'weight': 0.10, 'blocking': False},
        'review':   {'weight': 0.20, 'blocking': False},
    }

    total_score = 0.0
    blocking_failed = False

    for gate, config in weights.items():
        result = gate_results.get(gate, {})
        passed = result.get('passed', False)
        score = result.get('score', 0.0)  # 0.0-1.0

        if config['blocking'] and not passed:
            blocking_failed = True

        total_score += score * config['weight']

    # Blocking failures override score
    if blocking_failed:
        return 0.0

    return min(1.0, total_score)
```

### 2.4 Decision Logic

```python
def make_decision(score: float, gate_results: dict, context: dict) -> str:
    """
    Makes final APPROVE/REJECT/ESCALATE decision.
    """
    # Check for absolute blockers
    if gate_results.get('security', {}).get('critical_count', 0) > 0:
        return 'REJECT'  # No negotiation on critical security

    # Check retry count for escalation
    if context.get('retry_count', 0) >= 3:
        return 'ESCALATE'  # Human intervention needed

    # Score-based decision
    if score >= 0.7:
        return 'APPROVE'
    elif score >= 0.5:
        # Borderline - check consensus
        if context.get('consensus_available'):
            return 'CONSENSUS_REQUIRED'
        return 'REJECT'
    else:
        return 'REJECT'
```

---

## 3. Quality Gate Specifications

### 3.1 Gate Definitions

#### Gate 1: Syntax Validation
```yaml
gate: syntax
priority: 1
blocking: true
timeout_seconds: 30
checks:
  - name: shell_syntax
    command: "bash -n {file}"
    applies_to: "*.sh"
  - name: python_syntax
    command: "python3 -m py_compile {file}"
    applies_to: "*.py"
  - name: yaml_syntax
    command: "python3 -c \"import yaml; yaml.safe_load(open('{file}'))\""
    applies_to: "*.yaml,*.yml"
  - name: json_syntax
    command: "jq . {file} > /dev/null"
    applies_to: "*.json"
scoring:
  pass: 1.0
  fail: 0.0
```

#### Gate 2: Test Suite
```yaml
gate: tests
priority: 2
blocking: true
timeout_seconds: 300
checks:
  - name: unit_tests
    command: "./tests/run_tests.sh unit"
    weight: 0.6
  - name: integration_tests
    command: "./tests/run_tests.sh integration"
    weight: 0.4
scoring:
  formula: "(passed_tests / total_tests) * weight_sum"
  minimum_pass_rate: 0.95
  pass_threshold: 0.95
```

#### Gate 3: Security Audit
```yaml
gate: security
priority: 3
blocking: true
timeout_seconds: 180
checks:
  - name: secret_scan
    command: "bin/tri-agent-security-audit --secrets"
    critical_on: "any_match"
  - name: owasp_check
    command: "bin/tri-agent-security-audit --owasp"
    critical_on: "high_severity"
  - name: dependency_audit
    command: "bin/tri-agent-security-audit --deps"
    critical_on: "critical_cve"
scoring:
  critical_found: 0.0
  high_found: 0.3
  medium_found: 0.7
  low_only: 0.9
  clean: 1.0
```

#### Gate 4: Code Coverage
```yaml
gate: coverage
priority: 4
blocking: false  # Advisory only
timeout_seconds: 300
checks:
  - name: line_coverage
    command: "bin/tri-agent-coverage --metric line"
    target: 70
  - name: branch_coverage
    command: "bin/tri-agent-coverage --metric branch"
    target: 60
scoring:
  formula: "min(actual_coverage / target, 1.0)"
  regression_penalty: 0.2  # If coverage drops
```

#### Gate 5: Tri-Agent Code Review
```yaml
gate: review
priority: 5
blocking: false  # But required for approval
timeout_seconds: 180
checks:
  - name: claude_review
    command: "bin/claude-delegate 'Review this code for quality'"
    weight: 0.4
    extract_score: "confidence"
  - name: codex_review
    command: "bin/codex-ask 'Check this implementation'"
    weight: 0.3
    extract_score: "approval_confidence"
  - name: gemini_review
    command: "bin/gemini-ask 'Architecture review'"
    weight: 0.3
    extract_score: "confidence"
scoring:
  consensus_mode: "weighted_average"
  minimum_approvals: 2
  veto_on_security: true
```

### 3.2 Gate Execution Order

```bash
# Parallel where possible, serial where dependent
STAGE_1:  # Fast checks (parallel)
  - syntax (30s)

STAGE_2:  # Medium checks (serial - tests may modify state)
  - tests (300s)
  - security (180s)

STAGE_3:  # Slow checks (parallel)
  - coverage (300s)
  - review (180s)

# Total worst-case: ~15 minutes
# Typical case: ~5 minutes
```

---

## 4. Rejection Feedback Generator

### 4.1 Feedback Structure

```markdown
# SUPERVISOR REJECTION: {task_id}

## Decision: REJECT

## Summary
{1-2 sentence summary of why rejected}

## Failed Gates

### {Gate Name} - FAILED
- **Score:** {score}/1.0
- **Reason:** {specific failure reason}
- **Evidence:**
  ```
  {relevant log output or error messages}
  ```

## Recommended Fix

### Root Cause Analysis
{AI-generated analysis from tri-agent}

### Specific Actions
1. {Concrete action 1}
2. {Concrete action 2}
3. {Concrete action 3}

### Code Suggestions
```{language}
{Codex-generated fix suggestion}
```

## Constraints
- Retry Count: {n}/3
- Time Remaining: {estimated time budget}
- Scope: {what CAN be changed vs what's frozen}

## Metadata
- Task ID: {task_id}
- Commit: {commit_hash}
- Reviewed: {timestamp}
- Trace ID: {trace_id}
```

### 4.2 Feedback Generation Algorithm

```python
def generate_rejection_feedback(
    task_id: str,
    gate_results: dict,
    analysis: dict
) -> str:
    """
    Generates actionable rejection feedback.
    """
    # 1. Identify primary failure cause
    failed_gates = [g for g, r in gate_results.items() if not r['passed']]
    primary_failure = failed_gates[0] if failed_gates else 'unknown'

    # 2. Extract specific error evidence
    evidence = extract_failure_evidence(gate_results[primary_failure])

    # 3. Generate root cause analysis (async from tri-agent)
    root_cause = analysis.get('claude_analysis', 'Analysis unavailable')

    # 4. Generate fix suggestions (from Codex)
    fix_suggestions = analysis.get('codex_fix', 'No suggestions available')

    # 5. Generate architecture review (from Gemini)
    arch_review = analysis.get('gemini_review', '')

    # 6. Calculate constraints
    retry_count = get_retry_count(task_id)
    remaining_budget = estimate_time_budget(task_id)

    # 7. Assemble feedback
    return format_feedback_markdown(
        task_id=task_id,
        primary_failure=primary_failure,
        evidence=evidence,
        root_cause=root_cause,
        fix_suggestions=fix_suggestions,
        arch_review=arch_review,
        retry_count=retry_count,
        remaining_budget=remaining_budget
    )
```

### 4.3 Feedback Quality Rules

1. **Actionable**: Every rejection MUST include at least one concrete action
2. **Specific**: Reference exact line numbers, file paths, error messages
3. **Bounded**: Limit scope to prevent yak-shaving
4. **Prioritized**: Order fixes by impact (blocking issues first)
5. **Constructive**: Focus on "do this" not "don't do that"

---

## 5. Anti-Loop Safeguards

### 5.1 Loop Detection Mechanisms

```python
# Mechanism 1: Retry Counter
MAX_RETRIES = 3

def check_retry_limit(task_id: str) -> bool:
    """Returns True if retries exceeded."""
    history = load_task_history(task_id)
    retry_count = sum(1 for h in history if h['status'] == 'rejected')
    return retry_count >= MAX_RETRIES

# Mechanism 2: Signature Matching
def check_repeated_failure(task_id: str, error_signature: str) -> bool:
    """Returns True if same error repeated 3+ times."""
    history = load_task_history(task_id)
    matching = sum(1 for h in history
                   if h.get('error_signature') == error_signature)
    return matching >= 3

# Mechanism 3: Fix Deduplication
def check_duplicate_fix(task_id: str, fix_hash: str) -> bool:
    """Returns True if this exact fix was tried before."""
    history = load_task_history(task_id)
    return any(h.get('fix_hash') == fix_hash for h in history)

# Mechanism 4: Time Budget
MAX_TASK_AGE_HOURS = 24

def check_time_budget(task_id: str) -> bool:
    """Returns True if task exceeded time budget."""
    created_at = get_task_created_time(task_id)
    age_hours = (now() - created_at).total_seconds() / 3600
    return age_hours > MAX_TASK_AGE_HOURS
```

### 5.2 Escalation Triggers

| Trigger | Threshold | Action |
|---------|-----------|--------|
| Retry limit | 3 rejections | Escalate to human |
| Same error | 3 occurrences | Escalate with diagnosis |
| Duplicate fix | 1 occurrence | Block + escalate |
| Time budget | 24 hours | Escalate with summary |
| Resource limit | 80% CPU/MEM | Pause + escalate |
| Security critical | 1 occurrence | Immediate escalate |

### 5.3 Escalation Workflow

```
[Loop Detected]
      |
      v
[Create Incident]
      |
      +---> incident_YYYYMMDD_HHMMSS.json
      |
      v
[Pause Autonomous]
      |
      +---> touch PAUSE_REQUESTED
      |
      v
[Notify Human]
      |
      +---> Desktop notification
      +---> Task queue entry
      |
      v
[Preserve State]
      |
      +---> Checkpoint session
      +---> Archive logs
      |
      v
[Await Resolution]
```

### 5.4 Safeguard State Machine

```
                    +-------------------+
                    |    OPERATING      |
                    +--------+----------+
                             |
           retry_count++     |
                             v
                    +--------+----------+
                    |   CHECK_LIMITS    |
                    +--------+----------+
                             |
         +-------------------+-------------------+
         |                   |                   |
         v                   v                   v
   [under limit]      [at limit]         [over limit]
         |                   |                   |
         v                   v                   v
   +-----+-----+      +------+------+    +------+------+
   | CONTINUE  |      | WARN_USER   |    |  ESCALATE   |
   +-----------+      +------+------+    +------+------+
                             |                   |
                             v                   v
                      +------+------+    +------+------+
                      | one_more_try|    | PAUSED      |
                      +-------------+    +------+------+
                                                |
                                         [human resolves]
                                                |
                                                v
                                         +------+------+
                                         |   RESUME    |
                                         +-------------+
```

---

## 6. Bash Function Signatures

### 6.1 Core Supervisor Functions

```bash
# =============================================================================
# supervisor-approval.sh - Approval Engine Functions
# =============================================================================

# Main approval entry point
# Returns: 0=APPROVE, 1=REJECT, 2=ESCALATE
supervisor_approve() {
    local task_id="$1"
    local commit_hash="$2"
    # Implementation
}

# Run all quality gates
# Returns: JSON with gate results
run_quality_gates() {
    local commit_hash="$1"
    local output_file="$2"
    # Implementation
}

# Calculate approval score
# Returns: float 0.0-1.0
calculate_score() {
    local gate_results_json="$1"
    # Implementation
}

# Make final decision
# Returns: APPROVE|REJECT|ESCALATE
make_approval_decision() {
    local score="$1"
    local gate_results_json="$2"
    local context_json="$3"
    # Implementation
}
```

### 6.2 Gate Execution Functions

```bash
# =============================================================================
# supervisor-gates.sh - Quality Gate Functions
# =============================================================================

# Gate 1: Syntax validation
# Returns: 0=pass, 1=fail
gate_syntax() {
    local files_json="$1"
    local output_file="$2"
    # Implementation
}

# Gate 2: Test execution
# Returns: 0=pass, 1=fail
gate_tests() {
    local commit_hash="$1"
    local output_file="$2"
    # Implementation
}

# Gate 3: Security audit
# Returns: 0=pass, 1=fail (critical blocks)
gate_security() {
    local commit_hash="$1"
    local output_file="$2"
    # Implementation
}

# Gate 4: Coverage check
# Returns: 0=pass, 1=warning (advisory)
gate_coverage() {
    local commit_hash="$1"
    local output_file="$2"
    # Implementation
}

# Gate 5: Tri-agent review
# Returns: 0=pass, 1=fail
gate_review() {
    local commit_hash="$1"
    local diff_context="$2"
    local output_file="$3"
    # Implementation
}
```

### 6.3 Feedback Generation Functions

```bash
# =============================================================================
# supervisor-feedback.sh - Rejection Feedback Functions
# =============================================================================

# Generate rejection feedback
# Outputs: Markdown file path
generate_rejection_feedback() {
    local task_id="$1"
    local gate_results_json="$2"
    local analysis_json="$3"
    local output_dir="${4:-$FEEDBACK_DIR}"
    # Implementation
}

# Analyze failure with tri-agent
# Returns: JSON with analysis from all 3 models
analyze_failure_tri_agent() {
    local failure_log="$1"
    local failure_type="$2"  # code|security|test
    local output_file="$3"
    # Implementation
}

# Extract actionable fix suggestions
# Returns: Markdown list of actions
extract_fix_actions() {
    local analysis_json="$1"
    # Implementation
}
```

### 6.4 Anti-Loop Functions

```bash
# =============================================================================
# supervisor-safeguards.sh - Anti-Loop Safeguards
# =============================================================================

# Check all safeguards before allowing retry
# Returns: 0=safe, 1=escalate
check_safeguards() {
    local task_id="$1"
    local error_signature="$2"
    local fix_hash="$3"
    # Implementation
}

# Get retry count for task lineage
# Returns: integer
get_retry_count() {
    local task_id="$1"
    # Implementation
}

# Check for rejection loop
# Returns: 0=no loop, 1=loop detected
check_rejection_loop() {
    local task_json="$1"
    # Implementation (calls lineage_graph.py)
}

# Trigger human escalation
# Returns: incident file path
trigger_escalation() {
    local reason="$1"
    local context_file="$2"
    local severity="${3:-HIGH}"
    # Implementation
}

# Update task lineage history
# Returns: 0=success
update_task_history() {
    local task_id="$1"
    local status="$2"  # approved|rejected|escalated
    local metadata_json="$3"
    # Implementation
}
```

### 6.5 Workflow Orchestration Functions

```bash
# =============================================================================
# supervisor-workflow.sh - Workflow Orchestration
# =============================================================================

# Main approval workflow
# Returns: 0=approved, 1=rejected, 2=escalated
run_approval_workflow() {
    local task_id="$1"
    local commit_hash="$2"

    # 1. Check safeguards
    if ! check_safeguards "$task_id"; then
        trigger_escalation "Safeguard triggered" "$task_id"
        return 2
    fi

    # 2. Run quality gates
    local gate_results
    gate_results=$(run_quality_gates "$commit_hash")

    # 3. Calculate score
    local score
    score=$(calculate_score "$gate_results")

    # 4. Make decision
    local decision
    decision=$(make_approval_decision "$score" "$gate_results")

    # 5. Handle decision
    case "$decision" in
        APPROVE)
            handle_approval "$task_id" "$commit_hash"
            return 0
            ;;
        REJECT)
            handle_rejection "$task_id" "$gate_results"
            return 1
            ;;
        ESCALATE)
            handle_escalation "$task_id" "$gate_results"
            return 2
            ;;
    esac
}

# Handle approved task
handle_approval() {
    local task_id="$1"
    local commit_hash="$2"

    # Move to approved
    move_task "approved" "$task_id"

    # Update metrics
    update_metrics "$task_id" "approved"

    # Notify worker
    notify_worker "$task_id" "APPROVED" "Work accepted. Merging."
}

# Handle rejected task
handle_rejection() {
    local task_id="$1"
    local gate_results="$2"

    # Generate feedback
    local analysis
    analysis=$(analyze_failure_tri_agent "$gate_results")

    local feedback_file
    feedback_file=$(generate_rejection_feedback "$task_id" "$gate_results" "$analysis")

    # Create fix task
    create_fix_task "$task_id" "$feedback_file"

    # Update history
    update_task_history "$task_id" "rejected" "$gate_results"

    # Notify worker
    notify_worker "$task_id" "REJECTED" "See feedback: $feedback_file"
}

# Handle escalation
handle_escalation() {
    local task_id="$1"
    local context="$2"

    # Trigger escalation protocol
    trigger_escalation "Max retries or loop detected" "$task_id" "HIGH"

    # Update history
    update_task_history "$task_id" "escalated" "$context"
}
```

---

## 7. Task Queue Integration

### 7.1 Directory Structure

```
tasks/
├── queue/              # Pending tasks (worker picks up)
│   ├── CRITICAL_*.md
│   ├── HIGH_*.md
│   └── MEDIUM_*.md
├── running/            # Currently being worked on
├── review/             # Submitted for supervisor review
├── approved/           # Passed all gates
├── completed/          # Merged/deployed
├── failed/             # Exhausted retries
├── history/            # JSON metadata for lineage
└── supervisor_feedback/  # Rejection feedback files
```

### 7.2 Task State Transitions

```
[queue] --worker_picks_up--> [running]
    ^                            |
    |                   worker_submits
    |                            |
    |                            v
    +----feedback-------- [review] --supervisor_approves--> [approved]
                             |                                  |
                        supervisor_rejects                    merge
                             |                                  |
                             v                                  v
                    [queue + feedback]                    [completed]
                             |
                      (after 3 retries)
                             |
                             v
                        [failed] --escalation--> Human
```

### 7.3 Ledger Format

```jsonl
{"task_id":"TASK-001","timestamp":"2025-12-28T12:00:00Z","status":"created","phase":"queue"}
{"task_id":"TASK-001","timestamp":"2025-12-28T12:05:00Z","status":"running","worker":"codex"}
{"task_id":"TASK-001","timestamp":"2025-12-28T12:30:00Z","status":"review","commit":"abc123"}
{"task_id":"TASK-001","timestamp":"2025-12-28T12:35:00Z","status":"rejected","score":0.45,"retry":1}
{"task_id":"TASK-001","timestamp":"2025-12-28T13:00:00Z","status":"review","commit":"def456"}
{"task_id":"TASK-001","timestamp":"2025-12-28T13:05:00Z","status":"approved","score":0.82}
{"task_id":"TASK-001","timestamp":"2025-12-28T13:06:00Z","status":"completed","merged":true}
```

---

## 8. Metrics & Continuous Quality

### 8.1 Quality Metrics Tracked

```yaml
metrics:
  # Per-task metrics
  task:
    - approval_rate        # % of tasks approved on first try
    - avg_retry_count      # Average retries before approval
    - avg_time_to_approve  # Time from submit to approve
    - rejection_reasons    # Distribution of failure types

  # Per-gate metrics
  gate:
    - pass_rate            # % passing each gate
    - avg_score            # Average score per gate
    - blocking_rate        # % of rejections caused by gate

  # Trend metrics
  trend:
    - coverage_delta       # Coverage change over time
    - security_findings    # Security issues found over time
    - quality_score_trend  # Overall quality trajectory
```

### 8.2 Regression Detection

```python
def detect_regression(current_metrics: dict, baseline: dict) -> list:
    """
    Detects quality regressions that should trigger alerts.
    """
    regressions = []

    # Coverage regression (>5% drop)
    if current_metrics['coverage'] < baseline['coverage'] - 5:
        regressions.append({
            'type': 'coverage',
            'severity': 'HIGH',
            'delta': current_metrics['coverage'] - baseline['coverage']
        })

    # Approval rate regression (>10% drop)
    if current_metrics['approval_rate'] < baseline['approval_rate'] - 0.10:
        regressions.append({
            'type': 'approval_rate',
            'severity': 'MEDIUM',
            'delta': current_metrics['approval_rate'] - baseline['approval_rate']
        })

    # Security findings increase
    if current_metrics['security_high'] > baseline['security_high']:
        regressions.append({
            'type': 'security',
            'severity': 'CRITICAL',
            'delta': current_metrics['security_high'] - baseline['security_high']
        })

    return regressions
```

---

## 9. Configuration

### 9.1 Supervisor Config Section (tri-agent.yaml)

```yaml
supervisor:
  enabled: true
  watch_interval: 30          # Seconds between checks

  gates:
    syntax:
      enabled: true
      blocking: true
      timeout: 30
    tests:
      enabled: true
      blocking: true
      timeout: 300
      min_pass_rate: 0.95
    security:
      enabled: true
      blocking: true
      timeout: 180
      critical_blocks: true
    coverage:
      enabled: true
      blocking: false
      timeout: 300
      target: 70
      regression_threshold: 5
    review:
      enabled: true
      blocking: false
      timeout: 180
      consensus_required: 2

  thresholds:
    approval_score: 0.7
    warning_score: 0.5
    max_retries: 3
    max_task_age_hours: 24

  escalation:
    notify_desktop: true
    pause_autonomous: true
    create_incident: true
```

---

## 10. Implementation Roadmap

### Phase 1: Core Approval Engine (Week 1)
- [ ] `supervisor-approval.sh` - Core decision logic
- [ ] `supervisor-gates.sh` - Gate implementations
- [ ] Integration with existing `tri-agent-supervisor`

### Phase 2: Feedback Generator (Week 2)
- [ ] `supervisor-feedback.sh` - Feedback generation
- [ ] Tri-agent analysis integration
- [ ] Fix task creation

### Phase 3: Anti-Loop Safeguards (Week 3)
- [ ] `supervisor-safeguards.sh` - Loop detection
- [ ] Escalation workflow
- [ ] Lineage tracking

### Phase 4: Metrics & Tuning (Week 4)
- [ ] Metrics collection
- [ ] Regression detection
- [ ] Threshold tuning based on real data

---

## Appendix A: Error Signatures

Common error signatures for deduplication:

```python
ERROR_SIGNATURES = {
    # Test failures
    'test_assertion': r'AssertionError:.*',
    'test_timeout': r'Timeout.*test.*',

    # Security issues
    'hardcoded_secret': r'(password|secret|key)\s*=\s*["\'][^"\']+["\']',
    'sql_injection': r'execute\s*\([^)]*\+[^)]*\)',

    # Syntax errors
    'bash_syntax': r'syntax error near.*',
    'python_syntax': r'SyntaxError:.*',

    # Coverage failures
    'coverage_drop': r'Coverage.*below.*threshold',
}
```

---

## Appendix B: Consensus Voting

When `consensus_required` is set:

```python
def weighted_consensus(votes: dict) -> str:
    """
    Calculates weighted consensus from tri-agent reviews.

    votes = {
        'claude': {'decision': 'APPROVE', 'confidence': 0.8},
        'codex': {'decision': 'APPROVE', 'confidence': 0.7},
        'gemini': {'decision': 'REJECT', 'confidence': 0.6}
    }
    """
    weights = {'claude': 0.4, 'codex': 0.3, 'gemini': 0.3}

    approve_score = 0.0
    reject_score = 0.0

    for model, vote in votes.items():
        weighted_confidence = vote['confidence'] * weights[model]
        if vote['decision'] == 'APPROVE':
            approve_score += weighted_confidence
        else:
            reject_score += weighted_confidence

    # Veto check (security)
    if votes.get('claude', {}).get('security_veto'):
        return 'REJECT'

    return 'APPROVE' if approve_score > reject_score else 'REJECT'
```

---

**Document Status:** COMPLETE
**Ready for:** Implementation Phase
**Next Step:** Create `lib/supervisor-approval.sh` based on this design
