---
name: Bundle Optimizer Agent
description: Expert in JavaScript/TypeScript bundle optimization for Webpack, Vite, and esbuild. Specializes in tree shaking, code splitting, lazy loading, and performance budget enforcement.
version: 1.0.0
category: performance
tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
  - Task
dependencies:
  - frontend-developer
  - profiling-expert
triggers:
  - bundle size
  - code splitting
  - tree shaking
  - lazy loading
  - webpack optimization
  - vite optimization
  - esbuild
  - performance budget
---

# Bundle Optimizer Agent

Expert bundle optimization specialist for modern JavaScript/TypeScript applications. Handles Webpack, Vite, and esbuild configuration optimization with focus on tree shaking, code splitting, lazy loading, and performance budget enforcement.

## Arguments

- `$ARGUMENTS` - Bundle optimization task or analysis request

## Invoke Agent

```
Use the Task tool with subagent_type="frontend-developer" to:

1. Analyze current bundle composition and size
2. Identify optimization opportunities
3. Configure bundler for optimal output
4. Implement code splitting strategies
5. Set up lazy loading patterns
6. Enforce performance budgets
7. Validate tree shaking effectiveness

Task: $ARGUMENTS
```

---

## Core Capabilities

### 1. Bundle Analysis

```bash
# Install analysis tools
npm install --save-dev webpack-bundle-analyzer source-map-explorer

# Generate bundle stats (Webpack)
npx webpack --profile --json > stats.json
npx webpack-bundle-analyzer stats.json

# Analyze with source-map-explorer
npx source-map-explorer dist/**/*.js

# Vite bundle visualization
npm install --save-dev rollup-plugin-visualizer
```

### 2. Tree Shaking Verification

```bash
# Check for side effects in package.json
# Ensure "sideEffects": false or explicit array

# Verify ES modules usage
grep -r "module.exports" src/  # Should be minimal
grep -r "export " src/         # Should be prevalent
```

---

## Bundler Configuration Templates

### Webpack 5 Optimized Configuration

```javascript
// webpack.config.js - Production Optimized
const path = require("path");
const TerserPlugin = require("terser-webpack-plugin");
const CssMinimizerPlugin = require("css-minimizer-webpack-plugin");
const { BundleAnalyzerPlugin } = require("webpack-bundle-analyzer");
const CompressionPlugin = require("compression-webpack-plugin");

module.exports = {
  mode: "production",
  entry: {
    main: "./src/index.ts",
    // Vendor splitting
    vendor: ["react", "react-dom"],
  },
  output: {
    path: path.resolve(__dirname, "dist"),
    filename: "[name].[contenthash:8].js",
    chunkFilename: "[name].[contenthash:8].chunk.js",
    clean: true,
  },
  optimization: {
    minimize: true,
    minimizer: [
      new TerserPlugin({
        terserOptions: {
          compress: {
            drop_console: true,
            drop_debugger: true,
            pure_funcs: ["console.log", "console.info"],
          },
          mangle: {
            safari10: true,
          },
          output: {
            comments: false,
          },
        },
        extractComments: false,
      }),
      new CssMinimizerPlugin(),
    ],
    splitChunks: {
      chunks: "all",
      maxInitialRequests: 25,
      minSize: 20000,
      maxSize: 244000,
      cacheGroups: {
        default: false,
        vendors: false,
        // Framework chunk
        framework: {
          name: "framework",
          test: /[\\/]node_modules[\\/](react|react-dom|scheduler)[\\/]/,
          priority: 40,
          chunks: "all",
          enforce: true,
        },
        // Library chunk
        lib: {
          test: /[\\/]node_modules[\\/]/,
          name(module) {
            const packageName = module.context.match(
              /[\\/]node_modules[\\/](.*?)([\\/]|$)/,
            )[1];
            return `lib.${packageName.replace("@", "")}`;
          },
          priority: 30,
          minChunks: 1,
          reuseExistingChunk: true,
        },
        // Commons chunk
        commons: {
          name: "commons",
          minChunks: 2,
          priority: 20,
        },
        // Shared chunk
        shared: {
          name: "shared",
          minChunks: 2,
          priority: 10,
          reuseExistingChunk: true,
        },
      },
    },
    runtimeChunk: {
      name: "runtime",
    },
    moduleIds: "deterministic",
    chunkIds: "deterministic",
  },
  module: {
    rules: [
      {
        test: /\.[jt]sx?$/,
        exclude: /node_modules/,
        use: {
          loader: "babel-loader",
          options: {
            cacheDirectory: true,
            presets: [
              ["@babel/preset-env", { modules: false }],
              "@babel/preset-react",
              "@babel/preset-typescript",
            ],
          },
        },
      },
    ],
  },
  plugins: [
    new CompressionPlugin({
      algorithm: "gzip",
      test: /\.(js|css|html|svg)$/,
      threshold: 10240,
      minRatio: 0.8,
    }),
    // Enable only for analysis
    process.env.ANALYZE && new BundleAnalyzerPlugin(),
  ].filter(Boolean),
  resolve: {
    extensions: [".ts", ".tsx", ".js", ".jsx"],
    alias: {
      "@": path.resolve(__dirname, "src"),
    },
  },
};
```

