# Tri-Agent System API Reference

## Overview

This document provides a complete API reference for the tri-agent system's library functions and CLI utilities.

## Library Functions (lib/)

### common.sh

Core utilities shared across all components.

#### `generate_trace_id(prefix)`

Generates a unique trace ID for request tracking.

**Parameters:**
- `prefix` (string, optional): Prefix for the trace ID (default: "tri")

**Returns:**
- String: Unique trace ID in format `{prefix}-{timestamp}-{random}`

**Example:**
```bash
source lib/common.sh
TRACE_ID=$(generate_trace_id "req")
# Output: req-20251228143052-a1b2c3d4
```

---

#### `epoch_ms()`

Returns current Unix timestamp in milliseconds.

**Returns:**
- Integer: Milliseconds since Unix epoch

**Example:**
```bash
start_time=$(epoch_ms)
# ... do work ...
duration=$(($(epoch_ms) - start_time))
echo "Took ${duration}ms"
```

---

#### `iso_timestamp()`

Returns current time in ISO 8601 format.

**Returns:**
- String: ISO 8601 timestamp (e.g., `2025-12-28T14:30:52+00:00`)

**Example:**
```bash
log_entry="{\"timestamp\": \"$(iso_timestamp)\", \"event\": \"start\"}"
```

---

#### `mask_secrets(input)`

Masks sensitive information (API keys, tokens) in text.

**Parameters:**
- `input` (string): Text that may contain secrets

**Returns:**
- String: Text with secrets replaced by `[MASKED:***]`

**Patterns Masked:**
- OpenAI API keys (`sk-...`)
- Anthropic API keys (`sk-ant-...`)
- GitHub tokens (`ghp_...`, `gho_...`)
- Bearer tokens
- Environment variable assignments with API keys

**Example:**
```bash
safe_log=$(mask_secrets "Key: sk-1234567890abcdefghij")
# Output: Key: [MASKED:***sk-1...]
```

---

#### `command_exists(cmd)`

Checks if a command is available in PATH.

**Parameters:**
- `cmd` (string): Command name to check

**Returns:**
- Exit code 0 if exists, 1 otherwise

**Example:**
```bash
if command_exists "jq"; then
    echo "jq is available"
fi
```

---

#### `read_config(path, default, config_file)`

Reads a value from YAML configuration.

**Parameters:**
- `path` (string): YAML path (e.g., `.models.claude.timeout_seconds`)
- `default` (string): Default value if path not found
- `config_file` (string, optional): Path to config file

**Returns:**
- String: Configuration value or default

**Example:**
```bash
timeout=$(read_config ".models.claude.timeout_seconds" "300" "$CONFIG_FILE")
```

---

#### `_validate_numeric(value)`

Validates that a value is a positive integer.

**Parameters:**
- `value` (string): Value to validate

**Returns:**
- Exit code 0 if valid, 1 otherwise

**Example:**
```bash
if _validate_numeric "$timeout"; then
    echo "Valid timeout"
fi
```

---

### state.sh

State management with locking for concurrent access.

#### `acquire_lock(name)`

Acquires an exclusive lock.

**Parameters:**
- `name` (string): Lock name

**Returns:**
- Exit code 0 on success, 1 on failure

**Example:**
```bash
if acquire_lock "config_update"; then
    # Critical section
    release_lock "config_update"
fi
```

---

#### `release_lock(name)`

Releases a previously acquired lock.

**Parameters:**
- `name` (string): Lock name

---

#### `with_lock(name, function)`

Executes a function while holding a lock.

**Parameters:**
- `name` (string): Lock name
- `function` (string): Function name to execute

**Example:**
```bash
update_counter() {
    current=$(get_state "counter")
    set_state "counter" $((current + 1))
}
with_lock "counter_lock" update_counter
```

---

#### `with_lock_timeout(name, timeout_seconds, function)`

Executes a function with a lock timeout.

**Parameters:**
- `name` (string): Lock name
- `timeout_seconds` (integer): Maximum wait time for lock
- `function` (string): Function name to execute

---

#### `set_state(key, value)`

Stores a state value.

**Parameters:**
- `key` (string): State key
- `value` (string): Value to store

---

#### `get_state(key, default)`

Retrieves a state value.

**Parameters:**
- `key` (string): State key
- `default` (string, optional): Default if key not found

**Returns:**
- String: Stored value or default

---

#### `delete_state(key)`

Removes a state value.

**Parameters:**
- `key` (string): State key to delete

---

#### `atomic_increment(key)`

Atomically increments a numeric state value.

**Parameters:**
- `key` (string): State key (must contain numeric value)

