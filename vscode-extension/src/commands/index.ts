/**
 * Tri-Agent VS Code Extension - Command Implementations
 *
 * Author: Ahmed Adel Bakr Alderai
 */

import * as vscode from "vscode";
import { exec, spawn, ChildProcess } from "child_process";
import { promisify } from "util";
import { AgentManager, AgentType, TaskStatus } from "../utils/agentManager";
import { StatusBarManager } from "../utils/statusBar";
import { CostEstimator, TaskType } from "../utils/costEstimator";

const execAsync = promisify(exec);

interface CommandContext {
  agentManager: AgentManager;
  statusBarManager: StatusBarManager;
  costEstimator: CostEstimator;
}

let context: CommandContext;

export function registerCommands(
  extensionContext: vscode.ExtensionContext,
  agentManager: AgentManager,
  statusBarManager: StatusBarManager,
): void {
  context = {
    agentManager,
    statusBarManager,
    costEstimator: new CostEstimator(),
  };

  const commands: Array<{
    id: string;
    handler: (...args: unknown[]) => Promise<void>;
  }> = [
    { id: "triAgent.secure", handler: secureCommand },
    { id: "triAgent.testGen", handler: testGenCommand },
    { id: "triAgent.review", handler: reviewCommand },
    { id: "triAgent.analyze", handler: analyzeCommand },
    { id: "triAgent.implement", handler: implementCommand },
    { id: "triAgent.refactor", handler: refactorCommand },
    { id: "triAgent.explain", handler: explainCommand },
    { id: "triAgent.showPanel", handler: showPanelCommand },
    { id: "triAgent.showCostEstimate", handler: showCostEstimateCommand },
    { id: "triAgent.cancelTask", handler: cancelTaskCommand },
    { id: "triAgent.viewLogs", handler: viewLogsCommand },
    { id: "triAgent.refreshStatus", handler: refreshStatusCommand },
  ];

  for (const cmd of commands) {
    const disposable = vscode.commands.registerCommand(cmd.id, cmd.handler);
    extensionContext.subscriptions.push(disposable);
  }
}

/**
 * Security Review Command (/secure)
 * Uses Claude Opus for thorough security analysis
 */
async function secureCommand(): Promise<void> {
  const editor = vscode.window.activeTextEditor;
  if (!editor) {
    vscode.window.showWarningMessage("No active editor found");
    return;
  }

  const selection = editor.selection;
  const code = selection.isEmpty
    ? editor.document.getText()
    : editor.document.getText(selection);

  if (!code.trim()) {
    vscode.window.showWarningMessage("No code to analyze");
    return;
  }

  const config = vscode.workspace.getConfiguration("triAgent");
  if (config.get<boolean>("showCostEstimates", true)) {
    const estimate = context.costEstimator.estimate(
      TaskType.Security,
      code.length,
    );
    const proceed = await vscode.window.showInformationMessage(
      `Estimated cost: $${estimate.cost.toFixed(4)} (${estimate.tokens} tokens)`,
      "Proceed",
      "Cancel",
    );
    if (proceed !== "Proceed") {
      return;
    }
  }

  const taskId = context.agentManager.createTask({
    type: "security",
    description: "Security review",
    agent: AgentType.Claude,
    file: editor.document.fileName,
  });

  context.statusBarManager.showProgress("Running security review...");

  try {
    const prompt = buildSecurityPrompt(code, editor.document.languageId);
    const result = await executeClaudeCommand(prompt, taskId);

    context.agentManager.updateTaskStatus(taskId, TaskStatus.Completed);
    showResultPanel("Security Review", result);
  } catch (error) {
    context.agentManager.updateTaskStatus(taskId, TaskStatus.Failed);
    vscode.window.showErrorMessage(`Security review failed: ${error}`);
  } finally {
    context.statusBarManager.hideProgress();
  }
}

/**
 * Test Generation Command (/test-gen)
 * Uses Codex for rapid test generation
 */
