from datetime import datetime
from pydantic import BaseModel


class VitalSignsResponse(BaseModel):
    heart_rate: float | None = None
    spo2: float | None = None
    temperature: float | None = None
    respiratory_rate: float | None = None
    blood_pressure_sys: float | None = None
    blood_pressure_dia: float | None = None
    timestamp: datetime
    is_stale: bool = False


class SleepSessionResponse(BaseModel):
    quality_score: int
    in_bed_minutes: int
    wake_count: int
    phases: dict[str, int]
    start_time: datetime
    end_time: datetime
    session_id: str = ""
    sleep_minutes: int = 0
    awake_minutes: int = 0
    efficiency_ratio: float = 0.0
    quality_label: str = "AVERAGE"
