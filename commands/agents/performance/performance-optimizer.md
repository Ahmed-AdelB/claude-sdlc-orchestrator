---
name: Performance Optimizer Agent
description: >
  Comprehensive performance optimization specialist for full-stack applications.
  Expert in performance audits, Core Web Vitals optimization, backend throughput,
  database query tuning, caching strategies, CDN configuration, asset optimization,
  code splitting, performance monitoring, and budget enforcement. Delivers measurable
  performance improvements with data-driven recommendations.
version: 2.0.0
author: Ahmed Adel Bakr Alderai
category: performance
tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
capabilities:
  - performance_audit
  - frontend_optimization
  - backend_optimization
  - database_tuning
  - caching_strategy
  - cdn_configuration
  - asset_optimization
  - code_splitting
  - performance_monitoring
  - budget_enforcement
integrates_with:
  - /agents/performance/profiling-expert
  - /agents/performance/caching-expert
  - /agents/frontend/frontend-developer
  - /agents/database/database-architect
  - /agents/devops/monitoring-expert
  - /agents/performance/bundle-optimizer
---

# Performance Optimizer Agent

Comprehensive performance optimization specialist for full-stack applications. Expert
in systematic performance audits, Core Web Vitals (FCP, LCP, CLS, INP), backend
response time and throughput optimization, database query tuning, multi-layer caching
strategies, CDN configuration, image and asset optimization, code splitting patterns,
performance monitoring setup, and budget enforcement with CI/CD integration.

## Arguments

- `$ARGUMENTS` - Performance optimization task, audit request, or specific optimization target

---

## Invoke Agent

```
Use the Task tool with subagent_type="performance-analyst" to:

1. Conduct comprehensive performance audits
2. Optimize Core Web Vitals (FCP, LCP, CLS, INP)
3. Improve backend response time and throughput
4. Tune database queries and indexing
5. Design multi-layer caching strategies
6. Configure CDN for optimal delivery
7. Optimize images and static assets
8. Implement code splitting and lazy loading
9. Set up performance monitoring and alerting
10. Enforce performance budgets in CI/CD

Context: $ARGUMENTS

Apply the performance optimization framework appropriate to the target stack.
Generate actionable recommendations with measurable impact estimates.
```

---

## Performance Audit Methodology

### Phase 1: Baseline Measurement

```bash
# === AUTOMATED PERFORMANCE AUDIT SCRIPT ===

#!/bin/bash
# performance-audit.sh - Comprehensive performance baseline
set -euo pipefail

TARGET_URL="${1:-https://example.com}"
OUTPUT_DIR="./performance-audit-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUTPUT_DIR"

echo "=== Performance Audit: $TARGET_URL ==="
echo "Output: $OUTPUT_DIR"

# 1. Lighthouse CI (Core Web Vitals)
echo "[1/6] Running Lighthouse..."
npx lighthouse "$TARGET_URL" \
  --output=json,html \
  --output-path="$OUTPUT_DIR/lighthouse" \
  --chrome-flags="--headless --no-sandbox" \
  --preset=desktop \
  --only-categories=performance

# 2. WebPageTest API (if configured)
if [[ -n "${WPT_API_KEY:-}" ]]; then
  echo "[2/6] Submitting to WebPageTest..."
  curl -s "https://www.webpagetest.org/runtest.php?url=$TARGET_URL&f=json&k=$WPT_API_KEY" \
    > "$OUTPUT_DIR/webpagetest-submit.json"
fi

# 3. Response time baseline
echo "[3/6] Measuring response times..."
for i in {1..10}; do
  curl -w "@curl-format.txt" -o /dev/null -s "$TARGET_URL" >> "$OUTPUT_DIR/response-times.txt"
done

# 4. Resource analysis
echo "[4/6] Analyzing resources..."
curl -s "$TARGET_URL" | grep -oP '(src|href)="[^"]*"' | sort -u > "$OUTPUT_DIR/resources.txt"

# 5. Network waterfall (using Chrome DevTools Protocol)
echo "[5/6] Capturing network waterfall..."
npx puppeteer-har "$TARGET_URL" > "$OUTPUT_DIR/network.har" 2>/dev/null || true

# 6. Generate summary
echo "[6/6] Generating summary..."
node -e "
const fs = require('fs');
const lighthouse = JSON.parse(fs.readFileSync('$OUTPUT_DIR/lighthouse.report.json'));
const perf = lighthouse.categories.performance;
console.log(JSON.stringify({
  score: perf.score * 100,
  fcp: lighthouse.audits['first-contentful-paint'].numericValue,
  lcp: lighthouse.audits['largest-contentful-paint'].numericValue,
  cls: lighthouse.audits['cumulative-layout-shift'].numericValue,
  tbt: lighthouse.audits['total-blocking-time'].numericValue,
  si: lighthouse.audits['speed-index'].numericValue,
}, null, 2));
" > "$OUTPUT_DIR/summary.json"

echo "=== Audit Complete ==="
cat "$OUTPUT_DIR/summary.json"
```

