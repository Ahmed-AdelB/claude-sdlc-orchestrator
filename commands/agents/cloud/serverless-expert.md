---
name: serverless-expert
description: Multi-cloud serverless architecture specialist for Lambda, Cloud Functions, Azure Functions, with expertise in cold start optimization, event-driven design, workflow orchestration, and serverless database patterns
version: 2.0.0
author: Ahmed Adel Bakr Alderai
category: cloud
tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
integrations:
  - aws-expert
  - gcp-expert
  - azure-expert
  - terraform-expert
triggers:
  - serverless
  - lambda
  - cloud-functions
  - cloud-run
  - azure-functions
  - sam
  - serverless-framework
  - cold-start
  - event-driven
  - step-functions
  - workflows
  - faas
---

# Serverless Expert Agent

Multi-cloud serverless architecture specialist with deep expertise in AWS Lambda, Google Cloud Functions, Cloud Run, and Azure Functions. Provides guidance on event-driven architecture design, cold start optimization, connection pooling, IaC templates, workflow orchestration, cost optimization, and serverless observability.

## Core Expertise

| Domain               | Technologies                                                |
| -------------------- | ----------------------------------------------------------- |
| **AWS Serverless**   | Lambda, API Gateway, Step Functions, EventBridge, SQS, SNS  |
| **GCP Serverless**   | Cloud Functions, Cloud Run, Pub/Sub, Eventarc, Workflows    |
| **Azure Serverless** | Azure Functions, Logic Apps, Event Grid, Service Bus        |
| **Frameworks**       | Serverless Framework, AWS SAM, AWS CDK, Pulumi, Terraform   |
| **Databases**        | DynamoDB, Firestore, Aurora Serverless, Cosmos DB           |
| **Patterns**         | CQRS, Event Sourcing, Saga, Fan-out/Fan-in, Circuit Breaker |

## Arguments

- `$ARGUMENTS` - Serverless task description

## Invoke Agent

```
Use the Task tool to:

1. Design serverless architecture for the given requirements
2. Implement Lambda/Cloud Functions/Azure Functions
3. Configure API Gateway and event triggers
4. Optimize for cold starts and performance
5. Implement serverless database patterns
6. Create IaC templates (SAM, Serverless Framework, CDK)
7. Design Step Functions and workflow orchestration
8. Implement cost optimization strategies
9. Set up monitoring and observability

Task: $ARGUMENTS
```

---

## AWS Lambda Best Practices and Patterns

### Basic Lambda Handler (TypeScript)

```typescript
import { APIGatewayProxyHandler, APIGatewayProxyResult } from "aws-lambda";

// Cold start optimization: Initialize outside handler
const dbClient = initializeDbClient();

export const handler: APIGatewayProxyHandler = async (
  event,
): Promise<APIGatewayProxyResult> => {
  const requestId = event.requestContext.requestId;

  try {
    // Input validation
    const body = JSON.parse(event.body || "{}");
    const validated = validateInput(body);

    // Business logic
    const result = await processRequest(validated, dbClient);

    return {
      statusCode: 200,
      headers: {
        "Content-Type": "application/json",
        "X-Request-Id": requestId,
      },
      body: JSON.stringify({ data: result }),
    };
  } catch (error) {
    console.error("Handler error:", { requestId, error });

    if (error instanceof ValidationError) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: error.message }),
      };
    }

    return {
      statusCode: 500,
      body: JSON.stringify({ error: "Internal server error" }),
    };
  }
};

function initializeDbClient() {
  // Reuse connections across invocations
  return new DynamoDBClient({
    maxAttempts: 3,
    requestHandler: new NodeHttpHandler({
      connectionTimeout: 3000,
      socketTimeout: 3000,
    }),
  });
}
```

### Lambda with Powertools (Python)

```python
from aws_lambda_powertools import Logger, Tracer, Metrics
from aws_lambda_powertools.event_handler import APIGatewayRestResolver
from aws_lambda_powertools.logging import correlation_paths
from aws_lambda_powertools.utilities.typing import LambdaContext
import boto3
import os
import uuid
from datetime import datetime

logger = Logger()
tracer = Tracer()
metrics = Metrics()
app = APIGatewayRestResolver()

# Cold start: Initialize outside handler
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])

@app.post("/items")
@tracer.capture_method
def create_item():
    body = app.current_event.json_body

    # Validation
    if not body.get('name'):
        raise BadRequestError("name is required")

    item = {
        'id': str(uuid.uuid4()),
        'name': body['name'],
        'created_at': datetime.utcnow().isoformat(),
    }

    table.put_item(Item=item)
    metrics.add_metric(name="ItemsCreated", unit="Count", value=1)

    return {"item": item}

@logger.inject_lambda_context(correlation_id_path=correlation_paths.API_GATEWAY_REST)
@tracer.capture_lambda_handler
@metrics.log_metrics(capture_cold_start_metric=True)
def handler(event: dict, context: LambdaContext) -> dict:
    return app.resolve(event, context)
```

### Lambda Best Practices Checklist

| Practice                       | Description                                        | Impact                                 |
| ------------------------------ | -------------------------------------------------- | -------------------------------------- |
| **Initialize outside handler** | Create SDK clients, DB connections at module level | Reduces cold start by 50-80%           |
| **Use ARM64 architecture**     | Graviton2 processors                               | 20% cost reduction, better performance |
| **Right-size memory**          | Profile with Lambda Power Tuning                   | Optimal cost/performance ratio         |
| **Use Powertools**             | Structured logging, tracing, metrics               | Production-ready observability         |
| **Enable X-Ray tracing**       | Distributed tracing                                | End-to-end visibility                  |
| **Set appropriate timeout**    | Close to P99 latency + buffer                      | Prevents runaway costs                 |
| **Use reserved concurrency**   | Limit concurrent executions                        | Cost control, downstream protection    |

---

## Step Functions and Workflow Orchestration

### Step Functions State Machine (ASL)

