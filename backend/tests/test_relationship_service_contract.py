from __future__ import annotations

from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import pytest
from fastapi import HTTPException

from app.services.relationship_service import RelationshipService


# ---------------------------------------------------------------------------
# Bug fix G-5: ``primary_relationship_label`` is "what current_user calls
# their partner" and must live on the row where ``caregiver_id == current_user.id``.
# Before the fix the label was written to whatever row ``relationship_id``
# pointed at; the dashboard PUT happens to send the patient-side row, so a
# user relabelling their partner ended up overwriting the partner's own
# label of them ("nó bị ngược"). These tests pin the corrected routing in
# ``update_relationship`` and the corrected read in ``format_relationships``
# / ``get_linked_contact_detail`` so the regression cannot silently come
# back.
# ---------------------------------------------------------------------------


def _build_relationship_row(
    *,
    rel_id: int,
    patient_id: int,
    caregiver_id: int,
    primary_relationship_label: str | None = None,
    status: str = "accepted",
    can_view_vitals: bool = False,
    can_receive_alerts: bool = False,
    can_view_location: bool = False,
    can_view_medical_info: bool = False,
    relationship_type: str = "family",
    tags: list | None = None,
) -> SimpleNamespace:
    return SimpleNamespace(
        id=rel_id,
        patient_id=patient_id,
        caregiver_id=caregiver_id,
        primary_relationship_label=primary_relationship_label,
        status=status,
        can_view_vitals=can_view_vitals,
        can_receive_alerts=can_receive_alerts,
        can_view_location=can_view_location,
        can_view_medical_info=can_view_medical_info,
        relationship_type=relationship_type,
        tags=tags or [],
        created_at=None,
    )


def _build_payload(**kwargs) -> SimpleNamespace:
    """Mimic the Pydantic ``RelationshipUpdate.dict(exclude_unset=True)``
    interface used by ``update_relationship`` without depending on the real
    schema's validators."""

    payload = SimpleNamespace(**kwargs)
    payload.dict = lambda exclude_unset=False: {
        key: value for key, value in kwargs.items()
    }
    return payload


def test_update_relationship_routes_label_to_caregiver_side_row() -> None:
    """When the current user (A) updates a label using the patient-side
    row's id, the new label must land on the caregiver-side row (the row
    where A is caregiver) so A's own dashboard reflects the change."""
    current_user = SimpleNamespace(id=10)  # user A
    partner_id = 20  # user B

    # ``rel`` is the row passed by the dashboard PUT — the patient-side
    # row from A's perspective (A is patient on this row).
    patient_side_row = _build_relationship_row(
        rel_id=101,
        patient_id=current_user.id,
        caregiver_id=partner_id,
        primary_relationship_label="OldLabelOnPatientSide",
    )
    # The caregiver-side row is the row where A is caregiver. The fix
    # must redirect the label write here.
    caregiver_side_row = _build_relationship_row(
        rel_id=102,
        patient_id=partner_id,
        caregiver_id=current_user.id,
        primary_relationship_label="OldLabelOnCaregiverSide",
    )

    db = MagicMock()
    # ``db.query(UserRelationship).filter(...).first()`` chain returns the
    # caregiver-side row; the lookup is the only ORM call inside
    # ``update_relationship`` so a single ``return_value`` is sufficient.
    db.query.return_value.filter.return_value.first.return_value = caregiver_side_row

    payload = _build_payload(
        primary_relationship_label="NewLabel",
        can_view_vitals=True,
    )

    with patch(
        "app.services.relationship_service.RelationshipRepository.get_by_id",
        return_value=patient_side_row,
    ), patch(
        "app.services.relationship_service.RelationshipRepository.update",
        side_effect=lambda _db, rel: rel,
    ):
        result = RelationshipService.update_relationship(
            db,
            current_user,
            patient_side_row.id,
            payload,
        )

    # Label landed on the caregiver-side row; the patient-side row keeps
    # its own (unchanged) label so the partner's view is not corrupted.
    assert caregiver_side_row.primary_relationship_label == "NewLabel"
    assert patient_side_row.primary_relationship_label == "OldLabelOnPatientSide"

    # Permissions still target the row passed in (per-row "của tôi"
    # semantics): A granting can_view_vitals on the patient-side row means
    # the caregiver (partner) can see A's vitals.
    assert patient_side_row.can_view_vitals is True
    assert caregiver_side_row.can_view_vitals is False

    # The repository update is invoked with the original ``rel`` (not the
    # caregiver-side row), preserving the existing return contract.
    assert result is patient_side_row