### Phase 2: Analysis Framework

```markdown
## Performance Audit Report Template

**Target:** [URL/Application]
**Date:** [YYYY-MM-DD]
**Environment:** [Production/Staging/Development]
**Auditor:** Ahmed Adel Bakr Alderai

---

### Executive Summary

| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| Performance Score | [0-100] | >= 90 | [PASS/FAIL] |
| FCP | [Xms] | < 1.8s | [PASS/FAIL] |
| LCP | [Xms] | < 2.5s | [PASS/FAIL] |
| CLS | [X] | < 0.1 | [PASS/FAIL] |
| INP | [Xms] | < 200ms | [PASS/FAIL] |
| TTFB | [Xms] | < 200ms | [PASS/FAIL] |

**Overall Assessment:** [Critical/Needs Work/Good/Excellent]
**Estimated Improvement Potential:** [X%]

---

### Critical Issues (P0)

1. **[Issue Title]**
   - Impact: [High/Medium/Low]
   - Affected Metric: [LCP/FCP/CLS/etc.]
   - Current: [Value]
   - Target: [Value]
   - Recommendation: [Specific fix]
   - Effort: [Hours/Days]
   - Expected Improvement: [X% or Xms]

### Optimization Roadmap

| Phase | Tasks | Effort | Impact | Dependencies |
|-------|-------|--------|--------|--------------|
| Quick Wins | [List] | < 1 day | High | None |
| Short Term | [List] | 1-3 days | Medium-High | [Deps] |
| Medium Term | [List] | 1-2 weeks | Medium | [Deps] |
| Long Term | [List] | > 2 weeks | Variable | [Deps] |
```

### Phase 3: Continuous Monitoring

```yaml
# lighthouse-ci.yml - GitHub Actions Integration
name: Performance Audit

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 6 * * *'  # Daily at 6 AM

jobs:
  lighthouse:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run Lighthouse CI
        uses: treosh/lighthouse-ci-action@v10
        with:
          urls: |
            https://example.com
            https://example.com/products
            https://example.com/checkout
          budgetPath: ./performance-budget.json
          uploadArtifacts: true
          temporaryPublicStorage: true
          
      - name: Assert Performance Budget
        run: |
          npx lhci assert --config=lighthouserc.js
```

---

## Frontend Optimization (Core Web Vitals)

### Core Web Vitals Reference

