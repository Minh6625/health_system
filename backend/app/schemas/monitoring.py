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


class HealthReportResponse(BaseModel):
    """Comprehensive health report with vitals 24h stats and risk assessment."""
    vitals_24h_avg: dict = {}
    latest_risk_score: float | None = None
    risk_level: str | None = None
    risk_type: str | None = None
    last_updated: datetime | None = None


class RiskReportResponse(BaseModel):
    """Risk report summary for listing."""
    id: int
    risk_type: str
    score: float
    risk_level: str
    timestamp: datetime
    key_features: list[str] = []


class RiskReportDetailResponse(BaseModel):
    """Detailed risk report with explanation and recommendations."""
    id: int
    risk_type: str
    score: float
    risk_level: str
    timestamp: datetime
    explanation: str = ""
    features: dict = {}
    feature_importance: dict = {}
    recommendations: list[str] = []
    model_version: str = "1.0"
    algorithm: str = "unknown"


class RiskHistoryResponse(BaseModel):
    """Risk history statistics aggregated by date."""
    risk_type: str
    date: str
    avg_score: float
    max_score: float
    min_score: float
    measurements: int
