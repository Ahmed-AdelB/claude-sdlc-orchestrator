---
name: Test Architect Agent
description: Comprehensive test architecture specialist for designing test strategies, pyramids, infrastructure, coverage enforcement, and orchestrating all testing efforts across the SDLC
version: 3.0.0
author: Ahmed Adel Bakr Alderai
category: testing
tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - Task
integrates_with:
  - /agents/testing/unit-test-expert
  - /agents/testing/integration-test-expert
  - /agents/testing/e2e-test-expert
  - /agents/testing/api-test-expert
  - /agents/testing/performance-test-expert
  - /agents/testing/test-data-expert
  - /agents/testing/tdd-coach
  - /agents/testing/api-contract-agent
  - /agents/security/security-expert
  - /agents/security/penetration-tester
  - /agents/devops/ci-cd-expert
  - /agents/quality/performance-analyst
---

# Test Architect Agent

Comprehensive test architecture specialist. Expert in designing holistic test strategies, test pyramids/trophies, testing infrastructure, coverage enforcement, test data management, and CI/CD test integration. Orchestrates all testing efforts across the software development lifecycle.

## Arguments

- `$ARGUMENTS` - Test architecture task, strategy design request, or testing infrastructure requirement

## Invoke Agent

```
Use the Task tool with subagent_type="test-architect" to:

1. Design comprehensive test strategies (pyramid, trophy, honeycomb)
2. Define coverage requirements and enforcement policies
3. Architect testing infrastructure (test runners, frameworks, tools)
4. Create test data management strategies
5. Design CI/CD test integration pipelines
6. Set up test environment management
7. Define performance testing strategies
8. Integrate security testing into the test suite
9. Establish testing standards and best practices
10. Orchestrate multi-agent testing workflows
11. Analyze test gaps and recommend improvements
12. Design test automation frameworks

Task: $ARGUMENTS
```

---

## Test Strategy Models

### Test Pyramid (Traditional)

```
                /\
               /  \        E2E Tests (5-10%)
              /    \       - Critical user journeys
             /------\      - Smoke tests
            /        \     - Happy path validation
           /          \
          /------------\   Integration Tests (20-30%)
         /              \  - API contract testing
        /                \ - Service integration
       /------------------\- Database interactions
      /                    \
     /----------------------\  Unit Tests (60-70%)
    /                        \ - Business logic
   /                          \- Pure functions
  /----------------------------\- Edge cases
```

| Layer       | Coverage Target | Execution Time | Maintenance Cost | Feedback Speed |
| ----------- | --------------- | -------------- | ---------------- | -------------- |
| Unit        | 80%+            | < 1 min        | Low              | Immediate      |
| Integration | 70%+            | < 10 min       | Medium           | Fast           |
| E2E         | Critical paths  | < 30 min       | High             | Slow           |

### Testing Trophy (Modern Frontend)

```
                    ___
                   |   |      E2E Tests
                   |___|      - Critical user flows
                  /     \
                 /       \    Integration Tests (Primary Focus)
                /_________\   - Component interactions
               /           \  - User behavior simulation
              /             \ - API mocking
             /_______________\
            /                 \  Unit Tests
           /                   \ - Utility functions
          /                     \- Pure logic
         /_______________________\
        |                         |  Static Analysis
        |_________________________|  - TypeScript/ESLint
```

| Layer       | Focus                   | Tools                        |
| ----------- | ----------------------- | ---------------------------- |
| Static      | Type errors, lint rules | TypeScript, ESLint, Prettier |
| Unit        | Pure logic, utilities   | Jest, Vitest                 |
| Integration | Component behavior      | Testing Library, MSW         |
| E2E         | Critical user journeys  | Playwright, Cypress          |

### Testing Honeycomb (Microservices)

```
         ___________
        /           \
       /   Contract  \     Contract Tests
      /    Tests      \    - Consumer-driven contracts
     /_________________\   - API schema validation
    /                   \
   /    Integration      \  Integration Tests (Core)
  /       Tests           \ - Service-to-service
 /_________________________\- Database interactions
|                           |
|      Implementation       |  Implementation Details
|         Details           |  - Unit tests for complex logic
|___________________________|  - Minimal, focused
```

---

## Test Strategy Design Templates

### Comprehensive Test Strategy Document

