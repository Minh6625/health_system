"""Adapter for writing a :class:`NormalizedExplanation` to the database.

Responsibilities (Phase 3b — see plan section E.3):

* ``build_features_json`` — assemble the ``risk_scores.features`` JSON blob
  from a normalized explanation + the raw vitals row that produced it.
* ``persist`` — commit one ``risk_scores`` row + one ``risk_explanations``
  row (with all canonical and legacy columns populated) inside a single
  transaction. On failure rolls back and raises ``HTTPException 500`` so
  the FastAPI route layer renders a clean error.

This used to be ~60 inlined lines in
:func:`risk_alert_service.calculate_device_risk` mixed with the inference
branching. Splitting it out lets us:

* Unit-test the persistence shape (``features`` blob keys, varchar limits,
  legacy + canonical column population) without spinning up the full
  inference pipeline.
* Reuse the same persistence path for sleep / fall risk scores once those
  domains land (plan Phase 4A / 4B).
"""

from __future__ import annotations

import json
import logging
from decimal import Decimal
from typing import Any

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.adapters.normalized_explanation import NormalizedExplanation
from app.models.risk_explanation_model import RiskExplanation
from app.models.risk_score_model import RiskScore
from app.services.risk_inference_service import (
    derive_health_level,
    derive_health_score,
    derive_health_summary,
)
from app.utils.datetime_helper import get_current_time

logger = logging.getLogger(__name__)


class _DecimalEncoder(json.JSONEncoder):
    """JSON encoder that flattens ``Decimal`` (e.g. NUMERIC vitals) to ``float``.

    Kept private to this module so the encoder only escapes when the
    persistence adapter writes vitals coming straight off SQLAlchemy mappings.
    """

    def default(self, o: Any) -> Any:
        if isinstance(o, Decimal):
            return float(o)
        return super().default(o)


class RiskPersistenceAdapter:
    """Boundary class for writing a normalized risk inference to the database."""

    @staticmethod
    def build_features_json(
        *,
        inference: NormalizedExplanation,
        vitals_row: dict[str, Any],
        feature_snapshot: dict[str, Any],
        defaults_applied: list[str],
    ) -> dict[str, Any]:
        """Compose the ``risk_scores.features`` JSON blob.

        The blob is the source of truth ``MonitoringService._normalize_risk_row``
        reads when it later projects the row back to the mobile DTO, so its
        keys MUST stay aligned with ``NormalizedRiskRow``'s expectations.
        """
        features_json = {
            "model_features": feature_snapshot,
            "raw_vitals": {
                "heart_rate": vitals_row.get("heart_rate"),
                "spo2": vitals_row.get("spo2"),
                "temperature": vitals_row.get("temperature"),
                "respiratory_rate": vitals_row.get("respiratory_rate"),
                "blood_pressure_sys": vitals_row.get("blood_pressure_sys"),
                "blood_pressure_dia": vitals_row.get("blood_pressure_dia"),
                "hrv": vitals_row.get("hrv"),
            },
            "defaults_applied": defaults_applied,
            "backend": inference.backend_label,
            "label_id": inference.label_id,
            "label": inference.prediction_label,
            "risk_level": inference.risk_level,
            "risk_score": inference.risk_score,
            "health_score": derive_health_score(inference.risk_score),
            "health_level": derive_health_level(inference.risk_level),
            "health_summary": derive_health_summary(inference.risk_level),
            "confidence": inference.confidence_value,
            "fallback_reason": inference.fallback_reason,
            "artifact_path": inference.artifact_path,
        }
        # Round-trip through json.dumps with the Decimal-aware encoder so any
        # Decimal vitals get flattened to float before SQLAlchemy persists.
        return json.loads(json.dumps(features_json, cls=_DecimalEncoder))

    @staticmethod
    def persist(
        db: Session,
        *,
        user_id: int,
        device_id: int,
        inference: NormalizedExplanation,
        vitals_row: dict[str, Any],
        feature_snapshot: dict[str, Any],
        defaults_applied: list[str],
        risk_type: str = "general",
    ) -> RiskScore:
        """Persist one ``risk_scores`` row + one ``risk_explanations`` row.

        Both writes happen in the same transaction. On any error the
        transaction is rolled back, the failure is logged with the
        ``device_id``, and an ``HTTPException 500`` is raised so the FastAPI
        route returns a clean response.
        """
        features_json = RiskPersistenceAdapter.build_features_json(
            inference=inference,
            vitals_row=vitals_row,
            feature_snapshot=feature_snapshot,
            defaults_applied=defaults_applied,
        )

        try:
            risk_score_row = RiskScore(
                user_id=int(user_id),
                device_id=int(device_id),
                calculated_at=get_current_time(),
                risk_type=risk_type,
                score=round(float(inference.risk_score), 2),
                risk_level=inference.risk_level,
                features=features_json,
                model_version=inference.model_version_label,
                algorithm=inference.backend_label,
            )
            db.add(risk_score_row)
            db.flush()

            risk_explanation = RiskExplanation(
                risk_score_id=risk_score_row.id,
                explanation_text=inference.explanation_text,
                feature_importance=inference.feature_importance,
                xai_method=inference.xai_method,
                recommendations=inference.recommendations,
                top_features_json=inference.top_features or None,
                ai_explanation_json=inference.ai_explanation_payload,
                shap_details_json=(
                    inference.shap_details
                    if isinstance(inference.shap_details, dict)
                    else None
                ),
                # Phase 2 traceability — NULL on the rule_based / ONNX
                # fallback path (NormalizedExplanation defaults the field
                # to None there).
                model_request_id=inference.model_request_id,
            )
            db.add(risk_explanation)
            db.commit()
            db.refresh(risk_score_row)
        except Exception:
            db.rollback()
            logger.exception("Failed to persist risk score for device %s", device_id)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Không thể lưu risk score",
            )

        return risk_score_row
