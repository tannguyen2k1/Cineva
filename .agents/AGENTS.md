# Admin Pro — Project Rules (Nuxt frontend + FastAPI backend)

## 1. Architecture Overview

Monorepo:

```
frontend/   Nuxt 4 UI (Vue 3, Element Plus, Pinia, i18n)
backend/    FastAPI + SQLAlchemy 2 + Alembic + Scalar docs
```

- **UI**: Element Plus, CSS Modules, `@element-plus/icons-vue`
- **State**: Pinia (`frontend/stores/`)
- **API**: FastAPI under `backend/app/` — layers: `api/routes` → `services` → `repositories` → `models` / `schemas`
- **DB**: PostgreSQL via SQLAlchemy 2 (async) + Alembic migrations
- **Multi-tenancy**: RBAC with `tenant_id` from JWT only (never from client headers)

## 2. Frontend structure (`frontend/`)

- **Pages**: `frontend/pages/` — see `skills/nuxt-crud-page`
- **Components**: `frontend/components/` — see `skills/nuxt-component`
- **i18n**: `frontend/i18n/locales/` — see `skills/nuxt-i18n`
- **Mobile**: see `skills/nuxt-mobile-patterns`
- **API calls**: relative `$fetch('/api/...')` — Nuxt proxies `/api` and `/uploads` to FastAPI (`NUXT_API_PROXY`). Do **not** send `Authorization` / `x-tenant-id` (cookies).
- **Styling**: ALWAYS CSS Modules (`.module.scss`). NEVER `<style scoped>`.

## 3. Backend structure (`backend/`)

| Layer | Path | Role |
|-------|------|------|
| Routes | `app/api/routes/` | HTTP only — validate, call service, return JSON |
| Deps | `app/api/deps.py` | `get_current_user`, `require_permission` |
| Services | `app/services/` | Business logic, orchestration, system log |
| Repositories | `app/repositories/` | SQLAlchemy queries only (one file per aggregate) |
| Models | `app/models/<name>.py` | One SQLAlchemy model per file |
| Schemas | `app/schemas/<name>.py` | Pydantic I/O split by domain |
| Core | `app/core/` | Settings, JWT, permissions, error handlers |
| Docs | Scalar at `/api/docs`, OpenAPI at `/api/openapi.json` |

New endpoints: follow `skills/fastapi-endpoint`.

## 4. Auth & security (CRITICAL)

- Cookies: `auth_token` (15m httpOnly), `refresh_token` (7d, path `/api/auth`), `auth_logged_in` (readable)
- JWT HS256 (`JWT_SECRET`); access claims: `type=access`, `sub`/`userId`, `tenant_id`, `jti`
- Refresh tokens are **persisted** (table `refresh_tokens`, SHA-256 hash): rotation on every `/api/auth/refresh`, family revoke on reuse, revoke on logout / password change
- Access JWT `jti` denylist (`revoked_access_tokens`) on logout / refresh rotation
- CSRF double-submit: cookie `csrf_token` + header `X-CSRF-Token` on cookie-authenticated mutating requests
- Protected routes: `Depends(require_permission("action:resource"))` — rejects non-access token types
- Public: `/api/auth/login|logout|refresh`, `/api/docs`, `/api/openapi.json`, `/health`
- Soft delete: `deleted_at` on User / Role / Tenant — never hard-delete in normal CRUD
- System log: `write_system_log` after successful mutating actions (non-fatal)
- Errors: FastAPI returns `{ statusCode, statusMessage, message }` for UI compatibility

## 5. Permissions

Catalog in `backend/app/core/permissions.py` (`SYSTEM_MODULES`). Runtime key: `action:resource` (e.g. `read:users`).  
Sync with `ensure_system_permissions` on login / tenant bootstrap. Admin role always gets full catalog.

## 6. Internationalization

- `@nuxtjs/i18n` in frontend. Default `vi`. Keep `vi.json` / `en.json` in sync.
- Never hardcode UI copy — use `t()`.

## 7. Docker

`docker-compose.yml`: `db` (Postgres **5432**), `api` (8000), `web` (3000).  
Local backend: `DATABASE_URL=...@localhost:5432/multi_tenant_db`.

## 8. Skills map

| Need | Skill |
|------|--------|
| New API / OpenAPI | `fastapi-endpoint` |
| New module E2E | `nuxt-new-module` |
| Auth / security | `nuxt-security` |
| Soft delete | `nuxt-soft-delete` |
| Tenant scope | `nuxt-tenant-isolation` |
| Audit log | `nuxt-system-log` |
| WebSocket | `nuxt-websocket` |
| File upload | `nuxt-file-upload` |
| CRUD UI page | `nuxt-crud-page` |
| Vue component | `nuxt-component` |
| i18n | `nuxt-i18n` |
| Mobile UI | `nuxt-mobile-patterns` |

**Legacy (do not use):** `nuxt-api-endpoint`, `prisma-cli`, `prisma-client-api`, `prisma-upgrade-v7`.
