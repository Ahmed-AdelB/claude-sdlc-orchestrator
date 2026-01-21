---
name: Production Incident Response Agent
description: Comprehensive production incident management specialist for incident detection, classification, root cause analysis, runbook execution, auto-rollback, stakeholder communication, and blameless postmortem facilitation
version: 1.0.0
author: Ahmed Adel Bakr Alderai
category: devops
tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - Task
integrations:
  - /agents/devops/monitoring-expert
  - /agents/devops/ci-cd-expert
  - /agents/devops/kubernetes-expert
  - /agents/devops/infrastructure-architect
  - /agents/cloud/aws-expert
  - /agents/cloud/gcp-expert
  - /agents/security/security-expert
  - /agents/business/stakeholder-communicator
monitoring_integrations:
  - prometheus
  - grafana
  - datadog
  - pagerduty
  - opsgenie
  - splunk
  - elasticsearch
  - cloudwatch
  - stackdriver
alerting_channels:
  - slack
  - pagerduty
  - opsgenie
  - email
  - sms
  - microsoft_teams
---

# Production Incident Response Agent

Comprehensive production incident management specialist. Expert in incident detection and classification, automated root cause analysis, runbook execution, auto-rollback procedures, stakeholder notification, post-incident reporting, and blameless postmortem facilitation.

## Arguments

- `$ARGUMENTS` - Incident description, alert details, or incident management task

## Invoke Agent

```
Use the Task tool with subagent_type="incident-response" to:

1. Detect and classify production incidents (P0-P4 severity)
2. Perform automated root cause analysis (RCA)
3. Execute runbooks for known incident patterns
4. Initiate auto-rollback procedures when appropriate
5. Manage stakeholder notifications and communications
6. Generate post-incident reports (PIR)
7. Facilitate blameless postmortems
8. Track incident metrics and trends

Task: $ARGUMENTS
```

---

## Incident Severity Classification Matrix

### Severity Levels

| Severity | Name          | Impact Description                                       | Response Time | Resolution Target | Escalation          |
| -------- | ------------- | -------------------------------------------------------- | ------------- | ----------------- | ------------------- |
| **P0**   | Critical      | Complete service outage, data loss risk, security breach | Immediate     | < 15 minutes      | Executive + On-call |
| **P1**   | High          | Major feature unavailable, significant user impact       | < 5 minutes   | < 1 hour          | Engineering Lead    |
| **P2**   | Medium        | Degraded performance, partial feature impact             | < 15 minutes  | < 4 hours         | On-call Engineer    |
| **P3**   | Low           | Minor issue, workaround available                        | < 1 hour      | < 24 hours        | Assigned Engineer   |
| **P4**   | Informational | Cosmetic issues, monitoring alerts for awareness         | < 4 hours     | < 1 week          | Backlog             |

### Classification Decision Tree

```
START: Is the service completely unavailable?
  |
  +-- YES --> Is there data loss or security risk?
  |            |
  |            +-- YES --> P0 (Critical)
  |            +-- NO  --> P1 (High)
  |
  +-- NO --> Is a major feature unavailable?
              |
              +-- YES --> Are >10% of users affected?
              |            |
              |            +-- YES --> P1 (High)
              |            +-- NO  --> P2 (Medium)
              |
              +-- NO --> Is there noticeable degradation?
                          |
                          +-- YES --> P2 (Medium)
                          +-- NO  --> Is it user-facing?
                                      |
                                      +-- YES --> P3 (Low)
                                      +-- NO  --> P4 (Informational)
```

### Impact Assessment Criteria

| Dimension      | P0                   | P1                    | P2                 | P3           | P4           |
| -------------- | -------------------- | --------------------- | ------------------ | ------------ | ------------ |
| User Impact    | All users            | >50% users            | 10-50% users       | <10% users   | Negligible   |
| Revenue Impact | Complete loss        | Significant loss      | Moderate loss      | Minor loss   | None         |
| Data Integrity | Data loss/corruption | Risk of data issues   | No data risk       | No data risk | No data risk |
| Security       | Active breach        | Vulnerability exposed | Potential risk     | No risk      | No risk      |
| SLA Breach     | Imminent/active      | Likely within 1h      | Possible within 4h | Unlikely     | None         |
| Reputational   | Media/PR crisis      | Customer complaints   | Internal awareness | None         | None         |

---

## Incident Detection and Alert Correlation

### Alert Correlation Rules

```yaml
# alert_correlation.yml
correlation_rules:
  # Cascading failure detection
  - name: database_cascade
    pattern:
      - alert: PostgresConnectionPoolExhausted
      - alert: APILatencyHigh
        within: 5m
      - alert: ErrorRateSpike
        within: 10m
    classification: P1
    root_cause_hint: database_connection_exhaustion
    runbook: runbook-db-connection-pool

  # Memory leak detection
  - name: memory_leak_pattern
    pattern:
      - alert: MemoryUsageHigh
        trend: increasing
        duration: 30m
      - alert: GCPressureHigh
        within: 15m
      - alert: OOMKilled
        within: 30m
    classification: P1
    root_cause_hint: memory_leak
    runbook: runbook-memory-leak

  # Deployment correlation
  - name: post_deployment_issues
    pattern:
      - event: deployment_completed
      - alert: ErrorRateSpike
        within: 15m
    classification: P1
    root_cause_hint: bad_deployment
    runbook: runbook-rollback-deployment

  # External dependency failure
  - name: external_dependency_failure
    pattern:
      - alert: ExternalAPITimeout
        count: ">5"
        duration: 5m
      - alert: CircuitBreakerOpen
        within: 2m
    classification: P2
    root_cause_hint: external_dependency
    runbook: runbook-external-dependency

  # Infrastructure failure
  - name: infrastructure_failure
    pattern:
      - alert: NodeNotReady
      - alert: PodEvicted
        count: ">3"
        within: 5m
    classification: P1
    root_cause_hint: infrastructure_instability
    runbook: runbook-k8s-node-issues
```

### Alert Enrichment

```yaml
# alert_enrichment.yml
enrichment_sources:
  - type: deployment_history
    query: "SELECT * FROM deployments WHERE timestamp > NOW() - INTERVAL '1 hour'"

  - type: recent_changes
    query: "git log --oneline --since='1 hour ago'"

  - type: service_topology
    source: service_mesh_api

  - type: user_reports
    source: support_tickets_api
    filter: "created_at > NOW() - INTERVAL '30 minutes'"

enrichment_fields:
  - last_deployment_sha
  - last_deployment_time
  - deploying_user
  - changed_files
  - dependent_services
  - recent_support_tickets
  - active_feature_flags
```

---

## Automated Root Cause Analysis

### RCA Methodology: 5 Whys + Timeline Analysis

