from __future__ import annotations

from datetime import datetime

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_token
from app.core.timeutil import as_utc, utcnow
from app.models import RefreshToken


async def create(
    db: AsyncSession,
    *,
    jti: str,
    family_id: str,
    user_id: str,
    tenant_id: str,
    raw_token: str,
    expires_at: datetime,
) -> RefreshToken:
    row = RefreshToken(
        id=jti,
        family_id=family_id,
        user_id=user_id,
        tenant_id=tenant_id,
        token_hash=hash_token(raw_token),
        expires_at=as_utc(expires_at),
    )
    db.add(row)
    await db.flush()
    return row


async def get_by_raw_token(db: AsyncSession, raw_token: str) -> RefreshToken | None:
    token_hash = hash_token(raw_token)
    return (
        await db.execute(
            select(RefreshToken).where(RefreshToken.token_hash == token_hash)
        )
    ).scalar_one_or_none()


async def revoke(db: AsyncSession, row: RefreshToken, *, replaced_by: str | None = None) -> None:
    row.revoked_at = utcnow()
    if replaced_by:
        row.replaced_by = replaced_by


async def revoke_family(db: AsyncSession, family_id: str) -> None:
    now = utcnow()
    await db.execute(
        update(RefreshToken)
        .where(RefreshToken.family_id == family_id, RefreshToken.revoked_at.is_(None))
        .values(revoked_at=now)
    )


async def revoke_user_sessions(db: AsyncSession, user_id: str) -> None:
    now = utcnow()
    await db.execute(
        update(RefreshToken)
        .where(RefreshToken.user_id == user_id, RefreshToken.revoked_at.is_(None))
        .values(revoked_at=now)
    )
