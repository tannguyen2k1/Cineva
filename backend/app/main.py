from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
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
from app.websocket.server_stats import router as ws_router

settings = get_settings()
register_fastapi_utc_json()

app = FastAPI(
    title="Admin Pro API",
    description="Multi-tenant SaaS REST API. Auth via httpOnly cookies or Authorization: Bearer <token>.",
    version="1.0.0",
    docs_url=None,
    redoc_url=None,
    openapi_url="/api/openapi.json",
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


@app.get("/api", include_in_schema=False)
async def api_root():
    return RedirectResponse(url="/api/docs")


@app.get("/api/docs", include_in_schema=False)
async def scalar_docs():
    return get_scalar_api_reference(
        openapi_url=app.openapi_url,
        title=app.title,
    )


@app.get("/health", include_in_schema=False)
async def health():
    return {"status": "ok"}
