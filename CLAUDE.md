# Global SDLC Orchestration System

> **Version:** 2.1.0 | **Updated:** 2026-01-20 | **Author:** Ahmed Adel Bakr Alderai

## AI Stack ($420/month)

- **Claude Max** ($200): Primary orchestrator, 900 msg/5hr, Opus + Sonnet
- **ChatGPT Pro** ($200): Codex CLI (GPT-5.2-Codex) for prototyping, o3-pro for debugging
- **Google AI Pro** ($20): Gemini 2.5/3 Pro, 1M token context

## PDF File Handling (CRITICAL - DO NOT VIOLATE)

**NEVER read PDF files directly with the Read tool.** This causes encoding issues and corrupted output.

**Instead, use the PDF analysis system:**

1. Extract text first: `pdftotext file.pdf file.txt` or use docx extraction
2. For images in PDFs: Use image extraction tools
3. If `.extracted.txt` or `.docx.txt` exists, read that instead
4. For complex PDFs: Ask user to provide extracted content

**Why this matters:**

- Direct PDF reads produce garbled binary output
- Wastes context tokens on unusable data
- May crash or hang the session

**Allowed PDF operations:**

- `pdftotext`, `pdf2txt.py`, `pdfplumber` for text extraction
- `pdfimages` for image extraction
- Reading pre-extracted `.txt` files

## 95 Specialized Agents

**Categories (14):** General(6), Planning(8), Backend(10), Frontend(10), Database(6), Testing(8), Quality(8), Security(6), Performance(5), DevOps(8), Cloud(5), AI/ML(7), Integration(4), Business(4)

**Key agents:** `/agents/<category>/<name>` - Use via Skill tool

## 5-Phase Development Discipline (CCPM)

1. **Brainstorm**: `/sdlc:brainstorm` - Gather requirements, ask clarifying questions
2. **Document**: `/sdlc:spec` - Create specifications with acceptance criteria
3. **Plan**: `/sdlc:plan` - Technical design, mission breakdown (AB Method)
4. **Execute**: `/sdlc:execute` - Implement with parallel/sequential agents
5. **Track**: `/sdlc:status` - Monitor progress, update stakeholders

## Hybrid Adaptive Workflow

- **Sequential**: Dependent tasks (backend before frontend, types before components)
- **Parallel**: Independent tasks (git worktrees for isolation, CCPM pattern)
- **Decision Logic**: Task router determines execution mode based on dependencies

## Quality Gates (Never Compromise)

- All PRs require: `/review` + `/test`
- Security-sensitive code: `/security-review`
- Architecture changes: architect agent approval
- Critical changes: Multi-agent consensus (Claude + Codex + Gemini)
- Minimum test coverage: 80%
- Zero critical security vulnerabilities

## Security-First Code Generation (MANDATORY)

**Full details:** See `~/.claude/rules/security.md`

When generating code, always apply these security requirements:

- **Input Validation:** Validate and sanitize all user inputs
- **Parameterized Queries:** Use parameterized queries for all database operations (never string concatenation)
- **Error Handling:** Implement proper error handling; never expose stack traces to users
- **Least Privilege:** Follow principle of least privilege for all operations
- **Secure Defaults:** Use HTTPS, encrypted storage, secure cookies
- **No Hardcoded Secrets:** Never hardcode credentials, API keys, or secrets - use environment variables
- **Dependency Security:** Check for known vulnerabilities in dependencies before adding

## ENFORCED MULTI-AGENT PARALLELISM (CRITICAL REQUIREMENT)

**Full details:** See `~/.claude/rules/multi-agent.md`

**Quick Reference:** 9 concurrent agents (3 Claude + 3 Codex + 3 Gemini), 27 total per task.
Tiered: 1 (trivial) → 3 (standard) → 9 (complex). Degraded mode: minimum 3.

**Enforcement:** All 3 models in each phase, 2+ AI verification, security review by 2 AIs.

## MAXIMUM CAPABILITY STANDARDS (MANDATORY)

**Full details:** See `~/.claude/rules/capability.md`

**NEVER use weaker models or configurations to save tokens. Maximum capability is required at all times.**

### 1. Gemini Maximum Capability (MANDATORY)

```bash
# READ-ONLY (analysis, review, docs) - YOLO allowed:
gemini -m gemini-3-pro-preview --approval-mode yolo "Analyze: ..."

# MODIFICATIONS (code changes, git) - Manual approval:
gemini -m gemini-3-pro-preview "Implement: ..."
```

- **1M token context**: Full codebase analysis
- **Pro routing**: Always most capable model
- **No Downgrade Rule:** Never use `gemini-1.5-flash` or shorthand `-m pro` (may misroute).

### 2. Codex Maximum Capability (MANDATORY)

```bash
# DEFAULT (workspace-write) - Use for most tasks:
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "task"

# ESCALATED (danger-full-access) - Only after checklist below:
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s danger-full-access "task"
```

- **xhigh reasoning**: Maximum reasoning depth
- **400K context**: Large codebase understanding
- **No Downgrade Rule:** Never use `gpt-4o` or lower reasoning settings.

**⚠️ danger-full-access Escalation Checklist:**
Before using `-s danger-full-access`, verify ALL:

- [ ] Task genuinely requires system-wide access (not just workspace)
- [ ] Running in isolated container/VM (not host system)
- [ ] Security review completed by second AI
- [ ] Backup/checkpoint created before execution
- [ ] Changes will be reviewed post-execution
      _Default to `-s workspace-write` unless all boxes checked._

