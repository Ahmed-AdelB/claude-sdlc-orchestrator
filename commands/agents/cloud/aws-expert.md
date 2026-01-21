---
name: AWS Expert Agent
description: Comprehensive Amazon Web Services cloud specialist for CDK/CloudFormation infrastructure, EC2/ECS/EKS compute, Lambda serverless, S3 storage, RDS/DynamoDB databases, VPC networking, IAM security, cost optimization, and Well-Architected Framework compliance
version: 2.0.0
author: Ahmed Adel Bakr Alderai
category: cloud
tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
  - Task
integrates_with:
  - /agents/devops/kubernetes-expert
  - /agents/devops/devops-engineer
  - /agents/devops/terraform-expert
  - /agents/security/security-expert
  - /agents/cloud/multi-cloud-expert
  - /agents/database/database-architect
---

# AWS Expert Agent

Comprehensive Amazon Web Services cloud specialist. Expert in infrastructure as code (CDK/CloudFormation), compute services (EC2, ECS, EKS, Lambda), storage solutions (S3, EBS, EFS), databases (RDS, DynamoDB, Aurora), networking (VPC, CloudFront, Route53), security (IAM, KMS, Secrets Manager), cost optimization, and Well-Architected Framework compliance.

## Arguments

- `$ARGUMENTS` - AWS task, architecture design, or deployment request

## Invoke Agent

```
Use the Task tool with subagent_type="aws-expert" to:

1. Design AWS cloud architectures
2. Create CDK stacks and CloudFormation templates
3. Configure EC2, ECS, and EKS compute resources
4. Implement Lambda and serverless patterns
5. Set up S3 storage with lifecycle policies
6. Configure RDS, Aurora, and DynamoDB databases
7. Design VPC networking with security groups
8. Implement IAM policies and security best practices
9. Set up CloudWatch monitoring and alarms
10. Optimize costs with AWS Cost Explorer
11. Ensure Well-Architected Framework compliance

Task: $ARGUMENTS
```

---

## Core AWS Services Reference

| Category       | Services                                                        |
| -------------- | --------------------------------------------------------------- |
| **Compute**    | EC2, Lambda, ECS, EKS, Fargate, Batch, App Runner               |
| **Storage**    | S3, EBS, EFS, FSx, Glacier, Storage Gateway                     |
| **Database**   | RDS, Aurora, DynamoDB, ElastiCache, DocumentDB, Neptune         |
| **Networking** | VPC, CloudFront, Route53, API Gateway, ELB, Global Accelerator  |
| **Security**   | IAM, KMS, Secrets Manager, WAF, Shield, Security Hub, GuardDuty |
| **DevOps**     | CodePipeline, CodeBuild, CodeDeploy, ECR, CloudFormation, CDK   |
| **Monitoring** | CloudWatch, X-Ray, CloudTrail, Config, Systems Manager          |
| **Analytics**  | Athena, Redshift, Kinesis, EMR, Glue, QuickSight                |

---

## AWS CDK (Cloud Development Kit)

### CDK Project Structure

```
my-cdk-app/
├── bin/
│   └── my-cdk-app.ts          # Entry point
├── lib/
│   ├── stacks/
│   │   ├── network-stack.ts   # VPC, subnets, NAT
│   │   ├── compute-stack.ts   # ECS, Lambda
│   │   ├── database-stack.ts  # RDS, DynamoDB
│   │   └── monitoring-stack.ts
│   ├── constructs/
│   │   ├── secure-bucket.ts   # Reusable constructs
│   │   └── api-lambda.ts
│   └── config/
│       └── environments.ts    # Environment configs
├── test/
│   └── my-cdk-app.test.ts
├── cdk.json
├── tsconfig.json
└── package.json
```

### CDK Network Stack (VPC)

```typescript
// lib/stacks/network-stack.ts
import * as cdk from "aws-cdk-lib";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import { Construct } from "constructs";

export interface NetworkStackProps extends cdk.StackProps {
  environment: string;
  cidrBlock: string;
}

export class NetworkStack extends cdk.Stack {
  public readonly vpc: ec2.Vpc;
  public readonly privateSubnets: ec2.ISubnet[];
  public readonly publicSubnets: ec2.ISubnet[];

  constructor(scope: Construct, id: string, props: NetworkStackProps) {
    super(scope, id, props);

    // VPC with public and private subnets across 3 AZs
    this.vpc = new ec2.Vpc(this, "AppVpc", {
      ipAddresses: ec2.IpAddresses.cidr(props.cidrBlock),
      maxAzs: 3,
      natGateways: props.environment === "prod" ? 3 : 1,
      subnetConfiguration: [
        {
          name: "Public",
          subnetType: ec2.SubnetType.PUBLIC,
          cidrMask: 24,
        },
        {
          name: "Private",
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
          cidrMask: 24,
        },
        {
          name: "Isolated",
          subnetType: ec2.SubnetType.PRIVATE_ISOLATED,
          cidrMask: 24,
        },
      ],
      enableDnsHostnames: true,
      enableDnsSupport: true,
    });

    this.privateSubnets = this.vpc.privateSubnets;
    this.publicSubnets = this.vpc.publicSubnets;

    // VPC Flow Logs for security monitoring
    this.vpc.addFlowLog("FlowLog", {
      destination: ec2.FlowLogDestination.toCloudWatchLogs(),
      trafficType: ec2.FlowLogTrafficType.ALL,
    });

    // VPC Endpoints for AWS services (reduce NAT costs)
    this.vpc.addGatewayEndpoint("S3Endpoint", {
      service: ec2.GatewayVpcEndpointAwsService.S3,
    });

    this.vpc.addGatewayEndpoint("DynamoDBEndpoint", {
      service: ec2.GatewayVpcEndpointAwsService.DYNAMODB,
    });

    this.vpc.addInterfaceEndpoint("EcrEndpoint", {
      service: ec2.InterfaceVpcEndpointAwsService.ECR,
      privateDnsEnabled: true,
    });

    this.vpc.addInterfaceEndpoint("EcrDockerEndpoint", {
      service: ec2.InterfaceVpcEndpointAwsService.ECR_DOCKER,
      privateDnsEnabled: true,
    });

    this.vpc.addInterfaceEndpoint("SecretsManagerEndpoint", {
      service: ec2.InterfaceVpcEndpointAwsService.SECRETS_MANAGER,
      privateDnsEnabled: true,
    });

    // Tags
    cdk.Tags.of(this).add("Environment", props.environment);
    cdk.Tags.of(this).add("ManagedBy", "CDK");

    // Outputs
    new cdk.CfnOutput(this, "VpcId", {
      value: this.vpc.vpcId,
      exportName: `${props.environment}-VpcId`,
    });
  }
}
```

### CDK Compute Stack (ECS Fargate)

```typescript
// lib/stacks/compute-stack.ts
import * as cdk from "aws-cdk-lib";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as ecs from "aws-cdk-lib/aws-ecs";
import * as ecs_patterns from "aws-cdk-lib/aws-ecs-patterns";
import * as ecr from "aws-cdk-lib/aws-ecr";
import * as iam from "aws-cdk-lib/aws-iam";
import * as logs from "aws-cdk-lib/aws-logs";
import * as secretsmanager from "aws-cdk-lib/aws-secretsmanager";
import { Construct } from "constructs";

export interface ComputeStackProps extends cdk.StackProps {
  vpc: ec2.IVpc;
  environment: string;
}

export class ComputeStack extends cdk.Stack {
  public readonly cluster: ecs.Cluster;
  public readonly service: ecs_patterns.ApplicationLoadBalancedFargateService;

  constructor(scope: Construct, id: string, props: ComputeStackProps) {
    super(scope, id, props);

    // ECS Cluster with Container Insights
    this.cluster = new ecs.Cluster(this, "AppCluster", {
      vpc: props.vpc,
      clusterName: `app-${props.environment}`,
      containerInsights: true,
      enableFargateCapacityProviders: true,
    });

    // ECR Repository
    const repository = new ecr.Repository(this, "AppRepository", {
      repositoryName: `app-${props.environment}`,
      imageScanOnPush: true,
      lifecycleRules: [
        {
          maxImageCount: 10,
          rulePriority: 1,
          tagStatus: ecr.TagStatus.ANY,
        },
      ],
      encryption: ecr.RepositoryEncryption.AES_256,
    });

    // Database credentials from Secrets Manager
    const dbSecret = secretsmanager.Secret.fromSecretNameV2(
      this,
      "DbSecret",
      `${props.environment}/db/credentials`,
    );

    // Task Role with least privilege
    const taskRole = new iam.Role(this, "TaskRole", {
      assumedBy: new iam.ServicePrincipal("ecs-tasks.amazonaws.com"),
      description: "ECS Task Role",
    });

    // Grant read access to secrets
    dbSecret.grantRead(taskRole);

    // CloudWatch Log Group
    const logGroup = new logs.LogGroup(this, "AppLogGroup", {
      logGroupName: `/ecs/app-${props.environment}`,
      retention: logs.RetentionDays.ONE_MONTH,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    // Application Load Balanced Fargate Service
    this.service = new ecs_patterns.ApplicationLoadBalancedFargateService(
      this,
      "AppService",
      {
        cluster: this.cluster,
        serviceName: `app-${props.environment}`,
        cpu: props.environment === "prod" ? 1024 : 256,
        memoryLimitMiB: props.environment === "prod" ? 2048 : 512,
        desiredCount: props.environment === "prod" ? 3 : 1,
        taskImageOptions: {
          image: ecs.ContainerImage.fromEcrRepository(repository, "latest"),
          containerPort: 3000,
          taskRole: taskRole,
          logDriver: ecs.LogDrivers.awsLogs({
            streamPrefix: "app",
            logGroup: logGroup,
          }),
          environment: {
            NODE_ENV: props.environment,
            AWS_REGION: this.region,
          },
          secrets: {
            DB_PASSWORD: ecs.Secret.fromSecretsManager(dbSecret, "password"),
            DB_HOST: ecs.Secret.fromSecretsManager(dbSecret, "host"),
          },
        },
        publicLoadBalancer: true,
        assignPublicIp: false,
        circuitBreaker: { rollback: true },
        capacityProviderStrategies: [
          {
            capacityProvider: "FARGATE",
            weight: props.environment === "prod" ? 1 : 0,
            base: props.environment === "prod" ? 1 : 0,
          },
          {
            capacityProvider: "FARGATE_SPOT",
            weight: props.environment === "prod" ? 0 : 1,
          },
        ],
      },
    );

    // Auto Scaling
    const scaling = this.service.service.autoScaleTaskCount({
      minCapacity: props.environment === "prod" ? 3 : 1,
      maxCapacity: props.environment === "prod" ? 20 : 5,
    });

    scaling.scaleOnCpuUtilization("CpuScaling", {
      targetUtilizationPercent: 70,
      scaleInCooldown: cdk.Duration.seconds(60),
      scaleOutCooldown: cdk.Duration.seconds(60),
    });

    scaling.scaleOnMemoryUtilization("MemoryScaling", {
      targetUtilizationPercent: 80,
      scaleInCooldown: cdk.Duration.seconds(60),
      scaleOutCooldown: cdk.Duration.seconds(60),
    });

    // Health check
    this.service.targetGroup.configureHealthCheck({
      path: "/health",
      healthyHttpCodes: "200",
      interval: cdk.Duration.seconds(30),
      timeout: cdk.Duration.seconds(5),
      healthyThresholdCount: 2,
      unhealthyThresholdCount: 3,
    });

    // Security Group rules
    this.service.service.connections.allowFromAnyIpv4(
      ec2.Port.tcp(443),
      "Allow HTTPS",
    );
  }
}
```

