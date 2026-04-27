"""Tiny in-process circuit breaker for the model-api client.

Phase 7 (see ``backend/docs/risk-contract-baseline.md``) wraps every
outbound call to the external healthguard-model-api so a sustained
outage does not pay the full per-request timeout cost on every
incoming risk calculation.

State machine
-------------

::

    CLOSED  --(>= failure_threshold consecutive failures)-->  OPEN
    OPEN    --(reset_timeout elapsed)-->                       HALF_OPEN
    HALF_OPEN --(success)-->                                   CLOSED
    HALF_OPEN --(failure)-->                                   OPEN  (timer reset)

* ``CLOSED``: every call is forwarded.
* ``OPEN``: every call is short-circuited (the breaker reports it should
  be skipped) for ``reset_timeout_seconds``.
* ``HALF_OPEN``: a single probe call is allowed; success closes the
  breaker, failure re-opens it for another full window.

Why a hand-rolled implementation
--------------------------------

The plan suggested ``pybreaker``, but the requirements here are tiny:
sync only, no decorator metaclasses, no metrics emission (timing is
handled separately in :mod:`app.observability.timing`). A 70-line module
with explicit state transitions is easier to reason about and ships
without an extra runtime dependency.

The breaker is **process-local**. With multiple worker processes (e.g.
gunicorn) each will track its own state. That is intentional: the goal
is to amortise the timeout cost on each worker, not to coordinate across
the cluster. A dropped model-api will trip every worker independently
within ``failure_threshold`` requests.
"""

from __future__ import annotations

import logging
import os
import threading
import time
from enum import Enum
from typing import Callable

logger = logging.getLogger(__name__)


_DEFAULT_FAILURE_THRESHOLD = 5
_DEFAULT_RESET_TIMEOUT_SECONDS = 60.0


class CircuitState(str, Enum):
    """Three-state breaker: closed, open, half-open."""

    CLOSED = "closed"
    OPEN = "open"
    HALF_OPEN = "half_open"


