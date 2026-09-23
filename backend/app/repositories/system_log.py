from __future__ import annotations

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.timeutil import parse_filter_instant
from app.models import SystemLog, User


async def add_log(db: AsyncSession, log: SystemLog) -> None:
    db.add(log)


async def count_logs(db: AsyncSession, *filters) -> int:
    return (
        await db.execute(select(func.count()).select_from(SystemLog).where(*filters))
    ).scalar_one()


async def count_all(db: AsyncSession) -> int:
    return await count_logs(db)


WATCH_ACTIONS = ["WATCH_FILM", "WATCH_PROGRESS"]
ENGAGEMENT_ACTIONS = ["ADD_WATCHLIST", "REMOVE_WATCHLIST", "FOLLOW_FILM", "UNFOLLOW_FILM", "POST_COMMENT"]
AUTH_ACTIONS = ["LOGIN", "LOGOUT", "PASSWORD_CHANGE", "PASSWORD_RESET", "OAUTH2_TOKEN"]


async def list_logs_page(
    db: AsyncSession,
    *,
    page: int,
    page_size: int,
    search: str | None = None,
    category: str | None = None,
    resource: str | None = None,
    action: str | None = None,
    user_id: str | None = None,
    start_date: str | None = None,
    end_date: str | None = None,
) -> tuple[list[SystemLog], int]:
    filters = []
    if search:
        like = f"%{search}%"
        filters.append(
            or_(
                SystemLog.action.ilike(like),
                SystemLog.resource.ilike(like),
                SystemLog.details.ilike(like),
                SystemLog.user.has(User.username.ilike(like)),
                SystemLog.user.has(User.full_name.ilike(like)),
            )
        )
    if user_id:
        filters.append(SystemLog.user_id == user_id)
    if category:
        cat = category.strip().lower()
        if cat == "watch":
            filters.append(SystemLog.action.in_(WATCH_ACTIONS))
        elif cat == "engagement":
            filters.append(SystemLog.action.in_(ENGAGEMENT_ACTIONS))
        elif cat == "auth":
            filters.append(SystemLog.action.in_(AUTH_ACTIONS))
        elif cat == "system":
            filters.append(SystemLog.action.not_in(WATCH_ACTIONS + ENGAGEMENT_ACTIONS + AUTH_ACTIONS))

    if resource:
        filters.append(SystemLog.resource == resource)
    if action:
        filters.append(SystemLog.action == action)
    if start_date:
        filters.append(SystemLog.created_at >= parse_filter_instant(start_date, end=False))
    if end_date:
        filters.append(SystemLog.created_at <= parse_filter_instant(end_date, end=True))

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


async def list_recent(db: AsyncSession, *, limit: int = 20) -> list[SystemLog]:
    result = await db.execute(
        select(SystemLog)
        .order_by(SystemLog.created_at.desc())
        .limit(limit)
    )
    return list(result.scalars().all())
