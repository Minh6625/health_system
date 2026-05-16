"""SQLAlchemy model for the ``imu_windows`` TimescaleDB hypertable.

ADR-022 (IMU Window Persistence — OQ2) / Phase 7 redesign Slice 8.

The table holds the raw accel/gyro window the simulator/mobile posts to
``POST /api/v1/mobile/telemetry/imu-window`` so admin web can replay
false-positive cases and the dataset is available for retrain. Bounded
growth via TimescaleDB native retention (7 days) and compression policy
(1 day) — see ``migrations/20260516_imu_windows_hypertable.sql``.

Schema notes:

* Composite primary key ``(id, time)`` — TimescaleDB requires the
  partitioning column (``time``) to be part of every unique constraint
  on a hypertable, but downstream code (``fall_events.imu_window_id``)
  only carries the surrogate ``id``. The matching ``time`` value is
  duplicated onto ``fall_events.imu_window_time`` so the composite FK
  ``(imu_window_id, imu_window_time) -> imu_windows(id, time)`` stays
  enforceable.
* ``accel`` / ``gyro`` / ``orientation`` keep the model-api payload
  shape verbatim — list of ``{x, y, z}`` (or ``{pitch, roll, yaw}``)
  dicts. Stored as JSONB so a replay tool can render the original window
  without a per-sample table.
* ``fall_event_id`` is nullable so a window can be persisted before the
  fall row exists (write order in the handler) and back-linked after.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any, Optional

from sqlalchemy import BigInteger, CheckConstraint, DateTime, ForeignKey, Index, Integer
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import text

from app.db.database import Base
from app.utils.datetime_helper import get_current_time


class ImuWindow(Base):
    """One raw IMU window persisted from ``/telemetry/imu-window``."""

    __tablename__ = "imu_windows"

    __table_args__ = (
        CheckConstraint(
            "sample_rate_hz > 0 AND sample_rate_hz <= 200",
            name="check_imu_windows_sample_rate",
        ),
        CheckConstraint(
            "duration_seconds > 0 AND duration_seconds <= 60",
            name="check_imu_windows_duration",
        ),
        # Match the migration index — admin web fetches the latest N
        # windows for a device, hence (device_id, time DESC).
        Index("idx_imu_windows_device_time", "device_id", "time"),
        # Partial index — only the ~1-in-1000 rows that link to a fall
        # event are scanned by the join-back path.
        Index(
            "idx_imu_windows_fall_event",
            "fall_event_id",
            postgresql_where=text("fall_event_id IS NOT NULL"),
        ),
    )

    # Composite primary key (id, time). SQLAlchemy expresses this by
    # marking both columns as primary keys.
    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    time: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        primary_key=True,
    )

    device_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("devices.id", ondelete="CASCADE"),
        nullable=False,
    )
    fall_event_id: Mapped[Optional[int]] = mapped_column(
        Integer,
        ForeignKey("fall_events.id", ondelete="SET NULL"),
        nullable=True,
    )

    # Raw signal — preserved exactly as posted so the replay viewer can
    # reconstruct the original window without an inverse transform.
    accel: Mapped[list[dict[str, Any]]] = mapped_column(JSONB, nullable=False)
    gyro: Mapped[list[dict[str, Any]]] = mapped_column(JSONB, nullable=False)
    orientation: Mapped[Optional[list[dict[str, Any]]]] = mapped_column(
        JSONB, nullable=True
    )

    sample_rate_hz: Mapped[int] = mapped_column(Integer, nullable=False, default=50)
    duration_seconds: Mapped[float] = mapped_column(nullable=False, default=2.0)

    # Free-form scenario tag the simulator attaches (scenario_id,
    # variant, activity_before, model_request_id). Optional.
    context: Mapped[Optional[dict[str, Any]]] = mapped_column(JSONB, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=get_current_time,
    )
