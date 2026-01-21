/**
 * Tri-Agent VS Code Extension - Cost Estimator
 * Estimates costs for various AI operations
 *
 * Author: Ahmed Adel Bakr Alderai
 */

export enum TaskType {
  Security = "security",
  TestGen = "test-gen",
  Review = "review",
  Analyze = "analyze",
  Implement = "implement",
  Refactor = "refactor",
  Explain = "explain",
}

export interface CostEstimate {
  tokens: number;
  cost: number;
  model: string;
  breakdown?: {
    inputTokens: number;
    outputTokens: number;
    inputCost: number;
    outputCost: number;
  };
}

// Pricing per 1K tokens (as of 2026)
interface ModelPricing {
  name: string;
  inputPer1K: number;
  outputPer1K: number;
  contextLimit: number;
}

const MODEL_PRICING: Record<string, ModelPricing> = {
  "claude-opus": {
    name: "Claude Opus 4.5",
    inputPer1K: 0.015,
    outputPer1K: 0.075,
    contextLimit: 200000,
  },
  "claude-sonnet": {
    name: "Claude Sonnet 4",
    inputPer1K: 0.003,
    outputPer1K: 0.015,
    contextLimit: 200000,
  },
  codex: {
    name: "GPT-5.2 Codex",
    inputPer1K: 0.005,
    outputPer1K: 0.015,
    contextLimit: 400000,
  },
  "gemini-pro": {
    name: "Gemini 3 Pro",
    inputPer1K: 0.001,
    outputPer1K: 0.002,
    contextLimit: 1000000,
  },
};

// Task characteristics for estimation
interface TaskProfile {
  model: string;
  inputMultiplier: number; // How much of the input code is sent
  outputMultiplier: number; // Expected output relative to input
  basePromptTokens: number; // Fixed prompt overhead
  isMultiAgent: boolean;
}

const TASK_PROFILES: Record<TaskType, TaskProfile> = {
  [TaskType.Security]: {
    model: "claude-opus",
    inputMultiplier: 1.5, // Include context
    outputMultiplier: 0.8, // Detailed security report
    basePromptTokens: 500,
    isMultiAgent: false,
  },
  [TaskType.TestGen]: {
    model: "codex",
    inputMultiplier: 1.2,
    outputMultiplier: 2.0, // Tests are often longer than source
    basePromptTokens: 300,
    isMultiAgent: false,
  },
  [TaskType.Review]: {
    model: "claude-sonnet",
    inputMultiplier: 1.5,
    outputMultiplier: 0.6,
    basePromptTokens: 400,
    isMultiAgent: true, // Uses all three agents
  },
  [TaskType.Analyze]: {
    model: "gemini-pro",
    inputMultiplier: 2.0, // Large context analysis
    outputMultiplier: 0.5,
    basePromptTokens: 400,
    isMultiAgent: false,
  },
  [TaskType.Implement]: {
    model: "codex",
    inputMultiplier: 1.0,
    outputMultiplier: 1.5,
    basePromptTokens: 350,
    isMultiAgent: false,
  },
  [TaskType.Refactor]: {
    model: "claude-sonnet",
    inputMultiplier: 1.2,
    outputMultiplier: 1.2,
    basePromptTokens: 400,
    isMultiAgent: false,
  },
  [TaskType.Explain]: {
    model: "gemini-pro",
    inputMultiplier: 1.0,
    outputMultiplier: 1.5, // Explanations are verbose
    basePromptTokens: 300,
    isMultiAgent: false,
  },
};

export class CostEstimator {
  // Average characters per token (rough estimate)
  private readonly CHARS_PER_TOKEN = 4;

  estimate(taskType: TaskType, codeLength: number): CostEstimate {
    const profile = TASK_PROFILES[taskType];
    const pricing = MODEL_PRICING[profile.model];

    // Convert code length to tokens
    const codeTokens = Math.ceil(codeLength / this.CHARS_PER_TOKEN);

    // Calculate input and output tokens
    const inputTokens = Math.ceil(
      codeTokens * profile.inputMultiplier + profile.basePromptTokens,
    );
    const outputTokens = Math.ceil(codeTokens * profile.outputMultiplier);

    // Calculate costs
    let inputCost = (inputTokens / 1000) * pricing.inputPer1K;
    let outputCost = (outputTokens / 1000) * pricing.outputPer1K;

    // If multi-agent, multiply costs by 3 (all agents)
    if (profile.isMultiAgent) {
      inputCost *= 3;
      outputCost *= 3;
    }

    const totalCost = inputCost + outputCost;
    const totalTokens = inputTokens + outputTokens;

    return {
      tokens: profile.isMultiAgent ? totalTokens * 3 : totalTokens,
      cost: totalCost,
      model: profile.isMultiAgent ? "Multi-Agent" : pricing.name,
      breakdown: {
        inputTokens: profile.isMultiAgent ? inputTokens * 3 : inputTokens,
        outputTokens: profile.isMultiAgent ? outputTokens * 3 : outputTokens,
        inputCost,
        outputCost,
      },
    };
  }

  estimateFromPrompt(
    prompt: string,
    expectedOutputLength: number,
    model: string,
  ): CostEstimate {
    const pricing = MODEL_PRICING[model] || MODEL_PRICING["claude-sonnet"];

    const inputTokens = Math.ceil(prompt.length / this.CHARS_PER_TOKEN);
    const outputTokens = Math.ceil(expectedOutputLength / this.CHARS_PER_TOKEN);

    const inputCost = (inputTokens / 1000) * pricing.inputPer1K;
    const outputCost = (outputTokens / 1000) * pricing.outputPer1K;

    return {
      tokens: inputTokens + outputTokens,
      cost: inputCost + outputCost,
      model: pricing.name,
      breakdown: {
        inputTokens,
        outputTokens,
        inputCost,
        outputCost,
      },
    };
  }

  formatCost(cost: number): string {
    if (cost < 0.01) {
      return `$${(cost * 100).toFixed(2)}c`;
    }
    return `$${cost.toFixed(4)}`;
  }

  formatTokens(tokens: number): string {
    if (tokens >= 1000000) {
      return `${(tokens / 1000000).toFixed(1)}M`;
    }
    if (tokens >= 1000) {
      return `${(tokens / 1000).toFixed(1)}K`;
    }
    return String(tokens);
  }

  getModelPricing(model: string): ModelPricing | undefined {
    return MODEL_PRICING[model];
  }

  getAllModels(): Array<{ id: string; pricing: ModelPricing }> {
    return Object.entries(MODEL_PRICING).map(([id, pricing]) => ({
      id,
      pricing,
    }));
  }
}
