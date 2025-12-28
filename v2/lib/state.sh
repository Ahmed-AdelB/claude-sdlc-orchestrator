#!/bin/bash
# =============================================================================
# state.sh - File locking and atomic state management
# =============================================================================
# Provides:
# - File locking with flock for concurrent access safety
# - Atomic file writes (temp file + mv pattern)
# - Config validation
# - State directory management
#
# This file is sourced by common.sh - do not source directly
# =============================================================================

# Ensure we have required directories (may not be set if sourced directly)
: "${STATE_DIR:=$HOME/.claude/autonomous/state}"
: "${LOCKS_DIR:=$STATE_DIR/locks}"
: "${CONFIG_DIR:=$HOME/.claude/autonomous/config}"

# =============================================================================
# File Locking
# =============================================================================

# Acquire an exclusive lock and execute a command
# Usage: with_lock "lockname" command args...
with_lock() {
    local lock_name="$1"
    shift
    local lock_file="${LOCKS_DIR}/${lock_name}.lock"

    # Ensure locks directory exists
    mkdir -p "${LOCKS_DIR}"

    # Use file descriptor 9 for the lock
    exec 9>"${lock_file}"

    # Try to acquire exclusive lock (blocks until available)
    if ! flock -x 9; then
        log_error "Failed to acquire lock: ${lock_name}"
        return 1
    fi

    # Execute the command
    local result=0
    "$@" || result=$?

    # Lock is automatically released when fd 9 is closed (script exit or exec 9>&-)
    exec 9>&-

    return $result
}

# Try to acquire a lock without blocking
# Returns 0 if lock acquired, 1 if already locked
try_lock() {
    local lock_name="$1"
    local lock_file="${LOCKS_DIR}/${lock_name}.lock"

    mkdir -p "${LOCKS_DIR}"
    exec 9>"${lock_file}"

    # Non-blocking lock attempt
    if flock -n -x 9; then
        return 0  # Lock acquired
    else
        exec 9>&-
        return 1  # Already locked
    fi
}

# Release a lock (usually handled automatically by fd close)
release_lock() {
    exec 9>&- 2>/dev/null || true
}

# Acquire a lock with timeout
# Usage: with_lock_timeout "lockname" timeout_seconds command args...
with_lock_timeout() {
    local lock_name="$1"
    local timeout="$2"
    shift 2
    local lock_file="${LOCKS_DIR}/${lock_name}.lock"

    mkdir -p "${LOCKS_DIR}"
    exec 9>"${lock_file}"

    # Try to acquire lock with timeout
    if ! flock -x -w "${timeout}" 9; then
        log_error "Lock timeout after ${timeout}s: ${lock_name}"
        exec 9>&-
        return 1
    fi

    local result=0
    "$@" || result=$?

    exec 9>&-
    return $result
}

# Check if a lock is currently held (for debugging)
is_locked() {
    local lock_name="$1"
    local lock_file="${LOCKS_DIR}/${lock_name}.lock"

    [[ -f "$lock_file" ]] || return 1

    # Try non-blocking lock
    exec 8>"${lock_file}"
    if flock -n -x 8 2>/dev/null; then
        flock -u 8
        exec 8>&-
        return 1  # Not locked
    else
        exec 8>&-
        return 0  # Locked
    fi
}

# =============================================================================
# Atomic File Operations
# =============================================================================

# Atomic file writes (temp file + mv pattern)
# Usage: atomic_write "destination_file" "content"
# Or:    echo "content" | atomic_write "destination_file"
atomic_write() {
    local dest="$1"
    local content="${2:-}"
    local dest_dir
    dest_dir="$(dirname "$dest")"

    # Ensure destination directory exists
    mkdir -p "$dest_dir"

    # Create secure temp file in same directory (important for atomic mv)
    # Use mktemp with proper directory and random suffix (#89)
    local tmp
    tmp="$(mktemp -p "$dest_dir" ".$(basename "$dest").tmp.XXXXXXXXXX")"

    # Set restrictive permissions immediately
    chmod 600 "$tmp"

    # Write content
    if [[ -n "$content" ]]; then
        printf '%s' "$content" > "$tmp"
    else
        # Read from stdin
        cat > "$tmp"
    fi

    # Sync to disk before move (optional, for durability)
    sync "$tmp" 2>/dev/null || true

    # Atomic move
    mv "$tmp" "$dest"
}

