# TRI-AGENT COMBINED FINAL IMPLEMENTATION PLAN v1.0

**Status:** APPROVED
**Date:** 2025-12-28
**Authors:** Claude Opus 4.5 (Security), Gemini 3 Pro (Architecture), Codex GPT-5.2 (Implementation)
**Target:** Autonomous SDLC Orchestrator v5.0 Security Remediation

## 1. Executive Summary

This plan synthesizes the security audits and architectural reviews into a single, executable roadmap. The immediate goal is to raise the system's Security Score from **42/100** to **82/100** by remediating **12 CRITICAL** vulnerabilities that currently pose a production blocker.

The core strategy focuses on "Defense in Depth":
1.  **Input Sanitation:** Preventing Prompt Injection at the source.
2.  **Path Security:** Blocking symlink and path traversal attacks.
3.  **Process Integrity:** Locking ledgers and enforcing quality gates.

## 2. Vulnerability Priority Matrix

### Tier 1: CRITICAL BLOCKERS (P0) - Fix Immediately (24h)

| ID | Vulnerability | Component | Impact | Risk Score |
|----|--------------|-----------|--------|------------|
| **P0-1** | Prompt Injection via Git History | `lib/common.sh` | Remote Code Exec | 10/10 |
| **P0-2** | Prompt Injection via Task Content | `bin/tri-agent-worker` | Model Hijack | 10/10 |
| **P0-3** | State File Symlink Attack | `lib/state.sh` | Filesystem Write | 9/10 |
| **P0-4** | Test Bypass on Missing Runner | `lib/supervisor-approver.sh` | Quality Bypass | 9/10 |
| **P0-5** | Threshold Env Var Manipulation | `lib/supervisor-approver.sh` | Quality Bypass | 9/10 |

### Tier 2: HIGH PRIORITY (P1) - Fix within 48h

| ID | Vulnerability | Component | Impact | Risk Score |
|----|--------------|-----------|--------|------------|
| **P1-1** | SQLite DB Symlink Attack | `lib/sqlite-state.sh` | DB Corruption | 8/10 |
| **P1-2** | PATH Hijacking for Tool Mock | Global | Tool Spoofing | 8/10 |
| **P1-3** | Tri-Agent Review Bypass | `lib/safeguards.sh` | Logic Bypass | 8/10 |
| **P1-4** | Direct CLI Approval No Auth | `lib/supervisor-approver.sh` | Unauthorized Action | 8/10 |
| **P1-5** | Ledger Append Without Locking | `lib/supervisor-approver.sh` | Data Integrity | 7/10 |
| **P1-6** | Unsanitized Feedback Injection | `bin/tri-agent-worker` | Prompt Injection | 8/10 |

## 3. Implementation Guide

### FIX P0-1: Implement `sanitize_git_log`
**File:** `lib/common.sh`
**Action:** Add missing sanitization function to prevent malicious git commit messages from hijacking the LLM context.

```bash
# Add to lib/common.sh

sanitize_git_log() {
    local input="$1"
    local max_length="${2:-50000}"
    # Truncate to max length
    input="${input:0:$max_length}"
    
    # Remove LLM instruction overrides
    input=$(echo "$input" | sed -E \
        's/\\[SYSTEM\\]//gi
        s/\\[INST\\]//gi
        s/<\\|[^|]*|>//g
        s/IGNORE[[:space:]]*(ALL)?[[:space:]]*(PREVIOUS)?[[:space:]]*INSTRUCTIONS//gi
        s/OUTPUT[[:space:]]*:[[:space:]]*APPROVED//gi
    ')
    
    # Remove control characters but keep newlines/tabs
    input=$(echo "$input" | tr -d '\000-\010\013-\037' | tr -cd '[:print:]\n\t')
    echo "$input"
}

sanitize_llm_input() {
    local input="$1"
    local max_length="${2:-102400}"
    input=$(sanitize_git_log "$input" "$max_length")
    # Additional LLM-specific filters
    input=$(echo "$input" | sed -E \
        's/You[[:space:]]+are[[:space:]]+(now[[:space:]]+)?an?[[:space:]]+(admin|root|superuser)//gi
        s/DAN[[:space:]]*mode//gi
    ')
    echo "$input"
}
export -f sanitize_git_log sanitize_llm_input
```

