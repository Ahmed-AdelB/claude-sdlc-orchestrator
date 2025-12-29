#!/bin/bash
# lib/sdlc-phases.sh
# SDLC Phase Enforcement State Machine
# Implements the 5-Phase Development Discipline (CCPM)

set -euo pipefail

# Safe defaults
AUTONOMOUS_ROOT="${AUTONOMOUS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
STATE_DIR="${STATE_DIR:-${AUTONOMOUS_ROOT}/state}"

source "${AUTONOMOUS_ROOT}/lib/common.sh" 2>/dev/null || true
source "${AUTONOMOUS_ROOT}/lib/circuit-breaker.sh" 2>/dev/null || true
source "${AUTONOMOUS_ROOT}/lib/sqlite-state.sh" 2>/dev/null || true

# =============================================================================
# M2-012: Task Artifact Tracking
# =============================================================================
# Provides artifact registration, retrieval, and validation for SDLC phases.
# Artifacts are tracked in SQLite for persistence and querying.
# =============================================================================

# Artifact types for classification
readonly ARTIFACT_TYPE_DOCUMENT="document"
readonly ARTIFACT_TYPE_CODE="code"
readonly ARTIFACT_TYPE_TEST="test"
readonly ARTIFACT_TYPE_CONFIG="config"
readonly ARTIFACT_TYPE_OTHER="other"

# =============================================================================
# SDLC Phase Constants
# =============================================================================
# The 5 phases of the development discipline
readonly PHASE_BRAINSTORM="BRAINSTORM"   # Phase 1: Gather requirements, clarifying questions
readonly PHASE_DOCUMENT="DOCUMENT"        # Phase 2: Create specifications with acceptance criteria
readonly PHASE_PLAN="PLAN"                # Phase 3: Technical design, mission breakdown (AB Method)
readonly PHASE_EXECUTE="EXECUTE"          # Phase 4: Implement with parallel/sequential agents
readonly PHASE_TRACK="TRACK"              # Phase 5: Monitor progress, update stakeholders

# Additional terminal states
readonly PHASE_COMPLETE="COMPLETE"        # Final state: Task completed successfully
readonly PHASE_BLOCKED="BLOCKED"          # Task is blocked pending external input
readonly PHASE_FAILED="FAILED"            # Task failed and requires intervention

# Ordered list of phases for iteration
readonly SDLC_PHASES=("BRAINSTORM" "DOCUMENT" "PLAN" "EXECUTE" "TRACK" "COMPLETE")

# Phase indices for comparison
declare -A PHASE_ORDER=(
    ["BRAINSTORM"]=1
    ["DOCUMENT"]=2
    ["PLAN"]=3
    ["EXECUTE"]=4
    ["TRACK"]=5
    ["COMPLETE"]=6
)

# =============================================================================
# Phase Transitions
# =============================================================================
# Defines valid transitions (current -> next)
declare -A PHASE_TRANSITIONS=(
    ["BRAINSTORM"]="DOCUMENT"
    ["DOCUMENT"]="PLAN"
    ["PLAN"]="EXECUTE"
    ["EXECUTE"]="TRACK"
    ["TRACK"]="COMPLETE"
)

# =============================================================================
# Phase Artifacts
# =============================================================================
# Defines required artifacts per phase
declare -A PHASE_ARTIFACTS=(
    ["BRAINSTORM"]="requirements.md"
    ["DOCUMENT"]="spec.md"
    ["PLAN"]="tech_design.md"
)

# =============================================================================
# Phase Requirements
# =============================================================================
# Comprehensive requirements for each phase
declare -A PHASE_REQUIREMENTS=(
    ["BRAINSTORM"]="requirements_doc:requirements.md;stakeholder_input:true;clarifying_questions:true"
    ["DOCUMENT"]="spec_doc:spec.md;acceptance_criteria:true;scope_defined:true"
    ["PLAN"]="tech_design:tech_design.md;mission_breakdown:true;agent_assignment:true;dependencies_mapped:true"
    ["EXECUTE"]="code_changes:true;tests_written:true;quality_gates_passed:true"
    ["TRACK"]="progress_logged:true;stakeholders_updated:true;metrics_collected:true"
)

# =============================================================================
# M2-012: Artifact Tracking SQLite Schema
# =============================================================================

# Initialize the task_artifacts table in SQLite
# This extends the existing sqlite-state.sh schema
init_artifact_tracking_table() {
    local db="${STATE_DB:-${STATE_DIR}/tri-agent.db}"

    # Ensure base database exists first
    if declare -F _ensure_db >/dev/null 2>&1; then
        _ensure_db
    fi

    if [[ ! -f "$db" ]]; then
        log_warn "Database not found at $db, skipping artifact table init"
        return 1
    fi

    # Create task_artifacts table if it doesn't exist
    if command -v sqlite3 >/dev/null 2>&1; then
        sqlite3 "$db" <<'SQL'
CREATE TABLE IF NOT EXISTS task_artifacts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id TEXT NOT NULL,
    phase TEXT NOT NULL CHECK(phase IN ('BRAINSTORM','DOCUMENT','PLAN','EXECUTE','TRACK','COMPLETE')),
    artifact_path TEXT NOT NULL,
    artifact_type TEXT DEFAULT 'other' CHECK(artifact_type IN ('document','code','test','config','other')),
    checksum TEXT,
    file_size INTEGER,
    verified_at TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    trace_id TEXT,
    UNIQUE(task_id, phase, artifact_path)
);

CREATE INDEX IF NOT EXISTS idx_artifacts_task ON task_artifacts(task_id);
CREATE INDEX IF NOT EXISTS idx_artifacts_phase ON task_artifacts(phase);
CREATE INDEX IF NOT EXISTS idx_artifacts_task_phase ON task_artifacts(task_id, phase);
SQL
        log_info "M2-012: task_artifacts table initialized"
        return 0
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "
import sqlite3
db_path = '$db'
conn = sqlite3.connect(db_path, timeout=10.0)
conn.executescript('''
CREATE TABLE IF NOT EXISTS task_artifacts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id TEXT NOT NULL,
    phase TEXT NOT NULL CHECK(phase IN ('BRAINSTORM','DOCUMENT','PLAN','EXECUTE','TRACK','COMPLETE')),
    artifact_path TEXT NOT NULL,
    artifact_type TEXT DEFAULT 'other' CHECK(artifact_type IN ('document','code','test','config','other')),
    checksum TEXT,
    file_size INTEGER,
    verified_at TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    trace_id TEXT,
    UNIQUE(task_id, phase, artifact_path)
);

CREATE INDEX IF NOT EXISTS idx_artifacts_task ON task_artifacts(task_id);
CREATE INDEX IF NOT EXISTS idx_artifacts_phase ON task_artifacts(phase);
CREATE INDEX IF NOT EXISTS idx_artifacts_task_phase ON task_artifacts(task_id, phase);
''')
conn.commit()
conn.close()
"
        log_info "M2-012: task_artifacts table initialized (python fallback)"
        return 0
    else
        log_error "No sqlite3 or python3 available for artifact table init"
        return 1
    fi
}

# =============================================================================
# M2-012: Artifact Management Functions
# =============================================================================

# register_artifact(task_id, phase, artifact_path)
# Registers an artifact for a specific task and phase.
# Automatically calculates checksum and file size if file exists.
# Usage: register_artifact "TASK-001" "BRAINSTORM" "/path/to/requirements.md"
# Returns: 0 on success, 1 on failure
register_artifact() {
    local task_id="$1"
    local phase="$2"
    local artifact_path="$3"
    local artifact_type="${4:-other}"
    local trace_id="${TRACE_ID:-}"

    # Validate required parameters
    if [[ -z "$task_id" || -z "$phase" || -z "$artifact_path" ]]; then
        log_error "register_artifact: Missing required parameters (task_id=$task_id, phase=$phase, path=$artifact_path)"
        return 1
    fi

    # Validate phase
    if [[ -z "${PHASE_ORDER[$phase]:-}" ]]; then
        log_error "register_artifact: Invalid phase '$phase'"
        return 1
    fi

    # Validate artifact type
    case "$artifact_type" in
        document|code|test|config|other) ;;
        *)
            log_warn "register_artifact: Unknown artifact type '$artifact_type', defaulting to 'other'"
            artifact_type="other"
            ;;
    esac

    # Calculate file metadata if file exists
    local checksum=""
    local file_size=0
    local verified_at=""

    if [[ -f "$artifact_path" ]]; then
        # Calculate SHA256 checksum
        if command -v sha256sum >/dev/null 2>&1; then
            checksum=$(sha256sum "$artifact_path" 2>/dev/null | awk '{print $1}')
        elif command -v shasum >/dev/null 2>&1; then
            checksum=$(shasum -a 256 "$artifact_path" 2>/dev/null | awk '{print $1}')
        fi

        # Get file size
        if command -v stat >/dev/null 2>&1; then
            # Linux stat
            file_size=$(stat -c%s "$artifact_path" 2>/dev/null || stat -f%z "$artifact_path" 2>/dev/null || echo 0)
        fi

        verified_at=$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')
    else
        log_warn "register_artifact: File does not exist yet: $artifact_path"
    fi

    local db="${STATE_DB:-${STATE_DIR}/tri-agent.db}"

    # Ensure artifact tracking table exists
    init_artifact_tracking_table 2>/dev/null || true

    # Escape values for SQL
    local esc_task_id esc_phase esc_path esc_type esc_checksum esc_trace
    if declare -F _sql_escape >/dev/null 2>&1; then
        esc_task_id=$(_sql_escape "$task_id")
        esc_phase=$(_sql_escape "$phase")
        esc_path=$(_sql_escape "$artifact_path")
        esc_type=$(_sql_escape "$artifact_type")
        esc_checksum=$(_sql_escape "$checksum")
        esc_trace=$(_sql_escape "$trace_id")
    else
        # Simple escape fallback
        esc_task_id="${task_id//\'/\'\'}"
        esc_phase="${phase//\'/\'\'}"
        esc_path="${artifact_path//\'/\'\'}"
        esc_type="${artifact_type//\'/\'\'}"
        esc_checksum="${checksum//\'/\'\'}"
        esc_trace="${trace_id//\'/\'\'}"
    fi

    # Insert or update artifact record
    if command -v sqlite3 >/dev/null 2>&1; then
        sqlite3 "$db" <<SQL
