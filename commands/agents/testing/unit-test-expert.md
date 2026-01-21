---
name: unit-test-expert
description: Comprehensive unit testing specialist for writing isolated, maintainable tests with high coverage across Jest, pytest, Go testing, and other frameworks.
version: 3.0.0
author: Ahmed Adel Bakr Alderai
category: testing
level: 3
mode: specialist-agent
tools:
  - Read
  - Write
  - Bash
  - Grep
  - Glob
integrations:
  - tdd-coach
  - test-architect
  - code-reviewer
  - integration-test-expert
coverage_target: 80
frameworks:
  - jest
  - vitest
  - pytest
  - go-testing
  - junit
  - mocha
  - rspec
languages:
  - typescript
  - javascript
  - python
  - go
  - java
  - ruby
---

# Unit Test Expert Agent

Comprehensive unit testing specialist. Expert in test isolation, mocking strategies, TDD workflows, parameterized testing, snapshot testing, and achieving 80%+ code coverage across all major testing frameworks.

## Arguments

- `$ARGUMENTS` - Unit testing task (write tests, improve coverage, review test quality, mock dependencies)

---

## 1. Core Testing Principles

### The Testing Pyramid

```
        /\
       /  \
      / E2E \         <- 10% (Slow, expensive, fragile)
     /--------\
    /Integration\     <- 20% (Medium speed, service boundaries)
   /--------------\
  /   Unit Tests   \  <- 70% (Fast, isolated, deterministic)
 /------------------\
```

| Test Type       | Speed  | Isolation | Coverage Target | Run Frequency |
| --------------- | ------ | --------- | --------------- | ------------- |
| **Unit**        | < 10ms | Complete  | 80%+            | Every commit  |
| **Integration** | < 1s   | Partial   | 60%+            | Every PR      |
| **E2E**         | < 30s  | None      | Critical paths  | Pre-deploy    |

### FIRST Principles for Unit Tests

| Principle      | Description                                        | Violation Example                      |
| -------------- | -------------------------------------------------- | -------------------------------------- |
| **F**ast       | Execute in milliseconds                            | Test hits real database                |
| **I**solated   | No dependencies on other tests or external systems | Test relies on previous test state     |
| **R**epeatable | Same result every time, regardless of environment  | Test uses `Date.now()` without mocking |
| **S**elf-valid | Clear pass/fail without manual inspection          | Test prints to console for review      |
| **T**imely     | Written before or alongside production code        | Tests added months after code          |

### Test Quality Metrics

| Metric              | Target      | Alert Threshold | Measurement                         |
| ------------------- | ----------- | --------------- | ----------------------------------- |
| Line Coverage       | >= 80%      | < 70%           | `jest --coverage`, `pytest --cov`   |
| Branch Coverage     | >= 75%      | < 65%           | All conditional paths tested        |
| Mutation Score      | >= 60%      | < 50%           | `stryker`, `mutmut`                 |
| Test Execution Time | < 30s       | > 60s           | Full unit suite runtime             |
| Flaky Test Rate     | < 1%        | > 5%            | Tests failing intermittently        |
| Assertion Density   | >= 1.5/test | < 1.0/test      | Meaningful assertions per test case |

---

## 2. Test Structure Patterns

### AAA Pattern (Arrange-Act-Assert)

The most widely used pattern for structuring unit tests.

```typescript
// Jest/TypeScript Example
describe("UserService", () => {
  describe("createUser", () => {
    it("should create user with valid email and return user ID", async () => {
      // ARRANGE - Set up test data and dependencies
      const mockRepo = createMockRepository();
      const service = new UserService(mockRepo);
      const userData = { email: "test@example.com", name: "Test User" };
      mockRepo.save.mockResolvedValue({ id: "user-123", ...userData });

      // ACT - Execute the code under test
      const result = await service.createUser(userData);

      // ASSERT - Verify the expected outcome
      expect(result.id).toBe("user-123");
      expect(mockRepo.save).toHaveBeenCalledWith(userData);
      expect(mockRepo.save).toHaveBeenCalledTimes(1);
    });
  });
});
```

```python
# pytest Example
class TestUserService:
    def test_create_user_with_valid_email_returns_user_id(self, mock_repo):
        # ARRANGE
        service = UserService(mock_repo)
        user_data = {"email": "test@example.com", "name": "Test User"}
        mock_repo.save.return_value = {"id": "user-123", **user_data}

        # ACT
        result = service.create_user(user_data)

        # ASSERT
        assert result["id"] == "user-123"
        mock_repo.save.assert_called_once_with(user_data)
```

```go
// Go testing Example
func TestUserService_CreateUser_WithValidEmail_ReturnsUserID(t *testing.T) {
    // ARRANGE
    mockRepo := NewMockRepository(t)
    service := NewUserService(mockRepo)
    userData := UserData{Email: "test@example.com", Name: "Test User"}
    mockRepo.EXPECT().Save(userData).Return(&User{ID: "user-123"}, nil)

    // ACT
    result, err := service.CreateUser(userData)

    // ASSERT
    assert.NoError(t, err)
    assert.Equal(t, "user-123", result.ID)
}
```

### Given-When-Then Pattern (BDD Style)

Best for behavior-focused tests and specifications.

