# Incident Runbooks Complete Collection

This document contains detailed runbooks for 8 common incident scenarios identified for the Autonomous SDLC system.

**Table of Contents**
1. [RB-001] Database Migration Failures
2. [RB-002] Network/Connectivity Issues
3. [RB-003] Out of Memory (OOM)
4. [RB-004] File Descriptor Exhaustion
5. [RB-005] Authentication Token Expiration
6. [RB-006] MCP Server Failures
7. [RB-007] Long-Running Session State Corruption
8. [RB-008] Rate Limit Escalation

---

## [RB-001] Database Migration Failures

**Severity:** High
**Owner:** Database Reliability Engineer / Lead Developer

### 1. Symptom Detection
- **Alerts:**
    - `DatabaseMigrationFailed` alert in Prometheus/Grafana.
    - CI/CD pipeline failure during `db:migrate` or `alembic upgrade` steps.
- **Logs:**
    - Error messages containing `Foreign key constraint violation`, `Duplicate column name`, `Lock wait timeout exceeded`, or `Relation already exists`.
- **User Impact:**
    - Deployment stalls.
    - Application may fail to start if schema is inconsistent with code.
    - Potential data unavailability if locking persists.

### 2. Root Cause Analysis (RCA)
- **Schema Mismatch:** The migration script assumes a schema state that does not match production.
- **Data Integrity Violation:** Existing data violates new constraints (e.g., adding a `NOT NULL` column to a table with existing rows).
- **Locking Issues:** Heavy traffic or long-running queries preventing the migration from acquiring necessary table locks.
- **Version Skew:** Multiple migration commands running concurrently.

### 3. Recovery Procedures
**Immediate Actions:**
1.  **Stop the Deployment:** Prevent further automated attempts to apply the migration.
2.  **Verify Database State:**
    - Check the `_prisma_migrations` or `alembic_version` table to see which migration applied last.
    - Use database CLI (`psql`, `mysql`) to inspect the actual table structure.

**Resolution Steps:**
-   **Scenario A: Migration Failed mid-transaction (Rolled back automatically)**
    1.  Fix the migration script (e.g., provide a default value for new non-null columns).
    2.  Re-run the migration in a staging environment first.
    3.  Retry deployment.

-   **Scenario B: Migration stuck or partially applied (No transaction support)**
    1.  Manually reverse the partial changes (e.g., `ALTER TABLE ... DROP COLUMN ...`).
    2.  Mark the migration as failed in the tracking table if necessary.
    3.  Fix the script and retry.

-   **Scenario C: Locking Timeout**
    1.  Identify blocking queries: `SELECT * FROM pg_stat_activity WHERE wait_event_type = 'Lock';`
    2.  Kill blocking sessions if safe and necessary: `SELECT pg_terminate_backend(pid);`
    3.  Retry migration during a maintenance window or low-traffic period.

### 4. Prevention Measures
-   **Testing:** Always test migrations against a production-like copy of the data (sanitized) in Staging.
-   **Backwards Compatibility:** Ensure code is backwards compatible with the previous schema version (expand and contract pattern).
-   **Timeout Configuration:** Set appropriate `lock_timeout` values in migration scripts to fail fast rather than hang.
-   **CI Checks:** Use tools like `pg-schema-diff` to validate migration safety.

---

## [RB-002] Network/Connectivity Issues

**Severity:** Critical
**Owner:** Network Reliability Engineer

### 1. Symptom Detection
- **Alerts:**
    - `HighErrorRate` (5xx errors) from load balancers or API gateways.
    - `ServiceUnreachable` or ping check failures.
- **Logs:**
    - `Connection refused`, `Connection timed out`, `DNS lookup failed`, `No route to host`.
- **Metrics:**
    - Sudden drop in request volume or spike in latency.

### 2. Root Cause Analysis (RCA)
- **DNS Resolution:** DNS server failure or misconfigured records.
- **Firewall/Security Group:** Rules blocking traffic on specific ports.
- **Infrastructure:** Downstream provider outage (ISP, Cloud Region).
- **Exhaustion:** NAT gateway port exhaustion or bandwidth limits reached.

### 3. Recovery Procedures
**Immediate Actions:**
1.  **Isolate Scope:** Determine if the issue is internal (pod-to-pod) or external (user-facing).
2.  **Check Status Pages:** Verify Cloud Provider status (AWS, GCP, Azure).

**Resolution Steps:**
-   **DNS Issues:**
    1.  Flush DNS caches on affected nodes/containers.
    2.  Verify DNS records using `dig` or `nslookup`.
    3.  Temporarily switch to backup DNS resolvers (e.g., 8.8.8.8) if internal DNS is failing.

-   **Connectivity/Firewall:**
    1.  Use `traceroute` or `mtr` to identify where packets are dropping.
    2.  Review recent Security Group or firewall rule changes.
    3.  Rollback recent network configuration changes.

-   **Infrastructure:**
    1.  Failover to a passive region or availability zone if available (DR plan).

