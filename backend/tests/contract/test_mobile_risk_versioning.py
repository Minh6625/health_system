"""Phase 6 contract tests: ``X-Risk-Contract-Version`` + route surface.

These tests pin three orthogonal guarantees that together let an older
Flutter binary detect that it is talking to an incompatible backend:

1. Every mobile risk route declares its ``response_model`` explicitly so
   FastAPI generates the right schema in OpenAPI and validates the
   response shape on the way out.
2. Every mobile risk route returns the ``X-Risk-Contract-Version`` header
   on success, with the value pinned to
   :data:`app.core.risk_contract.RISK_CONTRACT_VERSION`.
3. Routes that are NOT part of the risk contract surface (e.g. auth,
   notifications) do **not** carry the header — bumping the contract
   version must not be confused with bumping unrelated APIs.
"""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any

import pytest
from fastapi import Header, HTTPException, status
from fastapi.testclient import TestClient

from app.core.audience import AudienceEnum, require_clinician_audience
from app.core.dependencies import get_db, get_target_profile_id
from app.core.risk_contract import (
    RISK_CONTRACT_VERSION,
    RISK_CONTRACT_VERSION_HEADER,
    applies_to_path,
)
from app.main import app as main_app
from app.schemas.monitoring import (
    HealthReportResponse,
    RiskHistoryResponse,
    RiskHistorySummaryResponse,
    RiskReportClinicianResponse,
    RiskReportDetailResponse,
    RiskReportResponse,
    SnapshotMetricsResponse,
)
from app.services.monitoring_service import MonitoringService


# ---------------------------------------------------------------------------
# Test fixtures + service stubs
# ---------------------------------------------------------------------------


_TIMESTAMP = datetime(2026, 4, 27, 8, 0, tzinfo=UTC)


def _stub_risk_report() -> RiskReportResponse:
    return RiskReportResponse(
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
        key_features=[],
        top_factors=[],
        recommendation_preview=[],
        confidence=0.92,
        is_stale=False,
    )


def _stub_risk_report_detail() -> RiskReportDetailResponse:
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


def _stub_risk_history() -> RiskHistoryResponse:
    return RiskHistoryResponse(
        range="7d",
        summary=RiskHistorySummaryResponse(),
        items=[],
        page=1,
        limit=20,
        has_more=False,
    )


def _stub_health_report() -> HealthReportResponse:
    return HealthReportResponse(vitals_24h_avg={})


@pytest.fixture
def risk_client(monkeypatch) -> TestClient:
    """``TestClient`` wired against the real ``main_app`` middleware stack.

    The middleware-under-test (``RiskContractVersionMiddleware``) is
    registered on ``main_app``, so we hit it here rather than building a
    bare ``FastAPI()`` like ``test_monitoring_routes_http.py`` does.
    """

    def _override_target_profile_id(
        x_target_profile_id: int | None = Header(
            default=None, alias="X-Target-Profile-Id"
        ),
    ) -> int:
        if x_target_profile_id is None:
            return 7
        if x_target_profile_id == 42:
            return 42
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN)

    def _override_db():
        yield object()

    # Phase 5 added ``require_clinician_audience`` to the detail route.
    # Override it to always return ``patient`` so the existing header /
    # OpenAPI tests don't need to plumb a real authenticated user — they
    # already exercise the patient surface.
    def _override_audience() -> AudienceEnum:
        return AudienceEnum.patient

    main_app.dependency_overrides[get_target_profile_id] = _override_target_profile_id
    main_app.dependency_overrides[get_db] = _override_db
    main_app.dependency_overrides[require_clinician_audience] = _override_audience

    monkeypatch.setattr(
        MonitoringService,
        "get_risk_reports",
        staticmethod(lambda patient_id, db, limit=10: [_stub_risk_report()]),
    )
    monkeypatch.setattr(
        MonitoringService,
        "get_risk_report_detail",
        staticmethod(
            lambda patient_id, report_id, db: _stub_risk_report_detail()
        ),
    )
    monkeypatch.setattr(
        MonitoringService,
        "get_risk_history",
        staticmethod(
            # Phase 4A-full slice 3b added the optional ``risk_type``
            # kwarg; accept + ignore it so this stub keeps working
            # for the version-header tests.
            lambda patient_id, db, range_key="7d", page=1, limit=20, risk_type=None: _stub_risk_history()
        ),
    )
    monkeypatch.setattr(
        MonitoringService,
        "get_health_report",
        staticmethod(lambda patient_id, db: _stub_health_report()),
    )

    yield TestClient(main_app)

    main_app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Route signature contract
# ---------------------------------------------------------------------------


