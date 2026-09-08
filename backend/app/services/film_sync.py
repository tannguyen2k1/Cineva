from __future__ import annotations

import asyncio
import json
import logging
from contextlib import asynccontextmanager
from datetime import timedelta
from typing import AsyncIterator

from fastapi import HTTPException
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.timeutil import utcnow
from app.models import Film, SyncRun
from app.repositories import film as film_repo
from app.repositories import cms as cms_repo
from app.services.film_mapper import apply_list_item_to_film
from app.services.film_images import mirror_film_images
from app.services.nguonc_client import get_nguonc_client
from app.services.system_log import write_system_log

logger = logging.getLogger(__name__)
FULL_SYNC_LOCK_KEY = 0x43494E455641

# Curated seeds so home rails / filters have real rows (nguonc has many more).
CATALOG_LISTS: list[tuple[str, str]] = [
    ("phim-le", "Phim Lẻ"),
    ("phim-bo", "Phim Bộ"),
    ("hoat-hinh", "Hoạt Hình"),
    ("dang-chieu", "Đang Chiếu"),
    ("tv-shows", "TV Shows"),
]

# Full genre set matching mega-menu (slugs verified).
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


async def upsert_list_item(
    db: AsyncSession,
    item,
    *,
    existing_by_slug: dict[str, Film] | None = None,
    notify_episode_updates: bool = True,
) -> Film:
    from app.repositories import notifications as notif_repo

    film = (
        existing_by_slug.get(item.slug)
        if existing_by_slug is not None
        else await film_repo.get_by_slug(db, slug=item.slug)
    )
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
        notify_episode_updates
        and old_episode
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


@asynccontextmanager
async def crawler_advisory_lock() -> AsyncIterator[None]:
    from app.db.session import engine

    connection = await engine.connect()
    locked = False
    try:
        locked = bool(
            (
                await connection.execute(
                    text("SELECT pg_try_advisory_lock(:key)"), {"key": FULL_SYNC_LOCK_KEY}
                )
            ).scalar_one()
        )
        if not locked:
            raise HTTPException(status_code=409, detail="Một tiến trình khác đang giữ khóa crawler")
        yield
    finally:
        if locked:
            await connection.execute(
                text("SELECT pg_advisory_unlock(:key)"), {"key": FULL_SYNC_LOCK_KEY}
            )
        await connection.close()


async def run_incremental_sync(
    db: AsyncSession, *, actor_id: str | None = None, max_pages: int | None = None
) -> dict:
    async with crawler_advisory_lock():
        return await _run_incremental_sync_unlocked(
            db, actor_id=actor_id, max_pages=max_pages
        )


async def _run_incremental_sync_unlocked(
    db: AsyncSession, *, actor_id: str | None = None, max_pages: int | None = None
) -> dict:
    if await cms_repo.has_running_sync(db):
        raise HTTPException(status_code=409, detail="Đang có tiến trình đồng bộ khác chạy")
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
    """Start catalog sync in the background (avoids proxy/gateway timeouts)."""
    if await cms_repo.has_running_sync(db):
        raise HTTPException(
            status_code=409, detail="Đang có job catalog chạy — đợi xong rồi thử lại"
        )

    run = SyncRun(job_type="catalog", status="running", page_from=1)
    await cms_repo.add_sync_run(db, run)
    await db.commit()

    asyncio.create_task(
        _execute_catalog_sync(
            run_id=run.id,
            actor_id=actor_id,
            pages_per_source=pages_per_source,
        )
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
            "async": True,
        },
    }


async def _execute_catalog_sync(
    *,
    run_id: str,
    actor_id: str | None,
    pages_per_source: int,
) -> None:
    try:
        async with crawler_advisory_lock():
            await _execute_catalog_sync_unlocked(
                run_id=run_id,
                actor_id=actor_id,
                pages_per_source=pages_per_source,
            )
    except HTTPException as exc:
        from app.db.session import AsyncSessionLocal

        async with AsyncSessionLocal() as db:
            run = await cms_repo.get_sync_run(db, run_id=run_id)
            if run:
                run.status = "failed"
                run.error = str(exc.detail)[:2000]
                run.finished_at = utcnow()
                await db.commit()


