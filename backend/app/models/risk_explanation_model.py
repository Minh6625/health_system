from datetime import datetime
from typing import Optional, List

from sqlalchemy import String, DateTime, Integer, ForeignKey, Text, CheckConstraint
from sqlalchemy.dialects.postgresql import ARRAY, JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.database import Base
from app.utils.datetime_helper import get_current_time


class RiskExplanation(Base):
    """ORM model for risk_explanations table."""
    __tablename__ = "risk_explanations"

    __table_args__ = (
        CheckConstraint(
            "xai_method IN ('shap', 'lime', 'rule_based', 'permutation')",
            name="check_xai_method",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)

    # Foreign key
    risk_score_id: Mapped[int] = mapped_column(
        ForeignKey("risk_scores.id", ondelete="CASCADE"), nullable=False, index=True,
    )

    # Explanation data
    explanation_text: Mapped[str] = mapped_column(Text, nullable=False)
    feature_importance: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)
    xai_method: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    recommendations: Mapped[Optional[List[str]]] = mapped_column(
        ARRAY(Text), nullable=True,
    )

    # Timestamps
    created_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), default=get_current_time, nullable=True,
    )

    # Relationships
    risk_score: Mapped["RiskScore"] = relationship(
        "RiskScore", back_populates="explanations",
    )
