"""Unit tests for ``app.services.risk_report_builder``.

The builders are pure functions of a normalized risk row + already-computed
dependencies, so these tests don't need a database fixture. They lock in
the Phase 1 / Phase 2 contract guarantees:

* Deprecated aliases (``risk_score``, ``xai_explanation``, ``key_features``,
  ``feature_importance``) mirror their canonical sources.
* The list view uses ``health_summary``; the detail view uses
  ``risk_summary`` (these are different strings produced by
  ``risk_inference_service`` for the two surfaces).
* The history-item builder picks the SHAP/AI explanation text first and
  falls back to ``risk_summary`` for the reason preview.
"""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any

import pytest

# These tests deliberately read deprecated aliases (``risk_score``,
# ``xai_explanation``, ``key_features``, ``feature_importance``) to verify
# they mirror their canonical sources. Silence the expected deprecation
# warnings so the suite stays quiet on the expected ones while still
# failing loudly on unexpected ones.
pytestmark = pytest.mark.filterwarnings(
    "ignore:.*scheduled for Phase 6.*:DeprecationWarning"
)

from app.schemas.monitoring import (
    AiExplanationResponse,
    FactorBreakdownResponse,
    SnapshotMetricsResponse,
    TopFactorResponse,
)
from app.services.risk_report_builder import (
    build_risk_history_item,
    build_risk_report,
    build_risk_report_detail,
)

# ---------------------------------------------------------------------------
# Shared fixtures
# ---------------------------------------------------------------------------

_FROZEN_TIMESTAMP = datetime(2026, 4, 21, 8, 0, tzinfo=UTC)


def _normalized_row() -> dict[str, Any]:
    """Minimal but representative ``_normalize_risk_row`` output."""
    return {
        "id": 42,
        "risk_type": "general",
        "risk_score": 58.0,
        "health_score": 42.0,
        "risk_level": "medium",
        "health_level": "watch",
        "display_status": "Cần theo dõi",
        "risk_summary": "Cần theo dõi nhịp tim và SpO2.",
        "health_summary": "Sức khỏe ổn định nhưng cần theo dõi.",
        "timestamp": _FROZEN_TIMESTAMP,
        "explanation_text": "Nhịp tim cao và SpO2 thấp đang đẩy mức rủi ro lên.",
        "features": {"heart_rate": 112, "spo2": 94},
        "feature_snapshot": {"heart_rate": 112, "spo2": 94},
        "raw_vitals": {"heart_rate": 112, "spo2": 94},
        "feature_importance": {"heart_rate": 0.4242, "spo2": 0.31},
        "recommendations": [
            "Đo lại chỉ số sau 15 phút",
            "Nghỉ ngơi tại chỗ",
            "Liên hệ bác sĩ nếu kéo dài",
        ],
        "top_features": [],
        "ai_explanation": {},
        "confidence": 0.82,
        "is_stale": False,
        "model_version": "model_api_v1",
        "algorithm": "model_api_health",
    }


def _top_factors() -> list[TopFactorResponse]:
    return [
        TopFactorResponse(
            key="heart_rate",
            label="Nhịp tim",
            impact=0.42,
            direction="risk_up",
            reason="Nhịp tim cao hơn bình thường",
            feature_value="112 bpm",
        ),
        TopFactorResponse(
            key="spo2",
            label="SpO₂",
            impact=0.31,
            direction="risk_up",
            reason="SpO2 dưới 95% kéo dài",
            feature_value="94 %",
        ),
    ]


def _breakdown() -> list[FactorBreakdownResponse]:
    return [
        FactorBreakdownResponse(
            key="heart_rate",
            label="Nhịp tim",
            contribution_score=0.42,
            impact_level="high",
            value="112",
            unit="bpm",
            route_target="vital_hr",
            direction="risk_up",
            reason="Nhịp tim cao hơn bình thường",
        ),
        FactorBreakdownResponse(
            key="spo2",
            label="SpO₂",
            contribution_score=0.31,
            impact_level="medium",
            value="94",
            unit="%",
            route_target="vital_spo2",
            direction="risk_up",
            reason="SpO2 dưới 95% kéo dài",
        ),
    ]


def _snapshot() -> SnapshotMetricsResponse:
    return SnapshotMetricsResponse(
        heart_rate=112,
        spo2=94,
        sys_bp=128,
        dia_bp=82,
        body_temp=36.8,
        hrv=42,
        map_val=97,
    )


