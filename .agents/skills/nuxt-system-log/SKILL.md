---
name: nuxt-system-log
description: >-
  System/audit logging for this FastAPI monorepo.
  Covers write_system_log, action naming, when to log, and the SystemLog model.
  Use when adding logging to endpoints, reviewing audit coverage, or debugging missing logs.
  Triggers on "system log", "audit log", "writeSystemLog", "write_system_log",
  "nhật ký", "action log", "SystemLog".
---

# System Log

## API

`backend/app/services/system_log.py`:

```python
await write_system_log(
    db,
    tenant_id=tenant_id,
    user_id=actor_id,          # optional
    action="CREATE_USER",
    resource="User",
    details={"id": row.id, "username": row.username},  # dict → JSON string
)
```

Errors are **swallowed** (log + rollback) so audit never breaks the main request.

## When to log

After **successful** mutating actions:

- Login (`LOGIN`)
- Create / update / delete resources
- Assign role permissions (`UPDATE_ROLE_PERMISSIONS`)

Do **not** log every GET, or failed login spam into this table (use rate-limit / separate channel if needed).

## Naming

- `action`: `VERB_NOUN` upper snake — `CREATE_USER`, `DELETE_ROLE`, `LOGIN`
- `resource`: PascalCase entity — `User`, `Role`, `Auth`, `Tenant`

## Model

`SystemLog` — `tenant_id`, optional `user_id`, `action`, `resource`, `details` (text JSON), `created_at`.

List UI: `GET /api/logs` (`read:logs`).

## Checklist

- [ ] Called after successful mutate (not before commit of business data unless intentional)
- [ ] Includes `tenant_id` + actor `user_id` when available
- [ ] `details` has ids/names useful for audit, no secrets/passwords
