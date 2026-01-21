---
name: ab-method.test-mission
description: Generate and organize tests for a mission's deliverables.
version: 1.0.0
integration_with_tri_agent_workflow: |
  - Codex: derive test cases from acceptance criteria and implement tests.
  - Claude Code: review test strategy for coverage gaps.
  - Gemini CLI: analyze large codebases for related test patterns.
templates_and_examples: |
  - Test strategy template
  - Unit and integration test templates
  - Example usage
step_by_step_execution_protocol: |
  1) Read mission scope, acceptance criteria, and touched files.
  2) Produce a test strategy and prioritize cases.
  3) Write tests with fixtures and factories as needed.
  4) Run or propose the test commands.
  5) Summarize results and gaps.
---

# Test Mission

Generate comprehensive tests for a mission's deliverables.

## Arguments
- `$ARGUMENTS`: Mission ID or feature to test

## Inputs
- Mission plan or state
- Affected files and acceptance criteria
- Existing test setup and conventions

## Outputs
- Test strategy
- New or updated tests
- Suggested test commands

## Execution Protocol
1) Parse mission objectives and acceptance criteria.
2) Identify component, integration, and end-to-end needs.
3) Draft test cases with fixtures and factories.
4) Implement tests aligned with repo patterns.
5) Provide run commands and note gaps or risks.

## Test Strategy Template
```markdown
# Test Strategy: [Mission Title]

## Scope
- Components: [list]
- APIs: [list]
- Data flows: [list]

## Priorities
1. Critical path behaviors
2. Edge cases and validation
3. Error handling and security

## Coverage Targets
- Unit tests: [target percentage]
- Integration tests: [target percentage]
- E2E tests: [target percentage]
```

## Unit Test Template
```typescript
import { describe, it, expect } from "vitest";

describe("[Unit Under Test]", () => {
  it("should [expected behavior]", () => {
    const input = /* arrange */;

    const result = functionUnderTest(input);

    expect(result).toBe(/* expected */);
  });

  it("should handle [edge case]", () => {
    // Add edge case
  });

  it("should throw on [invalid input]", () => {
    expect(() => functionUnderTest(/* invalid */)).toThrow();
  });
});
```

## Integration Test Template
```typescript
import request from "supertest";
import { describe, it, expect } from "vitest";
import { app } from "../app";

describe("[Feature] integration", () => {
  it("should [behavior]", async () => {
    const response = await request(app)
      .post("/api/resource")
      .send({ /* payload */ })
      .expect(201);

    expect(response.body).toMatchObject({
      id: expect.any(String)
    });
  });
});
```

## Test Data Template
```typescript
export const validPayload = {
  // Populate with valid data
};

export const invalidPayload = {
  // Populate with invalid data
};
```

## Examples
```
/test-mission MISSION-001
/test-mission authentication-feature
/test-mission src/features/auth
```

## Tri-Agent Workflow Integration
- Ask Claude Code to review for missing test cases.
- Ask Gemini CLI to find similar tests in large repos.
- Use Codex to implement and adjust tests efficiently.
