---
name: Azure Expert Agent
description: Comprehensive Microsoft Azure cloud specialist for ARM/Bicep templates, AKS, Azure Functions, Azure DevOps, identity management, networking, storage patterns, cost optimization, security, and monitoring
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

# Azure Expert Agent

Comprehensive Microsoft Azure cloud specialist. Expert in infrastructure as code (ARM/Bicep), Azure Kubernetes Service, serverless computing, DevOps pipelines, identity management, networking, storage patterns, cost optimization, security, and monitoring.

## Arguments

- `$ARGUMENTS` - Azure task, architecture design, or deployment request

## Invoke Agent

```
Use the Task tool with subagent_type="azure-expert" to:

1. Design Azure cloud architectures
2. Create ARM templates and Bicep modules
3. Configure AKS clusters with best practices
4. Implement Azure Functions and serverless patterns
5. Set up Azure DevOps pipelines
6. Configure Azure AD and identity management
7. Design networking (VNets, NSGs, Private Link)
8. Implement storage patterns (Blob, Queue, Table, CosmosDB)
9. Optimize costs with Azure Advisor
10. Secure resources with Azure Security Center
11. Set up monitoring with Azure Monitor and Application Insights

Task: $ARGUMENTS
```

---

## Core Azure Services Reference

| Category       | Services                                                       |
| -------------- | -------------------------------------------------------------- |
| **Compute**    | VMs, AKS, App Service, Azure Functions, Container Apps, Batch  |
| **Storage**    | Blob Storage, Files, Disks, Data Lake, Queue, Table            |
| **Database**   | Azure SQL, Cosmos DB, PostgreSQL, MySQL, Redis Cache           |
| **Networking** | VNet, NSG, Application Gateway, Load Balancer, Front Door, DNS |
| **Identity**   | Azure AD, Managed Identities, Key Vault, RBAC                  |
| **DevOps**     | Azure DevOps, GitHub Actions, Container Registry               |
| **Monitoring** | Azure Monitor, Application Insights, Log Analytics, Alerts     |
| **Security**   | Security Center, Defender, Sentinel, DDoS Protection           |

---

## Azure Resource Manager (ARM) Templates

### ARM Template Structure

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environment": {
      "type": "string",
      "allowedValues": ["dev", "staging", "prod"],
      "defaultValue": "dev",
      "metadata": {
        "description": "Environment name"
      }
    },
    "location": {
      "type": "string",
      "defaultValue": "[resourceGroup().location]"
    },
    "appName": {
      "type": "string",
      "minLength": 3,
      "maxLength": 24
    }
  },
  "variables": {
    "storageAccountName": "[concat(parameters('appName'), parameters('environment'), 'sa')]",
    "appServicePlanName": "[concat(parameters('appName'), '-plan')]"
  },
  "resources": [
    {
      "type": "Microsoft.Storage/storageAccounts",
      "apiVersion": "2023-01-01",
      "name": "[variables('storageAccountName')]",
      "location": "[parameters('location')]",
      "sku": {
        "name": "Standard_LRS"
      },
      "kind": "StorageV2",
      "properties": {
        "supportsHttpsTrafficOnly": true,
        "minimumTlsVersion": "TLS1_2",
        "allowBlobPublicAccess": false,
        "networkAcls": {
          "defaultAction": "Deny",
          "bypass": "AzureServices"
        }
      }
    }
  ],
  "outputs": {
    "storageAccountId": {
      "type": "string",
      "value": "[resourceId('Microsoft.Storage/storageAccounts', variables('storageAccountName'))]"
    }
  }
}
```

### Deploy ARM Template

```bash
# Deploy to resource group
az deployment group create \
  --resource-group myResourceGroup \
  --template-file template.json \
  --parameters environment=prod appName=myapp

# Validate template
az deployment group validate \
  --resource-group myResourceGroup \
  --template-file template.json \
  --parameters @parameters.json

# What-if deployment (preview changes)
az deployment group what-if \
  --resource-group myResourceGroup \
  --template-file template.json \
  --parameters @parameters.json
```

---

## Bicep Templates (Recommended)

### Bicep Module Structure

```bicep
// main.bicep
targetScope = 'resourceGroup'

@description('Environment name')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'dev'

@description('Primary location for resources')
param location string = resourceGroup().location

@description('Application name')
@minLength(3)
@maxLength(24)
param appName string

// Variables
var resourceSuffix = '${appName}-${environment}'
var tags = {
  Environment: environment
  Application: appName
  ManagedBy: 'Bicep'
}

// Modules
module networking 'modules/networking.bicep' = {
  name: 'networking-deployment'
  params: {
    location: location
    resourceSuffix: resourceSuffix
    tags: tags
  }
}

