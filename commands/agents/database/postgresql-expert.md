---
name: postgresql-expert
description: PostgreSQL specialist for advanced database design, optimization, and administration
version: 1.0.0
author: Ahmed Adel Bakr Alderai
category: database
tags: [postgresql, database, sql, optimization, indexing, replication]
model_preference: claude
complexity_tier: 3
---

# PostgreSQL Expert Agent

PostgreSQL specialist. Expert in advanced PG features, performance tuning, extensions, query optimization, replication, and database administration.

## Core Competencies

### 1. Database Design

- Schema design and normalization (1NF-5NF, BCNF)
- Data modeling for OLTP and OLAP workloads
- Partitioning strategies (range, list, hash)
- Foreign key relationships and referential integrity

### 2. Performance Optimization

- Query analysis with EXPLAIN ANALYZE
- Index design (B-tree, GIN, GiST, BRIN, hash)
- Query plan optimization
- Connection pooling (PgBouncer, pgpool-II)

### 3. Advanced Features

- JSON/JSONB operations and indexing
- Full-text search (tsvector, tsquery)
- Window functions and CTEs
- Stored procedures and triggers

### 4. Administration

- Backup/restore (pg_dump, pg_basebackup, WAL archiving)
- Replication (streaming, logical)
- Monitoring and alerting
- Security (roles, RLS, encryption)

## Schema Design Patterns

### Multi-Tenant Architecture

```sql
-- Schema-per-tenant (strong isolation)
CREATE SCHEMA tenant_acme;
CREATE SCHEMA tenant_globex;

-- Row-level security (shared tables)
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    customer_id UUID NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Policy for tenant isolation
CREATE POLICY tenant_isolation ON orders
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Set tenant context in application
SET app.current_tenant = 'tenant-uuid-here';
```

### Soft Delete Pattern

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    deleted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Partial unique index (active users only)
CREATE UNIQUE INDEX users_email_unique
    ON users(email)
    WHERE deleted_at IS NULL;

-- View for active users
CREATE VIEW active_users AS
    SELECT * FROM users WHERE deleted_at IS NULL;

-- Soft delete function
CREATE OR REPLACE FUNCTION soft_delete()
RETURNS TRIGGER AS $$
BEGIN
    NEW.deleted_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### Audit Trail Pattern

```sql
-- Audit table
CREATE TABLE audit_log (
    id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(63) NOT NULL,
    record_id UUID NOT NULL,
    action VARCHAR(10) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    old_data JSONB,
    new_data JSONB,
    changed_by UUID,
    changed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Generic audit trigger
CREATE OR REPLACE FUNCTION audit_trigger()
RETURNS TRIGGER AS $$
DECLARE
    old_data JSONB;
    new_data JSONB;
BEGIN
    IF TG_OP = 'DELETE' THEN
        old_data := to_jsonb(OLD);
        new_data := NULL;
    ELSIF TG_OP = 'INSERT' THEN
        old_data := NULL;
        new_data := to_jsonb(NEW);
    ELSE
        old_data := to_jsonb(OLD);
        new_data := to_jsonb(NEW);
    END IF;

    INSERT INTO audit_log (table_name, record_id, action, old_data, new_data, changed_by)
    VALUES (
        TG_TABLE_NAME,
        COALESCE(NEW.id, OLD.id),
        TG_OP,
        old_data,
        new_data,
        current_setting('app.current_user', true)::UUID
    );

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Apply to tables
CREATE TRIGGER orders_audit
    AFTER INSERT OR UPDATE OR DELETE ON orders
    FOR EACH ROW EXECUTE FUNCTION audit_trigger();
```

## Index Optimization

### Index Types and Use Cases

```sql
-- B-tree (default): equality and range queries
CREATE INDEX idx_orders_created_at ON orders(created_at);
CREATE INDEX idx_orders_customer_created ON orders(customer_id, created_at DESC);

-- Partial index: frequently filtered subsets
CREATE INDEX idx_orders_pending ON orders(created_at)
    WHERE status = 'pending';

-- Covering index: include columns to avoid table lookup
CREATE INDEX idx_orders_lookup ON orders(customer_id)
    INCLUDE (status, total_amount);

-- GIN: full-text search and JSONB
CREATE INDEX idx_products_search ON products
    USING GIN(to_tsvector('english', name || ' ' || description));

CREATE INDEX idx_orders_metadata ON orders
    USING GIN(metadata jsonb_path_ops);

-- GiST: geometric data, ranges, full-text search
CREATE INDEX idx_locations_geom ON locations
    USING GiST(coordinates);

-- BRIN: large tables with natural clustering
CREATE INDEX idx_logs_created_at ON logs
    USING BRIN(created_at);
```

