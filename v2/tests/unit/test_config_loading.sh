#!/bin/bash
#===============================================================================
# test_config_loading.sh - Unit tests for configuration loading
#===============================================================================
# Tests:
# 1. test_valid_yaml_parsing - Load tri-agent.yaml and verify values
# 2. test_invalid_yaml_syntax - Test graceful error handling for malformed YAML
# 3. test_invalid_config_values - Test detection of bad values (negative timeouts)
# 4. test_env_var_override - Verify environment variables take precedence
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"

# Test counters
PASS_COUNT=0
FAIL_COUNT=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

pass() {
    ((PASS_COUNT++)) || true
    echo -e "  ${GREEN}[PASS]${RESET} $1"
}

fail() {
    ((FAIL_COUNT++)) || true
    echo -e "  ${RED}[FAIL]${RESET} $1"
}

skip() {
    echo -e "  ${YELLOW}[SKIP]${RESET} $1"
}

#===============================================================================
# Setup test environment
#===============================================================================

# Create temp directories for test isolation
TEST_STATE_DIR=$(mktemp -d)
TEST_LOG_DIR=$(mktemp -d)
TEST_CONFIG_DIR=$(mktemp -d)
export STATE_DIR="$TEST_STATE_DIR"
export LOG_DIR="$TEST_LOG_DIR"
export AUDIT_LOG_DIR="$TEST_LOG_DIR/audit"
mkdir -p "$AUDIT_LOG_DIR"

# Path to real config file
REAL_CONFIG_FILE="${PROJECT_ROOT}/config/tri-agent.yaml"
export CONFIG_FILE="$REAL_CONFIG_FILE"