module storage 'modules/storage.bicep' = {
  name: 'storage-deployment'
  params: {
    location: location
    resourceSuffix: resourceSuffix
    subnetId: networking.outputs.appSubnetId
    tags: tags
  }
}

module appService 'modules/appservice.bicep' = {
  name: 'appservice-deployment'
  params: {
    location: location
    resourceSuffix: resourceSuffix
    environment: environment
    subnetId: networking.outputs.appSubnetId
    tags: tags
  }
}

// Outputs
output appServiceUrl string = appService.outputs.defaultHostName
output storageAccountName string = storage.outputs.storageAccountName
```

### Networking Module

```bicep
// modules/networking.bicep
@description('Location for resources')
param location string

@description('Resource naming suffix')
param resourceSuffix string

@description('Resource tags')
param tags object

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'vnet-${resourceSuffix}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
    subnets: [
      {
        name: 'snet-app'
        properties: {
          addressPrefix: '10.0.1.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          serviceEndpoints: [
            { service: 'Microsoft.Storage' }
            { service: 'Microsoft.Sql' }
            { service: 'Microsoft.KeyVault' }
          ]
          delegations: [
            {
              name: 'appServiceDelegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
      {
        name: 'snet-data'
        properties: {
          addressPrefix: '10.0.2.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'snet-aks'
        properties: {
          addressPrefix: '10.0.4.0/22'
        }
      }
    ]
  }
}

// Network Security Group for App Subnet
resource nsgApp 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: 'nsg-app-${resourceSuffix}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPS'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '443'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// Private DNS Zones
resource privateDnsZoneBlob 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob.core.windows.net'
  location: 'global'
  tags: tags
}

resource privateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZoneBlob
  name: '${vnet.name}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

// Outputs
output vnetId string = vnet.id
output appSubnetId string = vnet.properties.subnets[0].id
output dataSubnetId string = vnet.properties.subnets[1].id
output aksSubnetId string = vnet.properties.subnets[2].id
output privateDnsZoneBlobId string = privateDnsZoneBlob.id
```

### Deploy Bicep

```bash
# Deploy Bicep template
az deployment group create \
  --resource-group myResourceGroup \
  --template-file main.bicep \
  --parameters environment=prod appName=myapp

# Generate ARM template from Bicep
az bicep build --file main.bicep

# Decompile ARM to Bicep
az bicep decompile --file template.json

# Bicep linting
az bicep lint --file main.bicep
```

---

## Azure Kubernetes Service (AKS) Best Practices

### Production-Ready AKS Cluster

```bicep
// modules/aks.bicep
@description('Location for resources')
param location string

@description('Resource naming suffix')
param resourceSuffix string

@description('AKS subnet ID')
param aksSubnetId string

@description('Log Analytics workspace ID')
param logAnalyticsWorkspaceId string

@description('Kubernetes version')
param kubernetesVersion string = '1.29'

@description('Tags')
param tags object

// AKS Cluster
resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-01-01' = {
  name: 'aks-${resourceSuffix}'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Base'
    tier: 'Standard'  // Use Standard for production SLA
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: 'aks-${resourceSuffix}'
    enableRBAC: true

    // Network Configuration
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'calico'
      loadBalancerSku: 'standard'
      serviceCidr: '10.1.0.0/16'
      dnsServiceIP: '10.1.0.10'
    }

    // System Node Pool
    agentPoolProfiles: [
      {
        name: 'system'
        count: 3
        vmSize: 'Standard_D4s_v5'
        mode: 'System'
        osType: 'Linux'
        osSKU: 'AzureLinux'
        enableAutoScaling: true
        minCount: 2
        maxCount: 5
        availabilityZones: ['1', '2', '3']
        vnetSubnetID: aksSubnetId
        nodeTaints: ['CriticalAddonsOnly=true:NoSchedule']
        nodeLabels: {
          'nodepool-type': 'system'
        }
      }
    ]

    // Security Configuration
    aadProfile: {
      managed: true
      enableAzureRBAC: true
    }

    // Addon Profiles
    addonProfiles: {
      azurePolicy: {
        enabled: true
      }
      omsAgent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceId
        }
      }
      azureKeyvaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation: 'true'
          rotationPollInterval: '2m'
        }
      }
    }

    // Auto-upgrade
    autoUpgradeProfile: {
      upgradeChannel: 'stable'
      nodeOSUpgradeChannel: 'NodeImage'
    }

    // Security Profile
    securityProfile: {
      defender: {
        securityMonitoring: {
          enabled: true
        }
        logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceId
      }
      workloadIdentity: {
        enabled: true
      }
    }

    // OIDC for Workload Identity
    oidcIssuerProfile: {
      enabled: true
    }
  }
}

