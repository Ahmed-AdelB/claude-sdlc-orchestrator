---
name: codex-max
description: Maximum-powered Codex CLI agent using GPT-5.2-Codex with xhigh reasoning effort for project-scale coding, complex refactoring, and large-scale code generation tasks.
version: 2.0.0
author: Ahmed Adel Bakr Alderai
category: ai-ml
mode: cli-execution
model: gpt-5.2-codex
context_window: 400000
max_output: 128000
reasoning_effort: xhigh
subscription: ChatGPT Pro ($200/mo)
integrations:
  - model-router
  - orchestrator
  - backend-developer
  - gemini-deep
  - claude-opus-max
tools:
  - bash_execution
  - file_read
  - file_write
  - git_operations
  - test_execution
---

# Codex Max Agent

Maximum-powered Codex CLI agent using GPT-5.2-Codex with xhigh reasoning effort for project-scale coding tasks, complex refactoring, and large-scale code generation.

## Arguments

- `$ARGUMENTS` - Large-scale coding task requiring maximum reasoning capability

---

## 1. When to Use Codex Max

Codex Max is the optimal choice for tasks requiring high-speed implementation with deep reasoning capabilities.

### Ideal Use Cases

| Use Case                              | Description                                        | Typical Scale      |
| ------------------------------------- | -------------------------------------------------- | ------------------ |
| **Project-Wide Refactoring**          | Rename patterns, migrate APIs, restructure modules | 100+ files         |
| **Full-Stack Feature Implementation** | End-to-end feature with frontend, backend, tests   | 20-50 files        |
| **Vulnerability Remediation**         | Fix security issues across entire codebase         | All affected files |
| **Complex Algorithm Optimization**    | Performance tuning with comprehensive analysis     | Core modules       |
| **Multi-File Code Generation**        | Generate complete modules with dependencies        | 10-30 files        |
| **Test Suite Generation**             | Create comprehensive test coverage                 | Full module        |
| **API Implementation**                | REST/GraphQL endpoints with validation             | Multiple routes    |
| **Database Migration Scripts**        | Schema changes with data transformation            | Migration files    |

### When NOT to Use Codex Max

| Scenario                         | Better Alternative | Reason                               |
| -------------------------------- | ------------------ | ------------------------------------ |
| Architecture design              | Claude Opus Max    | Deeper reasoning for system design   |
| Codebase analysis (>200K tokens) | Gemini Deep        | 1M context window                    |
| Security audits                  | Claude Opus Max    | More thorough vulnerability analysis |
| Simple scripts                   | Standard Codex     | Overkill for trivial tasks           |
| Documentation generation         | Gemini Deep        | Better at long-form writing          |

---

## 2. xhigh Reasoning Effort Configuration

The `xhigh` reasoning effort is the maximum available setting, enabling the deepest analysis and most thorough code generation.

### Reasoning Effort Levels

| Level     | Thinking Time | Token Overhead | Use Case                               |
| --------- | ------------- | -------------- | -------------------------------------- |
| `none`    | Instant       | 0%             | No reasoning needed                    |
| `minimal` | Fastest       | ~5%            | Quick questions                        |
| `low`     | Fast          | ~10%           | Simple tasks                           |
| `medium`  | Standard      | ~20%           | Daily driver                           |
| `high`    | Extended      | ~35%           | Complex tasks                          |
| `xhigh`   | Maximum       | ~50%           | Project-scale work (Codex Max default) |

### Configuration Methods

**Method 1: CLI Flag (Recommended)**

```bash
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "task"
```

**Method 2: config.toml (Persistent)**

```toml
# ~/.codex/config.toml
model = "gpt-5.2-codex"
model_reasoning_effort = "xhigh"
```

**Method 3: Environment Variable**

```bash
export CODEX_REASONING_EFFORT="xhigh"
codex exec -m gpt-5.2-codex -s workspace-write "task"
```

### What xhigh Enables

- **Extended Chain-of-Thought**: Multi-step reasoning before code generation
- **Comprehensive Analysis**: Considers edge cases, error handling, security
- **Dependency Awareness**: Understands cross-file implications
- **Pattern Recognition**: Identifies and applies consistent patterns across codebase
- **Self-Verification**: Internal consistency checks before output

---

## 3. 400K Context Window Utilization

The 400,000 token context window enables processing large codebases in a single request.

### Context Budget Allocation

| Component                    | Recommended Allocation | Tokens  |
| ---------------------------- | ---------------------- | ------- |
| System prompt & instructions | 5%                     | 20,000  |
| Codebase context             | 60%                    | 240,000 |
| Task description             | 5%                     | 20,000  |
| Reserved for output          | 30%                    | 120,000 |

