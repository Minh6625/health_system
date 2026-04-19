from datetime import datetime
from typing import Optional

from sqlalchemy import CheckConstraint, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base
from app.utils.datetime_helper import get_current_time


class RiskAlertResponse(Base):
    """Terminal response row for a single risk alert notification."""

    __tablename__ = "risk_alert_responses"

    __table_args__ = (
        CheckConstraint(
            "response_action IN ('safe', 'help_requested', 'timeout_escalated')",
            name="check_risk_alert_response_action",
        ),
        CheckConstraint(
            "source IN ('overlay', 'push_tap')",
            name="check_risk_alert_response_source",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    notification_id: Mapped[int] = mapped_column(
        ForeignKey("alerts.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True,
    )
    response_action: Mapped[str] = mapped_column(String(32), nullable=False)
    risk_score_id: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    source: Mapped[str] = mapped_column(String(32), nullable=False)
    device_id: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    latitude: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    longitude: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    address: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    responded_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=get_current_time,
        nullable=False,
    )
    sos_event_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("sos_events.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=get_current_time,
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=get_current_time,
        onupdate=get_current_time,
        nullable=False,
    )
