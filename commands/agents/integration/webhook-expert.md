---
name: Webhook Implementation Expert Agent
description: Implements production-grade webhook systems with signature verification, idempotency, retry logic, event queuing, rate limiting, and comprehensive security
version: 2.0.0
author: Ahmed Adel Bakr Alderai
category: integration
tags:
  - webhooks
  - event-driven
  - integrations
  - api
  - security
  - idempotency
  - retry-logic
  - rate-limiting
tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - Task
dependencies:
  - /agents/integration/api-integration-expert
  - /agents/security/security-expert
  - /agents/database/redis-expert
  - /agents/testing/integration-test-expert
  - /agents/devops/monitoring-expert
inputs:
  - name: task
    type: string
    required: true
    description: The webhook implementation task
  - name: provider
    type: string
    required: false
    description: "Webhook provider (stripe, github, slack, twilio, shopify, custom)"
  - name: framework
    type: string
    required: false
    default: fastapi
    description: "Target framework (express, fastapi, flask, django, nestjs)"
  - name: queue_backend
    type: string
    required: false
    default: redis
    description: "Queue backend (redis, rabbitmq, sqs, kafka)"
outputs:
  - webhook_endpoint
  - signature_verification
  - idempotency_handler
  - retry_queue
  - rate_limiter
  - dead_letter_queue
  - test_suite
  - monitoring_config
---

# Webhook Implementation Expert Agent

Expert in designing and implementing production-grade webhook systems with comprehensive security, reliability, idempotency, rate limiting, and observability features.

## Arguments

- `$ARGUMENTS` - Webhook implementation task (e.g., "implement Stripe webhook handler with rate limiting")

## Invoke Agent

```
Use the Task tool with subagent_type="webhook-expert" to:

1. Design webhook endpoint architecture
2. Implement signature verification (HMAC-SHA256, Ed25519, RSA)
3. Add idempotency handling with event deduplication
4. Configure retry logic with exponential backoff and DLQ
5. Set up event queuing for async processing
6. Implement rate limiting for incoming webhooks
7. Create comprehensive test suite
8. Configure monitoring and alerting

Task: $ARGUMENTS
```

---

## Table of Contents

