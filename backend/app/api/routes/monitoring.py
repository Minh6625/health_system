from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.audience import AudienceEnum, require_clinician_audience
from app.core.dependencies import get_target_profile_id
from app.db.database import get_db
from app.schemas.monitoring import (
    SleepSessionResponse,
    SleepHistoryResponse,
    VitalSignsResponse,
    HealthReportResponse,
    RiskReportResponse,
    RiskReportClinicianResponse,
    RiskReportDetailResponse,
    RiskHistoryResponse,
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
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


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
    limit: int = 30,
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
    limit: int = 10,
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
) -> RiskHistoryResponse:
    """Get canonical risk score history for charts and paginated mobile lists."""
    return MonitoringService.get_risk_history(
        patient_id=target_profile_id,
        db=db,
        range_key=range,
        page=page,
        limit=limit,
    )


# Include sub-routers into main router
router.include_router(metrics_router)
router.include_router(analysis_router)
