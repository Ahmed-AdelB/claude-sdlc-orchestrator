/**
 * Tri-Agent VS Code Extension - Code Action Provider
 * Provides quick fixes and refactoring actions
 *
 * Author: Ahmed Adel Bakr Alderai
 */

import * as vscode from "vscode";
import { AgentManager } from "../utils/agentManager";

export class TriAgentCodeActionProvider implements vscode.CodeActionProvider {
  public static readonly providedCodeActionKinds = [
    vscode.CodeActionKind.QuickFix,
    vscode.CodeActionKind.Refactor,
    vscode.CodeActionKind.Source,
  ];

  private agentManager: AgentManager;

  constructor(agentManager: AgentManager) {
    this.agentManager = agentManager;
  }

  provideCodeActions(
    document: vscode.TextDocument,
    range: vscode.Range | vscode.Selection,
    context: vscode.CodeActionContext,
    token: vscode.CancellationToken,
  ): vscode.ProviderResult<(vscode.CodeAction | vscode.Command)[]> {
    const actions: vscode.CodeAction[] = [];

    // Get the selected text or line
    const hasSelection = !range.isEmpty;
    const text = hasSelection
      ? document.getText(range)
      : document.lineAt(range.start.line).text;

    // Security Review action
    const securityAction = new vscode.CodeAction(
      "Tri-Agent: Security Review",
      vscode.CodeActionKind.Source,
    );
    securityAction.command = {
      command: "triAgent.secure",
      title: "Run security review",
    };
    actions.push(securityAction);

    // Generate Tests action
    const testAction = new vscode.CodeAction(
      "Tri-Agent: Generate Tests",
      vscode.CodeActionKind.Source,
    );
    testAction.command = {
      command: "triAgent.testGen",
      title: "Generate tests",
    };
    actions.push(testAction);

    // Code Review action
    const reviewAction = new vscode.CodeAction(
      "Tri-Agent: Code Review",
      vscode.CodeActionKind.Source,
    );
    reviewAction.command = {
      command: "triAgent.review",
      title: "Run code review",
    };
    actions.push(reviewAction);

    // Refactoring actions (only when text is selected)
    if (hasSelection) {
      const refactorActions = this.getRefactorActions(document, range, text);
      actions.push(...refactorActions);
    }

    // Context-aware quick fixes based on diagnostics
    if (context.diagnostics.length > 0) {
      const quickFixes = this.getQuickFixActions(
        document,
        range,
        context.diagnostics,
      );
      actions.push(...quickFixes);
    }

    // Pattern-specific actions
    const patternActions = this.getPatternSpecificActions(
      document,
      range,
      text,
    );
    actions.push(...patternActions);

    return actions;
  }

  private getRefactorActions(
    document: vscode.TextDocument,
    range: vscode.Range,
    text: string,
  ): vscode.CodeAction[] {
    const actions: vscode.CodeAction[] = [];

    // Extract function
    const extractFunction = new vscode.CodeAction(
      "Tri-Agent: Extract to function",
      vscode.CodeActionKind.RefactorExtract,
    );
    extractFunction.command = {
      command: "triAgent.refactor",
      title: "Extract function",
      arguments: ["Extract function"],
    };
    actions.push(extractFunction);

    // Simplify conditionals (if text contains if/else)
    if (text.includes("if") || text.includes("else") || text.includes("?")) {
      const simplifyConditionals = new vscode.CodeAction(
        "Tri-Agent: Simplify conditionals",
        vscode.CodeActionKind.RefactorRewrite,
      );
      simplifyConditionals.command = {
        command: "triAgent.refactor",
        title: "Simplify conditionals",
        arguments: ["Simplify conditionals"],
      };
      actions.push(simplifyConditionals);
    }

    // Add error handling
    const addErrorHandling = new vscode.CodeAction(
      "Tri-Agent: Add error handling",
      vscode.CodeActionKind.RefactorRewrite,
    );
    addErrorHandling.command = {
      command: "triAgent.refactor",
      title: "Add error handling",
      arguments: ["Add error handling"],
    };
    actions.push(addErrorHandling);

    // Improve naming
    const improveNaming = new vscode.CodeAction(
      "Tri-Agent: Improve naming",
      vscode.CodeActionKind.RefactorRewrite,
    );
    improveNaming.command = {
      command: "triAgent.refactor",
      title: "Improve naming",
      arguments: ["Improve naming"],
    };
    actions.push(improveNaming);

    return actions;
  }

