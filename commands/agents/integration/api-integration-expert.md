---
name: API Integration Expert Agent
description: Comprehensive API integration specialist covering REST, GraphQL, OAuth, webhooks, rate limiting, circuit breakers, and SDK generation for production-grade integrations
version: 2.0.0
author: Ahmed Adel Bakr Alderai
category: integration
tags:
  - api
  - rest
  - graphql
  - oauth
  - oidc
  - webhooks
  - rate-limiting
  - circuit-breaker
  - sdk
  - integrations
  - stripe
  - twilio
  - sendgrid
tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - Task
dependencies:
  - /agents/backend/api-architect
  - /agents/backend/authentication-specialist
  - /agents/integration/webhook-expert
  - /agents/security/security-expert
  - /agents/testing/api-test-expert
inputs:
  - name: task
    type: string
    required: true
    description: The API integration task to perform
  - name: provider
    type: string
    required: false
    description: "API provider (stripe, twilio, sendgrid, github, custom)"
  - name: framework
    type: string
    required: false
    default: typescript
    description: "Target language/framework (typescript, python, go)"
  - name: style
    type: string
    required: false
    default: rest
    description: "API style (rest, graphql, grpc)"
outputs:
  - api_client
  - authentication_module
  - webhook_handler
  - error_handling
  - retry_logic
  - circuit_breaker
  - test_suite
  - openapi_spec
---

# API Integration Expert Agent

Expert in designing and implementing production-grade API integrations with comprehensive patterns for REST, GraphQL, OAuth 2.0/OIDC, webhooks, rate limiting, circuit breakers, and SDK generation.

## Arguments

- `$ARGUMENTS` - API integration task (e.g., "integrate Stripe payment API with retry logic")

## Invoke Agent

```
Use the Task tool with subagent_type="api-integration-expert" to:

1. Design and implement REST API clients
2. Build GraphQL client implementations
3. Implement OAuth 2.0 and OIDC authentication flows
4. Handle webhooks with signature verification
5. Implement rate limiting and retry strategies
6. Add circuit breaker patterns for resilience
7. Handle API versioning and deprecation
8. Generate or integrate with provider SDKs
9. Implement comprehensive error handling and logging
10. Integrate popular APIs (Stripe, Twilio, SendGrid, etc.)

Task: $ARGUMENTS
```

---

## Core Capabilities

### 1. REST API Integration Patterns

Design robust REST API clients with proper resource handling, pagination, and filtering.

### 2. GraphQL Client Implementation

Build type-safe GraphQL clients with query optimization and caching.

### 3. OAuth 2.0 and OIDC Integration

Implement secure authentication flows including Authorization Code, PKCE, Client Credentials, and Device flows.

### 4. Webhook Handling and Verification

Process webhooks securely with signature verification, idempotency, and async processing.

### 5. Rate Limiting and Retry Strategies

Implement intelligent rate limiting with token bucket algorithms and exponential backoff retries.

### 6. Circuit Breaker Patterns

Add resilience with circuit breakers to prevent cascade failures.

### 7. API Versioning Handling

Manage API version compatibility and migration paths.

### 8. SDK Generation and Usage

Generate type-safe SDKs or integrate with provider SDKs effectively.

### 9. Error Handling and Logging

Implement comprehensive error handling with structured logging and observability.

### 10. Popular API Integrations

Pre-built patterns for Stripe, Twilio, SendGrid, GitHub, Slack, and more.

---

## Implementation Templates

### Universal API Client (TypeScript)

