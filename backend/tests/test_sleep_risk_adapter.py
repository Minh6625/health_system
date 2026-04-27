"""Unit tests for ``SleepRiskAdapter`` (Phase 4A-thin).

The critical guarantee here is **score inversion**: a model-api
``predicted_sleep_score = 85`` (good sleep) must land as
``risk_score = 15`` in the ``risk_scores`` table so sleep rows share
the same axis as vitals risk rows. Every test in
``TestScoreInversion`` pins one boundary or edge case of that
transformation.

The other tests pin auxiliary behaviour: risk-level mapping, request_id
propagation, top-features → feature_importance projection, and the
fallback recommendations when the upstream provides none.
"""

from __future__ import annotations

from typing import Any

import pytest

from app.adapters.sleep_risk_adapter import SleepRiskAdapter


def _model_api_response(**overrides: Any) -> dict[str, Any]:
    base: dict[str, Any] = {
        "record_index": 0,
        "predicted_sleep_score": 85.0,
        "predicted_sleep_label": "good",
        "risk_level": "normal",
        "requires_attention": False,
        "high_priority_alert": False,
        "status": "ok",
        "meta": {
            "model_version": "sleep_v0.4.2",
            "request_id": "5lp1-9b3d-2a9c-4d27-9e1a-1234abcd",
        },
        "input_ref": {"index": 0},
        "prediction": {
            "prediction_label": "good",
            "prediction_score": 85.0,
            "prediction_band": "good",
        },
        "top_features": [
            {"feature": "sleep_efficiency_pct", "value": 92.0, "impact": 0.42},
            {"feature": "sleep_stage_deep_pct", "value": 18.0, "impact": 0.31},
        ],
        "shap": None,
        "explanation": {
            "short_text": "Giấc ngủ tốt, hiệu suất 92% và REM ổn định.",
            "clinical_note": "Theo dõi tiếp tục.",
            "recommended_actions": ["Duy trì lịch ngủ"],
        },
    }
    base.update(overrides)
    return base


def _record_stub() -> dict[str, Any]:
    """Minimal SleepRecord-shaped dict for ``from_response`` tests."""
    return {
        "user_id": "42",
        "date_recorded": "2026-04-26",
        "sleep_start_timestamp": "2026-04-26T22:00:00Z",
        "sleep_end_timestamp": "2026-04-27T06:30:00Z",
    }


# ---------------------------------------------------------------------------
# Score inversion — the headline behaviour
# ---------------------------------------------------------------------------


class TestScoreInversion:
    @pytest.mark.parametrize(
        "predicted_sleep_score, expected_risk_score",
        [
            (100.0, 0.0),  # perfect sleep → zero risk
            (85.0, 15.0),  # good sleep → low risk
            (65.0, 35.0),  # ok sleep → medium-low risk
            (50.0, 50.0),  # boundary
            (30.0, 70.0),  # poor sleep → high risk
            (0.0, 100.0),  # no sleep → critical risk
        ],
    )
    def test_inverts_predicted_sleep_score_to_risk_score(
        self,
        predicted_sleep_score: float,
        expected_risk_score: float,
    ) -> None:
        result = SleepRiskAdapter.from_response(
            _model_api_response(predicted_sleep_score=predicted_sleep_score),
            sleep_record=_record_stub(),
        )
        assert result.risk_score == pytest.approx(expected_risk_score)

    def test_clamps_above_100_to_zero(self) -> None:
        # A misconfigured model sending sleep_score=110 must NOT yield
        # risk_score=-10 — the constraint ``score >= 0`` would reject the
        # row otherwise.
        result = SleepRiskAdapter.from_response(
            _model_api_response(predicted_sleep_score=110.0),
            sleep_record=_record_stub(),
        )
        # 110 → clamp to 100 → invert to 0
        assert result.risk_score == 0.0

    def test_negative_score_clamps_to_full_risk(self) -> None:
        # Defensive: a negative sleep_score (model bug) lands as
        # risk_score=100 not 110.
        result = SleepRiskAdapter.from_response(
            _model_api_response(predicted_sleep_score=-5.0),
            sleep_record=_record_stub(),
        )
        # -5 → clamp to 0 → invert to 100
        assert result.risk_score == 100.0

    def test_missing_score_defaults_to_full_risk(self) -> None:
        # If the model returned nothing useful, surface it as critical
        # risk rather than silently treating it as healthy sleep.
        response = _model_api_response()
        del response["predicted_sleep_score"]
        response["prediction"] = {}
        result = SleepRiskAdapter.from_response(
            response, sleep_record=_record_stub()
        )
        assert result.risk_score == 100.0

    def test_falls_back_to_prediction_score_when_top_level_missing(self) -> None:
        response = _model_api_response()
        del response["predicted_sleep_score"]
        # prediction.prediction_score = 85.0 (set in the fixture)
        result = SleepRiskAdapter.from_response(
            response, sleep_record=_record_stub()
        )
        assert result.risk_score == 15.0


# ---------------------------------------------------------------------------
# Risk level mapping
# ---------------------------------------------------------------------------


