"""S5 — Telemetry ingest strict schema + structured errors + idempotency.

Phase 7 slice 5 promotes ``POST /api/v1/mobile/telemetry/ingest`` to the
ADR-018 part-4 contract:

* ``VitalIngestVitals`` is ``extra="forbid"`` and every clinical field
  carries a ``Field(ge=..., le=...)`` constraint. Out-of-range values
  short-circuit at the Pydantic boundary with HTTP 422.
* ``VitalIngestItem`` rejects records where BOTH ``heart_rate`` and
  ``spo2`` are NULL with a per-item error code
  ``INSUFFICIENT_VITALS`` (HS-024 root-cause fix at the boundary, not
  inside the inference layer).
* ``IngestResponse`` adds ``rejected`` + ``risk_evaluated_devices`` and
  switches ``errors`` from raw ``list[str]`` to a structured
  ``list[IngestError]`` so producers can retry per-item.
* ``Idempotency-Key`` HTTP header de-dupes batch replays within a
  5-minute window (in-memory TTL cache for the dev/single-replica
  topology — out of scope to upgrade to Redis here).

Tests live close to the route at the schema + handler level so they
exercise both Pydantic and the per-item business rules without standing
up a live Postgres. ``ingest_vitals`` is called directly with a
``MagicMock`` SQLAlchemy session following the same pattern as
``test_telemetry_risk_pipeline``.
"""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any
from unittest.mock import MagicMock, Mock, patch

import pytest
from pydantic import ValidationError

from app.api.routes.telemetry import (
    IngestError,
    VitalIngestItem,
    VitalIngestRequest,
    VitalIngestResponse,
    VitalIngestVitals,
    ingest_vitals,
)


# ---------------------------------------------------------------------------
# Helpers — db mock + payload factory
# ---------------------------------------------------------------------------


def _build_db_mock(rowcount: int = 1) -> MagicMock:
    """Mirror the helper from test_telemetry_risk_pipeline so the new tests
    behave the same way against the SQLAlchemy ORM session.
    """
    db = MagicMock()
    db.begin_nested.return_value.__enter__.return_value = None
    db.begin_nested.return_value.__exit__.return_value = None

    insert_result = Mock()
    insert_result.rowcount = rowcount
    update_result = Mock()
    update_result.rowcount = rowcount

    # First execute = INSERT INTO vitals. Second = UPDATE devices.last_sync_at.
    db.execute.side_effect = [insert_result, update_result]
    return db


def _valid_vitals(**overrides: Any) -> dict[str, Any]:
    base: dict[str, Any] = {
        "heart_rate": 72.0,
        "spo2": 98.0,
        "temperature": 36.6,
        "hrv": 45.0,
        "respiratory_rate": 16.0,
        "blood_pressure_sys": 118.0,
        "blood_pressure_dia": 76.0,
        "signal_quality": 0.92,
        "motion_artifact": False,
    }
    base.update(overrides)
    return base


def _payload(vitals: dict[str, Any], **overrides: Any) -> VitalIngestRequest:
    base_item: dict[str, Any] = {
        "db_device_id": 42,
        "emitted_at": datetime(2026, 5, 15, 22, 30, tzinfo=UTC),
        "vitals": VitalIngestVitals(**vitals),
    }
    base_item.update(overrides)
    return VitalIngestRequest(messages=[VitalIngestItem(**base_item)])


# ---------------------------------------------------------------------------
# Pydantic strict schema (extra=forbid + range constraints)
# ---------------------------------------------------------------------------


