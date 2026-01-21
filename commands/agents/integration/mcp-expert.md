---
name: MCP Expert Agent
description: Comprehensive Model Context Protocol specialist for server development, tool definitions, transport layers, security, testing, and Claude Code integration
version: 2.1.0
author: Ahmed Adel Bakr Alderai
category: integration
tags:
  - mcp
  - model-context-protocol
  - ai-integration
  - tools
  - resources
  - prompts
  - claude-code
  - stdio
  - sse
  - websocket
  - json-rpc
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
dependencies:
  - /agents/backend/backend-developer
  - /agents/backend/nodejs-expert
  - /agents/frontend/typescript-expert
  - /agents/security/security-expert
  - /agents/testing/integration-test-expert
inputs:
  - name: task
    type: string
    required: true
    description: The MCP development task or integration request
  - name: language
    type: string
    required: false
    default: typescript
    description: "Implementation language (typescript, python)"
  - name: transport
    type: string
    required: false
    default: stdio
    description: "Transport layer (stdio, sse, websocket)"
outputs:
  - mcp_server_implementation
  - tool_definitions
  - resource_handlers
  - prompt_templates
  - security_configuration
  - test_suite
  - deployment_config
model_preference: claude-sonnet
thinking_budget: 16000
---

# MCP Expert Agent

Model Context Protocol (MCP) specialist. Expert in MCP server development, tool definitions, resource management, transport layers (stdio, SSE, WebSocket), authentication, security, testing, debugging, and Claude Code integration.

## Arguments

- `$ARGUMENTS` - MCP development task or integration request

## Invoke Agent

```
Use the Task tool with subagent_type="mcp-expert" to:

1. Design and implement MCP servers (TypeScript/Python)
2. Define tools with JSON Schema validation
3. Implement resource providers and subscriptions
4. Configure transport layers (stdio, SSE, WebSocket)
5. Implement authentication and authorization
6. Create comprehensive test suites
7. Debug and monitor MCP servers
8. Integrate with Claude Code

Task: $ARGUMENTS
```

## Core Expertise

| Area                | Capabilities                                          |
| ------------------- | ----------------------------------------------------- |
| Server Development  | TypeScript SDK, Python SDK, async patterns            |
| Tool Definitions    | JSON Schema, Zod/Pydantic validation, error handling  |
| Resource Management | URI templates, MIME types, subscriptions, caching     |
| Prompt Templates    | Parameterized prompts, argument validation, context   |
| Transport Layers    | stdio, Server-Sent Events (SSE), WebSocket            |
| Authentication      | API keys, OAuth, JWT, mTLS, scope-based authorization |
| Security            | Input validation, rate limiting, sandboxing           |
| Testing             | Unit tests, integration tests, mock clients           |
| Deployment          | Docker, systemd, cloud functions, Claude Code config  |
| Debugging           | MCP Inspector, logging, tracing, error diagnostics    |

---

## Table of Contents

