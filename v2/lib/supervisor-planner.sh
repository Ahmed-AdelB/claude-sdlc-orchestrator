#!/bin/bash
# =============================================================================
# supervisor-planner.sh - Tri-Agent Failure Analysis & Fix Planning
# =============================================================================
# Uses all three models (Claude + Codex + Gemini) to analyze failures and
# generate fix recommendations.
#
# Usage: source this file in tri-agent-supervisor
# =============================================================================

# Planner version
SUPERVISOR_PLANNER_VERSION="1.0.0"

# =============================================================================
# Priority Classification
# =============================================================================

# Classify issue severity based on type and content
classify_severity() {
    local issue_type="$1"
    local content="$2"

    case "$issue_type" in
        security)
            # Security issues are always critical
            if echo "$content" | grep -qiE "(credential|password|api.?key|secret|token|injection|xss|sqli)"; then
                echo "CRITICAL"
            else
                echo "HIGH"
            fi
            ;;
        test)
            # Test failures based on count
            local fail_count=$(echo "$content" | grep -c "FAIL" || echo "0")
            if [[ $fail_count -gt 5 ]]; then
                echo "HIGH"
            elif [[ $fail_count -gt 0 ]]; then
                echo "MEDIUM"
            else
                echo "LOW"
            fi
            ;;
        coverage)
            # Coverage drops
            local coverage=$(echo "$content" | grep -oE "[0-9]+%" | head -1 | tr -d '%')
            if [[ -n "$coverage" && $coverage -lt 50 ]]; then
                echo "HIGH"
            elif [[ -n "$coverage" && $coverage -lt 70 ]]; then
                echo "MEDIUM"
            else
                echo "LOW"
            fi
            ;;
        lint)
            echo "LOW"
            ;;
        *)
            echo "MEDIUM"
            ;;
    esac
}

# =============================================================================
# Fix Recommendation Generation
# =============================================================================

# Parse test output to extract specific failures
parse_test_failures() {
    local log_file="$1"

    if [[ ! -f "$log_file" ]]; then
        echo "Log file not found: $log_file"
        return 1
    fi

    # Extract FAIL lines with context
    grep -B2 -A2 "FAIL" "$log_file" 2>/dev/null || echo "No failures found"
}

# Parse security audit to extract vulnerabilities
parse_security_findings() {
    local report_file="$1"

    if [[ ! -f "$report_file" ]]; then
        echo "Report file not found: $report_file"
        return 1
    fi

    # If JSON, parse with jq
    if [[ "$report_file" == *.json ]]; then
        jq -r '.issues[]? | "\(.severity): \(.description) in \(.file):\(.line)"' "$report_file" 2>/dev/null || \
            echo "Unable to parse JSON report"
    else
        cat "$report_file"
    fi
}

# Generate fix recommendations using Codex
generate_codex_fix() {
    local failure_content="$1"
    local fix_type="${2:-code}"

    if [[ ! -x "${BIN_DIR}/codex-ask" ]]; then
        echo "Codex not available"
        return 1
    fi

    local prompt="Generate a specific, actionable fix for this ${fix_type} issue.
Include the exact code changes needed:

${failure_content}

Provide:
1. Root cause analysis
2. Specific code fix (with file path and line numbers if possible)
3. Test to verify the fix"

    "${BIN_DIR}/codex-ask" "$prompt" 2>/dev/null || echo "Codex fix generation failed"
}

# Generate architecture recommendations using Gemini
generate_gemini_review() {
    local failure_content="$1"

    if [[ ! -x "${BIN_DIR}/gemini-ask" ]]; then
        echo "Gemini not available"
        return 1
    fi

    local prompt="Review this issue from an architecture perspective:

${failure_content}

Analyze:
1. Is this a symptom of a deeper architectural issue?
2. What patterns or refactoring would prevent similar issues?
3. Are there related areas that should be checked?"

    "${BIN_DIR}/gemini-ask" "$prompt" 2>/dev/null || echo "Gemini review generation failed"
}

# =============================================================================
# Task File Generation
# =============================================================================

