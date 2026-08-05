import json
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.models import SystemLog


async def write_system_log(
    db: AsyncSession,
    *,
    tenant_id: str,
    action: str,
    user_id: str | None = None,
    resource: str | None = None,
    details: Any = None,
) -> None:
    try:
        details_str = None
        if details is not None:
            details_str = details if isinstance(details, str) else json.dumps(details, ensure_ascii=False)
        db.add(
            SystemLog(
                tenant_id=tenant_id,
                user_id=user_id,
                action=action,
                resource=resource,
                details=details_str,
            )
        )
        await db.commit()
    except Exception as exc:  # noqa: BLE001 — audit must never break main flow
        await db.rollback()
        print(f"[systemLog] failed: {exc}")