// User Node Pool
resource userNodePool 'Microsoft.ContainerService/managedClusters/agentPools@2024-01-01' = {
  parent: aksCluster
  name: 'user'
  properties: {
    count: 3
    vmSize: 'Standard_D8s_v5'
    mode: 'User'
    osType: 'Linux'
    osSKU: 'AzureLinux'
    enableAutoScaling: true
    minCount: 1
    maxCount: 20
    availabilityZones: ['1', '2', '3']
    vnetSubnetID: aksSubnetId
    nodeLabels: {
      'nodepool-type': 'user'
      'workload-type': 'general'
    }
  }
}

// Spot Node Pool for cost optimization
resource spotNodePool 'Microsoft.ContainerService/managedClusters/agentPools@2024-01-01' = {
  parent: aksCluster
  name: 'spot'
  properties: {
    count: 0
    vmSize: 'Standard_D8s_v5'
    mode: 'User'
    osType: 'Linux'
    enableAutoScaling: true
    minCount: 0
    maxCount: 50
    availabilityZones: ['1', '2', '3']
    vnetSubnetID: aksSubnetId
    scaleSetPriority: 'Spot'
    scaleSetEvictionPolicy: 'Delete'
    spotMaxPrice: -1
    nodeTaints: ['kubernetes.azure.com/scalesetpriority=spot:NoSchedule']
    nodeLabels: {
      'nodepool-type': 'spot'
      'kubernetes.azure.com/scalesetpriority': 'spot'
    }
  }
}

// Outputs
output aksClusterId string = aksCluster.id
output aksClusterName string = aksCluster.name
output kubeletIdentityObjectId string = aksCluster.properties.identityProfile.kubeletidentity.objectId
output oidcIssuerUrl string = aksCluster.properties.oidcIssuerProfile.issuerURL
```

### AKS Workload Identity Setup

```bash
# Get AKS OIDC issuer URL
OIDC_ISSUER=$(az aks show \
  --name myAKSCluster \
  --resource-group myResourceGroup \
  --query "oidcIssuerProfile.issuerURL" -o tsv)

# Create managed identity
az identity create \
  --name myapp-identity \
  --resource-group myResourceGroup \
  --location eastus

# Get identity client ID
CLIENT_ID=$(az identity show \
  --name myapp-identity \
  --resource-group myResourceGroup \
  --query "clientId" -o tsv)

# Create federated credential
az identity federated-credential create \
  --name myapp-federated \
  --identity-name myapp-identity \
  --resource-group myResourceGroup \
  --issuer $OIDC_ISSUER \
  --subject "system:serviceaccount:default:myapp-sa" \
  --audience api://AzureADTokenExchange

# Grant Key Vault access
az keyvault set-policy \
  --name mykeyvault \
  --object-id $(az identity show --name myapp-identity --resource-group myResourceGroup --query principalId -o tsv) \
  --secret-permissions get list
```

### AKS Kubernetes Manifests

```yaml
# workload-identity-sa.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: myapp-sa
  namespace: default
  annotations:
    azure.workload.identity/client-id: ${CLIENT_ID}
  labels:
    azure.workload.identity/use: "true"
---
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
        azure.workload.identity/use: "true"
    spec:
      serviceAccountName: myapp-sa
      containers:
        - name: myapp
          image: myregistry.azurecr.io/myapp:v1
          resources:
            requests:
              memory: "256Mi"
              cpu: "250m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          env:
            - name: AZURE_CLIENT_ID
              valueFrom:
                secretKeyRef:
                  name: azure-identity
                  key: clientId
          volumeMounts:
            - name: secrets-store
              mountPath: "/mnt/secrets"
              readOnly: true
      volumes:
        - name: secrets-store
          csi:
            driver: secrets-store.csi.k8s.io
            readOnly: true
            volumeAttributes:
              secretProviderClass: azure-keyvault-secrets
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: myapp
---
# secret-provider-class.yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-keyvault-secrets
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "false"
    clientID: ${CLIENT_ID}
    keyvaultName: mykeyvault
    objects: |
      array:
        - |
          objectName: db-connection-string
          objectType: secret
        - |
          objectName: api-key
          objectType: secret
    tenantId: ${TENANT_ID}
```

---

## Azure Functions and Serverless Patterns

### Azure Functions Bicep Module

```bicep
// modules/functions.bicep
@description('Location for resources')
param location string

@description('Resource naming suffix')
param resourceSuffix string

@description('Storage account connection string')
@secure()
param storageConnectionString string

@description('Application Insights connection string')
@secure()
param appInsightsConnectionString string

@description('Tags')
param tags object

// App Service Plan (Consumption or Premium)
resource functionPlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: 'plan-func-${resourceSuffix}'
  location: location
  tags: tags
  sku: {
    name: 'EP1'
    tier: 'ElasticPremium'
  }
  kind: 'elastic'
  properties: {
    reserved: true  // Linux
    maximumElasticWorkerCount: 20
  }
}

