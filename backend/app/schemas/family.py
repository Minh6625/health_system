from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class FamilyProfileSnapshot(BaseModel):
    id: str
    name: str
    relation: str
    heart_rate: int
    spo2: int
    blood_pressure_systolic: Optional[int] = None
    blood_pressure_diastolic: Optional[int] = None
    body_temperature: Optional[float] = None
    risk_level: str = "low"
    is_sos_active: bool = False
    sos_id: Optional[str] = None
    has_view_vitals_permission: bool = True
    is_pinned: bool = False
    last_updated: datetime
    special_note: str = ""
    sleep_duration_minutes: int = 0
    sleep_quality: str = "Trung bình"
    # None = no health report data; an int (incl. 0) = real score from latest risk row.
    health_score_7_days: Optional[int] = None
    health_score_level: str = "Trung bình"

class LinkedContactDetailResponse(BaseModel):
    id: str
    daily_step_count: int
    daily_distance_km: float
    calories_burned: int

