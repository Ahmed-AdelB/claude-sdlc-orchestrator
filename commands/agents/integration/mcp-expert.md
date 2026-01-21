---
name: MCP Integration Expert Agent
description: Model Context Protocol specialist for server development, tool patterns, and AI integrations
version: 1.0.0
author: Ahmed Adel Bakr Alderai
category: integration
tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
  - Task
allowed_tools:
  - filesystem
  - git
  - github
model_preference: claude-sonnet
thinking_budget: 16000
---

# MCP Integration Expert Agent

Model Context Protocol (MCP) specialist. Expert in MCP server development, tool definitions, resource management, security, testing, and deployment strategies.

## Arguments

- `$ARGUMENTS` - MCP integration task or development request

## Invoke Agent

```
Use the Task tool with subagent_type="mcp-integration-expert" to:

1. Design and implement MCP servers
2. Define tools with proper schemas
3. Manage resources and prompts
4. Implement security best practices
5. Create comprehensive test suites
6. Plan deployment strategies

Task: $ARGUMENTS
```

## Expertise Areas

| Area                | Capabilities                                      |
| ------------------- | ------------------------------------------------- |
| Server Development  | TypeScript, Python, stdio/SSE transports          |
| Tool Definitions    | JSON Schema, input validation, error handling     |
| Resource Management | URI templates, content types, subscriptions       |
| Security            | Authentication, authorization, input sanitization |
| Testing             | Unit tests, integration tests, mock clients       |
| Deployment          | Docker, systemd, cloud functions                  |

---

## MCP Architecture Overview

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   MCP Client    │────▶│   Transport     │────▶│   MCP Server    │
│  (Claude Code)  │◀────│  (stdio/SSE)    │◀────│  (Your Server)  │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                        │
                                    ┌───────────────────┼───────────────────┐
                                    ▼                   ▼                   ▼
                              ┌──────────┐       ┌──────────┐       ┌──────────┐
                              │  Tools   │       │Resources │       │ Prompts  │
                              └──────────┘       └──────────┘       └──────────┘
