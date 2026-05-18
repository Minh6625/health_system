"""Adapter for the model-api sleep score endpoint (Phase 4A-thin).

Converts a model-api ``SleepPredictionResult`` into a
:class:`NormalizedExplanation` that the existing
:class:`RiskPersistenceAdapter` can persist with ``risk_type='sleep'``.

The single non-trivial transformation here is **sleep-score inversion**:

* Model-api returns ``predicted_sleep_score`` on a 0–100 scale where
  **higher = better sleep**.
* The ``risk_scores`` table stores risk on a 0–100 scale where
  **higher = worse risk**.

So the adapter writes ``risk_score = 100 - predicted_sleep_score``. This
matches plan §4A's risk note ("sleep score 0-100 high=tốt — convention
khác health risk (low=tốt) — adapter phải chuyển đúng") and lets sleep
rows live alongside vitals rows in the same risk-trend chart without
the mobile having to special-case the axis.

Risk-level mapping mirrors the band convention from the model-api:

* ``risk_level == "critical"`` (band ``poor`` / ``critical``) → already
  canonical.
* ``risk_level == "warning"`` (band ``fair``) → ``medium``.
* ``risk_level == "normal"`` (band ``good`` / ``excellent``) → ``low``.

Anything unrecognised defaults to ``medium`` so the row still passes
the ``check_risk_level`` constraint.
"""

from __future__ import annotations

import math
from typing import Any

from app.adapters.normalized_explanation import NormalizedExplanation


# ``predicted_sleep_label`` / model-api ``risk_level`` → backend canonical risk_level.
# The model-api uses ``normal | warning | critical`` (matches the health endpoint).
_SLEEP_RISK_LEVEL_MAP: dict[str, str] = {
    "normal": "low",
    "warning": "medium",
    "critical": "critical",
    # ``high`` / ``moderate`` aliases for resilience against future
    # model-api wording drift; same mapping as the health adapter.
    "high": "medium",
    "moderate": "medium",
    "medium": "medium",
    "low": "low",
}


