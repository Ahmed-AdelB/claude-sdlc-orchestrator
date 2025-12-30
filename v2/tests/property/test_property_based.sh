#!/bin/bash
#===============================================================================
# test_property_based.sh - Property-based tests with randomized inputs
#===============================================================================
# Tests that invariants and properties hold across many randomized inputs.
# Inspired by QuickCheck/Hypothesis-style property-based testing.
#===============================================================================

set -euo pipefail

# Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(dirname "$(dirname "$SCRIPT_DIR")")}"
LIB_DIR="${PROJECT_ROOT}/lib"

# Test counters
TESTS_PASSED=${TESTS_PASSED:-0}
TESTS_FAILED=${TESTS_FAILED:-0}
PROPERTY_ITERATIONS=${PROPERTY_ITERATIONS:-50}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

pass() {
    ((TESTS_PASSED++)) || true
    echo -e "  ${GREEN}[PASS]${RESET} $1"
}

fail() {
    ((TESTS_FAILED++)) || true
    echo -e "  ${RED}[FAIL]${RESET} $1"
}

skip() {
    echo -e "  ${YELLOW}[SKIP]${RESET} $1"
}

#===============================================================================
# Setup test environment
#===============================================================================

TEST_STATE_DIR=$(mktemp -d)
TEST_LOG_DIR=$(mktemp -d)
export STATE_DIR="$TEST_STATE_DIR"
export LOG_DIR="$TEST_LOG_DIR"
export TRACE_ID="property-$$"

mkdir -p "$STATE_DIR" "$LOG_DIR"

cleanup() {
    rm -rf "$TEST_STATE_DIR" "$TEST_LOG_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# Source dependencies
source "${LIB_DIR}/common.sh"

#===============================================================================
# Random Value Generators
#===============================================================================

# Generate random integer in range
random_int() {
    local min="${1:-0}"
    local max="${2:-1000}"
    echo $(( (RANDOM % (max - min + 1)) + min ))
}

# Generate random alphanumeric string
random_alphanum() {
    local length="${1:-16}"
    cat /dev/urandom 2>/dev/null | tr -dc 'a-zA-Z0-9' | head -c "$length" || {
        # Fallback for systems without /dev/urandom
        local str=""
        local chars="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        for ((i=0; i<length; i++)); do
            str+="${chars:RANDOM%${#chars}:1}"
        done
        echo "$str"
    }
}

# Generate random API key lookalike
random_api_key() {
    local type="${1:-openai}"
    case "$type" in
        openai) echo "sk-$(random_alphanum 48)" ;;
        anthropic) echo "sk-ant-$(random_alphanum 32)" ;;
        github) echo "ghp_$(random_alphanum 36)" ;;
        bearer) echo "Bearer $(random_alphanum 32)" ;;
    esac
}

# Generate random JSON object
random_json() {
    local num_fields="${1:-3}"
    local json="{"
    for ((i=0; i<num_fields; i++)); do
        [[ $i -gt 0 ]] && json+=","
        json+="\"$(random_alphanum 8)\": \"$(random_alphanum 16)\""
    done
    json+="}"
    echo "$json"
}

#===============================================================================
# Property Tests
#===============================================================================

echo ""
echo "Running property-based tests with $PROPERTY_ITERATIONS iterations..."

# Property 1: mask_secrets should never contain unmasked API keys
test_property_mask_secrets_always_masks() {
    echo "  Property: mask_secrets always masks API keys..."

    local violations=0

    for ((i=0; i<PROPERTY_ITERATIONS; i++)); do
        # Generate random API keys of different types
        local key_types=("openai" "anthropic" "github" "bearer")
        local key_type="${key_types[RANDOM % 4]}"
        local api_key
        api_key=$(random_api_key "$key_type")

        local prefix
        prefix=$(random_alphanum 10)
        local suffix
        suffix=$(random_alphanum 10)
        local input="${prefix} ${api_key} ${suffix}"

        local masked
        masked=$(mask_secrets "$input")

        # Property: The original API key should NOT appear in masked output
        if [[ "$masked" == *"$api_key"* ]]; then
            ((violations++)) || true
            echo "    Violation: API key leaked: $api_key"
        fi

        # Property: Output should contain REDACTED marker (function uses [REDACTED])
        if [[ "$masked" != *"REDACTED"* ]] && [[ "$input" != "$masked" ]]; then
            # If input was changed but doesn't contain REDACTED, that's suspicious
            ((violations++)) || true
            echo "    Violation: No REDACTED marker in: $masked"
        fi
    done

    if [[ $violations -eq 0 ]]; then
        pass "mask_secrets: Always masks API keys ($PROPERTY_ITERATIONS iterations)"
    else
        fail "mask_secrets: $violations violations found"
    fi
}