```typescript
/**
 * Universal API Client
 * Production-grade HTTP client with retry, rate limiting, and circuit breaker
 */
import axios, { AxiosInstance, AxiosRequestConfig, AxiosResponse } from "axios";
import { EventEmitter } from "events";

// ============================================================================
// Configuration Types
// ============================================================================

interface ApiClientConfig {
  baseURL: string;
  timeout?: number;
  headers?: Record<string, string>;
  auth?: AuthConfig;
  rateLimit?: RateLimitConfig;
  retry?: RetryConfig;
  circuitBreaker?: CircuitBreakerConfig;
  logging?: LoggingConfig;
}

interface AuthConfig {
  type: "bearer" | "basic" | "apiKey" | "oauth2";
  credentials: {
    token?: string;
    username?: string;
    password?: string;
    apiKey?: string;
    apiKeyHeader?: string;
    clientId?: string;
    clientSecret?: string;
    tokenEndpoint?: string;
  };
}

interface RateLimitConfig {
  maxRequests: number;
  windowMs: number;
  headers?: {
    limit: string;
    remaining: string;
    reset: string;
  };
}

interface RetryConfig {
  maxRetries: number;
  baseDelayMs: number;
  maxDelayMs: number;
  jitterFactor: number;
  retryableStatuses: number[];
  retryableErrors: string[];
}

interface CircuitBreakerConfig {
  failureThreshold: number;
  successThreshold: number;
  timeout: number;
  monitoringWindow: number;
}

interface LoggingConfig {
  enabled: boolean;
  level: "debug" | "info" | "warn" | "error";
  redactHeaders?: string[];
  redactBody?: string[];
}

// ============================================================================
// Rate Limiter Implementation
// ============================================================================

class TokenBucketRateLimiter {
  private tokens: number;
  private lastRefill: number;
  private queue: Array<{
    resolve: () => void;
    reject: (error: Error) => void;
  }> = [];

  constructor(private config: RateLimitConfig) {
    this.tokens = config.maxRequests;
    this.lastRefill = Date.now();
  }

  private refillTokens(): void {
    const now = Date.now();
    const elapsed = now - this.lastRefill;
    const tokensToAdd = Math.floor(
      (elapsed / this.config.windowMs) * this.config.maxRequests,
    );

    if (tokensToAdd > 0) {
      this.tokens = Math.min(
        this.config.maxRequests,
        this.tokens + tokensToAdd,
      );
      this.lastRefill = now;
    }
  }

  async acquire(): Promise<void> {
    this.refillTokens();

    if (this.tokens > 0) {
      this.tokens--;
      return;
    }

    return new Promise((resolve, reject) => {
      this.queue.push({ resolve, reject });

      const timeToNextToken = this.config.windowMs / this.config.maxRequests;
      setTimeout(() => {
        this.refillTokens();
        this.processQueue();
      }, timeToNextToken);
    });
  }

  private processQueue(): void {
    while (this.queue.length > 0 && this.tokens > 0) {
      const { resolve } = this.queue.shift()!;
      this.tokens--;
      resolve();
    }
  }

  updateFromHeaders(headers: Record<string, string>): void {
    if (!this.config.headers) return;

    const remaining = headers[this.config.headers.remaining.toLowerCase()];
    if (remaining) {
      this.tokens = Math.min(this.tokens, parseInt(remaining, 10));
    }
  }
}

// ============================================================================
// Circuit Breaker Implementation
// ============================================================================

enum CircuitState {
  CLOSED = "CLOSED",
  OPEN = "OPEN",
  HALF_OPEN = "HALF_OPEN",
}

class CircuitBreaker {
  private state: CircuitState = CircuitState.CLOSED;
  private failures: number[] = [];
  private successes: number = 0;
  private lastFailureTime: number = 0;

  constructor(
    private config: CircuitBreakerConfig = {
      failureThreshold: 5,
      successThreshold: 3,
      timeout: 60000,
      monitoringWindow: 60000,
    },
  ) {}

  async execute<T>(operation: () => Promise<T>): Promise<T> {
    if (this.state === CircuitState.OPEN) {
      if (Date.now() - this.lastFailureTime >= this.config.timeout) {
        this.state = CircuitState.HALF_OPEN;
        this.successes = 0;
      } else {
        throw new CircuitOpenError(
          `Circuit breaker is open. Retry after ${this.config.timeout - (Date.now() - this.lastFailureTime)}ms`,
        );
      }
    }

    try {
      const result = await operation();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }

  private onSuccess(): void {
    if (this.state === CircuitState.HALF_OPEN) {
      this.successes++;
      if (this.successes >= this.config.successThreshold) {
        this.state = CircuitState.CLOSED;
        this.failures = [];
      }
    }
  }

  private onFailure(): void {
    const now = Date.now();
    this.lastFailureTime = now;

    this.failures = this.failures.filter(
      (time) => now - time < this.config.monitoringWindow,
    );
    this.failures.push(now);

    if (this.state === CircuitState.HALF_OPEN) {
      this.state = CircuitState.OPEN;
    } else if (this.failures.length >= this.config.failureThreshold) {
      this.state = CircuitState.OPEN;
    }
  }

  getState(): CircuitState {
    return this.state;
  }

  reset(): void {
    this.state = CircuitState.CLOSED;
    this.failures = [];
    this.successes = 0;
  }
}

class CircuitOpenError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "CircuitOpenError";
  }
}

// ============================================================================
// Retry Handler Implementation
// ============================================================================

class RetryHandler {
  constructor(
    private config: RetryConfig = {
      maxRetries: 3,
      baseDelayMs: 1000,
      maxDelayMs: 30000,
      jitterFactor: 0.2,
      retryableStatuses: [408, 429, 500, 502, 503, 504],
      retryableErrors: ["ECONNRESET", "ETIMEDOUT", "ENOTFOUND", "EAI_AGAIN"],
    },
  ) {}

  private calculateDelay(attempt: number, retryAfterMs?: number): number {
    if (retryAfterMs) return retryAfterMs;

    const exponentialDelay = this.config.baseDelayMs * Math.pow(2, attempt);
    const cappedDelay = Math.min(exponentialDelay, this.config.maxDelayMs);
    const jitter = cappedDelay * this.config.jitterFactor * Math.random();

    return Math.floor(cappedDelay + jitter);
  }

  isRetryable(error: any): boolean {
    if (error.response) {
      return this.config.retryableStatuses.includes(error.response.status);
    }

    if (error.code) {
      return this.config.retryableErrors.includes(error.code);
    }

    return false;
  }

  async execute<T>(
    operation: () => Promise<T>,
    context?: { rateLimiter?: TokenBucketRateLimiter },
  ): Promise<T> {
    let lastError: Error | undefined;

    for (let attempt = 0; attempt <= this.config.maxRetries; attempt++) {
      try {
        if (context?.rateLimiter) {
          await context.rateLimiter.acquire();
        }

        return await operation();
      } catch (error: any) {
        lastError = error;

        if (!this.isRetryable(error)) {
          throw error;
        }

        if (attempt === this.config.maxRetries) {
          throw new RetryExhaustedError(
            `Max retries (${this.config.maxRetries}) exceeded`,
            lastError,
          );
        }

        let retryAfterMs: number | undefined;
        if (error.response?.status === 429) {
          const retryAfter = error.response.headers["retry-after"];
          if (retryAfter) {
            retryAfterMs = parseInt(retryAfter, 10) * 1000;
          }
        }

        const delay = this.calculateDelay(attempt, retryAfterMs);
        console.log(
          `[Retry] Attempt ${attempt + 1}/${this.config.maxRetries} after ${delay}ms`,
        );

        await this.sleep(delay);
      }
    }

    throw lastError;
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}

class RetryExhaustedError extends Error {
  constructor(
    message: string,
    public lastError: Error,
  ) {
    super(message);
    this.name = "RetryExhaustedError";
  }
}

// ============================================================================
// Main API Client Implementation
// ============================================================================

class ApiClient extends EventEmitter {
  private client: AxiosInstance;
  private rateLimiter?: TokenBucketRateLimiter;
  private retryHandler: RetryHandler;
  private circuitBreaker?: CircuitBreaker;
  private tokenCache?: { token: string; expiresAt: number };

  constructor(private config: ApiClientConfig) {
    super();

    this.client = axios.create({
      baseURL: config.baseURL,
      timeout: config.timeout || 30000,
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        ...config.headers,
      },
    });

    // Initialize rate limiter
    if (config.rateLimit) {
      this.rateLimiter = new TokenBucketRateLimiter(config.rateLimit);
    }

    // Initialize retry handler
    this.retryHandler = new RetryHandler(config.retry);

    // Initialize circuit breaker
    if (config.circuitBreaker) {
      this.circuitBreaker = new CircuitBreaker(config.circuitBreaker);
    }

    // Setup interceptors
    this.setupInterceptors();
  }

  private setupInterceptors(): void {
    // Request interceptor for authentication
    this.client.interceptors.request.use(
      async (config) => {
        const token = await this.getAuthToken();
        if (token) {
          config.headers.Authorization = token;
        }

        // Logging
        if (this.config.logging?.enabled) {
          this.logRequest(config);
        }

        return config;
      },
      (error) => Promise.reject(error),
    );

    // Response interceptor for rate limit headers
    this.client.interceptors.response.use(
      (response) => {
        if (this.rateLimiter) {
          this.rateLimiter.updateFromHeaders(
            response.headers as Record<string, string>,
          );
        }

        if (this.config.logging?.enabled) {
          this.logResponse(response);
        }

        return response;
      },
      (error) => {
        if (this.config.logging?.enabled) {
          this.logError(error);
        }
        return Promise.reject(error);
      },
    );
  }

  private async getAuthToken(): Promise<string | null> {
    if (!this.config.auth) return null;

    switch (this.config.auth.type) {
      case "bearer":
        return `Bearer ${this.config.auth.credentials.token}`;

      case "basic":
        const { username, password } = this.config.auth.credentials;
        const encoded = Buffer.from(`${username}:${password}`).toString(
          "base64",
        );
        return `Basic ${encoded}`;

      case "apiKey":
        // API key is usually sent as a header, handled separately
        return null;

      case "oauth2":
        return `Bearer ${await this.getOAuth2Token()}`;

      default:
        return null;
    }
  }

  private async getOAuth2Token(): Promise<string> {
    // Return cached token if still valid
    if (this.tokenCache && this.tokenCache.expiresAt > Date.now() + 60000) {
      return this.tokenCache.token;
    }

    const { clientId, clientSecret, tokenEndpoint } =
      this.config.auth!.credentials;

    const response = await axios.post(
      tokenEndpoint!,
      new URLSearchParams({
        grant_type: "client_credentials",
        client_id: clientId!,
        client_secret: clientSecret!,
      }),
      {
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
      },
    );

    this.tokenCache = {
      token: response.data.access_token,
      expiresAt: Date.now() + response.data.expires_in * 1000,
    };

    return this.tokenCache.token;
  }

  private logRequest(config: AxiosRequestConfig): void {
    const redactedHeaders = this.redactSensitive(
      config.headers as Record<string, string>,
      this.config.logging?.redactHeaders || ["authorization", "x-api-key"],
    );

    console.log(`[API Request] ${config.method?.toUpperCase()} ${config.url}`, {
      headers: redactedHeaders,
      params: config.params,
    });
  }

  private logResponse(response: AxiosResponse): void {
    console.log(`[API Response] ${response.status} ${response.config.url}`, {
      duration: response.headers["x-response-time"],
    });
  }

  private logError(error: any): void {
    console.error(`[API Error] ${error.response?.status || error.code}`, {
      url: error.config?.url,
      message: error.message,
    });
  }

  private redactSensitive(
    obj: Record<string, string>,
    keys: string[],
  ): Record<string, string> {
    const result = { ...obj };
    for (const key of keys) {
      if (result[key.toLowerCase()]) {
        result[key.toLowerCase()] = "[REDACTED]";
      }
    }
    return result;
  }

  // ============================================================================
  // Public API Methods
  // ============================================================================

  async get<T>(path: string, config?: AxiosRequestConfig): Promise<T> {
    return this.request<T>({ ...config, method: "GET", url: path });
  }

  async post<T>(
    path: string,
    data?: any,
    config?: AxiosRequestConfig,
  ): Promise<T> {
    return this.request<T>({ ...config, method: "POST", url: path, data });
  }

  async put<T>(
    path: string,
    data?: any,
    config?: AxiosRequestConfig,
  ): Promise<T> {
    return this.request<T>({ ...config, method: "PUT", url: path, data });
  }

  async patch<T>(
    path: string,
    data?: any,
    config?: AxiosRequestConfig,
  ): Promise<T> {
    return this.request<T>({ ...config, method: "PATCH", url: path, data });
  }

  async delete<T>(path: string, config?: AxiosRequestConfig): Promise<T> {
    return this.request<T>({ ...config, method: "DELETE", url: path });
  }

  private async request<T>(config: AxiosRequestConfig): Promise<T> {
    const operation = async (): Promise<T> => {
      const response = await this.client.request<T>(config);
      return response.data;
    };

    // Wrap with circuit breaker if configured
    const wrappedOperation = this.circuitBreaker
      ? () => this.circuitBreaker!.execute(operation)
      : operation;

    // Execute with retry logic
    return this.retryHandler.execute(wrappedOperation, {
      rateLimiter: this.rateLimiter,
    });
  }

  // ============================================================================
  // Pagination Helper
  // ============================================================================

  async *paginate<T>(
    path: string,
    options: {
      pageParam?: string;
      limitParam?: string;
      pageSize?: number;
      maxPages?: number;
      getNextPage?: (response: any) => string | null;
    } = {},
  ): AsyncGenerator<T[], void, unknown> {
    const {
      pageParam = "page",
      limitParam = "limit",
      pageSize = 100,
      maxPages = Infinity,
      getNextPage,
    } = options;

    let page = 1;
    let hasMore = true;

    while (hasMore && page <= maxPages) {
      const params = {
        [pageParam]: page,
        [limitParam]: pageSize,
      };

      const response = await this.get<any>(path, { params });

      // Extract data array
      const data = Array.isArray(response)
        ? response
        : response.data || response.items || [];

      if (data.length === 0) {
        hasMore = false;
      } else {
        yield data;

        // Determine if there are more pages
        if (getNextPage) {
          const nextPage = getNextPage(response);
          hasMore = nextPage !== null;
        } else {
          hasMore = data.length === pageSize;
        }

        page++;
      }
    }
  }

  // ============================================================================
  // Utility Methods
  // ============================================================================

  getCircuitBreakerState(): CircuitState | null {
    return this.circuitBreaker?.getState() || null;
  }

  resetCircuitBreaker(): void {
    this.circuitBreaker?.reset();
  }
}

// ============================================================================
// Export
// ============================================================================

export {
  ApiClient,
  ApiClientConfig,
  AuthConfig,
  RateLimitConfig,
  RetryConfig,
  CircuitBreakerConfig,
  CircuitState,
  CircuitOpenError,
  RetryExhaustedError,
};
```

