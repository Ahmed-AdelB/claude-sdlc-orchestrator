---
name: Third-Party API Integration Expert
description: Expert in external API integrations including OAuth, rate limiting, webhooks, provider SDKs, monitoring, and cost tracking
version: 3.0.0
author: Ahmed Adel Bakr Alderai
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
  - aws-sdk
  - gcp-sdk
  - webhook
  - rate-limit
  - api-integration
  - api-monitoring
  - cost-tracking
related_agents:
  - api-test-expert
  - webhook-expert
  - api-integration-expert
  - authentication-specialist
  - security-expert
  - aws-expert
  - gcp-expert
  - monitoring-expert
inputs:
  - name: task
    type: string
    required: true
    description: The third-party API integration task
  - name: provider
    type: string
    required: false
    description: "API provider (stripe, twilio, sendgrid, aws, gcp, github, shopify)"
  - name: language
    type: string
    required: false
    default: typescript
    description: "Target language (typescript, python, go)"
outputs:
  - api_client
  - authentication_handler
  - rate_limiter
  - retry_logic
  - webhook_processor
  - monitoring_config
  - cost_tracker
---

# Third-Party API Integration Expert Agent

Expert in external API integrations, OAuth flows, rate limiting, retry strategies, webhook handling, API versioning, SDK best practices, monitoring, and cost tracking. Specializes in production-ready integrations with major providers including Stripe, Twilio, SendGrid, AWS, GCP, GitHub, and Shopify.

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
7. Set up API health monitoring and alerting
8. Implement cost tracking for paid APIs

Task: $ARGUMENTS
```

---

## Table of Contents

1. [Authentication Patterns](#1-authentication-patterns)
2. [Rate Limit Handling](#2-rate-limit-handling)
3. [Retry Strategies with Backoff](#3-retry-strategies-with-backoff)
4. [Webhook Handling](#4-webhook-handling)
5. [API Versioning Compatibility](#5-api-versioning-compatibility)
6. [Provider Templates](#provider-templates)
7. [AWS SDK Integration](#aws-sdk-integration)
8. [GCP SDK Integration](#gcp-sdk-integration)
9. [SDK Best Practices](#sdk-best-practices)
10. [Error Handling Patterns](#error-handling-patterns)
11. [Monitoring and Alerting](#monitoring-and-alerting)
12. [Cost Tracking](#cost-tracking)
13. [Testing with Mock Services](#testing-with-mock-services)

---

## 1. Authentication Patterns

### OAuth 2.0 Authorization Code Flow (with PKCE)

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

### OAuth 2.0 Client Credentials Flow

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

### API Key Authentication Manager

```typescript
interface ApiKeyConfig {
  keyHeader: string; // e.g., 'X-API-Key', 'Authorization'
  keyPrefix?: string; // e.g., 'Bearer ', 'Api-Key '
  keyEnvVar: string; // Environment variable name
  rotationDays?: number; // Days before key rotation warning
}

class ApiKeyManager {
  private config: ApiKeyConfig;
  private key: string;
  private keyCreatedAt: Date;

  constructor(config: ApiKeyConfig) {
    this.config = config;
    this.key = this.loadKey();
    this.keyCreatedAt = new Date();
  }

  private loadKey(): string {
    const key = process.env[this.config.keyEnvVar];
    if (!key) {
      throw new Error(
        `API key not found in environment variable: ${this.config.keyEnvVar}`,
      );
    }
    return key;
  }

  getAuthHeaders(): Record<string, string> {
    const value = this.config.keyPrefix
      ? `${this.config.keyPrefix}${this.key}`
      : this.key;

    return {
      [this.config.keyHeader]: value,
    };
  }

  // Check if key rotation is needed
  needsRotation(): boolean {
    if (!this.config.rotationDays) return false;

    const daysSinceCreation = Math.floor(
      (Date.now() - this.keyCreatedAt.getTime()) / (1000 * 60 * 60 * 24),
    );

    return daysSinceCreation >= this.config.rotationDays;
  }

  // Validate key format (provider-specific)
  static validateKeyFormat(key: string, provider: string): boolean {
    const patterns: Record<string, RegExp> = {
      stripe: /^sk_(live|test)_[a-zA-Z0-9]{24,}$/,
      sendgrid: /^SG\.[a-zA-Z0-9_-]{22}\.[a-zA-Z0-9_-]{43}$/,
      twilio: /^SK[a-f0-9]{32}$/,
      github: /^gh[ps]_[a-zA-Z0-9]{36,}$/,
      openai: /^sk-[a-zA-Z0-9]{48}$/,
    };

    const pattern = patterns[provider];
    return pattern ? pattern.test(key) : true;
  }
}

// Provider-specific API key configurations
const apiKeyConfigs: Record<string, ApiKeyConfig> = {
  stripe: {
    keyHeader: "Authorization",
    keyPrefix: "Bearer ",
    keyEnvVar: "STRIPE_SECRET_KEY",
    rotationDays: 90,
  },
  sendgrid: {
    keyHeader: "Authorization",
    keyPrefix: "Bearer ",
    keyEnvVar: "SENDGRID_API_KEY",
    rotationDays: 90,
  },
  twilio: {
    keyHeader: "Authorization",
    keyPrefix: "Basic ", // Uses account SID:auth token
    keyEnvVar: "TWILIO_AUTH_TOKEN",
    rotationDays: 90,
  },
  openai: {
    keyHeader: "Authorization",
    keyPrefix: "Bearer ",
    keyEnvVar: "OPENAI_API_KEY",
    rotationDays: 90,
  },
  github: {
    keyHeader: "Authorization",
    keyPrefix: "Bearer ",
    keyEnvVar: "GITHUB_TOKEN",
    rotationDays: 365,
  },
};
```

### JWT Token Handler

```typescript
import jwt from "jsonwebtoken";

interface JwtConfig {
  issuer: string;
  audience: string;
  algorithm: "RS256" | "HS256" | "ES256";
  privateKey?: string;
  publicKey?: string;
  secret?: string;
  expiresIn: string;
}

class JwtTokenHandler {
  private config: JwtConfig;

  constructor(config: JwtConfig) {
    this.config = config;
    this.validateConfig();
  }

  private validateConfig(): void {
    if (this.config.algorithm === "HS256" && !this.config.secret) {
      throw new Error("HS256 algorithm requires a secret");
    }
    if (
      ["RS256", "ES256"].includes(this.config.algorithm) &&
      (!this.config.privateKey || !this.config.publicKey)
    ) {
      throw new Error(
        `${this.config.algorithm} requires privateKey and publicKey`,
      );
    }
  }

  // Generate JWT for service-to-service auth
  generateServiceToken(claims: Record<string, unknown>): string {
    const payload = {
      ...claims,
      iss: this.config.issuer,
      aud: this.config.audience,
      iat: Math.floor(Date.now() / 1000),
    };

    const signingKey =
      this.config.algorithm === "HS256"
        ? this.config.secret!
        : this.config.privateKey!;

    return jwt.sign(payload, signingKey, {
      algorithm: this.config.algorithm,
      expiresIn: this.config.expiresIn,
    });
  }

  // Verify JWT from external service
  verifyToken(token: string): jwt.JwtPayload {
    const verifyKey =
      this.config.algorithm === "HS256"
        ? this.config.secret!
        : this.config.publicKey!;

    try {
      const decoded = jwt.verify(token, verifyKey, {
        algorithms: [this.config.algorithm],
        issuer: this.config.issuer,
        audience: this.config.audience,
      });

      return decoded as jwt.JwtPayload;
    } catch (error) {
      if (error instanceof jwt.TokenExpiredError) {
        throw new AuthError("TOKEN_EXPIRED", "Token has expired");
      }
      if (error instanceof jwt.JsonWebTokenError) {
        throw new AuthError("INVALID_TOKEN", error.message);
      }
      throw error;
    }
  }

