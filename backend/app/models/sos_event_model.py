from datetime import datetime
from typing import Optional

from sqlalchemy import Index, String, Boolean, DateTime, Integer, ForeignKey, Numeric, Text, CheckConstraint
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import text

from app.db.database import Base
from app.utils.datetime_helper import get_current_time


class FallEvent(Base):
    """Model for fall detection events from AI."""
    __tablename__ = "fall_events"

    __table_args__ = (
        Index("ix_fall_events_device_id_detected_at", "device_id", "detected_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    uuid: Mapped[str] = mapped_column(UUID, unique=True, server_default=text("gen_random_uuid()"))
    device_id: Mapped[int] = mapped_column(ForeignKey("devices.id", ondelete="CASCADE"), index=True)
    
    # Detection
    detected_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    confidence: Mapped[float] = mapped_column(Numeric(4, 3))
    model_version: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    
    # Location (GPS)
    latitude: Mapped[Optional[float]] = mapped_column(Numeric(10, 8), nullable=True)
    longitude: Mapped[Optional[float]] = mapped_column(Numeric(11, 8), nullable=True)
    location_accuracy: Mapped[Optional[float]] = mapped_column(nullable=True)
    address: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    
    # User Response Workflow
    user_notified_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    user_responded_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    user_cancelled: Mapped[bool] = mapped_column(Boolean, default=False)
    cancel_reason: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    
    # SOS Status
    sos_triggered: Mapped[bool] = mapped_column(Boolean, default=False)
    sos_triggered_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    
    # AI Explainability (XAI)
    features: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)

    # Option 3-Lite stand-up survey (Module FA-2).  Populated by
    # ``POST /mobile/fall-events/{id}/survey``.  NULL when the user did
    # not reach step 2 (older app build, panic dismiss, or alert
    # auto-escalated to SOS without a confirm path).  Shape:
    # ``{"can_stand": bool|null, "skipped": bool, "answered_at": iso}``.
    survey_answers: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)

    # Metadata
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=get_current_time)


class Alert(Base):
    """Generic alert persisted from simulator or backend detection flows."""
    __tablename__ = "alerts"

    __table_args__ = (
        CheckConstraint("severity IN ('normal', 'high', 'critical')", name="check_alert_severity"),
        Index("ix_alerts_device_alert_type_created", "device_id", "alert_type", "created_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    uuid: Mapped[str] = mapped_column(UUID, unique=True, server_default=text("gen_random_uuid()"))

    # Source
    device_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("devices.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    user_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    fall_event_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("fall_events.id", ondelete="SET NULL"),
        nullable=True,
    )

    # Alert payload
    alert_type: Mapped[str] = mapped_column(String(50), index=True)
    severity: Mapped[str] = mapped_column(String(20), index=True)
    title: Mapped[str] = mapped_column(String(255))
    message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    details: Mapped[Optional[dict]] = mapped_column("data", JSONB, nullable=True)

    # Metadata
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=get_current_time)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=get_current_time,
        onupdate=get_current_time,
    )


class SOSEvent(Base):
    """Model for emergency SOS events."""
    __tablename__ = "sos_events"
    
    __table_args__ = (
        CheckConstraint("trigger_type IN ('auto', 'manual')", name="check_trigger_type"),
        CheckConstraint("status IN ('active', 'responded', 'cancelled', 'resolved')", name="check_status"),
        Index("ix_sos_events_user_id_status_triggered_at", "user_id", "status", "triggered_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    uuid: Mapped[str] = mapped_column(UUID, unique=True, server_default=text("gen_random_uuid()"))
    
    # Source
    fall_event_id: Mapped[Optional[int]] = mapped_column(ForeignKey("fall_events.id", ondelete="SET NULL"), nullable=True)
    device_id: Mapped[Optional[int]] = mapped_column(ForeignKey("devices.id", ondelete="CASCADE"), nullable=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    
    # Trigger
    trigger_type: Mapped[str] = mapped_column(String(20))
    triggered_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    
    # Location
    latitude: Mapped[Optional[float]] = mapped_column(Numeric(10, 8), nullable=True)
    longitude: Mapped[Optional[float]] = mapped_column(Numeric(11, 8), nullable=True)
    address: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    
    # Response Status
    status: Mapped[str] = mapped_column(String(20), default='active', index=True)
    resolved_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    resolved_by_user_id: Mapped[Optional[int]] = mapped_column(ForeignKey("users.id"), nullable=True)
    resolution_notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    
    # Metadata
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=get_current_time)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=get_current_time, onupdate=get_current_time)
