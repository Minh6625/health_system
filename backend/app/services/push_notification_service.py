from __future__ import annotations

import json
import logging
import os
from pathlib import Path
from typing import Any, Sequence
from datetime import datetime, timezone

try:
    import firebase_admin
    from firebase_admin import credentials, messaging
    _sdk_available = True
except ModuleNotFoundError:
    firebase_admin = None  # type: ignore[assignment]
    credentials = None  # type: ignore[assignment]
    messaging = None  # type: ignore[assignment]
    _sdk_available = False
from sqlalchemy.orm import Session

from app.models.push_token_model import UserPushToken

logger = logging.getLogger(__name__)


class PushNotificationService:
    """Handles FCM initialization and push fan-out delivery."""

    _init_attempted = False
    _enabled = False

    @staticmethod
    def _push_disabled_for_e2e() -> bool:
        return os.getenv("E2E_DISABLE_PUSH", "").strip() == "1"

    @staticmethod
    def is_sos_emergency_takeover(alert_type: str | None) -> bool:
        """Return ``True`` when an SOS / fall alert must use the data-only
        takeover path (no FCM ``notification`` payload, Flutter background
        handler will dispatch a fullScreenIntent local notification).
        """
        return (alert_type or "").strip().lower() in {
            "fall_detected",
            "fall_detection",
            "sos",
            "manual",
        }

    @staticmethod
    def _token_prefix(token: str) -> str:
        normalized = (token or "").strip()
        if not normalized:
            return ""
        return normalized[:24]

    @classmethod
    def _ensure_initialized(cls) -> bool:
        if not _sdk_available:
            logger.warning("FCM disabled: firebase_admin package is not installed")
            return False

        if cls._enabled:
            return True
        if cls._init_attempted:
            return False

        cls._init_attempted = True

        service_account_path = os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH", "").strip()
        service_account_json = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON", "").strip()

        if not service_account_path and not service_account_json:
            logger.warning(
                "FCM disabled: FIREBASE_SERVICE_ACCOUNT_PATH/FIREBASE_SERVICE_ACCOUNT_JSON not provided",
            )
            return False

        try:
            if service_account_json:
                cert_data = json.loads(service_account_json)
                cred = credentials.Certificate(cert_data)
            else:
                cred = credentials.Certificate(service_account_path)

            try:
                firebase_admin.get_app()
            except ValueError:
                firebase_admin.initialize_app(cred)

            cls._enabled = True
            logger.info(
                "FCM initialized successfully: source=%s",
                "json-env"
                if service_account_json
                else Path(service_account_path).name,
            )
            return True
        except Exception as exc:  # noqa: BLE001
            logger.exception("FCM initialization failed: %s", exc)
            return False

    # ------------------------------------------------------------------
    # Invalidate stale push tokens (shared helper)
    # ------------------------------------------------------------------

    @staticmethod
    def _invalidate_stale_tokens(
        db: Session,
        responses: Any,
        sent_token_refs: list[tuple[int, str]],
    ) -> None:
        """Deactivate tokens that FCM reports as invalid."""
        invalid_tokens: list[str] = []
        for index, send_response in enumerate(responses.responses):
            if send_response.success:
                continue

            error_code = getattr(send_response.exception, "code", "") or ""
            code_text = str(error_code).lower()
            if "registration-token-not-registered" in code_text or "invalid-argument" in code_text:
                _, token_value = sent_token_refs[index]
                invalid_tokens.append(token_value)

        if invalid_tokens:
            (
                db.query(UserPushToken)
                .filter(UserPushToken.token.in_(invalid_tokens))
                .update({"is_active": False}, synchronize_session=False)
            )
            db.commit()

    # ------------------------------------------------------------------
    # SOS push alerts (existing)
    # ------------------------------------------------------------------

    @classmethod
    def send_sos_push_alerts(
        cls,
        db: Session,
        *,
        recipient_user_ids: Sequence[int],
        title: str,
        body: str,
        sos_id: int,
        alert_type: str,
        trigger_type: str,
        notification_id_by_user: dict[int, int],
    ) -> None:
        """Fan out SOS push notifications.

        P1 #5 fix: SOS / fall_detected emergencies are sent as **data-only**
        messages (no FCM ``notification`` payload). The Flutter background
        handler then re-emits them as local ``flutter_local_notifications``
        with ``fullScreenIntent: true`` on the ``sos_fullscreen_alerts``
        channel — matching the proven ``risk_critical`` takeover path.
        """
        if not recipient_user_ids:
            return

        if cls._push_disabled_for_e2e():
            logger.info(
                "Skipping SOS push fan-out because E2E_DISABLE_PUSH=1",
            )
            return

        if not cls._ensure_initialized():
            return

        rows = (
            db.query(UserPushToken)
            .filter(
                UserPushToken.user_id.in_(list(recipient_user_ids)),
                UserPushToken.is_active.is_(True),
            )
            .all()
        )
        if not rows:
            return

        created_at = datetime.now(timezone.utc).isoformat()
        messages: list[Any] = []
        sent_token_refs: list[tuple[int, str]] = []
        is_emergency_takeover = cls.is_sos_emergency_takeover(alert_type)

        logger.info(
            "Preparing FCM SOS push: recipients=%s active_tokens=%s alert_type=%s trigger=%s sos_id=%s takeover=%s",
            list(recipient_user_ids),
            len(rows),
            alert_type,
            trigger_type,
            sos_id,
            is_emergency_takeover,
        )

        for row in rows:
            notification_id = notification_id_by_user.get(int(row.user_id))
            data = {
                "type": "sos_alert",
                "sos_id": str(sos_id),
                "sos_event_id": str(sos_id),
                "alert_type": alert_type,
                "trigger_type": trigger_type,
                "notification_id": str(notification_id or ""),
                "created_at": created_at,
                "title": title,
                "body": body,
                "click_action": "FLUTTER_NOTIFICATION_CLICK",
            }

            android_config: Any
            notification_payload: Any
            if is_emergency_takeover:
                # Data-only message: Flutter background handler dispatches
                # a fullScreenIntent local notification.
                android_config = messaging.AndroidConfig(priority="high")
                notification_payload = None
            else:
                # Non-emergency SOS-style alert (legacy behavior).
                android_config = messaging.AndroidConfig(
                    priority="high",
                    notification=messaging.AndroidNotification(
                        channel_id="sos_fullscreen_alerts",
                        click_action="FLUTTER_NOTIFICATION_CLICK",
                        sound="default",
                        priority="max",
                    ),
                )
                notification_payload = messaging.Notification(title=title, body=body)

            messages.append(
                messaging.Message(
                    token=row.token,
                    notification=notification_payload,
                    data=data,
                    android=android_config,
                )
            )
            sent_token_refs.append((row.id, row.token))

        if not messages:
            return

        try:
            response = messaging.send_each(messages)
        except Exception as exc:  # noqa: BLE001
            logger.exception("FCM send failed: %s", exc)
            return

        cls._invalidate_stale_tokens(db, response, sent_token_refs)
        logger.info(
            "FCM SOS push sent: success=%s failure=%s alert_type=%s sos_id=%s",
            response.success_count,
            response.failure_count,
            alert_type,
            sos_id,
        )

    # ------------------------------------------------------------------
    # Risk push alerts (A2 — new)
    # ------------------------------------------------------------------

    @classmethod
    def send_risk_push_alerts(
        cls,
        db: Session,
        *,
        recipient_user_ids: Sequence[int],
        title: str,
        body: str,
        alert_type: str,
        risk_level: str,
        device_id: int | None = None,
        notification_id_by_user: dict[int, int],
        risk_score_id: int | None = None,
        escalation_stage: str = "initial",
        auto_escalate_after_seconds: int = 60,
        fcm_channel: str | None = None,
    ) -> None:
        """Send FCM push notifications for a risk alert event.

        Follows the same fan-out pattern as ``send_sos_push_alerts`` but
        uses a risk-specific data payload and configurable Android
        notification channel (from ``EscalationRule.fcm_channel``).
        """
        if not recipient_user_ids:
            return

        if cls._push_disabled_for_e2e():
            logger.info(
                "Skipping risk push fan-out because E2E_DISABLE_PUSH=1",
            )
            return

        if not cls._ensure_initialized():
            logger.warning(
                "Risk push skipped: FCM unavailable for alert_type=%s device=%s recipients=%s",
                alert_type,
                device_id,
                list(recipient_user_ids),
            )
            return

        rows = (
            db.query(UserPushToken)
            .filter(
                UserPushToken.user_id.in_(list(recipient_user_ids)),
                UserPushToken.is_active.is_(True),
            )
            .all()
        )
        if not rows:
            logger.warning(
                "Risk push skipped: no active push tokens for recipients=%s alert_type=%s device=%s",
                list(recipient_user_ids),
                alert_type,
                device_id,
            )
            return

        channel_id = fcm_channel or "risk_alerts"
        created_at = datetime.now(timezone.utc).isoformat()
        messages: list[Any] = []
        sent_token_refs: list[tuple[int, str]] = []
        is_critical_takeover = (
            alert_type.strip().lower() == "risk_critical"
            or risk_level.strip().lower() == "critical"
        )

        logger.info(
            "Preparing FCM risk push: recipients=%s active_tokens=%s alert_type=%s level=%s device=%s channel=%s",
            list(recipient_user_ids),
            len(rows),
            alert_type,
            risk_level,
            device_id,
            channel_id,
        )

        for row in rows:
            notification_id = notification_id_by_user.get(int(row.user_id))
            data = {
                "type": "risk_alert",
                "alert_type": alert_type,
                "risk_level": risk_level,
                "device_id": str(device_id or ""),
                "notification_id": str(notification_id or ""),
                "risk_score_id": str(risk_score_id or ""),
                "escalation_stage": escalation_stage,
                "auto_escalate_after_seconds": str(auto_escalate_after_seconds),
                "created_at": created_at,
                "title": title,
                "body": body,
                "click_action": "FLUTTER_NOTIFICATION_CLICK",
            }

            android_config = messaging.AndroidConfig(priority="high")
            notification = None
            if not is_critical_takeover:
                notification = messaging.Notification(title=title, body=body)
                android_config = messaging.AndroidConfig(
                    priority="high",
                    notification=messaging.AndroidNotification(
                        channel_id=channel_id,
                        click_action="FLUTTER_NOTIFICATION_CLICK",
                        sound="default",
                        priority="max",
                    ),
                )

            messages.append(
                messaging.Message(
                    token=row.token,
                    notification=notification,
                    data=data,
                    android=android_config,
                )
            )
            sent_token_refs.append((row.id, row.token))
            logger.info(
                "FCM risk push target: user=%s token_prefix=%s notification_id=%s",
                row.user_id,
                cls._token_prefix(row.token),
                notification_id,
            )

        if not messages:
            return

        try:
            response = messaging.send_each(messages)
        except Exception as exc:  # noqa: BLE001
            logger.exception("FCM risk push send failed: %s", exc)
            return

        cls._invalidate_stale_tokens(db, response, sent_token_refs)
        logger.info(
            "FCM risk push sent: success=%s failure=%s alert_type=%s level=%s device=%s",
            response.success_count,
            response.failure_count,
            alert_type,
            risk_level,
            device_id,
        )
