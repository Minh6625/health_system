"""Tests for SHAP + AI explanation pipeline (Phase A–C).

Covers:
- MonitoringService._top_factors with SHAP top_features vs legacy fallback
- MonitoringService._build_breakdown with SHAP enrichment
- MonitoringService._build_ai_explanation with structured payload and fallbacks
- MonitoringService._index_top_features helper
- MonitoringService._format_metric_value helper
- risk_alert_service._default_recommendations per risk level
- risk_alert_service._build_ai_explanation_payload structure
- get_risk_report_detail wiring with SHAP columns present
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any
from unittest.mock import MagicMock

import pytest

from app.schemas.monitoring import (
    AiExplanationResponse,
    FactorBreakdownResponse,
    TopFactorResponse,
)
from app.services.monitoring_service import MonitoringService
from app.adapters.model_api_health_adapter import ModelApiHealthAdapter

# Phase 3b: these helpers moved from ``risk_alert_service`` to
# ``ModelApiHealthAdapter``. Module-level aliases preserve the existing
# call sites so the SHAP/AI explanation contract tests don't have to be
# rewritten.
_default_recommendations = ModelApiHealthAdapter._default_recommendations
_build_ai_explanation_payload = ModelApiHealthAdapter._build_ai_explanation_payload


# ---------------------------------------------------------------------------
# Fixtures — reusable SHAP payloads
# ---------------------------------------------------------------------------

SHAP_TOP_FEATURES: list[dict[str, Any]] = [
    {
        "feature": "heart_rate",
        "feature_value": 112,
        "impact": 0.38,
        "direction": "risk_up",
        "reason": "Nhịp tim cao hơn bình thường",
    },
    {
        "feature": "spo2",
        "feature_value": 94,
        "impact": 0.25,
        "direction": "risk_up",
        "reason": "SpO2 thấp hơn ngưỡng an toàn",
    },
    {
        "feature": "body_temp",
        "feature_value": 36.8,
        "impact": 0.02,
        "direction": "risk_down",
        "reason": "Thân nhiệt bình thường",
    },
]

AI_EXPLANATION_PAYLOAD: dict[str, Any] = {
    "short_text": "Nhịp tim và SpO2 cần theo dõi sát.",
    "clinical_note": "HR 112 bpm vượt ngưỡng 100; SpO2 94% dưới 95%.",
    "recommended_actions": [
        "Đo lại chỉ số sau 15 phút",
        "Nghỉ ngơi tại chỗ",
        "Liên hệ bác sĩ nếu triệu chứng tiếp diễn",
    ],
}

LEGACY_FEATURE_IMPORTANCE: dict[str, float] = {
    "heart_rate": 0.62,
    "spo2": 0.41,
    "body_temp": 0.05,
}


# ---------------------------------------------------------------------------
# _top_factors
# ---------------------------------------------------------------------------

class TestTopFactors:
    def test_prefers_shap_top_features_over_legacy(self) -> None:
        result = MonitoringService._top_factors(
            LEGACY_FEATURE_IMPORTANCE,
            limit=2,
            top_features=SHAP_TOP_FEATURES,
        )
        assert len(result) == 2
        assert result[0].key == "heart_rate"
        assert result[0].impact == 0.38
        assert result[0].direction == "risk_up"
        assert result[0].reason == "Nhịp tim cao hơn bình thường"
        assert result[1].key == "spo2"

    def test_falls_back_to_legacy_when_no_shap(self) -> None:
        result = MonitoringService._top_factors(
            LEGACY_FEATURE_IMPORTANCE,
            limit=2,
            top_features=None,
        )
        assert len(result) == 2
        assert result[0].key == "heart_rate"
        assert result[0].impact == 0.0  # legacy has no impact
        assert result[0].direction == ""

    def test_falls_back_to_legacy_when_shap_list_empty(self) -> None:
        result = MonitoringService._top_factors(
            LEGACY_FEATURE_IMPORTANCE,
            limit=2,
            top_features=[],
        )
        assert len(result) == 2
        assert result[0].direction == ""

    def test_skips_invalid_entries_in_shap(self) -> None:
        # Valid entry first, invalids after — limit=3 slices top_features[:3]
        bad_features = [SHAP_TOP_FEATURES[0], None, "not_a_dict", {"feature": ""}]
        result = MonitoringService._top_factors(
            {"heart_rate": 0.5},
            limit=3,
            top_features=bad_features,
        )
        assert len(result) == 1
        assert result[0].key == "heart_rate"
        assert result[0].impact == 0.38  # from SHAP, not legacy

    def test_label_fallback_for_unknown_feature_key(self) -> None:
        custom = [{"feature": "custom_metric", "impact": 0.1, "direction": "risk_down"}]
        result = MonitoringService._top_factors({}, limit=1, top_features=custom)
        assert result[0].label == "Custom Metric"


# ---------------------------------------------------------------------------
# _build_breakdown
# ---------------------------------------------------------------------------

class TestBuildBreakdown:
    def test_breakdown_includes_shap_direction_and_reason(self) -> None:
        result = MonitoringService._build_breakdown(
            feature_importance=LEGACY_FEATURE_IMPORTANCE,
            feature_snapshot={"heart_rate": 112, "spo2": 94},
            raw_vitals={},
            top_features=SHAP_TOP_FEATURES,
        )
        hr_item = next(item for item in result if item.key == "heart_rate")
        assert hr_item.direction == "risk_up"
        assert hr_item.reason == "Nhịp tim cao hơn bình thường"
        assert hr_item.contribution_score == 0.38  # SHAP impact overrides legacy

    def test_breakdown_uses_shap_feature_value_as_fallback(self) -> None:
        result = MonitoringService._build_breakdown(
            feature_importance={},
            feature_snapshot={},
            raw_vitals={},
            top_features=SHAP_TOP_FEATURES,
        )
        hr_item = next(item for item in result if item.key == "heart_rate")
        assert hr_item.value == "112"

    def test_breakdown_legacy_has_empty_direction_reason(self) -> None:
        result = MonitoringService._build_breakdown(
            feature_importance=LEGACY_FEATURE_IMPORTANCE,
            feature_snapshot={"heart_rate": 108},
            raw_vitals={},
            top_features=None,
        )
        hr_item = next(item for item in result if item.key == "heart_rate")
        assert hr_item.direction == ""
        assert hr_item.reason == ""

    def test_impact_level_thresholds(self) -> None:
        result = MonitoringService._build_breakdown(
            feature_importance={"a": 0.6, "b": 0.3, "c": 0.1},
            feature_snapshot={},
            raw_vitals={},
        )
        levels = {item.key: item.impact_level for item in result}
        assert levels["a"] == "high"
        assert levels["b"] == "medium"
        assert levels["c"] == "low"


# ---------------------------------------------------------------------------
# _build_ai_explanation
# ---------------------------------------------------------------------------

class TestBuildAiExplanation:
    def test_builds_full_explanation_from_payload(self) -> None:
        result = MonitoringService._build_ai_explanation(AI_EXPLANATION_PAYLOAD)
        assert result is not None
        assert result.short_text == "Nhịp tim và SpO2 cần theo dõi sát."
        assert "HR 112" in result.clinical_note
        assert len(result.recommended_actions) == 3

    def test_returns_none_for_empty_dict(self) -> None:
        assert MonitoringService._build_ai_explanation({}) is None

    def test_returns_none_for_all_empty_fields(self) -> None:
        assert MonitoringService._build_ai_explanation(
            {"short_text": "", "clinical_note": "", "recommended_actions": []}
        ) is None

    def test_fallback_recommendations_when_actions_empty(self) -> None:
        payload = {"short_text": "Some text", "recommended_actions": []}
        result = MonitoringService._build_ai_explanation(
            payload,
            fallback_recommendations=["Fallback action 1"],
        )
        assert result is not None
        assert result.recommended_actions == ["Fallback action 1"]

    def test_ignores_non_list_recommended_actions(self) -> None:
        payload = {"short_text": "Ok", "recommended_actions": "not_a_list"}
        result = MonitoringService._build_ai_explanation(payload)
        assert result is not None
        assert result.recommended_actions == []


# ---------------------------------------------------------------------------
# _index_top_features
# ---------------------------------------------------------------------------

class TestIndexTopFeatures:
    def test_indexes_by_feature_key(self) -> None:
        indexed = MonitoringService._index_top_features(SHAP_TOP_FEATURES)
        assert "heart_rate" in indexed
        assert indexed["heart_rate"]["impact"] == 0.38
        assert "spo2" in indexed

    def test_returns_empty_for_none(self) -> None:
        assert MonitoringService._index_top_features(None) == {}

    def test_skips_invalid_entries(self) -> None:
        result = MonitoringService._index_top_features([None, "bad", {"feature": "ok", "impact": 0.1}])
        assert len(result) == 1
        assert "ok" in result


# ---------------------------------------------------------------------------
# _format_metric_value
# ---------------------------------------------------------------------------

class TestFormatMetricValue:
    def test_integer_value(self) -> None:
        assert MonitoringService._format_metric_value(98) == "98"

    def test_float_near_integer(self) -> None:
        assert MonitoringService._format_metric_value(98.003) == "98"

    def test_float_with_decimal(self) -> None:
        assert MonitoringService._format_metric_value(36.8) == "36.8"

    def test_none_returns_dash(self) -> None:
        assert MonitoringService._format_metric_value(None) == "--"

    def test_string_passthrough(self) -> None:
        assert MonitoringService._format_metric_value("N/A") == "N/A"


# ---------------------------------------------------------------------------
# risk_alert_service helpers
# ---------------------------------------------------------------------------

class TestDefaultRecommendations:
    def test_critical_level(self) -> None:
        recs = _default_recommendations("critical")
        assert len(recs) == 3
        assert any("xác nhận" in r for r in recs)

    def test_medium_level(self) -> None:
        recs = _default_recommendations("medium")
        assert len(recs) == 2

    def test_high_level_maps_to_medium_bucket(self) -> None:
        recs = _default_recommendations("high")
        assert len(recs) == 2

    def test_low_level(self) -> None:
        recs = _default_recommendations("low")
        assert len(recs) == 2
        assert any("định kỳ" in r for r in recs)

    def test_empty_string_defaults_to_low(self) -> None:
        recs = _default_recommendations("")
        assert len(recs) == 2


class TestBuildAiExplanationPayload:
    def test_payload_structure(self) -> None:
        result = _build_ai_explanation_payload(
            explanation_text="Test explanation",
            risk_level="critical",
            recommendations=["Action 1", "Action 2"],
        )
        assert result["short_text"] == "Test explanation"
        assert result["clinical_note"] == ""
        assert result["recommended_actions"] == ["Action 1", "Action 2"]

    def test_empty_recommendations(self) -> None:
        result = _build_ai_explanation_payload(
            explanation_text="Ok",
            risk_level="low",
            recommendations=[],
        )
        assert result["recommended_actions"] == []


# ---------------------------------------------------------------------------
# get_risk_report_detail — full integration with SHAP columns
# ---------------------------------------------------------------------------

class _FakeQueryResult:
    def __init__(self, *, first=None, all_rows=None, scalar=None):
        self._first = first
        self._all_rows = all_rows or []
        self._scalar = scalar

    def mappings(self):
        return self

    def first(self):
        return self._first

    def all(self):
        return self._all_rows

    def scalar(self):
        return self._scalar


class TestReportDetailWithShap:
    def test_detail_returns_shap_enriched_top_factors_and_ai_explanation(self) -> None:
        now = datetime.now(UTC)
        db = MagicMock()
        db.execute.side_effect = [
            _FakeQueryResult(
                first={
                    "id": 55,
                    "user_id": 7,
                    "risk_type": "general",
                    "score": 79.0,
                    "risk_level": "critical",
                    "calculated_at": now,
                    "features": {
                        "confidence": 0.85,
                        "backend": "onnx",
                        "model_features": {"heart_rate": 112, "spo2": 94},
                        "raw_vitals": {
                            "heart_rate": 112,
                            "spo2": 94,
                            "blood_pressure_sys": 135,
                            "blood_pressure_dia": 88,
                            "temperature": 36.8,
                            "hrv": 30,
                        },
                    },
                    "model_version": "onnx-v1.0",
                    "algorithm": "onnx",
                    "explanation_text": "Nhịp tim và SpO2 cần theo dõi.",
                    "feature_importance": {"heart_rate": 0.62, "spo2": 0.41},
                    "recommendations": ["Nghỉ ngơi.", "Đo lại."],
                    "top_features_json": SHAP_TOP_FEATURES,
                    "ai_explanation_json": AI_EXPLANATION_PAYLOAD,
                }
            ),
            # _previous_risk_score
            _FakeQueryResult(first=None),
            # _compute_trend_7d
            _FakeQueryResult(all_rows=[]),
        ]

        detail = MonitoringService.get_risk_report_detail(patient_id=7, report_id=55, db=db)

        assert detail is not None

        # Top factors should use SHAP data
        assert len(detail.top_factors) == 2
        assert detail.top_factors[0].key == "heart_rate"
        assert detail.top_factors[0].impact == 0.38
        assert detail.top_factors[0].direction == "risk_up"
        assert detail.top_factors[0].reason != ""

        # Breakdown should have SHAP direction
        hr_breakdown = next((b for b in detail.breakdown if b.key == "heart_rate"), None)
        assert hr_breakdown is not None
        assert hr_breakdown.direction == "risk_up"

        # AI explanation should be present
        assert detail.ai_explanation is not None
        assert detail.ai_explanation.short_text == "Nhịp tim và SpO2 cần theo dõi sát."
        assert len(detail.ai_explanation.recommended_actions) == 3

    def test_detail_works_without_shap_columns(self) -> None:
        """Backward compat: SHAP columns NULL → legacy behavior."""
        now = datetime.now(UTC)
        db = MagicMock()
        db.execute.side_effect = [
            _FakeQueryResult(
                first={
                    "id": 56,
                    "user_id": 7,
                    "risk_type": "general",
                    "score": 50.0,
                    "risk_level": "medium",
                    "calculated_at": now,
                    "features": {
                        "confidence": 0.7,
                        "backend": "rule_based",
                        "model_features": {"heart_rate": 90},
                        "raw_vitals": {"heart_rate": 90, "spo2": 97},
                    },
                    "model_version": "rule-v1.0",
                    "algorithm": "rule_based",
                    "explanation_text": "Ổn định.",
                    "feature_importance": {"heart_rate": 0.3},
                    "recommendations": ["Theo dõi."],
                    "top_features_json": None,
                    "ai_explanation_json": None,
                }
            ),
            _FakeQueryResult(first=None),
            _FakeQueryResult(all_rows=[]),
        ]

        detail = MonitoringService.get_risk_report_detail(patient_id=7, report_id=56, db=db)

        assert detail is not None
        # Legacy fallback — no SHAP direction
        assert detail.top_factors[0].direction == ""
        assert detail.top_factors[0].impact == 0.0
        # ai_explanation populated from ai_explanation_json=None → still None
        # but _build_ai_explanation gets empty dict → returns None
        assert detail.ai_explanation is None