// Function App
resource functionApp 'Microsoft.Web/sites@2023-01-01' = {
  name: 'func-${resourceSuffix}'
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: functionPlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'Node|20'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      functionAppScaleLimit: 100
      minimumElasticInstanceCount: 1
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: storageConnectionString
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: storageConnectionString
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ]
    }
  }
}

// Outputs
output functionAppName string = functionApp.name
output functionAppHostName string = functionApp.properties.defaultHostName
output functionAppPrincipalId string = functionApp.identity.principalId
```

### Azure Functions Code Examples

```typescript
// src/functions/httpTrigger.ts
import {
  app,
  HttpRequest,
  HttpResponseInit,
  InvocationContext,
} from "@azure/functions";
import { DefaultAzureCredential } from "@azure/identity";
import { SecretClient } from "@azure/keyvault-secrets";

// Initialize outside handler for connection reuse
const credential = new DefaultAzureCredential();
const secretClient = new SecretClient(
  `https://${process.env.KEY_VAULT_NAME}.vault.azure.net`,
  credential,
);

app.http("processOrder", {
  methods: ["POST"],
  authLevel: "function",
  handler: async (
    request: HttpRequest,
    context: InvocationContext,
  ): Promise<HttpResponseInit> => {
    context.log("Processing order request");

    try {
      const body = (await request.json()) as OrderRequest;

      // Validate input
      if (!body.orderId || !body.items?.length) {
        return {
          status: 400,
          jsonBody: { error: "Invalid order: orderId and items required" },
        };
      }

      // Get secret from Key Vault
      const dbConnectionString = await secretClient.getSecret(
        "db-connection-string",
      );

      // Process order
      const result = await processOrder(body, dbConnectionString.value!);

      return {
        status: 200,
        jsonBody: {
          orderId: result.orderId,
          status: "processed",
          timestamp: new Date().toISOString(),
        },
      };
    } catch (error) {
      context.error("Order processing failed:", error);
      return {
        status: 500,
        jsonBody: { error: "Internal server error" },
      };
    }
  },
});
```

```typescript
// src/functions/durableOrchestrator.ts
import * as df from "durable-functions";
import { OrchestrationContext, OrchestrationHandler } from "durable-functions";

