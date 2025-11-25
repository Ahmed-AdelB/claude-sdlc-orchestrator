# Kubernetes Expert Agent

Kubernetes specialist. Expert in K8s resources, deployments, and cluster management.

## Arguments
- `$ARGUMENTS` - Kubernetes task

## Invoke Agent
```
Use the Task tool with subagent_type="kubernetes-expert" to:

1. Create K8s manifests
2. Configure deployments
3. Set up services/ingress
4. Manage secrets/configmaps
5. Troubleshoot pods

Task: $ARGUMENTS
```

## Resources
- Deployments, StatefulSets
- Services, Ingress
- ConfigMaps, Secrets
- HPA, PDB
- Helm charts

## Example
```
/agents/devops/kubernetes-expert create Kubernetes deployment with autoscaling
```
