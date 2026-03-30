from datetime import datetime, date

from sqlalchemy import String, Boolean, DateTime, Date, Float
from sqlalchemy.dialects.postgresql import ARRAY, JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base
from app.utils.datetime_helper import get_current_time


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    full_name: Mapped[str] = mapped_column(String(100))
    date_of_birth: Mapped[date | None] = mapped_column(Date, nullable=True)
    phone: Mapped[str | None] = mapped_column(String(20), nullable=True)
    role: Mapped[str] = mapped_column(String(20), default="user")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    avatar_url: Mapped[str | None] = mapped_column(nullable=True)
    # Medical information fields
    gender: Mapped[str | None] = mapped_column(String(10), nullable=True)
    blood_type: Mapped[str | None] = mapped_column(String(5), nullable=True)
    height_cm: Mapped[float | None] = mapped_column(Float, nullable=True)
    weight_kg: Mapped[float | None] = mapped_column(Float, nullable=True)
    medications: Mapped[list[str]] = mapped_column(ARRAY(String), default=list, server_default="{}")
    allergies: Mapped[list[str]] = mapped_column(ARRAY(String), default=list, server_default="{}")
    medical_conditions: Mapped[list[str]] = mapped_column(ARRAY(String), default=list, server_default="{}")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=get_current_time)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=get_current_time, onupdate=get_current_time)
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # --- Email verification (6-digit PIN code) ---
    # Stored as VARCHAR(6) to preserve leading zeros (e.g. '012345'). NULL after verified.
    verification_code: Mapped[str | None] = mapped_column(String(6), nullable=True)
    verification_code_expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # --- Password reset (6-digit PIN code) ---
    # NULL after reset is used. Expires in 15 minutes.
    reset_code: Mapped[str | None] = mapped_column(String(6), nullable=True)
    reset_code_expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

