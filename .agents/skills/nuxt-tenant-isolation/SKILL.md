---
name: nuxt-tenant-isolation
description: >-
  Multi-tenant data isolation pattern for this Nuxt 3 SaaS project.
  Covers how tenant_id flows from JWT through middleware to Prisma queries,
  the getTenantPrisma extension, Prisma model conventions, and common pitfalls.
  Use when adding tenant-scoped models, writing cross-tenant queries,
  debugging data leaks between tenants, or reviewing tenant security.
  Triggers on "tenant", "multi-tenant", "tenant_id", "data isolation",
  "getTenantPrisma", "tenant context", "cross-tenant".
---

# Tenant Isolation

## Architecture

```
JWT payload          Server middleware         API handler            Prisma
─────────────────    ──────────────────────    ──────────────────     ────────────────
{ tenant_id: "abc" } → event.context.tenant_id → getTenantPrisma(id) → auto-inject
                      event.context.user                                tenant_id in
                      event.context.permissions                         WHERE / data
```

**The tenant_id is NEVER provided by the client.** It comes exclusively from the
JWT payload, extracted and verified in `server/middleware/auth.ts`.

## How `getTenantPrisma` works

Location: `server/utils/prisma.ts`

`getTenantPrisma(tenant_id)` returns a Prisma client extension that automatically:

### 1. Injects `tenant_id` in WHERE clauses

For `findFirst`, `findMany`, `count`, `updateMany`, `deleteMany`:

```typescript
// You write:
db.user.findMany({ where: { isActive: true } })

// Prisma actually executes:
prisma.user.findMany({ where: { isActive: true, tenant_id: 'abc' } })
```

### 2. Injects `tenant_id` in CREATE data

For `create`, `createMany`:

```typescript
// You write:
db.user.create({ data: { username: 'john', password: '...' } })

// Prisma actually executes:
prisma.user.create({ data: { username: 'john', password: '...', tenant_id: 'abc' } })
```

### 3. Skips injection for Tenant model

Tenant queries (managing tenants themselves) are not scoped — they query across
all tenants by design.

### 4. Does NOT inject for `update`, `delete`, `findUnique`

These use `WhereUniqueInput` (primary key). Adding `tenant_id` would break the
unique constraint. **You must verify ownership with `findFirst` before calling these.**

## Standard API pattern

```typescript
export default defineEventHandler(async (event) => {
  try {
    requirePermission(event, 'update:products')

    // 1. Get tenant_id from context (populated by auth middleware)
    const tenant_id = event.context.tenant_id
    if (!tenant_id) {
      throw createError({ statusCode: 400, statusMessage: 'Missing tenant_id context' })
    }

    // 2. Use getTenantPrisma — all queries auto-scoped
    const db = getTenantPrisma(tenant_id)

    // 3. For update/delete by ID, verify ownership first
    const id = getRouterParam(event, 'id')
    const existing = await db.product.findFirst({ where: { id } })
    //                                          ↑ auto-adds tenant_id
    if (!existing) {
      throw createError({ statusCode: 404, statusMessage: 'Not found' })
    }

    // 4. Now safe to update (record confirmed to belong to this tenant)
    await db.product.update({
      where: { id },
      data: { name: body.name }
    })

    return { success: true }
  } catch (error: any) {
    // ...
  }
})
```

## Prisma model conventions

Every tenant-scoped model must have:

```prisma
model Product {
  // ... fields

  tenant_id String                        // ← required
  tenant    Tenant @relation(             // ← FK relation
    fields: [tenant_id],
    references: [id],
    onDelete: Cascade                     // ← cascade on tenant delete
  )

  @@index([tenant_id])                    // ← index for query performance
  @@index([tenant_id, name])              // ← compound indexes as needed
}
```

And add the reverse relation in `prisma/models/tenant.prisma`:

```prisma
model Tenant {
  // ...
  products Product[]                      // ← add this line
}
```

## Common pitfalls

### 1. Using raw `prisma` instead of `getTenantPrisma`

```typescript
// WRONG — no tenant scoping, data leak!
const users = await prisma.user.findMany()

// CORRECT
const db = getTenantPrisma(tenant_id)
const users = await db.user.findMany()
```

Raw `prisma` is only acceptable in:
- Auth middleware (verifying JWT, loading user)
- Login endpoint (finding user by username + tenant domain)
- System-level operations (managing tenants)
- `writeSystemLog` (uses raw prisma intentionally, logs have tenant_id in data)

### 2. Trusting client-supplied tenant_id

```typescript
// WRONG — client can spoof tenant
const tenant_id = getHeader(event, 'x-tenant-id')

// CORRECT — from JWT, verified by middleware
const tenant_id = event.context.tenant_id
```

### 3. Forgetting ownership check before update/delete

```typescript
// DANGEROUS — update doesn't auto-scope by tenant_id
await db.product.update({ where: { id }, data: { ... } })

// SAFE — verify first
const existing = await db.product.findFirst({ where: { id } })
if (!existing) throw createError({ statusCode: 404, ... })
await db.product.update({ where: { id }, data: { ... } })
```

### 4. Cross-tenant relation queries

When including relations, the parent query's tenant scope doesn't cascade:

```typescript
// The users include is NOT auto-scoped
const role = await db.role.findFirst({
  where: { id },
  include: { userRoles: { include: { user: true } } }
})
```

This is usually fine because foreign keys enforce the relation is within
the same tenant (if FK points to a tenant-scoped record). But be aware
when dealing with models that reference non-tenant-scoped tables.

## What the middleware provides

`server/middleware/auth.ts` sets on every authenticated request:

| Context field | Source | Type |
|--------------|--------|------|
| `event.context.tenant_id` | JWT `payload.tenant_id` | `string` |
| `event.context.user` | JWT + DB lookup | `{ userId, username }` |
| `event.context.permissions` | DB (role → permission) | `Set<string>` |

## Checklist

- [ ] New model has `tenant_id String` + `Tenant` relation + `onDelete: Cascade`
- [ ] `@@index([tenant_id])` added (+ compound indexes as needed)
- [ ] Reverse relation added to `Tenant` model
- [ ] API uses `getTenantPrisma(event.context.tenant_id)`, not raw `prisma`
- [ ] `update`/`delete` by ID preceded by `findFirst` ownership check
- [ ] `tenant_id` comes from `event.context.tenant_id`, never from client headers
- [ ] Raw `prisma` usage (if any) is justified and documented
