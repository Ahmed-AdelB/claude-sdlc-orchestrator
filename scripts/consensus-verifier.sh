#!/bin/bash
# =============================================================================
# Tri-Agent Consensus Verifier
# =============================================================================
# Validates 2/3 approval workflow per CLAUDE.md requirements:
# - Minimum 2 out of 3 AI models must approve
# - Different models for implementation vs verification
# - Consensus tracking and logging
#
# Author: Ahmed Adel Bakr Alderai
# Version: 1.0.0
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly STATE_DIR="${HOME}/.claude/state"
readonly DB_FILE="${STATE_DIR}/consensus.db"
readonly LOG_DIR="${HOME}/.claude/logs"
readonly REPORT_DIR="${HOME}/.claude/reports/consensus"
readonly TIMEOUT_DEFAULT=120
readonly MIN_APPROVALS=2
readonly TOTAL_AGENTS=3

# Models
readonly MODELS=("claude" "codex" "gemini")

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# =============================================================================
# Logging Functions
# =============================================================================
log_info()    { echo -e "${BLUE}[INFO]${NC} $(date '+%H:%M:%S') $*"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $(date '+%H:%M:%S') $*"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $(date '+%H:%M:%S') $*"; }
log_error()   { echo -e "${RED}[FAIL]${NC} $(date '+%H:%M:%S') $*"; }
log_debug()   { [[ "${DEBUG:-0}" == "1" ]] && echo -e "${MAGENTA}[DEBUG]${NC} $*" || true; }

# =============================================================================
# Database Setup
# =============================================================================
init_database() {
    mkdir -p "$STATE_DIR" "$LOG_DIR" "$REPORT_DIR"

    sqlite3 "$DB_FILE" <<'EOF'
-- Consensus sessions table
CREATE TABLE IF NOT EXISTS consensus_sessions (
    id TEXT PRIMARY KEY,
    task_id TEXT NOT NULL,
    description TEXT,
    implementer TEXT NOT NULL,
    scope TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME,
    final_result TEXT CHECK(final_result IN ('PASS', 'FAIL', 'INCONCLUSIVE', 'PENDING')),
    approvals INTEGER DEFAULT 0,
    rejections INTEGER DEFAULT 0
);

-- Individual votes table
CREATE TABLE IF NOT EXISTS consensus_votes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    agent TEXT NOT NULL CHECK(agent IN ('claude', 'codex', 'gemini')),
    vote TEXT NOT NULL CHECK(vote IN ('APPROVE', 'REJECT', 'ABSTAIN', 'TIMEOUT', 'ERROR')),
    reason TEXT,
    evidence TEXT,
    duration_ms INTEGER,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (session_id) REFERENCES consensus_sessions(id),
    UNIQUE(session_id, agent)
);

-- Verification history for audit trail
CREATE TABLE IF NOT EXISTS verification_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    action TEXT NOT NULL,
    details TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (session_id) REFERENCES consensus_sessions(id)
);

-- Metrics aggregation view
CREATE VIEW IF NOT EXISTS consensus_metrics AS
SELECT
    date(created_at) as date,
    COUNT(*) as total_sessions,
    SUM(CASE WHEN final_result = 'PASS' THEN 1 ELSE 0 END) as passed,
    SUM(CASE WHEN final_result = 'FAIL' THEN 1 ELSE 0 END) as failed,
    SUM(CASE WHEN final_result = 'INCONCLUSIVE' THEN 1 ELSE 0 END) as inconclusive,
    ROUND(AVG(approvals), 2) as avg_approvals,
    ROUND(100.0 * SUM(CASE WHEN final_result = 'PASS' THEN 1 ELSE 0 END) / COUNT(*), 1) as pass_rate
