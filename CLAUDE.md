# Global SDLC Orchestration System

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

## ENFORCED MULTI-AGENT PARALLELISM (CRITICAL REQUIREMENT)

### Minimum Agent Requirements

**Standard:** 9 concurrent agents (3 Claude + 3 Codex + 3 Gemini), 27 total per task.
**Tiered by complexity:** 1 (trivial) → 3 (standard) → 9 (complex tasks).
**Exception:** Degraded mode allows minimum 3 agents (see Graceful Degradation).

| Activity Type      | Min Concurrent | Distribution (3+3+3)                                                                                                        |
| ------------------ | -------------- | --------------------------------------------------------------------------------------------------------------------------- |
| **Planning**       | 9              | 3 Claude (architecture, security, specs) + 3 Gemini (context, codebase, patterns) + 3 Codex (feasibility, complexity, APIs) |
| **Implementation** | 9              | 3 Claude (core code, tests, docs) + 3 Codex (implement, optimize, validate) + 3 Gemini (review, context, security)          |
| **Verification**   | 9              | 3 Claude (security, logic, edges) + 3 Gemini (context, patterns, regression) + 3 Codex (completeness, coverage, quality)    |

**TOTAL PER TASK: 27 agent invocations (9 per phase × 3 phases)**

### Enforcement Checklist (Before Marking ANY Task Complete)

- [ ] **27 agents** were invoked across 3 phases (9 per phase)
- [ ] **9+ concurrent** agents ran simultaneously at peak
- [ ] All three AI models (Claude, Codex, Gemini) participated in EACH phase
- [ ] Implementation was verified by at least **2 non-implementing AIs**
- [ ] Security review completed by at least **2 AIs** from different models
- [ ] Todo was updated throughout the process with phase tracking

## MAXIMUM CAPABILITY STANDARDS (MANDATORY)

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

**Verification Marks:** `[ ]` pending | `[x]` passed | `[!]` failed

**Runtime:** Every AI MUST continuously add discovered requirements, update status in real-time, flag blockers, record verification results.

## VERIFICATION PROTOCOL (TWO-KEY RULE) — Enhanced

**Purpose:** Any change must be independently verified by a second agent before acceptance.

**Verification request format (required):**

```
VERIFY:
- Scope: <files/paths>
- Change summary: <1–3 sentences>
- Expected behavior: <concrete outcomes>
- Repro steps: <commands or manual steps>
- Evidence to check: <logs/screenshots/tests>
- Risk notes: <edge cases>
```

**PASS/FAIL/INCONCLUSIVE criteria:**

- **PASS** if _all_ expected behaviors match, tests/steps reproduce cleanly, and no regressions.
- **FAIL** if any expected behavior is missing, tests/steps fail, or regressions/new risks appear.
- **INCONCLUSIVE** if evidence is insufficient to determine outcome → escalate to third AI or user.

**Re-verification rules:**

- Any change after a FAIL requires a **fresh** verification request.
- The verifier must re-run the **full** scope (no partial "spot checks").

**FAIL Example:**

```
VERIFICATION RESULT: FAIL
Issues Found:
1. CRITICAL - Token expiration not enforced (line 47)
2. HIGH - Token not invalidated after use (line 89)
Required: Fix both issues, re-run tests, submit fresh VERIFY
Verifier: Codex (GPT-5.2)
```

## STALEMATE RESOLUTION PROTOCOL

**Trigger:** Implementer and verifier disagree after a verification cycle.

- **Max retries:** 2 total verification cycles after initial disagreement.
- **Deadlock detection:** If the same dispute recurs **twice**, declare a deadlock.
- **Tie‑breaker escalation:** Escalate to the user with:
  - the disputed claim,
  - evidence from both sides,
  - a clear ask: "Which outcome should we prioritize?"
- **Alternative path:** Request consensus from a **third AI** and follow majority decision.
- **Documentation:** Record the deadlock and resolution path in the change log.

## ROLLBACK & RECOVERY PROCEDURES

**When to rollback:**

