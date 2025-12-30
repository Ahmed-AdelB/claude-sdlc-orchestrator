#!/bin/bash
# =============================================================================
# tri-supervisor.sh - Multi-Model Consensus Approval Engine
# =============================================================================
# Implements tri-agent supervision for autonomous operation:
#   - Claude Opus: Architecture validation, security review
#   - Codex GPT-5.2: Implementation verification, code quality
#   - Gemini 3 Pro: Large context analysis, documentation review
#
# Consensus rules:
#   - APPROVE: Requires 2+ approvals with confidence >= 0.7
#   - REJECT: Any single rejection with confidence >= 0.9
#   - REQUEST_CHANGES: Single request triggers changes cycle
#   - ABSTAIN: Model cannot make determination (doesn't count)
# =============================================================================

: "${STATE_DIR:=$HOME/.claude/autonomous/state}"
: "${STATE_DB:=$STATE_DIR/tri-agent.db}"
: "${BIN_DIR:=$HOME/.claude/autonomous/bin}"
: "${LIB_DIR:=$HOME/.claude/autonomous/lib}"

# Source common utilities
if [[ -f "${LIB_DIR}/common.sh" ]]; then
    source "${LIB_DIR}/common.sh"
else
    echo "Warning: common.sh not found in ${LIB_DIR}" >&2
fi

# Consensus configuration
CONSENSUS_APPROVAL_THRESHOLD=2
CONSENSUS_MIN_CONFIDENCE=0.7
CONSENSUS_REJECT_CONFIDENCE=0.9
CONSENSUS_TIMEOUT_SECONDS=300

# =============================================================================
# JSON Validation Functions (SEC-009-1 Fix)
# =============================================================================

# Validate model response JSON structure
# Returns 0 if valid, 1 if invalid
# Sets global VALIDATION_ERROR with error message on failure
validate_model_response_json() {
    local json_string="$1"
    VALIDATION_ERROR=""

    # Check if jq is available
    if ! command -v jq >/dev/null 2>&1; then
        VALIDATION_ERROR="jq not found - cannot validate JSON"
        return 1
    fi

    # Check if input is valid JSON
    if ! echo "$json_string" | jq -e . >/dev/null 2>&1; then
        VALIDATION_ERROR="Invalid JSON structure"
        return 1
    fi

    # Check for required fields
    local decision confidence
    decision=$(echo "$json_string" | jq -r '.decision // empty' 2>/dev/null)
    confidence=$(echo "$json_string" | jq -r '.confidence // empty' 2>/dev/null)

    if [[ -z "$decision" ]]; then
        VALIDATION_ERROR="Missing required field: decision"
        return 1
    fi

    # Validate decision is one of allowed values
    case "$decision" in
        APPROVE|REJECT|ABSTAIN|REQUEST_CHANGES)
            ;;
        *)
            VALIDATION_ERROR="Invalid decision value: '$decision'. Must be APPROVE, REJECT, ABSTAIN, or REQUEST_CHANGES"
            return 1
            ;;
    esac

    # Validate confidence if present (not strictly required for ABSTAIN)
    if [[ -n "$confidence" ]]; then
        # Check if confidence is a valid number
        if ! echo "$confidence" | grep -qE '^-?[0-9]*\.?[0-9]+$'; then
            VALIDATION_ERROR="Invalid confidence value: '$confidence'. Must be a number"
            return 1
        fi

        # Check confidence range (0.0 to 1.0)
        local in_range
        in_range=$(echo "$confidence >= 0 && $confidence <= 1" | bc -l 2>/dev/null || echo 0)
        if [[ "$in_range" != "1" ]]; then
            VALIDATION_ERROR="Confidence out of range: '$confidence'. Must be between 0.0 and 1.0"
            return 1
        fi
    fi

    return 0
}

