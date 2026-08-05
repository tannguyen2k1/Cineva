from pydantic import BaseModel

from app.schemas.common import ORMModel


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
