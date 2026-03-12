from fastapi import APIRouter
from fastapi import Depends
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.models.user_model import User
from app.schemas.monitoring import SleepSessionResponse, VitalSignsResponse
from app.services.monitoring_service import MonitoringService

router = APIRouter(prefix="/mobile", tags=["mobile-monitoring"])


@router.get(
    "/vital-signs/latest",
    response_model=VitalSignsResponse,
)
def get_latest_vital_signs(
    current_user: User = Depends(get_current_user),
) -> VitalSignsResponse:
    return MonitoringService.get_latest_vital_signs(patient_id=current_user.id)


@router.get(
    "/sleep/latest",
    response_model=SleepSessionResponse,
)
def get_latest_sleep_session(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> SleepSessionResponse:
    return MonitoringService.get_latest_sleep_session(
        patient_id=current_user.id,
        db=db,
    )
