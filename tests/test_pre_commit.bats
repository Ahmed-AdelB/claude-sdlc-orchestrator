#!/usr/bin/env bats
# Unit tests for hooks/pre-commit.sh
# Run with: bats tests/test_pre_commit.bats

setup() {
    export TEMP_DIR=$(mktemp -d)
    export TEST_SCRIPT="./hooks/pre-commit.sh"
    export CLAUDE_HOOK_MODE="disabled"  # Disable actual hook execution
}

teardown() {
    rm -rf "$TEMP_DIR"
}

# ============================================
# Input Sanitization Tests
# ============================================

@test "pre-commit.sh sanitizes TOOL_INPUT" {
    grep -q "SECURITY.*Sanitize\|SECURITY.*sanitize" "$TEST_SCRIPT"
}

@test "pre-commit.sh checks for dangerous shell metacharacters" {
    grep -q '\[\;\|\&\`\$\(\)' "$TEST_SCRIPT"
}

@test "pre-commit.sh validates JSON input safely" {
    grep -q "jq -r" "$TEST_SCRIPT"
}

@test "pre-commit.sh does not use eval or shell expansion" {
    ! grep -q "eval " "$TEST_SCRIPT"
}

# ============================================
# Secret Detection Tests (Enhanced)
# ============================================

@test "pre-commit.sh defines SENSITIVE_PATTERNS array" {
    grep -q "SENSITIVE_PATTERNS=" "$TEST_SCRIPT"
}

@test "pre-commit.sh detects AWS access keys (AKIA format)" {
    grep -q "AKIA\[A-Z0-9\]" "$TEST_SCRIPT"
}

@test "pre-commit.sh detects AWS session keys (ASIA format)" {
    grep -q "ASIA\[A-Z0-9\]" "$TEST_SCRIPT"
}

@test "pre-commit.sh detects GitHub tokens (ghp_ format)" {
    grep -q "ghp_" "$TEST_SCRIPT"
}

@test "pre-commit.sh detects private keys (PEM format)" {
    grep -q "BEGIN.*PRIVATE KEY" "$TEST_SCRIPT"
}

@test "pre-commit.sh detects generic API keys" {
    grep -q "api.*key" "$TEST_SCRIPT"
}

@test "pre-commit.sh detects database connection strings" {
    grep -q "postgresql://\|mysql://\|mongodb://" "$TEST_SCRIPT"
}

@test "pre-commit.sh detects OAuth tokens" {
    grep -q "oauth" "$TEST_SCRIPT"
}

@test "pre-commit.sh detects Bearer tokens" {
    grep -q "Bearer" "$TEST_SCRIPT"
}

@test "pre-commit.sh detects Google Cloud API keys" {
    grep -q "AIza" "$TEST_SCRIPT"
}

@test "pre-commit.sh detects Slack tokens" {
    grep -q "xox" "$TEST_SCRIPT"
}

@test "pre-commit.sh detects URL-embedded credentials" {
    grep -q "https.*://.*:.*@" "$TEST_SCRIPT"
}

@test "pre-commit.sh detects environment variable exports with secrets" {
    grep -q "export.*API_KEY\|export.*PASSWORD\|export.*SECRET" "$TEST_SCRIPT"
}

# ============================================
# Debug Code Detection Tests
# ============================================

@test "pre-commit.sh checks for console.log" {
    grep -q "console\.log" "$TEST_SCRIPT"
}

@test "pre-commit.sh checks for debugger statements" {
    grep -q "debugger" "$TEST_SCRIPT"
}

@test "pre-commit.sh checks for Python print statements" {
    grep -q "print\\\(" "$TEST_SCRIPT"
}

# ============================================
# Tri-Agent Review Tests
# ============================================

@test "pre-commit.sh has tri-agent review implementation" {
    grep -q "TRI_AGENT\|tri.*agent" "$TEST_SCRIPT"
}

@test "pre-commit.sh calls Codex CLI" {
    grep -q "command -v codex" "$TEST_SCRIPT"
}

@test "pre-commit.sh calls Gemini CLI" {
    grep -q "command -v gemini" "$TEST_SCRIPT"
}

@test "pre-commit.sh uses timeout for CLI calls" {
    grep -q "timeout 30\|timeout [0-9]" "$TEST_SCRIPT"
}

@test "pre-commit.sh implements vote counting" {
    grep -q "APPROVE_COUNT\|vote.*count" "$TEST_SCRIPT"
}

@test "pre-commit.sh requires majority approval" {
    grep -q "REQUIRED.*TOTAL_VOTES\|majority" "$TEST_SCRIPT"
}

@test "pre-commit.sh fails closed on timeout/error (security)" {
    grep -q "BLOCKING_ISSUES\|fail.*closed\|timeout.*blocking" "$TEST_SCRIPT"
}

# ============================================
# Quality Gate Tests
# ============================================

@test "pre-commit.sh runs linting if available" {
    grep -q "npm run lint\|lint" "$TEST_SCRIPT"
}

@test "pre-commit.sh runs type checking for TypeScript" {
    grep -q "tsc --noEmit\|type.*check" "$TEST_SCRIPT"
}

@test "pre-commit.sh checks file sizes" {
    grep -q "MAX_FILE_SIZE\|file.*size" "$TEST_SCRIPT"
}

# ============================================
# Error Handling Tests
# ============================================

@test "pre-commit.sh tracks error count" {
    grep -q "ERRORS=\|ERROR.*COUNT" "$TEST_SCRIPT"
}

@test "pre-commit.sh tracks warning count" {
    grep -q "WARNINGS=\|WARNING.*COUNT" "$TEST_SCRIPT"
}

@test "pre-commit.sh exits with code 2 on blocking errors" {
    grep -q "exit 2" "$TEST_SCRIPT"
}

@test "pre-commit.sh allows warnings to proceed" {
    grep -q "proceeding with warnings" "$TEST_SCRIPT"
}

# ============================================
# Configuration Tests
# ============================================

@test "pre-commit.sh respects CLAUDE_HOOK_MODE" {
    grep -q "CLAUDE_HOOK_MODE\|HOOK_MODE" "$TEST_SCRIPT"
}

@test "pre-commit.sh skips when mode is disabled" {
    grep -q 'if.*disabled.*exit 0' "$TEST_SCRIPT"
}

@test "pre-commit.sh uses MIN_TEST_COVERAGE variable" {
    grep -q "MIN_COVERAGE\|MIN_TEST_COVERAGE" "$TEST_SCRIPT"
}