  // Decode without verification (for debugging)
  decodeToken(token: string): jwt.JwtPayload | null {
    return jwt.decode(token) as jwt.JwtPayload | null;
  }
}

class AuthError extends Error {
  constructor(
    public code: string,
    message: string,
  ) {
    super(message);
    this.name = "AuthError";
  }
}

// Google Service Account JWT (for GCP APIs)
class GoogleServiceAccountAuth {
  private serviceAccount: {
    client_email: string;
    private_key: string;
    project_id: string;
  };

  constructor(serviceAccountPath: string) {
    const content = require("fs").readFileSync(serviceAccountPath, "utf-8");
    this.serviceAccount = JSON.parse(content);
  }

  async getAccessToken(scopes: string[]): Promise<string> {
    const now = Math.floor(Date.now() / 1000);

    const payload = {
      iss: this.serviceAccount.client_email,
      sub: this.serviceAccount.client_email,
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
      scope: scopes.join(" "),
    };

    const assertion = jwt.sign(payload, this.serviceAccount.private_key, {
      algorithm: "RS256",
    });

    const response = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion,
      }),
    });

    if (!response.ok) {
      throw new Error(`Google auth failed: ${response.status}`);
    }

    const data = await response.json();
    return data.access_token;
  }
}
```

---

## 2. Rate Limit Handling

### Intelligent Rate Limiter with Token Bucket

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

  // Get current rate limit status
  getStatus(): { remaining: number; limit: number; resetIn: number } {
    this.refillTokens();
    return {
      remaining: this.tokens,
      limit: this.config.maxRequests,
      resetIn: this.config.windowMs - (Date.now() - this.lastRefill),
    };
  }
}
```

### Provider-Specific Rate Limit Configurations

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
  openai: {
    maxRequests: 60,
    windowMs: 60000, // Varies by tier
    retryAfterHeader: "Retry-After",
    rateLimitHeaders: {
      limit: "x-ratelimit-limit-requests",
      remaining: "x-ratelimit-remaining-requests",
      reset: "x-ratelimit-reset-requests",
    },
  },
  shopify: {
    maxRequests: 40,
    windowMs: 1000, // 40 requests per second (REST)
    retryAfterHeader: "Retry-After",
    rateLimitHeaders: {
      limit: "X-Shopify-Shop-Api-Call-Limit",
      remaining: "X-Shopify-Shop-Api-Call-Limit",
      reset: "Retry-After",
    },
  },
};
```

---

## 3. Retry Strategies with Backoff

### Exponential Backoff with Jitter

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

### Circuit Breaker Pattern

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
  private stateChangeCallbacks: ((state: CircuitState) => void)[] = [];

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
        this.setState(CircuitState.HALF_OPEN);
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
        this.setState(CircuitState.CLOSED);
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
      this.setState(CircuitState.OPEN);
    } else if (this.failures.length >= this.config.failureThreshold) {
      this.setState(CircuitState.OPEN);
    }
  }

  private setState(newState: CircuitState): void {
    if (this.state !== newState) {
      this.state = newState;
      this.stateChangeCallbacks.forEach((cb) => cb(newState));
    }
  }

  onStateChange(callback: (state: CircuitState) => void): void {
    this.stateChangeCallbacks.push(callback);
  }

  getState(): CircuitState {
    return this.state;
  }

  getMetrics(): {
    state: CircuitState;
    failures: number;
    lastFailure: Date | null;
  } {
    return {
      state: this.state,
      failures: this.failures.length,
      lastFailure: this.lastFailureTime ? new Date(this.lastFailureTime) : null,
    };
  }

  reset(): void {
    this.setState(CircuitState.CLOSED);
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

## 4. Webhook Handling

### Secure Webhook Processor

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

// Provider-specific webhook configurations
const webhookConfigs: Record<string, WebhookConfig> = {
  stripe: {
    secret: process.env.STRIPE_WEBHOOK_SECRET!,
    signatureHeader: "stripe-signature",
    signatureAlgorithm: "sha256",
    timestampTolerance: 300,
  },
  github: {
    secret: process.env.GITHUB_WEBHOOK_SECRET!,
    signatureHeader: "x-hub-signature-256",
    signatureAlgorithm: "sha256",
    signaturePrefix: "sha256=",
  },
  shopify: {
    secret: process.env.SHOPIFY_WEBHOOK_SECRET!,
    signatureHeader: "x-shopify-hmac-sha256",
    signatureAlgorithm: "sha256",
  },
  twilio: {
    secret: process.env.TWILIO_AUTH_TOKEN!,
    signatureHeader: "x-twilio-signature",
    signatureAlgorithm: "sha256",
  },
};
```

### Webhook Handler Express Middleware

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

## 5. API Versioning Compatibility

### Version-Aware API Client

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
  private circuitBreaker: CircuitBreaker;

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
      timestampTolerance: 300,
    });

    this.rateLimiter = new RateLimiter(rateLimitConfigs.stripe);
    this.retryHandler = new RetryHandler();
    this.circuitBreaker = new CircuitBreaker();
  }

  // Create payment intent with retry logic
  async createPaymentIntent(
    params: Stripe.PaymentIntentCreateParams,
  ): Promise<Stripe.PaymentIntent> {
    return this.circuitBreaker.execute(() =>
      this.retryHandler.execute(
        async () => {
          await this.rateLimiter.acquire();
          return this.stripe.paymentIntents.create(params);
        },
        { rateLimiter: this.rateLimiter },
      ),
    );
  }

  // Create customer
  async createCustomer(
    params: Stripe.CustomerCreateParams,
  ): Promise<Stripe.Customer> {
    return this.circuitBreaker.execute(() =>
      this.retryHandler.execute(
        async () => {
          await this.rateLimiter.acquire();
          return this.stripe.customers.create(params);
        },
        { rateLimiter: this.rateLimiter },
      ),
    );
  }

  // Create subscription
  async createSubscription(
    params: Stripe.SubscriptionCreateParams,
  ): Promise<Stripe.Subscription> {
    return this.circuitBreaker.execute(() =>
      this.retryHandler.execute(
        async () => {
          await this.rateLimiter.acquire();
          return this.stripe.subscriptions.create(params);
        },
        { rateLimiter: this.rateLimiter },
      ),
    );
  }

  // Handle webhook
  async handleWebhook(
    payload: string,
    signature: string,
  ): Promise<Stripe.Event> {
    const event = this.stripe.webhooks.constructEvent(
      payload,
      signature,
      this.webhookProcessor["config"].secret,
    );

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

  // Get circuit breaker status
  getHealthStatus(): {
    circuitState: CircuitState;
    rateLimitStatus: { remaining: number; limit: number; resetIn: number };
  } {
    return {
      circuitState: this.circuitBreaker.getState(),
      rateLimitStatus: this.rateLimiter.getStatus(),
    };
  }
}
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
```

---

## AWS SDK Integration

### AWS S3 Client with Best Practices

```typescript
import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  DeleteObjectCommand,
  ListObjectsV2Command,
  HeadObjectCommand,
} from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { Readable } from "stream";

interface AwsS3Config {
  region: string;
  bucket: string;
  accessKeyId?: string;
  secretAccessKey?: string;
  // Use IAM roles in production, not keys
}

class AwsS3Client {
  private client: S3Client;
  private bucket: string;
  private retryHandler: RetryHandler;
  private circuitBreaker: CircuitBreaker;