async function testGenCommand(): Promise<void> {
  const editor = vscode.window.activeTextEditor;
  if (!editor) {
    vscode.window.showWarningMessage("No active editor found");
    return;
  }

  const selection = editor.selection;
  const code = selection.isEmpty
    ? editor.document.getText()
    : editor.document.getText(selection);

  if (!code.trim()) {
    vscode.window.showWarningMessage("No code to generate tests for");
    return;
  }

  const testFramework = await vscode.window.showQuickPick(
    ["jest", "mocha", "pytest", "vitest", "playwright", "cypress"],
    { placeHolder: "Select test framework" },
  );

  if (!testFramework) {
    return;
  }

  const config = vscode.workspace.getConfiguration("triAgent");
  if (config.get<boolean>("showCostEstimates", true)) {
    const estimate = context.costEstimator.estimate(
      TaskType.TestGen,
      code.length,
    );
    const proceed = await vscode.window.showInformationMessage(
      `Estimated cost: $${estimate.cost.toFixed(4)} (${estimate.tokens} tokens)`,
      "Proceed",
      "Cancel",
    );
    if (proceed !== "Proceed") {
      return;
    }
  }

  const taskId = context.agentManager.createTask({
    type: "test-gen",
    description: `Generate ${testFramework} tests`,
    agent: AgentType.Codex,
    file: editor.document.fileName,
  });

  context.statusBarManager.showProgress("Generating tests...");

  try {
    const prompt = buildTestGenPrompt(
      code,
      editor.document.languageId,
      testFramework,
    );
    const result = await executeCodexCommand(prompt, taskId);

    context.agentManager.updateTaskStatus(taskId, TaskStatus.Completed);
    await insertTestCode(result, editor.document.fileName, testFramework);
  } catch (error) {
    context.agentManager.updateTaskStatus(taskId, TaskStatus.Failed);
    vscode.window.showErrorMessage(`Test generation failed: ${error}`);
  } finally {
    context.statusBarManager.hideProgress();
  }
}

/**
 * Code Review Command (/review)
 * Uses multi-agent approach: Claude + Codex + Gemini
 */
async function reviewCommand(): Promise<void> {
  const editor = vscode.window.activeTextEditor;
  if (!editor) {
    vscode.window.showWarningMessage("No active editor found");
    return;
  }

  const selection = editor.selection;
  const code = selection.isEmpty
    ? editor.document.getText()
    : editor.document.getText(selection);

  if (!code.trim()) {
    vscode.window.showWarningMessage("No code to review");
    return;
  }

  const config = vscode.workspace.getConfiguration("triAgent");
  if (config.get<boolean>("showCostEstimates", true)) {
    const estimate = context.costEstimator.estimate(
      TaskType.Review,
      code.length,
    );
    const proceed = await vscode.window.showInformationMessage(
      `Estimated cost: $${estimate.cost.toFixed(4)} (${estimate.tokens} tokens) - Multi-agent review`,
      "Proceed",
      "Cancel",
    );
    if (proceed !== "Proceed") {
      return;
    }
  }

  const taskId = context.agentManager.createTask({
    type: "review",
    description: "Multi-agent code review",
    agent: AgentType.Multi,
    file: editor.document.fileName,
  });

  context.statusBarManager.showProgress("Running multi-agent review...");

  try {
    const prompt = buildReviewPrompt(code, editor.document.languageId);

    // Run reviews in parallel from all three agents
    const [claudeReview, codexReview, geminiReview] = await Promise.all([
      executeClaudeCommand(prompt, taskId).catch(
        (e) => `Claude review failed: ${e}`,
      ),
      executeCodexCommand(prompt, taskId).catch(
        (e) => `Codex review failed: ${e}`,
      ),
      executeGeminiCommand(prompt, taskId).catch(
        (e) => `Gemini review failed: ${e}`,
      ),
    ]);

    const combinedReview = formatMultiAgentReview(
      claudeReview,
      codexReview,
      geminiReview,
    );

    context.agentManager.updateTaskStatus(taskId, TaskStatus.Completed);
    showResultPanel("Multi-Agent Code Review", combinedReview);
  } catch (error) {
    context.agentManager.updateTaskStatus(taskId, TaskStatus.Failed);
    vscode.window.showErrorMessage(`Code review failed: ${error}`);
  } finally {
    context.statusBarManager.hideProgress();
  }
}

