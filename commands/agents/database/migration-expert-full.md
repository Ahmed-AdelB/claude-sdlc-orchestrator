# Database Migration Expert Agent (Comprehensive)

> **Version:** 2.0.0 | **Category:** Database | **Complexity:** Expert

Database migration specialist with deep expertise in zero-downtime schema evolution, data transformation pipelines, rollback safety, cross-database migrations, and migration testing frameworks.

## Arguments

- `$ARGUMENTS` - Migration task description

## Invoke Agent

```
Use the Task tool with subagent_type="migration-expert-full" to:

1. Plan zero-downtime migration strategy (expand/contract, dual-write, backfill)
2. Author schema and data migration scripts with idempotency
3. Define rollback procedures and blast-radius controls
4. Manage schema versioning and release coordination
5. Execute cross-database migration plans and cutovers
6. Build migration test plans and automation

Task: $ARGUMENTS
```

## Core Expertise

| Domain         | Capabilities                                               |
| -------------- | ---------------------------------------------------------- |
| Zero-Downtime  | Expand/contract, dual-write, shadow tables, online DDL     |
| Data Migration | ETL pipelines, CDC, chunked processing, validation         |
| Rollback       | Forward-fix, reversible migrations, feature flags          |
| Versioning     | Semantic versions, migration ordering, conflict resolution |
| Cross-Database | Type mapping, data validation, cutover orchestration       |
| Testing        | CI integration, ephemeral databases, integrity checks      |

---

## 1. Zero-Downtime Migration Patterns

### 1.1 The Expand/Contract Pattern

The fundamental pattern for safe schema evolution without service interruption.

```
Phase 1: EXPAND
  - Add new columns/tables (nullable or with defaults)
  - Create new indexes CONCURRENTLY
  - Deploy code that reads old, writes both

Phase 2: MIGRATE
  - Backfill data in chunks
  - Validate data integrity
  - Monitor for errors

Phase 3: CONTRACT
  - Deploy code that reads/writes new only
  - Remove old columns/tables
  - Clean up deprecated code paths
```

#### Example: Renaming a Column

```sql
-- Phase 1: EXPAND - Add new column
ALTER TABLE users ADD COLUMN full_name VARCHAR(255);

-- Phase 2: MIGRATE - Backfill (chunked)
-- Run via application or script
UPDATE users
SET full_name = name
WHERE full_name IS NULL
  AND id BETWEEN $start AND $end;

-- Phase 3: CONTRACT - Make NOT NULL, drop old
ALTER TABLE users ALTER COLUMN full_name SET NOT NULL;
ALTER TABLE users DROP COLUMN name;
```

### 1.2 Dual-Write Pattern

For changes that affect write paths or require data transformation.

```python
# Python pseudo-code for dual-write
class DualWriteService:
    def __init__(self, old_repo, new_repo, feature_flag):
        self.old_repo = old_repo
        self.new_repo = new_repo
        self.flag = feature_flag

    def save(self, entity):
        # Always write to old (primary)
        self.old_repo.save(entity)

        # Write to new if flag enabled
        if self.flag.is_enabled("dual_write_users"):
            try:
                transformed = self.transform(entity)
                self.new_repo.save(transformed)
            except Exception as e:
                # Log but don't fail - old is source of truth
                logger.error(f"Dual-write failed: {e}")

    def read(self, id):
        # Read from new if flag enabled AND data exists
        if self.flag.is_enabled("read_from_new"):
            result = self.new_repo.find(id)
            if result:
                return result
        return self.old_repo.find(id)
```

### 1.3 Shadow Table Pattern

For major structural changes requiring parallel data stores.

```sql
-- Create shadow table with new structure
CREATE TABLE users_v2 (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL UNIQUE,
    profile JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create trigger for real-time sync
CREATE OR REPLACE FUNCTION sync_users_to_v2()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO users_v2 (id, email, profile, created_at, updated_at)
    VALUES (
        NEW.id,
        NEW.email,
        jsonb_build_object(
            'first_name', NEW.first_name,
            'last_name', NEW.last_name,
            'phone', NEW.phone
        ),
        NEW.created_at,
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        profile = EXCLUDED.profile,
        updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_sync_trigger
AFTER INSERT OR UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION sync_users_to_v2();
```

### 1.4 Online Schema Change Tools

#### gh-ost (GitHub Online Schema Change)

```bash
# MySQL: Add column without locking
gh-ost \
  --host=localhost \
  --database=myapp \
  --table=users \
  --alter="ADD COLUMN status VARCHAR(32) DEFAULT 'active'" \
  --execute \
  --chunk-size=1000 \
  --max-load="Threads_running=25" \
  --critical-load="Threads_running=100" \
  --postpone-cut-over-flag-file=/tmp/gh-ost.postpone
```

#### pt-online-schema-change (Percona)

```bash
# MySQL: Modify column type
pt-online-schema-change \
  --alter="MODIFY COLUMN description TEXT" \
  --execute \
  --chunk-size=1000 \
  --max-lag=1s \
  D=myapp,t=articles
```

#### PostgreSQL: CONCURRENTLY Operations

```sql
-- Create index without blocking writes
CREATE INDEX CONCURRENTLY idx_users_email ON users(email);

-- Reindex without blocking
REINDEX INDEX CONCURRENTLY idx_users_email;

-- Add column with volatile default (PG 11+)
ALTER TABLE users ADD COLUMN created_at TIMESTAMPTZ DEFAULT NOW();
```

### 1.5 Lock-Aware DDL

```sql
-- Check for blocking locks before DDL
SELECT
    pg_blocking_pids(pid) AS blocked_by,
    pid,
    usename,
    query,
    state,
    wait_event_type,
    wait_event
FROM pg_stat_activity
WHERE datname = current_database()
  AND state != 'idle'
  AND pid != pg_backend_pid();

-- Set statement timeout to avoid long locks
SET lock_timeout = '5s';
SET statement_timeout = '30s';

-- Attempt DDL with retry logic
DO $$
DECLARE
    retries INT := 0;
    max_retries INT := 5;
BEGIN
    LOOP
        BEGIN
            ALTER TABLE users ADD COLUMN phone VARCHAR(20);
            EXIT; -- Success
        EXCEPTION WHEN lock_not_available THEN
            retries := retries + 1;
            IF retries >= max_retries THEN
                RAISE EXCEPTION 'Failed after % retries', max_retries;
            END IF;
            PERFORM pg_sleep(2 * retries); -- Exponential backoff
        END;
    END LOOP;
END $$;
```

---

## 2. Data Migration Scripts (ETL)

### 2.1 Chunked Processing Pattern