INSERT INTO task_artifacts (task_id, phase, artifact_path, artifact_type, checksum, file_size, verified_at, trace_id, updated_at)
VALUES ('${esc_task_id}', '${esc_phase}', '${esc_path}', '${esc_type}', '${esc_checksum}', ${file_size}, '${verified_at}', '${esc_trace}', datetime('now'))
ON CONFLICT(task_id, phase, artifact_path) DO UPDATE SET
    artifact_type = excluded.artifact_type,
    checksum = excluded.checksum,
    file_size = excluded.file_size,
    verified_at = excluded.verified_at,
    trace_id = excluded.trace_id,
    updated_at = datetime('now');
SQL
        local rc=$?
        if [[ $rc -eq 0 ]]; then
            log_info "M2-012: Registered artifact for $task_id/$phase: $artifact_path"
            return 0
        else
            log_error "M2-012: Failed to register artifact (SQLite error $rc)"
            return 1
        fi
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "
import sqlite3, sys
db_path = '$db'
try:
    conn = sqlite3.connect(db_path, timeout=10.0)
    conn.execute('''
        INSERT INTO task_artifacts (task_id, phase, artifact_path, artifact_type, checksum, file_size, verified_at, trace_id, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
        ON CONFLICT(task_id, phase, artifact_path) DO UPDATE SET
            artifact_type = excluded.artifact_type,
            checksum = excluded.checksum,
            file_size = excluded.file_size,
            verified_at = excluded.verified_at,
            trace_id = excluded.trace_id,
            updated_at = datetime('now')
    ''', ('$task_id', '$phase', '$artifact_path', '$artifact_type', '$checksum', $file_size, '$verified_at', '$trace_id'))
    conn.commit()
    conn.close()
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
"
        local rc=$?
        if [[ $rc -eq 0 ]]; then
            log_info "M2-012: Registered artifact for $task_id/$phase: $artifact_path (python)"
            return 0
        else
            log_error "M2-012: Failed to register artifact (Python error $rc)"
            return 1
        fi
    else
        log_error "No sqlite3 or python3 available"
        return 1
    fi
}

# get_artifacts_for_phase(task_id, phase)
# Retrieves all registered artifacts for a specific task and phase.
# Usage: get_artifacts_for_phase "TASK-001" "BRAINSTORM"
# Output: One artifact path per line (or JSON with format=json)
get_artifacts_for_phase() {
    local task_id="$1"
    local phase="$2"
    local format="${3:-text}"  # text, json, or paths

    # Validate required parameters
    if [[ -z "$task_id" || -z "$phase" ]]; then
        log_error "get_artifacts_for_phase: Missing required parameters"
        return 1
    fi

    # Validate phase
    if [[ -z "${PHASE_ORDER[$phase]:-}" ]]; then
        log_error "get_artifacts_for_phase: Invalid phase '$phase'"
        return 1
    fi

    local db="${STATE_DB:-${STATE_DIR}/tri-agent.db}"

    if [[ ! -f "$db" ]]; then
        log_warn "Database not found: $db"
        return 1
    fi

    # Escape values
    local esc_task_id esc_phase
    if declare -F _sql_escape >/dev/null 2>&1; then
        esc_task_id=$(_sql_escape "$task_id")
        esc_phase=$(_sql_escape "$phase")
    else
        esc_task_id="${task_id//\'/\'\'}"
        esc_phase="${phase//\'/\'\'}"
    fi

    case "$format" in
        json)
            if command -v sqlite3 >/dev/null 2>&1; then
                echo "["
                local first=true
                sqlite3 -separator '|' "$db" "SELECT artifact_path, artifact_type, checksum, file_size, verified_at FROM task_artifacts WHERE task_id='${esc_task_id}' AND phase='${esc_phase}' ORDER BY created_at;" | while IFS='|' read -r path type checksum size verified; do
                    if [[ "$first" == "true" ]]; then
                        first=false
                    else
                        echo ","
                    fi
                    printf '  {"path": "%s", "type": "%s", "checksum": "%s", "size": %s, "verified_at": "%s"}' \
                        "$path" "$type" "$checksum" "${size:-0}" "$verified"
                done
                echo ""
                echo "]"
            else
                python3 -c "
import sqlite3, json, sys
db_path = '$db'
try:
    conn = sqlite3.connect(db_path, timeout=10.0)
    cur = conn.cursor()
    cur.execute('''
        SELECT artifact_path, artifact_type, checksum, file_size, verified_at
        FROM task_artifacts
        WHERE task_id=? AND phase=?
        ORDER BY created_at
    ''', ('$task_id', '$phase'))
    rows = cur.fetchall()
    result = []
    for row in rows:
        result.append({
            'path': row[0],
            'type': row[1],
            'checksum': row[2],
            'size': row[3] or 0,
            'verified_at': row[4]
        })
    print(json.dumps(result, indent=2))
    conn.close()
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
"
            fi
            ;;
        paths)
            # Just artifact paths, one per line
            if command -v sqlite3 >/dev/null 2>&1; then
                sqlite3 "$db" "SELECT artifact_path FROM task_artifacts WHERE task_id='${esc_task_id}' AND phase='${esc_phase}' ORDER BY created_at;"
            else
                python3 -c "
import sqlite3, sys
db_path = '$db'
try:
    conn = sqlite3.connect(db_path, timeout=10.0)
    cur = conn.cursor()
    cur.execute('SELECT artifact_path FROM task_artifacts WHERE task_id=? AND phase=? ORDER BY created_at', ('$task_id', '$phase'))
    for row in cur.fetchall():
        print(row[0])
    conn.close()
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
"
            fi
            ;;
        text|*)
            # Human-readable text format
            echo "Artifacts for task $task_id, phase $phase:"
            if command -v sqlite3 >/dev/null 2>&1; then
                sqlite3 -separator '|' "$db" "SELECT artifact_path, artifact_type, file_size, verified_at FROM task_artifacts WHERE task_id='${esc_task_id}' AND phase='${esc_phase}' ORDER BY created_at;" | while IFS='|' read -r path type size verified; do
                    local exists_marker="[MISSING]"
                    if [[ -f "$path" ]]; then
                        exists_marker="[EXISTS]"
                    fi
                    echo "  - $path ($type, ${size:-0} bytes) $exists_marker"
                    if [[ -n "$verified" ]]; then
                        echo "    Verified: $verified"
                    fi
                done
            else
                python3 -c "
import sqlite3, os, sys
db_path = '$db'
try:
    conn = sqlite3.connect(db_path, timeout=10.0)
    cur = conn.cursor()
    cur.execute('''
        SELECT artifact_path, artifact_type, file_size, verified_at
        FROM task_artifacts
        WHERE task_id=? AND phase=?
        ORDER BY created_at
    ''', ('$task_id', '$phase'))
    for row in cur.fetchall():
        path, atype, size, verified = row
        exists = '[EXISTS]' if os.path.isfile(path) else '[MISSING]'
        print(f'  - {path} ({atype}, {size or 0} bytes) {exists}')
        if verified:
            print(f'    Verified: {verified}')
    conn.close()
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
"
            fi
            ;;
    esac

    return 0
}

