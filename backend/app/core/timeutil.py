"""UTC datetime helpers — always prefer aware UTC, never naive local time."""

from __future__ import annotations

from datetime import date, datetime, time, timezone


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def as_utc(value: datetime) -> datetime:
    """Normalize to timezone-aware UTC (naive treated as UTC)."""
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def unix_ts(value: datetime | None = None) -> int:
    """JWT-style second precision UTC timestamp."""
    return int(as_utc(value or utcnow()).timestamp())


def from_unix_ts(ts: int | float) -> datetime:
    return datetime.fromtimestamp(ts, tz=timezone.utc)


def to_iso_utc(value: datetime | None = None) -> str:
    """Serialize as `...Z` for API clients."""
    return as_utc(value or utcnow()).isoformat().replace("+00:00", "Z")


def parse_iso_utc(value: str) -> datetime:
    """Parse ISO date/datetime; if offset present convert to UTC, else assume UTC."""
    raw = value.strip()
    if raw.endswith("Z"):
        raw = raw[:-1] + "+00:00"
    dt = datetime.fromisoformat(raw)
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def start_of_day_utc(value: str | date | datetime) -> datetime:
    if isinstance(value, str):
        dt = parse_iso_utc(value)
    elif isinstance(value, datetime):
        dt = as_utc(value)
    else:
        return datetime.combine(value, time.min, tzinfo=timezone.utc)
    return datetime.combine(dt.date(), time.min, tzinfo=timezone.utc)


def end_of_day_utc(value: str | date | datetime) -> datetime:
    if isinstance(value, str):
        dt = parse_iso_utc(value)
    elif isinstance(value, datetime):
        dt = as_utc(value)
    else:
        return datetime.combine(value, time(23, 59, 59, 999999), tzinfo=timezone.utc)
    return datetime.combine(dt.date(), time(23, 59, 59, 999999), tzinfo=timezone.utc)


def parse_filter_instant(value: str, *, end: bool = False) -> datetime:
    """Parse filter bound from FE.

    - Full ISO with time/offset → convert to UTC as-is.
    - Date-only `YYYY-MM-DD` → that calendar day in UTC (legacy); prefer FE sending ISO.
    """
    raw = value.strip()
    if "T" in raw or " " in raw:
        return parse_iso_utc(raw)
    return end_of_day_utc(raw) if end else start_of_day_utc(raw)


def is_jwt_issued_before(iat: datetime, cutoff: datetime) -> bool:
    """Compare at second precision — JWT iat is typically an int unix second."""
    return unix_ts(iat) < unix_ts(cutoff)


def register_fastapi_utc_json() -> None:
    """Make FastAPI/Pydantic JSON encode datetimes as `...Z` (UTC)."""
    from fastapi.encoders import ENCODERS_BY_TYPE

    ENCODERS_BY_TYPE[datetime] = to_iso_utc
