"""Unit tests for :mod:`app.services.model_api_client`.

Mocks ``httpx.Client.post`` so the suite never opens a real socket; verifies
graceful fallback semantics required by the audit (network error / non-200 /
malformed JSON / empty results / status!=ok all return ``None``).
"""

from __future__ import annotations

from unittest.mock import patch

import httpx
import pytest

from app.services.model_api_client import (
    ModelApiClient,
    get_model_api_client,
    set_model_api_client_for_tests,
)


@pytest.fixture(autouse=True)
def _reset_module_singleton():
    set_model_api_client_for_tests(None)
    yield
    set_model_api_client_for_tests(None)


def _ok_health_result() -> dict:
    return {
        "status": "ok",
        "record_index": 0,
        "predicted_health_risk_probability": 0.75,
        "predicted_health_risk_label": "high_risk",
        "risk_level": "critical",
        "requires_attention": True,
        "high_priority_alert": True,
        "prediction": {
            "prediction_label": "high_risk",
            "prediction_score": 0.75,
            "prediction_band": "critical",
            "requires_attention": True,
            "high_priority_alert": True,
            "confidence": 0.75,
        },
        "top_features": [
            {
                "feature": "spo2",
                "feature_value": 92.0,
                "impact": 0.42,
                "direction": "risk_up",
                "reason": "SpO2 thap dang lam tang nguy co",
            }
        ],
        "shap": {
            "available": True,
            "output_space": "raw_margin",
            "base_value": -0.15,
            "prediction_value": 0.75,
            "values": [],
        },
        "explanation": {
            "short_text": "SpO2 thap.",
            "clinical_note": "...",
            "recommended_actions": ["do lai chi so"],
        },
        "meta": {
            "model_family": "healthguard",
            "model_name": "healthguard",
            "model_version": "v_current",
            "artifact_type": "python_bundle",
            "artifact_path": "models/healthguard/healthguard_bundle.joblib",
            "timestamp": "2026-04-25T20:00:00+07:00",
            "request_id": "req_abc",
        },
        "input_ref": {},
    }


def _ok_fall_result() -> dict:
    return {
        "status": "ok",
        "device_id": "watch-1",
        "sample_count": 50,
        "predicted_fall_probability": 0.91,
        "predicted_fall": True,
        "predicted_fall_label": "fall",
        "risk_level": "critical",
        "requires_attention": True,
        "high_priority_alert": True,
        "prediction": {
            "prediction_label": "critical_fall",
            "prediction_score": 0.91,
            "prediction_band": "critical",
            "requires_attention": True,
            "high_priority_alert": True,
            "confidence": 0.91,
        },
        "meta": {"model_family": "fall"},
        "input_ref": {"device_id": "watch-1"},
    }


def _wrap_results(results: list[dict]) -> dict:
    return {"success": True, "total": len(results), "results": results}


