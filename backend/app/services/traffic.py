from __future__ import annotations

import hashlib
import re
from datetime import timedelta

from fastapi import Request
from pydantic import Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories import traffic as traffic_repo
from app.schemas.common import ORMModel


class TrafficHitBody(ORMModel):
    path: str = Field(default="/")
    referrer: str | None = None
    language: str | None = None


def client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip() or "unknown"
    if request.client and request.client.host:
        return request.client.host
    return "unknown"


def visitor_fingerprint(request: Request) -> str:
    ip = client_ip(request)
    ua = request.headers.get("user-agent", "")[:200]
    raw = f"{ip}|{ua}".encode("utf-8", errors="ignore")
    return hashlib.sha256(raw).hexdigest()[:32]


def parse_user_agent(ua: str | None) -> dict[str, str | None]:
    text = (ua or "").strip()
    if not text:
        return {"device_type": None, "os_name": None, "browser_name": None}

    lower = text.lower()
    device_type = "desktop"
    if re.search(r"bot|spider|crawl|slurp|facebookexternalhit", lower):
        device_type = "bot"
    elif re.search(r"ipad|tablet|kindle|silk|playbook", lower):
        device_type = "tablet"
    elif re.search(r"mobi|iphone|ipod|android.*mobile|opera mini|windows phone", lower):
        device_type = "mobile"

    os_name = "Other"
    if "windows nt" in lower:
        os_name = "Windows"
    elif "android" in lower:
        os_name = "Android"
    elif "iphone" in lower or "ipad" in lower or "ipod" in lower:
        os_name = "iOS"
    elif "mac os x" in lower or "macintosh" in lower:
        os_name = "macOS"
    elif "cros" in lower:
        os_name = "ChromeOS"
    elif "linux" in lower:
        os_name = "Linux"

    browser_name = "Other"
    if "edg/" in lower or "edgios/" in lower:
        browser_name = "Edge"
    elif "opr/" in lower or "opera" in lower:
        browser_name = "Opera"
    elif "firefox/" in lower or "fxios/" in lower:
        browser_name = "Firefox"
    elif "chrome/" in lower or "crios/" in lower:
        browser_name = "Chrome"
    elif "safari/" in lower and "chrome/" not in lower and "crios/" not in lower:
        browser_name = "Safari"

    return {
        "device_type": device_type,
        "os_name": os_name,
        "browser_name": browser_name,
    }


async def hit(
    db: AsyncSession,
    *,
    request: Request,
    body: TrafficHitBody | None = None,
    user_id: str | None = None,
) -> dict:
    ua = request.headers.get("user-agent")
    parsed = parse_user_agent(ua)
    path = (body.path if body else None) or request.headers.get("x-page-path") or "/"
    referrer = (body.referrer if body else None) or request.headers.get("referer")
    language = (body.language if body else None) or request.headers.get("accept-language", "")[:64]

    await traffic_repo.record_hit(
        db,
        visitor_key=visitor_fingerprint(request),
        path=path,
        method="GET",
        ip=client_ip(request),
        user_agent=(ua or None) and ua[:1000],
        device_type=parsed["device_type"],
        os_name=parsed["os_name"],
        browser_name=parsed["browser_name"],
        referrer=referrer,
        language=language or None,
        user_id=user_id,
    )
    return {"success": True}


async def series_last_days(db: AsyncSession, *, days: int = 7) -> list[dict]:
    days = max(1, min(days, 30))
    end = traffic_repo.today_vn()
    start = end - timedelta(days=days - 1)
    rows = await traffic_repo.list_daily_range(db, start=start, end=end)
    by_day = {r.day: r for r in rows}
    logins = await traffic_repo.login_counts_by_day(db, start=start, end=end)

    out: list[dict] = []
    cursor = start
    while cursor <= end:
        row = by_day.get(cursor)
        out.append(
            {
                "date": cursor.isoformat(),
                "pageViews": int(row.page_views) if row else 0,
                "uniqueVisitors": int(row.unique_visitors) if row else 0,
                "logins": int(logins.get(cursor, 0)),
            }
        )
        cursor += timedelta(days=1)
    return out
