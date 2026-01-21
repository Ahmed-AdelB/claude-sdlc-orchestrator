/**
 * Tri-Agent VS Code Extension - Task Tree Provider
 * Provides tree view for active and recent tasks
 *
 * Author: Ahmed Adel Bakr Alderai
 */

import * as vscode from "vscode";
import {
  AgentManager,
  Task,
  TaskStatus,
  AgentType,
} from "../utils/agentManager";

export class TaskTreeProvider implements vscode.TreeDataProvider<TaskTreeItem> {
  private _onDidChangeTreeData: vscode.EventEmitter<
    TaskTreeItem | undefined | null | void
  > = new vscode.EventEmitter<TaskTreeItem | undefined | null | void>();
  readonly onDidChangeTreeData: vscode.Event<
    TaskTreeItem | undefined | null | void
  > = this._onDidChangeTreeData.event;

  private agentManager: AgentManager;

  constructor(agentManager: AgentManager) {
    this.agentManager = agentManager;
  }

  refresh(): void {
    this._onDidChangeTreeData.fire();
  }

  getTreeItem(element: TaskTreeItem): vscode.TreeItem {
    return element;
  }

  getChildren(element?: TaskTreeItem): Thenable<TaskTreeItem[]> {
    if (!element) {
      // Root level - show categories
      return Promise.resolve([
        new TaskTreeItem(
          "Active Tasks",
          vscode.TreeItemCollapsibleState.Expanded,
          "category",
          "active",
        ),
        new TaskTreeItem(
          "Recent Tasks",
          vscode.TreeItemCollapsibleState.Collapsed,
          "category",
          "recent",
        ),
      ]);
    }

    if (element.contextValue === "category") {
      if (element.categoryId === "active") {
        const activeTasks = this.agentManager.getActiveTasks();
        return Promise.resolve(
          activeTasks.map((task) => this.createTaskItem(task)),
        );
      } else if (element.categoryId === "recent") {
        const recentTasks = this.agentManager
          .getRecentTasks(10)
          .filter(
            (t) =>
              t.status === TaskStatus.Completed ||
              t.status === TaskStatus.Failed ||
              t.status === TaskStatus.Cancelled,
          );
        return Promise.resolve(
          recentTasks.map((task) => this.createTaskItem(task)),
        );
      }
    }

    return Promise.resolve([]);
  }

  private createTaskItem(task: Task): TaskTreeItem {
    const item = new TaskTreeItem(
      task.description,
      vscode.TreeItemCollapsibleState.None,
      "task",
      task.id,
    );

    item.task = task;
    item.description = `${task.agent} - ${task.status}`;
    item.tooltip = this.createTaskTooltip(task);
    item.iconPath = this.getTaskIcon(task);

    // Add context menu based on status
    if (
      task.status === TaskStatus.InProgress ||
      task.status === TaskStatus.Pending
    ) {
      item.contextValue = "activeTask";
    } else {
      item.contextValue = "completedTask";
    }

    return item;
  }

  private createTaskTooltip(task: Task): vscode.MarkdownString {
    const tooltip = new vscode.MarkdownString();
    tooltip.appendMarkdown(`### ${task.description}\n\n`);
    tooltip.appendMarkdown(`**ID:** ${task.id}\n\n`);
    tooltip.appendMarkdown(`**Type:** ${task.type}\n\n`);
    tooltip.appendMarkdown(`**Agent:** ${task.agent}\n\n`);
    tooltip.appendMarkdown(`**Status:** ${task.status}\n\n`);

    if (task.file) {
      tooltip.appendMarkdown(`**File:** ${task.file}\n\n`);
    }

    tooltip.appendMarkdown(
      `**Created:** ${task.createdAt.toLocaleString()}\n\n`,
    );

    if (task.startedAt) {
      tooltip.appendMarkdown(
        `**Started:** ${task.startedAt.toLocaleString()}\n\n`,
      );
    }

    if (task.completedAt) {
      tooltip.appendMarkdown(
        `**Completed:** ${task.completedAt.toLocaleString()}\n\n`,
      );

      // Calculate duration
      if (task.startedAt) {
        const duration = Math.round(
          (task.completedAt.getTime() - task.startedAt.getTime()) / 1000,
        );
        tooltip.appendMarkdown(`**Duration:** ${duration}s\n\n`);
      }
    }

    if (task.cost) {
      tooltip.appendMarkdown(`**Cost:** $${task.cost.toFixed(4)}\n\n`);
    }

    if (task.error) {
      tooltip.appendMarkdown(`**Error:** ${task.error}\n\n`);
    }

    return tooltip;
  }

  private getTaskIcon(task: Task): vscode.ThemeIcon {
    switch (task.status) {
      case TaskStatus.Pending:
        return new vscode.ThemeIcon(
          "circle-outline",
          new vscode.ThemeColor("charts.gray"),
        );
      case TaskStatus.InProgress:
        return new vscode.ThemeIcon(
          "loading~spin",
          new vscode.ThemeColor("charts.blue"),
        );
      case TaskStatus.ReadyForVerify:
        return new vscode.ThemeIcon(
          "eye",
          new vscode.ThemeColor("charts.yellow"),
        );
      case TaskStatus.Verified:
        return new vscode.ThemeIcon(
          "check-all",
          new vscode.ThemeColor("charts.green"),
        );
      case TaskStatus.Completed:
        return new vscode.ThemeIcon(
          "pass",
          new vscode.ThemeColor("charts.green"),
        );
      case TaskStatus.Failed:
        return new vscode.ThemeIcon(
          "error",
          new vscode.ThemeColor("charts.red"),
        );
      case TaskStatus.Cancelled:
        return new vscode.ThemeIcon(
          "close",
          new vscode.ThemeColor("charts.gray"),
        );
      case TaskStatus.Blocked:
        return new vscode.ThemeIcon(
          "warning",
          new vscode.ThemeColor("charts.orange"),
        );
      default:
        return new vscode.ThemeIcon("circle-outline");
    }
  }
}

export class TaskTreeItem extends vscode.TreeItem {
  public task?: Task;
  public categoryId?: string;

  constructor(
    public readonly label: string,
    public readonly collapsibleState: vscode.TreeItemCollapsibleState,
    public contextValue: string,
    public readonly itemId?: string,
  ) {
    super(label, collapsibleState);
    this.categoryId = itemId;

    if (contextValue === "category") {
      this.iconPath =
        itemId === "active"
          ? new vscode.ThemeIcon("sync")
          : new vscode.ThemeIcon("history");
    }
  }
}
