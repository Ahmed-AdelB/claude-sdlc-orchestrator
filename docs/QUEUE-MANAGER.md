# Task Queue Prioritization System

## Overview

The task queue prioritization system manages the 286+ item backlog identified in the performance assessment. It provides:

- **Priority levels**: P0-CRITICAL, P1-HIGH, P2-MEDIUM, P3-LOW
- **Priority queue**: Heap-based data structure with SQLite persistence
- **Age-based boosting**: Old tasks automatically get promoted
- **Batch processing**: Similar tasks grouped for parallel execution

## Installation

The queue manager is located at:

- Python script: `~/.claude/scripts/queue-manager.py`
- Shell wrapper: `~/.claude/scripts/queue-manager.sh`
- CLI symlink: `~/.local/bin/queue-manager`

Database: `~/.claude/task-queue/queue.db`

## Quick Start

```bash
# Add a task
queue-manager add "Fix critical bug" -p P0 -c bugfix

# List pending tasks
queue-manager list

# Get next task
queue-manager next

# Start and complete a task
queue-manager start task_123456_789 -a claude
queue-manager complete task_123456_789

# View statistics
queue-manager stats
```

## Priority Levels

| Level | Name     | Value | Use Case                                     |
| ----- | -------- | ----- | -------------------------------------------- |
| P0    | CRITICAL | 0     | Security vulnerabilities, production outages |
| P1    | HIGH     | 1     | Important features, significant bugs         |
| P2    | MEDIUM   | 2     | Normal development tasks (default)           |
| P3    | LOW      | 3     | Nice-to-have, documentation, cleanup         |

Lower numeric value = higher priority.

## Age-Based Priority Boost

Tasks automatically get promoted if they wait too long:

| Original    | Promoted To   | Wait Time |
| ----------- | ------------- | --------- |
| P3 (LOW)    | P2 (MEDIUM)   | 4 hours   |
| P2 (MEDIUM) | P1 (HIGH)     | 8 hours   |
| P1 (HIGH)   | P0 (CRITICAL) | 24 hours  |

Run `queue-manager boost` to apply boosts manually, or they are applied automatically when calling `queue-manager next`.

## Task Categories

Categories are used for batch grouping:

- `security` - Security-related tasks
- `backend` - Server-side implementation
- `frontend` - UI/UX implementation
- `testing` - Test writing and maintenance
- `documentation` - Documentation tasks
- `devops` - Infrastructure and deployment
- `refactoring` - Code quality improvements
- `bugfix` - Bug fixes
- `feature` - New features
- `other` - Uncategorized (default)

## Commands Reference

### Add Task

```bash
queue-manager add <description> [options]

Options:
  -p, --priority    P0|P1|P2|P3|CRITICAL|HIGH|MEDIUM|LOW (default: P2)
  -c, --category    Task category (default: other)
  -t, --tags        Space-separated tags
  -d, --dependencies  Task IDs this task depends on
  -a, --agent       Assigned AI agent (claude|codex|gemini)
  -v, --verifier    Verifier AI agent (different from assigned)

Examples:
  queue-manager add "Implement OAuth2 PKCE" -p P1 -c security -a claude -v gemini
  queue-manager add "Add tests for auth module" -p P2 -c testing -t auth tests unit
```

### List Tasks

```bash
queue-manager list [options]

Options:
  -s, --status      Filter by status (pending|running|completed|failed)
  -p, --priority    Filter by priority (P0|P1|P2|P3)
  -l, --limit       Maximum tasks to show (default: 50)
  -V, --verbose     Show additional columns (boosts, retries)
  --json            Output as JSON

Examples:
  queue-manager list -s pending -p P0
  queue-manager list --verbose
  queue-manager list --json | jq '.[] | select(.category == "security")'
```

### Get Next Task

```bash
queue-manager next

Returns the highest priority pending task.
Automatically applies age-based boosts before selection.
```

### Start Task

```bash
queue-manager start <task_id> [options]

Options:
  -a, --agent       Agent working on the task

Example:
  queue-manager start task_1769000285_1660103 -a claude
```

### Complete Task

```bash
queue-manager complete <task_id> [--failed]

Options:
  --failed          Mark as failed instead of completed

Examples:
  queue-manager complete task_123456_789
  queue-manager fail task_123456_789  # Alias for --failed
```

### Retry Failed Task

```bash
queue-manager retry <task_id>

Re-queues a failed task (up to max_retries, default 3).
```

### Change Priority

```bash
queue-manager priority <task_id> <new_priority>

Example:
  queue-manager priority task_123456_789 P0
```

### Apply Age Boosts

```bash
queue-manager boost

Applies age-based priority promotions to all pending tasks.
Returns count of boosted tasks.
```

### Create Batch

```bash
queue-manager batch [--export]

Groups similar tasks (same category + priority) into batches.
Maximum 10 tasks per batch.

Options:
  --export          Export batch to file in task-queue/pending/
```

### View Statistics

```bash
queue-manager stats [options]

Options:
  --json            Output as JSON
  --save            Save metrics snapshot to database

Example output:
  === Queue Statistics ===
  Queue Size: 286

  By Status:
    Pending:   250
    Running:   15
    Completed: 18
    Failed:    3

  By Priority (Pending):
    P0-CRITICAL: 5
    P1-HIGH:     42
    P2-MEDIUM:   168
    P3-LOW:      35

  Boosted Tasks:      12
  Avg Wait Time:      3247.5s
  Oldest Pending Age: 48.3h
```

### Import Tasks

```bash
queue-manager import <file>

Imports tasks from batch file format:
  **Task N [task_id]:** Description
```

