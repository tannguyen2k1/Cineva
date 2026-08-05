from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import new_jti
from app.models import RefreshToken, User
from app.repositories import refresh_token as refresh_token_repo


async def create_refresh_session(
    db: AsyncSession,
    *,
    user_id: str,
    tenant_id: str,
    raw_token: str,
    jti: str,
    family_id: str,
    expires_at: datetime,
) -> RefreshToken:
    return await refresh_token_repo.create(
        db,
        jti=jti,
        family_id=family_id,
        user_id=user_id,
        tenant_id=tenant_id,
        raw_token=raw_token,
        expires_at=expires_at,
    )


async def get_active_refresh_by_raw(
    db: AsyncSession, raw_token: str
) -> RefreshToken | None:
    row = await refresh_token_repo.get_by_raw_token(db, raw_token)
    if not row:
        return None
    if row.revoked_at is not None:
        return row  # caller handles reuse / revoked
    now = datetime.now(timezone.utc)
    exp = row.expires_at
    if exp.tzinfo is None:
        exp = exp.replace(tzinfo=timezone.utc)
    if exp <= now:
        return None
    return row


async def revoke_token(
    db: AsyncSession, row: RefreshToken, *, replaced_by: str | None = None
) -> None:
    await refresh_token_repo.revoke(db, row, replaced_by=replaced_by)


async def revoke_family(db: AsyncSession, family_id: str) -> None:
    """Revoke entire rotation chain — used on refresh-token reuse (theft)."""
    await refresh_token_repo.revoke_family(db, family_id)


async def revoke_user_sessions(db: AsyncSession, user_id: str) -> None:
    """Revoke all refresh sessions + invalidate access JWTs for a user.

    Sets tokens_invalid_before so every device's access token fails immediately
    (not only after TTL / jti denylist of the current cookie).
    """
    now = datetime.now(timezone.utc)
    await db.execute(
        update(User).where(User.id == user_id).values(tokens_invalid_before=now)
    )
    await refresh_token_repo.revoke_user_sessions(db, user_id)


def next_refresh_ids() -> tuple[str, str]:
    """Return (jti, family_id) for a brand-new login session."""
    return new_jti(), new_jti()