### CDK Database Stack (RDS Aurora)

```typescript
// lib/stacks/database-stack.ts
import * as cdk from "aws-cdk-lib";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as rds from "aws-cdk-lib/aws-rds";
import * as secretsmanager from "aws-cdk-lib/aws-secretsmanager";
import * as kms from "aws-cdk-lib/aws-kms";
import { Construct } from "constructs";

export interface DatabaseStackProps extends cdk.StackProps {
  vpc: ec2.IVpc;
  environment: string;
}

export class DatabaseStack extends cdk.Stack {
  public readonly cluster: rds.DatabaseCluster;
  public readonly secret: secretsmanager.ISecret;

  constructor(scope: Construct, id: string, props: DatabaseStackProps) {
    super(scope, id, props);

    // KMS key for encryption
    const encryptionKey = new kms.Key(this, "DbEncryptionKey", {
      alias: `${props.environment}/db/encryption`,
      enableKeyRotation: true,
      removalPolicy:
        props.environment === "prod"
          ? cdk.RemovalPolicy.RETAIN
          : cdk.RemovalPolicy.DESTROY,
    });

    // Database credentials secret
    this.secret = new secretsmanager.Secret(this, "DbSecret", {
      secretName: `${props.environment}/db/credentials`,
      generateSecretString: {
        secretStringTemplate: JSON.stringify({ username: "admin" }),
        generateStringKey: "password",
        excludePunctuation: true,
        passwordLength: 32,
      },
    });

    // Security group for database
    const dbSecurityGroup = new ec2.SecurityGroup(this, "DbSecurityGroup", {
      vpc: props.vpc,
      description: "Security group for Aurora cluster",
      allowAllOutbound: false,
    });

    // Aurora PostgreSQL Serverless v2
    this.cluster = new rds.DatabaseCluster(this, "AuroraCluster", {
      engine: rds.DatabaseClusterEngine.auroraPostgres({
        version: rds.AuroraPostgresEngineVersion.VER_15_4,
      }),
      clusterIdentifier: `aurora-${props.environment}`,
      credentials: rds.Credentials.fromSecret(this.secret),
      vpc: props.vpc,
      vpcSubnets: {
        subnetType: ec2.SubnetType.PRIVATE_ISOLATED,
      },
      securityGroups: [dbSecurityGroup],
      serverlessV2MinCapacity: props.environment === "prod" ? 1 : 0.5,
      serverlessV2MaxCapacity: props.environment === "prod" ? 16 : 4,
      writer: rds.ClusterInstance.serverlessV2("writer", {
        publiclyAccessible: false,
      }),
      readers:
        props.environment === "prod"
          ? [
              rds.ClusterInstance.serverlessV2("reader1", {
                scaleWithWriter: true,
              }),
              rds.ClusterInstance.serverlessV2("reader2", {
                scaleWithWriter: true,
              }),
            ]
          : [],
      storageEncrypted: true,
      storageEncryptionKey: encryptionKey,
      backup: {
        retention: cdk.Duration.days(props.environment === "prod" ? 35 : 7),
        preferredWindow: "03:00-04:00",
      },
      preferredMaintenanceWindow: "sun:04:00-sun:05:00",
      deletionProtection: props.environment === "prod",
      removalPolicy:
        props.environment === "prod"
          ? cdk.RemovalPolicy.RETAIN
          : cdk.RemovalPolicy.DESTROY,
      cloudwatchLogsExports: ["postgresql"],
      cloudwatchLogsRetention: 30,
      iamAuthentication: true,
      monitoringInterval: cdk.Duration.seconds(60),
      enableDataApi: true,
    });

    // Parameter group for performance tuning
    const parameterGroup = new rds.ParameterGroup(this, "DbParameterGroup", {
      engine: rds.DatabaseClusterEngine.auroraPostgres({
        version: rds.AuroraPostgresEngineVersion.VER_15_4,
      }),
      parameters: {
        shared_preload_libraries: "pg_stat_statements",
        "pg_stat_statements.track": "all",
        log_min_duration_statement: "1000",
        log_connections: "1",
        log_disconnections: "1",
      },
    });

    // Outputs
    new cdk.CfnOutput(this, "ClusterEndpoint", {
      value: this.cluster.clusterEndpoint.hostname,
      exportName: `${props.environment}-DbEndpoint`,
    });

    new cdk.CfnOutput(this, "ClusterReadEndpoint", {
      value: this.cluster.clusterReadEndpoint.hostname,
      exportName: `${props.environment}-DbReadEndpoint`,
    });
  }
}
```

### CDK DynamoDB Table

```typescript
// lib/constructs/dynamodb-table.ts
import * as cdk from "aws-cdk-lib";
import * as dynamodb from "aws-cdk-lib/aws-dynamodb";
import { Construct } from "constructs";

export interface SecureDynamoTableProps {
  tableName: string;
  partitionKey: {
    name: string;
    type: dynamodb.AttributeType;
  };
  sortKey?: {
    name: string;
    type: dynamodb.AttributeType;
  };
  gsiKeys?: Array<{
    indexName: string;
    partitionKey: { name: string; type: dynamodb.AttributeType };
    sortKey?: { name: string; type: dynamodb.AttributeType };
  }>;
  environment: string;
  ttlAttribute?: string;
  stream?: dynamodb.StreamViewType;
}

export class SecureDynamoTable extends Construct {
  public readonly table: dynamodb.Table;

  constructor(scope: Construct, id: string, props: SecureDynamoTableProps) {
    super(scope, id);

    this.table = new dynamodb.Table(this, "Table", {
      tableName: `${props.tableName}-${props.environment}`,
      partitionKey: props.partitionKey,
      sortKey: props.sortKey,
      billingMode:
        props.environment === "prod"
          ? dynamodb.BillingMode.PROVISIONED
          : dynamodb.BillingMode.PAY_PER_REQUEST,
      readCapacity: props.environment === "prod" ? 5 : undefined,
      writeCapacity: props.environment === "prod" ? 5 : undefined,
      encryption: dynamodb.TableEncryption.AWS_MANAGED,
      pointInTimeRecovery: true,
      deletionProtection: props.environment === "prod",
      removalPolicy:
        props.environment === "prod"
          ? cdk.RemovalPolicy.RETAIN
          : cdk.RemovalPolicy.DESTROY,
      timeToLiveAttribute: props.ttlAttribute,
      stream: props.stream,
      contributorInsightsEnabled: props.environment === "prod",
    });

    // Auto scaling for production
    if (props.environment === "prod") {
      const readScaling = this.table.autoScaleReadCapacity({
        minCapacity: 5,
        maxCapacity: 100,
      });
      readScaling.scaleOnUtilization({
        targetUtilizationPercent: 70,
      });

      const writeScaling = this.table.autoScaleWriteCapacity({
        minCapacity: 5,
        maxCapacity: 100,
      });
      writeScaling.scaleOnUtilization({
        targetUtilizationPercent: 70,
      });
    }

    // Add GSI indexes
    props.gsiKeys?.forEach((gsi) => {
      this.table.addGlobalSecondaryIndex({
        indexName: gsi.indexName,
        partitionKey: gsi.partitionKey,
        sortKey: gsi.sortKey,
        projectionType: dynamodb.ProjectionType.ALL,
      });
    });

    // Tags
    cdk.Tags.of(this).add("Environment", props.environment);
  }
}
```

### Deploy CDK

```bash
# Install dependencies
npm install

# Bootstrap CDK (first time only)
cdk bootstrap aws://ACCOUNT_ID/REGION

# Synthesize CloudFormation template
cdk synth

# Diff changes
cdk diff

# Deploy all stacks
cdk deploy --all

# Deploy specific stack
cdk deploy NetworkStack

# Deploy with approval
cdk deploy --require-approval broadening

# Destroy stacks (careful!)
cdk destroy --all
```

---

## CloudFormation Templates

### CloudFormation VPC Template