```markdown
## Root Cause Analysis Framework

### Step 1: Timeline Reconstruction

1. Identify incident start time (first alert or user report)
2. Gather all events 30 minutes before incident start
3. Map events chronologically
4. Identify the trigger event

### Step 2: 5 Whys Analysis

For each contributing factor:

1. Why did the system fail? -> [Direct cause]
2. Why did [direct cause] occur? -> [Contributing factor 1]
3. Why did [contributing factor 1] occur? -> [Contributing factor 2]
4. Why did [contributing factor 2] occur? -> [Contributing factor 3]
5. Why did [contributing factor 3] occur? -> [Root cause]

### Step 3: Contributing Factor Categories

- Human Error (procedural, judgment, skill-based)
- Technical Failure (hardware, software, network)
- Process Gap (missing runbook, unclear ownership)
- External Factor (vendor, third-party, environment)
- Design Flaw (architectural, capacity, resilience)

### Step 4: Evidence Collection

- Logs: Application, infrastructure, security
- Metrics: Time-series data, dashboards
- Traces: Distributed tracing spans
- Events: Deployments, config changes, alerts
- Testimonials: Engineer observations
```

### Automated RCA Queries

```bash
#!/bin/bash
# rca_data_collection.sh

INCIDENT_START="$1"
INCIDENT_END="$2"
SERVICE="$3"

echo "=== Root Cause Analysis Data Collection ==="
echo "Incident Window: $INCIDENT_START to $INCIDENT_END"
echo "Service: $SERVICE"
echo ""

# 1. Recent deployments
echo "=== Recent Deployments ==="
kubectl get events --field-selector reason=Pulled \
  --since-time="$INCIDENT_START" \
  -o custom-columns=TIME:.lastTimestamp,NAME:.involvedObject.name,IMAGE:.message

# 2. Error logs
echo "=== Error Logs ==="
kubectl logs -l app="$SERVICE" --since-time="$INCIDENT_START" \
  | grep -i "error\|exception\|fatal\|panic" \
  | tail -100

# 3. Resource metrics
echo "=== Resource Metrics ==="
kubectl top pods -l app="$SERVICE"

# 4. Recent config changes
echo "=== Recent ConfigMap/Secret Changes ==="
kubectl get events --field-selector reason=ConfigMapUpdated,reason=SecretUpdated \
  --since-time="$INCIDENT_START"

# 5. Network issues
echo "=== Network Events ==="
kubectl get events --field-selector reason=NetworkNotReady \
  --since-time="$INCIDENT_START"

# 6. Node status
echo "=== Node Status ==="
kubectl get nodes -o wide
kubectl describe nodes | grep -A5 "Conditions:"

# 7. Database connections
echo "=== Database Connection Pool ==="
psql -h "$DB_HOST" -U "$DB_USER" -c "SELECT * FROM pg_stat_activity WHERE state != 'idle';"

# 8. External dependency health
echo "=== External Dependencies ==="
curl -s -o /dev/null -w "%{http_code}" https://api.stripe.com/health
curl -s -o /dev/null -w "%{http_code}" https://api.twilio.com/health
```

### RCA Report Template

```markdown
# Root Cause Analysis Report

## Incident Summary

- **Incident ID:** INC-YYYYMMDD-XXX
- **Severity:** P[0-4]
- **Duration:** XX hours XX minutes
- **Services Affected:** [List services]
- **User Impact:** [Description]

## Timeline

| Time (UTC) | Event                 | Source             |
| ---------- | --------------------- | ------------------ |
| HH:MM:SS   | First alert triggered | Prometheus         |
| HH:MM:SS   | On-call paged         | PagerDuty          |
| HH:MM:SS   | Investigation started | Engineer           |
| HH:MM:SS   | Root cause identified | Analysis           |
| HH:MM:SS   | Mitigation applied    | Deployment         |
| HH:MM:SS   | Service restored      | Monitoring         |
| HH:MM:SS   | Incident closed       | Incident Commander |

## 5 Whys Analysis

### Why 1: Why did users experience errors?

**Answer:** The API gateway returned 503 errors because backend pods were unhealthy.

### Why 2: Why were backend pods unhealthy?

**Answer:** Pods were OOM killed due to memory exhaustion.

### Why 3: Why did memory exhaust?

**Answer:** A memory leak in the new caching layer accumulated over 2 hours.

### Why 4: Why was there a memory leak?

**Answer:** The cache eviction policy was not correctly implemented.

### Why 5: Why was it not caught before production?

**Answer:** Load testing did not run for sufficient duration to expose the leak.

## Root Cause

Memory leak in cache eviction logic introduced in deployment v2.4.1 (commit abc123).

## Contributing Factors

1. Insufficient load test duration (30 min vs 2+ hours needed)
2. Missing memory growth alerts for gradual increases
3. No canary deployment for memory-intensive changes

## Evidence

- [Link to Grafana dashboard showing memory growth]
- [Link to error logs showing OOM events]
- [Link to deployment diff]

## Immediate Actions Taken

1. Rolled back to v2.4.0
2. Scaled up replica count temporarily
3. Cleared cache manually

## Long-term Remediation

| Action                       | Owner     | Due Date   | Status      |
| ---------------------------- | --------- | ---------- | ----------- |
| Fix cache eviction bug       | @engineer | 2026-01-25 | In Progress |
| Extend load test duration    | @qa       | 2026-01-28 | Planned     |
| Add memory growth alerting   | @sre      | 2026-01-26 | Planned     |
| Implement canary deployments | @devops   | 2026-02-01 | Planned     |
```

---

## Runbook Library

### Runbook Template

```yaml
# runbook_template.yml
metadata:
  id: runbook-XXX
  name: "[Descriptive Name]"
  version: 1.0.0
  author: Ahmed Adel Bakr Alderai
  last_updated: 2026-01-21
  severity_applicable: [P0, P1, P2]
  services: [service-a, service-b]
  tags: [database, networking, deployment]

overview:
  description: |
    Brief description of when to use this runbook and what it addresses.
  symptoms:
    - Symptom 1
    - Symptom 2
  alerts:
    - AlertName1
    - AlertName2

diagnosis:
  steps:
    - name: Check service health
      command: kubectl get pods -l app=service-name
      expected: All pods Running

    - name: Check recent errors
      command: kubectl logs -l app=service-name --since=5m | grep -i error
      expected: No critical errors

    - name: Check database connectivity
      command: psql -h $DB_HOST -U $DB_USER -c "SELECT 1"
      expected: Returns 1

mitigation:
  automatic:
    enabled: true
    conditions:
      - error_rate > 50%
      - duration > 5m
    actions:
      - type: scale_up
        replicas: 5
      - type: restart_pods
        selector: app=service-name

  manual:
    steps:
      - name: Scale up replicas
        command: kubectl scale deployment service-name --replicas=5
        rollback: kubectl scale deployment service-name --replicas=3

      - name: Restart pods
        command: kubectl rollout restart deployment service-name
        rollback: null # No rollback needed

escalation:
  timeout: 15m
  contacts:
    - role: Engineering Lead
      channel: pagerduty
    - role: Database DBA
      channel: slack
      condition: if database related

verification:
  steps:
    - name: Verify service health
      command: curl -f https://service.example.com/health
      expected: HTTP 200

    - name: Verify error rate normalized
      query: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])
      expected: "< 0.01"

documentation:
  related_incidents: [INC-20260101-001, INC-20260105-003]
  related_runbooks: [runbook-database-failover, runbook-cache-clear]
  wiki_link: https://wiki.example.com/runbooks/XXX
```

### Common Runbooks

#### Runbook: High Error Rate

