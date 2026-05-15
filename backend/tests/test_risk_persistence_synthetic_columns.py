"""S4 — RiskPersistenceAdapter writes the ADR-018 data-quality columns.

Phase 7 slice 4 promotes the data-quality contract from the
``risk_scores.features`` JSONB blob onto four real columns so the admin
dashboard, retraining pipelines, and UC-based audit reports can query
them without parsing JSON:

* ``is_synthetic_default BOOLEAN NOT NULL DEFAULT FALSE``
* ``defaults_applied JSONB`` (NULL when no soft fields were defaulted)
* ``effective_confidence DECIMAL(5,4)`` (NULL on rule-based fallback)
* ``data_quality_warning TEXT`` (NULL on clean records and fallback)

These tests pin :func:`RiskPersistenceAdapter.persist` against the new
columns. They use the same ``MagicMock`` SQLAlchemy session +
constructor-stub pattern as ``test_model_request_id_traceability`` so we
can assert on the kwargs the adapter passed to the ORM model rather than
spinning up a real Postgres.
"""

from __future__ import annotations

from typing import Any
from unittest.mock import MagicMock

import pytest

from app.adapters.normalized_explanation import NormalizedExplanation
from app.adapters.risk_persistence_adapter import RiskPersistenceAdapter


# ---------------------------------------------------------------------------
# Fixtures — capture both RiskScore + RiskExplanation kwargs
# ---------------------------------------------------------------------------


