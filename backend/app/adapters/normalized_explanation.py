"""Shared result type produced by both inference paths.

Whether the risk score comes from the external model-api (preferred) or
from the local rule-based fallback (``infer_risk``), the persistence
layer needs the same typed result. ``NormalizedExplanation`` is that
result — an immutable, complete record of one inference.

This is intentionally separate from
:class:`~app.services.normalized_risk_row.NormalizedRiskRow`:

* ``NormalizedRiskRow`` is the *read* path — what
  :func:`MonitoringService._normalize_risk_row` returns when projecting a
  persisted row back to a mobile DTO.
* ``NormalizedExplanation`` is the *write* path — what an inference
  produces *before* persistence, so it can be turned into
  ``risk_scores`` + ``risk_explanations`` rows.

Keeping the two separate avoids a producer/consumer cycle in the data
model and lets each side evolve independently.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class NormalizedExplanation:
    """Complete output of one risk inference, ready to persist.

    Field semantics:

    * ``risk_level`` is canonical (``low|medium|critical``) — the model-api
      adapter maps the upstream label through ``_MODEL_API_RISK_LEVEL_MAP``
      before populating this field.
    * ``risk_score`` is the canonical numeric (0..100, high=worse) already
      passed through ``normalize_risk_score``.
    * ``backend_label`` distinguishes the inference source:
      ``"model_api_health"`` vs the local backends (``"rule_based"``,
      ``"onnx"``, ``"lightgbm"``, ...).
    * ``feature_importance`` is the legacy flat dict; ``top_features`` is
      the canonical list. Both are populated for back-compat; the
      persistence adapter writes both columns.
    * ``ai_explanation_payload`` is the dict that lands in
      ``risk_explanations.ai_explanation_json``.
    * ``shap_details`` is ``None`` for the rule-based path; populated
      (with feature names already aliased to backend canonical names) for
      the model-api path.
    """

    # --- core risk metrics --------------------------------------------
    risk_level: str
    risk_score: float
    confidence_value: float
    prediction_label: str
    label_id: int | None
    backend_label: str
    model_version_label: str

    # --- explanation payloads -----------------------------------------
    explanation_text: str
    recommendations: list[str]
    feature_importance: dict[str, float] = field(default_factory=dict)
    top_features: list[dict[str, Any]] = field(default_factory=list)
    ai_explanation_payload: dict[str, Any] = field(default_factory=dict)
    shap_details: dict[str, Any] | None = None

    # --- traceability metadata ----------------------------------------
    xai_method: str = "rule_based"
    artifact_path: str | None = None
    fallback_reason: str | None = None
