"""Unit tests for :class:`PushNotificationService`.

Covers two surfaces:

* **takeover-routing helper** (``is_sos_emergency_takeover``) — the
  P1 #5 fix that routes SOS / fall_detected emergencies through the
  data-only path so the Flutter background handler can dispatch a
  fullScreenIntent local notification.
* **send_fall_critical_alert** (Phase 4B-full slice 2d) — the dedicated
  fall-detected push path that builds a ``type='fall_alert'`` envelope
  with ``fall_event_id`` for the mobile fall_event_handler to deep-link
  on.
"""

from __future__ import annotations

from typing import Any
from unittest.mock import MagicMock, patch

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


# ---------------------------------------------------------------------------
# send_fall_critical_alert (Phase 4B-full slice 2d)
# ---------------------------------------------------------------------------


def _fake_token_row(*, user_id: int, token: str) -> Any:
    row = MagicMock()
    row.user_id = user_id
    row.token = token
    row.id = user_id  # row.id only used for invalidation logging
    return row


def _make_db_with_tokens(rows: list[Any]) -> Any:
    """Build a Mock Session whose ``.query(...).filter(...).all()``
    chain returns the supplied rows."""
    db = MagicMock()
    chain = MagicMock()
    chain.filter.return_value.all.return_value = rows
    db.query.return_value = chain
    return db


