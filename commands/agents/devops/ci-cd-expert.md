---
name: CI/CD Expert Agent
description: Comprehensive CI/CD specialist for pipeline design, build automation, deployment strategies, and DevSecOps practices
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
integrates_with:
  - /agents/devops/docker-expert
  - /agents/devops/kubernetes-expert
  - /agents/devops/github-actions-expert
  - /agents/devops/terraform-expert
  - /agents/security/secrets-management-expert
  - /agents/security/vulnerability-scanner
  - /agents/testing/integration-test-expert
---

# CI/CD Expert Agent

Comprehensive CI/CD specialist. Expert in pipeline design, build automation, deployment strategies, and DevSecOps practices across GitHub Actions, GitLab CI/CD, Jenkins, and other CI/CD platforms.

## Arguments

- `$ARGUMENTS` - CI/CD task, pipeline design request, or deployment strategy

## Invoke Agent

```
Use the Task tool with subagent_type="ci-cd-expert" to:

1. Design CI/CD pipelines (GitHub Actions, GitLab CI, Jenkins)
2. Implement deployment strategies (blue-green, canary, rolling)
3. Configure build optimization and caching
4. Set up secret management in pipelines
5. Implement quality gates and security scanning
6. Create reusable pipeline components
7. Troubleshoot pipeline failures

Task: $ARGUMENTS
```

---

## Platform Expertise

| Platform        | Configuration File        | Strengths                                      |
| --------------- | ------------------------- | ---------------------------------------------- |
| GitHub Actions  | `.github/workflows/*.yml` | Native GitHub integration, Actions marketplace |
| GitLab CI/CD    | `.gitlab-ci.yml`          | Built-in container registry, Auto DevOps       |
| Jenkins         | `Jenkinsfile`             | Extensive plugins, on-premise control          |
| CircleCI        | `.circleci/config.yml`    | Fast builds, orbs ecosystem                    |
| Azure Pipelines | `azure-pipelines.yml`     | Azure integration, YAML templates              |

---

## GitHub Actions Workflow Templates

### Standard CI Pipeline

```yaml
name: CI Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

env:
  NODE_VERSION: "20"
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: "npm"
      - run: npm ci
      - run: npm run lint

  test:
    runs-on: ubuntu-latest
    needs: lint
    strategy:
      matrix:
        node-version: [18, 20, 22]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: "npm"
      - run: npm ci
      - run: npm run test -- --coverage
      - uses: codecov/codecov-action@v4
        with:
          token: ${{ secrets.CODECOV_TOKEN }}

  security:
    runs-on: ubuntu-latest
    needs: lint
    steps:
      - uses: actions/checkout@v4
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: "fs"
          scan-ref: "."
          severity: "CRITICAL,HIGH"
          exit-code: "1"
      - name: Run npm audit
        run: npm audit --audit-level=high

  build:
    runs-on: ubuntu-latest
    needs: [test, security]
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v5
        with:
          context: .
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

### Reusable Workflow Template

```yaml
# .github/workflows/deploy-reusable.yml
name: Reusable Deploy Workflow

on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
      version:
        required: true
        type: string
    secrets:
      DEPLOY_TOKEN:
        required: true
      KUBECONFIG:
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    steps:
      - uses: actions/checkout@v4
      - name: Set up kubectl
        uses: azure/setup-kubectl@v3
      - name: Configure kubeconfig
        run: echo "${{ secrets.KUBECONFIG }}" | base64 -d > kubeconfig
      - name: Deploy
        env:
          KUBECONFIG: kubeconfig
        run: |
          kubectl set image deployment/app \
            app=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ inputs.version }}
          kubectl rollout status deployment/app
```

---

## GitLab CI/CD Pipeline Templates

### Full Pipeline with Stages

```yaml
# .gitlab-ci.yml
stages:
  - validate
  - test
  - security
  - build
  - deploy

variables:
  DOCKER_TLS_CERTDIR: "/certs"
  REGISTRY: registry.gitlab.com
  IMAGE_TAG: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA

default:
  image: node:20-alpine
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/
      - .npm/

.deploy_template: &deploy_template
  image: bitnami/kubectl:latest
  before_script:
    - kubectl config set-cluster k8s --server=$KUBE_URL --certificate-authority=$KUBE_CA
    - kubectl config set-credentials deploy --token=$KUBE_TOKEN
    - kubectl config set-context deploy --cluster=k8s --user=deploy --namespace=$KUBE_NAMESPACE
    - kubectl config use-context deploy

