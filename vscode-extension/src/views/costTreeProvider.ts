/**
 * Tri-Agent VS Code Extension - Cost Tree Provider
 * Provides tree view for cost tracking and budget management
 *
 * Author: Ahmed Adel Bakr Alderai
 */

import * as vscode from "vscode";
import { AgentManager, AgentType } from "../utils/agentManager";

export class CostTreeProvider implements vscode.TreeDataProvider<CostTreeItem> {
  private _onDidChangeTreeData: vscode.EventEmitter<
    CostTreeItem | undefined | null | void
  > = new vscode.EventEmitter<CostTreeItem | undefined | null | void>();
  readonly onDidChangeTreeData: vscode.Event<
    CostTreeItem | undefined | null | void
  > = this._onDidChangeTreeData.event;

  private agentManager: AgentManager;

  // Daily budget allocation ($42/day total)
  private readonly DAILY_BUDGET = 42;
  private readonly BUDGET_ALLOCATION = {
    [AgentType.Claude]: 15, // $15/day for Claude
    [AgentType.Codex]: 12, // $12/day for Codex
    [AgentType.Gemini]: 5, // $5/day for Gemini (cheap)
    [AgentType.Multi]: 10, // $10/day for multi-agent
  };

  constructor(agentManager: AgentManager) {
    this.agentManager = agentManager;
  }

  refresh(): void {
    this._onDidChangeTreeData.fire();
  }

  getTreeItem(element: CostTreeItem): vscode.TreeItem {
    return element;
  }

  getChildren(element?: CostTreeItem): Thenable<CostTreeItem[]> {
    if (!element) {
      // Root level - show summary and categories
      return Promise.resolve(this.getRootItems());
    }

    if (element.contextValue === "category") {
      return Promise.resolve(this.getCategoryItems(element.categoryId));
    }

    return Promise.resolve([]);
  }

  private getRootItems(): CostTreeItem[] {
    const dailyCost = this.agentManager.getDailyCost();
    const budgetPercent = (dailyCost / this.DAILY_BUDGET) * 100;
    const metrics = this.agentManager.getMetrics();

    const items: CostTreeItem[] = [];

    // Daily summary
    const summaryItem = new CostTreeItem(
      `Today: $${dailyCost.toFixed(2)} / $${this.DAILY_BUDGET}`,
      vscode.TreeItemCollapsibleState.None,
      "summary",
    );
    summaryItem.description = `${budgetPercent.toFixed(1)}% used`;
    summaryItem.iconPath = this.getBudgetIcon(budgetPercent);
    summaryItem.tooltip = this.createSummaryTooltip(
      dailyCost,
      budgetPercent,
      metrics,
    );
    items.push(summaryItem);

    // Budget progress bar (visual representation)
    const progressItem = new CostTreeItem(
      this.createProgressBar(budgetPercent),
      vscode.TreeItemCollapsibleState.None,
      "progress",
    );
    items.push(progressItem);

    // Agent breakdown category
    const agentCategory = new CostTreeItem(
      "By Agent",
      vscode.TreeItemCollapsibleState.Expanded,
      "category",
      "agents",
    );
    agentCategory.iconPath = new vscode.ThemeIcon("organization");
    items.push(agentCategory);

    // Metrics category
    const metricsCategory = new CostTreeItem(
      "Metrics",
      vscode.TreeItemCollapsibleState.Collapsed,
      "category",
      "metrics",
    );
    metricsCategory.iconPath = new vscode.ThemeIcon("graph");
    items.push(metricsCategory);

    return items;
  }

  private getCategoryItems(categoryId?: string): CostTreeItem[] {
    if (categoryId === "agents") {
      return this.getAgentCostItems();
    }

    if (categoryId === "metrics") {
      return this.getMetricsItems();
    }

    return [];
  }

  private getAgentCostItems(): CostTreeItem[] {
    const items: CostTreeItem[] = [];
    const agents = [
      { type: AgentType.Claude, name: "Claude", icon: "C" },
      { type: AgentType.Codex, name: "Codex", icon: "X" },
      { type: AgentType.Gemini, name: "Gemini", icon: "G" },
    ];

    for (const agent of agents) {
      // Calculate estimated cost for this agent (simplified)
      const tasks = this.agentManager
        .getRecentTasks(100)
        .filter((t) => t.agent === agent.type);
      const agentCost = tasks.reduce((sum, t) => sum + (t.cost || 0), 0);
      const budget = this.BUDGET_ALLOCATION[agent.type];
      const percent = (agentCost / budget) * 100;

      const item = new CostTreeItem(
        `${agent.name}: $${agentCost.toFixed(2)}`,
        vscode.TreeItemCollapsibleState.None,
        "agentCost",
      );
      item.description = `/ $${budget} (${percent.toFixed(0)}%)`;
      item.iconPath = this.getAgentIcon(agent.type);

      const tooltip = new vscode.MarkdownString();
      tooltip.appendMarkdown(`### ${agent.name} Cost Tracking\n\n`);
      tooltip.appendMarkdown(`**Today's Cost:** $${agentCost.toFixed(4)}\n\n`);
      tooltip.appendMarkdown(`**Daily Budget:** $${budget}\n\n`);
      tooltip.appendMarkdown(`**Budget Used:** ${percent.toFixed(1)}%\n\n`);
      tooltip.appendMarkdown(`**Tasks Today:** ${tasks.length}\n\n`);
      item.tooltip = tooltip;

      items.push(item);
    }

    return items;
  }

