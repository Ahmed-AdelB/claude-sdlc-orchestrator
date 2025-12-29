# Implementation Roadmap: v4.0 to v5.0

**Date**: 2025-12-28
**Author**: Claude Opus 4.5 (ULTRATHINK)
**Based On**: Tri-Agent Discussion Log (Claude + Gemini + Codex)
**Target Score**: 87/100 -> 95/100

---

## Executive Summary

This roadmap addresses the critical issues identified during the tri-agent consensus discussion. The current v4.0 system has a **production readiness score of 87/100** but suffers from:

1. **State Corruption Risk (80% probability)** - JSON files with concurrent access
2. **Consensus Hallucination Cascade (90% probability)** - Same model family for all agents
3. **Single Worker Bottleneck** - M/M/1 queue model limits throughput to 72 tasks/day
4. **Missing Persistent Memory** - No RAG context store across sessions
5. **Inadequate Budget Controls** - $50 limit with no tiered throttling

---

## Phase 1: Critical Fixes (Week 1)

### Priority: MAXIMUM - These prevent system failure

---

### 1.1 SQLite Migration (Replaces JSON State Files)

**Problem**: File-based state with `flock` still vulnerable to corruption under high concurrency.

**Current Code Location**: `/home/aadel/projects/claude-sdlc-orchestrator/v2/lib/state.sh`

**Files to Modify**:
- `lib/state.sh` (622 lines) - Replace with SQLite wrapper
- `lib/common.sh` (570 lines) - Update sourcing
- `bin/tri-agent-worker` (1380 lines) - Use new state API

**New File**: `lib/sqlite-state.sh`

```bash
# Before (state.sh lines 350-405): File-based state_get/state_set
state_get() {
    local file="$1"
    local key="$2"
    local default="${3:-}"
    if [[ -f "$file" ]]; then
        value=$(grep -E "^${key}=" "$file" 2>/dev/null | head -1 | cut -d'=' -f2-)
        echo "${value:-$default}"
    else
        echo "$default"
    fi
}

# After: SQLite-based state management
STATE_DB="${AUTONOMOUS_ROOT}/state/tri-agent.db"

_init_sqlite_db() {
    sqlite3 "$STATE_DB" <<'SQL'
    CREATE TABLE IF NOT EXISTS state (
        file_path TEXT NOT NULL,
        key TEXT NOT NULL,
        value TEXT,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (file_path, key)
    );
    CREATE TABLE IF NOT EXISTS tasks (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        priority TEXT DEFAULT 'MEDIUM',
        status TEXT DEFAULT 'pending',
        worker_id TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        started_at DATETIME,
        completed_at DATETIME,
        retry_count INTEGER DEFAULT 0,
        trace_id TEXT
    );
    CREATE TABLE IF NOT EXISTS events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        event_type TEXT NOT NULL,
        task_id TEXT,
        worker_id TEXT,
        details TEXT,
        trace_id TEXT
    );
    CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
    CREATE INDEX IF NOT EXISTS idx_tasks_priority ON tasks(priority);
    CREATE INDEX IF NOT EXISTS idx_events_task ON events(task_id);
SQL
}

state_get() {
    local file="$1"
    local key="$2"
    local default="${3:-}"
    local result
    result=$(sqlite3 "$STATE_DB" \
        "SELECT value FROM state WHERE file_path='$file' AND key='$key' LIMIT 1;" 2>/dev/null)
    echo "${result:-$default}"
}

state_set() {
    local file="$1"
    local key="$2"
    local value="$3"
    sqlite3 "$STATE_DB" \
        "INSERT OR REPLACE INTO state (file_path, key, value, updated_at)
         VALUES ('$file', '$key', '$value', CURRENT_TIMESTAMP);"
}
```

**Schema Design**:

```sql
-- Core tables for v5.0
CREATE TABLE tasks (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT,  -- feature, bugfix, security, etc.
    priority TEXT CHECK(priority IN ('CRITICAL', 'HIGH', 'MEDIUM', 'LOW')),
    status TEXT CHECK(status IN ('pending', 'running', 'review', 'completed', 'failed', 'escalated')),
    worker_id TEXT,
    content TEXT,  -- Full task markdown
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    started_at DATETIME,
    completed_at DATETIME,
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    trace_id TEXT,
    parent_task_id TEXT,  -- For rejection retries
    FOREIGN KEY (parent_task_id) REFERENCES tasks(id)
);

CREATE TABLE events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    event_type TEXT NOT NULL,
    task_id TEXT,
    worker_id TEXT,
    model TEXT,
    details JSON,
    trace_id TEXT,
    FOREIGN KEY (task_id) REFERENCES tasks(id)
);

CREATE TABLE breakers (
    model TEXT PRIMARY KEY,
    state TEXT CHECK(state IN ('CLOSED', 'OPEN', 'HALF_OPEN')),
    failure_count INTEGER DEFAULT 0,
    last_failure DATETIME,
    last_success DATETIME,
    half_open_calls INTEGER DEFAULT 0
);

CREATE TABLE costs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    model TEXT NOT NULL,
    input_tokens INTEGER,
    output_tokens INTEGER,
    duration_ms INTEGER,
    task_type TEXT,
    trace_id TEXT
);

-- Materialized views for performance
CREATE VIEW daily_costs AS
SELECT
    date(timestamp) as day,
    model,
    COUNT(*) as requests,
    SUM(input_tokens) as total_input,
    SUM(output_tokens) as total_output,
    AVG(duration_ms) as avg_duration
FROM costs
GROUP BY date(timestamp), model;
```

**Estimated Lines of Code**: ~300 new lines, ~200 modified
**Testing Required**: Unit tests for ACID compliance, concurrent access stress tests

---

### 1.2 Budget Watchdog with Kill-Switch

