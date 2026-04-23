from typing import Any, List, Optional
from datetime import datetime

from pydantic import BaseModel, EmailStr

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
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    target_user_id: Optional[int] = None
    relationship_type: str = "family"
    primary_relationship_label: Optional[str] = None
    tags: Optional[list] = None

class RelationshipAcceptRequest(BaseModel):
    relationship_id: int

class RelationshipUpdate(BaseModel):
    can_view_vitals: Optional[bool] = None
    can_receive_alerts: Optional[bool] = None
    can_view_location: Optional[bool] = None
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
    has_view_vitals_permission: bool = False
    has_receive_alerts_permission: bool = False
    has_view_location_permission: bool = False
    created_at: datetime

    class Config:
        from_attributes = True

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
    health_score_7_days: int = 0
    health_score_level: str = "Trung bình"

