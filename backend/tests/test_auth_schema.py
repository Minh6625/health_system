"""
Unit tests for Auth Schemas

Run with: pytest backend/tests/test_auth_schema.py
"""
import pytest
from pydantic import ValidationError
from datetime import date

from app.schemas.auth import RegisterRequest


class TestRegisterRequestSchema:
    """Test cases for RegisterRequest Pydantic schema validation."""

    def test_valid_registration_request(self):
        """Test valid registration request."""
        request = RegisterRequest(
            email="test@example.com",
            full_name="John Doe",
            password="StrongPass123!"
        )
        
        assert request.email == "test@example.com"
        assert request.full_name == "John Doe"
        assert request.password == "StrongPass123!"
        assert request.role == "patient"

    def test_valid_registration_with_all_fields(self):
        """Test valid registration with all fields."""
        request = RegisterRequest(
            email="test@example.com",
            full_name="Jane Smith",
            password="SecurePass456!",
            role="caregiver",
            date_of_birth=date(2000, 1, 15),
            phone="0912345678"
        )
        
        assert request.email == "test@example.com"
        assert request.full_name == "Jane Smith"
        assert request.password == "SecurePass456!"
        assert request.role == "caregiver"
        assert request.date_of_birth == date(2000, 1, 15)
        assert request.phone == "0912345678"

    def test_full_name_with_vietnamese_diacritics(self):
        """Test full_name with Vietnamese diacritics."""
        request = RegisterRequest(
            email="test@example.com",
            full_name="Nguyễn Văn Anh",
            password="StrongPass123!"
        )
        
        assert request.full_name == "Nguyễn Văn Anh"

    def test_full_name_with_multiple_spaces(self):
        """Test full_name with multiple words."""
        request = RegisterRequest(
            email="test@example.com",
            full_name="John Michael Smith",
            password="StrongPass123!"
        )
        
        assert request.full_name == "John Michael Smith"

    def test_full_name_with_numbers_validation_error(self):
        """Test full_name containing numbers raises ValidationError."""
        with pytest.raises(ValidationError) as exc_info:
            RegisterRequest(
                email="test@example.com",
                full_name="User 123",  # Contains numbers
                password="StrongPass123!"
            )
        
        errors = exc_info.value.errors()
        assert any("full_name" in str(error["loc"]) for error in errors)
        assert any("số hoặc ký tự đặc biệt" in str(error["msg"]) for error in errors)

    def test_full_name_with_special_characters_validation_error(self):
        """Test full_name with special characters raises ValidationError."""
        with pytest.raises(ValidationError) as exc_info:
            RegisterRequest(
                email="test@example.com",
                full_name="User@123!",  # Contains @ and !
                password="StrongPass123!"
            )
        
        errors = exc_info.value.errors()
        assert any("full_name" in str(error["loc"]) for error in errors)

    def test_full_name_with_symbols_validation_error(self):
        """Test full_name with various symbols raises ValidationError."""
        invalid_names = [
            "John#Doe",
            "Jane$Smith",
            "User%Name",
            "Test^Name",
            "User&Name",
            "Name*Here",
            "Test(Name)",
            "User[Name]",
            "Name{Test}",
            "User.Name",
            "Name,Here",
            "User;Name",
            "Name:Here",
            "User'Name",
            'Name"Here',
            "User/Name",
            "Name\\Here",
            "User|Name",
            "Name<Test>",
            "User?Name",
            "Name~Here",
            "User`Name"
        ]
        
        for invalid_name in invalid_names:
            with pytest.raises(ValidationError):
                RegisterRequest(
                    email="test@example.com",
                    full_name=invalid_name,
                    password="StrongPass123!"
                )

    def test_full_name_too_short_validation_error(self):
        """Test full_name less than 2 characters raises ValidationError."""
        with pytest.raises(ValidationError) as exc_info:
            RegisterRequest(
                email="test@example.com",
                full_name="A",  # Only 1 character
                password="StrongPass123!"
            )
        
        errors = exc_info.value.errors()
        assert any("full_name" in str(error["loc"]) for error in errors)

    def test_full_name_too_long_validation_error(self):
        """Test full_name exceeding 100 characters raises ValidationError."""
        long_name = "A" * 101  # 101 characters
        
        with pytest.raises(ValidationError) as exc_info:
            RegisterRequest(
                email="test@example.com",
                full_name=long_name,
                password="StrongPass123!"
            )
        
        errors = exc_info.value.errors()
        assert any("full_name" in str(error["loc"]) for error in errors)

    def test_full_name_empty_validation_error(self):
        """Test empty full_name raises ValidationError."""
        with pytest.raises(ValidationError) as exc_info:
            RegisterRequest(
                email="test@example.com",
                full_name="",
                password="StrongPass123!"
            )
        
        errors = exc_info.value.errors()
        assert any("full_name" in str(error["loc"]) for error in errors)

    def test_full_name_whitespace_only_validation_error(self):
        """Test full_name with only whitespace raises ValidationError."""
        with pytest.raises(ValidationError) as exc_info:
            RegisterRequest(
                email="test@example.com",
                full_name="   ",  # Only spaces
                password="StrongPass123!"
            )
        
        errors = exc_info.value.errors()
        assert any("full_name" in str(error["loc"]) for error in errors)

    def test_full_name_stripped_whitespace(self):
        """Test full_name with leading/trailing whitespace is stripped."""
        request = RegisterRequest(
            email="test@example.com",
            full_name="  John Doe  ",
            password="StrongPass123!"
        )
        
        assert request.full_name == "John Doe"

    def test_email_validation(self):
        """Test email validation."""
        with pytest.raises(ValidationError) as exc_info:
            RegisterRequest(
                email="invalid-email",  # No @ or domain
                full_name="John Doe",
                password="StrongPass123!"
            )
        
        errors = exc_info.value.errors()
        assert any("email" in str(error["loc"]) for error in errors)

    def test_password_too_short_validation_error(self):
        """Test password less than 8 characters raises ValidationError."""
        with pytest.raises(ValidationError) as exc_info:
            RegisterRequest(
                email="test@example.com",
                full_name="John Doe",
                password="Pass1!"  # Less than 8 characters
            )
        
        errors = exc_info.value.errors()
        assert any("password" in str(error["loc"]) for error in errors)

    def test_password_too_long_validation_error(self):
        """Test password exceeding 64 characters raises ValidationError."""
        long_password = "P@ssw0rd" * 10  # 80 characters
        
        with pytest.raises(ValidationError) as exc_info:
            RegisterRequest(
                email="test@example.com",
                full_name="John Doe",
                password=long_password
            )
        
        errors = exc_info.value.errors()
        assert any("password" in str(error["loc"]) for error in errors)

    def test_role_invalid_validation_error(self):
        """Test invalid role raises ValidationError."""
        with pytest.raises(ValidationError) as exc_info:
            RegisterRequest(
                email="test@example.com",
                full_name="John Doe",
                password="StrongPass123!",
                role="admin"  # Invalid role
            )
        
        errors = exc_info.value.errors()
        assert any("role" in str(error["loc"]) for error in errors)

    def test_role_case_insensitive(self):
        """Test role is converted to lowercase."""
        request = RegisterRequest(
            email="test@example.com",
            full_name="John Doe",
            password="StrongPass123!",
            role="CAREGIVER"
        )
        
        assert request.role == "caregiver"

    def test_phone_validation_removes_spaces_and_dashes(self):
        """Test phone validation removes spaces and dashes."""
        request = RegisterRequest(
            email="test@example.com",
            full_name="John Doe",
            password="StrongPass123!",
            phone="0912 345-678"
        )
        
        assert request.phone == "0912345678"

    def test_phone_invalid_with_letters_validation_error(self):
        """Test phone with letters raises ValidationError."""
        with pytest.raises(ValidationError) as exc_info:
            RegisterRequest(
                email="test@example.com",
                full_name="John Doe",
                password="StrongPass123!",
                phone="0912ABC678"
            )
        
        errors = exc_info.value.errors()
        assert any("phone" in str(error["loc"]) for error in errors)

    def test_phone_too_short_validation_error(self):
        """Test phone less than 10 digits raises ValidationError."""
        with pytest.raises(ValidationError) as exc_info:
            RegisterRequest(
                email="test@example.com",
                full_name="John Doe",
                password="StrongPass123!",
                phone="12345"
            )
        
        errors = exc_info.value.errors()
        assert any("phone" in str(error["loc"]) for error in errors)

    def test_phone_too_long_validation_error(self):
        """Test phone more than 15 digits raises ValidationError."""
        with pytest.raises(ValidationError) as exc_info:
            RegisterRequest(
                email="test@example.com",
                full_name="John Doe",
                password="StrongPass123!",
                phone="1234567890123456"
            )
        
        errors = exc_info.value.errors()
        assert any("phone" in str(error["loc"]) for error in errors)
