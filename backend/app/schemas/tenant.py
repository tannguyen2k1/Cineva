from datetime import datetime

from pydantic import BaseModel

from app.schemas.common import ORMModel


class TenantOut(ORMModel):
    id: str
    name: str
    domain: str | None = None
    userCount: int = 0
    isActive: bool
    createdAt: datetime


class TenantCreate(BaseModel):
    name: str
    domain: str | None = None
    isActive: bool = True


class TenantUpdate(BaseModel):
    name: str | None = None
    domain: str | None = None
    isActive: bool | None = None


class TenantCreateResult(TenantOut):
    defaultAdmin: dict[str, str]
