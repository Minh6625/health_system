import re
from typing import Optional

from sqlalchemy.orm import Session

from app.models.user_model import User
from app.repositories.audit_log_repository import AuditLogRepository
from app.repositories.user_repository import UserRepository
from app.utils.jwt import create_access_token, create_refresh_token, decode_token


class AuthService:
    email_pattern = re.compile(r"^[^@]+@[^@]+\.[^@]+$")

    @classmethod
    def register(
        cls,
        db: Session,
        email: str,
        password: str,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> tuple[bool, str, Optional[dict]]:
        """
        Register new user.
        
        Returns:
            (success, message, None)
        """
        email = email.strip()
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

        if len(password) < 6:
            AuditLogRepository.log_action(
                db,
                action="user.register",
                status="failure",
                ip_address=ip_address,
                user_agent=user_agent,
                details={"email": email, "reason": "Password too short"},
            )
            return False, "Mật khẩu phải có ít nhất 6 ký tự", None

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
            user = UserRepository.create_user(db, email, password, full_name=email.split("@")[0])
            AuditLogRepository.log_action(
                db,
                action="user.register",
                status="success",
                user_id=user.id,
                resource_type="user",
                resource_id=user.id,
                ip_address=ip_address,
                user_agent=user_agent,
                details={"email": email},
            )
            return True, "Đăng ký thành công", None
        except Exception as e:
            AuditLogRepository.log_action(
                db,
                action="user.register",
                status="error",
                ip_address=ip_address,
                user_agent=user_agent,
                details={"email": email, "error": str(e)},
            )
            return False, f"Lỗi server: {str(e)}", None

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
            AuditLogRepository.log_action(
                db,
                action="user.login",
                status="error",
                ip_address=ip_address,
                user_agent=user_agent,
                details={"email": email, "error": str(e)},
            )
            return False, f"Lỗi server: {str(e)}", None

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
