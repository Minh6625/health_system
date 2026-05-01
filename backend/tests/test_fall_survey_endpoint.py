"""HTTP-level tests for the Module FA-2 fall survey endpoint.

``POST /mobile/fall-events/{id}/survey`` accepts the post-dismiss
"can stand?" answer from the Flutter ``FallStandUpSurveyScreen``.
Tests stub ``FallEventService.submit_survey`` so this file focuses on
routing + payload shape contracts; the service-level DB / push behaviour
is verified live in the Phase D smoke.

Pattern mirrors ``test_fall_events_routes_http.py`` (same target-profile
override stub, same fresh-app-per-test approach).
"""

from __future__ import annotations

from datetime import UTC, datetime

from fastapi import FastAPI, Header, HTTPException, status
from fastapi.testclient import TestClient

from app.api.routes.fall_events import router as fall_events_router
from app.core.dependencies import get_db, get_target_profile_id
from app.schemas.fall_telemetry import FallEventResponse
from app.services.fall_event_service import FallEventService


# ---------------------------------------------------------------------------
# Stubs (same shape as test_fall_events_routes_http.py)
# ---------------------------------------------------------------------------


_TIMESTAMP = datetime(2026, 5, 1, 0, 30, tzinfo=UTC)


def _stub_event(
    *,
    fall_event_id: int = 17,
    survey_answers: dict | None = None,
) -> FallEventResponse:
    return FallEventResponse(
        id=fall_event_id,
        uuid="11111111-2222-3333-4444-555555555555",
        device_id=5,
        detected_at=_TIMESTAMP,
        confidence=0.91,
        model_version="v1.0",
        latitude=21.0,
        longitude=105.8,
        address="Hà Nội",
        user_notified_at=_TIMESTAMP,
        user_responded_at=_TIMESTAMP,
        user_cancelled=True,
        cancel_reason="Tôi ổn",
        sos_triggered=False,
        status="dismissed",
        features={"meta": {"request_id": "rq-abc"}},
        survey_answers=survey_answers,
    )


def _build_test_client(*, target_profile_id: int = 7) -> TestClient:
    app = FastAPI()
    app.include_router(fall_events_router, prefix="/mobile")

    def _override_target(
        x_target_profile_id: int | None = Header(None, alias="X-Target-Profile-Id"),
    ) -> int:
        if x_target_profile_id is None or int(x_target_profile_id) == target_profile_id:
            return target_profile_id
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Không có quyền xem dữ liệu của người dùng này",
        )

    def _override_db():
        yield object()

    app.dependency_overrides[get_target_profile_id] = _override_target
    app.dependency_overrides[get_db] = _override_db
    return TestClient(app)


# ---------------------------------------------------------------------------
# Route tests — three answer shapes + 404 + validation
# ---------------------------------------------------------------------------


