# Claude Project Instructions (Autonomous Root)

This repository is the autonomous root for the tri-agent orchestrator. Treat it as a CLI-first system with bash scripts in `bin/` and shared utilities in `lib/`.

## Quick Orientation
- Source of truth: `config/tri-agent.yaml`
- Shared utilities: `lib/common.sh` (config reads, trace IDs, strict bash)
- Primary entrypoints: `bin/tri-agent`, `bin/tri-agent-route`, `bin/claude-delegate`, `bin/codex-delegate`, `bin/gemini-delegate`
- Tasks: `tasks/queue`, `tasks/running`, `tasks/completed`, `tasks/failed`
- Sessions: `sessions/`
- Logs: `logs/`

## Delegation Guidelines
- Use `tri-agent-route` to auto-route tasks; use `--consensus` for critical decisions.
- Use `gemini-ask` for large context analysis and multi-file review.
- Use `codex-ask` for implementation and rapid fixes.

## Script Conventions
- Keep strict bash behavior (set -euo pipefail) via `lib/common.sh`.
- When adding flags, update both parsing and CLI invocation.
- Avoid editing generated session artifacts in `sessions/` unless necessary.

## Custom Slash Commands
Custom tri-agent slash commands live in `.claude/commands`:
- `/route` routes a task to the best model
- `/consensus` runs all three models and synthesizes
- `/codex` delegates implementation to Codex
- `/gemini` delegates large-context analysis to Gemini
- `/tri-status` shows current tri-agent status
