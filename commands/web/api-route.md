---
name: web:api-route
description: Generate API route handlers with validation, error handling, OpenAPI docs, and integration tests.
version: 1.0.0
tools:
  - Read
  - Write
  - Bash
---

# API Route Generator

Generate API route handlers with validation, error handling, OpenAPI docs, and integration tests for Express, FastAPI, or Next.js App Router.

## Tri-Agent Integration
- Claude: Define endpoint architecture, data contracts, and auth strategy.
- Codex: Implement handlers, schemas, and tests for the chosen framework.
- Gemini: Review for correctness, security gaps, and edge cases.

## Inputs to collect
- Framework: express | fastapi | nextjs-app-router
- HTTP method and path (with path params)
- Auth requirements
- Request schema: path/query/header/body
- Response schema(s) and status codes
- Error cases and status codes
- Side effects (db, external APIs)
- Pagination/filtering/sorting
- Rate limiting/idempotency if relevant

If any are missing, ask concise questions before generating code.

## Workflow
1. Parse endpoint requirements into a structured summary.
2. Generate the route handler for the chosen framework.
3. Add input validation (Zod or Pydantic).
4. Implement error handling (central middleware or per-handler).
5. Add OpenAPI documentation.
6. Generate integration tests.

## Error Handling
- Normalize validation errors with consistent status codes and payload shape.
- Distinguish auth, not-found, and conflict errors from generic 500s.
- Avoid leaking internal error details in responses.
- Add tests for invalid inputs and common failure paths.

## Output checklist
- Handler code with explicit types
- Validation schemas
- Error handling and status codes
- OpenAPI spec snippet
- Integration tests

## Templates and Examples

### Example
`@api-route nextjs-app-router POST /api/users "Create user with validation"`

### Express (TypeScript + Zod)

Route handler (app/router file):

```ts
import type { Request, Response, NextFunction } from "express";
import { Router } from "express";
import { z } from "zod";

const router = Router();

const pathParamsSchema = z.object({
  id: z.string().uuid(),
});

const querySchema = z.object({
  include: z.enum(["basic", "full"]).optional(),
});

const bodySchema = z.object({
  name: z.string().min(1),
  email: z.string().email(),
});

const responseSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  email: z.string().email(),
});

type ResponseBody = z.infer<typeof responseSchema>;

router.post(
  "/users/:id",
  async (req: Request, res: Response<ResponseBody>, next: NextFunction) => {
    try {
      const pathParams = pathParamsSchema.parse(req.params);
      const query = querySchema.parse(req.query);
      const body = bodySchema.parse(req.body);

      const result: ResponseBody = await createUser({
        id: pathParams.id,
        include: query.include,
        ...body,
      });

      res.status(201).json(result);
    } catch (error) {
      next(error);
    }
  }
);

export { router };
```

Error handling middleware:

```ts
import type { Request, Response, NextFunction } from "express";
import { ZodError } from "zod";

export const errorHandler = (
  error: unknown,
  _req: Request,
  res: Response,
  _next: NextFunction
) => {
  if (error instanceof ZodError) {
    return res.status(400).json({ error: "ValidationError", details: error.errors });
  }

  if (error instanceof NotFoundError) {
    return res.status(404).json({ error: "NotFound", message: error.message });
  }

  return res.status(500).json({ error: "InternalError" });
};
```

OpenAPI snippet (YAML or JSON):

```yaml
paths:
  /users/{id}:
    post:
      summary: Create user
      tags: [Users]
      parameters:
        - in: path
          name: id
          required: true
          schema: { type: string, format: uuid }
        - in: query
          name: include
          required: false
          schema: { type: string, enum: [basic, full] }
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [name, email]
              properties:
                name: { type: string }
                email: { type: string, format: email }
      responses:
        "201":
          description: Created
          content:
            application/json:
              schema:
                type: object
                required: [id, name, email]
                properties:
                  id: { type: string, format: uuid }
                  name: { type: string }
                  email: { type: string, format: email }
        "400": { description: Validation error }
        "404": { description: Not found }
        "500": { description: Internal error }
```

Integration test (Vitest + Supertest):

```ts
import { describe, it, expect } from "vitest";
import request from "supertest";
import { createApp } from "../app";

describe("POST /users/:id", () => {
  it("creates a user", async () => {
    const app = createApp();

    const response = await request(app)
      .post("/users/1b4e28ba-2fa1-11d2-883f-0016d3cca427")
      .send({ name: "Ada", email: "ada@example.com" })
      .expect(201);

    expect(response.body).toMatchObject({
      id: expect.any(String),
      name: "Ada",
      email: "ada@example.com",
    });
  });

  it("rejects invalid input", async () => {
    const app = createApp();

    await request(app)
      .post("/users/not-a-uuid")
      .send({ name: "", email: "bad" })
      .expect(400);
  });
});
```