```yaml
# cloudformation/vpc.yaml
AWSTemplateFormatVersion: "2010-09-09"
Description: Production VPC with public and private subnets

Parameters:
  Environment:
    Type: String
    AllowedValues: [dev, staging, prod]
    Default: dev
  VpcCidr:
    Type: String
    Default: "10.0.0.0/16"
  ProjectName:
    Type: String
    Default: myapp

Mappings:
  SubnetConfig:
    VPC:
      CIDR: "10.0.0.0/16"
    PublicSubnet1:
      CIDR: "10.0.1.0/24"
    PublicSubnet2:
      CIDR: "10.0.2.0/24"
    PublicSubnet3:
      CIDR: "10.0.3.0/24"
    PrivateSubnet1:
      CIDR: "10.0.11.0/24"
    PrivateSubnet2:
      CIDR: "10.0.12.0/24"
    PrivateSubnet3:
      CIDR: "10.0.13.0/24"

Conditions:
  IsProd: !Equals [!Ref Environment, prod]

Resources:
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: !Ref VpcCidr
      EnableDnsHostnames: true
      EnableDnsSupport: true
      Tags:
        - Key: Name
          Value: !Sub ${ProjectName}-${Environment}-vpc
        - Key: Environment
          Value: !Ref Environment

  InternetGateway:
    Type: AWS::EC2::InternetGateway
    Properties:
      Tags:
        - Key: Name
          Value: !Sub ${ProjectName}-${Environment}-igw

  InternetGatewayAttachment:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      VpcId: !Ref VPC
      InternetGatewayId: !Ref InternetGateway

  PublicSubnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone: !Select [0, !GetAZs ""]
      CidrBlock: !FindInMap [SubnetConfig, PublicSubnet1, CIDR]
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Name
          Value: !Sub ${ProjectName}-${Environment}-public-1

  PublicSubnet2:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone: !Select [1, !GetAZs ""]
      CidrBlock: !FindInMap [SubnetConfig, PublicSubnet2, CIDR]
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Name
          Value: !Sub ${ProjectName}-${Environment}-public-2

  PrivateSubnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone: !Select [0, !GetAZs ""]
      CidrBlock: !FindInMap [SubnetConfig, PrivateSubnet1, CIDR]
      Tags:
        - Key: Name
          Value: !Sub ${ProjectName}-${Environment}-private-1

  PrivateSubnet2:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone: !Select [1, !GetAZs ""]
      CidrBlock: !FindInMap [SubnetConfig, PrivateSubnet2, CIDR]
      Tags:
        - Key: Name
          Value: !Sub ${ProjectName}-${Environment}-private-2

  NatGateway1EIP:
    Type: AWS::EC2::EIP
    DependsOn: InternetGatewayAttachment
    Properties:
      Domain: vpc

  NatGateway1:
    Type: AWS::EC2::NatGateway
    Properties:
      AllocationId: !GetAtt NatGateway1EIP.AllocationId
      SubnetId: !Ref PublicSubnet1
      Tags:
        - Key: Name
          Value: !Sub ${ProjectName}-${Environment}-nat-1

  # Additional NAT Gateway for prod (high availability)
  NatGateway2EIP:
    Type: AWS::EC2::EIP
    Condition: IsProd
    DependsOn: InternetGatewayAttachment
    Properties:
      Domain: vpc

  NatGateway2:
    Type: AWS::EC2::NatGateway
    Condition: IsProd
    Properties:
      AllocationId: !GetAtt NatGateway2EIP.AllocationId
      SubnetId: !Ref PublicSubnet2
      Tags:
        - Key: Name
          Value: !Sub ${ProjectName}-${Environment}-nat-2

  PublicRouteTable:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: !Sub ${ProjectName}-${Environment}-public-rt

  DefaultPublicRoute:
    Type: AWS::EC2::Route
    DependsOn: InternetGatewayAttachment
    Properties:
      RouteTableId: !Ref PublicRouteTable
      DestinationCidrBlock: 0.0.0.0/0
      GatewayId: !Ref InternetGateway

  PublicSubnet1RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PublicSubnet1
      RouteTableId: !Ref PublicRouteTable

  PublicSubnet2RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PublicSubnet2
      RouteTableId: !Ref PublicRouteTable

  PrivateRouteTable1:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: !Sub ${ProjectName}-${Environment}-private-rt-1

  DefaultPrivateRoute1:
    Type: AWS::EC2::Route
    Properties:
      RouteTableId: !Ref PrivateRouteTable1
      DestinationCidrBlock: 0.0.0.0/0
      NatGatewayId: !Ref NatGateway1

  PrivateSubnet1RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PrivateSubnet1
      RouteTableId: !Ref PrivateRouteTable1

  PrivateSubnet2RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PrivateSubnet2
      RouteTableId: !If
        - IsProd
        - !Ref PrivateRouteTable2
        - !Ref PrivateRouteTable1

  PrivateRouteTable2:
    Type: AWS::EC2::RouteTable
    Condition: IsProd
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: !Sub ${ProjectName}-${Environment}-private-rt-2

  DefaultPrivateRoute2:
    Type: AWS::EC2::Route
    Condition: IsProd
    Properties:
      RouteTableId: !Ref PrivateRouteTable2
      DestinationCidrBlock: 0.0.0.0/0
      NatGatewayId: !Ref NatGateway2

  # VPC Flow Logs
  FlowLogRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: "2012-10-17"
        Statement:
          - Effect: Allow
            Principal:
              Service: vpc-flow-logs.amazonaws.com
            Action: sts:AssumeRole
      Policies:
        - PolicyName: FlowLogPolicy
          PolicyDocument:
            Version: "2012-10-17"
            Statement:
              - Effect: Allow
                Action:
                  - logs:CreateLogGroup
                  - logs:CreateLogStream
                  - logs:PutLogEvents
                  - logs:DescribeLogGroups
                  - logs:DescribeLogStreams
                Resource: "*"

  FlowLogGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: !Sub /aws/vpc/${ProjectName}-${Environment}
      RetentionInDays: 30

  VpcFlowLog:
    Type: AWS::EC2::FlowLog
    Properties:
      DeliverLogsPermissionArn: !GetAtt FlowLogRole.Arn
      LogGroupName: !Ref FlowLogGroup
      ResourceId: !Ref VPC
      ResourceType: VPC
      TrafficType: ALL

Outputs:
  VpcId:
    Description: VPC ID
    Value: !Ref VPC
    Export:
      Name: !Sub ${ProjectName}-${Environment}-VpcId

  PublicSubnet1Id:
    Description: Public Subnet 1 ID
    Value: !Ref PublicSubnet1
    Export:
      Name: !Sub ${ProjectName}-${Environment}-PublicSubnet1Id

  PublicSubnet2Id:
    Description: Public Subnet 2 ID
    Value: !Ref PublicSubnet2
    Export:
      Name: !Sub ${ProjectName}-${Environment}-PublicSubnet2Id

  PrivateSubnet1Id:
    Description: Private Subnet 1 ID
    Value: !Ref PrivateSubnet1
    Export:
      Name: !Sub ${ProjectName}-${Environment}-PrivateSubnet1Id

  PrivateSubnet2Id:
    Description: Private Subnet 2 ID
    Value: !Ref PrivateSubnet2
    Export:
      Name: !Sub ${ProjectName}-${Environment}-PrivateSubnet2Id
```

### Deploy CloudFormation

```bash
# Validate template
aws cloudformation validate-template --template-body file://vpc.yaml

# Create stack
aws cloudformation create-stack \
  --stack-name myapp-prod-vpc \
  --template-body file://vpc.yaml \
  --parameters ParameterKey=Environment,ParameterValue=prod \
  --capabilities CAPABILITY_IAM

# Update stack
aws cloudformation update-stack \
  --stack-name myapp-prod-vpc \
  --template-body file://vpc.yaml \
  --parameters ParameterKey=Environment,ParameterValue=prod \
  --capabilities CAPABILITY_IAM

# Create change set (preview changes)
aws cloudformation create-change-set \
  --stack-name myapp-prod-vpc \
  --change-set-name update-001 \
  --template-body file://vpc.yaml \
  --parameters ParameterKey=Environment,ParameterValue=prod

# Execute change set
aws cloudformation execute-change-set \
  --stack-name myapp-prod-vpc \
  --change-set-name update-001

# Delete stack
aws cloudformation delete-stack --stack-name myapp-prod-vpc
```

---

## EC2 and Compute Patterns

### EC2 Auto Scaling Group with Launch Template

```typescript
// CDK: EC2 Auto Scaling
import * as autoscaling from "aws-cdk-lib/aws-autoscaling";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as iam from "aws-cdk-lib/aws-iam";
import * as elbv2 from "aws-cdk-lib/aws-elasticloadbalancingv2";

// Launch Template
const launchTemplate = new ec2.LaunchTemplate(this, "LaunchTemplate", {
  instanceType: ec2.InstanceType.of(
    ec2.InstanceClass.T3,
    ec2.InstanceSize.MEDIUM,
  ),
  machineImage: ec2.MachineImage.latestAmazonLinux2023(),
  securityGroup: appSecurityGroup,
  role: ec2InstanceRole,
  userData: ec2.UserData.custom(`#!/bin/bash
    yum update -y
    yum install -y docker
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ec2-user

    # Install CloudWatch agent
    yum install -y amazon-cloudwatch-agent
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config -m ec2 -s \
      -c ssm:AmazonCloudWatch-linux
  `),
  blockDevices: [
    {
      deviceName: "/dev/xvda",
      volume: ec2.BlockDeviceVolume.ebs(30, {
        encrypted: true,
        volumeType: ec2.EbsDeviceVolumeType.GP3,
        iops: 3000,
        throughput: 125,
      }),
    },
  ],
  requireImdsv2: true, // Enforce IMDSv2 for security
});

// Auto Scaling Group
const asg = new autoscaling.AutoScalingGroup(this, "ASG", {
  vpc,
  launchTemplate,
  minCapacity: environment === "prod" ? 2 : 1,
  maxCapacity: environment === "prod" ? 20 : 5,
  desiredCapacity: environment === "prod" ? 3 : 1,
  vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS },
  healthCheck: autoscaling.HealthCheck.elb({
    grace: cdk.Duration.minutes(5),
  }),
  updatePolicy: autoscaling.UpdatePolicy.rollingUpdate({
    maxBatchSize: 1,
    minInstancesInService: 1,
    pauseTime: cdk.Duration.minutes(5),
  }),
  signals: autoscaling.Signals.waitForMinCapacity({
    timeout: cdk.Duration.minutes(10),
  }),
  terminationPolicies: [
    autoscaling.TerminationPolicy.OLDEST_LAUNCH_TEMPLATE,
    autoscaling.TerminationPolicy.DEFAULT,
  ],
});

// Target Tracking Scaling
asg.scaleOnCpuUtilization("CpuScaling", {
  targetUtilizationPercent: 70,
  cooldown: cdk.Duration.seconds(300),
});

// Scheduled Scaling
asg.scaleOnSchedule("ScaleUp", {
  schedule: autoscaling.Schedule.cron({ hour: "8", minute: "0" }),
  minCapacity: 5,
});

asg.scaleOnSchedule("ScaleDown", {
  schedule: autoscaling.Schedule.cron({ hour: "20", minute: "0" }),
  minCapacity: 2,
});

// Application Load Balancer
const alb = new elbv2.ApplicationLoadBalancer(this, "ALB", {
  vpc,
  internetFacing: true,
  securityGroup: albSecurityGroup,
});

const listener = alb.addListener("Listener", {
  port: 443,
  certificates: [certificate],
  sslPolicy: elbv2.SslPolicy.TLS13_RES,
});

listener.addTargets("ASGTarget", {
  port: 80,
  targets: [asg],
  healthCheck: {
    path: "/health",
    interval: cdk.Duration.seconds(30),
    healthyThresholdCount: 2,
    unhealthyThresholdCount: 5,
  },
  deregistrationDelay: cdk.Duration.seconds(30),
});
```

### EKS Cluster with Managed Node Groups

```typescript
// CDK: EKS Cluster
import * as eks from "aws-cdk-lib/aws-eks";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as iam from "aws-cdk-lib/aws-iam";

const cluster = new eks.Cluster(this, "EksCluster", {
  version: eks.KubernetesVersion.V1_29,
  vpc,
  vpcSubnets: [{ subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS }],
  defaultCapacity: 0, // We'll add node groups separately
  clusterName: `eks-${environment}`,
  endpointAccess: eks.EndpointAccess.PRIVATE,
  secretsEncryptionKey: kmsKey,
  albController: {
    version: eks.AlbControllerVersion.V2_6_2,
  },
  clusterLogging: [
    eks.ClusterLoggingTypes.API,
    eks.ClusterLoggingTypes.AUTHENTICATOR,
    eks.ClusterLoggingTypes.SCHEDULER,
    eks.ClusterLoggingTypes.CONTROLLER_MANAGER,
    eks.ClusterLoggingTypes.AUDIT,
  ],
});

// System Node Group
cluster.addNodegroupCapacity("SystemNodes", {
  nodegroupName: "system",
  instanceTypes: [
    ec2.InstanceType.of(ec2.InstanceClass.M6I, ec2.InstanceSize.LARGE),
  ],
  minSize: 2,
  maxSize: 5,
  desiredSize: 3,
  diskSize: 50,
  amiType: eks.NodegroupAmiType.AL2023_X86_64_STANDARD,
  labels: {
    "node-type": "system",
  },
  taints: [
    {
      key: "CriticalAddonsOnly",
      value: "true",
      effect: eks.TaintEffect.NO_SCHEDULE,
    },
  ],
});

// Application Node Group
cluster.addNodegroupCapacity("AppNodes", {
  nodegroupName: "app",
  instanceTypes: [
    ec2.InstanceType.of(ec2.InstanceClass.M6I, ec2.InstanceSize.XLARGE),
    ec2.InstanceType.of(ec2.InstanceClass.M6A, ec2.InstanceSize.XLARGE),
  ],
  minSize: environment === "prod" ? 3 : 1,
  maxSize: environment === "prod" ? 50 : 10,
  desiredSize: environment === "prod" ? 5 : 2,
  diskSize: 100,
  amiType: eks.NodegroupAmiType.AL2023_X86_64_STANDARD,
  labels: {
    "node-type": "app",
  },
  capacityType:
    environment === "prod" ? eks.CapacityType.ON_DEMAND : eks.CapacityType.SPOT,
});

// Spot Node Group for cost optimization
if (environment === "prod") {
  cluster.addNodegroupCapacity("SpotNodes", {
    nodegroupName: "spot",
    instanceTypes: [
      ec2.InstanceType.of(ec2.InstanceClass.M6I, ec2.InstanceSize.XLARGE),
      ec2.InstanceType.of(ec2.InstanceClass.M6A, ec2.InstanceSize.XLARGE),
      ec2.InstanceType.of(ec2.InstanceClass.M5, ec2.InstanceSize.XLARGE),
    ],
    minSize: 0,
    maxSize: 100,
    desiredSize: 0,
    capacityType: eks.CapacityType.SPOT,
    labels: {
      "node-type": "spot",
    },
    taints: [
      {
        key: "spot",
        value: "true",
        effect: eks.TaintEffect.NO_SCHEDULE,
      },
    ],
  });
}

// Cluster Autoscaler
cluster.addHelmChart("ClusterAutoscaler", {
  chart: "cluster-autoscaler",
  repository: "https://kubernetes.github.io/autoscaler",
  namespace: "kube-system",
  values: {
    autoDiscovery: {
      clusterName: cluster.clusterName,
    },
    awsRegion: this.region,
    extraArgs: {
      "balance-similar-node-groups": true,
      "skip-nodes-with-system-pods": false,
    },
  },
});

// AWS Load Balancer Controller is automatically installed via albController
```

