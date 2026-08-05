from __future__ import annotations

from dataclasses import dataclass

from fastapi import Cookie, Depends, Header, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import TOKEN_TYPE_ACCESS, safe_decode_token
from app.db.session import get_db
from app.models import User
from app.repositories import user as user_repo
from app.services.permissions_sync import collect_permissions_from_user


@dataclass
class CurrentUser:
    id: str
    username: str
    tenant_id: str
    permissions: set[str]


async def _load_user(db: AsyncSession, user_id: str, tenant_id: str) -> User | None:
    return await user_repo.get_by_id(
        db,
        user_id=user_id,
        tenant_id=tenant_id,
        with_permissions=True,
        active_only=True,
    )


def extract_token(
    auth_token: str | None = Cookie(default=None),
    authorization: str | None = Header(default=None),
) -> str | None:
    if auth_token:
        return auth_token
    if authorization and authorization.startswith("Bearer "):
        return authorization[7:] or None
    return None


async def get_current_user(
    db: AsyncSession = Depends(get_db),
    token: str | None = Depends(extract_token),
) -> CurrentUser:
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Unauthorized")

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

    user_id = payload.get("userId") or payload.get("sub")
    tenant_id = payload.get("tenant_id")
    if not user_id or not tenant_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Unauthorized: Malformed token",
        )

    user = await _load_user(db, user_id, tenant_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Unauthorized: User not found or disabled",
        )

    return CurrentUser(
        id=user.id,
        username=user.username,
        tenant_id=user.tenant_id,
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
