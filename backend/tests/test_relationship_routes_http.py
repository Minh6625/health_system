from __future__ import annotations

from contextlib import contextmanager
import socket
import threading
import time
from types import SimpleNamespace

import httpx
from fastapi import FastAPI
import uvicorn

from fastapi import HTTPException

from app.api.routes.relationships import router as relationships_router
from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.schemas.relationship import (
    LinkedContactDetailResponse,
    LinkedContactMedicalInfoResponse,
)
from app.services.relationship_service import RelationshipService


def _build_test_app(*, user_id: int = 7) -> FastAPI:
    app = FastAPI()
    app.include_router(relationships_router, prefix="/api/v1/mobile")

    def _override_current_user():
        return SimpleNamespace(
            id=user_id,
            full_name=f"User {user_id}",
            avatar_url=None,
            role="user",
            is_active=True,
        )

    def _override_db():
        yield object()

    app.dependency_overrides[get_current_user] = _override_current_user
    app.dependency_overrides[get_db] = _override_db
    return app


def _free_port() -> int:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


@contextmanager
def _serve_test_app(*, user_id: int = 7):
    # TestClient hangs in this Linux worktree, so route contracts run over loopback HTTP instead.
    app = _build_test_app(user_id=user_id)
    port = _free_port()
    server = uvicorn.Server(
        uvicorn.Config(
            app,
            host="127.0.0.1",
            port=port,
            lifespan="off",
            log_level="error",
        )
    )
    thread = threading.Thread(target=server.run, daemon=True)
    thread.start()

    base_url = f"http://127.0.0.1:{port}"
    last_error: Exception | None = None

    with httpx.Client(base_url=base_url, timeout=2.0) as client:
        deadline = time.time() + 5
        while time.time() < deadline:
            try:
                if client.get("/openapi.json").status_code == 200:
                    break
            except httpx.HTTPError as exc:
                last_error = exc
                time.sleep(0.05)
                continue
            time.sleep(0.05)
        else:
            raise AssertionError(f"Test server did not start: {last_error!r}")

        try:
            yield client
        finally:
            server.should_exit = True
            thread.join(timeout=5)
            assert not thread.is_alive(), "Test server did not stop"


def _route(path: str, method: str):
    for route in relationships_router.routes:
        if getattr(route, "path", "") == path and method in getattr(route, "methods", set()):
            return route
    raise AssertionError(f"Route {method} {path} was not registered")


def test_detail_route_declares_typed_response_model(monkeypatch) -> None:
    route = _route("/relationships/{contact_id}/detail", "GET")
    expected_detail = {
        "id": "77",
        "displayName": "Target User",
        "email": "target@example.com",
        "avatarUrl": "",
        "primaryRelationshipLabel": "Mẹ",
        "tags": [{"id": "family", "name": "Gia đình"}],
        "role": "patient",
        "status": "accepted",
        "permissions": ["view_vitals", "receive_alerts"],
        "isIncomingRequest": False,
    }

    monkeypatch.setattr(
        RelationshipService,
        "get_linked_contact_detail",
        staticmethod(lambda db, current_user, contact_id: expected_detail),
    )

    with _serve_test_app(user_id=42) as client:
        response = client.get("/api/v1/mobile/relationships/77/detail")

    assert route.response_model is LinkedContactDetailResponse
    assert response.status_code == 200
    assert response.json() == expected_detail


def test_get_access_profiles_passes_current_user(monkeypatch) -> None:
    captured: dict[str, int] = {}

    def _get_access_profiles(db, current_user):
        captured["user_id"] = current_user.id
        return []

    monkeypatch.setattr(
        RelationshipService,
        "get_access_profiles",
        staticmethod(_get_access_profiles),
    )

    with _serve_test_app(user_id=42) as client:
        response = client.get("/api/v1/mobile/access-profiles")

    assert response.status_code == 200
    assert response.json() == []
    assert captured == {"user_id": 42}