# Validate vote JSON from temp file
# Returns 0 if valid, 1 if invalid
validate_vote_json() {
    local json_string="$1"
    VALIDATION_ERROR=""

    # Check if jq is available
    if ! command -v jq >/dev/null 2>&1; then
        VALIDATION_ERROR="jq not found - cannot validate JSON"
        return 1
    fi

    # Check if input is valid JSON
    if ! echo "$json_string" | jq -e . >/dev/null 2>&1; then
        VALIDATION_ERROR="Invalid JSON structure in vote file"
        return 1
    fi

    # Extract and validate required fields
    local model decision confidence
    model=$(echo "$json_string" | jq -r '.model // empty' 2>/dev/null)
    decision=$(echo "$json_string" | jq -r '.decision // empty' 2>/dev/null)
    confidence=$(echo "$json_string" | jq -r '.confidence // empty' 2>/dev/null)

    # Validate model field
    if [[ -z "$model" ]]; then
        VALIDATION_ERROR="Missing required field: model"
        return 1
    fi

    # Validate model is one of expected values
    case "$model" in
        claude|codex|gemini)
            ;;
        *)
            VALIDATION_ERROR="Invalid model value: '$model'. Must be claude, codex, or gemini"
            return 1
            ;;
    esac

    # Validate decision field
    if [[ -z "$decision" ]]; then
        VALIDATION_ERROR="Missing required field: decision"
        return 1
    fi

    case "$decision" in
        APPROVE|REJECT|ABSTAIN|REQUEST_CHANGES)
            ;;
        *)
            VALIDATION_ERROR="Invalid decision value: '$decision'. Must be APPROVE, REJECT, ABSTAIN, or REQUEST_CHANGES"
            return 1
            ;;
    esac

    # Validate confidence is a number in range
    if [[ -z "$confidence" ]]; then
        VALIDATION_ERROR="Missing required field: confidence"
        return 1
    fi

    if ! echo "$confidence" | grep -qE '^-?[0-9]*\.?[0-9]+$'; then
        VALIDATION_ERROR="Invalid confidence value: '$confidence'. Must be a number"
        return 1
    fi

    local in_range
    in_range=$(echo "$confidence >= 0 && $confidence <= 1" | bc -l 2>/dev/null || echo 0)
    if [[ "$in_range" != "1" ]]; then
        VALIDATION_ERROR="Confidence out of range: '$confidence'. Must be between 0.0 and 1.0"
        return 1
    fi

    return 0
}

# Model roles for different review types
declare -A MODEL_ROLES=(
    [ARCHITECTURE]="claude gemini"
    [SECURITY]="claude codex"
    [IMPLEMENTATION]="codex claude"
    [DOCUMENTATION]="gemini claude"
    [TESTING]="codex gemini"
    [LARGE_CONTEXT]="gemini claude"
    [DEFAULT]="claude codex gemini"
)

# =============================================================================
# Consensus Schema
# =============================================================================

init_consensus_schema() {
    local db="${1:-$STATE_DB}"

    if ! command -v sqlite3 >/dev/null 2>&1; then
        echo "Error: sqlite3 not found" >&2
        return 1
    fi

    sqlite3 "$db" <<SQL
-- Consensus requests table
CREATE TABLE IF NOT EXISTS consensus_requests (
    id TEXT PRIMARY KEY,
    task_id TEXT NOT NULL,
    review_type TEXT NOT NULL,
    subject TEXT NOT NULL,  -- What is being reviewed
    context TEXT,           -- Full context/artifacts JSON
    status TEXT DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'IN_PROGRESS', 'APPROVED', 'REJECTED', 'CHANGES_REQUESTED', 'TIMEOUT', 'ERROR')),
    final_decision TEXT,
    approvals INTEGER DEFAULT 0,
    rejections INTEGER DEFAULT 0,
    abstentions INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now')),
    completed_at TEXT,
    timeout_at TEXT
);

-- Individual model votes
CREATE TABLE IF NOT EXISTS consensus_votes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    request_id TEXT NOT NULL,
    model TEXT NOT NULL,
    decision TEXT CHECK (decision IN ('APPROVE', 'REJECT', 'ABSTAIN', 'REQUEST_CHANGES')),
    confidence REAL,
    reasoning TEXT,
    required_changes TEXT,
    latency_ms INTEGER,
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (request_id) REFERENCES consensus_requests(id),
    UNIQUE(request_id, model)
);

CREATE INDEX IF NOT EXISTS idx_consensus_task ON consensus_requests(task_id);
CREATE INDEX IF NOT EXISTS idx_consensus_votes_request ON consensus_votes(request_id);
SQL
}

# =============================================================================
# Consensus Functions
# =============================================================================

# Generate consensus request ID
generate_request_id() {
    echo "cons-$(date +%Y%m%d%H%M%S)-$$-$RANDOM"
}

