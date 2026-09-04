"""CSRF double-submit: cookie csrf_token must match header X-CSRF-Token."""

from __future__ import annotations

import hmac

from fastapi import Request
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware

from app.api.cookies import CSRF_COOKIE, CSRF_HEADER
from app.core.errors import error_body

UNSAFE_METHODS = frozenset({"POST", "PUT", "PATCH", "DELETE"})

# Login: no CSRF cookie yet (Turnstile covers bots).
# Logout / refresh: must work even if csrf_token missing (pre-CSRF sessions / cleared cookie);
# refresh is gated by HttpOnly refresh_token + server-side rotation anyway.
CSRF_EXEMPT_PREFIXES = (
    "/api/auth/login",
    "/api/auth/logout",
    "/api/auth/refresh",
    "/api/auth/token",  # OAuth2 clients / Scalar — no cookie session
    "/api/auth/register",
    "/api/docs",
    "/api/openapi.json",
    "/health",
    "/uploads",
)


def _is_exempt(path: str) -> bool:
    return any(path == p or path.startswith(p + "/") for p in CSRF_EXEMPT_PREFIXES)


class CsrfMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        if request.method in UNSAFE_METHODS and not _is_exempt(request.url.path):
            # Cookie CSRF only. Bearer clients (Scalar Authorize, scripts) skip —
            # even if login also set cookies in the same browser.
            auth = request.headers.get("authorization") or ""
            if auth.lower().startswith("bearer "):
                return await call_next(request)

            has_cookie_session = bool(
                request.cookies.get("auth_token") or request.cookies.get("refresh_token")
            )
            if has_cookie_session:
                cookie = request.cookies.get(CSRF_COOKIE) or ""
                header = (
                    request.headers.get(CSRF_HEADER)
                    or request.headers.get("X-CSRF-Token")
                    or ""
                )
                ok = (
                    bool(cookie)
                    and bool(header)
                    and len(cookie) == len(header)
                    and hmac.compare_digest(cookie, header)
                )
                if not ok:
                    return JSONResponse(
                        status_code=403,
                        content=error_body(403, "CSRF token missing or invalid"),
                    )
        return await call_next(request)
