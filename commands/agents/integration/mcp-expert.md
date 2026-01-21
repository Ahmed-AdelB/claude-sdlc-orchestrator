---
name: MCP Expert Agent
description: Comprehensive Model Context Protocol specialist for server development, tool definitions, transport layers, security, testing, and Claude Code integration
version: 2.0.0
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
| Transport Layers    | stdio, Server-Sent Events (SSE), WebSocket            |
| Authentication      | API keys, OAuth, JWT, mTLS, scope-based authorization |
| Security            | Input validation, rate limiting, sandboxing           |
| Testing             | Unit tests, integration tests, mock clients           |
| Deployment          | Docker, systemd, cloud functions, Claude Code config  |
| Debugging           | MCP Inspector, logging, tracing, error diagnostics    |

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
   |  <------- notifications/resources/updated ----    |
   |                                                   |
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
from fastapi import FastAPI, Request, Response
from fastapi.responses import StreamingResponse
from sse_starlette.sse import EventSourceResponse
from mcp.server import Server
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
    // Note: This requires implementing a custom transport adapter
    // that bridges WebSocket to the MCP SDK transport interface
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
import jwt from "jsonwebtoken";

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

  filterTools(tools: Tool[], userScopes: Scope[]): Tool[] {
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
    const cert = req.socket.getPeerCertificate();

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
    req.clientCert = {
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

## Error Handling Patterns

### 1. Structured Error Types

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

### 2. Error Handler Middleware

```typescript
// src/errors/handler.ts
import { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import { MCPError, MCPErrorCode } from "./types.js";
import { ZodError } from "zod";

export function handleToolError(error: unknown): CallToolResult {
  // Log error for debugging
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

  // Handle standard errors
  if (error instanceof Error) {
    // Check for specific error types
    if (error.name === "AbortError" || error.message.includes("timeout")) {
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(
              {
                error: "TimeoutError",
                code: MCPErrorCode.TIMEOUT,
                message: error.message,
              },
              null,
              2,
            ),
          },
        ],
        isError: true,
      };
    }

    // Generic error - don't expose internal details
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

  // Unknown error type
  return {
    content: [
      {
        type: "text",
        text: JSON.stringify(
          {
            error: "UnknownError",
            code: MCPErrorCode.INTERNAL_ERROR,
            message: "An unknown error occurred",
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

### 3. Retry Logic

```typescript
// src/errors/retry.ts
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
          error.data?.retryAfter
        ) {
          delay = error.data.retryAfter * 1000;
        }
      }

      // Last attempt - don't wait
      if (attempt === cfg.maxAttempts) {
        break;
      }

      console.warn(
        `Attempt ${attempt}/${cfg.maxAttempts} failed, retrying in ${delay}ms:`,
        error,
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

### 1. Unit Tests (Vitest)

```typescript
// tests/tools.test.ts
import { describe, it, expect, vi, beforeEach } from "vitest";
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

    it("should validate database name", async () => {
      const result = await handleToolCall("database_query", {
        query: "SELECT * FROM users",
        database: "malicious_db",
      });

      expect(result.isError).toBe(true);
    });

    it("should enforce limit constraints", async () => {
      const result = await handleToolCall("database_query", {
        query: "SELECT * FROM users",
        database: "users",
        limit: 10000, // Exceeds max of 1000
      });

      expect(result.isError).toBe(true);
    });
  });

  describe("file_search", () => {
    it("should search for files with valid pattern", async () => {
      const result = await handleToolCall("file_search", {
        pattern: "**/*.ts",
        directory: "src",
        maxResults: 10,
      });

      expect(result.isError).toBeFalsy();
    });

    it("should prevent path traversal in pattern", async () => {
      const result = await handleToolCall("file_search", {
        pattern: "../../../etc/passwd",
      });

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Path traversal");
    });

    it("should prevent path traversal in directory", async () => {
      const result = await handleToolCall("file_search", {
        pattern: "*.txt",
        directory: "../../../",
      });

      expect(result.isError).toBe(true);
    });
  });

  describe("api_request", () => {
    it("should make GET request to allowed host", async () => {
      const result = await handleToolCall("api_request", {
        method: "GET",
        url: "https://api.example.com/data",
      });

      // Note: This test assumes api.example.com is in allowlist
      expect(result.content).toBeDefined();
    });

    it("should reject disallowed hosts", async () => {
      const result = await handleToolCall("api_request", {
        url: "https://malicious-site.com/steal",
      });

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("not in allowlist");
    });

    it("should validate HTTP method", async () => {
      const result = await handleToolCall("api_request", {
        method: "INVALID",
        url: "https://api.example.com/data",
      });

      expect(result.isError).toBe(true);
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

### 2. Integration Tests

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

      // Verify tool structure
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
      expect(result.content.length).toBeGreaterThan(0);
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

  describe("Error Scenarios", () => {
    it("should handle unknown tool gracefully", async () => {
      const result = await client.callTool({
        name: "nonexistent_tool",
        arguments: {},
      });

      expect(result.isError).toBe(true);
    });

    it("should handle invalid arguments", async () => {
      const result = await client.callTool({
        name: "database_query",
        arguments: {
          // Missing required 'query' field
          database: "users",
        },
      });

      expect(result.isError).toBe(true);
    });
  });
});
```

### 3. Mock Client for Testing

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

  // Configure mock responses
  mockToolResponse(toolName: string, response: MockToolCallResult): void {
    this.toolResponses.set(toolName, response);
  }

  mockResourceResponse(uri: string, response: unknown): void {
    this.resourceResponses.set(uri, response);
  }

  // MCP Client interface
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

// Request logging middleware
export function logRequest(
  method: string,
  params: unknown,
  correlationId: string,
): void {
  logger.info({
    event: "mcp_request",
    correlationId,
    method,
    params: redactSensitive(params),
  });
}

export function logResponse(
  method: string,
  result: unknown,
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

function redactSensitive(obj: unknown): unknown {
  if (typeof obj !== "object" || obj === null) {
    return obj;
  }

  const sensitiveKeys = /password|secret|token|key|auth/i;
  const result: Record<string, unknown> = {};

  for (const [key, value] of Object.entries(obj)) {
    if (sensitiveKeys.test(key)) {
      result[key] = "[REDACTED]";
    } else if (typeof value === "object") {
      result[key] = redactSensitive(value);
    } else {
      result[key] = value;
    }
  }

  return result;
}

export default logger;
```

### 3. Metrics Collection

```typescript
// src/utils/metrics.ts
import { Registry, Counter, Histogram, Gauge } from "prom-client";

const register = new Registry();

// Define metrics
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

export const resourceReadsTotal = new Counter({
  name: "mcp_resource_reads_total",
  help: "Total number of resource reads",
  labelNames: ["protocol", "status"],
  registers: [register],
});

export const activeConnections = new Gauge({
  name: "mcp_active_connections",
  help: "Number of active MCP connections",
  registers: [register],
});

export const errorTotal = new Counter({
  name: "mcp_errors_total",
  help: "Total number of errors",
  labelNames: ["error_code", "tool_name"],
  registers: [register],
});

// Metrics endpoint handler
export async function metricsHandler(): Promise<string> {
  return register.metrics();
}

// Instrumentation wrapper
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
interface HealthCheck {
  name: string;
  status: "healthy" | "unhealthy" | "degraded";
  latencyMs?: number;
  message?: string;
}

interface HealthStatus {
  status: "healthy" | "unhealthy" | "degraded";
  version: string;
  uptime: number;
  checks: HealthCheck[];
  timestamp: string;
}

export async function checkHealth(): Promise<HealthStatus> {
  const startTime = process.hrtime.bigint();

  const checks = await Promise.all([
    checkDatabaseConnection(),
    checkExternalAPI(),
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

async function checkDatabaseConnection(): Promise<HealthCheck> {
  const start = Date.now();
  try {
    // Perform database ping
    // await db.query("SELECT 1");
    return {
      name: "database",
      status: "healthy",
      latencyMs: Date.now() - start,
    };
  } catch (error) {
    return {
      name: "database",
      status: "unhealthy",
      message: error instanceof Error ? error.message : "Unknown error",
    };
  }
}

async function checkExternalAPI(): Promise<HealthCheck> {
  const start = Date.now();
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 5000);

    await fetch("https://api.example.com/health", {
      signal: controller.signal,
    });

    clearTimeout(timeoutId);

    return {
      name: "external_api",
      status: "healthy",
      latencyMs: Date.now() - start,
    };
  } catch (error) {
    return {
      name: "external_api",
      status: "degraded",
      message: "API unreachable",
    };
  }
}

async function checkDiskSpace(): Promise<HealthCheck> {
  try {
    const { execSync } = await import("child_process");
    const output = execSync("df -BG / | tail -1 | awk '{print $4}'").toString();
    const freeGB = parseInt(output.replace("G", ""));

    if (freeGB < 1) {
      return { name: "disk", status: "unhealthy", message: "< 1GB free" };
    } else if (freeGB < 5) {
      return { name: "disk", status: "degraded", message: `${freeGB}GB free` };
    }
    return { name: "disk", status: "healthy" };
  } catch {
    return { name: "disk", status: "degraded", message: "Check failed" };
  }
}

async function checkMemory(): Promise<HealthCheck> {
  const used = process.memoryUsage();
  const heapUsedMB = Math.round(used.heapUsed / 1024 / 1024);
  const heapTotalMB = Math.round(used.heapTotal / 1024 / 1024);
  const usagePercent = (heapUsedMB / heapTotalMB) * 100;

  if (usagePercent > 90) {
    return {
      name: "memory",
      status: "unhealthy",
      message: `${usagePercent.toFixed(1)}% used`,
    };
  } else if (usagePercent > 75) {
    return {
      name: "memory",
      status: "degraded",
      message: `${usagePercent.toFixed(1)}% used`,
    };
  }
  return { name: "memory", status: "healthy" };
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

// Debug wrapper for tool handlers
export function debugTool<T extends (...args: any[]) => Promise<any>>(
  toolName: string,
  handler: T,
): T {
  return (async (...args: Parameters<T>): Promise<ReturnType<T>> => {
    const requestId = crypto.randomUUID();
    const start = Date.now();

    debugLog("tool", `[${requestId}] START ${toolName}`, { args });

    try {
      const result = await handler(...args);

      debugLog("tool", `[${requestId}] END ${toolName}`, {
        durationMs: Date.now() - start,
        success: true,
      });

      return result;
    } catch (error) {
      debugLog("tool", `[${requestId}] ERROR ${toolName}`, {
        durationMs: Date.now() - start,
        error: error instanceof Error ? error.message : error,
      });
      throw error;
    }
  }) as T;
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

# Check for memory leaks
node --expose-gc dist/index.js
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
```

---

## Deliverables

When invoked, this agent produces:

1. **MCP Server Implementation** - Complete server code (TypeScript/Python)
2. **Tool Definitions** - JSON Schema validated tools with handlers
3. **Resource Providers** - URI-based resource handlers
4. **Prompt Templates** - Reusable prompt definitions
5. **Transport Configuration** - stdio/SSE/WebSocket setup
6. **Authentication Module** - API key, OAuth, or JWT auth
7. **Test Suite** - Unit and integration tests
8. **Deployment Config** - Docker, systemd, or Claude Code config
9. **Monitoring Setup** - Metrics, logging, and health checks

---

## References

- [MCP Specification](https://spec.modelcontextprotocol.io/)
- [MCP TypeScript SDK](https://github.com/modelcontextprotocol/typescript-sdk)
- [MCP Python SDK](https://github.com/modelcontextprotocol/python-sdk)
- [Official MCP Servers](https://github.com/modelcontextprotocol/servers)
- [Claude Code MCP Integration](https://docs.anthropic.com/claude-code/mcp)
- [JSON-RPC 2.0 Specification](https://www.jsonrpc.org/specification)

---

Ahmed Adel Bakr Alderai
