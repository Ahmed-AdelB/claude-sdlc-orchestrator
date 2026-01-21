---
name: CI/CD Expert Agent
description: Comprehensive CI/CD specialist for pipeline design, build automation, deployment strategies, and DevSecOps practices
version: 3.0.0
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
  - /agents/security/security-expert
  - /agents/testing/integration-test-expert
---

# CI/CD Expert Agent

Comprehensive CI/CD specialist. Expert in pipeline design, build automation, deployment strategies, and DevSecOps practices across GitHub Actions, GitLab CI/CD, Jenkins, CircleCI, and other CI/CD platforms.

## Arguments

- `$ARGUMENTS` - CI/CD task, pipeline design request, or deployment strategy

## Invoke Agent

```
Use the Task tool with subagent_type="ci-cd-expert" to:

1. Design CI/CD pipelines (GitHub Actions, GitLab CI, Jenkins, CircleCI)
2. Implement deployment strategies (blue-green, canary, rolling)
3. Configure build optimization and caching
4. Set up secret management in pipelines
5. Implement quality gates and security scanning (SAST, DAST, SCA)
6. Create reusable pipeline components
7. Troubleshoot pipeline failures
8. Design branching and release strategies
9. Configure artifact management and versioning
10. Implement rollback strategies

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

## Pipeline Design Patterns

### Branching Strategies Comparison

| Strategy    | Best For                   | Branch Structure                            | Release Cadence       |
| ----------- | -------------------------- | ------------------------------------------- | --------------------- |
| Trunk-Based | Continuous deployment      | `main` + short-lived feature branches       | Multiple times/day    |
| GitHub Flow | SaaS, web applications     | `main` + feature branches + PR              | On demand             |
| GitFlow     | Scheduled releases, mobile | `main`, `develop`, `feature/*`, `release/*` | Scheduled (bi-weekly) |
| GitLab Flow | Environment-based releases | `main` + environment branches               | Environment-driven    |

### Trunk-Based Development Pipeline

```yaml
# .github/workflows/trunk-based.yml
name: Trunk-Based CI/CD

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  # Fast feedback loop - runs in parallel
  validate:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        check: [lint, typecheck, unit-test]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"
      - run: npm ci
      - name: Run ${{ matrix.check }}
        run: |
          case "${{ matrix.check }}" in
            lint) npm run lint ;;
            typecheck) npm run typecheck ;;
            unit-test) npm run test:unit -- --coverage ;;
          esac

  # Integration tests after validation
  integration-test:
    needs: validate
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"
      - run: npm ci
      - run: npm run test:integration
        env:
          DATABASE_URL: postgres://postgres:test@localhost:5432/test

  # Build and deploy on main branch only
  build-and-deploy:
    needs: integration-test
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest
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
      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max
      - name: Deploy to production
        run: |
          # Trunk-based: deploy directly to production with feature flags
          kubectl set image deployment/app app=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
          kubectl rollout status deployment/app --timeout=300s
```

### GitHub Flow Pipeline

```yaml
# .github/workflows/github-flow.yml
name: GitHub Flow CI/CD

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"
      - run: npm ci
      - run: npm run lint
      - run: npm run test -- --coverage
      - uses: codecov/codecov-action@v4

  # Preview environment for PRs
  preview:
    needs: test
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    environment:
      name: preview
      url: ${{ steps.deploy.outputs.url }}
    steps:
      - uses: actions/checkout@v4
      - name: Deploy Preview
        id: deploy
        run: |
          # Deploy to preview environment (e.g., Vercel, Netlify, or custom)
          PREVIEW_URL="https://pr-${{ github.event.number }}.preview.example.com"
          echo "url=$PREVIEW_URL" >> $GITHUB_OUTPUT
      - name: Comment PR
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: 'Preview deployed: ${{ steps.deploy.outputs.url }}'
            })

  # Production deployment when merged to main
  deploy:
    needs: test
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://example.com
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to Production
        run: ./scripts/deploy-production.sh
```

### GitFlow Pipeline

```yaml
# .github/workflows/gitflow.yml
name: GitFlow CI/CD

on:
  push:
    branches:
      - main
      - develop
      - "feature/**"
      - "release/**"
      - "hotfix/**"
  pull_request:
    branches: [main, develop]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"
      - run: npm ci
      - run: npm run lint
      - run: npm run test

  # Deploy to dev environment from develop branch
  deploy-dev:
    needs: test
    if: github.ref == 'refs/heads/develop'
    runs-on: ubuntu-latest
    environment: development
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to Development
        run: ./scripts/deploy.sh development

  # Deploy to staging from release branches
  deploy-staging:
    needs: test
    if: startsWith(github.ref, 'refs/heads/release/')
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v4
      - name: Extract version
        id: version
        run: echo "version=${GITHUB_REF#refs/heads/release/}" >> $GITHUB_OUTPUT
      - name: Deploy to Staging
        run: ./scripts/deploy.sh staging ${{ steps.version.outputs.version }}

  # Deploy to production from main branch
  deploy-production:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - name: Get latest tag
        id: tag
        run: echo "version=$(git describe --tags --abbrev=0)" >> $GITHUB_OUTPUT
      - name: Deploy to Production
        run: ./scripts/deploy.sh production ${{ steps.tag.outputs.version }}

  # Hotfix fast-track to production
  hotfix:
    needs: test
    if: startsWith(github.ref, 'refs/heads/hotfix/')
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - name: Deploy Hotfix
        run: ./scripts/deploy-hotfix.sh
```

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

## CircleCI Pipeline Templates

### Standard Pipeline with Orbs

```yaml
# .circleci/config.yml
version: 2.1

orbs:
  node: circleci/node@5.2.0
  docker: circleci/docker@2.6.0
  kubernetes: circleci/kubernetes@1.3.1
  slack: circleci/slack@4.13.1

parameters:
  run-deploy:
    type: boolean
    default: false

executors:
  node-executor:
    docker:
      - image: cimg/node:20.11
    resource_class: medium
  docker-executor:
    docker:
      - image: cimg/base:stable
    resource_class: medium

commands:
  install-deps:
    steps:
      - restore_cache:
          keys:
            - v1-deps-{{ checksum "package-lock.json" }}
            - v1-deps-
      - run: npm ci
      - save_cache:
          key: v1-deps-{{ checksum "package-lock.json" }}
          paths:
            - node_modules

  notify-status:
    parameters:
      status:
        type: string
    steps:
      - slack/notify:
          event: << parameters.status >>
          template: basic_<< parameters.status >>_1

jobs:
  lint:
    executor: node-executor
    steps:
      - checkout
      - install-deps
      - run: npm run lint
      - run: npm run typecheck

  test:
    executor: node-executor
    parallelism: 4
    steps:
      - checkout
      - install-deps
      - run:
          name: Run tests
          command: |
            TESTFILES=$(circleci tests glob "src/**/*.test.ts" | circleci tests split --split-by=timings)
            npm run test -- --coverage $TESTFILES
      - store_test_results:
          path: test-results
      - store_artifacts:
          path: coverage

  security-scan:
    executor: node-executor
    steps:
      - checkout
      - install-deps
      - run:
          name: Audit dependencies
          command: npm audit --audit-level=high
      - run:
          name: Run Snyk
          command: npx snyk test --severity-threshold=high

  build:
    executor: docker-executor
    steps:
      - checkout
      - setup_remote_docker:
          version: 20.10.24
          docker_layer_caching: true
      - docker/build:
          image: $DOCKER_REGISTRY/$CIRCLE_PROJECT_REPONAME
          tag: $CIRCLE_SHA1
      - docker/push:
          image: $DOCKER_REGISTRY/$CIRCLE_PROJECT_REPONAME
          tag: $CIRCLE_SHA1

  deploy-staging:
    executor: docker-executor
    steps:
      - checkout
      - kubernetes/install-kubectl
      - run:
          name: Deploy to staging
          command: |
            kubectl config set-cluster staging --server=$KUBE_SERVER_STAGING
            kubectl config set-credentials deploy --token=$KUBE_TOKEN_STAGING
            kubectl config set-context staging --cluster=staging --user=deploy
            kubectl config use-context staging
            kubectl set image deployment/app app=$DOCKER_REGISTRY/$CIRCLE_PROJECT_REPONAME:$CIRCLE_SHA1
            kubectl rollout status deployment/app --timeout=300s
      - notify-status:
          status: pass

  deploy-production:
    executor: docker-executor
    steps:
      - checkout
      - kubernetes/install-kubectl
      - run:
          name: Deploy to production
          command: |
            kubectl config set-cluster production --server=$KUBE_SERVER_PROD
            kubectl config set-credentials deploy --token=$KUBE_TOKEN_PROD
            kubectl config set-context production --cluster=production --user=deploy
            kubectl config use-context production
            kubectl set image deployment/app app=$DOCKER_REGISTRY/$CIRCLE_PROJECT_REPONAME:$CIRCLE_SHA1
            kubectl rollout status deployment/app --timeout=300s
      - notify-status:
          status: pass

