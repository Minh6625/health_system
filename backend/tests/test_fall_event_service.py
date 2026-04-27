"""Unit tests for :mod:`app.services.fall_event_service`.

Exercises the pure-Python parts of the service (status derivation,
DTO projection from a raw row dict) without touching the DB. The HTTP
+ end-to-end behaviour is covered separately in
``test_fall_events_routes_http.py``.
"""

from __future__ import annotations

from datetime import UTC, datetime
from types import SimpleNamespace

from app.services.fall_event_service import FallEventService, derive_status


# ---------------------------------------------------------------------------
# Status derivation
# ---------------------------------------------------------------------------


class TestDeriveStatus:
    """The state machine that maps four DB columns to one status string.

    Order matters: ``escalated`` > ``dismissed`` > ``confirmed`` >
    ``detected``. Tests pin the precedence so a future contributor
    re-ordering the if/else doesn't silently change semantics.
    """

    def test_no_response_yet_is_detected(self) -> None:
        row = SimpleNamespace(
            sos_triggered=False, user_cancelled=False, user_responded_at=None,
        )
        assert derive_status(row) == "detected"

    def test_user_cancelled_is_dismissed(self) -> None:
        row = SimpleNamespace(
            sos_triggered=False,
            user_cancelled=True,
            user_responded_at=datetime.now(UTC),
        )
        assert derive_status(row) == "dismissed"

    def test_responded_without_cancel_is_confirmed(self) -> None:
        row = SimpleNamespace(
            sos_triggered=False,
            user_cancelled=False,
            user_responded_at=datetime.now(UTC),
        )
        assert derive_status(row) == "confirmed"

    def test_sos_triggered_overrides_dismissed(self) -> None:
        # User dismissed AFTER auto-SOS already fired — the escalated
        # state still wins because the SOS workflow is downstream and
        # the alert was already escalated to caregivers.
        row = SimpleNamespace(
            sos_triggered=True,
            user_cancelled=True,
            user_responded_at=datetime.now(UTC),
        )
        assert derive_status(row) == "escalated"

    def test_sos_triggered_overrides_confirmed(self) -> None:
        row = SimpleNamespace(
            sos_triggered=True,
            user_cancelled=False,
            user_responded_at=datetime.now(UTC),
        )
        assert derive_status(row) == "escalated"


# ---------------------------------------------------------------------------
# DTO projection
# ---------------------------------------------------------------------------


_BASE_ROW: dict = {
    "id": 17,
    "uuid": "11111111-2222-3333-4444-555555555555",
    "device_id": 5,
    "detected_at": datetime(2026, 4, 27, 10, 0, tzinfo=UTC),
    "confidence": 0.91,
    "model_version": "v1.0",
    "latitude": 21.0,
    "longitude": 105.8,
    "address": "Hà Nội",
    "user_notified_at": datetime(2026, 4, 27, 10, 0, 5, tzinfo=UTC),
    "user_responded_at": None,
    "user_cancelled": False,
    "cancel_reason": None,
    "sos_triggered": False,
    "features": {"meta": {"request_id": "rq-abc"}, "shap": []},
}


class TestRowToResponse:
    def test_happy_path_projects_every_field(self) -> None:
        # ``_row_to_response`` is private but stable enough to test
        # directly — every public surface goes through it.
        result = FallEventService._row_to_response(dict(_BASE_ROW))
        assert result.id == 17
        assert result.device_id == 5
        assert result.confidence == 0.91
        assert result.model_version == "v1.0"
        assert result.latitude == 21.0
        assert result.longitude == 105.8
        assert result.address == "Hà Nội"
        assert result.user_cancelled is False
        assert result.sos_triggered is False
        # No user response yet, no SOS -> "detected".
        assert result.status == "detected"
        # Features should pass through verbatim.
        assert result.features == _BASE_ROW["features"]

    def test_decimal_columns_are_cast_to_float(self) -> None:
        # SQLAlchemy returns Numeric columns as decimal.Decimal; the
        # service must coerce so the JSON response is float, not str.
        from decimal import Decimal

        row = dict(_BASE_ROW)
        row["confidence"] = Decimal("0.873")
        row["latitude"] = Decimal("21.000123")
        row["longitude"] = Decimal("105.800456")

        result = FallEventService._row_to_response(row)

        assert isinstance(result.confidence, float)
        assert result.confidence == 0.873
        assert isinstance(result.latitude, float)
        assert isinstance(result.longitude, float)

    def test_null_optional_fields_pass_through_as_none(self) -> None:
        row = dict(_BASE_ROW)
        for k in (
            "model_version", "latitude", "longitude", "address",
            "user_notified_at", "user_responded_at", "cancel_reason", "features",
        ):
            row[k] = None
        result = FallEventService._row_to_response(row)
        assert result.model_version is None
        assert result.latitude is None
        assert result.longitude is None
        assert result.address is None
        assert result.user_notified_at is None
        assert result.user_responded_at is None
        assert result.cancel_reason is None
        assert result.features is None

    def test_features_must_be_dict_to_pass_through(self) -> None:
        # Defensive: a buggy persistence path could land a list / scalar
        # in the JSONB column. The DTO must keep features=None instead
        # of failing Pydantic validation later.
        row = dict(_BASE_ROW)
        row["features"] = "not a dict"  # malformed
        result = FallEventService._row_to_response(row)
        assert result.features is None

    def test_status_derivation_on_dismissed_row(self) -> None:
        row = dict(_BASE_ROW)
        row["user_cancelled"] = True
        row["user_responded_at"] = datetime(2026, 4, 27, 10, 0, 12, tzinfo=UTC)
        row["cancel_reason"] = "Tôi ổn"
        result = FallEventService._row_to_response(row)
        assert result.status == "dismissed"
        assert result.cancel_reason == "Tôi ổn"

    def test_status_derivation_on_escalated_row(self) -> None:
        row = dict(_BASE_ROW)
        row["sos_triggered"] = True
        result = FallEventService._row_to_response(row)
        assert result.status == "escalated"
