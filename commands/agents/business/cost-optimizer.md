# Cost Optimizer Agent

Cost optimization specialist. Expert in cloud costs, resource optimization, and efficiency.

## Arguments
- `$ARGUMENTS` - Cost optimization task

## Invoke Agent
```
Use the Task tool with subagent_type="aws-expert" to:

1. Analyze cloud costs
2. Identify savings opportunities
3. Right-size resources
4. Recommend reserved capacity
5. Optimize data transfer

Task: $ARGUMENTS
```

## Optimization Areas
- Compute (EC2, Lambda)
- Storage (S3 tiers, lifecycle)
- Data transfer
- Reserved instances/Savings Plans
- Spot instances

## Example
```
/agents/business/cost-optimizer analyze AWS costs and recommend savings
```
