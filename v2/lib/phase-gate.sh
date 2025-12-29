#!/bin/bash
# =============================================================================
# phase-gate.sh - SDLC Phase Gate Enforcement Library
# =============================================================================
# Enforces the 5-phase SDLC discipline:
#   1. BRAINSTORM - Requirements gathering, clarifying questions
#   2. DOCUMENT   - Specification with acceptance criteria
#   3. PLAN       - Technical design, mission breakdown
#   4. EXECUTE    - Implementation with parallel/sequential agents
#   5. TRACK      - Progress monitoring, stakeholder updates
#
# No task can skip phases. Each phase must produce artifacts and pass gates.
# =============================================================================

: "${STATE_DIR:=$HOME/.claude/autonomous/state}"
: "${STATE_DB:=$STATE_DIR/tri-agent.db}"

# =============================================================================
# SEC-008-3: Security Score Validation (Anti-Manipulation)
# =============================================================================
# Validates that security/validation scores are within valid ranges and cannot
# be manipulated. Prevents attacks where scores are injected to bypass gates.
#
# Validation rules:
# 1. Score must be a valid number (integer or decimal)
# 2. Score must be between 0 and 100 (inclusive)
# 3. Score cannot be negative or exceed 100
# 4. Score string must not contain shell/control characters
# =============================================================================

# Security score constraints (readonly)
readonly MIN_VALID_SCORE=0
readonly MAX_VALID_SCORE=100

