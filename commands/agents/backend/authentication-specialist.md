# Authentication Specialist Agent

Authentication and authorization specialist. Expert in JWT, OAuth, RBAC, and security best practices.

## Arguments
- `$ARGUMENTS` - Auth task or feature

## Invoke Agent
```
Use the Task tool with subagent_type="authentication-specialist" to:

1. Implement authentication flows
2. Set up OAuth 2.0 / OIDC
3. Create JWT token handling
4. Implement RBAC/ABAC
5. Secure session management

Task: $ARGUMENTS
```

## Expertise
- OAuth 2.0 / OpenID Connect
- JWT best practices
- Session management
- MFA implementation
- Social login integration

## Mandatory Security Requirements (Non-Negotiable)
All auth implementations MUST satisfy these requirements. If a requirement does not apply, document why and get explicit approval.

### 1) Password Hashing (Argon2id, bcrypt cost >=12)
Requirements:
- Use Argon2id by default. If bcrypt is required, cost MUST be >= 12.
- Never store plaintext passwords or reversible encryption.
- Store algorithm and parameters with the hash; rehash on login when parameters are outdated.

Code example:
```ts
import argon2 from "argon2";
import bcrypt from "bcrypt";

export const hashPassword = async (password: string): Promise<string> => {
  return argon2.hash(password, {
    type: argon2.argon2id,
    timeCost: 3,
    memoryCost: 19456,
    parallelism: 1,
  });
};

export const hashPasswordBcrypt = async (password: string): Promise<string> => {
  const cost = 12;
  return bcrypt.hash(password, cost);
};

export const verifyPassword = async (hash: string, password: string): Promise<boolean> => {
  if (hash.startsWith("$argon2id$")) {
    return argon2.verify(hash, password);
  }
  if (hash.startsWith("$2a$") || hash.startsWith("$2b$")) {
    return bcrypt.compare(password, hash);
  }
  return false;
};
```

### 2) JWT Security (algorithm validation, expiration, refresh tokens)
Requirements:
- Enforce algorithm allowlists, reject `none`, validate `iss`, `aud`, `exp`, `nbf`, and `typ`.
- Access tokens must be short-lived (<= 15 minutes). Use refresh tokens with rotation and revocation.
- Store refresh tokens as hashes only, bind to a session/device, and use `jti` to detect reuse.

Code example:
```ts
import { JWTPayload, jwtVerify, SignJWT } from "jose";
import { createHash, randomBytes, randomUUID } from "crypto";
import type { KeyLike } from "jose";

const ACCESS_TTL_SEC = 900;
const REFRESH_TTL_DAYS = 30;
const ISSUER = "https://auth.example.com";
const AUDIENCE = "api://service";

const hashToken = (token: string): string =>
  createHash("sha256").update(token).digest("hex");

export const verifyAccessToken = async (
  token: string,
  key: KeyLike,
): Promise<JWTPayload> => {
  const { payload, protectedHeader } = await jwtVerify(token, key, {
    issuer: ISSUER,
    audience: AUDIENCE,
    algorithms: ["RS256"],
  });
  if (protectedHeader.typ !== "JWT") {
    throw new Error("Invalid token type");
  }
  return payload;
};

interface RefreshTokenRecord {
  id: string;
  userId: string;
  jti: string;
  hash: string;
  expiresAt: Date;
  revokedAt: Date | null;
}

interface RefreshTokenStore {
  insert: (record: Omit<RefreshTokenRecord, "id" | "revokedAt">) => Promise<void>;
  findByHash: (hash: string) => Promise<RefreshTokenRecord | null>;
  revoke: (id: string) => Promise<void>;
}

export const issueTokens = async (
  userId: string,
  signingKey: KeyLike,
  store: RefreshTokenStore,
): Promise<{ accessToken: string; refreshToken: string }> => {
  const accessToken = await new SignJWT({ sub: userId })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(ISSUER)
    .setAudience(AUDIENCE)
    .setIssuedAt()
    .setExpirationTime(`${ACCESS_TTL_SEC}s`)
    .setJti(randomUUID())
    .sign(signingKey);

  const refreshToken = randomBytes(64).toString("base64url");
  const refreshHash = hashToken(refreshToken);
  const expiresAt = new Date(Date.now() + REFRESH_TTL_DAYS * 24 * 60 * 60 * 1000);
  const refreshJti = randomUUID();

  await store.insert({ userId, jti: refreshJti, hash: refreshHash, expiresAt });
  return { accessToken, refreshToken };
};

export const rotateRefreshToken = async (
  presentedToken: string,
  signingKey: KeyLike,
  store: RefreshTokenStore,
): Promise<{ accessToken: string; refreshToken: string }> => {
  const record = await store.findByHash(hashToken(presentedToken));
  if (!record || record.revokedAt || record.expiresAt <= new Date()) {
    throw new Error("Invalid refresh token");
  }
  await store.revoke(record.id);
  return issueTokens(record.userId, signingKey, store);
};
```

