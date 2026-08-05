---
name: nuxt-tenant-isolation
description: >-
  DEPRECATED on branch non_tenant. This template is single-org — there is no tenant_id.
  Do not add multi-tenant isolation. Triggers on "tenant", "multi-tenant", "tenant_id".
---

# Tenant Isolation — Not used

This branch (`non_tenant`) has **no multi-tenancy**:

- No `tenants` table / `Tenant` model
- No `tenant_id` on models, JWT, or API
- Permissions and users are **global**

Do **not** reintroduce `tenant_id` filters or a Tenants admin module here.
For multi-tenant SaaS, use the main/template branch that still has tenant isolation.
