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


# ── Phase 2: Health Connect mobile ingest ──────────────────────────────
# Mobile clients (Flutter app) push samples they read from Health Connect
# straight into ``vitals`` via ``POST /metrics/vitals/ingest``. Schemas
# stay strict: ``extra='forbid'`` blocks producers from smuggling unknown
# fields, and tight value bounds match the DB CHECK constraints in
# ``05_timeseries_vitals_motion_sleep.sql`` so a bad reading is rejected
# at the boundary instead of failing the SQL INSERT later.
from pydantic import ConfigDict, field_validator  # noqa: E402  (grouped with Phase 2 schemas)


class MobileVitalSample(BaseModel):
    """One reading harvested from Health Connect.

    Source-attribution lives in [source]; the canonical value today is
    ``"health_connect"`` for anything that came in via the Mi Fitness →
    Health Connect bridge. Manual entries from the app's emergency form
    use ``"manual"``. Unknown values are rejected so we don't silently
    pollute risk-pipeline assumptions with vendor-specific labels.
    """

    model_config = ConfigDict(extra="forbid")

    timestamp: datetime
    heart_rate: float | None = Field(default=None, ge=20, le=260)
    spo2: float | None = Field(default=None, ge=50, le=100)
    temperature: float | None = Field(default=None, ge=30, le=45)
    respiratory_rate: float | None = Field(default=None, ge=4, le=80)
    blood_pressure_sys: int | None = Field(default=None, ge=40, le=260)
    blood_pressure_dia: int | None = Field(default=None, ge=20, le=180)
    source: str = Field(default="health_connect")

    @field_validator("source")
    @classmethod
    def _validate_source(cls, value: str) -> str:
        allowed = {"health_connect", "manual"}
        if value not in allowed:
            raise ValueError("source phai la 'health_connect' hoac 'manual'")
        return value


class MobileVitalsBatch(BaseModel):
    """Batch wrapper for ``POST /metrics/vitals/ingest``.

    The 1000-sample cap matches the IoT simulator contract in
    ``vitals_ingest.md`` §1.3 so a buggy producer can't push a million
    rows in a single call.
    """

    model_config = ConfigDict(extra="forbid")

    device_id: int = Field(ge=1)
    samples: list[MobileVitalSample] = Field(min_length=1, max_length=1000)


class MobileVitalsIngestRejection(BaseModel):
    """Per-item rejection record. Producers iterate the batch and decide
    whether to retry just the rejected indices."""

    index: int
    timestamp: datetime
    reason: str


class MobileVitalsIngestResponse(BaseModel):
    """Boundary response shape for ``POST /metrics/vitals/ingest``.

    ``risk_evaluated_devices`` echoes the unique set of ``device_id`` for
    which the AI risk pipeline ran after this ingest, so the mobile UI
    can refresh the risk-history surface only when needed.
    """

    accepted: int
    rejected: int
    rejections: list[MobileVitalsIngestRejection] = Field(default_factory=list)
    risk_evaluated_devices: list[int] = Field(default_factory=list)


# F-12 (M-6): vitals time-series chart payload. The mobile
# `vital_detail_screen.dart` previously promised a "Biến động 24h qua"
# chart but `VitalSignsProvider.chartData` always returned `const []`
# because no endpoint existed. These schemas back the new
# `GET /api/v1/mobile/metrics/vitals/timeseries` endpoint that downsamples raw
# `vitals` rows into ~96 buckets (15 min × 24 h) — small enough for a
# fluid mobile chart, large enough to show real diurnal variation. Each
# bucket carries every vital channel in a single row so the screen can
# switch between heart_rate / spo2 / blood_pressure tabs without
# refetching.
class VitalsTimeseriesPointResponse(BaseModel):
    """One downsampled bucket. Null channels mean no samples in the
    bucket — the mobile chart treats those as gaps rather than zeros so
    a stretch of missing data does not pull the line to the floor."""

    ts: datetime
    heart_rate: float | None = None
    spo2: float | None = None
    temperature: float | None = None
    respiratory_rate: float | None = None
    blood_pressure_sys: float | None = None
    blood_pressure_dia: float | None = None


class VitalsTimeseriesResponse(BaseModel):
    """Envelope for the vitals time-series endpoint.

    ``range`` echoes the validated query parameter so the client can
    detect when the server fell back to the default (today only "24h"
    is supported; "7d"/"30d" are reserved for future ranges and
    currently silently coerced to "24h"). ``bucket_minutes`` lets the
    client size its X-axis ticks correctly without hard-coding a value
    that drifts from the server.
    """

    range: str
    bucket_minutes: int
    data: list[VitalsTimeseriesPointResponse] = Field(default_factory=list)


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

    # ADR-018 data quality contract (Phase 7 S11 read path). Persisted by
    # S4 (migration 20260516) but the read path was previously silent;
    # mobile binaries that pre-date S11 ignore these (extra fields), and
    # post-S11 binaries render the warning banner when
    # ``is_synthetic_default`` is true. ``defaults_applied`` is the
    # ordered list of soft vital fields the model-api had to fill with
    # population defaults; ``effective_confidence`` is the degraded
    # confidence the UI should display when the banner is shown;
    # ``data_quality_warning`` is the verbatim Vietnamese banner copy.
    is_synthetic_default: bool = False
    defaults_applied: list[str] | None = None
    effective_confidence: float | None = None
    data_quality_warning: str | None = None


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

    # ADR-018 data quality contract (Phase 7 S11 read path — same as list).
    is_synthetic_default: bool = False
    defaults_applied: list[str] | None = None
    effective_confidence: float | None = None
    data_quality_warning: str | None = None


class RiskReportClinicianResponse(RiskReportDetailResponse):
    """Phase 5 clinician-only extension of :class:`RiskReportDetailResponse`.

    Returned from ``GET /api/v1/mobile/analysis/risk-reports/{id}`` only when the
    caller passes ``?audience=clinician`` AND ``user.role`` is in
    :data:`~app.core.audience.CLINICIAN_ROLES`. Inherits every field of
    the patient response unchanged so mobile codegen can model this as a
    refinement / subtype, then adds two clinical-only fields:

    * ``shap_details`` — raw SHAP waterfall (base_value + per-feature
      contributions). Plan §F.1 frames raw SHAP as data lâm sàng that
      should not surface on the patient screen by default.
    * ``model_request_id`` — upstream model-api ``meta.request_id`` for
      end-to-end log correlation when investigating production
      incidents (already persisted by Phase 2; this surface lights it
      up on the read path for clinician audiences only).

    Phase 5 leaves the patient ``RiskReportDetailResponse`` shape
    unchanged so the existing snapshot tests + mobile parser keep
    working without modification. Wire-version bump is ``v0.4.0 ->
    v0.5.0`` (minor — additive, optional fields).
    """

    shap_details: dict[str, object] | None = None
    model_request_id: str | None = None


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
