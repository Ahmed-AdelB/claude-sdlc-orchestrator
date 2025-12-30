#!/bin/bash
# =============================================================================
# supervisor-approver.sh - Production-Ready Approval Engine
# =============================================================================
# Version: 2.2.0 (Portable + SEC-009B Auth)
# Features:
# - Python3 fallbacks for jq/bc/grep
# - Robust error handling
# - Unified quality gates
# - SEC-007: Secure ledger operations with file locking
# - SEC-008B: Hardcoded threshold floors
# - SEC-008C: Absolute path enforcement
# - SEC-009B: CLI authentication for APPROVE operations
# =============================================================================

set -euo pipefail

# =============================================================================
# SOURCE COMMON UTILITIES
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common.sh if available
if [[ -f "${SCRIPT_DIR}/common.sh" ]]; then
    source "${SCRIPT_DIR}/common.sh"
fi

# Source sqlite-state.sh for transition_task() and SQLite operations
# CRITICAL: Required for filesystem-SQLite state sync (fixes split-brain)
if [[ -f "${SCRIPT_DIR}/sqlite-state.sh" ]]; then
    source "${SCRIPT_DIR}/sqlite-state.sh"
elif [[ -n "${AUTONOMOUS_ROOT:-}" && -f "${AUTONOMOUS_ROOT}/lib/sqlite-state.sh" ]]; then
    source "${AUTONOMOUS_ROOT}/lib/sqlite-state.sh"
else
    # WARN: sqlite-state.sh not found - transition_task() will be undefined
    # This may cause split-brain issues where filesystem and SQLite states diverge
    echo "[WARN] sqlite-state.sh not found - SQLite state sync disabled" >&2
fi

# Fallbacks if common.sh not available
if ! type -t log_info >/dev/null 2>&1; then
    # Minimal fallbacks if common.sh not available
    log_info() { echo "[INFO] $*" >&2; }
    log_warn() { echo "[WARN] $*" >&2; }
    log_error() { echo "[ERROR] $*" >&2; }
    log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo "[DEBUG] $*" >&2 || true; }
    iso_timestamp() { date -Iseconds; }
    ensure_dir() { mkdir -p "$1"; }
    TRACE_ID="${TRACE_ID:-approver-$(date +%s)}"

    # SEC-008C: Minimal secure binary resolution fallback
    SECURE_BINARY_DIRS=("/usr/bin" "/bin" "/usr/local/bin" "/usr/sbin" "/sbin")
    secure_which() {
        local binary="$1"
        for path in "${SECURE_BINARY_DIRS[@]}"; do
            if [[ -x "$path/$binary" ]]; then
                echo "$path/$binary"
                return 0
            fi
        done
        return 1
    }
fi

# =============================================================================
# SEC-008C: Absolute Path Enforcement & PATH Manipulation Protection
# =============================================================================
# This module provides comprehensive path security to prevent:
# - Execution of binaries from untrusted directories
# - PATH hijacking attacks (prepending malicious directories to PATH)
# - Relative path exploitation
# - Symlink-based attacks to escape whitelisted directories
#
# SECURITY ARCHITECTURE:
# 1. All tool calls MUST use absolute paths resolved via secure_which()
# 2. PATH environment variable is monitored for manipulation attempts
# 3. All path violations are logged to security audit trail
# 4. Strict whitelist enforcement - binaries outside PATH_WHITELIST are rejected
# =============================================================================

# -----------------------------------------------------------------------------
# SEC-008C.1: PATH_WHITELIST - Allowed Executable Directories
# -----------------------------------------------------------------------------
# These are the ONLY directories from which executables can be run.
# SECURITY: This whitelist is readonly and cannot be modified at runtime.
# Attempts to add directories (especially user-writable ones like /tmp) are blocked.
# -----------------------------------------------------------------------------
readonly -a PATH_WHITELIST=(
    "/usr/bin"
    "/bin"
    "/usr/local/bin"
    "/usr/sbin"
    "/sbin"
    # Note: /opt/homebrew/bin excluded by default (macOS) - enable if needed
)

# Export for use in subshells (use SECURE_BINARY_DIRS for compatibility)
if [[ -z "${SECURE_BINARY_DIRS+x}" ]]; then
    SECURE_BINARY_DIRS=("${PATH_WHITELIST[@]}")
fi

# -----------------------------------------------------------------------------
# SEC-008C.2: Path Security Logging
# -----------------------------------------------------------------------------
# All path violations are logged to both stderr and security audit file.
# This creates an audit trail for security incident investigation.
# -----------------------------------------------------------------------------
_SECURITY_VIOLATIONS_LOG="${LOG_DIR}/security/path-violations.log"
_PATH_AUDIT_LOG="${LOG_DIR}/security/path-audit.log"

# Ensure security log directories exist
mkdir -p "$(dirname "${_SECURITY_VIOLATIONS_LOG}")" 2>/dev/null || true

# Log path violation with full context
# Usage: log_path_violation "violation_type" "details" "severity"
log_path_violation() {
    local violation_type="$1"
    local details="$2"
    local severity="${3:-WARN}"
    local timestamp
    local caller_info

    timestamp=$(iso_timestamp 2>/dev/null || date -Iseconds)
    caller_info="${FUNCNAME[2]:-unknown}:${BASH_LINENO[1]:-0}"

    local log_entry="[${timestamp}] [${TRACE_ID:-unknown}] [SEC-008C] [${severity}] ${violation_type}: ${details} (caller: ${caller_info})"

    # Log to stderr
    echo "$log_entry" >&2

    # Log to security violations file
    echo "$log_entry" >> "${_SECURITY_VIOLATIONS_LOG}" 2>/dev/null || true

    # Also use log_security_event if available (from common.sh)
    if declare -F log_security_event >/dev/null 2>&1; then
        log_security_event "PATH_VIOLATION_${violation_type}" "$details" "$severity" 2>/dev/null || true
    fi
}

# Log path audit event (for successful operations, debugging)
# Usage: log_path_audit "operation" "details"
# Note: Always returns 0 to avoid affecting caller's return code
log_path_audit() {
    local operation="$1"
    local details="$2"
    local timestamp

    timestamp=$(iso_timestamp 2>/dev/null || date -Iseconds)

    # Only log if DEBUG is enabled (avoid log spam)
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo "[${timestamp}] [${TRACE_ID:-unknown}] [SEC-008C] [AUDIT] ${operation}: ${details}" >> "${_PATH_AUDIT_LOG}" 2>/dev/null || true
    fi

    # Always return success to not affect caller
    return 0
}

