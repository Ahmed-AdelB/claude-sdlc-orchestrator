# Monitoring Assessment (2026-01-21)

## Scope
- Grafana dashboards: `dashboards/grafana/cost-analysis.json`, `dashboards/grafana/tri-agent-overview.json`
- Prometheus alerts: `dashboards/prometheus/alerts.yml`
- System metrics snapshot: `metrics/current.prom`, `metrics/current.json`
- Reference docs: `dashboards/README.md`, `monitoring/README.md`

## JSON Validation
- `dashboards/grafana/cost-analysis.json`: valid JSON (parsed by `python3 -m json.tool`).
- `dashboards/grafana/tri-agent-overview.json`: valid JSON (parsed by `python3 -m json.tool`).

## Alert Rules Review (Prometheus)
- YAML parses correctly; 6 groups and 23 alert rules.
- All rules include `alert`, `expr`, `labels`, and `annotations`.
- Potential template issue: `mul` and `sub` functions in annotations (budget alerts) are not standard Prometheus/Alertmanager template functions; these may render incorrectly depending on server configuration.

## Metric Existence Check
Metrics referenced by dashboards/alerts vs current exported metrics (`metrics/current.prom`):

### Present in system
- `tri_agent_tasks_total`
- `tri_agent_disk_free_bytes`

### Missing in system (referenced but not exported)
- `tri_agent_active_agents`
- `tri_agent_active_agents_by_model`
- `tri_agent_budget_total`
- `tri_agent_budget_used`
- `tri_agent_context_tokens_used`
- `tri_agent_cost_total`
- `tri_agent_db_integrity_check`
- `tri_agent_last_checkpoint_timestamp`
- `tri_agent_lock_attempts_total`
- `tri_agent_lock_failures_total`
- `tri_agent_model_available`
- `tri_agent_rate_limit_hits_total`
- `tri_agent_request_duration_seconds_bucket`
- `tri_agent_session_duration_seconds`
- `tri_agent_tasks_in_progress`
- `tri_agent_tokens_total`
- `tri_agent_verification_latency_seconds_bucket`
- `tri_agent_verification_total`

### Label/value mismatches
- `tri_agent_tasks_total` uses `status="success"|"failure"` in `metrics/current.prom`, while dashboards/alerts use `status="completed"|"failed"`. This causes error-rate panels/alerts and cost-per-task calculations to return no data.
- `tri_agent_tasks_total` includes a `model="all"` series in `metrics/current.prom`. Queries like `sum(tri_agent_tasks_total)` will double-count unless `model!="all"` is filtered out.

## Query/Expression Issues
- `dashboards/grafana/cost-analysis.json` panel "Token Efficiency by Model" uses:
  - `rate(tri_agent_cost_total{model="claude_sonnet"}[5m] + tri_agent_cost_total{model="claude_opus"}[5m])`
  - This is invalid PromQL; `rate()` cannot accept a binary operation over range vectors. It should be `rate(...sonnet...) + rate(...opus...)`.

## Missing Panels or Alerts
### Existing metrics with no dashboard/alert coverage
The following metrics exist in `metrics/current.prom` but are not referenced by any dashboard panels or alerts:
- Health/heartbeat: `tri_agent_heartbeat_healthy`, `tri_agent_heartbeat_age_seconds`, `tri_agent_health_status`, `tri_agent_health_score`
- Workers/queue: `tri_agent_active_workers`, `tri_agent_max_workers`, `tri_agent_worker_utilization_pct`, `tri_agent_queue_size`
- Performance: `tri_agent_execution_time_seconds_*`
- Errors: `tri_agent_errors_total`, `tri_agent_errors_by_type_total`
- Database: `tri_agent_db_lock_*`, `tri_agent_db_size_bytes`
- Disk: `tri_agent_disk_usage_bytes`
- API activity: `tri_agent_api_calls_total`, `tri_agent_api_calls_per_hour`
- KPIs: `tri_agent_kpi_*`

### Alert coverage gaps
- No alerting tied to heartbeat/health metrics (`tri_agent_heartbeat_healthy`, `tri_agent_health_status`).
- No alerts for queue depth or worker utilization despite metrics existing.
- No alert for data collection/scrape staleness (`tri_agent_scrape_timestamp`).
- Daily model budget alert lacks coverage for `model="gemini"`.

## Monitoring Coverage Assessment
- **Strengths**: The dashboards/alerts define a comprehensive conceptual model (cost, budget, throughput, error rate, context usage, verification, and infrastructure). Alert grouping is well-organized and thresholds are specified.
- **Key gaps**: Most referenced metrics are not exported by the current system, which means the dashboards and alerts will largely render empty or remain inactive. The only common metrics are `tri_agent_tasks_total` (with label mismatches) and `tri_agent_disk_free_bytes`.
- **Coverage mismatch**: The metrics actually exported today (worker utilization, queue depth, health/heartbeat, execution time, DB locks) are not visualized or alerted on. This leaves core operational health (availability, saturation, and latency) under-monitored despite data being available.
- **Overall completeness**: Low in practice due to instrumentation mismatch. The monitoring design is broad, but the current exporter and label taxonomy do not align with the dashboards/alerts.

## Recommended Next Steps
1. Align metric names and labels between exporter and dashboards/alerts (especially `tri_agent_tasks_total` status values and missing cost/context/token/verification metrics).
2. Fix invalid PromQL in the token efficiency panel.
3. Add panels/alerts for the existing health/heartbeat, queue, worker utilization, and execution-time metrics.
4. Decide whether to keep `model="all"` series or filter it out in queries to avoid double counting.
