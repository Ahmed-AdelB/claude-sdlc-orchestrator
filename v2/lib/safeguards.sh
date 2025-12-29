#!/bin/bash
# =============================================================================
# safeguards.sh - Comprehensive Safeguards & Circuit Breakers
# =============================================================================
# Implements multi-layer protection for autonomous SDLC:
# 1. Rejection Loop Prevention
# 2. Destructive Operation Blocking
# 3. Resource Usage Limits
# 4. Agent Health Monitoring
# 5. Quality Gate Enforcement
# =============================================================================

# Configuration
SAFEGUARDS_DIR="$HOME/.claude/autonomous/state/safeguards"
HISTORY_DIR="$HOME/.claude/autonomous/tasks/history"
METRICS_DIR="$HOME/.claude/autonomous/metrics"
LOG_FILE="$HOME/.claude/autonomous/logs/safeguards.log"

MAX_CPU_PERCENT=80
MAX_MEM_PERCENT=80
MIN_DISK_SPACE_MB=1024
MAX_CONSECUTIVE_FAILURES=3

# Ensure directories exist
mkdir -p "$SAFEGUARDS_DIR" "$METRICS_DIR" "$(dirname "$LOG_FILE")"

log_safeguard() {
    local level="$1"
    local msg="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $msg" >> "$LOG_FILE"
}