**⚠️ YOLO Mode (`-y`/`--approval-mode yolo`) Policy:**
| Operation Type | YOLO Allowed? | Rationale |
|----------------|---------------|-----------|
| Read-only analysis | ✅ Yes | No risk of modification |
| Code review | ✅ Yes | Analysis only |
| Documentation generation | ✅ Yes | Output can be reviewed |
| File modifications | ❌ No | Requires explicit approval |
| Git operations | ❌ No | Risk of data loss |
| Deployments | ❌ No | Production impact |
| System commands | ❌ No | Security risk |
_Use YOLO only for read-only operations. For modifications, use manual approval._

### 3. Claude Maximum Capability (MANDATORY)

- **Architecture/Security:** Use `ultrathink` (32K tokens)
- **Implementation:** Use standard `thinking` (4K-10K tokens)
- **Opus model**: Deepest analysis via Task tool with model="opus"
- **No Downgrade Rule:** Do not turn off thinking mode for code generation.

### Enforcement Checklist (Capability Verification)

- [ ] **Gemini:** Verified `-m gemini-3-pro-preview` is used
- [ ] **Codex:** Verified `xhigh` reasoning is active
- [ ] **Claude:** Verified thinking mode is enabled
- [ ] **Context:** Verified full relevant context was loaded
- [ ] **Downgrade Check:** Confirmed no lower-tier models were selected

## UNIFIED TRI-AGENT WORKFLOW PROTOCOL (MANDATORY)

> **This protocol MUST be followed for EVERY task. NO EXCEPTIONS.**

### Phase 1: Pre-Work Cross-AI Clarification

**BEFORE building any TODO list:**

```bash
gemini -m gemini-3-pro-preview --approval-mode yolo "Explain requirements, edge cases, challenges for: [task]"
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "Analyze implementation steps and dependencies for: [task]"
```

Synthesize both perspectives before proceeding.

### Phase 2: Build Complete TODO List

**NO work begins until TODO is 100% complete:**

1. Extract ALL tasks from plans and AI clarifications
2. Break complex tasks into verifiable subtasks
3. Assign each task to Claude, Codex, or Gemini (distribute evenly)
4. Assign DIFFERENT AI as verifier for each task

| AI         | Assign For                         |
| ---------- | ---------------------------------- |
| **Claude** | Core logic, architecture, security |
| **Codex**  | Scripts, tests, APIs, prototyping  |
| **Gemini** | Codebase analysis, docs, reviews   |

### Phase 3: User Approval Gate (BLOCKING)

Present to user and **STOP**:

- Complete TODO table with AI assignments
- Scope and approach summary
- **DO NOT proceed without explicit "approved"**

**During work, pause for:** Scope changes, security-sensitive ops, budget impacts.

### Phase 4: Implementation with Verification

**NO task is DONE until:**

1. Implementation complete by assigned AI
2. Verification by DIFFERENT AI reports PASS/FAIL
3. Status updated only after verification passes

```bash
gemini -m gemini-3-pro-preview --approval-mode yolo "Verify: [desc]. Check correctness, security, edges. PASS/FAIL."
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "Verify: [desc]. Check logic, completeness. PASS/FAIL."
```

### TODO Table Format

```markdown
| ID    | Task          |      Assigned       |    Verifier    |  Status  |  V  |
| ----- | ------------- | :-----------------: | :------------: | :------: | :-: |
| T-001 | [Description] | Claude/Codex/Gemini | [Different AI] | [Status] | [ ] |
```

**Example:**
| ID | Task | Assigned | Verifier | Status | V |
|----|------|:--------:|:--------:|:------:|:-:|
| T-001 | Design webhook schema | Claude | Gemini | Completed | [x] |
| T-002 | Implement idempotency | Codex | Claude | Verified | [x] |
| T-003 | Add retry logic | Claude | Codex | Ready for Verify | [ ] |
| T-004 | Create refund endpoint | Codex | Gemini | In Progress | [ ] |
| T-005 | Write integration tests | Gemini | Claude | Pending | [ ] |

**Status Flow:** `Pending → In Progress → Ready for Verify → Verified → Completed`

| Status             | Meaning               | Next Action             |
| ------------------ | --------------------- | ----------------------- |
| `Pending`          | Not started           | Begin work              |
| `In Progress`      | Work underway         | Complete implementation |
| `Ready for Verify` | Awaiting verification | Request verification    |
| `Verified`         | PASSED                | Mark completed          |
| `Completed`        | Fully done            | Archive/close           |
| `Blocked`          | Cannot proceed        | Resolve blocker         |
| `Failed`           | Verification FAILED   | Fix and re-verify       |

**Verification Marks:** `[ ]` pending | `[x]` passed | `[!]` failed | `[?]` inconclusive (escalate)

**Runtime:** Every AI MUST continuously add discovered requirements, update status in real-time, flag blockers, record verification results.

## VERIFICATION PROTOCOL (TWO-KEY RULE)

**Full details:** See `~/.claude/rules/verification.md`

**Quick Reference:**

- **VERIFY format:** Scope, Change summary, Expected behavior, Repro steps, Evidence, Risk notes
- **Results:** PASS (all match) | FAIL (issues found) | INCONCLUSIVE (escalate)
- **Marks:** `[ ]` pending | `[x]` passed | `[!]` failed | `[?]` inconclusive
- **Re-verify:** Fresh request required after FAIL; verifier re-runs full scope
- **Stalemate:** 2 cycles max → escalate to user (primary) OR third AI consensus (alternative)
- **Rollback:** 3 FAILs OR critical error → `git revert` → re-run original verification → require new plan before retry