def _ai_explanation() -> AiExplanationResponse:
    return AiExplanationResponse(
        short_text="Nhịp tim và SpO2 cần theo dõi sát.",
        clinical_note="HR 112 bpm vượt ngưỡng 100; SpO2 94% dưới 95%.",
        recommended_actions=["Đo lại sau 15 phút", "Nghỉ ngơi"],
    )


# ---------------------------------------------------------------------------
# build_risk_report
# ---------------------------------------------------------------------------


class TestBuildRiskReport:
    def test_canonical_and_deprecated_score_are_mirrored(self) -> None:
        report = build_risk_report(
            _normalized_row(),
            previous_score=55.0,
            trend_7d=[55, 56, 57, 58, 59, 58, 58],
            top_factors=_top_factors(),
        )
        assert report.score == 58.0
        assert report.risk_score == report.score

    def test_key_features_are_derived_from_top_factors(self) -> None:
        # Even if the normalized row carried something else for key_features,
        # the builder must derive it from top_factors so the Phase 1
        # invariant ``key_features == [f.key for f in top_factors]`` holds.
        report = build_risk_report(
            _normalized_row(),
            previous_score=None,
            trend_7d=[],
            top_factors=_top_factors(),
        )
        assert report.key_features == ["heart_rate", "spo2"]

    def test_summary_uses_health_summary_for_list_surface(self) -> None:
        # The list view surfaces ``health_summary`` (positive framing); the
        # detail view surfaces ``risk_summary``. Don't drift these.
        row = _normalized_row()
        report = build_risk_report(
            row,
            previous_score=None,
            trend_7d=[],
            top_factors=_top_factors(),
        )
        assert report.summary == row["health_summary"]

    def test_recommendation_preview_is_first_two_recommendations(self) -> None:
        report = build_risk_report(
            _normalized_row(),
            previous_score=None,
            trend_7d=[],
            top_factors=_top_factors(),
        )
        assert report.recommendation_preview == [
            "Đo lại chỉ số sau 15 phút",
            "Nghỉ ngơi tại chỗ",
        ]

    def test_passes_through_optional_previous_score(self) -> None:
        report = build_risk_report(
            _normalized_row(),
            previous_score=None,
            trend_7d=[],
            top_factors=_top_factors(),
        )
        assert report.previous_score is None


# ---------------------------------------------------------------------------
# build_risk_report_detail
# ---------------------------------------------------------------------------


class TestBuildRiskReportDetail:
    def test_canonical_and_deprecated_score_are_mirrored(self) -> None:
        detail = build_risk_report_detail(
            _normalized_row(),
            previous_score=55.0,
            trend_7d=[55, 56, 57, 58],
            top_factors=_top_factors(),
            breakdown=_breakdown(),
            snapshot=_snapshot(),
            ai_explanation=_ai_explanation(),
        )
        assert detail.score == 58.0
        assert detail.risk_score == detail.score

    def test_canonical_and_deprecated_explanation_are_mirrored(self) -> None:
        detail = build_risk_report_detail(
            _normalized_row(),
            previous_score=None,
            trend_7d=[],
            top_factors=_top_factors(),
            breakdown=_breakdown(),
            snapshot=_snapshot(),
            ai_explanation=None,
        )
        assert detail.explanation == (
            "Nhịp tim cao và SpO2 thấp đang đẩy mức rủi ro lên."
        )
        assert detail.xai_explanation == detail.explanation

    def test_explanation_falls_back_to_empty_string_when_missing(self) -> None:
        row = _normalized_row()
        row["explanation_text"] = None
        detail = build_risk_report_detail(
            row,
            previous_score=None,
            trend_7d=[],
            top_factors=_top_factors(),
            breakdown=_breakdown(),
            snapshot=_snapshot(),
            ai_explanation=None,
        )
        assert detail.explanation == ""
        assert detail.xai_explanation == ""

    def test_summary_uses_risk_summary_for_detail_surface(self) -> None:
        row = _normalized_row()
        detail = build_risk_report_detail(
            row,
            previous_score=None,
            trend_7d=[],
            top_factors=_top_factors(),
            breakdown=_breakdown(),
            snapshot=_snapshot(),
            ai_explanation=None,
        )
        assert detail.summary == row["risk_summary"]

    def test_feature_importance_is_rounded_to_4_decimals(self) -> None:
        row = _normalized_row()
        # 0.4242 already has 4 decimals; verify rounding works for longer
        # floats too.
        row["feature_importance"] = {"heart_rate": 0.42424242, "spo2": 0.31}
        detail = build_risk_report_detail(
            row,
            previous_score=None,
            trend_7d=[],
            top_factors=_top_factors(),
            breakdown=_breakdown(),
            snapshot=_snapshot(),
            ai_explanation=None,
        )
        assert detail.feature_importance == {"heart_rate": 0.4242, "spo2": 0.31}

    def test_feature_importance_keys_are_subset_of_breakdown_keys(self) -> None:
        # Phase 1 invariant: the deprecated ``feature_importance`` must be
        # reconstructible from the canonical ``breakdown``.
        detail = build_risk_report_detail(
            _normalized_row(),
            previous_score=None,
            trend_7d=[],
            top_factors=_top_factors(),
            breakdown=_breakdown(),
            snapshot=_snapshot(),
            ai_explanation=None,
        )
        breakdown_keys = {factor.key for factor in detail.breakdown}
        assert set(detail.feature_importance.keys()).issubset(breakdown_keys)

    def test_model_metadata_falls_back_when_missing(self) -> None:
        row = _normalized_row()
        row["model_version"] = None
        row["algorithm"] = None
        detail = build_risk_report_detail(
            row,
            previous_score=None,
            trend_7d=[],
            top_factors=_top_factors(),
            breakdown=_breakdown(),
            snapshot=_snapshot(),
            ai_explanation=None,
        )
        assert detail.model_version == "1.0"
        assert detail.algorithm == "unknown"


