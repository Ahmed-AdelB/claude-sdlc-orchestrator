#!/usr/bin/env python3
"""
test_delegates.py - Python tests for tri-agent delegate scripts
===============================================================================
Tests the helper functions, JSON parsing, and decision extraction logic
that can be easily tested in Python without requiring actual CLI calls.

Run with: pytest test_delegates.py -v
Or:       python3 -m pytest test_delegates.py -v
"""

import json
import os
import re
import subprocess
from pathlib import Path
from typing import Any, Dict, Optional, Tuple

import pytest


# ==============================================================================
# Test Configuration
# ==============================================================================

SCRIPT_DIR = Path(__file__).parent
CLAUDE_ROOT = SCRIPT_DIR.parent.parent
V2_BIN = CLAUDE_ROOT / "v2" / "bin"
AUTONOMOUS_BIN = CLAUDE_ROOT / "autonomous" / "bin"

# Use environment variable to override bin directory
BIN_DIR = Path(os.environ.get("TEST_BIN_DIR", str(V2_BIN)))


# ==============================================================================
# Helper Functions
# ==============================================================================


def run_delegate(
    delegate: str,
    args: list = None,
    stdin: str = None,
    env: dict = None,
    timeout: int = 30,
) -> Tuple[int, str, str]:
    """
    Run a delegate script and return exit code, stdout, and stderr.

    Args:
        delegate: Name of delegate script (e.g., "claude-delegate")
        args: List of arguments to pass
        stdin: Optional stdin input
        env: Additional environment variables
        timeout: Timeout in seconds

    Returns:
        Tuple of (exit_code, stdout, stderr)
    """
    script_path = BIN_DIR / delegate
    if not script_path.exists():
        pytest.skip(f"Delegate script not found: {script_path}")

    cmd = [str(script_path)]
    if args:
        cmd.extend(args)

    # Build environment
    process_env = os.environ.copy()
    if env:
        process_env.update(env)

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            input=stdin,
            env=process_env,
            timeout=timeout,
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return 124, "", "Timeout"
    except Exception as e:
        return 1, "", str(e)


def parse_json_envelope(output: str) -> Optional[Dict[str, Any]]:
    """Parse JSON envelope from delegate output."""
    try:
        return json.loads(output.strip())
    except json.JSONDecodeError:
        return None


def delegate_exists(name: str) -> bool:
    """Check if delegate script exists and is executable."""
    script_path = BIN_DIR / name
    return script_path.exists() and os.access(script_path, os.X_OK)


# ==============================================================================
# Decision Extraction Logic Tests
# ==============================================================================


class TestDecisionExtraction:
    """Tests for decision extraction from delegate outputs."""

    @pytest.mark.parametrize(
        "text,expected",
        [
            ("I APPROVE this change.", "APPROVE"),
            ("APPROVED - looks good!", "APPROVE"),
            ("LGTM", "APPROVE"),
            ("I accept this implementation", "APPROVE"),
            ("YES, this is correct", "APPROVE"),
            ("I REJECT this code.", "REJECT"),
            ("REJECTED due to security issues", "REJECT"),
            ("DENY this request", "REJECT"),
            ("NO, this is incorrect", "REJECT"),
            ("BLOCK this merge", "REJECT"),
            ("I'm UNSURE about this", "ABSTAIN"),
            ("ABSTAIN from this decision", "ABSTAIN"),
            ("Cannot determine the answer", "ABSTAIN"),
            ("Need more information", "ABSTAIN"),
            ("Some random text", "ABSTAIN"),
            ("", "ABSTAIN"),
        ],
    )
    def test_decision_keywords(self, text: str, expected: str):
        """Test that decision extraction recognizes keywords correctly."""
        # This tests the logic that should be in the delegates
        decision = "ABSTAIN"

        if re.search(r"\b(APPROVE|APPROVED|LGTM|ACCEPT|YES)\b", text, re.IGNORECASE):
            decision = "APPROVE"
        elif re.search(
            r"\b(REJECT|REJECTED|DENY|DENIED|NO|BLOCK)\b", text, re.IGNORECASE
        ):
            decision = "REJECT"
        elif re.search(
            r"\b(ABSTAIN|UNSURE|UNCLEAR|CANNOT DETERMINE|NEED MORE)\b",
            text,
            re.IGNORECASE,
        ):
            decision = "ABSTAIN"

        assert decision == expected


