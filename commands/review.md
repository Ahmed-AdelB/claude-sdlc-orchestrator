# Code Review

Perform comprehensive code review on the specified files or PR.

## Instructions

1. **Scope Identification**
   - Identify files to review
   - Or fetch PR diff if PR number provided

2. **Review Categories**

   ### Functionality
   - [ ] Code does what it should
   - [ ] Edge cases handled
   - [ ] Error handling appropriate

   ### Code Quality
   - [ ] Clear naming
   - [ ] Single responsibility
   - [ ] DRY principle
   - [ ] Appropriate abstractions

   ### Security
   - [ ] No hardcoded secrets
   - [ ] Input validation
   - [ ] SQL injection prevention
   - [ ] XSS prevention

   ### Performance
   - [ ] No N+1 queries
   - [ ] Efficient algorithms
   - [ ] Appropriate caching

   ### Testing
   - [ ] Adequate test coverage
   - [ ] Tests are meaningful
   - [ ] Edge cases tested

3. **Output Format**
   ```markdown
   ## Code Review Summary

   **Overall**: APPROVE | REQUEST_CHANGES | COMMENT

   ### Issues Found
   | Severity | File | Line | Issue | Suggestion |
   |----------|------|------|-------|------------|
   | 🔴 Critical | | | | |
   | 🟠 Major | | | | |
   | 🟡 Minor | | | | |

   ### Positive Notes
   - [Good practice observed]

   ### Suggestions
   - [Improvement idea]
   ```
