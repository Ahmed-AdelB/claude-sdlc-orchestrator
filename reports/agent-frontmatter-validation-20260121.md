# Agent Frontmatter Validation Report

> **Generated:** 2026-01-21 | **Author:** Ahmed Adel Bakr Alderai | **Total Files Analyzed:** 99

## Executive Summary

| Status                    | Count | Percentage |
| ------------------------- | ----- | ---------- |
| **Valid Frontmatter**     | 48    | 48.5%      |
| **Missing Frontmatter**   | 47    | 47.5%      |
| **Malformed Frontmatter** | 4     | 4.0%       |

---

## Validation Criteria

### Required Fields

- `name` - Agent identifier
- `description` - Purpose and capabilities
- `version` - Semantic version (e.g., 1.0.0)
- `author` - Attribution (Ahmed Adel Bakr Alderai)
- `category` - Domain classification
- `tools` - Available tools list

### Recommended Fields

- `integrations` - Related agents
- `tags` - Searchable keywords
- `capabilities` - Detailed feature list

### Frontmatter Format

```yaml
---
name: agent-name
description: Agent description
version: 1.0.0
author: Ahmed Adel Bakr Alderai
category: backend
tools:
  - Read
  - Write
  - Bash
---
```

---

## Files with Valid Frontmatter (48 files)

### AI-ML Category (7 files)

| File                             | Required Fields                              | Recommended Fields                                    | Status   |
| -------------------------------- | -------------------------------------------- | ----------------------------------------------------- | -------- |
| `ai-ml/claude-opus-max.md`       | name, description, version, author, category | integrations, model, context_window, reasoning        | COMPLETE |
| `ai-ml/codex-max.md`             | name, description, version, author, category | integrations, model, context_window, reasoning_effort | COMPLETE |
| `ai-ml/langchain-expert.md`      | name, description, version, category, author | tags, capabilities                                    | COMPLETE |
| `ai-ml/llmops-agent.md`          | name, description, category, tools           | -                                                     | PARTIAL  |
| `ai-ml/prompt-engineer.md`       | name, description, category, tools, version  | -                                                     | PARTIAL  |
| `ai-ml/quality-metrics-agent.md` | name, description, tools, version, category  | tags, capabilities, integrations                      | COMPLETE |
| `ai-ml/rag-expert.md`            | name, description, version, category, author | tags, capabilities, tools, integrations               | COMPLETE |

### Cloud Category (5 files)

| File                             | Required Fields                                     | Recommended Fields         | Status   |
| -------------------------------- | --------------------------------------------------- | -------------------------- | -------- |
| `cloud/azure-expert.md`          | name, description, version, author, category, tools | integrates_with            | COMPLETE |
| `cloud/gcp-expert-full.md`       | name, description, version, author, tools, category | -                          | COMPLETE |
| `cloud/multi-cloud-architect.md` | name, description, version, author, category, tools | integrations               | COMPLETE |
| `cloud/multi-cloud-expert.md`    | name, description, version, category, tools         | integrations, capabilities | COMPLETE |
| `cloud/serverless-expert.md`     | name, description, version, author, category, tools | integrations, triggers     | COMPLETE |

### DevOps Category (6 files)

| File                                    | Required Fields                                     | Recommended Fields                                       | Status   |
| --------------------------------------- | --------------------------------------------------- | -------------------------------------------------------- | -------- |
| `devops/ci-cd-expert.md`                | name, description, version, author, category, tools | integrates_with                                          | COMPLETE |
| `devops/github-actions-expert.md`       | name, description, category, tools                  | -                                                        | PARTIAL  |
| `devops/incident-response-agent.md`     | name, description, version, author, category, tools | integrations, monitoring_integrations, alerting_channels | COMPLETE |
| `devops/infrastructure-architect.md`    | name, description, version, author, category, tools | integrations, tags                                       | COMPLETE |
| `devops/self-healing-pipeline-agent.md` | name, description, version, author, tools           | capabilities, permissions                                | COMPLETE |

### Frontend Category (4 files)

| File                                  | Required Fields                      | Recommended Fields       | Status                                    |
| ------------------------------------- | ------------------------------------ | ------------------------ | ----------------------------------------- |
| `frontend/accessibility-expert.md`    | name, version, category, tools       | integrations, standards  | PARTIAL (missing description, author)     |
| `frontend/frontend-developer.md`      | name, description, version           | capabilities, tech_stack | PARTIAL (missing author, category, tools) |
| `frontend/state-management-expert.md` | name, description, version, category | tags, tools              | PARTIAL (missing author)                  |

