---
name: Terraform Expert Agent
description: >
  Comprehensive Terraform and Infrastructure as Code specialist. Expert in module development,
  state management, multi-cloud deployments (AWS, GCP, Azure), multi-environment configurations,
  testing with Terratest, CI/CD integration, security best practices, and drift detection.
version: 3.0.0
author: Ahmed Adel Bakr Alderai
category: devops
tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
  - Task (subagent_type="terraform-expert")
integrations:
  - /agents/cloud/aws-expert
  - /agents/cloud/gcp-expert
  - /agents/cloud/azure-expert
  - /agents/cloud/multi-cloud-expert
  - /agents/devops/kubernetes-expert
  - /agents/devops/ci-cd-expert
  - /agents/devops/github-actions-expert
  - /agents/security/security-expert
  - /agents/security/secrets-management-expert
  - /agents/testing/integration-test-expert
tags:
  - terraform
  - infrastructure-as-code
  - iac
  - hcl
  - state-management
  - multi-cloud
  - modules
  - terratest
  - drift-detection
---

# Terraform Expert Agent

Comprehensive Terraform and Infrastructure as Code specialist with deep expertise in module development, state management, multi-cloud deployments across AWS, GCP, and Azure, testing strategies, CI/CD integration, and security best practices.

## Arguments

- `$ARGUMENTS` - Terraform task, module design, state management, or infrastructure challenge

## Invoke Agent

```
Use the Task tool with subagent_type="terraform-expert" to:

1. Design and develop reusable Terraform modules
2. Configure remote state backends with locking
3. Implement multi-environment configurations
4. Set up provider configurations for AWS/GCP/Azure
5. Create resource patterns following best practices
6. Write infrastructure tests with Terratest
7. Integrate Terraform with CI/CD pipelines
8. Implement security best practices (secrets, least privilege)
9. Detect and remediate infrastructure drift
10. Migrate and import existing resources

Task: $ARGUMENTS
```

---

## 1. Terraform Fundamentals

### Version Constraints and Requirements

```hcl
# versions.tf - Always pin versions explicitly
terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.30"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.10"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
```

### Version Constraint Operators

| Operator | Meaning                          | Example         | Use Case                    |
| -------- | -------------------------------- | --------------- | --------------------------- |
| `=`      | Exact version                    | `= 5.30.0`      | Strict reproducibility      |
| `!=`     | Exclude version                  | `!= 5.25.0`     | Known buggy version         |
| `>`      | Greater than                     | `> 5.0`         | Minimum version             |
| `>=`     | Greater than or equal            | `>= 5.30`       | Minimum with exact          |
| `<`      | Less than                        | `< 6.0`         | Major version ceiling       |
| `<=`     | Less than or equal               | `<= 5.35`       | Version ceiling             |
| `~>`     | Pessimistic (allows patch bumps) | `~> 5.30`       | Recommended - allows 5.30.x |
| `, `     | AND (combine constraints)        | `>= 5.0, < 6.0` | Version range               |

### Project Structure - Standard Layout

```
infrastructure/
├── modules/                          # Reusable modules
│   ├── networking/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   ├── README.md
│   │   └── examples/
│   │       └── complete/
│   ├── compute/
│   │   ├── ec2-instance/
│   │   ├── asg/
│   │   └── ecs-service/
│   ├── database/
│   │   ├── rds/
│   │   ├── dynamodb/
│   │   └── elasticache/
│   ├── security/
│   │   ├── iam-role/
│   │   ├── security-group/
│   │   └── kms-key/
│   └── observability/
│       ├── cloudwatch/
│       └── prometheus/
├── environments/                     # Environment-specific configs
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── terraform.tfvars
│   │   ├── backend.tf
│   │   └── providers.tf
│   ├── staging/
│   └── production/
├── global/                           # Shared global resources
│   ├── iam/
│   ├── dns/
│   ├── ecr/
│   └── s3-state/
├── scripts/                          # Helper scripts
│   ├── init.sh
│   ├── plan.sh
│   ├── apply.sh
│   └── destroy.sh
├── tests/                            # Infrastructure tests
│   ├── unit/
│   ├── integration/
│   └── terratest/
├── docs/                             # Documentation
│   ├── architecture.md
│   ├── modules.md
│   └── runbooks/
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml
│       └── terraform-apply.yml
├── .pre-commit-config.yaml
├── .tflint.hcl
├── .terraform-version                # tfenv version file
├── .gitignore
└── README.md
```

### Project Structure - Monorepo Layout

```
infrastructure/
├── _modules/                         # Private modules
├── _templates/                       # Boilerplate templates
├── aws/
│   ├── account-1/
│   │   ├── us-east-1/
│   │   │   ├── production/
│   │   │   ├── staging/
│   │   │   └── development/
│   │   └── eu-west-1/
│   └── account-2/
├── gcp/
│   └── project-1/
└── azure/
    └── subscription-1/
```

---

## 2. Module Development Patterns

### Module Design Principles

| Principle             | Description                             | Implementation                     |
| --------------------- | --------------------------------------- | ---------------------------------- |
| Single Responsibility | One logical component per module        | VPC module creates only VPC + subs |
| Composition           | Build complex from simple modules       | Call vpc + security-group + ec2    |
| Encapsulation         | Hide implementation details             | Expose only necessary outputs      |
| Versioning            | Semantic versioning for modules         | Git tags: v1.0.0, v1.1.0           |
| Documentation         | Self-documenting with README + examples | terraform-docs auto-generation     |
| Validation            | Input validation in variables           | `validation` blocks                |
| Defaults              | Sensible defaults, override when needed | Optional variables with defaults   |

### Basic Module Template

```hcl
# modules/vpc/main.tf
locals {
  # Computed values
  azs_count      = length(var.availability_zones)
  public_count   = var.enable_public_subnets ? local.azs_count : 0
  private_count  = var.enable_private_subnets ? local.azs_count : 0
  database_count = var.enable_database_subnets ? local.azs_count : 0

  # Standard tags merged with user tags
  common_tags = merge(
    var.tags,
    {
      Module      = "vpc"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  )
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(local.common_tags, {
    Name = "${var.name}-vpc"
  })
}

resource "aws_internet_gateway" "main" {
  count  = var.enable_public_subnets ? 1 : 0
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.name}-igw"
  })
}

resource "aws_subnet" "public" {
  count                   = local.public_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, var.public_subnet_bits, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name                        = "${var.name}-public-${var.availability_zones[count.index]}"
    Tier                        = "public"
    "kubernetes.io/role/elb"    = var.kubernetes_cluster_name != "" ? "1" : null
    "kubernetes.io/cluster/${var.kubernetes_cluster_name}" = var.kubernetes_cluster_name != "" ? "shared" : null
  })
}

resource "aws_subnet" "private" {
  count             = local.private_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, var.private_subnet_bits, count.index + local.azs_count)
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name                              = "${var.name}-private-${var.availability_zones[count.index]}"
    Tier                              = "private"
    "kubernetes.io/role/internal-elb" = var.kubernetes_cluster_name != "" ? "1" : null
    "kubernetes.io/cluster/${var.kubernetes_cluster_name}" = var.kubernetes_cluster_name != "" ? "shared" : null
  })
}

resource "aws_subnet" "database" {
  count             = local.database_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, var.database_subnet_bits, count.index + (2 * local.azs_count))
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name = "${var.name}-database-${var.availability_zones[count.index]}"
    Tier = "database"
  })
}

# NAT Gateway (one per AZ for HA, or single for cost savings)
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : local.azs_count) : 0
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.name}-nat-eip-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : local.azs_count) : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.common_tags, {
    Name = "${var.name}-nat-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# Route Tables
resource "aws_route_table" "public" {
  count  = var.enable_public_subnets ? 1 : 0
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = merge(local.common_tags, {
    Name = "${var.name}-public-rt"
  })
}

resource "aws_route_table" "private" {
  count  = var.enable_private_subnets ? (var.single_nat_gateway ? 1 : local.azs_count) : 0
  vpc_id = aws_vpc.main.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index].id
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.name}-private-rt-${count.index + 1}"
  })
}

resource "aws_route_table_association" "public" {
  count          = local.public_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table_association" "private" {
  count          = local.private_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}
```

### Module Variables with Validation