# Property 2: generate_trace_id produces unique IDs
test_property_trace_id_unique() {
    echo "  Property: generate_trace_id produces unique IDs..."

    local ids=()
    local duplicates=0

    for ((i=0; i<PROPERTY_ITERATIONS; i++)); do
        local id
        id=$(generate_trace_id "test")

        # Check for duplicates
        for existing in "${ids[@]}"; do
            if [[ "$existing" == "$id" ]]; then
                ((duplicates++)) || true
                break
            fi
        done

        ids+=("$id")
    done

    if [[ $duplicates -eq 0 ]]; then
        pass "generate_trace_id: All IDs unique ($PROPERTY_ITERATIONS iterations)"
    else
        fail "generate_trace_id: $duplicates duplicates found"
    fi
}

# Property 3: generate_trace_id always starts with prefix
test_property_trace_id_prefix() {
    echo "  Property: generate_trace_id preserves prefix..."

    local violations=0

    for ((i=0; i<PROPERTY_ITERATIONS; i++)); do
        local prefix
        prefix=$(random_alphanum 5)
        local id
        id=$(generate_trace_id "$prefix")

        if [[ "$id" != "${prefix}-"* ]]; then
            ((violations++)) || true
            echo "    Violation: ID $id doesn't start with ${prefix}-"
        fi
    done

    if [[ $violations -eq 0 ]]; then
        pass "generate_trace_id: Prefix preserved ($PROPERTY_ITERATIONS iterations)"
    else
        fail "generate_trace_id: $violations prefix violations"
    fi
}

# Property 4: epoch_ms always returns positive integer
test_property_epoch_ms_positive() {
    echo "  Property: epoch_ms returns positive integer..."

    local violations=0

    for ((i=0; i<PROPERTY_ITERATIONS; i++)); do
        local ms
        ms=$(epoch_ms)

        # Property: Should be a positive integer
        if ! [[ "$ms" =~ ^[0-9]+$ ]]; then
            ((violations++)) || true
            echo "    Violation: Not a number: $ms"
        elif [[ "$ms" -le 0 ]]; then
            ((violations++)) || true
            echo "    Violation: Not positive: $ms"
        fi
    done

    if [[ $violations -eq 0 ]]; then
        pass "epoch_ms: Always positive integer ($PROPERTY_ITERATIONS iterations)"
    else
        fail "epoch_ms: $violations violations"
    fi
}

# Property 5: epoch_ms is monotonically non-decreasing
test_property_epoch_ms_monotonic() {
    echo "  Property: epoch_ms is monotonically non-decreasing..."

    local violations=0
    local prev_ms=0

    for ((i=0; i<PROPERTY_ITERATIONS; i++)); do
        local ms
        ms=$(epoch_ms)

        if [[ "$ms" -lt "$prev_ms" ]]; then
            ((violations++)) || true
            echo "    Violation: Time went backwards: $prev_ms -> $ms"
        fi

        prev_ms="$ms"
    done

    if [[ $violations -eq 0 ]]; then
        pass "epoch_ms: Monotonically non-decreasing ($PROPERTY_ITERATIONS iterations)"
    else
        fail "epoch_ms: $violations monotonicity violations"
    fi
}

# Property 6: iso_timestamp matches ISO 8601 format
test_property_iso_timestamp_format() {
    echo "  Property: iso_timestamp matches ISO 8601..."

    local violations=0
    local iso_pattern='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}'

    for ((i=0; i<PROPERTY_ITERATIONS; i++)); do
        local ts
        ts=$(iso_timestamp)

        if ! [[ "$ts" =~ $iso_pattern ]]; then
            ((violations++)) || true
            echo "    Violation: Invalid format: $ts"
        fi
    done

    if [[ $violations -eq 0 ]]; then
        pass "iso_timestamp: Always ISO 8601 format ($PROPERTY_ITERATIONS iterations)"
    else
        fail "iso_timestamp: $violations format violations"
    fi
}

