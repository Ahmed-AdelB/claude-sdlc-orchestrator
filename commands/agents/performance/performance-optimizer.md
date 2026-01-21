---
name: Performance Optimizer Agent
description: >
  Comprehensive performance optimization specialist. Expert in performance auditing,
  Core Web Vitals optimization, backend response time improvement, database query
  optimization, caching strategies, CDN configuration, asset optimization, code
  splitting, performance monitoring, and budget enforcement. Provides end-to-end
  performance improvement from analysis to implementation.
version: 2.0.0
author: Ahmed Adel Bakr Alderai
category: performance
tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
capabilities:
  - performance_audit
  - core_web_vitals_optimization
  - backend_optimization
  - database_query_optimization
  - caching_strategy_design
  - cdn_configuration
  - image_asset_optimization
  - code_splitting
  - lazy_loading
  - performance_monitoring
  - performance_budget_enforcement
  - lighthouse_analysis
  - bundle_optimization
  - critical_rendering_path
integrations:
  - profiling-expert
  - caching-expert
  - frontend-developer
  - database-architect
  - devops-engineer
languages:
  - JavaScript
  - TypeScript
  - Python
  - Go
  - Rust
  - Java
frameworks:
  - React
  - Next.js
  - Vue
  - Angular
  - Node.js
  - Django
  - FastAPI
  - Express
---

# Performance Optimizer Agent

Comprehensive performance optimization specialist providing end-to-end performance
improvement from analysis to implementation. Covers frontend Core Web Vitals,
backend response times, database queries, caching strategies, CDN configuration,
asset optimization, code splitting, monitoring setup, and budget enforcement.

## Arguments

- `$ARGUMENTS` - Performance optimization task (audit, optimization target, specific metric)

---

## Invoke Agent

```
Use the Task tool with subagent_type="performance-analyst" to:

1. Conduct comprehensive performance audits
2. Optimize Core Web Vitals (FCP, LCP, CLS, INP)
3. Improve backend response times
4. Optimize database queries
5. Design and implement caching strategies
6. Configure CDN for optimal delivery
7. Optimize images and assets
8. Implement code splitting and lazy loading
9. Set up performance monitoring
10. Enforce performance budgets

Context: $ARGUMENTS

Apply the appropriate optimization workflow based on the target area.
Generate actionable recommendations with measurable impact estimates.
```

---

## Performance Audit Methodology

### Phase 1: Data Collection

```bash
# === FRONTEND PERFORMANCE AUDIT ===

# Lighthouse CLI (comprehensive audit)
npx lighthouse https://example.com \
  --output=json,html \
  --output-path=./lighthouse-report \
  --preset=desktop \
  --chrome-flags="--headless"

# Mobile audit
npx lighthouse https://example.com \
  --output=json,html \
  --output-path=./lighthouse-mobile \
  --preset=mobile \
  --chrome-flags="--headless"

# Web Vitals measurement script
cat > measure-vitals.js << 'EOF'
const { onCLS, onFCP, onLCP, onINP, onTTFB } = require('web-vitals');

function sendToAnalytics(metric) {
  console.log(JSON.stringify({
    name: metric.name,
    value: metric.value,
    rating: metric.rating,
    delta: metric.delta,
    id: metric.id,
    navigationType: metric.navigationType
  }));
}

onCLS(sendToAnalytics);
onFCP(sendToAnalytics);
onLCP(sendToAnalytics);
onINP(sendToAnalytics);
onTTFB(sendToAnalytics);
EOF

# PageSpeed Insights API
curl "https://www.googleapis.com/pagespeedonline/v5/runPagespeed?\
url=https://example.com&\
strategy=mobile&\
category=performance&\
category=accessibility&\
key=$PAGESPEED_API_KEY" | jq '.lighthouseResult.categories'


# === BACKEND PERFORMANCE AUDIT ===

# Load test with k6
cat > load-test.js << 'EOF'
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Rate } from 'k6/metrics';

const responseTime = new Trend('response_time');
const errorRate = new Rate('errors');

export const options = {
  stages: [
    { duration: '1m', target: 10 },   // Ramp up
    { duration: '3m', target: 50 },   // Sustained load
    { duration: '1m', target: 100 },  // Peak load
    { duration: '1m', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    errors: ['rate<0.01'],
  },
};

export default function() {
  const res = http.get('https://api.example.com/endpoint');
  responseTime.add(res.timings.duration);
  errorRate.add(res.status !== 200);
  
  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });
  
  sleep(1);
}
EOF

k6 run load-test.js --out json=results.json

# Autocannon for quick benchmarks
npx autocannon -c 100 -d 30 -p 10 https://api.example.com/endpoint


# === DATABASE PERFORMANCE AUDIT ===

# PostgreSQL slow query analysis
psql -c "
SELECT 
    round(total_exec_time::numeric, 2) as total_ms,
    calls,
    round(mean_exec_time::numeric, 2) as mean_ms,
    round((100 * total_exec_time / sum(total_exec_time) over ())::numeric, 2) as pct,
    substring(query, 1, 100) as query
FROM pg_stat_statements
WHERE total_exec_time > 0
ORDER BY total_exec_time DESC
LIMIT 30;
"

# Index usage analysis
psql -c "
SELECT 
    schemaname, tablename, indexname,
    idx_scan, idx_tup_read, idx_tup_fetch,
    pg_size_pretty(pg_relation_size(indexrelid)) as size
FROM pg_stat_user_indexes
ORDER BY idx_scan ASC
LIMIT 20;
"

# Table bloat check
psql -c "
SELECT 
    schemaname, tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    n_dead_tup,
    n_live_tup,
    round(100.0 * n_dead_tup / nullif(n_live_tup + n_dead_tup, 0), 2) as dead_pct
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;
"


# === BUNDLE ANALYSIS ===

# Webpack bundle analyzer
npx webpack-bundle-analyzer stats.json

# Source map explorer
npx source-map-explorer dist/**/*.js --html bundle-analysis.html

# Next.js bundle analysis
ANALYZE=true npm run build

# Vite bundle analysis
npx vite-bundle-visualizer
```

### Phase 2: Baseline Establishment

```bash
# Create performance baseline document
cat > performance-baseline.json << 'EOF'
{
  "timestamp": "$(date -Iseconds)",
  "environment": "production",
  "metrics": {
    "webVitals": {
      "LCP": { "value": null, "target": 2500, "unit": "ms" },
      "FCP": { "value": null, "target": 1800, "unit": "ms" },
      "CLS": { "value": null, "target": 0.1, "unit": "score" },
      "INP": { "value": null, "target": 200, "unit": "ms" },
      "TTFB": { "value": null, "target": 200, "unit": "ms" }
    },
    "backend": {
      "p50_latency": { "value": null, "target": 100, "unit": "ms" },
      "p95_latency": { "value": null, "target": 500, "unit": "ms" },
      "p99_latency": { "value": null, "target": 1000, "unit": "ms" },
      "throughput": { "value": null, "target": 1000, "unit": "rps" },
      "error_rate": { "value": null, "target": 0.1, "unit": "%" }
    },
    "database": {
      "avg_query_time": { "value": null, "target": 10, "unit": "ms" },
      "slow_queries_pct": { "value": null, "target": 1, "unit": "%" },
      "connection_pool_usage": { "value": null, "target": 70, "unit": "%" }
    },
    "bundle": {
      "js_size": { "value": null, "target": 200, "unit": "KB" },
      "css_size": { "value": null, "target": 50, "unit": "KB" },
      "total_size": { "value": null, "target": 500, "unit": "KB" }
    }
  }
}
EOF
```

---

## Core Web Vitals Optimization

### Largest Contentful Paint (LCP) - Target: < 2.5s

