---
name: Third-Party API Expert
description: Expert in external API integrations including OAuth, rate limiting, webhooks, and provider SDKs
version: 2.0.0
category: integration
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - Task
triggers:
  - third-party
  - external-api
  - oauth
  - stripe
  - twilio
  - sendgrid
  - webhook
  - rate-limit
  - api-integration
related_agents:
  - api-test-expert
  - webhook-expert
  - api-integration-expert
  - authentication-specialist
  - security-expert
---

# Third-Party API Expert Agent

Expert in external API integrations, OAuth flows, rate limiting, retry strategies, webhook handling, and API versioning. Specializes in production-ready integrations with major providers.

## Arguments

- `$ARGUMENTS` - Third-party API integration task

## Invoke Agent

```
Use the Task tool with subagent_type="third-party-api-expert" to:

1. Implement OAuth 2.0 / OAuth 2.1 flows
2. Handle rate limits with intelligent backoff
3. Build retry strategies with circuit breakers
4. Process webhooks securely
5. Manage API version compatibility
6. Create provider-specific integrations

Task: $ARGUMENTS
```

---

## Core Expertise Areas

### 1. OAuth Flow Implementation

#### OAuth 2.0 Authorization Code Flow (with PKCE)

```typescript
import crypto from "crypto";

interface OAuthConfig {
  clientId: string;
  clientSecret: string;
  redirectUri: string;
  authorizationEndpoint: string;
  tokenEndpoint: string;
  scopes: string[];
}

interface TokenResponse {
  access_token: string;
  refresh_token?: string;
  expires_in: number;
  token_type: string;
  scope?: string;
}

class OAuth2Client {
  private config: OAuthConfig;
  private stateStore: Map<string, { codeVerifier: string; timestamp: number }> =
    new Map();

  constructor(config: OAuthConfig) {
    this.config = config;
  }

  // Generate PKCE challenge
  private generatePKCE(): { codeVerifier: string; codeChallenge: string } {
    const codeVerifier = crypto.randomBytes(32).toString("base64url");
    const codeChallenge = crypto
      .createHash("sha256")
      .update(codeVerifier)
      .digest("base64url");
    return { codeVerifier, codeChallenge };
  }

  // Generate authorization URL
  getAuthorizationUrl(): { url: string; state: string } {
    const state = crypto.randomBytes(16).toString("hex");
    const { codeVerifier, codeChallenge } = this.generatePKCE();

    // Store state with code verifier (expires in 10 minutes)
    this.stateStore.set(state, {
      codeVerifier,
      timestamp: Date.now(),
    });

    const params = new URLSearchParams({
      response_type: "code",
      client_id: this.config.clientId,
      redirect_uri: this.config.redirectUri,
      scope: this.config.scopes.join(" "),
      state,
      code_challenge: codeChallenge,
      code_challenge_method: "S256",
    });

    return {
      url: `${this.config.authorizationEndpoint}?${params.toString()}`,
      state,
    };
  }

  // Exchange authorization code for tokens
  async exchangeCode(code: string, state: string): Promise<TokenResponse> {
    const storedState = this.stateStore.get(state);

    if (!storedState) {
      throw new Error("Invalid or expired state parameter");
    }

    // Check state expiration (10 minutes)
    if (Date.now() - storedState.timestamp > 600000) {
      this.stateStore.delete(state);
      throw new Error("State parameter expired");
    }

    const response = await fetch(this.config.tokenEndpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        Accept: "application/json",
      },
      body: new URLSearchParams({
        grant_type: "authorization_code",
        code,
        redirect_uri: this.config.redirectUri,
        client_id: this.config.clientId,
        client_secret: this.config.clientSecret,
        code_verifier: storedState.codeVerifier,
      }),
    });

    this.stateStore.delete(state);

    if (!response.ok) {
      const error = await response.json();
      throw new OAuthError(error.error, error.error_description);
    }

    return response.json();
  }

  // Refresh access token
  async refreshToken(refreshToken: string): Promise<TokenResponse> {
    const response = await fetch(this.config.tokenEndpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        Accept: "application/json",
      },
      body: new URLSearchParams({
        grant_type: "refresh_token",
        refresh_token: refreshToken,
        client_id: this.config.clientId,
        client_secret: this.config.clientSecret,
      }),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new OAuthError(error.error, error.error_description);
    }

    return response.json();
  }
}

class OAuthError extends Error {
  constructor(
    public code: string,
    public description?: string,
  ) {
    super(`OAuth Error: ${code} - ${description || "Unknown error"}`);
    this.name = "OAuthError";
  }
}
```

#### OAuth 2.0 Client Credentials Flow

```typescript
class ClientCredentialsFlow {
  private tokenCache: { token: string; expiresAt: number } | null = null;

  constructor(
    private clientId: string,
    private clientSecret: string,
    private tokenEndpoint: string,
    private scopes: string[] = [],
  ) {}

  async getAccessToken(): Promise<string> {
    // Return cached token if still valid (with 5-minute buffer)
    if (this.tokenCache && this.tokenCache.expiresAt > Date.now() + 300000) {
      return this.tokenCache.token;
    }

    const response = await fetch(this.tokenEndpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        Authorization: `Basic ${Buffer.from(`${this.clientId}:${this.clientSecret}`).toString("base64")}`,
      },
      body: new URLSearchParams({
        grant_type: "client_credentials",
        scope: this.scopes.join(" "),
      }),
    });

    if (!response.ok) {
      throw new Error(`Token request failed: ${response.status}`);
    }

    const data: TokenResponse = await response.json();

    this.tokenCache = {
      token: data.access_token,
      expiresAt: Date.now() + data.expires_in * 1000,
    };

    return data.access_token;
  }
}
```

