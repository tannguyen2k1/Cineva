from __future__ import annotations

from datetime import datetime

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.timeutil import as_utc, utcnow
from app.models.revoked_access_token import RevokedAccessToken


async def revoke_jti(
    db: AsyncSession, *, jti: str, expires_at: datetime
) -> None:
    existing = await db.get(RevokedAccessToken, jti)
    if existing:
        return
    db.add(RevokedAccessToken(jti=jti, expires_at=as_utc(expires_at)))
    await db.flush()


async def is_revoked(db: AsyncSession, jti: str) -> bool:
    row = (
        await db.execute(select(RevokedAccessToken).where(RevokedAccessToken.jti == jti))
    ).scalar_one_or_none()
    if not row:
        return False
    now = utcnow()
    if as_utc(row.expires_at) <= now:
        await db.delete(row)
        await db.flush()
        return False
    return True


async def purge_expired(db: AsyncSession) -> None:
    now = utcnow()
    await db.execute(
        delete(RevokedAccessToken).where(RevokedAccessToken.expires_at <= now)
    )