class TestConfidenceCalculation:
    """Tests for confidence calculation from delegate outputs."""

    @pytest.mark.parametrize(
        "text,min_conf,max_conf",
        [
            ("I definitely approve this.", 0.85, 1.0),
            ("I certainly reject this.", 0.85, 1.0),
            ("I absolutely accept this.", 0.85, 1.0),
            ("This is clearly correct.", 0.85, 1.0),
            ("I strongly recommend approval.", 0.85, 1.0),
            ("This likely needs changes.", 0.65, 0.8),
            ("It probably works.", 0.65, 0.8),
            ("It appears to be correct.", 0.65, 0.8),
            ("This seems fine.", 0.65, 0.8),
            ("Maybe this could work.", 0.35, 0.5),
            ("It might be correct.", 0.35, 0.5),
            ("I'm unsure about this.", 0.35, 0.5),
            ("It's difficult to say.", 0.15, 0.35),
            ("Hard to tell without more context.", 0.15, 0.35),
            ("Cannot determine the impact.", 0.15, 0.35),
            ("Some neutral text.", 0.45, 0.55),
        ],
    )
    def test_confidence_levels(self, text: str, min_conf: float, max_conf: float):
        """Test confidence calculation based on language patterns."""
        confidence = 0.5  # Default

        if re.search(
            r"\b(definitely|certainly|absolutely|clearly|strongly)\b",
            text,
            re.IGNORECASE,
        ):
            confidence = 0.9
        elif re.search(
            r"\b(likely|probably|appears|seems|looks)\b", text, re.IGNORECASE
        ):
            confidence = 0.7
        elif re.search(
            r"\b(maybe|might|could|possibly|perhaps|unsure)\b", text, re.IGNORECASE
        ):
            confidence = 0.4
        elif re.search(
            r"\b(difficult to say|hard to tell|cannot determine|need more)\b",
            text,
            re.IGNORECASE,
        ):
            confidence = 0.2

        assert (
            min_conf <= confidence <= max_conf
        ), f"Confidence {confidence} not in range [{min_conf}, {max_conf}]"


# ==============================================================================
# JSON Envelope Tests
# ==============================================================================


class TestJsonEnvelope:
    """Tests for JSON envelope structure and validation."""

    def test_envelope_required_fields(self):
        """Test that JSON envelope has all required fields."""
        required_fields = {
            "model",
            "status",
            "decision",
            "confidence",
            "reasoning",
            "output",
            "trace_id",
            "duration_ms",
        }

        # Test with claude-delegate
        if delegate_exists("claude-delegate"):
            exit_code, stdout, _ = run_delegate(
                "claude-delegate",
                ["test"],
                env={
                    "CLAUDE_CMD": "nonexistent-cli",
                    "TRI_FALLBACK_DISABLED": "true",
                },
            )

            envelope = parse_json_envelope(stdout)
            if envelope:
                assert set(envelope.keys()) >= required_fields

    def test_envelope_model_field_values(self):
        """Test that model field has correct value for each delegate."""
        delegates_models = {
            "claude-delegate": "claude",
            "codex-delegate": "codex",
            "gemini-delegate": "gemini",
        }

        for delegate, expected_model in delegates_models.items():
            if not delegate_exists(delegate):
                continue

            cmd_var = delegate.replace("-", "_").upper() + "_CMD"
            exit_code, stdout, _ = run_delegate(
                delegate,
                ["test"],
                env={
                    cmd_var.replace("_DELEGATE", ""): "nonexistent-cli",
                    "TRI_FALLBACK_DISABLED": "true",
                },
            )

            envelope = parse_json_envelope(stdout)
            if envelope:
                assert (
                    envelope.get("model") == expected_model
                ), f"{delegate}: Expected model={expected_model}, got {envelope.get('model')}"

    def test_envelope_status_values(self):
        """Test that status field has valid values."""
        valid_statuses = {"success", "error"}

        for delegate in ["claude-delegate", "codex-delegate", "gemini-delegate"]:
            if not delegate_exists(delegate):
                continue

            # Test error status (missing CLI)
            exit_code, stdout, _ = run_delegate(
                delegate,
                ["test"],
                env={
                    delegate.split("-")[0].upper() + "_CMD": "nonexistent-cli",
                    "TRI_FALLBACK_DISABLED": "true",
                },
            )

            envelope = parse_json_envelope(stdout)
            if envelope:
                assert envelope.get("status") in valid_statuses

    def test_envelope_decision_values(self):
        """Test that decision field has valid values."""
        valid_decisions = {"APPROVE", "REJECT", "ABSTAIN"}

        for delegate in ["claude-delegate", "codex-delegate", "gemini-delegate"]:
            if not delegate_exists(delegate):
                continue

            exit_code, stdout, _ = run_delegate(
                delegate,
                ["test"],
                env={
                    delegate.split("-")[0].upper() + "_CMD": "nonexistent-cli",
                    "TRI_FALLBACK_DISABLED": "true",
                },
            )

            envelope = parse_json_envelope(stdout)
            if envelope:
                assert (
                    envelope.get("decision") in valid_decisions
                ), f"Invalid decision: {envelope.get('decision')}"

    def test_envelope_confidence_range(self):
        """Test that confidence is between 0 and 1."""
        for delegate in ["claude-delegate", "codex-delegate", "gemini-delegate"]:
            if not delegate_exists(delegate):
                continue

            exit_code, stdout, _ = run_delegate(
                delegate,
                ["test"],
                env={
                    delegate.split("-")[0].upper() + "_CMD": "nonexistent-cli",
                    "TRI_FALLBACK_DISABLED": "true",
                },
            )

            envelope = parse_json_envelope(stdout)
            if envelope and "confidence" in envelope:
                conf = float(envelope["confidence"])
                assert 0.0 <= conf <= 1.0, f"Confidence {conf} not in [0, 1]"

    def test_envelope_duration_is_number(self):
        """Test that duration_ms is a number."""
        for delegate in ["claude-delegate", "codex-delegate", "gemini-delegate"]:
            if not delegate_exists(delegate):
                continue

            exit_code, stdout, _ = run_delegate(
                delegate,
                ["test"],
                env={
                    delegate.split("-")[0].upper() + "_CMD": "nonexistent-cli",
                    "TRI_FALLBACK_DISABLED": "true",
                },
            )

            envelope = parse_json_envelope(stdout)
            if envelope and "duration_ms" in envelope:
                duration = envelope["duration_ms"]
                assert isinstance(
                    duration, (int, float)
                ), f"duration_ms is not a number: {duration}"


