# /test-gen

Generate tests with framework auto-detection, edge cases, integration templates, mocking/fixtures, and coverage gap analysis.

## Usage
```
/test-gen [target] [--unit|--integration|--both] [--framework <name>] [--language <lang>] [--files <globs>] [--focus <area>] [--dry-run]
```

## Arguments
- `target` (optional): File, folder, module, or symbol to test. Default: current working directory.

## Options
- `--unit`: Generate unit tests only.
- `--integration`: Generate integration test templates only.
- `--both`: Generate unit tests plus integration templates (default).
- `--framework <name>`: Force a framework. One of `pytest`, `jest`, `vitest`, `mocha`.
- `--language <lang>`: Force language. One of `python`, `ts`, `js`.
- `--files <globs>`: Comma-separated globs to include.
- `--focus <area>`: Narrow to `api`, `data`, `utils`, `ui`, `hooks`, or `services`.
- `--dry-run`: Show planned files without writing.

## Auto-detect Framework
If `--framework` is not provided, detect by scanning project files:

### Python
- `pyproject.toml` with `[tool.pytest]`
- `pytest.ini`, `tox.ini`, `setup.cfg` with pytest settings
- `requirements.txt` or `poetry.lock` containing `pytest`

### JavaScript/TypeScript
- `package.json` devDependencies or dependencies:
  - `jest` or `@jest/core`
  - `vitest`
  - `mocha`
- Config files:
  - `jest.config.*`, `vitest.config.*`
  - `.mocharc.*`, `mocha.opts`

### Tie-breaker
If multiple frameworks are found:
1) Prefer config file presence.
2) Prefer `vitest` for Vite projects, `jest` for React/Next, `mocha` for Node libs.
3) Otherwise, ask the user to choose.

## Process Steps
1. Parse args and decide scope (target, files, focus).
2. Detect language and test framework (or honor overrides).
3. Inspect target exports, public APIs, and existing tests.
4. Build a test matrix with normal cases, edge cases, and error paths.
5. Generate unit tests with clear arrange/act/assert structure.
6. Add mocks and fixtures for IO, time, random, network, DB, and external services.
7. Create integration test templates for module boundaries or API surfaces.
8. Produce a coverage gap analysis against public APIs and branches.
9. Summarize created files and key assumptions.

## Coverage Gap Analysis
Perform a lightweight static analysis:
- Enumerate exported functions/classes/modules in the target.
- Map existing tests to these exports by name and usage.
- Flag missing coverage for:
  - error branches
  - boundary conditions
  - optional or null inputs
  - environment-specific behavior
Provide a short list of uncovered areas and recommended tests.

## Mocking and Fixture Setup
### Python (pytest)
- Use fixtures for shared setup and teardown.
- Use `monkeypatch` for environment, time, random, and external APIs.
- Prefer `pytest-mock` or `unittest.mock` for call assertions.

### JavaScript/TypeScript
- Jest/Vitest: `vi.mock` or `jest.mock` for module mocks.
- Mocha: use `sinon` for spies/stubs/mocks.
- Use fake timers for time-based logic.

## Templates

### Python: pytest unit test
```python
import pytest

from <module> import <symbol>


def test_<symbol>_normal_case():
    # Arrange
    input_value = <value>

    # Act
    result = <symbol>(input_value)

    # Assert
    assert result == <expected>


def test_<symbol>_edge_case_empty():
    input_value = <empty_value>
    result = <symbol>(input_value)
    assert result == <expected>


def test_<symbol>_invalid_input_raises():
    with pytest.raises(<ExceptionType>):
        <symbol>(<invalid_value>)
```

### Python: pytest integration template
```python
import pytest


def test_<feature>_integration(<fixture>):
    # Arrange
    # Use fixtures to set up dependencies and data

    # Act
    result = <call_feature_under_test>()

    # Assert
    assert result == <expected>
```

### TypeScript/JavaScript: Jest/Vitest unit test
```ts
import { describe, it, expect, vi } from "vitest";
import { <symbol> } from "<module>";

describe("<symbol>", () => {
  it("handles normal case", () => {
    const inputValue = <value>;
    const result = <symbol>(inputValue);
    expect(result).toEqual(<expected>);
  });

  it("handles edge case", () => {
    const inputValue = <edge_value>;
    const result = <symbol>(inputValue);
    expect(result).toEqual(<expected>);
  });

  it("throws on invalid input", () => {
    expect(() => <symbol>(<invalid_value>)).toThrow();
  });
});
```

### JavaScript: Mocha + Chai unit test
```js
const { expect } = require("chai");
const { <symbol> } = require("<module>");

describe("<symbol>", () => {
  it("handles normal case", () => {
    const inputValue = <value>;
    const result = <symbol>(inputValue);
    expect(result).to.equal(<expected>);
  });

  it("handles edge case", () => {
    const inputValue = <edge_value>;
    const result = <symbol>(inputValue);
    expect(result).to.equal(<expected>);
  });

  it("throws on invalid input", () => {
    expect(() => <symbol>(<invalid_value>)).to.throw();
  });
});
```

### Integration Test Template (Node)
```ts
import { describe, it, expect } from "vitest";
import { createApp } from "<app_module>";

describe("<feature> integration", () => {
  it("processes request end-to-end", async () => {
    const app = createApp();
    const response = await app.inject({ method: "GET", url: "<path>" });
    expect(response.statusCode).toBe(200);
  });
});
```

## Output
- Create or update test files under the project test conventions.
- Report new files, changes, and the coverage gap summary.
- If `--dry-run` is set, only list planned actions.

## Notes
- Do not modify production code unless required for testability.
- If detection is ambiguous, ask the user which framework to use.