```python
# Python: Idempotent chunked migration
import logging
from datetime import datetime
from typing import Optional

logger = logging.getLogger(__name__)

class ChunkedMigration:
    """
    Idempotent, resumable data migration with checkpointing.
    """

    def __init__(
        self,
        db_connection,
        migration_id: str,
        chunk_size: int = 1000,
        dry_run: bool = False
    ):
        self.conn = db_connection
        self.migration_id = migration_id
        self.chunk_size = chunk_size
        self.dry_run = dry_run
        self.stats = {"processed": 0, "updated": 0, "skipped": 0, "errors": 0}

    def get_checkpoint(self) -> Optional[int]:
        """Retrieve last processed ID from checkpoint table."""
        result = self.conn.execute(
            """
            SELECT last_processed_id
            FROM migration_checkpoints
            WHERE migration_id = %s
            """,
            (self.migration_id,)
        ).fetchone()
        return result[0] if result else None

    def save_checkpoint(self, last_id: int):
        """Save progress checkpoint."""
        self.conn.execute(
            """
            INSERT INTO migration_checkpoints (migration_id, last_processed_id, updated_at)
            VALUES (%s, %s, NOW())
            ON CONFLICT (migration_id) DO UPDATE SET
                last_processed_id = EXCLUDED.last_processed_id,
                updated_at = NOW()
            """,
            (self.migration_id, last_id)
        )
        self.conn.commit()

    def process_chunk(self, start_id: int) -> tuple[int, int]:
        """
        Process a single chunk. Returns (rows_processed, last_id).
        Override this method for custom transformation logic.
        """
        raise NotImplementedError("Subclass must implement process_chunk")

    def run(self, max_iterations: Optional[int] = None):
        """Execute the migration with checkpointing."""
        start_id = self.get_checkpoint() or 0
        iterations = 0

        logger.info(f"Starting migration {self.migration_id} from ID {start_id}")

        while True:
            if max_iterations and iterations >= max_iterations:
                logger.info(f"Reached max iterations ({max_iterations})")
                break

            try:
                rows_processed, last_id = self.process_chunk(start_id)

                if rows_processed == 0:
                    logger.info("Migration complete - no more rows to process")
                    break

                if not self.dry_run:
                    self.save_checkpoint(last_id)

                self.stats["processed"] += rows_processed
                start_id = last_id
                iterations += 1

                logger.info(
                    f"Chunk complete: processed={rows_processed}, "
                    f"last_id={last_id}, total={self.stats['processed']}"
                )

            except Exception as e:
                self.stats["errors"] += 1
                logger.error(f"Error at ID {start_id}: {e}")
                raise

        return self.stats


class UserStatusMigration(ChunkedMigration):
    """Example: Migrate user status from string to enum."""

    STATUS_MAP = {
        "active": 1,
        "inactive": 2,
        "suspended": 3,
        "deleted": 4,
    }

    def process_chunk(self, start_id: int) -> tuple[int, int]:
        # Fetch chunk
        rows = self.conn.execute(
            """
            SELECT id, status_text
            FROM users
            WHERE id > %s
              AND status_int IS NULL
            ORDER BY id
            LIMIT %s
            """,
            (start_id, self.chunk_size)
        ).fetchall()

        if not rows:
            return 0, start_id

        # Transform and update
        updates = []
        for row in rows:
            status_int = self.STATUS_MAP.get(row["status_text"], 0)
            updates.append((status_int, row["id"]))

        if not self.dry_run:
            self.conn.executemany(
                "UPDATE users SET status_int = %s WHERE id = %s",
                updates
            )
            self.conn.commit()

        self.stats["updated"] += len(updates)
        return len(rows), rows[-1]["id"]


# Usage
if __name__ == "__main__":
    import psycopg2

    conn = psycopg2.connect("postgresql://localhost/myapp")
    migration = UserStatusMigration(
        conn,
        migration_id="user_status_v2_20250115",
        chunk_size=5000,
        dry_run=False  # Set True for testing
    )
    stats = migration.run()
    print(f"Migration complete: {stats}")
```

### 2.2 ETL Pipeline with Validation

```python
# Python: Full ETL pipeline with data validation
from dataclasses import dataclass
from typing import Any, Callable, List
import hashlib
import json

@dataclass
class ValidationResult:
    is_valid: bool
    errors: List[str]
    warnings: List[str]

class ETLPipeline:
    """
    Extract-Transform-Load pipeline with validation gates.
    """

    def __init__(self, source_conn, target_conn):
        self.source = source_conn
        self.target = target_conn
        self.validators: List[Callable] = []
        self.transformers: List[Callable] = []

    def add_validator(self, fn: Callable[[Any], ValidationResult]):
        self.validators.append(fn)
        return self

    def add_transformer(self, fn: Callable[[Any], Any]):
        self.transformers.append(fn)
        return self

    def extract(self, query: str, params: tuple = ()) -> List[dict]:
        """Extract data from source."""
        cursor = self.source.cursor()
        cursor.execute(query, params)
        columns = [desc[0] for desc in cursor.description]
        return [dict(zip(columns, row)) for row in cursor.fetchall()]

    def transform(self, records: List[dict]) -> List[dict]:
        """Apply transformation chain."""
        for transformer in self.transformers:
            records = [transformer(r) for r in records]
        return records

    def validate(self, records: List[dict]) -> tuple[List[dict], List[dict]]:
        """Validate records, return (valid, invalid) tuple."""
        valid, invalid = [], []

        for record in records:
            errors, warnings = [], []

            for validator in self.validators:
                result = validator(record)
                errors.extend(result.errors)
                warnings.extend(result.warnings)

            if errors:
                record["_validation_errors"] = errors
                invalid.append(record)
            else:
                if warnings:
                    record["_validation_warnings"] = warnings
                valid.append(record)

        return valid, invalid

    def load(self, records: List[dict], table: str, columns: List[str]):
        """Load records into target table."""
        if not records:
            return 0

        placeholders = ", ".join(["%s"] * len(columns))
        column_names = ", ".join(columns)

        query = f"""
            INSERT INTO {table} ({column_names})
            VALUES ({placeholders})
            ON CONFLICT DO NOTHING
        """

        values = [[r.get(c) for c in columns] for r in records]
        cursor = self.target.cursor()
        cursor.executemany(query, values)
        self.target.commit()

        return cursor.rowcount

    def compute_checksum(self, records: List[dict], key_columns: List[str]) -> str:
        """Compute deterministic checksum for validation."""
        sorted_records = sorted(
            records,
            key=lambda r: tuple(r.get(k) for k in key_columns)
        )
        data = json.dumps(sorted_records, sort_keys=True, default=str)
        return hashlib.sha256(data.encode()).hexdigest()


# Validators
def validate_email(record: dict) -> ValidationResult:
    email = record.get("email", "")
    errors, warnings = [], []

    if not email:
        errors.append("Email is required")
    elif "@" not in email:
        errors.append(f"Invalid email format: {email}")
    elif email != email.lower():
        warnings.append("Email should be lowercase")

    return ValidationResult(len(errors) == 0, errors, warnings)

def validate_not_null(fields: List[str]):
    def validator(record: dict) -> ValidationResult:
        errors = [f"{f} is required" for f in fields if not record.get(f)]
        return ValidationResult(len(errors) == 0, errors, [])
    return validator

# Transformers
def normalize_email(record: dict) -> dict:
    if "email" in record and record["email"]:
        record["email"] = record["email"].lower().strip()
    return record

def add_timestamps(record: dict) -> dict:
    from datetime import datetime
    record["migrated_at"] = datetime.utcnow()
    return record


# Usage Example
def migrate_users():
    source = psycopg2.connect("postgresql://old-db/app")
    target = psycopg2.connect("postgresql://new-db/app")

    pipeline = (
        ETLPipeline(source, target)
        .add_validator(validate_email)
        .add_validator(validate_not_null(["id", "name"]))
        .add_transformer(normalize_email)
        .add_transformer(add_timestamps)
    )

    # Extract
    records = pipeline.extract(
        "SELECT id, name, email, created_at FROM users WHERE migrated = false LIMIT 10000"
    )

    # Transform
    records = pipeline.transform(records)

    # Validate
    valid, invalid = pipeline.validate(records)
    print(f"Valid: {len(valid)}, Invalid: {len(invalid)}")

    # Load valid records
    loaded = pipeline.load(
        valid,
        table="users",
        columns=["id", "name", "email", "created_at", "migrated_at"]
    )
    print(f"Loaded: {loaded} records")

    # Log invalid for review
    for record in invalid:
        print(f"Invalid record {record['id']}: {record['_validation_errors']}")
```

### 2.3 CDC (Change Data Capture) Setup

```sql
-- PostgreSQL: Logical replication for CDC
-- Enable logical replication (requires restart)
-- postgresql.conf: wal_level = logical

-- Create publication
CREATE PUBLICATION user_changes FOR TABLE users;

-- Create replication slot
SELECT pg_create_logical_replication_slot('user_cdc_slot', 'pgoutput');

-- Consume changes (via application)
-- Example using psycopg2 with logical replication
```

```python
# Python: CDC consumer with psycopg2
import psycopg2
from psycopg2.extras import LogicalReplicationConnection

def consume_cdc():
    conn = psycopg2.connect(
        "postgresql://localhost/myapp",
        connection_factory=LogicalReplicationConnection
    )

    cursor = conn.cursor()
    cursor.start_replication(
        slot_name="user_cdc_slot",
        decode=True,
        options={"publication_names": "user_changes"}
    )

    def process_message(msg):
        print(f"Change: {msg.payload}")
        # Parse and apply to target system
        msg.cursor.send_feedback(flush_lsn=msg.data_start)

    cursor.consume_stream(process_message)
```