# Property 7: is_valid_json accepts all valid JSON
test_property_valid_json_accepted() {
    echo "  Property: is_valid_json accepts all valid JSON..."

    local violations=0

    for ((i=0; i<PROPERTY_ITERATIONS; i++)); do
        # Generate valid JSON
        local json
        json=$(random_json $((RANDOM % 5 + 1)))

        if ! is_valid_json "$json"; then
            ((violations++)) || true
            echo "    Violation: Valid JSON rejected: $json"
        fi
    done

    if [[ $violations -eq 0 ]]; then
        pass "is_valid_json: Accepts valid JSON ($PROPERTY_ITERATIONS iterations)"
    else
        fail "is_valid_json: $violations rejections of valid JSON"
    fi
}

# Property 8: _validate_numeric returns true iff input is non-negative integer
test_property_validate_numeric_correct() {
    echo "  Property: _validate_numeric is correct..."

    local violations=0

    for ((i=0; i<PROPERTY_ITERATIONS; i++)); do
        local num
        num=$(random_int 0 1000000)

        # Property: Should accept non-negative integers
        if ! _validate_numeric "$num"; then
            ((violations++)) || true
            echo "    Violation: Rejected valid number: $num"
        fi

        # Property: Should reject non-numeric strings
        local non_num
        non_num=$(random_alphanum 8)
        if _validate_numeric "$non_num" 2>/dev/null; then
            ((violations++)) || true
            echo "    Violation: Accepted non-number: $non_num"
        fi
    done

    if [[ $violations -eq 0 ]]; then
        pass "_validate_numeric: Correct validation ($PROPERTY_ITERATIONS iterations)"
    else
        fail "_validate_numeric: $violations incorrect validations"
    fi
}

# Property 9: parse_delegate_envelope preserves model and status
test_property_parse_envelope_preserves() {
    echo "  Property: parse_delegate_envelope preserves fields..."

    local violations=0
    local models=("claude" "gemini" "codex")
    local statuses=("success" "error" "timeout")

    for ((i=0; i<PROPERTY_ITERATIONS; i++)); do
        local model="${models[RANDOM % 3]}"
        local status="${statuses[RANDOM % 3]}"
        local decision="APPROVE"
        local confidence="0.$(random_int 1 99)"

        local json="{\"model\": \"$model\", \"status\": \"$status\", \"decision\": \"$decision\", \"confidence\": $confidence}"

        if parse_delegate_envelope "$json" 2>/dev/null; then
            if [[ "$DELEGATE_MODEL" != "$model" ]]; then
                ((violations++)) || true
                echo "    Violation: Model mismatch: expected $model, got $DELEGATE_MODEL"
            fi
            if [[ "$DELEGATE_STATUS" != "$status" ]]; then
                ((violations++)) || true
                echo "    Violation: Status mismatch: expected $status, got $DELEGATE_STATUS"
            fi
        fi
    done

    if [[ $violations -eq 0 ]]; then
        pass "parse_delegate_envelope: Preserves fields ($PROPERTY_ITERATIONS iterations)"
    else
        fail "parse_delegate_envelope: $violations field mismatches"
    fi
}

# Property 10: Idempotency - mask_secrets(mask_secrets(x)) == mask_secrets(x)
test_property_mask_secrets_idempotent() {
    echo "  Property: mask_secrets is idempotent..."

    local violations=0

    for ((i=0; i<PROPERTY_ITERATIONS; i++)); do
        local input
        input="API key: $(random_api_key openai) and $(random_api_key github)"

        local once
        once=$(mask_secrets "$input")
        local twice
        twice=$(mask_secrets "$once")

        if [[ "$once" != "$twice" ]]; then
            ((violations++)) || true
            echo "    Violation: Not idempotent"
            echo "      Once:  $once"
            echo "      Twice: $twice"
        fi
    done

    if [[ $violations -eq 0 ]]; then
        pass "mask_secrets: Idempotent ($PROPERTY_ITERATIONS iterations)"
    else
        fail "mask_secrets: $violations idempotency violations"
    fi
}

#===============================================================================
# Run Tests
#===============================================================================

test_property_mask_secrets_always_masks
test_property_trace_id_unique
test_property_trace_id_prefix
test_property_epoch_ms_positive
test_property_epoch_ms_monotonic
test_property_iso_timestamp_format
test_property_valid_json_accepted
test_property_validate_numeric_correct
test_property_parse_envelope_preserves
test_property_mask_secrets_idempotent

export TESTS_PASSED TESTS_FAILED

echo ""
echo "Property-based tests completed: $TESTS_PASSED passed, $TESTS_FAILED failed"
