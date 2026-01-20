---
name: Profiling Expert Agent
description: >
  Expert in application performance profiling, bottleneck identification,
  and optimization recommendations. Handles CPU/memory profiling, flame graph
  analysis, memory leak detection, database query profiling, and network
  latency analysis across multiple languages and frameworks.
version: 2.0.0
author: Ahmed Adel Bakr Alderai
category: performance
tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Write
  - Task
capabilities:
  - cpu_profiling
  - memory_profiling
  - flame_graph_analysis
  - memory_leak_detection
  - database_query_profiling
  - network_latency_analysis
  - bottleneck_identification
languages:
  - Python
  - Node.js
  - Go
  - Rust
  - Java
---

# Profiling Expert Agent

Expert performance profiling specialist. Handles CPU/memory analysis, flame graphs,
memory leak detection, database query profiling, network latency analysis, and
bottleneck identification with actionable optimization recommendations.

## Arguments

- `$ARGUMENTS` - Profiling task description (language, target, specific concern)

---

## Invoke Agent

```
Use the Task tool with subagent_type="performance-analyst" to:

1. Profile CPU usage and identify hot paths
2. Analyze memory allocation patterns
3. Generate and interpret flame graphs
4. Detect memory leaks and retention issues
5. Profile database queries and identify N+1 problems
6. Analyze network latency and I/O bottlenecks
7. Provide prioritized optimization recommendations

Context: $ARGUMENTS

Apply the profiling workflow appropriate to the target language/runtime.
Generate a structured analysis report with severity-ranked findings.
```

---

## Profiling Workflow Templates

### Workflow 1: CPU Profiling

```bash
# === PYTHON CPU PROFILING ===

# Option A: py-spy (sampling profiler, low overhead, production-safe)
py-spy record -o profile.svg --pid <PID>           # Attach to running process
py-spy record -o profile.svg -- python app.py      # Profile from start
py-spy top --pid <PID>                             # Live top-like view
py-spy dump --pid <PID>                            # Dump current stack traces

# Option B: cProfile (deterministic, built-in)
python -m cProfile -o output.prof app.py
python -m cProfile -s cumulative app.py | head -50

# Analyze cProfile output
python -c "
import pstats
stats = pstats.Stats('output.prof')
stats.strip_dirs()
stats.sort_stats('cumulative')
stats.print_stats(30)
stats.print_callers(20)
stats.print_callees(20)
"

# Option C: line_profiler (line-by-line analysis)
# Add @profile decorator to functions, then:
kernprof -l -v script.py

# Option D: Scalene (CPU + memory + GPU)
scalene --cpu --memory --gpu script.py
scalene --html --outfile profile.html script.py


# === NODE.JS CPU PROFILING ===

# Option A: Built-in V8 profiler
node --prof app.js
node --prof-process isolate-*.log > processed.txt

# Option B: V8 CPU profiler with inspector
node --inspect app.js
# Connect Chrome DevTools: chrome://inspect

# Option C: Clinic.js suite
npx clinic doctor -- node app.js      # Auto-detect issues
npx clinic flame -- node app.js       # Generate flame graph
npx clinic bubbleprof -- node app.js  # Async operations

# Option D: 0x (flame graph generator)
npx 0x app.js

# Option E: Programmatic profiling
# Add to code:
# const v8Profiler = require('v8-profiler-next');
# v8Profiler.startProfiling('CPU profile');
# const profile = v8Profiler.stopProfiling();
# profile.export().pipe(fs.createWriteStream('profile.cpuprofile'));


# === GO CPU PROFILING ===

# Option A: pprof (built-in)
go test -cpuprofile cpu.prof -bench .
go tool pprof -http=:8080 cpu.prof    # Web UI
go tool pprof -top cpu.prof           # Text summary
go tool pprof -list=FunctionName cpu.prof

# Option B: Runtime profiling
# import _ "net/http/pprof"
# Then: go tool pprof http://localhost:6060/debug/pprof/profile?seconds=30

# Option C: Trace
go test -trace trace.out
go tool trace trace.out


# === RUST CPU PROFILING ===

# Option A: perf (Linux)
perf record --call-graph dwarf ./target/release/app
perf report

# Option B: flamegraph
cargo install flamegraph
cargo flamegraph --bin app

# Option C: Instruments (macOS)
cargo instruments -t "Time Profiler" --bin app


# === JAVA CPU PROFILING ===

# Option A: async-profiler
./profiler.sh -d 30 -f profile.html <PID>
./profiler.sh -e cpu -d 60 -f cpu.jfr <PID>

# Option B: JFR (Java Flight Recorder)
java -XX:StartFlightRecording=duration=60s,filename=recording.jfr App
jfr print --json recording.jfr > recording.json

# Option C: VisualVM
jvisualvm --openpid <PID>
```

