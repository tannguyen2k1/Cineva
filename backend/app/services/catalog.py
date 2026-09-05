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
    films = await film_repo.count_films(db, include_hidden=True)
    films_hidden = await film_repo.count_hidden_films(db)
    films_visible = max(0, films - films_hidden)
    comments = await eng_repo.count_comments(db)
    comments_hidden = await eng_repo.count_comments(db, hidden_only=True)
    banners = await cms_repo.count_banners(db)
    banners_active = await cms_repo.count_banners(db, active_only=True)
    featured = await cms_repo.count_featured(db, section="home_hot")
    last_sync = await cms_repo.latest_sync_run(db)

    last_sync_payload = None
    if last_sync:
        last_sync_payload = {
            "id": last_sync.id,
            "jobType": last_sync.job_type,
            "status": last_sync.status,
            "itemsUpserted": last_sync.items_upserted,
            "error": last_sync.error,
            "startedAt": last_sync.started_at,
            "finishedAt": last_sync.finished_at,
        }

    from app.services import traffic as traffic_service

    traffic = await traffic_service.series_last_days(db, days=7)

    return {
        "success": True,
        "data": {
            "stats": {
                "users": users,
                "films": films,
                "filmsVisible": films_visible,
                "filmsHidden": films_hidden,
                "comments": comments,
                "commentsHidden": comments_hidden,
                "banners": banners,
                "bannersActive": banners_active,
                "featured": featured,
            },
            "lastSync": last_sync_payload,
            "traffic": traffic,
            "server": get_server_stats(),
        },
    }
