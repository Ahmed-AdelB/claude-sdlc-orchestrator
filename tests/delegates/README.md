# Tri-Agent Delegate Script Tests

Comprehensive test suite for the tri-agent delegate scripts (`claude-delegate`, `codex-delegate`, `gemini-delegate`).

## Test Coverage

The tests verify:

1. **CLI Invocation Patterns**
   - `--help` shows usage information
   - `--timeout` option handling
   - `--model` option handling
   - Delegate-specific options (e.g., `--reasoning` for codex, `--session` for gemini)

2. **Error Handling**
   - Missing prompt returns JSON error with status="error"
   - Missing CLI returns appropriate error message
   - Rate limit errors are handled gracefully
   - Auth errors are handled gracefully
   - Timeout errors return correct exit code (124)

3. **Timeout Behavior**
   - Timeout option is documented
   - Invalid timeout values are handled gracefully
   - Maximum timeout is enforced

4. **Return Code Handling**
   - `--help` returns exit code 0
   - Missing prompt returns exit code 1
   - Errors return exit code 1
   - Circuit breaker open returns exit code 126

5. **JSON Envelope Validation**
   - Required fields: model, status, decision, confidence, reasoning, output, trace_id, duration_ms
   - Decision values: APPROVE, REJECT, ABSTAIN
   - Confidence range: 0.0 to 1.0
   - Model field matches delegate name

6. **Security Features**
   - Secret masking in logs
   - Input sanitization
   - Temp file cleanup

## Running Tests

### Quick Validation

```bash
./run_tests.sh --quick
```

### All Tests

```bash
./run_tests.sh
```

### Specific Test Frameworks

```bash
# BATS tests only
./run_tests.sh --bats

# pytest tests only
./run_tests.sh --pytest

# Standalone shell tests only
./run_tests.sh --standalone
```

### Test Different Delegate Versions

```bash
# Test v2 delegates (default)
./run_tests.sh --v2

# Test autonomous delegates
./run_tests.sh --autonomous

# Test custom directory
TEST_BIN_DIR=/path/to/bin ./run_tests.sh
```

### Debug Mode

```bash
DEBUG=1 ./run_tests.sh --standalone
```

## Test Files

| File                           | Description                                       |
| ------------------------------ | ------------------------------------------------- |
| `test_delegates.bats`          | BATS (Bash Automated Testing System) tests        |
| `test_delegates.py`            | pytest tests for Python-testable components       |
| `test_delegates_standalone.sh` | Standalone shell tests (no external dependencies) |
| `test_helpers.bash`            | Shared test utilities and helpers                 |
| `run_tests.sh`                 | Test runner script                                |
| `requirements.txt`             | Python dependencies for pytest                    |

## Dependencies

### Required

- bash 4.0+
- jq (for JSON processing)

### Optional

- **BATS** - For running `.bats` tests

  ```bash
  npm install -g bats
  # Or on Ubuntu/Debian:
  sudo apt-get install bats
  ```

- **pytest** - For running Python tests
  ```bash
  pip install -r requirements.txt
  ```

## Test Structure

```
~/.claude/tests/delegates/
├── README.md                     # This file
├── requirements.txt              # Python dependencies
├── run_tests.sh                  # Test runner
├── test_delegates.bats           # BATS tests
├── test_delegates.py             # pytest tests
├── test_delegates_standalone.sh  # Standalone shell tests
└── test_helpers.bash             # Shared helpers
```

## Writing New Tests

### BATS Test Example

```bash
@test "delegate: feature description" {
    run "${BIN_DIR}/delegate-name" --option "value"
    [ "$status" -eq 0 ]
    [[ "$output" == *"expected"* ]]
}
```

### Standalone Shell Test Example

```bash
test_feature() {
    local result
    result=$(run_delegate "delegate-name" "--option" "value")
    parse_delegate_result "$result"

    assert_exit_code "0" "$DELEGATE_EXIT_CODE" "Feature works"
    assert_contains "$DELEGATE_OUTPUT" "expected" "Output contains expected"
}
```

### pytest Test Example

```python
def test_feature(self):
    """Test feature description."""
    exit_code, stdout, stderr = run_delegate(
        "delegate-name",
        ["--option", "value"]
    )
    assert exit_code == 0
    assert "expected" in stdout
```

## Mock Environment

For tests that need to avoid actual CLI calls, use the mock environment helpers:

```bash
# Create mock CLIs
mock_dir=$(create_mock_environment)

# Run delegate with mock
run_delegate_with_mock "claude-delegate" "$mock_dir" "test prompt"
```

## CI/CD Integration

The tests are designed to work in CI/CD pipelines:

```yaml
# GitHub Actions example
- name: Run delegate tests
  run: |
    cd ~/.claude/tests/delegates
    ./run_tests.sh --quick
```

Exit codes:

- `0` - All tests passed
- `1` - One or more tests failed

---

Author: Ahmed Adel Bakr Alderai