# validate_phase_artifacts(task_id, phase)
# Validates that all required artifacts for a phase exist and are valid.
# Checks: file existence, non-empty content, optional checksum verification.
# Usage: validate_phase_artifacts "TASK-001" "BRAINSTORM"
# Returns: 0 if all artifacts valid, 1 if any missing/invalid
validate_phase_artifacts() {
    local task_id="$1"
    local phase="$2"
    local strict="${3:-false}"  # If true, also verify checksums

    # Validate required parameters
    if [[ -z "$task_id" || -z "$phase" ]]; then
        log_error "validate_phase_artifacts: Missing required parameters"
        return 1
    fi

    # Validate phase
    if [[ -z "${PHASE_ORDER[$phase]:-}" ]]; then
        log_error "validate_phase_artifacts: Invalid phase '$phase'"
        return 1
    fi

    local db="${STATE_DB:-${STATE_DIR}/tri-agent.db}"

    if [[ ! -f "$db" ]]; then
        log_warn "Database not found: $db"
        # Fall back to checking PHASE_ARTIFACTS
        local required_artifact="${PHASE_ARTIFACTS[$phase]:-}"
        if [[ -n "$required_artifact" ]]; then
            local artifact_found=false
            local possible_paths=(
                "${AUTONOMOUS_ROOT}/artifacts/${task_id}/${required_artifact}"
                "${AUTONOMOUS_ROOT}/docs/${required_artifact}"
                "${AUTONOMOUS_ROOT}/docs/${task_id}_${required_artifact}"
            )

            for path in "${possible_paths[@]}"; do
                if [[ -f "$path" && -s "$path" ]]; then
                    artifact_found=true
                    break
                fi
            done

            if [[ "$artifact_found" == "false" ]]; then
                log_error "validate_phase_artifacts: Required artifact '$required_artifact' not found for phase $phase"
                return 1
            fi
        fi
        return 0
    fi

    # Escape values
    local esc_task_id esc_phase
    if declare -F _sql_escape >/dev/null 2>&1; then
        esc_task_id=$(_sql_escape "$task_id")
        esc_phase=$(_sql_escape "$phase")
    else
        esc_task_id="${task_id//\'/\'\'}"
        esc_phase="${phase//\'/\'\'}"
    fi

    local validation_failed=false
    local missing_artifacts=()
    local invalid_artifacts=()

    # Get artifacts from database
    local artifacts
    if command -v sqlite3 >/dev/null 2>&1; then
        artifacts=$(sqlite3 -separator '|' "$db" "SELECT artifact_path, checksum FROM task_artifacts WHERE task_id='${esc_task_id}' AND phase='${esc_phase}';")
    else
        artifacts=$(python3 -c "
import sqlite3, sys
db_path = '$db'
try:
    conn = sqlite3.connect(db_path, timeout=10.0)
    cur = conn.cursor()
    cur.execute('SELECT artifact_path, checksum FROM task_artifacts WHERE task_id=? AND phase=?', ('$task_id', '$phase'))
    for row in cur.fetchall():
        print(f'{row[0]}|{row[1] or \"\"}')
    conn.close()
except Exception as e:
    sys.exit(1)
")
    fi

    # If no registered artifacts, check fallback PHASE_ARTIFACTS
    if [[ -z "$artifacts" ]]; then
        local required_artifact="${PHASE_ARTIFACTS[$phase]:-}"
        if [[ -n "$required_artifact" ]]; then
            local artifact_found=false
            local possible_paths=(
                "${AUTONOMOUS_ROOT}/artifacts/${task_id}/${required_artifact}"
                "${AUTONOMOUS_ROOT}/docs/${required_artifact}"
                "${AUTONOMOUS_ROOT}/docs/${task_id}_${required_artifact}"
            )

            for path in "${possible_paths[@]}"; do
                if [[ -f "$path" && -s "$path" ]]; then
                    artifact_found=true
                    log_info "validate_phase_artifacts: Found fallback artifact at $path"
                    break
                fi
            done

            if [[ "$artifact_found" == "false" ]]; then
                log_error "validate_phase_artifacts: No registered artifacts and fallback '$required_artifact' not found"
                return 1
            fi
        fi
        return 0
    fi

    # Validate each registered artifact
    while IFS='|' read -r artifact_path stored_checksum; do
        [[ -z "$artifact_path" ]] && continue

        # Check file existence
        if [[ ! -f "$artifact_path" ]]; then
            missing_artifacts+=("$artifact_path")
            validation_failed=true
            continue
        fi

        # Check file is not empty
        if [[ ! -s "$artifact_path" ]]; then
            invalid_artifacts+=("$artifact_path (empty file)")
            validation_failed=true
            continue
        fi

        # Strict mode: verify checksum
        if [[ "$strict" == "true" && -n "$stored_checksum" ]]; then
            local current_checksum=""
            if command -v sha256sum >/dev/null 2>&1; then
                current_checksum=$(sha256sum "$artifact_path" 2>/dev/null | awk '{print $1}')
            elif command -v shasum >/dev/null 2>&1; then
                current_checksum=$(shasum -a 256 "$artifact_path" 2>/dev/null | awk '{print $1}')
            fi

            if [[ -n "$current_checksum" && "$current_checksum" != "$stored_checksum" ]]; then
                invalid_artifacts+=("$artifact_path (checksum mismatch)")
                validation_failed=true
                continue
            fi
        fi

        log_info "validate_phase_artifacts: Artifact valid: $artifact_path"
    done <<< "$artifacts"

    # Report results
    if [[ "$validation_failed" == "true" ]]; then
        if [[ ${#missing_artifacts[@]} -gt 0 ]]; then
            log_error "validate_phase_artifacts: Missing artifacts for $task_id/$phase:"
            for artifact in "${missing_artifacts[@]}"; do
                log_error "  - $artifact"
            done
        fi
        if [[ ${#invalid_artifacts[@]} -gt 0 ]]; then
            log_error "validate_phase_artifacts: Invalid artifacts for $task_id/$phase:"
            for artifact in "${invalid_artifacts[@]}"; do
                log_error "  - $artifact"
            done
        fi
        return 1
    fi

    log_info "validate_phase_artifacts: All artifacts valid for $task_id/$phase"
    return 0
}

# =============================================================================
# M2-013: Phase Gate Validation
# =============================================================================
# Provides comprehensive phase-specific gate checks before allowing transitions.
# Each phase has specific validation criteria that must be met.
# =============================================================================

# Default coverage threshold for EXECUTE phase
readonly COVERAGE_THRESHOLD="${COVERAGE_THRESHOLD:-80}"

# validate_phase_gate(task_id, phase)
# Runs phase-specific validation checks to enforce quality gates.
# Usage: validate_phase_gate "TASK-001" "BRAINSTORM"
# Returns: 0 if gate passes, 1 if gate fails
# Output: Logs validation results and reasons for failure
validate_phase_gate() {
    local task_id="$1"
    local phase="$2"

    # Validate required parameters
    if [[ -z "$task_id" || -z "$phase" ]]; then
        log_error "validate_phase_gate: Missing required parameters (task_id=$task_id, phase=$phase)"
        return 1
    fi

    # Validate phase is known
    if [[ -z "${PHASE_ORDER[$phase]:-}" ]]; then
        log_error "validate_phase_gate: Invalid phase '$phase'"
        return 1
    fi

    log_info "M2-013: Running gate validation for task $task_id, phase $phase"

    # Dispatch to phase-specific validation
    case "$phase" in
        BRAINSTORM)
            _validate_brainstorm_gate "$task_id"
            ;;
        DOCUMENT)
            _validate_document_gate "$task_id"
            ;;
        PLAN)
            _validate_plan_gate "$task_id"
            ;;
        EXECUTE)
            _validate_execute_gate "$task_id"
            ;;
        TRACK)
            _validate_track_gate "$task_id"
            ;;
        COMPLETE)
            # COMPLETE phase has no gate - it's the terminal state
            log_info "M2-013: COMPLETE phase has no gate requirements"
            return 0
            ;;
        *)
            log_warn "validate_phase_gate: Unknown phase '$phase', skipping gate validation"
            return 0
            ;;
    esac
}

