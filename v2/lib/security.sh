#!/bin/bash
#===============================================================================
# security.sh - Security utilities for tri-agent system
#===============================================================================
# Provides:
# - Input validation and sanitization
# - Secret detection
# - Path traversal prevention
# - Command injection prevention
# - Secure file operations
#===============================================================================

# Security configuration
SECURITY_LOG="${LOG_DIR:-/tmp}/security.log"
MAX_INPUT_LENGTH="${MAX_INPUT_LENGTH:-100000}"
ALLOWED_CHARS_PATTERN='[a-zA-Z0-9_\-\.\s\/\:\,\"\{\}\[\]\=\+]'

# SEC-009C: Resource limits to prevent DoS via unbounded JSON parsing
# MAX_JSON_SIZE_BYTES: General JSON size limit (default 1MB)
# MAX_TASK_SIZE_BYTES: Task-specific payload limit (default 100KB) - more restrictive
readonly MAX_JSON_SIZE_BYTES="${MAX_JSON_SIZE_BYTES:-1048576}"   # 1MB = 1048576 bytes
readonly MAX_TASK_SIZE_BYTES="${MAX_TASK_SIZE_BYTES:-102400}"    # 100KB task payload limit
readonly MAX_JSON_DEPTH="${MAX_JSON_DEPTH:-20}"                  # Maximum nesting depth
readonly MAX_ARRAY_ITEMS="${MAX_ARRAY_ITEMS:-1000}"              # Maximum array elements

# Dangerous patterns for detection (using grep -E compatible patterns)
declare -a DANGEROUS_PATTERNS=(
    # Command injection
    ';[[:space:]]*rm[[:space:]]'
    '\|[[:space:]]*rm[[:space:]]'
    '\$\(.*rm.*\)'
    '\`.*rm.*\`'
    '>[[:space:]]*/dev/sd'
    'mkfs\.'
    'dd[[:space:]]+if=.*of=/'
    # Path traversal
    '\.\./\.\.'
    '\.\./etc/'
    '\.\./passwd'
    # SQL injection patterns
    "OR[[:space:]]+'1'[[:space:]]*=[[:space:]]*'1"
    ';[[:space:]]*DROP[[:space:]]+TABLE'
    ';[[:space:]]*DELETE[[:space:]]+FROM'
    # Shell metacharacters
    '\$\{.*\}'
)

# Secret patterns for detection (using grep -E compatible patterns)
declare -a SECRET_PATTERNS=(
    # API Keys
    'sk-[a-zA-Z0-9]{48}'                           # OpenAI
    'sk-ant-[a-zA-Z0-9-]{20,}'                     # Anthropic
    'AIza[0-9A-Za-z_-]{35}'                        # Google API
    'ghp_[a-zA-Z0-9]{36}'                          # GitHub PAT
    'gho_[a-zA-Z0-9]{36}'                          # GitHub OAuth
    'xox[baprs]-[0-9a-zA-Z]{10,}'                  # Slack tokens
    # AWS
    'AKIA[0-9A-Z]{16}'                             # AWS Access Key
    # Passwords/secrets in config
    'password[[:space:]]*[=:][[:space:]]*["\x27]'
    'secret[[:space:]]*[=:][[:space:]]*["\x27]'
    'api[_-]?key[[:space:]]*[=:][[:space:]]*["\x27]'
    # Private keys
    'BEGIN.*PRIVATE.*KEY'
)

# Initialize security logging
init_security_log() {
    local log_dir
    log_dir=$(dirname "$SECURITY_LOG")
    mkdir -p "$log_dir"
    touch "$SECURITY_LOG"
    chmod 600 "$SECURITY_LOG"
}

# Log security event
log_security_event() {
    local event_type="$1"
    local message="$2"
    local severity="${3:-INFO}"

    init_security_log

    local timestamp
    timestamp=$(date -Iseconds)
    local trace_id="${TRACE_ID:-unknown}"

    echo "{\"timestamp\": \"$timestamp\", \"severity\": \"$severity\", \"type\": \"$event_type\", \"message\": \"$message\", \"trace_id\": \"$trace_id\"}" >> "$SECURITY_LOG"
}

