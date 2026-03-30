from fastapi import APIRouter, Depends, Request, HTTPException, status, BackgroundTasks
from fastapi.responses import RedirectResponse
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
    VerifyResetOtpRequest,
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

router = APIRouter(prefix="/auth", tags=["Auth"])


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
    payload: RegisterRequest, 
    request: Request, 
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
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
        background_tasks=background_tasks,
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
        db, payload.email, payload.code, ip_address, user_agent
    )
    
    return AuthResponse(success=success, message=message)


@router.post("/resend-verification", response_model=AuthResponse)
def resend_verification(
    payload: ResendVerificationRequest, 
    request: Request, 
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
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
        db, payload.email.strip(), ip_address, user_agent, background_tasks
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
    payload: ForgotPasswordRequest, 
    request: Request, 
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
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
        db, payload.email.strip(), ip_address, user_agent, background_tasks
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


@router.post("/verify-reset-otp", response_model=AuthResponse)
def verify_reset_otp(
    payload: VerifyResetOtpRequest, request: Request, db: Session = Depends(get_db)
) -> AuthResponse:
    """Verify password reset OTP code without changing the password."""
    ip_address = get_client_ip(request)
    user_agent = get_user_agent(request)

    success, message = AuthService.verify_reset_otp(
        db, payload.email, payload.code, ip_address, user_agent
    )

    return AuthResponse(success=success, message=message)


@router.post("/reset-password", response_model=AuthResponse)
def reset_password(
    payload: ResetPasswordRequest, request: Request, db: Session = Depends(get_db)
) -> AuthResponse:
    """Reset password using reset token."""
    ip_address = get_client_ip(request)
    user_agent = get_user_agent(request)

    success, message = AuthService.reset_password(
        db, payload.email, payload.code, payload.new_password, ip_address, user_agent
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


@router.get("/deep-link-redirect", include_in_schema=False)
def deep_link_redirect(action: str, code: str, email: str):
    """
    Redirect web links (from emails) to the mobile app deep link via HTML/JS.
    Directly using HTTP 302 redirects to custom schemes is often blocked by Chrome/Android.
    """
    from app.core.config import settings
    from fastapi.responses import HTMLResponse
    
    # iOS/Standard custom scheme
    ios_url = f"{settings.MOBILE_DEEP_LINK_SCHEME}://{action}?code={code}&email={email}"
    
    # Android Chrome specific Intent URI (Bypasses security blocks)
    android_intent_url = f"intent://{action}?code={code}&email={email}#Intent;scheme={settings.MOBILE_DEEP_LINK_SCHEME};package=com.example.health_system;end;"
    
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Đang mở Health Guard...</title>
        <style>
            body {{ font-family: -apple-system, system-ui, sans-serif; text-align: center; padding: 40px 20px; background-color: #171a21; color: #c6d4df; }}
            .container {{ max-width: 500px; margin: 0 auto; background-color: #1b2838; padding: 30px; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.3); }}
            h2 {{ color: #ffffff; }}
            .btn {{ display: inline-block; background: linear-gradient(to right, #47bfff 0%, #1a44c2 100%); color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; font-weight: bold; margin-top: 20px; }}
        </style>
    </head>
    <body>
        <div class="container">
            <h2>Đang mở ứng dụng Health Guard...</h2>
            <p>Nếu ứng dụng không tự động mở, vui lòng nhấn vào nút bên dưới:</p>
            <a href="#" id="open-btn" class="btn">Mở Health Guard</a>
        </div>
        <script>
            // Detect platform to set the correct app launch URL
            var isAndroid = /Android/i.test(navigator.userAgent);
            var targetUrl = isAndroid ? "{android_intent_url}" : "{ios_url}";
            
            // Set the fallback button link
            document.getElementById('open-btn').href = targetUrl;
            
            // Try to open the app automatically
            window.onload = function() {{
                setTimeout(function() {{
                    window.location.href = targetUrl;
                }}, 500);
            }};
        </script>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)