@pytest.fixture
def captured_kwargs(monkeypatch: pytest.MonkeyPatch) -> dict[str, dict[str, Any]]:
    """Capture kwargs handed to both ``RiskScore`` and ``RiskExplanation``.

    Returns a dict with two keys: ``"risk_score"`` and ``"risk_explanation"``
    so individual tests can assert on whichever side they care about.
    """
    captured: dict[str, dict[str, Any]] = {"risk_score": {}, "risk_explanation": {}}

    class _RiskScoreStub:
        def __init__(self, **kwargs: Any) -> None:
            captured["risk_score"].update(kwargs)
            self.id = 999
            self.calculated_at = None

    class _RiskExplanationStub:
        def __init__(self, **kwargs: Any) -> None:
            captured["risk_explanation"].update(kwargs)

    monkeypatch.setattr(
        "app.adapters.risk_persistence_adapter.RiskScore",
        _RiskScoreStub,
    )
    monkeypatch.setattr(
        "app.adapters.risk_persistence_adapter.RiskExplanation",
        _RiskExplanationStub,
    )
    return captured


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _normalized(
    *,
    is_synthetic_default: bool = False,
    effective_confidence: float | None = None,
    data_quality_warning: str | None = None,
) -> NormalizedExplanation:
    return NormalizedExplanation(
        risk_level="medium",
        risk_score=58.0,
        confidence_value=0.82,
        prediction_label="warning",
        label_id=None,
        backend_label="model_api_health",
        model_version_label="model_api_v1",
        explanation_text="x",
        recommendations=[],
        feature_importance={},
        top_features=[],
        ai_explanation_payload={},
        shap_details=None,
        xai_method="shap",
        artifact_path=None,
        fallback_reason=None,
        model_request_id=None,
        is_synthetic_default=is_synthetic_default,
        effective_confidence=effective_confidence,
        data_quality_warning=data_quality_warning,
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
# is_synthetic_default column
# ---------------------------------------------------------------------------


class TestPersistsIsSyntheticDefault:
    def test_writes_true_when_inference_flag_is_true(
        self, captured_kwargs: dict[str, dict[str, Any]]
    ) -> None:
        RiskPersistenceAdapter.persist(
            MagicMock(),
            user_id=42,
            device_id=7,
            inference=_normalized(is_synthetic_default=True),
            vitals_row=_vitals_row(),
            feature_snapshot=_feature_snapshot(),
            defaults_applied=["hrv"],
        )
        assert captured_kwargs["risk_score"]["is_synthetic_default"] is True

    def test_writes_false_when_inference_flag_false_and_no_defaults(
        self, captured_kwargs: dict[str, dict[str, Any]]
    ) -> None:
        RiskPersistenceAdapter.persist(
            MagicMock(),
            user_id=42,
            device_id=7,
            inference=_normalized(is_synthetic_default=False),
            vitals_row=_vitals_row(),
            feature_snapshot=_feature_snapshot(),
            defaults_applied=[],
        )
        assert captured_kwargs["risk_score"]["is_synthetic_default"] is False

    def test_defensive_or_with_defaults_applied_when_inference_flag_omitted(
        self, captured_kwargs: dict[str, dict[str, Any]]
    ) -> None:
        # Local rule-based fallback path may not set the inference flag
        # but still report ``defaults_applied`` from the payload builder.
        # The persistence layer must recognise that combination as
        # synthetic so the column reflects reality.
        RiskPersistenceAdapter.persist(
            MagicMock(),
            user_id=42,
            device_id=7,
            inference=_normalized(is_synthetic_default=False),
            vitals_row=_vitals_row(),
            feature_snapshot=_feature_snapshot(),
            defaults_applied=["hrv", "weight_kg"],
        )
        assert captured_kwargs["risk_score"]["is_synthetic_default"] is True


# ---------------------------------------------------------------------------
# defaults_applied column (JSONB)
# ---------------------------------------------------------------------------


class TestPersistsDefaultsAppliedColumn:
    def test_writes_list_as_jsonb_when_non_empty(
        self, captured_kwargs: dict[str, dict[str, Any]]
    ) -> None:
        RiskPersistenceAdapter.persist(
            MagicMock(),
            user_id=42,
            device_id=7,
            inference=_normalized(is_synthetic_default=True),
            vitals_row=_vitals_row(),
            feature_snapshot=_feature_snapshot(),
            defaults_applied=["hrv", "weight_kg", "height_cm"],
        )
        assert captured_kwargs["risk_score"]["defaults_applied"] == [
            "hrv",
            "weight_kg",
            "height_cm",
        ]

    def test_writes_null_when_empty_list(
        self, captured_kwargs: dict[str, dict[str, Any]]
    ) -> None:
        # SQL NULL is cleaner than ``[]`` for the "no defaults" case so
        # admin queries can use ``WHERE defaults_applied IS NOT NULL``
        # to find synthetic records.
        RiskPersistenceAdapter.persist(
            MagicMock(),
            user_id=42,
            device_id=7,
            inference=_normalized(is_synthetic_default=False),
            vitals_row=_vitals_row(),
            feature_snapshot=_feature_snapshot(),
            defaults_applied=[],
        )
        assert captured_kwargs["risk_score"]["defaults_applied"] is None


# ---------------------------------------------------------------------------
# effective_confidence column
# ---------------------------------------------------------------------------


class TestPersistsEffectiveConfidence:
    def test_passes_through_value_when_present(
        self, captured_kwargs: dict[str, dict[str, Any]]
    ) -> None:
        RiskPersistenceAdapter.persist(
            MagicMock(),
            user_id=42,
            device_id=7,
            inference=_normalized(
                is_synthetic_default=True,
                effective_confidence=0.41,
            ),
            vitals_row=_vitals_row(),
            feature_snapshot=_feature_snapshot(),
            defaults_applied=["hrv"],
        )
        assert captured_kwargs["risk_score"]["effective_confidence"] == pytest.approx(
            0.41
        )

    def test_writes_none_when_inference_omits(
        self, captured_kwargs: dict[str, dict[str, Any]]
    ) -> None:
        # Rule-based fallback path does not produce an effective_confidence;
        # the column must accept NULL so we can later distinguish those
        # records from real model-api outputs.
        RiskPersistenceAdapter.persist(
            MagicMock(),
            user_id=42,
            device_id=7,
            inference=_normalized(
                is_synthetic_default=False,
                effective_confidence=None,
            ),
            vitals_row=_vitals_row(),
            feature_snapshot=_feature_snapshot(),
            defaults_applied=[],
        )
        assert captured_kwargs["risk_score"]["effective_confidence"] is None


# ---------------------------------------------------------------------------
# data_quality_warning column
# ---------------------------------------------------------------------------


class TestPersistsDataQualityWarning:
    def test_passes_through_string_when_present(
        self, captured_kwargs: dict[str, dict[str, Any]]
    ) -> None:
        warning = "Một số chỉ số (hrv) được ước tính."
        RiskPersistenceAdapter.persist(
            MagicMock(),
            user_id=42,
            device_id=7,
            inference=_normalized(
                is_synthetic_default=True,
                data_quality_warning=warning,
            ),
            vitals_row=_vitals_row(),
            feature_snapshot=_feature_snapshot(),
            defaults_applied=["hrv"],
        )
        assert captured_kwargs["risk_score"]["data_quality_warning"] == warning

    def test_writes_none_when_inference_omits(
        self, captured_kwargs: dict[str, dict[str, Any]]
    ) -> None:
        RiskPersistenceAdapter.persist(
            MagicMock(),
            user_id=42,
            device_id=7,
            inference=_normalized(
                is_synthetic_default=False,
                data_quality_warning=None,
            ),
            vitals_row=_vitals_row(),
            feature_snapshot=_feature_snapshot(),
            defaults_applied=[],
        )
        assert captured_kwargs["risk_score"]["data_quality_warning"] is None


# ---------------------------------------------------------------------------
# Backwards-compatibility — features JSONB blob still carries the same shape
# ---------------------------------------------------------------------------


class TestFeaturesJsonStillCarriesDefaultsApplied:
    def test_features_blob_still_writes_defaults_applied_for_back_compat(
        self,
    ) -> None:
        # ``MonitoringService._normalize_risk_row`` reads ``defaults_applied``
        # straight off the features JSONB to build the mobile DTO. S4 only
        # promotes the field to a column — the JSON path must still work
        # so already-persisted rows continue to render.
        blob = RiskPersistenceAdapter.build_features_json(
            inference=_normalized(is_synthetic_default=True),
            vitals_row=_vitals_row(),
            feature_snapshot=_feature_snapshot(),
            defaults_applied=["hrv", "weight_kg"],
        )
        assert blob["defaults_applied"] == ["hrv", "weight_kg"]
