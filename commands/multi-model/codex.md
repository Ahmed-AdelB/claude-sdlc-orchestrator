# Codex CLI

Execute a task using OpenAI's Codex CLI for rapid prototyping and alternative implementations.

## Arguments
- `$ARGUMENTS` - Task description or code to execute

## Process

### Step 1: Prepare Context
Gather relevant context for Codex:
- Current file contents
- Project structure
- Related code files
- Requirements from user

### Step 2: Format Codex Prompt
```markdown
## Task for Codex

### Context
Project: [Project name]
Language: [Primary language]
Framework: [Framework if applicable]

### Current Code
```[language]
[Relevant code context]
```

### Task
[User's task description]

### Requirements
- Follow existing code style
- Include error handling
- Add necessary imports
- Write tests if applicable

### Output Format
Provide complete, runnable code.
```

### Step 3: Execute via Codex CLI
```bash
# Using Codex CLI
codex --model gpt-4 --task "[task]" --context "[context]"

# Or with file input
codex --model gpt-4 --file context.md --output result.ts
```

### Step 4: Process Result
```markdown
## Codex Result

### Generated Code
```[language]
[Generated code]
```

### Explanation
[Codex's explanation of the implementation]

### Suggestions
- [Alternative approach 1]
- [Alternative approach 2]
```

### Step 5: Integration Options
- **Apply directly** - Write code to file
- **Review first** - Show diff before applying
- **Compare** - Show alongside Claude's implementation
- **Iterate** - Refine with additional prompts

## Use Cases

### Rapid Prototyping
```
/codex Create a quick prototype of a file upload component
```

### Alternative Implementation
```
/codex Implement the same function using a different approach
```

### Code Translation
```
/codex Convert this Python code to TypeScript
```

### Complex Debugging
```
/codex Debug this function - it's returning incorrect values
```

## Codex Strengths

### Best For
- Quick iterations
- Multiple alternatives
- Code translation
- Boilerplate generation
- Algorithm implementation

### Example Tasks
- "Generate CRUD API for User model"
- "Create React form with validation"
- "Implement binary search tree"
- "Convert callback-based code to async/await"

## Configuration

### Environment Variables
```bash
export OPENAI_API_KEY="your-api-key"
export CODEX_MODEL="gpt-4"  # or "o3-pro" for complex tasks
```

### Model Selection
| Model | Use Case | Speed | Quality |
|-------|----------|-------|---------|
| gpt-4 | Standard tasks | Fast | Good |
| o3-pro | Complex debugging | Slow | Excellent |

## Example Usage
```
/codex implement user authentication
/codex refactor this function for better performance
/codex generate tests for the auth module
/codex translate to Python: [code]
```

## Response Format
```markdown
## Codex Response

### Task
[Original task]

### Implementation
```[language]
[Generated code]
```

### Notes
[Implementation notes and considerations]

### Next Steps
1. Review generated code
2. Run tests
3. Integrate into codebase
```

## Integration with Tri-Agent Workflow
When used in consensus mode:
1. Codex generates implementation
2. Claude reviews for quality
3. Gemini validates logic
4. Consensus determines final version