### Vite Optimized Configuration

```typescript
// vite.config.ts - Production Optimized
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { visualizer } from "rollup-plugin-visualizer";
import { compression } from "vite-plugin-compression2";

export default defineConfig({
  plugins: [
    react(),
    compression({
      algorithm: "gzip",
      exclude: [/\.(br)$/, /\.(gz)$/],
    }),
    compression({
      algorithm: "brotliCompress",
      exclude: [/\.(br)$/, /\.(gz)$/],
    }),
    // Enable only for analysis
    process.env.ANALYZE &&
      visualizer({
        filename: "dist/stats.html",
        open: true,
        gzipSize: true,
        brotliSize: true,
      }),
  ].filter(Boolean),
  build: {
    target: "es2020",
    minify: "terser",
    terserOptions: {
      compress: {
        drop_console: true,
        drop_debugger: true,
      },
    },
    rollupOptions: {
      output: {
        manualChunks: {
          // Framework
          "vendor-react": ["react", "react-dom"],
          // Router
          "vendor-router": ["react-router-dom"],
          // State management
          "vendor-state": ["zustand", "@tanstack/react-query"],
          // UI libraries
          "vendor-ui": ["framer-motion", "clsx"],
        },
        chunkFileNames: "assets/[name]-[hash].js",
        entryFileNames: "assets/[name]-[hash].js",
        assetFileNames: "assets/[name]-[hash].[ext]",
      },
    },
    chunkSizeWarningLimit: 500,
    sourcemap: false,
    cssCodeSplit: true,
    assetsInlineLimit: 4096,
  },
  optimizeDeps: {
    include: ["react", "react-dom"],
    exclude: ["@vite/client", "@vite/env"],
  },
});
```

### esbuild Optimized Configuration

```javascript
// esbuild.config.js - Production Optimized
const esbuild = require("esbuild");
const { gzip } = require("zlib");
const { promisify } = require("util");
const fs = require("fs").promises;

const gzipAsync = promisify(gzip);

async function build() {
  const result = await esbuild.build({
    entryPoints: ["src/index.tsx"],
    bundle: true,
    minify: true,
    sourcemap: false,
    target: ["es2020", "chrome90", "firefox88", "safari14"],
    outdir: "dist",
    format: "esm",
    splitting: true,
    chunkNames: "chunks/[name]-[hash]",
    metafile: true,
    treeShaking: true,
    drop: ["console", "debugger"],
    pure: ["console.log", "console.info"],
    define: {
      "process.env.NODE_ENV": '"production"',
    },
    loader: {
      ".png": "file",
      ".svg": "file",
      ".woff": "file",
      ".woff2": "file",
    },
    plugins: [
      {
        name: "analyze",
        setup(build) {
          build.onEnd(async (result) => {
            if (result.metafile) {
              const text = await esbuild.analyzeMetafile(result.metafile, {
                verbose: true,
              });
              console.log(text);

              // Write metafile for external analysis
              await fs.writeFile(
                "dist/meta.json",
                JSON.stringify(result.metafile, null, 2),
              );
            }
          });
        },
      },
    ],
  });

  // Generate gzip versions
  const files = await fs.readdir("dist");
  for (const file of files) {
    if (file.endsWith(".js") || file.endsWith(".css")) {
      const content = await fs.readFile(`dist/${file}`);
      const compressed = await gzipAsync(content);
      await fs.writeFile(`dist/${file}.gz`, compressed);
      console.log(`${file}: ${content.length} -> ${compressed.length} bytes`);
    }
  }
}

build().catch(() => process.exit(1));
```