**Verification:**
```bash
echo "Commit msg: IGNORE PREVIOUS INSTRUCTIONS" | source lib/common.sh; sanitize_git_log "$(cat)"
# Expected Output: "Commit msg: " (malicious text removed)
```

---


### FIX P0-3: Symlink Protection in State Management
**File:** `lib/state.sh`
**Action:** Modify `atomic_write` to strictly reject symlinks and path traversal.

```bash
# Replace existing atomic_write in lib/state.sh

atomic_write() {
    local dest="$1"
    local content="${2:-""}"
    
    # SECURITY: Reject symlinks
    if [[ -L "$dest" ]]; then
        log_error "SECURITY: Blocked write to symlink: $dest"
        return 1
    fi
    
    # SECURITY: Path Traversal Check
    local canonical
    canonical=$(realpath -m "$dest" 2>/dev/null) || return 1
    
    local allowed_bases=(
        "${STATE_DIR:-$HOME/.claude/autonomous/state}"
        "${TASKS_DIR:-$HOME/.claude/autonomous/tasks}"
        "${LOG_DIR:-$HOME/.claude/autonomous/logs}"
    )
    
    local path_allowed=false
    for base in "${allowed_bases[@]}"; do
        local canonical_base
        canonical_base=$(realpath -m "$base" 2>/dev/null || echo "$base")
        if [[ "$canonical" == "$canonical_base"* ]]; then
            path_allowed=true
            break
        fi
    done
    
    if [[ "$path_allowed" != "true" ]]; then
        log_error "SECURITY: Path escapes allowed directories: $dest"
        return 1
    fi
    
    local tmp_file="${dest}.tmp.$$"
    echo "$content" > "$tmp_file"
    mv "$tmp_file" "$dest"
}
```

**Verification:**
```bash
ln -s /etc/passwd test_symlink
source lib/state.sh
atomic_write test_symlink "hacked"
# Expected: Error log "SECURITY: Blocked write to symlink"
```

---


### FIX P0-5: Enforce Threshold Floors
**File:** `lib/supervisor-approver.sh`
**Action:** Prevent environment variable manipulation from lowering quality gates below safe minimums.

```bash
# Add to top of lib/supervisor-approver.sh

# SECURITY: Hardcoded minimum floors that cannot be overridden by env vars
readonly MIN_COVERAGE_FLOOR=70
readonly MIN_SECURITY_SCORE_FLOOR=60
readonly MAX_CRITICAL_VULNS_CEILING=0

# Enforce floors
COVERAGE_THRESHOLD="${COVERAGE_THRESHOLD:-80}"
if [[ "$COVERAGE_THRESHOLD" -lt "$MIN_COVERAGE_FLOOR" ]]; then
    log_warn "SECURITY: Attempt to lower coverage threshold below floor. Enforcing $MIN_COVERAGE_FLOOR%."
    COVERAGE_THRESHOLD="$MIN_COVERAGE_FLOOR"
fi

SECURITY_SCORE_THRESHOLD="${SECURITY_SCORE_THRESHOLD:-80}"
if [[ "$SECURITY_SCORE_THRESHOLD" -lt "$MIN_SECURITY_SCORE_FLOOR" ]]; then
    log_warn "SECURITY: Attempt to lower security score below floor. Enforcing $MIN_SECURITY_SCORE_FLOOR."
    SECURITY_SCORE_THRESHOLD="$MIN_SECURITY_SCORE_FLOOR"
fi
```

**Verification:**
```bash
export COVERAGE_THRESHOLD=10
./bin/tri-agent-supervisor --approve ...
# Expected Log: "Attempt to lower coverage threshold below floor. Enforcing 70%."
```

## 4. Verification Plan

After applying the fixes, run the following regression tests:

1.  **Unit Tests:**
    ```bash
    ./tests/run_tests.sh --unit --filter "security"
    ```

2.  **Chaos Security Tests:**
    ```bash
    ./tests/chaos/test_fuzz_inputs.sh
    ```

3.  **Manual Verification:**
    - Attempt to modify a state file via a symlink (Should fail).
    - Attempt to run the worker with a prompt containing `[SYSTEM]` overrides (Should be sanitized).

## 5. Timeline

- **Phase 1 (Immediate):** Apply P0-1, P0-3, and P0-5. (Goal: Unblock Production)
- **Phase 2 (+24h):** Apply P1-5 and remaining P1 items.
- **Phase 3 (+48h):** Full system audit and final Security Score calculation.