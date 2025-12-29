# M1 Implementation Quick Reference

## Quick Start Commands

### Queue Watcher
```bash
# Run as daemon (monitors tasks/queue/)
./bin/tri-agent-queue-watcher &

# One-time scan
./bin/tri-agent-queue-watcher --once

# View help
./bin/tri-agent-queue-watcher --help
```

### Budget Watchdog
```bash
# Check current status
./bin/budget-watchdog --status

# Run as daemon
./bin/budget-watchdog &

# Single check
./bin/budget-watchdog --once

# Reset kill-switch
./bin/budget-watchdog --reset
```

### Worker Management
```bash
# Start worker
./bin/tri-agent-worker &
WORKER_PID=$!

# Pause worker (SIGUSR1)
kill -SIGUSR1 $WORKER_PID

# Resume worker (SIGUSR2)
kill -SIGUSR2 $WORKER_PID

# Stop worker
kill $WORKER_PID
```

## SQLite Queries

### View All Tasks
```bash
sqlite3 state/tri-agent.db "SELECT id, state, priority, worker_id FROM tasks ORDER BY priority, created_at;"
```

### View Queued Tasks
```bash
sqlite3 state/tri-agent.db "SELECT id, CASE priority WHEN 0 THEN 'CRITICAL' WHEN 1 THEN 'HIGH' WHEN 2 THEN 'MEDIUM' WHEN 3 THEN 'LOW' END as priority FROM tasks WHERE state='QUEUED' ORDER BY priority, created_at;"
```

### View Active Workers
```bash
sqlite3 state/tri-agent.db "SELECT worker_id, status, pid, started_at FROM workers WHERE status IN ('idle','busy','paused');"
```

### View Task History
```bash
sqlite3 state/tri-agent.db "SELECT timestamp, event_type, actor, payload FROM events WHERE task_id='TASK_ID_HERE' ORDER BY timestamp;"
```

### Check Pause State
```bash
sqlite3 state/tri-agent.db "SELECT key, value FROM state WHERE file_path='system' AND key='pause_requested';"
```

## Budget Monitoring

### View Current Spend
```bash
./bin/budget-watchdog --status
```

### Manually Log Spend
```bash
# Format: {"timestamp":"ISO8601","timestamp_epoch":UNIX,"amount":FLOAT,"model":"MODEL","task_id":"ID"}
echo '{"timestamp":"'$(date -Iseconds)'","timestamp_epoch":'$(date +%s)',"amount":0.25,"model":"claude","task_id":"test-001"}' >> state/budget/spend.jsonl
```

### Check Kill-Switch Status
```bash
if [[ -f state/budget/kill_switch.active ]]; then
    echo "Kill-switch ACTIVE"
    cat state/budget/kill_switch.active | jq .
else
    echo "Kill-switch inactive"
fi
```

## File Structure

### Task Queue Layout
```
tasks/queue/
├── CRITICAL_M1-001_1234567890.md    # CRITICAL priority from filename
├── HIGH/                             # HIGH priority from directory
│   └── HIGH_M1-006_1234567891.md
├── MEDIUM/
│   └── MEDIUM_M3-015_1234567892.md
└── LOW/
    └── LOW_M5-035_1234567893.md
```

### State Directory
```
state/
├── tri-agent.db                    # SQLite canonical state
├── budget/
│   ├── spend.jsonl                 # Spend log
│   ├── kill_switch.active          # Kill-switch (when active)
│   └── watchdog.pid                # Watchdog PID
└── queue-watcher.pid               # Queue watcher PID
```

## Common Workflows

### Complete Task Lifecycle
```bash
# 1. Create task file
cat > tasks/queue/CRITICAL/CRITICAL_TEST_001.md <<EOF
# [CRITICAL] Test Task

Implementation details here...
EOF

# 2. Queue watcher bridges to SQLite (automatic if daemon running)
./bin/tri-agent-queue-watcher --once

# 3. Worker claims and processes
# (automatic if worker running)

# 4. Check task status
sqlite3 state/tri-agent.db "SELECT state, worker_id FROM tasks WHERE id='CRITICAL_TEST_001';"
```

### Emergency Budget Stop
```bash
# 1. Kill-switch activates automatically when limits exceeded
# 2. Or manually activate:
kill -SIGUSR1 $(pgrep tri-agent-worker)  # Pause all workers

# 3. Check status
./bin/budget-watchdog --status

# 4. Reset when safe
./bin/budget-watchdog --reset
kill -SIGUSR2 $(pgrep tri-agent-worker)  # Resume workers
```

### Worker Shard Management
```bash
# Start workers for different shards
WORKER_SHARD="critical" ./bin/tri-agent-worker &
WORKER_SHARD="high" ./bin/tri-agent-worker &
WORKER_SHARD="medium" ./bin/tri-agent-worker &

# Assign shard to task
sqlite3 state/tri-agent.db "UPDATE tasks SET shard='critical' WHERE id='TASK_ID';"
```

## Configuration Files

### Budget Limits (Environment)
```bash
# Set in shell or systemd service
export BUDGET_DAILY_LIMIT=75.00
export BUDGET_RATE_LIMIT=1.00
export BUDGET_RATE_WARNING=0.50
export BUDGET_CHECK_INTERVAL=30
export BUDGET_WINDOW_SIZE=300
```

### Queue Watcher (Environment)
```bash
export POLL_INTERVAL=5
export TRACE_ID=custom-trace-id
```

### Worker (Environment)
```bash
export WORKER_ID=custom-worker-1
export WORKER_SHARD=critical
export WORKER_MODEL=claude
```