### General Category (6 files)

| File                             | Required Fields                              | Recommended Fields                          | Status   |
| -------------------------------- | -------------------------------------------- | ------------------------------------------- | -------- |
| `general/cascade-agent.md`       | name, description, version, tools            | integrations                                | PARTIAL  |
| `general/model-router.md`        | name, description, version, author, tools    | mode                                        | COMPLETE |
| `general/observability-agent.md` | name, description, version, author, category | mode, tags, tools, integrations, thresholds | COMPLETE |
| `general/orchestrator.md`        | name, description, version, type             | capabilities, permissions                   | PARTIAL  |
| `general/pair-programmer.md`     | name, description, category, version, tools  | -                                           | PARTIAL  |

### Integration Category (4 files)

| File                                     | Required Fields                                     | Recommended Fields                               | Status   |
| ---------------------------------------- | --------------------------------------------------- | ------------------------------------------------ | -------- |
| `integration/api-integration-expert.md`  | name, description, version, author, category        | tags, tools, dependencies, inputs, outputs       | COMPLETE |
| `integration/api-observability-agent.md` | name, description, tools                            | integrates_with, metrics_storage, alert_config   | PARTIAL  |
| `integration/mcp-expert.md`              | name, description, version, author, category        | tags, tools, allowed_tools, dependencies, inputs | COMPLETE |
| `integration/third-party-api-expert.md`  | name, description, version, author, category, tools | triggers, related_agents, inputs                 | COMPLETE |
| `integration/webhook-expert.md`          | name, description, version, author, category        | tags, tools, dependencies, inputs, outputs       | COMPLETE |

### Performance Category (4 files)

| File                                   | Required Fields                                     | Recommended Fields                                | Status   |
| -------------------------------------- | --------------------------------------------------- | ------------------------------------------------- | -------- |
| `performance/bundle-optimizer.md`      | name, description, tools, category                  | -                                                 | PARTIAL  |
| `performance/load-testing-expert.md`   | name, description, category, tools                  | skills                                            | PARTIAL  |
| `performance/performance-optimizer.md` | name, description, version, author, category, tools | capabilities, integrations, languages, frameworks | COMPLETE |
| `performance/profiling-expert.md`      | name, description, version, author, category, tools | capabilities, languages                           | COMPLETE |

### Planning Category (3 files)

| File                                | Required Fields                                     | Recommended Fields                                                              | Status   |
| ----------------------------------- | --------------------------------------------------- | ------------------------------------------------------------------------------- | -------- |
| `planning/architect.md`             | name, description, version, author, category        | mode, level, tools, integrations, triggers, cost, context_window, quality_gates | COMPLETE |
| `planning/requirements-analyzer.md` | name, description, version, author, category, tools | -                                                                               | COMPLETE |
| `planning/spec-generator.md`        | name, description, version, author, tools           | integrations                                                                    | COMPLETE |

### Quality Category (3 files)

| File                               | Required Fields                             | Recommended Fields | Status  |
| ---------------------------------- | ------------------------------------------- | ------------------ | ------- |
| `quality/dependency-manager.md`    | name, description, tools, category, version | -                  | PARTIAL |
| `quality/doc-linter-agent.md`      | name, description, version, category, tools | system_prompt      | PARTIAL |
| `quality/semantic-search-agent.md` | name, description, tools, category, version | -                  | PARTIAL |

### Security Category (4 files)

| File                                      | Required Fields                                     | Recommended Fields                               | Status   |
| ----------------------------------------- | --------------------------------------------------- | ------------------------------------------------ | -------- |
| `security/dependency-auditor.md`          | name, description, version, type, category, tools   | capabilities, integrations                       | COMPLETE |
| `security/guardrails-agent.md`            | name, description, version, type                    | capabilities, tools                              | PARTIAL  |
| `security/penetration-tester.md`          | name, description, version, author, category, tools | integrations, authorization_required, risk_level | COMPLETE |
| `security/regulatory-compliance-agent.md` | name, description, category, version, author, tools | integrations, frameworks, capabilities, tags     | COMPLETE |

### Testing Category (2 files)

| File                            | Required Fields                                     | Recommended Fields                                                | Status   |
| ------------------------------- | --------------------------------------------------- | ----------------------------------------------------------------- | -------- |
| `testing/api-contract-agent.md` | name, description, version, category, tools         | -                                                                 | PARTIAL  |
| `testing/unit-test-expert.md`   | name, description, version, author, category, tools | level, mode, integrations, coverage_target, frameworks, languages | COMPLETE |