```

### Core Primitives

| Primitive     | Purpose                                  | Direction                   |
| ------------- | ---------------------------------------- | --------------------------- |
| **Tools**     | Execute actions, call APIs, modify state | Client invokes on Server    |
| **Resources** | Expose data, files, database content     | Server provides to Client   |
| **Prompts**   | Reusable prompt templates with arguments | Server provides to Client   |
| **Sampling**  | Request LLM completions from client      | Server requests from Client |

---

## TypeScript MCP Server Template

### Project Structure

```
my-mcp-server/
├── src/
│   ├── index.ts           # Entry point
│   ├── server.ts          # Server implementation
│   ├── tools/
│   │   ├── index.ts       # Tool registry
│   │   └── example.ts     # Tool implementations
│   ├── resources/
│   │   ├── index.ts       # Resource registry
│   │   └── example.ts     # Resource implementations
│   ├── prompts/
│   │   └── index.ts       # Prompt templates
│   └── utils/
│       ├── validation.ts  # Input validation
│       └── errors.ts      # Error handling
├── tests/
│   ├── tools.test.ts
│   ├── resources.test.ts
│   └── integration.test.ts
├── package.json
├── tsconfig.json
└── README.md
```

### package.json

```json
{
  "name": "my-mcp-server",
  "version": "1.0.0",
  "description": "Custom MCP server",
  "type": "module",
  "main": "dist/index.js",
  "bin": {
    "my-mcp-server": "dist/index.js"
  },
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js",
    "dev": "tsx watch src/index.ts",
    "test": "vitest",
    "lint": "eslint src/",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0",
    "zod": "^3.23.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "typescript": "^5.4.0",
    "tsx": "^4.7.0",
    "vitest": "^1.4.0",
    "eslint": "^8.57.0",
    "@typescript-eslint/eslint-plugin": "^7.0.0"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
```

### tsconfig.json

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "lib": ["ES2022"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "resolveJsonModule": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "tests"]
}
```

### src/index.ts (Entry Point)

```typescript
#!/usr/bin/env node

import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { createServer } from "./server.js";

async function main(): Promise<void> {
  const server = createServer();
  const transport = new StdioServerTransport();

  await server.connect(transport);

  // Handle graceful shutdown
  process.on("SIGINT", async () => {
    await server.close();
    process.exit(0);
  });

  process.on("SIGTERM", async () => {
    await server.close();
    process.exit(0);
  });
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
```

### src/server.ts (Server Implementation)

```typescript
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ListResourcesRequestSchema,
  ReadResourceRequestSchema,
  ListPromptsRequestSchema,
  GetPromptRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

import { tools, handleToolCall } from "./tools/index.js";
import { resources, handleResourceRead } from "./resources/index.js";
import { prompts, handleGetPrompt } from "./prompts/index.js";

export function createServer(): Server {
  const server = new Server(
    {
      name: "my-mcp-server",
      version: "1.0.0",
    },
    {
      capabilities: {
        tools: {},
        resources: { subscribe: true },
        prompts: {},
      },
    },
  );

  // Tool handlers
  server.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools,
  }));

  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;
    return handleToolCall(name, args);
  });

  // Resource handlers
  server.setRequestHandler(ListResourcesRequestSchema, async () => ({
    resources,
  }));

  server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
    const { uri } = request.params;
    return handleResourceRead(uri);
  });

  // Prompt handlers
  server.setRequestHandler(ListPromptsRequestSchema, async () => ({
    prompts,
  }));

  server.setRequestHandler(GetPromptRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;
    return handleGetPrompt(name, args);
  });

  // Error handling
  server.onerror = (error) => {
    console.error("[MCP Error]", error);
  };

  return server;
}
```

### src/tools/index.ts (Tool Registry)

```typescript
import { Tool, CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";

// Tool definitions with JSON Schema
export const tools: Tool[] = [
  {
    name: "database_query",
    description: "Execute a read-only SQL query against the database",
    inputSchema: {
      type: "object",
      properties: {
        query: {
          type: "string",
          description: "SQL SELECT query to execute",
        },
        database: {
          type: "string",
          description: "Database name",
          enum: ["users", "products", "orders"],
        },
        limit: {
          type: "number",
          description: "Maximum rows to return",
          default: 100,
          maximum: 1000,
        },
      },
      required: ["query", "database"],
      additionalProperties: false,
    },
  },
  {
    name: "file_search",
    description: "Search for files matching a pattern in the workspace",
    inputSchema: {
      type: "object",
      properties: {
        pattern: {
          type: "string",
          description: "Glob pattern to match files",
        },
        directory: {
          type: "string",
          description: "Starting directory for search",
          default: ".",
        },
        maxResults: {
          type: "number",
          description: "Maximum number of results",
          default: 50,
        },
      },
      required: ["pattern"],
      additionalProperties: false,
    },
  },
  {
    name: "api_request",
    description: "Make an HTTP request to an external API",
    inputSchema: {
      type: "object",
      properties: {
        method: {
          type: "string",
          enum: ["GET", "POST", "PUT", "DELETE"],
          default: "GET",
        },
        url: {
          type: "string",
          description: "Full URL for the request",
          format: "uri",
        },
        headers: {
          type: "object",
          description: "Request headers",
          additionalProperties: { type: "string" },
        },
        body: {
          type: "object",
          description: "Request body (for POST/PUT)",
        },
        timeout: {
          type: "number",
          description: "Timeout in milliseconds",
          default: 30000,
          maximum: 60000,
        },
      },
      required: ["url"],
      additionalProperties: false,
    },
  },
];

// Zod schemas for runtime validation
const DatabaseQuerySchema = z.object({
  query: z.string().min(1).max(10000),
  database: z.enum(["users", "products", "orders"]),
  limit: z.number().int().min(1).max(1000).default(100),
});

const FileSearchSchema = z.object({
  pattern: z.string().min(1).max(500),
  directory: z.string().default("."),
  maxResults: z.number().int().min(1).max(500).default(50),
});

const ApiRequestSchema = z.object({
  method: z.enum(["GET", "POST", "PUT", "DELETE"]).default("GET"),
  url: z.string().url(),
  headers: z.record(z.string()).optional(),
  body: z.record(z.unknown()).optional(),
  timeout: z.number().int().min(1000).max(60000).default(30000),
});

// Tool implementations
async function handleDatabaseQuery(
  args: z.infer<typeof DatabaseQuerySchema>,
): Promise<CallToolResult> {
  const validated = DatabaseQuerySchema.parse(args);

  // Security: Ensure query is read-only
  const normalizedQuery = validated.query.trim().toUpperCase();
  if (!normalizedQuery.startsWith("SELECT")) {
    return {
      content: [
        {
          type: "text",
          text: "Error: Only SELECT queries are allowed",
        },
      ],
      isError: true,
    };
  }

  // Implementation would connect to actual database
  // This is a placeholder
  return {
    content: [
      {
        type: "text",
        text: JSON.stringify(
          {
            status: "success",
            database: validated.database,
            rowCount: 0,
            rows: [],
          },
          null,
          2,
        ),
      },
    ],
  };
}

async function handleFileSearch(
  args: z.infer<typeof FileSearchSchema>,
): Promise<CallToolResult> {
  const validated = FileSearchSchema.parse(args);

  // Security: Prevent path traversal
  if (validated.pattern.includes("..") || validated.directory.includes("..")) {
    return {
      content: [
        {
          type: "text",
          text: "Error: Path traversal not allowed",
        },
      ],
      isError: true,
    };
  }

  // Implementation would use glob library
  return {
    content: [
      {
        type: "text",
        text: JSON.stringify(
          {
            pattern: validated.pattern,
            matches: [],
          },
          null,
          2,
        ),
      },
    ],
  };
}

async function handleApiRequest(
  args: z.infer<typeof ApiRequestSchema>,
): Promise<CallToolResult> {
  const validated = ApiRequestSchema.parse(args);

  // Security: URL allowlist validation
  const allowedHosts = ["api.example.com", "internal.mycompany.com"];
  const url = new URL(validated.url);

  if (!allowedHosts.includes(url.hostname)) {
    return {
      content: [
        {
          type: "text",
          text: `Error: Host ${url.hostname} not in allowlist`,
        },
      ],
      isError: true,
    };
  }

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), validated.timeout);

    const response = await fetch(validated.url, {
      method: validated.method,
      headers: validated.headers,
      body: validated.body ? JSON.stringify(validated.body) : undefined,
      signal: controller.signal,
    });

    clearTimeout(timeoutId);

    const data = await response.json();

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(
            {
              status: response.status,
              statusText: response.statusText,
              data,
            },
            null,
            2,
          ),
        },
      ],
    };
  } catch (error) {
    return {
      content: [
        {
          type: "text",
          text: `Error: ${error instanceof Error ? error.message : "Unknown error"}`,
        },
      ],
      isError: true,
    };
  }
}

// Tool dispatcher
export async function handleToolCall(
  name: string,
  args: unknown,
): Promise<CallToolResult> {
  try {
    switch (name) {
      case "database_query":
        return await handleDatabaseQuery(
          args as z.infer<typeof DatabaseQuerySchema>,
        );
      case "file_search":
        return await handleFileSearch(args as z.infer<typeof FileSearchSchema>);
      case "api_request":
        return await handleApiRequest(args as z.infer<typeof ApiRequestSchema>);
      default:
        return {
          content: [
            {
              type: "text",
              text: `Unknown tool: ${name}`,
            },
          ],
          isError: true,
        };
    }
  } catch (error) {
    if (error instanceof z.ZodError) {
      return {
        content: [
          {
            type: "text",
            text: `Validation error: ${JSON.stringify(error.errors, null, 2)}`,
          },
        ],
        isError: true,
      };
    }
    return {
      content: [
        {
          type: "text",
          text: `Error: ${error instanceof Error ? error.message : "Unknown error"}`,
        },
      ],
      isError: true,
    };
  }
}
```

### src/resources/index.ts (Resource Registry)

```typescript
import {
  Resource,
  ReadResourceResult,
} from "@modelcontextprotocol/sdk/types.js";

export const resources: Resource[] = [
  {
    uri: "config://app/settings",
    name: "Application Settings",
    description: "Current application configuration",
    mimeType: "application/json",
  },
  {
    uri: "file://workspace/README.md",
    name: "Project README",
    description: "Project documentation",
    mimeType: "text/markdown",
  },
  {
    uri: "db://users/schema",
    name: "Users Table Schema",
    description: "Database schema for users table",
    mimeType: "application/json",
  },
];

// Dynamic resource templates
export const resourceTemplates = [
  {
    uriTemplate: "file://workspace/{path}",
    name: "Workspace Files",
    description: "Access files in the workspace",
    mimeType: "application/octet-stream",
  },
  {
    uriTemplate: "db://{database}/{table}",
    name: "Database Tables",
    description: "Access database table data",
    mimeType: "application/json",
  },
];

export async function handleResourceRead(
  uri: string,
): Promise<ReadResourceResult> {
  const url = new URL(uri);

  switch (url.protocol) {
    case "config:":
      return handleConfigResource(url);
    case "file:":
      return handleFileResource(url);
    case "db:":
      return handleDatabaseResource(url);
    default:
      throw new Error(`Unsupported resource protocol: ${url.protocol}`);
  }
}

async function handleConfigResource(url: URL): Promise<ReadResourceResult> {
  // Security: Only expose non-sensitive config
  const safeConfig = {
    appName: "My Application",
    version: "1.0.0",
    environment: process.env.NODE_ENV || "development",
    features: {
      darkMode: true,
      analytics: false,
    },
  };

  return {
    contents: [
      {
        uri: url.href,
        mimeType: "application/json",
        text: JSON.stringify(safeConfig, null, 2),
      },
    ],
  };
}

async function handleFileResource(url: URL): Promise<ReadResourceResult> {
  const path = url.pathname;

  // Security: Prevent path traversal
  if (path.includes("..")) {
    throw new Error("Path traversal not allowed");
  }

  // Security: Restrict to workspace
  const allowedExtensions = [".md", ".txt", ".json", ".yaml", ".yml"];
  const ext = path.substring(path.lastIndexOf("."));

  if (!allowedExtensions.includes(ext)) {
    throw new Error(`File type ${ext} not allowed`);
  }

  // Implementation would read actual file
  return {
    contents: [
      {
        uri: url.href,
        mimeType: "text/plain",
        text: "File content would be here",
      },
    ],
  };
}

async function handleDatabaseResource(url: URL): Promise<ReadResourceResult> {
  const [database, table] = url.pathname.split("/").filter(Boolean);

  // Security: Validate database and table names
  const allowedDatabases = ["users", "products", "orders"];
  if (!allowedDatabases.includes(database)) {
    throw new Error(`Database ${database} not allowed`);
  }

  // Implementation would query actual database
  return {
    contents: [
      {
        uri: url.href,
        mimeType: "application/json",
        text: JSON.stringify(
          {
            database,
            table,
            schema: {
              columns: [],
            },
          },
          null,
          2,
        ),
      },
    ],
  };
}
```

### src/prompts/index.ts (Prompt Templates)

```typescript
import { Prompt, GetPromptResult } from "@modelcontextprotocol/sdk/types.js";

export const prompts: Prompt[] = [
  {
    name: "code_review",
    description: "Generate a code review for the given code",
    arguments: [
      {
        name: "code",
        description: "The code to review",
        required: true,
      },
      {
        name: "language",
        description: "Programming language",
        required: false,
      },
      {
        name: "focus",
        description: "Areas to focus on (security, performance, style)",
        required: false,
      },
    ],
  },
  {
    name: "sql_query_builder",
    description: "Build a SQL query from natural language",
    arguments: [
      {
        name: "description",
        description: "Natural language description of the query",
        required: true,
      },
      {
        name: "tables",
        description: "Available tables and their columns",
        required: true,
      },
    ],
  },
  {
    name: "api_documentation",
    description: "Generate API documentation for an endpoint",
    arguments: [
      {
        name: "endpoint",
        description: "API endpoint path",
        required: true,
      },
      {
        name: "method",
        description: "HTTP method",
        required: true,
      },
      {
        name: "requestBody",
        description: "Request body schema",
        required: false,
      },
      {
        name: "responseBody",
        description: "Response body schema",
        required: false,
      },
    ],
  },
];

export async function handleGetPrompt(
  name: string,
  args: Record<string, string> | undefined,
): Promise<GetPromptResult> {
  switch (name) {
    case "code_review":
      return buildCodeReviewPrompt(args);
    case "sql_query_builder":
      return buildSqlQueryPrompt(args);
    case "api_documentation":
      return buildApiDocPrompt(args);
    default:
      throw new Error(`Unknown prompt: ${name}`);
  }
}

function buildCodeReviewPrompt(
  args: Record<string, string> | undefined,
): GetPromptResult {
  const code = args?.code || "";
  const language = args?.language || "unknown";
  const focus = args?.focus || "general";

  return {
    description: "Code review prompt",
    messages: [
      {
        role: "user",
        content: {
          type: "text",
          text: `Please review the following ${language} code with a focus on ${focus}:

\`\`\`${language}
${code}
\`\`\`

Provide feedback on:
1. Code quality and readability
2. Potential bugs or issues
3. Security concerns
4. Performance considerations
5. Suggestions for improvement`,
        },
      },
    ],
  };
}

