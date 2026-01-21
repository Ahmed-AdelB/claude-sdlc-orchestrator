/**
 * Tri-Agent VS Code Extension - Agent Panel Webview
 * Displays agent status, tasks, and metrics in sidebar
 *
 * Author: Ahmed Adel Bakr Alderai
 */

import * as vscode from "vscode";
import {
  AgentManager,
  AgentType,
  AgentStatus,
  Task,
  TaskStatus,
} from "../utils/agentManager";

export class AgentPanelProvider implements vscode.WebviewViewProvider {
  public static readonly viewType = "triAgentStatus";

  private _view?: vscode.WebviewView;
  private _extensionUri: vscode.Uri;
  private _agentManager: AgentManager;

  constructor(extensionUri: vscode.Uri, agentManager: AgentManager) {
    this._extensionUri = extensionUri;
    this._agentManager = agentManager;
  }

  public resolveWebviewView(
    webviewView: vscode.WebviewView,
    context: vscode.WebviewViewResolveContext,
    _token: vscode.CancellationToken,
  ): void {
    this._view = webviewView;

    webviewView.webview.options = {
      enableScripts: true,
      localResourceRoots: [this._extensionUri],
    };

    webviewView.webview.html = this._getHtmlForWebview(webviewView.webview);

    // Handle messages from webview
    webviewView.webview.onDidReceiveMessage(async (data) => {
      switch (data.type) {
        case "refresh":
          this.refresh();
          break;
        case "cancelTask":
          this._agentManager.cancelTask(data.taskId);
          this.refresh();
          break;
        case "selectAgent":
          await vscode.commands.executeCommand(`triAgent.select${data.agent}`);
          break;
        case "openSettings":
          await vscode.commands.executeCommand(
            "workbench.action.openSettings",
            "triAgent",
          );
          break;
        case "viewLogs":
          await vscode.commands.executeCommand("triAgent.viewLogs");
          break;
      }
    });

    // Initial update
    this.refresh();
  }

  public refresh(): void {
    if (this._view) {
      this._view.webview.postMessage({
        type: "update",
        data: this._getStatusData(),
      });
    }
  }

  private _getStatusData(): {
    agents: Array<{
      name: string;
      type: AgentType;
      status: AgentStatus;
      tasksCompleted: number;
      tasksActive: number;
    }>;
    tasks: Task[];
    metrics: {
      dailyCost: number;
      budgetUsed: number;
      tasksCompleted: number;
      tasksFailed: number;
      avgDuration: number;
    };
  } {
    const agents = [
      {
        name: "Claude",
        type: AgentType.Claude,
        status: this._agentManager.getAgentStatus(AgentType.Claude),
        tasksCompleted: this._agentManager.getTaskCount(
          AgentType.Claude,
          TaskStatus.Completed,
        ),
        tasksActive: this._agentManager.getTaskCount(
          AgentType.Claude,
          TaskStatus.InProgress,
        ),
      },
      {
        name: "Codex",
        type: AgentType.Codex,
        status: this._agentManager.getAgentStatus(AgentType.Codex),
        tasksCompleted: this._agentManager.getTaskCount(
          AgentType.Codex,
          TaskStatus.Completed,
        ),
        tasksActive: this._agentManager.getTaskCount(
          AgentType.Codex,
          TaskStatus.InProgress,
        ),
      },
      {
        name: "Gemini",
        type: AgentType.Gemini,
        status: this._agentManager.getAgentStatus(AgentType.Gemini),
        tasksCompleted: this._agentManager.getTaskCount(
          AgentType.Gemini,
          TaskStatus.Completed,
        ),
        tasksActive: this._agentManager.getTaskCount(
          AgentType.Gemini,
          TaskStatus.InProgress,
        ),
      },
    ];

    const dailyCost = this._agentManager.getDailyCost();
    const metrics = this._agentManager.getMetrics();

    return {
      agents,
      tasks: this._agentManager.getActiveTasks(),
      metrics: {
        dailyCost,
        budgetUsed: (dailyCost / 42) * 100, // $42/day budget
        tasksCompleted: metrics.completed,
        tasksFailed: metrics.failed,
        avgDuration: metrics.avgDuration,
      },
    };
  }