---

### 2. Rate Limit Handling

#### Intelligent Rate Limiter with Token Bucket

```typescript
interface RateLimitConfig {
  maxRequests: number; // Maximum requests per window
  windowMs: number; // Time window in milliseconds
  retryAfterHeader: string; // Header name for retry-after
  rateLimitHeaders: {
    limit: string;
    remaining: string;
    reset: string;
  };
}

class RateLimiter {
  private tokens: number;
  private lastRefill: number;
  private queue: Array<{
    resolve: (value: void) => void;
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

    // Wait for next token
    return new Promise((resolve, reject) => {
      this.queue.push({ resolve, reject });

      // Process queue when tokens refill
      setTimeout(() => {
        this.refillTokens();
        this.processQueue();
      }, this.config.windowMs / this.config.maxRequests);
    });
  }

  private processQueue(): void {
    while (this.queue.length > 0 && this.tokens > 0) {
      const { resolve } = this.queue.shift()!;
      this.tokens--;
      resolve();
    }
  }

  // Update limits from response headers
  updateFromResponse(headers: Headers): void {
    const remaining = headers.get(this.config.rateLimitHeaders.remaining);
    const reset = headers.get(this.config.rateLimitHeaders.reset);

    if (remaining !== null) {
      this.tokens = Math.min(this.tokens, parseInt(remaining, 10));
    }

    if (reset !== null) {
      // Handle both Unix timestamp and seconds until reset
      const resetValue = parseInt(reset, 10);
      const resetTime =
        resetValue > 1e10 ? resetValue : Date.now() + resetValue * 1000;
      this.lastRefill = resetTime - this.config.windowMs;
    }
  }

  // Get wait time from 429 response
  getRetryAfter(headers: Headers): number {
    const retryAfter = headers.get(this.config.retryAfterHeader);

    if (!retryAfter) {
      return this.config.windowMs; // Default wait
    }

    // Handle both seconds and HTTP-date format
    const seconds = parseInt(retryAfter, 10);
    if (!isNaN(seconds)) {
      return seconds * 1000;
    }

    const date = new Date(retryAfter);
    return Math.max(0, date.getTime() - Date.now());
  }
}
```

#### Provider-Specific Rate Limit Configurations

```typescript
const rateLimitConfigs: Record<string, RateLimitConfig> = {
  stripe: {
    maxRequests: 100,
    windowMs: 1000, // 100 requests per second
    retryAfterHeader: "Retry-After",
    rateLimitHeaders: {
      limit: "X-RateLimit-Limit",
      remaining: "X-RateLimit-Remaining",
      reset: "X-RateLimit-Reset",
    },
  },
  twilio: {
    maxRequests: 100,
    windowMs: 1000,
    retryAfterHeader: "Retry-After",
    rateLimitHeaders: {
      limit: "X-Rate-Limit-Limit",
      remaining: "X-Rate-Limit-Remaining",
      reset: "X-Rate-Limit-Reset",
    },
  },
  sendgrid: {
    maxRequests: 600,
    windowMs: 60000, // 600 requests per minute
    retryAfterHeader: "Retry-After",
    rateLimitHeaders: {
      limit: "X-RateLimit-Limit",
      remaining: "X-RateLimit-Remaining",
      reset: "X-RateLimit-Reset",
    },
  },
  github: {
    maxRequests: 5000,
    windowMs: 3600000, // 5000 requests per hour
    retryAfterHeader: "Retry-After",
    rateLimitHeaders: {
      limit: "X-RateLimit-Limit",
      remaining: "X-RateLimit-Remaining",
      reset: "X-RateLimit-Reset",
    },
  },
};
```

---

### 3. Retry Strategies with Backoff

#### Exponential Backoff with Jitter

```typescript
interface RetryConfig {
  maxRetries: number;
  baseDelayMs: number;
  maxDelayMs: number;
  jitterFactor: number; // 0-1, adds randomness to prevent thundering herd
  retryableStatuses: number[];
  retryableErrors: string[];
}

const defaultRetryConfig: RetryConfig = {
  maxRetries: 3,
  baseDelayMs: 1000,
  maxDelayMs: 30000,
  jitterFactor: 0.2,
  retryableStatuses: [408, 429, 500, 502, 503, 504],
  retryableErrors: ["ECONNRESET", "ETIMEDOUT", "ENOTFOUND", "EAI_AGAIN"],
};

class RetryHandler {
  constructor(private config: RetryConfig = defaultRetryConfig) {}

  private calculateDelay(attempt: number, retryAfterMs?: number): number {
    if (retryAfterMs) {
      return retryAfterMs;
    }

    // Exponential backoff: base * 2^attempt
    const exponentialDelay = this.config.baseDelayMs * Math.pow(2, attempt);
    const cappedDelay = Math.min(exponentialDelay, this.config.maxDelayMs);

    // Add jitter to prevent thundering herd
    const jitter = cappedDelay * this.config.jitterFactor * Math.random();
    return cappedDelay + jitter;
  }

  private isRetryable(error: Error | Response): boolean {
    if (error instanceof Response) {
      return this.config.retryableStatuses.includes(error.status);
    }

    if (error instanceof Error) {
      return this.config.retryableErrors.some(
        (code) => error.message.includes(code) || (error as any).code === code,
      );
    }

    return false;
  }

  async execute<T>(
    operation: () => Promise<T>,
    context?: { rateLimiter?: RateLimiter },
  ): Promise<T> {
    let lastError: Error | undefined;

    for (let attempt = 0; attempt <= this.config.maxRetries; attempt++) {
      try {
        // Acquire rate limit token if provided
        if (context?.rateLimiter) {
          await context.rateLimiter.acquire();
        }

        const result = await operation();
        return result;
      } catch (error) {
        lastError = error as Error;

        // Check if response is retryable
        if (!this.isRetryable(error as Error | Response)) {
          throw error;
        }

        if (attempt === this.config.maxRetries) {
          throw new RetryExhaustedError(
            `Max retries (${this.config.maxRetries}) exceeded`,
            lastError,
          );
        }

        // Calculate delay
        let retryAfterMs: number | undefined;
        if (error instanceof Response && error.status === 429) {
          retryAfterMs = context?.rateLimiter?.getRetryAfter(error.headers);
        }

        const delay = this.calculateDelay(attempt, retryAfterMs);

        console.log(
          `Retry attempt ${attempt + 1}/${this.config.maxRetries} after ${delay}ms`,
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
```

