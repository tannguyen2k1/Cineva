---
name: nuxt-new-module
description: >-
  End-to-end guide for adding a complete new module (feature) to this Nuxt 3 SaaS project.
  Covers every step from Prisma schema → migration → permissions → API endpoints → CRUD page
  → i18n → sidebar entry → system logging.
  Use when creating a new resource, adding a feature module, or scaffolding a complete CRUD flow.
  Triggers on "new module", "add module", "add feature", "new resource", "scaffold",
  "tạo module", "thêm chức năng".
---

# Adding a New Module (End-to-End)

This guide walks through every file you need to touch when adding a new module
(e.g. "products", "orders", "customers") to the project.

## Overview of steps

```
1. Prisma model            → prisma/models/{resource}.prisma
2. Soft delete registry    → server/utils/prisma.ts  (SOFT_DELETE_MODELS)
3. DB migration            → npx prisma migrate dev
4. Permissions catalog     → server/utils/systemPermissions.ts
5. API endpoints           → server/api/{resource}/*.ts  (4 files)
6. CRUD page               → pages/{section}/{resource}/index.vue + .module.scss
7. i18n keys               → i18n/locales/vi.json + en.json
8. Sidebar (desktop)       → components/DesktopSidebar/index.vue
9. Mobile menu drawer      → components/MobileMenuDrawer/index.vue
10. Page title mapping     → layouts/default.vue  (pageTitleKeys)
11. Verify & test
```

---

## Step 1: Prisma model

Create `prisma/models/{resource}.prisma`:

```prisma
model Product {
  id        String    @id @default(uuid())
  name      String
  isActive  Boolean   @default(true)
  deletedAt DateTime?

  // Base fields (every tenant-scoped model needs these)
  tenant_id String
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  // Relations
  tenant Tenant @relation(fields: [tenant_id], references: [id], onDelete: Cascade)

  @@index([tenant_id])
  @@index([tenant_id, isActive])
  @@index([tenant_id, deletedAt])
}
```

Rules:
- `id` is always UUID.
- `tenant_id` + relation to `Tenant` is mandatory for tenant isolation.
- `deletedAt DateTime?` enables soft delete.
- Add `@@index` for common query patterns.
- If the model references another tenant-scoped model, add the FK + relation.
- Add `products Product[]` to the `Tenant` model in `prisma/models/tenant.prisma`.

## Step 2: Register in soft delete models

If the model has `deletedAt`, add it to `SOFT_DELETE_MODELS` in `server/utils/prisma.ts`:

```typescript
const SOFT_DELETE_MODELS = new Set(['User', 'Role', 'Tenant', 'Product']);
```

This ensures `getTenantPrisma` auto-filters deleted rows on read operations.

## Step 3: DB migration

```bash
npx prisma migrate dev --name add_product_model
npx prisma generate
```

## Step 4: Register permissions

In `server/utils/systemPermissions.ts`, add a new entry to `SYSTEM_MODULES`:

```typescript
{
  key: 'products',
  label: 'Sản phẩm',
  permissions: [
    { action: 'read', description: 'Xem danh sách sản phẩm' },
    { action: 'create', description: 'Tạo sản phẩm' },
    { action: 'update', description: 'Sửa sản phẩm' },
    { action: 'delete', description: 'Xóa sản phẩm (soft delete)' }
  ]
}
```

After deploying, call `ensureSystemPermissions(db, tenant_id)` or run the seed
so the DB has the permission rows and Admin role gets them automatically.

## Step 5: API endpoints

Create 4 files under `server/api/{resource}/`. Follow the `nuxt-api-endpoint` skill
for the full skeleton (including `defineRouteMeta` OpenAPI metadata on every file).
Quick reference:

### `server/api/products/index.get.ts` (list)

```typescript
import { getTenantPrisma } from '../../utils/prisma'
import { requirePermission } from '../../utils/requirePermission'

export default defineEventHandler(async (event) => {
  try {
    requirePermission(event, 'read:products')
    const tenant_id = event.context.tenant_id
    if (!tenant_id) throw createError({ statusCode: 400, statusMessage: 'Missing tenant_id' })

    const query = getQuery(event)
    const page = Number(query.page) || 1
    const pageSize = Number(query.pageSize) || 10
    const search = query.search as string

    const db = getTenantPrisma(tenant_id)
    const where: any = {}
    if (search) {
      where.OR = [{ name: { contains: search, mode: 'insensitive' } }]
    }

    const [data, total] = await Promise.all([
      db.product.findMany({ where, skip: (page - 1) * pageSize, take: pageSize, orderBy: { createdAt: 'desc' } }),
      db.product.count({ where })
    ])

    return { success: true, data, total, page, pageSize }
  } catch (error: any) {
    console.error('API Error:', error)
    if (error.statusCode) throw error
    throw createError({ statusCode: 500, statusMessage: 'Lỗi hệ thống', message: error.message })
  }
})
```