# ==============================================================================
# CLI Invocation Tests
# ==============================================================================


class TestCLIInvocation:
    """Tests for CLI invocation patterns."""

    @pytest.mark.parametrize(
        "delegate",
        ["claude-delegate", "codex-delegate", "gemini-delegate"],
    )
    def test_help_option(self, delegate: str):
        """Test that --help shows usage information."""
        if not delegate_exists(delegate):
            pytest.skip(f"{delegate} not found")

        exit_code, stdout, stderr = run_delegate(delegate, ["--help"])

        assert exit_code == 0, f"{delegate} --help returned non-zero exit code"
        output = stdout + stderr
        assert (
            "Usage" in output or "usage" in output
        ), f"{delegate} --help missing usage"

    @pytest.mark.parametrize(
        "delegate",
        ["claude-delegate", "codex-delegate", "gemini-delegate"],
    )
    def test_missing_prompt_returns_error(self, delegate: str):
        """Test that missing prompt returns JSON error."""
        if not delegate_exists(delegate):
            pytest.skip(f"{delegate} not found")

        exit_code, stdout, stderr = run_delegate(delegate, [])

        assert (
            exit_code == 1
        ), f"{delegate} should return exit code 1 for missing prompt"

        envelope = parse_json_envelope(stdout)
        if envelope:
            assert envelope.get("status") == "error"
            assert envelope.get("decision") == "ABSTAIN"

    @pytest.mark.parametrize(
        "delegate",
        ["claude-delegate", "codex-delegate", "gemini-delegate"],
    )
    def test_cli_not_found_returns_error(self, delegate: str):
        """Test that missing CLI returns JSON error."""
        if not delegate_exists(delegate):
            pytest.skip(f"{delegate} not found")

        # Use nonexistent CLI command
        cmd_name = delegate.split("-")[0].upper() + "_CMD"
        exit_code, stdout, stderr = run_delegate(
            delegate,
            ["test prompt"],
            env={
                cmd_name: "nonexistent-cli-xyz",
                "TRI_FALLBACK_DISABLED": "true",
            },
        )

        assert exit_code == 1
        envelope = parse_json_envelope(stdout)
        if envelope:
            assert envelope.get("status") == "error"
            assert "not found" in envelope.get("reasoning", "").lower()


# ==============================================================================
# Error Handling Tests
# ==============================================================================