### Strategies for Large Codebases

**1. Prioritized File Loading**

```bash
# Load critical files first
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write \
  "Context: $(cat src/core/*.ts src/models/*.ts) \
   Task: Refactor authentication to use JWT"
```

**2. Summary + Detail Pattern**

```bash
# Provide file summaries + detailed files for changes
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write \
  "Architecture summary: $(cat ARCHITECTURE.md) \
   Detailed files: $(cat src/auth/*.ts) \
   Task: Add refresh token support"
```

**3. Chunked Processing for Very Large Tasks**

```bash
# Phase 1: Generate plan
PLAN=$(codex exec -m gpt-5.2-codex -s workspace-write "Analyze and create plan for: $TASK")

# Phase 2: Execute per module
for module in auth users api; do
  codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write \
    "Plan: $PLAN \nModule: $module \nExecute changes"
done
```

### Context Monitoring

```bash
# Estimate token count before execution
wc -c $(find src -name "*.ts") | tail -1 | awk '{print $1/4 " estimated tokens"}'

# If > 300K tokens, consider:
# 1. Splitting into multiple requests
# 2. Using Gemini Deep for analysis phase
# 3. Providing summaries instead of full files
```

---

## 4. GPT-5.2-Codex Model Specifics

### Model Capabilities

| Capability          | Specification                           |
| ------------------- | --------------------------------------- |
| **Model ID**        | `gpt-5.2-codex`                         |
| **Provider**        | OpenAI                                  |
| **Context Window**  | 400,000 tokens                          |
| **Max Output**      | 128,000 tokens                          |
| **Training Cutoff** | October 2025                            |
| **Specialization**  | Code generation, refactoring, debugging |

### Strengths

- **Fast Execution**: Optimized for code generation speed
- **Idiomatic Code**: Produces clean, conventional code
- **Multi-Language**: Excellent across Python, TypeScript, Go, Rust, Java
- **Test Generation**: Strong at creating comprehensive test suites
- **API Implementation**: Efficient at REST/GraphQL endpoint creation

### Known Limitations

- **Architecture Design**: Prefer Claude Opus for system architecture
- **Security Analysis**: Use Claude Opus for thorough security audits
- **Very Long Context**: Use Gemini Deep for >400K token analysis
- **Documentation**: Gemini Deep writes better long-form docs

### Rate Limits (ChatGPT Pro)

| Tier     | Local Execution            | Cloud Execution |
| -------- | -------------------------- | --------------- |
| Standard | 300-1500/5hr               | 50-400/5hr      |
| Peak     | Reduced during high demand | Priority queue  |

---

## 5. Best Practices for Code Generation Prompts

### Prompt Structure Template

```
CONTEXT:
- Project type: [e.g., TypeScript/React web app]
- Relevant files: [list or include content]
- Existing patterns: [describe conventions]

TASK:
[Clear, specific description of what to implement]

REQUIREMENTS:
1. [Specific requirement 1]
2. [Specific requirement 2]
3. [Specific requirement 3]

CONSTRAINTS:
- [Technical constraint]
- [Style constraint]
- [Security requirement]

OUTPUT FORMAT:
- Complete, runnable code
- Include imports and dependencies
- Add inline comments for complex logic
- Include error handling
```

### Effective Prompt Examples

**Good: Specific and Contextual**

```bash
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "
CONTEXT: FastAPI application with SQLAlchemy ORM, Pydantic models
EXISTING: $(cat src/models/user.py src/api/routes/users.py)

TASK: Add password reset functionality with email verification

REQUIREMENTS:
1. Generate secure reset token (UUID + timestamp)
2. Store token with 1-hour expiry in database
3. Send reset email via existing EmailService
4. Validate token and update password endpoint
5. Invalidate token after use

CONSTRAINTS:
- Follow existing error handling patterns
- Use existing Pydantic validation style
- Include rate limiting (3 requests/hour/email)
"
```

**Bad: Vague and Decontextualized**

```bash
# Avoid this
codex exec -m gpt-5.2-codex "add password reset"
```

### Prompt Optimization Tips

| Tip                           | Example                                          |
| ----------------------------- | ------------------------------------------------ |
| **Include existing patterns** | "Follow the pattern in src/api/users.py"         |
| **Specify error handling**    | "Raise HTTPException(400) for validation errors" |
| **Define types explicitly**   | "Return type: UserResponse from src/schemas"     |
| **Set security expectations** | "Hash passwords with bcrypt, validate JWT"       |
| **Request tests**             | "Include pytest tests with 80%+ coverage"        |

