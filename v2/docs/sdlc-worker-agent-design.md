# SDLC Worker Agent Design Document

## Overview

This document defines the architecture for an autonomous SDLC Worker Agent that operates as part of a two-session (Worker + Supervisor) system for continuous 24/7 development with forced quality gates.

**Design Goal:** Enable fully autonomous task processing where the Worker Agent:
1. Automatically detects and picks up tasks from a queue
2. Executes tasks using appropriate models (Claude/Codex/Gemini)
3. Validates work through local testing
4. Submits completed work for supervisor approval
5. Handles rejections and iterates on feedback

---

## 1. Task Auto-Pickup Mechanism

### 1.1 Queue Directory Structure

```
tasks/
├── queue/                    # Pending tasks (Worker reads from here)
│   ├── CRITICAL_*.md         # Highest priority
│   ├── HIGH_*.md             # High priority
│   ├── MEDIUM_*.md           # Medium priority
│   └── LOW_*.md              # Low priority
├── running/                  # Currently being processed
│   └── {task}.md.lock        # Lock file with worker ID
├── review/                   # Awaiting supervisor approval
│   └── {task}.md             # With submission metadata
├── completed/                # Approved and done
├── failed/                   # Failed after max retries
├── rejected/                 # Returned for revision
└── ledger.jsonl              # Task state history
```

### 1.2 Priority Ordering

```bash
# Priority weight constants
declare -A PRIORITY_WEIGHTS=(
    ["CRITICAL"]=1000
    ["HIGH"]=100
    ["MEDIUM"]=10
    ["LOW"]=1
)

# Sort order: CRITICAL > HIGH > MEDIUM > LOW
# Within same priority: FIFO by file creation time
```

### 1.3 Task Pickup Algorithm

```bash
# Function: pick_next_task
# Returns: Path to selected task file, or empty if none available
pick_next_task() {
    local queue_dir="${TASKS_DIR}/queue"
    local running_dir="${TASKS_DIR}/running"

    # Priority order: CRITICAL -> HIGH -> MEDIUM -> LOW
    for priority in CRITICAL HIGH MEDIUM LOW; do
        # Get oldest task of this priority (FIFO within priority)
        local task_file
        task_file=$(find "$queue_dir" -name "${priority}_*.md" -type f \
            -printf '%T+ %p\n' 2>/dev/null | sort | head -1 | cut -d' ' -f2)

        if [[ -n "$task_file" && -f "$task_file" ]]; then
            # Attempt to lock
            if acquire_task_lock "$task_file"; then
                echo "$task_file"
                return 0
            fi
        fi
    done

    return 1  # No tasks available
}
```

### 1.4 Task Locking (Prevent Duplicate Processing)

```bash
# Lock acquisition with atomic file creation
acquire_task_lock() {
    local task_file="$1"
    local task_name=$(basename "$task_file")
    local lock_file="${TASKS_DIR}/running/${task_name}.lock"
    local worker_id="${WORKER_ID:-$$}"

    # Create lock directory if needed
    mkdir -p "${TASKS_DIR}/running"

    # Atomic lock acquisition using mkdir (atomic on POSIX)
    local lock_dir="${lock_file}.d"

    if mkdir "$lock_dir" 2>/dev/null; then
        # Won the lock
        cat > "$lock_file" <<EOF
{
    "worker_id": "$worker_id",
    "locked_at": "$(date -Iseconds)",
    "task": "$task_name",
    "pid": $$
}
EOF
        # Move task to running
        mv "$task_file" "${TASKS_DIR}/running/"

        # Log to ledger
        log_ledger "LOCKED" "$task_name" "$worker_id"

        return 0
    else
        return 1  # Another worker got it
    fi
}

# Release lock
release_task_lock() {
    local task_name="$1"
    local lock_file="${TASKS_DIR}/running/${task_name}.lock"
    local lock_dir="${lock_file}.d"

    rm -f "$lock_file"
    rmdir "$lock_dir" 2>/dev/null || true
}

# Check for stale locks (worker crash recovery)
cleanup_stale_locks() {
    local max_age_seconds="${1:-3600}"  # Default 1 hour
    local now=$(date +%s)

    for lock_file in "${TASKS_DIR}/running"/*.lock; do
        [[ -f "$lock_file" ]] || continue

        local locked_at=$(jq -r '.locked_at' "$lock_file" 2>/dev/null)
        local lock_time=$(date -d "$locked_at" +%s 2>/dev/null || echo 0)
        local age=$((now - lock_time))

        if [[ $age -gt $max_age_seconds ]]; then
            local task_name=$(jq -r '.task' "$lock_file")
            log_warn "Recovering stale lock: $task_name (age: ${age}s)"

            # Move task back to queue
            local task_file="${TASKS_DIR}/running/${task_name}"
            if [[ -f "$task_file" ]]; then
                mv "$task_file" "${TASKS_DIR}/queue/"
            fi

            release_task_lock "$task_name"
        fi
    done
}
```

