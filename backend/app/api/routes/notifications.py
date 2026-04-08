import asyncio
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.db.database import SessionLocal, get_db
from app.models.user_model import User
from app.repositories.user_repository import UserRepository
from app.schemas.notification import (
    NotificationItem,
    NotificationListResponse,
    PushTokenResponse,
    PushTokenUnregisterRequest,
    PushTokenUpsertRequest,
    NotificationReadResponse,
)
from app.services.notification_service import NotificationService
from app.utils.jwt import decode_token

router = APIRouter(tags=["mobile-notifications"])


@router.get("/notifications", response_model=NotificationListResponse)
def get_notifications(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    unread_only: bool = Query(default=False),
) -> NotificationListResponse:
    notifications, total_count, unread_count = NotificationService.list_notifications(
        db,
        current_user.id,
        limit=limit,
        offset=offset,
        unread_only=unread_only,
    )
    return NotificationListResponse(
        notifications=notifications,
        total_count=total_count,
        unread_count=unread_count,
        limit=limit,
        offset=offset,
    )


@router.get("/notifications/{notification_id}", response_model=NotificationItem)
def get_notification_detail(
    notification_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> NotificationItem:
    notification = NotificationService.get_notification_detail(
        db,
        current_user.id,
        notification_id,
    )
    if notification is None:
        raise HTTPException(status_code=404, detail="Notification not found")
    return notification


@router.put("/notifications/{notification_id}/read", response_model=NotificationReadResponse)
def mark_notification_as_read(
    notification_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> NotificationReadResponse:
    read_at = NotificationService.mark_notification_as_read(
        db,
        current_user.id,
        notification_id,
    )
    if read_at is None:
        raise HTTPException(status_code=404, detail="Notification not found")
    return NotificationReadResponse(
        success=True,
        message="Notification marked as read",
        notification_id=notification_id,
        read_at=read_at,
    )


@router.post("/notifications/push-token", response_model=PushTokenResponse)
def upsert_push_token(
    payload: PushTokenUpsertRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> PushTokenResponse:
    NotificationService.upsert_push_token(
        db,
        current_user.id,
        token=payload.token,
        platform=payload.platform,
        device_id=payload.device_id,
    )
    return PushTokenResponse(
        success=True,
        message="Push token registered",
    )


@router.post("/notifications/push-token/unregister", response_model=PushTokenResponse)
def unregister_push_token(
    payload: PushTokenUnregisterRequest,
    db: Session = Depends(get_db),
) -> PushTokenResponse:
    NotificationService.unregister_push_token_any_user(
        db,
        token=payload.token,
    )
    return PushTokenResponse(
        success=True,
        message="Push token unregistered",
    )


@router.websocket("/ws/notifications")
async def stream_notifications(websocket: WebSocket):
    token = websocket.query_params.get("token")

    if token is None:
        auth_header = websocket.headers.get("authorization", "")
        if auth_header.lower().startswith("bearer "):
            token = auth_header[7:].strip()

    payload = decode_token(token or "")
    if not payload or not payload.get("user_id"):
        await websocket.close(code=1008)
        return

    user_id = int(payload["user_id"])

    db = SessionLocal()
    try:
        user = UserRepository.get_by_id(db, user_id)
        if user is None or not user.is_active:
            await websocket.close(code=1008)
            return
    finally:
        db.close()

    await websocket.accept()

    last_signature: tuple[int, int | None, str | None] | None = None

    try:
        while True:
            db = SessionLocal()
            try:
                notifications, _, unread_count = NotificationService.list_notifications(
                    db,
                    user_id,
                    limit=1,
                    offset=0,
                    unread_only=False,
                )
                latest = notifications[0] if notifications else None
                latest_id = latest.id if latest else None
                latest_created = (
                    latest.created_at.isoformat() if latest else None
                )

                signature = (unread_count, latest_id, latest_created)
                if signature != last_signature:
                    payload_json = {
                        "type": "notifications.update",
                        "unread_count": unread_count,
                        "latest_notification": _serialize_notification(latest),
                        "sent_at": datetime.utcnow().isoformat(),
                    }
                    await websocket.send_json(payload_json)
                    last_signature = signature
            finally:
                db.close()

            await asyncio.sleep(5)
    except WebSocketDisconnect:
        return


def _serialize_notification(item: NotificationItem | None) -> dict | None:
    if item is None:
        return None
    return {
        "id": item.id,
        "alert_type": item.alert_type,
        "severity": item.severity,
        "title": item.title,
        "message": item.message,
        "data": item.data,
        "created_at": item.created_at.isoformat(),
        "is_read": item.is_read,
        "read_at": item.read_at.isoformat() if item.read_at else None,
    }
