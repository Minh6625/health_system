"""Unit tests for ``app.services.circuit_breaker.CircuitBreaker``.

The breaker is the only thing standing between a sustained model-api
outage and the per-request 5s timeout cost on every incoming risk
calculation, so its state machine is exercised explicitly here. Every
test injects a deterministic ``clock`` so we do not have to sleep.
"""

from __future__ import annotations

import pytest

from app.services.circuit_breaker import CircuitBreaker, CircuitState


class _FakeClock:
    """Manual clock — ``advance(seconds)`` to move time forward."""

    def __init__(self, start: float = 0.0) -> None:
        self.now = start

    def __call__(self) -> float:
        return self.now

    def advance(self, seconds: float) -> None:
        self.now += seconds


@pytest.fixture
def clock() -> _FakeClock:
    return _FakeClock()


@pytest.fixture
def breaker(clock: _FakeClock) -> CircuitBreaker:
    return CircuitBreaker(
        "test",
        failure_threshold=3,
        reset_timeout_seconds=60.0,
        clock=clock,
    )


# ---------------------------------------------------------------------------
# Initial state
# ---------------------------------------------------------------------------


class TestInitialState:
    def test_breaker_starts_closed(self, breaker: CircuitBreaker) -> None:
        assert breaker.state == CircuitState.CLOSED
        assert breaker.should_skip_call() is False

    def test_snapshot_reports_closed_zero_failures(
        self, breaker: CircuitBreaker
    ) -> None:
        snap = breaker.snapshot()
        assert snap["state"] == "closed"
        assert snap["consecutive_failures"] == 0
        assert snap["opened_at"] is None


# ---------------------------------------------------------------------------
# CLOSED -> OPEN
# ---------------------------------------------------------------------------


class TestTrippingOpen:
    def test_failures_below_threshold_keep_closed(
        self, breaker: CircuitBreaker
    ) -> None:
        breaker.record_failure()
        breaker.record_failure()
        assert breaker.state == CircuitState.CLOSED
        assert breaker.should_skip_call() is False

    def test_threshold_failures_trip_open(self, breaker: CircuitBreaker) -> None:
        for _ in range(3):
            breaker.record_failure()
        assert breaker.state == CircuitState.OPEN
        assert breaker.should_skip_call() is True

    def test_success_resets_consecutive_failure_counter(
        self, breaker: CircuitBreaker
    ) -> None:
        breaker.record_failure()
        breaker.record_failure()
        breaker.record_success()
        # Two more failures should NOT trip — counter was reset to 0.
        breaker.record_failure()
        breaker.record_failure()
        assert breaker.state == CircuitState.CLOSED


# ---------------------------------------------------------------------------
# OPEN -> HALF_OPEN -> CLOSED
# ---------------------------------------------------------------------------


class TestRecovery:
    def test_open_stays_open_until_reset_window_elapses(
        self, breaker: CircuitBreaker, clock: _FakeClock
    ) -> None:
        for _ in range(3):
            breaker.record_failure()
        assert breaker.state == CircuitState.OPEN

        clock.advance(30.0)
        assert breaker.state == CircuitState.OPEN
        assert breaker.should_skip_call() is True

        clock.advance(29.0)  # total 59s — still under 60s window
        assert breaker.state == CircuitState.OPEN

    def test_open_advances_to_half_open_after_reset_window(
        self, breaker: CircuitBreaker, clock: _FakeClock
    ) -> None:
        for _ in range(3):
            breaker.record_failure()
        assert breaker.state == CircuitState.OPEN

        clock.advance(60.0)
        assert breaker.state == CircuitState.HALF_OPEN
        assert breaker.should_skip_call() is False

    def test_half_open_success_returns_to_closed(
        self, breaker: CircuitBreaker, clock: _FakeClock
    ) -> None:
        for _ in range(3):
            breaker.record_failure()
        clock.advance(60.0)
        assert breaker.state == CircuitState.HALF_OPEN

        breaker.record_success()
        assert breaker.state == CircuitState.CLOSED
        assert breaker.snapshot()["consecutive_failures"] == 0

    def test_half_open_failure_re_opens_breaker_for_full_window(
        self, breaker: CircuitBreaker, clock: _FakeClock
    ) -> None:
        for _ in range(3):
            breaker.record_failure()
        clock.advance(60.0)
        assert breaker.state == CircuitState.HALF_OPEN

        breaker.record_failure()
        assert breaker.state == CircuitState.OPEN

        # 30s after the re-open: still open (window restarted).
        clock.advance(30.0)
        assert breaker.state == CircuitState.OPEN

        # 60s after the re-open: probing again.
        clock.advance(30.0)
        assert breaker.state == CircuitState.HALF_OPEN


# ---------------------------------------------------------------------------
# Misc / hooks
# ---------------------------------------------------------------------------


class TestResetHook:
    def test_reset_returns_to_closed_immediately(
        self, breaker: CircuitBreaker, clock: _FakeClock
    ) -> None:
        for _ in range(3):
            breaker.record_failure()
        assert breaker.state == CircuitState.OPEN

        breaker.reset()
        assert breaker.state == CircuitState.CLOSED
        assert breaker.snapshot()["consecutive_failures"] == 0


class TestEnvDefaults:
    def test_env_overrides_failure_threshold(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setenv("MODEL_API_BREAKER_FAILURES", "2")
        b = CircuitBreaker("env-test", clock=lambda: 0.0)
        b.record_failure()
        assert b.state == CircuitState.CLOSED
        b.record_failure()
        assert b.state == CircuitState.OPEN

    def test_invalid_env_falls_back_to_default(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setenv("MODEL_API_BREAKER_FAILURES", "not-a-number")
        b = CircuitBreaker("env-test", clock=lambda: 0.0)
        # Default is 5 — three failures should not trip.
        for _ in range(3):
            b.record_failure()
        assert b.state == CircuitState.CLOSED