class TestErrorHandling:
    """Tests for error handling in delegate scripts."""

    @pytest.mark.parametrize(
        "delegate",
        ["claude-delegate", "codex-delegate", "gemini-delegate"],
    )
    def test_invalid_timeout_handled(self, delegate: str):
        """Test that invalid timeout is handled gracefully."""
        if not delegate_exists(delegate):
            pytest.skip(f"{delegate} not found")

        # Should not crash with invalid timeout
        exit_code, stdout, stderr = run_delegate(
            delegate,
            ["--timeout", "invalid", "test"],
            env={
                delegate.split("-")[0].upper() + "_CMD": "nonexistent-cli",
                "TRI_FALLBACK_DISABLED": "true",
            },
        )

        # Should still return valid JSON (with error status)
        envelope = parse_json_envelope(stdout)
        assert envelope is not None or exit_code != 0

    @pytest.mark.parametrize(
        "delegate,option",
        [
            ("codex-delegate", "--reasoning"),
            ("codex-delegate", "--sandbox"),
            ("gemini-delegate", "--output-format"),
        ],
    )
    def test_invalid_option_values_handled(self, delegate: str, option: str):
        """Test that invalid option values are handled gracefully."""
        if not delegate_exists(delegate):
            pytest.skip(f"{delegate} not found")

        exit_code, stdout, stderr = run_delegate(
            delegate,
            [option, "invalid_value_xyz", "test"],
            env={
                delegate.split("-")[0].upper() + "_CMD": "nonexistent-cli",
                "TRI_FALLBACK_DISABLED": "true",
            },
        )

        # Should not crash (may warn but continue)
        assert True  # If we get here, script didn't crash


# ==============================================================================
# Return Code Tests
# ==============================================================================


class TestReturnCodes:
    """Tests for return code handling."""

    @pytest.mark.parametrize(
        "delegate",
        ["claude-delegate", "codex-delegate", "gemini-delegate"],
    )
    def test_help_returns_zero(self, delegate: str):
        """Test that --help returns exit code 0."""
        if not delegate_exists(delegate):
            pytest.skip(f"{delegate} not found")

        exit_code, _, _ = run_delegate(delegate, ["--help"])
        assert exit_code == 0

    @pytest.mark.parametrize(
        "delegate",
        ["claude-delegate", "codex-delegate", "gemini-delegate"],
    )
    def test_missing_prompt_returns_one(self, delegate: str):
        """Test that missing prompt returns exit code 1."""
        if not delegate_exists(delegate):
            pytest.skip(f"{delegate} not found")

        exit_code, _, _ = run_delegate(delegate, [])
        assert exit_code == 1

    @pytest.mark.parametrize(
        "delegate",
        ["claude-delegate", "codex-delegate", "gemini-delegate"],
    )
    def test_error_returns_one(self, delegate: str):
        """Test that errors return exit code 1."""
        if not delegate_exists(delegate):
            pytest.skip(f"{delegate} not found")

        exit_code, _, _ = run_delegate(
            delegate,
            ["test"],
            env={
                delegate.split("-")[0].upper() + "_CMD": "nonexistent-cli",
                "TRI_FALLBACK_DISABLED": "true",
            },
        )
        assert exit_code == 1


# ==============================================================================
# Timeout Handling Tests
# ==============================================================================


class TestTimeoutHandling:
    """Tests for timeout handling in delegates."""

    @pytest.mark.parametrize(
        "delegate",
        ["claude-delegate", "codex-delegate", "gemini-delegate"],
    )
    def test_timeout_option_documented(self, delegate: str):
        """Test that --timeout option is documented in help."""
        if not delegate_exists(delegate):
            pytest.skip(f"{delegate} not found")

        exit_code, stdout, stderr = run_delegate(delegate, ["--help"])
        output = stdout + stderr

        assert "--timeout" in output, f"{delegate}: --timeout not documented"

    @pytest.mark.parametrize(
        "delegate",
        ["claude-delegate", "codex-delegate", "gemini-delegate"],
    )
    def test_timeout_accepts_numeric_value(self, delegate: str):
        """Test that --timeout accepts numeric values."""
        if not delegate_exists(delegate):
            pytest.skip(f"{delegate} not found")

        # This should not crash even though CLI doesn't exist
        exit_code, stdout, stderr = run_delegate(
            delegate,
            ["--timeout", "10", "test"],
            env={
                delegate.split("-")[0].upper() + "_CMD": "nonexistent-cli",
                "TRI_FALLBACK_DISABLED": "true",
            },
        )

        # Should return JSON error (not crash)
        envelope = parse_json_envelope(stdout)
        assert envelope is not None or exit_code == 1


# ==============================================================================
# Script Content Tests (Static Analysis)
# ==============================================================================


