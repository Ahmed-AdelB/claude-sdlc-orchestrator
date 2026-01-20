# /secure - API Security Implementation Skill

> **Version:** 2.0.0 | **Category:** Security | **Agent:** security-expert

## Description

Implements comprehensive security measures for API endpoints including authentication (JWT, OAuth, API keys), rate limiting, input validation, CORS, security headers, and CSRF protection.

---

## Arguments

```
$ARGUMENTS: <target> [--auth <type>] [--framework <name>] [--level <basic|standard|strict>]

target:     File path or endpoint pattern to secure (e.g., src/api/*, /api/users)
--auth:     Authentication type: jwt | oauth | apikey | session (default: jwt)
--framework: Express | FastAPI | Flask | NestJS | auto-detect (default: auto-detect)
--level:    Security level - basic (dev), standard (staging), strict (production)
```

**Examples:**

```bash
/secure src/routes/api.ts --auth jwt --framework express --level strict
/secure app/api/ --auth oauth --framework fastapi
/secure server/routes/ --level standard
```

---

## Security Implementation Process

### Phase 1: Analysis and Threat Modeling

1. **Detect Framework** (if not specified)

   ```bash
   # Check package.json, requirements.txt, go.mod, etc.
   # Identify: Express, FastAPI, Flask, NestJS, Gin, etc.
   ```

2. **Audit Current Security State**
   - Identify entry points, data sensitivity, and trust boundaries
   - Check existing auth mechanisms
   - Review input validation coverage
   - Scan for security headers
   - Detect CORS configuration
   - Assess CSRF protection

3. **Generate Security Posture Report**
   ```markdown
   ## Current Security Posture

   - [ ] Authentication: None/Basic/Token/OAuth
   - [ ] Authorization: None/Role-based/Resource-based
   - [ ] Rate Limiting: None/Basic/Advanced
   - [ ] Input Validation: None/Partial/Complete
   - [ ] CORS: Open/Restrictive/Strict
   - [ ] Security Headers: Missing/Partial/Complete
   - [ ] CSRF Protection: None/Token/Double-Submit
   ```

### Phase 2: Implementation Order

Execute in order (dependencies matter):

| Step | Component          | Priority | Depends On |
| ---- | ------------------ | -------- | ---------- |
| 1    | Security Headers   | P0       | None       |
| 2    | CORS Configuration | P0       | None       |
| 3    | Rate Limiting      | P0       | None       |
| 4    | Input Validation   | P1       | None       |
| 5    | Authentication     | P1       | Step 4     |
| 6    | Authorization      | P1       | Step 5     |
| 7    | CSRF Protection    | P2       | Step 5     |

### Phase 3: Verification

```bash
# Run security scan via Gemini
gemini -m gemini-3-pro-preview --approval-mode yolo "Review security implementation in $TARGET for OWASP Top 10 compliance"

# Run automated tests
npm run test:security  # or pytest -m security
```

---

## Step 1: Security Headers

Add HTTP security headers to prevent common attacks.

### Express.js

```typescript
// src/middleware/security-headers.ts
import helmet from "helmet";
import { Express } from "express";

export function configureSecurityHeaders(
  app: Express,
  level: "basic" | "standard" | "strict" = "standard",
) {
  const configs = {
    basic: {
      contentSecurityPolicy: false,
      crossOriginEmbedderPolicy: false,
    },
    standard: {
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          scriptSrc: ["'self'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
          imgSrc: ["'self'", "data:", "https:"],
          connectSrc: ["'self'"],
          fontSrc: ["'self'"],
          objectSrc: ["'none'"],
          frameSrc: ["'none'"],
          upgradeInsecureRequests: [],
        },
      },
      hsts: { maxAge: 31536000, includeSubDomains: true },
    },
    strict: {
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          scriptSrc: ["'self'"],
          styleSrc: ["'self'"],
          imgSrc: ["'self'"],
          connectSrc: ["'self'"],
          fontSrc: ["'self'"],
          objectSrc: ["'none'"],
          frameSrc: ["'none'"],
          baseUri: ["'self'"],
          formAction: ["'self'"],
          upgradeInsecureRequests: [],
        },
      },
      hsts: { maxAge: 63072000, includeSubDomains: true, preload: true },
      referrerPolicy: { policy: "strict-origin-when-cross-origin" },
      crossOriginOpenerPolicy: { policy: "same-origin" },
      crossOriginResourcePolicy: { policy: "same-origin" },
    },
  };

  app.use(helmet(configs[level]));

  // Additional headers not covered by helmet
  app.use((req, res, next) => {
    res.setHeader("X-Content-Type-Options", "nosniff");
    res.setHeader("X-Frame-Options", "DENY");
    res.setHeader("X-XSS-Protection", "1; mode=block");
    res.setHeader(
      "Permissions-Policy",
      "geolocation=(), microphone=(), camera=()",
    );
    next();
  });
}
```

### FastAPI