class TestSendFallCriticalAlert:
    """Pin the contract of the new fall-detected push path."""

    @pytest.fixture(autouse=True)
    def _ensure_e2e_flag_off(self, monkeypatch: pytest.MonkeyPatch) -> None:
        # The E2E_DISABLE_PUSH guard short-circuits the method; clear
        # it so each test exercises the actual fan-out path.
        monkeypatch.delenv("E2E_DISABLE_PUSH", raising=False)

    def test_no_recipients_is_a_no_op(self) -> None:
        db = MagicMock()
        # Even with FCM disabled, an empty recipients list must not
        # blow up — the method short-circuits before initialisation.
        with patch.object(
            PushNotificationService, "_ensure_initialized", return_value=True,
        ) as ensure_init:
            PushNotificationService.send_fall_critical_alert(
                db,
                recipient_user_ids=[],
                fall_event_id=17,
                fall_event_uuid="abc",
                title="t",
                body="b",
                confidence=0.9,
            )
        ensure_init.assert_not_called()
        db.query.assert_not_called()

    def test_e2e_disabled_short_circuits(
        self, monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        monkeypatch.setenv("E2E_DISABLE_PUSH", "1")
        db = MagicMock()
        with patch.object(
            PushNotificationService, "_ensure_initialized", return_value=True,
        ) as ensure_init:
            PushNotificationService.send_fall_critical_alert(
                db,
                recipient_user_ids=[7],
                fall_event_id=17,
                fall_event_uuid="abc",
                title="t",
                body="b",
                confidence=0.9,
            )
        # Must NOT touch FCM init or DB when the e2e flag is set.
        ensure_init.assert_not_called()
        db.query.assert_not_called()

    def test_fcm_unavailable_skips_quietly(self) -> None:
        db = MagicMock()
        with patch.object(
            PushNotificationService, "_ensure_initialized", return_value=False,
        ):
            # Must not raise — FCM unavailability is logged but doesn't
            # propagate an exception that would 500 the IMU window route.
            PushNotificationService.send_fall_critical_alert(
                db,
                recipient_user_ids=[7],
                fall_event_id=17,
                fall_event_uuid="abc",
                title="t",
                body="b",
                confidence=0.9,
            )
        # No DB query when FCM is unavailable — initialisation gate
        # short-circuits before token lookup.
        db.query.assert_not_called()

    def test_no_active_tokens_short_circuits_send(self) -> None:
        db = _make_db_with_tokens(rows=[])
        with patch.object(
            PushNotificationService, "_ensure_initialized", return_value=True,
        ), patch(
            "app.services.push_notification_service.messaging"
        ) as messaging_mod:
            PushNotificationService.send_fall_critical_alert(
                db,
                recipient_user_ids=[7],
                fall_event_id=17,
                fall_event_uuid="abc",
                title="t",
                body="b",
                confidence=0.9,
            )
        messaging_mod.send_each.assert_not_called()

    def test_payload_uses_takeover_envelope(self) -> None:
        rows = [_fake_token_row(user_id=7, token="tok-7")]
        db = _make_db_with_tokens(rows)

        with patch.object(
            PushNotificationService, "_ensure_initialized", return_value=True,
        ), patch(
            "app.services.push_notification_service.messaging"
        ) as messaging_mod:
            # Capture what messages.send_each receives.
            response = MagicMock()
            response.success_count = 1
            response.failure_count = 0
            response.responses = []
            messaging_mod.send_each.return_value = response

            # ``Message`` / ``AndroidConfig`` / ``Notification`` are
            # used as constructors inside the method; let MagicMock
            # accept any kwargs and remember them.
            captured: dict[str, Any] = {}

            def _capture_message(
                token: str, notification: Any, data: dict, android: Any,
            ) -> Any:
                captured["token"] = token
                captured["notification"] = notification
                captured["data"] = data
                captured["android"] = android
                return MagicMock()

            messaging_mod.Message.side_effect = _capture_message

            PushNotificationService.send_fall_critical_alert(
                db,
                recipient_user_ids=[7],
                fall_event_id=42,
                fall_event_uuid="11111111-2222-3333-4444-555555555555",
                title="Phát hiện ngã",
                body="Bạn có ổn không?",
                confidence=0.91,
            )

        # Always-takeover for fall: the FCM ``notification`` payload
        # must be ``None`` so the OS doesn't auto-render a banner that
        # bypasses the full-screen alert flow.
        assert captured["notification"] is None
        # Data envelope shape pinned for the mobile handler.
        data = captured["data"]
        assert data["type"] == "fall_alert"
        assert data["event_type"] == "fall_detected"
        assert data["fall_event_id"] == "42"
        assert data["fall_event_uuid"] == "11111111-2222-3333-4444-555555555555"
        assert data["title"] == "Phát hiện ngã"
        assert data["body"] == "Bạn có ổn không?"
        # Confidence formatted with 3 decimals — consistent precision
        # across all platforms.
        assert data["confidence"] == "0.910"
        # click_action must be set so Android's notification tap
        # triggers Flutter's onMessageOpenedApp handler.
        assert data["click_action"] == "FLUTTER_NOTIFICATION_CLICK"
        # Token + send was called with the expected count.
        assert captured["token"] == "tok-7"
        messaging_mod.send_each.assert_called_once()

    def test_fans_out_to_all_recipients(self) -> None:
        rows = [
            _fake_token_row(user_id=7, token="tok-7"),
            _fake_token_row(user_id=8, token="tok-8"),
            _fake_token_row(user_id=9, token="tok-9"),
        ]
        db = _make_db_with_tokens(rows)

        with patch.object(
            PushNotificationService, "_ensure_initialized", return_value=True,
        ), patch(
            "app.services.push_notification_service.messaging"
        ) as messaging_mod:
            response = MagicMock()
            response.success_count = 3
            response.failure_count = 0
            response.responses = []
            messaging_mod.send_each.return_value = response
            messaging_mod.Message.side_effect = lambda **kw: MagicMock()

            PushNotificationService.send_fall_critical_alert(
                db,
                recipient_user_ids=[7, 8, 9],
                fall_event_id=42,
                fall_event_uuid="abc",
                title="t",
                body="b",
                confidence=0.91,
            )

        # One Message constructed per active token.
        assert messaging_mod.Message.call_count == 3
        messaging_mod.send_each.assert_called_once()

    def test_send_failure_does_not_propagate(self) -> None:
        rows = [_fake_token_row(user_id=7, token="tok-7")]
        db = _make_db_with_tokens(rows)

        with patch.object(
            PushNotificationService, "_ensure_initialized", return_value=True,
        ), patch(
            "app.services.push_notification_service.messaging"
        ) as messaging_mod:
            messaging_mod.Message.side_effect = lambda **kw: MagicMock()
            messaging_mod.send_each.side_effect = RuntimeError(
                "simulated FCM outage"
            )

            # Must NOT propagate — the IMU window route's HTTP 200 must
            # not flip to 500 just because FCM is down.
            PushNotificationService.send_fall_critical_alert(
                db,
                recipient_user_ids=[7],
                fall_event_id=42,
                fall_event_uuid="abc",
                title="t",
                body="b",
                confidence=0.91,
            )