lint:
  stage: validate
  script:
    - npm ci --cache .npm --prefer-offline
    - npm run lint
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

test:
  stage: test
  script:
    - npm ci --cache .npm --prefer-offline
    - npm run test:coverage
  coverage: '/Lines\s*:\s*(\d+\.?\d*)%/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml
    expire_in: 1 week

sast:
  stage: security
  image: returntocorp/semgrep
  script:
    - semgrep ci --config auto
  allow_failure: true

container_scanning:
  stage: security
  image: docker:stable
  services:
    - docker:dind
  script:
    - docker build -t $IMAGE_TAG .
    - docker run --rm -v /var/run/docker.sock:/var/run/docker.sock
      aquasec/trivy image --exit-code 1 --severity HIGH,CRITICAL $IMAGE_TAG

build:
  stage: build
  image: docker:stable
  services:
    - docker:dind
  script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - docker build --cache-from $CI_REGISTRY_IMAGE:latest -t $IMAGE_TAG .
    - docker push $IMAGE_TAG
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

deploy_staging:
  stage: deploy
  <<: *deploy_template
  environment:
    name: staging
    url: https://staging.example.com
  script:
    - kubectl set image deployment/app app=$IMAGE_TAG
    - kubectl rollout status deployment/app --timeout=300s
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

deploy_production:
  stage: deploy
  <<: *deploy_template
  environment:
    name: production
    url: https://example.com
  script:
    - kubectl set image deployment/app app=$IMAGE_TAG
    - kubectl rollout status deployment/app --timeout=300s
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      when: manual
  needs:
    - deploy_staging
```

---

## Jenkins Pipeline Templates

### Declarative Pipeline

```groovy
// Jenkinsfile
pipeline {
    agent {
        kubernetes {
            yaml '''
            apiVersion: v1
            kind: Pod
            spec:
              containers:
              - name: node
                image: node:20-alpine
                command: ['sleep', 'infinity']
              - name: docker
                image: docker:dind
                securityContext:
                  privileged: true
            '''
        }
    }

    environment {
        REGISTRY = 'registry.example.com'
        IMAGE_NAME = 'myapp'
        DOCKER_CREDS = credentials('docker-registry')
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install') {
            steps {
                container('node') {
                    sh 'npm ci'
                }
            }
        }

        stage('Parallel Checks') {
            parallel {
                stage('Lint') {
                    steps {
                        container('node') {
                            sh 'npm run lint'
                        }
                    }
                }
                stage('Test') {
                    steps {
                        container('node') {
                            sh 'npm run test -- --coverage'
                        }
                    }
                    post {
                        always {
                            publishHTML([
                                reportDir: 'coverage/lcov-report',
                                reportFiles: 'index.html',
                                reportName: 'Coverage Report'
                            ])
                        }
                    }
                }
                stage('Security Scan') {
                    steps {
                        container('node') {
                            sh 'npm audit --audit-level=high'
                        }
                    }
                }
            }
        }

        stage('Build Image') {
            when {
                branch 'main'
            }
            steps {
                container('docker') {
                    sh '''
                        docker login -u $DOCKER_CREDS_USR -p $DOCKER_CREDS_PSW $REGISTRY
                        docker build -t $REGISTRY/$IMAGE_NAME:$BUILD_NUMBER .
                        docker push $REGISTRY/$IMAGE_NAME:$BUILD_NUMBER
                    '''
                }
            }
        }

        stage('Deploy to Staging') {
            when {
                branch 'main'
            }
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh '''
                        kubectl set image deployment/myapp \
                            myapp=$REGISTRY/$IMAGE_NAME:$BUILD_NUMBER
                        kubectl rollout status deployment/myapp --timeout=300s
                    '''
                }
            }
        }

        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            input {
                message 'Deploy to production?'
                ok 'Deploy'
            }
            steps {
                withCredentials([file(credentialsId: 'kubeconfig-prod', variable: 'KUBECONFIG')]) {
                    sh '''
                        kubectl set image deployment/myapp \
                            myapp=$REGISTRY/$IMAGE_NAME:$BUILD_NUMBER
                        kubectl rollout status deployment/myapp --timeout=300s
                    '''
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        failure {
            slackSend(
                color: 'danger',
                message: "Build Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
            )
        }
        success {
            slackSend(
                color: 'good',
                message: "Build Succeeded: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
            )
        }
    }
}
```

### Shared Library Pattern

```groovy
// vars/standardPipeline.groovy
def call(Map config) {
    pipeline {
        agent any

        stages {
            stage('Build') {
                steps {
                    script {
                        docker.build("${config.imageName}:${env.BUILD_NUMBER}")
                    }
                }
            }

            stage('Test') {
                steps {
                    sh config.testCommand ?: 'npm test'
                }
            }

            stage('Deploy') {
                when {
                    branch 'main'
                }
                steps {
                    deployToKubernetes(
                        image: "${config.imageName}:${env.BUILD_NUMBER}",
                        namespace: config.namespace
                    )
                }
            }
        }
    }
}
```

---

## Deployment Strategies

### Blue-Green Deployment

```yaml
# GitHub Actions - Blue-Green
name: Blue-Green Deploy

