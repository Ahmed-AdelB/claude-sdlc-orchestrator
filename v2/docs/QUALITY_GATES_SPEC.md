# Quality Gates Specification for Autonomous SDLC System

*Generated from Claude Agent a72a24b research*

---

## GATE 4: EXECUTE → APPROVED (CRITICAL)

**Transition Criteria: Code Passes All Quality Checks**

### Automated Checks (12 total)

| Check ID | Check Name | Implementation | Pass Threshold |
|----------|------------|----------------|----------------|
| EXE-001 | Test Suite Execution | Run `npm test` or `pytest` | 100% pass |
| EXE-002 | Test Coverage | Generate coverage report | ≥ 80% |
| EXE-003 | Linting | ESLint, Ruff, or language-specific linter | Zero errors |
| EXE-004 | Type Checking | TypeScript tsc, mypy, etc. | Zero errors |
| EXE-005 | Security Scan | OWASP ZAP, Snyk, npm audit | Zero critical/high |
| EXE-006 | Build Success | Run build command | Exit code 0 |
| EXE-007 | Dependency Audit | Check for vulnerable dependencies | Zero critical |
| EXE-008 | Breaking Change Detection | Compare API surface with main branch | None OR documented |
| EXE-009 | Code Review (Tri-Agent) | Claude + Codex + Gemini review | ≥ 2/3 approve |
| EXE-010 | Performance Benchmarks | Run perf tests if applicable | Within ±10% baseline |
| EXE-011 | Documentation Updated | Check for README/CHANGELOG updates | Updated if required |
| EXE-012 | Commit Message Format | Validate conventional commits | Valid format |

### Metrics Structure

```json
{
  "tests": {
    "total": 247,
    "passed": 247,
    "failed": 0,
    "coverage": {
      "lines": 87.4,
      "branches": 82.1,
      "functions": 91.2
    }
  },
  "linting": { "errors": 0, "warnings": 3 },
  "type_checking": { "errors": 0 },
  "security": { "critical": 0, "high": 0, "medium": 2 },
  "build": { "success": true, "duration_seconds": 38.2 },
  "code_review": {
    "claude": { "score": 0.94, "verdict": "APPROVE" },
    "codex": { "score": 0.89, "verdict": "APPROVE" },
    "gemini": { "score": 0.91, "verdict": "APPROVE" },
    "consensus": "APPROVE"
  }
}
```

### Gate 4 Validation Script