workflows:
  ci-cd:
    jobs:
      - lint
      - test:
          requires:
            - lint
      - security-scan:
          requires:
            - lint
      - build:
          requires:
            - test
            - security-scan
          filters:
            branches:
              only: main
      - deploy-staging:
          requires:
            - build
          filters:
            branches:
              only: main
      - hold-production:
          type: approval
          requires:
            - deploy-staging
          filters:
            branches:
              only: main
      - deploy-production:
          requires:
            - hold-production
          filters:
            branches:
              only: main

  nightly-security:
    triggers:
      - schedule:
          cron: "0 2 * * *"
          filters:
            branches:
              only: main
    jobs:
      - security-scan
```

---

## Testing Strategies in Pipelines

### Test Pyramid Implementation

```yaml
# .github/workflows/test-pyramid.yml
name: Test Pyramid

on: [push, pull_request]

jobs:
  # Base of pyramid - fast, many tests
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"
      - run: npm ci
      - run: npm run test:unit -- --coverage --maxWorkers=4
      - name: Check coverage threshold
        run: |
          COVERAGE=$(cat coverage/coverage-summary.json | jq '.total.lines.pct')
          if (( $(echo "$COVERAGE < 80" | bc -l) )); then
            echo "Coverage $COVERAGE% is below 80% threshold"
            exit 1
          fi
      - uses: codecov/codecov-action@v4

  # Middle of pyramid - moderate speed, fewer tests
  integration-tests:
    needs: unit-tests
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: test
          POSTGRES_DB: test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      redis:
        image: redis:7
        ports:
          - 6379:6379
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"
      - run: npm ci
      - name: Run database migrations
        run: npm run migrate:test
        env:
          DATABASE_URL: postgres://postgres:test@localhost:5432/test
      - run: npm run test:integration
        env:
          DATABASE_URL: postgres://postgres:test@localhost:5432/test
          REDIS_URL: redis://localhost:6379

  # Top of pyramid - slow, few tests
  e2e-tests:
    needs: integration-tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"
      - run: npm ci
      - name: Install Playwright
        run: npx playwright install --with-deps chromium
      - name: Start application
        run: npm run start:test &
        env:
          NODE_ENV: test
      - name: Wait for app
        run: npx wait-on http://localhost:3000
      - name: Run E2E tests
        run: npm run test:e2e
      - uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: playwright-report
          path: playwright-report/

  # Performance tests (optional, on main branch)
  performance-tests:
    needs: e2e-tests
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run k6 load tests
        uses: grafana/k6-action@v0.3.1
        with:
          filename: tests/performance/load.js
          flags: --out json=results.json
      - name: Check performance thresholds
        run: |
          # Fail if p95 latency > 500ms
          P95=$(cat results.json | jq '.metrics.http_req_duration.values["p(95)"]')
          if (( $(echo "$P95 > 500" | bc -l) )); then
            echo "P95 latency $P95ms exceeds 500ms threshold"
            exit 1
          fi

  # Contract tests for microservices
  contract-tests:
    needs: unit-tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"
      - run: npm ci
      - name: Run Pact tests
        run: npm run test:contract
      - name: Publish contracts
        if: github.ref == 'refs/heads/main'
        run: npm run pact:publish
        env:
          PACT_BROKER_URL: ${{ secrets.PACT_BROKER_URL }}
          PACT_BROKER_TOKEN: ${{ secrets.PACT_BROKER_TOKEN }}
