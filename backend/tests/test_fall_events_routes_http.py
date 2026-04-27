"""HTTP-level tests for the fall-events mobile routes (slice 2c).

Stubs both the auth dependency (``get_target_profile_id``) and the
service-layer methods so the tests focus on routing + request/response
shape contracts without needing a real DB.

The full FastAPI app is built fresh per test (with the route under
test mounted) rather than reusing ``main_app`` so dependency overrides
don't leak between cases.
"""

from __future__ import annotations

from datetime import UTC, datetime

from fastapi import FastAPI, Header, HTTPException, status
from fastapi.testclient import TestClient

from app.api.routes.fall_events import router as fall_events_router
from app.core.dependencies import get_db, get_target_profile_id
from app.schemas.fall_telemetry import (
    FallEventListResponse,
    FallEventResponse,
)
from app.services.fall_event_service import FallEventService

# ---------------------------------------------------------------------------
# Stubs
# ---------------------------------------------------------------------------


_TIMESTAMP = datetime(2026, 4, 27, 10, 0, tzinfo=UTC)


def _stub_event(
    *,
    fall_event_id: int = 17,
    user_cancelled: bool = False,
    sos_triggered: bool = False,
    status_label: str = "detected",
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
        user_responded_at=_TIMESTAMP if user_cancelled else None,
        user_cancelled=user_cancelled,
        cancel_reason="Tôi ổn" if user_cancelled else None,
        sos_triggered=sos_triggered,
        status=status_label,
        features={"meta": {"request_id": "rq-abc"}},
    )


def _build_test_client(
    *,
    target_profile_id: int = 7,
    target_profile_overrides: dict[int, int] | None = None,
) -> TestClient:
    """Build a fresh FastAPI app with just the fall events router.

    ``target_profile_overrides`` lets tests simulate "caller asks for
    profile X but only owns profile 7" — overrides for non-owned
    profile ids raise 403 just like the real ``get_target_profile_id``.
    """
    app = FastAPI()
    app.include_router(fall_events_router, prefix="/mobile")

    overrides = target_profile_overrides or {}

    def _override_target(
        x_target_profile_id: int | None = Header(None, alias="X-Target-Profile-Id"),
    ) -> int:
        if x_target_profile_id is None:
            return target_profile_id
        if x_target_profile_id == target_profile_id:
            return target_profile_id
        if x_target_profile_id in overrides:
            return overrides[x_target_profile_id]
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
# List
# ---------------------------------------------------------------------------


class TestListFallEvents:
    def test_returns_list_response_shape(self, monkeypatch) -> None:
        captured: dict = {}

        def _fake_list(*, user_id, db, limit, offset):
            captured["user_id"] = user_id
            captured["limit"] = limit
            captured["offset"] = offset
            return FallEventListResponse(
                items=[_stub_event(fall_event_id=1), _stub_event(fall_event_id=2)],
                total=2, limit=limit, offset=offset,
            )

        monkeypatch.setattr(FallEventService, "list_for_user", _fake_list)
        client = _build_test_client()

        response = client.get("/mobile/fall-events")

        assert response.status_code == 200, response.text
        body = response.json()
        assert body["total"] == 2
        assert len(body["items"]) == 2
        assert body["items"][0]["id"] == 1
        assert body["limit"] == 20  # default
        assert body["offset"] == 0
        assert captured == {"user_id": 7, "limit": 20, "offset": 0}

    def test_limit_and_offset_are_propagated(self, monkeypatch) -> None:
        captured: dict = {}

        def _fake_list(*, user_id, db, limit, offset):
            captured.update({"limit": limit, "offset": offset})
            return FallEventListResponse(
                items=[], total=0, limit=limit, offset=offset,
            )

        monkeypatch.setattr(FallEventService, "list_for_user", _fake_list)
        client = _build_test_client()

        response = client.get("/mobile/fall-events?limit=5&offset=15")
        assert response.status_code == 200
        assert captured == {"limit": 5, "offset": 15}

    def test_limit_above_max_is_rejected_at_validation(self, monkeypatch) -> None:
        # FastAPI's Query(le=100) catches this at validation; service
        # never runs.
        called = {"hit": False}

        def _fake_list(**_kwargs):
            called["hit"] = True
            return FallEventListResponse(items=[], total=0, limit=0, offset=0)

        monkeypatch.setattr(FallEventService, "list_for_user", _fake_list)
        client = _build_test_client()

        response = client.get("/mobile/fall-events?limit=500")
        assert response.status_code == 422
        assert called["hit"] is False

    def test_target_profile_header_routes_to_caregiver_user(self, monkeypatch) -> None:
        captured: dict = {}

        def _fake_list(*, user_id, db, limit, offset):
            captured["user_id"] = user_id
            return FallEventListResponse(
                items=[], total=0, limit=limit, offset=offset,
            )

        monkeypatch.setattr(FallEventService, "list_for_user", _fake_list)
        # Caller is user 7, also has visibility into elder user 99 via a
        # caregiver relationship.
        client = _build_test_client(target_profile_overrides={99: 99})

        response = client.get(
            "/mobile/fall-events",
            headers={"X-Target-Profile-Id": "99"},
        )
        assert response.status_code == 200, response.text
        assert captured["user_id"] == 99

    def test_target_profile_header_for_unowned_user_is_403(self) -> None:
        # No override -> the stub raises 403 just like the real auth flow.
        client = _build_test_client()
        response = client.get(
            "/mobile/fall-events",
            headers={"X-Target-Profile-Id": "999"},
        )
        assert response.status_code == 403