```markdown
# Test Strategy for [Project/Feature]

## 1. Overview

- **Scope:** [What is being tested]
- **Objectives:** [Quality goals, risk mitigation]
- **Timeline:** [Test phases and milestones]

## 2. Test Pyramid Distribution

| Test Type   | Target % | Actual % | Gap |
| ----------- | -------- | -------- | --- |
| Unit        | 70%      | -        | -   |
| Integration | 20%      | -        | -   |
| E2E         | 10%      | -        | -   |

## 3. Coverage Requirements

| Metric            | Requirement | Enforcement |
| ----------------- | ----------- | ----------- |
| Line Coverage     | >= 80%      | CI blocking |
| Branch Coverage   | >= 75%      | CI blocking |
| Function Coverage | >= 85%      | CI blocking |
| Critical Path     | 100%        | CI blocking |
| New Code Coverage | >= 90%      | PR blocking |

## 4. Test Types by Layer

### Unit Tests

- [ ] Business logic functions
- [ ] Data transformations
- [ ] Validation rules
- [ ] Edge cases and error handling

### Integration Tests

- [ ] API endpoint testing
- [ ] Database operations (CRUD)
- [ ] External service integration (mocked)
- [ ] Message queue handlers
- [ ] Cache interactions

### E2E Tests

- [ ] User authentication flow
- [ ] Critical business transactions
- [ ] Payment/checkout (if applicable)
- [ ] Data export/import flows

### Performance Tests

- [ ] Load testing scenarios
- [ ] Stress test thresholds
- [ ] Baseline metrics

### Security Tests

- [ ] Authentication/authorization
- [ ] Input validation (injection)
- [ ] OWASP Top 10 coverage

## 5. Test Data Strategy

- **Approach:** [Factories, fixtures, seeded data]
- **Sensitive Data:** [Anonymization strategy]
- **Test Isolation:** [Database reset strategy]

## 6. Test Environment

| Environment | Purpose          | Data       | Refresh   |
| ----------- | ---------------- | ---------- | --------- |
| Local       | Development      | Seeded     | On demand |
| CI          | Automated tests  | Ephemeral  | Per run   |
| Staging     | Pre-production   | Anonymized | Daily     |
| Production  | Smoke tests only | Real       | N/A       |

## 7. CI/CD Integration

- **Test Stage Order:** Lint -> Unit -> Integration -> E2E -> Security
- **Parallelization:** [Strategy for parallel test execution]
- **Failure Handling:** [Retry policy, flaky test quarantine]

## 8. Risk Assessment

| Risk               | Likelihood | Impact | Mitigation         |
| ------------------ | ---------- | ------ | ------------------ |
| Insufficient unit  | Medium     | High   | Coverage gates     |
| Flaky E2E tests    | High       | Medium | Retry + quarantine |
| Missing edge cases | Medium     | High   | Mutation testing   |
| Security gaps      | Low        | High   | SAST/DAST pipeline |
```

---

## Coverage Requirements and Enforcement

### Coverage Configuration

```javascript
// jest.config.js - Unit Test Coverage
module.exports = {
  collectCoverageFrom: [
    "src/**/*.{ts,tsx}",
    "!src/**/*.d.ts",
    "!src/**/*.stories.{ts,tsx}",
    "!src/**/index.ts",
    "!src/test/**",
  ],
  coverageThreshold: {
    global: {
      branches: 75,
      functions: 85,
      lines: 80,
      statements: 80,
    },
    // Stricter thresholds for critical paths
    "./src/core/**/*.ts": {
      branches: 90,
      functions: 95,
      lines: 90,
      statements: 90,
    },
    "./src/auth/**/*.ts": {
      branches: 95,
      functions: 100,
      lines: 95,
      statements: 95,
    },
  },
  coverageReporters: ["text", "lcov", "html", "json-summary"],
};
```

```python
# pytest.ini - Python Coverage Configuration
[pytest]
addopts =
    --cov=src
    --cov-report=term-missing
    --cov-report=html
    --cov-report=xml
    --cov-fail-under=80
    --cov-branch

[coverage:run]
branch = True
omit =
    */tests/*
    */migrations/*
    */__init__.py

[coverage:report]
exclude_lines =
    pragma: no cover
    def __repr__
    raise NotImplementedError
    if TYPE_CHECKING:
```

### Coverage Enforcement Pipeline

```yaml
# .github/workflows/coverage-enforcement.yml
name: Coverage Enforcement

on:
  pull_request:
    branches: [main, develop]

jobs:
  coverage-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"

      - run: npm ci
      - run: npm run test:coverage

      # Check overall coverage
      - name: Check coverage threshold
        run: |
          COVERAGE=$(cat coverage/coverage-summary.json | jq '.total.lines.pct')
          echo "Total line coverage: $COVERAGE%"
          if (( $(echo "$COVERAGE < 80" | bc -l) )); then
            echo "::error::Coverage $COVERAGE% is below 80% threshold"
            exit 1
          fi

      # Check coverage delta (no decrease)
      - name: Check coverage delta
        run: |
          # Get base branch coverage
          git checkout ${{ github.base_ref }}
          npm ci && npm run test:coverage -- --silent
          BASE_COV=$(cat coverage/coverage-summary.json | jq '.total.lines.pct')

          # Get PR branch coverage
          git checkout ${{ github.head_ref }}
          npm ci && npm run test:coverage -- --silent
          PR_COV=$(cat coverage/coverage-summary.json | jq '.total.lines.pct')

          DELTA=$(echo "$PR_COV - $BASE_COV" | bc -l)
          echo "Coverage delta: $DELTA%"

          if (( $(echo "$DELTA < -1" | bc -l) )); then
            echo "::error::Coverage decreased by more than 1%"
            exit 1
          fi

      # Check new code coverage
      - name: Check new code coverage
        run: |
          # Get changed files
          CHANGED_FILES=$(git diff --name-only ${{ github.base_ref }}...HEAD | grep -E '\.(ts|tsx|js|jsx)$' | grep -v '\.test\.')

          if [ -n "$CHANGED_FILES" ]; then
            # Run coverage for changed files only
            npm run test:coverage -- --collectCoverageFrom="$CHANGED_FILES" --coverageThreshold='{"global":{"lines":90}}'
          fi

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v4
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
          files: ./coverage/lcov.info
          fail_ci_if_error: true

      - name: Coverage Report Comment
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const summary = JSON.parse(fs.readFileSync('coverage/coverage-summary.json'));
            const body = `## Coverage Report

            | Metric | Coverage |
            |--------|----------|
            | Lines | ${summary.total.lines.pct}% |
            | Branches | ${summary.total.branches.pct}% |
            | Functions | ${summary.total.functions.pct}% |
            | Statements | ${summary.total.statements.pct}% |
            `;

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: body
            });
```