### 3) Session Management (secure cookies, session fixation prevention)
Requirements:
- Use server-side sessions with secure, HttpOnly cookies and `SameSite` policy.
- Rotate session ID on login and privilege changes to prevent fixation.
- Enforce idle and absolute timeouts; invalidate sessions on logout and password change.

Code example:
```ts
import session from "express-session";
import type { Request } from "express";

declare module "express-session" {
  interface SessionData {
    userId?: string;
    createdAt?: number;
  }
}

export const sessionMiddleware = session({
  name: "__Host-session",
  secret: (() => {
    const secret = process.env.SESSION_SECRET;
    if (!secret) {
      throw new Error("SESSION_SECRET is required");
    }
    return secret;
  })(),
  resave: false,
  saveUninitialized: false,
  cookie: {
    httpOnly: true,
    secure: true,
    sameSite: "lax",
    path: "/",
    maxAge: 60 * 60 * 1000,
  },
});

export const establishSession = (req: Request, userId: string): Promise<void> =>
  new Promise((resolve, reject) => {
    req.session.regenerate((err) => {
      if (err) {
        reject(err);
        return;
      }
      req.session.userId = userId;
      req.session.createdAt = Date.now();
      resolve();
    });
  });
```

### 4) MFA Implementation Patterns
Requirements:
- Offer at least one phishing-resistant factor (WebAuthn) or TOTP where WebAuthn is not available.
- Encrypt MFA secrets at rest and enforce step-up auth for sensitive actions.
- Provide recovery codes (hashed) and rate-limit MFA attempts.

Code example (TOTP):
```ts
import { authenticator } from "otplib";

export const createTotpSecret = (): string => authenticator.generateSecret();

export const buildOtpAuthUrl = (email: string, secret: string): string => {
  return authenticator.keyuri(email, "ExampleApp", secret);
};

export const verifyTotpCode = (secret: string, token: string): boolean => {
  return authenticator.verify({ token, secret });
};
```

Code example (WebAuthn):
```ts
import {
  generateRegistrationOptions,
  verifyRegistrationResponse,
} from "@simplewebauthn/server";
import type { VerifiedRegistrationResponse } from "@simplewebauthn/server";

export const startWebAuthnRegistration = (userId: string) => {
  return generateRegistrationOptions({
    rpName: "ExampleApp",
    rpID: "example.com",
    userID: userId,
    userName: userId,
    attestationType: "none",
  });
};

export const finishWebAuthnRegistration = async (
  response: unknown,
): Promise<VerifiedRegistrationResponse> => {
  return verifyRegistrationResponse({
    response,
    expectedOrigin: "https://example.com",
    expectedRPID: "example.com",
    requireUserVerification: true,
  });
};
```

### 5) Brute Force Protection
Requirements:
- Rate-limit by IP and account identifier; apply exponential backoff and temporary blocks.
- Add user-visible friction (CAPTCHA/step-up) after threshold.
- Log and alert on abuse patterns without leaking account existence.

Code example:
```ts
import { RateLimiterRedis } from "rate-limiter-flexible";
import type { RedisClientType } from "redis";

export const buildLoginLimiter = (redis: RedisClientType) => {
  return new RateLimiterRedis({
    storeClient: redis,
    points: 5,
    duration: 60,
    blockDuration: 15 * 60,
  });
};

export const consumeLoginAttempt = async (
  limiter: RateLimiterRedis,
  ip: string,
  identifier: string,
): Promise<void> => {
  const key = `${ip}:${identifier.toLowerCase()}`;
  await limiter.consume(key);
};
```

### 6) Credential Storage Requirements
Requirements:
- Never store secrets in plaintext (passwords, refresh tokens, MFA seeds, API keys).
- Encrypt MFA secrets at rest; store refresh tokens as hashes; use constant-time comparisons.
- Secrets must be stored with least privilege and audited access.