#### Circuit Breaker Pattern

```typescript
enum CircuitState {
  CLOSED = "CLOSED",
  OPEN = "OPEN",
  HALF_OPEN = "HALF_OPEN",
}

interface CircuitBreakerConfig {
  failureThreshold: number; // Failures before opening
  successThreshold: number; // Successes to close from half-open
  timeout: number; // Time in open state before half-open
  monitoringWindow: number; // Time window for failure counting
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
        throw new CircuitOpenError("Circuit breaker is open");
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

    // Remove failures outside monitoring window
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
```

---

### 4. Webhook Handling

#### Secure Webhook Processor

```typescript
import crypto from "crypto";
import { EventEmitter } from "events";

interface WebhookConfig {
  secret: string;
  signatureHeader: string;
  signatureAlgorithm: "sha256" | "sha512";
  signaturePrefix?: string; // e.g., 'sha256=' for GitHub
  timestampHeader?: string; // For replay attack prevention
  timestampTolerance?: number; // Max age in seconds
}

interface WebhookEvent<T = unknown> {
  id: string;
  type: string;
  timestamp: Date;
  data: T;
  raw: string;
}

class WebhookProcessor extends EventEmitter {
  private processedEvents: Set<string> = new Set();
  private maxCacheSize: number = 10000;

  constructor(private config: WebhookConfig) {
    super();
  }

  // Verify webhook signature
  verifySignature(payload: string | Buffer, signature: string): boolean {
    const expectedSignature = this.computeSignature(payload);

    const providedSig = this.config.signaturePrefix
      ? signature.replace(this.config.signaturePrefix, "")
      : signature;

    try {
      return crypto.timingSafeEqual(
        Buffer.from(expectedSignature, "hex"),
        Buffer.from(providedSig, "hex"),
      );
    } catch {
      return false;
    }
  }

  private computeSignature(payload: string | Buffer): string {
    return crypto
      .createHmac(this.config.signatureAlgorithm, this.config.secret)
      .update(payload)
      .digest("hex");
  }

  // Check timestamp for replay attack prevention
  verifyTimestamp(timestamp: string | number): boolean {
    if (!this.config.timestampTolerance) {
      return true;
    }

    const eventTime =
      typeof timestamp === "string" ? parseInt(timestamp, 10) : timestamp;

    const now = Math.floor(Date.now() / 1000);
    const age = Math.abs(now - eventTime);

    return age <= this.config.timestampTolerance;
  }

  // Process webhook with idempotency
  async processWebhook<T>(
    payload: string,
    headers: Record<string, string>,
  ): Promise<WebhookEvent<T>> {
    // Verify signature
    const signature = headers[this.config.signatureHeader.toLowerCase()];
    if (!signature || !this.verifySignature(payload, signature)) {
      throw new WebhookError("Invalid webhook signature", "INVALID_SIGNATURE");
    }

    // Verify timestamp
    if (this.config.timestampHeader) {
      const timestamp = headers[this.config.timestampHeader.toLowerCase()];
      if (!timestamp || !this.verifyTimestamp(timestamp)) {
        throw new WebhookError(
          "Webhook timestamp too old",
          "TIMESTAMP_EXPIRED",
        );
      }
    }

    // Parse payload
    const data = JSON.parse(payload) as T & { id?: string; type?: string };

    // Check for idempotency
    const eventId =
      (data as any).id ||
      crypto.createHash("sha256").update(payload).digest("hex");

    if (this.processedEvents.has(eventId)) {
      throw new WebhookError("Duplicate webhook event", "DUPLICATE_EVENT");
    }

    // Add to processed cache (with size limit)
    if (this.processedEvents.size >= this.maxCacheSize) {
      const firstEvent = this.processedEvents.values().next().value;
      this.processedEvents.delete(firstEvent);
    }
    this.processedEvents.add(eventId);

    const event: WebhookEvent<T> = {
      id: eventId,
      type: (data as any).type || "unknown",
      timestamp: new Date(),
      data: data as T,
      raw: payload,
    };

    // Emit event for async processing
    this.emit("webhook", event);
    this.emit(event.type, event);

    return event;
  }
}

class WebhookError extends Error {
  constructor(
    message: string,
    public code: string,
  ) {
    super(message);
    this.name = "WebhookError";
  }
}
```

#### Webhook Handler Express Middleware