FROM consensus_sessions
WHERE final_result IS NOT NULL
GROUP BY date(created_at);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_sessions_task ON consensus_sessions(task_id);
CREATE INDEX IF NOT EXISTS idx_sessions_result ON consensus_sessions(final_result);
CREATE INDEX IF NOT EXISTS idx_votes_session ON consensus_votes(session_id);
CREATE INDEX IF NOT EXISTS idx_history_session ON verification_history(session_id);
EOF

    log_info "Database initialized: $DB_FILE"
}

# =============================================================================
# Session Management
# =============================================================================
generate_session_id() {
    local task_id="${1:-TASK}"
    echo "CS-$(date +%Y%m%d%H%M%S)-${task_id}-$(openssl rand -hex 4)"
}

create_session() {
    local task_id="$1"
    local description="$2"
    local implementer="$3"
    local scope="${4:-}"
    local session_id

    session_id=$(generate_session_id "$task_id")

    sqlite3 "$DB_FILE" <<EOF
INSERT INTO consensus_sessions (id, task_id, description, implementer, scope, final_result)
VALUES ('$session_id', '$task_id', '$(echo "$description" | sed "s/'/''/g")', '$implementer', '$(echo "$scope" | sed "s/'/''/g")', 'PENDING');
EOF

    log_audit "$session_id" "SESSION_CREATED" "Task: $task_id, Implementer: $implementer"
    echo "$session_id"
}