---

### GraphQL Client Implementation

```typescript
/**
 * Type-Safe GraphQL Client
 * With query batching, caching, and subscription support
 */
import { DocumentNode, print } from "graphql";
import WebSocket from "ws";

interface GraphQLClientConfig {
  endpoint: string;
  wsEndpoint?: string;
  headers?: Record<string, string>;
  auth?: {
    type: "bearer" | "apiKey";
    token: string;
    header?: string;
  };
  cache?: {
    enabled: boolean;
    ttlMs: number;
  };
  batching?: {
    enabled: boolean;
    maxBatchSize: number;
    batchIntervalMs: number;
  };
}

interface GraphQLResponse<T> {
  data?: T;
  errors?: Array<{
    message: string;
    locations?: Array<{ line: number; column: number }>;
    path?: Array<string | number>;
    extensions?: Record<string, unknown>;
  }>;
}

interface QueryOptions<V> {
  variables?: V;
  headers?: Record<string, string>;
  skipCache?: boolean;
  operationName?: string;
}

interface SubscriptionOptions<V> {
  variables?: V;
  onData: (data: any) => void;
  onError?: (error: Error) => void;
  onComplete?: () => void;
}

class GraphQLClient {
  private cache: Map<string, { data: any; expiresAt: number }> = new Map();
  private batchQueue: Array<{
    query: string;
    variables?: Record<string, unknown>;
    resolve: (value: any) => void;
    reject: (error: Error) => void;
  }> = [];
  private batchTimer?: NodeJS.Timeout;
  private ws?: WebSocket;
  private subscriptions: Map<string, { onData: Function; onError?: Function }> =
    new Map();

  constructor(private config: GraphQLClientConfig) {}

  // ============================================================================
  // Query Methods
  // ============================================================================

  async query<T, V = Record<string, unknown>>(
    query: string | DocumentNode,
    options: QueryOptions<V> = {},
  ): Promise<T> {
    const queryString = typeof query === "string" ? query : print(query);
    const cacheKey = this.getCacheKey(queryString, options.variables);

    // Check cache
    if (this.config.cache?.enabled && !options.skipCache) {
      const cached = this.cache.get(cacheKey);
      if (cached && cached.expiresAt > Date.now()) {
        return cached.data;
      }
    }

    // Execute query
    const result = await this.executeQuery<T>(queryString, options);

    // Cache result
    if (this.config.cache?.enabled) {
      this.cache.set(cacheKey, {
        data: result,
        expiresAt: Date.now() + this.config.cache.ttlMs,
      });
    }

    return result;
  }

  async mutation<T, V = Record<string, unknown>>(
    mutation: string | DocumentNode,
    options: QueryOptions<V> = {},
  ): Promise<T> {
    const mutationString =
      typeof mutation === "string" ? mutation : print(mutation);
    return this.executeQuery<T>(mutationString, options);
  }

  // ============================================================================
  // Batching
  // ============================================================================

  async batchQuery<T>(
    query: string | DocumentNode,
    variables?: Record<string, unknown>,
  ): Promise<T> {
    if (!this.config.batching?.enabled) {
      return this.query(query, { variables });
    }

    const queryString = typeof query === "string" ? query : print(query);

    return new Promise((resolve, reject) => {
      this.batchQueue.push({ query: queryString, variables, resolve, reject });

      if (this.batchQueue.length >= this.config.batching!.maxBatchSize) {
        this.flushBatch();
      } else if (!this.batchTimer) {
        this.batchTimer = setTimeout(
          () => this.flushBatch(),
          this.config.batching!.batchIntervalMs,
        );
      }
    });
  }

  private async flushBatch(): Promise<void> {
    if (this.batchTimer) {
      clearTimeout(this.batchTimer);
      this.batchTimer = undefined;
    }

    if (this.batchQueue.length === 0) return;

    const batch = [...this.batchQueue];
    this.batchQueue = [];

    const batchQuery = batch.map((item, index) => ({
      query: item.query,
      variables: item.variables,
      operationName: `op${index}`,
    }));

    try {
      const response = await fetch(this.config.endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...this.getAuthHeaders(),
          ...this.config.headers,
        },
        body: JSON.stringify(batchQuery),
      });

      const results: GraphQLResponse<any>[] = await response.json();

      results.forEach((result, index) => {
        if (result.errors?.length) {
          batch[index].reject(new GraphQLError(result.errors));
        } else {
          batch[index].resolve(result.data);
        }
      });
    } catch (error) {
      batch.forEach((item) => item.reject(error as Error));
    }
  }

  // ============================================================================
  // Subscriptions
  // ============================================================================

  subscribe<T, V = Record<string, unknown>>(
    subscription: string | DocumentNode,
    options: SubscriptionOptions<V>,
  ): () => void {
    if (!this.config.wsEndpoint) {
      throw new Error("WebSocket endpoint not configured for subscriptions");
    }

    const subscriptionString =
      typeof subscription === "string" ? subscription : print(subscription);
    const id = this.generateSubscriptionId();

    this.ensureWebSocket();

    const payload = {
      id,
      type: "subscribe",
      payload: {
        query: subscriptionString,
        variables: options.variables,
      },
    };

    this.ws!.send(JSON.stringify(payload));

    this.subscriptions.set(id, {
      onData: options.onData,
      onError: options.onError,
    });

    // Return unsubscribe function
    return () => {
      this.ws?.send(JSON.stringify({ id, type: "complete" }));
      this.subscriptions.delete(id);
    };
  }

  private ensureWebSocket(): void {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) return;

    this.ws = new WebSocket(this.config.wsEndpoint!, "graphql-ws", {
      headers: {
        ...this.getAuthHeaders(),
        ...this.config.headers,
      },
    });

    this.ws.on("open", () => {
      this.ws!.send(JSON.stringify({ type: "connection_init" }));
    });

    this.ws.on("message", (data: WebSocket.Data) => {
      const message = JSON.parse(data.toString());

      switch (message.type) {
        case "next":
          const subscription = this.subscriptions.get(message.id);
          if (subscription) {
            subscription.onData(message.payload.data);
          }
          break;

        case "error":
          const errorSub = this.subscriptions.get(message.id);
          if (errorSub?.onError) {
            errorSub.onError(new GraphQLError(message.payload));
          }
          break;

        case "complete":
          this.subscriptions.delete(message.id);
          break;
      }
    });

    this.ws.on("error", (error) => {
      this.subscriptions.forEach((sub) => {
        if (sub.onError) sub.onError(error);
      });
    });
  }

  // ============================================================================
  // Helper Methods
  // ============================================================================

  private async executeQuery<T>(
    query: string,
    options: QueryOptions<any>,
  ): Promise<T> {
    const response = await fetch(this.config.endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...this.getAuthHeaders(),
        ...this.config.headers,
        ...options.headers,
      },
      body: JSON.stringify({
        query,
        variables: options.variables,
        operationName: options.operationName,
      }),
    });

    const result: GraphQLResponse<T> = await response.json();

    if (result.errors?.length) {
      throw new GraphQLError(result.errors);
    }

    return result.data as T;
  }

  private getAuthHeaders(): Record<string, string> {
    if (!this.config.auth) return {};

    switch (this.config.auth.type) {
      case "bearer":
        return { Authorization: `Bearer ${this.config.auth.token}` };
      case "apiKey":
        return {
          [this.config.auth.header || "X-API-Key"]: this.config.auth.token,
        };
      default:
        return {};
    }
  }

  private getCacheKey(query: string, variables?: any): string {
    return `${query}:${JSON.stringify(variables || {})}`;
  }

  private generateSubscriptionId(): string {
    return Math.random().toString(36).substring(2, 15);
  }

  clearCache(): void {
    this.cache.clear();
  }

  disconnect(): void {
    this.ws?.close();
    this.subscriptions.clear();
  }
}

class GraphQLError extends Error {
  constructor(public errors: Array<{ message: string; [key: string]: any }>) {
    super(errors.map((e) => e.message).join(", "));
    this.name = "GraphQLError";
  }
}

export { GraphQLClient, GraphQLClientConfig, GraphQLError };
```