/**
 * Analyze Code Command
 * Uses Gemini for large context analysis
 */
async function analyzeCommand(): Promise<void> {
  const editor = vscode.window.activeTextEditor;
  if (!editor) {
    vscode.window.showWarningMessage("No active editor found");
    return;
  }

  const code = editor.document.getText();

  if (!code.trim()) {
    vscode.window.showWarningMessage("No code to analyze");
    return;
  }

  const analysisType = await vscode.window.showQuickPick(
    ["complexity", "dependencies", "patterns", "performance", "architecture"],
    { placeHolder: "Select analysis type" },
  );

  if (!analysisType) {
    return;
  }

  const taskId = context.agentManager.createTask({
    type: "analyze",
    description: `${analysisType} analysis`,
    agent: AgentType.Gemini,
    file: editor.document.fileName,
  });

  context.statusBarManager.showProgress(`Running ${analysisType} analysis...`);

  try {
    const prompt = buildAnalysisPrompt(
      code,
      editor.document.languageId,
      analysisType,
    );
    const result = await executeGeminiCommand(prompt, taskId);

    context.agentManager.updateTaskStatus(taskId, TaskStatus.Completed);
    showResultPanel(
      `${analysisType.charAt(0).toUpperCase() + analysisType.slice(1)} Analysis`,
      result,
    );
  } catch (error) {
    context.agentManager.updateTaskStatus(taskId, TaskStatus.Failed);
    vscode.window.showErrorMessage(`Analysis failed: ${error}`);
  } finally {
    context.statusBarManager.hideProgress();
  }
}

/**
 * Implement Feature Command
 * Uses Codex for rapid implementation
 */
async function implementCommand(): Promise<void> {
  const description = await vscode.window.showInputBox({
    prompt: "Describe the feature to implement",
    placeHolder: "e.g., Add input validation for email field",
  });

  if (!description) {
    return;
  }

  const editor = vscode.window.activeTextEditor;
  const existingCode = editor ? editor.document.getText() : "";
  const language = editor ? editor.document.languageId : "typescript";

  const taskId = context.agentManager.createTask({
    type: "implement",
    description,
    agent: AgentType.Codex,
    file: editor?.document.fileName,
  });

  context.statusBarManager.showProgress("Implementing feature...");

  try {
    const prompt = buildImplementPrompt(description, existingCode, language);
    const result = await executeCodexCommand(prompt, taskId);

    context.agentManager.updateTaskStatus(taskId, TaskStatus.Completed);

    if (editor) {
      await insertCodeAtCursor(editor, result);
    } else {
      showResultPanel("Implementation", result);
    }
  } catch (error) {
    context.agentManager.updateTaskStatus(taskId, TaskStatus.Failed);
    vscode.window.showErrorMessage(`Implementation failed: ${error}`);
  } finally {
    context.statusBarManager.hideProgress();
  }
}

/**
 * Refactor Code Command
 * Uses Claude for thoughtful refactoring
 */
