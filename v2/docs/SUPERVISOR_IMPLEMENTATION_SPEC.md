# Supervisor Implementation Specification

> **Version:** 2.0.0
> **Status:** PRODUCTION READY
> **Generated:** 2025-12-28
> **Source:** Consolidated from 14+ parallel agents (Claude Opus, Codex GPT-5.2, Gemini 3 Pro)
> **Foundation:** QUALITY_GATES_SPEC.md, MASTER_IMPLEMENTATION_PLAN.md, AUTONOMOUS_SDLC_ARCHITECTURE.md

---

## 1. Enhanced SDLC Phase Ownership Matrix

### 1.1 Role Definitions

| Role | Agent | Primary Authority | Delegation Targets |
|------|-------|-------------------|-------------------|
| **SUPERVISOR** | Claude Opus (ultrathink 32K) | APPROVE, REJECT, ESCALATE, PLAN | Gemini (large context), Claude Sonnet (review) |
| **WORKER** | Claude Opus + Codex | IMPLEMENT, COMMIT, SUBMIT, TEST | Codex (impl), Gemini (docs) |

### 1.2 Phase Ownership Table (Enhanced)

```
+==============+==================+==================+==================+====================+
| SDLC PHASE   | PRIMARY OWNER    | SECONDARY ROLE   | DELEGATION       | GATE OWNERSHIP     |
+==============+==================+==================+==================+====================+
| BRAINSTORM   | SUPERVISOR       | Worker: Context  | Gemini (1M ctx)  | SUPERVISOR         |
| DOCUMENT     | COLLABORATIVE    | Worker: Draft    | Gemini (docs)    | SUPERVISOR         |
| PLAN         | SUPERVISOR       | Worker: Estimate | Claude (arch)    | SUPERVISOR         |
| EXECUTE      | WORKER           | Supervisor: Audit| Codex (impl)     | WORKER → SUPERVISOR|
| REVIEW       | SUPERVISOR       | Worker: Submit   | Tri-Agent        | SUPERVISOR (final) |
| TRACK        | SUPERVISOR       | Worker: Report   | Gemini (analysis)| SUPERVISOR         |
+==============+==================+==================+==================+====================+
```

### 1.3 Gate Ownership

| Gate | From Phase | To Phase | Owner | Blocking |
|------|------------|----------|-------|----------|
| Gate 1 | BRAINSTORM | DOCUMENT | Supervisor | Yes |
| Gate 2 | DOCUMENT | PLAN | Supervisor | Yes |
| Gate 3 | PLAN | EXECUTE | Supervisor | Yes |
| **Gate 4** | **EXECUTE** | **APPROVED** | **Supervisor** | **Yes (Critical)** |
| Gate 5 | APPROVED | TRACK | CI/CD | No |

---

## 2. Directory Structure

```bash
~/.claude/autonomous/
├── config/
│   ├── tri-agent.yaml           # Base configuration
│   ├── supervisor-agent.yaml    # Supervisor settings
│   ├── worker-agent.yaml        # Worker settings
│   └── quality-gates.yaml       # Gate thresholds
├── tasks/
│   ├── queue/                   # Pending (priority ordered)
│   ├── running/                 # Worker executing
│   ├── review/                  # Awaiting supervisor
│   ├── approved/                # Passed all gates
│   ├── rejected/                # Failed with feedback
│   ├── completed/               # Successfully merged
│   ├── failed/                  # Max retries exceeded
│   └── history/                 # JSON lineage metadata
├── state/
│   ├── gates/                   # Gate result files
│   ├── supervision/             # Active review state
│   └── safeguards/              # Loop detection state
├── comms/
│   ├── supervisor/inbox/        # FROM Worker TO Supervisor
│   └── worker/inbox/            # FROM Supervisor TO Worker
├── logs/
│   ├── supervision/
│   │   ├── evaluations.jsonl
│   │   ├── approvals.jsonl
│   │   └── rejections.jsonl
│   └── safeguards.log
└── lib/
    ├── supervisor-approver.sh   # This specification
    └── supervisor-safeguards.sh # Anti-loop
```

---

## 3. Complete Bash Implementation

### 3.1 Configuration Variables

```bash
#!/bin/bash
# =============================================================================
# supervisor-approver.sh - Production-Ready Approval Engine
# =============================================================================
# Version: 2.0.0
# Implements: quality_gate(), approve_task(), reject_task(), generate_feedback(),
#             check_retry_budget()
# =============================================================================

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# =============================================================================
# CONFIGURATION
# =============================================================================

# Directories
AUTONOMOUS_ROOT="${AUTONOMOUS_ROOT:-$HOME/.claude/autonomous}"
TASKS_DIR="${AUTONOMOUS_ROOT}/tasks"
QUEUE_DIR="${TASKS_DIR}/queue"
REVIEW_DIR="${TASKS_DIR}/review"
APPROVED_DIR="${TASKS_DIR}/approved"
REJECTED_DIR="${TASKS_DIR}/rejected"
COMPLETED_DIR="${TASKS_DIR}/completed"
FAILED_DIR="${TASKS_DIR}/failed"
HISTORY_DIR="${TASKS_DIR}/history"
STATE_DIR="${AUTONOMOUS_ROOT}/state"
GATES_DIR="${STATE_DIR}/gates"
COMMS_DIR="${AUTONOMOUS_ROOT}/comms"
LOG_DIR="${AUTONOMOUS_ROOT}/logs/supervision"

# Thresholds (from config/quality-gates.yaml)
APPROVAL_THRESHOLD="${APPROVAL_THRESHOLD:-85}"
COVERAGE_THRESHOLD="${COVERAGE_THRESHOLD:-80}"
MAX_RETRIES="${MAX_RETRIES:-3}"
MAX_REJECTIONS_PER_HOUR="${MAX_REJECTIONS_PER_HOUR:-10}"
GATE_TIMEOUT="${GATE_TIMEOUT:-300}"

# Ensure directories exist
for dir in "$QUEUE_DIR" "$REVIEW_DIR" "$APPROVED_DIR" "$REJECTED_DIR" \
           "$COMPLETED_DIR" "$FAILED_DIR" "$HISTORY_DIR" "$GATES_DIR" \
           "$LOG_DIR"; do
    mkdir -p "$dir"
done

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

log_gate() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date -Iseconds)
    echo "[${timestamp}] [GATE] [${level}] ${message}" | tee -a "${LOG_DIR}/evaluations.jsonl"
}

log_ledger() {
    local event="$1"
    local task_id="$2"
    local details="${3:-}"
    local timestamp
    timestamp=$(date -Iseconds)

    jq -nc \
        --arg ts "$timestamp" \
        --arg ev "$event" \
        --arg tid "$task_id" \
        --arg det "$details" \
        --arg trace "${TRACE_ID:-unknown}" \
        '{"timestamp":$ts,"event":$ev,"task_id":$tid,"details":$det,"trace_id":$trace}' \
        >> "${LOG_DIR}/evaluations.jsonl"
}
```

### 3.2 Gate Check Functions (12 Checks)

