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
    relationship_type: str = "family"

class RelationshipAcceptRequest(BaseModel):
    relationship_id: int

class UserSearchResponse(BaseModel):
    id: int
    full_name: str
    email: str
    phone: Optional[str] = None
    avatar_url: Optional[str] = None

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
    created_at: datetime

    class Config:
        from_attributes = True