---

## Lambda and Serverless Patterns

### Lambda Function with CDK

```typescript
// CDK: Lambda Functions
import * as lambda from "aws-cdk-lib/aws-lambda";
import * as lambdaNodejs from "aws-cdk-lib/aws-lambda-nodejs";
import * as apigateway from "aws-cdk-lib/aws-apigateway";
import * as sqs from "aws-cdk-lib/aws-sqs";
import * as sns from "aws-cdk-lib/aws-sns";
import * as events from "aws-cdk-lib/aws-events";
import * as targets from "aws-cdk-lib/aws-events-targets";
import * as dynamodb from "aws-cdk-lib/aws-dynamodb";
import * as secretsmanager from "aws-cdk-lib/aws-secretsmanager";

// DynamoDB Table
const ordersTable = new dynamodb.Table(this, "OrdersTable", {
  tableName: `orders-${environment}`,
  partitionKey: { name: "pk", type: dynamodb.AttributeType.STRING },
  sortKey: { name: "sk", type: dynamodb.AttributeType.STRING },
  billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
  stream: dynamodb.StreamViewType.NEW_AND_OLD_IMAGES,
  encryption: dynamodb.TableEncryption.AWS_MANAGED,
  pointInTimeRecovery: true,
  timeToLiveAttribute: "ttl",
});

// Dead Letter Queue
const dlq = new sqs.Queue(this, "DLQ", {
  queueName: `orders-dlq-${environment}`,
  retentionPeriod: cdk.Duration.days(14),
  encryption: sqs.QueueEncryption.SQS_MANAGED,
});

// Processing Queue
const processingQueue = new sqs.Queue(this, "ProcessingQueue", {
  queueName: `orders-processing-${environment}`,
  visibilityTimeout: cdk.Duration.seconds(300),
  deadLetterQueue: {
    queue: dlq,
    maxReceiveCount: 3,
  },
  encryption: sqs.QueueEncryption.SQS_MANAGED,
});

// Lambda Layer for shared code
const sharedLayer = new lambda.LayerVersion(this, "SharedLayer", {
  code: lambda.Code.fromAsset("layers/shared"),
  compatibleRuntimes: [lambda.Runtime.NODEJS_20_X],
  description: "Shared utilities and dependencies",
});

// API Handler Lambda
const apiHandler = new lambdaNodejs.NodejsFunction(this, "ApiHandler", {
  entry: "src/handlers/api.ts",
  handler: "handler",
  runtime: lambda.Runtime.NODEJS_20_X,
  architecture: lambda.Architecture.ARM_64,
  memorySize: 1024,
  timeout: cdk.Duration.seconds(30),
  tracing: lambda.Tracing.ACTIVE,
  layers: [sharedLayer],
  environment: {
    TABLE_NAME: ordersTable.tableName,
    QUEUE_URL: processingQueue.queueUrl,
    NODE_OPTIONS: "--enable-source-maps",
    POWERTOOLS_SERVICE_NAME: "orders-api",
    POWERTOOLS_METRICS_NAMESPACE: "OrdersService",
    LOG_LEVEL: environment === "prod" ? "INFO" : "DEBUG",
  },
  bundling: {
    minify: true,
    sourceMap: true,
    externalModules: ["@aws-sdk/*"],
    define: {
      "process.env.NODE_ENV": JSON.stringify(environment),
    },
  },
  insightsVersion: lambda.LambdaInsightsVersion.VERSION_1_0_229_0,
});

// Grant permissions
ordersTable.grantReadWriteData(apiHandler);
processingQueue.grantSendMessages(apiHandler);

// Queue Processor Lambda
const queueProcessor = new lambdaNodejs.NodejsFunction(this, "QueueProcessor", {
  entry: "src/handlers/processor.ts",
  handler: "handler",
  runtime: lambda.Runtime.NODEJS_20_X,
  architecture: lambda.Architecture.ARM_64,
  memorySize: 512,
  timeout: cdk.Duration.seconds(60),
  reservedConcurrentExecutions: environment === "prod" ? 100 : 10,
  tracing: lambda.Tracing.ACTIVE,
  layers: [sharedLayer],
  environment: {
    TABLE_NAME: ordersTable.tableName,
    POWERTOOLS_SERVICE_NAME: "orders-processor",
  },
});

// SQS Event Source
queueProcessor.addEventSource(
  new lambdaEventSources.SqsEventSource(processingQueue, {
    batchSize: 10,
    maxBatchingWindow: cdk.Duration.seconds(5),
    reportBatchItemFailures: true,
  }),
);

ordersTable.grantReadWriteData(queueProcessor);

// DynamoDB Stream Processor
const streamProcessor = new lambdaNodejs.NodejsFunction(
  this,
  "StreamProcessor",
  {
    entry: "src/handlers/stream.ts",
    handler: "handler",
    runtime: lambda.Runtime.NODEJS_20_X,
    architecture: lambda.Architecture.ARM_64,
    memorySize: 256,
    timeout: cdk.Duration.seconds(30),
    tracing: lambda.Tracing.ACTIVE,
  },
);

streamProcessor.addEventSource(
  new lambdaEventSources.DynamoEventSource(ordersTable, {
    startingPosition: lambda.StartingPosition.LATEST,
    batchSize: 100,
    maxBatchingWindow: cdk.Duration.seconds(5),
    retryAttempts: 3,
    bisectBatchOnError: true,
    reportBatchItemFailures: true,
    filters: [
      lambda.FilterCriteria.filter({
        eventName: lambda.FilterRule.isEqual("INSERT"),
      }),
    ],
  }),
);

// Scheduled Lambda (EventBridge)
const cleanupFunction = new lambdaNodejs.NodejsFunction(
  this,
  "CleanupFunction",
  {
    entry: "src/handlers/cleanup.ts",
    handler: "handler",
    runtime: lambda.Runtime.NODEJS_20_X,
    timeout: cdk.Duration.minutes(5),
    memorySize: 256,
  },
);

new events.Rule(this, "CleanupSchedule", {
  schedule: events.Schedule.rate(cdk.Duration.hours(1)),
  targets: [new targets.LambdaFunction(cleanupFunction)],
});

// API Gateway REST API
const api = new apigateway.RestApi(this, "OrdersApi", {
  restApiName: `orders-api-${environment}`,
  description: "Orders Service API",
  deployOptions: {
    stageName: environment,
    tracingEnabled: true,
    metricsEnabled: true,
    loggingLevel: apigateway.MethodLoggingLevel.INFO,
    dataTraceEnabled: environment !== "prod",
    throttlingBurstLimit: 1000,
    throttlingRateLimit: 500,
  },
  defaultCorsPreflightOptions: {
    allowOrigins: apigateway.Cors.ALL_ORIGINS,
    allowMethods: apigateway.Cors.ALL_METHODS,
    allowHeaders: ["Content-Type", "Authorization", "X-Api-Key"],
  },
  endpointTypes: [apigateway.EndpointType.REGIONAL],
});

// API Resources and Methods
const orders = api.root.addResource("orders");
orders.addMethod("GET", new apigateway.LambdaIntegration(apiHandler));
orders.addMethod("POST", new apigateway.LambdaIntegration(apiHandler));

const order = orders.addResource("{orderId}");
order.addMethod("GET", new apigateway.LambdaIntegration(apiHandler));
order.addMethod("PUT", new apigateway.LambdaIntegration(apiHandler));
order.addMethod("DELETE", new apigateway.LambdaIntegration(apiHandler));

// API Gateway Usage Plan
const usagePlan = api.addUsagePlan("UsagePlan", {
  name: `orders-usage-plan-${environment}`,
  throttle: {
    rateLimit: 1000,
    burstLimit: 2000,
  },
  quota: {
    limit: 100000,
    period: apigateway.Period.DAY,
  },
});

const apiKey = api.addApiKey("ApiKey", {
  apiKeyName: `orders-api-key-${environment}`,
});

usagePlan.addApiKey(apiKey);
usagePlan.addApiStage({ stage: api.deploymentStage });
```

### Lambda Function Code Example

```typescript
// src/handlers/api.ts
import {
  APIGatewayProxyHandler,
  APIGatewayProxyEvent,
  APIGatewayProxyResult,
} from "aws-lambda";
import { Logger, Metrics, Tracer } from "@aws-lambda-powertools/";
import {
  DynamoDBClient,
  PutItemCommand,
  GetItemCommand,
  QueryCommand,
} from "@aws-sdk/client-dynamodb";
import { SQSClient, SendMessageCommand } from "@aws-sdk/client-sqs";
import { marshall, unmarshall } from "@aws-sdk/util-dynamodb";
import { randomUUID } from "crypto";

const logger = new Logger({ serviceName: "orders-api" });
const metrics = new Metrics({ namespace: "OrdersService" });
const tracer = new Tracer({ serviceName: "orders-api" });

const dynamodb = tracer.captureAWSv3Client(new DynamoDBClient({}));
const sqs = tracer.captureAWSv3Client(new SQSClient({}));

const TABLE_NAME = process.env.TABLE_NAME!;
const QUEUE_URL = process.env.QUEUE_URL!;

interface Order {
  orderId: string;
  customerId: string;
  items: Array<{ productId: string; quantity: number; price: number }>;
  status: "pending" | "processing" | "completed" | "cancelled";
  totalAmount: number;
  createdAt: string;
  updatedAt: string;
}

export const handler: APIGatewayProxyHandler = async (
  event: APIGatewayProxyEvent,
): Promise<APIGatewayProxyResult> => {
  logger.addContext({ requestId: event.requestContext.requestId });
  logger.info("Received request", {
    path: event.path,
    method: event.httpMethod,
  });

  try {
    const { httpMethod, path, pathParameters, body } = event;

    // POST /orders - Create order
    if (httpMethod === "POST" && path === "/orders") {
      return await createOrder(JSON.parse(body || "{}"));
    }

    // GET /orders - List orders
    if (httpMethod === "GET" && path === "/orders") {
      const customerId = event.queryStringParameters?.customerId;
      if (!customerId) {
        return response(400, { error: "customerId query parameter required" });
      }
      return await listOrders(customerId);
    }

    // GET /orders/{orderId} - Get order
    if (httpMethod === "GET" && pathParameters?.orderId) {
      return await getOrder(pathParameters.orderId);
    }

    // PUT /orders/{orderId} - Update order
    if (httpMethod === "PUT" && pathParameters?.orderId) {
      return await updateOrder(
        pathParameters.orderId,
        JSON.parse(body || "{}"),
      );
    }

    return response(404, { error: "Not found" });
  } catch (error) {
    logger.error("Request failed", { error });
    metrics.addMetric("Errors", 1);
    return response(500, { error: "Internal server error" });
  } finally {
    metrics.publishStoredMetrics();
  }
};

async function createOrder(
  data: Partial<Order>,
): Promise<APIGatewayProxyResult> {
  const orderId = randomUUID();
  const now = new Date().toISOString();

  const order: Order = {
    orderId,
    customerId: data.customerId!,
    items: data.items || [],
    status: "pending",
    totalAmount:
      data.items?.reduce((sum, item) => sum + item.price * item.quantity, 0) ||
      0,
    createdAt: now,
    updatedAt: now,
  };

  // Save to DynamoDB
  await dynamodb.send(
    new PutItemCommand({
      TableName: TABLE_NAME,
      Item: marshall({
        pk: `CUSTOMER#${order.customerId}`,
        sk: `ORDER#${orderId}`,
        ...order,
        ttl: Math.floor(Date.now() / 1000) + 90 * 24 * 60 * 60, // 90 days
      }),
      ConditionExpression: "attribute_not_exists(pk)",
    }),
  );

  // Send to processing queue
  await sqs.send(
    new SendMessageCommand({
      QueueUrl: QUEUE_URL,
      MessageBody: JSON.stringify(order),
      MessageGroupId: order.customerId,
      MessageDeduplicationId: orderId,
    }),
  );

  metrics.addMetric("OrdersCreated", 1);
  logger.info("Order created", { orderId });

  return response(201, order);
}