function buildSqlQueryPrompt(
  args: Record<string, string> | undefined,
): GetPromptResult {
  const description = args?.description || "";
  const tables = args?.tables || "";

  return {
    description: "SQL query builder prompt",
    messages: [
      {
        role: "user",
        content: {
          type: "text",
          text: `Build a SQL query based on this description:

Description: ${description}

Available tables and columns:
${tables}

Requirements:
- Use only SELECT statements
- Include appropriate JOINs if needed
- Add WHERE clauses for filtering
- Use aliases for clarity
- Optimize for readability`,
        },
      },
    ],
  };
}

function buildApiDocPrompt(
  args: Record<string, string> | undefined,
): GetPromptResult {
  const endpoint = args?.endpoint || "";
  const method = args?.method || "GET";
  const requestBody = args?.requestBody || "N/A";
  const responseBody = args?.responseBody || "N/A";

  return {
    description: "API documentation prompt",
    messages: [
      {
        role: "user",
        content: {
          type: "text",
          text: `Generate OpenAPI-style documentation for this endpoint:

Endpoint: ${method} ${endpoint}
Request Body: ${requestBody}
Response Body: ${responseBody}

Include:
- Summary and description
- Parameters (path, query, header)
- Request body schema
- Response codes and schemas
- Example requests and responses`,
        },
      },
    ],
  };
}
```

---

## Python MCP Server Template

### Project Structure

```
my-mcp-server-python/
├── src/
│   └── my_mcp_server/
│       ├── __init__.py
│       ├── __main__.py
│       ├── server.py
│       ├── tools.py
│       ├── resources.py
│       └── prompts.py
├── tests/
│   ├── __init__.py
│   ├── test_tools.py
│   ├── test_resources.py
│   └── conftest.py
├── pyproject.toml
└── README.md
```

### pyproject.toml

```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "my-mcp-server"
version = "1.0.0"
description = "Custom MCP server in Python"
readme = "README.md"
requires-python = ">=3.10"
license = "MIT"
dependencies = [
    "mcp>=1.0.0",
    "pydantic>=2.0.0",
    "httpx>=0.27.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0.0",
    "pytest-asyncio>=0.23.0",
    "ruff>=0.3.0",
    "mypy>=1.9.0",
]

