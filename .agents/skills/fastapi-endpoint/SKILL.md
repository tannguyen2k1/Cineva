---
name: fastapi-endpoint
description: >-
  Template for creating FastAPI endpoints in this monorepo backend.
  Covers router → service → SQLAlchemy model → Pydantic schema, auth deps,
  tenant scoping, soft delete, system log, and Scalar/OpenAPI tags.
  Use when creating a new API route, adding CRUD endpoints, or scaffolding
  backend handlers. Triggers on "create API", "new endpoint", "FastAPI",
  "backend route", "CRUD API", "openapi", "api docs".
---

# Creating FastAPI Endpoints

## Layout

```
backend/app/
  api/routes/{resource}.py      # HTTP handlers
  services/{resource}.py        # business logic / orchestration
  repositories/{resource}.py    # SQLAlchemy queries only
  models/{resource}.py          # one SQLAlchemy model per file
  schemas/{resource}.py         # Pydantic I/O (split by domain)
  api/deps.py                   # get_current_user, require_permission
```

Do **not** use a monolithic `entities.py` or a single schemas bag — one file per model/domain.
Register the router in `app/api/router.py` under prefix `/api`.

## Route skeleton

```python
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser, require_permission
from app.db.session import get_db
from app.schemas import ThingCreate
from app.services import things as things_service

router = APIRouter(prefix="/things", tags=["Things"])


@router.get("")
async def list_things(
    page: int = 1,
    pageSize: int = 10,
    search: str | None = None,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("read:things")),
):
    return await things_service.list_things(
        db, current.tenant_id, page=page, page_size=pageSize, search=search
    )


@router.post("")
async def create_thing(
    body: ThingCreate,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("create:things")),
):
    return await things_service.create_thing(db, current.tenant_id, current.id, body)
```

## Layer rules

1. Routes call services; services call repositories (no `select()` in routes).
2. Scope queries with `tenant_id` from `CurrentUser` (never from request body for authz).
3. Soft-deletable models: filter `deleted_at.is_(None)`; delete = set `deleted_at` (+ `is_active=False` when present).
4. After successful mutate, call `write_system_log(...)` (swallows errors).
5. Raise `HTTPException(status_code=..., detail="...")` — `app.core.errors` maps to Nuxt shape.
6. Response shape: `{ "success": True, "data": ..., "total"?, "page"?, "pageSize"? }`.
7. Do **not** leak raw SQL / stack traces to the client; unexpected errors → generic 500 `statusMessage`.

## Error handling (Nuxt-compatible)

All API errors must look like:

```json
{ "statusCode": 400, "statusMessage": "…", "message": "…" }
```

Handlers live in `backend/app/core/errors.py` (registered from `main.py`):

| Exception | Status | Notes |
|-----------|--------|--------|
| `HTTPException` | as raised | Business / auth errors from services |
| `RequestValidationError` | 422 | `"Dữ liệu không hợp lệ"` + `errors` |
| `IntegrityError` | 409 | Default conflict message |
| `SQLAlchemyError` | 500 | Generic DB message (logged) |
| `Exception` | 500 | Generic system message (logged) |

Frontend reads `err.data?.statusMessage`. Prefer raising `HTTPException` in services for known cases; rely on global handlers for the rest (no need for try/catch on every route like Nitro — same outcome).

`get_db` rolls back the session on any exception.

## Permissions catalog

If a new module needs permissions, add to `SYSTEM_MODULES` in `app/core/permissions.py`, then `ensure_system_permissions` will sync rows + Admin role.

## OpenAPI / Scalar

- Tags on `APIRouter(..., tags=["Things"])` group docs in `/api/docs`.
- Public auth routes: no `require_permission`; do not require Bearer.
- Docs UI: Scalar at `/api/docs` (`scalar-fastapi`). Spec: `/api/openapi.json`.

## Auth reminder

Access JWT must have `type=access`. Refresh is DB-backed with rotation — see `skills/nuxt-security`.
Do not reintroduce Nitro/`server/api` handlers.

## Checklist

- [ ] Router registered in `app/api/router.py`
- [ ] `require_permission("action:resource")` on protected routes
- [ ] Tenant scoped queries + soft-delete filters
- [ ] Pydantic schemas for body / documented fields
- [ ] `write_system_log` on create/update/delete
- [ ] Permission keys added to `SYSTEM_MODULES` if new module
- [ ] Frontend paths still use `/api/...` (Nuxt proxy)
