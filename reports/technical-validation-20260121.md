# Technical Validation Report (2026-01-21)

## Scope and method
- Reviewed `commands/**/*.md`, `agents/**/*.md`, and `**/SKILL.md`.
- YAML frontmatter parsed with PyYAML (top-of-file `---` blocks).
- Shell snippets validated with `bash -n` for fenced blocks labeled `bash`, `sh`, `shell`, `zsh`, `console`, or `terminal` (console prompts stripped).
- Agent references validated against agent names from `agents/**/*.md` frontmatter and command agent filenames in `commands/agents/`.

## Summary
- Commands: 164 files; 81 with valid frontmatter; 80 without frontmatter; 3 invalid frontmatter blocks.
- Agents: 94 files; 70 with valid frontmatter; 23 missing frontmatter; 1 invalid frontmatter blocks.
- Skills: 13 files; 0 frontmatter errors.
- Shell snippets: 17 syntax errors found.
- Agent references: 12 missing `subagent_type` targets; 9 `subagent_type` mismatches; 31 command agent docs without `subagent_type`.

## Findings

### 1) YAML frontmatter issues (commands)
- `commands/agents/quality/doc-linter-agent.md`: unterminated
- `commands/agents/security/guardrails-agent.md`: parse_error: ParserError: while parsing a block collection
  in "<unicode string>", line 11, column 3:
      - "read_file"
      ^
expected <block end>, but found '<scalar>'
  in "<unicode string>", line 12, column 18:
      - "write_file" (for audit logs only)
                     ^
- `commands/git/sync.md`: parse_error: ScannerError: mapping values are not allowed here
  in "<unicode string>", line 10, column 43:
     ... ption: Sync mode to run (default: status).
                                         ^
- 80 command files have no frontmatter (if frontmatter is required by tooling, these will be skipped).

### 2) Internal references between agents
- `subagent_type` values not defined by any agent frontmatter:
  - `commands/agents/integration/webhook-expert.md` -> `webhook-expert`
  - `commands/agents/integration/third-party-api-expert.md` -> `third-party-api-expert`
  - `commands/agents/integration/mcp-expert.md` -> `mcp-expert`
  - `commands/agents/ai-ml/gemini-deep.md` -> `general-purpose`
  - `commands/agents/business/cost-optimizer.md` -> `cost-optimizer`
  - `commands/agents/business/business-analyst.md` -> `business-analyst`
  - `commands/agents/devops/incident-response-agent.md` -> `incident-response`
  - `commands/agents/devops/ci-cd-expert.md` -> `ci-cd-expert`
  - `commands/agents/security/regulatory-compliance-agent.md` -> `regulatory-compliance`
  - `commands/agents/security/dependency-auditor.md` -> `dependency-auditor`
  - `commands/agents/cloud/azure-expert.md` -> `azure-expert`
  - `commands/agents/cloud/multi-cloud-architect.md` -> `multi-cloud-architect`
- `subagent_type` does not match command filename:
  - `commands/agents/ai-ml/gemini-deep.md`: file stem `gemini-deep`, `subagent_type` `general-purpose`
  - `commands/agents/devops/incident-response-agent.md`: file stem `incident-response-agent`, `subagent_type` `incident-response`
  - `commands/agents/devops/infrastructure-architect.md`: file stem `infrastructure-architect`, `subagent_type` `architect`
  - `commands/agents/performance/profiling-expert.md`: file stem `profiling-expert`, `subagent_type` `performance-analyst`
  - `commands/agents/performance/performance-optimizer.md`: file stem `performance-optimizer`, `subagent_type` `performance-analyst`
  - `commands/agents/security/regulatory-compliance-agent.md`: file stem `regulatory-compliance-agent`, `subagent_type` `regulatory-compliance`
  - `commands/agents/security/penetration-tester.md`: file stem `penetration-tester`, `subagent_type` `security-expert`
  - `commands/agents/cloud/multi-cloud-expert.md`: file stem `multi-cloud-expert`, `subagent_type` `architect`
  - `commands/agents/cloud/gcp-expert.md`: file stem `gcp-expert`, `subagent_type` `aws-expert`