- Verification fails **3 times** on the same change.
- A **critical error** is introduced (data loss, security regression, prod outage risk).
- The change is no longer aligned with user intent.

**How to rollback:**

- **Git revert** (preferred): `git revert <bad-commit>` (reversible, preserves history)
- **Checkpoint restore**: Restore to last known-good checkpoint.

**Post‑rollback verification:**

- Re-run the **original** verification steps against the rolled-back state.
- Log the rollback reason and verification outcome.

**Preventing rollback loops:**

- Require a **new plan** before re-attempting the same change.
- If rollback happens twice, **escalate to user** for direction.

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

Before starting work, verify:

```bash
node -v && python --version && git --version  # Tools present
git status                                     # Clean git state
sqlite3 state/tri-agent.db "PRAGMA integrity_check;"  # DB OK
test -f ~/.gemini/oauth_creds.json && echo "Gemini OK"  # Creds exist
```

## 24-HOUR CONTINUOUS OPERATION (CRITICAL)

### Session Persistence Architecture

**Progress File:** Update `claude-progress.txt` each session with: date, session ID, `git log --oneline -20`, current branch, uncommitted count, last checkpoint, and next TODOs.

**State Persistence Locations:**
| State Type | Location | Backup Frequency |
|------------|----------|------------------|
| Task Queue | `state/tri-agent.db` (SQLite) | Real-time WAL |
| Progress Log | `claude-progress.txt` | Every commit |
| Checkpoints | `sessions/checkpoints/` | Every 5 minutes |
| Event Log | `state/event-store/events.jsonl` | Append-only |

### Context Window Management (CRITICAL FOR 24HR)

**Token Budget Per Session:**
| Model | Context Window | Safe Working Limit | Refresh Trigger |
|-------|---------------|-------------------|-----------------|
| Claude Opus/Sonnet | 200K | 160K (80%) | 150K tokens used |
| Gemini 3 Pro | 1M | 800K (80%) | 750K tokens used |
| Codex GPT-5.2 | 400K | 320K (80%) | 300K tokens used |

**Context Overflow:** At 80% threshold (Claude 150K, Gemini 750K, Codex 300K): checkpoint → summarize via Gemini → refresh.
**Failover:** Claude (200K) → Gemini (1M) → split sub-tasks.

### Session Refresh Protocol (Every 8 Hours)

```bash
SESSION_DURATION_HOURS=8
SESSION_REFRESH_ENABLED=true
CONTEXT_CHECKPOINT_INTERVAL=300  # 5 minutes

# At session boundary:
# 1. Checkpoint all in-progress work
# 2. Commit with descriptive message
# 3. Update claude-progress.txt
# 4. Generate session summary via Gemini
# 5. Clear context and reload essentials
# 6. Resume from checkpoint
```

### Watchdog & Auto-Recovery Stack

**3-Layer Supervision:**

```
Layer 1: tri-agent-daemon (Parent)
  ├─ tri-agent-worker (Task executor)
  ├─ tri-agent-supervisor (Approval flow)
  └─ budget-watchdog (Cost tracking)

Layer 2: watchdog-master (External supervisor)
  ├─ Monitors Layer 1 health
  ├─ Restarts failed daemons
  └─ Exponential backoff (2^n seconds)

Layer 3: tri-24-monitor (24-hour guardian)
  ├─ Heartbeat every 30 seconds
  ├─ System health checks
  └─ Alerting on failures
```

**Recovery Hierarchy:**
| Failure Type | Detection | Recovery Action |
|--------------|-----------|-----------------|
| Task Timeout | Heartbeat > threshold | Requeue task, increment retry |
| Worker Crash | PID check fails | Mark dead, recover tasks |
| Daemon Crash | watchdog-master | Auto-restart with backoff |
| Context Overflow | Token tracking | Session refresh |
| Rate Limit | 429 response | Exponential backoff |
| Budget Exhausted | cost-tracker | Pause until reset |

### 24-Hour Budget Management