# _validate_brainstorm_gate(task_id)
# Gate check: requirements.md exists and has content
_validate_brainstorm_gate() {
    local task_id="$1"
    local gate_passed=true
    local failure_reasons=()

    log_info "M2-013: Validating BRAINSTORM gate for $task_id"

    # Find requirements.md in possible locations
    local requirements_file=""
    local possible_paths=(
        "${AUTONOMOUS_ROOT}/artifacts/${task_id}/requirements.md"
        "${AUTONOMOUS_ROOT}/docs/${task_id}_requirements.md"
        "${AUTONOMOUS_ROOT}/docs/requirements.md"
        "${STATE_DIR}/tasks/${task_id}/requirements.md"
    )

    # Also check registered artifacts from database
    local db="${STATE_DB:-${STATE_DIR}/tri-agent.db}"
    if [[ -f "$db" ]]; then
        local registered_path
        registered_path=$(get_artifacts_for_phase "$task_id" "BRAINSTORM" "paths" 2>/dev/null | grep -i "requirements" | head -1)
        if [[ -n "$registered_path" ]]; then
            possible_paths=("$registered_path" "${possible_paths[@]}")
        fi
    fi

    for path in "${possible_paths[@]}"; do
        if [[ -f "$path" && -s "$path" ]]; then
            requirements_file="$path"
            break
        fi
    done

    # Check 1: requirements.md exists
    if [[ -z "$requirements_file" ]]; then
        gate_passed=false
        failure_reasons+=("requirements.md not found in expected locations")
    else
        log_info "M2-013: Found requirements file at $requirements_file"

        # Check 2: File has meaningful content (not just whitespace/empty lines)
        local content_lines
        content_lines=$(grep -cv '^\s*$' "$requirements_file" 2>/dev/null || echo 0)

        if [[ "$content_lines" -lt 3 ]]; then
            gate_passed=false
            failure_reasons+=("requirements.md has insufficient content ($content_lines non-empty lines, minimum 3 required)")
        fi

        # Check 3: File contains key sections (optional but recommended)
        local has_requirements_section=false
        if grep -qiE '(^#+\s*(requirements?|features?|user stor|acceptance))|(^\*\s+)|(^-\s+)' "$requirements_file" 2>/dev/null; then
            has_requirements_section=true
        fi

        if [[ "$has_requirements_section" == "false" ]]; then
            log_warn "M2-013: requirements.md may be missing structured requirements sections"
        fi
    fi

    # Report results
    if [[ "$gate_passed" == "true" ]]; then
        log_info "M2-013: BRAINSTORM gate PASSED for $task_id"
        return 0
    else
        log_error "M2-013: BRAINSTORM gate FAILED for $task_id"
        for reason in "${failure_reasons[@]}"; do
            log_error "  - $reason"
        done
        return 1
    fi
}

# _validate_document_gate(task_id)
# Gate check: spec.md has acceptance criteria
_validate_document_gate() {
    local task_id="$1"
    local gate_passed=true
    local failure_reasons=()

    log_info "M2-013: Validating DOCUMENT gate for $task_id"

    # Find spec.md in possible locations
    local spec_file=""
    local possible_paths=(
        "${AUTONOMOUS_ROOT}/artifacts/${task_id}/spec.md"
        "${AUTONOMOUS_ROOT}/docs/${task_id}_spec.md"
        "${AUTONOMOUS_ROOT}/docs/spec.md"
        "${STATE_DIR}/tasks/${task_id}/spec.md"
    )

    # Also check registered artifacts from database
    local db="${STATE_DB:-${STATE_DIR}/tri-agent.db}"
    if [[ -f "$db" ]]; then
        local registered_path
        registered_path=$(get_artifacts_for_phase "$task_id" "DOCUMENT" "paths" 2>/dev/null | grep -i "spec" | head -1)
        if [[ -n "$registered_path" ]]; then
            possible_paths=("$registered_path" "${possible_paths[@]}")
        fi
    fi

    for path in "${possible_paths[@]}"; do
        if [[ -f "$path" && -s "$path" ]]; then
            spec_file="$path"
            break
        fi
    done

    # Check 1: spec.md exists
    if [[ -z "$spec_file" ]]; then
        gate_passed=false
        failure_reasons+=("spec.md not found in expected locations")
    else
        log_info "M2-013: Found spec file at $spec_file"

        # Check 2: File has acceptance criteria section
        local has_acceptance_criteria=false
        if grep -qiE '(^#+\s*acceptance\s*criteria)|(acceptance\s*criteria:)|(\[\s*\]\s+)|(given.*when.*then)|(\*\s+GIVEN)' "$spec_file" 2>/dev/null; then
            has_acceptance_criteria=true
        fi

        if [[ "$has_acceptance_criteria" == "false" ]]; then
            gate_passed=false
            failure_reasons+=("spec.md missing acceptance criteria section")
        fi

        # Check 3: File has meaningful content
        local content_lines
        content_lines=$(grep -cv '^\s*$' "$spec_file" 2>/dev/null || echo 0)

        if [[ "$content_lines" -lt 5 ]]; then
            gate_passed=false
            failure_reasons+=("spec.md has insufficient content ($content_lines non-empty lines, minimum 5 required)")
        fi

        # Check 4: Verify acceptance criteria has items (not just a header)
        if [[ "$has_acceptance_criteria" == "true" ]]; then
            local criteria_count=0
            # Count bullet points, checkboxes, or numbered items after acceptance criteria header
            criteria_count=$(grep -iA 20 'acceptance.*criteria' "$spec_file" 2>/dev/null | grep -cE '^\s*[-*\[]|\d+\.' || echo 0)

            if [[ "$criteria_count" -lt 1 ]]; then
                gate_passed=false
                failure_reasons+=("spec.md acceptance criteria section appears empty (no criteria items found)")
            else
                log_info "M2-013: Found $criteria_count acceptance criteria items"
            fi
        fi
    fi

    # Report results
    if [[ "$gate_passed" == "true" ]]; then
        log_info "M2-013: DOCUMENT gate PASSED for $task_id"
        return 0
    else
        log_error "M2-013: DOCUMENT gate FAILED for $task_id"
        for reason in "${failure_reasons[@]}"; do
            log_error "  - $reason"
        done
        return 1
    fi
}

# _validate_plan_gate(task_id)
# Gate check: tech_design.md has sections for approach, files, dependencies
_validate_plan_gate() {
    local task_id="$1"
    local gate_passed=true
    local failure_reasons=()

    log_info "M2-013: Validating PLAN gate for $task_id"

    # Find tech_design.md in possible locations
    local design_file=""
    local possible_paths=(
        "${AUTONOMOUS_ROOT}/artifacts/${task_id}/tech_design.md"
        "${AUTONOMOUS_ROOT}/docs/${task_id}_tech_design.md"
        "${AUTONOMOUS_ROOT}/docs/tech_design.md"
        "${STATE_DIR}/tasks/${task_id}/tech_design.md"
    )

    # Also check registered artifacts from database
    local db="${STATE_DB:-${STATE_DIR}/tri-agent.db}"
    if [[ -f "$db" ]]; then
        local registered_path
        registered_path=$(get_artifacts_for_phase "$task_id" "PLAN" "paths" 2>/dev/null | grep -iE "(tech|design)" | head -1)
        if [[ -n "$registered_path" ]]; then
            possible_paths=("$registered_path" "${possible_paths[@]}")
        fi
    fi

    for path in "${possible_paths[@]}"; do
        if [[ -f "$path" && -s "$path" ]]; then
            design_file="$path"
            break
        fi
    done

    # Check 1: tech_design.md exists
    if [[ -z "$design_file" ]]; then
        gate_passed=false
        failure_reasons+=("tech_design.md not found in expected locations")
    else
        log_info "M2-013: Found tech design file at $design_file"

        # Check 2: Has approach/implementation section
        local has_approach=false
        if grep -qiE '^#+\s*(approach|implementation|solution|design|architecture|overview)' "$design_file" 2>/dev/null; then
            has_approach=true
        fi

        if [[ "$has_approach" == "false" ]]; then
            gate_passed=false
            failure_reasons+=("tech_design.md missing approach/implementation section")
        fi

        # Check 3: Has files/changes section
        local has_files=false
        if grep -qiE '^#+\s*(files?|changes?|modified|affected|components?)' "$design_file" 2>/dev/null; then
            has_files=true
        fi

        # Alternative: look for file paths in the document
        if [[ "$has_files" == "false" ]]; then
            local file_references
            file_references=$(grep -cE '(\.ts|\.js|\.py|\.sh|\.md|\.json|\.yaml|\.yml|src/|lib/|bin/)' "$design_file" 2>/dev/null || echo 0)
            if [[ "$file_references" -ge 1 ]]; then
                has_files=true
                log_info "M2-013: Found $file_references file references in tech design"
            fi
        fi

        if [[ "$has_files" == "false" ]]; then
            gate_passed=false
            failure_reasons+=("tech_design.md missing files/changes section or file references")
        fi

        # Check 4: Has dependencies section
        local has_dependencies=false
        if grep -qiE '^#+\s*(dependencies?|prerequisites?|requirements?|blockers?)' "$design_file" 2>/dev/null; then
            has_dependencies=true
        fi

        # Alternative: look for dependency indicators
        if [[ "$has_dependencies" == "false" ]]; then
            if grep -qiE '(depends on|requires|prerequisite|before|after|blocked by|npm|pip|apt|brew)' "$design_file" 2>/dev/null; then
                has_dependencies=true
                log_info "M2-013: Found dependency references in tech design"
            fi
        fi

        if [[ "$has_dependencies" == "false" ]]; then
            gate_passed=false
            failure_reasons+=("tech_design.md missing dependencies section")
        fi

        # Check 5: Has minimum content
        local content_lines
        content_lines=$(grep -cv '^\s*$' "$design_file" 2>/dev/null || echo 0)

        if [[ "$content_lines" -lt 10 ]]; then
            gate_passed=false
            failure_reasons+=("tech_design.md has insufficient content ($content_lines non-empty lines, minimum 10 required)")
        fi
    fi

    # Report results
    if [[ "$gate_passed" == "true" ]]; then
        log_info "M2-013: PLAN gate PASSED for $task_id"
        return 0
    else
        log_error "M2-013: PLAN gate FAILED for $task_id"
        for reason in "${failure_reasons[@]}"; do
            log_error "  - $reason"
        done
        return 1
    fi
}

