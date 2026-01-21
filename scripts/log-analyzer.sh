#!/bin/bash
# ~/.claude/scripts/log-analyzer.sh
# Tri-Agent Daemon Log Analyzer
#
# Analyzes tri-agent daemon logs to:
# 1. Identify error patterns
# 2. Calculate success/failure rates
# 3. Detect anomalies (sudden spikes in failures)
# 4. Suggest fixes based on common patterns
# 5. Generate summary reports
#
# Author: Ahmed Adel Bakr Alderai

set -euo pipefail

#=============================================================================
# CONFIGURATION
#=============================================================================

# Default paths
CLAUDE_DIR="${HOME}/.claude"
LOG_DIR="${CLAUDE_DIR}/logs"
AUDIT_DIR="${LOG_DIR}/audit"
STATE_DIR="${CLAUDE_DIR}/state"
REPORT_DIR="${CLAUDE_DIR}/reports"

# Analysis settings
DEFAULT_HOURS=24
ANOMALY_THRESHOLD=2.0  # Standard deviations for anomaly detection
FAILURE_RATE_WARN=10   # Warn if failure rate exceeds this %
FAILURE_RATE_CRIT=20   # Critical if failure rate exceeds this %

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Report timestamp
REPORT_TIMESTAMP=$(date -Iseconds)

#=============================================================================
# UTILITY FUNCTIONS
#=============================================================================

print_header() {
    echo -e "\n${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}  $1${NC}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"
}