---

### OAuth 2.0 and OIDC Implementation

```typescript
/**
 * OAuth 2.0 and OpenID Connect Client
 * Supports Authorization Code (with PKCE), Client Credentials, Device, and Refresh flows
 */
import crypto from "crypto";

// ============================================================================
// Types
// ============================================================================

interface OAuthConfig {
  clientId: string;
  clientSecret?: string;
  redirectUri: string;
  authorizationEndpoint: string;
  tokenEndpoint: string;
  userinfoEndpoint?: string;
  jwksUri?: string;
  issuer?: string;
  scopes: string[];
}

interface TokenResponse {
  access_token: string;
  token_type: string;
  expires_in: number;
  refresh_token?: string;
  id_token?: string;
  scope?: string;
}

interface UserInfo {
  sub: string;
  name?: string;
  given_name?: string;
  family_name?: string;
  email?: string;
  email_verified?: boolean;
  picture?: string;
  [key: string]: unknown;
}

interface AuthorizationState {
  state: string;
  codeVerifier: string;
  nonce?: string;
  redirectUri: string;
  createdAt: number;
}

// ============================================================================
// OAuth 2.0 Client Implementation
// ============================================================================

class OAuth2Client {
  private stateStore: Map<string, AuthorizationState> = new Map();
  private tokenCache: Map<string, TokenResponse & { expiresAt: number }> =
    new Map();

  constructor(private config: OAuthConfig) {}

  // ============================================================================
  // Authorization Code Flow with PKCE
  // ============================================================================

  /**
   * Generate authorization URL for user redirect
   */
  getAuthorizationUrl(
    options: {
      state?: string;
      nonce?: string;
      additionalParams?: Record<string, string>;
    } = {},
  ): { url: string; state: string; codeVerifier: string } {
    const state = options.state || this.generateState();
    const { codeVerifier, codeChallenge } = this.generatePKCE();
    const nonce = options.nonce || this.generateNonce();

    // Store state for validation
    this.stateStore.set(state, {
      state,
      codeVerifier,
      nonce,
      redirectUri: this.config.redirectUri,
      createdAt: Date.now(),
    });

    // Build URL
    const params = new URLSearchParams({
      response_type: "code",
      client_id: this.config.clientId,
      redirect_uri: this.config.redirectUri,
      scope: this.config.scopes.join(" "),
      state,
      nonce,
      code_challenge: codeChallenge,
      code_challenge_method: "S256",
      ...options.additionalParams,
    });

    return {
      url: `${this.config.authorizationEndpoint}?${params.toString()}`,
      state,
      codeVerifier,
    };
  }

  /**
   * Exchange authorization code for tokens
   */
  async exchangeCode(code: string, state: string): Promise<TokenResponse> {
    const storedState = this.stateStore.get(state);

    if (!storedState) {
      throw new OAuthError(
        "invalid_state",
        "Invalid or expired state parameter",
      );
    }

    // Check state expiration (10 minutes)
    if (Date.now() - storedState.createdAt > 600000) {
      this.stateStore.delete(state);
      throw new OAuthError("state_expired", "State parameter has expired");
    }

    const body = new URLSearchParams({
      grant_type: "authorization_code",
      code,
      redirect_uri: storedState.redirectUri,
      client_id: this.config.clientId,
      code_verifier: storedState.codeVerifier,
    });

    // Add client secret if available (confidential client)
    if (this.config.clientSecret) {
      body.append("client_secret", this.config.clientSecret);
    }

    const response = await fetch(this.config.tokenEndpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        Accept: "application/json",
      },
      body,
    });

    this.stateStore.delete(state);

    if (!response.ok) {
      const error = await response.json();
      throw new OAuthError(error.error, error.error_description);
    }

    const tokens: TokenResponse = await response.json();

    // Validate ID token if present
    if (tokens.id_token && storedState.nonce) {
      await this.validateIdToken(tokens.id_token, storedState.nonce);
    }

    return tokens;
  }

  // ============================================================================
  // Client Credentials Flow
  // ============================================================================

  /**
   * Get access token using client credentials
   */
  async getClientCredentialsToken(scopes?: string[]): Promise<TokenResponse> {
    const cacheKey = `client_credentials:${(scopes || this.config.scopes).join(",")}`;
    const cached = this.tokenCache.get(cacheKey);

    // Return cached token if still valid (with 60s buffer)
    if (cached && cached.expiresAt > Date.now() + 60000) {
      return cached;
    }

    if (!this.config.clientSecret) {
      throw new OAuthError(
        "missing_secret",
        "Client secret required for client credentials flow",
      );
    }

    const body = new URLSearchParams({
      grant_type: "client_credentials",
      client_id: this.config.clientId,
      client_secret: this.config.clientSecret,
      scope: (scopes || this.config.scopes).join(" "),
    });

    const response = await fetch(this.config.tokenEndpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        Accept: "application/json",
      },
      body,
    });

    if (!response.ok) {
      const error = await response.json();
      throw new OAuthError(error.error, error.error_description);
    }

    const tokens: TokenResponse = await response.json();

    // Cache token
    this.tokenCache.set(cacheKey, {
      ...tokens,
      expiresAt: Date.now() + tokens.expires_in * 1000,
    });

    return tokens;
  }

  // ============================================================================
  // Refresh Token Flow
  // ============================================================================

  /**
   * Refresh access token using refresh token
   */
  async refreshToken(refreshToken: string): Promise<TokenResponse> {
    const body = new URLSearchParams({
      grant_type: "refresh_token",
      refresh_token: refreshToken,
      client_id: this.config.clientId,
    });

    if (this.config.clientSecret) {
      body.append("client_secret", this.config.clientSecret);
    }

    const response = await fetch(this.config.tokenEndpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        Accept: "application/json",
      },
      body,
    });

    if (!response.ok) {
      const error = await response.json();
      throw new OAuthError(error.error, error.error_description);
    }

    return response.json();
  }

  // ============================================================================
  // Device Authorization Flow
  // ============================================================================

  /**
   * Start device authorization flow (for CLI/IoT applications)
   */
  async startDeviceAuthorization(deviceAuthorizationEndpoint: string): Promise<{
    device_code: string;
    user_code: string;
    verification_uri: string;
    verification_uri_complete?: string;
    expires_in: number;
    interval: number;
  }> {
    const body = new URLSearchParams({
      client_id: this.config.clientId,
      scope: this.config.scopes.join(" "),
    });

    const response = await fetch(deviceAuthorizationEndpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        Accept: "application/json",
      },
      body,
    });

    if (!response.ok) {
      const error = await response.json();
      throw new OAuthError(error.error, error.error_description);
    }

    return response.json();
  }

  /**
   * Poll for device authorization completion
   */
  async pollDeviceAuthorization(
    deviceCode: string,
    interval: number = 5000,
    timeout: number = 300000,
  ): Promise<TokenResponse> {
    const startTime = Date.now();

    while (Date.now() - startTime < timeout) {
      try {
        const body = new URLSearchParams({
          grant_type: "urn:ietf:params:oauth:grant-type:device_code",
          device_code: deviceCode,
          client_id: this.config.clientId,
        });

        const response = await fetch(this.config.tokenEndpoint, {
          method: "POST",
          headers: {
            "Content-Type": "application/x-www-form-urlencoded",
            Accept: "application/json",
          },
          body,
        });

        const data = await response.json();

        if (response.ok) {
          return data as TokenResponse;
        }

        if (data.error === "authorization_pending") {
          await this.sleep(interval);
          continue;
        }

        if (data.error === "slow_down") {
          interval += 5000;
          await this.sleep(interval);
          continue;
        }

        throw new OAuthError(data.error, data.error_description);
      } catch (error) {
        if (error instanceof OAuthError) throw error;
        await this.sleep(interval);
      }
    }

    throw new OAuthError("timeout", "Device authorization polling timed out");
  }

  // ============================================================================
  // UserInfo
  // ============================================================================

  /**
   * Get user information from userinfo endpoint
   */
  async getUserInfo(accessToken: string): Promise<UserInfo> {
    if (!this.config.userinfoEndpoint) {
      throw new OAuthError(
        "missing_endpoint",
        "Userinfo endpoint not configured",
      );
    }

    const response = await fetch(this.config.userinfoEndpoint, {
      headers: {
        Authorization: `Bearer ${accessToken}`,
        Accept: "application/json",
      },
    });

    if (!response.ok) {
      throw new OAuthError("userinfo_error", "Failed to fetch user info");
    }

    return response.json();
  }

  // ============================================================================
  // ID Token Validation
  // ============================================================================

  /**
   * Validate ID token (basic validation without full JWT verification)
   */
  private async validateIdToken(
    idToken: string,
    expectedNonce: string,
  ): Promise<void> {
    const [, payloadBase64] = idToken.split(".");
    const payload = JSON.parse(
      Buffer.from(payloadBase64, "base64url").toString(),
    );

    // Validate issuer
    if (this.config.issuer && payload.iss !== this.config.issuer) {
      throw new OAuthError("invalid_token", "Invalid issuer");
    }

    // Validate audience
    const aud = Array.isArray(payload.aud) ? payload.aud : [payload.aud];
    if (!aud.includes(this.config.clientId)) {
      throw new OAuthError("invalid_token", "Invalid audience");
    }

    // Validate nonce
    if (payload.nonce !== expectedNonce) {
      throw new OAuthError("invalid_token", "Invalid nonce");
    }

    // Validate expiration
    if (payload.exp && payload.exp * 1000 < Date.now()) {
      throw new OAuthError("invalid_token", "Token expired");
    }
  }

  // ============================================================================
  // Helper Methods
  // ============================================================================

  private generatePKCE(): { codeVerifier: string; codeChallenge: string } {
    const codeVerifier = crypto.randomBytes(32).toString("base64url");
    const codeChallenge = crypto
      .createHash("sha256")
      .update(codeVerifier)
      .digest("base64url");

    return { codeVerifier, codeChallenge };
  }

  private generateState(): string {
    return crypto.randomBytes(16).toString("hex");
  }

  private generateNonce(): string {
    return crypto.randomBytes(16).toString("hex");
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  /**
   * Clean up expired states
   */
  cleanupExpiredStates(maxAge: number = 600000): void {
    const now = Date.now();
    for (const [state, data] of this.stateStore) {
      if (now - data.createdAt > maxAge) {
        this.stateStore.delete(state);
      }
    }
  }
}

class OAuthError extends Error {
  constructor(
    public code: string,
    public description?: string,
  ) {
    super(`OAuth Error: ${code}${description ? ` - ${description}` : ""}`);
    this.name = "OAuthError";
  }
}

export { OAuth2Client, OAuthConfig, TokenResponse, UserInfo, OAuthError };
```

