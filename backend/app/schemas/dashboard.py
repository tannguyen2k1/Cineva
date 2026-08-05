from datetime import datetime
from typing import Any

from pydantic import BaseModel

from app.schemas.common import ORMModel


class DashboardStats(BaseModel):
    users: int
    roles: int
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