```json
{
  "Comment": "Order Processing Workflow with Saga Pattern",
  "StartAt": "ValidateOrder",
  "States": {
    "ValidateOrder": {
      "Type": "Task",
      "Resource": "${ValidateOrderFunctionArn}",
      "Next": "CheckInventory",
      "Catch": [
        {
          "ErrorEquals": ["ValidationError"],
          "Next": "OrderFailed"
        }
      ],
      "Retry": [
        {
          "ErrorEquals": ["States.TaskFailed"],
          "IntervalSeconds": 2,
          "MaxAttempts": 3,
          "BackoffRate": 2
        }
      ]
    },
    "CheckInventory": {
      "Type": "Task",
      "Resource": "${CheckInventoryFunctionArn}",
      "Next": "ProcessPayment",
      "Catch": [
        {
          "ErrorEquals": ["InsufficientInventory"],
          "Next": "OrderFailed"
        }
      ]
    },
    "ProcessPayment": {
      "Type": "Task",
      "Resource": "${ProcessPaymentFunctionArn}",
      "Next": "FulfillOrder",
      "Catch": [
        {
          "ErrorEquals": ["PaymentFailed"],
          "Next": "RefundAndFail"
        }
      ]
    },
    "FulfillOrder": {
      "Type": "Parallel",
      "Branches": [
        {
          "StartAt": "UpdateInventory",
          "States": {
            "UpdateInventory": {
              "Type": "Task",
              "Resource": "${UpdateInventoryFunctionArn}",
              "End": true
            }
          }
        },
        {
          "StartAt": "SendConfirmation",
          "States": {
            "SendConfirmation": {
              "Type": "Task",
              "Resource": "${SendConfirmationFunctionArn}",
              "End": true
            }
          }
        }
      ],
      "Next": "OrderComplete"
    },
    "OrderComplete": {
      "Type": "Succeed"
    },
    "RefundAndFail": {
      "Type": "Task",
      "Resource": "${RefundFunctionArn}",
      "Next": "OrderFailed"
    },
    "OrderFailed": {
      "Type": "Fail",
      "Error": "OrderProcessingFailed",
      "Cause": "Order could not be processed"
    }
  }
}
```

### GCP Workflows

```yaml
main:
  params: [input]
  steps:
    - init:
        assign:
          - project_id: ${sys.get_env("GOOGLE_CLOUD_PROJECT_ID")}
          - order_id: ${input.order_id}

    - validate_order:
        call: http.post
        args:
          url: ${"https://" + project_id + "-validate.cloudfunctions.net/validate"}
          body:
            order_id: ${order_id}
        result: validation_result

    - check_validation:
        switch:
          - condition: ${validation_result.body.valid == false}
            raise: ${validation_result.body.error}

    - process_payment:
        call: http.post
        args:
          url: ${"https://" + project_id + "-payment.cloudfunctions.net/process"}
          body:
            order_id: ${order_id}
            amount: ${validation_result.body.total}
        result: payment_result

    - parallel_fulfillment:
        parallel:
          branches:
            - update_inventory:
                call: http.post
                args:
                  url: ${"https://" + project_id + "-inventory.cloudfunctions.net/update"}
                  body:
                    order_id: ${order_id}
            - send_notification:
                call: http.post
                args:
                  url: ${"https://" + project_id + "-notify.cloudfunctions.net/send"}
                  body:
                    order_id: ${order_id}

    - return_success:
        return:
          status: "completed"
          order_id: ${order_id}
```

### Azure Durable Functions Orchestrator

```typescript
import * as df from "durable-functions";
import { OrchestrationContext, OrchestrationHandler } from "durable-functions";

const orderOrchestrator: OrchestrationHandler = function* (
  context: OrchestrationContext,
) {
  const order = context.df.getInput();
  const outputs = [];

  try {
    // Step 1: Validate order
    const validationResult = yield context.df.callActivity(
      "ValidateOrder",
      order,
    );
    outputs.push({ step: "validation", result: validationResult });

    // Step 2: Reserve inventory (with retry)
    const retryOptions = new df.RetryOptions(5000, 3);
    retryOptions.backoffCoefficient = 2;

    const inventoryResult = yield context.df.callActivityWithRetry(
      "ReserveInventory",
      retryOptions,
      order,
    );
    outputs.push({ step: "inventory", result: inventoryResult });

    // Step 3: Process payment
    const paymentResult = yield context.df.callActivity(
      "ProcessPayment",
      order,
    );
    outputs.push({ step: "payment", result: paymentResult });

    // Step 4: Parallel fulfillment tasks
    const parallelTasks = [
      context.df.callActivity("UpdateOrderStatus", {
        orderId: order.id,
        status: "completed",
      }),
      context.df.callActivity("SendConfirmationEmail", order),
      context.df.callActivity("NotifyWarehouse", order),
    ];

    const parallelResults = yield context.df.Task.all(parallelTasks);
    outputs.push({ step: "fulfillment", result: parallelResults });

    return { success: true, outputs };
  } catch (error) {
    // Compensation logic (Saga pattern)
    yield context.df.callActivity("CompensateOrder", {
      orderId: order.id,
      completedSteps: outputs,
      error: error.message,
    });

    throw error;
  }
};

df.app.orchestration("OrderOrchestrator", orderOrchestrator);
```

---

## Google Cloud Functions and Cloud Run

### HTTP Cloud Function (TypeScript)

```typescript
import { HttpFunction } from "@google-cloud/functions-framework";
import { Firestore } from "@google-cloud/firestore";

// Cold start optimization
const firestore = new Firestore();
const collection = firestore.collection("items");

export const httpHandler: HttpFunction = async (req, res) => {
  const traceId = req.header("X-Cloud-Trace-Context")?.split("/")[0];

  // CORS handling
  res.set("Access-Control-Allow-Origin", process.env.ALLOWED_ORIGIN || "*");

  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
    res.status(204).send("");
    return;
  }

  try {
    switch (req.method) {
      case "GET":
        const snapshot = await collection.limit(100).get();
        const items = snapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));
        res.json({ items, traceId });
        break;

      case "POST":
        const data = req.body;
        if (!data.name) {
          res.status(400).json({ error: "name is required" });
          return;
        }
        const docRef = await collection.add({
          ...data,
          createdAt: Firestore.Timestamp.now(),
        });
        res.status(201).json({ id: docRef.id, traceId });
        break;

      default:
        res.status(405).json({ error: "Method not allowed" });
    }
  } catch (error) {
    console.error("Function error:", { traceId, error });
    res.status(500).json({ error: "Internal server error", traceId });
  }
};
```

### Pub/Sub Cloud Function (Python)

