"""Unit tests for ``FallPersistenceAdapter``.

The adapter has one orchestration method (``persist``) plus three
private extraction helpers. The helpers are pure and tested directly;
``persist`` is exercised through a ``MagicMock`` session that captures
the kwargs the adapter handed to ``FallEvent``.
"""

from __future__ import annotations

from typing import Any
from unittest.mock import MagicMock

import pytest

from app.adapters.fall_persistence_adapter import FallPersistenceAdapter


# ---------------------------------------------------------------------------
# Shared fixtures
# ---------------------------------------------------------------------------


def _model_api_prediction(**overrides: Any) -> dict[str, Any]:
    """Minimal but realistic ``FallPredictionResult.model_dump()`` shape."""
    base: dict[str, Any] = {
        "device_id": "42",
        "sample_count": 50,
        "predicted_fall_probability": 0.87,
        "predicted_fall": True,
        "predicted_fall_label": "fall",
        "risk_level": "critical",
        "requires_attention": True,
        "high_priority_alert": True,
        "predicted_activity": "fall_forward",
        "activity_probability": 0.93,
        "status": "ok",
        "meta": {
            "model_version": "fall_v0.3.1",
            "request_id": "fa11-9b3d-2a9c-4d27-9e1a-1234abcd",
        },
        "input_ref": {"index": 0},
        "prediction": {
            "prediction_label": "fall",
            "prediction_score": 0.87,
            "prediction_band": "critical_fall",
        },
        "top_features": [
            {"feature": "accel_peak", "value": 4.2, "shap": 0.31},
        ],
        "shap": None,
        "explanation": None,
    }
    base.update(overrides)
    return base


# ---------------------------------------------------------------------------
# _extract_probability
# ---------------------------------------------------------------------------


class TestExtractProbability:
    def test_prefers_top_level_predicted_fall_probability(self) -> None:
        prediction = _model_api_prediction(predicted_fall_probability=0.91)
        assert FallPersistenceAdapter._extract_probability(prediction) == 0.91

    def test_falls_back_to_prediction_score(self) -> None:
        prediction = _model_api_prediction()
        prediction.pop("predicted_fall_probability")
        assert FallPersistenceAdapter._extract_probability(prediction) == 0.87

    def test_zero_when_neither_field_present(self) -> None:
        prediction = _model_api_prediction()
        prediction.pop("predicted_fall_probability")
        prediction["prediction"] = {}
        assert FallPersistenceAdapter._extract_probability(prediction) == 0.0

    def test_clamps_above_one_to_one(self) -> None:
        prediction = _model_api_prediction(predicted_fall_probability=1.5)
        assert FallPersistenceAdapter._extract_probability(prediction) == 1.0

    def test_clamps_below_zero_to_zero(self) -> None:
        prediction = _model_api_prediction(predicted_fall_probability=-0.2)
        assert FallPersistenceAdapter._extract_probability(prediction) == 0.0

    def test_handles_string_value_gracefully(self) -> None:
        prediction = _model_api_prediction(predicted_fall_probability="0.5")
        assert FallPersistenceAdapter._extract_probability(prediction) == 0.5

    def test_returns_zero_for_unparseable_value(self) -> None:
        # Defensive: an unparseable top-level value clamps to 0.0 rather
        # than chaining to the inner prediction.score fallback. The
        # fallback chain only kicks in when the field is genuinely
        # absent (None / missing). This matches "if you can't parse it,
        # don't guess at high-stakes fall data".
        prediction = _model_api_prediction(predicted_fall_probability="not-a-number")
        assert FallPersistenceAdapter._extract_probability(prediction) == 0.0


# ---------------------------------------------------------------------------
# _extract_model_version
# ---------------------------------------------------------------------------