  constructor(config: AwsS3Config) {
    this.bucket = config.bucket;
    this.client = new S3Client({
      region: config.region,
      credentials: config.accessKeyId
        ? {
            accessKeyId: config.accessKeyId,
            secretAccessKey: config.secretAccessKey!,
          }
        : undefined, // Uses IAM role if no credentials
      maxAttempts: 3,
    });

    this.retryHandler = new RetryHandler({
      maxRetries: 3,
      baseDelayMs: 100,
      maxDelayMs: 3000,
      jitterFactor: 0.1,
      retryableStatuses: [429, 500, 502, 503, 504],
      retryableErrors: [
        "ECONNRESET",
        "ETIMEDOUT",
        "InternalError",
        "ServiceUnavailable",
        "SlowDown",
      ],
    });

    this.circuitBreaker = new CircuitBreaker({
      failureThreshold: 5,
      successThreshold: 2,
      timeout: 30000,
      monitoringWindow: 60000,
    });
  }

  // Upload file
  async uploadFile(
    key: string,
    body: Buffer | Readable | string,
    options?: {
      contentType?: string;
      metadata?: Record<string, string>;
      acl?: "private" | "public-read";
    },
  ): Promise<{ key: string; etag: string }> {
    return this.circuitBreaker.execute(() =>
      this.retryHandler.execute(async () => {
        const command = new PutObjectCommand({
          Bucket: this.bucket,
          Key: key,
          Body: body,
          ContentType: options?.contentType,
          Metadata: options?.metadata,
          ACL: options?.acl || "private",
        });

        const result = await this.client.send(command);
        return { key, etag: result.ETag || "" };
      }),
    );
  }

  // Download file
  async downloadFile(key: string): Promise<Buffer> {
    return this.circuitBreaker.execute(() =>
      this.retryHandler.execute(async () => {
        const command = new GetObjectCommand({
          Bucket: this.bucket,
          Key: key,
        });

        const result = await this.client.send(command);
        const chunks: Buffer[] = [];

        for await (const chunk of result.Body as Readable) {
          chunks.push(Buffer.from(chunk));
        }

        return Buffer.concat(chunks);
      }),
    );
  }

  // Generate presigned URL
  async getPresignedUrl(
    key: string,
    operation: "get" | "put",
    expiresIn: number = 3600,
  ): Promise<string> {
    const command =
      operation === "get"
        ? new GetObjectCommand({ Bucket: this.bucket, Key: key })
        : new PutObjectCommand({ Bucket: this.bucket, Key: key });

    return getSignedUrl(this.client, command, { expiresIn });
  }

  // Check if file exists
  async fileExists(key: string): Promise<boolean> {
    try {
      await this.client.send(
        new HeadObjectCommand({
          Bucket: this.bucket,
          Key: key,
        }),
      );
      return true;
    } catch (error: any) {
      if (error.name === "NotFound") {
        return false;
      }
      throw error;
    }
  }

  // List files with prefix
  async listFiles(
    prefix: string,
    maxKeys: number = 1000,
  ): Promise<Array<{ key: string; size: number; lastModified: Date }>> {
    const result = await this.client.send(
      new ListObjectsV2Command({
        Bucket: this.bucket,
        Prefix: prefix,
        MaxKeys: maxKeys,
      }),
    );

    return (result.Contents || []).map((obj) => ({
      key: obj.Key!,
      size: obj.Size!,
      lastModified: obj.LastModified!,
    }));
  }

  // Delete file
  async deleteFile(key: string): Promise<void> {
    await this.circuitBreaker.execute(() =>
      this.retryHandler.execute(async () => {
        await this.client.send(
          new DeleteObjectCommand({
            Bucket: this.bucket,
            Key: key,
          }),
        );
      }),
    );
  }
}
```

### AWS SES Email Client

```typescript
import {
  SESClient,
  SendEmailCommand,
  SendTemplatedEmailCommand,
  SendBulkTemplatedEmailCommand,
} from "@aws-sdk/client-ses";

interface AwsSesConfig {
  region: string;
  defaultFromEmail: string;
  configurationSetName?: string;
}

class AwsSesClient {
  private client: SESClient;
  private config: AwsSesConfig;
  private retryHandler: RetryHandler;
  private rateLimiter: RateLimiter;

  constructor(config: AwsSesConfig) {
    this.config = config;
    this.client = new SESClient({
      region: config.region,
      maxAttempts: 3,
    });

    // SES rate limit: 14 emails/second (sending quota)
    this.rateLimiter = new RateLimiter({
      maxRequests: 14,
      windowMs: 1000,
      retryAfterHeader: "Retry-After",
      rateLimitHeaders: {
        limit: "X-RateLimit-Limit",
        remaining: "X-RateLimit-Remaining",
        reset: "X-RateLimit-Reset",
      },
    });

    this.retryHandler = new RetryHandler();
  }

  // Send simple email
  async sendEmail(
    to: string[],
    subject: string,
    body: { text?: string; html?: string },
    options?: {
      cc?: string[];
      bcc?: string[];
      replyTo?: string[];
      from?: string;
    },
  ): Promise<string> {
    await this.rateLimiter.acquire();

    const command = new SendEmailCommand({
      Source: options?.from || this.config.defaultFromEmail,
      Destination: {
        ToAddresses: to,
        CcAddresses: options?.cc,
        BccAddresses: options?.bcc,
      },
      Message: {
        Subject: { Data: subject },
        Body: {
          Text: body.text ? { Data: body.text } : undefined,
          Html: body.html ? { Data: body.html } : undefined,
        },
      },
      ReplyToAddresses: options?.replyTo,
      ConfigurationSetName: this.config.configurationSetName,
    });

    const result = await this.retryHandler.execute(() =>
      this.client.send(command),
    );
    return result.MessageId!;
  }

  // Send templated email
  async sendTemplatedEmail(
    to: string[],
    templateName: string,
    templateData: Record<string, unknown>,
    options?: { from?: string },
  ): Promise<string> {
    await this.rateLimiter.acquire();

    const command = new SendTemplatedEmailCommand({
      Source: options?.from || this.config.defaultFromEmail,
      Destination: { ToAddresses: to },
      Template: templateName,
      TemplateData: JSON.stringify(templateData),
      ConfigurationSetName: this.config.configurationSetName,
    });

    const result = await this.retryHandler.execute(() =>
      this.client.send(command),
    );
    return result.MessageId!;
  }

  // Send bulk templated email
  async sendBulkTemplatedEmail(
    recipients: Array<{
      email: string;
      templateData: Record<string, unknown>;
    }>,
    templateName: string,
    defaultTemplateData: Record<string, unknown>,
  ): Promise<Array<{ email: string; messageId?: string; error?: string }>> {
    const command = new SendBulkTemplatedEmailCommand({
      Source: this.config.defaultFromEmail,
      Template: templateName,
      DefaultTemplateData: JSON.stringify(defaultTemplateData),
      Destinations: recipients.map((r) => ({
        Destination: { ToAddresses: [r.email] },
        ReplacementTemplateData: JSON.stringify(r.templateData),
      })),
      ConfigurationSetName: this.config.configurationSetName,
    });

    const result = await this.retryHandler.execute(() =>
      this.client.send(command),
    );

    return (result.Status || []).map((status, index) => ({
      email: recipients[index].email,
      messageId: status.MessageId,
      error: status.Error,
    }));
  }
}
```

### AWS SNS Client

```typescript
import {
  SNSClient,
  PublishCommand,
  CreateTopicCommand,
  SubscribeCommand,
} from "@aws-sdk/client-sns";

interface AwsSnsConfig {
  region: string;
}

class AwsSnsClient {
  private client: SNSClient;
  private retryHandler: RetryHandler;

  constructor(config: AwsSnsConfig) {
    this.client = new SNSClient({
      region: config.region,
      maxAttempts: 3,
    });
    this.retryHandler = new RetryHandler();
  }

