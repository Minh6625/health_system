"""
Unit tests for Password Utilities

Run with: pytest backend/tests/test_password_utils.py
"""
import pytest
from app.utils.password import validate_password_strength, hash_password, verify_password


class TestPasswordStrengthValidation:
    """Test cases for password strength validation."""

    def test_valid_strong_password(self):
        """Test validation of a strong password."""
        is_valid, message = validate_password_strength("StrongPass123!")
        assert is_valid is True
        assert "mạnh" in message.lower()

    def test_password_too_short(self):
        """Test password shorter than 8 characters."""
        is_valid, message = validate_password_strength("Short1!")
        assert is_valid is False
        assert "8 ký tự" in message

    def test_password_missing_uppercase(self):
        """Test password without uppercase letters."""
        is_valid, message = validate_password_strength("strongpass123!")
        assert is_valid is False
        assert "in hoa" in message

    def test_password_missing_lowercase(self):
        """Test password without lowercase letters."""
        is_valid, message = validate_password_strength("STRONGPASS123!")
        assert is_valid is False
        assert "in thường" in message

    def test_password_missing_digit(self):
        """Test password without digits."""
        is_valid, message = validate_password_strength("StrongPass!")
        assert is_valid is False
        assert "chữ số" in message

    def test_password_missing_special_char(self):
        """Test password without special characters."""
        is_valid, message = validate_password_strength("StrongPass123")
        assert is_valid is False
        assert "đặc biệt" in message

    def test_password_with_various_special_chars(self):
        """Test password validity with different special characters."""
        test_passwords = [
            "Valid1@password",
            "Valid1#password",
            "Valid1$password",
            "Valid1%password",
            "Valid1&password",
            "Valid1*password",
            "Valid1!password",
        ]
        
        for pwd in test_passwords:
            is_valid, message = validate_password_strength(pwd)
            assert is_valid is True, f"Password '{pwd}' should be valid"


class TestPasswordHashing:
    """Test cases for password hashing and verification."""

    def test_hash_password(self):
        """Test password hashing."""
        password = "TestPassword123!"
        hashed = hash_password(password)
        
        assert hashed != password
        assert len(hashed) > 20  # bcrypt hash is long
        assert hashed.startswith("$2b$")  # bcrypt format

    def test_verify_password_success(self):
        """Test password verification with correct password."""
        password = "TestPassword123!"
        hashed = hash_password(password)
        
        assert verify_password(password, hashed) is True

    def test_verify_password_failure(self):
        """Test password verification with incorrect password."""
        password = "TestPassword123!"
        wrong_password = "WrongPassword123!"
        hashed = hash_password(password)
        
        assert verify_password(wrong_password, hashed) is False

    def test_hash_consistency(self):
        """Test that same password can be verified across multiple hashes."""
        password = "TestPassword123!"
        hash1 = hash_password(password)
        hash2 = hash_password(password)
        
        # Hashes should be different (bcrypt adds salt)
        assert hash1 != hash2
        
        # But both should verify the password
        assert verify_password(password, hash1) is True
        assert verify_password(password, hash2) is True