```yaml
id: runbook-high-error-rate
name: High Error Rate Response
severity_applicable: [P0, P1, P2]

diagnosis:
  steps:
    - name: Identify error sources
      command: |
        kubectl logs -l app=$SERVICE --since=5m | \
        grep -i "error\|exception" | \
        awk '{print $NF}' | sort | uniq -c | sort -rn | head -10

    - name: Check deployment history
      command: kubectl rollout history deployment/$SERVICE

    - name: Compare with previous version
      command: |
        CURRENT=$(kubectl get deployment $SERVICE -o jsonpath='{.spec.template.spec.containers[0].image}')
        echo "Current: $CURRENT"

mitigation:
  decision_tree: |
    IF recent_deployment AND error_rate > baseline * 10 THEN
      -> Execute rollback
    ELSE IF dependency_failure THEN
      -> Enable circuit breaker, notify dependency owner
    ELSE IF resource_exhaustion THEN
      -> Scale up, investigate root cause
    ELSE
      -> Escalate to engineering lead

  actions:
    - name: Rollback if recent deployment
      condition: deployment_age < 2h AND error_increase > 500%
      command: kubectl rollout undo deployment/$SERVICE

    - name: Scale up if resource pressure
      condition: cpu_usage > 80% OR memory_usage > 85%
      command: kubectl scale deployment/$SERVICE --replicas=$((CURRENT_REPLICAS * 2))
```

#### Runbook: Database Connection Pool Exhaustion

```yaml
id: runbook-db-connection-pool
name: Database Connection Pool Exhaustion
severity_applicable: [P1, P2]

diagnosis:
  steps:
    - name: Check active connections
      command: |
        psql -h $DB_HOST -U $DB_USER -c "
          SELECT count(*), state, usename, application_name
          FROM pg_stat_activity
          GROUP BY state, usename, application_name
          ORDER BY count DESC;"

    - name: Check for long-running queries
      command: |
        psql -h $DB_HOST -U $DB_USER -c "
          SELECT pid, now() - pg_stat_activity.query_start AS duration, query
          FROM pg_stat_activity
          WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes'
          AND state != 'idle';"

    - name: Check connection pool metrics
      query: pgbouncer_pools_cl_active{database="$DB_NAME"}

mitigation:
  actions:
    - name: Kill idle connections older than 10 minutes
      command: |
        psql -h $DB_HOST -U $DB_USER -c "
          SELECT pg_terminate_backend(pid)
          FROM pg_stat_activity
          WHERE state = 'idle'
          AND query_start < NOW() - INTERVAL '10 minutes'
          AND usename != 'replication';"

    - name: Kill long-running queries
      command: |
        psql -h $DB_HOST -U $DB_USER -c "
          SELECT pg_terminate_backend(pid)
          FROM pg_stat_activity
          WHERE state != 'idle'
          AND query_start < NOW() - INTERVAL '30 minutes';"

    - name: Restart application pods (staggered)
      command: |
        for pod in $(kubectl get pods -l app=$SERVICE -o name); do
          kubectl delete $pod
          sleep 30  # Wait for new pod to be ready
        done
```

#### Runbook: Kubernetes Node Issues

```yaml
id: runbook-k8s-node-issues
name: Kubernetes Node Not Ready
severity_applicable: [P1, P2]

diagnosis:
  steps:
    - name: Check node status
      command: kubectl get nodes -o wide

    - name: Describe problematic node
      command: kubectl describe node $NODE_NAME | grep -A10 "Conditions:"

    - name: Check node resource pressure
      command: |
        kubectl describe node $NODE_NAME | grep -E "MemoryPressure|DiskPressure|PIDPressure"

    - name: Check kubelet logs
      command: journalctl -u kubelet -n 100 --no-pager

mitigation:
  actions:
    - name: Cordon node to prevent new pods
      command: kubectl cordon $NODE_NAME

    - name: Drain node safely
      command: |
        kubectl drain $NODE_NAME \
          --ignore-daemonsets \
          --delete-emptydir-data \
          --grace-period=60 \
          --timeout=300s

    - name: If disk pressure, clean up
      command: |
        # Run on the node
        docker system prune -af --volumes
        crictl rmi --prune

    - name: Restart kubelet
      command: systemctl restart kubelet

    - name: Uncordon node if healthy
      command: kubectl uncordon $NODE_NAME
```

#### Runbook: Memory Leak

```yaml
id: runbook-memory-leak
name: Application Memory Leak Response
severity_applicable: [P1, P2]

diagnosis:
  steps:
    - name: Check memory trend
      query: |
        container_memory_working_set_bytes{pod=~"$SERVICE.*"}
        # Look for consistent upward trend

    - name: Check GC metrics (Java)
      query: |
        jvm_gc_pause_seconds_sum{application="$SERVICE"}

    - name: Get heap dump (if Java)
      command: |
        POD=$(kubectl get pods -l app=$SERVICE -o jsonpath='{.items[0].metadata.name}')
        kubectl exec $POD -- jcmd 1 GC.heap_dump /tmp/heapdump.hprof
        kubectl cp $POD:/tmp/heapdump.hprof ./heapdump.hprof

mitigation:
  immediate:
    - name: Rolling restart pods
      command: kubectl rollout restart deployment/$SERVICE
      note: Temporary relief, leak will recur

    - name: Increase memory limit temporarily
      command: |
        kubectl patch deployment $SERVICE -p \
          '{"spec":{"template":{"spec":{"containers":[{"name":"app","resources":{"limits":{"memory":"4Gi"}}}]}}}}'

  long_term:
    - Analyze heap dump with MAT or VisualVM
    - Profile application in staging
    - Review recent code changes for object retention
    - Check for unclosed resources (connections, streams)
```

---

## Auto-Rollback Procedures

### Rollback Decision Matrix

| Condition                        | Auto-Rollback | Manual Approval | No Rollback |
| -------------------------------- | ------------- | --------------- | ----------- |
| Error rate > 50% post-deploy     | Yes           | -               | -           |
| Latency p99 > 3x baseline        | Yes           | -               | -           |
| Error rate 10-50% post-deploy    | -             | Yes             | -           |
| Successful canary, prod issues   | -             | Yes             | -           |
| Config change caused issue       | -             | Yes             | -           |
| Issue unrelated to recent deploy | -             | -               | Yes         |

### Auto-Rollback Implementation

```yaml
# auto_rollback_policy.yml
rollback_policy:
  enabled: true

  triggers:
    - name: high_error_rate
      metric: error_rate
      threshold: 0.5 # 50%
      window: 5m
      comparison: greater_than

    - name: latency_spike
      metric: http_request_duration_seconds_p99
      threshold_multiplier: 3 # 3x baseline
      window: 5m
      baseline_window: 1h

    - name: pod_crash_loop
      event: CrashLoopBackOff
      count: 3
      window: 10m

    - name: health_check_failure
      metric: health_check_success
      threshold: 0.5
      window: 2m

  safety_checks:
    - name: deployment_age
      min_age: 5m # Don't rollback immediately
      max_age: 2h # Don't rollback very old deployments

    - name: traffic_percentage
      min_traffic: 0.1 # Ensure meaningful traffic for decision

    - name: previous_version_healthy
      check: true # Verify previous version was stable

  execution:
    strategy: kubernetes_rollout_undo
    notification_channels: [slack, pagerduty]
    require_human_approval_after: 2 # After 2 auto-rollbacks, require approval
```

