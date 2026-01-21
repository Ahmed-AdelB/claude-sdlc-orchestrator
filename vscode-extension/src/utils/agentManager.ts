/**
 * Tri-Agent VS Code Extension - Agent Manager
 * Manages agent state, tasks, and coordination
 *
 * Author: Ahmed Adel Bakr Alderai
 */

import * as vscode from "vscode";
import { ChildProcess } from "child_process";

export enum AgentType {
  Claude = "Claude",
  Codex = "Codex",
  Gemini = "Gemini",
  Multi = "Multi",
}

export enum TaskStatus {
  Pending = "Pending",
  InProgress = "In Progress",
  ReadyForVerify = "Ready for Verify",
  Verified = "Verified",
  Completed = "Completed",
  Failed = "Failed",
  Cancelled = "Cancelled",
  Blocked = "Blocked",
}

export interface AgentStatus {
  available: boolean;
  busy: boolean;
  lastActive?: Date;
  currentTask?: string;
  errorCount: number;
}

export interface Task {
  id: string;
  type: string;
  description: string;
  agent: AgentType;
  file?: string;
  status: TaskStatus;
  createdAt: Date;
  startedAt?: Date;
  completedAt?: Date;
  cost?: number;
  tokens?: number;
  result?: string;
  error?: string;
  process?: ChildProcess;
}

export interface TaskInput {
  type: string;
  description: string;
  agent: AgentType;
  file?: string;
}

export interface Metrics {
  completed: number;
  failed: number;
  avgDuration: number;
  totalCost: number;
  totalTokens: number;
}

export class AgentManager {
  private context: vscode.ExtensionContext;
  private tasks: Map<string, Task> = new Map();
  private agentStatus: Map<AgentType, AgentStatus> = new Map();
  private taskCounter: number = 0;
  private dailyCostReset: Date = new Date();
  private dailyCost: number = 0;

  // Cost per 1K tokens (estimates)
  private readonly costRates: Record<
    AgentType,
    { input: number; output: number }
  > = {
    [AgentType.Claude]: { input: 0.015, output: 0.075 }, // Opus pricing
    [AgentType.Codex]: { input: 0.005, output: 0.015 }, // GPT-5 pricing
    [AgentType.Gemini]: { input: 0.001, output: 0.002 }, // Gemini Pro pricing
    [AgentType.Multi]: { input: 0.021, output: 0.092 }, // Combined
  };

  constructor(context: vscode.ExtensionContext) {
    this.context = context;
    this.initializeAgents();
    this.loadPersistedState();
  }

  private initializeAgents(): void {
    const agents = [AgentType.Claude, AgentType.Codex, AgentType.Gemini];

    for (const agent of agents) {
      this.agentStatus.set(agent, {
        available: true,
        busy: false,
        errorCount: 0,
      });
    }
  }

  private loadPersistedState(): void {
    const savedTasks = this.context.globalState.get<string>("triAgent.tasks");
    const savedDailyCost =
      this.context.globalState.get<number>("triAgent.dailyCost");
    const savedCostDate = this.context.globalState.get<string>(
      "triAgent.dailyCostDate",
    );

    if (savedTasks) {
      try {
        const tasks = JSON.parse(savedTasks);
        for (const task of tasks) {
          // Restore task with Date objects
          task.createdAt = new Date(task.createdAt);
          if (task.startedAt) task.startedAt = new Date(task.startedAt);
          if (task.completedAt) task.completedAt = new Date(task.completedAt);
          this.tasks.set(task.id, task);
        }
      } catch (error) {
        console.error("Failed to load persisted tasks:", error);
      }
    }

    // Reset daily cost if it's a new day
    const today = new Date().toDateString();
    if (savedCostDate !== today) {
      this.dailyCost = 0;
      this.dailyCostReset = new Date();
    } else if (savedDailyCost) {
      this.dailyCost = savedDailyCost;
    }
  }

  private persistState(): void {
    const tasksArray = Array.from(this.tasks.values()).map((task) => ({
      ...task,
      process: undefined, // Don't persist process handles
    }));

    this.context.globalState.update(
      "triAgent.tasks",
      JSON.stringify(tasksArray),
    );
    this.context.globalState.update("triAgent.dailyCost", this.dailyCost);
    this.context.globalState.update(
      "triAgent.dailyCostDate",
      new Date().toDateString(),
    );
  }

  createTask(input: TaskInput): string {
    const id = `T-${String(++this.taskCounter).padStart(3, "0")}`;

    const task: Task = {
      id,
      type: input.type,
      description: input.description,
      agent: input.agent,
      file: input.file,
      status: TaskStatus.Pending,
      createdAt: new Date(),
    };

    this.tasks.set(id, task);

    // Update agent status
    if (input.agent !== AgentType.Multi) {
      const status = this.agentStatus.get(input.agent);
      if (status) {
        status.busy = true;
        status.currentTask = id;
      }
    }

    this.persistState();
    return id;
  }