class TestExtractModelVersion:
    def test_returns_meta_model_version(self) -> None:
        prediction = _model_api_prediction()
        assert FallPersistenceAdapter._extract_model_version(prediction) == "fall_v0.3.1"

    def test_truncates_to_column_width_20(self) -> None:
        long_version = "fall_model_lightgbm_v2_2026_04_27_with_smote_oversample"
        prediction = _model_api_prediction(meta={"model_version": long_version})
        out = FallPersistenceAdapter._extract_model_version(prediction)
        assert out is not None
        assert len(out) == 20
        assert out == long_version[:20]

    def test_returns_none_for_missing_meta(self) -> None:
        prediction = _model_api_prediction()
        prediction.pop("meta")
        assert FallPersistenceAdapter._extract_model_version(prediction) is None

    def test_returns_none_for_blank(self) -> None:
        for blank in ("", "   ", "\n"):
            prediction = _model_api_prediction(meta={"model_version": blank})
            assert FallPersistenceAdapter._extract_model_version(prediction) is None

    def test_returns_none_for_non_dict_meta(self) -> None:
        prediction = _model_api_prediction(meta="not-a-dict")
        assert FallPersistenceAdapter._extract_model_version(prediction) is None


# ---------------------------------------------------------------------------
# _extract_features
# ---------------------------------------------------------------------------


class TestExtractFeatures:
    def test_includes_top_level_explainability_keys(self) -> None:
        features = FallPersistenceAdapter._extract_features(_model_api_prediction())
        for key in (
            "predicted_fall",
            "predicted_fall_probability",
            "risk_level",
            "predicted_activity",
            "top_features",
            "prediction",
            "meta",
        ):
            assert key in features

    def test_promotes_request_id_to_top_level_for_correlation(self) -> None:
        features = FallPersistenceAdapter._extract_features(_model_api_prediction())
        assert (
            features["model_request_id"]
            == "fa11-9b3d-2a9c-4d27-9e1a-1234abcd"
        )
        # Original meta block is preserved so nothing is lost.
        assert features["meta"]["request_id"] == features["model_request_id"]

    def test_request_id_truncated_to_36_chars(self) -> None:
        long_id = "x" * 64
        features = FallPersistenceAdapter._extract_features(
            _model_api_prediction(meta={"request_id": long_id})
        )
        assert len(features["model_request_id"]) == 36

    def test_skips_missing_keys_silently(self) -> None:
        prediction = {"predicted_fall_probability": 0.5}
        features = FallPersistenceAdapter._extract_features(prediction)
        assert features == {"predicted_fall_probability": 0.5}


# ---------------------------------------------------------------------------
# persist — happy path + rollback path
# ---------------------------------------------------------------------------


@pytest.fixture
def captured_kwargs(monkeypatch: pytest.MonkeyPatch) -> dict[str, Any]:
    """Capture the kwargs the adapter passes to ``FallEvent``."""
    captured: dict[str, Any] = {}

    class _FallEventStub:
        def __init__(self, **kwargs: Any) -> None:
            captured.update(kwargs)
            self.id = 1234
            self.uuid = "stub-uuid"

    monkeypatch.setattr(
        "app.adapters.fall_persistence_adapter.FallEvent",
        _FallEventStub,
    )
    return captured


class TestPersistHappyPath:
    def test_writes_expected_kwargs(
        self, captured_kwargs: dict[str, Any]
    ) -> None:
        db = MagicMock()
        prediction = _model_api_prediction()

        row = FallPersistenceAdapter.persist(
            db,
            db_device_id=42,
            prediction=prediction,
        )

        assert captured_kwargs["device_id"] == 42
        assert captured_kwargs["confidence"] == pytest.approx(0.87)
        assert captured_kwargs["model_version"] == "fall_v0.3.1"
        assert captured_kwargs["features"]["predicted_fall"] is True
        assert (
            captured_kwargs["features"]["model_request_id"]
            == "fa11-9b3d-2a9c-4d27-9e1a-1234abcd"
        )
        # detected_at is stamped server-side, just check it landed.
        assert "detected_at" in captured_kwargs
        # Adapter committed and refreshed.
        db.add.assert_called_once()
        db.commit.assert_called_once()
        db.refresh.assert_called_once()
        assert row.id == 1234


class TestPersistFailureRollsBack:
    def test_db_error_rolls_back_and_raises_500(
        self, captured_kwargs: dict[str, Any]
    ) -> None:
        from fastapi import HTTPException

        db = MagicMock()
        db.commit.side_effect = RuntimeError("simulated DB failure")

        with pytest.raises(HTTPException) as exc:
            FallPersistenceAdapter.persist(
                db,
                db_device_id=42,
                prediction=_model_api_prediction(),
            )

        assert exc.value.status_code == 500
        db.rollback.assert_called_once()