Code example:
```ts
import {
  createCipheriv,
  createDecipheriv,
  createHash,
  randomBytes,
  timingSafeEqual,
} from "crypto";

const ALGO = "aes-256-gcm";

export const encryptSecret = (plaintext: string, key: Buffer): string => {
  const iv = randomBytes(12);
  const cipher = createCipheriv(ALGO, key, iv);
  const ciphertext = Buffer.concat([cipher.update(plaintext, "utf8"), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `${iv.toString("base64")}.${tag.toString("base64")}.${ciphertext.toString("base64")}`;
};

export const decryptSecret = (payload: string, key: Buffer): string => {
  const [ivB64, tagB64, dataB64] = payload.split(".");
  if (!ivB64 || !tagB64 || !dataB64) {
    throw new Error("Invalid payload");
  }
  const decipher = createDecipheriv(ALGO, key, Buffer.from(ivB64, "base64"));
  decipher.setAuthTag(Buffer.from(tagB64, "base64"));
  const plaintext = Buffer.concat([
    decipher.update(Buffer.from(dataB64, "base64")),
    decipher.final(),
  ]);
  return plaintext.toString("utf8");
};

export const hashRefreshToken = (token: string): string =>
  createHash("sha256").update(token).digest("hex");

export const constantTimeEquals = (a: string, b: string): boolean => {
  const aBuf = Buffer.from(a);
  const bBuf = Buffer.from(b);
  return aBuf.length === bBuf.length && timingSafeEqual(aBuf, bBuf);
};
```

### 7) Account Lockout Policies
Requirements:
- Enforce temporary lockouts after repeated failed attempts (example: 5 attempts, 15 minutes).
- Apply progressive delays and reset counters only after successful auth.
- Do not reveal whether the account exists; responses must be uniform.

Code example:
```ts
const MAX_ATTEMPTS = 5;
const LOCK_MINUTES = 15;

interface UserAuthState {
  id: string;
  failedAttempts: number;
  lockedUntil: Date | null;
}

export const isLocked = (user: UserAuthState): boolean => {
  return Boolean(user.lockedUntil && user.lockedUntil > new Date());
};

export const recordFailedAttempt = (user: UserAuthState): UserAuthState => {
  const failedAttempts = user.failedAttempts + 1;
  const shouldLock = failedAttempts >= MAX_ATTEMPTS;
  return {
    ...user,
    failedAttempts,
    lockedUntil: shouldLock
      ? new Date(Date.now() + LOCK_MINUTES * 60 * 1000)
      : user.lockedUntil,
  };
};
```

### 8) OAuth 2.0 / OIDC Implementation
Requirements:
- Use Authorization Code with PKCE for public clients; validate `state` and `nonce`.
- Validate issuer, audience, signature, and `email_verified` (if using email claims).
- Restrict redirect URIs to exact allowlist; never accept wildcard redirects.

Code example:
```ts
import { Issuer, generators } from "openid-client";

const requireEnv = (name: string): string => {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} is required`);
  }
  return value;
};

export const buildAuthUrl = async (redirectUri: string) => {
  const issuer = await Issuer.discover("https://accounts.google.com");
  const client = new issuer.Client({
    client_id: requireEnv("GOOGLE_CLIENT_ID"),
    client_secret: requireEnv("GOOGLE_CLIENT_SECRET"),
    redirect_uris: [redirectUri],
    response_types: ["code"],
  });

  const codeVerifier = generators.codeVerifier();
  const codeChallenge = generators.codeChallenge(codeVerifier);
  const state = generators.state();
  const nonce = generators.nonce();

  const url = client.authorizationUrl({
    scope: "openid email profile",
    code_challenge: codeChallenge,
    code_challenge_method: "S256",
    state,
    nonce,
  });

  return { url, codeVerifier, state, nonce };
};
```

### 9) Social Login Security
Requirements:
- Use provider `sub` as the stable identifier; never trust email alone.
- Require `email_verified` before linking or provisioning accounts.
- Only link identities when the user is already authenticated or has proven control of the local account.

Code example:
```ts
interface OidcClaims {
  sub: string;
  email?: string;
  email_verified?: boolean;
}

export const validateSocialClaims = (claims: OidcClaims): void => {
  if (!claims.sub) {
    throw new Error("Missing subject");
  }
  if (claims.email && !claims.email_verified) {
    throw new Error("Email not verified");
  }
};
```

### 10) Security Audit Checklist
Requirements:
- Provide a checklist and verify every item before shipping.
- Include automated checks where possible (linting, dependency audit, log review).

Code example:
```ts
export const securityAuditChecklist = [
  "Passwords hashed with Argon2id or bcrypt >= 12",
  "JWT allowlist algorithms and exp/nbf/iss/aud validation",
  "Refresh tokens hashed, rotated, and revocable",
  "Sessions use Secure + HttpOnly cookies; session IDs rotate on login",
  "MFA enabled with WebAuthn or TOTP; recovery codes hashed",
  "Rate limiting and lockout policies enforced",
  "OAuth/OIDC uses PKCE, validates state/nonce, exact redirect URIs",
  "Social login requires provider sub and verified email",
  "Credential secrets encrypted at rest; no plaintext logs",
  "Audit logs for auth events with alerting on abuse",
] as const;
```

## Example
```
/agents/backend/authentication-specialist implement OAuth 2.0 with Google login
```
