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
- **Single-org**: global RBAC (no multi-tenant / no `tenant_id`)

## 2. Frontend structure (`frontend/`)

- **Pages**: `frontend/pages/` — see `skills/nuxt-crud-page`
- **Components**: `frontend/components/` — see `skills/nuxt-component`
- **i18n**: `frontend/i18n/locales/` — see `skills/nuxt-i18n`
- **Mobile**: see `skills/nuxt-mobile-patterns`
- **API calls**: relative `useApiFetch('/api/...')` (CSRF header + 401 refresh, from `utils/apiFetch.ts`) — Nuxt proxies `/api` and `/uploads` to FastAPI (`NUXT_API_PROXY`). Never bare `$fetch` for `/api/**`. Do **not** send `Authorization` (cookies).
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

### Layer boundaries

- **Routes** handle HTTP/dependencies only; never query the database or commit.
- **Services** own business rules, `HTTPException`, orchestration, audit logging, and
  transaction boundaries (`commit`). Do not use SQLAlchemy `select`/`update`/`delete`
  or `db.execute` directly; call repositories.
- **Repositories** own persistence only: SQLAlchemy queries/writes, eager-loading,
  pagination, and technical filters such as `deleted_at IS NULL`.
- Repository methods may use domain-intent names such as `revoke_family` or
  `set_tokens_invalid_before`, but must not enforce permissions, raise HTTP errors,
  write system logs, or commit. Use `flush` when generated values are needed.
- A service coordinates multiple repositories when one use case spans aggregates.

New endpoints: follow `skills/fastapi-endpoint`.

## 4. Auth & security (CRITICAL)

- Cookies: `auth_token` (15m httpOnly), `refresh_token` (7d, path `/api/auth`), `auth_logged_in` (readable)
- JWT HS256 (`JWT_SECRET`); access claims: `type=access`, `sub`/`userId`, `jti`
- Refresh tokens are **persisted** (table `refresh_tokens`, SHA-256 hash): rotation on every `/api/auth/refresh`, family revoke on reuse, revoke on logout / password change
- Access JWT `jti` denylist (`revoked_access_tokens`) on logout / refresh rotation
- CSRF double-submit: cookie `csrf_token` + header `X-CSRF-Token` on cookie-authenticated mutating requests; requests with `Authorization: Bearer` skip CSRF
- Scalar (`/api/docs`): login/refresh returns `data.accessToken`; Authorize with HTTP Bearer (`persist_auth` enabled)
- Rate limit (per IP, in-memory): login 5/min, refresh 30/min, ws-ticket 20/min, other `/api/*` 120/min — env `RATE_LIMIT_*`
- Protected routes: `Depends(require_permission("action:resource"))` — rejects non-access token types
- Public: `/api/auth/login|logout|refresh`, `/api/docs`, `/api/openapi.json`, `/health`
- Soft delete: `deleted_at` on User / Role — never hard-delete in normal CRUD
- System log: `write_system_log` after successful mutating actions (non-fatal)
- Errors: FastAPI returns `{ statusCode, statusMessage, message }` for UI compatibility. On 500, non-production (`ENVIRONMENT` ≠ `production`) also includes `debug: { type, detail, traceback }`; production stays generic.

## 5. DateTime / timezone (CRITICAL)

**Contract:** DB + API = UTC · UI = local browser time.

### Backend

| Layer | Rule |
|-------|------|
| Column | Always `DateTime(timezone=True)` → Postgres `timestamptz`. Never naive `DateTime()`. |
| Naming | snake_case: `created_at`, `updated_at`, `deleted_at`, `expires_at`, … |
| Write “now” | `from app.core.timeutil import utcnow` — **never** `datetime.now()` without tz |
| Compare / normalize | `as_utc()`, `unix_ts()` / `from_unix_ts()` for JWT |
| API JSON | UTC ISO ending with `Z` (`to_iso_utc` / `register_fastapi_utc_json`) |
| Date filters | Accept ISO from FE via `parse_filter_instant` (full ISO preferred) |

Typical model stamp:

```python
created_at: Mapped[datetime] = mapped_column(
    DateTime(timezone=True), server_default=func.now(), nullable=False
)
updated_at: Mapped[datetime] = mapped_column(
    DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
)
```

### Frontend

| Need | Use |
|------|-----|
| Show datetime / date | `useDateTime()` → `formatDateTime` / `formatDate` |
| Parse API string | `parseApiDate` (handles `Z` / `+00:00` / naive-as-UTC) |
| Date-range filter | `localDayStartToIso` / `localDayEndToIso` then send as `startDate`/`endDate` |
| Forbidden | `new Date(apiString).toLocaleString(...)` ad-hoc in pages |

Helpers: `frontend/composables/useDateTime.ts`, `frontend/utils/datetime.ts`.

## 6. Permissions

Catalog in `backend/app/core/permissions.py` (`SYSTEM_MODULES`). Runtime key: `action:resource` (e.g. `read:users`).  
Sync with `ensure_system_permissions` on login / seed. Admin role always gets full catalog.

## 7. Internationalization

- `@nuxtjs/i18n` in frontend. Default `vi`. Keep `vi.json` / `en.json` in sync.
- Never hardcode UI copy — use `t()`.

## 8. Docker

`docker-compose.yml`: `db` (Postgres **5432**), `api` (8000), `web` (3000).  
Local backend: `DATABASE_URL=...@localhost:5432/app_db`.

## 9. Skills map

| Need | Skill |
|------|--------|
| New API / OpenAPI | `fastapi-endpoint` |
| New module E2E | `nuxt-new-module` |
| Auth / security | `nuxt-security` |
| Soft delete | `nuxt-soft-delete` |
| Audit log | `nuxt-system-log` |
| WebSocket | `nuxt-websocket` |
| File upload | `nuxt-file-upload` |
| CRUD UI page | `nuxt-crud-page` |
| Vue component | `nuxt-component` |
| i18n | `nuxt-i18n` |
| Mobile UI | `nuxt-mobile-patterns` |

**Legacy (do not use):** `nuxt-api-endpoint`, `nuxt-tenant-isolation`, `prisma-cli`, `prisma-client-api`, `prisma-upgrade-v7`.
