# Tri-Agent Daemon Test Pass/Fail Criteria

## Overview

This document defines the pass/fail criteria for tri-agent daemon tests. All tests must meet these criteria to be considered passing.

## General Pass/Fail Rules

### Test Case Status Definitions

| Status | Description |
|--------|-------------|
| **PASS** | All assertions met, no errors, within timeout |
| **FAIL** | One or more assertions failed, or error occurred |
| **SKIP** | Test was skipped (disabled, filtered, or dependency failed) |
| **ERROR** | Test execution error (not a validation failure) |
| **TIMEOUT** | Test exceeded configured timeout |

### Automatic Failure Conditions

A test automatically **FAILS** if:

1. **Exit Code Mismatch**: Process exit code differs from expected
2. **Timeout Exceeded**: Test duration exceeds configured timeout
3. **Setup Failure**: Pre-test setup commands fail
4. **State Corruption**: Post-test state validation fails
5. **Missing Output**: Required output patterns not found
6. **Forbidden Output**: Prohibited patterns found in output
7. **Database Assertion Failure**: SQL queries return unexpected results
8. **Process State Mismatch**: Expected processes not running/stopped
9. **Agent Count Violation**: Less than required concurrent agents
10. **Two-Key Rule Violation**: Same model used for implementation and verification

---

## Category-Specific Criteria

### Daemon Lifecycle Tests

**PASS Requirements:**
- Daemon starts within 30 seconds
- All 9 agents initialize successfully
- PID file created with valid process ID
- Heartbeat file updated within 60 seconds
- Graceful shutdown completes within 15 seconds
- No orphan processes after shutdown

**FAIL Conditions:**
- Startup takes > 60 seconds
- Less than 9 agents active
- Missing PID or heartbeat files
- Zombie processes after shutdown

### Agent Coordination Tests

**PASS Requirements:**
- Tasks assigned within 5 seconds of submission
- Assigned agent differs from verifier agent
- Agent models match required distribution (3-3-3)
- Task state transitions are valid

**FAIL Conditions:**
- Assignment timeout (> 30 seconds)
- Same model for implementer and verifier
- Invalid state transition (e.g., pending -> completed without in_progress)
- Agent overload (> 5 tasks per agent)

### Verification Flow Tests

**PASS Requirements:**
- Two-Key Rule enforced (different AI models)
- Verification completes within 180 seconds
- VERIFY block format followed
- Audit trail created in database

**FAIL Conditions:**
- Same-model verification attempted
- Verification timeout
- Missing audit trail
- Invalid VERIFY block format

### Recovery Tests

**PASS Requirements:**
- Watchdog detects crash within 60 seconds
- Checkpoint restored successfully
- All pending tasks resumed
- No data loss confirmed
- Recovery completes within 120 seconds

**FAIL Conditions:**
- Recovery takes > 180 seconds
- Tasks lost during recovery
- State corruption detected
- Repeated crash loops (> 3)

### Concurrency Tests

**PASS Requirements:**
- Minimum 9 concurrent agents maintained
- Distribution: 3 Claude + 3 Codex + 3 Gemini
- No race conditions detected
- Lock contention < 10%
- Peak concurrency recorded correctly

**FAIL Conditions:**
- Concurrent agents < 9 at any point
- Unequal distribution (not 3-3-3)
- Deadlock detected
- Lock contention > 20%

---

## Validation Types

### 1. Exit Code Validation

```yaml
expected:
  exit_code: 0  # Must match exactly
```

**Criteria:**
- `exit_code: 0` = Success
- `exit_code: 1` = General error
- `exit_code: 124` = Timeout
- Any mismatch = FAIL

### 2. Output Validation

```yaml
expected:
  stdout:
    contains:
      - "expected string"
    not_contains:
      - "error"
      - "exception"
    regex: "pattern.*match"
```

**Criteria:**
- `contains`: ALL listed strings must appear
- `not_contains`: NONE of listed strings may appear
- `regex`: Pattern must match at least once
- Empty output when not expected = FAIL

### 3. State Validation

```yaml
expected:
  state:
    database:
      - query: "SELECT COUNT(*) FROM tasks WHERE status = 'completed'"
        expected: { "count": 5 }
        comparison: "exact"
```

**Comparison Types:**
- `exact`: Values must match exactly
- `contains`: Expected subset of actual
- `count`: Row count must match
- `exists`: At least one row returned

### 4. Process Validation

