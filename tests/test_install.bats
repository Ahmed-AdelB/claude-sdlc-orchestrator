#!/usr/bin/env bats
# Unit tests for install.sh
# Run with: bats tests/test_install.bats

setup() {
    export TEMP_DIR=$(mktemp -d)
    export TEST_INSTALL_SCRIPT="./install.sh"
}

teardown() {
    rm -rf "$TEMP_DIR"
}

# ============================================
# Temp Directory Security Tests
# ============================================

@test "install.sh uses mktemp for secure temp directory" {
    grep -q "mktemp -d" "$TEST_INSTALL_SCRIPT"
}

@test "install.sh has fallback mktemp for macOS/BSD" {
    grep -q "mktemp -d -t" "$TEST_INSTALL_SCRIPT"
}

@test "install.sh verifies temp dir was created" {
    grep -q 'if \[ ! -d "\$TEMP_DIR" \]' "$TEST_INSTALL_SCRIPT"
}

@test "install.sh sets restrictive permissions on temp dir" {
    grep -q "chmod 700.*TEMP_DIR" "$TEST_INSTALL_SCRIPT"
}

# ============================================
# Cleanup and Error Handling Tests
# ============================================

@test "install.sh has cleanup function" {
    grep -q "^cleanup()" "$TEST_INSTALL_SCRIPT"
}

@test "install.sh has cleanup trap on EXIT" {
    grep -q "trap cleanup EXIT" "$TEST_INSTALL_SCRIPT"
}

@test "install.sh removes temp dir in cleanup" {
    grep -q "rm -rf.*TEMP_DIR" "$TEST_INSTALL_SCRIPT"
}

@test "install.sh uses set -e for fail-fast" {
    grep -q "^set -e" "$TEST_INSTALL_SCRIPT"
}

# ============================================
# Backup Security Tests
# ============================================

@test "install.sh creates backup before installation" {
    grep -q "backup\|BACKUP" "$TEST_INSTALL_SCRIPT"
}

@test "install.sh checks for symlink attacks on claude dir" {
    grep -q 'if \[ -L.*CLAUDE_DIR' "$TEST_INSTALL_SCRIPT"
}

@test "install.sh sets secure permissions on backup (700)" {
    grep -q "chmod.*700.*backup\|chmod.*700.*BACKUP" "$TEST_INSTALL_SCRIPT"
}

@test "install.sh validates backup directory exists" {
    grep -q 'if \[ -d.*backup' "$TEST_INSTALL_SCRIPT"
}

# ============================================
# Logging and Output Tests
# ============================================

@test "install.sh has logging functions defined" {
    grep -q "log_info()" "$TEST_INSTALL_SCRIPT"
    grep -q "log_error()" "$TEST_INSTALL_SCRIPT"
}

@test "install.sh uses color codes for output" {
    grep -q 'RED=.*033\|GREEN=.*033' "$TEST_INSTALL_SCRIPT"
}

# ============================================
# Installation Process Tests
# ============================================

@test "install.sh defines repository variable" {
    grep -q 'REPO=' "$TEST_INSTALL_SCRIPT"
}

@test "install.sh defines Claude directory variable" {
    grep -q 'CLAUDE_DIR=' "$TEST_INSTALL_SCRIPT"
}

@test "install.sh checks for required commands" {
    grep -q "command -v\|which" "$TEST_INSTALL_SCRIPT"
}
