#!/bin/bash
#
# auto-recovery.sh - Automatic error recovery for tri-agent system
# Version: 1.0.0
# Author: Ahmed Adel Bakr Alderai
#
# Usage:
#   ./auto-recovery.sh detect "error message or log file"
#   ./auto-recovery.sh recover <pattern_id> [--retry-count N]
#   ./auto-recovery.sh analyze <log_file>
#
# Exit codes:
#   0 - Recovery successful
#   1 - Recovery failed, escalation needed
#   2 - Unknown error pattern
#   3 - Max retries exceeded

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATTERNS_FILE="${SCRIPT_DIR}/patterns.json"
LOG_DIR="${HOME}/.claude/logs"
RECOVERY_LOG="${LOG_DIR}/recovery.log"
DEBUG_DIR="${HOME}/.claude/debug"
STATE_DIR="${HOME}/.claude/state"

# Ensure directories exist
mkdir -p "${LOG_DIR}" "${DEBUG_DIR}" "${STATE_DIR}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*"
    echo -e "${BLUE}${msg}${NC}"
    echo "${msg}" >> "${RECOVERY_LOG}"
}

log_warn() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $*"
    echo -e "${YELLOW}${msg}${NC}"
    echo "${msg}" >> "${RECOVERY_LOG}"
}

log_error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*"
    echo -e "${RED}${msg}${NC}" >&2
    echo "${msg}" >> "${RECOVERY_LOG}"
}

log_success() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $*"
    echo -e "${GREEN}${msg}${NC}"
    echo "${msg}" >> "${RECOVERY_LOG}"
}

# Check if jq is available
check_dependencies() {
    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed. Install with: sudo apt install jq"
        exit 1
    fi
}

# Load pattern by ID from patterns.json
get_pattern() {
    local pattern_id="$1"
    jq -r ".patterns[] | select(.id == \"${pattern_id}\")" "${PATTERNS_FILE}"
}

# Detect error pattern from message or log content
detect_pattern() {
    local error_content="$1"
    local detected_patterns=()

    # Read all patterns and check signatures
    while IFS= read -r pattern; do
        local pattern_id
        local signature
        pattern_id=$(echo "${pattern}" | jq -r '.id')
        signature=$(echo "${pattern}" | jq -r '.error_signature')

        if echo "${error_content}" | grep -qiE "${signature}"; then
            detected_patterns+=("${pattern_id}")
        fi
    done < <(jq -c '.patterns[]' "${PATTERNS_FILE}")

    # Return detected patterns
    if [[ ${#detected_patterns[@]} -gt 0 ]]; then
        printf '%s\n' "${detected_patterns[@]}"
        return 0
    else
        return 2
    fi
}

# Get retry state for a pattern
get_retry_count() {
    local pattern_id="$1"
    local task_id="${2:-default}"
    local state_file="${STATE_DIR}/retry_${pattern_id}_${task_id}.state"

    if [[ -f "${state_file}" ]]; then
        cat "${state_file}"
    else
        echo "0"
    fi
}

# Update retry state
update_retry_count() {
    local pattern_id="$1"
    local task_id="${2:-default}"
    local count="$3"
    local state_file="${STATE_DIR}/retry_${pattern_id}_${task_id}.state"

    echo "${count}" > "${state_file}"
}

# Clear retry state
clear_retry_state() {
    local pattern_id="$1"
    local task_id="${2:-default}"
    local state_file="${STATE_DIR}/retry_${pattern_id}_${task_id}.state"

    rm -f "${state_file}"
}

# Send notification based on severity
send_notification() {
    local severity="$1"
    local title="$2"
    local message="$3"

    case "${severity}" in
        critical)
            # Desktop notification with sound
            if command -v notify-send &> /dev/null; then
                notify-send -u critical "Tri-Agent CRITICAL: ${title}" "${message}"
            fi
            # Play sound if available
            if command -v paplay &> /dev/null && [[ -f /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga ]]; then
                paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga &
            fi
            ;;
        high)
            if command -v notify-send &> /dev/null; then
                notify-send -u normal "Tri-Agent ERROR: ${title}" "${message}"
            fi
            ;;
        medium)
            log_warn "ALERT [${severity}]: ${title} - ${message}"
            ;;
        *)
            log_info "NOTICE: ${title} - ${message}"
            ;;
    esac
}

