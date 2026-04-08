from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base
from app.utils.datetime_helper import get_current_time


class NotificationRead(Base):
    """Track read state per-user for alerts/notifications."""

    __tablename__ = "notification_reads"
    __table_args__ = (
        UniqueConstraint("user_id", "alert_id", name="uq_notification_reads_user_alert"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    alert_id: Mapped[int] = mapped_column(ForeignKey("alerts.id", ondelete="CASCADE"), index=True)
    read_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=get_current_time)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=get_current_time)
