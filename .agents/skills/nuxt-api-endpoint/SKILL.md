---
name: nuxt-api-endpoint
description: >-
  Template and checklist for creating new Nuxt server API endpoints in this project.
  Covers the standard skeleton: permission check, tenant scoping, input validation,
  Prisma query, system log, error handling, response format, and OpenAPI docs metadata.
  Use when creating a new API route, adding CRUD endpoints, or scaffolding server handlers.
  Triggers on "create API", "new endpoint", "server/api", "add route", "CRUD API", "openapi", "api docs".
---

# Creating API Endpoints

## File naming

Follow Nuxt 3 convention under `server/api/`:

```
server/api/{resource}/index.get.ts      → GET    /api/{resource}
server/api/{resource}/index.post.ts     → POST   /api/{resource}
server/api/{resource}/[id].put.ts       → PUT    /api/{resource}/:id
server/api/{resource}/[id].delete.ts    → DELETE /api/{resource}/:id
```

## Standard skeleton

Every endpoint follows this structure:

```typescript
import { getTenantPrisma } from '../../utils/prisma'
import { getActorUserId, writeSystemLog } from '../../utils/systemLog'
import { requirePermission } from '../../utils/requirePermission'

export default defineEventHandler(async (event) => {
  try {
    // 1. Permission check
    requirePermission(event, 'action:resource')

    // 2. Tenant scope
    const tenant_id = event.context.tenant_id
    if (!tenant_id) {
      throw createError({ statusCode: 400, statusMessage: 'Missing tenant_id context' })
    }

    // 3. Input (for POST/PUT)
    const body = await readBody(event)
    const name = String(body?.name || '').trim()
    if (!name) {
      throw createError({ statusCode: 400, statusMessage: 'Name is required' })
    }

    // 4. DB operation
    const db = getTenantPrisma(tenant_id)
    const result = await db.myModel.create({
      data: { name, tenant_id }
    })

    // 5. System log (mutating actions only)
    await writeSystemLog({
      tenant_id,
      user_id: getActorUserId(event),
      action: 'CREATE_THING',
      resource: 'Thing',
      details: { id: result.id, name: result.name }
    })

    // 6. Response
    return { success: true, data: result }
  } catch (error: any) {
    console.error('API Error:', error)
    if (error.statusCode) throw error
    throw createError({
      statusCode: 500,
      statusMessage: 'Lỗi hệ thống',
      message: error.message || 'Đã có lỗi xảy ra',
    })
  }
})
```

## GET list with pagination

```typescript
const query = getQuery(event)
const page = Number(query.page) || 1
const pageSize = Number(query.pageSize) || 10
const search = query.search as string

const db = getTenantPrisma(tenant_id)
const where: any = {}

if (search) {
  where.OR = [
    { name: { contains: search, mode: 'insensitive' } }
  ]
}

const [data, total] = await Promise.all([
  db.myModel.findMany({
    where,
    skip: (page - 1) * pageSize,
    take: pageSize,
    orderBy: { createdAt: 'desc' }
  }),
  db.myModel.count({ where })
])

return { success: true, data, total, page, pageSize }
```

## DELETE (soft delete)

```typescript
const id = getRouterParam(event, 'id')
if (!id) throw createError({ statusCode: 400, statusMessage: 'Missing id' })

const db = getTenantPrisma(tenant_id)

await db.myModel.updateMany({
  where: { id },
  data: { deletedAt: new Date(), isActive: false }
})

await writeSystemLog({
  tenant_id,
  user_id: getActorUserId(event),
  action: 'DELETE_THING',
  resource: 'Thing',
  details: { id }
})

return { success: true }
```

## OpenAPI docs (required for every new endpoint)

Nitro auto-generates the spec from `defineRouteMeta({ openAPI: ... })` on each handler.
Config lives in `nuxt.config.ts` → `nitro.openAPI` (Scalar UI at `/api/docs`, spec at `/api/openapi.json`).

**Every new endpoint must include `defineRouteMeta` before `defineEventHandler`.**

### Protected endpoint (most routes)

```typescript
defineRouteMeta({
  openAPI: {
    tags: ['Products'],  // PascalCase module name — groups routes in /api/docs
    description: 'List products in the current tenant (paginated). Requires `read:products`.',
    parameters: [  // GET query params only
      { in: 'query', name: 'page', schema: { type: 'integer', default: 1 } },
      { in: 'query', name: 'pageSize', schema: { type: 'integer', default: 10 } },
      { in: 'query', name: 'search', schema: { type: 'string' } }
    ],
    security: [{ bearerAuth: [] }]  // omit for public routes
  }
})
```

### POST / PUT with body

```typescript
defineRouteMeta({
  openAPI: {
    tags: ['Products'],
    description: 'Create a product. Requires `create:products`.',
    requestBody: {
      required: true,
      content: {
        'application/json': {
          schema: {
            type: 'object',
            required: ['name'],
            properties: {
              name: { type: 'string' },
              price: { type: 'number' }
            }
          }
        }
      }
    },
    security: [{ bearerAuth: [] }]
  }
})
```

### Nested resource (e.g. role permissions)

File: `server/api/roles/[id]/permissions.put.ts` → `PUT /api/roles/:id/permissions`

Use the **parent module tag** (`Roles`), not a separate `Permissions` tag:

```typescript
defineRouteMeta({
  openAPI: {
    tags: ['Roles'],
    description: 'Replace permissions assigned to a role. Requires `update:roles`.',
    security: [{ bearerAuth: [] }]
  }
})
```

Catalog-only routes (`GET /api/permissions`) use tag `Permissions`.

### Public / auth routes

- **Do not** set `security` on login, register, refresh, logout.
- `bearerAuth` scheme is defined once in `server/api/auth/login.post.ts` via `openAPI.$global` — do not duplicate it.
- New public routes must be added to `PUBLIC_EXACT` or `PUBLIC_PREFIX` in `server/middleware/auth.ts`.

### Tag naming

| Module | Tag |
|--------|-----|
| users | `Users` |
| roles (+ nested permissions) | `Roles` |
| permissions catalog | `Permissions` |
| tenants | `Tenants` |
| logs | `Logs` |
| dashboard | `Dashboard` |
| auth | `Auth` |
| new module | PascalCase of resource name |

### Testing via docs UI

1. Login at `/login` in the browser (cookies are sent automatically).
2. Open `/api/docs` — protected endpoints work without manually setting Bearer.
3. Login endpoint is hard to test in Scalar (Turnstile) — use the UI instead.

## Checklist

- [ ] File named `[name].[method].ts` under correct folder
- [ ] `requirePermission()` called with matching permission key
- [ ] `tenant_id` extracted from `event.context.tenant_id` (never from header)
- [ ] Input validated and sanitized (trim strings, check required fields)
- [ ] Prisma queries scoped via `getTenantPrisma(tenant_id)`
- [ ] Soft delete uses `updateMany` with `deletedAt` (not hard delete)
- [ ] `writeSystemLog()` called for create/update/delete actions
- [ ] Response format: `{ success: true, data, total?, page?, pageSize? }`
- [ ] try/catch with standard error re-throw pattern
- [ ] If new permission needed, add to `SYSTEM_MODULES` in `systemPermissions.ts`
- [ ] `defineRouteMeta({ openAPI: { tags, description, security?, parameters?, requestBody? } })` added
- [ ] Public route (if any) registered in `server/middleware/auth.ts` `PUBLIC_EXACT` or `PUBLIC_PREFIX`
