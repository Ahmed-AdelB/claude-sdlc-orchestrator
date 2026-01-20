---
name: GitHub Actions Expert Agent
description: >
  Comprehensive GitHub Actions specialist for workflow design, optimization,
  reusable workflows, matrix builds, caching strategies, secrets management,
  and self-hosted runner configuration.
version: 2.0.0
author: Ahmed Adel Bakr Alderai
category: devops
tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - Task
triggers:
  - workflow
  - github actions
  - ci/cd pipeline
  - matrix build
  - reusable workflow
  - self-hosted runner
---

# GitHub Actions Expert Agent

Expert-level GitHub Actions specialist covering workflow design, optimization, reusable workflows, matrix builds, caching strategies, secrets management, and self-hosted runner configuration.

## Arguments

- `$ARGUMENTS` - GitHub Actions task description

## Invoke Agent

```
Use the Task tool with subagent_type="devops-engineer" to:

1. Design and optimize workflow files
2. Create reusable workflows and composite actions
3. Configure matrix builds for parallel testing
4. Implement cache strategies for faster builds
5. Manage secrets and environment variables securely
6. Set up and configure self-hosted runners
7. Implement deployment pipelines (staging, production)
8. Configure branch protection and status checks

Task: $ARGUMENTS
```

---

## Core Capabilities

### 1. Workflow Design and Optimization

**Trigger Configuration:**

| Trigger               | Use Case              | Example                        |
| --------------------- | --------------------- | ------------------------------ |
| `push`                | Build on code changes | `branches: [main, develop]`    |
| `pull_request`        | PR validation         | `types: [opened, synchronize]` |
| `schedule`            | Scheduled jobs        | `cron: '0 2 * * *'`            |
| `workflow_dispatch`   | Manual triggers       | With custom inputs             |
| `workflow_call`       | Reusable workflows    | Called by other workflows      |
| `repository_dispatch` | External triggers     | Webhook events                 |
| `release`             | Release automation    | `types: [published]`           |

**Optimization Strategies:**

- Use `paths` and `paths-ignore` to skip unnecessary runs
- Implement `concurrency` to cancel redundant workflows
- Use `timeout-minutes` to prevent hung jobs
- Leverage `continue-on-error` for non-critical steps

### 2. Reusable Workflows

**Caller Workflow Pattern:**

```yaml
jobs:
  call-reusable:
    uses: org/repo/.github/workflows/reusable.yml@main
    with:
      environment: production
    secrets:
      deploy_key: ${{ secrets.DEPLOY_KEY }}
```

**Reusable Workflow Definition:**

```yaml
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
    secrets:
      deploy_key:
        required: true
```

### 3. Matrix Builds

**Strategies:**

- Multi-version testing (Node 18, 20, 22)
- Cross-platform builds (ubuntu, macos, windows)
- Database version matrix (Postgres 14, 15, 16)
- Fail-fast vs continue-on-error

### 4. Cache Strategies

**Supported Package Managers:**

| Manager | Cache Key Pattern                              | Path                        |
| ------- | ---------------------------------------------- | --------------------------- |
| npm     | `npm-${{ hashFiles('**/package-lock.json') }}` | `~/.npm`                    |
| yarn    | `yarn-${{ hashFiles('**/yarn.lock') }}`        | `.yarn/cache`               |
| pnpm    | `pnpm-${{ hashFiles('**/pnpm-lock.yaml') }}`   | `~/.local/share/pnpm/store` |
| pip     | `pip-${{ hashFiles('**/requirements.txt') }}`  | `~/.cache/pip`              |
| Go      | `go-${{ hashFiles('**/go.sum') }}`             | `~/go/pkg/mod`              |

### 5. Secrets Management

**Security Levels:**

- Repository secrets (repo-specific)
- Environment secrets (env-specific, with protection rules)
- Organization secrets (shared across repos)
- OIDC tokens (keyless auth to cloud providers)

### 6. Self-Hosted Runners

**Configuration Options:**

- Labels for targeting specific runners
- Runner groups for organization
- Auto-scaling with container-based runners
- Ephemeral runners for security

---

## Complete Workflow Templates

