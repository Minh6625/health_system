"""Unit tests for :class:`ImuPersistenceAdapter` (ADR-022 Phase 7 S8).

The DB write itself is exercised end-to-end through the route in
``test_imu_window_route.py`` once that file is updated to mock the
adapter at the route level. The tests in this file focus on the
**pure projection helpers** that prepare the JSONB columns:

* ``_project_accel`` / ``_project_gyro`` — shape conversion from
  Pydantic ``SensorSample`` to ``{"t", "x", "y", "z"}`` JSONB rows.
* ``_project_orientation`` — None when every sample is zero (skip
  storing default-filled orientation), otherwise the projected list.
* ``_build_context`` — merges simulator context + ``model_request_id``
  + ``window_size`` into a single JSONB blob; None when nothing useful.
* ``_derive_duration`` — sample_count / sample_rate with clamping.
"""

from __future__ import annotations

from typing import Any

import pytest

from app.adapters.imu_window_persistence_adapter import ImuPersistenceAdapter
from app.schemas.fall_telemetry import ImuWindowRequest


def _make_payload(
    *,
    sample_count: int = 25,
    sampling_rate: int = 50,
    orientation_pitch: float = 0.0,
    orientation_roll: float = 0.0,
    orientation_yaw: float = 0.0,
) -> ImuWindowRequest:
    samples = [
        {
            "timestamp": i * 20,
            "accel": {"x": 0.1 + i * 0.01, "y": 0.2, "z": 1.0 - i * 0.01},
            "gyro": {"x": 5.0, "y": -2.0, "z": 1.0},
            "orientation": {
                "pitch": orientation_pitch,
                "roll": orientation_roll,
                "yaw": orientation_yaw,
            },
        }
        for i in range(sample_count)
    ]
    return ImuWindowRequest.model_validate(
        {
            "db_device_id": 42,
            "sampling_rate": sampling_rate,
            "window_size": sample_count,
            "data": samples,
        }
    )


class TestProjectAccel:
    def test_returns_one_row_per_sample(self) -> None:
        payload = _make_payload(sample_count=25)
        rendered = ImuPersistenceAdapter._project_accel(payload)
        assert len(rendered) == 25

    def test_preserves_x_y_z_and_timestamp(self) -> None:
        payload = _make_payload(sample_count=20)
        rendered = ImuPersistenceAdapter._project_accel(payload)
        assert rendered[0] == {"t": 0, "x": pytest.approx(0.10), "y": 0.2, "z": pytest.approx(1.0)}
        assert rendered[2]["t"] == 40
        assert rendered[2]["x"] == pytest.approx(0.12)


class TestProjectGyro:
    def test_returns_one_row_per_sample(self) -> None:
        payload = _make_payload(sample_count=22)
        rendered = ImuPersistenceAdapter._project_gyro(payload)
        assert len(rendered) == 22

    def test_preserves_x_y_z_and_timestamp(self) -> None:
        payload = _make_payload(sample_count=20)
        rendered = ImuPersistenceAdapter._project_gyro(payload)
        for row in rendered:
            assert row["x"] == 5.0
            assert row["y"] == -2.0
            assert row["z"] == 1.0


class TestProjectOrientation:
    def test_returns_none_when_all_zero(self) -> None:
        payload = _make_payload(sample_count=20)
        # Default sample uses pitch=roll=yaw=0.0 — should skip the column.
        assert ImuPersistenceAdapter._project_orientation(payload) is None

    def test_returns_rows_when_any_signal_present(self) -> None:
        payload = _make_payload(sample_count=20, orientation_pitch=0.4)
        rendered = ImuPersistenceAdapter._project_orientation(payload)
        assert rendered is not None
        assert len(rendered) == 20
        assert rendered[0]["pitch"] == pytest.approx(0.4)
        assert rendered[0]["roll"] == 0.0
        assert rendered[0]["yaw"] == 0.0

    def test_returns_rows_when_only_yaw_signal_present(self) -> None:
        payload = _make_payload(sample_count=20, orientation_yaw=1.2)
        rendered = ImuPersistenceAdapter._project_orientation(payload)
        assert rendered is not None
        assert rendered[3]["yaw"] == pytest.approx(1.2)


class TestBuildContext:
    def test_returns_window_size_even_without_scenario(self) -> None:
        payload = _make_payload(sample_count=25)
        ctx = ImuPersistenceAdapter._build_context(
            payload=payload,
            scenario_context=None,
            model_request_id=None,
        )
        # Always stores window_size so consumers can cross-check the
        # array length without scanning. Document the actual contract:
        # window_size is always present, even when neither scenario nor
        # request id is provided.
        assert ctx is not None
        assert ctx == {"window_size": 25}

    def test_merges_scenario_dict_skipping_nones(self) -> None:
        payload = _make_payload(sample_count=20)
        ctx = ImuPersistenceAdapter._build_context(
            payload=payload,
            scenario_context={"scenario_id": "fall_forward", "variant": None},
            model_request_id=None,
        )
        assert ctx is not None
        assert ctx["scenario_id"] == "fall_forward"
        assert "variant" not in ctx
        assert ctx["window_size"] == 20

    def test_adds_model_request_id_when_provided(self) -> None:
        payload = _make_payload(sample_count=21)
        ctx = ImuPersistenceAdapter._build_context(
            payload=payload,
            scenario_context=None,
            model_request_id="req-1234-abcd",
        )
        assert ctx is not None
        assert ctx["model_request_id"] == "req-1234-abcd"
        assert ctx["window_size"] == 21


class TestDeriveDuration:
    def test_50hz_50_samples_is_one_second(self) -> None:
        payload = _make_payload(sample_count=50, sampling_rate=50)
        assert ImuPersistenceAdapter._derive_duration(payload) == pytest.approx(1.0)

    def test_50hz_100_samples_is_two_seconds(self) -> None:
        payload = _make_payload(sample_count=100, sampling_rate=50)
        assert ImuPersistenceAdapter._derive_duration(payload) == pytest.approx(2.0)

    def test_clamps_to_sixty_seconds_upper_bound(self) -> None:
        # 4000 samples at 50 Hz = 80 seconds, but the CHECK constraint
        # caps duration_seconds at 60 — adapter must clamp.
        payload = _make_payload(sample_count=4000, sampling_rate=50)
        assert ImuPersistenceAdapter._derive_duration(payload) == 60.0

    def test_falls_back_to_two_when_empty(self) -> None:
        # The schema forbids empty `data` (min_length=20), so we can't
        # build an ImuWindowRequest with 0 samples; instead we hand the
        # helper a tiny stand-in object that mirrors the relevant
        # attributes. The defensive default exists to protect against a
        # future schema relaxation, hence the unit test.
        class _Stub:
            data: list[Any] = []
            sampling_rate = 50
            window_size = 0

        assert ImuPersistenceAdapter._derive_duration(_Stub()) == 2.0