```python
# src/middleware/security_headers.py
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

HEADERS = {
    'basic': {
        'X-Content-Type-Options': 'nosniff',
        'X-Frame-Options': 'SAMEORIGIN',
    },
    'standard': {
        'X-Content-Type-Options': 'nosniff',
        'X-Frame-Options': 'DENY',
        'X-XSS-Protection': '1; mode=block',
        'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
        'Content-Security-Policy': "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'",
        'Referrer-Policy': 'strict-origin-when-cross-origin',
        'Permissions-Policy': 'geolocation=(), microphone=(), camera=()',
    },
    'strict': {
        'X-Content-Type-Options': 'nosniff',
        'X-Frame-Options': 'DENY',
        'X-XSS-Protection': '1; mode=block',
        'Strict-Transport-Security': 'max-age=63072000; includeSubDomains; preload',
        'Content-Security-Policy': "default-src 'self'; frame-ancestors 'none'",
        'Referrer-Policy': 'strict-origin-when-cross-origin',
        'Cross-Origin-Opener-Policy': 'same-origin',
        'Cross-Origin-Resource-Policy': 'same-origin',
    },
}


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, level: str = 'standard'):
        super().__init__(app)
        self.headers = HEADERS.get(level, HEADERS['standard'])

    async def dispatch(self, request: Request, call_next) -> Response:
        response = await call_next(request)
        for header, value in self.headers.items():
            response.headers[header] = value
        return response
```

### Flask

```python
# src/middleware/security_headers.py
from flask import Flask

def configure_security_headers(app: Flask, level: str = 'standard'):
    @app.after_request
    def add_security_headers(response):
        headers = {
            'X-Content-Type-Options': 'nosniff',
            'X-Frame-Options': 'DENY',
            'X-XSS-Protection': '1; mode=block',
            'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
            'Content-Security-Policy': "default-src 'self'",
            'Referrer-Policy': 'strict-origin-when-cross-origin',
        }
        for header, value in headers.items():
            response.headers[header] = value
        return response
```

### NestJS

```typescript
// src/main.ts
import helmet from "helmet";

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.use(
    helmet({
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          scriptSrc: ["'self'"],
        },
      },
      hsts: { maxAge: 31536000, includeSubDomains: true },
    }),
  );

  await app.listen(3000);
}
```

---

## Step 2: CORS Configuration

Configure Cross-Origin Resource Sharing properly.

### Express.js

```typescript
// src/middleware/cors.ts
import cors, { CorsOptions } from "cors";
import { Express } from "express";

export function configureCORS(
  app: Express,
  level: "basic" | "standard" | "strict" = "standard",
) {
  const allowedOrigins = {
    basic: "*",
    standard: [
      process.env.FRONTEND_URL || "http://localhost:3000",
      process.env.ADMIN_URL || "http://localhost:3001",
    ],
    strict: [process.env.FRONTEND_URL].filter(Boolean) as string[],
  };

  const config: CorsOptions = {
    origin:
      level === "basic"
        ? "*"
        : (origin, callback) => {
            const origins = allowedOrigins[level];
            if (
              !origin ||
              (Array.isArray(origins) && origins.includes(origin))
            ) {
              callback(null, true);
            } else {
              callback(new Error("CORS policy violation"));
            }
          },
    methods:
      level === "strict"
        ? ["GET", "POST", "PUT", "DELETE"]
        : ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allowedHeaders: [
      "Content-Type",
      "Authorization",
      "X-Request-ID",
      "X-CSRF-Token",
    ],
    exposedHeaders: ["X-Request-ID", "X-RateLimit-Remaining"],
    credentials: level !== "basic",
    maxAge: level === "strict" ? 600 : 86400,
    optionsSuccessStatus: 204,
  };

  app.use(cors(config));
}
```

### FastAPI

```python
# src/middleware/cors.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import os

def configure_cors(app: FastAPI, level: str = 'standard'):
    origins = {
        'basic': ['*'],
        'standard': [
            os.getenv('FRONTEND_URL', 'http://localhost:3000'),
            os.getenv('ADMIN_URL', 'http://localhost:3001'),
        ],
        'strict': [os.getenv('FRONTEND_URL', 'http://localhost:3000')],
    }

    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins.get(level, origins['standard']),
        allow_credentials=level != 'basic',
        allow_methods=['GET', 'POST', 'PUT', 'DELETE'] if level == 'strict' else ['*'],
        allow_headers=['Content-Type', 'Authorization', 'X-Request-ID', 'X-CSRF-Token'],
        expose_headers=['X-Request-ID', 'X-RateLimit-Remaining'],
        max_age=600 if level == 'strict' else 86400,
    )
```

### Flask

```python
# src/middleware/cors.py
from flask import Flask
from flask_cors import CORS
import os

def configure_cors(app: Flask, level: str = 'standard'):
    origins = {
        'basic': '*',
        'standard': [
            os.getenv('FRONTEND_URL', 'http://localhost:3000'),
            os.getenv('ADMIN_URL', 'http://localhost:3001'),
        ],
        'strict': [os.getenv('FRONTEND_URL', 'http://localhost:3000')],
    }

    CORS(
        app,
        origins=origins.get(level, origins['standard']),
        supports_credentials=level != 'basic',
        methods=['GET', 'POST', 'PUT', 'DELETE'],
        allow_headers=['Content-Type', 'Authorization', 'X-CSRF-Token'],
    )
```

---

## Step 3: Rate Limiting

