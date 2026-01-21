/**
 * Tri-Agent VS Code Extension - Logger
 * Logging utility for the extension
 *
 * Author: Ahmed Adel Bakr Alderai
 */

import * as vscode from "vscode";

export enum LogLevel {
  Debug = 0,
  Info = 1,
  Warn = 2,
  Error = 3,
}

export class Logger {
  private outputChannel: vscode.OutputChannel;
  private name: string;
  private minLevel: LogLevel;

  constructor(name: string, minLevel: LogLevel = LogLevel.Info) {
    this.name = name;
    this.minLevel = minLevel;
    this.outputChannel = vscode.window.createOutputChannel(name);
  }

  private formatMessage(level: string, message: string): string {
    const timestamp = new Date().toISOString();
    return `[${timestamp}] [${level}] ${message}`;
  }

  private log(
    level: LogLevel,
    levelStr: string,
    message: string,
    data?: unknown,
  ): void {
    if (level < this.minLevel) return;

    let formattedMessage = this.formatMessage(levelStr, message);

    if (data !== undefined) {
      if (data instanceof Error) {
        formattedMessage += `\n  Error: ${data.message}`;
        if (data.stack) {
          formattedMessage += `\n  Stack: ${data.stack}`;
        }
      } else if (typeof data === "object") {
        try {
          formattedMessage += `\n  Data: ${JSON.stringify(data, null, 2)}`;
        } catch {
          formattedMessage += `\n  Data: [Object]`;
        }
      } else {
        formattedMessage += `\n  Data: ${String(data)}`;
      }
    }

    this.outputChannel.appendLine(formattedMessage);

    // Also log to console in development
    if (process.env.NODE_ENV === "development") {
      switch (level) {
        case LogLevel.Debug:
          console.debug(`[${this.name}]`, message, data);
          break;
        case LogLevel.Info:
          console.info(`[${this.name}]`, message, data);
          break;
        case LogLevel.Warn:
          console.warn(`[${this.name}]`, message, data);
          break;
        case LogLevel.Error:
          console.error(`[${this.name}]`, message, data);
          break;
      }
    }
  }

  debug(message: string, data?: unknown): void {
    this.log(LogLevel.Debug, "DEBUG", message, data);
  }

  info(message: string, data?: unknown): void {
    this.log(LogLevel.Info, "INFO", message, data);
  }

  warn(message: string, data?: unknown): void {
    this.log(LogLevel.Warn, "WARN", message, data);
  }

  error(message: string, data?: unknown): void {
    this.log(LogLevel.Error, "ERROR", message, data);
  }

  show(): void {
    this.outputChannel.show();
  }

  clear(): void {
    this.outputChannel.clear();
  }

  setMinLevel(level: LogLevel): void {
    this.minLevel = level;
  }

  dispose(): void {
    this.outputChannel.dispose();
  }
}

// Create a default logger instance
let defaultLogger: Logger | undefined;

export function getLogger(): Logger {
  if (!defaultLogger) {
    defaultLogger = new Logger("Tri-Agent");
  }
  return defaultLogger;
}