async function getOrder(orderId: string): Promise<APIGatewayProxyResult> {
  // Use GSI to find order by orderId
  const result = await dynamodb.send(
    new QueryCommand({
      TableName: TABLE_NAME,
      IndexName: "GSI1",
      KeyConditionExpression: "sk = :sk",
      ExpressionAttributeValues: marshall({
        ":sk": `ORDER#${orderId}`,
      }),
    }),
  );

  if (!result.Items?.length) {
    return response(404, { error: "Order not found" });
  }

  return response(200, unmarshall(result.Items[0]));
}

async function listOrders(customerId: string): Promise<APIGatewayProxyResult> {
  const result = await dynamodb.send(
    new QueryCommand({
      TableName: TABLE_NAME,
      KeyConditionExpression: "pk = :pk AND begins_with(sk, :skPrefix)",
      ExpressionAttributeValues: marshall({
        ":pk": `CUSTOMER#${customerId}`,
        ":skPrefix": "ORDER#",
      }),
      ScanIndexForward: false,
      Limit: 50,
    }),
  );

  const orders = result.Items?.map((item) => unmarshall(item)) || [];
  return response(200, { orders, count: orders.length });
}

async function updateOrder(
  orderId: string,
  updates: Partial<Order>,
): Promise<APIGatewayProxyResult> {
  // Implementation for update
  return response(200, { message: "Order updated", orderId });
}

function response(statusCode: number, body: unknown): APIGatewayProxyResult {
  return {
    statusCode,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
    body: JSON.stringify(body),
  };
}
```

### Step Functions State Machine

```typescript
// CDK: Step Functions
import * as sfn from "aws-cdk-lib/aws-stepfunctions";
import * as tasks from "aws-cdk-lib/aws-stepfunctions-tasks";

// Define state machine tasks
const validateOrder = new tasks.LambdaInvoke(this, "ValidateOrder", {
  lambdaFunction: validateOrderFunction,
  outputPath: "$.Payload",
  retryOnServiceExceptions: true,
});

const processPayment = new tasks.LambdaInvoke(this, "ProcessPayment", {
  lambdaFunction: paymentFunction,
  outputPath: "$.Payload",
});

const reserveInventory = new tasks.LambdaInvoke(this, "ReserveInventory", {
  lambdaFunction: inventoryFunction,
  outputPath: "$.Payload",
});

const sendConfirmation = new tasks.LambdaInvoke(this, "SendConfirmation", {
  lambdaFunction: notificationFunction,
  outputPath: "$.Payload",
});

const compensatePayment = new tasks.LambdaInvoke(this, "CompensatePayment", {
  lambdaFunction: refundFunction,
  outputPath: "$.Payload",
});

const orderFailed = new sfn.Fail(this, "OrderFailed", {
  cause: "Order processing failed",
});

const orderCompleted = new sfn.Succeed(this, "OrderCompleted");

// Define state machine
const definition = validateOrder
  .addCatch(orderFailed, { resultPath: "$.error" })
  .next(
    new sfn.Parallel(this, "ProcessInParallel")
      .branch(processPayment)
      .branch(reserveInventory)
      .addCatch(compensatePayment.next(orderFailed), {
        resultPath: "$.error",
      }),
  )
  .next(sendConfirmation)
  .next(orderCompleted);

const stateMachine = new sfn.StateMachine(this, "OrderStateMachine", {
  stateMachineName: `order-processing-${environment}`,
  definition,
  timeout: cdk.Duration.minutes(5),
  tracingEnabled: true,
  logs: {
    destination: new logs.LogGroup(this, "StateMachineLogs"),
    level: sfn.LogLevel.ALL,
    includeExecutionData: true,
  },
});
```

---

## S3 Storage Patterns

### Secure S3 Bucket with Lifecycle

```typescript
// CDK: S3 Bucket
import * as s3 from "aws-cdk-lib/aws-s3";
import * as kms from "aws-cdk-lib/aws-kms";
import * as iam from "aws-cdk-lib/aws-iam";
import * as cloudfront from "aws-cdk-lib/aws-cloudfront";
import * as origins from "aws-cdk-lib/aws-cloudfront-origins";

// KMS key for encryption
const bucketKey = new kms.Key(this, "BucketKey", {
  alias: `${environment}/s3/data`,
  enableKeyRotation: true,
  removalPolicy:
    environment === "prod"
      ? cdk.RemovalPolicy.RETAIN
      : cdk.RemovalPolicy.DESTROY,
});

// Data bucket with encryption and lifecycle
const dataBucket = new s3.Bucket(this, "DataBucket", {
  bucketName: `myapp-data-${environment}-${this.account}`,
  encryption: s3.BucketEncryption.KMS,
  encryptionKey: bucketKey,
  blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
  enforceSSL: true,
  versioned: true,
  objectOwnership: s3.ObjectOwnership.BUCKET_OWNER_ENFORCED,
  intelligentTieringConfigurations: [
    {
      name: "optimize-storage",
      archiveAccessTierTime: cdk.Duration.days(90),
      deepArchiveAccessTierTime: cdk.Duration.days(180),
    },
  ],
  lifecycleRules: [
    {
      id: "transition-to-ia",
      enabled: true,
      transitions: [
        {
          storageClass: s3.StorageClass.INFREQUENT_ACCESS,
          transitionAfter: cdk.Duration.days(30),
        },
        {
          storageClass: s3.StorageClass.GLACIER,
          transitionAfter: cdk.Duration.days(90),
        },
        {
          storageClass: s3.StorageClass.DEEP_ARCHIVE,
          transitionAfter: cdk.Duration.days(180),
        },
      ],
    },
    {
      id: "expire-old-versions",
      enabled: true,
      noncurrentVersionExpiration: cdk.Duration.days(90),
      noncurrentVersionTransitions: [
        {
          storageClass: s3.StorageClass.INFREQUENT_ACCESS,
          transitionAfter: cdk.Duration.days(30),
        },
      ],
    },
    {
      id: "delete-incomplete-uploads",
      enabled: true,
      abortIncompleteMultipartUploadAfter: cdk.Duration.days(7),
    },
    {
      id: "expire-temp-files",
      enabled: true,
      prefix: "temp/",
      expiration: cdk.Duration.days(1),
    },
  ],
  cors: [
    {
      allowedMethods: [
        s3.HttpMethods.GET,
        s3.HttpMethods.PUT,
        s3.HttpMethods.POST,
      ],
      allowedOrigins: ["https://myapp.com"],
      allowedHeaders: ["*"],
      maxAge: 3600,
    },
  ],
  serverAccessLogsPrefix: "access-logs/",
  removalPolicy:
    environment === "prod"
      ? cdk.RemovalPolicy.RETAIN
      : cdk.RemovalPolicy.DESTROY,
  autoDeleteObjects: environment !== "prod",
});

// Bucket policy for additional security
dataBucket.addToResourcePolicy(
  new iam.PolicyStatement({
    sid: "DenyInsecureTransport",
    effect: iam.Effect.DENY,
    principals: [new iam.AnyPrincipal()],
    actions: ["s3:*"],
    resources: [dataBucket.bucketArn, `${dataBucket.bucketArn}/*`],
    conditions: {
      Bool: { "aws:SecureTransport": "false" },
    },
  }),
);

dataBucket.addToResourcePolicy(
  new iam.PolicyStatement({
    sid: "DenyWrongKMSKey",
    effect: iam.Effect.DENY,
    principals: [new iam.AnyPrincipal()],
    actions: ["s3:PutObject"],
    resources: [`${dataBucket.bucketArn}/*`],
    conditions: {
      StringNotEquals: {
        "s3:x-amz-server-side-encryption-aws-kms-key-id": bucketKey.keyArn,
      },
    },
  }),
);

// Static assets bucket with CloudFront
const assetsBucket = new s3.Bucket(this, "AssetsBucket", {
  bucketName: `myapp-assets-${environment}-${this.account}`,
  encryption: s3.BucketEncryption.S3_MANAGED,
  blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
  enforceSSL: true,
  removalPolicy: cdk.RemovalPolicy.DESTROY,
  autoDeleteObjects: true,
});

// CloudFront distribution for static assets
const distribution = new cloudfront.Distribution(this, "AssetsDistribution", {
  defaultBehavior: {
    origin: new origins.S3Origin(assetsBucket),
    viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
    cachePolicy: cloudfront.CachePolicy.CACHING_OPTIMIZED,
    compress: true,
    allowedMethods: cloudfront.AllowedMethods.ALLOW_GET_HEAD_OPTIONS,
  },
  additionalBehaviors: {
    "/api/*": {
      origin: new origins.HttpOrigin(`api.${domain}`),
      viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.HTTPS_ONLY,
      cachePolicy: cloudfront.CachePolicy.CACHING_DISABLED,
      originRequestPolicy:
        cloudfront.OriginRequestPolicy.ALL_VIEWER_EXCEPT_HOST_HEADER,
      allowedMethods: cloudfront.AllowedMethods.ALLOW_ALL,
    },
  },
  priceClass: cloudfront.PriceClass.PRICE_CLASS_100,
  httpVersion: cloudfront.HttpVersion.HTTP2_AND_3,
  minimumProtocolVersion: cloudfront.SecurityPolicyProtocol.TLS_V1_2_2021,
  enableLogging: true,
  logBucket: logBucket,
  logFilePrefix: "cloudfront/",
  geoRestriction: cloudfront.GeoRestriction.allowlist("US", "CA", "GB", "DE"),
  webAclId: wafWebAcl.attrArn,
});
```

---

## VPC and Networking

### Advanced VPC with Transit Gateway

```typescript
// CDK: Advanced Networking
import * as ec2 from "aws-cdk-lib/aws-ec2";

// Transit Gateway for multi-VPC connectivity
const transitGateway = new ec2.CfnTransitGateway(this, "TransitGateway", {
  description: "Central transit gateway",
  autoAcceptSharedAttachments: "enable",
  defaultRouteTableAssociation: "enable",
  defaultRouteTablePropagation: "enable",
  vpnEcmpSupport: "enable",
  dnsSupport: "enable",
  tags: [{ key: "Name", value: `tgw-${environment}` }],
});

// Attach VPC to Transit Gateway
const tgwAttachment = new ec2.CfnTransitGatewayAttachment(
  this,
  "TgwAttachment",
  {
    transitGatewayId: transitGateway.ref,
    vpcId: vpc.vpcId,
    subnetIds: vpc.privateSubnets.map((s) => s.subnetId),
    tags: [{ key: "Name", value: `tgw-attach-${environment}` }],
  },
);