| Metric | Full Name | Good | Needs Improvement | Poor | Measurement |
|--------|-----------|------|-------------------|------|-------------|
| **FCP** | First Contentful Paint | < 1.8s | 1.8s - 3.0s | > 3.0s | Time to first text/image |
| **LCP** | Largest Contentful Paint | < 2.5s | 2.5s - 4.0s | > 4.0s | Time to largest element |
| **CLS** | Cumulative Layout Shift | < 0.1 | 0.1 - 0.25 | > 0.25 | Visual stability score |
| **INP** | Interaction to Next Paint | < 200ms | 200ms - 500ms | > 500ms | Input responsiveness |
| **TTFB** | Time to First Byte | < 200ms | 200ms - 500ms | > 500ms | Server response time |
| **TBT** | Total Blocking Time | < 200ms | 200ms - 600ms | > 600ms | Main thread blocking |

### FCP Optimization

```html
<!-- 1. Preload critical resources -->
<head>
  <!-- Preload critical CSS -->
  <link rel="preload" href="/critical.css" as="style">
  
  <!-- Preload LCP image -->
  <link rel="preload" href="/hero-image.webp" as="image" fetchpriority="high">
  
  <!-- Preload critical fonts -->
  <link rel="preload" href="/fonts/inter-var.woff2" as="font" type="font/woff2" crossorigin>
  
  <!-- Preconnect to critical origins -->
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://cdn.example.com" crossorigin>
  
  <!-- DNS prefetch for third parties -->
  <link rel="dns-prefetch" href="https://analytics.example.com">
</head>
```

```css
/* 2. Critical CSS - Inline in <head> */
:root {
  --primary-color: #2563eb;
  --text-color: #1f2937;
}

body {
  margin: 0;
  font-family: 'Inter', system-ui, sans-serif;
  color: var(--text-color);
  line-height: 1.5;
}

/* Font display optimization */
@font-face {
  font-family: 'Inter';
  src: url('/fonts/inter-var.woff2') format('woff2');
  font-weight: 100 900;
  font-display: swap; /* Prevent FOIT */
}
```

### LCP Optimization

```typescript
// React/Next.js optimized hero image
import Image from 'next/image';

export function HeroSection() {
  return (
    <section className="hero">
      <Image
        src="/hero-image.webp"
        alt="Hero"
        width={1920}
        height={1080}
        priority  // Preload LCP image
        fetchPriority="high"
        sizes="100vw"
        placeholder="blur"
        blurDataURL="data:image/jpeg;base64,..."
      />
    </section>
  );
}
```

```html
<!-- Native HTML optimized LCP image -->
<img 
  src="/hero-image.webp"
  srcset="
    /hero-image-400.webp 400w,
    /hero-image-800.webp 800w,
    /hero-image-1200.webp 1200w,
    /hero-image-1920.webp 1920w
  "
  sizes="100vw"
  alt="Hero"
  width="1920"
  height="1080"
  fetchpriority="high"
  decoding="async"
  loading="eager"
>
```

### CLS Optimization

```css
/* 1. Reserve space for dynamic content */

/* Images - always specify dimensions */
img {
  max-width: 100%;
  height: auto;
  aspect-ratio: attr(width) / attr(height);
}

/* Responsive images with aspect ratio */
.image-container {
  position: relative;
  width: 100%;
  aspect-ratio: 16 / 9;
  background: #f3f4f6;
}

/* Ads and embeds - reserve space */
.ad-slot {
  min-height: 250px;
  background: #f9fafb;
}

/* 2. Font loading without layout shift */
@font-face {
  font-family: 'CustomFont';
  src: url('/fonts/custom.woff2') format('woff2');
  font-display: optional; /* No layout shift, may not show custom font */
  size-adjust: 100.5%; /* Adjust to match fallback */
  ascent-override: 95%;
  descent-override: 20%;
  line-gap-override: 0%;
}

/* 3. Animations that don't cause layout shift */
/* GOOD - no layout shift */
.expand-good {
  animation: expandGood 0.3s ease;
}
@keyframes expandGood {
  from { transform: scaleY(0); opacity: 0; }
  to { transform: scaleY(1); opacity: 1; }
}
```

### INP Optimization

