from __future__ import annotations

from fastapi import HTTPException, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.cookies import clear_auth_cookies, set_auth_cookies
from app.core.security import (
    TOKEN_TYPE_REFRESH,
    create_access_token,
    create_refresh_token,
    create_ws_ticket,
    new_jti,
    safe_decode_token,
    verify_password,
)
from app.models import User
from app.repositories import user as user_repo
from app.schemas import AuthDataOut, AuthUserOut, LoginRequest
from app.services.access_denylist import revoke_access_token
from app.services.permissions_sync import collect_permissions_from_user, ensure_system_permissions
from app.services.refresh_sessions import (
    create_refresh_session,
    get_active_refresh_by_raw,
    next_refresh_ids,
    revoke_family,
    revoke_token,
)
from app.services.system_log import write_system_log
from app.services.turnstile import verify_login_turnstile


async def _issue_session(
    db: AsyncSession,
    response: Response,
    *,
    user: User,
    family_id: str | None = None,
) -> tuple[list[str], str]:
    permissions = collect_permissions_from_user(user)
    access = create_access_token(user_id=user.id, username=user.username)

    jti = new_jti()
    fam = family_id or next_refresh_ids()[1]
    refresh, expires_at = create_refresh_token(user_id=user.id, jti=jti)
    await create_refresh_session(
        db,
        user_id=user.id,
        raw_token=refresh,
        jti=jti,
        family_id=fam,
        expires_at=expires_at,
    )
    await db.commit()

    set_auth_cookies(response, access_token=access, refresh_token=refresh)
    return permissions, access


async def login(db: AsyncSession, body: LoginRequest, response: Response) -> dict:
    if not body.username or not body.password:
        raise HTTPException(status_code=400, detail="Thiếu username hoặc password")
    if not body.turnstileToken:
        raise HTTPException(status_code=400, detail="Vui lòng xác minh Cloudflare Turnstile")

    turnstile = await verify_login_turnstile(body.turnstileToken)
    if not turnstile.get("success"):
        raise HTTPException(status_code=403, detail="Xác minh Turnstile thất bại")

    await ensure_system_permissions(db)

    user = await user_repo.get_by_username(
        db, username=body.username, with_permissions=True
    )
    if not user or not verify_password(body.password, user.password):
        raise HTTPException(status_code=401, detail="Sai username hoặc mật khẩu")
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Tài khoản đã bị khóa")

    permissions, access = await _issue_session(db, response, user=user)

    await write_system_log(
        db,
        user_id=user.id,
        action="LOGIN",
        resource="Auth",
        details={"username": user.username},
    )

    return {
        "success": True,
        "data": AuthDataOut(
            user=AuthUserOut(id=user.id, username=user.username, fullName=user.full_name),
            permissions=permissions,
            accessToken=access,
        ).model_dump(),
    }


async def refresh(
    db: AsyncSession,
    refresh_token: str | None,
    response: Response,
    *,
    access_token: str | None = None,
) -> dict:
    if not refresh_token:
        raise HTTPException(status_code=401, detail="No refresh token")

    payload = safe_decode_token(refresh_token)
    if not payload or payload.get("type") != TOKEN_TYPE_REFRESH:
        clear_auth_cookies(response)
        raise HTTPException(status_code=401, detail="Refresh token expired or invalid")

    row = await get_active_refresh_by_raw(db, refresh_token)
    if row is None:
        clear_auth_cookies(response)
        raise HTTPException(status_code=401, detail="Refresh token expired or invalid")

    if row.revoked_at is not None:
        await revoke_family(db, row.family_id)
        await db.commit()
        clear_auth_cookies(response)
        raise HTTPException(status_code=401, detail="Refresh token reuse detected")

    jti = payload.get("jti")
    if not jti or jti != row.id:
        clear_auth_cookies(response)
        raise HTTPException(status_code=401, detail="Refresh token expired or invalid")

    user_id = payload.get("userId") or payload.get("sub")
    user = await user_repo.get_by_id(
        db,
        user_id=user_id,
        with_permissions=True,
        active_only=True,
    )
    if not user:
        await revoke_family(db, row.family_id)
        await db.commit()
        clear_auth_cookies(response)
        raise HTTPException(status_code=401, detail="User not found or disabled")

    await revoke_access_token(db, access_token)
    new_jti_val = new_jti()
    await revoke_token(db, row, replaced_by=new_jti_val)

    permissions = collect_permissions_from_user(user)
    access = create_access_token(user_id=user.id, username=user.username)
    new_refresh, expires_at = create_refresh_token(
        user_id=user.id, jti=new_jti_val
    )
    await create_refresh_session(
        db,
        user_id=user.id,
        raw_token=new_refresh,
        jti=new_jti_val,
        family_id=row.family_id,
        expires_at=expires_at,
    )
    await db.commit()
    set_auth_cookies(response, access_token=access, refresh_token=new_refresh)

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
            permissions=permissions,
            accessToken=access,
        ).model_dump(),
    }


async def me(db: AsyncSession, user_id: str) -> dict:
    user = await user_repo.get_by_id(
        db, user_id=user_id, with_permissions=True
    )
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
            permissions=collect_permissions_from_user(user),
        ).model_dump(),
    }


async def logout(
    db: AsyncSession,
    response: Response,
    refresh_token: str | None,
    *,
    access_token: str | None = None,
) -> dict:
    await revoke_access_token(db, access_token)
    if refresh_token:
        payload = safe_decode_token(refresh_token)
        row = await get_active_refresh_by_raw(db, refresh_token)
        if row and row.revoked_at is None:
            await revoke_family(db, row.family_id)
        elif payload and payload.get("type") == TOKEN_TYPE_REFRESH:
            pass
    await db.commit()
    clear_auth_cookies(response)
    return {"success": True}


def issue_ws_ticket(user_id: str) -> dict:
    return {"ticket": create_ws_ticket(user_id=user_id)}