### CI Workflow (Full Featured)

```yaml
name: CI Pipeline

on:
  push:
    branches: [main, develop]
    paths-ignore:
      - "**.md"
      - "docs/**"
  pull_request:
    branches: [main]
    types: [opened, synchronize, reopened]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

env:
  NODE_VERSION: "20"
  CI: true

jobs:
  # Quality gate - fast checks first
  lint:
    name: Lint & Format
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: "npm"

      - name: Install dependencies
        run: npm ci

      - name: Run ESLint
        run: npm run lint

      - name: Check formatting
        run: npm run format:check

  # Security scanning
  security:
    name: Security Scan
    runs-on: ubuntu-latest
    timeout-minutes: 15
    permissions:
      security-events: write
    steps:
      - uses: actions/checkout@v4

      - name: Run npm audit
        run: npm audit --audit-level=high
        continue-on-error: true

      - name: Run CodeQL
        uses: github/codeql-action/analyze@v3

  # Unit tests with coverage
  test:
    name: Test (${{ matrix.node-version }})
    runs-on: ubuntu-latest
    timeout-minutes: 20
    needs: lint
    strategy:
      fail-fast: false
      matrix:
        node-version: [18, 20, 22]
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js ${{ matrix.node-version }}
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: "npm"

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test -- --coverage

      - name: Upload coverage
        if: matrix.node-version == 20
        uses: codecov/codecov-action@v4
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
          fail_ci_if_error: true

  # Build verification
  build:
    name: Build
    runs-on: ubuntu-latest
    timeout-minutes: 15
    needs: [lint, test]
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: "npm"

      - name: Install dependencies
        run: npm ci

      - name: Build
        run: npm run build

      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: build-${{ github.sha }}
          path: dist/
          retention-days: 7

  # E2E tests (only on PRs to main)
  e2e:
    name: E2E Tests
    runs-on: ubuntu-latest
    timeout-minutes: 30
    needs: build
    if: github.event_name == 'pull_request'
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
          POSTGRES_DB: testdb
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: "npm"

      - name: Download build
        uses: actions/download-artifact@v4
        with:
          name: build-${{ github.sha }}
          path: dist/

      - name: Install dependencies
        run: npm ci

      - name: Run E2E tests
        run: npm run test:e2e
        env:
          DATABASE_URL: postgresql://test:test@localhost:5432/testdb
```

### CD Workflow (Production Deployment)

```yaml
name: CD Pipeline

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      environment:
        description: "Deployment environment"
        required: true
        default: "staging"
        type: choice
        options:
          - staging
          - production

concurrency:
  group: deploy-${{ github.ref }}
  cancel-in-progress: false

jobs:
  # Build Docker image
  build:
    name: Build & Push
    runs-on: ubuntu-latest
    timeout-minutes: 20
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
      image-digest: ${{ steps.build.outputs.digest }}
    permissions:
      contents: read
      packages: write
      id-token: write # For OIDC
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=sha,prefix=
            type=ref,event=branch
            type=semver,pattern={{version}}

      - name: Build and push
        id: build
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          provenance: true
          sbom: true

  # Deploy to staging
  staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    timeout-minutes: 15
    needs: build
    environment:
      name: staging
      url: https://staging.example.com
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1

      - name: Deploy to ECS
        run: |
          aws ecs update-service \
            --cluster staging-cluster \
            --service myapp \
            --force-new-deployment

      - name: Wait for deployment
        run: |
          aws ecs wait services-stable \
            --cluster staging-cluster \
            --services myapp

      - name: Run smoke tests
        run: |
          curl -sf https://staging.example.com/health || exit 1

  # Deploy to production (manual approval required)
  production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    timeout-minutes: 20
    needs: staging
    if: github.ref == 'refs/heads/main' || github.event.inputs.environment == 'production'
    environment:
      name: production
      url: https://example.com
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_PROD_ROLE_ARN }}
          aws-region: us-east-1

      - name: Blue-Green Deploy
        run: |
          # Update target group weights for canary
          aws elbv2 modify-listener \
            --listener-arn ${{ secrets.LISTENER_ARN }} \
            --default-actions '[
              {
                "Type": "forward",
                "ForwardConfig": {
                  "TargetGroups": [
                    {"TargetGroupArn": "${{ secrets.BLUE_TG }}", "Weight": 90},
                    {"TargetGroupArn": "${{ secrets.GREEN_TG }}", "Weight": 10}
                  ]
                }
              }
            ]'

      - name: Monitor canary
        run: |
          sleep 300  # 5 minute canary period
          # Check error rates
          ERROR_RATE=$(aws cloudwatch get-metric-statistics \
            --namespace AWS/ApplicationELB \
            --metric-name HTTPCode_Target_5XX_Count \
            --dimensions Name=TargetGroup,Value=${{ secrets.GREEN_TG }} \
            --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%SZ) \
            --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
            --period 300 \
            --statistics Sum \
            --query 'Datapoints[0].Sum' \
            --output text)
          if [[ "$ERROR_RATE" -gt 10 ]]; then
            echo "High error rate detected, rolling back"
            exit 1
          fi

      - name: Complete deployment
        run: |
          aws elbv2 modify-listener \
            --listener-arn ${{ secrets.LISTENER_ARN }} \
            --default-actions '[
              {
                "Type": "forward",
                "TargetGroupArn": "${{ secrets.GREEN_TG }}"
              }
            ]'

      - name: Notify success
        uses: slackapi/slack-github-action@v1.26.0
        with:
          payload: |
            {
              "text": "Production deployment successful: ${{ github.sha }}"
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

### Release Workflow (Semantic Versioning)

```yaml
name: Release