```bash
# === LCP OPTIMIZATION STRATEGIES ===

# 1. Preload critical resources
cat > preload-critical.html << 'EOF'
<!-- Preload hero image -->
<link rel="preload" as="image" href="/hero.webp" fetchpriority="high">

<!-- Preload critical font -->
<link rel="preload" as="font" type="font/woff2" href="/fonts/main.woff2" crossorigin>

<!-- Preload LCP image with fetchpriority -->
<img src="/hero.webp" fetchpriority="high" alt="Hero" loading="eager">
EOF

# 2. Optimize server response time
# See Backend Optimization section

# 3. Resource hints for external origins
cat > resource-hints.html << 'EOF'
<!-- DNS prefetch for CDN -->
<link rel="dns-prefetch" href="//cdn.example.com">

<!-- Preconnect to critical third parties -->
<link rel="preconnect" href="https://fonts.googleapis.com" crossorigin>
<link rel="preconnect" href="https://api.example.com" crossorigin>

<!-- Prefetch next page resources -->
<link rel="prefetch" href="/next-page.js">
EOF

# 4. Image optimization for LCP element
# See Image Optimization section

# 5. Server-side rendering / Static generation
cat > next.config.js << 'EOF'
module.exports = {
  // Enable static optimization
  experimental: {
    optimizeCss: true,
  },
  images: {
    formats: ['image/avif', 'image/webp'],
    deviceSizes: [640, 750, 828, 1080, 1200, 1920],
  },
};
EOF
```

### First Contentful Paint (FCP) - Target: < 1.8s

```bash
# === FCP OPTIMIZATION STRATEGIES ===

# 1. Critical CSS extraction
npx critical https://example.com \
  --base dist \
  --inline \
  --minify \
  --width 1300 \
  --height 900

# 2. Inline critical CSS
cat > critical-css-inline.html << 'EOF'
<head>
  <!-- Inline critical CSS -->
  <style>
    /* Critical above-the-fold styles */
    .header { display: flex; padding: 1rem; }
    .hero { min-height: 60vh; }
    /* ... */
  </style>
  
  <!-- Defer non-critical CSS -->
  <link rel="preload" href="/styles.css" as="style" onload="this.onload=null;this.rel='stylesheet'">
  <noscript><link rel="stylesheet" href="/styles.css"></noscript>
</head>
EOF

# 3. Remove render-blocking resources
cat > defer-scripts.html << 'EOF'
<!-- Defer non-critical JavaScript -->
<script defer src="/analytics.js"></script>
<script defer src="/chat-widget.js"></script>

<!-- Async for independent scripts -->
<script async src="/third-party.js"></script>

<!-- Module scripts are deferred by default -->
<script type="module" src="/app.js"></script>
EOF

# 4. Optimize font loading
cat > font-optimization.css << 'EOF'
/* Font display swap for fast initial render */
@font-face {
  font-family: 'CustomFont';
  src: url('/fonts/custom.woff2') format('woff2');
  font-display: swap;
  font-weight: 400;
}

/* Subset fonts for critical characters */
/* Use unicode-range for language-specific subsets */
@font-face {
  font-family: 'CustomFont';
  src: url('/fonts/custom-latin.woff2') format('woff2');
  unicode-range: U+0000-00FF;
  font-display: swap;
}
EOF

# 5. Minimize main thread work
# - Code split large bundles
# - Defer heavy JavaScript
# - Use web workers for CPU-intensive tasks
```

### Cumulative Layout Shift (CLS) - Target: < 0.1

```bash
# === CLS OPTIMIZATION STRATEGIES ===

# 1. Reserve space for dynamic content
cat > cls-prevention.css << 'EOF'
/* Reserve space for images */
.image-container {
  aspect-ratio: 16 / 9;
  width: 100%;
  background-color: #f0f0f0;
}

/* Reserve space for ads */
.ad-slot {
  min-height: 250px;
  min-width: 300px;
}

/* Reserve space for embeds */
.video-embed {
  aspect-ratio: 16 / 9;
  width: 100%;
}

/* Prevent font swap shifts */
.text-content {
  font-synthesis: none;
  font-optical-sizing: auto;
}
EOF

# 2. Always include size attributes on images
cat > img-sizes.html << 'EOF'
<!-- Always specify width and height -->
<img src="hero.webp" width="1200" height="600" alt="Hero">

<!-- Or use aspect-ratio in CSS -->
<style>
  img { aspect-ratio: attr(width) / attr(height); }
</style>
EOF

# 3. Avoid inserting content above existing content
cat > cls-safe-injection.js << 'EOF'
// BAD: Inserting at top causes shifts
element.prepend(newContent);

// GOOD: Insert at bottom or in reserved space
element.append(newContent);

// GOOD: Use CSS containment for isolated updates
element.style.contain = 'layout';
EOF

# 4. Transform animations instead of layout properties
cat > cls-safe-animations.css << 'EOF'
/* BAD: Animating layout properties causes shifts */
.animate-bad {
  transition: height 0.3s, width 0.3s, margin 0.3s;
}

/* GOOD: Use transform for animations */
.animate-good {
  transition: transform 0.3s, opacity 0.3s;
  will-change: transform;
}

/* GOOD: Scale instead of resize */
.expand {
  transform: scale(1.1);
}
EOF

# 5. Detect CLS issues
cat > detect-cls.js << 'EOF'
// Monitor layout shifts
new PerformanceObserver((entryList) => {
  for (const entry of entryList.getEntries()) {
    if (!entry.hadRecentInput) {
      console.log('Layout shift:', {
        value: entry.value,
        sources: entry.sources?.map(s => ({
          node: s.node,
          previousRect: s.previousRect,
          currentRect: s.currentRect
        }))
      });
    }
  }
}).observe({ type: 'layout-shift', buffered: true });
EOF
```

### Interaction to Next Paint (INP) - Target: < 200ms

```bash
# === INP OPTIMIZATION STRATEGIES ===

# 1. Break up long tasks
cat > long-task-splitting.js << 'EOF'
// BAD: Single long task
function processAllItems(items) {
  items.forEach(item => expensiveOperation(item));
}

// GOOD: Yield to main thread
async function processAllItems(items) {
  for (const item of items) {
    expensiveOperation(item);
    
    // Yield every 50ms
    if (Date.now() - lastYield > 50) {
      await scheduler.yield(); // If available
      // Or fallback:
      // await new Promise(r => setTimeout(r, 0));
      lastYield = Date.now();
    }
  }
}

// GOOD: Use requestIdleCallback
function processInIdle(items) {
  const iterator = items[Symbol.iterator]();
  
  function processChunk(deadline) {
    while (deadline.timeRemaining() > 5) {
      const { value, done } = iterator.next();
      if (done) return;
      expensiveOperation(value);
    }
    requestIdleCallback(processChunk);
  }
  
  requestIdleCallback(processChunk);
}
EOF

# 2. Debounce/throttle input handlers
cat > input-optimization.js << 'EOF'
// Debounce search input
const debouncedSearch = debounce((query) => {
  performSearch(query);
}, 300);

searchInput.addEventListener('input', (e) => {
  debouncedSearch(e.target.value);
});

// Use passive event listeners
element.addEventListener('scroll', handler, { passive: true });
element.addEventListener('touchstart', handler, { passive: true });
EOF

# 3. Optimize event handlers
cat > event-optimization.js << 'EOF'
// BAD: Heavy synchronous work in handler
button.onclick = () => {
  const data = heavyComputation();
  updateUI(data);
};

// GOOD: Immediate visual feedback, defer heavy work
button.onclick = () => {
  // Immediate feedback
  button.classList.add('loading');
  
  // Defer heavy work
  requestAnimationFrame(() => {
    queueMicrotask(() => {
      const data = heavyComputation();
      updateUI(data);
      button.classList.remove('loading');
    });
  });
};

// GOOD: Use web workers for CPU-intensive tasks
const worker = new Worker('compute-worker.js');
button.onclick = () => {
  button.classList.add('loading');
  worker.postMessage({ type: 'compute', data: inputData });
};
worker.onmessage = (e) => {
  updateUI(e.data);
  button.classList.remove('loading');
};
EOF

# 4. Reduce JavaScript execution time
# - Code splitting
# - Tree shaking
# - Minification
# - Avoid polyfills for modern browsers

# 5. Monitor long tasks
cat > monitor-long-tasks.js << 'EOF'
new PerformanceObserver((entryList) => {
  for (const entry of entryList.getEntries()) {
    if (entry.duration > 50) {
      console.warn('Long task detected:', {
        duration: entry.duration,
        startTime: entry.startTime,
        attribution: entry.attribution
      });
    }
  }
}).observe({ type: 'longtask', buffered: true });
EOF
```

