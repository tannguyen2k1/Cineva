---
name: nuxt-security
description: >-
  Authentication, authorization, and security patterns for this Nuxt 3 SaaS project.
  Covers httpOnly cookie auth flow, JWT access/refresh tokens, server-side permission
  enforcement, tenant isolation, CSRF/XSS prevention, and WebSocket auth.
  Use when adding API endpoints, modifying auth flows, reviewing security, or
  troubleshooting 401/403 errors. Triggers on "auth", "login", "token", "cookie",
  "permission", "401", "403", "security", "CSRF", "XSS", "httpOnly", "refresh token".
---

# Nuxt Security & Auth Patterns

## Auth Architecture

```
Browser ──cookie──► Nitro middleware ──context──► API handler
  │                  (auth.ts)                    (requirePermission)
  │
  ├─ auth_token    httpOnly, secure, sameSite=lax, path=/        (15 min)
  ├─ refresh_token httpOnly, secure, sameSite=lax, path=/api/auth (7 days)
  └─ auth_logged_in NON-httpOnly indicator "1" (client reads for UI state only)
```

**No token is ever exposed to client JS.** The browser sends cookies automatically.

## Server Middleware: `server/middleware/auth.ts`

- Reads token from `getCookie(event, 'auth_token')` first, then `Authorization` header as fallback for API clients.
- Verifies JWT with `jose.jwtVerify`. `JWT_SECRET` must come from env — no hardcoded fallback.
- Loads user + permissions from DB and attaches to `event.context`:
  - `event.context.user` — `{ userId, username }`
  - `event.context.tenant_id` — from JWT payload (never from client header)
  - `event.context.permissions` — `Set<string>` of `"action:resource"` keys
- Public routes skipped: `/api/auth/login`, `/api/auth/register`, `/api/auth/refresh`, `/api/auth/logout`.

### Adding a new public route

Add its prefix to the `PUBLIC_ROUTES` array in `server/middleware/auth.ts`.

## Permission Enforcement

Every protected API handler must call `requirePermission` before business logic:

```typescript
import { requirePermission } from '../../utils/requirePermission'

export default defineEventHandler(async (event) => {
  requirePermission(event, 'read:users')
  // ... business logic
})
```

Available permissions follow `action:resource` format from `server/utils/systemPermissions.ts`:

| Resource | Actions |
|----------|---------|
| dashboard | read |
| users | read, create, update, delete |
| roles | read, create, update, delete |
| tenants | read, create, update, delete |
| logs | read |

When adding a new module, add its entry to `SYSTEM_MODULES` in `systemPermissions.ts`.

## Login & Token Flow

### Login (`POST /api/auth/login`)
1. Validates credentials + Turnstile CAPTCHA.
2. Sets three cookies via `setCookie()`:
   - `auth_token` (access, 15 min, httpOnly)
   - `refresh_token` (7 day, httpOnly, path=/api/auth)
   - `auth_logged_in` ("1", non-httpOnly, for client UI state)
3. Returns user info + permissions in body (no token in body).

### Refresh (`POST /api/auth/refresh`)
1. Reads `refresh_token` cookie.
2. Verifies JWT and checks `type === 'refresh'`.
3. Re-validates user is active in DB.
4. Issues new `auth_token` cookie.
5. Returns updated user/permissions.

### Logout (`POST /api/auth/logout`)
Clears all three auth cookies with `maxAge: 0`.

### Client store (`stores/auth.ts`)
- `loggedIn` mirrors the `auth_logged_in` cookie (non-secret).
- `setAuth(user, tenant_id, permissions)` — no token parameter.
- `fetchUser()` — calls `/api/auth/me` (cookie sent automatically).
- `refreshToken()` — calls `/api/auth/refresh`.
- `logout()` — calls `/api/auth/logout`, clears state, redirects to `/login`.

## Client API Calls

**Do NOT pass `Authorization` headers or `x-tenant-id` headers.** The httpOnly cookie is sent automatically by the browser. All `$fetch` calls are plain:

```typescript
// Correct
const res = await $fetch('/api/users', { method: 'GET' })

// Wrong — exposes token to XSS
const res = await $fetch('/api/users', {
  headers: { Authorization: `Bearer ${token}` }
})
```

For SSR (server-side rendering in plugins), forward cookies explicitly:

```typescript
const headers: Record<string, string> = {}
if (import.meta.server) {
  const cookieHeaders = useRequestHeaders(['cookie'])
  if (cookieHeaders.cookie) headers.cookie = cookieHeaders.cookie
}
await $fetch('/api/auth/me', { headers })
```

## WebSocket Auth

WebSocket handlers can't read httpOnly cookies. Use a short-lived ticket:

1. Client calls `GET /api/auth/ws-ticket` → returns `{ ticket }` (30s TTL JWT).
2. Client connects: `ws://host/ws/endpoint?token=<ticket>`.
3. Server handler verifies ticket in `open()` before pushing data.

## Tenant Isolation

- `tenant_id` comes **only** from the JWT payload in server middleware.
- All Prisma queries must scope by `tenant_id` from `event.context.tenant_id`.
- `getTenantPrisma(tenant_id)` already adds tenant-scoped filters.
- Never trust client-supplied tenant identifiers.

## Security Checklist for New Features

- [ ] API handler calls `requirePermission()` with correct permission key
- [ ] Prisma queries scoped to `event.context.tenant_id`
- [ ] No token/secret in API response body
- [ ] No `Authorization` header construction on client side
- [ ] User input validated/sanitized before DB write
- [ ] File uploads: restrict MIME type, size, use safe filename
- [ ] New i18n keys added for error messages (no hardcoded strings)
- [ ] System log written for mutating actions via `writeSystemLog()`
