from __future__ import annotations

from datetime import UTC, date, datetime

from fastapi import FastAPI, Header, HTTPException, status
from fastapi.testclient import TestClient

from app.api.routes.monitoring import router as monitoring_router
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

    app.dependency_overrides[get_target_profile_id] = _override_target_profile_id
    app.dependency_overrides[get_db] = _override_db
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
                    vitals_24h_avg={"avg_hr": 72.0},
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
            lambda patient_id, db, range_key="7d", page=1, limit=20: (
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

    assert isinstance(self_responses[3].json(), list)
    assert self_responses[5].json()["summary"]["trend_points"] == [24, 21, 19, 18]
    assert linked_responses[3].json()[0]["previous_score"] is None

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
        "/mobile/metrics/vital-signs/latest",
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
