"""Phase 2 Health Connect: tests for the mobile vitals ingest path.

These tests cover ``MonitoringService.ingest_mobile_batch`` at the service
boundary using ``MagicMock`` Sessions so they don't need a live Postgres
or TimescaleDB. The DB-layer guards (PK ``(device_id, time)``,
``ON CONFLICT DO NOTHING``) live in
``PM_REVIEW/SQL SCRIPTS/canonical/05_timeseries_vitals_motion_sleep.sql``
and are validated separately in the e2e suite.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock, patch

import pytest

from app.models.device_model import Device
from app.schemas.monitoring import MobileVitalSample
from app.services.monitoring_service import MonitoringService


# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------


def _device(*, id_: int = 100, user_id: int | None = 10) -> MagicMock:
    """Build a mock Device that exposes only the fields the service
    inspects (id, user_id, deleted_at). Using MagicMock instead of
    constructing a real ORM instance keeps the test free of SQLAlchemy's
    instance-state requirements."""
    d = MagicMock(spec=Device)
    d.id = id_
    d.user_id = user_id
    d.deleted_at = None
    return d


def _sample(
    *,
    minutes_ago: int = 1,
    heart_rate: float | None = 78,
    spo2: float | None = 98.0,
) -> MobileVitalSample:
    return MobileVitalSample(
        timestamp=datetime.now(UTC) - timedelta(minutes=minutes_ago),
        heart_rate=heart_rate,
        spo2=spo2,
        source="health_connect",
    )


def _mock_db(device: MagicMock | None) -> MagicMock:
    """Stub a SQLAlchemy Session: query(Device).filter(...).first() returns
    [device], execute() returns a MagicMock with rowcount=1 to model a
    successful INSERT (ON CONFLICT path returns rowcount=0)."""
    db = MagicMock()
    db.query.return_value.filter.return_value.first.return_value = device
    insert_result = MagicMock()
    insert_result.rowcount = 1
    db.execute.return_value = insert_result
    return db


# ---------------------------------------------------------------------------
# Happy path
# ---------------------------------------------------------------------------


def test_ingest_mobile_batch_happy_path_inserts_and_triggers_risk() -> None:
    db = _mock_db(_device())
    samples = [_sample(minutes_ago=1), _sample(minutes_ago=2)]

    with patch(
        "app.services.risk_alert_service.calculate_device_risk"
    ) as risk_mock:
        result = MonitoringService.ingest_mobile_batch(
            patient_id=10, device_id=100, samples=samples, db=db,
        )

    assert result["accepted"] == 2
    assert result["rejected"] == 0
    assert result["risk_evaluated_devices"] == [100]
    risk_mock.assert_called_once_with(db, device_id=100, user_id=10)
    db.commit.assert_called_once()


# ---------------------------------------------------------------------------
# Ownership / 403 boundary
# ---------------------------------------------------------------------------


def test_ingest_mobile_batch_missing_device_raises_permission_error() -> None:
    db = _mock_db(None)
    with pytest.raises(PermissionError, match="khong ton tai"):
        MonitoringService.ingest_mobile_batch(
            patient_id=10, device_id=100, samples=[_sample()], db=db,
        )


def test_ingest_mobile_batch_foreign_device_raises_permission_error() -> None:
    db = _mock_db(_device(user_id=99))  # device belongs to user 99, not 10
    with pytest.raises(PermissionError, match="khong thuoc ve"):
        MonitoringService.ingest_mobile_batch(
            patient_id=10, device_id=100, samples=[_sample()], db=db,
        )


# ---------------------------------------------------------------------------
# Sample-level rejections
# ---------------------------------------------------------------------------


def test_ingest_mobile_batch_rejects_future_timestamp() -> None:
    db = _mock_db(_device())
    future = MobileVitalSample(
        timestamp=datetime.now(UTC) + timedelta(minutes=5),
        heart_rate=72,
    )
    result = MonitoringService.ingest_mobile_batch(
        patient_id=10, device_id=100, samples=[future], db=db,
    )
    assert result["accepted"] == 0
    assert result["rejected"] == 1
    assert result["rejections"][0]["reason"] == "timestamp_in_future"


def test_ingest_mobile_batch_rejects_old_timestamp() -> None:
    db = _mock_db(_device())
    old = MobileVitalSample(
        timestamp=datetime.now(UTC) - timedelta(hours=48),
        heart_rate=72,
    )
    result = MonitoringService.ingest_mobile_batch(
        patient_id=10, device_id=100, samples=[old], db=db,
    )
    assert result["rejected"] == 1
    assert result["rejections"][0]["reason"] == "timestamp_too_old"


def test_ingest_mobile_batch_rejects_no_clinical_signal() -> None:
    """ADR-018 part 4: HR + SpO2 both null -> reject at boundary."""
    db = _mock_db(_device())
    empty = MobileVitalSample(
        timestamp=datetime.now(UTC) - timedelta(minutes=1),
        heart_rate=None,
        spo2=None,
    )
    result = MonitoringService.ingest_mobile_batch(
        patient_id=10, device_id=100, samples=[empty], db=db,
    )
    assert result["rejected"] == 1
    assert result["rejections"][0]["reason"] == "no_clinical_signal"


# ---------------------------------------------------------------------------
# Risk pipeline failure must not break ingest
# ---------------------------------------------------------------------------


def test_ingest_mobile_batch_swallows_risk_pipeline_errors() -> None:
    db = _mock_db(_device())
    with patch(
        "app.services.risk_alert_service.calculate_device_risk",
        side_effect=RuntimeError("model down"),
    ):
        result = MonitoringService.ingest_mobile_batch(
            patient_id=10, device_id=100, samples=[_sample()], db=db,
        )
    # Insertion still succeeded; only risk eval was skipped.
    assert result["accepted"] == 1
    assert result["risk_evaluated_devices"] == []


# ---------------------------------------------------------------------------
# Risk pipeline NOT triggered when nothing was accepted
# ---------------------------------------------------------------------------


def test_ingest_mobile_batch_skips_risk_when_no_accept() -> None:
    db = _mock_db(_device())
    far_future = MobileVitalSample(
        timestamp=datetime.now(UTC) + timedelta(hours=1),
        heart_rate=72,
    )
    with patch(
        "app.services.risk_alert_service.calculate_device_risk"
    ) as risk_mock:
        result = MonitoringService.ingest_mobile_batch(
            patient_id=10, device_id=100, samples=[far_future], db=db,
        )
    assert result["accepted"] == 0
    risk_mock.assert_not_called()
