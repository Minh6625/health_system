"""Adapter for writing a fall prediction to the ``fall_events`` table.

Phase 4B-thin (see ``backend/docs/risk-contract-baseline.md`` §7e). The
plan deliberately keeps fall events out of the ``risk_scores`` /
``risk_explanations`` tables (different lifecycle: state machine
``detected -> confirmed/dismissed/escalated`` vs continuous trend) so
this lives next to :class:`RiskPersistenceAdapter` rather than reusing
it.

Inputs:

* ``db_device_id`` — primary key on ``devices``; resolved by the route
  before calling here.
* ``prediction`` — the first element of ``FallPredictionResponse.results``
  as returned by :meth:`ModelApiClient.predict_fall`. Already shaped
  by the model-api so we extract by key rather than constructing a
  typed intermediate.

Output: the persisted :class:`FallEvent` row, refreshed so the caller
has the auto-generated ``id`` and ``uuid``.
"""

from __future__ import annotations

import logging
from typing import Any

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.sos_event_model import FallEvent
from app.utils.datetime_helper import get_current_time

logger = logging.getLogger(__name__)


class FallPersistenceAdapter:
    """Boundary class for writing a fall prediction to the database."""

    @staticmethod
    def persist(
        db: Session,
        *,
        db_device_id: int,
        prediction: dict[str, Any],
    ) -> FallEvent:
        """Insert one ``fall_events`` row from a model-api prediction.

        On any DB failure the transaction is rolled back, the failure
        is logged with the device id, and an ``HTTPException 500`` is
        raised so the FastAPI route returns a clean response.
        """
        confidence = FallPersistenceAdapter._extract_probability(prediction)
        model_version = FallPersistenceAdapter._extract_model_version(prediction)
        features = FallPersistenceAdapter._extract_features(prediction)

        try:
            row = FallEvent(
                device_id=int(db_device_id),
                detected_at=get_current_time(),
                confidence=confidence,
                model_version=model_version,
                features=features,
            )
            db.add(row)
            db.commit()
            db.refresh(row)
        except Exception:
            db.rollback()
            logger.exception(
                "Failed to persist fall_event for device %s", db_device_id
            )
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Không thể lưu fall event",
            )

        return row

    # ------------------------------------------------------------------
    # Private extraction helpers — pure functions for unit testability
    # ------------------------------------------------------------------

    @staticmethod
    def _extract_probability(prediction: dict[str, Any]) -> float:
        """Pull the probability score out of the upstream prediction.

        Prefers ``predicted_fall_probability`` (top-level convenience
        on the model-api result), falls back to
        ``prediction.prediction_score`` (standard 6-layer location), then
        zero. Always clamped to [0, 1] so the column constraint
        ``NUMERIC(4, 3)`` never overflows.
        """
        raw = prediction.get("predicted_fall_probability")
        if raw is None:
            inner = prediction.get("prediction") or {}
            if isinstance(inner, dict):
                raw = inner.get("prediction_score")
        try:
            value = float(raw) if raw is not None else 0.0
        except (TypeError, ValueError):
            value = 0.0
        return max(0.0, min(1.0, value))

    @staticmethod
    def _extract_model_version(prediction: dict[str, Any]) -> str | None:
        """Pull ``meta.model_version`` truncated to the column width.

        ``fall_events.model_version`` is ``VARCHAR(20)``; we trim
        defensively so a longer label from a future model-api release
        cannot raise on insert.
        """
        meta = prediction.get("meta")
        if not isinstance(meta, dict):
            return None
        raw = meta.get("model_version")
        if raw is None:
            return None
        text = str(raw).strip()
        if not text:
            return None
        return text[:20]

    @staticmethod
    def _extract_features(prediction: dict[str, Any]) -> dict[str, Any]:
        """Snapshot the explainability + traceability bits onto the row.

        ``fall_events.features`` is a free-form ``JSONB`` so we land
        whatever the upstream sent, plus the request-id from
        ``meta.request_id`` (Phase 2 traceability) at the top level for
        easy log correlation without having to ``->>'meta'->>'request_id'``
        in SQL.
        """
        features: dict[str, Any] = {}
        for key in (
            "predicted_fall",
            "predicted_fall_label",
            "predicted_fall_probability",
            "predicted_activity",
            "activity_probability",
            "risk_level",
            "requires_attention",
            "high_priority_alert",
            "top_features",
            "shap",
            "explanation",
            "prediction",
        ):
            if key in prediction:
                features[key] = prediction[key]

        meta = prediction.get("meta")
        if isinstance(meta, dict):
            request_id = meta.get("request_id")
            if request_id is not None:
                # Promote to a top-level key for easier log correlation;
                # also keep the full meta block under "meta" so nothing is
                # lost.
                features["model_request_id"] = str(request_id).strip()[:36] or None
            features["meta"] = meta

        return features
