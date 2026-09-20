from pydantic import BaseModel, Field

from app.schemas.common import ORMModel


class LoginRequest(BaseModel):
    username: str
    password: str
    turnstileToken: str


class RegisterApiRequest(ORMModel):
    """Mobile / API registration — no Turnstile (bots gated elsewhere)."""

    username: str = Field(min_length=3, max_length=64)
    password: str = Field(min_length=6, max_length=128)
    email: str | None = None
    full_name: str | None = Field(default=None, alias="fullName")


class AuthUserOut(ORMModel):
    id: str
    username: str
    fullName: str | None = None
    email: str | None = None
    avatar: str | None = None


class AuthDataOut(BaseModel):
    """Web session payload — tokens live in HttpOnly cookies only."""

    user: AuthUserOut
    permissions: list[str]


class OAuth2TokenOut(BaseModel):
    """RFC 6749 token response for API clients / Scalar Authorize."""

    access_token: str
    token_type: str = "bearer"
    expires_in: int = Field(description="Access token lifetime in seconds")
    refresh_token: str
