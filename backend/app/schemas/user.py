from datetime import datetime

from pydantic import BaseModel

from app.schemas.common import ORMModel


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