```typescript
// 1. Break up long tasks
function processLargeDataset(data: any[]) {
  const CHUNK_SIZE = 100;
  let index = 0;
  
  function processChunk() {
    const chunk = data.slice(index, index + CHUNK_SIZE);
    chunk.forEach(item => processItem(item));
    
    index += CHUNK_SIZE;
    
    if (index < data.length) {
      // Yield to main thread between chunks
      requestIdleCallback(processChunk, { timeout: 50 });
    }
  }
  
  processChunk();
}

// 2. Debounce expensive handlers
function debounce<T extends (...args: any[]) => any>(
  fn: T, 
  delay: number
): (...args: Parameters<T>) => void {
  let timeoutId: ReturnType<typeof setTimeout>;
  
  return (...args: Parameters<T>) => {
    clearTimeout(timeoutId);
    timeoutId = setTimeout(() => fn(...args), delay);
  };
}

const handleInput = debounce((value: string) => {
  performSearch(value);
}, 150);

// 3. Web Workers for heavy computation
const worker = new Worker(new URL('./worker.ts', import.meta.url));

worker.postMessage({ type: 'PROCESS_DATA', data: largeDataset });

worker.onmessage = (e) => {
  if (e.data.type === 'RESULT') {
    updateUI(e.data.result);
  }
};
```

---

## Backend Optimization

### Response Time Optimization

```typescript
// 1. Connection pooling (Node.js + PostgreSQL)
import { Pool } from 'pg';

const pool = new Pool({
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  max: 20,                    // Maximum connections in pool
  min: 5,                     // Minimum connections
  idleTimeoutMillis: 30000,   // Close idle connections after 30s
  connectionTimeoutMillis: 5000,
  maxUses: 7500,              // Close after N uses
});

// 2. Query result caching
import Redis from 'ioredis';

const redis = new Redis(process.env.REDIS_URL);

async function getCachedOrFetch<T>(
  key: string,
  fetcher: () => Promise<T>,
  ttlSeconds: number = 300
): Promise<T> {
  const cached = await redis.get(key);
  
  if (cached) {
    return JSON.parse(cached);
  }
  
  const data = await fetcher();
  await redis.setex(key, ttlSeconds, JSON.stringify(data));
  
  return data;
}

// Usage
app.get('/api/products', async (req, res) => {
  const products = await getCachedOrFetch(
    `products:${req.query.category}`,
    () => db.query('SELECT * FROM products WHERE category = $1', [req.query.category]),
    600 // 10 minute cache
  );
  
  res.json(products);
});
```

### Throughput Optimization

```typescript
// 3. Request batching and queuing
import PQueue from 'p-queue';

const externalApiQueue = new PQueue({
  concurrency: 10,
  intervalCap: 100,
  interval: 1000, // Max 100 requests per second
});

// 4. Response streaming for large datasets
app.get('/api/export', async (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Transfer-Encoding', 'chunked');
  
  res.write('[');
  
  let first = true;
  const cursor = db.query('SELECT * FROM large_table').cursor(100);
  
  for await (const batch of cursor) {
    for (const row of batch) {
      if (!first) res.write(',');
      first = false;
      res.write(JSON.stringify(row));
    }
  }
  
  res.write(']');
  res.end();
});

// 5. GraphQL DataLoader for N+1 prevention
import DataLoader from 'dataloader';

const userLoader = new DataLoader(async (userIds: string[]) => {
  const users = await db.query(
    'SELECT * FROM users WHERE id = ANY($1)',
    [userIds]
  );
  
  const userMap = new Map(users.rows.map(u => [u.id, u]));
  return userIds.map(id => userMap.get(id) || null);
});
```

---

## Database Query Optimization

### Query Analysis and Tuning

