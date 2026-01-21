/**
 * Tri-Agent VS Code Extension - Status Bar Manager
 * Manages the status bar item showing agent status
 *
 * Author: Ahmed Adel Bakr Alderai
 */

import * as vscode from "vscode";
import { AgentStatus } from "./agentManager";

export class StatusBarManager {
  private statusBarItem: vscode.StatusBarItem;
  private progressItem: vscode.StatusBarItem;
  private isInitialized: boolean = false;

  constructor() {
    // Main status bar item
    this.statusBarItem = vscode.window.createStatusBarItem(
      vscode.StatusBarAlignment.Right,
      100,
    );
    this.statusBarItem.command = "triAgent.showPanel";

    // Progress indicator
    this.progressItem = vscode.window.createStatusBarItem(
      vscode.StatusBarAlignment.Right,
      99,
    );
  }

  initialize(context: vscode.ExtensionContext): void {
    if (this.isInitialized) return;

    context.subscriptions.push(this.statusBarItem);
    context.subscriptions.push(this.progressItem);

    this.statusBarItem.text = "$(robot) Tri-Agent";
    this.statusBarItem.tooltip = "Click to open Tri-Agent panel";
    this.statusBarItem.show();

    this.isInitialized = true;
  }

  update(status: {
    activeTasks: number;
    claudeStatus: AgentStatus;
    codexStatus: AgentStatus;
    geminiStatus: AgentStatus;
    dailyCost: number;
  }): void {
    // Build status text
    const activeIndicator =
      status.activeTasks > 0
        ? `$(sync~spin) ${status.activeTasks}`
        : "$(check)";

    const agentIndicators = [
      this.getAgentIndicator("C", status.claudeStatus),
      this.getAgentIndicator("X", status.codexStatus),
      this.getAgentIndicator("G", status.geminiStatus),
    ].join(" ");

    this.statusBarItem.text = `$(robot) ${activeIndicator} | ${agentIndicators}`;

    // Build tooltip
    const tooltip = new vscode.MarkdownString();
    tooltip.appendMarkdown("### Tri-Agent Status\n\n");
    tooltip.appendMarkdown(`**Active Tasks:** ${status.activeTasks}\n\n`);
    tooltip.appendMarkdown(
      `**Daily Cost:** $${status.dailyCost.toFixed(2)}\n\n`,
    );
    tooltip.appendMarkdown("---\n\n");
    tooltip.appendMarkdown(
      `**Claude:** ${this.formatAgentStatus(status.claudeStatus)}\n\n`,
    );
    tooltip.appendMarkdown(
      `**Codex:** ${this.formatAgentStatus(status.codexStatus)}\n\n`,
    );
    tooltip.appendMarkdown(
      `**Gemini:** ${this.formatAgentStatus(status.geminiStatus)}\n\n`,
    );
    tooltip.appendMarkdown("---\n\n");
    tooltip.appendMarkdown("*Click to open panel*");

    this.statusBarItem.tooltip = tooltip;

    // Update color based on status
    if (status.activeTasks > 0) {
      this.statusBarItem.backgroundColor = new vscode.ThemeColor(
        "statusBarItem.warningBackground",
      );
    } else {
      this.statusBarItem.backgroundColor = undefined;
    }

    // Warn if approaching budget limit
    const budgetPercent = (status.dailyCost / 42) * 100;
    if (budgetPercent > 90) {
      this.statusBarItem.backgroundColor = new vscode.ThemeColor(
        "statusBarItem.errorBackground",
      );
    } else if (budgetPercent > 70) {
      this.statusBarItem.backgroundColor = new vscode.ThemeColor(
        "statusBarItem.warningBackground",
      );
    }
  }

  private getAgentIndicator(letter: string, status: AgentStatus): string {
    if (status.busy) {
      return `$(loading~spin)${letter}`;
    } else if (status.available) {
      return `$(pass)${letter}`;
    } else {
      return `$(error)${letter}`;
    }
  }

  private formatAgentStatus(status: AgentStatus): string {
    if (status.busy) {
      return `Busy (Task: ${status.currentTask || "unknown"})`;
    } else if (status.available) {
      return "Available";
    } else {
      return `Offline (Errors: ${status.errorCount})`;
    }
  }

  showProgress(message: string): void {
    this.progressItem.text = `$(loading~spin) ${message}`;
    this.progressItem.show();
  }

  hideProgress(): void {
    this.progressItem.hide();
  }

  showNotification(
    message: string,
    type: "info" | "warning" | "error" = "info",
  ): void {
    switch (type) {
      case "error":
        vscode.window.showErrorMessage(`Tri-Agent: ${message}`);
        break;
      case "warning":
        vscode.window.showWarningMessage(`Tri-Agent: ${message}`);
        break;
      default:
        vscode.window.showInformationMessage(`Tri-Agent: ${message}`);
    }
  }

  dispose(): void {
    this.statusBarItem.dispose();
    this.progressItem.dispose();
  }
}
