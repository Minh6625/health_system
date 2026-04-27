"""Unit tests for ``RiskPersistenceAdapter``.

The adapter has two responsibilities. ``build_features_json`` is a pure
function and is the safest thing to pin with snapshot-style tests so any
future schema drift in the ``risk_scores.features`` blob fails loudly.
``persist`` is exercised end-to-end by the existing
``test_e2e_risk_response_real_db`` suite (real DB) and indirectly by
``test_monitoring_routes_http``, so we don't duplicate that here.
"""

from __future__ import annotations

from decimal import Decimal

import pytest

from app.adapters.normalized_explanation import NormalizedExplanation
from app.adapters.risk_persistence_adapter import RiskPersistenceAdapter


def _normalized_explanation(**overrides) -> NormalizedExplanation:
    base: dict = {
        "risk_level": "medium",
        "risk_score": 58.0,
        "confidence_value": 0.82,
        "prediction_label": "warning",
        "label_id": None,
        "backend_label": "model_api_health",
        "model_version_label": "model_api_v1",
        "explanation_text": "Nhịp tim cao và SpO2 thấp đang đẩy mức rủi ro lên.",
        "recommendations": ["Đo lại sau 30 phút", "Theo dõi triệu chứng"],
        "feature_importance": {"heart_rate": 0.42, "spo2": 0.31},
        "top_features": [
            {"feature": "heart_rate", "impact": 0.42, "direction": "risk_up"},
        ],
        "ai_explanation_payload": {
            "short_text": "Nhịp tim cao và SpO2 thấp đang đẩy mức rủi ro lên.",
            "clinical_note": "HR 112 bpm > 100; SpO2 94% < 95%.",
            "recommended_actions": ["Đo lại sau 30 phút"],
        },
        "shap_details": None,
        "xai_method": "shap",
        "artifact_path": None,
        "fallback_reason": None,
    }
    base.update(overrides)
    return NormalizedExplanation(**base)


def _vitals_row(**overrides) -> dict:
    base: dict = {
        "heart_rate": 112,
        "spo2": 94,
        "temperature": 36.8,
        "respiratory_rate": 18,
        "blood_pressure_sys": 128,
        "blood_pressure_dia": 82,
        "hrv": 42,
    }
    base.update(overrides)
    return base


_FEATURE_SNAPSHOT = {
    "heart_rate": 112.0,
    "spo2": 94.0,
    "sys_bp": 128.0,
    "dia_bp": 82.0,
    "resp_rate": 18.0,
    "body_temp": 36.8,
    "hrv": 42.0,
}


# Pinned by the mobile DTO contract (see
# ``backend/docs/risk-contract-baseline.md``). Drift here means
# ``MonitoringService._normalize_risk_row`` will fail to project a
# persisted row back into ``NormalizedRiskRow``.
_EXPECTED_FEATURES_KEYS = frozenset(
    {
        "model_features",
        "raw_vitals",
        "defaults_applied",
        "backend",
        "label_id",
        "label",
        "risk_level",
        "risk_score",
        "health_score",
        "health_level",
        "health_summary",
        "confidence",
        "fallback_reason",
        "artifact_path",
    }
)
_EXPECTED_RAW_VITALS_KEYS = frozenset(
    {
        "heart_rate",
        "spo2",
        "temperature",
        "respiratory_rate",
        "blood_pressure_sys",
        "blood_pressure_dia",
        "hrv",
    }
)


