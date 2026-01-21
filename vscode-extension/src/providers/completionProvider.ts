/**
 * Tri-Agent VS Code Extension - Completion Provider
 * Provides IntelliSense integration for tri-agent commands
 *
 * Author: Ahmed Adel Bakr Alderai
 */

import * as vscode from "vscode";
import { AgentManager, AgentType } from "../utils/agentManager";

interface CommandCompletion {
  label: string;
  detail: string;
  documentation: string;
  insertText: string;
  kind: vscode.CompletionItemKind;
  agent?: AgentType;
  cost?: string;
}

export class TriAgentCompletionProvider
  implements vscode.CompletionItemProvider
{
  private agentManager: AgentManager;

  // Slash commands for tri-agent operations
  private readonly slashCommands: CommandCompletion[] = [
    {
      label: "/secure",
      detail: "Security Review (Claude)",
      documentation:
        "Perform a comprehensive security review using Claude Opus. Checks for OWASP Top 10, input validation, SQL injection, XSS, and more.",
      insertText: "/secure",
      kind: vscode.CompletionItemKind.Function,
      agent: AgentType.Claude,
      cost: "~$0.45",
    },
    {
      label: "/test-gen",
      detail: "Generate Tests (Codex)",
      documentation:
        "Generate comprehensive test suites using Codex. Supports Jest, Mocha, Pytest, Vitest, Playwright, and Cypress.",
      insertText: "/test-gen",
      kind: vscode.CompletionItemKind.Function,
      agent: AgentType.Codex,
      cost: "~$0.12",
    },
    {
      label: "/review",
      detail: "Multi-Agent Code Review",
      documentation:
        "Perform a thorough code review using all three agents (Claude, Codex, Gemini) for comprehensive feedback.",
      insertText: "/review",
      kind: vscode.CompletionItemKind.Function,
      agent: AgentType.Multi,
      cost: "~$0.65",
    },
    {
      label: "/analyze",
      detail: "Code Analysis (Gemini)",
      documentation:
        "Analyze code for complexity, dependencies, patterns, performance, or architecture using Gemini with 1M token context.",
      insertText: "/analyze",
      kind: vscode.CompletionItemKind.Function,
      agent: AgentType.Gemini,
      cost: "~$0.02",
    },
    {
      label: "/implement",
      detail: "Implement Feature (Codex)",
      documentation:
        "Quickly implement a feature using Codex with xhigh reasoning. Describe the feature and get implementation code.",
      insertText: "/implement",
      kind: vscode.CompletionItemKind.Function,
      agent: AgentType.Codex,
      cost: "~$0.12",
    },
    {
      label: "/refactor",
      detail: "Refactor Code (Claude)",
      documentation:
        "Thoughtfully refactor code using Claude. Options include extract function, simplify conditionals, remove duplication, and more.",
      insertText: "/refactor",
      kind: vscode.CompletionItemKind.Function,
      agent: AgentType.Claude,
      cost: "~$0.08",
    },
    {
      label: "/explain",
      detail: "Explain Code (Gemini)",
      documentation:
        "Get a detailed explanation of code using Gemini. Includes high-level overview, line-by-line explanation, and improvement suggestions.",
      insertText: "/explain",
      kind: vscode.CompletionItemKind.Function,
      agent: AgentType.Gemini,
      cost: "~$0.02",
    },
    {
      label: "/consensus",
      detail: "Tri-Agent Consensus",
      documentation:
        "Get consensus from all three AI agents on a decision or implementation approach.",
      insertText: "/consensus",
      kind: vscode.CompletionItemKind.Function,
      agent: AgentType.Multi,
      cost: "~$0.65",
    },
    {
      label: "/debug",
      detail: "Debug Issue (Claude)",
      documentation:
        "Get debugging assistance with root cause analysis using Claude extended thinking.",
      insertText: "/debug",
      kind: vscode.CompletionItemKind.Function,
      agent: AgentType.Claude,
      cost: "~$0.45",
    },
    {
      label: "/optimize",
      detail: "Optimize Performance (Gemini)",
      documentation:
        "Identify and fix performance issues using Gemini with full codebase context.",
      insertText: "/optimize",
      kind: vscode.CompletionItemKind.Function,
      agent: AgentType.Gemini,
      cost: "~$0.02",
    },
  ];

  // Agent-specific completions
  private readonly agentCompletions: CommandCompletion[] = [
    {
      label: "@claude",
      detail: "Claude Agent",
      documentation:
        "Direct request to Claude. Best for architecture, security, and complex reasoning.",
      insertText: "@claude ",
      kind: vscode.CompletionItemKind.Reference,
      agent: AgentType.Claude,
    },
    {
      label: "@codex",
      detail: "Codex Agent",
      documentation:
        "Direct request to Codex (GPT-5.2). Best for implementation, tests, and prototyping.",
      insertText: "@codex ",
      kind: vscode.CompletionItemKind.Reference,
      agent: AgentType.Codex,
    },
    {
      label: "@gemini",
      detail: "Gemini Agent",
      documentation:
        "Direct request to Gemini 3 Pro. Best for large context analysis and documentation.",
      insertText: "@gemini ",
      kind: vscode.CompletionItemKind.Reference,
      agent: AgentType.Gemini,
    },
    {
      label: "@all",
      detail: "All Agents",
      documentation:
        "Send request to all three agents and get combined results.",
      insertText: "@all ",
      kind: vscode.CompletionItemKind.Reference,
      agent: AgentType.Multi,
    },
  ];

  // Task type completions (for #hashtag triggers)
  private readonly taskCompletions: CommandCompletion[] = [
    {
      label: "#security",
      detail: "Security Task",
      documentation:
        "Mark this as a security-sensitive task requiring Claude review.",
      insertText: "#security ",
      kind: vscode.CompletionItemKind.Keyword,
    },
    {
      label: "#test",
      detail: "Testing Task",
      documentation: "Mark this as a testing task for Codex.",
      insertText: "#test ",
      kind: vscode.CompletionItemKind.Keyword,
    },
    {
      label: "#docs",
      detail: "Documentation Task",
      documentation: "Mark this as a documentation task for Gemini.",
      insertText: "#docs ",
      kind: vscode.CompletionItemKind.Keyword,
    },
    {
      label: "#perf",
      detail: "Performance Task",
      documentation: "Mark this as a performance optimization task.",
      insertText: "#perf ",
      kind: vscode.CompletionItemKind.Keyword,
    },
    {
      label: "#refactor",
      detail: "Refactoring Task",
      documentation: "Mark this as a refactoring task.",
      insertText: "#refactor ",
      kind: vscode.CompletionItemKind.Keyword,
    },
    {
      label: "#bug",
      detail: "Bug Fix Task",
      documentation: "Mark this as a bug fix task with root cause analysis.",
      insertText: "#bug ",
      kind: vscode.CompletionItemKind.Keyword,
    },
    {
      label: "#feature",
      detail: "Feature Task",
      documentation: "Mark this as a new feature implementation task.",
      insertText: "#feature ",
      kind: vscode.CompletionItemKind.Keyword,
    },
  ];

  constructor(agentManager: AgentManager) {
    this.agentManager = agentManager;
  }

  provideCompletionItems(
    document: vscode.TextDocument,
    position: vscode.Position,
    token: vscode.CancellationToken,
    context: vscode.CompletionContext,
  ): vscode.ProviderResult<vscode.CompletionItem[] | vscode.CompletionList> {
    const lineText = document.lineAt(position).text;
    const textBeforeCursor = lineText.substring(0, position.character);

    // Check for slash command trigger
    if (textBeforeCursor.endsWith("/") || textBeforeCursor.match(/\/\w*$/)) {
      return this.createCompletionItems(this.slashCommands, "/");
    }

    // Check for agent trigger
    if (textBeforeCursor.endsWith("@") || textBeforeCursor.match(/@\w*$/)) {
      return this.createCompletionItems(this.agentCompletions, "@");
    }

    // Check for task type trigger
    if (textBeforeCursor.endsWith("#") || textBeforeCursor.match(/#\w*$/)) {
      return this.createCompletionItems(this.taskCompletions, "#");
    }

    // Context-aware completions
    if (this.isInCommentBlock(document, position)) {
      return this.provideCommentCompletions(document, position);
    }

    return undefined;
  }

  private createCompletionItems(
    commands: CommandCompletion[],
    trigger: string,
  ): vscode.CompletionItem[] {
    return commands.map((cmd) => {
      const item = new vscode.CompletionItem(cmd.label, cmd.kind);
      item.detail = cmd.detail;

      // Build rich documentation
      const markdown = new vscode.MarkdownString();
      markdown.appendMarkdown(`**${cmd.detail}**\n\n`);
      markdown.appendMarkdown(cmd.documentation + "\n\n");

      if (cmd.agent) {
        markdown.appendMarkdown(`**Agent:** ${cmd.agent}\n\n`);
      }

      if (cmd.cost) {
        markdown.appendMarkdown(`**Estimated Cost:** ${cmd.cost}\n`);
      }

      item.documentation = markdown;
      item.insertText = cmd.insertText;
      item.filterText = cmd.label;

      // Set sort order
      item.sortText = `0${cmd.label}`;

      // Add command to execute on selection
      if (cmd.label.startsWith("/")) {
        item.command = {
          command: `triAgent.${cmd.label.substring(1).replace(/-/g, "")}`,
          title: cmd.detail,
        };
      }

      return item;
    });
  }

  private isInCommentBlock(
    document: vscode.TextDocument,
    position: vscode.Position,
  ): boolean {
    const lineText = document.lineAt(position).text;
    const textBeforeCursor = lineText.substring(0, position.character);

    // Check for common comment patterns
    const commentPatterns = [
      /\/\/.*$/, // Single-line JS/TS/C
      /\/\*.*$/, // Multi-line JS/TS/C start
      /#.*$/, // Python/Shell
      /--.*$/, // SQL/Lua
      /<!--.*$/, // HTML
    ];

    return commentPatterns.some((pattern) => pattern.test(textBeforeCursor));
  }

  private provideCommentCompletions(
    document: vscode.TextDocument,
    position: vscode.Position,
  ): vscode.CompletionItem[] {
    const todoItems: CommandCompletion[] = [
      {
        label: "TODO: security",
        detail: "Security TODO",
        documentation: "Mark for security review by Claude",
        insertText: "TODO: [SECURITY] ",
        kind: vscode.CompletionItemKind.Snippet,
      },
      {
        label: "TODO: test",
        detail: "Test TODO",
        documentation: "Mark for test generation by Codex",
        insertText: "TODO: [TEST] ",
        kind: vscode.CompletionItemKind.Snippet,
      },
      {
        label: "TODO: refactor",
        detail: "Refactor TODO",
        documentation: "Mark for refactoring",
        insertText: "TODO: [REFACTOR] ",
        kind: vscode.CompletionItemKind.Snippet,
      },
      {
        label: "TODO: perf",
        detail: "Performance TODO",
        documentation: "Mark for performance optimization",
        insertText: "TODO: [PERF] ",
        kind: vscode.CompletionItemKind.Snippet,
      },
      {
        label: "FIXME",
        detail: "Fix Required",
        documentation: "Mark as requiring a fix",
        insertText: "FIXME: ",
        kind: vscode.CompletionItemKind.Snippet,
      },
      {
        label: "HACK",
        detail: "Temporary Hack",
        documentation: "Mark as temporary solution needing proper fix",
        insertText: "HACK: ",
        kind: vscode.CompletionItemKind.Snippet,
      },
      {
        label: "NOTE",
        detail: "Developer Note",
        documentation: "Add a developer note",
        insertText: "NOTE: ",
        kind: vscode.CompletionItemKind.Snippet,
      },
    ];

    return this.createCompletionItems(todoItems, "");
  }

  resolveCompletionItem(
    item: vscode.CompletionItem,
    token: vscode.CancellationToken,
  ): vscode.ProviderResult<vscode.CompletionItem> {
    // Add additional information when item is selected
    if (item.label === "/secure") {
      const status = this.agentManager.getAgentStatus(AgentType.Claude);
      const markdown = item.documentation as vscode.MarkdownString;
      markdown.appendMarkdown(
        `\n\n**Claude Status:** ${status.available ? "Available" : "Busy"}`,
      );
    }

    return item;
  }
}

/**
 * Inline completion provider for AI-assisted code suggestions
 */
export class TriAgentInlineCompletionProvider
  implements vscode.InlineCompletionItemProvider
{
  private agentManager: AgentManager;
  private debounceTimer: NodeJS.Timeout | undefined;
  private readonly debounceDelay = 500;

  constructor(agentManager: AgentManager) {
    this.agentManager = agentManager;
  }

  async provideInlineCompletionItems(
    document: vscode.TextDocument,
    position: vscode.Position,
    context: vscode.InlineCompletionContext,
    token: vscode.CancellationToken,
  ): Promise<
    vscode.InlineCompletionItem[] | vscode.InlineCompletionList | undefined
  > {
    // Only trigger on explicit request or after pause
    if (context.triggerKind !== vscode.InlineCompletionTriggerKind.Invoke) {
      return undefined;
    }

    const lineText = document.lineAt(position).text;
    const textBeforeCursor = lineText.substring(0, position.character);

    // Check for completion triggers
    if (!this.shouldProvideCompletion(textBeforeCursor)) {
      return undefined;
    }

    try {
      const completion = await this.getAICompletion(document, position, token);

      if (!completion || token.isCancellationRequested) {
        return undefined;
      }

      return [
        new vscode.InlineCompletionItem(
          completion,
          new vscode.Range(position, position),
        ),
      ];
    } catch (error) {
      console.error("Inline completion error:", error);
      return undefined;
    }
  }

  private shouldProvideCompletion(textBeforeCursor: string): boolean {
    // Trigger completions after function signatures, assignments, etc.
    const triggers = [
      /=\s*$/, // After assignment
      /:\s*$/, // After type annotation
      /\(\s*$/, // After opening parenthesis
      /{\s*$/, // After opening brace
      /=>\s*$/, // After arrow function
      /return\s*$/, // After return
      /\?\s*$/, // After ternary operator
    ];

    return triggers.some((pattern) => pattern.test(textBeforeCursor));
  }

  private async getAICompletion(
    document: vscode.TextDocument,
    position: vscode.Position,
    token: vscode.CancellationToken,
  ): Promise<string | undefined> {
    // Get context around cursor
    const startLine = Math.max(0, position.line - 20);
    const endLine = Math.min(document.lineCount, position.line + 5);

    const contextBefore = document.getText(
      new vscode.Range(startLine, 0, position.line, position.character),
    );
    const contextAfter = document.getText(
      new vscode.Range(position.line, position.character, endLine, 0),
    );

    // Use Codex for fast inline completions
    const prompt = `Complete the following ${document.languageId} code. Provide only the completion, no explanation.

Context:
${contextBefore}[CURSOR]${contextAfter}

Completion:`;

    // TODO: Implement actual API call to Codex
    // For now, return undefined to avoid blocking
    return undefined;
  }
}
