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

from pydantic import BaseModel, Field


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
    """Body for ``POST /mobile/telemetry/imu-window``.

    The ``data`` array MUST contain at least 20 samples; the model-api
    config ``fall_min_sequence_samples`` may demand more, in which case
    the upstream call returns a 4xx and the backend treats the window
    as ``status=model_unavailable``. We keep the backend-side minimum
    deliberately loose so a slightly-shorter window from a low-power
    mobile sensor still reaches the upstream where the authoritative
    threshold lives.
    """

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


class ImuWindowResponse(BaseModel):
    """Compact summary returned to the simulator / mobile.

    Tuned to be just enough for the caller to decide whether to escalate
    via ``POST /mobile/telemetry/alert`` (with the returned
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