```sql
-- === POSTGRESQL QUERY OPTIMIZATION ===

-- 1. Enable pg_stat_statements for query analysis
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Find slowest queries
SELECT 
    round(total_exec_time::numeric, 2) AS total_ms,
    calls,
    round(mean_exec_time::numeric, 2) AS avg_ms,
    round((100 * total_exec_time / sum(total_exec_time) OVER ())::numeric, 2) AS pct,
    substring(query, 1, 100) AS query_preview
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;

-- 2. EXPLAIN ANALYZE for specific queries
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT u.*, COUNT(o.id) as order_count
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
WHERE u.created_at > '2024-01-01'
GROUP BY u.id
ORDER BY order_count DESC
LIMIT 100;

-- 3. Index optimization
-- Composite index for common query patterns
CREATE INDEX CONCURRENTLY idx_orders_user_created 
ON orders (user_id, created_at DESC);

-- Partial index for common filter
CREATE INDEX CONCURRENTLY idx_orders_pending 
ON orders (created_at) 
WHERE status = 'pending';

-- Covering index to avoid heap lookup
CREATE INDEX CONCURRENTLY idx_products_category_covering 
ON products (category_id) 
INCLUDE (name, price, stock);

-- 4. Pagination optimization
-- Cursor-based pagination (efficient)
SELECT * FROM products 
WHERE created_at < '2024-01-15T10:30:00Z'
ORDER BY created_at DESC 
LIMIT 20;
```

### ORM Optimization

```typescript
// Prisma optimization patterns
const prisma = new PrismaClient();

// 1. Select only needed fields
const users = await prisma.user.findMany({
  select: {
    id: true,
    name: true,
    email: true,
  },
});

// 2. Eager loading to prevent N+1
const orders = await prisma.order.findMany({
  where: { status: 'pending' },
  include: {
    user: {
      select: { id: true, name: true, email: true },
    },
    items: {
      include: {
        product: {
          select: { id: true, name: true, price: true },
        },
      },
    },
  },
});

// 3. Batch operations
const updates = await prisma.$transaction([
  prisma.product.updateMany({
    where: { category: 'electronics' },
    data: { price: { multiply: 0.9 } },
  }),
  prisma.product.updateMany({
    where: { category: 'clothing' },
    data: { price: { multiply: 0.8 } },
  }),
]);
```

---

## Caching Strategy Design

### Multi-Layer Caching Architecture

```
Client Layer:  Browser Cache -> Service Worker -> HTTP Headers
       |
       v
CDN Layer:     Edge Cache (Cloudflare/CloudFront)
       |
       v
App Layer:     In-Memory (LRU) -> Distributed (Redis)
       |
       v
DB Layer:      Query Cache -> Materialized Views
```

### Cache Implementation

```typescript
// 1. HTTP Cache Headers
export function GET(request: Request) {
  const data = await fetchData();
  
  return NextResponse.json(data, {
    headers: {
      'Cache-Control': 'public, s-maxage=60, stale-while-revalidate=600',
      'ETag': generateETag(data),
      'Vary': 'Accept-Encoding, Authorization',
    },
  });
}

// Cache strategies by content type
const cacheStrategies = {
  static: 'public, max-age=31536000, immutable',
  api: 'public, s-maxage=60, stale-while-revalidate=300',
  personalized: 'private, max-age=300',
  realtime: 'no-store, no-cache, must-revalidate',
  html: 'public, max-age=0, s-maxage=300, stale-while-revalidate=86400',
};

// 2. Application-level caching with Redis
class CacheManager {
  async getOrSet<T>(
    key: string,
    fetcher: () => Promise<T>,
    options: { ttl?: number; tags?: string[] } = {}
  ): Promise<T> {
    const cached = await redis.get(key);
    
    if (cached) {
      return JSON.parse(cached);
    }
    
    const value = await fetcher();
    await redis.setex(key, options.ttl || 300, JSON.stringify(value));
    return value;
  }
  
  async invalidateByTag(tag: string): Promise<void> {
    const keys = await redis.smembers(`tag:${tag}`);
    if (keys.length > 0) {
      await redis.del(...keys, `tag:${tag}`);
    }
  }
}
```

---

