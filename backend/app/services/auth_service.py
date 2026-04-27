import re
import secrets

from app.utils.age_validator import validate_age as _validate_age
from typing import Optional
import logging
from datetime import date, datetime, timedelta, timezone

from fastapi import BackgroundTasks
from sqlalchemy.orm import Session

from app.models.user_model import User
from app.repositories.audit_log_repository import AuditLogRepository
from app.repositories.user_repository import UserRepository
from app.utils.jwt import (
    create_access_token,
    create_refresh_token,
    decode_token,
)
from app.utils.datetime_helper import get_current_time
from app.utils.email_service import EmailService
from app.utils.password import validate_password_strength

logger = logging.getLogger(__name__)


class AuthService:
    email_pattern = re.compile(r"^[^@]+@[^@]+\.[^@]+$")

    @staticmethod
    def _generate_pin_code() -> str:
        """Generate cryptographically secure 6-digit PIN (100000-999999)."""
        return str(secrets.randbelow(900000) + 100000)

    # ``validate_age`` lives in ``app.utils.age_validator`` so the
    # ProfileUpdateRequest schema can reuse it without importing the
    # whole service layer. Kept here as a passthrough for backward
    # compatibility with existing call sites and tests.
    @staticmethod
    def validate_age(date_of_birth: Optional[date]) -> tuple[bool, str]:
        return _validate_age(date_of_birth)

    @classmethod
    def register(
        cls,
        db: Session,
        email: str,
        full_name: str,
        password: str,
        role: str = "user",
        date_of_birth: Optional[date] = None,
        phone: Optional[str] = None,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
        background_tasks: Optional[BackgroundTasks] = None,
    ) -> tuple[bool, str, Optional[dict]]:
        """
        Register new user with role support and strong password validation.
        
        Args:
            db: Database session
            email: User email
            full_name: User full name
            password: User password (must meet strength requirements)
            role: User role (user or admin, default: user)
            date_of_birth: User date of birth (YYYY-MM-DD), optional
            phone: User phone number (10-15 digits), optional
            ip_address: Client IP address
            user_agent: Client user agent
        
        Returns:
            (success, message, token_data) tuple
            where token_data = {"verification_code": str, "user": User} or None on failure
        """
        email = email.strip()
        full_name = full_name.strip()

        # Validate email format
        if not cls.email_pattern.match(email):
            AuditLogRepository.log_action(
                db,
                action="user.register",
                status="failure",
                ip_address=ip_address,
                user_agent=user_agent,
                details={"email": email, "reason": "Invalid email format"},
            )
            return False, "Email không hợp lệ", None

        # Validate full_name format (only letters, Vietnamese diacritics, and spaces)
        full_name_pattern = re.compile(r"^[a-zA-ZÀ-ỿ\s]+$")
        if not full_name_pattern.match(full_name):
            AuditLogRepository.log_action(
                db,
                action="user.register",
                status="failure",
                ip_address=ip_address,
                user_agent=user_agent,
                details={"email": email, "reason": "Invalid full_name format (contains numbers or special characters)"},
            )
            return False, "Họ tên chỉ được chứa chữ cái và khoảng trắng. Không được phép dùng số hoặc ký tự đặc biệt", None

        # Validate password strength
        is_strong, strength_message = validate_password_strength(password)
        if not is_strong:
            AuditLogRepository.log_action(
                db,
                action="user.register",
                status="failure",
                ip_address=ip_address,
                user_agent=user_agent,
                details={"email": email, "reason": f"Password validation failed: {strength_message}"},
            )
            return False, strength_message, None

        # Validate date of birth and age
        is_valid_age, age_message = cls.validate_age(date_of_birth)
        if not is_valid_age:
            AuditLogRepository.log_action(
                db,
                action="user.register",
                status="failure",
                ip_address=ip_address,
                user_agent=user_agent,
                details={"email": email, "reason": f"Age validation failed: {age_message}"},
            )
            return False, age_message, None

        # Validate role
        if role not in ["user", "admin"]:
            role = "user"

        # Check if email already exists
        existing_user = UserRepository.get_by_email(db, email)
        if existing_user:
            if existing_user.is_verified:
                AuditLogRepository.log_action(
                    db,
                    action="user.register",
                    status="failure",
                    ip_address=ip_address,
                    user_agent=user_agent,
                    details={"email": email, "reason": "Email already exists and is verified"},
                )
                return False, "Email đã tồn tại", None
            else:
                # User exists but is not verified, allow them to re-register
                # Update their information with the new data
                try:
                    from app.utils.password import hash_password
                    existing_user.hashed_password = hash_password(password)
                    existing_user.full_name = full_name.strip()
                    existing_user.role = role
                    existing_user.date_of_birth = date_of_birth
                    existing_user.phone = phone
                    existing_user.updated_at = get_current_time()

                    # Generate email verification PIN code
                    verification_code = cls._generate_pin_code()
                    existing_user.verification_code = verification_code
                    existing_user.verification_code_expires_at = get_current_time() + timedelta(hours=24)
                    db.commit()

                    # Send verification email
                    if background_tasks:
                        background_tasks.add_task(EmailService.send_verification_email, email, verification_code)
                        email_sent = True
                    else:
                        email_sent = EmailService.send_verification_email(email, verification_code)

                    AuditLogRepository.log_action(
                        db,
                        action="user.register",
                        status="success",
                        user_id=existing_user.id,
                        resource_type="user",
                        resource_id=existing_user.id,
                        ip_address=ip_address,
                        user_agent=user_agent,
                        details={"email": email, "role": role, "email_sent": email_sent, "note": "Re-registration of unverified account"},
                    )

                    return True, "Đăng ký thành công. Vui lòng kiểm tra email để lấy mã xác thực.", {
                        "verification_code": verification_code,  # ONLY FOR DEV/TESTING
                        "user": existing_user,
                    }
                except Exception as e:
                    logger.error(f"Re-register error for {email}: {str(e)}")
                    return False, "Đã xảy ra lỗi khi cập nhật tài khoản đăng ký. Vui lòng thử lại.", None

        try:
            # Create new user
            user = UserRepository.create_user(
                db,
                email,
                password,
                full_name=full_name.strip(),
                role=role,
                date_of_birth=date_of_birth,
                phone=phone,
            )

            # Generate email verification PIN code
            verification_code = cls._generate_pin_code()
            user.verification_code = verification_code
            user.verification_code_expires_at = get_current_time() + timedelta(hours=24)
            db.commit()

            # Send verification email
            if background_tasks:
                background_tasks.add_task(EmailService.send_verification_email, email, verification_code)
                email_sent = True
            else:
                email_sent = EmailService.send_verification_email(email, verification_code)

            AuditLogRepository.log_action(
                db,
                action="user.register",
                status="success",
                user_id=user.id,
                resource_type="user",
                resource_id=user.id,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"email": email, "role": role, "email_sent": email_sent},
            )

            return True, "Đăng ký thành công. Vui lòng kiểm tra email để lấy mã xác thực.", {
                "verification_code": verification_code,  # ONLY FOR DEV/TESTING
                "user": user,
            }
        except Exception as e:
            logger.error(f"Register error for {email}: {str(e)}")
            AuditLogRepository.log_action(
                db,
                action="user.register",
                status="error",
                ip_address=ip_address,
                user_agent=user_agent,
                details={"email": email, "error": type(e).__name__},
            )
            # Return generic error message (don't leak details)
            return False, "Đã xảy ra lỗi. Vui lòng thử lại sau.", None

    @classmethod
    def login(
        cls,
        db: Session,
        email: str,
        password: str,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> tuple[bool, str, Optional[dict]]:
        """
        Authenticate user and return tokens.
        
        Returns:
            (success, message, token_data)
            where token_data = {"access_token": str, "refresh_token": str, "user": dict}
        """
        email = email.strip()
        if not cls.email_pattern.match(email):
            AuditLogRepository.log_action(
                db,
                action="user.login",
                status="failure",
                ip_address=ip_address,
                user_agent=user_agent,
                details={"email": email, "reason": "Invalid email format"},
            )
            return False, "Email không hợp lệ", None

        try:
            user = UserRepository.verify_login(db, email, password)
            
            if not user:
                AuditLogRepository.log_action(
                    db,
                    action="user.login",
                    status="failure",
                    ip_address=ip_address,
                    user_agent=user_agent,
                    details={"email": email, "reason": "Wrong email or password"},
                )
                return False, "Sai email hoặc mật khẩu", None
            
            # Check if account is active
            if not user.is_active:
                AuditLogRepository.log_action(
                    db,
                    action="user.login",
                    status="failure",
                    user_id=user.id,
                    resource_type="user",
                    resource_id=user.id,
                    ip_address=ip_address,
                    user_agent=user_agent,
                    details={"email": email, "reason": "Account locked/inactive"},
                )
                return False, "Tài khoản đã bị khóa", None
            
            # Check if email is verified
            if not user.is_verified:
                AuditLogRepository.log_action(
                    db,
                    action="user.login",
                    status="failure",
                    user_id=user.id,
                    resource_type="user",
                    resource_id=user.id,
                    ip_address=ip_address,
                    user_agent=user_agent,
                    details={"email": email, "reason": "Email not verified"},
                )
                return False, "Vui lòng xác thực email trước khi đăng nhập", None
            
            # Update last login timestamp
            UserRepository.update_last_login(db, user.id)
            
            # Generate tokens
            access_token = create_access_token(
                data={
                    "user_id": user.id,
                    "email": user.email,
                    "role": user.role,
                }
            )
            
            refresh_token = create_refresh_token(data={"user_id": user.id})
            
            # Log successful login
            AuditLogRepository.log_action(
                db,
                action="user.login",
                status="success",
                user_id=user.id,
                resource_type="user",
                resource_id=user.id,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"email": email},
            )
            
            token_data = {
                "access_token": access_token,
                "refresh_token": refresh_token,
                "user": {
                    "user_id": user.id,
                    "email": user.email,
                    "full_name": user.full_name,
                    "role": user.role,
                },
            }
            
            return True, "Đăng nhập thành công", token_data
            
        except Exception as e:
            logger.error(f"Login error for {email}: {str(e)}")
            AuditLogRepository.log_action(
                db,
                action="user.login",
                status="error",
                ip_address=ip_address,
                user_agent=user_agent,
                details={"email": email, "error": type(e).__name__},
            )
            # Return generic error message (don't leak details)
            return False, "Đã xảy ra lỗi. Vui lòng thử lại sau.", None

    @classmethod
    def refresh_access_token(
        cls,
        db: Session,
        refresh_token: str,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> tuple[bool, str, Optional[dict]]:
        """
        Generate new access token from refresh token.
        
        Returns:
            (success, message, token_data)
        """
        payload = decode_token(refresh_token)
        
        if not payload or payload.get("type") != "refresh":
            AuditLogRepository.log_action(
                db,
                action="token.refresh",
                status="failure",
                ip_address=ip_address,
                user_agent=user_agent,
                details={"reason": "Invalid refresh token"},
            )
            return False, "Refresh token không hợp lệ", None
        
        user_id = payload.get("user_id")
        user = UserRepository.get_by_id(db, user_id)
        
        if not user:
            AuditLogRepository.log_action(
                db,
                action="token.refresh",
                status="failure",
                user_id=user_id,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"reason": "User not found"},
            )
            return False, "User không tồn tại", None
        
        if not user.is_active:
            AuditLogRepository.log_action(
                db,
                action="token.refresh",
                status="failure",
                user_id=user_id,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"reason": "Account inactive"},
            )
            return False, "Tài khoản đã bị khóa", None
        
        # Generate new access token
        access_token = create_access_token(
            data={
                "user_id": user.id,
                "email": user.email,
                "role": user.role,
            }
        )
        
        AuditLogRepository.log_action(
            db,
            action="token.refresh",
            status="success",
            user_id=user.id,
            ip_address=ip_address,
            user_agent=user_agent,
        )
        
        token_data = {
            "access_token": access_token,
            "user": {
                "user_id": user.id,
                "email": user.email,
                "full_name": user.full_name,
                "role": user.role,
            },
        }
        
        return True, "Token đã được làm mới", token_data
    @classmethod
    def verify_email(
        cls,
        db: Session,
        email: str,
        code: str,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> tuple[bool, str]:
        """
        Verify user email using 6-digit PIN code.
        
        Returns:
            (success, message)
        """
        email = email.strip().lower()
        user = UserRepository.get_by_email(db, email)
        
        if not user:
            AuditLogRepository.log_action(
                db,
                action="user.email_verify",
                status="failure",
                ip_address=ip_address,
                user_agent=user_agent,
                details={"reason": "User not found", "email": email},
            )
            return False, "Email không tồn tại"
        
        if user.is_verified:
            AuditLogRepository.log_action(
                db,
                action="user.email_verify",
                status="success",
                user_id=user.id,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"email": email, "note": "Already verified"},
            )
            return True, "Email đã được xác thực"
            
        if not user.verification_code:
            AuditLogRepository.log_action(
                db,
                action="user.email_verify",
                status="failure",
                user_id=user.id,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"reason": "No verification code set"},
            )
            return False, "Không tìm thấy yêu cầu xác thực email. Vui lòng yêu cầu gửi lại mã."
            
        # Constant-time comparison to prevent timing attacks
        if not secrets.compare_digest(user.verification_code, code):
            AuditLogRepository.log_action(
                db,
                action="user.email_verify",
                status="failure",
                user_id=user.id,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"reason": "Invalid code"},
            )
            return False, "Mã xác thực không đúng"
            
        # Check expiry
        if not user.verification_code_expires_at or user.verification_code_expires_at < get_current_time():
            AuditLogRepository.log_action(
                db,
                action="user.email_verify",
                status="failure",
                user_id=user.id,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"reason": "Code expired"},
            )
            return False, "Mã xác thực đã hết hạn. Vui lòng yêu cầu gửi lại mã."
        
        try:
            # Mark as verified and clear the code
            user.is_verified = True
            user.verification_code = None
            user.verification_code_expires_at = None
            user.updated_at = get_current_time()
            db.commit()
            
            AuditLogRepository.log_action(
                db,
                action="user.email_verify",
                status="success",
                user_id=user.id,
                resource_type="user",
                resource_id=user.id,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"email": email},
            )
            return True, "Xác thực email thành công"
                
        except Exception as e:
            AuditLogRepository.log_action(
                db,
                action="user.email_verify",
                status="error",
                user_id=user.id,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"email": email, "error": str(e)},
            )
            return False, f"Lỗi server: {str(e)}"

    @classmethod
    def resend_verification_email(
        cls,
        db: Session,
        email: str,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
        background_tasks: Optional[BackgroundTasks] = None,
    ) -> tuple[bool, str, Optional[dict]]:
        """
        Resend email verification token to user.
        
        Returns:
            (success, message, token_data)
            where token_data = {"verification_token": str} or None
        """
        email = email.strip()
        if not cls.email_pattern.match(email):
            AuditLogRepository.log_action(
                db,
                action="user.resend_verification",
                status="failure",
                ip_address=ip_address,
                user_agent=user_agent,
                details={"email": email, "reason": "Invalid email format"},
            )
            return False, "Email không hợp lệ", None
        
        user = UserRepository.get_by_email(db, email)
        
        if not user:
            # Return success to prevent email enumeration
            AuditLogRepository.log_action(
                db,
                action="user.resend_verification",
                status="success",
                ip_address=ip_address,
                user_agent=user_agent,
                details={"email": email, "note": "User not found but returned success"},
            )
            return True, "Nếu email tồn tại và chưa xác thực, bạn sẽ nhận được email xác thực", None
        
        # Check if already verified
        if user.is_verified:
            AuditLogRepository.log_action(
                db,
                action="user.resend_verification",
                status="failure",
                user_id=user.id,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"email": email, "reason": "Already verified"},
            )
            return False, "Email đã được xác thực. Bạn có thể đăng nhập ngay", None
        
        try:
            # Generate new verification PIN code
            verification_code = cls._generate_pin_code()
            user.verification_code = verification_code
            user.verification_code_expires_at = get_current_time() + timedelta(hours=24)
            db.commit()
            
            # Send verification email
            if background_tasks:
                background_tasks.add_task(EmailService.send_verification_email, email, verification_code)
                email_sent = True
            else:
                email_sent = EmailService.send_verification_email(email, verification_code)
            
            AuditLogRepository.log_action(
                db,
                action="user.resend_verification",
                status="success",
                user_id=user.id,
                resource_type="user",
                resource_id=user.id,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"email": email, "email_sent": email_sent},
            )
            
            return True, "Mã xác thực mới đã được gửi. Vui lòng kiểm tra hộp thư", {
                "verification_code": verification_code  # ONLY FOR DEV/TESTING
            }
        except Exception as e:
            AuditLogRepository.log_action(
                db,
                action="user.resend_verification",
                status="error",
                user_id=user.id if user else None,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"email": email, "error": str(e)},
            )
            return False, f"Lỗi server: {str(e)}", None

    @classmethod
    def forgot_password(
        cls,
        db: Session,
        email: str,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
        background_tasks: Optional[BackgroundTasks] = None,
    ) -> tuple[bool, str, Optional[dict]]:
        """
        Generate password reset PIN code and send email.
        
        Returns:
            (success, message, token_data)
            where token_data = {"reset_code": str} or None
        """
        email = email.strip()
        if not cls.email_pattern.match(email):
            AuditLogRepository.log_action(
                db,
                action="user.forgot_password",
                status="failure",
                ip_address=ip_address,
                user_agent=user_agent,
                details={"email": email, "reason": "Invalid email format"},
            )
            return False, "Email không hợp lệ", None
        
        user = UserRepository.get_by_email(db, email)
        
        # Always return success message to prevent email enumeration
        # But only send email if user exists
        if not user:
            AuditLogRepository.log_action(
                db,
                action="user.forgot_password",
                status="success",
                ip_address=ip_address,
                user_agent=user_agent,
                details={"email": email, "note": "User not found but returned success"},
            )
            return True, "Nếu email tồn tại, bạn sẽ nhận được email chứa mã đặt lại mật khẩu", None
        
        try:
            # Generate reset PIN code
            reset_code = cls._generate_pin_code()
            user.reset_code = reset_code
            user.reset_code_expires_at = get_current_time() + timedelta(minutes=15)
            db.commit()
            
            # Send reset email
            if background_tasks:
                background_tasks.add_task(EmailService.send_password_reset_email, email, reset_code)
                email_sent = True
            else:
                email_sent = EmailService.send_password_reset_email(email, reset_code)
            
            AuditLogRepository.log_action(
                db,
                action="user.forgot_password",
                status="success",
                user_id=user.id,
                resource_type="user",
                resource_id=user.id,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"email": email, "email_sent": email_sent},
            )
            
            return True, "Nếu email tồn tại, bạn sẽ nhận được email chứa mã đặt lại mật khẩu", {
                "reset_code": reset_code  # ONLY FOR DEV/TESTING
            }
        except Exception as e:
            AuditLogRepository.log_action(
                db,
                action="user.forgot_password",
                status="error",
                user_id=user.id if user else None,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"email": email, "error": str(e)},
            )
            return False, f"Lỗi server: {str(e)}", None

    @classmethod
    def verify_reset_otp(
        cls,
        db: Session,
        email: str,
        code: str,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> tuple[bool, str]:
        """
        Verify password reset OTP code WITHOUT changing the password.
        Used by the frontend to validate the OTP before showing the new-password form.
        The reset_code is intentionally preserved so reset_password() can still use it.

        Returns:
            (success, message)
        """
        email = email.strip().lower()
        user = UserRepository.get_by_email(db, email)

        if not user:
            AuditLogRepository.log_action(
                db,
                action="user.verify_reset_otp",
                status="failure",
                ip_address=ip_address,
                user_agent=user_agent,
                details={"reason": "User not found", "email": email},
            )
            return False, "Email không tồn tại"

        if not user.reset_code:
            AuditLogRepository.log_action(
                db,
                action="user.verify_reset_otp",
                status="failure",
                user_id=user.id,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"reason": "No reset code set"},
            )
            return False, "Không tìm thấy yêu cầu đặt lại mật khẩu. Vui lòng yêu cầu lại."

        # Constant-time comparison to prevent timing attacks
        if not secrets.compare_digest(user.reset_code, code):
            AuditLogRepository.log_action(
                db,
                action="user.verify_reset_otp",
                status="failure",
                user_id=user.id,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"reason": "Invalid code"},
            )
            return False, "Mã xác thực không đúng"

        # Check expiry
        if not user.reset_code_expires_at or user.reset_code_expires_at < get_current_time():
            AuditLogRepository.log_action(
                db,
                action="user.verify_reset_otp",
                status="failure",
                user_id=user.id,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"reason": "Code expired"},
            )
            return False, "Mã xác thực đã hết hạn. Vui lòng yêu cầu lại."

        AuditLogRepository.log_action(
            db,
            action="user.verify_reset_otp",
            status="success",
            user_id=user.id,
            resource_type="user",
            resource_id=user.id,
            ip_address=ip_address,
            user_agent=user_agent,
            details={"email": email},
        )
        return True, "Mã xác thực hợp lệ"

    @classmethod
    def reset_password(
        cls,
        db: Session,
        email: str,
        code: str,
        new_password: str,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> tuple[bool, str]:
        """
        Reset password using 6-digit PIN code.
        
        Returns:
            (success, message)
        """
        is_strong, strength_message = validate_password_strength(new_password)
        if not is_strong:
            return False, strength_message
        
        email = email.strip().lower()
        user = UserRepository.get_by_email(db, email)
        
        if not user:
            AuditLogRepository.log_action(
                db,
                action="user.reset_password",
                status="failure",
                ip_address=ip_address,
                user_agent=user_agent,
                details={"reason": "User not found", "email": email},
            )
            return False, "Email không tồn tại"
            
        if not user.reset_code:
            AuditLogRepository.log_action(
                db,
                action="user.reset_password",
                status="failure",
                user_id=user.id,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"reason": "No reset code set"},
            )
            return False, "Không tìm thấy yêu cầu đặt lại mật khẩu"
            
        # Constant-time comparison to prevent timing attacks
        if not secrets.compare_digest(user.reset_code, code):
            AuditLogRepository.log_action(
                db,
                action="user.reset_password",
                status="failure",
                user_id=user.id,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"reason": "Invalid code"},
            )
            return False, "Mã đặt lại mật khẩu không đúng"
            
        # Check expiry
        if not user.reset_code_expires_at or user.reset_code_expires_at < get_current_time():
            AuditLogRepository.log_action(
                db,
                action="user.reset_password",
                status="failure",
                user_id=user.id,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"reason": "Code expired"},
            )
            return False, "Mã đặt lại mật khẩu đã hết hạn. Vui lòng yêu cầu lại."
        
        try:
            # Update password
            UserRepository.update_password(db, user.id, new_password)
            
            # Clear the reset code to prevent reuse
            user.reset_code = None
            user.reset_code_expires_at = None
            
            # Use a slightly complex update flow - ensure we do a db refresh or commit
            # (update_password does commit, but its best to ensure our manual changes save too)
            user.updated_at = get_current_time()
            db.commit()
            
            # Send notification email
            EmailService.send_password_changed_notification(user.email)
            
            AuditLogRepository.log_action(
                db,
                action="user.reset_password",
                status="success",
                user_id=user.id,
                resource_type="user",
                resource_id=user.id,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"email": email},
            )
            
            return True, "Mật khẩu đã được đặt lại thành công"
            
        except Exception as e:
            AuditLogRepository.log_action(
                db,
                action="user.reset_password",
                status="error",
                user_id=user.id,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"email": email, "error": str(e)},
            )
            return False, f"Lỗi server: {str(e)}"

    @classmethod
    def change_password(
        cls,
        db: Session,
        user_id: int,
        current_password: str,
        new_password: str,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> tuple[bool, str]:
        """
        Change password for authenticated user (requires current password).
        
        Returns:
            (success, message)
        """
        is_strong, strength_message = validate_password_strength(new_password)
        if not is_strong:
            return False, strength_message
        
        user = UserRepository.get_by_id(db, user_id)
        
        if not user:
            AuditLogRepository.log_action(
                db,
                action="user.change_password",
                status="failure",
                user_id=user_id,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"reason": "User not found"},
            )
            return False, "User không tồn tại"
        
        # Verify current password
        from app.utils.password import verify_password
        if not verify_password(current_password, user.password_hash):
            AuditLogRepository.log_action(
                db,
                action="user.change_password",
                status="failure",
                user_id=user_id,
                resource_type="user",
                resource_id=user_id,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"reason": "Wrong current password"},
            )
            return False, "Mật khẩu hiện tại không đúng"
        
        try:
            # Update password
            UserRepository.update_password(db, user_id, new_password)
            
            # Send notification email
            EmailService.send_password_changed_notification(user.email)
            
            AuditLogRepository.log_action(
                db,
                action="user.change_password",
                status="success",
                user_id=user_id,
                resource_type="user",
                resource_id=user_id,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"email": user.email},
            )
            
            return True, "Mật khẩu đã được thay đổi thành công"
            
        except Exception as e:
            AuditLogRepository.log_action(
                db,
                action="user.change_password",
                status="error",
                user_id=user_id,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"error": str(e)},
            )
            return False, f"Lỗi server: {str(e)}"
