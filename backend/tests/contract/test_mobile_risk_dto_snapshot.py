"""Phase 0 — Mobile risk DTO contract snapshot.

Pins the JSON keys exposed to the Flutter app by:

- ``GET  /api/v1/mobile/analysis/risk-reports``        (``RiskReportResponse[]``)
- ``GET  /api/v1/mobile/analysis/risk-reports/{id}``   (``RiskReportDetailResponse``)
- ``GET  /api/v1/mobile/analysis/risk-history``        (``RiskHistoryResponse``)

The point of this test is **not** to validate logic — that lives in
``test_monitoring_service_contract.py`` and ``test_shap_explanation_contract.py``.
This test fails loudly if a future PR adds, removes, or renames a key
without an explicit, intentional update here. That guard is the whole
point of "Phase 0 baseline" before the larger DTO cleanup in Phase 1.

Update procedure when the contract genuinely evolves:

1. Change the schema in ``app.schemas.monitoring``.
2. Update the matching ``EXPECTED_*_KEYS`` set in this file.
3. Bump the version table in ``backend/docs/risk-contract-baseline.md``.
4. If the change is breaking for older mobile binaries, also bump
   ``X-Risk-Contract-Version`` (planned in Phase 6).
"""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any

import pytest

from app.schemas.monitoring import (
    AiExplanationResponse,
    FactorBreakdownResponse,
    RiskHistoryItemResponse,
    RiskHistoryResponse,
    RiskHistorySummaryResponse,
    RiskReportDetailResponse,
    RiskReportResponse,
    SnapshotMetricsResponse,
    TopFactorResponse,
)


# ---------------------------------------------------------------------------
# Frozen sample data — keeps every snapshot deterministic
# ---------------------------------------------------------------------------

_FROZEN_TIMESTAMP = datetime(2026, 4, 27, 8, 0, tzinfo=UTC)


def _build_top_factor() -> TopFactorResponse:
    return TopFactorResponse(
        key="heart_rate",
        label="Nhịp tim",
        impact=0.42,
        direction="risk_up",
        reason="Nhịp tim cao hơn bình thường",
        feature_value="112 bpm",
    )


def _build_top_factors() -> list[TopFactorResponse]:
    """Top-factors list aligned with ``key_features`` and ``feature_importance``.

    Phase 1 invariant: ``key_features`` must equal ``[f.key for f in top_factors]``,
    so the fixture exposes the same two factors that ``key_features`` carries.
    """
    return [
        _build_top_factor(),
        TopFactorResponse(
            key="spo2",
            label="SpO₂",
            impact=0.31,
            direction="risk_up",
            reason="SpO2 dưới 95% kéo dài",
            feature_value="94 %",
        ),
    ]


def _build_breakdown_item() -> FactorBreakdownResponse:
    return FactorBreakdownResponse(
        key="spo2",
        label="SpO₂",
        contribution_score=0.31,
        impact_level="medium",
        value="94",
        unit="%",
        route_target="vitals/spo2",
        direction="risk_up",
        reason="SpO2 dưới 95% kéo dài",
    )


def _build_breakdown_items() -> list[FactorBreakdownResponse]:
    """Detail-level breakdown that covers every key in ``feature_importance``.

    Phase 1 deprecation guarantees that ``feature_importance.keys()`` is a
    subset of ``{b.key for b in breakdown}`` so removing ``feature_importance``
    in Phase 6 cannot lose data.
    """
    return [
        FactorBreakdownResponse(
            key="heart_rate",
            label="Nhịp tim",
            contribution_score=0.42,
            impact_level="high",
            value="112",
            unit="bpm",
            route_target="vitals/heart_rate",
            direction="risk_up",
            reason="Nhịp tim cao hơn bình thường",
        ),
        _build_breakdown_item(),
    ]


def _build_ai_explanation() -> AiExplanationResponse:
    return AiExplanationResponse(
        short_text="Nhịp tim và SpO2 cần theo dõi sát.",
        clinical_note="HR 112 bpm vượt ngưỡng 100; SpO2 94% dưới 95%.",
        recommended_actions=[
            "Đo lại chỉ số sau 15 phút",
            "Nghỉ ngơi tại chỗ",
        ],
    )


def _build_snapshot_metrics() -> SnapshotMetricsResponse:
    return SnapshotMetricsResponse(
        heart_rate=112,
        spo2=94,
        sys_bp=128,
        dia_bp=82,
        body_temp=36.9,
        hrv=42,
        map_val=97,
    )