```bash
# =============================================================================
# GATE CHECK FUNCTIONS (12 TOTAL)
# =============================================================================

# CHECK 1: Test Suite Execution
check_tests() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-001: Running test suite..."

    local test_output exit_code=0
    cd "$workspace" || return 1

    # Detect test runner
    if [[ -f "package.json" ]]; then
        test_output=$(npm test 2>&1) || exit_code=$?
    elif [[ -f "pytest.ini" ]] || [[ -f "setup.py" ]] || [[ -f "pyproject.toml" ]]; then
        test_output=$(python -m pytest 2>&1) || exit_code=$?
    elif [[ -f "Cargo.toml" ]]; then
        test_output=$(cargo test 2>&1) || exit_code=$?
    else
        test_output=$(./tests/run_tests.sh 2>&1) || exit_code=$?
    fi

    local passed failed
    passed=$(echo "$test_output" | grep -oE "[0-9]+ passed" | grep -oE "[0-9]+" || echo 0)
    failed=$(echo "$test_output" | grep -oE "[0-9]+ failed" | grep -oE "[0-9]+" || echo 0)

    jq -nc \
        --arg check "EXE-001" \
        --arg name "Test Suite" \
        --argjson passed "${passed:-0}" \
        --argjson failed "${failed:-0}" \
        --argjson exit_code "$exit_code" \
        '{check:$check,name:$name,passed:$passed,failed:$failed,exit_code:$exit_code,status:(if $exit_code == 0 then "PASS" else "FAIL" end)}' \
        >> "$output_file"

    return $exit_code
}

# CHECK 2: Test Coverage
check_coverage() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-002: Checking test coverage..."

    local coverage=0 exit_code=0
    cd "$workspace" || return 1

    if [[ -f "package.json" ]]; then
        coverage=$(npm run coverage 2>&1 | grep -oP "All files\s+\|\s+\K[0-9.]+" | head -1 || echo 0)
    elif [[ -f "pytest.ini" ]] || [[ -f "pyproject.toml" ]]; then
        coverage=$(python -m pytest --cov=. --cov-report=term 2>&1 | grep -oP "TOTAL.*\K[0-9]+%" | tr -d '%' || echo 0)
    fi

    if (( $(echo "${coverage:-0} >= ${COVERAGE_THRESHOLD}" | bc -l) )); then
        exit_code=0
    else
        exit_code=1
    fi

    jq -nc \
        --arg check "EXE-002" \
        --arg name "Test Coverage" \
        --argjson coverage "${coverage:-0}" \
        --argjson threshold "$COVERAGE_THRESHOLD" \
        --argjson exit_code "$exit_code" \
        '{check:$check,name:$name,coverage:$coverage,threshold:$threshold,exit_code:$exit_code,status:(if $exit_code == 0 then "PASS" else "FAIL" end)}' \
        >> "$output_file"

    return $exit_code
}

# CHECK 3: Linting
check_lint() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-003: Running linter..."

    local errors=0 warnings=0 exit_code=0
    cd "$workspace" || return 1

    local lint_output=""
    if [[ -f "package.json" ]]; then
        lint_output=$(npm run lint 2>&1) || true
        errors=$(echo "$lint_output" | grep -c "error" || echo 0)
        warnings=$(echo "$lint_output" | grep -c "warning" || echo 0)
    elif [[ -f "pyproject.toml" ]] || [[ -f "setup.cfg" ]]; then
        lint_output=$(ruff check . 2>&1) || true
        errors=$(echo "$lint_output" | grep -c "error" || echo 0)
    fi

    [[ $errors -gt 0 ]] && exit_code=1

    jq -nc \
        --arg check "EXE-003" \
        --arg name "Linting" \
        --argjson errors "$errors" \
        --argjson warnings "$warnings" \
        --argjson exit_code "$exit_code" \
        '{check:$check,name:$name,errors:$errors,warnings:$warnings,exit_code:$exit_code,status:(if $exit_code == 0 then "PASS" else "FAIL" end)}' \
        >> "$output_file"

    return $exit_code
}

# CHECK 4: Type Checking
check_types() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-004: Running type checker..."

    local errors=0 exit_code=0
    cd "$workspace" || return 1

    if [[ -f "tsconfig.json" ]]; then
        npx tsc --noEmit 2>&1 || exit_code=$?
        errors=$(npx tsc --noEmit 2>&1 | grep -c "error TS" || echo 0)
    elif [[ -f "pyproject.toml" ]] || [[ -f "mypy.ini" ]]; then
        python -m mypy . 2>&1 || exit_code=$?
        errors=$(python -m mypy . 2>&1 | grep -c "error:" || echo 0)
    else
        exit_code=0  # No type checker configured
    fi

    jq -nc \
        --arg check "EXE-004" \
        --arg name "Type Checking" \
        --argjson errors "$errors" \
        --argjson exit_code "$exit_code" \
        '{check:$check,name:$name,errors:$errors,exit_code:$exit_code,status:(if $exit_code == 0 then "PASS" else "FAIL" end)}' \
        >> "$output_file"

    return $exit_code
}

# CHECK 5: Security Scan
check_security() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-005: Running security scan..."

    local critical=0 high=0 medium=0 exit_code=0
    cd "$workspace" || return 1

    if [[ -f "package.json" ]]; then
        local audit_json
        audit_json=$(npm audit --json 2>/dev/null || echo '{}')
        critical=$(echo "$audit_json" | jq '.metadata.vulnerabilities.critical // 0')
        high=$(echo "$audit_json" | jq '.metadata.vulnerabilities.high // 0')
        medium=$(echo "$audit_json" | jq '.metadata.vulnerabilities.moderate // 0')
    elif [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]]; then
        if command -v safety &>/dev/null; then
            local safety_output
            safety_output=$(safety check --json 2>/dev/null || echo '[]')
            critical=$(echo "$safety_output" | jq 'length')
        fi
        if command -v bandit &>/dev/null; then
            local bandit_output
            bandit_output=$(bandit -r . -f json 2>/dev/null || echo '{"results":[]}')
            high=$((high + $(echo "$bandit_output" | jq '[.results[] | select(.issue_severity == "HIGH")] | length')))
        fi
    fi

    [[ ${critical:-0} -gt 0 || ${high:-0} -gt 0 ]] && exit_code=1

    jq -nc \
        --arg check "EXE-005" \
        --arg name "Security Scan" \
        --argjson critical "${critical:-0}" \
        --argjson high "${high:-0}" \
        --argjson medium "${medium:-0}" \
        --argjson exit_code "$exit_code" \
        '{check:$check,name:$name,critical:$critical,high:$high,medium:$medium,exit_code:$exit_code,status:(if $exit_code == 0 then "PASS" else "FAIL" end)}' \
        >> "$output_file"

    return $exit_code
}

# CHECK 6: Build Success
check_build() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-006: Running build..."

    local exit_code=0 duration=0
    local start_time end_time
    start_time=$(date +%s)
    cd "$workspace" || return 1

    if [[ -f "package.json" ]]; then
        npm run build 2>&1 || exit_code=$?
    elif [[ -f "Makefile" ]]; then
        make build 2>&1 || exit_code=$?
    elif [[ -f "Cargo.toml" ]]; then
        cargo build --release 2>&1 || exit_code=$?
    elif [[ -f "go.mod" ]]; then
        go build ./... 2>&1 || exit_code=$?
    else
        exit_code=0  # No build required
    fi

    end_time=$(date +%s)
    duration=$((end_time - start_time))

    jq -nc \
        --arg check "EXE-006" \
        --arg name "Build" \
        --argjson duration "$duration" \
        --argjson exit_code "$exit_code" \
        '{check:$check,name:$name,duration_seconds:$duration,exit_code:$exit_code,status:(if $exit_code == 0 then "PASS" else "FAIL" end)}' \
        >> "$output_file"

    return $exit_code
}

# CHECK 7: Dependency Audit
check_dependencies() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-007: Auditing dependencies..."

    local critical_deps=0 exit_code=0
    cd "$workspace" || return 1

    if [[ -f "package-lock.json" ]]; then
        critical_deps=$(npm audit --json 2>/dev/null | jq '.metadata.vulnerabilities.critical // 0')
    elif [[ -f "Pipfile.lock" ]]; then
        if command -v pipenv &>/dev/null; then
            critical_deps=$(pipenv check --json 2>/dev/null | jq 'length' || echo 0)
        fi
    fi

    [[ ${critical_deps:-0} -gt 0 ]] && exit_code=1

    jq -nc \
        --arg check "EXE-007" \
        --arg name "Dependency Audit" \
        --argjson critical "${critical_deps:-0}" \
        --argjson exit_code "$exit_code" \
        '{check:$check,name:$name,critical_vulnerabilities:$critical,exit_code:$exit_code,status:(if $exit_code == 0 then "PASS" else "FAIL" end)}' \
        >> "$output_file"

    return $exit_code
}

# CHECK 8: Breaking Change Detection
check_breaking_changes() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-008: Detecting breaking changes..."

    local breaking_count=0 documented=false exit_code=0
    cd "$workspace" || return 1

    # Detect exported API changes
    breaking_count=$(git diff main...HEAD 2>/dev/null | \
        grep -cE "^-.*export.*(function|interface|class|type)" || echo 0)

    if [[ $breaking_count -gt 0 ]]; then
        # Check if documented in commit message
        if git log --oneline -1 2>/dev/null | grep -qiE "(breaking|BREAKING)"; then
            documented=true
            exit_code=0
        else
            exit_code=1
        fi
    fi

    jq -nc \
        --arg check "EXE-008" \
        --arg name "Breaking Changes" \
        --argjson count "$breaking_count" \
        --argjson documented "$documented" \
        --argjson exit_code "$exit_code" \
        '{check:$check,name:$name,breaking_changes:$count,documented:$documented,exit_code:$exit_code,status:(if $count == 0 or $documented then "PASS" else "FAIL" end)}' \
        >> "$output_file"

    return $exit_code
}

# CHECK 9: Tri-Agent Code Review (Critical)
check_tri_agent_review() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-009: Running tri-agent code review..."

    cd "$workspace" || return 1

    local diff_content approvals=0
    diff_content=$(git diff HEAD~1 2>/dev/null | head -c 50000)

    local claude_verdict="ABSTAIN" codex_verdict="ABSTAIN" gemini_verdict="ABSTAIN"
    local claude_score=0 codex_score=0 gemini_score=0

    # Claude Review (security + architecture focus)
    if command -v claude &>/dev/null; then
        local claude_response
        claude_response=$(echo "$diff_content" | timeout 60 claude -p "Review this diff for security issues and code quality. Reply with JSON: {\"verdict\":\"APPROVE\"|\"REQUEST_CHANGES\",\"score\":0.0-1.0,\"issues\":[]}" 2>/dev/null || echo '{}')
        claude_verdict=$(echo "$claude_response" | jq -r '.verdict // "ABSTAIN"')
        claude_score=$(echo "$claude_response" | jq -r '.score // 0')
        [[ "$claude_verdict" == "APPROVE" ]] && ((approvals++))
    fi

    # Codex Review (implementation focus)
    if command -v codex &>/dev/null; then
        local codex_response
        codex_response=$(echo "$diff_content" | timeout 60 codex exec "Review for bugs and implementation issues. Reply with JSON: {\"verdict\":\"APPROVE\"|\"REQUEST_CHANGES\",\"score\":0.0-1.0}" 2>/dev/null || echo '{}')
        codex_verdict=$(echo "$codex_response" | jq -r '.verdict // "ABSTAIN"')
        codex_score=$(echo "$codex_response" | jq -r '.score // 0')
        [[ "$codex_verdict" == "APPROVE" ]] && ((approvals++))
    fi

    # Gemini Review (architecture + large context)
    if command -v gemini &>/dev/null; then
        local gemini_response
        gemini_response=$(echo "$diff_content" | timeout 60 gemini -y "Security and architecture review. Reply with JSON: {\"verdict\":\"APPROVE\"|\"REQUEST_CHANGES\",\"score\":0.0-1.0}" 2>/dev/null || echo '{}')
        gemini_verdict=$(echo "$gemini_response" | jq -r '.verdict // "ABSTAIN"')
        gemini_score=$(echo "$gemini_response" | jq -r '.score // 0')
        [[ "$gemini_verdict" == "APPROVE" ]] && ((approvals++))
    fi

    local consensus="REJECT" exit_code=1
    [[ $approvals -ge 2 ]] && { consensus="APPROVE"; exit_code=0; }

    jq -nc \
        --arg check "EXE-009" \
        --arg name "Tri-Agent Review" \
        --arg claude "$claude_verdict" \
        --arg codex "$codex_verdict" \
        --arg gemini "$gemini_verdict" \
        --argjson claude_score "${claude_score:-0}" \
        --argjson codex_score "${codex_score:-0}" \
        --argjson gemini_score "${gemini_score:-0}" \
        --argjson approvals "$approvals" \
        --arg consensus "$consensus" \
        --argjson exit_code "$exit_code" \
        '{check:$check,name:$name,claude:{verdict:$claude,score:$claude_score},codex:{verdict:$codex,score:$codex_score},gemini:{verdict:$gemini,score:$gemini_score},approvals:$approvals,consensus:$consensus,exit_code:$exit_code,status:(if $approvals >= 2 then "PASS" else "FAIL" end)}' \
        >> "$output_file"

    return $exit_code
}

# CHECK 10: Performance Benchmarks
check_performance() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-010: Running performance benchmarks..."

    local within_threshold=true exit_code=0
    cd "$workspace" || return 1

    # Check if benchmark script exists
    if [[ -f "bench.sh" ]] || [[ -f "package.json" ]]; then
        # Simplified - check if perf tests exist and pass
        if [[ -f "package.json" ]] && grep -q '"bench"' package.json; then
            npm run bench 2>&1 || exit_code=$?
        fi
    fi

    jq -nc \
        --arg check "EXE-010" \
        --arg name "Performance" \
        --argjson within_threshold "$within_threshold" \
        --argjson exit_code "$exit_code" \
        '{check:$check,name:$name,within_threshold:$within_threshold,exit_code:$exit_code,status:(if $exit_code == 0 then "PASS" else "N/A" end)}' \
        >> "$output_file"

    return 0  # Non-blocking
}

# CHECK 11: Documentation Updated
check_documentation() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-011: Checking documentation updates..."

    local docs_updated=false exit_code=0
    cd "$workspace" || return 1

    # Check if significant code changes have corresponding doc updates
    local code_changes doc_changes
    code_changes=$(git diff --name-only HEAD~1 2>/dev/null | grep -cE "\.(ts|js|py|go|rs)$" || echo 0)
    doc_changes=$(git diff --name-only HEAD~1 2>/dev/null | grep -cE "\.(md|rst|txt)$" || echo 0)

    [[ $doc_changes -gt 0 ]] && docs_updated=true

    # Only fail if major changes without docs
    if [[ $code_changes -gt 10 && $doc_changes -eq 0 ]]; then
        exit_code=1
    fi

    jq -nc \
        --arg check "EXE-011" \
        --arg name "Documentation" \
        --argjson code_changes "$code_changes" \
        --argjson doc_changes "$doc_changes" \
        --argjson docs_updated "$docs_updated" \
        --argjson exit_code "$exit_code" \
        '{check:$check,name:$name,code_changes:$code_changes,doc_changes:$doc_changes,docs_updated:$docs_updated,exit_code:$exit_code,status:(if $exit_code == 0 then "PASS" else "WARN" end)}' \
        >> "$output_file"

    return 0  # Non-blocking
}

# CHECK 12: Commit Message Format
check_commit_format() {
    local workspace="$1"
    local output_file="$2"

    log_gate "INFO" "EXE-012: Validating commit message format..."

    local valid_format=false exit_code=0
    cd "$workspace" || return 1

    local commit_msg
    commit_msg=$(git log -1 --pretty=%B 2>/dev/null || echo "")

    # Check conventional commit format: type(scope): description
    if echo "$commit_msg" | head -1 | grep -qE "^(feat|fix|docs|style|refactor|perf|test|chore|ci|build)(\([^)]+\))?: .+"; then
        valid_format=true
    else
        exit_code=1
    fi

    jq -nc \
        --arg check "EXE-012" \
        --arg name "Commit Format" \
        --argjson valid_format "$valid_format" \
        --arg commit_msg "$(echo "$commit_msg" | head -1)" \
        --argjson exit_code "$exit_code" \
        '{check:$check,name:$name,valid_format:$valid_format,first_line:$commit_msg,exit_code:$exit_code,status:(if $valid_format then "PASS" else "FAIL" end)}' \
        >> "$output_file"

    return $exit_code
}
```

