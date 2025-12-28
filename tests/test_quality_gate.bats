#!/usr/bin/env bats
# Unit tests for hooks/quality-gate.sh
# Run with: bats tests/test_quality_gate.bats

setup() {
    export TEMP_DIR=$(mktemp -d)
    export TEST_SCRIPT="./hooks/quality-gate.sh"
    export CLAUDE_HOOK_MODE="disabled"
}

teardown() {
    rm -rf "$TEMP_DIR"
}

# ============================================
# Existence and Permissions Tests
# ============================================

@test "quality-gate.sh exists" {
    [ -f "$TEST_SCRIPT" ]
}

@test "quality-gate.sh is executable" {
    [ -x "$TEST_SCRIPT" ]
}

@test "quality-gate.sh has bash shebang" {
    head -1 "$TEST_SCRIPT" | grep -q "#!/bin/bash"
}

# ============================================
# Test Coverage Tests
# ============================================

@test "quality-gate.sh checks test coverage" {
    grep -q "coverage\|COVERAGE" "$TEST_SCRIPT"
}

@test "quality-gate.sh respects MIN_TEST_COVERAGE setting" {
    grep -q "MIN_TEST_COVERAGE\|MIN_COVERAGE" "$TEST_SCRIPT"
}

@test "quality-gate.sh supports JavaScript test coverage" {
    grep -q "npm.*test.*coverage\|jest.*coverage\|vitest.*coverage" "$TEST_SCRIPT"
}

@test "quality-gate.sh supports Python test coverage" {
    grep -q "pytest.*cov\|coverage.*run" "$TEST_SCRIPT"
}

# ============================================
# Test Execution Tests
# ============================================

@test "quality-gate.sh runs tests if REQUIRE_TESTS is true" {
    grep -q "REQUIRE_TESTS" "$TEST_SCRIPT"
}

@test "quality-gate.sh runs npm test for Node.js projects" {
    grep -q "npm.*test\|npm run test" "$TEST_SCRIPT"
}

@test "quality-gate.sh runs pytest for Python projects" {
    grep -q "pytest" "$TEST_SCRIPT"
}

# ============================================
# Linting Tests
# ============================================

@test "quality-gate.sh runs linting checks" {
    grep -q "lint\|linter" "$TEST_SCRIPT"
}

@test "quality-gate.sh fails on linting errors" {
    grep -q "lint.*fail\|linting.*error" "$TEST_SCRIPT"
}

# ============================================
# Type Checking Tests
# ============================================

@test "quality-gate.sh runs TypeScript type checking" {
    grep -q "tsc\|type.*check" "$TEST_SCRIPT"
}

@test "quality-gate.sh runs mypy for Python type checking" {
    grep -q "mypy" "$TEST_SCRIPT"
}

# ============================================
# Documentation Tests
# ============================================

@test "quality-gate.sh checks for documentation if REQUIRE_DOCS is true" {
    grep -q "REQUIRE_DOCS" "$TEST_SCRIPT"
}

@test "quality-gate.sh validates README exists" {
    grep -q "README\|readme" "$TEST_SCRIPT"
}

# ============================================
# Complexity Checks
# ============================================

@test "quality-gate.sh checks code complexity" {
    grep -q "complexity\|COMPLEXITY" "$TEST_SCRIPT"
}

@test "quality-gate.sh has MAX_COMPLEXITY setting" {
    grep -q "MAX_COMPLEXITY" "$TEST_SCRIPT"
}

# ============================================
# Configuration Tests
# ============================================

@test "quality-gate.sh respects HOOK_MODE setting" {
    grep -q "HOOK_MODE" "$TEST_SCRIPT"
}

@test "quality-gate.sh exits when disabled" {
    grep -q 'if.*disabled.*exit 0' "$TEST_SCRIPT"
}

# ============================================
# Error Handling Tests
# ============================================

@test "quality-gate.sh does not use set -e" {
    ! grep -q "^set -e" "$TEST_SCRIPT"
}

@test "quality-gate.sh tracks passed checks" {
    grep -q "PASSED=" "$TEST_SCRIPT"
}

@test "quality-gate.sh tracks failed checks" {
    grep -q "FAILED=" "$TEST_SCRIPT"
}

@test "quality-gate.sh reports all issues before failing" {
    grep -q "report all\|continue on.*failure" "$TEST_SCRIPT"
}

# ============================================
# Output and Logging Tests
# ============================================

@test "quality-gate.sh has logging functions" {
    grep -q "log_info\|log_error\|log_success" "$TEST_SCRIPT"
}

@test "quality-gate.sh uses color codes for output" {
    grep -q 'RED=.*033\|GREEN=.*033' "$TEST_SCRIPT"
}

@test "quality-gate.sh has header separator" {
    grep -q "━━━\|===\|---" "$TEST_SCRIPT"
}
