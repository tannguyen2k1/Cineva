from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime

from fastapi import Cookie, Depends, Header, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import TOKEN_TYPE_ACCESS, safe_decode_token
from app.core.timeutil import as_utc, from_unix_ts, is_jwt_issued_before
from app.db.session import get_db
from app.models import User
from app.repositories import user as user_repo
from app.services.access_denylist import is_access_revoked
from app.services.permissions_sync import collect_permissions_from_user


@dataclass
class CurrentUser:
    id: str
    username: str
    permissions: set[str]


async def _load_user(db: AsyncSession, user_id: str) -> User | None:
    return await user_repo.get_by_id(
        db,
        user_id=user_id,
        with_permissions=True,
        active_only=True,
    )


def _token_issued_at(payload: dict) -> datetime | None:
    iat = payload.get("iat")
    if iat is None:
        return None
    if isinstance(iat, (int, float)):
        return from_unix_ts(iat)
    if isinstance(iat, datetime):
        return as_utc(iat)
    return None


def extract_token(
    auth_token: str | None = Cookie(default=None),
    authorization: str | None = Header(default=None),
) -> str | None:
    # Bearer wins when present (Scalar / API clients); else HttpOnly cookie (Nuxt).
    if authorization and authorization.startswith("Bearer "):
        return authorization[7:] or None
    if auth_token:
        return auth_token
    return None


async def get_current_user(
    db: AsyncSession = Depends(get_db),
    token: str | None = Depends(extract_token),
) -> CurrentUser:
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Unauthorized")

    return await _resolve_user(db, token)


async def get_optional_user(
    db: AsyncSession = Depends(get_db),
    token: str | None = Depends(extract_token),
) -> CurrentUser | None:
    if not token:
        return None
    try:
        return await _resolve_user(db, token)
    except HTTPException:
        return None


async def _resolve_user(db: AsyncSession, token: str) -> CurrentUser:
    payload = safe_decode_token(token)
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Unauthorized: Token expired or invalid",
        )

    if payload.get("type") != TOKEN_TYPE_ACCESS:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Unauthorized: Invalid token type",
        )

    jti = payload.get("jti")
    if await is_access_revoked(db, jti):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Unauthorized: Token revoked",
        )

    user_id = payload.get("userId") or payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Unauthorized: Malformed token",
        )

    user = await _load_user(db, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Unauthorized: User not found or disabled",
        )

    issued_at = _token_issued_at(payload)
    cutoff = user.tokens_invalid_before
    if cutoff is not None and issued_at is not None:
        if is_jwt_issued_before(issued_at, as_utc(cutoff)):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Unauthorized: Token revoked",
            )

    return CurrentUser(
        id=user.id,
        username=user.username,
        permissions=set(collect_permissions_from_user(user)),
    )


def require_permission(permission: str):
    async def _checker(current: CurrentUser = Depends(get_current_user)) -> CurrentUser:
        if permission not in current.permissions:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f'Forbidden: requires "{permission}"',
            )
        return current

    return _checker
