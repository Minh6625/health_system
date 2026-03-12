from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.models.user_model import User
from app.schemas.profile import DeleteAccountRequest, ProfileResponse, ProfileUpdateRequest
from app.services.profile_service import ProfileService

router = APIRouter(prefix='/mobile', tags=['mobile-profile'])


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
    ip = request.client.host if request.client else ""
    ua = request.headers.get("user-agent", "")
    return ProfileService.update_profile(current_user, payload, db, ip_address=ip, user_agent=ua)


@router.delete('/profile', status_code=204)
def delete_account(
    payload: DeleteAccountRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    ip = request.client.host if request.client else ""
    ua = request.headers.get("user-agent", "")
    ProfileService.delete_account(current_user, payload, db, ip_address=ip, user_agent=ua)
