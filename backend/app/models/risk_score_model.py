from datetime import datetime
from typing import Optional, List, Any

from sqlalchemy import Boolean, Index, String, DateTime, Integer, ForeignKey, Numeric, CheckConstraint, Text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.database import Base
from app.utils.datetime_helper import get_current_time


class RiskScore(Base):
    """ORM model for risk_scores table."""
    __tablename__ = "risk_scores"

    __table_args__ = (
        CheckConstraint(
            "risk_type IN ('stroke', 'heartattack', 'afib', 'general', 'sleep')",
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
        Index("ix_risk_scores_user_id_calculated_at", "user_id", "calculated_at"),
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

    # ADR-018 data quality contract (Phase 7 S4) — promoted from features
    # JSONB blob to first-class columns so the admin dashboard, retraining
    # pipelines and audit reports can query them without parsing JSON.
    is_synthetic_default: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false",
    )
    defaults_applied: Mapped[Optional[Any]] = mapped_column(JSONB, nullable=True)
    effective_confidence: Mapped[Optional[float]] = mapped_column(
        Numeric(5, 4), nullable=True,
    )
    data_quality_warning: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # Timestamps
    created_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), default=get_current_time, nullable=True,
    )

    # Relationships
    explanations: Mapped[List["RiskExplanation"]] = relationship(
        "RiskExplanation", back_populates="risk_score", cascade="all, delete-orphan",
    )