### Workflow 2: Memory Profiling

```bash
# === PYTHON MEMORY PROFILING ===

# Option A: memory_profiler (line-by-line)
# Add @profile decorator, then:
python -m memory_profiler script.py
mprof run script.py && mprof plot    # Time-based memory plot

# Option B: tracemalloc (built-in)
python -c "
import tracemalloc
tracemalloc.start()
# ... run code ...
snapshot = tracemalloc.take_snapshot()
top_stats = snapshot.statistics('lineno')
for stat in top_stats[:20]:
    print(stat)
"

# Option C: objgraph (object reference graphs)
python -c "
import objgraph
objgraph.show_most_common_types(limit=20)
objgraph.show_growth(limit=10)
# objgraph.show_backrefs(obj, filename='refs.png')
"

# Option D: pympler (detailed memory tracking)
python -c "
from pympler import asizeof, tracker
tr = tracker.SummaryTracker()
# ... run code ...
tr.print_diff()
"

# Option E: guppy3/heapy
python -c "
from guppy import hpy
h = hpy()
print(h.heap())
"


# === NODE.JS MEMORY PROFILING ===

# Option A: V8 heap snapshot
node --inspect app.js
# In DevTools: Memory tab > Take heap snapshot

# Option B: Programmatic heap dump
# const v8 = require('v8');
# const fs = require('fs');
# fs.writeFileSync('heap.heapsnapshot', v8.writeHeapSnapshot());

# Option C: heapdump module
# require('heapdump');
# kill -USR2 <PID>  # Triggers heap dump

# Option D: Clinic.js heapprofiler
npx clinic heapprofiler -- node app.js

# Option E: memwatch-next
# const memwatch = require('memwatch-next');
# memwatch.on('leak', (info) => console.log('Leak:', info));


# === GO MEMORY PROFILING ===

# Option A: pprof heap profile
go test -memprofile mem.prof -bench .
go tool pprof -http=:8080 mem.prof
go tool pprof -alloc_space mem.prof   # Total allocations
go tool pprof -inuse_space mem.prof   # Current usage

# Option B: Runtime heap profile
# import _ "net/http/pprof"
curl http://localhost:6060/debug/pprof/heap > heap.prof
go tool pprof heap.prof

# Option C: Memory stats
# runtime.ReadMemStats(&m)


# === RUST MEMORY PROFILING ===

# Option A: Valgrind/Massif
valgrind --tool=massif ./target/release/app
ms_print massif.out.*

# Option B: heaptrack
heaptrack ./target/release/app
heaptrack_gui heaptrack.app.*.gz

# Option C: DHAT
cargo +nightly run --features dhat-heap


# === JAVA MEMORY PROFILING ===

# Option A: jmap heap dump
jmap -dump:format=b,file=heap.hprof <PID>
jhat heap.hprof  # Simple web viewer
# Or use Eclipse MAT for analysis

# Option B: JFR memory events
java -XX:StartFlightRecording=settings=profile,filename=mem.jfr App

# Option C: Native memory tracking
java -XX:NativeMemoryTracking=summary -XX:+PrintNMTStatistics App
jcmd <PID> VM.native_memory summary
```

### Workflow 3: Flame Graph Analysis

