from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.revoked_access_token import RevokedAccessToken


async def revoke_jti(
    db: AsyncSession, *, jti: str, expires_at: datetime
) -> None:
    existing = await db.get(RevokedAccessToken, jti)
    if existing:
        return
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    db.add(RevokedAccessToken(jti=jti, expires_at=expires_at))
    await db.flush()


async def is_revoked(db: AsyncSession, jti: str) -> bool:
    row = (
        await db.execute(select(RevokedAccessToken).where(RevokedAccessToken.jti == jti))
    ).scalar_one_or_none()
    if not row:
        return False
    now = datetime.now(timezone.utc)
    exp = row.expires_at
    if exp.tzinfo is None:
        exp = exp.replace(tzinfo=timezone.utc)
    if exp <= now:
        await db.delete(row)
        await db.flush()
        return False
    return True


async def purge_expired(db: AsyncSession) -> None:
    now = datetime.now(timezone.utc)
    await db.execute(
        delete(RevokedAccessToken).where(RevokedAccessToken.expires_at <= now)
    )
