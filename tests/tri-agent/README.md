# Tri-Agent Daemon Test Framework

A comprehensive test framework for validating the tri-agent daemon system.

## Directory Structure

```
tests/tri-agent/
├── config.yaml                    # Framework configuration
├── PASS_FAIL_CRITERIA.md         # Pass/fail criteria documentation
├── README.md                      # This file
├── cases/                         # Test case definitions
│   ├── daemon-lifecycle/          # Daemon startup/shutdown tests
│   ├── agent-coordination/        # Task assignment tests
│   ├── verification-flow/         # Two-key rule tests
│   ├── recovery/                  # Crash recovery tests
│   ├── concurrency/               # 9-agent parallelism tests
│   ├── state-management/          # Checkpoint tests
│   └── budget-tracking/           # Token budget tests
├── fixtures/                      # Test fixtures and data
│   ├── daemon-config.yaml
│   └── sample-tasks.json
├── mocks/                         # Mock agent responses
│   └── agent-responses.yaml
├── schemas/                       # JSON schemas for validation
│   └── test-case-schema.json
├── runners/                       # Test runner scripts
│   ├── test-runner.sh
│   └── test_runner.py
├── results/                       # Test run results (generated)
└── logs/                          # Test run logs (generated)
```

## Quick Start

### Run All Tests

```bash
# Using Python runner (recommended)
python3 runners/test_runner.py -v

# Using Bash runner
bash runners/test-runner.sh
```

### Run Filtered Tests

```bash
# By category
python3 runners/test_runner.py --category=daemon-lifecycle

# By priority
python3 runners/test_runner.py --priority=critical

# By tags
python3 runners/test_runner.py --tags=core,smoke

# Combined
python3 runners/test_runner.py --category=recovery --priority=high -v
```

### Run with Options

```bash
# Parallel execution
python3 runners/test_runner.py --parallel

# Stop on first failure
python3 runners/test_runner.py --fail-fast

# Dry run (show what would run)
bash runners/test-runner.sh --dry-run
```

## Test Case Format

Test cases are defined in YAML format. Each test case must include:

```yaml
id: "TAT-XXXX"              # Unique identifier (TAT = Tri-Agent Test)
name: "Test Name"           # Human-readable name
category: "category-name"   # Test category
priority: "critical|high|medium|low"

setup:                      # Pre-test setup
  environment: {}           # Environment variables
  fixtures: []              # Fixture files to load
  commands: []              # Setup commands
  mocks: []                 # Mock configurations

input:                      # Test input
  type: "command|event|api|task"
  command: {}               # Command specification
  event: {}                 # Event specification
  api: {}                   # API call specification

expected:                   # Expected results
  exit_code: 0              # Expected exit code
  stdout: {}                # Stdout validation
  stderr: {}                # Stderr validation
  state: {}                 # State validation
  events: []                # Event validation

teardown:                   # Post-test cleanup
  commands: []              # Cleanup commands
  cleanup_files: []         # Files to delete

retry:                      # Retry configuration
  max_attempts: 3
  backoff:
    type: "exponential"
    base_seconds: 2
```

## Test Categories

| Category | Description | Priority |
|----------|-------------|----------|
| `daemon-lifecycle` | Daemon startup, shutdown, health | Critical |
| `agent-coordination` | Task assignment, distribution | Critical |
| `verification-flow` | Two-key rule, approvals | Critical |
| `recovery` | Crash recovery, checkpoint restore | Critical |
| `concurrency` | 9-agent parallelism | Critical |
| `state-management` | Checkpoints, persistence | High |
| `budget-tracking` | Token limits, cost control | High |
| `session-management` | Session handling | Medium |
| `integration` | End-to-end flows | Medium |

## Validation Types

### Exit Code
```yaml
expected:
  exit_code: 0
```

### Output Patterns
```yaml
expected:
  stdout:
    contains:
      - "expected string"
    not_contains:
      - "error"
    regex: "pattern.*match"
    empty: false
```

### State Validation
```yaml
expected:
  state:
    database:
      - query: "SELECT COUNT(*) FROM tasks"
        expected: { "count": 5 }
        comparison: "exact"
    files:
      - path: "/path/to/file"
        exists: true
        content:
          contains: "expected"
    processes:
      - name: "daemon"
        running: true
```

### Event Validation
```yaml
expected:
  events:
    - type: "event.name"
      count: 1
      order: 1
      payload:
        json_path: "$.field"
        value: "expected"
```

## Retry Logic

Tests support automatic retry with configurable backoff:

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
    - "state_mismatch"
  reset_state: true
```

### Backoff Calculation

- **Fixed**: `wait = base_seconds`
- **Linear**: `wait = base_seconds * attempt`
- **Exponential**: `wait = min(base_seconds ^ attempt, max_seconds)`

## Pass/Fail Criteria

See [PASS_FAIL_CRITERIA.md](./PASS_FAIL_CRITERIA.md) for detailed criteria.

### Key Requirements

1. **Exit Code**: Must match expected value
2. **Output**: All `contains` patterns found, no `not_contains` patterns
3. **State**: Database queries and file checks pass
4. **Metrics**: Duration and resource usage within limits
5. **Events**: Required events fired in correct order

### Tri-Agent Mandatory Requirements

- **9 Concurrent Agents**: 3 Claude + 3 Codex + 3 Gemini
- **Two-Key Rule**: Different AI models for implementation and verification
- **21 Invocations**: Per complete task (7 per phase x 3 phases)

## Reports

Test runs generate reports in `results/`:

```json
{
  "run_id": "20260104_120000",
  "summary": {
    "total": 50,
    "passed": 48,
    "failed": 1,
    "skipped": 1,
    "pass_rate": 96.0
  },
  "results": [...]
}
```

### Report Formats

- **JSON**: Machine-readable results
- **JUnit**: CI/CD integration
- **HTML**: Human-readable dashboard
- **Console**: Real-time output

## Adding New Tests

1. Create YAML file in appropriate category folder
2. Use naming convention: `TAT-XXXX-descriptive-name.yaml`
3. Follow the test case schema
4. Add required fixtures
5. Run validation: `python3 runners/test_runner.py --dry-run`

## CI/CD Integration

```yaml
# GitHub Actions example
test-daemon:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - name: Run tri-agent tests
      run: |
        cd ~/.claude/tests/tri-agent
        python3 runners/test_runner.py \
          --priority=critical \
          --fail-fast \
          -v
```

## Troubleshooting

### Test Discovery Issues
```bash
# Check for valid YAML syntax
python3 -c "import yaml; yaml.safe_load(open('cases/example.yaml'))"
```

### Timeout Issues
```bash
# Increase timeouts
python3 runners/test_runner.py --timeout=600
```

### State Issues
```bash
# Reset test environment
bash runners/scripts/reset-test-environment.sh
```
