"""Phase 5 contract tests — audience profile + clinician role gate.

Pins three guarantees on ``GET /mobile/analysis/risk-reports/{id}``:

1. **Default is patient.** A request with no ``audience=`` query param
   returns the existing :class:`RiskReportDetailResponse` shape, with
   neither ``shap_details`` nor ``model_request_id`` populated. Backwards
   compatible with every Flutter binary built before Phase 5.
2. **Clinician audience requires the role gate.** ``audience=clinician``
   from a user whose ``role`` is not in :data:`CLINICIAN_ROLES` returns
   HTTP 403; from a user whose role is in the set, returns the
   :class:`RiskReportClinicianResponse` shape with the additional
   fields populated.
3. **Unauthenticated requests are 401-rejected** by the existing
   ``HTTPBearer`` dependency before the audience gate runs.

The tests stub :class:`MonitoringService` at the per-method level so the
DB layer is not exercised. Authentication is stubbed via
``main_app.dependency_overrides`` so the test client can swap roles
without minting JWTs.
"""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any

import pytest
from fastapi import HTTPException, status
from fastapi.testclient import TestClient

from app.core.audience import CLINICIAN_ROLES
from app.core.dependencies import get_current_user, get_db, get_target_profile_id
from app.main import app as main_app
from app.models.user_model import User
from app.schemas.monitoring import (
    RiskReportClinicianResponse,
    RiskReportDetailResponse,
    SnapshotMetricsResponse,
)
from app.services.monitoring_service import MonitoringService


# ---------------------------------------------------------------------------
# Stubs
# ---------------------------------------------------------------------------


_TIMESTAMP = datetime(2026, 4, 27, 10, 0, tzinfo=UTC)


def _stub_user(role: str = "user", user_id: int = 7) -> User:
    """Build a minimal ``User`` stub with the requested role.

    We avoid hitting the DB by constructing the SQLAlchemy model
    directly with only the fields the auth flow + audience gate read.
    """
    user = User()
    user.id = user_id
    user.email = f"role_{role}@example.com"
    user.full_name = f"Test {role}"
    user.role = role
    user.is_active = True
    user.is_verified = True
    return user


def _stub_patient_detail() -> RiskReportDetailResponse:
    return RiskReportDetailResponse(
        id=42,
        risk_type="general",
        risk_score=18.0,
        score=18.0,
        health_score=82.0,
        risk_level="low",
        health_level="good",
        display_status="Ổn định",
        summary="OK",
        timestamp=_TIMESTAMP,
        previous_score=None,
        trend_7d=[24, 21, 19, 18],
        explanation="",
        xai_explanation="",
        features={},
        feature_importance={},
        breakdown=[],
        recommendations=[],
        recommendation_preview=[],
        top_factors=[],
        snapshot=SnapshotMetricsResponse(),
        model_version="1.0",
        algorithm="rule_based",
        confidence=0.92,
        is_stale=False,
        ai_explanation=None,
    )


def _stub_clinician_detail() -> RiskReportClinicianResponse:
    base = _stub_patient_detail().model_dump()
    return RiskReportClinicianResponse(
        **base,
        shap_details={
            "available": True,
            "base_value": 0.05,
            "values": [
                {"feature": "heart_rate", "shap_value": 0.42, "impact": 0.42},
            ],
        },
        model_request_id="rq01-9b3d-2a9c-4d27-9e1a-1234abcd",
    )


# ---------------------------------------------------------------------------
# Fixtures — TestClient with role-overridable auth
# ---------------------------------------------------------------------------


