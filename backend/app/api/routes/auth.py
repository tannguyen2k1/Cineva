from fastapi import APIRouter, Cookie, Depends, Form, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser, get_current_user
from app.db.session import get_db
from app.schemas import LoginRequest, OAuth2TokenOut
from app.services import auth as auth_service

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.post("/login", summary="Browser login (HttpOnly cookies + Turnstile)")
async def login(
    body: LoginRequest,
    response: Response,
    db: AsyncSession = Depends(get_db),
):
    return await auth_service.login(db, body, response)


@router.post(
    "/token",
    summary="OAuth2 token (password / refresh_token) for API clients & Scalar",
    response_model=OAuth2TokenOut,
)
async def token(
    db: AsyncSession = Depends(get_db),
    grant_type: str = Form(
        default="password",
        description="password | refresh_token",
    ),
    username: str | None = Form(default=None),
    password: str | None = Form(default=None),
    refresh_token: str | None = Form(default=None),
    scope: str = Form(default=""),
):
    _ = scope  # accepted for OAuth2 clients; unused (no scopes yet)
    return await auth_service.oauth2_token(
        db,
        grant_type=grant_type,
        username=username,
        password=password,
        refresh_token=refresh_token,
    )


@router.post("/logout", summary="Revoke access jti + refresh session and clear cookies")
async def logout(
    response: Response,
    db: AsyncSession = Depends(get_db),
    refresh_token: str | None = Cookie(default=None),
    auth_token: str | None = Cookie(default=None),
):
    return await auth_service.logout(
        db, response, refresh_token, access_token=auth_token
    )


@router.post("/refresh", summary="Browser refresh — rotate HttpOnly cookies")
async def refresh(
    response: Response,
    db: AsyncSession = Depends(get_db),
    refresh_token: str | None = Cookie(default=None),
    auth_token: str | None = Cookie(default=None),
):
    return await auth_service.refresh(
        db, refresh_token, response, access_token=auth_token
    )


@router.get("/me", summary="Current user", responses={401: {"description": "Unauthorized"}})
async def me(
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(get_current_user),
):
    return await auth_service.me(db, current.id)


@router.get("/ws-ticket", summary="Issue short-lived WebSocket ticket")
async def ws_ticket(current: CurrentUser = Depends(get_current_user)):
    return auth_service.issue_ws_ticket(current.id)
