---
name: nuxt-new-module
description: >-
  End-to-end guide for adding a complete new module to this monorepo.
  Backend: FastAPI (SQLAlchemy model → Alembic → permissions → routes/services).
  Frontend: CRUD page → i18n → sidebar.
  Use when creating a new resource, adding a feature module, or scaffolding CRUD.
  Triggers on "new module", "add module", "add feature", "new resource", "scaffold",
  "tạo module", "thêm chức năng".
---

# Adding a New Module (End-to-End)

## Overview

```
1. SQLAlchemy model       → backend/app/models/<name>.py (one file per model)
2. Alembic migration      → backend/alembic/versions/
3. Permissions catalog    → backend/app/core/permissions.py
4. Schema + repository    → backend/app/schemas/<name>.py, app/repositories/<name>.py
5. Service + API routes   → backend/app/services/, app/api/routes/ (+ router.py)
6. CRUD page              → frontend/pages/ (see nuxt-crud-page)
7. i18n                   → frontend/i18n/locales/vi.json
8. Sidebar                → frontend layout / nav
```

Do **not** dump models into `entities.py` or all schemas into one bag file — split by domain.

Follow `skills/fastapi-endpoint` for API details and `skills/nuxt-crud-page` for UI.

## Permissions

Add module to `SYSTEM_MODULES` in `backend/app/core/permissions.py`.
`ensure_system_permissions` syncs DB rows and Admin role automatically.

## Soft delete

If the resource is soft-deletable: `deleted_at` column, list filters `deleted_at IS NULL`,
delete handler sets `deleted_at` via `utcnow()` (and `is_active=False` when applicable).

## DateTime

Follow **AGENTS.md §5**:

- Model: `DateTime(timezone=True)` only
- Write now: `from app.core.timeutil import utcnow`
- FE columns: `useDateTime().formatDate` / `formatDateTime` — never raw `new Date(api)`
