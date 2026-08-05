from __future__ import annotations

import hashlib
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import get_settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

TOKEN_TYPE_ACCESS = "access"
TOKEN_TYPE_REFRESH = "refresh"
TOKEN_TYPE_WS = "ws-ticket"


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


def hash_token(raw_token: str) -> str:
    """SHA-256 of raw token — never store refresh JWT plaintext."""
    return hashlib.sha256(raw_token.encode("utf-8")).hexdigest()


def new_jti() -> str:
    return str(uuid.uuid4())


def create_access_token(*, user_id: str, username: str, tenant_id: str) -> str:
    settings = get_settings()
    now = datetime.now(timezone.utc)
    payload = {
        "sub": user_id,
        "userId": user_id,
        "username": username,
        "tenant_id": tenant_id,
        "type": TOKEN_TYPE_ACCESS,
        "jti": new_jti(),
        "iat": now,
        "exp": now + timedelta(minutes=settings.access_token_ttl_minutes),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")


def create_refresh_token(*, user_id: str, tenant_id: str, jti: str) -> tuple[str, datetime]:
    settings = get_settings()
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(days=settings.refresh_token_ttl_days)
    payload = {
        "sub": user_id,
        "userId": user_id,
        "tenant_id": tenant_id,
        "type": TOKEN_TYPE_REFRESH,
        "jti": jti,
        "iat": now,
        "exp": expires_at,
    }
    token = jwt.encode(payload, settings.jwt_secret, algorithm="HS256")
    return token, expires_at


def create_ws_ticket(*, user_id: str, tenant_id: str) -> str:
    settings = get_settings()
    now = datetime.now(timezone.utc)
    payload = {
        "sub": user_id,
        "userId": user_id,
        "tenant_id": tenant_id,
        "type": TOKEN_TYPE_WS,
        "jti": new_jti(),
        "iat": now,
        "exp": now + timedelta(seconds=settings.ws_ticket_ttl_seconds),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")


def decode_token(token: str) -> dict[str, Any]:
    settings = get_settings()
    return jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])


def safe_decode_token(token: str) -> dict[str, Any] | None:
    try:
        return decode_token(token)
    except JWTError:
        return None