Implement rate limiting with configurable limits per security level.

### Express.js

```typescript
// src/middleware/rate-limit.ts
import rateLimit, { RateLimitRequestHandler } from "express-rate-limit";
import RedisStore from "rate-limit-redis";
import Redis from "ioredis";
import { Request, Response } from "express";

interface RateLimitConfig {
  windowMs: number;
  max: number;
  message: string;
}

const LIMITS: Record<string, Record<string, RateLimitConfig>> = {
  basic: {
    general: { windowMs: 60000, max: 100, message: "Too many requests" },
    auth: { windowMs: 900000, max: 10, message: "Too many auth attempts" },
    api: { windowMs: 60000, max: 60, message: "API rate limit exceeded" },
  },
  standard: {
    general: { windowMs: 60000, max: 60, message: "Too many requests" },
    auth: {
      windowMs: 900000,
      max: 5,
      message: "Too many authentication attempts",
    },
    api: { windowMs: 60000, max: 30, message: "API rate limit exceeded" },
  },
  strict: {
    general: { windowMs: 60000, max: 30, message: "Rate limit exceeded" },
    auth: { windowMs: 3600000, max: 3, message: "Account temporarily locked" },
    api: { windowMs: 60000, max: 10, message: "API rate limit exceeded" },
  },
};

export function createRateLimiter(
  type: "general" | "auth" | "api" = "general",
  level: "basic" | "standard" | "strict" = "standard",
  redis?: Redis,
): RateLimitRequestHandler {
  const config = LIMITS[level][type];

  const baseOptions = {
    windowMs: config.windowMs,
    max: config.max,
    message: {
      error: config.message,
      retryAfter: Math.ceil(config.windowMs / 1000),
    },
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (req: Request) =>
      (req as any).user?.id || req.ip || "anonymous",
    handler: (req: Request, res: Response) => {
      res.status(429).json({
        error: config.message,
        retryAfter: Math.ceil(config.windowMs / 1000),
        limit: config.max,
      });
    },
  };

  if (redis) {
    return rateLimit({
      ...baseOptions,
      store: new RedisStore({
        sendCommand: (...args: string[]) => redis.call(...args),
        prefix: `ratelimit:${type}:`,
      }),
    });
  }

  return rateLimit(baseOptions);
}

// Pre-configured limiters
export const authLimiter = (
  level: "basic" | "standard" | "strict" = "standard",
) => createRateLimiter("auth", level);

export const apiLimiter = (
  level: "basic" | "standard" | "strict" = "standard",
) => createRateLimiter("api", level);
```

### FastAPI

```python
# src/middleware/rate_limit.py
import time
from collections import defaultdict
from functools import wraps
from typing import Callable, Optional
from fastapi import HTTPException, Request
from redis import Redis

LIMITS = {
    'basic': {'general': (100, 60), 'auth': (10, 900), 'api': (60, 60)},
    'standard': {'general': (60, 60), 'auth': (5, 900), 'api': (30, 60)},
    'strict': {'general': (30, 60), 'auth': (3, 3600), 'api': (10, 60)},
}


class RateLimiter:
    def __init__(self, redis_client: Optional[Redis] = None, level: str = 'standard'):
        self.redis = redis_client
        self.level = level
        self.local_store: dict = defaultdict(list)

    def _get_key(self, request: Request, limit_type: str) -> str:
        user_id = getattr(request.state, 'user_id', None)
        identifier = user_id or request.client.host or 'anonymous'
        return f"ratelimit:{limit_type}:{identifier}"

    def check_limit(self, request: Request, limit_type: str = 'general') -> tuple[bool, int]:
        max_requests, window_seconds = LIMITS[self.level][limit_type]
        key = self._get_key(request, limit_type)
        now = time.time()

        if self.redis:
            pipe = self.redis.pipeline()
            pipe.zremrangebyscore(key, 0, now - window_seconds)
            pipe.zadd(key, {str(now): now})
            pipe.zcard(key)
            pipe.expire(key, window_seconds)
            _, _, count, _ = pipe.execute()
        else:
            self.local_store[key] = [t for t in self.local_store[key] if now - t < window_seconds]
            self.local_store[key].append(now)
            count = len(self.local_store[key])

        remaining = max(0, max_requests - count)
        return count <= max_requests, remaining


def rate_limit(limit_type: str = 'general', level: str = 'standard'):
    limiter = RateLimiter(level=level)

    def decorator(func: Callable):
        @wraps(func)
        async def wrapper(request: Request, *args, **kwargs):
            allowed, remaining = limiter.check_limit(request, limit_type)
            if not allowed:
                max_requests, window = LIMITS[level][limit_type]
                raise HTTPException(
                    status_code=429,
                    detail={'error': 'Rate limit exceeded', 'retry_after': window},
                    headers={'Retry-After': str(window), 'X-RateLimit-Remaining': '0'},
                )
            return await func(request, *args, **kwargs)
        return wrapper
    return decorator
```

### Flask

