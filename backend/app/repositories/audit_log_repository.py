from typing import Optional

from sqlalchemy.orm import Session

from app.models.audit_log_model import AuditLog
from app.utils.datetime_helper import get_current_time


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
            ip_address: Client IP address
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
            ip_address=ip_address,
            user_agent=user_agent,
            details=details,
        )
        db.add(audit_log)
        db.commit()
        db.refresh(audit_log)
        return audit_log