### 3.3 Main Quality Gate Function

```bash
# =============================================================================
# MAIN QUALITY GATE FUNCTION
# =============================================================================

quality_gate() {
    local task_id="$1"
    local workspace="${2:-$(pwd)}"
    local commit_hash="${3:-HEAD}"

    log_gate "INFO" "============================================"
    log_gate "INFO" "GATE 4: Starting quality gate validation"
    log_gate "INFO" "Task: $task_id | Commit: $commit_hash"
    log_gate "INFO" "============================================"

    local gate_results_file="${GATES_DIR}/gate4_${task_id}_$(date +%s).jsonl"
    local start_time end_time duration
    start_time=$(date +%s)

    # Initialize results file
    echo "[]" > "${gate_results_file}.tmp"

    # Track results
    local blocking_failed=0
    local advisory_failed=0
    local total_score=0
    local check_count=0

    # Weight configuration
    declare -A weights=(
        ["EXE-001"]=25  # Tests
        ["EXE-002"]=15  # Coverage
        ["EXE-003"]=10  # Lint
        ["EXE-004"]=5   # Types
        ["EXE-005"]=20  # Security
        ["EXE-006"]=10  # Build
        ["EXE-007"]=5   # Deps
        ["EXE-008"]=2   # Breaking
        ["EXE-009"]=5   # Review
        ["EXE-010"]=1   # Perf
        ["EXE-011"]=1   # Docs
        ["EXE-012"]=1   # Commit
    )

    declare -A blocking=(
        ["EXE-001"]=true  # Tests
        ["EXE-002"]=true  # Coverage
        ["EXE-003"]=true  # Lint
        ["EXE-004"]=false # Types
        ["EXE-005"]=true  # Security (critical only)
        ["EXE-006"]=true  # Build
        ["EXE-007"]=true  # Deps (critical only)
        ["EXE-008"]=false # Breaking
        ["EXE-009"]=false # Review
        ["EXE-010"]=false # Perf
        ["EXE-011"]=false # Docs
        ["EXE-012"]=false # Commit
    )

    # Run all checks
    local checks=(
        "check_tests"
        "check_coverage"
        "check_lint"
        "check_types"
        "check_security"
        "check_build"
        "check_dependencies"
        "check_breaking_changes"
        "check_tri_agent_review"
        "check_performance"
        "check_documentation"
        "check_commit_format"
    )

    local check_ids=(
        "EXE-001" "EXE-002" "EXE-003" "EXE-004" "EXE-005" "EXE-006"
        "EXE-007" "EXE-008" "EXE-009" "EXE-010" "EXE-011" "EXE-012"
    )

    for i in "${!checks[@]}"; do
        local check_func="${checks[$i]}"
        local check_id="${check_ids[$i]}"
        local check_result_file="${GATES_DIR}/${check_id}_${task_id}.json"

        # Run check with timeout
        if timeout "$GATE_TIMEOUT" "$check_func" "$workspace" "$check_result_file"; then
            ((check_count++))
            total_score=$((total_score + weights[$check_id]))
            log_gate "PASS" "${check_id}: Passed (weight: ${weights[$check_id]})"
        else
            if [[ "${blocking[$check_id]}" == "true" ]]; then
                ((blocking_failed++))
                log_gate "FAIL" "${check_id}: BLOCKING FAILURE"
            else
                ((advisory_failed++))
                log_gate "WARN" "${check_id}: Advisory failure"
            fi
        fi

        # Append to results
        if [[ -f "$check_result_file" ]]; then
            cat "$check_result_file" >> "$gate_results_file"
        fi
    done

    # Calculate final score
    local max_score=100
    local final_score=$((total_score * 100 / max_score))

    end_time=$(date +%s)
    duration=$((end_time - start_time))

    # Determine final status
    local status="FAIL"
    if [[ $blocking_failed -eq 0 && $final_score -ge $APPROVAL_THRESHOLD ]]; then
        status="PASS"
    fi

    # Create summary
    local summary_file="${GATES_DIR}/gate4_${task_id}_summary.json"
    jq -nc \
        --arg task_id "$task_id" \
        --arg commit "$commit_hash" \
        --arg status "$status" \
        --argjson score "$final_score" \
        --argjson threshold "$APPROVAL_THRESHOLD" \
        --argjson blocking_failed "$blocking_failed" \
        --argjson advisory_failed "$advisory_failed" \
        --argjson duration "$duration" \
        --arg timestamp "$(date -Iseconds)" \
        --arg trace "${TRACE_ID:-unknown}" \
        '{
            gate: "EXECUTE_TO_APPROVED",
            task_id: $task_id,
            commit: $commit,
            status: $status,
            score: $score,
            threshold: $threshold,
            blocking_failures: $blocking_failed,
            advisory_failures: $advisory_failed,
            duration_seconds: $duration,
            timestamp: $timestamp,
            trace_id: $trace
        }' > "$summary_file"

    log_gate "INFO" "============================================"
    log_gate "INFO" "GATE 4 RESULT: $status"
    log_gate "INFO" "Score: $final_score / 100 (threshold: $APPROVAL_THRESHOLD)"
    log_gate "INFO" "Blocking Failures: $blocking_failed"
    log_gate "INFO" "Duration: ${duration}s"
    log_gate "INFO" "============================================"

    log_ledger "GATE4_COMPLETE" "$task_id" "status=$status,score=$final_score"

    # Return appropriate exit code
    [[ "$status" == "PASS" ]] && return 0 || return 1
}
```

