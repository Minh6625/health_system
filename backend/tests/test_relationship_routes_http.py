from __future__ import annotations

from types import SimpleNamespace

from app.api.routes.relationships import (
    delete_relationship,
    get_access_profiles,
    request_relationship,
    router as relationships_router,
)
from app.schemas.relationship import (
    LinkedContactDetailResponse,
    RelationshipRequestCreate,
)
from app.services.relationship_service import RelationshipService


def _route(path: str, method: str):
    return next(
        route
        for route in relationships_router.routes
        if getattr(route, "path", "") == path and method in getattr(route, "methods", set())
    )


def test_detail_route_declares_typed_response_model() -> None:
    route = _route("/relationships/{contact_id}/detail", "GET")
    assert route.response_model is LinkedContactDetailResponse


def test_get_access_profiles_passes_current_user(monkeypatch) -> None:
    route = _route("/access-profiles", "GET")
    current_user = SimpleNamespace(
        id=42,
        full_name="Requester",
        avatar_url=None,
        role="user",
        is_active=True,
    )
    captured: dict[str, int] = {}

    def _get_access_profiles(db, current_user):
        captured["user_id"] = current_user.id
        return []

    monkeypatch.setattr(
        RelationshipService,
        "get_access_profiles",
        staticmethod(_get_access_profiles),
    )

    response = get_access_profiles(current_user=current_user, db=object())

    assert route.path == "/access-profiles"
    assert response == []
    assert captured == {"user_id": 42}


def test_request_relationship_passes_payload(monkeypatch) -> None:
    route = _route("/relationships/request", "POST")
    current_user = SimpleNamespace(id=18, role="user", is_active=True)
    captured: dict[str, object] = {}
    expected_tags = [{"id": "family", "name": "Gia đình"}]

    def _request_relationship(db, current_user, payload):
        captured["user_id"] = current_user.id
        captured["target_user_id"] = payload.target_user_id
        captured["relationship_type"] = payload.relationship_type
        captured["primary_relationship_label"] = payload.primary_relationship_label
        captured["tags"] = payload.tags
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
                    "tags": expected_tags,
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

    response = request_relationship(
        payload=RelationshipRequestCreate(
            target_user_id=7,
            relationship_type="family",
            primary_relationship_label="Mẹ",
            tags=expected_tags,
        ),
        current_user=current_user,
        db=object(),
    )

    assert route.status_code == 201
    assert response["id"] == 91
    assert captured == {
        "user_id": 18,
        "target_user_id": 7,
        "relationship_type": "family",
        "primary_relationship_label": "Mẹ",
        "tags": expected_tags,
    }


def test_delete_relationship_returns_204(monkeypatch) -> None:
    route = _route("/relationships/{relationship_id}", "DELETE")
    current_user = SimpleNamespace(id=9, role="user", is_active=True)
    captured: dict[str, int] = {}

    def _delete_relationship(db, current_user, relationship_id: int) -> None:
        captured["user_id"] = current_user.id
        captured["relationship_id"] = relationship_id

    monkeypatch.setattr(
        RelationshipService,
        "delete_relationship",
        staticmethod(_delete_relationship),
    )

    response = delete_relationship(
        relationship_id=77,
        current_user=current_user,
        db=object(),
    )

    assert route.status_code == 204
    assert response is None
    assert captured == {"user_id": 9, "relationship_id": 77}
