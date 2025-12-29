#!/bin/bash
# =============================================================================
# input-validator.sh - Comprehensive Input Validation Library
# =============================================================================
# Provides validation functions for all user inputs to prevent injection attacks
# =============================================================================

# Validate that input contains only alphanumeric characters and underscores
validate_identifier() {
    local input="$1"
    local field_name="${2:-identifier}"

    if [[ -z "$input" ]]; then
        log_error "Empty $field_name provided"
        return 1
    fi

    if [[ ! "$input" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ ]]; then
        log_error "Invalid $field_name: must be alphanumeric with underscores/hyphens"
        return 1
    fi

    # Max length check
    if [[ ${#input} -gt 128 ]]; then
        log_error "Invalid $field_name: exceeds maximum length of 128"
        return 1
    fi

    return 0
}

# Validate task ID format
validate_task_id() {
    local task_id="$1"

    if [[ -z "$task_id" ]]; then
        log_error "Empty task_id"
        return 1
    fi

    # Task IDs should be: prefix-timestamp-random
    if [[ ! "$task_id" =~ ^[a-zA-Z]+-[0-9]+-[a-zA-Z0-9]+$ ]]; then
        log_error "Invalid task_id format: $task_id"
        return 1
    fi

    return 0
}

# Validate worker ID format
validate_worker_id() {
    local worker_id="$1"

    if [[ -z "$worker_id" ]]; then
        log_error "Empty worker_id"
        return 1
    fi

    # Worker IDs: worker-N or worker-lane-N
    if [[ ! "$worker_id" =~ ^worker(-[a-zA-Z]+)?-[0-9]+$ ]]; then
        log_error "Invalid worker_id format: $worker_id"
        return 1
    fi

    return 0
}

# Validate task type
validate_task_type() {
    local task_type="$1"
    local valid_types="IMPLEMENT REVIEW ANALYZE TEST DOCUMENT DEPLOY SECURITY"

    if [[ -z "$task_type" ]]; then
        log_error "Empty task_type"
        return 1
    fi

    local upper_type
    upper_type=$(echo "$task_type" | tr '[:lower:]' '[:upper:]')

    if [[ ! " $valid_types " =~ " $upper_type " ]]; then
        log_error "Invalid task_type: $task_type. Must be one of: $valid_types"
        return 1
    fi

    return 0
}

# Validate priority level
validate_priority() {
    local priority="$1"
    local valid_priorities="CRITICAL HIGH MEDIUM LOW"

    if [[ -z "$priority" ]]; then
        log_error "Empty priority"
        return 1
    fi

    local upper_priority
    upper_priority=$(echo "$priority" | tr '[:lower:]' '[:upper:]')

    if [[ ! " $valid_priorities " =~ " $upper_priority " ]]; then
        log_error "Invalid priority: $priority. Must be one of: $valid_priorities"
        return 1
    fi

    return 0
}

# Validate JSON input
validate_json() {
    local json="$1"
    local field_name="${2:-json}"

    if [[ -z "$json" ]]; then
        log_error "Empty $field_name"
        return 1
    fi

    if command -v jq &>/dev/null; then
        if ! printf '%s' "$json" | jq . &>/dev/null; then
            log_error "Invalid JSON in $field_name"
            return 1
        fi
    elif command -v python3 &>/dev/null; then
        if ! python3 -c "import json; json.loads('''$json''')" 2>/dev/null; then
            log_error "Invalid JSON in $field_name"
            return 1
        fi
    fi

    return 0
}

# Validate file path (prevent path traversal)
validate_file_path() {
    local path="$1"
    local allowed_root="${2:-$AUTONOMOUS_ROOT}"

    if [[ -z "$path" ]]; then
        log_error "Empty file path"
        return 1
    fi

    # Resolve to absolute path
    local abs_path
    abs_path=$(realpath -m "$path" 2>/dev/null) || {
        log_error "Cannot resolve path: $path"
        return 1
    }

    # Check for path traversal
    if [[ "$abs_path" != "$allowed_root"* ]]; then
        log_error "Path traversal attempt detected: $path"
        return 1
    fi

    # Check for dangerous patterns
    if [[ "$path" =~ \.\. ]] || [[ "$path" =~ ^/ && "$path" != "$allowed_root"* ]]; then
        log_error "Dangerous path pattern: $path"
        return 1
    fi

    return 0
}

# Validate numeric range
validate_numeric_range() {
    local value="$1"
    local min="${2:-0}"
    local max="${3:-2147483647}"
    local field_name="${4:-value}"

    if [[ -z "$value" ]]; then
        log_error "Empty $field_name"
        return 1
    fi

    if [[ ! "$value" =~ ^-?[0-9]+$ ]]; then
        log_error "Invalid numeric $field_name: $value"
        return 1
    fi

    if [[ "$value" -lt "$min" ]] || [[ "$value" -gt "$max" ]]; then
        log_error "$field_name out of range [$min, $max]: $value"
        return 1
    fi

    return 0
}

# Export functions
export -f validate_identifier
export -f validate_task_id
export -f validate_worker_id
export -f validate_task_type
export -f validate_priority
export -f validate_json
export -f validate_file_path
export -f validate_numeric_range
