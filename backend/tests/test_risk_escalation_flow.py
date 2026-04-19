from __future__ import annotations

from datetime import UTC, datetime
from unittest.mock import Mock, patch

from fastapi import HTTPException

from app.api.routes.risk import _dispatch_risk_alerts, RISK_ALERT_AUTO_ESCALATE_AFTER_SECONDS
from app.services.emergency_service import EmergencyService


class TestRiskEscalationFlow:
    def test_dispatch_targets_patient_only_and_enriches_payload(self) -> None:
        db = Mock()

        with patch(
            "app.services.risk_alert_service.NotificationService.is_risk_alert_in_cooldown",
            return_value=False,
        ), patch(
            "app.services.risk_alert_service.NotificationService.create_risk_alerts",
            return_value={77: 1001},
        ) as create_risk_alerts, patch(
            "app.services.risk_alert_service.PushNotificationService.send_risk_push_alerts"
        ) as send_risk_push_alerts:
            _dispatch_risk_alerts(
                db,
                device_id=12,
                user_id=77,
                risk_level="medium",
                score=84.2,
                risk_score_id=991,
            )

        create_kwargs = create_risk_alerts.call_args.kwargs
        assert create_kwargs["recipient_user_ids"] == [77]
        assert create_kwargs["risk_score_id"] == 991
        assert create_kwargs["details"] == {
            "device_id": 12,
            "risk_level": "medium",
            "risk_score_id": 991,
            "escalation_stage": "initial",
            "auto_escalate_after_seconds": RISK_ALERT_AUTO_ESCALATE_AFTER_SECONDS,
        }

        push_kwargs = send_risk_push_alerts.call_args.kwargs
        assert push_kwargs["recipient_user_ids"] == [77]
        assert push_kwargs["risk_score_id"] == 991
        assert push_kwargs["escalation_stage"] == "initial"
        assert push_kwargs["auto_escalate_after_seconds"] == RISK_ALERT_AUTO_ESCALATE_AFTER_SECONDS
        assert push_kwargs["alert_type"] == "risk_high"
        assert push_kwargs["device_id"] == 12

    def test_safe_response_persists_ack_only(self) -> None:
        db = Mock()
        db.commit = Mock()
        db.rollback = Mock()

        alert = Mock(id=501, user_id=10, alert_type="risk_high")
        response_row = Mock(
            notification_id=501,
            response_action="safe",
            responded_at=datetime(2026, 4, 16, tzinfo=UTC),
            sos_event_id=None,
        )

        with patch(
            "app.services.emergency_service.EmergencyRepository.get_alert_by_id",
            return_value=alert,
        ), patch(
            "app.services.emergency_service.EmergencyRepository.get_risk_alert_response",
            return_value=None,
        ), patch(
            "app.services.emergency_service.EmergencyRepository.create_risk_alert_response",
            return_value=response_row,
        ) as create_response, patch(
            "app.services.emergency_service.EmergencyService.trigger_sos"
        ) as trigger_sos, patch(
            "app.services.emergency_service.PushNotificationService.send_sos_push_alerts"
        ) as send_sos_push_alerts:
            result = EmergencyService.respond_to_risk_alert(
                db,
                current_user_id=10,
                notification_id=501,
                response_action="safe",
                risk_score_id=333,
                source="overlay",
            )

        assert result["status"] == "acknowledged"
        assert result["sos_event_id"] is None
        assert result["acknowledged_at"] == response_row.responded_at
        create_response.assert_called_once()
        trigger_sos.assert_not_called()
        send_sos_push_alerts.assert_not_called()
        db.commit.assert_called_once()

    def test_help_requested_creates_sos_once(self) -> None:
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
            "recipient_user_ids": [10, 11],
            "title": "SOS title",
            "body": "SOS body",
            "alert_type": "sos",
            "trigger_type": "manual",
            "notification_id_by_user": {10: 3001, 11: 3002},
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
        ) as trigger_sos, patch(
            "app.services.emergency_service.PushNotificationService.send_sos_push_alerts"
        ) as send_sos_push_alerts:
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
        trigger_sos.assert_called_once_with(
            db,
            user_id=10,
            trigger_type="manual",
            device_id=15,
            latitude=10.123,
            longitude=106.456,
            address="Test address",
            commit=False,
            send_push=False,
        )
        send_sos_push_alerts.assert_called_once_with(
            db,
            recipient_user_ids=[10, 11],
            title="SOS title",
            body="SOS body",
            sos_id=888,
            alert_type="sos",
            trigger_type="manual",
            notification_id_by_user={10: 3001, 11: 3002},
        )
        db.commit.assert_called_once()

    def test_duplicate_response_returns_existing_result(self) -> None:
        db = Mock()
        db.commit = Mock()
        db.rollback = Mock()

        alert = Mock(id=900, user_id=10, alert_type="risk_high")
        existing_response = Mock(
            notification_id=900,
            response_action="timeout_escalated",
            responded_at=datetime(2026, 4, 16, tzinfo=UTC),
            sos_event_id=42,
        )

        with patch(
            "app.services.emergency_service.EmergencyRepository.get_alert_by_id",
            return_value=alert,
        ), patch(
            "app.services.emergency_service.EmergencyRepository.get_risk_alert_response",
            return_value=existing_response,
        ), patch(
            "app.services.emergency_service.EmergencyRepository.create_risk_alert_response"
        ) as create_response, patch(
            "app.services.emergency_service.EmergencyService.trigger_sos"
        ) as trigger_sos, patch(
            "app.services.emergency_service.PushNotificationService.send_sos_push_alerts"
        ) as send_sos_push_alerts:
            result = EmergencyService.respond_to_risk_alert(
                db,
                current_user_id=10,
                notification_id=900,
                response_action="timeout_escalated",
                source="overlay",
            )

        assert result["status"] == "duplicate"
        assert result["sos_event_id"] == 42
        assert result["acknowledged_at"] == existing_response.responded_at
        create_response.assert_not_called()
        trigger_sos.assert_not_called()
        send_sos_push_alerts.assert_not_called()
        db.commit.assert_not_called()

    def test_invalid_action_is_rejected(self) -> None:
        db = Mock()
        db.commit = Mock()
        db.rollback = Mock()

        alert = Mock(id=901, user_id=10, alert_type="risk_high")

        with patch(
            "app.services.emergency_service.EmergencyRepository.get_alert_by_id",
            return_value=alert,
        ), patch(
            "app.services.emergency_service.EmergencyRepository.get_risk_alert_response",
            return_value=None,
        ):
            try:
                EmergencyService.respond_to_risk_alert(
                    db,
                    current_user_id=10,
                    notification_id=901,
                    response_action="not-valid",
                    source="overlay",
                )
            except HTTPException as exc:
                assert exc.status_code == 400
            else:
                raise AssertionError("Expected HTTPException for invalid action")