  private _getHtmlForWebview(webview: vscode.Webview): string {
    const nonce = getNonce();

    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src ${webview.cspSource} 'unsafe-inline'; script-src 'nonce-${nonce}';">
    <title>Tri-Agent Status</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: var(--vscode-font-family);
            font-size: var(--vscode-font-size);
            color: var(--vscode-foreground);
            background-color: var(--vscode-sideBar-background);
            padding: 12px;
        }

        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 16px;
            padding-bottom: 8px;
            border-bottom: 1px solid var(--vscode-panel-border);
        }

        .header h1 {
            font-size: 14px;
            font-weight: 600;
        }

        .header-actions {
            display: flex;
            gap: 8px;
        }

        .icon-btn {
            background: transparent;
            border: none;
            color: var(--vscode-foreground);
            cursor: pointer;
            padding: 4px;
            border-radius: 4px;
        }

        .icon-btn:hover {
            background: var(--vscode-toolbar-hoverBackground);
        }

        .section {
            margin-bottom: 20px;
        }

        .section-title {
            font-size: 11px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: var(--vscode-sideBarSectionHeader-foreground);
            margin-bottom: 8px;
        }

        .agent-card {
            display: flex;
            align-items: center;
            padding: 8px;
            margin-bottom: 6px;
            background: var(--vscode-editor-background);
            border-radius: 4px;
            cursor: pointer;
            transition: background 0.15s;
        }

        .agent-card:hover {
            background: var(--vscode-list-hoverBackground);
        }

        .agent-icon {
            width: 32px;
            height: 32px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: bold;
            font-size: 12px;
            margin-right: 10px;
        }

        .agent-icon.claude {
            background: linear-gradient(135deg, #d97706 0%, #f59e0b 100%);
            color: white;
        }

        .agent-icon.codex {
            background: linear-gradient(135deg, #10a37f 0%, #2dd4bf 100%);
            color: white;
        }

        .agent-icon.gemini {
            background: linear-gradient(135deg, #4285f4 0%, #8ab4f8 100%);
            color: white;
        }

        .agent-info {
            flex: 1;
        }

        .agent-name {
            font-weight: 500;
            font-size: 13px;
        }

        .agent-stats {
            font-size: 11px;
            color: var(--vscode-descriptionForeground);
        }

        .agent-status {
            width: 8px;
            height: 8px;
            border-radius: 50%;
        }

        .agent-status.available {
            background: #22c55e;
            box-shadow: 0 0 6px #22c55e;
        }

        .agent-status.busy {
            background: #f59e0b;
            box-shadow: 0 0 6px #f59e0b;
        }

        .agent-status.offline {
            background: #ef4444;
            box-shadow: 0 0 6px #ef4444;
        }

        .metrics-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 8px;
        }

        .metric-card {
            background: var(--vscode-editor-background);
            padding: 10px;
            border-radius: 4px;
        }

        .metric-value {
            font-size: 18px;
            font-weight: 600;
            color: var(--vscode-foreground);
        }

        .metric-label {
            font-size: 10px;
            color: var(--vscode-descriptionForeground);
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }

        .budget-bar {
            height: 4px;
            background: var(--vscode-progressBar-background);
            border-radius: 2px;
            margin-top: 4px;
            overflow: hidden;
        }

        .budget-fill {
            height: 100%;
            border-radius: 2px;
            transition: width 0.3s ease;
        }

        .budget-fill.safe {
            background: #22c55e;
        }

        .budget-fill.warning {
            background: #f59e0b;
        }

        .budget-fill.danger {
            background: #ef4444;
        }

        .task-list {
            max-height: 200px;
            overflow-y: auto;
        }

        .task-item {
            display: flex;
            align-items: center;
            padding: 8px;
            margin-bottom: 4px;
            background: var(--vscode-editor-background);
            border-radius: 4px;
            font-size: 12px;
        }

        .task-status-dot {
            width: 6px;
            height: 6px;
            border-radius: 50%;
            margin-right: 8px;
        }

        .task-status-dot.pending {
            background: var(--vscode-descriptionForeground);
        }

        .task-status-dot.in-progress {
            background: #3b82f6;
            animation: pulse 1.5s infinite;
        }

        .task-status-dot.completed {
            background: #22c55e;
        }

        .task-status-dot.failed {
            background: #ef4444;
        }

        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }

        .task-info {
            flex: 1;
            overflow: hidden;
        }

        .task-description {
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }

        .task-agent {
            font-size: 10px;
            color: var(--vscode-descriptionForeground);
        }

        .task-cancel {
            background: transparent;
            border: none;
            color: var(--vscode-errorForeground);
            cursor: pointer;
            padding: 4px;
            opacity: 0;
            transition: opacity 0.15s;
        }

        .task-item:hover .task-cancel {
            opacity: 1;
        }

        .empty-state {
            text-align: center;
            padding: 20px;
            color: var(--vscode-descriptionForeground);
            font-size: 12px;
        }

        .quick-actions {
            display: flex;
            gap: 6px;
            flex-wrap: wrap;
        }

        .quick-action-btn {
            background: var(--vscode-button-secondaryBackground);
            color: var(--vscode-button-secondaryForeground);
            border: none;
            padding: 6px 10px;
            border-radius: 4px;
            font-size: 11px;
            cursor: pointer;
            transition: background 0.15s;
        }

        .quick-action-btn:hover {
            background: var(--vscode-button-secondaryHoverBackground);
        }

        .quick-action-btn.primary {
            background: var(--vscode-button-background);
            color: var(--vscode-button-foreground);
        }

        .quick-action-btn.primary:hover {
            background: var(--vscode-button-hoverBackground);
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>Tri-Agent</h1>
        <div class="header-actions">
            <button class="icon-btn" onclick="openSettings()" title="Settings">
                <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
                    <path d="M9.1 4.4L8.6 2H7.4l-.5 2.4-.7.3-2-1.3-.9.8 1.3 2-.2.7-2.4.5v1.2l2.4.5.3.8-1.3 2 .8.8 2-1.3.8.3.4 2.3h1.2l.5-2.4.8-.3 2 1.3.8-.8-1.3-2 .3-.8 2.3-.4V7.4l-2.4-.5-.3-.8 1.3-2-.8-.8-2 1.3-.7-.2zM9.4 1l.5 2.4L12 2.1l2 2-1.4 2.1 2.4.4v2.8l-2.4.5L14 12l-2 2-2.1-1.4-.5 2.4H6.6l-.5-2.4L4 13.9l-2-2 1.4-2.1L1 9.4V6.6l2.4-.5L2.1 4l2-2 2.1 1.4.4-2.4h2.8zm.6 7c0 1.1-.9 2-2 2s-2-.9-2-2 .9-2 2-2 2 .9 2 2zM8 9c.6 0 1-.4 1-1s-.4-1-1-1-1 .4-1 1 .4 1 1 1z"/>
                </svg>
            </button>
            <button class="icon-btn" onclick="refresh()" title="Refresh">
                <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
                    <path d="M13.451 5.609l-.579-.939-1.068.812-.076.094c-.335.415-.927 1.341-.927 2.424 0 2.206-1.794 4-4 4-1.098 0-2.093-.445-2.813-1.163l-.057-.063-.061.054-1.128 1.01.065.072c.975 1.074 2.39 1.747 3.994 1.747 2.904 0 5.257-2.327 5.375-5.223l.014-.077h1.271l-1.896-2.756-.114.008zm-9.056-.7c.169-.21.505-.553.965-.825.378-.223.751-.414.914-.51l.115-.069.039-.103.39-1.016.173-.449-.444-.191-.187-.083c-.265-.117-.538-.161-.798-.161-.734 0-1.427.37-1.808.987l-.05.081-.036.088-.333.865L2.893 5.3l.5.223 1.002-.614zm.594 2.091l-.575-.939-1.068.812-.076.094c-.335.415-.927 1.341-.927 2.424 0 .636.25 1.23.685 1.681l.058.06.06-.053L4.273 10l-.065-.072c-.225-.248-.352-.573-.352-.928 0-.724.382-1.297.654-1.629l.025-.031.044-.053.411-.288zm3.012-3.563c-1.098 0-2.093.445-2.813 1.163l-.057.063.061-.054 1.128-1.01-.065-.072C7.23 2.454 8.645 1.78 10.249 1.78c2.904 0 5.257 2.328 5.375 5.224l.014.076h-1.271l1.896 2.757.114-.009v-.017l.579-.939-.568-.921-.119.009h-.762l-.014-.15c-.118-2.345-2.044-4.287-4.494-4.287z"/>
                </svg>
            </button>
        </div>
    </div>

    <div class="section">
        <div class="section-title">Agents</div>
        <div id="agents-container">
            <!-- Populated by JavaScript -->
        </div>
    </div>

    <div class="section">
        <div class="section-title">Metrics</div>
        <div class="metrics-grid">
            <div class="metric-card">
                <div class="metric-value" id="daily-cost">$0.00</div>
                <div class="metric-label">Today's Cost</div>
                <div class="budget-bar">
                    <div class="budget-fill safe" id="budget-bar" style="width: 0%"></div>
                </div>
            </div>
            <div class="metric-card">
                <div class="metric-value" id="tasks-completed">0</div>
                <div class="metric-label">Completed</div>
            </div>
            <div class="metric-card">
                <div class="metric-value" id="tasks-failed">0</div>
                <div class="metric-label">Failed</div>
            </div>
            <div class="metric-card">
                <div class="metric-value" id="avg-duration">0s</div>
                <div class="metric-label">Avg Duration</div>
            </div>
        </div>
    </div>

    <div class="section">
        <div class="section-title">Active Tasks</div>
        <div class="task-list" id="tasks-container">
            <div class="empty-state">No active tasks</div>
        </div>
    </div>

    <div class="section">
        <div class="section-title">Quick Actions</div>
        <div class="quick-actions">
            <button class="quick-action-btn primary" onclick="executeCommand('triAgent.secure')">Security</button>
            <button class="quick-action-btn" onclick="executeCommand('triAgent.testGen')">Tests</button>
            <button class="quick-action-btn" onclick="executeCommand('triAgent.review')">Review</button>
            <button class="quick-action-btn" onclick="executeCommand('triAgent.analyze')">Analyze</button>
        </div>
    </div>

    <script nonce="${nonce}">
        const vscode = acquireVsCodeApi();

        function refresh() {
            vscode.postMessage({ type: 'refresh' });
        }

        function openSettings() {
            vscode.postMessage({ type: 'openSettings' });
        }

        function cancelTask(taskId) {
            vscode.postMessage({ type: 'cancelTask', taskId });
        }

        function selectAgent(agent) {
            vscode.postMessage({ type: 'selectAgent', agent });
        }

        function executeCommand(command) {
            vscode.postMessage({ type: 'executeCommand', command });
        }

        function updateUI(data) {
            // Update agents
            const agentsContainer = document.getElementById('agents-container');
            agentsContainer.innerHTML = data.agents.map(agent => \`
                <div class="agent-card" onclick="selectAgent('\${agent.type}')">
                    <div class="agent-icon \${agent.type.toLowerCase()}">\${agent.name[0]}</div>
                    <div class="agent-info">
                        <div class="agent-name">\${agent.name}</div>
                        <div class="agent-stats">\${agent.tasksCompleted} completed, \${agent.tasksActive} active</div>
                    </div>
                    <div class="agent-status \${agent.status.available ? 'available' : (agent.status.busy ? 'busy' : 'offline')}"></div>
                </div>
            \`).join('');

            // Update metrics
            document.getElementById('daily-cost').textContent = '$' + data.metrics.dailyCost.toFixed(2);
            document.getElementById('tasks-completed').textContent = data.metrics.tasksCompleted;
            document.getElementById('tasks-failed').textContent = data.metrics.tasksFailed;
            document.getElementById('avg-duration').textContent = formatDuration(data.metrics.avgDuration);

            // Update budget bar
            const budgetBar = document.getElementById('budget-bar');
            const budgetPercent = Math.min(data.metrics.budgetUsed, 100);
            budgetBar.style.width = budgetPercent + '%';
            budgetBar.className = 'budget-fill ' + (budgetPercent > 90 ? 'danger' : (budgetPercent > 70 ? 'warning' : 'safe'));

            // Update tasks
            const tasksContainer = document.getElementById('tasks-container');
            if (data.tasks.length === 0) {
                tasksContainer.innerHTML = '<div class="empty-state">No active tasks</div>';
            } else {
                tasksContainer.innerHTML = data.tasks.map(task => \`
                    <div class="task-item">
                        <div class="task-status-dot \${task.status.toLowerCase().replace(' ', '-')}"></div>
                        <div class="task-info">
                            <div class="task-description">\${escapeHtml(task.description)}</div>
                            <div class="task-agent">\${task.agent}</div>
                        </div>
                        <button class="task-cancel" onclick="cancelTask('\${task.id}')" title="Cancel">
                            <svg width="12" height="12" viewBox="0 0 16 16" fill="currentColor">
                                <path d="M8 8.707l3.646 3.647.708-.707L8.707 8l3.647-3.646-.707-.708L8 7.293 4.354 3.646l-.707.708L7.293 8l-3.646 3.646.707.708L8 8.707z"/>
                            </svg>
                        </button>
                    </div>
                \`).join('');
            }
        }

        function formatDuration(seconds) {
            if (seconds < 60) return Math.round(seconds) + 's';
            if (seconds < 3600) return Math.round(seconds / 60) + 'm';
            return Math.round(seconds / 3600) + 'h';
        }

        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }

        // Listen for messages from extension
        window.addEventListener('message', event => {
            const message = event.data;
            if (message.type === 'update') {
                updateUI(message.data);
            }
        });

        // Request initial data
        refresh();
    </script>
</body>
</html>`;
  }
}

function getNonce(): string {
  let text = "";
  const possible =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  for (let i = 0; i < 32; i++) {
    text += possible.charAt(Math.floor(Math.random() * possible.length));
  }
  return text;
}
