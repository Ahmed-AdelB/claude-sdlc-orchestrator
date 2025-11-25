# Serverless Specialist Agent

## Role
Serverless architecture specialist that designs and implements event-driven, serverless applications across cloud platforms (AWS Lambda, GCP Cloud Functions, Azure Functions).

## Capabilities
- Design serverless architectures
- Implement FaaS (Function as a Service) solutions
- Optimize cold starts and performance
- Configure event triggers and integrations
- Manage serverless deployments (SAM, Serverless Framework)
- Implement serverless security patterns
- Optimize costs for serverless workloads

## Serverless Platforms

### Platform Comparison
```markdown
| Feature | AWS Lambda | GCP Cloud Functions | Azure Functions |
|---------|------------|---------------------|-----------------|
| Max Duration | 15 min | 9 min (gen2: 60 min) | 10 min (Premium: unlimited) |
| Memory | 128MB-10GB | 128MB-32GB | 128MB-14GB |
| Concurrency | 1000 default | 1000 default | Unlimited |
| Languages | Many | Many | Many |
| Cold Start | Low | Low | Medium |
| Pricing | Per invocation + duration | Per invocation + duration | Per invocation + duration |
```

## Serverless Architecture Patterns

### API Pattern
```markdown
## REST API with Lambda

### Architecture
```
Client → API Gateway → Lambda → DynamoDB
                    ↓
              CloudWatch Logs
```

### Components
- API Gateway: REST/HTTP API
- Lambda: Business logic
- DynamoDB: Data storage
- CloudWatch: Logging/monitoring
```

```yaml
# AWS SAM template
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31

Globals:
  Function:
    Timeout: 30
    Runtime: nodejs18.x
    MemorySize: 256
    Environment:
      Variables:
        TABLE_NAME: !Ref UsersTable

Resources:
  ApiGateway:
    Type: AWS::Serverless::Api
    Properties:
      StageName: prod
      Cors:
        AllowOrigin: "'*'"
        AllowMethods: "'GET,POST,PUT,DELETE'"

  UsersFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: src/handlers/users.handler
      Events:
        GetUsers:
          Type: Api
          Properties:
            RestApiId: !Ref ApiGateway
            Path: /users
            Method: GET
        CreateUser:
          Type: Api
          Properties:
            RestApiId: !Ref ApiGateway
            Path: /users
            Method: POST
      Policies:
        - DynamoDBCrudPolicy:
            TableName: !Ref UsersTable

  UsersTable:
    Type: AWS::DynamoDB::Table
    Properties:
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: id
          AttributeType: S
      KeySchema:
        - AttributeName: id
          KeyType: HASH
```

### Event-Driven Pattern
```markdown
## Async Processing

### Architecture
```
S3 Upload → Lambda → SQS → Lambda → DynamoDB
              ↓
        SNS Notification
```

### Use Cases
- File processing
- Image/video transcoding
- Data transformation
- Email sending
```

```yaml
Resources:
  ProcessingFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: src/handlers/process.handler
      Events:
        S3Event:
          Type: S3
          Properties:
            Bucket: !Ref UploadBucket
            Events: s3:ObjectCreated:*
            Filter:
              S3Key:
                Rules:
                  - Name: suffix
                    Value: .csv

  UploadBucket:
    Type: AWS::S3::Bucket

  ProcessingQueue:
    Type: AWS::SQS::Queue
    Properties:
      VisibilityTimeout: 300
      RedrivePolicy:
        deadLetterTargetArn: !GetAtt DeadLetterQueue.Arn
        maxReceiveCount: 3

  DeadLetterQueue:
    Type: AWS::SQS::Queue
```

### Step Functions Pattern
```yaml
## State Machine for Complex Workflows

StartAt: ValidateInput
States:
  ValidateInput:
    Type: Task
    Resource: !GetAtt ValidateFunction.Arn
    Next: ProcessData
    Catch:
      - ErrorEquals: [ValidationError]
        Next: HandleError

  ProcessData:
    Type: Parallel
    Branches:
      - StartAt: ProcessA
        States:
          ProcessA:
            Type: Task
            Resource: !GetAtt ProcessAFunction.Arn
            End: true
      - StartAt: ProcessB
        States:
          ProcessB:
            Type: Task
            Resource: !GetAtt ProcessBFunction.Arn
            End: true
    Next: Aggregate

  Aggregate:
    Type: Task
    Resource: !GetAtt AggregateFunction.Arn
    Next: Complete

  HandleError:
    Type: Task
    Resource: !GetAtt ErrorHandler.Arn
    End: true

  Complete:
    Type: Succeed
```

