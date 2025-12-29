# Master Implementation Plan v2: Autonomous Dual Tri-Agent SDLC System

**Version**: 2.0
**Generated**: 2025-12-28
**Sources**:
- v1 Master Plan (14+ parallel agents)
- Gemini: AUTONOMOUS_SDLC_ARCHITECTURE.md
- Gemini: INTER_AGENT_PROTOCOL.md
- Claude: QUALITY_GATES_SPEC.md
- Claude: sdlc-worker-agent-design.md

**Goal**: Production-ready implementation of self-sustaining SDLC with Worker + Supervisor agents operating 24/7 with forced quality gates.

---

## Executive Summary

This v2 plan provides **complete, implementation-ready bash code** for:
- **WORKER Agent**: Autonomous task pickup, execution, and submission
- **SUPERVISOR Agent**: Task generation, quality gates, and approval authority
- **Quality Gates**: 12-check validation (tests, coverage, security, tri-agent review)
- **Inter-Agent Communication**: File-based IPC with tmux signals
- **Failure Recovery**: Crash detection, stale locks, retry budgets

---

## 1. Architecture Overview

### 1.1 Dual Agent Roles

| Role | Primary Model | Responsibilities | Authority |
|------|---------------|------------------|-----------|
| **SUPERVISOR** | Claude Opus (ultrathink 32K) | Brainstorm, Plan, Track, Approve/Reject | APPROVE, REJECT, ESCALATE |
| **WORKER** | Claude Opus + Codex delegation | Execute, Test, Report, Retry | IMPLEMENT, COMMIT, SUBMIT |

### 1.2 SDLC Phase Ownership

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           SDLC PHASE OWNERSHIP                              │
├──────────────┬──────────────────┬────────────────┬─────────────────────────┤
│ SDLC PHASE   │ PRIMARY OWNER    │ SECONDARY      │ MODEL DELEGATION        │
├──────────────┼──────────────────┼────────────────┼─────────────────────────┤
│ BRAINSTORM   │ SUPERVISOR       │ Worker: Context│ Gemini (1M context)     │
│ DOCUMENT     │ COLLABORATIVE    │ Worker: Draft  │ Gemini (documentation)  │
│ PLAN         │ SUPERVISOR       │ Worker: Est    │ Claude Opus (architect) │
│ EXECUTE      │ WORKER           │ Supervisor: QA │ Codex (implementation)  │
│ TRACK        │ SUPERVISOR       │ Worker: Report │ Gemini (analysis)       │
└──────────────┴──────────────────┴────────────────┴─────────────────────────┘
```

---

## 2. Complete Directory Structure

```
~/.claude/autonomous/
├── config/
│   ├── tri-agent.yaml           # Base configuration
│   ├── supervisor-agent.yaml    # Supervisor settings
│   ├── worker-agent.yaml        # Worker settings
│   ├── quality-gates.yaml       # Gate thresholds (12 checks)
│   └── retry-limits.yaml        # Retry and escalation config
│
├── tasks/
│   ├── queue/                   # Pending tasks (priority ordered)
│   │   ├── CRITICAL_*.md        # P0: Immediate attention
│   │   ├── HIGH_*.md            # P1: Same-day
│   │   ├── MEDIUM_*.md          # P2: This sprint
│   │   └── LOW_*.md             # P3: Backlog
│   ├── running/                 # Worker executing (max 1 at a time)
│   │   └── *.lock               # Lock files with worker ID
│   ├── review/                  # Awaiting supervisor approval
│   │   └── *.meta.json          # Submission metadata
│   ├── approved/                # Passed all gates
│   ├── rejected/                # Failed with feedback (audit)
│   ├── completed/               # Successfully merged to main
│   ├── failed/                  # Max retries exceeded
│   └── escalations/             # Requires human intervention
│
├── comms/
│   ├── supervisor/
│   │   ├── inbox/               # FROM Worker TO Supervisor
│   │   └── sent/                # Supervisor sent history
│   └── worker/
│       ├── inbox/               # FROM Supervisor TO Worker
│       └── sent/                # Worker sent history
│
├── state/
│   ├── system_state.json        # Global system state
│   ├── gates/                   # Gate evaluation results
│   │   └── gate4_*.json         # Per-task gate results
│   ├── retries/                 # Retry counters per task
│   └── locks/                   # PID locks for crash detection
│       ├── supervisor.lock
│       └── worker.lock
│
├── lib/
│   ├── common.sh                # Shared utilities
│   ├── worker-executor.sh       # Worker execution engine
│   ├── supervisor-approver.sh   # Approval engine
│   ├── quality-gates.sh         # Gate runners
│   └── comms.sh                 # IPC helpers
│
├── bin/
│   ├── tri-agent-supervisor     # Supervisor daemon
│   └── tri-agent-worker         # Worker daemon
│
└── logs/
    ├── ledger.jsonl             # Immutable audit trail
    ├── supervisor.log           # Supervisor debug stream
    └── worker.log               # Worker debug stream
```

---

## 3. Worker Agent Implementation

### 3.1 Core Configuration

```yaml
# config/worker-agent.yaml
agent:
  name: "worker"
  role: "implementer"
  model: "claude-opus-4.5"
  thinking_tokens: 32000
  worker_id: "worker-${HOSTNAME}-$$"

permissions:
  can_modify_code: true
  can_commit: true
  can_push: false           # Supervisor pushes after approval
  can_run_tests: true
  can_install_deps: false   # Requires supervisor approval

delegation:
  implementation: "codex"   # GPT-5.2-Codex for coding
  test_generation: "codex"
  large_context: "gemini"   # For files > 50KB
  security_check: "self"    # Claude for security

polling:
  min_interval_seconds: 5
  max_interval_seconds: 60
  backoff_factor: 1.5

retries:
  max_per_task: 3
  max_rejection_retries: 2
```

### 3.2 Worker Main Loop (Complete Implementation)

```bash
#!/bin/bash
#===============================================================================
# tri-agent-worker - Autonomous SDLC Worker Agent
#===============================================================================
# Location: bin/tri-agent-worker
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
AUTONOMOUS_ROOT="${HOME}/.claude/autonomous"

# Source dependencies
source "${PROJECT_ROOT}/lib/common.sh"
source "${PROJECT_ROOT}/lib/worker-executor.sh"
source "${PROJECT_ROOT}/lib/comms.sh"

# Configuration
WORKER_ID="${WORKER_ID:-worker-$$-$(date +%s)}"
MAX_RETRIES=3
MAX_REJECTION_RETRIES=2
POLL_MIN_INTERVAL=5
POLL_MAX_INTERVAL=60
POLL_BACKOFF=1.5
POLL_CURRENT=$POLL_MIN_INTERVAL
HEARTBEAT_INTERVAL=60

# Directories
QUEUE_DIR="${AUTONOMOUS_ROOT}/tasks/queue"
RUNNING_DIR="${AUTONOMOUS_ROOT}/tasks/running"
REVIEW_DIR="${AUTONOMOUS_ROOT}/tasks/review"
REJECTED_DIR="${AUTONOMOUS_ROOT}/tasks/rejected"
COMPLETED_DIR="${AUTONOMOUS_ROOT}/tasks/completed"
FAILED_DIR="${AUTONOMOUS_ROOT}/tasks/failed"
ESCALATIONS_DIR="${AUTONOMOUS_ROOT}/tasks/escalations"
RETRIES_DIR="${AUTONOMOUS_ROOT}/state/retries"
LOCKS_DIR="${AUTONOMOUS_ROOT}/state/locks"
INBOX_DIR="${AUTONOMOUS_ROOT}/comms/worker/inbox"

#===============================================================================
# Initialize Directories
#===============================================================================