```hcl
# modules/vpc/variables.tf
variable "name" {
  description = "Name prefix for all resources"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name))
    error_message = "Name must be lowercase alphanumeric with hyphens only."
  }

  validation {
    condition     = length(var.name) >= 3 && length(var.name) <= 28
    error_message = "Name must be between 3 and 28 characters."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string

  validation {
    condition     = contains(["dev", "development", "staging", "uat", "prod", "production"], var.environment)
    error_message = "Environment must be one of: dev, development, staging, uat, prod, production."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid CIDR block."
  }

  validation {
    condition     = tonumber(split("/", var.vpc_cidr)[1]) >= 16 && tonumber(split("/", var.vpc_cidr)[1]) <= 24
    error_message = "VPC CIDR must be between /16 and /24."
  }
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2 && length(var.availability_zones) <= 6
    error_message = "Must specify between 2 and 6 availability zones."
  }
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in VPC"
  type        = bool
  default     = true
}

variable "enable_public_subnets" {
  description = "Create public subnets"
  type        = bool
  default     = true
}

variable "enable_private_subnets" {
  description = "Create private subnets"
  type        = bool
  default     = true
}

variable "enable_database_subnets" {
  description = "Create database subnets (isolated, no internet)"
  type        = bool
  default     = true
}

variable "enable_nat_gateway" {
  description = "Create NAT gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT gateway (cost savings, not HA)"
  type        = bool
  default     = false
}

variable "public_subnet_bits" {
  description = "Additional bits for public subnet CIDR"
  type        = number
  default     = 4

  validation {
    condition     = var.public_subnet_bits >= 2 && var.public_subnet_bits <= 8
    error_message = "Subnet bits must be between 2 and 8."
  }
}

variable "private_subnet_bits" {
  description = "Additional bits for private subnet CIDR"
  type        = number
  default     = 4
}

variable "database_subnet_bits" {
  description = "Additional bits for database subnet CIDR"
  type        = number
  default     = 6
}

variable "kubernetes_cluster_name" {
  description = "Kubernetes cluster name for subnet tagging (empty to disable)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
```

### Module Outputs

```hcl
# modules/vpc/outputs.tf
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "vpc_arn" {
  description = "VPC ARN"
  value       = aws_vpc.main.arn
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "List of database subnet IDs"
  value       = aws_subnet.database[*].id
}

output "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks"
  value       = aws_subnet.private[*].cidr_block
}

output "database_subnet_cidrs" {
  description = "List of database subnet CIDR blocks"
  value       = aws_subnet.database[*].cidr_block
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.main[*].id
}

output "nat_gateway_public_ips" {
  description = "List of NAT Gateway public IPs"
  value       = aws_eip.nat[*].public_ip
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = try(aws_internet_gateway.main[0].id, null)
}

output "public_route_table_id" {
  description = "Public route table ID"
  value       = try(aws_route_table.public[0].id, null)
}

output "private_route_table_ids" {
  description = "List of private route table IDs"
  value       = aws_route_table.private[*].id
}

# Convenience outputs for common use cases
output "database_subnet_group_name" {
  description = "Name of the database subnet group (if created)"
  value       = try(aws_db_subnet_group.database[0].name, null)
}

output "vpc_endpoint_s3_id" {
  description = "S3 VPC endpoint ID (if created)"
  value       = try(aws_vpc_endpoint.s3[0].id, null)
}
```

### Advanced Module - ECS Service

```hcl
# modules/ecs-service/main.tf
locals {
  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = var.container_image
      cpu       = var.container_cpu
      memory    = var.container_memory
      essential = true

      portMappings = var.container_port != null ? [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ] : []

      environment = [
        for key, value in var.environment_variables : {
          name  = key
          value = value
        }
      ]

      secrets = [
        for key, value in var.secrets : {
          name      = key
          valueFrom = value
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.main.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = var.service_name
        }
      }

      healthCheck = var.health_check != null ? {
        command     = var.health_check.command
        interval    = var.health_check.interval
        timeout     = var.health_check.timeout
        retries     = var.health_check.retries
        startPeriod = var.health_check.start_period
      } : null

      linuxParameters = {
        initProcessEnabled = true
      }
    }
  ])
}

data "aws_region" "current" {}

resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/${var.cluster_name}/${var.service_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

resource "aws_ecs_task_definition" "main" {
  family                   = var.service_name
  network_mode             = "awsvpc"
  requires_compatibilities = [var.launch_type]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = local.container_definitions

  dynamic "volume" {
    for_each = var.volumes
    content {
      name = volume.value.name

      dynamic "efs_volume_configuration" {
        for_each = volume.value.efs_volume_configuration != null ? [volume.value.efs_volume_configuration] : []
        content {
          file_system_id          = efs_volume_configuration.value.file_system_id
          root_directory          = efs_volume_configuration.value.root_directory
          transit_encryption      = efs_volume_configuration.value.transit_encryption
          transit_encryption_port = efs_volume_configuration.value.transit_encryption_port

          dynamic "authorization_config" {
            for_each = efs_volume_configuration.value.authorization_config != null ? [efs_volume_configuration.value.authorization_config] : []
            content {
              access_point_id = authorization_config.value.access_point_id
              iam             = authorization_config.value.iam
            }
          }
        }
      }
    }
  }

  runtime_platform {
    operating_system_family = var.operating_system_family
    cpu_architecture        = var.cpu_architecture
  }

  tags = var.tags
}

resource "aws_ecs_service" "main" {
  name                               = var.service_name
  cluster                            = var.cluster_id
  task_definition                    = aws_ecs_task_definition.main.arn
  desired_count                      = var.desired_count
  launch_type                        = var.launch_type == "FARGATE" ? "FARGATE" : null
  platform_version                   = var.launch_type == "FARGATE" ? var.platform_version : null
  scheduling_strategy                = "REPLICA"
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent
  health_check_grace_period_seconds  = var.target_group_arn != null ? var.health_check_grace_period : null
  enable_execute_command             = var.enable_execute_command
  force_new_deployment               = var.force_new_deployment
  wait_for_steady_state              = var.wait_for_steady_state

  dynamic "capacity_provider_strategy" {
    for_each = var.capacity_provider_strategy
    content {
      capacity_provider = capacity_provider_strategy.value.capacity_provider
      weight            = capacity_provider_strategy.value.weight
      base              = capacity_provider_strategy.value.base
    }
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = var.assign_public_ip
  }

  dynamic "load_balancer" {
    for_each = var.target_group_arn != null ? [1] : []
    content {
      target_group_arn = var.target_group_arn
      container_name   = var.container_name
      container_port   = var.container_port
    }
  }

  dynamic "service_registries" {
    for_each = var.service_registry_arn != null ? [1] : []
    content {
      registry_arn   = var.service_registry_arn
      container_name = var.container_name
      container_port = var.container_port
    }
  }

  deployment_circuit_breaker {
    enable   = var.enable_circuit_breaker
    rollback = var.enable_circuit_breaker_rollback
  }

  deployment_controller {
    type = var.deployment_controller_type
  }

  lifecycle {
    ignore_changes = var.ignore_task_definition_changes ? [task_definition] : []
  }

  tags = var.tags

  depends_on = [aws_cloudwatch_log_group.main]
}

# Auto Scaling
resource "aws_appautoscaling_target" "main" {
  count              = var.enable_autoscaling ? 1 : 0
  max_capacity       = var.autoscaling_max_capacity
  min_capacity       = var.autoscaling_min_capacity
  resource_id        = "service/${var.cluster_name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  count              = var.enable_autoscaling ? 1 : 0
  name               = "${var.service_name}-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.main[0].resource_id
  scalable_dimension = aws_appautoscaling_target.main[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.main[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.autoscaling_cpu_target
    scale_in_cooldown  = var.autoscaling_scale_in_cooldown
    scale_out_cooldown = var.autoscaling_scale_out_cooldown
  }
}

resource "aws_appautoscaling_policy" "memory" {
  count              = var.enable_autoscaling ? 1 : 0
  name               = "${var.service_name}-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.main[0].resource_id
  scalable_dimension = aws_appautoscaling_target.main[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.main[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = var.autoscaling_memory_target
    scale_in_cooldown  = var.autoscaling_scale_in_cooldown
    scale_out_cooldown = var.autoscaling_scale_out_cooldown
  }
}
```

### Module Composition Pattern