---

## Backend Response Time Optimization

### Server-Side Optimization

```bash
# === NODE.JS OPTIMIZATION ===

# 1. Enable clustering
cat > cluster-server.js << 'EOF'
const cluster = require('cluster');
const numCPUs = require('os').cpus().length;

if (cluster.isPrimary) {
  console.log(`Primary ${process.pid} starting ${numCPUs} workers`);
  
  for (let i = 0; i < numCPUs; i++) {
    cluster.fork();
  }
  
  cluster.on('exit', (worker, code, signal) => {
    console.log(`Worker ${worker.process.pid} died, restarting...`);
    cluster.fork();
  });
} else {
  require('./app.js');
}
EOF

# 2. Compression middleware
cat > compression-config.js << 'EOF'
const compression = require('compression');

app.use(compression({
  level: 6,
  threshold: 1024,
  filter: (req, res) => {
    if (req.headers['x-no-compression']) {
      return false;
    }
    return compression.filter(req, res);
  }
}));
EOF

# 3. Response caching
cat > response-cache.js << 'EOF'
const mcache = require('memory-cache');

const cache = (duration) => {
  return (req, res, next) => {
    const key = '__express__' + req.originalUrl;
    const cachedBody = mcache.get(key);
    
    if (cachedBody) {
      res.send(cachedBody);
      return;
    }
    
    res.sendResponse = res.send;
    res.send = (body) => {
      mcache.put(key, body, duration * 1000);
      res.sendResponse(body);
    };
    next();
  };
};

// Cache for 5 minutes
app.get('/api/data', cache(300), (req, res) => {
  // expensive operation
});
EOF

# 4. Connection pooling
cat > pool-config.js << 'EOF'
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST,
  port: 5432,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  max: 20,                      // Maximum connections
  idleTimeoutMillis: 30000,     // Close idle connections after 30s
  connectionTimeoutMillis: 2000, // Timeout after 2s
});

// Reuse connections
app.get('/api/users', async (req, res) => {
  const client = await pool.connect();
  try {
    const result = await client.query('SELECT * FROM users');
    res.json(result.rows);
  } finally {
    client.release();
  }
});
EOF


# === PYTHON/FASTAPI OPTIMIZATION ===

cat > fastapi-optimization.py << 'EOF'
from fastapi import FastAPI
from fastapi.middleware.gzip import GZipMiddleware
from fastapi_cache import FastAPICache
from fastapi_cache.backends.redis import RedisBackend
from redis import asyncio as aioredis
import uvicorn

app = FastAPI()

# GZip compression
app.add_middleware(GZipMiddleware, minimum_size=1000)

# Redis caching
@app.on_event("startup")
async def startup():
    redis = aioredis.from_url("redis://localhost")
    FastAPICache.init(RedisBackend(redis), prefix="fastapi-cache")

# Response caching decorator
from fastapi_cache.decorator import cache

@app.get("/api/data")
@cache(expire=300)  # 5 minutes
async def get_data():
    # expensive operation
    return {"data": result}

# Connection pooling with async
from databases import Database
database = Database(DATABASE_URL, min_size=5, max_size=20)

@app.on_event("startup")
async def connect_db():
    await database.connect()

@app.on_event("shutdown")
async def disconnect_db():
    await database.disconnect()

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        workers=4,
        loop="uvloop",
        http="httptools"
    )
EOF


# === GO OPTIMIZATION ===

cat > go-optimization.go << 'EOF'
package main

import (
    "net/http"
    "time"
    
    "github.com/go-chi/chi/v5"
    "github.com/go-chi/chi/v5/middleware"
)

func main() {
    r := chi.NewRouter()
    
    // Compression
    r.Use(middleware.Compress(5))
    
    // Timeout
    r.Use(middleware.Timeout(30 * time.Second))
    
    // Rate limiting
    r.Use(middleware.Throttle(100))
    
    // Profiling endpoint
    r.Mount("/debug", middleware.Profiler())
    
    http.ListenAndServe(":8080", r)
}
EOF
```

### API Response Optimization

```bash
# === RESPONSE PAYLOAD OPTIMIZATION ===

# 1. Field filtering (sparse fieldsets)
cat > field-filtering.js << 'EOF'
// Allow clients to request specific fields
app.get('/api/users', (req, res) => {
  const fields = req.query.fields?.split(',') || null;
  
  let users = await User.findAll();
  
  if (fields) {
    users = users.map(user => 
      fields.reduce((obj, field) => {
        if (user[field] !== undefined) obj[field] = user[field];
        return obj;
      }, {})
    );
  }
  
  res.json(users);
});
// Usage: GET /api/users?fields=id,name,email
EOF

# 2. Pagination
cat > pagination.js << 'EOF'
app.get('/api/items', async (req, res) => {
  const page = parseInt(req.query.page) || 1;
  const limit = Math.min(parseInt(req.query.limit) || 20, 100);
  const offset = (page - 1) * limit;
  
  const [items, total] = await Promise.all([
    Item.findAll({ limit, offset }),
    Item.count()
  ]);
  
  res.json({
    data: items,
    pagination: {
      page,
      limit,
      total,
      pages: Math.ceil(total / limit),
      hasNext: page * limit < total,
      hasPrev: page > 1
    }
  });
});
EOF

# 3. Response compression with proper content types
cat > compression-types.js << 'EOF'
const compression = require('compression');

app.use(compression({
  filter: (req, res) => {
    const type = res.getHeader('Content-Type');
    // Compress text-based responses
    return /json|text|javascript|css|html|xml|svg/.test(type);
  }
}));
EOF

# 4. ETag caching
cat > etag-caching.js << 'EOF'
const crypto = require('crypto');

function generateETag(data) {
  return crypto.createHash('md5').update(JSON.stringify(data)).digest('hex');
}

app.get('/api/resource/:id', async (req, res) => {
  const data = await fetchResource(req.params.id);
  const etag = generateETag(data);
  
  res.set('ETag', etag);
  res.set('Cache-Control', 'private, max-age=0, must-revalidate');
  
  if (req.headers['if-none-match'] === etag) {
    return res.status(304).end();
  }
  
  res.json(data);
});
EOF
```

---

## Database Query Optimization

### Query Analysis and Optimization

```bash
# === POSTGRESQL OPTIMIZATION ===

# 1. Identify slow queries
psql -c "
SELECT 
    round(total_exec_time::numeric, 2) as total_ms,
    calls,
    round(mean_exec_time::numeric, 2) as mean_ms,
    rows,
    round((100 * total_exec_time / sum(total_exec_time) over ())::numeric, 2) as pct,
    substring(query, 1, 80) as query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
"

# 2. Analyze query execution plan
psql -c "
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT u.*, COUNT(o.id) as order_count
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
WHERE u.created_at > NOW() - INTERVAL '30 days'
GROUP BY u.id
ORDER BY order_count DESC
LIMIT 10;
"

# 3. Create optimal indexes
psql -c "
-- Partial index for active users
CREATE INDEX CONCURRENTLY idx_users_active 
ON users (email) 
WHERE status = 'active';

-- Composite index for common queries
CREATE INDEX CONCURRENTLY idx_orders_user_date 
ON orders (user_id, created_at DESC);

-- Covering index to avoid table lookups
CREATE INDEX CONCURRENTLY idx_products_category_covering 
ON products (category_id) 
INCLUDE (name, price, stock);

-- Expression index for case-insensitive search
CREATE INDEX CONCURRENTLY idx_users_email_lower 
ON users (LOWER(email));
"

# 4. Optimize N+1 queries
cat > n-plus-one-fix.js << 'EOF'
// BAD: N+1 queries
const users = await User.findAll();
for (const user of users) {
  user.orders = await Order.findAll({ where: { userId: user.id } });
}

// GOOD: Single query with JOIN or include
const users = await User.findAll({
  include: [{
    model: Order,
    as: 'orders',
    where: { status: 'active' },
    required: false
  }]
});

// GOOD: Batch loading with DataLoader
const orderLoader = new DataLoader(async (userIds) => {
  const orders = await Order.findAll({
    where: { userId: { [Op.in]: userIds } }
  });
  
  const ordersByUser = userIds.map(id => 
    orders.filter(o => o.userId === id)
  );
  return ordersByUser;
});

// Usage in resolver
const user = await User.findByPk(id);
const orders = await orderLoader.load(user.id);
EOF

# 5. Connection pool optimization
cat > pool-tuning.sql << 'EOF'
-- Check current connections
SELECT count(*) FROM pg_stat_activity;

-- Optimal pool size formula:
-- connections = ((core_count * 2) + effective_spindle_count)
-- For SSD: connections = (core_count * 2) + 1

-- Set connection limits
ALTER SYSTEM SET max_connections = 200;
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET work_mem = '16MB';

-- Reload configuration
SELECT pg_reload_conf();
EOF
```

