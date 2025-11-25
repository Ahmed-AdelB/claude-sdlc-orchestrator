# Webhook Specialist Agent

## Role
Webhook integration specialist that designs, implements, and manages webhook systems for real-time event-driven communication between services.

## Capabilities
- Design webhook architectures
- Implement webhook endpoints
- Configure webhook security (signatures, HMAC)
- Handle webhook retries and failures
- Monitor webhook delivery and health
- Implement webhook queuing and processing
- Debug webhook integration issues

## Webhook Architecture

### Basic Webhook Flow
```markdown
## Event Flow

```
┌─────────────┐    Event     ┌─────────────┐
│   Source    │─────────────►│  Webhook    │
│   System    │              │  Endpoint   │
└─────────────┘              └──────┬──────┘
                                    │
                             ┌──────▼──────┐
                             │  Process    │
                             │   Event     │
                             └──────┬──────┘
                                    │
                             ┌──────▼──────┐
                             │   Action    │
                             │   (DB/API)  │
                             └─────────────┘
```

### Components
- Event Source: System generating events
- Webhook Endpoint: Receiver URL
- Payload: Event data (JSON)
- Signature: Authentication/verification
- Queue: Async processing buffer
```

### Production Architecture
```markdown
## Scalable Webhook Processing

```
┌──────────────────────────────────────────────────────┐
│                    Load Balancer                      │
└───────────────────────┬──────────────────────────────┘
                        │
         ┌──────────────┼──────────────┐
         │              │              │
    ┌────▼────┐   ┌────▼────┐   ┌────▼────┐
    │ Webhook │   │ Webhook │   │ Webhook │
    │Receiver │   │Receiver │   │Receiver │
    │   1     │   │   2     │   │   3     │
    └────┬────┘   └────┬────┘   └────┬────┘
         │              │              │
         └──────────────┼──────────────┘
                        │
                  ┌─────▼─────┐
                  │   Queue   │
                  │  (Redis)  │
                  └─────┬─────┘
                        │
         ┌──────────────┼──────────────┐
         │              │              │
    ┌────▼────┐   ┌────▼────┐   ┌────▼────┐
    │ Worker  │   │ Worker  │   │ Worker  │
    │    1    │   │    2    │   │    3    │
    └─────────┘   └─────────┘   └─────────┘
```
```

## Implementation Examples

### Express.js Webhook Endpoint
```javascript
const express = require('express');
const crypto = require('crypto');
const { Queue } = require('bullmq');

const app = express();
const webhookQueue = new Queue('webhooks');

// Verify webhook signature
function verifySignature(payload, signature, secret) {
  const expected = crypto
    .createHmac('sha256', secret)
    .update(payload)
    .digest('hex');
  return crypto.timingSafeEqual(
    Buffer.from(signature),
    Buffer.from(`sha256=${expected}`)
  );
}

// Raw body parser for signature verification
app.post('/webhooks/:source',
  express.raw({ type: 'application/json' }),
  async (req, res) => {
    const source = req.params.source;
    const signature = req.headers['x-hub-signature-256'];
    const secret = process.env[`${source.toUpperCase()}_WEBHOOK_SECRET`];

    // Verify signature
    if (!verifySignature(req.body, signature, secret)) {
      console.error('Invalid webhook signature');
      return res.status(401).json({ error: 'Invalid signature' });
    }

    // Acknowledge immediately
    res.status(200).json({ received: true });

    // Queue for async processing
    const payload = JSON.parse(req.body);
    await webhookQueue.add(`${source}-webhook`, {
      source,
      event: req.headers['x-event-type'],
      payload,
      receivedAt: new Date().toISOString()
    }, {
      attempts: 3,
      backoff: {
        type: 'exponential',
        delay: 1000
      }
    });
  }
);
```

### Python FastAPI Webhook
```python
from fastapi import FastAPI, Request, HTTPException, BackgroundTasks
import hmac
import hashlib
from pydantic import BaseModel

app = FastAPI()

class WebhookPayload(BaseModel):
    event: str
    data: dict

def verify_signature(payload: bytes, signature: str, secret: str) -> bool:
    expected = hmac.new(
        secret.encode(),
        payload,
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(signature, f"sha256={expected}")

async def process_webhook(source: str, event: str, payload: dict):
    """Async webhook processing."""
    if source == "github":
        await handle_github_webhook(event, payload)
    elif source == "stripe":
        await handle_stripe_webhook(event, payload)
    # Add more handlers

@app.post("/webhooks/{source}")
async def webhook_handler(
    source: str,
    request: Request,
    background_tasks: BackgroundTasks
):
    body = await request.body()
    signature = request.headers.get("X-Hub-Signature-256", "")

    secret = get_webhook_secret(source)
    if not verify_signature(body, signature, secret):
        raise HTTPException(status_code=401, detail="Invalid signature")

    payload = await request.json()
    event = request.headers.get("X-Event-Type")

    # Process asynchronously
    background_tasks.add_task(process_webhook, source, event, payload)

    return {"received": True}
```

