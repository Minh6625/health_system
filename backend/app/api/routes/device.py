from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.models.user_model import User
from app.schemas.device import (
    DeviceActionResponse,
    DeviceCreateRequest,
    DeviceItemResponse,
    DeviceListResponse,
    DeviceUpdateRequest,
)
from app.services.device_service import DeviceService

router = APIRouter(prefix="/mobile", tags=["mobile-devices"])


@router.get("/devices", response_model=DeviceListResponse)
def get_devices(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    device_type: str | None = Query(default=None),
    active: bool | None = Query(default=None),
    status_filter: str = Query(default="all", alias="status"),
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> DeviceListResponse:
    return DeviceService.get_user_devices(
        user_id=current_user.id,
        db=db,
        device_type=device_type,
        active=active,
        status=status_filter,
        limit=limit,
        offset=offset,
    )


@router.post("/devices", response_model=DeviceItemResponse)
def create_device(
    payload: DeviceCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> DeviceItemResponse:
    try:
        return DeviceService.create_device(
            user_id=current_user.id,
            payload=payload,
            db=db,
        )
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error


@router.patch("/devices/{device_id}", response_model=DeviceItemResponse)
def update_device(
    device_id: int,
    payload: DeviceUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> DeviceItemResponse:
    try:
        device = DeviceService.update_device(
            user_id=current_user.id,
            device_id=device_id,
            payload=payload,
            db=db,
        )
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error
    if device is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Khong tim thay thiet bi",
        )
    return device


@router.delete("/devices/{device_id}", response_model=DeviceActionResponse)
def delete_device(
    device_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> DeviceActionResponse:
    result = DeviceService.delete_device(
        user_id=current_user.id,
        device_id=device_id,
        db=db,
    )
    if not result.success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=result.message,
        )
    return result