```python
import base64
import json
import os
import functions_framework
from google.cloud import firestore
from google.cloud import pubsub_v1

# Cold start optimization
db = firestore.Client()
publisher = pubsub_v1.PublisherClient()
PROJECT_ID = os.environ.get('GOOGLE_CLOUD_PROJECT')

@functions_framework.cloud_event
def process_pubsub_message(cloud_event):
    """Process Pub/Sub message for event-driven architecture."""

    # Decode message
    message_data = base64.b64decode(cloud_event.data["message"]["data"]).decode()
    message = json.loads(message_data)

    event_type = message.get('event_type')
    payload = message.get('payload', {})

    print(f"Processing event: {event_type}")

    try:
        if event_type == 'order.created':
            handle_order_created(payload)
        elif event_type == 'order.shipped':
            handle_order_shipped(payload)
        else:
            print(f"Unknown event type: {event_type}")

    except Exception as e:
        print(f"Error processing message: {e}")
        # Publish to dead letter topic
        dlq_topic = f"projects/{PROJECT_ID}/topics/events-dlq"
        publisher.publish(dlq_topic, json.dumps({
            'original_message': message,
            'error': str(e),
        }).encode())
        raise

def handle_order_created(payload):
    order_id = payload['order_id']
    db.collection('orders').document(order_id).set({
        'status': 'processing',
        'updated_at': firestore.SERVER_TIMESTAMP,
    }, merge=True)

    # Publish downstream event
    topic = f"projects/{PROJECT_ID}/topics/inventory-updates"
    publisher.publish(topic, json.dumps({
        'event_type': 'inventory.reserve',
        'payload': {'order_id': order_id, 'items': payload['items']},
    }).encode())

def handle_order_shipped(payload):
    order_id = payload['order_id']
    db.collection('orders').document(order_id).set({
        'status': 'shipped',
        'shipped_at': firestore.SERVER_TIMESTAMP,
    }, merge=True)
```

### Cloud Run Service (Dockerfile + TypeScript)

```dockerfile
# Dockerfile for Cloud Run
FROM node:20-slim AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

FROM node:20-slim
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY package*.json ./

# Cloud Run sets PORT environment variable
ENV PORT=8080
EXPOSE 8080

# Run as non-root user
USER node

CMD ["node", "dist/server.js"]
```

```typescript
// server.ts for Cloud Run
import express from "express";
import { Firestore } from "@google-cloud/firestore";

const app = express();
const firestore = new Firestore();

app.use(express.json());

// Health check for Cloud Run
app.get("/health", (req, res) => {
  res.status(200).json({ status: "healthy" });
});

app.get("/items", async (req, res) => {
  try {
    const snapshot = await firestore.collection("items").limit(100).get();
    const items = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    res.json({ items });
  } catch (error) {
    console.error("Error fetching items:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

---

## Azure Functions Patterns

### HTTP Trigger (TypeScript)

```typescript
import { AzureFunction, Context, HttpRequest } from "@azure/functions";
import { CosmosClient } from "@azure/cosmos";

// Cold start optimization
const cosmosClient = new CosmosClient(process.env.COSMOS_CONNECTION_STRING!);
const container = cosmosClient.database("mydb").container("items");

const httpTrigger: AzureFunction = async (
  context: Context,
  req: HttpRequest,
): Promise<void> => {
  const invocationId = context.invocationId;
  context.log(`Processing request: ${invocationId}`);

  try {
    switch (req.method) {
      case "GET":
        const { resources } = await container.items
          .query("SELECT * FROM c ORDER BY c._ts DESC OFFSET 0 LIMIT 100")
          .fetchAll();

        context.res = {
          status: 200,
          body: { items: resources, invocationId },
          headers: { "Content-Type": "application/json" },
        };
        break;

      case "POST":
        const body = req.body;
        if (!body?.name) {
          context.res = { status: 400, body: { error: "name is required" } };
          return;
        }

        const newItem = {
          id: crypto.randomUUID(),
          ...body,
          createdAt: new Date().toISOString(),
        };

        await container.items.create(newItem);

        context.res = {
          status: 201,
          body: { item: newItem, invocationId },
          headers: { "Content-Type": "application/json" },
        };
        break;

      default:
        context.res = { status: 405, body: { error: "Method not allowed" } };
    }
  } catch (error) {
    context.log.error("Function error:", error);
    context.res = {
      status: 500,
      body: { error: "Internal server error", invocationId },
    };
  }
};

export default httpTrigger;
```

### Event Grid Trigger (Python)

```python
import azure.functions as func
import json
import logging
from azure.cosmos import CosmosClient
import os

# Cold start optimization
cosmos_client = CosmosClient.from_connection_string(
    os.environ['COSMOS_CONNECTION_STRING']
)
database = cosmos_client.get_database_client('mydb')
container = database.get_container_client('events')

def main(event: func.EventGridEvent):
    logging.info(f"Event Grid trigger: {event.id}")

    event_data = event.get_json()
    event_type = event.event_type

    try:
        # Store event for audit trail
        container.create_item({
            'id': event.id,
            'event_type': event_type,
            'subject': event.subject,
            'data': event_data,
            'event_time': str(event.event_time),
            'processed_at': datetime.utcnow().isoformat(),
        })

        # Route to appropriate handler
        if event_type == 'Microsoft.Storage.BlobCreated':
            handle_blob_created(event_data)
        elif event_type == 'Custom.Order.Created':
            handle_order_created(event_data)
        else:
            logging.warning(f"Unhandled event type: {event_type}")

    except Exception as e:
        logging.error(f"Error processing event: {e}")
        raise

def handle_blob_created(data):
    blob_url = data.get('url')
    logging.info(f"Processing new blob: {blob_url}")
    # Process blob...

def handle_order_created(data):
    order_id = data.get('order_id')
    logging.info(f"Processing new order: {order_id}")
    # Process order...
```

---

## Event-Driven Architecture Design

### Fan-Out Pattern

```
                    +-> Lambda A -> DynamoDB
                    |
SNS Topic -> Filter +-> Lambda B -> S3
                    |
                    +-> Lambda C -> SQS -> Lambda D
```

```yaml
# CloudFormation for Fan-Out
OrderCreatedTopic:
  Type: AWS::SNS::Topic

ProcessPaymentSubscription:
  Type: AWS::SNS::Subscription
  Properties:
    TopicArn: !Ref OrderCreatedTopic
    Protocol: lambda
    Endpoint: !GetAtt ProcessPaymentFunction.Arn
    FilterPolicy:
      order_type:
        - paid
        - subscription

UpdateInventorySubscription:
  Type: AWS::SNS::Subscription
  Properties:
    TopicArn: !Ref OrderCreatedTopic
    Protocol: lambda
    Endpoint: !GetAtt UpdateInventoryFunction.Arn

NotifyCustomerSubscription:
  Type: AWS::SNS::Subscription
  Properties:
    TopicArn: !Ref OrderCreatedTopic
    Protocol: lambda
    Endpoint: !GetAtt NotifyCustomerFunction.Arn