```hcl
# environments/production/main.tf
# Compose modules to build complete infrastructure

module "vpc" {
  source = "../../modules/vpc"

  name                    = "production"
  environment             = "production"
  vpc_cidr                = "10.0.0.0/16"
  availability_zones      = ["us-east-1a", "us-east-1b", "us-east-1c"]
  enable_nat_gateway      = true
  single_nat_gateway      = false
  kubernetes_cluster_name = "production-eks"

  tags = local.common_tags
}

module "security_groups" {
  source = "../../modules/security-groups"

  vpc_id      = module.vpc.vpc_id
  environment = "production"

  security_groups = {
    alb = {
      description = "Application Load Balancer"
      ingress_rules = [
        { from_port = 443, to_port = 443, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"], description = "HTTPS" },
        { from_port = 80, to_port = 80, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"], description = "HTTP redirect" }
      ]
    }
    app = {
      description = "Application servers"
      ingress_rules = [
        { from_port = 8080, to_port = 8080, protocol = "tcp", source_security_group = "alb", description = "From ALB" }
      ]
    }
    database = {
      description = "Database servers"
      ingress_rules = [
        { from_port = 5432, to_port = 5432, protocol = "tcp", source_security_group = "app", description = "PostgreSQL from app" }
      ]
    }
  }

  tags = local.common_tags
}

module "database" {
  source = "../../modules/rds"

  identifier     = "production-db"
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.r6g.xlarge"

  allocated_storage     = 100
  max_allocated_storage = 500
  storage_encrypted     = true
  kms_key_id            = module.kms.database_key_arn

  db_name  = "app"
  username = "admin"
  password = data.aws_secretsmanager_secret_version.db_password.secret_string

  multi_az               = true
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [module.security_groups.security_group_ids["database"]]

  backup_retention_period = 35
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  performance_insights_enabled    = true
  monitoring_interval             = 60
  monitoring_role_arn             = module.iam.rds_monitoring_role_arn
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  deletion_protection = true
  skip_final_snapshot = false

  tags = local.common_tags
}

module "ecs_cluster" {
  source = "../../modules/ecs-cluster"

  cluster_name = "production"

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
  default_capacity_provider_strategy = [
    { capacity_provider = "FARGATE", weight = 1, base = 1 },
    { capacity_provider = "FARGATE_SPOT", weight = 4 }
  ]

  container_insights = true

  tags = local.common_tags
}

module "api_service" {
  source = "../../modules/ecs-service"

  service_name   = "api"
  cluster_id     = module.ecs_cluster.cluster_id
  cluster_name   = module.ecs_cluster.cluster_name

  container_name   = "api"
  container_image  = "${data.aws_ecr_repository.api.repository_url}:${var.api_image_tag}"
  container_port   = 8080
  container_cpu    = 512
  container_memory = 1024

  task_cpu    = 1024
  task_memory = 2048
  launch_type = "FARGATE"

  desired_count = 3
  subnet_ids    = module.vpc.private_subnet_ids
  security_group_ids = [module.security_groups.security_group_ids["app"]]

  target_group_arn = module.alb.target_group_arns["api"]

  execution_role_arn = module.iam.ecs_execution_role_arn
  task_role_arn      = module.iam.ecs_task_role_arn

  environment_variables = {
    NODE_ENV     = "production"
    DATABASE_URL = "postgresql://${module.database.endpoint}/${module.database.db_name}"
    REDIS_URL    = "redis://${module.elasticache.primary_endpoint}:6379"
  }

  secrets = {
    DB_PASSWORD = "${data.aws_secretsmanager_secret.db_password.arn}:password::"
    API_KEY     = "${data.aws_secretsmanager_secret.api_key.arn}:key::"
  }

  enable_autoscaling       = true
  autoscaling_min_capacity = 3
  autoscaling_max_capacity = 20
  autoscaling_cpu_target   = 70

  enable_circuit_breaker          = true
  enable_circuit_breaker_rollback = true

  tags = local.common_tags
}
```

---

## 3. State Management

### Remote State Backend Configuration

#### AWS S3 Backend

```hcl
# backend.tf - S3 backend with DynamoDB locking
terraform {
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "production/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
    kms_key_id     = "alias/terraform-state"

    # Role assumption for cross-account access
    role_arn       = "arn:aws:iam::123456789012:role/TerraformStateAccess"
    session_name   = "terraform"

    # Workspace-aware key (optional)
    # key = "env:/${terraform.workspace}/terraform.tfstate"
  }
}
```

#### S3 State Bucket Setup Module

```hcl
# modules/terraform-state/main.tf
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.bucket_name

  lifecycle {
    prevent_destroy = true
  }

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.terraform_state.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

resource "aws_kms_key" "terraform_state" {
  description             = "KMS key for Terraform state encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Terraform Role"
        Effect = "Allow"
        Principal = {
          AWS = var.terraform_role_arns
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_kms_alias" "terraform_state" {
  name          = "alias/terraform-state"
  target_key_id = aws_kms_key.terraform_state.key_id
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.terraform_state.arn
  }

  tags = var.tags
}
```

#### GCP Cloud Storage Backend

```hcl
# backend.tf - GCS backend
terraform {
  backend "gcs" {
    bucket      = "company-terraform-state"
    prefix      = "production"
    credentials = "terraform-sa-key.json"  # Or use GOOGLE_APPLICATION_CREDENTIALS

    # Impersonation (preferred over key files)
    # impersonate_service_account = "terraform@project.iam.gserviceaccount.com"
  }
}
```

#### Azure Storage Backend

```hcl
# backend.tf - Azure Blob backend
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstatecompany"
    container_name       = "tfstate"
    key                  = "production.terraform.tfstate"

    # Use Azure AD authentication (recommended)
    use_azuread_auth = true
  }
}
```

### State Locking Strategy

| Backend         | Lock Mechanism | Lock Timeout | Notes                         |
| --------------- | -------------- | ------------ | ----------------------------- |
| S3 + DynamoDB   | DynamoDB item  | Configurable | Most common, highly reliable  |
| GCS             | Built-in       | 15 minutes   | Automatic with GCS backend    |
| Azure Blob      | Blob lease     | 1 minute     | Requires storage access       |
| Terraform Cloud | Built-in       | Unlimited    | Managed, recommended for orgs |
| Consul          | Consul lock    | Configurable | Good for on-premise           |
| PostgreSQL      | Row-level lock | Configurable | For existing Postgres setups  |

### State Operations

```bash
# View current state
terraform state list
terraform state show aws_instance.web

# Move resources (refactoring)
terraform state mv aws_instance.old aws_instance.new
terraform state mv module.old_name module.new_name

# Remove from state (without destroying)
terraform state rm aws_instance.imported

# Import existing resources
terraform import aws_instance.web i-1234567890abcdef0
terraform import 'aws_instance.web["production"]' i-1234567890abcdef0
terraform import module.vpc.aws_vpc.main vpc-1234567890

# Pull/push state (advanced)
terraform state pull > state.json
terraform state push state.json

# Force unlock (emergency)
terraform force-unlock LOCK_ID
```

### State Migration

```hcl
# Migrate from local to S3 backend
# 1. Add backend configuration
terraform {
  backend "s3" {
    bucket         = "terraform-state"
    key            = "app/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

# 2. Run init with migration
# terraform init -migrate-state

# 3. Verify state was migrated
# terraform state list
```

### Data Source for Remote State

```hcl
# Reference state from another configuration
data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = "terraform-state"
    key    = "vpc/terraform.tfstate"
    region = "us-east-1"
  }
}

# Use outputs from remote state
resource "aws_instance" "web" {
  subnet_id = data.terraform_remote_state.vpc.outputs.private_subnet_ids[0]
  # ...
}
```

---

## 4. Multi-Environment Configurations

### Environment Strategy Comparison

| Strategy        | Complexity | Isolation | Drift Risk | Best For               |
| --------------- | ---------- | --------- | ---------- | ---------------------- |
| Workspaces      | Low        | Low       | Medium     | Small projects         |
| Directory-based | Medium     | High      | Low        | Medium projects        |
| Terragrunt      | Medium     | High      | Low        | Large monorepos        |
| Separate repos  | High       | Highest   | Lowest     | Enterprise, compliance |

### Directory-Based Environments (Recommended)

```
environments/
├── dev/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   ├── backend.tf
│   └── providers.tf
├── staging/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   ├── backend.tf
│   └── providers.tf
└── production/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── terraform.tfvars
    ├── backend.tf
    └── providers.tf
```

```hcl
# environments/production/terraform.tfvars
environment = "production"
region      = "us-east-1"

# VPC
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
single_nat_gateway = false

# Database
db_instance_class = "db.r6g.xlarge"
db_multi_az       = true
db_storage        = 500

# Compute
ecs_desired_count      = 5
ecs_min_capacity       = 3
ecs_max_capacity       = 20
instance_type          = "m6i.xlarge"

# Features
enable_monitoring   = true
enable_alerting     = true
enable_waf          = true
enable_shield       = true
deletion_protection = true
```

```hcl
# environments/dev/terraform.tfvars
environment = "dev"
region      = "us-east-1"

# VPC (smaller, cost-optimized)
vpc_cidr           = "10.1.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]
single_nat_gateway = true  # Cost savings

# Database (smaller)
db_instance_class = "db.t3.medium"
db_multi_az       = false
db_storage        = 50

# Compute (minimal)
ecs_desired_count      = 1
ecs_min_capacity       = 1
ecs_max_capacity       = 3
instance_type          = "t3.medium"

# Features (minimal for dev)
enable_monitoring   = true
enable_alerting     = false
enable_waf          = false
enable_shield       = false
deletion_protection = false
```

### Environment-Agnostic Main Configuration

