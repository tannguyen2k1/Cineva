from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.openapi.utils import get_openapi
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles
from scalar_fastapi import get_scalar_api_reference

from app.api.csrf import CsrfMiddleware
from app.api.rate_limit import RateLimitMiddleware
from app.api.router import api_router
from app.core.config import get_settings
from app.core.errors import register_exception_handlers
from app.core.timeutil import register_fastapi_utc_json
from app.services.server_stats import ensure_upload_dirs
from app.services.sync_scheduler import start_sync_scheduler, stop_sync_scheduler
from app.websocket.server_stats import router as ws_router

settings = get_settings()
register_fastapi_utc_json()

PUBLIC_OPENAPI_PATHS = {
    "/api/auth/login",
    "/api/auth/logout",
    "/api/auth/refresh",
    "/api/auth/token",
}


@asynccontextmanager
async def lifespan(_app: FastAPI):
    start_sync_scheduler()
    try:
        yield
    finally:
        await stop_sync_scheduler()


app = FastAPI(
    title="Cineva API",
    description=(
        "Single-organization REST API.\n\n"
        "**Browser (Nuxt):** `POST /api/auth/login` → HttpOnly cookies + CSRF. "
        "No access token in JSON.\n\n"
        "**API / Scalar:** Authorize with **OAuth2Password** "
        "(`POST /api/auth/token`, grant `password`) → Bearer `access_token`. "
        "Refresh with `grant_type=refresh_token`. Bearer skips CSRF.\n\n"
        "Turnstile test keys accept token `XXXX.DUMMY.TOKEN.XXXX` (web login only)."
    ),
    version="1.0.0",
    docs_url=None,
    redoc_url=None,
    openapi_url="/api/openapi.json",
    lifespan=lifespan,
)

# Last added = outermost. Order: CORS → RateLimit → CSRF → app
app.add_middleware(CsrfMiddleware)
app.add_middleware(RateLimitMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

register_exception_handlers(app)

upload_root = ensure_upload_dirs(settings.upload_dir)
app.mount("/uploads", StaticFiles(directory=str(upload_root)), name="uploads")

app.include_router(api_router)
app.include_router(ws_router)


def custom_openapi():
    if app.openapi_schema:
        return app.openapi_schema

    schema = get_openapi(
        title=app.title,
        version=app.version,
        description=app.description,
        routes=app.routes,
    )
    components = schema.setdefault("components", {})
    components["securitySchemes"] = {
        "OAuth2Password": {
            "type": "oauth2",
            "description": (
                "Username + password → `access_token` via `POST /api/auth/token`. "
                "Use in Scalar Authorize (no Turnstile). Does not set cookies."
            ),
            "flows": {
                "password": {
                    "tokenUrl": "/api/auth/token",
                    "scopes": {},
                }
            },
        },
        "BearerAuth": {
            "type": "http",
            "scheme": "bearer",
            "bearerFormat": "JWT",
            "description": (
                "Paste `access_token` from `POST /api/auth/token` "
                "(or OAuth2Password Authorize)."
            ),
        },
    }
    # Either scheme satisfies security (OR)
    schema["security"] = [{"OAuth2Password": []}, {"BearerAuth": []}]

    for path, methods in schema.get("paths", {}).items():
        if path not in PUBLIC_OPENAPI_PATHS:
            continue
        for method, operation in methods.items():
            if method.startswith("x-") or not isinstance(operation, dict):
                continue
            operation["security"] = []

    app.openapi_schema = schema
    return app.openapi_schema


app.openapi = custom_openapi


@app.get("/api", include_in_schema=False)
async def api_root():
    return RedirectResponse(url="/api/docs")


@app.get("/api/docs", include_in_schema=False)
async def scalar_docs():
    return get_scalar_api_reference(
        openapi_url=app.openapi_url,
        title=app.title,
        persist_auth=True,
        authentication={
            "preferredSecurityScheme": "OAuth2Password",
        },
    )


@app.get("/health", include_in_schema=False)
async def health():
    return {"status": "ok"}