### Query Patterns and Anti-Patterns

```bash
# === QUERY OPTIMIZATION PATTERNS ===

cat > query-patterns.sql << 'EOF'
-- ANTI-PATTERN: SELECT * (fetches unnecessary data)
SELECT * FROM users WHERE id = 1;

-- PATTERN: Select only needed columns
SELECT id, name, email FROM users WHERE id = 1;


-- ANTI-PATTERN: OR conditions on different columns
SELECT * FROM products WHERE category_id = 5 OR brand_id = 10;

-- PATTERN: Use UNION for different indexes
SELECT * FROM products WHERE category_id = 5
UNION
SELECT * FROM products WHERE brand_id = 10;


-- ANTI-PATTERN: Function on indexed column
SELECT * FROM users WHERE LOWER(email) = 'test@example.com';

-- PATTERN: Store normalized data or use expression index
SELECT * FROM users WHERE email_lower = 'test@example.com';


-- ANTI-PATTERN: LIKE with leading wildcard
SELECT * FROM products WHERE name LIKE '%widget%';

-- PATTERN: Use full-text search
SELECT * FROM products 
WHERE to_tsvector('english', name) @@ to_tsquery('widget');


-- ANTI-PATTERN: Large OFFSET for pagination
SELECT * FROM orders ORDER BY created_at DESC LIMIT 10 OFFSET 100000;

-- PATTERN: Keyset pagination
SELECT * FROM orders 
WHERE created_at < '2024-01-15T10:30:00Z'
ORDER BY created_at DESC 
LIMIT 10;


-- PATTERN: Batch inserts
INSERT INTO events (type, data, created_at) VALUES
  ('click', '{}', NOW()),
  ('view', '{}', NOW()),
  ('purchase', '{}', NOW());


-- PATTERN: Use COPY for bulk imports
COPY events FROM '/tmp/events.csv' CSV HEADER;


-- PATTERN: Partial indexes for filtered queries
CREATE INDEX idx_orders_pending ON orders (created_at)
WHERE status = 'pending';
EOF
```

---

## Caching Strategy Design

### Multi-Layer Caching Architecture

```bash
# === CACHING LAYERS ===

cat > caching-architecture.md << 'EOF'
# Multi-Layer Caching Strategy

## Layer 1: Browser Cache (Client-Side)
- Static assets: 1 year (immutable with hash)
- HTML: no-cache or short TTL
- API responses: varies by endpoint

## Layer 2: CDN Cache (Edge)
- Static assets: 1 year
- Dynamic content: short TTL or stale-while-revalidate
- API responses: varies by endpoint

## Layer 3: Application Cache (In-Memory)
- Session data
- Frequently accessed DB queries
- Computed values

## Layer 4: Distributed Cache (Redis/Memcached)
- Shared state across instances
- Database query results
- Rate limiting counters
- Session storage

## Layer 5: Database Query Cache
- Query plan caching
- Result set caching
- Prepared statement caching
EOF

# 1. Browser caching headers
cat > cache-headers.js << 'EOF'
const express = require('express');
const app = express();

// Static assets - immutable
app.use('/static', express.static('public', {
  maxAge: '1y',
  immutable: true,
  etag: false
}));

// API endpoints with validation
app.get('/api/config', (req, res) => {
  res.set({
    'Cache-Control': 'public, max-age=300, stale-while-revalidate=60',
    'ETag': generateETag(config),
    'Vary': 'Accept-Encoding, Accept-Language'
  });
  res.json(config);
});

// Private user data
app.get('/api/user/profile', (req, res) => {
  res.set({
    'Cache-Control': 'private, no-cache, must-revalidate',
    'ETag': generateETag(profile)
  });
  res.json(profile);
});

// No caching for sensitive endpoints
app.get('/api/auth/status', (req, res) => {
  res.set({
    'Cache-Control': 'no-store',
    'Pragma': 'no-cache'
  });
  res.json({ authenticated: true });
});
EOF

# 2. Redis caching implementation
cat > redis-cache.js << 'EOF'
const Redis = require('ioredis');
const redis = new Redis({
  host: process.env.REDIS_HOST,
  port: 6379,
  maxRetriesPerRequest: 3,
  retryDelayOnFailover: 100
});

// Cache-aside pattern
async function getUser(userId) {
  const cacheKey = `user:${userId}`;
  
  // Try cache first
  let user = await redis.get(cacheKey);
  if (user) {
    return JSON.parse(user);
  }
  
  // Fetch from database
  user = await db.query('SELECT * FROM users WHERE id = $1', [userId]);
  
  // Store in cache
  await redis.setex(cacheKey, 3600, JSON.stringify(user));
  
  return user;
}

// Write-through pattern
async function updateUser(userId, data) {
  // Update database
  const user = await db.query(
    'UPDATE users SET name = $2 WHERE id = $1 RETURNING *',
    [userId, data.name]
  );
  
  // Update cache
  const cacheKey = `user:${userId}`;
  await redis.setex(cacheKey, 3600, JSON.stringify(user));
  
  return user;
}

// Cache invalidation
async function invalidateUserCache(userId) {
  const patterns = [
    `user:${userId}`,
    `user:${userId}:orders`,
    `user:${userId}:preferences`
  ];
  
  const pipeline = redis.pipeline();
  patterns.forEach(key => pipeline.del(key));
  await pipeline.exec();
}
EOF

# 3. Application-level memoization
cat > memoization.js << 'EOF'
// Simple memoization
function memoize(fn, ttl = 60000) {
  const cache = new Map();
  
  return async function(...args) {
    const key = JSON.stringify(args);
    const cached = cache.get(key);
    
    if (cached && Date.now() < cached.expiry) {
      return cached.value;
    }
    
    const result = await fn.apply(this, args);
    cache.set(key, { value: result, expiry: Date.now() + ttl });
    
    return result;
  };
}

// LRU cache with size limit
const LRU = require('lru-cache');

const cache = new LRU({
  max: 500,
  ttl: 1000 * 60 * 5, // 5 minutes
  updateAgeOnGet: true,
  updateAgeOnHas: true
});

async function getExpensiveData(id) {
  if (cache.has(id)) {
    return cache.get(id);
  }
  
  const data = await expensiveComputation(id);
  cache.set(id, data);
  return data;
}
EOF
```

### Cache Invalidation Strategies