  // Publish message to topic
  async publishToTopic(
    topicArn: string,
    message: string | Record<string, unknown>,
    options?: {
      subject?: string;
      messageAttributes?: Record<
        string,
        { DataType: string; StringValue: string }
      >;
    },
  ): Promise<string> {
    const messageBody =
      typeof message === "string" ? message : JSON.stringify(message);

    const command = new PublishCommand({
      TopicArn: topicArn,
      Message: messageBody,
      Subject: options?.subject,
      MessageAttributes: options?.messageAttributes,
    });

    const result = await this.retryHandler.execute(() =>
      this.client.send(command),
    );
    return result.MessageId!;
  }

  // Send SMS
  async sendSMS(
    phoneNumber: string,
    message: string,
    options?: {
      senderId?: string;
      messageType?: "Promotional" | "Transactional";
    },
  ): Promise<string> {
    const command = new PublishCommand({
      PhoneNumber: phoneNumber,
      Message: message,
      MessageAttributes: {
        "AWS.SNS.SMS.SenderID": {
          DataType: "String",
          StringValue: options?.senderId || "NOTIFY",
        },
        "AWS.SNS.SMS.SMSType": {
          DataType: "String",
          StringValue: options?.messageType || "Transactional",
        },
      },
    });

    const result = await this.retryHandler.execute(() =>
      this.client.send(command),
    );
    return result.MessageId!;
  }

  // Create topic
  async createTopic(name: string): Promise<string> {
    const command = new CreateTopicCommand({ Name: name });
    const result = await this.client.send(command);
    return result.TopicArn!;
  }

  // Subscribe to topic
  async subscribe(
    topicArn: string,
    protocol: "email" | "sms" | "http" | "https" | "lambda" | "sqs",
    endpoint: string,
  ): Promise<string> {
    const command = new SubscribeCommand({
      TopicArn: topicArn,
      Protocol: protocol,
      Endpoint: endpoint,
    });

    const result = await this.client.send(command);
    return result.SubscriptionArn!;
  }
}
```

### AWS Lambda Invocation Client

```typescript
import {
  LambdaClient,
  InvokeCommand,
  InvokeCommandOutput,
} from "@aws-sdk/client-lambda";

interface AwsLambdaConfig {
  region: string;
}

class AwsLambdaClient {
  private client: LambdaClient;
  private retryHandler: RetryHandler;
  private circuitBreaker: CircuitBreaker;

  constructor(config: AwsLambdaConfig) {
    this.client = new LambdaClient({
      region: config.region,
      maxAttempts: 3,
    });
    this.retryHandler = new RetryHandler();
    this.circuitBreaker = new CircuitBreaker();
  }

  // Invoke Lambda synchronously
  async invoke<TPayload, TResponse>(
    functionName: string,
    payload: TPayload,
  ): Promise<TResponse> {
    return this.circuitBreaker.execute(() =>
      this.retryHandler.execute(async () => {
        const command = new InvokeCommand({
          FunctionName: functionName,
          InvocationType: "RequestResponse",
          Payload: Buffer.from(JSON.stringify(payload)),
        });

        const result: InvokeCommandOutput = await this.client.send(command);

        if (result.FunctionError) {
          const errorPayload = JSON.parse(
            Buffer.from(result.Payload!).toString(),
          );
          throw new Error(`Lambda error: ${errorPayload.errorMessage}`);
        }

        return JSON.parse(Buffer.from(result.Payload!).toString());
      }),
    );
  }

  // Invoke Lambda asynchronously
  async invokeAsync(
    functionName: string,
    payload: unknown,
  ): Promise<{ statusCode: number }> {
    const command = new InvokeCommand({
      FunctionName: functionName,
      InvocationType: "Event",
      Payload: Buffer.from(JSON.stringify(payload)),
    });

    const result = await this.client.send(command);
    return { statusCode: result.StatusCode! };
  }
}
```

---

## GCP SDK Integration

### Google Cloud Storage Client

```typescript
import { Storage, Bucket, File } from "@google-cloud/storage";

interface GcsConfig {
  projectId: string;
  bucketName: string;
  keyFilename?: string; // Path to service account key
}

class GoogleCloudStorageClient {
  private storage: Storage;
  private bucket: Bucket;
  private retryHandler: RetryHandler;
  private circuitBreaker: CircuitBreaker;

  constructor(config: GcsConfig) {
    this.storage = new Storage({
      projectId: config.projectId,
      keyFilename: config.keyFilename,
    });
    this.bucket = this.storage.bucket(config.bucketName);

    this.retryHandler = new RetryHandler({
      maxRetries: 3,
      baseDelayMs: 100,
      maxDelayMs: 3000,
      jitterFactor: 0.1,
      retryableStatuses: [408, 429, 500, 502, 503, 504],
      retryableErrors: ["ECONNRESET", "ETIMEDOUT"],
    });

    this.circuitBreaker = new CircuitBreaker();
  }

  // Upload file
  async uploadFile(
    destination: string,
    content: Buffer | string,
    options?: {
      contentType?: string;
      metadata?: Record<string, string>;
      isPublic?: boolean;
    },
  ): Promise<{ name: string; mediaLink: string }> {
    return this.circuitBreaker.execute(() =>
      this.retryHandler.execute(async () => {
        const file = this.bucket.file(destination);

        await file.save(content, {
          contentType: options?.contentType,
          metadata: options?.metadata,
          public: options?.isPublic || false,
        });

        const [metadata] = await file.getMetadata();
        return {
          name: metadata.name!,
          mediaLink: metadata.mediaLink!,
        };
      }),
    );
  }

  // Download file
  async downloadFile(filename: string): Promise<Buffer> {
    return this.circuitBreaker.execute(() =>
      this.retryHandler.execute(async () => {
        const file = this.bucket.file(filename);
        const [contents] = await file.download();
        return contents;
      }),
    );
  }

  // Generate signed URL
  async getSignedUrl(
    filename: string,
    action: "read" | "write",
    expiresInMs: number = 3600000,
  ): Promise<string> {
    const file = this.bucket.file(filename);

    const [url] = await file.getSignedUrl({
      action,
      expires: Date.now() + expiresInMs,
    });

    return url;
  }

  // Check if file exists
  async fileExists(filename: string): Promise<boolean> {
    const file = this.bucket.file(filename);
    const [exists] = await file.exists();
    return exists;
  }

  // List files
  async listFiles(
    prefix?: string,
    maxResults: number = 1000,
  ): Promise<Array<{ name: string; size: number; updated: Date }>> {
    const [files] = await this.bucket.getFiles({
      prefix,
      maxResults,
    });

    return files.map((file) => ({
      name: file.name,
      size: parseInt(file.metadata.size as string, 10),
      updated: new Date(file.metadata.updated as string),
    }));
  }

  // Delete file
  async deleteFile(filename: string): Promise<void> {
    await this.circuitBreaker.execute(() =>
      this.retryHandler.execute(async () => {
        await this.bucket.file(filename).delete();
      }),
    );
  }
}
```

### Google Pub/Sub Client

```typescript
import { PubSub, Topic, Subscription, Message } from "@google-cloud/pubsub";

interface PubSubConfig {
  projectId: string;
  keyFilename?: string;
}

class GooglePubSubClient {
  private pubsub: PubSub;
  private retryHandler: RetryHandler;

  constructor(config: PubSubConfig) {
    this.pubsub = new PubSub({
      projectId: config.projectId,
      keyFilename: config.keyFilename,
    });
    this.retryHandler = new RetryHandler();
  }

  // Publish message
  async publish(
    topicName: string,
    data: Record<string, unknown>,
    attributes?: Record<string, string>,
  ): Promise<string> {
    const topic = this.pubsub.topic(topicName);

    const messageId = await this.retryHandler.execute(() =>
      topic.publishMessage({
        data: Buffer.from(JSON.stringify(data)),
        attributes,
      }),
    );

    return messageId;
  }