```typescript
import express, { Request, Response, NextFunction } from "express";

function createWebhookMiddleware(
  processor: WebhookProcessor,
  options: { path: string },
) {
  const router = express.Router();

  router.post(
    options.path,
    express.raw({ type: "application/json" }),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const payload = req.body.toString("utf-8");
        const headers = Object.fromEntries(
          Object.entries(req.headers).map(([k, v]) => [k, String(v)]),
        );

        const event = await processor.processWebhook(payload, headers);

        // Acknowledge receipt immediately
        res.status(200).json({ received: true, eventId: event.id });
      } catch (error) {
        if (error instanceof WebhookError) {
          const statusMap: Record<string, number> = {
            INVALID_SIGNATURE: 401,
            TIMESTAMP_EXPIRED: 400,
            DUPLICATE_EVENT: 200, // Return 200 for duplicates
          };

          return res.status(statusMap[error.code] || 400).json({
            error: error.code,
            message: error.message,
          });
        }
        next(error);
      }
    },
  );

  return router;
}
```

---

### 5. API Versioning Compatibility

#### Version-Aware API Client

```typescript
interface VersionConfig {
  currentVersion: string;
  supportedVersions: string[];
  deprecatedVersions: string[];
  versionHeader?: string;
  versionQueryParam?: string;
  versionPathPrefix?: boolean;
}

interface VersionedResponse<T> {
  data: T;
  apiVersion: string;
  deprecationWarning?: string;
}

class VersionedApiClient {
  private version: string;

  constructor(
    private baseUrl: string,
    private config: VersionConfig,
  ) {
    this.version = config.currentVersion;
  }

  setVersion(version: string): void {
    if (!this.config.supportedVersions.includes(version)) {
      throw new Error(`API version ${version} is not supported`);
    }
    this.version = version;
  }

  private buildUrl(path: string): string {
    if (this.config.versionPathPrefix) {
      return `${this.baseUrl}/v${this.version}${path}`;
    }

    const url = new URL(path, this.baseUrl);
    if (this.config.versionQueryParam) {
      url.searchParams.set(this.config.versionQueryParam, this.version);
    }
    return url.toString();
  }

  private buildHeaders(customHeaders?: Record<string, string>): Headers {
    const headers = new Headers(customHeaders);

    if (this.config.versionHeader) {
      headers.set(this.config.versionHeader, this.version);
    }

    return headers;
  }

  async request<T>(
    path: string,
    options: RequestInit = {},
  ): Promise<VersionedResponse<T>> {
    const url = this.buildUrl(path);
    const headers = this.buildHeaders(
      options.headers as Record<string, string>,
    );

    const response = await fetch(url, { ...options, headers });

    if (!response.ok) {
      throw new ApiError(response.status, await response.text());
    }

    const data = (await response.json()) as T;
    const responseVersion = response.headers.get(
      this.config.versionHeader || "",
    );

    return {
      data,
      apiVersion: responseVersion || this.version,
      deprecationWarning: this.config.deprecatedVersions.includes(this.version)
        ? `API version ${this.version} is deprecated`
        : undefined,
    };
  }

  // Version migration helper
  async migrateData<TFrom, TTo>(
    data: TFrom,
    fromVersion: string,
    toVersion: string,
    migrators: Record<string, (data: any) => any>,
  ): Promise<TTo> {
    const versions = this.config.supportedVersions;
    const fromIndex = versions.indexOf(fromVersion);
    const toIndex = versions.indexOf(toVersion);

    if (fromIndex === -1 || toIndex === -1) {
      throw new Error("Invalid version for migration");
    }

    let result: any = data;
    const direction = fromIndex < toIndex ? 1 : -1;

    for (let i = fromIndex; i !== toIndex; i += direction) {
      const currentVersion = versions[i];
      const nextVersion = versions[i + direction];
      const migratorKey = `${currentVersion}->${nextVersion}`;

      if (migrators[migratorKey]) {
        result = migrators[migratorKey](result);
      }
    }

    return result as TTo;
  }
}

class ApiError extends Error {
  constructor(
    public status: number,
    public body: string,
  ) {
    super(`API Error ${status}: ${body}`);
    this.name = "ApiError";
  }
}
```

---

## Provider Templates

### Stripe Integration

