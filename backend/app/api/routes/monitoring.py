from fastapi import APIRouter, HTTPException
from fastapi import Depends
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user, get_target_profile_id
from app.db.database import get_db
from app.models.user_model import User
from app.schemas.monitoring import (
    SleepSessionResponse,
    VitalSignsResponse,
    HealthReportResponse,
    RiskReportResponse,
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
    response_model=list[SleepSessionResponse],
)
def get_sleep_history(
    target_profile_id: int = Depends(get_target_profile_id),
    db: Session = Depends(get_db),
    from_date: str | None = None,
    to_date: str | None = None,
    limit: int = 30,
) -> list[SleepSessionResponse]:
    """Get sleep session history within a date range."""
    return MonitoringService.get_sleep_history(
        patient_id=target_profile_id,
        db=db,
        from_date=from_date,
        to_date=to_date,
        limit=limit,
    )


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
    response_model=RiskReportDetailResponse,
)
def get_risk_report_detail(
    report_id: int,
    target_profile_id: int = Depends(get_target_profile_id),
    db: Session = Depends(get_db),
) -> RiskReportDetailResponse:
    """Get detailed risk report with explanation and AI recommendations."""
    report = MonitoringService.get_risk_report_detail(
        report_id=report_id,
        db=db,
    )
    if not report:
        raise HTTPException(status_code=404, detail="Risk report not found")
    return report


@analysis_router.get(
    "/risk-history",
    response_model=dict,
)
def get_risk_history(
    target_profile_id: int = Depends(get_target_profile_id),
    db: Session = Depends(get_db),
    days: int = 30,
) -> dict:
    """Get risk score history over time (aggregated by date)."""
    return MonitoringService.get_risk_history(
        patient_id=target_profile_id,
        db=db,
        days=days,
    )


# Include sub-routers into main router
router.include_router(metrics_router)
router.include_router(analysis_router)
