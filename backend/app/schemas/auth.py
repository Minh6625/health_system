from pydantic import BaseModel, Field, field_validator
from typing import Optional
from datetime import date
import re


class RegisterRequest(BaseModel):
    email: str = Field(min_length=5, max_length=120)
    full_name: str = Field(min_length=2, max_length=100)
    password: str = Field(min_length=8, max_length=64)  # Updated to 8 chars for strength
    role: str = Field(default="patient")  # patient | caregiver
    date_of_birth: Optional[date] = None  # YYYY-MM-DD
    phone: Optional[str] = Field(None, min_length=10, max_length=15)  # 10-15 digits
    
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
        if v not in ["patient", "caregiver"]:
            raise ValueError("Role must be 'patient' or 'caregiver'")
        return v.lower()
    
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
    verification_token: str


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
    verification_token: Optional[str] = None
    user: Optional[UserData] = None


class ForgotPasswordRequest(BaseModel):
    email: str = Field(min_length=5, max_length=120)


class ResetPasswordRequest(BaseModel):
    reset_token: str
    new_password: str = Field(min_length=6, max_length=64)


class ChangePasswordRequest(BaseModel):
    current_password: str = Field(min_length=1, max_length=64)
    new_password: str = Field(min_length=6, max_length=64)