```typescript
import Stripe from "stripe";

interface StripeConfig {
  secretKey: string;
  webhookSecret: string;
  apiVersion?: Stripe.LatestApiVersion;
}

class StripeClient {
  private stripe: Stripe;
  private webhookProcessor: WebhookProcessor;
  private retryHandler: RetryHandler;
  private rateLimiter: RateLimiter;

  constructor(config: StripeConfig) {
    this.stripe = new Stripe(config.secretKey, {
      apiVersion: config.apiVersion || "2024-12-18.acacia",
      maxNetworkRetries: 0, // We handle retries ourselves
      timeout: 30000,
    });

    this.webhookProcessor = new WebhookProcessor({
      secret: config.webhookSecret,
      signatureHeader: "stripe-signature",
      signatureAlgorithm: "sha256",
      timestampTolerance: 300, // 5 minutes
    });

    this.rateLimiter = new RateLimiter(rateLimitConfigs.stripe);
    this.retryHandler = new RetryHandler();
  }

  // Create payment intent with retry logic
  async createPaymentIntent(
    params: Stripe.PaymentIntentCreateParams,
  ): Promise<Stripe.PaymentIntent> {
    return this.retryHandler.execute(
      async () => {
        await this.rateLimiter.acquire();
        return this.stripe.paymentIntents.create(params);
      },
      { rateLimiter: this.rateLimiter },
    );
  }

  // Create customer
  async createCustomer(
    params: Stripe.CustomerCreateParams,
  ): Promise<Stripe.Customer> {
    return this.retryHandler.execute(
      async () => {
        await this.rateLimiter.acquire();
        return this.stripe.customers.create(params);
      },
      { rateLimiter: this.rateLimiter },
    );
  }

  // Create subscription
  async createSubscription(
    params: Stripe.SubscriptionCreateParams,
  ): Promise<Stripe.Subscription> {
    return this.retryHandler.execute(
      async () => {
        await this.rateLimiter.acquire();
        return this.stripe.subscriptions.create(params);
      },
      { rateLimiter: this.rateLimiter },
    );
  }

  // Handle webhook
  async handleWebhook(
    payload: string,
    signature: string,
  ): Promise<Stripe.Event> {
    // Verify using Stripe's library for additional validation
    const event = this.stripe.webhooks.constructEvent(
      payload,
      signature,
      this.webhookProcessor["config"].secret,
    );

    // Process through our webhook handler for idempotency
    await this.webhookProcessor.processWebhook(payload, {
      "stripe-signature": signature,
    });

    return event;
  }

  // Webhook event handlers
  onWebhook(
    eventType: string,
    handler: (event: Stripe.Event) => Promise<void>,
  ): void {
    this.webhookProcessor.on(eventType, async (webhookEvent) => {
      await handler(webhookEvent.data as Stripe.Event);
    });
  }
}

// Usage example
const stripeClient = new StripeClient({
  secretKey: process.env.STRIPE_SECRET_KEY!,
  webhookSecret: process.env.STRIPE_WEBHOOK_SECRET!,
});

// Register webhook handlers
stripeClient.onWebhook("payment_intent.succeeded", async (event) => {
  const paymentIntent = event.data.object as Stripe.PaymentIntent;
  console.log(`Payment succeeded: ${paymentIntent.id}`);
});

stripeClient.onWebhook("customer.subscription.created", async (event) => {
  const subscription = event.data.object as Stripe.Subscription;
  console.log(`Subscription created: ${subscription.id}`);
});
```

### Twilio Integration

```typescript
import twilio from "twilio";

interface TwilioConfig {
  accountSid: string;
  authToken: string;
  fromNumber: string;
}

class TwilioClient {
  private client: twilio.Twilio;
  private retryHandler: RetryHandler;
  private rateLimiter: RateLimiter;
  private circuitBreaker: CircuitBreaker;

  constructor(
    config: TwilioConfig,
    private fromNumber: string = config.fromNumber,
  ) {
    this.client = twilio(config.accountSid, config.authToken);
    this.rateLimiter = new RateLimiter(rateLimitConfigs.twilio);
    this.retryHandler = new RetryHandler();
    this.circuitBreaker = new CircuitBreaker();
  }

  // Send SMS with retry and circuit breaker
  async sendSMS(
    to: string,
    body: string,
  ): Promise<twilio.Twilio.Api.V2010.MessageInstance> {
    return this.circuitBreaker.execute(() =>
      this.retryHandler.execute(
        async () => {
          await this.rateLimiter.acquire();
          return this.client.messages.create({
            to,
            from: this.fromNumber,
            body,
          });
        },
        { rateLimiter: this.rateLimiter },
      ),
    );
  }

  // Send SMS with media
  async sendMMS(
    to: string,
    body: string,
    mediaUrl: string[],
  ): Promise<twilio.Twilio.Api.V2010.MessageInstance> {
    return this.circuitBreaker.execute(() =>
      this.retryHandler.execute(
        async () => {
          await this.rateLimiter.acquire();
          return this.client.messages.create({
            to,
            from: this.fromNumber,
            body,
            mediaUrl,
          });
        },
        { rateLimiter: this.rateLimiter },
      ),
    );
  }

  // Make voice call
  async makeCall(
    to: string,
    twiml: string | URL,
  ): Promise<twilio.Twilio.Api.V2010.CallInstance> {
    const url = typeof twiml === "string" ? undefined : twiml.toString();
    const twimlContent = typeof twiml === "string" ? twiml : undefined;

    return this.circuitBreaker.execute(() =>
      this.retryHandler.execute(
        async () => {
          await this.rateLimiter.acquire();
          return this.client.calls.create({
            to,
            from: this.fromNumber,
            url,
            twiml: twimlContent,
          });
        },
        { rateLimiter: this.rateLimiter },
      ),
    );
  }

  // Validate webhook signature
  validateWebhook(
    signature: string,
    url: string,
    params: Record<string, string>,
  ): boolean {
    return twilio.validateRequest(
      this.client["password"], // authToken
      signature,
      url,
      params,
    );
  }

  // Get circuit breaker status
  getCircuitStatus(): CircuitState {
    return this.circuitBreaker.getState();
  }
}
```

### SendGrid Integration

