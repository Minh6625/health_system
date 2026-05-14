from datetime import datetime
from decimal import Decimal
from typing import Optional

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Numeric,
    String,
    Text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base
from app.utils.datetime_helper import get_current_time


class RiskAlertResponse(Base):
    """Terminal response row for a single risk alert notification.

    [HS-013] Type alignment with canonical schema:
    * ``risk_score_id`` and ``device_id`` widened from Integer to BigInteger
      (canonical BIGINT).
    * ``latitude`` (Numeric(10, 8)) and ``longitude`` (Numeric(11, 8))
      replace ``Float`` to keep precision consistent with FallEvent.latitude
      and avoid 4-byte REAL truncation on Postgres.
    """

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
    risk_score_id: Mapped[Optional[int]] = mapped_column(BigInteger, nullable=True)
    source: Mapped[str] = mapped_column(String(32), nullable=False)
    device_id: Mapped[Optional[int]] = mapped_column(BigInteger, nullable=True)
    latitude: Mapped[Optional[Decimal]] = mapped_column(Numeric(10, 8), nullable=True)
    longitude: Mapped[Optional[Decimal]] = mapped_column(Numeric(11, 8), nullable=True)
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
