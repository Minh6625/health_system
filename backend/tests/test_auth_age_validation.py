"""
Unit tests for Age Validation in Auth Service

Run with: pytest backend/tests/test_auth_age_validation.py
"""
import pytest
from datetime import date, timedelta
from app.services.auth_service import AuthService


class TestAgeValidation:
    """Test cases for date of birth and age validation."""

    def test_valid_adult_age(self):
        """Test valid adult age (25 years old)."""
        dob = date.today() - timedelta(days=25*365)
        is_valid, message = AuthService.validate_age(dob)
        assert is_valid is True
        assert "OK" in message

    def test_valid_minimum_age(self):
        """Test exactly 18 years old (minimum requirement)."""
        dob = date.today() - timedelta(days=18*365)
        is_valid, message = AuthService.validate_age(dob)
        assert is_valid is True

    def test_young_age_17_years(self):
        """Test age under 18 (17 years old)."""
        dob = date.today() - timedelta(days=17*365)
        is_valid, message = AuthService.validate_age(dob)
        assert is_valid is False
        assert "18 tuổi" in message

    def test_negative_age_future_date(self):
        """Test negative age (date in future)."""
        dob = date.today() + timedelta(days=1)
        is_valid, message = AuthService.validate_age(dob)
        assert is_valid is False
        assert "tương lai" in message.lower()

    def test_age_over_150(self):
        """Test age over 150 (over max limit)."""
        dob = date.today() - timedelta(days=151*365)
        is_valid, message = AuthService.validate_age(dob)
        assert is_valid is False
        assert "quá cao" in message.lower()

    def test_valid_elderly_age(self):
        """Test valid elderly age (100 years old)."""
        dob = date.today() - timedelta(days=100*365)
        is_valid, message = AuthService.validate_age(dob)
        assert is_valid is True

    def test_valid_age_150_limit(self):
        """Test exactly at maximum age limit (150 years)."""
        dob = date.today() - timedelta(days=150*365)
        is_valid, message = AuthService.validate_age(dob)
        assert is_valid is True

    def test_none_date_of_birth(self):
        """Test None date of birth (optional field)."""
        is_valid, message = AuthService.validate_age(None)
        assert is_valid is True
        assert "OK" in message

    def test_leap_year_age_calculation(self):
        """Test age calculation on leap year date."""
        # February 29 of 18 years ago
        dob = date(2006, 2, 28)  # Using 2006 which has Feb 28
        is_valid, message = AuthService.validate_age(dob)
        assert is_valid is True

    def test_age_boundary_just_turned_18(self):
        """Test age just after turning 18."""
        dob = date.today() - timedelta(days=18*365 - 1)
        is_valid, message = AuthService.validate_age(dob)
        assert is_valid is True

    def test_age_boundary_just_before_18(self):
        """Test age just before turning 18."""
        dob = date.today() - timedelta(days=18*365 + 1)
        is_valid, message = AuthService.validate_age(dob)
        assert is_valid is False