# Save failure snapshot for debugging
save_failure_snapshot() {
    local pattern_id="$1"
    local error_content="$2"
    local task_id="${3:-unknown}"

    local snapshot_file="${DEBUG_DIR}/last-failure.json"

    cat > "${snapshot_file}" << EOF
{
    "cid": "s$(date +%Y%m%d)-${task_id}-recovery-$(printf '%03d' $RANDOM)",
    "ts": "$(date -Iseconds)",
    "pattern_id": "${pattern_id}",
    "error_excerpt": $(echo "${error_content}" | tail -c 5000 | jq -Rs .),
    "retries": $(get_retry_count "${pattern_id}" "${task_id}"),
    "recovery_script": "auto-recovery.sh",
    "env": {
        "TRI_AGENT_DEBUG": "${TRI_AGENT_DEBUG:-0}",
        "USER": "${USER}",
        "PWD": "${PWD}"
    }
}
EOF

    log_info "Failure snapshot saved to ${snapshot_file}"
}

#
# Recovery Functions
#

# ERR-001: Timeout - split and retry
split_and_retry() {
    local task_id="${1:-default}"
    local retry_count
    retry_count=$(get_retry_count "ERR-001" "${task_id}")
    local max_retries=3

    log_info "Attempting split_and_retry recovery (attempt $((retry_count + 1))/${max_retries})"

    if [[ ${retry_count} -ge ${max_retries} ]]; then
        log_error "Max retries exceeded for timeout recovery"
        escalate_to_user "ERR-001" "Timeout persists after ${max_retries} attempts. Task may need manual splitting."
        return 1
    fi

    update_retry_count "ERR-001" "${task_id}" $((retry_count + 1))

    log_info "Recovery steps:"
    log_info "  1. Split the task into 2-4 smaller subtasks"
    log_info "  2. Increase timeout: --timeout 600"
    log_info "  3. Route large context tasks to Gemini (1M tokens)"
    log_info "  4. Pre-filter files to reduce scope"

    # Return suggestion for automation
    echo "RECOVERY_ACTION=split_task"
    echo "SUGGESTED_TIMEOUT=600"
    echo "ROUTE_TO=gemini"

    return 0
}

# ERR-002: Auth failed - re-auth prompt
reauth_prompt() {
    local service="${1:-all}"

    log_warn "Authentication failure detected. Manual re-authentication required."

    send_notification "high" "Authentication Required" "Please re-authenticate ${service}"

    echo ""
    echo "=== AUTHENTICATION RECOVERY ==="
    echo ""

    case "${service}" in
        gemini|all)
            echo "For Gemini:"
            echo "  Run: gemini-switch"
            echo "  Or:  rm ~/.gemini/oauth_creds.json && gemini"
            echo ""
            ;;
    esac

    case "${service}" in
        codex|all)
            echo "For Codex:"
            echo "  Run: codex auth"
            echo ""
            ;;
    esac

    case "${service}" in
        claude|all)
            echo "For Claude:"
            echo "  Check ~/.claude/settings.json"
            echo "  Verify API key in environment"
            echo ""
            ;;
    esac

    echo "After re-authentication, retry your task."
    echo "================================"

    return 1  # Requires user action
}

# ERR-003: SQLite busy - retry with backoff
sqlite_retry_backoff() {
    local db_path="${1:-}"
    local task_id="${2:-default}"
    local retry_count
    retry_count=$(get_retry_count "ERR-003" "${task_id}")
    local max_retries=5
    local backoff_base=2
    local max_backoff=32

    if [[ ${retry_count} -ge ${max_retries} ]]; then
        log_error "Max retries exceeded for SQLite recovery"
        escalate_to_user "ERR-003" "Database lock persists after ${max_retries} attempts"
        return 1
    fi

    # Calculate backoff
    local backoff=$((backoff_base ** retry_count))
    [[ ${backoff} -gt ${max_backoff} ]] && backoff=${max_backoff}

    log_info "SQLite retry with ${backoff}s backoff (attempt $((retry_count + 1))/${max_retries})"

    # If database path provided, try WAL checkpoint
    if [[ -n "${db_path}" && -f "${db_path}" ]]; then
        log_info "Attempting WAL checkpoint on ${db_path}"
        sqlite3 "${db_path}" "PRAGMA wal_checkpoint(TRUNCATE);" 2>/dev/null || true
    fi

    # Check for stale locks
    if command -v lsof &> /dev/null && [[ -n "${db_path}" ]]; then
        local lockers
        lockers=$(lsof "${db_path}" 2>/dev/null | tail -n +2 || true)
        if [[ -n "${lockers}" ]]; then
            log_warn "Processes holding database lock:"
            echo "${lockers}"
        fi
    fi

    update_retry_count "ERR-003" "${task_id}" $((retry_count + 1))

    log_info "Waiting ${backoff} seconds before retry..."
    sleep "${backoff}"

    echo "RECOVERY_ACTION=retry"
    echo "BACKOFF_SECONDS=${backoff}"

    return 0
}

