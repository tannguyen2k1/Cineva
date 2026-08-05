from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    database_url: str = "postgresql+asyncpg://postgres:password123@localhost:5432/multi_tenant_db"
    jwt_secret: str = "change-me"
    default_admin_username: str = "admin"
    default_admin_password: str = "admin123456"
    turnstile_secret_key: str = ""
    environment: str = "development"
    upload_dir: str = "uploads"
    cors_origins: str = "http://localhost:3000"

    access_token_ttl_minutes: int = 15
    refresh_token_ttl_days: int = 7
    ws_ticket_ttl_seconds: int = 30

    # Per-IP sliding window (requests / 60s). 0 = disabled for that bucket.
    rate_limit_login: int = 5
    rate_limit_refresh: int = 30
    rate_limit_ws_ticket: int = 20
    rate_limit_api: int = 120

    @property
    def is_prod(self) -> bool:
        return self.environment.lower() == "production"

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