async function refactorCommand(): Promise<void> {
  const editor = vscode.window.activeTextEditor;
  if (!editor) {
    vscode.window.showWarningMessage("No active editor found");
    return;
  }

  const selection = editor.selection;
  const code = selection.isEmpty
    ? editor.document.getText()
    : editor.document.getText(selection);

  if (!code.trim()) {
    vscode.window.showWarningMessage("No code to refactor");
    return;
  }

  const refactorType = await vscode.window.showQuickPick(
    [
      "Extract function",
      "Simplify conditionals",
      "Remove duplication",
      "Improve naming",
      "Add error handling",
      "Optimize performance",
      "Apply SOLID principles",
    ],
    { placeHolder: "Select refactoring type" },
  );

  if (!refactorType) {
    return;
  }

  const taskId = context.agentManager.createTask({
    type: "refactor",
    description: refactorType,
    agent: AgentType.Claude,
    file: editor.document.fileName,
  });

  context.statusBarManager.showProgress("Refactoring code...");

  try {
    const prompt = buildRefactorPrompt(
      code,
      editor.document.languageId,
      refactorType,
    );
    const result = await executeClaudeCommand(prompt, taskId);

    context.agentManager.updateTaskStatus(taskId, TaskStatus.Completed);

    const action = await vscode.window.showInformationMessage(
      "Refactoring complete. What would you like to do?",
      "Replace Selection",
      "Show in Panel",
      "Copy to Clipboard",
    );

    if (action === "Replace Selection") {
      await editor.edit((editBuilder) => {
        const range = selection.isEmpty
          ? new vscode.Range(
              editor.document.positionAt(0),
              editor.document.positionAt(editor.document.getText().length),
            )
          : selection;
        editBuilder.replace(range, extractCodeFromResult(result));
      });
    } else if (action === "Show in Panel") {
      showResultPanel("Refactored Code", result);
    } else if (action === "Copy to Clipboard") {
      await vscode.env.clipboard.writeText(extractCodeFromResult(result));
      vscode.window.showInformationMessage(
        "Refactored code copied to clipboard",
      );
    }
  } catch (error) {
    context.agentManager.updateTaskStatus(taskId, TaskStatus.Failed);
    vscode.window.showErrorMessage(`Refactoring failed: ${error}`);
  } finally {
    context.statusBarManager.hideProgress();
  }
}

/**
 * Explain Code Command
 * Uses Gemini for detailed explanations
 */
async function explainCommand(): Promise<void> {
  const editor = vscode.window.activeTextEditor;
  if (!editor) {
    vscode.window.showWarningMessage("No active editor found");
    return;
  }

  const selection = editor.selection;
  const code = selection.isEmpty
    ? editor.document.getText()
    : editor.document.getText(selection);

  if (!code.trim()) {
    vscode.window.showWarningMessage("No code to explain");
    return;
  }

  const taskId = context.agentManager.createTask({
    type: "explain",
    description: "Explain code",
    agent: AgentType.Gemini,
    file: editor.document.fileName,
  });

  context.statusBarManager.showProgress("Generating explanation...");

  try {
    const prompt = buildExplainPrompt(code, editor.document.languageId);
    const result = await executeGeminiCommand(prompt, taskId);

    context.agentManager.updateTaskStatus(taskId, TaskStatus.Completed);
    showResultPanel("Code Explanation", result);
  } catch (error) {
    context.agentManager.updateTaskStatus(taskId, TaskStatus.Failed);
    vscode.window.showErrorMessage(`Explanation failed: ${error}`);
  } finally {
    context.statusBarManager.hideProgress();
  }
}

/**
 * Show Agent Panel Command
 */
async function showPanelCommand(): Promise<void> {
  await vscode.commands.executeCommand("workbench.view.extension.triAgent");
}

/**
 * Show Cost Estimate Command
 */
