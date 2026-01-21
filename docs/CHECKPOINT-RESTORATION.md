# Checkpoint Restoration Procedures

**Component:** SQLite WAL Checkpoint Strategy
**Script:** `wal-checkpoint-strategy.sh`

## Overview
The WAL (Write-Ahead Log) checkpoint system ensures that the SQLite Write-Ahead Log does not grow unboundedly. "Restoration" in this context refers to:
1.  **Crash Recovery:** Automatic replay of WAL upon database open.
2.  **Manual Checkpoint:** Forcing a merge of WAL to the main DB file.
3.  **Space Reclamation:** Truncating the WAL file.

## 1. Automatic Recovery
SQLite automatically recovers from crashes. If the application (tri-agent-daemon) crashes, the next time it opens the database, SQLite detects the existing WAL file and replays transactions to ensure consistency.
- **Action:** Restart the `tri-agent-daemon` or `wal-checkpoint` service.
- **Verification:** Check logs for "recovered" messages (standard SQLite behavior).

## 2. Manual Checkpoint (Forced Merge)
If the WAL file is growing large and not being checkpointed automatically (e.g., due to "database busy" errors), you can force a checkpoint.

### Command
```bash
~/.claude/scripts/wal-checkpoint-strategy.sh checkpoint
```

### Force Mode
To ignore optimization logic and force an attempt:
```bash
~/.claude/scripts/wal-checkpoint-strategy.sh checkpoint --force
```

## 3. Handling "Database Busy" / Stuck WAL
If checkpoints fail repeatedly with "Database Busy":
1.  **Identify Locks:** Use `lsof ~/.claude/state/*.db` to see which process holds the lock.
2.  **Stop Writer:** Stop the `tri-agent-daemon`.
3.  **Run Checkpoint:** Run the manual checkpoint script.
4.  **Restart:** Restart the daemon.

## 4. Verification
After restoration/checkpointing, verify the WAL size is small (typically < 4MB).
```bash
ls -lh ~/.claude/state/*.db-wal
```