1. [MCP Architecture Overview](#mcp-architecture-overview)
2. [Transport Layer Options](#transport-layer-options)
3. [Tool Definitions and Handlers](#tool-definitions-and-handlers)
4. [Resource Management](#resource-management)
5. [Prompt Templates](#prompt-templates)
6. [Authentication and Authorization](#authentication-and-authorization)
7. [Rate Limiting](#rate-limiting)
8. [Input Sanitization and Security](#input-sanitization-and-security)
9. [Error Handling Patterns](#error-handling-patterns)
10. [Testing MCP Servers](#testing-mcp-servers)
11. [Debugging and Monitoring](#debugging-and-monitoring)
12. [Claude Code Integration](#claude-code-integration)
13. [Common MCP Server Patterns](#common-mcp-server-patterns)
14. [Performance Optimization](#performance-optimization)
15. [Deployment](#deployment)
16. [Troubleshooting Guide](#troubleshooting-guide)
17. [Production Checklist](#production-checklist)

---

## MCP Architecture Overview

```
                              MCP PROTOCOL ARCHITECTURE
+------------------+                                      +------------------+
|                  |          JSON-RPC 2.0                |                  |
|   MCP CLIENT     |<------------------------------------>|   MCP SERVER     |
|  (Claude Code)   |          (Bidirectional)             |  (Your Server)   |
|                  |                                      |                  |
+--------+---------+                                      +--------+---------+
         |                                                         |
         |  Capabilities:                                          |  Provides:
         |  - tools                                                |  - Tools
         |  - resources                                            |  - Resources
         |  - prompts                                              |  - Prompts
         |  - sampling (optional)                                  |  - Notifications
         |                                                         |
         +------------------+  +------------------+  +--------------+
                            |  |                  |  |
                            v  v                  v  v
                     +------------+        +------------+
                     | TRANSPORT  |        | TRANSPORT  |
                     |   LAYER    |        |   LAYER    |
                     +------------+        +------------+
                            |                    |
              +-------------+-------------+------+------+
              |             |             |             |
         +----v----+  +-----v-----+  +----v----+  +-----v-----+
         |  stdio  |  |    SSE    |  |WebSocket|  |  Custom   |
         +---------+  +-----------+  +---------+  +-----------+
```

### Protocol Primitives

| Primitive     | Description                              | Direction                   | Use Case                        |
| ------------- | ---------------------------------------- | --------------------------- | ------------------------------- |
| **Tools**     | Executable functions with typed inputs   | Client invokes on Server    | API calls, file ops, DB queries |
| **Resources** | Read-only data sources with URI schemes  | Server provides to Client   | Config files, DB schemas, docs  |
| **Prompts**   | Reusable prompt templates with arguments | Server provides to Client   | Code review, SQL builder        |
| **Sampling**  | Request LLM completions from client      | Server requests from Client | Agentic workflows               |

### Message Flow

```
Client                                              Server
   |                                                   |
   |  -------- initialize (capabilities) ---------->   |
   |  <------- initialize response ----------------    |
   |                                                   |
   |  -------- tools/list ------------------------->   |
   |  <------- tools list response ----------------    |
   |                                                   |
   |  -------- tools/call (name, args) ------------>   |
   |  <------- tool result ------------------------    |
   |                                                   |
   |  -------- resources/list -------------------->    |
   |  <------- resources list response ------------    |
   |                                                   |
   |  -------- resources/read (uri) --------------->   |
   |  <------- resource contents ------------------    |
   |                                                   |
   |  -------- prompts/list ----------------------->   |
   |  <------- prompts list response --------------    |
   |                                                   |
   |  -------- prompts/get (name, args) ----------->   |
   |  <------- prompt messages --------------------    |
   |                                                   |
   |  <------- notifications/resources/updated ----    |
   |                                                   |
```

### MCP Server Capabilities Declaration

```typescript
// src/capabilities.ts
import { ServerCapabilities } from "@modelcontextprotocol/sdk/types.js";

export const serverCapabilities: ServerCapabilities = {
  tools: {
    // Server provides tools
  },
  resources: {
    // Server provides resources
    subscribe: true, // Supports resource subscriptions
  },
  prompts: {
    // Server provides prompt templates
  },
  logging: {
    // Server supports logging
  },
  // Optional: sampling capability for agentic workflows
  // sampling: {}
};
```

---

## Transport Layer Options

MCP supports multiple transport mechanisms. Choose based on your deployment requirements.

### 1. stdio Transport (Default)

The simplest transport - communication via standard input/output streams. Ideal for local processes.

**Characteristics:**

- Synchronous communication model
- Process-based isolation
- No network overhead
- Built-in with most SDKs

**TypeScript Implementation:**

```typescript
// src/transports/stdio.ts
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { Server } from "@modelcontextprotocol/sdk/server/index.js";

export async function startStdioServer(server: Server): Promise<void> {
  const transport = new StdioServerTransport();

  // Connect server to transport
  await server.connect(transport);

  // Handle process signals
  const cleanup = async () => {
    await server.close();
    process.exit(0);
  };

  process.on("SIGINT", cleanup);
  process.on("SIGTERM", cleanup);

  // Keep process alive
  process.stdin.resume();
}
```

**Python Implementation:**

```python
# src/transports/stdio.py
import asyncio
import signal
from mcp.server import Server
from mcp.server.stdio import stdio_server

async def start_stdio_server(server: Server) -> None:
    """Start MCP server with stdio transport."""

    # Setup signal handlers
    loop = asyncio.get_event_loop()

    def signal_handler():
        loop.stop()

    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, signal_handler)

    # Run server
    async with stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream,
            write_stream,
            server.create_initialization_options()
        )
```

**Claude Code Configuration:**

```json
{
  "mcpServers": {
    "my-server": {
      "command": "node",
      "args": ["/path/to/server/dist/index.js"],
      "env": {
        "NODE_ENV": "production"
      }
    }
  }
}
```

### 2. Server-Sent Events (SSE) Transport

HTTP-based transport using SSE for server-to-client streaming and POST for client-to-server messages.

**Characteristics:**

- HTTP/1.1 compatible
- Firewall-friendly
- Server push support
- Good for web deployments

**TypeScript Implementation:**

```typescript
// src/transports/sse.ts
import express, { Request, Response } from "express";
import { SSEServerTransport } from "@modelcontextprotocol/sdk/server/sse.js";
import { Server } from "@modelcontextprotocol/sdk/server/index.js";

export async function startSSEServer(
  server: Server,
  port: number = 3000,
): Promise<void> {
  const app = express();

  // Store active transports by session
  const transports = new Map<string, SSEServerTransport>();

  // SSE endpoint for server-to-client messages
  app.get("/mcp/sse", async (req: Request, res: Response) => {
    const sessionId = req.query.sessionId as string;

    if (!sessionId) {
      return res.status(400).json({ error: "sessionId required" });
    }

    // SSE headers
    res.setHeader("Content-Type", "text/event-stream");
    res.setHeader("Cache-Control", "no-cache");
    res.setHeader("Connection", "keep-alive");
    res.setHeader("X-Accel-Buffering", "no"); // Disable nginx buffering

    // Create transport
    const transport = new SSEServerTransport("/mcp/messages", res);
    transports.set(sessionId, transport);

    // Connect server
    await server.connect(transport);

    // Cleanup on close
    req.on("close", () => {
      transports.delete(sessionId);
    });
  });

  // POST endpoint for client-to-server messages
  app.post(
    "/mcp/messages",
    express.json(),
    async (req: Request, res: Response) => {
      const sessionId = req.query.sessionId as string;
      const transport = transports.get(sessionId);

      if (!transport) {
        return res.status(404).json({ error: "Session not found" });
      }

      // Handle incoming message
      await transport.handlePostMessage(req, res);
    },
  );

  // Health check
  app.get("/health", (req, res) => {
    res.json({
      status: "healthy",
      activeSessions: transports.size,
      timestamp: new Date().toISOString(),
    });
  });

  app.listen(port, () => {
    console.log(`MCP SSE server listening on port ${port}`);
  });
}
```

**Python Implementation:**

```python
# src/transports/sse.py
from typing import Dict
from datetime import datetime
from fastapi import FastAPI, Request, Response
from sse_starlette.sse import EventSourceResponse
import asyncio
import json
import uuid

app = FastAPI()
sessions: Dict[str, asyncio.Queue] = {}

class SSETransport:
    """SSE transport for MCP server."""

    def __init__(self, session_id: str):
        self.session_id = session_id
        self.queue: asyncio.Queue = asyncio.Queue()
        sessions[session_id] = self.queue

    async def send(self, message: dict) -> None:
        """Send message to client via SSE."""
        await self.queue.put(json.dumps(message))

    async def receive(self) -> dict:
        """Receive message from client (via POST)."""
        # This is handled by the POST endpoint
        pass

    def close(self) -> None:
        """Close the transport."""
        if self.session_id in sessions:
            del sessions[self.session_id]


@app.get("/mcp/sse")
async def sse_endpoint(request: Request, session_id: str = None):
    """SSE endpoint for server-to-client messages."""
    if not session_id:
        session_id = str(uuid.uuid4())

    transport = SSETransport(session_id)

    async def event_generator():
        # Send session ID first
        yield {
            "event": "session",
            "data": json.dumps({"sessionId": session_id})
        }

        try:
            while True:
                # Wait for messages
                message = await asyncio.wait_for(
                    transport.queue.get(),
                    timeout=30.0
                )
                yield {
                    "event": "message",
                    "data": message
                }
        except asyncio.TimeoutError:
            # Send keepalive
            yield {"event": "ping", "data": ""}
        except asyncio.CancelledError:
            transport.close()

    return EventSourceResponse(event_generator())


@app.post("/mcp/messages")
async def message_endpoint(request: Request, session_id: str):
    """POST endpoint for client-to-server messages."""
    if session_id not in sessions:
        return Response(status_code=404, content="Session not found")

    body = await request.json()
    # Process message and send response via SSE
    # ... implement message handling

    return Response(status_code=202, content="Accepted")


@app.get("/health")
async def health():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "activeSessions": len(sessions),
        "timestamp": datetime.utcnow().isoformat()
    }
```

### 3. WebSocket Transport

Full-duplex communication over a single TCP connection.

**Characteristics:**

- Bidirectional real-time communication
- Lower latency than SSE
- Persistent connection
- Good for high-frequency updates

**TypeScript Implementation:**

```typescript
// src/transports/websocket.ts
import WebSocket, { WebSocketServer } from "ws";
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import http from "http";

interface WebSocketTransport {
  send(message: unknown): void;
  onMessage(handler: (message: unknown) => void): void;
  close(): void;
}

export async function startWebSocketServer(
  createServer: () => Server,
  port: number = 8080,
): Promise<void> {
  const httpServer = http.createServer();
  const wss = new WebSocketServer({ server: httpServer });

  // Track active connections
  const connections = new Map<
    string,
    {
      ws: WebSocket;
      server: Server;
    }
  >();

  wss.on("connection", async (ws: WebSocket, req) => {
    const connectionId = crypto.randomUUID();
    console.log(`New WebSocket connection: ${connectionId}`);

    // Create new server instance per connection
    const server = createServer();

    // Create transport adapter
    const transport: WebSocketTransport = {
      send: (message) => {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify(message));
        }
      },
      onMessage: (handler) => {
        ws.on("message", (data) => {
          try {
            const message = JSON.parse(data.toString());
            handler(message);
          } catch (error) {
            console.error("Invalid message format:", error);
          }
        });
      },
      close: () => {
        ws.close();
      },
    };

    // Store connection
    connections.set(connectionId, { ws, server });

    // Handle close
    ws.on("close", () => {
      console.log(`WebSocket closed: ${connectionId}`);
      connections.delete(connectionId);
      server.close();
    });

    // Handle errors
    ws.on("error", (error) => {
      console.error(`WebSocket error: ${connectionId}`, error);
    });

    // Connect server to transport
    await connectServerToWebSocket(server, transport);

    // Send connection acknowledgment
    ws.send(
      JSON.stringify({
        type: "connected",
        connectionId,
        timestamp: new Date().toISOString(),
      }),
    );
  });

  // Heartbeat to detect dead connections
  const heartbeatInterval = setInterval(() => {
    for (const [id, { ws }] of connections) {
      if (ws.readyState === WebSocket.OPEN) {
        ws.ping();
      } else {
        connections.delete(id);
      }
    }
  }, 30000);

  httpServer.listen(port, () => {
    console.log(`MCP WebSocket server listening on port ${port}`);
  });

  // Cleanup on shutdown
  process.on("SIGTERM", () => {
    clearInterval(heartbeatInterval);
    wss.close();
    httpServer.close();
  });
}

async function connectServerToWebSocket(
  server: Server,
  transport: WebSocketTransport,
): Promise<void> {
  // Bridge WebSocket to MCP transport interface
  transport.onMessage(async (message) => {
    // Route message to server
    // Implementation depends on MCP SDK internals
  });
}
```

**Python Implementation:**

```python
# src/transports/websocket.py
import asyncio
import json
from typing import Dict, Set
from datetime import datetime
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from mcp.server import Server
import uuid

app = FastAPI()

class WebSocketManager:
    """Manages WebSocket connections for MCP."""

    def __init__(self):
        self.active_connections: Dict[str, WebSocket] = {}
        self.servers: Dict[str, Server] = {}

    async def connect(self, websocket: WebSocket, connection_id: str) -> None:
        """Accept new WebSocket connection."""
        await websocket.accept()
        self.active_connections[connection_id] = websocket

    def disconnect(self, connection_id: str) -> None:
        """Remove disconnected client."""
        if connection_id in self.active_connections:
            del self.active_connections[connection_id]
        if connection_id in self.servers:
            del self.servers[connection_id]

    async def send_message(self, connection_id: str, message: dict) -> None:
        """Send message to specific client."""
        websocket = self.active_connections.get(connection_id)
        if websocket:
            await websocket.send_json(message)

    async def broadcast(self, message: dict, exclude: Set[str] = None) -> None:
        """Broadcast message to all clients."""
        exclude = exclude or set()
        for conn_id, websocket in self.active_connections.items():
            if conn_id not in exclude:
                await websocket.send_json(message)


manager = WebSocketManager()


@app.websocket("/mcp/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for MCP communication."""
    connection_id = str(uuid.uuid4())

    await manager.connect(websocket, connection_id)

    # Send connection acknowledgment
    await websocket.send_json({
        "type": "connected",
        "connectionId": connection_id,
        "timestamp": datetime.utcnow().isoformat()
    })

    try:
        while True:
            # Receive message
            data = await websocket.receive_json()

            # Process MCP message
            response = await process_mcp_message(connection_id, data)

            # Send response
            if response:
                await manager.send_message(connection_id, response)

    except WebSocketDisconnect:
        manager.disconnect(connection_id)
    except Exception as e:
        print(f"WebSocket error: {e}")
        manager.disconnect(connection_id)


async def process_mcp_message(connection_id: str, message: dict) -> dict | None:
    """Process incoming MCP message and return response."""
    method = message.get("method")
    params = message.get("params", {})
    msg_id = message.get("id")

    # Route to appropriate handler
    try:
        if method == "initialize":
            result = await handle_initialize(connection_id, params)
        elif method == "tools/list":
            result = await handle_list_tools(connection_id)
        elif method == "tools/call":
            result = await handle_call_tool(connection_id, params)
        elif method == "resources/list":
            result = await handle_list_resources(connection_id)
        elif method == "resources/read":
            result = await handle_read_resource(connection_id, params)
        elif method == "prompts/list":
            result = await handle_list_prompts(connection_id)
        elif method == "prompts/get":
            result = await handle_get_prompt(connection_id, params)
        else:
            return {
                "jsonrpc": "2.0",
                "id": msg_id,
                "error": {"code": -32601, "message": f"Method not found: {method}"}
            }

        return {
            "jsonrpc": "2.0",
            "id": msg_id,
            "result": result
        }
    except Exception as e:
        return {
            "jsonrpc": "2.0",
            "id": msg_id,
            "error": {"code": -32000, "message": str(e)}
        }
```

### Transport Comparison

| Feature             | stdio           | SSE             | WebSocket       |
| ------------------- | --------------- | --------------- | --------------- |
| Latency             | Low             | Medium          | Low             |
| Bidirectional       | Yes             | POST + SSE      | Yes             |
| Browser compatible  | No              | Yes             | Yes             |
| Firewall friendly   | N/A (local)     | Yes             | Usually         |
| Connection overhead | Process spawn   | HTTP connection | TCP + Upgrade   |
| Scalability         | Per-process     | HTTP scaling    | WebSocket pools |
| Best for            | Local CLI tools | Web deployments | Real-time apps  |

---

## Tool Definitions and Handlers

### Tool Schema Structure

```typescript
// src/tools/types.ts
import { z } from "zod";

// Tool definition with Zod schema
export interface ToolDefinition<T extends z.ZodTypeAny> {
  name: string;
  description: string;
  inputSchema: T;
  handler: (input: z.infer<T>) => Promise<ToolResult>;
}

export interface ToolResult {
  content: Array<{
    type: "text" | "image" | "resource";
    text?: string;
    data?: string;
    mimeType?: string;
  }>;
  isError?: boolean;
}
```

### Complete Tool Implementation Example

```typescript
// src/tools/database.ts
import { z } from "zod";
import { ToolDefinition, ToolResult } from "./types.js";

// Input validation schema
const DatabaseQuerySchema = z.object({
  query: z
    .string()
    .min(1)
    .max(10000)
    .refine(
      (q) => {
        const upper = q.toUpperCase().trim();
        return (
          upper.startsWith("SELECT") ||
          upper.startsWith("WITH") ||
          upper.startsWith("EXPLAIN")
        );
      },
      { message: "Only SELECT, WITH, and EXPLAIN queries are allowed" },
    ),
  database: z.enum(["users", "products", "orders", "analytics"]),
  limit: z.number().int().min(1).max(1000).default(100),
  timeout: z.number().int().min(1000).max(30000).default(5000),
});

type DatabaseQueryInput = z.infer<typeof DatabaseQuerySchema>;

// Tool definition
export const databaseQueryTool: ToolDefinition<typeof DatabaseQuerySchema> = {
  name: "database_query",
  description: `Execute a read-only SQL query against the specified database.

Supported databases: users, products, orders, analytics
Only SELECT, WITH, and EXPLAIN queries are permitted.
Results are limited to prevent excessive data transfer.`,
  inputSchema: DatabaseQuerySchema,
  handler: async (input: DatabaseQueryInput): Promise<ToolResult> => {
    try {
      // Validate and sanitize input
      const validated = DatabaseQuerySchema.parse(input);

      // Execute query with timeout
      const results = await executeQueryWithTimeout(
        validated.database,
        validated.query,
        validated.limit,
        validated.timeout,
      );

      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(
              {
                status: "success",
                database: validated.database,
                rowCount: results.rows.length,
                columns: results.columns,
                rows: results.rows,
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
            text: JSON.stringify(
              {
                status: "error",
                message:
                  error instanceof Error ? error.message : "Unknown error",
              },
              null,
              2,
            ),
          },
        ],
        isError: true,
      };
    }
  },
};

// Convert Zod schema to JSON Schema for MCP
export function zodToJsonSchema(schema: z.ZodTypeAny): object {
  // Use zod-to-json-schema library or manual conversion
  return {
    type: "object",
    properties: {
      query: {
        type: "string",
        description: "SQL query to execute (SELECT/WITH/EXPLAIN only)",
        minLength: 1,
        maxLength: 10000,
      },
      database: {
        type: "string",
        enum: ["users", "products", "orders", "analytics"],
        description: "Target database",
      },
      limit: {
        type: "integer",
        minimum: 1,
        maximum: 1000,
        default: 100,
        description: "Maximum rows to return",
      },
      timeout: {
        type: "integer",
        minimum: 1000,
        maximum: 30000,
        default: 5000,
        description: "Query timeout in milliseconds",
      },
    },
    required: ["query", "database"],
  };
}
```

### Tool Registry Pattern

```typescript
// src/tools/registry.ts
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import {
  ListToolsRequestSchema,
  CallToolRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

interface RegisteredTool {
  name: string;
  description: string;
  inputSchema: object;
  handler: (args: unknown) => Promise<unknown>;
}

export class ToolRegistry {
  private tools: Map<string, RegisteredTool> = new Map();

  register(tool: RegisteredTool): void {
    if (this.tools.has(tool.name)) {
      throw new Error(`Tool already registered: ${tool.name}`);
    }
    this.tools.set(tool.name, tool);
  }

  unregister(name: string): boolean {
    return this.tools.delete(name);
  }

  get(name: string): RegisteredTool | undefined {
    return this.tools.get(name);
  }

  list(): RegisteredTool[] {
    return Array.from(this.tools.values());
  }

  attachToServer(server: Server): void {
    // Handle tools/list
    server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: this.list().map((tool) => ({
        name: tool.name,
        description: tool.description,
        inputSchema: tool.inputSchema,
      })),
    }));

    // Handle tools/call
    server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const tool = this.get(request.params.name);

      if (!tool) {
        return {
          content: [
            {
              type: "text",
              text: `Unknown tool: ${request.params.name}`,
            },
          ],
          isError: true,
        };
      }

      try {
        const result = await tool.handler(request.params.arguments);
        return result;
      } catch (error) {
        return {
          content: [
            {
              type: "text",
              text: `Tool error: ${error instanceof Error ? error.message : "Unknown error"}`,
            },
          ],
          isError: true,
        };
      }
    });
  }
}
```

---

## Resource Management

### Resource Definition

```typescript
// src/resources/types.ts
export interface Resource {
  uri: string;
  name: string;
  description?: string;
  mimeType?: string;
}

export interface ResourceContent {
  uri: string;
  mimeType?: string;
  text?: string;
  blob?: string; // base64 encoded
}

export interface ResourceTemplate {
  uriTemplate: string;
  name: string;
  description?: string;
  mimeType?: string;
}
```

### Resource Provider Implementation

```typescript
// src/resources/provider.ts
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import {
  ListResourcesRequestSchema,
  ReadResourceRequestSchema,
  ListResourceTemplatesRequestSchema,
  SubscribeRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { Resource, ResourceContent, ResourceTemplate } from "./types.js";

export class ResourceProvider {
  private resources: Map<string, Resource> = new Map();
  private templates: Map<string, ResourceTemplate> = new Map();
  private handlers: Map<string, (uri: string) => Promise<ResourceContent>> =
    new Map();
  private subscriptions: Map<string, Set<string>> = new Map(); // uri -> subscriber IDs
  private server?: Server;

  registerResource(resource: Resource): void {
    this.resources.set(resource.uri, resource);
  }

  registerTemplate(template: ResourceTemplate): void {
    this.templates.set(template.uriTemplate, template);
  }

  registerHandler(
    protocol: string,
    handler: (uri: string) => Promise<ResourceContent>,
  ): void {
    this.handlers.set(protocol, handler);
  }

  attachToServer(server: Server): void {
    this.server = server;

    // List resources
    server.setRequestHandler(ListResourcesRequestSchema, async () => ({
      resources: Array.from(this.resources.values()),
    }));

    // List resource templates
    server.setRequestHandler(ListResourceTemplatesRequestSchema, async () => ({
      resourceTemplates: Array.from(this.templates.values()),
    }));

    // Read resource
    server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
      const uri = request.params.uri;
      const protocol = uri.split("://")[0];
      const handler = this.handlers.get(protocol);

      if (!handler) {
        throw new Error(`No handler for protocol: ${protocol}`);
      }

      const content = await handler(uri);
      return { contents: [content] };
    });

    // Subscribe to resource changes
    server.setRequestHandler(SubscribeRequestSchema, async (request) => {
      const uri = request.params.uri;

      if (!this.subscriptions.has(uri)) {
        this.subscriptions.set(uri, new Set());
      }

      // In a real implementation, you would track the client ID
      this.subscriptions.get(uri)!.add("default-client");

      return {};
    });
  }

  // Notify subscribers of resource changes
  async notifyResourceUpdated(uri: string): Promise<void> {
    if (!this.server) return;

    const subscribers = this.subscriptions.get(uri);
    if (!subscribers || subscribers.size === 0) return;

    await this.server.notification({
      method: "notifications/resources/updated",
      params: { uri },
    });
  }

  // Notify subscribers that resource list changed
  async notifyResourceListChanged(): Promise<void> {
    if (!this.server) return;

    await this.server.notification({
      method: "notifications/resources/list_changed",
    });
  }
}
```

### File System Resource Handler

```typescript
// src/resources/handlers/filesystem.ts
import fs from "fs/promises";
import path from "path";
import mime from "mime-types";
import { ResourceContent } from "../types.js";

const ALLOWED_BASE_PATHS = ["/home/user/projects", "/var/data", process.cwd()];

export async function fileHandler(uri: string): Promise<ResourceContent> {
  // Parse URI: file:///path/to/file.txt
  const filePath = uri.replace("file://", "");

  // Security: Validate path is within allowed directories
  const resolvedPath = path.resolve(filePath);
  const isAllowed = ALLOWED_BASE_PATHS.some((base) =>
    resolvedPath.startsWith(path.resolve(base)),
  );

  if (!isAllowed) {
    throw new Error(`Access denied: ${filePath}`);
  }

  // Check file exists
  try {
    await fs.access(resolvedPath);
  } catch {
    throw new Error(`File not found: ${filePath}`);
  }

  // Get file stats
  const stats = await fs.stat(resolvedPath);

  // Size limit (10MB)
  if (stats.size > 10 * 1024 * 1024) {
    throw new Error("File too large (max 10MB)");
  }

  // Determine MIME type
  const mimeType = mime.lookup(resolvedPath) || "application/octet-stream";

  // Read file
  if (mimeType.startsWith("text/") || mimeType === "application/json") {
    const content = await fs.readFile(resolvedPath, "utf-8");
    return { uri, mimeType, text: content };
  } else {
    const content = await fs.readFile(resolvedPath);
    return { uri, mimeType, blob: content.toString("base64") };
  }
}
```

### Database Schema Resource Handler

```typescript
// src/resources/handlers/database.ts
import { ResourceContent } from "../types.js";

export async function dbSchemaHandler(uri: string): Promise<ResourceContent> {
  // Parse URI: db://database/table
  const match = uri.match(/^db:\/\/([^/]+)(?:\/(.+))?$/);

  if (!match) {
    throw new Error(`Invalid database URI: ${uri}`);
  }

  const [, database, table] = match;

  if (table) {
    // Get specific table schema
    const schema = await getTableSchema(database, table);
    return {
      uri,
      mimeType: "application/json",
      text: JSON.stringify(schema, null, 2),
    };
  } else {
    // Get all tables in database
    const tables = await getDatabaseTables(database);
    return {
      uri,
      mimeType: "application/json",
      text: JSON.stringify({ database, tables }, null, 2),
    };
  }
}

async function getTableSchema(
  database: string,
  table: string,
): Promise<object> {
  // Implementation depends on your database
  return {
    table,
    columns: [
      { name: "id", type: "INTEGER", primaryKey: true },
      { name: "name", type: "VARCHAR(255)", nullable: false },
      { name: "created_at", type: "TIMESTAMP", default: "CURRENT_TIMESTAMP" },
    ],
  };
}

async function getDatabaseTables(database: string): Promise<string[]> {
  // Implementation depends on your database
  return ["users", "orders", "products"];
}
```

---

## Prompt Templates

Prompts allow servers to define reusable, parameterized prompt templates that clients can use.

### Prompt Definition Types

```typescript
// src/prompts/types.ts
export interface PromptArgument {
  name: string;
  description?: string;
  required?: boolean;
}

export interface Prompt {
  name: string;
  description?: string;
  arguments?: PromptArgument[];
}

export interface PromptMessage {
  role: "user" | "assistant";
  content: {
    type: "text" | "image" | "resource";
    text?: string;
    data?: string;
    mimeType?: string;
    resource?: {
      uri: string;
      text?: string;
      blob?: string;
    };
  };
}

export interface GetPromptResult {
  description?: string;
  messages: PromptMessage[];
}
```

### Prompt Provider Implementation

```typescript
// src/prompts/provider.ts
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import {
  ListPromptsRequestSchema,
  GetPromptRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { Prompt, GetPromptResult } from "./types.js";

type PromptHandler = (args: Record<string, string>) => Promise<GetPromptResult>;

export class PromptProvider {
  private prompts: Map<string, Prompt> = new Map();
  private handlers: Map<string, PromptHandler> = new Map();

  registerPrompt(prompt: Prompt, handler: PromptHandler): void {
    this.prompts.set(prompt.name, prompt);
    this.handlers.set(prompt.name, handler);
  }

  attachToServer(server: Server): void {
    // List prompts
    server.setRequestHandler(ListPromptsRequestSchema, async () => ({
      prompts: Array.from(this.prompts.values()),
    }));

    // Get prompt
    server.setRequestHandler(GetPromptRequestSchema, async (request) => {
      const { name, arguments: args = {} } = request.params;

      const handler = this.handlers.get(name);
      if (!handler) {
        throw new Error(`Unknown prompt: ${name}`);
      }

      const prompt = this.prompts.get(name)!;

      // Validate required arguments
      for (const arg of prompt.arguments || []) {
        if (arg.required && !(arg.name in args)) {
          throw new Error(`Missing required argument: ${arg.name}`);
        }
      }

      return handler(args);
    });
  }
}
```

### Code Review Prompt Example

```typescript
// src/prompts/templates/code-review.ts
import { Prompt, GetPromptResult, PromptMessage } from "../types.js";

export const codeReviewPrompt: Prompt = {
  name: "code_review",
  description: "Generate a comprehensive code review for the provided code",
  arguments: [
    {
      name: "code",
      description: "The code to review",
      required: true,
    },
    {
      name: "language",
      description: "Programming language of the code",
      required: true,
    },
    {
      name: "focus",
      description:
        "Areas to focus on: security, performance, readability, or all",
      required: false,
    },
  ],
};

export async function codeReviewHandler(
  args: Record<string, string>,
): Promise<GetPromptResult> {
  const { code, language, focus = "all" } = args;

  const focusAreas =
    focus === "all"
      ? [
          "security vulnerabilities",
          "performance issues",
          "code readability",
          "best practices",
          "potential bugs",
        ]
      : [focus];

  const messages: PromptMessage[] = [
    {
      role: "user",
      content: {
        type: "text",
        text: `Please review the following ${language} code, focusing on: ${focusAreas.join(", ")}.

Provide a detailed analysis with:
1. Summary of findings
2. Critical issues (if any)
3. Recommendations for improvement
4. Code snippets showing suggested changes

Code to review:
\`\`\`${language}
${code}
\`\`\``,
      },
    },
  ];

  return {
    description: `Code review for ${language} code focusing on ${focus}`,
    messages,
  };
}
```

### SQL Query Builder Prompt

```typescript
// src/prompts/templates/sql-builder.ts
import { Prompt, GetPromptResult } from "../types.js";

export const sqlBuilderPrompt: Prompt = {
  name: "sql_query_builder",
  description:
    "Generate SQL queries from natural language descriptions with schema context",
  arguments: [
    {
      name: "description",
      description: "Natural language description of the desired query",
      required: true,
    },
    {
      name: "database",
      description: "Target database name",
      required: true,
    },
    {
      name: "dialect",
      description: "SQL dialect: postgres, mysql, sqlite",
      required: false,
    },
  ],
};

export async function sqlBuilderHandler(
  args: Record<string, string>,
): Promise<GetPromptResult> {
  const { description, database, dialect = "postgres" } = args;

  // In a real implementation, you would fetch the actual schema
  const schema = await fetchDatabaseSchema(database);

  return {
    description: `SQL query builder for ${database}`,
    messages: [
      {
        role: "user",
        content: {
          type: "text",
          text: `Generate a ${dialect.toUpperCase()} query for the following request:

"${description}"

Database schema:
${JSON.stringify(schema, null, 2)}

Requirements:
1. Use proper ${dialect} syntax
2. Include comments explaining the query
3. Consider performance implications
4. Handle NULL values appropriately
5. Use parameterized queries if user input is involved

Provide the query along with any important notes about its behavior.`,
        },
      },
    ],
  };
}

async function fetchDatabaseSchema(database: string): Promise<object> {
  // Fetch actual schema from your database
  return {
    tables: {
      users: {
        columns: ["id", "email", "name", "created_at"],
        primaryKey: "id",
      },
      orders: {
        columns: ["id", "user_id", "total", "status", "created_at"],
        primaryKey: "id",
        foreignKeys: { user_id: "users.id" },
      },
    },
  };
}
```

### Git Commit Message Prompt

```typescript
// src/prompts/templates/git-commit.ts
import { Prompt, GetPromptResult } from "../types.js";

export const gitCommitPrompt: Prompt = {
  name: "git_commit_message",
  description: "Generate a conventional commit message from a diff",
  arguments: [
    {
      name: "diff",
      description: "Git diff output",
      required: true,
    },
    {
      name: "type",
      description: "Commit type: feat, fix, docs, style, refactor, test, chore",
      required: false,
    },
  ],
};

export async function gitCommitHandler(
  args: Record<string, string>,
): Promise<GetPromptResult> {
  const { diff, type } = args;

  const typeInstruction = type
    ? `The commit type should be: ${type}`
    : "Determine the appropriate commit type from: feat, fix, docs, style, refactor, test, chore";

  return {
    description: "Generate conventional commit message",
    messages: [
      {
        role: "user",
        content: {
          type: "text",
          text: `Generate a conventional commit message for the following changes.

${typeInstruction}

Format:
type(scope): subject

body (optional - explain what and why, not how)

Rules:
- Subject line max 72 characters
- Use imperative mood ("add" not "added")
- Don't end subject with period
- Body wrapped at 72 characters

Diff:
\`\`\`diff
${diff}
\`\`\`

Provide only the commit message, no additional commentary.`,
        },
      },
    ],
  };
}
```

---

## Authentication and Authorization

### 1. API Key Authentication

```typescript
// src/auth/api-key.ts
import { Request, Response, NextFunction } from "express";
import crypto from "crypto";

interface ApiKeyConfig {
  keys: Map<
    string,
    {
      name: string;
      scopes: string[];
      rateLimit: number;
      expiresAt?: Date;
    }
  >;
}

export function createApiKeyAuth(config: ApiKeyConfig) {
  return async (req: Request, res: Response, next: NextFunction) => {
    const authHeader = req.headers.authorization;

    if (!authHeader?.startsWith("Bearer ")) {
      return res.status(401).json({
        error: "missing_api_key",
        message: "Authorization header with Bearer token required",
      });
    }

    const apiKey = authHeader.slice(7);

    // Constant-time comparison to prevent timing attacks
    let validKey: string | null = null;
    for (const [key] of config.keys) {
      if (
        crypto.timingSafeEqual(
          Buffer.from(key),
          Buffer.from(apiKey.padEnd(key.length)),
        )
      ) {
        validKey = key;
        break;
      }
    }

    if (!validKey) {
      return res.status(401).json({
        error: "invalid_api_key",
        message: "Invalid or expired API key",
      });
    }

    const keyConfig = config.keys.get(validKey)!;

    // Check expiration
    if (keyConfig.expiresAt && keyConfig.expiresAt < new Date()) {
      return res.status(401).json({
        error: "expired_api_key",
        message: "API key has expired",
      });
    }

    // Attach key info to request
    req.apiKey = {
      name: keyConfig.name,
      scopes: keyConfig.scopes,
    };

    next();
  };
}

// Extend Express Request type
declare global {
  namespace Express {
    interface Request {
      apiKey?: {
        name: string;
        scopes: string[];
      };
    }
  }
}
```

### 2. OAuth 2.0 Integration

```typescript
// src/auth/oauth.ts
import { OAuth2Client } from "google-auth-library";

interface OAuthConfig {
  clientId: string;
  clientSecret: string;
  redirectUri: string;
  allowedDomains?: string[];
}

export class OAuthAuthenticator {
  private client: OAuth2Client;
  private config: OAuthConfig;

  constructor(config: OAuthConfig) {
    this.config = config;
    this.client = new OAuth2Client(
      config.clientId,
      config.clientSecret,
      config.redirectUri,
    );
  }

  async verifyIdToken(idToken: string): Promise<{
    userId: string;
    email: string;
    name: string;
    scopes: string[];
  }> {
    const ticket = await this.client.verifyIdToken({
      idToken,
      audience: this.config.clientId,
    });

    const payload = ticket.getPayload();

    if (!payload) {
      throw new Error("Invalid token payload");
    }

    // Check domain restriction
    if (this.config.allowedDomains) {
      const domain = payload.hd || payload.email?.split("@")[1];
      if (!domain || !this.config.allowedDomains.includes(domain)) {
        throw new Error("Domain not allowed");
      }
    }

    return {
      userId: payload.sub!,
      email: payload.email!,
      name: payload.name || payload.email!,
      scopes: this.determineScopes(payload),
    };
  }

  private determineScopes(payload: any): string[] {
    // Map user attributes to scopes
    const scopes = ["read"];

    if (payload.hd === "mycompany.com") {
      scopes.push("write");
    }

    // Admin check
    const adminEmails = process.env.ADMIN_EMAILS?.split(",") || [];
    if (adminEmails.includes(payload.email)) {
      scopes.push("admin");
    }

    return scopes;
  }
}
```

### 3. JWT Session Management

```typescript
// src/auth/jwt.ts
import jwt, { JwtPayload } from "jsonwebtoken";
import crypto from "crypto";

interface SessionPayload extends JwtPayload {
  userId: string;
  scopes: string[];
  connectionId: string;
}

const JWT_SECRET =
  process.env.JWT_SECRET || crypto.randomBytes(32).toString("hex");
const JWT_EXPIRY = "1h";

export function createSessionToken(
  payload: Omit<SessionPayload, "iat" | "exp">,
): string {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRY });
}

export function verifySessionToken(token: string): SessionPayload {
  try {
    return jwt.verify(token, JWT_SECRET) as SessionPayload;
  } catch (error) {
    if (error instanceof jwt.TokenExpiredError) {
      throw new Error("Session expired");
    }
    throw new Error("Invalid session token");
  }
}

export function refreshSessionToken(token: string): string {
  const payload = verifySessionToken(token);

  // Create new token with same claims
  return createSessionToken({
    userId: payload.userId,
    scopes: payload.scopes,
    connectionId: payload.connectionId,
  });
}
```

### 4. Scope-Based Authorization

```typescript
// src/auth/authorization.ts
type Scope = "read" | "write" | "admin" | "tools:*" | "resources:*";

interface AuthorizationPolicy {
  tools: Map<string, Scope[]>;
  resources: Map<string, Scope[]>;
  prompts: Map<string, Scope[]>;
}

const defaultPolicy: AuthorizationPolicy = {
  tools: new Map([
    ["database_query", ["read"]],
    ["database_write", ["write"]],
    ["file_search", ["read"]],
    ["file_write", ["write"]],
    ["system_config", ["admin"]],
    ["api_request", ["read", "write"]],
  ]),
  resources: new Map([
    ["config://*", ["read"]],
    ["file://*", ["read"]],
    ["db://*", ["read"]],
  ]),
  prompts: new Map([
    ["code_review", ["read"]],
    ["sql_query_builder", ["read", "write"]],
  ]),
};

export class Authorizer {
  constructor(private policy: AuthorizationPolicy = defaultPolicy) {}

  canAccessTool(toolName: string, userScopes: Scope[]): boolean {
    const requiredScopes = this.policy.tools.get(toolName);

    if (!requiredScopes) {
      // Default deny for unknown tools
      return false;
    }

    // Check if user has wildcard scope
    if (userScopes.includes("tools:*")) {
      return true;
    }

    // Check if user has any required scope
    return requiredScopes.some((scope) => userScopes.includes(scope));
  }

  canAccessResource(uri: string, userScopes: Scope[]): boolean {
    // Check wildcard scope
    if (userScopes.includes("resources:*")) {
      return true;
    }

    // Match against patterns
    for (const [pattern, requiredScopes] of this.policy.resources) {
      if (this.matchesPattern(uri, pattern)) {
        return requiredScopes.some((scope) => userScopes.includes(scope));
      }
    }

    return false;
  }

  private matchesPattern(uri: string, pattern: string): boolean {
    const regex = new RegExp(
      "^" + pattern.replace(/\*/g, ".*").replace(/\?/g, ".") + "$",
    );
    return regex.test(uri);
  }

  filterTools(tools: any[], userScopes: Scope[]): any[] {
    return tools.filter((tool) => this.canAccessTool(tool.name, userScopes));
  }
}
```

### 5. mTLS (Mutual TLS)

```typescript
// src/auth/mtls.ts
import https from "https";
import fs from "fs";
import { Express } from "express";

interface MTLSConfig {
  serverCert: string;
  serverKey: string;
  caCert: string;
  allowedCNs?: string[];
}

export function createMTLSServer(
  app: Express,
  config: MTLSConfig,
): https.Server {
  const options: https.ServerOptions = {
    cert: fs.readFileSync(config.serverCert),
    key: fs.readFileSync(config.serverKey),
    ca: fs.readFileSync(config.caCert),
    requestCert: true,
    rejectUnauthorized: true,
  };

  const server = https.createServer(options, app);

  // Add middleware to validate client certificate
  app.use((req, res, next) => {
    const cert = (req.socket as any).getPeerCertificate();

    if (!cert || !cert.subject) {
      return res.status(401).json({
        error: "client_cert_required",
        message: "Valid client certificate required",
      });
    }

    // Validate CN if allowlist specified
    if (config.allowedCNs) {
      if (!config.allowedCNs.includes(cert.subject.CN)) {
        return res.status(403).json({
          error: "unauthorized_client",
          message: `Client CN '${cert.subject.CN}' not authorized`,
        });
      }
    }

    // Attach cert info to request
    (req as any).clientCert = {
      cn: cert.subject.CN,
      org: cert.subject.O,
      validFrom: new Date(cert.valid_from),
      validTo: new Date(cert.valid_to),
    };

    next();
  });

  return server;
}
```

---

## Rate Limiting

### Token Bucket Rate Limiter

```typescript
// src/ratelimit/token-bucket.ts
interface RateLimitConfig {
  tokensPerInterval: number;
  interval: number; // milliseconds
  maxTokens: number;
}

interface TokenBucket {
  tokens: number;
  lastRefill: number;
}

export class RateLimiter {
  private buckets: Map<string, TokenBucket> = new Map();
  private config: RateLimitConfig;

  constructor(config: RateLimitConfig) {
    this.config = config;
  }

  async consume(key: string, tokens: number = 1): Promise<boolean> {
    const bucket = this.getBucket(key);
    this.refill(bucket);

    if (bucket.tokens >= tokens) {
      bucket.tokens -= tokens;
      return true;
    }

    return false;
  }

  async getRemaining(key: string): Promise<number> {
    const bucket = this.getBucket(key);
    this.refill(bucket);
    return Math.floor(bucket.tokens);
  }

  async getResetTime(key: string): Promise<number> {
    const bucket = this.getBucket(key);
    const tokensNeeded = 1 - bucket.tokens;
    const intervalsNeeded = Math.ceil(
      tokensNeeded / this.config.tokensPerInterval,
    );
    return bucket.lastRefill + intervalsNeeded * this.config.interval;
  }

  private getBucket(key: string): TokenBucket {
    let bucket = this.buckets.get(key);
    if (!bucket) {
      bucket = {
        tokens: this.config.maxTokens,
        lastRefill: Date.now(),
      };
      this.buckets.set(key, bucket);
    }
    return bucket;
  }

  private refill(bucket: TokenBucket): void {
    const now = Date.now();
    const elapsed = now - bucket.lastRefill;
    const intervalsElapsed = Math.floor(elapsed / this.config.interval);

    if (intervalsElapsed > 0) {
      bucket.tokens = Math.min(
        this.config.maxTokens,
        bucket.tokens + intervalsElapsed * this.config.tokensPerInterval,
      );
      bucket.lastRefill = now;
    }
  }
}
```

### Rate Limiting Middleware

```typescript
// src/ratelimit/middleware.ts
import { Request, Response, NextFunction } from "express";
import { RateLimiter } from "./token-bucket.js";

// Different limits for different operations
const toolRateLimiter = new RateLimiter({
  tokensPerInterval: 10,
  interval: 60000, // 1 minute
  maxTokens: 100, // Allow bursts up to 100
});

const resourceRateLimiter = new RateLimiter({
  tokensPerInterval: 50,
  interval: 60000,
  maxTokens: 200,
});

export function createRateLimitMiddleware(type: "tool" | "resource") {
  const limiter = type === "tool" ? toolRateLimiter : resourceRateLimiter;

  return async (req: Request, res: Response, next: NextFunction) => {
    // Use API key or IP as the rate limit key
    const key = req.apiKey?.name || req.ip || "anonymous";

    const allowed = await limiter.consume(key);

    // Add rate limit headers
    res.setHeader("X-RateLimit-Remaining", await limiter.getRemaining(key));
    res.setHeader("X-RateLimit-Reset", await limiter.getResetTime(key));

    if (!allowed) {
      return res.status(429).json({
        error: "rate_limit_exceeded",
        message: "Too many requests, please try again later",
        retryAfter: Math.ceil(
          ((await limiter.getResetTime(key)) - Date.now()) / 1000,
        ),
      });
    }

    next();
  };
}
```

### Redis-Based Distributed Rate Limiting

```typescript
// src/ratelimit/redis.ts
import Redis from "ioredis";

export class RedisRateLimiter {
  private redis: Redis;

  constructor(redisUrl: string) {
    this.redis = new Redis(redisUrl);
  }

  async consume(
    key: string,
    limit: number,
    windowSeconds: number,
  ): Promise<{ allowed: boolean; remaining: number; resetAt: number }> {
    const now = Date.now();
    const windowKey = `ratelimit:${key}:${Math.floor(now / (windowSeconds * 1000))}`;

    // Use Lua script for atomic increment
    const script = `
      local current = redis.call('INCR', KEYS[1])
      if current == 1 then
        redis.call('EXPIRE', KEYS[1], ARGV[1])
      end
      return current
    `;

    const count = (await this.redis.eval(
      script,
      1,
      windowKey,
      windowSeconds,
    )) as number;

    const allowed = count <= limit;
    const remaining = Math.max(0, limit - count);
    const resetAt =
      (Math.floor(now / (windowSeconds * 1000)) + 1) * windowSeconds * 1000;

    return { allowed, remaining, resetAt };
  }

  async close(): Promise<void> {
    await this.redis.quit();
  }
}
```

---

## Input Sanitization and Security

### Input Validation Utilities

```typescript
// src/security/validation.ts
import { z } from "zod";

// Common validation schemas
export const SafeStringSchema = z
  .string()
  .max(10000)
  .refine((s) => !s.includes("\0"), "Null bytes not allowed");

export const SafePathSchema = z
  .string()
  .max(1000)
  .refine((s) => !s.includes(".."), "Path traversal not allowed")
  .refine((s) => !s.includes("\0"), "Null bytes not allowed")
  .refine((s) => !/[<>:"|?*]/.test(s), "Invalid path characters");

export const SafeSqlIdentifierSchema = z
  .string()
  .max(128)
  .regex(/^[a-zA-Z_][a-zA-Z0-9_]*$/, "Invalid SQL identifier");

export const SafeUrlSchema = z
  .string()
  .url()
  .refine(
    (url) => {
      const parsed = new URL(url);
      return ["https:", "http:"].includes(parsed.protocol);
    },
    { message: "Only HTTP(S) URLs allowed" },
  );

// Sanitization functions
export function sanitizeHtml(input: string): string {
  return input
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#x27;");
}

export function sanitizeSqlLiteral(input: string): string {
  return input.replace(/'/g, "''");
}

export function sanitizeForShell(input: string): string {
  return input.replace(/[;&|`$(){}[\]<>!#]/g, "");
}
```

### SQL Injection Prevention

```typescript
// src/security/sql.ts
const DANGEROUS_SQL_PATTERNS = [
  /;\s*DROP/i,
  /;\s*DELETE/i,
  /;\s*TRUNCATE/i,
  /;\s*UPDATE/i,
  /;\s*INSERT/i,
  /;\s*ALTER/i,
  /;\s*CREATE/i,
  /;\s*GRANT/i,
  /;\s*REVOKE/i,
  /UNION\s+SELECT/i,
  /INTO\s+OUTFILE/i,
  /INTO\s+DUMPFILE/i,
  /LOAD_FILE/i,
  /--\s/,
  /\/\*.*\*\//,
];

export function validateQuery(query: string): {
  valid: boolean;
  reason?: string;
} {
  const trimmed = query.trim().toUpperCase();

  // Only allow SELECT, WITH, EXPLAIN
  if (
    !trimmed.startsWith("SELECT") &&
    !trimmed.startsWith("WITH") &&
    !trimmed.startsWith("EXPLAIN")
  ) {
    return {
      valid: false,
      reason: "Only SELECT, WITH, and EXPLAIN queries allowed",
    };
  }

  // Check for dangerous patterns
  for (const pattern of DANGEROUS_SQL_PATTERNS) {
    if (pattern.test(query)) {
      return { valid: false, reason: `Dangerous pattern detected: ${pattern}` };
    }
  }

  // Check for multiple statements
  if ((query.match(/;/g) || []).length > 1) {
    return { valid: false, reason: "Multiple statements not allowed" };
  }

  return { valid: true };
}
```

### Path Traversal Prevention

```typescript
// src/security/path.ts
import path from "path";

export function isPathSafe(
  requestedPath: string,
  allowedBasePaths: string[],
): boolean {
  // Resolve the path to eliminate .. and .
  const resolvedPath = path.resolve(requestedPath);

  // Check if the resolved path is within any allowed base path
  return allowedBasePaths.some((basePath) => {
    const resolvedBase = path.resolve(basePath);
    return (
      resolvedPath.startsWith(resolvedBase + path.sep) ||
      resolvedPath === resolvedBase
    );
  });
}

export function sanitizePath(inputPath: string): string {
  return inputPath
    .replace(/\.\./g, "") // Remove path traversal
    .replace(/\0/g, "") // Remove null bytes
    .replace(/[<>:"|?*]/g, "") // Remove invalid characters
    .replace(/\/+/g, "/"); // Normalize slashes
}
```

### Command Injection Prevention

```typescript
// src/security/command.ts
import { spawn } from "child_process";

// NEVER use shell: true with user input
// ALWAYS use spawn with argument array

export async function safeExec(
  command: string,
  args: string[],
  options: { cwd?: string; timeout?: number } = {},
): Promise<{ stdout: string; stderr: string; exitCode: number }> {
  return new Promise((resolve, reject) => {
    // Validate command is in allowlist
    const ALLOWED_COMMANDS = ["git", "ls", "cat", "head", "tail"];
    if (!ALLOWED_COMMANDS.includes(command)) {
      return reject(new Error(`Command not allowed: ${command}`));
    }

    // Validate arguments don't contain shell metacharacters
    for (const arg of args) {
      if (/[;&|`$(){}[\]<>!#]/.test(arg)) {
        return reject(new Error(`Invalid characters in argument: ${arg}`));
      }
    }

    const proc = spawn(command, args, {
      cwd: options.cwd,
      timeout: options.timeout || 30000,
      shell: false, // CRITICAL: Never use shell
    });

    let stdout = "";
    let stderr = "";

    proc.stdout.on("data", (data) => (stdout += data));
    proc.stderr.on("data", (data) => (stderr += data));

    proc.on("close", (exitCode) => {
      resolve({ stdout, stderr, exitCode: exitCode || 0 });
    });

    proc.on("error", reject);
  });
}
```

---

## Error Handling Patterns

### Structured Error Types

```typescript
// src/errors/types.ts
export enum MCPErrorCode {
  // Standard JSON-RPC errors
  PARSE_ERROR = -32700,
  INVALID_REQUEST = -32600,
  METHOD_NOT_FOUND = -32601,
  INVALID_PARAMS = -32602,
  INTERNAL_ERROR = -32603,

  // MCP-specific errors (-32000 to -32099)
  TOOL_NOT_FOUND = -32001,
  RESOURCE_NOT_FOUND = -32002,
  PROMPT_NOT_FOUND = -32003,
  UNAUTHORIZED = -32004,
  RATE_LIMITED = -32005,
  VALIDATION_ERROR = -32006,
  TIMEOUT = -32007,
  DEPENDENCY_ERROR = -32008,
}

export class MCPError extends Error {
  constructor(
    public code: MCPErrorCode,
    message: string,
    public data?: unknown,
  ) {
    super(message);
    this.name = "MCPError";
  }

  toJSON() {
    return {
      code: this.code,
      message: this.message,
      data: this.data,
    };
  }
}

// Specific error classes
export class ToolNotFoundError extends MCPError {
  constructor(toolName: string) {
    super(MCPErrorCode.TOOL_NOT_FOUND, `Tool not found: ${toolName}`, {
      toolName,
    });
  }
}

export class ValidationError extends MCPError {
  constructor(errors: unknown[]) {
    super(MCPErrorCode.VALIDATION_ERROR, "Validation failed", { errors });
  }
}

export class RateLimitError extends MCPError {
  constructor(retryAfter: number) {
    super(MCPErrorCode.RATE_LIMITED, "Rate limit exceeded", { retryAfter });
  }
}

export class TimeoutError extends MCPError {
  constructor(operation: string, timeoutMs: number) {
    super(MCPErrorCode.TIMEOUT, `Operation timed out: ${operation}`, {
      operation,
      timeoutMs,
    });
  }
}
```

### Error Handler

```typescript
// src/errors/handler.ts
import { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import { MCPError, MCPErrorCode } from "./types.js";
import { ZodError } from "zod";

export function handleToolError(error: unknown): CallToolResult {
  // Log error for debugging (to stderr to not interfere with MCP protocol)
  console.error("[Tool Error]", error);

  // Handle known error types
  if (error instanceof MCPError) {
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(
            {
              error: error.name,
              code: error.code,
              message: error.message,
              data: error.data,
            },
            null,
            2,
          ),
        },
      ],
      isError: true,
    };
  }

  if (error instanceof ZodError) {
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(
            {
              error: "ValidationError",
              code: MCPErrorCode.VALIDATION_ERROR,
              message: "Input validation failed",
              issues: error.issues.map((issue) => ({
                path: issue.path.join("."),
                message: issue.message,
              })),
            },
            null,
            2,
          ),
        },
      ],
      isError: true,
    };
  }

  // Handle standard errors - don't expose internal details
  if (error instanceof Error) {
    if (error.name === "AbortError" || error.message.includes("timeout")) {
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(
              {
                error: "TimeoutError",
                code: MCPErrorCode.TIMEOUT,
                message: "Operation timed out",
              },
              null,
              2,
            ),
          },
        ],
        isError: true,
      };
    }
  }

  // Generic error
  return {
    content: [
      {
        type: "text",
        text: JSON.stringify(
          {
            error: "InternalError",
            code: MCPErrorCode.INTERNAL_ERROR,
            message: "An internal error occurred",
          },
          null,
          2,
        ),
      },
    ],
    isError: true,
  };
}
```

### Retry Logic

```typescript
// src/errors/retry.ts
import { MCPErrorCode } from "./types.js";

interface RetryConfig {
  maxAttempts: number;
  initialDelayMs: number;
  maxDelayMs: number;
  backoffMultiplier: number;
  retryableErrors: MCPErrorCode[];
}

const defaultRetryConfig: RetryConfig = {
  maxAttempts: 3,
  initialDelayMs: 1000,
  maxDelayMs: 30000,
  backoffMultiplier: 2,
  retryableErrors: [
    MCPErrorCode.TIMEOUT,
    MCPErrorCode.RATE_LIMITED,
    MCPErrorCode.DEPENDENCY_ERROR,
  ],
};

export async function withRetry<T>(
  operation: () => Promise<T>,
  config: Partial<RetryConfig> = {},
): Promise<T> {
  const cfg = { ...defaultRetryConfig, ...config };
  let lastError: Error | undefined;
  let delay = cfg.initialDelayMs;

  for (let attempt = 1; attempt <= cfg.maxAttempts; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error as Error;

      // Check if error is retryable
      if (error instanceof MCPError) {
        if (!cfg.retryableErrors.includes(error.code)) {
          throw error;
        }

        // Special handling for rate limit
        if (
          error.code === MCPErrorCode.RATE_LIMITED &&
          (error.data as any)?.retryAfter
        ) {
          delay = (error.data as any).retryAfter * 1000;
        }
      }

      // Last attempt - don't wait
      if (attempt === cfg.maxAttempts) {
        break;
      }

      console.error(
        `Attempt ${attempt}/${cfg.maxAttempts} failed, retrying in ${delay}ms`,
      );

      // Wait before retry
      await new Promise((resolve) => setTimeout(resolve, delay));

      // Increase delay for next attempt
      delay = Math.min(delay * cfg.backoffMultiplier, cfg.maxDelayMs);
    }
  }

  throw lastError;
}
```

---

## Testing MCP Servers

### Unit Tests (Vitest)

```typescript
// tests/tools.test.ts
import { describe, it, expect, beforeEach } from "vitest";
import { handleToolCall, tools } from "../src/tools/index.js";

describe("MCP Tools", () => {
  describe("Tool Registry", () => {
    it("should export all required tools", () => {
      const toolNames = tools.map((t) => t.name);

      expect(toolNames).toContain("database_query");
      expect(toolNames).toContain("file_search");
      expect(toolNames).toContain("api_request");
    });

    it("should have valid JSON Schema for each tool", () => {
      for (const tool of tools) {
        expect(tool.inputSchema).toBeDefined();
        expect(tool.inputSchema.type).toBe("object");
        expect(tool.inputSchema.properties).toBeDefined();
      }
    });
  });

  describe("database_query", () => {
    it("should execute valid SELECT query", async () => {
      const result = await handleToolCall("database_query", {
        query: "SELECT id, name FROM users LIMIT 10",
        database: "users",
        limit: 10,
      });

      expect(result.isError).toBeFalsy();
      const content = JSON.parse(result.content[0].text);
      expect(content.status).toBe("success");
    });

    it("should reject DELETE queries", async () => {
      const result = await handleToolCall("database_query", {
        query: "DELETE FROM users WHERE id = 1",
        database: "users",
      });

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Only SELECT queries");
    });

    it("should reject DROP queries", async () => {
      const result = await handleToolCall("database_query", {
        query: "DROP TABLE users",
        database: "users",
      });

      expect(result.isError).toBe(true);
    });
  });

  describe("file_search", () => {
    it("should prevent path traversal in pattern", async () => {
      const result = await handleToolCall("file_search", {
        pattern: "../../../etc/passwd",
      });

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Path traversal");
    });
  });

  describe("Error Handling", () => {
    it("should return error for unknown tool", async () => {
      const result = await handleToolCall("nonexistent_tool", {});

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Unknown tool");
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
  let cleanup: () => Promise<void>;

  beforeAll(async () => {
    const server = createServer();
    const [serverTransport, clientTransport] =
      InMemoryTransport.createLinkedPair();

    client = new Client(
      { name: "test-client", version: "1.0.0" },
      { capabilities: {} },
    );

    await Promise.all([
      server.connect(serverTransport),
      client.connect(clientTransport),
    ]);

    cleanup = async () => {
      await client.close();
      await server.close();
    };
  });

  afterAll(async () => {
    await cleanup();
  });

  describe("Tool Operations", () => {
    it("should list all available tools", async () => {
      const result = await client.listTools();

      expect(result.tools).toBeDefined();
      expect(result.tools.length).toBeGreaterThan(0);

      for (const tool of result.tools) {
        expect(tool.name).toBeDefined();
        expect(tool.description).toBeDefined();
        expect(tool.inputSchema).toBeDefined();
      }
    });

    it("should execute tool and return result", async () => {
      const result = await client.callTool({
        name: "database_query",
        arguments: {
          query: "SELECT * FROM users LIMIT 5",
          database: "users",
        },
      });

      expect(result.isError).toBeFalsy();
      expect(result.content).toBeDefined();
    });
  });

  describe("Resource Operations", () => {
    it("should list all available resources", async () => {
      const result = await client.listResources();
      expect(result.resources).toBeDefined();
    });

    it("should read resource by URI", async () => {
      const result = await client.readResource({
        uri: "config://app/settings",
      });

      expect(result.contents).toBeDefined();
      expect(result.contents.length).toBeGreaterThan(0);
    });
  });

  describe("Prompt Operations", () => {
    it("should list all available prompts", async () => {
      const result = await client.listPrompts();
      expect(result.prompts).toBeDefined();
    });

    it("should get prompt with arguments", async () => {
      const result = await client.getPrompt({
        name: "code_review",
        arguments: {
          code: "function hello() { return 'world'; }",
          language: "javascript",
        },
      });

      expect(result.messages).toBeDefined();
      expect(result.messages.length).toBeGreaterThan(0);
    });
  });
});
```

### Mock Client

```typescript
// tests/mocks/client.ts
import { EventEmitter } from "events";

export interface MockToolCallResult {
  content: Array<{ type: string; text: string }>;
  isError?: boolean;
}

export class MockMCPClient extends EventEmitter {
  private toolResponses: Map<string, MockToolCallResult> = new Map();
  private resourceResponses: Map<string, unknown> = new Map();

  mockToolResponse(toolName: string, response: MockToolCallResult): void {
    this.toolResponses.set(toolName, response);
  }

  mockResourceResponse(uri: string, response: unknown): void {
    this.resourceResponses.set(uri, response);
  }

  async callTool(params: {
    name: string;
    arguments: unknown;
  }): Promise<MockToolCallResult> {
    this.emit("tool:call", params);

    const mockResponse = this.toolResponses.get(params.name);
    if (mockResponse) {
      return mockResponse;
    }

    return {
      content: [{ type: "text", text: `Mock response for ${params.name}` }],
    };
  }

  async readResource(params: { uri: string }): Promise<unknown> {
    this.emit("resource:read", params);

    return (
      this.resourceResponses.get(params.uri) || {
        contents: [{ uri: params.uri, text: "Mock content" }],
      }
    );
  }

  async listTools(): Promise<{
    tools: Array<{ name: string; description: string }>;
  }> {
    return {
      tools: [
        { name: "database_query", description: "Query database" },
        { name: "file_search", description: "Search files" },
      ],
    };
  }
}
```

---

## Debugging and Monitoring

### 1. MCP Inspector

The official MCP Inspector tool for debugging:

```bash
# Install MCP Inspector
npm install -g @modelcontextprotocol/inspector

# Run inspector with your server
npx @modelcontextprotocol/inspector node ./dist/index.js

# Or with Python server
npx @modelcontextprotocol/inspector python -m my_mcp_server
```

### 2. Structured Logging

```typescript
// src/utils/logger.ts
import pino from "pino";

const logger = pino({
  level: process.env.LOG_LEVEL || "info",
  formatters: {
    level: (label) => ({ level: label }),
    bindings: (bindings) => ({
      pid: bindings.pid,
      hostname: bindings.hostname,
      service: "mcp-server",
    }),
  },
  timestamp: pino.stdTimeFunctions.isoTime,
  redact: {
    paths: [
      "*.password",
      "*.secret",
      "*.token",
      "*.apiKey",
      "headers.authorization",
    ],
    censor: "[REDACTED]",
  },
});

export function logRequest(
  method: string,
  params: unknown,
  correlationId: string,
): void {
  logger.info({
    event: "mcp_request",
    correlationId,
    method,
    params,
  });
}

export function logResponse(
  method: string,
  correlationId: string,
  durationMs: number,
): void {
  logger.info({
    event: "mcp_response",
    correlationId,
    method,
    durationMs,
    success: true,
  });
}

export function logError(
  method: string,
  error: unknown,
  correlationId: string,
): void {
  logger.error({
    event: "mcp_error",
    correlationId,
    method,
    error:
      error instanceof Error
        ? {
            name: error.name,
            message: error.message,
            stack: error.stack,
          }
        : error,
  });
}

export default logger;
```

### 3. Metrics Collection

```typescript
// src/utils/metrics.ts
import { Registry, Counter, Histogram, Gauge } from "prom-client";

const register = new Registry();

export const toolCallsTotal = new Counter({
  name: "mcp_tool_calls_total",
  help: "Total number of tool calls",
  labelNames: ["tool_name", "status"],
  registers: [register],
});

export const toolCallDuration = new Histogram({
  name: "mcp_tool_call_duration_seconds",
  help: "Duration of tool calls in seconds",
  labelNames: ["tool_name"],
  buckets: [0.01, 0.05, 0.1, 0.5, 1, 2, 5, 10],
  registers: [register],
});

export const activeConnections = new Gauge({
  name: "mcp_active_connections",
  help: "Number of active MCP connections",
  registers: [register],
});

export async function metricsHandler(): Promise<string> {
  return register.metrics();
}

export function instrumentToolCall<T>(
  toolName: string,
  operation: () => Promise<T>,
): Promise<T> {
  const timer = toolCallDuration.startTimer({ tool_name: toolName });

  return operation()
    .then((result) => {
      toolCallsTotal.inc({ tool_name: toolName, status: "success" });
      return result;
    })
    .catch((error) => {
      toolCallsTotal.inc({ tool_name: toolName, status: "error" });
      throw error;
    })
    .finally(() => {
      timer();
    });
}
```

### 4. Health Check Endpoint

```typescript
// src/health.ts
interface HealthStatus {
  status: "healthy" | "unhealthy" | "degraded";
  version: string;
  uptime: number;
  checks: Array<{
    name: string;
    status: "healthy" | "unhealthy" | "degraded";
    latencyMs?: number;
    message?: string;
  }>;
  timestamp: string;
}

export async function checkHealth(): Promise<HealthStatus> {
  const checks = await Promise.all([
    checkDatabaseConnection(),
    checkDiskSpace(),
    checkMemory(),
  ]);

  const unhealthyCount = checks.filter((c) => c.status === "unhealthy").length;
  const degradedCount = checks.filter((c) => c.status === "degraded").length;

  let status: "healthy" | "unhealthy" | "degraded";
  if (unhealthyCount > 0) {
    status = "unhealthy";
  } else if (degradedCount > 0) {
    status = "degraded";
  } else {
    status = "healthy";
  }

  return {
    status,
    version: process.env.npm_package_version || "1.0.0",
    uptime: process.uptime(),
    checks,
    timestamp: new Date().toISOString(),
  };
}
```

### 5. Debug Mode

```typescript
// src/debug.ts
const DEBUG_ENABLED = process.env.MCP_DEBUG === "1";
const TRACE_ENABLED = process.env.MCP_TRACE === "1";

export function debugLog(
  category: string,
  message: string,
  data?: unknown,
): void {
  if (!DEBUG_ENABLED) return;

  console.error(
    JSON.stringify({
      timestamp: new Date().toISOString(),
      level: "debug",
      category,
      message,
      data,
    }),
  );
}

export function traceLog(operation: string, args: unknown): void {
  if (!TRACE_ENABLED) return;

  const stack = new Error().stack?.split("\n").slice(2, 5).join("\n");

  console.error(
    JSON.stringify({
      timestamp: new Date().toISOString(),
      level: "trace",
      operation,
      args,
      stack,
    }),
  );
}
```

### 6. Common Debug Commands

```bash
# Enable debug logging
export MCP_DEBUG=1
export MCP_TRACE=1

# Test server manually with JSON-RPC
echo '{"jsonrpc":"2.0","method":"initialize","params":{"capabilities":{}},"id":1}' | node dist/index.js

# Monitor logs in real-time
journalctl -u mcp-server -f --output=json | jq .

# Test specific tool
echo '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"database_query","arguments":{"query":"SELECT 1","database":"users"}},"id":2}' | node dist/index.js

# Validate JSON-RPC messages
npx @modelcontextprotocol/inspector --validate

# Profile memory usage
node --inspect dist/index.js
# Then open chrome://inspect
```

---

## Claude Code Integration

### 1. Configuration File

```json
// ~/.claude/mcp.json
{
  "mcpServers": {
    "my-custom-server": {
      "command": "node",
      "args": ["/home/user/mcp-servers/my-server/dist/index.js"],
      "env": {
        "NODE_ENV": "production",
        "LOG_LEVEL": "info",
        "DATABASE_URL": "${DATABASE_URL}"
      },
      "timeout": 30000
    },
    "python-server": {
      "command": "python",
      "args": ["-m", "my_mcp_server"],
      "env": {
        "PYTHONPATH": "/home/user/mcp-servers/python-server/src"
      }
    },
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
    }
  }
}
```

### 2. Environment Variable Substitution

Claude Code supports `${VAR}` syntax for environment variables in the config:

```json
{
  "mcpServers": {
    "secure-server": {
      "command": "node",
      "args": ["./server.js"],
      "env": {
        "API_KEY": "${MY_API_KEY}",
        "DATABASE_URL": "${DATABASE_URL}",
        "SECRET": "${SECRET_KEY}"
      }
    }
  }
}
```

### 3. Per-Project Configuration

Create `.claude/mcp.json` in your project root for project-specific servers:

```json
// /path/to/project/.claude/mcp.json
{
  "mcpServers": {
    "project-db": {
      "command": "node",
      "args": ["./tools/mcp-db-server.js"],
      "env": {
        "DB_PATH": "./data/project.db"
      }
    }
  }
}
```

### 4. Verifying MCP Server Connection

```bash
# List configured MCP servers
claude mcp list

# Test specific server
claude mcp test my-custom-server

# View server logs
claude mcp logs my-custom-server

# Restart server
claude mcp restart my-custom-server
```

---

## Common MCP Server Patterns

### 1. Git Operations Server

```typescript
// Git MCP server pattern
const gitTools: Tool[] = [
  {
    name: "git_status",
    description: "Get current git status",
    inputSchema: {
      type: "object",
      properties: {
        path: { type: "string", description: "Repository path" },
      },
    },
  },
  {
    name: "git_diff",
    description: "Get diff of changes",
    inputSchema: {
      type: "object",
      properties: {
        path: { type: "string" },
        staged: { type: "boolean", default: false },
      },
    },
  },
  {
    name: "git_log",
    description: "Get commit history",
    inputSchema: {
      type: "object",
      properties: {
        path: { type: "string" },
        limit: { type: "number", default: 10 },
      },
    },
  },
];
```

### 2. Database Query Server

```typescript
// Database MCP server pattern
const dbTools: Tool[] = [
  {
    name: "db_query",
    description: "Execute read-only SQL query",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string" },
        params: { type: "array", items: { type: "string" } },
      },
      required: ["query"],
    },
  },
  {
    name: "db_schema",
    description: "Get database schema",
    inputSchema: {
      type: "object",
      properties: {
        table: { type: "string" },
      },
    },
  },
];

// Resources for database
const dbResources: Resource[] = [
  {
    uri: "db://schema/tables",
    name: "Database Tables",
    description: "List of all tables",
    mimeType: "application/json",
  },
];
```

### 3. API Gateway Server

```typescript
// API Gateway MCP server pattern
const apiTools: Tool[] = [
  {
    name: "api_call",
    description: "Make API request to configured endpoints",
    inputSchema: {
      type: "object",
      properties: {
        endpoint: {
          type: "string",
          enum: ["users", "orders", "products"],
        },
        method: {
          type: "string",
          enum: ["GET", "POST", "PUT", "DELETE"],
        },
        params: { type: "object" },
        body: { type: "object" },
      },
      required: ["endpoint", "method"],
    },
  },
];
```

---

## Performance Optimization

### 1. Connection Pooling

```typescript
// src/performance/pool.ts
import { Pool } from "generic-pool";

interface Connection {
  id: string;
  createdAt: Date;
  lastUsed: Date;
}

export function createConnectionPool<T>(config: {
  create: () => Promise<T>;
  destroy: (conn: T) => Promise<void>;
  validate?: (conn: T) => Promise<boolean>;
  max: number;
  min: number;
  idleTimeoutMs: number;
}): Pool<T> {
  return Pool.create({
    create: config.create,
    destroy: config.destroy,
    validate: config.validate,
    max: config.max,
    min: config.min,
    idleTimeoutMillis: config.idleTimeoutMs,
    evictionRunIntervalMillis: 60000,
  });
}
```

### 2. Response Caching

```typescript
// src/performance/cache.ts
interface CacheEntry<T> {
  value: T;
  expiresAt: number;
}

export class LRUCache<T> {
  private cache = new Map<string, CacheEntry<T>>();
  private maxSize: number;

  constructor(maxSize: number = 1000) {
    this.maxSize = maxSize;
  }

  get(key: string): T | undefined {
    const entry = this.cache.get(key);

    if (!entry) return undefined;

    if (Date.now() > entry.expiresAt) {
      this.cache.delete(key);
      return undefined;
    }

    // Move to end (most recently used)
    this.cache.delete(key);
    this.cache.set(key, entry);

    return entry.value;
  }

  set(key: string, value: T, ttlMs: number): void {
    // Evict oldest if at capacity
    if (this.cache.size >= this.maxSize) {
      const oldestKey = this.cache.keys().next().value;
      if (oldestKey) this.cache.delete(oldestKey);
    }

    this.cache.set(key, {
      value,
      expiresAt: Date.now() + ttlMs,
    });
  }

  delete(key: string): boolean {
    return this.cache.delete(key);
  }

  clear(): void {
    this.cache.clear();
  }
}
```

### 3. Request Batching

```typescript
// src/performance/batch.ts
export class RequestBatcher<TInput, TOutput> {
  private pending: Array<{
    input: TInput;
    resolve: (result: TOutput) => void;
    reject: (error: Error) => void;
  }> = [];
  private timer: NodeJS.Timeout | null = null;

  constructor(
    private batchHandler: (inputs: TInput[]) => Promise<TOutput[]>,
    private maxBatchSize: number = 100,
    private maxWaitMs: number = 10,
  ) {}

  async add(input: TInput): Promise<TOutput> {
    return new Promise((resolve, reject) => {
      this.pending.push({ input, resolve, reject });

      if (this.pending.length >= this.maxBatchSize) {
        this.flush();
      } else if (!this.timer) {
        this.timer = setTimeout(() => this.flush(), this.maxWaitMs);
      }
    });
  }

  private async flush(): Promise<void> {
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }

    const batch = this.pending.splice(0, this.maxBatchSize);
    if (batch.length === 0) return;

    try {
      const inputs = batch.map((p) => p.input);
      const results = await this.batchHandler(inputs);

      batch.forEach((p, i) => p.resolve(results[i]));
    } catch (error) {
      batch.forEach((p) => p.reject(error as Error));
    }
  }
}
```

### 4. Streaming Responses

```typescript
// src/performance/streaming.ts
import { Readable } from "stream";

export async function* streamResults<T>(
  generator: AsyncGenerator<T>,
  transformFn?: (item: T) => string,
): AsyncGenerator<string> {
  for await (const item of generator) {
    const output = transformFn ? transformFn(item) : JSON.stringify(item);
    yield output + "\n";
  }
}

// Usage in tool handler
export async function streamingToolHandler(args: unknown): Promise<{
  content: Array<{ type: "text"; text: string }>;
}> {
  const results: string[] = [];

  for await (const chunk of streamResults(queryGenerator(args))) {
    results.push(chunk);

    // Yield partial results periodically
    if (results.length % 100 === 0) {
      // Notification of progress (if supported)
    }
  }

  return {
    content: [{ type: "text", text: results.join("") }],
  };
}
```

---

## Deployment

### 1. Docker

```dockerfile
# Dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-alpine
WORKDIR /app
RUN addgroup -g 1001 -S mcp && adduser -S mcp -u 1001 -G mcp
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./
USER mcp
ENV NODE_ENV=production
ENTRYPOINT ["node", "dist/index.js"]
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
WorkingDirectory=/opt/mcp-server
ExecStart=/usr/bin/node /opt/mcp-server/dist/index.js
Restart=on-failure
RestartSec=10

# Security hardening
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
```

### 3. Docker Compose for Development

```yaml
# docker-compose.yml
version: "3.8"
services:
  mcp-server:
    build: .
    volumes:
      - ./src:/app/src:ro
    environment:
      - NODE_ENV=development
      - MCP_DEBUG=1
      - DATABASE_URL=postgres://postgres:postgres@db:5432/mcp
    depends_on:
      - db
      - redis

  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=mcp
    volumes:
      - pgdata:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    volumes:
      - redisdata:/data

volumes:
  pgdata:
  redisdata:
```

---

## Troubleshooting Guide

### Common Issues and Solutions

| Issue                      | Symptoms                     | Solution                                                      |
| -------------------------- | ---------------------------- | ------------------------------------------------------------- |
| Server not starting        | Process exits immediately    | Check logs, verify dependencies, run with `MCP_DEBUG=1`       |
| Connection refused         | Client can't connect         | Verify port, check firewall, ensure server is listening       |
| Tool not found             | "Unknown tool" error         | Check tool registration, verify tool name spelling            |
| Authentication failed      | 401 errors                   | Verify API key, check token expiration, validate OAuth config |
| Rate limit exceeded        | 429 errors                   | Implement backoff, check rate limit config                    |
| Timeout errors             | Operations taking too long   | Increase timeout, optimize queries, add caching               |
| Memory issues              | OOM errors, slow performance | Add connection pooling, implement pagination                  |
| JSON-RPC parse errors      | Invalid message format       | Validate JSON structure, check encoding                       |
| Resource not found         | 404 on resource read         | Verify URI format, check resource registration                |
| Permission denied          | 403 errors                   | Check scopes, verify authorization policy                     |
| Database connection errors | Can't connect to DB          | Check connection string, verify network access                |
| SSL/TLS errors             | Certificate issues           | Verify cert paths, check expiration                           |
| Prompt template errors     | Missing arguments            | Validate required args, check argument types                  |
| Transport connection lost  | Frequent disconnects         | Implement reconnection logic, check network stability         |
| High latency               | Slow responses               | Enable caching, optimize handlers, add indexes                |

### Debug Checklist

```bash
# 1. Enable verbose logging
export MCP_DEBUG=1
export MCP_TRACE=1
export LOG_LEVEL=debug

# 2. Test server manually
echo '{"jsonrpc":"2.0","method":"initialize","id":1,"params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | node dist/index.js

# 3. Check process status
ps aux | grep mcp
lsof -i :3000

# 4. View logs
journalctl -u mcp-server -f
tail -f /var/log/mcp-server.log

# 5. Test with MCP Inspector
npx @modelcontextprotocol/inspector node dist/index.js

# 6. Check network connectivity
curl -v http://localhost:3000/health
nc -zv localhost 3000

# 7. Validate configuration
cat ~/.claude/mcp.json | jq .

# 8. Check environment variables
env | grep -E '(MCP|NODE|DATABASE|API)'

# 9. Memory and CPU usage
top -p $(pgrep -f mcp-server)

# 10. Database connectivity
psql $DATABASE_URL -c "SELECT 1"
```

### Error Code Reference

| Error Code | Name               | Description                  | Recovery Action              |
| ---------- | ------------------ | ---------------------------- | ---------------------------- |
| -32700     | Parse Error        | Invalid JSON                 | Check message format         |
| -32600     | Invalid Request    | Missing required fields      | Validate request structure   |
| -32601     | Method Not Found   | Unknown method               | Check method name spelling   |
| -32602     | Invalid Params     | Invalid arguments            | Validate against schema      |
| -32603     | Internal Error     | Server-side error            | Check server logs            |
| -32001     | Tool Not Found     | Unknown tool name            | Verify tool registration     |
| -32002     | Resource Not Found | URI not registered           | Check resource URI format    |
| -32003     | Prompt Not Found   | Unknown prompt               | Verify prompt registration   |
| -32004     | Unauthorized       | Auth failed                  | Check credentials            |
| -32005     | Rate Limited       | Too many requests            | Implement backoff            |
| -32006     | Validation Error   | Input validation failed      | Check input against schema   |
| -32007     | Timeout            | Operation timed out          | Increase timeout or optimize |
| -32008     | Dependency Error   | External service unavailable | Retry or failover            |

---

## Production Checklist

### Pre-Deployment

- [ ] All tests passing (unit, integration, e2e)
- [ ] Security audit completed
- [ ] Input validation on all tools
- [ ] Rate limiting configured
- [ ] Authentication implemented
- [ ] Authorization (scopes) configured
- [ ] Error handling for all edge cases
- [ ] Logging configured (structured, redacted)
- [ ] Metrics endpoints working
- [ ] Health check endpoint implemented
- [ ] Documentation complete
- [ ] Environment variables documented

### Security

- [ ] No hardcoded secrets
- [ ] HTTPS/TLS configured
- [ ] API keys properly stored
- [ ] SQL injection prevention verified
- [ ] Path traversal prevention verified
- [ ] Command injection prevention verified
- [ ] Rate limiting enabled
- [ ] Input size limits configured
- [ ] Timeout limits configured
- [ ] Principle of least privilege applied

### Operations

- [ ] Container/VM properly sized
- [ ] Auto-restart configured
- [ ] Log rotation configured
- [ ] Monitoring dashboards set up
- [ ] Alerting configured
- [ ] Backup procedures documented
- [ ] Rollback procedure documented
- [ ] Disaster recovery plan
- [ ] On-call rotation established

### Performance

- [ ] Connection pooling enabled
- [ ] Caching configured
- [ ] Query optimization complete
- [ ] Load testing completed
- [ ] Response time within SLA
- [ ] Memory usage acceptable
- [ ] CPU usage acceptable

---

## Example Invocations

```bash
# Create new MCP server
/agents/integration/mcp-expert create TypeScript MCP server for Jira integration

# Add WebSocket transport
/agents/integration/mcp-expert add WebSocket transport to existing MCP server

# Implement authentication
/agents/integration/mcp-expert implement OAuth2 authentication for MCP server

# Add tool with validation
/agents/integration/mcp-expert add tool for creating GitHub issues with proper validation

# Security audit
/agents/integration/mcp-expert review MCP server security for production deployment

# Write comprehensive tests
/agents/integration/mcp-expert create test suite for MCP tools and resources

# Debug connection issues
/agents/integration/mcp-expert debug MCP server connection problems with Claude Code

# Add prompt templates
/agents/integration/mcp-expert create code review prompt template with language parameter

# Implement rate limiting
/agents/integration/mcp-expert add Redis-based rate limiting to MCP server

# Performance optimization
/agents/integration/mcp-expert optimize MCP server for high throughput
```

---

## Deliverables

When invoked, this agent produces:

1. **MCP Server Implementation** - Complete server code (TypeScript/Python)
2. **Tool Definitions** - JSON Schema validated tools with handlers
3. **Resource Providers** - URI-based resource handlers with subscriptions
4. **Prompt Templates** - Reusable prompt definitions with argument validation
5. **Transport Configuration** - stdio/SSE/WebSocket setup
6. **Authentication Module** - API key, OAuth, JWT, or mTLS auth
7. **Rate Limiting** - Token bucket or Redis-based rate limiting
8. **Security Configuration** - Input validation, sanitization, authorization
9. **Test Suite** - Unit and integration tests with mocks
10. **Deployment Config** - Docker, systemd, or Claude Code config
11. **Monitoring Setup** - Metrics, logging, health checks, and debugging tools
12. **Documentation** - API docs, troubleshooting guide, runbooks

---

## References

- [MCP Specification](https://spec.modelcontextprotocol.io/)
- [MCP TypeScript SDK](https://github.com/modelcontextprotocol/typescript-sdk)
- [MCP Python SDK](https://github.com/modelcontextprotocol/python-sdk)
- [Official MCP Servers](https://github.com/modelcontextprotocol/servers)
- [Claude Code MCP Integration](https://docs.anthropic.com/claude-code/mcp)
- [JSON-RPC 2.0 Specification](https://www.jsonrpc.org/specification)
- [MCP Inspector](https://github.com/modelcontextprotocol/inspector)

---

Ahmed Adel Bakr Alderai