[project.scripts]
my-mcp-server = "my_mcp_server:main"

[tool.hatch.build.targets.wheel]
packages = ["src/my_mcp_server"]

[tool.ruff]
line-length = 100
target-version = "py310"

[tool.ruff.lint]
select = ["E", "F", "I", "N", "W", "UP", "S", "B", "A", "C4", "DTZ", "T10", "ISC", "ICN", "PIE", "PT", "RET", "SIM", "TID", "ARG", "PLC", "PLE", "PLR", "PLW", "TRY", "RUF"]

[tool.mypy]
python_version = "3.10"
strict = true
warn_return_any = true
warn_unused_configs = true

[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths = ["tests"]
```

### src/my_mcp_server/**init**.py

```python
"""MCP Server Package."""

from .server import create_server, main

__all__ = ["create_server", "main"]
```

### src/my_mcp_server/**main**.py

```python
"""Entry point for running as module."""

from . import main

if __name__ == "__main__":
    main()
```

### src/my_mcp_server/server.py

```python
"""MCP Server Implementation."""

import asyncio
import logging
import signal
from typing import Any

from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import (
    CallToolResult,
    GetPromptResult,
    ListPromptsResult,
    ListResourcesResult,
    ListToolsResult,
    ReadResourceResult,
    TextContent,
)

from .tools import TOOLS, handle_tool_call
from .resources import RESOURCES, handle_resource_read
from .prompts import PROMPTS, handle_get_prompt

logger = logging.getLogger(__name__)


def create_server() -> Server:
    """Create and configure the MCP server."""
    server = Server("my-mcp-server")

    @server.list_tools()
    async def list_tools() -> ListToolsResult:
        """Return available tools."""
        return ListToolsResult(tools=TOOLS)

    @server.call_tool()
    async def call_tool(name: str, arguments: dict[str, Any]) -> CallToolResult:
        """Handle tool invocation."""
        return await handle_tool_call(name, arguments)

    @server.list_resources()
    async def list_resources() -> ListResourcesResult:
        """Return available resources."""
        return ListResourcesResult(resources=RESOURCES)

    @server.read_resource()
    async def read_resource(uri: str) -> ReadResourceResult:
        """Handle resource read."""
        return await handle_resource_read(uri)

    @server.list_prompts()
    async def list_prompts() -> ListPromptsResult:
        """Return available prompts."""
        return ListPromptsResult(prompts=PROMPTS)

    @server.get_prompt()
    async def get_prompt(
        name: str, arguments: dict[str, str] | None = None
    ) -> GetPromptResult:
        """Handle prompt retrieval."""
        return await handle_get_prompt(name, arguments)

    return server


async def run_server() -> None:
    """Run the MCP server."""
    server = create_server()

    # Setup signal handlers for graceful shutdown
    loop = asyncio.get_event_loop()

    def signal_handler() -> None:
        logger.info("Received shutdown signal")
        loop.stop()

    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, signal_handler)

    async with stdio_server() as (read_stream, write_stream):
        await server.run(read_stream, write_stream, server.create_initialization_options())