  // Publish batch
  async publishBatch(
    topicName: string,
    messages: Array<{
      data: Record<string, unknown>;
      attributes?: Record<string, string>;
    }>,
  ): Promise<string[]> {
    const topic = this.pubsub.topic(topicName);

    const messageIds = await Promise.all(
      messages.map((msg) =>
        topic.publishMessage({
          data: Buffer.from(JSON.stringify(msg.data)),
          attributes: msg.attributes,
        }),
      ),
    );

    return messageIds;
  }

  // Subscribe to topic (pull)
  async pull(
    subscriptionName: string,
    maxMessages: number = 10,
  ): Promise<
    Array<{ id: string; data: unknown; attributes: Record<string, string> }>
  > {
    const subscription = this.pubsub.subscription(subscriptionName);

    const [messages] = await subscription.pull({ maxMessages });

    const results = messages.map((msg) => ({
      id: msg.ackId!,
      data: JSON.parse(msg.message.data?.toString() || "{}"),
      attributes: msg.message.attributes || {},
    }));

    // Acknowledge messages
    if (messages.length > 0) {
      await subscription.ack(messages.map((m) => m.ackId!));
    }

    return results;
  }

  // Subscribe with streaming (push)
  subscribe(
    subscriptionName: string,
    handler: (message: {
      id: string;
      data: unknown;
      ack: () => void;
      nack: () => void;
    }) => Promise<void>,
  ): void {
    const subscription = this.pubsub.subscription(subscriptionName);

    subscription.on("message", async (message: Message) => {
      await handler({
        id: message.id,
        data: JSON.parse(message.data.toString()),
        ack: () => message.ack(),
        nack: () => message.nack(),
      });
    });
  }

  // Create topic
  async createTopic(topicName: string): Promise<void> {
    await this.pubsub.createTopic(topicName);
  }

  // Create subscription
  async createSubscription(
    topicName: string,
    subscriptionName: string,
    options?: {
      ackDeadlineSeconds?: number;
      retainAckedMessages?: boolean;
      messageRetentionDuration?: { seconds: number };
    },
  ): Promise<void> {
    const topic = this.pubsub.topic(topicName);
    await topic.createSubscription(subscriptionName, options);
  }
}
```

### Google Cloud Functions Client

```typescript
import { CloudFunctionsServiceClient } from "@google-cloud/functions";

interface CloudFunctionsConfig {
  projectId: string;
  region: string;
  keyFilename?: string;
}

class GoogleCloudFunctionsClient {
  private client: CloudFunctionsServiceClient;
  private config: CloudFunctionsConfig;
  private retryHandler: RetryHandler;

  constructor(config: CloudFunctionsConfig) {
    this.config = config;
    this.client = new CloudFunctionsServiceClient({
      keyFilename: config.keyFilename,
    });
    this.retryHandler = new RetryHandler();
  }

  // Invoke HTTP function
  async invokeHttpFunction<TPayload, TResponse>(
    functionName: string,
    payload: TPayload,
    options?: { method?: "GET" | "POST"; headers?: Record<string, string> },
  ): Promise<TResponse> {
    // For HTTP-triggered functions, use fetch
    const functionUrl = `https://${this.config.region}-${this.config.projectId}.cloudfunctions.net/${functionName}`;

    return this.retryHandler.execute(async () => {
      const response = await fetch(functionUrl, {
        method: options?.method || "POST",
        headers: {
          "Content-Type": "application/json",
          ...options?.headers,
        },
        body: JSON.stringify(payload),
      });

      if (!response.ok) {
        throw new Error(`Function error: ${response.status}`);
      }

      return response.json();
    });
  }

  // Call function directly (for event-triggered functions)
  async callFunction(
    functionName: string,
    data: Record<string, unknown>,
  ): Promise<{ executionId: string; result: unknown }> {
    const name = `projects/${this.config.projectId}/locations/${this.config.region}/functions/${functionName}`;

    const [response] = await this.retryHandler.execute(() =>
      this.client.callFunction({
        name,
        data: JSON.stringify(data),
      }),
    );

    return {
      executionId: response.executionId || "",
      result: response.result ? JSON.parse(response.result) : null,
    };
  }
}
```

---

## SDK Best Practices

### 1. Client Initialization Pattern

```typescript
// Singleton pattern for SDK clients
class ApiClientFactory {
  private static instances: Map<string, unknown> = new Map();

  static getClient<T>(provider: string, factory: () => T): T {
    if (!this.instances.has(provider)) {
      this.instances.set(provider, factory());
    }
    return this.instances.get(provider) as T;
  }

  static resetClient(provider: string): void {
    this.instances.delete(provider);
  }
}

// Usage
const stripeClient = ApiClientFactory.getClient(
  "stripe",
  () =>
    new StripeClient({
      secretKey: process.env.STRIPE_SECRET_KEY!,
      webhookSecret: process.env.STRIPE_WEBHOOK_SECRET!,
    }),
);
```

### 2. Request Idempotency

```typescript
import { v4 as uuidv4 } from "uuid";

class IdempotentApiClient {
  private idempotencyKeys: Map<string, { key: string; timestamp: number }> =
    new Map();
  private keyTtlMs = 86400000; // 24 hours

  // Generate idempotency key for operation
  getIdempotencyKey(operationId: string): string {
    const existing = this.idempotencyKeys.get(operationId);

    if (existing && Date.now() - existing.timestamp < this.keyTtlMs) {
      return existing.key;
    }

    const newKey = uuidv4();
    this.idempotencyKeys.set(operationId, {
      key: newKey,
      timestamp: Date.now(),
    });

    return newKey;
  }

  // Make idempotent request
  async makeIdempotentRequest<T>(
    operationId: string,
    request: (idempotencyKey: string) => Promise<T>,
  ): Promise<T> {
    const key = this.getIdempotencyKey(operationId);
    return request(key);
  }
}

// Usage with Stripe
const idempotentClient = new IdempotentApiClient();

const payment = await idempotentClient.makeIdempotentRequest(
  `order-${orderId}-payment`,
  (idempotencyKey) =>
    stripe.paymentIntents.create(
      { amount: 1000, currency: "usd" },
      { idempotencyKey },
    ),
);
```

### 3. Connection Pooling

```typescript
import { Agent } from "https";

// Reuse connections for better performance
const httpsAgent = new Agent({
  keepAlive: true,
  maxSockets: 50,
  maxFreeSockets: 10,
  timeout: 30000,
});

// Use with fetch
const response = await fetch("https://api.example.com", {
  agent: httpsAgent,
});
```

### 4. Request Timeout Management

```typescript
class TimeoutManager {
  // Wrap promise with timeout
  static withTimeout<T>(
    promise: Promise<T>,
    timeoutMs: number,
    operation: string,
  ): Promise<T> {
    return Promise.race([
      promise,
      new Promise<T>((_, reject) =>
        setTimeout(
          () =>
            reject(
              new TimeoutError(`${operation} timed out after ${timeoutMs}ms`),
            ),
          timeoutMs,
        ),
      ),
    ]);
  }
}

class TimeoutError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "TimeoutError";
  }
}

// Usage
const result = await TimeoutManager.withTimeout(
  stripeClient.createPaymentIntent({ amount: 1000, currency: "usd" }),
  10000,
  "createPaymentIntent",
);
```

### 5. Graceful Shutdown

```typescript
class GracefulShutdown {
  private shutdownHandlers: Array<() => Promise<void>> = [];
  private isShuttingDown = false;

  register(handler: () => Promise<void>): void {
    this.shutdownHandlers.push(handler);
  }

  async shutdown(): Promise<void> {
    if (this.isShuttingDown) return;
    this.isShuttingDown = true;

    console.log("Starting graceful shutdown...");

    for (const handler of this.shutdownHandlers) {
      try {
        await handler();
      } catch (error) {
        console.error("Shutdown handler error:", error);
      }
    }

    console.log("Graceful shutdown complete");
  }
}