**Problem**: $50 budget with $36 baseline leaves only $14 margin. No kill-switch for runaway costs.

**Current Code Location**: `/home/aadel/projects/claude-sdlc-orchestrator/v2/lib/cost-tracker.sh`

**Files to Modify**:
- `lib/cost-tracker.sh` (623 lines) - Add rate monitoring
- `config/tri-agent.yaml` - Update budget config

**New Function**: Add to `cost-tracker.sh`

```bash
# Before: Simple tracking, no enforcement
record_request() {
    # ... just logs to JSONL
}

# After: Add rate monitoring and kill-switch
SPEND_RATE_LIMIT=1.00  # $1.00/minute = hard kill
SPEND_RATE_WARN=0.50   # $0.50/minute = warning
BUDGET_POOLS=(
    "baseline:50"    # Normal operation
    "retry:15"       # Retry budget
    "emergency:10"   # Emergency tasks only
)

check_spend_rate() {
    local window_minutes="${1:-5}"
    local recent_cost

    # Query SQLite for recent spend
    recent_cost=$(sqlite3 "$STATE_DB" "
        SELECT COALESCE(SUM(
            CASE model
                WHEN 'claude' THEN (input_tokens * 0.000015 + output_tokens * 0.000075)
                WHEN 'gemini' THEN (input_tokens * 0.0000025 + output_tokens * 0.000010)
                WHEN 'codex' THEN (input_tokens * 0.000010 + output_tokens * 0.000030)
            END
        ), 0)
        FROM costs
        WHERE timestamp > datetime('now', '-$window_minutes minutes');
    ")

    local rate_per_min
    rate_per_min=$(awk "BEGIN {printf \"%.4f\", $recent_cost / $window_minutes}")

    if (( $(echo "$rate_per_min > $SPEND_RATE_LIMIT" | bc -l) )); then
        log_error "BUDGET KILL-SWITCH: Rate \$${rate_per_min}/min exceeds limit"
        # Kill all running workers
        pkill -f "tri-agent-worker" || true
        # Notify supervisor
        send_message "BUDGET_KILLSWITCH" "supervisor" "{\"rate\": $rate_per_min}"
        return 1
    elif (( $(echo "$rate_per_min > $SPEND_RATE_WARN" | bc -l) )); then
        log_warn "BUDGET WARNING: Rate \$${rate_per_min}/min approaching limit"
    fi

    return 0
}

# Call before every model invocation
pre_request_check() {
    local model="$1"
    local estimated_tokens="$2"

    # Check rate
    check_spend_rate 5 || return 1

    # Check pool availability
    local pool_budget
    pool_budget=$(get_available_budget)
    if (( pool_budget < 1 )); then
        log_error "No budget available, pausing worker"
        return 1
    fi

    return 0
}
```

**Config Update** (`config/tri-agent.yaml`):

```yaml
cost_tracking:
  enabled: true
  # Raise budget from $50 to $75 with tiers
  budget:
    total_daily: 75
    pools:
      baseline: 50      # Normal operation
      retry: 15         # Retries get separate budget
      emergency: 10     # CRITICAL tasks only

  # Kill-switch thresholds
  rate_limits:
    warn_per_minute: 0.50
    kill_per_minute: 1.00
    window_minutes: 5

  # Throttling policy
  throttling:
    - threshold: 0.80   # 80% of daily budget
      action: "reduce_parallelism"
      parallelism: 1    # Drop to 1 worker
    - threshold: 0.90   # 90% of daily budget
      action: "critical_only"
    - threshold: 0.95   # 95% of daily budget
      action: "pause"
```

**Estimated Lines of Code**: ~150 new lines, ~50 modified
**Testing Required**: Simulate runaway cost scenarios, verify kill-switch triggers

---

### 1.3 Progressive Heartbeat (Task-Aware Timeouts)

**Problem**: 300s one-size-fits-all timeout causes false positives for long tasks.

**Current Code Location**: `/home/aadel/projects/claude-sdlc-orchestrator/v2/bin/tri-agent-worker` (lines 1118-1154)

**Files to Modify**:
- `bin/tri-agent-worker` - Update heartbeat logic
- `config/tri-agent.yaml` - Add timeout profiles

**Before** (tri-agent-worker lines 1118-1154):

```bash
HEARTBEAT_INTERVAL="${HEARTBEAT_INTERVAL:-60}"

send_heartbeat() {
    local status="idle"
    if [[ -n "$CURRENT_TASK" ]]; then
        status="busy"
    fi
    # Update lock file
    cat > "${WORKER_LOCKS_DIR}/worker.lock" <<EOF
{
    "worker_id": "$WORKER_ID",
    "heartbeat": "$(date -Iseconds)",
    "status": "$status",
    ...
}
EOF
}
```

**After**:

