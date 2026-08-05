from __future__ import annotations

import httpx
from fastapi import HTTPException

from app.core.config import get_settings


async def verify_login_turnstile(token: str) -> dict:
    settings = get_settings()
    if not settings.turnstile_secret_key:
        raise HTTPException(status_code=500, detail="TURNSTILE_SECRET_KEY is not configured")

    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.post(
            "https://challenges.cloudflare.com/turnstile/v0/siteverify",
            data={"secret": settings.turnstile_secret_key, "response": token},
        )
        data = resp.json()
    return data
