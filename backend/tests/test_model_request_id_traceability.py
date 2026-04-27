"""Phase 2 (focused) tests — model-api ``meta.request_id`` traceability.

These tests pin the round-trip:

1. ``ModelApiHealthAdapter.from_response`` extracts ``meta.request_id``
   from the upstream payload onto :class:`NormalizedExplanation`.
2. ``RiskPersistenceAdapter.persist`` writes the field onto the
   ``risk_explanations`` row alongside the existing payload columns.
3. The local rule-based fallback path leaves ``model_request_id`` as
   ``None`` so the column is NULL on those rows (matches the partial
   index in the migration).

The persistence test uses the same in-memory ``MagicMock`` SQLAlchemy
session pattern as the existing builder + adapter tests; we assert on
the kwargs the adapter passed to ``RiskExplanation`` rather than on a
real DB write.
"""

from __future__ import annotations

from typing import Any
from unittest.mock import MagicMock

import pytest

from app.adapters.model_api_health_adapter import ModelApiHealthAdapter
from app.adapters.normalized_explanation import NormalizedExplanation
from app.adapters.risk_persistence_adapter import RiskPersistenceAdapter
from app.services.risk_inference_service import RiskInferenceResult


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------


def _model_api_response(*, meta: dict[str, Any] | None) -> dict[str, Any]:
    """Build a minimal but valid model-api success payload."""
    return {
        "status": "ok",
        "risk_level": "warning",
        "predicted_health_risk_probability": 0.62,
        "prediction": {
            "prediction_label": "warning",
            "prediction_score": 0.62,
            "prediction_band": "warning",
        },
        "top_features": [],
        "shap": {"available": False, "values": []},
        "explanation": {
            "short_text": "OK",
            "clinical_note": "",
            "recommended_actions": [],
        },
        "meta": meta if meta is not None else {},
    }


def _feature_snapshot() -> dict[str, Any]:
    return {
        "heart_rate": 95.0,
        "spo2": 96.0,
        "sys_bp": 122.0,
        "dia_bp": 80.0,
        "resp_rate": 18.0,
        "body_temp": 36.7,
        "hrv": 45.0,
    }


# ---------------------------------------------------------------------------
# from_response — upstream meta.request_id extraction
# ---------------------------------------------------------------------------


class TestFromResponseExtractsRequestId:
    def test_extracts_uuid_from_meta(self) -> None:
        request_id = "1f6f4a73-90e6-4e54-9e6f-0f7d6a9e4321"
        result = ModelApiHealthAdapter.from_response(
            _model_api_response(meta={"request_id": request_id, "model_version": "v1.2"}),
            defaults_applied=[],
            feature_snapshot=_feature_snapshot(),
        )
        assert result.model_request_id == request_id

    def test_returns_none_when_meta_omits_request_id(self) -> None:
        result = ModelApiHealthAdapter.from_response(
            _model_api_response(meta={"model_version": "v1.2"}),
            defaults_applied=[],
            feature_snapshot=_feature_snapshot(),
        )
        assert result.model_request_id is None

    def test_returns_none_when_meta_block_absent(self) -> None:
        # ``from_response`` must not raise on missing ``meta``.
        payload = _model_api_response(meta=None)
        # Drop the empty meta dict entirely so the code path that handles
        # a totally absent block is exercised.
        del payload["meta"]
        result = ModelApiHealthAdapter.from_response(
            payload,
            defaults_applied=[],
            feature_snapshot=_feature_snapshot(),
        )
        assert result.model_request_id is None

    def test_coerces_numeric_request_id_to_string(self) -> None:
        # Defensive: if the upstream ever sends a numeric request_id the
        # adapter must not raise on the ``str()`` cast in the persistence
        # layer.
        result = ModelApiHealthAdapter.from_response(
            _model_api_response(meta={"request_id": 1234567890}),
            defaults_applied=[],
            feature_snapshot=_feature_snapshot(),
        )
        assert result.model_request_id == "1234567890"

    def test_truncates_oversized_request_id_to_column_limit(self) -> None:
        # The DB column is varchar(36); a longer value should be truncated
        # at the adapter boundary so SQLAlchemy never raises.
        oversized = "x" * 64
        result = ModelApiHealthAdapter.from_response(
            _model_api_response(meta={"request_id": oversized}),
            defaults_applied=[],
            feature_snapshot=_feature_snapshot(),
        )
        assert result.model_request_id is not None
        assert len(result.model_request_id) == 36

    def test_blank_request_id_normalised_to_none(self) -> None:
        for blank in ("", "   ", "\t\n"):
            result = ModelApiHealthAdapter.from_response(
                _model_api_response(meta={"request_id": blank}),
                defaults_applied=[],
                feature_snapshot=_feature_snapshot(),
            )
            assert result.model_request_id is None, (
                f"blank request_id {blank!r} must normalise to None so "
                "the partial index stays empty for it"
            )