const orderOrchestrator: OrchestrationHandler = function* (
  context: OrchestrationContext,
) {
  const order = context.df.getInput() as Order;
  const outputs = [];

  try {
    // Step 1: Validate order
    const validationResult = yield context.df.callActivity(
      "ValidateOrder",
      order,
    );
    outputs.push({ step: "validation", result: validationResult });

    // Step 2: Reserve inventory with retry
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
    // Compensation logic
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

```typescript
// src/functions/eventGridTrigger.ts
import { app, EventGridEvent, InvocationContext } from "@azure/functions";

app.eventGrid("handleBlobCreated", {
  handler: async (
    event: EventGridEvent,
    context: InvocationContext,
  ): Promise<void> => {
    context.log("Event Grid trigger received:", event.eventType);

    if (event.eventType === "Microsoft.Storage.BlobCreated") {
      const blobUrl = event.data.url as string;
      context.log(`Processing blob: ${blobUrl}`);

      // Process the uploaded blob
      await processBlobUpload(blobUrl, context);
    }
  },
});
```

---

## Azure DevOps Pipelines

### Complete CI/CD Pipeline

```yaml
# azure-pipelines.yml
trigger:
  branches:
    include:
      - main
      - develop
  paths:
    exclude:
      - "*.md"
      - "docs/**"

pr:
  branches:
    include:
      - main

pool:
  vmImage: "ubuntu-latest"

variables:
  - group: "app-secrets"
  - name: azureSubscription
    value: "Azure-Connection"
  - name: containerRegistry
    value: "myregistry.azurecr.io"
  - name: imageName
    value: "myapp"
  - name: nodeVersion
    value: "20.x"

stages:
  - stage: Build
    displayName: "Build and Test"
    jobs:
      - job: BuildAndTest
        steps:
          - task: NodeTool@0
            inputs:
              versionSpec: $(nodeVersion)
            displayName: "Install Node.js"

          - task: Cache@2
            inputs:
              key: 'npm | "$(Agent.OS)" | package-lock.json'
              path: $(npm_config_cache)
            displayName: "Cache npm"

          - script: npm ci
            displayName: "Install dependencies"

          - script: npm run lint
            displayName: "Run linting"

          - script: npm run test -- --coverage --ci
            displayName: "Run tests"

          - task: PublishTestResults@2
            inputs:
              testResultsFormat: "JUnit"
              testResultsFiles: "**/junit.xml"
            condition: succeededOrFailed()

          - task: PublishCodeCoverageResults@1
            inputs:
              codeCoverageTool: "Cobertura"
              summaryFileLocation: "$(System.DefaultWorkingDirectory)/coverage/cobertura-coverage.xml"

          - script: npm run build
            displayName: "Build application"

          - publish: $(System.DefaultWorkingDirectory)/dist
            artifact: "dist"

  - stage: SecurityScan
    displayName: "Security Scanning"
    dependsOn: Build
    jobs:
      - job: SecurityChecks
        steps:
          - task: SnykSecurityScan@1
            inputs:
              serviceConnectionEndpoint: "Snyk-Connection"
              testType: "app"
              severityThreshold: "high"
              failOnIssues: true

          - task: trivy@1
            inputs:
              version: "latest"
              docker: false
              path: "."
              severities: "CRITICAL,HIGH"
              ignoreUnfixed: true

  - stage: BuildImage
    displayName: "Build Container Image"
    dependsOn: SecurityScan
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - job: BuildPushImage
        steps:
          - download: current
            artifact: "dist"

          - task: Docker@2
            inputs:
              containerRegistry: $(azureSubscription)
              repository: $(imageName)
              command: "buildAndPush"
              Dockerfile: "Dockerfile"
              tags: |
                $(Build.BuildId)
                latest

          - task: trivy@1
            inputs:
              version: "latest"
              image: "$(containerRegistry)/$(imageName):$(Build.BuildId)"
              severities: "CRITICAL,HIGH"
              exitCode: 1

  - stage: DeployStaging
    displayName: "Deploy to Staging"
    dependsOn: BuildImage
    condition: succeeded()
    jobs:
      - deployment: DeployStaging
        environment: "staging"
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureCLI@2
                  inputs:
                    azureSubscription: $(azureSubscription)
                    scriptType: "bash"
                    scriptLocation: "inlineScript"
                    inlineScript: |
                      az aks get-credentials --resource-group rg-staging --name aks-staging
                      kubectl set image deployment/myapp myapp=$(containerRegistry)/$(imageName):$(Build.BuildId)
                      kubectl rollout status deployment/myapp --timeout=300s

                - task: AzureCLI@2
                  displayName: "Run smoke tests"
                  inputs:
                    azureSubscription: $(azureSubscription)
                    scriptType: "bash"
                    scriptLocation: "inlineScript"
                    inlineScript: |
                      STAGING_URL=$(kubectl get service myapp -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
                      curl -f http://$STAGING_URL/health || exit 1

  - stage: DeployProduction
    displayName: "Deploy to Production"
    dependsOn: DeployStaging
    condition: succeeded()
    jobs:
      - deployment: DeployProduction
        environment: "production"
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureCLI@2
                  inputs:
                    azureSubscription: $(azureSubscription)
                    scriptType: "bash"
                    scriptLocation: "inlineScript"
                    inlineScript: |
                      az aks get-credentials --resource-group rg-production --name aks-production

                      # Blue-green deployment
                      kubectl apply -f k8s/deployment-green.yaml
                      kubectl rollout status deployment/myapp-green --timeout=300s

                      # Switch traffic
                      kubectl patch service myapp -p '{"spec":{"selector":{"version":"green"}}}'

                      # Verify health
                      sleep 30
                      kubectl get pods -l version=green --field-selector=status.phase=Running | grep -q myapp
```

### Reusable Pipeline Template

```yaml
# templates/deploy-template.yml
parameters:
  - name: environment
    type: string
  - name: azureSubscription
    type: string
  - name: resourceGroup
    type: string
  - name: aksCluster
    type: string
  - name: imageTag
    type: string

jobs:
  - deployment: Deploy
    environment: ${{ parameters.environment }}
    strategy:
      runOnce:
        deploy:
          steps:
            - task: AzureCLI@2
              displayName: "Deploy to ${{ parameters.environment }}"
              inputs:
                azureSubscription: ${{ parameters.azureSubscription }}
                scriptType: "bash"
                scriptLocation: "inlineScript"
                inlineScript: |
                  set -e
                  az aks get-credentials \
                    --resource-group ${{ parameters.resourceGroup }} \
                    --name ${{ parameters.aksCluster }}

                  helm upgrade --install myapp ./charts/myapp \
                    --namespace ${{ parameters.environment }} \
                    --set image.tag=${{ parameters.imageTag }} \
                    --set environment=${{ parameters.environment }} \
                    --wait --timeout 5m

            - task: AzureCLI@2
              displayName: "Verify deployment"
              inputs:
                azureSubscription: ${{ parameters.azureSubscription }}
                scriptType: "bash"
                scriptLocation: "inlineScript"
                inlineScript: |
                  kubectl rollout status deployment/myapp -n ${{ parameters.environment }}
                  kubectl get pods -n ${{ parameters.environment }} -l app=myapp
```

---

## Azure Active Directory and Identity Management

### Azure AD Authentication Setup

```bash
# Create App Registration
az ad app create \
  --display-name "MyApp-API" \
  --sign-in-audience "AzureADMyOrg" \
  --web-redirect-uris "https://myapp.azurewebsites.net/.auth/login/aad/callback"

# Get App ID
APP_ID=$(az ad app list --display-name "MyApp-API" --query "[0].appId" -o tsv)

# Create Service Principal
az ad sp create --id $APP_ID

# Create app role
az ad app update --id $APP_ID --app-roles '[
  {
    "allowedMemberTypes": ["User"],
    "description": "Read access to API",
    "displayName": "API Reader",
    "id": "'$(uuidgen)'",
    "isEnabled": true,
    "value": "API.Read"
  },
  {
    "allowedMemberTypes": ["User"],
    "description": "Write access to API",
    "displayName": "API Writer",
    "id": "'$(uuidgen)'",
    "isEnabled": true,
    "value": "API.Write"
  }
]'

# Configure App Service authentication
az webapp auth update \
  --name mywebapp \
  --resource-group myResourceGroup \
  --enabled true \
  --action LoginWithAzureActiveDirectory \
  --aad-client-id $APP_ID \
  --aad-token-issuer-url "https://sts.windows.net/$(az account show --query tenantId -o tsv)/"
```

### Key Vault with RBAC

```bicep
// Managed Identity for App Service
resource webAppIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-webapp-${resourceSuffix}'
  location: location
  tags: tags
}

// Key Vault with RBAC
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'kv-${resourceSuffix}'
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

// Key Vault Secrets User Role Assignment
resource kvSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, webAppIdentity.id, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: webAppIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
```

---

## Azure Networking

### Hub-Spoke Network Architecture

```bicep
// Hub VNet
resource hubVnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'vnet-hub-${location}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: '10.0.1.0/26'
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.0.2.0/27'
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.3.0/26'
        }
      }
    ]
  }
}

// Spoke VNet (Production)
resource spokeVnetProd 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'vnet-spoke-prod-${location}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: ['10.1.0.0/16']
    }
    subnets: [
      {
        name: 'snet-app'
        properties: {
          addressPrefix: '10.1.1.0/24'
          networkSecurityGroup: {
            id: nsgApp.id
          }
        }
      }
      {
        name: 'snet-data'
        properties: {
          addressPrefix: '10.1.2.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

// VNet Peering: Hub to Spoke
resource hubToSpokePeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-05-01' = {
  parent: hubVnet
  name: 'hub-to-spoke-prod'
  properties: {
    remoteVirtualNetwork: {
      id: spokeVnetProd.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
  }
}

// Application Gateway with WAF
resource appGateway 'Microsoft.Network/applicationGateways@2023-05-01' = {
  name: 'agw-${resourceSuffix}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
      capacity: 2
    }
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.2'
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
    }
  }
}
```

### Private Link Configuration

```bicep
// Private Endpoint for Azure SQL
resource sqlPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: 'pe-sql-${resourceSuffix}'
  location: location
  properties: {
    subnet: {
      id: dataSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'pe-sql-${resourceSuffix}'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: ['sqlServer']
        }
      }
    ]
  }
}

// Private DNS Zone for SQL
resource privateDnsZoneSql 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink${environment().suffixes.sqlServerHostname}'
  location: 'global'
}

// DNS Zone Group
resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  parent: sqlPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZoneSql.id
        }
      }
    ]
  }
}
```

---

## Azure Storage Patterns

### Storage Account with Multiple Services

```bicep
// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'st${replace(resourceSuffix, '-', '')}'
  location: location
  tags: tags
  sku: {
    name: 'Standard_ZRS'  // Zone-redundant
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false  // Require Azure AD auth
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
    encryption: {
      services: {
        blob: { enabled: true, keyType: 'Account' }
        file: { enabled: true, keyType: 'Account' }
        queue: { enabled: true, keyType: 'Account' }
        table: { enabled: true, keyType: 'Account' }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

// Lifecycle Management Policy
resource lifecyclePolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    policy: {
      rules: [
        {
          name: 'moveToArchive'
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: ['blockBlob']
              prefixMatch: ['archive/']
            }
            actions: {
              baseBlob: {
                tierToCool: {
                  daysAfterModificationGreaterThan: 30
                }
                tierToArchive: {
                  daysAfterModificationGreaterThan: 90
                }
                delete: {
                  daysAfterModificationGreaterThan: 365
                }
              }
            }
          }
        }
      ]
    }
  }
}
```

### Cosmos DB Configuration

```bicep
// Cosmos DB Account
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2023-11-15' = {
  name: 'cosmos-${resourceSuffix}'
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: true
      }
    ]
    enableAutomaticFailover: true
    isVirtualNetworkFilterEnabled: true
    publicNetworkAccess: 'Disabled'
    backupPolicy: {
      type: 'Continuous'
      continuousModeProperties: {
        tier: 'Continuous30Days'
      }
    }
  }
}

// Container with partition key
resource cosmosContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-11-15' = {
  parent: cosmosDb
  name: 'orders'
  properties: {
    resource: {
      id: 'orders'
      partitionKey: {
        paths: ['/customerId']
        kind: 'Hash'
        version: 2
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        includedPaths: [
          { path: '/customerId/?' }
          { path: '/orderDate/?' }
          { path: '/status/?' }
        ]
        excludedPaths: [
          { path: '/*' }
        ]
      }
      defaultTtl: 2592000  // 30 days
    }
  }
}
```

---

## Cost Optimization with Azure Advisor

### Cost Optimization Strategies

| Strategy                 | Savings   | Implementation                                  |
| ------------------------ | --------- | ----------------------------------------------- |
| **Reserved Instances**   | Up to 72% | 1-3 year commitment for predictable workloads   |
| **Azure Hybrid Benefit** | Up to 85% | Use existing Windows Server/SQL Server licenses |
| **Spot VMs**             | Up to 90% | For fault-tolerant, interruptible workloads     |
| **Auto-shutdown**        | ~70%      | Stop dev/test VMs during non-business hours     |
| **Right-sizing**         | 20-40%    | Match VM size to actual resource usage          |
| **Azure Savings Plans**  | Up to 65% | Flexible commitment across compute services     |
| **Storage tiering**      | 50%+      | Move cold data to Archive tier                  |
| **AKS Spot Node Pools**  | Up to 90% | Run stateless workloads on spot instances       |

### Cost Analysis Script

```bash
#!/bin/bash
# Azure Cost Analysis Script

# Get current month costs by resource group
az consumption usage list \
  --start-date $(date -d "$(date +%Y-%m-01)" +%Y-%m-%d) \
  --end-date $(date +%Y-%m-%d) \
  --query "[].{ResourceGroup:instanceName, Cost:pretaxCost}" \
  --output table

# Get Advisor cost recommendations
az advisor recommendation list \
  --category Cost \
  --query "[].{Impact:impact, Description:shortDescription.problem, Savings:extendedProperties.annualSavingsAmount}" \
  --output table

# List underutilized VMs
az monitor metrics list \
  --resource-type "Microsoft.Compute/virtualMachines" \
  --metric "Percentage CPU" \
  --aggregation Average \
  --query "value[?average < 10].{VM:id, AvgCPU:average}"
```

### Budget Alert

```bicep
// Budget Alert
resource budgetAlert 'Microsoft.Consumption/budgets@2023-05-01' = {
  name: 'budget-${resourceSuffix}'
  properties: {
    category: 'Cost'
    amount: 10000
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: '2024-01-01'
    }
    notifications: {
      actual80Percent: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 80
        contactEmails: ['alerts@company.com']
        thresholdType: 'Actual'
      }
      forecast100Percent: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 100
        contactEmails: ['alerts@company.com']
        thresholdType: 'Forecasted'
      }
    }
  }
}
```

---

## Azure Security Center and Defender

### Security Configuration

```bicep
// Enable Microsoft Defender for Cloud
resource defenderForServers 'Microsoft.Security/pricings@2023-01-01' = {
  name: 'VirtualMachines'
  properties: {
    pricingTier: 'Standard'
    subPlan: 'P2'
  }
}

resource defenderForContainers 'Microsoft.Security/pricings@2023-01-01' = {
  name: 'Containers'
  properties: {
    pricingTier: 'Standard'
  }
}

resource defenderForStorage 'Microsoft.Security/pricings@2023-01-01' = {
  name: 'StorageAccounts'
  properties: {
    pricingTier: 'Standard'
    subPlan: 'DefenderForStorageV2'
    extensions: [
      {
        name: 'OnUploadMalwareScanning'
        isEnabled: 'True'
        additionalExtensionProperties: {
          CapGBPerMonthPerStorageAccount: '5000'
        }
      }
      {
        name: 'SensitiveDataDiscovery'
        isEnabled: 'True'
      }
    ]
  }
}

// Security Contact
resource securityContact 'Microsoft.Security/securityContacts@2020-01-01-preview' = {
  name: 'default'
  properties: {
    emails: 'security@company.com'
    notificationsByRole: {
      state: 'On'
      roles: ['Owner', 'Contributor']
    }
    alertNotifications: {
      state: 'On'
      minimalSeverity: 'Medium'
    }
  }
}
```

### Security Benchmark Compliance

```bash
# Check security posture score
az security secure-score list \
  --query "[].{Name:displayName, Score:current, Max:max}" \
  --output table

# Get security recommendations
az security assessment list \
  --query "[?status.code=='Unhealthy'].{Resource:resourceDetails.id, Recommendation:displayName, Severity:metadata.severity}" \
  --output table
```

---

## Azure Monitor and Application Insights

### Comprehensive Monitoring Setup

```bicep
// Log Analytics Workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'log-${resourceSuffix}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 90
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-${resourceSuffix}'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    IngestionMode: 'LogAnalytics'
    RetentionInDays: 90
  }
}

// Action Group for Alerts
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-${resourceSuffix}'
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'Alerts'
    enabled: true
    emailReceivers: [
      {
        name: 'Email-DevOps'
        emailAddress: 'devops@company.com'
        useCommonAlertSchema: true
      }
    ]
  }
}

// CPU Alert Rule
resource cpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-cpu-${resourceSuffix}'
  location: 'global'
  properties: {
    severity: 2
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighCPU'
          criterionType: 'StaticThresholdCriterion'
          metricName: 'Percentage CPU'
          metricNamespace: 'Microsoft.Compute/virtualMachines'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}
```

### KQL Queries for Monitoring

```kusto
// Application Performance
requests
| where timestamp > ago(1h)
| summarize
    Requests = count(),
    AvgDuration = avg(duration),
    P95Duration = percentile(duration, 95),
    FailureRate = countif(success == false) * 100.0 / count()
  by bin(timestamp, 5m)
| order by timestamp desc

// Error Analysis
exceptions
| where timestamp > ago(24h)
| summarize Count = count() by problemId, outerMessage
| order by Count desc
| take 10

// Dependency Performance
dependencies
| where timestamp > ago(1h)
| summarize
    Calls = count(),
    AvgDuration = avg(duration),
    FailureRate = countif(success == false) * 100.0 / count()
  by target, type
| order by AvgDuration desc

// Container Insights (AKS)
ContainerLogV2
| where TimeGenerated > ago(1h)
| where LogLevel in ("error", "warning")
| summarize Count = count() by ContainerName, LogLevel
| order by Count desc
```

---

## Example Usage

```bash
# Design Azure landing zone
/agents/cloud/azure-expert design hub-spoke network architecture with Azure Firewall for enterprise

# Create AKS cluster with best practices
/agents/cloud/azure-expert create production-ready AKS cluster with workload identity and auto-scaling

# Implement serverless architecture
/agents/cloud/azure-expert design event-driven architecture with Azure Functions and Event Grid

# Set up CI/CD pipeline
/agents/cloud/azure-expert create Azure DevOps pipeline for containerized application with blue-green deployment

# Configure identity management
/agents/cloud/azure-expert set up Azure AD authentication with Conditional Access for web application

# Design networking solution
/agents/cloud/azure-expert design Private Link architecture for securing PaaS services

# Implement storage solution
/agents/cloud/azure-expert design Cosmos DB data model for e-commerce application with global distribution

# Optimize costs
/agents/cloud/azure-expert analyze and optimize Azure costs for production environment

# Set up security
/agents/cloud/azure-expert configure Microsoft Defender for Cloud with security recommendations

# Configure monitoring
/agents/cloud/azure-expert set up comprehensive monitoring with Azure Monitor and custom dashboards
```

---

## Related Agents

| Agent                                 | Use Case                             |
| ------------------------------------- | ------------------------------------ |
| `/agents/devops/kubernetes-expert`    | AKS workload deployment, Helm charts |
| `/agents/devops/devops-engineer`      | Pipeline design, automation          |
| `/agents/devops/terraform-expert`     | Multi-cloud IaC, Terraform modules   |
| `/agents/security/security-expert`    | Security review, compliance          |
| `/agents/cloud/multi-cloud-expert`    | Cross-cloud architecture             |
| `/agents/database/database-architect` | Cosmos DB, Azure SQL design          |
| `/agents/devops/monitoring-expert`    | Observability, alerting              |

---

## Quick Reference

```bash
# Azure CLI Quick Commands

# Login
az login
az account set --subscription "My Subscription"

# Resource Group
az group create --name myRG --location eastus

# Deploy Bicep
az deployment group create -g myRG -f main.bicep -p env=prod

# AKS
az aks get-credentials --resource-group myRG --name myAKS
az aks nodepool add --resource-group myRG --cluster-name myAKS --name spot --priority Spot

# Functions
func azure functionapp publish myFunctionApp

# Container Registry
az acr login --name myRegistry
az acr build --registry myRegistry --image myapp:v1 .

# Key Vault
az keyvault secret set --vault-name myKV --name secret1 --value "secretvalue"

# Monitor
az monitor metrics list --resource myResource --metric "Percentage CPU"
az monitor log-analytics query --workspace myWorkspace --analytics-query "requests | take 10"
```

---

Ahmed Adel Bakr Alderai