```python
# src/middleware/rate_limit.py
from flask import Flask, g, request
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
import os

def configure_rate_limiting(app: Flask, level: str = 'standard'):
    limits = {
        'basic': {'default': '100/minute', 'auth': '10/15minutes'},
        'standard': {'default': '60/minute', 'auth': '5/15minutes'},
        'strict': {'default': '30/minute', 'auth': '3/hour'},
    }

    limiter = Limiter(
        key_func=lambda: g.get('user_id') or get_remote_address(),
        default_limits=[limits[level]['default']],
        storage_uri=os.getenv('REDIS_URL', 'memory://'),
    )
    limiter.init_app(app)

    return limiter
```

---

## Step 4: Input Validation and Sanitization

Validate and sanitize all user inputs to prevent injection attacks.

### Express.js (Zod)

```typescript
// src/middleware/validation.ts
import { Request, Response, NextFunction } from "express";
import { z, ZodSchema, ZodError } from "zod";
import createDOMPurify from "dompurify";
import { JSDOM } from "jsdom";

const window = new JSDOM("").window;
const DOMPurify = createDOMPurify(window as any);

// Sanitization utilities
export const sanitize = {
  html: (input: string): string =>
    DOMPurify.sanitize(input, { ALLOWED_TAGS: [] }),
  filename: (input: string): string =>
    input.replace(/[^a-zA-Z0-9._-]/g, "").substring(0, 255),
  email: (input: string): string => input.toLowerCase().trim(),
  object: <T extends Record<string, any>>(
    obj: T,
    allowedKeys: string[],
  ): Partial<T> =>
    Object.fromEntries(
      Object.entries(obj).filter(([key]) => allowedKeys.includes(key)),
    ) as Partial<T>,
};

// Validation middleware factory
export function validate<T>(
  schema: ZodSchema<T>,
  source: "body" | "query" | "params" = "body",
) {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = req[source];
      const validated = await schema.parseAsync(data);
      req[source] = validated as any;
      next();
    } catch (error) {
      if (error instanceof ZodError) {
        return res.status(400).json({
          error: "Validation failed",
          details: error.errors.map((e) => ({
            field: e.path.join("."),
            message: e.message,
            code: e.code,
          })),
        });
      }
      next(error);
    }
  };
}

// Common validation schemas
export const schemas = {
  id: z.object({ id: z.string().uuid("Invalid ID format") }),

  pagination: z.object({
    page: z.coerce.number().int().positive().default(1),
    limit: z.coerce.number().int().min(1).max(100).default(20),
    sort: z.string().optional(),
    order: z.enum(["asc", "desc"]).default("desc"),
  }),

  email: z.string().email().max(255).transform(sanitize.email),

  password: z
    .string()
    .min(12, "Password must be at least 12 characters")
    .max(128)
    .regex(/[A-Z]/, "Must contain uppercase")
    .regex(/[a-z]/, "Must contain lowercase")
    .regex(/[0-9]/, "Must contain number")
    .regex(/[^A-Za-z0-9]/, "Must contain special character"),

  username: z
    .string()
    .min(3)
    .max(30)
    .regex(/^[a-zA-Z0-9_-]+$/, "Invalid username"),
};

// Request sanitization middleware
export function sanitizeRequest(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  if (req.body && typeof req.body === "object") {
    req.body = deepSanitize(req.body);
  }
  if (req.query && typeof req.query === "object") {
    req.query = deepSanitize(req.query) as any;
  }
  next();
}

function deepSanitize(obj: any): any {
  if (typeof obj === "string") return sanitize.html(obj);
  if (Array.isArray(obj)) return obj.map(deepSanitize);
  if (obj && typeof obj === "object") {
    return Object.fromEntries(
      Object.entries(obj).map(([k, v]) => [k, deepSanitize(v)]),
    );
  }
  return obj;
}
```

### FastAPI (Pydantic)

```python
# src/middleware/validation.py
import re
import html
from typing import Any, Dict, List
from pydantic import BaseModel, field_validator, EmailStr
from bleach import clean


def sanitize_html(text: str) -> str:
    """Remove all HTML tags and decode entities."""
    return html.escape(clean(text, tags=[], strip=True))


def sanitize_filename(filename: str) -> str:
    """Sanitize filename to prevent path traversal."""
    return re.sub(r'[^a-zA-Z0-9._-]', '', filename)[:255]


class SecureBaseModel(BaseModel):
    """Base model with automatic string sanitization."""

    @field_validator('*', mode='before')
    @classmethod
    def sanitize_strings(cls, v):
        if isinstance(v, str):
            return sanitize_html(v)
        return v


class PasswordSchema(BaseModel):
    password: str

    @field_validator('password')
    @classmethod
    def validate_password(cls, v):
        if len(v) < 12:
            raise ValueError('Password must be at least 12 characters')
        if len(v) > 128:
            raise ValueError('Password too long')
        if not re.search(r'[A-Z]', v):
            raise ValueError('Must contain uppercase letter')
        if not re.search(r'[a-z]', v):
            raise ValueError('Must contain lowercase letter')
        if not re.search(r'[0-9]', v):
            raise ValueError('Must contain number')
        if not re.search(r'[^A-Za-z0-9]', v):
            raise ValueError('Must contain special character')
        return v


class PaginationSchema(BaseModel):
    page: int = 1
    limit: int = 20
    sort: str | None = None
    order: str = 'desc'

    @field_validator('page')
    @classmethod
    def validate_page(cls, v):
        if v < 1:
            raise ValueError('Page must be positive')
        return v

    @field_validator('limit')
    @classmethod
    def validate_limit(cls, v):
        if v < 1 or v > 100:
            raise ValueError('Limit must be between 1 and 100')
        return v
```

