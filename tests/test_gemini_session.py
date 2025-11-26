#!/usr/bin/env python3
"""
Unit tests for GeminiSession utility.

Run with: pytest tests/test_gemini_session.py -v
"""

import json
import os
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent / "utils"))

from gemini_session import (
    GeminiSession,
    GeminiResponse,
    quick_gemini,
    SUPPORTED_MODELS,
)


class TestGeminiResponse:
    """Tests for GeminiResponse dataclass."""

    def test_init_success_response(self):
        """Test creating a successful response."""
        response = GeminiResponse(
            content="Hello!",
            success=True,
            session_id="abc123"
        )
        assert response.content == "Hello!"
        assert response.success is True
        assert response.error is None
        assert response.session_id == "abc123"

    def test_init_error_response(self):
        """Test creating an error response."""
        response = GeminiResponse(
            content="",
            success=False,
            error="Connection timeout"
        )
        assert response.content == ""
        assert response.success is False
        assert response.error == "Connection timeout"
        assert response.session_id is None


class TestGeminiSession:
    """Tests for GeminiSession class."""

    @pytest.fixture
    def temp_history_path(self):
        """Create a temporary file for history."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            f.write('[]')
            temp_path = Path(f.name)
        yield temp_path
        # Cleanup
        if temp_path.exists():
            temp_path.unlink()

    def test_init_default_model(self, temp_history_path):
        """Test default model is gemini-3-pro."""
        session = GeminiSession(history_path=temp_history_path)
        assert session.model == "gemini-3-pro"

    def test_init_custom_model(self, temp_history_path):
        """Test custom model selection."""
        session = GeminiSession(model="gemini-2.5-pro", history_path=temp_history_path)
        assert session.model == "gemini-2.5-pro"

    def test_init_invalid_model_raises_error(self, temp_history_path):
        """Test that invalid model raises ValueError."""
        with pytest.raises(ValueError) as exc_info:
            GeminiSession(model="invalid-model", history_path=temp_history_path)
        assert "Unsupported model" in str(exc_info.value)

    def test_init_creates_parent_directory(self):
        """Test that parent directory is created if missing."""
        with tempfile.TemporaryDirectory() as tmpdir:
            history_path = Path(tmpdir) / "subdir" / "history.json"
            session = GeminiSession(history_path=history_path)
            assert history_path.parent.exists()
            # Check directory has secure permissions
            assert (history_path.parent.stat().st_mode & 0o777) == 0o700

    def test_history_persistence(self, temp_history_path):
        """Test that history is saved and loaded correctly."""
        # Create session and add history
        session1 = GeminiSession(history_path=temp_history_path)
        session1.conversation_history = [
            {"role": "user", "content": "Hello", "timestamp": "2025-01-01T00:00:00"}
        ]
        session1._save_history()

        # Create new session and verify history loaded
        session2 = GeminiSession(history_path=temp_history_path)
        assert len(session2.conversation_history) == 1
        assert session2.conversation_history[0]["content"] == "Hello"

    def test_history_file_secure_permissions(self, temp_history_path):
        """Test that history file has secure permissions (0600)."""
        session = GeminiSession(history_path=temp_history_path)
        session._save_history()

        # Check file permissions (owner read/write only)
        mode = temp_history_path.stat().st_mode & 0o777
        assert mode == 0o600, f"Expected 0600, got {oct(mode)}"

    def test_clear_history(self, temp_history_path):
        """Test clearing conversation history."""
        session = GeminiSession(history_path=temp_history_path)
        session.conversation_history = [{"role": "user", "content": "test"}]
        session._save_history()

        session.clear_history()

        assert session.conversation_history == []
        assert not temp_history_path.exists()

    def test_get_history_returns_copy(self, temp_history_path):
        """Test that get_history returns a copy, not the original."""
        session = GeminiSession(history_path=temp_history_path)
        session.conversation_history = [{"role": "user", "content": "test"}]

        history = session.get_history()
        history.append({"role": "assistant", "content": "modified"})

        # Original should be unchanged
        assert len(session.conversation_history) == 1

    def test_build_command_basic(self, temp_history_path):
        """Test building basic command."""
        session = GeminiSession(
            model="gemini-3-pro",
            auto_approve=True,
            history_path=temp_history_path
        )
        cmd = session._build_command("Hello", include_context=False)

        assert "gemini" in cmd
        assert "-m" in cmd
        assert "gemini-3-pro" in cmd
        assert "-y" in cmd
        assert "Hello" in cmd

    def test_build_command_with_session_id(self, temp_history_path):
        """Test building command with session ID."""
        session = GeminiSession(
            session_id="test-session-123",
            history_path=temp_history_path
        )
        cmd = session._build_command("Hello", include_context=False)

        assert "--resume" in cmd
        assert "test-session-123" in cmd

    @patch('subprocess.run')
    def test_send_success(self, mock_run, temp_history_path):
        """Test successful send."""
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout="Hello! How can I help?",
            stderr=""
        )

        session = GeminiSession(history_path=temp_history_path)
        response = session.send("Hello")

        assert response.success is True
        assert response.content == "Hello! How can I help?"
        assert len(session.conversation_history) == 2  # user + assistant

    @patch('subprocess.run')
    def test_send_failure(self, mock_run, temp_history_path):
        """Test failed send."""
        mock_run.return_value = MagicMock(
            returncode=1,
            stdout="",
            stderr="Connection refused"
        )

        session = GeminiSession(history_path=temp_history_path)
        response = session.send("Hello")

        assert response.success is False
        assert "Connection refused" in response.error

    @patch('subprocess.run')
    def test_send_timeout(self, mock_run, temp_history_path):
        """Test timeout handling."""
        import subprocess
        mock_run.side_effect = subprocess.TimeoutExpired(cmd="gemini", timeout=300)

        session = GeminiSession(history_path=temp_history_path)
        response = session.send("Hello")

        assert response.success is False
        assert "timed out" in response.error.lower()


class TestQuickGemini:
    """Tests for quick_gemini function."""

    @patch('subprocess.run')
    def test_quick_gemini_success(self, mock_run):
        """Test quick_gemini successful call."""
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout="Quick response",
            stderr=""
        )

        with tempfile.TemporaryDirectory() as tmpdir:
            # Temporarily change home to use temp directory
            with patch.dict(os.environ, {'HOME': tmpdir}):
                result = quick_gemini("Hello")

        assert result == "Quick response"

    def test_quick_gemini_invalid_model(self):
        """Test quick_gemini with invalid model."""
        result = quick_gemini("Hello", model="invalid-model")
        assert "Error" in result
        assert "Unsupported model" in result


class TestSupportedModels:
    """Tests for model validation."""

    def test_gemini_3_pro_supported(self):
        """Test that gemini-3-pro is in supported models."""
        assert "gemini-3-pro" in SUPPORTED_MODELS

    def test_gemini_3_pro_preview_supported(self):
        """Test that gemini-3-pro-preview is in supported models."""
        assert "gemini-3-pro-preview" in SUPPORTED_MODELS

    def test_legacy_model_supported(self):
        """Test that legacy gemini-2.5-pro is still supported."""
        assert "gemini-2.5-pro" in SUPPORTED_MODELS


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
