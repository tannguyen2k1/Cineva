from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.timeutil import utcnow
from app.models import Banner, FeaturedFilm, Film, SyncRun
from app.repositories.film import film_with_taxonomy_options


async def list_active_banners(db: AsyncSession) -> list[Banner]:
    now = utcnow()
    result = await db.execute(
        select(Banner)
        .where(Banner.is_active.is_(True))
        .order_by(Banner.sort_order.asc(), Banner.created_at.desc())
    )
    banners = list(result.scalars().all())
    out: list[Banner] = []
    for b in banners:
        if b.starts_at and b.starts_at > now:
            continue
        if b.ends_at and b.ends_at < now:
            continue
        out.append(b)
    return out


async def list_all_banners(db: AsyncSession) -> list[Banner]:
    result = await db.execute(
        select(Banner).order_by(Banner.sort_order.asc(), Banner.created_at.desc())
    )
    return list(result.scalars().all())


async def get_banner(db: AsyncSession, *, banner_id: str) -> Banner | None:
    return (
        await db.execute(select(Banner).where(Banner.id == banner_id))
    ).scalar_one_or_none()


async def add_banner(db: AsyncSession, banner: Banner) -> Banner:
    db.add(banner)
    await db.flush()
    return banner


async def delete_banner(db: AsyncSession, banner: Banner) -> None:
    await db.delete(banner)
    await db.flush()


async def list_featured(
    db: AsyncSession, *, section: str | None = None, include_hidden: bool = False
) -> list[FeaturedFilm]:
    stmt = (
        select(FeaturedFilm)
        .options(selectinload(FeaturedFilm.film).options(*film_with_taxonomy_options()))
        .order_by(FeaturedFilm.sort_order.asc(), FeaturedFilm.created_at.desc())
    )
    if section:
        stmt = stmt.where(FeaturedFilm.section == section)
    result = await db.execute(stmt)
    rows = list(result.scalars().unique().all())
    out: list[FeaturedFilm] = []
    for f in rows:
        if not f.film:
            continue
        if not include_hidden and f.film.is_hidden:
            continue
        out.append(f)
    return out


async def latest_sync_run(db: AsyncSession) -> SyncRun | None:
    result = await db.execute(
        select(SyncRun).order_by(SyncRun.created_at.desc()).limit(1)
    )
    return result.scalar_one_or_none()


async def get_featured(db: AsyncSession, *, featured_id: str) -> FeaturedFilm | None:
    return (
        await db.execute(select(FeaturedFilm).where(FeaturedFilm.id == featured_id))
    ).scalar_one_or_none()


async def add_featured(db: AsyncSession, item: FeaturedFilm) -> FeaturedFilm:
    db.add(item)
    await db.flush()
    return item


async def delete_featured(db: AsyncSession, item: FeaturedFilm) -> None:
    await db.delete(item)
    await db.flush()


async def add_sync_run(db: AsyncSession, run: SyncRun) -> SyncRun:
    db.add(run)
    await db.flush()
    return run


async def list_sync_runs(
    db: AsyncSession, *, page: int = 1, page_size: int = 20
) -> tuple[list[SyncRun], int]:
    from sqlalchemy import func

    total = (await db.execute(select(func.count()).select_from(SyncRun))).scalar_one()
    result = await db.execute(
        select(SyncRun)
        .order_by(SyncRun.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    return list(result.scalars().all()), total