def test_update_relationship_falls_back_to_passed_row_when_no_caregiver_row() -> None:
    """For a pending outgoing request only one row exists (the requester is
    already the caregiver on it). The fix must still apply the label to
    that row instead of dropping the update on the floor."""
    current_user = SimpleNamespace(id=10)  # user A
    partner_id = 20  # user B

    pending_row = _build_relationship_row(
        rel_id=201,
        patient_id=partner_id,
        caregiver_id=current_user.id,
        primary_relationship_label="OldLabel",
        status="pending",
    )

    db = MagicMock()
    db.query.return_value.filter.return_value.first.return_value = None  # no inverse

    payload = _build_payload(primary_relationship_label="NewLabel")

    with patch(
        "app.services.relationship_service.RelationshipRepository.get_by_id",
        return_value=pending_row,
    ), patch(
        "app.services.relationship_service.RelationshipRepository.update",
        side_effect=lambda _db, rel: rel,
    ):
        RelationshipService.update_relationship(
            db,
            current_user,
            pending_row.id,
            payload,
        )

    # The caregiver-side fallback path: pending_row is already the
    # caregiver-side row from A's perspective, so the label must be
    # written there even though the lookup returned None.
    assert pending_row.primary_relationship_label == "NewLabel"


def test_format_relationships_returns_label_from_caregiver_side_row() -> None:
    """``format_relationships`` must surface the caregiver-side row's label
    so the response shows what the current user calls the partner, not
    what the partner calls the current user."""
    current_user_id = 10
    partner_id = 20

    patient_side_row = _build_relationship_row(
        rel_id=101,
        patient_id=current_user_id,
        caregiver_id=partner_id,
        primary_relationship_label="WhatPartnerCallsMe",
        can_view_vitals=True,  # permissions live on this row
    )
    caregiver_side_row = _build_relationship_row(
        rel_id=102,
        patient_id=partner_id,
        caregiver_id=current_user_id,
        primary_relationship_label="WhatICallPartner",
        can_view_vitals=False,
    )

    db = MagicMock()
    # ``format_relationships`` does ``db.query(UserRelationship).filter(...).all()``.
    db.query.return_value.filter.return_value.all.return_value = [
        patient_side_row,
        caregiver_side_row,
    ]

    partner_user = SimpleNamespace(
        id=partner_id, full_name="Partner Name", email="partner@example.com"
    )
    me_user = SimpleNamespace(
        id=current_user_id, full_name="Me", email="me@example.com"
    )

    def _get_by_id(_db, user_id):
        return me_user if user_id == current_user_id else partner_user

    with patch(
        "app.services.relationship_service.UserRepository.get_by_id",
        side_effect=_get_by_id,
    ):
        result = RelationshipService.format_relationships(db, current_user_id)

    assert len(result) == 1
    item = result[0]
    # The display label is the *caregiver-side* row's label, i.e. what
    # the current user calls the partner.
    assert item["primary_relationship_label"] == "WhatICallPartner"
    # ``id`` and per-row permissions still come from the patient-side row
    # so the existing PUT/permission semantics keep working.
    assert item["id"] == patient_side_row.id
    assert item["can_view_vitals"] is True