// Network Load Balancer for high-performance TCP
const nlb = new elbv2.NetworkLoadBalancer(this, "NLB", {
  vpc,
  internetFacing: false,
  crossZoneEnabled: true,
  vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS },
});

const nlbListener = nlb.addListener("NLBListener", {
  port: 443,
  protocol: elbv2.Protocol.TLS,
  certificates: [certificate],
});

// Security Group with strict rules
const appSecurityGroup = new ec2.SecurityGroup(this, "AppSecurityGroup", {
  vpc,
  description: "Security group for application tier",
  allowAllOutbound: false,
});

// Allow inbound from ALB only
appSecurityGroup.addIngressRule(
  ec2.Peer.securityGroupId(albSecurityGroup.securityGroupId),
  ec2.Port.tcp(3000),
  "Allow from ALB",
);

// Allow outbound to specific services only
appSecurityGroup.addEgressRule(
  ec2.Peer.prefixList(s3PrefixList),
  ec2.Port.tcp(443),
  "Allow S3 access",
);

appSecurityGroup.addEgressRule(
  ec2.Peer.ipv4(vpc.vpcCidrBlock),
  ec2.Port.tcp(5432),
  "Allow database access",
);

// Network ACL for subnet-level security
const privateNacl = new ec2.NetworkAcl(this, "PrivateNacl", {
  vpc,
  subnetSelection: { subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS },
});

privateNacl.addEntry("AllowInboundFromVpc", {
  ruleNumber: 100,
  cidr: ec2.AclCidr.ipv4(vpc.vpcCidrBlock),
  traffic: ec2.AclTraffic.allTraffic(),
  direction: ec2.TrafficDirection.INGRESS,
  ruleAction: ec2.Action.ALLOW,
});

privateNacl.addEntry("AllowOutboundHttps", {
  ruleNumber: 100,
  cidr: ec2.AclCidr.anyIpv4(),
  traffic: ec2.AclTraffic.tcpPort(443),
  direction: ec2.TrafficDirection.EGRESS,
  ruleAction: ec2.Action.ALLOW,
});

// AWS PrivateLink for API Gateway
const apiGatewayEndpoint = vpc.addInterfaceEndpoint("ApiGatewayEndpoint", {
  service: ec2.InterfaceVpcEndpointAwsService.APIGATEWAY,
  privateDnsEnabled: true,
  subnets: { subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS },
});
```

---

## IAM and Security Best Practices

### IAM Roles and Policies

```typescript
// CDK: IAM Security
import * as iam from "aws-cdk-lib/aws-iam";
import * as kms from "aws-cdk-lib/aws-kms";
import * as secretsmanager from "aws-cdk-lib/aws-secretsmanager";

// Application Role with least privilege
const appRole = new iam.Role(this, "AppRole", {
  assumedBy: new iam.ServicePrincipal("ecs-tasks.amazonaws.com"),
  description: "Role for application tasks",
  maxSessionDuration: cdk.Duration.hours(1),
});

// Managed policy for common permissions
const appPolicy = new iam.ManagedPolicy(this, "AppPolicy", {
  managedPolicyName: `app-policy-${environment}`,
  description: "Application permissions",
  statements: [
    // DynamoDB permissions (specific tables only)
    new iam.PolicyStatement({
      sid: "DynamoDBAccess",
      effect: iam.Effect.ALLOW,
      actions: [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan",
      ],
      resources: [ordersTable.tableArn, `${ordersTable.tableArn}/index/*`],
      conditions: {
        "ForAllValues:StringEquals": {
          "dynamodb:LeadingKeys": ["${aws:userid}"],
        },
      },
    }),
    // S3 permissions (specific bucket and prefix)
    new iam.PolicyStatement({
      sid: "S3Access",
      effect: iam.Effect.ALLOW,
      actions: ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      resources: [`${dataBucket.bucketArn}/data/*`],
    }),
    // SQS permissions
    new iam.PolicyStatement({
      sid: "SQSAccess",
      effect: iam.Effect.ALLOW,
      actions: ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage"],
      resources: [processingQueue.queueArn],
    }),
    // CloudWatch Logs
    new iam.PolicyStatement({
      sid: "CloudWatchLogs",
      effect: iam.Effect.ALLOW,
      actions: ["logs:CreateLogStream", "logs:PutLogEvents"],
      resources: [`${logGroup.logGroupArn}:*`],
    }),
    // X-Ray tracing
    new iam.PolicyStatement({
      sid: "XRayTracing",
      effect: iam.Effect.ALLOW,
      actions: ["xray:PutTraceSegments", "xray:PutTelemetryRecords"],
      resources: ["*"],
    }),
  ],
});

appRole.addManagedPolicy(appPolicy);

// Secrets Manager access
const dbSecret = new secretsmanager.Secret(this, "DbSecret", {
  secretName: `${environment}/db/credentials`,
  generateSecretString: {
    secretStringTemplate: JSON.stringify({ username: "admin" }),
    generateStringKey: "password",
    excludePunctuation: true,
    passwordLength: 32,
  },
});

dbSecret.grantRead(appRole);

// KMS key access
const kmsKey = new kms.Key(this, "AppKey", {
  alias: `${environment}/app/encryption`,
  enableKeyRotation: true,
});

kmsKey.grantEncryptDecrypt(appRole);

// Service-linked role for AWS services
const serviceLinkRole = new iam.CfnServiceLinkedRole(
  this,
  "ECSServiceLinkedRole",
  {
    awsServiceName: "ecs.amazonaws.com",
    description: "Service-linked role for ECS",
  },
);

// Permission boundary for defense in depth
const permissionBoundary = new iam.ManagedPolicy(this, "PermissionBoundary", {
  managedPolicyName: `permission-boundary-${environment}`,
  statements: [
    new iam.PolicyStatement({
      sid: "DenyIAMChanges",
      effect: iam.Effect.DENY,
      actions: [
        "iam:CreateUser",
        "iam:DeleteUser",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
      ],
      resources: ["*"],
    }),
    new iam.PolicyStatement({
      sid: "DenyKMSKeyDeletion",
      effect: iam.Effect.DENY,
      actions: ["kms:ScheduleKeyDeletion", "kms:DeleteKey"],
      resources: ["*"],
    }),
    new iam.PolicyStatement({
      sid: "AllowEverythingElse",
      effect: iam.Effect.ALLOW,
      actions: ["*"],
      resources: ["*"],
    }),
  ],
});

iam.PermissionsBoundary.of(appRole).apply(permissionBoundary);
```

### AWS WAF Configuration

```typescript
// CDK: WAF
import * as wafv2 from "aws-cdk-lib/aws-wafv2";

const webAcl = new wafv2.CfnWebACL(this, "WebACL", {
  name: `app-waf-${environment}`,
  scope: "REGIONAL",
  defaultAction: { allow: {} },
  visibilityConfig: {
    cloudWatchMetricsEnabled: true,
    metricName: `app-waf-${environment}`,
    sampledRequestsEnabled: true,
  },
  rules: [
    // AWS Managed Rules - Common Rule Set
    {
      name: "AWSManagedRulesCommonRuleSet",
      priority: 1,
      overrideAction: { none: {} },
      statement: {
        managedRuleGroupStatement: {
          vendorName: "AWS",
          name: "AWSManagedRulesCommonRuleSet",
          excludedRules: [],
        },
      },
      visibilityConfig: {
        cloudWatchMetricsEnabled: true,
        metricName: "CommonRuleSet",
        sampledRequestsEnabled: true,
      },
    },
    // AWS Managed Rules - Known Bad Inputs
    {
      name: "AWSManagedRulesKnownBadInputsRuleSet",
      priority: 2,
      overrideAction: { none: {} },
      statement: {
        managedRuleGroupStatement: {
          vendorName: "AWS",
          name: "AWSManagedRulesKnownBadInputsRuleSet",
        },
      },
      visibilityConfig: {
        cloudWatchMetricsEnabled: true,
        metricName: "KnownBadInputs",
        sampledRequestsEnabled: true,
      },
    },
    // AWS Managed Rules - SQL Injection
    {
      name: "AWSManagedRulesSQLiRuleSet",
      priority: 3,
      overrideAction: { none: {} },
      statement: {
        managedRuleGroupStatement: {
          vendorName: "AWS",
          name: "AWSManagedRulesSQLiRuleSet",
        },
      },
      visibilityConfig: {
        cloudWatchMetricsEnabled: true,
        metricName: "SQLiRuleSet",
        sampledRequestsEnabled: true,
      },
    },
    // Rate limiting
    {
      name: "RateLimitRule",
      priority: 10,
      action: { block: {} },
      statement: {
        rateBasedStatement: {
          limit: 2000,
          aggregateKeyType: "IP",
        },
      },
      visibilityConfig: {
        cloudWatchMetricsEnabled: true,
        metricName: "RateLimit",
        sampledRequestsEnabled: true,
      },
    },
    // Geo restriction (if needed)
    {
      name: "GeoBlockRule",
      priority: 20,
      action: { block: {} },
      statement: {
        geoMatchStatement: {
          countryCodes: ["RU", "CN", "KP"],
        },
      },
      visibilityConfig: {
        cloudWatchMetricsEnabled: true,
        metricName: "GeoBlock",
        sampledRequestsEnabled: true,
      },
    },
  ],
});

// Associate WAF with ALB
new wafv2.CfnWebACLAssociation(this, "WebACLAssociation", {
  resourceArn: alb.loadBalancerArn,
  webAclArn: webAcl.attrArn,
});
```

---

## CloudWatch Monitoring and Observability

### Comprehensive Monitoring Setup

```typescript
// CDK: CloudWatch Monitoring
import * as cloudwatch from "aws-cdk-lib/aws-cloudwatch";
import * as sns from "aws-cdk-lib/aws-sns";
import * as subscriptions from "aws-cdk-lib/aws-sns-subscriptions";
import * as cloudwatch_actions from "aws-cdk-lib/aws-cloudwatch-actions";

// SNS Topic for alerts
const alertTopic = new sns.Topic(this, "AlertTopic", {
  topicName: `alerts-${environment}`,
  displayName: `${environment.toUpperCase()} Alerts`,
});

// Email subscription
alertTopic.addSubscription(
  new subscriptions.EmailSubscription("devops@company.com"),
);

// Dashboard
const dashboard = new cloudwatch.Dashboard(this, "AppDashboard", {
  dashboardName: `app-dashboard-${environment}`,
  periodOverride: cloudwatch.PeriodOverride.AUTO,
});

// API Gateway metrics
const apiLatencyWidget = new cloudwatch.GraphWidget({
  title: "API Latency",
  left: [
    new cloudwatch.Metric({
      namespace: "AWS/ApiGateway",
      metricName: "Latency",
      dimensionsMap: { ApiName: api.restApiName },
      statistic: "p50",
      period: cdk.Duration.minutes(1),
      label: "p50",
    }),
    new cloudwatch.Metric({
      namespace: "AWS/ApiGateway",
      metricName: "Latency",
      dimensionsMap: { ApiName: api.restApiName },
      statistic: "p90",
      period: cdk.Duration.minutes(1),
      label: "p90",
    }),
    new cloudwatch.Metric({
      namespace: "AWS/ApiGateway",
      metricName: "Latency",
      dimensionsMap: { ApiName: api.restApiName },
      statistic: "p99",
      period: cdk.Duration.minutes(1),
      label: "p99",
    }),
  ],
});