```bash
#!/bin/bash
# Quality gate validation script
# Location: lib/quality-gates/gate-4-execute-to-approved.sh

validate_execution() {
    local workspace="$1"
    local trace_id="$2"
    local gate_state_file="${STATE_DIR}/gates/gate4_${trace_id}.json"

    log_info "GATE 4: Starting execution validation"

    local checks_passed=0
    local checks_failed=0
    local results=()

    # --- CHECK 1: Test Suite ---
    log_info "Running test suite..."
    if cd "$workspace" && npm test &>/dev/null; then
        results+=("EXE-001:PASS:All tests passed")
        ((checks_passed++))
    else
        results+=("EXE-001:FAIL:Tests failed")
        ((checks_failed++))
    fi

    # --- CHECK 2: Test Coverage ---
    log_info "Checking test coverage..."
    local coverage=$(cd "$workspace" && npm run coverage 2>&1 | \
        grep -oP "All files\s+\|\s+\K[0-9.]+" | head -1)

    if (( $(echo "${coverage:-0} >= 80" | bc -l) )); then
        results+=("EXE-002:PASS:Coverage ${coverage}% >= 80%")
        ((checks_passed++))
    else
        results+=("EXE-002:FAIL:Coverage ${coverage:-0}% < 80%")
        ((checks_failed++))
    fi

    # --- CHECK 3: Linting ---
    log_info "Running linter..."
    local lint_errors
    lint_errors=$(cd "$workspace" && npm run lint 2>&1 | grep -c "error" || echo 0)

    if [[ $lint_errors -eq 0 ]]; then
        results+=("EXE-003:PASS:No linting errors")
        ((checks_passed++))
    else
        results+=("EXE-003:FAIL:${lint_errors} linting errors")
        ((checks_failed++))
    fi

    # --- CHECK 4: Type Checking ---
    log_info "Running type checker..."
    if cd "$workspace" && npx tsc --noEmit &>/dev/null; then
        results+=("EXE-004:PASS:No type errors")
        ((checks_passed++))
    else
        results+=("EXE-004:FAIL:Type errors detected")
        ((checks_failed++))
    fi

    # --- CHECK 5: Security Scan ---
    log_info "Running security scan..."
    local critical_vulns high_vulns
    critical_vulns=$(cd "$workspace" && npm audit --json 2>/dev/null | \
        jq '.metadata.vulnerabilities.critical // 0')
    high_vulns=$(cd "$workspace" && npm audit --json 2>/dev/null | \
        jq '.metadata.vulnerabilities.high // 0')

    if [[ ${critical_vulns:-0} -eq 0 && ${high_vulns:-0} -eq 0 ]]; then
        results+=("EXE-005:PASS:No critical/high vulnerabilities")
        ((checks_passed++))
    else
        results+=("EXE-005:FAIL:${critical_vulns} critical, ${high_vulns} high vulns")
        ((checks_failed++))
    fi

    # --- CHECK 6: Build ---
    log_info "Running build..."
    if cd "$workspace" && npm run build &>/dev/null; then
        results+=("EXE-006:PASS:Build successful")
        ((checks_passed++))
    else
        results+=("EXE-006:FAIL:Build failed")
        ((checks_failed++))
    fi

    # --- CHECK 7-8: Breaking Changes ---
    local breaking_changes
    breaking_changes=$(cd "$workspace" && git diff main...HEAD 2>/dev/null | \
        grep -c "export.*function\|export.*interface\|export.*class" || echo 0)

    if [[ $breaking_changes -gt 0 ]]; then
        if git log --oneline -1 | grep -qi "breaking"; then
            results+=("EXE-008:PASS:Breaking changes documented")
            ((checks_passed++))
        else
            results+=("EXE-008:FAIL:Breaking changes not documented")
            ((checks_failed++))
        fi
    else
        results+=("EXE-008:N/A:No breaking changes")
        ((checks_passed++))
    fi

    # --- CHECK 9: Tri-Agent Code Review ---
    log_info "Delegating to tri-agent code review..."
    local approvals=0
    local diff_content
    diff_content=$(cd "$workspace" && git diff HEAD~1 2>/dev/null | head -500)

    # Claude review
    local claude_verdict
    claude_verdict=$(echo "$diff_content" | claude -p "Review this diff. Reply APPROVE or REQUEST_CHANGES only." 2>/dev/null | grep -oE "APPROVE|REQUEST_CHANGES" | head -1)
    [[ "$claude_verdict" == "APPROVE" ]] && ((approvals++))

    # Codex review
    local codex_verdict
    codex_verdict=$(echo "$diff_content" | codex exec "Review for bugs. Reply APPROVE or REQUEST_CHANGES." 2>/dev/null | grep -oE "APPROVE|REQUEST_CHANGES" | head -1)
    [[ "$codex_verdict" == "APPROVE" ]] && ((approvals++))

    # Gemini review
    local gemini_verdict
    gemini_verdict=$(echo "$diff_content" | gemini -y "Security review. Reply APPROVE or REQUEST_CHANGES." 2>/dev/null | grep -oE "APPROVE|REQUEST_CHANGES" | head -1)
    [[ "$gemini_verdict" == "APPROVE" ]] && ((approvals++))

    if [[ $approvals -ge 2 ]]; then
        results+=("EXE-009:PASS:Tri-agent consensus ($approvals/3)")
        ((checks_passed++))
    else
        results+=("EXE-009:FAIL:Insufficient approvals ($approvals/3)")
        ((checks_failed++))
    fi

    # --- Save Results ---
    local status="FAIL"
    [[ $checks_failed -eq 0 ]] && status="PASS"

    jq -n \
        --arg status "$status" \
        --argjson passed "$checks_passed" \
        --argjson failed "$checks_failed" \
        --arg results "$(printf '%s\n' "${results[@]}")" \
        '{
            "gate": "EXECUTE_TO_APPROVED",
            "timestamp": (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
            "status": $status,
            "checks_passed": $passed,
            "checks_failed": $failed,
            "results": ($results | split("\n"))
        }' > "$gate_state_file"

    # --- Decision ---
    if [[ $checks_failed -eq 0 ]]; then
        log_info "GATE 4: PASS (${checks_passed} checks passed)"
        return 0
    else
        log_error "GATE 4: FAIL (${checks_failed} checks failed)"
        return 1
    fi
}
```

---

## ALL 5 GATES SUMMARY

| Gate | Transition | Key Checks | Pass Threshold | Decision Maker |
|------|------------|------------|----------------|----------------|
| **Gate 1** | Brainstorm → Document | Requirements, Q&A resolved | ≥3 functional req | Orchestrator |
| **Gate 2** | Document → Plan | Tech spec, acceptance criteria | 2/2 agents approve | Claude + Gemini |
| **Gate 3** | Plan → Execute | Task granularity, DAG valid | 8/8 checks | Tech Lead |
| **Gate 4** | Execute → Approved | Tests, security, tri-agent review | 100% tests, 80% coverage, 2/3 approve | Tri-Agent Consensus |
| **Gate 5** | Approved → Track | Deployment, smoke tests | Non-blocking | CI/CD Pipeline |

---

## RETRY & ESCALATION CONFIGURATION

```yaml
retry_limits:
  per_task:
    max_attempts: 3
    backoff_strategy: "linear"
    backoff_increment: 300  # 5 min per retry

  global:
    max_rejections_per_hour: 10
    max_rejections_per_day: 30
    pause_on_threshold: true

escalation:
  thresholds:
    - attempts: 3
      action: "notify_slack"
    - attempts: 4
      action: "pause_autonomous"
    - attempts: 5
      action: "create_github_issue"

  loop_detection:
    same_gate_failures: 2
    action: "switch_strategy"
```