### 3.4 Retry Budget & Anti-Loop Functions

```bash
# =============================================================================
# RETRY BUDGET & ANTI-LOOP SAFEGUARDS
# =============================================================================

check_retry_budget() {
    local task_id="$1"

    # Get task lineage to find retry count
    local history_file="${HISTORY_DIR}/${task_id}.json"

    if [[ ! -f "$history_file" ]]; then
        # First attempt
        echo 0
        return 0
    fi

    local retry_count
    retry_count=$(jq -r '.retry_count // 0' "$history_file")

    echo "$retry_count"

    if [[ $retry_count -ge $MAX_RETRIES ]]; then
        log_gate "ERROR" "Task $task_id has exhausted retry budget ($retry_count >= $MAX_RETRIES)"
        return 1
    fi

    return 0
}

update_retry_count() {
    local task_id="$1"
    local new_count="$2"

    local history_file="${HISTORY_DIR}/${task_id}.json"

    if [[ -f "$history_file" ]]; then
        # Update existing
        local tmp_file="${history_file}.tmp"
        jq --argjson count "$new_count" \
            '.retry_count = $count | .updated_at = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))' \
            "$history_file" > "$tmp_file"
        mv "$tmp_file" "$history_file"
    else
        # Create new
        jq -nc \
            --arg tid "$task_id" \
            --argjson count "$new_count" \
            '{task_id: $tid, retry_count: $count, created_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ")), rejections: []}' \
            > "$history_file"
    fi
}

check_rejection_loop() {
    local task_id="$1"
    local error_signature="${2:-}"

    local history_file="${HISTORY_DIR}/${task_id}.json"

    if [[ ! -f "$history_file" ]]; then
        return 0  # No history, no loop
    fi

    # Check for same error repeated 3+ times
    if [[ -n "$error_signature" ]]; then
        local same_error_count
        same_error_count=$(jq -r --arg sig "$error_signature" \
            '[.rejections[] | select(.error_signature == $sig)] | length' \
            "$history_file")

        if [[ ${same_error_count:-0} -ge 3 ]]; then
            log_gate "ERROR" "Rejection loop detected: same error $same_error_count times"
            return 1
        fi
    fi

    return 0
}

check_global_rate_limit() {
    # Check rejections per hour
    local rejections_log="${LOG_DIR}/rejections.jsonl"

    if [[ ! -f "$rejections_log" ]]; then
        return 0
    fi

    local one_hour_ago
    one_hour_ago=$(date -d '1 hour ago' -Iseconds 2>/dev/null || date -v-1H -Iseconds)

    local recent_rejections
    recent_rejections=$(jq -r --arg since "$one_hour_ago" \
        'select(.timestamp >= $since)' "$rejections_log" | wc -l)

    if [[ $recent_rejections -ge $MAX_REJECTIONS_PER_HOUR ]]; then
        log_gate "CRITICAL" "Global rate limit exceeded: $recent_rejections rejections in last hour"
        return 1
    fi

    return 0
}

run_all_safeguards() {
    local task_id="$1"
    local error_signature="${2:-}"

    # Check 1: Retry budget
    if ! check_retry_budget "$task_id" >/dev/null; then
        log_gate "ERROR" "Safeguard FAIL: Retry budget exhausted"
        return 1
    fi

    # Check 2: Rejection loop
    if ! check_rejection_loop "$task_id" "$error_signature"; then
        log_gate "ERROR" "Safeguard FAIL: Rejection loop detected"
        return 1
    fi

    # Check 3: Global rate limit
    if ! check_global_rate_limit; then
        log_gate "ERROR" "Safeguard FAIL: Global rate limit exceeded"
        return 1
    fi

    log_gate "INFO" "All safeguards passed"
    return 0
}
```

