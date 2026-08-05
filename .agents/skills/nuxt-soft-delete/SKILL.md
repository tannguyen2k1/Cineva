---
name: nuxt-soft-delete
description: >-
  Soft delete pattern for this FastAPI + SQLAlchemy monorepo.
  Covers deleted_at columns, list filters, delete handlers, and uniqueness among active rows.
  Use when adding soft-deletable models, writing delete endpoints, or debugging deleted rows still appearing.
  Triggers on "soft delete", "deletedAt", "deleted_at", "xóa mềm", "hide deleted", "restore", "hard delete".
---

# Soft Delete

## Model

Use snake_case column `deleted_at` (nullable timestamptz):

```python
deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
```

Typical soft-delete models: `User`, `Role`, `Tenant` (and any new business entity that should be recoverable).

## List / count / auth

Always filter active rows:

```python
.where(Model.tenant_id == tenant_id, Model.deleted_at.is_(None))
```

## Delete handler

```python
from app.core.timeutil import utcnow

row.deleted_at = utcnow()
if hasattr(row, "is_active"):
    row.is_active = False
await db.commit()
```

Do **not** `db.delete(row)` for normal CRUD.
Do **not** use `datetime.now()` without timezone — always `utcnow()`.

## Uniqueness

Check uniqueness among **non-deleted** rows only:

```python
select(User).where(
    User.tenant_id == tenant_id,
    User.username == name,
    User.deleted_at.is_(None),
)
```

Avoid relying on DB `UNIQUE(username)` alone if soft-deleted rows would block reuse.

## Checklist

- [ ] `deleted_at` on model + Alembic migration
- [ ] All reads filter `deleted_at.is_(None)`
- [ ] Delete sets `deleted_at` (+ `is_active=False` when present)
- [ ] Uniqueness checks ignore soft-deleted rows