# Request tri-supervisor approval
request_tri_supervisor_approval() {
    local task_id="$1"
    local review_type="${2:-DEFAULT}"
    local context="$3"
    local db="${4:-$STATE_DB}"

    local request_id
    request_id=$(generate_request_id)

    local timeout_at
    if date --version >/dev/null 2>&1; then
        timeout_at=$(date -d "+${CONSENSUS_TIMEOUT_SECONDS} seconds" -Iseconds 2>/dev/null || date -Iseconds)
    else
        timeout_at=$(date -v+${CONSENSUS_TIMEOUT_SECONDS}S -Iseconds 2>/dev/null || date -Iseconds)
    fi

    # Create consensus request
    sqlite3 "$db" <<SQL
INSERT INTO consensus_requests (id, task_id, review_type, subject, context, status, timeout_at)
VALUES ('$(_sql_escape "$request_id")', '$(_sql_escape "$task_id")', '$(_sql_escape "$review_type")', '$(_sql_escape "$task_id")', '$(_sql_escape "$context")', 'PENDING', '$(_sql_escape "$timeout_at")');
SQL

    log_info "Created consensus request $request_id for task $task_id (type: $review_type)"

    # Get models for this review type
    local models="${MODEL_ROLES[$review_type]:-${MODEL_ROLES[DEFAULT]}}"

    # Update status to IN_PROGRESS
    sqlite3 "$db" <<SQL
UPDATE consensus_requests SET status = 'IN_PROGRESS' WHERE id = '$(_sql_escape "$request_id")';
SQL

    # Collect votes from each model in parallel
    local temp_dir
    temp_dir=$(mktemp -d)
    local pids=()

    for model in $models; do
        (
            local vote_result
            vote_result=$(collect_model_vote "$request_id" "$model" "$task_id" "$review_type" "$context" "$db")
            echo "$vote_result" > "${temp_dir}/${model}.json"
        ) &
        pids+=($!)
    done

    # Wait for all votes with timeout
    local wait_start
    wait_start=$(date +%s)
    for pid in "${pids[@]}"; do
        local now
        now=$(date +%s)
        local elapsed=$((now - wait_start))
        local remaining=$((CONSENSUS_TIMEOUT_SECONDS - elapsed))
        
        if [[ $remaining -le 0 ]]; then
            kill "$pid" 2>/dev/null || true
        else
            # Simple wait with timeout logic
            # 'timeout' command might not be available or behave differently
            if command -v timeout >/dev/null 2>&1; then
                timeout "$remaining" tail --pid="$pid" -f /dev/null 2>/dev/null || true
            else
                wait "$pid" 2>/dev/null || true
            fi
        fi
    done
    wait 2>/dev/null || true

    # Aggregate votes
    local approvals=0
    local rejections=0
    local abstentions=0
    local changes_requested=0
    local vote_models=()
    local failures=()

    for model in $models; do
        if [[ -f "${temp_dir}/${model}.json" ]]; then
            local vote
            vote=$(cat "${temp_dir}/${model}.json")

            # SEC-009-1: Validate vote JSON structure before processing
            if ! validate_vote_json "$vote"; then
                log_warn "Invalid vote JSON from model $model: $VALIDATION_ERROR"
                # Treat invalid JSON as abstention - do not count towards consensus
                ((abstentions++)) || true
                failures+=("{\"model\":\"$model\",\"reason\":\"Malformed response: $VALIDATION_ERROR\"}")
                continue
            fi

            local decision
            decision=$(echo "$vote" | jq -r '.decision')
            local confidence
            confidence=$(echo "$vote" | jq -r '.confidence')

            case "$decision" in
                APPROVE)
                    if (( $(echo "$confidence >= $CONSENSUS_MIN_CONFIDENCE" | bc -l 2>/dev/null || echo 0) )); then
                        ((approvals++)) || true
                        vote_models+=("$model")
                    else
                        # Low confidence approval treated as abstention
                        ((abstentions++)) || true
                        log_info "Low confidence approval from $model ($confidence < $CONSENSUS_MIN_CONFIDENCE)"
                    fi
                    ;;
                REJECT)
                    ((rejections++)) || true
                    local reasoning
                    reasoning=$(echo "$vote" | jq -r '.reasoning // ""')
                    failures+=("{\"model\":\"$model\",\"reason\":\"$reasoning\"}")
                    ;;
                REQUEST_CHANGES)
                    ((changes_requested++)) || true
                    ;;
                ABSTAIN)
                    ((abstentions++)) || true
                    ;;
            esac
        else
            # Missing vote file - count as abstention
            ((abstentions++)) || true
            log_warn "No vote file found for model $model"
        fi
    done

    rm -rf "$temp_dir"

    # Determine final decision
    local final_decision="ABSTAIN"
    local final_status="PENDING"

    if [[ $rejections -gt 0 ]]; then
        final_decision="REJECT"
        final_status="REJECTED"
    elif [[ $changes_requested -gt 0 ]]; then
        final_decision="REQUEST_CHANGES"
        final_status="CHANGES_REQUESTED"
    elif [[ $approvals -ge $CONSENSUS_APPROVAL_THRESHOLD ]]; then
        final_decision="APPROVE"
        final_status="APPROVED"
    fi

    # Update consensus request (SQL injection fixed - all string params escaped)
    sqlite3 "$db" <<SQL