```

### EventBridge Pattern

```typescript
// Event publisher
import {
  EventBridgeClient,
  PutEventsCommand,
} from "@aws-sdk/client-eventbridge";

const eventBridge = new EventBridgeClient({});

export async function publishEvent(
  eventType: string,
  detail: object,
): Promise<void> {
  const command = new PutEventsCommand({
    Entries: [
      {
        Source: "my.application",
        DetailType: eventType,
        Detail: JSON.stringify(detail),
        EventBusName: process.env.EVENT_BUS_NAME,
      },
    ],
  });

  await eventBridge.send(command);
}

// Usage
await publishEvent("OrderCreated", {
  orderId: "12345",
  customerId: "cust-001",
  total: 99.99,
  items: [{ sku: "ABC123", qty: 2 }],
});
```

```yaml
# EventBridge Rule with pattern matching
OrderProcessingRule:
  Type: AWS::Events::Rule
  Properties:
    EventBusName: !Ref ApplicationEventBus
    EventPattern:
      source:
        - my.application
      detail-type:
        - OrderCreated
      detail:
        total:
          - numeric: [">", 100]
    Targets:
      - Id: HighValueOrderProcessor
        Arn: !GetAtt HighValueOrderFunction.Arn
        InputTransformer:
          InputPathsMap:
            orderId: "$.detail.orderId"
            total: "$.detail.total"
          InputTemplate: '{"orderId": <orderId>, "total": <total>, "priority": "high"}'
```

### Saga Pattern (Distributed Transactions)

```typescript
// Saga orchestrator using Step Functions
interface SagaStep {
  name: string;
  action: (context: SagaContext) => Promise<void>;
  compensate: (context: SagaContext) => Promise<void>;
}

interface SagaContext {
  order: Order;
  completedSteps: string[];
  inventoryReservationId?: string;
  paymentId?: string;
  shipmentId?: string;
}

class OrderSaga {
  private steps: SagaStep[] = [
    {
      name: "reserveInventory",
      action: async (ctx) => {
        ctx.inventoryReservationId = await inventoryService.reserve(
          ctx.order.items,
        );
      },
      compensate: async (ctx) => {
        if (ctx.inventoryReservationId) {
          await inventoryService.release(ctx.inventoryReservationId);
        }
      },
    },
    {
      name: "processPayment",
      action: async (ctx) => {
        ctx.paymentId = await paymentService.charge(
          ctx.order.customerId,
          ctx.order.total,
        );
      },
      compensate: async (ctx) => {
        if (ctx.paymentId) {
          await paymentService.refund(ctx.paymentId);
        }
      },
    },
    {
      name: "createShipment",
      action: async (ctx) => {
        ctx.shipmentId = await shippingService.create(ctx.order);
      },
      compensate: async (ctx) => {
        if (ctx.shipmentId) {
          await shippingService.cancel(ctx.shipmentId);
        }
      },
    },
  ];

  async execute(order: Order): Promise<SagaResult> {
    const context: SagaContext = { order, completedSteps: [] };

    for (const step of this.steps) {
      try {
        await step.action(context);
        context.completedSteps.push(step.name);
      } catch (error) {
        console.error(`Saga step ${step.name} failed:`, error);
        await this.compensate(context);
        throw new SagaFailedError(step.name, error);
      }
    }

    return { success: true, context };
  }

  private async compensate(context: SagaContext): Promise<void> {
    // Compensate in reverse order
    for (const stepName of context.completedSteps.reverse()) {
      const step = this.steps.find((s) => s.name === stepName);
      if (step) {
        try {
          await step.compensate(context);
        } catch (error) {
          console.error(`Compensation for ${stepName} failed:`, error);
          // Log for manual intervention
        }
      }
    }
  }
}
```

---

## Cold Start Optimization

### Optimization Strategies

| Strategy                    | Impact                       | Implementation                               |
| --------------------------- | ---------------------------- | -------------------------------------------- |
| **Provisioned Concurrency** | Eliminates cold starts       | Set PC = expected peak concurrent executions |
| **ARM64 Architecture**      | 34% better price-performance | Use Graviton2 processors                     |
| **Smaller Package Size**    | Faster download/extract      | Tree-shaking, exclude dev deps, use layers   |
| **Keep-Alive Connections**  | Reduce connection overhead   | Reuse HTTP/DB connections                    |
| **Lazy Loading**            | Defer non-critical init      | Import expensive modules only when needed    |
| **SnapStart (Java)**        | ~90% reduction               | Enable for Java 11+ runtimes                 |

### Cold Start Comparison by Runtime

| Runtime             | Avg Cold Start | Optimized |
| ------------------- | -------------- | --------- |
| Node.js 20.x        | 200-500ms      | 100-200ms |
| Python 3.12         | 200-400ms      | 100-200ms |
| Java 21 (SnapStart) | 100-200ms      | 50-100ms  |
| Go 1.x              | 50-100ms       | 30-50ms   |
| Rust                | 10-50ms        | 5-20ms    |

### Code-Level Optimizations

```typescript
// BEFORE: Cold start ~800ms - all clients initialized on import
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient } from "@aws-sdk/lib-dynamodb";
import { S3Client } from "@aws-sdk/client-s3";
import { SQSClient } from "@aws-sdk/client-sqs";
import { SNSClient } from "@aws-sdk/client-sns";

// AFTER: Cold start ~200ms - lazy initialization
let dynamoClient: DynamoDBDocumentClient | null = null;
let s3Client: S3Client | null = null;

function getDynamoClient(): DynamoDBDocumentClient {
  if (!dynamoClient) {
    dynamoClient = DynamoDBDocumentClient.from(
      new DynamoDBClient({
        maxAttempts: 3,
      }),
      {
        marshallOptions: { removeUndefinedValues: true },
      },
    );
  }
  return dynamoClient;
}

function getS3Client(): S3Client {
  if (!s3Client) {
    s3Client = new S3Client({ maxAttempts: 3 });
  }
  return s3Client;
}

// Only initialize what's needed for each handler
export const dynamoHandler = async (event: any) => {
  const client = getDynamoClient(); // Initialized only when called
  // ... handler logic
};
```

### Provisioned Concurrency Configuration

```yaml
# SAM template
MyFunction:
  Type: AWS::Serverless::Function
  Properties:
    AutoPublishAlias: live
    ProvisionedConcurrencyConfig:
      ProvisionedConcurrentExecutions: 10
    DeploymentPreference:
      Type: AllAtOnce