- Command agent docs missing `subagent_type` in Invoke/usage instructions:
  - `commands/agents/integration/api-observability-agent.md`
  - `commands/agents/ai-ml/claude-opus-max.md`
  - `commands/agents/ai-ml/llmops-agent.md`
  - `commands/agents/ai-ml/codex-max.md`
  - `commands/agents/ai-ml/quality-metrics-agent.md`
  - `commands/agents/ai-ml/rag-expert.md`
  - `commands/agents/ai-ml/prompt-engineer.md`
  - `commands/agents/ai-ml/langchain-expert.md`
  - `commands/agents/business/project-tracker.md`
  - `commands/agents/business/stakeholder-communicator.md`
  - `commands/agents/devops/self-healing-pipeline-agent.md`
  - `commands/agents/devops/github-actions-expert.md`
  - `commands/agents/testing/api-contract-agent.md`
  - `commands/agents/database/migration-expert-full.md`
  - `commands/agents/planning/spec-generator.md`
  - `commands/agents/planning/requirements-analyzer.md`
  - `commands/agents/performance/load-testing-expert.md`
  - `commands/agents/performance/bundle-optimizer.md`
  - `commands/agents/security/guardrails-agent.md`
  - `commands/agents/general/cascade-agent.md`
  - `commands/agents/general/observability-agent.md`
  - `commands/agents/general/orchestrator.md`
  - `commands/agents/general/pair-programmer.md`
  - `commands/agents/general/task-router.md`
  - `commands/agents/general/model-router.md`
  - `commands/agents/frontend/state-management-expert.md`
  - `commands/agents/quality/semantic-search-agent.md`
  - `commands/agents/quality/dependency-manager.md`
  - `commands/agents/quality/doc-linter-agent.md`
  - `commands/agents/cloud/gcp-expert-full.md`
  - `commands/agents/cloud/serverless-expert.md`
- `commands/agents/index.md` references agent names without a matching agent definition:
  - `azure-expert`, `cascade-agent`, `ci-cd-expert`, `claude-opus-max`, `codex-max`, `cost-optimizer`, `gcp-expert`, `gemini-deep`, `github-actions-expert`, `incident-response-agent`, `mcp-expert`, `model-router`, `pair-programmer`, `performance-optimizer`, `profiling-expert`, `project-tracker`, `stakeholder-communicator`, `webhook-expert`
- Command agent docs without a corresponding agent definition file:
  - `api-contract-agent`, `api-observability-agent`, `azure-expert`, `cascade-agent`, `ci-cd-expert`, `claude-opus-max`, `codex-max`, `dependency-auditor`, `dependency-manager`, `doc-linter-agent`, `gcp-expert`, `gcp-expert-full`, `gemini-deep`, `github-actions-expert`, `guardrails-agent`, `incident-response-agent`, `langchain-expert`, `llmops-agent`, `load-testing-expert`, `mcp-expert`, `migration-expert-full`, `model-router`, `multi-cloud-architect`, `multi-cloud-expert`, `observability-agent`, `pair-programmer`, `performance-optimizer`, `profiling-expert`, `project-tracker`, `quality-metrics-agent`, `rag-expert`, `regulatory-compliance-agent`, `requirements-analyzer`, `self-healing-pipeline-agent`, `semantic-search-agent`, `serverless-expert`, `spec-generator`, `third-party-api-expert`, `webhook-expert`
- Likely naming mismatches (expert vs specialist) between commands and agent files:
  - `azure-expert` -> `azure-specialist`
  - `ci-cd-expert` -> `ci-cd-specialist`
  - `gcp-expert` -> `gcp-specialist`
  - `github-actions-expert` -> `github-actions-specialist`
  - `load-testing-expert` -> `load-testing-specialist`
  - `profiling-expert` -> `profiling-specialist`
  - `serverless-expert` -> `serverless-specialist`
  - `third-party-api-expert` -> `third-party-api-specialist`
  - `webhook-expert` -> `webhook-specialist`
