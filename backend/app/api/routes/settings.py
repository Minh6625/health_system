from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.models.user_model import User
from app.schemas.general_settings import (
    GeneralSettingsResponse,
    GeneralSettingsUpdateRequest,
)
from app.services.settings_service import SettingsService

router = APIRouter(prefix="/settings", tags=["mobile-settings"])


@router.get("/general", response_model=GeneralSettingsResponse)
def get_general_settings(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> GeneralSettingsResponse:
    _ = current_user
    settings_data = SettingsService.get_general_settings(db)
    return GeneralSettingsResponse(**settings_data)


@router.put("/general", response_model=GeneralSettingsResponse)
def update_general_settings(
    payload: GeneralSettingsUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> GeneralSettingsResponse:
    if payload.maintenance_mode is not None and getattr(current_user, "role", None) != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Chỉ admin mới có thể bật/tắt chế độ bảo trì",
        )
    updated = SettingsService.update_general_settings(
        db,
        user_id=current_user.id,
        language=payload.language,
        theme=payload.theme,
        timezone=payload.timezone,
        push_notifications_enabled=payload.push_notifications_enabled,
        maintenance_mode=payload.maintenance_mode,
        session_timeout_minutes=payload.session_timeout_minutes,
    )
    return GeneralSettingsResponse(**updated)