```

### Test Parallelization Strategies

```yaml
# GitLab CI - Test sharding
test:
  stage: test
  parallel: 4
  script:
    - npm ci
    - |
      # Split tests across parallel jobs
      TOTAL_JOBS=4
      JOB_INDEX=$((CI_NODE_INDEX - 1))
      npm run test -- --shard=$((JOB_INDEX + 1))/$TOTAL_JOBS
  artifacts:
    reports:
      junit: junit.xml
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

### Deployment Strategy Comparison

| Strategy    | Downtime | Rollback Speed | Resource Usage | Risk Level | Best For                |
| ----------- | -------- | -------------- | -------------- | ---------- | ----------------------- |
| Rolling     | None     | Minutes        | 1.2x normal    | Medium     | Standard deployments    |
| Blue-Green  | None     | Instant        | 2x normal      | Low        | Critical applications   |
| Canary      | None     | Fast           | 1.1x normal    | Low        | High-traffic services   |
| Recreate    | Yes      | N/A            | 1x normal      | High       | Dev/test environments   |
| A/B Testing | None     | Fast           | 1.1x normal    | Low        | Feature experimentation |

---

## Environment Management

### Environment Configuration Matrix

```yaml
# .github/workflows/deploy-environments.yml
name: Multi-Environment Deployment

on:
  push:
    branches: [main, develop]
  workflow_dispatch:
    inputs:
      environment:
        description: "Target environment"
        type: choice
        options:
          - development
          - staging
          - production

jobs:
  determine-env:
    runs-on: ubuntu-latest
    outputs:
      environment: ${{ steps.env.outputs.environment }}
      url: ${{ steps.env.outputs.url }}
    steps:
      - id: env
        run: |
          if [ "${{ github.event_name }}" == "workflow_dispatch" ]; then
            ENV="${{ github.event.inputs.environment }}"
          elif [ "${{ github.ref }}" == "refs/heads/main" ]; then
            ENV="staging"
          else
            ENV="development"
          fi

          case $ENV in
            development)
              URL="https://dev.example.com"
              ;;
            staging)
              URL="https://staging.example.com"
              ;;
            production)
              URL="https://example.com"
              ;;
          esac

          echo "environment=$ENV" >> $GITHUB_OUTPUT
          echo "url=$URL" >> $GITHUB_OUTPUT

  deploy:
    needs: determine-env
    runs-on: ubuntu-latest
    environment:
      name: ${{ needs.determine-env.outputs.environment }}
      url: ${{ needs.determine-env.outputs.url }}
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to ${{ needs.determine-env.outputs.environment }}
        env:
          # Environment-specific secrets
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
          API_KEY: ${{ secrets.API_KEY }}
        run: |
          echo "Deploying to ${{ needs.determine-env.outputs.environment }}"
          ./scripts/deploy.sh ${{ needs.determine-env.outputs.environment }}
```

