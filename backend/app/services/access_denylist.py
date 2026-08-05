from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import TOKEN_TYPE_ACCESS, safe_decode_token
from app.repositories import revoked_access_token as denylist_repo


def _exp_from_payload(payload: dict) -> datetime | None:
    exp = payload.get("exp")
    if exp is None:
        return None
    if isinstance(exp, (int, float)):
        return datetime.fromtimestamp(exp, tz=timezone.utc)
    if isinstance(exp, datetime):
        return exp if exp.tzinfo else exp.replace(tzinfo=timezone.utc)
    return None


async def revoke_access_token(db: AsyncSession, raw_token: str | None) -> None:
    """Put access JWT jti on denylist until natural expiry (no-op if invalid/missing)."""
    if not raw_token:
        return
    payload = safe_decode_token(raw_token)
    if not payload or payload.get("type") != TOKEN_TYPE_ACCESS:
        return
    jti = payload.get("jti")
    expires_at = _exp_from_payload(payload)
    if not jti or not expires_at:
        return
    await denylist_repo.revoke_jti(db, jti=jti, expires_at=expires_at)


async def is_access_revoked(db: AsyncSession, jti: str | None) -> bool:
    if not jti:
        return True
    return await denylist_repo.is_revoked(db, jti)
