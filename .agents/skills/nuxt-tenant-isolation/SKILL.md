---
name: nuxt-tenant-isolation
description: >-
  Multi-tenant data isolation for this FastAPI monorepo.
  Covers tenant_id from JWT via CurrentUser, scoping SQLAlchemy queries, and common pitfalls.
  Use when adding tenant-scoped models, writing queries, debugging cross-tenant leaks, or reviewing security.
  Triggers on "tenant", "multi-tenant", "tenant_id", "data isolation", "tenant context", "cross-tenant".
---

# Tenant Isolation

## Flow

```
Login JWT { tenant_id, userId, type=access }
  → deps.get_current_user
  → CurrentUser.tenant_id
  → service queries .where(Model.tenant_id == current.tenant_id)
```

**Never** trust `tenant_id` from request body/headers for authorization. Use `current.tenant_id` from the verified access token.

## Service pattern

```python
async def list_things(db: AsyncSession, tenant_id: str, ...):
    filters = [Thing.tenant_id == tenant_id, Thing.deleted_at.is_(None)]
    ...
```

Route passes `current.tenant_id` into the service.

## Model convention

Tenant-scoped tables include:

```python
tenant_id: Mapped[str] = mapped_column(
    String(36), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False
)
```

Index `(tenant_id, ...)` for common filters.

## Exceptions

- **Tenants CRUD** — admin lists all non-deleted tenants (still permission-gated).
- **Login** — resolve workspace by name, then issue JWT with that tenant’s id.
- **SystemLog / RefreshToken** — still store `tenant_id`; write with actor’s tenant.

## Pitfalls

1. Forgetting `tenant_id` in `where` → cross-tenant leak.
2. Taking `tenant_id` from body for updates → privilege escalation.
3. Soft-deleted tenant still resolving on login → check `deleted_at` + `is_active`.

## Checklist

- [ ] `CurrentUser.tenant_id` used for scope
- [ ] Every tenant-owned query filters `tenant_id`
- [ ] Soft-delete filter combined when applicable
- [ ] No client-supplied tenant override for authz
