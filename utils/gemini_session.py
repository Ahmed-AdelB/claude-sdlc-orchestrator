#!/usr/bin/env python3
"""
GeminiSession - Wrapper for Gemini CLI with session management.

IMPORTANT: Uses positional prompts, NOT deprecated -p flag!

Usage:
    from gemini_session import GeminiSession

    session = GeminiSession(model="gemini-2.5-pro")
    response = session.send("Hello, how are you?")
    response = session.send("What did I just ask?")  # Maintains context

CLI Reference:
    gemini "prompt"                    # Basic usage (positional)
    gemini -m gemini-2.5-pro "prompt"  # With model selection
    gemini -y "prompt"                 # Auto-approve (YOLO mode)
    gemini --resume SESSION_ID "prompt" # Resume session
    gemini -i                          # Interactive mode
    gemini --list-sessions             # List sessions

    # DEPRECATED - DO NOT USE:
    gemini -p "prompt"                 # -p flag is deprecated!
"""

import subprocess
import json
import re
from pathlib import Path
from typing import Optional, List, Dict, Any
from dataclasses import dataclass
from datetime import datetime


@dataclass
class GeminiResponse:
    """Response from Gemini CLI."""
    content: str
    success: bool
    error: Optional[str] = None
    session_id: Optional[str] = None


class GeminiSession:
    """
    Gemini CLI wrapper with session management.

    Uses native Gemini CLI session features instead of deprecated -p flag.
    Maintains conversation history for multi-turn interactions.
    """

    def __init__(
        self,
        model: str = "gemini-2.5-pro",
        auto_approve: bool = True,
        session_id: Optional[str] = None,
        history_path: Optional[Path] = None
    ):
        """
        Initialize GeminiSession.

        Args:
            model: Gemini model to use (gemini-2.5-pro, gemini-2.0-flash)
            auto_approve: Use -y flag for auto-approval
            session_id: Existing session ID to resume
            history_path: Path to save conversation history
        """
        self.model = model
        self.auto_approve = auto_approve
        self.session_id = session_id
        self.history_path = history_path or Path.home() / ".claude" / "gemini_history.json"
        self.conversation_history: List[Dict[str, str]] = []

        if self.history_path.exists():
            self._load_history()

    def _load_history(self) -> None:
        """Load conversation history from file."""
        try:
            with open(self.history_path) as f:
                self.conversation_history = json.load(f)
        except (json.JSONDecodeError, FileNotFoundError):
            self.conversation_history = []

    def _save_history(self) -> None:
        """Save conversation history to file."""
        self.history_path.parent.mkdir(parents=True, exist_ok=True)
        with open(self.history_path, "w") as f:
            json.dump(self.conversation_history, f, indent=2)

    def _build_command(self, prompt: str, include_context: bool = True) -> List[str]:
        """
        Build the Gemini CLI command.

        Uses native session features:
        - Positional prompt (NOT deprecated -p)
        - --resume for session continuity
        - -m for model selection
        - -y for auto-approve
        """
        cmd = ["gemini"]

        # Add model selection
        if self.model:
            cmd.extend(["-m", self.model])

        # Add auto-approve if enabled
        if self.auto_approve:
            cmd.append("-y")

        # Resume existing session if available
        if self.session_id:
            cmd.extend(["--resume", self.session_id])

        # Build full prompt with context if needed
        if include_context and self.conversation_history:
            context_prompt = self._build_context_prompt(prompt)
            cmd.append(context_prompt)
        else:
            # Add positional prompt (NOT -p which is deprecated!)
            cmd.append(prompt)

        return cmd

    def _build_context_prompt(self, new_prompt: str) -> str:
        """Build prompt with conversation context."""
        if not self.conversation_history:
            return new_prompt

        parts = ["[Conversation History]"]
        for msg in self.conversation_history[-10:]:  # Last 10 messages
            role = msg["role"].capitalize()
            parts.append(f"{role}: {msg['content'][:500]}")  # Truncate long messages

        parts.append(f"\nUser: {new_prompt}")
        parts.append("\nAssistant:")

        return "\n\n".join(parts)

    def _extract_session_id(self, output: str) -> Optional[str]:
        """Extract session ID from Gemini output if present."""
        # Pattern may vary - adjust based on actual Gemini CLI output
        match = re.search(r'Session ID: ([a-zA-Z0-9-]+)', output)
        return match.group(1) if match else None

    def send(self, prompt: str, include_context: bool = True) -> GeminiResponse:
        """
        Send a prompt to Gemini and get response.

        Args:
            prompt: The prompt to send
            include_context: Include conversation history in prompt

        Returns:
            GeminiResponse with content, success status, and any errors
        """
        cmd = self._build_command(prompt, include_context)

        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=300  # 5 minute timeout
            )

            if result.returncode != 0:
                return GeminiResponse(
                    content="",
                    success=False,
                    error=result.stderr or f"Command failed with code {result.returncode}"
                )

            response_content = result.stdout.strip()

            # Try to extract session ID
            session_id = self._extract_session_id(result.stderr + result.stdout)
            if session_id:
                self.session_id = session_id

            # Update conversation history
            self.conversation_history.append({
                "role": "user",
                "content": prompt,
                "timestamp": datetime.now().isoformat()
            })
            self.conversation_history.append({
                "role": "assistant",
                "content": response_content,
                "timestamp": datetime.now().isoformat()
            })
            self._save_history()

            return GeminiResponse(
                content=response_content,
                success=True,
                session_id=self.session_id
            )

        except subprocess.TimeoutExpired:
            return GeminiResponse(
                content="",
                success=False,
                error="Request timed out after 5 minutes"
            )
        except Exception as e:
            return GeminiResponse(
                content="",
                success=False,
                error=str(e)
            )

    def clear_history(self) -> None:
        """Clear conversation history."""
        self.conversation_history = []
        if self.history_path.exists():
            self.history_path.unlink()

    def get_history(self) -> List[Dict[str, str]]:
        """Get current conversation history."""
        return self.conversation_history.copy()


def quick_gemini(prompt: str, model: str = "gemini-2.5-pro") -> str:
    """
    Quick one-shot Gemini call without session management.

    Args:
        prompt: The prompt to send
        model: Gemini model to use

    Returns:
        Response content or error message
    """
    session = GeminiSession(model=model)
    response = session.send(prompt, include_context=False)

    if response.success:
        return response.content
    else:
        return f"Error: {response.error}"


# CLI interface
if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("Usage: python gemini_session.py 'your prompt here'")
        print("\nOptions:")
        print("  --model MODEL    Specify model (default: gemini-2.5-pro)")
        print("  --no-context     Don't include conversation history")
        print("  --clear          Clear conversation history")
        sys.exit(1)

    model = "gemini-2.5-pro"
    include_context = True
    clear_history = False
    prompt_parts = []

    i = 1
    while i < len(sys.argv):
        arg = sys.argv[i]
        if arg == "--model" and i + 1 < len(sys.argv):
            model = sys.argv[i + 1]
            i += 2
        elif arg == "--no-context":
            include_context = False
            i += 1
        elif arg == "--clear":
            clear_history = True
            i += 1
        else:
            prompt_parts.append(arg)
            i += 1

    session = GeminiSession(model=model)

    if clear_history:
        session.clear_history()
        print("Conversation history cleared.")
        if not prompt_parts:
            sys.exit(0)

    if prompt_parts:
        prompt = " ".join(prompt_parts)
        response = session.send(prompt, include_context=include_context)

        if response.success:
            print(response.content)
        else:
            print(f"Error: {response.error}", file=sys.stderr)
            sys.exit(1)
