from __future__ import annotations

from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.timeutil import utcnow
from app.models.base_fields import new_uuid
from app.models.site_traffic import SiteTrafficDaily, SiteVisit, SiteVisitorDay
from app.models.system_log import SystemLog


def _vn_tz():
    name = get_settings().sync_schedule_timezone or "Asia/Ho_Chi_Minh"
    try:
        return ZoneInfo(name)
    except ZoneInfoNotFoundError:
        return timezone(timedelta(hours=7))


def today_vn() -> date:
    return datetime.now(_vn_tz()).date()


async def add_visit(db: AsyncSession, visit: SiteVisit) -> SiteVisit:
    db.add(visit)
    await db.flush()
    return visit


async def record_hit(
    db: AsyncSession,
    *,
    visitor_key: str,
    path: str,
    method: str = "GET",
    ip: str | None = None,
    user_agent: str | None = None,
    device_type: str | None = None,
    os_name: str | None = None,
    browser_name: str | None = None,
    referrer: str | None = None,
    language: str | None = None,
    user_id: str | None = None,
) -> None:
    day = today_vn()
    now = utcnow()

    await add_visit(
        db,
        SiteVisit(
            path=(path or "/")[:512],
            method=(method or "GET")[:16],
            ip=(ip or None) and ip[:64],
            user_agent=user_agent,
            device_type=(device_type or None) and device_type[:32],
            os_name=(os_name or None) and os_name[:64],
            browser_name=(browser_name or None) and browser_name[:64],
            referrer=(referrer or None) and referrer[:1024],
            language=(language or None) and language[:64],
            visitor_key=visitor_key[:64],
            user_id=user_id,
            created_at=now,
        ),
    )

    stmt = (
        pg_insert(SiteTrafficDaily)
        .values(day=day, page_views=1, unique_visitors=0, updated_at=now)
        .on_conflict_do_update(
            index_elements=[SiteTrafficDaily.day],
            set_={
                "page_views": SiteTrafficDaily.page_views + 1,
                "updated_at": now,
            },
        )
    )
    await db.execute(stmt)

    visitor_stmt = (
        pg_insert(SiteVisitorDay)
        .values(id=new_uuid(), day=day, visitor_key=visitor_key[:64], created_at=now)
        .on_conflict_do_nothing(constraint="uq_site_visitor_day_key")
        .returning(SiteVisitorDay.id)
    )
    result = await db.execute(visitor_stmt)
    if result.scalar_one_or_none():
        row = await db.get(SiteTrafficDaily, day)
        if row:
            row.unique_visitors = int(row.unique_visitors or 0) + 1
            row.updated_at = now

    await db.commit()


async def list_daily_range(
    db: AsyncSession, *, start: date, end: date
) -> list[SiteTrafficDaily]:
    result = await db.execute(
        select(SiteTrafficDaily)
        .where(SiteTrafficDaily.day >= start, SiteTrafficDaily.day <= end)
        .order_by(SiteTrafficDaily.day.asc())
    )
    return list(result.scalars().all())


async def login_counts_by_day(
    db: AsyncSession, *, start: date, end: date
) -> dict[date, int]:
    local_tz = _vn_tz()
    start_local = datetime.combine(start, datetime.min.time(), tzinfo=local_tz)
    end_local = datetime.combine(end + timedelta(days=1), datetime.min.time(), tzinfo=local_tz)
    start_utc = start_local.astimezone(timezone.utc)
    end_utc = end_local.astimezone(timezone.utc)

    result = await db.execute(
        select(SystemLog.created_at).where(
            SystemLog.action == "LOGIN",
            SystemLog.created_at >= start_utc,
            SystemLog.created_at < end_utc,
        )
    )
    counts: dict[date, int] = {}
    for (created_at,) in result.all():
        if created_at is None:
            continue
        local_day = created_at.astimezone(local_tz).date()
        counts[local_day] = counts.get(local_day, 0) + 1
    return counts
