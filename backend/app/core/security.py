from __future__ import annotations

import hashlib
import uuid
from datetime import datetime
from typing import Any

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import get_settings
from app.core.timeutil import from_unix_ts, unix_ts

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


def create_access_token(*, user_id: str, username: str) -> str:
    settings = get_settings()
    now = unix_ts()
    payload = {
        "sub": user_id,
        "userId": user_id,
        "username": username,
        "type": TOKEN_TYPE_ACCESS,
        "jti": new_jti(),
        "iat": now,
        "exp": now + settings.access_token_ttl_minutes * 60,
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")


def create_refresh_token(*, user_id: str, jti: str) -> tuple[str, datetime]:
    settings = get_settings()
    now = unix_ts()
    exp = now + settings.refresh_token_ttl_days * 24 * 60 * 60
    expires_at = from_unix_ts(exp)
    payload = {
        "sub": user_id,
        "userId": user_id,
        "type": TOKEN_TYPE_REFRESH,
        "jti": jti,
        "iat": now,
        "exp": exp,
    }
    token = jwt.encode(payload, settings.jwt_secret, algorithm="HS256")
    return token, expires_at


def create_ws_ticket(*, user_id: str) -> str:
    settings = get_settings()
    now = unix_ts()
    payload = {
        "sub": user_id,
        "userId": user_id,
        "type": TOKEN_TYPE_WS,
        "jti": new_jti(),
        "iat": now,
        "exp": now + settings.ws_ticket_ttl_seconds,
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