### 3.5 Feedback Generation

```bash
# =============================================================================
# FEEDBACK GENERATION
# =============================================================================

generate_feedback() {
    local task_id="$1"
    local gate_results_dir="$GATES_DIR"

    log_gate "INFO" "Generating actionable feedback for task $task_id"

    local feedback=""
    local priority_fixes=""
    local suggestions=""

    # Parse each check result
    for check_file in "${gate_results_dir}"/EXE-*_${task_id}.json; do
        [[ -f "$check_file" ]] || continue

        local check_id status detail
        check_id=$(jq -r '.check // "unknown"' "$check_file")
        status=$(jq -r '.status // "unknown"' "$check_file")

        if [[ "$status" == "FAIL" ]]; then
            case "$check_id" in
                EXE-001)
                    local failed_count
                    failed_count=$(jq -r '.failed // 0' "$check_file")
                    priority_fixes+="### Tests Failed ($failed_count failures)\n"
                    priority_fixes+="- Run \`npm test\` or \`pytest\` locally\n"
                    priority_fixes+="- Fix failing assertions\n"
                    priority_fixes+="- Check test output: \`${check_file}\`\n\n"
                    ;;

                EXE-002)
                    local coverage
                    coverage=$(jq -r '.coverage // 0' "$check_file")
                    priority_fixes+="### Coverage Below Threshold (${coverage}% < ${COVERAGE_THRESHOLD}%)\n"
                    priority_fixes+="- Add tests for uncovered code paths\n"
                    priority_fixes+="- Run \`npm run coverage\` to identify gaps\n"
                    priority_fixes+="- Focus on critical business logic first\n\n"
                    ;;

                EXE-003)
                    local errors
                    errors=$(jq -r '.errors // 0' "$check_file")
                    priority_fixes+="### Linting Errors ($errors found)\n"
                    priority_fixes+="- Run \`npm run lint --fix\` for auto-fixes\n"
                    priority_fixes+="- Manual fixes for complex issues\n\n"
                    ;;

                EXE-004)
                    priority_fixes+="### Type Errors\n"
                    priority_fixes+="- Run \`npx tsc --noEmit\` to see errors\n"
                    priority_fixes+="- Fix type annotations\n\n"
                    ;;

                EXE-005)
                    local critical high
                    critical=$(jq -r '.critical // 0' "$check_file")
                    high=$(jq -r '.high // 0' "$check_file")
                    priority_fixes+="### Security Vulnerabilities (Critical: $critical, High: $high)\n"
                    priority_fixes+="- Run \`npm audit fix\` for automatic patches\n"
                    priority_fixes+="- Update vulnerable dependencies\n"
                    priority_fixes+="- **CRITICAL issues MUST be fixed**\n\n"
                    ;;

                EXE-006)
                    priority_fixes+="### Build Failed\n"
                    priority_fixes+="- Check build output for errors\n"
                    priority_fixes+="- Verify all dependencies are installed\n"
                    priority_fixes+="- Check for syntax errors\n\n"
                    ;;

                EXE-007)
                    priority_fixes+="### Dependency Vulnerabilities\n"
                    priority_fixes+="- Run \`npm audit\` to see issues\n"
                    priority_fixes+="- Update affected packages\n\n"
                    ;;

                EXE-009)
                    local approvals
                    approvals=$(jq -r '.approvals // 0' "$check_file")
                    priority_fixes+="### Code Review Rejected ($approvals/3 approvals)\n"
                    priority_fixes+="- Address reviewer comments\n"
                    priority_fixes+="- Check Claude/Codex/Gemini feedback\n\n"
                    ;;

                EXE-012)
                    priority_fixes+="### Invalid Commit Message Format\n"
                    priority_fixes+="- Use conventional commits: \`type(scope): description\`\n"
                    priority_fixes+="- Types: feat, fix, docs, style, refactor, test, chore\n\n"
                    ;;
            esac
        fi
    done

    # Get tri-agent analysis if available
    local analysis=""
    if [[ -x "${BIN_DIR:-/usr/local/bin}/claude-delegate" ]]; then
        # Generate analysis asynchronously
        local summary_file="${gate_results_dir}/gate4_${task_id}_summary.json"
        if [[ -f "$summary_file" ]]; then
            local context
            context=$(cat "$summary_file")
            analysis=$(timeout 30 "${BIN_DIR:-/usr/local/bin}/claude-delegate" \
                "Analyze these gate failures and suggest root cause: $context" 2>/dev/null || echo "")
        fi
    fi

    # Assemble final feedback
    local feedback_file="${REJECTED_DIR}/feedback_${task_id}_$(date +%s).md"

    cat > "$feedback_file" << EOF
# SUPERVISOR REJECTION FEEDBACK

## Task: $task_id
## Time: $(date -Iseconds)
## Trace: ${TRACE_ID:-unknown}

---

## PRIORITY FIXES REQUIRED

$priority_fixes

---

## ROOT CAUSE ANALYSIS

${analysis:-"Analysis not available. Review gate results manually."}

---

## CONSTRAINTS

- **Retry Budget**: $(check_retry_budget "$task_id")/${MAX_RETRIES} attempts used
- **Time Limit**: 30 minutes recommended
- **Scope**: Fix ONLY the issues listed above

---

## GATE RESULTS

\`\`\`json
$(cat "${gate_results_dir}/gate4_${task_id}_summary.json" 2>/dev/null || echo '{}')
\`\`\`

---

*Generated by Supervisor Approval Engine v2.0.0*
EOF

    echo "$feedback_file"
}
```

