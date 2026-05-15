"""Mobile-side schemas for the Phase 4B IMU window ingest route.

These mirror the upstream healthguard-model-api ``FallPredictionRequest``
shape (`healthguard-model-api/app/schemas/fall.py`) **plus** a
``db_device_id`` field so the backend can resolve the row on
``devices`` without trusting the unauthenticated string ``device_id``
that the model-api uses internally.

Keeping the schemas as a verbatim port of the model-api side means the
mobile / simulator client can serialise once and the backend forwards
the inner ``data`` array unchanged when calling
``ModelApiClient.predict_fall`` — no per-field translation in either
direction.
"""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class AccelData(BaseModel):
    x: float
    y: float
    z: float


class GyroData(BaseModel):
    x: float
    y: float
    z: float


class OrientationData(BaseModel):
    pitch: float
    roll: float
    yaw: float


class EnvironmentData(BaseModel):
    floor_vibration: float = 0.0
    room_occupancy: float = 0.0
    pressure_mat: float = 0.0


class SensorSample(BaseModel):
    """One sensor row at a single timestamp.

    Matches ``healthguard-model-api`` ``SensorSample`` exactly so the
    backend can pass the parsed list straight through to the model-api
    without rebuilding it.
    """

    timestamp: int
    accel: AccelData
    gyro: GyroData
    orientation: OrientationData
    environment: EnvironmentData = Field(default_factory=EnvironmentData)


class ImuWindowRequest(BaseModel):
    """Body for ``POST /api/v1/mobile/telemetry/imu-window``.

    The ``data`` array MUST contain at least 20 samples; the model-api
    config ``fall_min_sequence_samples`` may demand more, in which case
    the upstream call returns a 4xx and the backend treats the window
    as ``status=model_unavailable``. We keep the backend-side minimum
    deliberately loose so a slightly-shorter window from a low-power
    mobile sensor still reaches the upstream where the authoritative
    threshold lives.
    """

    # [HS-015] Reject unknown fields so client typos surface as 422.
    model_config = ConfigDict(extra="forbid")

    db_device_id: int = Field(..., description="`devices.id` of the source watch.")
    sampling_rate: int = Field(default=50, ge=1, le=200)
    window_size: int = Field(default=50, ge=1)
    data: list[SensorSample] = Field(
        ...,
        min_length=20,
        description=(
            "IMU window: one SensorSample per timestep. Must contain at "
            "least 20 entries; the model-api may require more (e.g. 50 at "
            "default 50 Hz)."
        ),
    )


class FallEventResponse(BaseModel):
    """One row from the mobile-facing ``GET /api/v1/mobile/fall-events*`` surface.

    Phase 4B-full slice 2c (see ``backend/docs/risk-contract-baseline.md``
    §7j). Mirrors the columns the Flutter ``fall_alert_screen`` and
    ``fall_history_screen`` actually consume; deliberately leaves out
    GPS noise (``location_accuracy`` is internal — the address string is
    enough for the user) and internal SOS plumbing (``sos_triggered_at``
    surfaces as a derived boolean only).
    """

    id: int
    uuid: str
    device_id: int = Field(..., description="``devices.id`` that produced the event.")
    detected_at: datetime
    confidence: float = Field(..., ge=0.0, le=1.0)
    model_version: str | None = None

    # Location — present when the simulator / watch carried GPS at the time.
    latitude: float | None = None
    longitude: float | None = None
    address: str | None = None

    # User response workflow.
    user_notified_at: datetime | None = Field(
        default=None,
        description="When the push notification was delivered.",
    )
    user_responded_at: datetime | None = Field(
        default=None,
        description="When the user tapped dismiss / confirm.",
    )
    user_cancelled: bool = Field(
        default=False,
        description="``True`` when the user explicitly dismissed the alert.",
    )
    cancel_reason: str | None = Field(
        default=None,
        description="Free-form text the user supplied with a dismiss.",
    )
    sos_triggered: bool = Field(
        default=False,
        description=(
            "``True`` when the auto-SOS escalation fired (i.e. the user did "
            "NOT respond within the configured window)."
        ),
    )

    # Status helper — derived from the workflow timestamps so mobile
    # doesn't have to recompute the state machine.
    status: str = Field(
        ...,
        description=(
            "Derived state: ``detected`` (no user action yet, no SOS), "
            "``dismissed`` (user cancelled), ``confirmed`` (user responded "
            "without cancelling), or ``escalated`` (auto-SOS fired)."
        ),
    )

    # Explainability + traceability bundle — JSONB on the row, surfaced
    # verbatim so a future clinician audience can read SHAP without a
    # second query. Patient surfaces ignore it.
    features: dict | None = Field(
        default=None,
        description=(
            "Snapshot of upstream model-api ``meta`` + ``shap`` payload, "
            "plus ``meta.request_id`` lifted to the top level for log "
            "correlation."
        ),
    )

    # Option 3-Lite (Module FA-2) survey answers; NULL when the user did
    # not reach step 2.  Surfaced so the caregiver-facing UI can render
    # "patient said OK but cannot stand up" or "patient confirmed OK".
    survey_answers: dict | None = Field(
        default=None,
        description=(
            "Stand-up survey from FallStandUpSurveyScreen: "
            "`{can_stand: bool|null, skipped: bool, answered_at: iso}`. "
            "NULL when user did not reach step 2."
        ),
    )

    model_config = {
        # Allow construction directly from a SQLAlchemy ORM instance
        # so the service can ``FallEventResponse.model_validate(row)``.
        "from_attributes": True,
        # ``model_version`` would otherwise trip Pydantic's protected
        # namespace warning; it's a real DB column we deliberately keep.
        "protected_namespaces": (),
    }


