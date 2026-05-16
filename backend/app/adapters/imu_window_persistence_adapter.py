"""Adapter for writing one raw IMU window to ``imu_windows`` hypertable.

ADR-022 (IMU Window Persistence — OQ2) / Phase 7 redesign Slice 8.
Companion of :class:`FallPersistenceAdapter`: the fall route persists
both rows (window + event) and then bi-directionally links them.

Inputs:

* ``db_device_id`` — primary key on ``devices``.
* ``payload`` — the validated :class:`~app.schemas.fall_telemetry.ImuWindowRequest`
  the route already parsed. The adapter projects the nested
  :class:`SensorSample` list into the JSONB shape ``imu_windows.accel``
  / ``gyro`` / ``orientation`` expect.
* ``fall_event_id`` — optional; set when the back-link to ``fall_events``
  is known at insert time (current handler ordering: window is inserted
  AFTER the fall row, so ``fall_event_id`` is always populated).
* ``model_request_id`` — optional trace id from the model-api response
  meta block; stored alongside scenario context.

Output: the persisted :class:`ImuWindow` row, refreshed so the caller
has ``id`` + ``time`` available to back-link onto ``fall_events``.
"""

from __future__ import annotations

import logging
from typing import Any

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.imu_window_model import ImuWindow
from app.schemas.fall_telemetry import ImuWindowRequest
from app.utils.datetime_helper import get_current_time

logger = logging.getLogger(__name__)


class ImuPersistenceAdapter:
    """Boundary class for writing one raw IMU window to the hypertable."""

    @staticmethod
    def persist(
        db: Session,
        *,
        db_device_id: int,
        payload: ImuWindowRequest,
        fall_event_id: int | None = None,
        model_request_id: str | None = None,
        scenario_context: dict[str, Any] | None = None,
    ) -> ImuWindow:
        """Insert one ``imu_windows`` row and return the persisted entity.

        Any DB failure rolls back the transaction, logs the device id,
        and raises ``HTTPException 500`` so the FastAPI route surfaces a
        clean error to the simulator.
        """
        accel = ImuPersistenceAdapter._project_accel(payload)
        gyro = ImuPersistenceAdapter._project_gyro(payload)
        orientation = ImuPersistenceAdapter._project_orientation(payload)
        context = ImuPersistenceAdapter._build_context(
            payload=payload,
            scenario_context=scenario_context,
            model_request_id=model_request_id,
        )
        duration = ImuPersistenceAdapter._derive_duration(payload)

        try:
            row = ImuWindow(
                time=get_current_time(),
                device_id=int(db_device_id),
                fall_event_id=fall_event_id,
                accel=accel,
                gyro=gyro,
                orientation=orientation,
                sample_rate_hz=int(payload.sampling_rate),
                duration_seconds=duration,
                context=context,
            )
            db.add(row)
            db.commit()
            db.refresh(row)
        except Exception:
            db.rollback()
            logger.exception(
                "Failed to persist imu_window for device %s", db_device_id
            )
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Không thể lưu IMU window",
            )

        return row

    # ------------------------------------------------------------------
    # Private projection helpers — pure functions for unit testability
    # ------------------------------------------------------------------

    @staticmethod
    def _project_accel(payload: ImuWindowRequest) -> list[dict[str, float]]:
        return [
            {
                "t": sample.timestamp,
                "x": sample.accel.x,
                "y": sample.accel.y,
                "z": sample.accel.z,
            }
            for sample in payload.data
        ]

    @staticmethod
    def _project_gyro(payload: ImuWindowRequest) -> list[dict[str, float]]:
        return [
            {
                "t": sample.timestamp,
                "x": sample.gyro.x,
                "y": sample.gyro.y,
                "z": sample.gyro.z,
            }
            for sample in payload.data
        ]

    @staticmethod
    def _project_orientation(
        payload: ImuWindowRequest,
    ) -> list[dict[str, float]] | None:
        """Skip the column entirely when every sample is default zero.

        The Pydantic schema defaults ``orientation`` to ``(0, 0, 0)``
        when the source device omits the channel, so storing the array
        would waste rows that carry no real signal. We keep the column
        nullable and only persist a non-zero stream.
        """
        rendered = [
            {
                "t": sample.timestamp,
                "pitch": sample.orientation.pitch,
                "roll": sample.orientation.roll,
                "yaw": sample.orientation.yaw,
            }
            for sample in payload.data
        ]
        any_signal = any(
            row["pitch"] != 0.0 or row["roll"] != 0.0 or row["yaw"] != 0.0
            for row in rendered
        )
        return rendered if any_signal else None

    @staticmethod
    def _build_context(
        *,
        payload: ImuWindowRequest,
        scenario_context: dict[str, Any] | None,
        model_request_id: str | None,
    ) -> dict[str, Any] | None:
        """Merge handler + simulator context onto the JSONB blob.

        Returns ``None`` (so the column stays NULL) when neither the
        caller nor the route knows anything beyond the raw window.
        """
        context: dict[str, Any] = {}
        if scenario_context:
            for key, value in scenario_context.items():
                if value is not None:
                    context[str(key)] = value
        if model_request_id:
            context["model_request_id"] = model_request_id
        # Always record the schema-declared window size so consumers can
        # cross-check the array length without scanning.
        context["window_size"] = int(payload.window_size)
        return context or None

    @staticmethod
    def _derive_duration(payload: ImuWindowRequest) -> float:
        """Compute window length in seconds from sample count + rate.

        Defaults to the schema's 2.0s when the source data is shorter
        than the declared sampling rate. Clamped to the migration CHECK
        constraint (0 < duration_seconds <= 60).
        """
        sample_count = len(payload.data)
        rate = max(1, int(payload.sampling_rate))
        derived = sample_count / rate
        if derived <= 0:
            return 2.0
        if derived > 60:
            return 60.0
        return float(derived)