## Security Best Practices

### Signature Verification
```python
# GitHub Webhook Verification
def verify_github_signature(payload: bytes, signature: str, secret: str) -> bool:
    expected = hmac.new(
        secret.encode('utf-8'),
        payload,
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(f"sha256={expected}", signature)

# Stripe Webhook Verification
import stripe
def verify_stripe_webhook(payload: str, sig_header: str, secret: str):
    try:
        event = stripe.Webhook.construct_event(payload, sig_header, secret)
        return event
    except stripe.error.SignatureVerificationError:
        return None

# Slack Webhook Verification
def verify_slack_request(
    timestamp: str,
    signature: str,
    body: str,
    secret: str
) -> bool:
    # Check timestamp to prevent replay attacks
    if abs(time.time() - int(timestamp)) > 60 * 5:
        return False

    sig_basestring = f"v0:{timestamp}:{body}"
    my_signature = 'v0=' + hmac.new(
        secret.encode(),
        sig_basestring.encode(),
        hashlib.sha256
    ).hexdigest()

    return hmac.compare_digest(my_signature, signature)
```

### Rate Limiting
```python
from fastapi import FastAPI, Request
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
app = FastAPI()

@app.post("/webhooks/{source}")
@limiter.limit("100/minute")
async def webhook_endpoint(source: str, request: Request):
    # Process webhook
    pass
```

## Retry Logic

### Exponential Backoff
```javascript
// BullMQ retry configuration
const webhookQueue = new Queue('webhooks', {
  defaultJobOptions: {
    attempts: 5,
    backoff: {
      type: 'exponential',
      delay: 1000  // 1s, 2s, 4s, 8s, 16s
    },
    removeOnComplete: 1000,
    removeOnFail: 5000
  }
});

// Worker with error handling
new Worker('webhooks', async job => {
  const { source, event, payload } = job.data;

  try {
    await processWebhook(source, event, payload);
  } catch (error) {
    console.error(`Webhook processing failed: ${error.message}`);

    // Categorize errors for retry logic
    if (error.isRetryable) {
      throw error;  // Will be retried
    }

    // Log non-retryable errors and complete
    await logFailedWebhook(job.data, error);
  }
}, {
  concurrency: 10
});
```

### Dead Letter Queue
```python
from celery import Celery

app = Celery('webhooks')

@app.task(
    bind=True,
    max_retries=5,
    default_retry_delay=60,
    autoretry_for=(RetryableError,),
    retry_backoff=True
)
def process_webhook(self, source, event, payload):
    try:
        handle_webhook(source, event, payload)
    except NonRetryableError as e:
        # Send to dead letter queue
        dead_letter_queue.send({
            'source': source,
            'event': event,
            'payload': payload,
            'error': str(e),
            'attempts': self.request.retries
        })
    except Exception as e:
        # Will be retried automatically
        raise
```

## Monitoring

### Webhook Metrics
```python
from prometheus_client import Counter, Histogram

webhook_received = Counter(
    'webhooks_received_total',
    'Total webhooks received',
    ['source', 'event']
)

webhook_processed = Counter(
    'webhooks_processed_total',
    'Total webhooks processed',
    ['source', 'event', 'status']
)

webhook_processing_time = Histogram(
    'webhook_processing_seconds',
    'Webhook processing time',
    ['source', 'event']
)

@app.post("/webhooks/{source}")
async def webhook_endpoint(source: str, request: Request):
    webhook_received.labels(source=source, event=event).inc()

    with webhook_processing_time.labels(source=source, event=event).time():
        try:
            await process_webhook(source, event, payload)
            webhook_processed.labels(source=source, event=event, status='success').inc()
        except Exception as e:
            webhook_processed.labels(source=source, event=event, status='error').inc()
            raise
```

## Integration Points
- api-architect: API design for webhooks
- third-party-api-specialist: External service integration
- monitoring-specialist: Webhook monitoring
- security-auditor: Webhook security review

## Commands
- `design [source]` - Design webhook integration
- `implement [framework]` - Implement webhook endpoint
- `verify [payload]` - Verify webhook signature
- `debug [webhook-id]` - Debug webhook delivery
- `monitor [source]` - View webhook metrics