---

## Step 5: Authentication (JWT, OAuth, API Keys)

### JWT Authentication - Express.js

```typescript
// src/middleware/auth.ts
import { Request, Response, NextFunction } from "express";
import jwt, { JwtPayload, SignOptions } from "jsonwebtoken";
import { randomBytes, createHash } from "crypto";

interface TokenPayload extends JwtPayload {
  userId: string;
  email: string;
  roles: string[];
  sessionId: string;
}

const config = {
  accessTokenSecret: process.env.JWT_ACCESS_SECRET!,
  refreshTokenSecret: process.env.JWT_REFRESH_SECRET!,
  accessTokenExpiry: "15m",
  refreshTokenExpiry: "7d",
  issuer: process.env.JWT_ISSUER || "api",
  audience: process.env.JWT_AUDIENCE || "app",
};

// Token generation
export function generateTokens(user: {
  id: string;
  email: string;
  roles: string[];
}) {
  const sessionId = randomBytes(16).toString("hex");

  const accessToken = jwt.sign(
    {
      userId: user.id,
      email: user.email,
      roles: user.roles,
      sessionId,
    } as TokenPayload,
    config.accessTokenSecret,
    {
      expiresIn: config.accessTokenExpiry,
      issuer: config.issuer,
      audience: config.audience,
      algorithm: "HS256",
    },
  );

  const refreshToken = jwt.sign(
    { userId: user.id, sessionId },
    config.refreshTokenSecret,
    {
      expiresIn: config.refreshTokenExpiry,
      issuer: config.issuer,
      audience: config.audience,
      algorithm: "HS256",
    },
  );

  const refreshTokenHash = createHash("sha256")
    .update(refreshToken)
    .digest("hex");

  return { accessToken, refreshToken, refreshTokenHash, sessionId };
}

// Authentication middleware
export function authenticate(
  options: { required?: boolean; roles?: string[] } = {},
) {
  const { required = true, roles = [] } = options;

  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const authHeader = req.headers.authorization;

      if (!authHeader?.startsWith("Bearer ")) {
        if (required)
          return res.status(401).json({ error: "Authentication required" });
        return next();
      }

      const token = authHeader.slice(7);

      const payload = jwt.verify(token, config.accessTokenSecret, {
        issuer: config.issuer,
        audience: config.audience,
        algorithms: ["HS256"],
      }) as TokenPayload;

      if (
        roles.length > 0 &&
        !roles.some((role) => payload.roles.includes(role))
      ) {
        return res.status(403).json({ error: "Insufficient permissions" });
      }

      (req as any).user = {
        id: payload.userId,
        email: payload.email,
        roles: payload.roles,
        sessionId: payload.sessionId,
      };

      next();
    } catch (error) {
      if (error instanceof jwt.TokenExpiredError) {
        return res
          .status(401)
          .json({ error: "Token expired", code: "TOKEN_EXPIRED" });
      }
      if (error instanceof jwt.JsonWebTokenError) {
        return res
          .status(401)
          .json({ error: "Invalid token", code: "INVALID_TOKEN" });
      }
      next(error);
    }
  };
}

// Role-based access control
export function requireRoles(...roles: string[]) {
  return authenticate({ required: true, roles });
}

// API Key authentication (for service-to-service)
export function authenticateApiKey(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  const apiKey = req.headers["x-api-key"] as string;

  if (!apiKey) return res.status(401).json({ error: "API key required" });

  const keyHash = createHash("sha256").update(apiKey).digest("hex");
  const validKeyHash = process.env.API_KEY_HASH;

  if (keyHash !== validKeyHash) {
    return res.status(401).json({ error: "Invalid API key" });
  }

  (req as any).apiKey = { hash: keyHash };
  next();
}
```

### JWT Authentication - FastAPI

