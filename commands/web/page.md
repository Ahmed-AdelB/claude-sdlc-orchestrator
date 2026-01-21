---
name: web:page
description: Generate Next.js App Router pages with metadata, SEO, data fetching, and tests.
version: 1.0.0
tools:
  - Read
  - Write
  - Bash
---

# Next.js Page Generator

Generate Next.js App Router pages with metadata, SEO, data fetching, loading/error UI, and tests.

## Tri-Agent Integration
- Claude: Define routing architecture, data boundaries, and SEO strategy.
- Codex: Implement pages, loading/error UI, and tests.
- Gemini: Review for correctness, SEO coverage, and UX edge cases.

## Arguments

- `$ARGUMENTS` - Page requirements

## Instructions

Follow this workflow:

1. Parse page requirements
2. Generate App Router page component
3. Add metadata and SEO
4. Handle data fetching (Server/Client)
5. Add loading and error states
6. Generate tests

### Parse Requirements

- Route path and segments (static, dynamic, nested)
- Rendering mode (static, dynamic, streaming)
- Data sources and caching strategy
- Client interactivity (forms, state, hooks)
- SEO needs (title, description, OG, canonical)
- UX states (empty, loading, error)
- Test expectations (happy path, edge cases)

### Data Fetching Guidance

- Default to Server Components for data fetching.
- Use Client Components only for interactivity, browser APIs, or client state.
- Server data: `fetch` with `cache`, `revalidate`, or `no-store` as needed.
- Client data: React Query with explicit loading/error UI.

### Requirements

1. TypeScript with explicit prop and return types where non-obvious
2. Server Component by default; add `"use client"` only when required
3. Accessibility: semantic HTML and ARIA labels for controls
4. Metadata and SEO fields (title, description, OG/Twitter)
5. Loading and error UI (`loading.tsx`, `error.tsx`)
6. Tests using Vitest + React Testing Library

## Error Handling
- Use `notFound()` for missing resources and surface user-friendly copy.
- Provide `error.tsx` with recovery actions and log correlation IDs if available.
- Fail fast on failed fetches and avoid rendering partial invalid data.
- Add tests for error boundaries and empty states.

## Templates and Examples

### Example
`@page app/products/[id] "Product detail with SEO, SSR data, and error state"`

#### Static Page (Server Component)

```tsx
// app/[route]/page.tsx
import { type Metadata } from "next";

export const metadata: Metadata = {
  title: "Page Title",
  description: "Page description for SEO",
  openGraph: {
    title: "Page Title",
    description: "Page description for SEO",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "Page Title",
    description: "Page description for SEO",
  },
};

export const dynamic = "force-static";
// export const revalidate = 3600;

interface PageData {
  items: Array<{ id: string; title: string }>;
}

async function getPageData(): Promise<PageData> {
  const response = await fetch("https://example.com/api/items", {
    cache: "force-cache",
  });

  if (!response.ok) {
    throw new Error("Failed to load items");
  }

  return (await response.json()) as PageData;
}

export default async function Page() {
  const data = await getPageData();

  return (
    <div className="container py-8">
      <h1 className="text-3xl font-bold">Page Title</h1>
      <ul className="mt-6 space-y-3">
        {data.items.map((item) => (
          <li key={item.id} className="text-base">
            {item.title}
          </li>
        ))}
      </ul>
    </div>
  );
}
```

#### Dynamic Route Page (Server Component)

```tsx
// app/[route]/[id]/page.tsx
import { notFound } from "next/navigation";
import { type Metadata } from "next";

interface PageProps {
  params: Promise<{ id: string }>;
}

interface Item {
  id: string;
  title: string;
  description: string;
}

async function getItem(id: string): Promise<Item | null> {
  const response = await fetch(`https://example.com/api/items/${id}`, {
    cache: "no-store",
  });

  if (response.status === 404) return null;
  if (!response.ok) throw new Error("Failed to load item");

  return (await response.json()) as Item;
}

export async function generateMetadata({
  params,
}: PageProps): Promise<Metadata> {
  const { id } = await params;
  const item = await getItem(id);

  if (!item) {
    return { title: "Not Found", description: "Item not found." };
  }

  return {
    title: item.title,
    description: item.description,
    openGraph: {
      title: item.title,
      description: item.description,
      type: "article",
    },
  };
}

export default async function Page({ params }: PageProps) {
  const { id } = await params;
  const item = await getItem(id);

  if (!item) notFound();

  return (
    <div className="container py-8">
      <h1 className="text-3xl font-bold">{item.title}</h1>
      <p className="mt-4 text-muted-foreground">{item.description}</p>
    </div>
  );
}
```

#### Client Page (Interactive)

```tsx
// app/[route]/page.tsx
"use client";

import { useQuery } from "@tanstack/react-query";
import { Skeleton } from "@/components/ui/skeleton";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";

interface Item {
  id: string;
  title: string;
}

async function fetchItems(): Promise<Item[]> {
  const response = await fetch("/api/items");

  if (!response.ok) {
    throw new Error("Failed to load items");
  }

  return (await response.json()) as Item[];
}