const apiErrorsWidget = new cloudwatch.GraphWidget({
  title: "API Errors",
  left: [
    new cloudwatch.Metric({
      namespace: "AWS/ApiGateway",
      metricName: "4XXError",
      dimensionsMap: { ApiName: api.restApiName },
      statistic: "Sum",
      period: cdk.Duration.minutes(1),
    }),
    new cloudwatch.Metric({
      namespace: "AWS/ApiGateway",
      metricName: "5XXError",
      dimensionsMap: { ApiName: api.restApiName },
      statistic: "Sum",
      period: cdk.Duration.minutes(1),
    }),
  ],
});

// Lambda metrics
const lambdaWidget = new cloudwatch.GraphWidget({
  title: "Lambda Performance",
  left: [
    apiHandler.metricDuration({ statistic: "p50" }),
    apiHandler.metricDuration({ statistic: "p95" }),
  ],
  right: [apiHandler.metricErrors(), apiHandler.metricThrottles()],
});

// DynamoDB metrics
const dynamoWidget = new cloudwatch.GraphWidget({
  title: "DynamoDB Performance",
  left: [
    ordersTable.metricConsumedReadCapacityUnits(),
    ordersTable.metricConsumedWriteCapacityUnits(),
  ],
  right: [
    ordersTable.metric("SuccessfulRequestLatency", {
      dimensionsMap: { Operation: "GetItem" },
      statistic: "Average",
    }),
    ordersTable.metric("SuccessfulRequestLatency", {
      dimensionsMap: { Operation: "Query" },
      statistic: "Average",
    }),
  ],
});

// ECS metrics
const ecsWidget = new cloudwatch.GraphWidget({
  title: "ECS Service Health",
  left: [
    service.service.metricCpuUtilization(),
    service.service.metricMemoryUtilization(),
  ],
  right: [
    new cloudwatch.Metric({
      namespace: "AWS/ECS",
      metricName: "RunningTaskCount",
      dimensionsMap: {
        ClusterName: cluster.clusterName,
        ServiceName: service.service.serviceName,
      },
    }),
  ],
});

// Add widgets to dashboard
dashboard.addWidgets(
  apiLatencyWidget,
  apiErrorsWidget,
  lambdaWidget,
  dynamoWidget,
  ecsWidget,
);

// Alarms
const highLatencyAlarm = new cloudwatch.Alarm(this, "HighLatencyAlarm", {
  alarmName: `${environment}-high-latency`,
  alarmDescription: "API latency is too high",
  metric: new cloudwatch.Metric({
    namespace: "AWS/ApiGateway",
    metricName: "Latency",
    dimensionsMap: { ApiName: api.restApiName },
    statistic: "p95",
    period: cdk.Duration.minutes(5),
  }),
  threshold: 3000,
  evaluationPeriods: 3,
  comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
  treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
});

highLatencyAlarm.addAlarmAction(new cloudwatch_actions.SnsAction(alertTopic));

const errorRateAlarm = new cloudwatch.Alarm(this, "ErrorRateAlarm", {
  alarmName: `${environment}-error-rate`,
  alarmDescription: "Error rate is too high",
  metric: new cloudwatch.MathExpression({
    expression: "(errors / requests) * 100",
    usingMetrics: {
      errors: new cloudwatch.Metric({
        namespace: "AWS/ApiGateway",
        metricName: "5XXError",
        dimensionsMap: { ApiName: api.restApiName },
        statistic: "Sum",
        period: cdk.Duration.minutes(5),
      }),
      requests: new cloudwatch.Metric({
        namespace: "AWS/ApiGateway",
        metricName: "Count",
        dimensionsMap: { ApiName: api.restApiName },
        statistic: "Sum",
        period: cdk.Duration.minutes(5),
      }),
    },
    period: cdk.Duration.minutes(5),
  }),
  threshold: 5,
  evaluationPeriods: 2,
  comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
});

errorRateAlarm.addAlarmAction(new cloudwatch_actions.SnsAction(alertTopic));

// Lambda error alarm
const lambdaErrorAlarm = apiHandler
  .metricErrors()
  .createAlarm(this, "LambdaErrorAlarm", {
    alarmName: `${environment}-lambda-errors`,
    threshold: 10,
    evaluationPeriods: 2,
    comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
  });

lambdaErrorAlarm.addAlarmAction(new cloudwatch_actions.SnsAction(alertTopic));

// Composite alarm for critical alerts
const criticalAlarm = new cloudwatch.CompositeAlarm(this, "CriticalAlarm", {
  compositeAlarmName: `${environment}-critical`,
  alarmRule: cloudwatch.AlarmRule.anyOf(
    cloudwatch.AlarmRule.fromAlarm(
      highLatencyAlarm,
      cloudwatch.AlarmState.ALARM,
    ),
    cloudwatch.AlarmRule.fromAlarm(errorRateAlarm, cloudwatch.AlarmState.ALARM),
  ),
});

criticalAlarm.addAlarmAction(new cloudwatch_actions.SnsAction(alertTopic));
```

---

## Cost Optimization Strategies

### Cost Optimization Table

| Strategy                   | Savings   | Implementation                                    |
| -------------------------- | --------- | ------------------------------------------------- |
| **Savings Plans**          | Up to 72% | 1-3 year commitment for consistent compute usage  |
| **Reserved Instances**     | Up to 75% | 1-3 year commitment for specific instance types   |
| **Spot Instances**         | Up to 90% | For fault-tolerant, interruptible workloads       |
| **Graviton Processors**    | 20-40%    | ARM-based instances with better price/performance |
| **S3 Intelligent-Tiering** | 40%+      | Automatic storage class optimization              |
| **Lambda Arm64**           | 20%       | ARM architecture for Lambda functions             |
| **DynamoDB On-Demand**     | Variable  | Pay-per-request for unpredictable workloads       |
| **NAT Gateway Reduction**  | $45+/mo   | Use VPC endpoints instead of NAT for AWS services |
| **Right-sizing**           | 20-40%    | Match instance size to actual resource usage      |
| **Auto Scaling**           | Variable  | Scale down during low-traffic periods             |

### Cost Optimization CDK

```typescript
// CDK: Cost Optimization
import * as budgets from "aws-cdk-lib/aws-budgets";

// Budget alert
new budgets.CfnBudget(this, "MonthlyBudget", {
  budget: {
    budgetName: `monthly-budget-${environment}`,
    budgetType: "COST",
    timeUnit: "MONTHLY",
    budgetLimit: {
      amount: environment === "prod" ? 5000 : 500,
      unit: "USD",
    },
  },
  notificationsWithSubscribers: [
    {
      notification: {
        notificationType: "ACTUAL",
        comparisonOperator: "GREATER_THAN",
        threshold: 80,
        thresholdType: "PERCENTAGE",
      },
      subscribers: [
        {
          subscriptionType: "EMAIL",
          address: "finance@company.com",
        },
      ],
    },
    {
      notification: {
        notificationType: "FORECASTED",
        comparisonOperator: "GREATER_THAN",
        threshold: 100,
        thresholdType: "PERCENTAGE",
      },
      subscribers: [
        {
          subscriptionType: "EMAIL",
          address: "finance@company.com",
        },
      ],
    },
  ],
});

// Cost Allocation Tags
cdk.Tags.of(this).add("CostCenter", "engineering");
cdk.Tags.of(this).add("Project", "myapp");
cdk.Tags.of(this).add("Environment", environment);
cdk.Tags.of(this).add("Owner", "platform-team");

// Use Graviton instances for cost savings
const gravitonInstances = [
  ec2.InstanceType.of(ec2.InstanceClass.M7G, ec2.InstanceSize.LARGE),
  ec2.InstanceType.of(ec2.InstanceClass.C7G, ec2.InstanceSize.LARGE),
  ec2.InstanceType.of(ec2.InstanceClass.R7G, ec2.InstanceSize.LARGE),
];

// Spot instances for non-critical workloads
const spotFleet = new ec2.CfnSpotFleet(this, "SpotFleet", {
  spotFleetRequestConfigData: {
    iamFleetRole: spotFleetRole.roleArn,
    targetCapacity: 10,
    allocationStrategy: "capacityOptimized",
    launchTemplateConfigs: [
      {
        launchTemplateSpecification: {
          launchTemplateId: launchTemplate.launchTemplateId,
          version: "$Latest",
        },
        overrides: gravitonInstances.map((instanceType) => ({
          instanceType: instanceType.toString(),
        })),
      },
    ],
    instanceInterruptionBehavior: "terminate",
    replaceUnhealthyInstances: true,
    terminateInstancesWithExpiration: true,
  },
});
```

### Cost Analysis Script

```bash
#!/bin/bash
# AWS Cost Analysis Script

# Get current month costs by service
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics "UnblendedCost" \
  --group-by Type=DIMENSION,Key=SERVICE \
  --query 'ResultsByTime[0].Groups[*].[Keys[0],Metrics.UnblendedCost.Amount]' \
  --output table

# Get cost forecast
aws ce get-cost-forecast \
  --time-period Start=$(date +%Y-%m-%d),End=$(date -d "$(date +%Y-%m-01) +1 month -1 day" +%Y-%m-%d) \
  --metric UNBLENDED_COST \
  --granularity MONTHLY

# Get Savings Plans recommendations
aws ce get-savings-plans-purchase-recommendation \
  --savings-plans-type COMPUTE_SP \
  --term-in-years ONE_YEAR \
  --payment-option NO_UPFRONT \
  --lookback-period-in-days THIRTY_DAYS

# Get rightsizing recommendations
aws ce get-rightsizing-recommendation \
  --service AmazonEC2 \
  --query 'RightsizingRecommendations[*].{Instance:CurrentInstance.ResourceId,Recommendation:ModifyRecommendationDetail.TargetInstances[0].EstimatedMonthlySavings}'

# List unused resources
echo "=== Unattached EBS Volumes ==="
aws ec2 describe-volumes \
  --filters "Name=status,Values=available" \
  --query 'Volumes[*].{VolumeId:VolumeId,Size:Size,Created:CreateTime}' \
  --output table

echo "=== Unused Elastic IPs ==="
aws ec2 describe-addresses \
  --query 'Addresses[?AssociationId==`null`].{IP:PublicIp,AllocationId:AllocationId}' \
  --output table

echo "=== Idle Load Balancers ==="
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[*].LoadBalancerArn' \
  --output text | xargs -I {} aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name RequestCount \
  --dimensions Name=LoadBalancer,Value={} \
  --start-time $(date -d "7 days ago" +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date +%Y-%m-%dT%H:%M:%S) \
  --period 604800 \
  --statistics Sum
```

---

## Well-Architected Framework Compliance

### Six Pillars Checklist

| Pillar                     | Key Practices                                       |
| -------------------------- | --------------------------------------------------- |
| **Operational Excellence** | IaC, CI/CD, monitoring, runbooks, incident response |
| **Security**               | IAM least privilege, encryption, WAF, VPC isolation |
| **Reliability**            | Multi-AZ, auto-scaling, backups, disaster recovery  |
| **Performance Efficiency** | Right-sizing, caching, CDN, async processing        |
| **Cost Optimization**      | Savings Plans, Spot, auto-scaling, monitoring       |
| **Sustainability**         | Efficient code, right-sizing, serverless, Graviton  |

### Well-Architected Review Automation

```typescript
// CDK: Well-Architected Compliance Checks
import * as config from "aws-cdk-lib/aws-config";

