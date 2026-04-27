"""Unit tests for ``app.observability.timing``.

The helper has two surfaces — a function and a context manager — and
exposes a test-only listener API. Every test cleans up its listener
through the fixture so cross-test pollution is impossible.
"""

from __future__ import annotations

import logging
import time
from typing import Any

import pytest

from app.observability.timing import (
    StageTimer,
    TIMING_LOG_PREFIX,
    clear_test_listeners,
    record_timing,
    subscribe_for_tests,
)


@pytest.fixture
def captured_events() -> list[dict[str, Any]]:
    """Capture every ``record_timing`` payload emitted during the test."""
    events: list[dict[str, Any]] = []
    subscribe_for_tests(events.append)
    yield events
    clear_test_listeners()


# ---------------------------------------------------------------------------
# record_timing
# ---------------------------------------------------------------------------


class TestRecordTiming:
    def test_emits_payload_to_listener(
        self, captured_events: list[dict[str, Any]]
    ) -> None:
        record_timing("model_api_call", 42.5, endpoint="health_predict")
        assert captured_events == [
            {"stage": "model_api_call", "elapsed_ms": 42.5, "endpoint": "health_predict"}
        ]

    def test_rounds_elapsed_ms_to_3_decimals(
        self, captured_events: list[dict[str, Any]]
    ) -> None:
        record_timing("persist", 12.3456789)
        assert captured_events[0]["elapsed_ms"] == 12.346

    def test_emits_log_line_prefixed_with_channel(
        self,
        captured_events: list[dict[str, Any]],
        caplog: pytest.LogCaptureFixture,
    ) -> None:
        with caplog.at_level(logging.INFO, logger="app.observability.timing"):
            record_timing("build_record", 3.1, device_id=42)

        assert any(
            TIMING_LOG_PREFIX in record.getMessage() for record in caplog.records
        ), "every timing must emit one risk.timing log line"

    def test_listener_exception_does_not_break_caller(
        self,
        caplog: pytest.LogCaptureFixture,
    ) -> None:
        # A buggy listener must never propagate into the production code
        # path — record_timing fires on the hot path of every request.
        def _broken(_payload: dict[str, Any]) -> None:
            raise RuntimeError("boom")

        subscribe_for_tests(_broken)
        try:
            with caplog.at_level(logging.ERROR, logger="app.observability.timing"):
                record_timing("model_api_call", 5.0)  # must not raise
            assert any(
                "listener raised" in record.getMessage() for record in caplog.records
            )
        finally:
            clear_test_listeners()


# ---------------------------------------------------------------------------
# StageTimer
# ---------------------------------------------------------------------------


class TestStageTimer:
    def test_records_elapsed_ms_on_normal_exit(
        self, captured_events: list[dict[str, Any]]
    ) -> None:
        with StageTimer("persist", backend="rule_based"):
            pass
        assert len(captured_events) == 1
        evt = captured_events[0]
        assert evt["stage"] == "persist"
        assert evt["backend"] == "rule_based"
        assert isinstance(evt["elapsed_ms"], float)
        assert evt["elapsed_ms"] >= 0.0

    def test_still_records_when_block_raises(
        self, captured_events: list[dict[str, Any]]
    ) -> None:
        # Outage timing dashboards depend on the failing call still
        # being timed — the elapsed_ms is exactly the cost of the
        # timeout, which is what we want to chart.
        with pytest.raises(ValueError):
            with StageTimer("model_api_call", endpoint="health_predict"):
                raise ValueError("simulated upstream timeout")

        assert len(captured_events) == 1
        assert captured_events[0]["stage"] == "model_api_call"
        assert captured_events[0]["endpoint"] == "health_predict"

    def test_elapsed_ms_reflects_real_wall_clock(
        self, captured_events: list[dict[str, Any]]
    ) -> None:
        # Sleep for a small amount and verify the timer captured at
        # least that much. Loose lower bound to keep the test resilient.
        with StageTimer("build_record"):
            time.sleep(0.01)
        assert captured_events[0]["elapsed_ms"] >= 5.0
