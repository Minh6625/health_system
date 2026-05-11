from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, Index
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base
from app.utils.datetime_helper import get_current_time


class UserPushToken(Base):
    """FCM/APNs token registry for mobile push delivery."""

    __tablename__ = "user_push_tokens"
    __table_args__ = (
        Index("ix_push_tokens_user_id_active", "user_id", "is_active"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
    )
    token: Mapped[str] = mapped_column(String(512), unique=True, index=True)
    platform: Mapped[str] = mapped_column(String(20), default="android")
    device_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=get_current_time,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=get_current_time,
        onupdate=get_current_time,
    )
    last_seen_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=get_current_time,
    )
