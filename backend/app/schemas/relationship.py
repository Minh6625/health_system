from pydantic import BaseModel, EmailStr
from typing import List, Optional
from datetime import datetime

class AccessProfileResponse(BaseModel):
    id: int
    full_name: str
    avatar_url: Optional[str] = None
    relationship_type: str  # "self", "father", "mother", etc.
    can_view_vitals: bool
    can_receive_alerts: bool
    can_view_location: bool

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