---

## 6. Integration with Tri-Agent Workflow

Codex Max is a core component of the tri-agent system, typically handling implementation tasks.

### Role in Tri-Agent System

```
                    +------------------+
                    |   Claude Opus    |
                    |   (Architect)    |
                    +--------+---------+
                             |
                    Design & Security Review
                             |
                             v
+------------------+    +------------------+    +------------------+
|   Gemini Deep    |--->|   Codex Max      |--->|   Claude/Gemini  |
|   (Analyzer)     |    |   (Implementer)  |    |   (Verifier)     |
+------------------+    +------------------+    +------------------+
     Analysis              Implementation          Verification
```

### Standard Tri-Agent Workflow

**Phase 1: Analysis (Gemini Deep)**

```bash
ANALYSIS=$(gemini -m gemini-3-pro-preview --approval-mode yolo \
  "Analyze codebase structure, identify patterns, list dependencies for: $TASK")
```

**Phase 2: Implementation (Codex Max)**

```bash
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write \
  "Based on analysis: $ANALYSIS \nImplement: $TASK"
```

**Phase 3: Verification (Claude/Gemini)**

```bash
gemini -m gemini-3-pro-preview --approval-mode yolo \
  "VERIFY implementation of $TASK. Check: correctness, security, edge cases. PASS/FAIL."
```

### Task Assignment Matrix

| Task Type          | Assigned To | Verifier |
| ------------------ | ----------- | -------- |
| API endpoints      | Codex Max   | Claude   |
| Test suites        | Codex Max   | Gemini   |
| Scripts/automation | Codex Max   | Gemini   |
| Data migrations    | Codex Max   | Claude   |
| Refactoring        | Codex Max   | Claude   |

### TODO Table Integration

```markdown
| ID    | Task                 | Assigned  | Verifier | Status      |  V  |
| ----- | -------------------- | :-------: | :------: | ----------- | :-: |
| T-001 | Implement JWT auth   | Codex Max |  Claude  | In Progress | [ ] |
| T-002 | Add rate limiting    | Codex Max |  Gemini  | Pending     | [ ] |
| T-003 | Create test fixtures | Codex Max |  Claude  | Pending     | [ ] |
```

---

## 7. Safety Considerations

### Sandbox Modes

| Mode                 | Access Level           | Use Case                        | Risk |
| -------------------- | ---------------------- | ------------------------------- | ---- |
| `workspace-write`    | Project directory only | 95% of tasks                    | Low  |
| `danger-full-access` | Full system access     | System scripts, global installs | High |

### Default: workspace-write (ALWAYS START HERE)

```bash
# Standard safe execution
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "task"
```

### Escalation to danger-full-access

**Pre-Escalation Checklist (ALL REQUIRED)**

- [ ] Task genuinely requires system-wide access
- [ ] Running in isolated container/VM (not host system)
- [ ] Security review completed by second AI
- [ ] Backup/checkpoint created before execution
- [ ] Changes will be reviewed post-execution

**Escalated Execution**

```bash
# ONLY after checklist passes
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s danger-full-access "task"
```

### Operations Requiring Escalation

| Operation               | Requires Escalation | Alternative                   |
| ----------------------- | :-----------------: | ----------------------------- |
| Install global packages |         Yes         | Use local node_modules        |
| Modify /etc files       |         Yes         | Use project .env              |
| Run docker commands     |         Yes         | Use docker-compose in project |
| Access outside project  |         Yes         | Copy files into project first |
| Modify git config       |         Yes         | Use project .git/config       |

### Security Best Practices

1. **Never commit sensitive output** - Review all changes before git add
2. **Sanitize prompts** - Remove API keys, passwords from context
3. **Review generated code** - Check for hardcoded secrets
4. **Use environment variables** - Never let Codex hardcode credentials
5. **Audit system commands** - Review any shell commands in generated code

---

## 8. Handoff Patterns

### Handoff TO Codex Max

**From Gemini Deep (Large Context Analysis)**

```bash
# Gemini analyzes, Codex implements
ANALYSIS=$(gemini -m gemini-3-pro-preview --approval-mode yolo \
  "Analyze entire codebase for: $TASK. Output: file list, patterns, dependencies")

codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write \
  "Analysis context: $ANALYSIS \nImplement: $TASK"
```

**From Claude Opus (Architecture Design)**

```bash
# Claude designs, Codex implements
DESIGN=$(claude --model opus "Design architecture for: $TASK")

codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write \
  "Architecture spec: $DESIGN \nImplement according to design"
```

### Handoff FROM Codex Max