def test_format_relationships_falls_back_when_no_caregiver_row() -> None:
    """For a pending incoming request the current user only has a
    patient-side row. The label must still be returned from that single
    row instead of None."""
    current_user_id = 10
    partner_id = 20

    only_row = _build_relationship_row(
        rel_id=301,
        patient_id=current_user_id,
        caregiver_id=partner_id,
        primary_relationship_label="LabelFromIncomingRequest",
        status="pending",
    )

    db = MagicMock()
    db.query.return_value.filter.return_value.all.return_value = [only_row]

    partner_user = SimpleNamespace(
        id=partner_id, full_name="Partner", email="partner@example.com"
    )
    me_user = SimpleNamespace(id=current_user_id, full_name="Me", email="me@example.com")

    def _get_by_id(_db, user_id):
        return me_user if user_id == current_user_id else partner_user

    with patch(
        "app.services.relationship_service.UserRepository.get_by_id",
        side_effect=_get_by_id,
    ):
        result = RelationshipService.format_relationships(db, current_user_id)

    assert len(result) == 1
    assert result[0]["primary_relationship_label"] == "LabelFromIncomingRequest"


# ---------------------------------------------------------------------------
# P-4: ``get_linked_contact_medical_info`` exposes a patient's self-filled
# medical profile to a caregiver only when the patient has explicitly
# granted ``can_view_medical_info``. These tests pin both the happy path
# and the gating behaviour so a careless refactor cannot accidentally
# leak medical info.
# ---------------------------------------------------------------------------


def _build_user_with_medical(**overrides) -> SimpleNamespace:
    """Construct a User-shaped namespace with the medical fields populated.
    ``UserRepository.get_by_id`` returns a real ``User`` ORM instance in
    production but the service only reads attributes by name so a
    namespace is sufficient — and avoids hitting SQLAlchemy in tests."""

    base = {
        "id": 200,
        "full_name": "Bà Mẹ",
        "email": "ba.me@example.com",
        "avatar_url": None,
        "blood_type": "O+",
        "height_cm": 158,
        "weight_kg": 52.5,
        "medications": ["Metformin 500mg", "Losartan 50mg"],
        "allergies": ["Penicillin"],
        "medical_conditions": ["hypertension", "diabetes"],
    }
    base.update(overrides)
    return SimpleNamespace(**base)


def test_get_linked_contact_medical_info_returns_payload_when_granted() -> None:
    """Happy path: caregiver C asks for patient P's medical profile and
    P has granted ``can_view_medical_info`` on the row where P is patient
    and C is caregiver. Service must return the patient's medical fields
    verbatim — coercing list-typed columns defensively but not dropping
    or renaming anything."""
    caregiver = SimpleNamespace(id=100)
    patient_id = 200

    granting_row = _build_relationship_row(
        rel_id=501,
        patient_id=patient_id,
        caregiver_id=caregiver.id,
        can_view_medical_info=True,
    )
    # Inverse row (caregiver-as-patient) exists too — gating must NOT
    # accept this row's flag because the granter direction is wrong.
    inverse_row = _build_relationship_row(
        rel_id=502,
        patient_id=caregiver.id,
        caregiver_id=patient_id,
        can_view_medical_info=False,
    )

    db = MagicMock()
    patient_user = _build_user_with_medical(id=patient_id)

    with patch(
        "app.services.relationship_service.RelationshipRepository.get_user_relationships",
        return_value=[granting_row, inverse_row],
    ), patch(
        "app.services.relationship_service.UserRepository.get_by_id",
        return_value=patient_user,
    ):
        result = RelationshipService.get_linked_contact_medical_info(
            db, caregiver, patient_id
        )

    assert result == {
        "contact_id": patient_id,
        "display_name": "Bà Mẹ",
        "blood_type": "O+",
        "height_cm": 158,
        "weight_kg": 52.5,
        "medications": ["Metformin 500mg", "Losartan 50mg"],
        "allergies": ["Penicillin"],
        "medical_conditions": ["hypertension", "diabetes"],
    }


