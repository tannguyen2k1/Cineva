from __future__ import annotations

import logging

from fastapi import HTTPException, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.cookies import clear_auth_cookies, set_auth_cookies
from app.core.config import get_settings
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
from app.schemas import AuthDataOut, AuthUserOut, LoginRequest, OAuth2TokenOut
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

logger = logging.getLogger("app.auth")


def _token_response(*, access: str, refresh: str) -> OAuth2TokenOut:
    settings = get_settings()
    return OAuth2TokenOut(
        access_token=access,
        token_type="bearer",
        expires_in=settings.access_token_ttl_minutes * 60,
        refresh_token=refresh,
    )


def _auth_data(user: User, permissions: list[str]) -> dict:
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
        ).model_dump(),
    }


async def _create_token_pair(
    db: AsyncSession,
    *,
    user: User,
    family_id: str | None = None,
) -> tuple[list[str], str, str]:
    """Issue access + refresh JWTs and persist the refresh row. No cookies."""
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
    return permissions, access, refresh


async def _issue_cookie_session(
    db: AsyncSession,
    response: Response,
    *,
    user: User,
    family_id: str | None = None,
) -> list[str]:
    permissions, access, refresh = await _create_token_pair(
        db, user=user, family_id=family_id
    )
    set_auth_cookies(response, access_token=access, refresh_token=refresh)
    return permissions


async def _authenticate_password(db: AsyncSession, username: str, password: str) -> User:
    if not username or not password:
        raise HTTPException(status_code=400, detail="Thiếu username hoặc mật khẩu")

    await ensure_system_permissions(db)

    user = await user_repo.get_by_username(
        db, username=username, with_permissions=True
    )
    if not user or not verify_password(password, user.password):
        raise HTTPException(status_code=401, detail="Sai username hoặc mật khẩu")
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Tài khoản đã bị khóa")
    return user


async def login(db: AsyncSession, body: LoginRequest, response: Response) -> dict:
    """Browser login: HttpOnly cookies only (no access token in JSON)."""
    if not body.turnstileToken:
        raise HTTPException(status_code=400, detail="Vui lòng xác minh Cloudflare Turnstile")

    turnstile = await verify_login_turnstile(body.turnstileToken)
    if not turnstile.get("success"):
        raise HTTPException(status_code=403, detail="Xác minh Turnstile thất bại")

    user = await _authenticate_password(db, body.username, body.password)
    permissions = await _issue_cookie_session(db, response, user=user)

    await write_system_log(
        db,
        user_id=user.id,
        action="LOGIN",
        resource="Auth",
        details={"username": user.username, "channel": "cookie"},
    )

    return _auth_data(user, permissions)


async def oauth2_token(
    db: AsyncSession,
    *,
    grant_type: str,
    username: str | None = None,
    password: str | None = None,
    refresh_token: str | None = None,
) -> OAuth2TokenOut:
    """
    OAuth2 token endpoint for API clients / Scalar.
    Returns Bearer tokens in the body — does not set cookies.
    """
    grant = (grant_type or "password").strip().lower()

    if grant == "password":
        user = await _authenticate_password(db, username or "", password or "")
        _permissions, access, refresh = await _create_token_pair(db, user=user)

        await write_system_log(
            db,
            user_id=user.id,
            action="OAUTH2_TOKEN",
            resource="Auth",
            details={"username": user.username, "grant": "password"},
        )
        return _token_response(access=access, refresh=refresh)

    if grant == "refresh_token":
        return await _oauth2_refresh(db, refresh_token)

    raise HTTPException(
        status_code=400,
        detail="unsupported_grant_type: use password or refresh_token",
    )