export default function Page() {
  const { data, isLoading, error } = useQuery<Item[]>({
    queryKey: ["items"],
    queryFn: fetchItems,
  });

  if (isLoading) {
    return (
      <div className="container py-8 space-y-4">
        <Skeleton className="h-8 w-64" />
        <Skeleton className="h-32 w-full" />
      </div>
    );
  }

  if (error instanceof Error) {
    return (
      <Alert variant="destructive" className="container py-8">
        <AlertTitle>Unable to load items</AlertTitle>
        <AlertDescription>{error.message}</AlertDescription>
      </Alert>
    );
  }

  return (
    <div className="container py-8">
      <h1 className="text-3xl font-bold">Items</h1>
      <ul className="mt-6 space-y-3">
        {data?.map((item) => (
          <li key={item.id} className="text-base">
            {item.title}
          </li>
        ))}
      </ul>
    </div>
  );
}
```

#### Streaming Page (Server Component with Suspense)

```tsx
// app/[route]/page.tsx
import { Suspense } from "react";
import { type Metadata } from "next";

export const metadata: Metadata = {
  title: "Streaming Page",
  description: "Progressively rendered content.",
};

export const dynamic = "force-dynamic";

export default function Page() {
  return (
    <div className="container py-8 space-y-8">
      <h1 className="text-3xl font-bold">Streaming Page</h1>
      <Suspense fallback={<SectionSkeleton title="Stats" />}>
        <StatsSection />
      </Suspense>
      <Suspense fallback={<SectionSkeleton title="Latest" />}>
        <LatestSection />
      </Suspense>
    </div>
  );
}

function SectionSkeleton({ title }: { title: string }) {
  return (
    <div className="space-y-3">
      <div className="h-6 w-32 rounded bg-muted" />
      <div className="h-24 w-full rounded bg-muted" />
      <span className="text-sm text-muted-foreground">{title}</span>
    </div>
  );
}

async function StatsSection() {
  const response = await fetch("https://example.com/api/stats", {
    cache: "no-store",
  });
  if (!response.ok) {
    throw new Error("Failed to load stats");
  }
  const stats = (await response.json()) as Array<{ label: string; value: string }>;

  return (
    <div className="grid gap-4 md:grid-cols-3">
      {stats.map((stat) => (
        <div key={stat.label} className="rounded border p-4">
          <div className="text-sm text-muted-foreground">{stat.label}</div>
          <div className="text-2xl font-semibold">{stat.value}</div>
        </div>
      ))}
    </div>
  );
}

async function LatestSection() {
  const response = await fetch("https://example.com/api/latest", {
    cache: "no-store",
  });
  if (!response.ok) {
    throw new Error("Failed to load latest items");
  }
  const items = (await response.json()) as Array<{ id: string; title: string }>;

  return (
    <ul className="space-y-2">
      {items.map((item) => (
        <li key={item.id} className="text-base">
          {item.title}
        </li>
      ))}
    </ul>
  );
}
```

### Loading UI

```tsx
// app/[route]/loading.tsx
import { Skeleton } from "@/components/ui/skeleton";

export default function Loading() {
  return (
    <div className="container py-8 space-y-4">
      <Skeleton className="h-8 w-64" />
      <Skeleton className="h-32 w-full" />
      <Skeleton className="h-32 w-full" />
    </div>
  );
}
```

### Error UI

```tsx
// app/[route]/error.tsx
"use client";

import { useEffect } from "react";
import { Button } from "@/components/ui/button";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";

interface ErrorProps {
  error: Error & { digest?: string };
  reset: () => void;
}

export default function Error({ error, reset }: ErrorProps) {
  useEffect(() => {
    console.error(error);
  }, [error]);

  return (
    <Alert variant="destructive">
      <AlertTitle>Something went wrong</AlertTitle>
      <AlertDescription>{error.message}</AlertDescription>
      <Button onClick={reset} className="mt-4">
        Try again
      </Button>
    </Alert>
  );
}
```

### Test Templates

```tsx
// app/[route]/page.test.tsx
import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import Page from "./page";

describe("Page", () => {
  it("renders the heading", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => {
      return {
        ok: true,
        json: async () => ({ items: [{ id: "1", title: "Item 1" }] }),
      } as Response;
    }));

    const ui = await Page();
    render(ui);

    expect(screen.getByRole("heading", { name: /page title/i })).toBeInTheDocument();
  });
});
```

```tsx
// app/[route]/[id]/page.test.tsx
import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import Page from "./page";

describe("Dynamic Page", () => {
  it("renders item details", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => {
      return {
        ok: true,
        status: 200,
        json: async () => ({
          id: "42",
          title: "Item 42",
          description: "Detail",
        }),
      } as Response;
    }));

    const ui = await Page({ params: Promise.resolve({ id: "42" }) });
    render(ui);

    expect(screen.getByRole("heading", { name: /item 42/i })).toBeInTheDocument();
  });
});
```

## Task

Generate a Next.js page for: $ARGUMENTS

Include:

- App Router `page.tsx` component with explicit types
- Metadata and SEO fields
- Data fetching with proper caching strategy
- `loading.tsx` and `error.tsx` files
- Tests using Vitest + React Testing Library

## Example

```
/web/page Product detail page with dynamic slug, server data fetching, and streaming related items
```
