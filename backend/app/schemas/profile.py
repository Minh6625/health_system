from datetime import date, datetime
import re

from pydantic import BaseModel, Field, field_validator


class ProfileResponse(BaseModel):
    user_id: int
    email: str
    full_name: str
    role: str
    phone: str | None = None
    date_of_birth: date | None = None
    is_active: bool
    is_verified: bool
    avatar_url: str | None = None
    created_at: datetime
    updated_at: datetime


class ProfileUpdateRequest(BaseModel):
    full_name: str = Field(min_length=2, max_length=100)
    phone: str | None = Field(default=None, max_length=15)
    date_of_birth: date | None = None
    avatar_url: str | None = None

    @field_validator('full_name')
    @classmethod
    def validate_full_name(cls, value: str) -> str:
        cleaned = value.strip()
        name_pattern = re.compile(r'^[a-zA-ZÀ-ỿ\s]+$')
        if not name_pattern.match(cleaned):
            raise ValueError('Họ tên chỉ được chứa chữ cái và khoảng trắng')
        return cleaned

    @field_validator('phone')
    @classmethod
    def validate_phone(cls, value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = value.replace(' ', '').replace('-', '').strip()
        if not cleaned:
            return None
        if not cleaned.isdigit() or len(cleaned) < 10 or len(cleaned) > 15:
            raise ValueError('Số điện thoại phải có từ 10 đến 15 chữ số')
        return cleaned