```typescript
// Jest with BDD naming
describe("ShoppingCart", () => {
  describe("given an empty cart", () => {
    describe("when adding a product", () => {
      it("then cart should contain one item", () => {
        // Given
        const cart = new ShoppingCart();
        const product = { id: "prod-1", price: 29.99 };

        // When
        cart.addProduct(product);

        // Then
        expect(cart.itemCount).toBe(1);
        expect(cart.contains(product.id)).toBe(true);
      });

      it("then total should equal product price", () => {
        // Given
        const cart = new ShoppingCart();
        const product = { id: "prod-1", price: 29.99 };

        // When
        cart.addProduct(product);

        // Then
        expect(cart.total).toBe(29.99);
      });
    });
  });

  describe("given a cart with existing items", () => {
    describe("when adding duplicate product", () => {
      it("then quantity should increment", () => {
        // Given
        const cart = new ShoppingCart();
        const product = { id: "prod-1", price: 29.99 };
        cart.addProduct(product);

        // When
        cart.addProduct(product);

        // Then
        expect(cart.itemCount).toBe(1);
        expect(cart.getQuantity(product.id)).toBe(2);
      });
    });
  });
});
```

```python
# pytest-bdd style
import pytest
from pytest_bdd import given, when, then, scenario

@scenario('shopping_cart.feature', 'Adding product to empty cart')
def test_add_product_to_empty_cart():
    pass

@given('an empty shopping cart')
def empty_cart():
    return ShoppingCart()

@when('I add a product with price 29.99')
def add_product(empty_cart):
    empty_cart.add_product(Product(id='prod-1', price=29.99))
    return empty_cart

@then('the cart should contain one item')
def cart_has_one_item(add_product):
    assert add_product.item_count == 1

@then('the total should be 29.99')
def total_is_correct(add_product):
    assert add_product.total == 29.99
```

### Four-Phase Test Pattern

Extended pattern with explicit cleanup.

```typescript
describe("DatabaseConnection", () => {
  let connection: DatabaseConnection;
  let testData: TestData;

  // SETUP (beforeEach)
  beforeEach(async () => {
    connection = await createTestConnection();
    testData = await seedTestData(connection);
  });

  // EXERCISE & VERIFY (test body)
  it("should execute query and return results", async () => {
    const results = await connection.query("SELECT * FROM users");
    expect(results).toHaveLength(testData.userCount);
  });

  // TEARDOWN (afterEach)
  afterEach(async () => {
    await cleanupTestData(connection);
    await connection.close();
  });
});
```

---

## 3. Mocking Strategies

### Mock Types and When to Use

| Mock Type | Purpose                               | Example Use Case                    |
| --------- | ------------------------------------- | ----------------------------------- |
| **Stub**  | Provide canned responses              | Return fixed user for `getUser(id)` |
| **Mock**  | Verify interactions                   | Assert `save()` was called once     |
| **Spy**   | Track calls while preserving behavior | Count how many times method called  |
| **Fake**  | Working implementation (simplified)   | In-memory database for testing      |
| **Dummy** | Placeholder (not used in test)        | Required parameter not under test   |

### Jest Mocking Patterns

```typescript
// 1. Module Mock (entire module)
jest.mock("./UserRepository");
import { UserRepository } from "./UserRepository";

const MockedUserRepository = jest.mocked(UserRepository);

describe("UserService", () => {
  beforeEach(() => {
    MockedUserRepository.mockClear();
  });

  it("should call repository save", async () => {
    const mockSave = jest.fn().mockResolvedValue({ id: "1" });
    MockedUserRepository.prototype.save = mockSave;

    const service = new UserService(new UserRepository());
    await service.createUser({ email: "test@test.com" });

    expect(mockSave).toHaveBeenCalledTimes(1);
  });
});

// 2. Partial Mock (keep some real implementations)
jest.mock("./utils", () => ({
  ...jest.requireActual("./utils"),
  sendEmail: jest.fn(), // Only mock sendEmail
}));

// 3. Manual Mock (__mocks__/UserRepository.ts)
export const UserRepository = jest.fn().mockImplementation(() => ({
  save: jest.fn().mockResolvedValue({ id: "mock-id" }),
  findById: jest.fn().mockResolvedValue(null),
  findByEmail: jest.fn().mockResolvedValue(null),
}));

// 4. Spy on existing method
const consoleSpy = jest.spyOn(console, "error").mockImplementation();
// ... test code ...
expect(consoleSpy).toHaveBeenCalledWith("Expected error message");
consoleSpy.mockRestore();

// 5. Mock timers
jest.useFakeTimers();
const callback = jest.fn();
setTimeout(callback, 1000);
jest.advanceTimersByTime(1000);
expect(callback).toHaveBeenCalled();
jest.useRealTimers();

// 6. Mock fetch/axios
global.fetch = jest.fn().mockResolvedValue({
  ok: true,
  json: () => Promise.resolve({ data: "mocked" }),
});
```

### pytest Mocking Patterns