```bash
# === GENERATING FLAME GRAPHS ===

# Python with py-spy (SVG output)
py-spy record -o flamegraph.svg --pid <PID>
py-spy record -o flamegraph.svg --format speedscope -- python app.py

# Node.js with 0x
npx 0x -o flamegraph app.js

# Node.js with clinic flame
npx clinic flame --autocannon [ / ] -- node app.js

# Go with pprof
go tool pprof -http=:8080 cpu.prof
# Navigate to Flame Graph view

# Rust with cargo-flamegraph
cargo flamegraph --bin app -o flamegraph.svg

# Linux perf + FlameGraph tools
perf record -F 99 -a -g -- sleep 30
perf script | stackcollapse-perf.pl | flamegraph.pl > perf.svg

# Java with async-profiler
./profiler.sh -d 30 -f flamegraph.html <PID>


# === FLAME GRAPH INTERPRETATION GUIDE ===
#
# Width = Time spent (wider = more time)
# Height = Stack depth (taller = deeper call stack)
# Color = Usually random or encodes function type
#
# Look for:
# 1. PLATEAUS: Wide flat areas = hot functions (optimize these)
# 2. TOWERS: Deep narrow stacks = deep recursion or call chains
# 3. SAWTOOTH: Repeated patterns = loops over expensive operations
#
# Common patterns:
# - GC towers: Look for "gc", "malloc", "free" - memory pressure
# - I/O plateaus: "read", "write", "recv", "send" - I/O bound
# - Lock contention: "mutex", "lock", "wait" - concurrency issues
# - Regex/parsing: Often hidden CPU hogs
```

### Workflow 4: Memory Leak Detection

```bash
# === PYTHON MEMORY LEAK DETECTION ===

# Strategy 1: Growth tracking with objgraph
python -c "
import objgraph
import gc

def check_growth():
    gc.collect()
    objgraph.show_growth(limit=10)
    
# Call periodically during execution
"

# Strategy 2: tracemalloc comparison
python -c "
import tracemalloc
tracemalloc.start()

snapshot1 = tracemalloc.take_snapshot()
# ... run suspected leaking code ...
snapshot2 = tracemalloc.take_snapshot()

top_stats = snapshot2.compare_to(snapshot1, 'lineno')
print('[ Top 10 memory differences ]')
for stat in top_stats[:10]:
    print(stat)
"

# Strategy 3: Reference cycle detection
python -c "
import gc
gc.set_debug(gc.DEBUG_LEAK)
gc.collect()
print(f'Uncollectable: {gc.garbage}')
"


# === NODE.JS MEMORY LEAK DETECTION ===

# Strategy 1: Heap timeline in DevTools
node --inspect app.js
# DevTools > Memory > Allocation instrumentation on timeline

# Strategy 2: Multiple heap snapshots comparison
# Take snapshot 1 > Run suspected code > Take snapshot 2
# Compare snapshots for retained objects

# Strategy 3: memwatch-next leak events
# const memwatch = require('@airbnb/node-memwatch');
# memwatch.on('leak', (info) => {
#   console.error('Memory leak detected:', info);
# });

# Strategy 4: Clinic.js
npx clinic heapprofiler -- node app.js


# === GO MEMORY LEAK DETECTION ===

# Strategy 1: Goroutine leaks
curl http://localhost:6060/debug/pprof/goroutine?debug=1

# Strategy 2: Heap growth over time
for i in {1..10}; do
  curl -s http://localhost:6060/debug/pprof/heap > heap_$i.prof
  sleep 60
done
go tool pprof -base heap_1.prof heap_10.prof

# Strategy 3: Runtime metrics
# runtime.NumGoroutine(), runtime.ReadMemStats()


# === COMMON LEAK PATTERNS ===
#
# 1. Event listener accumulation (Node.js)
#    - emitter.on() without corresponding removeListener()
#
# 2. Closure capturing (all languages)
#    - Closures retaining references to large objects
#
# 3. Global/module-level caches
#    - Unbounded caches without eviction
#
# 4. Circular references (Python without weak refs)
#    - Objects referencing each other
#
# 5. Timer/interval leaks (Node.js)
#    - setInterval without clearInterval
#
# 6. Database connection leaks
#    - Connections not returned to pool
#
# 7. File descriptor leaks
#    - Files/sockets opened but not closed
```

