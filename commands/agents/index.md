# Claude Agent Index

A comprehensive guide to the specialized agents available in the Claude CLI ecosystem.

## Quick Reference

| Category | Agent | Primary Capability |
|----------|-------|-------------------|
| AI & Machine Learning | [Claude Opus Max Agent](#claude-opus-max) | Maximum-powered Claude Code agent using Opus 4.5 with ultrathink (32K token thin... |
| AI & Machine Learning | [Codex Max Agent](#codex-max) | Maximum-powered Codex CLI agent using GPT-5.2-Codex with xhigh reasoning effort ... |
| AI & Machine Learning | [Gemini Deep Agent](#gemini-deep) | Maximum-powered Gemini CLI agent using Gemini 3 Pro with Deep Think mode for com... |
| AI & Machine Learning | [LangChain Expert](#langchain-expert) | Specialized agent for designing, implementing, and optimizing LangChain and Lang... |
| AI & Machine Learning | [LLM Integration Expert Agent](#llm-integration-expert) | LLM integration specialist. Expert in OpenAI, Anthropic APIs, RAG, and prompt en... |
| AI & Machine Learning | [LLMOps Agent](#llmops-agent) | Specialized agent for end-to-end LLM lifecycle management, including fine-tuning... |
| AI & Machine Learning | [ML Engineer Agent](#ml-engineer) | Machine learning engineering specialist. Expert in ML pipelines, model deploymen... |
| AI & Machine Learning | [Prompt Engineer](#prompt-engineer) | Specialized agent for designing, optimizing, and securing LLM prompts |
| AI & Machine Learning | [AI Quality Metrics Agent](#quality-metrics-agent) | Specialized agent for measuring, analyzing, and improving AI output quality thro... |
| AI & Machine Learning | [rag-expert](#rag-expert) | Vector store and RAG optimization agent focusing on chunking, embeddings, retrie... |
| Backend Development | [API Architect Agent](#api-architect) | Designs and documents REST/GraphQL APIs. Creates OpenAPI specs and API contracts... |
| Backend Development | [Authentication Specialist Agent](#authentication-specialist) | Authentication and authorization specialist. Expert in JWT, OAuth, RBAC, and sec... |
| Backend Development | [Backend Developer Agent](#backend-developer) | General backend development expert. Implements APIs, services, and server-side l... |
| Backend Development | [Django Expert Agent](#django-expert) | Django and Django REST Framework specialist. Expert in Python web development wi... |
| Backend Development | [FastAPI Expert Agent](#fastapi-expert) | FastAPI framework specialist. Expert in async Python, Pydantic, dependency injec... |
| Backend Development | [Go Expert Agent](#go-expert) | Go/Golang specialist. Expert in Go web services, concurrency, and idiomatic Go p... |
| Backend Development | [GraphQL Specialist Agent](#graphql-specialist) | GraphQL API design and implementation specialist. Expert in schema design, resol... |
| Backend Development | [Microservices Architect Agent](#microservices-architect) | Microservices architecture specialist. Expert in service decomposition, communic... |
| Backend Development | [Node.js Expert Agent](#nodejs-expert) | Node.js and Express/NestJS specialist. Expert in TypeScript, async patterns, and... |
| Backend Development | [Rails Expert Agent](#rails-expert) | Ruby on Rails specialist. Expert in Rails conventions, ActiveRecord, and Ruby be... |
| Business & Planning | [Business Analyst Agent](#business-analyst) | tools: |
| Business & Planning | [Cloud Cost Optimizer Agent](#cost-optimizer) | Specialized agent for multi-cloud and AI cost optimization, including reserved i... |
| Business & Planning | [Project Tracker Agent](#project-tracker) | tools: |
| Business & Planning | [Stakeholder Communicator Agent](#stakeholder-communicator) | tools: |
| Cloud & Infrastructure | [AWS Expert Agent](#aws-expert) | AWS cloud specialist. Expert in AWS services, architecture, and best practices. |
| Cloud & Infrastructure | [Azure Expert Agent](#azure-expert) | Azure cloud specialist. Expert in Microsoft Azure services, architecture, automa... |
| Cloud & Infrastructure | [GCP Expert Agent](#gcp-expert-full) | A specialized agent for Google Cloud Platform architecture, implementation, and ... |
| Cloud & Infrastructure | [GCP Expert Agent](#gcp-expert) | Google Cloud Platform specialist. Expert in GCP services and architecture. |
| Cloud & Infrastructure | [Multi-Cloud Expert Agent](#multi-cloud-architect) | You are the **Multi-Cloud Architect**, an expert AI agent specializing in design... |
| Cloud & Infrastructure | [Multi-Cloud Expert Agent](#multi-cloud-expert) | Multi-cloud architecture specialist. Expert in cross-cloud strategies and portab... |
| Cloud & Infrastructure | [Serverless Expert Agent](#serverless-expert) | name: serverless-expert |
| Database Engineering | [Database Architect Agent](#database-architect) | Database architecture specialist. Expert in schema design, normalization, indexi... |
| Database Engineering | [Migration Expert Agent (Full)](#migration-expert-full) | Database migration specialist. Expert in zero-downtime schema evolution, data ba... |
| Database Engineering | [Migration Expert Agent](#migration-expert) | Database migration specialist. Expert in schema evolution, zero-downtime migrati... |
| Database Engineering | [MongoDB Expert Agent](#mongodb-expert) | MongoDB specialist. Expert in document modeling, aggregation, indexing, and Mong... |
| Database Engineering | [ORM Expert Agent](#orm-expert) | ORM specialist. Expert in Prisma, SQLAlchemy, TypeORM, and database abstraction ... |
| Database Engineering | [PostgreSQL Expert Agent](#postgresql-expert) | PostgreSQL specialist. Expert in PG features, performance tuning, extensions, an... |
| Database Engineering | [Redis Expert Agent](#redis-expert) | Redis specialist. Expert in caching, data structures, pub/sub, and Redis pattern... |
| DevOps & SRE | [CI/CD Expert Agent](#ci-cd-expert) | Comprehensive CI/CD specialist for pipeline design, build automation, deployment... |
| DevOps & SRE | [DevOps Engineer Agent](#devops-engineer) | DevOps specialist. Expert in CI/CD, infrastructure automation, and deployment st... |
| DevOps & SRE | [Docker Expert Agent](#docker-expert) | Docker and containerization specialist. Expert in Docker, Docker Compose, and co... |
| DevOps & SRE | [GitHub Actions Expert Agent](#github-actions-expert) | > |
| DevOps & SRE | [Production Incident Response Agent](#incident-response-agent) | Comprehensive production incident management specialist for incident detection, ... |
| DevOps & SRE | [Infrastructure Architect Agent](#infrastructure-architect) | name: infrastructure-architect |
| DevOps & SRE | [Kubernetes Expert Agent](#kubernetes-expert) | Kubernetes specialist. Expert in K8s resources, deployments, and cluster managem... |
| DevOps & SRE | [Monitoring Expert Agent](#monitoring-expert) | Monitoring and observability specialist. Expert in Prometheus, Grafana, and logg... |
| DevOps & SRE | [Self-Healing Pipeline Agent](#self-healing-pipeline-agent) | Autonomous agent for detecting, analyzing, and fixing CI/CD pipeline failures |
| DevOps & SRE | [Terraform Expert Agent](#terraform-expert) | Terraform and IaC specialist. Expert in Terraform modules, state management, and... |
| Frontend Development | [Accessibility Expert Agent](#accessibility-expert) | Web accessibility specialist. Expert in WCAG, ARIA, screen readers, and inclusiv... |
| Frontend Development | [CSS Expert Agent](#css-expert) | CSS and styling specialist. Expert in CSS, Tailwind, CSS-in-JS, animations, and ... |
| Frontend Development | [Frontend Developer Agent](#frontend-developer) | General frontend development specialist. Expert in modern web development, respo... |
| Frontend Development | [Mobile Web Expert Agent](#mobile-web-expert) | Mobile web and PWA specialist. Expert in responsive design, PWA, mobile performa... |
| Frontend Development | [Next.js Expert Agent](#nextjs-expert) | Next.js specialist. Expert in App Router, Server Components, SSR/SSG, and Next.j... |
| Frontend Development | [React Expert Agent](#react-expert) | React.js specialist. Expert in React patterns, hooks, state management, and Reac... |
| Frontend Development | [State Management Expert Agent](#state-management-expert) | State management specialist. Expert in Redux, Zustand, Jotai, React Query, and s... |
| Frontend Development | [Frontend Testing Agent](#testing-frontend) | Frontend testing specialist. Expert in Jest, Testing Library, Playwright, and co... |
| Frontend Development | [TypeScript Expert Agent](#typescript-expert) | TypeScript specialist. Expert in type systems, generics, advanced patterns, and ... |
| Frontend Development | [Vue Expert Agent](#vue-expert) | Vue.js specialist. Expert in Vue 3, Composition API, Pinia, and Vue ecosystem. |
| General Purpose & Orchestration | [Cascade Agent](#cascade-agent) | End-to-end automation of the ticket-to-PR workflow. Orchestrates specialized age... |
| General Purpose & Orchestration | [Context Manager Agent](#context-manager) | Manages project context, loads relevant files, and maintains awareness of the cu... |
| General Purpose & Orchestration | [Memory Coordinator Agent](#memory-coordinator) | Coordinates memory systems including vector memory, project ledger, and error kn... |
| General Purpose & Orchestration | [model-router](#model-router) | Intelligent orchestrator that routes tasks to the optimal AI model (Claude, Code... |
| General Purpose & Orchestration | [observability-agent](#observability-agent) | An agent designed to trace, monitor, and report on the performance, cost, and qu... |
| General Purpose & Orchestration | [Orchestrator Agent](#orchestrator) | Master workflow orchestrator that coordinates all SDLC phases and delegates to s... |
| General Purpose & Orchestration | [pair-programmer](#pair-programmer) | Interactive pair programmer for real-time coding assistance, incremental edits, ... |
| General Purpose & Orchestration | [Parallel Coordinator Agent](#parallel-coordinator) | Coordinates parallel execution of independent tasks using git worktrees or isola... |
| General Purpose & Orchestration | [Session Manager Agent](#session-manager) | Manages session state, progress tracking, and ensures continuity across conversa... |
| General Purpose & Orchestration | [Task Router Agent](#task-router) | Intelligent task routing agent that analyzes tasks and determines the optimal ag... |
| Integration & APIs | [API Integration Expert Agent](#api-integration-expert) | API integration specialist. Expert in REST, webhooks, OAuth, and third-party int... |
| Integration & APIs | [api-observability-agent](#api-observability-agent) | Monitors API health, performance, and reliability. Tracks latency percentiles, e... |
| Integration & APIs | [MCP Integration Expert Agent](#mcp-expert) | Model Context Protocol specialist for server development, tool patterns, and AI ... |
| Integration & APIs | [Third-Party API Expert](#third-party-api-expert) | Expert in external API integrations including OAuth, rate limiting, webhooks, an... |
| Integration & APIs | [Webhook Expert Agent](#webhook-expert) | "Target framework (express, fastapi, flask, django)" |
| Performance Engineering | [Bundle Optimizer Agent](#bundle-optimizer) | Expert in JavaScript/TypeScript bundle optimization for Webpack, Vite, and esbui... |
| Performance Engineering | [Caching Expert Agent](#caching-expert) | Caching specialist. Expert in cache strategies, Redis, CDN, and cache invalidati... |
| Performance Engineering | [load-testing-expert](#load-testing-expert) | Load testing expert for k6 and Artillery. Designs tests, configures load profile... |
| Performance Engineering | [Performance Optimizer Agent](#performance-optimizer) | Performance optimization specialist. Expert in code optimization, caching, and p... |
| Performance Engineering | [Profiling Expert Agent](#profiling-expert) | > |
| Planning & Architecture | [Architect Agent](#architect) | Designs system architecture, creates technical specifications, and makes archite... |
| Planning & Architecture | [Exponential Planner Agent](#exponential-planner) | Strategic long-term planner that creates comprehensive multi-phase development p... |
| Planning & Architecture | [Product Manager Agent](#product-manager) | Creates PRDs (Product Requirements Documents), prioritizes features, and manages... |
| Planning & Architecture | [Requirements Analyst Agent](#requirements-analyst) | Gathers, analyzes, and documents requirements. Creates user stories with accepta... |
| Planning & Architecture | [Requirements Analyzer Agent](#requirements-analyzer) | **Role:** You are the **Requirements Analyzer**, a specialized sub-agent respons... |
| Planning & Architecture | [Risk Assessor Agent](#risk-assessor) | Identifies, analyzes, and documents risks in software projects. Creates risk mat... |
| Planning & Architecture | [spec-generator](#spec-generator) | Generates formal, testable specifications, API contracts, and test scenarios fro... |
| Planning & Architecture | [Tech Lead Agent](#tech-lead) | Provides technical leadership, makes implementation decisions, and guides develo... |
| Planning & Architecture | [Tech Spec Writer Agent](#tech-spec-writer) | Creates detailed technical specifications from requirements. Translates business... |
| Planning & Architecture | [UX Researcher Agent](#ux-researcher) | Conducts UX research, creates user personas, and designs user journeys. |
| Quality Assurance & Code Quality | [Code Reviewer Agent](#code-reviewer) | Code review specialist. Expert in code quality, best practices, and constructive... |
| Quality Assurance & Code Quality | [Dependency Manager Agent](#dependency-manager) | Purpose: Manage project dependencies with clear, actionable guidance. |
| Quality Assurance & Code Quality | [Documentation Linter Agent](#doc-linter-agent) | You are the Documentation Linter Agent. You validate documentation quality and c... |
| Quality Assurance & Code Quality | [Documentation Expert Agent](#documentation-expert) | Documentation specialist. Expert in API docs, code comments, and technical writi... |
| Quality Assurance & Code Quality | [Gemini Reviewer Agent](#gemini-reviewer) | Gemini-powered code reviewer using CLI. Expert in security analysis, code qualit... |
| Quality Assurance & Code Quality | [Linting Expert Agent](#linting-expert) | Linting and formatting specialist. Expert in ESLint, Prettier, and code style en... |
| Quality Assurance & Code Quality | [Performance Analyst Agent](#performance-analyst) | Performance analysis specialist. Expert in profiling, bottleneck identification,... |
| Quality Assurance & Code Quality | [Product Analyst Agent](#product-analyst) | Product analysis specialist. Expert in requirements gathering, user stories, and... |
| Quality Assurance & Code Quality | [Refactoring Expert Agent](#refactoring-expert) | Code refactoring specialist. Expert in refactoring patterns, code smells, and sa... |
| Quality Assurance & Code Quality | [Semantic Code Search Agent](#semantic-search-agent) | You are the **Semantic Code Search Agent**, a specialized sub-agent responsible ... |
| Quality Assurance & Code Quality | [Technical Debt Analyst Agent](#technical-debt-analyst) | Technical debt specialist. Expert in debt identification, prioritization, and re... |
| Security & Compliance | [Compliance Expert Agent](#compliance-expert) | Security compliance specialist. Expert in SOC2, GDPR, HIPAA, and compliance fram... |
| Security & Compliance | [Dependency Auditor Agent](#dependency-auditor) | Dependency security auditor. Expert in supply chain security and dependency mana... |
| Security & Compliance | ["Guardrails Enforcement Agent"](#guardrails-agent) | "Security compliance agent responsible for pre-execution validation of tool call... |
| Security & Compliance | [Penetration Testing Agent](#penetration-tester) | Penetration testing specialist for authorized security testing, CTF challenges, ... |
| Security & Compliance | [regulatory-compliance-agent](#regulatory-compliance-agent) | Specialized security agent for auditing and ensuring compliance with AI and data... |
| Security & Compliance | [Secrets Management Expert Agent](#secrets-management-expert) | Secrets management specialist. Expert in vault systems, environment variables, a... |
| Security & Compliance | [Security Expert Agent](#security-expert) | Application security specialist. Expert in OWASP Top 10, secure coding, and vuln... |
| Security & Compliance | [Vulnerability Scanner Agent](#vulnerability-scanner) | Vulnerability scanning specialist. Expert in dependency scanning, SAST, and secu... |
| Testing & QA | ["API Contract Testing Agent"](#api-contract-agent) | "Specialized agent for API contract validation, consumer-driven contract testing... |
| Testing & QA | [API Test Expert Agent](#api-test-expert) | API testing specialist. Expert in REST/GraphQL testing, contract testing, and AP... |
| Testing & QA | [E2E Test Expert Agent](#e2e-test-expert) | End-to-end testing specialist. Expert in Playwright, Cypress, and full system te... |
| Testing & QA | [Integration Test Expert Agent](#integration-test-expert) | Integration testing specialist. Expert in API testing, database testing, and ser... |
| Testing & QA | [Performance Test Expert Agent](#performance-test-expert) | Performance testing specialist. Expert in load testing, stress testing, and perf... |
| Testing & QA | [TDD Coach Agent](#tdd-coach) | TDD coaching specialist. Expert in test-driven development, red-green-refactor c... |
| Testing & QA | [Test Architect Agent](#test-architect) | Test architecture specialist. Expert in test strategy, pyramid design, and testi... |
| Testing & QA | [Test Data Expert Agent](#test-data-expert) | Test data management specialist. Expert in fixtures, factories, and test data st... |
| Testing & QA | [Unit Test Expert Agent](#unit-test-expert) | Unit testing specialist. Expert in mocking, test isolation, TDD, and unit test p... |

---

## AI & Machine Learning

### <a id='claude-opus-max'></a>Claude Opus Max Agent

**Description:** Maximum-powered Claude Code agent using Opus 4.5 with ultrathink (32K token thinking budget) and high effort for the most complex tasks.

**When to Use:**
Use the `Claude Opus Max Agent` when you need maximum-powered claude code agent using opus 4.5 with ultrathink (32k token thinking budget) and high effort for the most complex tasks..

**Usage:**
```bash
/agent run ai-ml/claude-opus-max.md <instructions>
```

**Related Agents:**
[Codex Max Agent](#codex-max), [Gemini Deep Agent](#gemini-deep), [LangChain Expert](#langchain-expert)

---

### <a id='codex-max'></a>Codex Max Agent

**Description:** Maximum-powered Codex CLI agent using GPT-5.2-Codex with xhigh reasoning effort for project-scale coding tasks.

**When to Use:**
Use the `Codex Max Agent` when you need maximum-powered codex cli agent using gpt-5.2-codex with xhigh reasoning effort for project-scale coding tasks..

**Usage:**
```bash
/agent run ai-ml/codex-max.md <instructions>
```

**Related Agents:**
[Claude Opus Max Agent](#claude-opus-max), [Gemini Deep Agent](#gemini-deep), [LangChain Expert](#langchain-expert)

---

### <a id='gemini-deep'></a>Gemini Deep Agent

**Description:** Maximum-powered Gemini CLI agent using Gemini 3 Pro with Deep Think mode for comprehensive research and analysis with 1M token context.

**When to Use:**
Use the `Gemini Deep Agent` when you need maximum-powered gemini cli agent using gemini 3 pro with deep think mode for comprehensive research and analysis with 1m token context..

**Usage:**
```bash
/agent run ai-ml/gemini-deep.md <instructions>
```

**Related Agents:**
[Claude Opus Max Agent](#claude-opus-max), [Codex Max Agent](#codex-max), [LangChain Expert](#langchain-expert)

---

### <a id='langchain-expert'></a>LangChain Expert

**Description:** Specialized agent for designing, implementing, and optimizing LangChain and LangGraph applications, focusing on RAG, agentic workflows, and production deployment.

**When to Use:**
Use the `LangChain Expert` when you need specialized agent for designing, implementing, and optimizing langchain and langgraph applications, focusing on rag, agentic workflows, and production deployment..

**Usage:**
```bash
/agent run ai-ml/langchain-expert.md <instructions>
```

**Related Agents:**
[Claude Opus Max Agent](#claude-opus-max), [Codex Max Agent](#codex-max), [Gemini Deep Agent](#gemini-deep)

---

### <a id='llm-integration-expert'></a>LLM Integration Expert Agent

**Description:** LLM integration specialist. Expert in OpenAI, Anthropic APIs, RAG, and prompt engineering.

**When to Use:**
Use the `LLM Integration Expert Agent` when you need llm integration specialist. expert in openai, anthropic apis, rag, and prompt engineering..

**Usage:**
```bash
/agent run ai-ml/llm-integration-expert.md <instructions>
```

**Related Agents:**
[Claude Opus Max Agent](#claude-opus-max), [Codex Max Agent](#codex-max), [Gemini Deep Agent](#gemini-deep)

---

### <a id='llmops-agent'></a>LLMOps Agent

**Description:** Specialized agent for end-to-end LLM lifecycle management, including fine-tuning, evaluation, deployment, and monitoring.

**When to Use:**
Use the `LLMOps Agent` when you need specialized agent for end-to-end llm lifecycle management, including fine-tuning, evaluation, deployment, and monitoring..

**Usage:**
```bash
/agent run ai-ml/llmops-agent.md <instructions>
```

**Related Agents:**
[Claude Opus Max Agent](#claude-opus-max), [Codex Max Agent](#codex-max), [Gemini Deep Agent](#gemini-deep)

---

### <a id='ml-engineer'></a>ML Engineer Agent

**Description:** Machine learning engineering specialist. Expert in ML pipelines, model deployment, and MLOps.

**Key Capabilities:**
- Scikit-learn, PyTorch, TensorFlow
- MLflow, Kubeflow
- Feature stores
- Model serving (FastAPI, TF Serving)
- A/B testing for models

**When to Use:**
Use the `ML Engineer Agent` when you need machine learning engineering specialist. expert in ml pipelines, model deployment, and mlops..

**Usage:**
```bash
/agent run ai-ml/ml-engineer.md <instructions>
```

**Related Agents:**
[Claude Opus Max Agent](#claude-opus-max), [Codex Max Agent](#codex-max), [Gemini Deep Agent](#gemini-deep)

---

### <a id='prompt-engineer'></a>Prompt Engineer

**Description:** Specialized agent for designing, optimizing, and securing LLM prompts.

**Key Capabilities:**
- Prompt Design Patterns (Few-Shot, CoT, ReAct)
- System Prompt Templates & Persona Design
- Prompt Optimization & A/B Testing strategies
- Security & Prompt Injection Prevention
- Token usage optimization
- Multi-model adaptation (Claude, GPT, Gemini)

**When to Use:**
Use the `Prompt Engineer` when you need to design high-performance prompts, optimize existing prompts for cost/quality, secure prompts against injection, or adapt prompts for different LLM architectures.

**Usage:**
```bash
/agent run ai-ml/prompt-engineer.md <instructions>
```

**Related Agents:**
[Claude Opus Max Agent](#claude-opus-max), [Codex Max Agent](#codex-max), [Gemini Deep Agent](#gemini-deep)

---

### <a id='quality-metrics-agent'></a>AI Quality Metrics Agent

**Description:** Specialized agent for measuring, analyzing, and improving AI output quality through latency tracking, quality scoring, hallucination detection, code quality analysis, A/B testing, and regression detection.

**Key Capabilities:**
- Scikit-learn, PyTorch, TensorFlow
- MLflow, Kubeflow
- Feature stores
- Model serving (FastAPI, TF Serving)
- A/B testing for models

**When to Use:**
Use the `AI Quality Metrics Agent` when you need specialized agent for measuring, analyzing, and improving ai output quality through latency tracking, quality scoring, hallucination detection, code quality analysis, a/b testing, and regression detection..

**Usage:**
```bash
/agent run ai-ml/quality-metrics-agent.md <instructions>
```

**Related Agents:**
[Claude Opus Max Agent](#claude-opus-max), [Codex Max Agent](#codex-max), [Gemini Deep Agent](#gemini-deep)

---

### <a id='rag-expert'></a>rag-expert

**Description:** Vector store and RAG optimization agent focusing on chunking, embeddings, retrieval, and evaluation.

**Key Capabilities:**
- Scikit-learn, PyTorch, TensorFlow
- MLflow, Kubeflow
- Feature stores
- Model serving (FastAPI, TF Serving)
- A/B testing for models

**When to Use:**
Use the `rag-expert` when you need vector store and rag optimization agent focusing on chunking, embeddings, retrieval, and evaluation..

**Usage:**
```bash
/agent run ai-ml/rag-expert.md <instructions>
```

**Related Agents:**
[Claude Opus Max Agent](#claude-opus-max), [Codex Max Agent](#codex-max), [Gemini Deep Agent](#gemini-deep)

---

## Backend Development

### <a id='api-architect'></a>API Architect Agent

**Description:** Designs and documents REST/GraphQL APIs. Creates OpenAPI specs and API contracts.

**When to Use:**
Use the `API Architect Agent` when you need designs and documents rest/graphql apis. creates openapi specs and api contracts..

**Usage:**
```bash
/agent run backend/api-architect.md <instructions>
```

**Related Agents:**
[Authentication Specialist Agent](#authentication-specialist), [Backend Developer Agent](#backend-developer), [Django Expert Agent](#django-expert)

---

### <a id='authentication-specialist'></a>Authentication Specialist Agent

**Description:** Authentication and authorization specialist. Expert in JWT, OAuth, RBAC, and security best practices.

**Key Capabilities:**
- OAuth 2.0 / OpenID Connect
- JWT best practices
- Session management
- MFA implementation
- Social login integration

**When to Use:**
Use the `Authentication Specialist Agent` when you need authentication and authorization specialist. expert in jwt, oauth, rbac, and security best practices..

**Usage:**
```bash
/agent run backend/authentication-specialist.md <instructions>
```

**Related Agents:**
[API Architect Agent](#api-architect), [Backend Developer Agent](#backend-developer), [Django Expert Agent](#django-expert)

---

### <a id='backend-developer'></a>Backend Developer Agent

**Description:** General backend development expert. Implements APIs, services, and server-side logic.

**Key Capabilities:**
- RESTful API design
- Database operations
- Authentication/Authorization
- Caching strategies
- Background jobs

**When to Use:**
Use the `Backend Developer Agent` when you need general backend development expert. implements apis, services, and server-side logic..

**Usage:**
```bash
/agent run backend/backend-developer.md <instructions>
```

**Related Agents:**
[API Architect Agent](#api-architect), [Authentication Specialist Agent](#authentication-specialist), [Django Expert Agent](#django-expert)

---

### <a id='django-expert'></a>Django Expert Agent

**Description:** Django and Django REST Framework specialist. Expert in Python web development with Django.

**Key Capabilities:**
- Django ORM
- Django REST Framework
- Django Channels (WebSockets)
- Celery integration
- Django security best practices

**When to Use:**
Use the `Django Expert Agent` when you need django and django rest framework specialist. expert in python web development with django..

**Usage:**
```bash
/agent run backend/django-expert.md <instructions>
```

**Related Agents:**
[API Architect Agent](#api-architect), [Authentication Specialist Agent](#authentication-specialist), [Backend Developer Agent](#backend-developer)

---

### <a id='fastapi-expert'></a>FastAPI Expert Agent

**Description:** FastAPI framework specialist. Expert in async Python, Pydantic, dependency injection.

**Key Capabilities:**
- Async/await patterns
- Pydantic validation
- SQLAlchemy async
- Background tasks
- WebSocket endpoints

**When to Use:**
Use the `FastAPI Expert Agent` when you need fastapi framework specialist. expert in async python, pydantic, dependency injection..

**Usage:**
```bash
/agent run backend/fastapi-expert.md <instructions>
```

**Related Agents:**
[API Architect Agent](#api-architect), [Authentication Specialist Agent](#authentication-specialist), [Backend Developer Agent](#backend-developer)

---

### <a id='go-expert'></a>Go Expert Agent

**Description:** Go/Golang specialist. Expert in Go web services, concurrency, and idiomatic Go patterns.

**Key Capabilities:**
- Gin / Echo / Chi frameworks
- Goroutines and channels
- GORM / sqlx
- Go testing
- Protocol Buffers / gRPC

**When to Use:**
Use the `Go Expert Agent` when you need go/golang specialist. expert in go web services, concurrency, and idiomatic go patterns..

**Usage:**
```bash
/agent run backend/go-expert.md <instructions>
```

**Related Agents:**
[API Architect Agent](#api-architect), [Authentication Specialist Agent](#authentication-specialist), [Backend Developer Agent](#backend-developer)

---

### <a id='graphql-specialist'></a>GraphQL Specialist Agent

**Description:** GraphQL API design and implementation specialist. Expert in schema design, resolvers, and GraphQL best practices.

**Key Capabilities:**
- Apollo Server / GraphQL Yoga
- Schema design
- Query optimization
- Real-time subscriptions
- Federation/Stitching

**When to Use:**
Use the `GraphQL Specialist Agent` when you need graphql api design and implementation specialist. expert in schema design, resolvers, and graphql best practices..

**Usage:**
```bash
/agent run backend/graphql-specialist.md <instructions>
```

**Related Agents:**
[API Architect Agent](#api-architect), [Authentication Specialist Agent](#authentication-specialist), [Backend Developer Agent](#backend-developer)

---

### <a id='microservices-architect'></a>Microservices Architect Agent

**Description:** Microservices architecture specialist. Expert in service decomposition, communication patterns, and distributed systems.

**Key Capabilities:**
- Service decomposition
- Event-driven architecture
- Saga patterns
- Circuit breakers
- Service mesh

**When to Use:**
Use the `Microservices Architect Agent` when you need microservices architecture specialist. expert in service decomposition, communication patterns, and distributed systems..

**Usage:**
```bash
/agent run backend/microservices-architect.md <instructions>
```

**Related Agents:**
[API Architect Agent](#api-architect), [Authentication Specialist Agent](#authentication-specialist), [Backend Developer Agent](#backend-developer)

---

### <a id='nodejs-expert'></a>Node.js Expert Agent

**Description:** Node.js and Express/NestJS specialist. Expert in TypeScript, async patterns, and Node.js best practices.

**Key Capabilities:**
- Express.js / NestJS
- TypeScript strict mode
- Prisma / TypeORM
- Socket.io
- Bull/BullMQ queues

**When to Use:**
Use the `Node.js Expert Agent` when you need node.js and express/nestjs specialist. expert in typescript, async patterns, and node.js best practices..

**Usage:**
```bash
/agent run backend/nodejs-expert.md <instructions>
```

**Related Agents:**
[API Architect Agent](#api-architect), [Authentication Specialist Agent](#authentication-specialist), [Backend Developer Agent](#backend-developer)

---

### <a id='rails-expert'></a>Rails Expert Agent

**Description:** Ruby on Rails specialist. Expert in Rails conventions, ActiveRecord, and Ruby best practices.

**Key Capabilities:**
- Rails conventions
- ActiveRecord patterns
- Rails API mode
- Action Cable (WebSockets)
- RSpec testing

**When to Use:**
Use the `Rails Expert Agent` when you need ruby on rails specialist. expert in rails conventions, activerecord, and ruby best practices..

**Usage:**
```bash
/agent run backend/rails-expert.md <instructions>
```

**Related Agents:**
[API Architect Agent](#api-architect), [Authentication Specialist Agent](#authentication-specialist), [Backend Developer Agent](#backend-developer)

---

## Business & Planning

### <a id='business-analyst'></a>Business Analyst Agent

**Description:** tools:

**When to Use:**
Use the `Business Analyst Agent` when you need tools:.

**Usage:**
```bash
/agent run business/business-analyst.md <instructions>
```

**Related Agents:**
[Cloud Cost Optimizer Agent](#cost-optimizer), [Project Tracker Agent](#project-tracker), [Stakeholder Communicator Agent](#stakeholder-communicator)

---

### <a id='cost-optimizer'></a>Cloud Cost Optimizer Agent

**Description:** Specialized agent for multi-cloud and AI cost optimization, including reserved instances, spot strategies, right-sizing, token usage optimization, and budget forecasting.

**When to Use:**
Use the `Cloud Cost Optimizer Agent` when you need specialized agent for multi-cloud and ai cost optimization, including reserved instances, spot strategies, right-sizing, token usage optimization, and budget forecasting..

**Usage:**
```bash
/agent run business/cost-optimizer.md <instructions>
```

**Related Agents:**
[Business Analyst Agent](#business-analyst), [Project Tracker Agent](#project-tracker), [Stakeholder Communicator Agent](#stakeholder-communicator)

---

### <a id='project-tracker'></a>Project Tracker Agent

**Description:** tools:

**Key Capabilities:**
- 

**When to Use:**
Use the `Project Tracker Agent` when you need tools:.

**Usage:**
```bash
/agent run business/project-tracker.md <instructions>
```

**Related Agents:**
[Business Analyst Agent](#business-analyst), [Cloud Cost Optimizer Agent](#cost-optimizer), [Stakeholder Communicator Agent](#stakeholder-communicator)

---

### <a id='stakeholder-communicator'></a>Stakeholder Communicator Agent

**Description:** tools:

**Key Capabilities:**
- 

**When to Use:**
Use the `Stakeholder Communicator Agent` when you need tools:.

**Usage:**
```bash
/agent run business/stakeholder-communicator.md <instructions>
```

**Related Agents:**
[Business Analyst Agent](#business-analyst), [Cloud Cost Optimizer Agent](#cost-optimizer), [Project Tracker Agent](#project-tracker)

---

## Cloud & Infrastructure

### <a id='aws-expert'></a>AWS Expert Agent

**Description:** AWS cloud specialist. Expert in AWS services, architecture, and best practices.

**When to Use:**
Use the `AWS Expert Agent` when you need aws cloud specialist. expert in aws services, architecture, and best practices..

**Usage:**
```bash
/agent run cloud/aws-expert.md <instructions>
```

**Related Agents:**
[Azure Expert Agent](#azure-expert), [GCP Expert Agent](#gcp-expert-full), [GCP Expert Agent](#gcp-expert)

---

### <a id='azure-expert'></a>Azure Expert Agent

**Description:** Azure cloud specialist. Expert in Microsoft Azure services, architecture, automation, and cost management.

**When to Use:**
Use the `Azure Expert Agent` when you need azure cloud specialist. expert in microsoft azure services, architecture, automation, and cost management..

**Usage:**
```bash
/agent run cloud/azure-expert.md <instructions>
```

**Related Agents:**
[AWS Expert Agent](#aws-expert), [GCP Expert Agent](#gcp-expert-full), [GCP Expert Agent](#gcp-expert)

---

### <a id='gcp-expert-full'></a>GCP Expert Agent

**Description:** A specialized agent for Google Cloud Platform architecture, implementation, and optimization.

**When to Use:**
Use the `GCP Expert Agent` when you need a specialized agent for google cloud platform architecture, implementation, and optimization..

**Usage:**
```bash
/agent run cloud/gcp-expert-full.md <instructions>
```

**Related Agents:**
[AWS Expert Agent](#aws-expert), [Azure Expert Agent](#azure-expert), [GCP Expert Agent](#gcp-expert)

---

### <a id='gcp-expert'></a>GCP Expert Agent

**Description:** Google Cloud Platform specialist. Expert in GCP services and architecture.

**When to Use:**
Use the `GCP Expert Agent` when you need google cloud platform specialist. expert in gcp services and architecture..

**Usage:**
```bash
/agent run cloud/gcp-expert.md <instructions>
```

**Related Agents:**
[AWS Expert Agent](#aws-expert), [Azure Expert Agent](#azure-expert), [GCP Expert Agent](#gcp-expert-full)

---

### <a id='multi-cloud-architect'></a>Multi-Cloud Expert Agent

**Description:** You are the **Multi-Cloud Architect**, an expert AI agent specializing in designing, implementing, and optimizing architectures that span multiple cloud providers (AWS, Azure, GCP, and others). Your goal is to build resilient, cost-effective, and vendor-neutral systems.

**When to Use:**
Use the `Multi-Cloud Expert Agent` when you need you are the **multi-cloud architect**, an expert ai agent specializing in designing, implementing, and optimizing architectures that span multiple cloud providers (aws, azure, gcp, and others). your goal is to build resilient, cost-effective, and vendor-neutral systems..

**Usage:**
```bash
/agent run cloud/multi-cloud-architect.md <instructions>
```

**Related Agents:**
[AWS Expert Agent](#aws-expert), [Azure Expert Agent](#azure-expert), [GCP Expert Agent](#gcp-expert-full)

---

### <a id='multi-cloud-expert'></a>Multi-Cloud Expert Agent

**Description:** Multi-cloud architecture specialist. Expert in cross-cloud strategies and portability.

**When to Use:**
Use the `Multi-Cloud Expert Agent` when you need multi-cloud architecture specialist. expert in cross-cloud strategies and portability..

**Usage:**
```bash
/agent run cloud/multi-cloud-expert.md <instructions>
```

**Related Agents:**
[AWS Expert Agent](#aws-expert), [Azure Expert Agent](#azure-expert), [GCP Expert Agent](#gcp-expert-full)

---

### <a id='serverless-expert'></a>Serverless Expert Agent

**Description:** name: serverless-expert

**When to Use:**
Use the `Serverless Expert Agent` when you need name: serverless-expert.

**Usage:**
```bash
/agent run cloud/serverless-expert.md <instructions>
```

**Related Agents:**
[AWS Expert Agent](#aws-expert), [Azure Expert Agent](#azure-expert), [GCP Expert Agent](#gcp-expert-full)

---

## Database Engineering

### <a id='database-architect'></a>Database Architect Agent

**Description:** Database architecture specialist. Expert in schema design, normalization, indexing, and database optimization.

**Key Capabilities:**
- Schema normalization (1NF-BCNF)
- Index optimization
- Partitioning strategies
- Replication patterns
- Database selection

**When to Use:**
Use the `Database Architect Agent` when you need database architecture specialist. expert in schema design, normalization, indexing, and database optimization..

**Usage:**
```bash
/agent run database/database-architect.md <instructions>
```

**Related Agents:**
[Migration Expert Agent (Full)](#migration-expert-full), [Migration Expert Agent](#migration-expert), [MongoDB Expert Agent](#mongodb-expert)

---

### <a id='migration-expert-full'></a>Migration Expert Agent (Full)

**Description:** Database migration specialist. Expert in zero-downtime schema evolution, data backfills, rollback safety, and cross-database moves.

**Key Capabilities:**
- Zero-downtime patterns (expand/contract, dual-write, shadow tables)
- Online DDL and lock management
- Backfills, data validation, and idempotent scripts
- Rollback planning and feature flag coordination
- Schema versioning and migration ordering

**When to Use:**
Use the `Migration Expert Agent (Full)` when you need database migration specialist. expert in zero-downtime schema evolution, data backfills, rollback safety, and cross-database moves..

**Usage:**
```bash
/agent run database/migration-expert-full.md <instructions>
```

**Related Agents:**
[Database Architect Agent](#database-architect), [Migration Expert Agent](#migration-expert), [MongoDB Expert Agent](#mongodb-expert)

---

### <a id='migration-expert'></a>Migration Expert Agent

**Description:** Database migration specialist. Expert in schema evolution, zero-downtime migrations, and data migration strategies.

**Key Capabilities:**
- Schema evolution
- Zero-downtime migrations
- Data backfills
- Migration testing
- Rollback procedures

**When to Use:**
Use the `Migration Expert Agent` when you need database migration specialist. expert in schema evolution, zero-downtime migrations, and data migration strategies..

**Usage:**
```bash
/agent run database/migration-expert.md <instructions>
```

**Related Agents:**
[Database Architect Agent](#database-architect), [Migration Expert Agent (Full)](#migration-expert-full), [MongoDB Expert Agent](#mongodb-expert)

---

### <a id='mongodb-expert'></a>MongoDB Expert Agent

**Description:** MongoDB specialist. Expert in document modeling, aggregation, indexing, and MongoDB best practices.

**Key Capabilities:**
- Document modeling
- Aggregation framework
- Index strategies
- Sharding
- Change streams

**When to Use:**
Use the `MongoDB Expert Agent` when you need mongodb specialist. expert in document modeling, aggregation, indexing, and mongodb best practices..

**Usage:**
```bash
/agent run database/mongodb-expert.md <instructions>
```

**Related Agents:**
[Database Architect Agent](#database-architect), [Migration Expert Agent (Full)](#migration-expert-full), [Migration Expert Agent](#migration-expert)

---

### <a id='orm-expert'></a>ORM Expert Agent

**Description:** ORM specialist. Expert in Prisma, SQLAlchemy, TypeORM, and database abstraction patterns.

**Key Capabilities:**
- Prisma (Node.js)
- SQLAlchemy (Python)
- TypeORM / Drizzle
- ActiveRecord patterns
- Query optimization

**When to Use:**
Use the `ORM Expert Agent` when you need orm specialist. expert in prisma, sqlalchemy, typeorm, and database abstraction patterns..

**Usage:**
```bash
/agent run database/orm-expert.md <instructions>
```

**Related Agents:**
[Database Architect Agent](#database-architect), [Migration Expert Agent (Full)](#migration-expert-full), [Migration Expert Agent](#migration-expert)

---

### <a id='postgresql-expert'></a>PostgreSQL Expert Agent

**Description:** PostgreSQL specialist. Expert in PG features, performance tuning, extensions, and advanced queries.

**Key Capabilities:**
- Advanced SQL (CTEs, window functions)
- EXPLAIN ANALYZE
- pg_stat_statements
- JSON/JSONB operations
- Full-text search

**When to Use:**
Use the `PostgreSQL Expert Agent` when you need postgresql specialist. expert in pg features, performance tuning, extensions, and advanced queries..

**Usage:**
```bash
/agent run database/postgresql-expert.md <instructions>
```

**Related Agents:**
[Database Architect Agent](#database-architect), [Migration Expert Agent (Full)](#migration-expert-full), [Migration Expert Agent](#migration-expert)

---

### <a id='redis-expert'></a>Redis Expert Agent

**Description:** Redis specialist. Expert in caching, data structures, pub/sub, and Redis patterns.

**Key Capabilities:**
- Caching patterns
- Redis data structures
- Pub/Sub messaging
- Redis Streams
- Lua scripting

**When to Use:**
Use the `Redis Expert Agent` when you need redis specialist. expert in caching, data structures, pub/sub, and redis patterns..

**Usage:**
```bash
/agent run database/redis-expert.md <instructions>
```

**Related Agents:**
[Database Architect Agent](#database-architect), [Migration Expert Agent (Full)](#migration-expert-full), [Migration Expert Agent](#migration-expert)

---

## DevOps & SRE

### <a id='ci-cd-expert'></a>CI/CD Expert Agent

**Description:** Comprehensive CI/CD specialist for pipeline design, build automation, deployment strategies, and DevSecOps practices

**Key Capabilities:**
- Caching patterns
- Redis data structures
- Pub/Sub messaging
- Redis Streams
- Lua scripting

**When to Use:**
Use the `CI/CD Expert Agent` when you need comprehensive ci/cd specialist for pipeline design, build automation, deployment strategies, and devsecops practices.

**Usage:**
```bash
/agent run devops/ci-cd-expert.md <instructions>
```

**Related Agents:**
[DevOps Engineer Agent](#devops-engineer), [Docker Expert Agent](#docker-expert), [GitHub Actions Expert Agent](#github-actions-expert)

---

### <a id='devops-engineer'></a>DevOps Engineer Agent

**Description:** DevOps specialist. Expert in CI/CD, infrastructure automation, and deployment strategies.

**Key Capabilities:**
- CI/CD pipelines
- Infrastructure as Code
- Container orchestration
- Monitoring & logging
- Deployment strategies

**When to Use:**
Use the `DevOps Engineer Agent` when you need devops specialist. expert in ci/cd, infrastructure automation, and deployment strategies..

**Usage:**
```bash
/agent run devops/devops-engineer.md <instructions>
```

**Related Agents:**
[CI/CD Expert Agent](#ci-cd-expert), [Docker Expert Agent](#docker-expert), [GitHub Actions Expert Agent](#github-actions-expert)

---

### <a id='docker-expert'></a>Docker Expert Agent

**Description:** Docker and containerization specialist. Expert in Docker, Docker Compose, and container best practices.

**When to Use:**
Use the `Docker Expert Agent` when you need docker and containerization specialist. expert in docker, docker compose, and container best practices..

**Usage:**
```bash
/agent run devops/docker-expert.md <instructions>
```

**Related Agents:**
[CI/CD Expert Agent](#ci-cd-expert), [DevOps Engineer Agent](#devops-engineer), [GitHub Actions Expert Agent](#github-actions-expert)

---

### <a id='github-actions-expert'></a>GitHub Actions Expert Agent

**Description:** >

**When to Use:**
Use the `GitHub Actions Expert Agent` when you need >.

**Usage:**
```bash
/agent run devops/github-actions-expert.md <instructions>
```

**Related Agents:**
[CI/CD Expert Agent](#ci-cd-expert), [DevOps Engineer Agent](#devops-engineer), [Docker Expert Agent](#docker-expert)

---

### <a id='incident-response-agent'></a>Production Incident Response Agent

**Description:** Comprehensive production incident management specialist for incident detection, classification, root cause analysis, runbook execution, auto-rollback, stakeholder communication, and blameless postmortem facilitation

**When to Use:**
Use the `Production Incident Response Agent` when you need comprehensive production incident management specialist for incident detection, classification, root cause analysis, runbook execution, auto-rollback, stakeholder communication, and blameless postmortem facilitation.

**Usage:**
```bash
/agent run devops/incident-response-agent.md <instructions>
```

**Related Agents:**
[CI/CD Expert Agent](#ci-cd-expert), [DevOps Engineer Agent](#devops-engineer), [Docker Expert Agent](#docker-expert)

---

### <a id='infrastructure-architect'></a>Infrastructure Architect Agent

**Description:** name: infrastructure-architect

**When to Use:**
Use the `Infrastructure Architect Agent` when you need name: infrastructure-architect.

**Usage:**
```bash
/agent run devops/infrastructure-architect.md <instructions>
```

**Related Agents:**
[CI/CD Expert Agent](#ci-cd-expert), [DevOps Engineer Agent](#devops-engineer), [Docker Expert Agent](#docker-expert)

---

### <a id='kubernetes-expert'></a>Kubernetes Expert Agent

**Description:** Kubernetes specialist. Expert in K8s resources, deployments, and cluster management.

**When to Use:**
Use the `Kubernetes Expert Agent` when you need kubernetes specialist. expert in k8s resources, deployments, and cluster management..

**Usage:**
```bash
/agent run devops/kubernetes-expert.md <instructions>
```

**Related Agents:**
[CI/CD Expert Agent](#ci-cd-expert), [DevOps Engineer Agent](#devops-engineer), [Docker Expert Agent](#docker-expert)

---

### <a id='monitoring-expert'></a>Monitoring Expert Agent

**Description:** Monitoring and observability specialist. Expert in Prometheus, Grafana, and logging.

**When to Use:**
Use the `Monitoring Expert Agent` when you need monitoring and observability specialist. expert in prometheus, grafana, and logging..

**Usage:**
```bash
/agent run devops/monitoring-expert.md <instructions>
```

**Related Agents:**
[CI/CD Expert Agent](#ci-cd-expert), [DevOps Engineer Agent](#devops-engineer), [Docker Expert Agent](#docker-expert)

---

### <a id='self-healing-pipeline-agent'></a>Self-Healing Pipeline Agent

**Description:** Autonomous agent for detecting, analyzing, and fixing CI/CD pipeline failures

**When to Use:**
Use the `Self-Healing Pipeline Agent` when you need autonomous agent for detecting, analyzing, and fixing ci/cd pipeline failures.

**Usage:**
```bash
/agent run devops/self-healing-pipeline-agent.md <instructions>
```

**Related Agents:**
[CI/CD Expert Agent](#ci-cd-expert), [DevOps Engineer Agent](#devops-engineer), [Docker Expert Agent](#docker-expert)

---

### <a id='terraform-expert'></a>Terraform Expert Agent

**Description:** Terraform and IaC specialist. Expert in Terraform modules, state management, and multi-cloud.

**When to Use:**
Use the `Terraform Expert Agent` when you need terraform and iac specialist. expert in terraform modules, state management, and multi-cloud..

**Usage:**
```bash
/agent run devops/terraform-expert.md <instructions>
```

**Related Agents:**
[CI/CD Expert Agent](#ci-cd-expert), [DevOps Engineer Agent](#devops-engineer), [Docker Expert Agent](#docker-expert)

---

## Frontend Development

### <a id='accessibility-expert'></a>Accessibility Expert Agent

**Description:** Web accessibility specialist. Expert in WCAG, ARIA, screen readers, and inclusive design.

**Key Capabilities:**
- WCAG 2.1 AA/AAA
- ARIA roles and attributes
- Keyboard navigation
- Color contrast
- Focus management

**When to Use:**
Use the `Accessibility Expert Agent` when you need web accessibility specialist. expert in wcag, aria, screen readers, and inclusive design..

**Usage:**
```bash
/agent run frontend/accessibility-expert.md <instructions>
```

**Related Agents:**
[CSS Expert Agent](#css-expert), [Frontend Developer Agent](#frontend-developer), [Mobile Web Expert Agent](#mobile-web-expert)

---

### <a id='css-expert'></a>CSS Expert Agent

**Description:** CSS and styling specialist. Expert in CSS, Tailwind, CSS-in-JS, animations, and responsive design.

**Key Capabilities:**
- CSS Grid / Flexbox
- Tailwind CSS
- CSS-in-JS (styled-components, Emotion)
- CSS animations
- Dark mode implementation

**When to Use:**
Use the `CSS Expert Agent` when you need css and styling specialist. expert in css, tailwind, css-in-js, animations, and responsive design..

**Usage:**
```bash
/agent run frontend/css-expert.md <instructions>
```

**Related Agents:**
[Accessibility Expert Agent](#accessibility-expert), [Frontend Developer Agent](#frontend-developer), [Mobile Web Expert Agent](#mobile-web-expert)

---

### <a id='frontend-developer'></a>Frontend Developer Agent

**Description:** General frontend development specialist. Expert in modern web development, responsive design, and UI implementation.

**Key Capabilities:**
- HTML5/CSS3/JavaScript
- Component architecture
- Responsive design
- Accessibility (a11y)
- Browser compatibility

**When to Use:**
Use the `Frontend Developer Agent` when you need general frontend development specialist. expert in modern web development, responsive design, and ui implementation..

**Usage:**
```bash
/agent run frontend/frontend-developer.md <instructions>
```

**Related Agents:**
[Accessibility Expert Agent](#accessibility-expert), [CSS Expert Agent](#css-expert), [Mobile Web Expert Agent](#mobile-web-expert)

---

### <a id='mobile-web-expert'></a>Mobile Web Expert Agent

**Description:** Mobile web and PWA specialist. Expert in responsive design, PWA, mobile performance, and touch interactions.

**Key Capabilities:**
- Progressive Web Apps
- Service Workers
- Mobile-first design
- Touch gestures
- Offline functionality

**When to Use:**
Use the `Mobile Web Expert Agent` when you need mobile web and pwa specialist. expert in responsive design, pwa, mobile performance, and touch interactions..

**Usage:**
```bash
/agent run frontend/mobile-web-expert.md <instructions>
```

**Related Agents:**
[Accessibility Expert Agent](#accessibility-expert), [CSS Expert Agent](#css-expert), [Frontend Developer Agent](#frontend-developer)

---

### <a id='nextjs-expert'></a>Next.js Expert Agent

**Description:** Next.js specialist. Expert in App Router, Server Components, SSR/SSG, and Next.js best practices.

**Key Capabilities:**
- App Router (Next.js 13+)
- React Server Components
- Server Actions
- Middleware
- Edge Runtime

**When to Use:**
Use the `Next.js Expert Agent` when you need next.js specialist. expert in app router, server components, ssr/ssg, and next.js best practices..

**Usage:**
```bash
/agent run frontend/nextjs-expert.md <instructions>
```

**Related Agents:**
[Accessibility Expert Agent](#accessibility-expert), [CSS Expert Agent](#css-expert), [Frontend Developer Agent](#frontend-developer)

---

### <a id='react-expert'></a>React Expert Agent

**Description:** React.js specialist. Expert in React patterns, hooks, state management, and React ecosystem.

**Key Capabilities:**
- React 18+ features
- Custom hooks
- Context API
- React Query / SWR
- React performance

**When to Use:**
Use the `React Expert Agent` when you need react.js specialist. expert in react patterns, hooks, state management, and react ecosystem..

**Usage:**
```bash
/agent run frontend/react-expert.md <instructions>
```

**Related Agents:**
[Accessibility Expert Agent](#accessibility-expert), [CSS Expert Agent](#css-expert), [Frontend Developer Agent](#frontend-developer)

---

### <a id='state-management-expert'></a>State Management Expert Agent

**Description:** State management specialist. Expert in Redux, Zustand, Jotai, React Query, and state patterns.

**Key Capabilities:**
- Redux Toolkit
- Zustand / Jotai
- React Query / TanStack Query
- Recoil
- State normalization

**When to Use:**
Use the `State Management Expert Agent` when you need state management specialist. expert in redux, zustand, jotai, react query, and state patterns..

**Usage:**
```bash
/agent run frontend/state-management-expert.md <instructions>
```

**Related Agents:**
[Accessibility Expert Agent](#accessibility-expert), [CSS Expert Agent](#css-expert), [Frontend Developer Agent](#frontend-developer)

---

### <a id='testing-frontend'></a>Frontend Testing Agent

**Description:** Frontend testing specialist. Expert in Jest, Testing Library, Playwright, and component testing.

**Key Capabilities:**
- Jest / Vitest
- React Testing Library
- Playwright / Cypress
- Mock Service Worker (MSW)
- Snapshot testing

**When to Use:**
Use the `Frontend Testing Agent` when you need frontend testing specialist. expert in jest, testing library, playwright, and component testing..

**Usage:**
```bash
/agent run frontend/testing-frontend.md <instructions>
```

**Related Agents:**
[Accessibility Expert Agent](#accessibility-expert), [CSS Expert Agent](#css-expert), [Frontend Developer Agent](#frontend-developer)

---

### <a id='typescript-expert'></a>TypeScript Expert Agent

**Description:** TypeScript specialist. Expert in type systems, generics, advanced patterns, and TypeScript best practices.

**Key Capabilities:**
- Advanced generics
- Conditional types
- Template literal types
- Type inference
- Declaration files

**When to Use:**
Use the `TypeScript Expert Agent` when you need typescript specialist. expert in type systems, generics, advanced patterns, and typescript best practices..

**Usage:**
```bash
/agent run frontend/typescript-expert.md <instructions>
```

**Related Agents:**
[Accessibility Expert Agent](#accessibility-expert), [CSS Expert Agent](#css-expert), [Frontend Developer Agent](#frontend-developer)

---

### <a id='vue-expert'></a>Vue Expert Agent

**Description:** Vue.js specialist. Expert in Vue 3, Composition API, Pinia, and Vue ecosystem.

**Key Capabilities:**
- Vue 3 Composition API
- Pinia state management
- Vue Router
- Nuxt.js
- VueUse composables

**When to Use:**
Use the `Vue Expert Agent` when you need vue.js specialist. expert in vue 3, composition api, pinia, and vue ecosystem..

**Usage:**
```bash
/agent run frontend/vue-expert.md <instructions>
```

**Related Agents:**
[Accessibility Expert Agent](#accessibility-expert), [CSS Expert Agent](#css-expert), [Frontend Developer Agent](#frontend-developer)

---

## General Purpose & Orchestration

### <a id='cascade-agent'></a>Cascade Agent

**Description:** End-to-end automation of the ticket-to-PR workflow. Orchestrates specialized agents to convert issue descriptions into fully implemented, tested, and documented pull requests.

**Key Capabilities:**
- Vue 3 Composition API
- Pinia state management
- Vue Router
- Nuxt.js
- VueUse composables

**When to Use:**
Use the `Cascade Agent` when you need end-to-end automation of the ticket-to-pr workflow. orchestrates specialized agents to convert issue descriptions into fully implemented, tested, and documented pull requests..

**Usage:**
```bash
/agent run general/cascade-agent.md <instructions>
```

**Related Agents:**
[Context Manager Agent](#context-manager), [Memory Coordinator Agent](#memory-coordinator), [model-router](#model-router)

---

### <a id='context-manager'></a>Context Manager Agent

**Description:** Manages project context, loads relevant files, and maintains awareness of the current project state.

**When to Use:**
Use the `Context Manager Agent` when you need manages project context, loads relevant files, and maintains awareness of the current project state..

**Usage:**
```bash
/agent run general/context-manager.md <instructions>
```

**Related Agents:**
[Cascade Agent](#cascade-agent), [Memory Coordinator Agent](#memory-coordinator), [model-router](#model-router)

---

### <a id='memory-coordinator'></a>Memory Coordinator Agent

**Description:** Coordinates memory systems including vector memory, project ledger, and error knowledge graph.

**When to Use:**
Use the `Memory Coordinator Agent` when you need coordinates memory systems including vector memory, project ledger, and error knowledge graph..

**Usage:**
```bash
/agent run general/memory-coordinator.md <instructions>
```

**Related Agents:**
[Cascade Agent](#cascade-agent), [Context Manager Agent](#context-manager), [model-router](#model-router)

---

### <a id='model-router'></a>model-router

**Description:** Intelligent orchestrator that routes tasks to the optimal AI model (Claude, Codex, Gemini) based on complexity, cost, context, and file-type constraints.

**When to Use:**
Use the `model-router` when you need intelligent orchestrator that routes tasks to the optimal ai model (claude, codex, gemini) based on complexity, cost, context, and file-type constraints..

**Usage:**
```bash
/agent run general/model-router.md <instructions>
```

**Related Agents:**
[Cascade Agent](#cascade-agent), [Context Manager Agent](#context-manager), [Memory Coordinator Agent](#memory-coordinator)

---

### <a id='observability-agent'></a>observability-agent

**Description:** An agent designed to trace, monitor, and report on the performance, cost, and quality of other AI agents and workflows.

**When to Use:**
Use the `observability-agent` when you need an agent designed to trace, monitor, and report on the performance, cost, and quality of other ai agents and workflows..

**Usage:**
```bash
/agent run general/observability-agent.md <instructions>
```

**Related Agents:**
[Cascade Agent](#cascade-agent), [Context Manager Agent](#context-manager), [Memory Coordinator Agent](#memory-coordinator)

---

### <a id='orchestrator'></a>Orchestrator Agent

**Description:** Master workflow orchestrator that coordinates all SDLC phases and delegates to specialized agents.

**Key Capabilities:**
- Full SDLC workflow management
- Multi-agent coordination
- Parallel task execution via git worktrees
- Progress tracking and reporting
- Quality gate enforcement

**When to Use:**
Use the `Orchestrator Agent` when you need master workflow orchestrator that coordinates all sdlc phases and delegates to specialized agents..

**Usage:**
```bash
/agent run general/orchestrator.md <instructions>
```

**Related Agents:**
[Cascade Agent](#cascade-agent), [Context Manager Agent](#context-manager), [Memory Coordinator Agent](#memory-coordinator)

---

### <a id='pair-programmer'></a>pair-programmer

**Description:** Interactive pair programmer for real-time coding assistance, incremental edits, and rapid feedback.

**Key Capabilities:**
- Full SDLC workflow management
- Multi-agent coordination
- Parallel task execution via git worktrees
- Progress tracking and reporting
- Quality gate enforcement

**When to Use:**
Use the `pair-programmer` when you need interactive pair programmer for real-time coding assistance, incremental edits, and rapid feedback..

**Usage:**
```bash
/agent run general/pair-programmer.md <instructions>
```

**Related Agents:**
[Cascade Agent](#cascade-agent), [Context Manager Agent](#context-manager), [Memory Coordinator Agent](#memory-coordinator)

---

### <a id='parallel-coordinator'></a>Parallel Coordinator Agent

**Description:** Coordinates parallel execution of independent tasks using git worktrees or isolated contexts.

**When to Use:**
Use the `Parallel Coordinator Agent` when you need coordinates parallel execution of independent tasks using git worktrees or isolated contexts..

**Usage:**
```bash
/agent run general/parallel-coordinator.md <instructions>
```

**Related Agents:**
[Cascade Agent](#cascade-agent), [Context Manager Agent](#context-manager), [Memory Coordinator Agent](#memory-coordinator)

---

### <a id='session-manager'></a>Session Manager Agent

**Description:** Manages session state, progress tracking, and ensures continuity across conversation turns.

**When to Use:**
Use the `Session Manager Agent` when you need manages session state, progress tracking, and ensures continuity across conversation turns..

**Usage:**
```bash
/agent run general/session-manager.md <instructions>
```

**Related Agents:**
[Cascade Agent](#cascade-agent), [Context Manager Agent](#context-manager), [Memory Coordinator Agent](#memory-coordinator)

---

### <a id='task-router'></a>Task Router Agent

**Description:** Intelligent task routing agent that analyzes tasks and determines the optimal agent, model, and execution strategy.

**When to Use:**
Use the `Task Router Agent` when you need intelligent task routing agent that analyzes tasks and determines the optimal agent, model, and execution strategy..

**Usage:**
```bash
/agent run general/task-router.md <instructions>
```

**Related Agents:**
[Cascade Agent](#cascade-agent), [Context Manager Agent](#context-manager), [Memory Coordinator Agent](#memory-coordinator)

---

## Integration & APIs

### <a id='api-integration-expert'></a>API Integration Expert Agent

**Description:** API integration specialist. Expert in REST, webhooks, OAuth, and third-party integrations.

**When to Use:**
Use the `API Integration Expert Agent` when you need api integration specialist. expert in rest, webhooks, oauth, and third-party integrations..

**Usage:**
```bash
/agent run integration/api-integration-expert.md <instructions>
```

**Related Agents:**
[api-observability-agent](#api-observability-agent), [MCP Integration Expert Agent](#mcp-expert), [Third-Party API Expert](#third-party-api-expert)

---

### <a id='api-observability-agent'></a>api-observability-agent

**Description:** Monitors API health, performance, and reliability. Tracks latency percentiles, error rates, breaking changes, and generates comprehensive usage reports.

**When to Use:**
Use the `api-observability-agent` when you need monitors api health, performance, and reliability. tracks latency percentiles, error rates, breaking changes, and generates comprehensive usage reports..

**Usage:**
```bash
/agent run integration/api-observability-agent.md <instructions>
```

**Related Agents:**
[API Integration Expert Agent](#api-integration-expert), [MCP Integration Expert Agent](#mcp-expert), [Third-Party API Expert](#third-party-api-expert)

---

### <a id='mcp-expert'></a>MCP Integration Expert Agent

**Description:** Model Context Protocol specialist for server development, tool patterns, and AI integrations

**When to Use:**
Use the `MCP Integration Expert Agent` when you need model context protocol specialist for server development, tool patterns, and ai integrations.

**Usage:**
```bash
/agent run integration/mcp-expert.md <instructions>
```

**Related Agents:**
[API Integration Expert Agent](#api-integration-expert), [api-observability-agent](#api-observability-agent), [Third-Party API Expert](#third-party-api-expert)

---

### <a id='third-party-api-expert'></a>Third-Party API Expert

**Description:** Expert in external API integrations including OAuth, rate limiting, webhooks, and provider SDKs

**When to Use:**
Use the `Third-Party API Expert` when you need expert in external api integrations including oauth, rate limiting, webhooks, and provider sdks.

**Usage:**
```bash
/agent run integration/third-party-api-expert.md <instructions>
```

**Related Agents:**
[API Integration Expert Agent](#api-integration-expert), [api-observability-agent](#api-observability-agent), [MCP Integration Expert Agent](#mcp-expert)

---

### <a id='webhook-expert'></a>Webhook Expert Agent

**Description:** "Target framework (express, fastapi, flask, django)"

**When to Use:**
Use the `Webhook Expert Agent` when you need "target framework (express, fastapi, flask, django)".

**Usage:**
```bash
/agent run integration/webhook-expert.md <instructions>
```

**Related Agents:**
[API Integration Expert Agent](#api-integration-expert), [api-observability-agent](#api-observability-agent), [MCP Integration Expert Agent](#mcp-expert)

---

## Performance Engineering

### <a id='bundle-optimizer'></a>Bundle Optimizer Agent

**Description:** Expert in JavaScript/TypeScript bundle optimization for Webpack, Vite, and esbuild. Specializes in tree shaking, code splitting, lazy loading, and performance budget enforcement.

**When to Use:**
Use the `Bundle Optimizer Agent` when you need expert in javascript/typescript bundle optimization for webpack, vite, and esbuild. specializes in tree shaking, code splitting, lazy loading, and performance budget enforcement..

**Usage:**
```bash
/agent run performance/bundle-optimizer.md <instructions>
```

**Related Agents:**
[Caching Expert Agent](#caching-expert), [load-testing-expert](#load-testing-expert), [Performance Optimizer Agent](#performance-optimizer)

---

### <a id='caching-expert'></a>Caching Expert Agent

**Description:** Caching specialist. Expert in cache strategies, Redis, CDN, and cache invalidation.

**When to Use:**
Use the `Caching Expert Agent` when you need caching specialist. expert in cache strategies, redis, cdn, and cache invalidation..

**Usage:**
```bash
/agent run performance/caching-expert.md <instructions>
```

**Related Agents:**
[Bundle Optimizer Agent](#bundle-optimizer), [load-testing-expert](#load-testing-expert), [Performance Optimizer Agent](#performance-optimizer)

---

### <a id='load-testing-expert'></a>load-testing-expert

**Description:** Load testing expert for k6 and Artillery. Designs tests, configures load profiles, establishes baselines, identifies bottlenecks, and recommends scaling actions.

**When to Use:**
Use the `load-testing-expert` when you need load testing expert for k6 and artillery. designs tests, configures load profiles, establishes baselines, identifies bottlenecks, and recommends scaling actions..

**Usage:**
```bash
/agent run performance/load-testing-expert.md <instructions>
```

**Related Agents:**
[Bundle Optimizer Agent](#bundle-optimizer), [Caching Expert Agent](#caching-expert), [Performance Optimizer Agent](#performance-optimizer)

---

### <a id='performance-optimizer'></a>Performance Optimizer Agent

**Description:** Performance optimization specialist. Expert in code optimization, caching, and performance tuning.

**When to Use:**
Use the `Performance Optimizer Agent` when you need performance optimization specialist. expert in code optimization, caching, and performance tuning..

**Usage:**
```bash
/agent run performance/performance-optimizer.md <instructions>
```

**Related Agents:**
[Bundle Optimizer Agent](#bundle-optimizer), [Caching Expert Agent](#caching-expert), [load-testing-expert](#load-testing-expert)

---

### <a id='profiling-expert'></a>Profiling Expert Agent

**Description:** >

**When to Use:**
Use the `Profiling Expert Agent` when you need >.

**Usage:**
```bash
/agent run performance/profiling-expert.md <instructions>
```

**Related Agents:**
[Bundle Optimizer Agent](#bundle-optimizer), [Caching Expert Agent](#caching-expert), [load-testing-expert](#load-testing-expert)

---

## Planning & Architecture

### <a id='architect'></a>Architect Agent

**Description:** Designs system architecture, creates technical specifications, and makes architectural decisions.

**When to Use:**
Use the `Architect Agent` when you need designs system architecture, creates technical specifications, and makes architectural decisions..

**Usage:**
```bash
/agent run planning/architect.md <instructions>
```

**Related Agents:**
[Exponential Planner Agent](#exponential-planner), [Product Manager Agent](#product-manager), [Requirements Analyst Agent](#requirements-analyst)

---

### <a id='exponential-planner'></a>Exponential Planner Agent

**Description:** Strategic long-term planner that creates comprehensive multi-phase development plans. Inspired by exponential planning methodology.

**When to Use:**
Use the `Exponential Planner Agent` when you need strategic long-term planner that creates comprehensive multi-phase development plans. inspired by exponential planning methodology..

**Usage:**
```bash
/agent run planning/exponential-planner.md <instructions>
```

**Related Agents:**
[Architect Agent](#architect), [Product Manager Agent](#product-manager), [Requirements Analyst Agent](#requirements-analyst)

---

### <a id='product-manager'></a>Product Manager Agent

**Description:** Creates PRDs (Product Requirements Documents), prioritizes features, and manages product backlog.

**When to Use:**
Use the `Product Manager Agent` when you need creates prds (product requirements documents), prioritizes features, and manages product backlog..

**Usage:**
```bash
/agent run planning/product-manager.md <instructions>
```

**Related Agents:**
[Architect Agent](#architect), [Exponential Planner Agent](#exponential-planner), [Requirements Analyst Agent](#requirements-analyst)

---

### <a id='requirements-analyst'></a>Requirements Analyst Agent

**Description:** Gathers, analyzes, and documents requirements. Creates user stories with acceptance criteria.

**When to Use:**
Use the `Requirements Analyst Agent` when you need gathers, analyzes, and documents requirements. creates user stories with acceptance criteria..

**Usage:**
```bash
/agent run planning/requirements-analyst.md <instructions>
```

**Related Agents:**
[Architect Agent](#architect), [Exponential Planner Agent](#exponential-planner), [Product Manager Agent](#product-manager)

---

### <a id='requirements-analyzer'></a>Requirements Analyzer Agent

**Description:** **Role:** You are the **Requirements Analyzer**, a specialized sub-agent responsible for the rigorous analysis, clarification, and structuring of software requirements. You bridge the gap between vague stakeholder desires and concrete technical specifications.

**Key Capabilities:**
- Ingest raw text from diverse sources (PRDs, emails, Slack threads, transcripts).
- Extract functional and non-functional requirements.
- Categorize requirements (e.g., UI/UX, Backend, Security, Performance).
- Identify vague terms (e.g., "fast", "user-friendly", "robust").
- Detect missing edge cases, error states, and unhandled user flows.

**When to Use:**
Use the `Requirements Analyzer Agent` when you need **role:** you are the **requirements analyzer**, a specialized sub-agent responsible for the rigorous analysis, clarification, and structuring of software requirements. you bridge the gap between vague stakeholder desires and concrete technical specifications..

**Usage:**
```bash
/agent run planning/requirements-analyzer.md <instructions>
```

**Related Agents:**
[Architect Agent](#architect), [Exponential Planner Agent](#exponential-planner), [Product Manager Agent](#product-manager)

---

### <a id='risk-assessor'></a>Risk Assessor Agent

**Description:** Identifies, analyzes, and documents risks in software projects. Creates risk matrices and mitigation plans.

**When to Use:**
Use the `Risk Assessor Agent` when you need identifies, analyzes, and documents risks in software projects. creates risk matrices and mitigation plans..

**Usage:**
```bash
/agent run planning/risk-assessor.md <instructions>
```

**Related Agents:**
[Architect Agent](#architect), [Exponential Planner Agent](#exponential-planner), [Product Manager Agent](#product-manager)

---

### <a id='spec-generator'></a>spec-generator

**Description:** Generates formal, testable specifications, API contracts, and test scenarios from requirements.

**When to Use:**
Use the `spec-generator` when you need generates formal, testable specifications, api contracts, and test scenarios from requirements..

**Usage:**
```bash
/agent run planning/spec-generator.md <instructions>
```

**Related Agents:**
[Architect Agent](#architect), [Exponential Planner Agent](#exponential-planner), [Product Manager Agent](#product-manager)

---

### <a id='tech-lead'></a>Tech Lead Agent

**Description:** Provides technical leadership, makes implementation decisions, and guides development teams.

**Key Capabilities:**
- Technology selection
- Code review strategy
- Technical debt management
- Team guidance
- Quality standards

**When to Use:**
Use the `Tech Lead Agent` when you need provides technical leadership, makes implementation decisions, and guides development teams..

**Usage:**
```bash
/agent run planning/tech-lead.md <instructions>
```

**Related Agents:**
[Architect Agent](#architect), [Exponential Planner Agent](#exponential-planner), [Product Manager Agent](#product-manager)

---

### <a id='tech-spec-writer'></a>Tech Spec Writer Agent

**Description:** Creates detailed technical specifications from requirements. Translates business requirements into technical implementation plans.

**When to Use:**
Use the `Tech Spec Writer Agent` when you need creates detailed technical specifications from requirements. translates business requirements into technical implementation plans..

**Usage:**
```bash
/agent run planning/tech-spec-writer.md <instructions>
```

**Related Agents:**
[Architect Agent](#architect), [Exponential Planner Agent](#exponential-planner), [Product Manager Agent](#product-manager)

---

### <a id='ux-researcher'></a>UX Researcher Agent

**Description:** Conducts UX research, creates user personas, and designs user journeys.

**When to Use:**
Use the `UX Researcher Agent` when you need conducts ux research, creates user personas, and designs user journeys..

**Usage:**
```bash
/agent run planning/ux-researcher.md <instructions>
```

**Related Agents:**
[Architect Agent](#architect), [Exponential Planner Agent](#exponential-planner), [Product Manager Agent](#product-manager)

---

## Quality Assurance & Code Quality

### <a id='code-reviewer'></a>Code Reviewer Agent

**Description:** Code review specialist. Expert in code quality, best practices, and constructive feedback.

**When to Use:**
Use the `Code Reviewer Agent` when you need code review specialist. expert in code quality, best practices, and constructive feedback..

**Usage:**
```bash
/agent run quality/code-reviewer.md <instructions>
```

**Related Agents:**
[Dependency Manager Agent](#dependency-manager), [Documentation Linter Agent](#doc-linter-agent), [Documentation Expert Agent](#documentation-expert)

---

### <a id='dependency-manager'></a>Dependency Manager Agent

**Description:** Purpose: Manage project dependencies with clear, actionable guidance.

**Key Capabilities:**
- Analyze the dependency tree.
- Identify outdated packages.
- Detect security vulnerabilities.
- Find unused dependencies.
- Suggest lighter alternatives.

**When to Use:**
Use the `Dependency Manager Agent` when you need purpose: manage project dependencies with clear, actionable guidance..

**Usage:**
```bash
/agent run quality/dependency-manager.md <instructions>
```

**Related Agents:**
[Code Reviewer Agent](#code-reviewer), [Documentation Linter Agent](#doc-linter-agent), [Documentation Expert Agent](#documentation-expert)

---

### <a id='doc-linter-agent'></a>Documentation Linter Agent

**Description:** You are the Documentation Linter Agent. You validate documentation quality and completeness, enforce standards, and generate missing docs. You must integrate with the documentation-expert agent for deep checks, standards alignment, and any remediation that requires domain-specific guidance.

**When to Use:**
Use the `Documentation Linter Agent` when you need you are the documentation linter agent. you validate documentation quality and completeness, enforce standards, and generate missing docs. you must integrate with the documentation-expert agent for deep checks, standards alignment, and any remediation that requires domain-specific guidance..

**Usage:**
```bash
/agent run quality/doc-linter-agent.md <instructions>
```

**Related Agents:**
[Code Reviewer Agent](#code-reviewer), [Dependency Manager Agent](#dependency-manager), [Documentation Expert Agent](#documentation-expert)

---

### <a id='documentation-expert'></a>Documentation Expert Agent

**Description:** Documentation specialist. Expert in API docs, code comments, and technical writing.

**When to Use:**
Use the `Documentation Expert Agent` when you need documentation specialist. expert in api docs, code comments, and technical writing..

**Usage:**
```bash
/agent run quality/documentation-expert.md <instructions>
```

**Related Agents:**
[Code Reviewer Agent](#code-reviewer), [Dependency Manager Agent](#dependency-manager), [Documentation Linter Agent](#doc-linter-agent)

---

### <a id='gemini-reviewer'></a>Gemini Reviewer Agent

**Description:** Gemini-powered code reviewer using CLI. Expert in security analysis, code quality validation, and design review.

**When to Use:**
Use the `Gemini Reviewer Agent` when you need gemini-powered code reviewer using cli. expert in security analysis, code quality validation, and design review..

**Usage:**
```bash
/agent run quality/gemini-reviewer.md <instructions>
```

**Related Agents:**
[Code Reviewer Agent](#code-reviewer), [Dependency Manager Agent](#dependency-manager), [Documentation Linter Agent](#doc-linter-agent)

---

### <a id='linting-expert'></a>Linting Expert Agent

**Description:** Linting and formatting specialist. Expert in ESLint, Prettier, and code style enforcement.

**When to Use:**
Use the `Linting Expert Agent` when you need linting and formatting specialist. expert in eslint, prettier, and code style enforcement..

**Usage:**
```bash
/agent run quality/linting-expert.md <instructions>
```

**Related Agents:**
[Code Reviewer Agent](#code-reviewer), [Dependency Manager Agent](#dependency-manager), [Documentation Linter Agent](#doc-linter-agent)

---

### <a id='performance-analyst'></a>Performance Analyst Agent

**Description:** Performance analysis specialist. Expert in profiling, bottleneck identification, and optimization strategies.

**When to Use:**
Use the `Performance Analyst Agent` when you need performance analysis specialist. expert in profiling, bottleneck identification, and optimization strategies..

**Usage:**
```bash
/agent run quality/performance-analyst.md <instructions>
```

**Related Agents:**
[Code Reviewer Agent](#code-reviewer), [Dependency Manager Agent](#dependency-manager), [Documentation Linter Agent](#doc-linter-agent)

---

### <a id='product-analyst'></a>Product Analyst Agent

**Description:** Product analysis specialist. Expert in requirements gathering, user stories, and feature prioritization.

**When to Use:**
Use the `Product Analyst Agent` when you need product analysis specialist. expert in requirements gathering, user stories, and feature prioritization..

**Usage:**
```bash
/agent run quality/product-analyst.md <instructions>
```

**Related Agents:**
[Code Reviewer Agent](#code-reviewer), [Dependency Manager Agent](#dependency-manager), [Documentation Linter Agent](#doc-linter-agent)

---

### <a id='refactoring-expert'></a>Refactoring Expert Agent

**Description:** Code refactoring specialist. Expert in refactoring patterns, code smells, and safe transformations.

**When to Use:**
Use the `Refactoring Expert Agent` when you need code refactoring specialist. expert in refactoring patterns, code smells, and safe transformations..

**Usage:**
```bash
/agent run quality/refactoring-expert.md <instructions>
```

**Related Agents:**
[Code Reviewer Agent](#code-reviewer), [Dependency Manager Agent](#dependency-manager), [Documentation Linter Agent](#doc-linter-agent)

---

### <a id='semantic-search-agent'></a>Semantic Code Search Agent

**Description:** You are the **Semantic Code Search Agent**, a specialized sub-agent responsible for intelligent code retrieval, understanding user intent, and uncovering hidden relationships within the codebase. You go beyond grep/keyword search to understand *what* the code does, not just *what text* it contains.

**When to Use:**
Use the `Semantic Code Search Agent` when you need you are the **semantic code search agent**, a specialized sub-agent responsible for intelligent code retrieval, understanding user intent, and uncovering hidden relationships within the codebase. you go beyond grep/keyword search to understand *what* the code does, not just *what text* it contains..

**Usage:**
```bash
/agent run quality/semantic-search-agent.md <instructions>
```

**Related Agents:**
[Code Reviewer Agent](#code-reviewer), [Dependency Manager Agent](#dependency-manager), [Documentation Linter Agent](#doc-linter-agent)

---

### <a id='technical-debt-analyst'></a>Technical Debt Analyst Agent

**Description:** Technical debt specialist. Expert in debt identification, prioritization, and reduction strategies.

**When to Use:**
Use the `Technical Debt Analyst Agent` when you need technical debt specialist. expert in debt identification, prioritization, and reduction strategies..

**Usage:**
```bash
/agent run quality/technical-debt-analyst.md <instructions>
```

**Related Agents:**
[Code Reviewer Agent](#code-reviewer), [Dependency Manager Agent](#dependency-manager), [Documentation Linter Agent](#doc-linter-agent)

---

## Security & Compliance

### <a id='compliance-expert'></a>Compliance Expert Agent

**Description:** Security compliance specialist. Expert in SOC2, GDPR, HIPAA, and compliance frameworks.

**When to Use:**
Use the `Compliance Expert Agent` when you need security compliance specialist. expert in soc2, gdpr, hipaa, and compliance frameworks..

**Usage:**
```bash
/agent run security/compliance-expert.md <instructions>
```

**Related Agents:**
[Dependency Auditor Agent](#dependency-auditor), ["Guardrails Enforcement Agent"](#guardrails-agent), [Penetration Testing Agent](#penetration-tester)

---

### <a id='dependency-auditor'></a>Dependency Auditor Agent

**Description:** Dependency security auditor. Expert in supply chain security and dependency management.

**When to Use:**
Use the `Dependency Auditor Agent` when you need dependency security auditor. expert in supply chain security and dependency management..

**Usage:**
```bash
/agent run security/dependency-auditor.md <instructions>
```

**Related Agents:**
[Compliance Expert Agent](#compliance-expert), ["Guardrails Enforcement Agent"](#guardrails-agent), [Penetration Testing Agent](#penetration-tester)

---

### <a id='guardrails-agent'></a>"Guardrails Enforcement Agent"

**Description:** "Security compliance agent responsible for pre-execution validation of tool calls, enforcing EU AI Act & ISO 42001 standards, and maintaining immutable audit trails."

**When to Use:**
Use the `"Guardrails Enforcement Agent"` when you need "security compliance agent responsible for pre-execution validation of tool calls, enforcing eu ai act & iso 42001 standards, and maintaining immutable audit trails.".

**Usage:**
```bash
/agent run security/guardrails-agent.md <instructions>
```

**Related Agents:**
[Compliance Expert Agent](#compliance-expert), [Dependency Auditor Agent](#dependency-auditor), [Penetration Testing Agent](#penetration-tester)

---

### <a id='penetration-tester'></a>Penetration Testing Agent

**Description:** Penetration testing specialist for authorized security testing, CTF challenges, and defensive security.

**When to Use:**
Use the `Penetration Testing Agent` when you need penetration testing specialist for authorized security testing, ctf challenges, and defensive security..

**Usage:**
```bash
/agent run security/penetration-tester.md <instructions>
```

**Related Agents:**
[Compliance Expert Agent](#compliance-expert), [Dependency Auditor Agent](#dependency-auditor), ["Guardrails Enforcement Agent"](#guardrails-agent)

---

### <a id='regulatory-compliance-agent'></a>regulatory-compliance-agent

**Description:** Specialized security agent for auditing and ensuring compliance with AI and data regulations including EU AI Act, ISO 42001, GDPR, and SOC2.

**When to Use:**
Use the `regulatory-compliance-agent` when you need specialized security agent for auditing and ensuring compliance with ai and data regulations including eu ai act, iso 42001, gdpr, and soc2..

**Usage:**
```bash
/agent run security/regulatory-compliance-agent.md <instructions>
```

**Related Agents:**
[Compliance Expert Agent](#compliance-expert), [Dependency Auditor Agent](#dependency-auditor), ["Guardrails Enforcement Agent"](#guardrails-agent)

---

### <a id='secrets-management-expert'></a>Secrets Management Expert Agent

**Description:** Secrets management specialist. Expert in vault systems, environment variables, and secure credential handling.

**When to Use:**
Use the `Secrets Management Expert Agent` when you need secrets management specialist. expert in vault systems, environment variables, and secure credential handling..

**Usage:**
```bash
/agent run security/secrets-management-expert.md <instructions>
```

**Related Agents:**
[Compliance Expert Agent](#compliance-expert), [Dependency Auditor Agent](#dependency-auditor), ["Guardrails Enforcement Agent"](#guardrails-agent)

---

### <a id='security-expert'></a>Security Expert Agent

**Description:** Application security specialist. Expert in OWASP Top 10, secure coding, and vulnerability assessment.

**When to Use:**
Use the `Security Expert Agent` when you need application security specialist. expert in owasp top 10, secure coding, and vulnerability assessment..

**Usage:**
```bash
/agent run security/security-expert.md <instructions>
```

**Related Agents:**
[Compliance Expert Agent](#compliance-expert), [Dependency Auditor Agent](#dependency-auditor), ["Guardrails Enforcement Agent"](#guardrails-agent)

---

### <a id='vulnerability-scanner'></a>Vulnerability Scanner Agent

**Description:** Vulnerability scanning specialist. Expert in dependency scanning, SAST, and security automation.

**When to Use:**
Use the `Vulnerability Scanner Agent` when you need vulnerability scanning specialist. expert in dependency scanning, sast, and security automation..

**Usage:**
```bash
/agent run security/vulnerability-scanner.md <instructions>
```

**Related Agents:**
[Compliance Expert Agent](#compliance-expert), [Dependency Auditor Agent](#dependency-auditor), ["Guardrails Enforcement Agent"](#guardrails-agent)

---

## Testing & QA

### <a id='api-contract-agent'></a>"API Contract Testing Agent"

**Description:** "Specialized agent for API contract validation, consumer-driven contract testing (Pact), and schema compatibility enforcement."

**When to Use:**
Use the `"API Contract Testing Agent"` when you need "specialized agent for api contract validation, consumer-driven contract testing (pact), and schema compatibility enforcement.".

**Usage:**
```bash
/agent run testing/api-contract-agent.md <instructions>
```

**Related Agents:**
[API Test Expert Agent](#api-test-expert), [E2E Test Expert Agent](#e2e-test-expert), [Integration Test Expert Agent](#integration-test-expert)

---

### <a id='api-test-expert'></a>API Test Expert Agent

**Description:** API testing specialist. Expert in REST/GraphQL testing, contract testing, and API validation.

**Key Capabilities:**
- REST API testing
- GraphQL testing
- Contract testing (Pact)
- Schema validation
- Load testing

**When to Use:**
Use the `API Test Expert Agent` when you need api testing specialist. expert in rest/graphql testing, contract testing, and api validation..

**Usage:**
```bash
/agent run testing/api-test-expert.md <instructions>
```

**Related Agents:**
["API Contract Testing Agent"](#api-contract-agent), [E2E Test Expert Agent](#e2e-test-expert), [Integration Test Expert Agent](#integration-test-expert)

---

### <a id='e2e-test-expert'></a>E2E Test Expert Agent

**Description:** End-to-end testing specialist. Expert in Playwright, Cypress, and full system testing.

**Key Capabilities:**
- Playwright / Cypress
- Page Object Model
- Test parallelization
- Visual regression
- Cross-browser testing

**When to Use:**
Use the `E2E Test Expert Agent` when you need end-to-end testing specialist. expert in playwright, cypress, and full system testing..

**Usage:**
```bash
/agent run testing/e2e-test-expert.md <instructions>
```

**Related Agents:**
["API Contract Testing Agent"](#api-contract-agent), [API Test Expert Agent](#api-test-expert), [Integration Test Expert Agent](#integration-test-expert)

---

### <a id='integration-test-expert'></a>Integration Test Expert Agent

**Description:** Integration testing specialist. Expert in API testing, database testing, and service integration tests.

**Key Capabilities:**
- API testing
- Database testing
- Test containers
- Test data management
- CI integration

**When to Use:**
Use the `Integration Test Expert Agent` when you need integration testing specialist. expert in api testing, database testing, and service integration tests..

**Usage:**
```bash
/agent run testing/integration-test-expert.md <instructions>
```

**Related Agents:**
["API Contract Testing Agent"](#api-contract-agent), [API Test Expert Agent](#api-test-expert), [E2E Test Expert Agent](#e2e-test-expert)

---

### <a id='performance-test-expert'></a>Performance Test Expert Agent

**Description:** Performance testing specialist. Expert in load testing, stress testing, and performance benchmarking.

**Key Capabilities:**
- K6 / Locust / JMeter
- Load testing
- Stress testing
- Endurance testing
- Performance baselines

**When to Use:**
Use the `Performance Test Expert Agent` when you need performance testing specialist. expert in load testing, stress testing, and performance benchmarking..

**Usage:**
```bash
/agent run testing/performance-test-expert.md <instructions>
```

**Related Agents:**
["API Contract Testing Agent"](#api-contract-agent), [API Test Expert Agent](#api-test-expert), [E2E Test Expert Agent](#e2e-test-expert)

---

### <a id='tdd-coach'></a>TDD Coach Agent

**Description:** TDD coaching specialist. Expert in test-driven development, red-green-refactor cycle, and TDD best practices.

**When to Use:**
Use the `TDD Coach Agent` when you need tdd coaching specialist. expert in test-driven development, red-green-refactor cycle, and tdd best practices..

**Usage:**
```bash
/agent run testing/tdd-coach.md <instructions>
```

**Related Agents:**
["API Contract Testing Agent"](#api-contract-agent), [API Test Expert Agent](#api-test-expert), [E2E Test Expert Agent](#e2e-test-expert)

---

### <a id='test-architect'></a>Test Architect Agent

**Description:** Test architecture specialist. Expert in test strategy, pyramid design, and testing infrastructure.

**When to Use:**
Use the `Test Architect Agent` when you need test architecture specialist. expert in test strategy, pyramid design, and testing infrastructure..

**Usage:**
```bash
/agent run testing/test-architect.md <instructions>
```

**Related Agents:**
["API Contract Testing Agent"](#api-contract-agent), [API Test Expert Agent](#api-test-expert), [E2E Test Expert Agent](#e2e-test-expert)

---

### <a id='test-data-expert'></a>Test Data Expert Agent

**Description:** Test data management specialist. Expert in fixtures, factories, and test data strategies.

**Key Capabilities:**
- Factory patterns (FactoryBot, Faker)
- Fixture management
- Data anonymization
- Test database seeding
- Data generators

**When to Use:**
Use the `Test Data Expert Agent` when you need test data management specialist. expert in fixtures, factories, and test data strategies..

**Usage:**
```bash
/agent run testing/test-data-expert.md <instructions>
```

**Related Agents:**
["API Contract Testing Agent"](#api-contract-agent), [API Test Expert Agent](#api-test-expert), [E2E Test Expert Agent](#e2e-test-expert)

---

### <a id='unit-test-expert'></a>Unit Test Expert Agent

**Description:** Unit testing specialist. Expert in mocking, test isolation, TDD, and unit test patterns.

**Key Capabilities:**
- Jest / Vitest / pytest
- Mocking strategies
- Test isolation
- TDD workflow
- Assertion patterns

**When to Use:**
Use the `Unit Test Expert Agent` when you need unit testing specialist. expert in mocking, test isolation, tdd, and unit test patterns..

**Usage:**
```bash
/agent run testing/unit-test-expert.md <instructions>
```

**Related Agents:**
["API Contract Testing Agent"](#api-contract-agent), [API Test Expert Agent](#api-test-expert), [E2E Test Expert Agent](#e2e-test-expert)

---

