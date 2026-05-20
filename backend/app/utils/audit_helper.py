"""Shared helpers for audit logging on mobile-facing routes.

Centralises the request → audit_log plumbing so individual routes only
have to call ``safe_log_action(...)`` instead of repeating the
try/except + IP/UA extraction boilerplate. Used by Auth (existing) and
the SOS / Relationship / FallEvent slices added in
``feat/audit-log-mobile-be``.

Design notes:
* ``get_client_ip`` returns ``None`` (not "" / "unknown") so the Postgres
  ``audit_logs.ip_address`` ``inet`` column stores ``NULL`` instead of
  raising ``InvalidTextRepresentation``.
* ``safe_log_action`` swallows audit-write failures: an audit insert
  must NEVER block a successful business operation. Failures are logged
  via ``logger.warning`` so ops still has visibility.
* The helper deliberately does NOT open its own transaction or call
  ``db.commit`` — it delegates to ``AuditLogRepository.log_action``
  which already commits a single audit row. Callers should invoke this
  AFTER their business commit (or after rollback in error paths).
"""

from __future__ import annotations

import logging
from typing import Any, Optional

from fastapi import Request
from sqlalchemy.orm import Session

from app.repositories.audit_log_repository import AuditLogRepository

logger = logging.getLogger(__name__)


def get_client_ip(request: Request) -> Optional[str]:
    """Extract client IP from a FastAPI ``Request``.

    Honors ``X-Forwarded-For`` for deployments behind a reverse proxy
    (returns the first hop). Falls back to ``request.client.host`` for
    direct connections. Returns ``None`` when nothing is available so
    ``AuditLogRepository`` stores SQL ``NULL`` (the column is Postgres
    ``inet`` and would reject ``""`` / ``"unknown"``).
    """
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else None


def get_user_agent(request: Request) -> str:
    """Return the ``User-Agent`` header or ``"unknown"`` when absent."""
    return request.headers.get("User-Agent", "unknown")


def safe_log_action(
    db: Session,
    *,
    action: str,
    status: str,
    user_id: Optional[int] = None,
    resource_type: Optional[str] = None,
    resource_id: Optional[int] = None,
    ip_address: Optional[str] = None,
    user_agent: Optional[str] = None,
    details: Optional[dict[str, Any]] = None,
) -> None:
    """Best-effort audit log write.

    Wraps :meth:`AuditLogRepository.log_action` so an audit insert
    failure (DB transient, INET coercion bug, etc.) cannot break the
    parent request. The repository already coerces invalid IPs to
    ``NULL`` and validates the ``status`` CHECK constraint
    (``success`` / ``failure`` / ``pending``); we just protect the
    caller from any uncaught exception.
    """
    try:
        AuditLogRepository.log_action(
            db,
            action=action,
            status=status,
            user_id=user_id,
            resource_type=resource_type,
            resource_id=resource_id,
            ip_address=ip_address,
            user_agent=user_agent,
            details=details,
        )
    except Exception as exc:  # noqa: BLE001 — must never propagate
        logger.warning(
            "audit_log write failed for action=%s status=%s user_id=%s: %s",
            action,
            status,
            user_id,
            exc,
        )