# Append content to a file atomically (via lock + append)
# Usage: atomic_append "file" "content"
atomic_append() {
    local file="$1"
    local content="$2"
    local lock_name
    
    # Use hash of full path to avoid collisions (#85 fix)
    if command -v md5sum &>/dev/null; then
        lock_name="append_$(echo "$file" | md5sum | cut -d' ' -f1)"
    else
        # Fallback to replaced path if md5sum missing
        lock_name="append_$(echo "$file" | tr '/' '_')"
    fi

    with_lock "${lock_name}" _do_append "$file" "$content"
}

_do_append() {
    local file="$1"
    local content="$2"
    mkdir -p "$(dirname "$file")"
    printf '%s\n' "$content" >> "$file"
}

# Read file content safely
# Usage: content=$(safe_read "file" "default_value")
safe_read() {
    local file="$1"
    local default="${2:-}"

    if [[ -f "$file" && -r "$file" ]]; then
        cat "$file"
    else
        echo "$default"
    fi
}

# Atomically increment a counter file (#85 fix - ensure atomic read-modify-write)
# Usage: new_value=$(atomic_increment "counter_file")
atomic_increment() {
    local file="$1"
    local lock_name
    
    # Use hash of full path to avoid collisions (#85 fix)
    if command -v md5sum &>/dev/null; then
        lock_name="counter_$(echo "$file" | md5sum | cut -d' ' -f1)"
    else
        # Fallback to replaced path if md5sum missing
        lock_name="counter_$(echo "$file" | tr '/' '_')"
    fi

    # Use a wrapper to ensure output is properly captured (#85)
    local result
    result=$(with_lock "$lock_name" _do_increment "$file")
    echo "$result"
}

_do_increment() {
    local file="$1"
    local current=0

    mkdir -p "$(dirname "$file")"

    # Read current value within lock
    if [[ -f "$file" && -r "$file" ]]; then
        current=$(cat "$file" 2>/dev/null || echo 0)
        # Validate it's a number
        if ! [[ "$current" =~ ^[0-9]+$ ]]; then
            current=0
        fi
    fi

    # Calculate and write new value
    local new=$((current + 1))
    atomic_write "$file" "$new"

    # Return new value
    echo "$new"
}

# =============================================================================
# State File Operations
# =============================================================================

# Read a key from a state file (simple key=value format)
# Usage: value=$(state_get "state_file" "key" "default")
state_get() {
    local file="$1"
    local key="$2"
    local default="${3:-}"

    if [[ -f "$file" ]]; then
        local value
        value=$(grep -E "^${key}=" "$file" 2>/dev/null | head -1 | cut -d'=' -f2-)
        echo "${value:-$default}"
    else
        echo "$default"
    fi
}

# Set a key in a state file atomically
# Usage: state_set "state_file" "key" "value"
state_set() {
    local file="$1"
    local key="$2"
    local value="$3"
    local lock_name
    lock_name="state_$(basename "$file" | tr '.' '_')"

    with_lock "$lock_name" _do_state_set "$file" "$key" "$value"
}

_do_state_set() {
    local file="$1"
    local key="$2"
    local value="$3"

    mkdir -p "$(dirname "$file")"

    # Create new content with updated key
    local tmp
    tmp="$(mktemp)"

    # Copy existing entries except the one we're updating
    if [[ -f "$file" ]]; then
        grep -v -E "^${key}=" "$file" > "$tmp" 2>/dev/null || true
    fi

    # Add the new/updated entry
    echo "${key}=${value}" >> "$tmp"

    # Atomic replace
    mv "$tmp" "$file"
}

# Delete a key from a state file
# Usage: state_delete "state_file" "key"
state_delete() {
    local file="$1"
    local key="$2"

    if [[ ! -f "$file" ]]; then
        return 0
    fi

    local lock_name
    lock_name="state_$(basename "$file" | tr '.' '_')"

    with_lock "$lock_name" _do_state_delete "$file" "$key"
}

_do_state_delete() {
    local file="$1"
    local key="$2"

    local tmp
    tmp="$(mktemp)"
    grep -v -E "^${key}=" "$file" > "$tmp" 2>/dev/null || true
    mv "$tmp" "$file"
}