```bash
# Task-type-aware timeout profiles
declare -A TIMEOUT_PROFILES=(
    ["quick"]=120       # Simple queries, 2 min
    ["standard"]=300    # Normal tasks, 5 min
    ["complex"]=600     # Complex implementation, 10 min
    ["research"]=900    # Research/analysis, 15 min
    ["consensus"]=1200  # Tri-agent consensus, 20 min
    ["security"]=1800   # Security audits, 30 min
)

get_task_timeout() {
    local task_type="${1:-general}"

    case "$task_type" in
        security|audit)     echo "${TIMEOUT_PROFILES[security]}" ;;
        research|design)    echo "${TIMEOUT_PROFILES[research]}" ;;
        feature|refactor)   echo "${TIMEOUT_PROFILES[complex]}" ;;
        bugfix|testing)     echo "${TIMEOUT_PROFILES[standard]}" ;;
        *)                  echo "${TIMEOUT_PROFILES[standard]}" ;;
    esac
}

send_heartbeat() {
    local status="idle"
    local current_task=""
    local expected_completion=""
    local progress_percent=0

    if [[ -n "$CURRENT_TASK" ]]; then
        status="busy"
        current_task="$CURRENT_TASK"

        # Calculate expected completion based on task type
        local timeout
        timeout=$(get_task_timeout "$TASK_TYPE")
        local elapsed=$(($(date +%s) - TASK_START_TIME))
        progress_percent=$((elapsed * 100 / timeout))

        # Clamp to 99% max (100% = completed)
        [[ $progress_percent -gt 99 ]] && progress_percent=99
    fi

    # Store in SQLite for supervisor query
    sqlite3 "$STATE_DB" "
        INSERT OR REPLACE INTO worker_heartbeats
        (worker_id, timestamp, status, task_id, task_type, progress_percent, expected_timeout)
        VALUES (
            '$WORKER_ID',
            datetime('now'),
            '$status',
            '$current_task',
            '$TASK_TYPE',
            $progress_percent,
            $(get_task_timeout "$TASK_TYPE")
        );
    "
}

# Supervisor: Detect stale workers with task-aware thresholds
check_worker_health() {
    local stale_workers
    stale_workers=$(sqlite3 "$STATE_DB" "
        SELECT worker_id, task_id, task_type,
               (julianday('now') - julianday(timestamp)) * 86400 as age_seconds,
               expected_timeout
        FROM worker_heartbeats
        WHERE status = 'busy'
          AND (julianday('now') - julianday(timestamp)) * 86400 > expected_timeout * 1.5
    ")

    while IFS='|' read -r worker task task_type age timeout; do
        [[ -z "$worker" ]] && continue
        log_warn "Worker $worker exceeded timeout: task=$task type=$task_type age=${age}s timeout=${timeout}s"
        # Recover task
        recover_stale_task "$task" "$worker"
    done <<< "$stale_workers"
}
```

**Estimated Lines of Code**: ~100 new lines, ~50 modified
**Testing Required**: Simulate long-running tasks, verify no false timeout alerts

---

## Phase 2: Architecture Improvements (Weeks 2-3)

### Priority: HIGH - These improve throughput and reliability

---

### 2.1 Worker Pool Implementation (M/M/c Model)

**Problem**: Single worker (M/M/1) bottleneck limits throughput to 72 tasks/day.

**Current Analysis**:
- Current: 1 worker, 20-minute avg service time = 3 tasks/hour = 72 tasks/day
- Target: 3 workers (M/M/c) = 9 tasks/hour = 216 tasks/day (3x improvement)

**New File**: `bin/tri-agent-pool`

```bash
#!/bin/bash
#===============================================================================
# tri-agent-pool - Worker Pool Manager
#===============================================================================
# Manages multiple tri-agent-worker instances with:
# - Dynamic scaling based on queue depth
# - Task-type sharding (security vs. implementation)
# - Load balancing across workers
#===============================================================================

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

# Pool configuration
MIN_WORKERS=1
MAX_WORKERS=3
SCALE_UP_THRESHOLD=5      # Queue depth to add worker
SCALE_DOWN_THRESHOLD=1    # Queue depth to remove worker
SCALE_CHECK_INTERVAL=60   # Seconds between scale checks

# Worker registry in SQLite
init_pool_schema() {
    sqlite3 "$STATE_DB" <<'SQL'
    CREATE TABLE IF NOT EXISTS workers (
        worker_id TEXT PRIMARY KEY,
        pid INTEGER,
        status TEXT CHECK(status IN ('starting', 'idle', 'busy', 'stopping', 'dead')),
        specialization TEXT,  -- 'security' | 'implementation' | 'general'
        started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        last_heartbeat DATETIME,
        tasks_completed INTEGER DEFAULT 0
    );
SQL
}

# Start a new worker with optional specialization
start_worker() {
    local specialization="${1:-general}"
    local worker_id="worker-$(date +%s)-$$"

    # Check if we're at max
    local current_count
    current_count=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM workers WHERE status NOT IN ('dead', 'stopping');")

    if [[ $current_count -ge $MAX_WORKERS ]]; then
        log_warn "Cannot start worker: at max capacity ($MAX_WORKERS)"
        return 1
    fi

    # Start worker process
    WORKER_ID="$worker_id" \
    WORKER_SPECIALIZATION="$specialization" \
    nohup "${PROJECT_ROOT}/bin/tri-agent-worker" \
        >> "${LOG_DIR}/worker-${worker_id}.log" 2>&1 &

    local pid=$!

    # Register in pool
    sqlite3 "$STATE_DB" "
        INSERT INTO workers (worker_id, pid, status, specialization)
        VALUES ('$worker_id', $pid, 'starting', '$specialization');
    "

    log_info "Started worker $worker_id (PID: $pid, spec: $specialization)"
}

# Scale workers based on queue depth
auto_scale() {
    local queue_depth
    queue_depth=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM tasks WHERE status = 'pending';")

    local active_workers
    active_workers=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM workers WHERE status IN ('idle', 'busy');")

    log_debug "Queue depth: $queue_depth, Active workers: $active_workers"

    if [[ $queue_depth -gt $SCALE_UP_THRESHOLD ]] && [[ $active_workers -lt $MAX_WORKERS ]]; then
        log_info "Scaling UP: queue=$queue_depth, workers=$active_workers"
        start_worker "general"
    elif [[ $queue_depth -lt $SCALE_DOWN_THRESHOLD ]] && [[ $active_workers -gt $MIN_WORKERS ]]; then
        log_info "Scaling DOWN: queue=$queue_depth, workers=$active_workers"
        stop_oldest_idle_worker
    fi
}

# Sharded task assignment (security tasks go to security-specialized worker)
assign_task_to_worker() {
    local task_id="$1"
    local task_type="$2"

    local target_worker=""

    if [[ "$task_type" == "security" ]]; then
        # Prefer security-specialized worker
        target_worker=$(sqlite3 "$STATE_DB" "
            SELECT worker_id FROM workers
            WHERE status = 'idle' AND specialization = 'security'
            LIMIT 1;
        ")
    fi

    if [[ -z "$target_worker" ]]; then
        # Fall back to any idle worker
        target_worker=$(sqlite3 "$STATE_DB" "
            SELECT worker_id FROM workers
            WHERE status = 'idle'
            ORDER BY tasks_completed ASC  -- Prefer less-loaded workers
            LIMIT 1;
        ")
    fi

    if [[ -n "$target_worker" ]]; then
        sqlite3 "$STATE_DB" "
            UPDATE tasks SET worker_id = '$target_worker', status = 'running'
            WHERE id = '$task_id';
            UPDATE workers SET status = 'busy' WHERE worker_id = '$target_worker';
        "
        log_info "Assigned task $task_id to worker $target_worker"
        return 0
    fi

    return 1  # No available workers
}

# Main pool management loop
main() {
    init_pool_schema

    # Start minimum workers
    for ((i=0; i<MIN_WORKERS; i++)); do
        start_worker "general"
    done

    while true; do
        # Health check existing workers
        check_worker_health

        # Auto-scale based on queue
        auto_scale

        # Assign pending tasks
        local pending_tasks
        pending_tasks=$(sqlite3 "$STATE_DB" "
            SELECT id, type FROM tasks
            WHERE status = 'pending'
            ORDER BY
                CASE priority
                    WHEN 'CRITICAL' THEN 1
                    WHEN 'HIGH' THEN 2
                    WHEN 'MEDIUM' THEN 3
                    WHEN 'LOW' THEN 4
                END,
                created_at ASC
            LIMIT 10;
        ")

        while IFS='|' read -r task_id task_type; do
            [[ -z "$task_id" ]] && continue
            assign_task_to_worker "$task_id" "$task_type" || break
        done <<< "$pending_tasks"

        sleep 5
    done
}

main "$@"
```