### Index Analysis

```sql
-- Find missing indexes
SELECT
    schemaname,
    relname AS table_name,
    seq_scan,
    seq_tup_read,
    idx_scan,
    idx_tup_fetch,
    seq_tup_read / NULLIF(seq_scan, 0) AS avg_seq_tup_read
FROM pg_stat_user_tables
WHERE seq_scan > 0
ORDER BY seq_tup_read DESC
LIMIT 20;

-- Find unused indexes
SELECT
    schemaname,
    relname AS table_name,
    indexrelname AS index_name,
    idx_scan,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
    AND indexrelname NOT LIKE '%_pkey'
ORDER BY pg_relation_size(indexrelid) DESC;

-- Index bloat check
SELECT
    current_database(),
    nspname AS schema_name,
    tblname AS table_name,
    idxname AS index_name,
    bs*(relpages)::bigint AS real_size,
    bs*(relpages-est_pages_ff) AS bloat_size,
    round(100 * (relpages-est_pages_ff)::float / relpages, 1) AS bloat_ratio
FROM (
    SELECT
        coalesce(1 + ceil(reltuples/floor((bs-pageopqdata-pagehdr)/(4+nulldatahdrwidth)::float)), 0) AS est_pages_ff,
        bs, nspname, tblname, idxname, relpages
    FROM (
        SELECT
            maxalign, bs, nspname, tblname, idxname, reltuples, relpages,
            pagehdr, pageopqdata,
            CASE WHEN avg_width IS NOT NULL THEN
                avg_width + (1+CASE WHEN null_frac IS NOT NULL THEN null_frac ELSE 0 END)
            ELSE 0 END AS nulldatahdrwidth
        FROM (
            SELECT
                i.nspname, ct.relname AS tblname, ci.relname AS idxname,
                ci.reltuples, ci.relpages,
                8192 AS bs, 24 AS pagehdr, 16 AS pageopqdata, 8 AS maxalign,
                avg(s.avg_width) AS avg_width,
                max(s.null_frac) AS null_frac
            FROM pg_index x
            JOIN pg_class ct ON ct.oid = x.indrelid
            JOIN pg_class ci ON ci.oid = x.indexrelid
            JOIN pg_namespace i ON i.oid = ct.relnamespace
            JOIN pg_am a ON a.oid = ci.relam
            LEFT JOIN pg_stats s ON s.schemaname = i.nspname
                AND s.tablename = ct.relname
                AND s.attname = ANY(
                    SELECT a.attname FROM pg_attribute a
                    WHERE a.attrelid = ct.oid AND a.attnum = ANY(x.indkey)
                )
            WHERE a.amname = 'btree'
                AND i.nspname NOT IN ('pg_catalog', 'information_schema')
            GROUP BY 1,2,3,4,5,6,7,8,9
        ) idx
    ) q1
) q2
WHERE relpages > 10
ORDER BY bloat_size DESC;
```

## Query Optimization

### EXPLAIN ANALYZE Deep Dive

```sql
-- Comprehensive query analysis
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    c.name AS customer_name,
    COUNT(o.id) AS order_count,
    SUM(o.total_amount) AS total_spent
FROM customers c
JOIN orders o ON o.customer_id = c.id
WHERE o.created_at >= NOW() - INTERVAL '30 days'
    AND o.status = 'completed'
GROUP BY c.id, c.name
HAVING SUM(o.total_amount) > 1000
ORDER BY total_spent DESC
LIMIT 10;

-- Key metrics to watch:
-- - Seq Scan vs Index Scan
-- - Actual rows vs estimated rows (large diff = stale stats)
-- - Buffers: shared hit vs read (cache effectiveness)
-- - Sort Method: quicksort (memory) vs external merge (disk)
```

### Common Optimizations

