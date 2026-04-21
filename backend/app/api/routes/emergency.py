from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.models.user_model import User
from app.core.dependencies import get_current_user
from app.schemas.emergency import (
    SOSAlertsResponse,
    SOSEventResponse,
    ResolveSOSRequest,
    TriggerSOSRequest,
    SuccessResponse,
    TriggerSOSResponse,
)
from app.services.emergency_service import EmergencyService


router = APIRouter(prefix="/emergency", tags=["Emergency"])

@router.post("/sos/trigger", response_model=TriggerSOSResponse)
def trigger_sos(
    payload: TriggerSOSRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> TriggerSOSResponse:
    """
    Triggers a manual or automatic SOS event for the current user.
    """
    sos_event, dispatch_info = EmergencyService.trigger_sos(
        db,
        current_user.id,
        trigger_type=payload.trigger_type,
        latitude=payload.latitude,
        longitude=payload.longitude,
        address=payload.address,
    )
    return TriggerSOSResponse(
        success=True,
        message="Đã gửi tín hiệu khẩn cấp thành công",
        sos_id=int(sos_event.id),
        recipient_count=len(dispatch_info["recipient_user_ids"]),
    )

@router.get("/caregiver/sos-alerts", response_model=SOSAlertsResponse)
def get_sos_alerts(
    status_filter: str = Query("all", alias="status", pattern="^(all|active|resolved)$"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> SOSAlertsResponse:
    """
    Get list of SOS alerts for caregiver.
    
    Query Parameters:
        - status: Filter by status ("all", "active", "resolved")
    
    Returns:
        List of SOS alerts with patient info and basic details
    """
    return EmergencyService.get_sos_alerts_for_caregiver(
        db, current_user.id, status_filter
    )


@router.get("/sos/{sos_id}", response_model=SOSEventResponse)
def get_sos_detail(
    sos_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> SOSEventResponse:
    """
    Get detailed information for a specific SOS event.
    
    Path Parameters:
        - sos_id: SOS event ID
    
    Returns:
        Complete SOS event details including patient info, location, XAI data, resolution info
    """
    sos_detail = EmergencyService.get_sos_detail(db, sos_id)
    
    if not sos_detail:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy sự kiện SOS"
        )
    
    from app.repositories.emergency_repository import EmergencyRepository
    # Check authorization (must be owner or linked profile)
    has_access = EmergencyRepository.check_user_has_access(db, current_user.id, sos_detail.patient.user_id)
    if not has_access and current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Bạn không có quyền xem chi tiết SOS này"
        )
    
    return sos_detail


@router.post("/sos/{sos_id}/resolve", response_model=SuccessResponse)
def resolve_sos(
    sos_id: int,
    payload: ResolveSOSRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> SuccessResponse:
    """
    Mark SOS event as resolved (patient is safe).
    
    Path Parameters:
        - sos_id: SOS event ID
    
    Request Body:
        - resolution_status: "safe", "assisted", or "cancelled"
        - notes: Optional resolution notes
    
    Returns:
        Success response
    """
    sos_detail = EmergencyService.get_sos_detail(db, sos_id)
    if not sos_detail:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy sự kiện SOS"
        )
        
    from app.repositories.emergency_repository import EmergencyRepository
    # Check authorization
    has_access = EmergencyRepository.check_user_has_access(db, current_user.id, sos_detail.patient.user_id)
    if not has_access and current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Bạn không có quyền xác nhận xử lý SOS này"
        )
    
    success = EmergencyService.resolve_sos_by_caregiver(
        db, 
        sos_id, 
        current_user.id,
        payload.resolution_status,
        payload.notes
    )
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy sự kiện SOS"
        )
    
    return SuccessResponse(
        success=True,
        message="Đã xác nhận xử lý SOS thành công"
    )