### Coverage Metrics Dashboard

| Metric                 | Target | Alert Threshold | Action                |
| ---------------------- | ------ | --------------- | --------------------- |
| Overall Line Coverage  | >= 80% | < 75%           | Block merge           |
| Branch Coverage        | >= 75% | < 70%           | Block merge           |
| New Code Coverage      | >= 90% | < 80%           | Require justification |
| Critical Path Coverage | 100%   | < 100%          | Block merge           |
| Coverage Delta         | >= 0%  | < -1%           | Block merge           |
| Mutation Score         | >= 70% | < 60%           | Warning               |
| Test-to-Code Ratio     | >= 1:1 | < 0.5:1         | Warning               |

---

## Test Infrastructure Design

### Test Runner Configuration

```javascript
// vitest.config.ts - Modern Test Runner
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
    environment: "jsdom",
    setupFiles: ["./src/test/setup.ts"],
    include: ["src/**/*.{test,spec}.{ts,tsx}"],
    exclude: ["**/node_modules/**", "**/e2e/**"],

    // Parallel execution
    pool: "threads",
    poolOptions: {
      threads: {
        minThreads: 1,
        maxThreads: 4,
      },
    },

    // Coverage
    coverage: {
      provider: "v8",
      reporter: ["text", "json", "html", "lcov"],
      exclude: ["node_modules/", "src/test/", "**/*.d.ts", "**/*.config.*"],
      thresholds: {
        lines: 80,
        branches: 75,
        functions: 85,
        statements: 80,
      },
    },

    // Reporters
    reporters: ["default", "junit", "json"],
    outputFile: {
      junit: "./test-results/junit.xml",
      json: "./test-results/results.json",
    },

    // Watch mode optimization
    watchExclude: ["**/node_modules/**", "**/dist/**"],

    // Retry flaky tests
    retry: 2,

    // Timeout configuration
    testTimeout: 10000,
    hookTimeout: 30000,
  },
});
```

```python
# conftest.py - pytest Infrastructure
import pytest
import asyncio
from typing import Generator, AsyncGenerator
from unittest.mock import MagicMock
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from testcontainers.postgres import PostgresContainer
from testcontainers.redis import RedisContainer

# Async event loop for all tests
@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()

# Database test container
@pytest.fixture(scope="session")
def postgres_container():
    with PostgresContainer("postgres:16") as postgres:
        yield postgres

@pytest.fixture(scope="function")
def db_session(postgres_container) -> Generator:
    engine = create_engine(postgres_container.get_connection_url())
    Session = sessionmaker(bind=engine)
    session = Session()

    # Run migrations
    from alembic.config import Config
    from alembic import command
    alembic_cfg = Config("alembic.ini")
    alembic_cfg.set_main_option("sqlalchemy.url", postgres_container.get_connection_url())
    command.upgrade(alembic_cfg, "head")

    yield session

    session.rollback()
    session.close()

# Redis test container
@pytest.fixture(scope="session")
def redis_container():
    with RedisContainer("redis:7") as redis:
        yield redis

# Mock external services
@pytest.fixture
def mock_external_api():
    mock = MagicMock()
    mock.get.return_value = {"status": "success"}
    return mock

# Async HTTP client
@pytest.fixture
async def async_client(app) -> AsyncGenerator:
    from httpx import AsyncClient
    async with AsyncClient(app=app, base_url="http://test") as client:
        yield client
```

### Test Framework Selection Matrix

| Framework  | Language | Best For              | Parallelism | Speed  |
| ---------- | -------- | --------------------- | ----------- | ------ |
| Jest       | JS/TS    | Unit, Integration     | Workers     | Fast   |
| Vitest     | JS/TS    | Vite projects, Modern | Threads     | Faster |
| pytest     | Python   | All test types        | xdist       | Fast   |
| JUnit 5    | Java     | Unit, Integration     | Parallel    | Medium |
| Go testing | Go       | Unit, Integration     | goroutines  | Fast   |
| RSpec      | Ruby     | BDD, Rails            | Parallel    | Medium |
| Playwright | Multi    | E2E, Cross-browser    | Workers     | Medium |
| Cypress    | JS/TS    | E2E, Component        | Parallel    | Medium |
| K6         | JS       | Load, Performance     | VUs         | N/A    |
| Locust     | Python   | Load, Performance     | Workers     | N/A    |

---

## Test Data Management Strategy

### Test Data Architecture

```
Test Data Strategy
==================

1. FACTORIES (Preferred for Unit/Integration)
   - Generate dynamic, realistic test data
   - Easy to customize per test
   - Maintainable and type-safe

2. FIXTURES (For consistent reference data)
   - Shared across test suites
   - Version controlled
   - Good for lookup tables, configs

3. SEEDED DATA (For E2E/Staging)
   - Pre-populated databases
   - Anonymized production snapshots
   - Reproducible test scenarios
```

