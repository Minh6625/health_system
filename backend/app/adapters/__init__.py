"""Adapter layer (Phase 3b).

Adapters formalise the boundaries between layers that were previously
glued together in :mod:`app.services.risk_alert_service`:

* ``ModelApiHealthAdapter`` — translates between the
  ``risk_inference_service`` payload, the model-api request shape, and a
  uniform :class:`NormalizedExplanation` regardless of whether the
  inference came from model-api or the local rule-based fallback.
* ``RiskPersistenceAdapter`` — turns a :class:`NormalizedExplanation`
  + raw vitals into the ``risk_scores`` + ``risk_explanations`` rows.

The third adapter the plan calls ``MobileRiskDtoAdapter`` already exists
as :mod:`app.services.risk_report_builder`; it consumes the typed
:class:`~app.services.normalized_risk_row.NormalizedRiskRow` produced
when the persisted rows are fetched back through ``MonitoringService``.
"""

from app.adapters.model_api_health_adapter import ModelApiHealthAdapter
from app.adapters.normalized_explanation import NormalizedExplanation
from app.adapters.risk_persistence_adapter import RiskPersistenceAdapter

__all__ = [
    "ModelApiHealthAdapter",
    "NormalizedExplanation",
    "RiskPersistenceAdapter",
]
