---
name: Webhook Expert Agent
description: Implements production-grade webhook systems with signature verification, idempotency, retry logic, and event queuing
version: 1.0.0
author: Ahmed Adel Bakr Alderai
category: integration
tags:
  - webhooks
  - event-driven
  - integrations
  - api
  - security
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
  - /agents/security/security-auditor
  - /agents/testing/integration-tester
inputs:
  - name: task
    type: string
    required: true
    description: The webhook implementation task
  - name: provider
    type: string
    required: false
    description: "Webhook provider (stripe, github, twilio, custom)"
  - name: framework
    type: string
    required: false
    default: fastapi
    description: "Target framework (express, fastapi, flask, django)"
outputs:
  - webhook_endpoint
  - signature_verification
  - idempotency_handler
  - retry_queue
  - test_suite
---

# Webhook Expert Agent

Expert in designing and implementing production-grade webhook systems with comprehensive security, reliability, and observability features.

## Arguments

- `$ARGUMENTS` - Webhook implementation task (e.g., "implement Stripe webhook handler")

## Invoke Agent

```
Use the Task tool with subagent_type="webhook-expert" to:

1. Design webhook endpoint architecture
2. Implement signature verification (HMAC-SHA256)
3. Add idempotency handling with event deduplication
4. Configure retry logic with exponential backoff
5. Set up event queuing for async processing
6. Create comprehensive test suite

Task: $ARGUMENTS
```

## Core Capabilities

### 1. Webhook Endpoint Design

Design RESTful webhook endpoints following best practices:

- Single-purpose endpoints per event category
- Immediate 200/202 response (process async)
- Structured logging with correlation IDs
- Health check endpoints for monitoring

### 2. Signature Verification

Verify webhook authenticity using cryptographic signatures:

- HMAC-SHA256 (Stripe, GitHub, Shopify)
- Ed25519 (Svix, modern providers)
- RSA signatures (legacy systems)
- Timestamp validation (replay attack prevention)

### 3. Idempotency Handling

Prevent duplicate event processing:

- Event ID tracking in persistent storage
- TTL-based cleanup of processed events
- Atomic check-and-set operations
- Concurrent request handling

### 4. Retry Logic

Handle transient failures gracefully:

- Exponential backoff: 1s, 2s, 4s, 8s, 16s...
- Maximum retry attempts (configurable)
- Dead letter queue for failed events
- Circuit breaker pattern

### 5. Event Queuing

Decouple ingestion from processing:

- Redis/RabbitMQ/SQS integration
- Priority queuing for critical events
- Batch processing support
- Backpressure handling

### 6. Testing Tools

Comprehensive webhook testing:

- Signature generation utilities
- Mock webhook payloads
- Replay attack simulation
- Load testing scripts

---

## Implementation Templates

### FastAPI (Python) - Recommended