# ERR-004: Context exceeded - trigger summarization
trigger_summarization() {
    local current_tokens="${1:-0}"
    local target_model="${2:-claude}"

    log_info "Context length exceeded. Initiating summarization."

    # Get model limits
    local limit
    case "${target_model}" in
        claude)  limit=200000 ;;
        codex)   limit=400000 ;;
        gemini)  limit=1000000 ;;
        *)       limit=200000 ;;
    esac

    local target=$((limit / 2))  # Aim for 50% of limit

    log_info "Current tokens: ${current_tokens}, Target: ${target}, Model: ${target_model}"

    # If current model can't handle it, suggest routing to larger context model
    if [[ ${current_tokens} -gt 150000 && "${target_model}" != "gemini" ]]; then
        log_info "Recommending route to Gemini for large context (1M tokens)"
        echo "RECOVERY_ACTION=route_to_gemini"
        echo "RECOMMENDED_MODEL=gemini"
        return 0
    fi

    echo "RECOVERY_ACTION=summarize"
    echo "TARGET_TOKENS=${target}"
    echo "SUMMARIZATION_STEPS:"
    echo "  1. Identify non-essential context"
    echo "  2. Summarize intermediate results"
    echo "  3. Remove redundant information"
    echo "  4. Use file filtering to reduce scope"

    return 0
}

# ERR-005: Rate limit 429 - exponential backoff
exponential_backoff() {
    local task_id="${1:-default}"
    local retry_count
    retry_count=$(get_retry_count "ERR-005" "${task_id}")
    local max_retries=5
    local backoff_base=2
    local max_backoff=64

    if [[ ${retry_count} -ge ${max_retries} ]]; then
        log_error "Max retries exceeded for rate limit recovery"
        log_warn "Consider waiting for quota reset or using different model"
        escalate_to_user "ERR-005" "Rate limit persists. Daily quota may be exhausted."
        return 1
    fi

    # Calculate backoff
    local backoff=$((backoff_base ** (retry_count + 1)))
    [[ ${backoff} -gt ${max_backoff} ]] && backoff=${max_backoff}

    log_info "Rate limit hit. Backoff ${backoff}s (attempt $((retry_count + 1))/${max_retries})"

    update_retry_count "ERR-005" "${task_id}" $((retry_count + 1))

    # Check budget status
    log_info "Check daily budget status and consider:"
    log_info "  - Switching to cost-effective model"
    log_info "  - Reducing concurrent agents"
    log_info "  - Batching requests"

    log_info "Waiting ${backoff} seconds..."
    sleep "${backoff}"

    echo "RECOVERY_ACTION=retry"
    echo "BACKOFF_SECONDS=${backoff}"
    echo "RETRY_COUNT=$((retry_count + 1))"

    return 0
}

# ERR-006: Verification fail loop - escalate to user
escalate_to_user() {
    local pattern_id="${1:-unknown}"
    local message="${2:-Issue requires manual intervention}"
    local evidence="${3:-}"

    log_error "ESCALATION REQUIRED: ${message}"

    send_notification "critical" "Manual Intervention Required" "${message}"

    cat << EOF

================================================================================
                         ESCALATION TO USER REQUIRED
================================================================================

Pattern ID: ${pattern_id}
Timestamp:  $(date -Iseconds)
Message:    ${message}

EVIDENCE:
${evidence:-No additional evidence provided}

RECOMMENDED ACTIONS:
EOF

    # Get pattern-specific recommendations
    local pattern
    pattern=$(get_pattern "${pattern_id}")
    if [[ -n "${pattern}" && "${pattern}" != "null" ]]; then
        echo "${pattern}" | jq -r '.recovery_steps[]' | while read -r step; do
            echo "  - ${step}"
        done
    fi

    cat << EOF

DECISION NEEDED:
  [ ] Proceed with suggested recovery
  [ ] Provide alternative approach
  [ ] Abort current task

================================================================================

EOF

    # Log escalation
    echo "[$(date -Iseconds)] ESCALATION: ${pattern_id} - ${message}" >> "${LOG_DIR}/escalations.log"

    return 1
}

