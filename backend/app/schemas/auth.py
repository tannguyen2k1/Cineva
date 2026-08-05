from pydantic import BaseModel

from app.schemas.common import ORMModel


class LoginRequest(BaseModel):
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
    permissions: list[str]
    # Present on login/refresh for API clients & Scalar Authorize (FE uses cookies)
    accessToken: str | None = None