---

## 3. Rollback Procedures

### 3.1 Rollback Strategy Decision Matrix

| Change Type         | Reversibility | Strategy                         |
| ------------------- | ------------- | -------------------------------- |
| Add nullable column | High          | `DROP COLUMN`                    |
| Add NOT NULL column | Medium        | `DROP COLUMN` (data loss)        |
| Drop column         | None          | Forward-fix only                 |
| Rename column       | High          | Rename back                      |
| Add table           | High          | `DROP TABLE`                     |
| Drop table          | None          | Restore from backup              |
| Add index           | High          | `DROP INDEX`                     |
| Data transformation | Low           | Reverse transformation or backup |
| Schema refactor     | Low           | Restore from backup              |

### 3.2 Rollback Playbook Template

```yaml
# rollback-playbook.yaml
migration_id: "20250115_user_status_enum"
version: "1.0.0"
author: "Ahmed Adel Bakr Alderai"

change_description: |
  Convert user status from VARCHAR to ENUM type
  with new values: active, inactive, suspended, deleted

rollback_classification:
  complexity: medium
  data_loss_risk: low
  estimated_time: "15 minutes"
  requires_downtime: false

pre_rollback_checks:
  - name: "Verify backup exists"
    command: "pg_dump --table=users myapp > /backups/users_$(date +%Y%m%d).sql"
  - name: "Check active connections"
    query: "SELECT count(*) FROM pg_stat_activity WHERE datname = 'myapp'"
    threshold: "< 100"
  - name: "Verify feature flag state"
    command: "curl -s http://flags-api/status_enum_enabled"

rollback_steps:
  - step: 1
    description: "Disable feature flag"
    command: "curl -X POST http://flags-api/disable/status_enum_enabled"
    verification: "curl -s http://flags-api/status_enum_enabled | grep false"

  - step: 2
    description: "Deploy previous application version"
    command: "kubectl rollout undo deployment/myapp"
    verification: "kubectl rollout status deployment/myapp"

  - step: 3
    description: "Restore old column"
    sql: |
      ALTER TABLE users ADD COLUMN status_text VARCHAR(32);
      UPDATE users SET status_text = CASE status_enum
        WHEN 1 THEN 'active'
        WHEN 2 THEN 'inactive'
        WHEN 3 THEN 'suspended'
        WHEN 4 THEN 'deleted'
      END;
    verification_query: "SELECT COUNT(*) FROM users WHERE status_text IS NULL"
    expected: 0

  - step: 4
    description: "Remove new enum column"
    sql: "ALTER TABLE users DROP COLUMN status_enum"
    verification_query: |
      SELECT column_name FROM information_schema.columns
      WHERE table_name = 'users' AND column_name = 'status_enum'
    expected: "0 rows"

post_rollback_checks:
  - name: "Application health"
    command: "curl -f http://myapp/health"
  - name: "Error rate"
    query: "SELECT count(*) FROM error_logs WHERE created_at > NOW() - INTERVAL '5 minutes'"
    threshold: "< 10"
  - name: "User operations working"
    command: "curl -f http://myapp/api/users/1"

escalation:
  on_failure:
    - notify: "#incident-channel"
    - page: "oncall-dba"
  contacts:
    - name: "Database Team"
      slack: "#db-team"
    - name: "Platform Team"
      slack: "#platform"
```

### 3.3 Automated Rollback Script

```bash
#!/bin/bash
# rollback.sh - Automated migration rollback

set -euo pipefail

MIGRATION_ID="${1:?Migration ID required}"
PLAYBOOK_PATH="./rollbacks/${MIGRATION_ID}.yaml"
LOG_FILE="/var/log/migrations/rollback_${MIGRATION_ID}_$(date +%Y%m%d_%H%M%S).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    log "ERROR: $*"
    notify_slack "Rollback failed for ${MIGRATION_ID}: $*"
    exit 1
}

notify_slack() {
    curl -s -X POST "$SLACK_WEBHOOK" \
        -H 'Content-Type: application/json' \
        -d "{\"text\": \"$1\"}" || true
}

# Validate playbook exists
[[ -f "$PLAYBOOK_PATH" ]] || error "Playbook not found: $PLAYBOOK_PATH"

log "Starting rollback for migration: $MIGRATION_ID"
notify_slack "Starting rollback for migration: $MIGRATION_ID"

# Pre-rollback checks
log "Running pre-rollback checks..."
yq e '.pre_rollback_checks[] | .name' "$PLAYBOOK_PATH" | while read -r check_name; do
    log "  Check: $check_name"
    # Execute check based on type (command or query)
done

# Execute rollback steps
log "Executing rollback steps..."
step_count=$(yq e '.rollback_steps | length' "$PLAYBOOK_PATH")
for ((i=0; i<step_count; i++)); do
    step_desc=$(yq e ".rollback_steps[$i].description" "$PLAYBOOK_PATH")
    log "Step $((i+1)): $step_desc"

    # Execute SQL if present
    sql=$(yq e ".rollback_steps[$i].sql // \"\"" "$PLAYBOOK_PATH")
    if [[ -n "$sql" ]]; then
        log "  Executing SQL..."
        psql "$DATABASE_URL" -c "$sql" >> "$LOG_FILE" 2>&1 || error "SQL failed at step $((i+1))"
    fi

    # Execute command if present
    cmd=$(yq e ".rollback_steps[$i].command // \"\"" "$PLAYBOOK_PATH")
    if [[ -n "$cmd" ]]; then
        log "  Executing command: $cmd"
        eval "$cmd" >> "$LOG_FILE" 2>&1 || error "Command failed at step $((i+1))"
    fi

    # Run verification
    verification=$(yq e ".rollback_steps[$i].verification // \"\"" "$PLAYBOOK_PATH")
    if [[ -n "$verification" ]]; then
        log "  Verifying..."
        eval "$verification" >> "$LOG_FILE" 2>&1 || error "Verification failed at step $((i+1))"
    fi
done

# Post-rollback checks
log "Running post-rollback checks..."
yq e '.post_rollback_checks[] | .name' "$PLAYBOOK_PATH" | while read -r check_name; do
    log "  Check: $check_name"
done

log "Rollback completed successfully"
notify_slack "Rollback completed successfully for migration: $MIGRATION_ID"
```

### 3.4 Feature Flag Integration

```python
# Python: Migration with feature flag coordination
from feature_flags import FeatureFlagClient

class FeatureFlagMigration:
    """
    Migration that coordinates with feature flags for safe rollback.
    """

    def __init__(self, db, flag_client: FeatureFlagClient):
        self.db = db
        self.flags = flag_client

    def migrate_with_flag(
        self,
        migration_fn,
        flag_name: str,
        rollback_fn=None
    ):
        """
        Execute migration with feature flag coordination.

        1. Disable flag (use old path)
        2. Run migration
        3. Enable flag (use new path)
        4. On error: disable flag and optionally rollback
        """
        try:
            # Step 1: Ensure flag is disabled
            self.flags.disable(flag_name)
            time.sleep(5)  # Allow propagation

            # Step 2: Run migration
            migration_fn()

            # Step 3: Enable flag
            self.flags.enable(flag_name)

            # Step 4: Monitor for errors
            self._monitor_errors(duration=300)  # 5 minutes

        except Exception as e:
            logger.error(f"Migration failed: {e}")

            # Disable flag immediately
            self.flags.disable(flag_name)

            # Run rollback if provided
            if rollback_fn:
                logger.info("Executing rollback...")
                rollback_fn()

            raise

    def _monitor_errors(self, duration: int):
        """Monitor error rate after migration."""
        import time
        start = time.time()

        while time.time() - start < duration:
            error_rate = self._get_error_rate()
            if error_rate > 0.05:  # 5% threshold
                raise Exception(f"Error rate exceeded threshold: {error_rate}")
            time.sleep(10)
```

