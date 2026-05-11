from __future__ import annotations

from datetime import UTC, datetime
from types import SimpleNamespace

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.routes.emergency import router as emergency_router
from app.api.routes.risk import router as risk_router
from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.schemas.emergency import (
    LocationInfo,
    PatientInfo,
    ResolutionInfo,
    SOSEventResponse,
    SOSAlertsResponse,
    SOSEventListItem,
)
from app.services.emergency_service import EmergencyService


def _build_test_client(*, user_id: int = 7, role: str = "user") -> TestClient:
    app = FastAPI()
    app.include_router(emergency_router, prefix="/mobile")
    app.include_router(risk_router, prefix="/mobile")

    def _override_current_user():
        return SimpleNamespace(id=user_id, role=role)

    def _override_db():
        yield object()

    app.dependency_overrides[get_current_user] = _override_current_user
    app.dependency_overrides[get_db] = _override_db
    return TestClient(app)


def _sample_sos_detail(*, patient_user_id: int = 42) -> SOSEventResponse:
    return SOSEventResponse(
        sos_id=91,
        patient=PatientInfo(
            user_id=patient_user_id,
            full_name="Patient Elder",
            avatar_url=None,
            phone="0900000000",
            date_of_birth=None,
        ),
        trigger_type="vital_critical",
        trigger_time=datetime(2026, 4, 20, 10, 0, tzinfo=UTC),
        status="resolved",
        location=LocationInfo(
            latitude=10.5,
            longitude=106.7,
            address="123 Street",
            last_updated=datetime(2026, 4, 20, 10, 0, tzinfo=UTC),
        ),
        resolution=ResolutionInfo(
            resolved_at=datetime(2026, 4, 20, 10, 5, tzinfo=UTC),
            resolved_by_name="Caregiver",
            resolution_status="assisted",
            notes="Caregiver arrived",
        ),
    )


def test_trigger_sos_route_returns_sos_metadata_and_passes_named_payload(
    monkeypatch,
) -> None:
    client = _build_test_client(user_id=15)
    captured: dict[str, object] = {}

    def _trigger_sos(
        db,
        user_id: int,
        trigger_type: str = "manual",
        device_id=None,
        latitude=None,
        longitude=None,
        address=None,
        fall_event_id=None,
        *,
        commit: bool = True,
        send_push: bool = True,
    ):
        captured.update(
            {
                "user_id": user_id,
                "trigger_type": trigger_type,
                "device_id": device_id,
                "latitude": latitude,
                "longitude": longitude,
                "address": address,
                "commit": commit,
                "send_push": send_push,
            }
        )
        return (
            SimpleNamespace(id=55),
            {"recipient_user_ids": [101, 202, 303]},
        )

    monkeypatch.setattr(
        EmergencyService,
        "trigger_sos",
        staticmethod(_trigger_sos),
    )

    response = client.post(
        "/mobile/emergency/sos/trigger",
        json={
            "trigger_type": "manual",
            "latitude": 10.762622,
            "longitude": 106.660172,
            "address": "Ben Thanh",
        },
    )

    assert response.status_code == 200
    assert response.json() == {
        "success": True,
        "message": "Đã gửi tín hiệu khẩn cấp thành công",
        "sos_id": 55,
        "recipient_count": 3,
    }
    assert captured == {
        "user_id": 15,
        "trigger_type": "manual",
        "device_id": None,
        "latitude": 10.762622,
        "longitude": 106.660172,
        "address": "Ben Thanh",
        "commit": True,
        "send_push": True,
    }