def main() -> None:
    """Main entry point."""
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )

    try:
        asyncio.run(run_server())
    except KeyboardInterrupt:
        logger.info("Server shutdown complete")
```

### src/my_mcp_server/tools.py

```python
"""Tool definitions and handlers."""

from typing import Any
from urllib.parse import urlparse

import httpx
from mcp.types import CallToolResult, TextContent, Tool
from pydantic import BaseModel, Field, ValidationError, field_validator


# Pydantic models for validation
class DatabaseQueryInput(BaseModel):
    """Input schema for database query tool."""

    query: str = Field(..., min_length=1, max_length=10000)
    database: str = Field(..., pattern=r"^(users|products|orders)$")
    limit: int = Field(default=100, ge=1, le=1000)

    @field_validator("query")
    @classmethod
    def validate_query(cls, v: str) -> str:
        """Ensure query is read-only."""
        normalized = v.strip().upper()
        if not normalized.startswith("SELECT"):
            raise ValueError("Only SELECT queries are allowed")
        return v


class FileSearchInput(BaseModel):
    """Input schema for file search tool."""

    pattern: str = Field(..., min_length=1, max_length=500)
    directory: str = Field(default=".")
    max_results: int = Field(default=50, ge=1, le=500)

    @field_validator("pattern", "directory")
    @classmethod
    def validate_no_traversal(cls, v: str) -> str:
        """Prevent path traversal attacks."""
        if ".." in v:
            raise ValueError("Path traversal not allowed")
        return v


class ApiRequestInput(BaseModel):
    """Input schema for API request tool."""

    method: str = Field(default="GET", pattern=r"^(GET|POST|PUT|DELETE)$")
    url: str
    headers: dict[str, str] | None = None
    body: dict[str, Any] | None = None
    timeout: int = Field(default=30000, ge=1000, le=60000)

    @field_validator("url")
    @classmethod
    def validate_url(cls, v: str) -> str:
        """Validate URL and check allowlist."""
        parsed = urlparse(v)
        allowed_hosts = ["api.example.com", "internal.mycompany.com"]
        if parsed.hostname not in allowed_hosts:
            raise ValueError(f"Host {parsed.hostname} not in allowlist")
        return v


# Tool definitions
TOOLS: list[Tool] = [
    Tool(
        name="database_query",
        description="Execute a read-only SQL query against the database",
        inputSchema={
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "SQL SELECT query to execute",
                },
                "database": {
                    "type": "string",
                    "description": "Database name",
                    "enum": ["users", "products", "orders"],
                },
                "limit": {
                    "type": "integer",
                    "description": "Maximum rows to return",
                    "default": 100,
                    "maximum": 1000,
                },
            },
            "required": ["query", "database"],
            "additionalProperties": False,
        },
    ),
    Tool(
        name="file_search",
        description="Search for files matching a pattern in the workspace",
        inputSchema={
            "type": "object",
            "properties": {
                "pattern": {
                    "type": "string",
                    "description": "Glob pattern to match files",
                },
                "directory": {
                    "type": "string",
                    "description": "Starting directory for search",
                    "default": ".",
                },
                "max_results": {
                    "type": "integer",
                    "description": "Maximum number of results",
                    "default": 50,
                },
            },
            "required": ["pattern"],
            "additionalProperties": False,
        },
    ),
    Tool(
        name="api_request",
        description="Make an HTTP request to an external API",
        inputSchema={
            "type": "object",
            "properties": {
                "method": {
                    "type": "string",
                    "enum": ["GET", "POST", "PUT", "DELETE"],
                    "default": "GET",
                },
                "url": {
                    "type": "string",
                    "description": "Full URL for the request",
                    "format": "uri",
                },
                "headers": {
                    "type": "object",
                    "description": "Request headers",
                    "additionalProperties": {"type": "string"},
                },
                "body": {
                    "type": "object",
                    "description": "Request body (for POST/PUT)",
                },
                "timeout": {
                    "type": "integer",
                    "description": "Timeout in milliseconds",
                    "default": 30000,
                    "maximum": 60000,
                },
            },
            "required": ["url"],
            "additionalProperties": False,
        },
    ),
]