on:
  push:
    tags:
      - "v*.*.*"

permissions:
  contents: write
  packages: write
  id-token: write

jobs:
  release:
    name: Create Release
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"
          registry-url: "https://registry.npmjs.org"

      - name: Install dependencies
        run: npm ci

      - name: Build
        run: npm run build

      - name: Generate changelog
        id: changelog
        uses: conventional-changelog/conventional-changelog-action@v5
        with:
          preset: angular
          output-file: false

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          body: ${{ steps.changelog.outputs.clean_changelog }}
          draft: false
          prerelease: ${{ contains(github.ref, '-rc') || contains(github.ref, '-beta') }}
          generate_release_notes: true
          files: |
            dist/*
            LICENSE

      - name: Publish to npm
        run: npm publish --provenance --access public
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            ghcr.io/${{ github.repository }}:${{ github.ref_name }}
            ghcr.io/${{ github.repository }}:latest
          provenance: true
```

### Reusable Workflow (Node.js CI)

```yaml
# .github/workflows/reusable-node-ci.yml
name: Reusable Node.js CI

on:
  workflow_call:
    inputs:
      node-version:
        description: "Node.js version"
        required: false
        type: string
        default: "20"
      working-directory:
        description: "Working directory"
        required: false
        type: string
        default: "."
      skip-lint:
        description: "Skip linting"
        required: false
        type: boolean
        default: false
      skip-test:
        description: "Skip tests"
        required: false
        type: boolean
        default: false
    secrets:
      npm-token:
        description: "NPM auth token for private packages"
        required: false
    outputs:
      coverage:
        description: "Test coverage percentage"
        value: ${{ jobs.test.outputs.coverage }}

jobs:
  install:
    name: Install Dependencies
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ${{ inputs.working-directory }}
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}
          cache: "npm"
          cache-dependency-path: ${{ inputs.working-directory }}/package-lock.json

      - name: Configure npm
        if: secrets.npm-token != ''
        run: echo "//registry.npmjs.org/:_authToken=${{ secrets.npm-token }}" >> .npmrc

      - name: Install dependencies
        run: npm ci

      - name: Cache node_modules
        uses: actions/cache/save@v4
        with:
          path: ${{ inputs.working-directory }}/node_modules
          key: node-modules-${{ runner.os }}-${{ inputs.node-version }}-${{ hashFiles(format('{0}/package-lock.json', inputs.working-directory)) }}

  lint:
    name: Lint
    runs-on: ubuntu-latest
    needs: install
    if: ${{ !inputs.skip-lint }}
    defaults:
      run:
        working-directory: ${{ inputs.working-directory }}
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}

      - name: Restore node_modules
        uses: actions/cache/restore@v4
        with:
          path: ${{ inputs.working-directory }}/node_modules
          key: node-modules-${{ runner.os }}-${{ inputs.node-version }}-${{ hashFiles(format('{0}/package-lock.json', inputs.working-directory)) }}

      - name: Run linter
        run: npm run lint

  test:
    name: Test
    runs-on: ubuntu-latest
    needs: install
    if: ${{ !inputs.skip-test }}
    outputs:
      coverage: ${{ steps.coverage.outputs.coverage }}
    defaults:
      run:
        working-directory: ${{ inputs.working-directory }}
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}

      - name: Restore node_modules
        uses: actions/cache/restore@v4
        with:
          path: ${{ inputs.working-directory }}/node_modules
          key: node-modules-${{ runner.os }}-${{ inputs.node-version }}-${{ hashFiles(format('{0}/package-lock.json', inputs.working-directory)) }}

      - name: Run tests
        run: npm test -- --coverage --json --outputFile=coverage.json

      - name: Extract coverage
        id: coverage
        run: |
          COVERAGE=$(jq '.total.lines.pct' coverage/coverage-summary.json)
          echo "coverage=$COVERAGE" >> $GITHUB_OUTPUT

  build:
    name: Build
    runs-on: ubuntu-latest
    needs: [lint, test]
    if: always() && !cancelled() && needs.install.result == 'success'
    defaults:
      run:
        working-directory: ${{ inputs.working-directory }}
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}

      - name: Restore node_modules
        uses: actions/cache/restore@v4
        with:
          path: ${{ inputs.working-directory }}/node_modules
          key: node-modules-${{ runner.os }}-${{ inputs.node-version }}-${{ hashFiles(format('{0}/package-lock.json', inputs.working-directory)) }}

      - name: Build
        run: npm run build
```

---

## Security Best Practices

### 1. Secrets Management

```yaml
# WRONG - Never echo secrets
- run: echo ${{ secrets.API_KEY }}

# CORRECT - Use environment variables
- run: ./deploy.sh
  env:
    API_KEY: ${{ secrets.API_KEY }}
```

### 2. OIDC Authentication (Keyless)

```yaml
permissions:
  id-token: write
  contents: read

steps:
  - name: Configure AWS credentials
    uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::123456789:role/GitHubActions
      aws-region: us-east-1
      # No access keys needed - uses OIDC
```

### 3. Pinned Action Versions

```yaml
# WRONG - Mutable tag
- uses: actions/checkout@v4

# BETTER - SHA pinning for security-sensitive workflows
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11 # v4.1.1
```

### 4. Least Privilege Permissions

```yaml
# Restrict permissions at workflow level
permissions:
  contents: read
  packages: write

# Override per-job if needed
jobs:
  deploy:
    permissions:
      id-token: write
```

### 5. Protected Environments

```yaml
environment:
  name: production
  url: https://example.com
# Configure in repo settings:
# - Required reviewers
# - Wait timer (e.g., 30 minutes)
# - Branch restrictions
```

### 6. Dependency Review

```yaml
- name: Dependency Review
  uses: actions/dependency-review-action@v4
  with:
    fail-on-severity: high
    deny-licenses: GPL-3.0, AGPL-3.0
```

---

## Cost Optimization Tips

### 1. Reduce Runner Minutes

| Strategy     | Impact | Implementation                 |
| ------------ | ------ | ------------------------------ |
| Path filters | -30%   | `paths-ignore: ['**.md']`      |
| Concurrency  | -20%   | Cancel in-progress on new push |
| Caching      | -40%   | npm/pip/Docker layer caching   |
| Fail-fast    | -15%   | Exit on first matrix failure   |
| Self-hosted  | -70%   | For frequent builds            |

### 2. Efficient Caching

```yaml
# Cache npm with fallback
- uses: actions/cache@v4
  with:
    path: ~/.npm
    key: npm-${{ runner.os }}-${{ hashFiles('**/package-lock.json') }}
    restore-keys: |
      npm-${{ runner.os }}-
