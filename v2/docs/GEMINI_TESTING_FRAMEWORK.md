# Gemini Testing and Validation Framework

## Overview

This document defines the comprehensive testing and validation framework for the Autonomous SDLC Orchestrator. It integrates existing agent tools (`tri-agent-*`) with the defined Quality Gates to ensure code robustness, security, and maintainability.

## 1. SDLC Phase Transitions & Testing

The system enforces quality through 5 distinct gates. Tests are triggered automatically at each transition.

| Transition | Phase | Required Tests & Validations | Tool / Command |
| :--- | :--- | :--- | :--- |
| **Gate 1** | Brainstorm → Document | • Requirements Completeness Check<br>• Ambiguity Analysis | `codex-ask` (Reviewer Persona) |
| **Gate 2** | Document → Plan | • Architecture Review<br>• Feasibility Analysis | `gemini-ask` (Architect Persona) |
| **Gate 3** | Plan → Execute | • Dependency Graph Validation<br>• Task Granularity Check | `tri-agent-supervisor` (Planner) |
| **Gate 4** | **Execute → Approved** | • **Unit Tests** (100% Pass)<br>• **Code Coverage** (≥ 80%)<br>• **Linting** (Zero Errors)<br>• **Type Checking** (Zero Errors)<br>• **Security Scan** (Zero Critical/High)<br>• **Tri-Agent Consensus** | `npm test`<br>`tri-agent-coverage`<br>`npm run lint`<br>`tri-agent-security-audit`<br>`tri-agent-consensus` |
| **Gate 5** | Approved → Track | • Integration Tests<br>• Smoke Tests<br>• Deployment Verification | `npm run test:e2e`<br>`health-check` |

## 2. Code Coverage Enforcement (80%)

We enforce a strict **80% code coverage** validation.

### Mechanism
The `bin/tri-agent-coverage` tool analyzes the codebase and test suites.

- **Bash Scripts**: Static analysis maps defined functions in `bin/` and `lib/` against usages in `tests/`.
- **TypeScript/Python**: Standard coverage tools (Jest/Pytest) are parsed.

### Enforcement Policy
- **Threshold**: Global minimum of **80%**.
- **Blocking**: PRs and Task Completions (Gate 4) **fail automatically** if coverage drops below the threshold.
- **Reporting**: Detailed reports identify specific untested functions.

**Command:**
```bash
bin/tri-agent-coverage --run --threshold 80
```

## 3. Automated Security Scans

Security is proactive and automated using `bin/tri-agent-security-audit`.

### Scan Scope
1.  **Secret Detection**: API keys, tokens, passwords in code/config.
2.  **Permissions**: World-writable files, dangerous SUID/SGID bits.
3.  **Injection Flaws**: Unsafe `eval`, unquoted variables, shell injection risks.
4.  **Configuration**: Debug mode in prod, insecure protocols (HTTP/FTP).

### Execution Triggers
- **Pre-Commit**: Fast scan (`--quick`) for secrets and injection flaws.
- **Gate 4 (Approval)**: Full scan (`--full`) required for task completion.
- **Daily**: Scheduled full audit of the entire repository.

**Command:**
```bash
bin/tri-agent-security-audit --full --json
```

## 4. Code Quality Validation

Quality is measured by `bin/tri-agent-quality` and enforced via standard linters.

### Metrics Collected
- **Complexity**: Cyclomatic complexity estimation.
- **Documentation**: % of public functions with docstrings/usage comments.
- **Duplication**: Detection of copy-pasted code blocks.
- **Maintainability Index**: Composite score (0-100).

### Enforcement
- **Linting**: Standard `eslint` (TS) and `shellcheck` (Bash) must pass with **0 errors**.
- **Type Safety**: TypeScript `strict: true` mode checks must pass.
- **Quality Score**: A minimum score of **80/100** from `tri-agent-quality` is required.

**Command:**
```bash
bin/tri-agent-quality --full
```

## 5. Tri-Agent Code Review Consensus

Final approval requires consensus from three distinct AI agents (Claude, Codex, Gemini) to eliminate bias and hallucination.

### The Process (EXE-009)
1.  **Diff Generation**: The orchestrator extracts the git diff for the task.
2.  **Parallel Review**: The diff is sent simultaneously to:
    *   **Claude**: Focuses on **Architecture & Logic**.
    *   **Codex**: Focuses on **Implementation Bugs & Edge Cases**.
    *   **Gemini**: Focuses on **Security & Performance**.
3.  **Voting**: Each agent returns `APPROVE` or `REQUEST_CHANGES`.
4.  **Consensus**:
    *   **Pass**: ≥ 2/3 agents vote `APPROVE`.
    *   **Fail**: < 2 approvals triggers a rejection with consolidated feedback.

### Feedback Loop
If rejected, the specific feedback from the dissenting agents is aggregated and fed back to the implementing agent (Worker) for immediate remediation.

**Command:**
```bash
bin/tri-agent-consensus --diff HEAD~1
```
