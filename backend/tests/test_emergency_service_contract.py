from __future__ import annotations

from datetime import UTC, date, datetime
from types import SimpleNamespace
from unittest.mock import Mock, patch

import pytest
from fastapi import HTTPException

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
    ), patch(
        # Bug fix G-3: the service now batches a per-patient location
        # visibility lookup. The caregiver here (id=21) has location
        # access on patient 7, matching the legacy behaviour where the
        # response shipped LocationInfo whenever the SOS had coordinates.
        "app.services.emergency_service.EmergencyRepository.get_caregiver_location_visibility",
        return_value={7: True},
    ):
        result = EmergencyService.get_sos_alerts_for_caregiver(
            db,
            caregiver_user_id=21,
            status="all",
        )

    assert result.total_count == 1
    assert result.sos_alerts[0].trigger_type == "vital_critical"
    assert result.sos_alerts[0].location is not None
    assert result.sos_alerts[0].location.address == "123 Street"


def test_get_sos_alerts_for_caregiver_redacts_location_when_permission_revoked() -> None:
    """G-3 regression: caregivers without ``can_view_location`` no longer see
    coordinates/address in the SOS list response, even when the SOS event
    persisted them."""
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
        return_value=set(),
        create=True,
    ), patch(
        "app.services.emergency_service.EmergencyRepository.get_caregiver_location_visibility",
        return_value={7: False},
    ):
        result = EmergencyService.get_sos_alerts_for_caregiver(
            db,
            caregiver_user_id=21,
            status="all",
        )

    assert result.total_count == 1
    assert result.sos_alerts[0].location is None


def test_get_sos_detail_redacts_location_for_caregiver_without_permission() -> None:
    """G-3 regression: the SOS detail endpoint redacts ``LocationInfo`` when the
    caregiver's relationship row has ``can_view_location=False``."""
    db = object()
    sos = _build_sos(sos_id=77, trigger_type="manual")
    patient = _build_patient(user_id=7, full_name="Patient Elder")

    with patch(
        "app.services.emergency_service.EmergencyRepository.get_sos_detail",
        return_value=sos,
    ), patch(
        "app.services.emergency_service.EmergencyRepository.get_user_by_id",
        return_value=patient,
    ), patch(
        "app.services.emergency_service.EmergencyRepository.get_fall_event_by_id",
        return_value=None,
    ), patch(
        "app.services.emergency_service.EmergencyRepository.get_risk_alert_response_by_sos_event_id",
        return_value=None,
        create=True,
    ), patch(
        "app.services.emergency_service.EmergencyRepository.get_caregiver_view_permissions",
        return_value=(True, False),  # can_receive_alerts=True, can_view_location=False
    ):
        detail = EmergencyService.get_sos_detail(
            db,
            77,
            viewer_user_id=21,
            viewer_is_admin=False,
        )

    assert detail is not None
    assert detail.location is None


def test_get_sos_detail_keeps_location_for_patient_self_view() -> None:
    """G-3 regression: a patient viewing their own SOS always sees the full
    location regardless of relationship rows."""
    db = object()
    sos = _build_sos(sos_id=77, trigger_type="manual")
    patient = _build_patient(user_id=7, full_name="Patient Elder")

    with patch(
        "app.services.emergency_service.EmergencyRepository.get_sos_detail",
        return_value=sos,
    ), patch(
        "app.services.emergency_service.EmergencyRepository.get_user_by_id",
        return_value=patient,
    ), patch(
        "app.services.emergency_service.EmergencyRepository.get_fall_event_by_id",
        return_value=None,
    ), patch(
        "app.services.emergency_service.EmergencyRepository.get_risk_alert_response_by_sos_event_id",
        return_value=None,
        create=True,
    ):
        detail = EmergencyService.get_sos_detail(
            db,
            77,
            viewer_user_id=7,  # same as patient.user_id ⇒ self-view
            viewer_is_admin=False,
        )

    assert detail is not None
    assert detail.location is not None
    assert detail.location.address == "123 Street"


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


def test_trigger_sos_uses_active_device_when_request_omits_device_id() -> None:
    db = object()
    sos_event = SimpleNamespace(id=91, user_id=12, trigger_type="manual")

    with patch(
        "app.services.emergency_service.EmergencyRepository.get_active_device_id_for_user",
        return_value=44,
    ) as get_active_device_id, patch(
        "app.services.emergency_service.EmergencyRepository.create_sos_event",
        return_value=sos_event,
    ) as create_sos_event, patch(
        "app.services.emergency_service.EmergencyService._create_alerts_for_sos_event",
        return_value={"recipient_user_ids": [77]},
    ):
        result = EmergencyService.trigger_sos(
            db,
            user_id=12,
            trigger_type="manual",
        )

    get_active_device_id.assert_called_once_with(db, 12)
    create_sos_event.assert_called_once()
    assert create_sos_event.call_args.kwargs["device_id"] == 44
    assert result[0] is sos_event


