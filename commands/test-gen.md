---
name: test-gen
version: 1.0.0
description: Generate comprehensive tests from code analysis, covering unit, integration, and E2E with framework-specific patterns.
---

# Test Generation Skill

## Purpose
Automatically generate comprehensive tests based on code analysis with consistent naming, coverage goals, and framework-specific best practices.

## Core Capabilities
1. Unit test generation from code analysis
2. Integration test generation
3. E2E test generation (Playwright patterns)
4. Test coverage analysis
5. Mock generation
6. Test data generation
7. Property-based testing
8. Mutation testing integration
9. Test naming conventions
10. Framework-specific patterns (Jest, pytest, Go testing)

## Workflow
1. Analyze target code: public APIs, side effects, dependencies, error paths.
2. Identify test seams: pure functions, I/O boundaries, network/DB, UI.
3. Propose test plan: unit/integration/e2e split with priorities.
4. Generate tests with mocks, fixtures, and data factories.
5. Validate coverage risks and add edge/property/mutation tests.

## Output Requirements
- Prefer TypeScript for JS/TS projects; avoid `any`.
- Explicit types for props, inputs, outputs, and mocks.
- Include loading/error states for async flows.
- Use deterministic test data by default.
- Accessibility checks for UI tests.

## Test Naming Conventions
- Use `describe("<module>")` and `it("should <behavior>")`.
- Group by behavior, not implementation.
- Include edge cases: empty, null/undefined, invalid, large input.

## Unit Tests
- Isolate functions with mocks/stubs.
- Cover branches: success, failure, boundary.
- Example (Jest/Vitest):

```ts
import { describe, it, expect, vi } from "vitest";
import { functionName } from "./module";

describe("module/functionName", () => {
  it("should handle normal case", () => {
    expect(functionName("input")).toBe("expected");
  });

  it("should throw on invalid input", () => {
    expect(() => functionName("invalid")).toThrow();
  });
});
```

## Integration Tests
- Exercise real boundaries: DB, API, filesystem.
- Use test containers or in-memory substitutes.
- Clean up resources after tests.

## E2E Tests (Playwright)
- Use page object patterns for complex flows.
- Assert critical user journeys and accessibility.
- Example:

```ts
import { test, expect } from "@playwright/test";

test("user can sign in", async ({ page }) => {
  await page.goto("/signin");
  await page.getByLabel("Email").fill("user@example.com");
  await page.getByLabel("Password").fill("password123");
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page).toHaveURL("/dashboard");
});
```

## Test Coverage Analysis
- Report statement/branch/function coverage.
- Prioritize missing branches and error paths.
- Suggest minimal tests to close gaps.

## Mock Generation
- Mock external dependencies with explicit types.
- Use dependency injection where possible.
- Keep mocks minimal and realistic.

## Test Data Generation
- Provide factories and fixtures.
- Use deterministic seeds for random data.
- Cover edge and boundary inputs.

## Property-Based Testing
- Use `fast-check` (JS/TS), `hypothesis` (Python), `gopter` (Go).
- Express invariants and shrink failing cases.

## Mutation Testing Integration
- Recommend `stryker` (JS/TS), `mutmut` (Python), `go-mutesting` (Go).
- Add mutation tests for critical logic paths.

## Framework-Specific Patterns
- Jest/Vitest (TS/JS):
  - Use `describe/it`, `beforeEach/afterEach`.
  - Mock with `vi.mock` or `jest.mock`.
- pytest (Python):
  - Use fixtures, parametrization, and `pytest.raises`.
- Go testing:
  - Use table-driven tests and `t.Run`.

## Completion Checklist
- [ ] Unit tests for all public APIs
- [ ] Integration tests for external boundaries
- [ ] E2E tests for critical flows
- [ ] Mocks and fixtures generated
- [ ] Coverage gaps identified
- [ ] Property-based tests for invariants
- [ ] Mutation testing configured
- [ ] Naming conventions applied