```typescript
import sgMail, { MailDataRequired } from "@sendgrid/mail";

interface SendGridConfig {
  apiKey: string;
  defaultFrom: {
    email: string;
    name?: string;
  };
}

interface EmailTemplate {
  templateId: string;
  dynamicTemplateData: Record<string, unknown>;
}

class SendGridClient {
  private retryHandler: RetryHandler;
  private rateLimiter: RateLimiter;
  private circuitBreaker: CircuitBreaker;

  constructor(private config: SendGridConfig) {
    sgMail.setApiKey(config.apiKey);
    this.rateLimiter = new RateLimiter(rateLimitConfigs.sendgrid);
    this.retryHandler = new RetryHandler();
    this.circuitBreaker = new CircuitBreaker();
  }

  // Send single email
  async sendEmail(
    to: string | string[],
    subject: string,
    content: { text?: string; html?: string },
  ): Promise<void> {
    const msg: MailDataRequired = {
      to,
      from: this.config.defaultFrom,
      subject,
      text: content.text,
      html: content.html,
    };

    await this.circuitBreaker.execute(() =>
      this.retryHandler.execute(
        async () => {
          await this.rateLimiter.acquire();
          await sgMail.send(msg);
        },
        { rateLimiter: this.rateLimiter },
      ),
    );
  }

  // Send email with template
  async sendTemplateEmail(
    to: string | string[],
    template: EmailTemplate,
  ): Promise<void> {
    const msg: MailDataRequired = {
      to,
      from: this.config.defaultFrom,
      templateId: template.templateId,
      dynamicTemplateData: template.dynamicTemplateData,
    };

    await this.circuitBreaker.execute(() =>
      this.retryHandler.execute(
        async () => {
          await this.rateLimiter.acquire();
          await sgMail.send(msg);
        },
        { rateLimiter: this.rateLimiter },
      ),
    );
  }

  // Send bulk emails (up to 1000)
  async sendBulkEmail(
    messages: Array<{
      to: string;
      subject: string;
      content: { text?: string; html?: string };
      personalizations?: Record<string, unknown>;
    }>,
  ): Promise<void> {
    const msgs: MailDataRequired[] = messages.map((m) => ({
      to: m.to,
      from: this.config.defaultFrom,
      subject: m.subject,
      text: m.content.text,
      html: m.content.html,
      personalizations: m.personalizations ? [m.personalizations] : undefined,
    }));

    // SendGrid recommends batching in groups of 1000
    const batches = this.chunk(msgs, 1000);

    for (const batch of batches) {
      await this.circuitBreaker.execute(() =>
        this.retryHandler.execute(
          async () => {
            await this.rateLimiter.acquire();
            await sgMail.send(batch);
          },
          { rateLimiter: this.rateLimiter },
        ),
      );
    }
  }

  private chunk<T>(array: T[], size: number): T[][] {
    const chunks: T[][] = [];
    for (let i = 0; i < array.length; i += size) {
      chunks.push(array.slice(i, i + size));
    }
    return chunks;
  }
}

// Webhook event handler for SendGrid
class SendGridWebhookHandler {
  private processor: WebhookProcessor;

  constructor(webhookSecret: string) {
    this.processor = new WebhookProcessor({
      secret: webhookSecret,
      signatureHeader: "x-twilio-email-event-webhook-signature",
      signatureAlgorithm: "sha256",
      timestampHeader: "x-twilio-email-event-webhook-timestamp",
      timestampTolerance: 300,
    });
  }

  async handleEvents(
    payload: string,
    headers: Record<string, string>,
  ): Promise<SendGridEvent[]> {
    const result = await this.processor.processWebhook<SendGridEvent[]>(
      payload,
      headers,
    );
    return result.data;
  }

  onEvent(
    eventType: SendGridEventType,
    handler: (event: SendGridEvent) => Promise<void>,
  ): void {
    this.processor.on("webhook", async (webhookEvent) => {
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
```

---

## Error Handling Patterns

### Unified Error Handler

```typescript
interface ApiErrorDetails {
  provider: string;
  code: string;
  message: string;
  statusCode?: number;
  retryable: boolean;
  details?: Record<string, unknown>;
}

class ThirdPartyApiError extends Error {
  constructor(
    public details: ApiErrorDetails,
    public originalError?: Error,
  ) {
    super(`[${details.provider}] ${details.code}: ${details.message}`);
    this.name = "ThirdPartyApiError";
  }
}

// Provider-specific error normalizers
const errorNormalizers: Record<string, (error: unknown) => ApiErrorDetails> = {
  stripe: (error: unknown) => {
    const stripeError = error as any;
    return {
      provider: "stripe",
      code: stripeError.code || stripeError.type || "unknown",
      message: stripeError.message || "Unknown Stripe error",
      statusCode: stripeError.statusCode,
      retryable: ["rate_limit", "api_connection_error", "api_error"].includes(
        stripeError.type,
      ),
      details: {
        declineCode: stripeError.decline_code,
        param: stripeError.param,
      },
    };
  },

  twilio: (error: unknown) => {
    const twilioError = error as any;
    return {
      provider: "twilio",
      code: String(twilioError.code || "unknown"),
      message: twilioError.message || "Unknown Twilio error",
      statusCode: twilioError.status,
      retryable: [429, 500, 502, 503, 504].includes(twilioError.status),
      details: {
        moreInfo: twilioError.moreInfo,
      },
    };
  },

  sendgrid: (error: unknown) => {
    const sgError = error as any;
    const firstError = sgError.response?.body?.errors?.[0];
    return {
      provider: "sendgrid",
      code: firstError?.field || sgError.code || "unknown",
      message:
        firstError?.message || sgError.message || "Unknown SendGrid error",
      statusCode: sgError.code,
      retryable: [429, 500, 502, 503, 504].includes(sgError.code),
      details: {
        errors: sgError.response?.body?.errors,
      },
    };
  },
};

function normalizeApiError(
  provider: string,
  error: unknown,
): ThirdPartyApiError {
  const normalizer = errorNormalizers[provider];

  if (normalizer) {
    return new ThirdPartyApiError(
      normalizer(error),
      error instanceof Error ? error : undefined,
    );
  }

  // Generic fallback
  return new ThirdPartyApiError(
    {
      provider,
      code: "unknown",
      message: error instanceof Error ? error.message : String(error),
      retryable: false,
    },
    error instanceof Error ? error : undefined,
  );
}
```

### Error Recovery Strategies