on:
  workflow_dispatch:
    inputs:
      version:
        description: "Version to deploy"
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: azure/setup-kubectl@v3

      - name: Get current active color
        id: current
        run: |
          ACTIVE=$(kubectl get service app-prod -o jsonpath='{.spec.selector.color}')
          echo "active=$ACTIVE" >> $GITHUB_OUTPUT
          if [ "$ACTIVE" == "blue" ]; then
            echo "target=green" >> $GITHUB_OUTPUT
          else
            echo "target=blue" >> $GITHUB_OUTPUT
          fi

      - name: Deploy to inactive environment
        run: |
          kubectl set image deployment/app-${{ steps.current.outputs.target }} \
            app=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ inputs.version }}
          kubectl rollout status deployment/app-${{ steps.current.outputs.target }}

      - name: Run smoke tests
        run: |
          TARGET_URL=$(kubectl get service app-${{ steps.current.outputs.target }} \
            -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
          curl -f http://$TARGET_URL/health || exit 1

      - name: Switch traffic
        run: |
          kubectl patch service app-prod \
            -p '{"spec":{"selector":{"color":"${{ steps.current.outputs.target }}"}}}'

      - name: Verify switch
        run: |
          sleep 10
          HEALTH=$(curl -s https://app.example.com/health | jq -r '.status')
          [ "$HEALTH" == "healthy" ] || exit 1
```

### Canary Deployment

```yaml
# GitLab CI - Canary with Argo Rollouts
deploy_canary:
  stage: deploy
  script:
    - |
      kubectl apply -f - <<EOF
      apiVersion: argoproj.io/v1alpha1
      kind: Rollout
      metadata:
        name: app-rollout
      spec:
        replicas: 10
        strategy:
          canary:
            steps:
            - setWeight: 10
            - pause: {duration: 5m}
            - setWeight: 25
            - pause: {duration: 5m}
            - setWeight: 50
            - pause: {duration: 10m}
            - setWeight: 100
            analysis:
              templates:
              - templateName: success-rate
              startingStep: 1
        selector:
          matchLabels:
            app: myapp
        template:
          metadata:
            labels:
              app: myapp
          spec:
            containers:
            - name: app
              image: $IMAGE_TAG
      EOF
```

### Rolling Update

```yaml
# Kubernetes Rolling Update Config
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  replicas: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: app
          image: registry/app:latest
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 15
            periodSeconds: 20
```

---

## Build Optimization Strategies

### Caching Best Practices

```yaml
# GitHub Actions - Optimized Caching
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      # Node modules cache
      - uses: actions/cache@v4
        with:
          path: |
            ~/.npm
            node_modules
          key: node-${{ runner.os }}-${{ hashFiles('**/package-lock.json') }}
          restore-keys: |
            node-${{ runner.os }}-

      # Docker layer caching
      - uses: docker/build-push-action@v5
        with:
          context: .
          cache-from: |
            type=gha
            type=registry,ref=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:buildcache
          cache-to: |
            type=gha,mode=max
            type=registry,ref=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:buildcache,mode=max

      # Gradle cache
      - uses: actions/cache@v4
        with:
          path: |
            ~/.gradle/caches
            ~/.gradle/wrapper
          key: gradle-${{ runner.os }}-${{ hashFiles('**/*.gradle*', '**/gradle-wrapper.properties') }}

      # Maven cache
      - uses: actions/cache@v4
        with:
          path: ~/.m2/repository
          key: maven-${{ runner.os }}-${{ hashFiles('**/pom.xml') }}
```

### Parallel Execution

```yaml
# GitLab CI - Parallel Jobs
test:
  stage: test
  parallel:
    matrix:
      - TEST_SUITE: [unit, integration, e2e]
        NODE_VERSION: [18, 20]
  script:
    - npm run test:$TEST_SUITE
```

### Dockerfile Optimization

```dockerfile
# Multi-stage build with caching
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 appuser

COPY --from=deps --chown=appuser:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=appuser:nodejs /app/dist ./dist
COPY --from=builder --chown=appuser:nodejs /app/package.json ./

USER appuser
EXPOSE 3000

CMD ["node", "dist/main.js"]
```

---

## Secret Management in Pipelines

### GitHub Actions Secrets

```yaml
# Using GitHub Secrets
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Deploy with secrets
        env:
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
          API_KEY: ${{ secrets.API_KEY }}
        run: |
          # Secrets are masked in logs automatically
          ./deploy.sh

      # Using OIDC for cloud provider auth (no static secrets)
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/github-actions
          aws-region: us-east-1

      # External secrets management
      - name: Fetch secrets from Vault
        uses: hashicorp/vault-action@v2
        with:
          url: https://vault.example.com
          method: jwt
          role: github-actions
          secrets: |
            secret/data/app/prod api_key | API_KEY ;
            secret/data/app/prod db_password | DB_PASSWORD
```

### GitLab CI Secrets

```yaml
# GitLab CI/CD Variables
variables:
  # Masked and protected
  DEPLOY_TOKEN: $DEPLOY_TOKEN

deploy:
  script:
    # Using Vault integration
    - export VAULT_TOKEN=$(vault write -field=token auth/jwt/login role=gitlab jwt=$CI_JOB_JWT)
    - export DB_PASSWORD=$(vault kv get -field=password secret/app/db)
    - ./deploy.sh
  id_tokens:
    VAULT_ID_TOKEN:
      aud: https://vault.example.com
```

### Jenkins Credentials

```groovy
// Jenkins Credentials Binding
pipeline {
    agent any

    stages {
        stage('Deploy') {
            steps {
                withCredentials([
                    string(credentialsId: 'api-key', variable: 'API_KEY'),
                    usernamePassword(
                        credentialsId: 'db-creds',
                        usernameVariable: 'DB_USER',
                        passwordVariable: 'DB_PASS'
                    ),
                    file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')
                ]) {
                    sh '''
                        export API_KEY
                        export DB_USER DB_PASS
                        ./deploy.sh
                    '''
                }

                // HashiCorp Vault integration
                withVault(
                    configuration: [
                        vaultUrl: 'https://vault.example.com',
                        vaultCredentialId: 'vault-approle'
                    ],
                    vaultSecrets: [
                        [
                            path: 'secret/app/prod',
                            secretValues: [
                                [envVar: 'DB_PASSWORD', vaultKey: 'db_password'],
                                [envVar: 'API_SECRET', vaultKey: 'api_secret']
                            ]
                        ]
                    ]
                ) {
                    sh './deploy.sh'
                }
            }
        }
    }
}
```

---

## Security Best Practices

### Pipeline Security Checklist

| Category     | Practice                     | Implementation               |
| ------------ | ---------------------------- | ---------------------------- |
| Secrets      | Never hardcode secrets       | Use platform secret managers |
| Secrets      | Rotate credentials regularly | Automate with Vault/AWS SM   |
| Secrets      | Use OIDC for cloud auth      | Eliminate static credentials |
| Code         | Scan for vulnerabilities     | Trivy, Snyk, npm audit       |
| Code         | Static analysis (SAST)       | Semgrep, CodeQL, SonarQube   |
| Dependencies | Check for CVEs               | Dependabot, Renovate         |
| Images       | Scan container images        | Trivy, Clair, Anchore        |
| Images       | Use minimal base images      | Distroless, Alpine           |
| Access       | Principle of least privilege | Scoped tokens, RBAC          |
| Access       | Require PR reviews           | Branch protection rules      |
| Audit        | Log all pipeline runs        | Centralized logging          |
| Audit        | Sign commits and images      | GPG, Cosign                  |

### Security Scanning Integration

```yaml
# Comprehensive Security Pipeline
name: Security Checks

on:
  push:
    branches: [main]
  pull_request:
  schedule:
    - cron: "0 6 * * *"

jobs:
  sast:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Semgrep
        uses: returntocorp/semgrep-action@v1
        with:
          config: p/default p/security-audit p/owasp-top-ten

  dependency-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Snyk
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high

  container-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build image
        run: docker build -t app:${{ github.sha }} .
      - name: Run Trivy
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: app:${{ github.sha }}
          format: "sarif"
          output: "trivy-results.sarif"
          severity: "CRITICAL,HIGH"
      - name: Upload SARIF
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: "trivy-results.sarif"

  secret-scanning:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Run Gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## Quality Gates

### Merge Requirements

```yaml
# Branch protection + required checks
# Configure in repo settings or via Terraform

# Example quality gate checks
quality-gate:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4

    - name: Check test coverage
      run: |
        COVERAGE=$(cat coverage/coverage-summary.json | jq '.total.lines.pct')
        if (( $(echo "$COVERAGE < 80" | bc -l) )); then
          echo "Coverage $COVERAGE% is below 80% threshold"
          exit 1
        fi

    - name: Check linting
      run: npm run lint

    - name: Check no TODO in code
      run: |
        if grep -r "TODO" --include="*.ts" src/; then
          echo "Found TODO comments in code"
          exit 1
        fi

    - name: Check bundle size
      run: |
        SIZE=$(stat -f%z dist/bundle.js)
        MAX_SIZE=500000
        if [ $SIZE -gt $MAX_SIZE ]; then
          echo "Bundle size $SIZE exceeds limit $MAX_SIZE"
          exit 1
        fi
```

---

## Related Agents

| Agent                                        | Use Case                                   |
| -------------------------------------------- | ------------------------------------------ |
| `/agents/devops/docker-expert`               | Container optimization, multi-stage builds |
| `/agents/devops/kubernetes-expert`           | K8s deployments, Helm charts               |
| `/agents/devops/github-actions-expert`       | GitHub-specific workflows                  |
| `/agents/devops/terraform-expert`            | Infrastructure as Code for CI/CD resources |
| `/agents/security/secrets-management-expert` | Vault, AWS Secrets Manager                 |
| `/agents/security/vulnerability-scanner`     | Security scanning integration              |
| `/agents/testing/integration-test-expert`    | Pipeline test stages                       |

---

## Example Usage

```bash
# Design a complete CI/CD pipeline
/agents/devops/ci-cd-expert design GitHub Actions pipeline for Node.js monorepo with blue-green deployment

# Implement canary deployment
/agents/devops/ci-cd-expert implement canary deployment with Argo Rollouts for production

# Optimize build times
/agents/devops/ci-cd-expert optimize build caching for Python project with Docker

# Set up secret management
/agents/devops/ci-cd-expert configure HashiCorp Vault integration for GitLab CI

# Migrate from Jenkins to GitHub Actions
/agents/devops/ci-cd-expert migrate Jenkins pipeline to GitHub Actions with equivalent functionality

# Add security scanning
/agents/devops/ci-cd-expert add SAST, DAST, and container scanning to existing pipeline
```

---

## Troubleshooting Common Issues

| Issue                | Cause              | Solution                              |
| -------------------- | ------------------ | ------------------------------------- |
| Slow builds          | No caching         | Implement layer/dependency caching    |
| Flaky tests          | Race conditions    | Add proper waits, use test containers |
| Secret exposure      | Misconfigured logs | Mask secrets, audit log output        |
| Failed deployments   | No health checks   | Add readiness/liveness probes         |
| Pipeline timeouts    | Large artifacts    | Use artifact streaming, split stages  |
| Concurrent conflicts | No locking         | Add concurrency groups, mutex         |

---

## Quick Reference

```bash
# GitHub Actions - Test locally
act -j build

# GitLab CI - Validate syntax
gitlab-ci-lint .gitlab-ci.yml

# Jenkins - Validate Jenkinsfile
curl -X POST -F "jenkinsfile=<Jenkinsfile" \
  https://jenkins.example.com/pipeline-model-converter/validate
```