### Environment-Specific Configuration

```yaml
# config/environments.yml
environments:
  development:
    replicas: 1
    resources:
      cpu: 100m
      memory: 256Mi
    features:
      debug: true
      mock_services: true
    secrets_prefix: DEV_

  staging:
    replicas: 2
    resources:
      cpu: 250m
      memory: 512Mi
    features:
      debug: false
      mock_services: false
    secrets_prefix: STAGING_

  production:
    replicas: 5
    resources:
      cpu: 500m
      memory: 1Gi
    features:
      debug: false
      mock_services: false
    secrets_prefix: PROD_
    extra:
      auto_scaling: true
      min_replicas: 3
      max_replicas: 20
```

### Environment Promotion Pipeline

```yaml
# GitLab CI - Environment promotion
stages:
  - build
  - deploy-dev
  - test-dev
  - promote-staging
  - test-staging
  - promote-production

variables:
  IMAGE_TAG: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA

build:
  stage: build
  script:
    - docker build -t $IMAGE_TAG .
    - docker push $IMAGE_TAG

deploy-dev:
  stage: deploy-dev
  environment:
    name: development
    url: https://dev.example.com
  script:
    - kubectl apply -f k8s/dev/
    - kubectl set image deployment/app app=$IMAGE_TAG

test-dev:
  stage: test-dev
  script:
    - npm run test:smoke -- --url=https://dev.example.com
  needs:
    - deploy-dev

promote-staging:
  stage: promote-staging
  environment:
    name: staging
    url: https://staging.example.com
  when: manual
  script:
    - kubectl apply -f k8s/staging/
    - kubectl set image deployment/app app=$IMAGE_TAG
  needs:
    - test-dev

test-staging:
  stage: test-staging
  script:
    - npm run test:integration -- --url=https://staging.example.com
    - npm run test:performance -- --url=https://staging.example.com
  needs:
    - promote-staging

promote-production:
  stage: promote-production
  environment:
    name: production
    url: https://example.com
  when: manual
  script:
    - kubectl apply -f k8s/production/
    - kubectl set image deployment/app app=$IMAGE_TAG
  needs:
    - test-staging
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
```