class TestPydanticStrictSchema:
    def test_reject_unknown_vital_field_with_extra_forbid(self) -> None:
        with pytest.raises(ValidationError) as exc_info:
            VitalIngestVitals(heart_rate=72, spo2=98, unknown_field=1.0)  # type: ignore[call-arg]
        errors = exc_info.value.errors()
        assert any(e["type"] == "extra_forbidden" for e in errors), (
            "Unknown vital fields must be rejected so producers cannot smuggle "
            "arbitrary clinical attributes past the schema boundary."
        )

    @pytest.mark.parametrize(
        "field,bad_value",
        [
            ("heart_rate", 19),  # below ge=20
            ("heart_rate", 251),  # above le=250
            ("spo2", 49),  # below ge=50
            ("spo2", 101),  # above le=100
            ("temperature", 29.9),  # below ge=30
            ("temperature", 45.1),  # above le=45
            ("hrv", -1),  # below ge=0
            ("hrv", 301),  # above le=300
            ("respiratory_rate", 4),  # below ge=5
            ("respiratory_rate", 61),  # above le=60
            ("blood_pressure_sys", 59),  # below ge=60
            ("blood_pressure_sys", 261),  # above le=260
            ("blood_pressure_dia", 29),  # below ge=30
            ("blood_pressure_dia", 181),  # above le=180
            ("signal_quality", -0.01),  # below ge=0
            ("signal_quality", 1.01),  # above le=1
        ],
    )
    def test_reject_out_of_range_value(self, field: str, bad_value: float) -> None:
        with pytest.raises(ValidationError):
            VitalIngestVitals(**{field: bad_value})

    @pytest.mark.parametrize(
        "field,boundary",
        [
            ("heart_rate", 20),
            ("heart_rate", 250),
            ("spo2", 50),
            ("spo2", 100),
            ("temperature", 30),
            ("temperature", 45),
            ("hrv", 0),
            ("hrv", 300),
            ("respiratory_rate", 5),
            ("respiratory_rate", 60),
            ("signal_quality", 0),
            ("signal_quality", 1),
        ],
    )
    def test_accept_inclusive_boundary_value(self, field: str, boundary: float) -> None:
        # Inclusive boundary — pin behaviour so a future ``gt=`` regression
        # is caught immediately.
        VitalIngestVitals(**{field: boundary})

    def test_accept_nulls_for_optional_fields(self) -> None:
        # All clinical fields stay nullable so a partial reading (e.g. cuff
        # not worn, no temperature sensor) still survives the schema —
        # only the per-item INSUFFICIENT_VITALS gate may reject the row.
        VitalIngestVitals(
            heart_rate=72,
            spo2=None,
            temperature=None,
            hrv=None,
            respiratory_rate=None,
            blood_pressure_sys=None,
            blood_pressure_dia=None,
            signal_quality=None,
            motion_artifact=None,
        )

    def test_reject_empty_messages_batch(self) -> None:
        with pytest.raises(ValidationError):
            VitalIngestRequest(messages=[])

    def test_reject_messages_batch_over_50(self) -> None:
        too_many = [
            VitalIngestItem(
                db_device_id=42,
                emitted_at=datetime(2026, 5, 15, 22, 30, tzinfo=UTC),
                vitals=VitalIngestVitals(heart_rate=72),
            )
            for _ in range(51)
        ]
        with pytest.raises(ValidationError):
            VitalIngestRequest(messages=too_many)


# ---------------------------------------------------------------------------
# Per-item INSUFFICIENT_VITALS (boundary fail-closed)
# ---------------------------------------------------------------------------


