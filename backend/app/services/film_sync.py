from __future__ import annotations

import logging

from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.timeutil import utcnow
from app.models import Film, SyncRun
from app.repositories import film as film_repo
from app.repositories import cms as cms_repo
from app.services.film_mapper import apply_list_item_to_film
from app.services.nguonc_client import get_nguonc_client
from app.services.system_log import write_system_log

logger = logging.getLogger(__name__)

# Curated seeds so home rails / filters have real rows (nguonc has many more).
CATALOG_LISTS: list[tuple[str, str]] = [
    ("phim-le", "Phim Lẻ"),
    ("phim-bo", "Phim Bộ"),
    ("hoat-hinh", "Hoạt Hình"),
    ("dang-chieu", "Đang Chiếu"),
    ("tv-shows", "TV Shows"),
]

# Full genre set matching phim.nguonc.com mega-menu (slugs verified).
CATALOG_GENRES: list[tuple[str, str]] = [
    ("hanh-dong", "Hành Động"),
    ("phieu-luu", "Phiêu Lưu"),
    ("hoat-hinh", "Hoạt Hình"),
    ("phim-hai", "Hài"),
    ("hinh-su", "Hình Sự"),
    ("tai-lieu", "Tài Liệu"),
    ("chinh-kich", "Chính Kịch"),
    ("gia-dinh", "Gia Đình"),
    ("gia-tuong", "Giả Tưởng"),
    ("lich-su", "Lịch Sử"),
    ("kinh-di", "Kinh Dị"),
    ("phim-nhac", "Nhạc"),
    ("bi-an", "Bí Ẩn"),
    ("lang-man", "Lãng Mạn"),
    ("khoa-hoc-vien-tuong", "Khoa Học Viễn Tưởng"),
    ("gay-can", "Gây Cấn"),
    ("chien-tranh", "Chiến Tranh"),
    ("tam-ly", "Tâm Lý"),
    ("tinh-cam", "Tình Cảm"),
    ("co-trang", "Cổ Trang"),
    ("mien-tay", "Miền Tây"),
    ("phim-18", "Phim 18+"),
]

CATALOG_COUNTRIES: list[tuple[str, str]] = [
    ("trung-quoc", "Trung Quốc"),
    ("han-quoc", "Hàn Quốc"),
    ("thai-lan", "Thái Lan"),
    ("au-my", "Âu Mỹ"),
    ("nhat-ban", "Nhật Bản"),
    ("viet-nam", "Việt Nam"),
]


async def upsert_list_item(db: AsyncSession, item) -> Film:
    from app.repositories import notifications as notif_repo

    film = await film_repo.get_by_slug(db, slug=item.slug)
    now = utcnow()
    old_episode = film.current_episode if film else None
    if not film:
        film = Film(source_slug=item.slug, name=item.name or item.slug)
        apply_list_item_to_film(film, item)
        film.synced_at = now
        await film_repo.add_film(db, film)
    else:
        apply_list_item_to_film(film, item)
        film.synced_at = now
        await db.flush()

    new_episode = (item.current_episode or "").strip()
    if (
        old_episode
        and new_episode
        and old_episode != new_episode
        and film.id
    ):
        user_ids = await notif_repo.list_follow_user_ids(db, film_id=film.id)
        for uid in user_ids:
            await notif_repo.create_notification(
                db,
                user_id=uid,
                kind="episode_update",
                title=f"{film.name} có tập mới",
                body=new_episode,
                link_url=f"/phim/{film.source_slug}",
                ref_key=f"ep:{film.id}:{new_episode}",
                film_id=film.id,
            )
    return film


async def seed_catalog_taxonomies(db: AsyncSession) -> None:
    """Ensure mega-menu / filter options exist even before films are synced."""
    for slug, name in CATALOG_GENRES:
        await film_repo.get_or_create_genre(db, slug=slug, name=name)
    for slug, name in CATALOG_COUNTRIES:
        await film_repo.get_or_create_country(db, slug=slug, name=name)
    for slug, name in CATALOG_LISTS:
        await film_repo.get_or_create_film_type(db, slug=slug, name=name)
    await db.flush()


async def _sync_listing_pages(
    db: AsyncSession,
    *,
    fetch,
    pages: int,
    genre: tuple[str, str] | None = None,
    country: tuple[str, str] | None = None,
    film_type: tuple[str, str] | None = None,
) -> int:
    upserted = 0
    for page in range(1, pages + 1):
        try:
            listing = await fetch(page)
        except Exception:
            logger.exception("Failed fetching catalog page %s", page)
            break
        if not listing.items:
            break
        for item in listing.items:
            film = await upsert_list_item(db, item)
            if genre:
                await film_repo.ensure_film_genre(
                    db, film=film, slug=genre[0], name=genre[1]
                )
            if country:
                await film_repo.ensure_film_country(
                    db, film=film, slug=country[0], name=country[1]
                )
            if film_type:
                await film_repo.ensure_film_type(
                    db, film=film, slug=film_type[0], name=film_type[1]
                )
            upserted += 1
        await db.commit()
        if page >= listing.total_page:
            break
    return upserted