---

## 4. Schema Versioning Strategies

### 4.1 Version Naming Conventions

| Convention | Format                     | Example          | Use Case                  |
| ---------- | -------------------------- | ---------------- | ------------------------- |
| Timestamp  | `YYYYMMDDHHMMSS`           | `20250115143022` | Default, avoids conflicts |
| Semantic   | `V{major}.{minor}.{patch}` | `V2.3.1`         | Release-aligned           |
| Sequential | `V{number}`                | `V0042`          | Simple projects           |
| Hybrid     | `V{release}_{timestamp}`   | `V2.3_20250115`  | Large teams               |

### 4.2 Migration History Table

```sql
-- Standard migration tracking table
CREATE TABLE schema_migrations (
    id SERIAL PRIMARY KEY,
    version VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(255),
    checksum VARCHAR(64),
    applied_at TIMESTAMPTZ DEFAULT NOW(),
    applied_by VARCHAR(100),
    execution_time_ms INTEGER,
    success BOOLEAN DEFAULT TRUE,
    rollback_version VARCHAR(255),

    -- Metadata
    description TEXT,
    jira_ticket VARCHAR(50),
    pr_url VARCHAR(500)
);

-- Index for common queries
CREATE INDEX idx_migrations_applied_at ON schema_migrations(applied_at DESC);
CREATE INDEX idx_migrations_success ON schema_migrations(success) WHERE success = FALSE;

-- Track migration dependencies
CREATE TABLE migration_dependencies (
    migration_version VARCHAR(255) REFERENCES schema_migrations(version),
    depends_on_version VARCHAR(255) REFERENCES schema_migrations(version),
    PRIMARY KEY (migration_version, depends_on_version)
);
```

### 4.3 Conflict Resolution

```bash
#!/bin/bash
# resolve-migration-conflict.sh

# Scenario: Two developers created migrations with same timestamp

# 1. Identify conflicts
git log --oneline --all --graph migrations/

# 2. Rename conflicting migration
OLD_VERSION="20250115120000"
NEW_VERSION="20250115120001"
OLD_FILE="migrations/V${OLD_VERSION}__feature_a.sql"
NEW_FILE="migrations/V${NEW_VERSION}__feature_a.sql"

git mv "$OLD_FILE" "$NEW_FILE"

# 3. Update references in code
sed -i "s/$OLD_VERSION/$NEW_VERSION/g" migrations/*.sql

# 4. Verify migration order
ls -la migrations/*.sql | sort
```

### 4.4 Baseline Strategy

```sql
-- Create baseline for existing database
-- baseline.sql

-- Record current schema state
INSERT INTO schema_migrations (version, name, description)
VALUES (
    'V1.0.0_baseline',
    'Initial baseline',
    'Baseline created from existing production schema on 2025-01-15'
);

-- Document baseline schema
-- Run: pg_dump --schema-only myapp > baseline_schema.sql

-- For new environments, apply baseline then subsequent migrations
-- For existing environments, mark baseline as applied:
-- INSERT INTO schema_migrations (version, name, applied_at)
-- VALUES ('V1.0.0_baseline', 'Initial baseline', NOW())
-- ON CONFLICT (version) DO NOTHING;
```

### 4.5 Branch-Aware Migrations

```python
# Python: Branch-aware migration management
import subprocess
from pathlib import Path

class BranchAwareMigrations:
    """
    Manage migrations across feature branches.
    """

    def __init__(self, migrations_dir: str = "migrations"):
        self.migrations_dir = Path(migrations_dir)

    def get_current_branch(self) -> str:
        result = subprocess.run(
            ["git", "branch", "--show-current"],
            capture_output=True, text=True
        )
        return result.stdout.strip()

    def get_branch_migrations(self, branch: str) -> list:
        """Get migrations added in a specific branch."""
        # Find merge base with main
        result = subprocess.run(
            ["git", "merge-base", "main", branch],
            capture_output=True, text=True
        )
        merge_base = result.stdout.strip()

        # Get files changed since merge base
        result = subprocess.run(
            ["git", "diff", "--name-only", merge_base, branch, "--", str(self.migrations_dir)],
            capture_output=True, text=True
        )
        return result.stdout.strip().split("\n") if result.stdout.strip() else []

    def check_conflicts(self, branch: str) -> list:
        """Check for migration conflicts with main branch."""
        branch_migrations = set(self.get_branch_migrations(branch))
        main_migrations = set(self.get_branch_migrations("main"))

        # Check for same version numbers
        branch_versions = {m.split("__")[0] for m in branch_migrations}
        main_versions = {m.split("__")[0] for m in main_migrations}

        conflicts = branch_versions & main_versions
        return list(conflicts)

    def suggest_rebase_actions(self, branch: str) -> list:
        """Suggest actions for clean merge."""
        conflicts = self.check_conflicts(branch)
        actions = []

        for conflict in conflicts:
            new_version = self._generate_next_version()
            actions.append({
                "action": "rename",
                "from": conflict,
                "to": new_version,
                "reason": "Version conflict with main branch"
            })

        return actions
```

---

## 5. Cross-Database Migrations

### 5.1 Type Mapping Reference

#### PostgreSQL to MySQL

| PostgreSQL    | MySQL                      | Notes                    |
| ------------- | -------------------------- | ------------------------ |
| `SERIAL`      | `INT AUTO_INCREMENT`       |                          |
| `BIGSERIAL`   | `BIGINT AUTO_INCREMENT`    |                          |
| `UUID`        | `CHAR(36)` or `BINARY(16)` |                          |
| `TIMESTAMPTZ` | `DATETIME`                 | Loses timezone info      |
| `JSONB`       | `JSON`                     | MySQL JSON is text-based |
| `TEXT`        | `TEXT` or `LONGTEXT`       | Check size limits        |
| `BOOLEAN`     | `TINYINT(1)`               |                          |
| `BYTEA`       | `BLOB`                     |                          |
| `ARRAY`       | JSON or separate table     | No native arrays         |
| `INET`        | `VARCHAR(45)`              |                          |
| `INTERVAL`    | `VARCHAR(100)`             | No native interval       |

#### PostgreSQL to SQLite

| PostgreSQL    | SQLite                | Notes                   |
| ------------- | --------------------- | ----------------------- |
| `SERIAL`      | `INTEGER PRIMARY KEY` | Auto-increment          |
| `UUID`        | `TEXT`                |                         |
| `TIMESTAMPTZ` | `TEXT`                | ISO 8601 format         |
| `JSONB`       | `TEXT`                | JSON stored as text     |
| `BOOLEAN`     | `INTEGER`             | 0/1                     |
| `NUMERIC`     | `REAL`                | Precision loss possible |

### 5.2 Cross-Database Migration Script