```hcl
# environments/production/main.tf
locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = var.project_name
    CostCenter  = var.cost_center
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name               = "${var.project_name}-${var.environment}"
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  single_nat_gateway = var.single_nat_gateway

  tags = local.common_tags
}

module "database" {
  source = "../../modules/rds"

  identifier     = "${var.project_name}-${var.environment}"
  instance_class = var.db_instance_class
  multi_az       = var.db_multi_az
  storage        = var.db_storage

  # Environment-specific settings
  deletion_protection      = var.deletion_protection
  backup_retention_period  = var.environment == "production" ? 35 : 7
  performance_insights_enabled = var.environment == "production"

  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.database_subnet_ids
  security_groups = [module.security_groups.database_sg_id]

  tags = local.common_tags
}
```

### Workspace-Based Environments

```hcl
# main.tf - Workspace-aware configuration
locals {
  environment_configs = {
    default = {  # Treat default as dev
      instance_type = "t3.medium"
      min_size      = 1
      max_size      = 3
      db_class      = "db.t3.medium"
    }
    staging = {
      instance_type = "m6i.large"
      min_size      = 2
      max_size      = 5
      db_class      = "db.r6g.large"
    }
    production = {
      instance_type = "m6i.xlarge"
      min_size      = 3
      max_size      = 20
      db_class      = "db.r6g.xlarge"
    }
  }

  env    = terraform.workspace
  config = local.environment_configs[local.env]
}

resource "aws_instance" "web" {
  instance_type = local.config.instance_type
  # ...
}

resource "aws_db_instance" "main" {
  instance_class = local.config.db_class
  # ...
}
```

```bash
# Workspace commands
terraform workspace list
terraform workspace new staging
terraform workspace select production
terraform workspace show
terraform workspace delete staging
```

### Terragrunt Configuration

```hcl
# terragrunt.hcl (root)
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "company-terraform-state"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "terragrunt"
    }
  }
}
EOF
}

inputs = {
  aws_region = "us-east-1"
  project    = "myapp"
}
```

```hcl
# environments/production/terragrunt.hcl
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../modules//complete-stack"
}

inputs = {
  environment = "production"
  vpc_cidr    = "10.0.0.0/16"

  # Production-specific overrides
  db_instance_class = "db.r6g.xlarge"
  db_multi_az       = true
  min_capacity      = 3
  max_capacity      = 20
}

dependencies {
  paths = ["../global/iam", "../global/dns"]
}

dependency "iam" {
  config_path = "../global/iam"
}

dependency "dns" {
  config_path = "../global/dns"
}
```

---

## 5. Provider Configurations

### AWS Provider

```hcl
# providers.tf - AWS multi-region, multi-account
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      Project     = var.project_name
    }
  }

  # Cross-account access
  assume_role {
    role_arn     = "arn:aws:iam::${var.target_account_id}:role/TerraformExecutionRole"
    session_name = "terraform-${var.environment}"
    external_id  = var.external_id
  }
}

# Secondary region for DR
provider "aws" {
  alias  = "dr"
  region = var.dr_region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      Project     = var.project_name
    }
  }

  assume_role {
    role_arn     = "arn:aws:iam::${var.target_account_id}:role/TerraformExecutionRole"
    session_name = "terraform-${var.environment}-dr"
  }
}

# Global resources (us-east-1 for CloudFront, ACM)
provider "aws" {
  alias  = "global"
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Use aliased providers
resource "aws_s3_bucket" "dr_backup" {
  provider = aws.dr
  bucket   = "${var.project_name}-dr-backup-${var.environment}"
}

resource "aws_acm_certificate" "main" {
  provider          = aws.global  # CloudFront requires us-east-1
  domain_name       = var.domain_name
  validation_method = "DNS"
}
```

### GCP Provider

```hcl
# providers.tf - GCP multi-project
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region

  # Service account impersonation (recommended)
  impersonate_service_account = var.terraform_service_account
}

provider "google-beta" {
  project = var.gcp_project_id
  region  = var.gcp_region

  impersonate_service_account = var.terraform_service_account
}

# Secondary project
provider "google" {
  alias   = "shared_vpc"
  project = var.shared_vpc_project_id
  region  = var.gcp_region

  impersonate_service_account = var.terraform_service_account
}

# Use google-beta for preview features
resource "google_compute_instance" "main" {
  provider = google-beta

  name         = "instance-1"
  machine_type = "e2-medium"
  zone         = "${var.gcp_region}-a"

  # Beta feature
  advanced_machine_features {
    enable_nested_virtualization = true
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = "default"
  }
}
```

### Azure Provider

```hcl
# providers.tf - Azure multi-subscription
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = true
      skip_shutdown_and_force_delete = false
    }
  }

  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id

  # Use Azure AD authentication (recommended)
  # use_oidc = true  # For GitHub Actions OIDC
}

# Hub subscription for networking
provider "azurerm" {
  alias           = "hub"
  subscription_id = var.hub_subscription_id
  tenant_id       = var.azure_tenant_id

  features {}
}

# Management subscription
provider "azurerm" {
  alias           = "management"
  subscription_id = var.management_subscription_id
  tenant_id       = var.azure_tenant_id

  features {}
}
```

### Multi-Cloud Provider Setup

```hcl
# providers.tf - Multi-cloud
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.30"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.10"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

# Multi-cloud DNS example
resource "aws_route53_record" "main" {
  zone_id = var.route53_zone_id
  name    = "api.${var.domain}"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

resource "google_dns_record_set" "main" {
  name         = "api.${var.domain}."
  type         = "A"
  ttl          = 300
  managed_zone = var.gcp_dns_zone

  rrdatas = [google_compute_global_address.main.address]
}
```

---

## 6. Resource Patterns for AWS/GCP/Azure

### VPC/Network Patterns

#### AWS VPC

```hcl
# AWS VPC with full feature set
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.name}-vpc"
  })
}

# VPC Flow Logs
resource "aws_flow_log" "main" {
  vpc_id                   = aws_vpc.main.id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.flow_logs.arn
  iam_role_arn             = aws_iam_role.flow_logs.arn
  max_aggregation_interval = 60

  tags = var.tags
}

# VPC Endpoints for private access
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(
    aws_route_table.private[*].id,
    [aws_route_table.public.id]
  )

  tags = merge(var.tags, {
    Name = "${var.name}-s3-endpoint"
  })
}

resource "aws_vpc_endpoint" "interface_endpoints" {
  for_each = toset([
    "ec2",
    "ecr.api",
    "ecr.dkr",
    "ecs",
    "logs",
    "monitoring",
    "secretsmanager",
    "ssm",
    "ssmmessages",
    "kms"
  ])

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.name}-${each.key}-endpoint"
  })
}
```

#### GCP VPC

```hcl
# GCP VPC with custom subnets
resource "google_compute_network" "main" {
  name                            = var.name
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  delete_default_routes_on_create = true
}

resource "google_compute_subnetwork" "private" {
  for_each = var.subnets

  name                     = "${var.name}-${each.key}"
  ip_cidr_range            = each.value.cidr
  region                   = each.value.region
  network                  = google_compute_network.main.id
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = each.value.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = each.value.services_cidr
  }

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Cloud NAT for private subnet internet access
resource "google_compute_router" "main" {
  name    = "${var.name}-router"
  region  = var.region
  network = google_compute_network.main.id
}

resource "google_compute_router_nat" "main" {
  name                               = "${var.name}-nat"
  router                             = google_compute_router.main.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Private Service Access for managed services
resource "google_compute_global_address" "private_service_access" {
  name          = "${var.name}-psa"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main.id
}

resource "google_service_networking_connection" "main" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_access.name]
}
```

#### Azure VNet

```hcl
# Azure Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "${var.name}-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.vnet_cidr]

  tags = var.tags
}

resource "azurerm_subnet" "private" {
  for_each = var.subnets

  name                 = each.key
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [each.value.cidr]

  service_endpoints = each.value.service_endpoints

  dynamic "delegation" {
    for_each = each.value.delegation != null ? [each.value.delegation] : []
    content {
      name = delegation.value.name
      service_delegation {
        name    = delegation.value.service_name
        actions = delegation.value.actions
      }
    }
  }
}

# Network Security Group
resource "azurerm_network_security_group" "main" {
  name                = "${var.name}-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  tags = var.tags
}

resource "azurerm_network_security_rule" "inbound_rules" {
  for_each = var.nsg_rules

  name                        = each.key
  priority                    = each.value.priority
  direction                   = "Inbound"
  access                      = each.value.access
  protocol                    = each.value.protocol
  source_port_range           = each.value.source_port_range
  destination_port_range      = each.value.destination_port_range
  source_address_prefix       = each.value.source_address_prefix
  destination_address_prefix  = each.value.destination_address_prefix
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
}

# Private Endpoints for managed services
resource "azurerm_private_endpoint" "storage" {
  name                = "${var.name}-storage-pe"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private["endpoints"].id

  private_service_connection {
    name                           = "storage-connection"
    private_connection_resource_id = azurerm_storage_account.main.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }

  tags = var.tags
}
```