---

## Artifact Management and Versioning

### Semantic Versioning Pipeline

````yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    branches: [main]

permissions:
  contents: write
  packages: write

jobs:
  version:
    runs-on: ubuntu-latest
    outputs:
      new_version: ${{ steps.version.outputs.new_version }}
      changelog: ${{ steps.changelog.outputs.changelog }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Get next version
        id: version
        run: |
          # Analyze commits since last tag
          LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
          COMMITS=$(git log $LAST_TAG..HEAD --pretty=format:"%s")

          # Determine version bump based on conventional commits
          if echo "$COMMITS" | grep -qE "^BREAKING CHANGE:|^[a-z]+!:"; then
            BUMP="major"
          elif echo "$COMMITS" | grep -qE "^feat"; then
            BUMP="minor"
          else
            BUMP="patch"
          fi

          # Calculate new version
          IFS='.' read -r major minor patch <<< "${LAST_TAG#v}"
          case $BUMP in
            major) new_version="$((major + 1)).0.0" ;;
            minor) new_version="$major.$((minor + 1)).0" ;;
            patch) new_version="$major.$minor.$((patch + 1))" ;;
          esac

          echo "new_version=v$new_version" >> $GITHUB_OUTPUT

      - name: Generate changelog
        id: changelog
        run: |
          LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
          if [ -n "$LAST_TAG" ]; then
            CHANGELOG=$(git log $LAST_TAG..HEAD --pretty=format:"- %s (%h)")
          else
            CHANGELOG=$(git log --pretty=format:"- %s (%h)")
          fi
          echo "changelog<<EOF" >> $GITHUB_OUTPUT
          echo "$CHANGELOG" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT

  build:
    needs: version
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build Docker image
        run: |
          docker build \
            --label "org.opencontainers.image.version=${{ needs.version.outputs.new_version }}" \
            --label "org.opencontainers.image.revision=${{ github.sha }}" \
            -t ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ needs.version.outputs.new_version }} \
            -t ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest \
            .

      - name: Push to registry
        run: |
          docker push ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ needs.version.outputs.new_version }}
          docker push ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          tag_name: ${{ needs.version.outputs.new_version }}
          name: Release ${{ needs.version.outputs.new_version }}
          body: |
            ## Changes
            ${{ needs.version.outputs.changelog }}

            ## Docker Image
            ```
            docker pull ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ needs.version.outputs.new_version }}
            ```
          generate_release_notes: true

  publish-npm:
    needs: [version, build]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
          registry-url: "https://registry.npmjs.org"
      - run: npm ci
      - run: npm version ${{ needs.version.outputs.new_version }} --no-git-tag-version
      - run: npm publish
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
````

