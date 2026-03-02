from datetime import datetime
from typing import Optional

from sqlalchemy import JSON, Column, DateTime, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base
from app.utils.datetime_helper import get_current_time


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    time: Mapped[datetime] = mapped_column(DateTime(timezone=True), primary_key=True, default=get_current_time)
    user_id: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    action: Mapped[str] = mapped_column(String(100), nullable=False)
    resource_type: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    resource_id: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    status: Mapped[str] = mapped_column(String(20), nullable=False)
    ip_address: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    user_agent: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    details: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
