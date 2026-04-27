from datetime import date, datetime

from pydantic import BaseModel, Field


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
    session_id: str = ""
    sleep_date: date
    quality_score: int
    quality_label: str = "AVERAGE"
    in_bed_minutes: int
    sleep_minutes: int = 0
    awake_minutes: int = 0
    efficiency_ratio: float = 0.0
    wake_count: int
    phases: dict[str, int]
    start_time: datetime
    end_time: datetime


class SleepHistoryResponse(BaseModel):
    data: list[SleepSessionResponse] = Field(default_factory=list)


class HealthReportResponse(BaseModel):
    vitals_24h_avg: dict[str, float | int | None] = Field(default_factory=dict)
    latest_risk_score: float | None = None
    risk_level: str | None = None
    risk_type: str | None = None
    last_updated: datetime | None = None
    health_score: float | None = None
    health_level: str | None = None
    health_summary: str | None = None
    confidence: float | None = None
    is_stale: bool = True


class TopFactorResponse(BaseModel):
    key: str
    label: str
    impact: float = 0.0
    direction: str = ""
    reason: str = ""
    feature_value: str = ""


class FactorBreakdownResponse(BaseModel):
    key: str
    label: str
    contribution_score: float
    impact_level: str
    value: str
    unit: str
    route_target: str
    direction: str = ""
    reason: str = ""


class AiExplanationResponse(BaseModel):
    short_text: str = ""
    clinical_note: str = ""
    recommended_actions: list[str] = Field(default_factory=list)


class SnapshotMetricsResponse(BaseModel):
    heart_rate: int = 0
    spo2: int = 0
    sys_bp: int = 0
    dia_bp: int = 0
    body_temp: float = 0.0
    hrv: int = 0
    map_val: int = 0


class RiskReportResponse(BaseModel):
    """Mobile risk-report list item.

    Phase 1 canonicalisation (see ``backend/docs/risk-contract-baseline.md``):

    - ``score`` is the canonical risk score; ``risk_score`` is a deprecated alias.
    - ``display_status`` is the canonical UI label; ``health_level`` is a
      deprecated view kept for back-compat with older Flutter binaries.
    - ``top_factors[].key`` is the canonical key list; ``key_features`` is a
      deprecated convenience derived from it.

    All deprecated fields remain on the wire until Phase 6 introduces the
    ``X-Risk-Contract-Version`` header so dual-emit can be retired safely.
    """

    id: int
    risk_type: str
    risk_score: float = Field(
        deprecated="Use `score` instead. Removal scheduled for Phase 6.",
    )
    score: float
    health_score: float
    risk_level: str
    health_level: str | None = Field(
        default=None,
        deprecated="Use `display_status` instead. Removal scheduled for Phase 6.",
    )
    display_status: str
    summary: str
    timestamp: datetime
    previous_score: float | None = None
    trend_7d: list[int] = Field(default_factory=list)
    key_features: list[str] = Field(
        default_factory=list,
        deprecated=(
            "Derivable from `top_factors[].key`. Kept for back-compat; "
            "removal scheduled for Phase 6."
        ),
    )
    top_factors: list[TopFactorResponse] = Field(default_factory=list)
    recommendation_preview: list[str] = Field(default_factory=list)
    confidence: float = 0.0
    is_stale: bool = True


class RiskReportDetailResponse(BaseModel):
    """Mobile risk-report detail payload.

    Phase 1 canonicalisation (see ``backend/docs/risk-contract-baseline.md``):

    - ``score`` is canonical; ``risk_score`` is a deprecated alias.
    - ``display_status`` is canonical; ``health_level`` is a deprecated view.
    - ``explanation`` is canonical; ``xai_explanation`` is a deprecated alias.
    - ``breakdown`` is canonical; ``feature_importance`` is a deprecated subset.

    Deprecated fields are still emitted with the same value as their canonical
    counterpart and are guarded by invariance tests in
    ``backend/tests/contract/test_mobile_risk_dto_snapshot.py``.
    """

    id: int
    risk_type: str
    risk_score: float = Field(
        deprecated="Use `score` instead. Removal scheduled for Phase 6.",
    )
    score: float
    health_score: float
    risk_level: str
    health_level: str | None = Field(
        default=None,
        deprecated="Use `display_status` instead. Removal scheduled for Phase 6.",
    )
    display_status: str
    summary: str
    timestamp: datetime
    previous_score: float | None = None
    trend_7d: list[int] = Field(default_factory=list)
    explanation: str = ""
    xai_explanation: str = Field(
        default="",
        deprecated="Use `explanation` instead. Removal scheduled for Phase 6.",
    )
    features: dict[str, object] = Field(default_factory=dict)
    feature_importance: dict[str, float] = Field(
        default_factory=dict,
        deprecated=(
            "Derivable from `breakdown[*].contribution_score`. Kept for "
            "back-compat; removal scheduled for Phase 6."
        ),
    )
    breakdown: list[FactorBreakdownResponse] = Field(default_factory=list)
    recommendations: list[str] = Field(default_factory=list)
    recommendation_preview: list[str] = Field(default_factory=list)
    top_factors: list[TopFactorResponse] = Field(default_factory=list)
    snapshot: SnapshotMetricsResponse = Field(default_factory=SnapshotMetricsResponse)
    model_version: str = "1.0"
    algorithm: str = "unknown"
    confidence: float = 0.0
    is_stale: bool = True
    ai_explanation: AiExplanationResponse | None = None


class RiskHistorySummaryResponse(BaseModel):
    average_score: float = 0.0
    highest_score: float = 0.0
    lowest_score: float = 0.0
    delta_vs_previous_period: float = 0.0
    trend_points: list[int] = Field(default_factory=list)


class RiskHistoryItemResponse(BaseModel):
    """Mobile risk-history list row.

    Phase 1: ``score`` is canonical; ``risk_score`` is a deprecated alias kept
    for back-compat with older Flutter binaries. Removal scheduled for Phase 6.
    """

    report_id: int
    risk_score: float = Field(
        deprecated="Use `score` instead. Removal scheduled for Phase 6.",
    )
    score: float
    health_score: float
    risk_level: str
    display_status: str
    analyzed_at: datetime
    reason_preview: str
    is_stale: bool = True


class RiskHistoryResponse(BaseModel):
    range: str
    summary: RiskHistorySummaryResponse
    items: list[RiskHistoryItemResponse] = Field(default_factory=list)
    page: int = 1
    limit: int = 20
    has_more: bool = False
