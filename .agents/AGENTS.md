# Nuxt 3 SaaS Project Rules

## 1. Project Architecture Overview
- **Framework**: Nuxt 3 (Vue 3, Composition API, `<script setup lang="ts">`).
- **UI Library**: Element Plus (`el-table`, `el-button`, `el-dialog`, etc.).
- **Icons**: `@element-plus/icons-vue`.
- **State Management**: Pinia (e.g., `stores/auth.ts`).
- **Database / ORM**: Prisma (`prisma/schema.prisma`).
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
