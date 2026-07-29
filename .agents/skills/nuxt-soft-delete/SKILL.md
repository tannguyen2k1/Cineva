---
name: nuxt-soft-delete
description: >-
  Soft delete pattern for this Nuxt 3 SaaS project.
  Covers Prisma model setup, SOFT_DELETE_MODELS registry, getTenantPrisma auto-filter,
  API delete handler pattern, list/count filtering, and uniqueness handling.
  Use when adding soft-deletable models, writing delete endpoints, or debugging
  why deleted records still appear.
  Triggers on "soft delete", "deletedAt", "xóa mềm", "SOFT_DELETE_MODELS",
  "hide deleted", "restore", "hard delete".
---

# Soft Delete Pattern

## How it works

Soft delete means setting `deletedAt` to a timestamp instead of removing the row.
The `getTenantPrisma` extension auto-filters soft-deleted rows on read operations.

```
DELETE request → API handler → updateMany({ deletedAt: new Date() })
                                  ↓
                            Row stays in DB, invisible to reads
```

## Prisma model setup

Every soft-deletable model needs:

```prisma
model Product {
  id        String    @id @default(uuid())
  name      String
  isActive  Boolean   @default(true)
  deletedAt DateTime?            // ← this enables soft delete

  tenant_id String
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@index([tenant_id, deletedAt]) // ← index for filtered queries
}
```

## Register in SOFT_DELETE_MODELS

In `server/utils/prisma.ts`, add the model name (PascalCase, matching Prisma model name):

```typescript
const SOFT_DELETE_MODELS = new Set(['User', 'Role', 'Tenant', 'Product']);
```

This tells `getTenantPrisma` to auto-inject `deletedAt: null` on:
- `findFirst`
- `findMany`
- `count`
- `aggregate`
- `groupBy`

Without this registration, deleted rows **will still appear** in queries.

## API delete handler

Use `updateMany` (not `delete` or `deleteMany`):

```typescript
export default defineEventHandler(async (event) => {
  try {
    requirePermission(event, 'delete:products')
    const tenant_id = event.context.tenant_id
    if (!tenant_id) throw createError({ statusCode: 400, statusMessage: 'Missing tenant_id' })

    const id = getRouterParam(event, 'id')
    if (!id) throw createError({ statusCode: 400, statusMessage: 'Missing id' })

    const db = getTenantPrisma(tenant_id)

    // Verify exists (auto-filtered: won't find already-deleted rows)
    const existing = await db.product.findFirst({ where: { id } })
    if (!existing) throw createError({ statusCode: 404, statusMessage: 'Not found' })

    // Soft delete
    await db.product.updateMany({
      where: { id },
      data: { deletedAt: new Date(), isActive: false }
    })

    await writeSystemLog({
      tenant_id,
      user_id: getActorUserId(event),
      action: 'DELETE_PRODUCT',
      resource: 'Product',
      details: { id, name: existing.name }
    })

    return { success: true }
  } catch (error: any) {
    console.error('API Error:', error)
    if (error.statusCode) throw error
    throw createError({ statusCode: 500, statusMessage: 'Lỗi hệ thống' })
  }
})
```

Key points:
- `updateMany` (not `update`) — works with non-unique where clauses
- Set both `deletedAt: new Date()` **and** `isActive: false` when model has `isActive`
- `findFirst` before delete to verify the record exists and get its name for logging

## Blocking delete when dependencies exist

If a model has child relations (e.g. Role → UserRole), check before deleting:

```typescript
const existing = await db.role.findFirst({
  where: { id },
  include: { _count: { select: { userRoles: true } } }
})

if (existing._count.userRoles > 0) {
  throw createError({
    statusCode: 400,
    statusMessage: t('roles.cannotDeleteInUse', { count: existing._count.userRoles, name: existing.name })
  })
}
```

## Business uniqueness with soft delete

DB-level `@@unique` will block reusing a name/username after soft delete.
Instead, check uniqueness **among non-deleted rows** in the API:

```typescript
// Check duplicate among active records (getTenantPrisma already filters deletedAt)
const duplicate = await db.product.findFirst({
  where: { name: body.name }
})
if (duplicate) {
  throw createError({ statusCode: 400, statusMessage: 'Name already exists' })
}
```

Avoid `@@unique` on fields that should be reusable after soft delete.
Use `@@index` instead, and enforce uniqueness in application code.

## Raw prisma queries (outside getTenantPrisma)

When using raw `prisma` directly (e.g. in auth middleware, login endpoint),
you **must** manually filter `deletedAt`:

```typescript
const user = await prisma.user.findFirst({
  where: { username, tenant_id, deletedAt: null }  // ← manual filter
})
```

## Currently soft-deletable models

| Model | `deletedAt` | `isActive` | Registered |
|-------|:-----------:|:----------:|:----------:|
| User | Yes | Yes | Yes |
| Role | Yes | No | Yes |
| Tenant | Yes | Yes | Yes |

## Checklist for new soft-deletable models

- [ ] `deletedAt DateTime?` added to Prisma model
- [ ] `@@index([tenant_id, deletedAt])` added
- [ ] Model name added to `SOFT_DELETE_MODELS` in `server/utils/prisma.ts`
- [ ] DELETE API uses `updateMany` with `deletedAt: new Date()`
- [ ] DELETE API also sets `isActive: false` if model has that field
- [ ] Business uniqueness checked in app code (not just `@@unique`)
- [ ] Raw `prisma` queries (outside `getTenantPrisma`) filter `deletedAt: null`
- [ ] `_count` check added if model has child relations that should block deletion
