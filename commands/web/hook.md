---
name: web:hook
description: Generate production-ready React custom hooks with TypeScript typing, state management, and tests.
version: 1.0.0
tools:
  - Read
  - Write
  - Bash
---

# Custom Hook Generator Skill

## Description
Generates production-ready React custom hooks with TypeScript, proper typing, state management, and tests.

## Tri-Agent Integration
- Claude: Define hook responsibilities, boundaries, and API shape.
- Codex: Implement the hook, typing, and tests.
- Gemini: Review for correctness, edge cases, and performance pitfalls.

## Instructions

### 1. Analyze Hook Requirements
- Identify the core functionality (what state/logic needs to be reused).
- Determine inputs (parameters) and outputs (return values).
- Identify dependencies (other hooks, services, context).

### 2. Generate TypeScript Hook
- Use the `use` prefix for the hook name (e.g., `useFetchData`).
- Create a file named accordingly (e.g., `useFetchData.ts`).
- Define the function signature clearly.

### 3. Add Proper Typing
- Define interfaces for Props/Arguments.
- Define interfaces for the Return Value.
- Use Generics if the hook needs to handle flexible data types.
- Avoid `any`.

### 4. Handle Loading/Error States
- Include `isLoading`, `error`, and `data` (or similar) in the return object if async.
- Use strictly typed error handling.

### 5. Add Memoization
- Use `useCallback` for returned functions to prevent unnecessary re-renders in consumers.
- Use `useMemo` for derived state/calculations.

### 6. Generate Tests
- Use `@testing-library/react-hooks` (or `@testing-library/react` in newer versions).
- Test initial state.
- Test state changes/updates.
- Test error handling.
- Test unmounting/cleanup.

## Error Handling
- Normalize thrown values to `Error` and expose a typed error in the return object.
- Guard against stale updates on unmounted components.
- For async hooks, expose explicit `isLoading`/`isError` states and avoid swallowing errors.
- Validate required inputs early and fail fast with clear error messages.

## Templates and Examples

### Example
`@hook useDebouncedValue "Debounce a changing value with delay and cancel support"`

### Async Data Hook Template
```typescript
import { useState, useEffect, useCallback } from 'react';

interface UseAsyncOptions<T> {
  onSuccess?: (data: T) => void;
  onError?: (error: Error) => void;
  immediate?: boolean;
}

interface UseAsyncReturn<T> {
  execute: () => Promise<void>;
  data: T | null;
  isLoading: boolean;
  error: Error | null;
}

export const useAsync = <T>(
  asyncFunction: () => Promise<T>,
  options: UseAsyncOptions<T> = {}
): UseAsyncReturn<T> => {
  const { onSuccess, onError, immediate = true } = options;
  const [data, setData] = useState<T | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(immediate);
  const [error, setError] = useState<Error | null>(null);

  const execute = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const result = await asyncFunction();
      setData(result);
      onSuccess?.(result);
    } catch (err) {
      const errorObj = err instanceof Error ? err : new Error(String(err));
      setError(errorObj);
      onError?.(errorObj);
    } finally {
      setIsLoading(false);
    }
  }, [asyncFunction, onSuccess, onError]);

  useEffect(() => {
    if (immediate) {
      execute();
    }
  }, [execute, immediate]);

  return { execute, data, isLoading, error };
};
```

### Event Listener Hook Template
```typescript
import { useEffect, useRef } from 'react';

export const useEventListener = <K extends keyof WindowEventMap>(
  eventName: K,
  handler: (event: WindowEventMap[K]) => void,
  element: HTMLElement | Window = window
): void => {
  const savedHandler = useRef<(event: WindowEventMap[K]) => void>();

  useEffect(() => {
    savedHandler.current = handler;
  }, [handler]);

  useEffect(() => {
    const eventListener = (event: WindowEventMap[K]) => savedHandler.current?.(event);
    element.addEventListener(eventName, eventListener as EventListener);
    return () => {
      element.removeEventListener(eventName, eventListener as EventListener);
    };
  }, [eventName, element]);
};
```

## Best Practices
- **Single Responsibility:** A hook should do one thing well.
- **SSR Compatibility:** Check for `window` or `document` availability if using browser APIs.
- **Composition:** Compose smaller hooks into larger ones if complex logic is needed.
- **Debug Value:** Use `useDebugValue` for library hooks to provide labels in React DevTools.
- **Cleanup:** Always return a cleanup function in `useEffect` when setting up listeners, subscriptions, or timers.