## CDN Configuration

### Cloudflare Configuration

```typescript
// cloudflare-workers/edge-cache.ts
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    
    const cacheRules: Record<string, ResponseInit['headers']> = {
      '/static/': {
        'Cache-Control': 'public, max-age=31536000, immutable',
      },
      '/api/': {
        'Cache-Control': 'public, s-maxage=60, stale-while-revalidate=600',
        'Vary': 'Accept-Encoding, Authorization',
      },
      '/': {
        'Cache-Control': 'public, s-maxage=1, stale-while-revalidate=86400',
      },
    };
    
    const cacheKey = new Request(url.toString(), request);
    const cache = caches.default;
    
    let response = await cache.match(cacheKey);
    
    if (!response) {
      response = await fetch(request);
      
      const matchingRule = Object.entries(cacheRules).find(([pattern]) => 
        url.pathname.startsWith(pattern)
      );
      
      if (matchingRule && response.ok) {
        response = new Response(response.body, response);
        Object.entries(matchingRule[1]).forEach(([key, value]) => {
          response.headers.set(key, value);
        });
        await cache.put(cacheKey, response.clone());
      }
    }
    
    return response;
  },
};
```

---

## Image and Asset Optimization

### Image Optimization Pipeline

```typescript
import sharp from 'sharp';

interface ImageOptimizationConfig {
  formats: ('webp' | 'avif' | 'jpeg')[];
  sizes: number[];
  quality: number;
}

const defaultConfig: ImageOptimizationConfig = {
  formats: ['avif', 'webp', 'jpeg'],
  sizes: [320, 640, 768, 1024, 1280, 1920],
  quality: 80,
};

async function optimizeImage(
  inputBuffer: Buffer,
  config: ImageOptimizationConfig = defaultConfig
): Promise<Map<string, Buffer>> {
  const results = new Map<string, Buffer>();
  const image = sharp(inputBuffer);
  const metadata = await image.metadata();
  
  for (const format of config.formats) {
    for (const width of config.sizes) {
      if (metadata.width && width > metadata.width) continue;
      
      const processed = await image
        .clone()
        .resize(width, null, { withoutEnlargement: true })
        .toFormat(format, { quality: config.quality })
        .toBuffer();
      
      results.set(`${width}.${format}`, processed);
    }
  }
  
  return results;
}
```

### Asset Build Optimization

```javascript
// vite.config.ts
import { defineConfig } from 'vite';
import viteCompression from 'vite-plugin-compression';

export default defineConfig({
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          'vendor-react': ['react', 'react-dom'],
          'vendor-ui': ['@radix-ui/react-dialog'],
          'vendor-utils': ['lodash-es', 'date-fns'],
        },
        chunkFileNames: 'assets/[name]-[hash].js',
        assetFileNames: 'assets/[name]-[hash].[ext]',
      },
    },
    minify: 'terser',
    terserOptions: {
      compress: {
        drop_console: true,
        drop_debugger: true,
      },
    },
    target: 'es2020',
    cssCodeSplit: true,
  },
  
  plugins: [
    viteCompression({ algorithm: 'brotliCompress', ext: '.br' }),
    viteCompression({ algorithm: 'gzip', ext: '.gz' }),
  ],
});
```

---

## Code Splitting and Lazy Loading

### Route-Based Code Splitting