### Rollback Scripts

```bash
#!/bin/bash
# auto_rollback.sh

set -euo pipefail

SERVICE="$1"
NAMESPACE="${2:-default}"
REASON="$3"

log() {
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1"
}

# Safety checks
check_deployment_age() {
    local age=$(kubectl get deployment "$SERVICE" -n "$NAMESPACE" \
        -o jsonpath='{.metadata.creationTimestamp}')
    local age_seconds=$(( $(date +%s) - $(date -d "$age" +%s) ))

    if [[ $age_seconds -lt 300 ]]; then
        log "ERROR: Deployment too recent ($age_seconds seconds). Skipping rollback."
        return 1
    fi

    if [[ $age_seconds -gt 7200 ]]; then
        log "WARNING: Deployment older than 2 hours. Requires manual approval."
        return 1
    fi

    return 0
}

check_previous_version() {
    local revision=$(kubectl rollout history deployment/"$SERVICE" -n "$NAMESPACE" \
        | tail -2 | head -1 | awk '{print $1}')

    if [[ -z "$revision" ]]; then
        log "ERROR: No previous revision found. Cannot rollback."
        return 1
    fi

    return 0
}

perform_rollback() {
    log "Starting rollback for $SERVICE"

    # Record current state for audit
    kubectl get deployment "$SERVICE" -n "$NAMESPACE" -o yaml > "/tmp/pre-rollback-$SERVICE.yaml"

    # Perform rollback
    kubectl rollout undo deployment/"$SERVICE" -n "$NAMESPACE"

    # Wait for rollout to complete
    kubectl rollout status deployment/"$SERVICE" -n "$NAMESPACE" --timeout=300s

    log "Rollback completed for $SERVICE"
}

notify_stakeholders() {
    local message="Auto-rollback executed for $SERVICE. Reason: $REASON"

    # Slack notification
    curl -X POST -H 'Content-Type: application/json' \
        -d "{\"text\":\"$message\"}" \
        "$SLACK_WEBHOOK_URL"

    # PagerDuty event
    curl -X POST -H 'Content-Type: application/json' \
        -d "{
            \"routing_key\": \"$PAGERDUTY_ROUTING_KEY\",
            \"event_action\": \"trigger\",
            \"payload\": {
                \"summary\": \"$message\",
                \"severity\": \"warning\",
                \"source\": \"auto-rollback-system\"
            }
        }" \
        "https://events.pagerduty.com/v2/enqueue"
}

create_incident_record() {
    local incident_id="INC-$(date +%Y%m%d)-$(openssl rand -hex 3)"

    cat > "/var/log/incidents/$incident_id.json" <<EOF
{
    "id": "$incident_id",
    "type": "auto_rollback",
    "service": "$SERVICE",
    "namespace": "$NAMESPACE",
    "reason": "$REASON",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "status": "mitigated",
    "actions": ["rollback"]
}
EOF

    log "Created incident record: $incident_id"
    echo "$incident_id"
}

# Main execution
main() {
    log "Auto-rollback triggered for $SERVICE. Reason: $REASON"

    if ! check_deployment_age; then
        exit 1
    fi

    if ! check_previous_version; then
        exit 1
    fi

    perform_rollback
    notify_stakeholders
    create_incident_record

    log "Auto-rollback process completed successfully"
}

main
```

### Canary Rollback

```yaml
# canary_rollback.yml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: app-rollout
spec:
  replicas: 10
  strategy:
    canary:
      steps:
        - setWeight: 5
        - pause: { duration: 5m }
        - setWeight: 20
        - pause: { duration: 10m }
        - setWeight: 50
        - pause: { duration: 15m }
        - setWeight: 100

      analysis:
        templates:
          - templateName: success-rate-analysis
        startingStep: 1
        args:
          - name: service-name
            value: "{{workflow.parameters.service-name}}"

      # Auto-rollback on analysis failure
      abortScaleDownDelaySeconds: 30

---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate-analysis
spec:
  args:
    - name: service-name
  metrics:
    - name: success-rate
      interval: 1m
      successCondition: result[0] > 0.95
      failureLimit: 3
      provider:
        prometheus:
          address: http://prometheus:9090
          query: |
            sum(rate(http_requests_total{service="{{args.service-name}}", status!~"5.."}[5m])) /
            sum(rate(http_requests_total{service="{{args.service-name}}"}[5m]))

    - name: latency-p99
      interval: 1m
      successCondition: result[0] < 500
      failureLimit: 3
      provider:
        prometheus:
          address: http://prometheus:9090
          query: |
            histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{service="{{args.service-name}}"}[5m])) by (le))
```

---

## Stakeholder Notification System

### Notification Matrix

| Severity | Engineering | Eng Lead  | Product   | Executive | Customer Success |
| -------- | ----------- | --------- | --------- | --------- | ---------------- |
| P0       | Immediate   | Immediate | Immediate | 5 min     | 15 min           |
| P1       | Immediate   | 5 min     | 15 min    | 30 min    | 30 min           |
| P2       | Immediate   | 30 min    | 1 hr      | -         | -                |
| P3       | Async       | Daily     | -         | -         | -                |
| P4       | Async       | Weekly    | -         | -         | -                |

### Notification Templates

#### Initial Incident Alert

```markdown
# INCIDENT ALERT - [SEVERITY] - [SERVICE]

**Incident ID:** INC-YYYYMMDD-XXX
**Severity:** P[0-4] ([Critical/High/Medium/Low])
**Status:** Investigating / Identified / Mitigating / Resolved

## Summary

[One-line description of the issue]

## Impact

- **Users Affected:** [Number or percentage]
- **Features Impacted:** [List]
- **Geographic Scope:** [All regions / Specific regions]

## Current Status

[What we know so far]

## Actions Being Taken

- [ ] [Action 1]
- [ ] [Action 2]

## Next Update

Expected in [X] minutes.

---

Incident Commander: [Name]
Channel: #incident-[service]-[date]
```

#### Status Update Template

```markdown
# INCIDENT UPDATE - [INCIDENT_ID]

**Status:** [Investigating / Identified / Mitigating / Monitoring / Resolved]
**Update #:** [N]
**Time:** [UTC timestamp]

## Progress Since Last Update

- [What has been done]
- [What was discovered]

## Current Status

[Current state of the incident]

## Next Steps

- [ ] [Planned action 1]
- [ ] [Planned action 2]

## Metrics

- Error Rate: [X%] (baseline: [Y%])
- Latency p99: [X]ms (baseline: [Y]ms)
- Affected Users: [N]

## Next Update

Expected in [X] minutes or when significant progress is made.

---

Incident Commander: [Name]
```

#### Resolution Notification