class TestModelApiClientHealthPredict:
    def test_disabled_via_env_short_circuits_returning_none(self, monkeypatch) -> None:
        monkeypatch.setenv("HEALTHGUARD_MODEL_API_DISABLED", "1")
        client = ModelApiClient()
        with patch.object(httpx.Client, "post") as post:
            assert client.predict_health_risk({"heart_rate": 80}) is None
            post.assert_not_called()

    def test_successful_response_returns_first_result(self, monkeypatch) -> None:
        monkeypatch.delenv("HEALTHGUARD_MODEL_API_DISABLED", raising=False)
        response = httpx.Response(200, json=_wrap_results([_ok_health_result()]))
        with patch.object(httpx.Client, "post", return_value=response):
            result = ModelApiClient().predict_health_risk({"heart_rate": 80})
        assert result is not None
        assert result["risk_level"] == "critical"
        assert result["top_features"][0]["feature"] == "spo2"
        assert result["shap"]["available"] is True

    def test_non_200_status_returns_none(self, monkeypatch) -> None:
        monkeypatch.delenv("HEALTHGUARD_MODEL_API_DISABLED", raising=False)
        response = httpx.Response(503, json={"detail": "service unavailable"})
        with patch.object(httpx.Client, "post", return_value=response):
            assert ModelApiClient().predict_health_risk({"heart_rate": 80}) is None

    def test_connect_error_returns_none(self, monkeypatch) -> None:
        monkeypatch.delenv("HEALTHGUARD_MODEL_API_DISABLED", raising=False)
        with patch.object(httpx.Client, "post", side_effect=httpx.ConnectError("refused")):
            assert ModelApiClient().predict_health_risk({"heart_rate": 80}) is None

    def test_timeout_returns_none(self, monkeypatch) -> None:
        monkeypatch.delenv("HEALTHGUARD_MODEL_API_DISABLED", raising=False)
        with patch.object(httpx.Client, "post", side_effect=httpx.TimeoutException("slow")):
            assert ModelApiClient().predict_health_risk({"heart_rate": 80}) is None

    def test_malformed_json_returns_none(self, monkeypatch) -> None:
        monkeypatch.delenv("HEALTHGUARD_MODEL_API_DISABLED", raising=False)
        response = httpx.Response(200, text="not-json", headers={"content-type": "text/plain"})
        with patch.object(httpx.Client, "post", return_value=response):
            assert ModelApiClient().predict_health_risk({"heart_rate": 80}) is None

    def test_empty_results_returns_none(self, monkeypatch) -> None:
        monkeypatch.delenv("HEALTHGUARD_MODEL_API_DISABLED", raising=False)
        response = httpx.Response(200, json=_wrap_results([]))
        with patch.object(httpx.Client, "post", return_value=response):
            assert ModelApiClient().predict_health_risk({"heart_rate": 80}) is None

    def test_result_status_not_ok_returns_none(self, monkeypatch) -> None:
        monkeypatch.delenv("HEALTHGUARD_MODEL_API_DISABLED", raising=False)
        bad = {**_ok_health_result(), "status": "error"}
        response = httpx.Response(200, json=_wrap_results([bad]))
        with patch.object(httpx.Client, "post", return_value=response):
            assert ModelApiClient().predict_health_risk({"heart_rate": 80}) is None

    def test_attaches_user_id_and_device_id_to_record(self, monkeypatch) -> None:
        monkeypatch.delenv("HEALTHGUARD_MODEL_API_DISABLED", raising=False)
        captured: dict = {}

        def fake_post(self, url, **kwargs):  # type: ignore[no-untyped-def]
            captured["url"] = url
            captured["json"] = kwargs.get("json")
            return httpx.Response(200, json=_wrap_results([_ok_health_result()]))

        with patch.object(httpx.Client, "post", new=fake_post):
            ModelApiClient().predict_health_risk(
                {"heart_rate": 80},
                user_id=42,
                device_id=7,
            )

        assert captured["url"] == "/api/v1/health/predict"
        record = captured["json"]["records"][0]
        assert record["user_id"] == "42"
        assert record["device_id"] == "7"


class TestModelApiClientFallPredict:
    def test_disabled_via_env_short_circuits_returning_none(self, monkeypatch) -> None:
        monkeypatch.setenv("HEALTHGUARD_MODEL_API_DISABLED", "1")
        client = ModelApiClient()
        with patch.object(httpx.Client, "post") as post:
            assert client.predict_fall({"device_id": "x", "data": []}) is None
            post.assert_not_called()

    def test_successful_returns_first_result(self, monkeypatch) -> None:
        monkeypatch.delenv("HEALTHGUARD_MODEL_API_DISABLED", raising=False)
        response = httpx.Response(200, json=_wrap_results([_ok_fall_result()]))
        with patch.object(httpx.Client, "post", return_value=response):
            result = ModelApiClient().predict_fall({"device_id": "watch-1", "data": []})
        assert result is not None
        assert result["risk_level"] == "critical"
        assert result["predicted_fall_probability"] == pytest.approx(0.91)

    def test_connect_error_returns_none(self, monkeypatch) -> None:
        monkeypatch.delenv("HEALTHGUARD_MODEL_API_DISABLED", raising=False)
        with patch.object(httpx.Client, "post", side_effect=httpx.ConnectError("refused")):
            assert ModelApiClient().predict_fall({"device_id": "x", "data": []}) is None


class TestSingletonAccessor:
    def test_get_returns_same_instance(self) -> None:
        first = get_model_api_client()
        second = get_model_api_client()
        assert first is second

    def test_set_for_tests_replaces_singleton(self) -> None:
        custom = ModelApiClient(base_url="http://test:9999")
        set_model_api_client_for_tests(custom)
        assert get_model_api_client() is custom

    def test_set_none_creates_fresh_instance(self) -> None:
        first = get_model_api_client()
        set_model_api_client_for_tests(None)
        second = get_model_api_client()
        assert second is not first
