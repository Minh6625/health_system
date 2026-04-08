from typing import Optional

from pydantic import BaseModel, Field


class GeneralSettingsResponse(BaseModel):
    language: str
    theme: str
    timezone: str
    push_notifications_enabled: bool
    maintenance_mode: bool
    session_timeout_minutes: int


class GeneralSettingsUpdateRequest(BaseModel):
    language: Optional[str] = Field(default=None, min_length=2, max_length=10)
    theme: Optional[str] = Field(default=None, pattern="^(light|dark|system)$")
    timezone: Optional[str] = Field(default=None, min_length=3, max_length=100)
    push_notifications_enabled: Optional[bool] = None
    maintenance_mode: Optional[bool] = None
    session_timeout_minutes: Optional[int] = Field(default=None, ge=5, le=43200)