# ---------------------------------------------------------------------------
# build_risk_history_item
# ---------------------------------------------------------------------------


class TestBuildRiskHistoryItem:
    def test_canonical_and_deprecated_score_are_mirrored(self) -> None:
        item = build_risk_history_item(_normalized_row())
        assert item.score == 58.0
        assert item.risk_score == item.score

    def test_reason_preview_prefers_explanation_text(self) -> None:
        item = build_risk_history_item(_normalized_row())
        assert item.reason_preview == (
            "Nhịp tim cao và SpO2 thấp đang đẩy mức rủi ro lên."
        )

    def test_reason_preview_falls_back_to_risk_summary(self) -> None:
        row = _normalized_row()
        row["explanation_text"] = None
        item = build_risk_history_item(row)
        assert item.reason_preview == row["risk_summary"]

    def test_reason_preview_strips_whitespace_only_explanation(self) -> None:
        # Pre-existing producer behavior (preserved by Phase 2 verbatim):
        # a whitespace-only ``explanation_text`` wins the ``or`` chain and
        # gets ``.strip()``-ed down to "" rather than falling back to
        # ``risk_summary``. This is arguably a bug; if changed in a future
        # phase, update this test alongside ``monitoring_service``.
        row = _normalized_row()
        row["explanation_text"] = "   "
        item = build_risk_history_item(row)
        assert item.reason_preview == ""


# ---------------------------------------------------------------------------
# Cross-cutting: builders must satisfy the Phase 1 contract invariants
# ---------------------------------------------------------------------------


class TestBuilderInvariants:
    """Cheap regression guards mirroring TestDeprecatedFieldInvariants but at
    the builder layer — catches the bug class where a refactor breaks the
    invariant inside the builder before any other test surfaces it.
    """

    def test_report_invariants(self) -> None:
        report = build_risk_report(
            _normalized_row(),
            previous_score=None,
            trend_7d=[],
            top_factors=_top_factors(),
        )
        assert report.risk_score == report.score
        assert report.key_features == [f.key for f in report.top_factors]
        assert report.display_status

    def test_detail_invariants(self) -> None:
        detail = build_risk_report_detail(
            _normalized_row(),
            previous_score=None,
            trend_7d=[],
            top_factors=_top_factors(),
            breakdown=_breakdown(),
            snapshot=_snapshot(),
            ai_explanation=_ai_explanation(),
        )
        assert detail.risk_score == detail.score
        assert detail.xai_explanation == detail.explanation
        assert set(detail.feature_importance.keys()).issubset(
            {b.key for b in detail.breakdown}
        )
        assert detail.display_status

    def test_history_item_invariants(self) -> None:
        item = build_risk_history_item(_normalized_row())
        assert item.risk_score == item.score
        assert item.display_status
