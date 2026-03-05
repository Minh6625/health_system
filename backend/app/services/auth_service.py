import re
from typing import Optional
import logging
from datetime import date, datetime

from sqlalchemy.orm import Session

from app.models.user_model import User
from app.repositories.audit_log_repository import AuditLogRepository
from app.repositories.user_repository import UserRepository
from app.utils.jwt import (
    create_access_token,
    create_refresh_token,
    create_email_verification_token,
    create_password_reset_token,
    decode_token,
)
from app.utils.email_service import EmailService
from app.utils.password import validate_password_strength

logger = logging.getLogger(__name__)


class AuthService:
    email_pattern = re.compile(r"^[^@]+@[^@]+\.[^@]+$")
    
    @staticmethod
    def validate_age(date_of_birth: Optional[date]) -> tuple[bool, str]:
        """
        Validate age from date of birth.
        
        Requirements:
        - Age >= 18 (must be adult)
        - Age <= 150 (reasonable upper limit)
        
        Returns:
            (is_valid, message) tuple
        """
        if date_of_birth is None:
            return True, "OK"  # Optional field
        
        today = date.today()
        age = today.year - date_of_birth.year - (
            (today.month, today.day) < (date_of_birth.month, date_of_birth.day)
        )
        
        # Check if age is in valid range
        if age < 0:
            return False, "Ngày sinh không hợp lệ (trong tương lai)"
        
        if age < 18:
            return False, "Bạn phải đủ 18 tuổi để đăng ký"
        
        if age > 150:
            return False, "Ngày sinh không hợp lệ (tuổi quá cao)"
        
        return True, "OK"

    @classmethod
    def register(
        cls,
        db: Session,
        email: str,
        full_name: str,
        password: str,
        role: str = "patient",
        date_of_birth: Optional[date] = None,
        phone: Optional[str] = None,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> tuple[bool, str, Optional[dict]]:
        """
        Register new user with role support and strong password validation.
        
        Args:
            db: Database session
            email: User email
            full_name: User full name
            password: User password (must meet strength requirements)
            role: User role (patient or caregiver, default: patient)
            date_of_birth: User date of birth (YYYY-MM-DD), optional
            phone: User phone number (10-15 digits), optional
            ip_address: Client IP address
            user_agent: Client user agent
        
        Returns:
            (success, message, token_data) tuple
            where token_data = {"verification_token": str, "user": User} or None on failure
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
        if role not in ["patient", "caregiver"]:
            role = "patient"

        # Check if email already exists
        existing_user = UserRepository.get_by_email(db, email)
        if existing_user:
            AuditLogRepository.log_action(
                db,
                action="user.register",
                status="failure",
                ip_address=ip_address,
                user_agent=user_agent,
                details={"email": email, "reason": "Email already exists"},
            )
            return False, "Email đã tồn tại", None

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
            
            # Generate email verification token
            verification_token = create_email_verification_token(
                data={"user_id": user.id, "email": user.email}
            )
            
            # Send verification email
            email_sent = EmailService.send_verification_email(email, verification_token)
            
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
            
            return True, "Đăng ký thành công. Vui lòng xác thực email.", {
                "verification_token": verification_token,
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
        verification_token: str,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> tuple[bool, str]:
        """
        Verify user email using verification token.
        
        Returns:
            (success, message)
        """
        payload = decode_token(verification_token)
        
        if not payload or payload.get("type") != "email_verification":
            AuditLogRepository.log_action(
                db,
                action="user.email_verify",
                status="failure",
                ip_address=ip_address,
                user_agent=user_agent,
                details={"reason": "Invalid verification token"},
            )
            return False, "Token xác thực không hợp lệ"
        
        user_id = payload.get("user_id")
        email = payload.get("email")
        
        user = UserRepository.get_by_id(db, user_id)
        
        if not user:
            AuditLogRepository.log_action(
                db,
                action="user.email_verify",
                status="failure",
                ip_address=ip_address,
                user_agent=user_agent,
                details={"reason": "User not found", "user_id": user_id},
            )
            return False, "User không tồn tại"
        
        if user.email != email:
            AuditLogRepository.log_action(
                db,
                action="user.email_verify",
                status="failure",
                user_id=user_id,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"reason": "Email mismatch"},
            )
            return False, "Email không khớp"
        
        if user.is_verified:
            AuditLogRepository.log_action(
                db,
                action="user.email_verify",
                status="success",
                user_id=user_id,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"email": email, "note": "Already verified"},
            )
            return True, "Email đã được xác thực"
        
        try:
            verified = UserRepository.verify_email(db, user_id)
            
            if verified:
                AuditLogRepository.log_action(
                    db,
                    action="user.email_verify",
                    status="success",
                    user_id=user_id,
                    resource_type="user",
                    resource_id=user_id,
                    ip_address=ip_address,
                    user_agent=user_agent,
                    details={"email": email},
                )
                return True, "Xác thực email thành công"
            else:
                return False, "Lỗi khi xác thực email"
                
        except Exception as e:
            AuditLogRepository.log_action(
                db,
                action="user.email_verify",
                status="error",
                user_id=user_id,
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
            # Generate new verification token
            verification_token = create_email_verification_token(
                data={"user_id": user.id, "email": user.email}
            )
            
            # Send verification email
            email_sent = EmailService.send_verification_email(email, verification_token)
            
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
            
            return True, "Email xác thực đã được gửi lại. Vui lòng kiểm tra hộp thư", {
                "verification_token": verification_token
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
    ) -> tuple[bool, str, Optional[dict]]:
        """
        Generate password reset token and send email.
        
        Returns:
            (success, message, token_data)
            where token_data = {"reset_token": str} or None
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
            return True, "Nếu email tồn tại, bạn sẽ nhận được email hướng dẫn đặt lại mật khẩu", None
        
        try:
            # Generate reset token
            reset_token = create_password_reset_token(
                data={"user_id": user.id, "email": user.email}
            )
            
            # Send reset email (email service will create deep link)
            email_sent = EmailService.send_password_reset_email(email, reset_token)
            
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
            
            return True, "Nếu email tồn tại, bạn sẽ nhận được email hướng dẫn đặt lại mật khẩu", {
                "reset_token": reset_token
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
    def reset_password(
        cls,
        db: Session,
        reset_token: str,
        new_password: str,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> tuple[bool, str]:
        """
        Reset password using reset token (one-time use).
        
        Returns:
            (success, message)
        """
        if len(new_password) < 6:
            return False, "Mật khẩu phải có ít nhất 6 ký tự"
        
        payload = decode_token(reset_token)
        
        if not payload or payload.get("type") != "password_reset":
            AuditLogRepository.log_action(
                db,
                action="user.reset_password",
                status="failure",
                ip_address=ip_address,
                user_agent=user_agent,
                details={"reason": "Invalid reset token"},
            )
            return False, "Token đặt lại mật khẩu không hợp lệ hoặc đã hết hạn"
        
        user_id = payload.get("user_id")
        email = payload.get("email")
        
        user = UserRepository.get_by_id(db, user_id)
        
        if not user:
            AuditLogRepository.log_action(
                db,
                action="user.reset_password",
                status="failure",
                ip_address=ip_address,
                user_agent=user_agent,
                details={"reason": "User not found", "user_id": user_id},
            )
            return False, "User không tồn tại"
        
        if user.email != email:
            AuditLogRepository.log_action(
                db,
                action="user.reset_password",
                status="failure",
                user_id=user_id,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"reason": "Email mismatch"},
            )
            return False, "Token không hợp lệ"
        
        # Check if password was already changed after token was issued (one-time use)
        token_issued_at = payload.get("iat")
        if user.updated_at and token_issued_at:
            # Convert token_issued_at (timestamp) to datetime for comparison
            from datetime import datetime, timezone
            token_time = datetime.fromtimestamp(token_issued_at, tz=timezone.utc)
            
            # Ensure user.updated_at is timezone-aware for comparison
            user_updated_at = user.updated_at
            if user_updated_at.tzinfo is None:
                user_updated_at = user_updated_at.replace(tzinfo=timezone.utc)
            
            if user_updated_at > token_time:
                AuditLogRepository.log_action(
                    db,
                    action="user.reset_password",
                    status="failure",
                    user_id=user_id,
                    ip_address=ip_address,
                    user_agent=user_agent,
                    details={"reason": "Token already used"},
                )
                return False, "Token đã được sử dụng. Vui lòng yêu cầu đặt lại mật khẩu mới"
        
        try:
            # Update password
            UserRepository.update_password(db, user_id, new_password)
            
            # Send notification email
            EmailService.send_password_changed_notification(user.email)
            
            AuditLogRepository.log_action(
                db,
                action="user.reset_password",
                status="success",
                user_id=user_id,
                resource_type="user",
                resource_id=user_id,
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
                user_id=user_id,
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
        if len(new_password) < 6:
            return False, "Mật khẩu mới phải có ít nhất 6 ký tự"
        
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
