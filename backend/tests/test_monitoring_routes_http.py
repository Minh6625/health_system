from __future__ import annotations

from datetime import UTC, date, datetime

from fastapi import FastAPI, Header, HTTPException, status
from fastapi.testclient import TestClient

from app.api.routes.monitoring import router as monitoring_router
from app.core.audience import AudienceEnum, require_clinician_audience
from app.core.dependencies import get_db, get_target_profile_id
from app.main import app as main_app
from app.schemas.monitoring import (
    HealthReportResponse,
    RiskHistoryResponse,
    RiskHistorySummaryResponse,
    RiskReportDetailResponse,
    RiskReportResponse,
    SleepSessionResponse,
    SnapshotMetricsResponse,
    VitalSignsResponse,
    VitalsTimeseriesPointResponse,
    VitalsTimeseriesResponse,
)
from app.services.monitoring_service import MonitoringService


def _build_test_client() -> TestClient:
    app = FastAPI()
    app.include_router(monitoring_router, prefix="/mobile")

    def _override_target_profile_id(
        x_target_profile_id: int | None = Header(
            default=None,
            alias="X-Target-Profile-Id",
        ),
    ) -> int:
        if x_target_profile_id is None:
            return 7
        if x_target_profile_id == 42:
            return 42
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Không có quyền xem dữ liệu của người dùng này",
        )

    def _override_db():
        yield object()

    # Phase 5 added ``require_clinician_audience`` to the detail route.
    # This existing test exercises the patient surface only; override the
    # gate so the auth-less TestClient doesn't 403.
    def _override_audience() -> AudienceEnum:
        return AudienceEnum.patient

    app.dependency_overrides[get_target_profile_id] = _override_target_profile_id
    app.dependency_overrides[get_db] = _override_db
    app.dependency_overrides[require_clinician_audience] = _override_audience
    return TestClient(app)


