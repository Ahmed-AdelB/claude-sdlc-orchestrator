# Claude Code Autonomous & Continuous Operation Guide

**Version:** 1.0.0
**Last Updated:** Jan 2026

## Overview

This guide details the operational modes and procedures for running Claude Code autonomously for extended periods (24+ hours). It covers permission management, session persistence, and multi-agent architectures.

## Operation Modes

### 1. YOLO Mode (--dangerously-skip-permissions)
Bypasses all permission prompts for file system and shell access.
- **Use Case:** Isolated environments, Docker containers.
- **Command:** `claude --dangerously-skip-permissions`

### 2. Auto-Accept Mode
Interactive mode where edits and safe commands are auto-approved.
- **Toggle:** `Shift+Tab` in the CLI.
- **Use Case:** Supervised rapid development.

### 3. Headless Mode
Non-interactive execution for scripting and CI/CD.
- **Command:** `claude -p "prompt" --allowedTools "Bash,Read,Write"`

## Session Persistence

### tmux/Screen
To ensure sessions survive SSH disconnects:
```bash
tmux new -s autonomous
claude --dangerously-skip-permissions
# Detach with Ctrl+B, D
```

## Checkpoint & Recovery
The system uses SQLite WAL checkpointing to manage state size.
- **Daemon:** `wal-checkpoint-strategy.sh` runs every 10m.
- **Recovery:** Restarting the daemon automatically recovers the WAL state.

## Progress Tracking
Progress is tracked in `claude-progress.txt` at the project root.
- **Format:** See [PROGRESS-FILE-FORMAT.md](PROGRESS-FILE-FORMAT.md)