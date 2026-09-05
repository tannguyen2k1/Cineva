"""Daily film sync scheduler (default 00:00 Asia/Ho_Chi_Minh)."""

from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timedelta, time, timezone, tzinfo
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from app.core.config import get_settings
from app.db.session import AsyncSessionLocal
from app.services import film_sync as film_sync_service

logger = logging.getLogger(__name__)

_task: asyncio.Task | None = None
_FALLBACK_TZ = timezone(timedelta(hours=7))  # ICT


def _resolve_tz(name: str) -> tzinfo:
    try:
        return ZoneInfo(name)
    except ZoneInfoNotFoundError:
        logger.warning("Timezone %s unavailable; falling back to UTC+7", name)
        return _FALLBACK_TZ


def _next_run_at(now: datetime, *, hour: int, minute: int, tz: tzinfo) -> datetime:
    local = now.astimezone(tz)
    target = datetime.combine(local.date(), time(hour=hour, minute=minute), tzinfo=tz)
    if local >= target:
        target += timedelta(days=1)
    return target


async def _run_sync_once() -> None:
    async with AsyncSessionLocal() as db:
        result = await film_sync_service.run_incremental_sync(db, actor_id=None)
        upserted = (result.get("data") or {}).get("itemsUpserted")
        logger.info("Scheduled incremental sync finished itemsUpserted=%s", upserted)


async def _scheduler_loop() -> None:
    settings = get_settings()
    tz = _resolve_tz(settings.sync_schedule_timezone)
    hour = settings.sync_schedule_hour
    minute = settings.sync_schedule_minute

    while True:
        now = datetime.now(tz)
        nxt = _next_run_at(now, hour=hour, minute=minute, tz=tz)
        delay = max(1.0, (nxt - now).total_seconds())
        logger.info(
            "Film sync scheduled for %s (%s) — sleeping %.0fs",
            nxt.isoformat(),
            settings.sync_schedule_timezone,
            delay,
        )
        try:
            await asyncio.sleep(delay)
        except asyncio.CancelledError:
            raise

        try:
            await _run_sync_once()
        except asyncio.CancelledError:
            raise
        except Exception:
            logger.exception("Scheduled film sync failed")

        # Prevent immediate re-trigger if the run finishes within the same minute.
        await asyncio.sleep(60)


def start_sync_scheduler() -> None:
    global _task
    settings = get_settings()
    if not settings.sync_schedule_enabled:
        logger.info("Film sync scheduler disabled")
        return
    if _task and not _task.done():
        return
    _task = asyncio.create_task(_scheduler_loop(), name="film-sync-scheduler")
    logger.info(
        "Film sync scheduler started — daily %02d:%02d %s",
        settings.sync_schedule_hour,
        settings.sync_schedule_minute,
        settings.sync_schedule_timezone,
    )


async def stop_sync_scheduler() -> None:
    global _task
    if not _task:
        return
    _task.cancel()
    try:
        await _task
    except asyncio.CancelledError:
        pass
    _task = None
    logger.info("Film sync scheduler stopped")