```python
# src/middleware/auth.py
import os
import hashlib
import secrets
from datetime import datetime, timedelta
from typing import List
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
from pydantic import BaseModel

security = HTTPBearer()


class TokenPayload(BaseModel):
    user_id: str
    email: str
    roles: List[str]
    session_id: str
    exp: datetime
    iat: datetime


class JWTAuth:
    def __init__(self):
        self.access_secret = os.environ['JWT_ACCESS_SECRET']
        self.refresh_secret = os.environ['JWT_REFRESH_SECRET']
        self.algorithm = 'HS256'
        self.access_expiry = timedelta(minutes=15)
        self.refresh_expiry = timedelta(days=7)
        self.issuer = os.getenv('JWT_ISSUER', 'api')
        self.audience = os.getenv('JWT_AUDIENCE', 'app')

    def create_tokens(self, user_id: str, email: str, roles: List[str]) -> dict:
        session_id = secrets.token_hex(16)
        now = datetime.utcnow()

        access_payload = {
            'user_id': user_id, 'email': email, 'roles': roles,
            'session_id': session_id, 'iat': now, 'exp': now + self.access_expiry,
            'iss': self.issuer, 'aud': self.audience,
        }
        access_token = jwt.encode(access_payload, self.access_secret, algorithm=self.algorithm)

        refresh_payload = {
            'user_id': user_id, 'session_id': session_id,
            'iat': now, 'exp': now + self.refresh_expiry,
            'iss': self.issuer, 'aud': self.audience,
        }
        refresh_token = jwt.encode(refresh_payload, self.refresh_secret, algorithm=self.algorithm)
        refresh_hash = hashlib.sha256(refresh_token.encode()).hexdigest()

        return {
            'access_token': access_token, 'refresh_token': refresh_token,
            'refresh_token_hash': refresh_hash, 'session_id': session_id,
            'token_type': 'bearer', 'expires_in': int(self.access_expiry.total_seconds()),
        }

    def verify_access_token(self, token: str) -> TokenPayload:
        try:
            payload = jwt.decode(
                token, self.access_secret, algorithms=[self.algorithm],
                issuer=self.issuer, audience=self.audience,
            )
            return TokenPayload(**payload)
        except JWTError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail='Invalid or expired token',
                headers={'WWW-Authenticate': 'Bearer'},
            )


jwt_auth = JWTAuth()


async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> TokenPayload:
    return jwt_auth.verify_access_token(credentials.credentials)


def require_roles(*required_roles: str):
    async def role_checker(user: TokenPayload = Depends(get_current_user)):
        if not any(role in user.roles for role in required_roles):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail='Insufficient permissions')
        return user
    return role_checker
```

### OAuth2 with PKCE - Express.js

```typescript
// src/auth/oauth.ts
import { randomBytes, createHash } from "crypto";

export function generatePKCE() {
  const codeVerifier = randomBytes(32).toString("base64url");
  const codeChallenge = createHash("sha256")
    .update(codeVerifier)
    .digest("base64url");

  return { codeVerifier, codeChallenge, challengeMethod: "S256" };
}

export function verifyPKCE(
  codeVerifier: string,
  codeChallenge: string,
): boolean {
  const computed = createHash("sha256")
    .update(codeVerifier)
    .digest("base64url");
  return computed === codeChallenge;
}

// OAuth2 Authorization endpoint
app.get("/oauth/authorize", (req, res) => {
  const {
    client_id,
    redirect_uri,
    code_challenge,
    code_challenge_method,
    state,
  } = req.query;

  // Validate client_id and redirect_uri
  // Store code_challenge for later verification
  // Generate authorization code
  // Redirect to consent page or directly to redirect_uri
});

// OAuth2 Token endpoint
app.post("/oauth/token", async (req, res) => {
  const { grant_type, code, redirect_uri, client_id, code_verifier } = req.body;

  if (grant_type === "authorization_code") {
    // Retrieve stored code_challenge
    // Verify PKCE: verifyPKCE(code_verifier, storedCodeChallenge)
    // Exchange code for tokens
  }
});
```

---

## Step 6: CSRF Protection

Implement CSRF protection for state-changing requests.

### Express.js

```typescript
// src/middleware/csrf.ts
import { Request, Response, NextFunction } from "express";
import { randomBytes, createHmac, timingSafeEqual } from "crypto";

const config = {
  secret: process.env.CSRF_SECRET!,
  cookieName: "__csrf",
  headerName: "x-csrf-token",
  tokenLength: 32,
  maxAge: 3600,
};

export function generateCSRFToken(): { token: string; cookie: string } {
  const tokenValue = randomBytes(config.tokenLength).toString("hex");
  const timestamp = Date.now().toString(36);
  const signature = createHmac("sha256", config.secret)
    .update(`${tokenValue}.${timestamp}`)
    .digest("hex");

  const token = `${tokenValue}.${timestamp}.${signature}`;
  const cookie = createHmac("sha256", config.secret)
    .update(token)
    .digest("hex");

  return { token, cookie };
}

function validateCSRFToken(token: string, cookie: string): boolean {
  try {
    const [tokenValue, timestamp, signature] = token.split(".");
    if (!tokenValue || !timestamp || !signature) return false;

    const tokenTime = parseInt(timestamp, 36);
    if (Date.now() - tokenTime > config.maxAge * 1000) return false;

    const expectedSignature = createHmac("sha256", config.secret)
      .update(`${tokenValue}.${timestamp}`)
      .digest("hex");

    if (
      !timingSafeEqual(Buffer.from(signature), Buffer.from(expectedSignature))
    )
      return false;

    const expectedCookie = createHmac("sha256", config.secret)
      .update(token)
      .digest("hex");
    return timingSafeEqual(Buffer.from(cookie), Buffer.from(expectedCookie));
  } catch {
    return false;
  }
}

export function csrfProtection(options: { ignoreMethods?: string[] } = {}) {
  const { ignoreMethods = ["GET", "HEAD", "OPTIONS"] } = options;

  return (req: Request, res: Response, next: NextFunction) => {
    if (ignoreMethods.includes(req.method)) return next();

    const token = req.headers[config.headerName] as string;
    const cookie = req.cookies?.[config.cookieName];

    if (!token || !cookie)
      return res.status(403).json({ error: "CSRF token missing" });
    if (!validateCSRFToken(token, cookie))
      return res.status(403).json({ error: "CSRF token invalid" });

    next();
  };
}

export function csrfTokenEndpoint(req: Request, res: Response) {
  const { token, cookie } = generateCSRFToken();

  res.cookie(config.cookieName, cookie, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "strict",
    maxAge: config.maxAge * 1000,
  });

  res.json({ csrfToken: token });
}
```