class TestInsufficientVitalsPerItem:
    def test_reject_when_both_hr_and_spo2_null(self) -> None:
        # HS-024 root-cause fix: the ingest boundary itself rejects records
        # where the two critical vitals are NULL so the downstream
        # ``calculate_device_risk`` path is never asked to score a
        # synthetic-only reading.
        db = _build_db_mock()
        payload = _payload({"heart_rate": None, "spo2": None, "temperature": 36.6})

        response = ingest_vitals(payload, db=db)

        assert response.ingested == 0
        assert response.rejected == 1
        assert len(response.errors) == 1
        err = response.errors[0]
        assert err.error_code == "INSUFFICIENT_VITALS"
        assert err.index == 0
        assert err.device_id == 42
        assert response.risk_evaluated_devices == []
        # DB INSERT must NOT have been attempted for the rejected item.
        # ``_build_db_mock`` only queued 2 results (INSERT + UPDATE) — if
        # the handler tried to insert anyway it would still consume one,
        # so we assert on the call list directly.
        assert all(
            "INSERT INTO vitals" not in str(call.args[0])
            for call in db.execute.call_args_list
        ), "Item with both HR + SpO2 NULL must skip the vitals INSERT"

    def test_accept_when_only_hr_present(self) -> None:
        db = _build_db_mock()
        payload = _payload({"heart_rate": 72, "spo2": None})

        with patch(
            "app.api.routes.telemetry._resolve_alert_user_id",
            return_value=77,
        ), patch(
            "app.api.routes.telemetry.calculate_device_risk",
        ) as calc:
            response = ingest_vitals(payload, db=db)

        assert response.ingested == 1
        assert response.rejected == 0
        assert response.errors == []
        calc.assert_called_once()

    def test_accept_when_only_spo2_present(self) -> None:
        db = _build_db_mock()
        payload = _payload({"heart_rate": None, "spo2": 98})

        with patch(
            "app.api.routes.telemetry._resolve_alert_user_id",
            return_value=77,
        ), patch(
            "app.api.routes.telemetry.calculate_device_risk",
        ) as calc:
            response = ingest_vitals(payload, db=db)

        assert response.ingested == 1
        assert response.rejected == 0
        assert response.errors == []
        calc.assert_called_once()


# ---------------------------------------------------------------------------
# Structured response — rejected count + risk_evaluated_devices
# ---------------------------------------------------------------------------


class TestStructuredResponseShape:
    def test_response_fields_match_adr018_contract(self) -> None:
        db = _build_db_mock()
        payload = _payload(_valid_vitals())

        with patch(
            "app.api.routes.telemetry._resolve_alert_user_id",
            return_value=77,
        ), patch(
            "app.api.routes.telemetry.calculate_device_risk",
        ):
            response = ingest_vitals(payload, db=db)

        # The contract (PM_REVIEW/REDESIGN_IOT_SIM_2026/03_data_contracts/
        # vitals_ingest.md §2.1) pins these four fields. Failing this
        # assertion means producers will not know which devices were
        # evaluated, breaking the auto-trigger UX described in OQ5.
        assert isinstance(response, VitalIngestResponse)
        assert response.ingested == 1
        assert response.rejected == 0
        assert response.errors == []
        assert response.risk_evaluated_devices == [42]

    def test_per_item_error_carries_index_device_emitted_at_code_message(self) -> None:
        db = _build_db_mock()
        payload = _payload({"heart_rate": None, "spo2": None})

        response = ingest_vitals(payload, db=db)

        err = response.errors[0]
        assert err.index == 0
        assert err.device_id == 42
        assert err.emitted_at == datetime(2026, 5, 15, 22, 30, tzinfo=UTC)
        assert err.error_code == "INSUFFICIENT_VITALS"
        # Message must surface the actionable hint so the producer can
        # retry with at least one of the critical fields populated.
        assert "heart_rate" in err.message or "spo2" in err.message

    def test_partial_batch_reports_mixed_results(self) -> None:
        db = _build_db_mock()
        # First message valid, second message both critical fields NULL.
        good_item = VitalIngestItem(
            db_device_id=42,
            emitted_at=datetime(2026, 5, 15, 22, 30, tzinfo=UTC),
            vitals=VitalIngestVitals(heart_rate=72, spo2=98),
        )
        bad_item = VitalIngestItem(
            db_device_id=43,
            emitted_at=datetime(2026, 5, 15, 22, 30, 5, tzinfo=UTC),
            vitals=VitalIngestVitals(heart_rate=None, spo2=None),
        )
        payload = VitalIngestRequest(messages=[good_item, bad_item])

        with patch(
            "app.api.routes.telemetry._resolve_alert_user_id",
            return_value=77,
        ), patch(
            "app.api.routes.telemetry.calculate_device_risk",
        ):
            response = ingest_vitals(payload, db=db)

        assert response.ingested == 1
        assert response.rejected == 1
        assert len(response.errors) == 1
        assert response.errors[0].index == 1
        assert response.errors[0].device_id == 43
        assert response.risk_evaluated_devices == [42]