### Get Task Details

```bash
queue-manager get <task_id> [--json]
```

### Delete Task

```bash
queue-manager delete <task_id>
queue-manager rm <task_id>  # Alias
```

### Watch Mode (Shell Only)

```bash
queue-manager watch [interval_seconds]

Live-updating display of queue status. Default refresh: 5 seconds.
Press Ctrl+C to stop.
```

### Daemon Mode (Shell Only)

```bash
queue-manager daemon

Runs as background processor:
- Applies age boosts every 60 seconds
- Logs available tasks
- Saves metrics periodically
```

## Database Schema

### tasks table

```sql
CREATE TABLE tasks (
    task_id TEXT PRIMARY KEY,
    priority INTEGER NOT NULL,
    original_priority INTEGER,
    description TEXT NOT NULL,
    category TEXT DEFAULT 'other',
    status TEXT DEFAULT 'pending',
    assigned_agent TEXT,
    verifier_agent TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    started_at TEXT,
    completed_at TEXT,
    boost_count INTEGER DEFAULT 0,
    batch_id TEXT,
    metadata TEXT DEFAULT '{}',
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    dependencies TEXT DEFAULT '[]',
    tags TEXT DEFAULT '[]'
);
```

### Indexes

```sql
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_priority ON tasks(priority, created_at);
CREATE INDEX idx_tasks_category ON tasks(category);
CREATE INDEX idx_tasks_batch ON tasks(batch_id);
```

### History Tracking

```sql
CREATE TABLE task_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id TEXT NOT NULL,
    action TEXT NOT NULL,
    old_value TEXT,
    new_value TEXT,
    timestamp TEXT NOT NULL
);
```

### Metrics Snapshots

```sql
CREATE TABLE queue_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    total_tasks INTEGER,
    pending_tasks INTEGER,
    running_tasks INTEGER,
    completed_tasks INTEGER,
    failed_tasks INTEGER,
    p0_count INTEGER,
    p1_count INTEGER,
    p2_count INTEGER,
    p3_count INTEGER,
    avg_wait_time_seconds REAL,
    boosted_tasks INTEGER
);
```

## Integration with Tri-Agent Workflow

### Task Assignment Pattern

```bash
# Claude handles security and architecture
queue-manager add "Security audit for auth module" -p P0 -c security -a claude -v gemini

# Codex handles implementation and testing
queue-manager add "Implement retry logic" -p P2 -c backend -a codex -v claude

# Gemini handles documentation and review
queue-manager add "Update API documentation" -p P3 -c documentation -a gemini -v codex
```

### Batch Processing for Parallel Agents

```bash
# Create batches by category
queue-manager batch --export

# Each batch file can be assigned to a different agent
# Files are exported to: ~/.claude/task-queue/pending/batch_*.txt
```

### Status Mapping

| Queue Status | Tri-Agent Status |
| ------------ | ---------------- |
| pending      | Pending          |
| running      | In Progress      |
| completed    | Completed        |
| failed       | Failed           |
| blocked      | Blocked          |

## Programmatic Usage (Python)

```python
from queue_manager import QueueManager, Priority, TaskCategory

# Initialize
manager = QueueManager()

# Add task
task = manager.add_task(
    description="Implement feature X",
    priority="P1",
    category="backend",
    assigned_agent="codex",
    verifier_agent="claude",
    tags=["api", "auth"],
)

# Process queue
while True:
    task = manager.get_next_task()
    if not task:
        break

    # Start task
    manager.start_task(task.task_id, agent="claude")

    # Do work...

    # Complete task
    manager.complete_task(task.task_id, success=True)

# Get statistics
stats = manager.get_stats()
print(f"Pending: {stats['pending_count']}")
print(f"Completed: {stats['completed_count']}")
```

## Configuration

Age boost thresholds can be modified in the script:

```python
AGE_BOOST_THRESHOLDS = {
    "P3_to_P2": 4,   # hours
    "P2_to_P1": 8,   # hours
    "P1_to_P0": 24,  # hours
}

BATCH_SIZE_LIMIT = 10  # tasks per batch
```

## Monitoring

### Cron Job for Regular Boosts

```bash
# Add to crontab: crontab -e
# Run every hour
0 * * * * ~/.claude/scripts/queue-manager.py boost >> ~/.claude/logs/queue-boost.log 2>&1

# Save metrics every 30 minutes
*/30 * * * * ~/.claude/scripts/queue-manager.py stats --save >/dev/null 2>&1
```

### Query Metrics History

```bash
sqlite3 ~/.claude/task-queue/queue.db "
SELECT timestamp, pending_tasks, p0_count, avg_wait_time_seconds
FROM queue_metrics
ORDER BY timestamp DESC
LIMIT 10;
"
```

## Troubleshooting

### Database Locked

```bash
# Check for stale connections
fuser ~/.claude/task-queue/queue.db

# Vacuum and checkpoint
sqlite3 ~/.claude/task-queue/queue.db "PRAGMA wal_checkpoint(TRUNCATE); VACUUM;"
```

### Reset Queue

```bash
# Delete database (WARNING: loses all data)
rm ~/.claude/task-queue/queue.db

# Or just clear pending tasks
sqlite3 ~/.claude/task-queue/queue.db "DELETE FROM tasks WHERE status = 'pending';"
```

### View Task History

```bash
sqlite3 ~/.claude/task-queue/queue.db "
SELECT task_id, action, old_value, new_value, timestamp
FROM task_history
WHERE task_id = 'task_123456_789'
ORDER BY timestamp;
"
```

---

Author: Ahmed Adel Bakr Alderai
