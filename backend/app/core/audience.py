"""Audience profile + clinician-role gate for the mobile risk surface.

Phase 5 (see ``backend/docs/risk-contract-baseline.md`` §7g) introduces
``?audience=patient|clinician`` on the risk-report detail route. The
gate is a per-request decision driven by the authenticated user's
``users.role`` value:

* ``audience=patient`` — open to every authenticated user. Returns the
  existing :class:`RiskReportDetailResponse` shape, unchanged.
* ``audience=clinician`` — requires ``user.role`` in
  :data:`CLINICIAN_ROLES`. Returns
  :class:`RiskReportClinicianResponse`, which adds raw ``shap_details``
  + ``model_request_id`` for clinical interpretation + audit
  correlation.

Why a query param + dependency instead of two routes:

* Mobile clients can flip a single feature flag (clinician toggle) and
  re-issue the same path; no per-audience routing on the client side.
* OpenAPI generates a ``oneOf`` response_model so codegen consumers
  pick the right type at the call site without branching on the path.

The role gate is intentionally a small allow-list rather than a full
RBAC table (plan §I.1 open question). Plan acceptance for Phase 5 only
requires "clinician profile chỉ available cho user role có quyền y
tế" — two roles satisfy that, and a future RBAC migration can expand
the set without breaking the gate's contract.
"""

from __future__ import annotations

from enum import Enum

from fastapi import Depends, HTTPException, Query, status

from app.core.dependencies import get_current_user
from app.models.user_model import User


class AudienceEnum(str, Enum):
    """Two-value audience profile used by ``GET /risk-reports/{id}``."""

    patient = "patient"
    clinician = "clinician"


#: Roles that may request ``audience=clinician``.
#:
#: ``admin`` is included as a superset (full system access) so the
#: backoffice doesn't need a separate clinician account to debug
#: issues. Adding ``doctor`` / ``nurse`` later is a one-line edit.
CLINICIAN_ROLES: frozenset[str] = frozenset({"clinician", "admin"})


def require_clinician_audience(
    audience: AudienceEnum = Query(
        default=AudienceEnum.patient,
        description=(
            "Audience profile. ``patient`` (default) returns the lean "
            "DTO; ``clinician`` adds raw SHAP + model_request_id but "
            "requires user.role in CLINICIAN_ROLES."
        ),
    ),
    current_user: User = Depends(get_current_user),
) -> AudienceEnum:
    """Return the requested audience after enforcing the role gate.

    * Patient audience is always allowed (no role check).
    * Clinician audience requires ``current_user.role`` to be in
      :data:`CLINICIAN_ROLES`; otherwise raises HTTP 403.

    The check happens at the FastAPI dependency boundary so the
    handler is never invoked with an unauthorised audience — that
    matches the plan's trust-boundary requirement (raw SHAP must NOT
    leave the backend toward a patient client).
    """
    if audience == AudienceEnum.clinician and current_user.role not in CLINICIAN_ROLES:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cần quyền clinician để xem bản chi tiết chuyên môn",
        )
    return audience


__all__ = [
    "AudienceEnum",
    "CLINICIAN_ROLES",
    "require_clinician_audience",
]