const shutdown = new GracefulShutdown();

// Register cleanup handlers
shutdown.register(async () => {
  console.log("Closing database connections...");
  await db.close();
});

shutdown.register(async () => {
  console.log("Draining message queues...");
  await messageQueue.drain();
});

// Handle process signals
process.on("SIGTERM", () => shutdown.shutdown());
process.on("SIGINT", () => shutdown.shutdown());
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

  toJSON(): Record<string, unknown> {
    return {
      name: this.name,
      provider: this.details.provider,
      code: this.details.code,
      message: this.details.message,
      statusCode: this.details.statusCode,
      retryable: this.details.retryable,
      details: this.details.details,
    };
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

  aws: (error: unknown) => {
    const awsError = error as any;
    return {
      provider: "aws",
      code: awsError.Code || awsError.name || "unknown",
      message: awsError.message || "Unknown AWS error",
      statusCode: awsError.$metadata?.httpStatusCode,
      retryable: awsError.$retryable?.throttling || false,
      details: {
        requestId: awsError.$metadata?.requestId,
        service: awsError.$service,
      },
    };
  },

  gcp: (error: unknown) => {
    const gcpError = error as any;
    return {
      provider: "gcp",
      code: gcpError.code?.toString() || "unknown",
      message: gcpError.message || "Unknown GCP error",
      statusCode: gcpError.code,
      retryable: [408, 429, 500, 502, 503, 504].includes(gcpError.code),
      details: {
        details: gcpError.details,
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
      canRecover: (e) => e.details.code === "card_declined",
      recover: async (e, ctx) => {
        await ctx.notifyUser(
          "Your card was declined. Please try another card.",
        );
      },
    },
    {
      canRecover: (e) => e.details.code === "idempotency_key_in_use",
      recover: async (e, ctx) => {
        const existingResult = await ctx.stripe.paymentIntents.retrieve(
          e.details.details?.existingObjectId as string,
        );
        ctx.setResult(existingResult);
      },
    },
  ],

  aws: [
    {
      canRecover: (e) => e.details.code === "ThrottlingException",
      recover: async (e, ctx) => {
        await new Promise((r) => setTimeout(r, 5000));
        ctx.retry = true;
      },
    },
    {
      canRecover: (e) => e.details.code === "ServiceUnavailable",
      recover: async (e, ctx) => {
        ctx.useBackupRegion = true;
        ctx.retry = true;
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
        if (context.retry) {
          return operation();
        }
        break;
      }
    }

    throw normalizedError;
  }
}
```

---

## Monitoring and Alerting

### API Health Monitor

```typescript
interface HealthCheckConfig {
  providers: Array<{
    name: string;
    healthEndpoint: string;
    timeout: number;
    expectedStatus?: number;
  }>;
  checkIntervalMs: number;
}

interface HealthStatus {
  provider: string;
  status: "healthy" | "degraded" | "unhealthy";
  latencyMs: number;
  lastChecked: Date;
  error?: string;
  consecutiveFailures: number;
}

class ApiHealthMonitor {
  private healthStatuses: Map<string, HealthStatus> = new Map();
  private checkInterval: NodeJS.Timeout | null = null;
  private alertCallbacks: Array<(status: HealthStatus) => void> = [];

  constructor(private config: HealthCheckConfig) {}

  start(): void {
    this.checkInterval = setInterval(
      () => this.checkAll(),
      this.config.checkIntervalMs,
    );
    this.checkAll(); // Initial check
  }

  stop(): void {
    if (this.checkInterval) {
      clearInterval(this.checkInterval);
      this.checkInterval = null;
    }
  }

  onAlert(callback: (status: HealthStatus) => void): void {
    this.alertCallbacks.push(callback);
  }

  private async checkAll(): Promise<void> {
    await Promise.all(
      this.config.providers.map((provider) => this.checkProvider(provider)),
    );
  }

  private async checkProvider(provider: {
    name: string;
    healthEndpoint: string;
    timeout: number;
    expectedStatus?: number;
  }): Promise<void> {
    const startTime = Date.now();
    const previousStatus = this.healthStatuses.get(provider.name);

    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), provider.timeout);

      const response = await fetch(provider.healthEndpoint, {
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      const latencyMs = Date.now() - startTime;
      const expectedStatus = provider.expectedStatus || 200;

      const status: HealthStatus = {
        provider: provider.name,
        status:
          response.status === expectedStatus
            ? latencyMs < 1000
              ? "healthy"
              : "degraded"
            : "degraded",
        latencyMs,
        lastChecked: new Date(),
        consecutiveFailures: 0,
      };

      this.healthStatuses.set(provider.name, status);
      this.checkAlerts(status, previousStatus);
    } catch (error) {
      const consecutiveFailures =
        (previousStatus?.consecutiveFailures || 0) + 1;

      const status: HealthStatus = {
        provider: provider.name,
        status: consecutiveFailures >= 3 ? "unhealthy" : "degraded",
        latencyMs: Date.now() - startTime,
        lastChecked: new Date(),
        error: error instanceof Error ? error.message : "Unknown error",
        consecutiveFailures,
      };

      this.healthStatuses.set(provider.name, status);
      this.checkAlerts(status, previousStatus);
    }
  }

  private checkAlerts(
    current: HealthStatus,
    previous: HealthStatus | undefined,
  ): void {
    // Alert on status changes
    if (!previous || previous.status !== current.status) {
      if (current.status !== "healthy") {
        this.alertCallbacks.forEach((cb) => cb(current));
      }
    }

    // Alert on high latency
    if (current.latencyMs > 2000 && current.status === "healthy") {
      this.alertCallbacks.forEach((cb) =>
        cb({ ...current, status: "degraded" }),
      );
    }
  }

  getStatus(provider: string): HealthStatus | undefined {
    return this.healthStatuses.get(provider);
  }

  getAllStatuses(): HealthStatus[] {
    return Array.from(this.healthStatuses.values());
  }
}

// Provider health endpoints
const healthEndpoints: Record<string, string> = {
  stripe: "https://status.stripe.com/api/v2/status.json",
  twilio: "https://status.twilio.com/api/v2/status.json",
  sendgrid: "https://status.sendgrid.com/api/v2/status.json",
  github: "https://www.githubstatus.com/api/v2/status.json",
  aws: "https://health.aws.amazon.com/health/status",
};
```

### Metrics Collector

```typescript
interface ApiMetrics {
  provider: string;
  endpoint: string;
  method: string;
  statusCode: number;
  latencyMs: number;
  timestamp: Date;
  success: boolean;
  errorCode?: string;
}

class ApiMetricsCollector {
  private metrics: ApiMetrics[] = [];
  private maxMetrics = 10000;
  private flushCallbacks: Array<(metrics: ApiMetrics[]) => Promise<void>> = [];

  record(metric: Omit<ApiMetrics, "timestamp">): void {
    const fullMetric: ApiMetrics = {
      ...metric,
      timestamp: new Date(),
    };

    this.metrics.push(fullMetric);

    // Flush if buffer is full
    if (this.metrics.length >= this.maxMetrics) {
      this.flush();
    }
  }

  onFlush(callback: (metrics: ApiMetrics[]) => Promise<void>): void {
    this.flushCallbacks.push(callback);
  }

  async flush(): Promise<void> {
    if (this.metrics.length === 0) return;

    const metricsToFlush = [...this.metrics];
    this.metrics = [];

    for (const callback of this.flushCallbacks) {
      await callback(metricsToFlush);
    }
  }