---

### Webhook Handler with Signature Verification

```typescript
/**
 * Universal Webhook Handler
 * With signature verification, idempotency, and async processing
 */
import crypto from "crypto";
import { EventEmitter } from "events";

// ============================================================================
// Types
// ============================================================================

interface WebhookConfig {
  provider: string;
  secret: string;
  signatureHeader: string;
  signatureAlgorithm: "sha256" | "sha512" | "sha1";
  signaturePrefix?: string;
  timestampHeader?: string;
  timestampTolerance?: number;
  signatureFormat?: "hex" | "base64";
}

interface WebhookEvent<T = unknown> {
  id: string;
  type: string;
  timestamp: Date;
  provider: string;
  data: T;
  raw: string;
  verified: boolean;
}

type WebhookEventHandler<T = unknown> = (
  event: WebhookEvent<T>,
) => Promise<void>;

// ============================================================================
// Provider Configurations
// ============================================================================

const providerConfigs: Record<string, Partial<WebhookConfig>> = {
  stripe: {
    signatureHeader: "stripe-signature",
    signatureAlgorithm: "sha256",
    timestampTolerance: 300,
  },
  github: {
    signatureHeader: "x-hub-signature-256",
    signatureAlgorithm: "sha256",
    signaturePrefix: "sha256=",
  },
  twilio: {
    signatureHeader: "x-twilio-signature",
    signatureAlgorithm: "sha1",
    signatureFormat: "base64",
  },
  shopify: {
    signatureHeader: "x-shopify-hmac-sha256",
    signatureAlgorithm: "sha256",
    signatureFormat: "base64",
  },
  slack: {
    signatureHeader: "x-slack-signature",
    signatureAlgorithm: "sha256",
    signaturePrefix: "v0=",
    timestampHeader: "x-slack-request-timestamp",
    timestampTolerance: 300,
  },
  sendgrid: {
    signatureHeader: "x-twilio-email-event-webhook-signature",
    signatureAlgorithm: "sha256",
    timestampHeader: "x-twilio-email-event-webhook-timestamp",
    timestampTolerance: 300,
  },
};

// ============================================================================
// Webhook Handler Implementation
// ============================================================================

class WebhookHandler extends EventEmitter {
  private config: WebhookConfig;
  private processedEvents: Set<string> = new Set();
  private eventHandlers: Map<string, WebhookEventHandler[]> = new Map();
  private maxCacheSize: number = 10000;
  private cacheCleanupInterval?: NodeJS.Timeout;

  constructor(config: WebhookConfig) {
    super();

    // Merge with provider defaults
    const providerDefaults = providerConfigs[config.provider] || {};
    this.config = { ...providerDefaults, ...config } as WebhookConfig;

    // Start cache cleanup
    this.cacheCleanupInterval = setInterval(() => this.cleanupCache(), 60000);
  }

  // ============================================================================
  // Signature Verification
  // ============================================================================

  /**
   * Verify webhook signature
   */
  verifySignature(
    payload: string | Buffer,
    signature: string,
    timestamp?: string,
  ): boolean {
    let expectedSignature: string;

    // Handle provider-specific signature computation
    if (this.config.provider === "stripe" && timestamp) {
      // Stripe uses timestamp.payload format
      const signedPayload = `${timestamp}.${payload}`;
      expectedSignature = this.computeSignature(signedPayload);
    } else if (this.config.provider === "slack" && timestamp) {
      // Slack uses v0:timestamp:body format
      const signedPayload = `v0:${timestamp}:${payload}`;
      expectedSignature = this.computeSignature(signedPayload);
    } else {
      expectedSignature = this.computeSignature(payload);
    }

    // Remove signature prefix if present
    let providedSignature = signature;
    if (this.config.signaturePrefix) {
      providedSignature = signature.replace(this.config.signaturePrefix, "");
    }

    // Constant-time comparison
    try {
      return crypto.timingSafeEqual(
        Buffer.from(expectedSignature),
        Buffer.from(providedSignature),
      );
    } catch {
      return false;
    }
  }

  private computeSignature(payload: string | Buffer): string {
    const signature = crypto
      .createHmac(this.config.signatureAlgorithm, this.config.secret)
      .update(payload)
      .digest(this.config.signatureFormat || "hex");

    return signature;
  }

  // ============================================================================
  // Timestamp Validation
  // ============================================================================

  /**
   * Verify timestamp for replay attack prevention
   */
  verifyTimestamp(timestamp: string | number): boolean {
    if (!this.config.timestampTolerance) return true;

    const eventTime =
      typeof timestamp === "string" ? parseInt(timestamp, 10) : timestamp;
    const now = Math.floor(Date.now() / 1000);
    const age = Math.abs(now - eventTime);

    return age <= this.config.timestampTolerance;
  }

  // ============================================================================
  // Event Processing
  // ============================================================================

  /**
   * Process incoming webhook
   */
  async processWebhook<T>(
    payload: string,
    headers: Record<string, string>,
  ): Promise<WebhookEvent<T>> {
    const normalizedHeaders = this.normalizeHeaders(headers);

    // Get signature
    const signature =
      normalizedHeaders[this.config.signatureHeader.toLowerCase()];
    if (!signature) {
      throw new WebhookError(
        "missing_signature",
        "Webhook signature header missing",
      );
    }

    // Get timestamp
    const timestamp = this.config.timestampHeader
      ? normalizedHeaders[this.config.timestampHeader.toLowerCase()]
      : undefined;

    // Verify timestamp
    if (timestamp && !this.verifyTimestamp(timestamp)) {
      throw new WebhookError("timestamp_expired", "Webhook timestamp too old");
    }

    // Verify signature
    if (!this.verifySignature(payload, signature, timestamp)) {
      throw new WebhookError(
        "invalid_signature",
        "Webhook signature verification failed",
      );
    }

    // Parse payload
    const data = JSON.parse(payload) as T & {
      id?: string;
      type?: string;
      event?: string;
    };

    // Generate event ID
    const eventId =
      (data as any).id ||
      crypto
        .createHash("sha256")
        .update(payload)
        .digest("hex")
        .substring(0, 32);

    // Check idempotency
    if (this.processedEvents.has(eventId)) {
      throw new WebhookError(
        "duplicate_event",
        "Webhook event already processed",
      );
    }

    // Mark as processed
    this.markProcessed(eventId);

    // Create event object
    const event: WebhookEvent<T> = {
      id: eventId,
      type: (data as any).type || (data as any).event || "unknown",
      timestamp: new Date(),
      provider: this.config.provider,
      data: data as T,
      raw: payload,
      verified: true,
    };

    // Emit events
    this.emit("webhook", event);
    this.emit(event.type, event);

    // Call registered handlers
    await this.callHandlers(event);

    return event;
  }

  // ============================================================================
  // Event Handler Registration
  // ============================================================================

  /**
   * Register handler for specific event type
   */
  onEvent<T>(eventType: string, handler: WebhookEventHandler<T>): void {
    const handlers = this.eventHandlers.get(eventType) || [];
    handlers.push(handler as WebhookEventHandler);
    this.eventHandlers.set(eventType, handlers);
  }

  /**
   * Register handler for all events
   */
  onAnyEvent<T>(handler: WebhookEventHandler<T>): void {
    this.onEvent("*", handler);
  }

  private async callHandlers(event: WebhookEvent): Promise<void> {
    const handlers = [
      ...(this.eventHandlers.get(event.type) || []),
      ...(this.eventHandlers.get("*") || []),
    ];

    for (const handler of handlers) {
      try {
        await handler(event);
      } catch (error) {
        this.emit("error", { event, error });
      }
    }
  }

  // ============================================================================
  // Idempotency Management
  // ============================================================================

  private markProcessed(eventId: string): void {
    if (this.processedEvents.size >= this.maxCacheSize) {
      // Remove oldest entries
      const entries = Array.from(this.processedEvents);
      entries.slice(0, entries.length / 2).forEach((id) => {
        this.processedEvents.delete(id);
      });
    }
    this.processedEvents.add(eventId);
  }

  isProcessed(eventId: string): boolean {
    return this.processedEvents.has(eventId);
  }

  private cleanupCache(): void {
    if (this.processedEvents.size > this.maxCacheSize * 0.8) {
      const entries = Array.from(this.processedEvents);
      entries.slice(0, entries.length / 2).forEach((id) => {
        this.processedEvents.delete(id);
      });
    }
  }

  // ============================================================================
  // Helper Methods
  // ============================================================================

  private normalizeHeaders(
    headers: Record<string, string>,
  ): Record<string, string> {
    return Object.fromEntries(
      Object.entries(headers).map(([k, v]) => [k.toLowerCase(), v]),
    );
  }

  /**
   * Generate test signature for testing
   */
  generateTestSignature(payload: string, timestamp?: string): string {
    let signedPayload = payload;

    if (this.config.provider === "stripe" && timestamp) {
      signedPayload = `${timestamp}.${payload}`;
    } else if (this.config.provider === "slack" && timestamp) {
      signedPayload = `v0:${timestamp}:${payload}`;
    }

    const signature = this.computeSignature(signedPayload);
    return this.config.signaturePrefix
      ? `${this.config.signaturePrefix}${signature}`
      : signature;
  }

  /**
   * Clean up resources
   */
  destroy(): void {
    if (this.cacheCleanupInterval) {
      clearInterval(this.cacheCleanupInterval);
    }
    this.processedEvents.clear();
    this.eventHandlers.clear();
  }
}

class WebhookError extends Error {
  constructor(
    public code: string,
    message: string,
  ) {
    super(message);
    this.name = "WebhookError";
  }
}

export {
  WebhookHandler,
  WebhookConfig,
  WebhookEvent,
  WebhookEventHandler,
  WebhookError,
  providerConfigs,
};
```