# Validate input length
# Usage: validate_input_length "input" [max_length]
validate_input_length() {
    local input="$1"
    local max_length="${2:-$MAX_INPUT_LENGTH}"

    local length=${#input}

    if [[ $length -gt $max_length ]]; then
        log_security_event "INPUT_TOO_LONG" "Input length $length exceeds max $max_length" "WARN"
        return 1
    fi

    return 0
}

# Sanitize input - remove dangerous characters
# Usage: sanitize_input "input"
sanitize_input() {
    local input="$1"

    # Remove null bytes
    input="${input//$'\x00'/}"

    # Remove control characters except newline and tab
    input=$(echo "$input" | tr -d '\000-\010\013-\037')

    # Escape shell metacharacters
    input="${input//\\/\\\\}"
    input="${input//\$/\\\$}"
    input="${input//\`/\\\`}"
    input="${input//\"/\\\"}"

    echo "$input"
}

# Check for dangerous patterns
# Usage: check_dangerous_patterns "input"
# Returns: 0 if safe, 1 if dangerous
check_dangerous_patterns() {
    local input="$1"

    for pattern in "${DANGEROUS_PATTERNS[@]}"; do
        if echo "$input" | grep -qiE "$pattern"; then
            log_security_event "DANGEROUS_PATTERN" "Detected pattern: $pattern" "CRITICAL"
            return 1
        fi
    done

    return 0
}

# Check for secrets in input
# Usage: check_secrets "input"
# Returns: 0 if no secrets, 1 if secrets found
check_secrets() {
    local input="$1"
    local found_secrets=()

    for pattern in "${SECRET_PATTERNS[@]}"; do
        if echo "$input" | grep -qE "$pattern"; then
            found_secrets+=("$pattern")
        fi
    done

    if [[ ${#found_secrets[@]} -gt 0 ]]; then
        log_security_event "SECRET_DETECTED" "Found ${#found_secrets[@]} potential secrets" "CRITICAL"
        return 1
    fi

    return 0
}

# Redact secrets from text
# Usage: redact_secrets "text"
redact_secrets() {
    local text="$1"

    # Redact API keys
    text=$(echo "$text" | sed -E 's/sk-[a-zA-Z0-9]{48}/sk-***REDACTED***/g')
    text=$(echo "$text" | sed -E 's/sk-ant-[a-zA-Z0-9\-]{20,}/sk-ant-***REDACTED***/g')
    text=$(echo "$text" | sed -E 's/AIza[0-9A-Za-z\-_]{35}/AIza***REDACTED***/g')
    text=$(echo "$text" | sed -E 's/ghp_[a-zA-Z0-9]{36}/ghp_***REDACTED***/g')
    text=$(echo "$text" | sed -E 's/gho_[a-zA-Z0-9]{36}/gho_***REDACTED***/g')
    text=$(echo "$text" | sed -E 's/AKIA[0-9A-Z]{16}/AKIA***REDACTED***/g')

    # Redact password-like values
    text=$(echo "$text" | sed -E 's/(password\s*[=:]\s*["\x27])[^"\x27]+/\1***REDACTED***/gi')
    text=$(echo "$text" | sed -E 's/(secret\s*[=:]\s*["\x27])[^"\x27]+/\1***REDACTED***/gi')
    text=$(echo "$text" | sed -E 's/(api[_-]?key\s*[=:]\s*["\x27])[^"\x27]+/\1***REDACTED***/gi')

    echo "$text"
}

# Validate file path - prevent path traversal
# Usage: validate_path "path" "base_dir"
validate_path() {
    local path="$1"
    local base_dir="${2:-$(pwd)}"

    # Resolve to absolute path
    local resolved_path
    resolved_path=$(realpath -m "$path" 2>/dev/null || echo "")

    if [[ -z "$resolved_path" ]]; then
        log_security_event "INVALID_PATH" "Could not resolve path: $path" "WARN"
        return 1
    fi

    # Resolve base directory
    local resolved_base
    resolved_base=$(realpath -m "$base_dir" 2>/dev/null || echo "")

    # Check if path is within base directory
    if [[ "$resolved_path" != "$resolved_base"* ]]; then
        log_security_event "PATH_TRAVERSAL" "Path $path attempts to escape $base_dir" "CRITICAL"
        return 1
    fi

    # Check for symlink attacks
    if [[ -L "$path" ]]; then
        local link_target
        link_target=$(readlink -f "$path" 2>/dev/null || echo "")
        if [[ "$link_target" != "$resolved_base"* ]]; then
            log_security_event "SYMLINK_ATTACK" "Symlink $path points outside base" "CRITICAL"
            return 1
        fi
    fi

    echo "$resolved_path"
    return 0
}

# Secure file read - with validation
# Usage: secure_read "file" "base_dir"
secure_read() {
    local file="$1"
    local base_dir="${2:-$(pwd)}"

    local validated_path
    validated_path=$(validate_path "$file" "$base_dir")

    if [[ $? -ne 0 ]] || [[ -z "$validated_path" ]]; then
        return 1
    fi

    if [[ ! -f "$validated_path" ]]; then
        log_security_event "FILE_NOT_FOUND" "File not found: $validated_path" "WARN"
        return 1
    fi

    if [[ ! -r "$validated_path" ]]; then
        log_security_event "FILE_NOT_READABLE" "File not readable: $validated_path" "WARN"
        return 1
    fi

    cat "$validated_path"
}

# Secure file write - with validation
# Usage: secure_write "file" "content" "base_dir"
secure_write() {
    local file="$1"
    local content="$2"
    local base_dir="${3:-$(pwd)}"

    local validated_path
    validated_path=$(validate_path "$file" "$base_dir")

    if [[ $? -ne 0 ]] || [[ -z "$validated_path" ]]; then
        return 1
    fi

    # Ensure parent directory exists
    local parent_dir
    parent_dir=$(dirname "$validated_path")
    if [[ ! -d "$parent_dir" ]]; then
        mkdir -p "$parent_dir" || {
            log_security_event "MKDIR_FAILED" "Could not create directory: $parent_dir" "ERROR"
            return 1
        }
    fi

    # Write atomically via temp file
    local tmp_file="${validated_path}.tmp.$$"
    echo "$content" > "$tmp_file" && mv "$tmp_file" "$validated_path"

    if [[ $? -eq 0 ]]; then
        chmod 600 "$validated_path"
        return 0
    else
        rm -f "$tmp_file"
        log_security_event "WRITE_FAILED" "Could not write to: $validated_path" "ERROR"
        return 1
    fi
}

# Escape for shell command
# Usage: shell_escape "string"
shell_escape() {
    local string="$1"
    printf '%q' "$string"
}

# Escape for JSON
# Usage: json_escape "string"
json_escape() {
    local string="$1"
    # Use jq for proper JSON escaping
    echo -n "$string" | jq -Rs '.'
}

# Validate JSON input
# Usage: validate_json "json_string"
validate_json() {
    local json="$1"

    if ! echo "$json" | jq -e '.' >/dev/null 2>&1; then
        log_security_event "INVALID_JSON" "Failed to parse JSON input" "WARN"
        return 1
    fi

    # Check for suspicious keys
    local suspicious_keys=("__proto__" "constructor" "prototype")
    for key in "${suspicious_keys[@]}"; do
        if echo "$json" | jq -e ".. | objects | has(\"$key\")" 2>/dev/null | grep -q true; then
            log_security_event "SUSPICIOUS_JSON" "JSON contains suspicious key: $key" "CRITICAL"
            return 1
        fi
    done

    return 0
}

# SEC-009C: Validate JSON input size before parsing
# Usage: validate_json_size "json_string"
# Returns: 0 if within limits, 1 if exceeds limit
validate_json_size() {
    local input="$1"
    local size=${#input}

    if [[ $size -gt $MAX_TASK_SIZE_BYTES ]]; then
        log_security_event "JSON_SIZE_EXCEEDED" "SEC-009C: JSON input exceeds size limit ($size > $MAX_TASK_SIZE_BYTES bytes)" "CRITICAL"
        return 1
    fi
    return 0
}

# SEC-009C: Validate JSON nesting depth
# Usage: validate_json_depth "json_string"
# Returns: 0 if within depth limit, 1 if too deeply nested
validate_json_depth() {
    local input="$1"

    # Count maximum nesting depth by tracking brackets
    local max_depth=0
    local current_depth=0
    local in_string=false
    local prev_char=""

    # Process character by character
    local i
    for ((i=0; i<${#input}; i++)); do
        local char="${input:$i:1}"

        # Track string state (skip characters inside strings)
        if [[ "$char" == '"' ]] && [[ "$prev_char" != '\' ]]; then
            if $in_string; then
                in_string=false
            else
                in_string=true
            fi
        fi

        # Only count brackets outside of strings
        if ! $in_string; then
            if [[ "$char" == '{' ]] || [[ "$char" == '[' ]]; then
                ((current_depth++))
                if [[ $current_depth -gt $max_depth ]]; then
                    max_depth=$current_depth
                fi
            elif [[ "$char" == '}' ]] || [[ "$char" == ']' ]]; then
                ((current_depth--)) || true
            fi
        fi

        prev_char="$char"
    done

    if [[ $max_depth -gt $MAX_JSON_DEPTH ]]; then
        log_security_event "JSON_DEPTH_EXCEEDED" "SEC-009C: JSON nesting depth exceeds limit ($max_depth > $MAX_JSON_DEPTH)" "CRITICAL"
        return 1
    fi

    return 0
}

# SEC-009C: Safe JSON parsing with size and depth limits
# Usage: safe_parse_json "json_string"
# Returns: Parsed JSON on stdout, or error
safe_parse_json() {
    local input="$1"

    # Size check
    if ! validate_json_size "$input"; then
        return 1
    fi

    # Depth check
    if ! validate_json_depth "$input"; then
        return 1
    fi

    # Parse with jq if available (includes additional validation)
    if command -v jq >/dev/null 2>&1; then
        echo "$input" | jq '.' 2>/dev/null || {
            log_security_event "JSON_PARSE_FAILED" "SEC-009C: JSON parsing failed" "WARN"
            return 1
        }
    else
        # Fallback: validate JSON via Python if jq not available
        if command -v python3 >/dev/null 2>&1; then
            echo "$input" | python3 -c 'import sys,json; json.load(sys.stdin)' 2>/dev/null || {
                log_security_event "JSON_PARSE_FAILED" "SEC-009C: Invalid JSON format" "WARN"
                return 1
            }
            # Output the input since Python validation succeeded
            echo "$input"
        else
            # Last resort: basic syntax check and pass through
            if ! echo "$input" | grep -qE '^\s*[\{\[]'; then
                log_security_event "JSON_PARSE_FAILED" "SEC-009C: Input does not appear to be valid JSON" "WARN"
                return 1
            fi
            echo "$input"
        fi
    fi
}

# SEC-009C: Validate JSON against general size limit (1MB)
# Usage: validate_json_general_size "json_string"
# Returns: 0 if within limits, 1 if exceeds limit
validate_json_general_size() {
    local input="$1"
    local size=${#input}

    if [[ $size -gt $MAX_JSON_SIZE_BYTES ]]; then
        log_security_event "JSON_SIZE_EXCEEDED" "SEC-009C: JSON input exceeds general size limit ($size > $MAX_JSON_SIZE_BYTES bytes)" "CRITICAL"
        return 1
    fi
    return 0
}

# SEC-009C: Validate task payload with strict limits
# Usage: validate_task_payload "json_string"
# Returns: 0 if valid, 1 if rejected
# This function applies stricter limits for task payloads
validate_task_payload() {
    local input="$1"
    local size=${#input}

    # Check task-specific size limit (stricter than general JSON limit)
    if [[ $size -gt $MAX_TASK_SIZE_BYTES ]]; then
        log_security_event "TASK_PAYLOAD_OVERSIZED" "SEC-009C: Task payload exceeds limit ($size > $MAX_TASK_SIZE_BYTES bytes)" "CRITICAL"
        echo "error: Task payload too large ($size bytes, max $MAX_TASK_SIZE_BYTES bytes)" >&2
        return 1
    fi

    # Check nesting depth
    if ! validate_json_depth "$input"; then
        echo "error: Task payload nesting depth exceeds limit (max $MAX_JSON_DEPTH levels)" >&2
        return 1
    fi

    # Validate JSON structure
    if command -v jq >/dev/null 2>&1; then
        if ! echo "$input" | jq -e '.' >/dev/null 2>&1; then
            log_security_event "TASK_PAYLOAD_INVALID" "SEC-009C: Task payload is not valid JSON" "WARN"
            echo "error: Task payload is not valid JSON" >&2
            return 1
        fi
    fi

    return 0
}

# SEC-009C: Safe task parsing with all security validations
# Usage: safe_parse_task "json_string"
# Returns: Parsed task JSON on stdout, or error message to stderr
# This is the recommended function for parsing task payloads from external sources
safe_parse_task() {
    local input="$1"

    # Validate task payload (size, depth, structure)
    if ! validate_task_payload "$input"; then
        return 1
    fi

    # Check for dangerous patterns in the task
    if ! check_dangerous_patterns "$input"; then
        echo "error: Task payload contains dangerous patterns" >&2
        return 1
    fi

    # Check for secrets in task (should not be in task payloads)
    if ! check_secrets "$input"; then
        echo "error: Task payload appears to contain secrets" >&2
        return 1
    fi

    # Check for suspicious JSON keys (prototype pollution, etc.)
    if ! validate_json "$input"; then
        return 1
    fi

    # Parse and return the validated JSON
    if command -v jq >/dev/null 2>&1; then
        echo "$input" | jq '.'
    else
        echo "$input"
    fi
}

# SEC-009C: Validate array item count
# Usage: validate_array_items "json_array_string"
# Returns: 0 if within limits, 1 if exceeds limit
validate_array_items() {
    local input="$1"

    if command -v jq >/dev/null 2>&1; then
        local count
        count=$(echo "$input" | jq 'if type == "array" then length else 0 end' 2>/dev/null || echo "0")

        if [[ "$count" -gt "$MAX_ARRAY_ITEMS" ]]; then
            log_security_event "ARRAY_ITEMS_EXCEEDED" "SEC-009C: Array exceeds item limit ($count > $MAX_ARRAY_ITEMS items)" "CRITICAL"
            return 1
        fi

        # Also check nested arrays recursively
        local max_nested
        max_nested=$(echo "$input" | jq '[.. | arrays | length] | max // 0' 2>/dev/null || echo "0")

        if [[ "$max_nested" -gt "$MAX_ARRAY_ITEMS" ]]; then
            log_security_event "NESTED_ARRAY_ITEMS_EXCEEDED" "SEC-009C: Nested array exceeds item limit ($max_nested > $MAX_ARRAY_ITEMS items)" "CRITICAL"
            return 1
        fi
    fi

    return 0
}

# SEC-009C: Comprehensive task queue item validation
# Usage: validate_task_queue_item "json_string"
# Returns: 0 if valid, 1 if rejected
# Use this when adding items to the task queue
validate_task_queue_item() {
    local input="$1"

    # All standard task validations
    if ! validate_task_payload "$input"; then
        return 1
    fi

    # Additional check for array sizes
    if ! validate_array_items "$input"; then
        echo "error: Task contains arrays exceeding size limits" >&2
        return 1
    fi

    log_security_event "TASK_VALIDATED" "SEC-009C: Task queue item passed all validation checks" "INFO"
    return 0
}

# Generate secure random string
# Usage: secure_random [length] [type]
# type: hex, base64, alphanumeric
secure_random() {
    local length="${1:-32}"
    local type="${2:-hex}"

    case "$type" in
        hex)
            # Use od as fallback if xxd is not available
            if command -v xxd >/dev/null 2>&1; then
                head -c "$length" /dev/urandom | xxd -p | tr -d '\n' | head -c "$length"
            else
                head -c "$length" /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c "$length"
            fi
            ;;
        base64)
            head -c "$((length * 3 / 4 + 1))" /dev/urandom | base64 | tr -d '\n' | head -c "$length"
            ;;
        alphanumeric)
            head -c "$((length * 2))" /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c "$length"
            ;;
        *)
            if command -v xxd >/dev/null 2>&1; then
                head -c "$length" /dev/urandom | xxd -p | tr -d '\n' | head -c "$length"
            else
                head -c "$length" /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c "$length"
            fi
            ;;
    esac
    echo ""
}

# Hash sensitive data
# Usage: hash_sensitive "data"
hash_sensitive() {
    local data="$1"
    echo -n "$data" | sha256sum | cut -d' ' -f1
}

# Verify file integrity
# Usage: verify_integrity "file" "expected_hash"
verify_integrity() {
    local file="$1"
    local expected_hash="$2"

    if [[ ! -f "$file" ]]; then
        return 1
    fi

    local actual_hash
    actual_hash=$(sha256sum "$file" | cut -d' ' -f1)

    if [[ "$actual_hash" == "$expected_hash" ]]; then
        return 0
    else
        log_security_event "INTEGRITY_FAILURE" "File $file hash mismatch" "CRITICAL"
        return 1
    fi
}

# Create secure temp file
# Usage: secure_tempfile [prefix]
secure_tempfile() {
    local prefix="${1:-tri-agent}"
    local tmp_dir="${TMPDIR:-/tmp}"

    # Create with restrictive permissions
    local tmp_file
    tmp_file=$(mktemp "${tmp_dir}/${prefix}.XXXXXXXXXX")
    chmod 600 "$tmp_file"

    echo "$tmp_file"
}

# Comprehensive input validation
# Usage: validate_input "input" [options]
# Options: --no-secrets --no-dangerous --max-length=N
validate_input() {
    local input="$1"
    shift

    local check_secrets=true
    local check_dangerous=true
    local max_length=$MAX_INPUT_LENGTH

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-secrets)
                check_secrets=false
                ;;
            --no-dangerous)
                check_dangerous=false
                ;;
            --max-length=*)
                max_length="${1#*=}"
                ;;
        esac
        shift
    done

    # Length check
    if ! validate_input_length "$input" "$max_length"; then
        return 1
    fi

    # Dangerous patterns check
    if $check_dangerous && ! check_dangerous_patterns "$input"; then
        return 1
    fi

    # Secrets check
    if $check_secrets && ! check_secrets "$input"; then
        return 1
    fi

    return 0
}

# Get security status summary
get_security_status() {
    local event_count=0
    local critical_count=0
    local warn_count=0

    if [[ -f "$SECURITY_LOG" ]]; then
        event_count=$(wc -l < "$SECURITY_LOG")
        critical_count=$(grep -c '"severity": "CRITICAL"' "$SECURITY_LOG" 2>/dev/null || echo 0)
        warn_count=$(grep -c '"severity": "WARN"' "$SECURITY_LOG" 2>/dev/null || echo 0)
    fi

    cat << EOF
{
    "total_events": $event_count,
    "critical": $critical_count,
    "warnings": $warn_count,
    "log_file": "$SECURITY_LOG"
}
EOF
}

# Export functions
export -f init_security_log
export -f log_security_event
export -f validate_input_length
export -f sanitize_input
export -f check_dangerous_patterns
export -f check_secrets
export -f redact_secrets
export -f validate_path
export -f secure_read
export -f secure_write
export -f shell_escape
export -f json_escape
export -f validate_json
export -f validate_json_size
export -f validate_json_depth
export -f validate_json_general_size
export -f safe_parse_json
export -f validate_task_payload
export -f safe_parse_task
export -f validate_array_items
export -f validate_task_queue_item
export -f secure_random
export -f hash_sensitive
export -f verify_integrity
export -f secure_tempfile
export -f validate_input
export -f get_security_status
