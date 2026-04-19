from datetime import date
from unittest.mock import Mock, patch

from fastapi import BackgroundTasks

from app.api.routes.auth import register, resend_verification
from app.schemas.auth import RegisterRequest, ResendVerificationRequest


def _build_request() -> Mock:
    request = Mock()
    request.headers = {"User-Agent": "pytest"}
    request.client = Mock(host="127.0.0.1")
    return request


def test_register_returns_verification_code_from_service_payload():
    payload = RegisterRequest(
        email="test@example.com",
        full_name="Test User",
        password="StrongPass123!",
        date_of_birth=date(1990, 1, 1),
    )
    user = Mock()
    user.id = 1
    user.email = "test@example.com"
    user.full_name = "Test User"
    user.role = "user"

    with patch(
        "app.api.routes.auth.register_rate_limiter.is_rate_limited",
        return_value=False,
    ), patch("app.api.routes.auth.register_rate_limiter.record_attempt"), patch(
        "app.api.routes.auth.AuthService.register",
        return_value=(True, "Đăng ký thành công", {"verification_code": "123456", "user": user}),
    ):
        response = register(payload, _build_request(), BackgroundTasks(), Mock())

    assert response.success is True
    assert response.verification_code == "123456"


def test_resend_verification_returns_verification_code_from_service_payload():
    payload = ResendVerificationRequest(email="test@example.com")

    with patch(
        "app.api.routes.auth.resend_verification_rate_limiter.is_rate_limited",
        return_value=False,
    ), patch(
        "app.api.routes.auth.resend_verification_rate_limiter.record_attempt"
    ), patch(
        "app.api.routes.auth.AuthService.resend_verification_email",
        return_value=(True, "Đã gửi mã", {"verification_code": "654321"}),
    ):
        response = resend_verification(payload, _build_request(), BackgroundTasks(), Mock())

    assert response.success is True
    assert response.verification_code == "654321"