async function showCostEstimateCommand(): Promise<void> {
  const editor = vscode.window.activeTextEditor;
  const codeLength = editor ? editor.document.getText().length : 1000;

  const estimates = [
    {
      type: "Security Review",
      ...context.costEstimator.estimate(TaskType.Security, codeLength),
    },
    {
      type: "Test Generation",
      ...context.costEstimator.estimate(TaskType.TestGen, codeLength),
    },
    {
      type: "Code Review (Multi)",
      ...context.costEstimator.estimate(TaskType.Review, codeLength),
    },
    {
      type: "Analysis",
      ...context.costEstimator.estimate(TaskType.Analyze, codeLength),
    },
    {
      type: "Implementation",
      ...context.costEstimator.estimate(TaskType.Implement, codeLength),
    },
    {
      type: "Refactoring",
      ...context.costEstimator.estimate(TaskType.Refactor, codeLength),
    },
    {
      type: "Explanation",
      ...context.costEstimator.estimate(TaskType.Explain, codeLength),
    },
  ];

  const content = estimates
    .map(
      (e) =>
        `${e.type}: ~$${e.cost.toFixed(4)} (${e.tokens} tokens, ${e.model})`,
    )
    .join("\n");

  const totalDaily = context.agentManager.getDailyCost();
  const budgetUsed = (totalDaily / 42) * 100; // $42/day budget

  showResultPanel(
    "Cost Estimates",
    `
Current Code: ${codeLength} characters

Estimated Costs by Task Type:
${content}

Daily Usage:
- Spent today: $${totalDaily.toFixed(2)}
- Budget used: ${budgetUsed.toFixed(1)}%
- Remaining: $${(42 - totalDaily).toFixed(2)}
    `,
  );
}

/**
 * Cancel Current Task Command
 */
async function cancelTaskCommand(): Promise<void> {
  const activeTasks = context.agentManager.getActiveTasks();

  if (activeTasks.length === 0) {
    vscode.window.showInformationMessage("No active tasks to cancel");
    return;
  }

  const taskToCancel = await vscode.window.showQuickPick(
    activeTasks.map((t) => ({
      label: t.description,
      description: `${t.agent} - ${t.status}`,
      id: t.id,
    })),
    { placeHolder: "Select task to cancel" },
  );

  if (taskToCancel) {
    context.agentManager.cancelTask(taskToCancel.id);
    vscode.window.showInformationMessage(
      `Task cancelled: ${taskToCancel.label}`,
    );
  }
}

/**
 * View Logs Command
 */
async function viewLogsCommand(): Promise<void> {
  const config = vscode.workspace.getConfiguration("triAgent");
  const logsDir = config.get<string>("logsDirectory", "~/.claude/logs");
  const expandedPath = logsDir.replace("~", process.env.HOME || "");

  const logFiles = await vscode.workspace.fs.readDirectory(
    vscode.Uri.file(expandedPath),
  );
  const logFileNames = logFiles
    .filter(([name]) => name.endsWith(".log"))
    .map(([name]) => name);

  const selectedLog = await vscode.window.showQuickPick(logFileNames, {
    placeHolder: "Select log file to view",
  });

  if (selectedLog) {
    const logPath = `${expandedPath}/${selectedLog}`;
    const doc = await vscode.workspace.openTextDocument(
      vscode.Uri.file(logPath),
    );
    await vscode.window.showTextDocument(doc);
  }
}

/**
 * Refresh Status Command
 */
async function refreshStatusCommand(): Promise<void> {
  context.statusBarManager.update(context.agentManager.getStatus());
  vscode.window.showInformationMessage("Status refreshed");
}

// CLI Execution Helpers

async function executeClaudeCommand(
  prompt: string,
  taskId: string,
): Promise<string> {
  const config = vscode.workspace.getConfiguration("triAgent");
  const claudePath = config.get<string>("claudePath", "claude");

  context.agentManager.updateTaskStatus(taskId, TaskStatus.InProgress);

  return new Promise((resolve, reject) => {
    const process = spawn(claudePath, ["--print", prompt], {
      shell: true,
      env: { ...process.env },
    });

    let stdout = "";
    let stderr = "";

    process.stdout.on("data", (data) => {
      stdout += data.toString();
    });

    process.stderr.on("data", (data) => {
      stderr += data.toString();
    });

    process.on("close", (code) => {
      if (code === 0) {
        resolve(stdout);
      } else {
        reject(new Error(stderr || `Claude exited with code ${code}`));
      }
    });

    process.on("error", (error) => {
      reject(error);
    });

    // Store process for cancellation
    context.agentManager.setTaskProcess(taskId, process);
  });
}