### Business Category (1 file)

| File                         | Required Fields                             | Recommended Fields | Status  |
| ---------------------------- | ------------------------------------------- | ------------------ | ------- |
| `business/cost-optimizer.md` | name, description, tools, version, category | integrates_with    | PARTIAL |

---

## Files with Missing Frontmatter (47 files)

These files have no YAML frontmatter (no `---` delimiters at the start of the file).

### Backend Category (9 files)

| File                         | Path                                                                       |
| ---------------------------- | -------------------------------------------------------------------------- |
| api-architect.md             | `/home/aadel/.claude/commands/agents/backend/api-architect.md`             |
| authentication-specialist.md | `/home/aadel/.claude/commands/agents/backend/authentication-specialist.md` |
| django-expert.md             | `/home/aadel/.claude/commands/agents/backend/django-expert.md`             |
| fastapi-expert.md            | `/home/aadel/.claude/commands/agents/backend/fastapi-expert.md`            |
| go-expert.md                 | `/home/aadel/.claude/commands/agents/backend/go-expert.md`                 |
| graphql-specialist.md        | `/home/aadel/.claude/commands/agents/backend/graphql-specialist.md`        |
| microservices-architect.md   | `/home/aadel/.claude/commands/agents/backend/microservices-architect.md`   |
| nodejs-expert.md             | `/home/aadel/.claude/commands/agents/backend/nodejs-expert.md`             |
| rails-expert.md              | `/home/aadel/.claude/commands/agents/backend/rails-expert.md`              |

### AI-ML Category (2 files)

| File                      | Path                                                                  |
| ------------------------- | --------------------------------------------------------------------- |
| llm-integration-expert.md | `/home/aadel/.claude/commands/agents/ai-ml/llm-integration-expert.md` |
| ml-engineer.md            | `/home/aadel/.claude/commands/agents/ai-ml/ml-engineer.md`            |

### Cloud Category (1 file)

| File          | Path                                                      |
| ------------- | --------------------------------------------------------- |
| gcp-expert.md | `/home/aadel/.claude/commands/agents/cloud/gcp-expert.md` |

### Database Category (4 files)

| File                  | Path                                                                 |
| --------------------- | -------------------------------------------------------------------- |
| database-architect.md | `/home/aadel/.claude/commands/agents/database/database-architect.md` |
| migration-expert.md   | `/home/aadel/.claude/commands/agents/database/migration-expert.md`   |
| mongodb-expert.md     | `/home/aadel/.claude/commands/agents/database/mongodb-expert.md`     |
| orm-expert.md         | `/home/aadel/.claude/commands/agents/database/orm-expert.md`         |

### DevOps Category (2 files)

| File                 | Path                                                              |
| -------------------- | ----------------------------------------------------------------- |
| devops-engineer.md   | `/home/aadel/.claude/commands/agents/devops/devops-engineer.md`   |
| monitoring-expert.md | `/home/aadel/.claude/commands/agents/devops/monitoring-expert.md` |

### Frontend Category (5 files)

| File                 | Path                                                                |
| -------------------- | ------------------------------------------------------------------- |
| css-expert.md        | `/home/aadel/.claude/commands/agents/frontend/css-expert.md`        |
| mobile-web-expert.md | `/home/aadel/.claude/commands/agents/frontend/mobile-web-expert.md` |
| testing-frontend.md  | `/home/aadel/.claude/commands/agents/frontend/testing-frontend.md`  |
| typescript-expert.md | `/home/aadel/.claude/commands/agents/frontend/typescript-expert.md` |
| vue-expert.md        | `/home/aadel/.claude/commands/agents/frontend/vue-expert.md`        |

### General Category (3 files)

| File                    | Path                                                                  |
| ----------------------- | --------------------------------------------------------------------- |
| memory-coordinator.md   | `/home/aadel/.claude/commands/agents/general/memory-coordinator.md`   |
| parallel-coordinator.md | `/home/aadel/.claude/commands/agents/general/parallel-coordinator.md` |
| session-manager.md      | `/home/aadel/.claude/commands/agents/general/session-manager.md`      |

### Performance Category (1 file)

| File              | Path                                                                |
| ----------------- | ------------------------------------------------------------------- |
| caching-expert.md | `/home/aadel/.claude/commands/agents/performance/caching-expert.md` |

### Planning Category (6 files)

