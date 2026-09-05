from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import FilmFollow, Notification, WatchlistItem
from app.models.base_fields import new_uuid


async def list_notifications(
    db: AsyncSession, *, user_id: str, page: int = 1, page_size: int = 20
) -> tuple[list[Notification], int]:
    filters = [Notification.user_id == user_id]
    total = (
        await db.execute(
            select(func.count()).select_from(Notification).where(*filters)
        )
    ).scalar_one()
    result = await db.execute(
        select(Notification)
        .where(*filters)
        .options(
            selectinload(Notification.actor),
            selectinload(Notification.film),
        )
        .order_by(Notification.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    return list(result.scalars().unique().all()), total


async def unread_count(db: AsyncSession, *, user_id: str) -> int:
    return (
        await db.execute(
            select(func.count())
            .select_from(Notification)
            .where(Notification.user_id == user_id, Notification.is_read.is_(False))
        )
    ).scalar_one()


async def get_notification(
    db: AsyncSession, *, user_id: str, notification_id: str
) -> Notification | None:
    return (
        await db.execute(
            select(Notification).where(
                Notification.id == notification_id,
                Notification.user_id == user_id,
            )
        )
    ).scalar_one_or_none()


async def mark_read(db: AsyncSession, *, notification: Notification) -> None:
    notification.is_read = True
    await db.flush()


async def mark_all_read(db: AsyncSession, *, user_id: str) -> int:
    rows = (
        await db.execute(
            select(Notification).where(
                Notification.user_id == user_id,
                Notification.is_read.is_(False),
            )
        )
    ).scalars().all()
    for row in rows:
        row.is_read = True
    await db.flush()
    return len(rows)


async def create_notification(
    db: AsyncSession,
    *,
    user_id: str,
    kind: str,
    title: str,
    body: str | None = None,
    link_url: str | None = None,
    ref_key: str | None = None,
    actor_id: str | None = None,
    film_id: str | None = None,
    comment_id: str | None = None,
) -> Notification | None:
    """Create notification; skip duplicates when ref_key is set."""
    if ref_key:
        existing = (
            await db.execute(
                select(Notification.id).where(
                    Notification.user_id == user_id,
                    Notification.kind == kind,
                    Notification.ref_key == ref_key,
                )
            )
        ).scalar_one_or_none()
        if existing:
            return None

    item = Notification(
        id=new_uuid(),
        user_id=user_id,
        kind=kind,
        title=title,
        body=body,
        link_url=link_url,
        ref_key=ref_key,
        actor_id=actor_id,
        film_id=film_id,
        comment_id=comment_id,
        is_read=False,
    )
    db.add(item)
    await db.flush()
    return item


async def list_follow_user_ids(db: AsyncSession, *, film_id: str) -> list[str]:
    result = await db.execute(
        select(FilmFollow.user_id).where(FilmFollow.film_id == film_id)
    )
    return list(result.scalars().all())


async def list_watchlist_user_ids(db: AsyncSession, *, film_id: str) -> list[str]:
    result = await db.execute(
        select(WatchlistItem.user_id).where(WatchlistItem.film_id == film_id)
    )
    return list(result.scalars().all())
