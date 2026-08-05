"""Nuxt-compatible API errors: { statusCode, statusMessage, message }."""

from __future__ import annotations

import logging

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from starlette.exceptions import HTTPException as StarletteHTTPException

logger = logging.getLogger("app.errors")


def error_body(status_code: int, message: str, **extra) -> dict:
    body = {
        "statusCode": status_code,
        "statusMessage": message,
        "message": message,
    }
    body.update(extra)
    return body


def json_error(status_code: int, message: str, **extra) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content=error_body(status_code, message, **extra),
    )


def _detail_message(detail: object) -> str:
    if isinstance(detail, str):
        return detail
    if isinstance(detail, list):
        # FastAPI sometimes uses list-of-dicts for validation-ish details
        parts = []
        for item in detail:
            if isinstance(item, dict) and "msg" in item:
                parts.append(str(item["msg"]))
            else:
                parts.append(str(item))
        return "; ".join(parts) if parts else "Request failed"
    return str(detail) if detail is not None else "Request failed"


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(StarletteHTTPException)
    async def http_exception_handler(_request: Request, exc: StarletteHTTPException):
        return json_error(exc.status_code, _detail_message(exc.detail))

    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(_request: Request, exc: RequestValidationError):
        return json_error(
            422,
            "Dữ liệu không hợp lệ",
            errors=exc.errors(),
        )

    @app.exception_handler(IntegrityError)
    async def integrity_exception_handler(_request: Request, exc: IntegrityError):
        logger.warning("IntegrityError: %s", exc)
        return json_error(409, "Dữ liệu bị trùng hoặc vi phạm ràng buộc.")

    @app.exception_handler(SQLAlchemyError)
    async def sqlalchemy_exception_handler(_request: Request, exc: SQLAlchemyError):
        logger.exception("SQLAlchemyError: %s", exc)
        return json_error(500, "Lỗi cơ sở dữ liệu. Vui lòng thử lại sau.")

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(_request: Request, exc: Exception):
        logger.exception("Unhandled error: %s", exc)
        return json_error(500, "Đã xảy ra lỗi hệ thống. Vui lòng thử lại sau.")