### Artifact Storage and Retention

```yaml
# GitHub Actions - Artifact management
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run build

      # Upload build artifacts
      - uses: actions/upload-artifact@v4
        with:
          name: build-${{ github.sha }}
          path: |
            dist/
            !dist/**/*.map
          retention-days: 30
          compression-level: 9

      # Upload test results
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results-${{ github.sha }}
          path: |
            test-results/
            coverage/
          retention-days: 14

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      # Download artifacts from build job
      - uses: actions/download-artifact@v4
        with:
          name: build-${{ github.sha }}
          path: dist/

      - name: Deploy artifacts
        run: ./scripts/deploy.sh
```

### Container Image Versioning

```dockerfile
# Dockerfile with build metadata
ARG VERSION=dev
ARG BUILD_DATE
ARG VCS_REF

FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-alpine
WORKDIR /app

# OCI Image Labels
LABEL org.opencontainers.image.title="My Application"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.source="https://github.com/org/repo"

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY package.json ./

USER node
EXPOSE 3000
CMD ["node", "dist/main.js"]
```

---

## Rollback Strategies

### Automated Rollback Pipeline

```yaml
# .github/workflows/rollback.yml
name: Rollback Deployment

on:
  workflow_dispatch:
    inputs:
      environment:
        description: "Environment to rollback"
        type: choice
        options:
          - staging
          - production
      version:
        description: "Version to rollback to (leave empty for previous)"
        required: false
      reason:
        description: "Reason for rollback"
        required: true

jobs:
  rollback:
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment }}
    steps:
      - uses: actions/checkout@v4

      - name: Determine rollback version
        id: version
        run: |
          if [ -n "${{ github.event.inputs.version }}" ]; then
            VERSION="${{ github.event.inputs.version }}"
          else
            # Get previous deployment version from history
            VERSION=$(kubectl rollout history deployment/app -n ${{ github.event.inputs.environment }} | \
              tail -2 | head -1 | awk '{print $1}')
          fi
          echo "version=$VERSION" >> $GITHUB_OUTPUT

      - name: Create rollback record
        run: |
          echo "Rollback initiated" >> rollback.log
          echo "Environment: ${{ github.event.inputs.environment }}" >> rollback.log
          echo "Target version: ${{ steps.version.outputs.version }}" >> rollback.log
          echo "Reason: ${{ github.event.inputs.reason }}" >> rollback.log
          echo "Initiated by: ${{ github.actor }}" >> rollback.log
          echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> rollback.log

      - name: Execute rollback
        run: |
          # Kubernetes rollback
          kubectl rollout undo deployment/app \
            -n ${{ github.event.inputs.environment }} \
            --to-revision=${{ steps.version.outputs.version }}

          # Wait for rollback to complete
          kubectl rollout status deployment/app \
            -n ${{ github.event.inputs.environment }} \
            --timeout=300s

      - name: Verify rollback
        run: |
          # Health check
          HEALTH=$(curl -s https://${{ github.event.inputs.environment }}.example.com/health | jq -r '.status')
          if [ "$HEALTH" != "healthy" ]; then
            echo "Rollback verification failed!"
            exit 1
          fi
          echo "Rollback successful - application healthy"

      - name: Notify team
        uses: slackapi/slack-github-action@v1.25.0
        with:
          payload: |
            {
              "text": "Rollback completed",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Rollback Completed*\n*Environment:* ${{ github.event.inputs.environment }}\n*Version:* ${{ steps.version.outputs.version }}\n*Reason:* ${{ github.event.inputs.reason }}\n*Initiated by:* ${{ github.actor }}"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}

      - name: Create incident ticket
        if: github.event.inputs.environment == 'production'
        run: |
          # Create incident record for production rollbacks
          curl -X POST "${{ secrets.INCIDENT_API_URL }}" \
            -H "Authorization: Bearer ${{ secrets.INCIDENT_API_TOKEN }}" \
            -H "Content-Type: application/json" \
            -d '{
              "title": "Production Rollback - ${{ github.event.inputs.reason }}",
              "severity": "high",
              "description": "Automated rollback triggered by ${{ github.actor }}",
              "version_from": "current",
              "version_to": "${{ steps.version.outputs.version }}"
            }'
```

