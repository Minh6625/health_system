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
    RecentAlertDeepLink,
    RecentAlertItem,
    RecentAlertsResponse,
    ResolutionInfo,
    SOSEventResponse,
    SOSAlertsResponse,
    SOSEventListItem,
)
from app.services.emergency_service import EmergencyService


def _build_test_client(*, user_id: int = 7, role: str = "user") -> TestClient:
    app = FastAPI()
    app.include_router(emergency_router, prefix="/api/v1/mobile")
    app.include_router(risk_router, prefix="/api/v1/mobile")

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
        "/api/v1/mobile/emergency/sos/trigger",
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

    response = client.get("/api/v1/mobile/emergency/caregiver/sos-alerts?status=resolved")

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

    response = client.get("/api/v1/mobile/emergency/sos/91")

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
        "/api/v1/mobile/emergency/sos/91/resolve",
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
        "/api/v1/mobile/risk/alerts/501/respond",
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


# ----------------------------------------------------------------------------
# Recent alerts (caregiver feed) — GET /caregiver/patients/{id}/recent-alerts
# ----------------------------------------------------------------------------


def _build_recent_alerts(
    *,
    item_count: int = 2,
    permission_state: str = "granted",
    window_days: int = 7,
) -> RecentAlertsResponse:
    items = [
        RecentAlertItem(
            id=1000 + i,
            uuid=f"00000000-0000-0000-0000-{i:012d}",
            alert_type="risk_high" if i % 2 == 0 else "fall_detected",
            severity="high" if i % 2 == 0 else "critical",
            title="Cảnh báo sức khoẻ" if i % 2 == 0 else "Phát hiện té ngã",
            message=f"Sample alert #{i}",
            occurred_at=datetime(2026, 5, 19, 10, i, tzinfo=UTC),
            is_resolved=False,
            deep_link=RecentAlertDeepLink(
                type="alert" if i % 2 == 0 else "fall_event",
                id=2000 + i,
            ),
        )
        for i in range(item_count)
    ]
    return RecentAlertsResponse(
        items=items,
        permission_state=permission_state,  # type: ignore[arg-type]
        window_days=window_days,
        total_in_window=len(items),
    )


def test_recent_alerts_route_passes_caller_and_default_query(monkeypatch) -> None:
    """Happy path: caregiver hits the endpoint, service receives the
    expected viewer/patient/days/limit, response shape matches schema."""
    client = _build_test_client(user_id=11)
    captured: dict[str, object] = {}

    def _service(db, *, viewer_user_id, patient_user_id, days, limit):
        captured.update(
            {
                "viewer_user_id": viewer_user_id,
                "patient_user_id": patient_user_id,
                "days": days,
                "limit": limit,
            }
        )
        return _build_recent_alerts(item_count=2)

    monkeypatch.setattr(
        EmergencyService,
        "get_recent_alerts_for_patient",
        staticmethod(_service),
    )

    response = client.get(
        "/api/v1/mobile/emergency/caregiver/patients/42/recent-alerts"
    )

    assert response.status_code == 200
    body = response.json()
    assert body["permission_state"] == "granted"
    assert body["window_days"] == 7
    assert len(body["items"]) == 2
    # Defaults are explicit per the FastAPI route signature; assert both so a
    # future drive-by edit to ``Query(...)`` defaults breaks the test.
    assert captured == {
        "viewer_user_id": 11,
        "patient_user_id": 42,
        "days": 7,
        "limit": 10,
    }


def test_recent_alerts_route_forwards_custom_query_params(monkeypatch) -> None:
    """Caregiver overrides ``days``/``limit`` — the route must pipe both
    through verbatim (within the ``ge``/``le`` bounds enforced by Query)."""
    client = _build_test_client(user_id=11)
    captured: dict[str, object] = {}

    def _service(db, *, viewer_user_id, patient_user_id, days, limit):
        captured.update({"days": days, "limit": limit})
        return _build_recent_alerts(item_count=0)

    monkeypatch.setattr(
        EmergencyService,
        "get_recent_alerts_for_patient",
        staticmethod(_service),
    )

    response = client.get(
        "/api/v1/mobile/emergency/caregiver/patients/42/recent-alerts"
        "?days=14&limit=25"
    )

    assert response.status_code == 200
    assert captured == {"days": 14, "limit": 25}


def test_recent_alerts_route_rejects_out_of_range_query(monkeypatch) -> None:
    """``Query(ge/le)`` bounds must reject ``days=0`` and ``limit=99``
    before the service is called — the service stub asserts on entry."""
    client = _build_test_client(user_id=11)
    monkeypatch.setattr(
        EmergencyService,
        "get_recent_alerts_for_patient",
        staticmethod(
            lambda *a, **kw: (_ for _ in ()).throw(
                AssertionError("service must not be called")
            )
        ),
    )

    too_small = client.get(
        "/api/v1/mobile/emergency/caregiver/patients/42/recent-alerts?days=0"
    )
    too_large = client.get(
        "/api/v1/mobile/emergency/caregiver/patients/42/recent-alerts?limit=999"
    )

    assert too_small.status_code == 422
    assert too_large.status_code == 422


def test_recent_alerts_route_returns_empty_list_when_no_data(monkeypatch) -> None:
    """Granted permission but no alerts in the window — still 200 with
    ``permission_state=granted``. Mobile distinguishes empty from denied via
    this field, not via HTTP status."""
    client = _build_test_client(user_id=11)
    monkeypatch.setattr(
        EmergencyService,
        "get_recent_alerts_for_patient",
        staticmethod(
            lambda db, **_: _build_recent_alerts(item_count=0),
        ),
    )

    response = client.get(
        "/api/v1/mobile/emergency/caregiver/patients/42/recent-alerts"
    )

    assert response.status_code == 200
    body = response.json()
    assert body["items"] == []
    assert body["permission_state"] == "granted"
    assert body["total_in_window"] == 0


def test_recent_alerts_route_propagates_403_from_service(monkeypatch) -> None:
    """When the service raises 403 (no relationship OR no
    ``can_receive_alerts``), the route must surface it untouched. Mobile
    relies on the status code to switch into the ``permissionDenied`` UI
    state."""
    from fastapi import HTTPException

    client = _build_test_client(user_id=11)

    def _denied(*_a, **_kw):
        raise HTTPException(
            status_code=403,
            detail="You do not have permission to view this patient's alerts",
        )

    monkeypatch.setattr(
        EmergencyService,
        "get_recent_alerts_for_patient",
        staticmethod(_denied),
    )

    response = client.get(
        "/api/v1/mobile/emergency/caregiver/patients/42/recent-alerts"
    )

    assert response.status_code == 403
    assert response.json()["detail"].startswith("You do not have permission")