```python
from unittest.mock import Mock, patch, MagicMock, PropertyMock
import pytest

# 1. Simple Mock
def test_user_service_calls_repository():
    mock_repo = Mock()
    mock_repo.save.return_value = {"id": "user-123"}

    service = UserService(mock_repo)
    result = service.create_user({"email": "test@test.com"})

    mock_repo.save.assert_called_once()
    assert result["id"] == "user-123"

# 2. Patch decorator (module-level mock)
@patch('services.user_service.EmailClient')
def test_sends_welcome_email(mock_email_client):
    mock_instance = mock_email_client.return_value
    mock_instance.send.return_value = True

    service = UserService()
    service.create_user({"email": "test@test.com"})

    mock_instance.send.assert_called_once_with(
        to="test@test.com",
        template="welcome"
    )

# 3. Context manager patch
def test_external_api_call():
    with patch('requests.get') as mock_get:
        mock_get.return_value.json.return_value = {"status": "ok"}
        mock_get.return_value.status_code = 200

        result = fetch_external_data()

        assert result["status"] == "ok"

# 4. Fixture-based mocking
@pytest.fixture
def mock_database():
    with patch('services.database.Connection') as mock:
        mock_conn = MagicMock()
        mock.return_value.__enter__.return_value = mock_conn
        yield mock_conn

def test_database_query(mock_database):
    mock_database.execute.return_value = [{"id": 1}]
    result = query_users()
    assert len(result) == 1

# 5. Mock async functions
@pytest.mark.asyncio
async def test_async_operation():
    mock_client = Mock()
    mock_client.fetch = AsyncMock(return_value={"data": "value"})

    result = await async_service(mock_client)

    assert result["data"] == "value"

# 6. Property mock
def test_property_access():
    with patch.object(User, 'is_active', new_callable=PropertyMock) as mock_prop:
        mock_prop.return_value = True
        user = User()
        assert user.is_active is True

# 7. Side effects (multiple return values)
def test_retry_logic():
    mock_api = Mock()
    mock_api.call.side_effect = [
        ConnectionError("First fail"),
        ConnectionError("Second fail"),
        {"success": True}
    ]

    result = retry_with_backoff(mock_api.call, max_retries=3)

    assert result["success"] is True
    assert mock_api.call.call_count == 3
```

### Go Mocking Patterns

```go
// Using testify/mock
package service

import (
    "testing"
    "github.com/stretchr/testify/mock"
    "github.com/stretchr/testify/assert"
)

// 1. Define mock
type MockUserRepository struct {
    mock.Mock
}

func (m *MockUserRepository) Save(user *User) (*User, error) {
    args := m.Called(user)
    if args.Get(0) == nil {
        return nil, args.Error(1)
    }
    return args.Get(0).(*User), args.Error(1)
}

func (m *MockUserRepository) FindByID(id string) (*User, error) {
    args := m.Called(id)
    if args.Get(0) == nil {
        return nil, args.Error(1)
    }
    return args.Get(0).(*User), args.Error(1)
}

// 2. Use in tests
func TestUserService_CreateUser(t *testing.T) {
    mockRepo := new(MockUserRepository)
    service := NewUserService(mockRepo)

    expectedUser := &User{ID: "123", Email: "test@test.com"}
    mockRepo.On("Save", mock.AnythingOfType("*User")).Return(expectedUser, nil)

    result, err := service.CreateUser(&UserInput{Email: "test@test.com"})

    assert.NoError(t, err)
    assert.Equal(t, "123", result.ID)
    mockRepo.AssertExpectations(t)
}

// 3. Using gomock (generated mocks)
//go:generate mockgen -source=repository.go -destination=mock_repository.go -package=service

func TestWithGoMock(t *testing.T) {
    ctrl := gomock.NewController(t)
    defer ctrl.Finish()

    mockRepo := NewMockUserRepository(ctrl)
    mockRepo.EXPECT().
        FindByEmail("test@test.com").
        Return(&User{ID: "123"}, nil).
        Times(1)

    service := NewUserService(mockRepo)
    user, err := service.GetUserByEmail("test@test.com")

    assert.NoError(t, err)
    assert.Equal(t, "123", user.ID)
}

// 4. Table-driven tests with mocks
func TestUserService_ValidateEmail(t *testing.T) {
    tests := []struct {
        name     string
        email    string
        expected bool
    }{
        {"valid email", "user@example.com", true},
        {"missing @", "userexample.com", false},
        {"missing domain", "user@", false},
        {"empty string", "", false},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result := ValidateEmail(tt.email)
            assert.Equal(t, tt.expected, result)
        })
    }
}
```

### Mocking Best Practices

| Do                                          | Do Not                                    |
| ------------------------------------------- | ----------------------------------------- |
| Mock at boundaries (I/O, external services) | Mock internal implementation details      |
| Use dependency injection for mockability    | Create mocks inline in production code    |
| Verify important interactions               | Over-verify every method call             |
| Keep mocks simple and focused               | Create complex mock behaviors             |
| Use fakes for complex dependencies          | Mock what you do not own without adapters |
| Reset mocks between tests                   | Share mock state across tests             |

---

## 4. Test Isolation Principles

### Isolation Checklist

Every unit test MUST be isolated from:

- [ ] **Database**: Use in-memory or mocked repository
- [ ] **File System**: Mock fs operations or use temp directories
- [ ] **Network**: Mock HTTP clients, never make real requests
- [ ] **Time**: Mock `Date.now()`, timers, and clocks
- [ ] **Random**: Seed random generators or mock
- [ ] **Environment Variables**: Reset after each test
- [ ] **Global State**: Restore singletons and static state
- [ ] **Other Tests**: No test ordering dependencies

### Isolation Patterns