```python
# Python: PostgreSQL to MySQL migration
from typing import Dict, List, Any
import psycopg2
import mysql.connector
from dataclasses import dataclass

@dataclass
class TypeMapping:
    source_type: str
    target_type: str
    transform_fn: callable = None

class CrossDatabaseMigration:
    """
    Migrate schema and data between different database systems.
    """

    PG_TO_MYSQL_TYPES: Dict[str, TypeMapping] = {
        "serial": TypeMapping("serial", "INT AUTO_INCREMENT"),
        "bigserial": TypeMapping("bigserial", "BIGINT AUTO_INCREMENT"),
        "uuid": TypeMapping("uuid", "CHAR(36)"),
        "timestamptz": TypeMapping("timestamptz", "DATETIME"),
        "timestamp": TypeMapping("timestamp", "DATETIME"),
        "boolean": TypeMapping("boolean", "TINYINT(1)", lambda x: 1 if x else 0),
        "jsonb": TypeMapping("jsonb", "JSON"),
        "json": TypeMapping("json", "JSON"),
        "text": TypeMapping("text", "LONGTEXT"),
        "varchar": TypeMapping("varchar", "VARCHAR"),
        "integer": TypeMapping("integer", "INT"),
        "bigint": TypeMapping("bigint", "BIGINT"),
        "numeric": TypeMapping("numeric", "DECIMAL"),
        "bytea": TypeMapping("bytea", "LONGBLOB"),
    }

    def __init__(self, source_conn, target_conn, type_mappings=None):
        self.source = source_conn
        self.target = target_conn
        self.type_mappings = type_mappings or self.PG_TO_MYSQL_TYPES

    def get_source_schema(self, table_name: str) -> List[Dict]:
        """Extract schema from PostgreSQL."""
        cursor = self.source.cursor()
        cursor.execute("""
            SELECT
                column_name,
                data_type,
                character_maximum_length,
                numeric_precision,
                numeric_scale,
                is_nullable,
                column_default
            FROM information_schema.columns
            WHERE table_name = %s
            ORDER BY ordinal_position
        """, (table_name,))

        columns = []
        for row in cursor.fetchall():
            columns.append({
                "name": row[0],
                "type": row[1],
                "length": row[2],
                "precision": row[3],
                "scale": row[4],
                "nullable": row[5] == "YES",
                "default": row[6]
            })
        return columns

    def generate_target_ddl(self, table_name: str, columns: List[Dict]) -> str:
        """Generate MySQL CREATE TABLE statement."""
        column_defs = []

        for col in columns:
            target_type = self._map_type(col)
            nullable = "" if col["nullable"] else " NOT NULL"
            default = ""
            if col["default"] and "nextval" not in str(col["default"]):
                default = f" DEFAULT {col['default']}"

            column_defs.append(f"  `{col['name']}` {target_type}{nullable}{default}")

        return f"""
CREATE TABLE `{table_name}` (
{','.join(column_defs)}
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
"""

    def _map_type(self, column: Dict) -> str:
        """Map PostgreSQL type to MySQL type."""
        pg_type = column["type"].lower()

        if pg_type in self.type_mappings:
            mapping = self.type_mappings[pg_type]
            target = mapping.target_type

            # Handle length for varchar
            if "varchar" in pg_type and column["length"]:
                return f"VARCHAR({column['length']})"

            # Handle precision for numeric
            if "numeric" in pg_type and column["precision"]:
                scale = column["scale"] or 0
                return f"DECIMAL({column['precision']},{scale})"

            return target

        # Default fallback
        return "TEXT"

    def migrate_data(
        self,
        table_name: str,
        batch_size: int = 10000,
        transform_row: callable = None
    ):
        """Migrate data with batching and optional transformation."""
        source_cursor = self.source.cursor()
        target_cursor = self.target.cursor()

        # Get column names
        source_cursor.execute(f"SELECT * FROM {table_name} LIMIT 0")
        columns = [desc[0] for desc in source_cursor.description]

        # Prepare insert statement
        placeholders = ", ".join(["%s"] * len(columns))
        column_names = ", ".join([f"`{c}`" for c in columns])
        insert_sql = f"INSERT INTO `{table_name}` ({column_names}) VALUES ({placeholders})"

        # Stream data in batches
        source_cursor.execute(f"SELECT * FROM {table_name}")

        total_rows = 0
        while True:
            rows = source_cursor.fetchmany(batch_size)
            if not rows:
                break

            # Transform rows if needed
            if transform_row:
                rows = [transform_row(row) for row in rows]

            target_cursor.executemany(insert_sql, rows)
            self.target.commit()

            total_rows += len(rows)
            print(f"Migrated {total_rows} rows from {table_name}")

        return total_rows

    def validate_migration(self, table_name: str) -> Dict:
        """Validate data integrity after migration."""
        source_cursor = self.source.cursor()
        target_cursor = self.target.cursor()

        # Row count comparison
        source_cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
        source_count = source_cursor.fetchone()[0]

        target_cursor.execute(f"SELECT COUNT(*) FROM `{table_name}`")
        target_count = target_cursor.fetchone()[0]

        # Sample checksum (first 1000 rows)
        source_cursor.execute(f"SELECT * FROM {table_name} ORDER BY 1 LIMIT 1000")
        source_sample = source_cursor.fetchall()

        target_cursor.execute(f"SELECT * FROM `{table_name}` ORDER BY 1 LIMIT 1000")
        target_sample = target_cursor.fetchall()

        return {
            "table": table_name,
            "source_count": source_count,
            "target_count": target_count,
            "count_match": source_count == target_count,
            "sample_match": source_sample == target_sample,
            "valid": source_count == target_count
        }


# Usage Example
def run_pg_to_mysql_migration():
    pg_conn = psycopg2.connect("postgresql://localhost/source_db")
    mysql_conn = mysql.connector.connect(
        host="localhost",
        database="target_db",
        user="root",
        password="password"
    )

    migration = CrossDatabaseMigration(pg_conn, mysql_conn)

    tables = ["users", "orders", "products"]

    for table in tables:
        # Generate and execute DDL
        columns = migration.get_source_schema(table)
        ddl = migration.generate_target_ddl(table, columns)
        print(f"Creating table: {table}")
        mysql_conn.cursor().execute(ddl)

        # Migrate data
        rows = migration.migrate_data(table, batch_size=5000)
        print(f"Migrated {rows} rows")

        # Validate
        result = migration.validate_migration(table)
        print(f"Validation: {result}")

        if not result["valid"]:
            raise Exception(f"Validation failed for {table}")
```

### 5.3 Cutover Orchestration

```yaml
# cutover-plan.yaml
migration_id: "pg_to_mysql_20250115"
source_db: "postgresql://source/app"
target_db: "mysql://target/app"

pre_cutover:
  - name: "Final sync check"
    query_source: "SELECT MAX(updated_at) FROM users"
    query_target: "SELECT MAX(updated_at) FROM users"
    max_lag: "5 minutes"

  - name: "Application read-only mode"
    command: "kubectl set env deployment/app READ_ONLY=true"
    rollback: "kubectl set env deployment/app READ_ONLY=false"

cutover_steps:
  - step: 1
    name: "Stop writes to source"
    duration: "immediate"
    commands:
      - "psql $SOURCE_DB -c 'ALTER TABLE users SET (autovacuum_enabled = false)'"
      - "psql $SOURCE_DB -c 'REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public FROM app_user'"
    rollback:
      - "psql $SOURCE_DB -c 'GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user'"

  - step: 2
    name: "Final data sync"
    duration: "5-10 minutes"
    command: "python sync_final_changes.py --since='5 minutes ago'"
    verification:
      query_source: "SELECT COUNT(*) FROM users WHERE updated_at > NOW() - INTERVAL '10 minutes'"
      query_target: "SELECT COUNT(*) FROM users WHERE updated_at > NOW() - INTERVAL '10 minutes'"
      must_match: true

  - step: 3
    name: "Update application config"
    duration: "1 minute"
    commands:
      - "kubectl set env deployment/app DATABASE_URL=$TARGET_DB"
      - "kubectl rollout restart deployment/app"
    verification:
      command: "kubectl rollout status deployment/app --timeout=5m"
    rollback:
      - "kubectl set env deployment/app DATABASE_URL=$SOURCE_DB"
      - "kubectl rollout restart deployment/app"

  - step: 4
    name: "Enable writes"
    duration: "immediate"
    command: "kubectl set env deployment/app READ_ONLY=false"
    verification:
      command: "curl -f http://app/api/health"

post_cutover:
  - name: "Monitor error rates"
    duration: "30 minutes"
    metric: "error_rate"
    threshold: "< 1%"

  - name: "Monitor latency"
    duration: "30 minutes"
    metric: "p99_latency"
    threshold: "< 500ms"

rollback_trigger:
  - "Error rate > 5%"
  - "P99 latency > 2s"
  - "Any critical alert"

rollback_procedure:
  - "Set READ_ONLY=true"
  - "Sync changes back to source (if any)"
  - "Update DATABASE_URL to source"
  - "Set READ_ONLY=false"
  - "Post-incident review"
```

---

## 6. Migration Testing Frameworks

### 6.1 Testcontainers Setup