class TestRiskLevelMapping:
    @pytest.mark.parametrize(
        "raw, expected",
        [
            ("normal", "low"),
            ("warning", "medium"),
            ("high", "medium"),
            ("moderate", "medium"),
            ("medium", "medium"),
            ("critical", "critical"),
            ("low", "low"),
        ],
    )
    def test_maps_known_levels(self, raw: str, expected: str) -> None:
        result = SleepRiskAdapter.from_response(
            _model_api_response(risk_level=raw),
            sleep_record=_record_stub(),
        )
        assert result.risk_level == expected

    @pytest.mark.parametrize("raw", [None, "", "weird-value", "info"])
    def test_unknown_or_empty_defaults_to_medium(self, raw: str | None) -> None:
        response = _model_api_response()
        response["risk_level"] = raw
        # Also clear the prediction.prediction_band so the fallback
        # extraction can't override.
        response["prediction"] = {
            "prediction_label": response["prediction"]["prediction_label"],
            "prediction_score": response["prediction"]["prediction_score"],
            "prediction_band": "definitely-not-a-known-level",
        }
        result = SleepRiskAdapter.from_response(
            response, sleep_record=_record_stub()
        )
        assert result.risk_level == "medium"


# ---------------------------------------------------------------------------
# Backend label + version + traceability
# ---------------------------------------------------------------------------


class TestBackendMetadata:
    def test_backend_label_is_model_api_sleep(self) -> None:
        result = SleepRiskAdapter.from_response(
            _model_api_response(),
            sleep_record=_record_stub(),
        )
        assert result.backend_label == "model_api_sleep"

    def test_model_version_truncated_to_column_width_20(self) -> None:
        long_version = "model_api_sleep_lightgbm_v2_2026_04_27_with_smote"
        result = SleepRiskAdapter.from_response(
            _model_api_response(meta={"model_version": long_version}),
            sleep_record=_record_stub(),
        )
        assert len(result.model_version_label) == 20

    def test_request_id_propagates_to_normalized_explanation(self) -> None:
        result = SleepRiskAdapter.from_response(
            _model_api_response(),
            sleep_record=_record_stub(),
        )
        assert (
            result.model_request_id
            == "5lp1-9b3d-2a9c-4d27-9e1a-1234abcd"
        )

    def test_request_id_truncated_to_36(self) -> None:
        long_id = "x" * 64
        result = SleepRiskAdapter.from_response(
            _model_api_response(meta={"request_id": long_id}),
            sleep_record=_record_stub(),
        )
        assert result.model_request_id is not None
        assert len(result.model_request_id) == 36


# ---------------------------------------------------------------------------
# Top features projection + feature_importance derivation
# ---------------------------------------------------------------------------


class TestFeatureImportanceFromTopFeatures:
    def test_builds_from_upstream_top_features(self) -> None:
        result = SleepRiskAdapter.from_response(
            _model_api_response(),
            sleep_record=_record_stub(),
        )
        assert result.feature_importance == {
            "sleep_efficiency_pct": 0.42,
            "sleep_stage_deep_pct": 0.31,
        }
        assert len(result.top_features) == 2

    def test_skips_invalid_top_feature_entries(self) -> None:
        response = _model_api_response()
        response["top_features"] = [
            None,
            "not-a-dict",
            {"feature": "", "impact": 0.5},  # blank key
            {"impact": 0.4},  # missing feature
            {"feature": "spo2_mean_pct", "impact": "not-a-number"},
            {"feature": "sleep_efficiency_pct", "impact": 0.42},
        ]
        result = SleepRiskAdapter.from_response(
            response, sleep_record=_record_stub()
        )
        assert result.feature_importance == {"sleep_efficiency_pct": 0.42}


# ---------------------------------------------------------------------------
# Recommendations + explanation text fallback
# ---------------------------------------------------------------------------


class TestRecommendationsFallback:
    def test_uses_upstream_recommendations_when_present(self) -> None:
        result = SleepRiskAdapter.from_response(
            _model_api_response(),
            sleep_record=_record_stub(),
        )
        assert result.recommendations == ["Duy trì lịch ngủ"]

    def test_falls_back_to_default_recommendations_when_empty(self) -> None:
        response = _model_api_response()
        response["explanation"] = {
            "short_text": "x",
            "clinical_note": "",
            "recommended_actions": [],
        }
        # Force critical risk so we know which default list to assert.
        response["risk_level"] = "critical"
        response["predicted_sleep_score"] = 20.0
        result = SleepRiskAdapter.from_response(
            response, sleep_record=_record_stub()
        )
        assert len(result.recommendations) == 3
        assert any("chuyên khoa" in rec for rec in result.recommendations)

    def test_synthesises_explanation_text_when_short_text_missing(self) -> None:
        response = _model_api_response()
        response["explanation"] = {
            "short_text": "",
            "clinical_note": "",
            "recommended_actions": [],
        }
        response["predicted_sleep_score"] = 73.0
        result = SleepRiskAdapter.from_response(
            response, sleep_record=_record_stub()
        )
        # Synthetic narrative includes the score and the inferred level.
        assert "73" in result.explanation_text


# ---------------------------------------------------------------------------
# to_record passthrough
# ---------------------------------------------------------------------------


class TestToRecordPassthrough:
    def test_returns_a_copy(self) -> None:
        record = _record_stub()
        out = SleepRiskAdapter.to_record(record)
        assert out == record
        # Confirm it's a copy, not the same dict — mutation must not
        # bleed back into the caller.
        out["user_id"] = "mutated"
        assert record["user_id"] == "42"
