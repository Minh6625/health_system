"""Regression tests for DeviceService Phase 4 fixes.

Bugs:
- HS-001 (Critical) - Device.user_id nullable + ON DELETE SET NULL per ADR-010.
- HS-002 (High)     - Cross-user MAC duplicate -> 409 Conflict per BR-040-01.
- HS-003 (Medium)   - DeviceSettingsRequest dropped 3 calibration offsets per ADR-012.

These are unit tests at service / schema boundary using MagicMock. They do
not require a live Postgres connection. The DB-layer guards (partial UNIQUE
indexes) live in PM_REVIEW migration 20260514_device_mac_global_unique.sql.
"""

from __future__ import annotations

from unittest.mock import MagicMock

import pytest

from app.models.device_model import Device
from app.schemas.device import DeviceSettingsRequest
from app.services.device_service import DeviceService


# ---------------------------------------------------------------------------
# HS-001 - ORM nullable user_id (ADR-010)
# ---------------------------------------------------------------------------


def test_hs001_device_user_id_is_nullable_optional() -> None:
    """Mapped[Optional[int]] + nullable=True so admin provisioning passes."""
    user_id_col = Device.__table__.c.user_id
    assert user_id_col.nullable is True, "Device.user_id must be nullable per ADR-010"


def test_hs001_device_user_id_fk_uses_set_null() -> None:
    """ON DELETE SET NULL preserves device + telemetry when user is removed."""
    user_id_col = Device.__table__.c.user_id
    fk = next(iter(user_id_col.foreign_keys))
    assert fk.ondelete == "SET NULL", "Device.user_id FK must use ON DELETE SET NULL per ADR-010"


# ---------------------------------------------------------------------------
# HS-002 - Cross-user duplicate MAC (BR-040-01)
# ---------------------------------------------------------------------------


def _patch_db_first(existing_user_id: int | None) -> MagicMock:
    """Build a SQLAlchemy Session mock that returns a single row from the
    duplicate-identity SELECT. ``existing_user_id=None`` simulates "no
    existing device with this MAC"."""
    db = MagicMock()
    if existing_user_id is None:
        db.execute.return_value.mappings.return_value.first.return_value = None
    else:
        db.execute.return_value.mappings.return_value.first.return_value = {
            "id": 999,
            "user_id": existing_user_id,
        }
    return db


def test_hs002_check_duplicate_identity_no_match_passes() -> None:
    """No existing device -> _check_duplicate_identity returns silently."""
    db = _patch_db_first(existing_user_id=None)

    DeviceService._check_duplicate_identity(
        user_id=10,
        serial_number=None,
        mac_address="AA:BB:CC:11:22:33",
        mqtt_client_id=None,
        db=db,
    )


def test_hs002_check_duplicate_identity_same_user_raises_generic() -> None:
    """Same user re-pairs same MAC -> generic duplicate message."""
    db = _patch_db_first(existing_user_id=10)

    with pytest.raises(ValueError) as excinfo:
        DeviceService._check_duplicate_identity(
            user_id=10,
            serial_number=None,
            mac_address="AA:BB:CC:11:22:33",
            mqtt_client_id=None,
            db=db,
        )
    assert "trung serial/mac/mqtt" in str(excinfo.value)
    assert "tai khoan khac" not in str(excinfo.value)


def test_hs002_check_duplicate_identity_cross_user_raises_specific() -> None:
    """User B pairs MAC already owned by user A -> cross-user error message
    (router will translate to 409 Conflict)."""
    db = _patch_db_first(existing_user_id=10)  # row owned by A

    with pytest.raises(ValueError) as excinfo:
        DeviceService._check_duplicate_identity(
            user_id=20,  # user B
            serial_number=None,
            mac_address="AA:BB:CC:11:22:33",
            mqtt_client_id=None,
            db=db,
        )
    assert "tai khoan khac" in str(excinfo.value), (
        "Cross-user duplicate must surface specific message so router maps "
        "to 409 Conflict (BR-040-01)."
    )


def test_hs002_check_duplicate_identity_no_input_short_circuits() -> None:
    """All identity inputs None -> skip DB call entirely."""
    db = MagicMock()

    DeviceService._check_duplicate_identity(
        user_id=10,
        serial_number=None,
        mac_address=None,
        mqtt_client_id=None,
        db=db,
    )

    db.execute.assert_not_called()


def test_hs002_check_duplicate_identity_query_does_not_filter_by_user_id() -> None:
    """Regression guard: SELECT must NOT filter ``user_id = :user_id`` per HS-002."""
    db = _patch_db_first(existing_user_id=None)

    DeviceService._check_duplicate_identity(
        user_id=10,
        serial_number=None,
        mac_address="AA:BB:CC:11:22:33",
        mqtt_client_id=None,
        db=db,
    )

    # First positional arg of db.execute is the SQL statement (sqlalchemy text()).
    sql_text = str(db.execute.call_args[0][0])
    assert "user_id = :user_id" not in sql_text, (
        "Cross-user duplicate check must scan globally (no user_id filter) "
        "per HS-002 / ADR-011."
    )


# ---------------------------------------------------------------------------
# HS-003 - Drop calibration offsets from DeviceSettingsRequest (ADR-012)
# ---------------------------------------------------------------------------


def test_hs003_settings_request_rejects_dropped_calibration_keys() -> None:
    """Pydantic schema must not expose heart_rate_offset / spo2_calibration /
    temperature_offset anymore."""
    fields = set(DeviceSettingsRequest.model_fields.keys())
    assert "heart_rate_offset" not in fields
    assert "spo2_calibration" not in fields
    assert "temperature_offset" not in fields


def test_hs003_settings_request_keeps_active_fields() -> None:
    """notify_* + wear_side stay - they have real consumers."""
    fields = set(DeviceSettingsRequest.model_fields.keys())
    assert {
        "notify_high_hr",
        "notify_low_spo2",
        "notify_high_bp",
        "wear_side",
    }.issubset(fields)


def test_hs003_settings_request_validates_active_fields() -> None:
    payload = DeviceSettingsRequest(
        notify_high_hr=True,
        notify_low_spo2=False,
        notify_high_bp=True,
        wear_side="right",
    )
    assert payload.wear_side == "right"
    assert payload.notify_low_spo2 is False
