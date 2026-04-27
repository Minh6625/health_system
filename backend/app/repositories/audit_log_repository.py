import ipaddress
from typing import Optional

from sqlalchemy.orm import Session

from app.models.audit_log_model import AuditLog
from app.utils.datetime_helper import get_current_time


def _coerce_ip(value: Optional[str]) -> Optional[str]:
    """Coerce caller-provided IP to a value Postgres `inet` accepts.

    The `audit_logs.ip_address` column has Postgres type `inet`. Inserting
    an empty string or non-IP placeholder (e.g. "", "unknown") raises
    `psycopg2.errors.InvalidTextRepresentation` and crashes the whole
    request with HTTP 500. Defensive coercion: empty/whitespace/invalid
    inputs become NULL.
    """
    if not value:
        return None
    cleaned = value.strip()
    if not cleaned:
        return None
    try:
        ipaddress.ip_address(cleaned)
    except ValueError:
        return None
    return cleaned


class AuditLogRepository:
    @staticmethod
    def log_action(
        db: Session,
        action: str,
        status: str,
        user_id: Optional[int] = None,
        resource_type: Optional[str] = None,
        resource_id: Optional[int] = None,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
        details: Optional[dict] = None,
    ) -> AuditLog:
        """
        Log an action to audit_logs table.
        
        Args:
            action: Action performed (e.g., "user.login", "user.register")
            status: Status of action ("success", "failure", "error")
            user_id: User ID if applicable
            resource_type: Resource type (e.g., "user", "alert")
            resource_id: Resource ID
            ip_address: Client IP address (empty/invalid → stored as NULL)
            user_agent: Client user agent
            details: Additional details as JSON
        """
        audit_log = AuditLog(
            time=get_current_time(),
            user_id=user_id,
            action=action,
            resource_type=resource_type,
            resource_id=resource_id,
            status=status,
            ip_address=_coerce_ip(ip_address),
            user_agent=user_agent,
            details=details,
        )
        db.add(audit_log)
        db.commit()
        db.refresh(audit_log)
        return audit_log
