from fastapi import Response

from app.core.config import get_settings


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