def test_request_relationship_passes_payload(monkeypatch) -> None:
    route = _route("/relationships/request", "POST")
    captured: dict[str, object] = {}
    expected_tags = [{"id": "family", "name": "Gia đình"}]
    expected_response = {
        "id": 91,
        "patient_id": 7,
        "patient_name": "Target User",
        "patient_email": "target@example.com",
        "caregiver_id": 18,
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
            lambda db, user_id: [expected_response]
        ),
    )

    with _serve_test_app(user_id=18) as client:
        response = client.post(
            "/api/v1/mobile/relationships/request",
            json={
                "target_user_id": 7,
                "relationship_type": "family",
                "primary_relationship_label": "Mẹ",
                "tags": expected_tags,
            },
        )

    assert route.status_code == 201
    assert response.status_code == 201
    assert response.json()["id"] == 91
    assert response.json()["relationship_type"] == "family"
    assert response.json()["primary_relationship_label"] == "Mẹ"
    assert response.json()["tags"] == expected_tags
    assert response.json()["created_at"].startswith("2026-04-23T00:00:00")
    assert captured == {
        "user_id": 18,
        "target_user_id": 7,
        "relationship_type": "family",
        "primary_relationship_label": "Mẹ",
        "tags": expected_tags,
    }


def test_medical_info_route_returns_payload_when_permission_granted(monkeypatch) -> None:
    """P-4: happy path — service returns the payload, route serialises it
    via ``LinkedContactMedicalInfoResponse``. We hardcode the expected dict
    so a future schema field rename is caught here, not silently dropped."""

    route = _route("/relationships/{contact_id}/medical-info", "GET")
    expected = {
        "contact_id": 77,
        "display_name": "Bà Mẹ",
        "blood_type": "O+",
        "height_cm": 158,
        "weight_kg": 52.5,
        "medications": ["Metformin 500mg", "Losartan 50mg"],
        "allergies": ["Penicillin"],
        "medical_conditions": ["hypertension", "diabetes"],
    }

    captured: dict[str, object] = {}

    def _service(db, current_user, contact_id):
        captured["user_id"] = current_user.id
        captured["contact_id"] = contact_id
        return expected

    monkeypatch.setattr(
        RelationshipService,
        "get_linked_contact_medical_info",
        staticmethod(_service),
    )

    with _serve_test_app(user_id=42) as client:
        response = client.get("/api/v1/mobile/relationships/77/medical-info")

    assert route.response_model is LinkedContactMedicalInfoResponse
    assert response.status_code == 200
    assert response.json() == expected
    assert captured == {"user_id": 42, "contact_id": 77}


def test_medical_info_route_returns_403_when_permission_denied(monkeypatch) -> None:
    """P-4: when the patient has not granted ``can_view_medical_info`` to
    the requester the service raises 403; the route must propagate that
    intact (not 500). Frontend relies on the 403 to show the 'permission
    not granted' empty state."""

    def _service(db, current_user, contact_id):
        raise HTTPException(
            status_code=403,
            detail="Người này chưa cho phép bạn xem hồ sơ y tế.",
        )

    monkeypatch.setattr(
        RelationshipService,
        "get_linked_contact_medical_info",
        staticmethod(_service),
    )

    with _serve_test_app(user_id=42) as client:
        response = client.get("/api/v1/mobile/relationships/77/medical-info")

    assert response.status_code == 403
    body = response.json()
    assert "chưa cho phép" in body["detail"]


def test_medical_info_route_returns_404_when_no_relationship(monkeypatch) -> None:
    """P-4: 404 path — caller passed a contact_id they have no link to."""

    def _service(db, current_user, contact_id):
        raise HTTPException(
            status_code=404,
            detail="Không tìm thấy dữ liệu liên hệ này",
        )

    monkeypatch.setattr(
        RelationshipService,
        "get_linked_contact_medical_info",
        staticmethod(_service),
    )

    with _serve_test_app(user_id=42) as client:
        response = client.get("/api/v1/mobile/relationships/999/medical-info")

    assert response.status_code == 404
    assert "Không tìm thấy" in response.json()["detail"]


def test_delete_relationship_returns_204(monkeypatch) -> None:
    route = _route("/relationships/{relationship_id}", "DELETE")
    captured: dict[str, int] = {}

    def _delete_relationship(db, current_user, relationship_id: int) -> None:
        captured["user_id"] = current_user.id
        captured["relationship_id"] = relationship_id

    monkeypatch.setattr(
        RelationshipService,
        "delete_relationship",
        staticmethod(_delete_relationship),
    )

    with _serve_test_app(user_id=9) as client:
        response = client.delete("/api/v1/mobile/relationships/77")

    assert route.status_code == 204
    assert response.status_code == 204
    assert response.content == b""
    assert captured == {"user_id": 9, "relationship_id": 77}