- `integrations` lists include non-agent entries (not resolvable as agents or command paths):
  - `commands/agents/planning/spec-generator.md`: `qa-engineer`
  - `commands/agents/general/cascade-agent.md`: `GitHub`
  - `commands/agents/general/cascade-agent.md`: `Linear`
  - `commands/agents/general/cascade-agent.md`: `Jira`
  - `commands/agents/general/cascade-agent.md`: `Claude Architect Agent`
  - `commands/agents/general/cascade-agent.md`: `Claude Backend Agent`
  - `commands/agents/general/cascade-agent.md`: `Claude Frontend Agent`
  - `commands/agents/general/cascade-agent.md`: `Claude Test Agent`
- Agent category counts in `commands/agents/index.md` do not match actual command docs:
  - Planning: index=9, actual=10
  - Testing: index=10, actual=9
  - DevOps: index=11, actual=10
  - Cloud: index=6, actual=7

### 3) Command examples and shell snippet syntax
- `commands/agents/ai-ml/claude-opus-max.md` (block 8, bash): /tmp/tmpwtnxdmr9.sh: line 5: syntax error near unexpected token `('
/tmp/tmpwtnxdmr9.sh: line 5: `Predicted Cost = (Input * $0.015) + (Output * $0.075) + (Thinking * $0.075)'
  - First line: `# Daily cap enforcement`
- `commands/agents/devops/kubernetes-expert.md` (block 39, bash): /tmp/tmpqqm1uum6.sh: line 5: syntax error near unexpected token `newline'
/tmp/tmpqqm1uum6.sh: line 5: `kubectl describe node <node-name>'
  - First line: `# Cluster info`
- `commands/agents/devops/kubernetes-expert.md` (block 41, bash): /tmp/tmp0gx9sf8u.sh: line 2: syntax error near unexpected token `newline'
/tmp/tmp0gx9sf8u.sh: line 2: `kubectl debug <pod-name> -it --image=nicolaka/netshoot --target=<container>'
  - First line: `# Add debug container to running pod`
- `commands/agents/index.md` (block 23, bash): /tmp/tmp77shqvwz.sh: line 1: syntax error near unexpected token `<'
/tmp/tmp77shqvwz.sh: line 1: `/agents/<category>/<agent-name> <task-description>'
  - First line: `/agents/<category>/<agent-name> <task-description>`
- `commands/agents/index.md` (block 27, bash): /tmp/tmpqrg71z1n.sh: line 2: syntax error near unexpected token `newline'
/tmp/tmpqrg71z1n.sh: line 2: `/agents/ai-ml/claude-opus-max <complex-architecture-task>'
  - First line: `# For architecture (use Opus)`
- `commands/agents/index.md` (block 28, bash): /tmp/tmpf53si9rc.sh: line 1: syntax error near unexpected token `newline'
/tmp/tmpf53si9rc.sh: line 1: `/agents/general/orchestrator <task>'
  - First line: `/agents/general/orchestrator <task>`
- `commands/agents/index.md` (block 29, bash): /tmp/tmpmbr7g6qe.sh: line 1: syntax error near unexpected token `newline'
/tmp/tmpmbr7g6qe.sh: line 1: `/agents/planning/architect <system-description>'
  - First line: `/agents/planning/architect <system-description>`
- `commands/agents/index.md` (block 30, bash): /tmp/tmp_xa01cr0.sh: line 1: syntax error near unexpected token `newline'
/tmp/tmp_xa01cr0.sh: line 1: `/agents/backend/nodejs-expert <node-task>'
  - First line: `/agents/backend/nodejs-expert <node-task>`
- `commands/agents/index.md` (block 31, bash): /tmp/tmphfzsmvm4.sh: line 1: syntax error near unexpected token `newline'
/tmp/tmphfzsmvm4.sh: line 1: `/agents/quality/code-reviewer review <module>'
  - First line: `/agents/quality/code-reviewer review <module>`
- `commands/agents/index.md` (block 32, bash): /tmp/tmp83ag_7lz.sh: line 1: syntax error near unexpected token `newline'
/tmp/tmp83ag_7lz.sh: line 1: `/agents/devops/ci-cd-expert design pipeline for <project>'
  - First line: `/agents/devops/ci-cd-expert design pipeline for <project>`
