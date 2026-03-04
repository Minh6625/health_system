from pydantic import BaseModel, Field
from typing import Optional


class RegisterRequest(BaseModel):
    email: str = Field(min_length=5, max_length=120)
    full_name: str = Field(min_length=2, max_length=100)
    password: str = Field(min_length=6, max_length=64)


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