```yaml
expected:
  state:
    processes:
      - name: "tri-agent-daemon"
        running: true
        count: 1
```

**Criteria:**
- `running: true` = Process must be active
- `running: false` = Process must not exist
- `count`: Exact number of matching processes

### 5. File Validation

```yaml
expected:
  state:
    files:
      - path: "/path/to/file"
        exists: true
        content:
          contains: "expected content"
```

**Criteria:**
- `exists: true` = File must exist
- `exists: false` = File must not exist
- `content`: Content must match pattern

### 6. Metric Validation

```yaml
expected:
  metrics:
    duration_max_ms: 30000
    memory_max_mb: 512
    cpu_max_percent: 80
```

**Criteria:**
- Actual value must be <= maximum
- Exceeding any threshold = FAIL

### 7. Event Validation

```yaml
expected:
  events:
    - type: "daemon.started"
      count: 1
      order: 1
```

**Criteria:**
- `count`: Exact number of events
- `order`: Relative ordering (1 before 2 before 3)
- Missing events = FAIL

---

## Retry Logic

### Retry Configuration

```yaml
retry:
  max_attempts: 3
  backoff:
    type: "exponential"  # fixed, linear, exponential
    base_seconds: 2
    max_seconds: 60
  on_conditions:
    - "timeout"
    - "transient_error"
  reset_state: true
```

### Retry Conditions

| Condition | Description | Retry? |
|-----------|-------------|--------|
| `timeout` | Test exceeded timeout | Yes |
| `transient_error` | Network/API temporary failure | Yes |
| `exit_code_mismatch` | Wrong exit code | Configurable |
| `output_mismatch` | Wrong output | Configurable |
| `state_mismatch` | State validation failed | Configurable |
| `setup_failure` | Setup phase failed | Yes |

### Backoff Calculation

```
fixed:       wait = base_seconds
linear:      wait = base_seconds * attempt
exponential: wait = min(base_seconds ^ attempt, max_seconds)
```

### Final Verdict

- Test **PASSES** if it succeeds on ANY attempt
- Test **FAILS** only after ALL retries exhausted
- Retry count recorded in report

---

## Scoring and Thresholds

### Test Suite Pass Criteria

| Metric | Threshold | Action |
|--------|-----------|--------|
| Pass Rate | >= 95% | Suite PASSES |
| Pass Rate | 90-95% | Suite PASSES with warnings |
| Pass Rate | < 90% | Suite FAILS |
| Critical Tests | 100% | All must pass |
| High Priority | >= 98% | Required for release |

### Quality Gates

```yaml
quality_gates:
  minimum_pass_rate: 0.95
  critical_tests_required: true
  max_flaky_tests: 5
  coverage_categories:
    - daemon-lifecycle: 100%
    - agent-coordination: 100%
    - verification-flow: 100%
    - recovery: 95%
    - concurrency: 95%
```

---

## Failure Reporting

### Required Information on Failure

1. **Test ID and Name**
2. **Category and Priority**
3. **Failure Type** (assertion, timeout, error)
4. **Expected vs Actual Values**
5. **Stack Trace** (if applicable)
6. **Retry Attempts** and results
7. **Log File Location**
8. **State Snapshot** (if available)

### Failure Format

```json
{
  "test_id": "TAT-0001",
  "name": "Daemon Startup - Normal Conditions",
  "status": "FAIL",
  "failure_type": "assertion",
  "assertion": {
    "type": "exit_code",
    "expected": 0,
    "actual": 1
  },
  "attempts": 3,
  "duration_ms": 45000,
  "log_file": "/path/to/log",
  "timestamp": "2026-01-04T12:00:00Z"
}
```

---

## Special Criteria

### Tri-Agent Mandatory Requirements

Every test involving agent execution MUST verify:

1. **9 Concurrent Agents**: 3 Claude + 3 Codex + 3 Gemini
2. **Two-Key Rule**: Different models for implementation and verification
3. **Tri-Agent Distribution**: Equal distribution across models
4. **21 Agent Invocations**: Per complete task (7 per phase x 3 phases)

### Security-Sensitive Tests

Additional criteria for security tests:

1. No credentials in logs
2. Audit trail complete
3. Permissions validated
4. Input sanitization verified
5. No privilege escalation

### Performance Tests

Additional criteria for performance tests:

1. Response time within SLA
2. Memory usage within limits
3. No memory leaks detected
4. CPU usage sustainable
5. No resource exhaustion