```bash
# === CACHE INVALIDATION PATTERNS ===

cat > cache-invalidation.js << 'EOF'
// 1. Time-based expiration (TTL)
await redis.setex('key', 3600, value); // Expires in 1 hour

// 2. Event-based invalidation
eventEmitter.on('user:updated', async (userId) => {
  await redis.del(`user:${userId}`);
  await redis.del(`user:${userId}:computed`);
});

// 3. Version-based invalidation
async function getWithVersion(key) {
  const version = await redis.get('cache:version');
  const versionedKey = `${key}:v${version}`;
  return redis.get(versionedKey);
}

async function incrementCacheVersion() {
  await redis.incr('cache:version');
}

// 4. Tag-based invalidation
async function setWithTags(key, value, tags) {
  const pipeline = redis.pipeline();
  pipeline.set(key, value);
  tags.forEach(tag => {
    pipeline.sadd(`tag:${tag}`, key);
  });
  await pipeline.exec();
}

async function invalidateByTag(tag) {
  const keys = await redis.smembers(`tag:${tag}`);
  if (keys.length > 0) {
    await redis.del(...keys);
    await redis.del(`tag:${tag}`);
  }
}

// 5. Stale-while-revalidate pattern
async function getWithSWR(key, fetchFn, ttl = 300, staleTime = 60) {
  const cached = await redis.get(key);
  const metadata = await redis.get(`${key}:meta`);
  
  if (cached) {
    const meta = JSON.parse(metadata || '{}');
    const age = Date.now() - (meta.timestamp || 0);
    
    // If stale but within grace period, return and refresh in background
    if (age > ttl * 1000 && age < (ttl + staleTime) * 1000) {
      // Async refresh
      fetchFn().then(data => {
        redis.setex(key, ttl + staleTime, JSON.stringify(data));
        redis.setex(`${key}:meta`, ttl + staleTime, 
          JSON.stringify({ timestamp: Date.now() }));
      });
    }
    
    return JSON.parse(cached);
  }
  
  // Cache miss - fetch and store
  const data = await fetchFn();
  await redis.setex(key, ttl + staleTime, JSON.stringify(data));
  await redis.setex(`${key}:meta`, ttl + staleTime,
    JSON.stringify({ timestamp: Date.now() }));
  
  return data;
}
EOF
```

---

## CDN Configuration

### CDN Setup and Optimization

```bash
# === CLOUDFLARE CONFIGURATION ===

cat > cloudflare-config.json << 'EOF'
{
  "cache_rules": [
    {
      "name": "Static Assets - Long Cache",
      "expression": "(http.request.uri.path matches \"\\.(js|css|woff2|avif|webp|png|jpg|svg)$\")",
      "action": {
        "cache_control": {
          "browser_ttl": 31536000,
          "edge_ttl": 31536000
        },
        "respect_strong_etags": true
      }
    },
    {
      "name": "HTML - Short Cache with Revalidation",
      "expression": "(http.request.uri.path eq \"/\" or http.request.uri.path matches \"\\.html$\")",
      "action": {
        "cache_control": {
          "browser_ttl": 0,
          "edge_ttl": 300,
          "stale_while_revalidate": 60
        }
      }
    },
    {
      "name": "API - Vary by Auth",
      "expression": "(starts_with(http.request.uri.path, \"/api/\"))",
      "action": {
        "cache_control": {
          "bypass_cache_on_cookie": "session_id",
          "vary_headers": ["Authorization", "Accept-Language"]
        }
      }
    }
  ],
  "page_rules": {
    "/api/*": {
      "cache_level": "bypass",
      "origin_cache_control": true
    },
    "/*.js": {
      "cache_level": "cache_everything",
      "edge_cache_ttl": 2592000
    }
  },
  "settings": {
    "auto_minify": {
      "javascript": true,
      "css": true,
      "html": true
    },
    "brotli": "on",
    "early_hints": "on",
    "rocket_loader": "off",
    "polish": "lossless",
    "webp": "on",
    "mirage": "on"
  }
}
EOF


# === AWS CLOUDFRONT CONFIGURATION ===

cat > cloudfront-config.yaml << 'EOF'
AWSTemplateFormatVersion: '2010-09-09'
Resources:
  Distribution:
    Type: AWS::CloudFront::Distribution
    Properties:
      DistributionConfig:
        Origins:
          - DomainName: origin.example.com
            Id: S3Origin
            CustomOriginConfig:
              HTTPSPort: 443
              OriginProtocolPolicy: https-only
        
        DefaultCacheBehavior:
          TargetOriginId: S3Origin
          ViewerProtocolPolicy: redirect-to-https
          CachePolicyId: !Ref OptimizedCachePolicy
          Compress: true
          
        CacheBehaviors:
          - PathPattern: "/static/*"
            TargetOriginId: S3Origin
            CachePolicyId: !Ref StaticAssetsCachePolicy
            Compress: true
            
          - PathPattern: "/api/*"
            TargetOriginId: APIOrigin
            CachePolicyId: !Ref APICachePolicy
            OriginRequestPolicyId: !Ref APIOriginRequestPolicy
            
        HttpVersion: http2and3
        PriceClass: PriceClass_100

  StaticAssetsCachePolicy:
    Type: AWS::CloudFront::CachePolicy
    Properties:
      CachePolicyConfig:
        Name: StaticAssetsPolicy
        DefaultTTL: 86400
        MaxTTL: 31536000
        MinTTL: 0
        ParametersInCacheKeyAndForwardedToOrigin:
          EnableAcceptEncodingBrotli: true
          EnableAcceptEncodingGzip: true
          HeadersConfig:
            HeaderBehavior: none
          QueryStringsConfig:
            QueryStringBehavior: none
          CookiesConfig:
            CookieBehavior: none

  APICachePolicy:
    Type: AWS::CloudFront::CachePolicy
    Properties:
      CachePolicyConfig:
        Name: APICachePolicy
        DefaultTTL: 0
        MaxTTL: 60
        MinTTL: 0
        ParametersInCacheKeyAndForwardedToOrigin:
          EnableAcceptEncodingBrotli: true
          EnableAcceptEncodingGzip: true
          HeadersConfig:
            HeaderBehavior: whitelist
            Headers:
              - Authorization
              - Accept-Language
          QueryStringsConfig:
            QueryStringBehavior: all
          CookiesConfig:
            CookieBehavior: none
EOF


# === CACHE-CONTROL HEADERS REFERENCE ===

cat > cache-control-reference.md << 'EOF'
# Cache-Control Header Reference

## Directives

| Directive | Description |
|-----------|-------------|
| `public` | Can be cached by any cache |
| `private` | Only browser can cache |
| `no-cache` | Must revalidate before using cache |
| `no-store` | Don't cache at all |
| `max-age=N` | Cache for N seconds |
| `s-maxage=N` | CDN cache for N seconds |
| `stale-while-revalidate=N` | Serve stale while refreshing |
| `stale-if-error=N` | Serve stale on origin error |
| `immutable` | Content will never change |
| `must-revalidate` | Don't serve stale content |

## Recommended Patterns

### Static Assets (versioned)
```
Cache-Control: public, max-age=31536000, immutable
```

### HTML Documents
```
Cache-Control: public, max-age=0, must-revalidate
```

### API with CDN
```
Cache-Control: public, max-age=60, s-maxage=300, stale-while-revalidate=60
```

### User-Specific Data
```
Cache-Control: private, no-cache
```

### Sensitive Data
```
Cache-Control: no-store
```
EOF
```

---

## Image and Asset Optimization

### Image Optimization Pipeline