# ---------------------------------------------------------------------------
# from_local_inference — fallback path leaves the field None
# ---------------------------------------------------------------------------


class TestFromLocalInferenceLeavesRequestIdNone:
    def test_rule_based_fallback_yields_none(self) -> None:
        local = RiskInferenceResult(
            label_id=1,
            label="medium",
            score=55.0,
            confidence=0.7,
            backend="rule_based",
            feature_vector=(),
            fallback_reason=None,
        )
        result = ModelApiHealthAdapter.from_local_inference(
            local,
            defaults_applied=[],
            feature_snapshot=_feature_snapshot(),
        )
        assert result.model_request_id is None


# ---------------------------------------------------------------------------
# persist — passes model_request_id through to the RiskExplanation row
# ---------------------------------------------------------------------------


def _normalized(model_request_id: str | None) -> NormalizedExplanation:
    return NormalizedExplanation(
        risk_level="medium",
        risk_score=58.0,
        confidence_value=0.82,
        prediction_label="warning",
        label_id=None,
        backend_label="model_api_health" if model_request_id else "rule_based",
        model_version_label="model_api_v1",
        explanation_text="x",
        recommendations=[],
        feature_importance={},
        top_features=[],
        ai_explanation_payload={},
        shap_details=None,
        xai_method="shap" if model_request_id else "rule_based",
        artifact_path=None,
        fallback_reason=None,
        model_request_id=model_request_id,
    )


def _vitals_row() -> dict[str, Any]:
    return {
        "heart_rate": 95,
        "spo2": 96,
        "temperature": 36.7,
        "respiratory_rate": 18,
        "blood_pressure_sys": 122,
        "blood_pressure_dia": 80,
        "hrv": 45,
    }


@pytest.fixture
def captured_explanation_kwargs(monkeypatch: pytest.MonkeyPatch) -> dict[str, Any]:
    """Capture the kwargs ``RiskPersistenceAdapter.persist`` hands to ``RiskExplanation``."""
    captured: dict[str, Any] = {}

    class _RiskExplanationStub:
        def __init__(self, **kwargs: Any) -> None:
            captured.update(kwargs)

    monkeypatch.setattr(
        "app.adapters.risk_persistence_adapter.RiskExplanation",
        _RiskExplanationStub,
    )

    class _RiskScoreStub:
        def __init__(self, **_kwargs: Any) -> None:
            self.id = 999
            self.calculated_at = None

    monkeypatch.setattr(
        "app.adapters.risk_persistence_adapter.RiskScore",
        _RiskScoreStub,
    )
    return captured


class TestPersistWritesModelRequestId:
    def test_persists_upstream_request_id_when_available(
        self,
        captured_explanation_kwargs: dict[str, Any],
    ) -> None:
        db = MagicMock()
        request_id = "8b3d2a9c-7f4d-4d27-9e1a-1234abcd5678"

        RiskPersistenceAdapter.persist(
            db,
            user_id=42,
            device_id=7,
            inference=_normalized(request_id),
            vitals_row=_vitals_row(),
            feature_snapshot=_feature_snapshot(),
            defaults_applied=[],
        )

        assert captured_explanation_kwargs.get("model_request_id") == request_id

    def test_writes_none_for_rule_based_fallback(
        self,
        captured_explanation_kwargs: dict[str, Any],
    ) -> None:
        db = MagicMock()
        RiskPersistenceAdapter.persist(
            db,
            user_id=42,
            device_id=7,
            inference=_normalized(None),
            vitals_row=_vitals_row(),
            feature_snapshot=_feature_snapshot(),
            defaults_applied=[],
        )

        assert captured_explanation_kwargs.get("model_request_id") is None