### 1.5 Polling Interval Strategy

```bash
# Adaptive polling with exponential backoff
POLL_MIN_INTERVAL=5        # Minimum 5 seconds when busy
POLL_MAX_INTERVAL=60       # Maximum 60 seconds when idle
POLL_BACKOFF_FACTOR=1.5    # Increase by 50% on idle
POLL_CURRENT_INTERVAL=$POLL_MIN_INTERVAL

worker_main_loop() {
    while true; do
        cleanup_stale_locks  # Recover from crashes

        local task_file
        task_file=$(pick_next_task)

        if [[ -n "$task_file" ]]; then
            # Reset to minimum interval (we're busy)
            POLL_CURRENT_INTERVAL=$POLL_MIN_INTERVAL

            # Execute task
            execute_task "$task_file"
        else
            # No tasks - increase interval (exponential backoff)
            POLL_CURRENT_INTERVAL=$(echo "$POLL_CURRENT_INTERVAL * $POLL_BACKOFF_FACTOR" | bc)
            if (( $(echo "$POLL_CURRENT_INTERVAL > $POLL_MAX_INTERVAL" | bc -l) )); then
                POLL_CURRENT_INTERVAL=$POLL_MAX_INTERVAL
            fi
        fi

        sleep "$POLL_CURRENT_INTERVAL"
    done
}
```

---

## 2. Execution Workflow

### 2.1 Task File Parsing

```bash
# Parse task file and extract structured data
parse_task_file() {
    local task_file="$1"

    # Initialize task context
    declare -g TASK_ID=""
    declare -g TASK_PRIORITY=""
    declare -g TASK_TITLE=""
    declare -g TASK_DESCRIPTION=""
    declare -g TASK_TYPE=""
    declare -g TASK_FILES=()
    declare -g TASK_ACCEPTANCE_CRITERIA=()

    # Extract metadata from filename
    local filename=$(basename "$task_file")
    TASK_PRIORITY=$(echo "$filename" | grep -oE '^(CRITICAL|HIGH|MEDIUM|LOW)' || echo "MEDIUM")
    TASK_ID=$(echo "$filename" | sed 's/\.[^.]*$//' | sed 's/^[A-Z]*_//')

    # Parse markdown content
    local content
    content=$(cat "$task_file")

    # Extract title (first # heading)
    TASK_TITLE=$(echo "$content" | grep -m1 '^#[^#]' | sed 's/^#\s*//')

    # Extract objective/description
    TASK_DESCRIPTION=$(echo "$content" | sed -n '/^## Objective/,/^##/p' | head -n -1 | tail -n +2)

    # Detect task type from content
    if echo "$content" | grep -qi "security\|vulnerability\|audit"; then
        TASK_TYPE="security"
    elif echo "$content" | grep -qi "test\|coverage"; then
        TASK_TYPE="testing"
    elif echo "$content" | grep -qi "fix\|bug\|error"; then
        TASK_TYPE="bugfix"
    elif echo "$content" | grep -qi "feature\|implement\|create\|add"; then
        TASK_TYPE="feature"
    elif echo "$content" | grep -qi "research\|design\|plan"; then
        TASK_TYPE="research"
    else
        TASK_TYPE="general"
    fi

    # Extract acceptance criteria
    while IFS= read -r line; do
        if [[ "$line" =~ ^\-\ \[.\] ]]; then
            TASK_ACCEPTANCE_CRITERIA+=("$line")
        fi
    done <<< "$content"

    # Extract file structure/paths mentioned
    local in_file_block=false
    while IFS= read -r line; do
        if [[ "$line" =~ ^\`\`\` && $in_file_block == true ]]; then
            in_file_block=false
        elif [[ "$line" =~ ^\`\`\` ]]; then
            in_file_block=true
        elif $in_file_block && [[ "$line" =~ ^[[:space:]]+[a-zA-Z_/]+\.[a-z]+ ]]; then
            TASK_FILES+=("$(echo "$line" | xargs)")
        fi
    done <<< "$content"

    return 0
}
```

