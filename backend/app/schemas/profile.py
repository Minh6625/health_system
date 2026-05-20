from datetime import date, datetime
import re

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.utils.age_validator import validate_age

VALID_BLOOD_TYPES = {'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'}

# DB CHECK constraint `users_gender_check` only accepts canonical English
# values. UI/API speaks Vietnamese; we map at the schema/service boundary.
GENDER_VI_TO_EN = {'Nam': 'male', 'Nữ': 'female', 'Khác': 'other'}
GENDER_EN_TO_VI = {v: k for k, v in GENDER_VI_TO_EN.items()}
VALID_GENDERS = set(GENDER_VI_TO_EN.keys())

# Whitelist of medical-condition keys the mobile UI exposes via
# checkboxes. The DB column is `text[]` with no enum check, so without
# this validator a buggy/older client could persist arbitrary values
# that the UI then renders as empty checkboxes.
MEDICAL_CONDITION_KEYS = {
    'hypertension',
    'heart_disease',
    'diabetes',
    'stroke',
    'other',
}


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
    height_cm: int | None = None
    weight_kg: float | None = None
    medications: list[str] = []
    allergies: list[str] = []
    medical_conditions: list[str] = []
    # Phase 3: primary device pointer (nullable when user has not chosen one).
    primary_device_id: int | None = None
    created_at: datetime
    updated_at: datetime


class SetPrimaryDeviceRequest(BaseModel):
    """Phase 3: PATCH /profile/primary-device body. ``device_id=null``
    clears the primary pointer so the dashboard falls back to the
    legacy latest-of-all behaviour."""

    model_config = ConfigDict(extra="forbid")
    device_id: int | None


class SetPrimaryDeviceResponse(BaseModel):
    success: bool
    primary_device_id: int | None


class ProfileUpdateRequest(BaseModel):
    # [HS-015] Reject unknown fields so client typos surface as 422.
    model_config = ConfigDict(extra="forbid")

    full_name: str = Field(min_length=2, max_length=100)
    phone: str | None = Field(default=None, max_length=15)
    date_of_birth: date | None = None
    avatar_url: str | None = None
    # Medical fields
    gender: str | None = None
    blood_type: str | None = None
    # DB column is `smallint`; only whole-cm values are persistable. We
    # accept ints (and silently reject floats with a helpful message)
    # rather than rounding behind the user's back.
    height_cm: int | None = Field(default=None, ge=50, le=250)
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

    @field_validator('date_of_birth')
    @classmethod
    def validate_date_of_birth(cls, value: date | None) -> date | None:
        """Same age constraints as registration to prevent users from
        editing themselves into impossible ages (future dates, < 16, > 150).
        """
        is_valid, message = validate_age(value)
        if not is_valid:
            raise ValueError(message)
        return value

    @field_validator('medical_conditions')
    @classmethod
    def validate_medical_conditions(cls, value: list[str] | None) -> list[str] | None:
        if value is None:
            return None
        unknown = [v for v in value if v not in MEDICAL_CONDITION_KEYS]
        if unknown:
            raise ValueError(
                f'Tiền sử bệnh không hợp lệ: {", ".join(unknown)}. '
                f'Giá trị hợp lệ: {", ".join(sorted(MEDICAL_CONDITION_KEYS))}'
            )
        return value


class DeleteAccountRequest(BaseModel):
    # [HS-015] Reject unknown fields so client typos surface as 422.
    model_config = ConfigDict(extra="forbid")

    password: str = Field(min_length=1)
