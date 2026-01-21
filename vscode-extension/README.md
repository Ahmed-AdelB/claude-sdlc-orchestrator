# Tri-Agent VS Code Extension

A VS Code extension for integrating the Tri-Agent workflow (Claude, Codex, Gemini) directly into your development environment.

## Features

### AI-Powered Code Actions

- **Security Review** (`Ctrl+Shift+S` / `Cmd+Shift+S`): Comprehensive OWASP-based security analysis using Claude Opus
- **Test Generation** (`Ctrl+Shift+T` / `Cmd+Shift+T`): Generate comprehensive test suites using Codex
- **Code Review** (`Ctrl+Shift+R` / `Cmd+Shift+R`): Multi-agent code review using all three AI agents
- **Code Analysis** (`Ctrl+Shift+A` / `Cmd+Shift+A`): Deep analysis using Gemini's 1M token context
- **Refactoring**: AI-assisted code refactoring with Claude

### Agent Status Panel

View real-time status of all three AI agents in the sidebar:

- Agent availability (Claude, Codex, Gemini)
- Active tasks and their progress
- Cost tracking and budget management
- Metrics and performance statistics

### IntelliSense Integration

Type `/` to access Tri-Agent commands directly:

- `/secure` - Security review
- `/test-gen` - Generate tests
- `/review` - Multi-agent code review
- `/analyze` - Code analysis
- `/implement` - Implement feature
- `/refactor` - Refactor code
- `/explain` - Explain code

Type `@` to direct commands to specific agents:

- `@claude` - Send to Claude
- `@codex` - Send to Codex
- `@gemini` - Send to Gemini
- `@all` - Multi-agent consensus

### Code Actions

Right-click on code to access:

- Tri-Agent: Security Review
- Tri-Agent: Generate Tests
- Tri-Agent: Code Review
- Tri-Agent: Extract to function
- Tri-Agent: Simplify conditionals
- Tri-Agent: Add error handling
- Tri-Agent: Improve naming

### Cost Tracking

Real-time cost tracking with:

- Daily budget monitoring ($42/day default)
- Per-agent cost breakdown
- Budget warnings at 70% and 90% usage
- Cost estimates before execution

## Requirements

### CLI Tools

This extension requires the following CLI tools to be installed:

1. **Claude Code CLI**

   ```bash
   # Already installed if you have Claude Max subscription
   claude --version
   ```

2. **Codex CLI**

   ```bash
   npm install -g @openai/codex-cli
   codex --version
   ```

3. **Gemini CLI**
   ```bash
   npm install -g @google/gemini-cli
   gemini --version
   ```

### Authentication

Ensure you have authenticated with each service:

```bash
# Claude (uses Claude Code authentication)
claude auth

# Codex
codex auth

# Gemini
gemini auth
```

## Installation

### From Source

1. Clone or copy the extension to your VS Code extensions directory:

   ```bash
   cd ~/.vscode/extensions
   git clone <repo> tri-agent-vscode
   cd tri-agent-vscode
   npm install
   npm run compile
   ```

2. Restart VS Code

### From VSIX

1. Build the VSIX package:

   ```bash
   npm run package
   ```

2. Install in VS Code:
   - Open Command Palette (`Ctrl+Shift+P`)
   - Run "Extensions: Install from VSIX..."
   - Select the generated `.vsix` file

## Configuration

Configure the extension in VS Code Settings (`Ctrl+,`):

| Setting                           | Default          | Description                                 |
| --------------------------------- | ---------------- | ------------------------------------------- |
| `triAgent.claudePath`             | `claude`         | Path to Claude CLI executable               |
| `triAgent.codexPath`              | `codex`          | Path to Codex CLI executable                |
| `triAgent.geminiPath`             | `gemini`         | Path to Gemini CLI executable               |
| `triAgent.defaultModel`           | `auto`           | Default AI model (claude/codex/gemini/auto) |
| `triAgent.showCostEstimates`      | `true`           | Show cost estimates before execution        |
| `triAgent.autoRefreshInterval`    | `30`             | Status panel refresh interval (seconds)     |
| `triAgent.maxConcurrentAgents`    | `9`              | Maximum concurrent agent instances          |
| `triAgent.budgetWarningThreshold` | `70`             | Budget warning threshold (%)                |
| `triAgent.logsDirectory`          | `~/.claude/logs` | Directory for tri-agent logs                |