```python
# Python: Migration testing with Testcontainers
import pytest
from testcontainers.postgres import PostgresContainer
from testcontainers.mysql import MySqlContainer
import subprocess

class TestMigrations:
    """
    Test migrations against ephemeral database containers.
    """

    @pytest.fixture(scope="class")
    def postgres_container(self):
        with PostgresContainer("postgres:15") as pg:
            yield pg

    @pytest.fixture(scope="class")
    def mysql_container(self):
        with MySqlContainer("mysql:8.0") as mysql:
            yield mysql

    def test_migrations_apply_cleanly(self, postgres_container):
        """Test that all migrations apply without errors."""
        connection_url = postgres_container.get_connection_url()

        # Run migrations
        result = subprocess.run(
            ["alembic", "upgrade", "head"],
            env={"DATABASE_URL": connection_url},
            capture_output=True,
            text=True
        )

        assert result.returncode == 0, f"Migration failed: {result.stderr}"

    def test_migrations_are_reversible(self, postgres_container):
        """Test that migrations can be rolled back."""
        connection_url = postgres_container.get_connection_url()

        # Apply all migrations
        subprocess.run(
            ["alembic", "upgrade", "head"],
            env={"DATABASE_URL": connection_url},
            check=True
        )

        # Roll back one step
        result = subprocess.run(
            ["alembic", "downgrade", "-1"],
            env={"DATABASE_URL": connection_url},
            capture_output=True,
            text=True
        )

        assert result.returncode == 0, f"Rollback failed: {result.stderr}"

    def test_migrations_are_idempotent(self, postgres_container):
        """Test that migrations handle re-runs gracefully."""
        connection_url = postgres_container.get_connection_url()

        # Apply twice
        for _ in range(2):
            result = subprocess.run(
                ["alembic", "upgrade", "head"],
                env={"DATABASE_URL": connection_url},
                capture_output=True,
                text=True
            )
            assert result.returncode == 0

    def test_data_integrity_after_migration(self, postgres_container):
        """Test that existing data is preserved during migration."""
        import psycopg2

        conn = psycopg2.connect(postgres_container.get_connection_url())
        cursor = conn.cursor()

        # Setup: Apply migrations up to a point
        subprocess.run(
            ["alembic", "upgrade", "abc123"],  # Specific revision
            env={"DATABASE_URL": postgres_container.get_connection_url()},
            check=True
        )

        # Insert test data
        cursor.execute("""
            INSERT INTO users (id, email, name)
            VALUES (1, 'test@example.com', 'Test User')
        """)
        conn.commit()

        # Apply remaining migrations
        subprocess.run(
            ["alembic", "upgrade", "head"],
            env={"DATABASE_URL": postgres_container.get_connection_url()},
            check=True
        )

        # Verify data is preserved
        cursor.execute("SELECT email, name FROM users WHERE id = 1")
        result = cursor.fetchone()

        assert result == ('test@example.com', 'Test User')


class TestCrossDatabaseMigration:
    """Test cross-database migration correctness."""

    @pytest.fixture(scope="class")
    def source_pg(self):
        with PostgresContainer("postgres:15") as pg:
            yield pg

    @pytest.fixture(scope="class")
    def target_mysql(self):
        with MySqlContainer("mysql:8.0") as mysql:
            yield mysql

    def test_type_mapping_correctness(self, source_pg, target_mysql):
        """Test that type mappings produce correct results."""
        import psycopg2
        import mysql.connector

        # Setup source data
        pg_conn = psycopg2.connect(source_pg.get_connection_url())
        pg_cursor = pg_conn.cursor()

        pg_cursor.execute("""
            CREATE TABLE test_types (
                id SERIAL PRIMARY KEY,
                uuid_col UUID DEFAULT gen_random_uuid(),
                json_col JSONB,
                bool_col BOOLEAN,
                ts_col TIMESTAMPTZ DEFAULT NOW()
            )
        """)
        pg_cursor.execute("""
            INSERT INTO test_types (json_col, bool_col)
            VALUES ('{"key": "value"}', true)
        """)
        pg_conn.commit()

        # Run migration
        # ... migration code ...

        # Verify target data
        mysql_conn = mysql.connector.connect(
            host=target_mysql.get_container_host_ip(),
            port=target_mysql.get_exposed_port(3306),
            database="test",
            user="root",
            password="test"
        )
        mysql_cursor = mysql_conn.cursor()

        mysql_cursor.execute("SELECT json_col, bool_col FROM test_types")
        result = mysql_cursor.fetchone()

        # Verify JSON preserved
        assert result[0] == '{"key": "value"}'
        # Verify boolean converted
        assert result[1] == 1
```

### 6.2 pytest-alembic Integration

```python
# conftest.py
import pytest
from pytest_alembic import MigrationContext, Config

@pytest.fixture
def alembic_config():
    return Config.from_raw_config({
        "script_location": "alembic",
        "sqlalchemy.url": "postgresql://localhost/test_db"
    })

@pytest.fixture
def alembic_engine(postgres_container):
    from sqlalchemy import create_engine
    return create_engine(postgres_container.get_connection_url())


# test_migrations.py
def test_single_head_revision(alembic_runner):
    """Test that there's only one head revision."""
    heads = alembic_runner.heads
    assert len(heads) == 1, f"Multiple heads detected: {heads}"

def test_upgrade_downgrade_cycle(alembic_runner):
    """Test full upgrade/downgrade cycle."""
    alembic_runner.migrate_up_to("head")
    alembic_runner.migrate_down_to("base")
    alembic_runner.migrate_up_to("head")

def test_model_definitions_match_ddl(alembic_runner):
    """Test that SQLAlchemy models match migration DDL."""
    alembic_runner.migrate_up_to("head")

    # Compare model metadata with database schema
    from myapp.models import Base
    from sqlalchemy import inspect

    inspector = inspect(alembic_runner.connection)

    for table_name in Base.metadata.tables:
        # Get model columns
        model_columns = set(Base.metadata.tables[table_name].columns.keys())

        # Get database columns
        db_columns = set(c["name"] for c in inspector.get_columns(table_name))

        assert model_columns == db_columns, \
            f"Column mismatch in {table_name}: model={model_columns}, db={db_columns}"
```

### 6.3 pgTAP Testing

```sql
-- t/test_migrations.sql
-- Run with: pg_prove -d myapp t/test_migrations.sql

BEGIN;
SELECT plan(10);

-- Test table exists
SELECT has_table('users', 'users table should exist');
SELECT has_table('orders', 'orders table should exist');

-- Test columns
SELECT has_column('users', 'id', 'users should have id column');
SELECT has_column('users', 'email', 'users should have email column');
SELECT has_column('users', 'created_at', 'users should have created_at column');

-- Test column types
SELECT col_type_is('users', 'id', 'uuid', 'id should be UUID');
SELECT col_type_is('users', 'email', 'character varying(255)', 'email should be varchar(255)');

-- Test constraints
SELECT col_not_null('users', 'email', 'email should be NOT NULL');
SELECT col_is_unique('users', 'email', 'email should be unique');

-- Test indexes
SELECT has_index('users', 'idx_users_email', 'users should have email index');

-- Test foreign keys
SELECT fk_ok(
    'orders', 'user_id',
    'users', 'id',
    'orders.user_id should reference users.id'
);

SELECT * FROM finish();
ROLLBACK;
```

### 6.4 Data Integrity Checks

