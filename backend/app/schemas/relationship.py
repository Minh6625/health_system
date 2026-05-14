from typing import Any, List, Optional
from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr

class AccessProfileResponse(BaseModel):
    id: int
    full_name: str
    avatar_url: Optional[str] = None
    relationship_type: str  # "self", "father", "mother", etc.
    can_view_vitals: bool
    can_receive_alerts: bool
    can_view_location: bool


class LinkedContactDetailResponse(BaseModel):
    id: str
    displayName: str
    email: str
    avatarUrl: str = ""
    primaryRelationshipLabel: Optional[str] = None
    tags: List[Any] = []
    role: str = "unclassified"
    status: str
    permissions: List[str] = []
    isIncomingRequest: bool = False

class RelationshipRequestCreate(BaseModel):
    # [HS-015] Reject unknown fields so client typos surface as 422.
    model_config = ConfigDict(extra="forbid")

    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    target_user_id: Optional[int] = None
    relationship_type: str = "family"
    primary_relationship_label: Optional[str] = None
    tags: Optional[list] = None

class RelationshipAcceptRequest(BaseModel):
    # [HS-015] Reject unknown fields so client typos surface as 422.
    model_config = ConfigDict(extra="forbid")

    relationship_id: int

class RelationshipUpdate(BaseModel):
    # [HS-015] Reject unknown fields so client typos surface as 422.
    model_config = ConfigDict(extra="forbid")

    can_view_vitals: Optional[bool] = None
    can_receive_alerts: Optional[bool] = None
    can_view_location: Optional[bool] = None
    # P-4: opt-in permission for caregiver to read the patient's medical profile.
    can_view_medical_info: Optional[bool] = None
    relationship_type: Optional[str] = None
    primary_relationship_label: Optional[str] = None
    tags: Optional[list] = None

class UserSearchResponse(BaseModel):
    id: int
    full_name: str
    email: str
    phone: Optional[str] = None
    avatar_url: Optional[str] = None
    connection_status: str = "none"
    relationship_id: Optional[int] = None
    is_incoming: bool = False

class RelationshipResponse(BaseModel):
    id: int
    patient_id: int
    patient_name: str
    patient_email: str
    caregiver_id: int
    caregiver_name: str
    caregiver_email: str
    relationship_type: str
    status: str
    primary_relationship_label: Optional[str] = None
    tags: Optional[list] = None
    can_view_vitals: bool = False
    can_receive_alerts: bool = False
    can_view_location: bool = False
    # P-4: granted by current user to partner. Mirrors the can_view_* trio.
    can_view_medical_info: bool = False
    has_view_vitals_permission: bool = False
    has_receive_alerts_permission: bool = False
    has_view_location_permission: bool = False
    # P-4: granted by partner to current user (inverse direction). Defaults
    # False so legacy clients/parsers ignoring the field still see the
    # privacy-preserving outcome.
    has_view_medical_info_permission: bool = False
    created_at: datetime

    class Config:
        from_attributes = True


class LinkedContactMedicalInfoResponse(BaseModel):
    """P-4: caregiver-facing read-only view of the patient's medical
    profile. Only returned when the patient granted
    ``can_view_medical_info`` to the requesting caregiver; otherwise the
    route raises 403 — the schema itself never carries a "denied" state
    so deserializers stay simple.
    """

    contact_id: int
    display_name: str
    blood_type: Optional[str] = None
    height_cm: Optional[int] = None
    weight_kg: Optional[float] = None
    medications: List[str] = []
    allergies: List[str] = []
    medical_conditions: List[str] = []

class FamilyProfileSnapshot(BaseModel):
    id: str
    name: str
    relation: str
    heart_rate: int = 0
    spo2: int = 0
    blood_pressure_systolic: Optional[int] = None
    blood_pressure_diastolic: Optional[int] = None
    body_temperature: Optional[float] = None
    risk_level: str = "low"
    is_sos_active: bool = False
    sos_id: Optional[str] = None
    has_view_vitals_permission: bool = True
    has_vitals_data: bool = True
    vitals_data_message: Optional[str] = None
    is_pinned: bool = False
    last_updated: datetime
    special_note: str = ""
    sleep_duration_minutes: int = 0
    sleep_quality: str = "Tốt"
    # None = no health report data; an int (incl. 0) = real score from latest risk row.
    health_score_7_days: Optional[int] = None
    health_score_level: str = "Trung bình"