**Daily Token Budgets:**
| Model | Daily Limit | Hourly Average | Alert Threshold |
|-------|-------------|----------------|-----------------|
| Claude Max | ~100M tokens | 4.2M/hour | 70% daily |
| Gemini Pro | Unlimited\* | N/A | API rate limits |
| Codex | ~50M tokens | 2.1M/hour | 70% daily |

**Budget Reset Schedule:**

- Claude: Rolling 5-hour window + 7-day weekly cap
- Gemini: Daily reset at midnight UTC
- Codex: Daily reset at midnight UTC

### 24-Hour Operation Checklist

**Before Starting:**

- [ ] Verify watchdog-master is running
- [ ] Check daily budget availability
- [ ] Initialize claude-progress.txt
- [ ] Create initial git checkpoint
- [ ] Configure 8-hour session refresh

**During Operation (Automated):**

- [ ] Heartbeat every 30 seconds
- [ ] Context checkpoint every 5 minutes
- [ ] Progress update every commit
- [ ] Budget check every 100K tokens
- [ ] Session refresh at 8-hour boundaries

**Recovery Triggers:**

- [ ] Task timeout → Requeue
- [ ] Worker crash → Auto-restart
- [ ] Context overflow → Session refresh
- [ ] Budget exhaustion → Pause & alert

### Commands for 24-Hour Operation

```bash
# Start 24-hour session
tri-agent start --mode=24hr --watchdog --monitor

# Check session health
tri-agent health --verbose

# Force checkpoint
tri-agent checkpoint --reason="manual"

# Resume from crash
tri-agent resume --from-checkpoint latest

# View progress
cat claude-progress.txt

# Check budget
cost-tracker --status --daily

# Session refresh
tri-agent session-refresh --summarize
```

### Resource & Log Governance (24HR MANDATORY)

**Log Rotation Policy:**

- **Max Log Size:** 50MB per file
- **Retention:** 7 days (rolling window)
- **Rotation Check:** Every session refresh (8 hours)
- **Command:** `find logs/ -name "*.log" -size +50M -exec gzip {} \;`

**Hardware Safety Limits:**

- **Max Concurrent CLI Processes:** 15 (prevent fork bombs)
- **Max RAM Usage:** 75% of System Total (pause new agents if exceeded)
- **Disk Free Space Floor:** 2GB (emergency stop if crossed)

**Emergency Dead Man's Switch:**

- **Mechanism:** `tri-24-monitor` must touch `~/.claude/heartbeat` every 30s
- **Systemd/Cron Action:** If file age > 5m, kill all `tri-agent` processes and restart `watchdog-master`

### Large Repository Protocol (8GB+ Support)

**Context Strategy: Sparse Loading**

- **Problem:** 1M tokens ≈ 4MB text. 8GB repo is 2000x larger
- **Solution:** NEVER load "entire codebase". Use hierarchical narrowing:
  1. **Map:** `tree -L 2` or `find . -maxdepth 2` for structure
  2. **Search:** Use `ripgrep` (rg) to find specific symbols
  3. **Read:** Only read files confirmed relevant by search

**Smart Ignore (Performance):**

```bash
# .geminiignore / .claudeignore
package-lock.json
yarn.lock
*.log
.cache/
tmp/
dist/
build/
node_modules/
*.so
*.dll
*.png
*.mp4
```

**Incremental Verification (8GB+ repos):**

- **Unit:** `jest -o` / `pytest --lf` (last-failed only)
- **Build:** `tsc --incremental`
- **Lint:** `eslint --cache`

### Security Hardening (Production)

**Risk Mitigation:**
| Risk | Mitigation |
|------|------------|
| `danger-full-access` | Run Codex in Docker container |
| YOLO mode | Audit log all auto-approved actions |
| Credential exposure | Secret scanning on `claude-progress.txt` |
| Budget drain | Hard stop at 95% daily budget |

**Atomic State Writes:**

```bash
# Use write-to-temp-and-rename pattern
write_state() {
    local target="$1" content="$2"
    local tmp="${target}.tmp.$$"
    echo "$content" > "$tmp"
    mv "$tmp" "$target"  # Atomic on same filesystem
}
```

**Fallback Summarization:**

