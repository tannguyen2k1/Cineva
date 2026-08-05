from datetime import datetime

from pydantic import BaseModel

from app.schemas.common import ORMModel


class RoleOut(ORMModel):
    id: str
    name: str
    description: str | None = None
    userCount: int = 0
    createdAt: datetime


class RoleCreate(BaseModel):
    name: str
    description: str | None = None


class RoleUpdate(BaseModel):
    name: str | None = None
    description: str | None = None


class RolePermissionsOut(BaseModel):
    roleId: str
    roleName: str
    permissionIds: list[str]


class RolePermissionsUpdate(BaseModel):
    permissionIds: list[str] = []
