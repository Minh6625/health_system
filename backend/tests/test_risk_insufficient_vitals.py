"""ADR-018 / HS-024: fail-closed risk inference when critical vitals NULL.

Service-level contract for ``_build_inference_payload``:
- Raises ``InsufficientVitalsError`` when ``heart_rate``, ``spo2``,
  ``respiratory_rate``, or ``temperature`` is NULL on the vitals row.
- Returns ``defaults_applied`` listing soft fields that were defaulted
  (blood_pressure_sys/dia, hrv, weight_kg, height_cm).

Adapter contract for ``ModelApiHealthAdapter.to_record``:
- Tracks defaults for height_cm, weight_kg, hrv when missing.
- HRV default aligned to 40.0 to match the service layer (was 50.0).
"""

from __future__ import annotations

from datetime import date

import pytest

from app.adapters.model_api_health_adapter import ModelApiHealthAdapter
from app.exceptions import InsufficientVitalsError
from app.services.risk_alert_service import _build_inference_payload


def _full_vitals_row() -> dict:
    return {
        "heart_rate": 80.0,
        "respiratory_rate": 16.0,
        "temperature": 36.8,
        "spo2": 98.0,
        "blood_pressure_sys": 120.0,
        "blood_pressure_dia": 80.0,
        "hrv": 35.0,
    }


def _full_context() -> dict:
    return {
        "date_of_birth": date(1960, 1, 1),
        "gender": "male",
        "weight_kg": 70.0,
        "height_cm": 170.0,
    }


class TestBuildInferencePayloadFailClosed:
    """ADR-018: critical NULL fields trigger InsufficientVitalsError."""

    @pytest.mark.parametrize(
        "missing_field",
        ["heart_rate", "spo2", "respiratory_rate", "temperature"],
    )
    def test_raises_when_critical_field_is_null(self, missing_field: str) -> None:
        row = {**_full_vitals_row(), missing_field: None}
        with pytest.raises(InsufficientVitalsError) as exc_info:
            _build_inference_payload(row, _full_context())
        assert missing_field in exc_info.value.missing_fields

    def test_raises_when_multiple_critical_fields_null(self) -> None:
        row = {**_full_vitals_row(), "heart_rate": None, "spo2": None}
        with pytest.raises(InsufficientVitalsError) as exc_info:
            _build_inference_payload(row, _full_context())
        assert set(exc_info.value.missing_fields) == {"heart_rate", "spo2"}

    def test_does_not_raise_for_soft_field_null(self) -> None:
        row = {**_full_vitals_row(), "blood_pressure_sys": None, "hrv": None}
        payload, defaults = _build_inference_payload(row, _full_context())
        assert payload is not None
        assert "blood_pressure_sys" in defaults
        assert "hrv" in defaults


class TestBuildInferencePayloadDefaults:
    """ADR-018: soft fields default with tracking, critical fields pass through."""

    def test_full_vitals_no_defaults_applied(self) -> None:
        payload, defaults = _build_inference_payload(
            _full_vitals_row(), _full_context()
        )
        assert defaults == []
        assert payload["heart_rate"] == 80.0
        assert payload["spo2"] == 98.0

    def test_missing_blood_pressure_sys_tracked(self) -> None:
        row = {**_full_vitals_row(), "blood_pressure_sys": None}
        _, defaults = _build_inference_payload(row, _full_context())
        assert "blood_pressure_sys" in defaults

    def test_missing_blood_pressure_dia_tracked(self) -> None:
        row = {**_full_vitals_row(), "blood_pressure_dia": None}
        _, defaults = _build_inference_payload(row, _full_context())
        assert "blood_pressure_dia" in defaults

    def test_missing_hrv_tracked(self) -> None:
        row = {**_full_vitals_row(), "hrv": None}
        _, defaults = _build_inference_payload(row, _full_context())
        assert "hrv" in defaults

    def test_missing_weight_kg_tracked(self) -> None:
        ctx = {**_full_context(), "weight_kg": None}
        _, defaults = _build_inference_payload(_full_vitals_row(), ctx)
        assert "weight_kg" in defaults

    def test_missing_height_cm_tracked(self) -> None:
        ctx = {**_full_context(), "height_cm": None}
        _, defaults = _build_inference_payload(_full_vitals_row(), ctx)
        assert "height_cm" in defaults


class TestAdapterDefaultsTrack:
    """ADR-018: adapter tracks soft defaults too (was silently filling)."""

    def test_adapter_tracks_height_cm_default(self) -> None:
        record = ModelApiHealthAdapter.to_record(
            {
                "heart_rate": 80.0,
                "resp_rate": 16.0,
                "body_temp": 36.8,
                "spo2": 98.0,
                "sys_bp": 120.0,
                "dia_bp": 80.0,
                "weight_kg": 70.0,
                "hrv": 35.0,
                # height_cm missing
            }
        )
        assert "height_cm" in record["defaults_applied"]
        assert record["is_synthetic_default"] is True

    def test_adapter_tracks_weight_kg_default(self) -> None:
        record = ModelApiHealthAdapter.to_record(
            {
                "heart_rate": 80.0,
                "resp_rate": 16.0,
                "body_temp": 36.8,
                "spo2": 98.0,
                "sys_bp": 120.0,
                "dia_bp": 80.0,
                "height_cm": 170.0,
                "hrv": 35.0,
                # weight_kg missing
            }
        )
        assert "weight_kg" in record["defaults_applied"]

    def test_adapter_tracks_hrv_default(self) -> None:
        record = ModelApiHealthAdapter.to_record(
            {
                "heart_rate": 80.0,
                "resp_rate": 16.0,
                "body_temp": 36.8,
                "spo2": 98.0,
                "sys_bp": 120.0,
                "dia_bp": 80.0,
                "height_cm": 170.0,
                "weight_kg": 70.0,
                # hrv missing
            }
        )
        assert "hrv" in record["defaults_applied"]
        assert record["derived_hrv"] == 40.0  # aligned default

    def test_adapter_no_defaults_when_complete(self) -> None:
        record = ModelApiHealthAdapter.to_record(
            {
                "heart_rate": 80.0,
                "resp_rate": 16.0,
                "body_temp": 36.8,
                "spo2": 98.0,
                "sys_bp": 120.0,
                "dia_bp": 80.0,
                "height_cm": 170.0,
                "weight_kg": 70.0,
                "hrv": 35.0,
            }
        )
        assert record["defaults_applied"] == []
        assert record["is_synthetic_default"] is False