```python
"""
Webhook Handler - FastAPI Implementation
Production-grade webhook processing with all security features.
"""
import hashlib
import hmac
import json
import time
from datetime import datetime, timedelta
from typing import Optional
from uuid import uuid4

from fastapi import FastAPI, Request, HTTPException, Header, BackgroundTasks, Depends
from pydantic import BaseModel
from redis import Redis
import structlog

# Configuration
WEBHOOK_SECRET = os.environ["WEBHOOK_SECRET"]  # Never hardcode
SIGNATURE_TOLERANCE_SECONDS = 300  # 5 minute tolerance
IDEMPOTENCY_TTL_SECONDS = 86400  # 24 hours
MAX_RETRIES = 5
RETRY_BACKOFF_BASE = 2

logger = structlog.get_logger()
app = FastAPI()
redis_client = Redis.from_url(os.environ.get("REDIS_URL", "redis://localhost:6379"))


# --- Models ---

class WebhookEvent(BaseModel):
    """Webhook event payload structure."""
    id: str
    type: str
    created: int
    data: dict


class ProcessingResult(BaseModel):
    """Result of webhook processing."""
    event_id: str
    status: str  # "processed", "duplicate", "failed"
    message: Optional[str] = None


# --- Signature Verification ---

def verify_signature(
    payload: bytes,
    signature_header: str,
    timestamp_header: str,
    secret: str
) -> bool:
    """
    Verify webhook signature using HMAC-SHA256.

    Args:
        payload: Raw request body bytes
        signature_header: Signature from webhook header
        timestamp_header: Timestamp from webhook header
        secret: Webhook signing secret

    Returns:
        True if signature is valid

    Raises:
        HTTPException: If signature verification fails
    """
    # Validate timestamp to prevent replay attacks
    try:
        timestamp = int(timestamp_header)
    except (ValueError, TypeError):
        logger.warning("webhook_invalid_timestamp", timestamp=timestamp_header)
        raise HTTPException(status_code=400, detail="Invalid timestamp")

    current_time = int(time.time())
    if abs(current_time - timestamp) > SIGNATURE_TOLERANCE_SECONDS:
        logger.warning(
            "webhook_timestamp_expired",
            timestamp=timestamp,
            current_time=current_time,
            tolerance=SIGNATURE_TOLERANCE_SECONDS
        )
        raise HTTPException(status_code=400, detail="Timestamp expired")

    # Compute expected signature
    signed_payload = f"{timestamp}.{payload.decode('utf-8')}"
    expected_signature = hmac.new(
        secret.encode("utf-8"),
        signed_payload.encode("utf-8"),
        hashlib.sha256
    ).hexdigest()

    # Constant-time comparison to prevent timing attacks
    if not hmac.compare_digest(expected_signature, signature_header):
        logger.warning(
            "webhook_signature_mismatch",
            expected=expected_signature[:16] + "...",
            received=signature_header[:16] + "..."
        )
        raise HTTPException(status_code=401, detail="Invalid signature")

    return True


# --- Idempotency Handler ---

class IdempotencyHandler:
    """Handles event deduplication using Redis."""

    def __init__(self, redis: Redis, ttl: int = IDEMPOTENCY_TTL_SECONDS):
        self.redis = redis
        self.ttl = ttl
        self.key_prefix = "webhook:processed:"

    def is_duplicate(self, event_id: str) -> bool:
        """Check if event was already processed."""
        key = f"{self.key_prefix}{event_id}"
        return self.redis.exists(key) > 0

    def mark_processed(self, event_id: str, result: dict) -> None:
        """Mark event as processed with result metadata."""
        key = f"{self.key_prefix}{event_id}"
        self.redis.setex(
            key,
            self.ttl,
            json.dumps({
                "processed_at": datetime.utcnow().isoformat(),
                "result": result
            })
        )

    def get_previous_result(self, event_id: str) -> Optional[dict]:
        """Get result of previously processed event."""
        key = f"{self.key_prefix}{event_id}"
        data = self.redis.get(key)
        if data:
            return json.loads(data)
        return None


idempotency = IdempotencyHandler(redis_client)


# --- Retry Queue ---

class RetryQueue:
    """Manages webhook retry logic with exponential backoff."""

    def __init__(self, redis: Redis, max_retries: int = MAX_RETRIES):
        self.redis = redis
        self.max_retries = max_retries
        self.queue_key = "webhook:retry_queue"
        self.dlq_key = "webhook:dead_letter_queue"

    def enqueue_retry(self, event: dict, attempt: int) -> None:
        """Add event to retry queue with backoff delay."""
        if attempt >= self.max_retries:
            self._move_to_dlq(event, "max_retries_exceeded")
            return

        delay = RETRY_BACKOFF_BASE ** attempt
        execute_at = time.time() + delay

        self.redis.zadd(self.queue_key, {
            json.dumps({
                "event": event,
                "attempt": attempt + 1,
                "enqueued_at": datetime.utcnow().isoformat()
            }): execute_at
        })

        logger.info(
            "webhook_retry_enqueued",
            event_id=event.get("id"),
            attempt=attempt + 1,
            delay_seconds=delay
        )

    def get_ready_events(self, batch_size: int = 10) -> list:
        """Get events ready for retry processing."""
        now = time.time()
        items = self.redis.zrangebyscore(
            self.queue_key, 0, now, start=0, num=batch_size
        )
        return [json.loads(item) for item in items]

    def remove_from_queue(self, event_json: str) -> None:
        """Remove processed event from retry queue."""
        self.redis.zrem(self.queue_key, event_json)

    def _move_to_dlq(self, event: dict, reason: str) -> None:
        """Move failed event to dead letter queue."""
        self.redis.lpush(self.dlq_key, json.dumps({
            "event": event,
            "reason": reason,
            "moved_at": datetime.utcnow().isoformat()
        }))
        logger.error(
            "webhook_moved_to_dlq",
            event_id=event.get("id"),
            reason=reason
        )


retry_queue = RetryQueue(redis_client)


# --- Event Handlers ---

async def process_payment_succeeded(event: WebhookEvent) -> dict:
    """Handle payment.succeeded webhook event."""
    logger.info("processing_payment_succeeded", event_id=event.id)
    # Implement your business logic here
    # Example: Update order status, send confirmation email
    return {"action": "payment_confirmed", "amount": event.data.get("amount")}


async def process_payment_failed(event: WebhookEvent) -> dict:
    """Handle payment.failed webhook event."""
    logger.info("processing_payment_failed", event_id=event.id)
    # Implement your business logic here
    return {"action": "payment_failed", "reason": event.data.get("failure_reason")}


async def process_subscription_updated(event: WebhookEvent) -> dict:
    """Handle subscription.updated webhook event."""
    logger.info("processing_subscription_updated", event_id=event.id)
    return {"action": "subscription_updated"}


# Event handler registry
EVENT_HANDLERS = {
    "payment.succeeded": process_payment_succeeded,
    "payment.failed": process_payment_failed,
    "subscription.updated": process_subscription_updated,
}


async def process_event(event: WebhookEvent) -> dict:
    """Route event to appropriate handler."""
    handler = EVENT_HANDLERS.get(event.type)
    if not handler:
        logger.warning("webhook_unknown_event_type", event_type=event.type)
        return {"action": "ignored", "reason": "unknown_event_type"}

    return await handler(event)


# --- Main Webhook Endpoint ---

@app.post("/webhooks/stripe", response_model=ProcessingResult)
async def handle_stripe_webhook(
    request: Request,
    background_tasks: BackgroundTasks,
    stripe_signature: str = Header(..., alias="Stripe-Signature"),
    stripe_timestamp: str = Header(..., alias="Stripe-Timestamp"),
):
    """
    Handle incoming Stripe webhook events.

    Security:
    - Verifies HMAC-SHA256 signature
    - Validates timestamp (5 minute tolerance)
    - Implements idempotency (24 hour window)
    - Processes events asynchronously

    Returns:
        202 Accepted - Event queued for processing
        200 OK - Duplicate event (already processed)
        400 Bad Request - Invalid payload/timestamp
        401 Unauthorized - Invalid signature
    """
    # Get raw body for signature verification
    body = await request.body()
    correlation_id = str(uuid4())

    logger.info("webhook_received", correlation_id=correlation_id)

    # Verify signature
    verify_signature(body, stripe_signature, stripe_timestamp, WEBHOOK_SECRET)

    # Parse event
    try:
        event_data = json.loads(body)
        event = WebhookEvent(**event_data)
    except (json.JSONDecodeError, ValueError) as e:
        logger.error("webhook_parse_error", error=str(e))
        raise HTTPException(status_code=400, detail="Invalid payload")

    # Check idempotency
    if idempotency.is_duplicate(event.id):
        previous = idempotency.get_previous_result(event.id)
        logger.info(
            "webhook_duplicate_event",
            event_id=event.id,
            correlation_id=correlation_id
        )
        return ProcessingResult(
            event_id=event.id,
            status="duplicate",
            message="Event already processed"
        )

    # Process asynchronously
    async def process_in_background():
        try:
            result = await process_event(event)
            idempotency.mark_processed(event.id, result)
            logger.info(
                "webhook_processed",
                event_id=event.id,
                event_type=event.type,
                correlation_id=correlation_id
            )
        except Exception as e:
            logger.error(
                "webhook_processing_error",
                event_id=event.id,
                error=str(e),
                correlation_id=correlation_id
            )
            retry_queue.enqueue_retry(event_data, attempt=0)

    background_tasks.add_task(process_in_background)

    # Return immediately with 202 Accepted
    return ProcessingResult(
        event_id=event.id,
        status="accepted",
        message="Event queued for processing"
    )


@app.get("/webhooks/health")
async def webhook_health():
    """Health check endpoint for webhook system."""
    return {
        "status": "healthy",
        "redis": redis_client.ping(),
        "timestamp": datetime.utcnow().isoformat()
    }
```

