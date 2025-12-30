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

## Tri-Agent Implementation Workflow (MANDATORY)

### Planning Phase
1. **Build comprehensive todo list FIRST** - Include ALL items from the plan before starting any work
2. **Get user approval** on the todo list before implementation begins
3. **Consult all three AIs** (Claude, Codex, Gemini) during planning to understand requirements better

### Implementation Phase
1. **Use all three AIs** for implementation:
   - Claude: Architecture, complex logic, security analysis
   - Codex: Rapid implementation, code generation
   - Gemini: Large context analysis, code review, documentation

2. **Tri-Agent Verification Required**:
   - NO task is considered complete until verified by another AI
   - After implementing: Ask Gemini or Codex to verify the implementation
   - Verification should check: correctness, security, edge cases, test coverage

3. **Verification Commands**:
   ```bash
   # Verify with Gemini
   gemini -y "Review this implementation for correctness, security issues, and edge cases: [code/file]"

   # Verify with Codex
   codex exec "Review and validate this implementation, check for bugs and security issues: [code/file]"
   ```

### Task Completion Criteria
- Implementation complete
- At least one other AI has verified the code
- Tests pass (if applicable)
- No security vulnerabilities identified

### Example Workflow
```
1. Claude implements fix for SEC-008-4
2. Claude asks Gemini: "Verify this syntax fix is correct and complete"
3. Gemini confirms OR identifies issues
4. If issues found → Claude fixes → Re-verify
5. Only mark todo as complete after verification passes
```

## ENFORCED MULTI-AGENT PARALLELISM (CRITICAL REQUIREMENT)

### Minimum Agent Requirements
**ALWAYS run at least 9 CONCURRENT agents** (3 Claude + 3 Codex + 3 Gemini) at ANY time.
**Total invocations per task: 21 agents across 3 phases.**
**CRITICAL: At least 9 agents (3×3) MUST be running simultaneously throughout ALL work.**

| Activity Type | Min Concurrent | Distribution (3+3+3) |
|--------------|----------------|----------------------|
| **Planning** | 9 | 3 Claude (architecture, security, specs) + 3 Gemini (context, codebase, patterns) + 3 Codex (feasibility, complexity, APIs) |
| **Implementation** | 9 | 3 Claude (core code, tests, docs) + 3 Codex (implement, optimize, validate) + 3 Gemini (review, context, security) |
| **Verification** | 9 | 3 Claude (security, logic, edges) + 3 Gemini (context, patterns, regression) + 3 Codex (completeness, coverage, quality) |
| **Research** | 9 | 3 Gemini (codebase, history, patterns) + 3 Claude (analysis, synthesis, architecture) + 3 Codex (examples, implementations, libraries) |
| **Debugging** | 9 | 3 Claude (root cause, fix, test) + 3 Codex (trace, reproduce, verify) + 3 Gemini (context, similar, patterns) |

**TOTAL PER TASK: 21 agent invocations (7 per phase × 3 phases)**

### How to Launch Parallel Agents

**Option 1: Use Task tool with multiple parallel agents**
```
Launch 5 agents in a SINGLE message with multiple Task tool calls:
- Task 1: Claude Opus - architecture analysis
- Task 2: Claude Sonnet - implementation
- Task 3: Codex - rapid prototyping
- Task 4: Gemini - large context review
- Task 5: Gemini - security analysis
```

**Option 2: Use CLI delegates in parallel**
```bash
# Launch all 5 in parallel using & and wait
gemini -y "Analyze architecture of: [context]" &
gemini -y "Review security of: [context]" &
codex exec "Implement: [task]" &
codex exec "Generate tests for: [task]" &
# Claude runs inline as orchestrator
wait  # Wait for all background jobs
```

**Option 3: Use bin/ scripts for delegation**
```bash
# Launch delegates in parallel
bin/claude-delegate "Design the solution for: [task]" &
bin/codex-delegate "Implement the solution for: [task]" &
bin/gemini-delegate "Review the solution for: [task]" &
wait
```

### Mandatory Consensus Points
These activities REQUIRE all three AIs to agree:

1. **Architecture decisions** → Claude + Codex + Gemini must approve
2. **Security-sensitive changes** → All three must verify
3. **Production deployments** → Tri-agent consensus required
4. **Breaking changes** → All three must acknowledge impact
5. **Configuration changes** → All three must validate

### Verification Matrix
Every implementation MUST be verified by at least 2 other AIs:

| Primary Implementer | Verifier 1 | Verifier 2 |
|--------------------|------------|------------|
| Claude | Gemini | Codex |
| Codex | Claude | Gemini |
| Gemini | Claude | Codex |

### Enforcement Checklist (Before Marking ANY Task Complete)
- [ ] **21 agents** were invoked across 3 phases (7 per phase)
- [ ] **9+ concurrent** agents ran simultaneously at peak
- [ ] All three AI models (Claude, Codex, Gemini) participated in EACH phase
- [ ] Implementation was verified by at least **4 non-implementing AIs** (2 per other model)
- [ ] Security review completed by at least **2 AIs** from different models
- [ ] Performance/optimization review by Codex
- [ ] Context/pattern analysis by Gemini (1M context)
- [ ] Todo was updated throughout the process with phase tracking

### Example: 21-Agent Implementation Flow (MANDATORY)
```
1. PLANNING PHASE (7 concurrent agents):
   - Claude Opus 1: Analyze requirements, design architecture
   - Claude Opus 2: Security threat modeling, attack surface analysis
   - Claude Sonnet: Write technical specifications
   - Gemini 1: Review existing codebase (1M context)
   - Gemini 2: Analyze code patterns and dependencies
   - Codex 1: Assess implementation complexity
   - Codex 2: Identify reusable components and APIs

2. IMPLEMENTATION PHASE (7 concurrent agents):
   - Claude 1: Write core implementation
   - Claude 2: Write comprehensive tests
   - Claude 3: Generate inline documentation
   - Codex 1: Implement supporting modules
   - Codex 2: Optimize performance-critical paths
   - Gemini 1: Real-time code review
   - Gemini 2: Validate against specifications

3. VERIFICATION PHASE (7 concurrent agents):
   - Claude 1: Security vulnerability scan
   - Claude 2: Logic correctness verification
   - Claude 3: Edge case and boundary testing
   - Gemini 1: Context-aware pattern validation
   - Gemini 2: Regression impact analysis
   - Codex 1: Implementation completeness check
   - Codex 2: Test coverage verification

TOTAL: 21 agent invocations across 3 phases
MINIMUM: 9 concurrent agents at ANY time (3 Claude + 3 Codex + 3 Gemini)
```

### Phase Execution Commands
```bash
# Phase 1: Planning (7 agents)
gemini -y "Analyze codebase context for: [task]" &
gemini -y "Identify patterns and dependencies for: [task]" &
codex exec "Assess implementation complexity for: [task]" &
codex exec "Find reusable components for: [task]" &
# + 3 Claude agents via Task tool (architecture, security, specs)
wait

# Phase 2: Implementation (7 agents)
codex exec "Implement core module: [task]" &
codex exec "Optimize critical paths: [task]" &
gemini -y "Review implementation: [code]" &
gemini -y "Validate against specs: [code]" &
# + 3 Claude agents via Task tool (code, tests, docs)
wait

# Phase 3: Verification (7 agents)
gemini -y "Check patterns: [implementation]" &
gemini -y "Analyze regression impact: [implementation]" &
codex exec "Verify completeness: [implementation]" &
codex exec "Check test coverage: [implementation]" &
# + 3 Claude agents via Task tool (security, logic, edge cases)
wait
```

### Commands to Invoke Multi-Agent Parallelism
```bash
# Tri-agent consensus (all 3 models)
/consensus "Review and approve: [task]"

# Route to optimal model with verification
/route "Implement with tri-agent verification: [task]"

# Force all models to participate
tri-agent-route --consensus "Critical: [task]"
```

## MAXIMUM CAPABILITY USAGE (MANDATORY)

### Gemini Maximum Capability Configuration
```bash
# Gemini 3 Pro with full capabilities
gemini -m gemini-3-pro-preview -y --approval-mode yolo "prompt"

# Or use settings.json (~/.gemini/settings.json):
{
  "previewFeatures": true,
  "general": {
    "preferredModel": "gemini-3-pro-preview"
  },
  "thinking": {
    "level": "high"  # Maximum reasoning
  },
  "routing": {
    "preferPro": true  # Always use most capable model
  }
}
```