class SleepRiskAdapter:
    """Boundary class between the model-api sleep endpoint and persistence."""

    @staticmethod
    def to_record(sleep_record: dict[str, Any]) -> dict[str, Any]:
        """Pass-through projection — the route already validated the shape.

        ``sleep_record`` must already match the model-api ``SleepRecord``
        contract; the route's :class:`SleepRiskRequest` is a verbatim
        port of that schema, so we just return a copy. Defined as a
        method anyway for symmetry with
        :class:`ModelApiHealthAdapter.to_record`.
        """
        return dict(sleep_record)

    @staticmethod
    def from_response(
        response: dict[str, Any],
        *,
        sleep_record: dict[str, Any],
    ) -> NormalizedExplanation:
        """Translate a model-api sleep result to ``NormalizedExplanation``.

        Sleep-score inversion happens here: the persisted ``risk_score``
        is ``100 - predicted_sleep_score`` so the row sits on the same
        axis as vitals risk rows.
        """
        backend_label = "model_api_sleep"
        meta = response.get("meta") if isinstance(response.get("meta"), dict) else {}
        model_version_label = str(meta.get("model_version") or "model_api_sleep_v1")[:20]

        sleep_score = SleepRiskAdapter._extract_sleep_score(response)
        risk_score = max(0.0, min(100.0, round(100.0 - sleep_score, 2)))
        confidence_value = SleepRiskAdapter._extract_confidence(response)

        raw_level = response.get("risk_level") or (
            response.get("prediction") or {}
        ).get("prediction_band")
        risk_level = SleepRiskAdapter._map_risk_level(raw_level) or "medium"

        prediction_label = str(
            response.get("predicted_sleep_label")
            or (response.get("prediction") or {}).get("prediction_label")
            or risk_level
        )

        ai_explanation = response.get("explanation") or {}
        if not isinstance(ai_explanation, dict):
            ai_explanation = {}
        explanation_text = str(ai_explanation.get("short_text") or "").strip() or (
            f"Mô hình giấc ngủ dự báo điểm {sleep_score:.0f}/100 "
            f"(nguy cơ ở mức {risk_level})."
        )
        clinical_note = str(ai_explanation.get("clinical_note") or "").strip()

        recommendations_raw = ai_explanation.get("recommended_actions") or []
        recommendations = [
            str(item).strip() for item in recommendations_raw if str(item).strip()
        ] or SleepRiskAdapter._default_recommendations(risk_level)

        ai_explanation_payload = {
            "short_text": explanation_text,
            "clinical_note": clinical_note,
            "recommended_actions": recommendations,
        }

        top_features = response.get("top_features") or []
        if not isinstance(top_features, list):
            top_features = []

        # ``feature_importance`` is the legacy flat dict consumed by the
        # mobile risk surface. Build it from top_features so the mobile
        # gets the same structure it does today for the health domain.
        feature_importance: dict[str, float] = {}
        for entry in top_features:
            if not isinstance(entry, dict):
                continue
            key = str(entry.get("feature") or "").strip()
            if not key:
                continue
            try:
                feature_importance[key] = round(float(entry.get("impact") or 0.0), 4)
            except (TypeError, ValueError):
                continue

        shap_details = response.get("shap")
        if not isinstance(shap_details, dict):
            shap_details = None

        # Phase 2: pull upstream meta.request_id for log correlation.
        raw_request_id = meta.get("request_id") if isinstance(meta, dict) else None
        model_request_id: str | None = None
        if raw_request_id is not None:
            candidate = str(raw_request_id).strip()
            model_request_id = candidate[:36] if candidate else None

        return NormalizedExplanation(
            risk_level=risk_level,
            risk_score=risk_score,
            confidence_value=confidence_value,
            prediction_label=prediction_label,
            label_id=None,
            backend_label=backend_label,
            model_version_label=model_version_label,
            explanation_text=explanation_text,
            recommendations=recommendations,
            feature_importance=feature_importance,
            top_features=top_features,
            ai_explanation_payload=ai_explanation_payload,
            shap_details=shap_details,
            xai_method="shap"
            if isinstance(shap_details, dict) and shap_details.get("available")
            else "rule_based",
            artifact_path=meta.get("artifact_path") if isinstance(meta, dict) else None,
            fallback_reason=None,
            model_request_id=model_request_id,
        )

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _extract_sleep_score(response: dict[str, Any]) -> float:
        """Pull the sleep score in the [0, 100] scale (high = good).

        Prefers the top-level ``predicted_sleep_score`` (convenience
        field on ``SleepPredictionResult``), falls back to
        ``prediction.prediction_score`` (which the model-api scales to
        the same [0, 100]). Returns ``0.0`` if neither is parseable —
        the inversion to ``risk_score = 100 - 0 = 100`` deliberately
        flags "we got nothing useful from the model" as critical risk
        rather than silently treating it as healthy sleep.

        P1-3 (2026-05-18): NaN/inf bypass guard. ``max(0, min(100,
        NaN))`` returns NaN because every NaN comparison is False,
        which would propagate into ``risk_score = 100 - NaN = NaN``
        and corrupt the persisted DB row. Treat any non-finite value
        as the same "nothing useful" signal that nulls produce.
        """
        raw = response.get("predicted_sleep_score")
        if raw is None:
            inner = response.get("prediction") or {}
            if isinstance(inner, dict):
                raw = inner.get("prediction_score")
        try:
            value = float(raw) if raw is not None else 0.0
        except (TypeError, ValueError):
            value = 0.0
        if math.isnan(value) or math.isinf(value):
            value = 0.0
        return max(0.0, min(100.0, value))

    @staticmethod
    def _extract_confidence(response: dict[str, Any]) -> float:
        """Pull a [0, 1] confidence value off ``prediction.prediction_score``.

        Sleep results don't surface a separate ``confidence`` field; the
        prediction_score doubles as both the inverted risk and the
        confidence proxy. We divide by 100 so it lands in [0, 1] like
        the health adapter.

        P1-3: NaN/inf guard mirrors :meth:`_extract_sleep_score`.
        """
        prediction = response.get("prediction") or {}
        raw = prediction.get("prediction_score") if isinstance(prediction, dict) else None
        try:
            value = float(raw) / 100.0 if raw is not None else 0.0
        except (TypeError, ValueError):
            value = 0.0
        if math.isnan(value) or math.isinf(value):
            value = 0.0
        return max(0.0, min(1.0, value))

    @staticmethod
    def _map_risk_level(raw_level: str | None) -> str | None:
        if not raw_level:
            return None
        return _SLEEP_RISK_LEVEL_MAP.get(str(raw_level).strip().lower())

    @staticmethod
    def _default_recommendations(risk_level: str) -> list[str]:
        """Sleep-domain fallback recommendations.

        Pinned by the route-level test ``test_sleep_risk_route.py``;
        update both together if the copy changes.
        """
        normalized = (risk_level or "").strip().lower()
        if normalized == "critical":
            return [
                "Đặt lịch khám với chuyên khoa giấc ngủ trong tuần",
                "Tránh caffeine và thiết bị điện tử 2 tiếng trước khi ngủ",
                "Theo dõi sát các chỉ số sinh hiệu ban đêm",
            ]
        if normalized in {"medium", "moderate", "high", "warning"}:
            return [
                "Giữ giờ đi ngủ và thức dậy ổn định trong 7 ngày tới",
                "Đo lại chỉ số giấc ngủ sau 3 đêm",
            ]
        return [
            "Tiếp tục duy trì thói quen giấc ngủ tốt",
            "Theo dõi định kỳ chất lượng giấc ngủ",
        ]


__all__ = ["SleepRiskAdapter"]