# =============================================================================
# Config Validation
# =============================================================================

# Validate a YAML config file
# Returns 0 if valid, 1 if invalid
validate_config() {
    local cfg="${1:-$CONFIG_DIR/tri-agent.yaml}"

    if [[ ! -f "$cfg" ]]; then
        log_error "Config file not found: $cfg"
        return 1
    fi

    # Try yq first (faster)
    if command -v yq &>/dev/null; then
        if ! yq eval '.' "$cfg" &>/dev/null; then
            log_error "Invalid YAML syntax in: $cfg"
            return 1
        fi

        # Check required sections
        local has_models has_routing
        has_models=$(yq eval '.models // ""' "$cfg")
        has_routing=$(yq eval '.routing // ""' "$cfg")

        if [[ -z "$has_models" || "$has_models" == "null" ]]; then
            log_error "Config missing required 'models' section"
            return 1
        fi
        if [[ -z "$has_routing" || "$has_routing" == "null" ]]; then
            log_error "Config missing required 'routing' section"
            return 1
        fi

        return 0
    fi

    # Fallback to Python
    if command -v python3 &>/dev/null; then
        python3 -c "
import yaml
import sys

try:
    with open('$cfg') as f:
        cfg = yaml.safe_load(f)

    if cfg is None:
        print('Error: Empty config file', file=sys.stderr)
        sys.exit(1)

    if 'models' not in cfg:
        print('Error: Missing models section', file=sys.stderr)
        sys.exit(1)

    if 'routing' not in cfg:
        print('Error: Missing routing section', file=sys.stderr)
        sys.exit(1)

    sys.exit(0)
except yaml.YAMLError as e:
    print(f'YAML Error: {e}', file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
" 2>&1
        return $?
    fi

    # No validation tools available - warn but proceed
    log_warn "No YAML validation tools (yq/python3) available"
    return 0
}

# Validate config against schema (if schema exists)
validate_config_schema() {
    local cfg="${1:-$CONFIG_DIR/tri-agent.yaml}"
    local schema="${2:-$CONFIG_DIR/schema.yaml}"

    if [[ ! -f "$schema" ]]; then
        log_warn "Schema file not found, skipping schema validation: $schema"
        return 0
    fi

    # Schema validation requires yq or python with jsonschema
    if command -v python3 &>/dev/null; then
        python3 -c "
import yaml
import sys

try:
    from jsonschema import validate, ValidationError
except ImportError:
    print('jsonschema not installed, skipping schema validation', file=sys.stderr)
    sys.exit(0)

try:
    with open('$cfg') as f:
        config = yaml.safe_load(f)
    with open('$schema') as f:
        schema = yaml.safe_load(f)

    validate(instance=config, schema=schema)
    sys.exit(0)
except ValidationError as e:
    print(f'Schema validation error: {e.message}', file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
" 2>&1
        return $?
    fi

    log_warn "Schema validation not available (requires python3 + jsonschema)"
    return 0
}

# =============================================================================
# Cleanup Functions
# =============================================================================

# Remove stale lock files (older than N seconds)
cleanup_stale_locks() {
    local max_age="${1:-3600}"  # Default: 1 hour

    if [[ ! -d "$LOCKS_DIR" ]]; then
        return 0
    fi

    find "$LOCKS_DIR" -name "*.lock" -type f -mmin "+$((max_age / 60))" -delete 2>/dev/null || true
}

# Cleanup old state files
cleanup_old_state() {
    local dir="$1"
    local max_age_days="${2:-7}"

    if [[ ! -d "$dir" ]]; then
        return 0
    fi

    find "$dir" -type f -mtime "+${max_age_days}" -delete 2>/dev/null || true
}

# =============================================================================
# Export Functions
# =============================================================================
export -f with_lock
export -f try_lock
export -f release_lock
export -f with_lock_timeout
export -f is_locked
export -f atomic_write
export -f atomic_append
export -f safe_read
export -f atomic_increment
export -f state_get
export -f state_set
export -f state_delete
export -f validate_config
export -f validate_config_schema
export -f cleanup_stale_locks
export -f cleanup_old_state