**Estimated Lines of Code**: ~400 new lines
**Testing Required**: Load tests with 3 concurrent workers, verify no race conditions

---

### 2.2 Priority Queue with Preemption

**Problem**: CRITICAL tasks wait behind MEDIUM tasks.

**Files to Modify**:
- `bin/tri-agent-worker` (lines 213-234) - Update `pick_next_task()`
- New: `lib/priority-queue.sh`

**Before** (tri-agent-worker lines 213-234):

```bash
pick_next_task() {
    for priority in CRITICAL HIGH MEDIUM LOW; do
        # Simple find with filename pattern
        while IFS= read -r line; do
            task_file="${line#* }"
            [[ -n "$task_file" && -f "$task_file" ]] && break
        done < <(find "$QUEUE_DIR" -name "${priority}_*.md" -type f -printf '%T+ %p\n' 2>/dev/null | sort | head -1)
        ...
    done
}
```

**After** (SQLite-based with preemption):

```bash
# lib/priority-queue.sh

# Get next task respecting priority, with preemption support
get_next_task() {
    local worker_id="$1"
    local current_priority="${2:-}"  # Current task priority (for preemption check)

    # Check for preemption opportunity
    if [[ -n "$current_priority" ]] && [[ "$current_priority" != "CRITICAL" ]]; then
        local critical_pending
        critical_pending=$(sqlite3 "$STATE_DB" "
            SELECT COUNT(*) FROM tasks
            WHERE status = 'pending' AND priority = 'CRITICAL';
        ")

        if [[ $critical_pending -gt 0 ]]; then
            log_warn "CRITICAL task pending - preemption available"
            return 2  # Signal preemption opportunity
        fi
    fi

    # Atomic task claim with transaction
    local task
    task=$(sqlite3 "$STATE_DB" "
        BEGIN IMMEDIATE;

        SELECT id, name, type, priority, content FROM tasks
        WHERE status = 'pending'
        ORDER BY
            CASE priority
                WHEN 'CRITICAL' THEN 1
                WHEN 'HIGH' THEN 2
                WHEN 'MEDIUM' THEN 3
                WHEN 'LOW' THEN 4
            END,
            created_at ASC
        LIMIT 1;

        UPDATE tasks SET
            status = 'running',
            worker_id = '$worker_id',
            started_at = datetime('now')
        WHERE id = (
            SELECT id FROM tasks
            WHERE status = 'pending'
            ORDER BY
                CASE priority
                    WHEN 'CRITICAL' THEN 1
                    WHEN 'HIGH' THEN 2
                    WHEN 'MEDIUM' THEN 3
                    WHEN 'LOW' THEN 4
                END,
                created_at ASC
            LIMIT 1
        );

        COMMIT;
    ")

    echo "$task"
}

# Checkpoint current task for preemption
checkpoint_task() {
    local task_id="$1"
    local checkpoint_data="$2"

    sqlite3 "$STATE_DB" "
        INSERT INTO task_checkpoints (task_id, checkpoint_data, created_at)
        VALUES ('$task_id', '$checkpoint_data', datetime('now'));

        UPDATE tasks SET status = 'paused' WHERE id = '$task_id';
    "
}

# Resume from checkpoint after preemption
resume_from_checkpoint() {
    local task_id="$1"

    local checkpoint
    checkpoint=$(sqlite3 "$STATE_DB" "
        SELECT checkpoint_data FROM task_checkpoints
        WHERE task_id = '$task_id'
        ORDER BY created_at DESC
        LIMIT 1;
    ")

    echo "$checkpoint"
}
```

**Preemption Flow**:

```
1. Worker processing MEDIUM task
2. CRITICAL task arrives
3. Supervisor signals worker: PREEMPT
4. Worker checkpoints current task state
5. Worker marks task as 'paused'
6. Worker picks up CRITICAL task
7. CRITICAL completes
8. Worker resumes paused task from checkpoint
```

**Estimated Lines of Code**: ~200 new lines
**Testing Required**: Verify preemption doesn't corrupt state, checkpoint/resume works

---

### 2.3 Model Diversity in Consensus (Break Hallucination Cascade)

**Problem**: Using same model family for consensus doesn't detect correlated hallucinations.

**Current**: Claude + Gemini + Codex all have overlapping training data, can hallucinate same errors.

**Solution**: Use different reasoning approaches per model.

**Files to Modify**:
- `bin/tri-agent-consensus` (create new)
- `config/tri-agent.yaml` - Add diversity config

**New File**: `bin/tri-agent-consensus`

```bash
#!/bin/bash
#===============================================================================
# tri-agent-consensus - Diverse Model Consensus
#===============================================================================
# Implements consensus with:
# 1. Model diversity (different prompting strategies per model)
# 2. Independent context windows (no shared context contamination)
# 3. Hallucination detection via cross-validation
#===============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

# Diverse prompting strategies
build_claude_prompt() {
    local question="$1"
    cat <<EOF
You are a senior software architect. Think step by step.

QUESTION: $question

Before answering:
1. Identify assumptions you're making
2. Consider edge cases
3. List potential risks

Provide your analysis with confidence level (0-100).
EOF
}

build_gemini_prompt() {
    local question="$1"
    cat <<EOF
You are a critical code reviewer focused on correctness.

QUESTION: $question

Use the following verification approach:
1. What could go wrong?
2. What has the asker potentially missed?
3. Cross-reference against common anti-patterns

Be skeptical. Challenge assumptions. Rate your confidence (0-100).
EOF
}

build_codex_prompt() {
    local question="$1"
    cat <<EOF
You are a pragmatic implementation expert.

QUESTION: $question

Focus on:
1. Is this implementable as described?
2. What are the hidden complexity traps?
3. Estimate effort and risk

Provide concrete implementation concerns. Confidence (0-100).
EOF
}

# Cross-validate responses for consistency
detect_hallucination() {
    local claude_response="$1"
    local gemini_response="$2"
    local codex_response="$3"

    # Extract key claims from each response
    local claude_claims=$(echo "$claude_response" | grep -E "^\*|^-|^[0-9]+\." | head -10)
    local gemini_claims=$(echo "$gemini_response" | grep -E "^\*|^-|^[0-9]+\." | head -10)
    local codex_claims=$(echo "$codex_response" | grep -E "^\*|^-|^[0-9]+\." | head -10)

    # Calculate claim overlap
    local total_claims=$(echo -e "$claude_claims\n$gemini_claims\n$codex_claims" | sort -u | wc -l)
    local agreed_claims=$(echo -e "$claude_claims\n$gemini_claims\n$codex_claims" | sort | uniq -d | wc -l)

    local agreement_ratio
    agreement_ratio=$(awk "BEGIN {printf \"%.2f\", $agreed_claims / $total_claims}")

    if (( $(echo "$agreement_ratio < 0.3" | bc -l) )); then
        log_warn "LOW AGREEMENT ($agreement_ratio) - possible hallucination cascade"
        return 1
    fi

    return 0
}

# Run consensus with diversity
run_diverse_consensus() {
    local question="$1"

    log_info "Running diverse consensus..."

    # Build diverse prompts
    local claude_prompt=$(build_claude_prompt "$question")
    local gemini_prompt=$(build_gemini_prompt "$question")
    local codex_prompt=$(build_codex_prompt "$question")

    # Execute in parallel with isolated contexts
    local claude_result gemini_result codex_result

    {
        claude_result=$("${BIN_DIR}/claude-delegate" "$claude_prompt" 2>/dev/null)
    } &
    local claude_pid=$!

    {
        gemini_result=$("${BIN_DIR}/gemini-delegate" "$gemini_prompt" 2>/dev/null)
    } &
    local gemini_pid=$!

    {
        codex_result=$("${BIN_DIR}/codex-delegate" "$codex_prompt" 2>/dev/null)
    } &
    local codex_pid=$!

    # Wait for all
    wait $claude_pid $gemini_pid $codex_pid

    # Extract decisions and confidence
    local claude_decision=$(echo "$claude_result" | jq -r '.decision // "ABSTAIN"')
    local claude_confidence=$(echo "$claude_result" | jq -r '.confidence // 50')

    local gemini_decision=$(echo "$gemini_result" | jq -r '.decision // "ABSTAIN"')
    local gemini_confidence=$(echo "$gemini_result" | jq -r '.confidence // 50')

    local codex_decision=$(echo "$codex_result" | jq -r '.decision // "ABSTAIN"')
    local codex_confidence=$(echo "$codex_result" | jq -r '.confidence // 50')

    # Cross-validate for hallucinations
    if ! detect_hallucination "$claude_result" "$gemini_result" "$codex_result"; then
        log_error "Hallucination detected - escalating to human"
        return 1
    fi

    # Weighted voting
    local approve_weight=0
    local reject_weight=0

    # Claude weight: 0.4
    [[ "$claude_decision" == "APPROVE" ]] && approve_weight=$(awk "BEGIN {print $approve_weight + 0.4 * $claude_confidence / 100}")
    [[ "$claude_decision" == "REJECT" ]] && reject_weight=$(awk "BEGIN {print $reject_weight + 0.4 * $claude_confidence / 100}")

    # Gemini weight: 0.3
    [[ "$gemini_decision" == "APPROVE" ]] && approve_weight=$(awk "BEGIN {print $approve_weight + 0.3 * $gemini_confidence / 100}")
    [[ "$gemini_decision" == "REJECT" ]] && reject_weight=$(awk "BEGIN {print $reject_weight + 0.3 * $gemini_confidence / 100}")

    # Codex weight: 0.3
    [[ "$codex_decision" == "APPROVE" ]] && approve_weight=$(awk "BEGIN {print $approve_weight + 0.3 * $codex_confidence / 100}")
    [[ "$codex_decision" == "REJECT" ]] && reject_weight=$(awk "BEGIN {print $reject_weight + 0.3 * $codex_confidence / 100}")

    # Determine final decision
    local final_decision="ABSTAIN"
    if (( $(echo "$approve_weight > 0.5" | bc -l) )); then
        final_decision="APPROVE"
    elif (( $(echo "$reject_weight > 0.5" | bc -l) )); then
        final_decision="REJECT"
    fi

    cat <<EOF
{
    "decision": "$final_decision",
    "approve_weight": $approve_weight,
    "reject_weight": $reject_weight,
    "models": {
        "claude": {"decision": "$claude_decision", "confidence": $claude_confidence},
        "gemini": {"decision": "$gemini_decision", "confidence": $gemini_confidence},
        "codex": {"decision": "$codex_decision", "confidence": $codex_confidence}
    },
    "trace_id": "$TRACE_ID"
}
EOF
}
```