log_audit() {
    local session_id="$1"
    local action="$2"
    local details="$3"

    sqlite3 "$DB_FILE" <<EOF
INSERT INTO verification_history (session_id, action, details)
VALUES ('$session_id', '$action', '$(echo "$details" | sed "s/'/''/g")');
EOF
}

# =============================================================================
# Vote Recording
# =============================================================================
record_vote() {
    local session_id="$1"
    local agent="$2"
    local vote="$3"
    local reason="${4:-}"
    local evidence="${5:-}"
    local duration_ms="${6:-0}"

    # Validate agent is not the implementer
    local implementer
    implementer=$(sqlite3 "$DB_FILE" "SELECT implementer FROM consensus_sessions WHERE id='$session_id';")

    if [[ "$agent" == "$implementer" ]]; then
        log_error "Agent '$agent' cannot vote on their own implementation"
        return 1
    fi

    # Record the vote (upsert)
    sqlite3 "$DB_FILE" <<EOF
INSERT OR REPLACE INTO consensus_votes (session_id, agent, vote, reason, evidence, duration_ms)
VALUES ('$session_id', '$agent', '$vote', '$(echo "$reason" | sed "s/'/''/g")', '$(echo "$evidence" | sed "s/'/''/g")', $duration_ms);
EOF

    log_audit "$session_id" "VOTE_RECORDED" "Agent: $agent, Vote: $vote"

    # Update session counts
    update_session_counts "$session_id"
}

update_session_counts() {
    local session_id="$1"

    sqlite3 "$DB_FILE" <<EOF
UPDATE consensus_sessions SET
    approvals = (SELECT COUNT(*) FROM consensus_votes WHERE session_id='$session_id' AND vote='APPROVE'),
    rejections = (SELECT COUNT(*) FROM consensus_votes WHERE session_id='$session_id' AND vote='REJECT')
WHERE id='$session_id';
EOF
}

# =============================================================================
# Consensus Evaluation
# =============================================================================
evaluate_consensus() {
    local session_id="$1"

    local approvals rejections abstains errors total_votes
    approvals=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM consensus_votes WHERE session_id='$session_id' AND vote='APPROVE';")
    rejections=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM consensus_votes WHERE session_id='$session_id' AND vote='REJECT';")
    abstains=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM consensus_votes WHERE session_id='$session_id' AND vote IN ('ABSTAIN', 'TIMEOUT');")
    errors=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM consensus_votes WHERE session_id='$session_id' AND vote='ERROR';")
    total_votes=$((approvals + rejections + abstains + errors))

    local result

    # Decision logic per CLAUDE.md: 2/3 approval required
    if [[ $approvals -ge $MIN_APPROVALS ]]; then
        result="PASS"
    elif [[ $rejections -ge $MIN_APPROVALS ]]; then
        result="FAIL"
    elif [[ $total_votes -ge 2 && $errors -gt 0 ]]; then
        result="INCONCLUSIVE"
    elif [[ $abstains -ge 2 ]]; then
        result="INCONCLUSIVE"
    else
        result="PENDING"
    fi

    # Update final result
    sqlite3 "$DB_FILE" <<EOF
UPDATE consensus_sessions SET
    final_result = '$result',
    completed_at = CASE WHEN '$result' != 'PENDING' THEN CURRENT_TIMESTAMP ELSE NULL END
WHERE id='$session_id';
EOF

    log_audit "$session_id" "CONSENSUS_EVALUATED" "Result: $result (Approvals: $approvals, Rejections: $rejections)"

    echo "$result"
}

# =============================================================================
# Agent Invocation
# =============================================================================
invoke_claude() {
    local prompt="$1"
    local timeout="${2:-$TIMEOUT_DEFAULT}"

    # Claude is the orchestrator - this represents internal review
    # In practice, this would be a separate Claude instance or internal verification
    log_debug "Claude verification request (internal)"

    # Simulate Claude verification with timeout
    local start_ms=$(($(date +%s%N) / 1000000))
    local result

    if command -v claude &>/dev/null; then
        result=$(timeout "$timeout" claude -p "$prompt" 2>/dev/null | tail -20) || result="TIMEOUT"
    else
        result="ERROR: Claude CLI not available"
    fi

    local end_ms=$(($(date +%s%N) / 1000000))
    local duration=$((end_ms - start_ms))

    echo "$result"
    echo "DURATION:$duration"
}

invoke_gemini() {
    local prompt="$1"
    local timeout="${2:-$TIMEOUT_DEFAULT}"

    log_debug "Gemini verification request"

    local start_ms=$(($(date +%s%N) / 1000000))
    local result

    if command -v gemini &>/dev/null; then
        result=$(timeout "$timeout" gemini -m gemini-3-pro-preview --approval-mode yolo "$prompt" 2>/dev/null | tail -20) || result="TIMEOUT"
    else
        result="ERROR: Gemini CLI not available"
    fi

    local end_ms=$(($(date +%s%N) / 1000000))
    local duration=$((end_ms - start_ms))

    echo "$result"
    echo "DURATION:$duration"
}

invoke_codex() {
    local prompt="$1"
    local timeout="${2:-$TIMEOUT_DEFAULT}"

    log_debug "Codex verification request"

    local start_ms=$(($(date +%s%N) / 1000000))
    local result

    if command -v codex &>/dev/null; then
        result=$(timeout "$timeout" codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "$prompt" 2>/dev/null | tail -20) || result="TIMEOUT"
    else
        result="ERROR: Codex CLI not available"
    fi

    local end_ms=$(($(date +%s%N) / 1000000))
    local duration=$((end_ms - start_ms))

    echo "$result"
    echo "DURATION:$duration"
}

parse_vote_from_response() {
    local response="$1"

    # Extract vote from response
    if echo "$response" | grep -qiE '(APPROVE|APPROVED|PASS|LGTM)'; then
        echo "APPROVE"
    elif echo "$response" | grep -qiE '(REJECT|REJECTED|FAIL|BLOCK)'; then
        echo "REJECT"
    elif echo "$response" | grep -qiE '(ABSTAIN|SKIP|UNABLE)'; then
        echo "ABSTAIN"
    elif echo "$response" | grep -qiE '(TIMEOUT|timed out)'; then
        echo "TIMEOUT"
    elif echo "$response" | grep -qiE '(ERROR|error:)'; then
        echo "ERROR"
    else
        echo "ABSTAIN"
    fi
}

# =============================================================================
# Verification Workflow
# =============================================================================
run_verification() {
    local session_id="$1"
    local verify_prompt="$2"
    local exclude_agent="${3:-}"
    local timeout="${4:-$TIMEOUT_DEFAULT}"

    local implementer
    implementer=$(sqlite3 "$DB_FILE" "SELECT implementer FROM consensus_sessions WHERE id='$session_id';")

    log_info "Starting consensus verification for session: $session_id"
    log_info "Implementer: $implementer (excluded from voting)"

    echo ""
    echo "=============================================="
    echo " TRI-AGENT CONSENSUS VERIFICATION"
    echo "=============================================="
    echo ""

    # Collect votes from non-implementing agents
    for agent in "${MODELS[@]}"; do
        if [[ "$agent" == "$implementer" ]]; then
            log_info "$agent: SKIPPED (implementer)"
            continue
        fi

        log_info "Requesting verification from $agent..."

        local response duration vote reason

        case "$agent" in
            claude)
                response=$(invoke_claude "$verify_prompt" "$timeout")
                ;;
            gemini)
                response=$(invoke_gemini "$verify_prompt" "$timeout")
                ;;
            codex)
                response=$(invoke_codex "$verify_prompt" "$timeout")
                ;;
        esac

        # Parse duration from response
        duration=$(echo "$response" | grep "DURATION:" | cut -d: -f2)
        response=$(echo "$response" | grep -v "DURATION:")

        # Parse vote
        vote=$(parse_vote_from_response "$response")
        reason=$(echo "$response" | head -5)

        # Record the vote
        record_vote "$session_id" "$agent" "$vote" "$reason" "" "${duration:-0}"

        # Display result
        case "$vote" in
            APPROVE)
                log_success "$agent: APPROVED"
                ;;
            REJECT)
                log_error "$agent: REJECTED"
                ;;
            ABSTAIN|TIMEOUT)
                log_warning "$agent: $vote"
                ;;
            ERROR)
                log_error "$agent: ERROR"
                ;;
        esac

        echo ""
    done

    # Evaluate final consensus
    local result
    result=$(evaluate_consensus "$session_id")

    echo "=============================================="
    echo " CONSENSUS RESULT"
    echo "=============================================="

    local approvals rejections
    approvals=$(sqlite3 "$DB_FILE" "SELECT approvals FROM consensus_sessions WHERE id='$session_id';")
    rejections=$(sqlite3 "$DB_FILE" "SELECT rejections FROM consensus_sessions WHERE id='$session_id';")

    echo ""
    echo "  Approvals:  $approvals / $((TOTAL_AGENTS - 1))"
    echo "  Rejections: $rejections / $((TOTAL_AGENTS - 1))"
    echo "  Required:   $MIN_APPROVALS approvals"
    echo ""

    case "$result" in
        PASS)
            echo -e "  ${GREEN}${BOLD}CONSENSUS: PASS${NC}"
            echo "  Verification successful - 2/3 majority achieved"
            ;;
        FAIL)
            echo -e "  ${RED}${BOLD}CONSENSUS: FAIL${NC}"
            echo "  Verification failed - insufficient approvals"
            ;;
        INCONCLUSIVE)
            echo -e "  ${YELLOW}${BOLD}CONSENSUS: INCONCLUSIVE${NC}"
            echo "  Unable to reach consensus - escalate to user"
            ;;
        PENDING)
            echo -e "  ${BLUE}${BOLD}CONSENSUS: PENDING${NC}"
            echo "  Waiting for more votes"
            ;;
    esac

    echo ""
    echo "=============================================="

    return $([ "$result" == "PASS" ] && echo 0 || echo 1)
}