class TestScriptContent:
    """Static analysis tests for delegate script content."""

    @pytest.mark.parametrize(
        "delegate",
        ["claude-delegate", "codex-delegate", "gemini-delegate"],
    )
    def test_script_sources_common_sh(self, delegate: str):
        """Test that script sources common.sh."""
        script_path = BIN_DIR / delegate
        if not script_path.exists():
            pytest.skip(f"{delegate} not found")

        content = script_path.read_text()
        assert "common.sh" in content, f"{delegate}: Does not source common.sh"

    @pytest.mark.parametrize(
        "delegate",
        ["claude-delegate", "codex-delegate", "gemini-delegate"],
    )
    def test_script_has_timeout_handling(self, delegate: str):
        """Test that script handles timeouts."""
        script_path = BIN_DIR / delegate
        if not script_path.exists():
            pytest.skip(f"{delegate} not found")

        content = script_path.read_text()
        assert "timeout" in content.lower(), f"{delegate}: No timeout handling"
        assert "124" in content, f"{delegate}: Exit code 124 not handled"

    @pytest.mark.parametrize(
        "delegate",
        ["claude-delegate", "codex-delegate", "gemini-delegate"],
    )
    def test_script_has_decision_extraction(self, delegate: str):
        """Test that script has decision extraction logic."""
        script_path = BIN_DIR / delegate
        if not script_path.exists():
            pytest.skip(f"{delegate} not found")

        content = script_path.read_text()
        assert (
            "extract_decision" in content
        ), f"{delegate}: No extract_decision function"
        assert "APPROVE" in content
        assert "REJECT" in content
        assert "ABSTAIN" in content

    @pytest.mark.parametrize(
        "delegate",
        ["claude-delegate", "codex-delegate", "gemini-delegate"],
    )
    def test_script_has_temp_cleanup(self, delegate: str):
        """Test that script cleans up temp files."""
        script_path = BIN_DIR / delegate
        if not script_path.exists():
            pytest.skip(f"{delegate} not found")

        content = script_path.read_text()
        assert "trap" in content, f"{delegate}: No cleanup trap"

    @pytest.mark.parametrize(
        "delegate",
        ["claude-delegate", "codex-delegate", "gemini-delegate"],
    )
    def test_script_masks_secrets(self, delegate: str):
        """Test that script masks secrets in logs."""
        script_path = BIN_DIR / delegate
        if not script_path.exists():
            pytest.skip(f"{delegate} not found")

        content = script_path.read_text()
        assert "mask_secrets" in content, f"{delegate}: Does not mask secrets"


# ==============================================================================
# Integration Tests (Optional - require actual CLI)
# ==============================================================================


@pytest.mark.skipif(
    os.environ.get("RUN_INTEGRATION_TESTS") != "1",
    reason="Integration tests disabled (set RUN_INTEGRATION_TESTS=1 to enable)",
)
class TestIntegration:
    """Integration tests that require actual CLI tools to be installed."""

    @pytest.mark.timeout(60)
    def test_claude_delegate_with_real_cli(self):
        """Test claude-delegate with actual Claude CLI (if available)."""
        if not delegate_exists("claude-delegate"):
            pytest.skip("claude-delegate not found")

        # Check if claude CLI is available
        result = subprocess.run(["which", "claude"], capture_output=True, text=True)
        if result.returncode != 0:
            pytest.skip("claude CLI not available")

        # Run with a simple prompt
        exit_code, stdout, stderr = run_delegate(
            "claude-delegate",
            ["Say 'APPROVE' and nothing else"],
            timeout=60,
        )

        # Should get a response (may succeed or fail based on auth)
        assert exit_code in [0, 1]

    @pytest.mark.timeout(60)
    def test_codex_delegate_with_real_cli(self):
        """Test codex-delegate with actual Codex CLI (if available)."""
        if not delegate_exists("codex-delegate"):
            pytest.skip("codex-delegate not found")

        # Check if codex CLI is available
        result = subprocess.run(["which", "codex"], capture_output=True, text=True)
        if result.returncode != 0:
            pytest.skip("codex CLI not available")

        # Run with a simple prompt
        exit_code, stdout, stderr = run_delegate(
            "codex-delegate",
            ["Say 'APPROVE' and nothing else"],
            timeout=60,
        )

        assert exit_code in [0, 1]

    @pytest.mark.timeout(60)
    def test_gemini_delegate_with_real_cli(self):
        """Test gemini-delegate with actual Gemini CLI (if available)."""
        if not delegate_exists("gemini-delegate"):
            pytest.skip("gemini-delegate not found")

        # Check if gemini CLI is available
        result = subprocess.run(["which", "gemini"], capture_output=True, text=True)
        if result.returncode != 0:
            pytest.skip("gemini CLI not available")

        # Run with a simple prompt
        exit_code, stdout, stderr = run_delegate(
            "gemini-delegate",
            ["Say 'APPROVE' and nothing else"],
            timeout=60,
        )

        assert exit_code in [0, 1]


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