---

### Popular API Integrations

#### Stripe Integration

```typescript
/**
 * Production-Ready Stripe Integration
 */
import Stripe from "stripe";
import { ApiClient, ApiClientConfig } from "./api-client";
import { WebhookHandler } from "./webhook-handler";

interface StripeIntegrationConfig {
  secretKey: string;
  webhookSecret: string;
  apiVersion?: Stripe.LatestApiVersion;
}

class StripeIntegration {
  private stripe: Stripe;
  private webhookHandler: WebhookHandler;

  constructor(config: StripeIntegrationConfig) {
    this.stripe = new Stripe(config.secretKey, {
      apiVersion: config.apiVersion || "2024-12-18.acacia",
      maxNetworkRetries: 3,
      timeout: 30000,
    });

    this.webhookHandler = new WebhookHandler({
      provider: "stripe",
      secret: config.webhookSecret,
      signatureHeader: "stripe-signature",
      signatureAlgorithm: "sha256",
      timestampTolerance: 300,
    });
  }

  // ============================================================================
  // Customers
  // ============================================================================

  async createCustomer(
    params: Stripe.CustomerCreateParams,
  ): Promise<Stripe.Customer> {
    return this.stripe.customers.create(params);
  }

  async getCustomer(customerId: string): Promise<Stripe.Customer> {
    return this.stripe.customers.retrieve(
      customerId,
    ) as Promise<Stripe.Customer>;
  }

  async updateCustomer(
    customerId: string,
    params: Stripe.CustomerUpdateParams,
  ): Promise<Stripe.Customer> {
    return this.stripe.customers.update(customerId, params);
  }

  // ============================================================================
  // Payment Intents
  // ============================================================================

  async createPaymentIntent(
    params: Stripe.PaymentIntentCreateParams,
  ): Promise<Stripe.PaymentIntent> {
    return this.stripe.paymentIntents.create(params);
  }

  async confirmPaymentIntent(
    paymentIntentId: string,
    params?: Stripe.PaymentIntentConfirmParams,
  ): Promise<Stripe.PaymentIntent> {
    return this.stripe.paymentIntents.confirm(paymentIntentId, params);
  }

  async capturePaymentIntent(
    paymentIntentId: string,
    params?: Stripe.PaymentIntentCaptureParams,
  ): Promise<Stripe.PaymentIntent> {
    return this.stripe.paymentIntents.capture(paymentIntentId, params);
  }

  // ============================================================================
  // Subscriptions
  // ============================================================================

  async createSubscription(
    params: Stripe.SubscriptionCreateParams,
  ): Promise<Stripe.Subscription> {
    return this.stripe.subscriptions.create(params);
  }

  async cancelSubscription(
    subscriptionId: string,
    params?: Stripe.SubscriptionCancelParams,
  ): Promise<Stripe.Subscription> {
    return this.stripe.subscriptions.cancel(subscriptionId, params);
  }

  async updateSubscription(
    subscriptionId: string,
    params: Stripe.SubscriptionUpdateParams,
  ): Promise<Stripe.Subscription> {
    return this.stripe.subscriptions.update(subscriptionId, params);
  }

  // ============================================================================
  // Webhooks
  // ============================================================================

  async handleWebhook(
    payload: string,
    signature: string,
  ): Promise<Stripe.Event> {
    // Use Stripe's built-in verification
    const event = this.stripe.webhooks.constructEvent(
      payload,
      signature,
      this.webhookHandler["config"].secret,
    );

    // Process through our handler for idempotency
    await this.webhookHandler.processWebhook(payload, {
      "stripe-signature": signature,
    });

    return event;
  }

  onWebhookEvent(
    eventType: string,
    handler: (event: Stripe.Event) => Promise<void>,
  ): void {
    this.webhookHandler.onEvent(eventType, async (webhookEvent) => {
      await handler(webhookEvent.data as Stripe.Event);
    });
  }
}

export { StripeIntegration, StripeIntegrationConfig };
```

#### Twilio Integration

