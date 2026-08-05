"""Per-IP rate limits for spam / brute-force protection."""

from __future__ import annotations

from fastapi import Request
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware

from app.core.config import get_settings
from app.core.errors import error_body
from app.core.rate_limit import limiter

EXEMPT_PREFIXES = (
    "/health",
    "/api/docs",
    "/api/openapi.json",
    "/uploads",
)


def client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip() or "unknown"
    if request.client and request.client.host:
        return request.client.host
    return "unknown"


def _match_rule(path: str, method: str) -> tuple[str, int, int] | None:
    """Return (bucket_name, limit, window_seconds) or None if exempt/unlimited."""
    settings = get_settings()
    if any(path == p or path.startswith(p + "/") for p in EXEMPT_PREFIXES):
        return None
    if method == "OPTIONS":
        return None

    if path == "/api/auth/login" and method == "POST":
        return ("login", settings.rate_limit_login, 60)
    if path == "/api/auth/refresh" and method == "POST":
        return ("refresh", settings.rate_limit_refresh, 60)
    if path == "/api/auth/ws-ticket" and method == "GET":
        return ("ws_ticket", settings.rate_limit_ws_ticket, 60)
    if path.startswith("/api/"):
        return ("api", settings.rate_limit_api, 60)
    return None


class RateLimitMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        rule = _match_rule(request.url.path, request.method)
        if rule is None:
            return await call_next(request)

        bucket, limit, window = rule
        ip = client_ip(request)
        key = f"{bucket}:{ip}"
        allowed, retry_after = limiter.check(key, limit=limit, window_seconds=window)
        if not allowed:
            return JSONResponse(
                status_code=429,
                headers={"Retry-After": str(retry_after)},
                content=error_body(
                    429,
                    "Quá nhiều yêu cầu. Vui lòng thử lại sau.",
                    retryAfter=retry_after,
                ),
            )
        return await call_next(request)