```bash
# === IMAGE OPTIMIZATION ===

# 1. Convert to modern formats
cat > image-convert.sh << 'EOF'
#!/bin/bash

INPUT_DIR="./images/original"
OUTPUT_DIR="./images/optimized"

mkdir -p "$OUTPUT_DIR"/{webp,avif}

# Convert to WebP
for img in "$INPUT_DIR"/*.{jpg,jpeg,png}; do
  [ -f "$img" ] || continue
  filename=$(basename "$img" | sed 's/\.[^.]*$//')
  cwebp -q 80 "$img" -o "$OUTPUT_DIR/webp/${filename}.webp"
done

# Convert to AVIF (smaller, better quality)
for img in "$INPUT_DIR"/*.{jpg,jpeg,png}; do
  [ -f "$img" ] || continue
  filename=$(basename "$img" | sed 's/\.[^.]*$//')
  avifenc --min 0 --max 63 -a end-usage=q -a cq-level=30 "$img" "$OUTPUT_DIR/avif/${filename}.avif"
done
EOF

# 2. Responsive images generation
cat > responsive-images.sh << 'EOF'
#!/bin/bash

INPUT="$1"
OUTPUT_DIR="./images/responsive"
WIDTHS=(320 640 768 1024 1280 1920)

filename=$(basename "$INPUT" | sed 's/\.[^.]*$//')

for width in "${WIDTHS[@]}"; do
  # WebP
  convert "$INPUT" -resize "${width}x>" -quality 80 \
    "$OUTPUT_DIR/${filename}-${width}w.webp"
  
  # AVIF
  convert "$INPUT" -resize "${width}x>" -quality 80 png:- | \
    avifenc --min 0 --max 63 -a end-usage=q -a cq-level=30 - \
    "$OUTPUT_DIR/${filename}-${width}w.avif"
done
EOF

# 3. HTML picture element with srcset
cat > responsive-picture.html << 'EOF'
<picture>
  <!-- AVIF for modern browsers -->
  <source
    type="image/avif"
    srcset="
      /images/hero-320w.avif 320w,
      /images/hero-640w.avif 640w,
      /images/hero-1024w.avif 1024w,
      /images/hero-1920w.avif 1920w
    "
    sizes="(max-width: 640px) 100vw, (max-width: 1024px) 80vw, 1200px"
  >
  
  <!-- WebP fallback -->
  <source
    type="image/webp"
    srcset="
      /images/hero-320w.webp 320w,
      /images/hero-640w.webp 640w,
      /images/hero-1024w.webp 1024w,
      /images/hero-1920w.webp 1920w
    "
    sizes="(max-width: 640px) 100vw, (max-width: 1024px) 80vw, 1200px"
  >
  
  <!-- JPEG fallback -->
  <img
    src="/images/hero-1024w.jpg"
    srcset="
      /images/hero-320w.jpg 320w,
      /images/hero-640w.jpg 640w,
      /images/hero-1024w.jpg 1024w,
      /images/hero-1920w.jpg 1920w
    "
    sizes="(max-width: 640px) 100vw, (max-width: 1024px) 80vw, 1200px"
    alt="Hero image"
    loading="lazy"
    decoding="async"
    width="1920"
    height="1080"
  >
</picture>
EOF

# 4. Next.js Image component configuration
cat > next-image-config.js << 'EOF'
// next.config.js
module.exports = {
  images: {
    formats: ['image/avif', 'image/webp'],
    deviceSizes: [640, 750, 828, 1080, 1200, 1920, 2048, 3840],
    imageSizes: [16, 32, 48, 64, 96, 128, 256, 384],
    minimumCacheTTL: 60 * 60 * 24 * 30, // 30 days
    dangerouslyAllowSVG: false,
    contentSecurityPolicy: "default-src 'self'; script-src 'none'; sandbox;",
  },
};

// Usage
import Image from 'next/image';

<Image
  src="/hero.jpg"
  alt="Hero"
  width={1920}
  height={1080}
  priority // For LCP images
  placeholder="blur"
  blurDataURL="data:image/jpeg;base64,..."
/>
EOF

# 5. Sharp for server-side optimization
cat > sharp-optimization.js << 'EOF'
const sharp = require('sharp');

async function optimizeImage(input, output, options = {}) {
  const {
    width,
    quality = 80,
    format = 'webp'
  } = options;

  let pipeline = sharp(input);
  
  if (width) {
    pipeline = pipeline.resize(width, null, {
      withoutEnlargement: true,
      fit: 'inside'
    });
  }
  
  switch (format) {
    case 'webp':
      pipeline = pipeline.webp({ quality, effort: 6 });
      break;
    case 'avif':
      pipeline = pipeline.avif({ quality, effort: 6 });
      break;
    case 'jpeg':
      pipeline = pipeline.jpeg({ quality, progressive: true, mozjpeg: true });
      break;
  }
  
  await pipeline.toFile(output);
}

// Generate all variants
async function generateResponsiveImages(input, outputDir) {
  const widths = [320, 640, 768, 1024, 1280, 1920];
  const formats = ['webp', 'avif'];
  
  for (const width of widths) {
    for (const format of formats) {
      await optimizeImage(input, `${outputDir}/image-${width}w.${format}`, {
        width,
        format
      });
    }
  }
}
EOF
```

### CSS and JavaScript Optimization

```bash
# === BUNDLE OPTIMIZATION ===

# 1. CSS optimization
cat > postcss.config.js << 'EOF'
module.exports = {
  plugins: [
    require('postcss-import'),
    require('tailwindcss'),
    require('autoprefixer'),
    require('cssnano')({
      preset: ['advanced', {
        discardComments: { removeAll: true },
        reduceIdents: false,
        zindex: false
      }]
    })
  ]
};
EOF

# 2. PurgeCSS configuration
cat > purgecss.config.js << 'EOF'
module.exports = {
  content: [
    './src/**/*.{js,jsx,ts,tsx}',
    './public/index.html'
  ],
  defaultExtractor: content => content.match(/[\w-/:]+(?<!:)/g) || [],
  safelist: {
    standard: [/^modal/, /^toast/],
    deep: [/^data-/],
    greedy: [/animate/]
  }
};
EOF

# 3. JavaScript minification with Terser
cat > terser.config.js << 'EOF'
module.exports = {
  compress: {
    dead_code: true,
    drop_console: true,
    drop_debugger: true,
    pure_funcs: ['console.log', 'console.info'],
    passes: 2
  },
  mangle: {
    safari10: true,
    properties: {
      regex: /^_/  // Mangle private properties starting with _
    }
  },
  format: {
    comments: false
  }
};
EOF

# 4. Webpack optimization
cat > webpack.optimization.js << 'EOF'
module.exports = {
  optimization: {
    minimize: true,
    minimizer: [
      new TerserPlugin({
        parallel: true,
        terserOptions: {
          compress: { drop_console: true }
        }
      }),
      new CssMinimizerPlugin()
    ],
    splitChunks: {
      chunks: 'all',
      maxInitialRequests: 25,
      minSize: 20000,
      cacheGroups: {
        vendor: {
          test: /[\\/]node_modules[\\/]/,
          name(module) {
            const packageName = module.context.match(
              /[\\/]node_modules[\\/](.*?)([\\/]|$)/
            )[1];
            return `vendor.${packageName.replace('@', '')}`;
          },
          priority: -10
        },
        common: {
          minChunks: 2,
          priority: -20,
          reuseExistingChunk: true
        }
      }
    },
    runtimeChunk: 'single',
    moduleIds: 'deterministic'
  }
};
EOF
```

---

## Code Splitting and Lazy Loading

### Code Splitting Strategies