```python
# data_integrity_tests.py
import pytest
from dataclasses import dataclass
from typing import List, Optional
import hashlib

@dataclass
class IntegrityCheck:
    name: str
    query: str
    expected: any
    tolerance: float = 0.0

class DataIntegrityValidator:
    """
    Validate data integrity before and after migrations.
    """

    def __init__(self, connection):
        self.conn = connection
        self.baseline: dict = {}

    def capture_baseline(self, checks: List[IntegrityCheck]):
        """Capture pre-migration state."""
        cursor = self.conn.cursor()

        for check in checks:
            cursor.execute(check.query)
            result = cursor.fetchone()[0]
            self.baseline[check.name] = result

    def validate(self, checks: List[IntegrityCheck]) -> List[dict]:
        """Validate post-migration state against baseline."""
        cursor = self.conn.cursor()
        results = []

        for check in checks:
            cursor.execute(check.query)
            current = cursor.fetchone()[0]
            baseline = self.baseline.get(check.name)

            # Handle numeric tolerance
            if isinstance(current, (int, float)) and isinstance(baseline, (int, float)):
                diff = abs(current - baseline)
                tolerance_abs = baseline * check.tolerance if baseline else 0
                passed = diff <= tolerance_abs
            else:
                passed = current == check.expected if check.expected else current == baseline

            results.append({
                "check": check.name,
                "baseline": baseline,
                "current": current,
                "expected": check.expected,
                "passed": passed
            })

        return results


# Define integrity checks
INTEGRITY_CHECKS = [
    IntegrityCheck(
        name="total_users",
        query="SELECT COUNT(*) FROM users",
        expected=None,  # Compare to baseline
        tolerance=0.0   # Exact match
    ),
    IntegrityCheck(
        name="total_orders",
        query="SELECT COUNT(*) FROM orders",
        expected=None,
        tolerance=0.01  # Allow 1% variance
    ),
    IntegrityCheck(
        name="users_with_orders",
        query="""
            SELECT COUNT(DISTINCT user_id)
            FROM orders
            WHERE user_id IS NOT NULL
        """,
        expected=None,
        tolerance=0.0
    ),
    IntegrityCheck(
        name="revenue_total",
        query="SELECT COALESCE(SUM(amount), 0) FROM orders",
        expected=None,
        tolerance=0.001  # Allow 0.1% for rounding
    ),
    IntegrityCheck(
        name="orphaned_orders",
        query="""
            SELECT COUNT(*) FROM orders o
            LEFT JOIN users u ON o.user_id = u.id
            WHERE u.id IS NULL AND o.user_id IS NOT NULL
        """,
        expected=0  # Should always be 0
    ),
    IntegrityCheck(
        name="null_emails",
        query="SELECT COUNT(*) FROM users WHERE email IS NULL",
        expected=0  # Email required
    ),
]


# Test usage
def test_data_integrity():
    import psycopg2

    conn = psycopg2.connect("postgresql://localhost/myapp")
    validator = DataIntegrityValidator(conn)

    # Capture before migration
    validator.capture_baseline(INTEGRITY_CHECKS)

    # Run migration
    # ... migration code ...

    # Validate after migration
    results = validator.validate(INTEGRITY_CHECKS)

    for result in results:
        assert result["passed"], \
            f"Integrity check failed: {result['check']} " \
            f"(baseline={result['baseline']}, current={result['current']})"
```

---

## 7. Migration Tool Templates

### 7.1 Prisma Migrations

```prisma
// prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id        String   @id @default(uuid())
  email     String   @unique
  name      String?
  status    UserStatus @default(ACTIVE)
  profile   Json?
  createdAt DateTime @default(now()) @map("created_at")
  updatedAt DateTime @updatedAt @map("updated_at")

  orders    Order[]

  @@map("users")
  @@index([email])
  @@index([status])
}

enum UserStatus {
  ACTIVE
  INACTIVE
  SUSPENDED
}

model Order {
  id        String   @id @default(uuid())
  userId    String   @map("user_id")
  amount    Decimal  @db.Decimal(10, 2)
  status    OrderStatus @default(PENDING)
  createdAt DateTime @default(now()) @map("created_at")

  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@map("orders")
  @@index([userId])
  @@index([status])
}

enum OrderStatus {
  PENDING
  COMPLETED
  CANCELLED
  REFUNDED
}
```

```sql
-- prisma/migrations/20250115120000_add_user_status/migration.sql

-- CreateEnum
CREATE TYPE "UserStatus" AS ENUM ('ACTIVE', 'INACTIVE', 'SUSPENDED');

-- AlterTable (Expand)
ALTER TABLE "users" ADD COLUMN "status" "UserStatus";

-- Backfill (run separately or via app)
-- UPDATE "users" SET "status" = 'ACTIVE' WHERE "status" IS NULL;

-- AlterTable (Contract - after backfill verified)
-- ALTER TABLE "users" ALTER COLUMN "status" SET NOT NULL;
-- ALTER TABLE "users" ALTER COLUMN "status" SET DEFAULT 'ACTIVE';

-- CreateIndex
CREATE INDEX "users_status_idx" ON "users"("status");
```

```bash
# Prisma CLI commands
# Development
npx prisma migrate dev --name add_user_status

# Preview migration SQL
npx prisma migrate diff \
  --from-schema-datamodel prisma/schema.prisma \
  --to-schema-datasource prisma/schema.prisma \
  --script

# Production deployment
npx prisma migrate deploy

# Reset database (dev only)
npx prisma migrate reset

# Check migration status
npx prisma migrate status
```

### 7.2 Alembic (Python)

```python
# alembic/versions/20250115_1200_add_user_status.py
"""Add user status enum

Revision ID: abc123def456
Revises: 789ghi012jkl
Create Date: 2025-01-15 12:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers
revision = 'abc123def456'
down_revision = '789ghi012jkl'
branch_labels = None
depends_on = None


def upgrade():
    # Create enum type
    user_status = postgresql.ENUM(
        'ACTIVE', 'INACTIVE', 'SUSPENDED',
        name='userstatus',
        create_type=False
    )
    user_status.create(op.get_bind(), checkfirst=True)

    # Add column (nullable for expand phase)
    op.add_column(
        'users',
        sa.Column(
            'status',
            postgresql.ENUM('ACTIVE', 'INACTIVE', 'SUSPENDED', name='userstatus'),
            nullable=True
        )
    )

    # Backfill default value
    op.execute("UPDATE users SET status = 'ACTIVE' WHERE status IS NULL")

    # Make column NOT NULL (contract phase)
    op.alter_column(
        'users',
        'status',
        existing_type=postgresql.ENUM('ACTIVE', 'INACTIVE', 'SUSPENDED', name='userstatus'),
        nullable=False,
        server_default='ACTIVE'
    )

    # Create index
    op.create_index(
        'ix_users_status',
        'users',
        ['status'],
        unique=False
    )


def downgrade():
    # Drop index
    op.drop_index('ix_users_status', table_name='users')

    # Drop column
    op.drop_column('users', 'status')

    # Drop enum type
    op.execute("DROP TYPE IF EXISTS userstatus")


# Separate migration for large backfills
# alembic/versions/20250115_1201_backfill_user_status.py
"""Backfill user status (chunked)

This is a data migration - run separately from schema changes.
"""
from alembic import op
import sqlalchemy as sa

revision = 'backfill001'
down_revision = 'abc123def456'

def upgrade():
    connection = op.get_bind()

    # Chunked update
    chunk_size = 10000
    offset = 0

    while True:
        result = connection.execute(sa.text("""
            WITH batch AS (
                SELECT id FROM users
                WHERE status IS NULL
                ORDER BY id
                LIMIT :chunk_size
            )
            UPDATE users
            SET status = 'ACTIVE'
            WHERE id IN (SELECT id FROM batch)
            RETURNING id
        """), {"chunk_size": chunk_size})

        updated = result.rowcount
        if updated == 0:
            break

        print(f"Updated {updated} rows")
        offset += updated


def downgrade():
    # Data backfills are typically not reversible
    pass
```

```bash
# Alembic CLI commands
# Generate migration from model changes
alembic revision --autogenerate -m "Add user status"

# Apply migrations
alembic upgrade head

# Rollback one step
alembic downgrade -1

# Rollback to specific revision
alembic downgrade abc123

# Show current revision
alembic current

# Show migration history
alembic history --verbose

# Generate SQL without applying
alembic upgrade head --sql > migration.sql
```

```ini
# alembic.ini
[alembic]
script_location = alembic
sqlalchemy.url = postgresql://localhost/myapp

[post_write_hooks]
hooks = black
black.type = console_scripts
black.entrypoint = black
black.options = -q

[logging]
keys = root,sqlalchemy,alembic

[logger_alembic]
level = INFO
handlers =
qualname = alembic
```

