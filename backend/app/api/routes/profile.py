from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.models.user_model import User
from app.schemas.profile import (
    DeleteAccountRequest,
    ProfileResponse,
    ProfileUpdateRequest,
    SetPrimaryDeviceRequest,
    SetPrimaryDeviceResponse,
)
from app.services.profile_service import ProfileService

router = APIRouter(tags=['mobile-profile'])


@router.get('/profile', response_model=ProfileResponse)
def get_profile(current_user: User = Depends(get_current_user)) -> ProfileResponse:
    return ProfileService.get_profile(current_user)


@router.put('/profile', response_model=ProfileResponse)
def update_profile(
    payload: ProfileUpdateRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ProfileResponse:
    ip = request.client.host if request.client else None
    ua = request.headers.get("user-agent", "")
    return ProfileService.update_profile(current_user, payload, db, ip_address=ip, user_agent=ua)


@router.delete('/profile', status_code=204)
def delete_account(
    payload: DeleteAccountRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    ip = request.client.host if request.client else None
    ua = request.headers.get("user-agent", "")
    ProfileService.delete_account(current_user, payload, db, ip_address=ip, user_agent=ua)


@router.patch('/profile/primary-device', response_model=SetPrimaryDeviceResponse)
def set_primary_device(
    payload: SetPrimaryDeviceRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> SetPrimaryDeviceResponse:
    """Phase 3: pin a device as the user's primary data source.

    Only one device per user can be primary. Other paired devices stay
    active in the DB and may still ingest vitals (multi-device is
    first-class), but the dashboard's latest-vitals query filters on
    this pointer to avoid the "latest-of-all" race that mixes sources.
    """
    primary_id = ProfileService.set_primary_device(
        current_user, payload.device_id, db,
    )
    return SetPrimaryDeviceResponse(success=True, primary_device_id=primary_id)
