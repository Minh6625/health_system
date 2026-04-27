"""Mobile-side schemas for the Phase 4A-thin sleep risk ingest route.

The inner record is a verbatim port of the upstream healthguard-model-api
``SleepRecord`` (`healthguard-model-api/app/schemas/sleep.py`) plus
``db_device_id`` / ``user_id`` so the backend can resolve the source
device + owner without trusting the unauthenticated string ``user_id``
that the model-api uses internally.

Keeping the schemas verbatim means the inner record passes through to
``ModelApiClient.predict_sleep`` unchanged — no per-field translation
in either direction.
"""

from __future__ import annotations

from pydantic import BaseModel, Field


class SleepRecord(BaseModel):
    """One canonical sleep session — verbatim port of model-api ``SleepRecord``.

    Field set is intentionally large (40+ entries). Most have no safe
    default; silently filling in ``0.0`` would bias the model toward
    "perfect sleep" even on a device that didn't capture the value.
    Caller must populate every field.
    """

    user_id: str
    date_recorded: str
    sleep_start_timestamp: str
    sleep_end_timestamp: str
    duration_minutes: float
    sleep_latency_minutes: float
    wake_after_sleep_onset_minutes: float
    sleep_efficiency_pct: float
    sleep_stage_deep_pct: float
    sleep_stage_light_pct: float
    sleep_stage_rem_pct: float
    sleep_stage_awake_pct: float
    heart_rate_mean_bpm: float
    heart_rate_min_bpm: float
    heart_rate_max_bpm: float
    hrv_rmssd_ms: float
    respiration_rate_bpm: float
    spo2_mean_pct: float
    spo2_min_pct: float
    movement_count: float
    snore_events: float
    ambient_noise_db: float
    room_temperature_c: float
    room_humidity_pct: float
    step_count_day: float
    caffeine_mg: float
    alcohol_units: float
    medication_flag: float
    jetlag_hours: float
    timezone: str
    age: float
    gender: str
    weight_kg: float
    height_cm: float
    device_model: str
    bedtime_consistency_std_min: float
    stress_score: float
    activity_before_bed_min: float
    screen_time_before_bed_min: float
    insomnia_flag: float
    apnea_risk_score: float
    nap_duration_minutes: float
    created_at: str


class SleepRiskRequest(BaseModel):
    """Body for ``POST /mobile/telemetry/sleep-risk``.

    Adds the backend-only fields (``db_device_id``, ``db_user_id``) that
    the model-api doesn't need but that the persistence layer requires
    for FK resolution. The inner ``record`` is forwarded verbatim to
    ``predict_sleep``.
    """

    db_device_id: int = Field(..., description="`devices.id` of the source watch.")
    db_user_id: int = Field(..., description="`users.id` who owns the device.")
    record: SleepRecord


class SleepRiskResponse(BaseModel):
    """Compact summary returned to the simulator / mobile."""

    status: str = Field(
        ...,
        description=(
            "``ok`` when the upstream returned a prediction and a "
            "``risk_scores`` row was persisted with ``risk_type='sleep'``. "
            "``model_unavailable`` when the breaker is open or the "
            "upstream errored — no row written."
        ),
    )
    risk_score_id: int | None = Field(
        default=None,
        description="Primary key of the persisted ``risk_scores`` row.",
    )
    risk_score: float = Field(
        default=100.0,
        ge=0.0,
        le=100.0,
        description=(
            "Inverted risk score (0–100, high=worse). Computed as "
            "``100 - predicted_sleep_score`` so sleep rows share the "
            "same axis as vitals risk rows."
        ),
    )
    risk_level: str = Field(default="medium")
    predicted_sleep_score: float = Field(
        default=0.0,
        ge=0.0,
        le=100.0,
        description="Original model-api sleep score (0–100, high=better).",
    )
    model_request_id: str | None = Field(
        default=None,
        description=(
            "Upstream ``meta.request_id`` for end-to-end log correlation "
            "(Phase 2 traceability)."
        ),
    )