class TestBuildFeaturesJsonContractShape:
    def test_top_level_keys_match_pinned_contract(self) -> None:
        blob = RiskPersistenceAdapter.build_features_json(
            inference=_normalized_explanation(),
            vitals_row=_vitals_row(),
            feature_snapshot=_FEATURE_SNAPSHOT,
            defaults_applied=[],
        )
        assert set(blob.keys()) == _EXPECTED_FEATURES_KEYS, (
            "features_json shape drifted; update _EXPECTED_FEATURES_KEYS only "
            "after also updating MonitoringService._normalize_risk_row + the "
            "baseline doc"
        )

    def test_raw_vitals_keys_match_pinned_contract(self) -> None:
        blob = RiskPersistenceAdapter.build_features_json(
            inference=_normalized_explanation(),
            vitals_row=_vitals_row(),
            feature_snapshot=_FEATURE_SNAPSHOT,
            defaults_applied=[],
        )
        assert set(blob["raw_vitals"].keys()) == _EXPECTED_RAW_VITALS_KEYS

    def test_propagates_defaults_applied_list(self) -> None:
        blob = RiskPersistenceAdapter.build_features_json(
            inference=_normalized_explanation(),
            vitals_row=_vitals_row(),
            feature_snapshot=_FEATURE_SNAPSHOT,
            defaults_applied=["hrv", "weight_kg"],
        )
        assert blob["defaults_applied"] == ["hrv", "weight_kg"]


class TestBuildFeaturesJsonValueMirroring:
    def test_canonical_risk_metrics_come_from_inference(self) -> None:
        inference = _normalized_explanation(risk_score=72.5, risk_level="critical")
        blob = RiskPersistenceAdapter.build_features_json(
            inference=inference,
            vitals_row=_vitals_row(),
            feature_snapshot=_FEATURE_SNAPSHOT,
            defaults_applied=[],
        )
        assert blob["risk_score"] == 72.5
        assert blob["risk_level"] == "critical"
        # ``health_score`` is the canonical UI counterpart (high = good)
        # and MUST be derived from ``risk_score`` so it cannot drift.
        assert blob["health_score"] == pytest.approx(100.0 - 72.5, abs=0.01)

    def test_health_summary_derives_from_risk_level(self) -> None:
        # Sanity check that the persisted blob carries the same canonical
        # health_summary that ``MonitoringService._normalize_risk_row``
        # later returns; the exact copy comes from ``risk_inference_service``
        # so we only assert non-empty + string here.
        blob = RiskPersistenceAdapter.build_features_json(
            inference=_normalized_explanation(risk_level="critical"),
            vitals_row=_vitals_row(),
            feature_snapshot=_FEATURE_SNAPSHOT,
            defaults_applied=[],
        )
        assert isinstance(blob["health_summary"], str)
        assert blob["health_summary"]

    def test_artifact_path_and_fallback_reason_passthrough(self) -> None:
        blob = RiskPersistenceAdapter.build_features_json(
            inference=_normalized_explanation(
                artifact_path="/tmp/model_api_v1.tar",
                fallback_reason="model-api timeout",
            ),
            vitals_row=_vitals_row(),
            feature_snapshot=_FEATURE_SNAPSHOT,
            defaults_applied=[],
        )
        assert blob["artifact_path"] == "/tmp/model_api_v1.tar"
        assert blob["fallback_reason"] == "model-api timeout"


class TestBuildFeaturesJsonDecimalEncoding:
    def test_decimal_vitals_are_flattened_to_float(self) -> None:
        # SQLAlchemy NUMERIC columns return ``Decimal``; the adapter must
        # round-trip through json so the saved blob contains plain floats.
        # Otherwise SQLAlchemy's JSONB coerce path raises at write time.
        vitals = _vitals_row(
            heart_rate=Decimal("112.5"),
            spo2=Decimal("94"),
            temperature=Decimal("36.78"),
        )
        blob = RiskPersistenceAdapter.build_features_json(
            inference=_normalized_explanation(),
            vitals_row=vitals,
            feature_snapshot=_FEATURE_SNAPSHOT,
            defaults_applied=[],
        )
        assert blob["raw_vitals"]["heart_rate"] == 112.5
        assert isinstance(blob["raw_vitals"]["heart_rate"], float)
        assert isinstance(blob["raw_vitals"]["spo2"], float)
        assert isinstance(blob["raw_vitals"]["temperature"], float)
