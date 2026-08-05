from __future__ import annotations

import secrets

from fastapi import Response

from app.core.config import get_settings

CSRF_COOKIE = "csrf_token"
CSRF_HEADER = "x-csrf-token"


def new_csrf_token() -> str:
    return secrets.token_urlsafe(32)


def set_csrf_cookie(response: Response, token: str | None = None) -> str:
    settings = get_settings()
    value = token or new_csrf_token()
    response.set_cookie(
        key=CSRF_COOKIE,
        value=value,
        httponly=False,  # double-submit: JS must read and send as header
        secure=settings.is_prod,
        samesite="lax",
        path="/",
        max_age=settings.refresh_token_ttl_days * 24 * 60 * 60,
    )
    return value


def clear_csrf_cookie(response: Response) -> None:
    settings = get_settings()
    response.set_cookie(
        key=CSRF_COOKIE,
        value="",
        httponly=False,
        secure=settings.is_prod,
        samesite="lax",
        path="/",
        max_age=0,
    )


def set_auth_cookies(response: Response, *, access_token: str, refresh_token: str) -> None:
    settings = get_settings()
    secure = settings.is_prod
    access_max = settings.access_token_ttl_minutes * 60
    refresh_max = settings.refresh_token_ttl_days * 24 * 60 * 60

    response.set_cookie(
        key="auth_token",
        value=access_token,
        httponly=True,
        secure=secure,
        samesite="lax",
        path="/",
        max_age=access_max,
    )
    response.set_cookie(
        key="refresh_token",
        value=refresh_token,
        httponly=True,
        secure=secure,
        samesite="lax",
        path="/api/auth",
        max_age=refresh_max,
    )
    response.set_cookie(
        key="auth_logged_in",
        value="1",
        httponly=False,
        secure=secure,
        samesite="lax",
        path="/",
        max_age=refresh_max,
    )
    set_csrf_cookie(response)


def set_access_cookie(response: Response, *, access_token: str) -> None:
    settings = get_settings()
    response.set_cookie(
        key="auth_token",
        value=access_token,
        httponly=True,
        secure=settings.is_prod,
        samesite="lax",
        path="/",
        max_age=settings.access_token_ttl_minutes * 60,
    )


def clear_auth_cookies(response: Response) -> None:
    settings = get_settings()
    secure = settings.is_prod
    response.set_cookie(
        key="auth_token", value="", httponly=True, secure=secure, samesite="lax", path="/", max_age=0
    )
    response.set_cookie(
        key="refresh_token",
        value="",
        httponly=True,
        secure=secure,
        samesite="lax",
        path="/api/auth",
        max_age=0,
    )
    response.set_cookie(
        key="auth_logged_in",
        value="",
        httponly=False,
        secure=secure,
        samesite="lax",
        path="/",
        max_age=0,
    )
    clear_csrf_cookie(response)
