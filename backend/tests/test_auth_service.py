"""
Unit tests for Auth Service

Run with: pytest backend/tests/test_auth_service.py
"""
import pytest
from unittest.mock import Mock, patch, MagicMock
from datetime import datetime, timedelta

from app.services.auth_service import AuthService
from app.models.user_model import User


class TestAuthService:
    """Test cases for AuthService class."""

    @pytest.fixture
    def mock_db(self):
        """Mock database session."""
        return Mock()

    @pytest.fixture
    def mock_user(self):
        """Mock user object."""
        user = Mock(spec=User)
        user.id = 1
        user.email = "test@example.com"
        user.password_hash = "$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/Lt.dbn9/JvY8TJZ6."  # "password123"
        user.full_name = "Test User"
        user.role = "patient"
        user.is_active = True
        user.is_verified = True
        user.updated_at = datetime.now()
        user.last_login_at = None
        return user

    def test_register_valid_email_password(self, mock_db):
        """Test successful user registration with valid credentials."""
        with patch('app.services.auth_service.UserRepository') as mock_repo, \
             patch('app.services.auth_service.AuditLogRepository'), \
             patch('app.services.auth_service.create_email_verification_token') as mock_token, \
             patch('app.services.auth_service.EmailService'):
            
            # Setup
            mock_repo.get_by_email.return_value = None  # Email doesn't exist
            mock_user = Mock()
            mock_user.id = 1
            mock_user.email = "newuser@example.com"
            mock_repo.create_user.return_value = mock_user
            mock_token.return_value = "fake_token_123"
            
            # Execute
            success, message, token_data = AuthService.register(
                mock_db,
                email="newuser@example.com",
                full_name="New User",
                password="password123",
                ip_address="127.0.0.1",
                user_agent="test"
            )
            
            # Assert
            assert success is True
            assert "thành công" in message.lower()
            assert token_data is not None
            assert "verification_token" in token_data

    def test_register_invalid_email(self, mock_db):
        """Test registration with invalid email format."""
        with patch('app.services.auth_service.AuditLogRepository'):
            success, message, token_data = AuthService.register(
                mock_db,
                email="invalid-email",
                full_name="Test User",
                password="password123",
                ip_address="127.0.0.1",
                user_agent="test"
            )
            
            assert success is False
            assert "email không hợp lệ" in message.lower()
            assert token_data is None

    def test_register_short_password(self, mock_db):
        """Test registration with password too short."""
        with patch('app.services.auth_service.AuditLogRepository'):
            success, message, token_data = AuthService.register(
                mock_db,
                email="test@example.com",
                full_name="Test User",
                password="123",  # Less than 6 characters
                ip_address="127.0.0.1",
                user_agent="test"
            )
            
            assert success is False
            assert "6 ký tự" in message.lower()
            assert token_data is None

    def test_register_duplicate_email(self, mock_db, mock_user):
        """Test registration with existing email."""
        with patch('app.services.auth_service.UserRepository') as mock_repo, \
             patch('app.services.auth_service.AuditLogRepository'):
            
            mock_repo.get_by_email.return_value = mock_user  # Email exists
            
            success, message, token_data = AuthService.register(
                mock_db,
                email="test@example.com",
                full_name="Test User",
                password="password123",
                ip_address="127.0.0.1",
                user_agent="test"
            )
            
            assert success is False
            assert "đã tồn tại" in message.lower()
            assert token_data is None

    def test_login_valid_credentials(self, mock_db, mock_user):
        """Test login with valid email and password."""
        with patch('app.services.auth_service.UserRepository') as mock_repo, \
             patch('app.services.auth_service.AuditLogRepository'), \
             patch('app.services.auth_service.create_access_token') as mock_access, \
             patch('app.services.auth_service.create_refresh_token') as mock_refresh:
            
            # Setup
            mock_repo.verify_login.return_value = mock_user
            mock_access.return_value = "access_token_123"
            mock_refresh.return_value = "refresh_token_123"
            
            # Execute
            success, message, token_data = AuthService.login(
                mock_db,
                email="test@example.com",
                password="password123",
                ip_address="127.0.0.1",
                user_agent="test"
            )
            
            # Assert
            assert success is True
            assert "thành công" in message.lower()
            assert token_data is not None
            assert "access_token" in token_data
            assert "refresh_token" in token_data
            assert "user" in token_data

    def test_login_invalid_credentials(self, mock_db):
        """Test login with wrong password."""
        with patch('app.services.auth_service.UserRepository') as mock_repo, \
             patch('app.services.auth_service.AuditLogRepository'):
            
            mock_repo.verify_login.return_value = None  # Invalid credentials
            
            success, message, token_data = AuthService.login(
                mock_db,
                email="test@example.com",
                password="wrongpassword",
                ip_address="127.0.0.1",
                user_agent="test"
            )
            
            assert success is False
            assert "sai email hoặc mật khẩu" in message.lower()
            assert token_data is None

    def test_login_inactive_account(self, mock_db, mock_user):
        """Test login with locked/inactive account."""
        with patch('app.services.auth_service.UserRepository') as mock_repo, \
             patch('app.services.auth_service.AuditLogRepository'):
            
            mock_user.is_active = False  # Account locked
            mock_repo.verify_login.return_value = mock_user
            
            success, message, token_data = AuthService.login(
                mock_db,
                email="test@example.com",
                password="password123",
                ip_address="127.0.0.1",
                user_agent="test"
            )
            
            assert success is False
            assert "khóa" in message.lower()
            assert token_data is None

    def test_login_unverified_email(self, mock_db, mock_user):
        """Test login with unverified email."""
        with patch('app.services.auth_service.UserRepository') as mock_repo, \
             patch('app.services.auth_service.AuditLogRepository'):
            
            mock_user.is_verified = False  # Email not verified
            mock_repo.verify_login.return_value = mock_user
            
            success, message, token_data = AuthService.login(
                mock_db,
                email="test@example.com",
                password="password123",
                ip_address="127.0.0.1",
                user_agent="test"
            )
            
            assert success is False
            assert "xác thực email" in message.lower()
            assert token_data is None

    def test_forgot_password_valid_email(self, mock_db, mock_user):
        """Test forgot password with valid email."""
        with patch('app.services.auth_service.UserRepository') as mock_repo, \
             patch('app.services.auth_service.AuditLogRepository'), \
             patch('app.services.auth_service.create_password_reset_token') as mock_token, \
             patch('app.services.auth_service.EmailService'):
            
            mock_repo.get_by_email.return_value = mock_user
            mock_token.return_value = "reset_token_123"
            
            success, message, token_data = AuthService.forgot_password(
                mock_db,
                email="test@example.com",
                ip_address="127.0.0.1",
                user_agent="test"
            )
            
            assert success is True
            assert token_data is not None
            assert "reset_token" in token_data

    def test_forgot_password_nonexistent_email(self, mock_db):
        """Test forgot password with non-existent email (should return success to prevent enumeration)."""
        with patch('app.services.auth_service.UserRepository') as mock_repo, \
             patch('app.services.auth_service.AuditLogRepository'):
            
            mock_repo.get_by_email.return_value = None  # Email doesn't exist
            
            success, message, token_data = AuthService.forgot_password(
                mock_db,
                email="nonexistent@example.com",
                ip_address="127.0.0.1",
                user_agent="test"
            )
            
            # Should return success to prevent email enumeration
            assert success is True
            assert "email tồn tại" in message.lower()

    def test_change_password_wrong_current_password(self, mock_db, mock_user):
        """Test change password with wrong current password."""
        with patch('app.services.auth_service.UserRepository') as mock_repo, \
             patch('app.services.auth_service.AuditLogRepository'), \
             patch('app.utils.password.verify_password') as mock_verify:
            
            mock_repo.get_by_id.return_value = mock_user
            mock_verify.return_value = False  # Wrong password
            
            success, message = AuthService.change_password(
                mock_db,
                user_id=1,
                current_password="wrongpassword",
                new_password="newpassword123",
                ip_address="127.0.0.1",
                user_agent="test"
            )
            
            assert success is False
            assert "không đúng" in message.lower()

    def test_change_password_success(self, mock_db, mock_user):
        """Test successful password change."""
        with patch('app.services.auth_service.UserRepository') as mock_repo, \
             patch('app.services.auth_service.AuditLogRepository'), \
             patch('app.utils.password.verify_password') as mock_verify, \
             patch('app.services.auth_service.EmailService'):
            
            mock_repo.get_by_id.return_value = mock_user
            mock_verify.return_value = True  # Correct current password
            mock_repo.update_password.return_value = True
            
            success, message = AuthService.change_password(
                mock_db,
                user_id=1,
                current_password="password123",
                new_password="newpassword456",
                ip_address="127.0.0.1",
                user_agent="test"
            )
            
            assert success is True
            assert "thành công" in message.lower()

    def test_resend_verification_already_verified(self, mock_db, mock_user):
        """Test resend verification when email is already verified."""
        with patch('app.services.auth_service.UserRepository') as mock_repo, \
             patch('app.services.auth_service.AuditLogRepository'):
            
            mock_user.is_verified = True  # Already verified
            mock_repo.get_by_email.return_value = mock_user
            
            success, message, token_data = AuthService.resend_verification_email(
                mock_db,
                email="test@example.com",
                ip_address="127.0.0.1",
                user_agent="test"
            )
            
            assert success is False
            assert "đã được xác thực" in message.lower()
            assert token_data is None

    def test_resend_verification_success(self, mock_db, mock_user):
        """Test successful resend verification email."""
        with patch('app.services.auth_service.UserRepository') as mock_repo, \
             patch('app.services.auth_service.AuditLogRepository'), \
             patch('app.services.auth_service.create_email_verification_token') as mock_token, \
             patch('app.services.auth_service.EmailService'):
            
            mock_user.is_verified = False  # Not verified yet
            mock_repo.get_by_email.return_value = mock_user
            mock_token.return_value = "new_verification_token_123"
            
            success, message, token_data = AuthService.resend_verification_email(
                mock_db,
                email="test@example.com",
                ip_address="127.0.0.1",
                user_agent="test"
            )
            
            assert success is True
            assert "gửi lại" in message.lower()
            assert token_data is not None
            assert "verification_token" in token_data

    def test_resend_verification_nonexistent_email(self, mock_db):
        """Test resend verification with non-existent email (should return success to prevent enumeration)."""
        with patch('app.services.auth_service.UserRepository') as mock_repo, \
             patch('app.services.auth_service.AuditLogRepository'):
            
            mock_repo.get_by_email.return_value = None  # Email doesn't exist
            
            success, message, token_data = AuthService.resend_verification_email(
                mock_db,
                email="nonexistent@example.com",
                ip_address="127.0.0.1",
                user_agent="test"
            )
            
            # Should return success to prevent email enumeration
            assert success is True
            assert "email tồn tại" in message.lower()
