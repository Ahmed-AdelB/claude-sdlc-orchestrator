# /split

Split a monolithic file into cohesive modules while preserving behavior, compatibility, and imports.

## Arguments

$ARGUMENTS: Path to the file to split (relative or absolute).

## When to Use

- Files that mix multiple responsibilities (UI + data fetching, business logic + persistence, etc.).
- Files with repeated patterns that deserve reuse.
- Files with high cognitive load or frequent merge conflicts.

## Safety Checks (Before Splitting)

- Confirm file exists and is readable.
- Check for generated files or vendor code; do not split those.
- Look for implicit side effects or top-level initialization order.
- Identify external references, dynamic imports, and reflective access (e.g., getattr, eval).
- Note circular dependency risk: avoid creating module cycles.
- Ensure tests exist or propose adding a minimal test scaffold.

## Analysis Process

1. **Inventory Symbols**
   - List exported/public items: classes, functions, constants.
   - Identify internal helpers and their call graph.
   - Mark side-effectful code and module-level state.

2. **Find Cohesive Clusters**
   - Group by responsibility (e.g., parsing, I/O, validation, rendering).
   - Group by domain model (e.g., User, Order, Payment).
   - Group by layer (UI, service, data access).

3. **Define Split Points**
   - Each module should own a single responsibility.
   - Prefer stable, testable seams (pure functions, interfaces).
   - Keep shared types in a dedicated types module.

4. **Plan Exports and Backward Compatibility**
   - Maintain existing import paths where possible via barrel exports.
   - Provide re-exports in the original file (or an index) to avoid breaking callers.

5. **Update Dependents**
   - Refactor imports in dependent files to new module paths.
   - Keep public API surface unchanged unless explicitly requested.

## Output Structure

- New modules in the same directory (or a new folder if needed).
- `index` barrel that re-exports public symbols.
- Original file becomes a compatibility layer if required.

## Templates

### Python Split Template

```python
# original_file.py (compatibility layer)
from .core import CoreClass, core_function
from .io import load_data, save_data
from .types import DataModel

__all__ = [
    "CoreClass",
    "core_function",
    "load_data",
    "save_data",
    "DataModel",
]
```

```python
# core.py
from .types import DataModel

class CoreClass:
    def __init__(self, model: DataModel) -> None:
        self.model = model

def core_function(value: int) -> int:
    return value * 2
```

```python
# io.py
from .types import DataModel

def load_data(path: str) -> DataModel:
    # TODO: implement
    raise NotImplementedError

def save_data(path: str, model: DataModel) -> None:
    # TODO: implement
    raise NotImplementedError
```

```python
# types.py
from dataclasses import dataclass

@dataclass(frozen=True)
class DataModel:
    id: str
    value: int
```

### TypeScript Split Template

```ts
// index.ts (barrel)
export { CoreClass, coreFunction } from "./core";
export { loadData, saveData } from "./io";
export type { DataModel } from "./types";
```

```ts
// originalFile.ts (compatibility layer)
export { CoreClass, coreFunction, loadData, saveData } from "./index";
export type { DataModel } from "./types";
```

```ts
// core.ts
import type { DataModel } from "./types";

export class CoreClass {
  constructor(private readonly model: DataModel) {}
}

export const coreFunction = (value: number): number => value * 2;
```

```ts
// io.ts
import type { DataModel } from "./types";

export const loadData = async (path: string): Promise<DataModel> => {
  throw new Error("Not implemented");
};

export const saveData = async (path: string, model: DataModel): Promise<void> => {
  void path;
  void model;
};
```

```ts
// types.ts
export interface DataModel {
  id: string;
  value: number;
}
```

## Steps to Execute

1. Read `$ARGUMENTS` file and list all public symbols.
2. Propose split modules and the rationale for each.
3. Extract code into new files, preserving behavior.
4. Add barrel `index` and compatibility re-exports.
5. Update imports in dependent files.
6. Run tests or propose validation steps.

## Notes

- Avoid moving code that depends on runtime side effects unless order is preserved.
- Minimize churn: keep names stable and avoid unnecessary refactors.
- If the file is a module entrypoint, keep it as a re-export layer.