---

#### `hash_name(input)`

Creates a consistent hash of a string.

**Parameters:**
- `input` (string): String to hash

**Returns:**
- String: MD5 hash (first 8 characters)

---

### circuit-breaker.sh

Circuit breaker pattern implementation.

#### `get_breaker_state(model)`

Gets the current state of a circuit breaker.

**Parameters:**
- `model` (string): Model name (claude, gemini, codex)

**Returns:**
- String: One of `CLOSED`, `OPEN`, `HALF_OPEN`

---

#### `set_breaker_state(model, state)`

Sets the circuit breaker state.

**Parameters:**
- `model` (string): Model name
- `state` (string): New state (`CLOSED`, `OPEN`, `HALF_OPEN`)

---

#### `record_failure(model)`

Records a failure for a model.

**Parameters:**
- `model` (string): Model name

**Side Effects:**
- Increments failure count
- May transition to OPEN state if threshold reached

---

#### `record_success(model)`

Records a success for a model.

**Parameters:**
- `model` (string): Model name

**Side Effects:**
- Resets failure count
- Transitions HALF_OPEN to CLOSED

---

#### `check_circuit(model)`

Checks if a circuit is available for requests.

**Parameters:**
- `model` (string): Model name

**Returns:**
- Exit code 0 if available, 1 if circuit is open

---

#### `reset_breaker(model)`

Resets a circuit breaker to initial state.

**Parameters:**
- `model` (string): Model name

---

#### `get_failure_count(model)`

Gets the current failure count.

**Parameters:**
- `model` (string): Model name

**Returns:**
- Integer: Number of consecutive failures

---

#### `should_attempt(model)`

Determines if a request should be attempted.

**Parameters:**
- `model` (string): Model name

**Returns:**
- Exit code 0 if should attempt, 1 otherwise

---

#### `get_all_breaker_states()`

Gets all circuit breaker states as JSON.

**Returns:**
- String: JSON object with all breaker states

---

#### `get_breaker_info(model)`

Gets detailed information about a circuit breaker.

**Parameters:**
- `model` (string): Model name

**Returns:**
- String: JSON with state, failure_count, last_failure, etc.

---

### error-handler.sh

Error classification and retry logic.

#### `classify_error(error_message)`

Classifies an error message into a category.

**Parameters:**
- `error_message` (string): Error message text

**Returns:**
- String: One of `rate_limit`, `auth_error`, `timeout`, `model_unavailable`, `unknown`

---

#### `should_retry(error_type, attempt)`

Determines if a request should be retried.

**Parameters:**
- `error_type` (string): Error classification
- `attempt` (integer): Current attempt number

**Returns:**
- Exit code 0 if should retry, 1 otherwise

---

#### `calculate_backoff(attempt)`

Calculates exponential backoff delay.

**Parameters:**
- `attempt` (integer): Attempt number (1-based)

**Returns:**
- Integer: Seconds to wait before retry

**Formula:**
- `min(base * multiplier^(attempt-1) + jitter, max_backoff)`
- Default: base=5, multiplier=2, max=300

---

#### `get_fallback_model(model)`

Gets the fallback model for a given model.

**Parameters:**
- `model` (string): Current model name

**Returns:**
- String: Fallback model name or empty

---

#### `get_next_model_in_chain(model)`

Gets the next model in the fallback chain.

**Parameters:**
- `model` (string): Current model name

**Returns:**
- String: Next model name or empty if end of chain

---

#### `execute_with_retry(function, max_attempts)`

Executes a function with automatic retry.

**Parameters:**
- `function` (string): Function name to execute
- `max_attempts` (integer, optional): Maximum attempts (default: 3)

**Returns:**
- Output of the function on success
- Exit code 1 after all retries exhausted

---

#### `handle_error(model, error_type, error_message)`

Handles an error with logging and circuit breaker update.

**Parameters:**
- `model` (string): Model name
- `error_type` (string): Error classification
- `error_message` (string): Full error message

---

### logging.sh

Structured JSON logging.

#### `log(level, event, message, metadata)`

Writes a log entry.

**Parameters:**
- `level` (string): Log level (DEBUG, INFO, WARN, ERROR, FATAL)
- `event` (string): Event type identifier
- `message` (string): Human-readable message
- `metadata` (string, optional): JSON object with additional data

**Example:**
```bash
log "INFO" "REQUEST_START" "Starting request" '{"model":"claude","timeout":300}'
```

---

#### Component-specific loggers

