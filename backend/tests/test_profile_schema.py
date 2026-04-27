"""Regression tests for ProfileUpdateRequest and gender VI<->EN mapping.

Bug surfaced as PUT /profile -> 500 with psycopg2 CheckViolation
`users_gender_check`: the DB column accepts only canonical English
('male'/'female'/'other') but the validator was returning Vietnamese
labels straight from the UI ('Nam'/'Nữ'/'Khác').

These tests pin both directions of the boundary mapping so a future
refactor cannot silently revert and break the mobile app.
"""

import pytest
from pydantic import ValidationError

from app.schemas.profile import (
    GENDER_EN_TO_VI,
    GENDER_VI_TO_EN,
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