UPDATE consensus_requests
SET status = '$(_sql_escape "$final_status")',
    final_decision = '$(_sql_escape "$final_decision")',
    approvals = $approvals,
    rejections = $rejections,
    abstentions = $abstentions,
    completed_at = datetime('now')
WHERE id = '$(_sql_escape "$request_id")';
SQL

    # Build result JSON
    local models_json
    models_json=$(printf '%s\n' "${vote_models[@]}" | jq -R . | jq -s . 2>/dev/null || echo "[]")
    local failures_json
    failures_json="[$(IFS=,; echo "${failures[*]}")]"

    cat <<EOF
{
    "request_id": "$request_id",
    "task_id": "$task_id",
    "decision": "$final_decision",
    "status": "$final_status",
    "approvals": $approvals,
    "rejections": $rejections,
    "abstentions": $abstentions,
    "changes_requested": $changes_requested,
    "models": $models_json,
    "failures": $failures_json
}
EOF
}

# Collect vote from a single model
collect_model_vote() {
    local request_id="$1"
    local model="$2"
    local task_id="$3"
    local review_type="$4"
    local context="$5"
    local db="${6:-$STATE_DB}"

    local start_time
    start_time=$(date +%s%N 2>/dev/null || echo "$(date +%s)000000000")

    local prompt
    prompt=$(build_review_prompt "$review_type" "$task_id" "$context")

    local response=""
    local exit_code=0

    # Ensure delegate scripts are executable and in path or absolute path
    local delegate_cmd=""
    case "$model" in
        claude)
            delegate_cmd="${BIN_DIR}/claude-delegate"
            ;; 
        codex)
            delegate_cmd="${BIN_DIR}/codex-delegate"
            ;; 
        gemini)
            delegate_cmd="${BIN_DIR}/gemini-delegate"
            ;; 
    esac

    if [[ -x "$delegate_cmd" ]]; then
        response=$("$delegate_cmd" "$prompt" 2>&1) || exit_code=$?
    else
        # Fallback to direct CLI if delegates not ready
        case "$model" in
            claude)
                response=$(claude --dangerously-skip-permissions -p "$prompt" --output-format json 2>&1) || exit_code=$?
                ;; 
            codex)
                if [[ -x "${BIN_DIR}/codex-ask" ]]; then
                    response=$("${BIN_DIR}/codex-ask" "$prompt" 2>&1) || exit_code=$?
                fi
                ;; 
            gemini)
                if [[ -x "${BIN_DIR}/gemini-ask" ]]; then
                    response=$("${BIN_DIR}/gemini-ask" "$prompt" 2>&1) || exit_code=$?
                fi
                ;; 
        esac
    fi

    local end_time
    end_time=$(date +%s%N 2>/dev/null || echo "$(date +%s)000000000")
    local latency_ms=$(( (end_time - start_time) / 1000000 ))

    # Parse response to extract decision
    local decision="ABSTAIN"
    local confidence=0
    local reasoning=""
    local required_changes=""

    if [[ $exit_code -eq 0 ]] && [[ -n "$response" ]]; then
        # SEC-009-1: Validate model response JSON structure before processing
        # Try to extract structured decision from response (assuming JSON envelope or internal JSON)
        # Delegates return JSON envelope. Direct calls might not.

        # Check if response is valid JSON with required structure
        if validate_model_response_json "$response"; then
            # Response passed validation - safe to extract fields
            decision=$(echo "$response" | jq -r '.decision')
            confidence=$(echo "$response" | jq -r '.confidence // 0')
            reasoning=$(echo "$response" | jq -r '.reasoning // ""')
            required_changes=$(echo "$response" | jq -r '.required_changes // ""')
            log_info "Valid JSON response from $model: decision=$decision, confidence=$confidence"
        elif echo "$response" | jq -e . >/dev/null 2>&1; then
            # Valid JSON but missing/invalid required fields
            log_warn "JSON from $model missing required fields: $VALIDATION_ERROR"
            decision="ABSTAIN"
            confidence=0
            reasoning="Response validation failed: $VALIDATION_ERROR. Original: $(echo "$response" | head -c 200)"
        else
            # Not valid JSON - reject unstructured responses for security
            # SEC-009-1: Do NOT use grep-based parsing as it can be manipulated
            log_warn "Non-JSON response from $model rejected (SEC-009-1)"
            decision="ABSTAIN"
            confidence=0
            reasoning="Non-JSON response rejected for security. Raw response: $(echo "$response" | head -c 200)"
        fi
    else
        log_warn "Model $model returned error (exit code: $exit_code)"
        decision="ABSTAIN"
        confidence=0
        reasoning="Model error (exit $exit_code): $(echo "$response" | head -c 200)"
    fi

    # Final validation: Ensure decision is valid (defense in depth)
    case "$decision" in
        APPROVE|REJECT|ABSTAIN|REQUEST_CHANGES)
            ;;
        *)
            log_error "Invalid decision value after parsing: '$decision' - forcing ABSTAIN"
            decision="ABSTAIN"
            confidence=0
            ;;
    esac

    # Record vote (SQL injection fixed - all string params escaped)
    sqlite3 "$db" <<SQL