async def _execute_catalog_sync_unlocked(
    *,
    run_id: str,
    actor_id: str | None,
    pages_per_source: int,
) -> None:
    from app.db.session import AsyncSessionLocal

    client = get_nguonc_client()
    upserted = 0
    async with AsyncSessionLocal() as db:
        run = await cms_repo.get_sync_run(db, run_id=run_id)
        if not run:
            logger.error("Catalog sync run %s not found", run_id)
            return
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
                await db.commit()
        except Exception as exc:
            logger.exception("Catalog sync failed")
            await db.rollback()
            run = await cms_repo.get_sync_run(db, run_id=run_id)
            if run:
                run.status = "failed"
                run.error = str(exc)[:2000]
                run.items_upserted = upserted
                run.finished_at = utcnow()
                await db.commit()


def serialize_sync_run(run: SyncRun) -> dict:
    return {
        "id": run.id,
        "jobType": run.job_type,
        "status": run.status,
        "pageFrom": run.page_from,
        "pageTo": run.page_to,
        "checkpointPage": run.checkpoint_page,
        "totalPages": run.total_pages,
        "itemsUpserted": run.items_upserted,
        "itemsDiscovered": run.items_discovered,
        "itemsInserted": run.items_inserted,
        "itemsUpdated": run.items_updated,
        "itemsSkipped": run.items_skipped,
        "itemsFailed": run.items_failed,
        "imagesDownloaded": run.images_downloaded,
        "imagesFailed": run.images_failed,
        "error": run.error,
        "heartbeatAt": run.heartbeat_at,
        "startedAt": run.started_at,
        "finishedAt": run.finished_at,
    }


async def prepare_full_sync(
    db: AsyncSession, *, resume: bool, actor_id: str | None = None
) -> SyncRun:
    previous = await cms_repo.latest_sync_by_type(db, job_type="full")
    if previous and previous.status == "running":
        stale_before = utcnow() - timedelta(minutes=5)
        if not previous.heartbeat_at or previous.heartbeat_at >= stale_before:
            raise HTTPException(status_code=409, detail="Đang có job cào toàn bộ chạy")
        previous.status = "failed"
        previous.error = "Tiến trình cũ mất heartbeat; có thể resume"
        previous.finished_at = utcnow()
        await db.commit()
    if await cms_repo.has_running_sync(db):
        raise HTTPException(status_code=409, detail="Đang có tiến trình đồng bộ khác chạy")
    if resume and previous and previous.total_pages and previous.checkpoint_page < previous.total_pages:
        run = previous
        run.status = "running"
        run.error = None
        run.finished_at = None
        run.heartbeat_at = utcnow()
        run.params_json = json.dumps({"resume": True, "actorId": actor_id})
    else:
        run = SyncRun(
            job_type="full",
            status="running",
            page_from=1,
            heartbeat_at=utcnow(),
            params_json=json.dumps({"resume": False, "actorId": actor_id}),
        )
        await cms_repo.add_sync_run(db, run)
    await db.commit()
    return run


async def start_full_sync(
    db: AsyncSession, *, resume: bool = False, actor_id: str | None = None
) -> dict:
    run = await prepare_full_sync(db, resume=resume, actor_id=actor_id)
    asyncio.create_task(_execute_full_sync(run.id, actor_id=actor_id))
    return {"success": True, "data": {**serialize_sync_run(run), "async": True}}


async def run_full_sync_now(
    db: AsyncSession, *, resume: bool = False, actor_id: str | None = None
) -> dict:
    run = await prepare_full_sync(db, resume=resume, actor_id=actor_id)
    await _execute_full_sync(run.id, actor_id=actor_id)
    await db.refresh(run)
    return {"success": run.status == "success", "data": serialize_sync_run(run)}


async def run_images_sync_now(db: AsyncSession, *, batch_size: int = 50) -> dict:
    from app.db.session import engine

    if await cms_repo.has_running_sync(db):
        raise HTTPException(status_code=409, detail="Đang có tiến trình đồng bộ khác chạy")
    run = SyncRun(job_type="images", status="running", heartbeat_at=utcnow())
    await cms_repo.add_sync_run(db, run)
    await db.commit()
    connection = await engine.connect()
    locked = False
    try:
        locked = bool(
            (
                await connection.execute(
                    text("SELECT pg_try_advisory_lock(:key)"), {"key": FULL_SYNC_LOCK_KEY}
                )
            ).scalar_one()
        )
        if not locked:
            raise RuntimeError("Một tiến trình khác đang giữ khóa crawler")
        offset = 0
        while True:
            films = await film_repo.list_image_candidates(
                db, offset=offset, limit=max(1, batch_size)
            )
            if not films:
                break
            downloaded, failed = await mirror_film_images(films)
            run.items_discovered += len(films)
            run.images_downloaded += downloaded
            run.images_failed += failed
            run.heartbeat_at = utcnow()
            offset += len(films)
            await db.commit()
        run.status = "success"
        run.finished_at = utcnow()
        await db.commit()
    except Exception as exc:
        await db.rollback()
        run = await cms_repo.get_sync_run(db, run_id=run.id)
        if run:
            run.status = "failed"
            run.error = str(exc)[:2000]
            run.finished_at = utcnow()
            await db.commit()
    finally:
        if locked:
            await connection.execute(
                text("SELECT pg_advisory_unlock(:key)"), {"key": FULL_SYNC_LOCK_KEY}
            )
        await connection.close()
    return {"success": run.status == "success", "data": serialize_sync_run(run)}