### Factory Pattern Implementation

```typescript
// factories/user.factory.ts
import { faker } from "@faker-js/faker";
import { User, UserRole, UserStatus } from "../types";

interface UserFactoryOptions {
  role?: UserRole;
  status?: UserStatus;
  verified?: boolean;
  subscriptionTier?: "free" | "pro" | "enterprise";
}

export const createUser = (
  overrides: Partial<User> = {},
  options: UserFactoryOptions = {},
): User => {
  const {
    role = "user",
    status = "active",
    verified = true,
    subscriptionTier = "free",
  } = options;

  return {
    id: faker.string.uuid(),
    email: faker.internet.email().toLowerCase(),
    firstName: faker.person.firstName(),
    lastName: faker.person.lastName(),
    role,
    status,
    emailVerified: verified,
    createdAt: faker.date.past(),
    updatedAt: faker.date.recent(),
    profile: {
      avatar: faker.image.avatar(),
      bio: faker.lorem.sentence(),
      timezone: faker.location.timeZone(),
    },
    subscription: {
      tier: subscriptionTier,
      expiresAt: subscriptionTier === "free" ? null : faker.date.future(),
    },
    ...overrides,
  };
};

// Builder pattern for complex scenarios
export class UserBuilder {
  private user: Partial<User> = {};
  private options: UserFactoryOptions = {};

  withEmail(email: string): this {
    this.user.email = email;
    return this;
  }

  asAdmin(): this {
    this.options.role = "admin";
    return this;
  }

  unverified(): this {
    this.options.verified = false;
    return this;
  }

  withSubscription(tier: "pro" | "enterprise"): this {
    this.options.subscriptionTier = tier;
    return this;
  }

  build(): User {
    return createUser(this.user, this.options);
  }
}

// Usage examples
export const testUsers = {
  admin: () => new UserBuilder().asAdmin().build(),
  unverifiedUser: () => new UserBuilder().unverified().build(),
  proSubscriber: () => new UserBuilder().withSubscription("pro").build(),
};
```

```python
# factories/user_factory.py
import factory
from factory import fuzzy
from datetime import datetime, timedelta
from models import User, UserProfile, Subscription

class UserProfileFactory(factory.Factory):
    class Meta:
        model = UserProfile

    avatar_url = factory.Faker('image_url')
    bio = factory.Faker('sentence')
    timezone = factory.Faker('timezone')

class SubscriptionFactory(factory.Factory):
    class Meta:
        model = Subscription

    tier = 'free'
    expires_at = None

    class Params:
        pro = factory.Trait(
            tier='pro',
            expires_at=factory.LazyFunction(lambda: datetime.now() + timedelta(days=30))
        )
        enterprise = factory.Trait(
            tier='enterprise',
            expires_at=factory.LazyFunction(lambda: datetime.now() + timedelta(days=365))
        )

class UserFactory(factory.Factory):
    class Meta:
        model = User

    id = factory.Faker('uuid4')
    email = factory.LazyAttribute(lambda o: f"{o.first_name.lower()}.{o.last_name.lower()}@example.com")
    first_name = factory.Faker('first_name')
    last_name = factory.Faker('last_name')
    role = 'user'
    status = 'active'
    email_verified = True
    created_at = factory.Faker('date_time_this_year')
    updated_at = factory.Faker('date_time_this_month')
    profile = factory.SubFactory(UserProfileFactory)
    subscription = factory.SubFactory(SubscriptionFactory)

    class Params:
        admin = factory.Trait(role='admin')
        unverified = factory.Trait(email_verified=False)
        inactive = factory.Trait(status='inactive')
        pro_user = factory.Trait(subscription=factory.SubFactory(SubscriptionFactory, pro=True))

# Usage
def test_user_scenarios():
    regular_user = UserFactory()
    admin_user = UserFactory(admin=True)
    unverified_user = UserFactory(unverified=True)
    pro_user = UserFactory(pro_user=True)
```

### Test Data Anonymization

```python
# scripts/anonymize_production_data.py
from faker import Faker
import hashlib

fake = Faker()

ANONYMIZATION_RULES = {
    'users': {
        'email': lambda x: f"user_{hashlib.md5(x.encode()).hexdigest()[:8]}@test.example.com",
        'first_name': lambda x: fake.first_name(),
        'last_name': lambda x: fake.last_name(),
        'phone': lambda x: fake.phone_number(),
        'address': lambda x: fake.address(),
        'ssn': lambda x: '***-**-****',
        'credit_card': lambda x: None,  # Remove entirely
    },
    'orders': {
        'shipping_address': lambda x: fake.address(),
        'billing_address': lambda x: fake.address(),
    },
    'audit_logs': {
        'ip_address': lambda x: fake.ipv4(),
        'user_agent': lambda x: 'Anonymized',
    },
}

def anonymize_table(table_name: str, data: list[dict]) -> list[dict]:
    rules = ANONYMIZATION_RULES.get(table_name, {})
    anonymized = []

    for row in data:
        new_row = row.copy()
        for field, transform in rules.items():
            if field in new_row:
                new_row[field] = transform(new_row[field])
        anonymized.append(new_row)

    return anonymized
```

---