### 2.2 Model Routing Decision

```bash
# Decide which model(s) to use based on task type
route_task_to_model() {
    local task_type="$1"
    local task_size="$2"  # small, medium, large

    case "$task_type" in
        research|design)
            # Research tasks: Claude for reasoning, Gemini for large context
            if [[ "$task_size" == "large" ]]; then
                echo "gemini"
            else
                echo "claude"
            fi
            ;;

        feature|bugfix)
            # Implementation: Codex for coding
            echo "codex"
            ;;

        security)
            # Security: Multi-model consensus
            echo "consensus"
            ;;

        testing)
            # Testing: Codex for test writing, Claude for analysis
            echo "codex"
            ;;

        *)
            # Default: Claude
            echo "claude"
            ;;
    esac
}

# Execute with appropriate model
execute_with_model() {
    local model="$1"
    local prompt="$2"
    local context="${3:-}"

    case "$model" in
        claude)
            # Execute via Claude delegate
            "${BIN_DIR}/claude-delegate" --prompt "$prompt" --context "$context"
            ;;

        codex)
            # Execute via Codex delegate
            "${BIN_DIR}/codex-delegate" --prompt "$prompt" --context "$context"
            ;;

        gemini)
            # Execute via Gemini delegate (large context)
            "${BIN_DIR}/gemini-delegate" --prompt "$prompt" --context "$context"
            ;;

        consensus)
            # Use tri-agent consensus for critical decisions
            "${BIN_DIR}/tri-agent-consensus" "$prompt"
            ;;
    esac
}
```

### 2.3 Execution Pipeline

```bash
# Main task execution function
execute_task() {
    local task_file="$1"
    local task_name=$(basename "$task_file")

    log_info "Executing task: $task_name"

    # Parse task
    parse_task_file "$task_file"

    # Create execution context
    local execution_dir="${SESSIONS_DIR}/execution_${TASK_ID}_$(date +%s)"
    mkdir -p "$execution_dir"

    # Determine model routing
    local model
    model=$(route_task_to_model "$TASK_TYPE" "medium")

    # Build execution prompt
    local prompt
    prompt=$(build_execution_prompt)

    # Execute
    local result
    local exit_code

    log_info "Routing to model: $model"
    result=$(execute_with_model "$model" "$prompt" 2>&1)
    exit_code=$?

    # Save execution result
    echo "$result" > "${execution_dir}/output.txt"

    if [[ $exit_code -eq 0 ]]; then
        # Run local tests
        if run_local_tests; then
            # Submit for review
            submit_for_review "$task_file" "$execution_dir"
        else
            handle_execution_failure "$task_file" "Tests failed" "$execution_dir"
        fi
    else
        handle_execution_failure "$task_file" "Execution failed: exit code $exit_code" "$execution_dir"
    fi
}

# Build execution prompt from parsed task
build_execution_prompt() {
    cat <<EOF
# Task: ${TASK_TITLE}

## Objective
${TASK_DESCRIPTION}

## Task Type
${TASK_TYPE}

## Priority
${TASK_PRIORITY}

## Acceptance Criteria
$(printf '%s\n' "${TASK_ACCEPTANCE_CRITERIA[@]}")

## Instructions
1. Implement the solution following best practices
2. Add appropriate error handling
3. Include inline documentation
4. Ensure code is testable

## Files to Consider
$(printf '%s\n' "${TASK_FILES[@]}")

Please provide a complete implementation.
EOF
}
```