  private getMetricsItems(): CostTreeItem[] {
    const metrics = this.agentManager.getMetrics();
    const items: CostTreeItem[] = [];

    // Total tasks completed
    const completedItem = new CostTreeItem(
      `Completed: ${metrics.completed}`,
      vscode.TreeItemCollapsibleState.None,
      "metric",
    );
    completedItem.iconPath = new vscode.ThemeIcon(
      "pass",
      new vscode.ThemeColor("charts.green"),
    );
    items.push(completedItem);

    // Failed tasks
    const failedItem = new CostTreeItem(
      `Failed: ${metrics.failed}`,
      vscode.TreeItemCollapsibleState.None,
      "metric",
    );
    failedItem.iconPath = new vscode.ThemeIcon(
      "error",
      new vscode.ThemeColor("charts.red"),
    );
    items.push(failedItem);

    // Success rate
    const total = metrics.completed + metrics.failed;
    const successRate = total > 0 ? (metrics.completed / total) * 100 : 100;
    const successItem = new CostTreeItem(
      `Success Rate: ${successRate.toFixed(1)}%`,
      vscode.TreeItemCollapsibleState.None,
      "metric",
    );
    successItem.iconPath = new vscode.ThemeIcon("pulse");
    items.push(successItem);

    // Average duration
    const avgDurationItem = new CostTreeItem(
      `Avg Duration: ${this.formatDuration(metrics.avgDuration)}`,
      vscode.TreeItemCollapsibleState.None,
      "metric",
    );
    avgDurationItem.iconPath = new vscode.ThemeIcon("clock");
    items.push(avgDurationItem);

    // Total cost
    const totalCostItem = new CostTreeItem(
      `Total Cost: $${metrics.totalCost.toFixed(2)}`,
      vscode.TreeItemCollapsibleState.None,
      "metric",
    );
    totalCostItem.iconPath = new vscode.ThemeIcon("credit-card");
    items.push(totalCostItem);

    // Cost per task
    const costPerTask = total > 0 ? metrics.totalCost / total : 0;
    const costPerTaskItem = new CostTreeItem(
      `Cost/Task: $${costPerTask.toFixed(4)}`,
      vscode.TreeItemCollapsibleState.None,
      "metric",
    );
    costPerTaskItem.iconPath = new vscode.ThemeIcon("symbol-number");
    items.push(costPerTaskItem);

    return items;
  }

  private createSummaryTooltip(
    dailyCost: number,
    budgetPercent: number,
    metrics: { completed: number; failed: number; totalCost: number },
  ): vscode.MarkdownString {
    const tooltip = new vscode.MarkdownString();
    tooltip.appendMarkdown("### Daily Cost Summary\n\n");
    tooltip.appendMarkdown(`**Spent Today:** $${dailyCost.toFixed(2)}\n\n`);
    tooltip.appendMarkdown(`**Daily Budget:** $${this.DAILY_BUDGET}\n\n`);
    tooltip.appendMarkdown(
      `**Remaining:** $${(this.DAILY_BUDGET - dailyCost).toFixed(2)}\n\n`,
    );
    tooltip.appendMarkdown(`**Budget Used:** ${budgetPercent.toFixed(1)}%\n\n`);
    tooltip.appendMarkdown("---\n\n");
    tooltip.appendMarkdown(`**Tasks Completed:** ${metrics.completed}\n\n`);
    tooltip.appendMarkdown(`**Tasks Failed:** ${metrics.failed}\n\n`);

    if (budgetPercent > 90) {
      tooltip.appendMarkdown("\n**Warning:** Budget nearly exhausted!\n");
    } else if (budgetPercent > 70) {
      tooltip.appendMarkdown("\n**Note:** Approaching budget limit.\n");
    }

    return tooltip;
  }

  private createProgressBar(percent: number): string {
    const width = 20;
    const filled = Math.round((percent / 100) * width);
    const empty = width - filled;

    let bar = "";
    if (percent > 90) {
      bar = "\u2588".repeat(filled) + "\u2591".repeat(empty);
    } else if (percent > 70) {
      bar = "\u2588".repeat(filled) + "\u2591".repeat(empty);
    } else {
      bar = "\u2588".repeat(filled) + "\u2591".repeat(empty);
    }

    return `[${bar}]`;
  }

  private getBudgetIcon(percent: number): vscode.ThemeIcon {
    if (percent > 90) {
      return new vscode.ThemeIcon(
        "warning",
        new vscode.ThemeColor("charts.red"),
      );
    } else if (percent > 70) {
      return new vscode.ThemeIcon(
        "info",
        new vscode.ThemeColor("charts.yellow"),
      );
    } else {
      return new vscode.ThemeIcon(
        "pass",
        new vscode.ThemeColor("charts.green"),
      );
    }
  }

  private getAgentIcon(agent: AgentType): vscode.ThemeIcon {
    switch (agent) {
      case AgentType.Claude:
        return new vscode.ThemeIcon(
          "hubot",
          new vscode.ThemeColor("charts.orange"),
        );
      case AgentType.Codex:
        return new vscode.ThemeIcon(
          "code",
          new vscode.ThemeColor("charts.green"),
        );
      case AgentType.Gemini:
        return new vscode.ThemeIcon(
          "sparkle",
          new vscode.ThemeColor("charts.blue"),
        );
      default:
        return new vscode.ThemeIcon("robot");
    }
  }

  private formatDuration(seconds: number): string {
    if (seconds < 60) {
      return `${Math.round(seconds)}s`;
    } else if (seconds < 3600) {
      return `${Math.round(seconds / 60)}m`;
    } else {
      return `${(seconds / 3600).toFixed(1)}h`;
    }
  }
}

export class CostTreeItem extends vscode.TreeItem {
  public categoryId?: string;

  constructor(
    public readonly label: string,
    public readonly collapsibleState: vscode.TreeItemCollapsibleState,
    public contextValue: string,
    categoryId?: string,
  ) {
    super(label, collapsibleState);
    this.categoryId = categoryId;
  }
}