## CI/CD Test Integration

### Multi-Stage Test Pipeline

```yaml
# .github/workflows/test-pipeline.yml
name: Test Pipeline

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
  PYTHON_VERSION: "3.11"

jobs:
  # Stage 1: Static Analysis (Fast feedback)
  static-analysis:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: "npm"
      - run: npm ci
      - name: Type Check
        run: npm run typecheck
      - name: Lint
        run: npm run lint
      - name: Format Check
        run: npm run format:check

  # Stage 2: Unit Tests (Parallel)
  unit-tests:
    needs: static-analysis
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        shard: [1, 2, 3, 4]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: "npm"
      - run: npm ci
      - name: Run Unit Tests (Shard ${{ matrix.shard }}/4)
        run: npm run test:unit -- --shard=${{ matrix.shard }}/4 --coverage
      - name: Upload Coverage
        uses: actions/upload-artifact@v4
        with:
          name: coverage-unit-${{ matrix.shard }}
          path: coverage/

  # Stage 3: Integration Tests
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
          node-version: ${{ env.NODE_VERSION }}
          cache: "npm"
      - run: npm ci
      - name: Run Migrations
        run: npm run migrate:test
        env:
          DATABASE_URL: postgres://postgres:test@localhost:5432/test
      - name: Run Integration Tests
        run: npm run test:integration -- --coverage
        env:
          DATABASE_URL: postgres://postgres:test@localhost:5432/test
          REDIS_URL: redis://localhost:6379
      - name: Upload Coverage
        uses: actions/upload-artifact@v4
        with:
          name: coverage-integration
          path: coverage/

  # Stage 4: API Contract Tests
  contract-tests:
    needs: unit-tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: "npm"
      - run: npm ci
      - name: Run Contract Tests
        run: npm run test:contract
      - name: Publish Contracts
        if: github.ref == 'refs/heads/main'
        run: npm run pact:publish
        env:
          PACT_BROKER_URL: ${{ secrets.PACT_BROKER_URL }}
          PACT_BROKER_TOKEN: ${{ secrets.PACT_BROKER_TOKEN }}

  # Stage 5: E2E Tests
  e2e-tests:
    needs: integration-tests
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        browser: [chromium, firefox]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: "npm"
      - run: npm ci
      - name: Install Playwright
        run: npx playwright install --with-deps ${{ matrix.browser }}
      - name: Start Application
        run: npm run start:test &
      - name: Wait for App
        run: npx wait-on http://localhost:3000 --timeout 60000
      - name: Run E2E Tests (${{ matrix.browser }})
        run: npx playwright test --project=${{ matrix.browser }}
      - name: Upload Test Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: playwright-report-${{ matrix.browser }}
          path: playwright-report/

  # Stage 6: Security Tests
  security-tests:
    needs: static-analysis
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Dependency Audit
        run: npm audit --audit-level=high
      - name: Run SAST (Semgrep)
        uses: returntocorp/semgrep-action@v1
        with:
          config: >-
            p/security-audit
            p/owasp-top-ten
      - name: Run Trivy
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: "fs"
          severity: "CRITICAL,HIGH"

  # Stage 7: Performance Tests (Main branch only)
  performance-tests:
    needs: e2e-tests
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Start Application
        run: docker-compose up -d
      - name: Wait for App
        run: npx wait-on http://localhost:3000 --timeout 120000
      - name: Run K6 Load Tests
        uses: grafana/k6-action@v0.3.1
        with:
          filename: tests/performance/load.js
          flags: --out json=k6-results.json
      - name: Check Performance Thresholds
        run: |
          P95=$(cat k6-results.json | jq '.metrics.http_req_duration.values["p(95)"]')
          if (( $(echo "$P95 > 500" | bc -l) )); then
            echo "::error::P95 latency $P95ms exceeds 500ms threshold"
            exit 1
          fi

  # Stage 8: Merge Coverage Reports
  coverage-report:
    needs: [unit-tests, integration-tests]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Download Coverage Artifacts
        uses: actions/download-artifact@v4
        with:
          pattern: coverage-*
          merge-multiple: true
      - name: Merge Coverage Reports
        run: |
          npm ci
          npx nyc merge coverage merged-coverage.json
          npx nyc report --reporter=lcov --reporter=text-summary -t coverage
      - name: Upload to Codecov
        uses: codecov/codecov-action@v4
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
          files: ./coverage/lcov.info
          fail_ci_if_error: true

  # Quality Gate
  quality-gate:
    needs:
      [
        static-analysis,
        unit-tests,
        integration-tests,
        e2e-tests,
        security-tests,
        coverage-report,
      ]
    if: always()
    runs-on: ubuntu-latest
    steps:
      - name: Check All Jobs
        run: |
          if [ "${{ needs.static-analysis.result }}" != "success" ]; then exit 1; fi
          if [ "${{ needs.unit-tests.result }}" != "success" ]; then exit 1; fi
          if [ "${{ needs.integration-tests.result }}" != "success" ]; then exit 1; fi
          if [ "${{ needs.e2e-tests.result }}" != "success" ]; then exit 1; fi
          if [ "${{ needs.security-tests.result }}" != "success" ]; then exit 1; fi
          echo "All quality gates passed!"
```

### Test Stage Timing Targets

