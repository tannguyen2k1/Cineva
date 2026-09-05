from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.timeutil import utcnow
from app.models import Film, FilmComment, FilmFollow, FilmRating, WatchProgress, WatchlistItem
from app.repositories.film import film_with_taxonomy_options


async def get_watchlist_item(
    db: AsyncSession, *, user_id: str, film_id: str
) -> WatchlistItem | None:
    return (
        await db.execute(
            select(WatchlistItem).where(
                WatchlistItem.user_id == user_id,
                WatchlistItem.film_id == film_id,
            )
        )
    ).scalar_one_or_none()


async def list_watchlist(
    db: AsyncSession, *, user_id: str, page: int, page_size: int
) -> tuple[list[WatchlistItem], int]:
    filters = [WatchlistItem.user_id == user_id]
    total = (
        await db.execute(select(func.count()).select_from(WatchlistItem).where(*filters))
    ).scalar_one()
    result = await db.execute(
        select(WatchlistItem)
        .where(*filters)
        .options(selectinload(WatchlistItem.film).options(*film_with_taxonomy_options()))
        .order_by(WatchlistItem.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    return list(result.scalars().unique().all()), total


async def add_watchlist(db: AsyncSession, item: WatchlistItem) -> WatchlistItem:
    db.add(item)
    await db.flush()
    return item


async def delete_watchlist(db: AsyncSession, item: WatchlistItem) -> None:
    await db.delete(item)
    await db.flush()


async def get_follow(
    db: AsyncSession, *, user_id: str, film_id: str
) -> FilmFollow | None:
    return (
        await db.execute(
            select(FilmFollow).where(
                FilmFollow.user_id == user_id,
                FilmFollow.film_id == film_id,
            )
        )
    ).scalar_one_or_none()


async def add_follow(db: AsyncSession, item: FilmFollow) -> FilmFollow:
    db.add(item)
    await db.flush()
    return item


async def delete_follow(db: AsyncSession, item: FilmFollow) -> None:
    await db.delete(item)
    await db.flush()


async def get_progress(
    db: AsyncSession, *, user_id: str, film_id: str
) -> WatchProgress | None:
    return (
        await db.execute(
            select(WatchProgress).where(
                WatchProgress.user_id == user_id,
                WatchProgress.film_id == film_id,
            )
        )
    ).scalar_one_or_none()


async def upsert_progress(
    db: AsyncSession,
    *,
    user_id: str,
    film_id: str,
    episode_slug: str,
    episode_name: str | None,
    server_name: str | None,
    position_sec: int | None,
) -> WatchProgress:
    existing = await get_progress(db, user_id=user_id, film_id=film_id)
    if existing:
        existing.episode_slug = episode_slug
        existing.episode_name = episode_name
        existing.server_name = server_name
        existing.position_sec = position_sec
        existing.updated_at = utcnow()
        await db.flush()
        return existing
    item = WatchProgress(
        user_id=user_id,
        film_id=film_id,
        episode_slug=episode_slug,
        episode_name=episode_name,
        server_name=server_name,
        position_sec=position_sec,
    )
    db.add(item)
    await db.flush()
    return item


async def list_continue(
    db: AsyncSession, *, user_id: str, limit: int = 20
) -> list[WatchProgress]:
    result = await db.execute(
        select(WatchProgress)
        .where(WatchProgress.user_id == user_id)
        .options(selectinload(WatchProgress.film).options(*film_with_taxonomy_options()))
        .order_by(WatchProgress.updated_at.desc())
        .limit(limit)
    )
    return [
        p
        for p in result.scalars().unique().all()
        if p.film and not p.film.is_hidden
    ]


async def get_rating(
    db: AsyncSession, *, user_id: str, film_id: str
) -> FilmRating | None:
    return (
        await db.execute(
            select(FilmRating).where(
                FilmRating.user_id == user_id,
                FilmRating.film_id == film_id,
            )
        )
    ).scalar_one_or_none()


async def upsert_rating(
    db: AsyncSession, *, user_id: str, film_id: str, score: int
) -> FilmRating:
    existing = await get_rating(db, user_id=user_id, film_id=film_id)
    if existing:
        existing.score = score
        await db.flush()
        return existing
    rating = FilmRating(user_id=user_id, film_id=film_id, score=score)
    db.add(rating)
    await db.flush()
    return rating


async def rating_stats(db: AsyncSession, *, film_id: str) -> tuple[float, int]:
    row = (
        await db.execute(
            select(func.avg(FilmRating.score), func.count(FilmRating.id)).where(
                FilmRating.film_id == film_id
            )
        )
    ).one()
    avg = float(row[0] or 0)
    count = int(row[1] or 0)
    return avg, count


async def list_comments(
    db: AsyncSession,
    *,
    film_id: str,
    page: int,
    page_size: int,
    include_hidden: bool = False,
) -> tuple[list[FilmComment], int]:
    """Paginate top-level comments; each includes nested replies."""
    filters = [
        FilmComment.film_id == film_id,
        FilmComment.deleted_at.is_(None),
        FilmComment.parent_id.is_(None),
    ]
    if not include_hidden:
        filters.append(FilmComment.is_hidden.is_(False))
    total = (
        await db.execute(select(func.count()).select_from(FilmComment).where(*filters))
    ).scalar_one()
    result = await db.execute(
        select(FilmComment)
        .where(*filters)
        .options(
            selectinload(FilmComment.user),
            selectinload(FilmComment.replies).selectinload(FilmComment.user),
        )
        .order_by(FilmComment.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    return list(result.scalars().unique().all()), total


async def add_comment(db: AsyncSession, comment: FilmComment) -> FilmComment:
    db.add(comment)
    await db.flush()
    return comment


async def get_comment(db: AsyncSession, *, comment_id: str) -> FilmComment | None:
    return (
        await db.execute(
            select(FilmComment)
            .where(FilmComment.id == comment_id)
            .options(
                selectinload(FilmComment.user),
                selectinload(FilmComment.film),
                selectinload(FilmComment.parent).selectinload(FilmComment.user),
            )
        )
    ).scalar_one_or_none()


async def list_admin_comments(
    db: AsyncSession, *, page: int, page_size: int, film_id: str | None = None
) -> tuple[list[FilmComment], int]:
    filters = [FilmComment.deleted_at.is_(None)]
    if film_id:
        filters.append(FilmComment.film_id == film_id)
    total = (
        await db.execute(select(func.count()).select_from(FilmComment).where(*filters))
    ).scalar_one()
    result = await db.execute(
        select(FilmComment)
        .where(*filters)
        .options(
            selectinload(FilmComment.user),
            selectinload(FilmComment.film),
        )
        .order_by(FilmComment.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    return list(result.scalars().all()), total


async def count_comments(
    db: AsyncSession, *, include_deleted: bool = False, hidden_only: bool = False
) -> int:
    filters = []
    if not include_deleted:
        filters.append(FilmComment.deleted_at.is_(None))
    if hidden_only:
        filters.append(FilmComment.is_hidden.is_(True))
    stmt = select(func.count()).select_from(FilmComment)
    if filters:
        stmt = stmt.where(*filters)
    return (await db.execute(stmt)).scalar_one()