## Usage

### Quick Start

1. Open a file in VS Code
2. Use keyboard shortcuts or right-click menu to access Tri-Agent features
3. View agent status in the sidebar (Tri-Agent icon)
4. Monitor costs in the Cost Tracking panel

### Security Review

```
Ctrl+Shift+S (Windows/Linux)
Cmd+Shift+S (macOS)
```

Performs OWASP Top 10 security analysis:

- SQL injection detection
- XSS vulnerabilities
- Authentication flaws
- Sensitive data exposure
- Input validation issues

### Test Generation

```
Ctrl+Shift+T (Windows/Linux)
Cmd+Shift+T (macOS)
```

Generates comprehensive tests using Codex:

- Supports Jest, Mocha, Pytest, Vitest, Playwright, Cypress
- Unit tests for each function
- Edge case coverage
- Error handling tests

### Multi-Agent Code Review

```
Ctrl+Shift+R (Windows/Linux)
Cmd+Shift+R (macOS)
```

Runs code review with all three agents:

- Claude: Security and architecture focus
- Codex: Implementation and testing focus
- Gemini: Patterns and documentation focus

## Architecture

```
src/
  extension.ts           # Main entry point
  commands/
    index.ts            # Command implementations
  providers/
    completionProvider.ts    # IntelliSense integration
    codeActionProvider.ts    # Quick fixes and refactoring
  views/
    agentPanel.ts       # Sidebar webview
    taskTreeProvider.ts # Task tree view
    costTreeProvider.ts # Cost tracking tree view
  utils/
    agentManager.ts     # Agent state management
    statusBar.ts        # Status bar manager
    costEstimator.ts    # Cost estimation
    logger.ts           # Logging utility
```

## Cost Estimates

| Task Type           | Model         | Estimated Cost  |
| ------------------- | ------------- | --------------- |
| Security Review     | Claude Opus   | ~$0.45/review   |
| Test Generation     | Codex         | ~$0.12/file     |
| Code Review (Multi) | All           | ~$0.65/review   |
| Analysis            | Gemini Pro    | ~$0.02/file     |
| Implementation      | Codex         | ~$0.12/feature  |
| Refactoring         | Claude Sonnet | ~$0.08/refactor |
| Explanation         | Gemini Pro    | ~$0.02/file     |

_Costs vary based on code size and complexity_

## Keyboard Shortcuts

| Command         | Windows/Linux  | macOS         |
| --------------- | -------------- | ------------- |
| Security Review | `Ctrl+Shift+S` | `Cmd+Shift+S` |
| Generate Tests  | `Ctrl+Shift+T` | `Cmd+Shift+T` |
| Code Review     | `Ctrl+Shift+R` | `Cmd+Shift+R` |
| Analyze Code    | `Ctrl+Shift+A` | `Cmd+Shift+A` |
| Show Panel      | `Ctrl+Shift+P` | `Cmd+Shift+P` |
| Cancel Task     | `Ctrl+Shift+C` | `Cmd+Shift+C` |

## Troubleshooting

### CLI Not Found

If you see "CLI tools not found" warnings:

1. Check that the CLI tools are installed globally
2. Verify the paths in VS Code settings
3. Ensure the tools are in your system PATH

### Authentication Errors

If commands fail with authentication errors:

1. Re-authenticate with the respective CLI:

   ```bash
   claude auth
   codex auth
   gemini auth
   ```

2. Check credential files:
   - Claude: `~/.claude/`
   - Codex: `~/.codex/config.toml`
   - Gemini: `~/.gemini/oauth_creds.json`

### Rate Limiting

If you encounter rate limits:

1. Wait for the cooldown period
2. Check your daily budget usage in the Cost Tracking panel
3. Consider reducing concurrent agent usage

## Contributing

Contributions are welcome. Please follow the existing code style and include tests for new features.

## License

MIT License

---

**Author:** Ahmed Adel Bakr Alderai
