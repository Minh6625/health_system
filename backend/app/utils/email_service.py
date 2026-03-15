import smtplib
from email.mime.text import MIMEText
import logging

from app.core.config import settings
from app.utils.email_templates import (
    get_verification_email_html,
    get_password_reset_html,
    get_password_changed_html,
)

logger = logging.getLogger(__name__)


class EmailService:
    """Service for sending emails via SMTP."""

    SMTP_SERVER = settings.SMTP_SERVER or "smtp.gmail.com"
    SMTP_PORT = settings.SMTP_PORT or 587
    SENDER_EMAIL = settings.SENDER_EMAIL or "noreply@healthguard.com"
    SENDER_PASSWORD = settings.SENDER_PASSWORD or ""

    @classmethod
    def send_verification_email(cls, to_email: str, verification_code: str) -> bool:
        """
        Send email verification token to user.

        Args:
            to_email: Recipient email address
            verification_code: 6-digit PIN code for email verification

        Returns:
            True if sent successfully, False otherwise
        """
        try:
            # Use the backend's HTML redirect page to bypass email client restrictions on custom schemes (healthguard://)
            verification_link = f"{settings.BACKEND_URL}/api/v1/mobile/auth/deep-link-redirect?action=verify-email&code={verification_code}&email={to_email}"

            subject = "Xác thực email - Health Guard"
            html_body = get_verification_email_html(verification_link, verification_code)

            return cls._send_email(to_email, subject, html_body)

        except Exception as e:
            logger.error(f"Error sending verification email to {to_email}: {str(e)}")
            return False

    @classmethod
    def send_password_reset_email(
        cls, to_email: str, reset_code: str
    ) -> bool:
        """
        Send password reset PIN code to user.

        Args:
            to_email: Recipient email address
            reset_code: 6-digit PIN code for password reset

        Returns:
            True if sent successfully, False otherwise
        """
        try:
            # Use the backend's HTML redirect page to bypass email client restrictions on custom schemes (healthguard://)
            reset_link = f"{settings.BACKEND_URL}/api/v1/mobile/auth/deep-link-redirect?action=reset-password&code={reset_code}&email={to_email}"

            subject = "Đặt lại mật khẩu - Health Guard"
            html_body = get_password_reset_html(reset_link, reset_code)

            return cls._send_email(to_email, subject, html_body)

        except Exception as e:
            logger.error(f"Error sending password reset email to {to_email}: {str(e)}")
            return False

    @classmethod
    def send_password_changed_notification(cls, to_email: str) -> bool:
        """
        Send notification email after password change.

        Args:
            to_email: Recipient email address

        Returns:
            True if sent successfully, False otherwise
        """
        try:
            subject = "Mật khẩu đã được thay đổi - Health Guard"
            html_body = get_password_changed_html()

            return cls._send_email(to_email, subject, html_body)

        except Exception as e:
            logger.error(f"Error sending password changed notification to {to_email}: {str(e)}")
            return False

    @classmethod
    def _send_email(cls, to_email: str, subject: str, html_body: str) -> bool:
        """
        Internal method to send email via SMTP.

        Args:
            to_email: Recipient email
            subject: Email subject
            html_body: Email HTML body

        Returns:
            True if sent, False if failed
        """
        try:
            # For development/testing: skip if credentials not configured
            if not cls.SENDER_PASSWORD:
                logger.warning(f"SMTP not configured. Skipping email to {to_email}")
                logger.info(f"Email subject: {subject}")
                return True

            message = MIMEText(html_body, "html", "utf-8")
            message["From"] = cls.SENDER_EMAIL
            message["To"] = to_email
            message["Subject"] = subject

            with smtplib.SMTP(cls.SMTP_SERVER, cls.SMTP_PORT, timeout=10) as server:
                server.starttls()
                server.login(cls.SENDER_EMAIL, cls.SENDER_PASSWORD)
                server.send_message(message)

            logger.info(f"Email sent successfully to {to_email}")
            return True

        except Exception as e:
            logger.error(f"SMTP error sending to {to_email}: {str(e)}")
            return False
