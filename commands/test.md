# Generate Tests

Generate comprehensive tests for specified code.

## Instructions

1. **Analyze Target Code**
   - Identify functions/classes to test
   - Understand dependencies
   - Identify edge cases

2. **Test Generation Strategy**
   - Unit tests for pure functions
   - Integration tests for services
   - Mock external dependencies

3. **Test Template (TypeScript/Jest)**
   ```typescript
   import { describe, it, expect, beforeEach, vi } from 'vitest';
   import { TargetFunction } from './target';

   describe('TargetFunction', () => {
     beforeEach(() => {
       vi.clearAllMocks();
     });

     describe('happy path', () => {
       it('should [expected behavior]', () => {
         // Arrange
         const input = {};

         // Act
         const result = TargetFunction(input);

         // Assert
         expect(result).toEqual({});
       });
     });

     describe('edge cases', () => {
       it('should handle empty input', () => {});
       it('should handle null values', () => {});
     });

     describe('error handling', () => {
       it('should throw on invalid input', () => {
         expect(() => TargetFunction(null)).toThrow();
       });
     });
   });
   ```

4. **Test Template (Python/pytest)**
   ```python
   import pytest
   from target import target_function

   class TestTargetFunction:
       def test_happy_path(self):
           result = target_function(input_data)
           assert result == expected

       def test_edge_case_empty(self):
           result = target_function([])
           assert result == []

       def test_raises_on_invalid(self):
           with pytest.raises(ValueError):
               target_function(None)
   ```

5. **Run Tests**
   ```bash
   npm test  # or pytest
   ```
