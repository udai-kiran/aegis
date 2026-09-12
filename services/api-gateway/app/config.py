"""Application settings loaded from environment variables."""

from __future__ import annotations

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql://aegis:aegis@localhost:5432/aegis"
    redis_url: str = "redis://localhost:6379/0"
    jwt_secret: str = "CHANGE-ME-IN-PRODUCTION"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 480

    model_config = {"env_file": ".env", "extra": "ignore"}


settings = Settings()
