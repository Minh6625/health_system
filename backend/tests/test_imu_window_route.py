"""HTTP tests for ``POST /api/v1/mobile/telemetry/imu-window`` (Phase 4B-thin).

Three scenarios pin the route's contract:

1. **Happy path** — ``predict_fall`` returns a structured prediction;
   the route persists a ``fall_events`` row and the response carries the
   new ``fall_event_id`` + the upstream ``meta.request_id``.
2. **Model unavailable** — ``predict_fall`` returns ``None`` (breaker
   open / transport fail / 5xx); **no row is written**, the response
   carries ``status="model_unavailable"`` and a NULL ``fall_event_id``.
3. **Schema validation** — payloads with fewer than 20 samples are
   rejected at the FastAPI layer with HTTP 422.
"""

from __future__ import annotations

from typing import Any

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.routes.telemetry import router as telemetry_router
from app.db.database import get_db


# Internal-service header required by ``require_internal_service`` dep
# (ADR-005). Without this the route returns 403 before reaching the
# handler, so every POST in this module must carry it.
_INTERNAL_HEADERS = {"X-Internal-Service": "iot-simulator"}


# ---------------------------------------------------------------------------
# Test client + DB stub
# ---------------------------------------------------------------------------


def _build_app(monkeypatch: pytest.MonkeyPatch) -> FastAPI:
    """Mount the telemetry router with a stub DB so the route is hit
    without a real Postgres connection. Both persistence adapters
    (``FallPersistenceAdapter`` + ``ImuPersistenceAdapter``) are stubbed
    to capture the kwargs that would have been written, so the tests
    can assert the route's side effects without touching Postgres or
    TimescaleDB.
    """
    from datetime import datetime, timezone

    app = FastAPI()
    app.include_router(telemetry_router, prefix="/api/v1/mobile")

    captured_persist: dict[str, Any] = {"called": False, "kwargs": {}}
    captured_imu_persist: dict[str, Any] = {"called": False, "kwargs": {}}

    class _StubFallEvent:
        def __init__(self, **kwargs: Any) -> None:
            self.id = 7777
            self.uuid = "stub-uuid"
            # ADR-022 Phase 7 S8 back-link columns. Initialised to None
            # so the test can detect when the route writes the
            # composite link onto the fall row.
            self.imu_window_id: int | None = None
            self.imu_window_time: datetime | None = None

    class _StubImuWindow:
        def __init__(self) -> None:
            self.id = 5555
            self.time = datetime(2026, 5, 16, 1, 23, 45, tzinfo=timezone.utc)

    def _fake_persist(db, *, db_device_id: int, prediction: dict[str, Any]):
        captured_persist["called"] = True
        captured_persist["kwargs"] = {
            "db_device_id": db_device_id,
            "prediction": prediction,
        }
        fall_event = _StubFallEvent()
        # ADR-022 Phase 7 S8: keep the stub fall event reachable so the
        # back-link assertion can verify ``imu_window_id`` / ``time``
        # were written after :class:`ImuPersistenceAdapter.persist`.
        app.state.fall_event = fall_event
        return fall_event

    def _fake_imu_persist(
        db,
        *,
        db_device_id: int,
        payload: Any,
        fall_event_id: int | None = None,
        model_request_id: str | None = None,
        scenario_context: dict[str, Any] | None = None,
    ):
        captured_imu_persist["called"] = True
        captured_imu_persist["kwargs"] = {
            "db_device_id": db_device_id,
            "fall_event_id": fall_event_id,
            "model_request_id": model_request_id,
            "scenario_context": scenario_context,
            "sample_count": len(payload.data),
        }
        return _StubImuWindow()

    # ADR-022 Phase 7 S8: db.commit / db.refresh are no-ops here so the
    # back-link write does not blow up the stub session. The test
    # observes the field assignment directly on the captured fall row.
    class _StubSession:
        def add(self, _row: Any) -> None:  # pragma: no cover - trivial
            return None

        def commit(self) -> None:  # pragma: no cover - trivial
            return None

        def refresh(self, _row: Any) -> None:  # pragma: no cover - trivial
            return None

        def rollback(self) -> None:  # pragma: no cover - trivial
            return None

    monkeypatch.setattr(
        "app.api.routes.telemetry.FallPersistenceAdapter.persist",
        staticmethod(_fake_persist),
    )
    monkeypatch.setattr(
        "app.api.routes.telemetry.ImuPersistenceAdapter.persist",
        staticmethod(_fake_imu_persist),
    )

    app.state.captured_persist = captured_persist  # noqa: SLF001 - test seam
    app.state.captured_imu_persist = captured_imu_persist  # noqa: SLF001 - test seam

    def _override_db():
        yield _StubSession()

    app.dependency_overrides[get_db] = _override_db
    return app