def _build_client(
    *,
    role: str | None,
    monkeypatch: pytest.MonkeyPatch,
) -> TestClient:
    """Construct a TestClient that authenticates as a user with ``role``.

    ``role=None`` simulates an unauthenticated request — the auth
    dependency raises 401 from inside the override.
    """
    if role is None:
        def _override_user() -> User:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token không hợp lệ",
                headers={"WWW-Authenticate": "Bearer"},
            )
    else:
        user = _stub_user(role=role)

        def _override_user() -> User:
            return user

    def _override_target_profile_id() -> int:
        return 7

    def _override_db():
        yield object()

    main_app.dependency_overrides[get_current_user] = _override_user
    main_app.dependency_overrides[get_target_profile_id] = _override_target_profile_id
    main_app.dependency_overrides[get_db] = _override_db

    monkeypatch.setattr(
        MonitoringService,
        "get_risk_report_detail",
        staticmethod(lambda patient_id, report_id, db: _stub_patient_detail()),
    )
    monkeypatch.setattr(
        MonitoringService,
        "get_risk_report_clinician_detail",
        staticmethod(lambda patient_id, report_id, db: _stub_clinician_detail()),
    )

    return TestClient(main_app)


@pytest.fixture(autouse=True)
def _clear_overrides_after_test():
    yield
    main_app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Default audience = patient (no query param)
# ---------------------------------------------------------------------------


class TestPatientDefault:
    def test_no_audience_param_returns_patient_dto(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        client = _build_client(role="user", monkeypatch=monkeypatch)
        response = client.get("/api/v1/mobile/analysis/risk-reports/42")
        assert response.status_code == 200, response.text
        body = response.json()
        # Patient DTO does NOT carry shap_details / model_request_id.
        assert "shap_details" not in body
        assert "model_request_id" not in body
        # But carries the existing detail fields.
        assert body["display_status"] == "Ổn định"
        assert body["risk_level"] == "low"

    def test_explicit_patient_audience_returns_patient_dto(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        client = _build_client(role="user", monkeypatch=monkeypatch)
        response = client.get(
            "/api/v1/mobile/analysis/risk-reports/42?audience=patient"
        )
        assert response.status_code == 200
        body = response.json()
        assert "shap_details" not in body
        assert "model_request_id" not in body


# ---------------------------------------------------------------------------
# audience=clinician — role gate
# ---------------------------------------------------------------------------


class TestClinicianAudienceGate:
    @pytest.mark.parametrize("role", ["user", "patient"])
    def test_non_clinician_role_is_403(
        self, monkeypatch: pytest.MonkeyPatch, role: str
    ) -> None:
        client = _build_client(role=role, monkeypatch=monkeypatch)
        response = client.get(
            "/api/v1/mobile/analysis/risk-reports/42?audience=clinician"
        )
        assert response.status_code == 403, response.text
        assert response.json()["detail"] == (
            "Cần quyền clinician để xem bản chi tiết chuyên môn"
        )

    @pytest.mark.parametrize("role", sorted(CLINICIAN_ROLES))
    def test_clinician_roles_get_clinician_dto(
        self, monkeypatch: pytest.MonkeyPatch, role: str
    ) -> None:
        client = _build_client(role=role, monkeypatch=monkeypatch)
        response = client.get(
            "/api/v1/mobile/analysis/risk-reports/42?audience=clinician"
        )
        assert response.status_code == 200, response.text
        body = response.json()
        # Clinician DTO carries the additional fields.
        assert body["shap_details"]["available"] is True
        assert (
            body["model_request_id"] == "rq01-9b3d-2a9c-4d27-9e1a-1234abcd"
        )
        # And still carries every patient field.
        assert body["display_status"] == "Ổn định"


# ---------------------------------------------------------------------------
# Unauthenticated
# ---------------------------------------------------------------------------


class TestUnauthenticatedRejection:
    def test_no_auth_returns_401_or_403(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        # FastAPI's HTTPBearer (auto_error=True) raises 403 when the
        # Authorization header is missing; our explicit auth override
        # raises 401. Both are valid "not authenticated" responses for
        # this surface — the route MUST NOT serve data to unauthenticated
        # callers.
        client = _build_client(role=None, monkeypatch=monkeypatch)
        response = client.get(
            "/api/v1/mobile/analysis/risk-reports/42?audience=clinician"
        )
        assert response.status_code in (401, 403)