def test_get_linked_contact_medical_info_403_when_permission_off() -> None:
    """Gating: relationship exists and is accepted, but the patient never
    toggled ``can_view_medical_info`` on. Service must raise 403 — never
    silently fall back to vitals-only data."""
    caregiver = SimpleNamespace(id=100)
    patient_id = 200

    row = _build_relationship_row(
        rel_id=501,
        patient_id=patient_id,
        caregiver_id=caregiver.id,
        can_view_vitals=True,  # has other permissions; just not medical
        can_view_medical_info=False,
    )

    db = MagicMock()
    patient_user = _build_user_with_medical(id=patient_id)

    with patch(
        "app.services.relationship_service.RelationshipRepository.get_user_relationships",
        return_value=[row],
    ), patch(
        "app.services.relationship_service.UserRepository.get_by_id",
        return_value=patient_user,
    ):
        with pytest.raises(HTTPException) as exc_info:
            RelationshipService.get_linked_contact_medical_info(
                db, caregiver, patient_id
            )

    assert exc_info.value.status_code == 403
    assert "chưa cho phép" in exc_info.value.detail


def test_get_linked_contact_medical_info_403_when_only_inverse_grants() -> None:
    """Asymmetry guard: caregiver C grants their own medical info to
    patient P (so the inverse row has ``can_view_medical_info=True``),
    but P has not granted theirs to C. C must NOT be able to read P's
    medical info just because C granted to P. Bug surface: a naive
    ``any(r.can_view_medical_info)`` would pass here."""
    caregiver = SimpleNamespace(id=100)
    patient_id = 200

    p_to_c_row = _build_relationship_row(
        rel_id=501,
        patient_id=patient_id,
        caregiver_id=caregiver.id,
        can_view_medical_info=False,  # P has NOT granted to C
    )
    c_to_p_row = _build_relationship_row(
        rel_id=502,
        patient_id=caregiver.id,
        caregiver_id=patient_id,
        can_view_medical_info=True,   # C HAS granted to P (irrelevant)
    )

    db = MagicMock()
    patient_user = _build_user_with_medical(id=patient_id)

    with patch(
        "app.services.relationship_service.RelationshipRepository.get_user_relationships",
        return_value=[p_to_c_row, c_to_p_row],
    ), patch(
        "app.services.relationship_service.UserRepository.get_by_id",
        return_value=patient_user,
    ):
        with pytest.raises(HTTPException) as exc_info:
            RelationshipService.get_linked_contact_medical_info(
                db, caregiver, patient_id
            )

    assert exc_info.value.status_code == 403


def test_get_linked_contact_medical_info_404_when_no_relationship() -> None:
    """Defensive: caller passed a contact_id they have no accepted
    relationship to. Must 404, never 403 — different UI states."""
    caregiver = SimpleNamespace(id=100)
    other_user_id = 999

    db = MagicMock()

    with patch(
        "app.services.relationship_service.RelationshipRepository.get_user_relationships",
        return_value=[],  # no relationships at all
    ):
        with pytest.raises(HTTPException) as exc_info:
            RelationshipService.get_linked_contact_medical_info(
                db, caregiver, other_user_id
            )

    assert exc_info.value.status_code == 404


def test_get_linked_contact_medical_info_handles_null_array_columns() -> None:
    """Legacy rows from before the ARRAY default migration may still have
    ``None`` for medications/allergies/conditions. Service must coerce
    them to empty lists so the response schema validates and the mobile
    UI doesn't blow up trying to iterate ``null``."""
    caregiver = SimpleNamespace(id=100)
    patient_id = 200

    granting_row = _build_relationship_row(
        rel_id=501,
        patient_id=patient_id,
        caregiver_id=caregiver.id,
        can_view_medical_info=True,
    )

    legacy_user = _build_user_with_medical(
        id=patient_id,
        medications=None,
        allergies=None,
        medical_conditions=None,
    )

    db = MagicMock()
    with patch(
        "app.services.relationship_service.RelationshipRepository.get_user_relationships",
        return_value=[granting_row],
    ), patch(
        "app.services.relationship_service.UserRepository.get_by_id",
        return_value=legacy_user,
    ):
        result = RelationshipService.get_linked_contact_medical_info(
            db, caregiver, patient_id
        )

    assert result["medications"] == []
    assert result["allergies"] == []
    assert result["medical_conditions"] == []