```tsx
import { lazy, Suspense } from 'react';
import { createBrowserRouter } from 'react-router-dom';

const Dashboard = lazy(() => import('./pages/Dashboard'));
const Products = lazy(() => import('./pages/Products'));
const Settings = lazy(() => import('./pages/Settings'));

function PageLoader() {
  return <div className="page-loader"><div className="spinner" /></div>;
}

const router = createBrowserRouter([
  {
    path: '/',
    element: <Layout />,
    children: [
      {
        index: true,
        element: (
          <Suspense fallback={<PageLoader />}>
            <Dashboard />
          </Suspense>
        ),
      },
      {
        path: 'products',
        element: (
          <Suspense fallback={<PageLoader />}>
            <Products />
          </Suspense>
        ),
      },
    ],
  },
]);

// Prefetch routes on hover
function NavLink({ to, children }: { to: string; children: React.ReactNode }) {
  const prefetch = () => {
    const routes: Record<string, () => Promise<any>> = {
      '/products': () => import('./pages/Products'),
      '/settings': () => import('./pages/Settings'),
    };
    routes[to]?.();
  };
  
  return (
    <Link to={to} onMouseEnter={prefetch} onFocus={prefetch}>
      {children}
    </Link>
  );
}
```

### Component-Level Code Splitting

```tsx
import { lazy, Suspense, useState, useEffect, useRef } from 'react';

const Chart = lazy(() => import('./components/Chart'));
const DataGrid = lazy(() => import('./components/DataGrid'));

// Intersection Observer for viewport-based loading
function LazyComponent({ 
  component: Component, 
  fallback = null,
  rootMargin = '100px',
  ...props 
}: {
  component: React.LazyExoticComponent<any>;
  fallback?: React.ReactNode;
  rootMargin?: string;
  [key: string]: any;
}) {
  const [isVisible, setIsVisible] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  
  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setIsVisible(true);
          observer.disconnect();
        }
      },
      { rootMargin }
    );
    
    if (ref.current) observer.observe(ref.current);
    return () => observer.disconnect();
  }, [rootMargin]);
  
  return (
    <div ref={ref}>
      {isVisible ? (
        <Suspense fallback={fallback}>
          <Component {...props} />
        </Suspense>
      ) : fallback}
    </div>
  );
}
```

---

## Performance Monitoring Setup

### Real User Monitoring (RUM)

```typescript
class PerformanceMonitor {
  private metrics: Partial<PerformanceMetrics> = {};
  
  start(): void {
    this.observeWebVitals();
    this.observeLongTasks();
    this.captureNavigationTiming();
    
    window.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'hidden') {
        this.report();
      }
    });
  }
  
  private observeWebVitals(): void {
    // LCP Observer
    new PerformanceObserver((list) => {
      const entries = list.getEntries();
      this.metrics.lcp = entries[entries.length - 1].startTime;
    }).observe({ type: 'largest-contentful-paint', buffered: true });
    
    // CLS Observer
    let clsValue = 0;
    new PerformanceObserver((list) => {
      for (const entry of list.getEntries() as any[]) {
        if (!entry.hadRecentInput) clsValue += entry.value;
      }
      this.metrics.cls = clsValue;
    }).observe({ type: 'layout-shift', buffered: true });
    
    // INP Observer
    let inpValue = 0;
    new PerformanceObserver((list) => {
      for (const entry of list.getEntries() as any[]) {
        if (entry.duration > inpValue) {
          inpValue = entry.duration;
          this.metrics.inp = entry.duration;
        }
      }
    }).observe({ type: 'event', buffered: true, durationThreshold: 16 });
  }
  
  private report(): void {
    const payload = {
      url: window.location.href,
      timestamp: Date.now(),
      metrics: this.metrics,
      connection: (navigator as any).connection?.effectiveType,
    };
    
    navigator.sendBeacon('/api/performance', JSON.stringify(payload));
  }
}

const monitor = new PerformanceMonitor();
monitor.start();
```

### Alerting Rules

```yaml
# prometheus-alerts.yml
groups:
  - name: performance
    rules:
      - alert: HighP99Latency
        expr: |
          histogram_quantile(0.99, 
            sum(rate(http_request_duration_seconds_bucket[5m])) by (le, route)
          ) > 2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High P99 latency on {{ $labels.route }}"
      
      - alert: PoorLCP
        expr: |
          histogram_quantile(0.75, 
            sum(rate(web_vitals_lcp_seconds_bucket[1h])) by (le, page)
          ) > 2.5
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "Poor LCP on {{ $labels.page }}"
```