async def _execute_full_sync(run_id: str, *, actor_id: str | None) -> None:
    from app.db.session import AsyncSessionLocal, engine

    lock_connection = await engine.connect()
    locked = False
    try:
        locked = bool(
            (
                await lock_connection.execute(
                    text("SELECT pg_try_advisory_lock(:key)"), {"key": FULL_SYNC_LOCK_KEY}
                )
            ).scalar_one()
        )
        if not locked:
            async with AsyncSessionLocal() as db:
                run = await cms_repo.get_sync_run(db, run_id=run_id)
                if run:
                    run.status = "failed"
                    run.error = "Một tiến trình đồng bộ khác đang giữ khóa crawler"
                    run.finished_at = utcnow()
                    await db.commit()
            return

        async with AsyncSessionLocal() as db:
            run = await cms_repo.get_sync_run(db, run_id=run_id)
            if not run:
                return
            client = get_nguonc_client()
            start_page = max(1, run.checkpoint_page + 1)
            try:
                page = start_page
                while True:
                    listing = await client.fetch_newest(page)
                    run.total_pages = listing.total_page
                    if not listing.items:
                        break

                    deduped = {item.slug: item for item in listing.items if item.slug}
                    run.items_discovered += len(listing.items)
                    existing = await film_repo.get_by_slugs(db, slugs=list(deduped))
                    page_films: list[Film] = []
                    for slug, item in deduped.items():
                        was_existing = slug in existing
                        try:
                            async with db.begin_nested():
                                film = await upsert_list_item(
                                    db,
                                    item,
                                    existing_by_slug=existing,
                                    notify_episode_updates=False,
                                )
                            page_films.append(film)
                            if was_existing:
                                run.items_updated += 1
                            else:
                                run.items_inserted += 1
                                existing[slug] = film
                        except Exception:  # noqa: BLE001
                            logger.exception("Could not upsert film %s", slug)
                            run.items_failed += 1

                    downloaded, image_failures = await mirror_film_images(page_films)
                    run.images_downloaded += downloaded
                    run.images_failed += image_failures
                    run.items_upserted = run.items_inserted + run.items_updated
                    run.checkpoint_page = page
                    run.page_to = page
                    run.heartbeat_at = utcnow()
                    await db.commit()
                    if page >= listing.total_page:
                        break
                    page += 1

                run.status = "success"
                run.finished_at = utcnow()
                run.heartbeat_at = utcnow()
                await db.commit()
                if actor_id:
                    await write_system_log(
                        db,
                        user_id=actor_id,
                        action="SYNC_FILMS_FULL",
                        resource="Sync",
                        details=(
                            f"pages={run.checkpoint_page}/{run.total_pages} "
                            f"films={run.items_upserted} images={run.images_downloaded}"
                        ),
                    )
                    await db.commit()
            except Exception as exc:
                logger.exception("Full film crawl failed")
                await db.rollback()
                run = await cms_repo.get_sync_run(db, run_id=run_id)
                if run:
                    run.status = "failed"
                    run.error = str(exc)[:2000]
                    run.finished_at = utcnow()
                    run.heartbeat_at = utcnow()
                    await db.commit()
    finally:
        if locked:
            await lock_connection.execute(
                text("SELECT pg_advisory_unlock(:key)"), {"key": FULL_SYNC_LOCK_KEY}
            )
        await lock_connection.close()


async def list_sync_runs(db: AsyncSession, *, page: int = 1, page_size: int = 20) -> dict:
    rows, total = await cms_repo.list_sync_runs(db, page=page, page_size=page_size)
    return {
        "success": True,
        "data": [serialize_sync_run(r) for r in rows],
        "total": total,
        "page": page,
        "pageSize": page_size,
    }