# =============================================================================
# Report Generation
# =============================================================================
generate_report() {
    local session_id="$1"
    local format="${2:-text}"
    local output_file="${REPORT_DIR}/${session_id}.${format}"

    mkdir -p "$REPORT_DIR"

    # Fetch session data
    local session_data votes_data
    session_data=$(sqlite3 -json "$DB_FILE" "SELECT * FROM consensus_sessions WHERE id='$session_id';")
    votes_data=$(sqlite3 -json "$DB_FILE" "SELECT * FROM consensus_votes WHERE session_id='$session_id' ORDER BY created_at;")
    history_data=$(sqlite3 -json "$DB_FILE" "SELECT * FROM verification_history WHERE session_id='$session_id' ORDER BY created_at;")

    case "$format" in
        json)
            cat > "$output_file" <<EOF
{
  "session": $session_data,
  "votes": $votes_data,
  "history": $history_data,
  "generated_at": "$(date -Iseconds)"
}
EOF
            ;;
        markdown|md)
            generate_markdown_report "$session_id" > "$output_file"
            ;;
        text|*)
            generate_text_report "$session_id" > "$output_file"
            ;;
    esac

    log_info "Report generated: $output_file"
    echo "$output_file"
}

generate_text_report() {
    local session_id="$1"

    cat <<EOF
================================================================================
TRI-AGENT CONSENSUS VERIFICATION REPORT
================================================================================

Session ID: $session_id
Generated:  $(date)

--------------------------------------------------------------------------------
SESSION DETAILS
--------------------------------------------------------------------------------
$(sqlite3 -header -column "$DB_FILE" "SELECT task_id, description, implementer, scope, final_result, approvals, rejections, created_at, completed_at FROM consensus_sessions WHERE id='$session_id';")

--------------------------------------------------------------------------------
VOTES
--------------------------------------------------------------------------------
$(sqlite3 -header -column "$DB_FILE" "SELECT agent, vote, reason, duration_ms, created_at FROM consensus_votes WHERE session_id='$session_id';")

--------------------------------------------------------------------------------
AUDIT TRAIL
--------------------------------------------------------------------------------
$(sqlite3 -header -column "$DB_FILE" "SELECT action, details, created_at FROM verification_history WHERE session_id='$session_id' ORDER BY created_at;")

================================================================================
END OF REPORT
================================================================================
EOF
}