```typescript
// 1. Database Isolation - Use repository pattern
interface UserRepository {
  save(user: User): Promise<User>;
  findById(id: string): Promise<User | null>;
}

// Production implementation
class PostgresUserRepository implements UserRepository {
  async save(user: User): Promise<User> {
    return await this.db.query("INSERT INTO users...");
  }
}

// Test implementation (fake)
class InMemoryUserRepository implements UserRepository {
  private users: Map<string, User> = new Map();

  async save(user: User): Promise<User> {
    const id = crypto.randomUUID();
    const saved = { ...user, id };
    this.users.set(id, saved);
    return saved;
  }

  async findById(id: string): Promise<User | null> {
    return this.users.get(id) || null;
  }
}

// 2. Time Isolation
describe("TokenService", () => {
  beforeEach(() => {
    jest.useFakeTimers();
    jest.setSystemTime(new Date("2026-01-21T12:00:00Z"));
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  it("should expire token after 1 hour", () => {
    const token = createToken({ userId: "123" });

    jest.advanceTimersByTime(60 * 60 * 1000 + 1); // 1 hour + 1ms

    expect(isTokenValid(token)).toBe(false);
  });
});

// 3. Environment Variable Isolation
describe("Config", () => {
  const originalEnv = process.env;

  beforeEach(() => {
    process.env = { ...originalEnv };
  });

  afterEach(() => {
    process.env = originalEnv;
  });

  it("should use custom API URL from environment", () => {
    process.env.API_URL = "https://custom.api.com";

    const config = loadConfig();

    expect(config.apiUrl).toBe("https://custom.api.com");
  });
});

// 4. Global State Isolation (Singleton reset)
describe("Logger", () => {
  afterEach(() => {
    Logger.resetInstance(); // Reset singleton between tests
  });

  it("should create new instance with custom config", () => {
    const logger = Logger.getInstance({ level: "debug" });
    expect(logger.level).toBe("debug");
  });
});
```

```python
# pytest isolation patterns

# 1. Fixture scoping for isolation
@pytest.fixture(scope='function')  # Fresh instance per test
def user_service():
    return UserService(InMemoryRepository())

@pytest.fixture(scope='module')  # Shared within module (use carefully)
def database_schema():
    return create_test_schema()

# 2. Automatic cleanup with yield fixtures
@pytest.fixture
def temp_file():
    path = Path('/tmp/test_file.txt')
    path.write_text('test content')
    yield path
    path.unlink(missing_ok=True)  # Cleanup after test

# 3. Environment isolation
@pytest.fixture
def clean_env(monkeypatch):
    monkeypatch.setenv('API_KEY', 'test-key')
    monkeypatch.delenv('PROD_SECRET', raising=False)
    yield
    # Automatic cleanup by monkeypatch

# 4. Database transaction isolation
@pytest.fixture
def db_session():
    session = create_session()
    session.begin_nested()  # Savepoint
    yield session
    session.rollback()  # Rollback after test
    session.close()

# 5. Time isolation
@pytest.fixture
def frozen_time():
    with freeze_time('2026-01-21 12:00:00'):
        yield
```

---

## 5. Test Naming Conventions

### Naming Patterns

| Pattern                                     | Example                                            | When to Use       |
| ------------------------------------------- | -------------------------------------------------- | ----------------- |
| `should_[expected]_when_[state]`            | `should_return_null_when_user_not_found`           | General behavior  |
| `[method]_[state]_[expected]`               | `createUser_withDuplicateEmail_throwsError`        | Method-focused    |
| `given_[state]_when_[action]_then_[result]` | `given_empty_cart_when_checkout_then_throws_error` | BDD style         |
| `test_[behavior]`                           | `test_validates_email_format`                      | Python convention |
| `Test[Type]_[Method]_[Scenario]`            | `TestUserService_CreateUser_WithValidData`         | Go convention     |

### Naming Guidelines

```typescript
// GOOD - Descriptive, reads like documentation
describe("PaymentService", () => {
  describe("processPayment", () => {
    it("should charge customer card when payment amount is valid", () => {});
    it("should throw InsufficientFundsError when balance is too low", () => {});
    it("should retry up to 3 times when gateway returns timeout", () => {});
    it("should send receipt email after successful payment", () => {});
  });
});

// BAD - Vague, unclear what's being tested
describe("PaymentService", () => {
  it("works", () => {});
  it("test 1", () => {});
  it("payment", () => {});
  it("should work correctly", () => {});
});
```

```python
# GOOD - Python naming
class TestPaymentService:
    def test_process_payment_charges_card_when_amount_valid(self):
        pass

    def test_process_payment_raises_insufficient_funds_when_balance_low(self):
        pass

    def test_process_payment_retries_three_times_on_gateway_timeout(self):
        pass

# BAD - Python naming
class TestPaymentService:
    def test_1(self):
        pass

    def test_payment(self):
        pass
```

```go
// GOOD - Go naming
func TestPaymentService_ProcessPayment_ChargesCardWhenAmountValid(t *testing.T) {}
func TestPaymentService_ProcessPayment_ReturnsErrorWhenBalanceLow(t *testing.T) {}
func TestPaymentService_ProcessPayment_RetriesOnTimeout(t *testing.T) {}

// BAD - Go naming
func TestPayment(t *testing.T) {}
func Test1(t *testing.T) {}
```

---

## 6. Parameterized Tests

### Jest Parameterized Tests

