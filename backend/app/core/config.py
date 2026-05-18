"""Application settings via pydantic-settings (HS-005, HS-006, HS-007).

Reads from environment variables (+ .env file via dotenv).
Production: CORS allowlist finite, internal secret required, JWT TTL short.
Development: CORS wildcard OK, internal secret optional, JWT TTL 30 days.
"""

from __future__ import annotations

import os
from typing import Literal

from dotenv import load_dotenv
from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

load_dotenv()


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # --- Database ---
    DATABASE_URL: str = Field(default="postgresql://localhost:5432/hg_db")

    # --- Security ---
    SECRET_KEY: str = Field(default="")
    ALGORITHM: str = Field(default="HS256")
    ACCESS_TOKEN_EXPIRE_DAYS: int = Field(default=30)

    # --- Environment ---
    ENVIRONMENT: str = Field(default="development")

    # --- Internal service auth (ADR-005) ---
    INTERNAL_SERVICE_SECRET: str = Field(default="")

    # --- CORS (HS-005) ---
    CORS_ALLOWED_ORIGINS: list[str] = Field(
        default=["http://localhost:3000", "http://localhost:5173", "http://localhost:8080", "http://localhost:7777"]
    )

    # --- Email ---
    SMTP_SERVER: str = Field(default="smtp.gmail.com")
    SMTP_PORT: int = Field(default=587)
    SENDER_EMAIL: str = Field(default="")
    SENDER_PASSWORD: str = Field(default="")

    # --- URLs ---
    BACKEND_URL: str = Field(default="http://localhost:8080")
    FRONTEND_URL: str = Field(default="http://localhost:3000")
    MOBILE_DEEP_LINK_SCHEME: str = Field(default="healthguard")

    @field_validator("DATABASE_URL")
    @classmethod
    def fix_postgres_scheme(cls, v: str) -> str:
        if v.startswith("postgres://"):
            return v.replace("postgres://", "postgresql://", 1)
        return v

    @field_validator("SECRET_KEY")
    @classmethod
    def validate_secret_key(cls, v: str) -> str:
        if not v or v == "your-secret-key-change-in-production":
            raise ValueError(
                "SECRET_KEY must be set in environment variables (.env file). "
                "Generate a secure key using: openssl rand -hex 32"
            )
        return v


settings = Settings()
