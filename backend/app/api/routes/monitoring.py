from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.audience import AudienceEnum, require_clinician_audience
from app.core.dependencies import get_current_user, get_target_profile_id
from app.db.database import get_db
from app.models.user_model import User
from app.schemas.monitoring import (
    SleepSessionResponse,
    SleepHistoryResponse,
    VitalSignsResponse,
    VitalsTimeseriesResponse,
    HealthReportResponse,
    RiskReportResponse,
    RiskReportClinicianResponse,
    RiskReportDetailResponse,
    RiskHistoryResponse,
    MobileVitalsBatch,
    MobileVitalsIngestResponse,
    MobileVitalsIngestRejection,
)
from app.services.monitoring_service import MonitoringService

# Create sub-routers for different metric categories
metrics_router = APIRouter(prefix="/metrics", tags=["mobile-metrics"])
analysis_router = APIRouter(prefix="/analysis", tags=["mobile-analysis"])

# Main router to include both
router = APIRouter(tags=["mobile-monitoring"])


@metrics_router.get(
    "/vital-signs/latest",
    response_model=VitalSignsResponse,
)
def get_latest_vital_signs(
    target_profile_id: int = Depends(get_target_profile_id),
    db: Session = Depends(get_db),
) -> VitalSignsResponse:
    """Get latest vital signs from database (real-time data)."""
    try:
        return MonitoringService.get_latest_vital_signs(
            patient_id=target_profile_id,
            db=db,
        )
    except ValueError:
        raise HTTPException(status_code=404, detail="Không tìm thấy dữ liệu sinh hiệu")


@metrics_router.get(
    "/vitals/timeseries",
    response_model=VitalsTimeseriesResponse,
)
def get_vitals_timeseries(
    target_profile_id: int = Depends(get_target_profile_id),
    db: Session = Depends(get_db),
    range: str = Query(
        default="1h",
        description=(
            "Time window for the chart. Supported: ``1h`` (12 × 5-min buckets), "
            "``6h`` (12 × 30-min), ``24h`` (96 × 15-min). "
            "Unknown values are coerced to ``1h``."
        ),
    ),
) -> VitalsTimeseriesResponse:
    """F-12 (M-6) — vitals time-series for the chart on `vital_detail_screen.dart`.

    Returns a downsampled list of `{ts, heart_rate, spo2, temperature,
    respiratory_rate, blood_pressure_sys, blood_pressure_dia}` rows. The
    server picks a bucket size that matches the range (15 min for 24h,
    1 h for 7d, 6 h for 30d) so each response stays well under 10 KB.

    Always returns 200 — including when the patient has no vitals or the
    `vitals` hypertable doesn't exist yet — so the mobile chart can render
    its "no data" placeholder without an error toast.
    """
    return MonitoringService.get_vitals_timeseries(
        patient_id=target_profile_id,
        db=db,
        range_key=range,
    )


@metrics_router.get(
    "/sleep/latest",
    response_model=SleepSessionResponse | None,
)
def get_latest_sleep_session(
    target_profile_id: int = Depends(get_target_profile_id),
    db: Session = Depends(get_db),
) -> SleepSessionResponse | None:
    """Get latest sleep session (real data only)."""
    return MonitoringService.get_latest_sleep_session(
        patient_id=target_profile_id,
        db=db,
    )


@metrics_router.get(
    "/sleep/history",
    response_model=SleepHistoryResponse,
)
def get_sleep_history(
    target_profile_id: int = Depends(get_target_profile_id),
    db: Session = Depends(get_db),
    from_date: str | None = None,
    to_date: str | None = None,
    limit: int = Query(default=30, ge=1, le=90),
) -> SleepHistoryResponse:
    """Get sleep session history within a date range."""
    sessions = MonitoringService.get_sleep_history(
        patient_id=target_profile_id,
        db=db,
        from_date=from_date,
        to_date=to_date,
        limit=limit,
    )
    return SleepHistoryResponse(data=sessions)


@metrics_router.get(
    "/health-report",
    response_model=HealthReportResponse,
)
def get_health_report(
    target_profile_id: int = Depends(get_target_profile_id),
    db: Session = Depends(get_db),
) -> HealthReportResponse:
    """Get comprehensive health report with vitals stats and risk assessment."""
    return MonitoringService.get_health_report(
        patient_id=target_profile_id,
        db=db,
    )