### Compute Patterns

#### AWS EKS Cluster

```hcl
# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = var.enable_public_access
    public_access_cidrs     = var.enable_public_access ? var.public_access_cidrs : []
    security_group_ids      = [aws_security_group.cluster.id]
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSVPCResourceController,
    aws_cloudwatch_log_group.eks,
  ]
}

# Managed Node Groups
resource "aws_eks_node_group" "main" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = each.key
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids

  instance_types = each.value.instance_types
  capacity_type  = each.value.capacity_type  # ON_DEMAND or SPOT
  ami_type       = each.value.ami_type       # AL2_x86_64, AL2_ARM_64, BOTTLEROCKET_ARM_64

  scaling_config {
    desired_size = each.value.desired_size
    min_size     = each.value.min_size
    max_size     = each.value.max_size
  }

  update_config {
    max_unavailable_percentage = 33
  }

  labels = merge(
    each.value.labels,
    {
      "node-group" = each.key
    }
  )

  dynamic "taint" {
    for_each = each.value.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  launch_template {
    id      = aws_launch_template.node[each.key].id
    version = aws_launch_template.node[each.key].latest_version
  }

  tags = merge(var.tags, {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]
}

# Fargate Profile
resource "aws_eks_fargate_profile" "main" {
  count = var.enable_fargate ? 1 : 0

  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "default"
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = var.private_subnet_ids

  selector {
    namespace = "fargate"
  }

  selector {
    namespace = "kube-system"
    labels = {
      "fargate" = "true"
    }
  }

  tags = var.tags
}

# EKS Addons
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  addon_version               = var.vpc_cni_version
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = aws_iam_role.vpc_cni.arn

  configuration_values = jsonencode({
    enableNetworkPolicy = "true"
  })

  tags = var.tags
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  addon_version               = var.coredns_version
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags

  depends_on = [aws_eks_node_group.main]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "kube-proxy"
  addon_version               = var.kube_proxy_version
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags
}
```

#### GCP GKE Cluster

```hcl
# GKE Cluster
resource "google_container_cluster" "main" {
  name     = var.cluster_name
  location = var.region

  # Remove default node pool
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.main.id
  subnetwork = google_compute_subnetwork.private["main"].id

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.master_cidr
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr
        display_name = cidr_blocks.value.name
      }
    }
  }

  release_channel {
    channel = var.release_channel  # RAPID, REGULAR, STABLE
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  datapath_provider = "ADVANCED_DATAPATH"  # Enable Dataplane V2

  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  cluster_autoscaling {
    enabled = var.enable_cluster_autoscaling

    auto_provisioning_defaults {
      service_account = google_service_account.nodes.email
      oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

      management {
        auto_repair  = true
        auto_upgrade = true
      }

      shielded_instance_config {
        enable_secure_boot          = true
        enable_integrity_monitoring = true
      }
    }

    resource_limits {
      resource_type = "cpu"
      minimum       = var.autoscaling_cpu_min
      maximum       = var.autoscaling_cpu_max
    }

    resource_limits {
      resource_type = "memory"
      minimum       = var.autoscaling_memory_min
      maximum       = var.autoscaling_memory_max
    }
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
    gcp_filestore_csi_driver_config {
      enabled = true
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]

    managed_prometheus {
      enabled = true
    }
  }

  maintenance_policy {
    recurring_window {
      start_time = "2024-01-01T04:00:00Z"
      end_time   = "2024-01-01T08:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SA,SU"
    }
  }

  resource_labels = var.labels
}

# Node Pools
resource "google_container_node_pool" "main" {
  for_each = var.node_pools

  name     = each.key
  location = var.region
  cluster  = google_container_cluster.main.name

  initial_node_count = each.value.initial_node_count

  autoscaling {
    min_node_count  = each.value.min_node_count
    max_node_count  = each.value.max_node_count
    location_policy = "BALANCED"
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
    strategy        = "SURGE"
  }

  node_config {
    machine_type = each.value.machine_type
    disk_size_gb = each.value.disk_size_gb
    disk_type    = each.value.disk_type
    image_type   = "COS_CONTAINERD"

    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    labels = merge(var.labels, each.value.labels)
    tags   = each.value.tags

    dynamic "taint" {
      for_each = each.value.taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    gvnic {
      enabled = true
    }
  }
}
```

---

## 7. Testing with Terratest

### Terratest Setup

```go
// tests/terratest/vpc_test.go
package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestVPCModule(t *testing.T) {
	t.Parallel()

	awsRegion := "us-east-1"
	vpcCidr := "10.99.0.0/16"

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../modules/vpc",

		Vars: map[string]interface{}{
			"name":               "test-vpc",
			"environment":        "test",
			"vpc_cidr":           vpcCidr,
			"availability_zones": []string{"us-east-1a", "us-east-1b"},
			"enable_nat_gateway": true,
			"single_nat_gateway": true,
		},

		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify outputs
	vpcId := terraform.Output(t, terraformOptions, "vpc_id")
	assert.NotEmpty(t, vpcId)

	publicSubnetIds := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
	assert.Equal(t, 2, len(publicSubnetIds))

	privateSubnetIds := terraform.OutputList(t, terraformOptions, "private_subnet_ids")
	assert.Equal(t, 2, len(privateSubnetIds))

	// Verify VPC exists and has correct CIDR
	vpc := aws.GetVpcById(t, vpcId, awsRegion)
	assert.Equal(t, vpcCidr, *vpc.CidrBlock)

	// Verify DNS settings
	assert.True(t, *vpc.EnableDnsHostnames)
	assert.True(t, *vpc.EnableDnsSupport)

	// Verify subnets
	for _, subnetId := range publicSubnetIds {
		subnet := aws.GetSubnetById(t, subnetId, awsRegion)
		assert.True(t, *subnet.MapPublicIpOnLaunch)
	}

	for _, subnetId := range privateSubnetIds {
		subnet := aws.GetSubnetById(t, subnetId, awsRegion)
		assert.False(t, *subnet.MapPublicIpOnLaunch)
	}

	// Verify NAT Gateway
	natGatewayIds := terraform.OutputList(t, terraformOptions, "nat_gateway_ids")
	assert.Equal(t, 1, len(natGatewayIds))
}

func TestVPCModuleValidation(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/vpc",

		Vars: map[string]interface{}{
			"name":               "TEST_INVALID",  // Should fail validation
			"environment":        "test",
			"vpc_cidr":           "10.99.0.0/16",
			"availability_zones": []string{"us-east-1a"},  // Only 1 AZ, should fail
		},
	}

	_, err := terraform.InitAndPlanE(t, terraformOptions)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "must be lowercase")
}
```

### Integration Test Example

```go
// tests/terratest/full_stack_test.go
package test

import (
	"crypto/tls"
	"fmt"
	"net/http"
	"testing"
	"time"

	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestFullStackDeployment(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../environments/test",

		Vars: map[string]interface{}{
			"environment":     "test",
			"desired_count":   1,
			"instance_type":   "t3.small",
			"db_instance_class": "db.t3.micro",
		},

		// Retry settings for flaky cloud APIs
		MaxRetries:         3,
		TimeBetweenRetries: 5 * time.Second,
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Get outputs
	albDnsName := terraform.Output(t, terraformOptions, "alb_dns_name")
	eksClusterName := terraform.Output(t, terraformOptions, "eks_cluster_name")

	// Wait for ALB to become available
	maxRetries := 30
	timeBetweenRetries := 10 * time.Second

	url := fmt.Sprintf("https://%s/health", albDnsName)
	tlsConfig := &tls.Config{InsecureSkipVerify: true}

	http_helper.HttpGetWithRetryWithCustomValidation(
		t,
		url,
		&tlsConfig,
		maxRetries,
		timeBetweenRetries,
		func(statusCode int, body string) bool {
			return statusCode == 200 && body == `{"status":"healthy"}`
		},
	)

	// Verify EKS cluster
	kubectlOptions := k8s.NewKubectlOptions("", fmt.Sprintf("~/.kube/%s", eksClusterName), "default")

	// Verify nodes are ready
	nodes := k8s.GetNodes(t, kubectlOptions)
	assert.GreaterOrEqual(t, len(nodes), 2)

	for _, node := range nodes {
		for _, condition := range node.Status.Conditions {
			if condition.Type == "Ready" {
				assert.Equal(t, "True", string(condition.Status))
			}
		}
	}

	// Verify pods are running
	pods := k8s.ListPods(t, kubectlOptions, map[string]string{"app": "api"})
	assert.GreaterOrEqual(t, len(pods), 1)

	for _, pod := range pods {
		assert.Equal(t, "Running", string(pod.Status.Phase))
	}
}
```

