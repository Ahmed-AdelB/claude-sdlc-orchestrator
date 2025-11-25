# Gemini CLI

Execute a task using Google's Gemini CLI for large context analysis and documentation.

## Arguments
- `$ARGUMENTS` - Task description or content to analyze

## Process

### Step 1: Prepare Context
Gather context leveraging Gemini's large context window:
- Full file contents (up to 1M tokens)
- Complete project documentation
- Extensive code history
- Related resources

### Step 2: Format Gemini Prompt
```markdown
## Task for Gemini

### Context (Large)
[Full project context - can include entire codebase]

### Documentation
[Complete documentation files]

### Task
[User's task description]

### Requirements
- Analyze comprehensively
- Consider all edge cases
- Provide detailed explanations
- Reference specific code locations

### Output Format
Detailed analysis with code references.
```

### Step 3: Execute via Gemini CLI
```bash
# Using Gemini CLI
gemini --model gemini-2.5-pro --task "[task]" --context-file context.md

# With large context
gemini --model gemini-2.5-pro --context-dir ./src --output analysis.md
```

### Step 4: Process Result
```markdown
## Gemini Analysis

### Summary
[High-level summary]

### Detailed Analysis
[Comprehensive analysis with code references]

### Findings
1. [Finding 1 with file:line reference]
2. [Finding 2 with file:line reference]

### Recommendations
- [Recommendation 1]
- [Recommendation 2]
```

### Step 5: Integration Options
- **Generate report** - Create detailed documentation
- **Code review** - Review large PRs
- **Architecture analysis** - Analyze system design
- **Migration planning** - Plan large refactors

## Use Cases

### Large Codebase Analysis
```
/gemini Analyze the entire authentication module and document its flow
```

### Documentation Generation
```
/gemini Generate comprehensive API documentation from source code
```

### Code Review (Large PRs)
```
/gemini Review this PR with 50+ file changes
```

### Architecture Review
```
/gemini Analyze the microservices architecture and identify issues
```

## Gemini Strengths

### Best For
- Large context analysis (1M tokens)
- Documentation generation
- Codebase understanding
- Long-form writing
- Cross-file analysis

### Context Advantages
| Feature | Gemini | Other Models |
|---------|--------|--------------|
| Max Context | 1M tokens | 128K-200K |
| Full Project | ✅ Yes | ❌ Partial |
| Complete History | ✅ Yes | ❌ Limited |

### Example Tasks
- "Analyze the entire /src directory"
- "Generate documentation for all API endpoints"
- "Review the complete PR diff"
- "Create architecture diagram from codebase"

## Configuration

### Environment Variables
```bash
export GOOGLE_AI_API_KEY="your-api-key"
export GEMINI_MODEL="gemini-2.5-pro"
```

### Model Selection
| Model | Context | Speed | Use Case |
|-------|---------|-------|----------|
| gemini-2.5-pro | 1M | Medium | Analysis |
| gemini-3-pro | 1M+ | Fast | General |

## Example Usage
```
/gemini analyze entire codebase architecture
/gemini generate API documentation
/gemini review large PR #123
/gemini explain the authentication flow
```

## Response Format
```markdown
## Gemini Analysis

### Overview
[Comprehensive overview]

### Detailed Findings

#### Architecture
[Architecture analysis]

#### Code Quality
[Code quality assessment]

#### Security
[Security considerations]

### Recommendations

#### Immediate Actions
1. [Action 1]
2. [Action 2]

#### Long-term Improvements
1. [Improvement 1]
2. [Improvement 2]

### References
- `src/auth/login.ts:45` - Authentication entry point
- `src/middleware/auth.ts:12` - Token validation
```

## Integration with Tri-Agent Workflow
When used in consensus mode:
1. Gemini provides comprehensive analysis
2. Claude validates implementation details
3. Codex suggests optimizations
4. Consensus combines insights