### Database Rollback Strategy

```yaml
# .github/workflows/db-rollback.yml
name: Database Rollback

on:
  workflow_dispatch:
    inputs:
      migration_version:
        description: "Target migration version"
        required: true
      dry_run:
        description: "Dry run (show what would be rolled back)"
        type: boolean
        default: true

jobs:
  db-rollback:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Backup current state
        run: |
          pg_dump $DATABASE_URL > backup-$(date +%Y%m%d-%H%M%S).sql
          aws s3 cp backup-*.sql s3://backups/db/
        env:
          DATABASE_URL: ${{ secrets.DATABASE_URL }}

      - name: Preview rollback
        if: github.event.inputs.dry_run == 'true'
        run: |
          npm run migrate:rollback -- --to=${{ github.event.inputs.migration_version }} --dry-run

      - name: Execute rollback
        if: github.event.inputs.dry_run == 'false'
        run: |
          npm run migrate:rollback -- --to=${{ github.event.inputs.migration_version }}

      - name: Verify database health
        run: |
          npm run db:health-check
```

### Rollback Decision Matrix

| Metric                | Threshold      | Action             |
| --------------------- | -------------- | ------------------ |
| Error rate            | > 5%           | Auto-rollback      |
| P99 latency           | > 2x baseline  | Alert + manual     |
| Health check failures | > 3 in 1 min   | Auto-rollback      |
| Memory usage          | > 90%          | Alert + manual     |
| CPU usage             | > 95% for 5min | Alert + scale/roll |
| Failed requests       | > 10/min       | Auto-rollback      |

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

## Pipeline Security (SAST, DAST, SCA)

### Comprehensive Security Pipeline

```yaml
# .github/workflows/security.yml
name: Security Checks

on:
  push:
    branches: [main]
  pull_request:
  schedule:
    - cron: "0 6 * * *"

jobs:
  # Static Application Security Testing (SAST)
  sast:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Semgrep
        uses: returntocorp/semgrep-action@v1
        with:
          config: >-
            p/default
            p/security-audit
            p/owasp-top-ten
            p/cwe-top-25

      - name: Run CodeQL
        uses: github/codeql-action/init@v3
        with:
          languages: javascript, typescript
      - uses: github/codeql-action/analyze@v3

      - name: Run Bandit (Python)
        if: hashFiles('**/*.py') != ''
        run: |
          pip install bandit
          bandit -r . -f json -o bandit-results.json || true
      - uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: bandit-results.json

  # Software Composition Analysis (SCA)
  sca:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Snyk
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high --sarif-file-output=snyk.sarif

      - name: Run Trivy (filesystem)
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: "fs"
          scan-ref: "."
          severity: "CRITICAL,HIGH"
          format: "sarif"
          output: "trivy-fs.sarif"

      - name: Run npm audit
        run: npm audit --audit-level=high --json > npm-audit.json || true

      - name: Upload SARIF files
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: snyk.sarif

  # Container Security
  container-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: docker build -t app:${{ github.sha }} .

      - name: Run Trivy (image)
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: app:${{ github.sha }}
          format: "sarif"
          output: "trivy-image.sarif"
          severity: "CRITICAL,HIGH"

      - name: Run Grype
        uses: anchore/scan-action@v3
        with:
          image: app:${{ github.sha }}
          fail-build: true
          severity-cutoff: high

      - name: Upload SARIF
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: trivy-image.sarif

  # Dynamic Application Security Testing (DAST)
  dast:
    needs: [sast, sca]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Start application
        run: |
          docker-compose up -d
          sleep 30

      - name: Run OWASP ZAP
        uses: zaproxy/action-full-scan@v0.9.0
        with:
          target: "http://localhost:3000"
          rules_file_name: ".zap/rules.tsv"
          cmd_options: "-a"

      - name: Run Nuclei
        uses: projectdiscovery/nuclei-action@main
        with:
          target: http://localhost:3000
          flags: "-severity critical,high -sarif-export nuclei.sarif"

  # Secret Scanning
  secret-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run Gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Run TruffleHog
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: ${{ github.event.repository.default_branch }}
          head: HEAD

  # Infrastructure Security
  iac-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Checkov
        uses: bridgecrewio/checkov-action@v12
        with:
          directory: .
          framework: terraform,kubernetes,dockerfile
          output_format: sarif
          output_file_path: checkov.sarif

      - name: Run tfsec
        uses: aquasecurity/tfsec-action@v1.0.0
        with:
          soft_fail: true
```