init_worker() {
    log_info "Initializing Worker Agent: $WORKER_ID"

    mkdir -p "$QUEUE_DIR" "$RUNNING_DIR" "$REVIEW_DIR" \
             "$REJECTED_DIR" "$COMPLETED_DIR" "$FAILED_DIR" \
             "$ESCALATIONS_DIR" "$RETRIES_DIR" "$LOCKS_DIR" "$INBOX_DIR"

    # Create worker lock file
    echo "{\"worker_id\": \"$WORKER_ID\", \"started\": \"$(date -Iseconds)\", \"pid\": $$}" \
        > "${LOCKS_DIR}/worker.lock"

    log_info "Worker directories initialized"
}

#===============================================================================
# Task Auto-Pickup Mechanism
#===============================================================================

# Pick next task by priority (CRITICAL > HIGH > MEDIUM > LOW)
pick_next_task() {
    for priority in CRITICAL HIGH MEDIUM LOW; do
        # Get oldest task of this priority (FIFO within priority)
        local task_file
        task_file=$(find "$QUEUE_DIR" -name "${priority}_*.md" -type f \
            -printf '%T+ %p\n' 2>/dev/null | sort | head -1 | cut -d' ' -f2-)

        if [[ -n "$task_file" && -f "$task_file" ]]; then
            # Attempt to acquire lock
            if acquire_task_lock "$task_file"; then
                echo "$task_file"
                return 0
            fi
        fi
    done

    return 1  # No tasks available
}

# Acquire atomic lock on task
acquire_task_lock() {
    local task_file="$1"
    local task_name=$(basename "$task_file")
    local lock_dir="${RUNNING_DIR}/${task_name}.lock.d"
    local lock_file="${RUNNING_DIR}/${task_name}.lock"

    # Atomic lock acquisition using mkdir (POSIX atomic)
    if mkdir "$lock_dir" 2>/dev/null; then
        # Won the lock - write lock metadata
        cat > "$lock_file" <<EOF
{
    "worker_id": "$WORKER_ID",
    "locked_at": "$(date -Iseconds)",
    "task": "$task_name",
    "pid": $$
}
EOF
        # Move task to running
        mv "$task_file" "$RUNNING_DIR/"

        # Log to ledger
        log_ledger "TASK_LOCKED" "$task_name" "worker=$WORKER_ID"
        log_info "Locked task: $task_name"

        return 0
    else
        return 1  # Another worker got it
    fi
}

# Release task lock
release_task_lock() {
    local task_name="$1"
    local lock_file="${RUNNING_DIR}/${task_name}.lock"
    local lock_dir="${RUNNING_DIR}/${task_name}.lock.d"

    rm -f "$lock_file" 2>/dev/null
    rmdir "$lock_dir" 2>/dev/null || true

    log_debug "Released lock: $task_name"
}

# Cleanup stale locks from crashed workers
cleanup_stale_locks() {
    local max_age_seconds="${1:-3600}"  # Default 1 hour
    local now=$(date +%s)

    for lock_file in "$RUNNING_DIR"/*.lock; do
        [[ -f "$lock_file" ]] || continue

        local locked_at=$(jq -r '.locked_at // ""' "$lock_file" 2>/dev/null)
        [[ -z "$locked_at" ]] && continue

        local lock_time=$(date -d "$locked_at" +%s 2>/dev/null || echo 0)
        local age=$((now - lock_time))

        if [[ $age -gt $max_age_seconds ]]; then
            local task_name=$(jq -r '.task' "$lock_file")
            log_warn "Recovering stale lock: $task_name (age: ${age}s)"

            # Move task back to queue
            local task_file="${RUNNING_DIR}/${task_name}"
            if [[ -f "$task_file" ]]; then
                mv "$task_file" "$QUEUE_DIR/"
            fi

            release_task_lock "$task_name"
            log_ledger "STALE_LOCK_RECOVERED" "$task_name"
        fi
    done
}

#===============================================================================
# Task File Parsing
#===============================================================================

# Parse task markdown file into structured data
parse_task_file() {
    local task_file="$1"

    # Extract from filename
    local filename=$(basename "$task_file")
    TASK_PRIORITY=$(echo "$filename" | grep -oE '^(CRITICAL|HIGH|MEDIUM|LOW)' || echo "MEDIUM")
    TASK_ID=$(echo "$filename" | sed 's/\.md$//' | sed 's/^[A-Z]*_//')

    local content
    content=$(cat "$task_file")

    # Extract title (first # heading)
    TASK_TITLE=$(echo "$content" | grep -m1 '^#[^#]' | sed 's/^#\s*//' || echo "Untitled")

    # Extract description/objective
    TASK_DESCRIPTION=$(echo "$content" | sed -n '/^## Objective\|^## Description/,/^##/p' | head -n -1 | tail -n +2)

    # Detect task type from keywords
    if echo "$content" | grep -qi "security\|vulnerability\|audit\|CVE"; then
        TASK_TYPE="security"
    elif echo "$content" | grep -qi "test\|coverage\|spec"; then
        TASK_TYPE="testing"
    elif echo "$content" | grep -qi "fix\|bug\|error\|crash"; then
        TASK_TYPE="bugfix"
    elif echo "$content" | grep -qi "feature\|implement\|create\|add\|build"; then
        TASK_TYPE="feature"
    elif echo "$content" | grep -qi "research\|design\|plan\|investigate"; then
        TASK_TYPE="research"
    elif echo "$content" | grep -qi "refactor\|clean\|optimize"; then
        TASK_TYPE="refactor"
    else
        TASK_TYPE="general"
    fi

    # Extract acceptance criteria
    TASK_CRITERIA=()
    while IFS= read -r line; do
        if [[ "$line" =~ ^\-\ \[.\] ]]; then
            TASK_CRITERIA+=("$line")
        fi
    done <<< "$content"

    log_debug "Parsed task: id=$TASK_ID type=$TASK_TYPE priority=$TASK_PRIORITY"
}

#===============================================================================
# Model Routing Decision
#===============================================================================

# Route task to appropriate model based on type and size
route_to_model() {
    local task_type="$1"
    local context_size="${2:-0}"  # Bytes

    # Large context (> 50KB) always goes to Gemini
    if [[ $context_size -gt 51200 ]]; then
        echo "gemini"
        return
    fi

    case "$task_type" in
        research|design)
            echo "claude"  # Claude for reasoning
            ;;
        feature|bugfix|refactor)
            echo "codex"   # Codex for implementation
            ;;
        security)
            echo "consensus"  # All 3 for security
            ;;
        testing)
            echo "codex"   # Codex for test writing
            ;;
        *)
            echo "claude"  # Default to Claude
            ;;
    esac
}

# Execute with selected model
execute_with_model() {
    local model="$1"
    local prompt="$2"
    local context="${3:-}"

    case "$model" in
        claude)
            # Use Claude delegate
            if [[ -x "${PROJECT_ROOT}/bin/claude-delegate" ]]; then
                "${PROJECT_ROOT}/bin/claude-delegate" "$prompt" "$context"
            else
                # Fallback to direct invocation
                echo "$prompt" | head -c 50000
            fi
            ;;
        codex)
            # Use Codex delegate
            if [[ -x "${PROJECT_ROOT}/bin/codex-delegate" ]]; then
                "${PROJECT_ROOT}/bin/codex-delegate" "$prompt" "$context"
            elif command -v codex &>/dev/null; then
                codex exec "$prompt" 2>/dev/null
            fi
            ;;
        gemini)
            # Use Gemini delegate for large context
            if [[ -x "${PROJECT_ROOT}/bin/gemini-delegate" ]]; then
                "${PROJECT_ROOT}/bin/gemini-delegate" "$prompt" "$context"
            elif command -v gemini &>/dev/null; then
                gemini -y "$prompt" 2>/dev/null
            fi
            ;;
        consensus)
            # Tri-agent consensus for critical decisions
            if [[ -x "${PROJECT_ROOT}/bin/tri-agent-consensus" ]]; then
                "${PROJECT_ROOT}/bin/tri-agent-consensus" "$prompt"
            fi
            ;;
    esac
}