def _build_risk_report() -> RiskReportResponse:
    return RiskReportResponse(
        id=42,
        risk_type="general",
        risk_score=58.0,
        score=58.0,
        health_score=42.0,
        risk_level="medium",
        health_level="watch",
        display_status="Cần theo dõi",
        summary="Sức khỏe ổn định nhưng cần theo dõi nhịp tim và SpO2.",
        timestamp=_FROZEN_TIMESTAMP,
        previous_score=55.0,
        trend_7d=[55, 56, 57, 58, 59, 58, 58],
        key_features=["heart_rate", "spo2"],
        top_factors=_build_top_factors(),
        recommendation_preview=["Đo lại chỉ số sau 15 phút"],
        confidence=0.82,
        is_stale=False,
    )


def _build_risk_report_detail() -> RiskReportDetailResponse:
    return RiskReportDetailResponse(
        id=42,
        risk_type="general",
        risk_score=58.0,
        score=58.0,
        health_score=42.0,
        risk_level="medium",
        health_level="watch",
        display_status="Cần theo dõi",
        summary="Sức khỏe ổn định nhưng cần theo dõi nhịp tim và SpO2.",
        timestamp=_FROZEN_TIMESTAMP,
        previous_score=55.0,
        trend_7d=[55, 56, 57, 58, 59, 58, 58],
        explanation="Nhịp tim cao và SpO2 thấp đang đẩy mức rủi ro lên.",
        xai_explanation="Nhịp tim cao và SpO2 thấp đang đẩy mức rủi ro lên.",
        features={"heart_rate": 112, "spo2": 94},
        feature_importance={"heart_rate": 0.42, "spo2": 0.31},
        breakdown=_build_breakdown_items(),
        recommendations=[
            "Đo lại chỉ số sau 15 phút",
            "Nghỉ ngơi tại chỗ",
        ],
        recommendation_preview=["Đo lại chỉ số sau 15 phút"],
        top_factors=_build_top_factors(),
        snapshot=_build_snapshot_metrics(),
        model_version="model_api_v1",
        algorithm="model_api_health",
        confidence=0.82,
        is_stale=False,
        ai_explanation=_build_ai_explanation(),
    )


def _build_risk_history() -> RiskHistoryResponse:
    return RiskHistoryResponse(
        range="7d",
        summary=RiskHistorySummaryResponse(
            average_score=57.4,
            highest_score=62.0,
            lowest_score=51.0,
            delta_vs_previous_period=-3.5,
            trend_points=[55, 56, 57, 58, 59, 58, 58],
        ),
        items=[
            RiskHistoryItemResponse(
                report_id=42,
                risk_score=58.0,
                score=58.0,
                health_score=42.0,
                risk_level="medium",
                display_status="Cần theo dõi",
                analyzed_at=_FROZEN_TIMESTAMP,
                reason_preview="Nhịp tim cao",
                is_stale=False,
            ),
        ],
        page=1,
        limit=20,
        has_more=False,
    )


# ---------------------------------------------------------------------------
# Expected key sets — frozen at Phase 0 baseline (refactor/ux-phase1-and-2 HEAD)
# ---------------------------------------------------------------------------

EXPECTED_TOP_FACTOR_KEYS: frozenset[str] = frozenset({
    "key",
    "label",
    "impact",
    "direction",
    "reason",
    "feature_value",
})

EXPECTED_BREAKDOWN_ITEM_KEYS: frozenset[str] = frozenset({
    "key",
    "label",
    "contribution_score",
    "impact_level",
    "value",
    "unit",
    "route_target",
    "direction",
    "reason",
})

EXPECTED_AI_EXPLANATION_KEYS: frozenset[str] = frozenset({
    "short_text",
    "clinical_note",
    "recommended_actions",
})

EXPECTED_SNAPSHOT_METRICS_KEYS: frozenset[str] = frozenset({
    "heart_rate",
    "spo2",
    "sys_bp",
    "dia_bp",
    "body_temp",
    "hrv",
    "map_val",
})

EXPECTED_RISK_REPORT_KEYS: frozenset[str] = frozenset({
    "id",
    "risk_type",
    "risk_score",        # Phase 1 candidate to drop (alias of `score`)
    "score",
    "health_score",
    "risk_level",
    "health_level",      # Phase 1 candidate to drop (overlap with display_status)
    "display_status",
    "summary",
    "timestamp",
    "previous_score",
    "trend_7d",
    "key_features",      # Phase 1 candidate to drop (derivable from top_factors)
    "top_factors",
    "recommendation_preview",
    "confidence",
    "is_stale",
})

