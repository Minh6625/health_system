from datetime import datetime

from sqlalchemy import String, Boolean, DateTime, Integer, ForeignKey, UniqueConstraint, CheckConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.database import Base
from app.utils.datetime_helper import get_current_time


class UserRelationship(Base):
    __tablename__ = "user_relationships"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    patient_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True)
    caregiver_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True)
    
    # Relationship meta
    relationship_type: Mapped[str] = mapped_column(String(50), default="family")
    is_primary: Mapped[bool] = mapped_column(Boolean, default=False)
    status: Mapped[str] = mapped_column(String(20), default="pending") # "pending", "accepted"
    
    # Permissions
    can_view_vitals: Mapped[bool] = mapped_column(Boolean, default=False)
    can_receive_alerts: Mapped[bool] = mapped_column(Boolean, default=False)
    can_view_location: Mapped[bool] = mapped_column(Boolean, default=False)
    
    # Metadata
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=get_current_time)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    __table_args__ = (
        UniqueConstraint("patient_id", "caregiver_id", name="unique_patient_caregiver"),
        CheckConstraint("patient_id != caregiver_id", name="different_users"),
    )