```typescript
interface RecoveryStrategy {
  canRecover: (error: ThirdPartyApiError) => boolean;
  recover: (error: ThirdPartyApiError, context: any) => Promise<void>;
}

const recoveryStrategies: Record<string, RecoveryStrategy[]> = {
  stripe: [
    {
      // Card declined - notify user
      canRecover: (e) => e.details.code === "card_declined",
      recover: async (e, ctx) => {
        await ctx.notifyUser(
          "Your card was declined. Please try another card.",
        );
      },
    },
    {
      // Idempotency key conflict - use existing result
      canRecover: (e) => e.details.code === "idempotency_key_in_use",
      recover: async (e, ctx) => {
        const existingResult = await ctx.stripe.paymentIntents.retrieve(
          e.details.details?.existingObjectId as string,
        );
        ctx.setResult(existingResult);
      },
    },
  ],

  twilio: [
    {
      // Invalid phone number - mark as undeliverable
      canRecover: (e) => e.details.code === "21211",
      recover: async (e, ctx) => {
        await ctx.markPhoneInvalid(ctx.phoneNumber);
      },
    },
    {
      // Queue full - schedule for later
      canRecover: (e) => e.details.code === "30008",
      recover: async (e, ctx) => {
        await ctx.scheduleForLater(ctx.message, 300000); // 5 minutes
      },
    },
  ],

  sendgrid: [
    {
      // Invalid email - remove from list
      canRecover: (e) => e.details.statusCode === 400,
      recover: async (e, ctx) => {
        await ctx.removeFromMailingList(ctx.email);
      },
    },
  ],
};

async function handleWithRecovery<T>(
  provider: string,
  operation: () => Promise<T>,
  context: any,
): Promise<T> {
  try {
    return await operation();
  } catch (error) {
    const normalizedError = normalizeApiError(provider, error);
    const strategies = recoveryStrategies[provider] || [];

    for (const strategy of strategies) {
      if (strategy.canRecover(normalizedError)) {
        await strategy.recover(normalizedError, context);

        if (context.result) {
          return context.result;
        }
        break;
      }
    }

    throw normalizedError;
  }
}
```

---

## Integration Testing Patterns

### Mock Provider Factory

```typescript
interface MockResponse {
  status: number;
  data: unknown;
  headers?: Record<string, string>;
  delay?: number;
}

class MockProviderServer {
  private responses: Map<string, MockResponse[]> = new Map();
  private requestLog: Array<{ method: string; path: string; body: unknown }> =
    [];

  // Queue responses for a path
  mockResponse(method: string, path: string, response: MockResponse): void {
    const key = `${method}:${path}`;
    const existing = this.responses.get(key) || [];
    existing.push(response);
    this.responses.set(key, existing);
  }

  // Get next response for path
  getResponse(method: string, path: string): MockResponse | undefined {
    const key = `${method}:${path}`;
    const responses = this.responses.get(key);

    if (!responses || responses.length === 0) {
      return undefined;
    }

    return responses.shift();
  }

  // Log request
  logRequest(method: string, path: string, body: unknown): void {
    this.requestLog.push({ method, path, body });
  }

  // Get logged requests
  getRequests(): Array<{ method: string; path: string; body: unknown }> {
    return [...this.requestLog];
  }

  // Clear state
  reset(): void {
    this.responses.clear();
    this.requestLog = [];
  }
}

// Integration with api-test-expert
class ApiIntegrationTestHelper {
  constructor(
    private mockServer: MockProviderServer,
    private provider: string,
  ) {}

  // Common test scenarios
  async testRateLimitHandling(
    client: any,
    operation: () => Promise<any>,
  ): Promise<void> {
    // Queue rate limit response then success
    this.mockServer.mockResponse("POST", "/test", {
      status: 429,
      data: { error: "rate_limit_exceeded" },
      headers: { "Retry-After": "1" },
    });

    this.mockServer.mockResponse("POST", "/test", {
      status: 200,
      data: { success: true },
    });

    const result = await operation();

    // Verify retry occurred
    const requests = this.mockServer.getRequests();
    if (requests.length !== 2) {
      throw new Error(`Expected 2 requests, got ${requests.length}`);
    }
  }

  async testCircuitBreaker(
    client: any,
    operation: () => Promise<any>,
    failureCount: number,
  ): Promise<void> {
    // Queue failures
    for (let i = 0; i < failureCount; i++) {
      this.mockServer.mockResponse("POST", "/test", {
        status: 500,
        data: { error: "internal_error" },
      });
    }

    // Attempt operations until circuit opens
    let circuitOpened = false;

    for (let i = 0; i < failureCount + 1; i++) {
      try {
        await operation();
      } catch (error) {
        if (error instanceof CircuitOpenError) {
          circuitOpened = true;
          break;
        }
      }
    }

    if (!circuitOpened) {
      throw new Error("Circuit breaker did not open");
    }
  }

  async testWebhookSignatureValidation(
    processor: WebhookProcessor,
    validPayload: string,
    validSignature: string,
  ): Promise<void> {
    // Test valid signature
    const validResult = await processor.processWebhook(validPayload, {
      [processor["config"].signatureHeader]: validSignature,
    });

    if (!validResult) {
      throw new Error("Valid signature rejected");
    }

    // Test invalid signature
    try {
      await processor.processWebhook(validPayload, {
        [processor["config"].signatureHeader]: "invalid_signature",
      });
      throw new Error("Invalid signature accepted");
    } catch (error) {
      if (
        !(error instanceof WebhookError) ||
        error.code !== "INVALID_SIGNATURE"
      ) {
        throw error;
      }
    }
  }

  async testIdempotency(
    processor: WebhookProcessor,
    payload: string,
    headers: Record<string, string>,
  ): Promise<void> {
    // First request should succeed
    await processor.processWebhook(payload, headers);

    // Second request with same payload should be rejected
    try {
      await processor.processWebhook(payload, headers);
      throw new Error("Duplicate event accepted");
    } catch (error) {
      if (
        !(error instanceof WebhookError) ||
        error.code !== "DUPLICATE_EVENT"
      ) {
        throw error;
      }
    }
  }
}
```