INSERT OR REPLACE INTO consensus_votes (request_id, model, decision, confidence, reasoning, required_changes, latency_ms)
VALUES ('$(_sql_escape "$request_id")', '$(_sql_escape "$model")', '$(_sql_escape "$decision")', $confidence, '$(_sql_escape "$reasoning")', '$(_sql_escape "$required_changes")', $latency_ms);
SQL

    # Return vote result
    # Escape for JSON string
    local esc_reasoning
    esc_reasoning=$(echo "$reasoning" | jq -R -s . 2>/dev/null || echo "\"\"")
    local esc_changes
    esc_changes=$(echo "$required_changes" | jq -R -s . 2>/dev/null || echo "\"\"")

    cat <<EOF
{
    "model": "$model",
    "decision": "$decision",
    "confidence": $confidence,
    "reasoning": $esc_reasoning,
    "required_changes": $esc_changes,
    "latency_ms": $latency_ms
}
EOF
}

# Build review prompt based on type
build_review_prompt() {
    local review_type="$1"
    local task_id="$2"
    local context="$3"

    local base_prompt="You are a code reviewer. Analyze the following and provide a structured decision.

IMPORTANT: Respond with JSON in this format:
{
    \"decision\": \"APPROVE|REJECT|REQUEST_CHANGES|ABSTAIN\",
    \"confidence\": 0.0-1.0,
    \"reasoning\": \"explanation\",
    \"required_changes\": \"if REQUEST_CHANGES\"
}

Review Type: $review_type
Task ID: $task_id

Context:
$context

Provide your assessment:"

    echo "$base_prompt"
}

# Check if consensus is still valid (not expired)
is_consensus_valid() {
    local request_id="$1"
    local db="${2:-$STATE_DB}"

    local status
    status=$(sqlite3 "$db" <<SQL
SELECT status FROM consensus_requests WHERE id = '$(_sql_escape "$request_id")';
SQL
)

    [[ "$status" == "APPROVED" ]]
}

# Get consensus summary
get_consensus_summary() {
    local task_id="$1"
    local db="${2:-$STATE_DB}"

    sqlite3 -json "$db" <<SQL
SELECT
    cr.id,
    cr.review_type,
    cr.status,
    cr.final_decision,
    cr.approvals,
    cr.rejections,
    cr.created_at,
    cr.completed_at,
    (SELECT json_group_array(json_object('model', model, 'decision', decision, 'confidence', confidence))
     FROM consensus_votes WHERE request_id = cr.id) as votes
FROM consensus_requests cr
WHERE cr.task_id = '$(_sql_escape "$task_id")'
ORDER BY cr.created_at DESC;
SQL
}

# Export functions
export -f validate_model_response_json
export -f validate_vote_json
export -f init_consensus_schema
export -f generate_request_id
export -f request_tri_supervisor_approval
export -f collect_model_vote
export -f build_review_prompt
export -f is_consensus_valid
export -f get_consensus_summary