### 7.3 Flyway (Java/SQL)

```sql
-- V1.0.0__create_users_table.sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email);

-- V1.1.0__add_user_status.sql
-- Expand phase: add nullable column
ALTER TABLE users ADD COLUMN status VARCHAR(20);

-- V1.1.1__backfill_user_status.sql
-- Backfill (run as repeatable or separate step)
UPDATE users SET status = 'ACTIVE' WHERE status IS NULL;

-- V1.1.2__enforce_user_status.sql
-- Contract phase: add constraint
ALTER TABLE users ALTER COLUMN status SET NOT NULL;
ALTER TABLE users ALTER COLUMN status SET DEFAULT 'ACTIVE';
ALTER TABLE users ADD CONSTRAINT chk_user_status
    CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED'));

CREATE INDEX idx_users_status ON users(status);

-- R__user_status_view.sql (Repeatable migration)
-- Repeatable migrations run whenever their checksum changes
CREATE OR REPLACE VIEW active_users AS
SELECT * FROM users WHERE status = 'ACTIVE';
```

```properties
# flyway.conf
flyway.url=jdbc:postgresql://localhost:5432/myapp
flyway.user=postgres
flyway.password=${FLYWAY_PASSWORD}
flyway.locations=filesystem:./migrations
flyway.baselineOnMigrate=true
flyway.baselineVersion=1.0.0
flyway.validateOnMigrate=true
flyway.outOfOrder=false
flyway.cleanDisabled=true
flyway.table=flyway_schema_history
```

```bash
# Flyway CLI commands
# Apply pending migrations
flyway migrate

# Validate migrations
flyway validate

# Show migration info
flyway info

# Create baseline
flyway baseline

# Clean database (dev only, disabled by default)
flyway clean

# Repair metadata
flyway repair

# Generate migration script
flyway migrate -outputFile=migration.sql -dryRun=true
```

```java
// Java: Programmatic Flyway configuration
import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.configuration.FluentConfiguration;

public class DatabaseMigrator {
    public static void migrate(String jdbcUrl, String user, String password) {
        FluentConfiguration config = Flyway.configure()
            .dataSource(jdbcUrl, user, password)
            .locations("classpath:db/migration")
            .baselineOnMigrate(true)
            .validateOnMigrate(true)
            .outOfOrder(false)
            .cleanDisabled(true)
            .table("flyway_schema_history")
            .callbacks(new MigrationCallback()); // Custom callbacks

        Flyway flyway = config.load();

        // Validate before migrating
        flyway.validate();

        // Run migrations
        flyway.migrate();
    }
}
```

### 7.4 Atlas (Modern Schema Management)

```hcl
# schema.hcl - Declarative schema definition
schema "public" {}

table "users" {
  schema = schema.public

  column "id" {
    type = uuid
    default = sql("gen_random_uuid()")
  }

  column "email" {
    type = varchar(255)
    null = false
  }

  column "name" {
    type = varchar(100)
    null = true
  }

  column "status" {
    type = enum("ACTIVE", "INACTIVE", "SUSPENDED")
    default = "ACTIVE"
  }

  column "profile" {
    type = jsonb
    null = true
  }

  column "created_at" {
    type = timestamptz
    default = sql("NOW()")
  }

  column "updated_at" {
    type = timestamptz
    default = sql("NOW()")
  }

  primary_key {
    columns = [column.id]
  }

  index "idx_users_email" {
    columns = [column.email]
    unique = true
  }

  index "idx_users_status" {
    columns = [column.status]
  }
}

table "orders" {
  schema = schema.public

  column "id" {
    type = uuid
    default = sql("gen_random_uuid()")
  }

  column "user_id" {
    type = uuid
    null = false
  }

  column "amount" {
    type = decimal(10, 2)
    null = false
  }

  column "status" {
    type = enum("PENDING", "COMPLETED", "CANCELLED", "REFUNDED")
    default = "PENDING"
  }

  column "created_at" {
    type = timestamptz
    default = sql("NOW()")
  }

  primary_key {
    columns = [column.id]
  }

  foreign_key "fk_orders_user" {
    columns = [column.user_id]
    ref_columns = [table.users.column.id]
    on_delete = CASCADE
  }

  index "idx_orders_user_id" {
    columns = [column.user_id]
  }
}
```

```bash
# Atlas CLI commands
# Inspect current database schema
atlas schema inspect \
  --url "postgresql://localhost:5432/myapp?sslmode=disable" \
  --format '{{ sql . }}'

# Generate migration from schema diff
atlas migrate diff add_user_status \
  --dir "file://migrations" \
  --to "file://schema.hcl" \
  --dev-url "docker://postgres/15"

# Apply migrations
atlas migrate apply \
  --url "postgresql://localhost:5432/myapp?sslmode=disable" \
  --dir "file://migrations"

# Lint migrations for issues
atlas migrate lint \
  --dir "file://migrations" \
  --dev-url "docker://postgres/15" \
  --latest 1

# Validate schema
atlas schema apply \
  --url "postgresql://localhost:5432/myapp?sslmode=disable" \
  --to "file://schema.hcl" \
  --dry-run

# Hash migrations for integrity
atlas migrate hash \
  --dir "file://migrations"
```

```yaml
# atlas.hcl - Atlas configuration
env "local" {
url = "postgresql://localhost:5432/myapp?sslmode=disable"
dev = "docker://postgres/15"

migration {
dir = "file://migrations"
}

schema {
src = "file://schema.hcl"
}
}

env "production" {
url = getenv("DATABASE_URL")

migration {
dir    = "file://migrations"
format = atlas
}
}

lint {
destructive {
error = true
}

data_depend {
error = true
}
}
```

---

## 8. Integration with Other Agents

### 8.1 PostgreSQL Expert Integration

```
Use the Task tool with subagent_type="postgresql-expert" to:

1. Review DDL for lock impact and blocking potential
2. Plan index creation strategies (CONCURRENTLY)
3. Optimize backfill queries for large tables
4. Assess replication lag and WAL impact
5. Analyze query plans before/after migration

Task: Review migration plan for zero-downtime DDL on users table
```

### 8.2 ORM Expert Integration

```
Use the Task tool with subagent_type="orm-expert" to:

1. Generate model definitions matching migration DDL
2. Validate ORM queries after schema changes
3. Handle migration of relationships and associations
4. Optimize N+1 queries post-migration

Task: Update SQLAlchemy models after user status migration
```

### 8.3 Database Architect Integration

```
Use the Task tool with subagent_type="database-architect" to:

1. Review schema design decisions
2. Plan denormalization strategies
3. Design sharding and partitioning schemes
4. Evaluate indexing strategies

Task: Design partition strategy for orders table migration
```

---

## 9. Quick Reference Commands

```bash
# Prisma
npx prisma migrate dev --name <name>      # Create + apply migration
npx prisma migrate deploy                  # Apply pending (production)
npx prisma migrate status                  # Check status
npx prisma db push                         # Push schema without migration

# Alembic
alembic revision --autogenerate -m "<msg>" # Generate from models
alembic upgrade head                       # Apply all pending
alembic downgrade -1                       # Rollback one step
alembic current                            # Show current revision

# Flyway
flyway migrate                             # Apply pending
flyway validate                            # Validate checksums
flyway info                                # Show status
flyway repair                              # Fix metadata

# Atlas
atlas migrate diff <name>                  # Generate from schema diff
atlas migrate apply                        # Apply pending
atlas migrate lint                         # Check for issues
atlas schema inspect                       # Show current schema
```

---

## Example Usage

```
/agents/database/migration-expert-full Plan zero-downtime migration to add JSONB profile column to users table with 10M rows

/agents/database/migration-expert-full Design cross-database migration from PostgreSQL to MySQL for e-commerce schema

/agents/database/migration-expert-full Create rollback playbook for user status enum migration

/agents/database/migration-expert-full Set up migration testing with Testcontainers and pytest-alembic
```

---

## Author

Ahmed Adel Bakr Alderai