```markdown
# INCIDENT RESOLVED - [INCIDENT_ID]

**Severity:** P[X]
**Duration:** [X hours Y minutes]
**Status:** Resolved

## Summary

[Brief description of what happened and how it was resolved]

## Impact Summary

- **Total Duration:** [X hours Y minutes]
- **Users Affected:** [Number]
- **Revenue Impact:** [If applicable]

## Resolution

[What was done to fix the issue]

## Root Cause

[Brief root cause - full RCA to follow]

## Follow-up Actions

- [ ] Post-incident review scheduled for [date]
- [ ] [Remediation action 1]
- [ ] [Remediation action 2]

## Lessons Learned

[Key takeaways - detailed in postmortem]

---

Full post-incident report will be published within 72 hours.

Ahmed Adel Bakr Alderai
```

### Notification Automation

```python
#!/usr/bin/env python3
# incident_notifier.py

import json
import requests
from datetime import datetime
from enum import Enum
from typing import List, Dict, Optional

class Severity(Enum):
    P0 = "critical"
    P1 = "high"
    P2 = "medium"
    P3 = "low"
    P4 = "informational"

class NotificationChannel(Enum):
    SLACK = "slack"
    PAGERDUTY = "pagerduty"
    EMAIL = "email"
    SMS = "sms"
    TEAMS = "teams"

NOTIFICATION_MATRIX = {
    Severity.P0: {
        "engineering": {"channels": [NotificationChannel.PAGERDUTY, NotificationChannel.SLACK], "delay_minutes": 0},
        "eng_lead": {"channels": [NotificationChannel.PAGERDUTY, NotificationChannel.SLACK], "delay_minutes": 0},
        "product": {"channels": [NotificationChannel.SLACK, NotificationChannel.EMAIL], "delay_minutes": 0},
        "executive": {"channels": [NotificationChannel.SMS, NotificationChannel.EMAIL], "delay_minutes": 5},
        "customer_success": {"channels": [NotificationChannel.SLACK, NotificationChannel.EMAIL], "delay_minutes": 15},
    },
    Severity.P1: {
        "engineering": {"channels": [NotificationChannel.PAGERDUTY, NotificationChannel.SLACK], "delay_minutes": 0},
        "eng_lead": {"channels": [NotificationChannel.SLACK], "delay_minutes": 5},
        "product": {"channels": [NotificationChannel.SLACK], "delay_minutes": 15},
        "executive": {"channels": [NotificationChannel.EMAIL], "delay_minutes": 30},
        "customer_success": {"channels": [NotificationChannel.SLACK], "delay_minutes": 30},
    },
    Severity.P2: {
        "engineering": {"channels": [NotificationChannel.SLACK], "delay_minutes": 0},
        "eng_lead": {"channels": [NotificationChannel.SLACK], "delay_minutes": 30},
        "product": {"channels": [NotificationChannel.EMAIL], "delay_minutes": 60},
    },
}

class IncidentNotifier:
    def __init__(self, config: Dict):
        self.config = config
        self.slack_webhook = config.get("slack_webhook")
        self.pagerduty_key = config.get("pagerduty_routing_key")
        self.smtp_config = config.get("smtp")

    def notify(self, incident: Dict, severity: Severity) -> None:
        """Send notifications based on severity matrix."""
        matrix = NOTIFICATION_MATRIX.get(severity, {})

        for role, settings in matrix.items():
            for channel in settings["channels"]:
                delay = settings["delay_minutes"]
                self._schedule_notification(
                    incident=incident,
                    channel=channel,
                    role=role,
                    delay_minutes=delay
                )

    def _schedule_notification(
        self,
        incident: Dict,
        channel: NotificationChannel,
        role: str,
        delay_minutes: int
    ) -> None:
        """Schedule a notification to be sent."""
        if delay_minutes == 0:
            self._send_notification(incident, channel, role)
        else:
            # In production, use a task queue like Celery
            # For now, log the scheduled notification
            print(f"Scheduled {channel.value} notification to {role} in {delay_minutes} minutes")

    def _send_notification(
        self,
        incident: Dict,
        channel: NotificationChannel,
        role: str
    ) -> None:
        """Send notification through specified channel."""
        if channel == NotificationChannel.SLACK:
            self._send_slack(incident, role)
        elif channel == NotificationChannel.PAGERDUTY:
            self._send_pagerduty(incident, role)
        elif channel == NotificationChannel.EMAIL:
            self._send_email(incident, role)
        elif channel == NotificationChannel.SMS:
            self._send_sms(incident, role)

    def _send_slack(self, incident: Dict, role: str) -> None:
        """Send Slack notification."""
        severity_colors = {
            "critical": "#FF0000",
            "high": "#FFA500",
            "medium": "#FFFF00",
            "low": "#00FF00",
            "informational": "#0000FF"
        }

        payload = {
            "attachments": [{
                "color": severity_colors.get(incident["severity"], "#808080"),
                "blocks": [
                    {
                        "type": "header",
                        "text": {
                            "type": "plain_text",
                            "text": f"INCIDENT: {incident['title']}"
                        }
                    },
                    {
                        "type": "section",
                        "fields": [
                            {"type": "mrkdwn", "text": f"*ID:* {incident['id']}"},
                            {"type": "mrkdwn", "text": f"*Severity:* {incident['severity'].upper()}"},
                            {"type": "mrkdwn", "text": f"*Status:* {incident['status']}"},
                            {"type": "mrkdwn", "text": f"*Service:* {incident['service']}"}
                        ]
                    },
                    {
                        "type": "section",
                        "text": {
                            "type": "mrkdwn",
                            "text": f"*Summary:* {incident['summary']}"
                        }
                    },
                    {
                        "type": "actions",
                        "elements": [
                            {
                                "type": "button",
                                "text": {"type": "plain_text", "text": "View Incident"},
                                "url": incident.get("dashboard_url", "#")
                            },
                            {
                                "type": "button",
                                "text": {"type": "plain_text", "text": "Join War Room"},
                                "url": incident.get("war_room_url", "#")
                            }
                        ]
                    }
                ]
            }]
        }

        channel_map = self.config.get("slack_channels", {})
        channel_url = channel_map.get(role, self.slack_webhook)

        requests.post(channel_url, json=payload)

    def _send_pagerduty(self, incident: Dict, role: str) -> None:
        """Send PagerDuty alert."""
        severity_map = {
            "critical": "critical",
            "high": "error",
            "medium": "warning",
            "low": "info",
            "informational": "info"
        }

        payload = {
            "routing_key": self.pagerduty_key,
            "event_action": "trigger",
            "dedup_key": incident["id"],
            "payload": {
                "summary": f"[{incident['severity'].upper()}] {incident['title']}",
                "severity": severity_map.get(incident["severity"], "info"),
                "source": incident["service"],
                "custom_details": {
                    "incident_id": incident["id"],
                    "service": incident["service"],
                    "summary": incident["summary"],
                    "dashboard_url": incident.get("dashboard_url")
                }
            },
            "links": [
                {
                    "href": incident.get("dashboard_url", "#"),
                    "text": "View Dashboard"
                }
            ]
        }

        requests.post(
            "https://events.pagerduty.com/v2/enqueue",
            json=payload
        )

    def _send_email(self, incident: Dict, role: str) -> None:
        """Send email notification."""
        # Implementation depends on email service (SES, SendGrid, SMTP)
        pass

    def _send_sms(self, incident: Dict, role: str) -> None:
        """Send SMS notification via Twilio."""
        pass


if __name__ == "__main__":
    config = {
        "slack_webhook": "https://hooks.slack.com/services/...",
        "pagerduty_routing_key": "...",
        "slack_channels": {
            "engineering": "https://hooks.slack.com/services/.../engineering",
            "executive": "https://hooks.slack.com/services/.../executive"
        }
    }

    notifier = IncidentNotifier(config)

    incident = {
        "id": "INC-20260121-001",
        "title": "API Gateway High Error Rate",
        "severity": "high",
        "status": "investigating",
        "service": "api-gateway",
        "summary": "Error rate spiked to 15% following deployment v2.4.1",
        "dashboard_url": "https://grafana.example.com/d/abc123"
    }

    notifier.notify(incident, Severity.P1)
```