  // Get aggregated stats
  getStats(
    provider: string,
    timeRangeMs: number = 3600000,
  ): {
    totalRequests: number;
    successRate: number;
    avgLatencyMs: number;
    p95LatencyMs: number;
    errorsByCode: Record<string, number>;
  } {
    const cutoff = Date.now() - timeRangeMs;
    const relevantMetrics = this.metrics.filter(
      (m) => m.provider === provider && m.timestamp.getTime() > cutoff,
    );

    if (relevantMetrics.length === 0) {
      return {
        totalRequests: 0,
        successRate: 0,
        avgLatencyMs: 0,
        p95LatencyMs: 0,
        errorsByCode: {},
      };
    }

    const successCount = relevantMetrics.filter((m) => m.success).length;
    const latencies = relevantMetrics
      .map((m) => m.latencyMs)
      .sort((a, b) => a - b);
    const p95Index = Math.floor(latencies.length * 0.95);

    const errorsByCode: Record<string, number> = {};
    relevantMetrics
      .filter((m) => !m.success && m.errorCode)
      .forEach((m) => {
        errorsByCode[m.errorCode!] = (errorsByCode[m.errorCode!] || 0) + 1;
      });

    return {
      totalRequests: relevantMetrics.length,
      successRate: successCount / relevantMetrics.length,
      avgLatencyMs: latencies.reduce((a, b) => a + b, 0) / latencies.length,
      p95LatencyMs: latencies[p95Index] || 0,
      errorsByCode,
    };
  }
}

// Prometheus-style metrics export
class PrometheusExporter {
  constructor(private collector: ApiMetricsCollector) {}

  export(providers: string[]): string {
    const lines: string[] = [];

    for (const provider of providers) {
      const stats = this.collector.getStats(provider);

      lines.push(
        `# HELP api_requests_total Total API requests`,
        `# TYPE api_requests_total counter`,
        `api_requests_total{provider="${provider}"} ${stats.totalRequests}`,
        ``,
        `# HELP api_success_rate API success rate`,
        `# TYPE api_success_rate gauge`,
        `api_success_rate{provider="${provider}"} ${stats.successRate}`,
        ``,
        `# HELP api_latency_avg_ms Average API latency in milliseconds`,
        `# TYPE api_latency_avg_ms gauge`,
        `api_latency_avg_ms{provider="${provider}"} ${stats.avgLatencyMs}`,
        ``,
        `# HELP api_latency_p95_ms P95 API latency in milliseconds`,
        `# TYPE api_latency_p95_ms gauge`,
        `api_latency_p95_ms{provider="${provider}"} ${stats.p95LatencyMs}`,
      );

      // Error breakdown
      for (const [code, count] of Object.entries(stats.errorsByCode)) {
        lines.push(
          `api_errors_total{provider="${provider}",code="${code}"} ${count}`,
        );
      }

      lines.push("");
    }

    return lines.join("\n");
  }
}
```

### Alert Configuration

```typescript
interface AlertRule {
  name: string;
  provider: string;
  condition: (stats: ReturnType<ApiMetricsCollector["getStats"]>) => boolean;
  severity: "info" | "warning" | "critical";
  message: (stats: ReturnType<ApiMetricsCollector["getStats"]>) => string;
  cooldownMs: number;
}

class AlertManager {
  private lastAlerts: Map<string, number> = new Map();
  private notifiers: Array<
    (alert: {
      rule: AlertRule;
      message: string;
      timestamp: Date;
    }) => Promise<void>
  > = [];

  constructor(
    private rules: AlertRule[],
    private collector: ApiMetricsCollector,
  ) {}

  addNotifier(
    notifier: (alert: {
      rule: AlertRule;
      message: string;
      timestamp: Date;
    }) => Promise<void>,
  ): void {
    this.notifiers.push(notifier);
  }

  async evaluate(): Promise<void> {
    for (const rule of this.rules) {
      const stats = this.collector.getStats(rule.provider);

      if (rule.condition(stats)) {
        const lastAlert = this.lastAlerts.get(rule.name);
        const now = Date.now();

        if (!lastAlert || now - lastAlert > rule.cooldownMs) {
          this.lastAlerts.set(rule.name, now);

          const alert = {
            rule,
            message: rule.message(stats),
            timestamp: new Date(),
          };

          for (const notifier of this.notifiers) {
            await notifier(alert);
          }
        }
      }
    }
  }
}

// Example alert rules
const alertRules: AlertRule[] = [
  {
    name: "stripe_high_error_rate",
    provider: "stripe",
    condition: (stats) => stats.successRate < 0.95 && stats.totalRequests > 10,
    severity: "warning",
    message: (stats) =>
      `Stripe error rate is ${((1 - stats.successRate) * 100).toFixed(1)}%`,
    cooldownMs: 300000, // 5 minutes
  },
  {
    name: "stripe_high_latency",
    provider: "stripe",
    condition: (stats) => stats.p95LatencyMs > 3000,
    severity: "warning",
    message: (stats) => `Stripe P95 latency is ${stats.p95LatencyMs}ms`,
    cooldownMs: 300000,
  },
  {
    name: "aws_critical_errors",
    provider: "aws",
    condition: (stats) => stats.successRate < 0.8,
    severity: "critical",
    message: (stats) =>
      `AWS error rate critical: ${((1 - stats.successRate) * 100).toFixed(1)}%`,
    cooldownMs: 60000, // 1 minute
  },
];
```

---

## Cost Tracking

### API Cost Tracker

```typescript
interface CostConfig {
  provider: string;
  pricing: {
    perRequest?: number;
    perUnit?: { unit: string; price: number };
    tiers?: Array<{ upTo: number; price: number }>;
    monthly?: number;
  };
  currency: string;
}

interface UsageRecord {
  provider: string;
  operation: string;
  units: number;
  timestamp: Date;
  metadata?: Record<string, unknown>;
}

class ApiCostTracker {
  private usageRecords: UsageRecord[] = [];
  private costConfigs: Map<string, CostConfig> = new Map();
  private budgetAlerts: Array<{
    provider: string;
    threshold: number;
    callback: (current: number, threshold: number) => void;
  }> = [];

  registerProvider(config: CostConfig): void {
    this.costConfigs.set(config.provider, config);
  }

  recordUsage(record: Omit<UsageRecord, "timestamp">): void {
    this.usageRecords.push({
      ...record,
      timestamp: new Date(),
    });

    // Check budget alerts
    this.checkBudgetAlerts(record.provider);
  }

  setBudgetAlert(
    provider: string,
    threshold: number,
    callback: (current: number, threshold: number) => void,
  ): void {
    this.budgetAlerts.push({ provider, threshold, callback });
  }

  private checkBudgetAlerts(provider: string): void {
    const currentCost = this.getProviderCost(provider, "month");

    for (const alert of this.budgetAlerts) {
      if (alert.provider === provider && currentCost >= alert.threshold) {
        alert.callback(currentCost, alert.threshold);
      }
    }
  }

  getProviderCost(provider: string, period: "day" | "week" | "month"): number {
    const config = this.costConfigs.get(provider);
    if (!config) return 0;

    const periodMs = {
      day: 86400000,
      week: 604800000,
      month: 2592000000,
    }[period];

    const cutoff = Date.now() - periodMs;
    const periodRecords = this.usageRecords.filter(
      (r) => r.provider === provider && r.timestamp.getTime() > cutoff,
    );

    const totalUnits = periodRecords.reduce((sum, r) => sum + r.units, 0);

    return this.calculateCost(config, totalUnits);
  }

  private calculateCost(config: CostConfig, units: number): number {
    const pricing = config.pricing;

    if (pricing.perRequest) {
      return units * pricing.perRequest;
    }

    if (pricing.perUnit) {
      return units * pricing.perUnit.price;
    }

    if (pricing.tiers) {
      let cost = 0;
      let remainingUnits = units;

      for (let i = 0; i < pricing.tiers.length; i++) {
        const tier = pricing.tiers[i];
        const prevLimit = i > 0 ? pricing.tiers[i - 1].upTo : 0;
        const tierUnits = Math.min(remainingUnits, tier.upTo - prevLimit);

        cost += tierUnits * tier.price;
        remainingUnits -= tierUnits;

        if (remainingUnits <= 0) break;
      }

      return cost;
    }

    return pricing.monthly || 0;
  }

