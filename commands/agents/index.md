# Agent Index

> **Version:** 2.0.0 | **Updated:** 2026-01-21 | **Total Agents:** 95+

Comprehensive index of all specialized agents in the SDLC orchestration system. Use this guide to find the right agent for any task.

---

## Table of Contents

1. [Quick Navigation](#quick-navigation)
2. [Agent Selection Guide](#agent-selection-guide)
3. [Integration Map](#integration-map)
4. [Workflow Examples](#workflow-examples)
5. [Agent Categories](#agent-categories)
   - [General (Orchestration)](#general-agents)
   - [Planning](#planning-agents)
   - [Backend](#backend-agents)
   - [Frontend](#frontend-agents)
   - [Database](#database-agents)
   - [Testing](#testing-agents)
   - [Quality](#quality-agents)
   - [Security](#security-agents)
   - [Performance](#performance-agents)
   - [DevOps](#devops-agents)
   - [Cloud](#cloud-agents)
   - [AI/ML](#ai-ml-agents)
   - [Integration](#integration-agents)
   - [Business](#business-agents)
6. [Invocation Patterns](#invocation-patterns)
7. [Best Practices](#best-practices)

---

## Quick Navigation

| Category                           | Count | Primary Use Case                     | Key Agents                                                      |
| ---------------------------------- | ----- | ------------------------------------ | --------------------------------------------------------------- |
| [General](#general-agents)         | 10    | Orchestration, routing, coordination | `orchestrator`, `cascade-agent`, `model-router`                 |
| [Planning](#planning-agents)       | 9     | Architecture, requirements, specs    | `architect`, `product-manager`, `tech-lead`                     |
| [Backend](#backend-agents)         | 10    | API development, services            | `nodejs-expert`, `fastapi-expert`, `go-expert`                  |
| [Frontend](#frontend-agents)       | 10    | UI/UX, React, Vue, Next.js           | `react-expert`, `nextjs-expert`, `vue-expert`                   |
| [Database](#database-agents)       | 7     | SQL, NoSQL, migrations               | `postgresql-expert`, `mongodb-expert`, `redis-expert`           |
| [Testing](#testing-agents)         | 10    | Unit, E2E, integration               | `test-architect`, `unit-test-expert`, `e2e-test-expert`         |
| [Quality](#quality-agents)         | 11    | Code review, refactoring, docs       | `code-reviewer`, `refactoring-expert`, `documentation-expert`   |
| [Security](#security-agents)       | 8     | Audits, scanning, compliance         | `security-expert`, `vulnerability-scanner`, `compliance-expert` |
| [Performance](#performance-agents) | 5     | Caching, optimization                | `performance-optimizer`, `caching-expert`, `profiling-expert`   |
| [DevOps](#devops-agents)           | 11    | CI/CD, Docker, K8s                   | `ci-cd-expert`, `docker-expert`, `kubernetes-expert`            |
| [Cloud](#cloud-agents)             | 6     | AWS, GCP, Azure                      | `aws-expert`, `gcp-expert`, `azure-expert`                      |
| [AI/ML](#ai-ml-agents)             | 10    | LLM integration, ML pipelines        | `claude-opus-max`, `codex-max`, `gemini-deep`                   |
| [Integration](#integration-agents) | 5     | APIs, webhooks, MCP                  | `webhook-expert`, `mcp-expert`, `api-integration-expert`        |
| [Business](#business-agents)       | 4     | Cost, tracking, communication        | `cost-optimizer`, `project-tracker`, `stakeholder-communicator` |

---

## Agent Selection Guide

### By Task Type

| Task                         | Primary Agent                              | Backup Agent               | Model         |
| ---------------------------- | ------------------------------------------ | -------------------------- | ------------- |
| **New feature end-to-end**   | `cascade-agent`                            | `orchestrator`             | Auto          |
| **Architecture design**      | `architect`                                | `claude-opus-max`          | Opus          |
| **Complex debugging**        | `claude-opus-max`                          | `codex-max`                | Opus/Codex    |
| **Code implementation**      | `backend-developer` / `frontend-developer` | `codex-max`                | Sonnet/Codex  |
| **Code review**              | `code-reviewer`                            | `gemini-reviewer`          | Sonnet/Gemini |
| **Security audit**           | `security-expert`                          | `vulnerability-scanner`    | Opus          |
| **Database design**          | `database-architect`                       | `postgresql-expert`        | Sonnet        |
| **Test generation**          | `test-architect`                           | `unit-test-expert`         | Sonnet        |
| **Performance optimization** | `performance-optimizer`                    | `caching-expert`           | Sonnet        |
| **Documentation**            | `documentation-expert`                     | `gemini-deep`              | Gemini        |
| **CI/CD pipeline**           | `ci-cd-expert`                             | `github-actions-expert`    | Codex         |
| **Cloud infrastructure**     | `aws-expert` / `gcp-expert`                | `terraform-expert`         | Sonnet        |
| **Full codebase analysis**   | `gemini-deep`                              | `model-router`             | Gemini        |
| **Incident response**        | `incident-response-agent`                  | `stakeholder-communicator` | Sonnet        |

### By AI Model Strength

| Model               | Agent             | Context | Thinking       | Best For                                  |
| ------------------- | ----------------- | ------- | -------------- | ----------------------------------------- |
| **Claude Opus 4.5** | `claude-opus-max` | 200K    | 32K ultrathink | Architecture, security, critical bugs     |
| **GPT-5.2-Codex**   | `codex-max`       | 400K    | xhigh          | Project-scale refactoring, implementation |
| **Gemini 3 Pro**    | `gemini-deep`     | 1M      | high           | Full codebase analysis, documentation     |
| **Claude Sonnet**   | Most agents       | 200K    | 4K-10K         | Standard coding, 80% of tasks             |

### By Complexity Level

| Complexity        | Recommended Agent    | Context Size | Model  |
| ----------------- | -------------------- | ------------ | ------ |
| **Trivial**       | `pair-programmer`    | < 10K        | Sonnet |
| **Standard**      | `task-router` (auto) | 50K          | Sonnet |
| **Complex**       | `claude-opus-max`    | 150K         | Opus   |
| **Project-scale** | `codex-max`          | 400K         | Codex  |
| **Full codebase** | `gemini-deep`        | 1M           | Gemini |

---

## Integration Map

### How Agents Work Together

```
                                    ┌─────────────────────┐
                                    │    Orchestrator     │
                                    │   (Master Control)  │
                                    └──────────┬──────────┘
                                               │
                    ┌──────────────────────────┼──────────────────────────┐
                    │                          │                          │
                    ▼                          ▼                          ▼
           ┌───────────────┐          ┌───────────────┐          ┌───────────────┐
           │  Model Router │          │  Task Router  │          │   Cascade     │
           │ (AI Selection)│          │(Agent Select) │          │    Agent      │
           └───────┬───────┘          └───────┬───────┘          └───────┬───────┘
                   │                          │                          │
       ┌───────────┼───────────┐              │              ┌───────────┼───────────┐
       │           │           │              │              │           │           │
       ▼           ▼           ▼              ▼              ▼           ▼           ▼
  ┌─────────┐ ┌─────────┐ ┌─────────┐   ┌──────────┐   ┌──────────┐ ┌──────────┐ ┌──────────┐
  │ Claude  │ │  Codex  │ │ Gemini  │   │ Planning │   │ Backend  │ │ Frontend │ │ Testing  │
  │Opus Max │ │   Max   │ │  Deep   │   │  Agents  │   │  Agents  │ │  Agents  │ │  Agents  │
  └─────────┘ └─────────┘ └─────────┘   └──────────┘   └──────────┘ └──────────┘ └──────────┘
       │                                      │              │           │           │
       └──────────────────────────────────────┴──────────────┴───────────┴───────────┘
                                              │
                              ┌───────────────┴───────────────┐
                              │      Supporting Agents        │
                              ├───────────────────────────────┤
                              │ Security │ DevOps │ Quality  │
                              │  Cloud   │Database│ Business │
                              └───────────────────────────────┘
```

### Agent Collaboration Patterns

| Pattern          | Flow                                  | Use Case            |
| ---------------- | ------------------------------------- | ------------------- |
| **Cascade**      | Ticket → Spec → Implement → Test → PR | End-to-end features |
| **Parallel**     | Multiple agents on independent tasks  | Large features      |
| **Sequential**   | Agent A output → Agent B input        | Dependent tasks     |
| **Verification** | Implement (AI-1) → Verify (AI-2)      | Quality assurance   |
| **Consensus**    | 3 agents review → 2 must agree        | Critical decisions  |

### Tri-Agent Assignment Matrix

| Category          | Implementer | Reviewer 1 | Reviewer 2 |
| ----------------- | ----------- | ---------- | ---------- |
| **Security**      | Claude      | Codex      | Gemini     |
| **UI/Frontend**   | Codex       | Claude     | Gemini     |
| **Documentation** | Gemini      | Claude     | Codex      |
| **Complex Logic** | Claude      | Gemini     | Codex      |
| **Testing**       | Codex       | Gemini     | Claude     |
| **API/Backend**   | Codex       | Claude     | Gemini     |

---

## Workflow Examples

### Feature Development Workflow

```
1. Product Manager    → Creates PRD
       ↓
2. Architect          → Designs architecture (ADRs)
       ↓
3. Tech Lead          → Makes technical decisions
       ↓
4. Backend Developer  → Implements API
       ↓ (parallel)
5. Frontend Developer → Implements UI
       ↓
6. Test Architect     → Designs test strategy
       ↓
7. Security Expert    → Audits implementation
       ↓
8. Code Reviewer      → Reviews code
       ↓
9. CI/CD Expert       → Deploys to production
```

**Command Sequence:**

```bash
# Phase 1: Planning
/agents/planning/product-manager create PRD for user notification system
/agents/planning/architect design architecture for notification service

# Phase 2: Implementation
/agents/backend/nodejs-expert create NestJS module for notifications
/agents/frontend/react-expert create notification components

# Phase 3: Quality
/agents/testing/test-architect design test strategy for notifications
/agents/security/security-expert audit notification module
/agents/quality/code-reviewer review notification implementation

# Phase 4: Deploy
/agents/devops/ci-cd-expert configure deployment pipeline
```

### Bug Fix Workflow

```
1. Claude Opus Max    → Analyzes and diagnoses root cause
       ↓
2. Backend/Frontend   → Implements fix
       ↓
3. Unit Test Expert   → Adds regression tests
       ↓
4. Code Reviewer      → Reviews fix
       ↓
5. CI/CD Expert       → Deploys hotfix
```

**Command Sequence:**

```bash
/agents/ai-ml/claude-opus-max analyze and debug authentication timeout issue
/agents/backend/nodejs-expert implement fix for auth timeout
/agents/testing/unit-test-expert write regression tests for auth fix
/agents/quality/code-reviewer review auth fix implementation
```

### Security Audit Workflow

```
1. Security Expert          → Manual code audit (OWASP Top 10)
       ↓
2. Vulnerability Scanner    → Automated SAST/DAST
       ↓
3. Dependency Auditor       → Supply chain review
       ↓
4. Compliance Expert        → Compliance verification
       ↓
5. Stakeholder Communicator → Reports findings
```

**Command Sequence:**

```bash
/agents/security/security-expert audit authentication module for OWASP Top 10
/agents/security/vulnerability-scanner scan project dependencies
/agents/security/dependency-auditor audit supply chain security
/agents/security/compliance-expert verify GDPR compliance
/agents/business/stakeholder-communicator generate security report
```

### Database Migration Workflow

```
1. Database Architect  → Design new schema
       ↓
2. Migration Expert    → Create migration plan
       ↓
3. PostgreSQL Expert   → Optimize queries
       ↓
4. Performance Test    → Load test migrations
       ↓
5. Code Reviewer       → Review migration code
```

---

## Agent Categories

### General Agents

Orchestration, routing, and coordination agents that manage workflows.

| Agent                    | Path                                   | Key Capabilities                                               |
| ------------------------ | -------------------------------------- | -------------------------------------------------------------- |
| **Orchestrator**         | `/agents/general/orchestrator`         | Master workflow management, SDLC phase coordination            |
| **Model Router**         | `/agents/general/model-router`         | Intelligent routing to Claude/Codex/Gemini based on complexity |
| **Task Router**          | `/agents/general/task-router`          | Analyzes tasks, determines optimal agent and strategy          |
| **Cascade Agent**        | `/agents/general/cascade-agent`        | Ticket-to-PR automation, end-to-end features                   |
| **Parallel Coordinator** | `/agents/general/parallel-coordinator` | Git worktree management, parallel execution                    |
| **Pair Programmer**      | `/agents/general/pair-programmer`      | Real-time coding assistance, bug catching                      |
| **Context Manager**      | `/agents/general/context-manager`      | Project structure scanning, file dependencies                  |
| **Memory Coordinator**   | `/agents/general/memory-coordinator`   | Session memory, cross-agent context                            |
| **Session Manager**      | `/agents/general/session-manager`      | Session lifecycle, checkpoints, recovery                       |
| **Observability Agent**  | `/agents/general/observability-agent`  | System monitoring, metrics collection                          |

**Usage Examples:**

```bash
/agents/general/orchestrator implement user authentication with OAuth
/agents/general/cascade-agent github.com/org/repo/issues/42
/agents/general/parallel-coordinator implement login, signup, password reset in parallel
/agents/general/pair-programmer add debounce to search input
```

---

### Planning Agents

Requirements gathering, architecture design, and technical specifications.

| Agent                     | Path                                     | Key Capabilities                              |
| ------------------------- | ---------------------------------------- | --------------------------------------------- |
| **Architect**             | `/agents/planning/architect`             | System architecture, ADRs, component diagrams |
| **Product Manager**       | `/agents/planning/product-manager`       | PRDs, feature prioritization (MoSCoW, RICE)   |
| **Tech Lead**             | `/agents/planning/tech-lead`             | Technical decisions, coding standards         |
| **Requirements Analyst**  | `/agents/planning/requirements-analyst`  | User stories, acceptance criteria, NFRs       |
| **Requirements Analyzer** | `/agents/planning/requirements-analyzer` | Deep requirements analysis and validation     |
| **Tech Spec Writer**      | `/agents/planning/tech-spec-writer`      | Technical specifications, API contracts       |
| **Spec Generator**        | `/agents/planning/spec-generator`        | Auto-generate specs from requirements         |
| **Risk Assessor**         | `/agents/planning/risk-assessor`         | Risk identification, mitigation planning      |
| **UX Researcher**         | `/agents/planning/ux-researcher`         | User research, journey mapping, personas      |

**Usage Examples:**

```bash
/agents/planning/architect microservices architecture for e-commerce platform
/agents/planning/product-manager create PRD for notification system
/agents/planning/tech-lead decide between REST and GraphQL for new API
```

---

### Backend Agents

Server-side development, API design, and framework expertise.

| Agent                         | Path                                        | Key Capabilities                      |
| ----------------------------- | ------------------------------------------- | ------------------------------------- |
| **Backend Developer**         | `/agents/backend/backend-developer`         | General backend, API development      |
| **API Architect**             | `/agents/backend/api-architect`             | API design, OpenAPI specs, versioning |
| **Node.js Expert**            | `/agents/backend/nodejs-expert`             | Express/NestJS, TypeScript, Prisma    |
| **FastAPI Expert**            | `/agents/backend/fastapi-expert`            | Async Python, Pydantic, SQLAlchemy    |
| **Django Expert**             | `/agents/backend/django-expert`             | Django ORM, DRF, admin, signals       |
| **Rails Expert**              | `/agents/backend/rails-expert`              | Ruby on Rails, ActiveRecord, Hotwire  |
| **Go Expert**                 | `/agents/backend/go-expert`                 | Go concurrency, Gin/Echo, gRPC        |
| **GraphQL Specialist**        | `/agents/backend/graphql-specialist`        | Schema design, resolvers, federation  |
| **Microservices Architect**   | `/agents/backend/microservices-architect`   | Service decomposition, event-driven   |
| **Authentication Specialist** | `/agents/backend/authentication-specialist` | OAuth, JWT, OIDC, session management  |

**Usage Examples:**

```bash
/agents/backend/nodejs-expert create NestJS module for user management
/agents/backend/fastapi-expert create async CRUD API with SQLAlchemy
/agents/backend/microservices-architect design event-driven order processing
```

---

### Frontend Agents

Client-side development, UI frameworks, and user experience.

| Agent                       | Path                                       | Key Capabilities                       |
| --------------------------- | ------------------------------------------ | -------------------------------------- |
| **Frontend Developer**      | `/agents/frontend/frontend-developer`      | General frontend, responsive design    |
| **React Expert**            | `/agents/frontend/react-expert`            | React 18+, hooks, React Query          |
| **Vue Expert**              | `/agents/frontend/vue-expert`              | Vue 3, Composition API, Pinia          |
| **Next.js Expert**          | `/agents/frontend/nextjs-expert`           | App Router, Server Components          |
| **TypeScript Expert**       | `/agents/frontend/typescript-expert`       | Strict typing, generics, utility types |
| **CSS Expert**              | `/agents/frontend/css-expert`              | Tailwind, CSS Modules, animations      |
| **State Management Expert** | `/agents/frontend/state-management-expert` | Redux, Zustand, Jotai                  |
| **Mobile Web Expert**       | `/agents/frontend/mobile-web-expert`       | PWA, responsive, mobile-first          |
| **Accessibility Expert**    | `/agents/frontend/accessibility-expert`    | WCAG, ARIA, screen readers             |
| **Testing Frontend**        | `/agents/frontend/testing-frontend`        | React Testing Library, component tests |

**Usage Examples:**

```bash
/agents/frontend/react-expert create data table with sorting and filtering
/agents/frontend/nextjs-expert create dashboard with server components
/agents/frontend/accessibility-expert audit form components for WCAG 2.1 AA
```

---

### Database Agents

Database design, optimization, and migration specialists.

| Agent                     | Path                                     | Key Capabilities                            |
| ------------------------- | ---------------------------------------- | ------------------------------------------- |
| **Database Architect**    | `/agents/database/database-architect`    | Schema design, normalization, data modeling |
| **PostgreSQL Expert**     | `/agents/database/postgresql-expert`     | CTEs, window functions, EXPLAIN ANALYZE     |
| **MongoDB Expert**        | `/agents/database/mongodb-expert`        | Document modeling, aggregation pipelines    |
| **Redis Expert**          | `/agents/database/redis-expert`          | Caching patterns, pub/sub, data structures  |
| **ORM Expert**            | `/agents/database/orm-expert`            | Prisma, TypeORM, SQLAlchemy                 |
| **Migration Expert**      | `/agents/database/migration-expert`      | Zero-downtime migrations, schema versioning |
| **Migration Expert Full** | `/agents/database/migration-expert-full` | Complex multi-database migrations           |

**Usage Examples:**

```bash
/agents/database/postgresql-expert optimize slow query with EXPLAIN ANALYZE
/agents/database/mongodb-expert design schema for social media posts
/agents/database/migration-expert create zero-downtime migration plan
```

---

### Testing Agents

Test strategy, implementation, and quality assurance.

| Agent                       | Path                                      | Key Capabilities                        |
| --------------------------- | ----------------------------------------- | --------------------------------------- |
| **Test Architect**          | `/agents/testing/test-architect`          | Test strategy, pyramid design, coverage |
| **Unit Test Expert**        | `/agents/testing/unit-test-expert`        | Jest/Vitest/pytest, mocking, TDD        |
| **Integration Test Expert** | `/agents/testing/integration-test-expert` | API testing, database testing           |
| **E2E Test Expert**         | `/agents/testing/e2e-test-expert`         | Playwright/Cypress, page objects        |
| **API Test Expert**         | `/agents/testing/api-test-expert`         | REST/GraphQL testing, contracts         |
| **Performance Test Expert** | `/agents/testing/performance-test-expert` | Load testing, k6, stress testing        |
| **TDD Coach**               | `/agents/testing/tdd-coach`               | Test-first methodology                  |
| **Test Data Expert**        | `/agents/testing/test-data-expert`        | Fixtures, factories, realistic data     |
| **API Contract Agent**      | `/agents/testing/api-contract-agent`      | Pact testing, consumer-driven contracts |

**Usage Examples:**

```bash
/agents/testing/unit-test-expert write unit tests for payment service
/agents/testing/e2e-test-expert create E2E tests for checkout flow
/agents/testing/performance-test-expert create load test for 1000 concurrent users
```

---

### Quality Agents

Code quality, review, and technical debt management.

| Agent                      | Path                                     | Key Capabilities                       |
| -------------------------- | ---------------------------------------- | -------------------------------------- |
| **Code Reviewer**          | `/agents/quality/code-reviewer`          | Code quality, best practices, feedback |
| **Gemini Reviewer**        | `/agents/quality/gemini-reviewer`        | Large context review with Gemini       |
| **Refactoring Expert**     | `/agents/quality/refactoring-expert`     | Code smells, safe transformations      |
| **Documentation Expert**   | `/agents/quality/documentation-expert`   | API docs, README, JSDoc/TSDoc          |
| **Linting Expert**         | `/agents/quality/linting-expert`         | ESLint, Ruff, custom rules             |
| **Technical Debt Analyst** | `/agents/quality/technical-debt-analyst` | Debt identification, prioritization    |
| **Performance Analyst**    | `/agents/quality/performance-analyst`    | Code performance analysis              |
| **Product Analyst**        | `/agents/quality/product-analyst`        | Product metrics, feature impact        |
| **Dependency Manager**     | `/agents/quality/dependency-manager`     | Dependency updates, version management |
| **Doc Linter Agent**       | `/agents/quality/doc-linter-agent`       | Documentation quality checks           |
| **Semantic Search Agent**  | `/agents/quality/semantic-search-agent`  | Codebase semantic search               |

**Usage Examples:**

```bash
/agents/quality/code-reviewer review authentication module
/agents/quality/refactoring-expert refactor user service to reduce complexity
/agents/quality/documentation-expert generate API documentation for user endpoints
```

---

### Security Agents

Application security, compliance, and vulnerability management.

| Agent                           | Path                                           | Key Capabilities                    |
| ------------------------------- | ---------------------------------------------- | ----------------------------------- |
| **Security Expert**             | `/agents/security/security-expert`             | OWASP Top 10, secure coding         |
| **Vulnerability Scanner**       | `/agents/security/vulnerability-scanner`       | SAST, dependency scanning, CVEs     |
| **Penetration Tester**          | `/agents/security/penetration-tester`          | Security testing, attack simulation |
| **Compliance Expert**           | `/agents/security/compliance-expert`           | SOC2, GDPR, HIPAA                   |
| **Regulatory Compliance Agent** | `/agents/security/regulatory-compliance-agent` | Industry-specific regulations       |
| **Secrets Management Expert**   | `/agents/security/secrets-management-expert`   | Vault, AWS Secrets Manager          |
| **Dependency Auditor**          | `/agents/security/dependency-auditor`          | Supply chain security, SBOMs        |
| **Guardrails Agent**            | `/agents/security/guardrails-agent`            | Runtime security, input validation  |

**Usage Examples:**

```bash
/agents/security/security-expert audit authentication module for OWASP Top 10
/agents/security/vulnerability-scanner scan project dependencies
/agents/security/compliance-expert verify GDPR compliance for user data
```

---

### Performance Agents

Application performance optimization and caching.

| Agent                     | Path                                        | Key Capabilities                     |
| ------------------------- | ------------------------------------------- | ------------------------------------ |
| **Performance Optimizer** | `/agents/performance/performance-optimizer` | Profiling, bottleneck identification |
| **Caching Expert**        | `/agents/performance/caching-expert`        | Redis, CDN, cache invalidation       |
| **Profiling Expert**      | `/agents/performance/profiling-expert`      | CPU/memory profiling, flame graphs   |
| **Load Testing Expert**   | `/agents/performance/load-testing-expert`   | k6, Artillery, load profiles         |
| **Bundle Optimizer**      | `/agents/performance/bundle-optimizer`      | Webpack/Vite optimization            |

**Usage Examples:**

```bash
/agents/performance/performance-optimizer profile and optimize slow API endpoint
/agents/performance/caching-expert implement Redis caching for API responses
```

---

### DevOps Agents

CI/CD, containerization, infrastructure, and monitoring.

| Agent                           | Path                                         | Key Capabilities                        |
| ------------------------------- | -------------------------------------------- | --------------------------------------- |
| **DevOps Engineer**             | `/agents/devops/devops-engineer`             | General DevOps, automation              |
| **CI/CD Expert**                | `/agents/devops/ci-cd-expert`                | GitHub Actions, GitLab CI, Jenkins      |
| **GitHub Actions Expert**       | `/agents/devops/github-actions-expert`       | Workflow optimization, reusable actions |
| **Docker Expert**               | `/agents/devops/docker-expert`               | Dockerfiles, compose, multi-stage       |
| **Kubernetes Expert**           | `/agents/devops/kubernetes-expert`           | K8s manifests, Helm, operators          |
| **Terraform Expert**            | `/agents/devops/terraform-expert`            | IaC, modules, state management          |
| **Infrastructure Architect**    | `/agents/devops/infrastructure-architect`    | Cloud architecture, scalability         |
| **Monitoring Expert**           | `/agents/devops/monitoring-expert`           | Prometheus, Grafana, alerting           |
| **Incident Response Agent**     | `/agents/devops/incident-response-agent`     | Incident management, postmortems        |
| **Self-Healing Pipeline Agent** | `/agents/devops/self-healing-pipeline-agent` | Auto-remediation, resilience            |

**Usage Examples:**

```bash
/agents/devops/ci-cd-expert design GitHub Actions pipeline for Node.js monorepo
/agents/devops/docker-expert create optimized Dockerfile for Node.js app
/agents/devops/kubernetes-expert create Kubernetes deployment with autoscaling
```

---

### Cloud Agents

Cloud platform specialists for AWS, GCP, and Azure.

| Agent                     | Path                                  | Key Capabilities                      |
| ------------------------- | ------------------------------------- | ------------------------------------- |
| **AWS Expert**            | `/agents/cloud/aws-expert`            | EC2, Lambda, ECS, RDS, IAM            |
| **GCP Expert**            | `/agents/cloud/gcp-expert`            | Compute Engine, Cloud Run, BigQuery   |
| **GCP Expert Full**       | `/agents/cloud/gcp-expert-full`       | Comprehensive GCP services            |
| **Azure Expert**          | `/agents/cloud/azure-expert`          | VMs, Functions, AKS, Azure SQL        |
| **Multi-Cloud Expert**    | `/agents/cloud/multi-cloud-expert`    | Cross-cloud strategies, portability   |
| **Multi-Cloud Architect** | `/agents/cloud/multi-cloud-architect` | Multi-cloud architecture design       |
| **Serverless Expert**     | `/agents/cloud/serverless-expert`     | Lambda, Cloud Functions, event-driven |

**Usage Examples:**

```bash
/agents/cloud/aws-expert design serverless architecture with Lambda and API Gateway
/agents/cloud/gcp-expert deploy Cloud Run service with Cloud SQL
/agents/cloud/serverless-expert implement event-driven image processing pipeline
```

---

### AI/ML Agents

Machine learning, LLM integration, and AI model management.

| Agent                      | Path                                   | Key Capabilities                        |
| -------------------------- | -------------------------------------- | --------------------------------------- |
| **Claude Opus Max**        | `/agents/ai-ml/claude-opus-max`        | 32K ultrathink, architecture, debugging |
| **Codex Max**              | `/agents/ai-ml/codex-max`              | 400K context, project-scale refactoring |
| **Gemini Deep**            | `/agents/ai-ml/gemini-deep`            | 1M context, full codebase analysis      |
| **ML Engineer**            | `/agents/ai-ml/ml-engineer`            | ML pipelines, MLOps, model deployment   |
| **LLM Integration Expert** | `/agents/ai-ml/llm-integration-expert` | OpenAI/Anthropic APIs, RAG              |
| **RAG Expert**             | `/agents/ai-ml/rag-expert`             | Retrieval-Augmented Generation          |
| **LLMOps Agent**           | `/agents/ai-ml/llmops-agent`           | LLM deployment, monitoring              |
| **Prompt Engineer**        | `/agents/ai-ml/prompt-engineer`        | Prompt design, optimization             |
| **LangChain Expert**       | `/agents/ai-ml/langchain-expert`       | LangChain/LangGraph applications        |
| **Quality Metrics Agent**  | `/agents/ai-ml/quality-metrics-agent`  | AI output quality measurement           |

**Usage Examples:**

```bash
/agents/ai-ml/claude-opus-max design distributed event-driven architecture for 10M events/second
/agents/ai-ml/codex-max refactor authentication system from session-based to JWT
/agents/ai-ml/gemini-deep analyze entire microservices architecture across 12 repositories
```

---

### Integration Agents

Third-party integrations, webhooks, and MCP servers.

| Agent                       | Path                                          | Key Capabilities                    |
| --------------------------- | --------------------------------------------- | ----------------------------------- |
| **API Integration Expert**  | `/agents/integration/api-integration-expert`  | Third-party API integration         |
| **Webhook Expert**          | `/agents/integration/webhook-expert`          | Signature verification, idempotency |
| **Third-Party API Expert**  | `/agents/integration/third-party-api-expert`  | Payment, email, SMS integrations    |
| **MCP Expert**              | `/agents/integration/mcp-expert`              | Model Context Protocol servers      |
| **API Observability Agent** | `/agents/integration/api-observability-agent` | API monitoring, tracing             |

**Usage Examples:**

```bash
/agents/integration/webhook-expert implement Stripe webhook handler with idempotency
/agents/integration/mcp-expert create TypeScript MCP server for Jira integration
/agents/integration/api-integration-expert integrate Twilio for SMS notifications
```

---

### Business Agents

Cost optimization, project tracking, and stakeholder communication.

| Agent                        | Path                                        | Key Capabilities                         |
| ---------------------------- | ------------------------------------------- | ---------------------------------------- |
| **Cost Optimizer**           | `/agents/business/cost-optimizer`           | Cloud cost analysis, reserved instances  |
| **Project Tracker**          | `/agents/business/project-tracker`          | Sprint tracking, velocity, milestones    |
| **Stakeholder Communicator** | `/agents/business/stakeholder-communicator` | Status reports, release notes, incidents |
| **Business Analyst**         | `/agents/business/business-analyst`         | Business requirements, process analysis  |

**Usage Examples:**

```bash
/agents/business/cost-optimizer analyze AWS costs and create optimization plan
/agents/business/stakeholder-communicator exec-report --project "Platform Migration"
/agents/business/project-tracker sprint-report --sprint 12
```

---

## Invocation Patterns

### Basic Invocation

```bash
/agents/<category>/<agent-name> <task-description>
```

### Via Task Tool

```typescript
Use the Task tool with subagent_type="<agent-name>" to:
1. [Capability 1]
2. [Capability 2]
Task: <your-task>
```

### Chained Invocation

```bash
# Planning → Implementation → Testing → Review
/agents/planning/architect design auth system
/agents/backend/nodejs-expert implement auth service
/agents/testing/unit-test-expert write tests for auth
/agents/quality/code-reviewer review auth implementation
```

### Parallel Invocation

```bash
/agents/general/parallel-coordinator [
  "backend: implement user API",
  "frontend: create user form",
  "testing: write API tests"
]
```

### Model-Specific Invocation

```bash
# For architecture (use Opus)
/agents/ai-ml/claude-opus-max <complex-architecture-task>

# For large refactoring (use Codex)
/agents/ai-ml/codex-max <project-scale-refactoring>

# For codebase analysis (use Gemini)
/agents/ai-ml/gemini-deep <full-codebase-analysis>
```

---

## Best Practices

### Agent Selection

1. **Start with routing** - Use `model-router` or `task-router` for uncertain complexity
2. **Match expertise** - Choose framework-specific agents (e.g., `nextjs-expert` for Next.js)
3. **Consider context** - Use `gemini-deep` for large codebase analysis (>100K tokens)
4. **Security first** - Always include `security-expert` for auth/payment code

### Workflow Optimization

1. **Cascade for features** - Use `cascade-agent` for end-to-end feature implementation
2. **Parallel for independence** - Use `parallel-coordinator` for unrelated tasks
3. **Verify with different AI** - Assign different model for verification than implementation
4. **Sequential for dependencies** - Backend before frontend, types before components

### Quality Gates

| Gate                  | Required Agent     | Trigger                       |
| --------------------- | ------------------ | ----------------------------- |
| Code Review           | `code-reviewer`    | All PRs                       |
| Security Review       | `security-expert`  | Auth, payment, sensitive code |
| Architecture Review   | `architect`        | Architecture changes          |
| Multi-Agent Consensus | 3 different agents | Critical decisions            |

### Troubleshooting

| Issue                | Solution                                                   |
| -------------------- | ---------------------------------------------------------- |
| Agent timeout        | Use `gemini-deep` for large context, split task for others |
| Wrong model selected | Use `model-router` explicitly with complexity hint         |
| Missing context      | Use `context-manager` to load project structure first      |
| Inconsistent output  | Specify output format in task description                  |
| Agent unavailable    | Check failover chain in `model-router`                     |

---

## Quick Reference Commands

### Orchestration

```bash
/agents/general/orchestrator <task>
/agents/general/cascade-agent <ticket-url>
/agents/general/model-router <task>
```

### Planning

```bash
/agents/planning/architect <system-description>
/agents/planning/product-manager create PRD for <feature>
/agents/planning/tech-lead <technical-decision>
```

### Development

```bash
/agents/backend/nodejs-expert <node-task>
/agents/backend/fastapi-expert <python-task>
/agents/frontend/react-expert <react-task>
```

### Quality

```bash
/agents/quality/code-reviewer review <module>
/agents/testing/unit-test-expert write tests for <module>
/agents/security/security-expert audit <module>
```

### DevOps

```bash
/agents/devops/ci-cd-expert design pipeline for <project>
/agents/devops/docker-expert create Dockerfile for <app>
/agents/devops/kubernetes-expert deploy <service>
```

### AI-Powered

```bash
/agents/ai-ml/claude-opus-max <complex-task>
/agents/ai-ml/codex-max <large-refactoring>
/agents/ai-ml/gemini-deep <full-codebase-analysis>
```

---

## Version History

| Version | Date       | Changes                                                   |
| ------- | ---------- | --------------------------------------------------------- |
| 2.0.0   | 2026-01-21 | Added integration map, workflow examples, selection guide |
| 1.0.0   | 2026-01-15 | Initial comprehensive index                               |

---

**Maintained by:** Ahmed Adel Bakr Alderai
**Location:** `/home/aadel/.claude/commands/agents/index.md`