# ERR-007: Network retry
network_retry() {
    local task_id="${1:-default}"
    local retry_count
    retry_count=$(get_retry_count "ERR-007" "${task_id}")
    local max_retries=3
    local backoff=5

    if [[ ${retry_count} -ge ${max_retries} ]]; then
        log_error "Network recovery failed after ${max_retries} attempts"
        escalate_to_user "ERR-007" "Persistent network connectivity issues"
        return 1
    fi

    log_info "Network error detected. Checking connectivity..."

    # Check basic connectivity
    local endpoints=(
        "api.anthropic.com"
        "generativelanguage.googleapis.com"
        "api.openai.com"
    )

    for endpoint in "${endpoints[@]}"; do
        if curl -sf --max-time 5 "https://${endpoint}" > /dev/null 2>&1; then
            log_success "${endpoint}: reachable"
        else
            log_warn "${endpoint}: unreachable"
        fi
    done

    # Check DNS
    if ! host api.anthropic.com > /dev/null 2>&1; then
        log_error "DNS resolution failing. Check /etc/resolv.conf"
    fi

    update_retry_count "ERR-007" "${task_id}" $((retry_count + 1))

    local wait_time=$((backoff * (retry_count + 1)))
    log_info "Waiting ${wait_time}s before retry..."
    sleep "${wait_time}"

    echo "RECOVERY_ACTION=retry"
    echo "NETWORK_STATUS=checked"

    return 0
}

# ERR-008: Memory recovery
memory_recovery() {
    log_warn "Memory pressure detected. Initiating recovery..."

    # Show current memory status
    free -h

    # Find memory-heavy processes
    log_info "Top memory consumers:"
    ps aux --sort=-%mem | head -6

    log_info "Recovery steps:"
    echo "  1. Reduce concurrent agents"
    echo "  2. Split task into smaller memory footprint"
    echo "  3. Clear caches if needed: sync && sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'"
    echo "  4. Restart affected services"

    # Try to free some memory by clearing Claude caches
    if [[ -d "${HOME}/.claude/cache" ]]; then
        local cache_size
        cache_size=$(du -sh "${HOME}/.claude/cache" 2>/dev/null | cut -f1)
        log_info "Claude cache size: ${cache_size}"
        echo "  Run: rm -rf ~/.claude/cache/* to free cache"
    fi

    echo "RECOVERY_ACTION=reduce_memory"
    echo "SUGGESTED_MAX_AGENTS=3"

    return 0
}

# ERR-009: Git conflict resolution
git_conflict_resolve() {
    log_warn "Git conflict detected"

    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "Not in a git repository"
        return 1
    fi

    log_info "Conflicting files:"
    git diff --name-only --diff-filter=U

    log_info "Conflict details:"
    git status

    echo ""
    echo "MANUAL RESOLUTION REQUIRED"
    echo ""
    echo "Steps:"
    echo "  1. Review conflict markers in files (<<<<<<< ======= >>>>>>>)"
    echo "  2. Edit files to resolve conflicts"
    echo "  3. Stage resolved files: git add <file>"
    echo "  4. Complete merge: git commit"
    echo ""
    echo "Or abort: git merge --abort"

    escalate_to_user "ERR-009" "Git conflict requires manual resolution"

    return 1
}