- `log_claude(level, event, message, metadata)` - Claude-specific logging
- `log_gemini(level, event, message, metadata)` - Gemini-specific logging
- `log_codex(level, event, message, metadata)` - Codex-specific logging
- `log_router(level, event, message, metadata)` - Router-specific logging

---

### cost-tracker.sh

Usage metrics tracking.

#### `record_request(model, input_tokens, output_tokens, duration_ms, trace_id)`

Records a request for usage tracking.

**Parameters:**
- `model` (string): Model name
- `input_tokens` (integer): Number of input tokens
- `output_tokens` (integer): Number of output tokens
- `duration_ms` (integer): Request duration in milliseconds
- `trace_id` (string, optional): Trace ID for correlation

---

#### `get_usage_summary()`

Gets overall usage summary.

**Returns:**
- String: JSON with total requests, tokens, by-model breakdown

---

#### `get_daily_stats(date)`

Gets statistics for a specific date.

**Parameters:**
- `date` (string, optional): Date in YYYY-MM-DD format (default: today)

**Returns:**
- String: JSON with daily statistics

---

#### `get_model_stats(model)`

Gets statistics for a specific model.

**Parameters:**
- `model` (string): Model name

**Returns:**
- String: JSON with model-specific statistics

---

## CLI Tools (bin/)

### tri-agent-router

Routes tasks to the optimal model.

```bash
# Auto-route based on task content
tri-agent-router "Analyze this codebase"

# Force specific model
tri-agent-router --claude "Design the architecture"
tri-agent-router --gemini "Review all files"
tri-agent-router --codex "Implement the feature"

# Query all models for consensus
tri-agent-router --consensus "Critical security decision"
```

### Delegate Scripts

#### claude-delegate

Wraps Claude CLI with JSON envelope output.

```bash
# Basic usage
claude-delegate "Review this code"

# With options
claude-delegate --timeout 120 --model opus "Complex analysis"
claude-delegate --print "Show result on stderr too"

# Piped input
cat code.ts | claude-delegate "Analyze for bugs"
```

**JSON Output:**
```json
{
  "model": "claude",
  "status": "success|error",
  "decision": "APPROVE|REJECT|ABSTAIN",
  "confidence": 0.0-1.0,
  "reasoning": "...",
  "output": "...",
  "trace_id": "...",
  "duration_ms": 1234
}
```

#### gemini-delegate

Wraps Gemini CLI with JSON envelope output.

```bash
# Basic usage
gemini-delegate "Analyze this large codebase"

# With session resumption
gemini-delegate --session latest "Continue analysis"

# With additional directories
gemini-delegate --include-directories ~/other-repo "Cross-repo analysis"
```

#### codex-delegate

Wraps Codex CLI with JSON envelope output.

```bash
# Basic usage
codex-delegate "Implement authentication"

# With reasoning level
codex-delegate --reasoning xhigh "Complex debugging"

# With sandbox mode
codex-delegate --sandbox danger-full-access "Run system tests"
```

### Utility Scripts

#### health-check

Monitor system health.

```bash
health-check              # Display health status
health-check --json       # Output as JSON
health-check --daemon     # Run continuous monitoring
health-check --notify     # Enable desktop notifications
```

#### cost-tracker

View usage statistics.

```bash
cost-tracker summary           # Overall summary
cost-tracker daily             # Today's stats
cost-tracker daily 2025-12-27  # Specific date
cost-tracker model claude      # Per-model stats
cost-tracker range 2025-12-01 2025-12-28  # Date range
```

#### tri-agent-preflight

Validate system prerequisites.

```bash
tri-agent-preflight           # Quick validation
tri-agent-preflight --full    # Include API connectivity tests
tri-agent-preflight --json    # Output as JSON
tri-agent-preflight --quiet   # Silent (exit code only)
```

#### tri-agent-dashboard

Real-time TUI dashboard.

```bash
tri-agent-dashboard        # Start with auto-refresh
tri-agent-dashboard --once # Single snapshot
```

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `STATE_DIR` | State storage directory | `$HOME/.claude/autonomous/state` |
| `LOG_DIR` | Log storage directory | `$HOME/.claude/autonomous/logs` |
| `CONFIG_FILE` | Main configuration file | `config/tri-agent.yaml` |
| `TRACE_ID` | Request trace ID | Auto-generated |
| `CLAUDE_CMD` | Claude CLI command | `claude` |
| `GEMINI_CMD` | Gemini CLI command | `gemini` |
| `CODEX_CMD` | Codex CLI command | `codex` |

---

## Error Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error / Critical failure |
| 2 | Warnings only (degraded mode possible) |
| 124 | Timeout (from `timeout` command) |