# ---------------------------------------------------------------------------
# Detail
# ---------------------------------------------------------------------------


class TestGetFallEventDetail:
    def test_returns_event_response_on_hit(self, monkeypatch) -> None:
        def _fake_get(*, user_id, fall_event_id, db):
            return _stub_event(fall_event_id=fall_event_id)

        monkeypatch.setattr(FallEventService, "get_for_user", _fake_get)
        client = _build_test_client()

        response = client.get("/mobile/fall-events/17")
        assert response.status_code == 200
        body = response.json()
        assert body["id"] == 17
        assert body["status"] == "detected"

    def test_missing_event_is_404_not_403(self, monkeypatch) -> None:
        # The route returns 404 for both "doesn't exist" and "not yours"
        # to avoid leaking the difference (enumeration vector).
        def _fake_get(*, user_id, fall_event_id, db):
            return None

        monkeypatch.setattr(FallEventService, "get_for_user", _fake_get)
        client = _build_test_client()

        response = client.get("/mobile/fall-events/9999")
        assert response.status_code == 404
        assert response.json()["detail"] == "Không tìm thấy sự kiện ngã"

    def test_propagates_target_profile_to_service(self, monkeypatch) -> None:
        captured: dict = {}

        def _fake_get(*, user_id, fall_event_id, db):
            captured["user_id"] = user_id
            captured["fall_event_id"] = fall_event_id
            return _stub_event(fall_event_id=fall_event_id)

        monkeypatch.setattr(FallEventService, "get_for_user", _fake_get)
        client = _build_test_client(target_profile_overrides={42: 42})

        response = client.get(
            "/mobile/fall-events/100",
            headers={"X-Target-Profile-Id": "42"},
        )
        assert response.status_code == 200
        assert captured == {"user_id": 42, "fall_event_id": 100}


# ---------------------------------------------------------------------------
# Dismiss
# ---------------------------------------------------------------------------


class TestDismissFallEvent:
    def test_dismiss_with_reason_returns_updated_event(self, monkeypatch) -> None:
        captured: dict = {}

        def _fake_dismiss(*, user_id, fall_event_id, reason, db):
            captured.update({
                "user_id": user_id,
                "fall_event_id": fall_event_id,
                "reason": reason,
            })
            return _stub_event(
                fall_event_id=fall_event_id,
                user_cancelled=True,
                status_label="dismissed",
            )

        monkeypatch.setattr(FallEventService, "dismiss", _fake_dismiss)
        client = _build_test_client()

        response = client.post(
            "/mobile/fall-events/17/dismiss",
            json={"reason": "Tôi ổn"},
        )
        assert response.status_code == 200, response.text
        body = response.json()
        assert body["fall_event"]["id"] == 17
        assert body["fall_event"]["status"] == "dismissed"
        assert body["fall_event"]["user_cancelled"] is True
        assert captured == {"user_id": 7, "fall_event_id": 17, "reason": "Tôi ổn"}

    def test_dismiss_without_body_is_allowed(self, monkeypatch) -> None:
        captured: dict = {}

        def _fake_dismiss(*, user_id, fall_event_id, reason, db):
            captured["reason"] = reason
            return _stub_event(
                fall_event_id=fall_event_id,
                user_cancelled=True,
                status_label="dismissed",
            )

        monkeypatch.setattr(FallEventService, "dismiss", _fake_dismiss)
        client = _build_test_client()

        response = client.post("/mobile/fall-events/17/dismiss")
        assert response.status_code == 200
        # No body -> reason should be None.
        assert captured == {"reason": None}

    def test_dismiss_unknown_event_is_404(self, monkeypatch) -> None:
        def _fake_dismiss(*, user_id, fall_event_id, reason, db):
            return None

        monkeypatch.setattr(FallEventService, "dismiss", _fake_dismiss)
        client = _build_test_client()

        response = client.post("/mobile/fall-events/9999/dismiss")
        assert response.status_code == 404

    def test_reason_too_long_is_validation_error(self, monkeypatch) -> None:
        # Pydantic enforces max_length=255; service is never reached.
        called = {"hit": False}

        def _fake_dismiss(**_kwargs):
            called["hit"] = True
            return _stub_event()

        monkeypatch.setattr(FallEventService, "dismiss", _fake_dismiss)
        client = _build_test_client()

        response = client.post(
            "/mobile/fall-events/17/dismiss",
            json={"reason": "x" * 300},
        )
        assert response.status_code == 422
        assert called["hit"] is False