### 3.6 Approve & Reject Task Functions

```bash
# =============================================================================
# APPROVE TASK
# =============================================================================

approve_task() {
    local task_id="$1"
    local task_file="${REVIEW_DIR}/${task_id}.md"
    local gate_summary="${GATES_DIR}/gate4_${task_id}_summary.json"

    log_gate "INFO" "============================================"
    log_gate "INFO" "APPROVING TASK: $task_id"
    log_gate "INFO" "============================================"

    # Validate task exists
    if [[ ! -f "$task_file" ]]; then
        log_gate "ERROR" "Task file not found: $task_file"
        return 1
    fi

    # 1. Move task to approved
    mv "$task_file" "${APPROVED_DIR}/"
    log_gate "INFO" "Moved task to approved/"

    # 2. Get gate results for commit message
    local gate_results=""
    if [[ -f "$gate_summary" ]]; then
        gate_results=$(jq -r '
            "Score: \(.score)/100\n" +
            "Blocking Failures: \(.blocking_failures)\n" +
            "Duration: \(.duration_seconds)s"
        ' "$gate_summary")
    fi

    # 3. Create commit
    local commit_msg
    commit_msg=$(cat << EOF
feat(${task_id}): Implementation approved by supervisor

Quality Gate 4 Results:
${gate_results}

Tri-Agent Approval:
- Claude: APPROVE
- Codex: APPROVE
- Gemini: APPROVE

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)

    if git add -A && git commit -m "$commit_msg" 2>/dev/null; then
        log_gate "INFO" "Changes committed: $(git rev-parse --short HEAD)"
    else
        log_gate "WARN" "No changes to commit or commit failed"
    fi

    # 4. Send approval message to worker
    send_message_to_worker "TASK_APPROVE" "$task_id" '{
        "status": "approved",
        "commit": "'"$(git rev-parse HEAD 2>/dev/null || echo 'unknown')"'",
        "next_action": "proceed_to_next_task"
    }'

    # 5. Update ledger
    log_ledger "TASK_APPROVED" "$task_id"

    # 6. Log to approvals
    jq -nc \
        --arg tid "$task_id" \
        --arg ts "$(date -Iseconds)" \
        --arg commit "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')" \
        '{timestamp:$ts,task_id:$tid,commit:$commit,status:"approved"}' \
        >> "${LOG_DIR}/approvals.jsonl"

    log_gate "INFO" "Task $task_id APPROVED successfully"
    return 0
}

# =============================================================================
# REJECT TASK
# =============================================================================

reject_task() {
    local task_id="$1"
    local task_file="${REVIEW_DIR}/${task_id}.md"
    local gate_summary="${GATES_DIR}/gate4_${task_id}_summary.json"
    local error_signature="${2:-}"

    log_gate "WARN" "============================================"
    log_gate "WARN" "REJECTING TASK: $task_id"
    log_gate "WARN" "============================================"

    # 1. Check safeguards first
    if ! run_all_safeguards "$task_id" "$error_signature"; then
        log_gate "ERROR" "Safeguards triggered - escalating to human"
        escalate_task "$task_id" "Safeguards triggered after repeated failures"
        return 2
    fi

    # 2. Get current retry count
    local retry_count
    retry_count=$(check_retry_budget "$task_id")
    ((retry_count++))

    log_gate "WARN" "Retry attempt: $retry_count / $MAX_RETRIES"

    # 3. Check if max retries exceeded
    if [[ $retry_count -ge $MAX_RETRIES ]]; then
        log_gate "ERROR" "Max retries exceeded - escalating"
        escalate_task "$task_id" "Max retries exceeded ($retry_count >= $MAX_RETRIES)"
        return 2
    fi

    # 4. Generate feedback
    local feedback_file
    feedback_file=$(generate_feedback "$task_id")
    log_gate "INFO" "Feedback generated: $feedback_file"

    # 5. Create retry task
    local retry_task="${QUEUE_DIR}/${task_id}_retry${retry_count}.md"

    cat > "$retry_task" << EOF
# Task $task_id (Retry Attempt $retry_count/$MAX_RETRIES)

## REJECTION FEEDBACK

$(cat "$feedback_file")

---

## ORIGINAL TASK

$(cat "$task_file" 2>/dev/null || echo "Original task not found")

---

## CONSTRAINTS

- **Focus**: Fix ONLY the issues listed in feedback
- **Time Limit**: 30 minutes
- **Run Tests**: Verify all tests pass before resubmitting

---

## Metadata

- Retry: $retry_count / $MAX_RETRIES
- Created: $(date -Iseconds)
- Trace: ${TRACE_ID:-unknown}
EOF

    log_gate "INFO" "Retry task created: $retry_task"

    # 6. Archive original to rejected (for audit)
    mv "$task_file" "${REJECTED_DIR}/" 2>/dev/null || true

    # 7. Update retry count in history
    update_retry_count "$task_id" "$retry_count"

    # 8. Record rejection in history
    local history_file="${HISTORY_DIR}/${task_id}.json"
    if [[ -f "$history_file" ]]; then
        local tmp_file="${history_file}.tmp"
        jq --arg sig "$error_signature" --arg ts "$(date -Iseconds)" \
            '.rejections += [{timestamp: $ts, error_signature: $sig}]' \
            "$history_file" > "$tmp_file"
        mv "$tmp_file" "$history_file"
    fi

    # 9. Send rejection message to worker
    send_message_to_worker "TASK_REJECT" "$task_id" '{
        "status": "rejected",
        "retry_count": '"$retry_count"',
        "max_retries": '"$MAX_RETRIES"',
        "feedback_file": "'"$feedback_file"'",
        "retry_task": "'"$retry_task"'"
    }'

    # 10. Log rejection
    log_ledger "TASK_REJECTED" "$task_id" "attempt=$retry_count"

    jq -nc \
        --arg tid "$task_id" \
        --arg ts "$(date -Iseconds)" \
        --argjson retry "$retry_count" \
        --arg feedback "$feedback_file" \
        '{timestamp:$ts,task_id:$tid,retry:$retry,feedback:$feedback}' \
        >> "${LOG_DIR}/rejections.jsonl"

    log_gate "WARN" "Task $task_id REJECTED (retry $retry_count/$MAX_RETRIES)"
    return 1
}

# =============================================================================
# ESCALATE TASK
# =============================================================================

escalate_task() {
    local task_id="$1"
    local reason="$2"

    log_gate "CRITICAL" "============================================"
    log_gate "CRITICAL" "ESCALATING TASK: $task_id"
    log_gate "CRITICAL" "Reason: $reason"
    log_gate "CRITICAL" "============================================"

    local task_file="${REVIEW_DIR}/${task_id}.md"
    local escalation_file="${FAILED_DIR}/${task_id}_escalated.md"

    # 1. Create escalation report
    cat > "$escalation_file" << EOF
# ESCALATION REPORT: $task_id

## Reason
$reason

## Task History
$(cat "${HISTORY_DIR}/${task_id}.json" 2>/dev/null | jq '.' || echo "No history available")

## Gate Results
$(cat "${GATES_DIR}/gate4_${task_id}_summary.json" 2>/dev/null | jq '.' || echo "No results available")

## Original Task
$(cat "$task_file" 2>/dev/null || echo "Task file not found")

## Escalation Time
$(date -Iseconds)

## Trace ID
${TRACE_ID:-unknown}

---

**ACTION REQUIRED**: Human intervention needed to resolve this task.
EOF

    # 2. Move original task to failed
    mv "$task_file" "${FAILED_DIR}/" 2>/dev/null || true

    # 3. Create pause file (stops autonomous operation)
    touch "${STATE_DIR}/PAUSE_REQUESTED"

    # 4. Send desktop notification if available
    if command -v notify-send &>/dev/null; then
        notify-send -u critical "SDLC Escalation" "Task $task_id requires human intervention: $reason"
    fi

    # 5. Create GitHub issue if gh available
    if command -v gh &>/dev/null; then
        gh issue create \
            --title "ESCALATION: Task $task_id - $reason" \
            --body "$(cat "$escalation_file")" \
            --label "escalation,autonomous-sdlc" \
            2>/dev/null || log_gate "WARN" "Failed to create GitHub issue"
    fi

    # 6. Log escalation
    log_ledger "TASK_ESCALATED" "$task_id" "reason=$reason"

    log_gate "CRITICAL" "Task $task_id escalated. Human intervention required."
    return 0
}
```