def test_mobile_monitoring_routes_use_canonical_shape_and_target_profile(
    monkeypatch,
) -> None:
    client = _build_test_client()
    calls: list[tuple[str, int, int | None]] = []
    timestamp = datetime(2026, 4, 19, 8, 0, tzinfo=UTC)

    def _record(name: str, patient_id: int, report_id: int | None = None) -> None:
        calls.append((name, patient_id, report_id))

    monkeypatch.setattr(
        MonitoringService,
        "get_latest_vital_signs",
        staticmethod(
            lambda patient_id, db: (
                _record("vitals", patient_id),
                VitalSignsResponse(
                    heart_rate=71.0,
                    spo2=98.0,
                    temperature=36.7,
                    respiratory_rate=17.0,
                    blood_pressure_sys=118.0,
                    blood_pressure_dia=76.0,
                    timestamp=timestamp,
                    is_stale=False,
                ),
            )[1]
        ),
    )
    monkeypatch.setattr(
        MonitoringService,
        "get_latest_sleep_session",
        staticmethod(
            lambda patient_id, db: (
                _record("sleep", patient_id),
                SleepSessionResponse(
                    session_id="sleep-1",
                    sleep_date=date(2026, 4, 18),
                    quality_score=84,
                    quality_label="GOOD",
                    in_bed_minutes=430,
                    sleep_minutes=390,
                    awake_minutes=40,
                    efficiency_ratio=0.91,
                    wake_count=1,
                    phases={"light": 220, "deep": 90, "rem": 80, "awake": 40},
                    start_time=datetime(2026, 4, 18, 22, 30, tzinfo=UTC),
                    end_time=datetime(2026, 4, 19, 5, 40, tzinfo=UTC),
                ),
            )[1]
        ),
    )
    monkeypatch.setattr(
        MonitoringService,
        "get_health_report",
        staticmethod(
            lambda patient_id, db: (
                _record("health", patient_id),
                HealthReportResponse(
                    vitals_24h_avg={"heart_rate": 72.0},
                    latest_risk_score=18.0,
                    risk_level="low",
                    risk_type="general",
                    last_updated=timestamp,
                    health_score=82.0,
                    health_level="good",
                    health_summary="Ổn định.",
                    confidence=0.92,
                    is_stale=False,
                ),
            )[1]
        ),
    )
    monkeypatch.setattr(
        MonitoringService,
        "get_risk_reports",
        staticmethod(
            lambda patient_id, db, limit=10: (
                _record("reports", patient_id),
                [
                    RiskReportResponse(
                        id=9,
                        risk_type="general",
                        risk_score=18.0,
                        score=18.0,
                        health_score=82.0,
                        risk_level="low",
                        health_level="good",
                        display_status="Ổn định",
                        summary="Ổn định.",
                        timestamp=timestamp,
                        previous_score=None,
                        trend_7d=[24, 21, 19, 18],
                        key_features=["heart_rate"],
                        recommendation_preview=["Tiếp tục theo dõi định kỳ."],
                        confidence=0.92,
                        is_stale=False,
                    ),
                ],
            )[1]
        ),
    )
    monkeypatch.setattr(
        MonitoringService,
        "get_risk_report_detail",
        staticmethod(
            lambda patient_id, report_id, db: (
                _record("detail", patient_id, report_id),
                RiskReportDetailResponse(
                    id=report_id,
                    risk_type="general",
                    risk_score=18.0,
                    score=18.0,
                    health_score=82.0,
                    risk_level="low",
                    health_level="good",
                    display_status="Ổn định",
                    summary="Ổn định.",
                    timestamp=timestamp,
                    previous_score=None,
                    trend_7d=[24, 21, 19, 18],
                    explanation="On dinh.",
                    xai_explanation="On dinh.",
                    features={"confidence": 0.92},
                    feature_importance={"heart_rate": 0.4},
                    breakdown=[],
                    recommendations=["Tiếp tục theo dõi định kỳ."],
                    recommendation_preview=["Tiếp tục theo dõi định kỳ."],
                    top_factors=[],
                    snapshot=SnapshotMetricsResponse(heart_rate=71, spo2=98),
                    model_version="1.0",
                    algorithm="rule_based",
                    confidence=0.92,
                    is_stale=False,
                ),
            )[1]
        ),
    )
    monkeypatch.setattr(
        MonitoringService,
        "get_risk_history",
        staticmethod(
            # Phase 4A-full slice 3b added the optional ``risk_type``
            # kwarg; this stub accepts it but the test doesn't assert
            # on filter behaviour (covered separately).
            lambda patient_id, db, range_key="7d", page=1, limit=20, risk_type=None: (
                _record("history", patient_id),
                RiskHistoryResponse(
                    range=range_key,
                    summary=RiskHistorySummaryResponse(
                        average_score=18.0,
                        highest_score=24.0,
                        lowest_score=18.0,
                        delta_vs_previous_period=-3.0,
                        trend_points=[24, 21, 19, 18],
                    ),
                    items=[],
                    page=page,
                    limit=limit,
                    has_more=False,
                ),
            )[1]
        ),
    )

    self_headers = {}
    linked_headers = {"X-Target-Profile-Id": "42"}

    self_responses = [
        client.get("/mobile/metrics/vital-signs/latest", headers=self_headers),
        client.get("/mobile/metrics/sleep/latest", headers=self_headers),
        client.get("/mobile/metrics/health-report", headers=self_headers),
        client.get("/mobile/analysis/risk-reports?limit=1", headers=self_headers),
        client.get("/mobile/analysis/risk-reports/9", headers=self_headers),
        client.get("/mobile/analysis/risk-history?range=7d&page=1&limit=5", headers=self_headers),
    ]
    linked_responses = [
        client.get("/mobile/metrics/vital-signs/latest", headers=linked_headers),
        client.get("/mobile/metrics/sleep/latest", headers=linked_headers),
        client.get("/mobile/metrics/health-report", headers=linked_headers),
        client.get("/mobile/analysis/risk-reports?limit=1", headers=linked_headers),
        client.get("/mobile/analysis/risk-reports/9", headers=linked_headers),
        client.get("/mobile/analysis/risk-history?range=7d&page=1&limit=5", headers=linked_headers),
    ]

    for response in [*self_responses, *linked_responses]:
        assert response.status_code == 200

    latest_payload = self_responses[3].json()
    detail_payload = self_responses[4].json()
    history_payload = self_responses[5].json()
    linked_latest_payload = linked_responses[3].json()

    assert isinstance(latest_payload, list)
    assert latest_payload[0]["display_status"] == "Ổn định"
    assert latest_payload[0]["health_score"] == 82.0
    assert latest_payload[0]["is_stale"] is False
    assert detail_payload["display_status"] == "Ổn định"
    assert detail_payload["health_score"] == 82.0
    assert detail_payload["snapshot"]["heart_rate"] == 71
    assert detail_payload["is_stale"] is False
    assert history_payload["range"] == "7d"
    assert history_payload["page"] == 1
    assert history_payload["limit"] == 5
    assert history_payload["has_more"] is False
    assert history_payload["summary"]["trend_points"] == [24, 21, 19, 18]
    assert linked_latest_payload[0]["previous_score"] is None

    assert calls == [
        ("vitals", 7, None),
        ("sleep", 7, None),
        ("health", 7, None),
        ("reports", 7, None),
        ("detail", 7, 9),
        ("history", 7, None),
        ("vitals", 42, None),
        ("sleep", 42, None),
        ("health", 42, None),
        ("reports", 42, None),
        ("detail", 42, 9),
        ("history", 42, None),
    ]


def test_mobile_monitoring_routes_reject_unauthorized_linked_profile() -> None:
    client = _build_test_client()

    response = client.get(
        "/mobile/analysis/risk-history",
        headers={"X-Target-Profile-Id": "999"},
    )

    assert response.status_code == 403


