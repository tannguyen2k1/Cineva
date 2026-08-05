from datetime import datetime
from typing import Any

from app.schemas.common import ORMModel


class LogOut(ORMModel):
    id: str
    action: str
    resource: str | None = None
    details: Any = None
    createdAt: datetime
    actor: str | None = None
    actorUsername: str | None = None