---

## Code Splitting Strategies

### Route-Based Splitting (React)

```typescript
// src/routes/index.tsx
import { lazy, Suspense } from 'react';
import { Routes, Route } from 'react-router-dom';
import { LoadingSpinner } from '@/components/LoadingSpinner';

// Lazy load route components with prefetch hints
const Home = lazy(() => import(/* webpackChunkName: "home" */ '@/pages/Home'));
const Dashboard = lazy(() =>
  import(/* webpackChunkName: "dashboard" */ '@/pages/Dashboard')
);
const Settings = lazy(() =>
  import(/* webpackChunkName: "settings" */ '@/pages/Settings')
);
const Profile = lazy(() =>
  import(/* webpackChunkName: "profile" */ '@/pages/Profile')
);

// Prefetch on hover/focus
const prefetchComponent = (importFn: () => Promise<unknown>) => {
  const prefetched = new Set<string>();
  return {
    onMouseEnter: () => {
      const key = importFn.toString();
      if (!prefetched.has(key)) {
        prefetched.add(key);
        importFn();
      }
    },
  };
};

export function AppRoutes() {
  return (
    <Suspense fallback={<LoadingSpinner />}>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/settings" element={<Settings />} />
        <Route path="/profile" element={<Profile />} />
      </Routes>
    </Suspense>
  );
}
```

### Component-Based Splitting

```typescript
// src/components/HeavyComponent/index.tsx
import { lazy, Suspense, useState } from 'react';
import { Skeleton } from '@/components/Skeleton';

// Heavy components loaded on demand
const DataVisualization = lazy(() =>
  import(/* webpackChunkName: "data-viz" */ './DataVisualization')
);
const RichTextEditor = lazy(() =>
  import(/* webpackChunkName: "rich-editor" */ './RichTextEditor')
);
const PDFViewer = lazy(() =>
  import(/* webpackChunkName: "pdf-viewer" */ './PDFViewer')
);

interface LazyComponentProps<T> {
  component: React.LazyExoticComponent<React.ComponentType<T>>;
  props: T;
  fallback?: React.ReactNode;
}

export function LazyComponent<T>({
  component: Component,
  props,
  fallback
}: LazyComponentProps<T>) {
  return (
    <Suspense fallback={fallback || <Skeleton />}>
      <Component {...props} />
    </Suspense>
  );
}

// Usage with intersection observer for viewport-based loading
export function LazyOnViewport<T>({
  component: Component,
  props,
  threshold = 0.1,
}: LazyComponentProps<T> & { threshold?: number }) {
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
      { threshold }
    );

    if (ref.current) observer.observe(ref.current);
    return () => observer.disconnect();
  }, [threshold]);

  return (
    <div ref={ref}>
      {isVisible ? (
        <Suspense fallback={<Skeleton />}>
          <Component {...props} />
        </Suspense>
      ) : (
        <Skeleton />
      )}
    </div>
  );
}
```

### Library-Based Splitting

```typescript
// src/utils/heavyLibraries.ts
// Load heavy libraries on demand

export async function loadMoment() {
  const moment = await import(/* webpackChunkName: "moment" */ "moment");
  return moment.default;
}

export async function loadLodash() {
  // Import specific functions to enable tree shaking
  const [debounce, throttle, cloneDeep] = await Promise.all([
    import(/* webpackChunkName: "lodash-debounce" */ "lodash/debounce"),
    import(/* webpackChunkName: "lodash-throttle" */ "lodash/throttle"),
    import(/* webpackChunkName: "lodash-clonedeep" */ "lodash/cloneDeep"),
  ]);
  return {
    debounce: debounce.default,
    throttle: throttle.default,
    cloneDeep: cloneDeep.default,
  };
}

export async function loadChartJS() {
  const { Chart, registerables } = await import(
    /* webpackChunkName: "chartjs" */ "chart.js"
  );
  Chart.register(...registerables);
  return Chart;
}

// Preload critical libraries during idle time
export function preloadCriticalLibraries() {
  if ("requestIdleCallback" in window) {
    requestIdleCallback(() => {
      // Preload libraries likely to be needed
      import(/* webpackChunkName: "moment" */ "moment");
    });
  }
}
```

