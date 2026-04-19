from datetime import datetime
from typing import Optional, List

from sqlalchemy import String, DateTime, Integer, ForeignKey, Numeric, CheckConstraint
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.database import Base
from app.utils.datetime_helper import get_current_time


class RiskScore(Base):
    """ORM model for risk_scores table."""
    __tablename__ = "risk_scores"

    __table_args__ = (
        CheckConstraint(
            "risk_type IN ('stroke', 'heartattack', 'afib', 'general')",
            name="check_risk_type",
        ),
        CheckConstraint(
            "score >= 0 AND score <= 100",
            name="check_score_range",
        ),
        CheckConstraint(
            "risk_level IN ('low', 'medium', 'critical')",
            name="check_risk_level",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)

    # Foreign keys
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True,
    )
    device_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("devices.id", ondelete="SET NULL"), nullable=True, index=True,
    )

    # Score data
    calculated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False,
    )
    risk_type: Mapped[str] = mapped_column(String(50), nullable=False)
    score: Mapped[float] = mapped_column(Numeric, nullable=False)
    risk_level: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    features: Mapped[dict] = mapped_column(JSONB, nullable=False)

    # Model metadata
    model_version: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    algorithm: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)

    # Timestamps
    created_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), default=get_current_time, nullable=True,
    )

    # Relationships
    explanations: Mapped[List["RiskExplanation"]] = relationship(
        "RiskExplanation", back_populates="risk_score", cascade="all, delete-orphan",
    )
