from __future__ import annotations

from datetime import datetime, time, timezone

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import SystemLog


async def add_log(db: AsyncSession, log: SystemLog) -> None:
    db.add(log)


async def count_logs(db: AsyncSession, *filters) -> int:
    return (
        await db.execute(select(func.count()).select_from(SystemLog).where(*filters))
    ).scalar_one()


async def count_in_tenant(db: AsyncSession, tenant_id: str) -> int:
    return await count_logs(db, SystemLog.tenant_id == tenant_id)


async def list_logs_page(
    db: AsyncSession,
    *,
    tenant_id: str,
    page: int,
    page_size: int,
    search: str | None = None,
    resource: str | None = None,
    action: str | None = None,
    start_date: str | None = None,
    end_date: str | None = None,
) -> tuple[list[SystemLog], int]:
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

    total = await count_logs(db, *filters)
    result = await db.execute(
        select(SystemLog)
        .where(*filters)
        .options(selectinload(SystemLog.user))
        .order_by(SystemLog.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    return list(result.scalars().all()), total


async def list_recent(db: AsyncSession, tenant_id: str, *, limit: int = 20) -> list[SystemLog]:
    result = await db.execute(
        select(SystemLog)
        .where(SystemLog.tenant_id == tenant_id)
        .order_by(SystemLog.created_at.desc())
        .limit(limit)
    )
    return list(result.scalars().all())
