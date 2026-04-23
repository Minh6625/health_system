from __future__ import annotations

from types import SimpleNamespace

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.routes.relationships import router as relationships_router
from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.schemas.relationship import LinkedContactDetailResponse
from app.services.relationship_service import RelationshipService


def _build_test_client(*, user_id: int = 7) -> TestClient:
    app = FastAPI()
    app.include_router(relationships_router, prefix="/mobile")

    def _override_current_user():
        return SimpleNamespace(id=user_id, role="user", is_active=True)

    def _override_db():
        yield object()

    app.dependency_overrides[get_current_user] = _override_current_user
    app.dependency_overrides[get_db] = _override_db
    return TestClient(app)


def test_detail_route_declares_typed_response_model() -> None:
    route = next(
        route
        for route in relationships_router.routes
        if getattr(route, "path", "") == "/relationships/{contact_id}/detail"
    )
    assert route.response_model is LinkedContactDetailResponse


def test_get_access_profiles_passes_current_user(monkeypatch) -> None:
    client = _build_test_client(user_id=42)
    captured: dict[str, int] = {}

    def _get_access_profiles(db, current_user):
        captured["user_id"] = current_user.id
        return []

    monkeypatch.setattr(
        RelationshipService,
        "get_access_profiles",
        staticmethod(_get_access_profiles),
    )

    response = client.get("/mobile/access-profiles")

    assert response.status_code == 200
    assert response.json() == []
    assert captured == {"user_id": 42}


def test_request_relationship_passes_payload(monkeypatch) -> None:
    client = _build_test_client(user_id=18)
    captured: dict[str, object] = {}

    def _request_relationship(db, current_user, payload):
        captured["user_id"] = current_user.id
        captured["target_user_id"] = payload.target_user_id
        return object()

    monkeypatch.setattr(
        RelationshipService,
        "request_relationship",
        staticmethod(_request_relationship),
    )
    monkeypatch.setattr(
        RelationshipService,
        "format_relationships",
        staticmethod(
            lambda db, user_id: [
                {
                    "id": 91,
                    "patient_id": 7,
                    "patient_name": "Target User",
                    "patient_email": "target@example.com",
                    "caregiver_id": user_id,
                    "caregiver_name": "Requester",
                    "caregiver_email": "requester@example.com",
                    "relationship_type": "family",
                    "status": "pending",
                    "primary_relationship_label": "Mẹ",
                    "tags": [{"id": "family", "name": "Gia đình"}],
                    "can_view_vitals": False,
                    "can_receive_alerts": False,
                    "can_view_location": False,
                    "has_view_vitals_permission": False,
                    "has_receive_alerts_permission": False,
                    "has_view_location_permission": False,
                    "created_at": "2026-04-23T00:00:00Z",
                }
            ]
        ),
    )

    response = client.post(
        "/mobile/relationships/request",
        json={
            "target_user_id": 7,
            "relationship_type": "family",
            "primary_relationship_label": "Mẹ",
            "tags": [{"id": "family", "name": "Gia đình"}],
        },
    )

    assert response.status_code == 201
    assert response.json()["id"] == 91
    assert captured == {"user_id": 18, "target_user_id": 7}


def test_delete_relationship_returns_204(monkeypatch) -> None:
    client = _build_test_client(user_id=9)
    captured: dict[str, int] = {}

    def _delete_relationship(db, current_user, relationship_id: int) -> None:
        captured["user_id"] = current_user.id
        captured["relationship_id"] = relationship_id

    monkeypatch.setattr(
        RelationshipService,
        "delete_relationship",
        staticmethod(_delete_relationship),
    )

    response = client.delete("/mobile/relationships/77")

    assert response.status_code == 204
    assert captured == {"user_id": 9, "relationship_id": 77}