def _imu_window_payload(*, sample_count: int = 25) -> dict[str, Any]:
    """Build a minimal valid IMU window with ``sample_count`` rows."""
    samples = [
        {
            "timestamp": i * 20,
            "accel": {"x": 0.1, "y": 0.2, "z": 1.0 - i * 0.01},
            "gyro": {"x": 5.0, "y": -2.0, "z": 1.0},
            "orientation": {"pitch": 0.0, "roll": 0.0, "yaw": 0.0},
        }
        for i in range(sample_count)
    ]
    return {
        "db_device_id": 42,
        "sampling_rate": 50,
        "window_size": sample_count,
        "data": samples,
    }


def _ok_prediction() -> dict[str, Any]:
    return {
        "device_id": "42",
        "sample_count": 25,
        "predicted_fall_probability": 0.87,
        "predicted_fall": True,
        "predicted_fall_label": "fall",
        "risk_level": "critical",
        "requires_attention": True,
        "high_priority_alert": True,
        "predicted_activity": "fall_forward",
        "activity_probability": 0.93,
        "status": "ok",
        "meta": {
            "model_version": "fall_v0.3.1",
            "request_id": "fa11-9b3d-2a9c-4d27-9e1a-1234abcd",
        },
        "input_ref": {"index": 0},
        "prediction": {
            "prediction_label": "fall",
            "prediction_score": 0.87,
            "prediction_band": "critical_fall",
        },
        "top_features": [],
    }


# ---------------------------------------------------------------------------
# Happy path
# ---------------------------------------------------------------------------