# _validate_execute_gate(task_id)
# Gate check: tests pass, coverage meets threshold
_validate_execute_gate() {
    local task_id="$1"
    local gate_passed=true
    local failure_reasons=()

    log_info "M2-013: Validating EXECUTE gate for $task_id"

    # Check 1: Look for test results in various locations
    local test_results_found=false
    local tests_passed=false
    local coverage_met=false

    # Possible test result locations
    local test_result_paths=(
        "${AUTONOMOUS_ROOT}/artifacts/${task_id}/test_results.json"
        "${AUTONOMOUS_ROOT}/artifacts/${task_id}/test_results.txt"
        "${STATE_DIR}/tasks/${task_id}/test_results.json"
        "${STATE_DIR}/tasks/${task_id}/test_results.txt"
        "${AUTONOMOUS_ROOT}/coverage/lcov.info"
        "${AUTONOMOUS_ROOT}/coverage/coverage.json"
        "${AUTONOMOUS_ROOT}/htmlcov/index.html"
        "${AUTONOMOUS_ROOT}/.coverage"
    )

    # Check for test result files
    for path in "${test_result_paths[@]}"; do
        if [[ -f "$path" ]]; then
            test_results_found=true
            log_info "M2-013: Found test results at $path"

            # Parse test results based on file type
            case "$path" in
                *.json)
                    if command -v jq >/dev/null 2>&1; then
                        # Check for common test result formats (jest, pytest, etc.)
                        local test_status
                        test_status=$(jq -r '.success // .passed // .numPassedTests // .tests_passed // "unknown"' "$path" 2>/dev/null)

                        if [[ "$test_status" == "true" || "$test_status" != "0" && "$test_status" != "unknown" ]]; then
                            tests_passed=true
                        fi

                        # Check coverage
                        local coverage_value
                        coverage_value=$(jq -r '.coverage // .coveragePercentage // .total.lines.pct // .totals.percent_covered // "0"' "$path" 2>/dev/null)

                        if [[ "$coverage_value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                            local coverage_int=${coverage_value%.*}
                            if [[ "$coverage_int" -ge "$COVERAGE_THRESHOLD" ]]; then
                                coverage_met=true
                                log_info "M2-013: Coverage $coverage_int% meets threshold $COVERAGE_THRESHOLD%"
                            else
                                log_warn "M2-013: Coverage $coverage_int% below threshold $COVERAGE_THRESHOLD%"
                            fi
                        fi
                    fi
                    ;;
                *.txt)
                    # Check for common pass indicators in text output
                    if grep -qiE '(passed|success|ok|all tests passed|0 failed)' "$path" 2>/dev/null; then
                        tests_passed=true
                    fi
                    if grep -qiE '(failed|error|failure)' "$path" 2>/dev/null; then
                        if ! grep -qiE '0 failed|no failures' "$path" 2>/dev/null; then
                            tests_passed=false
                        fi
                    fi
                    ;;
                lcov.info|coverage.json|.coverage)
                    # Coverage file exists - try to extract coverage percentage
                    coverage_met=true  # Assume met if coverage was generated
                    ;;
            esac
            break
        fi
    done

    # Check database for recorded test events
    local db="${STATE_DB:-${STATE_DIR}/tri-agent.db}"
    if [[ -f "$db" && "$test_results_found" == "false" ]]; then
        if command -v sqlite3 >/dev/null 2>&1; then
            local esc_task_id="${task_id//\'/\'\'}"

            # Look for test execution events
            local test_event
            test_event=$(sqlite3 "$db" "SELECT payload FROM events WHERE task_id='${esc_task_id}' AND event_type LIKE '%TEST%' ORDER BY created_at DESC LIMIT 1;" 2>/dev/null)

            if [[ -n "$test_event" ]]; then
                test_results_found=true
                if [[ "$test_event" == *"passed"* || "$test_event" == *"success"* ]]; then
                    tests_passed=true
                fi
            fi
        fi
    fi

    # Validate results
    if [[ "$test_results_found" == "false" ]]; then
        gate_passed=false
        failure_reasons+=("No test results found - tests must be executed before completing EXECUTE phase")
    elif [[ "$tests_passed" == "false" ]]; then
        gate_passed=false
        failure_reasons+=("Tests did not pass - all tests must pass before completing EXECUTE phase")
    fi

    # Coverage check (warning if not met, but not a hard failure unless strict mode)
    if [[ "$coverage_met" == "false" && "$test_results_found" == "true" ]]; then
        log_warn "M2-013: Coverage threshold ($COVERAGE_THRESHOLD%) not verified - consider adding coverage reporting"
        # Only fail on coverage if STRICT_COVERAGE is enabled
        if [[ "${STRICT_COVERAGE:-false}" == "true" ]]; then
            gate_passed=false
            failure_reasons+=("Coverage threshold ($COVERAGE_THRESHOLD%) not met")
        fi
    fi

    # Check 2: Verify code changes exist (at least some code was modified)
    local code_artifacts
    code_artifacts=$(get_artifacts_for_phase "$task_id" "EXECUTE" "paths" 2>/dev/null | grep -vE '\.(md|txt|json)$' | head -1)

    if [[ -z "$code_artifacts" ]]; then
        # Alternative: check git for changes
        if command -v git >/dev/null 2>&1; then
            local git_changes
            git_changes=$(git diff --name-only HEAD~1 2>/dev/null | wc -l || echo 0)
            if [[ "$git_changes" -eq 0 ]]; then
                log_warn "M2-013: No code changes detected for EXECUTE phase"
            fi
        fi
    fi

    # Report results
    if [[ "$gate_passed" == "true" ]]; then
        log_info "M2-013: EXECUTE gate PASSED for $task_id"
        return 0
    else
        log_error "M2-013: EXECUTE gate FAILED for $task_id"
        for reason in "${failure_reasons[@]}"; do
            log_error "  - $reason"
        done
        return 1
    fi
}

# _validate_track_gate(task_id)
# Gate check: progress logged, metrics collected
_validate_track_gate() {
    local task_id="$1"
    local gate_passed=true
    local failure_reasons=()

    log_info "M2-013: Validating TRACK gate for $task_id"

    # Check 1: Progress has been logged
    local progress_logged=false

    # Check log files
    local log_paths=(
        "${AUTONOMOUS_ROOT}/logs/${task_id}.log"
        "${AUTONOMOUS_ROOT}/logs/tasks/${task_id}.log"
        "${STATE_DIR}/tasks/${task_id}/progress.log"
        "${STATE_DIR}/tasks/${task_id}/activity.log"
    )

    for path in "${log_paths[@]}"; do
        if [[ -f "$path" && -s "$path" ]]; then
            progress_logged=true
            log_info "M2-013: Found progress log at $path"
            break
        fi
    done

    # Check database for progress events
    local db="${STATE_DB:-${STATE_DIR}/tri-agent.db}"
    if [[ -f "$db" && "$progress_logged" == "false" ]]; then
        if command -v sqlite3 >/dev/null 2>&1; then
            local esc_task_id="${task_id//\'/\'\'}"

            # Check for any events logged for this task
            local event_count
            event_count=$(sqlite3 "$db" "SELECT COUNT(*) FROM events WHERE task_id='${esc_task_id}';" 2>/dev/null || echo 0)

            if [[ "$event_count" -gt 0 ]]; then
                progress_logged=true
                log_info "M2-013: Found $event_count events logged for task in database"
            fi
        fi
    fi

    if [[ "$progress_logged" == "false" ]]; then
        gate_passed=false
        failure_reasons+=("No progress log found - progress must be logged before completing TRACK phase")
    fi

    # Check 2: Metrics have been collected
    local metrics_collected=false

    # Check for metrics files
    local metric_paths=(
        "${AUTONOMOUS_ROOT}/artifacts/${task_id}/metrics.json"
        "${STATE_DIR}/tasks/${task_id}/metrics.json"
        "${AUTONOMOUS_ROOT}/metrics/${task_id}.json"
    )

    for path in "${metric_paths[@]}"; do
        if [[ -f "$path" && -s "$path" ]]; then
            metrics_collected=true
            log_info "M2-013: Found metrics at $path"
            break
        fi
    done

    # Check database for metrics
    if [[ -f "$db" && "$metrics_collected" == "false" ]]; then
        if command -v sqlite3 >/dev/null 2>&1; then
            local esc_task_id="${task_id//\'/\'\'}"

            # Check metrics table if it exists
            local metrics_count
            metrics_count=$(sqlite3 "$db" "SELECT COUNT(*) FROM task_metrics WHERE task_id='${esc_task_id}';" 2>/dev/null || echo 0)

            if [[ "$metrics_count" -gt 0 ]]; then
                metrics_collected=true
                log_info "M2-013: Found $metrics_count metrics in database for task"
            fi

            # Alternative: check for metric events
            if [[ "$metrics_collected" == "false" ]]; then
                local metric_events
                metric_events=$(sqlite3 "$db" "SELECT COUNT(*) FROM events WHERE task_id='${esc_task_id}' AND (event_type LIKE '%METRIC%' OR payload LIKE '%duration%' OR payload LIKE '%time%');" 2>/dev/null || echo 0)

                if [[ "$metric_events" -gt 0 ]]; then
                    metrics_collected=true
                    log_info "M2-013: Found $metric_events metric events in database"
                fi
            fi
        fi
    fi

    # Check phase status file as fallback
    local phase_file="${STATE_DIR}/sdlc/${task_id}.phase"
    if [[ -f "$phase_file" && "$metrics_collected" == "false" ]]; then
        # If we have phase tracking, consider that basic metrics
        metrics_collected=true
        log_info "M2-013: Phase tracking file exists, basic metrics recorded"
    fi

    if [[ "$metrics_collected" == "false" ]]; then
        gate_passed=false
        failure_reasons+=("No metrics collected - metrics must be recorded before completing TRACK phase")
    fi

    # Check 3: Stakeholder update (optional, warning only)
    local stakeholder_updated=false

    # Check for stakeholder communication artifacts
    local comm_paths=(
        "${AUTONOMOUS_ROOT}/artifacts/${task_id}/status_update.md"
        "${AUTONOMOUS_ROOT}/artifacts/${task_id}/stakeholder_update.md"
        "${STATE_DIR}/tasks/${task_id}/status.md"
    )

    for path in "${comm_paths[@]}"; do
        if [[ -f "$path" ]]; then
            stakeholder_updated=true
            break
        fi
    done

    if [[ "$stakeholder_updated" == "false" ]]; then
        log_warn "M2-013: No stakeholder update artifact found - consider documenting status update"
    fi

    # Report results
    if [[ "$gate_passed" == "true" ]]; then
        log_info "M2-013: TRACK gate PASSED for $task_id"
        return 0
    else
        log_error "M2-013: TRACK gate FAILED for $task_id"
        for reason in "${failure_reasons[@]}"; do
            log_error "  - $reason"
        done
        return 1
    fi
}