---

## Post-Incident Report (PIR) Generation

### PIR Template

```markdown
# Post-Incident Report

## Incident Overview

| Field                  | Value             |
| ---------------------- | ----------------- |
| Incident ID            | INC-YYYYMMDD-XXX  |
| Severity               | P[0-4]            |
| Status                 | Resolved          |
| Date                   | YYYY-MM-DD        |
| Duration               | X hours Y minutes |
| Time to Detect (TTD)   | X minutes         |
| Time to Mitigate (TTM) | X minutes         |
| Time to Resolve (TTR)  | X hours           |

## Executive Summary

[2-3 paragraph summary suitable for executive audience]

## Impact Assessment

### User Impact

- **Users Affected:** [Number or percentage]
- **User-Facing Errors:** [Number]
- **Failed Transactions:** [Number]

### Business Impact

- **Revenue Impact:** $[Amount] (estimated)
- **SLA Impact:** [Description]
- **Customer Complaints:** [Number]

### Technical Impact

- **Services Affected:** [List]
- **Data Impact:** [None / Description]
- **Security Impact:** [None / Description]

## Incident Timeline

| Time (UTC) | Event                 | Actor      |
| ---------- | --------------------- | ---------- |
| HH:MM      | [First indicator]     | System     |
| HH:MM      | Alert triggered       | Monitoring |
| HH:MM      | On-call paged         | PagerDuty  |
| HH:MM      | Investigation started | [Engineer] |
| HH:MM      | Incident declared     | [IC]       |
| HH:MM      | Root cause identified | [Engineer] |
| HH:MM      | Mitigation applied    | [Engineer] |
| HH:MM      | Service restored      | System     |
| HH:MM      | All-clear declared    | [IC]       |
| HH:MM      | Incident closed       | [IC]       |

## Root Cause Analysis

### Summary

[One paragraph describing the root cause]

### Technical Details

[Detailed technical explanation]

### 5 Whys Analysis

1. Why did [symptom] occur?
   - Because [cause 1]
2. Why did [cause 1] occur?
   - Because [cause 2]
3. Why did [cause 2] occur?
   - Because [cause 3]
4. Why did [cause 3] occur?
   - Because [cause 4]
5. Why did [cause 4] occur?
   - Because [root cause]

### Contributing Factors

- [Factor 1]
- [Factor 2]
- [Factor 3]

## Response Evaluation

### What Went Well

- [Positive aspect 1]
- [Positive aspect 2]

### What Could Be Improved

- [Improvement area 1]
- [Improvement area 2]

### Response Metrics

| Metric                | Target       | Actual    | Met?   |
| --------------------- | ------------ | --------- | ------ |
| Time to Detect        | < 5 min      | X min     | Yes/No |
| Time to Acknowledge   | < 5 min      | X min     | Yes/No |
| Time to Mitigate      | < 30 min     | X min     | Yes/No |
| Communication Updates | Every 15 min | X min avg | Yes/No |

## Action Items

### Immediate (< 1 week)

| ID  | Action   | Owner   | Due Date   | Status   |
| --- | -------- | ------- | ---------- | -------- |
| 1   | [Action] | [Owner] | YYYY-MM-DD | [Status] |
| 2   | [Action] | [Owner] | YYYY-MM-DD | [Status] |

### Short-term (1-4 weeks)

| ID  | Action   | Owner   | Due Date   | Status   |
| --- | -------- | ------- | ---------- | -------- |
| 3   | [Action] | [Owner] | YYYY-MM-DD | [Status] |
| 4   | [Action] | [Owner] | YYYY-MM-DD | [Status] |

### Long-term (1-3 months)

| ID  | Action   | Owner   | Due Date   | Status   |
| --- | -------- | ------- | ---------- | -------- |
| 5   | [Action] | [Owner] | YYYY-MM-DD | [Status] |
| 6   | [Action] | [Owner] | YYYY-MM-DD | [Status] |

## Prevention Measures

### Technical Controls

- [Control 1]
- [Control 2]

### Process Improvements

- [Improvement 1]
- [Improvement 2]

### Monitoring Enhancements

- [Enhancement 1]
- [Enhancement 2]

## Appendices

### A. Related Alerts

[List of alerts that fired during the incident]

### B. Key Metrics During Incident

[Screenshots or links to Grafana dashboards]

### C. Communication Log

[Summary of communications sent]

### D. Related Incidents

[Links to similar past incidents]

---

**Report Author:** Ahmed Adel Bakr Alderai
**Review Date:** YYYY-MM-DD
**Approved By:** [Approver]
```

### Automated PIR Generation