# -----------------------------------------------------------------------------
# 1. Rejection Loop Prevention
# -----------------------------------------------------------------------------
check_rejection_loop() {
    local task_json="$1"
    local utils_dir="$(dirname "${BASH_SOURCE[0]}")/../utils"
    
    if [[ ! -f "$task_json" ]]; then
        return 0 # Skip if no task file
    fi

    if python3 "$utils_dir/lineage_graph.py" \
        --history-dir "$HISTORY_DIR" \
        --current-task "$task_json"; then
        return 0
    else
        log_safeguard "ERROR" "Rejection loop detected for task $(basename "$task_json")"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# 2. Destructive Operation Blocking
# -----------------------------------------------------------------------------
# Block list of dangerous command patterns (expanded for SEC-009A)
BLACKLISTED_PATTERNS=(
    # File system destruction
    "rm -rf /"
    "rm -rf ~"
    "rm -rf *"
    "rmdir /"

    # Disk operations
    "mkfs"
    "dd if="
    "> /dev/sd"
    "> /dev/nvme"

    # Fork bomb variations
    ":(){ :|:& };:"
    ":(){:|:&};"
    "bomb(){ bomb|bomb& };bomb"

    # Permission escalation
    "chmod 777 /"
    "chmod -R 777"
    "chown root /"

    # Database destruction
    "DROP TABLE"
    "DROP DATABASE"
    "DELETE FROM"
    "TRUNCATE TABLE"

    # System shutdown
    "shutdown -h"
    "shutdown -r"
    "init 0"
    "init 6"
    "systemctl poweroff"
    "systemctl reboot"

    # Process killing
    "kill -9 1"
    "kill -9 -1"
    "killall"
    "pkill -9"

    # Remote code execution
    "curl|bash"
    "curl|sh"
    "wget|bash"
    "wget|sh"
    'eval $(curl'
    'eval $(wget'

    # History manipulation
    "history -c"
    "unset HISTFILE"
    "> ~/.bash_history"
)

# =============================================================================
# Content Normalization for Pattern Matching (SEC-009A)
# =============================================================================
# Normalizes content to prevent pattern matching evasion.
# Handles: case variations, Unicode lookalikes, whitespace tricks, encoding.
# =============================================================================

# Normalize content for consistent pattern matching
# Usage: normalized=$(normalize_for_matching "$content")
normalize_for_matching() {
    local content="$1"

    # Return empty if input is empty
    [[ -z "$content" ]] && return 0

    local normalized="$content"

    # Step 1: Remove zero-width characters (Unicode lookalike prevention)
    # Zero-width space (U+200B), zero-width non-joiner (U+200C),
    # zero-width joiner (U+200D), LTR mark (U+200E), RTL mark (U+200F),
    # BOM (U+FEFF), non-breaking space (U+00A0) -> regular space
    normalized=$(printf '%s' "$normalized" | sed 's/\xE2\x80\x8B//g; s/\xE2\x80\x8C//g; s/\xE2\x80\x8D//g; s/\xE2\x80\x8E//g; s/\xE2\x80\x8F//g; s/\xEF\xBB\xBF//g; s/\xC2\xA0/ /g')

    # Step 2: Convert to lowercase for case-insensitive matching
    normalized=$(printf '%s' "$normalized" | tr '[:upper:]' '[:lower:]')

    # Step 3: Normalize whitespace (multiple spaces/tabs to single space)
    normalized=$(printf '%s' "$normalized" | tr -s '[:space:]' ' ')

    # Step 3b: Trim leading/trailing whitespace
    normalized=$(printf '%s' "$normalized" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

    # Step 4: Remove non-printable characters except newline
    normalized=$(printf '%s' "$normalized" | tr -d '\000-\010\013-\037\177')

    # Step 5: Normalize common fullwidth characters to ASCII equivalents
    # Fullwidth slash, backslash, colon, semicolon, pipe
    normalized=$(printf '%s' "$normalized" | sed 's/／/\//g; s/＼/\\/g; s/：/:/g; s/；/;/g; s/｜/|/g')

    # Step 6: URL-decode %XX sequences if present (for encoded evasion attempts)
    if echo "$normalized" | grep -qE '%[0-9A-Fa-f]{2}'; then
        # Use python for URL decoding if available, otherwise skip
        if command -v python3 &>/dev/null; then
            normalized=$(printf '%s' "$normalized" | python3 -c "import sys, urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))" 2>/dev/null || echo "$normalized")
        fi
    fi

    printf '%s' "$normalized"
}

# Normalize patterns for consistent matching (SEC-009A)
# Usage: normalized_pattern=$(normalize_pattern_for_matching "$pattern")
normalize_pattern_for_matching() {
    local input="$1"

    # Return empty if input is empty
    [[ -z "$input" ]] && return 0

    local normalized
    normalized=$(echo "$input" | tr '[:upper:]' '[:lower:]' | tr -s '[:space:]' ' ' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    printf '%s' "$normalized"
}

# Check content against destructive patterns with normalization
# Usage: check_destructive_normalized "$content"
# Returns: 0 if safe, 1 if destructive pattern detected
check_destructive_normalized() {
    local content="$1"

    # Normalize the input before checking
    local normalized
    normalized=$(normalize_for_matching "$content")

    # Expanded pattern list (all lowercase after normalization)
    # Using regex patterns for flexible matching
    local patterns=(
        "rm -rf /"
        "rm -rf ~"
        'rm -rf \$home'
        "rm -rf \*"
        "rmdir /"
        "mkfs"
        "mkfs\."
        "dd if="
        "dd of=/dev"
        ":(){:|:&};"
        ":\(\){ :|:& };"
        "fork bomb"
        "chmod 777 /"
        "chmod -r 777"
        "chown root /"
        "> /dev/sd"
        "> /dev/nvme"
        "drop table"
        "drop database"
        "delete from.*where.*1.*=.*1"
        "truncate table"
        "shutdown -h"
        "shutdown -r"
        "init 0"
        "init 6"
        "systemctl poweroff"
        "systemctl reboot"
        "kill -9 1$"
        "kill -9 -1"
        "killall.*-9"
        "pkill.*-9"
        'curl.*\|.*bash'
        'wget.*\|.*bash'
        'curl.*\|.*sh'
        'wget.*\|.*sh'
        'eval.*\$\(curl'
        'eval.*\$\(wget'
        "history -c"
        "unset histfile"
        "> ~/\.bash_history"
        "> /etc/passwd"
        "> /etc/shadow"
    )

    for pattern in "${patterns[@]}"; do
        local normalized_pattern
        normalized_pattern=$(normalize_pattern_for_matching "$pattern")
        if echo "$normalized" | grep -qiE "$normalized_pattern"; then
            log_safeguard "CRITICAL" "Destructive pattern detected: '$normalized_pattern' in normalized content"
            return 1
        fi
    done

    return 0
}

# Validate git commit message for destructive patterns and suspicious characters
# Usage: validate_commit_message "$message"
# Returns: 0 if safe, 1 if suspicious
validate_commit_message() {
    local message="$1"

    # Normalize the message
    local normalized
    normalized=$(normalize_for_matching "$message")

    # Check for destructive patterns
    if ! check_destructive_normalized "$normalized"; then
        log_safeguard "CRITICAL" "Destructive pattern detected in commit message"
        return 1
    fi

    # Check for suspicious Unicode (potential evasion attempt)
    # Compare original length vs normalized length
    local orig_len=${#message}
    local norm_len=${#normalized}
    local diff_chars=$((orig_len - norm_len))

    if [[ $diff_chars -gt 5 ]]; then
        log_safeguard "WARN" "Commit message contains $diff_chars suspicious/hidden characters (potential evasion attempt)"
        # Warning only, not blocking - but log it
    fi

    # Check for common shell injection patterns in commit messages
    local shell_patterns=(
        '\$\('
        '\`'
        '\$\{'
        '&&.*rm'
        ';.*rm'
        '\|.*sh'
    )

    for pattern in "${shell_patterns[@]}"; do
        if echo "$message" | grep -qE "$pattern"; then
            log_safeguard "WARN" "Suspicious shell pattern in commit message: $pattern"
        fi
    done

    return 0
}

check_destructive_ops() {
    local command="$1"

    # SEC-009A: Use normalized pattern matching first
    if ! check_destructive_normalized "$command"; then
        return 1
    fi

    # Normalize command for case-insensitive legacy matching
    local normalized_command
    normalized_command=$(normalize_for_matching "$command")

    # Legacy blacklist check (kept for backwards compatibility and explicit patterns)
    for pattern in "${BLACKLISTED_PATTERNS[@]}"; do
        local normalized_pattern
        normalized_pattern=$(normalize_pattern_for_matching "$pattern")
        if [[ "$normalized_command" == *"$normalized_pattern"* ]]; then
            log_safeguard "CRITICAL" "Blocked destructive command (normalized): $normalized_pattern"
            return 1
        fi
    done

    return 0
}

# -----------------------------------------------------------------------------
# 3. Resource Limits
# -----------------------------------------------------------------------------
check_resources() {
    # Check CPU
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    if (( $(echo "$cpu_usage $MAX_CPU_PERCENT" | awk '{print ($1 > $2)}') )); then
        log_safeguard "WARN" "High CPU usage: ${cpu_usage}%"
        # Optional: return 1 to block new tasks
    fi

    # Check Memory
    local mem_usage=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
    if (( $(echo "$mem_usage $MAX_MEM_PERCENT" | awk '{print ($1 > $2)}') )); then
        log_safeguard "WARN" "High Memory usage: ${mem_usage}%"
        # Optional: return 1
    fi

    # Check Disk Space
    local disk_avail=$(df -m . | awk 'NR==2 {print $4}')
    if (( disk_avail < MIN_DISK_SPACE_MB )); then
        log_safeguard "CRITICAL" "Low disk space: ${disk_avail}MB"
        return 1
    fi

    return 0
}

# -----------------------------------------------------------------------------
# 4. Agent Health
# -----------------------------------------------------------------------------
check_agent_health() {
    # Check if the main agent loop is responding
    # This assumes a PID file or a heartbeat file is updated
    local heartbeat_file="$SAFEGUARDS_DIR/heartbeat"
    
    if [[ -f "$heartbeat_file" ]]; then
        local last_beat=$(stat -c %Y "$heartbeat_file")
        local now=$(date +%s)
        local diff=$((now - last_beat))
        
        if (( diff > 300 )); then # 5 minutes
            log_safeguard "ERROR" "Agent heartbeat lost! Last beat ${diff}s ago."
            return 1
        fi
    fi
    return 0
}

# -----------------------------------------------------------------------------
# 5. Quality Gate
# -----------------------------------------------------------------------------
check_quality_gate() {
    local current_metrics="$1" # JSON file
    local baseline="$METRICS_DIR/baseline.json"
    
    if [[ ! -f "$baseline" ]] || [[ ! -f "$current_metrics" ]]; then
        return 0 # Cannot compare
    fi
    
    # Simple python one-liner to compare test coverage
    local degradation=$(python3 -c "
import json
import sys
try:
    base = json.load(open(sys.argv[1]))
    curr = json.load(open(sys.argv[2]))
    if curr.get('coverage', 0) < base.get('coverage', 0) - 5: # 5% drop allowed
        print('Coverage dropped')
        sys.exit(1)
except Exception:
    pass
" "$baseline" "$current_metrics")
    
    if [[ -n "$degradation" ]]; then
        log_safeguard "ERROR" "Quality Gate Failed: $degradation"
        return 1
    fi
    return 0
}

# -----------------------------------------------------------------------------
# Main Entrypoint
# -----------------------------------------------------------------------------
run_safeguards() {
    local task_file="$1"
    local command="$2"
    
    check_resources || return 1
    check_agent_health || return 1
    
    if [[ -n "$command" ]]; then
        check_destructive_ops "$command" || return 1
    fi
    
    if [[ -n "$task_file" ]]; then
        check_rejection_loop "$task_file" || return 1
    fi
    
    return 0
}

# Export
export -f check_rejection_loop
export -f check_destructive_ops
export -f check_resources
export -f check_agent_health
export -f check_quality_gate
export -f run_safeguards
# SEC-009A: Pattern normalization exports
export -f normalize_for_matching
export -f check_destructive_normalized
export -f validate_commit_message