def test_trigger_sos_rejects_request_without_active_device() -> None:
    db = object()

    with patch(
        "app.services.emergency_service.EmergencyRepository.get_active_device_id_for_user",
        return_value=None,
    ):
        try:
            EmergencyService.trigger_sos(
                db,
                user_id=12,
                trigger_type="manual",
            )
        except HTTPException as error:
            assert error.status_code == 400
            assert "thiết bị hoạt động" in error.detail
        else:
            raise AssertionError("Expected HTTPException when no active device exists")


# ---------------------------------------------------------------------------
# P1 #4 — _build_fall_detection_xai derives from real FallEvent (no hardcoded mock)
# ---------------------------------------------------------------------------


class TestBuildFallDetectionXai:
    @staticmethod
    def _make_fall_event(*, confidence: float | None, features: dict | None) -> SimpleNamespace:
        return SimpleNamespace(
            id=1,
            confidence=confidence,
            features=features,
            detected_at=datetime(2026, 4, 25, tzinfo=UTC),
        )

    def test_returns_none_for_none_input(self) -> None:
        assert EmergencyService._build_fall_detection_xai(None) is None

    def test_uses_real_confidence_no_fake_default(self) -> None:
        fall_event = self._make_fall_event(confidence=0.42, features=None)
        xai = EmergencyService._build_fall_detection_xai(fall_event)
        assert xai is not None
        assert xai.confidence == pytest.approx(0.42)

    def test_zero_confidence_when_missing(self) -> None:
        fall_event = self._make_fall_event(confidence=None, features=None)
        xai = EmergencyService._build_fall_detection_xai(fall_event)
        assert xai is not None
        assert xai.confidence == 0.0

    def test_no_features_uses_single_detection_marker(self) -> None:
        fall_event = self._make_fall_event(confidence=0.85, features=None)
        xai = EmergencyService._build_fall_detection_xai(fall_event)
        assert xai is not None
        assert len(xai.timeline) == 1
        assert xai.timeline[0].time_offset == "T+0s"
        assert "85%" in xai.timeline[0].event

    def test_persisted_timeline_is_used_when_present(self) -> None:
        features = {
            "timeline": [
                {"time_offset": "T+0s", "event": "Impact 12.4g"},
                {"time_offset": "T+0.5s", "event": "Posture: prone"},
                # Invalid entries should be skipped:
                {"time_offset": "", "event": ""},
                "not-a-dict",
            ],
        }
        fall_event = self._make_fall_event(confidence=0.8, features=features)
        xai = EmergencyService._build_fall_detection_xai(fall_event)
        assert xai is not None
        assert [e.time_offset for e in xai.timeline] == ["T+0s", "T+0.5s"]

    def test_persisted_explanation_short_text_is_used(self) -> None:
        features = {
            "explanation": {
                "short_text": "Tac dong manh + nam yen 5s. Nguy co cao.",
                "clinical_note": "...",
            }
        }
        fall_event = self._make_fall_event(confidence=0.91, features=features)
        xai = EmergencyService._build_fall_detection_xai(fall_event)
        assert xai is not None
        assert xai.trigger_reason == "Tac dong manh + nam yen 5s. Nguy co cao."

    def test_trigger_reason_falls_back_to_variant_summary(self) -> None:
        features = {"variant": "fall_1", "source": "tick"}
        fall_event = self._make_fall_event(confidence=0.78, features=features)
        xai = EmergencyService._build_fall_detection_xai(fall_event)
        assert xai is not None
        assert "78%" in xai.trigger_reason
        assert "fall_1" in xai.trigger_reason
        assert "tick" in xai.trigger_reason

    def test_trigger_reason_generic_when_no_metadata(self) -> None:
        fall_event = self._make_fall_event(confidence=0.0, features=None)
        xai = EmergencyService._build_fall_detection_xai(fall_event)
        assert xai is not None
        assert "thiết bị đeo" in xai.trigger_reason

    def test_invalid_features_ignored_safely(self) -> None:
        fall_event = self._make_fall_event(confidence=0.7, features="not-a-dict")  # type: ignore[arg-type]
        xai = EmergencyService._build_fall_detection_xai(fall_event)
        assert xai is not None
        assert xai.confidence == pytest.approx(0.7)
        assert len(xai.timeline) == 1  # fallback marker