**Estimated Lines of Code**: ~250 new lines
**Testing Required**: Inject known hallucination scenarios, verify detection

---

## Phase 3: Advanced Features (Weeks 4-6)

### Priority: MEDIUM - These provide long-term value

---

### 3.1 Event Sourcing for Audit Trail

**Purpose**: Enable time-travel debugging and complete audit history.

**New Schema Addition**:

```sql
CREATE TABLE event_log (
    sequence_id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    aggregate_type TEXT NOT NULL,  -- 'task' | 'worker' | 'breaker' | 'budget'
    aggregate_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    event_data JSON,
    trace_id TEXT,
    causation_id TEXT,  -- Links to triggering event
    correlation_id TEXT -- Links related events
);

CREATE INDEX idx_event_aggregate ON event_log(aggregate_type, aggregate_id);
CREATE INDEX idx_event_time ON event_log(timestamp);
```

**Event Types**:

```bash
# Task events
TASK_CREATED
TASK_ASSIGNED
TASK_STARTED
TASK_CHECKPOINTED
TASK_COMPLETED
TASK_FAILED
TASK_REJECTED
TASK_ESCALATED

# Worker events
WORKER_STARTED
WORKER_HEARTBEAT
WORKER_BUSY
WORKER_IDLE
WORKER_STOPPED
WORKER_CRASHED

# Breaker events
BREAKER_TRIPPED
BREAKER_HALF_OPEN
BREAKER_CLOSED
BREAKER_RESET

# Budget events
BUDGET_SPENT
BUDGET_WARNING
BUDGET_THROTTLED
BUDGET_KILLSWITCH
```

**Estimated Lines of Code**: ~300 new lines
**Testing Required**: Event replay tests, verify state reconstruction

---

### 3.2 RAG Context Store (Shared Memory)

**Problem**: Supervisor and Worker have different context windows, causing plan/execution drift.

**Solution**: SQLite FTS5 for full-text search across session history.

**New File**: `lib/rag-store.sh`

```bash
#!/bin/bash
# RAG Context Store - Shared Memory for Tri-Agent

RAG_DB="${AUTONOMOUS_ROOT}/state/rag.db"

init_rag_store() {
    sqlite3 "$RAG_DB" <<'SQL'
    -- Main document store
    CREATE TABLE IF NOT EXISTS documents (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,  -- 'decision' | 'code' | 'error' | 'context'
        title TEXT,
        content TEXT NOT NULL,
        embedding BLOB,  -- Future: vector embeddings
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        task_id TEXT,
        trace_id TEXT
    );

    -- Full-text search index
    CREATE VIRTUAL TABLE IF NOT EXISTS documents_fts USING fts5(
        title,
        content,
        content='documents',
        content_rowid='rowid'
    );

    -- Trigger to keep FTS in sync
    CREATE TRIGGER IF NOT EXISTS documents_ai AFTER INSERT ON documents BEGIN
        INSERT INTO documents_fts(rowid, title, content)
        VALUES (NEW.rowid, NEW.title, NEW.content);
    END;
SQL
}

# Store a document
store_document() {
    local type="$1"
    local title="$2"
    local content="$3"
    local task_id="${4:-}"
    local doc_id="doc-$(date +%s)-$$"

    sqlite3 "$RAG_DB" "
        INSERT INTO documents (id, type, title, content, task_id, trace_id)
        VALUES ('$doc_id', '$type', '$title', '$content', '$task_id', '$TRACE_ID');
    "
    echo "$doc_id"
}

# Search documents
search_documents() {
    local query="$1"
    local limit="${2:-5}"

    sqlite3 "$RAG_DB" "
        SELECT d.id, d.type, d.title, snippet(documents_fts, 1, '<b>', '</b>', '...', 64) as snippet
        FROM documents_fts f
        JOIN documents d ON f.rowid = d.rowid
        WHERE documents_fts MATCH '$query'
        ORDER BY rank
        LIMIT $limit;
    "
}

# Get relevant context for a task
get_task_context() {
    local task_description="$1"
    local max_tokens="${2:-4000}"

    # Extract keywords
    local keywords=$(echo "$task_description" | tr ' ' '\n' | grep -E '^[a-zA-Z]{4,}' | sort -u | head -10 | tr '\n' ' ')

    # Search for relevant documents
    local results=$(search_documents "$keywords" 10)

    # Build context string (respect token limit)
    local context=""
    local current_length=0

    while IFS='|' read -r id type title snippet; do
        [[ -z "$id" ]] && continue

        local entry="## $title ($type)\n$snippet\n\n"
        local entry_length=${#entry}

        if (( current_length + entry_length < max_tokens * 4 )); then  # ~4 chars/token
            context+="$entry"
            current_length=$((current_length + entry_length))
        fi
    done <<< "$results"

    echo "$context"
}

# Store decision for future reference
store_decision() {
    local decision="$1"
    local reasoning="$2"
    local task_id="$3"

    store_document "decision" "Decision for task $task_id" \
        "Decision: $decision\n\nReasoning:\n$reasoning" \
        "$task_id"
}

# Store error for learning
store_error() {
    local error_type="$1"
    local error_message="$2"
    local resolution="$3"
    local task_id="${4:-}"

    store_document "error" "Error: $error_type" \
        "Error: $error_message\n\nResolution:\n$resolution" \
        "$task_id"
}
```

