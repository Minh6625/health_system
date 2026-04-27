"""Typed representation of a normalized risk row.

Phase 3 (see ``backend/docs/risk-contract-baseline.md``) replaces the
``dict[str, Any]`` previously returned by
``MonitoringService._normalize_risk_row`` with this immutable dataclass so:

* The set of fields produced by the normaliser is **explicit and finite**;
  adding a field requires touching the dataclass, which forces a code review
  on every consumer.
* Builders (``app.services.risk_report_builder``) and helpers
  (``MonitoringService._compute_trend_7d`` etc.) get attribute access with
  full IDE / mypy support instead of stringly-typed dict lookups.
* The Phase 1 invariants the builders rely on (``risk_score``,
  ``health_score``, ``display_status`` etc. are always populated) are now
  guaranteed structurally rather than by convention.

The dataclass is intentionally **plain** — not a Pydantic model — because:

* It is purely an internal data carrier; it never crosses the API
  boundary, so we do not need Pydantic's serialisation / validation cost.
* ``frozen=True`` + ``slots=True`` give us the immutability guarantee plus
  a small memory win on the hot path of the risk-report endpoints.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Any


@dataclass(frozen=True, slots=True)
class NormalizedRiskRow:
    """Canonical view of one ``risk_scores`` row + its joined explanation.

    Field semantics match the Phase 1 / Phase 2 contract documented in
    ``backend/docs/risk-contract-baseline.md`` section 6:

    * ``risk_score`` is the canonical numeric score on the 0..100 scale.
    * ``risk_level`` is one of ``low`` | ``medium`` | ``high`` | ``critical``.
    * ``risk_summary`` is the detail-screen narrative; ``health_summary`` is
      the dashboard / list narrative. Don't drift these.
    * ``explanation_text`` may be ``None`` when the SHAP/AI pipeline did not
      persist a free-text rationale; consumers fall back to ``risk_summary``.
    """

    # --- identity / type ------------------------------------------------
    id: int
    risk_type: str

    # --- core risk metrics ---------------------------------------------
    risk_score: float
    health_score: float
    risk_level: str
    health_level: str | None
    display_status: str
    risk_summary: str
    health_summary: str
    timestamp: datetime
    confidence: float
    is_stale: bool

    # --- raw model inputs / SHAP outputs --------------------------------
    features: dict[str, Any] = field(default_factory=dict)
    feature_snapshot: dict[str, Any] = field(default_factory=dict)
    raw_vitals: dict[str, Any] = field(default_factory=dict)
    feature_importance: dict[str, Any] = field(default_factory=dict)
    top_features: list[dict[str, Any]] = field(default_factory=list)
    ai_explanation: dict[str, Any] = field(default_factory=dict)
    recommendations: list[str] = field(default_factory=list)

    # --- optional metadata read from joined ``risk_explanations`` ------
    explanation_text: str | None = None
    model_version: str | None = None
    algorithm: str | None = None
    #: Phase 5 — raw SHAP waterfall payload from ``risk_explanations.shap_details_json``.
    #: Surfaced ONLY on the clinician audience response; gated at the route
    #: layer because raw SHAP is clinical data per plan §F.1.
    shap_details: dict[str, Any] | None = None
    #: Phase 5 (read path) — upstream model-api ``meta.request_id`` already
    #: persisted by :class:`~app.adapters.risk_persistence_adapter.RiskPersistenceAdapter`
    #: in Phase 2. Phase 5 lights it up on the read path so the clinician
    #: response can carry it for end-to-end log correlation.
    model_request_id: str | None = None
