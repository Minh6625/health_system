"""Mobile-facing fall event read + dismiss service.

Phase 4B-full slice 2c. The Flutter ``fall_alert_screen`` and
``fall_history_screen`` call into this service via three routes
(``GET /mobile/fall-events``, ``GET /mobile/fall-events/{id}``,
``POST /mobile/fall-events/{id}/dismiss``).

The service owns three concerns:

1. **User scoping.** ``fall_events`` rows reference ``device_id`` only;
   they have no direct ``user_id`` column. Every query LATERAL-joins
   through ``devices.user_id`` so a request for one of *another* user's
   events returns 404, never 200.
2. **Status derivation.** The DB stores raw timestamps + booleans
   (``user_responded_at``, ``user_cancelled``, ``sos_triggered``); the
   mobile DTO carries a single ``status`` string derived from them so
   the Flutter side does not have to reproduce the state machine.
3. **Dismiss writes.** ``POST .../dismiss`` is the only mutation —
   sets ``user_responded_at`` + ``user_cancelled`` + optional
   ``cancel_reason``. Writes are best-effort: a failure rolls back the
   transaction and surfaces a 500 so the Flutter client knows the
   dismiss did NOT take effect (rather than silently keeping the
   "alert active" UI).
"""

from __future__ import annotations

import logging
from typing import Any

from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.models.sos_event_model import FallEvent
from app.schemas.fall_telemetry import (
    FallEventListResponse,
    FallEventResponse,
)
from app.utils.datetime_helper import get_current_time

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Status state machine
# ---------------------------------------------------------------------------


_STATUS_DETECTED = "detected"
_STATUS_DISMISSED = "dismissed"
_STATUS_CONFIRMED = "confirmed"
_STATUS_ESCALATED = "escalated"


def derive_status(row: FallEvent) -> str:
    """Project the raw workflow columns to a single ``status`` string.

    Priority order:

    1. ``sos_triggered`` ⇒ ``escalated`` (auto-SOS path took over).
    2. ``user_cancelled`` ⇒ ``dismissed`` (user explicitly cleared).
    3. ``user_responded_at IS NOT NULL`` ⇒ ``confirmed`` (user
       acknowledged but did NOT cancel — this is the "I need help"
       branch which leaves the SOS workflow running but stops the
       countdown).
    4. Otherwise ⇒ ``detected`` (no user action yet, no SOS).

    Order matters because a single row can have multiple booleans set
    (e.g. user dismissed AFTER auto-SOS already escalated). The most
    decisive state wins.
    """
    if row.sos_triggered:
        return _STATUS_ESCALATED
    if row.user_cancelled:
        return _STATUS_DISMISSED
    if row.user_responded_at is not None:
        return _STATUS_CONFIRMED
    return _STATUS_DETECTED


# ---------------------------------------------------------------------------
# Service
# ---------------------------------------------------------------------------