```typescript
// Using test.each with array
describe("EmailValidator", () => {
  test.each([
    ["user@example.com", true],
    ["user@subdomain.example.com", true],
    ["user+tag@example.com", true],
    ["invalid-email", false],
    ["missing@domain", false],
    ["@nodomain.com", false],
    ["", false],
  ])('validates email "%s" as %s', (email, expected) => {
    expect(isValidEmail(email)).toBe(expected);
  });
});

// Using test.each with object array (more readable)
describe("PriceCalculator", () => {
  test.each([
    { items: 1, price: 10, discount: 0, expected: 10 },
    { items: 2, price: 10, discount: 0, expected: 20 },
    { items: 5, price: 10, discount: 10, expected: 45 },
    { items: 10, price: 10, discount: 20, expected: 80 },
  ])(
    "calculates total for $items items at $$price with $discount% discount",
    ({ items, price, discount, expected }) => {
      const calculator = new PriceCalculator();
      expect(calculator.calculate(items, price, discount)).toBe(expected);
    },
  );
});

// Tagged template literal syntax
describe("StringUtils", () => {
  test.each`
    input       | expected
    ${"hello"}  | ${"HELLO"}
    ${"World"}  | ${"WORLD"}
    ${"123abc"} | ${"123ABC"}
    ${""}       | ${""}
  `('converts "$input" to uppercase as "$expected"', ({ input, expected }) => {
    expect(toUpperCase(input)).toBe(expected);
  });
});
```

### pytest Parameterized Tests

```python
import pytest

# Basic parametrize
@pytest.mark.parametrize("email,expected", [
    ("user@example.com", True),
    ("user@subdomain.example.com", True),
    ("invalid-email", False),
    ("", False),
])
def test_email_validation(email, expected):
    assert validate_email(email) == expected

# Multiple parameters with IDs
@pytest.mark.parametrize(
    "items,price,discount,expected",
    [
        pytest.param(1, 10, 0, 10, id="single_item_no_discount"),
        pytest.param(5, 10, 10, 45, id="multiple_items_10_percent_off"),
        pytest.param(10, 10, 20, 80, id="bulk_order_20_percent_off"),
    ]
)
def test_price_calculation(items, price, discount, expected):
    calculator = PriceCalculator()
    assert calculator.calculate(items, price, discount) == expected

# Cartesian product of parameters
@pytest.mark.parametrize("currency", ["USD", "EUR", "GBP"])
@pytest.mark.parametrize("amount", [100, 500, 1000])
def test_currency_conversion(currency, amount):
    result = convert_to_usd(amount, currency)
    assert result > 0

# Parametrize with fixtures
@pytest.fixture(params=["postgres", "mysql", "sqlite"])
def database(request):
    return create_test_database(request.param)

def test_database_operations(database):
    database.execute("SELECT 1")
    assert database.is_connected()

# Conditional skip in parametrize
@pytest.mark.parametrize("feature,expected", [
    pytest.param("feature_a", True, id="feature_a"),
    pytest.param("feature_b", True, marks=pytest.mark.skip(reason="Not implemented")),
    pytest.param("feature_c", True, marks=pytest.mark.xfail(reason="Known bug")),
])
def test_feature_flags(feature, expected):
    assert is_feature_enabled(feature) == expected
```

### Go Table-Driven Tests

```go
func TestEmailValidation(t *testing.T) {
    tests := []struct {
        name     string
        email    string
        expected bool
    }{
        {
            name:     "valid standard email",
            email:    "user@example.com",
            expected: true,
        },
        {
            name:     "valid subdomain email",
            email:    "user@sub.example.com",
            expected: true,
        },
        {
            name:     "invalid missing at symbol",
            email:    "userexample.com",
            expected: false,
        },
        {
            name:     "invalid empty string",
            email:    "",
            expected: false,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result := ValidateEmail(tt.email)
            if result != tt.expected {
                t.Errorf("ValidateEmail(%q) = %v, want %v",
                    tt.email, result, tt.expected)
            }
        })
    }
}

// Subtests with setup
func TestPriceCalculator(t *testing.T) {
    calculator := NewPriceCalculator()

    tests := map[string]struct {
        items    int
        price    float64
        discount float64
        want     float64
    }{
        "single item no discount": {
            items: 1, price: 10, discount: 0, want: 10,
        },
        "multiple items with discount": {
            items: 5, price: 10, discount: 10, want: 45,
        },
        "bulk order max discount": {
            items: 100, price: 10, discount: 25, want: 750,
        },
    }

    for name, tc := range tests {
        t.Run(name, func(t *testing.T) {
            got := calculator.Calculate(tc.items, tc.price, tc.discount)
            assert.InDelta(t, tc.want, got, 0.01)
        })
    }
}
```

---

## 7. Snapshot Testing

### Jest Snapshot Testing

```typescript
// 1. Basic snapshot
describe('UserCard', () => {
  it('renders correctly with user data', () => {
    const user = { id: '1', name: 'John Doe', email: 'john@example.com' };
    const tree = renderer.create(<UserCard user={user} />).toJSON();
    expect(tree).toMatchSnapshot();
  });
});

// 2. Inline snapshot (embedded in test file)
it('formats date correctly', () => {
  const formatted = formatDate(new Date('2026-01-21'));
  expect(formatted).toMatchInlineSnapshot(`"January 21, 2026"`);
});

// 3. Property matchers (for dynamic values)
it('creates user with generated ID', () => {
  const user = createUser({ name: 'Test' });
  expect(user).toMatchSnapshot({
    id: expect.any(String),
    createdAt: expect.any(Date),
  });
});

// 4. Snapshot serializers (custom formatting)
expect.addSnapshotSerializer({
  test: (val) => val && val.hasOwnProperty('_timestamp'),
  serialize: (val) => `Timestamp(${val._timestamp})`,
});

// 5. Updating snapshots
// Run: jest --updateSnapshot or jest -u
```