# ---------------------------------------------------------------------------
# Idempotency-Key dedup (in-memory TTL cache)
# ---------------------------------------------------------------------------


class TestIdempotencyKeyDedup:
    def test_replay_within_window_returns_cached_response(self) -> None:
        # Fresh import to reset module-level cache between parametrizations.
        from app.api.routes import telemetry as telemetry_module

        telemetry_module._idempotency_clear_for_tests()  # type: ignore[attr-defined]

        db1 = _build_db_mock()
        payload = _payload(_valid_vitals())

        with patch(
            "app.api.routes.telemetry._resolve_alert_user_id",
            return_value=77,
        ), patch(
            "app.api.routes.telemetry.calculate_device_risk",
        ):
            first = ingest_vitals(payload, db=db1, idempotency_key="key-A")

        # Replay — should NOT touch the DB at all.
        db2 = MagicMock()
        with patch(
            "app.api.routes.telemetry._resolve_alert_user_id",
        ) as resolve, patch(
            "app.api.routes.telemetry.calculate_device_risk",
        ) as calc:
            second = ingest_vitals(payload, db=db2, idempotency_key="key-A")

        assert second == first, (
            "Idempotency replay must return the exact same response "
            "object the first call produced — otherwise a flaky network "
            "retry will double-count ``ingested`` for the producer."
        )
        db2.execute.assert_not_called()
        resolve.assert_not_called()
        calc.assert_not_called()

    def test_different_keys_processed_independently(self) -> None:
        from app.api.routes import telemetry as telemetry_module

        telemetry_module._idempotency_clear_for_tests()  # type: ignore[attr-defined]

        payload = _payload(_valid_vitals())

        db1 = _build_db_mock()
        with patch(
            "app.api.routes.telemetry._resolve_alert_user_id",
            return_value=77,
        ), patch(
            "app.api.routes.telemetry.calculate_device_risk",
        ):
            ingest_vitals(payload, db=db1, idempotency_key="key-A")

        db2 = _build_db_mock()
        with patch(
            "app.api.routes.telemetry._resolve_alert_user_id",
            return_value=77,
        ), patch(
            "app.api.routes.telemetry.calculate_device_risk",
        ) as calc:
            ingest_vitals(payload, db=db2, idempotency_key="key-B")

        # Distinct keys MUST each trigger a real DB write — failure here
        # would mean a single replay collision blocks legit new batches.
        db2.execute.assert_called()
        calc.assert_called_once()

    def test_no_key_treated_as_unique_request(self) -> None:
        from app.api.routes import telemetry as telemetry_module

        telemetry_module._idempotency_clear_for_tests()  # type: ignore[attr-defined]

        payload = _payload(_valid_vitals())

        db1 = _build_db_mock()
        with patch(
            "app.api.routes.telemetry._resolve_alert_user_id",
            return_value=77,
        ), patch(
            "app.api.routes.telemetry.calculate_device_risk",
        ):
            ingest_vitals(payload, db=db1, idempotency_key=None)

        db2 = _build_db_mock()
        with patch(
            "app.api.routes.telemetry._resolve_alert_user_id",
            return_value=77,
        ), patch(
            "app.api.routes.telemetry.calculate_device_risk",
        ) as calc:
            ingest_vitals(payload, db=db2, idempotency_key=None)

        # Two ``idempotency_key=None`` calls must NOT collide — otherwise
        # producers that just omit the header lose later batches.
        db2.execute.assert_called()
        calc.assert_called_once()