generate_markdown_report() {
    local session_id="$1"

    local task_id desc implementer scope result approvals rejections created completed
    read -r task_id desc implementer scope result approvals rejections created completed < <(
        sqlite3 -separator $'\t' "$DB_FILE" \
        "SELECT task_id, description, implementer, scope, final_result, approvals, rejections, created_at, completed_at FROM consensus_sessions WHERE id='$session_id';"
    )

    cat <<EOF
# Tri-Agent Consensus Verification Report

**Session ID:** \`$session_id\`
**Generated:** $(date)

---

## Session Details

| Field | Value |
|-------|-------|
| Task ID | $task_id |
| Description | $desc |
| Implementer | $implementer |
| Scope | $scope |
| Final Result | **$result** |
| Approvals | $approvals |
| Rejections | $rejections |
| Created | $created |
| Completed | $completed |

---

## Votes

| Agent | Vote | Reason | Duration (ms) | Timestamp |
|-------|------|--------|---------------|-----------|
$(sqlite3 -separator '|' "$DB_FILE" "SELECT agent, vote, reason, duration_ms, created_at FROM consensus_votes WHERE session_id='$session_id';" | while IFS='|' read -r agent vote reason dur ts; do
    echo "| $agent | $vote | $reason | $dur | $ts |"
done)

---

## Audit Trail

| Action | Details | Timestamp |
|--------|---------|-----------|
$(sqlite3 -separator '|' "$DB_FILE" "SELECT action, details, created_at FROM verification_history WHERE session_id='$session_id' ORDER BY created_at;" | while IFS='|' read -r action details ts; do
    echo "| $action | $details | $ts |"
done)

---

## Consensus Analysis

$(case "$result" in
    PASS) echo "The verification **PASSED** with $approvals out of $((TOTAL_AGENTS - 1)) approvals (minimum $MIN_APPROVALS required).";;
    FAIL) echo "The verification **FAILED** with only $approvals approvals (minimum $MIN_APPROVALS required).";;
    INCONCLUSIVE) echo "The verification was **INCONCLUSIVE**. Manual review is required.";;
    *) echo "The verification is still **PENDING**.";;
esac)

---

*Report generated by Tri-Agent Consensus Verifier v1.0.0*
EOF
}

# =============================================================================
# Demo Functions
# =============================================================================
demo_pass_scenario() {
    echo ""
    echo -e "${CYAN}${BOLD}=== DEMO: PASS SCENARIO ===${NC}"
    echo ""

    local session_id
    session_id=$(create_session "T-001" "Implement OAuth2 PKCE flow" "claude" "src/auth/")

    log_info "Created session: $session_id"
    log_info "Implementer: claude (excluded from voting)"
    echo ""

    # Simulate gemini approval
    log_info "Simulating Gemini review..."
    record_vote "$session_id" "gemini" "APPROVE" "Architecture follows RFC 7636, security best practices applied" "Code review completed" 5200
    log_success "Gemini: APPROVED"

    # Simulate codex approval
    log_info "Simulating Codex review..."
    record_vote "$session_id" "codex" "APPROVE" "Tests pass, code coverage 85%, no vulnerabilities detected" "npm test output clean" 8100
    log_success "Codex: APPROVED"

    # Evaluate
    local result
    result=$(evaluate_consensus "$session_id")

    echo ""
    echo -e "${GREEN}${BOLD}Final Result: $result${NC}"
    echo "Approvals: 2/2 (minimum 2 required)"
    echo ""

    # Generate report
    generate_report "$session_id" "markdown"
}

demo_fail_scenario() {
    echo ""
    echo -e "${CYAN}${BOLD}=== DEMO: FAIL SCENARIO ===${NC}"
    echo ""

    local session_id
    session_id=$(create_session "T-002" "Add admin bypass endpoint" "codex" "src/api/admin.ts")

    log_info "Created session: $session_id"
    log_info "Implementer: codex (excluded from voting)"
    echo ""

    # Simulate claude rejection
    log_info "Simulating Claude review..."
    record_vote "$session_id" "claude" "REJECT" "CRITICAL: Hardcoded credentials detected on line 47, bypasses authentication" "Security scan failed" 3200
    log_error "Claude: REJECTED"

    # Simulate gemini rejection
    log_info "Simulating Gemini review..."
    record_vote "$session_id" "gemini" "REJECT" "HIGH: No input validation, SQL injection vulnerability in query builder" "Static analysis failed" 4800
    log_error "Gemini: REJECTED"

    # Evaluate
    local result
    result=$(evaluate_consensus "$session_id")

    echo ""
    echo -e "${RED}${BOLD}Final Result: $result${NC}"
    echo "Rejections: 2/2 (consensus to reject)"
    echo ""
    echo "Issues Found:"
    echo "  1. CRITICAL - Hardcoded credentials (line 47)"
    echo "  2. HIGH - SQL injection vulnerability"
    echo ""
    echo "Required Actions:"
    echo "  - Remove hardcoded credentials, use environment variables"
    echo "  - Add parameterized queries"
    echo "  - Re-submit for fresh verification"
    echo ""

    # Generate report
    generate_report "$session_id" "markdown"
}

demo_inconclusive_scenario() {
    echo ""
    echo -e "${CYAN}${BOLD}=== DEMO: INCONCLUSIVE SCENARIO ===${NC}"
    echo ""

    local session_id
    session_id=$(create_session "T-003" "Refactor database connection pool" "gemini" "src/db/pool.ts")

    log_info "Created session: $session_id"
    log_info "Implementer: gemini (excluded from voting)"
    echo ""

    # Simulate claude approval
    log_info "Simulating Claude review..."
    record_vote "$session_id" "claude" "APPROVE" "Connection pooling implementation looks correct" "Code review passed" 4100
    log_success "Claude: APPROVED"

    # Simulate codex timeout/error
    log_info "Simulating Codex review..."
    record_vote "$session_id" "codex" "TIMEOUT" "Request timed out after 120s" "" 120000
    log_warning "Codex: TIMEOUT"

    # Evaluate
    local result
    result=$(evaluate_consensus "$session_id")

    echo ""
    echo -e "${YELLOW}${BOLD}Final Result: $result${NC}"
    echo "Approvals: 1/2, Timeouts: 1/2"
    echo ""
    echo "Status: Unable to reach consensus"
    echo ""
    echo "Resolution Options:"
    echo "  1. Retry Codex verification with increased timeout"
    echo "  2. Request third AI (manual Claude instance) for tiebreaker"
    echo "  3. Escalate to user for manual review"
    echo ""

    # Generate report
    generate_report "$session_id" "markdown"
}

run_all_demos() {
    echo ""
    echo "=============================================="
    echo " TRI-AGENT CONSENSUS VERIFIER - DEMO MODE"
    echo "=============================================="
    echo ""
    echo "This demo illustrates three verification scenarios:"
    echo "  1. PASS - 2/2 approvals achieved"
    echo "  2. FAIL - 2/2 rejections (security issues)"
    echo "  3. INCONCLUSIVE - Split vote with timeout"
    echo ""

    demo_pass_scenario
    echo ""
    demo_fail_scenario
    echo ""
    demo_inconclusive_scenario

    echo ""
    echo "=============================================="
    echo " DEMO COMPLETE"
    echo "=============================================="
    echo ""
    echo "Reports saved to: $REPORT_DIR/"
    echo ""

    # Show metrics
    echo "Session Metrics:"
    sqlite3 -header -column "$DB_FILE" "SELECT * FROM consensus_metrics;"
}

# =============================================================================
# CLI Interface
# =============================================================================
usage() {
    cat <<EOF
${BOLD}Tri-Agent Consensus Verifier${NC}

Validates 2/3 approval workflow per CLAUDE.md requirements.

${BOLD}USAGE:${NC}
    $(basename "$0") <command> [options]

${BOLD}COMMANDS:${NC}
    init                Initialize database
    verify              Run verification workflow
    create              Create new consensus session
    vote                Record a vote
    evaluate            Evaluate consensus for session
    report              Generate verification report
    metrics             Show consensus metrics
    demo                Run demonstration scenarios
    help                Show this help message

${BOLD}VERIFY OPTIONS:${NC}
    -t, --task ID       Task identifier
    -d, --desc TEXT     Task description
    -i, --impl AGENT    Implementing agent (claude|codex|gemini)
    -s, --scope PATH    File/directory scope
    -p, --prompt TEXT   Verification prompt
    --timeout SEC       Timeout per agent (default: 120)

${BOLD}VOTE OPTIONS:${NC}
    -s, --session ID    Session identifier
    -a, --agent NAME    Voting agent (claude|codex|gemini)
    -v, --vote VOTE     Vote (APPROVE|REJECT|ABSTAIN)
    -r, --reason TEXT   Reason for vote

${BOLD}REPORT OPTIONS:${NC}
    -s, --session ID    Session identifier
    -f, --format FMT    Output format (text|markdown|json)

${BOLD}EXAMPLES:${NC}
    # Initialize database
    $(basename "$0") init

    # Run full verification workflow
    $(basename "$0") verify -t T-001 -d "Add OAuth2 support" -i claude -s src/auth/

    # Create session manually
    $(basename "$0") create -t T-002 -d "Fix login bug" -i codex

    # Record vote
    $(basename "$0") vote -s CS-xxx -a gemini -v APPROVE -r "LGTM"

    # Generate report
    $(basename "$0") report -s CS-xxx -f markdown

    # Show metrics
    $(basename "$0") metrics

    # Run demos
    $(basename "$0") demo

${BOLD}ENVIRONMENT:${NC}
    DEBUG=1             Enable debug output
    TIMEOUT=120         Default timeout in seconds

${BOLD}CONSENSUS RULES:${NC}
    - Minimum 2 out of 3 AI models must approve
    - Implementer cannot vote on their own work
    - PASS: >= 2 approvals
    - FAIL: >= 2 rejections
    - INCONCLUSIVE: Split votes or errors

EOF
}

# =============================================================================
# Main
# =============================================================================
main() {
    local command="${1:-help}"
    shift || true

    case "$command" in
        init)
            init_database
            ;;

        verify)
            init_database
            local task_id="" description="" implementer="" scope="" prompt="" timeout="$TIMEOUT_DEFAULT"

            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -t|--task) task_id="$2"; shift 2;;
                    -d|--desc) description="$2"; shift 2;;
                    -i|--impl) implementer="$2"; shift 2;;
                    -s|--scope) scope="$2"; shift 2;;
                    -p|--prompt) prompt="$2"; shift 2;;
                    --timeout) timeout="$2"; shift 2;;
                    *) log_error "Unknown option: $1"; exit 1;;
                esac
            done

            if [[ -z "$task_id" || -z "$implementer" ]]; then
                log_error "Task ID and implementer are required"
                exit 1
            fi

            local session_id
            session_id=$(create_session "$task_id" "$description" "$implementer" "$scope")

            if [[ -z "$prompt" ]]; then
                prompt="Verify the implementation for task $task_id: $description. Scope: $scope. Check for correctness, security issues, edge cases. Reply with APPROVE or REJECT followed by your findings."
            fi

            run_verification "$session_id" "$prompt" "$implementer" "$timeout"
            generate_report "$session_id" "markdown"
            ;;

        create)
            init_database
            local task_id="" description="" implementer="" scope=""

            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -t|--task) task_id="$2"; shift 2;;
                    -d|--desc) description="$2"; shift 2;;
                    -i|--impl) implementer="$2"; shift 2;;
                    -s|--scope) scope="$2"; shift 2;;
                    *) log_error "Unknown option: $1"; exit 1;;
                esac
            done

            if [[ -z "$task_id" || -z "$implementer" ]]; then
                log_error "Task ID and implementer are required"
                exit 1
            fi

            create_session "$task_id" "$description" "$implementer" "$scope"
            ;;

        vote)
            init_database
            local session_id="" agent="" vote="" reason=""

            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -s|--session) session_id="$2"; shift 2;;
                    -a|--agent) agent="$2"; shift 2;;
                    -v|--vote) vote="$2"; shift 2;;
                    -r|--reason) reason="$2"; shift 2;;
                    *) log_error "Unknown option: $1"; exit 1;;
                esac
            done

            if [[ -z "$session_id" || -z "$agent" || -z "$vote" ]]; then
                log_error "Session ID, agent, and vote are required"
                exit 1
            fi

            record_vote "$session_id" "$agent" "$vote" "$reason"
            ;;

        evaluate)
            init_database
            local session_id="${1:-}"

            if [[ -z "$session_id" ]]; then
                log_error "Session ID is required"
                exit 1
            fi

            evaluate_consensus "$session_id"
            ;;

        report)
            init_database
            local session_id="" format="text"

            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -s|--session) session_id="$2"; shift 2;;
                    -f|--format) format="$2"; shift 2;;
                    *) log_error "Unknown option: $1"; exit 1;;
                esac
            done

            if [[ -z "$session_id" ]]; then
                log_error "Session ID is required"
                exit 1
            fi

            generate_report "$session_id" "$format"
            ;;

        metrics)
            init_database
            echo ""
            echo "=== CONSENSUS METRICS ==="
            echo ""
            sqlite3 -header -column "$DB_FILE" "SELECT * FROM consensus_metrics ORDER BY date DESC LIMIT 30;"
            echo ""
            echo "=== RECENT SESSIONS ==="
            echo ""
            sqlite3 -header -column "$DB_FILE" "SELECT id, task_id, implementer, final_result, approvals, rejections, created_at FROM consensus_sessions ORDER BY created_at DESC LIMIT 10;"
            ;;

        demo)
            init_database
            run_all_demos
            ;;

        help|--help|-h)
            usage
            ;;

        *)
            log_error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

main "$@"
