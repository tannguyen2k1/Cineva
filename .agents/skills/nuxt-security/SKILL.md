---
name: nuxt-security
description: >-
  Authentication, authorization, and security for this monorepo (Nuxt FE + FastAPI BE).
  Covers httpOnly cookie auth, access/refresh JWT with DB-backed refresh rotation,
  permission checks, tenant isolation, CSRF/XSS notes, and WebSocket tickets.
  Use when adding API endpoints, modifying auth, reviewing security, or debugging 401/403.
  Triggers on "auth", "login", "token", "cookie", "permission", "401", "403", "security",
  "CSRF", "XSS", "httpOnly", "refresh token".
---

# Security & Auth

## Architecture

```
Browser ──cookie──► Nuxt (:3000) ──proxy /api──► FastAPI (:8000)
                      │                            │
                      │                            ├─ deps.get_current_user
                      │                            └─ require_permission
Cookies (set by FastAPI, proxied through Nuxt):
  auth_token      httpOnly, path=/, 15m          (access JWT)
  refresh_token   httpOnly, path=/api/auth, 7d   (refresh JWT + DB row)
  auth_logged_in  readable "1"                   (UI only)
  csrf_token      readable                       (double-submit CSRF)
```

**Never store JWT in localStorage / Pinia.** Cookies only.

## Tokens

| Kind | Cookie / use | Claims | Persist |
|------|----------------|--------|---------|
| Access | `auth_token` | `type=access`, `sub`/`userId`, `username`, `tenant_id`, `jti` | Denylist table on revoke |
| Refresh | `refresh_token` | `type=refresh`, `userId`, `tenant_id`, `jti` | Yes — `refresh_tokens` table, SHA-256 hash |
| WS ticket | query `?token=` | `type=ws-ticket`, 30s | No |
| CSRF | `csrf_token` + header `X-CSRF-Token` | random | Cookie only |

### Refresh rotation (`backend/app/services/auth.py` + `refresh_sessions.py`)

1. Login → create access + refresh; insert `RefreshToken` (jti, family_id, token_hash); set `csrf_token`.
2. `POST /api/auth/refresh` → validate JWT + DB row active → **denylist old access jti**, **revoke old refresh**, issue new pair in same `family_id`.
3. Reuse of revoked refresh → revoke **entire family** (theft signal).
4. Logout → denylist access `jti` + revoke refresh family + clear cookies (incl. CSRF).
5. Password change / `revoke_user_sessions` → revoke all refresh rows **and** set `User.tokens_invalid_before=now()` so every device's access JWT (`iat` before cutoff) fails immediately.

### Access enforcement (`backend/app/api/deps.py`)

- Cookie `auth_token` first, else `Authorization: Bearer`.
- Reject if `type != access`.
- Reject if `jti` is in `revoked_access_tokens` (logout / rotated).
- Reject if JWT `iat` < `user.tokens_invalid_before` (password change / force logout all).
- Reload user from DB (active, not soft-deleted); build permission set.

### CSRF (double-submit)

- Mutating methods (`POST`/`PUT`/`PATCH`/`DELETE`) require header `X-CSRF-Token` == cookie `csrf_token`.
- Exempt: `/api/auth/login`, `/api/auth/logout`, docs, health, uploads.
- FE: `frontend/plugins/csrf.client.ts` attaches the header on `$fetch`.
- Only enforced when `auth_token` or `refresh_token` cookies are present (Bearer-only clients skip).

### Rate limit

In-memory sliding window per IP (`backend/app/api/rate_limit.py`):

| Path | Default |
|------|---------|
| `POST /api/auth/login` | 5 / min |
| `POST /api/auth/refresh` | 30 / min |
| `GET /api/auth/ws-ticket` | 20 / min |
| other `/api/*` | 120 / min |

Env: `RATE_LIMIT_LOGIN`, `RATE_LIMIT_REFRESH`, `RATE_LIMIT_WS_TICKET`, `RATE_LIMIT_API` (0 = off).  
429 body uses Nuxt shape + `Retry-After`. Multi-worker/multi-host: terminate limits at gateway or swap store to Redis.

## Permissions

Catalog: `backend/app/core/permissions.py` (`SYSTEM_MODULES`).  
Key format: `action:resource` (e.g. `read:users`).

```python
current: CurrentUser = Depends(require_permission("read:users"))
# current.tenant_id — ONLY from JWT, never from client body/header
```

## Public routes

No auth: `/api/auth/login`, `/logout`, `/refresh`, `/api/docs`, `/api/openapi.json`, `/health`.

## Frontend

- `$fetch('/api/...')` relative — Nuxt proxies to FastAPI (`NUXT_API_PROXY`).
- Do **not** send `Authorization` or `x-tenant-id` from the browser for normal UI calls.
- Indicator cookie `auth_logged_in` for route middleware only.

## Checklist

- [ ] Protected route uses `require_permission` / `get_current_user`
- [ ] Queries scoped by `current.tenant_id`
- [ ] Mutating actions call `write_system_log`
- [ ] Soft delete uses `deleted_at`, not hard delete
- [ ] No secrets in API responses / client storage
- [ ] New permissions added to `SYSTEM_MODULES`
