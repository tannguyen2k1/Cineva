# Nuxt 3 SaaS Project Rules

## 1. Project Architecture Overview
- **Framework**: Nuxt 3 (Vue 3, Composition API, `<script setup lang="ts">`).
- **UI Library**: Element Plus (`el-table`, `el-button`, `el-dialog`, etc.).
- **Icons**: `@element-plus/icons-vue`.
- **State Management**: Pinia (e.g., `stores/auth.ts`).
- **Database / ORM**: Prisma (`prisma/schema.prisma` + `prisma/models/*.prisma`).
- **Multi-tenancy**: RBAC (Role-Based Access Control) with Tenant data isolation.

## 2. File Modularity & Structure
- **Pages**: Placed in `pages/` (e.g., `pages/systems/users/index.vue`).
- **Components**: Reusable UI parts go to `components/`.
- **API Endpoints**: Placed in `server/api/` (e.g., `server/api/users/index.get.ts`).
- **Always modularize code**: Keep `.vue` files clean. Extract complex business logic, composables, or API calls if files get too large.

## 3. Styling & CSS Rules (CRITICAL)
- **ALWAYS** use CSS Modules (`.module.scss`) for component and page styling.
- **NEVER** use `<style scoped>` or `<style>` directly in `.vue` files.
- **Implementation**:
  1. Create a `[name].module.scss` alongside the `.vue` file.
  2. Use camelCase for all CSS classes (e.g., `.pageContainer`, `.fwBold`).
  3. In `.vue`: `import styles from './[name].module.scss';`
  4. Apply classes via dynamic binding: `:class="styles.pageContainer"`.

## 4. API & Backend Rules
- **Authentication**: JWT Tokens. Checked globally via `server/middleware/auth.ts`.
- **Tenant Context**: Always extract `event.context.tenant_id` (from headers or JWT) and use it in Prisma queries to ensure strict data isolation.
- **Error Handling**: Throw errors using `createError({ statusCode, statusMessage })`.
- **Response Format**: APIs should consistently return `{ success: true, data: ..., total?: ... }`.
- **System logs**: After successful mutating actions (create/update/delete/login/assign permissions), call `writeSystemLog` from `server/utils/systemLog.ts` in that API handler. Do not block the main response if logging fails.

## 5. Frontend Guidelines
- **API Calls**: Use Nuxt's `$fetch` for client-side API requests. Include `Authorization: Bearer <token>` and `x-tenant-id` headers where necessary (usually handled via Pinia store data).
- **Reactivity**: Use `ref` for primitives and simple values, `reactive` for objects/forms.
- **Forms**: Use `el-form` with proper validation rules (`FormRules`) for all data entry.

## 6. Naming Conventions
- **Variables/Functions/CSS Classes**: `camelCase`
- **Vue Components/Interfaces**: `PascalCase`
- **API File Names**: Nuxt 3 pattern `[name].[method].ts` (e.g., `index.get.ts`, `profile.put.ts`)

## 7. Security Best Practices (CRITICAL)
- **Always pay attention to security** in all implementation tasks.
- Never expose sensitive information (like `password` hashes, secret keys) in API responses.
- Always validate and sanitize user inputs to prevent Injection and XSS.
- Secure file uploads (restrict mime types, size, and use safe paths).
- Ensure strict multi-tenant data isolation on EVERY database query.

## 8. Soft Delete (CRITICAL)
- Models with `deletedAt DateTime?` (User, Role, Tenant, and any new soft-deletable model) must **not** be hard-deleted in normal CRUD.
- Handle soft delete **inside that resource’s API** (e.g. `server/api/users/[id].delete.ts`). Do **not** create a shared `softDelete` util.
- Delete = `updateMany` set `deletedAt: new Date()` (and `isActive: false` when the model has it).
- List / count / auth must ignore soft-deleted rows (`deletedAt: null`). `getTenantPrisma` already filters this on read for soft-delete models; raw `prisma` queries (login, `me`, …) must also use `deletedAt: null`.
- Business uniqueness (username, role name, …) is checked among **non-deleted** rows in the API. Avoid DB `@@unique` alone if soft-deleted rows would block reusing the same key.
- New soft-deletable models: add `deletedAt DateTime?` + index; relation `_count` for “active” totals should filter `deletedAt: null`.

## 9. Internationalization / i18n (CRITICAL)
- Stack: `@nuxtjs/i18n` (configured in `nuxt.config.ts`). Default locale: `vi`. Strategy: `no_prefix`.
- Locale files live under `i18n/locales/` (`vi.json`, `en.json`). Keep both files in sync — every new key must exist in **vi and en**.
- **Never** hardcode user-facing UI copy (labels, placeholders, buttons, toasts, confirm dialogs, empty states, page titles, validation messages) in Vietnamese or English. Use `t('...')` / `$t('...')` via `useI18n()`.
- Key naming: group by feature (`login.*`, `users.*`, `roles.*`, `tenants.*`, `logs.*`, `dashboard.*`, `nav.*`, `pages.*`, `header.*`, `common.*`, `lang.*`, `app.*`). Prefer reusing `common.*` for shared actions (cancel, save, delete, status, …).
- Dynamic text: use interpolation, e.g. `t('users.deleteConfirm', { name })`, not string concatenation.
- Form rules / `ElMessage` / `ElMessageBox`: messages must come from `t()` (usually inside `computed` so they update on locale change).
- Element Plus locale must stay in sync with i18n locale (`el-config-provider` in `app.vue` — `vi` / `en` from `element-plus/es/locale/lang/...`).
- Language switcher belongs in the app shell (layout header) and on layout-less pages that need it (e.g. login). Persist via i18n cookie (`detectBrowserLanguage`).
- Server/API `statusMessage` strings may stay as-is for now; UI should still prefer a client-side `t()` fallback when showing errors.
- When adding a new page or feature UI: add keys first, then wire `t()` — do not ship untranslated strings.