- `commands/agents/index.md` (block 33, bash): /tmp/tmpfjit4nkr.sh: line 1: syntax error near unexpected token `newline'
/tmp/tmpfjit4nkr.sh: line 1: `/agents/ai-ml/claude-opus-max <complex-task>'
  - First line: `/agents/ai-ml/claude-opus-max <complex-task>`
- `commands/agents/performance/profiling-expert.md` (block 2, bash): /tmp/tmpf6msokit.sh: line 4: syntax error near unexpected token `newline'
/tmp/tmpf6msokit.sh: line 4: `py-spy record -o profile.svg --pid <PID>           # Attach to running process'
  - First line: `# === PYTHON CPU PROFILING ===`
- `commands/agents/performance/profiling-expert.md` (block 3, bash): /tmp/tmp4syukt08.sh: line 100: syntax error near unexpected token `newline'
/tmp/tmp4syukt08.sh: line 100: `jmap -dump:format=b,file=heap.hprof <PID>'
  - First line: `# === PYTHON MEMORY PROFILING ===`
- `commands/agents/performance/profiling-expert.md` (block 4, bash): /tmp/tmp26n5fd0s.sh: line 4: syntax error near unexpected token `newline'
/tmp/tmp26n5fd0s.sh: line 4: `py-spy record -o flamegraph.svg --pid <PID>'
  - First line: `# === GENERATING FLAME GRAPHS ===`
- `commands/agents/security/penetration-tester.md` (block 37, bash): /tmp/tmpsg5uhz5x.sh: line 2: syntax error near unexpected token `('
/tmp/tmpsg5uhz5x.sh: line 2: `/agents/security/penetration-tester test web app at https://staging.example.com (authorized pentest, scope: web app only)'
  - First line: `# Web application penetration test`
- `plugins/marketplaces/claude-plugins-official/plugins/plugin-dev/skills/plugin-settings/SKILL.md` (block 3, bash): /tmp/tmpe37zkvn7.sh: line 28: syntax error near unexpected token `fi'
/tmp/tmpe37zkvn7.sh: line 28: `fi'
  - First line: `#!/bin/bash`
- `plugins/marketplaces/claude-plugins-official/plugins/plugin-dev/skills/plugin-settings/SKILL.md` (block 19, bash): /tmp/tmp2yey4kmd.sh: line 8: syntax error near unexpected token `fi'
/tmp/tmp2yey4kmd.sh: line 8: `fi'
  - First line: `if [[ ! -f "$STATE_FILE" ]]; then`

### 4) Agent pattern inconsistencies
- Agent files missing YAML frontmatter:
  - `agents/07-quality/code-archaeologist.md`
  - `agents/07-quality/qa-validator.md`
  - `agents/07-quality/rubber-duck-debugger.md`
  - `agents/08-security/owasp-specialist.md`
  - `agents/08-security/penetration-tester.md`
  - `agents/09-performance/bundle-optimizer.md`
  - `agents/09-performance/load-testing-specialist.md`
  - `agents/09-performance/profiling-specialist.md`
  - `agents/10-devops/ci-cd-specialist.md`
  - `agents/10-devops/deployment-manager.md`
  - `agents/10-devops/github-actions-specialist.md`
  - `agents/10-devops/infrastructure-architect.md`
  - `agents/11-cloud/azure-specialist.md`
  - `agents/11-cloud/gcp-specialist.md`
  - `agents/11-cloud/serverless-specialist.md`
  - `agents/12-ai-ml/ai-agent-builder.md`
  - `agents/12-ai-ml/prompt-engineer.md`
  - `agents/13-integration/mcp-integration-specialist.md`
  - `agents/13-integration/third-party-api-specialist.md`
  - `agents/13-integration/webhook-specialist.md`
  - `agents/14-business/business-analyst.md`
  - `agents/14-business/cost-optimizer.md`
  - `agents/14-business/stakeholder-communicator.md`
- Agent files with invalid YAML frontmatter:
  - `agents/codex-sdlc-developer.md`: parse_error: ScannerError: mapping values are not allowed here
  in "<unicode string>", line 2, column 323:
     ...  Examples:\n\n<example>\nContext: User needs a new feature imple ... 
                                         ^

### 5) Skill files
- No YAML frontmatter errors found in skill files.
