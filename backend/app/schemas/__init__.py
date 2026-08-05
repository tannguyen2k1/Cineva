from datetime import datetime
from typing import Any, Generic, TypeVar

from pydantic import BaseModel, ConfigDict, Field

T = TypeVar("T")


class ORMModel(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)


class SuccessResponse(BaseModel, Generic[T]):
    success: bool = True
    data: T


class MessageResponse(BaseModel):
    success: bool = True
    message: str


class PaginatedResponse(BaseModel, Generic[T]):
    success: bool = True
    data: list[T]
    total: int
    page: int
    page_size: int = Field(alias="pageSize")

    model_config = ConfigDict(populate_by_name=True)


# --- Auth ---


class LoginRequest(BaseModel):
    tenant_id: str
    username: str
    password: str
    turnstileToken: str


class AuthUserOut(ORMModel):
    id: str
    username: str
    fullName: str | None = None
    email: str | None = None
    avatar: str | None = None


class AuthDataOut(BaseModel):
    user: AuthUserOut
    tenant_id: str
    permissions: list[str]


# --- Users ---


class UserOut(ORMModel):
    id: str
    username: str
    email: str | None = None
    fullName: str | None = None
    avatar: str | None = None
    isActive: bool
    createdAt: datetime
    roles: list[str] = []
    roleIds: list[str] = []


class UserCreate(BaseModel):
    username: str
    password: str
    fullName: str | None = None
    email: str | None = None
    isActive: bool = True
    roleIds: list[str] = []


class UserUpdate(BaseModel):
    fullName: str | None = None
    email: str | None = None
    isActive: bool | None = None
    password: str | None = None
    roleIds: list[str] | None = None


class ProfileUpdate(BaseModel):
    fullName: str | None = None
    email: str | None = None
    password: str | None = None


class ProfileOut(ORMModel):
    id: str
    username: str
    email: str | None = None
    fullName: str | None = None
    avatar: str | None = None
    isActive: bool
    tenant_id: str


# --- Roles ---


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


# --- Permissions catalog ---


class PermissionItemOut(BaseModel):
    id: str
    action: str
    actionLabel: str
    key: str
    description: str | None = None


class PermissionGroupOut(BaseModel):
    resource: str
    label: str
    permissions: list[PermissionItemOut]


# --- Tenants ---


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


# --- Logs ---


class LogOut(ORMModel):
    id: str
    action: str
    resource: str | None = None
    details: Any = None
    createdAt: datetime
    actor: str | None = None
    actorUsername: str | None = None


# --- Dashboard ---


class DashboardStats(BaseModel):
    users: int
    roles: int
    tenants: int
    logs: int


class RecentLogOut(BaseModel):
    id: str
    action: str
    details: Any = None
    createdAt: datetime
    type: str


class RecentUserOut(ORMModel):
    id: str
    username: str
    fullName: str | None = None
    avatar: str | None = None
    createdAt: datetime


class ServerStatsOut(BaseModel):
    cpu: float
    cpuCores: int
    ram: float
    ramUsed: float
    ramTotal: float
    disk: float
    diskUsed: float
    diskTotal: float
    updatedAt: str


class DashboardDataOut(BaseModel):
    stats: DashboardStats
    recentLogs: list[RecentLogOut]
    server: ServerStatsOut
    recentUsers: list[RecentUserOut]