# Application Auto Scaling for PC
ProvisionedConcurrencyScaling:
  Type: AWS::ApplicationAutoScaling::ScalableTarget
  Properties:
    ServiceNamespace: lambda
    ScalableDimension: lambda:function:ProvisionedConcurrency
    ResourceId: !Sub "function:${MyFunction}:live"
    MinCapacity: 5
    MaxCapacity: 100

ProvisionedConcurrencyScalingPolicy:
  Type: AWS::ApplicationAutoScaling::ScalingPolicy
  Properties:
    PolicyName: PCUtilizationPolicy
    PolicyType: TargetTrackingScaling
    ScalingTargetId: !Ref ProvisionedConcurrencyScaling
    TargetTrackingScalingPolicyConfiguration:
      TargetValue: 70
      PredefinedMetricSpecification:
        PredefinedMetricType: LambdaProvisionedConcurrencyUtilization
```

---

## Connection Pooling for Databases

### RDS Proxy for Lambda

```yaml
# SAM template with RDS Proxy
RDSProxy:
  Type: AWS::RDS::DBProxy
  Properties:
    DBProxyName: my-lambda-proxy
    EngineFamily: POSTGRESQL
    Auth:
      - AuthScheme: SECRETS
        SecretArn: !Ref DatabaseSecret
        IAMAuth: REQUIRED
    RoleArn: !GetAtt RDSProxyRole.Arn
    VpcSubnetIds:
      - !Ref PrivateSubnet1
      - !Ref PrivateSubnet2
    VpcSecurityGroupIds:
      - !Ref ProxySecurityGroup

RDSProxyTargetGroup:
  Type: AWS::RDS::DBProxyTargetGroup
  Properties:
    DBProxyName: !Ref RDSProxy
    TargetGroupName: default
    DBInstanceIdentifiers:
      - !Ref DatabaseInstance
    ConnectionPoolConfig:
      MaxConnectionsPercent: 100
      MaxIdleConnectionsPercent: 50
      ConnectionBorrowTimeout: 120
```

### Connection Pooling Pattern (TypeScript)

```typescript
import { Pool, PoolClient } from "pg";

// Global connection pool - reused across invocations
let pool: Pool | null = null;

function getPool(): Pool {
  if (!pool) {
    pool = new Pool({
      host: process.env.DB_HOST, // RDS Proxy endpoint
      port: parseInt(process.env.DB_PORT || "5432"),
      database: process.env.DB_NAME,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      max: 1, // Lambda: single connection per instance
      idleTimeoutMillis: 60000,
      connectionTimeoutMillis: 5000,
      ssl: { rejectUnauthorized: false },
    });

    // Handle pool errors
    pool.on("error", (err) => {
      console.error("Unexpected pool error:", err);
      pool = null;
    });
  }
  return pool;
}

export const handler = async (event: any) => {
  const client: PoolClient = await getPool().connect();

  try {
    const result = await client.query("SELECT * FROM items WHERE id = $1", [
      event.itemId,
    ]);
    return { statusCode: 200, body: JSON.stringify(result.rows) };
  } finally {
    client.release(); // Return connection to pool
  }
};
```

### DynamoDB Connection Reuse

```typescript
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, GetCommand } from "@aws-sdk/lib-dynamodb";
import { NodeHttpHandler } from "@smithy/node-http-handler";
import https from "https";

// Keep-alive agent for connection reuse
const agent = new https.Agent({
  keepAlive: true,
  maxSockets: 50,
  keepAliveMsecs: 1000,
});

// Global client with connection reuse
const client = new DynamoDBClient({
  requestHandler: new NodeHttpHandler({
    httpsAgent: agent,
    connectionTimeout: 3000,
    socketTimeout: 3000,
  }),
});

const docClient = DynamoDBDocumentClient.from(client, {
  marshallOptions: { removeUndefinedValues: true },
});

export const handler = async (event: any) => {
  const result = await docClient.send(
    new GetCommand({
      TableName: process.env.TABLE_NAME,
      Key: { pk: event.pk, sk: event.sk },
    }),
  );

  return {
    statusCode: 200,
    body: JSON.stringify(result.Item),
  };
};
```

---

## Serverless Framework and SAM Templates

### Serverless Framework (serverless.yml)

```yaml
service: my-serverless-api
frameworkVersion: "3"

provider:
  name: aws
  runtime: nodejs20.x
  stage: ${opt:stage, 'dev'}
  region: ${opt:region, 'us-east-1'}
  memorySize: 256
  timeout: 29
  architecture: arm64 # Cost optimization: Graviton2

  # Cold start optimization
  provisionedConcurrency: ${self:custom.provisionedConcurrency.${self:provider.stage}, 0}

  environment:
    TABLE_NAME: ${self:custom.tableName}
    STAGE: ${self:provider.stage}
    LOG_LEVEL: ${self:custom.logLevel.${self:provider.stage}, 'INFO'}

  iam:
    role:
      statements:
        - Effect: Allow
          Action:
            - dynamodb:GetItem
            - dynamodb:PutItem
            - dynamodb:UpdateItem
            - dynamodb:DeleteItem
            - dynamodb:Query
            - dynamodb:Scan
          Resource:
            - !GetAtt ItemsTable.Arn
            - !Sub "${ItemsTable.Arn}/index/*"
        - Effect: Allow
          Action:
            - sqs:SendMessage
            - sqs:ReceiveMessage
            - sqs:DeleteMessage
          Resource: !GetAtt ProcessingQueue.Arn

custom:
  tableName: items-${self:provider.stage}

  logLevel:
    dev: DEBUG
    staging: INFO
    prod: WARN

  provisionedConcurrency:
    dev: 0
    staging: 2
    prod: 10

  esbuild:
    bundle: true
    minify: true
    sourcemap: true
    target: "node20"
    platform: "node"
    concurrency: 10
    exclude:
      - "@aws-sdk/*" # Use Lambda-provided SDK

  prune:
    automatic: true
    number: 3

plugins:
  - serverless-esbuild
  - serverless-offline
  - serverless-prune-plugin
  - serverless-iam-roles-per-function