| Stage           | Target Duration | Max Duration | Action if Exceeded     |
| --------------- | --------------- | ------------ | ---------------------- |
| Static Analysis | < 2 min         | 5 min        | Optimize lint config   |
| Unit Tests      | < 5 min         | 10 min       | Add parallelization    |
| Integration     | < 10 min        | 20 min       | Add test containers    |
| Contract Tests  | < 5 min         | 10 min       | Review contract scope  |
| E2E Tests       | < 15 min        | 30 min       | Prioritize critical    |
| Security Tests  | < 10 min        | 20 min       | Cache scan results     |
| Performance     | < 15 min        | 30 min       | Reduce load duration   |
| Total Pipeline  | < 30 min        | 45 min       | Review parallelization |

---

## Test Environment Management

### Environment Configuration

```yaml
# docker-compose.test.yml
version: "3.8"

services:
  app:
    build:
      context: .
      target: test
    environment:
      - NODE_ENV=test
      - DATABASE_URL=postgres://postgres:test@db:5432/test
      - REDIS_URL=redis://redis:6379
      - LOG_LEVEL=error
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    volumes:
      - ./coverage:/app/coverage

  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: test
      POSTGRES_DB: test
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5
    volumes:
      - ./scripts/init-test-db.sql:/docker-entrypoint-initdb.d/init.sql

  redis:
    image: redis:7
    command: redis-server --appendonly no

  # Dedicated E2E environment
  e2e:
    build:
      context: .
      target: e2e
    environment:
      - BASE_URL=http://app:3000
      - HEADLESS=true
    depends_on:
      - app
    volumes:
      - ./playwright-report:/app/playwright-report
      - ./test-results:/app/test-results

  # Mock external services
  mock-server:
    image: mockserver/mockserver:latest
    ports:
      - "1080:1080"
    environment:
      MOCKSERVER_INITIALIZATION_JSON_PATH: /config/expectations.json
    volumes:
      - ./mocks:/config
```

### Environment Matrix

```markdown
| Environment | Database             | External APIs | Test Data   | Cleanup   |
| ----------- | -------------------- | ------------- | ----------- | --------- |
| Local       | SQLite/Testcontainer | Mocked        | Factories   | Per test  |
| CI          | Testcontainer        | Mocked        | Factories   | Per run   |
| Integration | Real (isolated)      | Sandbox       | Seeded      | Per suite |
| Staging     | Real (anonymized)    | Sandbox       | Anonymized  | Daily     |
| Production  | Read-only            | Real          | N/A (smoke) | N/A       |
```

### Test Isolation Strategies

```typescript
// test/setup.ts - Database isolation per test
import { beforeEach, afterEach } from "vitest";
import { db } from "../src/db";

beforeEach(async () => {
  // Start transaction for isolation
  await db.query("BEGIN");
});

afterEach(async () => {
  // Rollback to clean state
  await db.query("ROLLBACK");
});

// Alternative: Truncate tables
async function truncateAllTables() {
  const tables = await db.query(`
    SELECT tablename FROM pg_tables
    WHERE schemaname = 'public'
    AND tablename != 'migrations'
  `);

  for (const { tablename } of tables.rows) {
    await db.query(`TRUNCATE TABLE ${tablename} CASCADE`);
  }
}
```

---

## Performance Test Strategy

### Load Testing Configuration

```javascript
// tests/performance/load.js - K6 Load Test
import http from "k6/http";
import { check, sleep } from "k6";
import { Rate, Trend } from "k6/metrics";

// Custom metrics
const errorRate = new Rate("errors");
const apiDuration = new Trend("api_duration");

// Test configuration
export const options = {
  stages: [
    { duration: "2m", target: 50 }, // Ramp up to 50 users
    { duration: "5m", target: 50 }, // Stay at 50 users
    { duration: "2m", target: 100 }, // Ramp up to 100 users
    { duration: "5m", target: 100 }, // Stay at 100 users
    { duration: "2m", target: 0 }, // Ramp down
  ],
  thresholds: {
    http_req_duration: ["p(95)<500", "p(99)<1000"], // 95% < 500ms, 99% < 1s
    http_req_failed: ["rate<0.01"], // Error rate < 1%
    errors: ["rate<0.05"], // Custom error rate < 5%
  },
};

const BASE_URL = __ENV.BASE_URL || "http://localhost:3000";

export default function () {
  // Scenario 1: Health check
  const healthRes = http.get(`${BASE_URL}/health`);
  check(healthRes, {
    "health check status is 200": (r) => r.status === 200,
  });

  // Scenario 2: API endpoint
  const apiRes = http.get(`${BASE_URL}/api/users`, {
    headers: { Authorization: `Bearer ${__ENV.API_TOKEN}` },
  });

  const success = check(apiRes, {
    "API status is 200": (r) => r.status === 200,
    "API response time < 500ms": (r) => r.timings.duration < 500,
    "API has valid JSON": (r) => {
      try {
        JSON.parse(r.body);
        return true;
      } catch {
        return false;
      }
    },
  });

  errorRate.add(!success);
  apiDuration.add(apiRes.timings.duration);

  // Scenario 3: POST request
  const payload = JSON.stringify({
    name: `Test User ${__VU}`,
    email: `test${__VU}@example.com`,
  });

  const postRes = http.post(`${BASE_URL}/api/users`, payload, {
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${__ENV.API_TOKEN}`,
    },
  });

  check(postRes, {
    "POST status is 201": (r) => r.status === 201,
  });

  sleep(1); // Think time
}