  getCostReport(period: "day" | "week" | "month"): {
    total: number;
    byProvider: Record<string, number>;
    byOperation: Record<string, number>;
    projectedMonthly: number;
  } {
    const providers = Array.from(this.costConfigs.keys());
    const byProvider: Record<string, number> = {};
    const byOperation: Record<string, number> = {};

    for (const provider of providers) {
      byProvider[provider] = this.getProviderCost(provider, period);
    }

    const periodMs = {
      day: 86400000,
      week: 604800000,
      month: 2592000000,
    }[period];

    const cutoff = Date.now() - periodMs;
    const periodRecords = this.usageRecords.filter(
      (r) => r.timestamp.getTime() > cutoff,
    );

    for (const record of periodRecords) {
      const opKey = `${record.provider}:${record.operation}`;
      const config = this.costConfigs.get(record.provider);
      if (config) {
        byOperation[opKey] =
          (byOperation[opKey] || 0) + this.calculateCost(config, record.units);
      }
    }

    const total = Object.values(byProvider).reduce((a, b) => a + b, 0);
    const multiplier = {
      day: 30,
      week: 4.33,
      month: 1,
    }[period];

    return {
      total,
      byProvider,
      byOperation,
      projectedMonthly: total * multiplier,
    };
  }

  exportCsv(startDate: Date, endDate: Date): string {
    const records = this.usageRecords.filter(
      (r) => r.timestamp >= startDate && r.timestamp <= endDate,
    );

    const headers = ["timestamp", "provider", "operation", "units", "cost"];
    const rows = records.map((r) => {
      const config = this.costConfigs.get(r.provider);
      const cost = config ? this.calculateCost(config, r.units) : 0;

      return [
        r.timestamp.toISOString(),
        r.provider,
        r.operation,
        r.units.toString(),
        cost.toFixed(4),
      ].join(",");
    });

    return [headers.join(","), ...rows].join("\n");
  }
}

// Example cost configurations
const costConfigs: CostConfig[] = [
  {
    provider: "stripe",
    pricing: {
      perRequest: 0.0, // Stripe charges per transaction, not per API call
    },
    currency: "USD",
  },
  {
    provider: "twilio",
    pricing: {
      perUnit: { unit: "sms", price: 0.0075 }, // Per SMS segment
    },
    currency: "USD",
  },
  {
    provider: "sendgrid",
    pricing: {
      tiers: [
        { upTo: 100, price: 0.0 }, // Free tier
        { upTo: 50000, price: 0.001 },
        { upTo: 100000, price: 0.0008 },
        { upTo: Infinity, price: 0.0005 },
      ],
    },
    currency: "USD",
  },
  {
    provider: "openai",
    pricing: {
      perUnit: { unit: "1k_tokens", price: 0.03 }, // GPT-4 pricing
    },
    currency: "USD",
  },
  {
    provider: "aws_s3",
    pricing: {
      tiers: [
        { upTo: 50000, price: 0.023 / 1000 }, // Per GB
        { upTo: 450000, price: 0.022 / 1000 },
        { upTo: Infinity, price: 0.021 / 1000 },
      ],
    },
    currency: "USD",
  },
];

// Usage
const costTracker = new ApiCostTracker();
costConfigs.forEach((config) => costTracker.registerProvider(config));

// Record API usage
costTracker.recordUsage({
  provider: "twilio",
  operation: "send_sms",
  units: 1,
});

costTracker.recordUsage({
  provider: "openai",
  operation: "chat_completion",
  units: 2.5, // 2500 tokens = 2.5 units
});

// Set budget alert
costTracker.setBudgetAlert("twilio", 100, (current, threshold) => {
  console.warn(`Twilio cost $${current} exceeded $${threshold} threshold`);
});
```

---

## Testing with Mock Services

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

  mockResponse(method: string, path: string, response: MockResponse): void {
    const key = `${method}:${path}`;
    const existing = this.responses.get(key) || [];
    existing.push(response);
    this.responses.set(key, existing);
  }

  getResponse(method: string, path: string): MockResponse | undefined {
    const key = `${method}:${path}`;
    const responses = this.responses.get(key);

    if (!responses || responses.length === 0) {
      return undefined;
    }

    return responses.shift();
  }

  logRequest(method: string, path: string, body: unknown): void {
    this.requestLog.push({ method, path, body });
  }

  getRequests(): Array<{ method: string; path: string; body: unknown }> {
    return [...this.requestLog];
  }

  reset(): void {
    this.responses.clear();
    this.requestLog = [];
  }
}

// Test helper for common scenarios
class ApiIntegrationTestHelper {
  constructor(
    private mockServer: MockProviderServer,
    private provider: string,
  ) {}

  async testRateLimitHandling(
    client: any,
    operation: () => Promise<any>,
  ): Promise<void> {
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
    for (let i = 0; i < failureCount; i++) {
      this.mockServer.mockResponse("POST", "/test", {
        status: 500,
        data: { error: "internal_error" },
      });
    }

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
}
```

### Test Fixtures

```typescript
const testFixtures = {
  stripe: {
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

  aws: {
    s3PutResponse: {
      ETag: '"abc123"',
      VersionId: "v1",
    },
    sesResponse: {
      MessageId: "msg_test_123",
    },
  },

  gcp: {
    storageResponse: {
      name: "test-file.txt",
      mediaLink: "https://storage.googleapis.com/test-bucket/test-file.txt",
    },
    pubsubResponse: {
      messageId: "msg_test_123",
    },
  },
};
```

---

## Best Practices Checklist

### Implementation Checklist

- [ ] **Authentication**
  - [ ] Use PKCE for authorization code flow
  - [ ] Store tokens securely (encrypted at rest)
  - [ ] Implement proactive token refresh
  - [ ] Rotate API keys every 90 days
  - [ ] Never hardcode credentials

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

- [ ] **Monitoring**
  - [ ] Track success rate per provider
  - [ ] Monitor latency percentiles
  - [ ] Set up alerts for degradation
  - [ ] Export metrics to monitoring system

- [ ] **Cost Tracking**
  - [ ] Record all API usage
  - [ ] Set budget alerts
  - [ ] Generate cost reports
  - [ ] Optimize high-cost operations

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

# AWS S3 integration
/agents/integration/third-party-api-expert implement AWS S3 file upload with presigned URLs

# GCP Pub/Sub
/agents/integration/third-party-api-expert set up Google Pub/Sub for event streaming

# API monitoring
/agents/integration/third-party-api-expert configure API health monitoring with alerts

# Cost tracking
/agents/integration/third-party-api-expert implement cost tracking for Twilio and SendGrid
```

---

## Related Agents

| Agent                                        | Use Case                 |
| -------------------------------------------- | ------------------------ |
| `/agents/testing/api-test-expert`            | Integration testing      |
| `/agents/integration/webhook-expert`         | Webhook design patterns  |
| `/agents/integration/api-integration-expert` | General API integration  |
| `/agents/backend/authentication-specialist`  | OAuth implementation     |
| `/agents/security/security-expert`           | Security review          |
| `/agents/cloud/aws-expert`                   | AWS services integration |
| `/agents/cloud/gcp-expert`                   | GCP services integration |
| `/agents/devops/monitoring-expert`           | Monitoring setup         |
| `/agents/business/cost-optimizer`            | Cost optimization        |

---

_Agent Version: 3.0.0 | Category: Integration | Author: Ahmed Adel Bakr Alderai_