def test_get_sos_alerts_route_uses_status_filter_and_current_user(monkeypatch) -> None:
    client = _build_test_client(user_id=33)
    calls: list[tuple[int, str]] = []

    def _get_alerts(db, caregiver_user_id: int, status: str):
        calls.append((caregiver_user_id, status))
        return SOSAlertsResponse(
            sos_alerts=[
                SOSEventListItem(
                    sos_id=91,
                    patient=PatientInfo(
                        user_id=44,
                        full_name="Patient Elder",
                        avatar_url=None,
                        phone="0900000000",
                        date_of_birth=None,
                    ),
                    trigger_type="manual",
                    trigger_time=datetime(2026, 4, 20, 10, 0, tzinfo=UTC),
                    status="resolved",
                    time_elapsed_minutes=6,
                )
            ],
            total_count=1,
            active_count=0,
            resolved_count=1,
        )

    monkeypatch.setattr(
        EmergencyService,
        "get_sos_alerts_for_caregiver",
        staticmethod(_get_alerts),
    )

    response = client.get("/mobile/emergency/caregiver/sos-alerts?status=resolved")

    assert response.status_code == 200
    assert calls == [(33, "resolved")]
    assert response.json()["resolved_count"] == 1


def test_get_sos_detail_route_rejects_unauthorized_access(monkeypatch) -> None:
    client = _build_test_client(user_id=7, role="user")

    # Bug fix G-3: the route now passes ``viewer_user_id`` and
    # ``viewer_is_admin`` as keyword args so the service can redact location
    # for caregivers without ``can_view_location``. Accept **kwargs to stay
    # compatible with both the old and new call shapes.
    monkeypatch.setattr(
        EmergencyService,
        "get_sos_detail",
        staticmethod(
            lambda db, sos_id, **_: _sample_sos_detail(patient_user_id=42),
        ),
    )
    monkeypatch.setattr(
        "app.repositories.emergency_repository.EmergencyRepository.check_user_has_access",
        lambda db, viewer_id, target_user_id: False,
    )

    response = client.get("/mobile/emergency/sos/91")

    assert response.status_code == 403
    assert response.json()["detail"] == "Bạn không có quyền xem chi tiết SOS này"


def test_resolve_sos_route_passes_resolution_status_and_notes(monkeypatch) -> None:
    client = _build_test_client(user_id=77, role="user")
    resolve_calls: list[tuple[int, int, str, str | None]] = []

    monkeypatch.setattr(
        EmergencyService,
        "get_sos_detail",
        staticmethod(lambda db, sos_id: _sample_sos_detail(patient_user_id=42)),
    )
    monkeypatch.setattr(
        "app.repositories.emergency_repository.EmergencyRepository.check_user_has_access",
        lambda db, viewer_id, target_user_id: True,
    )
    monkeypatch.setattr(
        EmergencyService,
        "resolve_sos_by_caregiver",
        staticmethod(
            lambda db, sos_id, caregiver_user_id, resolution_status, notes: (
                resolve_calls.append(
                    (sos_id, caregiver_user_id, resolution_status, notes),
                ),
                True,
            )[1]
        ),
    )

    response = client.post(
        "/mobile/emergency/sos/91/resolve",
        json={
            "resolution_status": "assisted",
            "notes": "Caregiver arrived",
        },
    )

    assert response.status_code == 200
    assert response.json() == {
        "success": True,
        "message": "Đã xác nhận xử lý SOS thành công",
    }
    assert resolve_calls == [(91, 77, "assisted", "Caregiver arrived")]


def test_risk_response_route_surfaces_recipient_count_for_escalation(
    monkeypatch,
) -> None:
    client = _build_test_client(user_id=51)

    monkeypatch.setattr(
        EmergencyService,
        "respond_to_risk_alert",
        staticmethod(
            lambda db, **kwargs: {
                "success": True,
                "status": "escalated",
                "acknowledged_at": datetime(2026, 4, 20, 10, 0, tzinfo=UTC),
                "sos_event_id": 12,
                "recipient_count": 2,
            }
        ),
    )

    response = client.post(
        "/mobile/risk/alerts/501/respond",
        json={
            "action": "help_requested",
            "source": "overlay",
            "risk_score_id": 901,
        },
    )

    assert response.status_code == 200
    assert response.json() == {
        "success": True,
        "status": "escalated",
        "acknowledged_at": "2026-04-20T10:00:00Z",
        "sos_event_id": 12,
        "recipient_count": 2,
    }