class FallEventListResponse(BaseModel):
    """Paginated wrapper around ``FallEventResponse``.

    Matches the existing list-shape conventions on
    :class:`~app.schemas.monitoring.RiskHistoryResponse` so the Flutter
    client can reuse its pagination widgets.
    """

    items: list[FallEventResponse]
    total: int = Field(
        ...,
        description="Total fall events for the current user (across all pages).",
    )
    limit: int
    offset: int


class FallEventDismissRequest(BaseModel):
    """Body for ``POST /api/v1/mobile/fall-events/{id}/dismiss``.

    A single optional reason string. The mobile UI usually offers
    two-three preset chips ("Tôi ổn", "Báo nhầm", ...) plus a free-text
    field; whichever the user picked lands here verbatim.
    """

    # [HS-015] Reject unknown fields so client typos surface as 422.
    model_config = ConfigDict(extra="forbid")

    reason: str | None = Field(
        default=None,
        max_length=255,
        description="Optional free-form reason; persisted to ``cancel_reason``.",
    )


class FallEventDismissResponse(BaseModel):
    """Success body for ``POST /api/v1/mobile/fall-events/{id}/dismiss``.

    Echoes back the updated event so the Flutter client doesn't need a
    second GET to refresh its local state.
    """

    fall_event: FallEventResponse


class FallSurveySubmitRequest(BaseModel):
    """Body for ``POST /api/v1/mobile/fall-events/{id}/survey`` (Module FA-2).

    Option 3-Lite stand-up survey shown after the user dismissed the
    initial fall alert with "Tôi ổn".  Three possible outcomes:

    * ``can_stand=True, skipped=False``  — user confirmed they're up.
      Caregiver gets a soft check-in noti (no SOS).
    * ``can_stand=False, skipped=False`` — user said OK but can't get
      up.  Caregiver gets a *follow-up concern* push so they can call.
    * ``can_stand=None, skipped=True``   — user tapped "Bỏ qua" or
      the 15-second timer expired.  Default-to-safety: caregiver gets
      the same check-in noti ("patient seems OK but did not answer
      stand-up question").
    """

    # [HS-015] Reject unknown fields so client typos surface as 422.
    model_config = ConfigDict(extra="forbid")

    can_stand: bool | None = Field(
        default=None,
        description=(
            "True → patient stood up; False → cannot stand; None → user "
            "skipped or timer expired."
        ),
    )
    skipped: bool = Field(
        default=False,
        description="True when the survey was skipped or timed out.",
    )


class FallSurveySubmitResponse(BaseModel):
    """Success body for ``POST /api/v1/mobile/fall-events/{id}/survey``.

    Echoes the persisted survey so the Flutter client can show the
    confirmation chip without a follow-up GET.  Mirrors the
    ``FallEventDismissResponse`` style.
    """

    fall_event: FallEventResponse


class ImuWindowResponse(BaseModel):
    """Compact summary returned to the simulator / mobile.

    Tuned to be just enough for the caller to decide whether to escalate
    via ``POST /api/v1/mobile/telemetry/alert`` (with the returned
    ``fall_event_id``) or simply log the window for later review.
    """

    status: str = Field(
        ...,
        description=(
            "``ok`` when the upstream returned a prediction and a "
            "``fall_events`` row was persisted. ``model_unavailable`` when "
            "the breaker is open or the upstream errored — no row written."
        ),
    )
    fall_event_id: int | None = Field(
        default=None,
        description="Primary key of the persisted ``fall_events`` row (NULL on ``model_unavailable``).",
    )
    fall_probability: float = Field(default=0.0, ge=0.0, le=1.0)
    prediction_band: str = Field(default="unknown")
    predicted_fall: bool = False
    requires_attention: bool = False
    model_request_id: str | None = Field(
        default=None,
        description=(
            "Upstream ``meta.request_id`` for end-to-end log correlation "
            "(Phase 2 traceability)."
        ),
    )
