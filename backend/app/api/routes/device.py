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
    DeviceScanPairRequest,
    DeviceScanPairResponse,
    DeviceSettingsRequest,
    DeviceSettingsResponse,
)
from app.services.device_service import DeviceService

router = APIRouter(tags=["mobile-devices"])


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


@router.get("/devices/{device_id}", response_model=DeviceItemResponse)
def get_device(
    device_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> DeviceItemResponse:
    """
    Get single device by ID - for DEVICE_StatusDetail screen.
    Returns device details only if it belongs to the current user.
    """
    device = DeviceService.get_device_by_id(
        user_id=current_user.id,
        device_id=device_id,
        db=db,
    )
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Thiết bị không tìm thấy",
        )
    return device


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
        # [HS-002] Cross-user duplicate -> 409 Conflict (per BR-040-01).
        # Same-user duplicate or other validation errors -> 400 Bad Request.
        message = str(error)
        if "tai khoan khac" in message:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=message,
            ) from error
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message,
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


@router.post("/devices/scan/pair", response_model=DeviceScanPairResponse)
def scan_and_pair_device(
    payload: DeviceScanPairRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> DeviceScanPairResponse:
    """
    BLE Scan & Pair endpoint - for DEVICE_Connect screen.
    Creates a new device record after successful pairing.
    """
    try:
        device = DeviceService.pair_new_device(
            user_id=current_user.id,
            mac_address=payload.mac_address,
            device_name=payload.device_name,
            device_type=payload.device_type,
            model=payload.model,
            db=db,
        )
        return DeviceScanPairResponse(
            success=True,
            message="Ghép nối thiết bị thành công",
            device=device,
        )
    except ValueError as e:
        # [HS-002] Cross-user duplicate -> 409 Conflict (per BR-040-01).
        # Same-user duplicate or other validation errors -> 400 Bad Request.
        message = str(e)
        if "tai khoan khac" in message:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=message,
            ) from e
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message,
        ) from e


@router.put("/devices/{device_id}/settings", response_model=DeviceSettingsResponse)
def update_device_settings(
    device_id: int,
    payload: DeviceSettingsRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> DeviceSettingsResponse:
    """
    Update device settings and calibration - for DEVICE_Configure screen.
    Updates notification preferences and sensor calibration parameters.
    """
    try:
        calibration = DeviceService.update_device_settings(
            user_id=current_user.id,
            device_id=device_id,
            settings=payload,
            db=db,
        )
        return DeviceSettingsResponse(
            success=True,
            message="Cập nhật cấu hình thành công",
            calibration_data=calibration,
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        ) from e
    except PermissionError as e:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=str(e),
        ) from e