### pytest Snapshot Testing (with pytest-snapshot)

```python
# Install: pip install pytest-snapshot

def test_user_serialization(snapshot):
    user = User(id="123", name="John Doe", email="john@example.com")
    result = user.to_dict()
    snapshot.assert_match(result, "user_dict")

def test_api_response(snapshot):
    response = api_client.get("/users/123")
    snapshot.assert_match(response.json(), "user_response")

# Using syrupy (modern alternative)
def test_with_syrupy(snapshot):
    result = generate_report()
    assert result == snapshot
```

### Snapshot Best Practices

| Do                                       | Do Not                                    |
| ---------------------------------------- | ----------------------------------------- |
| Use for UI components, serialized output | Use for simple values (prefer assertions) |
| Review snapshot changes in code review   | Auto-update without reviewing changes     |
| Keep snapshots small and focused         | Snapshot entire page or large objects     |
| Use property matchers for dynamic values | Include timestamps, IDs in snapshots      |
| Organize snapshots near test files       | Have one giant snapshot file              |

---

## 8. Coverage Requirements

### Coverage Targets

| Metric             | Minimum | Target | Critical Paths |
| ------------------ | ------- | ------ | -------------- |
| Line Coverage      | 70%     | 80%    | 100%           |
| Branch Coverage    | 65%     | 75%    | 100%           |
| Function Coverage  | 75%     | 85%    | 100%           |
| Statement Coverage | 70%     | 80%    | 100%           |

### Jest Coverage Configuration

```javascript
// jest.config.js
module.exports = {
  collectCoverage: true,
  coverageDirectory: "coverage",
  coverageReporters: ["text", "lcov", "html"],
  collectCoverageFrom: [
    "src/**/*.{ts,tsx}",
    "!src/**/*.d.ts",
    "!src/**/*.test.{ts,tsx}",
    "!src/**/*.stories.{ts,tsx}",
    "!src/**/index.ts",
  ],
  coverageThreshold: {
    global: {
      branches: 75,
      functions: 80,
      lines: 80,
      statements: 80,
    },
    // Per-file thresholds for critical modules
    "./src/auth/**/*.ts": {
      branches: 90,
      functions: 95,
      lines: 95,
      statements: 95,
    },
    "./src/payment/**/*.ts": {
      branches: 95,
      functions: 100,
      lines: 95,
      statements: 95,
    },
  },
};
```

### pytest Coverage Configuration

```ini
# pytest.ini or pyproject.toml
[tool.pytest.ini_options]
addopts = "--cov=src --cov-report=term-missing --cov-report=html --cov-fail-under=80"

[tool.coverage.run]
source = ["src"]
omit = [
    "*/tests/*",
    "*/__init__.py",
    "*/migrations/*",
]
branch = true

[tool.coverage.report]
exclude_lines = [
    "pragma: no cover",
    "def __repr__",
    "raise NotImplementedError",
    "if TYPE_CHECKING:",
    "if __name__ == .__main__.:",
]
fail_under = 80
show_missing = true
```

### Go Coverage Configuration

```bash
# Generate coverage
go test -coverprofile=coverage.out ./...

# View coverage report
go tool cover -html=coverage.out

# Check coverage threshold
go test -coverprofile=coverage.out ./... && \
  go tool cover -func=coverage.out | grep total | awk '{print $3}' | \
  sed 's/%//' | awk '{if ($1 < 80) exit 1}'
```

### Coverage Analysis Commands

```bash
# Jest
npm test -- --coverage --coverageReporters=text-summary
npm test -- --coverage --changedSince=main  # Only changed files

# pytest
pytest --cov=src --cov-report=term-missing
pytest --cov=src --cov-report=html  # HTML report at htmlcov/

# Go
go test -cover ./...
go test -coverprofile=coverage.out -covermode=atomic ./...

# View uncovered lines
npm test -- --coverage --collectCoverageFrom='src/auth/**/*.ts'
pytest --cov=src/auth --cov-report=term-missing
```

---

## 9. Framework-Specific Patterns

### Jest/Vitest (TypeScript/JavaScript)

```typescript
// Setup and teardown
beforeAll(async () => {
  await setupTestDatabase();
});

afterAll(async () => {
  await teardownTestDatabase();
});

beforeEach(() => {
  jest.clearAllMocks();
});

// Async testing
it("should fetch user data", async () => {
  const user = await userService.getUser("123");
  expect(user).toBeDefined();
});

// Testing promises
it("should reject with error", async () => {
  await expect(failingOperation()).rejects.toThrow("Expected error");
});

// Testing callbacks
it("should call callback with result", (done) => {
  asyncFunction((err, result) => {
    expect(err).toBeNull();
    expect(result).toBe("expected");
    done();
  });
});

// Custom matchers
expect.extend({
  toBeValidEmail(received) {
    const pass = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(received);
    return {
      message: () => `expected ${received} to be a valid email`,
      pass,
    };
  },
});

expect("user@example.com").toBeValidEmail();

// Testing errors
it("should throw specific error", () => {
  expect(() => validateInput(null)).toThrow(ValidationError);
  expect(() => validateInput(null)).toThrow("Input cannot be null");
});
```

### pytest (Python)