**Gemini Maximum Capabilities:**
- **1M token context**: Use for full codebase analysis, multi-file review
- **Pro routing**: Always routes to Gemini 3 Pro for complex tasks
- **High thinking**: Extended reasoning for architectural decisions
- **Tool use**: File editing, code execution, web search

### Codex Maximum Capability Configuration
```bash
# Codex with GPT-5.2-Codex and xhigh reasoning
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s danger-full-access "task"

# Or use config.toml (~/.codex/config.toml):
model = "gpt-5.2-codex"
model_reasoning_effort = "xhigh"  # Maximum reasoning depth
model_context_window = 400000    # Full context
model_max_output_tokens = 128000 # Maximum output
approval_policy = "never"        # Auto-approve for speed
sandbox_mode = "danger-full-access"  # Full system access
```

**Codex Maximum Capabilities:**
- **xhigh reasoning**: Maximum reasoning depth for complex problems
- **400K context**: Large codebase understanding
- **Full access**: Can modify files, run commands, access system
- **GPT-5.2-Codex**: Most advanced coding model

### Claude Maximum Capability Configuration
```bash
# Claude with ultrathink (32K reasoning tokens)
# In Claude Code, use: ultrathink before complex tasks

# Or use Task tool with model="opus" for maximum capability
```

**Claude Maximum Capabilities:**
- **ultrathink (32K)**: Maximum reasoning for architecture, security
- **Opus model**: Deepest analysis and most thorough responses
- **Tool orchestration**: Coordinates other AIs and agents

## TRI-AI ACTIVE TODO MANAGEMENT (CRITICAL)

### All Three AIs MUST Update Todo
Every AI (Claude, Codex, Gemini) is responsible for:

1. **Adding new requirements discovered during work**
2. **Updating task status in real-time**
3. **Breaking down complex tasks into subtasks**
4. **Flagging blockers and dependencies**
5. **Recording verification results**

### How Each AI Updates Todo

**Claude (Primary Orchestrator):**
```
- Uses TodoWrite tool directly
- Coordinates todo updates from other AIs
- Synthesizes requirements from all sources
```

**Codex (via Claude orchestration):**
```bash
# Codex reports findings that Claude adds to todo:
codex exec "Analyze task and report: 1) New requirements found, 2) Subtasks needed, 3) Dependencies, 4) Blockers. Format as JSON for todo update."

# Claude then parses output and updates todo
```

**Gemini (via Claude orchestration):**
```bash
# Gemini provides comprehensive analysis for todo:
gemini -y "Analyze task context and report: 1) Additional requirements from codebase, 2) Hidden dependencies, 3) Security considerations, 4) Test requirements. Format as structured list."

# Claude then parses output and updates todo
```

### Todo Synchronization Protocol
```
1. Before ANY task: Claude creates initial todo items
2. During task:
   - Codex reports implementation findings → Claude updates todo
   - Gemini reports context findings → Claude updates todo
   - Claude updates own findings in real-time
3. After task: All three AIs verify todo reflects actual state
4. On plan changes: ALL requirements from ANY AI are captured
```

### Requirement Sources to Track
- **User requirements**: Direct user input
- **Claude requirements**: Architecture, security, integration needs
- **Codex requirements**: Implementation complexity, technical debt
- **Gemini requirements**: Codebase patterns, documentation needs
- **Plan file requirements**: All items from plan mode

### Active Todo Enforcement
```
BEFORE marking ANY task complete, verify:
- [ ] All user requirements addressed
- [ ] All Claude-identified requirements addressed
- [ ] All Codex-identified requirements addressed
- [ ] All Gemini-identified requirements addressed
- [ ] Plan file synced with todo
- [ ] No orphaned requirements
```

### Cross-AI Communication for Todo
```bash
# Standard communication pattern:
1. Claude: "Gemini, analyze [context] and report requirements"
2. Gemini: Returns structured requirements
3. Claude: Adds to todo with source="Gemini"
4. Claude: "Codex, implement [task] and report new requirements"
5. Codex: Returns implementation + discovered requirements
6. Claude: Updates todo with source="Codex"
7. Claude: Syncs todo with plan file
```