### 2.4 Local Testing Before Commit

```bash
# Run local tests before submission
run_local_tests() {
    local test_results="${execution_dir}/test_results.txt"

    log_info "Running local tests..."

    # Run preflight checks
    if [[ -x "${BIN_DIR}/tri-agent-preflight" ]]; then
        "${BIN_DIR}/tri-agent-preflight" --quick > "$test_results" 2>&1
        local preflight_exit=$?

        if [[ $preflight_exit -ne 0 ]]; then
            log_error "Preflight checks failed"
            return 1
        fi
    fi

    # Run test suite
    if [[ -x "${TESTS_DIR}/run_tests.sh" ]]; then
        "${TESTS_DIR}/run_tests.sh" unit >> "$test_results" 2>&1
        local test_exit=$?

        if [[ $test_exit -ne 0 ]]; then
            log_error "Unit tests failed"
            return 1
        fi
    fi

    # Run linter
    if [[ -x "${BIN_DIR}/tri-agent-lint" ]]; then
        "${BIN_DIR}/tri-agent-lint" >> "$test_results" 2>&1 || true
    fi

    log_info "Local tests passed"
    return 0
}

# Handle execution failure
handle_execution_failure() {
    local task_file="$1"
    local reason="$2"
    local execution_dir="$3"
    local task_name=$(basename "$task_file")

    log_error "Task failed: $task_name - $reason"

    # Check retry count
    local retry_count
    retry_count=$(get_task_retry_count "$task_name")

    if [[ $retry_count -lt $MAX_RETRIES ]]; then
        # Increment retry and requeue
        increment_retry_count "$task_name"
        mv "${TASKS_DIR}/running/$task_name" "${TASKS_DIR}/queue/"
        release_task_lock "$task_name"

        log_info "Requeued task for retry ($((retry_count + 1))/$MAX_RETRIES)"
    else
        # Max retries exceeded - move to failed
        mv "${TASKS_DIR}/running/$task_name" "${TASKS_DIR}/failed/"
        release_task_lock "$task_name"

        # Notify supervisor
        notify_supervisor "TASK_FAILED" "$task_name" "$reason"

        log_error "Task exceeded max retries, moved to failed/"
    fi
}
```

---

## 3. Submission for Approval

### 3.1 Submission Protocol

```bash
# Submit completed work for supervisor review
submit_for_review() {
    local task_file="$1"
    local execution_dir="$2"
    local task_name=$(basename "$task_file")

    local review_dir="${TASKS_DIR}/review"
    mkdir -p "$review_dir"

    # Create submission metadata
    local submission_file="${review_dir}/${task_name}"
    local submission_meta="${review_dir}/${task_name}.meta.json"

    # Copy task with submission info appended
    cp "${TASKS_DIR}/running/$task_name" "$submission_file"

    # Append submission section
    cat >> "$submission_file" <<EOF

---

## Worker Submission

### Submitted
- Time: $(date -Iseconds)
- Worker ID: ${WORKER_ID:-$$}
- Execution ID: $(basename "$execution_dir")

### Changes Made
$(git diff --stat HEAD~1 2>/dev/null || echo "No git changes detected")

### Commits
$(git log --oneline -5 2>/dev/null || echo "No recent commits")

### Test Results
$(cat "${execution_dir}/test_results.txt" 2>/dev/null | tail -20 || echo "No test results")

### Files Modified
$(git diff --name-only HEAD~1 2>/dev/null || echo "No files tracked")

---

**Status:** AWAITING_REVIEW
EOF

    # Create JSON metadata
    cat > "$submission_meta" <<EOF
{
    "task_id": "$TASK_ID",
    "task_name": "$task_name",
    "submitted_at": "$(date -Iseconds)",
    "worker_id": "${WORKER_ID:-$$}",
    "execution_dir": "$execution_dir",
    "commit_sha": "$(git rev-parse HEAD 2>/dev/null || echo 'none')",
    "status": "AWAITING_REVIEW",
    "retry_count": $(get_task_retry_count "$task_name")
}
EOF

    # Move from running to review
    rm -f "${TASKS_DIR}/running/$task_name"
    release_task_lock "$task_name"

    # Log to ledger
    log_ledger "SUBMITTED" "$task_name" "${WORKER_ID:-$$}"

    # Notify supervisor
    notify_supervisor "SUBMISSION" "$task_name" "Ready for review"

    log_info "Task submitted for review: $task_name"
}
```

