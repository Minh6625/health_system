"""Stage timing helpers for the risk pipeline.

Two surfaces:

* :func:`record_timing(stage, elapsed_ms, **fields)` — emit one
  structured INFO log line so an aggregator can build histograms.
  Keeping it a plain log keeps the backend free of a metrics runtime
  dependency (statsd / prometheus_client) until Phase 7+ infrastructure
  is in place.
* :class:`StageTimer` — tiny ``with`` block that calls ``record_timing``
  for the wrapped block. Use it inline at the call site so the stage
  name lives next to the code being timed.

Tests can subscribe via :func:`subscribe_for_tests` to capture every
``record_timing`` call without having to parse log output.
"""

from __future__ import annotations

import logging
import time
from contextlib import contextmanager
from typing import Any, Callable, Iterator

logger = logging.getLogger(__name__)

#: Channel used by every emitted log line — lets the aggregator filter
#: timing events away from the rest of the application logs.
TIMING_LOG_PREFIX = "risk.timing"

#: Test-only sink. Production code never reads this; tests register a
#: callback through :func:`subscribe_for_tests` and read it back to
#: assert that the expected stages were timed in the expected order.
_TEST_LISTENERS: list[Callable[[dict[str, Any]], None]] = []


def record_timing(stage: str, elapsed_ms: float, /, **fields: Any) -> None:
    """Record one stage timing as a structured log line.

    ``stage`` should be one of the four canonical names listed in the
    package docstring (``build_record`` / ``model_api_call`` / ``persist``
    / ``build_dto``); free-form names are accepted but consumers may not
    chart them.

    ``elapsed_ms`` is the wall-clock duration in milliseconds. Pass
    ``time.monotonic()`` deltas (multiplied by 1000) — wall-clock-aware
    aggregations live downstream in the log layer.

    Extra ``**fields`` (e.g. ``device_id=42``, ``backend="model_api_health"``)
    are merged into the log record so dashboards can slice by tag.
    """
    payload = {"stage": stage, "elapsed_ms": round(elapsed_ms, 3), **fields}
    logger.info("%s %s", TIMING_LOG_PREFIX, payload)
    for listener in tuple(_TEST_LISTENERS):
        try:
            listener(payload)
        except Exception:  # noqa: BLE001 - never let listener bugs break callers
            logger.exception("risk.timing listener raised; ignoring")


@contextmanager
def StageTimer(stage: str, /, **fields: Any) -> Iterator[None]:
    """Context manager that records elapsed wall-clock time on exit.

    Usage::

        with StageTimer("model_api_call", backend="model_api_health"):
            response = client.predict_health_risk(record)

    The timer fires unconditionally on ``__exit__``, including when an
    exception propagates out of the block (the ``elapsed_ms`` still
    reflects how long the failing call took, which is exactly what you
    want for outage timing dashboards).
    """
    start = time.monotonic()
    try:
        yield
    finally:
        elapsed_ms = (time.monotonic() - start) * 1000.0
        record_timing(stage, elapsed_ms, **fields)


def subscribe_for_tests(listener: Callable[[dict[str, Any]], None]) -> None:
    """Register a listener invoked synchronously on every ``record_timing``.

    Tests should always call :func:`unsubscribe_for_tests` (or use a
    pytest fixture) to remove the listener afterwards so cross-test
    leakage cannot happen.
    """
    _TEST_LISTENERS.append(listener)


def unsubscribe_for_tests(listener: Callable[[dict[str, Any]], None]) -> None:
    """Mirror of :func:`subscribe_for_tests`; idempotent."""
    try:
        _TEST_LISTENERS.remove(listener)
    except ValueError:
        pass


def clear_test_listeners() -> None:
    """Test hook: drop every registered listener."""
    _TEST_LISTENERS.clear()


__all__ = [
    "TIMING_LOG_PREFIX",
    "StageTimer",
    "record_timing",
    "subscribe_for_tests",
    "unsubscribe_for_tests",
    "clear_test_listeners",
]
