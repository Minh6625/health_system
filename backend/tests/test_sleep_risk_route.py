"""HTTP tests for ``POST /api/v1/mobile/telemetry/sleep-risk`` (Phase 4A-thin).

Mirrors the IMU window route tests (Phase 4B-thin) one-for-one:

1. **Happy path** — ``predict_sleep`` returns a structured prediction;
   the route persists a ``risk_scores`` row with ``risk_type='sleep'``
   and the response carries the new ``risk_score_id``, the inverted
   ``risk_score`` (100 - sleep_score), the level, and the upstream
   ``meta.request_id``.
2. **Model unavailable** — ``predict_sleep`` returns ``None``; **no
   row is written**, response carries ``status="model_unavailable"``.
3. **Schema validation** — payloads missing required ``SleepRecord``
   fields are rejected at FastAPI's layer with HTTP 422.

Plus one direct check that the score-inversion contract — sleep_score
85 → risk_score 15 — round-trips cleanly through the route.
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
    app = FastAPI()
    app.include_router(telemetry_router, prefix="/api/v1/mobile")

    captured_persist: dict[str, Any] = {"called": False, "kwargs": {}}

    class _StubRiskScore:
        def __init__(self, **kwargs: Any) -> None:
            self.id = 5555
            self.calculated_at = None
            for key, value in kwargs.items():
                setattr(self, key, value)

    def _fake_persist(db, **kwargs):
        captured_persist["called"] = True
        captured_persist["kwargs"] = kwargs
        return _StubRiskScore()

    monkeypatch.setattr(
        "app.api.routes.telemetry.RiskPersistenceAdapter.persist",
        staticmethod(_fake_persist),
    )

    app.state.captured_persist = captured_persist  # noqa: SLF001 - test seam

    def _override_db():
        yield object()

    app.dependency_overrides[get_db] = _override_db
    return app


def _full_sleep_record() -> dict[str, Any]:
    """Every required SleepRecord field with realistic values.

    Mirrors the canonical model-api schema verbatim; missing any field
    causes a 422 at the FastAPI boundary because ``SleepRecord`` is a
    BaseModel with no defaults on these fields.
    """
    return {
        "user_id": "42",
        "date_recorded": "2026-04-26",
        "sleep_start_timestamp": "2026-04-26T22:00:00Z",
        "sleep_end_timestamp": "2026-04-27T06:30:00Z",
        "duration_minutes": 510.0,
        "sleep_latency_minutes": 12.0,
        "wake_after_sleep_onset_minutes": 8.0,
        "sleep_efficiency_pct": 92.0,
        "sleep_stage_deep_pct": 18.0,
        "sleep_stage_light_pct": 50.0,
        "sleep_stage_rem_pct": 22.0,
        "sleep_stage_awake_pct": 10.0,
        "heart_rate_mean_bpm": 58.0,
        "heart_rate_min_bpm": 48.0,
        "heart_rate_max_bpm": 72.0,
        "hrv_rmssd_ms": 45.0,
        "respiration_rate_bpm": 14.0,
        "spo2_mean_pct": 96.0,
        "spo2_min_pct": 93.0,
        "movement_count": 14.0,
        "snore_events": 2.0,
        "ambient_noise_db": 32.0,
        "room_temperature_c": 22.0,
        "room_humidity_pct": 45.0,
        "step_count_day": 8200.0,
        "caffeine_mg": 80.0,
        "alcohol_units": 0.0,
        "medication_flag": 0.0,
        "jetlag_hours": 0.0,
        "timezone": "Asia/Ho_Chi_Minh",
        "age": 35.0,
        "gender": "female",
        "weight_kg": 60.0,
        "height_cm": 165.0,
        "device_model": "watch_v3",
        "bedtime_consistency_std_min": 18.0,
        "stress_score": 42.0,
        "activity_before_bed_min": 0.0,
        "screen_time_before_bed_min": 25.0,
        "insomnia_flag": 0.0,
        "apnea_risk_score": 0.1,
        "nap_duration_minutes": 0.0,
        "created_at": "2026-04-27T07:00:00Z",
    }


def _ok_prediction(predicted_sleep_score: float = 85.0) -> dict[str, Any]:
    return {
        "record_index": 0,
        "predicted_sleep_score": predicted_sleep_score,
        "predicted_sleep_label": "good" if predicted_sleep_score >= 70 else "poor",
        "risk_level": "normal" if predicted_sleep_score >= 70 else "critical",
        "requires_attention": predicted_sleep_score < 70,
        "high_priority_alert": predicted_sleep_score < 50,
        "status": "ok",
        "meta": {
            "model_version": "sleep_v0.4.2",
            "request_id": "5lp1-9b3d-2a9c-4d27-9e1a-1234abcd",
        },
        "input_ref": {"index": 0},
        "prediction": {
            "prediction_label": "good" if predicted_sleep_score >= 70 else "poor",
            "prediction_score": predicted_sleep_score,
            "prediction_band": "good" if predicted_sleep_score >= 70 else "critical",
        },
        "top_features": [],
        "shap": None,
        "explanation": {"short_text": "ok", "clinical_note": "", "recommended_actions": []},
    }


# ---------------------------------------------------------------------------
# Happy path
# ---------------------------------------------------------------------------


class TestSleepRiskHappyPath:
    def test_persists_row_and_returns_inverted_score(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        app = _build_app(monkeypatch)

        class _StubClient:
            def predict_sleep(self, record: dict[str, Any]):
                return _ok_prediction(predicted_sleep_score=85.0)

        monkeypatch.setattr(
            "app.api.routes.telemetry.get_model_api_client",
            lambda: _StubClient(),
        )

        with TestClient(app) as client:
            response = client.post(
                "/api/v1/mobile/telemetry/sleep-risk",
                json={
                    "db_device_id": 7,
                    "db_user_id": 42,
                    "record": _full_sleep_record(),
                },
                headers=_INTERNAL_HEADERS,
            )

        assert response.status_code == 200, response.text
        body = response.json()
        assert body["status"] == "ok"
        assert body["risk_score_id"] == 5555
        # Headline: predicted_sleep_score=85 → risk_score=15 (inverted).
        assert body["predicted_sleep_score"] == pytest.approx(85.0)
        assert body["risk_score"] == pytest.approx(15.0)
        assert body["risk_level"] == "low"  # normal → low
        assert body["model_request_id"] == "5lp1-9b3d-2a9c-4d27-9e1a-1234abcd"

        # Persistence was called with risk_type='sleep' and inverted score.
        captured = app.state.captured_persist
        assert captured["called"] is True
        kwargs = captured["kwargs"]
        assert kwargs["risk_type"] == "sleep"
        assert kwargs["device_id"] == 7
        assert kwargs["user_id"] == 42
        assert kwargs["inference"].risk_score == pytest.approx(15.0)
        assert kwargs["inference"].backend_label == "model_api_sleep"

    def test_critical_sleep_score_inverts_to_high_risk(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        """Boundary: sleep_score=20 → risk_score=80 → risk_level=critical.

        Confirms the inversion + level-mapping work together for a
        clearly-bad night, which is the most important case to get
        right (false-negative cost = missed sleep apnea or insomnia
        worsening).
        """
        app = _build_app(monkeypatch)

        class _StubClient:
            def predict_sleep(self, record: dict[str, Any]):
                return _ok_prediction(predicted_sleep_score=20.0)

        monkeypatch.setattr(
            "app.api.routes.telemetry.get_model_api_client",
            lambda: _StubClient(),
        )

        with TestClient(app) as client:
            response = client.post(
                "/api/v1/mobile/telemetry/sleep-risk",
                json={
                    "db_device_id": 7,
                    "db_user_id": 42,
                    "record": _full_sleep_record(),
                },
                headers=_INTERNAL_HEADERS,
            )

        body = response.json()
        assert body["risk_score"] == pytest.approx(80.0)
        assert body["risk_level"] == "critical"


# ---------------------------------------------------------------------------
# Model unavailable
# ---------------------------------------------------------------------------


class TestSleepRiskModelUnavailable:
    def test_breaker_open_returns_status_without_persisting(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        app = _build_app(monkeypatch)

        class _UnavailableClient:
            def predict_sleep(self, record: dict[str, Any]):
                return None

        monkeypatch.setattr(
            "app.api.routes.telemetry.get_model_api_client",
            lambda: _UnavailableClient(),
        )

        with TestClient(app) as client:
            response = client.post(
                "/api/v1/mobile/telemetry/sleep-risk",
                json={
                    "db_device_id": 7,
                    "db_user_id": 42,
                    "record": _full_sleep_record(),
                },
                headers=_INTERNAL_HEADERS,
            )

        assert response.status_code == 200
        body = response.json()
        assert body["status"] == "model_unavailable"
        assert body["risk_score_id"] is None
        # No row written — sleep risk is not worth guessing at.
        assert app.state.captured_persist["called"] is False


# ---------------------------------------------------------------------------
# Schema validation
# ---------------------------------------------------------------------------


class TestSleepRiskSchemaValidation:
    def test_missing_required_field_rejected_with_422(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        app = _build_app(monkeypatch)
        # predict_sleep MUST NOT be invoked on validation failure.
        monkeypatch.setattr(
            "app.api.routes.telemetry.get_model_api_client",
            lambda: pytest.fail(
                "predict_sleep must NOT be called on schema validation failure"
            ),
        )

        record = _full_sleep_record()
        del record["sleep_efficiency_pct"]  # drop a required field

        with TestClient(app) as client:
            response = client.post(
                "/api/v1/mobile/telemetry/sleep-risk",
                json={
                    "db_device_id": 7,
                    "db_user_id": 42,
                    "record": record,
                },
                headers=_INTERNAL_HEADERS,
            )

        assert response.status_code == 422
        assert app.state.captured_persist["called"] is False

    def test_missing_db_user_id_rejected_with_422(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        app = _build_app(monkeypatch)

        with TestClient(app) as client:
            response = client.post(
                "/api/v1/mobile/telemetry/sleep-risk",
                json={
                    "db_device_id": 7,
                    # db_user_id intentionally omitted
                    "record": _full_sleep_record(),
                },
                headers=_INTERNAL_HEADERS,
            )

        assert response.status_code == 422
