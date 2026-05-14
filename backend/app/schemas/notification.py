from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, ConfigDict, Field


class NotificationItem(BaseModel):
    id: int
    alert_type: str
    severity: str
    title: str
    message: Optional[str] = None
    data: Optional[dict[str, Any]] = None
    created_at: datetime
    is_read: bool
    read_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class NotificationListResponse(BaseModel):
    notifications: list[NotificationItem]
    total_count: int
    unread_count: int
    limit: int
    offset: int


class NotificationReadResponse(BaseModel):
    success: bool = True
    message: str
    notification_id: int
    read_at: datetime


class PushTokenUpsertRequest(BaseModel):
    # [HS-015] Reject unknown fields so client typos surface as 422.
    model_config = ConfigDict(extra="forbid")

    token: str = Field(min_length=20, max_length=1024)
    platform: str = Field(default="android", min_length=2, max_length=20)
    device_id: Optional[str] = Field(default=None, max_length=128)


class PushTokenUnregisterRequest(BaseModel):
    # [HS-015] Reject unknown fields so client typos surface as 422.
    model_config = ConfigDict(extra="forbid")

    token: str = Field(min_length=20, max_length=1024)


class PushTokenResponse(BaseModel):
    success: bool = True
    message: str
