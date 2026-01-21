# Tri-Agent Daemon Startup Tests

Comprehensive test suite for validating tri-agent daemon startup, lifecycle, and shutdown behavior.

## Overview

This test suite verifies:

1. **Daemon Startup** - Daemon starts correctly and initializes all components
2. **PID File Management** - PID file is created with valid process ID
3. **Heartbeat Mechanism** - Heartbeat updates at expected intervals
4. **Graceful Shutdown** - SIGTERM and SIGINT handling works correctly
5. **Restart Behavior** - Daemon can be stopped and restarted cleanly

## Test Files

### Shell-Based Tests

| File                     | Description                                       |
| ------------------------ | ------------------------------------------------- |
| `test-daemon-startup.sh` | Comprehensive shell test suite with 14 test cases |

### YAML Test Cases

| ID       | Name                | Priority | Description                                        |
| -------- | ------------------- | -------- | -------------------------------------------------- |
| TAT-D001 | Basic Startup       | Critical | Validates daemon starts and creates required files |
| TAT-D002 | PID File Validation | Critical | Validates PID file format and process existence    |
| TAT-D003 | Heartbeat Mechanism | High     | Validates heartbeat updates and ISO format         |
| TAT-D004 | Graceful Shutdown   | Critical | Validates SIGTERM and SIGINT handling              |
| TAT-D005 | Restart Behavior    | High     | Validates stop and restart cycle                   |

## Running Tests

### Run All Tests

```bash
./run-daemon-tests.sh
```

### Run Only Shell Tests

```bash
./run-daemon-tests.sh --shell-only
```

### Run Only YAML Tests

```bash
./run-daemon-tests.sh --yaml-only
```

### Run Only Critical Tests (Quick Mode)

```bash
./run-daemon-tests.sh --quick
```

### Run With Verbose Output

```bash
./run-daemon-tests.sh --verbose
```

### Run Shell Tests Directly

```bash
./test-daemon-startup.sh --verbose
```

## Test Case Details

### T-001: Daemon Starts Correctly

- Starts the daemon process
- Verifies process is running
- Validates exit code

### T-002: PID File Created

- Verifies PID file exists after startup
- Validates PID is numeric
- Confirms PID matches running process

### T-003: Heartbeat Mechanism Works

- Verifies heartbeat file is created
- Confirms heartbeat updates over time
- Validates timestamp format

### T-004: Heartbeat File Format

- Validates ISO 8601 timestamp format
- Checks timestamp is parseable

### T-005: Graceful Shutdown (SIGTERM)

- Sends SIGTERM to daemon
- Verifies daemon stops within timeout
- Checks shutdown log message

### T-006: Graceful Shutdown (SIGINT)

- Sends SIGINT to daemon
- Verifies daemon stops within timeout

### T-007: PID File Cleanup

- Verifies PID file is removed after graceful shutdown

### T-008: Restart Behavior

- Stops daemon and starts again
- Verifies new PID is different
- Confirms new instance works correctly

### T-009: State File Creation

- Verifies daemon-state.json is created
- Validates JSON format

### T-010: Log Directory Creation

- Verifies daemon-logs directory exists
- Confirms daemon.log is created

### T-011: Concurrent Startup Prevention

- Tests behavior when multiple startups attempted
- Ensures only one daemon runs

### T-012: Stale PID File Handling

- Creates stale PID file (non-existent process)
- Verifies daemon starts despite stale file

### T-013: Startup Time

- Measures startup duration
- Validates startup completes within 2 seconds

### T-014: Heartbeat Frequency

- Monitors heartbeat updates over time
- Validates update frequency

## Configuration

### Environment Variables

| Variable              | Default | Description                             |
| --------------------- | ------- | --------------------------------------- |
| `TRI_AGENT_TEST_MODE` | `false` | Enable test mode (isolated environment) |
| `TRI_AGENT_LOG_LEVEL` | `info`  | Log level for daemon                    |

### Test Timeouts

| Timeout   | Default | Description                     |
| --------- | ------- | ------------------------------- |
| Setup     | 10s     | Time allowed for test setup     |
| Execution | 60-120s | Time allowed for test execution |
| Teardown  | 15s     | Time allowed for cleanup        |

## Test Output

### Results Directory

Test results are saved to `./results/`:

- JSON reports for each test run
- Summary statistics

### Log Files

Test logs are saved with timestamp:

- `daemon-tests-YYYYMMDD_HHMMSS.log`

## Dependencies

- Bash 4.0+
- Standard Unix utilities (grep, sed, awk, kill, etc.)
- `jq` (for JSON validation)
- `bc` (for arithmetic operations)

## Related Files

| Path                                                                | Description              |
| ------------------------------------------------------------------- | ------------------------ |
| `/home/aadel/.claude/tri-agent-daemon.sh`                           | Main daemon script       |
| `/home/aadel/.claude/autonomous/lib/daemon-atomic-startup.sh`       | Atomic startup module    |
| `/home/aadel/.claude/autonomous/lib/tri-agent-graceful-shutdown.sh` | Graceful shutdown module |

## Author

Ahmed Adel Bakr Alderai
