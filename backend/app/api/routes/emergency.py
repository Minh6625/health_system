from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request, status, Query
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
    RecentAlertsResponse,
)
from app.services.emergency_service import EmergencyService
from app.services.push_notification_service import PushNotificationService
from app.utils.audit_helper import get_client_ip, get_user_agent, safe_log_action


router = APIRouter(prefix="/emergency", tags=["Emergency"])

@router.post("/sos/trigger", response_model=TriggerSOSResponse)
def trigger_sos(
    payload: TriggerSOSRequest,
    request: Request,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> TriggerSOSResponse:
    """
    Triggers a manual or automatic SOS event for the current user.
    """
    ip_address = get_client_ip(request)
    user_agent = get_user_agent(request)
    try:
        sos_event, dispatch_info = EmergencyService.trigger_sos(
            db,
            current_user.id,
            trigger_type=payload.trigger_type,
            latitude=payload.latitude,
            longitude=payload.longitude,
            address=payload.address,
            send_push=False,
        )
    except HTTPException as exc:
        # Log failure (e.g. 400 no_active_device) before re-raising so the
        # forensic trail captures the attempt.
        safe_log_action(
            db,
            action="sos.triggered",
            status="failure",
            user_id=int(current_user.id),
            resource_type="sos_event",
            ip_address=ip_address,
            user_agent=user_agent,
            details={
                "trigger_type": payload.trigger_type,
                "has_location": payload.latitude is not None,
                "reason": str(exc.detail),
                "http_status": exc.status_code,
            },
        )
        raise
    background_tasks.add_task(
        PushNotificationService.send_sos_push_alerts,
        db,
        recipient_user_ids=dispatch_info["recipient_user_ids"],
        title=dispatch_info["title"],
        body=dispatch_info["body"],
        sos_id=int(sos_event.id),
        alert_type=dispatch_info["alert_type"],
        trigger_type=dispatch_info["trigger_type"],
        notification_id_by_user=dispatch_info["notification_id_by_user"],
    )
    safe_log_action(
        db,
        action="sos.triggered",
        status="success",
        user_id=int(current_user.id),
        resource_type="sos_event",
        resource_id=int(sos_event.id),
        ip_address=ip_address,
        user_agent=user_agent,
        details={
            "trigger_type": payload.trigger_type,
            "has_location": payload.latitude is not None,
            "deduplicated": bool(dispatch_info.get("skipped", False)),
            "recipient_count": len(dispatch_info["recipient_user_ids"]),
            "alert_type": dispatch_info.get("alert_type"),
        },
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


@router.get(
    "/caregiver/patients/{patient_user_id}/recent-alerts",
    response_model=RecentAlertsResponse,
)
def get_patient_recent_alerts(
    patient_user_id: int,
    days: int = Query(7, ge=1, le=30),
    limit: int = Query(10, ge=1, le=50),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> RecentAlertsResponse:
    """Recent health alerts about a single patient (caregiver feed).

    Powers the "Cảnh báo gần đây" section on the mobile PersonDetailScreen.
    Filters to the curated whitelist in
    :data:`app.core.alert_constants.CAREGIVER_FEED_ALERT_TYPES` so device
    status (offline / battery) and conversational events stay out of the
    health timeline.

    Authorization: caller must be the patient themselves OR an accepted
    caregiver with ``can_receive_alerts = True``. The service layer raises
    403 with no information leak about whether a relationship exists.
    """
    return EmergencyService.get_recent_alerts_for_patient(
        db,
        viewer_user_id=int(current_user.id),
        patient_user_id=int(patient_user_id),
        days=days,
        limit=limit,
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
    # Bug fix G-3: pass the viewer's identity so the service can redact
    # ``LocationInfo`` for caregivers whose relationship row has
    # ``can_view_location=False``. Owners (patient viewing their own SOS) and
    # admins see the full payload.
    sos_detail = EmergencyService.get_sos_detail(
        db,
        sos_id,
        viewer_user_id=int(current_user.id),
        viewer_is_admin=(current_user.role == "admin"),
    )

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
    request: Request,
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
    ip_address = get_client_ip(request)
    user_agent = get_user_agent(request)
    sos_detail = EmergencyService.get_sos_detail(db, sos_id)
    if not sos_detail:
        # 404 enumeration-resistant: skip audit log on purpose.
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy sự kiện SOS"
        )
        
    from app.repositories.emergency_repository import EmergencyRepository
    # Check authorization
    has_access = EmergencyRepository.check_user_has_access(db, current_user.id, sos_detail.patient.user_id)
    if not has_access and current_user.role != "admin":
        # 403 forensic: a caregiver/admin tried to close someone's SOS.
        safe_log_action(
            db,
            action="sos.resolved",
            status="failure",
            user_id=int(current_user.id),
            resource_type="sos_event",
            resource_id=int(sos_id),
            ip_address=ip_address,
            user_agent=user_agent,
            details={
                "reason": "forbidden",
                "resolution_status": payload.resolution_status,
                "patient_user_id": int(sos_detail.patient.user_id),
            },
        )
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

    safe_log_action(
        db,
        action="sos.resolved",
        status="success",
        user_id=int(current_user.id),
        resource_type="sos_event",
        resource_id=int(sos_id),
        ip_address=ip_address,
        user_agent=user_agent,
        details={
            "resolution_status": payload.resolution_status,
            "patient_user_id": int(sos_detail.patient.user_id),
            "is_admin": current_user.role == "admin",
            "has_notes": bool(payload.notes),
        },
    )

    return SuccessResponse(
        success=True,
        message="Đã xác nhận xử lý SOS thành công"
    )