  updateTaskStatus(taskId: string, status: TaskStatus): void {
    const task = this.tasks.get(taskId);
    if (!task) return;

    task.status = status;

    if (status === TaskStatus.InProgress && !task.startedAt) {
      task.startedAt = new Date();
    }

    if (status === TaskStatus.Completed || status === TaskStatus.Failed) {
      task.completedAt = new Date();

      // Update agent status
      if (task.agent !== AgentType.Multi) {
        const agentStatus = this.agentStatus.get(task.agent);
        if (agentStatus) {
          agentStatus.busy = false;
          agentStatus.currentTask = undefined;
          agentStatus.lastActive = new Date();

          if (status === TaskStatus.Failed) {
            agentStatus.errorCount++;
          }
        }
      }

      // Calculate estimated cost
      if (task.tokens) {
        const rates = this.costRates[task.agent];
        task.cost = ((task.tokens / 1000) * (rates.input + rates.output)) / 2;
        this.dailyCost += task.cost;
      }
    }

    this.persistState();
  }

  setTaskProcess(taskId: string, process: ChildProcess): void {
    const task = this.tasks.get(taskId);
    if (task) {
      task.process = process;
    }
  }

  cancelTask(taskId: string): void {
    const task = this.tasks.get(taskId);
    if (!task) return;

    // Kill process if running
    if (task.process && !task.process.killed) {
      task.process.kill("SIGTERM");
    }

    task.status = TaskStatus.Cancelled;
    task.completedAt = new Date();

    // Update agent status
    if (task.agent !== AgentType.Multi) {
      const agentStatus = this.agentStatus.get(task.agent);
      if (agentStatus && agentStatus.currentTask === taskId) {
        agentStatus.busy = false;
        agentStatus.currentTask = undefined;
      }
    }

    this.persistState();
  }

  getTask(taskId: string): Task | undefined {
    return this.tasks.get(taskId);
  }

  getActiveTasks(): Task[] {
    return Array.from(this.tasks.values()).filter(
      (task) =>
        task.status === TaskStatus.Pending ||
        task.status === TaskStatus.InProgress ||
        task.status === TaskStatus.ReadyForVerify,
    );
  }

  getRecentTasks(limit: number = 10): Task[] {
    return Array.from(this.tasks.values())
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
      .slice(0, limit);
  }

  getAgentStatus(agent: AgentType): AgentStatus {
    return (
      this.agentStatus.get(agent) || {
        available: false,
        busy: false,
        errorCount: 0,
      }
    );
  }

  getTaskCount(agent: AgentType, status?: TaskStatus): number {
    return Array.from(this.tasks.values()).filter((task) => {
      const matchesAgent = task.agent === agent || agent === AgentType.Multi;
      const matchesStatus = !status || task.status === status;
      return matchesAgent && matchesStatus;
    }).length;
  }

  getDailyCost(): number {
    // Reset if it's a new day
    const today = new Date().toDateString();
    if (this.dailyCostReset.toDateString() !== today) {
      this.dailyCost = 0;
      this.dailyCostReset = new Date();
      this.persistState();
    }
    return this.dailyCost;
  }

  getMetrics(): Metrics {
    const tasks = Array.from(this.tasks.values());
    const completed = tasks.filter((t) => t.status === TaskStatus.Completed);
    const failed = tasks.filter((t) => t.status === TaskStatus.Failed);

    let totalDuration = 0;
    for (const task of completed) {
      if (task.startedAt && task.completedAt) {
        totalDuration += task.completedAt.getTime() - task.startedAt.getTime();
      }
    }

    const avgDuration =
      completed.length > 0 ? totalDuration / completed.length / 1000 : 0;

    const totalCost = tasks.reduce((sum, t) => sum + (t.cost || 0), 0);
    const totalTokens = tasks.reduce((sum, t) => sum + (t.tokens || 0), 0);

    return {
      completed: completed.length,
      failed: failed.length,
      avgDuration,
      totalCost,
      totalTokens,
    };
  }

  getStatus(): {
    activeTasks: number;
    claudeStatus: AgentStatus;
    codexStatus: AgentStatus;
    geminiStatus: AgentStatus;
    dailyCost: number;
  } {
    return {
      activeTasks: this.getActiveTasks().length,
      claudeStatus: this.getAgentStatus(AgentType.Claude),
      codexStatus: this.getAgentStatus(AgentType.Codex),
      geminiStatus: this.getAgentStatus(AgentType.Gemini),
      dailyCost: this.getDailyCost(),
    };
  }

  dispose(): void {
    // Cancel all active tasks
    for (const task of this.getActiveTasks()) {
      this.cancelTask(task.id);
    }
    this.persistState();
  }
}