class TestSubmitFallSurveyRoute:
    """Module FA-2 ``POST /mobile/fall-events/{id}/survey`` contract."""

    def test_can_stand_true_returns_event_with_survey_attached(
        self, monkeypatch
    ) -> None:
        captured: dict = {}

        def _fake_submit(*, user_id, fall_event_id, can_stand, skipped, db):
            captured.update(
                {
                    "user_id": user_id,
                    "fall_event_id": fall_event_id,
                    "can_stand": can_stand,
                    "skipped": skipped,
                }
            )
            return _stub_event(
                fall_event_id=fall_event_id,
                survey_answers={
                    "can_stand": True,
                    "skipped": False,
                    "answered_at": _TIMESTAMP.isoformat(),
                },
            )

        monkeypatch.setattr(FallEventService, "submit_survey", _fake_submit)
        client = _build_test_client()

        response = client.post(
            "/mobile/fall-events/17/survey",
            json={"can_stand": True, "skipped": False},
        )

        assert response.status_code == 200, response.text
        body = response.json()
        # Echoed survey answers — Flutter swaps state without a follow-up GET.
        assert body["fall_event"]["id"] == 17
        assert body["fall_event"]["survey_answers"]["can_stand"] is True
        assert body["fall_event"]["survey_answers"]["skipped"] is False
        # Service was called with the right kwargs.
        assert captured == {
            "user_id": 7,
            "fall_event_id": 17,
            "can_stand": True,
            "skipped": False,
        }

    def test_can_stand_false_propagates_to_service(self, monkeypatch) -> None:
        """``can_stand=False`` is the soft-alert trigger path.

        We don't assert the FCM call here (that's a service-internal
        side-effect verified by the live E2E + the push-service unit
        tests).  We only verify the route forwards the boolean correctly.
        """
        captured: dict = {}

        def _fake_submit(*, user_id, fall_event_id, can_stand, skipped, db):
            captured["can_stand"] = can_stand
            return _stub_event(
                fall_event_id=fall_event_id,
                survey_answers={
                    "can_stand": False,
                    "skipped": False,
                    "answered_at": _TIMESTAMP.isoformat(),
                },
            )

        monkeypatch.setattr(FallEventService, "submit_survey", _fake_submit)
        client = _build_test_client()

        response = client.post(
            "/mobile/fall-events/17/survey",
            json={"can_stand": False, "skipped": False},
        )

        assert response.status_code == 200
        assert captured["can_stand"] is False
        assert response.json()["fall_event"]["survey_answers"]["can_stand"] is False

    def test_skipped_with_null_can_stand(self, monkeypatch) -> None:
        captured: dict = {}

        def _fake_submit(*, user_id, fall_event_id, can_stand, skipped, db):
            captured.update({"can_stand": can_stand, "skipped": skipped})
            return _stub_event(
                fall_event_id=fall_event_id,
                survey_answers={
                    "can_stand": None,
                    "skipped": True,
                    "answered_at": _TIMESTAMP.isoformat(),
                },
            )

        monkeypatch.setattr(FallEventService, "submit_survey", _fake_submit)
        client = _build_test_client()

        response = client.post(
            "/mobile/fall-events/17/survey",
            json={"can_stand": None, "skipped": True},
        )

        assert response.status_code == 200
        assert captured == {"can_stand": None, "skipped": True}
        assert response.json()["fall_event"]["survey_answers"]["skipped"] is True

    def test_unknown_event_is_404(self, monkeypatch) -> None:
        def _fake_submit(**_kwargs):
            return None

        monkeypatch.setattr(FallEventService, "submit_survey", _fake_submit)
        client = _build_test_client()

        response = client.post(
            "/mobile/fall-events/9999/survey",
            json={"can_stand": True, "skipped": False},
        )

        assert response.status_code == 404
        assert response.json()["detail"] == "Không tìm thấy sự kiện ngã"

    def test_default_payload_is_skipped(self, monkeypatch) -> None:
        """Empty body → defaults: can_stand=None, skipped=False.

        Flutter UI always sends an explicit shape so this is mostly a
        sanity guard on the Pydantic defaults.
        """
        captured: dict = {}

        def _fake_submit(*, user_id, fall_event_id, can_stand, skipped, db):
            captured.update({"can_stand": can_stand, "skipped": skipped})
            return _stub_event(fall_event_id=fall_event_id)

        monkeypatch.setattr(FallEventService, "submit_survey", _fake_submit)
        client = _build_test_client()

        response = client.post("/mobile/fall-events/17/survey", json={})

        assert response.status_code == 200, response.text
        assert captured == {"can_stand": None, "skipped": False}

    def test_invalid_can_stand_type_is_validation_error(self, monkeypatch) -> None:
        """``can_stand`` must be bool | null.

        Pydantic v2's default lax mode coerces ``"yes"`` / ``1`` to bool
        — so we use a value with no bool mapping (a list) to verify the
        validator actually rejects garbage.
        """
        called = {"hit": False}

        def _fake_submit(**_kwargs):
            called["hit"] = True
            return _stub_event()

        monkeypatch.setattr(FallEventService, "submit_survey", _fake_submit)
        client = _build_test_client()

        response = client.post(
            "/mobile/fall-events/17/survey",
            json={"can_stand": ["maybe"], "skipped": False},
        )

        assert response.status_code == 422
        assert called["hit"] is False

    def test_propagates_target_profile_to_service(self, monkeypatch) -> None:
        """Caregiver inspecting an elder's event still routes via target profile."""
        captured: dict = {}

        def _fake_submit(*, user_id, fall_event_id, can_stand, skipped, db):
            captured["user_id"] = user_id
            return _stub_event(fall_event_id=fall_event_id)

        monkeypatch.setattr(FallEventService, "submit_survey", _fake_submit)
        # The default override above only allows target_profile_id=7.
        client = _build_test_client()

        response = client.post(
            "/mobile/fall-events/17/survey",
            json={"can_stand": True, "skipped": False},
            headers={"X-Target-Profile-Id": "7"},
        )

        assert response.status_code == 200
        assert captured["user_id"] == 7

    def test_target_profile_for_unowned_user_is_403(self) -> None:
        client = _build_test_client()
        response = client.post(
            "/mobile/fall-events/17/survey",
            json={"can_stand": True, "skipped": False},
            headers={"X-Target-Profile-Id": "999"},
        )
        assert response.status_code == 403


# ---------------------------------------------------------------------------
# DTO projection — survey_answers passthrough
# ---------------------------------------------------------------------------


class TestSurveyAnswersInRowResponse:
    """Mirrors the existing ``TestRowToResponse`` patterns from
    ``test_fall_event_service.py`` — verifies the new column lands in
    the DTO without breaking the older shape.
    """

    _BASE_ROW = {
        "id": 17,
        "uuid": "11111111-2222-3333-4444-555555555555",
        "device_id": 5,
        "detected_at": _TIMESTAMP,
        "confidence": 0.91,
        "model_version": "v1.0",
        "latitude": 21.0,
        "longitude": 105.8,
        "address": "Hà Nội",
        "user_notified_at": _TIMESTAMP,
        "user_responded_at": None,
        "user_cancelled": False,
        "cancel_reason": None,
        "sos_triggered": False,
        "features": {"meta": {"request_id": "rq-abc"}},
    }

    def test_survey_answers_dict_passes_through(self) -> None:
        row = dict(self._BASE_ROW)
        row["survey_answers"] = {
            "can_stand": False,
            "skipped": False,
            "answered_at": _TIMESTAMP.isoformat(),
        }
        result = FallEventService._row_to_response(row)
        assert result.survey_answers == row["survey_answers"]

    def test_survey_answers_missing_key_yields_none(self) -> None:
        # Older app versions / pre-survey events have no key at all.
        row = dict(self._BASE_ROW)  # no survey_answers key
        result = FallEventService._row_to_response(row)
        assert result.survey_answers is None

    def test_survey_answers_malformed_value_yields_none(self) -> None:
        # Defensive: a legacy migration could land a string here.
        row = dict(self._BASE_ROW)
        row["survey_answers"] = "not a dict"  # malformed
        result = FallEventService._row_to_response(row)
        assert result.survey_answers is None