### Express (Node.js/TypeScript)

```typescript
/**
 * Webhook Handler - Express/TypeScript Implementation
 * Production-grade webhook processing with all security features.
 */
import express, { Request, Response, NextFunction } from "express";
import crypto from "crypto";
import Redis from "ioredis";
import { v4 as uuidv4 } from "uuid";

// Configuration
const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET!;
const SIGNATURE_TOLERANCE_MS = 300_000; // 5 minutes
const IDEMPOTENCY_TTL_SECONDS = 86400; // 24 hours
const MAX_RETRIES = 5;
const RETRY_BACKOFF_BASE = 2;

const redis = new Redis(process.env.REDIS_URL || "redis://localhost:6379");
const app = express();

// --- Interfaces ---

interface WebhookEvent {
  id: string;
  type: string;
  created: number;
  data: Record<string, unknown>;
}

interface ProcessingResult {
  eventId: string;
  status: "processed" | "duplicate" | "accepted" | "failed";
  message?: string;
}

// --- Middleware ---

// Raw body parser for signature verification
app.use("/webhooks", express.raw({ type: "application/json" }));

// --- Signature Verification ---

function verifySignature(
  payload: Buffer,
  signatureHeader: string,
  timestampHeader: string,
  secret: string,
): void {
  // Validate timestamp
  const timestamp = parseInt(timestampHeader, 10);
  if (isNaN(timestamp)) {
    throw new WebhookError("Invalid timestamp", 400);
  }

  const now = Date.now();
  if (Math.abs(now - timestamp * 1000) > SIGNATURE_TOLERANCE_MS) {
    throw new WebhookError("Timestamp expired", 400);
  }

  // Compute expected signature
  const signedPayload = `${timestamp}.${payload.toString("utf-8")}`;
  const expectedSignature = crypto
    .createHmac("sha256", secret)
    .update(signedPayload)
    .digest("hex");

  // Constant-time comparison
  if (
    !crypto.timingSafeEqual(
      Buffer.from(expectedSignature),
      Buffer.from(signatureHeader),
    )
  ) {
    throw new WebhookError("Invalid signature", 401);
  }
}

// --- Custom Error Class ---

class WebhookError extends Error {
  constructor(
    message: string,
    public statusCode: number = 400,
  ) {
    super(message);
    this.name = "WebhookError";
  }
}

// --- Idempotency Handler ---

class IdempotencyHandler {
  private keyPrefix = "webhook:processed:";

  async isDuplicate(eventId: string): Promise<boolean> {
    const exists = await redis.exists(`${this.keyPrefix}${eventId}`);
    return exists > 0;
  }

  async markProcessed(
    eventId: string,
    result: Record<string, unknown>,
  ): Promise<void> {
    await redis.setex(
      `${this.keyPrefix}${eventId}`,
      IDEMPOTENCY_TTL_SECONDS,
      JSON.stringify({
        processedAt: new Date().toISOString(),
        result,
      }),
    );
  }

  async getPreviousResult(
    eventId: string,
  ): Promise<Record<string, unknown> | null> {
    const data = await redis.get(`${this.keyPrefix}${eventId}`);
    return data ? JSON.parse(data) : null;
  }
}

const idempotency = new IdempotencyHandler();

// --- Retry Queue ---

class RetryQueue {
  private queueKey = "webhook:retry_queue";
  private dlqKey = "webhook:dead_letter_queue";

  async enqueueRetry(event: WebhookEvent, attempt: number): Promise<void> {
    if (attempt >= MAX_RETRIES) {
      await this.moveToDLQ(event, "max_retries_exceeded");
      return;
    }

    const delay = Math.pow(RETRY_BACKOFF_BASE, attempt);
    const executeAt = Date.now() / 1000 + delay;

    await redis.zadd(
      this.queueKey,
      executeAt,
      JSON.stringify({
        event,
        attempt: attempt + 1,
        enqueuedAt: new Date().toISOString(),
      }),
    );

    console.log(
      `Webhook retry enqueued: ${event.id}, attempt: ${attempt + 1}, delay: ${delay}s`,
    );
  }

  async getReadyEvents(
    batchSize: number = 10,
  ): Promise<Array<{ event: WebhookEvent; attempt: number }>> {
    const now = Date.now() / 1000;
    const items = await redis.zrangebyscore(
      this.queueKey,
      0,
      now,
      "LIMIT",
      0,
      batchSize,
    );
    return items.map((item) => JSON.parse(item));
  }

  private async moveToDLQ(event: WebhookEvent, reason: string): Promise<void> {
    await redis.lpush(
      this.dlqKey,
      JSON.stringify({
        event,
        reason,
        movedAt: new Date().toISOString(),
      }),
    );
    console.error(`Webhook moved to DLQ: ${event.id}, reason: ${reason}`);
  }
}

const retryQueue = new RetryQueue();

// --- Event Handlers ---

type EventHandler = (event: WebhookEvent) => Promise<Record<string, unknown>>;

const eventHandlers: Record<string, EventHandler> = {
  "payment.succeeded": async (event) => {
    console.log(`Processing payment.succeeded: ${event.id}`);
    return { action: "payment_confirmed", amount: event.data.amount };
  },
  "payment.failed": async (event) => {
    console.log(`Processing payment.failed: ${event.id}`);
    return { action: "payment_failed", reason: event.data.failure_reason };
  },
  "subscription.updated": async (event) => {
    console.log(`Processing subscription.updated: ${event.id}`);
    return { action: "subscription_updated" };
  },
};

async function processEvent(
  event: WebhookEvent,
): Promise<Record<string, unknown>> {
  const handler = eventHandlers[event.type];
  if (!handler) {
    console.warn(`Unknown event type: ${event.type}`);
    return { action: "ignored", reason: "unknown_event_type" };
  }
  return handler(event);
}

// --- Main Webhook Endpoint ---

app.post(
  "/webhooks/stripe",
  async (req: Request, res: Response, next: NextFunction) => {
    const correlationId = uuidv4();
    console.log(`Webhook received: ${correlationId}`);

    try {
      const body = req.body as Buffer;
      const signature = req.headers["stripe-signature"] as string;
      const timestamp = req.headers["stripe-timestamp"] as string;

      // Verify signature
      verifySignature(body, signature, timestamp, WEBHOOK_SECRET);

      // Parse event
      const event: WebhookEvent = JSON.parse(body.toString("utf-8"));

      // Check idempotency
      if (await idempotency.isDuplicate(event.id)) {
        console.log(`Duplicate event: ${event.id}`);
        return res.status(200).json({
          eventId: event.id,
          status: "duplicate",
          message: "Event already processed",
        } as ProcessingResult);
      }

      // Process asynchronously
      setImmediate(async () => {
        try {
          const result = await processEvent(event);
          await idempotency.markProcessed(event.id, result);
          console.log(`Webhook processed: ${event.id}, type: ${event.type}`);
        } catch (error) {
          console.error(`Webhook processing error: ${event.id}`, error);
          await retryQueue.enqueueRetry(event, 0);
        }
      });

      // Return immediately
      res.status(202).json({
        eventId: event.id,
        status: "accepted",
        message: "Event queued for processing",
      } as ProcessingResult);
    } catch (error) {
      if (error instanceof WebhookError) {
        return res.status(error.statusCode).json({ error: error.message });
      }
      next(error);
    }
  },
);

// Health check
app.get("/webhooks/health", async (req: Request, res: Response) => {
  const redisStatus = await redis.ping();
  res.json({
    status: "healthy",
    redis: redisStatus === "PONG",
    timestamp: new Date().toISOString(),
  });
});

// Error handler
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  console.error("Unhandled error:", err);
  res.status(500).json({ error: "Internal server error" });
});

export default app;
```