# Validate a security/validation score value
validate_security_score() {
    local score_value="$1"
    local context="${2:-unknown}"

    # Strip whitespace
    score_value=$(echo "$score_value" | tr -d '[:space:]')

    # SEC-008-3: Check for empty value
    if [[ -z "$score_value" ]]; then
        log_error "SEC-008-3: Empty security score from $context" 2>/dev/null || echo "[ERROR] SEC-008-3: Empty security score from $context" >&2
        return 1
    fi

    # SEC-008-3: Check for valid numeric format (integer or decimal)
    if ! [[ "$score_value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        log_error "SEC-008-3: Invalid score format '$score_value' from $context (must be numeric)" 2>/dev/null || \
            echo "[ERROR] SEC-008-3: Invalid score format '$score_value' from $context (must be numeric)" >&2
        return 1
    fi

    # SEC-008-3: Check for shell injection attempts (defense in depth)
    if [[ "$score_value" =~ [\$\`\;\|\&\<\>] ]]; then
        log_error "SEC-008-3: Shell injection attempt in score from $context" 2>/dev/null || \
            echo "[ERROR] SEC-008-3: Shell injection attempt in score from $context" >&2
        return 1
    fi

    # SEC-008-3: Use awk for numeric range validation
    local awk_bin
    awk_bin=$(command -v awk 2>/dev/null) || awk_bin="/usr/bin/awk"

    # Check if score is below minimum (< 0)
    if "$awk_bin" "BEGIN{exit !($score_value < $MIN_VALID_SCORE)}"; then
        log_error "SEC-008-3: Negative security score '$score_value' from $context" 2>/dev/null || \
            echo "[ERROR] SEC-008-3: Negative security score '$score_value' from $context" >&2
        return 1
    fi

    # Check if score exceeds maximum (> 100)
    if "$awk_bin" "BEGIN{exit !($score_value > $MAX_VALID_SCORE)}"; then
        log_error "SEC-008-3: Security score exceeds 100: '$score_value' from $context" 2>/dev/null || \
            echo "[ERROR] SEC-008-3: Security score exceeds 100: '$score_value' from $context" >&2
        return 1
    fi

    # SEC-008-3: Warn on perfect scores (may indicate spoofing)
    if [[ "$score_value" == "100" ]] || [[ "$score_value" == "100.0" ]]; then
        log_warn "SEC-008-3: Perfect 100 score from $context - verify legitimacy" 2>/dev/null || \
            echo "[WARN] SEC-008-3: Perfect 100 score from $context - verify legitimacy" >&2
    fi

    return 0
}

# Validate confidence score (same constraints as security score)
validate_confidence_score() {
    local confidence="$1"
    local context="${2:-unknown}"

    # Confidence is typically 0.0-1.0, but we also support 0-100%
    local normalized="$confidence"

    # If confidence is in 0-1 range, it's a probability - validate differently
    local awk_bin
    awk_bin=$(command -v awk 2>/dev/null) || awk_bin="/usr/bin/awk"

    # Strip whitespace
    confidence=$(echo "$confidence" | tr -d '[:space:]')

    # Check for valid numeric format
    if ! [[ "$confidence" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        log_error "SEC-008-3: Invalid confidence format '$confidence' from $context" 2>/dev/null || \
            echo "[ERROR] SEC-008-3: Invalid confidence format '$confidence' from $context" >&2
        return 1
    fi

    # Check if confidence appears to be a probability (0-1)
    if "$awk_bin" "BEGIN{exit !($confidence >= 0 && $confidence <= 1)}"; then
        # Valid probability range
        return 0
    fi

    # Check if confidence appears to be a percentage (0-100)
    if "$awk_bin" "BEGIN{exit !($confidence >= 0 && $confidence <= 100)}"; then
        # Valid percentage range
        return 0
    fi

    # Out of all valid ranges
    log_error "SEC-008-3: Confidence '$confidence' out of valid range from $context" 2>/dev/null || \
        echo "[ERROR] SEC-008-3: Confidence '$confidence' out of valid range from $context" >&2
    return 1
}

# Wrapper to validate any score-like value with appropriate context
validate_gate_score() {
    local score="$1"
    local score_type="${2:-generic}"
    local context="${3:-unknown}"

    case "$score_type" in
        security|validation_score)
            validate_security_score "$score" "$context"
            ;;
        confidence)
            validate_confidence_score "$score" "$context"
            ;;
        *)
            # Default to security score validation (0-100 range)
            validate_security_score "$score" "$context"
            ;;
    esac
}

# Export validation functions
export -f validate_security_score
export -f validate_confidence_score
export -f validate_gate_score

# Phase definitions with required artifacts
declare -A PHASE_CONFIG=(
    [BRAINSTORM]="order:1|next:DOCUMENT|artifacts:requirements.md,questions.md"
    [DOCUMENT]="order:2|next:PLAN|artifacts:spec.md,acceptance_criteria.md"
    [PLAN]="order:3|next:EXECUTE|artifacts:design.md,missions.json"
    [EXECUTE]="order:4|next:TRACK|artifacts:implementation_log.md,test_results.json"
    [TRACK]="order:5|next:COMPLETE|artifacts:progress_report.md,metrics.json"
)

# Valid phase transitions
declare -A VALID_TRANSITIONS=(
    [BRAINSTORM]="DOCUMENT"
    [DOCUMENT]="PLAN BRAINSTORM"     # Can go back to brainstorm if spec reveals gaps
    [PLAN]="EXECUTE DOCUMENT"         # Can go back to document if plan reveals spec issues
    [EXECUTE]="TRACK PLAN"            # Can go back to plan if implementation reveals design issues
    [TRACK]="COMPLETE EXECUTE"        # Can continue executing if tracking reveals work needed
)

# =============================================================================
# Phase Gate Schema
# =============================================================================

init_phase_gate_schema() {
    local db="${1:-$STATE_DB}"

    if ! command -v sqlite3 >/dev/null 2>&1; then
        echo "Error: sqlite3 not found" >&2
        return 1
    fi

    sqlite3 "$db" <<SQL
-- Phase tracking table
CREATE TABLE IF NOT EXISTS task_phases (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id TEXT NOT NULL,
    phase TEXT NOT NULL CHECK (phase IN ('BRAINSTORM', 'DOCUMENT', 'PLAN', 'EXECUTE', 'TRACK', 'COMPLETE')),
    started_at TEXT DEFAULT (datetime('now')),
    completed_at TEXT,
    artifacts TEXT,  -- JSON array of artifact paths
    gate_status TEXT CHECK (gate_status IN ('PENDING', 'PASSED', 'FAILED', 'BLOCKED')),
    gate_failures TEXT,  -- JSON array of failure reasons
    gate_approvers TEXT, -- JSON array of approving models
    created_at TEXT DEFAULT (datetime('now')),
    UNIQUE(task_id, phase)
);

-- Phase artifacts table
CREATE TABLE IF NOT EXISTS phase_artifacts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id TEXT NOT NULL,
    phase TEXT NOT NULL,
    artifact_type TEXT NOT NULL,
    artifact_path TEXT NOT NULL,
    content_hash TEXT,
    validated BOOLEAN DEFAULT 0,
    validator_model TEXT,
    validation_score REAL,
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (task_id) REFERENCES tasks(id)
);

-- Phase gate decisions table
CREATE TABLE IF NOT EXISTS phase_gate_decisions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id TEXT NOT NULL,
    phase TEXT NOT NULL,
    model TEXT NOT NULL,
    decision TEXT CHECK (decision IN ('APPROVE', 'REJECT', 'ABSTAIN', 'REQUEST_CHANGES')),
    confidence REAL,
    reasoning TEXT,
    required_changes TEXT,  -- JSON if REQUEST_CHANGES
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_task_phases_task ON task_phases(task_id);
CREATE INDEX IF NOT EXISTS idx_phase_artifacts_task ON phase_artifacts(task_id, phase);
CREATE INDEX IF NOT EXISTS idx_gate_decisions_task ON phase_gate_decisions(task_id, phase);
SQL
}

# =============================================================================
# Phase Management Functions
# =============================================================================

# Get current phase for a task
get_current_phase() {
    local task_id="$1"
    local db="${2:-$STATE_DB}"

    local phase
    phase=$(sqlite3 "$db" <<SQL
SELECT phase FROM task_phases
WHERE task_id = '$(_sql_escape "$task_id")'
AND completed_at IS NULL
ORDER BY started_at DESC
LIMIT 1;
SQL
)

    if [[ -z "$phase" ]]; then
        echo "NONE"
    else
        echo "$phase"
    fi
}

# Start a new phase for a task
start_phase() {
    local task_id="$1"
    local phase="$2"
    local db="${3:-$STATE_DB}"

    # Validate phase
    if [[ -z "${PHASE_CONFIG[$phase]:-}" ]]; then
        log_error "Invalid phase: $phase"
        return 1
    fi

    # Check if this is a valid transition
    local current_phase
    current_phase=$(get_current_phase "$task_id" "$db")

    if [[ "$current_phase" != "NONE" ]]; then
        local valid_next="${VALID_TRANSITIONS[$current_phase]:-}"
        if [[ ! " $valid_next " =~ " $phase " ]]; then
            log_error "Invalid phase transition: $current_phase -> $phase"
            log_error "Valid transitions from $current_phase: $valid_next"
            return 1
        fi

        # Close current phase as incomplete if transitioning back
        sqlite3 "$db" <<SQL
UPDATE task_phases
SET completed_at = datetime('now'),
    gate_status = 'BLOCKED'
WHERE task_id = '$(_sql_escape "$task_id")'
AND phase = '$current_phase'
AND completed_at IS NULL;
SQL
    fi

    # Start new phase
    sqlite3 "$db" <<SQL
INSERT INTO task_phases (task_id, phase, gate_status)
VALUES ('$(_sql_escape "$task_id")', '$phase', 'PENDING');
SQL

    log_info "Task $task_id started phase: $phase"

    # Emit event
    if declare -f emit_event >/dev/null; then
        emit_event "PHASE_STARTED" "$task_id" "{\"phase\":\"$phase\",\"previous\":\"$current_phase\"}"
    fi

    return 0
}

# Check if phase has required artifacts
check_phase_artifacts() {
    local task_id="$1"
    local phase="$2"
    local db="${3:-$STATE_DB}"

    local config="${PHASE_CONFIG[$phase]:-}"
    local required_artifacts=""

    # Parse required artifacts from config
    IFS='|' read -ra parts <<< "$config"
    for part in "${parts[@]}"; do
        if [[ "$part" == artifacts:* ]]; then
            required_artifacts="${part#artifacts:}"
            break
        fi
    done

    if [[ -z "$required_artifacts" ]]; then
        return 0  # No required artifacts
    fi

    # Check each required artifact
    local missing=()
    IFS=',' read -ra artifacts <<< "$required_artifacts"
    for artifact in "${artifacts[@]}"; do
        local count
        count=$(sqlite3 "$db" <<SQL
SELECT COUNT(*) FROM phase_artifacts
WHERE task_id = '$(_sql_escape "$task_id")'
AND phase = '$phase'
AND artifact_type = '$artifact';
SQL
)
        if [[ "$count" -eq 0 ]]; then
            missing+=("$artifact")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warn "Phase $phase missing artifacts: ${missing[*]}"
        return 1
    fi

    return 0
}

# Request phase gate approval
request_gate_approval() {
    local task_id="$1"
    local phase="$2"
    local db="${3:-$STATE_DB}"

    # First check artifacts
    if ! check_phase_artifacts "$task_id" "$phase" "$db"; then
        log_error "Cannot request gate approval: missing required artifacts"
        return 1
    fi

    # Get phase summary for review
    local summary
    summary=$(get_phase_summary "$task_id" "$phase" "$db")

    # Request approval from tri-supervisor
    if ! declare -f request_tri_supervisor_approval >/dev/null; then
        log_error "request_tri_supervisor_approval not defined. Load tri-supervisor.sh first."
        return 1
    fi

    local approval_result
    approval_result=$(request_tri_supervisor_approval "$task_id" "$phase" "$summary")

    local decision
    decision=$(echo "$approval_result" | jq -r '.decision // "ABSTAIN"')
    local consensus_count
    consensus_count=$(echo "$approval_result" | jq -r '.approvals // 0')

    if [[ "$decision" == "APPROVE" ]] && [[ "$consensus_count" -ge 2 ]]; then
        # Gate passed
        local approvers
        approvers=$(echo "$approval_result" | jq -c '.models // []')
        
        sqlite3 "$db" <<SQL
UPDATE task_phases
SET gate_status = 'PASSED',
    gate_approvers = '$approvers',
    completed_at = datetime('now')
WHERE task_id = '$(_sql_escape "$task_id")'
AND phase = '$phase';
SQL

        log_info "Phase gate PASSED for $task_id:$phase with $consensus_count approvals"
        if declare -f emit_event >/dev/null; then
            emit_event "PHASE_GATE_PASSED" "$task_id" "{\"phase\":\"$phase\",\"approvals\":$consensus_count}"
        fi
        return 0
    else
        # Gate failed
        local failures
        failures=$(echo "$approval_result" | jq -c '.failures // []')

        sqlite3 "$db" <<SQL
UPDATE task_phases
SET gate_status = 'FAILED',
    gate_failures = '$failures'
WHERE task_id = '$(_sql_escape "$task_id")'
AND phase = '$phase';
SQL

        log_warn "Phase gate FAILED for $task_id:$phase"
        if declare -f emit_event >/dev/null; then
            emit_event "PHASE_GATE_FAILED" "$task_id" "{\"phase\":\"$phase\",\"failures\":$failures}"
        fi
        return 1
    fi
}

# Get phase summary for review
get_phase_summary() {
    local task_id="$1"
    local phase="$2"
    local db="${3:-$STATE_DB}"

    # Get all artifacts for this phase
    local artifacts
    artifacts=$(sqlite3 -json "$db" <<SQL
SELECT artifact_type, artifact_path, validated, validation_score
FROM phase_artifacts
WHERE task_id = '$(_sql_escape "$task_id")'
AND phase = '$phase'
ORDER BY created_at;
SQL
)

    # Get phase timing
    local timing
    timing=$(sqlite3 -json "$db" <<SQL
SELECT started_at,
       CASE WHEN completed_at IS NULL
            THEN (strftime('%s','now') - strftime('%s', started_at))
            ELSE (strftime('%s', completed_at) - strftime('%s', started_at))
       END as duration_seconds
FROM task_phases
WHERE task_id = '$(_sql_escape "$task_id")'
AND phase = '$phase';
SQL
)

    cat <<EOF
{
    "task_id": "$task_id",
    "phase": "$phase",
    "artifacts": $artifacts,
    "timing": $timing
}
EOF
}

# Get next phase for a task
get_next_phase() {
    local current_phase="$1"

    local config="${PHASE_CONFIG[$current_phase]:-}"
    local next_phase=""

    IFS='|' read -ra parts <<< "$config"
    for part in "${parts[@]}"; do
        if [[ "$part" == next:* ]]; then
            next_phase="${part#next:}"
            break
        fi
    done

    echo "$next_phase"
}

# Transition to next phase
transition_to_next_phase() {
    local task_id="$1"
    local db="${2:-$STATE_DB}"

    local current_phase
    current_phase=$(get_current_phase "$task_id" "$db")

    if [[ "$current_phase" == "NONE" ]]; then
        # Start with brainstorm
        start_phase "$task_id" "BRAINSTORM" "$db"
        return $?
    fi

    # Check if current phase gate is passed
    local gate_status
    gate_status=$(sqlite3 "$db" <<SQL
SELECT gate_status FROM task_phases
WHERE task_id = '$(_sql_escape "$task_id")'
AND phase = '$current_phase'
AND completed_at IS NULL;
SQL
)

    if [[ "$gate_status" != "PASSED" ]]; then
        log_error "Cannot transition: current phase gate not passed (status: $gate_status)"
        return 1
    fi

    local next_phase
    next_phase=$(get_next_phase "$current_phase")

    if [[ -z "$next_phase" ]] || [[ "$next_phase" == "COMPLETE" ]]; then
        log_info "Task $task_id has completed all phases"
        if declare -f emit_event >/dev/null; then
            emit_event "TASK_PHASES_COMPLETE" "$task_id" "{}"
        fi
        return 0
    fi

    start_phase "$task_id" "$next_phase" "$db"
}

# Export functions
export -f init_phase_gate_schema
export -f get_current_phase
export -f start_phase
export -f check_phase_artifacts
export -f request_gate_approval
export -f get_phase_summary
export -f get_next_phase
export -f transition_to_next_phase