# ERR-010: Disk cleanup
disk_cleanup() {
    log_warn "Low disk space detected. Running cleanup..."

    # Show disk usage
    df -h "${HOME}"

    log_info "Claude directory usage:"
    du -sh "${HOME}/.claude"/* 2>/dev/null | sort -hr | head -10

    # Cleanup old logs
    log_info "Cleaning logs older than 7 days..."
    find "${LOG_DIR}" -name "*.log" -mtime +7 -delete 2>/dev/null || true
    find "${LOG_DIR}" -name "*.log.gz" -mtime +30 -delete 2>/dev/null || true

    # Cleanup old checkpoints
    if [[ -d "${HOME}/.claude/sessions/checkpoints" ]]; then
        log_info "Cleaning checkpoints older than 3 days..."
        find "${HOME}/.claude/sessions/checkpoints" -name "*.json" -mtime +3 -delete 2>/dev/null || true
    fi

    # Compress large logs
    log_info "Compressing logs larger than 50MB..."
    find "${LOG_DIR}" -name "*.log" -size +50M -exec gzip {} \; 2>/dev/null || true

    # Vacuum SQLite databases
    log_info "Vacuuming databases..."
    for db in "${STATE_DIR}"/*.db; do
        if [[ -f "${db}" ]]; then
            sqlite3 "${db}" "VACUUM; PRAGMA wal_checkpoint(TRUNCATE);" 2>/dev/null || true
            log_info "Vacuumed: $(basename "${db}")"
        fi
    done

    # Report freed space
    log_success "Cleanup complete"
    df -h "${HOME}"

    echo "RECOVERY_ACTION=cleanup_complete"

    return 0
}

# ERR-011: Permission fix
permission_fix() {
    local target_path="${1:-${HOME}/.claude}"

    log_warn "Permission issues detected for ${target_path}"

    if [[ ! -e "${target_path}" ]]; then
        log_error "Path does not exist: ${target_path}"
        return 1
    fi

    log_info "Current permissions:"
    ls -la "${target_path}"

    # Check if we own the path
    if [[ "$(stat -c '%U' "${target_path}")" != "${USER}" ]]; then
        log_error "Path is owned by different user"
        escalate_to_user "ERR-011" "Permission fix requires elevated privileges"
        return 1
    fi

    log_info "Suggested fixes:"
    echo "  chmod 700 ${target_path}  # For directories"
    echo "  chmod 600 ${target_path}  # For sensitive files"

    echo "RECOVERY_ACTION=manual_permission_fix"

    return 0
}

# ERR-012: JSON recovery
json_recovery() {
    local json_file="${1:-}"

    log_warn "JSON parse error detected"

    if [[ -n "${json_file}" && -f "${json_file}" ]]; then
        log_info "Validating JSON file: ${json_file}"

        if jq . "${json_file}" > /dev/null 2>&1; then
            log_success "JSON is valid"
            return 0
        fi

        log_error "JSON validation failed"

        # Try to identify the error location
        local error_msg
        error_msg=$(jq . "${json_file}" 2>&1 || true)
        log_info "Parse error: ${error_msg}"

        # Check for common issues
        if head -c 3 "${json_file}" | grep -q $'\xef\xbb\xbf'; then
            log_warn "BOM detected at start of file"
            echo "Fix: tail -c +4 ${json_file} > ${json_file}.fixed"
        fi

        if tail -c 1 "${json_file}" | grep -qv '}'; then
            log_warn "File may be truncated"
        fi
    fi

    log_info "Recovery options:"
    echo "  1. Re-fetch the data"
    echo "  2. Use backup if available"
    echo "  3. Use default values"

    echo "RECOVERY_ACTION=json_reparse"

    return 0
}

# ERR-013: Model failover
model_failover() {
    local current_model="${1:-claude}"
    local task="${2:-}"

    log_warn "Model ${current_model} overloaded. Initiating failover..."

    # Define failover chain
    declare -A failover_chain
    failover_chain["claude"]="gemini"
    failover_chain["gemini"]="codex"
    failover_chain["codex"]="claude"

    local next_model="${failover_chain[${current_model}]:-gemini}"

    log_info "Failover: ${current_model} -> ${next_model}"

    # Check if next model is available
    case "${next_model}" in
        gemini)
            if [[ -f "${HOME}/.gemini/oauth_creds.json" ]]; then
                log_success "Gemini credentials available"
            else
                log_warn "Gemini credentials not found"
                next_model="codex"
            fi
            ;;
        codex)
            if [[ -n "${OPENAI_API_KEY:-}" || -f "${HOME}/.codex/config.toml" ]]; then
                log_success "Codex credentials available"
            else
                log_warn "Codex credentials not found"
                next_model="claude"
            fi
            ;;
    esac

    echo "RECOVERY_ACTION=failover"
    echo "FAILOVER_MODEL=${next_model}"
    echo "ORIGINAL_MODEL=${current_model}"

    return 0
}

# ERR-014: Process cleanup
process_cleanup() {
    log_info "Checking for stale tri-agent processes..."

    local stale_pids=()

    # Find tri-agent related processes
    while IFS= read -r pid; do
        if [[ -n "${pid}" ]] && ! kill -0 "${pid}" 2>/dev/null; then
            stale_pids+=("${pid}")
        fi
    done < <(pgrep -f "tri-agent" 2>/dev/null || true)

    # Check for stale PID files
    for pidfile in "${STATE_DIR}"/*.pid; do
        if [[ -f "${pidfile}" ]]; then
            local pid
            pid=$(cat "${pidfile}")
            if ! kill -0 "${pid}" 2>/dev/null; then
                log_warn "Removing stale PID file: ${pidfile}"
                rm -f "${pidfile}"
            fi
        fi
    done

    if [[ ${#stale_pids[@]} -gt 0 ]]; then
        log_warn "Found ${#stale_pids[@]} stale processes"
        echo "Stale PIDs: ${stale_pids[*]}"
    else
        log_success "No stale processes found"
    fi

    echo "RECOVERY_ACTION=process_cleanup_complete"

    return 0
}

# ERR-015: Test analysis
test_analysis() {
    local test_output="${1:-}"

    log_info "Analyzing test failures..."

    if [[ -n "${test_output}" && -f "${test_output}" ]]; then
        # Count failures
        local fail_count
        fail_count=$(grep -ciE "(FAIL|failed|error)" "${test_output}" || echo "0")
        log_info "Detected approximately ${fail_count} failure indicators"

        # Extract failing test names (common patterns)
        log_info "Potentially failing tests:"
        grep -iE "(FAIL|✗|✕|failed).*test" "${test_output}" | head -10 || true
    fi

    log_info "Analysis steps:"
    echo "  1. Identify specific failing tests"
    echo "  2. Check if failures are flaky (rerun once)"
    echo "  3. Review test output for root cause"
    echo "  4. Fix code or update test expectations"
    echo "  5. Run full test suite to verify fix"

    echo "RECOVERY_ACTION=analyze_tests"

    return 0
}

#
# Main Command Interface
#

show_help() {
    cat << 'EOF'
auto-recovery.sh - Automatic error recovery for tri-agent system

USAGE:
    auto-recovery.sh <command> [arguments]

COMMANDS:
    detect <error_message|log_file>
        Detect error pattern from message or log file content

    recover <pattern_id> [--task-id ID] [--arg VALUE]
        Execute recovery procedure for specified pattern

    analyze <log_file>
        Analyze log file for multiple error patterns

    list
        List all known error patterns

    clear-state [pattern_id]
        Clear retry state for pattern (or all patterns)

    help
        Show this help message

EXAMPLES:
    # Detect pattern from error message
    auto-recovery.sh detect "exit code 124 timeout"

    # Run recovery for timeout
    auto-recovery.sh recover ERR-001 --task-id T-042

    # Analyze a log file
    auto-recovery.sh analyze ~/.claude/logs/session.log

    # List all patterns
    auto-recovery.sh list

    # Clear all retry states
    auto-recovery.sh clear-state

EXIT CODES:
    0 - Success
    1 - Recovery failed / escalation needed
    2 - Unknown error pattern
    3 - Max retries exceeded
EOF
}

list_patterns() {
    echo "Known Error Patterns:"
    echo "===================="
    jq -r '.patterns[] | "\(.id): \(.name) [\(.severity)]"' "${PATTERNS_FILE}"
    echo ""
    echo "Use 'auto-recovery.sh recover <ID>' to execute recovery"
}

main() {
    check_dependencies

    local command="${1:-help}"
    shift || true

    case "${command}" in
        detect)
            local content="${1:-}"
            if [[ -z "${content}" ]]; then
                log_error "Usage: auto-recovery.sh detect <error_message|log_file>"
                exit 1
            fi

            # If it's a file, read content
            if [[ -f "${content}" ]]; then
                content=$(cat "${content}")
            fi

            local patterns
            if patterns=$(detect_pattern "${content}"); then
                log_success "Detected patterns:"
                echo "${patterns}"

                # Show details for first pattern
                local first_pattern
                first_pattern=$(echo "${patterns}" | head -1)
                echo ""
                log_info "Details for ${first_pattern}:"
                get_pattern "${first_pattern}" | jq -r '"  Root cause: \(.root_cause)\n  Recovery: \(.recovery_command)"'
            else
                log_warn "No known error patterns detected"
                exit 2
            fi
            ;;

        recover)
            local pattern_id="${1:-}"
            shift || true

            if [[ -z "${pattern_id}" ]]; then
                log_error "Usage: auto-recovery.sh recover <pattern_id> [--task-id ID]"
                exit 1
            fi

            # Parse additional arguments
            local task_id="default"
            local extra_arg=""
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --task-id) task_id="$2"; shift 2 ;;
                    --arg) extra_arg="$2"; shift 2 ;;
                    *) shift ;;
                esac
            done

            # Get recovery command
            local pattern
            pattern=$(get_pattern "${pattern_id}")
            if [[ -z "${pattern}" || "${pattern}" == "null" ]]; then
                log_error "Unknown pattern: ${pattern_id}"
                exit 2
            fi

            local recovery_cmd
            recovery_cmd=$(echo "${pattern}" | jq -r '.recovery_command')
            local severity
            severity=$(echo "${pattern}" | jq -r '.severity')

            log_info "Executing recovery: ${recovery_cmd} for ${pattern_id}"
            save_failure_snapshot "${pattern_id}" "Recovery initiated" "${task_id}"

            # Execute recovery function
            case "${recovery_cmd}" in
                split_and_retry)       split_and_retry "${task_id}" ;;
                reauth_prompt)         reauth_prompt "${extra_arg:-all}" ;;
                sqlite_retry_backoff)  sqlite_retry_backoff "${extra_arg}" "${task_id}" ;;
                trigger_summarization) trigger_summarization "${extra_arg:-0}" ;;
                exponential_backoff)   exponential_backoff "${task_id}" ;;
                escalate_to_user)      escalate_to_user "${pattern_id}" "User escalation requested" ;;
                network_retry)         network_retry "${task_id}" ;;
                memory_recovery)       memory_recovery ;;
                git_conflict_resolve)  git_conflict_resolve ;;
                disk_cleanup)          disk_cleanup ;;
                permission_fix)        permission_fix "${extra_arg}" ;;
                json_recovery)         json_recovery "${extra_arg}" ;;
                model_failover)        model_failover "${extra_arg:-claude}" ;;
                process_cleanup)       process_cleanup ;;
                test_analysis)         test_analysis "${extra_arg}" ;;
                *)
                    log_error "Unknown recovery command: ${recovery_cmd}"
                    exit 1
                    ;;
            esac
            ;;

        analyze)
            local log_file="${1:-}"
            if [[ -z "${log_file}" || ! -f "${log_file}" ]]; then
                log_error "Usage: auto-recovery.sh analyze <log_file>"
                exit 1
            fi

            log_info "Analyzing: ${log_file}"

            local content
            content=$(cat "${log_file}")

            local found_any=false
            while IFS= read -r pattern_id; do
                if [[ -n "${pattern_id}" ]]; then
                    found_any=true
                    local pattern
                    pattern=$(get_pattern "${pattern_id}")
                    local name severity
                    name=$(echo "${pattern}" | jq -r '.name')
                    severity=$(echo "${pattern}" | jq -r '.severity')

                    echo ""
                    echo "=== ${pattern_id}: ${name} [${severity}] ==="
                    echo "${pattern}" | jq -r '.root_cause'
                    echo ""
                    echo "Recovery: $(echo "${pattern}" | jq -r '.recovery_command')"
                fi
            done < <(detect_pattern "${content}" 2>/dev/null || true)

            if [[ "${found_any}" == "false" ]]; then
                log_info "No known error patterns found in log file"
            fi
            ;;

        list)
            list_patterns
            ;;

        clear-state)
            local pattern_id="${1:-}"
            if [[ -n "${pattern_id}" ]]; then
                rm -f "${STATE_DIR}/retry_${pattern_id}_"*.state
                log_success "Cleared retry state for ${pattern_id}"
            else
                rm -f "${STATE_DIR}/retry_"*.state
                log_success "Cleared all retry states"
            fi
            ;;

        help|--help|-h)
            show_help
            ;;

        *)
            log_error "Unknown command: ${command}"
            show_help
            exit 1
            ;;
    esac
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
