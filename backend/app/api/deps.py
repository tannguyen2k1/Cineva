from __future__ import annotations

from dataclasses import dataclass

from fastapi import Cookie, Depends, Header, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.security import safe_decode_token
from app.db.session import get_db
from app.models import Role, RolePermission, User, UserRole
from app.services.permissions_sync import collect_permissions_from_user


@dataclass
class CurrentUser:
    id: str
    username: str
    tenant_id: str
    permissions: set[str]


async def _load_user(db: AsyncSession, user_id: str, tenant_id: str) -> User | None:
    result = await db.execute(
        select(User)
        .where(
            User.id == user_id,
            User.tenant_id == tenant_id,
            User.deleted_at.is_(None),
            User.is_active.is_(True),
        )
        .options(
            selectinload(User.user_roles)
            .selectinload(UserRole.role)
            .selectinload(Role.role_permissions)
            .selectinload(RolePermission.permission)
        )
    )
    return result.scalar_one_or_none()


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

    user_id = payload.get("userId")
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