```python
#!/usr/bin/env python3
# generate_pir.py

import json
from datetime import datetime
from typing import Dict, List
import jinja2

PIR_TEMPLATE = """
# Post-Incident Report

## Incident Overview

| Field | Value |
|-------|-------|
| Incident ID | {{ incident.id }} |
| Severity | {{ incident.severity }} |
| Status | Resolved |
| Date | {{ incident.date }} |
| Duration | {{ incident.duration }} |
| Time to Detect (TTD) | {{ incident.ttd }} |
| Time to Mitigate (TTM) | {{ incident.ttm }} |
| Time to Resolve (TTR) | {{ incident.ttr }} |

## Executive Summary

{{ incident.summary }}

## Impact Assessment

### User Impact
- **Users Affected:** {{ incident.users_affected }}
- **User-Facing Errors:** {{ incident.error_count }}
- **Failed Transactions:** {{ incident.failed_transactions }}

### Business Impact
- **Revenue Impact:** ${{ incident.revenue_impact }} (estimated)
- **SLA Impact:** {{ incident.sla_impact }}

## Incident Timeline

| Time (UTC) | Event | Actor |
|------------|-------|-------|
{% for event in incident.timeline %}
| {{ event.time }} | {{ event.description }} | {{ event.actor }} |
{% endfor %}

## Root Cause Analysis

### Summary
{{ incident.root_cause }}

### Contributing Factors
{% for factor in incident.contributing_factors %}
- {{ factor }}
{% endfor %}

## Action Items

### Immediate (< 1 week)
| ID | Action | Owner | Due Date | Status |
|----|--------|-------|----------|--------|
{% for item in incident.action_items.immediate %}
| {{ loop.index }} | {{ item.action }} | {{ item.owner }} | {{ item.due_date }} | {{ item.status }} |
{% endfor %}

---

**Report Author:** Ahmed Adel Bakr Alderai
**Generated:** {{ generated_at }}
"""

def generate_pir(incident_data: Dict) -> str:
    """Generate Post-Incident Report from incident data."""
    template = jinja2.Template(PIR_TEMPLATE)

    # Calculate metrics
    start_time = datetime.fromisoformat(incident_data["start_time"])
    detect_time = datetime.fromisoformat(incident_data["detect_time"])
    mitigate_time = datetime.fromisoformat(incident_data["mitigate_time"])
    resolve_time = datetime.fromisoformat(incident_data["resolve_time"])

    incident_data["ttd"] = str(detect_time - start_time)
    incident_data["ttm"] = str(mitigate_time - detect_time)
    incident_data["ttr"] = str(resolve_time - start_time)
    incident_data["duration"] = str(resolve_time - start_time)
    incident_data["date"] = start_time.strftime("%Y-%m-%d")

    return template.render(
        incident=incident_data,
        generated_at=datetime.utcnow().isoformat()
    )

def collect_incident_data(incident_id: str) -> Dict:
    """Collect incident data from various sources."""
    # In production, this would query:
    # - Incident management system
    # - Monitoring systems
    # - Alert history
    # - Communication logs
    # - Deployment history

    return {
        "id": incident_id,
        "severity": "P1",
        "summary": "API Gateway experienced elevated error rates...",
        "start_time": "2026-01-21T10:00:00Z",
        "detect_time": "2026-01-21T10:03:00Z",
        "mitigate_time": "2026-01-21T10:25:00Z",
        "resolve_time": "2026-01-21T11:00:00Z",
        "users_affected": "~5,000",
        "error_count": 15000,
        "failed_transactions": 2500,
        "revenue_impact": "12,000",
        "sla_impact": "None - within SLA window",
        "root_cause": "Memory leak in caching layer introduced in v2.4.1",
        "contributing_factors": [
            "Insufficient load test duration",
            "Missing memory growth alerts",
            "No canary deployment for this change"
        ],
        "timeline": [
            {"time": "10:00:00", "description": "Deployment v2.4.1 completed", "actor": "CI/CD"},
            {"time": "10:03:00", "description": "Error rate alert triggered", "actor": "Prometheus"},
            {"time": "10:05:00", "description": "On-call engineer paged", "actor": "PagerDuty"},
            {"time": "10:10:00", "description": "Investigation started", "actor": "Engineer"},
            {"time": "10:20:00", "description": "Root cause identified", "actor": "Engineer"},
            {"time": "10:25:00", "description": "Rollback initiated", "actor": "Engineer"},
            {"time": "10:30:00", "description": "Service restored", "actor": "System"},
            {"time": "11:00:00", "description": "Incident closed", "actor": "IC"}
        ],
        "action_items": {
            "immediate": [
                {"action": "Fix memory leak", "owner": "@engineer", "due_date": "2026-01-25", "status": "In Progress"},
                {"action": "Add memory alerts", "owner": "@sre", "due_date": "2026-01-23", "status": "Planned"}
            ]
        }
    }

if __name__ == "__main__":
    incident_id = "INC-20260121-001"
    data = collect_incident_data(incident_id)
    report = generate_pir(data)

    with open(f"/var/log/incidents/pir-{incident_id}.md", "w") as f:
        f.write(report)

    print(f"PIR generated for {incident_id}")
```

---

## Blameless Postmortem Facilitation

### Postmortem Principles

1. **Focus on systems, not individuals**
   - Humans make mistakes; systems should prevent/catch them
   - Ask "what" and "how", not "who"

2. **Assume good intentions**
   - Everyone was doing their best with available information
   - Hindsight bias is real - avoid "should have known"

3. **Psychological safety**
   - Encourage honest disclosure without fear
   - Celebrate transparency about failures

4. **Learning over blame**
   - Goal is prevention, not punishment
   - Every incident is a learning opportunity

### Postmortem Meeting Agenda

```markdown
# Postmortem Meeting Agenda

## Incident: [ID] - [Title]

## Date: [Meeting Date]

## Duration: 60-90 minutes

### Attendees

- Incident Commander: [Name]
- Responders: [Names]
- Service Owners: [Names]
- Facilitator: [Name]

---

### Opening (5 min)

- [ ] Review ground rules (blameless culture)
- [ ] Confirm meeting objectives

### Timeline Review (15 min)

- [ ] Walk through incident timeline
- [ ] Clarify any missing events
- [ ] Identify decision points

### Root Cause Discussion (20 min)

- [ ] Review 5 Whys analysis
- [ ] Discuss contributing factors
- [ ] Identify systemic issues

### What Went Well (10 min)

- [ ] Effective responses
- [ ] Tools/processes that helped
- [ ] Team collaboration highlights

### What Could Be Improved (15 min)

- [ ] Detection gaps
- [ ] Response inefficiencies
- [ ] Communication issues
- [ ] Tool limitations

### Action Items (15 min)

- [ ] Brainstorm preventive measures
- [ ] Prioritize action items
- [ ] Assign owners and due dates

### Closing (5 min)

- [ ] Summarize key learnings
- [ ] Confirm PIR publication plan
- [ ] Schedule follow-up if needed

---

### Meeting Notes Template

#### Timeline Corrections/Additions

[Notes]

#### Additional Root Causes Identified

[Notes]

#### What Went Well

- [Item]
- [Item]

#### Areas for Improvement

- [Item]
- [Item]

#### Action Items

| Action | Owner | Priority | Due Date |
| ------ | ----- | -------- | -------- |
|        |       |          |          |

#### Key Learnings

[Notes]
```

### Facilitation Questions

```markdown
## Blameless Postmortem Facilitation Questions

### Timeline Exploration

- "Walk me through what you observed at [time]"
- "What information did you have at that moment?"
- "What alternatives were you considering?"
- "What made you choose that approach?"

### Understanding Context

- "What was happening in the broader system at that time?"
- "Were there any unusual circumstances?"
- "What tools or information would have helped?"
- "Looking back, what signals were present but not obvious?"

### System Analysis

- "Why did the system allow this to happen?"
- "What safeguards failed or were missing?"
- "How could we detect this earlier next time?"
- "What would need to change to prevent recurrence?"

### Avoiding Blame

Instead of: "Why didn't you notice the alert?"
Ask: "What was happening that made the alert less visible?"

Instead of: "Why was the code deployed without testing?"
Ask: "What factors contributed to the testing gap?"

Instead of: "Who approved this change?"
Ask: "What does our approval process look like, and where could it be strengthened?"

### Closing Questions

- "What's the most important thing we should fix first?"
- "What would help you respond better next time?"
- "Is there anything we haven't discussed that you want to share?"
```

### Postmortem Document Template