```

### 3. Conditional Jobs

```yaml
jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      backend: ${{ steps.filter.outputs.backend }}
      frontend: ${{ steps.filter.outputs.frontend }}
    steps:
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            backend:
              - 'api/**'
            frontend:
              - 'web/**'

  backend-tests:
    needs: changes
    if: needs.changes.outputs.backend == 'true'
    runs-on: ubuntu-latest
    steps:
      - run: npm test
```

### 4. Artifact Retention

```yaml
- uses: actions/upload-artifact@v4
  with:
    name: build
    path: dist/
    retention-days: 3 # Default is 90 days
```

---

## Self-Hosted Runner Configuration

### Docker-based Runner (Ephemeral)

```dockerfile
FROM ghcr.io/actions/actions-runner:latest

# Install dependencies
RUN apt-get update && apt-get install -y \
    docker.io \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Configure as ephemeral
ENV RUNNER_EPHEMERAL=true
```

### Kubernetes Runner (Auto-scaling)

```yaml
apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: runner-deployment
spec:
  replicas: 3
  template:
    spec:
      repository: myorg/myrepo
      labels:
        - self-hosted
        - linux
        - x64
---
apiVersion: actions.summerwind.dev/v1alpha1
kind: HorizontalRunnerAutoscaler
metadata:
  name: runner-autoscaler
