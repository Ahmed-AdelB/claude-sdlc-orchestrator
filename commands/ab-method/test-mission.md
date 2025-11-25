# Test Mission

Generate comprehensive tests for a mission's deliverables.

## Arguments
- `$ARGUMENTS` - Mission ID or feature to test

## Process

### Step 1: Analyze Mission Scope
Read the mission specification to identify:
- Components created/modified
- Expected behaviors
- Edge cases from acceptance criteria
- Integration points

### Step 2: Determine Test Strategy

```markdown
# Test Strategy for: [Mission Title]

## Test Pyramid

### Unit Tests (70%)
- Individual functions
- Class methods
- Utility functions
- Pure logic

### Integration Tests (20%)
- API endpoints
- Database operations
- Service interactions
- Authentication flows

### E2E Tests (10%)
- Critical user journeys
- Happy path scenarios
- Key workflows
```

### Step 3: Generate Tests

#### Unit Test Template
```typescript
describe('[Component/Function Name]', () => {
  describe('[Method/Scenario]', () => {
    it('should [expected behavior] when [condition]', () => {
      // Arrange
      const input = /* test data */;

      // Act
      const result = functionUnderTest(input);

      // Assert
      expect(result).toBe(/* expected */);
    });

    it('should handle [edge case]', () => {
      // Test edge case
    });

    it('should throw error when [invalid condition]', () => {
      // Test error handling
    });
  });
});
```

#### Integration Test Template
```typescript
describe('[API/Feature] Integration', () => {
  beforeAll(async () => {
    // Setup test database/mocks
  });

  afterAll(async () => {
    // Cleanup
  });

  describe('POST /api/resource', () => {
    it('should create resource with valid data', async () => {
      const response = await request(app)
        .post('/api/resource')
        .send(validData)
        .expect(201);

      expect(response.body).toMatchObject({
        id: expect.any(String),
        ...validData
      });
    });

    it('should return 400 for invalid data', async () => {
      const response = await request(app)
        .post('/api/resource')
        .send(invalidData)
        .expect(400);

      expect(response.body.error).toBeDefined();
    });

    it('should return 401 without authentication', async () => {
      await request(app)
        .post('/api/resource')
        .send(validData)
        .expect(401);
    });
  });
});
```

### Step 4: Generate Test Data
Create test fixtures and factories:

```typescript
// factories/user.factory.ts
export const createTestUser = (overrides = {}) => ({
  id: faker.string.uuid(),
  email: faker.internet.email(),
  name: faker.person.fullName(),
  createdAt: new Date(),
  ...overrides
});

// fixtures/auth.fixtures.ts
export const validCredentials = {
  email: 'test@example.com',
  password: 'ValidP@ssw0rd'
};

export const invalidCredentials = {
  email: 'invalid',
  password: '123'
};
```

### Step 5: Run Tests
Execute tests and report results:

```markdown
## Test Results

### Summary
✅ Passed: 45
❌ Failed: 2
⏭️ Skipped: 1
📊 Coverage: 87%

### Failed Tests
1. `auth.test.ts` - "should refresh expired token"
   - Expected: New token returned
   - Actual: 401 Unauthorized
   - Suggested fix: Check token refresh logic

2. `user.test.ts` - "should handle concurrent updates"
   - Expected: Last write wins
   - Actual: Race condition detected
   - Suggested fix: Add optimistic locking

### Coverage Report
| File | Statements | Branches | Functions | Lines |
|------|------------|----------|-----------|-------|
| auth.ts | 95% | 88% | 100% | 95% |
| user.ts | 82% | 75% | 90% | 82% |
```

### Step 6: Suggest Improvements
- Missing test cases
- Uncovered edge cases
- Flaky test detection
- Performance test suggestions

## Example Usage
```
/test-mission MISSION-001
/test-mission authentication-feature
/test-mission src/features/auth
```

## Test Types Generated

### Happy Path Tests
- Normal operation with valid inputs
- Expected successful outcomes

### Edge Case Tests
- Empty inputs
- Maximum/minimum values
- Boundary conditions

### Error Case Tests
- Invalid inputs
- Missing required fields
- Authorization failures

### Security Tests
- SQL injection attempts
- XSS payloads
- Authentication bypass attempts