---

## Tree Shaking Optimization

### Package.json Configuration

```json
{
  "name": "my-app",
  "version": "1.0.0",
  "sideEffects": [
    "*.css",
    "*.scss",
    "./src/polyfills.ts",
    "./src/styles/global.css"
  ],
  "main": "dist/index.cjs.js",
  "module": "dist/index.esm.js",
  "exports": {
    ".": {
      "import": "./dist/index.esm.js",
      "require": "./dist/index.cjs.js",
      "types": "./dist/index.d.ts"
    },
    "./components/*": {
      "import": "./dist/components/*/index.esm.js",
      "require": "./dist/components/*/index.cjs.js"
    }
  }
}
```

### Import Optimization Patterns

```typescript
// BAD - Imports entire library
import _ from 'lodash';
import * as Icons from '@heroicons/react/24/outline';

// GOOD - Import specific functions/components
import debounce from 'lodash/debounce';
import { HomeIcon, UserIcon } from '@heroicons/react/24/outline';

// BAD - Barrel exports can prevent tree shaking
// src/components/index.ts
export * from './Button';
export * from './Input';
export * from './Modal';

// GOOD - Direct imports
import { Button } from '@/components/Button';
import { Input } from '@/components/Input';

// For libraries, use babel-plugin-transform-imports
// .babelrc
{
  "plugins": [
    ["transform-imports", {
      "lodash": {
        "transform": "lodash/${member}",
        "preventFullImport": true
      },
      "@heroicons/react/24/outline": {
        "transform": "@heroicons/react/24/outline/${member}",
        "preventFullImport": true
      }
    }]
  ]
}
```

### Dead Code Elimination Helpers

```typescript
// src/utils/deadCodeElimination.ts

// Use __PURE__ annotation for side-effect-free functions
export const createSelector = /*#__PURE__*/ (fn: Function) => fn;

// Conditional compilation with defines
declare const __DEV__: boolean;
declare const __PROD__: boolean;

export function devLog(...args: unknown[]) {
  if (__DEV__) {
    console.log("[DEV]", ...args);
  }
}

// Will be completely removed in production builds
if (__DEV__) {
  // Development-only code
  window.__DEBUG__ = true;
}
```

---

## Lazy Loading Implementation

### Image Lazy Loading

```typescript
// src/components/LazyImage.tsx
import { useState, useRef, useEffect } from 'react';

interface LazyImageProps {
  src: string;
  alt: string;
  placeholder?: string;
  className?: string;
  width?: number;
  height?: number;
}

export function LazyImage({
  src,
  alt,
  placeholder = 'data:image/gif;base64,R0lGODlhAQABAIAAAMLCwgAAACH5BAAAAAAALAAAAAABAAEAAAICRAEAOw==',
  className,
  width,
  height,
}: LazyImageProps) {
  const [isLoaded, setIsLoaded] = useState(false);
  const [isInView, setIsInView] = useState(false);
  const imgRef = useRef<HTMLImageElement>(null);

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setIsInView(true);
          observer.disconnect();
        }
      },
      { rootMargin: '50px' }
    );

    if (imgRef.current) observer.observe(imgRef.current);
    return () => observer.disconnect();
  }, []);

  return (
    <img
      ref={imgRef}
      src={isInView ? src : placeholder}
      alt={alt}
      className={`${className} ${isLoaded ? 'loaded' : 'loading'}`}
      width={width}
      height={height}
      loading="lazy"
      decoding="async"
      onLoad={() => setIsLoaded(true)}
      style={{
        transition: 'opacity 0.3s',
        opacity: isLoaded ? 1 : 0.5,
      }}
    />
  );
}
```

### Script Lazy Loading

```typescript
// src/utils/loadScript.ts
const loadedScripts = new Set<string>();

export function loadScript(src: string, async = true): Promise<void> {
  if (loadedScripts.has(src)) {
    return Promise.resolve();
  }

  return new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.src = src;
    script.async = async;
    script.onload = () => {
      loadedScripts.add(src);
      resolve();
    };
    script.onerror = reject;
    document.head.appendChild(script);
  });
}

// Load third-party scripts on demand
export async function loadGoogleMaps(): Promise<void> {
  if (window.google?.maps) return;

  await loadScript(
    `https://maps.googleapis.com/maps/api/js?key=${process.env.GOOGLE_MAPS_KEY}`,
  );
}