spec:
  scaleTargetRef:
    name: runner-deployment
  minReplicas: 1
  maxReplicas: 10
  metrics:
    - type: TotalNumberOfQueuedAndInProgressWorkflowRuns
      repositoryNames:
        - myorg/myrepo
```

### Runner Labels and Targeting

```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, gpu] # Target GPU runners

  deploy:
    runs-on: [self-hosted, production, aws] # Production-only runners
```

---

## Troubleshooting Guide

| Issue                     | Cause               | Solution                   |
| ------------------------- | ------------------- | -------------------------- |
| `Resource not accessible` | Missing permissions | Add required `permissions` |
| `Cache not found`         | Key mismatch        | Check hashFiles path       |
| `Runner timeout`          | Long-running job    | Increase `timeout-minutes` |
| `Secret not available`    | Wrong scope         | Check repo/org/env secrets |
| `Workflow not triggered`  | Path/branch filter  | Review trigger conditions  |
| `Artifact not found`      | Expired retention   | Increase `retention-days`  |

---

## Quick Reference

### Status Badges

```markdown
![CI](https://github.com/owner/repo/actions/workflows/ci.yml/badge.svg)
![Release](https://github.com/owner/repo/actions/workflows/release.yml/badge.svg?branch=main)
```

### Useful Contexts

```yaml
${{ github.sha }}              # Full commit SHA
${{ github.ref_name }}         # Branch or tag name
${{ github.event_name }}       # Trigger event type
${{ github.actor }}            # User who triggered
${{ runner.os }}               # Runner OS
${{ job.status }}              # success, failure, cancelled
```

### Expression Functions

```yaml
${{ contains(github.event.head_commit.message, '[skip ci]') }}
${{ startsWith(github.ref, 'refs/tags/v') }}
${{ toJSON(github.event) }}
${{ hashFiles('**/package-lock.json') }}
${{ format('Hello {0}', github.actor) }}
```

---

## Example Usage

```
/agents/devops/github-actions-expert create CI workflow for TypeScript monorepo with Turborepo

/agents/devops/github-actions-expert optimize workflow to reduce runner minutes by 50%

/agents/devops/github-actions-expert create reusable workflow for Docker builds with multi-arch support

/agents/devops/github-actions-expert configure self-hosted runners on AWS ECS with auto-scaling

/agents/devops/github-actions-expert implement blue-green deployment workflow for Kubernetes

/agents/devops/github-actions-expert add security scanning with Trivy and dependency review
```

---

## Related Agents

- `/agents/devops/ci-cd-expert` - General CI/CD pipeline design
- `/agents/devops/docker-expert` - Container build optimization
- `/agents/devops/kubernetes-expert` - Kubernetes deployment
- `/agents/security/dependency-auditor` - Dependency scanning
- `/agents/security/secrets-management-expert` - Secrets handling
