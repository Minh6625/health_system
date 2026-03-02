from fastapi import APIRouter, Depends, Request, HTTPException, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.schemas.auth import (
    AuthResponse,
    LoginRequest,
    RefreshTokenRequest,
    RegisterRequest,
    UserData,
)
from app.services.auth_service import AuthService
from app.utils.rate_limiter import login_rate_limiter

router = APIRouter(prefix="/auth", tags=["auth"])


def get_client_ip(request: Request) -> str:
    """Extract client IP address from request."""
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def get_user_agent(request: Request) -> str:
    """Extract user agent from request."""
    return request.headers.get("User-Agent", "unknown")


@router.post("/register", response_model=AuthResponse)
def register(
    payload: RegisterRequest, request: Request, db: Session = Depends(get_db)
) -> AuthResponse:
    """Register a new user account."""
    ip_address = get_client_ip(request)
    user_agent = get_user_agent(request)

    success, message, _ = AuthService.register(
        db, payload.email.strip(), payload.password, ip_address, user_agent
    )
    return AuthResponse(success=success, message=message)


@router.post("/login", response_model=AuthResponse)
def login(
    payload: LoginRequest, request: Request, db: Session = Depends(get_db)
) -> AuthResponse:
    """Authenticate user and return access tokens."""
    ip_address = get_client_ip(request)
    user_agent = get_user_agent(request)

    # Check rate limiting
    if login_rate_limiter.is_rate_limited(ip_address):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Quá nhiều lần đăng nhập thất bại. Vui lòng thử lại sau 15 phút.",
        )

    # Process login (chưa record attempt)
    success, message, token_data = AuthService.login(
        db, payload.email.strip(), payload.password, ip_address, user_agent
    )

    # Record attempt chỉ sau khi login thất bại
    if not success:
        login_rate_limiter.record_attempt(ip_address)
    else:
        # Login thành công → reset rate limiter
        login_rate_limiter.reset(ip_address)

    if success and token_data:
        return AuthResponse(
            success=True,
            message=message,
            access_token=token_data["access_token"],
            refresh_token=token_data["refresh_token"],
            user=UserData(**token_data["user"]),
        )
    else:
        return AuthResponse(success=False, message=message)


@router.post("/refresh", response_model=AuthResponse)
def refresh_token(
    payload: RefreshTokenRequest, request: Request, db: Session = Depends(get_db)
) -> AuthResponse:
    """Refresh access token using refresh token."""
    ip_address = get_client_ip(request)
    user_agent = get_user_agent(request)

    success, message, token_data = AuthService.refresh_access_token(
        db, payload.refresh_token, ip_address, user_agent
    )

    if success and token_data:
        return AuthResponse(
            success=True,
            message=message,
            access_token=token_data["access_token"],
            user=UserData(**token_data["user"]),
        )
    else:
        return AuthResponse(success=False, message=message)