def test_main_app_registers_single_mobile_risk_reports_route() -> None:
    matching_routes = [
        (route.path, tuple(sorted(route.methods)))
        for route in main_app.routes
        if getattr(route, "path", None) == "/mobile/analysis/risk-reports"
    ]

    assert matching_routes == [
        ("/mobile/analysis/risk-reports", ("GET",)),
    ]


# ----------------------------------------------------------------------
# F-12 (M-6): vitals time-series HTTP route.
#
# Lives in its own test rather than the canonical-shape mega-test above
# because that test asserts on an exact call list — extending it would
# touch many unrelated assertions and risk muddying the diff. The
# isolated test pins three things end-to-end: the route is mounted at
# the documented path, the `range` query param flows through to the
# service, and the JSON payload preserves `null` channels (a zero in a
# missing-data bucket would render a misleading cliff in the chart).
# ----------------------------------------------------------------------


def test_vitals_timeseries_route_passes_range_through_and_preserves_nulls(
    monkeypatch,
) -> None:
    client = _build_test_client()

    captured: dict[str, object] = {}

    bucket_a = datetime(2026, 4, 29, 6, 0, tzinfo=UTC)
    bucket_b = datetime(2026, 4, 29, 6, 15, tzinfo=UTC)

    def _stub_get_vitals_timeseries(patient_id, db, range_key="24h"):
        captured["patient_id"] = patient_id
        captured["range_key"] = range_key
        return VitalsTimeseriesResponse(
            range=range_key,
            bucket_minutes=15,
            data=[
                VitalsTimeseriesPointResponse(
                    ts=bucket_a,
                    heart_rate=72.0,
                    spo2=98.0,
                    temperature=36.7,
                    respiratory_rate=16.0,
                    blood_pressure_sys=118.0,
                    blood_pressure_dia=76.0,
                ),
                VitalsTimeseriesPointResponse(
                    ts=bucket_b,
                    heart_rate=74.5,
                    spo2=None,
                    temperature=36.8,
                    respiratory_rate=17.0,
                    blood_pressure_sys=None,
                    blood_pressure_dia=None,
                ),
            ],
        )

    monkeypatch.setattr(
        MonitoringService,
        "get_vitals_timeseries",
        staticmethod(_stub_get_vitals_timeseries),
    )

    # Default range — confirms the route mounts at the documented path
    # and that `range_key` defaults to "24h" when the client omits it.
    default_response = client.get("/mobile/metrics/vitals/timeseries")
    assert default_response.status_code == 200
    default_payload = default_response.json()
    assert captured["patient_id"] == 7
    assert captured["range_key"] == "24h"
    assert default_payload["range"] == "24h"
    assert default_payload["bucket_minutes"] == 15
    assert len(default_payload["data"]) == 2
    # Channel-level null MUST round-trip as `null`, not 0 — a zero
    # would draw a misleading "SpO2 dropped to 0" cliff. This is the
    # precise regression M-6's chart wiring is meant to avoid.
    assert default_payload["data"][1]["spo2"] is None
    assert default_payload["data"][1]["blood_pressure_sys"] is None

    # Explicit `range` param flows through to the service so the future
    # 7d / 30d tabs can be wired without further route changes.
    seven_day_response = client.get(
        "/mobile/metrics/vitals/timeseries?range=7d"
    )
    assert seven_day_response.status_code == 200
    assert captured["range_key"] == "7d"


def test_vitals_timeseries_route_respects_target_profile_header(
    monkeypatch,
) -> None:
    client = _build_test_client()

    captured_patient_ids: list[int] = []

    def _stub_get_vitals_timeseries(patient_id, db, range_key="24h"):
        captured_patient_ids.append(patient_id)
        return VitalsTimeseriesResponse(range="24h", bucket_minutes=15, data=[])

    monkeypatch.setattr(
        MonitoringService,
        "get_vitals_timeseries",
        staticmethod(_stub_get_vitals_timeseries),
    )

    # Self profile (no header).
    self_resp = client.get("/mobile/metrics/vitals/timeseries")
    assert self_resp.status_code == 200

    # Linked profile (allowed).
    linked_resp = client.get(
        "/mobile/metrics/vitals/timeseries",
        headers={"X-Target-Profile-Id": "42"},
    )
    assert linked_resp.status_code == 200

    # Forbidden profile MUST 403 like every other monitoring route —
    # this is the exact gate that keeps a caregiver from snooping a
    # non-linked patient's vitals time-series. Drift here would be a
    # security regression.
    forbidden_resp = client.get(
        "/mobile/metrics/vitals/timeseries",
        headers={"X-Target-Profile-Id": "999"},
    )
    assert forbidden_resp.status_code == 403

    # Service was only called for the two allowed profiles.
    assert captured_patient_ids == [7, 42]
