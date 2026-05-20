"""Mobile-facing fall event read + dismiss routes.

Phase 4B-full slice 2c (see ``backend/docs/risk-contract-baseline.md``
§7j). Three routes that the Flutter ``lib/features/fall/`` module
consumes:

* ``GET    /api/v1/mobile/fall-events`` — paginated list, newest first.
* ``GET    /api/v1/mobile/fall-events/{id}`` — one event detail.
* ``POST   /api/v1/mobile/fall-events/{id}/dismiss`` — mark as user-cancelled.

All three are scoped through ``X-Target-Profile-Id`` (relationships
already resolved by :func:`get_target_profile_id`). The service layer
re-checks ownership against ``devices.user_id`` so a request for one
of *another* user's events returns 404 — never 200, never 403 (which
would leak existence).
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy.orm import Session

from app.core.dependencies import get_target_profile_id, get_current_user
from app.db.database import get_db
from app.models.user_model import User
from app.schemas.fall_telemetry import (
    FallEventDismissRequest,
    FallEventDismissResponse,
    FallEventListResponse,
    FallEventResponse,
    FallSurveySubmitRequest,
    FallSurveySubmitResponse,
)
from app.services.fall_event_service import FallEventService
from app.utils.audit_helper import get_client_ip, get_user_agent, safe_log_action

router = APIRouter(prefix="/fall-events", tags=["mobile-fall-events"])


# ---------------------------------------------------------------------------
# List
# ---------------------------------------------------------------------------


@router.get(
    "",
    response_model=FallEventListResponse,
    summary="List fall events for the target profile",
)
def list_fall_events(
    limit: int = Query(default=20, ge=1, le=100, description="Page size, max 100."),
    offset: int = Query(default=0, ge=0, description="Page offset for pagination."),
    target_profile_id: int = Depends(get_target_profile_id),
    db: Session = Depends(get_db),
) -> FallEventListResponse:
    """Return the user's fall events newest-first with total count.

    ``limit`` is bounded server-side to a max of 100 to protect the DB.
    The ``X-Target-Profile-Id`` header lets a caregiver inspect a
    related elder's events; the relationship resolver in
    :func:`get_target_profile_id` enforces who can see whom.
    """
    return FallEventService.list_for_user(
        user_id=int(target_profile_id),
        db=db,
        limit=int(limit),
        offset=int(offset),
    )


# ---------------------------------------------------------------------------
# Detail
# ---------------------------------------------------------------------------


@router.get(
    "/{fall_event_id}",
    response_model=FallEventResponse,
    summary="Fetch one fall event scoped by user",
)
def get_fall_event(
    fall_event_id: int,
    target_profile_id: int = Depends(get_target_profile_id),
    db: Session = Depends(get_db),
) -> FallEventResponse:
    """Return one fall event by id, or HTTP 404 if it doesn't belong to
    the target user.

    We deliberately return the same 404 for "not found" and "exists but
    belongs to someone else" so the route doesn't leak the difference
    (an enumeration vector). Same trick the existing relationship
    routes use.
    """
    result = FallEventService.get_for_user(
        user_id=int(target_profile_id),
        fall_event_id=int(fall_event_id),
        db=db,
    )
    if result is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy sự kiện ngã",
        )
    return result


# ---------------------------------------------------------------------------
# Dismiss
# ---------------------------------------------------------------------------


@router.post(
    "/{fall_event_id}/dismiss",
    response_model=FallEventDismissResponse,
    summary="Dismiss a fall event (user is OK)",
)
def dismiss_fall_event(
    fall_event_id: int,
    request: Request,
    payload: FallEventDismissRequest | None = None,
    target_profile_id: int = Depends(get_target_profile_id),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> FallEventDismissResponse:
    """Mark a fall event as ``user_cancelled`` and update
    ``user_responded_at``.

    Idempotent: re-dismissing an already-dismissed event refreshes the
    timestamp and overwrites ``cancel_reason`` if the new request
    supplies one. A missing body is allowed (treated as no reason).

    Auth: the caller must own the device that produced the event;
    otherwise HTTP 404.
    """
    reason = payload.reason if payload is not None else None
    result = FallEventService.dismiss(
        user_id=int(target_profile_id),
        fall_event_id=int(fall_event_id),
        reason=reason,
        db=db,
    )
    if result is None:
        # 404 enumeration-resistant — skip audit.
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy sự kiện ngã",
        )
    safe_log_action(
        db,
        action="fall_event.dismissed",
        status="success",
        user_id=int(current_user.id),
        resource_type="fall_event",
        resource_id=int(fall_event_id),
        ip_address=get_client_ip(request),
        user_agent=get_user_agent(request),
        details={
            "target_profile_id": int(target_profile_id),
            "via_target_header": int(target_profile_id) != int(current_user.id),
            "has_reason": bool(reason),
            "reason": reason,
        },
    )
    return FallEventDismissResponse(fall_event=result)


# ---------------------------------------------------------------------------
# Stand-up survey (Module FA-2 — Option 3-Lite)
# ---------------------------------------------------------------------------


@router.post(
    "/{fall_event_id}/survey",
    response_model=FallSurveySubmitResponse,
    summary="Submit the post-dismiss stand-up survey answer",
)
def submit_fall_survey(
    fall_event_id: int,
    payload: FallSurveySubmitRequest,
    request: Request,
    target_profile_id: int = Depends(get_target_profile_id),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> FallSurveySubmitResponse:
    """Persist the FallStandUpSurveyScreen answer (Option 3-Lite).

    The Flutter side calls this *after* the user has tapped "Tôi ổn"
    on the initial fall alert and answered (or skipped) the follow-up
    "Bạn có thể đứng dậy được không?" question.  Three answer shapes:

    * ``can_stand=True, skipped=False``  — patient stood up.
    * ``can_stand=False, skipped=False`` — patient said OK but cannot
      stand; the BE fans a softer follow-up notification to caregivers.
    * ``can_stand=None,  skipped=True``  — patient skipped or timer
      expired; we still record the audit trail.

    Idempotent: re-submitting overwrites the previous answer.
    Returns HTTP 404 when the event doesn't belong to the target user
    (same enumeration-resistant pattern as ``GET`` / ``dismiss``).
    """
    result = FallEventService.submit_survey(
        user_id=int(target_profile_id),
        fall_event_id=int(fall_event_id),
        can_stand=payload.can_stand,
        skipped=bool(payload.skipped),
        db=db,
    )
    if result is None:
        # 404 enumeration-resistant — skip audit.
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy sự kiện ngã",
        )
    safe_log_action(
        db,
        action="fall_event.survey_submitted",
        status="success",
        user_id=int(current_user.id),
        resource_type="fall_event",
        resource_id=int(fall_event_id),
        ip_address=get_client_ip(request),
        user_agent=get_user_agent(request),
        details={
            "target_profile_id": int(target_profile_id),
            "via_target_header": int(target_profile_id) != int(current_user.id),
            "can_stand": payload.can_stand,
            "skipped": bool(payload.skipped),
        },
    )
    return FallSurveySubmitResponse(fall_event=result)
