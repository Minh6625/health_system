from fastapi import APIRouter, Depends, Request, HTTPException, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.models.user_model import User
from app.schemas.auth import (
    AuthResponse,
    LoginRequest,
    RefreshTokenRequest,
    RegisterRequest,
    VerifyEmailRequest,
    ResendVerificationRequest,
    ForgotPasswordRequest,
    ResetPasswordRequest,
    ChangePasswordRequest,
    UserData,
)
from app.services.auth_service import AuthService
from app.utils.rate_limiter import (
    login_rate_limiter,
    register_rate_limiter,
    forgot_password_rate_limiter,
    change_password_rate_limiter,
    resend_verification_rate_limiter,
)
from app.core.dependencies import get_current_user

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
    """Register a new user account with role support."""
    ip_address = get_client_ip(request)
    user_agent = get_user_agent(request)

    # Check rate limiting (5 attempts per hour per IP)
    if register_rate_limiter.is_rate_limited(ip_address):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Quá nhiều yêu cầu đăng ký. Vui lòng thử lại sau 1 giờ.",
        )

    success, message, token_data = AuthService.register(
        db,
        payload.email.strip(),
        payload.full_name,
        payload.password,
        role=payload.role,
        date_of_birth=payload.date_of_birth,
        phone=payload.phone,
        ip_address=ip_address,
        user_agent=user_agent,
    )
    
    # Record attempt for rate limiting
    register_rate_limiter.record_attempt(ip_address)
    
    if success and token_data:
        user_obj = token_data.get("user")
        user_data = UserData(
            user_id=user_obj.id,
            email=user_obj.email,
            full_name=user_obj.full_name,
            role=user_obj.role,
        ) if user_obj else None
        
        return AuthResponse(
            success=True,
            message=message,
            verification_token=token_data.get("verification_token"),
            user=user_data,
        )
    else:
        return AuthResponse(success=False, message=message)


@router.post("/verify-email", response_model=AuthResponse)
def verify_email(
    payload: VerifyEmailRequest, request: Request, db: Session = Depends(get_db)
) -> AuthResponse:
    """Verify user email using verification token."""
    ip_address = get_client_ip(request)
    user_agent = get_user_agent(request)

    success, message = AuthService.verify_email(
        db, payload.verification_token, ip_address, user_agent
    )
    
    return AuthResponse(success=success, message=message)


@router.post("/resend-verification", response_model=AuthResponse)
def resend_verification(
    payload: ResendVerificationRequest, request: Request, db: Session = Depends(get_db)
) -> AuthResponse:
    """Resend email verification token to user."""
    ip_address = get_client_ip(request)
    user_agent = get_user_agent(request)

    # Check rate limiting (3 attempts per 15 minutes)
    identifier = f"resend_{payload.email.strip()}"
    if resend_verification_rate_limiter.is_rate_limited(identifier):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Quá nhiều yêu cầu. Vui lòng thử lại sau 15 phút.",
        )

    success, message, token_data = AuthService.resend_verification_email(
        db, payload.email.strip(), ip_address, user_agent
    )

    # Always record attempt for rate limiting
    resend_verification_rate_limiter.record_attempt(identifier)

    if success:
        return AuthResponse(
            success=True,
            message=message,
            verification_token=token_data.get("verification_token") if token_data else None
        )
    else:
        return AuthResponse(success=False, message=message)


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


@router.post("/forgot-password", response_model=AuthResponse)
def forgot_password(
    payload: ForgotPasswordRequest, request: Request, db: Session = Depends(get_db)
) -> AuthResponse:
    """Request password reset token."""
    ip_address = get_client_ip(request)
    user_agent = get_user_agent(request)

    # Check rate limiting (3 attempts per 15 minutes)
    if forgot_password_rate_limiter.is_rate_limited(ip_address):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Quá nhiều yêu cầu. Vui lòng thử lại sau 15 phút.",
        )

    success, message, token_data = AuthService.forgot_password(
        db, payload.email.strip(), ip_address, user_agent
    )

    # Always record attempt for rate limiting
    forgot_password_rate_limiter.record_attempt(ip_address)

    # Return success response even if email doesn't exist (prevent enumeration)
    if success:
        return AuthResponse(
            success=True,
            message=message,
        )
    else:
        return AuthResponse(success=False, message=message)


@router.post("/reset-password", response_model=AuthResponse)
def reset_password(
    payload: ResetPasswordRequest, request: Request, db: Session = Depends(get_db)
) -> AuthResponse:
    """Reset password using reset token."""
    ip_address = get_client_ip(request)
    user_agent = get_user_agent(request)

    success, message = AuthService.reset_password(
        db, payload.reset_token, payload.new_password, ip_address, user_agent
    )

    return AuthResponse(success=success, message=message)


@router.post("/change-password", response_model=AuthResponse)
def change_password(
    payload: ChangePasswordRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> AuthResponse:
    """Change password for authenticated user."""
    ip_address = get_client_ip(request)
    user_agent = get_user_agent(request)

    # Check rate limiting (5 attempts per 15 minutes)
    identifier = f"change_pwd_{current_user.id}"
    if change_password_rate_limiter.is_rate_limited(identifier):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Quá nhiều yêu cầu. Vui lòng thử lại sau 15 phút.",
        )

    success, message = AuthService.change_password(
        db,
        current_user.id,
        payload.current_password,
        payload.new_password,
        ip_address,
        user_agent,
    )

    if not success:
        change_password_rate_limiter.record_attempt(identifier)
    else:
        change_password_rate_limiter.reset(identifier)

    return AuthResponse(success=success, message=message)