EXPECTED_RISK_REPORT_DETAIL_KEYS: frozenset[str] = frozenset({
    "id",
    "risk_type",
    "risk_score",        # Phase 1 candidate to drop
    "score",
    "health_score",
    "risk_level",
    "health_level",      # Phase 1 candidate to drop
    "display_status",
    "summary",
    "timestamp",
    "previous_score",
    "trend_7d",
    "explanation",
    "xai_explanation",   # Phase 1 candidate to drop (alias of explanation)
    "features",
    "feature_importance",  # Phase 1 candidate to drop (subset of breakdown)
    "breakdown",
    "recommendations",
    "recommendation_preview",
    "top_factors",
    "snapshot",
    "model_version",
    "algorithm",
    "confidence",
    "is_stale",
    "ai_explanation",
})

EXPECTED_RISK_HISTORY_SUMMARY_KEYS: frozenset[str] = frozenset({
    "average_score",
    "highest_score",
    "lowest_score",
    "delta_vs_previous_period",
    "trend_points",
})

EXPECTED_RISK_HISTORY_ITEM_KEYS: frozenset[str] = frozenset({
    "report_id",
    "risk_score",        # Phase 1 candidate to drop
    "score",
    "health_score",
    "risk_level",
    "display_status",
    "analyzed_at",
    "reason_preview",
    "is_stale",
})

EXPECTED_RISK_HISTORY_KEYS: frozenset[str] = frozenset({
    "range",
    "summary",
    "items",
    "page",
    "limit",
    "has_more",
})


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _drift_message(*, name: str, expected: frozenset[str], actual: set[str]) -> str:
    added = actual - expected
    removed = expected - actual
    return (
        f"Mobile contract drift detected on {name!r}.\n"
        f"  Added keys:   {sorted(added)}\n"
        f"  Removed keys: {sorted(removed)}\n"
        "If intentional, update the matching EXPECTED_*_KEYS in "
        "backend/tests/contract/test_mobile_risk_dto_snapshot.py and "
        "bump backend/docs/risk-contract-baseline.md."
    )


def _assert_keys(*, name: str, expected: frozenset[str], payload: dict[str, Any]) -> None:
    actual = set(payload.keys())
    assert actual == expected, _drift_message(
        name=name, expected=expected, actual=actual
    )


# ---------------------------------------------------------------------------
# Tests — top-level mobile DTOs
# ---------------------------------------------------------------------------


class TestMobileRiskDtoContractSnapshot:
    """Pin the public JSON shape of the three mobile risk routes."""

    def test_risk_report_response_keys_are_pinned(self) -> None:
        payload = _build_risk_report().model_dump()
        _assert_keys(
            name="RiskReportResponse",
            expected=EXPECTED_RISK_REPORT_KEYS,
            payload=payload,
        )

    def test_risk_report_detail_response_keys_are_pinned(self) -> None:
        payload = _build_risk_report_detail().model_dump()
        _assert_keys(
            name="RiskReportDetailResponse",
            expected=EXPECTED_RISK_REPORT_DETAIL_KEYS,
            payload=payload,
        )

    def test_risk_history_response_keys_are_pinned(self) -> None:
        payload = _build_risk_history().model_dump()
        _assert_keys(
            name="RiskHistoryResponse",
            expected=EXPECTED_RISK_HISTORY_KEYS,
            payload=payload,
        )


# ---------------------------------------------------------------------------
# Tests — nested types (drift here also breaks mobile parsing)
# ---------------------------------------------------------------------------


class TestNestedDtoContractSnapshot:
    """Pin nested response shapes — mobile parsers are positional on each."""

    def test_top_factor_response_keys_are_pinned(self) -> None:
        payload = _build_top_factor().model_dump()
        _assert_keys(
            name="TopFactorResponse",
            expected=EXPECTED_TOP_FACTOR_KEYS,
            payload=payload,
        )

    def test_factor_breakdown_response_keys_are_pinned(self) -> None:
        payload = _build_breakdown_item().model_dump()
        _assert_keys(
            name="FactorBreakdownResponse",
            expected=EXPECTED_BREAKDOWN_ITEM_KEYS,
            payload=payload,
        )

    def test_ai_explanation_response_keys_are_pinned(self) -> None:
        payload = _build_ai_explanation().model_dump()
        _assert_keys(
            name="AiExplanationResponse",
            expected=EXPECTED_AI_EXPLANATION_KEYS,
            payload=payload,
        )

    def test_snapshot_metrics_response_keys_are_pinned(self) -> None:
        payload = _build_snapshot_metrics().model_dump()
        _assert_keys(
            name="SnapshotMetricsResponse",
            expected=EXPECTED_SNAPSHOT_METRICS_KEYS,
            payload=payload,
        )

    def test_risk_history_summary_response_keys_are_pinned(self) -> None:
        payload = RiskHistorySummaryResponse().model_dump()
        _assert_keys(
            name="RiskHistorySummaryResponse",
            expected=EXPECTED_RISK_HISTORY_SUMMARY_KEYS,
            payload=payload,
        )

    def test_risk_history_item_response_keys_are_pinned(self) -> None:
        item = _build_risk_history().items[0]
        payload = item.model_dump()
        _assert_keys(
            name="RiskHistoryItemResponse",
            expected=EXPECTED_RISK_HISTORY_ITEM_KEYS,
            payload=payload,
        )