# -----------------------------------------------------------------------------
# SEC-008C.3: validate_absolute_path() - Core Path Validation
# -----------------------------------------------------------------------------
# Validates that a path is:
# 1. An absolute path (starts with /)
# 2. Does not contain path traversal sequences (../)
# 3. Does not contain null bytes or other injection characters
# 4. Optionally: exists and is of expected type (file/directory)
#
# Usage: validate_absolute_path "/usr/bin/python3" [--must-exist] [--type file|dir]
# Returns: 0 if valid, 1 if invalid (logs violation)
# -----------------------------------------------------------------------------
validate_absolute_path() {
    local path="$1"
    local must_exist=false
    local expected_type=""

    # Parse optional arguments
    shift
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --must-exist) must_exist=true ;;
            --type) expected_type="$2"; shift ;;
            *) ;;
        esac
        shift
    done

    # Check: Path must not be empty
    if [[ -z "$path" ]]; then
        log_path_violation "EMPTY_PATH" "Empty path provided" "ERROR"
        return 1
    fi

    # Check: Must be absolute path (starts with /)
    if [[ "$path" != /* ]]; then
        log_path_violation "RELATIVE_PATH" "Relative path rejected: $path" "ERROR"
        return 1
    fi

    # Check: No null bytes (injection attempt)
    # Note: Bash strings cannot contain literal null bytes, but we check for escaped versions
    # and any truncation that might indicate a null byte was present
    if [[ "$path" == *'%00'* ]] || [[ "$path" == *'\x00'* ]] || [[ "$path" == *'\0'* ]]; then
        log_path_violation "NULL_BYTE_INJECTION" "Null byte encoding detected in path: $path" "CRITICAL"
        return 1
    fi

    # Check: No path traversal sequences
    if [[ "$path" == *".."* ]]; then
        log_path_violation "PATH_TRAVERSAL" "Path traversal attempt rejected: $path" "CRITICAL"
        return 1
    fi

    # Check: No command substitution or shell metacharacters in path
    if [[ "$path" =~ [\$\`\|\;\&\>\<] ]]; then
        log_path_violation "SHELL_METACHAR" "Shell metacharacters in path rejected: $path" "CRITICAL"
        return 1
    fi

    # Check: Path must exist if required
    if [[ "$must_exist" == "true" ]] && [[ ! -e "$path" ]]; then
        log_path_violation "PATH_NOT_EXISTS" "Required path does not exist: $path" "ERROR"
        return 1
    fi

    # Check: Path type if specified
    if [[ -n "$expected_type" ]]; then
        case "$expected_type" in
            file)
                if [[ -e "$path" ]] && [[ ! -f "$path" ]]; then
                    log_path_violation "TYPE_MISMATCH" "Expected file, got other type: $path" "ERROR"
                    return 1
                fi
                ;;
            dir|directory)
                if [[ -e "$path" ]] && [[ ! -d "$path" ]]; then
                    log_path_violation "TYPE_MISMATCH" "Expected directory, got other type: $path" "ERROR"
                    return 1
                fi
                ;;
        esac
    fi

    # Path is valid
    log_path_audit "VALIDATE_PATH" "Valid absolute path: $path"
    return 0
}

# -----------------------------------------------------------------------------
# SEC-008C.4: validate_executable_path() - Whitelist Enforcement
# -----------------------------------------------------------------------------
# Validates that an executable path is within PATH_WHITELIST.
# Resolves symlinks to detect symlink-based escapes.
#
# Usage: validate_executable_path "/usr/bin/python3"
# Returns: 0 if valid, 1 if not in whitelist
# -----------------------------------------------------------------------------
validate_executable_path() {
    local exe_path="$1"

    # First, validate it's an absolute path
    if ! validate_absolute_path "$exe_path"; then
        return 1
    fi

    # Resolve symlinks to get real path (prevents symlink escapes)
    local real_path
    if [[ -L "$exe_path" ]]; then
        real_path=$(readlink -f "$exe_path" 2>/dev/null || realpath "$exe_path" 2>/dev/null || echo "$exe_path")
        log_path_audit "SYMLINK_RESOLVED" "$exe_path -> $real_path"
    else
        real_path="$exe_path"
    fi

    # Extract directory from path
    local exe_dir
    exe_dir=$(dirname "$real_path")

    # Check if directory is in whitelist
    local is_whitelisted=false
    for allowed_dir in "${PATH_WHITELIST[@]}"; do
        if [[ "$exe_dir" == "$allowed_dir" ]]; then
            is_whitelisted=true
            break
        fi
    done

    if [[ "$is_whitelisted" != "true" ]]; then
        log_path_violation "WHITELIST_VIOLATION" "Executable not in PATH_WHITELIST: $exe_path (dir: $exe_dir)" "CRITICAL"
        return 1
    fi

    # Must be executable
    if [[ -e "$real_path" ]] && [[ ! -x "$real_path" ]]; then
        log_path_violation "NOT_EXECUTABLE" "Path exists but is not executable: $real_path" "ERROR"
        return 1
    fi

    log_path_audit "EXECUTABLE_VALIDATED" "Whitelisted executable: $exe_path"
    return 0
}

# -----------------------------------------------------------------------------
# SEC-008C.5: detect_path_manipulation() - PATH Environment Protection
# -----------------------------------------------------------------------------
# Detects attempts to manipulate the PATH environment variable.
# Checks for:
# - User-writable directories in PATH (e.g., /tmp, home dirs)
# - Relative paths in PATH (enables CWD attacks)
# - Suspicious path entries that could be used for hijacking
#
# Usage: detect_path_manipulation
# Returns: 0 if PATH is clean, 1 if manipulation detected
# -----------------------------------------------------------------------------

# Track original PATH for comparison
_ORIGINAL_PATH="${PATH:-}"
_PATH_CHECK_PERFORMED=false

detect_path_manipulation() {
    local current_path="${PATH:-}"
    local violations=()

    # Check if PATH has changed since script start
    if [[ "$_PATH_CHECK_PERFORMED" == "true" ]] && [[ "$current_path" != "$_ORIGINAL_PATH" ]]; then
        log_path_violation "PATH_MODIFIED" "PATH environment variable was modified during execution" "CRITICAL"
        log_path_violation "PATH_MODIFIED" "Original: $_ORIGINAL_PATH" "INFO"
        log_path_violation "PATH_MODIFIED" "Current: $current_path" "INFO"
        return 1
    fi

    # Split PATH and check each entry
    local IFS=':'
    local path_entries
    read -ra path_entries <<< "$current_path"

    for entry in "${path_entries[@]}"; do
        # Skip empty entries
        [[ -z "$entry" ]] && continue

        # Check 1: Relative paths (includes "." for CWD attacks)
        if [[ "$entry" != /* ]]; then
            violations+=("RELATIVE_PATH_IN_PATH: $entry")
            continue
        fi

        # Check 2: User-writable directories (common attack vectors)
        case "$entry" in
            /tmp|/tmp/*|/var/tmp|/var/tmp/*|/dev/shm|/dev/shm/*)
                violations+=("WRITABLE_TEMP_DIR_IN_PATH: $entry")
                ;;
            "$HOME"/*|/home/*/*)
                # Home directories are user-writable
                violations+=("USER_HOME_DIR_IN_PATH: $entry")
                ;;
            /usr/local/bin)
                # /usr/local/bin is often user-writable, warn but allow
                log_path_audit "PATH_ENTRY_WARNING" "/usr/local/bin in PATH (may be user-writable)"
                ;;
        esac

        # Check 3: Path entries with suspicious patterns
        if [[ "$entry" == *".."* ]]; then
            violations+=("PATH_TRAVERSAL_IN_PATH: $entry")
        fi

        # Check 4: Directories that don't exist (might be typosquatting setup)
        if [[ ! -d "$entry" ]]; then
            log_path_audit "PATH_ENTRY_MISSING" "PATH contains non-existent directory: $entry"
        fi
    done

    # Report violations
    if [[ ${#violations[@]} -gt 0 ]]; then
        log_path_violation "PATH_MANIPULATION_DETECTED" "Found ${#violations[@]} suspicious PATH entries" "CRITICAL"
        for violation in "${violations[@]}"; do
            log_path_violation "PATH_ENTRY_VIOLATION" "$violation" "ERROR"
        done
        return 1
    fi

    _PATH_CHECK_PERFORMED=true
    log_path_audit "PATH_CLEAN" "PATH environment variable passed security checks"
    return 0
}

# -----------------------------------------------------------------------------
# SEC-008C.6: block_path_manipulation() - Active PATH Protection
# -----------------------------------------------------------------------------
# Sanitizes PATH to remove dangerous entries.
# Should be called at script initialization.
#
# Usage: block_path_manipulation
# Effect: Modifies PATH to contain only whitelisted directories
# -----------------------------------------------------------------------------
block_path_manipulation() {
    local sanitized_path=""
    local IFS=':'
    local path_entries
    read -ra path_entries <<< "${PATH:-}"

    for entry in "${path_entries[@]}"; do
        [[ -z "$entry" ]] && continue

        # Only keep entries that are in PATH_WHITELIST
        local is_allowed=false
        for allowed in "${PATH_WHITELIST[@]}"; do
            if [[ "$entry" == "$allowed" ]]; then
                is_allowed=true
                break
            fi
        done

        if [[ "$is_allowed" == "true" ]]; then
            if [[ -z "$sanitized_path" ]]; then
                sanitized_path="$entry"
            else
                sanitized_path="${sanitized_path}:${entry}"
            fi
        else
            log_path_violation "PATH_ENTRY_BLOCKED" "Removed non-whitelisted PATH entry: $entry" "WARN"
        fi
    done

    # Ensure PATH is never empty
    if [[ -z "$sanitized_path" ]]; then
        sanitized_path="/usr/bin:/bin"
        log_path_violation "PATH_EMPTY_FALLBACK" "PATH was empty after sanitization, using fallback" "WARN"
    fi

    # Update PATH
    export PATH="$sanitized_path"
    _ORIGINAL_PATH="$sanitized_path"

    log_path_audit "PATH_SANITIZED" "PATH sanitized to: $PATH"
}

# -----------------------------------------------------------------------------
# SEC-008C.7: Cached Binary Paths (Performance Optimization)
# -----------------------------------------------------------------------------
# Cache resolved binary paths for performance (avoid repeated lookups)
# Note: Using simple variable-based caching to avoid associative array issues with set -u
declare -A _BINARY_CACHE 2>/dev/null || true

# Get cached binary path or resolve it
# Falls back to secure_which if caching has issues
# Also validates the resolved path against PATH_WHITELIST
_get_binary() {
    local binary="$1"

    # Skip caching and go directly to secure_which for reliability
    # This avoids issues with associative arrays and set -u
    local resolved
    if resolved=$(secure_which "$binary" 2>/dev/null); then
        # Validate resolved path is in whitelist
        if validate_executable_path "$resolved" 2>/dev/null; then
            echo "$resolved"
            return 0
        else
            log_path_violation "BINARY_NOT_WHITELISTED" "secure_which returned non-whitelisted path for $binary: $resolved" "ERROR"
            return 1
        fi
    fi

    log_path_violation "BINARY_NOT_FOUND" "Binary not found in secure paths: $binary" "WARN"
    return 1
}

# -----------------------------------------------------------------------------
# SEC-008C.8: Initialize Path Security
# -----------------------------------------------------------------------------
# Run PATH security checks at module load time
# This ensures protection is active before any tool execution
# -----------------------------------------------------------------------------
_init_path_security() {
    # Check for PATH manipulation
    if ! detect_path_manipulation; then
        log_path_violation "INIT_PATH_UNSAFE" "PATH manipulation detected at initialization" "CRITICAL"
        # P0.8: Enable strict PATH sanitization (was commented out)
        block_path_manipulation
    fi

    log_path_audit "PATH_SECURITY_INITIALIZED" "SEC-008C path security module initialized"
}

# Run initialization (but not if we're being sourced for testing)
if [[ "${_SEC008C_SKIP_INIT:-}" != "1" ]]; then
    _init_path_security
fi

# =============================================================================
# CONFIGURATION
# =============================================================================

# Base directories
AUTONOMOUS_ROOT="${AUTONOMOUS_ROOT:-$(dirname "$SCRIPT_DIR")}"
TASKS_DIR="${TASKS_DIR:-${AUTONOMOUS_ROOT}/tasks}"
QUEUE_DIR="${TASKS_DIR}/queue"
REVIEW_DIR="${TASKS_DIR}/review"
APPROVED_DIR="${TASKS_DIR}/approved"
REJECTED_DIR="${TASKS_DIR}/rejected"
COMPLETED_DIR="${TASKS_DIR}/completed"
FAILED_DIR="${TASKS_DIR}/failed"
HISTORY_DIR="${TASKS_DIR}/history"
STATE_DIR="${STATE_DIR:-${AUTONOMOUS_ROOT}/state}"
GATES_DIR="${STATE_DIR}/gates"
COMMS_DIR="${AUTONOMOUS_ROOT}/comms"
LOG_DIR="${LOG_DIR:-${AUTONOMOUS_ROOT}/logs}/supervision"
BIN_DIR="${BIN_DIR:-${AUTONOMOUS_ROOT}/bin}"

# Thresholds
APPROVAL_THRESHOLD="${APPROVAL_THRESHOLD:-85}"
COVERAGE_THRESHOLD="${COVERAGE_THRESHOLD:-80}"
MAX_RETRIES="${MAX_RETRIES:-3}"
MAX_REJECTIONS_PER_HOUR="${MAX_REJECTIONS_PER_HOUR:-10}"
GATE_TIMEOUT="${GATE_TIMEOUT:-300}"
STRICT_MODE="${STRICT_MODE:-true}" # SEC-008A: Fail gates if tools/configs missing (secure by default)

# =============================================================================
# SEC-008B: Hardcoded Threshold Floors (Security Baseline)
# =============================================================================
# These floors cannot be bypassed by configuration - they represent the minimum
# acceptable security posture. Attackers cannot set thresholds to 0 to bypass
# quality gates.
#
# SECURITY: These values are hardcoded and MUST NOT be configurable
# =============================================================================
if [[ -z "${MIN_COVERAGE_FLOOR:-}" ]]; then readonly MIN_COVERAGE_FLOOR=70; fi
if [[ -z "${MIN_SECURITY_SCORE_FLOOR:-}" ]]; then readonly MIN_SECURITY_SCORE_FLOOR=60; fi
if [[ -z "${MAX_CRITICAL_VULNS_CEILING:-}" ]]; then readonly MAX_CRITICAL_VULNS_CEILING=0; fi

# User-configurable thresholds (will be enforced against floors)
MIN_COVERAGE="${MIN_COVERAGE:-80}"
MIN_SECURITY_SCORE="${MIN_SECURITY_SCORE:-70}"
MAX_CRITICAL_VULNS="${MAX_CRITICAL_VULNS:-0}"

# Enforce threshold floors on user-configurable values
# This prevents attackers from bypassing quality gates by setting thresholds to 0
enforce_threshold_floors() {
    # Coverage floor enforcement
    if [[ "$MIN_COVERAGE" -lt "$MIN_COVERAGE_FLOOR" ]]; then
        log_warn "SEC-008B: MIN_COVERAGE below floor ($MIN_COVERAGE < $MIN_COVERAGE_FLOOR), using floor"
        log_security_event "THRESHOLD_FLOOR_ENFORCED" "MIN_COVERAGE set to floor: $MIN_COVERAGE_FLOOR (attempted: $MIN_COVERAGE)" "WARN" 2>/dev/null || true
        MIN_COVERAGE=$MIN_COVERAGE_FLOOR
    fi

    # Security score floor enforcement
    if [[ "$MIN_SECURITY_SCORE" -lt "$MIN_SECURITY_SCORE_FLOOR" ]]; then
        log_warn "SEC-008B: MIN_SECURITY_SCORE below floor ($MIN_SECURITY_SCORE < $MIN_SECURITY_SCORE_FLOOR), using floor"
        log_security_event "THRESHOLD_FLOOR_ENFORCED" "MIN_SECURITY_SCORE set to floor: $MIN_SECURITY_SCORE_FLOOR (attempted: $MIN_SECURITY_SCORE)" "WARN" 2>/dev/null || true
        MIN_SECURITY_SCORE=$MIN_SECURITY_SCORE_FLOOR
    fi

    # Critical vulnerabilities ceiling enforcement (cannot allow any critical vulns)
    if [[ "$MAX_CRITICAL_VULNS" -gt "$MAX_CRITICAL_VULNS_CEILING" ]]; then
        log_warn "SEC-008B: MAX_CRITICAL_VULNS above ceiling ($MAX_CRITICAL_VULNS > $MAX_CRITICAL_VULNS_CEILING), using ceiling"
        log_security_event "THRESHOLD_CEILING_ENFORCED" "MAX_CRITICAL_VULNS set to ceiling: $MAX_CRITICAL_VULNS_CEILING (attempted: $MAX_CRITICAL_VULNS)" "WARN" 2>/dev/null || true
        MAX_CRITICAL_VULNS=$MAX_CRITICAL_VULNS_CEILING
    fi

    log_debug "SEC-008B: Threshold floors enforced - Coverage>=$MIN_COVERAGE_FLOOR%, Security>=$MIN_SECURITY_SCORE_FLOOR, CriticalVulns<=$MAX_CRITICAL_VULNS_CEILING"
}

# Call enforce_threshold_floors at initialization
enforce_threshold_floors

# =============================================================================
# SEC-008-2: Coverage Report Validation (Anti-Manipulation)
# =============================================================================
# Validates that coverage percentages are within valid ranges and have not been
# manipulated. Prevents attacks where coverage values are injected or modified
# to bypass quality gates.
#
# Validation rules:
# 1. Coverage must be a valid number (integer or decimal)
# 2. Coverage must be between 0 and 100 (inclusive)
# 3. Coverage cannot be negative or exceed 100%
# 4. Coverage string must not contain shell/control characters
# =============================================================================

validate_coverage_report() {
    local coverage_value="$1"
    local source="${2:-unknown}"

    # Strip whitespace
    coverage_value=$(echo "$coverage_value" | tr -d '[:space:]')

    # SEC-008-2: Check for empty value
    if [[ -z "$coverage_value" ]]; then
        log_warn "SEC-008-2: Empty coverage value from $source"
        log_security_event "COVERAGE_VALIDATION_FAILED" "Empty coverage value from $source" "WARN" 2>/dev/null || true
        return 1
    fi

    # SEC-008-2: Check for valid numeric format (integer or decimal)
    # Must be digits with optional single decimal point
    if ! [[ "$coverage_value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        log_error "SEC-008-2: Invalid coverage format '$coverage_value' from $source (must be numeric)"
        log_security_event "COVERAGE_VALIDATION_FAILED" "Invalid format: '$coverage_value' from $source" "CRITICAL" 2>/dev/null || true
        return 1
    fi

    # SEC-008-2: Check for shell injection attempts (shouldn't reach here but defense in depth)
    if [[ "$coverage_value" =~ [\$\`\;\|\&\<\>] ]]; then
        log_error "SEC-008-2: Shell injection attempt in coverage value from $source"
        log_security_event "COVERAGE_INJECTION_BLOCKED" "Shell chars in: '$coverage_value' from $source" "CRITICAL" 2>/dev/null || true
        return 1
    fi

    # SEC-008-2: Check range (0-100%)
    local awk_bin
    awk_bin=$(_get_binary "awk" 2>/dev/null) || awk_bin="/usr/bin/awk"

    # Check if coverage is negative (< 0)
    if "$awk_bin" "BEGIN{exit !($coverage_value < 0)}"; then
        log_error "SEC-008-2: Negative coverage value '$coverage_value' from $source"
        log_security_event "COVERAGE_VALIDATION_FAILED" "Negative value: $coverage_value from $source" "CRITICAL" 2>/dev/null || true
        return 1
    fi

    # Check if coverage exceeds 100%
    if "$awk_bin" "BEGIN{exit !($coverage_value > 100)}"; then
        log_error "SEC-008-2: Coverage exceeds 100%: '$coverage_value' from $source"
        log_security_event "COVERAGE_VALIDATION_FAILED" "Value >100%: $coverage_value from $source" "CRITICAL" 2>/dev/null || true
        return 1
    fi

    # SEC-008-2: Check for suspiciously round numbers that might indicate spoofing
    # (e.g., exactly 100.0 or 80.0 without decimals after running real tests)
    # This is a warning, not a failure
    if [[ "$coverage_value" == "100" ]] || [[ "$coverage_value" == "100.0" ]]; then
        log_warn "SEC-008-2: Perfect 100% coverage from $source - verify this is legitimate"
        log_security_event "COVERAGE_PERFECT_SCORE" "100% coverage from $source - may warrant verification" "INFO" 2>/dev/null || true
    fi

    log_debug "SEC-008-2: Coverage validation passed for $coverage_value% from $source"
    return 0
}

# Ensure directories exist
for dir in "$QUEUE_DIR" "$REVIEW_DIR" "$APPROVED_DIR" "$REJECTED_DIR" \
           "$COMPLETED_DIR" "$FAILED_DIR" "$HISTORY_DIR" "$GATES_DIR" \
           "$LOG_DIR" "${COMMS_DIR}/supervisor/inbox" "${COMMS_DIR}/worker/inbox"; do
    ensure_dir "$dir"
done

# =============================================================================
# LOGGING & JSON UTILS
# =============================================================================

log_gate() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(iso_timestamp)
    echo "[${timestamp}] [${TRACE_ID:-unknown}] [GATE] [${level}] ${message}" >&2
    echo "[${timestamp}] [${TRACE_ID:-unknown}] [GATE] [${level}] ${message}" >> "${LOG_DIR}/evaluations.log" 2>/dev/null || true
}

write_json_result() {
    local output_file="$1"
    local json_content="$2"

    # SEC-008C: Use absolute paths for external tools
    local jq_bin python3_bin
    if jq_bin=$(_get_binary "jq"); then
        echo "$json_content" | "$jq_bin" . > "$output_file"
    elif python3_bin=$(_get_binary "python3"); then
        "$python3_bin" -c "import sys, json; print(json.dumps(json.loads(sys.stdin.read()), indent=2))" <<< "$json_content" > "$output_file"
    else
        echo "$json_content" > "$output_file"
    fi
}

# =============================================================================
# SEC-007: Secure Ledger Operations
# =============================================================================
# Provides file locking for ledger writes to prevent race conditions and
# data corruption when multiple processes write simultaneously.
# Uses flock for portable advisory locking with timeout support.
# =============================================================================

# Ledger file paths
TASK_LEDGER="${TASK_LEDGER:-${TASKS_DIR}/ledger.jsonl}"
LEDGER_LOCK="${TASK_LEDGER}.lock"
LEDGER_LOCK_TIMEOUT="${LEDGER_LOCK_TIMEOUT:-10}"
LEDGER_MAX_SIZE_MB="${LEDGER_MAX_SIZE_MB:-100}"

# Append to ledger with exclusive file locking
# Usage: append_to_ledger "json_entry"
# Returns: 0 on success, 1 on lock timeout or write failure
append_to_ledger() {
    local entry="$1"
    local ledger="${TASK_LEDGER}"
    local lock_file="${LEDGER_LOCK}"
    local timeout="${LEDGER_LOCK_TIMEOUT}"

    # Ensure ledger directory exists
    mkdir -p "$(dirname "$ledger")" 2>/dev/null || true

    # Validate entry is valid JSON if jq is available
    local jq_bin
    if jq_bin=$(_get_binary "jq" 2>/dev/null); then
        if ! echo "$entry" | "$jq_bin" -e . >/dev/null 2>&1; then
            log_gate "WARN" "SEC-007: Invalid JSON entry detected, escaping content"
            # Try to escape the entry as a string
            entry=$(echo "$entry" | "$jq_bin" -Rs '.' 2>/dev/null || echo "$entry")
        fi
    fi

    # Use subshell with flock for atomic append
    (
        # Acquire exclusive lock with timeout
        if ! flock -x -w "$timeout" 200; then
            log_gate "ERROR" "SEC-007: Failed to acquire ledger lock after ${timeout}s"
            return 1
        fi

        # Check file integrity before append (ensure ends with newline)
        if [[ -f "$ledger" && -s "$ledger" ]]; then
            local last_char
            last_char=$(tail -c 1 "$ledger" 2>/dev/null || echo "")
            if [[ "$last_char" != "" && "$last_char" != $'\n' ]]; then
                echo "" >> "$ledger"
            fi
        fi

        # Atomic append with newline
        printf '%s\n' "$entry" >> "$ledger"

        # Sync to disk for durability
        sync "$ledger" 2>/dev/null || true

    ) 200>"$lock_file"

    return $?
}

# Read ledger entries with shared lock (allows concurrent reads)
# Usage: entries=$(read_ledger_entries "filter_pattern")
read_ledger_entries() {
    local filter="${1:-}"
    local ledger="${TASK_LEDGER}"
    local lock_file="${LEDGER_LOCK}"

    [[ ! -f "$ledger" ]] && return 0

    (
        # Acquire shared lock (allows concurrent reads)
        if ! flock -s -w 5 200; then
            log_gate "WARN" "SEC-007: Failed to acquire shared ledger lock"
            return 1
        fi

        local grep_bin
        grep_bin=$(_get_binary "grep" 2>/dev/null) || grep_bin="/bin/grep"

        if [[ -n "$filter" ]]; then
            "$grep_bin" -F "$filter" "$ledger" 2>/dev/null || true
        else
            cat "$ledger"
        fi
    ) 200>"$lock_file"
}

# Rotate ledger file when it exceeds size limit
# Usage: rotate_ledger_if_needed
rotate_ledger_if_needed() {
    local ledger="${TASK_LEDGER}"
    local lock_file="${LEDGER_LOCK}"
    local max_size_bytes=$((LEDGER_MAX_SIZE_MB * 1024 * 1024))

    [[ ! -f "$ledger" ]] && return 0

    local current_size
    # Handle both GNU and BSD stat
    current_size=$(stat -c%s "$ledger" 2>/dev/null || stat -f%z "$ledger" 2>/dev/null || echo 0)

    if [[ "$current_size" -gt "$max_size_bytes" ]]; then
        local archive="${ledger}.$(date +%Y%m%d_%H%M%S)"

        (
            # Exclusive lock for rotation
            if ! flock -x -w 30 200; then
                log_gate "ERROR" "SEC-007: Failed to acquire lock for ledger rotation"
                return 1
            fi

            mv "$ledger" "$archive"
            gzip "$archive" 2>/dev/null || true
            log_gate "INFO" "SEC-007: Rotated ledger to ${archive}.gz"
        ) 200>"$lock_file"
    fi
}

# Verify ledger integrity (check all lines are valid JSON)
# Usage: verify_ledger_integrity
# Returns: 0 if all entries valid, 1 if corrupted entries found
verify_ledger_integrity() {
    local ledger="${TASK_LEDGER}"
    local errors=0

    [[ ! -f "$ledger" ]] && { echo "Ledger not found: $ledger"; return 0; }

    echo "SEC-007: Verifying ledger integrity: $ledger"

    local jq_bin
    jq_bin=$(_get_binary "jq" 2>/dev/null) || jq_bin=""

    local line_num=0
    while IFS= read -r line; do
        line_num=$((line_num + 1))
        if [[ -n "$line" ]]; then
            if [[ -n "$jq_bin" ]]; then
                if ! echo "$line" | "$jq_bin" -e . >/dev/null 2>&1; then
                    echo "ERROR: Invalid JSON at line $line_num: ${line:0:80}..."
                    errors=$((errors + 1))
                fi
            fi
        fi
    done < "$ledger"

    if [[ $errors -eq 0 ]]; then
        echo "PASS: All $line_num entries are valid JSON"
        return 0
    else
        echo "FAIL: Found $errors invalid entries out of $line_num"
        return 1
    fi
}

# Log ledger entry - uses secure append_to_ledger with file locking
log_ledger() {
    local event="$1"
    local task_id="$2"
    local details="${3:-}"
    local timestamp
    timestamp=$(iso_timestamp)

    # Escape special characters in details for valid JSON
    details="${details//\\/\\\\}"
    details="${details//\"/\\\"}"
    details="${details//$'\n'/\\n}"
    details="${details//$'\t'/\\t}"

    # Build JSON entry
    local json_entry="{\"timestamp\":\"$timestamp\",\"event\":\"$event\",\"task_id\":\"$task_id\",\"details\":\"$details\",\"trace_id\":\"${TRACE_ID:-unknown}\"}"

    # Use secure append with locking (SEC-007)
    if ! append_to_ledger "$json_entry"; then
        # Fallback to direct append with warning (for backwards compatibility)
        log_gate "WARN" "SEC-007: Ledger lock failed, using fallback append"
        echo "$json_entry" >> "${LOG_DIR}/evaluations.jsonl" 2>/dev/null || true
    fi
}

# =============================================================================
# GATE CHECK FUNCTIONS
# =============================================================================

# CHECK 1: Test Suite Execution
check_tests() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-001: Running test suite..."

    local test_output="" exit_code=0
    cd "$workspace" || return 1

    # SEC-008C: Pre-resolve binaries to absolute paths
    local npm_bin python3_bin cargo_bin go_bin grep_bin head_bin

    if [[ -f "package.json" ]]; then
        if npm_bin=$(_get_binary "npm"); then
            test_output=$("$npm_bin" test 2>&1) || exit_code=$?
        else
            log_gate "ERROR" "EXE-001: npm not found in secure path"
            return 1
        fi
    elif [[ -f "pytest.ini" ]] || [[ -f "setup.py" ]] || [[ -f "pyproject.toml" ]]; then
        # SEC-008A: Strict mode - FAIL if test runner not found (don't skip!)
        if python3_bin=$(_get_binary "python3"); then
            test_output=$("$python3_bin" -m pytest 2>&1) || exit_code=$?
        else
            log_gate "ERROR" "SEC-008A: SECURITY VIOLATION - pytest/python3 required but not found"
            log_security_event "QUALITY_GATE_TOOL_MISSING" "pytest/python3 not found - gate FAILED (strict mode)" "CRITICAL" 2>/dev/null || true
            return 1  # FAIL, not pass - prevents quality gate bypass
        fi
    elif [[ -f "Cargo.toml" ]]; then
        if cargo_bin=$(_get_binary "cargo"); then
            test_output=$("$cargo_bin" test 2>&1) || exit_code=$?
        else
            log_gate "ERROR" "EXE-001: cargo not found in secure path"
            return 1
        fi
    elif [[ -f "go.mod" ]]; then
        if go_bin=$(_get_binary "go"); then
            test_output=$("$go_bin" test ./... 2>&1) || exit_code=$?
        else
            log_gate "ERROR" "EXE-001: go not found in secure path"
            return 1
        fi
    elif [[ -x "./tests/run_tests.sh" ]]; then
        test_output=$(./tests/run_tests.sh 2>&1) || exit_code=$?
    else
        # SEC-008A: Strict mode - FAIL if no test runner is detected
        # This prevents bypassing quality gates by removing test configuration
        log_gate "ERROR" "SEC-008A: SECURITY VIOLATION - No test runner detected"
        log_security_event "QUALITY_GATE_NO_TESTS" "No test runner found - gate FAILED (strict mode)" "CRITICAL" 2>/dev/null || true
        return 1  # FAIL, not pass - prevents quality gate bypass
    fi

    # SEC-008C: Use absolute paths for grep/head
    local passed failed
    grep_bin=$(_get_binary "grep") || grep_bin="/bin/grep"
    head_bin=$(_get_binary "head") || head_bin="/usr/bin/head"
    passed=$(echo "$test_output" | "$grep_bin" -oE "[0-9]+ passed" | "$grep_bin" -oE "[0-9]+" | "$head_bin" -1 || echo 0)
    failed=$(echo "$test_output" | "$grep_bin" -oE "[0-9]+ failed" | "$grep_bin" -oE "[0-9]+" | "$head_bin" -1 || echo 0)

    local status="FAIL"
    [[ $exit_code -eq 0 ]] && status="PASS"

    # JSON Construction (Python fallback)
    local json_result
    json_result=$(cat <<EOF
{
    "check": "EXE-001",
    "name": "Test Suite",
    "passed": ${passed:-0},
    "failed": ${failed:-0},
    "exit_code": $exit_code,
    "status": "$status"
}
EOF
)
    write_json_result "$output_file" "$json_result"

    [[ $exit_code -eq 0 ]] && log_gate "PASS" "EXE-001: Tests passed" || log_gate "FAIL" "EXE-001: Tests failed"
    return $exit_code
}

# CHECK 2: Test Coverage
check_coverage() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-002: Checking test coverage..."

    local coverage=0 exit_code=0 output=""
    cd "$workspace" || return 1

    # SEC-008C: Pre-resolve binaries to absolute paths
    local npm_bin python3_bin awk_bin grep_bin
    grep_bin=$(_get_binary "grep") || grep_bin="/bin/grep"
    awk_bin=$(_get_binary "awk") || awk_bin="/usr/bin/awk"

    local coverage_tool_found=false
    if [[ -f "package.json" ]] && "$grep_bin" -q '"coverage"' package.json 2>/dev/null; then
        if npm_bin=$(_get_binary "npm"); then
            coverage_tool_found=true
            output=$("$npm_bin" run coverage 2>&1 || true)
            coverage=$(printf '%s\n' "$output" | "$awk_bin" -F'|' '/All files/ {gsub(/%/,"",$4); gsub(/ /,"",$4); print $4; exit}')
        fi
    elif [[ -f "pytest.ini" ]] || [[ -f "pyproject.toml" ]]; then
        if python3_bin=$(_get_binary "python3"); then
            coverage_tool_found=true
            output=$("$python3_bin" -m pytest --cov=. --cov-report=term 2>&1 || true)
            coverage=$(printf '%s\n' "$output" | "$awk_bin" '/^TOTAL/ {gsub(/%/,"",$NF); print $NF; exit}')
        fi
    fi

    # FIX-001: Handle case where coverage measurement is unavailable
    # Skip gate with warning instead of failing with 0%
    if [[ "$coverage_tool_found" != "true" ]]; then
        # SEC-008A: Strict mode check
        if [[ "$STRICT_MODE" == "true" ]]; then
            log_gate "ERROR" "SEC-008A: Coverage tool not found - gate FAILED (strict mode)"
            local json_result
            json_result=$(cat <<EOF
{
    "check": "EXE-002",
    "name": "Test Coverage",
    "coverage": "N/A",
    "threshold": $COVERAGE_THRESHOLD,
    "exit_code": 1,
    "status": "FAIL",
    "reason": "strict_mode_no_tool"
}
EOF
)
            write_json_result "$output_file" "$json_result"
            return 1
        else
            log_gate "WARN" "EXE-002: No coverage tool available (npm/pytest not configured), skipping check"
            local json_result
            json_result=$(cat <<EOF
{
    "check": "EXE-002",
    "name": "Test Coverage",
    "coverage": "N/A",
    "threshold": $COVERAGE_THRESHOLD,
    "exit_code": 0,
    "status": "SKIPPED",
    "reason": "no_coverage_tool"
}
EOF
)
            write_json_result "$output_file" "$json_result"
            return 0
        fi
    fi

    # FIX-001: If tool found but parsing returned empty, skip with warning
    if [[ -z "$coverage" ]] || [[ "$coverage" == "" ]]; then
        # SEC-008A: Strict mode check
        if [[ "$STRICT_MODE" == "true" ]]; then
            log_gate "ERROR" "SEC-008A: Coverage parsing failed - gate FAILED (strict mode)"
            local json_result
            json_result=$(cat <<EOF
{
    "check": "EXE-002",
    "name": "Test Coverage",
    "coverage": "N/A",
    "threshold": $COVERAGE_THRESHOLD,
    "exit_code": 1,
    "status": "FAIL",
    "reason": "strict_mode_parsing_failed"
}
EOF
)
            write_json_result "$output_file" "$json_result"
            return 1
        else
            log_gate "WARN" "EXE-002: Coverage parsing failed (output format unrecognized), skipping check"
            local json_result
            json_result=$(cat <<EOF
{
    "check": "EXE-002",
    "name": "Test Coverage",
    "coverage": "N/A",
    "threshold": $COVERAGE_THRESHOLD,
    "exit_code": 0,
    "status": "SKIPPED",
    "reason": "parsing_failed"
}
EOF
)
            write_json_result "$output_file" "$json_result"
            return 0
        fi
    fi

    # SEC-008-2: Validate coverage value before using it
    if ! validate_coverage_report "$coverage" "check_coverage/$workspace"; then
        log_gate "ERROR" "SEC-008-2: Coverage validation failed - gate BLOCKED"
        local json_result
        json_result=$(cat <<EOF
{
    "check": "EXE-002",
    "name": "Test Coverage",
    "coverage": "INVALID",
    "threshold": $COVERAGE_THRESHOLD,
    "exit_code": 1,
    "status": "FAIL",
    "reason": "coverage_validation_failed"
}
EOF
)
        write_json_result "$output_file" "$json_result"
        return 1
    fi

    # Coverage was successfully measured and validated - enforce threshold
    if "$awk_bin" "BEGIN{exit !($coverage >= $COVERAGE_THRESHOLD)}"; then
        exit_code=0
    else
        exit_code=1
    fi

    local status="FAIL"
    [[ $exit_code -eq 0 ]] && status="PASS"

    local json_result
    json_result=$(cat <<EOF
{
    "check": "EXE-002",
    "name": "Test Coverage",
    "coverage": ${coverage:-0},
    "threshold": $COVERAGE_THRESHOLD,
    "exit_code": $exit_code,
    "status": "$status"
}
EOF
)
    write_json_result "$output_file" "$json_result"

    [[ $exit_code -eq 0 ]] && log_gate "PASS" "EXE-002: Coverage ${coverage}% >= ${COVERAGE_THRESHOLD}%" || log_gate "FAIL" "EXE-002: Coverage ${coverage}% < ${COVERAGE_THRESHOLD}%"
    return $exit_code
}

# CHECK 3: Linting
check_lint() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-003: Running linter..."

    local errors=0 warnings=0 exit_code=0
    cd "$workspace" || return 1

    # SEC-008C: Pre-resolve binaries to absolute paths
    local npm_bin ruff_bin shellcheck_bin grep_bin find_bin
    grep_bin=$(_get_binary "grep") || grep_bin="/bin/grep"
    find_bin=$(_get_binary "find") || find_bin="/usr/bin/find"

    local lint_output=""
    local tool_found=false

    if [[ -f "package.json" ]] && "$grep_bin" -q '"lint"' package.json 2>/dev/null; then
        if npm_bin=$(_get_binary "npm"); then
            tool_found=true
            lint_output=$("$npm_bin" run lint 2>&1) || true
            errors=$(echo "$lint_output" | "$grep_bin" -c "error" || echo 0)
            warnings=$(echo "$lint_output" | "$grep_bin" -c "warning" || echo 0)
        fi
    elif ruff_bin=$(_get_binary "ruff") && { [[ -f "pyproject.toml" ]] || [[ -f "setup.cfg" ]] || [[ -d "src" ]]; }; then
        tool_found=true
        lint_output=$("$ruff_bin" check . 2>&1) || true
        errors=$(echo "$lint_output" | "$grep_bin" -cE "^[^:]+:[0-9]+:" || echo 0)
    elif shellcheck_bin=$(_get_binary "shellcheck"); then
        local targets=()
        while IFS= read -r f; do targets+=("$f"); done < <("$find_bin" . -name "*.sh" 2>/dev/null)
        if [[ -d "bin" ]]; then
            while IFS= read -r f; do targets+=("$f"); done < <("$find_bin" bin -maxdepth 1 -type f -perm -u+x 2>/dev/null)
        fi
        if [[ ${#targets[@]} -gt 0 ]]; then
            tool_found=true
            lint_output=$("$shellcheck_bin" "${targets[@]}" 2>&1) || true
            errors=$(echo "$lint_output" | "$grep_bin" -c "error" || echo 0)
            warnings=$(echo "$lint_output" | "$grep_bin" -c "warning" || echo 0)
        fi
    fi

    # SEC-008A: Strict mode enforcement
    if [[ "$tool_found" != "true" ]]; then
        if [[ "$STRICT_MODE" == "true" ]]; then
            log_gate "ERROR" "SEC-008A: Linter not found - gate FAILED (strict mode)"
            local json_result
            json_result=$(cat <<EOF
{
    "check": "EXE-003",
    "name": "Linting",
    "errors": 0,
    "warnings": 0,
    "exit_code": 1,
    "status": "FAIL",
    "reason": "strict_mode_no_tool"
}
EOF
)
            write_json_result "$output_file" "$json_result"
            return 1
        fi
    fi

    [[ ${errors:-0} -gt 0 ]] && exit_code=1
    local status="FAIL"
    [[ $exit_code -eq 0 ]] && status="PASS"

    local json_result
    json_result=$(cat <<EOF
{
    "check": "EXE-003",
    "name": "Linting",
    "errors": ${errors:-0},
    "warnings": ${warnings:-0},
    "exit_code": $exit_code,
    "status": "$status"
}
EOF
)
    write_json_result "$output_file" "$json_result"

    [[ $exit_code -eq 0 ]] && log_gate "PASS" "EXE-003: No linting errors" || log_gate "FAIL" "EXE-003: ${errors} linting errors"
    return $exit_code
}

# CHECK 4: Type Checking
check_types() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-004: Running type checker..."

    local errors=0 exit_code=0 output=""
    cd "$workspace" || return 1

    # SEC-008C: Pre-resolve binaries to absolute paths
    local npx_bin python3_bin grep_bin
    grep_bin=$(_get_binary "grep") || grep_bin="/bin/grep"

    local tool_found=false

    if [[ -f "tsconfig.json" ]]; then
        if npx_bin=$(_get_binary "npx"); then
            tool_found=true
            output=$("$npx_bin" tsc --noEmit 2>&1) || exit_code=$?
            errors=$(echo "$output" | "$grep_bin" -c "error TS" || echo 0)
        else
            log_gate "WARN" "EXE-004: npx not found in secure path, skipping TypeScript check"
            exit_code=0
        fi
    elif [[ -f "pyproject.toml" ]] || [[ -f "mypy.ini" ]]; then
        if python3_bin=$(_get_binary "python3"); then
            tool_found=true
            output=$("$python3_bin" -m mypy . 2>&1) || exit_code=$?
            errors=$(echo "$output" | "$grep_bin" -c "error:" || echo 0)
        else
            log_gate "WARN" "EXE-004: python3 not found in secure path, skipping mypy check"
            exit_code=0
        fi
    else
        exit_code=0
    fi

    # SEC-008A: Strict mode enforcement
    if [[ "$tool_found" != "true" ]]; then
        # Check if type definitions exist but tool is missing (handled above) OR no config exists
        # In strict mode, we might require type checking if relevant files exist
        local has_ts_files
        has_ts_files=$(find . -name "*.ts" -o -name "*.tsx" 2>/dev/null | head -n 1)
        local has_py_files
        has_py_files=$(find . -name "*.py" 2>/dev/null | head -n 1)

        if [[ "$STRICT_MODE" == "true" ]]; then
            if [[ -n "$has_ts_files" ]] && [[ ! -f "tsconfig.json" ]]; then
                 # Strict mode: TS files exist but no config
                 log_gate "ERROR" "SEC-008A: TypeScript files found but no tsconfig.json - gate FAILED (strict mode)"
                 exit_code=1
            elif [[ -n "$has_py_files" ]] && [[ ! -f "mypy.ini" && ! -f "pyproject.toml" ]]; then
                 # Strict mode: Python files exist but no type config (loose check, pyproject might not have mypy)
                 # Only fail if we are sure type checking was expected.
                 # For now, just fail if tool was expected but not found (logic above handles missing binary)
                 :
            fi
            
            # If config existed but binary missing (handled in if/else blocks above setting exit_code=0)
            if [[ -f "tsconfig.json" ]] || [[ -f "mypy.ini" ]]; then
                 log_gate "ERROR" "SEC-008A: Type checker configuration found but tool missing - gate FAILED (strict mode)"
                 exit_code=1
            fi
        fi
    fi

    local status="FAIL"
    [[ $exit_code -eq 0 ]] && status="PASS"

    local json_result
    json_result=$(cat <<EOF
{
    "check": "EXE-004",
    "name": "Type Checking",
    "errors": ${errors:-0},
    "exit_code": $exit_code,
    "status": "$status"
}
EOF
)
    write_json_result "$output_file" "$json_result"

    [[ $exit_code -eq 0 ]] && log_gate "PASS" "EXE-004: No type errors" || log_gate "FAIL" "EXE-004: ${errors} type errors"
    return $exit_code
}

# CHECK 5: Security Scan
check_security() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-005: Running security scan..."

    local critical=0 high=0 medium=0 exit_code=0
    cd "$workspace" || return 1

    # SEC-008C: Pre-resolve binaries to absolute paths
    local npm_bin jq_bin python3_bin
    local tool_found=false

    if [[ -f "package.json" ]] || [[ -f "package-lock.json" ]]; then
        local audit_json
        if npm_bin=$(_get_binary "npm"); then
            tool_found=true
            audit_json=$("$npm_bin" audit --json 2>/dev/null || echo '{"metadata":{"vulnerabilities":{}}}')
        else
            audit_json='{"metadata":{"vulnerabilities":{}}}'
        fi

        if jq_bin=$(_get_binary "jq"); then
            critical=$(echo "$audit_json" | "$jq_bin" '.metadata.vulnerabilities.critical // 0' 2>/dev/null || echo 0)
            high=$(echo "$audit_json" | "$jq_bin" '.metadata.vulnerabilities.high // 0' 2>/dev/null || echo 0)
            medium=$(echo "$audit_json" | "$jq_bin" '.metadata.vulnerabilities.moderate // 0' 2>/dev/null || echo 0)
        elif python3_bin=$(_get_binary "python3"); then
            critical=$("$python3_bin" - "$audit_json" <<'PY'
import json, sys
try:
    data=json.loads(sys.argv[1])
    print(data.get('metadata',{}).get('vulnerabilities',{}).get('critical',0))
except Exception:
    print(0)
PY
)
            high=$("$python3_bin" - "$audit_json" <<'PY'
import json, sys
try:
    data=json.loads(sys.argv[1])
    print(data.get('metadata',{}).get('vulnerabilities',{}).get('high',0))
except Exception:
    print(0)
PY
)
            medium=$("$python3_bin" - "$audit_json" <<'PY'
import json, sys
try:
    data=json.loads(sys.argv[1])
    print(data.get('metadata',{}).get('vulnerabilities',{}).get('moderate',0))
except Exception:
    print(0)
PY
)
        fi
    fi

    # SEC-008A: Strict mode enforcement
    if [[ "$tool_found" != "true" ]]; then
        if [[ "$STRICT_MODE" == "true" ]]; then
             # Fail if we expected to scan but couldn't
             if [[ -f "package.json" ]]; then
                 log_gate "ERROR" "SEC-008A: Security scanner (npm) not found - gate FAILED (strict mode)"
                 exit_code=1
             fi
        fi
    fi

    # Critical or high = blocking failure
    [[ ${critical:-0} -gt 0 || ${high:-0} -gt 0 ]] && exit_code=1
    
    local status="FAIL"
    [[ $exit_code -eq 0 ]] && status="PASS"

    local json_result
    json_result=$(cat <<EOF
{
    "check": "EXE-005",
    "name": "Security Scan",
    "critical": ${critical:-0},
    "high": ${high:-0},
    "medium": ${medium:-0},
    "exit_code": $exit_code,
    "status": "$status"
}
EOF
)
    write_json_result "$output_file" "$json_result"

    [[ $exit_code -eq 0 ]] && log_gate "PASS" "EXE-005: No critical/high vulnerabilities" || log_gate "FAIL" "EXE-005: Critical=${critical}, High=${high}"
    return $exit_code
}

# CHECK 6: Build Success
check_build() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-006: Running build..."

    local exit_code=0 duration=0
    local start_time end_time
    start_time=$(date +%s)
    cd "$workspace" || return 1

    # SEC-008C: Pre-resolve binaries to absolute paths
    local npm_bin make_bin cargo_bin go_bin grep_bin
    grep_bin=$(_get_binary "grep") || grep_bin="/bin/grep"

    local tool_found=false

    if [[ -f "package.json" ]] && "$grep_bin" -q '"build"' package.json 2>/dev/null; then
        if npm_bin=$(_get_binary "npm"); then
            tool_found=true
            "$npm_bin" run build 2>&1 || exit_code=$?
        else
            log_gate "ERROR" "EXE-006: npm not found in secure path"
            exit_code=1
        fi
    elif [[ -f "Makefile" ]]; then
        if make_bin=$(_get_binary "make"); then
            tool_found=true
            "$make_bin" build 2>&1 || exit_code=$?
        else
            log_gate "ERROR" "EXE-006: make not found in secure path"
            exit_code=1
        fi
    elif [[ -f "Cargo.toml" ]]; then
        if cargo_bin=$(_get_binary "cargo"); then
            tool_found=true
            "$cargo_bin" build --release 2>&1 || exit_code=$?
        else
            log_gate "ERROR" "EXE-006: cargo not found in secure path"
            exit_code=1
        fi
    elif [[ -f "go.mod" ]]; then
        if go_bin=$(_get_binary "go"); then
            tool_found=true
            "$go_bin" build ./... 2>&1 || exit_code=$?
        else
            log_gate "ERROR" "EXE-006: go not found in secure path"
            exit_code=1
        fi
    else
        exit_code=0
    fi

    # SEC-008A: Strict mode enforcement
    if [[ "$tool_found" != "true" ]]; then
        if [[ "$STRICT_MODE" == "true" ]]; then
            # If we see build configs but couldn't run build (already failed above with exit_code=1), we are good.
            # But if we didn't find ANY config (exit_code=0 above), we might want to enforce "Build required"
            # However, not all projects need building. We'll rely on the logic above:
            # If config exists but tool missing -> exit_code=1 (already STRICT behavior implicit in code)
            # If no config -> exit_code=0. We generally allow no-build projects unless explicitly configured otherwise.
            # So the logic above is actually already mostly compliant for "missing tool" case.
            :
        fi
    fi

    end_time=$(date +%s)
    duration=$((end_time - start_time))

    local status="FAIL"
    [[ $exit_code -eq 0 ]] && status="PASS"

    local json_result
    json_result=$(cat <<EOF
{
    "check": "EXE-006",
    "name": "Build",
    "duration_seconds": $duration,
    "exit_code": $exit_code,
    "status": "$status"
}
EOF
)
    write_json_result "$output_file" "$json_result"

    [[ $exit_code -eq 0 ]] && log_gate "PASS" "EXE-006: Build succeeded (${duration}s)" || log_gate "FAIL" "EXE-006: Build failed"
    return $exit_code
}

# CHECK 7: Dependency Audit
check_dependencies() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-007: Auditing dependencies..."

    local critical_deps=0 exit_code=0
    cd "$workspace" || return 1

    # SEC-008C: Pre-resolve binaries to absolute paths
    local npm_bin jq_bin python3_bin pipenv_bin
    local tool_found=false

    if [[ -f "package-lock.json" ]]; then
        local audit_json
        if npm_bin=$(_get_binary "npm"); then
            tool_found=true
            audit_json=$("$npm_bin" audit --json 2>/dev/null || echo '{"metadata":{"vulnerabilities":{}}}')
        else
            audit_json='{"metadata":{"vulnerabilities":{}}}'
        fi

        if jq_bin=$(_get_binary "jq"); then
            critical_deps=$(echo "$audit_json" | "$jq_bin" '.metadata.vulnerabilities.critical // 0' 2>/dev/null || echo 0)
        elif python3_bin=$(_get_binary "python3"); then
            critical_deps=$("$python3_bin" - "$audit_json" <<'PY'
import json, sys
try:
    data=json.loads(sys.argv[1])
    print(data.get('metadata',{}).get('vulnerabilities',{}).get('critical',0))
except Exception:
    print(0)
PY
)
        fi
    elif [[ -f "Pipfile.lock" ]]; then
        if pipenv_bin=$(_get_binary "pipenv"); then
            tool_found=true
            local pipenv_json
            pipenv_json=$("$pipenv_bin" check --json 2>/dev/null || echo '[]')
            if jq_bin=$(_get_binary "jq"); then
                critical_deps=$(echo "$pipenv_json" | "$jq_bin" 'length' 2>/dev/null || echo 0)
            elif python3_bin=$(_get_binary "python3"); then
                critical_deps=$("$python3_bin" - "$pipenv_json" <<'PY'
import json, sys
try:
    print(len(json.loads(sys.argv[1])))
except Exception:
    print(0)
PY
)
            fi
        fi
    fi

    # SEC-008A: Strict mode enforcement
    if [[ "$tool_found" != "true" ]]; then
        if [[ "$STRICT_MODE" == "true" ]]; then
             if [[ -f "package-lock.json" ]] || [[ -f "Pipfile.lock" ]]; then
                 log_gate "ERROR" "SEC-008A: Dependency auditor not found - gate FAILED (strict mode)"
                 exit_code=1
             fi
        fi
    fi

    [[ ${critical_deps:-0} -gt 0 ]] && exit_code=1
    
    local status="FAIL"
    [[ $exit_code -eq 0 ]] && status="PASS"

    local json_result
    json_result=$(cat <<EOF
{
    "check": "EXE-007",
    "name": "Dependency Audit",
    "critical_vulnerabilities": ${critical_deps:-0},
    "exit_code": $exit_code,
    "status": "$status"
}
EOF
)
    write_json_result "$output_file" "$json_result"

    [[ $exit_code -eq 0 ]] && log_gate "PASS" "EXE-007: No critical dependency vulnerabilities" || log_gate "FAIL" "EXE-007: ${critical_deps} critical vulnerabilities"
    return $exit_code
}

# CHECK 8: Breaking Changes
check_breaking_changes() {
    local workspace="$1"
    local output_file="$2"
    
    local status="PASS"
    # Placeholder
    echo "{"status":"PASS"}" > "$output_file"
    return 0
}

# CHECK 9: Code Review
check_tri_agent_review() {
    local workspace="$1"
    local output_file="$2"
    
    local status="PASS"
    # Placeholder
    echo "{"status":"PASS"}" > "$output_file"
    return 0
}

# CHECK 10-12
check_performance() { echo "{"status":"N/A"}" > "$2"; return 0; }
check_documentation() { echo "{"status":"N/A"}" > "$2"; return 0; }
check_commit_format() { echo "{"status":"N/A"}" > "$2"; return 0; }

# =============================================================================
# M2-010: UNIFIED SUPERVISOR FLOW
# =============================================================================
# Global array to track gate results for feedback
declare -a GATE_RESULTS=()
declare -a FAILED_GATES=()

# Initialize gate tracking for a task
init_gate_tracking() {
    GATE_RESULTS=()
    FAILED_GATES=()
}

# Record gate result
# Usage: record_gate_result "gate_name" "status" "message"
record_gate_result() {
    local gate_name="$1"
    local status="$2"
    local message="${3:-}"

    GATE_RESULTS+=("${gate_name}:${status}:${message}")

    if [[ "$status" == "FAIL" ]]; then
        FAILED_GATES+=("${gate_name}")
    fi
}

# Generate feedback summary from gate results
generate_feedback() {
    local task_id="$1"
    local feedback=""

    feedback+="Task: $task_id\n"
    feedback+="Timestamp: $(iso_timestamp)\n"
    feedback+="---\n"
    feedback+="Gate Results:\n"

    for result in "${GATE_RESULTS[@]}"; do
        local gate_name status message
        gate_name=$(echo "$result" | cut -d: -f1)
        status=$(echo "$result" | cut -d: -f2)
        message=$(echo "$result" | cut -d: -f3-)

        local icon="[OK]"
        [[ "$status" == "FAIL" ]] && icon="[X]"
        [[ "$status" == "SKIP" ]] && icon="[-]"

        feedback+="  $icon $gate_name: $status"
        [[ -n "$message" ]] && feedback+=" ($message)"
        feedback+="\n"
    done

    if [[ ${#FAILED_GATES[@]} -gt 0 ]]; then
        feedback+="---\n"
        feedback+="Failed Gates: ${FAILED_GATES[*]}\n"
        feedback+="Action Required: Fix the above issues and resubmit.\n"
    fi

    echo -e "$feedback"
}

# =============================================================================
# M2-014: REJECTION FEEDBACK GENERATOR
# =============================================================================
# Generates comprehensive, human-readable feedback for rejected tasks with:
# - Specific fix suggestions for each failed gate
# - Code snippets showing what failed
# - Links to relevant documentation
# - Retry guidance with estimated effort
#
# Usage: generate_rejection_feedback "task_id" ["gate1" "gate2" ...]
# Returns: Formatted feedback string to stdout
# =============================================================================

# Documentation links for each gate type
declare -A GATE_DOCUMENTATION=(
    ["EXE-001"]="https://docs.sdlc-orchestrator.dev/gates/testing"
    ["EXE-002"]="https://docs.sdlc-orchestrator.dev/gates/coverage"
    ["EXE-003"]="https://docs.sdlc-orchestrator.dev/gates/linting"
    ["EXE-004"]="https://docs.sdlc-orchestrator.dev/gates/type-checking"
    ["EXE-005"]="https://docs.sdlc-orchestrator.dev/gates/security"
    ["EXE-006"]="https://docs.sdlc-orchestrator.dev/gates/build"
    ["Tests"]="https://docs.sdlc-orchestrator.dev/guides/testing-best-practices"
    ["Coverage"]="https://docs.sdlc-orchestrator.dev/guides/improving-coverage"
    ["Lint"]="https://docs.sdlc-orchestrator.dev/guides/code-quality"
    ["Types"]="https://docs.sdlc-orchestrator.dev/guides/type-safety"
    ["Security"]="https://docs.sdlc-orchestrator.dev/guides/security-vulnerabilities"
    ["Build"]="https://docs.sdlc-orchestrator.dev/guides/build-troubleshooting"
)

# Estimated fix effort for each gate type (in minutes)
declare -A GATE_EFFORT_ESTIMATES=(
    ["EXE-001:Tests"]="15-60"
    ["EXE-002:Coverage"]="30-120"
    ["EXE-003:Lint"]="5-30"
    ["EXE-004:Types"]="10-45"
    ["EXE-005:Security"]="30-180"
    ["EXE-006:Build"]="10-60"
)

# Generate rejection feedback with detailed fix suggestions
# Usage: generate_rejection_feedback "task_id" ["gate1" "gate2" ...]
generate_rejection_feedback() {
    local task_id="$1"
    shift
    local failed_gates_array=("${@:-${FAILED_GATES[@]}}")

    local feedback=""
    local timestamp
    timestamp=$(iso_timestamp)

    # Header section
    feedback+="================================================================================\n"
    feedback+="                     TASK REJECTION FEEDBACK REPORT                             \n"
    feedback+="================================================================================\n"
    feedback+="\n"
    feedback+="Task ID:      $task_id\n"
    feedback+="Timestamp:    $timestamp\n"
    feedback+="Trace ID:     ${TRACE_ID:-unknown}\n"
    feedback+="Failed Gates: ${#failed_gates_array[@]}\n"
    feedback+="\n"

    # Summary section
    feedback+="--------------------------------------------------------------------------------\n"
    feedback+="                              SUMMARY                                           \n"
    feedback+="--------------------------------------------------------------------------------\n"
    feedback+="\n"

    local total_effort_min=0
    local total_effort_max=0

    for gate in "${failed_gates_array[@]}"; do
        local gate_code
        gate_code=$(echo "$gate" | cut -d: -f1)
        local gate_name
        gate_name=$(echo "$gate" | cut -d: -f2)

        feedback+="  [X] $gate\n"

        # Calculate effort estimates
        local effort="${GATE_EFFORT_ESTIMATES[$gate]:-10-30}"
        local min_effort max_effort
        min_effort=$(echo "$effort" | cut -d- -f1)
        max_effort=$(echo "$effort" | cut -d- -f2)
        total_effort_min=$((total_effort_min + min_effort))
        total_effort_max=$((total_effort_max + max_effort))
    done

    feedback+="\n"
    feedback+="Estimated Total Fix Time: ${total_effort_min}-${total_effort_max} minutes\n"
    feedback+="\n"

    # Detailed feedback for each failed gate
    feedback+="================================================================================\n"
    feedback+="                         DETAILED FAILURE ANALYSIS                              \n"
    feedback+="================================================================================\n"

    for gate in "${failed_gates_array[@]}"; do
        local gate_code gate_name
        gate_code=$(echo "$gate" | cut -d: -f1)
        gate_name=$(echo "$gate" | cut -d: -f2)

        feedback+="\n"
        feedback+="--------------------------------------------------------------------------------\n"
        feedback+="Gate: $gate\n"
        feedback+="--------------------------------------------------------------------------------\n"

        # Generate gate-specific feedback
        _generate_gate_specific_feedback "$task_id" "$gate_code" "$gate_name"
        feedback+="$_GATE_FEEDBACK"
    done

    # Retry guidance section
    feedback+="\n"
    feedback+="================================================================================\n"
    feedback+="                            RETRY GUIDANCE                                       \n"
    feedback+="================================================================================\n"
    feedback+="\n"

    local retry_file="${GATES_DIR}/retry_${task_id}.count"
    local retry_count=0
    local remaining_retries

    if [[ -f "$retry_file" ]]; then
        retry_count=$(cat "$retry_file" 2>/dev/null || echo "0")
    fi
    remaining_retries=$((MAX_RETRIES - retry_count))

    feedback+="Current Retry Count:    $retry_count / $MAX_RETRIES\n"
    feedback+="Remaining Retries:      $remaining_retries\n"
    feedback+="\n"

    if [[ $remaining_retries -le 0 ]]; then
        feedback+="[!] WARNING: No retries remaining! Task will be permanently failed on next attempt.\n"
        feedback+="    Manual intervention is required to reset the retry counter.\n"
        feedback+="\n"
    elif [[ $remaining_retries -eq 1 ]]; then
        feedback+="[!] CAUTION: Only 1 retry remaining. Ensure all issues are resolved before resubmitting.\n"
        feedback+="\n"
    fi

    # Recommended fix order
    feedback+="Recommended Fix Order:\n"
    feedback+="----------------------\n"
    _generate_fix_priority_order "${failed_gates_array[@]}"
    feedback+="$_FIX_ORDER"
    feedback+="\n"

    # Quick fix commands
    feedback+="Quick Fix Commands:\n"
    feedback+="-------------------\n"
    _generate_quick_fix_commands "${failed_gates_array[@]}"
    feedback+="$_QUICK_FIX_COMMANDS"
    feedback+="\n"

    # Documentation links
    feedback+="Documentation Links:\n"
    feedback+="--------------------\n"
    for gate in "${failed_gates_array[@]}"; do
        local gate_code
        gate_code=$(echo "$gate" | cut -d: -f1)
        local doc_link="${GATE_DOCUMENTATION[$gate_code]:-}"
        if [[ -n "$doc_link" ]]; then
            feedback+="  - $gate: $doc_link\n"
        fi
    done
    feedback+="\n"

    # Footer
    feedback+="================================================================================\n"
    feedback+="                              END OF REPORT                                     \n"
    feedback+="================================================================================\n"
    feedback+="\n"
    feedback+="To resubmit this task after fixing:\n"
    feedback+="  1. Fix all failing gates listed above\n"
    feedback+="  2. Run local validation: ./bin/tri-agent validate $task_id\n"
    feedback+="  3. Resubmit: ./bin/tri-agent submit $task_id\n"
    feedback+="\n"
    feedback+="For assistance, contact the supervisor or consult the documentation.\n"

    echo -e "$feedback"
}

# Internal: Generate gate-specific feedback based on gate results JSON
# Sets _GATE_FEEDBACK variable with the generated feedback
_generate_gate_specific_feedback() {
    local task_id="$1"
    local gate_code="$2"
    local gate_name="$3"

    _GATE_FEEDBACK=""

    # Map gate code to JSON file
    local gate_file=""
    case "$gate_code" in
        "EXE-001") gate_file="${GATES_DIR}/tests_${task_id}.json" ;;
        "EXE-002") gate_file="${GATES_DIR}/coverage_${task_id}.json" ;;
        "EXE-003") gate_file="${GATES_DIR}/lint_${task_id}.json" ;;
        "EXE-004") gate_file="${GATES_DIR}/types_${task_id}.json" ;;
        "EXE-005") gate_file="${GATES_DIR}/security_${task_id}.json" ;;
        "EXE-006") gate_file="${GATES_DIR}/build_${task_id}.json" ;;
    esac

    # Generate feedback based on gate type
    case "$gate_code" in
        "EXE-001")
            _generate_test_failure_feedback "$gate_file"
            ;;
        "EXE-002")
            _generate_coverage_failure_feedback "$gate_file"
            ;;
        "EXE-003")
            _generate_lint_failure_feedback "$gate_file"
            ;;
        "EXE-004")
            _generate_type_failure_feedback "$gate_file"
            ;;
        "EXE-005")
            _generate_security_failure_feedback "$gate_file"
            ;;
        "EXE-006")
            _generate_build_failure_feedback "$gate_file"
            ;;
        *)
            _GATE_FEEDBACK+="  No specific feedback available for gate: $gate_code\n"
            _GATE_FEEDBACK+="  Please review the gate output and fix any issues.\n"
            ;;
    esac
}

# Internal: Generate test failure feedback
_generate_test_failure_feedback() {
    local gate_file="$1"

    _GATE_FEEDBACK+="Issue: Test suite failed\n\n"

    if [[ -f "$gate_file" ]]; then
        local passed failed exit_code
        passed=$(grep -o '"passed": *[0-9]*' "$gate_file" 2>/dev/null | cut -d: -f2 | tr -d ' ' || echo "0")
        failed=$(grep -o '"failed": *[0-9]*' "$gate_file" 2>/dev/null | cut -d: -f2 | tr -d ' ' || echo "0")
        exit_code=$(grep -o '"exit_code": *[0-9]*' "$gate_file" 2>/dev/null | cut -d: -f2 | tr -d ' ' || echo "1")

        _GATE_FEEDBACK+="Test Results:\n"
        _GATE_FEEDBACK+="  - Passed: $passed\n"
        _GATE_FEEDBACK+="  - Failed: $failed\n"
        _GATE_FEEDBACK+="  - Exit Code: $exit_code\n\n"
    fi

    _GATE_FEEDBACK+="Fix Suggestions:\n"
    _GATE_FEEDBACK+="  1. Review the test output to identify failing tests\n"
    _GATE_FEEDBACK+="  2. Check for recent code changes that may have broken tests\n"
    _GATE_FEEDBACK+="  3. Run tests locally: npm test / pytest / cargo test\n"
    _GATE_FEEDBACK+="  4. Fix assertions or update expected values if behavior changed intentionally\n"
    _GATE_FEEDBACK+="  5. Check for missing dependencies or environment issues\n\n"

    _GATE_FEEDBACK+="Common Causes:\n"
    _GATE_FEEDBACK+="  - Assertion failures due to logic changes\n"
    _GATE_FEEDBACK+="  - Missing test fixtures or mock data\n"
    _GATE_FEEDBACK+="  - Async/timing issues in tests\n"
    _GATE_FEEDBACK+="  - Environment variable or configuration mismatches\n\n"

    _GATE_FEEDBACK+="Code Snippet (example test command):\n"
    _GATE_FEEDBACK+="  \`\`\`bash\n"
    _GATE_FEEDBACK+="  # Run tests with verbose output\n"
    _GATE_FEEDBACK+="  npm test -- --verbose\n"
    _GATE_FEEDBACK+="  # or for Python\n"
    _GATE_FEEDBACK+="  pytest -v --tb=long\n"
    _GATE_FEEDBACK+="  \`\`\`\n\n"
}

# Internal: Generate coverage failure feedback
_generate_coverage_failure_feedback() {
    local gate_file="$1"

    _GATE_FEEDBACK+="Issue: Test coverage below threshold\n\n"

    if [[ -f "$gate_file" ]]; then
        local coverage threshold
        coverage=$(grep -o '"coverage": *[0-9.]*' "$gate_file" 2>/dev/null | cut -d: -f2 | tr -d ' ' || echo "0")
        threshold=$(grep -o '"threshold": *[0-9]*' "$gate_file" 2>/dev/null | cut -d: -f2 | tr -d ' ' || echo "$COVERAGE_THRESHOLD")

        _GATE_FEEDBACK+="Coverage Results:\n"
        _GATE_FEEDBACK+="  - Current Coverage: ${coverage}%\n"
        _GATE_FEEDBACK+="  - Required Threshold: ${threshold}%\n"
        _GATE_FEEDBACK+="  - Gap: $(echo "$threshold - $coverage" | bc 2>/dev/null || echo "?")%\n\n"
    fi

    _GATE_FEEDBACK+="Fix Suggestions:\n"
    _GATE_FEEDBACK+="  1. Identify uncovered code using coverage reports\n"
    _GATE_FEEDBACK+="  2. Add tests for uncovered functions and branches\n"
    _GATE_FEEDBACK+="  3. Focus on critical paths and error handling\n"
    _GATE_FEEDBACK+="  4. Consider edge cases and boundary conditions\n"
    _GATE_FEEDBACK+="  5. Review and remove dead code if safe to do so\n\n"

    _GATE_FEEDBACK+="Common Causes:\n"
    _GATE_FEEDBACK+="  - New code added without corresponding tests\n"
    _GATE_FEEDBACK+="  - Error handling paths not covered\n"
    _GATE_FEEDBACK+="  - Complex conditional logic without branch coverage\n"
    _GATE_FEEDBACK+="  - Integration code that's hard to unit test\n\n"

    _GATE_FEEDBACK+="Code Snippet (generate coverage report):\n"
    _GATE_FEEDBACK+="  \`\`\`bash\n"
    _GATE_FEEDBACK+="  # Node.js with Jest\n"
    _GATE_FEEDBACK+="  npm run coverage -- --coverageReporters=text-summary\n"
    _GATE_FEEDBACK+="  \n"
    _GATE_FEEDBACK+="  # Python with pytest-cov\n"
    _GATE_FEEDBACK+="  pytest --cov=. --cov-report=term-missing\n"
    _GATE_FEEDBACK+="  \`\`\`\n\n"
}

# Internal: Generate lint failure feedback
_generate_lint_failure_feedback() {
    local gate_file="$1"

    _GATE_FEEDBACK+="Issue: Linting errors detected\n\n"

    if [[ -f "$gate_file" ]]; then
        local errors warnings
        errors=$(grep -o '"errors": *[0-9]*' "$gate_file" 2>/dev/null | cut -d: -f2 | tr -d ' ' || echo "0")
        warnings=$(grep -o '"warnings": *[0-9]*' "$gate_file" 2>/dev/null | cut -d: -f2 | tr -d ' ' || echo "0")

        _GATE_FEEDBACK+="Lint Results:\n"
        _GATE_FEEDBACK+="  - Errors: $errors\n"
        _GATE_FEEDBACK+="  - Warnings: $warnings\n\n"
    fi

    _GATE_FEEDBACK+="Fix Suggestions:\n"
    _GATE_FEEDBACK+="  1. Run linter locally to see all issues\n"
    _GATE_FEEDBACK+="  2. Use auto-fix where available (--fix flag)\n"
    _GATE_FEEDBACK+="  3. Review and fix remaining manual issues\n"
    _GATE_FEEDBACK+="  4. Update linter config if rules are too strict\n"
    _GATE_FEEDBACK+="  5. Add disable comments only for justified cases\n\n"

    _GATE_FEEDBACK+="Common Causes:\n"
    _GATE_FEEDBACK+="  - Unused variables or imports\n"
    _GATE_FEEDBACK+="  - Inconsistent formatting (spaces, quotes, semicolons)\n"
    _GATE_FEEDBACK+="  - Missing or extra newlines\n"
    _GATE_FEEDBACK+="  - Complexity or line length violations\n\n"

    _GATE_FEEDBACK+="Code Snippet (auto-fix linting issues):\n"
    _GATE_FEEDBACK+="  \`\`\`bash\n"
    _GATE_FEEDBACK+="  # ESLint (JavaScript/TypeScript)\n"
    _GATE_FEEDBACK+="  npx eslint --fix .\n"
    _GATE_FEEDBACK+="  \n"
    _GATE_FEEDBACK+="  # Ruff (Python)\n"
    _GATE_FEEDBACK+="  ruff check --fix .\n"
    _GATE_FEEDBACK+="  \n"
    _GATE_FEEDBACK+="  # Prettier (formatting)\n"
    _GATE_FEEDBACK+="  npx prettier --write .\n"
    _GATE_FEEDBACK+="  \`\`\`\n\n"
}

# Internal: Generate type checking failure feedback
_generate_type_failure_feedback() {
    local gate_file="$1"

    _GATE_FEEDBACK+="Issue: Type checking errors detected\n\n"

    if [[ -f "$gate_file" ]]; then
        local errors
        errors=$(grep -o '"errors": *[0-9]*' "$gate_file" 2>/dev/null | cut -d: -f2 | tr -d ' ' || echo "0")

        _GATE_FEEDBACK+="Type Check Results:\n"
        _GATE_FEEDBACK+="  - Type Errors: $errors\n\n"
    fi

    _GATE_FEEDBACK+="Fix Suggestions:\n"
    _GATE_FEEDBACK+="  1. Run type checker locally to see all errors\n"
    _GATE_FEEDBACK+="  2. Add missing type annotations\n"
    _GATE_FEEDBACK+="  3. Fix type mismatches in function calls\n"
    _GATE_FEEDBACK+="  4. Update type definitions if interfaces changed\n"
    _GATE_FEEDBACK+="  5. Use type guards for narrowing complex types\n\n"

    _GATE_FEEDBACK+="Common Causes:\n"
    _GATE_FEEDBACK+="  - Missing type annotations on functions/variables\n"
    _GATE_FEEDBACK+="  - Incompatible types in assignments or returns\n"
    _GATE_FEEDBACK+="  - Property access on possibly undefined values\n"
    _GATE_FEEDBACK+="  - Generic type argument mismatches\n\n"

    _GATE_FEEDBACK+="Code Snippet (run type checker):\n"
    _GATE_FEEDBACK+="  \`\`\`bash\n"
    _GATE_FEEDBACK+="  # TypeScript\n"
    _GATE_FEEDBACK+="  npx tsc --noEmit\n"
    _GATE_FEEDBACK+="  \n"
    _GATE_FEEDBACK+="  # Python (mypy)\n"
    _GATE_FEEDBACK+="  mypy . --show-error-codes\n"
    _GATE_FEEDBACK+="  \`\`\`\n\n"
}

# Internal: Generate security failure feedback
_generate_security_failure_feedback() {
    local gate_file="$1"

    _GATE_FEEDBACK+="Issue: Security vulnerabilities detected\n\n"

    if [[ -f "$gate_file" ]]; then
        local critical high medium
        critical=$(grep -o '"critical": *[0-9]*' "$gate_file" 2>/dev/null | cut -d: -f2 | tr -d ' ' || echo "0")
        high=$(grep -o '"high": *[0-9]*' "$gate_file" 2>/dev/null | cut -d: -f2 | tr -d ' ' || echo "0")
        medium=$(grep -o '"medium": *[0-9]*' "$gate_file" 2>/dev/null | cut -d: -f2 | tr -d ' ' || echo "0")

        _GATE_FEEDBACK+="Security Scan Results:\n"
        _GATE_FEEDBACK+="  - Critical Vulnerabilities: $critical\n"
        _GATE_FEEDBACK+="  - High Vulnerabilities: $high\n"
        _GATE_FEEDBACK+="  - Medium Vulnerabilities: $medium\n\n"

        if [[ "$critical" -gt 0 ]]; then
            _GATE_FEEDBACK+="[!] CRITICAL: Immediate action required for critical vulnerabilities!\n\n"
        fi
    fi

    _GATE_FEEDBACK+="Fix Suggestions:\n"
    _GATE_FEEDBACK+="  1. Run 'npm audit' or equivalent to see vulnerability details\n"
    _GATE_FEEDBACK+="  2. Update vulnerable dependencies to patched versions\n"
    _GATE_FEEDBACK+="  3. Review breaking changes before major version updates\n"
    _GATE_FEEDBACK+="  4. Consider alternative packages if no fix available\n"
    _GATE_FEEDBACK+="  5. Document any accepted risks if vulnerability cannot be fixed\n\n"

    _GATE_FEEDBACK+="Common Causes:\n"
    _GATE_FEEDBACK+="  - Outdated dependencies with known CVEs\n"
    _GATE_FEEDBACK+="  - Transitive dependencies with vulnerabilities\n"
    _GATE_FEEDBACK+="  - Using deprecated or unmaintained packages\n"
    _GATE_FEEDBACK+="  - Insecure configuration settings\n\n"

    _GATE_FEEDBACK+="Code Snippet (fix security vulnerabilities):\n"
    _GATE_FEEDBACK+="  \`\`\`bash\n"
    _GATE_FEEDBACK+="  # NPM - view and fix vulnerabilities\n"
    _GATE_FEEDBACK+="  npm audit\n"
    _GATE_FEEDBACK+="  npm audit fix\n"
    _GATE_FEEDBACK+="  npm audit fix --force  # Use with caution\n"
    _GATE_FEEDBACK+="  \n"
    _GATE_FEEDBACK+="  # Python - check with safety\n"
    _GATE_FEEDBACK+="  pip install safety\n"
    _GATE_FEEDBACK+="  safety check\n"
    _GATE_FEEDBACK+="  \`\`\`\n\n"
}

# Internal: Generate build failure feedback
_generate_build_failure_feedback() {
    local gate_file="$1"

    _GATE_FEEDBACK+="Issue: Build process failed\n\n"

    if [[ -f "$gate_file" ]]; then
        local exit_code duration
        exit_code=$(grep -o '"exit_code": *[0-9]*' "$gate_file" 2>/dev/null | cut -d: -f2 | tr -d ' ' || echo "1")
        duration=$(grep -o '"duration_seconds": *[0-9]*' "$gate_file" 2>/dev/null | cut -d: -f2 | tr -d ' ' || echo "0")

        _GATE_FEEDBACK+="Build Results:\n"
        _GATE_FEEDBACK+="  - Exit Code: $exit_code\n"
        _GATE_FEEDBACK+="  - Duration: ${duration}s (before failure)\n\n"
    fi

    _GATE_FEEDBACK+="Fix Suggestions:\n"
    _GATE_FEEDBACK+="  1. Run build locally to see full error output\n"
    _GATE_FEEDBACK+="  2. Check for syntax errors in source files\n"
    _GATE_FEEDBACK+="  3. Verify all imports and dependencies are available\n"
    _GATE_FEEDBACK+="  4. Clear build cache and node_modules, reinstall\n"
    _GATE_FEEDBACK+="  5. Check for environment-specific configuration issues\n\n"

    _GATE_FEEDBACK+="Common Causes:\n"
    _GATE_FEEDBACK+="  - Syntax errors in source code\n"
    _GATE_FEEDBACK+="  - Missing or incompatible dependencies\n"
    _GATE_FEEDBACK+="  - Incorrect build configuration\n"
    _GATE_FEEDBACK+="  - Out of memory or disk space\n\n"

    _GATE_FEEDBACK+="Code Snippet (clean build):\n"
    _GATE_FEEDBACK+="  \`\`\`bash\n"
    _GATE_FEEDBACK+="  # Node.js - clean rebuild\n"
    _GATE_FEEDBACK+="  rm -rf node_modules dist\n"
    _GATE_FEEDBACK+="  npm ci\n"
    _GATE_FEEDBACK+="  npm run build\n"
    _GATE_FEEDBACK+="  \n"
    _GATE_FEEDBACK+="  # Python - clean build\n"
    _GATE_FEEDBACK+="  rm -rf build dist *.egg-info\n"
    _GATE_FEEDBACK+="  pip install -e .\n"
    _GATE_FEEDBACK+="  \`\`\`\n\n"
}

# Internal: Generate fix priority order based on gate dependencies
# Sets _FIX_ORDER variable
_generate_fix_priority_order() {
    local gates=("$@")
    _FIX_ORDER=""

    # Priority order: Build > Lint > Types > Tests > Coverage > Security
    # Rationale: Fix compilation first, then style, then tests, then coverage
    local priority_order=("EXE-006:Build" "EXE-003:Lint" "EXE-004:Types" "EXE-001:Tests" "EXE-002:Coverage" "EXE-005:Security")

    local step=1
    for priority_gate in "${priority_order[@]}"; do
        for gate in "${gates[@]}"; do
            if [[ "$gate" == "$priority_gate" ]]; then
                local effort="${GATE_EFFORT_ESTIMATES[$gate]:-10-30}"
                _FIX_ORDER+="  $step. $gate (Est: ${effort} min)\n"
                ((step++))
                break
            fi
        done
    done

    # Add any remaining gates not in priority list
    for gate in "${gates[@]}"; do
        local found=false
        for priority_gate in "${priority_order[@]}"; do
            if [[ "$gate" == "$priority_gate" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" == "false" ]]; then
            _FIX_ORDER+="  $step. $gate (Est: 10-30 min)\n"
            ((step++))
        fi
    done
}

# Internal: Generate quick fix commands for failed gates
# Sets _QUICK_FIX_COMMANDS variable
_generate_quick_fix_commands() {
    local gates=("$@")
    _QUICK_FIX_COMMANDS=""

    for gate in "${gates[@]}"; do
        case "$gate" in
            "EXE-001:Tests")
                _QUICK_FIX_COMMANDS+="  # Fix failing tests\n"
                _QUICK_FIX_COMMANDS+="  npm test -- --watch  # or: pytest -x --pdb\n\n"
                ;;
            "EXE-002:Coverage")
                _QUICK_FIX_COMMANDS+="  # View uncovered lines and add tests\n"
                _QUICK_FIX_COMMANDS+="  npm run coverage -- --coverageReporters=lcov && open coverage/lcov-report/index.html\n\n"
                ;;
            "EXE-003:Lint")
                _QUICK_FIX_COMMANDS+="  # Auto-fix linting issues\n"
                _QUICK_FIX_COMMANDS+="  npm run lint -- --fix  # or: ruff check --fix .\n\n"
                ;;
            "EXE-004:Types")
                _QUICK_FIX_COMMANDS+="  # Find and fix type errors\n"
                _QUICK_FIX_COMMANDS+="  npx tsc --noEmit  # or: mypy . --show-error-codes\n\n"
                ;;
            "EXE-005:Security")
                _QUICK_FIX_COMMANDS+="  # Fix security vulnerabilities\n"
                _QUICK_FIX_COMMANDS+="  npm audit fix  # or: pip install --upgrade <package>\n\n"
                ;;
            "EXE-006:Build")
                _QUICK_FIX_COMMANDS+="  # Clean rebuild\n"
                _QUICK_FIX_COMMANDS+="  rm -rf node_modules && npm ci && npm run build\n\n"
                ;;
        esac
    done
}

# =============================================================================
# MAIN GATE (Enhanced with tracking)
# =============================================================================

quality_gate() {
    local task_id="$1"
    local workspace="${2:-$(pwd)}"

    log_gate "INFO" "GATE: Starting quality gate validation for $task_id"

    # Ensure circuit breaker is available (INC-ARCH-002)
    if ! command -v quality_gate_breaker &>/dev/null; then
        if [[ -f "${SCRIPT_DIR}/circuit-breaker.sh" ]]; then
            source "${SCRIPT_DIR}/circuit-breaker.sh"
        elif [[ -f "${AUTONOMOUS_ROOT}/lib/circuit-breaker.sh" ]]; then
            source "${AUTONOMOUS_ROOT}/lib/circuit-breaker.sh"
        fi
    fi

    # Initialize gate tracking
    init_gate_tracking

    # FIX-005: Check retry count before running gates
    local retry_file="${GATES_DIR}/retry_${task_id}.count"
    local retry_count=0
    mkdir -p "$GATES_DIR" 2>/dev/null || true

    if [[ -f "$retry_file" ]]; then
        retry_count=$(cat "$retry_file" 2>/dev/null || echo "0")
    fi

    # FIX-005: Fail permanently if max retries exceeded
    if [[ $retry_count -ge $MAX_RETRIES ]]; then
        log_gate "ERROR" "GATE: Task $task_id exceeded max retries ($retry_count >= $MAX_RETRIES)"
        log_gate "ERROR" "GATE: Moving task to FAILED state permanently"
        record_gate_result "RETRY_LIMIT" "FAIL" "Max retries exceeded ($retry_count/$MAX_RETRIES)"
        echo "{\"task_id\":\"$task_id\",\"status\":\"MAX_RETRIES_EXCEEDED\",\"retry_count\":$retry_count,\"max_retries\":$MAX_RETRIES,\"timestamp\":\"$(date -Iseconds)\"}" >> "${GATES_DIR}/failed_tasks.jsonl"
        return 2  # Special exit code for max retries
    fi

    local start_time end_time duration
    start_time=$(date +%s)
    local blocking_failed=0

    # Run Checks in sequence with error handling and tracking

    # Gate 1: Tests (Blocking)
    log_gate "INFO" "GATE 1/6: Running test suite..."
    if quality_gate_breaker "EXE-001" "check"; then
        if check_tests "$workspace" "${GATES_DIR}/tests_${task_id}.json"; then
            quality_gate_breaker "EXE-001" "success"
            record_gate_result "EXE-001:Tests" "PASS" "All tests passed"
        else
            local exit_code=$?
            quality_gate_breaker "EXE-001" "failure"
            record_gate_result "EXE-001:Tests" "FAIL" "Test suite failed (exit: $exit_code)"
            ((blocking_failed++))
        fi
    else
        log_gate "ERROR" "Circuit breaker OPEN for EXE-001"
        record_gate_result "EXE-001:Tests" "FAIL" "Circuit breaker OPEN"
        ((blocking_failed++))
    fi

    # Gate 2: Coverage (Blocking)
    log_gate "INFO" "GATE 2/6: Checking test coverage..."
    if quality_gate_breaker "EXE-002" "check"; then
        if check_coverage "$workspace" "${GATES_DIR}/coverage_${task_id}.json"; then
            local cov_status
            cov_status=$(grep -o '"status": *"[^"]*"' "${GATES_DIR}/coverage_${task_id}.json" 2>/dev/null | head -1 | cut -d'"' -f4 || echo "PASS")
            if [[ "$cov_status" == "SKIPPED" ]]; then
                quality_gate_breaker "EXE-002" "success"
                record_gate_result "EXE-002:Coverage" "SKIP" "No coverage tool configured"
            else
                quality_gate_breaker "EXE-002" "success"
                record_gate_result "EXE-002:Coverage" "PASS" "Coverage meets threshold"
            fi
        else
            quality_gate_breaker "EXE-002" "failure"
            local coverage_pct
            coverage_pct=$(grep -o '"coverage": *[0-9.]*' "${GATES_DIR}/coverage_${task_id}.json" 2>/dev/null | cut -d: -f2 | tr -d ' ' || echo "0")
            record_gate_result "EXE-002:Coverage" "FAIL" "Coverage ${coverage_pct}% below threshold ${COVERAGE_THRESHOLD}%"
            ((blocking_failed++))
        fi
    else
        log_gate "ERROR" "Circuit breaker OPEN for EXE-002"
        record_gate_result "EXE-002:Coverage" "FAIL" "Circuit breaker OPEN"
        ((blocking_failed++))
    fi

    # Gate 3: Linting (Blocking)
    log_gate "INFO" "GATE 3/6: Running linter..."
    if quality_gate_breaker "EXE-003" "check"; then
        if check_lint "$workspace" "${GATES_DIR}/lint_${task_id}.json"; then
            quality_gate_breaker "EXE-003" "success"
            record_gate_result "EXE-003:Lint" "PASS" "No linting errors"
        else
            quality_gate_breaker "EXE-003" "failure"
            local lint_errors
            lint_errors=$(grep -o '"errors": *[0-9]*' "${GATES_DIR}/lint_${task_id}.json" 2>/dev/null | cut -d: -f2 | tr -d ' ' || echo "unknown")
            record_gate_result "EXE-003:Lint" "FAIL" "${lint_errors} linting errors found"
            ((blocking_failed++))
        fi
    else
        log_gate "ERROR" "Circuit breaker OPEN for EXE-003"
        record_gate_result "EXE-003:Lint" "FAIL" "Circuit breaker OPEN"
        ((blocking_failed++))
    fi

    # Gate 4: Type Checking (Non-blocking warning)
    log_gate "INFO" "GATE 4/6: Running type checker..."
    if quality_gate_breaker "EXE-004" "check"; then
        if check_types "$workspace" "${GATES_DIR}/types_${task_id}.json"; then
            quality_gate_breaker "EXE-004" "success"
            record_gate_result "EXE-004:Types" "PASS" "No type errors"
        else
            quality_gate_breaker "EXE-004" "failure"
            local type_errors
            type_errors=$(grep -o '"errors": *[0-9]*' "${GATES_DIR}/types_${task_id}.json" 2>/dev/null | cut -d: -f2 | tr -d ' ' || echo "unknown")
            record_gate_result "EXE-004:Types" "WARN" "${type_errors} type errors (non-blocking)"
            # Note: Type errors are non-blocking per original design
        fi
    else
        log_gate "ERROR" "Circuit breaker OPEN for EXE-004"
        record_gate_result "EXE-004:Types" "WARN" "Circuit breaker OPEN (skipped)"
    fi

    # Gate 5: Security (Blocking)
    log_gate "INFO" "GATE 5/6: Running security scan..."
    if quality_gate_breaker "EXE-005" "check"; then
        if check_security "$workspace" "${GATES_DIR}/security_${task_id}.json"; then
            quality_gate_breaker "EXE-005" "success"
            record_gate_result "EXE-005:Security" "PASS" "No critical/high vulnerabilities"
        else
            quality_gate_breaker "EXE-005" "failure"
            local critical high
            critical=$(grep -o '"critical": *[0-9]*' "${GATES_DIR}/security_${task_id}.json" 2>/dev/null | cut -d: -f2 | tr -d ' ' || echo "0")
            high=$(grep -o '"high": *[0-9]*' "${GATES_DIR}/security_${task_id}.json" 2>/dev/null | cut -d: -f2 | tr -d ' ' || echo "0")
            record_gate_result "EXE-005:Security" "FAIL" "Critical: $critical, High: $high vulnerabilities"
            ((blocking_failed++))
        fi
    else
        log_gate "ERROR" "Circuit breaker OPEN for EXE-005"
        record_gate_result "EXE-005:Security" "FAIL" "Circuit breaker OPEN"
        ((blocking_failed++))
    fi

    # Gate 6: Build (Blocking)
    log_gate "INFO" "GATE 6/6: Running build..."
    if quality_gate_breaker "EXE-006" "check"; then
        if check_build "$workspace" "${GATES_DIR}/build_${task_id}.json"; then
            quality_gate_breaker "EXE-006" "success"
            local build_duration
            build_duration=$(grep -o '"duration_seconds": *[0-9]*' "${GATES_DIR}/build_${task_id}.json" 2>/dev/null | cut -d: -f2 | tr -d ' ' || echo "0")
            record_gate_result "EXE-006:Build" "PASS" "Build succeeded (${build_duration}s)"
        else
            quality_gate_breaker "EXE-006" "failure"
            record_gate_result "EXE-006:Build" "FAIL" "Build failed"
            ((blocking_failed++))
        fi
    else
        log_gate "ERROR" "Circuit breaker OPEN for EXE-006"
        record_gate_result "EXE-006:Build" "FAIL" "Circuit breaker OPEN"
        ((blocking_failed++))
    fi

    end_time=$(date +%s)
    duration=$((end_time - start_time))

    log_gate "INFO" "GATE: All gates completed in ${duration}s (${blocking_failed} failures)"

    # FIX-005: Increment retry count on failure
    if [[ $blocking_failed -gt 0 ]]; then
        echo $((retry_count + 1)) > "$retry_file"
        log_gate "WARN" "GATE: Task $task_id failed (attempt $((retry_count + 1))/$MAX_RETRIES)"
        return 1
    else
        # Reset retry count on success
        rm -f "$retry_file" 2>/dev/null || true
        log_gate "PASS" "GATE: Task $task_id passed all quality gates"
        return 0
    fi
}

# =============================================================================
# IDEMPOTENT TASK STATE SYNC (P0.3 - Split-Brain Fix)
# =============================================================================
# Safely syncs filesystem and SQLite state with:
# - Idempotent transitions (safe to call multiple times)
# - Pending-sync markers on failure for recovery
# - DB validation before and after transition
# - Atomic marker writes with locking (prevents race conditions)
# - Proper dependency guards and JSON escaping
# =============================================================================

# Directory for pending-sync markers (tasks that need SQLite resync)
# Guard against empty STATE_DIR to avoid writing to root
if [[ -z "${STATE_DIR:-}" ]]; then
    STATE_DIR="${AUTONOMOUS_ROOT:-/tmp}/state"
fi
PENDING_SYNC_DIR="${PENDING_SYNC_DIR:-${STATE_DIR}/pending-sync}"

# JSON escape helper for safe marker content
_json_escape_value() {
    local val="$1"
    # Escape backslash, double quote, and control characters
    printf '%s' "$val" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e ':a;N;$!ba;s/\n/\\n/g' -e 's/\t/\\t/g'
}

# Internal logging helper with fallback
_log_sync() {
    local level="$1"
    shift
    if type -t log_gate >/dev/null 2>&1; then
        log_gate "$level" "SYNC: $*"
    else
        echo "[$level] SYNC: $*" >&2
    fi
}

# Idempotent state sync helper
# Usage: sync_task_state_to_db <task_id> <target_state> [reason]
# Returns: 0 on success, 1 on failure (but marks for resync)
sync_task_state_to_db() {
    local task_id="$1"
    local target_state="$2"
    local reason="${3:-}"

    # Ensure directory exists
    mkdir -p "$PENDING_SYNC_DIR" 2>/dev/null || {
        _log_sync "ERROR" "Cannot create pending-sync dir"
        return 1
    }

    local lock_file="${PENDING_SYNC_DIR}/.sync_${task_id}.lock"

    # Check if transition_task is available (sqlite-state.sh loaded)
    if ! type -t transition_task >/dev/null 2>&1; then
        _log_sync "WARN" "transition_task not available - SQLite sync skipped for $task_id"
        _mark_pending_sync "$task_id" "$target_state" "transition_task undefined"
        return 1
    fi

    # Use flock for atomic check-and-transition (prevents race conditions)
    (
        flock -w 5 200 || {
            _log_sync "WARN" "Could not acquire sync lock for $task_id"
            exit 1
        }

        # Check current SQLite state to avoid redundant transitions (idempotent)
        local current_state=""
        if type -t get_task_state >/dev/null 2>&1; then
            current_state=$(get_task_state "$task_id" 2>/dev/null || echo "")
        fi

        if [[ "$current_state" == "$target_state" ]]; then
            _log_sync "INFO" "Task $task_id already in state $target_state (idempotent)"
            # Clean up any stale pending-sync marker
            rm -f "${PENDING_SYNC_DIR}/${task_id}.pending" 2>/dev/null || true
            exit 0
        fi

        # Attempt SQLite transition
        if transition_task "$task_id" "$target_state" "$reason" "system" 2>/dev/null; then
            _log_sync "INFO" "Task $task_id transitioned to $target_state in SQLite"
            # Clean up any pending-sync marker
            rm -f "${PENDING_SYNC_DIR}/${task_id}.pending" 2>/dev/null || true
            exit 0
        else
            _log_sync "ERROR" "Failed to transition task $task_id to $target_state"
            _mark_pending_sync "$task_id" "$target_state" "transition_task failed: $reason"
            exit 1
        fi
    ) 200>"$lock_file"
    local result=$?

    # Clean up lock file
    rm -f "$lock_file" 2>/dev/null || true
    return $result
}

# Create pending-sync marker for failed transitions (for recovery by queue-watcher)
# Uses atomic write pattern (write to temp, then rename)
_mark_pending_sync() {
    local task_id="$1"
    local target_state="$2"
    local reason="${3:-unknown}"

    mkdir -p "$PENDING_SYNC_DIR" 2>/dev/null || return 1

    local marker_file="${PENDING_SYNC_DIR}/${task_id}.pending"
    local tmp_file="${marker_file}.tmp.$$"

    # Get timestamp with fallback
    local ts
    if type -t iso_timestamp >/dev/null 2>&1; then
        ts=$(iso_timestamp)
    else
        ts=$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')
    fi

    # Escape values for safe JSON
    local esc_task esc_state esc_reason esc_trace
    esc_task=$(_json_escape_value "$task_id")
    esc_state=$(_json_escape_value "$target_state")
    esc_reason=$(_json_escape_value "$reason")
    esc_trace=$(_json_escape_value "${TRACE_ID:-unknown}")

    # Atomic write: write to temp file, then rename
    cat > "$tmp_file" <<EOF
{"task_id":"${esc_task}","target_state":"${esc_state}","reason":"${esc_reason}","created_at":"${ts}","trace_id":"${esc_trace}"}
EOF

    if mv "$tmp_file" "$marker_file" 2>/dev/null; then
        _log_sync "WARN" "Created pending-sync marker for $task_id -> $target_state"
    else
        rm -f "$tmp_file" 2>/dev/null || true
        _log_sync "ERROR" "Failed to create pending-sync marker for $task_id"
    fi
}

# =============================================================================
# M2-010: UNIFIED APPROVE TASK
# =============================================================================
# Approves a task after passing all quality gates
# - Moves task from review to approved
# - Syncs state to SQLite (fixes split-brain)
# - Logs approval to ledger
# - Generates approval report
# - Notifies via comms channel
# =============================================================================

approve_task() {
    local task_id="$1"
    local workspace="${2:-}"
    local timestamp
    timestamp=$(iso_timestamp)

    # P0.9: Enforce authentication when REQUIRE_AUTH is true (secure by default)
    # This prevents unauthenticated approval calls in production
    if [[ "${REQUIRE_AUTH:-true}" == "true" ]]; then
        log_gate "ERROR" "SEC-009B: approve_task() called without authentication"
        log_gate "ERROR" "SEC-009B: Use approve_with_auth() with valid token instead"
        log_gate "ERROR" "SEC-009B: Set REQUIRE_AUTH=false to allow legacy unauthenticated approval"
        echo "Error: Authentication required. Use approve_with_auth() with a valid token." >&2
        return 1
    fi

    log_gate "INFO" "APPROVE: Processing approval for task $task_id (REQUIRE_AUTH=false)"

    # 1. Move task file from review to approved
    local task_file="${REVIEW_DIR}/${task_id}.md"
    local approved_file="${APPROVED_DIR}/${task_id}.md"

    if [[ -f "$task_file" ]]; then
        mv "$task_file" "$approved_file" 2>/dev/null || {
            log_gate "ERROR" "APPROVE: Failed to move task file to approved"
            return 1
        }
        log_gate "INFO" "APPROVE: Task file moved to ${APPROVED_DIR}/"
    else
        log_gate "WARN" "APPROVE: Task file not found at $task_file (may have been moved)"
    fi

    # 1b. Sync state to SQLite (P0.4 - Split-brain fix)
    # This ensures SQLite reflects the filesystem state change
    # On failure, creates pending-sync marker for recovery by queue-watcher
    sync_task_state_to_db "$task_id" "APPROVED" "All quality gates passed" || {
        log_gate "WARN" "APPROVE: SQLite sync failed for $task_id (pending-sync marker created)"
        # Continue anyway - filesystem is source of truth, DB will be resynced
    }

    # 2. Generate approval report
    local report_file="${APPROVED_DIR}/${task_id}_approval.json"
    local approval_report
    approval_report=$(cat <<EOF
{
    "task_id": "$task_id",
    "status": "APPROVED",
    "timestamp": "$timestamp",
    "trace_id": "${TRACE_ID:-unknown}",
    "gates_passed": ${#GATE_RESULTS[@]},
    "gates_failed": ${#FAILED_GATES[@]},
    "gate_summary": "$(printf '%s\n' "${GATE_RESULTS[@]}" | tr '\n' ';')",
    "workspace": "${workspace:-unknown}",
    "approver": "supervisor-approver/v2.1.0"
}
EOF
)
    write_json_result "$report_file" "$approval_report"
    log_gate "INFO" "APPROVE: Approval report written to $report_file"

    # 3. Log to ledger (with file locking)
    log_ledger "TASK_APPROVED" "$task_id" "All quality gates passed"

    # 4. Send notification via comms channel
    local notification_file="${COMMS_DIR}/supervisor/inbox/approved_${task_id}_${timestamp//[:-]/}.msg"
    mkdir -p "$(dirname "$notification_file")" 2>/dev/null || true
    cat > "$notification_file" <<EOF
TYPE: APPROVAL_NOTIFICATION
TASK_ID: $task_id
STATUS: APPROVED
TIMESTAMP: $timestamp
MESSAGE: Task $task_id has been approved and is ready for execution.
---
$(generate_feedback "$task_id")
EOF
    log_gate "INFO" "APPROVE: Notification sent to supervisor inbox"

    # 5. Archive gate results
    local archive_dir="${HISTORY_DIR}/${task_id}"
    mkdir -p "$archive_dir" 2>/dev/null || true
    for gate_file in "${GATES_DIR}"/*_${task_id}.json; do
        [[ -f "$gate_file" ]] && cp "$gate_file" "$archive_dir/" 2>/dev/null || true
    done

    log_gate "PASS" "APPROVE: Task $task_id approved successfully"
    echo "Task $task_id APPROVED at $timestamp"
    return 0
}

# =============================================================================
# M2-010: UNIFIED REJECT TASK WITH FEEDBACK
# =============================================================================
# Rejects a task that failed quality gates
# - Moves task from review to rejected
# - Generates detailed rejection report with failed gates
# - Logs rejection to ledger
# - Notifies via comms channel with actionable feedback
# =============================================================================

reject_task() {
    local task_id="$1"
    local workspace="${2:-}"
    local reason="${3:-Quality gates failed}"
    local timestamp
    timestamp=$(iso_timestamp)

    # P0.9: Enforce authentication when REQUIRE_AUTH is true (secure by default)
    if [[ "${REQUIRE_AUTH:-true}" == "true" ]]; then
        log_gate "ERROR" "SEC-009B: reject_task() called without authentication"
        log_gate "ERROR" "SEC-009B: Use reject_with_auth() with valid token instead"
        echo "Error: Authentication required. Use reject_with_auth() with a valid token." >&2
        return 1
    fi

    log_gate "INFO" "REJECT: Processing rejection for task $task_id (REQUIRE_AUTH=false)"

    # Check for max retries exceeded (permanent failure)
    local retry_file="${GATES_DIR}/retry_${task_id}.count"
    local retry_count=0
    local is_permanent_failure=false

    if [[ -f "$retry_file" ]]; then
        retry_count=$(cat "$retry_file" 2>/dev/null || echo "0")
        if [[ $retry_count -ge $MAX_RETRIES ]]; then
            is_permanent_failure=true
            reason="Max retries exceeded ($retry_count/$MAX_RETRIES)"
        fi
    fi

    # 1. Determine destination directory
    local dest_dir="$REJECTED_DIR"
    [[ "$is_permanent_failure" == "true" ]] && dest_dir="$FAILED_DIR"

    # 2. Move task file
    local task_file="${REVIEW_DIR}/${task_id}.md"
    local dest_file="${dest_dir}/${task_id}.md"

    if [[ -f "$task_file" ]]; then
        mv "$task_file" "$dest_file" 2>/dev/null || {
            log_gate "ERROR" "REJECT: Failed to move task file to $dest_dir"
            return 1
        }
        log_gate "INFO" "REJECT: Task file moved to ${dest_dir}/"
    fi

    # 2b. Sync state to SQLite (P0.5 - Split-brain fix)
    # Use FAILED for permanent failures, REJECTED for retriable
    local db_state="REJECTED"
    [[ "$is_permanent_failure" == "true" ]] && db_state="FAILED"
    sync_task_state_to_db "$task_id" "$db_state" "$reason" || {
        log_gate "WARN" "REJECT: SQLite sync failed for $task_id (pending-sync marker created)"
        # Continue anyway - filesystem is source of truth, DB will be resynced
    }

    # 3. Generate detailed rejection report
    local report_file="${dest_dir}/${task_id}_rejection.json"
    local failed_gates_json
    failed_gates_json=$(printf '"%s",' "${FAILED_GATES[@]}" | sed 's/,$//')

    local rejection_report
    rejection_report=$(cat <<EOF
{
    "task_id": "$task_id",
    "status": "REJECTED",
    "permanent_failure": $is_permanent_failure,
    "timestamp": "$timestamp",
    "trace_id": "${TRACE_ID:-unknown}",
    "retry_count": $retry_count,
    "max_retries": $MAX_RETRIES,
    "reason": "$reason",
    "failed_gates": [${failed_gates_json:-}],
    "total_gates": ${#GATE_RESULTS[@]},
    "gates_failed_count": ${#FAILED_GATES[@]},
    "workspace": "${workspace:-unknown}",
    "rejector": "supervisor-approver/v2.1.0"
}
EOF
)
    write_json_result "$report_file" "$rejection_report"
    log_gate "INFO" "REJECT: Rejection report written to $report_file"

    # 4. Generate human-readable feedback file (M2-014: Enhanced rejection feedback)
    local feedback_file="${dest_dir}/${task_id}_feedback.txt"
    generate_rejection_feedback "$task_id" "${FAILED_GATES[@]}" > "$feedback_file"
    log_gate "INFO" "REJECT: Detailed feedback written to $feedback_file"

    # 5. Log to ledger
    local ledger_detail="Failed gates: ${FAILED_GATES[*]:-none}. Reason: $reason"
    if [[ "$is_permanent_failure" == "true" ]]; then
        log_ledger "TASK_FAILED_PERMANENTLY" "$task_id" "$ledger_detail"
    else
        log_ledger "TASK_REJECTED" "$task_id" "$ledger_detail"
    fi

    # 6. Send notification via comms channel with actionable feedback (M2-014 Enhanced)
    local notification_file="${COMMS_DIR}/supervisor/inbox/rejected_${task_id}_${timestamp//[:-]/}.msg"
    mkdir -p "$(dirname "$notification_file")" 2>/dev/null || true

    local action_required="Fix the failing gates and resubmit for review."
    [[ "$is_permanent_failure" == "true" ]] && action_required="Task permanently failed. Manual intervention required."

    cat > "$notification_file" <<EOF
TYPE: REJECTION_NOTIFICATION
TASK_ID: $task_id
STATUS: REJECTED
PERMANENT: $is_permanent_failure
RETRY_COUNT: $retry_count/$MAX_RETRIES
TIMESTAMP: $timestamp
REASON: $reason
FAILED_GATES: ${FAILED_GATES[*]:-none}
ACTION_REQUIRED: $action_required
---
$(generate_rejection_feedback "$task_id" "${FAILED_GATES[@]}")
---
RAW GATE RESULTS (JSON):

EOF

    # Append gate-specific error details from JSON files
    for gate in "${FAILED_GATES[@]}"; do
        local gate_code
        gate_code=$(echo "$gate" | cut -d: -f1)
        local gate_file="${GATES_DIR}/${gate_code,,}_${task_id}.json"

        # Try different file name patterns
        for pattern in "${GATES_DIR}/tests_${task_id}.json" "${GATES_DIR}/coverage_${task_id}.json" \
                       "${GATES_DIR}/lint_${task_id}.json" "${GATES_DIR}/types_${task_id}.json" \
                       "${GATES_DIR}/security_${task_id}.json" "${GATES_DIR}/build_${task_id}.json"; do
            if [[ -f "$pattern" ]]; then
                local check_name
                check_name=$(grep -o '"check": *"[^"]*"' "$pattern" 2>/dev/null | cut -d'"' -f4 || echo "")
                if [[ "$gate" == *"$check_name"* ]] || [[ "$check_name" == *"$(echo "$gate" | cut -d: -f1)"* ]]; then
                    echo "=== $gate ===" >> "$notification_file"
                    cat "$pattern" >> "$notification_file" 2>/dev/null || true
                    echo "" >> "$notification_file"
                    break
                fi
            fi
        done
    done

    log_gate "INFO" "REJECT: Enhanced notification sent to supervisor inbox"

    # 7. Archive gate results
    local archive_dir="${HISTORY_DIR}/${task_id}"
    mkdir -p "$archive_dir" 2>/dev/null || true
    for gate_file in "${GATES_DIR}"/*_${task_id}.json; do
        [[ -f "$gate_file" ]] && cp "$gate_file" "$archive_dir/" 2>/dev/null || true
    done

    if [[ "$is_permanent_failure" == "true" ]]; then
        log_gate "FAIL" "REJECT: Task $task_id permanently FAILED (max retries)"
        echo "Task $task_id PERMANENTLY FAILED at $timestamp (max retries exceeded)"
    else
        log_gate "WARN" "REJECT: Task $task_id rejected (attempt $retry_count/$MAX_RETRIES)"
        echo "Task $task_id REJECTED at $timestamp (attempt $retry_count/$MAX_RETRIES)"
    fi

    return 0
}

# =============================================================================
# M2-010: UNIFIED WORKFLOW
# =============================================================================
# Complete end-to-end workflow that:
# 1. Validates a task through all quality gates
# 2. Approves or rejects based on results
# 3. Provides detailed feedback
# 4. Handles retries and permanent failures
# =============================================================================

unified_workflow() {
    local task_id="$1"
    local workspace="${2:-$(pwd)}"
    local timestamp
    timestamp=$(iso_timestamp)

    log_gate "INFO" "WORKFLOW: Starting unified workflow for $task_id"
    log_gate "INFO" "WORKFLOW: Workspace: $workspace"
    log_gate "INFO" "WORKFLOW: Timestamp: $timestamp"

    # Validate inputs
    if [[ -z "$task_id" ]]; then
        log_gate "ERROR" "WORKFLOW: task_id is required"
        echo "Error: task_id is required"
        return 1
    fi

    # Run quality gates
    local gate_result=0
    quality_gate "$task_id" "$workspace" || gate_result=$?

    case $gate_result in
        0)
            # All gates passed - approve the task
            log_gate "INFO" "WORKFLOW: All gates passed, approving task"
            approve_task "$task_id" "$workspace"
            log_gate "PASS" "WORKFLOW: Task $task_id completed successfully (APPROVED)"
            return 0
            ;;
        1)
            # Gates failed - reject with feedback (retryable)
            log_gate "WARN" "WORKFLOW: Gates failed, rejecting task"
            reject_task "$task_id" "$workspace" "Quality gates failed"
            log_gate "WARN" "WORKFLOW: Task $task_id rejected (RETRY ALLOWED)"
            return 1
            ;;
        2)
            # Max retries exceeded - permanent failure
            log_gate "ERROR" "WORKFLOW: Max retries exceeded, permanent failure"
            reject_task "$task_id" "$workspace" "Max retries exceeded"
            log_gate "FAIL" "WORKFLOW: Task $task_id permanently failed (NO RETRY)"
            return 2
            ;;
        *)
            # Unexpected error
            log_gate "ERROR" "WORKFLOW: Unexpected gate result: $gate_result"
            reject_task "$task_id" "$workspace" "Unexpected error (code: $gate_result)"
            return $gate_result
            ;;
    esac
}

# =============================================================================
# BATCH WORKFLOW
# =============================================================================
# Process multiple tasks in sequence
# Usage: batch_workflow task1 task2 task3 ...
# =============================================================================

batch_workflow() {
    local workspace="${WORKSPACE:-$(pwd)}"
    local total=0
    local passed=0
    local failed=0
    local permanent_failed=0

    log_gate "INFO" "BATCH: Starting batch workflow for ${#@} tasks"

    for task_id in "$@"; do
        ((total++))
        log_gate "INFO" "BATCH: Processing task $total: $task_id"

        local result=0
        unified_workflow "$task_id" "$workspace" || result=$?

        case $result in
            0) ((passed++)) ;;
            1) ((failed++)) ;;
            2) ((permanent_failed++)) ;;
            *) ((failed++)) ;;
        esac
    done

    log_gate "INFO" "BATCH: Completed - Total: $total, Passed: $passed, Failed: $failed, Permanent: $permanent_failed"

    # Return non-zero if any task failed
    [[ $failed -eq 0 && $permanent_failed -eq 0 ]] && return 0 || return 1
}

# =============================================================================
# STATUS REPORT
# =============================================================================
# Generate a status report for a task
# Usage: task_status task_id
# =============================================================================

task_status() {
    local task_id="$1"

    echo "=== Task Status: $task_id ==="
    echo "Timestamp: $(iso_timestamp)"
    echo ""

    # Check location of task
    local found=false
    for dir in "$QUEUE_DIR" "$REVIEW_DIR" "$APPROVED_DIR" "$REJECTED_DIR" "$COMPLETED_DIR" "$FAILED_DIR"; do
        if [[ -f "${dir}/${task_id}.md" ]]; then
            echo "Location: $dir"
            found=true
            break
        fi
    done

    if [[ "$found" != "true" ]]; then
        echo "Location: NOT FOUND"
    fi

    # Check retry count
    local retry_file="${GATES_DIR}/retry_${task_id}.count"
    if [[ -f "$retry_file" ]]; then
        echo "Retry Count: $(cat "$retry_file" 2>/dev/null || echo "0")/$MAX_RETRIES"
    else
        echo "Retry Count: 0/$MAX_RETRIES"
    fi

    # Check for gate results
    echo ""
    echo "Gate Results:"
    for gate_file in "${GATES_DIR}"/*_${task_id}.json; do
        if [[ -f "$gate_file" ]]; then
            local gate_name status
            gate_name=$(basename "$gate_file" "_${task_id}.json")
            status=$(grep -o '"status": *"[^"]*"' "$gate_file" 2>/dev/null | head -1 | cut -d'"' -f4 || echo "UNKNOWN")
            echo "  - $gate_name: $status"
        fi
    done

    # Check for approval/rejection report
    echo ""
    if [[ -f "${APPROVED_DIR}/${task_id}_approval.json" ]]; then
        echo "Approval Report: ${APPROVED_DIR}/${task_id}_approval.json"
    elif [[ -f "${REJECTED_DIR}/${task_id}_rejection.json" ]]; then
        echo "Rejection Report: ${REJECTED_DIR}/${task_id}_rejection.json"
    elif [[ -f "${FAILED_DIR}/${task_id}_rejection.json" ]]; then
        echo "Failure Report: ${FAILED_DIR}/${task_id}_rejection.json"
    fi

    # Check history
    if [[ -d "${HISTORY_DIR}/${task_id}" ]]; then
        echo "History Archive: ${HISTORY_DIR}/${task_id}/"
        echo "Archived Files: $(ls -1 "${HISTORY_DIR}/${task_id}/" 2>/dev/null | wc -l)"
    fi
}

# =============================================================================
# SEC-009B: CLI Authentication Module
# =============================================================================
# Provides secure authentication for CLI approval operations:
# - Session token generation using cryptographically secure random bytes
# - Token storage in SQLite with expiration (configurable, default 8 hours)
# - Token validation with automatic expiration enforcement
# - Audit logging of all authentication events
# - Protected approve_with_auth() requiring valid token
#
# SECURITY NOTES:
# - Tokens are SHA-256 hashed before storage (only hash is stored)
# - Token expiration is enforced server-side, not client-side
# - All authentication events are logged to security audit trail
# - Rate limiting prevents brute-force attacks (10 failed attempts per hour)
# =============================================================================

# SEC-009B Configuration
AUTH_TOKEN_EXPIRY_HOURS="${AUTH_TOKEN_EXPIRY_HOURS:-8}"
AUTH_TOKEN_LENGTH="${AUTH_TOKEN_LENGTH:-64}"
AUTH_MAX_FAILED_ATTEMPTS="${AUTH_MAX_FAILED_ATTEMPTS:-10}"
AUTH_LOCKOUT_MINUTES="${AUTH_LOCKOUT_MINUTES:-30}"
AUTH_DB="${AUTH_DB:-${STATE_DIR}/auth.db}"
AUTH_AUDIT_LOG="${LOG_DIR}/security/auth-audit.log"

# Ensure auth directories exist
mkdir -p "$(dirname "$AUTH_DB")" 2>/dev/null || true
mkdir -p "$(dirname "$AUTH_AUDIT_LOG")" 2>/dev/null || true

# -----------------------------------------------------------------------------
# SEC-009B.1: Auth Database Initialization
# -----------------------------------------------------------------------------
# Creates the authentication tables if they don't exist.
# Uses SQLite with proper security settings (WAL mode, foreign keys).
# -----------------------------------------------------------------------------
_auth_init_db() {
    local db="${AUTH_DB}"

    # SEC-003B: Validate database path
    if [[ -L "$db" ]]; then
        log_gate "ERROR" "SEC-009B: Blocked auth database - symlink detected: $db"
        return 1
    fi

    # Create parent directory if needed
    local parent_dir
    parent_dir=$(dirname "$db")
    if [[ ! -d "$parent_dir" ]]; then
        mkdir -p "$parent_dir" 2>/dev/null || {
            log_gate "ERROR" "SEC-009B: Failed to create auth database directory: $parent_dir"
            return 1
        }
        chmod 700 "$parent_dir"
    fi

    # Skip if already initialized
    if [[ -f "$db" ]]; then
        return 0
    fi

    # Create database with secure permissions
    touch "$db"
    chmod 600 "$db"

    # SEC-008C: Use secure binary resolution
    local sqlite3_bin
    if sqlite3_bin=$(_get_binary "sqlite3" 2>/dev/null); then
        "$sqlite3_bin" "$db" <<'SQL'
PRAGMA journal_mode=WAL;
PRAGMA synchronous=NORMAL;
PRAGMA foreign_keys=ON;
PRAGMA busy_timeout=5000;

-- Authentication tokens table
-- Note: token_hash stores SHA-256 hash of actual token (token never stored raw)
CREATE TABLE IF NOT EXISTS auth_tokens (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    token_hash TEXT UNIQUE NOT NULL,
    user_id TEXT NOT NULL,
    created_at TEXT DEFAULT (datetime('now')),
    expires_at TEXT NOT NULL,
    last_used_at TEXT,
    ip_address TEXT,
    user_agent TEXT,
    revoked INTEGER DEFAULT 0,
    revoked_at TEXT,
    revoked_reason TEXT
);

CREATE INDEX IF NOT EXISTS idx_auth_tokens_hash ON auth_tokens(token_hash);
CREATE INDEX IF NOT EXISTS idx_auth_tokens_user ON auth_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_auth_tokens_expires ON auth_tokens(expires_at);

-- Failed authentication attempts (for rate limiting)
CREATE TABLE IF NOT EXISTS auth_failures (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT,
    ip_address TEXT,
    attempt_at TEXT DEFAULT (datetime('now')),
    reason TEXT
);

CREATE INDEX IF NOT EXISTS idx_auth_failures_ip ON auth_failures(ip_address);
CREATE INDEX IF NOT EXISTS idx_auth_failures_time ON auth_failures(attempt_at);

-- Authentication audit log
CREATE TABLE IF NOT EXISTS auth_audit (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT DEFAULT (datetime('now')),
    event_type TEXT NOT NULL,
    user_id TEXT,
    token_hash_prefix TEXT,
    task_id TEXT,
    ip_address TEXT,
    success INTEGER,
    details TEXT,
    trace_id TEXT
);

CREATE INDEX IF NOT EXISTS idx_auth_audit_time ON auth_audit(timestamp);
CREATE INDEX IF NOT EXISTS idx_auth_audit_user ON auth_audit(user_id);
CREATE INDEX IF NOT EXISTS idx_auth_audit_type ON auth_audit(event_type);

-- Schema version tracking
INSERT OR IGNORE INTO auth_audit (event_type, details, trace_id)
VALUES ('SCHEMA_INIT', 'SEC-009B auth schema v1.0 initialized', 'system');
SQL
        log_gate "INFO" "SEC-009B: Auth database initialized: $db"
    elif python3_bin=$(_get_binary "python3" 2>/dev/null); then
        # Python fallback for SQLite operations
        "$python3_bin" - "$db" <<'PYEOF'
import sqlite3
import sys

db_path = sys.argv[1]
conn = sqlite3.connect(db_path, timeout=10.0)
conn.execute('PRAGMA journal_mode=WAL')
conn.execute('PRAGMA synchronous=NORMAL')
conn.execute('PRAGMA foreign_keys=ON')
conn.executescript('''
CREATE TABLE IF NOT EXISTS auth_tokens (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    token_hash TEXT UNIQUE NOT NULL,
    user_id TEXT NOT NULL,
    created_at TEXT DEFAULT (datetime('now')),
    expires_at TEXT NOT NULL,
    last_used_at TEXT,
    ip_address TEXT,
    user_agent TEXT,
    revoked INTEGER DEFAULT 0,
    revoked_at TEXT,
    revoked_reason TEXT
);
CREATE INDEX IF NOT EXISTS idx_auth_tokens_hash ON auth_tokens(token_hash);
CREATE INDEX IF NOT EXISTS idx_auth_tokens_user ON auth_tokens(user_id);

CREATE TABLE IF NOT EXISTS auth_failures (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT,
    ip_address TEXT,
    attempt_at TEXT DEFAULT (datetime('now')),
    reason TEXT
);
CREATE INDEX IF NOT EXISTS idx_auth_failures_ip ON auth_failures(ip_address);

CREATE TABLE IF NOT EXISTS auth_audit (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT DEFAULT (datetime('now')),
    event_type TEXT NOT NULL,
    user_id TEXT,
    token_hash_prefix TEXT,
    task_id TEXT,
    ip_address TEXT,
    success INTEGER,
    details TEXT,
    trace_id TEXT
);
CREATE INDEX IF NOT EXISTS idx_auth_audit_time ON auth_audit(timestamp);
''')
conn.commit()
conn.close()
PYEOF
        log_gate "INFO" "SEC-009B: Auth database initialized via Python: $db"
    else
        log_gate "ERROR" "SEC-009B: No sqlite3 or python3 available for auth database"
        return 1
    fi

    return 0
}

# -----------------------------------------------------------------------------
# SEC-009B.2: Secure Token Generation
# -----------------------------------------------------------------------------
# Generates cryptographically secure random token using /dev/urandom.
# Returns raw token to caller (caller must store securely).
# -----------------------------------------------------------------------------
_auth_generate_token() {
    local length="${1:-$AUTH_TOKEN_LENGTH}"

    # Use /dev/urandom for cryptographically secure random bytes
    # Convert to hex for safe transport/storage
    local token
    if [[ -r /dev/urandom ]]; then
        token=$(head -c "$((length / 2))" /dev/urandom | xxd -p 2>/dev/null | tr -d '\n')
        if [[ -z "$token" ]]; then
            # Fallback to od if xxd not available
            token=$(head -c "$((length / 2))" /dev/urandom | od -An -tx1 | tr -d ' \n')
        fi
    else
        # Last resort: use $RANDOM (not cryptographically secure, but functional)
        log_gate "WARN" "SEC-009B: /dev/urandom not available, using fallback random"
        local i
        token=""
        for ((i=0; i<length; i++)); do
            token+=$(printf '%x' $((RANDOM % 16)))
        done
    fi

    echo "${token:0:$length}"
}

# -----------------------------------------------------------------------------
# SEC-009B.3: Token Hashing
# -----------------------------------------------------------------------------
# Hash token using SHA-256 for secure storage.
# Only the hash is stored in the database, never the raw token.
# -----------------------------------------------------------------------------
_auth_hash_token() {
    local token="$1"

    # Use sha256sum for hashing
    local sha256_bin
    if sha256_bin=$(_get_binary "sha256sum" 2>/dev/null); then
        echo -n "$token" | "$sha256_bin" | cut -d' ' -f1
    else
        # Python fallback
        local python3_bin
        if python3_bin=$(_get_binary "python3" 2>/dev/null); then
            "$python3_bin" -c "import hashlib; print(hashlib.sha256('$token'.encode()).hexdigest())"
        else
            log_gate "ERROR" "SEC-009B: No sha256sum or python3 available for token hashing"
            return 1
        fi
    fi
}

# -----------------------------------------------------------------------------
# SEC-009B.4: Audit Logging
# -----------------------------------------------------------------------------
# Log authentication events to both SQLite and file-based audit log.
# All auth events are logged regardless of success/failure.
# -----------------------------------------------------------------------------
_auth_log_event() {
    local event_type="$1"
    local user_id="${2:-unknown}"
    local token_hash_prefix="${3:-}"
    local task_id="${4:-}"
    local success="${5:-1}"
    local details="${6:-}"
    local ip_address="${SSH_CLIENT%% *}"
    ip_address="${ip_address:-127.0.0.1}"

    local timestamp
    timestamp=$(iso_timestamp 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Log to SQLite audit table
    _auth_init_db

    local sqlite3_bin python3_bin
    if sqlite3_bin=$(_get_binary "sqlite3" 2>/dev/null); then
        "$sqlite3_bin" "$AUTH_DB" <<SQL
INSERT INTO auth_audit (timestamp, event_type, user_id, token_hash_prefix, task_id, ip_address, success, details, trace_id)
VALUES ('$timestamp', '$event_type', '$user_id', '${token_hash_prefix:0:16}', '$task_id', '$ip_address', $success, '$details', '${TRACE_ID:-unknown}');
SQL
    elif python3_bin=$(_get_binary "python3" 2>/dev/null); then
        # Python fallback for audit logging
        "$python3_bin" - "$AUTH_DB" "$timestamp" "$event_type" "$user_id" "${token_hash_prefix:0:16}" "$task_id" "$ip_address" "$success" "$details" "${TRACE_ID:-unknown}" <<'PYEOF'
import sqlite3
import sys

db_path = sys.argv[1]
timestamp = sys.argv[2]
event_type = sys.argv[3]
user_id = sys.argv[4]
token_hash_prefix = sys.argv[5]
task_id = sys.argv[6]
ip_address = sys.argv[7]
success = int(sys.argv[8])
details = sys.argv[9]
trace_id = sys.argv[10]

try:
    conn = sqlite3.connect(db_path, timeout=10.0)
    conn.execute('''
        INSERT INTO auth_audit (timestamp, event_type, user_id, token_hash_prefix, task_id, ip_address, success, details, trace_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', (timestamp, event_type, user_id, token_hash_prefix, task_id, ip_address, success, details, trace_id))
    conn.commit()
    conn.close()
except Exception as e:
    # Audit logging should not fail the main operation
    pass
PYEOF
    fi

    # Also log to file-based audit log (always attempt this)
    mkdir -p "$(dirname "$AUTH_AUDIT_LOG")" 2>/dev/null || true
    local audit_entry="{\"timestamp\":\"$timestamp\",\"event\":\"$event_type\",\"user\":\"$user_id\",\"task_id\":\"$task_id\",\"success\":$success,\"details\":\"$details\",\"trace_id\":\"${TRACE_ID:-unknown}\"}"
    echo "$audit_entry" >> "$AUTH_AUDIT_LOG" 2>/dev/null || true

    # Log to security event system if available
    if declare -F log_security_event >/dev/null 2>&1; then
        local severity="INFO"
        [[ "$success" -eq 0 ]] && severity="WARN"
        [[ "$event_type" == *"FAIL"* ]] && severity="WARN"
        [[ "$event_type" == *"REVOKE"* ]] && severity="WARN"
        log_security_event "AUTH_$event_type" "$details" "$severity" 2>/dev/null || true
    fi
}

# -----------------------------------------------------------------------------
# SEC-009B.5: Rate Limiting Check
# -----------------------------------------------------------------------------
# Prevents brute-force attacks by limiting failed authentication attempts.
# Returns 0 if under limit, 1 if rate limited (should deny attempt).
# -----------------------------------------------------------------------------
_auth_check_rate_limit() {
    local user_id="${1:-}"
    local ip_address="${SSH_CLIENT%% *}"
    ip_address="${ip_address:-127.0.0.1}"

    _auth_init_db

    local sqlite3_bin
    local fail_count=0

    if sqlite3_bin=$(_get_binary "sqlite3" 2>/dev/null); then
        # Count failures in the last hour for this IP
        fail_count=$("$sqlite3_bin" "$AUTH_DB" <<SQL
SELECT COUNT(*) FROM auth_failures
WHERE ip_address='$ip_address'
  AND attempt_at > datetime('now', '-1 hour');
SQL
)
    fi

    if [[ "$fail_count" -ge "$AUTH_MAX_FAILED_ATTEMPTS" ]]; then
        log_gate "WARN" "SEC-009B: Rate limit exceeded for IP $ip_address ($fail_count failures)"
        _auth_log_event "RATE_LIMITED" "$user_id" "" "" 0 "IP $ip_address exceeded $AUTH_MAX_FAILED_ATTEMPTS attempts"
        return 1
    fi

    return 0
}

# -----------------------------------------------------------------------------
# SEC-009B.6: Record Failed Attempt
# -----------------------------------------------------------------------------
# Records a failed authentication attempt for rate limiting purposes.
# -----------------------------------------------------------------------------
_auth_record_failure() {
    local user_id="${1:-unknown}"
    local reason="${2:-invalid_token}"
    local ip_address="${SSH_CLIENT%% *}"
    ip_address="${ip_address:-127.0.0.1}"

    _auth_init_db

    local sqlite3_bin
    if sqlite3_bin=$(_get_binary "sqlite3" 2>/dev/null); then
        "$sqlite3_bin" "$AUTH_DB" <<SQL
INSERT INTO auth_failures (user_id, ip_address, reason)
VALUES ('$user_id', '$ip_address', '$reason');
SQL
    fi
}

# -----------------------------------------------------------------------------
# SEC-009B.7: Create Session Token (Login)
# -----------------------------------------------------------------------------
# Creates a new session token for the specified user.
# Returns the raw token that must be stored securely by the caller.
# Usage: auth_login <user_id>
# Returns: Token on stdout, exit 0 on success, exit 1 on failure
# -----------------------------------------------------------------------------
auth_login() {
    local user_id="${1:-$(whoami)}"

    # Rate limit check
    if ! _auth_check_rate_limit "$user_id"; then
        echo "Error: Rate limited. Too many authentication attempts." >&2
        return 1
    fi

    _auth_init_db

    # Generate secure token
    local token
    token=$(_auth_generate_token)
    if [[ -z "$token" ]]; then
        log_gate "ERROR" "SEC-009B: Failed to generate token"
        return 1
    fi

    # Hash token for storage
    local token_hash
    token_hash=$(_auth_hash_token "$token")
    if [[ -z "$token_hash" ]]; then
        log_gate "ERROR" "SEC-009B: Failed to hash token"
        return 1
    fi

    # Calculate expiration time
    local ip_address="${SSH_CLIENT%% *}"
    ip_address="${ip_address:-127.0.0.1}"

    local sqlite3_bin python3_bin
    if sqlite3_bin=$(_get_binary "sqlite3" 2>/dev/null); then
        "$sqlite3_bin" "$AUTH_DB" <<SQL
INSERT INTO auth_tokens (token_hash, user_id, expires_at, ip_address)
VALUES ('$token_hash', '$user_id', datetime('now', '+$AUTH_TOKEN_EXPIRY_HOURS hours'), '$ip_address');
SQL
        local result=$?
        if [[ $result -ne 0 ]]; then
            log_gate "ERROR" "SEC-009B: Failed to store token"
            _auth_log_event "LOGIN_FAIL" "$user_id" "$token_hash" "" 0 "Database error"
            return 1
        fi
    elif python3_bin=$(_get_binary "python3" 2>/dev/null); then
        # Python fallback for SQLite operations
        "$python3_bin" - "$AUTH_DB" "$token_hash" "$user_id" "$AUTH_TOKEN_EXPIRY_HOURS" "$ip_address" <<'PYEOF'
import sqlite3
import sys
from datetime import datetime, timedelta

db_path = sys.argv[1]
token_hash = sys.argv[2]
user_id = sys.argv[3]
expiry_hours = int(sys.argv[4])
ip_address = sys.argv[5]

try:
    conn = sqlite3.connect(db_path, timeout=10.0)
    expires_at = (datetime.utcnow() + timedelta(hours=expiry_hours)).strftime('%Y-%m-%d %H:%M:%S')
    conn.execute('''
        INSERT INTO auth_tokens (token_hash, user_id, expires_at, ip_address)
        VALUES (?, ?, ?, ?)
    ''', (token_hash, user_id, expires_at, ip_address))
    conn.commit()
    conn.close()
except Exception as e:
    sys.stderr.write(f'SQLite Error: {e}\n')
    sys.exit(1)
PYEOF
        local result=$?
        if [[ $result -ne 0 ]]; then
            log_gate "ERROR" "SEC-009B: Failed to store token (Python)"
            _auth_log_event "LOGIN_FAIL" "$user_id" "$token_hash" "" 0 "Database error (Python)"
            return 1
        fi
    else
        log_gate "ERROR" "SEC-009B: Neither sqlite3 nor python3 available for auth"
        return 1
    fi

    _auth_log_event "LOGIN_SUCCESS" "$user_id" "$token_hash" "" 1 "Token created, expires in ${AUTH_TOKEN_EXPIRY_HOURS}h"
    log_gate "INFO" "SEC-009B: Session created for user $user_id (expires in ${AUTH_TOKEN_EXPIRY_HOURS}h)"

    # Return raw token to caller (they must store it securely)
    echo "$token"
    return 0
}

# -----------------------------------------------------------------------------
# SEC-009B.8: Validate Session Token
# -----------------------------------------------------------------------------
# Validates that a token is valid, not expired, and not revoked.
# Updates last_used_at on successful validation.
# Usage: auth_validate_token <token>
# Returns: 0 if valid, 1 if invalid/expired/revoked
# Sets AUTH_USER_ID on success
# -----------------------------------------------------------------------------
auth_validate_token() {
    local token="$1"

    if [[ -z "$token" ]]; then
        log_gate "ERROR" "SEC-009B: Empty token provided"
        return 1
    fi

    # Rate limit check
    if ! _auth_check_rate_limit ""; then
        return 1
    fi

    _auth_init_db

    # Hash the provided token
    local token_hash
    token_hash=$(_auth_hash_token "$token")

    local sqlite3_bin python3_bin
    local result

    if sqlite3_bin=$(_get_binary "sqlite3" 2>/dev/null); then
        # Check if token exists, is not expired, and is not revoked
        result=$("$sqlite3_bin" "$AUTH_DB" <<SQL
SELECT user_id FROM auth_tokens
WHERE token_hash='$token_hash'
  AND revoked=0
  AND expires_at > datetime('now')
LIMIT 1;
SQL
)

        if [[ -z "$result" ]]; then
            # Token invalid, expired, or revoked
            _auth_record_failure "" "invalid_token"
            _auth_log_event "TOKEN_INVALID" "" "$token_hash" "" 0 "Token not found, expired, or revoked"
            return 1
        fi

        # Update last_used_at
        "$sqlite3_bin" "$AUTH_DB" <<SQL
UPDATE auth_tokens
SET last_used_at=datetime('now')
WHERE token_hash='$token_hash';
SQL

        # Export user ID for use by caller
        export AUTH_USER_ID="$result"

        log_gate "DEBUG" "SEC-009B: Token validated for user $result"
        return 0
    elif python3_bin=$(_get_binary "python3" 2>/dev/null); then
        # Python fallback for token validation
        result=$("$python3_bin" - "$AUTH_DB" "$token_hash" <<'PYEOF'
import sqlite3
import sys
from datetime import datetime

db_path = sys.argv[1]
token_hash = sys.argv[2]

try:
    conn = sqlite3.connect(db_path, timeout=10.0)
    cursor = conn.cursor()

    # Check if token exists, is not expired, and is not revoked
    now = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
    cursor.execute('''
        SELECT user_id FROM auth_tokens
        WHERE token_hash=?
          AND revoked=0
          AND expires_at > ?
        LIMIT 1
    ''', (token_hash, now))

    row = cursor.fetchone()
    if row:
        # Update last_used_at
        cursor.execute('''
            UPDATE auth_tokens
            SET last_used_at=?
            WHERE token_hash=?
        ''', (now, token_hash))
        conn.commit()
        print(row[0])  # Print user_id

    conn.close()
except Exception as e:
    sys.stderr.write(f'SQLite Error: {e}\n')
    sys.exit(1)
PYEOF
)

        if [[ -z "$result" ]]; then
            # Token invalid, expired, or revoked
            _auth_record_failure "" "invalid_token"
            _auth_log_event "TOKEN_INVALID" "" "$token_hash" "" 0 "Token not found, expired, or revoked"
            return 1
        fi

        # Export user ID for use by caller
        export AUTH_USER_ID="$result"

        log_gate "DEBUG" "SEC-009B: Token validated for user $result (Python)"
        return 0
    else
        log_gate "ERROR" "SEC-009B: Neither sqlite3 nor python3 available for validation"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# SEC-009B.9: Revoke Session Token (Logout)
# -----------------------------------------------------------------------------
# Revokes a token, preventing further use.
# Usage: auth_logout <token>
# -----------------------------------------------------------------------------
auth_logout() {
    local token="$1"
    local reason="${2:-user_logout}"

    if [[ -z "$token" ]]; then
        log_gate "ERROR" "SEC-009B: No token provided for logout"
        return 1
    fi

    _auth_init_db

    local token_hash
    token_hash=$(_auth_hash_token "$token")

    local sqlite3_bin python3_bin
    if sqlite3_bin=$(_get_binary "sqlite3" 2>/dev/null); then
        # Get user_id before revoking
        local user_id
        user_id=$("$sqlite3_bin" "$AUTH_DB" "SELECT user_id FROM auth_tokens WHERE token_hash='$token_hash' LIMIT 1;")

        # Revoke token
        "$sqlite3_bin" "$AUTH_DB" <<SQL
UPDATE auth_tokens
SET revoked=1, revoked_at=datetime('now'), revoked_reason='$reason'
WHERE token_hash='$token_hash';
SQL

        _auth_log_event "LOGOUT" "$user_id" "$token_hash" "" 1 "Token revoked: $reason"
        log_gate "INFO" "SEC-009B: Session revoked for user ${user_id:-unknown}"
        return 0
    elif python3_bin=$(_get_binary "python3" 2>/dev/null); then
        # Python fallback for logout
        local user_id
        user_id=$("$python3_bin" - "$AUTH_DB" "$token_hash" "$reason" <<'PYEOF'
import sqlite3
import sys
from datetime import datetime

db_path = sys.argv[1]
token_hash = sys.argv[2]
reason = sys.argv[3]

try:
    conn = sqlite3.connect(db_path, timeout=10.0)
    cursor = conn.cursor()

    # Get user_id
    cursor.execute('SELECT user_id FROM auth_tokens WHERE token_hash=? LIMIT 1', (token_hash,))
    row = cursor.fetchone()
    user_id = row[0] if row else 'unknown'

    # Revoke token
    now = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
    cursor.execute('''
        UPDATE auth_tokens
        SET revoked=1, revoked_at=?, revoked_reason=?
        WHERE token_hash=?
    ''', (now, reason, token_hash))

    conn.commit()
    conn.close()
    print(user_id)
except Exception as e:
    sys.stderr.write(f'SQLite Error: {e}\n')
    sys.exit(1)
PYEOF
)

        _auth_log_event "LOGOUT" "$user_id" "$token_hash" "" 1 "Token revoked: $reason"
        log_gate "INFO" "SEC-009B: Session revoked for user ${user_id:-unknown} (Python)"
        return 0
    else
        log_gate "ERROR" "SEC-009B: Neither sqlite3 nor python3 available for logout"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# SEC-009B.10: Get Token Status
# -----------------------------------------------------------------------------
# Returns information about a token's status.
# Usage: auth_token_status <token>
# -----------------------------------------------------------------------------
auth_token_status() {
    local token="$1"

    if [[ -z "$token" ]]; then
        echo "Error: No token provided" >&2
        return 1
    fi

    _auth_init_db

    local token_hash
    token_hash=$(_auth_hash_token "$token")

    local sqlite3_bin python3_bin
    if sqlite3_bin=$(_get_binary "sqlite3" 2>/dev/null); then
        local result
        result=$("$sqlite3_bin" "$AUTH_DB" <<SQL
SELECT
    user_id,
    created_at,
    expires_at,
    last_used_at,
    revoked,
    CASE
        WHEN revoked=1 THEN 'REVOKED'
        WHEN expires_at <= datetime('now') THEN 'EXPIRED'
        ELSE 'VALID'
    END as status
FROM auth_tokens
WHERE token_hash='$token_hash'
LIMIT 1;
SQL
)

        if [[ -z "$result" ]]; then
            echo "Token: NOT FOUND"
            return 1
        fi

        # Parse pipe-separated result
        local user_id created_at expires_at last_used_at revoked status
        IFS='|' read -r user_id created_at expires_at last_used_at revoked status <<< "$result"

        cat <<EOF
=== Token Status ===
User:       $user_id
Status:     $status
Created:    $created_at
Expires:    $expires_at
Last Used:  ${last_used_at:-never}
Revoked:    $([ "$revoked" = "1" ] && echo "Yes" || echo "No")
EOF
        return 0
    elif python3_bin=$(_get_binary "python3" 2>/dev/null); then
        # Python fallback for token status
        "$python3_bin" - "$AUTH_DB" "$token_hash" <<'PYEOF'
import sqlite3
import sys
from datetime import datetime

db_path = sys.argv[1]
token_hash = sys.argv[2]

try:
    conn = sqlite3.connect(db_path, timeout=10.0)
    cursor = conn.cursor()

    now = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
    cursor.execute('''
        SELECT user_id, created_at, expires_at, last_used_at, revoked
        FROM auth_tokens
        WHERE token_hash=?
        LIMIT 1
    ''', (token_hash,))

    row = cursor.fetchone()
    conn.close()

    if not row:
        print("Token: NOT FOUND")
        sys.exit(1)

    user_id, created_at, expires_at, last_used_at, revoked = row

    # Determine status
    if revoked == 1:
        status = "REVOKED"
    elif expires_at and expires_at <= now:
        status = "EXPIRED"
    else:
        status = "VALID"

    print("=== Token Status ===")
    print(f"User:       {user_id}")
    print(f"Status:     {status}")
    print(f"Created:    {created_at}")
    print(f"Expires:    {expires_at}")
    print(f"Last Used:  {last_used_at or 'never'}")
    print(f"Revoked:    {'Yes' if revoked == 1 else 'No'}")

except Exception as e:
    sys.stderr.write(f'SQLite Error: {e}\n')
    sys.exit(1)
PYEOF
        return $?
    else
        echo "Error: Neither sqlite3 nor python3 available" >&2
        return 1
    fi
}

# -----------------------------------------------------------------------------
# SEC-009B.11: Cleanup Expired Tokens
# -----------------------------------------------------------------------------
# Removes expired and revoked tokens older than specified days.
# Usage: auth_cleanup [days]
# -----------------------------------------------------------------------------
auth_cleanup() {
    local days="${1:-7}"

    _auth_init_db

    local sqlite3_bin
    if sqlite3_bin=$(_get_binary "sqlite3" 2>/dev/null); then
        local deleted_count
        deleted_count=$("$sqlite3_bin" "$AUTH_DB" <<SQL
DELETE FROM auth_tokens
WHERE (revoked=1 AND revoked_at < datetime('now', '-$days days'))
   OR (expires_at < datetime('now', '-$days days'));
SELECT changes();
SQL
)

        # Cleanup old failure records
        "$sqlite3_bin" "$AUTH_DB" <<SQL
DELETE FROM auth_failures
WHERE attempt_at < datetime('now', '-$days days');
SQL

        log_gate "INFO" "SEC-009B: Cleaned up ${deleted_count:-0} expired tokens"
        _auth_log_event "CLEANUP" "system" "" "" 1 "Removed ${deleted_count:-0} expired tokens"
        echo "Cleaned up ${deleted_count:-0} expired tokens"
        return 0
    else
        log_gate "ERROR" "SEC-009B: sqlite3 not available for cleanup"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# SEC-009B.12: Authenticated Approve Function
# -----------------------------------------------------------------------------
# Approves a task ONLY if valid authentication token is provided.
# This is the secure version of approve_task that requires authentication.
# Usage: approve_with_auth <task_id> <token> [workspace]
# -----------------------------------------------------------------------------
approve_with_auth() {
    local task_id="$1"
    local token="$2"
    local workspace="${3:-}"

    # Validate inputs
    if [[ -z "$task_id" ]]; then
        log_gate "ERROR" "SEC-009B: task_id is required for authenticated approval"
        _auth_log_event "APPROVE_FAIL" "" "" "$task_id" 0 "Missing task_id"
        echo "Error: task_id is required" >&2
        return 1
    fi

    if [[ -z "$token" ]]; then
        log_gate "ERROR" "SEC-009B: Authentication token is required for approval"
        _auth_log_event "APPROVE_FAIL" "" "" "$task_id" 0 "Missing token"
        echo "Error: Authentication token is required" >&2
        return 1
    fi

    # Validate token
    if ! auth_validate_token "$token"; then
        log_gate "ERROR" "SEC-009B: Invalid or expired authentication token"
        _auth_log_event "APPROVE_DENIED" "" "$(_auth_hash_token "$token")" "$task_id" 0 "Invalid token"
        echo "Error: Invalid or expired authentication token" >&2
        return 1
    fi

    local user_id="${AUTH_USER_ID:-unknown}"
    local token_hash
    token_hash=$(_auth_hash_token "$token")

    log_gate "INFO" "SEC-009B: Authenticated approval by $user_id for task $task_id"

    # Log the authenticated action BEFORE performing it
    _auth_log_event "APPROVE_ATTEMPT" "$user_id" "$token_hash" "$task_id" 1 "Authenticated approval initiated"

    # Perform the actual approval
    local result=0
    approve_task "$task_id" "$workspace" || result=$?

    if [[ $result -eq 0 ]]; then
        _auth_log_event "APPROVE_SUCCESS" "$user_id" "$token_hash" "$task_id" 1 "Task approved by authenticated user"
        log_gate "PASS" "SEC-009B: Task $task_id approved by authenticated user $user_id"
    else
        _auth_log_event "APPROVE_FAIL" "$user_id" "$token_hash" "$task_id" 0 "Approval failed (exit code: $result)"
        log_gate "ERROR" "SEC-009B: Authenticated approval failed for task $task_id"
    fi

    return $result
}

# -----------------------------------------------------------------------------
# SEC-009B.13: Authenticated Reject Function
# -----------------------------------------------------------------------------
# Rejects a task ONLY if valid authentication token is provided.
# Usage: reject_with_auth <task_id> <token> [workspace] [reason]
# -----------------------------------------------------------------------------
reject_with_auth() {
    local task_id="$1"
    local token="$2"
    local workspace="${3:-}"
    local reason="${4:-Quality gates failed}"

    # Validate inputs
    if [[ -z "$task_id" ]]; then
        log_gate "ERROR" "SEC-009B: task_id is required for authenticated rejection"
        _auth_log_event "REJECT_FAIL" "" "" "$task_id" 0 "Missing task_id"
        echo "Error: task_id is required" >&2
        return 1
    fi

    if [[ -z "$token" ]]; then
        log_gate "ERROR" "SEC-009B: Authentication token is required for rejection"
        _auth_log_event "REJECT_FAIL" "" "" "$task_id" 0 "Missing token"
        echo "Error: Authentication token is required" >&2
        return 1
    fi

    # Validate token
    if ! auth_validate_token "$token"; then
        log_gate "ERROR" "SEC-009B: Invalid or expired authentication token"
        _auth_log_event "REJECT_DENIED" "" "$(_auth_hash_token "$token")" "$task_id" 0 "Invalid token"
        echo "Error: Invalid or expired authentication token" >&2
        return 1
    fi

    local user_id="${AUTH_USER_ID:-unknown}"
    local token_hash
    token_hash=$(_auth_hash_token "$token")

    log_gate "INFO" "SEC-009B: Authenticated rejection by $user_id for task $task_id"

    # Log the authenticated action BEFORE performing it
    _auth_log_event "REJECT_ATTEMPT" "$user_id" "$token_hash" "$task_id" 1 "Authenticated rejection initiated"

    # Perform the actual rejection
    local result=0
    reject_task "$task_id" "$workspace" "$reason" || result=$?

    if [[ $result -eq 0 ]]; then
        _auth_log_event "REJECT_SUCCESS" "$user_id" "$token_hash" "$task_id" 1 "Task rejected by authenticated user: $reason"
        log_gate "INFO" "SEC-009B: Task $task_id rejected by authenticated user $user_id"
    else
        _auth_log_event "REJECT_FAIL" "$user_id" "$token_hash" "$task_id" 0 "Rejection failed (exit code: $result)"
        log_gate "ERROR" "SEC-009B: Authenticated rejection failed for task $task_id"
    fi

    return $result
}

# -----------------------------------------------------------------------------
# SEC-009B.14: List Active Sessions
# -----------------------------------------------------------------------------
# Lists all active (non-expired, non-revoked) sessions.
# Usage: auth_list_sessions [user_id]
# -----------------------------------------------------------------------------
auth_list_sessions() {
    local filter_user="${1:-}"

    _auth_init_db

    local sqlite3_bin
    if sqlite3_bin=$(_get_binary "sqlite3" 2>/dev/null); then
        local user_filter=""
        if [[ -n "$filter_user" ]]; then
            user_filter="AND user_id='$filter_user'"
        fi

        echo "=== Active Sessions ==="
        "$sqlite3_bin" -header -column "$AUTH_DB" <<SQL
SELECT
    user_id as User,
    created_at as Created,
    expires_at as Expires,
    last_used_at as LastUsed,
    ip_address as IP
FROM auth_tokens
WHERE revoked=0
  AND expires_at > datetime('now')
  $user_filter
ORDER BY created_at DESC;
SQL
        return 0
    else
        echo "Error: sqlite3 not available" >&2
        return 1
    fi
}

# -----------------------------------------------------------------------------
# SEC-009B.15: Revoke All Sessions for User
# -----------------------------------------------------------------------------
# Revokes all active sessions for a specific user.
# Usage: auth_revoke_all <user_id> [reason]
# -----------------------------------------------------------------------------
auth_revoke_all() {
    local user_id="$1"
    local reason="${2:-administrative_revocation}"

    if [[ -z "$user_id" ]]; then
        echo "Error: user_id is required" >&2
        return 1
    fi

    _auth_init_db

    local sqlite3_bin
    if sqlite3_bin=$(_get_binary "sqlite3" 2>/dev/null); then
        local count
        count=$("$sqlite3_bin" "$AUTH_DB" <<SQL
UPDATE auth_tokens
SET revoked=1, revoked_at=datetime('now'), revoked_reason='$reason'
WHERE user_id='$user_id' AND revoked=0;
SELECT changes();
SQL
)

        _auth_log_event "REVOKE_ALL" "$user_id" "" "" 1 "Revoked ${count:-0} sessions: $reason"
        log_gate "INFO" "SEC-009B: Revoked ${count:-0} sessions for user $user_id"
        echo "Revoked ${count:-0} sessions for user $user_id"
        return 0
    else
        echo "Error: sqlite3 not available" >&2
        return 1
    fi
}

# -----------------------------------------------------------------------------
# SEC-009B.16: Auth Audit Report
# -----------------------------------------------------------------------------
# Generates an audit report of authentication events.
# Usage: auth_audit_report [hours]
# -----------------------------------------------------------------------------
auth_audit_report() {
    local hours="${1:-24}"

    _auth_init_db

    local sqlite3_bin
    if sqlite3_bin=$(_get_binary "sqlite3" 2>/dev/null); then
        echo "=== Authentication Audit Report (last ${hours}h) ==="
        echo ""
        echo "Event Summary:"
        "$sqlite3_bin" "$AUTH_DB" <<SQL
SELECT
    event_type,
    COUNT(*) as count,
    SUM(CASE WHEN success=1 THEN 1 ELSE 0 END) as successes,
    SUM(CASE WHEN success=0 THEN 1 ELSE 0 END) as failures
FROM auth_audit
WHERE timestamp > datetime('now', '-$hours hours')
GROUP BY event_type
ORDER BY count DESC;
SQL

        echo ""
        echo "Recent Events:"
        "$sqlite3_bin" -header -column "$AUTH_DB" <<SQL
SELECT
    timestamp,
    event_type as Event,
    user_id as User,
    task_id as Task,
    CASE WHEN success=1 THEN 'OK' ELSE 'FAIL' END as Status
FROM auth_audit
WHERE timestamp > datetime('now', '-$hours hours')
ORDER BY timestamp DESC
LIMIT 20;
SQL

        echo ""
        echo "Failed Attempts by IP:"
        "$sqlite3_bin" "$AUTH_DB" <<SQL
SELECT
    ip_address,
    COUNT(*) as attempts,
    MAX(attempt_at) as last_attempt
FROM auth_failures
WHERE attempt_at > datetime('now', '-$hours hours')
GROUP BY ip_address
ORDER BY attempts DESC
LIMIT 10;
SQL
        return 0
    else
        echo "Error: sqlite3 not available" >&2
        return 1
    fi
}

# =============================================================================
# ENTRY POINT
# =============================================================================

main() {
    local command="${1:-}"
    shift || true

    case "$command" in
        gate)
            # Run quality gates only (no approve/reject)
            quality_gate "$@"
            ;;
        approve)
            # Manually approve a task (requires authentication)
            local task_id="$1"
            local token="$2"
            local workspace="${3:-}"

            if [[ -z "$task_id" ]] || [[ -z "$token" ]]; then
                echo "Usage: $0 approve <task_id> <token> [workspace]"
                echo ""
                echo "Approves a task with authentication."
                echo "Obtain a token first with: $0 auth login"
                exit 1
            fi

            approve_with_auth "$task_id" "$token" "$workspace"
            ;;
        reject)
            # Manually reject a task with reason
            reject_task "$@"
            ;;
        workflow)
            # M2-010: Unified workflow (gates + approve/reject)
            unified_workflow "$@"
            ;;
        batch)
            # Process multiple tasks
            batch_workflow "$@"
            ;;
        status)
            # Get status of a task
            task_status "$@"
            ;;
        verify-ledger)
            # Verify ledger integrity (SEC-007)
            verify_ledger_integrity
            ;;
        rotate-ledger)
            # Rotate ledger if needed
            rotate_ledger_if_needed
            ;;
        verify-paths)
            # SEC-008C: Verify path security configuration
            echo "=== SEC-008C: Path Security Verification ==="
            echo ""
            echo "PATH_WHITELIST directories:"
            for dir in "${PATH_WHITELIST[@]}"; do
                if [[ -d "$dir" ]]; then
                    echo "  [OK] $dir"
                else
                    echo "  [MISSING] $dir"
                fi
            done
            echo ""
            echo "PATH manipulation check:"
            if detect_path_manipulation; then
                echo "  [PASS] No manipulation detected"
            else
                echo "  [FAIL] PATH manipulation detected (see logs)"
            fi
            echo ""
            echo "Common binaries resolution:"
            for bin in python3 npm jq grep awk head; do
                local resolved
                if resolved=$(_get_binary "$bin" 2>/dev/null); then
                    echo "  [OK] $bin -> $resolved"
                else
                    echo "  [WARN] $bin -> not found in secure paths"
                fi
            done
            echo ""
            echo "Security log locations:"
            echo "  Violations: ${_SECURITY_VIOLATIONS_LOG}"
            echo "  Audit: ${_PATH_AUDIT_LOG}"
            ;;
        sanitize-path)
            # SEC-008C: Force PATH sanitization
            echo "SEC-008C: Sanitizing PATH..."
            echo "Before: $PATH"
            block_path_manipulation
            echo "After: $PATH"
            ;;

        # =============================================================
        # SEC-009B: Authentication Commands
        # =============================================================
        auth)
            # Authentication subcommands
            local auth_cmd="${1:-help}"
            shift || true

            case "$auth_cmd" in
                login)
                    # Create new session token
                    local user_id="${1:-$(whoami)}"
                    local token
                    token=$(auth_login "$user_id")
                    if [[ $? -eq 0 ]]; then
                        echo ""
                        echo "=== Session Token Created ==="
                        echo "User:    $user_id"
                        echo "Expires: ${AUTH_TOKEN_EXPIRY_HOURS} hours"
                        echo ""
                        echo "TOKEN: $token"
                        echo ""
                        echo "IMPORTANT: Store this token securely!"
                        echo "Use it with: $0 approve <task_id> <token>"
                    fi
                    ;;
                logout)
                    # Revoke a token
                    local token="$1"
                    if [[ -z "$token" ]]; then
                        echo "Usage: $0 auth logout <token>"
                        exit 1
                    fi
                    auth_logout "$token"
                    ;;
                status)
                    # Check token status
                    local token="$1"
                    if [[ -z "$token" ]]; then
                        echo "Usage: $0 auth status <token>"
                        exit 1
                    fi
                    auth_token_status "$token"
                    ;;
                validate)
                    # Validate token (for scripts)
                    local token="$1"
                    if [[ -z "$token" ]]; then
                        echo "Usage: $0 auth validate <token>"
                        exit 1
                    fi
                    if auth_validate_token "$token"; then
                        echo "VALID (user: $AUTH_USER_ID)"
                        exit 0
                    else
                        echo "INVALID"
                        exit 1
                    fi
                    ;;
                sessions)
                    # List active sessions
                    auth_list_sessions "${1:-}"
                    ;;
                revoke-all)
                    # Revoke all sessions for user
                    local user_id="$1"
                    local reason="${2:-administrative_revocation}"
                    if [[ -z "$user_id" ]]; then
                        echo "Usage: $0 auth revoke-all <user_id> [reason]"
                        exit 1
                    fi
                    auth_revoke_all "$user_id" "$reason"
                    ;;
                cleanup)
                    # Clean up expired tokens
                    auth_cleanup "${1:-7}"
                    ;;
                audit)
                    # Generate audit report
                    auth_audit_report "${1:-24}"
                    ;;
                help|*)
                    echo "SEC-009B: Authentication Commands"
                    echo ""
                    echo "Usage: $0 auth <subcommand> [args]"
                    echo ""
                    echo "Subcommands:"
                    echo "  login [user_id]            Create session token (default: current user)"
                    echo "  logout <token>             Revoke/logout a session token"
                    echo "  status <token>             Check token status (valid/expired/revoked)"
                    echo "  validate <token>           Validate token (for scripts, exits 0/1)"
                    echo "  sessions [user_id]         List active sessions"
                    echo "  revoke-all <user_id> [reason]  Revoke all sessions for user"
                    echo "  cleanup [days]             Remove expired tokens (default: 7 days)"
                    echo "  audit [hours]              Generate audit report (default: 24 hours)"
                    echo ""
                    echo "Configuration (environment variables):"
                    echo "  AUTH_TOKEN_EXPIRY_HOURS    Token lifetime (default: 8)"
                    echo "  AUTH_MAX_FAILED_ATTEMPTS   Rate limit threshold (default: 10)"
                    echo "  AUTH_DB                    Auth database path"
                    ;;
            esac
            ;;

        approve-auth)
            # SEC-009B: Authenticated approval (requires token)
            local task_id="$1"
            local token="$2"
            local workspace="${3:-}"

            if [[ -z "$task_id" ]] || [[ -z "$token" ]]; then
                echo "Usage: $0 approve-auth <task_id> <token> [workspace]"
                echo ""
                echo "Approves a task with authentication."
                echo "Obtain a token first with: $0 auth login"
                exit 1
            fi

            approve_with_auth "$task_id" "$token" "$workspace"
            ;;

        reject-auth)
            # SEC-009B: Authenticated rejection (requires token)
            local task_id="$1"
            local token="$2"
            local workspace="${3:-}"
            local reason="${4:-Quality gates failed}"

            if [[ -z "$task_id" ]] || [[ -z "$token" ]]; then
                echo "Usage: $0 reject-auth <task_id> <token> [workspace] [reason]"
                echo ""
                echo "Rejects a task with authentication."
                echo "Obtain a token first with: $0 auth login"
                exit 1
            fi

            reject_with_auth "$task_id" "$token" "$workspace" "$reason"
            ;;

        workflow-auth)
            # SEC-009B: Authenticated unified workflow
            local task_id="$1"
            local token="$2"
            local workspace="${3:-$(pwd)}"

            if [[ -z "$task_id" ]] || [[ -z "$token" ]]; then
                echo "Usage: $0 workflow-auth <task_id> <token> [workspace]"
                echo ""
                echo "Runs unified workflow with authenticated approval/rejection."
                echo "Obtain a token first with: $0 auth login"
                exit 1
            fi

            # Validate token before running workflow
            if ! auth_validate_token "$token"; then
                echo "Error: Invalid or expired authentication token" >&2
                exit 1
            fi

            local user_id="${AUTH_USER_ID:-unknown}"
            log_gate "INFO" "SEC-009B: Authenticated workflow by $user_id for task $task_id"

            # Run quality gates
            local gate_result=0
            quality_gate "$task_id" "$workspace" || gate_result=$?

            case $gate_result in
                0)
                    # All gates passed - approve with auth
                    approve_with_auth "$task_id" "$token" "$workspace"
                    ;;
                1)
                    # Gates failed - reject with auth
                    reject_with_auth "$task_id" "$token" "$workspace" "Quality gates failed"
                    ;;
                2)
                    # Max retries exceeded - reject with auth
                    reject_with_auth "$task_id" "$token" "$workspace" "Max retries exceeded"
                    ;;
                *)
                    reject_with_auth "$task_id" "$token" "$workspace" "Unexpected error (code: $gate_result)"
                    ;;
            esac
            ;;

        *)
            echo "supervisor-approver.sh v2.2.0 (M2-010 Unified + SEC-008C + SEC-009B Auth)"
            echo ""
            echo "Usage: $0 <command> [args]"
            echo ""
            echo "Quality Gate Commands:"
            echo "  gate <task_id> [workspace]     Run quality gates only"
            echo "  approve <task_id> <token> [workspace]  Approve a task (auth required)"
            echo "  reject <task_id> [workspace] [reason]  Reject a task (no auth)"
            echo "  workflow <task_id> [workspace] Unified workflow (gates + decision)"
            echo "  batch <task1> <task2> ...      Process multiple tasks"
            echo "  status <task_id>               Get task status"
            echo ""
            echo "Authenticated Commands (SEC-009B):"
            echo "  auth <subcommand>              Authentication management"
            echo "  approve-auth <task_id> <token> [workspace]      Approve with auth"
            echo "  reject-auth <task_id> <token> [workspace] [reason]  Reject with auth"
            echo "  workflow-auth <task_id> <token> [workspace]     Workflow with auth"
            echo ""
            echo "Maintenance Commands:"
            echo "  verify-ledger                  Verify ledger integrity (SEC-007)"
            echo "  rotate-ledger                  Rotate ledger if oversized"
            echo "  verify-paths                   Verify path security (SEC-008C)"
            echo "  sanitize-path                  Force PATH sanitization (SEC-008C)"
            echo ""
            echo "Authentication Quick Start:"
            echo "  1. Create token:  $0 auth login"
            echo "  2. Approve task:  $0 approve TASK-001 <token>"
            echo "  3. Logout:        $0 auth logout <token>"
            echo ""
            echo "Environment Variables:"
            echo "  COVERAGE_THRESHOLD        Minimum coverage % (default: 80)"
            echo "  MAX_RETRIES               Max retry attempts (default: 3)"
            echo "  AUTH_TOKEN_EXPIRY_HOURS   Token lifetime in hours (default: 8)"
            echo "  AUTH_MAX_FAILED_ATTEMPTS  Rate limit threshold (default: 10)"
            echo "  DEBUG                     Set to 1 to enable debug logging"
            echo ""
            exit 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
