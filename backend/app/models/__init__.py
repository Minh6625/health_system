"""
Models package - imports all SQLAlchemy models for proper table registration.

This ensures SQLAlchemy can resolve foreign key relationships between tables.
"""

from app.models.user_model import User
from app.models.device_model import Device
from app.models.notification_read_model import NotificationRead
from app.models.push_token_model import UserPushToken
from app.models.sos_event_model import FallEvent, SOSEvent
from app.models.audit_log_model import AuditLog

__all__ = [
    "User",
    "Device",
    "NotificationRead",
    "UserPushToken",
    "FallEvent",
    "SOSEvent",
    "AuditLog",
]