### Security Gate Configuration

```yaml
# Branch protection rules (configure via API or UI)
security-gate:
  runs-on: ubuntu-latest
  needs: [sast, sca, container-scan, secret-scan]
  if: always()
  steps:
    - name: Check security results
      run: |
        # Fail if any critical vulnerabilities found
        if [ "${{ needs.sast.result }}" == "failure" ]; then
          echo "SAST checks failed"
          exit 1
        fi
        if [ "${{ needs.sca.result }}" == "failure" ]; then
          echo "SCA checks failed"
          exit 1
        fi
        if [ "${{ needs.container-scan.result }}" == "failure" ]; then
          echo "Container scan failed"
          exit 1
        fi
        if [ "${{ needs.secret-scan.result }}" == "failure" ]; then
          echo "Secret scan failed - potential credential leak!"
          exit 1
        fi
        echo "All security checks passed"
```

### Security Checklist

| Category     | Practice                     | Tool                        |
| ------------ | ---------------------------- | --------------------------- |
| Secrets      | Never hardcode secrets       | Gitleaks, TruffleHog        |
| Secrets      | Rotate credentials regularly | Vault, AWS Secrets Manager  |
| Secrets      | Use OIDC for cloud auth      | GitHub OIDC, GitLab JWT     |
| Code         | Scan for vulnerabilities     | Semgrep, CodeQL, Bandit     |
| Code         | Static analysis (SAST)       | SonarQube, Checkmarx        |
| Dependencies | Check for CVEs               | Snyk, npm audit, Dependabot |
| Images       | Scan container images        | Trivy, Grype, Clair         |
| Images       | Use minimal base images      | Distroless, Alpine          |
| IaC          | Scan infrastructure code     | Checkov, tfsec, Terrascan   |
| Runtime      | Dynamic testing (DAST)       | OWASP ZAP, Nuclei           |
| Access       | Principle of least privilege | Scoped tokens, RBAC         |
| Audit        | Sign commits and images      | GPG, Cosign, Sigstore       |

---

## Quality Gates

### Merge Requirements

```yaml
# Branch protection + required checks
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
| `/agents/security/security-expert`           | Security architecture and auditing         |
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

# Design branching strategy
/agents/devops/ci-cd-expert design trunk-based development workflow with feature flags

# Configure multi-environment deployment
/agents/devops/ci-cd-expert set up dev/staging/production environments with promotion gates

# Implement rollback strategy
/agents/devops/ci-cd-expert create automated rollback pipeline with health checks

# Set up artifact versioning
/agents/devops/ci-cd-expert implement semantic versioning with changelog generation
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
| OOM errors           | Large builds       | Increase runner memory, optimize deps |
| Permission denied    | Wrong credentials  | Verify OIDC/token permissions         |

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

# CircleCI - Validate config
circleci config validate

# Kubernetes - Check rollout status
kubectl rollout status deployment/app --timeout=300s

# Rollback deployment
kubectl rollout undo deployment/app

# View deployment history
kubectl rollout history deployment/app
```