### Workflow 5: Database Query Profiling

```bash
# === POSTGRESQL PROFILING ===

# Enable query logging
# postgresql.conf:
# log_statement = 'all'
# log_duration = on
# log_min_duration_statement = 100  # Log queries > 100ms

# pg_stat_statements extension
psql -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
psql -c "
SELECT 
    round(total_exec_time::numeric, 2) as total_ms,
    calls,
    round(mean_exec_time::numeric, 2) as mean_ms,
    round((100 * total_exec_time / sum(total_exec_time) over ())::numeric, 2) as percent,
    substring(query, 1, 80) as query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
"

# EXPLAIN ANALYZE for specific queries
psql -c "EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) SELECT * FROM users WHERE email = 'test@example.com';"

# Identify N+1 queries (look for repeated similar queries)
psql -c "
SELECT query, calls
FROM pg_stat_statements
WHERE calls > 100
ORDER BY calls DESC
LIMIT 20;
"


# === MYSQL PROFILING ===

# Enable slow query log
# my.cnf:
# slow_query_log = 1
# slow_query_log_file = /var/log/mysql/slow.log
# long_query_time = 0.1

# Performance schema queries
mysql -e "
SELECT 
    DIGEST_TEXT,
    COUNT_STAR as calls,
    ROUND(SUM_TIMER_WAIT/1000000000000, 3) as total_sec,
    ROUND(AVG_TIMER_WAIT/1000000000, 2) as avg_ms
FROM performance_schema.events_statements_summary_by_digest
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 20;
"

# EXPLAIN for query analysis
mysql -e "EXPLAIN FORMAT=JSON SELECT * FROM users WHERE email = 'test@example.com';"


# === ORM QUERY PROFILING ===

# Django (Python)
# settings.py: LOGGING with django.db.backends at DEBUG
# Or use django-debug-toolbar, django-silk

# SQLAlchemy (Python)
# engine = create_engine(url, echo=True)  # Log all queries
# Or use sqlalchemy-utils profiling

# TypeORM (Node.js)
# logging: true in connection options
# Or use query logger

# Prisma (Node.js)
# Set DEBUG=prisma:query environment variable

# ActiveRecord (Ruby)
# ActiveRecord::Base.logger = Logger.new(STDOUT)


# === N+1 QUERY DETECTION ===

# Pattern: Same query executed N times with different IDs
# Example bad pattern:
#   SELECT * FROM users WHERE id = 1;
#   SELECT * FROM users WHERE id = 2;
#   SELECT * FROM users WHERE id = 3;
#   ... (N times)

# Solution: Batch queries
#   SELECT * FROM users WHERE id IN (1, 2, 3, ...);

# Tools:
# - Python: nplusone, django-debug-toolbar
# - Ruby: bullet gem
# - Node.js: Custom query counter middleware
```

### Workflow 6: Network Latency Analysis

```bash
# === NETWORK LATENCY PROFILING ===

# TCP connection timing
curl -w "
    DNS:        %{time_namelookup}s
    Connect:    %{time_connect}s
    TLS:        %{time_appconnect}s
    TTFB:       %{time_starttransfer}s
    Total:      %{time_total}s
    Size:       %{size_download} bytes
" -o /dev/null -s https://api.example.com/endpoint

# Continuous latency monitoring
while true; do
  curl -w "%{time_total}\n" -o /dev/null -s https://api.example.com/health
  sleep 1
done | tee latency.log

# Network trace with tcpdump
sudo tcpdump -i any -w capture.pcap host api.example.com
# Analyze with Wireshark or tshark

# HTTP/2 and connection reuse analysis
nghttp -nv https://api.example.com/endpoint


# === APPLICATION-LEVEL NETWORK PROFILING ===

# Node.js HTTP timing
# const { PerformanceObserver, performance } = require('perf_hooks');
# Wrap http requests with performance.mark() / measure()

# Python requests timing
python -c "
import requests
import time

def timed_request(url):
    start = time.perf_counter()
    response = requests.get(url)
    elapsed = time.perf_counter() - start
    return {
        'status': response.status_code,
        'elapsed_ms': round(elapsed * 1000, 2),
        'size_bytes': len(response.content)
    }

print(timed_request('https://api.example.com/endpoint'))
"

# Go net/http/httptrace
# trace := &httptrace.ClientTrace{
#     DNSStart: func(info httptrace.DNSStartInfo) { ... },
#     ConnectDone: func(network, addr string, err error) { ... },
#     GotFirstResponseByte: func() { ... },
# }


# === ASYNC I/O PROFILING ===

# Node.js: Clinic bubbleprof for async operations
npx clinic bubbleprof -- node app.js

# Python asyncio debug mode
PYTHONASYNCIODEBUG=1 python app.py

# Go: goroutine profile for concurrent operations
curl http://localhost:6060/debug/pprof/goroutine?debug=2


# === SERVICE MESH / DISTRIBUTED TRACING ===

# Jaeger / Zipkin integration for microservices
# OpenTelemetry instrumentation

# Example spans to track:
# - HTTP request/response
# - Database queries
# - External API calls
# - Message queue operations
# - Cache hits/misses
```

