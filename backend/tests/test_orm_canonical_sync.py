"""Regression tests for ORM canonical sync (Session B BLOCK 3).

Bugs:
- HS-010 (High)   - Alert ORM 7 new fields + alert_type CHECK (12 values).
- HS-011 (High)   - AuditLog FK + INET + CHECK status canonical.
- HS-012 (Medium) - UserRelationship default can_view_vitals + can_receive_alerts True.
- HS-013 (Medium) - RiskAlertResponse BigInteger + Numeric precision.

Tests inspect SQLAlchemy column metadata at the model boundary - no DB
required. Validate ORM declares match canonical SQL semantics.
"""

from __future__ import annotations

from sqlalchemy import BigInteger, Numeric
from sqlalchemy.dialects.postgresql import ARRAY, INET

from app.models.audit_log_model import AuditLog
from app.models.relationship_model import UserRelationship
from app.models.risk_alert_response_model import RiskAlertResponse
from app.models.sos_event_model import Alert


# ---------------------------------------------------------------------------
# HS-010 - Alert ORM canonical alignment
# ---------------------------------------------------------------------------


def _alert_columns() -> dict:
    return {col.name: col for col in Alert.__table__.columns}


def test_hs010_alert_has_seven_canonical_fields() -> None:
    cols = _alert_columns()
    for field in (
        "sos_event_id",
        "sent_at",
        "delivered_at",
        "read_at",
        "acknowledged_at",
        "sent_via",
        "expires_at",
    ):
        assert field in cols, f"Alert missing canonical field {field!r}"


def test_hs010_alert_sos_event_id_is_fk_to_sos_events() -> None:
    sos_event_id = _alert_columns()["sos_event_id"]
    fk = next(iter(sos_event_id.foreign_keys))
    assert fk.target_fullname.startswith("sos_events.")
    assert fk.ondelete == "SET NULL"


def test_hs010_alert_sent_via_is_array_text() -> None:
    sent_via = _alert_columns()["sent_via"]
    assert isinstance(sent_via.type, ARRAY)


def test_hs010_alert_has_alert_type_check_constraint() -> None:
    """alert_type CHECK constraint must be present and cover 12 canonical values."""
    constraints = {c.name for c in Alert.__table__.constraints if c.name}
    assert "check_alert_type" in constraints

    check = next(
        c for c in Alert.__table__.constraints if getattr(c, "name", None) == "check_alert_type"
    )
    sql_text = str(check.sqltext)
    for canonical_value in (
        "vital_abnormal",
        "fall_detected",
        "sos_triggered",
        "risk_high",
        "risk_critical",
        "device_offline",
        "low_battery",
        "medication_reminder",
        "system",
        "sleep_anomaly",
        "manual_check_in",
        "caregiver_message",
    ):
        assert canonical_value in sql_text, f"alert_type CHECK missing {canonical_value!r}"


# ---------------------------------------------------------------------------
# HS-011 - AuditLog canonical alignment
# ---------------------------------------------------------------------------


def _audit_log_columns() -> dict:
    return {col.name: col for col in AuditLog.__table__.columns}


def test_hs011_audit_log_user_id_has_fk_set_null() -> None:
    cols = _audit_log_columns()
    assert "user_id" in cols
    fks = list(cols["user_id"].foreign_keys)
    assert fks, "AuditLog.user_id missing FK to users(id)"
    assert fks[0].target_fullname == "users.id"
    assert fks[0].ondelete == "SET NULL"


def test_hs011_audit_log_device_id_has_fk_set_null() -> None:
    cols = _audit_log_columns()
    assert "device_id" in cols
    fks = list(cols["device_id"].foreign_keys)
    assert fks, "AuditLog.device_id missing FK to devices(id)"
    assert fks[0].target_fullname == "devices.id"
    assert fks[0].ondelete == "SET NULL"


def test_hs011_audit_log_has_error_message_text() -> None:
    cols = _audit_log_columns()
    assert "error_message" in cols


def test_hs011_audit_log_ip_address_uses_inet() -> None:
    ip = _audit_log_columns()["ip_address"]
    assert isinstance(ip.type, INET)


def test_hs011_audit_log_has_status_check_constraint() -> None:
    constraints = {c.name for c in AuditLog.__table__.constraints if c.name}
    assert "check_audit_log_status" in constraints
    check = next(
        c
        for c in AuditLog.__table__.constraints
        if getattr(c, "name", None) == "check_audit_log_status"
    )
    sql_text = str(check.sqltext)
    for value in ("success", "failure", "pending"):
        assert value in sql_text


# ---------------------------------------------------------------------------
# HS-012 - UserRelationship default permissions True
# ---------------------------------------------------------------------------


def test_hs012_user_relationship_can_view_vitals_default_true() -> None:
    col = UserRelationship.__table__.c.can_view_vitals
    assert col.default is not None and col.default.arg is True


def test_hs012_user_relationship_can_receive_alerts_default_true() -> None:
    col = UserRelationship.__table__.c.can_receive_alerts
    assert col.default is not None and col.default.arg is True


def test_hs012_user_relationship_can_view_location_stays_default_false() -> None:
    """Location remains opt-in - patient must explicitly grant."""
    col = UserRelationship.__table__.c.can_view_location
    assert col.default is not None and col.default.arg is False


def test_hs012_user_relationship_can_view_medical_info_stays_default_false() -> None:
    """Medical info remains opt-in (P-4 privacy posture)."""
    col = UserRelationship.__table__.c.can_view_medical_info
    assert col.default is not None and col.default.arg is False


# ---------------------------------------------------------------------------
# HS-013 - RiskAlertResponse type fixes
# ---------------------------------------------------------------------------


def test_hs013_risk_alert_response_risk_score_id_is_bigint() -> None:
    col = RiskAlertResponse.__table__.c.risk_score_id
    assert isinstance(col.type, BigInteger)


def test_hs013_risk_alert_response_device_id_is_bigint() -> None:
    col = RiskAlertResponse.__table__.c.device_id
    assert isinstance(col.type, BigInteger)


def test_hs013_risk_alert_response_latitude_uses_numeric_10_8() -> None:
    col = RiskAlertResponse.__table__.c.latitude
    assert isinstance(col.type, Numeric)
    assert col.type.precision == 10
    assert col.type.scale == 8


def test_hs013_risk_alert_response_longitude_uses_numeric_11_8() -> None:
    col = RiskAlertResponse.__table__.c.longitude
    assert isinstance(col.type, Numeric)
    assert col.type.precision == 11
    assert col.type.scale == 8
