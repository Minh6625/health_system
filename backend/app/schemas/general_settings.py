from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class GeneralSettingsResponse(BaseModel):
    language: str
    theme: str
    timezone: str
    push_notifications_enabled: bool
    maintenance_mode: bool
    session_timeout_minutes: int


class GeneralSettingsUpdateRequest(BaseModel):
    # [HS-015] Reject unknown fields so client typos surface as 422.
    model_config = ConfigDict(extra="forbid")

    language: Optional[str] = Field(default=None, min_length=2, max_length=10)
    theme: Optional[str] = Field(default=None, pattern="^(light|dark|system)$")
    timezone: Optional[str] = Field(default=None, min_length=3, max_length=100)
    push_notifications_enabled: Optional[bool] = None
    maintenance_mode: Optional[bool] = None
    session_timeout_minutes: Optional[int] = Field(default=None, ge=5, le=43200)


# ---------------------------------------------------------------------------
# Threshold endpoint (Phase 0.1 — single source of truth)
# ---------------------------------------------------------------------------


class HeartRateThresholds(BaseModel):
    urgent_low: float
    send_low: float
    watch_high: float
    send_high: float
    urgent_high: float


class Spo2Thresholds(BaseModel):
    urgent_low: float
    send_low: float
    watch_low: float


class BodyTempThresholds(BaseModel):
    urgent_low: float
    send_low: float
    watch_high: float
    send_high: float
    urgent_high: float


class RespRateThresholds(BaseModel):
    urgent_low: float
    watch_high: float
    send_high: float
    urgent_high: float


class SysBpThresholds(BaseModel):
    urgent_low: float
    send_low: float
    watch_high: float
    send_high: float
    urgent_high: float


class DiaBpThresholds(BaseModel):
    watch_high: float
    send_high: float
    urgent_high: float


class VitalsThresholds(BaseModel):
    """Per-metric thresholds projected from rules_config.json instant_rules."""

    heart_rate: HeartRateThresholds
    spo2: Spo2Thresholds
    body_temp: BodyTempThresholds
    resp_rate: RespRateThresholds
    sys_bp: SysBpThresholds
    dia_bp: DiaBpThresholds


class ModelHealthThresholds(BaseModel):
    warning_at: float = 0.35
    high_risk_true_at: float = 0.5
    critical_at: float = 0.65


class ModelFallThresholds(BaseModel):
    fall_true_at: float = 0.5
    warning_at: float = 0.6
    critical_at: float = 0.85


class ModelSleepThresholds(BaseModel):
    critical_below: float = 50
    poor_below: float = 60
    fair_below: float = 75
    good_below: float = 85


class ModelThresholds(BaseModel):
    health: ModelHealthThresholds
    fall: ModelFallThresholds
    sleep: ModelSleepThresholds


class ThresholdConfigResponse(BaseModel):
    """Mobile + sim-web pull this once at app start to render warning/critical zones."""

    version: str = Field(..., description="rules_config.json::version (clinical rule pin).")
    snapshot_version: str = Field(..., description="Backend snapshot pin (bump on file refresh).")
    vitals: VitalsThresholds
    fall_confidence_threshold: float = Field(
        ...,
        ge=0.0,
        le=1.0,
        description="BE secondary-validation gate before SOS escalation (telemetry.py).",
    )
    model_thresholds: ModelThresholds