async def handle_database_query(args: dict[str, Any]) -> CallToolResult:
    """Handle database query tool."""
    try:
        validated = DatabaseQueryInput(**args)
    except ValidationError as e:
        return CallToolResult(
            content=[TextContent(type="text", text=f"Validation error: {e}")],
            isError=True,
        )

    # Implementation would connect to actual database
    import json
    result = {
        "status": "success",
        "database": validated.database,
        "rowCount": 0,
        "rows": [],
    }

    return CallToolResult(
        content=[TextContent(type="text", text=json.dumps(result, indent=2))]
    )


async def handle_file_search(args: dict[str, Any]) -> CallToolResult:
    """Handle file search tool."""
    try:
        validated = FileSearchInput(**args)
    except ValidationError as e:
        return CallToolResult(
            content=[TextContent(type="text", text=f"Validation error: {e}")],
            isError=True,
        )

    # Implementation would use glob
    import json
    result = {
        "pattern": validated.pattern,
        "matches": [],
    }

    return CallToolResult(
        content=[TextContent(type="text", text=json.dumps(result, indent=2))]
    )


async def handle_api_request(args: dict[str, Any]) -> CallToolResult:
    """Handle API request tool."""
    try:
        validated = ApiRequestInput(**args)
    except ValidationError as e:
        return CallToolResult(
            content=[TextContent(type="text", text=f"Validation error: {e}")],
            isError=True,
        )

    try:
        async with httpx.AsyncClient() as client:
            response = await client.request(
                method=validated.method,
                url=validated.url,
                headers=validated.headers,
                json=validated.body if validated.body else None,
                timeout=validated.timeout / 1000,
            )

            import json
            result = {
                "status": response.status_code,
                "statusText": response.reason_phrase,
                "data": response.json() if response.headers.get("content-type", "").startswith("application/json") else response.text,
            }

            return CallToolResult(
                content=[TextContent(type="text", text=json.dumps(result, indent=2))]
            )
    except Exception as e:
        return CallToolResult(
            content=[TextContent(type="text", text=f"Error: {str(e)}")],
            isError=True,
        )


async def handle_tool_call(name: str, arguments: dict[str, Any]) -> CallToolResult:
    """Route tool calls to appropriate handler."""
    handlers = {
        "database_query": handle_database_query,
        "file_search": handle_file_search,
        "api_request": handle_api_request,
    }

    handler = handlers.get(name)
    if not handler:
        return CallToolResult(
            content=[TextContent(type="text", text=f"Unknown tool: {name}")],
            isError=True,
        )

    return await handler(arguments)
```

---

## Security Best Practices

### 1. Input Validation (CRITICAL)

```typescript
// Always validate ALL inputs with strict schemas
import { z } from "zod";

const StrictInputSchema = z
  .object({
    query: z
      .string()
      .min(1)
      .max(10000)
      .refine(
        (q) => !q.toLowerCase().includes("drop"),
        "Dangerous SQL keyword detected",
      ),
    path: z
      .string()
      .refine(
        (p) => !p.includes("..") && !p.startsWith("/"),
        "Path traversal detected",
      ),
  })
  .strict(); // Reject unknown properties
```

### 2. URL Allowlisting

```typescript
const ALLOWED_HOSTS = new Set(["api.example.com", "internal.company.com"]);

const ALLOWED_SCHEMES = new Set(["https"]);

function validateUrl(url: string): boolean {
  try {
    const parsed = new URL(url);
    return (
      ALLOWED_SCHEMES.has(parsed.protocol.replace(":", "")) &&
      ALLOWED_HOSTS.has(parsed.hostname)
    );
  } catch {
    return false;
  }
}
```

### 3. Rate Limiting

```typescript
import { RateLimiterMemory } from "rate-limiter-flexible";

const rateLimiter = new RateLimiterMemory({
  points: 100, // Number of requests
  duration: 60, // Per 60 seconds
  blockDuration: 60, // Block for 60 seconds if exceeded
});

async function withRateLimit<T>(key: string, fn: () => Promise<T>): Promise<T> {
  try {
    await rateLimiter.consume(key);
    return await fn();
  } catch (error) {
    throw new Error("Rate limit exceeded");
  }
}
```

### 4. Secrets Management

```typescript
// NEVER log or expose secrets
const REDACTED_PATTERNS = [
  /api[_-]?key/i,
  /password/i,
  /secret/i,
  /token/i,
  /bearer/i,
];

function redactSensitive(obj: unknown): unknown {
  if (typeof obj === "string") {
    return obj.replace(/Bearer [^ ]+/gi, "Bearer [REDACTED]");
  }
  if (typeof obj === "object" && obj !== null) {
    const result: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(obj)) {
      if (REDACTED_PATTERNS.some((p) => p.test(key))) {
        result[key] = "[REDACTED]";
      } else {
        result[key] = redactSensitive(value);
      }
    }
    return result;
  }
  return obj;
}
```

### 5. Authorization Scopes

```typescript
type Scope = "read" | "write" | "admin";

interface ToolDefinition {
  name: string;
  requiredScopes: Scope[];
  handler: ToolHandler;
}

const tools: ToolDefinition[] = [
  {
    name: "database_query",
    requiredScopes: ["read"],
    handler: handleDatabaseQuery,
  },
  {
    name: "database_write",
    requiredScopes: ["write"],
    handler: handleDatabaseWrite,
  },
  {
    name: "system_config",
    requiredScopes: ["admin"],
    handler: handleSystemConfig,
  },
];