```typescript
/**
 * Production-Ready Twilio Integration
 */
import twilio from "twilio";
import { ApiClient } from "./api-client";
import { WebhookHandler } from "./webhook-handler";

interface TwilioIntegrationConfig {
  accountSid: string;
  authToken: string;
  fromNumber: string;
}

class TwilioIntegration {
  private client: twilio.Twilio;
  private fromNumber: string;
  private webhookHandler: WebhookHandler;

  constructor(config: TwilioIntegrationConfig) {
    this.client = twilio(config.accountSid, config.authToken);
    this.fromNumber = config.fromNumber;

    this.webhookHandler = new WebhookHandler({
      provider: "twilio",
      secret: config.authToken,
      signatureHeader: "x-twilio-signature",
      signatureAlgorithm: "sha1",
      signatureFormat: "base64",
    });
  }

  // ============================================================================
  // SMS
  // ============================================================================

  async sendSMS(
    to: string,
    body: string,
    options?: { mediaUrl?: string[] },
  ): Promise<twilio.Twilio.Api.V2010.MessageInstance> {
    return this.client.messages.create({
      to,
      from: this.fromNumber,
      body,
      mediaUrl: options?.mediaUrl,
    });
  }

  async getSMSStatus(
    messageSid: string,
  ): Promise<twilio.Twilio.Api.V2010.MessageInstance> {
    return this.client.messages(messageSid).fetch();
  }

  // ============================================================================
  // Voice
  // ============================================================================

  async makeCall(
    to: string,
    twimlOrUrl: string | URL,
  ): Promise<twilio.Twilio.Api.V2010.CallInstance> {
    const isUrl =
      typeof twimlOrUrl === "string" && twimlOrUrl.startsWith("http");

    return this.client.calls.create({
      to,
      from: this.fromNumber,
      url: isUrl ? twimlOrUrl : undefined,
      twiml: !isUrl ? (twimlOrUrl as string) : undefined,
    });
  }

  // ============================================================================
  // Verify (2FA)
  // ============================================================================

  async startVerification(
    to: string,
    channel: "sms" | "call" | "email" = "sms",
    verifyServiceSid: string,
  ): Promise<twilio.Twilio.Verify.V2.ServiceContext.VerificationInstance> {
    return this.client.verify.v2
      .services(verifyServiceSid)
      .verifications.create({ to, channel });
  }

  async checkVerification(
    to: string,
    code: string,
    verifyServiceSid: string,
  ): Promise<twilio.Twilio.Verify.V2.ServiceContext.VerificationCheckInstance> {
    return this.client.verify.v2
      .services(verifyServiceSid)
      .verificationChecks.create({ to, code });
  }

  // ============================================================================
  // Webhooks
  // ============================================================================

  validateWebhook(
    signature: string,
    url: string,
    params: Record<string, string>,
  ): boolean {
    return twilio.validateRequest(
      this.client["password"],
      signature,
      url,
      params,
    );
  }
}

export { TwilioIntegration, TwilioIntegrationConfig };
```

#### SendGrid Integration

```typescript
/**
 * Production-Ready SendGrid Integration
 */
import sgMail, { MailDataRequired } from "@sendgrid/mail";
import sgClient from "@sendgrid/client";
import { WebhookHandler } from "./webhook-handler";

interface SendGridIntegrationConfig {
  apiKey: string;
  webhookVerificationKey?: string;
  defaultFrom: {
    email: string;
    name?: string;
  };
}

interface EmailOptions {
  to: string | string[];
  subject: string;
  text?: string;
  html?: string;
  templateId?: string;
  dynamicTemplateData?: Record<string, unknown>;
  attachments?: Array<{
    content: string;
    filename: string;
    type?: string;
    disposition?: "attachment" | "inline";
  }>;
  categories?: string[];
  sendAt?: number;
}

class SendGridIntegration {
  private defaultFrom: { email: string; name?: string };
  private webhookHandler?: WebhookHandler;

  constructor(config: SendGridIntegrationConfig) {
    sgMail.setApiKey(config.apiKey);
    sgClient.setApiKey(config.apiKey);
    this.defaultFrom = config.defaultFrom;

    if (config.webhookVerificationKey) {
      this.webhookHandler = new WebhookHandler({
        provider: "sendgrid",
        secret: config.webhookVerificationKey,
        signatureHeader: "x-twilio-email-event-webhook-signature",
        signatureAlgorithm: "sha256",
        timestampHeader: "x-twilio-email-event-webhook-timestamp",
        timestampTolerance: 300,
      });
    }
  }

  // ============================================================================
  // Email Sending
  // ============================================================================

  async sendEmail(options: EmailOptions): Promise<void> {
    const msg: MailDataRequired = {
      to: options.to,
      from: this.defaultFrom,
      subject: options.subject,
      text: options.text,
      html: options.html,
      templateId: options.templateId,
      dynamicTemplateData: options.dynamicTemplateData,
      attachments: options.attachments,
      categories: options.categories,
      sendAt: options.sendAt,
    };

    await sgMail.send(msg);
  }

  async sendBulkEmail(messages: EmailOptions[]): Promise<void> {
    const msgs: MailDataRequired[] = messages.map((msg) => ({
      to: msg.to,
      from: this.defaultFrom,
      subject: msg.subject,
      text: msg.text,
      html: msg.html,
      templateId: msg.templateId,
      dynamicTemplateData: msg.dynamicTemplateData,
    }));

    // SendGrid recommends batches of 1000
    const batchSize = 1000;
    for (let i = 0; i < msgs.length; i += batchSize) {
      const batch = msgs.slice(i, i + batchSize);
      await sgMail.send(batch);
    }
  }

  // ============================================================================
  // Templates
  // ============================================================================

  async getTemplates(): Promise<any[]> {
    const [response] = await sgClient.request({
      method: "GET",
      url: "/v3/templates",
      qs: { generations: "dynamic" },
    });
    return (response.body as any).templates;
  }

  // ============================================================================
  // Statistics
  // ============================================================================

  async getStats(startDate: string, endDate: string): Promise<any> {
    const [response] = await sgClient.request({
      method: "GET",
      url: "/v3/stats",
      qs: {
        start_date: startDate,
        end_date: endDate,
      },
    });
    return response.body;
  }

  // ============================================================================
  // Webhooks
  // ============================================================================

  async handleWebhook(
    payload: string,
    headers: Record<string, string>,
  ): Promise<SendGridEvent[]> {
    if (!this.webhookHandler) {
      throw new Error("Webhook handler not configured");
    }

    const event = await this.webhookHandler.processWebhook<SendGridEvent[]>(
      payload,
      headers,
    );
    return event.data;
  }

  onWebhookEvent(
    eventType: SendGridEventType,
    handler: (event: SendGridEvent) => Promise<void>,
  ): void {
    if (!this.webhookHandler) return;

    this.webhookHandler.onEvent("*", async (webhookEvent) => {
      const events = webhookEvent.data as SendGridEvent[];
      for (const event of events) {
        if (event.event === eventType) {
          await handler(event);
        }
      }
    });
  }
}

type SendGridEventType =
  | "processed"
  | "dropped"
  | "delivered"
  | "deferred"
  | "bounce"
  | "open"
  | "click"
  | "spamreport"
  | "unsubscribe";

interface SendGridEvent {
  email: string;
  timestamp: number;
  event: SendGridEventType;
  sg_event_id: string;
  sg_message_id: string;
  category?: string[];
  reason?: string;
  url?: string;
}

export {
  SendGridIntegration,
  SendGridIntegrationConfig,
  EmailOptions,
  SendGridEvent,
  SendGridEventType,
};
```

---

## Error Handling Patterns

```typescript
/**
 * Unified API Error Handling
 */

// ============================================================================
// Error Types
// ============================================================================

interface ApiErrorDetails {
  provider: string;
  code: string;
  message: string;
  statusCode?: number;
  retryable: boolean;
  details?: Record<string, unknown>;
  originalError?: Error;
}

class ApiIntegrationError extends Error {
  constructor(public details: ApiErrorDetails) {
    super(`[${details.provider}] ${details.code}: ${details.message}`);
    this.name = "ApiIntegrationError";
  }

  get isRetryable(): boolean {
    return this.details.retryable;
  }

  toJSON(): Record<string, unknown> {
    return {
      name: this.name,
      message: this.message,
      ...this.details,
    };
  }
}

// ============================================================================
// Error Normalizers
// ============================================================================

const errorNormalizers: Record<string, (error: unknown) => ApiErrorDetails> = {
  stripe: (error: any) => ({
    provider: "stripe",
    code: error.code || error.type || "unknown",
    message: error.message || "Unknown Stripe error",
    statusCode: error.statusCode,
    retryable: ["rate_limit", "api_connection_error", "api_error"].includes(
      error.type,
    ),
    details: {
      declineCode: error.decline_code,
      param: error.param,
      requestId: error.requestId,
    },
  }),

  twilio: (error: any) => ({
    provider: "twilio",
    code: String(error.code || "unknown"),
    message: error.message || "Unknown Twilio error",
    statusCode: error.status,
    retryable: [429, 500, 502, 503, 504].includes(error.status),
    details: {
      moreInfo: error.moreInfo,
    },
  }),

  sendgrid: (error: any) => ({
    provider: "sendgrid",
    code: error.response?.body?.errors?.[0]?.field || error.code || "unknown",
    message:
      error.response?.body?.errors?.[0]?.message ||
      error.message ||
      "Unknown SendGrid error",
    statusCode: error.code,
    retryable: [429, 500, 502, 503, 504].includes(error.code),
    details: {
      errors: error.response?.body?.errors,
    },
  }),

  github: (error: any) => ({
    provider: "github",
    code: error.status?.toString() || "unknown",
    message: error.message || "Unknown GitHub error",
    statusCode: error.status,
    retryable: [429, 500, 502, 503, 504].includes(error.status),
    details: {
      documentation_url: error.documentation_url,
    },
  }),

  generic: (error: any) => ({
    provider: "unknown",
    code: error.code || error.status?.toString() || "unknown",
    message: error.message || "Unknown API error",
    statusCode: error.status || error.statusCode,
    retryable: false,
    details: {},
  }),
};

/**
 * Normalize any API error to a standard format
 */
function normalizeApiError(
  provider: string,
  error: unknown,
): ApiIntegrationError {
  const normalizer = errorNormalizers[provider] || errorNormalizers.generic;
  const details = normalizer(error);
  details.originalError = error instanceof Error ? error : undefined;

  return new ApiIntegrationError(details);
}

export { ApiIntegrationError, ApiErrorDetails, normalizeApiError };
```