async def _oauth2_refresh(db: AsyncSession, refresh_token: str | None) -> OAuth2TokenOut:
    if not refresh_token:
        raise HTTPException(status_code=400, detail="missing refresh_token")

    payload = safe_decode_token(refresh_token)
    if not payload or payload.get("type") != TOKEN_TYPE_REFRESH:
        raise HTTPException(status_code=401, detail="invalid_grant: refresh token expired or invalid")

    row = await get_active_refresh_by_raw(db, refresh_token)
    if row is None:
        raise HTTPException(status_code=401, detail="invalid_grant: refresh token expired or invalid")

    if row.revoked_at is not None:
        await revoke_family(db, row.family_id)
        await db.commit()
        raise HTTPException(status_code=401, detail="invalid_grant: refresh token reuse detected")

    jti = payload.get("jti")
    if not jti or jti != row.id:
        raise HTTPException(status_code=401, detail="invalid_grant: refresh token expired or invalid")

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
        raise HTTPException(status_code=401, detail="invalid_grant: user not found or disabled")

    new_jti_val = new_jti()
    await revoke_token(db, row, replaced_by=new_jti_val)

    access = create_access_token(user_id=user.id, username=user.username)
    new_refresh, expires_at = create_refresh_token(user_id=user.id, jti=new_jti_val)
    await create_refresh_session(
        db,
        user_id=user.id,
        raw_token=new_refresh,
        jti=new_jti_val,
        family_id=row.family_id,
        expires_at=expires_at,
    )
    await db.commit()
    return _token_response(access=access, refresh=new_refresh)


async def refresh(
    db: AsyncSession,
    refresh_token: str | None,
    response: Response,
    *,
    access_token: str | None = None,
) -> dict:
    """Browser refresh: rotate cookies only (no access token in JSON)."""
    if not refresh_token:
        logger.warning("refresh denied: no refresh_token cookie")
        raise HTTPException(status_code=401, detail="No refresh token")

    logger.info(
        "refresh attempt: token length=%d, first8=%s",
        len(refresh_token),
        refresh_token[:8] if refresh_token else "N/A",
    )
    payload = safe_decode_token(refresh_token)
    if not payload:
        from jose import JWTError as _JE
        from jose import jwt as _jwt

        from app.core.config import get_settings as _gs
        try:
            _jwt.decode(refresh_token, _gs().jwt_secret, algorithms=["HS256"])
        except _JE as decode_err:
            logger.warning("refresh denied: decode failed — %s", decode_err)
        except Exception as decode_err:  # noqa: BLE001
            logger.warning("refresh denied: unexpected decode error — %s", decode_err)
        clear_auth_cookies(response)
        raise HTTPException(status_code=401, detail="Refresh token expired or invalid")
    if payload.get("type") != TOKEN_TYPE_REFRESH:
        logger.warning("refresh denied: wrong type=%s", payload.get("type"))
        clear_auth_cookies(response)
        raise HTTPException(status_code=401, detail="Refresh token expired or invalid")

    row = await get_active_refresh_by_raw(db, refresh_token)
    if row is None:
        logger.warning("refresh denied: token not in db or expired")
        clear_auth_cookies(response)
        raise HTTPException(status_code=401, detail="Refresh token expired or invalid")

    if row.revoked_at is not None:
        logger.warning("refresh denied: reuse detected family=%s", row.family_id)
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
    new_refresh, expires_at = create_refresh_token(user_id=user.id, jti=new_jti_val)
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

    return _auth_data(user, permissions)


async def me(db: AsyncSession, user_id: str) -> dict:
    user = await user_repo.get_by_id(db, user_id=user_id, with_permissions=True)
    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    return _auth_data(user, collect_permissions_from_user(user))


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


async def register(db: AsyncSession, body, response: Response) -> dict:
    """Public member registration — assigns Member role, issues cookie session."""
    from app.core.security import hash_password
    from app.repositories import role as role_repo
    from app.schemas.film import RegisterRequest

    if not isinstance(body, RegisterRequest):
        body = RegisterRequest.model_validate(body)

    username = body.username.strip()
    if await user_repo.find_active_username(db, username=username):
        raise HTTPException(status_code=409, detail="Username đã tồn tại")

    member = await role_repo.find_by_name(db, name="Member")
    if not member:
        from app.models import Role

        member = await role_repo.add_role(
            db, Role(name="Member", description="Thành viên xem phim")
        )

    user = await user_repo.add_user(
        db,
        User(
            username=username,
            password=hash_password(body.password),
            email=body.email,
            full_name=body.full_name,
            is_active=True,
        ),
    )
    await user_repo.add_user_roles(db, user_id=user.id, role_ids=[member.id])
    await db.commit()

    user = await user_repo.get_by_id(db, user_id=user.id, with_permissions=True)
    assert user is not None
    permissions = await _issue_cookie_session(db, response, user=user)

    await write_system_log(
        db,
        user_id=user.id,
        action="REGISTER",
        resource="Auth",
        details={"username": user.username},
    )
    return _auth_data(user, permissions)