functions:
  createItem:
    handler: src/handlers/items.create
    events:
      - http:
          path: /items
          method: post
          cors: true
          authorizer:
            name: authorizer
            resultTtlInSeconds: 300
            identitySource: method.request.header.Authorization

  getItem:
    handler: src/handlers/items.get
    events:
      - http:
          path: /items/{id}
          method: get
          cors: true

  listItems:
    handler: src/handlers/items.list
    events:
      - http:
          path: /items
          method: get
          cors: true

  processQueue:
    handler: src/handlers/queue.process
    timeout: 30
    reservedConcurrency: 10
    events:
      - sqs:
          arn: !GetAtt ProcessingQueue.Arn
          batchSize: 10
          maximumBatchingWindow: 5

  dailyCleanup:
    handler: src/handlers/maintenance.cleanup
    timeout: 300
    memorySize: 512
    events:
      - schedule:
          rate: cron(0 2 * * ? *)
          enabled: ${self:custom.schedulesEnabled.${self:provider.stage}, false}

  authorizer:
    handler: src/handlers/auth.authorize
    memorySize: 128

resources:
  Resources:
    ItemsTable:
      Type: AWS::DynamoDB::Table
      Properties:
        TableName: ${self:custom.tableName}
        BillingMode: PAY_PER_REQUEST
        AttributeDefinitions:
          - AttributeName: pk
            AttributeType: S
          - AttributeName: sk
            AttributeType: S
          - AttributeName: gsi1pk
            AttributeType: S
          - AttributeName: gsi1sk
            AttributeType: S
        KeySchema:
          - AttributeName: pk
            KeyType: HASH
          - AttributeName: sk
            KeyType: RANGE
        GlobalSecondaryIndexes:
          - IndexName: gsi1
            KeySchema:
              - AttributeName: gsi1pk
                KeyType: HASH
              - AttributeName: gsi1sk
                KeyType: RANGE
            Projection:
              ProjectionType: ALL
        PointInTimeRecoverySpecification:
          PointInTimeRecoveryEnabled: true
        SSESpecification:
          SSEEnabled: true

    ProcessingQueue:
      Type: AWS::SQS::Queue
      Properties:
        QueueName: ${self:service}-processing-${self:provider.stage}
        VisibilityTimeout: 180
        MessageRetentionPeriod: 1209600
        RedrivePolicy:
          deadLetterTargetArn: !GetAtt DeadLetterQueue.Arn
          maxReceiveCount: 3

    DeadLetterQueue:
      Type: AWS::SQS::Queue
      Properties:
        QueueName: ${self:service}-dlq-${self:provider.stage}
        MessageRetentionPeriod: 1209600

  Outputs:
    ApiEndpoint:
      Value: !Sub "https://${ApiGatewayRestApi}.execute-api.${AWS::Region}.amazonaws.com/${self:provider.stage}"
    TableName:
      Value: !Ref ItemsTable
```

### AWS SAM Template (template.yaml)

```yaml
AWSTemplateFormatVersion: "2010-09-09"
Transform: AWS::Serverless-2016-10-31
Description: Serverless API with SAM

Globals:
  Function:
    Runtime: python3.12
    Architectures:
      - arm64
    MemorySize: 256
    Timeout: 29
    Tracing: Active
    Environment:
      Variables:
        LOG_LEVEL: INFO
        POWERTOOLS_SERVICE_NAME: my-api
        POWERTOOLS_METRICS_NAMESPACE: MyApi

Parameters:
  Stage:
    Type: String
    Default: dev
    AllowedValues:
      - dev
      - staging
      - prod

Conditions:
  IsProd: !Equals [!Ref Stage, prod]

Resources:
  # API Gateway
  ApiGateway:
    Type: AWS::Serverless::Api
    Properties:
      StageName: !Ref Stage
      TracingEnabled: true
      AccessLogSetting:
        DestinationArn: !GetAtt ApiAccessLogGroup.Arn
        Format: '{"requestId":"$context.requestId","ip":"$context.identity.sourceIp","requestTime":"$context.requestTime","httpMethod":"$context.httpMethod","path":"$context.path","status":"$context.status","responseLatency":"$context.responseLatency"}'
      MethodSettings:
        - HttpMethod: "*"
          ResourcePath: "/*"
          ThrottlingBurstLimit: 1000
          ThrottlingRateLimit: 500
      Cors:
        AllowOrigin: "'*'"
        AllowHeaders: "'Content-Type,Authorization,X-Request-Id'"
        AllowMethods: "'GET,POST,PUT,DELETE,OPTIONS'"

  ApiAccessLogGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: !Sub "/aws/apigateway/${AWS::StackName}"
      RetentionInDays: 30

  # Lambda Functions
  CreateItemFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: src/handlers/items.create_handler
      Description: Create new item
      Policies:
        - DynamoDBCrudPolicy:
            TableName: !Ref ItemsTable
      Events:
        CreateItem:
          Type: Api
          Properties:
            RestApiId: !Ref ApiGateway
            Path: /items
            Method: POST
      ProvisionedConcurrencyConfig: !If
        - IsProd
        - ProvisionedConcurrentExecutions: 5
        - !Ref AWS::NoValue
      AutoPublishAlias: live

  GetItemFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: src/handlers/items.get_handler
      Description: Get item by ID
      Policies:
        - DynamoDBReadPolicy:
            TableName: !Ref ItemsTable
      Events:
        GetItem:
          Type: Api
          Properties:
            RestApiId: !Ref ApiGateway
            Path: /items/{id}
            Method: GET

  ProcessEventFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: src/handlers/events.process_handler
      Description: Process events from EventBridge
      Timeout: 60
      MemorySize: 512
      Policies:
        - DynamoDBCrudPolicy:
            TableName: !Ref ItemsTable
        - SNSPublishMessagePolicy:
            TopicName: !GetAtt NotificationTopic.TopicName
      Events:
        EventRule:
          Type: EventBridgeRule
          Properties:
            Pattern:
              source:
                - my.application
              detail-type:
                - ItemCreated
                - ItemUpdated
      DeadLetterQueue:
        Type: SQS
        TargetArn: !GetAtt DeadLetterQueue.Arn

  StreamProcessorFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: src/handlers/streams.process_handler
      Description: Process DynamoDB stream events
      Policies:
        - DynamoDBStreamReadPolicy:
            TableName: !Ref ItemsTable
            StreamName: !GetAtt ItemsTable.StreamArn
        - EventBridgePutEventsPolicy:
            EventBusName: default
      Events:
        DynamoDBStream:
          Type: DynamoDB
          Properties:
            Stream: !GetAtt ItemsTable.StreamArn
            StartingPosition: TRIM_HORIZON
            BatchSize: 100
            MaximumBatchingWindowInSeconds: 5
            FilterCriteria:
              Filters:
                - Pattern: '{"eventName": ["INSERT", "MODIFY"]}'

  # DynamoDB Table
  ItemsTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: !Sub "items-${Stage}"
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: pk
          AttributeType: S
        - AttributeName: sk
          AttributeType: S
      KeySchema:
        - AttributeName: pk
          KeyType: HASH
        - AttributeName: sk
          KeyType: RANGE
      StreamSpecification:
        StreamViewType: NEW_AND_OLD_IMAGES
      PointInTimeRecoverySpecification:
        PointInTimeRecoveryEnabled: true
      SSESpecification:
        SSEEnabled: true
      Tags:
        - Key: Environment
          Value: !Ref Stage

  NotificationTopic:
    Type: AWS::SNS::Topic
    Properties:
      TopicName: !Sub "${AWS::StackName}-notifications"

  DeadLetterQueue:
    Type: AWS::SQS::Queue
    Properties:
      QueueName: !Sub "${AWS::StackName}-dlq"
      MessageRetentionPeriod: 1209600

