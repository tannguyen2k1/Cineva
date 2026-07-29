---
name: nuxt-system-log
description: >-
  System logging pattern for this Nuxt 3 SaaS project.
  Covers when to log, the writeSystemLog API, action naming conventions,
  the SystemLog Prisma model, and how logs are displayed.
  Use when adding logging to new endpoints, reviewing log coverage,
  or debugging missing audit trail entries.
  Triggers on "system log", "audit log", "writeSystemLog", "nhật ký",
  "action log", "SystemLog", "getActorUserId".
---

# System Logging

## Purpose

Every mutating action (create, update, delete, login, assign permissions) must be
logged for audit trail. Logs are tenant-scoped and viewable at `/systems/logs`.

## Prisma model

```prisma
model SystemLog {
  id       String  @id @default(uuid())
  action   String  // e.g. "CREATE_USER", "LOGIN"
  resource String? // e.g. "User", "Role"
  details  String? // JSON string for extra data

  tenant_id String
  user_id   String?
  createdAt DateTime @default(now())

  tenant Tenant @relation(fields: [tenant_id], references: [id], onDelete: Cascade)
  user   User?  @relation(fields: [user_id], references: [id], onDelete: SetNull)

  @@index([tenant_id])
  @@index([tenant_id, createdAt])
}
```

## API: `writeSystemLog`

Location: `server/utils/systemLog.ts`

```typescript
import { getActorUserId, writeSystemLog } from '../../utils/systemLog'
```

### Signature

```typescript
writeSystemLog({
  tenant_id: string,          // required — from event.context.tenant_id
  user_id?: string | null,    // from getActorUserId(event)
  action: string,             // e.g. "CREATE_USER"
  resource?: string | null,   // e.g. "User"
  details?: string | Record<string, unknown> | null
})
```

### `getActorUserId`

Extracts the current user's ID from `event.context.user`:

```typescript
const userId = getActorUserId(event) // returns string | null
```

## Usage in API handlers

Call `writeSystemLog` **after** the successful mutation, inside the try block:

```typescript
export default defineEventHandler(async (event) => {
  try {
    requirePermission(event, 'create:products')
    const tenant_id = event.context.tenant_id

    const body = await readBody(event)
    const db = getTenantPrisma(tenant_id)

    const product = await db.product.create({
      data: { name: body.name, tenant_id }
    })

    // Log after success
    await writeSystemLog({
      tenant_id,
      user_id: getActorUserId(event),
      action: 'CREATE_PRODUCT',
      resource: 'Product',
      details: { id: product.id, name: product.name }
    })

    return { success: true, data: product }
  } catch (error: any) {
    // ...
  }
})
```

## Action naming convention

Format: `VERB_RESOURCE` (UPPER_SNAKE_CASE)

| Action | When |
|--------|------|
| `CREATE_USER` | User created |
| `UPDATE_USER` | User updated |
| `DELETE_USER` | User soft-deleted |
| `CREATE_ROLE` | Role created |
| `UPDATE_ROLE` | Role updated |
| `DELETE_ROLE` | Role soft-deleted |
| `ASSIGN_PERMISSIONS` | Role permissions updated |
| `CREATE_TENANT` | Tenant created |
| `UPDATE_TENANT` | Tenant updated |
| `DELETE_TENANT` | Tenant soft-deleted |
| `LOGIN` | User logged in |

For new modules, follow the same pattern: `CREATE_PRODUCT`, `UPDATE_ORDER`, etc.

## Resource naming

Use the **PascalCase Prisma model name**: `User`, `Role`, `Tenant`, `Product`.
This matches the `resource` column in the logs table and is used for filtering
in the logs UI.

## Details field

Pass a plain object — it will be JSON-stringified automatically:

```typescript
// Object (recommended)
details: { id: product.id, name: product.name, price: product.price }

// String (also accepted)
details: 'Manual description of what happened'

// Null (when no extra info needed)
details: null
```

Keep details concise. Include the record's `id` and key identifying fields
(name, username, etc.) for traceability.

## Error handling

`writeSystemLog` catches its own errors internally and logs to console.
It will **never** cause the main API request to fail:

```typescript
export async function writeSystemLog(input: SystemLogInput) {
  try {
    await prisma.systemLog.create({ data: { ... } })
  } catch (err) {
    console.error('[systemLog]', err)  // silent fail
  }
}
```

Do **not** wrap `writeSystemLog` calls in additional try/catch.

## When to log

| Operation | Log? | Notes |
|-----------|:----:|-------|
| Create | Yes | |
| Update | Yes | |
| Soft delete | Yes | |
| Login | Yes | Logged in login.post.ts |
| Read / List | No | Too noisy |
| Failed attempts | No | Error is thrown, no log needed |
| Status toggle | Yes | Considered an update |
| Assign permissions | Yes | |

## Checklist for new endpoints

- [ ] `writeSystemLog` called after successful mutation
- [ ] `action` follows `VERB_RESOURCE` format (UPPER_SNAKE_CASE)
- [ ] `resource` matches PascalCase Prisma model name
- [ ] `details` includes record `id` and key identifying fields
- [ ] `user_id` from `getActorUserId(event)`
- [ ] `tenant_id` from `event.context.tenant_id`
- [ ] No extra try/catch around `writeSystemLog` (it handles errors internally)
- [ ] Read-only endpoints (GET) do NOT log
