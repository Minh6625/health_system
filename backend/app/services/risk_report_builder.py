"""Pure DTO builders for the mobile risk-report contract.

Phase 2 (see ``backend/docs/risk-contract-baseline.md``) extracts the DTO
construction logic out of :mod:`monitoring_service` so:

* Both list and detail code paths assemble :class:`RiskReportResponse` /
  :class:`RiskReportDetailResponse` through one call site, eliminating the
  field-level duplication that originally allowed ``risk_score`` and
  ``score`` to drift.
* The Phase 1 invariants (``risk_score == score``,
  ``xai_explanation == explanation``, ``key_features == [f.key for f in
  top_factors]``) are encoded *once*, here, and impossible to forget at the
  call sites.
* The builders are pure functions of ``normalized`` + already-computed
  dependencies, so they can be unit-tested without a database fixture.

The shape of ``normalized`` is the dict returned by
``MonitoringService._normalize_risk_row``. We deliberately keep it as a
plain dict for now; introducing a typed ``NormalizedRiskRow`` is tracked as
a possible follow-up and would be a much larger change.
"""

from __future__ import annotations

from typing import Any

from app.schemas.monitoring import (
    AiExplanationResponse,
    FactorBreakdownResponse,
    RiskHistoryItemResponse,
    RiskReportDetailResponse,
    RiskReportResponse,
    SnapshotMetricsResponse,
    TopFactorResponse,
)

__all__ = [
    "build_risk_report",
    "build_risk_report_detail",
    "build_risk_history_item",
]


def build_risk_report(
    normalized: dict[str, Any],
    *,
    previous_score: float | None,
    trend_7d: list[int],
    top_factors: list[TopFactorResponse],
) -> RiskReportResponse:
    """Build a :class:`RiskReportResponse` from a normalized risk row.

    The deprecated aliases ``risk_score`` and ``key_features`` are populated
    from their canonical sources so the Phase 1 invariants always hold.
    """

    score = float(normalized["risk_score"])
    return RiskReportResponse(
        id=normalized["id"],
        risk_type=normalized["risk_type"],
        # Canonical: ``score``. Deprecated alias ``risk_score`` mirrors it
        # so older clients keep parsing until Phase 6.
        risk_score=score,
        score=score,
        health_score=normalized["health_score"],
        risk_level=normalized["risk_level"],
        health_level=normalized["health_level"],
        display_status=normalized["display_status"],
        summary=normalized["health_summary"],
        timestamp=normalized["timestamp"],
        previous_score=previous_score,
        trend_7d=trend_7d,
        # Canonical: ``top_factors``. Deprecated ``key_features`` is derived
        # from it so the two cannot drift.
        key_features=[factor.key for factor in top_factors],
        top_factors=top_factors,
        recommendation_preview=normalized["recommendations"][:2],
        confidence=normalized["confidence"],
        is_stale=normalized["is_stale"],
    )


def build_risk_report_detail(
    normalized: dict[str, Any],
    *,
    previous_score: float | None,
    trend_7d: list[int],
    top_factors: list[TopFactorResponse],
    breakdown: list[FactorBreakdownResponse],
    snapshot: SnapshotMetricsResponse,
    ai_explanation: AiExplanationResponse | None,
) -> RiskReportDetailResponse:
    """Build a :class:`RiskReportDetailResponse` from a normalized risk row.

    The deprecated aliases ``risk_score`` and ``xai_explanation`` are
    populated from their canonical sources so the Phase 1 invariants always
    hold. ``feature_importance`` is derived from the normalized row;
    Phase 1 guarantees its keys are a subset of the breakdown keys.
    """

    score = float(normalized["risk_score"])
    explanation = str(normalized.get("explanation_text") or "")
    feature_importance = {
        key: round(_safe_float(value), 4)
        for key, value in normalized["feature_importance"].items()
    }
    return RiskReportDetailResponse(
        id=normalized["id"],
        risk_type=normalized["risk_type"],
        # Canonical: ``score``. Deprecated alias ``risk_score`` mirrors it.
        risk_score=score,
        score=score,
        health_score=normalized["health_score"],
        risk_level=normalized["risk_level"],
        health_level=normalized["health_level"],
        display_status=normalized["display_status"],
        summary=normalized["risk_summary"],
        timestamp=normalized["timestamp"],
        previous_score=previous_score,
        trend_7d=trend_7d,
        # Canonical: ``explanation``. Deprecated alias ``xai_explanation``
        # mirrors it so older clients keep parsing until Phase 6.
        explanation=explanation,
        xai_explanation=explanation,
        features=normalized["features"],
        feature_importance=feature_importance,
        breakdown=breakdown,
        recommendations=normalized["recommendations"],
        recommendation_preview=normalized["recommendations"][:2],
        top_factors=top_factors,
        snapshot=snapshot,
        model_version=str(normalized.get("model_version") or "1.0"),
        algorithm=str(normalized.get("algorithm") or "unknown"),
        confidence=normalized["confidence"],
        is_stale=normalized["is_stale"],
        ai_explanation=ai_explanation,
    )


def build_risk_history_item(
    normalized: dict[str, Any],
) -> RiskHistoryItemResponse:
    """Build a :class:`RiskHistoryItemResponse` from a normalized risk row.

    The deprecated alias ``risk_score`` mirrors the canonical ``score``.
    The reason preview prefers the SHAP/AI explanation text and falls back
    to the canonical risk summary, matching the legacy behavior.
    """

    score = float(normalized["risk_score"])
    reason_preview = str(
        normalized.get("explanation_text") or normalized["risk_summary"]
    ).strip()
    return RiskHistoryItemResponse(
        report_id=normalized["id"],
        risk_score=score,
        score=score,
        health_score=normalized["health_score"],
        risk_level=normalized["risk_level"],
        display_status=normalized["display_status"],
        analyzed_at=normalized["timestamp"],
        reason_preview=reason_preview,
        is_stale=normalized["is_stale"],
    )


def _safe_float(value: Any, default: float = 0.0) -> float:
    """Mirror of ``MonitoringService._safe_float`` kept private to this module.

    Duplicated to avoid importing from :mod:`monitoring_service` (which would
    create a cycle once Phase 2 wires the service through this builder).
    """

    if value is None:
        return default
    try:
        return float(value)
    except (TypeError, ValueError):
        return default