_EXPECTED_RESPONSE_MODELS: dict[str, type] = {
    "/mobile/analysis/risk-reports": list[RiskReportResponse],  # type: ignore[dict-item]
    # Phase 5 turned the detail route's response_model into a Union of
    # patient + clinician DTOs. FastAPI preserves the Union on the
    # runtime ``route.response_model`` attribute AND emits a faithful
    # ``anyOf`` in OpenAPI (the latter is asserted below in
    # ``TestMobileRiskOpenApiSnapshot.test_detail_path_emits_anyof_for_audience``).
    "/mobile/analysis/risk-reports/{report_id}": (
        RiskReportDetailResponse | RiskReportClinicianResponse
    ),
    "/mobile/analysis/risk-history": RiskHistoryResponse,
    "/mobile/metrics/health-report": HealthReportResponse,
}


class TestMobileRiskRouteSignatureContract:
    """Pin the FastAPI route declarations so renaming a path or dropping a
    ``response_model`` fails the contract suite immediately."""

    def test_each_risk_route_declares_expected_response_model(self) -> None:
        actual: dict[str, Any] = {}
        for route in main_app.routes:
            path = getattr(route, "path", None)
            if path in _EXPECTED_RESPONSE_MODELS:
                actual[path] = getattr(route, "response_model", None)

        assert actual == _EXPECTED_RESPONSE_MODELS, (
            "Mobile risk route surface drifted. Update the test "
            "if the change is intentional, then bump "
            "RISK_CONTRACT_VERSION + the baseline doc."
        )

    def test_all_expected_routes_are_registered_exactly_once(self) -> None:
        path_counts: dict[str, int] = {}
        for route in main_app.routes:
            path = getattr(route, "path", None)
            if path in _EXPECTED_RESPONSE_MODELS:
                path_counts[path] = path_counts.get(path, 0) + 1

        assert path_counts == {p: 1 for p in _EXPECTED_RESPONSE_MODELS}, (
            f"A mobile risk route is registered more than once: {path_counts}. "
            "Duplicate registrations create silent ambiguity in OpenAPI and "
            "make Phase 6 versioning meaningless."
        )


# ---------------------------------------------------------------------------
# X-Risk-Contract-Version header contract
# ---------------------------------------------------------------------------


class TestRiskContractVersionHeaderOnRiskSurface:
    """Phase 6 guarantee: every successful response on the risk surface
    carries ``X-Risk-Contract-Version: RISK_CONTRACT_VERSION``.
    """

    @pytest.mark.parametrize(
        "path",
        [
            "/mobile/analysis/risk-reports",
            "/mobile/analysis/risk-reports/42",
            "/mobile/analysis/risk-history",
            "/mobile/metrics/health-report",
        ],
    )
    def test_header_is_set_on_risk_route_responses(
        self, risk_client: TestClient, path: str
    ) -> None:
        response = risk_client.get(path)
        assert response.status_code == 200, response.text
        assert response.headers.get(RISK_CONTRACT_VERSION_HEADER) == RISK_CONTRACT_VERSION

    def test_header_value_is_the_single_source_of_truth_constant(
        self, risk_client: TestClient
    ) -> None:
        # Guard against ad-hoc literals creeping into the middleware.
        response = risk_client.get("/mobile/analysis/risk-reports")
        assert response.headers[RISK_CONTRACT_VERSION_HEADER] == RISK_CONTRACT_VERSION
        assert RISK_CONTRACT_VERSION  # must be non-empty


class TestRiskContractVersionHeaderScope:
    """The header scope MUST stay narrow.

    The risk contract version describes the **mobile risk DTO** only;
    bumping it should not signal a change in unrelated APIs (auth,
    notifications, telemetry ingestion). These tests pin that boundary.
    """

    @pytest.mark.parametrize(
        "path",
        [
            "/mobile/analysis/risk-reports",
            "/mobile/analysis/risk-reports/42",
            "/mobile/analysis/risk-history",
            "/mobile/metrics/health-report",
            "/api/v1/mobile/analysis/risk-reports",
            "/api/v1/mobile/metrics/health-report",
        ],
    )
    def test_applies_to_path_recognises_risk_surface(self, path: str) -> None:
        assert applies_to_path(path) is True

    @pytest.mark.parametrize(
        "path",
        [
            "/mobile/auth/login",
            "/mobile/notifications",
            "/mobile/vitals/latest",
            "/mobile/analysis/sleep-history",  # sleep is NOT in the risk surface (Phase 4A territory)
            "/api/v1/mobile/auth/refresh",
            "/",
            "/mobile-docs",
        ],
    )
    def test_applies_to_path_excludes_non_risk_surface(self, path: str) -> None:
        assert applies_to_path(path) is False


# ---------------------------------------------------------------------------
# OpenAPI snapshot — the schemas we expose to mobile codegen
# ---------------------------------------------------------------------------