  private getQuickFixActions(
    document: vscode.TextDocument,
    range: vscode.Range,
    diagnostics: readonly vscode.Diagnostic[],
  ): vscode.CodeAction[] {
    const actions: vscode.CodeAction[] = [];

    for (const diagnostic of diagnostics) {
      // Security-related diagnostics
      if (this.isSecurityDiagnostic(diagnostic)) {
        const fixSecurity = new vscode.CodeAction(
          "Tri-Agent: Fix security issue",
          vscode.CodeActionKind.QuickFix,
        );
        fixSecurity.command = {
          command: "triAgent.secure",
          title: "Fix security issue",
        };
        fixSecurity.diagnostics = [diagnostic];
        fixSecurity.isPreferred = true;
        actions.push(fixSecurity);
      }

      // Type errors
      if (this.isTypeError(diagnostic)) {
        const fixType = new vscode.CodeAction(
          "Tri-Agent: Fix type error",
          vscode.CodeActionKind.QuickFix,
        );
        fixType.command = {
          command: "triAgent.implement",
          title: "Fix type error",
          arguments: [`Fix type error: ${diagnostic.message}`],
        };
        fixType.diagnostics = [diagnostic];
        actions.push(fixType);
      }

      // General errors - get AI help
      const aiHelp = new vscode.CodeAction(
        "Tri-Agent: Get AI help for this issue",
        vscode.CodeActionKind.QuickFix,
      );
      aiHelp.command = {
        command: "triAgent.explain",
        title: "Explain and fix issue",
        arguments: [diagnostic.message],
      };
      aiHelp.diagnostics = [diagnostic];
      actions.push(aiHelp);
    }

    return actions;
  }

  private getPatternSpecificActions(
    document: vscode.TextDocument,
    range: vscode.Range,
    text: string,
  ): vscode.CodeAction[] {
    const actions: vscode.CodeAction[] = [];
    const language = document.languageId;

    // SQL-like patterns - suggest parameterization
    if (this.containsSqlPattern(text)) {
      const sqlFix = new vscode.CodeAction(
        "Tri-Agent: Check for SQL injection",
        vscode.CodeActionKind.QuickFix,
      );
      sqlFix.command = {
        command: "triAgent.secure",
        title: "Check SQL for injection vulnerabilities",
      };
      sqlFix.isPreferred = true;
      actions.push(sqlFix);
    }

    // Async patterns - suggest error handling
    if (this.containsAsyncPattern(text, language)) {
      const asyncFix = new vscode.CodeAction(
        "Tri-Agent: Add async error handling",
        vscode.CodeActionKind.RefactorRewrite,
      );
      asyncFix.command = {
        command: "triAgent.refactor",
        title: "Add error handling",
        arguments: ["Add error handling"],
      };
      actions.push(asyncFix);
    }

    // TODO/FIXME comments
    if (this.containsTodoPattern(text)) {
      const todoFix = new vscode.CodeAction(
        "Tri-Agent: Implement TODO",
        vscode.CodeActionKind.QuickFix,
      );
      todoFix.command = {
        command: "triAgent.implement",
        title: "Implement TODO",
      };
      actions.push(todoFix);
    }

    // Long functions (basic heuristic)
    const lineCount = range.end.line - range.start.line;
    if (lineCount > 30) {
      const splitFunction = new vscode.CodeAction(
        "Tri-Agent: Split long function",
        vscode.CodeActionKind.RefactorExtract,
      );
      splitFunction.command = {
        command: "triAgent.refactor",
        title: "Extract function",
        arguments: ["Extract function"],
      };
      actions.push(splitFunction);
    }

    return actions;
  }

  private isSecurityDiagnostic(diagnostic: vscode.Diagnostic): boolean {
    const securityKeywords = [
      "security",
      "injection",
      "xss",
      "csrf",
      "authentication",
      "authorization",
      "password",
      "secret",
      "credential",
      "vulnerability",
    ];
    const message = diagnostic.message.toLowerCase();
    return securityKeywords.some((keyword) => message.includes(keyword));
  }

  private isTypeError(diagnostic: vscode.Diagnostic): boolean {
    const typeKeywords = ["type", "typescript", "expected", "argument"];
    const message = diagnostic.message.toLowerCase();
    return typeKeywords.some((keyword) => message.includes(keyword));
  }

  private containsSqlPattern(text: string): boolean {
    const sqlPatterns = [
      /SELECT.*FROM/i,
      /INSERT.*INTO/i,
      /UPDATE.*SET/i,
      /DELETE.*FROM/i,
      /query\s*\(/i,
      /execute\s*\(/i,
    ];
    return sqlPatterns.some((pattern) => pattern.test(text));
  }

  private containsAsyncPattern(text: string, language: string): boolean {
    if (
      [
        "typescript",
        "javascript",
        "typescriptreact",
        "javascriptreact",
      ].includes(language)
    ) {
      return /async\s+|await\s+|\.then\s*\(|Promise/i.test(text);
    }
    if (language === "python") {
      return /async\s+def|await\s+|asyncio/i.test(text);
    }
    return false;
  }

  private containsTodoPattern(text: string): boolean {
    return /TODO|FIXME|HACK|XXX/i.test(text);
  }

  resolveCodeAction(
    codeAction: vscode.CodeAction,
    token: vscode.CancellationToken,
  ): vscode.ProviderResult<vscode.CodeAction> {
    // Add additional context when action is selected
    return codeAction;
  }
}
