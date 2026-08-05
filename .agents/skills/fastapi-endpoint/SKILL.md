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
  api/routes/{resource}.py   # HTTP handlers
  services/{resource}.py     # business logic
  models/entities.py         # SQLAlchemy (or split files)
  schemas/                   # Pydantic I/O
  api/deps.py                # get_current_user, require_permission
```

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

## Service rules

1. Scope queries with `tenant_id` from `CurrentUser` (never from request body for authz).
2. Soft-deletable models: filter `deleted_at.is_(None)`; delete = set `deleted_at` (+ `is_active=False` when present).
3. After successful mutate, call `write_system_log(...)` (swallows errors).
4. Raise `HTTPException(status_code=..., detail="...")` — main app maps to `statusMessage`.
5. Response shape: `{ "success": True, "data": ..., "total"?, "page"?, "pageSize"? }`.

## Permissions catalog

If a new module needs permissions, add to `SYSTEM_MODULES` in `app/core/permissions.py`, then `ensure_system_permissions` will sync rows + Admin role.

## OpenAPI / Scalar

- Tags on `APIRouter(..., tags=["Things"])` group docs in `/api/docs`.
- Public auth routes: no `require_permission`; do not require Bearer.
- Docs UI: Scalar at `/api/docs` (`scalar-fastapi`). Spec: `/api/openapi.json`.

## Checklist

- [ ] Router registered in `app/api/router.py`
- [ ] `require_permission("action:resource")` on protected routes
- [ ] Tenant scoped queries + soft-delete filters
- [ ] Pydantic schemas for body / documented fields
- [ ] `write_system_log` on create/update/delete
- [ ] Permission keys added to `SYSTEM_MODULES` if new module
- [ ] Frontend paths still use `/api/...` (Nuxt proxy)