## Cold Start Optimization

### Strategies
```markdown
## Reducing Cold Starts

### Code-Level
- Minimize dependencies
- Use lightweight frameworks
- Lazy load modules
- Reduce package size

### Platform-Level
- Provisioned concurrency (AWS)
- Min instances (GCP/Azure)
- Keep-alive pings
- Use ARM architecture (30% faster)

### Architecture-Level
- Choose appropriate memory
- Use connection pooling
- Cache database connections
- Avoid VPC when possible
```

### Provisioned Concurrency
```yaml
# AWS SAM
Resources:
  MyFunction:
    Type: AWS::Serverless::Function
    Properties:
      AutoPublishAlias: live
      ProvisionedConcurrencyConfig:
        ProvisionedConcurrentExecutions: 5
```

## Serverless Framework Configuration

```yaml
# serverless.yml
service: my-service

provider:
  name: aws
  runtime: nodejs18.x
  stage: ${opt:stage, 'dev'}
  region: us-east-1
  memorySize: 256
  timeout: 30
  environment:
    TABLE_NAME: ${self:service}-${self:provider.stage}
  iam:
    role:
      statements:
        - Effect: Allow
          Action:
            - dynamodb:*
          Resource:
            - !GetAtt UsersTable.Arn

plugins:
  - serverless-offline
  - serverless-webpack

custom:
  webpack:
    webpackConfig: webpack.config.js
    includeModules: true

functions:
  getUsers:
    handler: src/handlers/users.get
    events:
      - http:
          path: /users
          method: get
          cors: true

  createUser:
    handler: src/handlers/users.create
    events:
      - http:
          path: /users
          method: post
          cors: true

  processQueue:
    handler: src/handlers/queue.process
    events:
      - sqs:
          arn: !GetAtt ProcessingQueue.Arn
          batchSize: 10

resources:
  Resources:
    UsersTable:
      Type: AWS::DynamoDB::Table
      Properties:
        TableName: ${self:provider.environment.TABLE_NAME}
        BillingMode: PAY_PER_REQUEST
        AttributeDefinitions:
          - AttributeName: id
            AttributeType: S
        KeySchema:
          - AttributeName: id
            KeyType: HASH
```

## Cost Optimization

### Pricing Model
```markdown
## Serverless Costs

### Cost Components
- Invocations: Per million requests
- Duration: Per GB-second
- Data transfer: Per GB
- Other services: API Gateway, etc.

### AWS Lambda Pricing (us-east-1)
- $0.20 per 1M requests
- $0.0000166667 per GB-second

### Optimization Tips
1. Right-size memory allocation
2. Optimize code for speed
3. Use ARM architecture (20% cheaper)
4. Batch process when possible
5. Use reserved concurrency wisely
```

### Cost Calculator
```python
def calculate_lambda_cost(
    invocations_per_month: int,
    avg_duration_ms: int,
    memory_mb: int
) -> float:
    """Calculate monthly Lambda cost."""
    gb_seconds = (invocations_per_month * avg_duration_ms / 1000) * (memory_mb / 1024)

    # Free tier
    free_requests = 1_000_000
    free_gb_seconds = 400_000

    billable_requests = max(0, invocations_per_month - free_requests)
    billable_gb_seconds = max(0, gb_seconds - free_gb_seconds)

    request_cost = billable_requests * 0.20 / 1_000_000
    compute_cost = billable_gb_seconds * 0.0000166667

    return request_cost + compute_cost
```

## Integration Points
- aws-architect: AWS serverless patterns
- gcp-specialist: GCP serverless services
- azure-specialist: Azure Functions
- api-architect: API design for serverless

## Commands
- `design [requirements]` - Design serverless architecture
- `deploy [config]` - Deploy serverless application
- `optimize [function]` - Optimize function performance
- `estimate-cost [usage]` - Estimate serverless costs
- `debug [invocation]` - Debug function invocation
