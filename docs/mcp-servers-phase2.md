# MCP Servers Phase 2: AWS, Vault, Docker, Kubernetes

This document covers installation, configuration, and usage patterns for four MCP servers:
- mcp-server-aws (EC2, S3, Lambda)
- mcp-server-vault (HashiCorp Vault)
- mcp-server-docker (container management)
- mcp-server-kubernetes (k8s operations)

The examples assume a Claude-style MCP config in JSON format (adjust the path to match your client). Use environment variables for credentials whenever possible.

---

## 1) mcp-server-aws (EC2, S3, Lambda)

### Install
```bash
npm install -g mcp-server-aws
```

### Configure
Example MCP config snippet:
```json
{
  "mcpServers": {
    "aws": {
      "command": "mcp-server-aws",
      "args": [],
      "env": {
        "AWS_PROFILE": "default",
        "AWS_REGION": "us-east-1"
      }
    }
  }
}
```

Alternate auth via env vars:
```json
{
  "env": {
    "AWS_ACCESS_KEY_ID": "<key>",
    "AWS_SECRET_ACCESS_KEY": "<secret>",
    "AWS_REGION": "us-east-1"
  }
}
```

### Usage patterns
- List EC2 instances:
  - "List EC2 instances in us-east-1, include id, name tag, state, and instance type."
- Fetch S3 objects:
  - "Show the 20 most recent objects in s3://my-bucket/logs/."
- Invoke Lambda:
  - "Invoke Lambda my-function with payload {\"dryRun\":true} and return the response."
- Describe resources by tag:
  - "Find EC2 instances tagged Env=prod and report public IPs."

---

## 2) mcp-server-vault (HashiCorp Vault)

### Install
```bash
npm install -g mcp-server-vault
```

### Configure
Example MCP config snippet:
```json
{
  "mcpServers": {
    "vault": {
      "command": "mcp-server-vault",
      "args": [],
      "env": {
        "VAULT_ADDR": "https://vault.example.com:8200",
        "VAULT_TOKEN": "<token>",
        "VAULT_NAMESPACE": "admin"
      }
    }
  }
}
```

Optional auth via Vault CLI login (token read from env or token helper):
```bash
export VAULT_ADDR=https://vault.example.com:8200
vault login
```

### Usage patterns
- Read a secret:
  - "Read secret at kv/data/app/config and return the data fields."
- Write a secret:
  - "Write username and password to kv/data/app/config."
- List secrets:
  - "List keys under kv/metadata/app/."
- Rotate a token (if allowed by policy):
  - "Create a periodic token with 24h period for app access."

---

## 3) mcp-server-docker (container management)

### Install
```bash
npm install -g mcp-server-docker
```

### Configure
Example MCP config snippet:
```json
{
  "mcpServers": {
    "docker": {
      "command": "mcp-server-docker",
      "args": [],
      "env": {
        "DOCKER_HOST": "unix:///var/run/docker.sock"
      }
    }
  }
}
```

If using Docker Desktop with TCP:
```json
{
  "env": {
    "DOCKER_HOST": "tcp://127.0.0.1:2375"
  }
}
```

### Usage patterns
- List running containers:
  - "List running containers with name, image, status, and ports."
- Inspect a container:
  - "Inspect container api-service and summarize mounts and env vars."
- Fetch logs:
  - "Show last 200 lines of logs for container web."
- Manage images:
  - "List images and identify those unused in the last 30 days."

---

## 4) mcp-server-kubernetes (k8s operations)

### Install
```bash
npm install -g mcp-server-kubernetes
```

### Configure
Example MCP config snippet:
```json
{
  "mcpServers": {
    "kubernetes": {
      "command": "mcp-server-kubernetes",
      "args": [],
      "env": {
        "KUBECONFIG": "/home/aadel/.kube/config",
        "KUBE_CONTEXT": "prod-cluster"
      }
    }
  }
}
```

If KUBECONFIG is default:
```json
{
  "env": {
    "KUBECONFIG": "~/.kube/config"
  }
}
```

### Usage patterns
- List pods:
  - "List pods in namespace payments with status and restarts."
- Describe a deployment:
  - "Describe deployment api in namespace default."
- Stream logs:
  - "Stream logs for pod api-5f6d7 in namespace default."
- Scale a deployment:
  - "Scale deployment worker to 5 replicas in namespace jobs."

---

## Notes and tips
- Prefer scoped credentials and least-privilege policies for AWS and Vault.
- For Docker and Kubernetes, ensure the local user has permission to access the Docker socket or kubeconfig.
- Store secrets in env vars or secret managers; avoid committing them to config files.
