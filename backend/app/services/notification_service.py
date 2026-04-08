from __future__ import annotations

from datetime import datetime

from sqlalchemy import and_, case, func
from sqlalchemy.orm import Session

from app.models.notification_read_model import NotificationRead
from app.models.push_token_model import UserPushToken
from app.models.sos_event_model import Alert
from app.schemas.notification import NotificationItem
from app.utils.datetime_helper import get_current_time
from app.utils.datetime_helper import get_current_time


class NotificationService:
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

    @staticmethod
    def upsert_push_token(
        db: Session,
        user_id: int,
        token: str,
        platform: str,
        device_id: str | None = None,
    ) -> None:
        existing = db.query(UserPushToken).filter(UserPushToken.token == token).first()

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
        else:
            existing.user_id = user_id
            existing.platform = platform
            existing.device_id = device_id
            existing.is_active = True
            existing.last_seen_at = get_current_time()

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
        return int(affected)