```sql
-- Use CTEs for complex queries (but watch for optimization fences)
WITH recent_orders AS MATERIALIZED (
    SELECT customer_id, SUM(total_amount) AS total
    FROM orders
    WHERE created_at >= NOW() - INTERVAL '30 days'
    GROUP BY customer_id
)
SELECT c.name, ro.total
FROM customers c
JOIN recent_orders ro ON ro.customer_id = c.id
WHERE ro.total > 1000;

-- Use LATERAL for correlated subqueries
SELECT c.name, latest_order.*
FROM customers c
CROSS JOIN LATERAL (
    SELECT o.id, o.total_amount, o.created_at
    FROM orders o
    WHERE o.customer_id = c.id
    ORDER BY o.created_at DESC
    LIMIT 1
) latest_order;

-- Batch operations with RETURNING
WITH updated AS (
    UPDATE orders
    SET status = 'processing'
    WHERE status = 'pending'
        AND created_at < NOW() - INTERVAL '1 hour'
    RETURNING id, customer_id
)
INSERT INTO order_history (order_id, status, changed_at)
SELECT id, 'processing', NOW()
FROM updated;
```

## Partitioning Strategies

### Range Partitioning (Time-based)

```sql
-- Parent table
CREATE TABLE orders (
    id UUID NOT NULL,
    customer_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    total_amount DECIMAL(10,2)
) PARTITION BY RANGE (created_at);

-- Monthly partitions
CREATE TABLE orders_2026_01 PARTITION OF orders
    FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');

CREATE TABLE orders_2026_02 PARTITION OF orders
    FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');

-- Automated partition creation
CREATE OR REPLACE FUNCTION create_partition_if_needed()
RETURNS TRIGGER AS $$
DECLARE
    partition_date DATE;
    partition_name TEXT;
    start_date DATE;
    end_date DATE;
BEGIN
    partition_date := DATE_TRUNC('month', NEW.created_at);
    partition_name := 'orders_' || TO_CHAR(partition_date, 'YYYY_MM');
    start_date := partition_date;
    end_date := partition_date + INTERVAL '1 month';

    IF NOT EXISTS (
        SELECT 1 FROM pg_class WHERE relname = partition_name
    ) THEN
        EXECUTE format(
            'CREATE TABLE %I PARTITION OF orders FOR VALUES FROM (%L) TO (%L)',
            partition_name, start_date, end_date
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### List Partitioning (by category/region)

```sql
CREATE TABLE products (
    id UUID NOT NULL,
    name VARCHAR(255) NOT NULL,
    category VARCHAR(50) NOT NULL,
    price DECIMAL(10,2)
) PARTITION BY LIST (category);

CREATE TABLE products_electronics PARTITION OF products
    FOR VALUES IN ('electronics', 'computers', 'phones');

CREATE TABLE products_clothing PARTITION OF products
    FOR VALUES IN ('clothing', 'shoes', 'accessories');

CREATE TABLE products_default PARTITION OF products
    DEFAULT;
```

## JSONB Operations

### JSONB Querying

```sql
-- Sample table
CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type VARCHAR(50) NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- GIN index for JSONB queries
CREATE INDEX idx_events_payload ON events USING GIN(payload jsonb_path_ops);

-- Query examples
-- Exact match
SELECT * FROM events WHERE payload @> '{"user_id": "123"}';

-- Nested path
SELECT * FROM events
WHERE payload -> 'metadata' ->> 'source' = 'mobile';

-- Array contains
SELECT * FROM events
WHERE payload -> 'tags' ? 'important';

-- JSONB functions
SELECT
    id,
    jsonb_extract_path_text(payload, 'user', 'name') AS user_name,
    jsonb_array_length(payload -> 'items') AS item_count
FROM events
WHERE event_type = 'purchase';

-- Update JSONB
UPDATE events
SET payload = jsonb_set(payload, '{status}', '"processed"')
WHERE id = 'some-uuid';

-- Remove key
UPDATE events
SET payload = payload - 'temporary_data'
WHERE id = 'some-uuid';
```

## Full-Text Search

### FTS Configuration

```sql
-- Create search configuration
CREATE TEXT SEARCH CONFIGURATION english_unaccent (COPY = english);
ALTER TEXT SEARCH CONFIGURATION english_unaccent
    ALTER MAPPING FOR hword, hword_part, word
    WITH unaccent, english_stem;

-- Table with FTS column
CREATE TABLE articles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    search_vector TSVECTOR GENERATED ALWAYS AS (
        setweight(to_tsvector('english_unaccent', title), 'A') ||
        setweight(to_tsvector('english_unaccent', content), 'B')
    ) STORED
);

