from __future__ import annotations

from fastapi import HTTPException, Response, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.cookies import clear_auth_cookies, set_access_cookie, set_auth_cookies
from app.core.security import (
    create_access_token,
    create_refresh_token,
    create_ws_ticket,
    safe_decode_token,
    verify_password,
)
from app.models import Role, RolePermission, Tenant, User, UserRole
from app.schemas import AuthDataOut, AuthUserOut, LoginRequest
from app.services.permissions_sync import collect_permissions_from_user, ensure_system_permissions
from app.services.system_log import write_system_log
from app.services.turnstile import verify_login_turnstile


def _user_options():
    return (
        selectinload(User.user_roles)
        .selectinload(UserRole.role)
        .selectinload(Role.role_permissions)
        .selectinload(RolePermission.permission)
    )


async def login(db: AsyncSession, body: LoginRequest, response: Response) -> dict:
    if not body.username or not body.password or not body.tenant_id:
        raise HTTPException(status_code=400, detail="Thiếu username, password hoặc tenant_id")
    if not body.turnstileToken:
        raise HTTPException(status_code=400, detail="Vui lòng xác minh Cloudflare Turnstile")

    turnstile = await verify_login_turnstile(body.turnstileToken)
    if not turnstile.get("success"):
        raise HTTPException(status_code=403, detail="Xác minh Turnstile thất bại")

    tenant_result = await db.execute(
        select(Tenant).where(Tenant.name == body.tenant_id, Tenant.deleted_at.is_(None))
    )
    tenant = tenant_result.scalar_one_or_none()
    if not tenant:
        raise HTTPException(status_code=404, detail="Không tìm thấy Workspace này")
    if not tenant.is_active:
        raise HTTPException(status_code=403, detail="Workspace đã bị khóa")

    await ensure_system_permissions(db, tenant.id)

    user_result = await db.execute(
        select(User)
        .where(
            User.username == body.username,
            User.tenant_id == tenant.id,
            User.deleted_at.is_(None),
        )
        .options(_user_options())
    )
    user = user_result.scalar_one_or_none()
    if not user or not verify_password(body.password, user.password):
        raise HTTPException(status_code=401, detail="Sai username hoặc mật khẩu")
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Tài khoản đã bị khóa")

    permissions = collect_permissions_from_user(user)
    access = create_access_token(user_id=user.id, username=user.username, tenant_id=tenant.id)
    refresh = create_refresh_token(user_id=user.id, tenant_id=tenant.id)
    set_auth_cookies(response, access_token=access, refresh_token=refresh)

    await write_system_log(
        db,
        tenant_id=tenant.id,
        user_id=user.id,
        action="LOGIN",
        resource="Auth",
        details={"username": user.username},
    )

    return {
        "success": True,
        "data": AuthDataOut(
            user=AuthUserOut(id=user.id, username=user.username, fullName=user.full_name),
            tenant_id=tenant.id,
            permissions=permissions,
        ).model_dump(),
    }


async def refresh(db: AsyncSession, refresh_token: str | None, response: Response) -> dict:
    if not refresh_token:
        raise HTTPException(status_code=401, detail="No refresh token")

    payload = safe_decode_token(refresh_token)
    if not payload or payload.get("type") != "refresh":
        clear_auth_cookies(response)
        raise HTTPException(status_code=401, detail="Refresh token expired or invalid")

    user_id = payload.get("userId")
    tenant_id = payload.get("tenant_id")
    user_result = await db.execute(
        select(User)
        .where(
            User.id == user_id,
            User.tenant_id == tenant_id,
            User.deleted_at.is_(None),
            User.is_active.is_(True),
        )
        .options(_user_options())
    )
    user = user_result.scalar_one_or_none()
    if not user:
        clear_auth_cookies(response)
        raise HTTPException(status_code=401, detail="User not found or disabled")

    permissions = collect_permissions_from_user(user)
    access = create_access_token(user_id=user.id, username=user.username, tenant_id=tenant_id)
    set_access_cookie(response, access_token=access)

    return {
        "success": True,
        "data": AuthDataOut(
            user=AuthUserOut(
                id=user.id,
                username=user.username,
                fullName=user.full_name,
                email=user.email,
                avatar=user.avatar,
            ),
            tenant_id=tenant_id,
            permissions=permissions,
        ).model_dump(),
    }


async def me(db: AsyncSession, user_id: str, tenant_id: str) -> dict:
    user_result = await db.execute(
        select(User)
        .where(User.id == user_id, User.tenant_id == tenant_id, User.deleted_at.is_(None))
        .options(_user_options())
    )
    user = user_result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    return {
        "success": True,
        "data": AuthDataOut(
            user=AuthUserOut(
                id=user.id,
                username=user.username,
                fullName=user.full_name,
                email=user.email,
                avatar=user.avatar,
            ),
            tenant_id=user.tenant_id,
            permissions=collect_permissions_from_user(user),
        ).model_dump(),
    }


def logout(response: Response) -> dict:
    clear_auth_cookies(response)
    return {"success": True}


def issue_ws_ticket(user_id: str, tenant_id: str) -> dict:
    return {"ticket": create_ws_ticket(user_id=user_id, tenant_id=tenant_id)}
