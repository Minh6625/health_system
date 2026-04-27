"""Integration tests for the breaker wired into ``ModelApiClient``.

These are the tests that prove Phase 7's value proposition: with the
breaker tripped, subsequent calls return ``None`` immediately without
paying the timeout cost. We use a fake httpx transport to deterministically
inject ``ConnectError`` / ``HTTPStatusError`` failures.
"""

from __future__ import annotations

from typing import Any, Callable

import httpx
import pytest

from app.observability.timing import (
    clear_test_listeners,
    subscribe_for_tests,
)
from app.services.circuit_breaker import CircuitBreaker, CircuitState
from app.services.model_api_client import ModelApiClient


def _ok_health_response() -> httpx.Response:
    return httpx.Response(
        200,
        json={
            "results": [
                {
                    "status": "ok",
                    "risk_level": "low",
                    "predicted_health_risk_probability": 0.1,
                    "prediction": {
                        "prediction_label": "low",
                        "prediction_score": 0.1,
                        "prediction_band": "normal",
                    },
                }
            ]
        },
    )


def _build_client_with_handler(
    handler: Callable[[httpx.Request], httpx.Response],
    *,
    failure_threshold: int = 3,
) -> tuple[ModelApiClient, _Counter]:
    counter = _Counter()

    def _wrapped(request: httpx.Request) -> httpx.Response:
        counter.calls += 1
        return handler(request)

    transport = httpx.MockTransport(_wrapped)
    breaker = CircuitBreaker(
        "test_health",
        failure_threshold=failure_threshold,
        reset_timeout_seconds=60.0,
        clock=lambda: 0.0,
    )
    client = ModelApiClient(
        base_url="http://stub",
        timeout_seconds=1.0,
        health_breaker=breaker,
    )
    # Replace the lazy httpx.Client with one bound to MockTransport.
    client._client = httpx.Client(  # noqa: SLF001 - explicit test seam
        base_url="http://stub",
        transport=transport,
        headers={"X-Internal-Service": "health-system-backend"},
    )
    return client, counter


class _Counter:
    def __init__(self) -> None:
        self.calls = 0


# ---------------------------------------------------------------------------
# Breaker behaviour on the model-api client
# ---------------------------------------------------------------------------


class TestHealthBreakerTripsOnConnectionFailures:
    def test_three_connect_errors_trip_breaker_open(self) -> None:
        def _always_connect_error(_request: httpx.Request) -> httpx.Response:
            raise httpx.ConnectError("simulated outage")

        client, counter = _build_client_with_handler(
            _always_connect_error, failure_threshold=3
        )

        assert client.health_breaker.state == CircuitState.CLOSED
        for _ in range(3):
            assert client.predict_health_risk({"heart_rate": 80.0}) is None
        assert client.health_breaker.state == CircuitState.OPEN
        assert counter.calls == 3

    def test_subsequent_call_short_circuits_without_hitting_upstream(self) -> None:
        def _always_connect_error(_request: httpx.Request) -> httpx.Response:
            raise httpx.ConnectError("simulated outage")

        client, counter = _build_client_with_handler(
            _always_connect_error, failure_threshold=3
        )
        for _ in range(3):
            client.predict_health_risk({"heart_rate": 80.0})
        assert counter.calls == 3

        # Breaker is now OPEN — these calls must NOT touch the transport.
        for _ in range(5):
            assert client.predict_health_risk({"heart_rate": 80.0}) is None
        assert counter.calls == 3, (
            "with breaker open, no further upstream calls should be issued"
        )


class TestHealthBreakerCountsServerErrorsToward5xxStorms:
    def test_three_500_responses_trip_breaker(self) -> None:
        def _server_error(_request: httpx.Request) -> httpx.Response:
            return httpx.Response(503, text="upstream draining")

        client, counter = _build_client_with_handler(
            _server_error, failure_threshold=3
        )
        for _ in range(3):
            assert client.predict_health_risk({"heart_rate": 80.0}) is None
        assert client.health_breaker.state == CircuitState.OPEN

        # And then short-circuits.
        client.predict_health_risk({"heart_rate": 80.0})
        assert counter.calls == 3


class TestHealthBreakerDoesNotTripOnContractBugs:
    def test_malformed_json_does_not_count_toward_breaker(self) -> None:
        def _malformed(_request: httpx.Request) -> httpx.Response:
            return httpx.Response(200, content=b"not-valid-json")

        client, _ = _build_client_with_handler(_malformed, failure_threshold=2)
        for _ in range(5):
            assert client.predict_health_risk({"heart_rate": 80.0}) is None
        # 5 calls with malformed JSON — breaker still closed because the
        # upstream is reachable; the issue is a contract bug.
        assert client.health_breaker.state == CircuitState.CLOSED


class TestHealthBreakerSuccessClosesOnRecovery:
    def test_a_single_success_resets_failure_counter(self) -> None:
        # Toggle: first 2 fail, then 1 success, then 2 more failures.
        # If the success reset the counter, the breaker stays CLOSED.
        sequence: list[Callable[[httpx.Request], httpx.Response]] = [
            lambda _r: (_ for _ in ()).throw(httpx.ConnectError("fail")),
            lambda _r: (_ for _ in ()).throw(httpx.ConnectError("fail")),
            lambda _r: _ok_health_response(),
            lambda _r: (_ for _ in ()).throw(httpx.ConnectError("fail")),
            lambda _r: (_ for _ in ()).throw(httpx.ConnectError("fail")),
        ]
        idx = {"i": 0}

        def _dispatch(request: httpx.Request) -> httpx.Response:
            i = idx["i"]
            idx["i"] += 1
            return sequence[i](request)

        client, _ = _build_client_with_handler(_dispatch, failure_threshold=3)
        for _ in range(5):
            client.predict_health_risk({"heart_rate": 80.0})

        assert client.health_breaker.state == CircuitState.CLOSED


# ---------------------------------------------------------------------------
# Timing observability is wired in
# ---------------------------------------------------------------------------


class TestTimingEmissionFromModelApiClient:
    @pytest.fixture
    def captured(self) -> list[dict[str, Any]]:
        events: list[dict[str, Any]] = []
        subscribe_for_tests(events.append)
        yield events
        clear_test_listeners()

    def test_predict_health_risk_emits_model_api_call_timing(
        self, captured: list[dict[str, Any]]
    ) -> None:
        client, _ = _build_client_with_handler(lambda _r: _ok_health_response())
        client.predict_health_risk({"heart_rate": 80.0})

        timing_events = [e for e in captured if e["stage"] == "model_api_call"]
        assert len(timing_events) == 1
        assert timing_events[0]["endpoint"] == "health_predict"
        assert timing_events[0]["elapsed_ms"] >= 0.0

    def test_short_circuited_call_does_not_emit_timing(
        self, captured: list[dict[str, Any]]
    ) -> None:
        # Trip the breaker first.
        def _connect_error(_request: httpx.Request) -> httpx.Response:
            raise httpx.ConnectError("simulated outage")

        client, _ = _build_client_with_handler(_connect_error, failure_threshold=2)
        for _ in range(2):
            client.predict_health_risk({"heart_rate": 80.0})

        # Capture only what comes AFTER the breaker is open.
        captured.clear()
        client.predict_health_risk({"heart_rate": 80.0})
        # Short-circuited path skips StageTimer entirely — no events.
        assert [e for e in captured if e["stage"] == "model_api_call"] == []
