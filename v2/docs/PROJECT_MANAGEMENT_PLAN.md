# Claude SDLC Orchestrator v5.0 - Implementation & Deployment Plan

**Start Date:** 2024-12-29
**Target Go-Live:** 2025-01-26

---

## 1. 4-Week Implementation Timeline

### Week 1: Critical Infrastructure (Dec 29 - Jan 4)
*Goal: Solidify data persistence and cost controls.*

- **Day 1 (Sun):** Initialize SQLite database with WAL mode. Migrate `preflight.json` and `health.json` to DB tables.
- **Day 2 (Mon):** Implement `lib/sqlite-state.sh` for atomic locking and task claiming. Replace file-based locking.
- **Day 3 (Tue):** Develop `budget-watchdog` daemon. Implement token counting logic and $1/min kill-switch.
- **Day 4 (Wed):** Update `tri-agent-router` to enforce Model Diversity (different families for consensus).
- **Day 5 (Thu):** Docker hardening. Create non-root user, multi-stage builds (as per `Dockerfile.prod`).
- **Day 6 (Fri):** Integration testing of SQLite locking under load (simulated 3 workers).
- **Day 7 (Sat):** Buffer / Code Review.

### Week 2: Reliability & Workers (Jan 5 - Jan 11)
*Goal: Scale to parallel workers and ensure system liveness.*

- **Day 8 (Sun):** Implement `M/M/1` worker pool skeleton.
- **Day 9 (Mon):** Implement Progressive Heartbeat (task-aware timeouts: 5m for small, 30m for large tasks).
- **Day 10 (Tue):** Scale Worker Pool to 3 concurrent workers (sharded by task type: impl, review, architect).
- **Day 11 (Wed):** Load test API rate limits with 3 workers. Implement "Cool-down Mode" for 429s.
- **Day 12 (Thu):** Setup Prometheus Pushgateway integration for metrics (`llm_tokens`, `task_duration`).
- **Day 13 (Fri):** Implement "Zombie Process Reaper" to clean up stuck sessions >24h.
- **Day 14 (Sat):** Deployment dry-run on staging env.

### Week 3: Optimization & Flow (Jan 12 - Jan 18)
*Goal: Optimize task flow and user experience.*

- **Day 15 (Sun):** Implement Priority Lanes (Critical/Normal/Background) in SQLite schema.
- **Day 16 (Mon):** Create `bin/tri-agent-ctl` CLI for manual priority overrides and pausing.
- **Day 17 (Tue):** Refine "Amnesia Protocol" (auto-archive memory >24h).
- **Day 18 (Wed):** Security Audit: Verify no `.env` leakage in logs, check `sudo` restrictions.
- **Day 19 (Thu):** Chaos Engineering: Simulate network blackouts and API failures.
- **Day 20 (Fri):** Documentation update (Architecture diagrams, recovery runbooks).
- **Day 21 (Sat):** Buffer.

### Week 4: Polish & Go-Live (Jan 19 - Jan 25)
*Goal: Final testing and production deployment.*

- **Day 22 (Sun):** Full Event Sourcing implementation for Audit Trail (if on schedule).
- **Day 23 (Mon):** End-to-end regression testing suite.
- **Day 24 (Tue):** Finalize Grafana dashboards and Alertmanager rules.
- **Day 25 (Wed):** Code Freeze. Release Candidate 1 (RC1).
- **Day 26 (Thu):** User Acceptance Testing (Self-Host).
- **Day 27 (Fri):** **GO-LIVE DEPLOYMENT**.
- **Day 28 (Sat):** Post-deployment monitoring and party.

---

## 2. Deployment Infrastructure

### Artifacts Created
- `v2/deployment/Dockerfile.prod`: Hardened, non-root, multi-stage build.
- `v2/deployment/docker-compose.prod.yml`: Full stack with Redis, Prometheus, Grafana.
- `v2/monitoring/prometheus.yml`: Metric scraping config.
- `v2/monitoring/alertmanager.yml`: Alert routing.

### Environment Variables
Required in `.env.prod`:
```bash
ANTHROPIC_API_KEY=sk-...
OPENAI_API_KEY=sk-...
GOOGLE_API_KEY=AI...
REDIS_URL=redis://claude-redis:6379/0
CLAUDE_AUTONOMOUS_MODE=true
GRAFANA_PASSWORD=secure_password
```

## 3. Go-Live Checklist

### Pre-Deployment
- [ ] **Secret Rotation:** Rotate all API keys before setting production vars.
- [ ] **Database Migration:** Ensure `tasks.db` schema is applied (`sqlite3 tasks.db < schema.sql`).
- [ ] **Resource Quotas:** Verify Docker host has at least 8GB RAM / 4 CPUs.
- [ ] **Rate Limits:** Request quota increase from Anthropic/OpenAI if needed.
- [ ] **Backup:** Snapshot current `v2/state` directory.

### Deployment Steps
1. **Clone/Pull:** `git pull origin main`
2. **Config:** `cp .env.example .env.prod` and populate.
3. **Build:** `docker compose -f v2/deployment/docker-compose.prod.yml build`
4. **Start Data:** `docker compose -f v2/deployment/docker-compose.prod.yml up -d redis prometheus`
5. **Start Orchestrator:** `docker compose -f v2/deployment/docker-compose.prod.yml up -d orchestrator`
6. **Verify:** Check logs `docker compose -f v2/deployment/docker-compose.prod.yml logs -f orchestrator`

### Post-Deployment Validation
- [ ] **Health Check:** `curl localhost:8080/health` (if exposed) or check `state/health.json`.
- [ ] **Test Task:** Submit a "Hello World" task via `task-queue`.
- [ ] **Metrics:** Verify Prometheus is receiving data at `localhost:9090`.
- [ ] **Alerts:** Manually trigger a high-cost alert to test notification path.

### Rollback Procedure
1. Stop containers: `docker compose down`
2. Revert image tag in compose file to previous version.
3. Restore `tasks.db` from backup if schema corrupted.
4. `docker compose up -d`
