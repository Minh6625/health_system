from pydantic import BaseModel, Field, field_validator
from typing import Optional
from datetime import date
import re


class RegisterRequest(BaseModel):
    email: str = Field(min_length=5, max_length=120)
    full_name: str = Field(min_length=2, max_length=100)
    password: str = Field(min_length=8, max_length=64)
    role: str = Field(default="user")  # user | admin
    date_of_birth: Optional[date] = None  # YYYY-MM-DD
    phone: Optional[str] = Field(None, min_length=10, max_length=15)  # 10-15 digits
    
    @field_validator("email")
    @classmethod
    def validate_email(cls, v: str) -> str:
        """Validate email format."""
        if not v or not v.strip():
            raise ValueError("Email không được để trống")
        
        # Simple email pattern validation
        email_pattern = re.compile(r"^[^@]+@[^@]+\.[^@]+$")
        if not email_pattern.match(v.strip()):
            raise ValueError("Email không hợp lệ")
        
        return v.strip().lower()
    
    @field_validator("full_name")
    @classmethod
    def validate_full_name(cls, v: str) -> str:
        """
        Validate full_name contains only letters, Vietnamese diacritics, and spaces.
        Rejects numbers and special characters.
        """
        if not v or not v.strip():
            raise ValueError("Họ tên không được để trống")
        
        # Pattern: letters (a-z, A-Z), Vietnamese diacritics (À-ỿ), and spaces only
        name_pattern = re.compile(r"^[a-zA-ZÀ-ỿ\s]+$")
        if not name_pattern.match(v.strip()):
            raise ValueError("Họ tên chỉ được chứa chữ cái và khoảng trắng. Không được phép dùng số hoặc ký tự đặc biệt")
        
        return v.strip()
    
    @field_validator("role")
    @classmethod
    def validate_role(cls, v: str) -> str:
        v_lower = v.lower()
        if v_lower not in ["user", "admin"]:
            raise ValueError("Role must be 'user' or 'admin'")
        return v_lower
    
    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        # Remove spaces and dashes
        v = v.replace(" ", "").replace("-", "").strip()
        # Check if only digits
        if not v.isdigit():
            raise ValueError("Số điện thoại phải chứa chỉ các chữ số")
        # Check length
        if len(v) < 10 or len(v) > 15:
            raise ValueError("Số điện thoại phải có từ 10 đến 15 chữ số")
        return v


class LoginRequest(BaseModel):
    email: str = Field(min_length=5, max_length=120)
    password: str = Field(min_length=1, max_length=64)


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class VerifyEmailRequest(BaseModel):
    """Request to verify email with 6-digit PIN code."""
    email: str = Field(min_length=5, max_length=120)
    code: str = Field(min_length=6, max_length=6, description="Mã xác thực 6 chữ số")

    @field_validator("code")
    @classmethod
    def validate_code(cls, v: str) -> str:
        if not v.isdigit():
            raise ValueError("Mã xác thực phải là 6 chữ số")
        return v

    @field_validator("email")
    @classmethod
    def validate_email(cls, v: str) -> str:
        return v.strip().lower()


class ResendVerificationRequest(BaseModel):
    email: str = Field(min_length=5, max_length=120)


class UserData(BaseModel):
    user_id: int
    email: str
    full_name: str
    role: str


class AuthResponse(BaseModel):
    success: bool
    message: str
    access_token: Optional[str] = None
    refresh_token: Optional[str] = None
    verification_code: Optional[str] = None  # Only returned in DEV for testing
    user: Optional[UserData] = None


class ForgotPasswordRequest(BaseModel):
    email: str = Field(min_length=5, max_length=120)


class ResetPasswordRequest(BaseModel):
    """Request to reset password with 6-digit PIN code."""
    email: str = Field(min_length=5, max_length=120)
    code: str = Field(min_length=6, max_length=6, description="Mã đặt lại mật khẩu 6 chữ số")
    new_password: str = Field(min_length=6, max_length=64)

    @field_validator("code")
    @classmethod
    def validate_code(cls, v: str) -> str:
        if not v.isdigit():
            raise ValueError("Mã đặt lại mật khẩu phải là 6 chữ số")
        return v

    @field_validator("email")
    @classmethod
    def validate_email(cls, v: str) -> str:
        return v.strip().lower()


class VerifyResetOtpRequest(BaseModel):
    """Request to verify password reset OTP code (without changing password yet)."""
    email: str = Field(min_length=5, max_length=120)
    code: str = Field(min_length=6, max_length=6, description="Mã đặt lại mật khẩu 6 chữ số")

    @field_validator("code")
    @classmethod
    def validate_code(cls, v: str) -> str:
        if not v.isdigit():
            raise ValueError("Mã đặt lại mật khẩu phải là 6 chữ số")
        return v

    @field_validator("email")
    @classmethod
    def validate_email(cls, v: str) -> str:
        return v.strip().lower()


class ChangePasswordRequest(BaseModel):
    current_password: str = Field(min_length=1, max_length=64)
    new_password: str = Field(min_length=6, max_length=64)