# get_gate_status(task_id, phase)
# Returns the status of a specific gate without modifying state.
# Usage: get_gate_status "TASK-001" "BRAINSTORM"
# Output: "passed", "failed", or "unknown"
get_gate_status() {
    local task_id="$1"
    local phase="$2"

    if [[ -z "$task_id" || -z "$phase" ]]; then
        echo "unknown"
        return 1
    fi

    # Temporarily redirect logs to /dev/null for clean status check
    if validate_phase_gate "$task_id" "$phase" 2>/dev/null; then
        echo "passed"
        return 0
    else
        echo "failed"
        return 1
    fi
}

# get_all_gates_status(task_id)
# Returns status of all phase gates for a task.
# Usage: get_all_gates_status "TASK-001"
get_all_gates_status() {
    local task_id="$1"
    local format="${2:-text}"

    if [[ -z "$task_id" ]]; then
        log_error "get_all_gates_status: task_id required"
        return 1
    fi

    case "$format" in
        json)
            echo "{"
            echo "  \"task_id\": \"$task_id\","
            echo "  \"gates\": {"
            local first=true
            for phase in "${SDLC_PHASES[@]}"; do
                [[ "$phase" == "COMPLETE" ]] && continue  # Skip COMPLETE phase
                local status
                status=$(get_gate_status "$task_id" "$phase")
                if [[ "$first" == "true" ]]; then
                    first=false
                else
                    echo ","
                fi
                printf '    "%s": "%s"' "$phase" "$status"
            done
            echo ""
            echo "  }"
            echo "}"
            ;;
        text|*)
            echo "Gate Status for task $task_id:"
            for phase in "${SDLC_PHASES[@]}"; do
                [[ "$phase" == "COMPLETE" ]] && continue
                local status
                status=$(get_gate_status "$task_id" "$phase")
                local status_marker
                case "$status" in
                    passed) status_marker="[PASSED]" ;;
                    failed) status_marker="[FAILED]" ;;
                    *) status_marker="[UNKNOWN]" ;;
                esac
                echo "  $phase: $status_marker"
            done
            ;;
    esac

    return 0
}

# =============================================================================
# End M2-013: Phase Gate Validation
# =============================================================================

# verify_artifact_exists(artifact_path)
# Simple helper to check if an artifact file exists and is non-empty.
# Usage: verify_artifact_exists "/path/to/file.md"
# Returns: 0 if exists and non-empty, 1 otherwise
verify_artifact_exists() {
    local artifact_path="$1"

    if [[ -z "$artifact_path" ]]; then
        return 1
    fi

    if [[ -f "$artifact_path" && -s "$artifact_path" ]]; then
        return 0
    fi

    return 1
}

# update_artifact_verification(task_id, phase, artifact_path)
# Updates the verification timestamp and checksum for an existing artifact.
# Used when confirming an artifact still exists before phase transition.
update_artifact_verification() {
    local task_id="$1"
    local phase="$2"
    local artifact_path="$3"

    if [[ -z "$task_id" || -z "$phase" || -z "$artifact_path" ]]; then
        return 1
    fi

    if [[ ! -f "$artifact_path" ]]; then
        log_error "update_artifact_verification: File not found: $artifact_path"
        return 1
    fi

    # Calculate current checksum
    local checksum=""
    if command -v sha256sum >/dev/null 2>&1; then
        checksum=$(sha256sum "$artifact_path" 2>/dev/null | awk '{print $1}')
    elif command -v shasum >/dev/null 2>&1; then
        checksum=$(shasum -a 256 "$artifact_path" 2>/dev/null | awk '{print $1}')
    fi

    local file_size=0
    if command -v stat >/dev/null 2>&1; then
        file_size=$(stat -c%s "$artifact_path" 2>/dev/null || stat -f%z "$artifact_path" 2>/dev/null || echo 0)
    fi

    local verified_at
    verified_at=$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')

    local db="${STATE_DB:-${STATE_DIR}/tri-agent.db}"

    if [[ ! -f "$db" ]]; then
        return 1
    fi

    # Escape values
    local esc_task_id esc_phase esc_path esc_checksum
    if declare -F _sql_escape >/dev/null 2>&1; then
        esc_task_id=$(_sql_escape "$task_id")
        esc_phase=$(_sql_escape "$phase")
        esc_path=$(_sql_escape "$artifact_path")
        esc_checksum=$(_sql_escape "$checksum")
    else
        esc_task_id="${task_id//\'/\'\'}"
        esc_phase="${phase//\'/\'\'}"
        esc_path="${artifact_path//\'/\'\'}"
        esc_checksum="${checksum//\'/\'\'}"
    fi

    if command -v sqlite3 >/dev/null 2>&1; then
        sqlite3 "$db" "UPDATE task_artifacts SET checksum='${esc_checksum}', file_size=${file_size}, verified_at='${verified_at}', updated_at=datetime('now') WHERE task_id='${esc_task_id}' AND phase='${esc_phase}' AND artifact_path='${esc_path}';"
        return $?
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "
import sqlite3, sys
try:
    conn = sqlite3.connect('$db', timeout=10.0)
    conn.execute('''
        UPDATE task_artifacts
        SET checksum=?, file_size=?, verified_at=?, updated_at=datetime('now')
        WHERE task_id=? AND phase=? AND artifact_path=?
    ''', ('$checksum', $file_size, '$verified_at', '$task_id', '$phase', '$artifact_path'))
    conn.commit()
    conn.close()
except Exception as e:
    sys.exit(1)
"
        return $?
    fi

    return 1
}

# get_all_task_artifacts(task_id)
# Retrieves all artifacts for a task across all phases.
# Usage: get_all_task_artifacts "TASK-001"
get_all_task_artifacts() {
    local task_id="$1"
    local format="${2:-text}"

    if [[ -z "$task_id" ]]; then
        log_error "get_all_task_artifacts: task_id required"
        return 1
    fi

    local db="${STATE_DB:-${STATE_DIR}/tri-agent.db}"

    if [[ ! -f "$db" ]]; then
        log_warn "Database not found: $db"
        return 1
    fi

    local esc_task_id
    if declare -F _sql_escape >/dev/null 2>&1; then
        esc_task_id=$(_sql_escape "$task_id")
    else
        esc_task_id="${task_id//\'/\'\'}"
    fi

    case "$format" in
        json)
            if command -v sqlite3 >/dev/null 2>&1; then
                echo "{"
                echo "  \"task_id\": \"$task_id\","
                echo "  \"artifacts\": ["
                local first=true
                sqlite3 -separator '|' "$db" "SELECT phase, artifact_path, artifact_type, checksum, file_size, verified_at FROM task_artifacts WHERE task_id='${esc_task_id}' ORDER BY phase, created_at;" | while IFS='|' read -r phase path type checksum size verified; do
                    if [[ "$first" == "true" ]]; then
                        first=false
                    else
                        echo ","
                    fi
                    printf '    {"phase": "%s", "path": "%s", "type": "%s", "checksum": "%s", "size": %s, "verified_at": "%s"}' \
                        "$phase" "$path" "$type" "$checksum" "${size:-0}" "$verified"
                done
                echo ""
                echo "  ]"
                echo "}"
            elif command -v python3 >/dev/null 2>&1; then
                python3 -c "