Outputs:
  ApiEndpoint:
    Description: API Gateway endpoint URL
    Value: !Sub "https://${ApiGateway}.execute-api.${AWS::Region}.amazonaws.com/${Stage}"

  TableName:
    Description: DynamoDB table name
    Value: !Ref ItemsTable
```

---

## Cost Optimization Strategies

### Lambda Pricing Optimization

| Strategy                    | Savings      | Implementation                       |
| --------------------------- | ------------ | ------------------------------------ |
| **ARM64 (Graviton2)**       | 20%          | `Architectures: [arm64]`             |
| **Right-size memory**       | 10-40%       | Profile with AWS Lambda Power Tuning |
| **Shorter timeouts**        | Indirect     | Set timeout close to P99 latency     |
| **Reserved concurrency**    | 0% (control) | Prevent runaway costs                |
| **Provisioned concurrency** | Higher cost  | Use only for latency-critical paths  |

### Memory vs Duration Trade-off

```bash
# AWS Lambda Power Tuning tool
sam deploy --template-file power-tuning.yaml
aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:...:power-tuning \
  --input '{
    "lambdaARN": "arn:aws:lambda:...:my-function",
    "powerValues": [128, 256, 512, 1024, 2048],
    "num": 50,
    "payload": {}
  }'
```

### Cost Comparison by Approach

| Approach                   | Monthly Cost (1M requests) | Best For         |
| -------------------------- | -------------------------- | ---------------- |
| Lambda (128MB, 100ms)      | ~$0.21                     | Light processing |
| Lambda (512MB, 200ms)      | ~$1.67                     | Standard APIs    |
| Lambda (1GB, 500ms)        | ~$8.34                     | Heavy processing |
| Fargate (0.25 vCPU, 0.5GB) | ~$9.12                     | Long-running     |
| EC2 t3.micro               | ~$7.59                     | Consistent load  |

### DynamoDB Cost Optimization

```yaml
# On-demand for unpredictable workloads
BillingMode: PAY_PER_REQUEST

# Provisioned with auto-scaling for predictable workloads
BillingMode: PROVISIONED
ProvisionedThroughput:
  ReadCapacityUnits: 5
  WriteCapacityUnits: 5

# Auto-scaling configuration
ScalableTarget:
  Type: AWS::ApplicationAutoScaling::ScalableTarget
  Properties:
    ServiceNamespace: dynamodb
    ResourceId: !Sub "table/${TableName}"
    ScalableDimension: dynamodb:table:ReadCapacityUnits
    MinCapacity: 5
    MaxCapacity: 100

ScalingPolicy:
  Type: AWS::ApplicationAutoScaling::ScalingPolicy
  Properties:
    PolicyType: TargetTrackingScaling
    TargetTrackingScalingPolicyConfiguration:
      TargetValue: 70
      PredefinedMetricSpecification:
        PredefinedMetricType: DynamoDBReadCapacityUtilization
```

### Cost Monitoring Dashboard

```typescript
// CloudWatch cost monitoring
import {
  CloudWatchClient,
  PutMetricDataCommand,
} from "@aws-sdk/client-cloudwatch";

const cloudwatch = new CloudWatchClient({});

export async function recordCostMetric(
  functionName: string,
  billedDurationMs: number,
  memoryMB: number,
): Promise<void> {
  // Calculate estimated cost
  const gbSeconds = (billedDurationMs / 1000) * (memoryMB / 1024);
  const estimatedCost = gbSeconds * 0.0000166667; // Lambda pricing

  await cloudwatch.send(
    new PutMetricDataCommand({
      Namespace: "ServerlessCosts",
      MetricData: [
        {
          MetricName: "EstimatedCost",
          Dimensions: [{ Name: "FunctionName", Value: functionName }],
          Value: estimatedCost,
          Unit: "None",
        },
      ],
    }),
  );
}
```

---

## Monitoring and Observability for Serverless

### CloudWatch Embedded Metrics

```typescript
import { createMetricsLogger, Unit } from "aws-embedded-metrics";

export const handler = async (event: any) => {
  const metrics = createMetricsLogger();
  metrics.setNamespace("MyApplication");
  metrics.setDimensions({
    Service: "OrderService",
    Environment: process.env.STAGE,
  });

  const startTime = Date.now();

  try {
    const result = await processOrder(event);

    metrics.putMetric("OrderProcessed", 1, Unit.Count);
    metrics.putMetric(
      "ProcessingTime",
      Date.now() - startTime,
      Unit.Milliseconds,
    );
    metrics.setProperty("orderId", result.orderId);

    return result;
  } catch (error) {
    metrics.putMetric("OrderFailed", 1, Unit.Count);
    metrics.setProperty("errorType", error.constructor.name);
    throw error;
  } finally {
    await metrics.flush();
  }
};
```

### X-Ray Tracing

```typescript
import AWSXRay from "aws-xray-sdk-core";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";

// Instrument AWS SDK
const dynamoClient = AWSXRay.captureAWSv3Client(new DynamoDBClient({}));

export const handler = async (event: any) => {
  // Add custom subsegment
  const segment = AWSXRay.getSegment();
  const subsegment = segment?.addNewSubsegment("processBusinessLogic");

  try {
    subsegment?.addAnnotation("orderId", event.orderId);
    subsegment?.addMetadata("input", event);

    const result = await processOrder(event);

    subsegment?.addMetadata("output", result);
    return result;
  } catch (error) {
    subsegment?.addError(error);
    throw error;
  } finally {
    subsegment?.close();
  }
};
```

### Structured Logging with Powertools

```python
from aws_lambda_powertools import Logger, Tracer, Metrics
from aws_lambda_powertools.utilities.typing import LambdaContext
from aws_lambda_powertools.metrics import MetricUnit

logger = Logger()
tracer = Tracer()
metrics = Metrics()

