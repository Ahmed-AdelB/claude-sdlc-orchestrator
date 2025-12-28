# Sample Task: Fix Login Form Validation

## Issue Description
Users report that the login form accepts empty submissions and doesn't show
proper error messages for invalid inputs.

## Steps to Reproduce
1. Navigate to /login
2. Leave email and password fields empty
3. Click "Sign In"
4. Form submits without validation

## Expected Behavior
- Email field should show "Email is required" if empty
- Email field should show "Invalid email format" for invalid emails
- Password field should show "Password is required" if empty
- Password field should show "Password must be at least 8 characters"
- Form should not submit until all validations pass
- Error messages should clear when user starts typing

## Technical Investigation
Check these files:
- `src/components/auth/LoginForm.tsx`
- `src/hooks/useLoginForm.ts`
- `src/lib/validations/auth.ts`

## Solution Requirements
1. Add Zod schema for login validation
2. Integrate with react-hook-form
3. Display inline error messages
4. Disable submit button while form is invalid
5. Add unit tests for validation logic

## Acceptance Criteria
- [ ] Empty form cannot be submitted
- [ ] Invalid email shows appropriate error
- [ ] Short password shows appropriate error
- [ ] Errors clear on input change
- [ ] All existing tests still pass
- [ ] New validation tests added