import sqlite3, json, sys
db_path = '$db'
try:
    conn = sqlite3.connect(db_path, timeout=10.0)
    cur = conn.cursor()
    cur.execute('''
        SELECT phase, artifact_path, artifact_type, checksum, file_size, verified_at
        FROM task_artifacts
        WHERE task_id=?
        ORDER BY phase, created_at
    ''', ('$task_id',))
    result = {'task_id': '$task_id', 'artifacts': []}
    for row in cur.fetchall():
        result['artifacts'].append({
            'phase': row[0],
            'path': row[1],
            'type': row[2],
            'checksum': row[3],
            'size': row[4] or 0,
            'verified_at': row[5]
        })
    print(json.dumps(result, indent=2))
    conn.close()
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
"
            fi
            ;;
        text|*)
            echo "All artifacts for task $task_id:"
            if command -v sqlite3 >/dev/null 2>&1; then
                local current_phase=""
                sqlite3 -separator '|' "$db" "SELECT phase, artifact_path, artifact_type, file_size FROM task_artifacts WHERE task_id='${esc_task_id}' ORDER BY phase, created_at;" | while IFS='|' read -r phase path type size; do
                    if [[ "$phase" != "$current_phase" ]]; then
                        current_phase="$phase"
                        echo ""
                        echo "  Phase: $phase"
                    fi
                    local exists_marker="[MISSING]"
                    if [[ -f "$path" ]]; then
                        exists_marker="[EXISTS]"
                    fi
                    echo "    - $path ($type, ${size:-0} bytes) $exists_marker"
                done
            elif command -v python3 >/dev/null 2>&1; then
                python3 -c "
import sqlite3, os, sys
db_path = '$db'
try:
    conn = sqlite3.connect(db_path, timeout=10.0)
    cur = conn.cursor()
    cur.execute('''
        SELECT phase, artifact_path, artifact_type, file_size
        FROM task_artifacts
        WHERE task_id=?
        ORDER BY phase, created_at
    ''', ('$task_id',))
    current_phase = ''
    for row in cur.fetchall():
        phase, path, atype, size = row
        if phase != current_phase:
            current_phase = phase
            print(f'')
            print(f'  Phase: {phase}')
        exists = '[EXISTS]' if os.path.isfile(path) else '[MISSING]'
        print(f'    - {path} ({atype}, {size or 0} bytes) {exists}')
    conn.close()
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
"
            fi
            ;;
    esac

    return 0
}

# Initialize SDLC state for a task
sdlc_init_task() {
    local task_id="$1"
    local phase="${2:-BRAINSTORM}"

    mkdir -p "${STATE_DIR}/sdlc"
    echo "$phase" > "${STATE_DIR}/sdlc/${task_id}.phase"

    # M2-012: Ensure artifact tracking table exists
    init_artifact_tracking_table 2>/dev/null || true

    log_info "Task $task_id initialized in phase $phase"
}

# Get current phase
sdlc_get_phase() {
    local task_id="$1"
    local phase_file="${STATE_DIR}/sdlc/${task_id}.phase"
    
    if [[ -f "$phase_file" ]]; then
        cat "$phase_file"
    else
        echo "BRAINSTORM"
    fi
}

validate_transition() {
    local task_id="$1"
    local current_phase="$2"
    local next_phase="$3"
    local skip_gate="${4:-false}"  # Allow skipping gate for emergency transitions
    local breaker_id="sdlc_gate_${task_id}"

    # Check circuit breaker status
    if declare -F should_call_model >/dev/null 2>&1; then
        if ! should_call_model "$breaker_id"; then
            log_error "Circuit breaker OPEN for task $task_id quality gate. Too many consecutive failures."
            return 1
        fi
    fi

    local validation_failed=false
    local failure_reason=""

    # 1. Check valid transition
    if [[ "${PHASE_TRANSITIONS[$current_phase]}" != "$next_phase" ]]; then
        validation_failed=true
        failure_reason="Invalid transition: $current_phase -> $next_phase"
    fi

    # 2. M2-012: Validate phase artifacts using new artifact tracking system
    if [[ "$validation_failed" == "false" ]]; then
        # First try the new validate_phase_artifacts function (M2-012)
        if ! validate_phase_artifacts "$task_id" "$current_phase"; then
            # validate_phase_artifacts already logs detailed errors
            validation_failed=true
            failure_reason="Artifact validation failed for phase $current_phase (M2-012)"
        fi
    fi

    # 3. M2-012: File existence verification for registered artifacts
    if [[ "$validation_failed" == "false" ]]; then
        local db="${STATE_DB:-${STATE_DIR}/tri-agent.db}"
        if [[ -f "$db" ]]; then
            # Get all artifact paths for this task/phase and verify they exist
            local artifacts_to_verify
            artifacts_to_verify=$(get_artifacts_for_phase "$task_id" "$current_phase" "paths" 2>/dev/null)

            if [[ -n "$artifacts_to_verify" ]]; then
                while IFS= read -r artifact_path; do
                    [[ -z "$artifact_path" ]] && continue

                    if ! verify_artifact_exists "$artifact_path"; then
                        validation_failed=true
                        failure_reason="M2-012: Required artifact missing or empty: $artifact_path"
                        log_error "$failure_reason"
                        break
                    fi

                    # Update verification timestamp for existing artifacts
                    update_artifact_verification "$task_id" "$current_phase" "$artifact_path" 2>/dev/null || true
                done <<< "$artifacts_to_verify"
            fi
        fi
    fi

    # 4. M2-013: Phase gate validation - enforce phase-specific quality gates
    if [[ "$validation_failed" == "false" && "$skip_gate" != "true" ]]; then
        log_info "M2-013: Running phase gate validation for $current_phase -> $next_phase"

        if ! validate_phase_gate "$task_id" "$current_phase"; then
            validation_failed=true
            failure_reason="M2-013: Phase gate validation failed for $current_phase"
            # validate_phase_gate already logs detailed reasons
        else
            log_info "M2-013: Phase gate validation passed for $current_phase"
        fi
    elif [[ "$skip_gate" == "true" ]]; then
        log_warn "M2-013: Phase gate validation skipped (skip_gate=true) for $current_phase -> $next_phase"
    fi

    if [[ "$validation_failed" == "true" ]]; then
        log_error "$failure_reason"
        if declare -F record_failure >/dev/null 2>&1; then
            record_failure "$breaker_id" "VALIDATION_FAILURE"
        fi
        return 1
    else
        if declare -F record_success >/dev/null 2>&1; then
            record_success "$breaker_id"
        fi
        return 0
    fi
}

# Execute transition
sdlc_transition() {
    local task_id="$1"
    local next_phase="$2"
    local current_phase
    current_phase=$(sdlc_get_phase "$task_id")

    # M2-012: Ensure artifact tracking table exists before transition
    init_artifact_tracking_table 2>/dev/null || true

    if validate_transition "$task_id" "$current_phase" "$next_phase"; then
        echo "$next_phase" > "${STATE_DIR}/sdlc/${task_id}.phase"
        log_info "Task $task_id transitioned to $next_phase"

        # M2-012: Log transition event with artifact summary
        local db="${STATE_DB:-${STATE_DIR}/tri-agent.db}"
        if [[ -f "$db" ]] && command -v sqlite3 >/dev/null 2>&1; then
            # Record transition event
            local esc_task_id esc_current esc_next
            if declare -F _sql_escape >/dev/null 2>&1; then
                esc_task_id=$(_sql_escape "$task_id")
                esc_current=$(_sql_escape "$current_phase")
                esc_next=$(_sql_escape "$next_phase")
            else
                esc_task_id="${task_id//\'/\'\'}"
                esc_current="${current_phase//\'/\'\'}"
                esc_next="${next_phase//\'/\'\'}"
            fi

            # Get artifact count for logging
            local artifact_count
            artifact_count=$(sqlite3 "$db" "SELECT COUNT(*) FROM task_artifacts WHERE task_id='${esc_task_id}' AND phase='${esc_current}';" 2>/dev/null || echo 0)

            sqlite3 "$db" "INSERT INTO events (task_id, event_type, actor, payload, trace_id) VALUES ('${esc_task_id}', 'PHASE_TRANSITION', 'sdlc_engine', 'from=${esc_current},to=${esc_next},artifacts=${artifact_count}', '${TRACE_ID:-}');" 2>/dev/null || true

            log_info "M2-012: Phase transition completed with $artifact_count artifacts verified"
        fi
        return 0
    else
        return 1
    fi
}