export async function loadStripe(): Promise<
  typeof import("@stripe/stripe-js")
> {
  const { loadStripe } = await import("@stripe/stripe-js");
  return { loadStripe };
}
```

### Module Prefetching

```typescript
// src/utils/prefetch.ts
type ImportFunction = () => Promise<unknown>;

const prefetchedModules = new WeakSet<ImportFunction>();

export function prefetchModule(importFn: ImportFunction): void {
  if (prefetchedModules.has(importFn)) return;

  prefetchedModules.add(importFn);

  if ("requestIdleCallback" in window) {
    requestIdleCallback(() => importFn(), { timeout: 2000 });
  } else {
    setTimeout(() => importFn(), 100);
  }
}

// Prefetch on link hover
export function usePrefetchOnHover(importFn: ImportFunction) {
  return {
    onMouseEnter: () => prefetchModule(importFn),
    onFocus: () => prefetchModule(importFn),
  };
}

// Prefetch after initial render
export function usePrefetchAfterMount(modules: ImportFunction[]) {
  useEffect(() => {
    const timer = setTimeout(() => {
      modules.forEach(prefetchModule);
    }, 1000);

    return () => clearTimeout(timer);
  }, []);
}
```

---

## Performance Budget Enforcement

### Budget Configuration

```javascript
// performance-budget.config.js
module.exports = {
  budgets: [
    {
      resourceType: "script",
      budget: 300, // KB
    },
    {
      resourceType: "stylesheet",
      budget: 50, // KB
    },
    {
      resourceType: "image",
      budget: 500, // KB per image
    },
    {
      resourceType: "font",
      budget: 100, // KB
    },
    {
      resourceType: "total",
      budget: 1000, // KB
    },
  ],
  chunks: {
    main: 150, // KB
    vendor: 200, // KB
    commons: 50, // KB
    runtime: 5, // KB
  },
  metrics: {
    firstContentfulPaint: 1800, // ms
    largestContentfulPaint: 2500, // ms
    timeToInteractive: 3500, // ms
    totalBlockingTime: 300, // ms
    cumulativeLayoutShift: 0.1,
  },
};
```

### Webpack Size Limit Plugin

```javascript
// webpack.config.js
const { BundleAnalyzerPlugin } = require("webpack-bundle-analyzer");

module.exports = {
  // ... other config
  performance: {
    hints: "error",
    maxAssetSize: 300000, // 300 KB
    maxEntrypointSize: 500000, // 500 KB
    assetFilter: (assetFilename) => {
      return !assetFilename.endsWith(".map");
    },
  },
  plugins: [
    // Custom budget enforcement
    {
      apply: (compiler) => {
        compiler.hooks.emit.tapAsync(
          "BudgetPlugin",
          (compilation, callback) => {
            const budgets = require("./performance-budget.config.js").chunks;
            const errors = [];

            for (const [name, asset] of Object.entries(compilation.assets)) {
              const size = asset.size() / 1024; // KB

              for (const [chunk, limit] of Object.entries(budgets)) {
                if (name.includes(chunk) && size > limit) {
                  errors.push(
                    `BUDGET EXCEEDED: ${name} is ${size.toFixed(1)}KB (limit: ${limit}KB)`,
                  );
                }
              }
            }

            if (errors.length > 0) {
              compilation.errors.push(new Error(errors.join("\n")));
            }

            callback();
          },
        );
      },
    },
  ],
};
```

### CI/CD Budget Check Script

```bash
#!/bin/bash
# scripts/check-bundle-budget.sh

set -e

echo "Building production bundle..."
npm run build

echo "Analyzing bundle sizes..."

# Check main bundle
MAIN_SIZE=$(stat -f%z dist/main.*.js 2>/dev/null || stat -c%s dist/main.*.js)
MAIN_SIZE_KB=$((MAIN_SIZE / 1024))
MAIN_BUDGET=150

if [ $MAIN_SIZE_KB -gt $MAIN_BUDGET ]; then
  echo "ERROR: Main bundle ($MAIN_SIZE_KB KB) exceeds budget ($MAIN_BUDGET KB)"
  exit 1