### 3.2 Commit Linking

```bash
# Create commit with task reference
create_task_commit() {
    local task_id="$1"
    local task_title="$2"
    local task_type="$3"

    # Determine commit type
    local commit_type
    case "$task_type" in
        bugfix)     commit_type="fix" ;;
        feature)    commit_type="feat" ;;
        security)   commit_type="security" ;;
        testing)    commit_type="test" ;;
        research)   commit_type="docs" ;;
        *)          commit_type="chore" ;;
    esac

    # Stage changes
    git add -A

    # Create commit with task reference
    git commit -m "$(cat <<EOF
${commit_type}: ${task_title}

Task-ID: ${task_id}
Worker: ${WORKER_ID:-autonomous}

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
}
```

### 3.3 Supervisor Notification

```bash
# Notify supervisor of events
notify_supervisor() {
    local event_type="$1"
    local task_name="$2"
    local message="$3"

    local notification_file="${TASKS_DIR}/supervisor_feedback/notification_$(date +%s).json"

    cat > "$notification_file" <<EOF
{
    "event": "$event_type",
    "task": "$task_name",
    "message": "$message",
    "timestamp": "$(date -Iseconds)",
    "worker_id": "${WORKER_ID:-$$}"
}
EOF

    # Also try tmux notification if available
    if [[ -n "${SUPERVISOR_SESSION:-}" ]]; then
        local socket="${TMUX_SOCKET:-tri-agent}"
        tmux -L "$socket" send-keys -t "$SUPERVISOR_SESSION" \
            "WORKER [${event_type}]: ${task_name} - ${message}" Enter 2>/dev/null || true
    fi
}
```

---

## 4. Handling Rejections

### 4.1 Rejection Detection

```bash
# Check for rejected tasks
check_for_rejections() {
    local rejected_dir="${TASKS_DIR}/rejected"

    for rejection_file in "$rejected_dir"/*.md; do
        [[ -f "$rejection_file" ]] || continue

        local task_name=$(basename "$rejection_file")

        # Check if we haven't already picked this up
        if ! is_task_locked "$task_name"; then
            process_rejection "$rejection_file"
        fi
    done
}

# Poll for rejection feedback
monitor_rejections() {
    local feedback_dir="${TASKS_DIR}/supervisor_feedback"

    for feedback_file in "$feedback_dir"/rejection_*.json; do
        [[ -f "$feedback_file" ]] || continue

        local task_name=$(jq -r '.task' "$feedback_file")
        local processed=$(jq -r '.processed // false' "$feedback_file")

        if [[ "$processed" != "true" ]]; then
            handle_rejection_feedback "$feedback_file"
        fi
    done
}
```

### 4.2 Parsing Rejection Feedback

```bash
# Parse rejection feedback
parse_rejection_feedback() {
    local rejection_file="$1"

    # Initialize rejection context
    declare -g REJECTION_REASON=""
    declare -g REJECTION_ITEMS=()
    declare -g REJECTION_SUGGESTIONS=()

    local content
    content=$(cat "$rejection_file")

    # Extract rejection reason
    REJECTION_REASON=$(echo "$content" | sed -n '/^## Rejection Reason/,/^##/p' | head -n -1 | tail -n +2)

    # Extract specific items to address
    while IFS= read -r line; do
        if [[ "$line" =~ ^-\ ]]; then
            REJECTION_ITEMS+=("${line#- }")
        fi
    done < <(echo "$content" | sed -n '/^## Items to Address/,/^##/p')

    # Extract suggestions
    while IFS= read -r line; do
        if [[ "$line" =~ ^[0-9]+\. ]]; then
            REJECTION_SUGGESTIONS+=("$line")
        fi
    done < <(echo "$content" | sed -n '/^## Suggestions/,/^##/p')
}
```