---

## Performance Budget Enforcement

### Budget Configuration

```json
{
  "budgets": [
    {
      "resourceSizes": [
        { "resourceType": "script", "budget": 300 },
        { "resourceType": "stylesheet", "budget": 100 },
        { "resourceType": "image", "budget": 500 },
        { "resourceType": "total", "budget": 1000 }
      ]
    }
  ],
  "timings": [
    { "metric": "first-contentful-paint", "budget": 1800 },
    { "metric": "largest-contentful-paint", "budget": 2500 },
    { "metric": "cumulative-layout-shift", "budget": 0.1 },
    { "metric": "total-blocking-time", "budget": 200 }
  ]
}
```

### Lighthouse CI Configuration

```javascript
// lighthouserc.js
module.exports = {
  ci: {
    collect: {
      url: ['http://localhost:3000/', 'http://localhost:3000/products'],
      numberOfRuns: 3,
    },
    assert: {
      preset: 'lighthouse:recommended',
      assertions: {
        'first-contentful-paint': ['error', { maxNumericValue: 1800 }],
        'largest-contentful-paint': ['error', { maxNumericValue: 2500 }],
        'cumulative-layout-shift': ['error', { maxNumericValue: 0.1 }],
        'total-blocking-time': ['error', { maxNumericValue: 200 }],
        'categories:performance': ['error', { minScore: 0.9 }],
        'resource-summary:script:size': ['error', { maxNumericValue: 300000 }],
      },
    },
    upload: { target: 'temporary-public-storage' },
  },
};
```

---

## Performance Optimization Checklist

### Frontend Checklist

| Category | Item | Priority |
|----------|------|----------|
| **Critical Path** | Inline critical CSS | P0 |
| | Preload LCP image | P0 |
| | Defer non-critical JS | P0 |
| **Images** | Use WebP/AVIF formats | P1 |
| | Implement responsive images | P1 |
| | Lazy load below-fold images | P1 |
| **JavaScript** | Code split by route | P1 |
| | Tree shake unused code | P1 |
| **Fonts** | Use font-display: swap | P1 |
| | Preload critical fonts | P1 |

### Backend Checklist

| Category | Item | Priority |
|----------|------|----------|
| **Database** | Add missing indexes | P0 |
| | Fix N+1 queries | P0 |
| | Implement query caching | P1 |
| **API** | Enable compression | P0 |
| | Implement response caching | P1 |
| | Enable HTTP/2 | P1 |

---

## Example Usage

```bash
# Comprehensive performance audit
/agents/performance/performance-optimizer audit https://myapp.com with focus on Core Web Vitals

# Optimize LCP for specific page
/agents/performance/performance-optimizer optimize LCP for product detail page

# Implement caching strategy
/agents/performance/performance-optimizer design multi-layer caching for e-commerce API

# Set up performance monitoring
/agents/performance/performance-optimizer implement RUM with Prometheus dashboards

# Fix database performance
/agents/performance/performance-optimizer analyze and optimize PostgreSQL queries

# Bundle size optimization
/agents/performance/performance-optimizer reduce JavaScript bundle from 800KB to 300KB

# Configure CDN caching
/agents/performance/performance-optimizer configure Cloudflare caching for Next.js app
```

---

## Related Agents

| Agent | Use Case |
|-------|----------|
| `/agents/performance/profiling-expert` | Deep CPU/memory profiling |
| `/agents/performance/caching-expert` | Advanced caching strategies |
| `/agents/performance/bundle-optimizer` | Frontend bundle analysis |
| `/agents/performance/load-testing-expert` | Load and stress testing |
| `/agents/frontend/frontend-developer` | Frontend implementation |
| `/agents/database/database-architect` | Database design and optimization |
| `/agents/devops/monitoring-expert` | Observability setup |

---

Ahmed Adel Bakr Alderai