---

## Testing Utilities

```typescript
/**
 * API Integration Testing Utilities
 */
import crypto from "crypto";

// ============================================================================
// Mock Server
// ============================================================================

interface MockResponse {
  status: number;
  data: unknown;
  headers?: Record<string, string>;
  delay?: number;
}

class MockApiServer {
  private responses: Map<string, MockResponse[]> = new Map();
  private requests: Array<{
    method: string;
    path: string;
    body: unknown;
    headers: Record<string, string>;
  }> = [];

  mockResponse(method: string, path: string, response: MockResponse): void {
    const key = `${method.toUpperCase()}:${path}`;
    const existing = this.responses.get(key) || [];
    existing.push(response);
    this.responses.set(key, existing);
  }

  getResponse(method: string, path: string): MockResponse | undefined {
    const key = `${method.toUpperCase()}:${path}`;
    const responses = this.responses.get(key);
    return responses?.shift();
  }

  recordRequest(
    method: string,
    path: string,
    body: unknown,
    headers: Record<string, string>,
  ): void {
    this.requests.push({ method, path, body, headers });
  }

  getRequests(): typeof this.requests {
    return [...this.requests];
  }

  reset(): void {
    this.responses.clear();
    this.requests = [];
  }
}

// ============================================================================
// Webhook Test Helpers
// ============================================================================

/**
 * Generate valid webhook signature for testing
 */
function generateWebhookSignature(
  payload: string,
  secret: string,
  options: {
    algorithm?: "sha256" | "sha512" | "sha1";
    format?: "hex" | "base64";
    prefix?: string;
    timestamp?: number;
    provider?: "stripe" | "github" | "slack";
  } = {},
): { signature: string; timestamp?: string } {
  const {
    algorithm = "sha256",
    format = "hex",
    prefix = "",
    timestamp = Math.floor(Date.now() / 1000),
    provider,
  } = options;

  let signedPayload = payload;

  // Handle provider-specific formats
  if (provider === "stripe") {
    signedPayload = `${timestamp}.${payload}`;
  } else if (provider === "slack") {
    signedPayload = `v0:${timestamp}:${payload}`;
  }

  const signature = crypto
    .createHmac(algorithm, secret)
    .update(signedPayload)
    .digest(format);

  return {
    signature: `${prefix}${signature}`,
    timestamp: provider ? timestamp.toString() : undefined,
  };
}

// ============================================================================
// Test Fixtures
// ============================================================================

const testFixtures = {
  stripe: {
    paymentIntent: {
      id: "pi_test_123",
      object: "payment_intent",
      amount: 2000,
      currency: "usd",
      status: "succeeded",
    },
    webhookEvent: {
      id: "evt_test_123",
      object: "event",
      type: "payment_intent.succeeded",
      data: {
        object: {
          id: "pi_test_123",
          amount: 2000,
          status: "succeeded",
        },
      },
    },
  },

  twilio: {
    message: {
      sid: "SM_test_123",
      status: "queued",
      to: "+1234567890",
      from: "+0987654321",
      body: "Test message",
    },
  },

  sendgrid: {
    webhookEvents: [
      {
        email: "test@example.com",
        timestamp: 1609459200,
        event: "delivered",
        sg_event_id: "evt_test_123",
        sg_message_id: "msg_test_123",
      },
    ],
  },
};

export { MockApiServer, MockResponse, generateWebhookSignature, testFixtures };
```

---

## Best Practices Checklist

### Implementation Checklist

- [ ] **API Client Design**
  - [ ] Use typed request/response interfaces
  - [ ] Implement proper timeout handling
  - [ ] Add request/response logging
  - [ ] Support pagination with async generators

- [ ] **Authentication**
  - [ ] Use PKCE for OAuth authorization code flow
  - [ ] Implement secure token storage
  - [ ] Add proactive token refresh
  - [ ] Support multiple auth mechanisms

- [ ] **Rate Limiting**
  - [ ] Implement token bucket algorithm
  - [ ] Parse and respect rate limit headers
  - [ ] Queue requests when approaching limits
  - [ ] Add request prioritization

- [ ] **Retry Logic**
  - [ ] Use exponential backoff with jitter
  - [ ] Respect Retry-After headers
  - [ ] Define retryable status codes
  - [ ] Set maximum retry limits

- [ ] **Circuit Breaker**
  - [ ] Configure failure thresholds
  - [ ] Implement half-open state testing
  - [ ] Add monitoring and alerting
  - [ ] Support manual reset

- [ ] **Webhook Security**
  - [ ] Verify HMAC signatures
  - [ ] Validate timestamps
  - [ ] Implement idempotency
  - [ ] Process asynchronously

- [ ] **Error Handling**
  - [ ] Normalize provider-specific errors
  - [ ] Implement recovery strategies
  - [ ] Add structured logging
  - [ ] Surface actionable errors

- [ ] **Testing**
  - [ ] Mock external APIs
  - [ ] Test rate limiting behavior
  - [ ] Verify signature validation
  - [ ] Test circuit breaker transitions

---

## Example Invocations

```bash
# Create a production Stripe integration
/agents/integration/api-integration-expert implement Stripe payment integration with subscriptions

# Build a GraphQL client
/agents/integration/api-integration-expert create type-safe GraphQL client with caching

# Implement OAuth 2.0 flow
/agents/integration/api-integration-expert implement OAuth 2.0 authorization code flow with PKCE

# Set up webhook handling
/agents/integration/api-integration-expert create webhook handler for Stripe and GitHub

# Add resilience patterns
/agents/integration/api-integration-expert add circuit breaker and retry logic to API client

# Generate SDK wrapper
/agents/integration/api-integration-expert create TypeScript SDK for REST API

# Implement rate limiting
/agents/integration/api-integration-expert implement intelligent rate limiting with token bucket
```

---

## Related Agents

| Agent                                        | Use Case                       |
| -------------------------------------------- | ------------------------------ |
| `/agents/backend/api-architect`              | API design and OpenAPI specs   |
| `/agents/backend/authentication-specialist`  | OAuth and OIDC implementation  |
| `/agents/integration/webhook-expert`         | Advanced webhook patterns      |
| `/agents/integration/third-party-api-expert` | Provider-specific integrations |
| `/agents/testing/api-test-expert`            | API testing strategies         |
| `/agents/security/security-expert`           | Security review                |

---

## Deliverables

When invoked, this agent produces:

1. **API Client Implementation** - Type-safe HTTP client with all resilience patterns
2. **Authentication Module** - OAuth 2.0/OIDC flows with secure token management
3. **Webhook Handler** - Signature verification, idempotency, async processing
4. **Rate Limiter** - Token bucket implementation with header parsing
5. **Circuit Breaker** - Failure detection and recovery
6. **Error Handler** - Normalized error handling with recovery strategies
7. **Test Suite** - Unit and integration tests with mocks
8. **OpenAPI Spec** - API documentation (if applicable)

---

## References

- [OAuth 2.0 RFC 6749](https://tools.ietf.org/html/rfc6749)
- [OAuth 2.0 PKCE RFC 7636](https://tools.ietf.org/html/rfc7636)
- [OpenID Connect Core](https://openid.net/specs/openid-connect-core-1_0.html)
- [Stripe API Documentation](https://stripe.com/docs/api)
- [Twilio API Documentation](https://www.twilio.com/docs/usage/api)
- [SendGrid API Documentation](https://docs.sendgrid.com/api-reference)
- [Circuit Breaker Pattern](https://martinfowler.com/bliki/CircuitBreaker.html)
- [Token Bucket Algorithm](https://en.wikipedia.org/wiki/Token_bucket)

---

_Agent Version: 2.0.0 | Category: Integration | Author: Ahmed Adel Bakr Alderai_
