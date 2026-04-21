from datetime import datetime
from typing import Optional, List, Dict, Any, Literal
from pydantic import BaseModel, Field


# ============================================================================
# Location Models
# ============================================================================

class LocationInfo(BaseModel):
    """Location information snapshot."""
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    accuracy: Optional[float] = None
    address: Optional[str] = None
    last_updated: Optional[datetime] = None
    
    class Config:
        from_attributes = True


# ============================================================================
# Patient Info Models
# ============================================================================

class PatientInfo(BaseModel):
    """Patient basic information for SOS alerts."""
    user_id: int
    full_name: str
    avatar_url: Optional[str] = None
    phone: Optional[str] = None
    date_of_birth: Optional[str] = None
    
    class Config:
        from_attributes = True


# ============================================================================
# Fall Detection XAI Models
# ============================================================================

class TimelineEvent(BaseModel):
    """Timeline event in fall detection explanation."""
    time_offset: str  # e.g., "T+0s", "T+0.25s"
    event: str  # e.g., "Impact detected", "Stillness detected"
    
    
class FallDetectionXAI(BaseModel):
    """Explainable AI data for fall detection."""
    confidence: float
    timeline: List[TimelineEvent]
    trigger_reason: str
    
    class Config:
        from_attributes = True


# ============================================================================
# Resolution Info Models
# ============================================================================

class ResolutionInfo(BaseModel):
    """Information about SOS resolution."""
    resolved_at: datetime
    resolved_by_name: str
    resolution_status: str  # e.g., "safe", "assisted"
    notes: Optional[str] = None
    
    class Config:
        from_attributes = True


# ============================================================================
# SOS Event Response Models
# ============================================================================

class SOSEventResponse(BaseModel):
    """Complete SOS event data for mobile app."""
    sos_id: int
    patient: PatientInfo
    trigger_type: str  # "fall_detected", "manual", "vital_critical"
    trigger_time: datetime
    status: str  # "active", "resolved"
    location: Optional[LocationInfo] = None
    fall_detection_xai: Optional[FallDetectionXAI] = None
    resolution: Optional[ResolutionInfo] = None
    
    class Config:
        from_attributes = True


class SOSEventListItem(BaseModel):
    """Simplified SOS event data for list view."""
    sos_id: int
    patient: PatientInfo
    trigger_type: str
    trigger_time: datetime
    status: str
    location: Optional[LocationInfo] = None
    time_elapsed_minutes: int
    
    class Config:
        from_attributes = True


class SOSAlertsResponse(BaseModel):
    """Response for SOS alerts list endpoint."""
    sos_alerts: List[SOSEventListItem]
    total_count: int
    active_count: int
    resolved_count: int


# ============================================================================
# Request Models
# ============================================================================
class TriggerSOSRequest(BaseModel):
    """Request to trigger a new SOS event."""
    trigger_type: str = "manual"
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    address: Optional[str] = None


class RiskAlertResponseRequest(BaseModel):
    """Request to respond to an initial risk alert."""

    risk_score_id: Optional[int] = None
    action: Literal["safe", "help_requested", "timeout_escalated"]
    source: Literal["overlay", "push_tap"]
    device_id: Optional[int] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    address: Optional[str] = Field(None, max_length=255)
    notes: Optional[str] = Field(None, max_length=500)


class RiskAlertResponseResponse(BaseModel):
    """Response returned after handling a risk alert response."""

    success: bool = True
    status: Literal["acknowledged", "escalated", "duplicate"]
    acknowledged_at: datetime
    sos_event_id: Optional[int] = None
    recipient_count: Optional[int] = None


class ResolveSOSRequest(BaseModel):
    """Request to resolve SOS event by caregiver."""
    resolution_status: str = Field(..., pattern="^(safe|assisted|cancelled)$")
    notes: Optional[str] = Field(None, max_length=500)


# ============================================================================
# Generic Response Models
# ============================================================================

class SuccessResponse(BaseModel):
    """Generic success response."""
    success: bool = True
    message: str


class TriggerSOSResponse(SuccessResponse):
    """Manual SOS trigger response with fan-out metadata."""

    sos_id: int
    recipient_count: int