### 4. Prevention Measures
-   **Redundancy:** Use multi-AZ and multi-region deployments.
-   **Circuit Breakers:** Implement circuit breakers in code to handle downstream failures gracefully.
-   **Timeouts/Retries:** Configure aggressive timeouts with exponential backoff for network calls.
-   **Monitoring:** Set up synthetic monitoring (Canary) to detect connectivity issues from the outside in.

---

## [RB-003] Out of Memory (OOM)

**Severity:** High
**Owner:** SRE / Application Developer

### 1. Symptom Detection
- **Alerts:**
    - `ContainerOOMKilled` (Kubernetes).
    - `HighMemoryUsage` (>90%).
- **Logs:**
    - System logs (`dmesg` or `/var/log/syslog`) showing `OOM Killer` invoked.
    - Application logs typically stop abruptly.
- **Behavior:**
    - Process restarts unexpectedly.
    - Performance degradation (swapping) before crash.

### 2. Root Cause Analysis (RCA)
- **Memory Leak:** Application fails to release memory objects (e.g., closures, global variables).
- **Spike in Load:** Sudden increase in concurrent requests or data processing volume.
- **Misconfiguration:** Memory limits (cgroups/Docker) set too low for the workload.
- **Large Payload:** Processing a single massive request (e.g., uploading a 5GB file into RAM).

### 3. Recovery Procedures
**Immediate Actions:**
1.  **Restart Service:** Orchestrator (e.g., K8s) usually does this, but manual restart might clear transient states.
2.  **Scale Up:** Temporarily increase memory limits or horizontal replicas to distribute load.

**Resolution Steps:**
1.  **Analyze Profiles:** Capture heap dumps or use a profiler (e.g., `pprof` for Go, `heapsnapshot` for Node.js).
2.  **Identify Leaks:** Look for growing object counts in the heap dump.
3.  **Optimize:** Refactor code to stream data instead of loading into memory (e.g., processing large CSVs).
4.  **Adjust Limits:** Permanently increase resource requests/limits based on observed peak usage.

### 4. Prevention Measures
-   **Resource Limits:** Set appropriate Request/Limit pairs in Kubernetes.
-   **Load Testing:** Perform stress tests to identify memory usage patterns under load.
-   **Code Review:** Watch for common leak patterns (unbounded caches, detached DOM nodes, global listeners).
-   **Auto-scaling:** Configure HPA (Horizontal Pod Autoscaler) based on memory metrics.

---

## [RB-004] File Descriptor Exhaustion

**Severity:** Medium/High
**Owner:** SRE

### 1. Symptom Detection
- **Alerts:**
    - `TooManyOpenFiles` errors.
    - File Descriptor usage metric > 80% of `ulimit`.
- **Logs:**
    - `EMFILE: too many open files`.
    - `Socket accept failed`.

### 2. Root Cause Analysis (RCA)
- **Resource Leak:** Application opens files or sockets but fails to close them (e.g., missing `finally` block or `defer`).
- **High Concurrency:** Valid high traffic requiring more sockets than the OS default allows.
- **Log Rotation Failure:** Logs not rotating, keeping file handles open indefinitely (though usually just disk space).

### 3. Recovery Procedures
**Immediate Actions:**
1.  **Restart Application:** Frees all descriptors associated with the process.

**Resolution Steps:**
1.  **Inspect Open Files:** Use `lsof -p <pid>` to see what files/sockets are open.
2.  **Increase Ulimit:**
    -   Temporary: `ulimit -n 65535`
    -   Permanent: Edit `/etc/security/limits.conf` or systemd service file (`LimitNOFILE`).
3.  **Fix Code:** Ensure all resources (DB connections, HTTP clients, file readers) are closed properly using `using`/`try-with-resources` patterns.

### 4. Prevention Measures
-   **Monitoring:** Export `process_open_fds` metric and alert on it.
-   **Code Standards:** Enforce linting rules that require resource cleanup (e.g., `eslint-plugin-promise`).
-   **Connection Pooling:** Use connection pools for DBs and HTTP clients to reuse sockets.

---

## [RB-005] Authentication Token Expiration

**Severity:** Medium
**Owner:** Security Engineer / Backend Developer

### 1. Symptom Detection
- **Alerts:**
    - Spike in `401 Unauthorized` responses.
    - Failed scheduled jobs or background tasks.
- **Logs:**
    - `JwtExpired`, `TokenExpiredError`, `InvalidCredentials`.
- **User Reports:**
    - Users forced to log out and log back in repeatedly.

### 2. Root Cause Analysis (RCA)
- **Drift:** System clock skew between auth server and resource server.
- **Configuration:** Token Time-To-Live (TTL) set too short.
- **Refresh Failure:** Refresh token logic failed (e.g., refresh token expired or revoked).
- **Key Rotation:** Signing keys rotated without grace period for verification.

### 3. Recovery Procedures
**Immediate Actions:**
1.  **Service Accounts:** Manually rotate/generate new API keys for critical background services.