### FastAPI

```python
# src/middleware/csrf.py
import hmac
import secrets
import time
from fastapi import HTTPException, Request, Response

CSRF_SECRET = os.environ['CSRF_SECRET']
CSRF_COOKIE = '__csrf'
CSRF_HEADER = 'x-csrf-token'
MAX_AGE = 3600


def generate_csrf_token() -> tuple[str, str]:
    token_value = secrets.token_hex(32)
    timestamp = hex(int(time.time()))[2:]
    signature = hmac.new(
        CSRF_SECRET.encode(), f'{token_value}.{timestamp}'.encode(), 'sha256'
    ).hexdigest()

    token = f'{token_value}.{timestamp}.{signature}'
    cookie = hmac.new(CSRF_SECRET.encode(), token.encode(), 'sha256').hexdigest()

    return token, cookie


def validate_csrf_token(token: str, cookie: str) -> bool:
    try:
        parts = token.split('.')
        if len(parts) != 3:
            return False

        token_value, timestamp, signature = parts
        token_time = int(timestamp, 16)

        if time.time() - token_time > MAX_AGE:
            return False

        expected_sig = hmac.new(
            CSRF_SECRET.encode(), f'{token_value}.{timestamp}'.encode(), 'sha256'
        ).hexdigest()

        if not hmac.compare_digest(signature, expected_sig):
            return False

        expected_cookie = hmac.new(CSRF_SECRET.encode(), token.encode(), 'sha256').hexdigest()
        return hmac.compare_digest(cookie, expected_cookie)
    except Exception:
        return False


async def csrf_protect(request: Request):
    if request.method in ('GET', 'HEAD', 'OPTIONS'):
        return

    token = request.headers.get(CSRF_HEADER)
    cookie = request.cookies.get(CSRF_COOKIE)

    if not token or not cookie:
        raise HTTPException(status_code=403, detail='CSRF token missing')

    if not validate_csrf_token(token, cookie):
        raise HTTPException(status_code=403, detail='CSRF token invalid')
```

---

## Complete Setup Examples

### Express.js Full Setup

```typescript
// src/app.ts
import express from "express";
import cookieParser from "cookie-parser";
import { configureSecurityHeaders } from "./middleware/security-headers";
import { configureCORS } from "./middleware/cors";
import { createRateLimiter, authLimiter } from "./middleware/rate-limit";
import { sanitizeRequest, validate, schemas } from "./middleware/validation";
import { authenticate, requireRoles } from "./middleware/auth";
import { csrfProtection, csrfTokenEndpoint } from "./middleware/csrf";

const app = express();
const level =
  (process.env.SECURITY_LEVEL as "basic" | "standard" | "strict") || "standard";

// 1. Security headers
configureSecurityHeaders(app, level);

// 2. CORS
configureCORS(app, level);

// 3. Body parsing with limits
app.use(express.json({ limit: "10kb" }));
app.use(express.urlencoded({ extended: true, limit: "10kb" }));
app.use(cookieParser());

// 4. Request sanitization
app.use(sanitizeRequest);

// 5. General rate limiting
app.use(createRateLimiter("general", level));

// 6. CSRF token endpoint
app.get("/api/csrf-token", csrfTokenEndpoint);

// 7. CSRF protection for state-changing requests
app.use("/api", csrfProtection());

// 8. Auth routes with stricter rate limiting
app.use("/api/auth", authLimiter(level));

// Protected routes
app.get("/api/users", authenticate(), async (req, res) => {
  res.json({ user: (req as any).user });
});

app.get("/api/admin", requireRoles("admin"), async (req, res) => {
  res.json({ message: "Admin access granted" });
});

export default app;
```

### FastAPI Full Setup

```python
# src/main.py
from fastapi import FastAPI, Depends, Request
from src.middleware.security_headers import SecurityHeadersMiddleware
from src.middleware.cors import configure_cors
from src.middleware.rate_limit import rate_limit
from src.middleware.auth import get_current_user, require_roles
from src.middleware.csrf import csrf_protect

app = FastAPI()
level = 'standard'

# 1. Security headers
app.add_middleware(SecurityHeadersMiddleware, level=level)

# 2. CORS
configure_cors(app, level)


# Protected routes
@app.get('/api/users')
@rate_limit('api', level)
async def get_users(request: Request, user=Depends(get_current_user)):
    return {'user': user.dict()}


@app.get('/api/admin')
async def admin_area(user=Depends(require_roles('admin'))):
    return {'message': 'Admin access'}


@app.post('/api/data')
async def create_data(request: Request, _=Depends(csrf_protect), user=Depends(get_current_user)):
    return {'ok': True}
```

### NestJS Full Setup