**Estimated Lines of Code**: ~200 new lines
**Testing Required**: FTS query performance, context relevance

---

### 3.3 Process Reaper Daemon

**Problem**: 24-hour sessions accumulate orphaned processes.

**New File**: `bin/tri-agent-reaper`

```bash
#!/bin/bash
#===============================================================================
# tri-agent-reaper - Process Cleanup Daemon
#===============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

REAP_INTERVAL=1800  # 30 minutes
MAX_PROCESS_AGE=7200  # 2 hours
ZOMBIE_CHECK_INTERVAL=300  # 5 minutes

# Track known processes
declare -A KNOWN_PROCESSES

reap_orphan_processes() {
    log_info "Running orphan process cleanup..."

    # Find tri-agent related processes older than MAX_PROCESS_AGE
    local now=$(date +%s)

    for pid_file in "${AUTONOMOUS_ROOT}/state"/*.pid; do
        [[ -f "$pid_file" ]] || continue

        local pid=$(cat "$pid_file")
        local process_name=$(basename "${pid_file%.pid}")

        # Check if process is still running
        if ! kill -0 "$pid" 2>/dev/null; then
            log_info "Removing stale PID file for dead process: $process_name"
            rm -f "$pid_file"
            continue
        fi

        # Check process age
        local start_time=$(stat -c %Y "$pid_file" 2>/dev/null || stat -f %m "$pid_file")
        local age=$((now - start_time))

        if [[ $age -gt $MAX_PROCESS_AGE ]]; then
            # Check if process is actually working
            if ! is_process_active "$pid"; then
                log_warn "Killing orphan process: $process_name (PID: $pid, age: ${age}s)"
                kill -TERM "$pid" 2>/dev/null
                sleep 5
                kill -9 "$pid" 2>/dev/null || true
                rm -f "$pid_file"
            fi
        fi
    done

    # Cleanup zombie processes
    cleanup_zombies

    # Cleanup temp files
    cleanup_temp_files
}

is_process_active() {
    local pid="$1"

    # Check if process is responsive
    if [[ -f "${AUTONOMOUS_ROOT}/state/heartbeat_${pid}" ]]; then
        local last_beat=$(stat -c %Y "${AUTONOMOUS_ROOT}/state/heartbeat_${pid}" 2>/dev/null)
        local now=$(date +%s)
        local since=$((now - last_beat))

        if [[ $since -lt 300 ]]; then
            return 0  # Active
        fi
    fi

    return 1  # Not active
}

cleanup_zombies() {
    log_debug "Checking for zombie processes..."

    # Find zombie processes owned by current user
    local zombies=$(ps -u "$(whoami)" -o pid,stat,comm | grep 'Z' | awk '{print $1}')

    for pid in $zombies; do
        log_warn "Found zombie process: $pid"
        # Can't kill zombies directly, but log for awareness
    done
}

cleanup_temp_files() {
    log_debug "Cleaning temp files..."

    # Clean up temp files older than 1 hour
    find "${AUTONOMOUS_ROOT}/state" -name "*.tmp" -mmin +60 -delete 2>/dev/null || true
    find "${AUTONOMOUS_ROOT}/state" -name "*.lock" -mmin +60 -delete 2>/dev/null || true

    # Clean up old log files (keep 7 days)
    find "${LOG_DIR}" -name "*.log" -mtime +7 -delete 2>/dev/null || true
    find "${LOG_DIR}" -name "*.jsonl" -mtime +7 -delete 2>/dev/null || true
}

main() {
    log_info "Process reaper daemon started"

    while true; do
        reap_orphan_processes
        sleep $REAP_INTERVAL
    done
}

main "$@"
```

**Estimated Lines of Code**: ~150 new lines
**Testing Required**: Simulate orphan processes, verify cleanup

---

## Testing Strategy

### Unit Tests

| Component | Test File | Coverage Target |
|-----------|-----------|-----------------|
| SQLite State | `tests/unit/test_sqlite_state.sh` | 90% |
| Budget Watchdog | `tests/unit/test_budget_watchdog.sh` | 95% |
| Priority Queue | `tests/unit/test_priority_queue.sh` | 90% |
| Worker Pool | `tests/unit/test_worker_pool.sh` | 85% |
| RAG Store | `tests/unit/test_rag_store.sh` | 80% |

### Integration Tests

| Scenario | Test File | Description |
|----------|-----------|-------------|
| Concurrent Workers | `tests/integration/test_concurrent_workers.sh` | 3 workers processing same queue |
| Preemption Flow | `tests/integration/test_preemption.sh` | CRITICAL task preempts MEDIUM |
| Budget Kill-Switch | `tests/integration/test_budget_killswitch.sh` | Verify workers stop on limit |
| Consensus Diversity | `tests/integration/test_consensus_diversity.sh` | Different responses detected |