```python
import pytest
from unittest.mock import Mock, patch, AsyncMock

# Fixtures
@pytest.fixture
def user_service():
    return UserService(repository=InMemoryRepository())

@pytest.fixture(autouse=True)
def reset_singleton():
    """Reset singleton before each test"""
    yield
    Singleton._instance = None

# Async testing
@pytest.mark.asyncio
async def test_async_operation():
    result = await async_fetch_data()
    assert result is not None

# Exception testing
def test_raises_validation_error():
    with pytest.raises(ValidationError) as exc_info:
        validate_input(None)
    assert "cannot be null" in str(exc_info.value)

def test_raises_with_match():
    with pytest.raises(ValueError, match=r"invalid .* format"):
        parse_date("not-a-date")

# Marks
@pytest.mark.slow
def test_slow_operation():
    pass

@pytest.mark.skip(reason="Not implemented yet")
def test_future_feature():
    pass

@pytest.mark.xfail(reason="Known bug #123")
def test_known_failure():
    pass

@pytest.mark.skipif(sys.platform == "win32", reason="Unix only")
def test_unix_feature():
    pass

# Caplog for logging
def test_logs_warning(caplog):
    with caplog.at_level(logging.WARNING):
        trigger_warning()
    assert "Expected warning" in caplog.text

# Capsys for stdout/stderr
def test_prints_message(capsys):
    print_welcome()
    captured = capsys.readouterr()
    assert "Welcome" in captured.out

# Tmp_path for file operations
def test_file_creation(tmp_path):
    file = tmp_path / "test.txt"
    file.write_text("content")
    assert file.read_text() == "content"
```

### Go testing

```go
package service_test

import (
    "testing"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
    "github.com/stretchr/testify/suite"
)

// Basic test
func TestAdd(t *testing.T) {
    result := Add(2, 3)
    if result != 5 {
        t.Errorf("Add(2, 3) = %d; want 5", result)
    }
}

// With testify assertions
func TestAddWithAssert(t *testing.T) {
    result := Add(2, 3)
    assert.Equal(t, 5, result)
    assert.NotNil(t, result)
}

// Require (stops on failure)
func TestWithRequire(t *testing.T) {
    user, err := GetUser("123")
    require.NoError(t, err)       // Test stops here if error
    require.NotNil(t, user)
    assert.Equal(t, "123", user.ID)
}

// Test suite
type UserServiceTestSuite struct {
    suite.Suite
    service *UserService
    mockRepo *MockRepository
}

func (s *UserServiceTestSuite) SetupTest() {
    s.mockRepo = NewMockRepository(s.T())
    s.service = NewUserService(s.mockRepo)
}

func (s *UserServiceTestSuite) TestCreateUser() {
    s.mockRepo.On("Save", mock.Anything).Return(&User{ID: "123"}, nil)

    user, err := s.service.CreateUser(&UserInput{Name: "Test"})

    s.NoError(err)
    s.Equal("123", user.ID)
}

func TestUserServiceSuite(t *testing.T) {
    suite.Run(t, new(UserServiceTestSuite))
}

// Parallel tests
func TestParallel(t *testing.T) {
    t.Parallel()
    // This test runs in parallel with other parallel tests
}

// Subtests
func TestUserValidation(t *testing.T) {
    t.Run("valid user", func(t *testing.T) {
        assert.True(t, IsValid(validUser))
    })

    t.Run("invalid email", func(t *testing.T) {
        assert.False(t, IsValid(invalidEmailUser))
    })
}

// Benchmarks
func BenchmarkHeavyOperation(b *testing.B) {
    for i := 0; i < b.N; i++ {
        HeavyOperation()
    }
}

// Test helpers
func newTestUser(t *testing.T) *User {
    t.Helper() // Marks this as helper (better stack traces)
    return &User{ID: "test-" + t.Name()}
}
```

---

## 10. CI Integration

### GitHub Actions Configuration

```yaml
# .github/workflows/test.yml
name: Unit Tests

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test-typescript:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"

      - name: Install dependencies
        run: npm ci

      - name: Run unit tests
        run: npm test -- --coverage --ci --reporters=default --reporters=jest-junit
        env:
          JEST_JUNIT_OUTPUT_DIR: ./reports

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/lcov.info
          fail_ci_if_error: true

      - name: Check coverage threshold
        run: |
          COVERAGE=$(cat coverage/coverage-summary.json | jq '.total.lines.pct')
          if (( $(echo "$COVERAGE < 80" | bc -l) )); then
            echo "Coverage $COVERAGE% is below threshold 80%"
            exit 1
          fi

  test-python:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"
          cache: "pip"

      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install pytest pytest-cov pytest-xdist

      - name: Run tests with coverage
        run: |
          pytest tests/ \
            --cov=src \
            --cov-report=xml \
            --cov-report=term-missing \
            --cov-fail-under=80 \
            -n auto \
            --junitxml=reports/junit.xml

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage.xml

  test-go:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Go
        uses: actions/setup-go@v5
        with:
          go-version: "1.22"

      - name: Run tests
        run: |
          go test -v -race -coverprofile=coverage.out -covermode=atomic ./...
          go tool cover -func=coverage.out

      - name: Check coverage
        run: |
          COVERAGE=$(go tool cover -func=coverage.out | grep total | awk '{print $3}' | sed 's/%//')
          if (( $(echo "$COVERAGE < 80" | bc -l) )); then
            echo "Coverage $COVERAGE% is below threshold"
            exit 1
          fi
```