### Test Makefile

```makefile
# tests/Makefile
.PHONY: test test-unit test-integration test-all clean

TERRATEST_DIR := ./terratest

# Run all tests
test-all: test-unit test-integration

# Unit tests (fast, no cloud resources)
test-unit:
	cd $(TERRATEST_DIR) && go test -v -timeout 10m -run "TestUnit" ./...

# Integration tests (creates real resources)
test-integration:
	cd $(TERRATEST_DIR) && go test -v -timeout 60m -run "TestIntegration" ./...

# VPC module tests
test-vpc:
	cd $(TERRATEST_DIR) && go test -v -timeout 30m -run "TestVPC" ./...

# EKS module tests
test-eks:
	cd $(TERRATEST_DIR) && go test -v -timeout 45m -run "TestEKS" ./...

# Full stack tests
test-full-stack:
	cd $(TERRATEST_DIR) && go test -v -timeout 90m -run "TestFullStack" ./...

# Clean up any orphaned resources
clean:
	@echo "Cleaning up test resources..."
	aws resourcegroupstaggingapi get-resources \
		--tag-filters Key=Environment,Values=test \
		--query 'ResourceTagMappingList[*].ResourceARN' \
		--output text | xargs -I {} aws resource-groups delete-group --group {}

# Initialize Go modules
init:
	cd $(TERRATEST_DIR) && go mod init terratest && go mod tidy
```

---

## 8. CI/CD Integration

### GitHub Actions Pipeline

```yaml
# .github/workflows/terraform.yml
name: Terraform CI/CD

on:
  push:
    branches: [main]
    paths: ["infrastructure/**"]
  pull_request:
    branches: [main]
    paths: ["infrastructure/**"]
  workflow_dispatch:
    inputs:
      environment:
        description: "Environment to deploy"
        type: choice
        options:
          - dev
          - staging
          - production
        required: true
      action:
        description: "Action to perform"
        type: choice
        options:
          - plan
          - apply
          - destroy
        default: plan

env:
  TF_VERSION: "1.6.6"
  TFLINT_VERSION: "0.50.0"
  AWS_REGION: "us-east-1"

permissions:
  id-token: write
  contents: read
  pull-requests: write

jobs:
  # Validate and lint
  validate:
    name: Validate
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Terraform Format Check
        run: terraform fmt -check -recursive -diff
        working-directory: infrastructure

      - name: Setup TFLint
        uses: terraform-linters/setup-tflint@v4
        with:
          tflint_version: ${{ env.TFLINT_VERSION }}

      - name: TFLint Init
        run: tflint --init
        working-directory: infrastructure

      - name: TFLint
        run: tflint --recursive --format compact
        working-directory: infrastructure

      - name: Checkov Security Scan
        uses: bridgecrewio/checkov-action@v12
        with:
          directory: infrastructure
          framework: terraform
          output_format: sarif
          output_file_path: checkov.sarif
          soft_fail: false
          skip_check: CKV_AWS_144,CKV_AWS_145 # Skip specific checks if needed

      - name: Upload SARIF
        if: always()
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: checkov.sarif

  # Plan for each environment
  plan:
    name: Plan (${{ matrix.environment }})
    needs: validate
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        environment: [dev, staging, production]
    environment: ${{ matrix.environment }}
    outputs:
      plan_exitcode: ${{ steps.plan.outputs.exitcode }}
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}
          terraform_wrapper: false

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Terraform Init
        run: terraform init -backend-config="key=${{ matrix.environment }}/terraform.tfstate"
        working-directory: infrastructure/environments/${{ matrix.environment }}

      - name: Terraform Plan
        id: plan
        run: |
          terraform plan \
            -var-file=terraform.tfvars \
            -out=tfplan \
            -detailed-exitcode \
            -no-color 2>&1 | tee plan.txt

          echo "exitcode=${PIPESTATUS[0]}" >> $GITHUB_OUTPUT
        working-directory: infrastructure/environments/${{ matrix.environment }}
        continue-on-error: true

      - name: Upload Plan
        uses: actions/upload-artifact@v4
        with:
          name: tfplan-${{ matrix.environment }}
          path: |
            infrastructure/environments/${{ matrix.environment }}/tfplan
            infrastructure/environments/${{ matrix.environment }}/plan.txt
          retention-days: 7

      - name: Comment PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const planOutput = fs.readFileSync('infrastructure/environments/${{ matrix.environment }}/plan.txt', 'utf8');

            const truncatedPlan = planOutput.length > 60000
              ? planOutput.substring(0, 60000) + '\n\n... (truncated)'
              : planOutput;

            const body = `### Terraform Plan for \`${{ matrix.environment }}\`

            <details>
            <summary>Show Plan</summary>

            \`\`\`hcl
            ${truncatedPlan}
            \`\`\`

            </details>

            **Exit Code:** ${{ steps.plan.outputs.exitcode }}
            - \`0\` = No changes
            - \`1\` = Error
            - \`2\` = Changes pending
            `;

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: body
            });

  # Apply changes
  apply:
    name: Apply (${{ matrix.environment }})
    needs: plan
    if: |
      github.ref == 'refs/heads/main' &&
      github.event_name == 'push' &&
      needs.plan.outputs.plan_exitcode == '2'
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, staging, production]
      max-parallel: 1 # Deploy sequentially
    environment: ${{ matrix.environment }}
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Download Plan
        uses: actions/download-artifact@v4
        with:
          name: tfplan-${{ matrix.environment }}
          path: infrastructure/environments/${{ matrix.environment }}

      - name: Terraform Init
        run: terraform init -backend-config="key=${{ matrix.environment }}/terraform.tfstate"
        working-directory: infrastructure/environments/${{ matrix.environment }}

      - name: Terraform Apply
        run: terraform apply -auto-approve tfplan
        working-directory: infrastructure/environments/${{ matrix.environment }}

      - name: Notify Slack
        if: always()
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "Terraform ${{ job.status }} for ${{ matrix.environment }}",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Terraform Apply ${{ job.status }}*\n*Environment:* ${{ matrix.environment }}\n*Commit:* ${{ github.sha }}"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}

  # Drift detection (scheduled)
  drift-detection:
    name: Drift Detection
    if: github.event_name == 'schedule'
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, staging, production]
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Terraform Init
        run: terraform init -backend-config="key=${{ matrix.environment }}/terraform.tfstate"
        working-directory: infrastructure/environments/${{ matrix.environment }}

      - name: Detect Drift
        id: drift
        run: |
          terraform plan -detailed-exitcode -var-file=terraform.tfvars > drift.txt 2>&1
          echo "exitcode=$?" >> $GITHUB_OUTPUT
        working-directory: infrastructure/environments/${{ matrix.environment }}
        continue-on-error: true

      - name: Alert on Drift
        if: steps.drift.outputs.exitcode == '2'
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "Infrastructure drift detected in ${{ matrix.environment }}!",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Infrastructure Drift Detected*\n*Environment:* ${{ matrix.environment }}\n*Action Required:* Review and apply changes"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

### GitLab CI Pipeline

```yaml
# .gitlab-ci.yml
stages:
  - validate
  - plan
  - apply
  - drift

variables:
  TF_VERSION: "1.6.6"
  TF_ROOT: "${CI_PROJECT_DIR}/infrastructure"

.terraform_template: &terraform_template
  image:
    name: hashicorp/terraform:${TF_VERSION}
    entrypoint: [""]
  before_script:
    - cd ${TF_ROOT}/environments/${ENVIRONMENT}
    - terraform init -backend-config="key=${ENVIRONMENT}/terraform.tfstate"

validate:
  stage: validate
  image:
    name: hashicorp/terraform:${TF_VERSION}
    entrypoint: [""]
  script:
    - terraform fmt -check -recursive -diff
    - terraform validate
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

.plan_template: &plan_template
  <<: *terraform_template
  stage: plan
  script:
    - terraform plan -var-file=terraform.tfvars -out=tfplan
    - terraform show -no-color tfplan > plan.txt
  artifacts:
    paths:
      - ${TF_ROOT}/environments/${ENVIRONMENT}/tfplan
      - ${TF_ROOT}/environments/${ENVIRONMENT}/plan.txt
    expire_in: 7 days

plan:dev:
  <<: *plan_template
  variables:
    ENVIRONMENT: dev
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

plan:staging:
  <<: *plan_template
  variables:
    ENVIRONMENT: staging
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

plan:production:
  <<: *plan_template
  variables:
    ENVIRONMENT: production
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

.apply_template: &apply_template
  <<: *terraform_template
  stage: apply
  script:
    - terraform apply -auto-approve tfplan
  dependencies:
    - plan:${ENVIRONMENT}

apply:dev:
  <<: *apply_template
  variables:
    ENVIRONMENT: dev
  environment:
    name: development
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
  needs:
    - plan:dev

apply:staging:
  <<: *apply_template
  variables:
    ENVIRONMENT: staging
  environment:
    name: staging
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
  needs:
    - plan:staging
    - apply:dev

apply:production:
  <<: *apply_template
  variables:
    ENVIRONMENT: production
  environment:
    name: production
  when: manual
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
  needs:
    - plan:production
    - apply:staging

drift:detection:
  <<: *terraform_template
  stage: drift
  script:
    - |
      for env in dev staging production; do
        cd ${TF_ROOT}/environments/${env}
        terraform init -backend-config="key=${env}/terraform.tfstate"
        if ! terraform plan -detailed-exitcode -var-file=terraform.tfvars; then
          echo "Drift detected in ${env}!"
          # Send alert
        fi
      done
  rules:
    - if: $CI_PIPELINE_SOURCE == "schedule"
```

