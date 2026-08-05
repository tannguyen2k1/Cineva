from __future__ import annotations

import json
from datetime import datetime, time, timezone

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.permissions import ACTION_LABELS, SYSTEM_MODULES, permission_key
from app.models import Permission, Role, SystemLog, Tenant, User
from app.services.permissions_sync import ensure_system_permissions
from app.services.server_stats import get_server_stats


async def list_permission_catalog(db: AsyncSession, tenant_id: str) -> dict:
    await ensure_system_permissions(db, tenant_id)
    result = await db.execute(select(Permission).where(Permission.tenant_id == tenant_id))
    permissions = result.scalars().all()
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
    tenant_id: str,
    *,
    page: int = 1,
    page_size: int = 10,
    search: str | None = None,
    resource: str | None = None,
    action: str | None = None,
    start_date: str | None = None,
    end_date: str | None = None,
) -> dict:
    filters = [SystemLog.tenant_id == tenant_id]
    if search:
        like = f"%{search}%"
        filters.append(
            or_(
                SystemLog.action.ilike(like),
                SystemLog.resource.ilike(like),
                SystemLog.details.ilike(like),
            )
        )
    if resource:
        filters.append(SystemLog.resource == resource)
    if action:
        filters.append(SystemLog.action == action)
    if start_date:
        start = datetime.fromisoformat(start_date).replace(tzinfo=timezone.utc)
        filters.append(SystemLog.created_at >= start)
    if end_date:
        end = datetime.fromisoformat(end_date)
        end = datetime.combine(end.date(), time(23, 59, 59, 999000), tzinfo=timezone.utc)
        filters.append(SystemLog.created_at <= end)

    total = (
        await db.execute(select(func.count()).select_from(SystemLog).where(*filters))
    ).scalar_one()
    result = await db.execute(
        select(SystemLog)
        .where(*filters)
        .options(selectinload(SystemLog.user))
        .order_by(SystemLog.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    logs = result.scalars().all()
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


async def dashboard_stats(db: AsyncSession, tenant_id: str) -> dict:
    users = (
        await db.execute(
            select(func.count()).select_from(User).where(
                User.tenant_id == tenant_id, User.deleted_at.is_(None)
            )
        )
    ).scalar_one()
    roles = (
        await db.execute(
            select(func.count()).select_from(Role).where(
                Role.tenant_id == tenant_id, Role.deleted_at.is_(None)
            )
        )
    ).scalar_one()
    tenants = (
        await db.execute(
            select(func.count()).select_from(Tenant).where(Tenant.deleted_at.is_(None))
        )
    ).scalar_one()
    logs_count = (
        await db.execute(
            select(func.count()).select_from(SystemLog).where(SystemLog.tenant_id == tenant_id)
        )
    ).scalar_one()

    recent_logs_result = await db.execute(
        select(SystemLog)
        .where(SystemLog.tenant_id == tenant_id)
        .order_by(SystemLog.created_at.desc())
        .limit(20)
    )
    recent_logs = []
    for log in recent_logs_result.scalars().all():
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

    recent_users_result = await db.execute(
        select(User)
        .where(User.tenant_id == tenant_id, User.deleted_at.is_(None))
        .order_by(User.created_at.desc())
        .limit(4)
    )
    recent_users = [
        {
            "id": u.id,
            "username": u.username,
            "fullName": u.full_name,
            "avatar": u.avatar,
            "createdAt": u.created_at,
        }
        for u in recent_users_result.scalars().all()
    ]

    return {
        "success": True,
        "data": {
            "stats": {
                "users": users,
                "roles": roles,
                "tenants": tenants,
                "logs": logs_count,
            },
            "recentLogs": recent_logs,
            "server": get_server_stats(),
            "recentUsers": recent_users,
        },
    }
