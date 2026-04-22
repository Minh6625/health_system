from __future__ import annotations

from datetime import UTC, datetime
from types import SimpleNamespace

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.routes.notifications import router as notifications_router
from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.schemas.notification import NotificationItem
from app.services.notification_service import NotificationService


def _build_test_client(*, user_id: int = 7) -> TestClient:
    app = FastAPI()
    app.include_router(notifications_router, prefix="/mobile")

    def _override_current_user():
        return SimpleNamespace(id=user_id, role="user", is_active=True)

    def _override_db():
        yield object()

    app.dependency_overrides[get_current_user] = _override_current_user
    app.dependency_overrides[get_db] = _override_db
    return TestClient(app)


def _item(notification_id: int, *, is_read: bool = False) -> NotificationItem:
    return NotificationItem(
        id=notification_id,
        alert_type="risk_high",
        severity="high",
        title="Risk warning",
        message="Check vitals now",
        data={"risk_level": "medium", "risk_score_id": 901},
        created_at=datetime(2026, 4, 22, 0, 0, tzinfo=UTC),
        is_read=is_read,
        read_at=datetime(2026, 4, 22, 0, 1, tzinfo=UTC) if is_read else None,
    )


def test_get_notifications_passes_query_params_and_current_user(
    monkeypatch,
) -> None:
    client = _build_test_client(user_id=42)
    captured: dict[str, object] = {}

    def _list_notifications(
        db,
        user_id: int,
        *,
        limit: int,
        offset: int,
        unread_only: bool,
    ):
        captured.update(
            {
                "user_id": user_id,
                "limit": limit,
                "offset": offset,
                "unread_only": unread_only,
            }
        )
        return ([_item(91)], 1, 1)

    monkeypatch.setattr(
        NotificationService,
        "list_notifications",
        staticmethod(_list_notifications),
    )

    response = client.get("/mobile/notifications?limit=10&offset=20&unread_only=true")

    assert response.status_code == 200
    assert response.json()["unread_count"] == 1
    assert captured == {
        "user_id": 42,
        "limit": 10,
        "offset": 20,
        "unread_only": True,
    }


def test_get_notification_detail_returns_404_when_missing(monkeypatch) -> None:
    client = _build_test_client()
    monkeypatch.setattr(
        NotificationService,
        "get_notification_detail",
        staticmethod(lambda db, user_id, notification_id: None),
    )

    response = client.get("/mobile/notifications/91")

    assert response.status_code == 404
    assert response.json()["detail"] == "Notification not found"


def test_get_notification_detail_returns_notification_payload(
    monkeypatch,
) -> None:
    client = _build_test_client(user_id=18)
    captured: dict[str, object] = {}

    def _get_notification_detail(db, user_id: int, notification_id: int):
        captured.update(
            {
                "user_id": user_id,
                "notification_id": notification_id,
            }
        )
        return _item(91, is_read=True)

    monkeypatch.setattr(
        NotificationService,
        "get_notification_detail",
        staticmethod(_get_notification_detail),
    )

    response = client.get("/mobile/notifications/91")

    assert response.status_code == 200
    assert response.json()["id"] == 91
    assert response.json()["is_read"] is True
    assert response.json()["read_at"].startswith("2026-04-22T00:01:00")
    assert captured == {
        "user_id": 18,
        "notification_id": 91,
    }


def test_mark_notification_as_read_returns_read_at(monkeypatch) -> None:
    client = _build_test_client(user_id=99)
    captured: dict[str, object] = {}

    def _mark_notification_as_read(db, user_id: int, notification_id: int):
        captured.update(
            {
                "user_id": user_id,
                "notification_id": notification_id,
            }
        )
        return datetime(2026, 4, 22, 0, 1, tzinfo=UTC)

    monkeypatch.setattr(
        NotificationService,
        "mark_notification_as_read",
        staticmethod(_mark_notification_as_read),
    )

    response = client.put("/mobile/notifications/91/read", json={})

    assert response.status_code == 200
    assert response.json()["notification_id"] == 91
    assert response.json()["success"] is True
    assert response.json()["read_at"].startswith("2026-04-22T00:01:00")
    assert captured == {
        "user_id": 99,
        "notification_id": 91,
    }


def test_upsert_push_token_uses_current_user(monkeypatch) -> None:
    client = _build_test_client(user_id=77)
    captured: dict[str, object] = {}

    def _upsert_push_token(
        db,
        user_id: int,
        *,
        token: str,
        platform: str,
        device_id: str | None,
    ):
        captured.update(
            {
                "user_id": user_id,
                "token": token,
                "platform": platform,
                "device_id": device_id,
            }
        )

    monkeypatch.setattr(
        NotificationService,
        "upsert_push_token",
        staticmethod(_upsert_push_token),
    )

    response = client.post(
        "/mobile/notifications/push-token",
        json={
            "token": "a" * 32,
            "platform": "android",
            "device_id": "device-1",
        },
    )

    assert response.status_code == 200
    assert captured["user_id"] == 77
    assert captured["platform"] == "android"


def test_unregister_push_token_does_not_require_current_user(monkeypatch) -> None:
    app = FastAPI()
    app.include_router(notifications_router, prefix="/mobile")

    def _override_db():
        yield object()

    app.dependency_overrides[get_db] = _override_db
    client = TestClient(app)
    captured: dict[str, object] = {}

    def _unregister_push_token_any_user(db, *, token: str):
        captured["token"] = token

    monkeypatch.setattr(
        NotificationService,
        "unregister_push_token_any_user",
        staticmethod(_unregister_push_token_any_user),
    )

    response = client.post(
        "/mobile/notifications/push-token/unregister",
        json={"token": "b" * 32},
    )

    assert response.status_code == 200
    assert captured == {"token": "b" * 32}