### 4.3 Incorporating Feedback

```bash
# Process rejection and retry
process_rejection() {
    local rejection_file="$1"
    local task_name=$(basename "$rejection_file")

    log_info "Processing rejection: $task_name"

    # Parse the rejection
    parse_rejection_feedback "$rejection_file"

    # Get retry count
    local retry_count
    retry_count=$(get_task_retry_count "$task_name")

    if [[ $retry_count -ge $MAX_REJECTION_RETRIES ]]; then
        # Escalate to human
        escalate_to_human "$task_name" "Max rejection retries exceeded"
        return 1
    fi

    # Build retry prompt with feedback incorporated
    local retry_prompt
    retry_prompt=$(build_retry_prompt "$task_name")

    # Requeue with feedback context
    create_retry_task "$rejection_file" "$retry_prompt"
}

# Build prompt incorporating rejection feedback
build_retry_prompt() {
    local task_name="$1"

    cat <<EOF
# Retry: ${TASK_TITLE}

## Previous Attempt Rejected

### Rejection Reason
${REJECTION_REASON}

### Items to Address
$(printf '- %s\n' "${REJECTION_ITEMS[@]}")

### Supervisor Suggestions
$(printf '%s\n' "${REJECTION_SUGGESTIONS[@]}")

---

## Original Task

${TASK_DESCRIPTION}

## Acceptance Criteria
$(printf '%s\n' "${TASK_ACCEPTANCE_CRITERIA[@]}")

---

## Instructions for Retry

1. **Carefully address each rejection item**
2. Review the supervisor's suggestions
3. Ensure all acceptance criteria are met
4. Run comprehensive tests before resubmitting
5. Include notes on what was changed from previous attempt

Please provide an improved implementation addressing the feedback.
EOF
}

# Create retry task with feedback
create_retry_task() {
    local rejection_file="$1"
    local retry_prompt="$2"
    local task_name=$(basename "$rejection_file")

    local queue_dir="${TASKS_DIR}/queue"
    local retry_file="${queue_dir}/${task_name}"

    # Copy original task
    cp "$rejection_file" "$retry_file"

    # Append retry context
    cat >> "$retry_file" <<EOF

---

## Retry Attempt $((retry_count + 1))

### Feedback to Address
${REJECTION_REASON}

### Items
$(printf '- %s\n' "${REJECTION_ITEMS[@]}")

---
EOF

    # Move rejection to processed
    mv "$rejection_file" "${TASKS_DIR}/processed_rejections/"

    # Increment retry count
    increment_retry_count "$task_name"

    log_info "Created retry task: $task_name (attempt $((retry_count + 1)))"
}
```

### 4.4 Escalation

```bash
# Escalate to human when automated resolution fails
escalate_to_human() {
    local task_name="$1"
    local reason="$2"

    local escalation_file="${TASKS_DIR}/escalations/ESCALATION_${task_name}_$(date +%s).md"
    mkdir -p "${TASKS_DIR}/escalations"

    cat > "$escalation_file" <<EOF
# HUMAN ESCALATION REQUIRED

## Task
${task_name}

## Escalation Reason
${reason}

## Rejection History
$(cat "${TASKS_DIR}/rejected/${task_name}" 2>/dev/null || echo "No rejection history")

## Retry Attempts
${retry_count:-0}

## Worker Recommendations
Based on repeated failures, this task may require:
1. Clarification of requirements
2. Architectural decision by human
3. Access to external resources not available to worker
4. Resolution of conflicting requirements

## Timestamp
$(date -Iseconds)
EOF

    # Send urgent notification
    notify_supervisor "ESCALATION" "$task_name" "Human intervention required: $reason"

    log_warn "Task escalated to human: $task_name"
}
```

---

## 5. Complete Worker Main Loop