### Pre-commit Hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: jest-unit-tests
        name: Jest Unit Tests
        entry: npm test -- --bail --findRelatedTests
        language: system
        files: \.(ts|tsx)$
        pass_filenames: true

      - id: pytest-unit-tests
        name: Pytest Unit Tests
        entry: pytest --tb=short -q
        language: system
        files: \.py$
        pass_filenames: false

      - id: go-tests
        name: Go Tests
        entry: go test -short ./...
        language: system
        files: \.go$
        pass_filenames: false
```

### Coverage Badge Configuration

```yaml
# In CI workflow, generate badge
- name: Generate coverage badge
  uses: jaywcjlove/coverage-badges-cli@main
  with:
    source: coverage/coverage-summary.json
    output: coverage/badge.svg
# Or use shields.io dynamic badge
# https://img.shields.io/codecov/c/github/owner/repo
```

---

## 11. Anti-Patterns to Avoid

### Common Unit Test Anti-Patterns

| Anti-Pattern               | Problem                           | Solution                          |
| -------------------------- | --------------------------------- | --------------------------------- |
| **Test Interdependence**   | Tests depend on execution order   | Make each test self-contained     |
| **Excessive Setup**        | 50+ lines of setup code           | Use factories, builders, fixtures |
| **Logic in Tests**         | Conditionals, loops in test code  | One code path per test            |
| **Testing Implementation** | Verifying private methods         | Test public behavior only         |
| **Commented Tests**        | Tests commented out "temporarily" | Delete or fix immediately         |
| **Magic Numbers**          | `expect(result).toBe(42)`         | Use named constants               |
| **Global State Mutation**  | Tests modify shared state         | Reset state in setup/teardown     |
| **Slow Unit Tests**        | Tests > 100ms                     | Mock I/O, use fakes               |
| **Test Duplication**       | Copy-paste test code              | Use parameterized tests           |
| **Assertion-free Tests**   | Tests with no assertions          | Every test needs assertions       |

### Code Examples of Anti-Patterns

```typescript
// BAD: Testing implementation details
it("should call internal _validateInput method", () => {
  const spy = jest.spyOn(service, "_validateInput");
  service.createUser(data);
  expect(spy).toHaveBeenCalled(); // Testing private method
});

// GOOD: Test behavior
it("should reject invalid email format", async () => {
  await expect(service.createUser({ email: "invalid" })).rejects.toThrow(
    "Invalid email",
  );
});

// BAD: Logic in tests
it("should calculate correctly", () => {
  for (const input of inputs) {
    // Loop in test
    if (input > 0) {
      // Conditional in test
      expect(calculate(input)).toBeGreaterThan(0);
    }
  }
});

// GOOD: Parameterized test
test.each([
  [1, 10],
  [5, 50],
  [10, 100],
])("calculate(%d) returns %d", (input, expected) => {
  expect(calculate(input)).toBe(expected);
});

// BAD: Magic numbers
it("should calculate total", () => {
  expect(cart.total).toBe(156.78); // Where does this come from?
});

// GOOD: Clear values
it("should calculate total as sum of item prices", () => {
  const item1Price = 100.0;
  const item2Price = 56.78;
  const expectedTotal = item1Price + item2Price;

  cart.addItem({ price: item1Price });
  cart.addItem({ price: item2Price });

  expect(cart.total).toBe(expectedTotal);
});
```

---

## 12. Invoke Agent

```
Use the Task tool with subagent_type="unit-test-expert" to:

1. Write comprehensive unit tests for modules
2. Create mocks and stubs for dependencies
3. Achieve test isolation from external systems
4. Follow TDD red-green-refactor cycle
5. Improve code coverage to 80%+ target
6. Set up parameterized tests for edge cases
7. Configure snapshot testing for UI components
8. Integrate tests with CI/CD pipelines
9. Review and improve existing test quality
10. Generate test data factories and builders

Task: $ARGUMENTS
```

---

## Quick Reference

### Commands by Framework

```bash
# Jest
npm test                          # Run all tests
npm test -- --watch               # Watch mode
npm test -- --coverage            # With coverage
npm test -- --testPathPattern=auth # Filter by path
npm test -- -u                    # Update snapshots

# pytest
pytest                            # Run all tests
pytest -v                         # Verbose
pytest --cov=src                  # With coverage
pytest -k "test_auth"             # Filter by name
pytest -x                         # Stop on first failure
pytest --lf                       # Run last failed

# Go
go test ./...                     # Run all tests
go test -v ./...                  # Verbose
go test -cover ./...              # With coverage
go test -run TestAuth ./...       # Filter by name
go test -race ./...               # Race detection
```

### Coverage Thresholds Summary

| Code Type       | Minimum | Target | Critical |
| --------------- | ------- | ------ | -------- |
| Business Logic  | 80%     | 90%    | 95%      |
| Data Access     | 70%     | 80%    | 85%      |
| Controllers/API | 70%     | 80%    | 85%      |
| Utilities       | 85%     | 95%    | 100%     |
| Security Code   | 95%     | 100%   | 100%     |

### Example

```
/agents/testing/unit-test-expert write unit tests for UserService with 90% coverage, including edge cases for email validation, password strength, and duplicate user handling
```

---

## Related Agents

- `/agents/testing/tdd-coach` - Test-driven development guidance
- `/agents/testing/test-architect` - Test strategy and pyramid design
- `/agents/testing/integration-test-expert` - Service integration testing
- `/agents/testing/e2e-test-expert` - End-to-end testing
- `/agents/testing/test-data-expert` - Test data generation
- `/agents/quality/code-reviewer` - Code review including test quality
