# Debug Issue

Systematically debug and fix the described issue.

## Instructions

1. **Understand the Problem**
   - Reproduce the issue
   - Identify expected vs actual behavior
   - Collect error messages/stack traces

2. **Investigation Steps**
   - Locate relevant code
   - Add logging if needed
   - Check recent changes (git log)
   - Review related tests

3. **Root Cause Analysis**
   ```markdown
   ## Debug Report

   ### Issue
   [Description]

   ### Steps to Reproduce
   1. [Step 1]
   2. [Step 2]

   ### Expected Behavior
   [What should happen]

   ### Actual Behavior
   [What happens]

   ### Root Cause
   [Identified cause]

   ### Solution
   [Proposed fix]
   ```

4. **Fix Implementation**
   - Make minimal changes
   - Add regression test
   - Verify fix works
   - Check for side effects

5. **Commit Format**
   ```
   fix: [Brief description of fix]

   Root cause: [What caused the bug]
   Solution: [How it was fixed]

   Fixes #[issue-number]

   🤖 Generated with Claude Code
   ```