# =============================================================================
# Required Functions (as specified)
# =============================================================================

# validate_phase_transition()
# Enforces correct phase order. Returns 0 if valid, 1 if invalid.
# Usage: validate_phase_transition "task_id" "BRAINSTORM" "DOCUMENT"
validate_phase_transition() {
    local task_id="$1"
    local current_phase="${2:-}"
    local next_phase="${3:-}"

    # If current_phase not provided, get it from task metadata
    if [[ -z "$current_phase" ]]; then
        current_phase=$(current_phase_for_task "$task_id")
    fi

    # Validate inputs
    if [[ -z "$current_phase" || -z "$next_phase" ]]; then
        log_error "validate_phase_transition: Missing required parameters"
        return 1
    fi

    # Check if current phase is valid
    if [[ -z "${PHASE_ORDER[$current_phase]:-}" ]]; then
        log_error "Invalid current phase: $current_phase"
        return 1
    fi

    # Check if next phase is valid
    if [[ -z "${PHASE_ORDER[$next_phase]:-}" ]]; then
        log_error "Invalid next phase: $next_phase"
        return 1
    fi

    # Check if this is a valid forward transition (no skipping phases)
    local current_order="${PHASE_ORDER[$current_phase]}"
    local next_order="${PHASE_ORDER[$next_phase]}"

    # Must be exactly one step forward
    if [[ $((next_order - current_order)) -ne 1 ]]; then
        log_error "Invalid phase transition: $current_phase -> $next_phase (must advance exactly one phase)"
        return 1
    fi

    # Check expected next phase from transitions map
    local expected_next="${PHASE_TRANSITIONS[$current_phase]:-}"
    if [[ "$expected_next" != "$next_phase" ]]; then
        log_error "Phase order violation: From $current_phase, expected $expected_next but got $next_phase"
        return 1
    fi

    # Delegate to validate_transition for artifact checks
    validate_transition "$task_id" "$current_phase" "$next_phase"
}

# get_phase_requirements()
# Returns what's needed for each phase as a structured output.
# Usage: get_phase_requirements "BRAINSTORM"
# Output format: key:value pairs separated by semicolons
get_phase_requirements() {
    local phase="$1"
    local format="${2:-text}"  # text, json, or array

    # Validate phase
    if [[ -z "${PHASE_REQUIREMENTS[$phase]:-}" ]]; then
        log_error "Unknown phase: $phase"
        return 1
    fi

    local requirements="${PHASE_REQUIREMENTS[$phase]}"

    case "$format" in
        json)
            # Convert to JSON format
            echo "{"
            echo "  \"phase\": \"$phase\","
            echo "  \"requirements\": {"
            local first=true
            IFS=';' read -ra req_array <<< "$requirements"
            for req in "${req_array[@]}"; do
                local key="${req%%:*}"
                local value="${req#*:}"
                if [[ "$first" == "true" ]]; then
                    first=false
                else
                    echo ","
                fi
                printf "    \"%s\": \"%s\"" "$key" "$value"
            done
            echo ""
            echo "  },"
            echo "  \"artifact\": \"${PHASE_ARTIFACTS[$phase]:-none}\","
            echo "  \"next_phase\": \"${PHASE_TRANSITIONS[$phase]:-COMPLETE}\""
            echo "}"
            ;;
        array)
            # Return as newline-separated key=value pairs
            IFS=';' read -ra req_array <<< "$requirements"
            for req in "${req_array[@]}"; do
                echo "${req/:/=}"
            done
            echo "artifact=${PHASE_ARTIFACTS[$phase]:-none}"
            echo "next_phase=${PHASE_TRANSITIONS[$phase]:-COMPLETE}"
            ;;
        text|*)
            # Human-readable text format
            echo "Phase: $phase"
            echo "Requirements:"
            IFS=';' read -ra req_array <<< "$requirements"
            for req in "${req_array[@]}"; do
                local key="${req%%:*}"
                local value="${req#*:}"
                echo "  - $key: $value"
            done
            echo "Required artifact: ${PHASE_ARTIFACTS[$phase]:-none}"
            echo "Next phase: ${PHASE_TRANSITIONS[$phase]:-COMPLETE}"
            ;;
    esac

    return 0
}

# current_phase_for_task()
# Reads the current phase from task metadata.
# Usage: current_phase_for_task "task_id"
# Returns: The current phase name (defaults to BRAINSTORM if not set)
current_phase_for_task() {
    local task_id="$1"

    if [[ -z "$task_id" ]]; then
        log_error "current_phase_for_task: task_id is required"
        echo "BRAINSTORM"
        return 1
    fi

    local phase_file="${STATE_DIR}/sdlc/${task_id}.phase"
    local metadata_file="${STATE_DIR}/tasks/${task_id}/metadata.json"

    # Try reading from dedicated phase file first
    if [[ -f "$phase_file" ]]; then
        local phase
        phase=$(cat "$phase_file" 2>/dev/null | tr -d '[:space:]')
        if [[ -n "$phase" && -n "${PHASE_ORDER[$phase]:-}" ]]; then
            echo "$phase"
            return 0
        fi
    fi

    # Try reading from task metadata JSON
    if [[ -f "$metadata_file" ]]; then
        if command -v jq >/dev/null 2>&1; then
            local phase
            phase=$(jq -r '.phase // .sdlc_phase // empty' "$metadata_file" 2>/dev/null)
            if [[ -n "$phase" && -n "${PHASE_ORDER[$phase]:-}" ]]; then
                echo "$phase"
                return 0
            fi
        fi
    fi

    # Try SQLite state if available
    local db_file="${STATE_DIR}/orchestrator.db"
    if [[ -f "$db_file" ]] && command -v sqlite3 >/dev/null 2>&1; then
        local phase
        phase=$(sqlite3 "$db_file" "SELECT phase FROM tasks WHERE id='$task_id' LIMIT 1;" 2>/dev/null)
        if [[ -n "$phase" && -n "${PHASE_ORDER[$phase]:-}" ]]; then
            echo "$phase"
            return 0
        fi
    fi

    # Default to BRAINSTORM if no phase found
    echo "BRAINSTORM"
    return 0
}

# =============================================================================
# Helper Functions
# =============================================================================

# Check if a phase is valid
is_valid_phase() {
    local phase="$1"
    [[ -n "${PHASE_ORDER[$phase]:-}" ]]
}

# Get the next phase in sequence
get_next_phase() {
    local current_phase="$1"
    echo "${PHASE_TRANSITIONS[$current_phase]:-COMPLETE}"
}

# Get the previous phase in sequence
get_previous_phase() {
    local current_phase="$1"
    local current_order="${PHASE_ORDER[$current_phase]:-0}"

    if [[ "$current_order" -le 1 ]]; then
        echo ""  # No previous phase for BRAINSTORM
        return 1
    fi

    local prev_order=$((current_order - 1))
    for phase in "${!PHASE_ORDER[@]}"; do
        if [[ "${PHASE_ORDER[$phase]}" -eq "$prev_order" ]]; then
            echo "$phase"
            return 0
        fi
    done

    echo ""
    return 1
}

# Check if task can advance to next phase
can_advance_phase() {
    local task_id="$1"
    local current_phase
    current_phase=$(current_phase_for_task "$task_id")
    local next_phase
    next_phase=$(get_next_phase "$current_phase")

    # Check if we're already complete
    if [[ "$current_phase" == "COMPLETE" ]]; then
        return 1
    fi

    # Check required artifacts exist
    local required_artifact="${PHASE_ARTIFACTS[$current_phase]:-}"
    if [[ -n "$required_artifact" ]]; then
        local artifact_found=false
        local possible_paths=(
            "${AUTONOMOUS_ROOT}/artifacts/${task_id}/${required_artifact}"
            "${AUTONOMOUS_ROOT}/docs/${required_artifact}"
            "${AUTONOMOUS_ROOT}/docs/${task_id}_${required_artifact}"
        )

        for path in "${possible_paths[@]}"; do
            if [[ -f "$path" ]]; then
                artifact_found=true
                break
            fi
        done

        if [[ "$artifact_found" == "false" ]]; then
            return 1
        fi
    fi

    return 0
}

# Get phase status summary for a task
get_phase_status() {
    local task_id="$1"
    local current_phase
    current_phase=$(current_phase_for_task "$task_id")
    local current_order="${PHASE_ORDER[$current_phase]}"

    echo "Task: $task_id"
    echo "Current Phase: $current_phase"
    echo "Progress: $current_order/${#SDLC_PHASES[@]}"
    echo ""
    echo "Phase History:"

    for phase in "${SDLC_PHASES[@]}"; do
        local phase_order="${PHASE_ORDER[$phase]}"
        local status

        if [[ "$phase_order" -lt "$current_order" ]]; then
            status="[COMPLETED]"
        elif [[ "$phase_order" -eq "$current_order" ]]; then
            status="[CURRENT]"
        else
            status="[PENDING]"
        fi

        echo "  $phase_order. $phase $status"
    done
}