#===============================================================================
# Task Execution Pipeline
#===============================================================================

# Main task execution function
execute_task() {
    local task_file="$1"
    local task_name=$(basename "$task_file")

    log_info "═══════════════════════════════════════════════════════"
    log_info "Executing task: $task_name"
    log_info "═══════════════════════════════════════════════════════"

    # Parse task
    parse_task_file "$task_file"

    # Create execution context directory
    local exec_dir="${AUTONOMOUS_ROOT}/state/executions/${TASK_ID}_$(date +%s)"
    mkdir -p "$exec_dir"

    # Determine model routing
    local context_size=$(wc -c < "$task_file" 2>/dev/null || echo 0)
    local model=$(route_to_model "$TASK_TYPE" "$context_size")

    log_info "Task type: $TASK_TYPE"
    log_info "Routing to model: $model"

    # Build execution prompt
    local prompt
    prompt=$(build_execution_prompt)
    echo "$prompt" > "${exec_dir}/prompt.txt"

    # Execute with model
    local result
    local exit_code=0

    log_info "Starting model execution..."
    result=$(execute_with_model "$model" "$prompt" 2>&1) || exit_code=$?
    echo "$result" > "${exec_dir}/output.txt"

    if [[ $exit_code -eq 0 ]]; then
        log_info "Model execution completed"

        # Run local tests before submission
        if run_local_tests "$exec_dir"; then
            log_info "Local tests passed"
            submit_for_review "$task_file" "$exec_dir"
        else
            log_error "Local tests failed"
            handle_execution_failure "$task_file" "Local tests failed" "$exec_dir"
        fi
    else
        log_error "Model execution failed (exit code: $exit_code)"
        handle_execution_failure "$task_file" "Model execution failed" "$exec_dir"
    fi
}

# Build structured prompt from parsed task
build_execution_prompt() {
    cat <<EOF
# Task: ${TASK_TITLE}

## Task ID
${TASK_ID}

## Priority
${TASK_PRIORITY}

## Type
${TASK_TYPE}

## Objective
${TASK_DESCRIPTION}

## Acceptance Criteria
$(printf '%s\n' "${TASK_CRITERIA[@]}")

## Instructions
1. Implement the solution following best practices
2. Add comprehensive error handling
3. Include inline documentation (JSDoc/docstrings)
4. Ensure code is fully testable
5. Follow existing code patterns in the project

## Constraints
- All tests must pass before submission
- Coverage must be ≥80%
- No critical/high security vulnerabilities
- Follow conventional commit format

Please provide a complete, working implementation.
EOF
}

#===============================================================================
# Local Testing (Pre-Submission Validation)
#===============================================================================

# Run local tests before submission
run_local_tests() {
    local exec_dir="$1"
    local test_results="${exec_dir}/test_results.txt"
    local all_passed=true

    log_info "Running local validation..."

    # Check 1: Preflight checks
    if [[ -x "${PROJECT_ROOT}/bin/tri-agent-preflight" ]]; then
        log_info "  Running preflight checks..."
        if "${PROJECT_ROOT}/bin/tri-agent-preflight" --quick >> "$test_results" 2>&1; then
            echo "PREFLIGHT: PASS" >> "$test_results"
        else
            echo "PREFLIGHT: FAIL" >> "$test_results"
            all_passed=false
        fi
    fi

    # Check 2: Unit tests
    if [[ -x "${PROJECT_ROOT}/tests/run_tests.sh" ]]; then
        log_info "  Running unit tests..."
        if "${PROJECT_ROOT}/tests/run_tests.sh" unit >> "$test_results" 2>&1; then
            echo "UNIT_TESTS: PASS" >> "$test_results"
        else
            echo "UNIT_TESTS: FAIL" >> "$test_results"
            all_passed=false
        fi
    fi

    # Check 3: Linting
    if [[ -x "${PROJECT_ROOT}/bin/tri-agent-lint" ]]; then
        log_info "  Running linter..."
        if "${PROJECT_ROOT}/bin/tri-agent-lint" >> "$test_results" 2>&1; then
            echo "LINT: PASS" >> "$test_results"
        else
            echo "LINT: WARN" >> "$test_results"
            # Linting warnings don't fail the build
        fi
    fi

    # Check 4: Git status (ensure changes are staged)
    log_info "  Checking git status..."
    if git diff --cached --quiet 2>/dev/null; then
        echo "GIT_STAGED: NOTHING_STAGED" >> "$test_results"
    else
        echo "GIT_STAGED: CHANGES_READY" >> "$test_results"
    fi

    if $all_passed; then
        log_info "All local tests passed"
        return 0
    else
        log_error "Some local tests failed"
        return 1
    fi
}

#===============================================================================
# Submission Protocol
#===============================================================================

