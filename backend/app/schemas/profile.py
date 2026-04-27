from datetime import date, datetime
import re

from pydantic import BaseModel, Field, field_validator

VALID_BLOOD_TYPES = {'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'}

# DB CHECK constraint `users_gender_check` only accepts canonical English
# values. UI/API speaks Vietnamese; we map at the schema/service boundary.
GENDER_VI_TO_EN = {'Nam': 'male', 'Nữ': 'female', 'Khác': 'other'}
GENDER_EN_TO_VI = {v: k for k, v in GENDER_VI_TO_EN.items()}
VALID_GENDERS = set(GENDER_VI_TO_EN.keys())


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
    # Medical fields
    gender: str | None = None
    blood_type: str | None = None
    height_cm: float | None = None
    weight_kg: float | None = None
    medications: list[str] = []
    allergies: list[str] = []
    medical_conditions: list[str] = []
    created_at: datetime
    updated_at: datetime


class ProfileUpdateRequest(BaseModel):
    full_name: str = Field(min_length=2, max_length=100)
    phone: str | None = Field(default=None, max_length=15)
    date_of_birth: date | None = None
    avatar_url: str | None = None
    # Medical fields
    gender: str | None = None
    blood_type: str | None = None
    height_cm: float | None = Field(default=None, ge=50, le=250)
    # DB CHECK: weight_kg < 500 (strict). Pydantic must mirror.
    weight_kg: float | None = Field(default=None, ge=2, lt=500)
    medications: list[str] | None = None
    allergies: list[str] | None = None
    medical_conditions: list[str] | None = None

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
        if not cleaned.isdigit():
            raise ValueError('Số điện thoại chỉ được chứa chữ số')
        if len(cleaned) < 10 or len(cleaned) > 11:
            raise ValueError('Số điện thoại phải có 10-11 chữ số')
        if not cleaned.startswith('0'):
            raise ValueError('Số điện thoại Việt Nam phải bắt đầu bằng 0')
        return cleaned

    @field_validator('blood_type')
    @classmethod
    def validate_blood_type(cls, value: str | None) -> str | None:
        if value is None:
            return None
        if value not in VALID_BLOOD_TYPES:
            raise ValueError(f'Nhóm máu không hợp lệ. Các giá trị hợp lệ: {", ".join(sorted(VALID_BLOOD_TYPES))}')
        return value

    @field_validator('gender')
    @classmethod
    def validate_gender(cls, value: str | None) -> str | None:
        """Accept Vietnamese label from UI; persist canonical English to DB."""
        if value is None:
            return None
        if value not in VALID_GENDERS:
            raise ValueError(f'Giới tính không hợp lệ. Các giá trị hợp lệ: {", ".join(VALID_GENDERS)}')
        return GENDER_VI_TO_EN[value]


class DeleteAccountRequest(BaseModel):
    password: str = Field(min_length=1)