class TestImuWindowHappyPath:
    def test_persists_row_and_returns_prediction(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        app = _build_app(monkeypatch)

        class _StubClient:
            def predict_fall(self, payload: dict[str, Any]):
                return _ok_prediction()

        monkeypatch.setattr(
            "app.api.routes.telemetry.get_model_api_client",
            lambda: _StubClient(),
        )

        with TestClient(app) as client:
            response = client.post(
                "/api/v1/mobile/telemetry/imu-window",
                json=_imu_window_payload(),
                headers=_INTERNAL_HEADERS,
            )

        assert response.status_code == 200, response.text
        body = response.json()
        assert body["status"] == "ok"
        assert body["fall_event_id"] == 7777
        assert body["fall_probability"] == pytest.approx(0.87)
        assert body["prediction_band"] == "critical_fall"
        assert body["predicted_fall"] is True
        assert body["requires_attention"] is True
        assert body["model_request_id"] == "fa11-9b3d-2a9c-4d27-9e1a-1234abcd"

        # Confirm the persistence adapter was actually called with the
        # right db_device_id and full prediction body.
        captured = app.state.captured_persist
        assert captured["called"] is True
        assert captured["kwargs"]["db_device_id"] == 42
        assert captured["kwargs"]["prediction"]["predicted_fall"] is True

    def test_persists_imu_window_after_fall_event(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        """ADR-022 Phase 7 S8: the raw window is written to ``imu_windows``
        after the fall row is created, with ``fall_event_id`` populated
        from the freshly-persisted fall id.
        """
        app = _build_app(monkeypatch)

        class _StubClient:
            def predict_fall(self, payload: dict[str, Any]):
                return _ok_prediction()

        monkeypatch.setattr(
            "app.api.routes.telemetry.get_model_api_client",
            lambda: _StubClient(),
        )

        with TestClient(app) as client:
            response = client.post(
                "/api/v1/mobile/telemetry/imu-window",
                json=_imu_window_payload(sample_count=30),
                headers=_INTERNAL_HEADERS,
            )

        assert response.status_code == 200, response.text

        imu_capture = app.state.captured_imu_persist
        assert imu_capture["called"] is True
        # Same device id passes through.
        assert imu_capture["kwargs"]["db_device_id"] == 42
        # ``fall_event_id`` comes from the freshly-persisted fall row.
        assert imu_capture["kwargs"]["fall_event_id"] == 7777
        # ``model_request_id`` propagated from the model-api meta block
        # so admin replay can correlate prediction <-> raw window.
        assert (
            imu_capture["kwargs"]["model_request_id"]
            == "fa11-9b3d-2a9c-4d27-9e1a-1234abcd"
        )
        # All 30 samples handed to the adapter — no slicing.
        assert imu_capture["kwargs"]["sample_count"] == 30

    def test_back_links_fall_event_to_imu_window(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        """ADR-022 Phase 7 S8: after the IMU window is persisted, the
        composite link ``(imu_window_id, imu_window_time)`` is written
        onto the fall row so the FK ``fk_fall_events_imu_window`` (set
        up by the migration) is satisfied.
        """
        app = _build_app(monkeypatch)

        class _StubClient:
            def predict_fall(self, payload: dict[str, Any]):
                return _ok_prediction()

        monkeypatch.setattr(
            "app.api.routes.telemetry.get_model_api_client",
            lambda: _StubClient(),
        )

        with TestClient(app) as client:
            response = client.post(
                "/api/v1/mobile/telemetry/imu-window",
                json=_imu_window_payload(),
                headers=_INTERNAL_HEADERS,
            )

        assert response.status_code == 200, response.text

        fall_event = app.state.fall_event
        assert fall_event.imu_window_id == 5555
        assert fall_event.imu_window_time is not None
        assert fall_event.imu_window_time.year == 2026

    def test_forwards_data_to_model_api_in_native_shape(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        """Backend must NOT translate field names — the model-api
        SensorSample contract IS the wire shape we accept on this
        route, so the inner ``data`` array passes through unchanged.
        """
        app = _build_app(monkeypatch)
        captured_payload: dict[str, Any] = {}

        class _CapturingClient:
            def predict_fall(self, payload: dict[str, Any]):
                captured_payload.update(payload)
                return _ok_prediction()

        monkeypatch.setattr(
            "app.api.routes.telemetry.get_model_api_client",
            lambda: _CapturingClient(),
        )

        with TestClient(app) as client:
            response = client.post(
                "/api/v1/mobile/telemetry/imu-window",
                json=_imu_window_payload(sample_count=30),
                headers=_INTERNAL_HEADERS,
            )

        assert response.status_code == 200
        # Backend stripped ``db_device_id`` (internal) and added the
        # string device_id the model-api expects; everything else
        # passed through.
        assert captured_payload["device_id"] == "42"
        assert captured_payload["sampling_rate"] == 50
        assert captured_payload["window_size"] == 30
        assert len(captured_payload["data"]) == 30
        first = captured_payload["data"][0]
        assert set(first.keys()) >= {"timestamp", "accel", "gyro", "orientation", "environment"}


# ---------------------------------------------------------------------------
# Model unavailable
# ---------------------------------------------------------------------------


class TestImuWindowModelUnavailable:
    def test_breaker_open_returns_status_without_persisting(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        app = _build_app(monkeypatch)

        class _UnavailableClient:
            def predict_fall(self, payload: dict[str, Any]):
                # ``ModelApiClient.predict_fall`` returns None on
                # breaker-open / transport / 5xx / malformed body.
                return None

        monkeypatch.setattr(
            "app.api.routes.telemetry.get_model_api_client",
            lambda: _UnavailableClient(),
        )

        with TestClient(app) as client:
            response = client.post(
                "/api/v1/mobile/telemetry/imu-window",
                json=_imu_window_payload(),
                headers=_INTERNAL_HEADERS,
            )

        assert response.status_code == 200
        body = response.json()
        assert body["status"] == "model_unavailable"
        assert body["fall_event_id"] is None
        assert body["fall_probability"] == 0.0
        assert body["predicted_fall"] is False
        assert body["requires_attention"] is False

        # Critical: no fall_events row was written. False-negative on
        # a real fall is dangerous — the route must surface uncertainty,
        # not silently report "no fall".
        assert app.state.captured_persist["called"] is False


# ---------------------------------------------------------------------------
# Schema validation
# ---------------------------------------------------------------------------


class TestImuWindowSchemaValidation:
    def test_short_window_rejected_with_422(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        app = _build_app(monkeypatch)

        # No need to stub the client — request is rejected before that.
        monkeypatch.setattr(
            "app.api.routes.telemetry.get_model_api_client",
            lambda: pytest.fail("predict_fall must NOT be called on validation failure"),
        )

        with TestClient(app) as client:
            response = client.post(
                "/api/v1/mobile/telemetry/imu-window",
                json=_imu_window_payload(sample_count=5),
                headers=_INTERNAL_HEADERS,
            )

        assert response.status_code == 422
        assert app.state.captured_persist["called"] is False

    def test_missing_db_device_id_rejected_with_422(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        app = _build_app(monkeypatch)
        payload = _imu_window_payload()
        del payload["db_device_id"]

        with TestClient(app) as client:
            response = client.post(
                "/api/v1/mobile/telemetry/imu-window",
                json=payload,
                headers=_INTERNAL_HEADERS,
            )

        assert response.status_code == 422