## TODO-FIRST WORKFLOW (MANDATORY)

### Critical Requirements
1. **Build COMPLETE todo from plan FIRST** - Do NOT start any work until todo has EVERYTHING from the plan
2. **Use ALL THREE AIs** (Claude, Codex, Gemini) to implement every todo item
3. **NO todo is done until ANOTHER AI verifies it** - Always ask Gemini AND Codex to verify
4. **Ask Gemini and Codex to explain requirements** - Before building todo, consult them
5. **Get USER APPROVAL on todo** - Before starting any implementation work
6. **NO API USAGE** - We use CLI subscriptions only (gemini CLI, codex CLI, claude CLI)

### Pre-Implementation Protocol
```bash
# STEP 1: Ask Gemini to analyze requirements
gemini -y "Analyze the plan and explain: 1) What needs to be built, 2) Hidden requirements, 3) Dependencies, 4) Risks. Be thorough."

# STEP 2: Ask Codex to analyze implementation
codex exec "Analyze the plan and explain: 1) Implementation approach, 2) Technical requirements, 3) Edge cases, 4) Test requirements."

# STEP 3: Build comprehensive todo from:
# - Plan file items
# - Gemini analysis
# - Codex analysis
# - Claude analysis

# STEP 4: Present todo to user for approval
# DO NOT START WORK UNTIL USER APPROVES

# STEP 5: For EACH todo item:
# - Implement with appropriate AI
# - Verify with at least 2 other AIs
# - Only mark complete after verification passes
```

### Verification Protocol (EVERY TODO)
```bash
# After implementing any todo item:

# Verify with Gemini
gemini -y "Verify this implementation is correct, secure, handles edge cases: [code/change]"

# Verify with Codex
codex exec "Validate this implementation, check for bugs, security issues, completeness: [code/change]"

# Only mark todo complete if BOTH verifications pass
```

### CLI-Only Rule (NO API)
- **gemini CLI**: Use `gemini -y "prompt"` (subscription-based)
- **codex CLI**: Use `codex exec "prompt"` (subscription-based)
- **claude CLI**: Use Task tool or direct Claude Code (subscription-based)
- **NEVER use**: curl to API endpoints, direct API keys, REST calls

## P5.3 CONFIG HARDENING (SECURITY RECOMMENDATIONS)

### Gemini CLI Security (~/.gemini/settings.json)
```json
{
  "tools": {
    "sandbox": true,  // P5.3a: Enable sandboxing for security
    "deniedPaths": [  // P5.3b: Block access to sensitive credential dirs
      "/home/$USER/.ssh",
      "/home/$USER/.gnupg",
      "/home/$USER/.aws",
      "/home/$USER/.codex",
      "/home/$USER/.kube",
      "/home/$USER/.docker",
      "/home/$USER/.config/gcloud"
    ]
  }
}
```

### Codex CLI Retry Config (~/.codex/config.toml)
```toml
# P5.3c: Retry configuration for resilience
[provider]
request_max_retries = 3
stream_max_retries = 2
retry_delay_base_ms = 1000
retry_delay_max_ms = 30000
```

### Application Checklist
- [ ] Set `sandbox: true` in Gemini settings
- [ ] Add `deniedPaths` for credential directories
- [ ] Add retry config to Codex for resilience
- [ ] Verify with: `gemini -y "echo sandbox test"` (should work with sandbox)

## CAPABILITY ESCALATION MATRIX

| Task Type | Claude Mode | Codex Mode | Gemini Mode |
|-----------|-------------|------------|-------------|
| Simple fix | think (4K) | medium | Flash |
| Feature | think hard (10K) | high | Pro |
| Architecture | ultrathink (32K) | xhigh | Pro + high thinking |
| Security audit | ultrathink (32K) | xhigh | Pro + high thinking |
| Full codebase | think hard (10K) | high | Pro (1M context) |
| Debugging | ultrathink (32K) | xhigh | Pro |
| Documentation | think (4K) | medium | Pro (long-form) |