function checkScopes(required: Scope[], granted: Scope[]): boolean {
  return required.every((scope) => granted.includes(scope));
}
```

---

## Testing MCP Servers

### Unit Tests (TypeScript with Vitest)

```typescript
// tests/tools.test.ts
import { describe, it, expect, vi, beforeEach } from "vitest";
import { handleToolCall, tools } from "../src/tools/index.js";

describe("Tools", () => {
  describe("database_query", () => {
    it("should reject non-SELECT queries", async () => {
      const result = await handleToolCall("database_query", {
        query: "DROP TABLE users",
        database: "users",
      });

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Only SELECT queries");
    });

    it("should validate database name", async () => {
      const result = await handleToolCall("database_query", {
        query: "SELECT * FROM users",
        database: "invalid_db",
      });

      expect(result.isError).toBe(true);
    });

    it("should enforce limit constraints", async () => {
      const result = await handleToolCall("database_query", {
        query: "SELECT * FROM users",
        database: "users",
        limit: 5000, // Exceeds max
      });

      expect(result.isError).toBe(true);
    });
  });

  describe("file_search", () => {
    it("should prevent path traversal", async () => {
      const result = await handleToolCall("file_search", {
        pattern: "../../../etc/passwd",
      });

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Path traversal");
    });
  });

  describe("api_request", () => {
    it("should reject disallowed hosts", async () => {
      const result = await handleToolCall("api_request", {
        url: "https://evil.com/steal-data",
      });

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("not in allowlist");
    });
  });
});
```

### Integration Tests

```typescript
// tests/integration.test.ts
import { describe, it, expect, beforeAll, afterAll } from "vitest";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import { createServer } from "../src/server.js";

describe("MCP Server Integration", () => {
  let client: Client;
  let serverTransport: InMemoryTransport;
  let clientTransport: InMemoryTransport;

  beforeAll(async () => {
    const server = createServer();
    [serverTransport, clientTransport] = InMemoryTransport.createLinkedPair();

    client = new Client(
      { name: "test-client", version: "1.0.0" },
      { capabilities: {} },
    );

    await Promise.all([
      server.connect(serverTransport),
      client.connect(clientTransport),
    ]);
  });

  afterAll(async () => {
    await client.close();
  });

  it("should list all tools", async () => {
    const result = await client.listTools();

    expect(result.tools).toHaveLength(3);
    expect(result.tools.map((t) => t.name)).toContain("database_query");
  });

  it("should list all resources", async () => {
    const result = await client.listResources();

    expect(result.resources.length).toBeGreaterThan(0);
  });

  it("should list all prompts", async () => {
    const result = await client.listPrompts();

    expect(result.prompts.length).toBeGreaterThan(0);
  });

  it("should execute tool and return result", async () => {
    const result = await client.callTool({
      name: "database_query",
      arguments: {
        query: "SELECT * FROM users LIMIT 10",
        database: "users",
      },
    });

    expect(result.isError).toBeFalsy();
    const content = JSON.parse(result.content[0].text);
    expect(content.status).toBe("success");
  });
});
```

### Mock Client for Testing

```typescript
// tests/mock-client.ts
import { EventEmitter } from "events";

export class MockMCPClient extends EventEmitter {
  private tools: Map<string, unknown> = new Map();
  private resources: Map<string, unknown> = new Map();

  async callTool(name: string, args: unknown): Promise<unknown> {
    // Simulate tool call
    this.emit("tool:call", { name, args });
    return { success: true };
  }

  async readResource(uri: string): Promise<unknown> {
    // Simulate resource read
    this.emit("resource:read", { uri });
    return { contents: [] };
  }

  async getPrompt(
    name: string,
    args?: Record<string, string>,
  ): Promise<unknown> {
    // Simulate prompt retrieval
    this.emit("prompt:get", { name, args });
    return { messages: [] };
  }
}
```

---

## Deployment Strategies

### 1. Docker Deployment

```dockerfile
# Dockerfile
FROM node:20-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-alpine AS runner

WORKDIR /app
RUN addgroup -g 1001 -S mcp && \
    adduser -S mcp -u 1001 -G mcp

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./

USER mcp
ENV NODE_ENV=production

ENTRYPOINT ["node", "dist/index.js"]
```

```yaml
# docker-compose.yml
version: "3.8"

