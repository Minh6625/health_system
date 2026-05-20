from datetime import date, datetime
from typing import Optional, List, Dict, Any, Literal
from pydantic import BaseModel, ConfigDict, Field


# [HS-015] Every Request schema in this module rejects unknown fields so
# typos surface as 422 instead of being silently dropped.


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
    date_of_birth: Optional[date] = None  # [HS-017] typed (rejects "abc" / "2026-13-45")
    
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
    model_config = ConfigDict(extra="forbid")

    trigger_type: Literal["auto", "manual"] = "manual"
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    address: Optional[str] = None


class RiskAlertResponseRequest(BaseModel):
    """Request to respond to an initial risk alert."""
    model_config = ConfigDict(extra="forbid")

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
    model_config = ConfigDict(extra="forbid")

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


# ============================================================================
# Recent Alerts (caregiver feed for PersonDetailScreen)
# ============================================================================


class RecentAlertDeepLink(BaseModel):
    """Hint to the mobile client about which detail screen to open on tap.

    The backend never derives a route string — it only emits the *kind* of
    target plus its primary key. Mobile owns the route table so that backend
    changes can't break navigation.
    """

    type: Literal["sos_event", "risk_score", "fall_event", "alert"]
    id: int


class RecentAlertItem(BaseModel):
    """A single alert as shown on the caregiver-facing feed."""

    id: int
    uuid: str
    alert_type: str  # value from CAREGIVER_FEED_ALERT_TYPES
    severity: str  # 'low' | 'medium' | 'high' | 'critical'
    title: str
    message: Optional[str] = None
    occurred_at: datetime
    is_resolved: bool = False
    deep_link: Optional[RecentAlertDeepLink] = None

    class Config:
        from_attributes = True


class RecentAlertsResponse(BaseModel):
    """Response for ``GET /caregiver/patients/{id}/recent-alerts``.

    ``permission_state`` lets the client tell apart *no rows* (granted but
    quiet) from *no permission* (caregiver hasn't been allowed to receive
    alerts) without parsing the HTTP status. The status itself stays 200 in
    both granted cases; 403 only fires when the relationship is missing or
    not accepted.
    """

    items: List[RecentAlertItem]
    permission_state: Literal["granted"]
    window_days: int
    total_in_window: int
