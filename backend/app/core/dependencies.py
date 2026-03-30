from fastapi import Depends, HTTPException, status, Header
from fastapi.security import HTTPBearer
from fastapi.security.http import HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from typing import Optional

from app.db.database import get_db
from app.models.user_model import User
from app.repositories.user_repository import UserRepository
from app.utils.jwt import decode_token


security = HTTPBearer()
optional_security = HTTPBearer(auto_error=False)


def _resolve_user_from_credentials(
    credentials: HTTPAuthorizationCredentials,
    db: Session,
) -> User:
    token = credentials.credentials

    payload = decode_token(token)

    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token không hợp lệ hoặc đã hết hạn",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Access tokens don't have "type" field, refresh tokens have type="refresh"
    if payload.get("type") == "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Không thể sử dụng refresh token cho endpoint này",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user_id = payload.get("user_id")

    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token không hợp lệ",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user = UserRepository.get_by_id(db, user_id)

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User không tồn tại",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tài khoản đã bị khóa",
        )

    return user


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
) -> User:
    """
    Dependency to get current authenticated user from JWT token.
    
    Args:
        credentials: Bearer token from Authorization header
        db: Database session
    
    Returns:
        User object
    
    Raises:
        HTTPException: If token is invalid or user not found
    """
    return _resolve_user_from_credentials(credentials, db)


def get_optional_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(optional_security),
    db: Session = Depends(get_db),
) -> User | None:
    if credentials is None:
        return None
    return _resolve_user_from_credentials(credentials, db)


def get_target_profile_id(
    x_target_profile_id: Optional[int] = Header(None, alias="X-Target-Profile-Id"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> int:
    """
    Dependency to resolve the target profile ID to fetch data for.
    If X-Target-Profile-Id is not provided, defaults to current_user.id.
    If provided, it checks if current_user has an accepted relationship allowing vitals viewing.
    """
    if not x_target_profile_id or x_target_profile_id == current_user.id:
        return current_user.id
        
    from app.models.relationship_model import UserRelationship
    relationship = db.query(UserRelationship).filter(
        UserRelationship.patient_id == x_target_profile_id,
        UserRelationship.caregiver_id == current_user.id,
        UserRelationship.status == "accepted",
        UserRelationship.can_view_vitals == True
    ).first()
    
    if not relationship:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Không có quyền xem dữ liệu của người dùng này"
        )
        
    return x_target_profile_id


def require_internal_service(
    x_internal_service: str | None = Header(default=None, alias="X-Internal-Service")
) -> None:
    if x_internal_service != "iot-simulator":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Endpoint này chỉ dành cho IoT Simulator internal service",
        )
