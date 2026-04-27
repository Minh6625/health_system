"""HTTP client for the external healthguard-model-api inference service.

Provides graceful fallback when the model-api is unreachable or returns an
error: methods return ``None`` and the caller falls back to the local
rule-based path in ``risk_inference_service``.

Environment:
- ``HEALTHGUARD_MODEL_API_URL`` (default ``http://localhost:8001``)
- ``HEALTHGUARD_MODEL_API_DISABLED=1`` to short-circuit (unit tests / Heroku)
- ``HEALTHGUARD_MODEL_API_TIMEOUT_SECONDS`` (default ``5.0``)
"""

from __future__ import annotations

import logging
import os
from typing import Any

import httpx

from app.observability.timing import StageTimer
from app.services.circuit_breaker import CircuitBreaker

logger = logging.getLogger(__name__)


_DEFAULT_BASE_URL = "http://localhost:8001"
_DEFAULT_TIMEOUT_SECONDS = 5.0


class ModelApiClient:
    """Thin httpx wrapper around healthguard-model-api endpoints.

    All calls are best-effort: any failure (network, 4xx/5xx, malformed JSON,
    missing ``results``) returns ``None`` so the caller can fall back to the
    local rule-based path. Status is logged at WARNING level for observability.

    Phase 7 wraps every outbound call in a per-endpoint
    :class:`CircuitBreaker` so a sustained model-api outage does not pay
    the full per-request timeout cost on every incoming risk
    calculation. Each call site is also instrumented with
    :class:`~app.observability.timing.StageTimer` so the
    ``risk.timing`` log channel emits one record per request, ready for
    a downstream histogram dashboard.
    """

    def __init__(
        self,
        *,
        base_url: str | None = None,
        timeout_seconds: float | None = None,
        health_breaker: CircuitBreaker | None = None,
        fall_breaker: CircuitBreaker | None = None,
    ) -> None:
        self._base_url = (base_url or os.getenv("HEALTHGUARD_MODEL_API_URL", _DEFAULT_BASE_URL)).rstrip("/")
        timeout_value = timeout_seconds
        if timeout_value is None:
            try:
                timeout_value = float(os.getenv("HEALTHGUARD_MODEL_API_TIMEOUT_SECONDS", _DEFAULT_TIMEOUT_SECONDS))
            except (TypeError, ValueError):
                timeout_value = _DEFAULT_TIMEOUT_SECONDS
        self._timeout = httpx.Timeout(timeout_value)
        self._client: httpx.Client | None = None
        # Two breakers because a healthy fall endpoint should keep
        # accepting traffic even when health predictions are degraded
        # (and vice versa).
        self._health_breaker = health_breaker or CircuitBreaker("model_api_health")
        self._fall_breaker = fall_breaker or CircuitBreaker("model_api_fall")

    @property
    def health_breaker(self) -> CircuitBreaker:
        return self._health_breaker

    @property
    def fall_breaker(self) -> CircuitBreaker:
        return self._fall_breaker

    @property
    def base_url(self) -> str:
        return self._base_url

    @staticmethod
    def is_disabled() -> bool:
        return os.getenv("HEALTHGUARD_MODEL_API_DISABLED", "").strip() == "1"

    def _ensure_client(self) -> httpx.Client:
        if self._client is None:
            self._client = httpx.Client(
                base_url=self._base_url,
                timeout=self._timeout,
                headers={"X-Internal-Service": "health-system-backend"},
            )
        return self._client

    def close(self) -> None:
        if self._client is not None:
            try:
                self._client.close()
            finally:
                self._client = None

    # ------------------------------------------------------------------
    # Health risk
    # ------------------------------------------------------------------

    def predict_health_risk(
        self,
        record: dict[str, Any],
        *,
        user_id: str | int | None = None,
        device_id: str | int | None = None,
    ) -> dict[str, Any] | None:
        """POST a single ``VitalSignsRecord`` and return the first result.

        Returns ``None`` on any failure path (disabled, breaker open,
        network error, non-200, malformed body, empty results). Network /
        timeout errors trip the per-endpoint circuit breaker; malformed
        responses do not (the upstream is reachable, just speaking the
        wrong dialect, and skipping won't help).
        """
        if self.is_disabled():
            logger.debug("Model-api health predict skipped: HEALTHGUARD_MODEL_API_DISABLED=1")
            return None
        if self._health_breaker.should_skip_call():
            logger.warning(
                "Model-api health predict short-circuited: breaker %s open",
                self._health_breaker.name,
            )
            return None

        payload = {"records": [self._with_input_ref(record, user_id=user_id, device_id=device_id)]}
        with StageTimer("model_api_call", endpoint="health_predict"):
            try:
                response = self._ensure_client().post("/api/v1/health/predict", json=payload)
            except (httpx.ConnectError, httpx.ConnectTimeout) as exc:
                self._health_breaker.record_failure()
                logger.warning("Model-api health predict connection failed: %s", exc)
                return None
            except httpx.TimeoutException as exc:
                self._health_breaker.record_failure()
                logger.warning("Model-api health predict timeout: %s", exc)
                return None
            except httpx.HTTPError as exc:
                self._health_breaker.record_failure()
                logger.warning("Model-api health predict transport error: %s", exc)
                return None

        if response.status_code != 200:
            # Server is reachable but unhappy — count toward the breaker
            # too, otherwise a 5xx loop drains the request thread pool.
            self._health_breaker.record_failure()
            logger.warning(
                "Model-api health predict non-200: status=%s body=%s",
                response.status_code,
                response.text[:200] if response.text else "",
            )
            return None

        try:
            body = response.json()
        except ValueError as exc:
            # Reachable but garbled — do NOT trip the breaker, this is a
            # contract bug not an outage.
            logger.warning("Model-api health predict malformed JSON: %s", exc)
            return None

        if not isinstance(body, dict):
            return None
        results = body.get("results") or []
        if not results or not isinstance(results, list):
            return None
        first = results[0]
        if not isinstance(first, dict) or first.get("status") != "ok":
            return None
        # The call cleared the success path: any prior failures are stale.
        self._health_breaker.record_success()
        return first

    # ------------------------------------------------------------------
    # Fall risk
    # ------------------------------------------------------------------

    def predict_fall(
        self,
        request_payload: dict[str, Any],
    ) -> dict[str, Any] | None:
        """POST a single ``FallPredictionRequest`` window and return the first result.

        ``request_payload`` must already follow the model-api shape:
        ``{"device_id", "sampling_rate", "window_size", "data": [SensorSample, ...]}``.

        Same breaker / timing semantics as :meth:`predict_health_risk`,
        but on its own ``model_api_fall`` breaker so health and fall
        outages do not mask one another.
        """
        if self.is_disabled():
            logger.debug("Model-api fall predict skipped: HEALTHGUARD_MODEL_API_DISABLED=1")
            return None
        if self._fall_breaker.should_skip_call():
            logger.warning(
                "Model-api fall predict short-circuited: breaker %s open",
                self._fall_breaker.name,
            )
            return None

        with StageTimer("model_api_call", endpoint="fall_predict"):
            try:
                response = self._ensure_client().post("/api/v1/fall/predict", json=request_payload)
            except (httpx.ConnectError, httpx.ConnectTimeout) as exc:
                self._fall_breaker.record_failure()
                logger.warning("Model-api fall predict connection failed: %s", exc)
                return None
            except httpx.TimeoutException as exc:
                self._fall_breaker.record_failure()
                logger.warning("Model-api fall predict timeout: %s", exc)
                return None
            except httpx.HTTPError as exc:
                self._fall_breaker.record_failure()
                logger.warning("Model-api fall predict transport error: %s", exc)
                return None

        if response.status_code != 200:
            self._fall_breaker.record_failure()
            logger.warning(
                "Model-api fall predict non-200: status=%s body=%s",
                response.status_code,
                response.text[:200] if response.text else "",
            )
            return None

        try:
            body = response.json()
        except ValueError as exc:
            logger.warning("Model-api fall predict malformed JSON: %s", exc)
            return None

        if not isinstance(body, dict):
            return None
        results = body.get("results") or []
        if not results or not isinstance(results, list):
            return None
        first = results[0]
        if not isinstance(first, dict) or first.get("status") != "ok":
            return None
        self._fall_breaker.record_success()
        return first

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _with_input_ref(
        record: dict[str, Any],
        *,
        user_id: str | int | None,
        device_id: str | int | None,
    ) -> dict[str, Any]:
        """Attach optional input_ref hints — extra keys are ignored by VitalSignsRecord."""
        enriched = dict(record)
        if user_id is not None:
            enriched.setdefault("user_id", str(user_id))
        if device_id is not None:
            enriched.setdefault("device_id", str(device_id))
        return enriched


# ---------------------------------------------------------------------------
# Module-level singleton (so risk_alert_service can import a ready client)
# ---------------------------------------------------------------------------

_model_api_client: ModelApiClient | None = None


def get_model_api_client() -> ModelApiClient:
    """Return the process-wide :class:`ModelApiClient` singleton (lazy)."""
    global _model_api_client
    if _model_api_client is None:
        _model_api_client = ModelApiClient()
    return _model_api_client


def set_model_api_client_for_tests(client: ModelApiClient | None) -> None:
    """Test hook: replace the singleton (or reset to ``None``)."""
    global _model_api_client
    _model_api_client = client


__all__ = [
    "ModelApiClient",
    "get_model_api_client",
    "set_model_api_client_for_tests",
]