class CircuitBreaker:
    """Sync-friendly breaker around any outbound call.

    Typical usage from the model-api client::

        if self._breaker.should_skip_call():
            return None
        try:
            response = self._http.post(...)
        except httpx.HTTPError:
            self._breaker.record_failure()
            return None
        self._breaker.record_success()
        return response

    Parameters
    ----------
    name:
        Used in log lines so multiple breakers (health vs fall) are
        distinguishable.
    failure_threshold:
        Number of *consecutive* failures that trip the breaker open.
        Defaults to 5; configurable via ``MODEL_API_BREAKER_FAILURES`` env.
    reset_timeout_seconds:
        How long to stay open before allowing a probe. Defaults to 60s;
        configurable via ``MODEL_API_BREAKER_RESET_SECONDS`` env.
    clock:
        Injectable monotonic clock for deterministic tests. Defaults to
        :func:`time.monotonic`.
    """

    def __init__(
        self,
        name: str = "default",
        *,
        failure_threshold: int | None = None,
        reset_timeout_seconds: float | None = None,
        clock: Callable[[], float] | None = None,
    ) -> None:
        self.name = name
        self._failure_threshold = (
            failure_threshold
            if failure_threshold is not None
            else _read_int_env("MODEL_API_BREAKER_FAILURES", _DEFAULT_FAILURE_THRESHOLD)
        )
        self._reset_timeout = (
            reset_timeout_seconds
            if reset_timeout_seconds is not None
            else _read_float_env(
                "MODEL_API_BREAKER_RESET_SECONDS", _DEFAULT_RESET_TIMEOUT_SECONDS
            )
        )
        self._clock = clock or time.monotonic
        self._lock = threading.Lock()
        self._state = CircuitState.CLOSED
        self._consecutive_failures = 0
        # ``_opened_at`` is None unless the breaker is OPEN; on transition to
        # HALF_OPEN we reset to None so a subsequent failure restarts the
        # full reset window from the new opening time.
        self._opened_at: float | None = None

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    @property
    def state(self) -> CircuitState:
        """Return the current state, advancing OPEN -> HALF_OPEN if due.

        Reading ``state`` is a side-effecting operation: it is the
        canonical place where the elapsed reset window is checked. Doing
        the check here (rather than in ``record_success`` / ``record_failure``)
        means a long idle period naturally lets the breaker recover.
        """
        with self._lock:
            self._maybe_advance_to_half_open_locked()
            return self._state

    def should_skip_call(self) -> bool:
        """Return ``True`` iff the breaker is OPEN and the call should be skipped.

        HALF_OPEN allows a single probe call (the caller dispatches
        normally and reports the outcome via ``record_success`` /
        ``record_failure``).
        """
        return self.state == CircuitState.OPEN

    def record_success(self) -> None:
        """Reset the failure counter and close the breaker if it was probing."""
        with self._lock:
            previous_state = self._state
            self._consecutive_failures = 0
            self._state = CircuitState.CLOSED
            self._opened_at = None
            if previous_state != CircuitState.CLOSED:
                logger.info(
                    "Circuit breaker %s closed after probe success", self.name
                )

    def record_failure(self) -> None:
        """Increment the failure counter and trip the breaker if at threshold.

        When called from HALF_OPEN, immediately re-opens the breaker for
        another full reset window.
        """
        with self._lock:
            self._consecutive_failures += 1
            now = self._clock()
            if self._state == CircuitState.HALF_OPEN:
                # Probe failed: re-open immediately for another full window.
                self._state = CircuitState.OPEN
                self._opened_at = now
                logger.warning(
                    "Circuit breaker %s re-opened after probe failure (will retry in %.0fs)",
                    self.name,
                    self._reset_timeout,
                )
                return
            if (
                self._state == CircuitState.CLOSED
                and self._consecutive_failures >= self._failure_threshold
            ):
                self._state = CircuitState.OPEN
                self._opened_at = now
                logger.warning(
                    "Circuit breaker %s tripped open after %d consecutive failures (will retry in %.0fs)",
                    self.name,
                    self._consecutive_failures,
                    self._reset_timeout,
                )

    def reset(self) -> None:
        """Force the breaker back to CLOSED. Test hook only."""
        with self._lock:
            self._state = CircuitState.CLOSED
            self._consecutive_failures = 0
            self._opened_at = None

    # ------------------------------------------------------------------
    # Introspection (for logs / future metrics dashboards)
    # ------------------------------------------------------------------

    def snapshot(self) -> dict[str, float | int | str | None]:
        with self._lock:
            return {
                "name": self.name,
                "state": self._state.value,
                "consecutive_failures": self._consecutive_failures,
                "failure_threshold": self._failure_threshold,
                "reset_timeout_seconds": self._reset_timeout,
                "opened_at": self._opened_at,
            }

    # ------------------------------------------------------------------
    # Internal
    # ------------------------------------------------------------------

    def _maybe_advance_to_half_open_locked(self) -> None:
        if self._state != CircuitState.OPEN or self._opened_at is None:
            return
        if self._clock() - self._opened_at < self._reset_timeout:
            return
        self._state = CircuitState.HALF_OPEN
        # Keep ``_opened_at`` so a HALF_OPEN failure can compute a fresh
        # window; we explicitly reset it on success or failure in the
        # respective methods.
        logger.info(
            "Circuit breaker %s probing (HALF_OPEN) after %.0fs reset window",
            self.name,
            self._reset_timeout,
        )


def _read_int_env(name: str, default: int) -> int:
    raw = os.getenv(name)
    if raw is None or not raw.strip():
        return default
    try:
        return int(raw)
    except ValueError:
        return default


def _read_float_env(name: str, default: float) -> float:
    raw = os.getenv(name)
    if raw is None or not raw.strip():
        return default
    try:
        return float(raw)
    except ValueError:
        return default


__all__ = ["CircuitBreaker", "CircuitState"]
