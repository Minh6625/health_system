"""Regression tests for ProfileUpdateRequest and gender VI<->EN mapping.

Bug surfaced as PUT /profile -> 500 with psycopg2 CheckViolation
`users_gender_check`: the DB column accepts only canonical English
('male'/'female'/'other') but the validator was returning Vietnamese
labels straight from the UI ('Nam'/'Nữ'/'Khác').

These tests pin both directions of the boundary mapping so a future
refactor cannot silently revert and break the mobile app.
"""

from datetime import date, timedelta

import pytest
from pydantic import ValidationError

from app.schemas.profile import (
    GENDER_EN_TO_VI,
    GENDER_VI_TO_EN,
    MEDICAL_CONDITION_KEYS,
    ProfileUpdateRequest,
    VALID_GENDERS,
)


class TestGenderMapping:
    def test_inbound_vi_converts_to_canonical_en(self):
        for vi, en in GENDER_VI_TO_EN.items():
            payload = ProfileUpdateRequest(full_name="Anh A", gender=vi)
            assert payload.gender == en, f"{vi!r} should persist as {en!r}"

    def test_inbound_canonical_en_is_rejected(self):
        # English values come from the DB layer; the API contract is
        # Vietnamese-in / Vietnamese-out, so accepting English would
        # silently bypass the boundary mapping.
        for en in GENDER_EN_TO_VI:
            with pytest.raises(ValidationError):
                ProfileUpdateRequest(full_name="Anh A", gender=en)

    def test_inbound_unknown_value_rejected(self):
        with pytest.raises(ValidationError):
            ProfileUpdateRequest(full_name="Anh A", gender="khong-biet")

    def test_inbound_none_passes_through(self):
        payload = ProfileUpdateRequest(full_name="Anh A", gender=None)
        assert payload.gender is None

    def test_mapping_is_bijective(self):
        assert set(GENDER_VI_TO_EN.values()) == set(GENDER_EN_TO_VI.keys())
        assert set(GENDER_EN_TO_VI.values()) == set(GENDER_VI_TO_EN.keys())
        assert VALID_GENDERS == set(GENDER_VI_TO_EN.keys())


class TestWeightBound:
    """DB CHECK has weight_kg < 500 (strict); Pydantic must mirror."""

    def test_weight_500_rejected(self):
        with pytest.raises(ValidationError):
            ProfileUpdateRequest(full_name="Anh A", weight_kg=500)

    def test_weight_499_accepted(self):
        payload = ProfileUpdateRequest(full_name="Anh A", weight_kg=499)
        assert payload.weight_kg == 499

    def test_weight_2_accepted(self):
        payload = ProfileUpdateRequest(full_name="Anh A", weight_kg=2)
        assert payload.weight_kg == 2

    def test_weight_below_min_rejected(self):
        with pytest.raises(ValidationError):
            ProfileUpdateRequest(full_name="Anh A", weight_kg=1)


class TestHeightInteger:
    """DB column is `smallint`; Pydantic must reject non-integer cm to
    avoid the prior silent rounding (175.5 -> 176)."""

    def test_height_int_accepted(self):
        payload = ProfileUpdateRequest(full_name="Anh A", height_cm=175)
        assert payload.height_cm == 175
        assert isinstance(payload.height_cm, int)

    def test_height_whole_float_accepted(self):
        # 175.0 has no fractional component -> coerce to int
        payload = ProfileUpdateRequest(full_name="Anh A", height_cm=175.0)
        assert payload.height_cm == 175
        assert isinstance(payload.height_cm, int)

    def test_height_fractional_float_rejected(self):
        with pytest.raises(ValidationError):
            ProfileUpdateRequest(full_name="Anh A", height_cm=175.5)

    def test_height_below_min_rejected(self):
        with pytest.raises(ValidationError):
            ProfileUpdateRequest(full_name="Anh A", height_cm=49)

    def test_height_above_max_rejected(self):
        with pytest.raises(ValidationError):
            ProfileUpdateRequest(full_name="Anh A", height_cm=251)

    def test_height_none_passes_through(self):
        payload = ProfileUpdateRequest(full_name="Anh A", height_cm=None)
        assert payload.height_cm is None


class TestMedicalConditions:
    """List values must be a subset of the UI's checkbox keys."""

    def test_known_keys_accepted(self):
        keys = sorted(MEDICAL_CONDITION_KEYS)
        payload = ProfileUpdateRequest(full_name="Anh A", medical_conditions=keys)
        assert payload.medical_conditions == keys

    def test_empty_list_accepted(self):
        payload = ProfileUpdateRequest(full_name="Anh A", medical_conditions=[])
        assert payload.medical_conditions == []

    def test_none_passes_through(self):
        payload = ProfileUpdateRequest(full_name="Anh A", medical_conditions=None)
        assert payload.medical_conditions is None

    def test_unknown_key_rejected(self):
        with pytest.raises(ValidationError) as exc_info:
            ProfileUpdateRequest(
                full_name="Anh A",
                medical_conditions=["hypertension", "cancer"],
            )
        assert "cancer" in str(exc_info.value)

    def test_typo_rejected(self):
        # Common-typo regression: 'heart-disease' (hyphen) is not a valid key.
        with pytest.raises(ValidationError):
            ProfileUpdateRequest(
                full_name="Anh A",
                medical_conditions=["heart-disease"],
            )


class TestDateOfBirthValidation:
    """ProfileUpdateRequest reuses validate_age so users cannot edit
    themselves into the future or under 16."""

    def test_valid_dob_accepted(self):
        dob = date.today() - timedelta(days=25 * 365)
        payload = ProfileUpdateRequest(full_name="Anh A", date_of_birth=dob)
        assert payload.date_of_birth == dob

    def test_none_accepted(self):
        payload = ProfileUpdateRequest(full_name="Anh A", date_of_birth=None)
        assert payload.date_of_birth is None

    def test_future_date_rejected(self):
        with pytest.raises(ValidationError) as exc_info:
            ProfileUpdateRequest(
                full_name="Anh A",
                date_of_birth=date.today() + timedelta(days=1),
            )
        assert "tương lai" in str(exc_info.value).lower()

    def test_under_16_rejected(self):
        with pytest.raises(ValidationError) as exc_info:
            ProfileUpdateRequest(
                full_name="Anh A",
                date_of_birth=date.today() - timedelta(days=15 * 365),
            )
        assert "16 tuổi" in str(exc_info.value)

    def test_over_150_rejected(self):
        today = date.today()
        with pytest.raises(ValidationError):
            ProfileUpdateRequest(
                full_name="Anh A",
                date_of_birth=date(today.year - 151, today.month, today.day),
            )