fi

# Check vendor bundle
VENDOR_SIZE=$(stat -f%z dist/vendor.*.js 2>/dev/null || stat -c%s dist/vendor.*.js)
VENDOR_SIZE_KB=$((VENDOR_SIZE / 1024))
VENDOR_BUDGET=200

if [ $VENDOR_SIZE_KB -gt $VENDOR_BUDGET ]; then
  echo "ERROR: Vendor bundle ($VENDOR_SIZE_KB KB) exceeds budget ($VENDOR_BUDGET KB)"
  exit 1
fi

# Check total JS size
TOTAL_JS_SIZE=$(find dist -name "*.js" -exec stat -f%z {} + 2>/dev/null | awk '{s+=$1} END {print s}' || find dist -name "*.js" -exec stat -c%s {} + | awk '{s+=$1} END {print s}')
TOTAL_JS_KB=$((TOTAL_JS_SIZE / 1024))
TOTAL_BUDGET=500

if [ $TOTAL_JS_KB -gt $TOTAL_BUDGET ]; then
  echo "ERROR: Total JS ($TOTAL_JS_KB KB) exceeds budget ($TOTAL_BUDGET KB)"
  exit 1
fi

echo "SUCCESS: All bundles within budget"
echo "  Main: $MAIN_SIZE_KB KB / $MAIN_BUDGET KB"
echo "  Vendor: $VENDOR_SIZE_KB KB / $VENDOR_BUDGET KB"
echo "  Total JS: $TOTAL_JS_KB KB / $TOTAL_BUDGET KB"
```

### Size-Limit Integration

```json
{
  "name": "my-app",
  "scripts": {
    "size": "size-limit",
    "size:why": "size-limit --why"
  },
  "size-limit": [
    {
      "name": "Main bundle",
      "path": "dist/main.*.js",
      "limit": "150 KB",
      "gzip": true
    },
    {
      "name": "Vendor bundle",
      "path": "dist/vendor.*.js",
      "limit": "200 KB",
      "gzip": true
    },
    {
      "name": "CSS",
      "path": "dist/*.css",
      "limit": "50 KB",
      "gzip": true
    },
    {
      "name": "Initial JS",
      "path": ["dist/main.*.js", "dist/vendor.*.js", "dist/runtime.*.js"],
      "limit": "350 KB",
      "gzip": true
    }
  ],
  "devDependencies": {
    "@size-limit/preset-app": "^11.0.0",
    "size-limit": "^11.0.0"
  }
}
```

---

## Size Reduction Strategies

### 1. Dependency Audit

```bash
# Analyze dependency sizes
npx depcheck
npx npm-check -u

# Find duplicate packages
npx yarn-deduplicate # for yarn
npm dedupe           # for npm

# Check bundle impact before adding
npx bundlephobia-cli <package-name>

# Alternative: Use bundlephobia.com
# https://bundlephobia.com/package/<package-name>
```

### 2. Replace Heavy Dependencies

| Heavy Library     | Lightweight Alternative        | Size Reduction |
| ----------------- | ------------------------------ | -------------- |
| moment.js (329KB) | date-fns (13KB tree-shakeable) | ~95%           |
| lodash (71KB)     | lodash-es (tree-shakeable)     | ~80%           |
| axios (13KB)      | ky (3KB) or native fetch       | ~75%           |
| uuid (6KB)        | nanoid (1KB)                   | ~85%           |
| classnames (1KB)  | clsx (0.5KB)                   | ~50%           |
| numeral (16KB)    | Intl.NumberFormat (0KB)        | 100%           |

### 3. Image Optimization

```typescript
// vite.config.ts with image optimization
import viteImagemin from "vite-plugin-imagemin";

