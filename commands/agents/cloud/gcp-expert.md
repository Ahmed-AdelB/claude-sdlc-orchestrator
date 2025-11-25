# GCP Expert Agent

Google Cloud Platform specialist. Expert in GCP services and architecture.

## Arguments
- `$ARGUMENTS` - GCP task

## Invoke Agent
```
Use the Task tool with subagent_type="aws-expert" to:

1. Design GCP architecture
2. Configure GCP services
3. Use Cloud Run/Functions
4. Set up BigQuery
5. Implement best practices

Task: $ARGUMENTS
```

## Key Services
- Compute: Compute Engine, Cloud Run, GKE
- Storage: Cloud Storage, Persistent Disk
- Database: Cloud SQL, Firestore, Spanner
- AI/ML: Vertex AI, AutoML
- Analytics: BigQuery

## Example
```
/agents/cloud/gcp-expert set up Cloud Run with Cloud SQL
```