print_section() {
    echo -e "\n${BOLD}${CYAN}─── $1 ───${NC}\n"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Calculate time range
get_time_cutoff() {
    local hours=$1
    date -d "${hours} hours ago" -Iseconds 2>/dev/null || \
    date -v-${hours}H -Iseconds 2>/dev/null || \
    echo ""
}

# Check if timestamp is within range
is_within_range() {
    local timestamp="$1"
    local cutoff="$2"
    [[ "$timestamp" > "$cutoff" ]]
}

# Ensure directories exist
ensure_directories() {
    mkdir -p "$REPORT_DIR"
    mkdir -p "${LOG_DIR}/analysis"
}

# Safe division using awk (avoids bc dependency)
calc_percent() {
    local numerator=$1
    local denominator=$2
    local scale=${3:-1}
    if [[ $denominator -eq 0 ]]; then
        echo "0"
    else
        awk "BEGIN {printf \"%.${scale}f\", ($numerator * 100) / $denominator}"
    fi
}

# Safe count - ensures numeric value
safe_count() {
    local result
    result="${1:-0}"
    # Remove any whitespace/newlines and ensure numeric
    result=$(echo "$result" | tr -d '[:space:]' | head -c 20)
    if [[ "$result" =~ ^[0-9]+$ ]]; then
        echo "$result"
    else
        echo "0"
    fi
}

# Count pattern in file safely
count_pattern() {
    local pattern="$1"
    local file="$2"
    local count
    count=$(grep -c "$pattern" "$file" 2>/dev/null || echo "0")
    safe_count "$count"
}

# Count pattern case-insensitive in file safely
count_pattern_i() {
    local pattern="$1"
    local file="$2"
    local count
    count=$(grep -ci "$pattern" "$file" 2>/dev/null || echo "0")
    safe_count "$count"
}

#=============================================================================
# ERROR PATTERN DETECTION
#=============================================================================

analyze_error_patterns() {
    local hours=${1:-$DEFAULT_HOURS}
    local cutoff
    cutoff=$(get_time_cutoff "$hours")

    print_section "Error Pattern Analysis (Last ${hours}h)"

    local patterns_found=0
    declare -A error_counts
    declare -A error_examples

    # Pattern 1: Empty task descriptions
    if [[ -f "${LOG_DIR}/tasks.log" ]]; then
        local empty_desc_count
        empty_desc_count=$(count_pattern "desc=''" "${LOG_DIR}/tasks.log")
        if [[ $empty_desc_count -gt 0 ]]; then
            error_counts["EMPTY_TASK_DESC"]=$empty_desc_count
            error_examples["EMPTY_TASK_DESC"]="Tasks with empty descriptions found"
            ((patterns_found++)) || true
        fi
    fi

    # Pattern 2: Verification failures
    if [[ -f "${LOG_DIR}/tasks.log" ]]; then
        local verify_fail_count
        verify_fail_count=$(count_pattern "TASK_VERIFICATION present=false" "${LOG_DIR}/tasks.log")
        if [[ $verify_fail_count -gt 0 ]]; then
            error_counts["VERIFICATION_MISSING"]=$verify_fail_count
            error_examples["VERIFICATION_MISSING"]="Tasks executed without verification"
            ((patterns_found++)) || true
        fi
    fi

    # Pattern 3: Unknown agent types
    if [[ -f "${LOG_DIR}/subagents.log" ]]; then
        local unknown_agent_count
        unknown_agent_count=$(count_pattern "type=unknown" "${LOG_DIR}/subagents.log")
        if [[ $unknown_agent_count -gt 0 ]]; then
            error_counts["UNKNOWN_AGENT_TYPE"]=$unknown_agent_count
            error_examples["UNKNOWN_AGENT_TYPE"]="Subagents with unknown type classification"
            ((patterns_found++)) || true
        fi
    fi

    # Pattern 4: Rate limit errors (from bash log)
    if [[ -f "${LOG_DIR}/bash.log" ]]; then
        local rate_limit_count
        rate_limit_count=$(count_pattern_i "429\|rate.limit\|too.many.requests" "${LOG_DIR}/bash.log")
        if [[ $rate_limit_count -gt 0 ]]; then
            error_counts["RATE_LIMIT"]=$rate_limit_count
            error_examples["RATE_LIMIT"]="API rate limit errors detected"
            ((patterns_found++)) || true
        fi
    fi

    # Pattern 5: Hook errors
    if [[ -f "${LOG_DIR}/bash.log" ]]; then
        local hook_error_count
        hook_error_count=$(count_pattern_i "hook.*error\|PreToolUse.*error" "${LOG_DIR}/bash.log")
        if [[ $hook_error_count -gt 0 ]]; then
            error_counts["HOOK_ERROR"]=$hook_error_count
            error_examples["HOOK_ERROR"]="Hook execution errors"
            ((patterns_found++)) || true
        fi
    fi

    # Pattern 6: Timeout errors
    if [[ -f "${LOG_DIR}/bash.log" ]]; then
        local timeout_count
        timeout_count=$(count_pattern_i "timeout\|timed.out\|ETIMEDOUT" "${LOG_DIR}/bash.log")
        if [[ $timeout_count -gt 0 ]]; then
            error_counts["TIMEOUT"]=$timeout_count
            error_examples["TIMEOUT"]="Command/API timeout errors"
            ((patterns_found++)) || true
        fi
    fi

    # Pattern 7: Connection errors
    if [[ -f "${LOG_DIR}/bash.log" ]]; then
        local connection_count
        connection_count=$(count_pattern_i "ECONNREFUSED\|ECONNRESET\|connection.refused\|network.error" "${LOG_DIR}/bash.log")
        if [[ $connection_count -gt 0 ]]; then
            error_counts["CONNECTION_ERROR"]=$connection_count
            error_examples["CONNECTION_ERROR"]="Network/connection errors"
            ((patterns_found++)) || true
        fi
    fi

    # Pattern 8: Permission/Auth errors
    if [[ -f "${LOG_DIR}/bash.log" ]]; then
        local auth_count
        auth_count=$(count_pattern_i "401\|403\|permission.denied\|unauthorized\|authentication.failed" "${LOG_DIR}/bash.log")
        if [[ $auth_count -gt 0 ]]; then
            error_counts["AUTH_ERROR"]=$auth_count
            error_examples["AUTH_ERROR"]="Authentication/permission errors"
            ((patterns_found++)) || true
        fi
    fi

    # Pattern 9: Empty type fields
    if [[ -f "${LOG_DIR}/tasks.log" ]]; then
        local empty_type_count
        empty_type_count=$(count_pattern "type= desc=" "${LOG_DIR}/tasks.log")
        if [[ $empty_type_count -gt 0 ]]; then
            error_counts["EMPTY_TASK_TYPE"]=$empty_type_count
            error_examples["EMPTY_TASK_TYPE"]="Tasks with empty type field"
            ((patterns_found++)) || true
        fi
    fi

    # Pattern 10: Daemon crashes (from security log)
    if [[ -f "${LOG_DIR}/security.log" ]]; then
        local crash_count
        crash_count=$(count_pattern_i "crash\|segfault\|killed\|terminated" "${LOG_DIR}/security.log")
        if [[ $crash_count -gt 0 ]]; then
            error_counts["DAEMON_CRASH"]=$crash_count
            error_examples["DAEMON_CRASH"]="Daemon crash/termination events"
            ((patterns_found++)) || true
        fi
    fi

    # Display results
    if [[ $patterns_found -eq 0 ]]; then
        print_success "No significant error patterns detected"
    else
        echo -e "${BOLD}Found ${patterns_found} error patterns:${NC}\n"
        printf "%-25s %10s %s\n" "Pattern" "Count" "Description"
        printf "%-25s %10s %s\n" "-------" "-----" "-----------"

        for pattern in "${!error_counts[@]}"; do
            local count=${error_counts[$pattern]}
            local desc=${error_examples[$pattern]}

            if [[ $count -gt 100 ]]; then
                printf "${RED}%-25s %10d %s${NC}\n" "$pattern" "$count" "$desc"
            elif [[ $count -gt 10 ]]; then
                printf "${YELLOW}%-25s %10d %s${NC}\n" "$pattern" "$count" "$desc"
            else
                printf "%-25s %10d %s\n" "$pattern" "$count" "$desc"
            fi
        done
    fi

    # Store for report
    echo "$patterns_found"
}

#=============================================================================
# SUCCESS/FAILURE RATE CALCULATION
#=============================================================================

calculate_rates() {
    local hours=${1:-$DEFAULT_HOURS}

    print_section "Success/Failure Rates (Last ${hours}h)"

    # Task verification rates
    if [[ -f "${LOG_DIR}/tasks.log" ]]; then
        local total_tasks
        local verified_tasks
        local unverified_tasks

        total_tasks=$(count_pattern "TASK_VERIFICATION" "${LOG_DIR}/tasks.log")
        verified_tasks=$(count_pattern "TASK_VERIFICATION present=true" "${LOG_DIR}/tasks.log")
        unverified_tasks=$(count_pattern "TASK_VERIFICATION present=false" "${LOG_DIR}/tasks.log")

        if [[ $total_tasks -gt 0 ]]; then
            local verify_rate
            verify_rate=$(calc_percent "$verified_tasks" "$total_tasks" 1)

            echo -e "${BOLD}Task Verification:${NC}"
            echo "  Total tasks:      $total_tasks"
            echo "  Verified:         $verified_tasks"
            echo "  Unverified:       $unverified_tasks"

            if awk "BEGIN {exit !($verify_rate >= 90)}"; then
                print_success "Verification rate: ${verify_rate}%"
            elif awk "BEGIN {exit !($verify_rate >= 70)}"; then
                print_warning "Verification rate: ${verify_rate}%"
            else
                print_error "Verification rate: ${verify_rate}%"
            fi
        else
            print_info "No task verification data available"
        fi
    fi

    echo ""

    # Session rates
    if [[ -f "${LOG_DIR}/sessions.log" ]]; then
        local session_starts
        local session_ends

        session_starts=$(count_pattern "SESSION_START" "${LOG_DIR}/sessions.log")
        session_ends=$(count_pattern "SESSION_END" "${LOG_DIR}/sessions.log")

        echo -e "${BOLD}Session Statistics:${NC}"
        echo "  Sessions started: $session_starts"
        echo "  Sessions ended:   $session_ends"
        echo "  Incomplete:       $((session_starts - session_ends))"

        if [[ $session_starts -gt 0 ]]; then
            local completion_rate
            completion_rate=$(calc_percent "$session_ends" "$session_starts" 1)
            echo "  Completion rate:  ${completion_rate}%"
        fi
    fi

    echo ""

    # Subagent rates
    if [[ -f "${LOG_DIR}/subagents.log" ]]; then
        local total_agents
        local known_agents
        local unknown_agents

        total_agents=$(count_pattern "SUBAGENT_STOP" "${LOG_DIR}/subagents.log")
        unknown_agents=$(count_pattern "type=unknown" "${LOG_DIR}/subagents.log")
        known_agents=$((total_agents - unknown_agents))
        if [[ $known_agents -lt 0 ]]; then known_agents=0; fi

        echo -e "${BOLD}Subagent Statistics:${NC}"
        echo "  Total agents:     $total_agents"
        echo "  Known type:       $known_agents"
        echo "  Unknown type:     $unknown_agents"

        if [[ $total_agents -gt 0 ]]; then
            local known_rate
            known_rate=$(calc_percent "$known_agents" "$total_agents" 1)
            echo "  Classification:   ${known_rate}%"
        fi
    fi

    echo ""

    # Checkpoint rates
    if [[ -f "${LOG_DIR}/checkpoints.log" ]]; then
        local manual_checkpoints
        local auto_checkpoints

        manual_checkpoints=$(count_pattern "MANUAL_CHECKPOINT" "${LOG_DIR}/checkpoints.log")
        auto_checkpoints=$(count_pattern "AUTO_CHECKPOINT" "${LOG_DIR}/checkpoints.log")

        echo -e "${BOLD}Checkpoint Statistics:${NC}"
        echo "  Manual:           $manual_checkpoints"
        echo "  Automatic:        $auto_checkpoints"
        echo "  Total:            $((manual_checkpoints + auto_checkpoints))"
    fi

    echo ""

    # Audit log activity
    if [[ -d "$AUDIT_DIR" ]]; then
        local today_audit
        local today_file
        today_file="${AUDIT_DIR}/audit-$(date +%Y%m%d).jsonl"

        if [[ -f "$today_file" ]]; then
            today_audit=$(wc -l < "$today_file")
            echo -e "${BOLD}Today's Activity:${NC}"
            echo "  Audit entries:    $today_audit"
        fi
    fi
}

#=============================================================================
# ANOMALY DETECTION
#=============================================================================

detect_anomalies() {
    local hours=${1:-$DEFAULT_HOURS}

    print_section "Anomaly Detection (Last ${hours}h)"

    local anomalies_found=0
    declare -a anomaly_list

    # Analyze hourly failure rates for spikes
    if [[ -f "${LOG_DIR}/tasks.log" ]]; then
        print_info "Analyzing hourly task patterns..."

        # Get hourly counts of unverified tasks
        declare -A hourly_failures
        local total_hours=0
        local total_failures=0

        while IFS= read -r line; do
            # Extract hour from timestamp
            local hour
            hour=$(echo "$line" | grep -oP '\d{4}-\d{2}-\d{2}T\d{2}' | head -1 || echo "")
            if [[ -n "$hour" ]]; then
                hourly_failures["$hour"]=$((${hourly_failures["$hour"]:-0} + 1))
                ((total_failures++)) || true
            fi
        done < <(grep "TASK_VERIFICATION present=false" "${LOG_DIR}/tasks.log" 2>/dev/null || true)

        # Calculate mean and std dev
        if [[ ${#hourly_failures[@]} -gt 2 ]]; then
            local sum=0
            for count in "${hourly_failures[@]}"; do
                ((sum += count)) || true
            done
            local mean=$((sum / ${#hourly_failures[@]}))

            # Calculate std dev
            local sq_diff_sum=0
            for count in "${hourly_failures[@]}"; do
                local diff=$((count - mean))
                ((sq_diff_sum += diff * diff)) || true
            done
            local variance=$((sq_diff_sum / ${#hourly_failures[@]}))
            local std_dev
            std_dev=$(awk "BEGIN {printf \"%.2f\", sqrt($variance)}")

            # Find anomalies (> 2 std devs from mean)
            local threshold
            threshold=$(awk "BEGIN {printf \"%.0f\", $mean + ($ANOMALY_THRESHOLD * $std_dev)}")

            for hour in "${!hourly_failures[@]}"; do
                if awk "BEGIN {exit !(${hourly_failures[$hour]} > $threshold)}"; then
                    anomaly_list+=("SPIKE: ${hourly_failures[$hour]} failures at $hour (threshold: ${threshold})")
                    ((anomalies_found++)) || true
                fi
            done

            echo "  Mean failures/hour: $mean"
            echo "  Std deviation:      $std_dev"
            echo "  Anomaly threshold:  ${threshold}"
        fi
    fi

    # Check for sudden session terminations
    if [[ -f "${LOG_DIR}/sessions.log" ]]; then
        print_info "Checking session patterns..."

        # Count sessions without proper end
        local orphan_sessions
        orphan_sessions=$(grep "SESSION_START" "${LOG_DIR}/sessions.log" | \
            while read -r line; do
                local sid
                sid=$(echo "$line" | grep -oP 'session_id=\K[a-f0-9-]+')
                if [[ -n "$sid" ]] && ! grep -q "SESSION_END session_id=$sid" "${LOG_DIR}/sessions.log"; then
                    echo "$sid"
                fi
            done | sort -u | wc -l)

        if [[ $orphan_sessions -gt 5 ]]; then
            anomaly_list+=("ORPHAN_SESSIONS: $orphan_sessions sessions without proper termination")
            ((anomalies_found++)) || true
        fi
    fi

    # Check for rapid subagent terminations
    if [[ -f "${LOG_DIR}/subagents.log" ]]; then
        print_info "Checking subagent patterns..."

        # Look for multiple terminations within same second
        local rapid_stops
        rapid_stops=$(sort "${LOG_DIR}/subagents.log" 2>/dev/null | \
            uniq -c | awk '$1 > 5 {print $0}' | wc -l || echo "0")

        if [[ $rapid_stops -gt 0 ]]; then
            anomaly_list+=("RAPID_TERMINATION: $rapid_stops instances of mass subagent termination")
            ((anomalies_found++)) || true
        fi
    fi

    # Check for disk space issues in logs
    if [[ -d "$LOG_DIR" ]]; then
        local large_logs
        large_logs=$(find "$LOG_DIR" -name "*.log" -size +50M 2>/dev/null | wc -l || echo "0")

        if [[ $large_logs -gt 0 ]]; then
            anomaly_list+=("LARGE_LOGS: $large_logs log files exceed 50MB")
            ((anomalies_found++)) || true
        fi
    fi

    # Check audit log gaps
    if [[ -d "$AUDIT_DIR" ]]; then
        print_info "Checking audit log continuity..."

        local missing_days=0
        for i in {1..7}; do
            local check_date
            check_date=$(date -d "$i days ago" +%Y%m%d 2>/dev/null || date -v-${i}d +%Y%m%d 2>/dev/null || echo "")
            if [[ -n "$check_date" ]] && [[ ! -f "${AUDIT_DIR}/audit-${check_date}.jsonl" ]]; then
                ((missing_days++)) || true
            fi
        done

        if [[ $missing_days -gt 2 ]]; then
            anomaly_list+=("AUDIT_GAPS: $missing_days missing audit logs in last 7 days")
            ((anomalies_found++)) || true
        fi
    fi

    # Display results
    echo ""
    if [[ $anomalies_found -eq 0 ]]; then
        print_success "No anomalies detected"
    else
        print_warning "Found ${anomalies_found} anomalies:"
        for anomaly in "${anomaly_list[@]}"; do
            echo -e "  ${YELLOW}*${NC} $anomaly"
        done
    fi

    echo "$anomalies_found"
}

#=============================================================================
# FIX SUGGESTIONS
#=============================================================================

suggest_fixes() {
    local hours=${1:-$DEFAULT_HOURS}

    print_section "Recommended Fixes"

    local suggestions=0

    # Check for empty task descriptions
    local empty_desc
    empty_desc=$(count_pattern "desc=''" "${LOG_DIR}/tasks.log")
    if [[ $empty_desc -gt 0 ]]; then
        echo -e "${BOLD}1. Empty Task Descriptions (${empty_desc} occurrences)${NC}"
        echo "   Problem: Tasks are being created without proper descriptions"
        echo "   Fix: Ensure all task creation includes meaningful descriptions"
        echo "   Command: Check task creation in delegates - ensure desc parameter is set"
        echo ""
        ((suggestions++)) || true
    fi

    # Check for unverified tasks
    local unverified
    unverified=$(count_pattern "TASK_VERIFICATION present=false" "${LOG_DIR}/tasks.log")
    if [[ $unverified -gt 10 ]]; then
        echo -e "${BOLD}2. Unverified Tasks (${unverified} occurrences)${NC}"
        echo "   Problem: Tasks executing without tri-agent verification"
        echo "   Fix: Enable mandatory verification in CLAUDE.md protocol"
        echo "   Command: Ensure all tasks have verifier AI assigned"
        echo ""
        ((suggestions++)) || true
    fi

    # Check for unknown agent types
    local unknown_types
    unknown_types=$(count_pattern "type=unknown" "${LOG_DIR}/subagents.log")
    if [[ $unknown_types -gt 0 ]]; then
        echo -e "${BOLD}3. Unknown Agent Types (${unknown_types} occurrences)${NC}"
        echo "   Problem: Subagents not properly classified"
        echo "   Fix: Update agent registration to include type metadata"
        echo "   Action: Review agent initialization code"
        echo ""
        ((suggestions++)) || true
    fi

    # Check for rate limits
    local rate_limits
    rate_limits=$(count_pattern_i "429\|rate.limit" "${LOG_DIR}/bash.log")
    if [[ $rate_limits -gt 0 ]]; then
        echo -e "${BOLD}4. Rate Limit Errors (${rate_limits} occurrences)${NC}"
        echo "   Problem: API rate limits being hit"
        echo "   Fix: Implement exponential backoff and request throttling"
        echo "   Command: Add delays between API calls or use queue system"
        echo "   Config: Set RETRY_BACKOFF_BASE in ~/.claude/degradation.conf"
        echo ""
        ((suggestions++)) || true
    fi

    # Check for timeout errors
    local timeouts
    timeouts=$(count_pattern_i "timeout" "${LOG_DIR}/bash.log")
    if [[ $timeouts -gt 5 ]]; then
        echo -e "${BOLD}5. Timeout Errors (${timeouts} occurrences)${NC}"
        echo "   Problem: Commands or API calls timing out"
        echo "   Fix: Increase timeout thresholds or optimize operations"
        echo "   Config: Adjust timeouts in configuration files"
        echo ""
        ((suggestions++)) || true
    fi

    # Check for large log files
    local large_logs
    large_logs=$(find "$LOG_DIR" -name "*.log" -size +50M 2>/dev/null | wc -l || echo "0")
    large_logs=$(safe_count "$large_logs")
    if [[ $large_logs -gt 0 ]]; then
        echo -e "${BOLD}6. Large Log Files (${large_logs} files > 50MB)${NC}"
        echo "   Problem: Log files growing too large"
        echo "   Fix: Run log rotation"
        echo "   Command: ~/.claude/scripts/cleanup.sh"
        echo ""
        ((suggestions++)) || true
    fi

    # Check for hook errors
    local hook_errors
    hook_errors=$(count_pattern_i "hook.*error" "${LOG_DIR}/bash.log")
    if [[ $hook_errors -gt 0 ]]; then
        echo -e "${BOLD}7. Hook Errors (${hook_errors} occurrences)${NC}"
        echo "   Problem: Pre/post tool use hooks failing"
        echo "   Fix: Debug and fix hook scripts"
        echo "   Command: ~/.claude/hooks/health-check.sh"
        echo ""
        ((suggestions++)) || true
    fi

    # Check for authentication errors
    local auth_errors
    auth_errors=$(count_pattern_i "401\|403\|unauthorized" "${LOG_DIR}/bash.log")
    if [[ $auth_errors -gt 0 ]]; then
        echo -e "${BOLD}8. Authentication Errors (${auth_errors} occurrences)${NC}"
        echo "   Problem: API authentication failures"
        echo "   Fix: Refresh API tokens/credentials"
        echo "   Check: ~/.claude/.credentials.json, ~/.codex/config.toml, ~/.gemini/oauth_creds.json"
        echo ""
        ((suggestions++)) || true
    fi

    # Empty task types
    local empty_types
    empty_types=$(count_pattern "type= desc=" "${LOG_DIR}/tasks.log")
    if [[ $empty_types -gt 0 ]]; then
        echo -e "${BOLD}9. Empty Task Types (${empty_types} occurrences)${NC}"
        echo "   Problem: Tasks created without type classification"
        echo "   Fix: Ensure task router assigns proper types"
        echo "   Review: Task creation and routing logic"
        echo ""
        ((suggestions++)) || true
    fi

    if [[ $suggestions -eq 0 ]]; then
        print_success "No critical issues requiring fixes"
    else
        echo -e "\n${BOLD}Total recommendations: ${suggestions}${NC}"
    fi
}

#=============================================================================
# SUMMARY REPORT GENERATION
#=============================================================================

generate_report() {
    local hours=${1:-$DEFAULT_HOURS}
    local output_format=${2:-"text"}
    local report_file

    ensure_directories

    if [[ "$output_format" == "json" ]]; then
        report_file="${REPORT_DIR}/log-analysis-$(date +%Y%m%d_%H%M%S).json"
        generate_json_report "$hours" > "$report_file"
    elif [[ "$output_format" == "markdown" ]]; then
        report_file="${REPORT_DIR}/log-analysis-$(date +%Y%m%d_%H%M%S).md"
        generate_markdown_report "$hours" > "$report_file"
    else
        report_file="${REPORT_DIR}/log-analysis-$(date +%Y%m%d_%H%M%S).txt"
        generate_text_report "$hours" > "$report_file"
    fi

    echo "$report_file"
}

generate_text_report() {
    local hours=${1:-$DEFAULT_HOURS}

    cat << EOF
================================================================================
TRI-AGENT LOG ANALYSIS REPORT
Generated: ${REPORT_TIMESTAMP}
Analysis Period: Last ${hours} hours
================================================================================

EOF

    echo "1. ERROR PATTERNS"
    echo "================="
    analyze_error_patterns "$hours" 2>&1 | sed 's/\x1b\[[0-9;]*m//g'

    echo ""
    echo "2. SUCCESS/FAILURE RATES"
    echo "========================"
    calculate_rates "$hours" 2>&1 | sed 's/\x1b\[[0-9;]*m//g'

    echo ""
    echo "3. ANOMALIES DETECTED"
    echo "====================="
    detect_anomalies "$hours" 2>&1 | sed 's/\x1b\[[0-9;]*m//g'

    echo ""
    echo "4. RECOMMENDED FIXES"
    echo "===================="
    suggest_fixes "$hours" 2>&1 | sed 's/\x1b\[[0-9;]*m//g'

    cat << EOF

================================================================================
END OF REPORT
================================================================================
EOF
}

generate_json_report() {
    local hours=${1:-$DEFAULT_HOURS}

    # Collect metrics
    local total_tasks=0
    local verified_tasks=0
    local empty_desc=0
    local unknown_agents=0
    local rate_limits=0
    local timeouts=0

    if [[ -f "${LOG_DIR}/tasks.log" ]]; then
        total_tasks=$(count_pattern "TASK_VERIFICATION" "${LOG_DIR}/tasks.log")
        verified_tasks=$(count_pattern "TASK_VERIFICATION present=true" "${LOG_DIR}/tasks.log")
        empty_desc=$(count_pattern "desc=''" "${LOG_DIR}/tasks.log")
    fi

    if [[ -f "${LOG_DIR}/subagents.log" ]]; then
        unknown_agents=$(count_pattern "type=unknown" "${LOG_DIR}/subagents.log")
    fi

    if [[ -f "${LOG_DIR}/bash.log" ]]; then
        rate_limits=$(count_pattern_i "429\|rate.limit" "${LOG_DIR}/bash.log")
        timeouts=$(count_pattern_i "timeout" "${LOG_DIR}/bash.log")
    fi

    local verify_rate=0
    if [[ $total_tasks -gt 0 ]]; then
        verify_rate=$(calc_percent "$verified_tasks" "$total_tasks" 2)
    fi

    cat << EOF
{
  "report": {
    "generated": "${REPORT_TIMESTAMP}",
    "period_hours": ${hours},
    "log_directory": "${LOG_DIR}"
  },
  "metrics": {
    "tasks": {
      "total": ${total_tasks},
      "verified": ${verified_tasks},
      "unverified": $((total_tasks - verified_tasks)),
      "verification_rate": ${verify_rate}
    },
    "errors": {
      "empty_descriptions": ${empty_desc},
      "unknown_agent_types": ${unknown_agents},
      "rate_limits": ${rate_limits},
      "timeouts": ${timeouts}
    }
  },
  "health": {
    "status": "$([ $verified_tasks -gt $((total_tasks / 2)) ] && echo "healthy" || echo "degraded")",
    "verification_passing": $(awk "BEGIN {print ($verify_rate >= 90) ? \"true\" : \"false\"}"),
    "critical_errors": $([ $rate_limits -gt 100 ] || [ $timeouts -gt 50 ] && echo "true" || echo "false")
  }
}
EOF
}

generate_markdown_report() {
    local hours=${1:-$DEFAULT_HOURS}

    cat << EOF
# Tri-Agent Log Analysis Report

**Generated:** ${REPORT_TIMESTAMP}
**Analysis Period:** Last ${hours} hours

---

## Executive Summary

EOF

    # Quick health check
    local health="Healthy"
    local verify_count
    verify_count=$(count_pattern "TASK_VERIFICATION present=true" "${LOG_DIR}/tasks.log")
    local total_verify
    total_verify=$(count_pattern "TASK_VERIFICATION" "${LOG_DIR}/tasks.log")

    if [[ $total_verify -gt 0 ]]; then
        local rate
        rate=$(calc_percent "$verify_count" "$total_verify" 0)
        if [[ $rate -lt 70 ]]; then
            health="Degraded"
        elif [[ $rate -lt 90 ]]; then
            health="Warning"
        fi
    fi

    echo "**System Health:** $health"
    echo ""

    echo "## Error Patterns"
    echo ""
    echo "| Pattern | Count | Severity |"
    echo "|---------|-------|----------|"

    local empty_desc
    empty_desc=$(count_pattern "desc=''" "${LOG_DIR}/tasks.log")
    echo "| Empty Task Description | $empty_desc | $([ "$empty_desc" -gt 100 ] && echo "High" || echo "Low") |"

    local unverified
    unverified=$(count_pattern "TASK_VERIFICATION present=false" "${LOG_DIR}/tasks.log")
    echo "| Unverified Tasks | $unverified | $([ "$unverified" -gt 50 ] && echo "High" || echo "Medium") |"

    local unknown_types
    unknown_types=$(count_pattern "type=unknown" "${LOG_DIR}/subagents.log")
    echo "| Unknown Agent Types | $unknown_types | Low |"

    echo ""
    echo "## Recommendations"
    echo ""

    if [[ $empty_desc -gt 0 ]]; then
        echo "- [ ] Fix empty task descriptions in task creation logic"
    fi
    if [[ $unverified -gt 10 ]]; then
        echo "- [ ] Enable mandatory tri-agent verification"
    fi
    if [[ $unknown_types -gt 0 ]]; then
        echo "- [ ] Update agent type classification"
    fi

    echo ""
    echo "---"
    echo "*Report generated by log-analyzer.sh*"
}

#=============================================================================
# REAL-TIME MONITORING
#=============================================================================

monitor_realtime() {
    local interval=${1:-30}

    print_header "Real-Time Log Monitoring (Interval: ${interval}s)"
    echo "Press Ctrl+C to stop"
    echo ""

    while true; do
        clear
        echo -e "${BOLD}Tri-Agent Real-Time Monitor${NC} - $(date)"
        echo "───────────────────────────────────────────────────────"

        # Current session count
        local active_sessions
        active_sessions=$(grep -c "SESSION_START" "${LOG_DIR}/sessions.log" 2>/dev/null || echo "0")
        active_sessions=$((active_sessions > 10 ? 10 : active_sessions))
        echo -e "Active sessions (last 10): ${CYAN}${active_sessions}${NC}"

        # Recent tasks
        local recent_tasks
        recent_tasks=$(tail -5 "${LOG_DIR}/tasks.log" 2>/dev/null | grep -c "PRE_TASK" 2>/dev/null || echo "0")
        echo -e "Recent tasks (last 5 logs): ${CYAN}${recent_tasks}${NC}"

        # Error count in last minute
        local recent_errors=0
        if [[ -f "${LOG_DIR}/bash.log" ]]; then
            recent_errors=$(tail -100 "${LOG_DIR}/bash.log" 2>/dev/null | grep -ci "error\|fail\|timeout" 2>/dev/null || echo "0")
        fi
        if [[ $recent_errors -gt 10 ]]; then
            echo -e "Recent errors: ${RED}${recent_errors}${NC}"
        else
            echo -e "Recent errors: ${GREEN}${recent_errors}${NC}"
        fi

        # Disk usage
        local disk_usage
        disk_usage=$(du -sh "${CLAUDE_DIR}" 2>/dev/null | cut -f1)
        echo -e "Disk usage: ${CYAN}${disk_usage}${NC}"

        # Last checkpoint
        local last_checkpoint
        last_checkpoint=$(tail -1 "${LOG_DIR}/checkpoints.log" 2>/dev/null | grep -oP '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}' | head -1)
        echo -e "Last checkpoint: ${CYAN}${last_checkpoint:-N/A}${NC}"

        echo ""
        echo "───────────────────────────────────────────────────────"
        echo "Recent log entries:"
        tail -5 "${LOG_DIR}/tasks.log" 2>/dev/null | sed 's/^/  /'

        sleep "$interval"
    done
}

#=============================================================================
# HELP AND USAGE
#=============================================================================

show_help() {
    cat << EOF
${BOLD}Tri-Agent Log Analyzer${NC}
Analyzes daemon logs for errors, rates, anomalies, and generates reports.

${BOLD}USAGE:${NC}
    $(basename "$0") [COMMAND] [OPTIONS]

${BOLD}COMMANDS:${NC}
    analyze         Full analysis (default)
    errors          Analyze error patterns only
    rates           Calculate success/failure rates
    anomalies       Detect anomalies only
    fixes           Show fix suggestions
    report          Generate summary report
    monitor         Real-time monitoring
    help            Show this help message

${BOLD}OPTIONS:${NC}
    -h, --hours     Analysis period in hours (default: 24)
    -f, --format    Report format: text, json, markdown (default: text)
    -o, --output    Output file path for report
    -v, --verbose   Verbose output
    --no-color      Disable colored output

${BOLD}EXAMPLES:${NC}
    # Full analysis for last 24 hours
    $(basename "$0") analyze

    # Error analysis for last 48 hours
    $(basename "$0") errors --hours 48

    # Generate JSON report
    $(basename "$0") report --format json

    # Real-time monitoring (30s interval)
    $(basename "$0") monitor

    # Generate markdown report to specific file
    $(basename "$0") report --format markdown --output /tmp/report.md

${BOLD}LOG FILES ANALYZED:${NC}
    ${LOG_DIR}/tasks.log       - Task execution logs
    ${LOG_DIR}/subagents.log   - Subagent lifecycle logs
    ${LOG_DIR}/sessions.log    - Session start/end logs
    ${LOG_DIR}/checkpoints.log - Checkpoint logs
    ${LOG_DIR}/bash.log        - Command execution logs
    ${AUDIT_DIR}/*.jsonl       - Audit trail logs

${BOLD}REPORT OUTPUT:${NC}
    Reports are saved to: ${REPORT_DIR}/

Author: Ahmed Adel Bakr Alderai
EOF
}

#=============================================================================
# MAIN ENTRY POINT
#=============================================================================

main() {
    local command="${1:-analyze}"
    shift || true

    local hours=$DEFAULT_HOURS
    local format="text"
    local output=""
    local verbose=false

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--hours)
                hours="$2"
                shift 2
                ;;
            -f|--format)
                format="$2"
                shift 2
                ;;
            -o|--output)
                output="$2"
                shift 2
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            --no-color)
                RED=""
                YELLOW=""
                GREEN=""
                BLUE=""
                CYAN=""
                BOLD=""
                NC=""
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    # Validate log directory
    if [[ ! -d "$LOG_DIR" ]]; then
        print_error "Log directory not found: $LOG_DIR"
        exit 1
    fi

    case $command in
        analyze|full)
            print_header "Tri-Agent Log Analysis (Last ${hours}h)"
            analyze_error_patterns "$hours"
            calculate_rates "$hours"
            detect_anomalies "$hours"
            suggest_fixes "$hours"
            ;;
        errors|error)
            print_header "Error Pattern Analysis"
            analyze_error_patterns "$hours"
            ;;
        rates|rate)
            print_header "Success/Failure Rates"
            calculate_rates "$hours"
            ;;
        anomalies|anomaly)
            print_header "Anomaly Detection"
            detect_anomalies "$hours"
            ;;
        fixes|fix|suggestions)
            print_header "Fix Suggestions"
            suggest_fixes "$hours"
            ;;
        report)
            print_header "Generating Report"
            local report_file
            report_file=$(generate_report "$hours" "$format")
            if [[ -n "$output" ]]; then
                cp "$report_file" "$output"
                print_success "Report saved to: $output"
            else
                print_success "Report saved to: $report_file"
            fi
            ;;
        monitor|watch)
            monitor_realtime "${hours}"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            echo "Run '$(basename "$0") help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