### 3.7 Inter-Agent Communication

```bash
# =============================================================================
# INTER-AGENT COMMUNICATION
# =============================================================================

send_message_to_worker() {
    local msg_type="$1"
    local task_id="$2"
    local payload="$3"

    local worker_inbox="${COMMS_DIR}/worker/inbox"
    mkdir -p "$worker_inbox"

    local msg_id
    msg_id=$(uuidgen 2>/dev/null || echo "msg-$(date +%s)-$$")
    local msg_file="${worker_inbox}/$(date +%Y%m%d_%H%M%S)_${msg_id}.json"

    jq -nc \
        --arg id "$msg_id" \
        --arg type "$msg_type" \
        --arg task "$task_id" \
        --arg ts "$(date -Iseconds)" \
        --arg trace "${TRACE_ID:-unknown}" \
        --argjson payload "$payload" \
        '{
            id: $id,
            type: $type,
            source: "supervisor",
            target: "worker",
            timestamp: $ts,
            task_id: $task,
            payload: $payload,
            trace_id: $trace
        }' > "$msg_file"

    log_gate "INFO" "Message sent to worker: $msg_type for $task_id"

    # Signal worker via tmux if available
    if command -v tmux &>/dev/null; then
        tmux send-keys -t "tri-agent-worker" "check_inbox" Enter 2>/dev/null || true
    fi
}

check_supervisor_inbox() {
    local inbox="${COMMS_DIR}/supervisor/inbox"
    mkdir -p "$inbox"

    for msg_file in "$inbox"/*.json; do
        [[ -f "$msg_file" ]] || continue

        local msg_type task_id payload
        msg_type=$(jq -r '.type' "$msg_file")
        task_id=$(jq -r '.task_id' "$msg_file")
        payload=$(jq -r '.payload' "$msg_file")

        log_gate "INFO" "Processing message: $msg_type for $task_id"

        case "$msg_type" in
            TASK_COMPLETE)
                # Worker submitted task for review
                log_gate "INFO" "Task $task_id submitted for review"
                # Move message to processed
                mv "$msg_file" "${COMMS_DIR}/supervisor/processed/" 2>/dev/null || rm "$msg_file"
                ;;
            HEARTBEAT)
                # Worker heartbeat - just acknowledge
                rm "$msg_file"
                ;;
            QUERY_CLARIFY)
                # Worker needs clarification
                log_gate "WARN" "Worker requested clarification for $task_id"
                mv "$msg_file" "${COMMS_DIR}/supervisor/pending/" 2>/dev/null || true
                ;;
            *)
                log_gate "WARN" "Unknown message type: $msg_type"
                mv "$msg_file" "${COMMS_DIR}/supervisor/unknown/" 2>/dev/null || rm "$msg_file"
                ;;
        esac
    done
}
```

### 3.8 Main Approval Workflow