### Chaos Tests

| Scenario | Test File | Injects |
|----------|-----------|---------|
| Random Worker Death | `tests/chaos/test_worker_crash.sh` | SIGKILL random worker |
| SQLite Corruption | `tests/chaos/test_db_corruption.sh` | Truncate DB mid-write |
| Network Partition | `tests/chaos/test_network_partition.sh` | Block API endpoints |
| Clock Skew | `tests/chaos/test_clock_skew.sh` | NTP jump simulation |

### Load Tests

| Scenario | Target | Tool |
|----------|--------|------|
| Queue Depth | 100 tasks queued | Custom script |
| Throughput | 50 tasks/hour sustained | Artillery |
| Memory Leak | 24 hours runtime | Valgrind |
| Concurrent Access | 10 simultaneous writes | Stress test |

---

## Migration Path: v4.0 to v5.0

### Zero-Downtime Migration Strategy

```
Phase A: Prepare (No service impact)
1. Deploy new SQLite schema alongside existing files
2. Run dual-write mode: writes go to both JSON and SQLite
3. Background job syncs historical data to SQLite

Phase B: Validate (No service impact)
4. Run read comparisons: verify SQLite matches JSON
5. Monitor for discrepancies for 24 hours
6. Fix any sync issues

Phase C: Switch (Brief pause possible)
7. Stop all workers gracefully
8. Switch read path from JSON to SQLite
9. Start workers with new code
10. Monitor for issues

Phase D: Cleanup (No service impact)
11. Disable dual-write after 48 hours stable
12. Archive JSON files
13. Remove legacy code paths
```

### Rollback Plan

```bash
# Immediate rollback (< 5 minutes)
git checkout v4.0
systemctl restart tri-agent-supervisor
systemctl restart tri-agent-worker

# Data rollback (if SQLite corrupted)
cp ~/.claude/autonomous/state/backup/tri-agent.db.bak ~/.claude/autonomous/state/tri-agent.db
# Or restore from JSON
./bin/restore-from-json.sh
```

---

## Success Metrics

### Stability Metrics (Target: 99.5% uptime)

| Metric | Current | Target | How to Measure |
|--------|---------|--------|----------------|
| State Corruption Rate | Unknown (~50% risk) | <0.1% | SQLite integrity checks |
| False Timeout Alerts | High | <5% | Compare timeouts to task types |
| Worker Crashes/Day | Unknown | <1 | Process monitoring |
| Orphan Processes | Unknown | 0 | Reaper daemon stats |

### Performance Metrics

| Metric | Current | Target | How to Measure |
|--------|---------|--------|----------------|
| Tasks/Day | 72 | 200+ | Completed task count |
| P99 Task Wait | Unknown | <30 min | Queue time tracking |
| Preemption Latency | N/A | <30 sec | CRITICAL task assignment time |
| Memory Growth | Unknown | <50MB/hr | Process memory monitoring |

### Quality Metrics

| Metric | Current | Target | How to Measure |
|--------|---------|--------|----------------|
| Hallucination Detection | 0% | >80% | Cross-model validation |
| Consensus Agreement | Unknown | >70% | Voting records |
| Context Relevance | Unknown | >85% | RAG retrieval precision |
| Event Completeness | Unknown | 100% | Event sourcing coverage |

### Cost Metrics

| Metric | Current | Target | How to Measure |
|--------|---------|--------|----------------|
| Daily Spend | Unknown | <$50 | Cost tracker |
| Spend Rate Alerts | None | 100% | Kill-switch triggers |
| Budget Utilization | Unknown | 60-80% | Pool balance tracking |

---

## Implementation Timeline

```
Week 1: Critical Fixes
├── Day 1-2: SQLite schema design + state.sh migration
├── Day 3-4: Budget watchdog implementation
├── Day 5: Progressive heartbeat
└── Day 6-7: Testing + bug fixes

Week 2: Worker Pool
├── Day 1-2: tri-agent-pool implementation
├── Day 3-4: Priority queue with preemption
├── Day 5: Load testing
└── Day 6-7: Bug fixes + documentation

Week 3: Consensus Improvements
├── Day 1-2: Diverse prompting strategies
├── Day 3-4: Hallucination detection
├── Day 5: Integration testing
└── Day 6-7: Performance tuning

Week 4: Event Sourcing
├── Day 1-2: Event log schema + recording
├── Day 3-4: Event replay + state reconstruction
└── Day 5-7: Testing + documentation

Week 5: RAG Context Store
├── Day 1-2: FTS5 setup + store API
├── Day 3-4: Context retrieval for tasks
└── Day 5-7: Testing + tuning

Week 6: Polish + Migration
├── Day 1-2: Process reaper daemon
├── Day 3-4: Migration scripting
├── Day 5: Dry run migration
└── Day 6-7: Production deployment
```

---

## Appendix: File Change Summary

| File | Lines Changed | Type |
|------|---------------|------|
| `lib/state.sh` | ~200 removed, ~300 added | Replace |
| `lib/sqlite-state.sh` | ~400 new | New |
| `lib/cost-tracker.sh` | ~150 modified | Modify |
| `lib/priority-queue.sh` | ~200 new | New |
| `lib/rag-store.sh` | ~200 new | New |
| `bin/tri-agent-worker` | ~300 modified | Modify |
| `bin/tri-agent-pool` | ~400 new | New |
| `bin/tri-agent-consensus` | ~250 new | New |
| `bin/tri-agent-reaper` | ~150 new | New |
| `config/tri-agent.yaml` | ~50 modified | Modify |
| **Total** | **~2,500 lines** | |

---

**Document Version**: 1.0.0
**Last Updated**: 2025-12-28
**Status**: READY FOR REVIEW