# Generate a structured task file for the primary session
generate_fix_task() {
    local issue_id="$1"
    local severity="$2"
    local title="$3"
    local description="$4"
    local codex_fix="${5:-}"
    local gemini_review="${6:-}"
    local output_dir="${7:-${TASKS_DIR}/queue}"

    local task_file="${output_dir}/${severity}_${issue_id}_$(date +%Y%m%d_%H%M%S).md"

    cat > "$task_file" <<EOF
# SUPERVISOR FIX REQUEST: ${issue_id}

## Priority: ${severity}

## Title
${title}

## Description
${description}

---

## Codex Fix Recommendation
\`\`\`
${codex_fix:-No Codex fix available}
\`\`\`

---

## Gemini Architecture Review
\`\`\`
${gemini_review:-No Gemini review available}
\`\`\`

---

## Instructions for Primary Session

1. **Review** the issue details and recommendations above
2. **Implement** the suggested fix (or your own if better)
3. **Test** the fix thoroughly:
   - Run \`./tests/run_tests.sh\`
   - Run \`bin/tri-agent-preflight --quick\`
4. **Commit** with message referencing this issue: \`fix: ${title} [${issue_id}]\`
5. **Move** this file to \`tasks/completed/\` when done

## Metadata
- Created: $(date -Iseconds)
- Issue ID: ${issue_id}
- Severity: ${severity}
- Generator: supervisor-planner v${SUPERVISOR_PLANNER_VERSION}
EOF

    echo "$task_file"
}

# =============================================================================
# Batch Processing
# =============================================================================

# Queue multiple issues for batch processing
queue_issues_batch() {
    local issues_file="$1"  # JSON array of issues
    local output_dir="${2:-${TASKS_DIR}/queue}"

    if [[ ! -f "$issues_file" ]]; then
        echo "Issues file not found: $issues_file"
        return 1
    fi

    local count=0
    while read -r issue; do
        local id=$(echo "$issue" | jq -r '.id')
        local severity=$(echo "$issue" | jq -r '.severity')
        local title=$(echo "$issue" | jq -r '.title')
        local description=$(echo "$issue" | jq -r '.description')

        generate_fix_task "$id" "$severity" "$title" "$description" "" "" "$output_dir"
        ((count++))
    done < <(jq -c '.[]' "$issues_file")

    echo "Queued $count issues for processing"
}

# =============================================================================
# Utility Functions
# =============================================================================

# Check if an issue was already reported
is_issue_duplicate() {
    local issue_id="$1"
    local queue_dir="${TASKS_DIR}/queue"
    local feedback_dir="${TASKS_DIR}/supervisor_feedback"

    # Check if task already exists
    if ls "${queue_dir}"/*"${issue_id}"* 2>/dev/null | head -1 | grep -q .; then
        return 0  # Duplicate
    fi

    if ls "${feedback_dir}"/*"${issue_id}"* 2>/dev/null | head -1 | grep -q .; then
        return 0  # Duplicate
    fi

    return 1  # Not duplicate
}

# Get pending task count
get_pending_task_count() {
    local queue_dir="${TASKS_DIR}/queue"
    ls -1 "$queue_dir"/*.md 2>/dev/null | wc -l || echo "0"
}

# Summarize all pending tasks
summarize_pending_tasks() {
    local queue_dir="${TASKS_DIR}/queue"

    echo "=== Pending Supervisor Tasks ==="
    echo ""

    local critical=$(ls -1 "$queue_dir"/CRITICAL_*.md 2>/dev/null | wc -l || echo "0")
    local high=$(ls -1 "$queue_dir"/HIGH_*.md 2>/dev/null | wc -l || echo "0")
    local medium=$(ls -1 "$queue_dir"/MEDIUM_*.md 2>/dev/null | wc -l || echo "0")
    local low=$(ls -1 "$queue_dir"/LOW_*.md 2>/dev/null | wc -l || echo "0")

    echo "CRITICAL: $critical"
    echo "HIGH: $high"
    echo "MEDIUM: $medium"
    echo "LOW: $low"
    echo ""
    echo "Total: $((critical + high + medium + low))"
}