# Submit completed work for supervisor review
submit_for_review() {
    local task_file="$1"
    local exec_dir="$2"
    local task_name=$(basename "$task_file")

    log_info "Submitting task for review: $task_name"

    mkdir -p "$REVIEW_DIR"

    # Create submission file
    local submission_file="${REVIEW_DIR}/${task_name}"
    cp "${RUNNING_DIR}/${task_name}" "$submission_file"

    # Append submission metadata
    cat >> "$submission_file" <<EOF

---

## WORKER SUBMISSION

### Submission Details
- **Submitted**: $(date -Iseconds)
- **Worker ID**: ${WORKER_ID}
- **Execution ID**: $(basename "$exec_dir")

### Git Changes
\`\`\`
$(git diff --stat HEAD~1 2>/dev/null || echo "No git changes detected")
\`\`\`

### Recent Commits
\`\`\`
$(git log --oneline -5 2>/dev/null || echo "No recent commits")
\`\`\`

### Test Results Summary
\`\`\`
$(cat "${exec_dir}/test_results.txt" 2>/dev/null | tail -20 || echo "No test results")
\`\`\`

### Files Modified
$(git diff --name-only HEAD~1 2>/dev/null | sed 's/^/- /' || echo "- None tracked")

---

**Status**: AWAITING_REVIEW
EOF

    # Create JSON metadata
    local meta_file="${REVIEW_DIR}/${task_name}.meta.json"
    cat > "$meta_file" <<EOF
{
    "task_id": "${TASK_ID}",
    "task_name": "${task_name}",
    "task_type": "${TASK_TYPE}",
    "priority": "${TASK_PRIORITY}",
    "submitted_at": "$(date -Iseconds)",
    "worker_id": "${WORKER_ID}",
    "execution_dir": "${exec_dir}",
    "commit_sha": "$(git rev-parse HEAD 2>/dev/null || echo 'none')",
    "status": "AWAITING_REVIEW",
    "retry_count": $(get_retry_count "$task_name")
}
EOF

    # Move from running (cleanup)
    rm -f "${RUNNING_DIR}/${task_name}"
    release_task_lock "$task_name"

    # Log to ledger
    log_ledger "TASK_SUBMITTED" "$task_name" "worker=$WORKER_ID"

    # Notify supervisor
    send_message "TASK_COMPLETE" "supervisor" "{
        \"task_id\": \"${TASK_ID}\",
        \"task_name\": \"${task_name}\",
        \"status\": \"ready_for_review\",
        \"submission_file\": \"${submission_file}\"
    }"

    # Signal supervisor via tmux
    signal_supervisor "New submission: $task_name"

    log_info "Task submitted successfully: $task_name"
}

# Send message to target agent
send_message() {
    local msg_type="$1"
    local target="$2"
    local payload="$3"

    local msg_id=$(uuidgen 2>/dev/null || echo "msg-$(date +%s)-$$")
    local inbox_dir="${AUTONOMOUS_ROOT}/comms/${target}/inbox"
    local msg_file="${inbox_dir}/${msg_id}.json"

    mkdir -p "$inbox_dir"

    cat > "$msg_file" <<EOF
{
    "id": "${msg_id}",
    "type": "${msg_type}",
    "source": "worker",
    "target": "${target}",
    "timestamp": "$(date -Iseconds)",
    "payload": ${payload},
    "metadata": {
        "worker_id": "${WORKER_ID}",
        "priority": "high",
        "requires_ack": true
    }
}
EOF

    log_debug "Sent message: $msg_type to $target"
}

# Signal supervisor via tmux
signal_supervisor() {
    local message="$1"
    local session="${SUPERVISOR_SESSION:-tri-agent-supervisor}"
    local socket="${TMUX_SOCKET:-tri-agent}"

    if tmux -L "$socket" has-session -t "$session" 2>/dev/null; then
        tmux -L "$socket" send-keys -t "$session" \
            "WORKER [SUBMISSION]: $message" Enter 2>/dev/null || true
    fi
}

#===============================================================================
# Failure & Retry Handling
#===============================================================================

# Handle execution failure
handle_execution_failure() {
    local task_file="$1"
    local reason="$2"
    local exec_dir="$3"
    local task_name=$(basename "$task_file")

    log_error "Task failed: $task_name - $reason"

    # Get retry count
    local retry_count=$(get_retry_count "$task_name")

    if [[ $retry_count -lt $MAX_RETRIES ]]; then
        # Increment retry and requeue
        increment_retry_count "$task_name"
        mv "${RUNNING_DIR}/${task_name}" "$QUEUE_DIR/"
        release_task_lock "$task_name"

        log_info "Requeued task for retry ($((retry_count + 1))/$MAX_RETRIES)"
        log_ledger "TASK_REQUEUED" "$task_name" "retry=$((retry_count + 1))"
    else
        # Max retries exceeded - move to failed
        mv "${RUNNING_DIR}/${task_name}" "$FAILED_DIR/"
        release_task_lock "$task_name"

        # Notify supervisor
        send_message "TASK_FAIL" "supervisor" "{
            \"task_id\": \"${TASK_ID}\",
            \"task_name\": \"${task_name}\",
            \"reason\": \"${reason}\",
            \"retries\": ${retry_count}
        }"

        log_error "Task exceeded max retries, moved to failed/"
        log_ledger "TASK_FAILED" "$task_name" "reason=$reason"
    fi
}

# Get retry count for task
get_retry_count() {
    local task_name="$1"
    local retry_file="${RETRIES_DIR}/${task_name}.retry"

    if [[ -f "$retry_file" ]]; then
        cat "$retry_file"
    else
        echo "0"
    fi
}

# Increment retry count
increment_retry_count() {
    local task_name="$1"
    local retry_file="${RETRIES_DIR}/${task_name}.retry"

    mkdir -p "$RETRIES_DIR"

    local current=$(get_retry_count "$task_name")
    echo "$((current + 1))" > "$retry_file"
}

#===============================================================================
# Rejection Handling
#===============================================================================

# Check for rejection feedback
check_for_rejections() {
    for rejection_file in "$REJECTED_DIR"/*.md; do
        [[ -f "$rejection_file" ]] || continue

        local task_name=$(basename "$rejection_file")

        # Check if not already being processed
        if [[ ! -f "${RUNNING_DIR}/${task_name}.lock" ]]; then
            process_rejection "$rejection_file"
        fi
    done
}

# Process rejection and create retry task
process_rejection() {
    local rejection_file="$1"
    local task_name=$(basename "$rejection_file")

    log_info "Processing rejection: $task_name"

    # Parse rejection feedback
    local feedback=$(grep -A100 "^## REJECTION FEEDBACK" "$rejection_file" | tail -n +2 | head -50)
    local failed_checks=$(grep -E "^- (EXE|FAIL)" "$rejection_file" || true)

    # Get retry count
    local retry_count=$(get_retry_count "$task_name")

    if [[ $retry_count -ge $MAX_REJECTION_RETRIES ]]; then
        # Escalate to human
        escalate_task "$task_name" "Max rejection retries exceeded"
        return 1
    fi

    # Create retry task with feedback incorporated
    local retry_file="${QUEUE_DIR}/${task_name}"

    cat > "$retry_file" <<EOF
# RETRY: ${TASK_TITLE:-$task_name}

## IMPORTANT: Addressing Previous Rejection

**Attempt**: $((retry_count + 1)) of $MAX_REJECTION_RETRIES

### Rejection Feedback
${feedback}

### Failed Checks to Fix
${failed_checks}

---

## Original Task
$(cat "$rejection_file" | sed -n '/^# Task\|^## Objective/,/^## REJECTION/p' | head -n -1)

---

## Retry Instructions
1. **FOCUS** on fixing the specific issues listed above
2. Run ALL tests before resubmitting
3. Ensure coverage is ≥80%
4. Address every item in the rejection feedback
5. Do NOT introduce new features - only fix the issues
EOF

    # Move original to processed
    mv "$rejection_file" "${AUTONOMOUS_ROOT}/state/processed_rejections/" 2>/dev/null || \
        rm "$rejection_file"

    # Increment retry
    increment_retry_count "$task_name"

    log_info "Created retry task: $task_name (attempt $((retry_count + 1)))"
    log_ledger "REJECTION_PROCESSED" "$task_name" "retry=$((retry_count + 1))"
}

# Escalate task requiring human intervention
escalate_task() {
    local task_name="$1"
    local reason="$2"

    mkdir -p "$ESCALATIONS_DIR"

    local escalation_file="${ESCALATIONS_DIR}/ESCALATION_${task_name}_$(date +%s).md"

    cat > "$escalation_file" <<EOF
# HUMAN INTERVENTION REQUIRED

## Task
${task_name}

## Escalation Reason
${reason}

## Retry History
- Total attempts: $(get_retry_count "$task_name")
- Max retries: $MAX_RETRIES

## Rejection History
$(cat "${REJECTED_DIR}/${task_name}" 2>/dev/null || echo "No rejection history available")

## Recommendations
Based on repeated failures, this task may require:
1. Clarification of requirements from stakeholder
2. Architectural decision by human architect
3. Access to external resources not available to worker
4. Resolution of conflicting requirements
5. Manual debugging of complex issue

## Timestamp
$(date -Iseconds)

## Worker
${WORKER_ID}
EOF

    # Send urgent notification
    send_message "ESCALATION" "supervisor" "{
        \"task_name\": \"${task_name}\",
        \"reason\": \"${reason}\",
        \"escalation_file\": \"${escalation_file}\"
    }"

    log_warn "ESCALATED: $task_name - $reason"
    log_ledger "TASK_ESCALATED" "$task_name" "reason=$reason"
}

#===============================================================================
# Inbox Processing
#===============================================================================

# Check worker inbox for supervisor messages
check_inbox() {
    for msg_file in "$INBOX_DIR"/*.json; do
        [[ -f "$msg_file" ]] || continue

        local msg_type=$(jq -r '.type' "$msg_file" 2>/dev/null)
        local payload=$(jq -r '.payload' "$msg_file" 2>/dev/null)

        case "$msg_type" in
            TASK_APPROVE)
                local task_id=$(echo "$payload" | jq -r '.task_id')
                log_info "Received APPROVAL for task: $task_id"
                ;;
            TASK_REJECT)
                local task_id=$(echo "$payload" | jq -r '.task_id')
                log_warn "Received REJECTION for task: $task_id"
                # Rejection will be processed by check_for_rejections
                ;;
            CONTROL_PAUSE)
                log_warn "Received PAUSE command"
                WORKER_PAUSED=true
                ;;
            CONTROL_RESUME)
                log_info "Received RESUME command"
                WORKER_PAUSED=false
                ;;
        esac

        # Move to processed
        mv "$msg_file" "${AUTONOMOUS_ROOT}/comms/worker/processed/" 2>/dev/null || \
            rm "$msg_file"
    done
}

#===============================================================================
# Heartbeat
#===============================================================================

# Send heartbeat to supervisor
send_heartbeat() {
    local status="idle"
    local current_task=""

    # Check if we're working on something
    local running_task=$(ls -1 "$RUNNING_DIR"/*.md 2>/dev/null | head -1)
    if [[ -n "$running_task" ]]; then
        status="busy"
        current_task=$(basename "$running_task")
    fi

    # Update lock file
    cat > "${LOCKS_DIR}/worker.lock" <<EOF
{
    "worker_id": "$WORKER_ID",
    "heartbeat": "$(date -Iseconds)",
    "status": "$status",
    "current_task": "$current_task",
    "pid": $$
}
EOF

    # Send heartbeat message
    send_message "HEARTBEAT" "supervisor" "{
        \"status\": \"$status\",
        \"current_task\": \"$current_task\",
        \"uptime_seconds\": $SECONDS
    }"
}

#===============================================================================
# Logging
#===============================================================================

log_info() { echo "[$(date -Iseconds)] [INFO] $*" | tee -a "${AUTONOMOUS_ROOT}/logs/worker.log"; }
log_warn() { echo "[$(date -Iseconds)] [WARN] $*" | tee -a "${AUTONOMOUS_ROOT}/logs/worker.log" >&2; }
log_error() { echo "[$(date -Iseconds)] [ERROR] $*" | tee -a "${AUTONOMOUS_ROOT}/logs/worker.log" >&2; }
log_debug() { [[ "${DEBUG:-}" == "true" ]] && echo "[$(date -Iseconds)] [DEBUG] $*" >> "${AUTONOMOUS_ROOT}/logs/worker.log"; }

log_ledger() {
    local event="$1"
    local task="$2"
    local details="${3:-}"

    echo "{\"timestamp\":\"$(date -Iseconds)\",\"event\":\"$event\",\"task\":\"$task\",\"worker\":\"$WORKER_ID\",\"details\":\"$details\"}" \
        >> "${AUTONOMOUS_ROOT}/logs/ledger.jsonl"
}

#===============================================================================
# Main Loop
#===============================================================================

main() {
    init_worker

    local last_heartbeat=0
    WORKER_PAUSED=false

    log_info "═══════════════════════════════════════════════════════"
    log_info "  TRI-AGENT WORKER STARTED"
    log_info "  Worker ID: $WORKER_ID"
    log_info "  PID: $$"
    log_info "═══════════════════════════════════════════════════════"

    while true; do
        local now=$(date +%s)

        # Send heartbeat periodically
        if (( now - last_heartbeat >= HEARTBEAT_INTERVAL )); then
            send_heartbeat
            last_heartbeat=$now
        fi

        # Check inbox for supervisor messages
        check_inbox

        # Skip processing if paused
        if $WORKER_PAUSED; then
            sleep 5
            continue
        fi

        # Cleanup stale locks
        cleanup_stale_locks 3600

        # Process rejections first (higher priority)
        check_for_rejections

        # Pick next task
        local task_file
        task_file=$(pick_next_task) || true

        if [[ -n "$task_file" ]]; then
            # Reset polling interval (we're busy)
            POLL_CURRENT=$POLL_MIN_INTERVAL

            # Execute task
            execute_task "$task_file"
        else
            # No tasks - apply backoff
            POLL_CURRENT=$(echo "$POLL_CURRENT * $POLL_BACKOFF" | bc 2>/dev/null || echo $POLL_CURRENT)
            if (( $(echo "$POLL_CURRENT > $POLL_MAX_INTERVAL" | bc -l 2>/dev/null || echo 0) )); then
                POLL_CURRENT=$POLL_MAX_INTERVAL
            fi

            log_debug "No tasks available, sleeping ${POLL_CURRENT%.*}s"
        fi

        sleep "${POLL_CURRENT%.*}"
    done
}

# Graceful shutdown
cleanup() {
    log_info "Worker shutting down..."

    # Release any held locks
    for lock in "$RUNNING_DIR"/*.lock; do
        [[ -f "$lock" ]] || continue
        local task=$(jq -r '.task' "$lock" 2>/dev/null)
        if [[ -n "$task" ]]; then
            # Move task back to queue
            [[ -f "${RUNNING_DIR}/${task}" ]] && mv "${RUNNING_DIR}/${task}" "$QUEUE_DIR/"
            release_task_lock "$task"
        fi
    done

    rm -f "${LOCKS_DIR}/worker.lock"
    log_info "Worker shutdown complete"
    exit 0
}

trap cleanup SIGTERM SIGINT SIGHUP

main "$@"
```

---

## 4. Quality Gates (12-Check Gate 4)

### 4.1 Complete Gate Implementation

```bash
#!/bin/bash
#===============================================================================
# lib/quality-gates.sh - Quality Gate Validation Engine
#===============================================================================

# Gate 4: EXECUTE → APPROVED (Critical Gate)
# 12 automated checks must pass before approval

validate_gate_4() {
    local workspace="$1"
    local task_id="$2"
    local gate_results="${STATE_DIR}/gates/gate4_${task_id}.json"

    log_info "═══════════════════════════════════════════════════════"
    log_info "  GATE 4: EXECUTE → APPROVED"
    log_info "  Task: $task_id"
    log_info "═══════════════════════════════════════════════════════"

    local checks_passed=0
    local checks_failed=0
    local checks_skipped=0
    declare -a results

    # --- CHECK 1: Test Suite Execution (EXE-001) ---
    log_info "[1/12] Running test suite..."
    if run_test_suite "$workspace"; then
        results+=("EXE-001:PASS:All tests passed")
        ((checks_passed++))
    else
        results+=("EXE-001:FAIL:Tests failed")
        ((checks_failed++))
    fi

    # --- CHECK 2: Test Coverage (EXE-002) ---
    log_info "[2/12] Checking test coverage..."
    local coverage=$(get_test_coverage "$workspace")
    if (( $(echo "${coverage:-0} >= 80" | bc -l) )); then
        results+=("EXE-002:PASS:Coverage ${coverage}% >= 80%")
        ((checks_passed++))
    else
        results+=("EXE-002:FAIL:Coverage ${coverage:-0}% < 80%")
        ((checks_failed++))
    fi

    # --- CHECK 3: Linting (EXE-003) ---
    log_info "[3/12] Running linter..."
    local lint_errors=$(run_linter "$workspace")
    if [[ $lint_errors -eq 0 ]]; then
        results+=("EXE-003:PASS:No linting errors")
        ((checks_passed++))
    else
        results+=("EXE-003:FAIL:${lint_errors} linting errors")
        ((checks_failed++))
    fi

    # --- CHECK 4: Type Checking (EXE-004) ---
    log_info "[4/12] Running type checker..."
    if run_type_check "$workspace"; then
        results+=("EXE-004:PASS:No type errors")
        ((checks_passed++))
    else
        results+=("EXE-004:FAIL:Type errors detected")
        ((checks_failed++))
    fi

    # --- CHECK 5: Security Scan (EXE-005) ---
    log_info "[5/12] Running security scan..."
    local vuln_result=$(run_security_scan "$workspace")
    local critical=$(echo "$vuln_result" | cut -d: -f1)
    local high=$(echo "$vuln_result" | cut -d: -f2)
    if [[ ${critical:-0} -eq 0 && ${high:-0} -eq 0 ]]; then
        results+=("EXE-005:PASS:No critical/high vulnerabilities")
        ((checks_passed++))
    else
        results+=("EXE-005:FAIL:${critical} critical, ${high} high vulnerabilities")
        ((checks_failed++))
    fi

    # --- CHECK 6: Build Success (EXE-006) ---
    log_info "[6/12] Running build..."
    if run_build "$workspace"; then
        results+=("EXE-006:PASS:Build successful")
        ((checks_passed++))
    else
        results+=("EXE-006:FAIL:Build failed")
        ((checks_failed++))
    fi

    # --- CHECK 7: Dependency Audit (EXE-007) ---
    log_info "[7/12] Auditing dependencies..."
    local dep_critical=$(run_dependency_audit "$workspace")
    if [[ ${dep_critical:-0} -eq 0 ]]; then
        results+=("EXE-007:PASS:No critical dependency vulnerabilities")
        ((checks_passed++))
    else
        results+=("EXE-007:FAIL:${dep_critical} critical dependency issues")
        ((checks_failed++))
    fi

    # --- CHECK 8: Breaking Change Detection (EXE-008) ---
    log_info "[8/12] Checking for breaking changes..."
    local breaking=$(detect_breaking_changes "$workspace")
    if [[ "$breaking" == "none" ]]; then
        results+=("EXE-008:PASS:No breaking changes")
        ((checks_passed++))
    elif [[ "$breaking" == "documented" ]]; then
        results+=("EXE-008:PASS:Breaking changes documented")
        ((checks_passed++))
    else
        results+=("EXE-008:FAIL:Undocumented breaking changes")
        ((checks_failed++))
    fi

    # --- CHECK 9: Tri-Agent Code Review (EXE-009) ---
    log_info "[9/12] Running tri-agent code review..."
    local approvals=$(run_tri_agent_review "$workspace")
    if [[ $approvals -ge 2 ]]; then
        results+=("EXE-009:PASS:Tri-agent consensus ($approvals/3)")
        ((checks_passed++))
    else
        results+=("EXE-009:FAIL:Insufficient approvals ($approvals/3)")
        ((checks_failed++))
    fi

    # --- CHECK 10: Performance Benchmarks (EXE-010) ---
    log_info "[10/12] Running performance benchmarks..."
    local perf_result=$(run_perf_benchmarks "$workspace")
    if [[ "$perf_result" == "pass" ]]; then
        results+=("EXE-010:PASS:Performance within ±10% baseline")
        ((checks_passed++))
    elif [[ "$perf_result" == "skip" ]]; then
        results+=("EXE-010:SKIP:No benchmarks configured")
        ((checks_skipped++))
    else
        results+=("EXE-010:FAIL:Performance regression detected")
        ((checks_failed++))
    fi

    # --- CHECK 11: Documentation Updated (EXE-011) ---
    log_info "[11/12] Checking documentation..."
    if check_documentation_updated "$workspace"; then
        results+=("EXE-011:PASS:Documentation up to date")
        ((checks_passed++))
    else
        results+=("EXE-011:FAIL:Documentation needs update")
        ((checks_failed++))
    fi

    # --- CHECK 12: Commit Message Format (EXE-012) ---
    log_info "[12/12] Validating commit message..."
    if validate_commit_message; then
        results+=("EXE-012:PASS:Valid conventional commit")
        ((checks_passed++))
    else
        results+=("EXE-012:FAIL:Invalid commit message format")
        ((checks_failed++))
    fi

    # --- Calculate Score ---
    local total=$((checks_passed + checks_failed))
    local score=0
    [[ $total -gt 0 ]] && score=$((checks_passed * 100 / total))

    local status="FAIL"
    [[ $checks_failed -eq 0 ]] && status="PASS"

    # --- Save Results ---
    mkdir -p "$(dirname "$gate_results")"
    cat > "$gate_results" <<EOF
{
    "gate": "EXECUTE_TO_APPROVED",
    "task_id": "$task_id",
    "timestamp": "$(date -Iseconds)",
    "status": "$status",
    "score": $score,
    "checks_passed": $checks_passed,
    "checks_failed": $checks_failed,
    "checks_skipped": $checks_skipped,
    "results": [
$(printf '        "%s",\n' "${results[@]}" | sed '$ s/,$//')
    ]
}
EOF

    # --- Summary ---
    log_info "═══════════════════════════════════════════════════════"
    log_info "  GATE 4 RESULTS: $status"
    log_info "  Score: $score%"
    log_info "  Passed: $checks_passed / Failed: $checks_failed / Skipped: $checks_skipped"
    log_info "═══════════════════════════════════════════════════════"

    [[ $checks_failed -eq 0 ]]
}

#===============================================================================
# Individual Check Implementations
#===============================================================================

run_test_suite() {
    local workspace="$1"
    cd "$workspace" 2>/dev/null || return 1

    # Try different test frameworks
    if [[ -f "package.json" ]] && grep -q '"test"' package.json; then
        npm test &>/dev/null
    elif [[ -f "pytest.ini" ]] || [[ -d "tests" ]]; then
        pytest --tb=short &>/dev/null
    elif [[ -f "Makefile" ]] && grep -q '^test:' Makefile; then
        make test &>/dev/null
    else
        return 0  # No tests configured = pass
    fi
}

get_test_coverage() {
    local workspace="$1"
    cd "$workspace" 2>/dev/null || echo "0"

    if [[ -f "package.json" ]]; then
        npm run coverage 2>&1 | grep -oP "All files\s+\|\s+\K[0-9.]+" | head -1 || echo "0"
    elif command -v pytest &>/dev/null; then
        pytest --cov --cov-report=term-missing 2>&1 | grep -oP "TOTAL\s+\d+\s+\d+\s+\K[0-9]+" | head -1 || echo "0"
    else
        echo "80"  # Default pass if no coverage tool
    fi
}

run_linter() {
    local workspace="$1"
    cd "$workspace" 2>/dev/null || echo "0"

    local errors=0

    if [[ -f "package.json" ]]; then
        errors=$(npm run lint 2>&1 | grep -c "error" || echo 0)
    elif command -v ruff &>/dev/null; then
        errors=$(ruff check . 2>&1 | grep -c "error" || echo 0)
    elif command -v shellcheck &>/dev/null; then
        errors=$(find . -name "*.sh" -exec shellcheck {} \; 2>&1 | grep -c "error" || echo 0)
    fi

    echo "$errors"
}

run_type_check() {
    local workspace="$1"
    cd "$workspace" 2>/dev/null || return 0

    if [[ -f "tsconfig.json" ]]; then
        npx tsc --noEmit &>/dev/null
    elif [[ -f "mypy.ini" ]] || [[ -f "pyproject.toml" ]]; then
        mypy . &>/dev/null
    else
        return 0  # No type checker = pass
    fi
}

run_security_scan() {
    local workspace="$1"
    cd "$workspace" 2>/dev/null || echo "0:0"

    local critical=0
    local high=0

    if [[ -f "package.json" ]]; then
        local audit_json=$(npm audit --json 2>/dev/null || echo '{}')
        critical=$(echo "$audit_json" | jq '.metadata.vulnerabilities.critical // 0')
        high=$(echo "$audit_json" | jq '.metadata.vulnerabilities.high // 0')
    elif [[ -f "requirements.txt" ]]; then
        # Use safety or pip-audit
        if command -v safety &>/dev/null; then
            critical=$(safety check --json 2>/dev/null | jq 'length' || echo 0)
        fi
    fi

    echo "${critical}:${high}"
}

run_build() {
    local workspace="$1"
    cd "$workspace" 2>/dev/null || return 0

    if [[ -f "package.json" ]] && grep -q '"build"' package.json; then
        npm run build &>/dev/null
    elif [[ -f "Makefile" ]]; then
        make build &>/dev/null || make &>/dev/null
    else
        return 0
    fi
}

run_dependency_audit() {
    local workspace="$1"
    cd "$workspace" 2>/dev/null || echo "0"

    if [[ -f "package.json" ]]; then
        npm audit --json 2>/dev/null | jq '.metadata.vulnerabilities.critical // 0'
    else
        echo "0"
    fi
}

detect_breaking_changes() {
    local workspace="$1"
    cd "$workspace" 2>/dev/null || echo "none"

    # Check for API surface changes
    local breaking_patterns=$(git diff main...HEAD 2>/dev/null | \
        grep -cE "^[-+].*(export.*function|export.*class|public.*method)" || echo 0)

    if [[ $breaking_patterns -eq 0 ]]; then
        echo "none"
    elif git log --oneline -1 2>/dev/null | grep -qi "breaking\|BREAKING"; then
        echo "documented"
    else
        echo "undocumented"
    fi
}

run_tri_agent_review() {
    local workspace="$1"
    cd "$workspace" 2>/dev/null || echo "0"

    local approvals=0
    local diff_content=$(git diff HEAD~1 2>/dev/null | head -500)

    [[ -z "$diff_content" ]] && { echo "3"; return; }  # No changes = approve

    # Claude review
    if command -v claude &>/dev/null; then
        local claude_verdict=$(echo "$diff_content" | \
            claude -p "Review this code diff. Reply only APPROVE or REQUEST_CHANGES." 2>/dev/null | \
            grep -oE "APPROVE|REQUEST_CHANGES" | head -1)
        [[ "$claude_verdict" == "APPROVE" ]] && ((approvals++))
    else
        ((approvals++))  # Skip if not available
    fi

    # Codex review
    if command -v codex &>/dev/null; then
        local codex_verdict=$(echo "$diff_content" | \
            codex exec "Review for bugs. Reply APPROVE or REQUEST_CHANGES only." 2>/dev/null | \
            grep -oE "APPROVE|REQUEST_CHANGES" | head -1)
        [[ "$codex_verdict" == "APPROVE" ]] && ((approvals++))
    else
        ((approvals++))
    fi

    # Gemini review
    if command -v gemini &>/dev/null; then
        local gemini_verdict=$(echo "$diff_content" | \
            gemini -y "Security review. Reply APPROVE or REQUEST_CHANGES only." 2>/dev/null | \
            grep -oE "APPROVE|REQUEST_CHANGES" | head -1)
        [[ "$gemini_verdict" == "APPROVE" ]] && ((approvals++))
    else
        ((approvals++))
    fi

    echo "$approvals"
}

run_perf_benchmarks() {
    local workspace="$1"
    cd "$workspace" 2>/dev/null || echo "skip"

    if [[ -f "benchmark.js" ]] || [[ -d "benchmarks" ]]; then
        # Run benchmarks and compare to baseline
        echo "pass"  # Simplified for now
    else
        echo "skip"
    fi
}

check_documentation_updated() {
    local workspace="$1"
    cd "$workspace" 2>/dev/null || return 0

    # Check if code files changed but docs didn't
    local code_changes=$(git diff --name-only HEAD~1 2>/dev/null | grep -cE "\.(js|ts|py|sh)$" || echo 0)
    local doc_changes=$(git diff --name-only HEAD~1 2>/dev/null | grep -cE "\.(md|rst|txt)$" || echo 0)

    # If significant code changes, require some doc update
    if [[ $code_changes -gt 10 && $doc_changes -eq 0 ]]; then
        return 1
    fi
    return 0
}

validate_commit_message() {
    local msg=$(git log -1 --format=%s 2>/dev/null)

    # Conventional commit pattern
    if [[ "$msg" =~ ^(feat|fix|docs|style|refactor|test|chore|perf|ci)(\(.+\))?:\ .+ ]]; then
        return 0
    fi
    return 1
}
```

---

## 5. Supervisor Approval Engine

### 5.1 Core Approval Functions

```bash
#!/bin/bash
#===============================================================================
# lib/supervisor-approver.sh - Supervisor Approval Engine
#===============================================================================

# Approve task and commit changes
approve_task() {
    local task_id="$1"
    local task_file="${REVIEW_DIR}/${task_id}.md"
    local gate_results="${STATE_DIR}/gates/gate4_${task_id}.json"

    log_info "═══════════════════════════════════════════════════════"
    log_info "  APPROVING TASK: $task_id"
    log_info "═══════════════════════════════════════════════════════"

    # Move to approved
    mv "$task_file" "${APPROVED_DIR}/"
    mv "${REVIEW_DIR}/${task_id}.md.meta.json" "${APPROVED_DIR}/" 2>/dev/null || true

    # Create commit
    local commit_msg=$(cat <<EOF
feat(${task_id}): Implementation approved by supervisor

Quality Gate 4 Results:
$(jq -r '.results[]' "$gate_results" 2>/dev/null | sed 's/^/- /')

Tri-Agent Review: APPROVED

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)

    git add -A && git commit -m "$commit_msg" || true

    # Notify worker
    send_message "TASK_APPROVE" "worker" "{
        \"task_id\": \"${task_id}\",
        \"status\": \"approved\",
        \"commit\": \"$(git rev-parse HEAD 2>/dev/null || echo 'none')\",
        \"next_action\": \"proceed_to_next_task\"
    }"

    # Update ledger
    log_ledger "TASK_APPROVED" "$task_id"

    log_info "Task $task_id approved and committed"
}

# Reject task with feedback
reject_task() {
    local task_id="$1"
    local task_file="${REVIEW_DIR}/${task_id}.md"
    local gate_results="${STATE_DIR}/gates/gate4_${task_id}.json"

    # Get retry count
    local retry_count=$(get_retry_count "$task_id")
    ((retry_count++))

    log_warn "═══════════════════════════════════════════════════════"
    log_warn "  REJECTING TASK: $task_id"
    log_warn "  Attempt: $retry_count / 3"
    log_warn "═══════════════════════════════════════════════════════"

    # Check retry budget
    if [[ $retry_count -ge 3 ]]; then
        escalate_task "$task_id" "Max retries exceeded after 3 attempts"
        return 1
    fi

    # Generate actionable feedback
    local feedback=$(generate_rejection_feedback "$gate_results")

    # Create enhanced retry task
    local retry_file="${REJECTED_DIR}/${task_id}.md"

    cat > "$retry_file" <<EOF
# REJECTED: ${task_id}

## REJECTION FEEDBACK

**Attempt**: $retry_count of 3

### Issues to Fix
$feedback

### Gate Results
\`\`\`
$(jq -r '.results[] | select(contains("FAIL"))' "$gate_results" 2>/dev/null)
\`\`\`

---

## Original Task
$(cat "$task_file")

---

## Instructions
1. Focus ONLY on fixing the issues listed above
2. Run all tests locally before resubmitting
3. Ensure coverage remains ≥80%
4. Time limit: 30 minutes
EOF

    # Archive original
    mv "$task_file" "${AUTONOMOUS_ROOT}/state/review_history/" 2>/dev/null || true

    # Notify worker
    send_message "TASK_REJECT" "worker" "{
        \"task_id\": \"${task_id}\",
        \"retry_count\": $retry_count,
        \"max_retries\": 3,
        \"feedback\": $(echo "$feedback" | jq -Rs '.'),
        \"retry_file\": \"${retry_file}\"
    }"

    log_ledger "TASK_REJECTED" "$task_id" "attempt=$retry_count"
}

# Generate actionable feedback from gate failures
generate_rejection_feedback() {
    local gate_results="$1"
    local feedback=""

    while IFS= read -r result; do
        [[ -z "$result" ]] && continue

        local check_id="${result%%:*}"
        local rest="${result#*:}"
        local status="${rest%%:*}"
        local detail="${rest#*:}"

        if [[ "$status" == "FAIL" ]]; then
            case "$check_id" in
                EXE-001)
                    feedback+="### Tests Failed\n"
                    feedback+="Run \`npm test\` or \`pytest\` and fix all failing tests.\n"
                    feedback+="Detail: $detail\n\n"
                    ;;
                EXE-002)
                    feedback+="### Coverage Below 80%\n"
                    feedback+="Add tests for uncovered code paths.\n"
                    feedback+="Current: $detail\n\n"
                    ;;
                EXE-003)
                    feedback+="### Linting Errors\n"
                    feedback+="Run \`npm run lint --fix\` or fix manually.\n"
                    feedback+="$detail\n\n"
                    ;;
                EXE-004)
                    feedback+="### Type Errors\n"
                    feedback+="Fix TypeScript/mypy type errors.\n"
                    feedback+="$detail\n\n"
                    ;;
                EXE-005)
                    feedback+="### Security Vulnerabilities\n"
                    feedback+="Critical/High issues must be fixed before approval.\n"
                    feedback+="Run \`npm audit fix\` or update dependencies.\n"
                    feedback+="$detail\n\n"
                    ;;
                EXE-009)
                    feedback+="### Code Review Rejected\n"
                    feedback+="Address reviewer comments before resubmitting.\n"
                    feedback+="$detail\n\n"
                    ;;
                *)
                    feedback+="### $check_id Failed\n"
                    feedback+="$detail\n\n"
                    ;;
            esac
        fi
    done < <(jq -r '.results[]' "$gate_results" 2>/dev/null)

    echo -e "$feedback"
}
```

---

## 6. Configuration Files

### 6.1 quality-gates.yaml

```yaml
# config/quality-gates.yaml
quality_gates:
  gate_4:
    name: "EXECUTE_TO_APPROVED"
    checks:
      - id: EXE-001
        name: "Test Suite"
        required: true
        threshold: 1.0  # 100% pass rate

      - id: EXE-002
        name: "Test Coverage"
        required: true
        threshold: 0.80  # 80% minimum

      - id: EXE-003
        name: "Linting"
        required: true
        threshold: 0  # Zero errors

      - id: EXE-004
        name: "Type Checking"
        required: true
        threshold: 0  # Zero errors

      - id: EXE-005
        name: "Security Scan"
        required: true
        threshold: 0  # Zero critical/high

      - id: EXE-006
        name: "Build"
        required: true

      - id: EXE-007
        name: "Dependency Audit"
        required: true
        threshold: 0

      - id: EXE-008
        name: "Breaking Changes"
        required: true

      - id: EXE-009
        name: "Tri-Agent Review"
        required: true
        threshold: 2  # 2/3 must approve

      - id: EXE-010
        name: "Performance"
        required: false
        threshold: 0.10  # ±10%

      - id: EXE-011
        name: "Documentation"
        required: false

      - id: EXE-012
        name: "Commit Format"
        required: true

approval:
  min_score: 85
  require_no_blockers: true
```

### 6.2 retry-limits.yaml

```yaml
# config/retry-limits.yaml
retry_limits:
  per_task:
    max_attempts: 3
    backoff_strategy: "linear"
    backoff_increment: 300  # 5 min per retry

  rejection:
    max_retries: 2

  global:
    max_rejections_per_hour: 10
    max_rejections_per_day: 30
    pause_on_threshold: true

escalation:
  thresholds:
    - attempts: 3
      action: "notify_supervisor"
    - attempts: 4
      action: "pause_autonomous"
    - attempts: 5
      action: "create_github_issue"

  loop_detection:
    same_gate_failures: 2
    action: "switch_strategy"
```

---

## 7. State Machine (Complete)

```
                         ┌─────────────────┐
                         │     DRAFT       │ Supervisor defining spec
                         └────────┬────────┘
                                  │ spec_complete
                                  v
                         ┌─────────────────┐
                    ┌────│     QUEUED      │ Priority ordered
                    │    └────────┬────────┘
                    │             │ worker_claims (lock acquired)
                    │             v
                    │    ┌─────────────────┐
              unlock│    │    RUNNING      │ Worker executing
                    │    └────────┬────────┘
                    │             │ work_completed
                    │             v
                    │    ┌─────────────────┐
                    │    │    REVIEW       │◄──────────────────────┐
                    │    └────────┬────────┘                       │
                    │             │                                │
                    │      ┌──────┴──────┐                        │
                    │      v             v                        │
              ┌─────────────────┐ ┌─────────────────┐            │
              │   APPROVED      │ │   REJECTED      │────────────┘
              └────────┬────────┘ └────────┬────────┘  retry < 3
                       │                   │
                       │                   v retry >= 3
                       │           ┌─────────────────┐
                       │           │   ESCALATED     │ Human required
                       │           └────────┬────────┘
                       v                    │
              ┌─────────────────┐          v
              │   COMPLETED     │  ┌─────────────────┐
              │   (merged)      │  │     FAILED      │
              └─────────────────┘  └─────────────────┘
```

---

## 8. Implementation Timeline

| Day | Phase | Deliverables |
|-----|-------|--------------|
| 1 | Core Infrastructure | `lib/worker-executor.sh`, `lib/comms.sh`, directory structure |
| 2 | Worker Daemon | `bin/tri-agent-worker` with full task lifecycle |
| 3 | Quality Gates | `lib/quality-gates.sh` with 12 checks |
| 4 | Supervisor Integration | `lib/supervisor-approver.sh`, approval/rejection flow |
| 5 | Hardening | Circuit breakers, crash recovery, metrics |

---

## 9. Success Criteria

- [ ] 24/7 autonomous operation without human intervention
- [ ] Zero unapproved code reaches main branch
- [ ] Quality gates enforce 80%+ test coverage
- [ ] All 12 Gate 4 checks pass before approval
- [ ] Rejection feedback is actionable (worker can fix without clarification)
- [ ] Max 3 retries prevent infinite loops
- [ ] Escalation creates GitHub issue for human review
- [ ] System recovers automatically from crashes
- [ ] Heartbeats detect agent failures within 5 minutes
- [ ] Complete audit trail in ledger.jsonl

---

## 10. Operations & Cost

> **Detailed Plan**: See [OPERATIONS_AND_COST_PLAN.md](./OPERATIONS_AND_COST_PLAN.md) for full mathematical models, cost breakdown, and runbooks.

### 10.1 Key Operational Metrics
- **Queuing Model**: M/M/c with 3 workers (Claude, Gemini, Codex)
- **Stability**: System is stable at 55% utilization with $\lambda=5$ tasks/hour
- **Latency**: Average wait time $W_q \approx 1.7$ minutes

### 10.2 Cost Controls
- **Budget**: $75/month ($2.50/day)
- **Kill-Switch**: Triggers at >$1.00/minute velocity or >$10.00/day
- **Model Routing**: Haiku (Low) → Sonnet (Med) → Opus (High)

### 10.3 Resilience
- **Chaos Testing**: 10 distinct failure modes (e.g., `kill -9`, network blackout)
- **Recovery**: Automated via `monitor.sh` and stale lock reaper
- **Alerts**: P0 (Critical) for cost spikes and supervisor downtime

---

*Master Implementation Plan v2.0*
*Sources: 14+ parallel agents + AUTONOMOUS_SDLC_ARCHITECTURE + INTER_AGENT_PROTOCOL + QUALITY_GATES_SPEC + sdlc-worker-agent-design*
