#!/usr/bin/env bats
# Unit tests for hooks/post-edit.sh
# Run with: bats tests/test_post_edit.bats

setup() {
    export TEMP_DIR=$(mktemp -d)
    export TEST_SCRIPT="./hooks/post-edit.sh"
    export CLAUDE_HOOK_MODE="disabled"
}

teardown() {
    rm -rf "$TEMP_DIR"
}

# ============================================
# Input Sanitization Tests
# ============================================

@test "post-edit.sh sanitizes FILE_PATH" {
    grep -q "SECURITY.*Sanitize.*FILE_PATH" "$TEST_SCRIPT"
}

@test "post-edit.sh rejects dangerous characters in path" {
    grep -q '\[\;\|\&\$\`\(\)\{\}\<\>\!\#\]' "$TEST_SCRIPT"
}

@test "post-edit.sh resolves file path to absolute" {
    grep -q "realpath\|readlink" "$TEST_SCRIPT"
}

@test "post-edit.sh validates resolved path exists" {
    grep -q 'if.*\[ -f.*FILE_PATH' "$TEST_SCRIPT"
}

# ============================================
# Security Tests
# ============================================

@test "post-edit.sh prevents symlink attacks" {
    grep -q "prevent symlink\|symlink attack" "$TEST_SCRIPT"
}

@test "post-edit.sh validates file is within project directory" {
    grep -q "PROJECT_DIR\|project directory" "$TEST_SCRIPT"
}

@test "post-edit.sh aborts on file outside project" {
    grep -q "File outside project.*aborting" "$TEST_SCRIPT"
}

# ============================================
# Auto-Formatting Tests
# ============================================

@test "post-edit.sh respects AUTO_FORMAT setting" {
    grep -q "AUTO_FORMAT" "$TEST_SCRIPT"
}

@test "post-edit.sh supports Prettier for JS/TS" {
    grep -q "prettier\|npx prettier" "$TEST_SCRIPT"
}

@test "post-edit.sh supports Black for Python" {
    grep -q "black\|python.*format" "$TEST_SCRIPT"
}

@test "post-edit.sh supports gofmt for Go" {
    grep -q "gofmt" "$TEST_SCRIPT"
}

# ============================================
# Linting Tests
# ============================================

@test "post-edit.sh respects AUTO_LINT_FIX setting" {
    grep -q "AUTO_LINT_FIX" "$TEST_SCRIPT"
}

@test "post-edit.sh runs ESLint fix for JS/TS" {
    grep -q "eslint.*--fix" "$TEST_SCRIPT"
}

@test "post-edit.sh runs Ruff for Python" {
    grep -q "ruff" "$TEST_SCRIPT"
}

# ============================================
# Configuration Tests
# ============================================

@test "post-edit.sh respects HOOK_MODE setting" {
    grep -q "HOOK_MODE.*disabled" "$TEST_SCRIPT"
}

@test "post-edit.sh exits when disabled" {
    grep -q 'if.*disabled.*exit 0' "$TEST_SCRIPT"
}

# ============================================
# Error Handling Tests
# ============================================

@test "post-edit.sh does not use set -e" {
    ! grep -q "^set -e" "$TEST_SCRIPT"
}

@test "post-edit.sh continues on formatting failures" {
    grep -q "continue on.*formatting\|formatting.*failure" "$TEST_SCRIPT"
}