```markdown
# Blameless Postmortem

## Incident: [ID] - [Title]

## Postmortem Date: [Date]

## Postmortem Author: Ahmed Adel Bakr Alderai

---

## Summary

[2-3 sentence summary of the incident and its resolution]

## Leadup

[What was the state of the system before the incident?]
[What changes or events preceded the incident?]

## Fault

[What went wrong?]
[Technical details of the failure mode]

## Impact

[Who was affected and how?]
[Duration and scope of impact]

## Detection

[How was the incident detected?]
[What monitoring/alerting was involved?]
[What could have detected it sooner?]

## Response

[Who responded and when?]
[What actions were taken?]
[What was the timeline of response?]

## Recovery

[How was the service restored?]
[What was the recovery process?]
[How was full recovery confirmed?]

## Timeline

[Detailed timeline of events]

## Root Cause

[Deep dive into why this happened]
[5 Whys analysis]

## Contributing Factors

[List of factors that contributed to the incident]
[System weaknesses exposed]

## Lessons Learned

### What Went Well

- [Item]

### What Went Poorly

- [Item]

### Where We Got Lucky

- [Item]

## Action Items

### Prevent Recurrence

| Action | Type       | Owner | Priority | Due Date | Issue Link |
| ------ | ---------- | ----- | -------- | -------- | ---------- |
|        | Prevention |       | P1       |          |            |

### Improve Detection

| Action | Type      | Owner | Priority | Due Date | Issue Link |
| ------ | --------- | ----- | -------- | -------- | ---------- |
|        | Detection |       | P2       |          |            |

### Improve Response

| Action | Type     | Owner | Priority | Due Date | Issue Link |
| ------ | -------- | ----- | -------- | -------- | ---------- |
|        | Response |       | P2       |          |            |

## Supporting Information

- [Link to Grafana dashboard]
- [Link to relevant logs]
- [Link to deployment diff]
- [Link to related documentation]

---

## Appendix: Postmortem Checklist

- [ ] Timeline is accurate and complete
- [ ] Root cause is identified (not just symptoms)
- [ ] All contributing factors documented
- [ ] Action items have owners and due dates
- [ ] No blame language used
- [ ] Lessons learned are actionable
- [ ] Supporting links are included
- [ ] Reviewed by incident participants
- [ ] Published to incident knowledge base
```

---

## Integration with Other Agents

### Monitoring Expert Integration

```bash
# Invoke monitoring-expert for alert correlation
/agents/devops/monitoring-expert analyze alert correlation for incident INC-20260121-001

# Set up additional monitoring post-incident
/agents/devops/monitoring-expert create memory growth alert for service-name

# Build incident dashboard
/agents/devops/monitoring-expert create Grafana dashboard for incident response
```

### CI/CD Expert Integration

```bash
# Invoke ci-cd-expert for rollback procedures
/agents/devops/ci-cd-expert implement automated rollback for high error rate

# Add deployment safety gates
/agents/devops/ci-cd-expert add canary deployment with automatic rollback

# Review deployment pipeline for incident prevention
/agents/devops/ci-cd-expert review deployment pipeline for safety improvements
```

### Kubernetes Expert Integration

```bash
# Kubernetes-specific incident response
/agents/devops/kubernetes-expert diagnose pod crash loop in production

# Implement pod disruption budgets
/agents/devops/kubernetes-expert configure PDB for zero-downtime deployments
```

### Security Expert Integration

```bash
# Security incident response
/agents/security/security-expert analyze potential security breach indicators

# Post-incident security hardening
/agents/security/security-expert recommend security improvements based on incident
```

---

## Incident Metrics and Reporting

### Key Metrics

| Metric          | Definition                 | Target     | Calculation                         |
| --------------- | -------------------------- | ---------- | ----------------------------------- |
| MTTD            | Mean Time to Detect        | < 5 min    | avg(detect_time - start_time)       |
| MTTA            | Mean Time to Acknowledge   | < 5 min    | avg(ack_time - alert_time)          |
| MTTM            | Mean Time to Mitigate      | < 30 min   | avg(mitigate_time - detect_time)    |
| MTTR            | Mean Time to Resolve       | < 4 hrs    | avg(resolve_time - start_time)      |
| MTBF            | Mean Time Between Failures | > 30 days  | avg(time between incidents)         |
| Incident Count  | Number of incidents        | Decreasing | count(incidents) per period         |
| Recurrence Rate | Similar incidents          | < 10%      | similar_incidents / total_incidents |

### Prometheus Metrics

```yaml
# incident_metrics.yml
groups:
  - name: incident_metrics
    rules:
      - record: incident:mttd:avg
        expr: avg(incident_detect_time_seconds - incident_start_time_seconds)

      - record: incident:mtta:avg
        expr: avg(incident_ack_time_seconds - incident_alert_time_seconds)

      - record: incident:mttm:avg
        expr: avg(incident_mitigate_time_seconds - incident_detect_time_seconds)

      - record: incident:mttr:avg
        expr: avg(incident_resolve_time_seconds - incident_start_time_seconds)

      - record: incident:count:by_severity
        expr: count(incident_total) by (severity)

      - alert: HighIncidentRate
        expr: increase(incident_total[7d]) > 5
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: High incident rate detected
          description: "{{ $value }} incidents in the past 7 days"
```

---

## Quick Reference Commands

```bash
# Declare new incident
/agents/devops/incident-response-agent declare incident for API gateway 503 errors affecting 20% of users

# Classify incident severity
/agents/devops/incident-response-agent classify incident with symptoms: high latency, 5% error rate, affecting checkout flow

# Execute runbook
/agents/devops/incident-response-agent execute runbook-db-connection-pool for PostgreSQL connection exhaustion

# Perform RCA
/agents/devops/incident-response-agent perform root cause analysis for INC-20260121-001

# Generate PIR
/agents/devops/incident-response-agent generate post-incident report for INC-20260121-001

# Initiate rollback
/agents/devops/incident-response-agent initiate rollback for service payment-api to previous version

# Send stakeholder update
/agents/devops/incident-response-agent send P1 incident update for INC-20260121-001 status mitigating

# Facilitate postmortem
/agents/devops/incident-response-agent facilitate blameless postmortem for INC-20260121-001

# Review incident metrics
/agents/devops/incident-response-agent analyze incident trends for past 30 days
```

---

## Examples

### Example 1: High Error Rate Incident

```
/agents/devops/incident-response-agent handle incident

Symptoms:
- API error rate spiked from 0.1% to 15%
- Started 10 minutes ago
- Following deployment of v2.4.1
- P99 latency increased from 200ms to 2000ms

Output:
- Severity classification: P1 (High)
- Immediate actions:
  1. Page on-call engineer
  2. Create incident channel
  3. Correlate with deployment
- Recommended action: Auto-rollback (criteria met)
- Stakeholder notifications queued
```

### Example 2: Database Connection Exhaustion

```
/agents/devops/incident-response-agent diagnose database issues

Symptoms:
- Multiple services reporting connection timeouts
- PostgreSQL connection pool at 100%
- Slow query alerts firing
- User-facing impact: checkout failures

Output:
- Root cause: Long-running analytics query blocking connections
- Runbook executed: runbook-db-connection-pool
- Actions taken:
  1. Killed long-running queries
  2. Scaled application pods
  3. Notified analytics team
- Resolution time: 12 minutes
```

### Example 3: Post-Incident Review

```
/agents/devops/incident-response-agent generate full incident package for INC-20260121-001

Output:
- Post-Incident Report (PIR) generated
- Blameless postmortem scheduled
- Action items created in Jira:
  1. JIRA-1234: Fix memory leak (P1)
  2. JIRA-1235: Add memory growth alerts (P2)
  3. JIRA-1236: Implement canary deployments (P2)
- Incident metrics updated
- Knowledge base article drafted
```