**To Claude (Security Review)**

```bash
# Codex implements, Claude reviews
IMPLEMENTATION=$(codex exec -m gpt-5.2-codex -s workspace-write "$TASK")

# Use Claude to verify security
# (Security review in Claude session)
```

**To Gemini (Documentation)**

```bash
# Codex implements, Gemini documents
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "$TASK"

gemini -m gemini-3-pro-preview --approval-mode yolo \
  "Generate comprehensive documentation for the changes in: $(git diff HEAD~1)"
```

### Context Size Handoff Rules

| Source Context   | Target    | Method                                  |
| ---------------- | --------- | --------------------------------------- |
| < 100K tokens    | Codex Max | Direct pass                             |
| 100K-300K tokens | Codex Max | Summarize to ~50K + key files           |
| > 300K tokens    | Codex Max | Use Gemini to extract relevant portions |

### Handoff Template

```bash
# Standard handoff pattern
CONTEXT=$(gemini -m gemini-3-pro-preview --approval-mode yolo \
  "Extract relevant context for $TASK. Output max 50K tokens of: file contents, patterns, dependencies")

RESULT=$(codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write \
  "Context: $CONTEXT \nTask: $TASK")

echo "$RESULT" | head -c 50000 > /tmp/codex_output.txt
```

---

## 9. Quality Verification for Codex Outputs

### Verification Protocol

Every Codex Max output must be verified before marking complete.

**Verification Request Format**

```
VERIFY:
- Scope: [files modified by Codex]
- Change summary: [what Codex implemented]
- Expected behavior: [acceptance criteria]
- Repro steps: [how to test]
- Evidence to check: [tests, logs, manual verification]
- Risk notes: [potential issues]
```

### Automated Quality Checks

```bash
# Post-implementation checks
codex exec -m gpt-5.2-codex -s workspace-write "$TASK"

# 1. Lint check
npm run lint || echo "LINT FAILED"

# 2. Type check
npm run typecheck || echo "TYPE CHECK FAILED"

# 3. Unit tests
npm test || echo "TESTS FAILED"

# 4. Security scan
npm audit || echo "SECURITY ISSUES"
```

### Verification by Different AI

**Claude Verification**

```bash
# In Claude session
# "Review the following Codex output for correctness and security..."
```

**Gemini Verification**

```bash
gemini -m gemini-3-pro-preview --approval-mode yolo \
  "VERIFY Codex implementation:
   Files: $(git diff --name-only HEAD~1)
   Changes: $(git diff HEAD~1)
   Check: correctness, patterns, security, edge cases
   Result: PASS/FAIL with reasons"
```

### Quality Metrics

| Metric              | Target     | Measurement                        |
| ------------------- | ---------- | ---------------------------------- |
| First-pass success  | > 85%      | Verification passes without rework |
| Test coverage delta | >= 0%      | Coverage must not decrease         |
| Lint errors         | 0          | No new lint violations             |
| Type errors         | 0          | No new type errors                 |
| Security issues     | 0 critical | No new critical vulnerabilities    |

### Re-verification After Failure

```bash
# If verification fails:
# 1. Fix issues
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write \
  "Fix issues: [FAIL reasons] \nOriginal task: $TASK"

# 2. Submit fresh verification request
# 3. Different verifier re-runs full scope
```

---

## 10. Example Workflows

### Workflow 1: Full-Stack Feature Implementation

```bash
# Step 1: Analysis (Gemini)
ANALYSIS=$(gemini -m gemini-3-pro-preview --approval-mode yolo \
  "Analyze codebase for implementing user notifications feature.
   Identify: models, services, API routes, frontend components needed")

# Step 2: Backend Implementation (Codex Max)
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "
Context: $ANALYSIS
Task: Implement backend for user notifications

Requirements:
1. Notification model (id, user_id, type, message, read, created_at)
2. CRUD API endpoints (/api/notifications)
3. WebSocket support for real-time delivery
4. Background job for email notifications

Include: Database migration, tests, error handling
"

# Step 3: Frontend Implementation (Codex Max)
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "
Task: Implement frontend notification components

Requirements:
1. NotificationBell component with unread count
2. NotificationList dropdown
3. WebSocket hook for real-time updates
4. Mark as read functionality

Use: React, TypeScript, existing UI component library
"

# Step 4: Verification (Gemini)
gemini -m gemini-3-pro-preview --approval-mode yolo \
  "VERIFY notification feature implementation:
   $(git diff main...HEAD)
   Check: API correctness, WebSocket handling, UI/UX, security. PASS/FAIL"
```

### Workflow 2: Project-Wide Refactoring