---

## APPROVAL ENGINE FUNCTIONS

```bash
# approve_task - Handle successful task approval
approve_task() {
    local task_id="$1"
    local task_file="$REVIEW_DIR/${task_id}.md"
    local gate_results="$STATE_DIR/gates/gate4_${task_id}.json"

    log_info "Approving task: $task_id"

    # 1. Move task to approved
    mv "$task_file" "$APPROVED_DIR/"

    # 2. Commit changes
    local commit_msg="feat(${task_id}): Implementation approved by supervisor

Quality Gate 4 Results:
$(jq -r '.results[]' "$gate_results" | sed 's/^/- /')

Tri-Agent Approval:
- Claude: APPROVE
- Codex: APPROVE
- Gemini: APPROVE

🤖 Generated with [Claude Code](https://claude.com/claude-code)"

    git add -A && git commit -m "$commit_msg"

    # 3. Notify worker
    send_message "TASK_APPROVE" "worker" "$task_id" '{
        "status": "approved",
        "commit": "'"$(git rev-parse HEAD)"'",
        "next_action": "proceed_to_next_task"
    }'

    # 4. Update ledger
    log_ledger "TASK_APPROVED" "$task_id"

    log_info "Task $task_id approved and committed"
}

# reject_task - Handle task rejection with feedback
reject_task() {
    local task_id="$1"
    local task_file="$REVIEW_DIR/${task_id}.md"
    local gate_results="$STATE_DIR/gates/gate4_${task_id}.json"

    # Get current retry count
    local retry_count
    retry_count=$(get_task_metadata "$task_id" "retry_count" || echo 0)
    ((retry_count++))

    log_warn "Rejecting task: $task_id (attempt $retry_count/3)"

    # Check retry budget
    if [[ $retry_count -ge 3 ]]; then
        escalate_task "$task_id" "Max retries exceeded"
        return 1
    fi

    # Generate feedback
    local feedback
    feedback=$(generate_feedback "$task_id" "$gate_results")

    # Create enhanced retry task
    local retry_task="$QUEUE_DIR/${task_id}_retry${retry_count}.md"
    cat > "$retry_task" << EOF
# Task $task_id (Retry Attempt $retry_count/3)

## REJECTION FEEDBACK
$feedback

## PRIORITY FIXES REQUIRED
$(jq -r '.results[] | select(contains("FAIL"))' "$gate_results" | sed 's/^/1. /')

## ORIGINAL TASK
$(cat "$task_file")

## CONSTRAINTS
- Focus ONLY on fixing the issues above
- Run all tests before resubmitting
- Time limit: 30 minutes
EOF

    # Move original to rejected (for audit)
    mv "$task_file" "$REJECTED_DIR/"

    # Notify worker
    send_message "TASK_REJECT" "worker" "$task_id" '{
        "retry_count": '"$retry_count"',
        "max_retries": 3,
        "feedback": "'"${feedback//\"/\\\"}"'",
        "retry_task": "'"$retry_task"'"
    }'

    log_ledger "TASK_REJECTED" "$task_id" "attempt=$retry_count"
}

# generate_feedback - Create actionable feedback from gate failures
generate_feedback() {
    local task_id="$1"
    local gate_results="$2"

    local feedback=""

    # Parse each failure
    while IFS= read -r result; do
        local check_id="${result%%:*}"
        local status="${result#*:}"
        status="${status%%:*}"
        local detail="${result##*:}"

        if [[ "$status" == "FAIL" ]]; then
            case "$check_id" in
                EXE-001)
                    feedback+="**Tests Failed**: Run \`npm test\` and fix failing tests.\n"
                    feedback+="$detail\n\n"
                    ;;
                EXE-002)
                    feedback+="**Coverage Below 80%**: Add tests for uncovered code paths.\n"
                    feedback+="Current: $detail\n\n"
                    ;;
                EXE-003)
                    feedback+="**Linting Errors**: Run \`npm run lint --fix\` or manually fix.\n"
                    feedback+="$detail\n\n"
                    ;;
                EXE-005)
                    feedback+="**Security Vulnerabilities**: Critical/High issues must be fixed.\n"
                    feedback+="Run \`npm audit fix\` or update dependencies.\n"
                    feedback+="$detail\n\n"
                    ;;
                EXE-009)
                    feedback+="**Code Review Rejected**: Address reviewer comments.\n"
                    feedback+="$detail\n\n"
                    ;;
            esac
        fi
    done < <(jq -r '.results[]' "$gate_results")

    echo -e "$feedback"
}
```

---

## FILES TO IMPLEMENT

1. `lib/quality-gates/gate-4-execute-to-approved.sh` - Critical gate validation
2. `lib/supervisor-approver.sh` - Approval/rejection engine
3. `config/quality-gates.yaml` - Thresholds configuration
4. `bin/claude-gates` - CLI for gate management