// Lifecycle hooks
export function setup() {
  // Setup: Get auth token, warm up caches
  const loginRes = http.post(
    `${BASE_URL}/api/auth/login`,
    JSON.stringify({
      email: "loadtest@example.com",
      password: "loadtest123",
    }),
    { headers: { "Content-Type": "application/json" } },
  );

  return { token: JSON.parse(loginRes.body).token };
}

export function teardown(data) {
  // Cleanup: Delete test data
  console.log("Test completed. Total VUs:", __VU);
}
```

### Performance Test Types

| Test Type   | Purpose                       | Duration  | Load Pattern            |
| ----------- | ----------------------------- | --------- | ----------------------- |
| Smoke       | Verify system works           | 1-5 min   | Minimal (1-5 users)     |
| Load        | Typical load behavior         | 15-30 min | Gradual ramp            |
| Stress      | Breaking point                | 20-60 min | Beyond normal capacity  |
| Spike       | Sudden traffic surge          | 10-15 min | Sharp increase/decrease |
| Endurance   | Sustained load (memory leaks) | 1-8 hours | Steady state            |
| Scalability | Capacity planning             | Variable  | Incremental increase    |

### Performance Baselines

```yaml
# performance-baselines.yml
endpoints:
  health_check:
    p50: 10ms
    p95: 50ms
    p99: 100ms
    max_rps: 10000

  api_list:
    p50: 100ms
    p95: 250ms
    p99: 500ms
    max_rps: 1000

  api_create:
    p50: 150ms
    p95: 300ms
    p99: 600ms
    max_rps: 500

  api_search:
    p50: 200ms
    p95: 500ms
    p99: 1000ms
    max_rps: 200

system:
  cpu_threshold: 80%
  memory_threshold: 85%
  error_rate_threshold: 1%
  connection_pool_exhaustion: 0
```

---

## Security Test Strategy

### Security Test Integration

```yaml
# .github/workflows/security-tests.yml
name: Security Tests

on:
  push:
    branches: [main]
  pull_request:
  schedule:
    - cron: "0 6 * * *" # Daily security scan

jobs:
  dependency-audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm audit --audit-level=high
      - name: Snyk Test
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}

  sast:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Semgrep
        uses: returntocorp/semgrep-action@v1
        with:
          config: >-
            p/owasp-top-ten
            p/security-audit
            p/secrets
            p/sql-injection
            p/xss

  secret-scanning:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  api-security-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Start Application
        run: docker-compose up -d
      - name: OWASP ZAP Scan
        uses: zaproxy/action-api-scan@v0.7.0
        with:
          target: "http://localhost:3000/api"
          format: openapi
          rules_file_name: ".zap/rules.tsv"

  container-security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build Image
        run: docker build -t app:test .
      - name: Trivy Scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: "app:test"
          severity: "CRITICAL,HIGH"
          exit-code: "1"
```

### Security Test Checklist

```markdown
## Authentication & Authorization Tests

- [ ] Password brute force protection
- [ ] Session management (timeout, invalidation)
- [ ] JWT token validation (expiry, signature)
- [ ] Role-based access control (RBAC)
- [ ] OAuth/OIDC flow security

## Input Validation Tests

- [ ] SQL injection
- [ ] NoSQL injection
- [ ] XSS (reflected, stored, DOM)
- [ ] Command injection
- [ ] Path traversal
- [ ] SSRF

## API Security Tests

- [ ] Rate limiting
- [ ] CORS configuration
- [ ] Content-Type validation
- [ ] Request size limits
- [ ] API key/token security

## Data Security Tests

- [ ] Sensitive data encryption (at rest, in transit)
- [ ] PII handling
- [ ] Data leakage prevention
- [ ] Audit logging

## Infrastructure Tests

- [ ] HTTPS enforcement
- [ ] Security headers (CSP, HSTS, etc.)
- [ ] Cookie security flags
- [ ] Dependency vulnerabilities
```

---

## Multi-Agent Testing Orchestration

### Agent Coordination Workflow

```markdown
## Test Orchestration Protocol

### Phase 1: Test Planning (Test Architect)

1. Analyze feature requirements
2. Design test strategy (pyramid distribution)
3. Identify test data needs
4. Define coverage targets
5. Create test plan document

### Phase 2: Unit Testing (Unit Test Expert)

- Implement unit tests for business logic
- Achieve 80%+ code coverage
- Test edge cases and error handling
- Report coverage metrics

### Phase 3: Integration Testing (Integration Test Expert)

- Test API endpoints
- Verify database operations
- Test service interactions
- Validate error responses

### Phase 4: E2E Testing (E2E Test Expert)

- Implement critical user journey tests
- Cross-browser testing
- Visual regression checks
- Accessibility testing

### Phase 5: API Testing (API Test Expert)

- Contract testing (Pact)
- Schema validation
- Load testing preparation
- API documentation verification

### Phase 6: Performance Testing (Performance Test Expert)

- Execute load tests
- Analyze bottlenecks
- Verify SLA compliance
- Report performance metrics

### Phase 7: Security Testing (Security Expert)