def _collect_refs(schema: dict[str, Any]) -> list[str]:
    """Walk an OpenAPI schema fragment and return every ``$ref`` it contains.

    Handles three shapes:

    * ``{"$ref": "..."}`` — single DTO response.
    * ``{"items": {"$ref": "..."}}`` — list response.
    * ``{"oneOf"|"anyOf": [{"$ref": "..."}, ...]}`` — Phase 5 Union
      response_model on the detail surface.
    """
    refs: list[str] = []
    if not isinstance(schema, dict):
        return refs
    if isinstance(schema.get("$ref"), str):
        refs.append(schema["$ref"])
    items = schema.get("items")
    if isinstance(items, dict) and isinstance(items.get("$ref"), str):
        refs.append(items["$ref"])
    for key in ("oneOf", "anyOf"):
        branch = schema.get(key)
        if isinstance(branch, list):
            for entry in branch:
                refs.extend(_collect_refs(entry))
    return refs


_EXPECTED_OPENAPI_PATHS = frozenset(
    {
        "/mobile/analysis/risk-reports",
        "/mobile/analysis/risk-reports/{report_id}",
        "/mobile/analysis/risk-history",
        "/mobile/metrics/health-report",
    }
)


class TestMobileRiskOpenApiSnapshot:
    """Pin which paths + DTO references show up in the generated OpenAPI.

    We deliberately do NOT snapshot the entire OpenAPI document — that
    would couple this test to every unrelated route. We only check the
    risk surface so a Phase 4A sleep route can land without breaking us.
    """

    def test_expected_risk_paths_are_present_in_openapi(self) -> None:
        paths = main_app.openapi().get("paths", {})
        present = {p for p in _EXPECTED_OPENAPI_PATHS if p in paths}
        assert present == _EXPECTED_OPENAPI_PATHS, (
            "Mobile risk route surface missing from OpenAPI. Updating: ensure "
            "every risk route in main_app declares response_model and that "
            "the path in _EXPECTED_OPENAPI_PATHS still matches the route "
            "decorator."
        )

    def test_each_risk_path_references_a_dto_schema(self) -> None:
        paths = main_app.openapi()["paths"]
        for path in _EXPECTED_OPENAPI_PATHS:
            spec = paths[path]["get"]
            content = spec["responses"]["200"]["content"]["application/json"]
            schema = content["schema"]
            # Phase 5: the detail surface emits a ``oneOf`` (Union of
            # patient + clinician DTOs); other surfaces stay as a single
            # ``$ref`` or a list of ``$ref``. Walk all three shapes so a
            # single helper covers every risk path.
            refs = _collect_refs(schema)
            assert refs, (
                f"Risk path {path} does not reference any DTO schema in "
                f"OpenAPI; mobile codegen would emit ``Map<String, dynamic>``. "
                f"Ensure ``response_model=...`` is set on the route."
            )

    def test_detail_path_emits_anyof_for_audience(self) -> None:
        """Phase 5: the detail route's OpenAPI schema must include both
        the patient and clinician DTOs as an ``anyOf`` so mobile codegen
        can model the audience-conditioned response.

        FastAPI collapses ``A | B(A)`` on the runtime ``route.response_model``
        attribute, but the OpenAPI generator preserves both branches
        because the route function's return type annotation is still the
        Union. This test pins the OpenAPI guarantee — codegen consumers
        depend on it.
        """
        spec = main_app.openapi()
        schema = spec["paths"]["/mobile/analysis/risk-reports/{report_id}"][
            "get"
        ]["responses"]["200"]["content"]["application/json"]["schema"]
        refs = set(_collect_refs(schema))
        expected = {
            "#/components/schemas/RiskReportDetailResponse",
            "#/components/schemas/RiskReportClinicianResponse",
        }
        assert expected.issubset(refs), (
            f"OpenAPI detail-route response is missing one or more "
            f"audience DTOs. Expected refs: {expected}. Got: {refs}. "
            "If you collapsed the Union response_model to a single DTO, "
            "either restore it or update this test + bump "
            "RISK_CONTRACT_VERSION + the baseline doc."
        )

    def test_dto_components_match_phase_1_pinned_dtos(self) -> None:
        components = main_app.openapi()["components"]["schemas"]
        # The Phase 0/1 baseline pins these exact DTO names. If they ever
        # rename / split / merge, both this test AND the snapshot tests in
        # tests/contract/test_mobile_risk_dto_snapshot.py will fail —
        # which is the intended behaviour.
        # Phase 5 adds ``RiskReportClinicianResponse`` to the required set.
        for required in (
            "RiskReportResponse",
            "RiskReportDetailResponse",
            "RiskReportClinicianResponse",
            "RiskHistoryResponse",
            "RiskHistoryItemResponse",
            "RiskHistorySummaryResponse",
            "TopFactorResponse",
            "FactorBreakdownResponse",
            "AiExplanationResponse",
            "SnapshotMetricsResponse",
            "HealthReportResponse",
        ):
            assert required in components, (
                f"OpenAPI components.schemas missing {required!r}. "
                "Mobile codegen + manual SDK consumers depend on this name."
            )
