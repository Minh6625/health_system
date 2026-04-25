"""Unit tests for the model-api integration helpers in ``risk_alert_service``.

Covers (from the audit P0 #2 / P1 #3 fixes):

- ``_build_model_api_record``: vital payload -> 14-feature ``VitalSignsRecord`` shape,
  including the four derived features (HRV / pulse-pressure / BMI / MAP).
- ``_map_model_api_risk_level``: map model-api ``normal|warning|critical`` to
  backend canonical ``low|medium|critical``.
- ``_normalize_model_api_top_features``: alias model-api feature names
  (``body_temperature`` -> ``body_temp`` etc.) to backend/UI canonical keys.
- ``_normalize_model_api_shap``: alias names inside ``shap.values`` so the UI
  can correlate SHAP entries with vitals.
- ``_feature_importance_from_top_features``: derive the legacy
  ``feature_importance`` dict from SHAP top features.
"""

from __future__ import annotations

import pytest

from app.services.risk_alert_service import (
    _build_model_api_record,
    _feature_importance_from_top_features,
    _map_model_api_risk_level,
    _normalize_model_api_shap,
    _normalize_model_api_top_features,
)


class TestBuildModelApiRecord:
    def test_full_payload_maps_to_fourteen_feature_record(self) -> None:
        payload = {
            "heart_rate": 118.0,
            "resp_rate": 24.0,
            "body_temp": 38.2,
            "spo2": 92.5,
            "sys_bp": 148.0,
            "dia_bp": 96.0,
            "age": 67.0,
            "gender": "male",
            "weight_kg": 73.5,
            "height_cm": 168.0,
            "hrv": 24.0,
        }
        record = _build_model_api_record(payload)

        assert record["heart_rate"] == 118.0
        assert record["respiratory_rate"] == 24.0
        assert record["body_temperature"] == 38.2
        assert record["spo2"] == 92.5
        assert record["systolic_blood_pressure"] == 148.0
        assert record["diastolic_blood_pressure"] == 96.0
        assert record["age"] == 67
        assert record["gender"] == 1
        assert record["weight_kg"] == 73.5
        assert record["height_m"] == pytest.approx(1.68)
        assert record["derived_hrv"] == 24.0
        assert record["derived_pulse_pressure"] == pytest.approx(52.0)
        assert record["derived_bmi"] == pytest.approx(73.5 / (1.68 * 1.68), rel=1e-3)
        assert record["derived_map"] == pytest.approx((148 + 2 * 96) / 3.0, rel=1e-3)

    def test_height_already_in_meters_is_preserved(self) -> None:
        payload = {
            "heart_rate": 80,
            "resp_rate": 16,
            "body_temp": 36.5,
            "spo2": 98,
            "sys_bp": 120,
            "dia_bp": 80,
            "age": 30,
            "gender": "female",
            "weight_kg": 60,
            "height_cm": 1.65,  # already meters
            "hrv": 50,
        }
        record = _build_model_api_record(payload)
        assert record["height_m"] == pytest.approx(1.65)

    def test_missing_optional_fields_use_clinical_defaults(self) -> None:
        record = _build_model_api_record({})
        assert record["heart_rate"] == 75.0
        assert record["respiratory_rate"] == 16.0
        assert record["body_temperature"] == 36.6
        assert record["spo2"] == 98.0
        assert record["systolic_blood_pressure"] == 120.0
        assert record["diastolic_blood_pressure"] == 80.0
        assert record["age"] == 35
        assert record["gender"] == 0
        assert record["weight_kg"] == 65.0
        assert record["height_m"] == pytest.approx(1.65)
        assert record["derived_hrv"] == 50.0

    def test_invalid_height_falls_back_to_one_six_five(self) -> None:
        payload = {"height_cm": -10, "weight_kg": 60}
        record = _build_model_api_record(payload)
        assert record["height_m"] == pytest.approx(1.65)
        assert record["derived_bmi"] > 0

    def test_gender_aliases(self) -> None:
        for label in ("male", "M", "Man", "nam", "1", "true"):
            assert _build_model_api_record({"gender": label})["gender"] == 1
        for label in ("female", "F", "woman", "nu", "0", "", "unknown"):
            assert _build_model_api_record({"gender": label})["gender"] == 0


class TestMapModelApiRiskLevel:
    @pytest.mark.parametrize(
        "raw,expected",
        [
            ("normal", "low"),
            ("low", "low"),
            ("warning", "medium"),
            ("medium", "medium"),
            ("moderate", "medium"),
            ("high", "medium"),
            ("critical", "critical"),
            ("CRITICAL", "critical"),
            ("  Warning  ", "medium"),
        ],
    )
    def test_known_levels_map_to_backend_canonical(self, raw: str, expected: str) -> None:
        assert _map_model_api_risk_level(raw) == expected

    @pytest.mark.parametrize("raw", [None, "", "weird", "info"])
    def test_unknown_or_empty_returns_none(self, raw: str | None) -> None:
        assert _map_model_api_risk_level(raw) is None