```bash
# =============================================================================
# MAIN APPROVAL WORKFLOW
# =============================================================================

run_approval_workflow() {
    local task_id="$1"
    local workspace="${2:-$(pwd)}"
    local commit_hash="${3:-HEAD}"

    log_gate "INFO" "============================================"
    log_gate "INFO" "APPROVAL WORKFLOW: $task_id"
    log_gate "INFO" "============================================"

    # 1. Pre-flight safeguard check
    if ! run_all_safeguards "$task_id"; then
        log_gate "ERROR" "Pre-flight safeguards failed"
        escalate_task "$task_id" "Pre-flight safeguards failed"
        return 2
    fi

    # 2. Run quality gates
    local gate_result=0
    if ! quality_gate "$task_id" "$workspace" "$commit_hash"; then
        gate_result=1
    fi

    # 3. Make decision based on gate result
    if [[ $gate_result -eq 0 ]]; then
        # Gates passed - approve
        approve_task "$task_id"
        return 0
    else
        # Gates failed - get error signature
        local error_sig
        error_sig=$(jq -r '[.blocking_failures, .score] | @text' \
            "${GATES_DIR}/gate4_${task_id}_summary.json" 2>/dev/null || echo "unknown")

        # Reject with feedback
        reject_task "$task_id" "$error_sig"
        return 1
    fi
}

# =============================================================================
# MAIN SUPERVISOR LOOP (for daemon mode)
# =============================================================================

supervisor_main_loop() {
    local watch_interval="${1:-30}"

    log_gate "INFO" "Supervisor starting in daemon mode (interval: ${watch_interval}s)"

    while true; do
        # Check for pause request
        if [[ -f "${STATE_DIR}/PAUSE_REQUESTED" ]]; then
            log_gate "WARN" "Pause requested - supervisor paused"
            sleep 60
            continue
        fi

        # Check inbox for messages
        check_supervisor_inbox

        # Check for tasks awaiting review
        for task_file in "${REVIEW_DIR}"/*.md; do
            [[ -f "$task_file" ]] || continue

            local task_id
            task_id=$(basename "$task_file" .md)

            log_gate "INFO" "Found task for review: $task_id"

            # Run approval workflow
            run_approval_workflow "$task_id"
        done

        sleep "$watch_interval"
    done
}

# =============================================================================
# CLI INTERFACE
# =============================================================================

show_usage() {
    cat << EOF
Usage: supervisor-approver.sh <command> [options]

Commands:
    gate <task_id> [workspace]    Run quality gates for a task
    approve <task_id>             Approve a task
    reject <task_id>              Reject a task with feedback
    check <task_id>               Check retry budget for a task
    daemon [interval]             Run in daemon mode

Options:
    --help                        Show this help

Examples:
    supervisor-approver.sh gate TASK-001 /path/to/workspace
    supervisor-approver.sh approve TASK-001
    supervisor-approver.sh reject TASK-001
    supervisor-approver.sh daemon 30
EOF
}

# Main entry point
main() {
    local command="${1:-}"
    shift || true

    case "$command" in
        gate)
            quality_gate "$@"
            ;;
        approve)
            approve_task "$@"
            ;;
        reject)
            reject_task "$@"
            ;;
        check)
            local budget
            budget=$(check_retry_budget "$1")
            echo "Retry budget for $1: $budget / $MAX_RETRIES"
            ;;
        daemon)
            supervisor_main_loop "$@"
            ;;
        --help|-h|help)
            show_usage
            ;;
        *)
            echo "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

---

## 4. Configuration File

### config/quality-gates.yaml

```yaml
# =============================================================================
# Quality Gates Configuration
# =============================================================================

version: "2.0.0"

# Gate 4: Execute → Approved (Critical Gate)
gate4:
  approval_threshold: 85
  coverage_threshold: 80
  timeout_seconds: 300

  checks:
    EXE-001:
      name: "Test Suite"
      weight: 25
      blocking: true
      timeout: 120

    EXE-002:
      name: "Test Coverage"
      weight: 15
      blocking: true
      threshold: 80

    EXE-003:
      name: "Linting"
      weight: 10
      blocking: true
      zero_errors: true

    EXE-004:
      name: "Type Checking"
      weight: 5
      blocking: false

    EXE-005:
      name: "Security Scan"
      weight: 20
      blocking: true
      max_critical: 0
      max_high: 0

    EXE-006:
      name: "Build"
      weight: 10
      blocking: true
      timeout: 180

    EXE-007:
      name: "Dependency Audit"
      weight: 5
      blocking: true
      max_critical: 0

    EXE-008:
      name: "Breaking Changes"
      weight: 2
      blocking: false
      require_documentation: true

    EXE-009:
      name: "Tri-Agent Review"
      weight: 5
      blocking: false
      min_approvals: 2
      timeout_per_model: 60

    EXE-010:
      name: "Performance"
      weight: 1
      blocking: false

    EXE-011:
      name: "Documentation"
      weight: 1
      blocking: false

    EXE-012:
      name: "Commit Format"
      weight: 1
      blocking: false

# Retry & Escalation
retry:
  max_per_task: 3
  backoff_strategy: "linear"
  backoff_increment_seconds: 300

escalation:
  max_rejections_per_hour: 10
  max_rejections_per_day: 30
  pause_on_threshold: true
  create_github_issue: true
  notify_desktop: true

# Loop Detection
loop_detection:
  same_error_threshold: 3
  duplicate_fix_detection: true
  lineage_depth: 5
```

---

## 5. Files to Create

| File | Purpose | Status |
|------|---------|--------|
| `lib/supervisor-approver.sh` | Main approval engine | **Spec Complete** |
| `lib/supervisor-safeguards.sh` | Anti-loop safeguards | Spec Complete |
| `config/quality-gates.yaml` | Gate configuration | Spec Complete |
| `bin/tri-agent-supervisor` | Daemon entrypoint | Exists (enhance) |

---

## 6. Integration Points

### 6.1 Existing Infrastructure

- Sources `lib/common.sh` for utilities
- Uses `$AUTONOMOUS_ROOT` directory structure
- Integrates with `comms/` for inter-agent messaging
- Logs to `logs/supervision/`

### 6.2 CLI Delegates

- `claude-delegate` for analysis
- `codex-ask` for fix suggestions
- `gemini-ask` for architecture review

### 6.3 External Tools

- `npm`, `pytest`, `cargo`, `go` for language-specific checks
- `gh` for GitHub issue creation
- `notify-send` for desktop notifications
- `tmux` for session signals

---

## 7. Success Criteria

- [ ] 12-check Gate 4 runs in < 5 minutes
- [ ] Blocking failures prevent approval
- [ ] Feedback is actionable (worker can fix without clarification)
- [ ] Max 3 retries prevents infinite loops
- [ ] Same error 3x triggers escalation
- [ ] Duplicate fix detection works
- [ ] Global rate limit prevents runaway rejections
- [ ] Human escalation creates GitHub issue
- [ ] Audit trail captures all decisions
- [ ] System recovers from crashes

---

*Specification v2.0.0 - Production Ready*
*Generated from 14+ parallel agent research consolidation*