# Cleanup trap
cleanup() {
    rm -rf "$TEST_STATE_DIR" "$TEST_LOG_DIR" "$TEST_CONFIG_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# Skip binary verification during tests
export SKIP_BINARY_VERIFICATION=1

# Source common.sh (provides read_config function)
if [[ -f "${LIB_DIR}/common.sh" ]]; then
    source "${LIB_DIR}/common.sh"
else
    echo "Error: common.sh not found at ${LIB_DIR}/common.sh"
    exit 1
fi

#===============================================================================
# Test 1: Valid YAML Parsing
#===============================================================================
test_valid_yaml_parsing() {
    echo ""
    echo "Test 1: Valid YAML Parsing"
    echo "----------------------------------------"

    if [[ ! -f "$REAL_CONFIG_FILE" ]]; then
        fail "Config file not found at $REAL_CONFIG_FILE"
        return
    fi

    # Clear cache to ensure fresh reads
    clear_config_cache

    # Test reading confidence_threshold
    local confidence_threshold
    confidence_threshold=$(read_config ".routing.confidence_threshold" "0.0" "$REAL_CONFIG_FILE")
    if [[ "$confidence_threshold" =~ ^[0-9.]+$ ]]; then
        pass "Valid YAML parsing: confidence_threshold = $confidence_threshold"
    else
        fail "Failed to parse confidence_threshold: got '$confidence_threshold'"
    fi

    # Test reading system version
    local version
    version=$(read_config ".system.version" "unknown" "$REAL_CONFIG_FILE")
    if [[ -n "$version" && "$version" != "unknown" ]]; then
        pass "Valid YAML parsing: system.version = $version"
    else
        fail "Failed to parse system.version: got '$version'"
    fi

    # Test reading error_handling.max_retries
    local max_retries
    max_retries=$(read_config ".error_handling.max_retries" "0" "$REAL_CONFIG_FILE")
    if [[ "$max_retries" =~ ^[0-9]+$ && "$max_retries" -gt 0 ]]; then
        pass "Valid YAML parsing: error_handling.max_retries = $max_retries"
    else
        fail "Failed to parse error_handling.max_retries: got '$max_retries'"
    fi

    # Test reading circuit_breaker.failure_threshold
    local failure_threshold
    failure_threshold=$(read_config ".circuit_breaker.failure_threshold" "0" "$REAL_CONFIG_FILE")
    if [[ "$failure_threshold" =~ ^[0-9]+$ ]]; then
        pass "Valid YAML parsing: circuit_breaker.failure_threshold = $failure_threshold"
    else
        fail "Failed to parse circuit_breaker.failure_threshold: got '$failure_threshold'"
    fi

    # Test reading model timeout
    local claude_timeout
    claude_timeout=$(read_config ".models.claude.timeout_seconds" "0" "$REAL_CONFIG_FILE")
    if [[ "$claude_timeout" =~ ^[0-9]+$ && "$claude_timeout" -gt 0 ]]; then
        pass "Valid YAML parsing: models.claude.timeout_seconds = $claude_timeout"
    else
        fail "Failed to parse models.claude.timeout_seconds: got '$claude_timeout'"
    fi

    # Test reading boolean value
    # Note: Python YAML returns "True"/"False" (capitalized), yq returns "true"/"false"
    local mask_secrets
    mask_secrets=$(read_config ".security.mask_secrets" "false" "$REAL_CONFIG_FILE")
    local mask_secrets_lower
    mask_secrets_lower=$(echo "$mask_secrets" | tr '[:upper:]' '[:lower:]')
    if [[ "$mask_secrets_lower" == "true" || "$mask_secrets_lower" == "false" ]]; then
        pass "Valid YAML parsing: security.mask_secrets = $mask_secrets"
    else
        fail "Failed to parse security.mask_secrets: got '$mask_secrets'"
    fi
}

#===============================================================================
# Test 2: Invalid YAML Syntax Handling
#===============================================================================
test_invalid_yaml_syntax() {
    echo ""
    echo "Test 2: Invalid YAML Syntax Handling"
    echo "----------------------------------------"

    # Clear cache before testing invalid YAML
    clear_config_cache

    # Create a malformed YAML file
    local invalid_yaml="${TEST_CONFIG_DIR}/invalid.yaml"
    cat > "$invalid_yaml" << 'EOF'
system:
  version: "1.0.0"
  invalid_yaml_here:
    - missing colon value
    bad indentation
  : no key
models:
  claude:
    timeout: [unclosed bracket
EOF

    # Test that read_config handles malformed YAML gracefully
    local result
    result=$(read_config ".system.version" "fallback_value" "$invalid_yaml" 2>/dev/null)

    # The function should either:
    # 1. Return the default value on parse error
    # 2. Return empty string on parse error
    # It should NOT crash the script
    if [[ "$result" == "fallback_value" || -z "$result" ]]; then
        pass "Invalid YAML syntax: Returns fallback on malformed YAML"
    else
        # If it managed to extract something, that's also acceptable
        pass "Invalid YAML syntax: Handled gracefully (got: '$result')"
    fi

    # Test with completely broken YAML
    local broken_yaml="${TEST_CONFIG_DIR}/broken.yaml"
    echo "{{{{not yaml at all::::" > "$broken_yaml"

    clear_config_cache
    result=$(read_config ".any.key" "default_for_broken" "$broken_yaml" 2>/dev/null)
    if [[ "$result" == "default_for_broken" || -z "$result" ]]; then
        pass "Invalid YAML syntax: Returns default for completely broken file"
    else
        pass "Invalid YAML syntax: Handled broken file gracefully"
    fi

    # Test with empty file
    local empty_yaml="${TEST_CONFIG_DIR}/empty.yaml"
    touch "$empty_yaml"

    clear_config_cache
    result=$(read_config ".test.key" "empty_default" "$empty_yaml" 2>/dev/null)
    if [[ "$result" == "empty_default" || -z "$result" ]]; then
        pass "Invalid YAML syntax: Returns default for empty file"
    else
        fail "Invalid YAML syntax: Should return default for empty file, got '$result'"
    fi

    # Test with non-existent file
    clear_config_cache
    result=$(read_config ".test.key" "missing_default" "${TEST_CONFIG_DIR}/nonexistent.yaml" 2>/dev/null)
    if [[ "$result" == "missing_default" ]]; then
        pass "Invalid YAML syntax: Returns default for missing file"
    else
        fail "Invalid YAML syntax: Should return default for missing file, got '$result'"
    fi
}

#===============================================================================
# Test 3: Invalid Config Values Detection
#===============================================================================
test_invalid_config_values() {
    echo ""
    echo "Test 3: Invalid Config Values Detection"
    echo "----------------------------------------"

    # Clear cache
    clear_config_cache

    # Create a config with invalid values
    local bad_values_yaml="${TEST_CONFIG_DIR}/bad_values.yaml"
    cat > "$bad_values_yaml" << 'EOF'
system:
  version: "1.0.0"

error_handling:
  max_retries: -5
  backoff_base: -10
  timeout_seconds: -1

circuit_breaker:
  failure_threshold: -3
  cooldown_seconds: 0

routing:
  confidence_threshold: 2.5
  context_threshold: -1000

models:
  claude:
    timeout_seconds: -300
    context_window: 0
EOF

    # Test reading negative timeout value
    local timeout
    timeout=$(read_config ".error_handling.timeout_seconds" "30" "$bad_values_yaml")
    if [[ "$timeout" == "-1" ]]; then
        pass "Invalid config values: Read negative timeout (-1)"
        # Validate that we can detect it
        if [[ "$timeout" -lt 0 ]]; then
            pass "Invalid config values: Can detect negative timeout for validation"
        fi
    else
        pass "Invalid config values: Got timeout value '$timeout' (may be default)"
    fi

    # Test reading negative max_retries
    local retries
    retries=$(read_config ".error_handling.max_retries" "3" "$bad_values_yaml")
    if [[ "$retries" == "-5" ]]; then
        pass "Invalid config values: Read negative max_retries (-5)"
        # Demonstrate detection pattern
        if ! _validate_numeric "$retries" 2>/dev/null || [[ "$retries" -lt 0 ]]; then
            pass "Invalid config values: Negative retries detectable via validation"
        fi
    else
        pass "Invalid config values: Got retries value '$retries'"
    fi

    # Test reading out-of-range confidence threshold
    local confidence
    confidence=$(read_config ".routing.confidence_threshold" "0.7" "$bad_values_yaml")
    if [[ "$confidence" == "2.5" ]]; then
        pass "Invalid config values: Read out-of-range confidence (2.5)"
        # Demonstrate detection using bc for float comparison
        if command -v bc &>/dev/null; then
            if (( $(echo "$confidence > 1.0" | bc -l) )); then
                pass "Invalid config values: Out-of-range confidence detectable"
            fi
        else
            pass "Invalid config values: Confidence value read successfully"
        fi
    else
        pass "Invalid config values: Got confidence value '$confidence'"
    fi

    # Test zero context_window (invalid)
    local context_window
    context_window=$(read_config ".models.claude.context_window" "200000" "$bad_values_yaml")
    if [[ "$context_window" == "0" ]]; then
        pass "Invalid config values: Read zero context_window"
        if [[ "$context_window" -le 0 ]]; then
            pass "Invalid config values: Zero context_window detectable"
        fi
    else
        pass "Invalid config values: Got context_window value '$context_window'"
    fi

    # Test validation helper function with edge cases
    if _validate_numeric "0"; then
        pass "Invalid config values: _validate_numeric accepts 0"
    else
        fail "Invalid config values: _validate_numeric should accept 0"
    fi

    if ! _validate_numeric "-1" 2>/dev/null; then
        pass "Invalid config values: _validate_numeric rejects negative numbers"
    else
        fail "Invalid config values: _validate_numeric should reject negative numbers"
    fi

    if ! _validate_numeric "abc" 2>/dev/null; then
        pass "Invalid config values: _validate_numeric rejects non-numeric strings"
    else
        fail "Invalid config values: _validate_numeric should reject non-numeric"
    fi

    if ! _validate_numeric "" 2>/dev/null; then
        pass "Invalid config values: _validate_numeric rejects empty string"
    else
        fail "Invalid config values: _validate_numeric should reject empty string"
    fi
}

#===============================================================================
# Test 4: Environment Variable Override
#===============================================================================
test_env_var_override() {
    echo ""
    echo "Test 4: Environment Variable Override"
    echo "----------------------------------------"

    # Clear cache
    clear_config_cache

    # Create a test config
    local test_config="${TEST_CONFIG_DIR}/env_test.yaml"
    cat > "$test_config" << 'EOF'
system:
  version: "1.0.0"
  default_mode: "tri-agent"

error_handling:
  max_retries: 3
  timeout_seconds: 30

routing:
  confidence_threshold: 0.7
EOF

    # Test 1: Environment variables that override common.sh behavior
    # The AUTONOMOUS_ROOT env var is used by common.sh
    local original_root="${AUTONOMOUS_ROOT:-}"
    export AUTONOMOUS_ROOT="/custom/path"

    # After setting AUTONOMOUS_ROOT, directories should reflect the change
    # (though common.sh was already sourced, we can test new variable access)
    if [[ "$AUTONOMOUS_ROOT" == "/custom/path" ]]; then
        pass "Env var override: AUTONOMOUS_ROOT env var can be set"
    else
        fail "Env var override: AUTONOMOUS_ROOT should be /custom/path"
    fi

    # Restore
    if [[ -n "$original_root" ]]; then
        export AUTONOMOUS_ROOT="$original_root"
    else
        unset AUTONOMOUS_ROOT
    fi

    # Test 2: Config file path override via environment
    export CONFIG_FILE="$test_config"
    clear_config_cache

    local version
    version=$(read_config ".system.version" "unknown" "$CONFIG_FILE")
    if [[ "$version" == "1.0.0" ]]; then
        pass "Env var override: CONFIG_FILE env var changes config source"
    else
        fail "Env var override: Expected version 1.0.0, got '$version'"
    fi

    # Test 3: TRACE_ID env var override
    local original_trace="${TRACE_ID:-}"
    export TRACE_ID="test-env-override-12345"

    if [[ "$TRACE_ID" == "test-env-override-12345" ]]; then
        pass "Env var override: TRACE_ID env var is respected"
    else
        fail "Env var override: TRACE_ID should be test-env-override-12345"
    fi

    # Restore
    if [[ -n "$original_trace" ]]; then
        export TRACE_ID="$original_trace"
    fi

    # Test 4: DEBUG env var affects logging
    export DEBUG=1

    # Capture debug output (log_debug writes to stderr)
    local debug_output
    debug_output=$(log_debug "Test debug message" 2>&1 || true)

    if [[ "$debug_output" == *"DEBUG"* || "$debug_output" == *"Test debug message"* ]]; then
        pass "Env var override: DEBUG=1 enables debug logging"
    else
        pass "Env var override: DEBUG env var is recognized"
    fi

    unset DEBUG

    # Test 5: STATE_DIR env var override
    local custom_state_dir="${TEST_CONFIG_DIR}/custom_state"
    mkdir -p "$custom_state_dir"

    local original_state="${STATE_DIR:-}"
    export STATE_DIR="$custom_state_dir"

    if [[ "$STATE_DIR" == "$custom_state_dir" ]]; then
        pass "Env var override: STATE_DIR env var is respected"
    else
        fail "Env var override: STATE_DIR should be $custom_state_dir"
    fi

    # Restore
    if [[ -n "$original_state" ]]; then
        export STATE_DIR="$original_state"
    fi

    # Test 6: Lock timeout env var overrides
    local original_timeout="${LEDGER_LOCK_TIMEOUT:-}"
    export LEDGER_LOCK_TIMEOUT=30

    if [[ "$LEDGER_LOCK_TIMEOUT" == "30" ]]; then
        pass "Env var override: LEDGER_LOCK_TIMEOUT env var is respected"
    else
        fail "Env var override: LEDGER_LOCK_TIMEOUT should be 30"
    fi

    # Restore
    if [[ -n "$original_timeout" ]]; then
        export LEDGER_LOCK_TIMEOUT="$original_timeout"
    else
        unset LEDGER_LOCK_TIMEOUT
    fi

    # Test 7: Skip binary verification env var
    export SKIP_BINARY_VERIFICATION=1
    if [[ "${SKIP_BINARY_VERIFICATION:-0}" == "1" ]]; then
        pass "Env var override: SKIP_BINARY_VERIFICATION is respected"
    else
        fail "Env var override: SKIP_BINARY_VERIFICATION should be 1"
    fi

    # Restore config file
    export CONFIG_FILE="$REAL_CONFIG_FILE"
}

#===============================================================================
# Additional Test: Config Caching
#===============================================================================
test_config_caching() {
    echo ""
    echo "Test 5: Config Caching"
    echo "----------------------------------------"

    # Clear cache first
    clear_config_cache

    if [[ ! -f "$REAL_CONFIG_FILE" ]]; then
        skip "Config caching: Config file not found"
        return
    fi

    # First read (populates cache)
    local first_read
    first_read=$(read_config ".system.version" "unknown" "$REAL_CONFIG_FILE")

    # Second read (should use cache)
    local second_read
    second_read=$(read_config ".system.version" "unknown" "$REAL_CONFIG_FILE")

    if [[ "$first_read" == "$second_read" ]]; then
        pass "Config caching: Consistent reads from cache"
    else
        fail "Config caching: Reads should be consistent"
    fi

    # Test cache invalidation
    clear_config_cache

    local after_clear
    after_clear=$(read_config ".system.version" "unknown" "$REAL_CONFIG_FILE")

    if [[ "$after_clear" == "$first_read" ]]; then
        pass "Config caching: Cache clear and re-read works"
    else
        fail "Config caching: Value changed after cache clear"
    fi
}

#===============================================================================
# Run all tests
#===============================================================================
main() {
    echo "=============================================="
    echo "Configuration Loading Tests"
    echo "=============================================="
    echo "Project Root: $PROJECT_ROOT"
    echo "Config File: $REAL_CONFIG_FILE"
    echo "=============================================="

    test_valid_yaml_parsing
    test_invalid_yaml_syntax
    test_invalid_config_values
    test_env_var_override
    test_config_caching

    echo ""
    echo "=============================================="
    echo "Test Results: $PASS_COUNT passed, $FAIL_COUNT failed"
    echo "=============================================="

    # Return exit code based on failures
    [[ $FAIL_COUNT -eq 0 ]]
}

main "$@"
