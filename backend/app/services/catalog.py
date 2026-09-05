from __future__ import annotations

import json

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.permissions import ACTION_LABELS, SYSTEM_MODULES, permission_key
from app.repositories import permission as permission_repo
from app.repositories import role as role_repo
from app.repositories import system_log as system_log_repo
from app.repositories import user as user_repo
from app.services.permissions_sync import ensure_system_permissions
from app.services.server_stats import get_server_stats


async def list_permission_catalog(db: AsyncSession) -> dict:
    await ensure_system_permissions(db)
    permissions = await permission_repo.list_all(db)
    by_key = {permission_key(p.action, p.resource): p for p in permissions}

    data = []
    for mod in SYSTEM_MODULES:
        items = []
        for defn in mod.permissions:
            row = by_key.get(permission_key(defn.action, mod.key))
            if not row:
                continue
            items.append(
                {
                    "id": row.id,
                    "action": row.action,
                    "actionLabel": ACTION_LABELS.get(row.action, row.action),
                    "key": permission_key(row.action, row.resource),
                    "description": row.description or defn.description,
                }
            )
        if items:
            data.append({"resource": mod.key, "label": mod.label, "permissions": items})

    return {"success": True, "data": data}


async def list_logs(
    db: AsyncSession,
    *,
    page: int = 1,
    page_size: int = 10,
    search: str | None = None,
    resource: str | None = None,
    action: str | None = None,
    start_date: str | None = None,
    end_date: str | None = None,
) -> dict:
    logs, total = await system_log_repo.list_logs_page(
        db,
        page=page,
        page_size=page_size,
        search=search,
        resource=resource,
        action=action,
        start_date=start_date,
        end_date=end_date,
    )
    data = []
    for log in logs:
        details = log.details
        if details:
            try:
                details = json.loads(details)
            except (TypeError, json.JSONDecodeError):
                pass
        data.append(
            {
                "id": log.id,
                "action": log.action,
                "resource": log.resource,
                "details": details,
                "createdAt": log.created_at,
                "actor": log.user.full_name if log.user else None,
                "actorUsername": log.user.username if log.user else None,
            }
        )
    return {
        "success": True,
        "data": data,
        "total": total,
        "page": page,
        "pageSize": page_size,
    }


async def dashboard_stats(db: AsyncSession) -> dict:
    from app.repositories import cms as cms_repo
    from app.repositories import engagement as eng_repo
    from app.repositories import film as film_repo

    users = await user_repo.count_active(db)
    roles = await role_repo.count_active(db)
    logs_count = await system_log_repo.count_all(db)
    films = await film_repo.count_films(db, include_hidden=True)
    comments = await eng_repo.count_comments(db)
    last_sync = await cms_repo.latest_sync_run(db)

    recent_logs = []
    for log in await system_log_repo.list_recent(db, limit=20):
        action_upper = (log.action or "").upper()
        if "LỖI" in action_upper or "ERROR" in action_upper:
            log_type = "danger"
        elif "CẢNH BÁO" in action_upper or "WARN" in action_upper:
            log_type = "warning"
        else:
            log_type = "primary"
        details = log.details
        if details:
            try:
                details = json.loads(details)
            except (TypeError, json.JSONDecodeError):
                pass
        recent_logs.append(
            {
                "id": log.id,
                "action": log.action,
                "details": details,
                "createdAt": log.created_at,
                "type": log_type,
            }
        )

    recent_users = [
        {
            "id": u.id,
            "username": u.username,
            "fullName": u.full_name,
            "avatar": u.avatar,
            "createdAt": u.created_at,
        }
        for u in await user_repo.list_recent(db, limit=4)
    ]

    last_sync_payload = None
    if last_sync:
        last_sync_payload = {
            "id": last_sync.id,
            "jobType": last_sync.job_type,
            "status": last_sync.status,
            "itemsUpserted": last_sync.items_upserted,
            "startedAt": last_sync.started_at,
            "finishedAt": last_sync.finished_at,
        }

    return {
        "success": True,
        "data": {
            "stats": {
                "users": users,
                "roles": roles,
                "logs": logs_count,
                "films": films,
                "comments": comments,
            },
            "lastSync": last_sync_payload,
            "recentLogs": recent_logs,
            "server": get_server_stats(),
            "recentUsers": recent_users,
        },
    }