@analysis_router.get(
    "/risk-reports",
    response_model=list[RiskReportResponse],
)
def list_risk_reports(
    target_profile_id: int = Depends(get_target_profile_id),
    db: Session = Depends(get_db),
    limit: int = Query(default=10, ge=1, le=50),
) -> list[RiskReportResponse]:
    """Get recent risk reports from AI analysis."""
    return MonitoringService.get_risk_reports(
        patient_id=target_profile_id,
        db=db,
        limit=limit,
    )


@analysis_router.get(
    "/risk-reports/{report_id}",
    response_model=RiskReportDetailResponse | RiskReportClinicianResponse,
)
def get_risk_report_detail(
    report_id: int,
    audience: AudienceEnum = Depends(require_clinician_audience),
    target_profile_id: int = Depends(get_target_profile_id),
    db: Session = Depends(get_db),
) -> RiskReportDetailResponse | RiskReportClinicianResponse:
    """Get detailed risk report with explanation and AI recommendations.

    Phase 5: ``?audience=patient`` (default, open) returns the lean
    :class:`RiskReportDetailResponse`; ``?audience=clinician`` requires
    ``user.role`` in :data:`~app.core.audience.CLINICIAN_ROLES` (gated
    by :func:`require_clinician_audience`) and returns
    :class:`RiskReportClinicianResponse` which adds raw ``shap_details``
    + ``model_request_id``.
    """
    if audience == AudienceEnum.clinician:
        report = MonitoringService.get_risk_report_clinician_detail(
            patient_id=target_profile_id,
            report_id=report_id,
            db=db,
        )
    else:
        report = MonitoringService.get_risk_report_detail(
            patient_id=target_profile_id,
            report_id=report_id,
            db=db,
        )
    if not report:
        raise HTTPException(status_code=404, detail="Risk report not found")
    return report


@analysis_router.get(
    "/risk-history",
    response_model=RiskHistoryResponse,
)
def get_risk_history(
    target_profile_id: int = Depends(get_target_profile_id),
    db: Session = Depends(get_db),
    range: str = Query(default="7d"),
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=20, ge=1, le=100),
    risk_type: str | None = Query(
        default=None,
        description=(
            "Optional filter — one of ``general`` / ``sleep`` / ``fall``. "
            "Phase 4A-full slice 3b. Unknown values are silently ignored "
            "(forward-compatible with future risk types). Omit to return "
            "every type in one paginated stream."
        ),
    ),
) -> RiskHistoryResponse:
    """Get canonical risk score history for charts and paginated mobile lists.

    Phase 4A-full slice 3b adds the optional ``risk_type`` query parameter
    so the Flutter risk-history screen can render a filter chip row over
    "All" / "Sức khỏe" (general) / "Giấc ngủ" (sleep) / "Té ngã" (fall)
    without a separate endpoint per type.
    """
    return MonitoringService.get_risk_history(
        patient_id=target_profile_id,
        db=db,
        range_key=range,
        page=page,
        limit=limit,
        risk_type=risk_type,
    )


@metrics_router.post(
    "/vitals/ingest",
    response_model=MobileVitalsIngestResponse,
)
def ingest_mobile_vitals(
    payload: MobileVitalsBatch,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MobileVitalsIngestResponse:
    """Phase 2: Mobile clients (Flutter app reading from Health Connect)
    push batches of vitals harvested from the user's watch via Mi Fitness.

    Auth boundary: standard JWT user (NOT the internal-service token used
    by the IoT simulator) — the device must belong to the calling user.
    Insertion path is shared with `/telemetry/ingest` so risk pipeline
    output is symmetric across simulator and real-watch sources.
    """
    try:
        result = MonitoringService.ingest_mobile_batch(
            patient_id=current_user.id,
            device_id=payload.device_id,
            samples=payload.samples,
            db=db,
        )
    except PermissionError as exc:
        raise HTTPException(status_code=403, detail=str(exc))

    return MobileVitalsIngestResponse(
        accepted=result["accepted"],
        rejected=result["rejected"],
        rejections=[
            MobileVitalsIngestRejection(**r) for r in result["rejections"]
        ],
        risk_evaluated_devices=result["risk_evaluated_devices"],
    )


# Include sub-routers into main router
router.include_router(metrics_router)
router.include_router(analysis_router)
