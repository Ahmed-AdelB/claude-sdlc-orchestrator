/**
 * Tri-Agent VS Code Extension
 * Main entry point for the extension
 *
 * Author: Ahmed Adel Bakr Alderai
 */

import * as vscode from "vscode";
import { registerCommands } from "./commands";
import { TriAgentCompletionProvider } from "./providers/completionProvider";
import { AgentPanelProvider } from "./views/agentPanel";
import { TaskTreeProvider } from "./views/taskTreeProvider";
import { CostTreeProvider } from "./views/costTreeProvider";
import { TriAgentCodeActionProvider } from "./providers/codeActionProvider";
import { StatusBarManager } from "./utils/statusBar";
import { AgentManager } from "./utils/agentManager";
import { Logger } from "./utils/logger";

let agentManager: AgentManager;
let statusBarManager: StatusBarManager;
let logger: Logger;

export async function activate(
  context: vscode.ExtensionContext,
): Promise<void> {
  logger = new Logger("Tri-Agent");
  logger.info("Activating Tri-Agent extension...");

  try {
    // Initialize core managers
    agentManager = new AgentManager(context);
    statusBarManager = new StatusBarManager();

    // Register all commands
    registerCommands(context, agentManager, statusBarManager);

    // Register completion provider for IntelliSense
    const completionProvider = new TriAgentCompletionProvider(agentManager);
    context.subscriptions.push(
      vscode.languages.registerCompletionItemProvider(
        { scheme: "file", pattern: "**/*" },
        completionProvider,
        "/",
        "@",
        "#",
      ),
    );

    // Register code action provider
    const codeActionProvider = new TriAgentCodeActionProvider(agentManager);
    context.subscriptions.push(
      vscode.languages.registerCodeActionsProvider(
        { scheme: "file", pattern: "**/*" },
        codeActionProvider,
        {
          providedCodeActionKinds:
            TriAgentCodeActionProvider.providedCodeActionKinds,
        },
      ),
    );

    // Register webview panel provider for agent status
    const agentPanelProvider = new AgentPanelProvider(
      context.extensionUri,
      agentManager,
    );
    context.subscriptions.push(
      vscode.window.registerWebviewViewProvider(
        "triAgentStatus",
        agentPanelProvider,
      ),
    );

    // Register tree data providers
    const taskTreeProvider = new TaskTreeProvider(agentManager);
    context.subscriptions.push(
      vscode.window.registerTreeDataProvider("triAgentTasks", taskTreeProvider),
    );

    const costTreeProvider = new CostTreeProvider(agentManager);
    context.subscriptions.push(
      vscode.window.registerTreeDataProvider("triAgentCosts", costTreeProvider),
    );

    // Initialize status bar
    statusBarManager.initialize(context);

    // Start auto-refresh for status updates
    const config = vscode.workspace.getConfiguration("triAgent");
    const refreshInterval =
      config.get<number>("autoRefreshInterval", 30) * 1000;

    const refreshTimer = setInterval(() => {
      agentPanelProvider.refresh();
      taskTreeProvider.refresh();
      costTreeProvider.refresh();
      statusBarManager.update(agentManager.getStatus());
    }, refreshInterval);

    context.subscriptions.push({
      dispose: () => clearInterval(refreshTimer),
    });

    // Verify CLI tools are available
    await verifyCliTools();

    logger.info("Tri-Agent extension activated successfully");
    vscode.window.showInformationMessage("Tri-Agent extension activated");
  } catch (error) {
    logger.error("Failed to activate Tri-Agent extension", error);
    vscode.window.showErrorMessage(`Tri-Agent activation failed: ${error}`);
  }
}

export function deactivate(): void {
  logger?.info("Deactivating Tri-Agent extension...");

  if (agentManager) {
    agentManager.dispose();
  }

  if (statusBarManager) {
    statusBarManager.dispose();
  }

  logger?.info("Tri-Agent extension deactivated");
}

async function verifyCliTools(): Promise<void> {
  const config = vscode.workspace.getConfiguration("triAgent");

  const tools = [
    { name: "Claude", path: config.get<string>("claudePath", "claude") },
    { name: "Codex", path: config.get<string>("codexPath", "codex") },
    { name: "Gemini", path: config.get<string>("geminiPath", "gemini") },
  ];

  const missingTools: string[] = [];

  for (const tool of tools) {
    try {
      const { exec } = require("child_process");
      await new Promise<void>((resolve, reject) => {
        exec(`which ${tool.path}`, (error: Error | null) => {
          if (error) {
            missingTools.push(tool.name);
          }
          resolve();
        });
      });
    } catch {
      missingTools.push(tool.name);
    }
  }

  if (missingTools.length > 0) {
    const message = `Some CLI tools not found: ${missingTools.join(", ")}. Some features may be limited.`;
    logger.warn(message);
    vscode.window.showWarningMessage(message);
  }
}

// Export for testing
export { agentManager, statusBarManager, logger };
