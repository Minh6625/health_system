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
from sqlalchemy import text
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

        # B-Lane: attach latest known location for the device so caregivers
        # can see where the patient is when the risk alert arrives.
        # Falls back to None if no location has ever been recorded.
        location_lat: str = ""
        location_lng: str = ""
        location_address: str = ""
        if device_id is not None:
            try:
                loc_row = db.execute(
                    text(
                        """
                        SELECT latitude, longitude, address
                        FROM (
                            SELECT latitude, longitude, address, detected_at AS ts
                            FROM fall_events
                            WHERE device_id = :did AND latitude IS NOT NULL
                            UNION ALL
                            SELECT se.latitude, se.longitude, se.address,
                                   se.triggered_at AS ts
                            FROM sos_events se
                            JOIN devices d ON d.id = :did
                            WHERE se.user_id = d.user_id AND se.latitude IS NOT NULL
                        ) loc
                        ORDER BY ts DESC
                        LIMIT 1
                        """
                    ),
                    {"did": int(device_id)},
                ).mappings().first()
                if loc_row is not None:
                    location_lat = str(float(loc_row["latitude"]))
                    location_lng = str(float(loc_row["longitude"]))
                    location_address = loc_row["address"] or ""
            except Exception:
                logger.debug(
                    "Could not query last known location for device=%s (non-fatal)",
                    device_id,
                )

        # recipient_count = number of unique users receiving this push.
        unique_recipient_count = len(set(int(r.user_id) for r in rows))

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
                "recipient_count": str(unique_recipient_count),
            }
            if location_lat:
                data["latitude"] = location_lat
                data["longitude"] = location_lng
            if location_address:
                data["location_address"] = location_address

            # Phase 8 B4 (2026-05-20): risk push CHUYEN sang DATA-ONLY de
            # khu duplicate notification. Truoc fix: BE gui ca
            # ``messaging.Notification(title, body)`` block lan ``data``
            # block. Khi app foreground hoac vua tu background ve, OS
            # tu render 1 banner tu ``notification`` block + Flutter
            # ``_handleFcmForegroundMessage`` -> ``_processNotificationEvent``
            # -> ``_emergencyAdapter.presentMissedAlert`` render banner thu
            # 2 -> user thay 2 notification trung. Background path da co
            # ``_showBackgroundCriticalRiskNotification`` tu render qua
            # ``_backgroundNotifications.show`` cho cold-start, foreground
            # path da co ``_processNotificationEvent`` xu ly. Bo
            # ``notification`` block o BE de client la nguon duy nhat
            # render UI - giong pattern fall takeover (line 533).
            android_config = messaging.AndroidConfig(priority="high")
            notification = None
            data["channel_id"] = channel_id

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

    # ------------------------------------------------------------------
    # Fall critical push (Phase 4B-full slice 2d)
    # ------------------------------------------------------------------

    @classmethod
    def send_fall_critical_alert(
        cls,
        db: Session,
        *,
        recipient_user_ids: Sequence[int],
        fall_event_id: int,
        fall_event_uuid: str,
        title: str,
        body: str,
        confidence: float,
        notification_id_by_user: dict[int, int] | None = None,
        patient_user_id: int | None = None,
    ) -> None:
        """Fan out a fall-detected push to the user + their caregivers.

        Phase 4B-full slice 2d (see baseline doc §7k). Distinct from
        :meth:`send_sos_push_alerts` because:

        * It carries a ``fall_event_id`` (not an ``sos_id``) so the
          mobile handler can deep-link into ``FallAlertScreen`` /
          ``FallHistoryScreen`` without the heavy SOS state-machine
          stomping on the alert.
        * The data envelope uses ``type='fall_alert'`` +
          ``event_type='fall_detected'`` so the mobile
          ``fall_event_handler.dart`` can branch cleanly off the
          existing SOS / risk handlers.
        * Always uses the takeover path (data-only, full-screen-intent
          via ``sos_fullscreen_alerts`` channel) — false negatives on
          a real fall are dangerous so we never let the OS suppress
          the notification.

        ``confidence`` lands in the FCM data payload so the mobile
        side can decide whether to auto-open the alert vs just show
        a banner. Bounded ``[0, 1]`` by the upstream model-api
        contract; we trust the value here.
        """
        if not recipient_user_ids:
            return

        if cls._push_disabled_for_e2e():
            logger.info(
                "Skipping fall critical push fan-out because E2E_DISABLE_PUSH=1",
            )
            return

        if not cls._ensure_initialized():
            logger.warning(
                "Fall critical push skipped: FCM unavailable for fall_event_id=%s recipients=%s",
                fall_event_id,
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
                "Fall critical push skipped: no active tokens for fall_event_id=%s recipients=%s",
                fall_event_id,
                list(recipient_user_ids),
            )
            return

        notif_map = notification_id_by_user or {}
        created_at = datetime.now(timezone.utc).isoformat()
        messages: list[Any] = []
        sent_token_refs: list[tuple[int, str]] = []

        logger.info(
            "Preparing FCM fall critical push: recipients=%s active_tokens=%s fall_event_id=%s confidence=%.3f",
            list(recipient_user_ids),
            len(rows),
            fall_event_id,
            float(confidence),
        )

        for row in rows:
            notification_id = notif_map.get(int(row.user_id))
            # ADR-023 Phase 7 S13: per-recipient flag so the mobile handler
            # can differentiate the patient (fullscreen FallAlertScreen) from
            # caregivers (banner-only "family member fell" notification).
            # When ``patient_user_id`` is ``None`` (legacy call-site or
            # patient-only fan-out) every recipient is treated as patient.
            is_patient = (
                patient_user_id is None
                or int(row.user_id) == int(patient_user_id)
            )
            data = {
                # Discriminator that the mobile fall_event_handler keys on.
                "type": "fall_alert",
                "event_type": "fall_detected",
                # ``alert_type`` is required by the mobile foreground
                # mapper (``isActionableNotificationType``) — without it,
                # ``_handleFcmForegroundMessage`` silently drops the push
                # because the mapper rejects empty alert_type.
                "alert_type": "fall_detected",
                "fall_event_id": str(fall_event_id),
                "fall_event_uuid": str(fall_event_uuid),
                "confidence": f"{float(confidence):.3f}",
                "notification_id": str(notification_id or ""),
                "created_at": created_at,
                "title": title,
                "body": body,
                "click_action": "FLUTTER_NOTIFICATION_CLICK",
                # S13: caregiver-facing flag. String "true"/"false" because
                # FCM data payloads must be Map<String, String>.
                "is_recipient_patient": "true" if is_patient else "false",
            }

            # Always-takeover for fall alerts: a missed fall = potential
            # untreated injury, so we never let the OS suppress the
            # notification or let the user "swipe to dismiss" without
            # surfacing the full-screen alert first.
            android_config = messaging.AndroidConfig(priority="high")
            messages.append(
                messaging.Message(
                    token=row.token,
                    notification=None,  # data-only, takeover
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
            logger.exception("FCM fall critical push send failed: %s", exc)
            return

        cls._invalidate_stale_tokens(db, response, sent_token_refs)
        logger.info(
            "FCM fall critical push sent: success=%s failure=%s fall_event_id=%s",
            response.success_count,
            response.failure_count,
            fall_event_id,
        )

    # ------------------------------------------------------------------
    # Module FA-2 — Option 3-Lite follow-up concern push
    # ------------------------------------------------------------------

    @classmethod
    def send_fall_followup_concern(
        cls,
        db: Session,
        *,
        patient_user_id: int,
        fall_event_id: int,
        fall_event_uuid: str,
    ) -> None:
        """Caregiver-facing soft push when patient said OK but cannot stand.

        Distinct from :meth:`send_fall_critical_alert`:

        * **NOT** a full-screen takeover.  Patient already confirmed
          they're conscious; this is a *check-in* nudge, not an SOS.
        * Goes through the normal FCM ``notification`` payload (not
          data-only) so the OS shows it as a regular noti — caregiver
          can read on their lock screen and decide whether to call /
          visit.
        * Does NOT push to the patient (would defeat the purpose;
          they're the one being checked on).
        * Severity ``warning`` so the caregiver app's noti center
          renders it distinctly from a real SOS.
        """
        # Lazy import to dodge the circular dependency with
        # ``emergency_repository`` (which itself imports models that
        # transitively import this module via ``alert_constants``).
        from app.repositories.emergency_repository import EmergencyRepository

        caregivers = EmergencyRepository.get_alert_recipient_user_ids(
            db, patient_user_id=int(patient_user_id)
        )
        if not caregivers:
            logger.info(
                "Fall follow-up concern skipped: no caregivers for patient_user_id=%s",
                patient_user_id,
            )
            return

        if cls._push_disabled_for_e2e():
            logger.info(
                "Skipping fall follow-up concern fan-out because E2E_DISABLE_PUSH=1 "
                "(would have notified caregivers=%s patient_user_id=%s)",
                caregivers,
                patient_user_id,
            )
            return

        if not cls._ensure_initialized():
            logger.warning(
                "Fall follow-up concern skipped: FCM unavailable for fall_event_id=%s caregivers=%s",
                fall_event_id,
                caregivers,
            )
            return

        rows = (
            db.query(UserPushToken)
            .filter(
                UserPushToken.user_id.in_(list(caregivers)),
                UserPushToken.is_active.is_(True),
            )
            .all()
        )
        if not rows:
            logger.warning(
                "Fall follow-up concern skipped: no active tokens for fall_event_id=%s caregivers=%s",
                fall_event_id,
                caregivers,
            )
            return

        # Resolve patient name once so the noti is operator-friendly.
        from app.models.user_model import User  # local to avoid widening top-level imports

        patient_row = (
            db.query(User).filter(User.id == int(patient_user_id)).first()
        )
        patient_name = (
            patient_row.full_name if patient_row and patient_row.full_name else f"Người dùng #{patient_user_id}"
        )

        title = f"{patient_name} cần kiểm tra"
        body = (
            "Đã té ngã và xác nhận tỉnh táo nhưng không thể tự đứng dậy. "
            "Hãy gọi điện hỏi thăm hoặc đến nhà ngay khi có thể."
        )
        created_at = datetime.now(timezone.utc).isoformat()

        logger.info(
            "Preparing FCM fall follow-up concern push: caregivers=%s active_tokens=%s fall_event_id=%s patient_user_id=%s",
            caregivers,
            len(rows),
            fall_event_id,
            patient_user_id,
        )

        messages: list[Any] = []
        sent_token_refs: list[tuple[int, str]] = []
        for row in rows:
            data = {
                # Distinct discriminator so the mobile handler doesn't
                # confuse this with the takeover ``fall_alert`` push.
                "type": "fall_followup",
                "event_type": "fall_followup_concern",
                "fall_event_id": str(fall_event_id),
                "fall_event_uuid": str(fall_event_uuid),
                "patient_user_id": str(patient_user_id),
                "severity": "warning",
                "created_at": created_at,
                "title": title,
                "body": body,
                "click_action": "FLUTTER_NOTIFICATION_CLICK",
            }
            messages.append(
                messaging.Message(
                    token=row.token,
                    # Soft path: regular notification payload so the OS
                    # shows it on the lock screen.  No full-screen intent.
                    notification=messaging.Notification(title=title, body=body),
                    data=data,
                    android=messaging.AndroidConfig(priority="normal"),
                )
            )
            sent_token_refs.append((row.id, row.token))

        if not messages:
            return

        try:
            response = messaging.send_each(messages)
        except Exception as exc:  # noqa: BLE001
            logger.exception("FCM fall follow-up concern send failed: %s", exc)
            return

        cls._invalidate_stale_tokens(db, response, sent_token_refs)
        logger.info(
            "FCM fall follow-up concern push sent: success=%s failure=%s fall_event_id=%s patient_user_id=%s",
            response.success_count,
            response.failure_count,
            fall_event_id,
            patient_user_id,
        )