async function executeCodexCommand(
  prompt: string,
  taskId: string,
): Promise<string> {
  const config = vscode.workspace.getConfiguration("triAgent");
  const codexPath = config.get<string>("codexPath", "codex");

  context.agentManager.updateTaskStatus(taskId, TaskStatus.InProgress);

  const command = `${codexPath} exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "${prompt.replace(/"/g, '\\"')}"`;

  try {
    const { stdout, stderr } = await execAsync(command, { timeout: 180000 });
    if (stderr && !stdout) {
      throw new Error(stderr);
    }
    return stdout;
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`Codex execution failed: ${message}`);
  }
}

async function executeGeminiCommand(
  prompt: string,
  taskId: string,
): Promise<string> {
  const config = vscode.workspace.getConfiguration("triAgent");
  const geminiPath = config.get<string>("geminiPath", "gemini");

  context.agentManager.updateTaskStatus(taskId, TaskStatus.InProgress);

  const command = `${geminiPath} -m gemini-3-pro-preview --approval-mode yolo "${prompt.replace(/"/g, '\\"')}"`;

  try {
    const { stdout, stderr } = await execAsync(command, { timeout: 120000 });
    if (stderr && !stdout) {
      throw new Error(stderr);
    }
    return stdout;
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`Gemini execution failed: ${message}`);
  }
}

// Prompt Builders

function buildSecurityPrompt(code: string, language: string): string {
  return `Perform a comprehensive security review of this ${language} code. Check for:
1. OWASP Top 10 vulnerabilities
2. Input validation issues
3. SQL injection risks
4. XSS vulnerabilities
5. Authentication/authorization flaws
6. Sensitive data exposure
7. Insecure dependencies
8. Error handling issues

Code:
\`\`\`${language}
${code}
\`\`\`

Provide findings in this format:
- CRITICAL: [issue]
- HIGH: [issue]
- MEDIUM: [issue]
- LOW: [issue]
- INFO: [recommendation]`;
}

function buildTestGenPrompt(
  code: string,
  language: string,
  framework: string,
): string {
  return `Generate comprehensive tests for this ${language} code using ${framework}.
Include:
1. Unit tests for each function/method
2. Edge case tests
3. Error handling tests
4. Integration tests where applicable
5. Mock external dependencies

Code:
\`\`\`${language}
${code}
\`\`\`

Generate only the test code, no explanations.`;
}

function buildReviewPrompt(code: string, language: string): string {
  return `Review this ${language} code for:
1. Code quality and readability
2. Performance issues
3. Best practices violations
4. Potential bugs
5. Architecture concerns
6. Documentation gaps

Code:
\`\`\`${language}
${code}
\`\`\`

Provide actionable feedback with specific line references.`;
}

function buildAnalysisPrompt(
  code: string,
  language: string,
  analysisType: string,
): string {
  const prompts: Record<string, string> = {
    complexity:
      "Analyze cyclomatic complexity, cognitive complexity, and suggest simplifications.",
    dependencies:
      "Map all dependencies, identify tight coupling, and suggest decoupling strategies.",
    patterns:
      "Identify design patterns used and suggest applicable patterns for improvement.",
    performance:
      "Identify performance bottlenecks, memory leaks, and optimization opportunities.",
    architecture:
      "Analyze overall architecture, SOLID principles adherence, and suggest improvements.",
  };

  return `${prompts[analysisType]}

Code:
\`\`\`${language}
${code}
\`\`\`

Provide detailed analysis with specific recommendations.`;
}

function buildImplementPrompt(
  description: string,
  existingCode: string,
  language: string,
): string {
  return `Implement the following feature in ${language}:
${description}

${existingCode ? `Existing code context:\n\`\`\`${language}\n${existingCode}\n\`\`\`` : ""}

Requirements:
1. Follow best practices for ${language}
2. Include proper error handling
3. Add type annotations where applicable
4. Make code testable
5. Follow security best practices

Generate only the implementation code.`;
}

function buildRefactorPrompt(
  code: string,
  language: string,
  refactorType: string,
): string {
  return `Refactor this ${language} code to: ${refactorType}