@logger.inject_lambda_context(log_event=True)
@tracer.capture_lambda_handler
@metrics.log_metrics(capture_cold_start_metric=True)
def handler(event: dict, context: LambdaContext) -> dict:
    # Structured logging
    logger.info("Processing order", extra={
        "order_id": event.get("order_id"),
        "customer_id": event.get("customer_id"),
    })

    # Custom metrics
    metrics.add_metric(
        name="OrdersProcessed",
        unit=MetricUnit.Count,
        value=1
    )

    # Custom dimension
    metrics.add_dimension(
        name="OrderType",
        value=event.get("order_type", "standard")
    )

    return {"status": "success"}
```

### CloudWatch Alarms and Dashboards

```yaml
# SAM template for monitoring
LambdaErrorAlarm:
  Type: AWS::CloudWatch::Alarm
  Properties:
    AlarmName: !Sub "${AWS::StackName}-lambda-errors"
    AlarmDescription: Lambda function error rate too high
    MetricName: Errors
    Namespace: AWS/Lambda
    Statistic: Sum
    Period: 300
    EvaluationPeriods: 2
    Threshold: 5
    ComparisonOperator: GreaterThanThreshold
    Dimensions:
      - Name: FunctionName
        Value: !Ref MyFunction
    AlarmActions:
      - !Ref AlertTopic

LambdaDurationAlarm:
  Type: AWS::CloudWatch::Alarm
  Properties:
    AlarmName: !Sub "${AWS::StackName}-lambda-duration"
    MetricName: Duration
    Namespace: AWS/Lambda
    Statistic: p99
    Period: 300
    EvaluationPeriods: 3
    Threshold: 5000
    ComparisonOperator: GreaterThanThreshold
    Dimensions:
      - Name: FunctionName
        Value: !Ref MyFunction

ServerlessDashboard:
  Type: AWS::CloudWatch::Dashboard
  Properties:
    DashboardName: !Sub "${AWS::StackName}-dashboard"
    DashboardBody: !Sub |
      {
        "widgets": [
          {
            "type": "metric",
            "properties": {
              "title": "Lambda Invocations",
              "metrics": [
                ["AWS/Lambda", "Invocations", "FunctionName", "${MyFunction}"]
              ],
              "period": 60
            }
          },
          {
            "type": "metric",
            "properties": {
              "title": "Lambda Duration",
              "metrics": [
                ["AWS/Lambda", "Duration", "FunctionName", "${MyFunction}", {"stat": "p50"}],
                ["...", {"stat": "p99"}]
              ],
              "period": 60
            }
          },
          {
            "type": "metric",
            "properties": {
              "title": "Lambda Errors",
              "metrics": [
                ["AWS/Lambda", "Errors", "FunctionName", "${MyFunction}"]
              ],
              "period": 60
            }
          }
        ]
      }
```

---

## Security Best Practices

### IAM Least Privilege

```yaml
# Per-function IAM roles
CreateItemFunction:
  Type: AWS::Serverless::Function
  Properties:
    Policies:
      - Version: "2012-10-17"
        Statement:
          - Effect: Allow
            Action:
              - dynamodb:PutItem
            Resource: !GetAtt ItemsTable.Arn
            Condition:
              ForAllValues:StringEquals:
                dynamodb:LeadingKeys:
                  - !Sub "TENANT#${aws:PrincipalTag/tenantId}"

# Deny overly permissive actions
DenyPolicy:
  Type: AWS::IAM::Policy
  Properties:
    PolicyDocument:
      Statement:
        - Effect: Deny
          Action:
            - dynamodb:DeleteTable
            - dynamodb:UpdateTable
            - s3:DeleteBucket
          Resource: "*"
```

### Secrets Management

```typescript
import {
  SecretsManagerClient,
  GetSecretValueCommand,
} from "@aws-sdk/client-secrets-manager";

// Cache secrets outside handler
let cachedSecrets: Record<string, string> | null = null;
const secretsClient = new SecretsManagerClient({});

async function getSecrets(): Promise<Record<string, string>> {
  if (!cachedSecrets) {
    const command = new GetSecretValueCommand({
      SecretId: process.env.SECRET_ARN,
    });
    const response = await secretsClient.send(command);
    cachedSecrets = JSON.parse(response.SecretString || "{}");
  }
  return cachedSecrets;
}

export const handler = async (event: any) => {
  const secrets = await getSecrets();
  const apiKey = secrets.API_KEY;
  // Use apiKey securely
};
```

### API Gateway Security

```yaml
ApiGateway:
  Type: AWS::Serverless::Api
  Properties:
    Auth:
      DefaultAuthorizer: CognitoAuthorizer
      Authorizers:
        CognitoAuthorizer:
          UserPoolArn: !GetAtt UserPool.Arn
      ResourcePolicy:
        CustomStatements:
          - Effect: Deny
            Principal: "*"
            Action: execute-api:Invoke
            Resource: execute-api:/*
            Condition:
              NotIpAddress:
                aws:SourceIp:
                  - "10.0.0.0/8"
                  - "192.168.0.0/16"

    # WAF Integration
    MethodSettings:
      - HttpMethod: "*"
        ResourcePath: "/*"
        ThrottlingBurstLimit: 1000
        ThrottlingRateLimit: 500
```

---

## Example Invocations

```bash
# Design serverless architecture
/agents/cloud/serverless-expert design event-driven order processing system with DynamoDB

# Optimize cold starts
/agents/cloud/serverless-expert optimize cold start for Node.js Lambda handling 1000 req/s

# Create SAM template
/agents/cloud/serverless-expert create SAM template for REST API with Cognito auth

# Implement saga pattern
/agents/cloud/serverless-expert implement saga pattern for distributed transaction

# Cost analysis
/agents/cloud/serverless-expert analyze cost for 10M monthly Lambda invocations at 512MB

# Step Functions workflow
/agents/cloud/serverless-expert design Step Functions workflow for order processing

# Multi-cloud serverless
/agents/cloud/serverless-expert compare Lambda vs Cloud Functions vs Azure Functions for API backend
```

---

## Related Agents

- `/agents/cloud/aws-expert` - General AWS architecture
- `/agents/cloud/gcp-expert` - Google Cloud Platform
- `/agents/cloud/azure-expert` - Microsoft Azure
- `/agents/devops/terraform-expert` - Infrastructure as Code
- `/agents/backend/api-architect` - API design patterns
- `/agents/backend/microservices-architect` - Microservices patterns

---

Ahmed Adel Bakr Alderai
