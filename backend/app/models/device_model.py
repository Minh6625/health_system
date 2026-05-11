from datetime import datetime
from typing import Optional

from sqlalchemy import String, Boolean, DateTime, Integer, ForeignKey, SmallInteger, CheckConstraint, Text, Index
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import text

from app.db.database import Base
from app.utils.datetime_helper import get_current_time


class Device(Base):
    """Model for IoT devices (smartwatch, fitness band)."""
    __tablename__ = "devices"
    
    __table_args__ = (
        CheckConstraint("device_type IN ('smartwatch', 'fitness_band', 'medical_device')", name="check_device_type"),
        CheckConstraint("battery_level >= 0 AND battery_level <= 100", name="check_battery_level"),
        Index("ix_devices_user_id_active_deleted", "user_id", "is_active", "deleted_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    uuid: Mapped[str] = mapped_column(UUID, unique=True, server_default=text("gen_random_uuid()"))
    
    # Ownership
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    
    # Device Info
    device_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    device_type: Mapped[str] = mapped_column(String(50), default='smartwatch')
    model: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    firmware_version: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    
    # Identification
    mac_address: Mapped[Optional[str]] = mapped_column(String(17), nullable=True)
    serial_number: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    
    # Status
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    battery_level: Mapped[Optional[int]] = mapped_column(SmallInteger, nullable=True)
    signal_strength: Mapped[Optional[int]] = mapped_column(SmallInteger, nullable=True)
    
    # Connection
    last_seen_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    last_sync_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    mqtt_client_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    
    # Calibration & Settings
    calibration_data: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)
    
    # Metadata
    registered_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=get_current_time)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=get_current_time, onupdate=get_current_time)
    deleted_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