```bash
# === REACT CODE SPLITTING ===

cat > code-splitting-react.tsx << 'EOF'
import React, { Suspense, lazy } from 'react';
import { Routes, Route } from 'react-router-dom';

// Lazy load route components
const Home = lazy(() => import('./pages/Home'));
const Dashboard = lazy(() => import('./pages/Dashboard'));
const Settings = lazy(() => import('./pages/Settings'));

// Preload on hover/focus
const preloadComponent = (importFn: () => Promise<any>) => {
  return () => {
    importFn(); // Start loading
  };
};

// Named exports require different syntax
const Analytics = lazy(() => 
  import('./pages/Analytics').then(module => ({ default: module.Analytics }))
);

// Loading fallback component
function PageLoader() {
  return (
    <div className="page-loader">
      <div className="spinner" />
      <p>Loading...</p>
    </div>
  );
}

// Error boundary for lazy components
class ErrorBoundary extends React.Component {
  state = { hasError: false };
  
  static getDerivedStateFromError() {
    return { hasError: true };
  }
  
  render() {
    if (this.state.hasError) {
      return <div>Failed to load. <button onClick={() => window.location.reload()}>Retry</button></div>;
    }
    return this.props.children;
  }
}

// App with code splitting
function App() {
  return (
    <ErrorBoundary>
      <Suspense fallback={<PageLoader />}>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="/settings" element={<Settings />} />
          <Route path="/analytics" element={<Analytics />} />
        </Routes>
      </Suspense>
    </ErrorBoundary>
  );
}

// Prefetch links
function NavLink({ to, children, importFn }) {
  return (
    <Link
      to={to}
      onMouseEnter={preloadComponent(importFn)}
      onFocus={preloadComponent(importFn)}
    >
      {children}
    </Link>
  );
}
EOF


# === NEXT.JS CODE SPLITTING ===

cat > code-splitting-nextjs.tsx << 'EOF'
import dynamic from 'next/dynamic';

// Dynamic import with loading state
const DynamicChart = dynamic(() => import('../components/Chart'), {
  loading: () => <div className="chart-skeleton" />,
  ssr: false // Disable SSR for client-only components
});

// Dynamic import with suspense
const DynamicEditor = dynamic(() => import('../components/Editor'), {
  suspense: true
});

// Conditional loading
const DynamicMap = dynamic(
  () => import('../components/Map'),
  { 
    ssr: false,
    loading: () => <MapSkeleton />
  }
);

// Usage with Suspense
import { Suspense } from 'react';

function Dashboard() {
  return (
    <div>
      <h1>Dashboard</h1>
      
      {/* Component with built-in loading */}
      <DynamicChart data={chartData} />
      
      {/* Component with Suspense */}
      <Suspense fallback={<EditorSkeleton />}>
        <DynamicEditor />
      </Suspense>
      
      {/* Conditionally loaded */}
      {showMap && <DynamicMap location={location} />}
    </div>
  );
}
EOF


# === VUE CODE SPLITTING ===

cat > code-splitting-vue.js << 'EOF'
// Router-level code splitting
const routes = [
  {
    path: '/',
    component: () => import('./views/Home.vue')
  },
  {
    path: '/dashboard',
    component: () => import(
      /* webpackChunkName: "dashboard" */
      /* webpackPrefetch: true */
      './views/Dashboard.vue'
    )
  },
  {
    path: '/settings',
    component: () => import(
      /* webpackChunkName: "settings" */
      './views/Settings.vue'
    )
  }
];

// Component-level code splitting
import { defineAsyncComponent } from 'vue';

const AsyncChart = defineAsyncComponent({
  loader: () => import('./components/Chart.vue'),
  loadingComponent: LoadingSpinner,
  errorComponent: ErrorDisplay,
  delay: 200,
  timeout: 10000
});
EOF


# === IMAGE LAZY LOADING ===

cat > lazy-loading-images.html << 'EOF'
<!-- Native lazy loading (recommended) -->
<img 
  src="image.webp" 
  loading="lazy"
  decoding="async"
  width="800"
  height="600"
  alt="Description"
>

<!-- Intersection Observer for advanced control -->
<script>
const lazyImages = document.querySelectorAll('img[data-src]');

const imageObserver = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      const img = entry.target;
      img.src = img.dataset.src;
      img.srcset = img.dataset.srcset || '';
      img.classList.add('loaded');
      imageObserver.unobserve(img);
    }
  });
}, {
  rootMargin: '50px 0px', // Load 50px before viewport
  threshold: 0.01
});

lazyImages.forEach(img => imageObserver.observe(img));
</script>

<!-- With placeholder -->
<img
  class="lazy"
  src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 800 600'%3E%3C/svg%3E"
  data-src="image.webp"
  data-srcset="image-400.webp 400w, image-800.webp 800w"
  width="800"
  height="600"
  alt="Description"
>
EOF
```

---

## Performance Monitoring Setup

### Real User Monitoring (RUM)

```bash
# === WEB VITALS MONITORING ===

cat > web-vitals-monitoring.js << 'EOF'
import { onCLS, onFCP, onLCP, onINP, onTTFB } from 'web-vitals';

// Analytics endpoint
const ANALYTICS_ENDPOINT = '/api/analytics/vitals';

function sendToAnalytics(metric) {
  const body = JSON.stringify({
    name: metric.name,
    value: metric.value,
    rating: metric.rating,
    delta: metric.delta,
    id: metric.id,
    navigationType: metric.navigationType,
    page: window.location.pathname,
    timestamp: Date.now(),
    // Additional context
    connection: navigator.connection?.effectiveType,
    deviceMemory: navigator.deviceMemory,
    hardwareConcurrency: navigator.hardwareConcurrency
  });

  // Use sendBeacon for reliability
  if (navigator.sendBeacon) {
    navigator.sendBeacon(ANALYTICS_ENDPOINT, body);
  } else {
    fetch(ANALYTICS_ENDPOINT, {
      body,
      method: 'POST',
      keepalive: true
    });
  }
}

// Register all vitals
onCLS(sendToAnalytics);
onFCP(sendToAnalytics);
onLCP(sendToAnalytics);
onINP(sendToAnalytics);
onTTFB(sendToAnalytics);

// Custom performance marks
export function markStart(name) {
  performance.mark(`${name}-start`);
}

export function markEnd(name) {
  performance.mark(`${name}-end`);
  performance.measure(name, `${name}-start`, `${name}-end`);
  
  const measure = performance.getEntriesByName(name, 'measure')[0];
  sendToAnalytics({
    name: `custom:${name}`,
    value: measure.duration,
    rating: measure.duration < 100 ? 'good' : measure.duration < 300 ? 'needs-improvement' : 'poor'
  });
}
EOF


# === SERVER-SIDE MONITORING ===

cat > server-monitoring.js << 'EOF'
const promClient = require('prom-client');

// Create registry
const register = new promClient.Registry();

// Add default metrics
promClient.collectDefaultMetrics({ register });

// HTTP request duration histogram
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]
});
register.registerMetric(httpRequestDuration);

// HTTP requests counter
const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});
register.registerMetric(httpRequestsTotal);

// Database query duration
const dbQueryDuration = new promClient.Histogram({
  name: 'db_query_duration_seconds',
  help: 'Database query duration in seconds',
  labelNames: ['query_type', 'table'],
  buckets: [0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1]
});
register.registerMetric(dbQueryDuration);

// Cache hit rate
const cacheHits = new promClient.Counter({
  name: 'cache_hits_total',
  help: 'Cache hits',
  labelNames: ['cache_name']
});

const cacheMisses = new promClient.Counter({
  name: 'cache_misses_total',
  help: 'Cache misses',
  labelNames: ['cache_name']
});

register.registerMetric(cacheHits);
register.registerMetric(cacheMisses);

// Express middleware
function metricsMiddleware(req, res, next) {
  const start = process.hrtime.bigint();
  
  res.on('finish', () => {
    const duration = Number(process.hrtime.bigint() - start) / 1e9;
    const route = req.route?.path || req.path;
    
    httpRequestDuration.labels(req.method, route, res.statusCode).observe(duration);
    httpRequestsTotal.labels(req.method, route, res.statusCode).inc();
  });
  
  next();
}

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

module.exports = { register, metricsMiddleware, dbQueryDuration, cacheHits, cacheMisses };
EOF


# === ALERTING RULES (PROMETHEUS) ===

cat > alerting-rules.yml << 'EOF'
groups:
  - name: performance
    rules:
      # High P95 latency
      - alert: HighP95Latency
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 0.5
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High P95 latency ({{ $value }}s)"
          
      # High P99 latency
      - alert: HighP99Latency
        expr: histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m])) > 1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High P99 latency ({{ $value }}s)"
          
      # High error rate
      - alert: HighErrorRate
        expr: rate(http_requests_total{status_code=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.01
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate ({{ $value | humanizePercentage }})"
          
      # Low cache hit rate
      - alert: LowCacheHitRate
        expr: rate(cache_hits_total[5m]) / (rate(cache_hits_total[5m]) + rate(cache_misses_total[5m])) < 0.8
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Low cache hit rate ({{ $value | humanizePercentage }})"
          
      # Slow database queries
      - alert: SlowDatabaseQueries
        expr: histogram_quantile(0.95, rate(db_query_duration_seconds_bucket[5m])) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Slow database queries (P95: {{ $value }}s)"
EOF
```

---

## Performance Budget Enforcement

### Budget Configuration