### Test Fixtures

```typescript
// Stripe test fixtures
const stripeFixtures = {
  paymentIntent: {
    id: "pi_test_123",
    object: "payment_intent",
    amount: 2000,
    currency: "usd",
    status: "succeeded",
    client_secret: "pi_test_123_secret_456",
  },

  customer: {
    id: "cus_test_123",
    object: "customer",
    email: "test@example.com",
    name: "Test Customer",
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
};

// Twilio test fixtures
const twilioFixtures = {
  message: {
    sid: "SM_test_123",
    status: "queued",
    to: "+1234567890",
    from: "+0987654321",
    body: "Test message",
  },

  call: {
    sid: "CA_test_123",
    status: "queued",
    to: "+1234567890",
    from: "+0987654321",
  },
};

// SendGrid test fixtures
const sendgridFixtures = {
  emailResponse: {
    statusCode: 202,
    body: "",
  },

  webhookEvents: [
    {
      email: "test@example.com",
      timestamp: 1609459200,
      event: "delivered",
      sg_event_id: "evt_test_123",
      sg_message_id: "msg_test_123",
    },
  ],
};
```

---

## Integration with Related Agents

### Cross-Agent Workflow

```typescript
// Integrate with api-test-expert for comprehensive testing
async function runIntegrationTests(provider: string): Promise<void> {
  // Use Task tool to invoke api-test-expert
  const testResults = await invokeAgent("api-test-expert", {
    task: `Run integration tests for ${provider} API client`,
    scope: [
      "Rate limit handling",
      "Retry logic",
      "Circuit breaker",
      "Webhook validation",
      "Error handling",
    ],
  });

  // Analyze results
  if (testResults.failures.length > 0) {
    throw new Error(
      `Integration tests failed: ${JSON.stringify(testResults.failures)}`,
    );
  }
}

// Coordinate with webhook-expert for webhook setup
async function setupWebhooks(
  provider: string,
  endpoints: string[],
): Promise<void> {
  await invokeAgent("webhook-expert", {
    task: `Configure webhook endpoints for ${provider}`,
    endpoints,
    security: {
      signatureValidation: true,
      timestampValidation: true,
      idempotencyTracking: true,
    },
  });
}

// Coordinate with authentication-specialist for OAuth
async function setupOAuth(
  provider: string,
  config: OAuthConfig,
): Promise<void> {
  await invokeAgent("authentication-specialist", {
    task: `Implement OAuth 2.0 flow for ${provider}`,
    flow: "authorization_code",
    pkce: true,
    tokenStorage: "encrypted",
    refreshStrategy: "proactive",
  });
}
```

---

## Best Practices Checklist

### Implementation Checklist

- [ ] **OAuth Implementation**
  - [ ] Use PKCE for authorization code flow
  - [ ] Store tokens securely (encrypted at rest)
  - [ ] Implement proactive token refresh
  - [ ] Handle token revocation gracefully

- [ ] **Rate Limiting**
  - [ ] Implement token bucket or sliding window
  - [ ] Parse rate limit headers from responses
  - [ ] Queue requests when approaching limits
  - [ ] Log rate limit events for monitoring

- [ ] **Retry Strategy**
  - [ ] Use exponential backoff with jitter
  - [ ] Respect Retry-After headers
  - [ ] Implement circuit breaker for failures
  - [ ] Set maximum retry attempts

- [ ] **Webhook Security**
  - [ ] Verify HMAC signatures
  - [ ] Validate timestamps for replay prevention
  - [ ] Implement idempotency tracking
  - [ ] Process webhooks asynchronously

- [ ] **API Versioning**
  - [ ] Pin to specific API version
  - [ ] Handle deprecation warnings
  - [ ] Implement version migration paths
  - [ ] Test across supported versions

- [ ] **Error Handling**
  - [ ] Normalize provider-specific errors
  - [ ] Implement recovery strategies
  - [ ] Log errors with context
  - [ ] Surface actionable errors to users

---

## Example Invocations

```bash
# Integrate Stripe payments
/agents/integration/third-party-api-expert integrate Stripe for subscription billing

# Set up Twilio SMS
/agents/integration/third-party-api-expert implement Twilio SMS with delivery tracking

# Configure SendGrid emails
/agents/integration/third-party-api-expert set up SendGrid transactional emails with templates

# Implement OAuth flow
/agents/integration/third-party-api-expert implement GitHub OAuth for user authentication

# Handle webhooks
/agents/integration/third-party-api-expert create webhook handler for Shopify orders
```

---

## Related Agents

| Agent                                        | Use Case                |
| -------------------------------------------- | ----------------------- |
| `/agents/testing/api-test-expert`            | Integration testing     |
| `/agents/integration/webhook-expert`         | Webhook design patterns |
| `/agents/integration/api-integration-expert` | General API integration |
| `/agents/backend/authentication-specialist`  | OAuth implementation    |
| `/agents/security/security-expert`           | Security review         |

---

_Agent Version: 2.0.0 | Category: Integration | Author: Ahmed Adel Bakr Alderai_