---

## Security Best Practices

### 1. Signature Verification (CRITICAL)

| Provider | Algorithm   | Header Name             | Documentation                                                               |
| -------- | ----------- | ----------------------- | --------------------------------------------------------------------------- |
| Stripe   | HMAC-SHA256 | `Stripe-Signature`      | [Stripe Docs](https://stripe.com/docs/webhooks/signatures)                  |
| GitHub   | HMAC-SHA256 | `X-Hub-Signature-256`   | [GitHub Docs](https://docs.github.com/en/webhooks)                          |
| Twilio   | HMAC-SHA1   | `X-Twilio-Signature`    | [Twilio Docs](https://www.twilio.com/docs/usage/webhooks/webhooks-security) |
| Shopify  | HMAC-SHA256 | `X-Shopify-Hmac-Sha256` | [Shopify Docs](https://shopify.dev/docs/apps/webhooks)                      |
| Svix     | Ed25519     | `Svix-Signature`        | [Svix Docs](https://docs.svix.com/receiving/verifying-payloads)             |

### 2. Security Checklist

- [ ] **Never log raw payloads** - May contain PII/secrets
- [ ] **Use constant-time comparison** - Prevent timing attacks
- [ ] **Validate timestamps** - Prevent replay attacks (5 min tolerance)
- [ ] **Store secrets in env vars** - Never hardcode
- [ ] **Use HTTPS only** - No plain HTTP endpoints
- [ ] **Implement rate limiting** - Prevent DoS
- [ ] **Rotate secrets periodically** - Every 90 days minimum
- [ ] **Monitor for anomalies** - Unusual event volume/patterns

### 3. Secret Management

```python
# Correct: Environment variable
WEBHOOK_SECRET = os.environ["WEBHOOK_SECRET"]

# Correct: Secret manager
from google.cloud import secretmanager
client = secretmanager.SecretManagerServiceClient()
WEBHOOK_SECRET = client.access_secret_version(name="projects/xxx/secrets/webhook-secret/versions/latest").payload.data.decode()

# WRONG: Hardcoded (NEVER DO THIS)
# WEBHOOK_SECRET = "whsec_abc123..."  # SECURITY VIOLATION
```

### 4. IP Allowlisting (Optional)

```python
ALLOWED_IPS = {
    "stripe": ["3.18.12.63", "3.130.192.231", ...],  # Get from provider docs
    "github": ["192.30.252.0/22", "185.199.108.0/22", ...]
}

def verify_source_ip(request: Request, provider: str) -> bool:
    client_ip = request.client.host
    return any(ipaddress.ip_address(client_ip) in ipaddress.ip_network(cidr)
               for cidr in ALLOWED_IPS.get(provider, []))
```

---

## Testing Tools

### Signature Generation Utility

```python
"""Generate valid webhook signatures for testing."""
import hashlib
import hmac
import time
import json


def generate_test_signature(
    payload: dict,
    secret: str,
    timestamp: int = None
) -> tuple[str, str]:
    """
    Generate a valid webhook signature for testing.

    Returns:
        Tuple of (signature, timestamp)
    """
    timestamp = timestamp or int(time.time())
    payload_str = json.dumps(payload, separators=(',', ':'))
    signed_payload = f"{timestamp}.{payload_str}"

    signature = hmac.new(
        secret.encode('utf-8'),
        signed_payload.encode('utf-8'),
        hashlib.sha256
    ).hexdigest()

    return signature, str(timestamp)


# Usage in tests
def test_webhook_endpoint():
    payload = {
        "id": "evt_test_123",
        "type": "payment.succeeded",
        "created": int(time.time()),
        "data": {"amount": 1000}
    }

    signature, timestamp = generate_test_signature(payload, "test_secret")

    response = client.post(
        "/webhooks/stripe",
        json=payload,
        headers={
            "Stripe-Signature": signature,
            "Stripe-Timestamp": timestamp
        }
    )

    assert response.status_code == 202
```

### Mock Webhook Server

```python
"""Local webhook testing server."""
from fastapi import FastAPI
from fastapi.testclient import TestClient
import pytest

@pytest.fixture
def webhook_client():
    """Create test client with mocked Redis."""
    from unittest.mock import MagicMock

    # Mock Redis
    mock_redis = MagicMock()
    mock_redis.exists.return_value = 0
    mock_redis.ping.return_value = True

    # Inject mock
    import webhook_handler
    webhook_handler.redis_client = mock_redis
    webhook_handler.idempotency.redis = mock_redis
    webhook_handler.retry_queue.redis = mock_redis

    return TestClient(webhook_handler.app)


def test_valid_webhook(webhook_client):
    """Test processing a valid webhook."""
    payload = {"id": "evt_1", "type": "payment.succeeded", "created": 123, "data": {}}
    sig, ts = generate_test_signature(payload, WEBHOOK_SECRET)

    response = webhook_client.post(
        "/webhooks/stripe",
        content=json.dumps(payload),
        headers={"Stripe-Signature": sig, "Stripe-Timestamp": ts}
    )

    assert response.status_code == 202
    assert response.json()["status"] == "accepted"


def test_invalid_signature(webhook_client):
    """Test rejection of invalid signature."""
    payload = {"id": "evt_1", "type": "payment.succeeded", "created": 123, "data": {}}

    response = webhook_client.post(
        "/webhooks/stripe",
        content=json.dumps(payload),
        headers={"Stripe-Signature": "invalid", "Stripe-Timestamp": str(int(time.time()))}
    )

    assert response.status_code == 401


def test_expired_timestamp(webhook_client):
    """Test rejection of expired timestamp."""
    payload = {"id": "evt_1", "type": "payment.succeeded", "created": 123, "data": {}}
    old_timestamp = str(int(time.time()) - 600)  # 10 minutes ago
    sig, _ = generate_test_signature(payload, WEBHOOK_SECRET, int(old_timestamp))

    response = webhook_client.post(
        "/webhooks/stripe",
        content=json.dumps(payload),
        headers={"Stripe-Signature": sig, "Stripe-Timestamp": old_timestamp}
    )

    assert response.status_code == 400


def test_idempotency(webhook_client):
    """Test duplicate event handling."""
    # First request
    payload = {"id": "evt_dup", "type": "payment.succeeded", "created": 123, "data": {}}
    sig, ts = generate_test_signature(payload, WEBHOOK_SECRET)

    webhook_client.post(
        "/webhooks/stripe",
        content=json.dumps(payload),
        headers={"Stripe-Signature": sig, "Stripe-Timestamp": ts}
    )

    # Mock duplicate check
    webhook_client.app.state.idempotency.is_duplicate = lambda x: True

    # Second request (duplicate)
    response = webhook_client.post(
        "/webhooks/stripe",
        content=json.dumps(payload),
        headers={"Stripe-Signature": sig, "Stripe-Timestamp": ts}
    )

    assert response.status_code == 200
    assert response.json()["status"] == "duplicate"
```

### Load Testing Script

```bash
#!/bin/bash
# webhook-load-test.sh - Webhook endpoint load testing

ENDPOINT="${1:-http://localhost:8000/webhooks/stripe}"
CONCURRENCY="${2:-10}"
REQUESTS="${3:-1000}"
SECRET="${WEBHOOK_SECRET:-test_secret}"

echo "Load testing: $ENDPOINT"
echo "Concurrency: $CONCURRENCY, Requests: $REQUESTS"

# Generate test payload
generate_payload() {
    local id="evt_$(date +%s%N)"
    echo "{\"id\":\"$id\",\"type\":\"payment.succeeded\",\"created\":$(date +%s),\"data\":{\"amount\":1000}}"
}

# Generate signature
generate_signature() {
    local payload="$1"
    local timestamp="$2"
    echo -n "${timestamp}.${payload}" | openssl dgst -sha256 -hmac "$SECRET" | cut -d' ' -f2
}

# Single request
send_request() {
    local payload=$(generate_payload)
    local timestamp=$(date +%s)
    local signature=$(generate_signature "$payload" "$timestamp")

    curl -s -o /dev/null -w "%{http_code}" \
        -X POST "$ENDPOINT" \
        -H "Content-Type: application/json" \
        -H "Stripe-Signature: $signature" \
        -H "Stripe-Timestamp: $timestamp" \
        -d "$payload"
}

# Run load test with parallel
export -f send_request generate_payload generate_signature
export ENDPOINT SECRET

seq $REQUESTS | xargs -P $CONCURRENCY -I {} bash -c 'send_request' | sort | uniq -c

echo "Load test complete"
```

---

## Integration with API Architect

This agent integrates with `/agents/backend/api-architect` for:

1. **OpenAPI Specification**: Generate webhook endpoint specs
2. **Request/Response Schemas**: Define event payload structures
3. **Error Code Definitions**: Document webhook-specific errors
4. **Authentication Documentation**: Document signature verification

### Example Integration

```
# Step 1: Design webhook API with api-architect
/agents/backend/api-architect design webhook API for payment events

# Step 2: Implement with webhook-expert
/agents/integration/webhook-expert implement Stripe webhook handler based on spec

# Step 3: Security review
/agents/security/security-auditor review webhook implementation

# Step 4: Integration tests
/agents/testing/integration-tester create webhook test suite
```

---

## Provider-Specific Configurations

### Stripe

```python
# Stripe uses v1 signature format
# Header: Stripe-Signature: t=timestamp,v1=signature

def parse_stripe_signature(header: str) -> tuple[str, str]:
    """Parse Stripe signature header format."""
    parts = dict(item.split('=') for item in header.split(','))
    return parts['v1'], parts['t']
```

### GitHub

```python
# GitHub uses X-Hub-Signature-256 with sha256= prefix
def verify_github_signature(payload: bytes, signature_header: str, secret: str) -> bool:
    expected = 'sha256=' + hmac.new(
        secret.encode(),
        payload,
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(expected, signature_header)
```

### Twilio

```python
# Twilio validates URL + POST params + auth token
from twilio.request_validator import RequestValidator

def verify_twilio_signature(url: str, params: dict, signature: str, token: str) -> bool:
    validator = RequestValidator(token)
    return validator.validate(url, params, signature)
```

---

## Monitoring and Observability

### Key Metrics

| Metric                                | Description             | Alert Threshold |
| ------------------------------------- | ----------------------- | --------------- |
| `webhook_received_total`              | Total webhooks received | -               |
| `webhook_processed_total`             | Successfully processed  | -               |
| `webhook_duplicate_total`             | Duplicate events        | > 10%           |
| `webhook_failed_total`                | Failed processing       | > 5%            |
| `webhook_retry_queue_size`            | Pending retries         | > 100           |
| `webhook_dlq_size`                    | Dead letter queue       | > 0             |
| `webhook_processing_duration_seconds` | Processing latency      | P99 > 5s        |
| `webhook_signature_failures_total`    | Invalid signatures      | > 1/min         |

### Structured Logging

```python
# Log format for webhook events
logger.info(
    "webhook_event",
    event_id=event.id,
    event_type=event.type,
    correlation_id=correlation_id,
    source_ip=request.client.host,
    processing_time_ms=processing_time,
    status="processed"
)
```

---

## Example Usage

```bash
# Implement Stripe webhook handler
/agents/integration/webhook-expert implement Stripe payment webhook with idempotency

# Add GitHub webhook support
/agents/integration/webhook-expert add GitHub webhook handler for push events

# Create webhook testing infrastructure
/agents/integration/webhook-expert create webhook test suite for Stripe and GitHub

# Review existing webhook implementation
/agents/integration/webhook-expert review and improve existing webhook handler at src/webhooks/
```

---

## Deliverables

When invoked, this agent produces:

1. **Webhook Endpoint Implementation** - Complete handler code
2. **Signature Verification Module** - Provider-specific verification
3. **Idempotency Handler** - Event deduplication logic
4. **Retry Queue System** - Exponential backoff with DLQ
5. **Test Suite** - Unit, integration, and load tests
6. **OpenAPI Specification** - Webhook endpoint documentation
7. **Monitoring Dashboard** - Grafana/DataDog configuration

---

## References

- [Stripe Webhook Best Practices](https://stripe.com/docs/webhooks/best-practices)
- [GitHub Webhook Security](https://docs.github.com/en/webhooks/using-webhooks/best-practices-for-using-webhooks)
- [Svix Webhook Guide](https://docs.svix.com/receiving/introduction)
- [OWASP API Security](https://owasp.org/API-Security/)

---

Ahmed Adel Bakr Alderai