---

## 9. Security Best Practices

### Secrets Management

```hcl
# NEVER store secrets in Terraform code or state
# Use external secret managers

# AWS Secrets Manager
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "production/database/password"
}

resource "aws_db_instance" "main" {
  password = data.aws_secretsmanager_secret_version.db_password.secret_string
  # ...
}

# HashiCorp Vault
provider "vault" {
  address = "https://vault.example.com"
}

data "vault_generic_secret" "db_password" {
  path = "secret/data/production/database"
}

resource "aws_db_instance" "main" {
  password = data.vault_generic_secret.db_password.data["password"]
  # ...
}

# Environment variables (CI/CD)
variable "db_password" {
  description = "Database password (set via TF_VAR_db_password)"
  type        = string
  sensitive   = true
}

# Mark outputs as sensitive
output "db_connection_string" {
  value     = "postgresql://${aws_db_instance.main.username}:${var.db_password}@${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
  sensitive = true
}
```

### Sensitive Variables

```hcl
# variables.tf
variable "api_key" {
  description = "API key for external service"
  type        = string
  sensitive   = true  # Prevents value from appearing in logs

  validation {
    condition     = length(var.api_key) >= 32
    error_message = "API key must be at least 32 characters."
  }
}

variable "database_password" {
  description = "Database password"
  type        = string
  sensitive   = true

  validation {
    condition = (
      length(var.database_password) >= 16 &&
      can(regex("[A-Z]", var.database_password)) &&
      can(regex("[a-z]", var.database_password)) &&
      can(regex("[0-9]", var.database_password)) &&
      can(regex("[!@#$%^&*]", var.database_password))
    )
    error_message = "Password must be 16+ characters with uppercase, lowercase, numbers, and special characters."
  }
}
```

### IAM Least Privilege

```hcl
# modules/iam-role/main.tf
# Create role with minimum required permissions

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = [var.trusted_service]
    }

    # Add conditions for extra security
    dynamic "condition" {
      for_each = var.assume_role_conditions
      content {
        test     = condition.value.test
        variable = condition.value.variable
        values   = condition.value.values
      }
    }
  }
}

data "aws_iam_policy_document" "permissions" {
  # Principle: Start with deny, explicitly allow only what's needed

  # Explicit deny for dangerous actions
  statement {
    sid    = "DenyDangerousActions"
    effect = "Deny"
    actions = [
      "iam:CreateUser",
      "iam:DeleteUser",
      "iam:CreateAccessKey",
      "organizations:*",
      "account:*"
    ]
    resources = ["*"]
  }

  # Allow only specific S3 actions on specific buckets
  statement {
    sid    = "AllowS3Access"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket"
    ]
    resources = [
      var.s3_bucket_arn,
      "${var.s3_bucket_arn}/*"
    ]

    # Require encryption
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }
  }

  # Allow DynamoDB access with tenant isolation
  statement {
    sid    = "AllowDynamoDBAccess"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query"
    ]
    resources = [
      var.dynamodb_table_arn,
      "${var.dynamodb_table_arn}/index/*"
    ]

    # Restrict to tenant's data only
    condition {
      test     = "ForAllValues:StringEquals"
      variable = "dynamodb:LeadingKeys"
      values   = ["$${aws:PrincipalTag/TenantId}"]
    }
  }

  # Require MFA for sensitive actions
  statement {
    sid    = "RequireMFAForSensitiveActions"
    effect = "Deny"
    actions = [
      "kms:Decrypt",
      "secretsmanager:GetSecretValue"
    ]
    resources = ["*"]

    condition {
      test     = "BoolIfExists"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["false"]
    }
  }
}

resource "aws_iam_role" "main" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  max_session_duration = var.max_session_duration

  # Permission boundary
  permissions_boundary = var.permissions_boundary_arn

  tags = var.tags
}

resource "aws_iam_role_policy" "main" {
  name   = "${var.role_name}-policy"
  role   = aws_iam_role.main.id
  policy = data.aws_iam_policy_document.permissions.json
}
```

### Security Group Rules

```hcl
# Principle: Default deny, explicit allow

resource "aws_security_group" "database" {
  name        = "${var.name}-database-sg"
  description = "Security group for database - allows only application tier"
  vpc_id      = var.vpc_id

  # No ingress rules by default - must be explicitly added

  # Egress: Deny all by default
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["127.0.0.1/32"]  # Effectively blocks all egress
    description = "Default deny egress"
  }

  tags = merge(var.tags, {
    Name = "${var.name}-database-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Separate rules for audit trail
resource "aws_security_group_rule" "database_ingress_app" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = var.app_security_group_id
  security_group_id        = aws_security_group.database.id
  description              = "PostgreSQL from application tier"
}

# No public CIDR blocks for database
resource "aws_security_group_rule" "database_ingress_public" {
  count = 0  # Explicitly disabled

  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]  # NEVER do this for databases
  security_group_id = aws_security_group.database.id
}
```

### Encryption Configuration

```hcl
# Encryption at rest for all resources

# S3
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

# RDS
resource "aws_db_instance" "main" {
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn
  # ...
}

# EBS
resource "aws_ebs_default_kms_key" "main" {
  key_arn = aws_kms_key.ebs.arn
}

resource "aws_ebs_encryption_by_default" "main" {
  enabled = true
}

# Secrets Manager
resource "aws_secretsmanager_secret" "main" {
  name       = "production/database/password"
  kms_key_id = aws_kms_key.secrets.arn

  # Automatic rotation
  rotation_rules {
    automatically_after_days = 30
  }
}
```

---

## 10. Drift Detection and Remediation

### Drift Detection Strategy

```hcl
# drift-detection/main.tf
# Scheduled Lambda for drift detection

resource "aws_lambda_function" "drift_detector" {
  function_name = "terraform-drift-detector"
  role          = aws_iam_role.drift_detector.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 300
  memory_size   = 512

  filename         = data.archive_file.drift_detector.output_path
  source_code_hash = data.archive_file.drift_detector.output_base64sha256

  environment {
    variables = {
      STATE_BUCKET      = var.state_bucket
      SLACK_WEBHOOK_URL = var.slack_webhook_url
      SNS_TOPIC_ARN     = aws_sns_topic.drift_alerts.arn
    }
  }

  tags = var.tags
}

resource "aws_cloudwatch_event_rule" "drift_schedule" {
  name                = "terraform-drift-detection"
  description         = "Run drift detection every 6 hours"
  schedule_expression = "rate(6 hours)"

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "drift_detector" {
  rule      = aws_cloudwatch_event_rule.drift_schedule.name
  target_id = "drift-detector"
  arn       = aws_lambda_function.drift_detector.arn
}
```

### Drift Detection Script