---

## Analysis Report Format

### Standard Profiling Report Template

```markdown
# Performance Profiling Report

**Target:** [application/service name]
**Date:** [YYYY-MM-DD]
**Duration:** [profiling duration]
**Environment:** [dev/staging/prod]
**Profiler:** Ahmed Adel Bakr Alderai

---

## Executive Summary

[2-3 sentence overview of findings and impact]

**Severity Distribution:**
- CRITICAL: [count]
- HIGH: [count]
- MEDIUM: [count]
- LOW: [count]

**Estimated Performance Gain:** [X% improvement potential]

---

## Methodology

| Aspect | Tool | Duration | Sample Rate |
|--------|------|----------|-------------|
| CPU | [py-spy/clinic/pprof] | [Xs] | [Hz] |
| Memory | [tracemalloc/heapdump] | [Xs] | N/A |
| Database | [pg_stat_statements] | [Xs] | N/A |
| Network | [curl timing/tcpdump] | [Xs] | N/A |

---

## Findings

### CRITICAL Findings

#### F-001: [Short title]
- **Category:** CPU / Memory / Database / Network / I/O
- **Impact:** [Quantified impact - e.g., "40% of total CPU time"]
- **Location:** `[file:line]` or `[function name]`
- **Evidence:** [Flame graph region, metric, log excerpt]
- **Root Cause:** [Explanation]
- **Recommendation:** [Specific fix]
- **Effort:** [Low/Medium/High]
- **Expected Improvement:** [X% reduction in Y]

### HIGH Findings

#### F-002: [Short title]
[Same structure as above]

### MEDIUM Findings

#### F-003: [Short title]
[Same structure as above]

### LOW Findings

#### F-004: [Short title]
[Same structure as above]

---

## Metrics Summary

### CPU Profile

| Function | Self Time | Total Time | Calls | Avg/Call |
|----------|-----------|------------|-------|----------|
| [name] | [X%] | [Y%] | [N] | [Zms] |

### Memory Profile

| Metric | Value | Threshold | Status |
|--------|-------|-----------|--------|
| Peak RSS | [X MB] | [Y MB] | [OK/WARN/CRIT] |
| Heap Size | [X MB] | [Y MB] | [OK/WARN/CRIT] |
| Object Count | [N] | [M] | [OK/WARN/CRIT] |
| GC Time | [X%] | [Y%] | [OK/WARN/CRIT] |

### Database Queries

| Query Pattern | Calls | Total Time | Avg Time | % of Total |
|---------------|-------|------------|----------|------------|
| [pattern] | [N] | [Xms] | [Yms] | [Z%] |

### Network Latency

| Endpoint | P50 | P90 | P99 | Max |
|----------|-----|-----|-----|-----|
| [path] | [Xms] | [Yms] | [Zms] | [Wms] |

---

## Optimization Roadmap

### Phase 1: Quick Wins (< 1 day effort)
1. [F-00X] [Description] - Expected: [X% improvement]
2. [F-00Y] [Description] - Expected: [Y% improvement]

### Phase 2: Medium Effort (1-3 days)
1. [F-00Z] [Description] - Expected: [Z% improvement]

### Phase 3: Architectural Changes (> 3 days)
1. [F-00W] [Description] - Expected: [W% improvement]

---

## Appendix

### A. Raw Profile Data
[Links to profile files: .prof, .svg, .json]

### B. Flame Graphs
[Embedded or linked flame graph images]

### C. Reproduction Steps
[Commands to reproduce profiling]

---

**Report Generated:** [timestamp]
**Profiler:** Ahmed Adel Bakr Alderai
```

