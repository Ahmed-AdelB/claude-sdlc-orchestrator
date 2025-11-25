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
# IMPORTANT: Use positional prompt, NOT -p flag!
gemini "Review this code for security issues"
gemini -m gemini-2.5-pro "Analyze architecture"
gemini -y "Quick code review"  # Auto-approve mode
```

## Example
```
/agents/quality/gemini-reviewer security review authentication module
```
