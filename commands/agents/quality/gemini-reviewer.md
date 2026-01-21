# Gemini Reviewer Agent

Gemini-powered code reviewer using CLI. Expert in security analysis, code quality validation, and design review.

## Arguments

- `$ARGUMENTS` - Code to review

## Invoke Agent

```
Use the Task tool with subagent_type="gemini-reviewer" to:

1. Security analysis
2. Code quality validation
3. Design pattern review
4. Large codebase review (1M context)
5. Part of tri-agent consensus

Task: $ARGUMENTS
```

## CLI Usage

```bash
# IMPORTANT: Always use canonical form with explicit model!
gemini -m gemini-3-pro-preview "Review this code for security issues"
gemini -m gemini-3-pro-preview "Analyze architecture"
gemini -m gemini-3-pro-preview --approval-mode yolo "Quick code review"  # Auto-approve for read-only
```

## Example

```
/agents/quality/gemini-reviewer security review authentication module
```