class TestNormalizeModelApiTopFeatures:
    def test_aliases_known_feature_names(self) -> None:
        top = [
            {"feature": "body_temperature", "feature_value": 38.2, "impact": 0.31, "direction": "risk_up"},
            {"feature": "respiratory_rate", "feature_value": 24, "impact": 0.18, "direction": "risk_up"},
            {"feature": "systolic_blood_pressure", "feature_value": 148, "impact": 0.12, "direction": "risk_up"},
            {"feature": "diastolic_blood_pressure", "feature_value": 96, "impact": 0.09, "direction": "risk_up"},
            {"feature": "derived_hrv", "feature_value": 24, "impact": 0.06, "direction": "risk_up"},
            {"feature": "derived_pulse_pressure", "feature_value": 52, "impact": 0.05, "direction": "risk_up"},
            {"feature": "derived_bmi", "feature_value": 26.0, "impact": 0.02, "direction": "risk_down"},
            {"feature": "derived_map", "feature_value": 113.3, "impact": 0.01, "direction": "risk_down"},
        ]
        normalized = _normalize_model_api_top_features(top)
        keys = [item["feature"] for item in normalized]
        assert keys == [
            "body_temp",
            "resp_rate",
            "sys_bp",
            "dia_bp",
            "hrv",
            "pulse_pressure",
            "bmi",
            "map_val",
        ]

    def test_passthrough_for_unknown_feature_names(self) -> None:
        top = [{"feature": "spo2", "impact": 0.4, "direction": "risk_up"}]
        normalized = _normalize_model_api_top_features(top)
        assert normalized[0]["feature"] == "spo2"
        assert normalized[0]["impact"] == 0.4

    def test_drops_invalid_entries(self) -> None:
        top = [None, "not-a-dict", {"feature": ""}, {"feature": "spo2", "impact": 0.4}]
        normalized = _normalize_model_api_top_features(top)
        assert len(normalized) == 1
        assert normalized[0]["feature"] == "spo2"

    def test_empty_or_none_returns_empty_list(self) -> None:
        assert _normalize_model_api_top_features(None) == []
        assert _normalize_model_api_top_features([]) == []


class TestNormalizeModelApiShap:
    def test_aliases_inside_values(self) -> None:
        shap_payload = {
            "available": True,
            "output_space": "raw_margin",
            "base_value": -0.15,
            "prediction_value": 0.81,
            "values": [
                {"feature": "body_temperature", "shap_value": 0.31, "impact": 0.31, "direction": "risk_up"},
                {"feature": "spo2", "shap_value": -0.12, "impact": 0.12, "direction": "risk_down"},
            ],
        }
        normalized = _normalize_model_api_shap(shap_payload)
        assert normalized is not None
        assert normalized["available"] is True
        assert normalized["base_value"] == -0.15
        feature_keys = [v["feature"] for v in normalized["values"]]
        assert feature_keys == ["body_temp", "spo2"]

    def test_returns_none_when_not_dict(self) -> None:
        assert _normalize_model_api_shap(None) is None
        assert _normalize_model_api_shap("not-a-dict") is None  # type: ignore[arg-type]

    def test_returns_payload_unchanged_when_values_field_absent(self) -> None:
        payload = {"available": False, "output_space": "raw_margin"}
        assert _normalize_model_api_shap(payload) == payload

    def test_drops_invalid_value_entries(self) -> None:
        payload = {
            "values": [
                None,
                {"feature": ""},
                {"feature": "heart_rate", "impact": 0.5},
            ]
        }
        normalized = _normalize_model_api_shap(payload)
        assert normalized is not None
        assert len(normalized["values"]) == 1
        assert normalized["values"][0]["feature"] == "heart_rate"


class TestFeatureImportanceFromTopFeatures:
    def test_extracts_impact_per_feature(self) -> None:
        top = [
            {"feature": "spo2", "impact": 0.43},
            {"feature": "body_temp", "impact": 0.21},
        ]
        importance = _feature_importance_from_top_features(top)
        assert importance == {"spo2": 0.43, "body_temp": 0.21}

    def test_handles_missing_impact(self) -> None:
        top = [{"feature": "spo2"}, {"feature": "heart_rate", "impact": "0.3"}]
        importance = _feature_importance_from_top_features(top)
        assert importance["spo2"] == 0.0
        assert importance["heart_rate"] == 0.3

    def test_returns_empty_for_none_or_empty(self) -> None:
        assert _feature_importance_from_top_features(None) == {}
        assert _feature_importance_from_top_features([]) == {}

    def test_skips_entries_without_feature_key(self) -> None:
        top = [{"feature": "", "impact": 0.5}, {"impact": 0.4}, {"feature": "spo2", "impact": 0.3}]
        importance = _feature_importance_from_top_features(top)
        assert importance == {"spo2": 0.3}