Code:
\`\`\`${language}
${code}
\`\`\`

Requirements:
1. Maintain existing functionality
2. Improve code quality
3. Add comments explaining changes
4. Follow ${language} best practices

Provide the refactored code with brief explanations of changes.`;
}

function buildExplainPrompt(code: string, language: string): string {
  return `Explain this ${language} code in detail:

\`\`\`${language}
${code}
\`\`\`

Provide:
1. High-level overview of what the code does
2. Line-by-line explanation of key sections
3. Design decisions and patterns used
4. Potential improvements
5. Common pitfalls to avoid`;
}

// Helper Functions

function formatMultiAgentReview(
  claude: string,
  codex: string,
  gemini: string,
): string {
  return `
## Claude Review (Security & Architecture Focus)
${claude}

---

## Codex Review (Implementation & Testing Focus)
${codex}

---

## Gemini Review (Patterns & Documentation Focus)
${gemini}

---

## Consensus Summary
Review the above findings from all three AI agents. Common issues mentioned across agents should be prioritized.
    `.trim();
}

function showResultPanel(title: string, content: string): void {
  const panel = vscode.window.createWebviewPanel(
    "triAgentResult",
    title,
    vscode.ViewColumn.Beside,
    { enableScripts: true },
  );

  panel.webview.html = `
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body {
                    font-family: var(--vscode-font-family);
                    padding: 20px;
                    line-height: 1.6;
                }
                pre {
                    background: var(--vscode-textBlockQuote-background);
                    padding: 16px;
                    border-radius: 4px;
                    overflow-x: auto;
                }
                code {
                    font-family: var(--vscode-editor-font-family);
                }
                h2 {
                    border-bottom: 1px solid var(--vscode-panel-border);
                    padding-bottom: 8px;
                }
                hr {
                    border: none;
                    border-top: 1px solid var(--vscode-panel-border);
                    margin: 20px 0;
                }
                .critical { color: #ff5555; }
                .high { color: #ffaa00; }
                .medium { color: #ffff55; }
                .low { color: #55ff55; }
            </style>
        </head>
        <body>
            <h1>${title}</h1>
            <pre>${escapeHtml(content)}</pre>
        </body>
        </html>
    `;
}

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function extractCodeFromResult(result: string): string {
  const codeBlockMatch = result.match(/```[\w]*\n([\s\S]*?)```/);
  return codeBlockMatch ? codeBlockMatch[1].trim() : result.trim();
}

async function insertCodeAtCursor(
  editor: vscode.TextEditor,
  code: string,
): Promise<void> {
  const extractedCode = extractCodeFromResult(code);
  await editor.edit((editBuilder) => {
    editBuilder.insert(editor.selection.active, extractedCode);
  });
}

async function insertTestCode(
  testCode: string,
  sourceFile: string,
  framework: string,
): Promise<void> {
  const extractedCode = extractCodeFromResult(testCode);
  const testFileName = sourceFile.replace(/\.(ts|js|py|tsx|jsx)$/, `.test.$1`);

  const testUri = vscode.Uri.file(testFileName);

  try {
    await vscode.workspace.fs.stat(testUri);
    // File exists, append
    const doc = await vscode.workspace.openTextDocument(testUri);
    const edit = new vscode.WorkspaceEdit();
    edit.insert(
      testUri,
      new vscode.Position(doc.lineCount, 0),
      "\n\n" + extractedCode,
    );
    await vscode.workspace.applyEdit(edit);
  } catch {
    // File doesn't exist, create
    const encoder = new TextEncoder();
    await vscode.workspace.fs.writeFile(testUri, encoder.encode(extractedCode));
  }

  const doc = await vscode.workspace.openTextDocument(testUri);
  await vscode.window.showTextDocument(doc);
}

export {
  secureCommand,
  testGenCommand,
  reviewCommand,
  analyzeCommand,
  implementCommand,
  refactorCommand,
  explainCommand,
};