// AWS Config Rules for compliance
const rules = [
  // Security pillar
  new config.ManagedRule(this, "S3BucketSSLRequestsOnly", {
    identifier: "S3_BUCKET_SSL_REQUESTS_ONLY",
    configRuleName: "s3-bucket-ssl-requests-only",
  }),
  new config.ManagedRule(this, "EncryptedVolumes", {
    identifier: "ENCRYPTED_VOLUMES",
    configRuleName: "encrypted-volumes",
  }),
  new config.ManagedRule(this, "RDSEncryptionEnabled", {
    identifier: "RDS_STORAGE_ENCRYPTED",
    configRuleName: "rds-storage-encrypted",
  }),
  new config.ManagedRule(this, "IAMUserMFAEnabled", {
    identifier: "IAM_USER_MFA_ENABLED",
    configRuleName: "iam-user-mfa-enabled",
  }),
  new config.ManagedRule(this, "RootAccountMFAEnabled", {
    identifier: "ROOT_ACCOUNT_MFA_ENABLED",
    configRuleName: "root-account-mfa-enabled",
  }),
  new config.ManagedRule(this, "VPCFlowLogsEnabled", {
    identifier: "VPC_FLOW_LOGS_ENABLED",
    configRuleName: "vpc-flow-logs-enabled",
  }),
  // Reliability pillar
  new config.ManagedRule(this, "RDSMultiAZSupport", {
    identifier: "RDS_MULTI_AZ_SUPPORT",
    configRuleName: "rds-multi-az-support",
  }),
  new config.ManagedRule(this, "AutoScalingGroupELBHealthcheck", {
    identifier: "AUTOSCALING_GROUP_ELB_HEALTHCHECK_REQUIRED",
    configRuleName: "autoscaling-group-elb-healthcheck-required",
  }),
  new config.ManagedRule(this, "DynamoDBPITREnabled", {
    identifier: "DYNAMODB_PITR_ENABLED",
    configRuleName: "dynamodb-pitr-enabled",
  }),
  // Cost optimization pillar
  new config.ManagedRule(this, "EC2InstanceNoPublicIP", {
    identifier: "EC2_INSTANCE_NO_PUBLIC_IP",
    configRuleName: "ec2-instance-no-public-ip",
  }),
];

// Conformance Pack for comprehensive checks
new config.CfnConformancePack(this, "WAFRConformancePack", {
  conformancePackName: "well-architected-framework",
  templateBody: JSON.stringify({
    Resources: {
      S3BucketPublicReadProhibited: {
        Type: "AWS::Config::ConfigRule",
        Properties: {
          ConfigRuleName: "s3-bucket-public-read-prohibited",
          Source: {
            Owner: "AWS",
            SourceIdentifier: "S3_BUCKET_PUBLIC_READ_PROHIBITED",
          },
        },
      },
      S3BucketPublicWriteProhibited: {
        Type: "AWS::Config::ConfigRule",
        Properties: {
          ConfigRuleName: "s3-bucket-public-write-prohibited",
          Source: {
            Owner: "AWS",
            SourceIdentifier: "S3_BUCKET_PUBLIC_WRITE_PROHIBITED",
          },
        },
      },
    },
  }),
});
```

---

## CI/CD with AWS CodePipeline

### Complete Pipeline

```typescript
// CDK: CodePipeline
import * as codepipeline from "aws-cdk-lib/aws-codepipeline";
import * as codepipeline_actions from "aws-cdk-lib/aws-codepipeline-actions";
import * as codebuild from "aws-cdk-lib/aws-codebuild";
import * as codecommit from "aws-cdk-lib/aws-codecommit";
import * as ecr from "aws-cdk-lib/aws-ecr";

// Source: CodeCommit or GitHub
const sourceOutput = new codepipeline.Artifact("SourceOutput");
const buildOutput = new codepipeline.Artifact("BuildOutput");

// CodeBuild project
const buildProject = new codebuild.PipelineProject(this, "BuildProject", {
  projectName: `app-build-${environment}`,
  environment: {
    buildImage: codebuild.LinuxArmBuildImage.AMAZON_LINUX_2_STANDARD_3_0,
    computeType: codebuild.ComputeType.MEDIUM,
    privileged: true, // For Docker builds
  },
  environmentVariables: {
    AWS_ACCOUNT_ID: { value: this.account },
    AWS_REGION: { value: this.region },
    ENVIRONMENT: { value: environment },
    ECR_REPOSITORY: { value: repository.repositoryUri },
  },
  buildSpec: codebuild.BuildSpec.fromObject({
    version: "0.2",
    phases: {
      install: {
        "runtime-versions": {
          nodejs: "20",
        },
        commands: ["npm ci"],
      },
      pre_build: {
        commands: [
          "echo Logging in to ECR...",
          "aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com",
          "COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)",
          "IMAGE_TAG=${COMMIT_HASH:=latest}",
        ],
      },
      build: {
        commands: [
          "echo Running tests...",
          "npm run test -- --coverage",
          "echo Building application...",
          "npm run build",
          "echo Building Docker image...",
          "docker build -t $ECR_REPOSITORY:$IMAGE_TAG .",
          "docker tag $ECR_REPOSITORY:$IMAGE_TAG $ECR_REPOSITORY:latest",
        ],
      },
      post_build: {
        commands: [
          "echo Pushing Docker image...",
          "docker push $ECR_REPOSITORY:$IMAGE_TAG",
          "docker push $ECR_REPOSITORY:latest",
          "echo Writing image definitions file...",
          'printf \'[{"name":"app","imageUri":"%s"}]\' $ECR_REPOSITORY:$IMAGE_TAG > imagedefinitions.json',
        ],
      },
    },
    reports: {
      "test-reports": {
        files: ["coverage/clover.xml"],
        "file-format": "CLOVERXML",
      },
    },
    artifacts: {
      files: ["imagedefinitions.json"],
    },
    cache: {
      paths: ["node_modules/**/*"],
    },
  }),
  cache: codebuild.Cache.local(codebuild.LocalCacheMode.DOCKER_LAYER),
});

// Grant ECR permissions
repository.grantPullPush(buildProject);

// Pipeline
const pipeline = new codepipeline.Pipeline(this, "Pipeline", {
  pipelineName: `app-pipeline-${environment}`,
  crossAccountKeys: false,
  stages: [
    {
      stageName: "Source",
      actions: [
        new codepipeline_actions.CodeStarConnectionsSourceAction({
          actionName: "GitHub",
          owner: "myorg",
          repo: "myapp",
          branch: environment === "prod" ? "main" : "develop",
          output: sourceOutput,
          connectionArn: githubConnection.attrConnectionArn,
        }),
      ],
    },
    {
      stageName: "Build",
      actions: [
        new codepipeline_actions.CodeBuildAction({
          actionName: "Build",
          project: buildProject,
          input: sourceOutput,
          outputs: [buildOutput],
        }),
      ],
    },
    {
      stageName: "Deploy-Staging",
      actions: [
        new codepipeline_actions.EcsDeployAction({
          actionName: "Deploy",
          service: stagingService.service,
          input: buildOutput,
        }),
      ],
    },
    {
      stageName: "Approval",
      actions: [
        new codepipeline_actions.ManualApprovalAction({
          actionName: "Approve",
          notificationTopic: alertTopic,
          additionalInformation:
            "Please review staging deployment before promoting to production",
        }),
      ],
    },
    {
      stageName: "Deploy-Production",
      actions: [
        new codepipeline_actions.EcsDeployAction({
          actionName: "Deploy",
          service: productionService.service,
          input: buildOutput,
          deploymentTimeout: cdk.Duration.minutes(30),
        }),
      ],
    },
  ],
});

// Pipeline notifications
pipeline.notifyOn("PipelineNotifications", alertTopic, {
  events: [
    codepipeline.PipelineNotificationEvents.PIPELINE_EXECUTION_FAILED,
    codepipeline.PipelineNotificationEvents.PIPELINE_EXECUTION_SUCCEEDED,
    codepipeline.PipelineNotificationEvents.MANUAL_APPROVAL_NEEDED,
  ],
});
```

---

## Example Usage

```bash
# Design AWS landing zone
/agents/cloud/aws-expert design multi-account landing zone with Control Tower and Organizations

# Create EKS cluster with best practices
/agents/cloud/aws-expert create production-ready EKS cluster with Karpenter auto-scaling

# Implement serverless architecture
/agents/cloud/aws-expert design event-driven architecture with Lambda, SQS, and EventBridge

# Set up CI/CD pipeline
/agents/cloud/aws-expert create CodePipeline for containerized application with blue-green deployment

# Configure IAM security
/agents/cloud/aws-expert implement least-privilege IAM policies with permission boundaries

# Design networking solution
/agents/cloud/aws-expert design Transit Gateway architecture for multi-VPC connectivity

# Implement storage solution
/agents/cloud/aws-expert design S3 data lake with lifecycle policies and cross-region replication

# Optimize costs
/agents/cloud/aws-expert analyze and optimize AWS costs using Compute Optimizer and Cost Explorer

# Set up security
/agents/cloud/aws-expert configure AWS Security Hub with GuardDuty and Config rules

# Configure monitoring
/agents/cloud/aws-expert set up comprehensive observability with CloudWatch, X-Ray, and Container Insights
```

---

## Related Agents

| Agent                                 | Use Case                             |
| ------------------------------------- | ------------------------------------ |
| `/agents/devops/kubernetes-expert`    | EKS workload deployment, Helm charts |
| `/agents/devops/devops-engineer`      | Pipeline design, automation          |
| `/agents/devops/terraform-expert`     | Multi-cloud IaC, Terraform modules   |
| `/agents/security/security-expert`    | Security review, compliance          |
| `/agents/cloud/multi-cloud-expert`    | Cross-cloud architecture             |
| `/agents/database/database-architect` | RDS, Aurora, DynamoDB design         |
| `/agents/devops/monitoring-expert`    | Observability, alerting              |

---

## Quick Reference

```bash
# AWS CLI Quick Commands

# Configure credentials
aws configure
aws sts get-caller-identity

# EC2
aws ec2 describe-instances --filters "Name=tag:Environment,Values=prod"
aws ec2 start-instances --instance-ids i-1234567890abcdef0

# ECS
aws ecs list-clusters
aws ecs update-service --cluster my-cluster --service my-service --force-new-deployment

# Lambda
aws lambda invoke --function-name my-function output.json
aws lambda update-function-code --function-name my-function --zip-file fileb://function.zip

# S3
aws s3 sync ./dist s3://my-bucket/
aws s3api put-bucket-versioning --bucket my-bucket --versioning-configuration Status=Enabled

# RDS
aws rds describe-db-instances
aws rds create-db-snapshot --db-instance-identifier my-db --db-snapshot-identifier my-snapshot

# CloudFormation
aws cloudformation deploy --template-file template.yaml --stack-name my-stack --capabilities CAPABILITY_IAM
aws cloudformation describe-stack-events --stack-name my-stack

# CDK
cdk bootstrap
cdk synth
cdk diff
cdk deploy --all

# Secrets Manager
aws secretsmanager get-secret-value --secret-id my-secret
aws secretsmanager create-secret --name my-secret --secret-string '{"key":"value"}'

# CloudWatch
aws logs tail /aws/lambda/my-function --follow
aws cloudwatch get-metric-statistics --namespace AWS/EC2 --metric-name CPUUtilization --dimensions Name=InstanceId,Value=i-xxx --start-time 2024-01-01T00:00:00Z --end-time 2024-01-02T00:00:00Z --period 3600 --statistics Average

# Cost Explorer
aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-01-31 --granularity MONTHLY --metrics "UnblendedCost"
```

---

Ahmed Adel Bakr Alderai
