from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import and_, case, func, select
from sqlalchemy.orm import Session

from app.core.alert_constants import (
    RISK_ALERT_COOLDOWN_SECONDS,
    RISK_ALERT_TYPES,
    EscalationRule,
)
from app.models.notification_read_model import NotificationRead
from app.models.push_token_model import UserPushToken
from app.models.risk_alert_response_model import RiskAlertResponse
from app.models.sos_event_model import Alert
from app.schemas.notification import NotificationItem
from app.utils.datetime_helper import get_current_time

logger = logging.getLogger(__name__)


class NotificationService:
    @staticmethod
    def _token_prefix(token: str) -> str:
        normalized = (token or "").strip()
        if not normalized:
            return ""
        return normalized[:24]

    @staticmethod
    def list_notifications(
        db: Session,
        user_id: int,
        *,
        limit: int = 20,
        offset: int = 0,
        unread_only: bool = False,
    ) -> tuple[list[NotificationItem], int, int]:
        base_query = (
            db.query(Alert, NotificationRead.read_at.label("read_at"))
            .outerjoin(
                NotificationRead,
                and_(
                    NotificationRead.alert_id == Alert.id,
                    NotificationRead.user_id == user_id,
                ),
            )
            .filter(Alert.user_id == user_id)
        )

        if unread_only:
            base_query = base_query.filter(NotificationRead.read_at.is_(None))

        total_count = base_query.count()

        rows = (
            base_query.order_by(
                case((NotificationRead.read_at.is_(None), 0), else_=1).asc(),
                Alert.created_at.desc(),
            )
            .limit(limit)
            .offset(offset)
            .all()
        )

        # When unread_only=True the base_query already filters to unread rows,
        # so total_count == unread_count — no second query needed.
        if unread_only:
            unread_count = total_count
        else:
            unread_count = (
                db.query(func.count(Alert.id))
                .outerjoin(
                    NotificationRead,
                    and_(
                        NotificationRead.alert_id == Alert.id,
                        NotificationRead.user_id == user_id,
                    ),
                )
                .filter(
                    Alert.user_id == user_id,
                    NotificationRead.read_at.is_(None),
                )
                .scalar()
                or 0
            )

        items = [
            NotificationItem(
                id=alert.id,
                alert_type=alert.alert_type,
                severity=alert.severity,
                title=alert.title,
                message=alert.message,
                data=alert.details,
                created_at=alert.created_at,
                is_read=read_at is not None,
                read_at=read_at,
            )
            for alert, read_at in rows
        ]

        return items, total_count, int(unread_count)

    @staticmethod
    def get_notification_detail(
        db: Session,
        user_id: int,
        notification_id: int,
    ) -> NotificationItem | None:
        row = (
            db.query(Alert, NotificationRead.read_at.label("read_at"))
            .outerjoin(
                NotificationRead,
                and_(
                    NotificationRead.alert_id == Alert.id,
                    NotificationRead.user_id == user_id,
                ),
            )
            .filter(
                Alert.id == notification_id,
                Alert.user_id == user_id,
            )
            .first()
        )

        if row is None:
            return None

        alert, read_at = row
        return NotificationItem(
            id=alert.id,
            alert_type=alert.alert_type,
            severity=alert.severity,
            title=alert.title,
            message=alert.message,
            data=alert.details,
            created_at=alert.created_at,
            is_read=read_at is not None,
            read_at=read_at,
        )

    @staticmethod
    def mark_notification_as_read(
        db: Session,
        user_id: int,
        notification_id: int,
    ) -> datetime | None:
        alert = (
            db.query(Alert)
            .filter(
                Alert.id == notification_id,
                Alert.user_id == user_id,
            )
            .first()
        )
        if alert is None:
            return None

        existing = (
            db.query(NotificationRead)
            .filter(
                NotificationRead.user_id == user_id,
                NotificationRead.alert_id == notification_id,
            )
            .first()
        )

        if existing is None:
            existing = NotificationRead(
                user_id=user_id,
                alert_id=notification_id,
                read_at=get_current_time(),
            )
            db.add(existing)
        elif existing.read_at is None:
            existing.read_at = get_current_time()

        db.commit()
        db.refresh(existing)
        return existing.read_at

    # -----------------------------------------------------------------
    # Risk alert cooldown check  (A5 — GAP-5 fix)
    # -----------------------------------------------------------------

    @staticmethod
    def is_risk_alert_in_cooldown(
        db: Session,
        *,
        device_id: int,
        alert_type: str,
    ) -> bool:
        """Check whether a risk alert family for *device_id* is in cooldown.

        Phase 8 (2026-05-20): cooldown gate now operates at the **risk
        alert family** level (``RISK_ALERT_TYPES`` = {risk_high,
        risk_critical}) instead of one window per ``alert_type``.

        Trước fix: mỗi ``alert_type`` có cooldown 5 phút riêng. Khi vitals
        dao động quanh ``health_thresholds.critical_at`` (0.65), một mẫu
        nhảy qua nhảy lại giữa medium/critical → backend bắn push xen kẽ
        2 type vì cooldown của type kia chưa active. Hệ quả: user nhận
        FCM warning + critical liên tục cách nhau vài chục giây.

        Quy tắc mới:
        - Trong cửa sổ cooldown, **bất kỳ** risk_* alert chưa ack đều
          coi là active.
        - Cho phép escalate UP: lần trước là ``risk_high`` mà lần này
          là ``risk_critical`` thì pass cooldown (escalation thực sự).
        - Mọi trường hợp khác (cùng type, hoặc downgrade
          ``risk_critical → risk_high``) đều bị block.

        Issue 2b vẫn được giữ: alert đã ack ``response_action='safe'``
        không tính vào cooldown. Phần B2 (group-ack) mở rộng quy tắc này
        để 1 patient ack release cho cả nhóm caregiver.
        """
        cutoff = datetime.now(timezone.utc) - timedelta(
            seconds=RISK_ALERT_COOLDOWN_SECONDS,
        )

        # Select alert ids that the user already marked safe — these
        # are excluded from the cooldown count so a fresh test inject
        # (or real follow-up event) fires its own push instead of
        # being dedup-suppressed against an already-acknowledged
        # alert.  Using ``select(...)`` explicitly avoids the SQLA 2.x
        # deprecation warning around bare Subquery objects in ``in_()``.
        acknowledged_alert_ids = select(RiskAlertResponse.notification_id).where(
            RiskAlertResponse.response_action == "safe"
        )

        # Family gate: lấy alert_type của cảnh báo gần nhất trong cửa sổ
        # cooldown thuộc cùng family (đã loại trừ alert đã ack).
        recent_family = (
            db.query(Alert.alert_type)
            .filter(
                Alert.device_id == device_id,
                Alert.alert_type.in_(RISK_ALERT_TYPES),
                Alert.created_at >= cutoff,
                ~Alert.id.in_(acknowledged_alert_ids),
            )
            .order_by(Alert.created_at.desc())
            .limit(1)
            .first()
        )

        if recent_family is None:
            return False

        last_type = recent_family[0]
        # Escalate UP từ medium → critical luôn pass cooldown
        # (đây là tình huống xấu đi cần thông báo lại ngay).
        if last_type == "risk_high" and alert_type == "risk_critical":
            return False

        logger.info(
            "Risk alert cooldown active: device=%d, type=%s, last_in_family=%s, window=%ds",
            device_id,
            alert_type,
            last_type,
            RISK_ALERT_COOLDOWN_SECONDS,
        )
        return True

    # -----------------------------------------------------------------
    # Risk alert creation  (A1 — GAP-6 fix)
    # -----------------------------------------------------------------

    @staticmethod
    def create_risk_alerts(
        db: Session,
        *,
        device_id: int,
        recipient_user_ids: list[int],
        rule: EscalationRule,
        risk_score: float,
        risk_score_id: int | None = None,
        details: dict[str, Any] | None = None,
    ) -> dict[int, int]:
        """Create one Alert row per recipient for a risk event.

        Follows the same fan-out pattern used by SOS alerts in
        ``EmergencyService``: one ``Alert`` per recipient so each user
        gets their own notification entry.

        Parameters
        ----------
        db:
            Active SQLAlchemy session (caller manages commit).
        device_id:
            The ``devices.id`` that triggered the risk score.
        recipient_user_ids:
            User IDs that should receive the alert (patient + caregivers).
        rule:
            ``EscalationRule`` from ``alert_constants`` — carries
            ``alert_type``, ``severity``, title/message templates.
        risk_score:
            Numeric risk score for template interpolation.
        risk_score_id:
            Optional FK to ``risk_scores.id`` for traceability.

        Returns
        -------
        dict[int, int]
            Mapping of ``user_id`` -> ``alert.id`` (needed by FCM push).
        """
        if not recipient_user_ids:
            return {}

        title = rule.title_template
        message = rule.message_template.format(score=risk_score)
        alert_details: dict[str, Any] = {
            "risk_score": risk_score,
            "risk_level": rule.risk_level,
        }
        if risk_score_id is not None:
            alert_details["risk_score_id"] = risk_score_id
        if details is not None:
            alert_details.update(details)

        alert_by_uid: list[tuple[int, Alert]] = []
        for uid in recipient_user_ids:
            alert = Alert(
                device_id=device_id,
                user_id=uid,
                alert_type=rule.alert_type,
                severity=rule.severity,
                title=title,
                message=message,
                details=alert_details,
            )
            db.add(alert)
            alert_by_uid.append((uid, alert))

        db.flush()  # single flush — all ids populated at once
        notification_id_by_user: dict[int, int] = {
            uid: alert.id for uid, alert in alert_by_uid
        }
        db.commit()
        logger.info(
            "Created %d risk alerts (type=%s, device=%d, score=%.1f)",
            len(notification_id_by_user),
            rule.alert_type,
            device_id,
            risk_score,
        )
        return notification_id_by_user

    # -----------------------------------------------------------------
    # Push token management
    # -----------------------------------------------------------------

    @staticmethod
    def upsert_push_token(
        db: Session,
        user_id: int,
        token: str,
        platform: str,
        device_id: str | None = None,
    ) -> None:
        existing = db.query(UserPushToken).filter(UserPushToken.token == token).first()
        token_prefix = NotificationService._token_prefix(token)

        if existing is None:
            db.add(
                UserPushToken(
                    user_id=user_id,
                    token=token,
                    platform=platform,
                    device_id=device_id,
                    is_active=True,
                    last_seen_at=get_current_time(),
                )
            )
            logger.info(
                "Push token registered: user=%s platform=%s device_id=%s token_prefix=%s status=new",
                user_id,
                platform,
                device_id,
                token_prefix,
            )
        else:
            existing.user_id = user_id
            existing.platform = platform
            existing.device_id = device_id
            existing.is_active = True
            existing.last_seen_at = get_current_time()
            logger.info(
                "Push token registered: user=%s platform=%s device_id=%s token_prefix=%s status=updated",
                user_id,
                platform,
                device_id,
                token_prefix,
            )

        db.commit()

    @staticmethod
    def unregister_push_token(
        db: Session,
        user_id: int,
        token: str,
    ) -> int:
        affected = (
            db.query(UserPushToken)
            .filter(
                UserPushToken.user_id == user_id,
                UserPushToken.token == token,
                UserPushToken.is_active.is_(True),
            )
            .update(
                {
                    "is_active": False,
                    "last_seen_at": get_current_time(),
                },
                synchronize_session=False,
            )
        )

        db.commit()
        return int(affected)

    @staticmethod
    def unregister_push_token_any_user(
        db: Session,
        token: str,
    ) -> int:
        token_prefix = NotificationService._token_prefix(token)
        affected = (
            db.query(UserPushToken)
            .filter(
                UserPushToken.token == token,
                UserPushToken.is_active.is_(True),
            )
            .update(
                {
                    "is_active": False,
                    "last_seen_at": get_current_time(),
                },
                synchronize_session=False,
            )
        )

        db.commit()
        logger.info(
            "Push token unregistered: affected=%s token_prefix=%s scope=any-user",
            int(affected),
            token_prefix,
        )
        return int(affected)
