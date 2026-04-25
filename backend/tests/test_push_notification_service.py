"""Unit tests for :class:`PushNotificationService` takeover-routing helper.

Covers the P1 #5 fix: SOS / fall_detected emergencies must route through the
data-only takeover path (no FCM ``notification`` payload) so the Flutter
background handler can dispatch a fullScreenIntent local notification.
"""

from __future__ import annotations

import pytest

from app.services.push_notification_service import PushNotificationService


class TestIsSosEmergencyTakeover:
    @pytest.mark.parametrize(
        "alert_type",
        [
            "fall_detected",
            "FALL_DETECTED",
            "  fall_detected  ",
            "fall_detection",
            "sos",
            "SOS",
            "manual",
            "Manual",
        ],
    )
    def test_emergency_alert_types_take_over(self, alert_type: str) -> None:
        assert PushNotificationService.is_sos_emergency_takeover(alert_type) is True

    @pytest.mark.parametrize(
        "alert_type",
        [
            None,
            "",
            "vitals_threshold",
            "generic_alert",
            "risk_high",
            "risk_critical",
            "info",
        ],
    )
    def test_non_emergency_alert_types_do_not_take_over(
        self, alert_type: str | None
    ) -> None:
        assert PushNotificationService.is_sos_emergency_takeover(alert_type) is False