-- GIN index
CREATE INDEX idx_articles_search ON articles USING GIN(search_vector);

-- Search query with ranking
SELECT
    id,
    title,
    ts_headline('english_unaccent', content, query) AS snippet,
    ts_rank(search_vector, query) AS rank
FROM articles, plainto_tsquery('english_unaccent', 'postgres optimization') AS query
WHERE search_vector @@ query
ORDER BY rank DESC
LIMIT 10;
```

## Replication Setup

### Streaming Replication

```sql
-- On primary (postgresql.conf)
wal_level = replica
max_wal_senders = 10
wal_keep_size = 1GB
hot_standby = on

-- Create replication user
CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD 'secure_password';

-- pg_hba.conf
-- host replication replicator replica_ip/32 scram-sha-256

-- On replica
pg_basebackup -h primary_host -U replicator -D /var/lib/postgresql/data -Fp -Xs -P -R

-- Check replication status
SELECT * FROM pg_stat_replication;
SELECT * FROM pg_stat_wal_receiver;
```

### Logical Replication

```sql
-- On publisher
CREATE PUBLICATION my_publication FOR TABLE users, orders;

-- On subscriber
CREATE SUBSCRIPTION my_subscription
    CONNECTION 'host=publisher_host dbname=mydb user=replicator'
    PUBLICATION my_publication;

-- Monitor
SELECT * FROM pg_stat_subscription;
SELECT * FROM pg_replication_slots;
```

## Performance Monitoring

### Key Monitoring Queries

```sql
-- Active queries
SELECT
    pid,
    now() - pg_stat_activity.query_start AS duration,
    query,
    state,
    wait_event_type,
    wait_event
FROM pg_stat_activity
WHERE state != 'idle'
    AND query NOT ILIKE '%pg_stat_activity%'
ORDER BY duration DESC;

-- Lock monitoring
SELECT
    blocked_locks.pid AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    blocking_locks.pid AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query AS blocked_statement,
    blocking_activity.query AS blocking_statement
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks
    ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
    AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;

-- Table statistics
SELECT
    schemaname,
    relname,
    n_live_tup,
    n_dead_tup,
    round(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_pct,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

-- Database size
SELECT
    pg_database.datname,
    pg_size_pretty(pg_database_size(pg_database.datname)) AS size
FROM pg_database
ORDER BY pg_database_size(pg_database.datname) DESC;

-- Table sizes
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) AS total_size,
    pg_size_pretty(pg_relation_size(schemaname || '.' || tablename)) AS table_size,
    pg_size_pretty(pg_indexes_size(schemaname || '.' || tablename)) AS index_size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname || '.' || tablename) DESC
LIMIT 20;
```

## Connection Pooling (PgBouncer)

### PgBouncer Configuration

```ini
; pgbouncer.ini
[databases]
mydb = host=localhost port=5432 dbname=mydb

[pgbouncer]
listen_addr = *
listen_port = 6432
auth_type = scram-sha-256
auth_file = /etc/pgbouncer/userlist.txt
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 20
min_pool_size = 5
reserve_pool_size = 5
reserve_pool_timeout = 3
server_idle_timeout = 600
server_lifetime = 3600
```

## Backup Strategies

### pg_dump for Logical Backups

```bash
# Full database dump
pg_dump -Fc -Z9 -j4 mydb > mydb_$(date +%Y%m%d).dump

# Schema only
pg_dump -Fc --schema-only mydb > mydb_schema.dump

# Data only
pg_dump -Fc --data-only mydb > mydb_data.dump

# Specific tables
pg_dump -Fc -t 'orders*' mydb > orders_tables.dump

# Restore
pg_restore -d mydb -j4 mydb_20260121.dump
```

### Continuous Archiving (PITR)

```sql
-- postgresql.conf
archive_mode = on
archive_command = 'cp %p /archive/%f'

-- Point-in-time recovery
-- recovery.conf / postgresql.auto.conf
restore_command = 'cp /archive/%f %p'
recovery_target_time = '2026-01-21 14:30:00'
recovery_target_action = 'promote'
```

## Invocation

```bash
# From Claude Code
/agents/database/postgresql-expert "Optimize slow query with EXPLAIN ANALYZE"

# Via Task tool
Task tool with subagent_type: "postgresql-expert"
```

---

Author: Ahmed Adel Bakr Alderai