# ---------------------------------------------------------------------------
# Smoke tests — the JSON round-trip must be lossless and deterministic
# ---------------------------------------------------------------------------


class TestMobileRiskDtoJsonRoundtrip:
    """Catch silent drift caused by ``model_config`` changes (e.g. aliasing)."""

    @pytest.mark.parametrize(
        "factory",
        [
            _build_risk_report,
            _build_risk_report_detail,
            _build_risk_history,
        ],
        ids=["risk_report", "risk_report_detail", "risk_history"],
    )
    def test_serialize_deserialize_preserves_keys(self, factory) -> None:
        original = factory()
        json_text = original.model_dump_json()
        rebuilt = type(original).model_validate_json(json_text)
        assert rebuilt.model_dump() == original.model_dump()


# ---------------------------------------------------------------------------
# Tests — Phase 1 deprecation invariants
# ---------------------------------------------------------------------------


class TestDeprecatedFieldInvariants:
    """Phase 1 invariants — every deprecated alias must mirror its canonical source.

    These guarantees are what make the Phase 6 removal safe: as long as the
    deprecated field's value is reconstructible from the canonical field, the
    backend can stop emitting it without losing data.

    The tests deliberately access deprecated attributes; the corresponding
    ``DeprecationWarning`` is filtered so the suite stays quiet on the
    expected warnings while still failing loudly on real invariant breaks.
    """

    @pytest.fixture(autouse=True)
    def _silence_expected_deprecation_warnings(self):
        import warnings

        with warnings.catch_warnings():
            warnings.filterwarnings(
                "ignore",
                category=DeprecationWarning,
                message=r".*scheduled for Phase 6.*",
            )
            yield

    def test_risk_score_mirrors_score_in_report(self) -> None:
        report = _build_risk_report()
        assert report.risk_score == report.score

    def test_risk_score_mirrors_score_in_detail(self) -> None:
        detail = _build_risk_report_detail()
        assert detail.risk_score == detail.score

    def test_risk_score_mirrors_score_in_history_items(self) -> None:
        history = _build_risk_history()
        assert history.items, "fixture must contain at least one history item"
        for item in history.items:
            assert item.risk_score == item.score, (
                f"risk_score {item.risk_score} != score {item.score} on item "
                f"{item.report_id}"
            )

    def test_xai_explanation_mirrors_explanation(self) -> None:
        detail = _build_risk_report_detail()
        assert detail.xai_explanation == detail.explanation

    def test_key_features_derive_from_top_factors(self) -> None:
        report = _build_risk_report()
        assert report.key_features == [factor.key for factor in report.top_factors]

    def test_feature_importance_keys_are_subset_of_breakdown_keys(self) -> None:
        detail = _build_risk_report_detail()
        breakdown_keys = {factor.key for factor in detail.breakdown}
        importance_keys = set(detail.feature_importance.keys())
        assert importance_keys.issubset(breakdown_keys), (
            "feature_importance carries keys missing from breakdown — "
            "Phase 6 removal would lose data.\n"
            f"  feature_importance keys: {sorted(importance_keys)}\n"
            f"  breakdown keys:          {sorted(breakdown_keys)}\n"
            f"  missing from breakdown:  {sorted(importance_keys - breakdown_keys)}"
        )

    def test_health_level_is_optional_when_display_status_present(self) -> None:
        # ``display_status`` is canonical and must never be empty; ``health_level``
        # may be ``None`` (since Phase 1 it is purely optional).
        report = _build_risk_report()
        detail = _build_risk_report_detail()
        for dto in (report, detail):
            assert dto.display_status, "display_status must be populated"