```bash
#!/bin/bash
# sdlc-worker-agent - Autonomous SDLC Worker

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

source "${PROJECT_ROOT}/lib/common.sh"

# Configuration
WORKER_ID="${WORKER_ID:-worker-$$}"
MAX_RETRIES=3
MAX_REJECTION_RETRIES=2
POLL_MIN_INTERVAL=5
POLL_MAX_INTERVAL=60

# Main worker loop
main() {
    log_info "Starting SDLC Worker Agent: $WORKER_ID"

    # Initialize directories
    mkdir -p "${TASKS_DIR}"/{queue,running,review,completed,failed,rejected,escalations}

    while true; do
        # Cleanup stale locks from crashed workers
        cleanup_stale_locks

        # Check for rejection feedback first (higher priority)
        check_for_rejections

        # Pick next task
        local task_file
        task_file=$(pick_next_task)

        if [[ -n "$task_file" ]]; then
            POLL_CURRENT_INTERVAL=$POLL_MIN_INTERVAL
            execute_task "$task_file"
        else
            # Backoff when idle
            POLL_CURRENT_INTERVAL=$(echo "$POLL_CURRENT_INTERVAL * 1.5" | bc)
            if (( $(echo "$POLL_CURRENT_INTERVAL > $POLL_MAX_INTERVAL" | bc -l) )); then
                POLL_CURRENT_INTERVAL=$POLL_MAX_INTERVAL
            fi
        fi

        sleep "${POLL_CURRENT_INTERVAL%.*}"
    done
}

# Graceful shutdown
trap 'log_info "Worker shutting down..."; exit 0' SIGTERM SIGINT

main "$@"
```

---

## 6. Function Signatures Summary

```bash
# === Task Pickup ===
pick_next_task() -> string              # Returns path to next task
acquire_task_lock(task_file) -> bool    # Lock task for processing
release_task_lock(task_name)            # Release task lock
cleanup_stale_locks(max_age_seconds)    # Recover crashed tasks

# === Parsing ===
parse_task_file(task_file)              # Parse task into global vars
route_task_to_model(type, size) -> str  # Select execution model

# === Execution ===
execute_task(task_file)                 # Main execution pipeline
execute_with_model(model, prompt, ctx)  # Run with specific model
run_local_tests() -> bool               # Pre-submission validation
handle_execution_failure(file, reason, dir)

# === Submission ===
submit_for_review(task_file, exec_dir)  # Submit to supervisor
create_task_commit(id, title, type)     # Create linked commit
notify_supervisor(event, task, message) # Send notification

# === Rejection Handling ===
check_for_rejections()                  # Poll for rejections
parse_rejection_feedback(file)          # Parse rejection details
process_rejection(rejection_file)       # Handle and retry
build_retry_prompt(task_name) -> str    # Build feedback-aware prompt
create_retry_task(file, prompt)         # Requeue with feedback
escalate_to_human(task, reason)         # Human intervention

# === Utility ===
get_task_retry_count(task) -> int       # Get retry attempts
increment_retry_count(task)             # Increment counter
log_ledger(event, task, worker)         # Audit logging
```

---

## 7. Integration Points

### 7.1 With Supervisor Session

```
SUPERVISOR                              WORKER
    │                                      │
    ├──── Creates task in queue/ ─────────►│
    │                                      │
    │◄──── SUBMISSION notification ────────┤
    │                                      │
    ├──── APPROVE → moves to completed/ ──►│
    │  OR                                  │
    ├──── REJECT → moves to rejected/ ────►│
    │                                      │
    │◄──── Retry or ESCALATION ────────────┤
    │                                      │
```

### 7.2 With Existing Scripts

- Uses `tri-agent-preflight` for pre-submission checks
- Uses `tri-agent-consensus` for critical decisions
- Uses delegate scripts (`claude-delegate`, `codex-delegate`, `gemini-delegate`)
- Integrates with `supervisor-communicator.sh` for notifications

---

## 8. Success Criteria Met

| Criterion | Design Feature |
|-----------|---------------|
| 24/7 autonomous processing | Main loop with adaptive polling |
| No human intervention | Full automation with escalation path |
| Quality maintained | Local testing before submission |
| Clean handoff | Structured submission with metadata |

---

*Document created by SDLC Worker Agent Research Sprint*
*Phase: CRITICAL Research Task*
*Duration: 1 hour*
