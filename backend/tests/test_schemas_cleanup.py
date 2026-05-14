"""Regression tests for schema cleanup Phase 4 fixes (Session B BLOCK 4).

Bugs:
- HS-014 (High)   - FamilyProfileSnapshot single canonical definition.
- HS-015 (Low)    - extra='forbid' on every Request schema.
- HS-016 (Low)    - Password min_length=8 across register/reset/change.
- HS-017 (Low)    - PatientInfo.date_of_birth typed as date.

Tests live at the schema boundary (Pydantic model) - no DB / no FastAPI
TestClient required.
"""

from __future__ import annotations

import pytest
from pydantic import ValidationError

from app.schemas import family as family_schemas
from app.schemas import relationship as relationship_schemas
from app.schemas.auth import (
    ChangePasswordRequest,
    LoginRequest,
    RegisterRequest,
    ResetPasswordRequest,
)
from app.schemas.emergency import PatientInfo, TriggerSOSRequest
from app.schemas.relationship import RelationshipRequestCreate


# ---------------------------------------------------------------------------
# HS-014 - Single canonical FamilyProfileSnapshot
# ---------------------------------------------------------------------------


def test_hs014_family_re_exports_relationship_definition() -> None:
    """family.FamilyProfileSnapshot must BE relationship.FamilyProfileSnapshot
    (object identity) so dashboards return one consistent shape."""
    assert family_schemas.FamilyProfileSnapshot is relationship_schemas.FamilyProfileSnapshot


def test_hs014_canonical_field_set_has_21_fields() -> None:
    """Canonical superset has the 21-field shape including the new
    ``has_vitals_data`` / ``vitals_data_message`` flags."""
    fields = set(relationship_schemas.FamilyProfileSnapshot.model_fields.keys())
    assert "has_vitals_data" in fields
    assert "vitals_data_message" in fields
    assert len(fields) == 21


# ---------------------------------------------------------------------------
# HS-015 - Reject unknown fields on Request schemas
# ---------------------------------------------------------------------------

# Sample of representative Request schemas; covers auth + emergency +
# relationship modules. Schemas that need additional required fields are
# constructed with valid baseline payloads first to isolate the
# ``extra="forbid"`` behaviour.
_REQUEST_BASELINE_PAYLOADS = {
    LoginRequest: {"email": "user@example.com", "password": "secret123"},
    TriggerSOSRequest: {"trigger_type": "manual"},
    RelationshipRequestCreate: {"email": "friend@example.com"},
    ResetPasswordRequest: {
        "email": "user@example.com",
        "code": "123456",
        "new_password": "Strong#1Pass",
    },
}


@pytest.mark.parametrize("schema_cls,baseline", list(_REQUEST_BASELINE_PAYLOADS.items()))
def test_hs015_request_schema_rejects_unknown_field(schema_cls, baseline) -> None:
    """Sending an unknown field MUST raise ValidationError so caller sees
    a 422 instead of the field being silently dropped."""
    payload = {**baseline, "this_typo_field_does_not_exist": "value"}
    with pytest.raises(ValidationError) as excinfo:
        schema_cls.model_validate(payload)
    assert "this_typo_field_does_not_exist" in str(excinfo.value)


def test_hs015_register_request_rejects_unknown_field() -> None:
    """RegisterRequest is the cross-cutting case - typos here have caused
    field-named mismatches in the past (e.g. ``fullName`` vs ``full_name``)."""
    with pytest.raises(ValidationError):
        RegisterRequest(
            email="user@example.com",
            full_name="Tester",
            password="Strong#1Pass",
            unknown_field="hi",  # type: ignore[call-arg]
        )


# ---------------------------------------------------------------------------
# HS-016 - Password min_length = 8 across register/reset/change
# ---------------------------------------------------------------------------


def test_hs016_register_request_rejects_short_password() -> None:
    with pytest.raises(ValidationError):
        RegisterRequest(
            email="user@example.com",
            full_name="Tester",
            password="short7p",  # 7 chars
        )


def test_hs016_register_request_accepts_8_char_password() -> None:
    # No raise = pass; field validators on email/full_name still apply.
    RegisterRequest(
        email="user@example.com",
        full_name="Tester",
        password="Aa1!Aa1!",  # 8 chars
    )


def test_hs016_reset_password_request_rejects_7_char_new_password() -> None:
    with pytest.raises(ValidationError):
        ResetPasswordRequest(
            email="user@example.com",
            code="123456",
            new_password="short7p",
        )


def test_hs016_reset_password_request_accepts_8_char_new_password() -> None:
    ResetPasswordRequest(
        email="user@example.com",
        code="123456",
        new_password="Aa1!Aa1!",
    )


def test_hs016_change_password_request_rejects_7_char_new_password() -> None:
    with pytest.raises(ValidationError):
        ChangePasswordRequest(
            current_password="anything",
            new_password="short7p",
        )


def test_hs016_change_password_request_accepts_8_char_new_password() -> None:
    ChangePasswordRequest(
        current_password="anything",
        new_password="Aa1!Aa1!",
    )


# ---------------------------------------------------------------------------
# HS-017 - PatientInfo.date_of_birth typed as date
# ---------------------------------------------------------------------------


def test_hs017_patient_info_date_of_birth_rejects_invalid_string() -> None:
    """``"2026-13-45"`` and ``"abcdef"`` must NOT coerce - raise instead."""
    with pytest.raises(ValidationError):
        PatientInfo.model_validate({
            "user_id": 1,
            "full_name": "Patient",
            "date_of_birth": "2026-13-45",
        })

    with pytest.raises(ValidationError):
        PatientInfo.model_validate({
            "user_id": 1,
            "full_name": "Patient",
            "date_of_birth": "abcdef",
        })


def test_hs017_patient_info_date_of_birth_accepts_iso_date() -> None:
    info = PatientInfo.model_validate({
        "user_id": 1,
        "full_name": "Patient",
        "date_of_birth": "1950-04-15",
    })
    assert info.date_of_birth is not None
    assert info.date_of_birth.isoformat() == "1950-04-15"


def test_hs017_patient_info_date_of_birth_optional_remains_none() -> None:
    info = PatientInfo.model_validate({
        "user_id": 1,
        "full_name": "Patient",
    })
    assert info.date_of_birth is None
