from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import and_, case, func
from sqlalchemy.orm import Session

from app.core.alert_constants import RISK_ALERT_COOLDOWN_SECONDS, EscalationRule
from app.models.notification_read_model import NotificationRead
from app.models.push_token_model import UserPushToken
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
        """Check whether a risk alert of *alert_type* for *device_id* was
        created within the cooldown window.

        Uses ``RISK_ALERT_COOLDOWN_SECONDS`` from ``alert_constants``.
        Returns ``True`` if a recent alert exists (i.e. should NOT send
        another one yet).
        """
        cutoff = datetime.now(timezone.utc) - timedelta(
            seconds=RISK_ALERT_COOLDOWN_SECONDS,
        )

        recent = (
            db.query(Alert.id)
            .filter(
                Alert.device_id == device_id,
                Alert.alert_type == alert_type,
                Alert.created_at >= cutoff,
            )
            .limit(1)
            .first()
        )

        if recent is not None:
            logger.info(
                "Risk alert cooldown active: device=%d, type=%s, window=%ds",
                device_id,
                alert_type,
                RISK_ALERT_COOLDOWN_SECONDS,
            )

        return recent is not None

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

        notification_id_by_user: dict[int, int] = {}

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
            db.flush()  # populate alert.id
            notification_id_by_user[uid] = alert.id

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
