from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from scalar_fastapi import get_scalar_api_reference
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.api.router import api_router
from app.core.config import get_settings
from app.services.server_stats import ensure_upload_dirs
from app.websocket.server_stats import router as ws_router

settings = get_settings()

app = FastAPI(
    title="Admin Pro API",
    description="Multi-tenant SaaS REST API. Auth via httpOnly cookies or Authorization: Bearer <token>.",
    version="1.0.0",
    docs_url=None,
    redoc_url=None,
    openapi_url="/api/openapi.json",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(_request: Request, exc: StarletteHTTPException):
    detail = exc.detail
    message = detail if isinstance(detail, str) else str(detail)
    return JSONResponse(
        status_code=exc.status_code,
        content={"statusCode": exc.status_code, "statusMessage": message, "message": message},
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(_request: Request, exc: RequestValidationError):
    message = "Dữ liệu không hợp lệ"
    return JSONResponse(
        status_code=422,
        content={"statusCode": 422, "statusMessage": message, "message": message, "errors": exc.errors()},
    )

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