**Resolution Steps:**
1.  **Check Clocks:** Verify NTP synchronization on all servers.
2.  **Verify Refresh Logic:** Inspect client-side or service-side logic for token renewal flows.
3.  **Key Caching:** Ensure services fetch new public keys (JWKS) if signing keys were rotated.
4.  **Update TTL:** If business requirements allow, increase token validity duration temporarily.

### 4. Prevention Measures
-   **Graceful Rotation:** Support multiple valid signing keys during rotation windows.
-   **Proactive Refresh:** Clients should refresh tokens *before* expiration (e.g., at 80% of TTL).
-   **Monitoring:** Alert on increases in 401 rates specifically for internal services.

---

## [RB-006] MCP Server Failures

**Severity:** High (for AI Agent functionality)
**Owner:** AI Systems Engineer

### 1. Symptom Detection
- **Alerts:**
    - Agent tool execution failure rate high.
    - `ConnectionRefused` when Agent tries to contact MCP server.
- **Logs:**
    - `Stdio transport error`, `Process exited unexpectedly`.
    - JSON-RPC parse errors.

### 2. Root Cause Analysis (RCA)
- **Process Crash:** Underlying tool (e.g., `sqlite3`, `git`) crashed.
- **Protocol Violation:** Malformed JSON-RPC messages between client and server.
- **Environment:** Missing dependencies (env vars, binaries) in the MCP server execution context.
- **Concurrency:** Single-threaded MCP server blocked by long operation.

### 3. Recovery Procedures
**Immediate Actions:**
1.  **Restart MCP Server:** Restart the specific sub-process or the Agent container hosting the connections.

**Resolution Steps:**
1.  **Check Stderr:** MCP servers usually log debug info to stderr. Capture this output.
2.  **Validate Config:** Ensure `claude_desktop_config.json` or equivalent configuration maps to valid executable paths.
3.  **Test Isolation:** Run the MCP server manually in a terminal to verify it starts and accepts input.

### 4. Prevention Measures
-   **Supervision:** Use a process supervisor (like `pm2` or systemd) for standalone MCP servers.
-   **Validation:** Use strict schema validation for all tool inputs/outputs (Pydantic/Zod).
-   **Timeouts:** Implement timeouts for tool calls to prevent indefinite blocking.

---

## [RB-007] Long-Running Session State Corruption

**Severity:** Medium
**Owner:** Backend Developer

### 1. Symptom Detection
- **Alerts:**
    - `SerializationError` or `DeserializationError` in session store (Redis).
    - User state inconsistencies (e.g., cart items vanishing, wrong user profile data).
- **Logs:**
    - `PickleError`, `ClassMismatch`, `Invalid JSON`.

### 2. Root Cause Analysis (RCA)
- **Deployment:** New code deployed with incompatible object structure (schema change) while old sessions exist.
- **Race Condition:** Concurrent requests modifying the same session object.
- **Data Corruption:** Memory bit flip or storage failure (rare).

### 3. Recovery Procedures
**Immediate Actions:**
1.  **Flush Sessions:** Worst case, clear all sessions (`FLUSHDB` in Redis) to force re-login. (High impact, use caution).

**Resolution Steps:**
1.  **Namespace Versioning:** Prefix session keys with version (e.g., `sess:v2:...`). Increment version on breaking changes.
2.  **Safe Fallback:** Update deserialization logic to handle missing fields gracefully or discard invalid sessions without crashing.

### 4. Prevention Measures
-   **Versioning:** Always version serialized data structures.
-   **Atomic Operations:** Use atomic operators (Redis `HSET`, `INCR`) instead of `GET`-modify-`SET`.
-   **TTL:** Ensure all sessions have reasonable expiration to auto-clean old formats.

---

## [RB-008] Rate Limit Escalation

**Severity:** Medium
**Owner:** API Gateway / SRE

### 1. Symptom Detection
- **Alerts:**
    - `429 Too Many Requests` spike.
    - `QuotaExceeded` notifications from 3rd party APIs (e.g., OpenAI, GitHub).
- **User Impact:**
    - Degraded feature availability.

### 2. Root Cause Analysis (RCA)
- **DDoS/Abuse:** Malicious actor flooding endpoints.
- **Bug:** Retry loop without backoff in client code (thundering herd).
- **Configuration:** Limits set too low for valid organic growth.
- **Shared Quota:** "Noisy neighbor" consuming shared API quota.

### 3. Recovery Procedures
**Immediate Actions:**
1.  **Block Offender:** Identify IP or User ID and block at WAF/Gateway level.
2.  **Increase Quota:** Temporarily purchase more credits or request limit increase from provider.

**Resolution Steps:**
1.  **Analyze Traffic:** Use logs to determine if traffic is legitimate.
2.  **Implement Caching:** Cache responses to reduce calls to rate-limited upstream services.
3.  **Fix Clients:** Patch client code to use exponential backoff with jitter.

### 4. Prevention Measures
-   **Per-User Limits:** Implement granular rate limiting (Token Bucket) per user/IP.
-   **Bulkheads:** Segregate quotas for critical vs. non-critical features.
-   **Monitoring:** Alert at 70% and 90% of quota usage.