class FallEventService:
    """Static methods that own the SQL + status derivation for slice 2c.

    Uses :class:`Session` directly (no repository layer) to match the
    existing :class:`~app.services.monitoring_service.MonitoringService`
    style — simple SQL, no extra abstraction.
    """

    @staticmethod
    def list_for_user(
        *,
        user_id: int,
        db: Session,
        limit: int = 20,
        offset: int = 0,
    ) -> FallEventListResponse:
        """Return the user's fall events, newest first, paginated.

        ``limit`` is bounded server-side (caller may have requested
        anything; we cap at 100 to protect the DB from a runaway scan).
        """
        safe_limit = max(1, min(int(limit), 100))
        safe_offset = max(0, int(offset))

        # Two queries: one for the page of rows, one for the total count.
        # Keeping them separate (vs window function) keeps the query
        # planner happy on partitioned ``fall_events`` tables.
        # Raw SQL (vs ORM relationships) keeps the JOIN through
        # ``devices.user_id`` explicit and matches the rest of the
        # read-path style in this code base.
        rows_result = db.execute(
            text(
                """
                SELECT fe.*
                FROM fall_events fe
                JOIN devices d ON d.id = fe.device_id
                WHERE d.user_id = :user_id
                ORDER BY fe.detected_at DESC, fe.id DESC
                LIMIT :limit OFFSET :offset
                """
            ),
            {"user_id": int(user_id), "limit": safe_limit, "offset": safe_offset},
        ).mappings().all()

        total = (
            db.execute(
                text(
                    """
                    SELECT COUNT(*) AS total
                    FROM fall_events fe
                    JOIN devices d ON d.id = fe.device_id
                    WHERE d.user_id = :user_id
                    """
                ),
                {"user_id": int(user_id)},
            )
            .mappings()
            .first()
        )
        total_count = int(total["total"]) if total else 0

        items = [
            FallEventService._row_to_response(dict(r))
            for r in rows_result
        ]
        return FallEventListResponse(
            items=items, total=total_count, limit=safe_limit, offset=safe_offset,
        )

    @staticmethod
    def get_for_user(
        *,
        user_id: int,
        fall_event_id: int,
        db: Session,
    ) -> FallEventResponse | None:
        """Return one fall event scoped by user.

        Returns ``None`` when:

        * The id does not exist, OR
        * The id exists but belongs to another user's device.

        Either way the route layer turns this into HTTP 404 — leaking
        the difference between "doesn't exist" and "exists but not
        yours" would be an enumeration vector.
        """
        row = (
            db.execute(
                text(
                    """
                    SELECT fe.*
                    FROM fall_events fe
                    JOIN devices d ON d.id = fe.device_id
                    WHERE fe.id = :fall_event_id
                      AND d.user_id = :user_id
                    LIMIT 1
                    """
                ),
                {"fall_event_id": int(fall_event_id), "user_id": int(user_id)},
            )
            .mappings()
            .first()
        )
        if row is None:
            return None
        return FallEventService._row_to_response(dict(row))

    @staticmethod
    def dismiss(
        *,
        user_id: int,
        fall_event_id: int,
        reason: str | None,
        db: Session,
    ) -> FallEventResponse | None:
        """Mark a fall event as user-cancelled.

        Idempotent in spirit: re-dismissing an already-dismissed event
        refreshes ``user_responded_at`` and overwrites the
        ``cancel_reason`` if one was supplied. Returns ``None`` (→ 404)
        when the event does not belong to the caller.

        On DB error the transaction is rolled back and
        :class:`SQLAlchemyError` is re-raised so the route layer can
        return 500 — silently swallowing would leave the Flutter
        client showing a stale "alert active" UI.
        """
        # Look up + lock the row in the same transaction so two
        # concurrent dismisses can't race.
        row = (
            db.query(FallEvent)
            .filter(FallEvent.id == int(fall_event_id))
            .with_for_update()
            .first()
        )
        if row is None:
            return None
        # Authorisation: re-check ownership inside the transaction.
        owner_check = (
            db.execute(
                text(
                    """
                    SELECT 1
                    FROM devices d
                    WHERE d.id = :device_id AND d.user_id = :user_id
                    LIMIT 1
                    """
                ),
                {"device_id": int(row.device_id), "user_id": int(user_id)},
            )
            .mappings()
            .first()
        )
        if owner_check is None:
            return None

        try:
            row.user_responded_at = get_current_time()
            row.user_cancelled = True
            if reason is not None:
                # Pydantic schema already enforces max_length=255.
                row.cancel_reason = reason
            db.add(row)
            db.commit()
            db.refresh(row)
        except SQLAlchemyError:
            db.rollback()
            logger.exception(
                "Failed to dismiss fall_event id=%s for user=%s",
                fall_event_id,
                user_id,
            )
            raise

        # Convert the mutated ORM instance to the response DTO.
        return FallEventResponse(
            id=row.id,
            uuid=str(row.uuid),
            device_id=row.device_id,
            detected_at=row.detected_at,
            confidence=float(row.confidence),
            model_version=row.model_version,
            latitude=float(row.latitude) if row.latitude is not None else None,
            longitude=float(row.longitude) if row.longitude is not None else None,
            address=row.address,
            user_notified_at=row.user_notified_at,
            user_responded_at=row.user_responded_at,
            user_cancelled=row.user_cancelled,
            cancel_reason=row.cancel_reason,
            sos_triggered=row.sos_triggered,
            status=derive_status(row),
            features=row.features if isinstance(row.features, dict) else None,
        )

    # ------------------------------------------------------------------
    # Internals
    # ------------------------------------------------------------------

    @staticmethod
    def _row_to_response(row: dict[str, Any]) -> FallEventResponse:
        """Project a raw SQL row into :class:`FallEventResponse`.

        We get the row from ``execute(text(...)).mappings()`` rather
        than the ORM, so we have a plain dict here. Values that map to
        ``Numeric`` columns come back as :class:`decimal.Decimal`;
        explicit ``float()`` casts keep the DTO JSON-serialisable
        without leaning on Pydantic's loose coercion.
        """

        class _Stub:
            """Tiny shim so :func:`derive_status` can reuse its
            attribute-based contract on a raw dict row.

            Defined inline because it has no other use site.
            """

            def __init__(self, mapping: dict[str, Any]) -> None:
                self.sos_triggered = bool(mapping.get("sos_triggered"))
                self.user_cancelled = bool(mapping.get("user_cancelled"))
                self.user_responded_at = mapping.get("user_responded_at")

        return FallEventResponse(
            id=int(row["id"]),
            uuid=str(row["uuid"]),
            device_id=int(row["device_id"]),
            detected_at=row["detected_at"],
            confidence=float(row["confidence"]),
            model_version=row.get("model_version"),
            latitude=float(row["latitude"]) if row.get("latitude") is not None else None,
            longitude=float(row["longitude"]) if row.get("longitude") is not None else None,
            address=row.get("address"),
            user_notified_at=row.get("user_notified_at"),
            user_responded_at=row.get("user_responded_at"),
            user_cancelled=bool(row.get("user_cancelled")),
            cancel_reason=row.get("cancel_reason"),
            sos_triggered=bool(row.get("sos_triggered")),
            status=derive_status(_Stub(row)),  # type: ignore[arg-type]
            features=row.get("features") if isinstance(row.get("features"), dict) else None,
        )


__all__ = [
    "FallEventService",
    "derive_status",
]