services:
  mcp-server:
    build: .
    restart: unless-stopped
    environment:
      - NODE_ENV=production
      - LOG_LEVEL=info
    volumes:
      - ./config:/app/config:ro
    healthcheck:
      test: ["CMD", "node", "-e", "process.exit(0)"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 256M
```

### 2. Systemd Service

```ini
# /etc/systemd/system/mcp-server.service
[Unit]
Description=MCP Server
After=network.target

[Service]
Type=simple
User=mcp
Group=mcp
WorkingDirectory=/opt/mcp-server
ExecStart=/usr/bin/node /opt/mcp-server/dist/index.js
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=mcp-server

# Security hardening
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
RestrictNamespaces=yes
LockPersonality=yes
MemoryDenyWriteExecute=yes
RestrictRealtime=yes
RestrictSUIDSGID=yes

[Install]
WantedBy=multi-user.target
```

### 3. Claude Code Configuration

```json
// ~/.claude/mcp.json
{
  "mcpServers": {
    "my-mcp-server": {
      "command": "node",
      "args": ["/path/to/my-mcp-server/dist/index.js"],
      "env": {
        "NODE_ENV": "production",
        "LOG_LEVEL": "info"
      }
    },
    "my-python-server": {
      "command": "python",
      "args": ["-m", "my_mcp_server"],
      "env": {
        "PYTHONPATH": "/path/to/my-mcp-server-python/src"
      }
    }
  }
}
```

### 4. Health Monitoring

```typescript
// src/health.ts
interface HealthStatus {
  status: "healthy" | "degraded" | "unhealthy";
  checks: {
    name: string;
    status: "pass" | "fail";
    message?: string;
  }[];
  timestamp: string;
}

export async function checkHealth(): Promise<HealthStatus> {
  const checks = await Promise.all([
    checkDatabaseConnection(),
    checkExternalApi(),
    checkDiskSpace(),
  ]);

  const status = checks.every((c) => c.status === "pass")
    ? "healthy"
    : checks.some((c) => c.status === "pass")
      ? "degraded"
      : "unhealthy";

  return {
    status,
    checks,
    timestamp: new Date().toISOString(),
  };
}
```

---

## Integration with Existing MCP Ecosystem

### Available Official MCP Servers

| Server                                      | Purpose            | Install    |
| ------------------------------------------- | ------------------ | ---------- |
| `@modelcontextprotocol/server-filesystem`   | File system access | `npm i -g` |
| `@modelcontextprotocol/server-git`          | Git operations     | `npm i -g` |
| `@modelcontextprotocol/server-github`       | GitHub API         | `npm i -g` |
| `@modelcontextprotocol/server-postgres`     | PostgreSQL access  | `npm i -g` |
| `@modelcontextprotocol/server-sqlite`       | SQLite access      | `npm i -g` |
| `@modelcontextprotocol/server-brave-search` | Brave Search API   | `npm i -g` |

### Composing Multiple Servers

```json
// ~/.claude/mcp.json
{
  "mcpServers": {
    "git": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-git"]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      }
    },
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "DATABASE_URL": "${DATABASE_URL}"
      }
    },
    "custom": {
      "command": "node",
      "args": ["./my-custom-server/dist/index.js"]
    }
  }
}
```

---

## Common Patterns

### 1. Tool Chaining

```typescript
// Chain multiple tools for complex workflows
async function handleComplexWorkflow(
  args: WorkflowArgs,
): Promise<CallToolResult> {
  // Step 1: Query database
  const queryResult = await handleDatabaseQuery({
    query: `SELECT * FROM ${args.table} WHERE id = ?`,
    database: args.database,
    params: [args.id],
  });

  if (queryResult.isError) {
    return queryResult;
  }

  // Step 2: Process data
  const data = JSON.parse(queryResult.content[0].text);

  // Step 3: Call external API
  const apiResult = await handleApiRequest({
    method: "POST",
    url: "https://api.example.com/process",
    body: data,
  });

  return apiResult;
}
```

### 2. Resource Subscriptions

```typescript
// Enable real-time resource updates
server.setRequestHandler(SubscribeRequestSchema, async (request) => {
  const { uri } = request.params;

  // Add subscription
  subscriptions.add(uri);

  // Set up watcher
  watchResource(uri, (update) => {
    server.notification({
      method: "notifications/resources/updated",
      params: { uri },
    });
  });

  return {};
});
```

### 3. Progress Reporting

```typescript
// Report progress for long-running tools
async function handleLongRunningTool(
  args: unknown,
  progressToken?: string,
): Promise<CallToolResult> {
  const total = 100;

  for (let i = 0; i <= total; i += 10) {
    // Report progress
    if (progressToken) {
      await server.notification({
        method: "notifications/progress",
        params: {
          progressToken,
          progress: i,
          total,
        },
      });
    }

    // Do work
    await processChunk(i);
  }

  return {
    content: [{ type: "text", text: "Complete" }],
  };
}
```

---

## Debugging Tips

```bash
# Enable debug logging
export MCP_DEBUG=1

# Test server manually with stdio
echo '{"jsonrpc":"2.0","method":"initialize","params":{"capabilities":{}},"id":1}' | node dist/index.js

# Validate JSON-RPC messages
npx @modelcontextprotocol/inspector

# Monitor server logs
journalctl -u mcp-server -f
```

---

## Example Invocations

```bash
# Create new MCP server
/agents/integration/mcp-expert create TypeScript MCP server for Jira integration

# Add tool to existing server
/agents/integration/mcp-expert add tool for creating GitHub issues with labels

# Implement resource provider
/agents/integration/mcp-expert implement resource provider for S3 bucket contents

# Security audit
/agents/integration/mcp-expert review MCP server security for production deployment

# Testing
/agents/integration/mcp-expert write comprehensive tests for MCP tools

# Deployment
/agents/integration/mcp-expert create Docker deployment for MCP server
```

---

## References

- [MCP Specification](https://spec.modelcontextprotocol.io/)
- [MCP TypeScript SDK](https://github.com/modelcontextprotocol/typescript-sdk)
- [MCP Python SDK](https://github.com/modelcontextprotocol/python-sdk)
- [Official MCP Servers](https://github.com/modelcontextprotocol/servers)
- [Claude Code MCP Integration](https://docs.anthropic.com/claude-code/mcp)