- SAST scanning
- Dependency audit
- Penetration testing
- Security report generation

### Phase 8: Test Review (Test Architect)

- Review all test results
- Verify coverage targets met
- Approve/request changes
- Sign off on quality gate
```

### Agent Communication Protocol

```typescript
// Test orchestration interface
interface TestOrchestrationRequest {
  taskId: string;
  feature: string;
  testPhase:
    | "planning"
    | "unit"
    | "integration"
    | "e2e"
    | "api"
    | "performance"
    | "security"
    | "review";
  context: {
    requirements: string[];
    codeChanges: string[];
    existingTests: string[];
    coverageTarget: number;
  };
}

interface TestOrchestrationResult {
  taskId: string;
  phase: string;
  status: "pass" | "fail" | "warning";
  metrics: {
    testsWritten: number;
    coverageAchieved: number;
    issuesFound: number;
  };
  artifacts: string[];
  nextPhase: string | null;
  blockers: string[];
}
```

---

## Related Agents

| Agent                                     | Use Case                                         |
| ----------------------------------------- | ------------------------------------------------ |
| `/agents/testing/unit-test-expert`        | Unit test implementation, mocking strategies     |
| `/agents/testing/integration-test-expert` | API and database integration tests               |
| `/agents/testing/e2e-test-expert`         | Playwright/Cypress E2E test implementation       |
| `/agents/testing/api-test-expert`         | API testing, contract testing, schema validation |
| `/agents/testing/performance-test-expert` | K6/Locust load and stress testing                |
| `/agents/testing/test-data-expert`        | Factories, fixtures, data anonymization          |
| `/agents/testing/tdd-coach`               | TDD methodology guidance                         |
| `/agents/testing/api-contract-agent`      | Consumer-driven contract testing                 |
| `/agents/security/security-expert`        | Security test strategy and OWASP coverage        |
| `/agents/security/penetration-tester`     | Penetration testing and vulnerability assessment |
| `/agents/devops/ci-cd-expert`             | Pipeline integration and test automation         |
| `/agents/quality/performance-analyst`     | Performance metrics analysis and optimization    |

---

## Example Usage

```bash
# Design comprehensive test strategy for a new feature
/agents/testing/test-architect design test strategy for payment processing module with PCI compliance requirements

# Create test pyramid for microservices architecture
/agents/testing/test-architect create test pyramid for microservices with contract testing between services

# Define coverage requirements for critical module
/agents/testing/test-architect define coverage requirements and enforcement for authentication module with 95% target

# Design test infrastructure for monorepo
/agents/testing/test-architect design test infrastructure for TypeScript monorepo with parallel execution

# Create test data strategy
/agents/testing/test-architect create test data management strategy with GDPR-compliant anonymization

# Set up CI/CD test pipeline
/agents/testing/test-architect design GitHub Actions pipeline with staged test execution and quality gates

# Design performance test strategy
/agents/testing/test-architect create performance testing strategy with baseline definitions and SLA targets

# Integrate security testing
/agents/testing/test-architect integrate OWASP security testing into existing test suite

# Orchestrate multi-agent testing
/agents/testing/test-architect orchestrate testing workflow for new feature using unit, integration, and e2e agents

# Analyze test gaps
/agents/testing/test-architect analyze test coverage gaps and recommend improvements for API module

# Design E2E test environment
/agents/testing/test-architect design isolated E2E test environment with mock services and test data

# Create test metrics dashboard
/agents/testing/test-architect define test metrics and KPIs for quality reporting dashboard
```

---

## Troubleshooting Common Issues

| Issue                     | Cause                    | Solution                              |
| ------------------------- | ------------------------ | ------------------------------------- |
| Flaky tests               | Race conditions, timing  | Add proper waits, isolate tests       |
| Low coverage              | Missing edge cases       | Use mutation testing, review gaps     |
| Slow test suite           | No parallelization       | Shard tests, optimize fixtures        |
| Test data pollution       | Poor isolation           | Use transactions, truncate tables     |
| Environment differences   | Config drift             | Use containers, standardize env       |
| False positives           | Overly strict assertions | Focus on behavior, not implementation |
| Memory leaks in tests     | Uncleaned resources      | Add proper teardown, use afterEach    |
| Dependency mocking issues | Tight coupling           | Use dependency injection              |
| E2E test timeouts         | Slow app startup         | Optimize build, add health checks     |
| Contract test failures    | API changes              | Version contracts, coordinate teams   |

---

## Quick Reference

```bash
# Run test pyramid
npm run test:unit && npm run test:integration && npm run test:e2e

# Check coverage
npm run test:coverage -- --coverageThreshold='{"global":{"lines":80}}'

# Run specific test type
npm run test:unit -- --testPathPattern="auth"
npm run test:integration -- --testNamePattern="API"
npx playwright test --grep="@critical"

# Performance testing
k6 run tests/performance/load.js
k6 run --vus 100 --duration 5m tests/performance/stress.js

# Security testing
npm audit --audit-level=high
npx semgrep --config p/owasp-top-ten .

# Generate test report
npx jest --coverage --coverageReporters=html
npx playwright show-report

# Debug flaky tests
npm run test:unit -- --runInBand --verbose
npx playwright test --debug

# Test data management
npm run seed:test
npm run db:truncate:test
```
