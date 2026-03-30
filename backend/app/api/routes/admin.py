from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.dependencies import require_internal_service
from app.db.database import get_db
from app.services.admin_device_service import AdminDeviceService


router = APIRouter(
    prefix="/admin",
    tags=["admin-internal"],
    dependencies=[Depends(require_internal_service)],
)


class AdminCreateDeviceRequest(BaseModel):
    device_name: str = Field(min_length=1, max_length=100)
    device_type: str = Field(default="smartwatch", max_length=50)
    serial_number: str | None = Field(default=None, max_length=100)
    mqtt_client_id: str | None = Field(default=None, max_length=100)
    model: str | None = Field(default=None, max_length=100)
    user_email: str | None = Field(default=None, max_length=255)
    firmware_version: str | None = Field(default=None, max_length=50)
    mac_address: str | None = Field(default=None, max_length=17)


class AdminAssignRequest(BaseModel):
    user_email: str = Field(min_length=1, max_length=255)


class AdminUpdateRequest(BaseModel):
    device_name: str | None = Field(default=None, min_length=1, max_length=100)
    firmware_version: str | None = Field(default=None, max_length=50)
    battery_level: int | None = None
    signal_strength: int | None = None


class AdminHeartbeatRequest(BaseModel):
    battery_level: int | None = None
    signal_strength: int | None = None


def _find_user_or_404(*, email: str, db: Session) -> Any:
    user = AdminDeviceService.find_user_by_email(email, db)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Không tìm thấy user: {email}",
        )
    return user


@router.get("/devices")
def list_devices(
    user_id: int | None = Query(default=None),
    skip: int = Query(default=0, ge=0),
    limit: int = Query(default=200, ge=1, le=500),
    db: Session = Depends(get_db),
) -> list[dict[str, Any]]:
    return AdminDeviceService.list_all_devices(
        db,
        skip=skip,
        limit=limit,
        user_id=user_id,
    )


@router.post("/devices", status_code=status.HTTP_201_CREATED)
def create_device(
    payload: AdminCreateDeviceRequest,
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    user = None
    if payload.user_email:
        user = _find_user_or_404(email=payload.user_email, db=db)
        if not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"User {payload.user_email} bị vô hiệu hóa",
            )

    try:
        result = AdminDeviceService.create_device(
            db,
            device_name=payload.device_name,
            device_type=payload.device_type,
            serial_number=payload.serial_number,
            mqtt_client_id=payload.mqtt_client_id,
            model=payload.model,
            user_id=user.id if user is not None else None,
            firmware_version=payload.firmware_version,
            mac_address=payload.mac_address,
        )
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error

    message = "Tạo device thành công"
    if user is not None:
        message = f"Tạo device và bind với {user.email} thành công"

    return {
        **result,
        "message": message,
    }


@router.patch("/devices/{device_id}")
def update_device(
    device_id: int,
    payload: AdminUpdateRequest,
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    try:
        result = AdminDeviceService.update_device(
            device_id,
            db,
            device_name=payload.device_name,
            firmware_version=payload.firmware_version,
            battery_level=payload.battery_level,
            signal_strength=payload.signal_strength,
        )
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error

    if result is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device {device_id} không tồn tại",
        )

    return {
        **result,
        "message": "Device đã được cập nhật",
    }


@router.delete("/devices/{device_id}")
def delete_device(
    device_id: int,
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    deleted = AdminDeviceService.delete_device(device_id, db)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device {device_id} không tồn tại",
        )

    return {
        "success": True,
        "message": "Device đã được xóa mềm",
    }


@router.post("/devices/{device_id}/assign")
def assign_device(
    device_id: int,
    payload: AdminAssignRequest,
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    user = _find_user_or_404(email=payload.user_email, db=db)
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"User {payload.user_email} bị vô hiệu hóa",
        )

    try:
        result = AdminDeviceService.assign_device(device_id, user.id, db)
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error

    if result is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device {device_id} không tồn tại",
        )

    return {
        **result,
        "user_email": user.email,
        "message": f"Bind thành công với {user.email}",
    }


@router.post("/devices/{device_id}/activate")
def activate_device(
    device_id: int,
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    try:
        result = AdminDeviceService.activate_device(device_id, db)
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error

    if result is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device {device_id} không tồn tại",
        )

    return {
        **result,
        "message": "Device đã được kích hoạt",
    }


@router.post("/devices/{device_id}/deactivate")
def deactivate_device(
    device_id: int,
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    result = AdminDeviceService.deactivate_device(device_id, db)
    if result is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device {device_id} không tồn tại",
        )

    return {
        **result,
        "message": "Device đã được vô hiệu hóa",
    }


@router.post("/devices/{device_id}/heartbeat")
def update_heartbeat(
    device_id: int,
    payload: AdminHeartbeatRequest,
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    AdminDeviceService.update_heartbeat(
        device_id,
        db,
        battery_level=payload.battery_level,
        signal_strength=payload.signal_strength,
    )

    result = AdminDeviceService._fetch_device(device_id, db)
    if result is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device {device_id} không tồn tại",
        )

    return {
        **result,
        "message": "Heartbeat đã được cập nhật",
    }


@router.get("/users/search")
def search_user(
    email: str = Query(..., min_length=1),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    user = _find_user_or_404(email=email, db=db)
    return {
        "id": user.id,
        "email": user.email,
        "full_name": user.full_name,
        "is_active": user.is_active,
    }