1. [Webhook Endpoint Design Patterns](#1-webhook-endpoint-design-patterns)
2. [Signature Verification](#2-signature-verification)
3. [Idempotency Handling](#3-idempotency-handling)
4. [Retry Logic and Dead Letter Queues](#4-retry-logic-and-dead-letter-queues)
5. [Event Queuing and Processing](#5-event-queuing-and-processing)
6. [Rate Limiting for Incoming Webhooks](#6-rate-limiting-for-incoming-webhooks)
7. [Security Best Practices](#7-security-best-practices)
8. [Testing Webhook Integrations](#8-testing-webhook-integrations)
9. [Monitoring and Alerting](#9-monitoring-and-alerting)
10. [Popular Webhook Integrations](#10-popular-webhook-integrations)

---

## 1. Webhook Endpoint Design Patterns

### Core Design Principles

| Principle                 | Description                       | Implementation                                  |
| ------------------------- | --------------------------------- | ----------------------------------------------- |
| **Single Responsibility** | One endpoint per event category   | `/webhooks/payments`, `/webhooks/subscriptions` |
| **Immediate Response**    | Return 200/202 within 5 seconds   | Process asynchronously via queue                |
| **Idempotent Processing** | Same event = same result          | Track event IDs with TTL                        |
| **Graceful Degradation**  | Handle failures without data loss | Retry queue + DLQ                               |
| **Observable**            | Full visibility into processing   | Structured logging + metrics                    |

### Endpoint Architecture

```
                                    +-----------------+
                                    |   Rate Limiter  |
                                    +--------+--------+
                                             |
+----------+    +-----------+    +----------v----------+    +-------------+
| Provider | -> | Signature | -> | Idempotency Check   | -> | Event Queue |
| Webhook  |    | Verify    |    | (Redis/DB)          |    | (Redis/SQS) |
+----------+    +-----------+    +---------------------+    +------+------+
                                                                   |
                     +----------------------+----------------------+
                     |                      |                      |
              +------v------+        +------v------+        +------v------+
              | Handler A   |        | Handler B   |        | Handler C   |
              | (payment)   |        | (refund)    |        | (dispute)   |
              +------+------+        +------+------+        +------+------+
                     |                      |                      |
                     +----------------------+----------------------+
                                           |
                                    +------v------+
                                    | Dead Letter |
                                    | Queue (DLQ) |
                                    +-------------+
```

### FastAPI Implementation Pattern

```python
"""
Webhook Handler Architecture - FastAPI Implementation
Production-grade webhook processing with all security features.
"""
import os
import hashlib
import hmac
import json
import time
import asyncio
from datetime import datetime, timedelta
from typing import Optional, Callable, Dict, Any
from uuid import uuid4
from functools import wraps
from enum import Enum

from fastapi import FastAPI, Request, HTTPException, Header, BackgroundTasks, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from redis.asyncio import Redis
import structlog

# ============================================================================
# CONFIGURATION
# ============================================================================

class Config:
    """Webhook configuration - loaded from environment."""
    WEBHOOK_SECRET: str = os.environ.get("WEBHOOK_SECRET", "")
    SIGNATURE_TOLERANCE_SECONDS: int = 300  # 5 minute tolerance
    IDEMPOTENCY_TTL_SECONDS: int = 86400  # 24 hours
    MAX_RETRIES: int = 5
    RETRY_BACKOFF_BASE: int = 2
    RATE_LIMIT_REQUESTS: int = 100  # per window
    RATE_LIMIT_WINDOW_SECONDS: int = 60
    REDIS_URL: str = os.environ.get("REDIS_URL", "redis://localhost:6379")

    @classmethod
    def validate(cls) -> None:
        """Validate required configuration."""
        if not cls.WEBHOOK_SECRET:
            raise ValueError("WEBHOOK_SECRET environment variable required")


# ============================================================================
# MODELS
# ============================================================================

class WebhookEventType(str, Enum):
    """Supported webhook event types."""
    PAYMENT_SUCCEEDED = "payment.succeeded"
    PAYMENT_FAILED = "payment.failed"
    PAYMENT_REFUNDED = "payment.refunded"
    SUBSCRIPTION_CREATED = "subscription.created"
    SUBSCRIPTION_UPDATED = "subscription.updated"
    SUBSCRIPTION_CANCELLED = "subscription.cancelled"
    INVOICE_PAID = "invoice.paid"
    INVOICE_FAILED = "invoice.failed"
    DISPUTE_CREATED = "dispute.created"
    DISPUTE_RESOLVED = "dispute.resolved"


class WebhookEvent(BaseModel):
    """Webhook event payload structure."""
    id: str = Field(..., description="Unique event identifier")
    type: str = Field(..., description="Event type")
    created: int = Field(..., description="Unix timestamp of event creation")
    data: Dict[str, Any] = Field(default_factory=dict, description="Event payload data")
    api_version: Optional[str] = Field(None, description="API version")
    livemode: bool = Field(True, description="Live or test mode")


class ProcessingResult(BaseModel):
    """Result of webhook processing."""
    event_id: str
    status: str  # "accepted", "processed", "duplicate", "failed", "rate_limited"
    message: Optional[str] = None
    correlation_id: Optional[str] = None


class WebhookMetrics(BaseModel):
    """Metrics for webhook processing."""
    total_received: int = 0
    total_processed: int = 0
    total_duplicates: int = 0
    total_failed: int = 0
    total_rate_limited: int = 0
    avg_processing_time_ms: float = 0.0


# ============================================================================
# LOGGING SETUP
# ============================================================================

logger = structlog.get_logger()

def configure_logging():
    """Configure structured logging."""
    structlog.configure(
        processors=[
            structlog.stdlib.filter_by_level,
            structlog.stdlib.add_logger_name,
            structlog.stdlib.add_log_level,
            structlog.stdlib.PositionalArgumentsFormatter(),
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.UnicodeDecoder(),
            structlog.processors.JSONRenderer()
        ],
        wrapper_class=structlog.stdlib.BoundLogger,
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )


# ============================================================================
# APPLICATION SETUP
# ============================================================================

app = FastAPI(
    title="Webhook Handler API",
    description="Production-grade webhook processing system",
    version="2.0.0"
)

# Redis connection pool
redis_pool: Optional[Redis] = None


async def get_redis() -> Redis:
    """Get Redis connection from pool."""
    global redis_pool
    if redis_pool is None:
        redis_pool = Redis.from_url(Config.REDIS_URL, decode_responses=True)
    return redis_pool


@app.on_event("startup")
async def startup():
    """Application startup tasks."""
    Config.validate()
    configure_logging()
    await get_redis()
    logger.info("webhook_handler_started")


@app.on_event("shutdown")
async def shutdown():
    """Application shutdown tasks."""
    global redis_pool
    if redis_pool:
        await redis_pool.close()
    logger.info("webhook_handler_stopped")
```

---

## 2. Signature Verification

### HMAC-SHA256 Verification (Stripe, GitHub, Shopify)

```python
# ============================================================================
# SIGNATURE VERIFICATION
# ============================================================================

class SignatureVerificationError(Exception):
    """Raised when signature verification fails."""
    def __init__(self, message: str, status_code: int = 401):
        self.message = message
        self.status_code = status_code
        super().__init__(self.message)


class SignatureVerifier:
    """
    Cryptographic signature verification for webhooks.

    Supports multiple algorithms:
    - HMAC-SHA256 (Stripe, GitHub, Shopify)
    - HMAC-SHA1 (Twilio, legacy)
    - Ed25519 (Svix, modern providers)
    """

    def __init__(self, secret: str, tolerance_seconds: int = 300):
        self.secret = secret
        self.tolerance_seconds = tolerance_seconds

    def verify_hmac_sha256(
        self,
        payload: bytes,
        signature: str,
        timestamp: Optional[str] = None,
        signed_payload_format: str = "{timestamp}.{payload}"
    ) -> bool:
        """
        Verify HMAC-SHA256 signature.

        Args:
            payload: Raw request body bytes
            signature: Signature from header
            timestamp: Optional timestamp for replay protection
            signed_payload_format: Format string for signed payload

        Returns:
            True if signature is valid

        Raises:
            SignatureVerificationError: If verification fails
        """
        # Validate timestamp if provided
        if timestamp:
            self._validate_timestamp(timestamp)
            signed_payload = signed_payload_format.format(
                timestamp=timestamp,
                payload=payload.decode("utf-8")
            )
        else:
            signed_payload = payload.decode("utf-8")

        # Compute expected signature
        expected = hmac.new(
            self.secret.encode("utf-8"),
            signed_payload.encode("utf-8"),
            hashlib.sha256
        ).hexdigest()

        # Constant-time comparison (prevents timing attacks)
        if not hmac.compare_digest(expected, signature):
            logger.warning(
                "signature_verification_failed",
                expected_prefix=expected[:16],
                received_prefix=signature[:16] if signature else "empty"
            )
            raise SignatureVerificationError("Invalid signature")

        return True

    def verify_hmac_sha1(self, payload: bytes, signature: str) -> bool:
        """Verify HMAC-SHA1 signature (legacy, Twilio)."""
        expected = hmac.new(
            self.secret.encode("utf-8"),
            payload,
            hashlib.sha1
        ).hexdigest()

        if not hmac.compare_digest(f"sha1={expected}", signature):
            raise SignatureVerificationError("Invalid SHA1 signature")

        return True

    def _validate_timestamp(self, timestamp_str: str) -> int:
        """
        Validate timestamp is within tolerance window.

        Prevents replay attacks by rejecting old webhooks.
        """
        try:
            timestamp = int(timestamp_str)
        except (ValueError, TypeError):
            raise SignatureVerificationError("Invalid timestamp format", 400)

        current_time = int(time.time())
        age = abs(current_time - timestamp)

        if age > self.tolerance_seconds:
            logger.warning(
                "timestamp_expired",
                timestamp=timestamp,
                current_time=current_time,
                age_seconds=age,
                tolerance=self.tolerance_seconds
            )
            raise SignatureVerificationError(
                f"Timestamp expired (age: {age}s, tolerance: {self.tolerance_seconds}s)",
                400
            )

        return timestamp


# Provider-specific signature parsers
class StripeSignatureParser:
    """Parse Stripe's composite signature header."""

    @staticmethod
    def parse(header: str) -> tuple[str, str]:
        """
        Parse Stripe-Signature header.

        Format: t=timestamp,v1=signature

        Returns:
            Tuple of (signature, timestamp)
        """
        parts = dict(item.split("=", 1) for item in header.split(","))
        return parts.get("v1", ""), parts.get("t", "")


class GitHubSignatureParser:
    """Parse GitHub's signature header."""

    @staticmethod
    def parse(header: str) -> str:
        """
        Parse X-Hub-Signature-256 header.

        Format: sha256=signature

        Returns:
            Signature hex string
        """
        if header.startswith("sha256="):
            return header[7:]
        return header
```

### Ed25519 Verification (Modern Providers)

```python
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
from cryptography.exceptions import InvalidSignature
import base64


class Ed25519Verifier:
    """Ed25519 signature verification for modern webhook providers like Svix."""

    def __init__(self, public_key_base64: str):
        """
        Initialize with base64-encoded public key.

        Args:
            public_key_base64: Base64-encoded Ed25519 public key
        """
        key_bytes = base64.b64decode(public_key_base64)
        self.public_key = Ed25519PublicKey.from_public_bytes(key_bytes)

    def verify(
        self,
        payload: bytes,
        signature_base64: str,
        message_id: str,
        timestamp: str
    ) -> bool:
        """
        Verify Ed25519 signature.

        Args:
            payload: Raw request body
            signature_base64: Base64-encoded signature
            message_id: Unique message identifier
            timestamp: Unix timestamp string

        Returns:
            True if valid

        Raises:
            SignatureVerificationError: If verification fails
        """
        # Construct signed content (Svix format)
        signed_content = f"{message_id}.{timestamp}.{payload.decode('utf-8')}"
        signature = base64.b64decode(signature_base64)

        try:
            self.public_key.verify(signature, signed_content.encode("utf-8"))
            return True
        except InvalidSignature:
            raise SignatureVerificationError("Invalid Ed25519 signature")
```

---

## 3. Idempotency Handling

### Redis-Based Idempotency Handler

```python
# ============================================================================
# IDEMPOTENCY HANDLING
# ============================================================================

class IdempotencyHandler:
    """
    Handles event deduplication using Redis.

    Prevents duplicate processing of webhook events by tracking
    event IDs with configurable TTL.

    Features:
    - Atomic check-and-set operations
    - TTL-based automatic cleanup
    - Previous result retrieval
    - Concurrent request handling
    """

    def __init__(
        self,
        redis: Redis,
        ttl_seconds: int = 86400,
        key_prefix: str = "webhook:idempotency:"
    ):
        self.redis = redis
        self.ttl = ttl_seconds
        self.key_prefix = key_prefix

    async def check_and_set(self, event_id: str) -> tuple[bool, Optional[dict]]:
        """
        Atomically check if event was processed and set if not.

        Uses Redis SET with NX (not exists) for atomic operation.

        Args:
            event_id: Unique event identifier

        Returns:
            Tuple of (is_new, previous_result)
            - is_new: True if this is a new event
            - previous_result: Previous processing result if duplicate
        """
        key = f"{self.key_prefix}{event_id}"

        # Try to set a placeholder atomically
        was_set = await self.redis.set(
            key,
            json.dumps({"status": "processing", "started_at": datetime.utcnow().isoformat()}),
            ex=self.ttl,
            nx=True  # Only set if not exists
        )

        if was_set:
            return True, None

        # Event exists, get previous result
        previous = await self.get_previous_result(event_id)
        return False, previous

    async def is_duplicate(self, event_id: str) -> bool:
        """Check if event was already processed."""
        key = f"{self.key_prefix}{event_id}"
        return await self.redis.exists(key) > 0

    async def mark_processed(
        self,
        event_id: str,
        result: dict,
        extend_ttl: bool = True
    ) -> None:
        """
        Mark event as successfully processed.

        Args:
            event_id: Event identifier
            result: Processing result to store
            extend_ttl: Whether to extend TTL from now
        """
        key = f"{self.key_prefix}{event_id}"
        data = {
            "status": "processed",
            "processed_at": datetime.utcnow().isoformat(),
            "result": result
        }

        if extend_ttl:
            await self.redis.setex(key, self.ttl, json.dumps(data))
        else:
            await self.redis.set(key, json.dumps(data), keepttl=True)

        logger.info("event_marked_processed", event_id=event_id)

    async def mark_failed(
        self,
        event_id: str,
        error: str,
        attempt: int
    ) -> None:
        """Mark event as failed (for retry tracking)."""
        key = f"{self.key_prefix}{event_id}"
        data = {
            "status": "failed",
            "failed_at": datetime.utcnow().isoformat(),
            "error": error,
            "attempt": attempt
        }
        await self.redis.setex(key, self.ttl, json.dumps(data))

    async def get_previous_result(self, event_id: str) -> Optional[dict]:
        """Get result of previously processed event."""
        key = f"{self.key_prefix}{event_id}"
        data = await self.redis.get(key)
        if data:
            return json.loads(data)
        return None

    async def get_processing_stats(self) -> dict:
        """Get idempotency processing statistics."""
        # Use SCAN to count keys (production: use separate counter)
        cursor = 0
        count = 0
        while True:
            cursor, keys = await self.redis.scan(
                cursor,
                match=f"{self.key_prefix}*",
                count=1000
            )
            count += len(keys)
            if cursor == 0:
                break

        return {
            "tracked_events": count,
            "ttl_seconds": self.ttl
        }
```

### Database-Based Idempotency (PostgreSQL)

```python
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import Column, String, DateTime, JSON, select, func
from sqlalchemy.dialects.postgresql import insert


class WebhookEventRecord(Base):
    """SQLAlchemy model for webhook event tracking."""
    __tablename__ = "webhook_events"

    event_id = Column(String(255), primary_key=True)
    event_type = Column(String(100), nullable=False)
    status = Column(String(50), default="processing")
    payload_hash = Column(String(64))  # SHA256 of payload
    result = Column(JSON)
    received_at = Column(DateTime, default=func.now())
    processed_at = Column(DateTime)
    error_message = Column(String(1000))
    retry_count = Column(Integer, default=0)


class DatabaseIdempotencyHandler:
    """Database-backed idempotency for stronger durability guarantees."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def check_and_set(
        self,
        event_id: str,
        event_type: str,
        payload: bytes
    ) -> tuple[bool, Optional[dict]]:
        """
        Atomic check-and-insert using PostgreSQL upsert.

        Uses INSERT ... ON CONFLICT for atomic operation.
        """
        payload_hash = hashlib.sha256(payload).hexdigest()

        stmt = insert(WebhookEventRecord).values(
            event_id=event_id,
            event_type=event_type,
            payload_hash=payload_hash,
            status="processing"
        ).on_conflict_do_nothing(index_elements=["event_id"])

        result = await self.session.execute(stmt)
        await self.session.commit()

        if result.rowcount > 0:
            return True, None

        # Fetch existing record
        existing = await self.session.execute(
            select(WebhookEventRecord).where(
                WebhookEventRecord.event_id == event_id
            )
        )
        record = existing.scalar_one_or_none()

        if record:
            return False, {
                "status": record.status,
                "processed_at": record.processed_at.isoformat() if record.processed_at else None,
                "result": record.result
            }

        return False, None
```

---

## 4. Retry Logic and Dead Letter Queues

### Comprehensive Retry System

```python
# ============================================================================
# RETRY LOGIC AND DEAD LETTER QUEUE
# ============================================================================

class RetryStrategy(str, Enum):
    """Available retry strategies."""
    EXPONENTIAL_BACKOFF = "exponential"
    LINEAR_BACKOFF = "linear"
    FIBONACCI_BACKOFF = "fibonacci"


class RetryQueue:
    """
    Manages webhook retry logic with configurable backoff strategies.

    Features:
    - Exponential, linear, and Fibonacci backoff
    - Maximum retry limits
    - Dead letter queue for failed events
    - Priority queue support
    - Batch retrieval for workers
    """

    def __init__(
        self,
        redis: Redis,
        max_retries: int = 5,
        backoff_base: int = 2,
        max_backoff_seconds: int = 3600,
        strategy: RetryStrategy = RetryStrategy.EXPONENTIAL_BACKOFF
    ):
        self.redis = redis
        self.max_retries = max_retries
        self.backoff_base = backoff_base
        self.max_backoff = max_backoff_seconds
        self.strategy = strategy

        # Queue keys
        self.retry_queue_key = "webhook:retry:queue"
        self.dlq_key = "webhook:dlq"
        self.metrics_key = "webhook:retry:metrics"

    def _calculate_delay(self, attempt: int) -> int:
        """Calculate delay based on strategy."""
        if self.strategy == RetryStrategy.EXPONENTIAL_BACKOFF:
            delay = self.backoff_base ** attempt
        elif self.strategy == RetryStrategy.LINEAR_BACKOFF:
            delay = self.backoff_base * attempt
        elif self.strategy == RetryStrategy.FIBONACCI_BACKOFF:
            delay = self._fibonacci(attempt + 2)
        else:
            delay = self.backoff_base ** attempt

        # Add jitter (10% randomization)
        import random
        jitter = delay * 0.1 * random.random()

        return min(int(delay + jitter), self.max_backoff)

    def _fibonacci(self, n: int) -> int:
        """Calculate nth Fibonacci number."""
        if n <= 1:
            return n
        a, b = 0, 1
        for _ in range(2, n + 1):
            a, b = b, a + b
        return b

    async def enqueue_retry(
        self,
        event: dict,
        attempt: int,
        error: str,
        priority: int = 0
    ) -> bool:
        """
        Add event to retry queue with calculated delay.

        Args:
            event: Original webhook event
            attempt: Current attempt number (0-indexed)
            error: Error message from failed processing
            priority: Higher priority = processed sooner (0-10)

        Returns:
            True if enqueued, False if moved to DLQ
        """
        if attempt >= self.max_retries:
            await self._move_to_dlq(event, error, "max_retries_exceeded")
            return False

        delay = self._calculate_delay(attempt)
        execute_at = time.time() + delay

        # Priority affects score (higher priority = lower score = earlier processing)
        score = execute_at - (priority * 10)

        retry_item = {
            "event": event,
            "attempt": attempt + 1,
            "error": error,
            "enqueued_at": datetime.utcnow().isoformat(),
            "execute_at": datetime.utcfromtimestamp(execute_at).isoformat(),
            "priority": priority
        }

        await self.redis.zadd(
            self.retry_queue_key,
            {json.dumps(retry_item): score}
        )

        # Update metrics
        await self.redis.hincrby(self.metrics_key, "total_retries", 1)
        await self.redis.hincrby(self.metrics_key, f"attempt_{attempt + 1}", 1)

        logger.info(
            "webhook_retry_enqueued",
            event_id=event.get("id"),
            attempt=attempt + 1,
            delay_seconds=delay,
            priority=priority
        )

        return True

    async def get_ready_events(self, batch_size: int = 10) -> list[dict]:
        """
        Get events ready for retry processing.

        Uses ZPOPMIN for atomic retrieval.
        """
        now = time.time()

        # Get items with score <= now
        items = await self.redis.zrangebyscore(
            self.retry_queue_key,
            "-inf",
            now,
            start=0,
            num=batch_size,
            withscores=True
        )

        if not items:
            return []

        # Remove retrieved items atomically
        pipe = self.redis.pipeline()
        for item, _ in items:
            pipe.zrem(self.retry_queue_key, item)
        await pipe.execute()

        return [json.loads(item) for item, _ in items]

    async def _move_to_dlq(
        self,
        event: dict,
        error: str,
        reason: str
    ) -> None:
        """Move failed event to dead letter queue."""
        dlq_item = {
            "event": event,
            "error": error,
            "reason": reason,
            "moved_at": datetime.utcnow().isoformat(),
            "original_attempts": self.max_retries
        }

        await self.redis.lpush(self.dlq_key, json.dumps(dlq_item))
        await self.redis.hincrby(self.metrics_key, "total_dlq", 1)

        logger.error(
            "webhook_moved_to_dlq",
            event_id=event.get("id"),
            reason=reason,
            error=error
        )

    async def get_dlq_events(
        self,
        limit: int = 100,
        remove: bool = False
    ) -> list[dict]:
        """Get events from dead letter queue for manual review."""
        if remove:
            items = []
            for _ in range(limit):
                item = await self.redis.rpop(self.dlq_key)
                if item:
                    items.append(json.loads(item))
                else:
                    break
            return items
        else:
            items = await self.redis.lrange(self.dlq_key, 0, limit - 1)
            return [json.loads(item) for item in items]

    async def requeue_from_dlq(self, event_id: str) -> bool:
        """Manually requeue a DLQ event for retry."""
        items = await self.redis.lrange(self.dlq_key, 0, -1)

        for i, item_json in enumerate(items):
            item = json.loads(item_json)
            if item["event"].get("id") == event_id:
                await self.redis.lrem(self.dlq_key, 1, item_json)
                await self.enqueue_retry(item["event"], 0, "manual_requeue")
                return True

        return False

    async def get_queue_stats(self) -> dict:
        """Get retry queue statistics."""
        retry_count = await self.redis.zcard(self.retry_queue_key)
        dlq_count = await self.redis.llen(self.dlq_key)
        metrics = await self.redis.hgetall(self.metrics_key)

        return {
            "pending_retries": retry_count,
            "dlq_size": dlq_count,
            "total_retries": int(metrics.get("total_retries", 0)),
            "total_dlq": int(metrics.get("total_dlq", 0)),
            "by_attempt": {
                k: int(v) for k, v in metrics.items()
                if k.startswith("attempt_")
            }
        }


# Retry worker process
async def retry_worker(
    redis: Redis,
    retry_queue: RetryQueue,
    process_func: Callable,
    poll_interval: int = 5
):
    """
    Background worker that processes retry queue.

    Run this as a separate process or async task.
    """
    logger.info("retry_worker_started")

    while True:
        try:
            events = await retry_queue.get_ready_events(batch_size=10)

            for item in events:
                event = item["event"]
                attempt = item["attempt"]

                try:
                    await process_func(event)
                    logger.info(
                        "retry_succeeded",
                        event_id=event.get("id"),
                        attempt=attempt
                    )
                except Exception as e:
                    logger.error(
                        "retry_failed",
                        event_id=event.get("id"),
                        attempt=attempt,
                        error=str(e)
                    )
                    await retry_queue.enqueue_retry(event, attempt, str(e))

            if not events:
                await asyncio.sleep(poll_interval)

        except Exception as e:
            logger.error("retry_worker_error", error=str(e))
            await asyncio.sleep(poll_interval)
```

---

## 5. Event Queuing and Processing

### Redis Streams Implementation

```python
# ============================================================================
# EVENT QUEUING AND PROCESSING
# ============================================================================

class EventQueue:
    """
    High-performance event queue using Redis Streams.

    Features:
    - At-least-once delivery guarantee
    - Consumer groups for parallel processing
    - Automatic acknowledgment tracking
    - Dead letter handling for stale messages
    - Backpressure management
    """

    def __init__(
        self,
        redis: Redis,
        stream_name: str = "webhook:events",
        consumer_group: str = "webhook-processors",
        max_stream_length: int = 100000
    ):
        self.redis = redis
        self.stream_name = stream_name
        self.consumer_group = consumer_group
        self.max_length = max_stream_length

    async def initialize(self) -> None:
        """Create consumer group if not exists."""
        try:
            await self.redis.xgroup_create(
                self.stream_name,
                self.consumer_group,
                id="0",
                mkstream=True
            )
        except Exception as e:
            if "BUSYGROUP" not in str(e):
                raise

    async def enqueue(
        self,
        event: dict,
        priority: str = "normal"
    ) -> str:
        """
        Add event to the queue.

        Args:
            event: Webhook event to queue
            priority: Event priority (high, normal, low)

        Returns:
            Stream message ID
        """
        message = {
            "event": json.dumps(event),
            "priority": priority,
            "enqueued_at": datetime.utcnow().isoformat()
        }

        message_id = await self.redis.xadd(
            self.stream_name,
            message,
            maxlen=self.max_length,
            approximate=True
        )

        logger.debug(
            "event_enqueued",
            event_id=event.get("id"),
            message_id=message_id
        )

        return message_id

    async def dequeue(
        self,
        consumer_name: str,
        count: int = 1,
        block_ms: int = 5000
    ) -> list[tuple[str, dict]]:
        """
        Retrieve events for processing.

        Args:
            consumer_name: Unique consumer identifier
            count: Maximum events to retrieve
            block_ms: Milliseconds to block waiting for events

        Returns:
            List of (message_id, event) tuples
        """
        # First, try to claim any pending messages older than 60 seconds
        pending = await self.redis.xautoclaim(
            self.stream_name,
            self.consumer_group,
            consumer_name,
            min_idle_time=60000,
            start_id="0-0",
            count=count
        )

        if pending and pending[1]:
            return [
                (msg_id, json.loads(data["event"]))
                for msg_id, data in pending[1]
            ]

        # Read new messages
        messages = await self.redis.xreadgroup(
            self.consumer_group,
            consumer_name,
            {self.stream_name: ">"},
            count=count,
            block=block_ms
        )

        if not messages:
            return []

        result = []
        for stream_name, stream_messages in messages:
            for msg_id, data in stream_messages:
                result.append((msg_id, json.loads(data["event"])))

        return result

    async def acknowledge(self, message_id: str) -> None:
        """Acknowledge successful processing of a message."""
        await self.redis.xack(
            self.stream_name,
            self.consumer_group,
            message_id
        )

    async def get_pending_count(self) -> int:
        """Get count of unacknowledged messages."""
        info = await self.redis.xpending(
            self.stream_name,
            self.consumer_group
        )
        return info["pending"] if info else 0

    async def get_stream_stats(self) -> dict:
        """Get queue statistics."""
        length = await self.redis.xlen(self.stream_name)
        pending = await self.get_pending_count()

        info = await self.redis.xinfo_groups(self.stream_name)
        consumers = sum(g["consumers"] for g in info) if info else 0

        return {
            "stream_length": length,
            "pending_messages": pending,
            "consumer_groups": len(info) if info else 0,
            "total_consumers": consumers
        }


# Event processor with circuit breaker
class CircuitBreaker:
    """
    Circuit breaker pattern for event processing.

    States:
    - CLOSED: Normal operation
    - OPEN: Failing, reject all requests
    - HALF_OPEN: Testing if service recovered
    """

    def __init__(
        self,
        failure_threshold: int = 5,
        recovery_timeout: int = 60,
        half_open_requests: int = 3
    ):
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.half_open_requests = half_open_requests

        self.failures = 0
        self.state = "CLOSED"
        self.last_failure_time: Optional[float] = None
        self.half_open_successes = 0

    def can_execute(self) -> bool:
        """Check if execution is allowed."""
        if self.state == "CLOSED":
            return True

        if self.state == "OPEN":
            if time.time() - self.last_failure_time >= self.recovery_timeout:
                self.state = "HALF_OPEN"
                self.half_open_successes = 0
                return True
            return False

        if self.state == "HALF_OPEN":
            return self.half_open_successes < self.half_open_requests

        return False

    def record_success(self) -> None:
        """Record successful execution."""
        if self.state == "HALF_OPEN":
            self.half_open_successes += 1
            if self.half_open_successes >= self.half_open_requests:
                self.state = "CLOSED"
                self.failures = 0
        else:
            self.failures = 0

    def record_failure(self) -> None:
        """Record failed execution."""
        self.failures += 1
        self.last_failure_time = time.time()

        if self.failures >= self.failure_threshold:
            self.state = "OPEN"
            logger.warning(
                "circuit_breaker_opened",
                failures=self.failures
            )
        elif self.state == "HALF_OPEN":
            self.state = "OPEN"
```

### RabbitMQ Implementation

```python
import aio_pika
from aio_pika import ExchangeType


class RabbitMQEventQueue:
    """Event queue implementation using RabbitMQ."""

    def __init__(
        self,
        url: str = "amqp://guest:guest@localhost/",
        exchange_name: str = "webhooks",
        queue_name: str = "webhook-events",
        dlx_name: str = "webhooks-dlx"
    ):
        self.url = url
        self.exchange_name = exchange_name
        self.queue_name = queue_name
        self.dlx_name = dlx_name

        self.connection = None
        self.channel = None
        self.exchange = None
        self.queue = None

    async def connect(self) -> None:
        """Establish connection and declare topology."""
        self.connection = await aio_pika.connect_robust(self.url)
        self.channel = await self.connection.channel()

        # Set QoS for fair dispatch
        await self.channel.set_qos(prefetch_count=10)

        # Declare dead letter exchange
        dlx = await self.channel.declare_exchange(
            self.dlx_name,
            ExchangeType.DIRECT,
            durable=True
        )

        # Declare dead letter queue
        dlq = await self.channel.declare_queue(
            f"{self.queue_name}-dlq",
            durable=True
        )
        await dlq.bind(dlx, routing_key="dead-letter")

        # Declare main exchange
        self.exchange = await self.channel.declare_exchange(
            self.exchange_name,
            ExchangeType.TOPIC,
            durable=True
        )

        # Declare main queue with DLX
        self.queue = await self.channel.declare_queue(
            self.queue_name,
            durable=True,
            arguments={
                "x-dead-letter-exchange": self.dlx_name,
                "x-dead-letter-routing-key": "dead-letter"
            }
        )

        # Bind queue to exchange
        await self.queue.bind(self.exchange, routing_key="webhook.*")

    async def publish(
        self,
        event: dict,
        routing_key: str = "webhook.event"
    ) -> None:
        """Publish event to queue."""
        message = aio_pika.Message(
            body=json.dumps(event).encode(),
            content_type="application/json",
            delivery_mode=aio_pika.DeliveryMode.PERSISTENT
        )

        await self.exchange.publish(message, routing_key=routing_key)

    async def consume(
        self,
        handler: Callable[[dict], Awaitable[None]]
    ) -> None:
        """Start consuming events."""
        async with self.queue.iterator() as queue_iter:
            async for message in queue_iter:
                async with message.process():
                    try:
                        event = json.loads(message.body.decode())
                        await handler(event)
                    except Exception as e:
                        logger.error("consume_error", error=str(e))
                        # Message will be moved to DLQ on rejection
                        await message.reject(requeue=False)
```

---

## 6. Rate Limiting for Incoming Webhooks

### Token Bucket Rate Limiter

```python
# ============================================================================
# RATE LIMITING FOR INCOMING WEBHOOKS
# ============================================================================

class RateLimitExceeded(Exception):
    """Raised when rate limit is exceeded."""
    def __init__(self, retry_after: int):
        self.retry_after = retry_after
        super().__init__(f"Rate limit exceeded. Retry after {retry_after} seconds.")


class TokenBucketRateLimiter:
    """
    Token bucket rate limiter for webhook endpoints.

    Allows burst traffic while maintaining average rate limit.

    Features:
    - Per-source IP limiting
    - Per-provider limiting
    - Global rate limiting
    - Burst allowance
    - Lua script for atomic operations
    """

    # Lua script for atomic token bucket operation
    TOKEN_BUCKET_SCRIPT = """
    local key = KEYS[1]
    local capacity = tonumber(ARGV[1])
    local rate = tonumber(ARGV[2])
    local now = tonumber(ARGV[3])
    local requested = tonumber(ARGV[4])

    local bucket = redis.call('HMGET', key, 'tokens', 'last_update')
    local tokens = tonumber(bucket[1]) or capacity
    local last_update = tonumber(bucket[2]) or now

    -- Calculate tokens to add based on time elapsed
    local elapsed = now - last_update
    local new_tokens = math.min(capacity, tokens + (elapsed * rate))

    if new_tokens >= requested then
        -- Allow request
        new_tokens = new_tokens - requested
        redis.call('HMSET', key, 'tokens', new_tokens, 'last_update', now)
        redis.call('EXPIRE', key, 3600)
        return {1, new_tokens}
    else
        -- Deny request, calculate retry-after
        local retry_after = math.ceil((requested - new_tokens) / rate)
        return {0, retry_after}
    end
    """

    def __init__(
        self,
        redis: Redis,
        capacity: int = 100,  # Max tokens (burst size)
        rate: float = 10.0,   # Tokens per second (sustained rate)
        key_prefix: str = "webhook:ratelimit:"
    ):
        self.redis = redis
        self.capacity = capacity
        self.rate = rate
        self.key_prefix = key_prefix
        self._script_sha = None

    async def _get_script_sha(self) -> str:
        """Load Lua script into Redis."""
        if self._script_sha is None:
            self._script_sha = await self.redis.script_load(
                self.TOKEN_BUCKET_SCRIPT
            )
        return self._script_sha

    async def check_rate_limit(
        self,
        identifier: str,
        tokens_requested: int = 1
    ) -> tuple[bool, int]:
        """
        Check if request is within rate limit.

        Args:
            identifier: Rate limit key (IP, provider, etc.)
            tokens_requested: Number of tokens to consume

        Returns:
            Tuple of (allowed, remaining_tokens_or_retry_after)
        """
        key = f"{self.key_prefix}{identifier}"
        script_sha = await self._get_script_sha()

        result = await self.redis.evalsha(
            script_sha,
            1,
            key,
            self.capacity,
            self.rate,
            time.time(),
            tokens_requested
        )

        allowed = result[0] == 1
        value = int(result[1])

        return allowed, value

    async def is_allowed(
        self,
        identifier: str,
        tokens_requested: int = 1
    ) -> bool:
        """Simple check if request is allowed."""
        allowed, _ = await self.check_rate_limit(identifier, tokens_requested)
        return allowed

    async def consume_or_raise(
        self,
        identifier: str,
        tokens_requested: int = 1
    ) -> int:
        """
        Consume tokens or raise RateLimitExceeded.

        Returns:
            Remaining tokens
        """
        allowed, value = await self.check_rate_limit(identifier, tokens_requested)

        if not allowed:
            logger.warning(
                "rate_limit_exceeded",
                identifier=identifier,
                retry_after=value
            )
            raise RateLimitExceeded(retry_after=value)

        return value


class SlidingWindowRateLimiter:
    """
    Sliding window rate limiter for more accurate rate limiting.

    Uses Redis sorted sets to track request timestamps.
    """

    def __init__(
        self,
        redis: Redis,
        limit: int = 100,
        window_seconds: int = 60,
        key_prefix: str = "webhook:ratelimit:sliding:"
    ):
        self.redis = redis
        self.limit = limit
        self.window = window_seconds
        self.key_prefix = key_prefix

    async def check_rate_limit(self, identifier: str) -> tuple[bool, int]:
        """
        Check and record request in sliding window.

        Returns:
            Tuple of (allowed, current_count)
        """
        key = f"{self.key_prefix}{identifier}"
        now = time.time()
        window_start = now - self.window

        pipe = self.redis.pipeline()

        # Remove old entries
        pipe.zremrangebyscore(key, "-inf", window_start)

        # Count current entries
        pipe.zcard(key)

        # Add current request
        pipe.zadd(key, {str(uuid4()): now})

        # Set TTL
        pipe.expire(key, self.window + 1)

        results = await pipe.execute()
        current_count = results[1]

        allowed = current_count < self.limit

        return allowed, current_count


# Rate limiter middleware for FastAPI
class RateLimitMiddleware:
    """FastAPI middleware for rate limiting."""

    def __init__(
        self,
        rate_limiter: TokenBucketRateLimiter,
        identifier_func: Optional[Callable[[Request], str]] = None
    ):
        self.rate_limiter = rate_limiter
        self.identifier_func = identifier_func or self._default_identifier

    @staticmethod
    def _default_identifier(request: Request) -> str:
        """Extract identifier from request (default: client IP)."""
        # Handle X-Forwarded-For header for proxied requests
        forwarded = request.headers.get("X-Forwarded-For")
        if forwarded:
            return forwarded.split(",")[0].strip()
        return request.client.host if request.client else "unknown"

    async def __call__(
        self,
        request: Request,
        call_next: Callable
    ):
        """Process request with rate limiting."""
        identifier = self.identifier_func(request)

        try:
            remaining = await self.rate_limiter.consume_or_raise(identifier)

            response = await call_next(request)

            # Add rate limit headers
            response.headers["X-RateLimit-Limit"] = str(self.rate_limiter.capacity)
            response.headers["X-RateLimit-Remaining"] = str(remaining)

            return response

        except RateLimitExceeded as e:
            return JSONResponse(
                status_code=429,
                content={
                    "error": "rate_limit_exceeded",
                    "message": str(e),
                    "retry_after": e.retry_after
                },
                headers={
                    "Retry-After": str(e.retry_after),
                    "X-RateLimit-Limit": str(self.rate_limiter.capacity),
                    "X-RateLimit-Remaining": "0"
                }
            )
```

### Tiered Rate Limiting

```python
class TieredRateLimiter:
    """
    Multi-tier rate limiting for different webhook sources.

    Tiers:
    - Global: Overall system limit
    - Provider: Per-provider limit (Stripe, GitHub, etc.)
    - IP: Per-source IP limit
    """

    def __init__(self, redis: Redis):
        self.redis = redis

        # Configure tiers
        self.tiers = {
            "global": TokenBucketRateLimiter(
                redis, capacity=1000, rate=100, key_prefix="webhook:rl:global:"
            ),
            "provider": TokenBucketRateLimiter(
                redis, capacity=200, rate=20, key_prefix="webhook:rl:provider:"
            ),
            "ip": TokenBucketRateLimiter(
                redis, capacity=50, rate=5, key_prefix="webhook:rl:ip:"
            )
        }

    async def check_all_limits(
        self,
        provider: str,
        ip: str
    ) -> tuple[bool, Optional[str], int]:
        """
        Check all rate limit tiers.

        Returns:
            Tuple of (allowed, violated_tier, retry_after)
        """
        # Check from most specific to least specific
        for tier_name, identifier in [
            ("ip", ip),
            ("provider", provider),
            ("global", "system")
        ]:
            limiter = self.tiers[tier_name]
            allowed, value = await limiter.check_rate_limit(identifier)

            if not allowed:
                return False, tier_name, value

        return True, None, 0
```

---

## 7. Security Best Practices

### Security Checklist

| Category              | Requirement                  | Implementation                         |
| --------------------- | ---------------------------- | -------------------------------------- |
| **Authentication**    | Verify webhook signatures    | HMAC-SHA256, Ed25519, RSA              |
| **Replay Prevention** | Validate timestamps          | 5-minute tolerance window              |
| **Transport**         | HTTPS only                   | Reject HTTP requests                   |
| **Input Validation**  | Validate payload structure   | Pydantic schemas                       |
| **Rate Limiting**     | Prevent DoS attacks          | Token bucket algorithm                 |
| **Logging**           | Audit trail without PII      | Structured logging                     |
| **Secrets**           | Secure storage               | Environment variables, secret managers |
| **IP Allowlisting**   | Optional source verification | Provider IP ranges                     |

### Security Implementation

```python
# ============================================================================
# SECURITY BEST PRACTICES
# ============================================================================

from ipaddress import ip_address, ip_network
from typing import Set


class WebhookSecurityValidator:
    """
    Comprehensive security validation for webhooks.

    Implements defense-in-depth with multiple security layers.
    """

    # Known provider IP ranges (update periodically)
    PROVIDER_IP_RANGES: dict[str, list[str]] = {
        "stripe": [
            "3.18.12.63/32",
            "3.130.192.231/32",
            "13.235.14.237/32",
            "13.235.122.149/32",
            "18.211.135.69/32",
            "35.154.171.200/32",
            "52.15.183.38/32",
            "54.187.174.169/32",
            "54.187.205.235/32",
            "54.187.216.72/32",
        ],
        "github": [
            "192.30.252.0/22",
            "185.199.108.0/22",
            "140.82.112.0/20",
            "143.55.64.0/20",
        ],
        "slack": [
            "3.125.148.88/29",
            "3.126.10.88/29",
            "34.194.0.0/15",
            "34.226.0.0/16",
            "52.0.0.0/11",
        ]
    }

    def __init__(
        self,
        signature_verifier: SignatureVerifier,
        rate_limiter: TokenBucketRateLimiter,
        require_https: bool = True,
        enable_ip_allowlist: bool = False,
        blocked_ips: Optional[Set[str]] = None
    ):
        self.signature_verifier = signature_verifier
        self.rate_limiter = rate_limiter
        self.require_https = require_https
        self.enable_ip_allowlist = enable_ip_allowlist
        self.blocked_ips = blocked_ips or set()

    async def validate_request(
        self,
        request: Request,
        body: bytes,
        provider: str,
        signature_header: str,
        timestamp_header: Optional[str] = None
    ) -> None:
        """
        Perform comprehensive security validation.

        Raises:
            HTTPException: If any validation fails
        """
        client_ip = self._get_client_ip(request)

        # 1. Check HTTPS
        if self.require_https:
            self._validate_https(request)

        # 2. Check blocked IPs
        self._check_blocked_ip(client_ip)

        # 3. Check IP allowlist (if enabled)
        if self.enable_ip_allowlist:
            self._validate_source_ip(client_ip, provider)

        # 4. Check rate limit
        await self._check_rate_limit(client_ip)

        # 5. Verify signature
        self._verify_signature(body, signature_header, timestamp_header)

        # 6. Validate content type
        self._validate_content_type(request)

        # 7. Validate payload size
        self._validate_payload_size(body)

        logger.info(
            "webhook_security_validated",
            provider=provider,
            client_ip=client_ip
        )

    def _get_client_ip(self, request: Request) -> str:
        """Extract real client IP handling proxies."""
        # Check X-Forwarded-For (trusted proxy required)
        forwarded = request.headers.get("X-Forwarded-For")
        if forwarded:
            # First IP is the original client
            return forwarded.split(",")[0].strip()

        # Check X-Real-IP
        real_ip = request.headers.get("X-Real-IP")
        if real_ip:
            return real_ip.strip()

        return request.client.host if request.client else "0.0.0.0"

    def _validate_https(self, request: Request) -> None:
        """Ensure request came over HTTPS."""
        # Check X-Forwarded-Proto for proxied requests
        proto = request.headers.get("X-Forwarded-Proto", request.url.scheme)

        if proto != "https":
            logger.warning("webhook_http_rejected", scheme=proto)
            raise HTTPException(
                status_code=400,
                detail="HTTPS required for webhook endpoints"
            )

    def _check_blocked_ip(self, ip: str) -> None:
        """Check if IP is blocked."""
        if ip in self.blocked_ips:
            logger.warning("webhook_blocked_ip", ip=ip)
            raise HTTPException(status_code=403, detail="Forbidden")

    def _validate_source_ip(self, ip: str, provider: str) -> None:
        """Validate source IP against provider's known ranges."""
        ranges = self.PROVIDER_IP_RANGES.get(provider, [])

        if not ranges:
            return  # No allowlist defined for provider

        client = ip_address(ip)

        for cidr in ranges:
            if client in ip_network(cidr):
                return

        logger.warning(
            "webhook_ip_not_in_allowlist",
            ip=ip,
            provider=provider
        )
        raise HTTPException(
            status_code=403,
            detail=f"Source IP not in allowed range for {provider}"
        )

    async def _check_rate_limit(self, ip: str) -> None:
        """Enforce rate limiting."""
        try:
            await self.rate_limiter.consume_or_raise(ip)
        except RateLimitExceeded as e:
            raise HTTPException(
                status_code=429,
                detail=str(e),
                headers={"Retry-After": str(e.retry_after)}
            )

    def _verify_signature(
        self,
        body: bytes,
        signature: str,
        timestamp: Optional[str]
    ) -> None:
        """Verify cryptographic signature."""
        try:
            self.signature_verifier.verify_hmac_sha256(
                body, signature, timestamp
            )
        except SignatureVerificationError as e:
            raise HTTPException(status_code=e.status_code, detail=e.message)

    def _validate_content_type(self, request: Request) -> None:
        """Ensure correct content type."""
        content_type = request.headers.get("Content-Type", "")

        if "application/json" not in content_type:
            raise HTTPException(
                status_code=415,
                detail="Content-Type must be application/json"
            )

    def _validate_payload_size(
        self,
        body: bytes,
        max_size: int = 1_048_576  # 1MB
    ) -> None:
        """Prevent oversized payloads."""
        if len(body) > max_size:
            raise HTTPException(
                status_code=413,
                detail=f"Payload too large (max: {max_size} bytes)"
            )


# Secret management utilities
class SecretManager:
    """Secure secret retrieval from various backends."""

    @staticmethod
    def from_env(key: str) -> str:
        """Get secret from environment variable."""
        value = os.environ.get(key)
        if not value:
            raise ValueError(f"Required secret {key} not found in environment")
        return value

    @staticmethod
    async def from_gcp_secret_manager(
        project: str,
        secret_id: str,
        version: str = "latest"
    ) -> str:
        """Get secret from Google Cloud Secret Manager."""
        from google.cloud import secretmanager

        client = secretmanager.SecretManagerServiceClient()
        name = f"projects/{project}/secrets/{secret_id}/versions/{version}"
        response = client.access_secret_version(name=name)
        return response.payload.data.decode("utf-8")

    @staticmethod
    async def from_aws_secrets_manager(secret_name: str) -> str:
        """Get secret from AWS Secrets Manager."""
        import boto3

        client = boto3.client("secretsmanager")
        response = client.get_secret_value(SecretId=secret_name)
        return response["SecretString"]

    @staticmethod
    async def from_vault(path: str, key: str) -> str:
        """Get secret from HashiCorp Vault."""
        import hvac

        client = hvac.Client(url=os.environ["VAULT_ADDR"])
        client.token = os.environ["VAULT_TOKEN"]

        response = client.secrets.kv.v2.read_secret_version(path=path)
        return response["data"]["data"][key]
```

---

## 8. Testing Webhook Integrations

### Comprehensive Test Suite

```python
# ============================================================================
# TESTING WEBHOOK INTEGRATIONS
# ============================================================================

import pytest
from fastapi.testclient import TestClient
from unittest.mock import AsyncMock, MagicMock, patch
from freezegun import freeze_time


class WebhookTestUtils:
    """Utilities for testing webhook implementations."""

    @staticmethod
    def generate_signature(
        payload: dict,
        secret: str,
        timestamp: Optional[int] = None
    ) -> tuple[str, str]:
        """
        Generate valid webhook signature for testing.

        Returns:
            Tuple of (signature, timestamp)
        """
        timestamp = timestamp or int(time.time())
        payload_str = json.dumps(payload, separators=(",", ":"))
        signed_payload = f"{timestamp}.{payload_str}"

        signature = hmac.new(
            secret.encode("utf-8"),
            signed_payload.encode("utf-8"),
            hashlib.sha256
        ).hexdigest()

        return signature, str(timestamp)

    @staticmethod
    def create_test_event(
        event_type: str = "payment.succeeded",
        event_id: Optional[str] = None,
        data: Optional[dict] = None
    ) -> dict:
        """Create a test webhook event."""
        return {
            "id": event_id or f"evt_test_{uuid4().hex[:12]}",
            "type": event_type,
            "created": int(time.time()),
            "data": data or {"amount": 1000, "currency": "usd"},
            "livemode": False,
            "api_version": "2024-01-01"
        }

    @staticmethod
    def create_mock_redis() -> MagicMock:
        """Create a mock Redis client for testing."""
        mock_redis = MagicMock()
        mock_redis.exists = AsyncMock(return_value=0)
        mock_redis.set = AsyncMock(return_value=True)
        mock_redis.setex = AsyncMock(return_value=True)
        mock_redis.get = AsyncMock(return_value=None)
        mock_redis.ping = AsyncMock(return_value=True)
        mock_redis.evalsha = AsyncMock(return_value=[1, 99])
        mock_redis.script_load = AsyncMock(return_value="mock_sha")
        return mock_redis


# Test fixtures
@pytest.fixture
def test_secret():
    return "whsec_test_secret_key_12345"


@pytest.fixture
def mock_redis():
    return WebhookTestUtils.create_mock_redis()


@pytest.fixture
def webhook_client(mock_redis, test_secret):
    """Create test client with mocked dependencies."""
    with patch.dict(os.environ, {"WEBHOOK_SECRET": test_secret}):
        from webhook_handler import app, get_redis

        async def mock_get_redis():
            return mock_redis

        app.dependency_overrides[get_redis] = mock_get_redis

        yield TestClient(app)

        app.dependency_overrides.clear()


# Unit tests
class TestSignatureVerification:
    """Tests for signature verification."""

    def test_valid_signature(self, test_secret):
        """Test verification of valid signature."""
        verifier = SignatureVerifier(test_secret)
        payload = b'{"id":"evt_123","type":"test"}'
        timestamp = str(int(time.time()))

        signed = f"{timestamp}.{payload.decode()}"
        signature = hmac.new(
            test_secret.encode(),
            signed.encode(),
            hashlib.sha256
        ).hexdigest()

        result = verifier.verify_hmac_sha256(payload, signature, timestamp)
        assert result is True

    def test_invalid_signature(self, test_secret):
        """Test rejection of invalid signature."""
        verifier = SignatureVerifier(test_secret)
        payload = b'{"id":"evt_123"}'

        with pytest.raises(SignatureVerificationError) as exc:
            verifier.verify_hmac_sha256(payload, "invalid_signature", str(int(time.time())))

        assert exc.value.status_code == 401

    def test_expired_timestamp(self, test_secret):
        """Test rejection of expired timestamp."""
        verifier = SignatureVerifier(test_secret, tolerance_seconds=300)
        payload = b'{"id":"evt_123"}'
        old_timestamp = str(int(time.time()) - 600)

        signature, _ = WebhookTestUtils.generate_signature(
            json.loads(payload), test_secret, int(old_timestamp)
        )

        with pytest.raises(SignatureVerificationError) as exc:
            verifier.verify_hmac_sha256(payload, signature, old_timestamp)

        assert "expired" in exc.value.message.lower()

    def test_timing_attack_resistance(self, test_secret):
        """Verify constant-time comparison is used."""
        verifier = SignatureVerifier(test_secret)
        payload = b'{"id":"evt_123"}'
        timestamp = str(int(time.time()))

        # Generate valid signature
        valid_sig, _ = WebhookTestUtils.generate_signature(
            json.loads(payload), test_secret, int(timestamp)
        )

        # Measure time for valid signature
        import time as time_module

        times_valid = []
        times_invalid = []

        for _ in range(100):
            start = time_module.perf_counter()
            try:
                verifier.verify_hmac_sha256(payload, valid_sig, timestamp)
            except:
                pass
            times_valid.append(time_module.perf_counter() - start)

            start = time_module.perf_counter()
            try:
                verifier.verify_hmac_sha256(payload, "x" * len(valid_sig), timestamp)
            except:
                pass
            times_invalid.append(time_module.perf_counter() - start)

        # Times should be similar (within 2x)
        avg_valid = sum(times_valid) / len(times_valid)
        avg_invalid = sum(times_invalid) / len(times_invalid)

        assert 0.5 < avg_valid / avg_invalid < 2.0


class TestIdempotency:
    """Tests for idempotency handling."""

    @pytest.mark.asyncio
    async def test_new_event_allowed(self, mock_redis):
        """Test that new events are allowed."""
        mock_redis.set = AsyncMock(return_value=True)

        handler = IdempotencyHandler(mock_redis)
        is_new, _ = await handler.check_and_set("evt_new_123")

        assert is_new is True
        mock_redis.set.assert_called_once()

    @pytest.mark.asyncio
    async def test_duplicate_event_rejected(self, mock_redis):
        """Test that duplicate events are detected."""
        mock_redis.set = AsyncMock(return_value=False)  # Key exists
        mock_redis.get = AsyncMock(return_value=json.dumps({
            "status": "processed",
            "result": {"action": "completed"}
        }))

        handler = IdempotencyHandler(mock_redis)
        is_new, previous = await handler.check_and_set("evt_dup_123")

        assert is_new is False
        assert previous["status"] == "processed"


class TestRateLimiting:
    """Tests for rate limiting."""

    @pytest.mark.asyncio
    async def test_rate_limit_allowed(self, mock_redis):
        """Test requests within limit are allowed."""
        mock_redis.evalsha = AsyncMock(return_value=[1, 99])

        limiter = TokenBucketRateLimiter(mock_redis, capacity=100, rate=10)
        allowed, remaining = await limiter.check_rate_limit("test_ip")

        assert allowed is True
        assert remaining == 99

    @pytest.mark.asyncio
    async def test_rate_limit_exceeded(self, mock_redis):
        """Test requests over limit are rejected."""
        mock_redis.evalsha = AsyncMock(return_value=[0, 30])

        limiter = TokenBucketRateLimiter(mock_redis, capacity=100, rate=10)

        with pytest.raises(RateLimitExceeded) as exc:
            await limiter.consume_or_raise("test_ip")

        assert exc.value.retry_after == 30


# Integration tests
class TestWebhookEndpoint:
    """Integration tests for webhook endpoint."""

    def test_valid_webhook_accepted(self, webhook_client, test_secret):
        """Test valid webhook is accepted."""
        event = WebhookTestUtils.create_test_event()
        signature, timestamp = WebhookTestUtils.generate_signature(event, test_secret)

        response = webhook_client.post(
            "/webhooks/stripe",
            json=event,
            headers={
                "Stripe-Signature": signature,
                "Stripe-Timestamp": timestamp
            }
        )

        assert response.status_code == 202
        assert response.json()["status"] == "accepted"

    def test_invalid_signature_rejected(self, webhook_client):
        """Test invalid signature is rejected."""
        event = WebhookTestUtils.create_test_event()

        response = webhook_client.post(
            "/webhooks/stripe",
            json=event,
            headers={
                "Stripe-Signature": "invalid",
                "Stripe-Timestamp": str(int(time.time()))
            }
        )

        assert response.status_code == 401

    def test_duplicate_event_returns_200(self, webhook_client, mock_redis, test_secret):
        """Test duplicate events return 200 with duplicate status."""
        mock_redis.set = AsyncMock(return_value=False)
        mock_redis.get = AsyncMock(return_value=json.dumps({
            "status": "processed"
        }))

        event = WebhookTestUtils.create_test_event()
        signature, timestamp = WebhookTestUtils.generate_signature(event, test_secret)

        response = webhook_client.post(
            "/webhooks/stripe",
            json=event,
            headers={
                "Stripe-Signature": signature,
                "Stripe-Timestamp": timestamp
            }
        )

        assert response.status_code == 200
        assert response.json()["status"] == "duplicate"

    def test_rate_limited_returns_429(self, webhook_client, mock_redis, test_secret):
        """Test rate limited requests return 429."""
        mock_redis.evalsha = AsyncMock(return_value=[0, 60])

        event = WebhookTestUtils.create_test_event()
        signature, timestamp = WebhookTestUtils.generate_signature(event, test_secret)

        response = webhook_client.post(
            "/webhooks/stripe",
            json=event,
            headers={
                "Stripe-Signature": signature,
                "Stripe-Timestamp": timestamp
            }
        )

        assert response.status_code == 429
        assert "Retry-After" in response.headers


# Load testing
class TestLoadTesting:
    """Load testing for webhook endpoint."""

    @pytest.mark.slow
    def test_concurrent_requests(self, webhook_client, test_secret):
        """Test handling of concurrent requests."""
        import concurrent.futures

        def send_webhook():
            event = WebhookTestUtils.create_test_event()
            sig, ts = WebhookTestUtils.generate_signature(event, test_secret)
            return webhook_client.post(
                "/webhooks/stripe",
                json=event,
                headers={"Stripe-Signature": sig, "Stripe-Timestamp": ts}
            )

        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            futures = [executor.submit(send_webhook) for _ in range(100)]
            results = [f.result() for f in concurrent.futures.as_completed(futures)]

        success_count = sum(1 for r in results if r.status_code in (200, 202))
        assert success_count >= 90  # Allow some rate limiting
```

### Load Testing Script

```bash
#!/bin/bash
# webhook-load-test.sh - Comprehensive webhook load testing

set -euo pipefail

# Configuration
ENDPOINT="${1:-http://localhost:8000/webhooks/stripe}"
CONCURRENCY="${2:-10}"
REQUESTS="${3:-1000}"
SECRET="${WEBHOOK_SECRET:-test_secret}"

echo "========================================"
echo "Webhook Load Test"
echo "========================================"
echo "Endpoint: $ENDPOINT"
echo "Concurrency: $CONCURRENCY"
echo "Total Requests: $REQUESTS"
echo "========================================"

# Generate test payload
generate_payload() {
    local id="evt_$(date +%s%N | sha256sum | head -c 12)"
    cat <<EOF
{"id":"$id","type":"payment.succeeded","created":$(date +%s),"data":{"amount":1000,"currency":"usd"},"livemode":false}
EOF
}

# Generate HMAC-SHA256 signature
generate_signature() {
    local payload="$1"
    local timestamp="$2"
    echo -n "${timestamp}.${payload}" | openssl dgst -sha256 -hmac "$SECRET" | cut -d' ' -f2
}

# Send single request and capture result
send_request() {
    local payload
    local timestamp
    local signature
    local start_time
    local end_time
    local http_code

    payload=$(generate_payload)
    timestamp=$(date +%s)
    signature=$(generate_signature "$payload" "$timestamp")

    start_time=$(date +%s%N)

    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "$ENDPOINT" \
        -H "Content-Type: application/json" \
        -H "Stripe-Signature: $signature" \
        -H "Stripe-Timestamp: $timestamp" \
        -d "$payload" \
        --max-time 30)

    end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))

    echo "$http_code,$duration"
}

# Export functions for parallel execution
export -f send_request generate_payload generate_signature
export ENDPOINT SECRET

# Run load test
echo "Starting load test..."
start_time=$(date +%s)

results=$(seq "$REQUESTS" | xargs -P "$CONCURRENCY" -I {} bash -c 'send_request')

end_time=$(date +%s)
duration=$((end_time - start_time))

# Analyze results
echo ""
echo "========================================"
echo "Results"
echo "========================================"

total=$(echo "$results" | wc -l)
success_200=$(echo "$results" | grep -c "^200," || true)
success_202=$(echo "$results" | grep -c "^202," || true)
rate_limited=$(echo "$results" | grep -c "^429," || true)
errors=$(echo "$results" | grep -cvE "^(200|202|429)," || true)

echo "Total Requests: $total"
echo "Success (200): $success_200"
echo "Accepted (202): $success_202"
echo "Rate Limited (429): $rate_limited"
echo "Errors: $errors"
echo ""
echo "Duration: ${duration}s"
echo "Requests/sec: $(echo "scale=2; $total / $duration" | bc)"
echo ""

# Calculate latency percentiles
latencies=$(echo "$results" | cut -d',' -f2 | sort -n)
p50=$(echo "$latencies" | awk 'NR==int(NR*0.5){print}')
p90=$(echo "$latencies" | awk 'NR==int(NR*0.9){print}')
p99=$(echo "$latencies" | awk 'NR==int(NR*0.99){print}')

echo "Latency (ms):"
echo "  P50: ${p50:-N/A}"
echo "  P90: ${p90:-N/A}"
echo "  P99: ${p99:-N/A}"

echo "========================================"
echo "Load test complete"
```

---

## 9. Monitoring and Alerting

### Prometheus Metrics

```python
# ============================================================================
# MONITORING AND ALERTING
# ============================================================================

from prometheus_client import Counter, Histogram, Gauge, Info
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST


# Define metrics
WEBHOOK_RECEIVED = Counter(
    "webhook_received_total",
    "Total webhooks received",
    ["provider", "event_type"]
)

WEBHOOK_PROCESSED = Counter(
    "webhook_processed_total",
    "Total webhooks processed",
    ["provider", "event_type", "status"]
)

WEBHOOK_LATENCY = Histogram(
    "webhook_processing_duration_seconds",
    "Webhook processing duration",
    ["provider", "event_type"],
    buckets=[0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0]
)

WEBHOOK_QUEUE_SIZE = Gauge(
    "webhook_queue_size",
    "Current webhook queue size",
    ["queue_type"]
)

WEBHOOK_SIGNATURE_FAILURES = Counter(
    "webhook_signature_failures_total",
    "Total signature verification failures",
    ["provider", "reason"]
)

WEBHOOK_RATE_LIMITED = Counter(
    "webhook_rate_limited_total",
    "Total rate limited requests",
    ["provider", "tier"]
)

WEBHOOK_DLQ_SIZE = Gauge(
    "webhook_dlq_size",
    "Current dead letter queue size"
)

WEBHOOK_RETRY_QUEUE_SIZE = Gauge(
    "webhook_retry_queue_size",
    "Current retry queue size"
)


class MetricsCollector:
    """Collects and exposes webhook metrics."""

    def __init__(self, redis: Redis, retry_queue: RetryQueue):
        self.redis = redis
        self.retry_queue = retry_queue

    async def collect_queue_metrics(self) -> None:
        """Update queue size metrics."""
        stats = await self.retry_queue.get_queue_stats()

        WEBHOOK_RETRY_QUEUE_SIZE.set(stats["pending_retries"])
        WEBHOOK_DLQ_SIZE.set(stats["dlq_size"])

    def record_webhook_received(
        self,
        provider: str,
        event_type: str
    ) -> None:
        """Record incoming webhook."""
        WEBHOOK_RECEIVED.labels(
            provider=provider,
            event_type=event_type
        ).inc()

    def record_webhook_processed(
        self,
        provider: str,
        event_type: str,
        status: str,
        duration_seconds: float
    ) -> None:
        """Record processed webhook."""
        WEBHOOK_PROCESSED.labels(
            provider=provider,
            event_type=event_type,
            status=status
        ).inc()

        WEBHOOK_LATENCY.labels(
            provider=provider,
            event_type=event_type
        ).observe(duration_seconds)

    def record_signature_failure(
        self,
        provider: str,
        reason: str
    ) -> None:
        """Record signature verification failure."""
        WEBHOOK_SIGNATURE_FAILURES.labels(
            provider=provider,
            reason=reason
        ).inc()

    def record_rate_limited(
        self,
        provider: str,
        tier: str
    ) -> None:
        """Record rate limited request."""
        WEBHOOK_RATE_LIMITED.labels(
            provider=provider,
            tier=tier
        ).inc()


# FastAPI metrics endpoint
@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint."""
    # Update queue metrics
    await metrics_collector.collect_queue_metrics()

    return Response(
        content=generate_latest(),
        media_type=CONTENT_TYPE_LATEST
    )
```

### Grafana Dashboard Configuration

```json
{
  "dashboard": {
    "title": "Webhook Processing Dashboard",
    "uid": "webhook-dashboard",
    "panels": [
      {
        "title": "Webhooks Received (Rate)",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(webhook_received_total[5m])",
            "legendFormat": "{{provider}} - {{event_type}}"
          }
        ]
      },
      {
        "title": "Processing Success Rate",
        "type": "gauge",
        "targets": [
          {
            "expr": "sum(rate(webhook_processed_total{status='success'}[5m])) / sum(rate(webhook_processed_total[5m])) * 100"
          }
        ],
        "thresholds": [
          { "value": 0, "color": "red" },
          { "value": 90, "color": "yellow" },
          { "value": 95, "color": "green" }
        ]
      },
      {
        "title": "Processing Latency (P95)",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(webhook_processing_duration_seconds_bucket[5m]))",
            "legendFormat": "P95 Latency"
          }
        ]
      },
      {
        "title": "Queue Sizes",
        "type": "graph",
        "targets": [
          {
            "expr": "webhook_retry_queue_size",
            "legendFormat": "Retry Queue"
          },
          {
            "expr": "webhook_dlq_size",
            "legendFormat": "Dead Letter Queue"
          }
        ]
      },
      {
        "title": "Signature Failures",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(increase(webhook_signature_failures_total[1h]))"
          }
        ],
        "thresholds": [
          { "value": 0, "color": "green" },
          { "value": 10, "color": "yellow" },
          { "value": 50, "color": "red" }
        ]
      },
      {
        "title": "Rate Limited Requests",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(webhook_rate_limited_total[5m])",
            "legendFormat": "{{provider}} - {{tier}}"
          }
        ]
      }
    ]
  }
}
```

### Alerting Rules

```yaml
# prometheus-alerts.yml
groups:
  - name: webhook-alerts
    rules:
      # High error rate
      - alert: WebhookHighErrorRate
        expr: |
          sum(rate(webhook_processed_total{status="failed"}[5m])) /
          sum(rate(webhook_processed_total[5m])) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Webhook error rate above 5%"
          description: "Error rate is {{ $value | humanizePercentage }}"

      # High latency
      - alert: WebhookHighLatency
        expr: |
          histogram_quantile(0.95, rate(webhook_processing_duration_seconds_bucket[5m])) > 5
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Webhook P95 latency above 5 seconds"
          description: "P95 latency is {{ $value | humanizeDuration }}"

      # DLQ not empty
      - alert: WebhookDLQNotEmpty
        expr: webhook_dlq_size > 0
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "Webhook dead letter queue has items"
          description: "DLQ size: {{ $value }}"

      # Retry queue growing
      - alert: WebhookRetryQueueGrowing
        expr: |
          delta(webhook_retry_queue_size[30m]) > 100
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Webhook retry queue growing"
          description: "Queue grew by {{ $value }} in 30 minutes"

      # Signature failures spike
      - alert: WebhookSignatureFailuresSpike
        expr: |
          rate(webhook_signature_failures_total[5m]) > 1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High rate of signature verification failures"
          description: "{{ $value | humanize }}/sec failures - possible attack or misconfiguration"

      # Excessive rate limiting
      - alert: WebhookExcessiveRateLimiting
        expr: |
          sum(rate(webhook_rate_limited_total[5m])) /
          sum(rate(webhook_received_total[5m])) > 0.1
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "More than 10% of webhooks rate limited"
          description: "Rate limiting {{ $value | humanizePercentage }} of traffic"
```

### Structured Logging Format

```python
# Structured logging configuration
def configure_structured_logging():
    """Configure structured JSON logging."""

    structlog.configure(
        processors=[
            structlog.stdlib.filter_by_level,
            structlog.contextvars.merge_contextvars,
            structlog.processors.add_log_level,
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            # Add standard fields
            add_standard_fields,
            structlog.processors.JSONRenderer()
        ],
        wrapper_class=structlog.stdlib.BoundLogger,
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )


def add_standard_fields(logger, method_name, event_dict):
    """Add standard fields to all log entries."""
    event_dict["service"] = "webhook-handler"
    event_dict["environment"] = os.environ.get("ENVIRONMENT", "development")
    event_dict["version"] = "2.0.0"
    return event_dict


# Example log entries
"""
{"timestamp": "2026-01-21T10:30:00.000Z", "level": "info", "event": "webhook_received",
 "event_id": "evt_abc123", "provider": "stripe", "event_type": "payment.succeeded",
 "correlation_id": "req_xyz789", "service": "webhook-handler", "environment": "production"}

{"timestamp": "2026-01-21T10:30:00.150Z", "level": "info", "event": "webhook_processed",
 "event_id": "evt_abc123", "status": "success", "duration_ms": 145,
 "service": "webhook-handler", "environment": "production"}

{"timestamp": "2026-01-21T10:30:01.000Z", "level": "error", "event": "webhook_processing_error",
 "event_id": "evt_def456", "error": "Database connection failed", "attempt": 1,
 "will_retry": true, "service": "webhook-handler", "environment": "production"}
"""
```

---

## 10. Popular Webhook Integrations

### Stripe Integration

```python
# ============================================================================
# STRIPE WEBHOOK INTEGRATION
# ============================================================================

class StripeWebhookHandler:
    """
    Complete Stripe webhook handler.

    Handles all major Stripe event types with proper error handling.
    """

    # Stripe signature header format: t=timestamp,v1=signature
    SIGNATURE_HEADER = "Stripe-Signature"

    def __init__(
        self,
        webhook_secret: str,
        redis: Redis,
        idempotency_handler: IdempotencyHandler,
        retry_queue: RetryQueue
    ):
        self.secret = webhook_secret
        self.redis = redis
        self.idempotency = idempotency_handler
        self.retry_queue = retry_queue

        # Event handlers registry
        self.handlers: dict[str, Callable] = {
            "payment_intent.succeeded": self.handle_payment_succeeded,
            "payment_intent.payment_failed": self.handle_payment_failed,
            "charge.refunded": self.handle_charge_refunded,
            "charge.dispute.created": self.handle_dispute_created,
            "customer.subscription.created": self.handle_subscription_created,
            "customer.subscription.updated": self.handle_subscription_updated,
            "customer.subscription.deleted": self.handle_subscription_deleted,
            "invoice.paid": self.handle_invoice_paid,
            "invoice.payment_failed": self.handle_invoice_payment_failed,
        }

    def parse_signature_header(self, header: str) -> tuple[str, str]:
        """Parse Stripe's composite signature header."""
        parts = {}
        for item in header.split(","):
            key, value = item.split("=", 1)
            parts[key] = value
        return parts.get("v1", ""), parts.get("t", "")

    async def verify_and_process(
        self,
        payload: bytes,
        signature_header: str
    ) -> ProcessingResult:
        """Verify signature and process Stripe webhook."""
        signature, timestamp = self.parse_signature_header(signature_header)

        # Verify signature
        verifier = SignatureVerifier(self.secret)
        verifier.verify_hmac_sha256(payload, signature, timestamp)

        # Parse event
        event = WebhookEvent(**json.loads(payload))

        # Check idempotency
        is_new, previous = await self.idempotency.check_and_set(event.id)
        if not is_new:
            return ProcessingResult(
                event_id=event.id,
                status="duplicate",
                message="Event already processed"
            )

        # Route to handler
        handler = self.handlers.get(event.type)
        if not handler:
            logger.info("stripe_unhandled_event_type", event_type=event.type)
            return ProcessingResult(
                event_id=event.id,
                status="ignored",
                message=f"Unhandled event type: {event.type}"
            )

        try:
            result = await handler(event)
            await self.idempotency.mark_processed(event.id, result)
            return ProcessingResult(
                event_id=event.id,
                status="processed",
                message=json.dumps(result)
            )
        except Exception as e:
            logger.error("stripe_processing_error", event_id=event.id, error=str(e))
            await self.retry_queue.enqueue_retry(
                event.dict(), 0, str(e)
            )
            return ProcessingResult(
                event_id=event.id,
                status="accepted",
                message="Queued for retry"
            )

    async def handle_payment_succeeded(self, event: WebhookEvent) -> dict:
        """Handle successful payment."""
        payment_intent = event.data.get("object", {})
        return {
            "action": "payment_confirmed",
            "payment_intent_id": payment_intent.get("id"),
            "amount": payment_intent.get("amount"),
            "currency": payment_intent.get("currency")
        }

    async def handle_payment_failed(self, event: WebhookEvent) -> dict:
        """Handle failed payment."""
        payment_intent = event.data.get("object", {})
        return {
            "action": "payment_failed",
            "payment_intent_id": payment_intent.get("id"),
            "error_code": payment_intent.get("last_payment_error", {}).get("code")
        }

    async def handle_charge_refunded(self, event: WebhookEvent) -> dict:
        """Handle refund."""
        charge = event.data.get("object", {})
        return {
            "action": "refund_processed",
            "charge_id": charge.get("id"),
            "amount_refunded": charge.get("amount_refunded")
        }

    async def handle_dispute_created(self, event: WebhookEvent) -> dict:
        """Handle new dispute."""
        dispute = event.data.get("object", {})
        return {
            "action": "dispute_opened",
            "dispute_id": dispute.get("id"),
            "amount": dispute.get("amount"),
            "reason": dispute.get("reason")
        }

    async def handle_subscription_created(self, event: WebhookEvent) -> dict:
        """Handle new subscription."""
        subscription = event.data.get("object", {})
        return {
            "action": "subscription_created",
            "subscription_id": subscription.get("id"),
            "customer_id": subscription.get("customer"),
            "status": subscription.get("status")
        }

    async def handle_subscription_updated(self, event: WebhookEvent) -> dict:
        """Handle subscription update."""
        subscription = event.data.get("object", {})
        return {
            "action": "subscription_updated",
            "subscription_id": subscription.get("id"),
            "status": subscription.get("status")
        }

    async def handle_subscription_deleted(self, event: WebhookEvent) -> dict:
        """Handle subscription cancellation."""
        subscription = event.data.get("object", {})
        return {
            "action": "subscription_cancelled",
            "subscription_id": subscription.get("id")
        }

    async def handle_invoice_paid(self, event: WebhookEvent) -> dict:
        """Handle paid invoice."""
        invoice = event.data.get("object", {})
        return {
            "action": "invoice_paid",
            "invoice_id": invoice.get("id"),
            "amount_paid": invoice.get("amount_paid")
        }

    async def handle_invoice_payment_failed(self, event: WebhookEvent) -> dict:
        """Handle failed invoice payment."""
        invoice = event.data.get("object", {})
        return {
            "action": "invoice_payment_failed",
            "invoice_id": invoice.get("id"),
            "attempt_count": invoice.get("attempt_count")
        }
```

### GitHub Integration

```python
# ============================================================================
# GITHUB WEBHOOK INTEGRATION
# ============================================================================

class GitHubWebhookHandler:
    """
    GitHub webhook handler for CI/CD and automation.

    Handles push, PR, issue, and other GitHub events.
    """

    SIGNATURE_HEADER = "X-Hub-Signature-256"
    EVENT_HEADER = "X-GitHub-Event"
    DELIVERY_HEADER = "X-GitHub-Delivery"

    def __init__(self, webhook_secret: str, redis: Redis):
        self.secret = webhook_secret
        self.redis = redis

        self.handlers: dict[str, Callable] = {
            "push": self.handle_push,
            "pull_request": self.handle_pull_request,
            "issues": self.handle_issues,
            "issue_comment": self.handle_issue_comment,
            "workflow_run": self.handle_workflow_run,
            "release": self.handle_release,
            "ping": self.handle_ping,
        }

    def verify_signature(self, payload: bytes, signature_header: str) -> bool:
        """Verify GitHub signature (sha256=...)."""
        expected = "sha256=" + hmac.new(
            self.secret.encode(),
            payload,
            hashlib.sha256
        ).hexdigest()

        if not hmac.compare_digest(expected, signature_header):
            raise SignatureVerificationError("Invalid GitHub signature")

        return True

    async def process(
        self,
        payload: bytes,
        signature_header: str,
        event_type: str,
        delivery_id: str
    ) -> ProcessingResult:
        """Process GitHub webhook."""
        # Verify signature
        self.verify_signature(payload, signature_header)

        # Parse payload
        data = json.loads(payload)

        # Route to handler
        handler = self.handlers.get(event_type)
        if not handler:
            return ProcessingResult(
                event_id=delivery_id,
                status="ignored",
                message=f"Unhandled event: {event_type}"
            )

        result = await handler(data, delivery_id)
        return ProcessingResult(
            event_id=delivery_id,
            status="processed",
            message=json.dumps(result)
        )

    async def handle_push(self, data: dict, delivery_id: str) -> dict:
        """Handle push event."""
        return {
            "action": "push_received",
            "ref": data.get("ref"),
            "repository": data.get("repository", {}).get("full_name"),
            "commits": len(data.get("commits", [])),
            "pusher": data.get("pusher", {}).get("name")
        }

    async def handle_pull_request(self, data: dict, delivery_id: str) -> dict:
        """Handle PR events."""
        pr = data.get("pull_request", {})
        return {
            "action": data.get("action"),
            "pr_number": pr.get("number"),
            "title": pr.get("title"),
            "state": pr.get("state"),
            "merged": pr.get("merged", False)
        }

    async def handle_issues(self, data: dict, delivery_id: str) -> dict:
        """Handle issue events."""
        issue = data.get("issue", {})
        return {
            "action": data.get("action"),
            "issue_number": issue.get("number"),
            "title": issue.get("title"),
            "state": issue.get("state")
        }

    async def handle_issue_comment(self, data: dict, delivery_id: str) -> dict:
        """Handle issue comment events."""
        return {
            "action": data.get("action"),
            "issue_number": data.get("issue", {}).get("number"),
            "comment_id": data.get("comment", {}).get("id")
        }

    async def handle_workflow_run(self, data: dict, delivery_id: str) -> dict:
        """Handle workflow run events."""
        workflow = data.get("workflow_run", {})
        return {
            "action": data.get("action"),
            "workflow_name": workflow.get("name"),
            "conclusion": workflow.get("conclusion"),
            "run_number": workflow.get("run_number")
        }

    async def handle_release(self, data: dict, delivery_id: str) -> dict:
        """Handle release events."""
        release = data.get("release", {})
        return {
            "action": data.get("action"),
            "tag_name": release.get("tag_name"),
            "name": release.get("name"),
            "prerelease": release.get("prerelease")
        }

    async def handle_ping(self, data: dict, delivery_id: str) -> dict:
        """Handle ping event (webhook setup verification)."""
        return {
            "action": "pong",
            "zen": data.get("zen"),
            "hook_id": data.get("hook_id")
        }
```

### Slack Integration

```python
# ============================================================================
# SLACK WEBHOOK INTEGRATION
# ============================================================================

class SlackWebhookHandler:
    """
    Slack webhook handler for slash commands and events.

    Handles:
    - Event API callbacks
    - Slash commands
    - Interactive components
    - URL verification challenges
    """

    SIGNATURE_HEADER = "X-Slack-Signature"
    TIMESTAMP_HEADER = "X-Slack-Request-Timestamp"

    def __init__(
        self,
        signing_secret: str,
        bot_token: str,
        redis: Redis
    ):
        self.signing_secret = signing_secret
        self.bot_token = bot_token
        self.redis = redis

        self.event_handlers: dict[str, Callable] = {
            "message": self.handle_message,
            "app_mention": self.handle_app_mention,
            "reaction_added": self.handle_reaction_added,
            "channel_created": self.handle_channel_created,
            "member_joined_channel": self.handle_member_joined,
        }

    def verify_signature(
        self,
        payload: bytes,
        signature_header: str,
        timestamp_header: str
    ) -> bool:
        """Verify Slack request signature."""
        # Check timestamp (5 minute tolerance)
        timestamp = int(timestamp_header)
        if abs(time.time() - timestamp) > 300:
            raise SignatureVerificationError("Request timestamp expired")

        # Compute signature
        sig_basestring = f"v0:{timestamp}:{payload.decode('utf-8')}"
        expected = "v0=" + hmac.new(
            self.signing_secret.encode(),
            sig_basestring.encode(),
            hashlib.sha256
        ).hexdigest()

        if not hmac.compare_digest(expected, signature_header):
            raise SignatureVerificationError("Invalid Slack signature")

        return True

    async def process(
        self,
        payload: bytes,
        signature_header: str,
        timestamp_header: str
    ) -> dict:
        """Process Slack webhook."""
        # Verify signature
        self.verify_signature(payload, signature_header, timestamp_header)

        # Parse payload
        data = json.loads(payload)

        # Handle URL verification challenge
        if data.get("type") == "url_verification":
            return {"challenge": data.get("challenge")}

        # Handle event callback
        if data.get("type") == "event_callback":
            event = data.get("event", {})
            event_type = event.get("type")

            handler = self.event_handlers.get(event_type)
            if handler:
                return await handler(event, data)

            logger.info("slack_unhandled_event", event_type=event_type)
            return {"ok": True}

        return {"ok": True}

    async def handle_message(self, event: dict, envelope: dict) -> dict:
        """Handle message events."""
        # Ignore bot messages to prevent loops
        if event.get("bot_id"):
            return {"ok": True, "ignored": "bot_message"}

        return {
            "ok": True,
            "action": "message_received",
            "channel": event.get("channel"),
            "user": event.get("user"),
            "ts": event.get("ts")
        }

    async def handle_app_mention(self, event: dict, envelope: dict) -> dict:
        """Handle @mentions of the app."""
        return {
            "ok": True,
            "action": "app_mentioned",
            "channel": event.get("channel"),
            "user": event.get("user"),
            "text": event.get("text")
        }

    async def handle_reaction_added(self, event: dict, envelope: dict) -> dict:
        """Handle reaction events."""
        return {
            "ok": True,
            "action": "reaction_added",
            "reaction": event.get("reaction"),
            "user": event.get("user"),
            "item": event.get("item")
        }

    async def handle_channel_created(self, event: dict, envelope: dict) -> dict:
        """Handle new channel creation."""
        channel = event.get("channel", {})
        return {
            "ok": True,
            "action": "channel_created",
            "channel_id": channel.get("id"),
            "channel_name": channel.get("name")
        }

    async def handle_member_joined(self, event: dict, envelope: dict) -> dict:
        """Handle user joining a channel."""
        return {
            "ok": True,
            "action": "member_joined",
            "user": event.get("user"),
            "channel": event.get("channel")
        }

    async def process_slash_command(self, form_data: dict) -> dict:
        """
        Process slash command.

        Slash commands are sent as form-encoded data.
        """
        command = form_data.get("command")
        text = form_data.get("text", "")
        user_id = form_data.get("user_id")
        channel_id = form_data.get("channel_id")

        return {
            "response_type": "in_channel",
            "text": f"Received command: {command} {text}",
            "blocks": [
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": f"*Command:* `{command}`\n*Args:* {text}"
                    }
                }
            ]
        }
```

### Twilio Integration

```python
# ============================================================================
# TWILIO WEBHOOK INTEGRATION
# ============================================================================

from urllib.parse import urlencode


class TwilioWebhookHandler:
    """
    Twilio webhook handler for SMS, voice, and WhatsApp.

    Handles callbacks for:
    - Incoming SMS/MMS
    - Incoming voice calls
    - Message status updates
    - WhatsApp messages
    """

    SIGNATURE_HEADER = "X-Twilio-Signature"

    def __init__(self, auth_token: str, account_sid: str, redis: Redis):
        self.auth_token = auth_token
        self.account_sid = account_sid
        self.redis = redis

    def verify_signature(
        self,
        url: str,
        params: dict,
        signature: str
    ) -> bool:
        """
        Verify Twilio request signature.

        Twilio uses URL + sorted params + auth token for signature.
        """
        # Build string to sign
        s = url
        if params:
            s += urlencode(sorted(params.items()))

        # Compute signature
        expected = base64.b64encode(
            hmac.new(
                self.auth_token.encode(),
                s.encode(),
                hashlib.sha1
            ).digest()
        ).decode()

        if not hmac.compare_digest(expected, signature):
            raise SignatureVerificationError("Invalid Twilio signature")

        return True

    async def handle_incoming_sms(self, params: dict) -> str:
        """
        Handle incoming SMS.

        Returns TwiML response.
        """
        from_number = params.get("From")
        to_number = params.get("To")
        body = params.get("Body", "")
        message_sid = params.get("MessageSid")

        logger.info(
            "twilio_sms_received",
            message_sid=message_sid,
            from_number=from_number[:6] + "****"  # Mask for privacy
        )

        # Return TwiML response
        return """<?xml version="1.0" encoding="UTF-8"?>
        <Response>
            <Message>Thanks for your message!</Message>
        </Response>"""

    async def handle_message_status(self, params: dict) -> dict:
        """Handle message status callback."""
        message_sid = params.get("MessageSid")
        status = params.get("MessageStatus")
        error_code = params.get("ErrorCode")

        return {
            "message_sid": message_sid,
            "status": status,
            "error_code": error_code
        }

    async def handle_incoming_call(self, params: dict) -> str:
        """
        Handle incoming voice call.

        Returns TwiML response.
        """
        from_number = params.get("From")
        call_sid = params.get("CallSid")

        logger.info(
            "twilio_call_received",
            call_sid=call_sid
        )

        return """<?xml version="1.0" encoding="UTF-8"?>
        <Response>
            <Say>Thank you for calling. Please leave a message after the beep.</Say>
            <Record maxLength="60" />
        </Response>"""
```

---

## Example Usage

```bash
# Implement Stripe webhook handler with full features
/agents/integration/webhook-expert implement Stripe payment webhook with idempotency and rate limiting

# Add GitHub webhook for CI/CD
/agents/integration/webhook-expert add GitHub webhook handler for push and PR events

# Create Slack bot webhook handler
/agents/integration/webhook-expert implement Slack Events API webhook with slash commands

# Review and improve existing webhook implementation
/agents/integration/webhook-expert review webhook handler at src/webhooks/ for security and performance

# Create comprehensive webhook test suite
/agents/integration/webhook-expert create webhook test suite covering signature verification, idempotency, and rate limiting

# Set up webhook monitoring and alerting
/agents/integration/webhook-expert configure Prometheus metrics and Grafana dashboard for webhook monitoring
```

---

## Deliverables

When invoked, this agent produces:

1. **Webhook Endpoint Implementation** - Complete handler code with routing
2. **Signature Verification Module** - Provider-specific verification (HMAC-SHA256, Ed25519)
3. **Idempotency Handler** - Redis or database-backed event deduplication
4. **Retry Queue System** - Exponential backoff with dead letter queue
5. **Rate Limiter** - Token bucket or sliding window implementation
6. **Event Queue** - Redis Streams or RabbitMQ integration
7. **Test Suite** - Unit, integration, and load tests
8. **Monitoring Configuration** - Prometheus metrics and Grafana dashboards
9. **OpenAPI Specification** - Webhook endpoint documentation
10. **Runbook** - Operations guide for incident response

---

## Integration with Other Agents

| Agent                                        | Integration                              |
| -------------------------------------------- | ---------------------------------------- |
| `/agents/integration/api-integration-expert` | API design, OpenAPI specs                |
| `/agents/security/security-expert`           | Security audit, vulnerability assessment |
| `/agents/database/redis-expert`              | Redis optimization, Lua scripts          |
| `/agents/testing/integration-test-expert`    | Test strategy, mocking                   |
| `/agents/devops/monitoring-expert`           | Metrics, alerting, dashboards            |

---

## References

- [Stripe Webhook Best Practices](https://stripe.com/docs/webhooks/best-practices)
- [GitHub Webhook Security](https://docs.github.com/en/webhooks/using-webhooks/best-practices-for-using-webhooks)
- [Slack Events API](https://api.slack.com/apis/connections/events-api)
- [Twilio Request Validation](https://www.twilio.com/docs/usage/webhooks/webhooks-security)
- [Svix Webhook Guide](https://docs.svix.com/receiving/introduction)
- [OWASP API Security](https://owasp.org/API-Security/)

---

Ahmed Adel Bakr Alderai