```python
# drift-detection/lambda/index.py
import boto3
import json
import os
import subprocess
import tempfile
from datetime import datetime

def handler(event, context):
    state_bucket = os.environ['STATE_BUCKET']
    environments = ['dev', 'staging', 'production']
    drift_results = []

    s3 = boto3.client('s3')
    sns = boto3.client('sns')

    for env in environments:
        try:
            # Download state file
            state_key = f"{env}/terraform.tfstate"
            with tempfile.NamedTemporaryFile(suffix='.tfstate', delete=False) as f:
                s3.download_file(state_bucket, state_key, f.name)
                state_file = f.name

            # Run terraform plan
            result = subprocess.run(
                [
                    'terraform', 'plan',
                    '-state', state_file,
                    '-detailed-exitcode',
                    '-no-color'
                ],
                capture_output=True,
                text=True,
                timeout=300
            )

            if result.returncode == 2:  # Changes detected
                drift_results.append({
                    'environment': env,
                    'status': 'DRIFT_DETECTED',
                    'changes': parse_plan_output(result.stdout),
                    'timestamp': datetime.utcnow().isoformat()
                })
            elif result.returncode == 0:
                drift_results.append({
                    'environment': env,
                    'status': 'NO_DRIFT',
                    'timestamp': datetime.utcnow().isoformat()
                })
            else:
                drift_results.append({
                    'environment': env,
                    'status': 'ERROR',
                    'error': result.stderr,
                    'timestamp': datetime.utcnow().isoformat()
                })

        except Exception as e:
            drift_results.append({
                'environment': env,
                'status': 'ERROR',
                'error': str(e),
                'timestamp': datetime.utcnow().isoformat()
            })

    # Send alerts for drift
    drift_environments = [r for r in drift_results if r['status'] == 'DRIFT_DETECTED']

    if drift_environments:
        sns.publish(
            TopicArn=os.environ['SNS_TOPIC_ARN'],
            Subject='Infrastructure Drift Detected',
            Message=json.dumps(drift_environments, indent=2)
        )

        # Slack notification
        send_slack_alert(drift_environments)

    return {
        'statusCode': 200,
        'body': json.dumps(drift_results)
    }

def parse_plan_output(output):
    """Parse terraform plan output to extract changes"""
    changes = {
        'add': 0,
        'change': 0,
        'destroy': 0
    }
    for line in output.split('\n'):
        if 'Plan:' in line:
            # Parse "Plan: X to add, Y to change, Z to destroy"
            parts = line.split(',')
            for part in parts:
                if 'add' in part:
                    changes['add'] = int(part.split()[0])
                elif 'change' in part:
                    changes['change'] = int(part.split()[0])
                elif 'destroy' in part:
                    changes['destroy'] = int(part.split()[0])
    return changes

def send_slack_alert(drift_results):
    """Send Slack notification for drift"""
    import urllib.request

    webhook_url = os.environ.get('SLACK_WEBHOOK_URL')
    if not webhook_url:
        return

    blocks = [
        {
            "type": "header",
            "text": {
                "type": "plain_text",
                "text": "Infrastructure Drift Detected"
            }
        }
    ]

    for result in drift_results:
        changes = result.get('changes', {})
        blocks.append({
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": f"*Environment:* `{result['environment']}`\n"
                        f"*Changes:* +{changes.get('add', 0)} ~{changes.get('change', 0)} -{changes.get('destroy', 0)}"
            }
        })

    payload = json.dumps({"blocks": blocks}).encode('utf-8')
    req = urllib.request.Request(webhook_url, data=payload, headers={'Content-Type': 'application/json'})
    urllib.request.urlopen(req)
```

### Remediation Workflow

```yaml
# .github/workflows/drift-remediation.yml
name: Drift Remediation

on:
  workflow_dispatch:
    inputs:
      environment:
        description: "Environment to remediate"
        required: true
        type: choice
        options:
          - dev
          - staging
          - production
      action:
        description: "Remediation action"
        required: true
        type: choice
        options:
          - apply # Apply Terraform to fix drift
          - import # Import out-of-band changes
          - report # Generate drift report only

jobs:
  remediate:
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment }}
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.6.6"

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1

      - name: Terraform Init
        run: terraform init
        working-directory: infrastructure/environments/${{ github.event.inputs.environment }}

      - name: Generate Drift Report
        run: |
          terraform plan -detailed-exitcode -var-file=terraform.tfvars > drift-report.txt 2>&1 || true
          cat drift-report.txt
        working-directory: infrastructure/environments/${{ github.event.inputs.environment }}

      - name: Apply Remediation
        if: github.event.inputs.action == 'apply'
        run: |
          terraform apply -auto-approve -var-file=terraform.tfvars
        working-directory: infrastructure/environments/${{ github.event.inputs.environment }}

      - name: Upload Report
        uses: actions/upload-artifact@v4
        with:
          name: drift-report-${{ github.event.inputs.environment }}
          path: infrastructure/environments/${{ github.event.inputs.environment }}/drift-report.txt

      - name: Notify Completion
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "Drift remediation completed",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Drift Remediation Complete*\n*Environment:* ${{ github.event.inputs.environment }}\n*Action:* ${{ github.event.inputs.action }}\n*Status:* ${{ job.status }}"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

---

## Related Agents

| Agent                                        | Use Case                                  |
| -------------------------------------------- | ----------------------------------------- |
| `/agents/cloud/aws-expert`                   | AWS-specific resources and best practices |
| `/agents/cloud/gcp-expert`                   | GCP-specific resources and configurations |
| `/agents/cloud/azure-expert`                 | Azure-specific resources and patterns     |
| `/agents/cloud/multi-cloud-expert`           | Multi-cloud architectures                 |
| `/agents/devops/kubernetes-expert`           | K8s resources and Helm charts             |
| `/agents/devops/ci-cd-expert`                | CI/CD pipeline integration                |
| `/agents/devops/github-actions-expert`       | GitHub Actions workflows                  |
| `/agents/security/security-expert`           | Security audits and compliance            |
| `/agents/security/secrets-management-expert` | Vault, Secrets Manager integration        |
| `/agents/testing/integration-test-expert`    | Terratest and infrastructure testing      |

---

## Example Usage

```bash
# Create a new Terraform module
/agents/devops/terraform-expert create VPC module with public/private subnets and NAT gateway

# Configure remote state backend
/agents/devops/terraform-expert set up S3 backend with DynamoDB locking and KMS encryption

# Multi-environment setup
/agents/devops/terraform-expert create directory-based multi-environment structure for dev/staging/prod

# Provider configuration
/agents/devops/terraform-expert configure AWS provider with multi-region and cross-account access

# EKS cluster module
/agents/devops/terraform-expert create EKS module with managed node groups and Fargate profiles

# Terratest tests
/agents/devops/terraform-expert write Terratest tests for VPC module

# CI/CD pipeline
/agents/devops/terraform-expert create GitHub Actions workflow for Terraform CI/CD

# Security hardening
/agents/devops/terraform-expert implement IAM least privilege for ECS task role

# Drift detection
/agents/devops/terraform-expert set up automated drift detection with Lambda and SNS alerts

# Import existing resources
/agents/devops/terraform-expert import existing AWS resources into Terraform state

# State migration
/agents/devops/terraform-expert migrate from local state to S3 backend

# Module versioning
/agents/devops/terraform-expert implement semantic versioning for Terraform modules
```

---

## Quick Reference

```bash
# Initialize
terraform init
terraform init -upgrade
terraform init -reconfigure
terraform init -migrate-state

# Validate
terraform validate
terraform fmt -check -recursive

# Plan
terraform plan
terraform plan -out=tfplan
terraform plan -target=module.vpc
terraform plan -var-file=production.tfvars

# Apply
terraform apply
terraform apply tfplan
terraform apply -auto-approve
terraform apply -target=aws_instance.web

# State
terraform state list
terraform state show aws_instance.web
terraform state mv aws_instance.old aws_instance.new
terraform state rm aws_instance.imported
terraform import aws_instance.web i-1234567890abcdef0
terraform force-unlock LOCK_ID

# Workspaces
terraform workspace list
terraform workspace new staging
terraform workspace select production
terraform workspace delete dev

# Output
terraform output
terraform output -json
terraform output vpc_id

# Destroy
terraform destroy
terraform destroy -target=module.database

# Debug
TF_LOG=DEBUG terraform plan
TF_LOG_PATH=./terraform.log terraform apply

# Graph
terraform graph | dot -Tpng > graph.png

# Providers
terraform providers
terraform providers lock -platform=linux_amd64
```

---

## Checklists

### Module Development Checklist

- [ ] Clear, single responsibility
- [ ] Input validation with `validation` blocks
- [ ] Sensible defaults for optional variables
- [ ] Meaningful outputs exposed
- [ ] README with examples
- [ ] terraform-docs generated documentation
- [ ] Version constraints in versions.tf
- [ ] Terratest or equivalent tests
- [ ] Examples directory with working configurations

### Security Checklist

- [ ] No hardcoded secrets in code
- [ ] Sensitive variables marked with `sensitive = true`
- [ ] State file encrypted at rest
- [ ] IAM roles follow least privilege
- [ ] Security groups default deny
- [ ] All storage encrypted (S3, EBS, RDS)
- [ ] VPC Flow Logs enabled
- [ ] CloudTrail enabled for audit
- [ ] Checkov/tfsec scans passing

### CI/CD Checklist

- [ ] Format check (`terraform fmt`)
- [ ] Validation (`terraform validate`)
- [ ] Linting (tflint)
- [ ] Security scanning (Checkov)
- [ ] Plan for all environments
- [ ] Plan output as PR comment
- [ ] Manual approval for production
- [ ] State locking configured
- [ ] Drift detection scheduled

### Pre-Apply Checklist

- [ ] Plan reviewed and understood
- [ ] No unexpected destroys
- [ ] State backup available
- [ ] Rollback plan documented
- [ ] Team notified of changes
- [ ] Change window approved (for production)

---

_Terraform Expert Agent v3.0.0 | Author: Ahmed Adel Bakr Alderai_