- If Gemini fails during session refresh, dump raw context to timestamped file
- Alert and preserve data for manual recovery

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
# CANONICAL COMMAND (always use this for tasks):
gemini -m gemini-3-pro-preview --approval-mode yolo "prompt"

# Session management
gemini -r latest                      # Resume most recent session
gemini --list-sessions                # List available sessions

# Read-only analysis (YOLO allowed)
gemini -m gemini-3-pro-preview --approval-mode yolo "Analyze: ..."

# For modifications (use manual approval)
gemini -m gemini-3-pro-preview "Implement: ..."
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

### Gemini 3 Pro Setup & Usage

**Requirements**:

- Gemini CLI v0.18.x+ (`npm install -g @google/gemini-cli@latest`)
- Google AI Pro/Ultra subscription OR paid Gemini API key
- Preview Features enabled

**Enable Gemini 3 Pro**:

1. Run `gemini` interactively
2. Type `/settings` → Enable "Preview Features"
3. Type `/model` → Select "Pro routing" for Gemini 3 Pro priority
4. Model shows as "Pro (gemini-3-pro, gemini-2.5-pro)"

**Model Routing**:

- **Auto routing** (default): Simple → 2.5 Flash, Complex → 3 Pro or 2.5 Pro
- **Pro routing**: Always uses most capable model (Gemini 3 Pro when enabled)

**Usage Limits**:

- Daily limits apply; CLI notifies when reached
- Options: Switch to 2.5 Pro, upgrade, or wait for reset
- Quota resets shown in error message (e.g., "resets after 4h")

**Best Use Cases for Gemini 3 Pro**:

- Full codebase analysis (1M token context)
- Complex multi-step reasoning
- Multimodal tasks (images, PDFs, code repos)
- Agentic coding with project scaffolding
- Documentation generation from code

### Gemini Native Sessions (Multi-turn Conversations)

The CLI natively supports conversation history - no manual context management needed:

```bash
# Start a new conversation
gemini -m gemini-3-pro-preview "Analyze the database schema"

# Follow up (resumes latest session)
gemini -m gemini-3-pro-preview -r latest "Generate migration scripts"

# List/manage sessions
gemini --list-sessions
gemini --delete-session 3
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
# CANONICAL COMMAND (workspace-write default):
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "task"

# With o3 for complex reasoning:
codex exec -m o3 -c 'model_reasoning_effort="xhigh"' "complex reasoning task"

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

| Data Type    | Retention Period | Cleanup Frequency | Location                          |
| ------------ | ---------------- | ----------------- | --------------------------------- |
| Audit Logs   | 30 days          | Daily             | `~/.claude/logs/audit/`           |
| Session Logs | 7 days           | Daily             | `~/.claude/logs/sessions.log`     |
| Checkpoints  | 3 days           | Every 8 hours     | `~/.claude/sessions/checkpoints/` |
| Snapshots    | 7 days           | Daily             | `~/.claude/sessions/snapshots/`   |
| Task Files   | 14 days          | Daily             | `~/.claude/tasks/`                |
| Metrics      | 90 days          | Weekly            | `~/.claude/metrics/`              |
| Backups      | 30 days          | Daily             | `~/.claude/backups/`              |

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

# Delete old audit logs
find "$LOG_DIR/audit" -name "*.jsonl" -mtime +30 -delete
find "$LOG_DIR/audit" -name "*.jsonl.gz" -mtime +90 -delete

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

## Attribution Rules (CRITICAL)

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
**Context Handoff:** `RESULT=$(gemini -m gemini-3-pro-preview --approval-mode yolo "..."); codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "Use: $RESULT"`

## GEMINI MODEL ENFORCEMENT (CRITICAL)

**Always use:** `gemini -m gemini-3-pro-preview --approval-mode yolo "prompt"`
**Never use:** `-m pro` (misroutes) or bare `gemini "prompt"` (wrong model)
**Pre-flight:** Verify `~/.gemini/settings.json` has `"preferredModel": "gemini-3-pro-preview"`
**Fix script:** See `~/.claude/context/advanced-protocols.md` for automated config repair