```bash
# === PERFORMANCE BUDGET CONFIGURATION ===

cat > performance-budget.json << 'EOF'
{
  "budgets": {
    "timings": {
      "FCP": { "warning": 1500, "error": 1800, "unit": "ms" },
      "LCP": { "warning": 2000, "error": 2500, "unit": "ms" },
      "INP": { "warning": 150, "error": 200, "unit": "ms" },
      "TTFB": { "warning": 150, "error": 200, "unit": "ms" },
      "TTI": { "warning": 3500, "error": 5000, "unit": "ms" },
      "TBT": { "warning": 150, "error": 200, "unit": "ms" }
    },
    "scores": {
      "CLS": { "warning": 0.05, "error": 0.1, "unit": "score" },
      "lighthouse-performance": { "warning": 90, "error": 80, "unit": "score" },
      "lighthouse-accessibility": { "warning": 95, "error": 90, "unit": "score" }
    },
    "bundles": {
      "javascript": { "warning": 180, "error": 200, "unit": "KB" },
      "css": { "warning": 40, "error": 50, "unit": "KB" },
      "images": { "warning": 500, "error": 750, "unit": "KB" },
      "fonts": { "warning": 100, "error": 150, "unit": "KB" },
      "total": { "warning": 1000, "error": 1500, "unit": "KB" }
    },
    "requests": {
      "javascript": { "warning": 10, "error": 15 },
      "css": { "warning": 3, "error": 5 },
      "images": { "warning": 20, "error": 30 },
      "total": { "warning": 50, "error": 75 }
    }
  }
}
EOF


# === LIGHTHOUSE CI CONFIGURATION ===

cat > lighthouserc.js << 'EOF'
module.exports = {
  ci: {
    collect: {
      url: [
        'http://localhost:3000/',
        'http://localhost:3000/products',
        'http://localhost:3000/checkout'
      ],
      numberOfRuns: 3,
      settings: {
        preset: 'desktop',
        throttling: {
          rttMs: 40,
          throughputKbps: 10240,
          cpuSlowdownMultiplier: 1
        }
      }
    },
    assert: {
      preset: 'lighthouse:recommended',
      assertions: {
        'first-contentful-paint': ['warn', { maxNumericValue: 1800 }],
        'largest-contentful-paint': ['error', { maxNumericValue: 2500 }],
        'cumulative-layout-shift': ['error', { maxNumericValue: 0.1 }],
        'total-blocking-time': ['warn', { maxNumericValue: 200 }],
        'interactive': ['warn', { maxNumericValue: 3500 }],
        'categories:performance': ['error', { minScore: 0.8 }],
        'categories:accessibility': ['error', { minScore: 0.9 }],
        'categories:best-practices': ['warn', { minScore: 0.9 }],
        'categories:seo': ['warn', { minScore: 0.9 }],
        'resource-summary:script:size': ['error', { maxNumericValue: 200000 }],
        'resource-summary:stylesheet:size': ['warn', { maxNumericValue: 50000 }]
      }
    },
    upload: {
      target: 'lhci',
      serverBaseUrl: process.env.LHCI_SERVER_URL,
      token: process.env.LHCI_TOKEN
    }
  }
};
EOF


# === GITHUB ACTIONS WORKFLOW ===

cat > .github/workflows/performance.yml << 'EOF'
name: Performance Budget Check

on:
  pull_request:
    branches: [main]

jobs:
  lighthouse:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          
      - name: Install dependencies
        run: npm ci
        
      - name: Build
        run: npm run build
        
      - name: Start server
        run: npm start &
        
      - name: Wait for server
        run: npx wait-on http://localhost:3000
        
      - name: Run Lighthouse CI
        run: |
          npm install -g @lhci/cli
          lhci autorun
        env:
          LHCI_GITHUB_APP_TOKEN: ${{ secrets.LHCI_GITHUB_APP_TOKEN }}
          
      - name: Bundle size check
        run: |
          npm run build:analyze
          npx bundlesize
        
  bundle-budget:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          
      - run: npm ci
      - run: npm run build
      
      - name: Check bundle size
        uses: preactjs/compressed-size-action@v2
        with:
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          pattern: './dist/**/*.{js,css}'
          build-script: 'build'
EOF


# === BUNDLESIZE CONFIGURATION ===

cat > bundlesize.config.json << 'EOF'
{
  "files": [
    {
      "path": "./dist/js/main.*.js",
      "maxSize": "100 kB",
      "compression": "gzip"
    },
    {
      "path": "./dist/js/vendor.*.js",
      "maxSize": "150 kB",
      "compression": "gzip"
    },
    {
      "path": "./dist/css/main.*.css",
      "maxSize": "30 kB",
      "compression": "gzip"
    },
    {
      "path": "./dist/**/*.js",
      "maxSize": "300 kB",
      "compression": "gzip"
    }
  ],
  "ci": {
    "repoBranchBase": "main",
    "trackBranches": ["main", "develop"]
  }
}
EOF
```

---

## Performance Optimization Report Template

```markdown
# Performance Optimization Report

**Target:** [application/service name]
**Date:** [YYYY-MM-DD]
**Environment:** [production/staging]
**Analyst:** Ahmed Adel Bakr Alderai

---

## Executive Summary

[2-3 sentence overview of findings and recommendations]

**Key Metrics:**
| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| LCP | [X]ms | <2500ms | [PASS/FAIL] |
| FCP | [X]ms | <1800ms | [PASS/FAIL] |
| CLS | [X] | <0.1 | [PASS/FAIL] |
| INP | [X]ms | <200ms | [PASS/FAIL] |
| TTFB | [X]ms | <200ms | [PASS/FAIL] |
| Bundle Size | [X]KB | <200KB | [PASS/FAIL] |
| P95 Latency | [X]ms | <500ms | [PASS/FAIL] |

**Overall Performance Score:** [X]/100

---

## Findings by Priority

### P0 - Critical (Implement Immediately)

#### Finding 1: [Title]
- **Impact:** [Quantified impact]
- **Current:** [Current state]
- **Target:** [Target state]
- **Fix:** [Specific recommendation]
- **Effort:** [Hours/Days]
- **Expected Improvement:** [X% improvement in Y metric]

### P1 - High (Implement This Sprint)

#### Finding 2: [Title]
[Same structure]

### P2 - Medium (Implement Next Sprint)

#### Finding 3: [Title]
[Same structure]

### P3 - Low (Backlog)

#### Finding 4: [Title]
[Same structure]

---

## Optimization Roadmap

### Week 1: Quick Wins
- [ ] [Task 1] - [Expected improvement]
- [ ] [Task 2] - [Expected improvement]

### Week 2-3: Core Optimizations
- [ ] [Task 3] - [Expected improvement]
- [ ] [Task 4] - [Expected improvement]

### Week 4+: Architectural Changes
- [ ] [Task 5] - [Expected improvement]

---

## Appendix

### A. Test Methodology
[Tools used, test conditions, sample sizes]

### B. Raw Data
[Links to Lighthouse reports, profiles, metrics]

### C. Monitoring Setup
[Dashboards, alerts configured]

---

**Report Generated:** [timestamp]
**Analyst:** Ahmed Adel Bakr Alderai
```

---

## Example Usage

```bash
# Full performance audit
/agents/performance/performance-optimizer comprehensive audit for e-commerce site including Core Web Vitals, backend, and database

# Core Web Vitals optimization
/agents/performance/performance-optimizer optimize LCP for product listing page, current score is 4.2s

# Backend response time
/agents/performance/performance-optimizer reduce API response time for /api/search endpoint from 800ms to under 200ms

# Database optimization
/agents/performance/performance-optimizer analyze and optimize slow PostgreSQL queries for orders table

# Caching strategy
/agents/performance/performance-optimizer design multi-layer caching strategy for high-traffic API

# CDN setup
/agents/performance/performance-optimizer configure CloudFront CDN for static assets and API caching

# Image optimization
/agents/performance/performance-optimizer implement responsive image pipeline with AVIF/WebP for product images

# Code splitting
/agents/performance/performance-optimizer implement route-based code splitting for React SPA, reduce initial bundle from 500KB

# Monitoring setup
/agents/performance/performance-optimizer set up RUM with Web Vitals and Prometheus metrics for Node.js API

# Performance budgets
/agents/performance/performance-optimizer enforce performance budgets in CI/CD for bundle size and Lighthouse scores
```

---

## Related Agents

- `/agents/performance/profiling-expert` - Deep CPU/memory profiling
- `/agents/performance/caching-expert` - Advanced caching strategies
- `/agents/performance/load-testing-expert` - Load testing and capacity planning
- `/agents/frontend/frontend-developer` - Frontend implementation
- `/agents/database/database-architect` - Database design and optimization
- `/agents/devops/devops-engineer` - Infrastructure optimization
- `/agents/quality/performance-analyst` - Performance testing and analysis
