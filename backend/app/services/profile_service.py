from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.user_model import User
from app.repositories.audit_log_repository import AuditLogRepository
from app.schemas.profile import (
    GENDER_EN_TO_VI,
    DeleteAccountRequest,
    ProfileResponse,
    ProfileUpdateRequest,
)
from app.utils.datetime_helper import get_current_time
from app.utils.password import verify_password


class ProfileService:
    @staticmethod
    def get_profile(user: User) -> ProfileResponse:
        # DB stores canonical English ('male'/'female'/'other'); API surface
        # exposes Vietnamese to keep the mobile UI label-driven.
        gender_label = GENDER_EN_TO_VI.get(user.gender) if user.gender else None
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
            gender=gender_label,
            blood_type=user.blood_type,
            height_cm=user.height_cm,
            weight_kg=user.weight_kg,
            medications=user.medications or [],
            allergies=user.allergies or [],
            medical_conditions=user.medical_conditions or [],
            primary_device_id=user.primary_device_id,
            created_at=user.created_at,
            updated_at=user.updated_at,
        )

    @staticmethod
    def update_profile(
        user: User,
        payload: ProfileUpdateRequest,
        db: Session,
        ip_address: str = "",
        user_agent: str = "",
    ) -> ProfileResponse:
        user.full_name = payload.full_name
        user.phone = payload.phone
        user.date_of_birth = payload.date_of_birth
        user.avatar_url = payload.avatar_url
        user.gender = payload.gender
        user.blood_type = payload.blood_type
        user.height_cm = payload.height_cm
        user.weight_kg = payload.weight_kg
        if payload.medications is not None:
            user.medications = payload.medications
        if payload.allergies is not None:
            user.allergies = payload.allergies
        if payload.medical_conditions is not None:
            user.medical_conditions = payload.medical_conditions
        user.updated_at = get_current_time()
        db.commit()
        db.refresh(user)
        AuditLogRepository.log_action(
            db,
            action="profile.update",
            status="success",
            user_id=user.id,
            resource_type="user",
            resource_id=user.id,
            ip_address=ip_address,
            user_agent=user_agent,
            details={"fields_updated": list(payload.model_fields_set)},
        )
        return ProfileService.get_profile(user)

    @staticmethod
    def delete_account(
        user: User,
        payload: DeleteAccountRequest,
        db: Session,
        ip_address: str = "",
        user_agent: str = "",
    ) -> None:
        if not verify_password(payload.password, user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Mật khẩu không đúng",
            )
        user.deleted_at = get_current_time()
        user.is_active = False
        db.commit()
        AuditLogRepository.log_action(
            db,
            action="profile.delete_account",
            status="success",
            user_id=user.id,
            resource_type="user",
            resource_id=user.id,
            ip_address=ip_address,
            user_agent=user_agent,
            details={"reason": "user_requested"},
        )

    @staticmethod
    def set_primary_device(
        user: User,
        device_id: int | None,
        db: Session,
    ) -> int | None:
        """Phase 3: pin a device as the user's primary data source.

        Passing ``device_id=None`` clears the pointer. Validates that the
        device exists and belongs to the calling user before persisting.
        """
        from app.models.device_model import Device

        if device_id is None:
            user.primary_device_id = None
            user.updated_at = get_current_time()
            db.commit()
            db.refresh(user)
            return None

        device = (
            db.query(Device)
            .filter(Device.id == device_id, Device.deleted_at.is_(None))
            .first()
        )
        if device is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Thiết bị không tồn tại",
            )
        if device.user_id is not None and device.user_id != user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Thiết bị không thuộc về bạn",
            )

        user.primary_device_id = device_id
        user.updated_at = get_current_time()
        db.commit()
        db.refresh(user)
        return device_id