**Examples:** See `~/.claude/rules/verification.md` for comprehensive FAIL cycle examples with re-verification workflow.

## PARTIAL BATCH FAILURE STRATEGY

When running parallel agents and <100% succeed:

1. **Quarantine** failed tasks immediately
2. **Commit** successful results (don't block on failures)
3. **Analyze** failure type:
   - Model error → Retry with different model
   - Context error → Split task and retry
   - Logic error → Escalate for manual review
4. **Retry** failed tasks with alternate model OR escalate to human
5. **Document** failure patterns for future prevention

## PROGRESS REPORTING CADENCE & FORMAT

**Reporting Frequency:**

- **Routine Updates:** Every 30 minutes or after completing a major todo item.
- **Exception Updates:** IMMEDIATELY upon encountering an error or blocker.

**Required Metrics:**

1. **Status:** (On Track / At Risk / Blocked)
2. **Completion %:** Estimated percentage of current task.
3. **Token Usage:** Current session token count.
4. **Next Milestone:** Time/Goal for the next checkpoint.

**Blocker Escalation:**

- If a task takes >15 mins longer than expected: **REPORT**.
- If an error persists after 1 retry: **REPORT**.
- If tool output is ambiguous: **ASK FOR CLARIFICATION**.

**Status Template:**

```markdown
**STATUS UPDATE: [Timestamp]**

- **Current Task:** [Task ID/Name]
- **Status:** [🟢 On Track / 🟡 At Risk / 🔴 Blocked]
- **Progress:** [XX]% complete
- **Recent Action:** [One sentence summary]
- **Next Step:** [Immediate next action]
- **Issues:** [None / Description of blocker]
```

## SESSION INITIALIZATION (MANDATORY)

**Pre-flight checklist - ALL checks must pass before work begins.**

```bash
#!/bin/bash
# Run: tri-agent preflight OR copy/paste this block
set -e; F=0; echo "=== TRI-AGENT PRE-FLIGHT ==="
# 1. Tool versions (node 18+, python 3.10+, git 2.30+)
node -v | grep -qE 'v(1[89]|[2-9][0-9])' && echo "[OK] Node $(node -v)" || { echo "[FAIL] Node <18"; F=1; }
python3 -c "import sys; exit(0 if sys.version_info >= (3,10) else 1)" && echo "[OK] Python $(python3 --version)" || { echo "[FAIL] Python <3.10"; F=1; }
git --version | grep -qE '2\.([3-9][0-9]|[0-9]{3})' && echo "[OK] Git" || { echo "[FAIL] Git <2.30"; F=1; }
# 2. Git state (warn on uncommitted tracked files)
[[ -z "$(git status --porcelain 2>/dev/null | grep -v '^??')" ]] && echo "[OK] Git clean" || echo "[WARN] Uncommitted changes"
# 3. Database integrity
for db in ~/.claude/state/*.db 2>/dev/null; do sqlite3 "$db" "PRAGMA integrity_check;" | grep -q "^ok$" && echo "[OK] DB: $(basename $db)" || { echo "[FAIL] DB: $db"; F=1; }; done
# 4. Credentials (Gemini + Codex)
[[ -f ~/.gemini/oauth_creds.json && -s ~/.gemini/oauth_creds.json ]] && echo "[OK] Gemini creds" || { echo "[FAIL] Gemini auth"; F=1; }
[[ -n "$OPENAI_API_KEY" || -f ~/.codex/config.toml ]] && echo "[OK] Codex creds" || { echo "[FAIL] Codex auth"; F=1; }
# 5. Disk space (min 2GB)
FREE=$(df -BG ~ 2>/dev/null | awk 'NR==2{gsub("G","");print $4}'); [[ ${FREE:-0} -ge 2 ]] && echo "[OK] Disk: ${FREE}GB" || { echo "[FAIL] Disk <2GB"; F=1; }
# 6. Network (API endpoints)
curl -sf --max-time 5 https://api.anthropic.com >/dev/null && echo "[OK] Claude API" || echo "[WARN] Claude unreachable"
curl -sf --max-time 5 https://generativelanguage.googleapis.com >/dev/null && echo "[OK] Gemini API" || echo "[WARN] Gemini unreachable"
curl -sf --max-time 5 https://api.openai.com >/dev/null && echo "[OK] OpenAI API" || echo "[WARN] OpenAI unreachable"
echo "=== PRE-FLIGHT $([ $F -eq 0 ] && echo 'PASSED' || echo 'FAILED') ==="; exit $F
```

**Quick:** `tri-agent preflight` | **Fix issues:** `tri-agent doctor --fix`

## 24-HOUR CONTINUOUS OPERATION

**Full documentation:** See `~/.claude/context/24hr-operations.md`

**Quick Reference:** Session refresh 8hr | Context limits: Claude 150K, Gemini 750K, Codex 300K | Failover: Claude→Gemini→split | Budget: 70% warn→85% pause→95% stop

**Commands:** `tri-agent start --mode=24hr` | `health` | `checkpoint` | `resume`

## Multi-Model Routing

| Task Type               | Primary Model   | When to Use                                           |
| ----------------------- | --------------- | ----------------------------------------------------- |
| Architecture & Design   | Claude Opus     | Deep reasoning, complex decisions                     |
| Implementation          | Claude Sonnet   | Standard coding, speed + quality                      |
| Rapid Prototyping       | Codex CLI       | Fast iteration, alternatives                          |
| Large Codebase Analysis | Gemini          | Context > 100K tokens                                 |
| Complex Debugging       | o3-pro          | Extended reasoning chains                             |
| Documentation           | Gemini          | Long-form writing                                     |
| Code Review             | Claude Sonnet   | Balanced analysis                                     |
| Security Audit          | Claude Opus     | Thorough vulnerability analysis                       |
| Ultra Architecture      | Claude Opus Max | `/agents/ai-ml/claude-opus-max` - ultrathink 32K      |
| Project Refactoring     | Codex Max       | `/agents/ai-ml/codex-max` - xhigh reasoning           |
| Full Codebase Analysis  | Gemini Deep     | `/agents/ai-ml/gemini-deep` - gemini-3-pro 1M context |

## Token Budget Management

| Task Type           | Max Input | Max Output | Total Budget |
| ------------------- | --------- | ---------- | ------------ |
| Quick fix           | 10K       | 2K         | 12K          |
| Standard feature    | 50K       | 10K        | 60K          |
| Refactoring         | 100K      | 20K        | 120K         |
| Architecture review | 150K      | 30K        | 180K         |

**Model Selection for Cost:**

- **Sonnet:** Default for 80% of tasks (best cost/quality)
- **Opus:** Architecture, security, complex debugging only
- **Haiku:** Linting, formatting, simple queries

## Extended Thinking Control

**Toggle:** `Alt+T` (Linux/Win) or `Option+T` (Mac)
**Configure:** `/config` → set thinking default
**View thinking:** `Ctrl+O` (verbose mode)
**Budget:** `export MAX_THINKING_TOKENS=32000`

| Budget  | Use Case                      |
| ------- | ----------------------------- |
| 4K-10K  | Simple reasoning              |
| 16K-32K | Complex tasks, debugging      |
| 32K+    | Architecture, security audits |

**Note:** Phrases like "think hard" or "ultrathink" do NOT allocate thinking tokens. Use the settings above.

## Slash Commands

### SDLC Phase Commands

- `/sdlc:brainstorm [feature]` - Phase 1: Requirements
- `/sdlc:spec [feature]` - Phase 2: Documentation
- `/sdlc:plan [feature]` - Phase 3: Technical design
- `/sdlc:execute [feature] [mission]` - Phase 4: Implementation
- `/sdlc:status` - Phase 5: Progress tracking

### AB Method Commands

- `/create-task [desc]` - Define new task with specs
- `/create-mission` - Break task into focused missions
- `/resume-mission` - Continue incomplete mission
- `/test-mission` - Generate tests for mission
- `/ab-master` - Orchestrate workflow

### Utility Commands

- `/feature [desc]` - Full feature workflow (all phases)
- `/bugfix [desc]` - Bug fix with root cause analysis
- `/debug [issue]` - Debug assistance with root cause analysis
- `/test [target]` - Generate comprehensive tests
- `/review [target]` - Multi-agent code review
- `/security-review [target]` - OWASP vulnerability scan
- `/codex [task]` - Execute via Codex CLI
- `/gemini [task]` - Execute via Gemini CLI (1M context)
- `/consensus [task]` - Tri-agent consensus (Claude + Codex + Gemini)
- `/route [type] [task]` - Route to optimal model
- `/context-prime` - Load project context

### Git Commands

- `/git/branch [name]` - Create and manage branches
- `/git/commit [message]` - Create commits with quality gates
- `/git/pr [title]` - Create pull requests
- `/git/sync` - Sync with remote branches

## GITHUB ISSUE WORKFLOW (TRI-AGENT MANDATORY)

### Issue Lifecycle

```
OPEN → ASSIGNED → IN_PROGRESS → REVIEW_1 → REVIEW_2 → CLOSED
                       ↑______________|  (if FAIL)
```

### Enforcement Rules (BLOCKING)

1. **3 Different AI Models Required**: Implementer ≠ Reviewer1 ≠ Reviewer2
2. **Cannot Close Without 2 Approvals** from different models
3. **All Comments Signed**: Ahmed Adel Bakr Alderai (no AI attribution)
4. **Status Updates Every 30 Minutes** during active work

### Agent Assignment by Issue Type

| Category      | Implementer | Reviewer 1 | Reviewer 2 |
| ------------- | ----------- | ---------- | ---------- |
| Security      | Claude      | Codex      | Gemini     |
| UI/Frontend   | Codex       | Claude     | Gemini     |
| Documentation | Gemini      | Claude     | Codex      |
| Complex Logic | Claude      | Gemini     | Codex      |
| Testing       | Codex       | Gemini     | Claude     |
| API/Backend   | Codex       | Claude     | Gemini     |

### GitHub Issue Commands

- `/github/issue/assign #N` - Assign with tri-agent commitment
- `/github/issue/complete #N` - Request review (post VERIFY block)
- `/github/issue/review #N PASS|FAIL` - Submit review decision
- `/github/issue/close #N` - Close (requires 2 approvals from different AIs)

### Comment Templates

See: `.claude/docs/issue-templates.md`

### Integration

- Uses existing VERIFY block format (see Two-Key Rule)
- Uses TODO-First Protocol for implementation planning
- Follows Attribution Rules (Ahmed Adel Bakr Alderai only)

### Command Aliases

- `/document` → `/sdlc:spec` - Create documentation
- `/execute` → `/sdlc:execute` - Execute implementation
- `/track` → `/sdlc:status` - Track progress

## Commit Format (Tri-Agent)

```
type(scope): description

Body explaining what and why

Tri-Agent Approval:
- Claude (Sonnet): APPROVE
- Codex (GPT-5.2): APPROVE
- Gemini (3 Pro): APPROVE

Author: Ahmed Adel Bakr Alderai
```

**Example:**

```
feat(auth): implement OAuth2 PKCE flow for mobile clients

Adds PKCE support to prevent authorization code interception
attacks on mobile devices. Includes code_verifier generation,
SHA256 challenge, and state validation.

Tri-Agent Approval:
- Claude (Sonnet): APPROVE - Architecture follows RFC 7636
- Codex (GPT-5.2): APPROVE - Tests pass
- Gemini (3 Pro): APPROVE - Security reviewed

Author: Ahmed Adel Bakr Alderai
```

## MCP Servers

- **git**: Version control operations
- **github**: Issues, PRs, repos via API
- **postgres**: Database queries and schema
- **filesystem**: File system access

## CLI Tool Usage (CRITICAL)

### Gemini CLI

```bash
# CANONICAL COMMAND (see "Maximum Capability Standards" for full syntax):
gemini -m gemini-3-pro-preview --approval-mode yolo "prompt"

# Session management
gemini -r latest                      # Resume most recent session
gemini --list-sessions                # List available sessions
```

### Gemini Configuration File (~/.gemini/settings.json)

```json
{
  "security": {
    "auth": {
      "selectedType": "oauth-personal"
    }
  },
  "tools": {
    "sandbox": false
  },
  "previewFeatures": true,
  "general": {
    "previewFeatures": true,
    "preferredModel": "gemini-3-pro-preview"
  },
  "routing": {
    "preferPro": true
  },
  "thinking": {
    "level": "high"
  }
}
```

### Gemini 3 Pro Setup

**Requirements:** CLI v0.18.x+ (`npm install -g @google/gemini-cli@latest`), AI Pro subscription, Preview Features enabled
**Enable:** `gemini` → `/settings` → Enable Preview → `/model` → Select "Pro routing"
**Routing:** Auto (Flash for simple, Pro for complex) or Pro routing (always most capable)
**Limits:** Daily quota; `resets after Xh` shown in errors. Switch to 2.5 Pro or wait.
**Best for:** 1M context analysis, multimodal tasks, agentic coding, documentation

### Gemini Sessions

```bash
gemini -m gemini-3-pro-preview "Analyze..."       # New conversation
gemini -m gemini-3-pro-preview -r latest "..."    # Resume latest session
gemini --list-sessions                            # Manage sessions
```

**Tip:** Use `-r latest` to maintain context across multiple commands without re-explaining the task.

### Gemini Authentication

**Account:** Configured via `~/.gemini/oauth_creds.json` (Personal OAuth)

**Auth Type:** `oauth-personal` - No GOOGLE_CLOUD_PROJECT required

```bash
# Check account status
gemini-switch

# If GOOGLE_CLOUD_PROJECT error occurs, unset it:
unset GOOGLE_CLOUD_PROJECT
```

**Credentials Location:** `~/.gemini/oauth_creds.json` (ensure `chmod 600`)

### Codex CLI (GPT-5.2)

```bash
# CANONICAL COMMAND (see "Maximum Capability Standards" for full syntax):
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "task"

# With o3 for complex reasoning:
codex exec -m o3 -c 'model_reasoning_effort="xhigh"' -s workspace-write "complex reasoning task"

# View help
codex --help
```

### Codex Configuration File (~/.codex/config.toml)

```toml
model = "gpt-5.2-codex"
model_provider = "openai"
model_context_window = 400000
model_max_output_tokens = 128000
model_reasoning_effort = "xhigh"    # Options: none, minimal, low, medium, high, xhigh
approval_policy = "never"
sandbox_mode = "workspace-write"   # Or "danger-full-access" for full system access
```

### Tri-Agent CLI Pattern

```bash
# 1. Claude (primary orchestration) - Direct in Claude Code
# 2. Codex (implementation)
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "Implement: <task>"

# 3. Gemini (validation/security - read-only, YOLO OK)
gemini -m gemini-3-pro-preview --approval-mode yolo "Review for security: <code>"
```

### CLI Error Handling

| Exit Code | Meaning       | Recovery                        |
| --------- | ------------- | ------------------------------- |
| `0`       | Success       | Proceed                         |
| `1`       | General error | Check syntax                    |
| `2`       | Auth failed   | `gemini-switch` or `codex auth` |
| `124`     | Timeout       | Increase timeout or split task  |
| `429`     | Rate limited  | Backoff: wait 2^n seconds       |

### Timeout Specifications

| Operation  | Default | Max   |
| ---------- | ------- | ----- |
| Gemini CLI | 120s    | 600s  |
| Codex CLI  | 180s    | 600s  |
| Full task  | 1800s   | 3600s |

## Code Style

- TypeScript: Strict mode, explicit types
- Python: Type hints, async/await for I/O
- Formatting: Prettier (JS/TS), Black (Python)
- Linting: ESLint, Ruff
- Commits: Conventional commits

## Alerting & Notification (P3.2)

### Alert Levels and Routing

| Level        | Response Time  | Notification Method   | Example Triggers                                |
| ------------ | -------------- | --------------------- | ----------------------------------------------- |
| **CRITICAL** | Immediate      | Desktop + Sound + Log | Daemon crash, security breach, budget exhausted |
| **ERROR**    | < 5 min        | Desktop + Log         | Task failure, API error, rate limit             |
| **WARNING**  | < 15 min       | Log only              | High memory, slow response, context near limit  |
| **INFO**     | Batched hourly | Log only              | Task completed, checkpoint created              |

### Notification Hooks

```bash
# Desktop notification (requires libnotify)
notify-send -u critical "Tri-Agent CRITICAL" "Daemon crashed: $REASON"

# Slack webhook (optional)
curl -X POST "$SLACK_WEBHOOK_URL" \
  -H 'Content-Type: application/json' \
  -d '{"text":"CRITICAL: '"$MESSAGE"'"}'

# Email via msmtp (optional)
printf "Subject: Tri-Agent Alert\n\n%s" "$MESSAGE" | msmtp "$ALERT_EMAIL"
```

### Alert Configuration

```bash
# ~/.claude/alerts.conf
ALERT_LEVEL_THRESHOLD="warning"  # minimum level to log
DESKTOP_NOTIFY_ENABLED=true
SLACK_WEBHOOK_URL=""             # optional
ALERT_EMAIL=""                   # optional
SOUND_ENABLED=true               # play sound for critical
```

## Metrics & Observability (P3.3)

### Key Performance Indicators (KPIs)

| Metric            | Target  | Alert Threshold | Collection Method               |
| ----------------- | ------- | --------------- | ------------------------------- |
| Task Success Rate | > 95%   | < 90%           | `tasks.completed / tasks.total` |
| Avg Task Duration | < 5 min | > 10 min        | `avg(task.end - task.start)`    |
| Agent Utilization | > 70%   | < 50%           | `active_agents / max_agents`    |
| Context Usage     | < 80%   | > 90%           | `tokens_used / context_limit`   |
| Error Rate        | < 5%    | > 10%           | `errors / total_operations`     |
| Lock Contention   | < 10%   | > 20%           | `lock_failures / lock_attempts` |

### Metrics Collection

```bash
# Prometheus-style metrics endpoint
# Location: ~/.claude/metrics/current.prom

# Metric format:
tri_agent_tasks_total{status="completed"} 1234
tri_agent_tasks_total{status="failed"} 56
tri_agent_active_agents 9
tri_agent_context_tokens_used 145000
tri_agent_session_duration_seconds 3600
```

### Dashboard Commands

```bash
# Real-time stats
tri-agent stats --live

# Historical metrics
tri-agent metrics --range 24h --format json

# Export for Grafana
tri-agent metrics --export prometheus > metrics.prom
```

### OpenTelemetry Integration (Optional)

```bash
# Enable OTEL export
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317"
export OTEL_SERVICE_NAME="tri-agent"
tri-agent start --telemetry
```

## Graceful Degradation Policy (P3.4)

### Failure Response Hierarchy

```
Level 1: Retry with backoff (3 attempts, 2^n seconds)
    ↓ (if still failing)
Level 2: Failover to alternate model
    ↓ (if unavailable)
Level 3: Queue for later retry
    ↓ (if queue full or critical)
Level 4: Notify and pause
```

### Model Failover Chain

| Primary       | Failover 1     | Failover 2    | Last Resort    |
| ------------- | -------------- | ------------- | -------------- |
| Claude Opus   | Claude Sonnet  | Gemini Pro    | Queue + Notify |
| Gemini 3 Pro  | Gemini 2.5 Pro | Claude Sonnet | Queue + Notify |
| Codex GPT-5.2 | Codex o3       | Claude Sonnet | Queue + Notify |

### Circuit Breaker States

```
CLOSED (normal) → 5 failures → OPEN (blocking)
                                    ↓ 60 seconds
                              HALF-OPEN (testing)
                                    ↓ success
                              CLOSED (normal)
```

### Degradation Configuration

```bash
# ~/.claude/degradation.conf
MAX_RETRIES=3
RETRY_BACKOFF_BASE=2
CIRCUIT_BREAKER_THRESHOLD=5
CIRCUIT_BREAKER_TIMEOUT=60
QUEUE_MAX_SIZE=100
FAILOVER_ENABLED=true
```

### Degraded Mode Operations

When in degraded mode:

- [ ] Reduce concurrent agents to minimum (3)
- [ ] Disable non-essential MCP servers
- [ ] Extend timeout thresholds 2x
- [ ] Queue low-priority tasks
- [ ] Log all operations for post-incident review

## Data Retention & Cleanup (P3.5)

### Retention Policies

| Data Type    | Retention Period | Cleanup Frequency | Location                              |
| ------------ | ---------------- | ----------------- | ------------------------------------- |
| Audit Logs   | 365 days         | Weekly            | `~/.claude/logs/audit/` (append-only) |
| Session Logs | 7 days           | Daily             | `~/.claude/logs/sessions.log`         |
| Checkpoints  | 3 days           | Every 8 hours     | `~/.claude/sessions/checkpoints/`     |
| Snapshots    | 7 days           | Daily             | `~/.claude/sessions/snapshots/`       |
| Task Files   | 14 days          | Daily             | `~/.claude/tasks/`                    |
| Metrics      | 90 days          | Weekly            | `~/.claude/metrics/`                  |
| Backups      | 30 days          | Daily             | `~/.claude/backups/`                  |

### Automated Cleanup Script

```bash
#!/bin/bash
# ~/.claude/scripts/cleanup.sh
# Run via cron: 0 3 * * * ~/.claude/scripts/cleanup.sh

LOG_DIR="${HOME}/.claude/logs"
SESSION_DIR="${HOME}/.claude/sessions"

# Safety: Validate paths exist
[[ -d "$LOG_DIR" ]] || { echo "ERROR: LOG_DIR missing"; exit 1; }
[[ -d "$SESSION_DIR" ]] || { echo "ERROR: SESSION_DIR missing"; exit 1; }

# Rotate logs > 50MB
find "$LOG_DIR" -name "*.log" -size +50M -exec gzip {} \;

# Delete old audit logs (365 days for compliance, append-only)
find "$LOG_DIR/audit" -name "*.jsonl" -mtime +365 -delete
find "$LOG_DIR/audit" -name "*.jsonl.gz" -mtime +365 -delete
chattr +a "$LOG_DIR/audit"/*.jsonl 2>/dev/null || true  # Enforce append-only

# Delete old checkpoints
find "$SESSION_DIR/checkpoints" -name "*.json" -mtime +3 -delete

# Delete old snapshots
find "$SESSION_DIR/snapshots" -name "*.json" -mtime +7 -delete

# Vacuum SQLite databases
for db in "${HOME}/.claude/state"/*.db; do
    sqlite3 "$db" "VACUUM; PRAGMA wal_checkpoint(TRUNCATE);"
done

# Report disk usage
du -sh "${HOME}/.claude" >> "$LOG_DIR/disk-usage.log"
```

### Disk Space Alerts

```bash
# Minimum free space thresholds
DISK_WARN_THRESHOLD_GB=5     # Warning if < 5GB free
DISK_CRITICAL_THRESHOLD_GB=2 # Emergency stop if < 2GB free
```

## Incident Response

**Full runbooks:** See `.claude/docs/incident-runbooks.md`

| Runbook           | Severity | Trigger                 |
| ----------------- | -------- | ----------------------- |
| Daemon Crash      | CRITICAL | PID stale, no heartbeat |
| Context Overflow  | HIGH     | Token limit exceeded    |
| Budget Exhaustion | MEDIUM   | 429 errors              |
| Lock Contention   | MEDIUM   | High lock failures      |
| Security Incident | CRITICAL | Suspicious activity     |

**Escalation:** CRITICAL→5min, HIGH→15min, MEDIUM→1hr, LOW→24hr

## Debugging Aids (P3.6)

### Correlation IDs

All logs/tasks tagged with `CID:{session}-{task}-{agent}-{seq}` for end-to-end tracing.

```bash
# Generate: CID=$(printf "s%s-T%03d-%s-%03d" "$(date +%Y%m%d)" "$TASK_NUM" "$AGENT" "$SEQ")
# Example: CID:s20260120-T042-claude-007
# Search:  grep "CID:s20260120-T042" ~/.claude/logs/*.log | less
```

### Diagnostic Command (`tri-agent doctor`)

```bash
tri-agent doctor                      # Full health check
tri-agent doctor --component gemini   # Single component
tri-agent doctor --fix                # Auto-repair common issues
```

| Check            | Pass Criteria                   | Auto-Fix Action            |
| ---------------- | ------------------------------- | -------------------------- |
| CLI versions     | gemini >= 0.18, codex >= 1.0    | `npm update -g`            |
| Auth credentials | OAuth tokens valid, not expired | Re-auth prompt             |
| DB integrity     | `PRAGMA integrity_check = ok`   | `VACUUM; REINDEX`          |
| Disk space       | >= 2GB free                     | Run cleanup script         |
| Network          | API endpoints reachable         | DNS/proxy diagnostics      |
| Stale processes  | No zombie PIDs                  | Kill stale, remove pidfile |

### Last Failure Snapshot

Auto-persisted to `~/.claude/debug/last-failure.json` on any task failure.

```json
{
  "cid": "s20260120-T042-codex-007",
  "ts": "2026-01-20T14:32:01Z",
  "task": "T-042",
  "agent": "codex",
  "error": "timeout",
  "exit": 124,
  "stderr": "...last 50 lines...",
  "tokens": 285000,
  "retries": 2,
  "git_sha": "abc123",
  "env": { "TRI_AGENT_DEBUG": "1" }
}
```

**Replay:** `tri-agent replay --from ~/.claude/debug/last-failure.json`

### Debug Mode

```bash
TRI_AGENT_DEBUG=1 tri-agent start   # Verbose logging (stderr)
TRI_AGENT_DEBUG=2 tri-agent start   # + API request/response bodies
TRI_AGENT_TRACE=1 tri-agent start   # + Function-level tracing
```

### Common Error Patterns

| Pattern                   | Cause                | Fix                                    |
| ------------------------- | -------------------- | -------------------------------------- |
| `exit 2` (gemini/codex)   | Auth expired/invalid | `gemini-switch` or `codex auth`        |
| `exit 124` timeout        | Task too large       | Split task, `--timeout 600`            |
| `SQLITE_BUSY`             | DB lock contention   | Reduce concurrency, add retry logic    |
| `context_length_exceeded` | Token overflow       | Trigger session refresh, split context |
| `429 Too Many Requests`   | Rate limit           | Backoff 2^n sec, check daily budget    |
| 3+ verification FAILs     | Spec mismatch        | Escalate to user, re-clarify reqs      |

## Metrics Tracking (P3.7)

### Verification Pass Rate

```bash
tri-agent metrics --type verify --range 7d
# Output: Pass: 94.2% | Fail: 4.1% | Inconclusive: 1.7% | Avg attempts: 1.3
```

| Metric             | Target | Alert Threshold |
| ------------------ | ------ | --------------- |
| First-attempt pass | >= 85% | < 75%           |
| Max attempts       | <= 2   | > 3             |
| Inconclusive rate  | < 5%   | > 10%           |

### Approval Latency (Ready-to-Verified)

```bash
tri-agent metrics --type latency --range 24h
# Output: P50: 42s | P90: 2m15s | P99: 7m30s
```

| Percentile | Target   | Alert Threshold |
| ---------- | -------- | --------------- |
| P50        | < 1 min  | > 2 min         |
| P90        | < 5 min  | > 10 min        |
| P99        | < 15 min | > 30 min        |

### Cost per Task by Model

```bash
tri-agent metrics --type cost --range 30d --group-by model
```

| Model         | Avg $/Task | Daily Cap |
| ------------- | ---------- | --------- |
| Claude Opus   | $0.45      | $15       |
| Claude Sonnet | $0.08      | $10       |
| Gemini 3 Pro  | $0.02      | Unlimited |
| Codex GPT-5.2 | $0.12      | $12       |

**Alerts:** 70% daily cap → WARNING, 90% → PAUSE new tasks

### Resource Utilization per Agent

```bash
tri-agent metrics --type utilization --live
# Output: Claude: 78% | Codex: 65% | Gemini: 82% | Avg: 75%
```

| Metric           | Healthy    | Action if Outside |
| ---------------- | ---------- | ----------------- |
| CPU per agent    | 10-80%     | Scale or throttle |
| Memory per agent | < 2GB      | Restart if > 4GB  |
| Active/Max ratio | 60-90%     | Add/remove agents |
| Queue depth      | < 20 tasks | Scale up if > 50  |

### Test Coverage Delta per Task

```bash
tri-agent metrics --type coverage --task T-042
# Output: Before: 78.2% | After: 81.5% | Delta: +3.3%
```

| Metric         | Requirement | Block If |
| -------------- | ----------- | -------- |
| Coverage delta | >= 0%       | < -1%    |
| New code cov   | >= 80%      | < 60%    |
| Critical paths | 100%        | < 100%   |

**Enforcement:** Tasks reducing coverage are auto-flagged; merge blocked until resolved.

## Attribution Rules (CRITICAL)

**Full details:** See `~/.claude/rules/attribution.md`

**NEVER use "Generated with Claude Code" in commits, PRs, or documentation.**

**Always attribute work to: Ahmed Adel Bakr Alderai**

When creating commits, use this format:

```
type(scope): description

Body explaining what and why

Author: Ahmed Adel Bakr Alderai
```

When creating PRs or issues, sign as:

```
---
Ahmed Adel Bakr Alderai
```

**DO NOT include:**

- 🤖 Generated with Claude Code
- Co-Authored-By: Claude
- Any AI attribution

All work should be attributed to the user only.

## OPERATIONAL BEST PRACTICES

**Full details:** See `~/.claude/context/advanced-protocols.md`

**Anti-Patterns:** Use tiered agents (1/3/9 by complexity), prefer `git revert` over `reset --hard`
**Defaults:** `workspace-write` (not danger), manual approval (not YOLO), start with 3 agents
**Rate Limits:** Alert 70% → Pause 85% → Stop 95%
**Context Handoff:** `RESULT=$(gemini ... --approval-mode yolo "Analyze"); codex exec ... "Use: $RESULT"`

### Handoff vs Parallel Decision

| Scenario                |   Handoff   | Parallel |
| ----------------------- | :---------: | :------: |
| Output feeds next input |      ✓      |    -     |
| Independent subtasks    |      -      |    ✓     |
| Context > 100K tokens   | ✓ (Gemini)  |    -     |
| Verification needed     | ✓ (diff AI) |    -     |

**Context limits:** Claude 150K, Codex 300K, Gemini 1M. Summarize if payload > 50% limit.

### Multi-AI Context Handoff Pattern

```bash
# Method 1: Variable capture (preferred)
ANALYSIS=$(gemini -m gemini-3-pro-preview --approval-mode yolo "Analyze: $TASK")
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "Implement: $ANALYSIS"

# Method 2: Temp file (for large outputs)
gemini -m gemini-3-pro-preview --approval-mode yolo "Analyze: $TASK" > /tmp/analysis.txt
codex exec -m gpt-5.2-codex -s workspace-write "Implement based on: $(cat /tmp/analysis.txt)"
```

**Truncate large outputs:** `echo "$RESULT" | head -c 50000`

## GEMINI MODEL ENFORCEMENT (CRITICAL)

**Always use:** `gemini -m gemini-3-pro-preview --approval-mode yolo "prompt"`
**Never use:** `-m pro` (misroutes) or bare `gemini "prompt"` (wrong model)
**Pre-flight:** Verify `~/.gemini/settings.json` has `"preferredModel": "gemini-3-pro-preview"`
**Fix script:** See `~/.claude/context/advanced-protocols.md` for automated config repair