### FastAPI (Python + Pydantic)

Route handler:

```py
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, EmailStr, Field

router = APIRouter(prefix="/users", tags=["Users"])

class CreateUserRequest(BaseModel):
    name: str = Field(min_length=1)
    email: EmailStr

class UserResponse(BaseModel):
    id: str
    name: str
    email: EmailStr

@router.post(
    "/{user_id}",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
    responses={
        400: {"description": "Validation error"},
        404: {"description": "Not found"},
        500: {"description": "Internal error"},
    },
    summary="Create user",
)
async def create_user(user_id: str, payload: CreateUserRequest) -> UserResponse:
    try:
        user = await create_user_service(user_id=user_id, payload=payload)
        return UserResponse(**user)
    except UserNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail="Internal error") from exc
```

OpenAPI is generated automatically by FastAPI from the models, decorators, and responses.

Integration test (pytest):

```py
from fastapi.testclient import TestClient
from myapp.main import app

client = TestClient(app)

def test_create_user_success():
    response = client.post(
        "/users/1b4e28ba-2fa1-11d2-883f-0016d3cca427",
        json={"name": "Ada", "email": "ada@example.com"},
    )
    assert response.status_code == 201
    body = response.json()
    assert body["name"] == "Ada"
    assert body["email"] == "ada@example.com"

def test_create_user_validation_error():
    response = client.post("/users/not-a-uuid", json={"name": "", "email": "bad"})
    assert response.status_code in (400, 422)
```

### Next.js App Router (TypeScript + Zod)

Route handler: `app/api/users/[id]/route.ts`

```ts
import { NextResponse } from "next/server";
import { z } from "zod";

const paramsSchema = z.object({
  id: z.string().uuid(),
});

const bodySchema = z.object({
  name: z.string().min(1),
  email: z.string().email(),
});

const responseSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  email: z.string().email(),
});

export async function POST(
  request: Request,
  context: { params: { id: string } }
) {
  try {
    const params = paramsSchema.parse(context.params);
    const body = bodySchema.parse(await request.json());

    const result = await createUser({
      id: params.id,
      ...body,
    });

    const responseBody = responseSchema.parse(result);
    return NextResponse.json(responseBody, { status: 201 });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { error: "ValidationError", details: error.errors },
        { status: 400 }
      );
    }

    if (error instanceof NotFoundError) {
      return NextResponse.json(
        { error: "NotFound", message: error.message },
        { status: 404 }
      );
    }

    return NextResponse.json({ error: "InternalError" }, { status: 500 });
  }
}

export const openapi = {
  path: "/api/users/{id}",
  method: "post",
  summary: "Create user",
  tags: ["Users"],
  parameters: [
    { in: "path", name: "id", required: true, schema: { type: "string", format: "uuid" } },
  ],
  requestBody: {
    required: true,
    content: {
      "application/json": {
        schema: {
          type: "object",
          required: ["name", "email"],
          properties: {
            name: { type: "string" },
            email: { type: "string", format: "email" },
          },
        },
      },
    },
  },
  responses: {
    "201": {
      description: "Created",
      content: {
        "application/json": {
          schema: {
            type: "object",
            required: ["id", "name", "email"],
            properties: {
              id: { type: "string", format: "uuid" },
              name: { type: "string" },
              email: { type: "string", format: "email" },
            },
          },
        },
      },
    },
    "400": { description: "Validation error" },
    "404": { description: "Not found" },
    "500": { description: "Internal error" },
  },
};
```

Integration test (Vitest):

```ts
import { describe, it, expect } from "vitest";
import { POST } from "./route";

describe("POST /api/users/[id]", () => {
  it("creates a user", async () => {
    const request = new Request("http://localhost/api/users/1", {
      method: "POST",
      body: JSON.stringify({ name: "Ada", email: "ada@example.com" }),
      headers: { "Content-Type": "application/json" },
    });

    const response = await POST(request, { params: { id: "1b4e28ba-2fa1-11d2-883f-0016d3cca427" } });
    expect(response.status).toBe(201);

    const body = await response.json();
    expect(body).toMatchObject({ name: "Ada", email: "ada@example.com" });
  });

  it("rejects invalid input", async () => {
    const request = new Request("http://localhost/api/users/bad", {
      method: "POST",
      body: JSON.stringify({ name: "", email: "bad" }),
      headers: { "Content-Type": "application/json" },
    });

    const response = await POST(request, { params: { id: "bad" } });
    expect(response.status).toBe(400);
  });
});
```

## Notes
- Replace placeholder service calls and error classes with real implementations.
- Keep response schemas in sync with OpenAPI.
- Keep tests focused on the route behavior and validation.