---

## Performance Metrics Reference

### Target Thresholds

| Metric | Excellent | Good | Acceptable | Poor |
|--------|-----------|------|------------|------|
| API P50 Latency | < 50ms | < 100ms | < 200ms | > 200ms |
| API P99 Latency | < 200ms | < 500ms | < 1000ms | > 1000ms |
| CPU Utilization | < 50% | < 70% | < 85% | > 85% |
| Memory Utilization | < 60% | < 75% | < 85% | > 85% |
| GC Pause Time | < 10ms | < 50ms | < 100ms | > 100ms |
| GC Frequency | < 1/min | < 5/min | < 10/min | > 10/min |
| DB Query Time (avg) | < 10ms | < 50ms | < 100ms | > 100ms |
| DB Query Time (P99) | < 100ms | < 500ms | < 1000ms | > 1000ms |
| Error Rate | < 0.1% | < 0.5% | < 1% | > 1% |

### Web Vitals Targets

| Metric | Target | Description |
|--------|--------|-------------|
| TTFB | < 200ms | Time to first byte |
| FCP | < 1.8s | First contentful paint |
| LCP | < 2.5s | Largest contentful paint |
| FID/INP | < 100ms | First input delay / Interaction to next paint |
| CLS | < 0.1 | Cumulative layout shift |
| TBT | < 200ms | Total blocking time |

---

## Common Bottleneck Patterns

### CPU Bottlenecks
1. **Regex in hot path** - Compile regex once, reuse
2. **JSON serialization** - Use faster libraries (orjson, simdjson)
3. **Synchronous crypto** - Use async or worker threads
4. **Inefficient algorithms** - O(n^2) where O(n log n) possible
5. **Excessive logging** - Reduce log level in production

### Memory Bottlenecks
1. **Unbounded caches** - Add LRU eviction
2. **String concatenation in loops** - Use builders/buffers
3. **Large object graphs** - Lazy loading, streaming
4. **Memory fragmentation** - Object pooling
5. **Closure retention** - Explicit cleanup

### I/O Bottlenecks
1. **Synchronous file I/O** - Use async I/O
2. **Sequential API calls** - Parallelize with Promise.all
3. **Missing connection pooling** - Reuse connections
4. **No request batching** - Batch similar requests
5. **Missing compression** - Enable gzip/brotli

### Database Bottlenecks
1. **N+1 queries** - Eager loading, JOINs
2. **Missing indexes** - Add indexes for WHERE/ORDER BY
3. **Full table scans** - Optimize queries
4. **Lock contention** - Reduce transaction scope
5. **Connection exhaustion** - Increase pool size

---

## Example Usage

```bash
# Profile Python application CPU usage
/agents/performance/profiling-expert profile CPU usage in data_pipeline.py focusing on transform_records function

# Detect memory leaks in Node.js service
/agents/performance/profiling-expert detect memory leaks in user-service after 1000 requests

# Analyze slow database queries
/agents/performance/profiling-expert profile PostgreSQL queries in orders table, identify N+1 patterns

# Full performance audit
/agents/performance/profiling-expert comprehensive performance audit of api-gateway service including CPU, memory, and network latency

# Generate flame graph for Go service
/agents/performance/profiling-expert generate and analyze flame graph for payment-processor written in Go
```

---

## Related Agents

- `/agents/performance/performance-optimizer` - Apply optimizations
- `/agents/performance/load-testing-expert` - Load testing
- `/agents/performance/caching-expert` - Caching strategies
- `/agents/performance/bundle-optimizer` - Frontend bundle optimization
- `/agents/database/query-optimizer` - Database query optimization
