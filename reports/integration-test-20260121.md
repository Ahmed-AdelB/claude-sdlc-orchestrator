# Integration Test Report - 2026-01-21

## Scope
- Files checked: `CLAUDE.md`, `v2/CLAUDE.md`, `skills/README.md`, `commands/agents/**`, `commands/**`
- System paths checked: `~/.claude/*`, `~/.gemini/*`, `~/.codex/*`
- Assumption: `.claude/...` paths resolve relative to `$HOME` (i.e., `~/.claude/...`).

## Results Summary
- CLAUDE.md references: PASS
- v2/CLAUDE.md references: FAIL (missing task/session/log dirs)
- Agent integrations: FAIL (1 missing agent)
- Skill invocation patterns: FAIL (placeholder skill files missing)
- Example commands: FAIL (missing slash commands + CLI subcommand gaps)
- Circular dependencies: PASS (none detected)

## Findings

### 1) CLAUDE.md References
- PASS: all `~/.claude/*`, `.claude/*`, `~/.gemini/*`, and `~/.codex/*` references resolve to existing files/dirs.

### 2) v2/CLAUDE.md References
Missing paths relative to `v2/`:
- `v2/tasks/queue`
- `v2/tasks/running`
- `v2/tasks/completed`
- `v2/tasks/failed`
- `v2/sessions`
- `v2/logs`

All other referenced paths in `v2/CLAUDE.md` exist (`config/tri-agent.yaml`, `lib/common.sh`, `bin/*`).

### 3) Agent integrates_with Targets
Missing target:
- `project-manager` referenced in `commands/agents/business/business-analyst.md` (no matching agent file in `commands/agents/**`).

All other integrates_with references resolve to existing agent files.

### 4) Skill Invocation Patterns
- `skills/README.md` lists future skill files under `~/.claude/skills/` (e.g., `sdlc/*.md`, `workflows/*.md`, `quality/*.md`, `security/review.md`, `tri-agent/consensus.md`, `git/*.md`). None of these files exist; only `skills/README.md` and `skills/.gitkeep` are present.
- `~/.codex/skills/` entries are valid: `frontend-design`, `nextjs-page`, `react-component`, `ui-engineer`, `web-dev`, plus system skills (`.system/skill-creator`, `.system/skill-installer`) all have `SKILL.md`.

### 5) Example Commands
Slash commands (CLAUDE.md):
- Present: `/sdlc:*`, `/create-*`, `/feature`, `/bugfix`, `/debug`, `/test`, `/review`, `/security-review`, `/codex`, `/gemini`, `/consensus`, `/route`, `/context-prime`, `/git/*`, `/document`, `/execute`, `/track`.
- Missing: `/github/issue/assign`, `/github/issue/complete`, `/github/issue/review`, `/github/issue/close` (no `commands/github/**`).

Slash commands (v2/CLAUDE.md):
- Missing: `/tri-status` (no command file).

CLI commands:
- Found in PATH: `gemini`, `codex`, `tri-agent` (symlink to `autonomous/bin/tri-agent`).
- `tri-agent preflight` should work (`autonomous/bin/tri-agent-preflight` exists).
- `tri-agent doctor --fix` likely fails (`autonomous/bin/tri-agent-doctor` missing).
- `tri-agent start --mode=24hr`, `tri-agent stats --live`, `tri-agent metrics ...`, `tri-agent replay --from ...` are not supported subcommands in `autonomous/bin/tri-agent` (standalone scripts exist in `v2/bin/` instead).

### 6) Circular Dependencies
- No cycles detected in the `integrates_with` graph under `commands/agents/**`.