async def run_incremental_sync(
    db: AsyncSession, *, actor_id: str | None = None, max_pages: int | None = None
) -> dict:
    settings = get_settings()
    pages = max_pages or settings.sync_max_pages_per_run
    client = get_nguonc_client()
    run = SyncRun(job_type="incremental", status="running", page_from=1)
    await cms_repo.add_sync_run(db, run)
    await db.commit()

    upserted = 0
    last_page = 0
    try:
        watermark = await film_repo.latest_source_modified(db)
        for page in range(1, pages + 1):
            listing = await client.fetch_newest(page)
            last_page = page
            if not listing.items:
                break
            stop = False
            for item in listing.items:
                if watermark and item.modified and item.modified <= watermark:
                    stop = True
                await upsert_list_item(db, item)
                upserted += 1
            await db.commit()
            if stop and page > 1:
                break
            if page >= listing.total_page:
                break

        run.status = "success"
        run.page_to = last_page
        run.items_upserted = upserted
        run.finished_at = utcnow()
        await db.commit()

        if actor_id:
            await write_system_log(
                db,
                user_id=actor_id,
                action="SYNC_FILMS",
                resource="Sync",
                details=f"upserted={upserted} pages=1-{last_page}",
            )

        return {
            "success": True,
            "data": {
                "id": run.id,
                "jobType": run.job_type,
                "status": run.status,
                "pageFrom": run.page_from,
                "pageTo": run.page_to,
                "itemsUpserted": run.items_upserted,
                "startedAt": run.started_at,
                "finishedAt": run.finished_at,
            },
        }
    except Exception as exc:
        logger.exception("Film sync failed")
        run.status = "failed"
        run.error = str(exc)[:2000]
        run.page_to = last_page or None
        run.items_upserted = upserted
        run.finished_at = utcnow()
        await db.commit()
        raise HTTPException(status_code=502, detail=f"Đồng bộ thất bại: {exc}") from exc


async def run_catalog_sync(
    db: AsyncSession,
    *,
    actor_id: str | None = None,
    pages_per_source: int = 2,
) -> dict:
    """Pull newest + curated danh-sach / thể loại / quốc gia and tag films."""
    client = get_nguonc_client()
    run = SyncRun(job_type="catalog", status="running", page_from=1)
    await cms_repo.add_sync_run(db, run)
    await db.commit()

    upserted = 0
    try:
        await seed_catalog_taxonomies(db)
        await db.commit()

        upserted += await _sync_listing_pages(
            db,
            fetch=client.fetch_newest,
            pages=pages_per_source,
        )

        for slug, name in CATALOG_LISTS:
            upserted += await _sync_listing_pages(
                db,
                fetch=lambda page, s=slug: client.fetch_by_list(s, page),
                pages=pages_per_source,
                film_type=(slug, name),
            )

        for slug, name in CATALOG_GENRES:
            upserted += await _sync_listing_pages(
                db,
                fetch=lambda page, s=slug: client.fetch_by_genre(s, page),
                pages=pages_per_source,
                genre=(slug, name),
            )

        for slug, name in CATALOG_COUNTRIES:
            upserted += await _sync_listing_pages(
                db,
                fetch=lambda page, s=slug: client.fetch_by_country(s, page),
                pages=pages_per_source,
                country=(slug, name),
            )

        run.status = "success"
        run.page_to = pages_per_source
        run.items_upserted = upserted
        run.finished_at = utcnow()
        await db.commit()

        if actor_id:
            await write_system_log(
                db,
                user_id=actor_id,
                action="SYNC_CATALOG",
                resource="Sync",
                details=f"catalog upserted={upserted} pages_per_source={pages_per_source}",
            )

        return {
            "success": True,
            "data": {
                "id": run.id,
                "jobType": run.job_type,
                "status": run.status,
                "pageFrom": run.page_from,
                "pageTo": run.page_to,
                "itemsUpserted": run.items_upserted,
                "startedAt": run.started_at,
                "finishedAt": run.finished_at,
            },
        }
    except Exception as exc:
        logger.exception("Catalog sync failed")
        run.status = "failed"
        run.error = str(exc)[:2000]
        run.items_upserted = upserted
        run.finished_at = utcnow()
        await db.commit()
        raise HTTPException(status_code=502, detail=f"Đồng bộ catalog thất bại: {exc}") from exc


async def list_sync_runs(db: AsyncSession, *, page: int = 1, page_size: int = 20) -> dict:
    rows, total = await cms_repo.list_sync_runs(db, page=page, page_size=page_size)
    return {
        "success": True,
        "data": [
            {
                "id": r.id,
                "jobType": r.job_type,
                "status": r.status,
                "pageFrom": r.page_from,
                "pageTo": r.page_to,
                "itemsUpserted": r.items_upserted,
                "error": r.error,
                "startedAt": r.started_at,
                "finishedAt": r.finished_at,
            }
            for r in rows
        ],
        "total": total,
        "page": page,
        "pageSize": page_size,
    }