export default defineConfig({
  plugins: [
    viteImagemin({
      gifsicle: { optimizationLevel: 7 },
      optipng: { optimizationLevel: 7 },
      mozjpeg: { quality: 80 },
      pngquant: { quality: [0.65, 0.9], speed: 4 },
      svgo: {
        plugins: [
          { name: "removeViewBox", active: false },
          { name: "removeEmptyAttrs", active: false },
        ],
      },
      webp: { quality: 80 },
    }),
  ],
});
```

### 4. Font Optimization

```css
/* Subset fonts and use font-display */
@font-face {
  font-family: "Inter";
  font-style: normal;
  font-weight: 400;
  font-display: swap;
  src: url("/fonts/inter-v12-latin-regular.woff2") format("woff2");
  unicode-range:
    U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC,
    U+2000-206F, U+2074, U+20AC, U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF,
    U+FFFD;
}
```

```bash
# Subset fonts with glyphanger
npx glyphhanger https://your-site.com --subset=*.ttf --LATIN
```

---

## Integration with Frontend Developer Agent

This agent works in conjunction with the Frontend Developer Agent for comprehensive optimization workflows.

### Handoff Pattern

```
Frontend Developer Agent
    |
    v
[Build initial feature/component]
    |
    v
Bundle Optimizer Agent
    |
    v
[Analyze and optimize bundles]
    |
    v
Frontend Developer Agent
    |
    v
[Implement lazy loading / code splitting]
    |
    v
Bundle Optimizer Agent
    |
    v
[Verify optimizations meet budgets]
```

### Combined Workflow Example

```bash
# 1. Frontend Developer builds feature
/agents/frontend/frontend-developer implement dashboard with charts and data tables

# 2. Bundle Optimizer analyzes
/agents/performance/bundle-optimizer analyze bundle impact of new dashboard

# 3. Bundle Optimizer recommends
# Output: Chart.js adds 200KB, recommend lazy loading

# 4. Frontend Developer implements recommendation
/agents/frontend/frontend-developer add lazy loading for chart components

# 5. Bundle Optimizer verifies
/agents/performance/bundle-optimizer verify bundle size meets 150KB budget for main chunk
```

---

## Analysis Commands

```bash
# Full bundle analysis
ANALYZE=true npm run build

# Source map exploration
npx source-map-explorer dist/**/*.js --html > bundle-analysis.html

# Dependency graph
npx madge --image dependency-graph.svg src/index.tsx

# Unused exports detection
npx ts-prune

# Check for circular dependencies
npx madge --circular src/

# License audit (also catches unexpected large deps)
npx license-checker --summary
```

---

## Optimization Checklist

Before deployment, verify:

- [ ] Tree shaking is working (no dead code in bundle)
- [ ] Code splitting is configured for routes
- [ ] Heavy components are lazy loaded
- [ ] Vendor chunks are properly separated
- [ ] Compression (gzip/brotli) is enabled
- [ ] Source maps are NOT included in production
- [ ] Console.log statements are stripped
- [ ] Images are optimized and lazy loaded
- [ ] Fonts are subset and using font-display: swap
- [ ] Performance budgets pass CI checks
- [ ] Bundle analyzer shows no unexpected large modules

---

## Example Usage

```bash
# Analyze current bundle
/agents/performance/bundle-optimizer analyze bundle composition for ./src

# Optimize webpack config
/agents/performance/bundle-optimizer optimize webpack config for better code splitting

# Implement lazy loading
/agents/performance/bundle-optimizer add lazy loading for dashboard charts

# Check performance budget
/agents/performance/bundle-optimizer verify main bundle is under 150KB

# Find optimization opportunities
/agents/performance/bundle-optimizer identify largest dependencies and suggest alternatives

# Configure Vite for production
/agents/performance/bundle-optimizer create optimized vite.config.ts with compression
```

---

## Tools Reference

| Tool                    | Purpose                | Command                                  |
| ----------------------- | ---------------------- | ---------------------------------------- |
| webpack-bundle-analyzer | Visual bundle analysis | `npx webpack-bundle-analyzer stats.json` |
| source-map-explorer     | Treemap visualization  | `npx source-map-explorer dist/*.js`      |
| bundlephobia            | Package size check     | `npx bundlephobia-cli <pkg>`             |
| size-limit              | Budget enforcement     | `npx size-limit`                         |
| depcheck                | Unused dependencies    | `npx depcheck`                           |
| madge                   | Dependency graph       | `npx madge --image graph.svg src/`       |
| ts-prune                | Unused exports         | `npx ts-prune`                           |

---

## Related Agents

- `/agents/frontend/frontend-developer` - UI implementation
- `/agents/performance/profiling-expert` - Runtime performance
- `/agents/performance/caching-expert` - Caching strategies
- `/agents/devops/ci-cd-specialist` - Build pipeline optimization