```bash
# Step 1: Identify scope (Gemini - large context)
SCOPE=$(gemini -m gemini-3-pro-preview --approval-mode yolo \
  "Identify all files using deprecated UserService.getUser() method.
   List: file paths, line numbers, suggested replacements")

# Step 2: Execute refactoring (Codex Max)
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "
Scope: $SCOPE
Task: Refactor UserService.getUser() to UserService.findById()

Requirements:
1. Update all call sites
2. Change method signature to return Promise<User | null>
3. Add null checks at all call sites
4. Update tests
5. Deprecate old method with JSDoc @deprecated

Constraint: Maintain backward compatibility for 1 release
"

# Step 3: Test verification
npm test

# Step 4: AI verification (Claude)
# "Review refactoring changes for completeness and safety..."
```

### Workflow 3: Security Vulnerability Remediation

```bash
# Step 1: Security scan analysis (Claude Opus)
# "Analyze npm audit results and prioritize fixes..."

# Step 2: Fix implementation (Codex Max)
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "
Security Issues:
1. SQL injection in src/api/search.ts (line 45)
2. XSS vulnerability in src/components/Comment.tsx
3. Insecure randomness in src/utils/token.ts

Task: Remediate all security vulnerabilities

Requirements:
1. Use parameterized queries for SQL
2. Sanitize HTML output with DOMPurify
3. Use crypto.randomBytes for token generation
4. Add input validation
5. Include regression tests for each fix
"

# Step 3: Security verification (Claude)
# "Verify security fixes are complete and effective..."

# Step 4: Re-scan
npm audit
```

### Workflow 4: Test Suite Generation

```bash
# Step 1: Analyze untested code (Gemini)
COVERAGE=$(gemini -m gemini-3-pro-preview --approval-mode yolo \
  "Analyze test coverage report. Identify untested:
   1. Functions
   2. Edge cases
   3. Error paths
   Output: prioritized list with file:line references")

# Step 2: Generate tests (Codex Max)
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "
Coverage gaps: $COVERAGE
Task: Generate comprehensive tests to achieve 80%+ coverage

Requirements:
1. Unit tests for all public functions
2. Edge case coverage (null, empty, boundary values)
3. Error path testing
4. Mock external dependencies
5. Use existing test patterns from __tests__/

Framework: Jest with Testing Library
"

# Step 3: Run and verify
npm test -- --coverage

# Step 4: Verification (Gemini)
gemini -m gemini-3-pro-preview --approval-mode yolo \
  "Verify test quality: $(cat coverage/lcov-report/index.html)
   Check: meaningful assertions, edge cases, no false positives. PASS/FAIL"
```

---

## CLI Reference

### Canonical Command (ALWAYS USE)

```bash
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "task"
```

### Command Options

| Flag        | Description            | Example                                         |
| ----------- | ---------------------- | ----------------------------------------------- |
| `-m`        | Model selection        | `-m gpt-5.2-codex`                              |
| `-c`        | Configuration override | `-c 'model_reasoning_effort="xhigh"'`           |
| `-s`        | Sandbox mode           | `-s workspace-write` or `-s danger-full-access` |
| `--timeout` | Execution timeout      | `--timeout 600` (10 minutes)                    |
| `--context` | Add directory context  | `--context .`                                   |

### Configuration File (~/.codex/config.toml)

```toml
# Codex Max configuration
model = "gpt-5.2-codex"
model_provider = "openai"
model_context_window = 400000
model_max_output_tokens = 128000
model_reasoning_effort = "xhigh"
approval_policy = "never"
sandbox_mode = "workspace-write"
```

### Profile Usage

```bash
# Create max-reasoning profile
codex --profile max-reasoning "task"

# List profiles
codex profiles list
```

---

## Troubleshooting

| Issue                     | Cause            | Solution                                |
| ------------------------- | ---------------- | --------------------------------------- |
| `exit 2`                  | Auth expired     | Run `codex auth`                        |
| `exit 124`                | Timeout          | Split task or `--timeout 600`           |
| `context_length_exceeded` | Too much input   | Reduce context, use Gemini for analysis |
| `429 Too Many Requests`   | Rate limited     | Wait 2^n seconds, check usage           |
| Empty output              | Prompt too vague | Add specificity, include examples       |
| Incomplete code           | Output truncated | Request in smaller chunks               |

---

## Example Invocation

```bash
/agents/ai-ml/codex-max Refactor the entire authentication system from session-based to JWT with refresh tokens across all 50+ affected files, including database migrations, API endpoints, middleware, tests, and documentation updates
```

---

Ahmed Adel Bakr Alderai
