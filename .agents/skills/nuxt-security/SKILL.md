---
name: nuxt-security
description: >-
  Authentication, authorization, and security for this monorepo (Nuxt FE + FastAPI BE).
  Covers httpOnly cookie auth for browsers, OAuth2 password/refresh for API clients & Scalar,
  permission checks, CSRF/XSS notes, and WebSocket tickets.
  Use when adding API endpoints, modifying auth, reviewing security, or debugging 401/403.
  Triggers on "auth", "login", "token", "cookie", "permission", "401", "403", "security",
  "CSRF", "XSS", "httpOnly", "refresh token", "OAuth2".
---

# Security & Auth

## Architecture

Two channels, one JWT format:

```
Browser (Nuxt)
  POST /api/auth/login (+ Turnstile)
    → Set-Cookie: auth_token / refresh_token / csrf_token (HttpOnly where needed)
    → JSON: { user, permissions } only — never access_token in body

API client / Scalar / mobile
  POST /api/auth/token  (OAuth2 form: grant_type=password|refresh_token)
    → JSON: { access_token, token_type, expires_in, refresh_token }
    → no cookies
  Then: Authorization: Bearer <access_token>
```

```
Browser ──cookie──► Nuxt (:3000) ──proxy /api──► FastAPI (:8000)
API/Scalar ──Bearer──► FastAPI (:8000)
```

**Never store JWT in localStorage / Pinia.** Browser uses cookies only.

## Tokens

| Kind | Transport | Claims | Persist |
|------|-----------|--------|---------|
| Access | Cookie `auth_token` **or** Bearer | `type=access`, `sub`/`userId`, `username`, `jti` | Denylist table on revoke |
| Refresh | Cookie `refresh_token` **or** OAuth2 body | `type=refresh`, `userId`, `jti` | Yes — `refresh_tokens` table, SHA-256 hash |
| WS ticket | query `?token=` | `type=ws-ticket`, 30s | No |
| CSRF | `csrf_token` + header `X-CSRF-Token` | random | Cookie only (browser) |

### Cookie session (`/api/auth/login`, `/refresh`, `/logout`)

1. Login → create access + refresh; insert `RefreshToken`; set cookies + CSRF. Body has **no** token.
2. `POST /api/auth/refresh` (cookie) → denylist old access jti, rotate refresh, new cookies.
3. Reuse of revoked refresh → revoke **entire family**.
4. Logout → denylist access + revoke family + clear cookies.
5. Password change / `revoke_user_sessions` → revoke all refresh + `tokens_invalid_before`.

### OAuth2 (`POST /api/auth/token`)

Form `application/x-www-form-urlencoded`:

| grant_type | Fields | Result |
|------------|--------|--------|
| `password` (default) | `username`, `password` | New access + refresh (no Turnstile) |
| `refresh_token` | `refresh_token` | Rotated pair |

Response (RFC 6749 shape):

```json
{
  "access_token": "...",
  "token_type": "bearer",
  "expires_in": 900,
  "refresh_token": "..."
}
```

Scalar: OpenAPI scheme **OAuth2Password** (`tokenUrl: /api/auth/token`) + `persist_auth`. Prefer Authorize → enter username/password → token auto-applied.

### Access enforcement (`backend/app/api/deps.py`)

- `extract_token`: **Bearer first**, else cookie `auth_token`.
- Reject if `type != access`.
- Reject if `jti` is in `revoked_access_tokens`.
- Reject if JWT `iat` < `user.tokens_invalid_before`.
- Reload user from DB; build permission set.

### CSRF (double-submit)

- Mutating methods require `X-CSRF-Token` == cookie `csrf_token` when cookie session is present.
- Exempt: `/api/auth/login`, `/logout`, `/token`, docs, health, uploads.
- FE: `frontend/utils/apiFetch.ts` — never bare `$fetch` for `/api/**`.
- `Authorization: Bearer ...` skips CSRF.

### Rate limit

| Path | Default |
|------|---------|
| `POST /api/auth/login` | 5 / min |
| `POST /api/auth/token` | 5 / min (same bucket as login) |
| `POST /api/auth/refresh` | 30 / min |
| `GET /api/auth/ws-ticket` | 20 / min |
| other `/api/*` | 120 / min |

Env: `RATE_LIMIT_LOGIN`, `RATE_LIMIT_REFRESH`, `RATE_LIMIT_WS_TICKET`, `RATE_LIMIT_API` (0 = off).

## Permissions

Catalog: `backend/app/core/permissions.py` (`SYSTEM_MODULES`).  
Key format: `action:resource` (e.g. `read:users`).

```python
current: CurrentUser = Depends(require_permission("read:users"))
```

Single-org: no `tenant_id` in JWT or queries.

## Public routes

No auth: `/api/auth/login`, `/logout`, `/refresh`, `/token`, `/api/docs`, `/api/openapi.json`, `/health`.

## Frontend

- `useApiFetch('/api/...')` relative — cookies + CSRF.
- Do **not** send `Authorization` from the browser for normal UI calls.
- Indicator cookie `auth_logged_in` for route middleware only.

## Timezone

- Backend stores UTC (`DateTime(timezone=True)` / `timestamptz`). Helpers: `app.core.timeutil`.
- API JSON datetimes use `...Z`. JWT `iat`/`exp` are unix seconds (UTC).
- Frontend: `composables/useDateTime.ts` + `utils/datetime.ts`.

## Checklist

- [ ] Protected route uses `require_permission` / `get_current_user`
- [ ] Browser auth never returns JWT in JSON
- [ ] API clients use `/api/auth/token` or Bearer — not cookie login
- [ ] Mutating actions call `write_system_log`
- [ ] Soft delete uses `deleted_at`, not hard delete
- [ ] No secrets in API responses / client storage
- [ ] New permissions added to `SYSTEM_MODULES`