### `server/api/products/index.post.ts` (create)

Permission: `requirePermission(event, 'create:products')`
Log: `writeSystemLog({ action: 'CREATE_PRODUCT', resource: 'Product', ... })`

### `server/api/products/[id].put.ts` (update)

Permission: `requirePermission(event, 'update:products')`
Log: `writeSystemLog({ action: 'UPDATE_PRODUCT', ... })`

### `server/api/products/[id].delete.ts` (soft delete)

Permission: `requirePermission(event, 'delete:products')`
Use `updateMany` with `{ deletedAt: new Date(), isActive: false }`.
Log: `writeSystemLog({ action: 'DELETE_PRODUCT', ... })`

## Step 6: CRUD page

Follow the `nuxt-crud-page` skill for the full template. Create:

```
pages/{section}/products/
├── index.vue
└── products.module.scss
```

Key points:
- Desktop: `<DataTable>` with pagination.
- Mobile: card list with `useInfiniteScroll`.
- Wrap in `<ClientOnly>` to avoid SSR hydration issues.
- Use `usePageRefresh(() => fetchData())` for pull-to-refresh.
- All strings via `t()`.

## Step 7: i18n keys

Add to **both** `i18n/locales/vi.json` and `en.json`:

```json
// vi.json
"products": {
  "searchPlaceholder": "Tìm kiếm sản phẩm...",
  "add": "Thêm sản phẩm",
  "createTitle": "Tạo sản phẩm",
  "editTitle": "Chỉnh sửa sản phẩm",
  "createSubmit": "Tạo",
  "name": "Tên sản phẩm",
  "requiredName": "Nhập tên sản phẩm",
  "minName": "Ít nhất 2 ký tự",
  "created": "Đã tạo sản phẩm",
  "updated": "Đã cập nhật sản phẩm",
  "deleted": "Đã xóa sản phẩm",
  "deleteFailed": "Không thể xóa sản phẩm",
  "deleteConfirm": "Xóa sản phẩm \"{name}\"?"
}
```

Also add:
- `nav.products` — sidebar label
- `pages.products` — page title (shown in header/breadcrumb)

Follow the `nuxt-i18n` skill for key naming conventions.

## Step 8: Sidebar entry (desktop)

In `components/DesktopSidebar/index.vue`, add a menu item:

```vue
<el-menu-item
  v-if="authStore.hasPermission('read:products')"
  index="/systems/products"
>
  <el-icon><ShoppingBag /></el-icon>
  <span>{{ t('nav.products') }}</span>
</el-menu-item>
```

- Import the icon from `@element-plus/icons-vue`.
- Add `activeMenu` mapping in the `computed` if the route has sub-pages.
- Gate with `v-if="authStore.hasPermission('read:{resource}')"`.

## Step 9: Mobile menu drawer

In `components/MobileMenuDrawer/index.vue`, add a list item:

```vue
<div
  v-if="authStore.hasPermission('read:products')"
  :class="styles.listItem"
  @click="goTo('/systems/products')"
>
  <el-icon><ShoppingBag /></el-icon>
  <span>{{ t('pages.products') }}</span>
</div>
```

## Step 10: Page title mapping

In `layouts/default.vue`, add the route to `pageTitleKeys`:

```typescript
const pageTitleKeys: Record<string, string> = {
  // ... existing entries
  '/systems/products': 'pages.products'
}
```

## Step 11: Verify

Run through this checklist:

- [ ] Prisma model created with `tenant_id`, `deletedAt`, indexes
- [ ] Model added to `SOFT_DELETE_MODELS` in `server/utils/prisma.ts`
- [ ] `npx prisma migrate dev` succeeded
- [ ] `npx prisma generate` succeeded
- [ ] Permission entry added to `SYSTEM_MODULES`
- [ ] 4 API files created (GET list, POST create, PUT update, DELETE soft-delete)
- [ ] Each API calls `requirePermission()` with correct key
- [ ] Each API scopes queries via `getTenantPrisma(tenant_id)`
- [ ] Mutating APIs call `writeSystemLog()`
- [ ] CRUD page created with desktop table + mobile cards
- [ ] i18n keys added to both `vi.json` and `en.json`
- [ ] Desktop sidebar entry added with permission gate
- [ ] Mobile menu drawer entry added with permission gate
- [ ] Page title mapping added to `pageTitleKeys` in `layouts/default.vue`
- [ ] No hardcoded user-facing strings — all use `t()`
- [ ] Page uses `usePageRefresh(() => fetchData())`
- [ ] Dev server starts without errors