```typescript
// src/main.ts
import { NestFactory } from "@nestjs/core";
import { ValidationPipe } from "@nestjs/common";
import helmet from "helmet";
import { AppModule } from "./app.module";

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Security headers
  app.use(
    helmet({
      contentSecurityPolicy: {
        directives: { defaultSrc: ["'self'"], scriptSrc: ["'self'"] },
      },
      hsts: { maxAge: 31536000, includeSubDomains: true },
    }),
  );

  // CORS
  app.enableCors({
    origin: process.env.ALLOWED_ORIGINS?.split(",") || [
      "http://localhost:3000",
    ],
    credentials: true,
    methods: ["GET", "POST", "PUT", "DELETE"],
  });

  // Global validation pipe
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  await app.listen(3000);
}
bootstrap();
```

---

## OWASP Top 10 Coverage Checklist (2021)

After running `/secure`, verify coverage:

| #   | Vulnerability             | Mitigation                                            | Status |
| --- | ------------------------- | ----------------------------------------------------- | ------ |
| A01 | Broken Access Control     | JWT auth, RBAC, route guards                          | [ ]    |
| A02 | Cryptographic Failures    | HTTPS, secure cookies, hashed tokens                  | [ ]    |
| A03 | Injection                 | Parameterized queries, input validation, sanitization | [ ]    |
| A04 | Insecure Design           | Security headers, least privilege, threat modeling    | [ ]    |
| A05 | Security Misconfiguration | Helmet/CSP, CORS strict mode, env-based config        | [ ]    |
| A06 | Vulnerable Components     | Dependency audit (npm audit, pip-audit)               | [ ]    |
| A07 | Auth Failures             | Rate limiting on auth, JWT best practices, PKCE       | [ ]    |
| A08 | Software Integrity        | CSRF protection, SRI hashes, signed tokens            | [ ]    |
| A09 | Logging Failures          | Audit logging (implement separately)                  | [ ]    |
| A10 | SSRF                      | Input validation, URL allowlists, egress filtering    | [ ]    |

---

## Integration with Security Review Agent

After implementation, invoke security review:

```bash
# Automated security review via Gemini
gemini -m gemini-3-pro-preview --approval-mode yolo "
SECURITY REVIEW REQUEST:
- Target: $TARGET
- Changes: Authentication, rate limiting, validation, CORS, headers, CSRF
- Check: OWASP Top 10 compliance
- Output: PASS/FAIL with specific findings
"

# Deep security scan via Codex
codex exec -m gpt-5.2-codex -c 'model_reasoning_effort="xhigh"' -s workspace-write "
Run security analysis on $TARGET:
1. Check for hardcoded secrets
2. Verify parameterized queries
3. Review auth implementation
4. Check rate limit bypass vectors
5. Validate CSRF token implementation
Output: Security report with severity ratings
"
```

---

## Post-Implementation Verification

```bash
# 1. Test authentication
curl -X POST /api/auth/login -d '{"email":"test@example.com","password":"Test123!@#abc"}' -v

# 2. Test rate limiting
for i in {1..100}; do curl -s -o /dev/null -w "%{http_code}\n" /api/users; done | sort | uniq -c

# 3. Test CORS
curl -H "Origin: http://evil.com" -I /api/users

# 4. Test security headers
curl -I /api/users | grep -E "X-Frame|X-Content|Strict-Transport|Content-Security"

# 5. Test CSRF
curl -X POST /api/data -d '{"key":"value"}' -H "Origin: http://evil.com"

# 6. Run security scanner
npm audit --audit-level=moderate
trivy fs --severity HIGH,CRITICAL .
bandit -r . -ll  # Python
```

---

## Dependencies

### Node.js (Express/NestJS)

```json
{
  "dependencies": {
    "helmet": "^7.1.0",
    "cors": "^2.8.5",
    "express-rate-limit": "^7.1.5",
    "rate-limit-redis": "^4.2.0",
    "jsonwebtoken": "^9.0.2",
    "zod": "^3.22.4",
    "dompurify": "^3.0.6",
    "jsdom": "^23.0.1",
    "cookie-parser": "^1.4.6",
    "ioredis": "^5.3.2"
  }
}
```

### Python (FastAPI/Flask)

```txt
python-jose[cryptography]>=3.3.0
passlib[bcrypt]>=1.7.4
python-multipart>=0.0.6
bleach>=6.1.0
pydantic>=2.5.0
flask-cors>=4.0.0
flask-limiter>=3.5.0
flask-wtf>=1.2.0
redis>=5.0.0
slowapi>=0.1.9
```

---

## Error Handling Best Practices

Security implementations should fail closed:

```typescript
// GOOD: Fail closed
if (!token || !validateToken(token)) {
  return res.status(401).json({ error: "Unauthorized" });
}

// BAD: Fail open - NEVER do this
try {
  validateToken(token);
} catch {
  // Silently continue
}
```

---

## Example Usage

```bash
/secure src/routes/api.ts --auth jwt --framework express --level strict
/secure app/api/ --auth oauth --framework fastapi --level standard
/secure server/routes/ --auth apikey --framework flask --level basic
/secure src/controllers/ --framework nestjs --level strict
```

---

## Attribution

```
Author: Ahmed Adel Bakr Alderai
```
