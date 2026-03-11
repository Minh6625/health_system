from sqlalchemy.orm import Session

from app.models.user_model import User
from app.schemas.profile import ProfileResponse, ProfileUpdateRequest
from app.utils.datetime_helper import get_current_time


class ProfileService:
    @staticmethod
    def get_profile(user: User) -> ProfileResponse:
        return ProfileResponse(
            user_id=user.id,
            email=user.email,
            full_name=user.full_name,
            role=user.role,
            phone=user.phone,
            date_of_birth=user.date_of_birth,
            is_active=user.is_active,
            is_verified=user.is_verified,
            avatar_url=user.avatar_url,
            created_at=user.created_at,
            updated_at=user.updated_at,
        )

    @staticmethod
    def update_profile(
        user: User,
        payload: ProfileUpdateRequest,
        db: Session,
    ) -> ProfileResponse:
        user.full_name = payload.full_name
        user.phone = payload.phone
        user.date_of_birth = payload.date_of_birth
        user.avatar_url = payload.avatar_url
        user.updated_at = get_current_time()
        db.commit()
        db.refresh(user)
        return ProfileService.get_profile(user)