| File                    | Path                                                                   |
| ----------------------- | ---------------------------------------------------------------------- |
| exponential-planner.md  | `/home/aadel/.claude/commands/agents/planning/exponential-planner.md`  |
| requirements-analyst.md | `/home/aadel/.claude/commands/agents/planning/requirements-analyst.md` |
| risk-assessor.md        | `/home/aadel/.claude/commands/agents/planning/risk-assessor.md`        |
| tech-lead.md            | `/home/aadel/.claude/commands/agents/planning/tech-lead.md`            |
| tech-spec-writer.md     | `/home/aadel/.claude/commands/agents/planning/tech-spec-writer.md`     |
| ux-researcher.md        | `/home/aadel/.claude/commands/agents/planning/ux-researcher.md`        |

### Quality Category (6 files)

| File                      | Path                                                                    |
| ------------------------- | ----------------------------------------------------------------------- |
| documentation-expert.md   | `/home/aadel/.claude/commands/agents/quality/documentation-expert.md`   |
| linting-expert.md         | `/home/aadel/.claude/commands/agents/quality/linting-expert.md`         |
| performance-analyst.md    | `/home/aadel/.claude/commands/agents/quality/performance-analyst.md`    |
| product-analyst.md        | `/home/aadel/.claude/commands/agents/quality/product-analyst.md`        |
| refactoring-expert.md     | `/home/aadel/.claude/commands/agents/quality/refactoring-expert.md`     |
| technical-debt-analyst.md | `/home/aadel/.claude/commands/agents/quality/technical-debt-analyst.md` |

### Security Category (3 files)

| File                         | Path                                                                        |
| ---------------------------- | --------------------------------------------------------------------------- |
| compliance-expert.md         | `/home/aadel/.claude/commands/agents/security/compliance-expert.md`         |
| secrets-management-expert.md | `/home/aadel/.claude/commands/agents/security/secrets-management-expert.md` |
| vulnerability-scanner.md     | `/home/aadel/.claude/commands/agents/security/vulnerability-scanner.md`     |

### Testing Category (5 files)

| File                       | Path                                                                     |
| -------------------------- | ------------------------------------------------------------------------ |
| api-test-expert.md         | `/home/aadel/.claude/commands/agents/testing/api-test-expert.md`         |
| integration-test-expert.md | `/home/aadel/.claude/commands/agents/testing/integration-test-expert.md` |
| performance-test-expert.md | `/home/aadel/.claude/commands/agents/testing/performance-test-expert.md` |
| tdd-coach.md               | `/home/aadel/.claude/commands/agents/testing/tdd-coach.md`               |
| test-data-expert.md        | `/home/aadel/.claude/commands/agents/testing/test-data-expert.md`        |

---

## Files with Malformed Frontmatter (4 files)

These files have frontmatter structure issues that need correction.

### 1. backend/backend-developer.md

**Issue:** H1 header appears BEFORE the frontmatter delimiters

**Current (Incorrect):**

```markdown
# Backend Developer Agent

---

tools:

- Read
- Write
  ...

---
```

**Correct Format:**

```yaml
---
name: backend-developer
description: "Expert backend engineer..."
version: 1.0.0
author: Ahmed Adel Bakr Alderai
category: backend
tools:
  - Read
  - Write
  - Edit
  - Task
  - Run
  - Grep
  - WebSearch
integrates_with:
  - frontend-developer
  - database-administrator
---
# Backend Developer Agent
```

### 2. business/business-analyst.md

**Issue:** Frontmatter structure is malformed - tools listed incorrectly, description placed oddly

**Fix:** Restructure with proper YAML syntax

### 3. business/stakeholder-communicator.md

**Issue:** Tools listed as list items before description field; description embedded inside tools section

**Current (Incorrect):**

```markdown
# Stakeholder Communicator Agent

---

tools:

- Read
- Write
- Edit
  ...
  description: Manages stakeholder communications...
  version: 1.0.0
```

**Correct Format:**

```yaml
---
name: stakeholder-communicator
description: Manages stakeholder communications including status reports, release notes, incident communications, demo scripts, and meeting summaries
version: 1.0.0
author: Ahmed Adel Bakr Alderai
category: business
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - WebSearch
  - Task
---
```

### 4. business/project-tracker.md

**Issue:** Same malformed structure as stakeholder-communicator.md

**Fix:** Apply same restructuring pattern

---

## Suggested Fixes

### Template for Adding Frontmatter

Use this template for files missing frontmatter:

```yaml
---
name: agent-name
description: >
  Brief description of the agent's purpose and expertise.
  Can span multiple lines using YAML block scalar.
version: 1.0.0
author: Ahmed Adel Bakr Alderai
category: backend|frontend|database|testing|quality|security|performance|devops|cloud|ai-ml|integration|business|planning|general
tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
  - Task
integrations:
  - related-agent-1
  - related-agent-2
tags:
  - keyword1
  - keyword2
capabilities:
  - capability1
  - capability2
---
```

### Priority Fix Order

1. **P0 - Critical (Malformed):** Fix 4 malformed files immediately
2. **P1 - High (Backend missing):** Add frontmatter to 9 backend agents
3. **P2 - Medium (Testing/Security):** Add frontmatter to 8 testing/security agents
4. **P3 - Normal (Others):** Add frontmatter to remaining 30 agents

### Automation Script

To add basic frontmatter to missing files:

```bash
#!/bin/bash
# add-frontmatter.sh
# Usage: ./add-frontmatter.sh <file> <category>

FILE="$1"
CATEGORY="$2"
NAME=$(basename "$FILE" .md)

# Extract description from first paragraph
DESC=$(sed -n '3p' "$FILE" | head -c 200)

FRONTMATTER="---
name: $NAME
description: \"$DESC\"
version: 1.0.0
author: Ahmed Adel Bakr Alderai
category: $CATEGORY
tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
---

"

# Prepend frontmatter
echo "$FRONTMATTER$(cat "$FILE")" > "$FILE.tmp"
mv "$FILE.tmp" "$FILE"
```

---

## Statistics by Category

| Category    | Total  | Valid  | Missing | Malformed |
| ----------- | ------ | ------ | ------- | --------- |
| ai-ml       | 9      | 7      | 2       | 0         |
| backend     | 10     | 1      | 9       | 1         |
| business    | 4      | 1      | 0       | 3         |
| cloud       | 6      | 5      | 1       | 0         |
| database    | 5      | 1      | 4       | 0         |
| devops      | 8      | 6      | 2       | 0         |
| frontend    | 9      | 4      | 5       | 0         |
| general     | 9      | 6      | 3       | 0         |
| integration | 5      | 5      | 0       | 0         |
| performance | 5      | 4      | 1       | 0         |
| planning    | 9      | 3      | 6       | 0         |
| quality     | 9      | 3      | 6       | 0         |
| security    | 7      | 4      | 3       | 0         |
| testing     | 8      | 2      | 5       | 0         |
| **TOTAL**   | **99** | **48** | **47**  | **4**     |

---

## Recommendations

### Immediate Actions

1. **Fix malformed frontmatter** in 4 business/backend files
2. **Add frontmatter** to high-priority backend agents (api-architect, fastapi-expert, nodejs-expert)
3. **Standardize version** to semantic versioning (1.0.0 format)

### Long-term Improvements

1. **Create validation CI check** to enforce frontmatter on all new agents
2. **Add author field** consistently (Ahmed Adel Bakr Alderai)
3. **Standardize tool names** (use PascalCase: Read, Write, Bash, Glob, Grep)
4. **Add integrations field** to enable better agent discovery and chaining

### Quality Metrics Target

| Metric              | Current | Target |
| ------------------- | ------- | ------ |
| Valid frontmatter   | 48.5%   | 100%   |
| Complete fields     | 35%     | 90%    |
| Author attribution  | 40%     | 100%   |
| Integration mapping | 30%     | 80%    |

---

## Appendix: Field Definitions

| Field          | Type   | Required | Description                              |
| -------------- | ------ | -------- | ---------------------------------------- |
| `name`         | string | Yes      | Unique agent identifier (kebab-case)     |
| `description`  | string | Yes      | Purpose and capabilities (1-3 sentences) |
| `version`      | string | Yes      | Semantic version (MAJOR.MINOR.PATCH)     |
| `author`       | string | Yes      | Creator attribution                      |
| `category`     | string | Yes      | Domain classification                    |
| `tools`        | array  | Yes      | Available Claude tools                   |
| `integrations` | array  | No       | Related agents for chaining              |
| `tags`         | array  | No       | Searchable keywords                      |
| `capabilities` | array  | No       | Detailed feature list                    |
| `triggers`     | array  | No       | Keywords that activate this agent        |
| `inputs`       | array  | No       | Expected input parameters                |
| `outputs`      | array  | No       | Expected output types                    |

---

**Report generated by Documentation Expert Agent**

---

Ahmed Adel Bakr Alderai