## Troubleshooting

### Workers Not Claiming Tasks
```bash
# Check if tasks exist in SQLite
sqlite3 state/tri-agent.db "SELECT COUNT(*) FROM tasks WHERE state='QUEUED';"

# Check worker status
sqlite3 state/tri-agent.db "SELECT * FROM workers;"

# Check if paused
sqlite3 state/tri-agent.db "SELECT value FROM state WHERE key='pause_requested';"

# Check budget status
./bin/budget-watchdog --status
```

### Queue Watcher Not Bridging
```bash
# Check if daemon is running
pgrep -f tri-agent-queue-watcher

# Run manually once
./bin/tri-agent-queue-watcher --once

# Check logs
tail -f logs/worker.log
```

### Kill-Switch Won't Deactivate
```bash
# Manually remove
rm -f state/budget/kill_switch.active

# Clear SQLite pause flag
sqlite3 state/tri-agent.db "DELETE FROM state WHERE key='pause_requested';"

# Or use reset command
./bin/budget-watchdog --reset
```

### Task Stuck in RUNNING
```bash
# Check worker heartbeat
sqlite3 state/tri-agent.db "SELECT worker_id, last_heartbeat FROM workers WHERE worker_id IN (SELECT worker_id FROM tasks WHERE state='RUNNING');"

# Manually recover stale tasks (use lib/sqlite-state.sh)
source lib/sqlite-state.sh
recover_zombie_tasks 60  # 60 minute timeout
```

## Testing

### Test Task Claiming
```bash
# Create test task
sqlite3 state/tri-agent.db "INSERT INTO tasks (id, name, type, priority, state) VALUES ('TEST_001', 'Test', 'test', 0, 'QUEUED');"

# Claim it
source lib/sqlite-state.sh
task_id=$(claim_task_atomic_filtered "test-worker" "" "" "")
echo "Claimed: $task_id"

# Verify
sqlite3 state/tri-agent.db "SELECT state, worker_id FROM tasks WHERE id='TEST_001';"
```

### Test Budget Limits
```bash
# Simulate high spend
for i in {1..100}; do
    echo '{"timestamp":"'$(date -Iseconds)'","timestamp_epoch":'$(date +%s)',"amount":0.20,"model":"claude","task_id":"test"}' >> state/budget/spend.jsonl
done

# Check if would trigger
./bin/budget-watchdog --once
```

### Test Signal Handling
```bash
# Start worker
./bin/tri-agent-worker &
PID=$!

# Send pause
kill -SIGUSR1 $PID
sleep 2

# Check log
tail logs/worker.log | grep -i pause

# Send resume
kill -SIGUSR2 $PID
sleep 2
tail logs/worker.log | grep -i resume

# Cleanup
kill $PID
```

## Performance Tuning

### High-Throughput Queue
```bash
# Reduce poll interval
POLL_INTERVAL=1 ./bin/tri-agent-queue-watcher &
```

### Budget Check Frequency
```bash
# More frequent checks
BUDGET_CHECK_INTERVAL=10 ./bin/budget-watchdog &
```

### SQLite Optimization
```bash
# Already configured in sqlite-state.sh:
# - WAL mode for concurrent writes
# - NORMAL synchronous (faster than FULL)
# - 5s busy timeout
# - Foreign keys enabled
```

## Integration Examples

### Systemd Service Files

#### queue-watcher.service
```ini
[Unit]
Description=TRI-24 Queue Watcher
After=network.target

[Service]
Type=simple
User=aadel
WorkingDirectory=/path/to/claude-sdlc-orchestrator/v2
Environment="POLL_INTERVAL=5"
ExecStart=/path/to/claude-sdlc-orchestrator/v2/bin/tri-agent-queue-watcher
Restart=always

[Install]
WantedBy=multi-user.target
```

#### budget-watchdog.service
```ini
[Unit]
Description=TRI-24 Budget Watchdog
After=network.target

[Service]
Type=simple
User=aadel
WorkingDirectory=/path/to/claude-sdlc-orchestrator/v2
Environment="BUDGET_DAILY_LIMIT=75.00"
Environment="BUDGET_RATE_LIMIT=1.00"
ExecStart=/path/to/claude-sdlc-orchestrator/v2/bin/budget-watchdog
Restart=always

[Install]
WantedBy=multi-user.target
```

### Cron Jobs
```cron
# Run queue watcher every 5 minutes (if not using daemon)
*/5 * * * * cd /path/to/v2 && ./bin/tri-agent-queue-watcher --once

# Check budget hourly
0 * * * * cd /path/to/v2 && ./bin/budget-watchdog --once || echo "Budget exceeded!" | mail -s "TRI-24 Budget Alert" admin@example.com
```

## API Reference

### SQLite State Functions (lib/sqlite-state.sh)

```bash
# Create task
create_task ID NAME TYPE PRIORITY PAYLOAD STATE TRACE_ID

# Claim task atomically
task_id=$(claim_task_atomic_filtered WORKER_ID TYPES SHARD MODEL)

# Transition task
transition_task TASK_ID NEW_STATE REASON ACTOR

# State helpers
mark_task_running TASK_ID WORKER_ID
mark_task_review TASK_ID
mark_task_completed TASK_ID REASON
mark_task_failed TASK_ID REASON

# Pause management
set_pause_requested REASON
clear_pause_requested
pause_requested  # Returns 0 if paused, 1 if not
```

---

**Last Updated:** 2025-12-29
**Version:** v2.0.0
