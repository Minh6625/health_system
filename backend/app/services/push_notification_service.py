from __future__ import annotations

import json
import logging
import os
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
            logger.info("FCM initialized successfully")
            return True
        except Exception as exc:  # noqa: BLE001
            logger.exception("FCM initialization failed: %s", exc)
            return False

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
        if not recipient_user_ids:
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

            messages.append(
                messaging.Message(
                    token=row.token,
                    notification=messaging.Notification(title=title, body=body),
                    data=data,
                    android=messaging.AndroidConfig(
                        priority="high",
                        notification=messaging.AndroidNotification(
                            channel_id="sos_fullscreen_alerts",
                            click_action="FLUTTER_NOTIFICATION_CLICK",
                            sound="default",
                            priority="PRIORITY_MAX",
                        ),
                    ),
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

        invalid_tokens: list[str] = []
        for index, send_response in enumerate(response.responses):
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
