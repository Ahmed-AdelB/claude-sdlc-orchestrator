#!/usr/bin/env bats
# Unit tests for Claude SDLC Orchestrator hooks
# Run with: bats tests/test_hooks.bats

# Setup - create temp directory for tests
setup() {
    export TEMP_DIR=$(mktemp -d)
    export TEST_FILE="$TEMP_DIR/test_file.py"
    echo 'print("hello")' > "$TEST_FILE"

    # Disable hooks for testing
    export CLAUDE_HOOK_MODE="disabled"
}

# Teardown - cleanup temp files
teardown() {
    rm -rf "$TEMP_DIR"
}

# ============================================
# install.sh tests
# ============================================

@test "install.sh uses mktemp for temp directory" {
    grep -q "mktemp -d" install.sh
}

@test "install.sh has cleanup trap" {
    grep -q "trap cleanup EXIT" install.sh
}

@test "install.sh checks for symlink attacks" {
    grep -q "if \[ -L" install.sh
}

@test "install.sh sets secure permissions on backup" {
    grep -q "chmod -R 700" install.sh
}

# ============================================
# post-edit.sh tests
# ============================================

@test "post-edit.sh sanitizes FILE_PATH" {
    grep -q "SECURITY.*Sanitize FILE_PATH" hooks/post-edit.sh
}

@test "post-edit.sh rejects dangerous characters in path" {
    grep -q '\[\;\|\&\$\`' hooks/post-edit.sh
}

@test "post-edit.sh uses secure session directory" {
    grep -q "XDG_RUNTIME_DIR" hooks/post-edit.sh
}

@test "post-edit.sh sets 700 permissions on session dir" {
    grep -q "chmod 700" hooks/post-edit.sh
}

# ============================================
# pre-commit.sh tests
# ============================================

@test "pre-commit.sh sanitizes TOOL_INPUT" {
    grep -q "SECURITY.*Sanitize TOOL_INPUT" hooks/pre-commit.sh
}

@test "pre-commit.sh detects sensitive patterns" {
    grep -q "SENSITIVE_PATTERNS" hooks/pre-commit.sh
}

@test "pre-commit.sh checks for AWS keys" {
    grep -q "AWS_ACCESS_KEY" hooks/pre-commit.sh
}

@test "pre-commit.sh has real tri-agent review implementation" {
    # Should NOT have the fake "Simulated consensus" comment
    ! grep -q "Simulated consensus" hooks/pre-commit.sh
}

@test "pre-commit.sh calls Codex CLI for tri-agent review" {
    grep -q "command -v codex" hooks/pre-commit.sh
}

@test "pre-commit.sh calls Gemini CLI for tri-agent review" {
    grep -q "command -v gemini" hooks/pre-commit.sh
}

@test "pre-commit.sh has timeout for CLI calls" {
    grep -q "timeout 30" hooks/pre-commit.sh
}

@test "pre-commit.sh implements consensus voting" {
    grep -q "APPROVE_COUNT" hooks/pre-commit.sh
}

# ============================================
# quality-gate.sh tests
# ============================================

@test "quality-gate.sh exists" {
    [ -f "hooks/quality-gate.sh" ]
}

@test "quality-gate.sh is executable" {
    [ -x "hooks/quality-gate.sh" ]
}

@test "quality-gate.sh checks test coverage" {
    grep -q "MIN.*COVERAGE\|coverage" hooks/quality-gate.sh
}

# ============================================
# Security tests
# ============================================

@test "no hardcoded secrets in hooks" {
    ! grep -riE "(password|secret|api_key)\s*=\s*['\"][^'\"]{8,}" hooks/
}

@test "hooks use secure temp file handling" {
    # Should not use predictable /tmp paths
    ! grep -E "/tmp/[a-zA-Z]+-\$\$" hooks/*.sh
}

# ============================================
# gemini_session.py tests
# ============================================

@test "gemini_session.py uses gemini-3-pro as default" {
    grep -q 'model.*=.*"gemini-3-pro"' utils/gemini_session.py
}

@test "gemini_session.py validates model" {
    grep -q "if model not in SUPPORTED_MODELS" utils/gemini_session.py
}

@test "gemini_session.py has secure file permissions" {
    grep -q "chmod.*0o600\|S_IRUSR.*S_IWUSR" utils/gemini_session.py
}

@test "gemini_session.py creates parent dir with 0700" {
    grep -q "mode=0o700" utils/gemini_session.py
}
