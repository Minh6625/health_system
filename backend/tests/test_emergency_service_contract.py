from __future__ import annotations

from datetime import UTC, date, datetime
from types import SimpleNamespace
from unittest.mock import Mock, patch

from app.services.emergency_service import EmergencyService


def _build_patient(*, user_id: int, full_name: str) -> SimpleNamespace:
    return SimpleNamespace(
        id=user_id,
        full_name=full_name,
        avatar_url=None,
        phone="0900000000",
        date_of_birth=date(1940, 1, 1),
    )


def _build_sos(
    *,
    sos_id: int = 55,
    user_id: int = 7,
    trigger_type: str = "manual",
    status: str = "active",
    resolution_notes: str | None = None,
) -> SimpleNamespace:
    return SimpleNamespace(
        id=sos_id,
        user_id=user_id,
        trigger_type=trigger_type,
        triggered_at=datetime(2026, 4, 20, 10, 0, tzinfo=UTC),
        latitude=10.5,
        longitude=106.7,
        address="123 Street",
        fall_event_id=None,
        status=status,
        resolved_at=datetime(2026, 4, 20, 10, 5, tzinfo=UTC)
        if status == "resolved"
        else None,
        resolved_by_user_id=99 if status == "resolved" else None,
        resolution_notes=resolution_notes,
        device_id=12,
    )


def test_get_sos_alerts_for_caregiver_marks_risk_origin_rows_as_vital_critical() -> None:
    db = object()
    patient = _build_patient(user_id=7, full_name="Patient Elder")
    sos = _build_sos(sos_id=55, trigger_type="manual")

    with patch(
        "app.services.emergency_service.EmergencyRepository.get_sos_alerts_by_caregiver",
        return_value=([sos], 1, 1, 0),
    ), patch(
        "app.services.emergency_service.EmergencyRepository.get_user_by_id",
        return_value=patient,
    ), patch(
        "app.services.emergency_service.EmergencyRepository.get_risk_response_sos_event_ids",
        return_value={55},
        create=True,
    ):
        result = EmergencyService.get_sos_alerts_for_caregiver(
            db,
            caregiver_user_id=21,
            status="all",
        )

    assert result.total_count == 1
    assert result.sos_alerts[0].trigger_type == "vital_critical"


def test_get_sos_detail_marks_risk_origin_and_parses_resolution_notes() -> None:
    db = object()
    sos = _build_sos(
        sos_id=77,
        trigger_type="auto",
        status="resolved",
        resolution_notes="[assisted] Caregiver arrived",
    )
    patient = _build_patient(user_id=7, full_name="Patient Elder")
    resolver = _build_patient(user_id=99, full_name="Caregiver A")

    def _get_user_by_id(_db, user_id: int):
        if user_id == 7:
            return patient
        if user_id == 99:
            return resolver
        return None

    with patch(
        "app.services.emergency_service.EmergencyRepository.get_sos_detail",
        return_value=sos,
    ), patch(
        "app.services.emergency_service.EmergencyRepository.get_user_by_id",
        side_effect=_get_user_by_id,
    ), patch(
        "app.services.emergency_service.EmergencyRepository.get_fall_event_by_id",
        return_value=None,
    ), patch(
        "app.services.emergency_service.EmergencyRepository.get_risk_alert_response_by_sos_event_id",
        return_value=SimpleNamespace(notification_id=601),
        create=True,
    ):
        detail = EmergencyService.get_sos_detail(db, 77)

    assert detail is not None
    assert detail.trigger_type == "vital_critical"
    assert detail.resolution is not None
    assert detail.resolution.resolution_status == "assisted"
    assert detail.resolution.notes == "Caregiver arrived"


def test_help_requested_response_includes_recipient_count() -> None:
    db = Mock()
    db.commit = Mock()
    db.rollback = Mock()

    alert = Mock(id=777, user_id=10, alert_type="risk_critical")
    response_row = Mock(
        notification_id=777,
        response_action="help_requested",
        responded_at=datetime(2026, 4, 16, tzinfo=UTC),
        sos_event_id=None,
    )
    sos_event = Mock(id=888)
    dispatch_info = {
        "recipient_user_ids": [10, 11, 12],
        "title": "SOS title",
        "body": "SOS body",
        "alert_type": "sos",
        "trigger_type": "manual",
        "notification_id_by_user": {10: 3001, 11: 3002, 12: 3003},
    }

    with patch(
        "app.services.emergency_service.EmergencyRepository.get_alert_by_id",
        return_value=alert,
    ), patch(
        "app.services.emergency_service.EmergencyRepository.get_risk_alert_response",
        return_value=None,
    ), patch(
        "app.services.emergency_service.EmergencyRepository.create_risk_alert_response",
        return_value=response_row,
    ), patch(
        "app.services.emergency_service.EmergencyService.trigger_sos",
        return_value=(sos_event, dispatch_info),
    ), patch(
        "app.services.emergency_service.PushNotificationService.send_sos_push_alerts",
    ):
        result = EmergencyService.respond_to_risk_alert(
            db,
            current_user_id=10,
            notification_id=777,
            response_action="help_requested",
            risk_score_id=444,
            source="overlay",
            device_id=15,
            latitude=10.123,
            longitude=106.456,
            address="Test address",
        )

    assert result["status"] == "escalated"
    assert result["sos_event_id"] == 888
    assert result["recipient_count"] == 3
