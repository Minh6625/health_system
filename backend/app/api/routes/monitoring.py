from fastapi import APIRouter
from fastapi import Depends
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user, get_target_profile_id
from app.db.database import get_db
from app.models.user_model import User
from app.schemas.monitoring import SleepSessionResponse, VitalSignsResponse
from app.services.monitoring_service import MonitoringService

router = APIRouter(tags=["mobile-monitoring"])


@router.get(
    "/vital-signs/latest",
    response_model=VitalSignsResponse,
)
def get_latest_vital_signs(
    target_profile_id: int = Depends(get_target_profile_id),
) -> VitalSignsResponse:
    return MonitoringService.get_latest_vital_signs(patient_id=target_profile_id)


@router.get(
    "/sleep/latest",
    response_model=SleepSessionResponse,
)
def get_latest_sleep_session(
    target_profile_id: int = Depends(get_target_profile_id),
    db: Session = Depends(get_db),
) -> SleepSessionResponse:
    return MonitoringService.get_latest_sleep_session(
        patient_id=target_profile_id,
        db=db,
    )
